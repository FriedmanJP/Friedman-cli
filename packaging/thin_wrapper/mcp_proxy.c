/* Friedman-cli (frdc) — Lazy-spawning Pure C99 + yyjson stdio MCP proxy ([FASTPATH-W6] #299)
 * Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
 * SPDX-License-Identifier: GPL-3.0-only
 *
 * State 0 (~2-4 MiB RSS, <5 ms): answers initialize, notifications/..., ping,
 *   tools/list (prefix, families, tools, cursor, limit, --compact), -32700,
 *   -32601, and unknown-tool -32602 directly from FRDCACHE v1 (M:index, M:full,
 *   M:compact) without booting Julia.
 * State 1 (first valid tools/call): spawns frdc-core serve --mcp with stdin piped
 *   and stdout/stderr directly inherited (zero 2-pipe deadlock), forwards the
 *   triggering line + buffered unread stdin bytes, pumps remaining stdin until EOF,
 *   and propagates the child exit code.
 */

#ifndef _WIN32
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#endif

#include "frdc_thin.h"
#include "yyjson.h"

#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <io.h>
#else
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

#define MCP_PATH_MAX 4096

/* ── Small growable buffer ─────────────────────────────────────────────── */

typedef struct {
    char *data;
    size_t len;
    size_t cap;
    int oom;
} McpBuf;

static void mb_init(McpBuf *b) {
    b->data = NULL; b->len = 0; b->cap = 0; b->oom = 0;
}

static void mb_free(McpBuf *b) {
    free(b->data);
    b->data = NULL; b->len = 0; b->cap = 0; b->oom = 0;
}

static int mb_reserve(McpBuf *b, size_t extra) {
    if (b->oom) return -1;
    if (extra > SIZE_MAX - b->len - 1u) { b->oom = 1; return -1; }
    size_t need = b->len + extra + 1u;
    if (need <= b->cap) return 0;
    size_t ncap = b->cap ? b->cap : 512u;
    while (ncap < need) {
        if (ncap > SIZE_MAX / 2u) { ncap = need; break; }
        ncap *= 2u;
    }
    char *p = (char *)realloc(b->data, ncap);
    if (!p) { b->oom = 1; return -1; }
    b->data = p;
    b->cap = ncap;
    return 0;
}

static void mb_mem(McpBuf *b, const void *src, size_t n) {
    if (n == 0) return;
    if (mb_reserve(b, n) != 0) return;
    memcpy(b->data + b->len, src, n);
    b->len += n;
    b->data[b->len] = '\0';
}

static void mb_str(McpBuf *b, const char *s) {
    if (s) mb_mem(b, s, strlen(s));
}

static void mb_ch(McpBuf *b, char c) {
    if (mb_reserve(b, 1u) != 0) return;
    b->data[b->len++] = c;
    b->data[b->len] = '\0';
}

static void mb_json_str(McpBuf *b, const char *s, size_t len) {
    static const char HEX[] = "0123456789abcdef";
    mb_ch(b, '"');
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char)s[i];
        switch (c) {
            case '"':  mb_mem(b, "\\\"", 2); break;
            case '\\': mb_mem(b, "\\\\", 2); break;
            case '\b': mb_mem(b, "\\b", 2); break;
            case '\f': mb_mem(b, "\\f", 2); break;
            case '\n': mb_mem(b, "\\n", 2); break;
            case '\r': mb_mem(b, "\\r", 2); break;
            case '\t': mb_mem(b, "\\t", 2); break;
            default:
                if (c < 0x20u) {
                    char esc[6];
                    esc[0] = '\\'; esc[1] = 'u'; esc[2] = '0'; esc[3] = '0';
                    esc[4] = HEX[(c >> 4) & 0x0Fu];
                    esc[5] = HEX[c & 0x0Fu];
                    mb_mem(b, esc, 6);
                } else {
                    mb_ch(b, (char)c);
                }
                break;
        }
    }
    mb_ch(b, '"');
}

/* ── Explicit buffered LineReader (preserves unread bytes across handoff) ─ */

typedef struct {
    uint8_t rbuf[8192];
    size_t rpos;
    size_t rlen;
    char *line;
    size_t line_cap;
    int eof;
} LineReader;

static void lr_init(LineReader *lr) {
    memset(lr, 0, sizeof(*lr));
}

static void lr_free(LineReader *lr) {
    free(lr->line);
    lr->line = NULL;
    lr->line_cap = 0;
}

static ssize_t read_stdin_raw(uint8_t *dst, size_t cap) {
#ifdef _WIN32
    HANDLE h = GetStdHandle(STD_INPUT_HANDLE);
    if (h == INVALID_HANDLE_VALUE || h == NULL) return 0;
    DWORD got = 0;
    BOOL ok = ReadFile(h, dst, (DWORD)cap, &got, NULL);
    if (!ok) {
        DWORD err = GetLastError();
        if (err == ERROR_BROKEN_PIPE || err == ERROR_HANDLE_EOF) return 0;
        return -1;
    }
    return (ssize_t)got;
#else
    for (;;) {
        ssize_t n = read(STDIN_FILENO, dst, cap);
        if (n < 0 && errno == EINTR) continue;
        return n;
    }
#endif
}

/* Returns 1 if a line was read, 0 on EOF, -1 on error */
static int lr_next_line(LineReader *lr, const char **out_line, size_t *out_len) {
    size_t llen = 0;
    for (;;) {
        if (lr->rpos < lr->rlen) {
            uint8_t *nl = (uint8_t *)memchr(lr->rbuf + lr->rpos, '\n', lr->rlen - lr->rpos);
            size_t chunk = nl ? (size_t)(nl - (lr->rbuf + lr->rpos)) : (lr->rlen - lr->rpos);
            if (llen + chunk + 1u > lr->line_cap) {
                size_t ncap = lr->line_cap ? lr->line_cap : 1024u;
                while (ncap < llen + chunk + 1u) ncap *= 2u;
                char *p = (char *)realloc(lr->line, ncap);
                if (!p) return -1;
                lr->line = p;
                lr->line_cap = ncap;
            }
            if (chunk > 0) {
                memcpy(lr->line + llen, lr->rbuf + lr->rpos, chunk);
                llen += chunk;
            }
            lr->rpos += chunk;
            if (nl) {
                lr->rpos++; /* consume '\n' */
                if (llen > 0 && lr->line[llen - 1] == '\r') llen--;
                lr->line[llen] = '\0';
                *out_line = lr->line;
                *out_len = llen;
                return 1;
            }
        }
        if (lr->eof) {
            if (llen == 0) return 0;
            if (!lr->line) return 0;
            if (llen > 0 && lr->line[llen - 1] == '\r') llen--;
            lr->line[llen] = '\0';
            *out_line = lr->line;
            *out_len = llen;
            return 1;
        }
        lr->rpos = 0;
        lr->rlen = 0;
        ssize_t n = read_stdin_raw(lr->rbuf, sizeof(lr->rbuf));
        if (n < 0) return -1;
        if (n == 0) {
            lr->eof = 1;
            continue;
        }
        lr->rlen = (size_t)n;
    }
}

/* ── MCP tool index & filter replication (matches src/commands/serve.jl) ─ */

typedef struct {
    const char *name;
    size_t name_len;
    const char *family;
    size_t family_len;
    uint32_t seg_count;
    const char *segs[4];
    uint32_t full_off;
    uint32_t full_len;
    uint32_t compact_off;
    uint32_t compact_len;
} McpToolRec;

typedef struct {
    uint8_t *idx_buf;
    size_t idx_len;
    McpToolRec *recs;
    uint32_t n_tools;

    uint8_t *payload_buf;
    size_t payload_len;
    int payload_loaded;
} McpCatalog;

static void catalog_free(McpCatalog *cat) {
    free(cat->idx_buf);
    free(cat->recs);
    free(cat->payload_buf);
    memset(cat, 0, sizeof(*cat));
}

static int catalog_ensure_index(const FrdcPack *pack, McpCatalog *cat) {
    if (cat->idx_buf) return 0;
    if (frdc_pack_read_entry(pack, "M:index", 7, &cat->idx_buf, &cat->idx_len) != 0) return -1;
    if (cat->idx_len < 8u) return -1;
    uint32_t n_tools = frdc_rd_u32(cat->idx_buf);
    uint32_t sp_off  = frdc_rd_u32(cat->idx_buf + 4);
    if ((uint64_t)8u + (uint64_t)52u * n_tools != (uint64_t)sp_off || sp_off >= cat->idx_len) {
        return -1;
    }
    McpToolRec *recs = (McpToolRec *)calloc(n_tools ? n_tools : 1u, sizeof(McpToolRec));
    if (!recs) return -1;
    const char *pool = (const char *)(cat->idx_buf + sp_off);
    size_t pool_len = cat->idx_len - sp_off;

    for (uint32_t i = 0; i < n_tools; i++) {
        const uint8_t *p = cat->idx_buf + 8u + 52u * i;
        uint32_t noff = frdc_rd_u32(p);
        uint32_t nlen = frdc_rd_u32(p + 4);
        uint32_t foff = frdc_rd_u32(p + 8);
        uint32_t flen = frdc_rd_u32(p + 12);
        uint32_t scnt = frdc_rd_u32(p + 16);
        if (scnt > 4u || (uint64_t)noff + nlen >= pool_len || (uint64_t)foff + flen >= pool_len) {
            free(recs);
            return -1;
        }
        recs[i].name = pool + noff;
        recs[i].name_len = nlen;
        recs[i].family = pool + foff;
        recs[i].family_len = flen;
        recs[i].seg_count = scnt;
        for (uint32_t s = 0; s < 4u; s++) {
            uint32_t soff = frdc_rd_u32(p + 20u + 4u * s);
            if (soff >= pool_len) { free(recs); return -1; }
            recs[i].segs[s] = pool + soff;
        }
        recs[i].full_off    = frdc_rd_u32(p + 36);
        recs[i].full_len    = frdc_rd_u32(p + 40);
        recs[i].compact_off = frdc_rd_u32(p + 44);
        recs[i].compact_len = frdc_rd_u32(p + 48);
    }
    cat->recs = recs;
    cat->n_tools = n_tools;
    return 0;
}

static int catalog_ensure_payload(const FrdcPack *pack, McpCatalog *cat, int compact) {
    if (cat->payload_loaded) return 0;
    const char *key = compact ? "M:compact" : "M:full";
    if (frdc_pack_read_entry(pack, key, strlen(key), &cat->payload_buf, &cat->payload_len) != 0) {
        return -1;
    }
    cat->payload_loaded = 1;
    return 0;
}

typedef struct {
    char **items;
    size_t count;
} StrList;

static void sl_free(StrList *sl) {
    for (size_t i = 0; i < sl->count; i++) free(sl->items[i]);
    free(sl->items);
    sl->items = NULL;
    sl->count = 0;
}

static void sl_split_csv_lower(const char *csv, StrList *out) {
    out->items = NULL;
    out->count = 0;
    if (!csv || !*csv) return;
    const char *p = csv;
    while (*p) {
        const char *comma = strchr(p, ',');
        const char *end = comma ? comma : (p + strlen(p));
        while (p < end && isspace((unsigned char)*p)) p++;
        const char *q = end;
        while (q > p && isspace((unsigned char)q[-1])) q--;
        if (q > p) {
            size_t len = (size_t)(q - p);
            char *s = (char *)malloc(len + 1u);
            if (s) {
                for (size_t i = 0; i < len; i++) s[i] = (char)tolower((unsigned char)p[i]);
                s[len] = '\0';
                char **ni = (char **)realloc(out->items, (out->count + 1u) * sizeof(char *));
                if (ni) {
                    out->items = ni;
                    out->items[out->count++] = s;
                } else {
                    free(s);
                }
            }
        }
        if (!comma) break;
        p = comma + 1;
    }
}

static int mcp_path_matches(const McpToolRec *r, const char *prefix) {
    if (!prefix) return 1;
    /* Split prefix on ASCII whitespace into tokens */
    const char *toks[8];
    size_t tlens[8];
    size_t ntoks = 0;
    const char *p = prefix;
    while (*p) {
        while (*p && isspace((unsigned char)*p)) p++;
        if (!*p) break;
        const char *s = p;
        while (*p && !isspace((unsigned char)*p)) p++;
        if (ntoks < 8u) {
            toks[ntoks] = s;
            tlens[ntoks] = (size_t)(p - s);
            ntoks++;
        } else {
            return 0;
        }
    }
    if (ntoks == 0) return 1;

    /* 1. Direct leading slice of path */
    if (ntoks <= r->seg_count) {
        int match = 1;
        for (size_t i = 0; i < ntoks; i++) {
            if (strlen(r->segs[i]) != tlens[i] || memcmp(r->segs[i], toks[i], tlens[i]) != 0) {
                match = 0;
                break;
            }
        }
        if (match) return 1;
    }

    /* 2. verb family [rest...] */
    if (ntoks >= 2u && r->seg_count >= 1u &&
        strlen(r->segs[0]) == tlens[0] && memcmp(r->segs[0], toks[0], tlens[0]) == 0 &&
        r->family_len == tlens[1] && memcmp(r->family, toks[1], tlens[1]) == 0) {
        if (ntoks == 2u) return 1;
        size_t rest_n = ntoks - 2u;
        if (r->seg_count < 2u + rest_n) return 0;
        for (size_t i = 0; i < rest_n; i++) {
            if (strlen(r->segs[2u + i]) != tlens[2u + i] ||
                memcmp(r->segs[2u + i], toks[2u + i], tlens[2u + i]) != 0) {
                return 0;
            }
        }
        return 1;
    }
    return 0;
}

static void str_to_lower(const char *src, size_t len, char *dst, size_t cap) {
    size_t n = len < cap - 1u ? len : cap - 1u;
    for (size_t i = 0; i < n; i++) dst[i] = (char)tolower((unsigned char)src[i]);
    dst[n] = '\0';
}

static int mcp_matches_filters(const McpToolRec *r, const StrList *fam_pats, const StrList *tool_pats) {
    if (fam_pats->count > 0) {
        char p1[128] = "", p12[256] = "", fl[128] = "", pf[256] = "";
        if (r->seg_count >= 1u) str_to_lower(r->segs[0], strlen(r->segs[0]), p1, sizeof(p1));
        if (r->seg_count >= 2u) {
            char p2[128] = "";
            str_to_lower(r->segs[1], strlen(r->segs[1]), p2, sizeof(p2));
            snprintf(p12, sizeof(p12), "%s %s", p1, p2);
        }
        str_to_lower(r->family, r->family_len, fl, sizeof(fl));
        if (fl[0] == '\0') {
            snprintf(pf, sizeof(pf), "%s", p1);
        } else {
            snprintf(pf, sizeof(pf), "%s %s", p1, fl);
        }
        int matched = 0;
        for (size_t i = 0; i < fam_pats->count; i++) {
            const char *f = fam_pats->items[i];
            if (strcmp(f, p1) == 0 || strcmp(f, fl) == 0 ||
                strcmp(f, pf) == 0 || strcmp(f, p12) == 0) {
                matched = 1;
                break;
            }
        }
        if (!matched) return 0;
    }
    if (tool_pats->count > 0) {
        char tl[256];
        str_to_lower(r->name, r->name_len, tl, sizeof(tl));
        int matched = 0;
        for (size_t i = 0; i < tool_pats->count; i++) {
            const char *pat = tool_pats->items[i];
            size_t plen = strlen(pat);
            if (plen > 0 && pat[plen - 1] == '*') {
                if (strncmp(tl, pat, plen - 1) == 0) { matched = 1; break; }
            } else {
                if (strcmp(tl, pat) == 0) { matched = 1; break; }
            }
        }
        if (!matched) return 0;
    }
    return 1;
}

/* ── JSON-RPC 2.0 emission helpers ─────────────────────────────────────── */

static void rpc_append_id(McpBuf *b, yyjson_val *id_val) {
    if (!id_val || yyjson_is_null(id_val)) {
        mb_str(b, "null");
        return;
    }
    size_t len = 0;
    char *s = yyjson_val_write(id_val, 0, &len);
    if (s) {
        mb_mem(b, s, len);
        free(s);
    } else {
        mb_str(b, "null");
    }
}

static void rpc_send_error(yyjson_val *id_val, int code, const char *msg) {
    McpBuf b;
    mb_init(&b);
    char cbuf[32];
    snprintf(cbuf, sizeof(cbuf), "%d", code);
    mb_str(&b, "{\"jsonrpc\":\"2.0\",\"id\":");
    rpc_append_id(&b, id_val);
    mb_str(&b, ",\"error\":{\"code\":");
    mb_str(&b, cbuf);
    mb_str(&b, ",\"message\":");
    mb_json_str(&b, msg, strlen(msg));
    mb_str(&b, "}}\n");
    if (!b.oom) frdc_write_all_stdout((const uint8_t *)b.data, b.len);
    fflush(stdout);
    mb_free(&b);
}

/* ── State 1: Half-duplex lazy spawn & stdin pump ──────────────────────── */

#ifdef _WIN32
static wchar_t *mcp_utf8_to_wide(const char *s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    if (n <= 0) return NULL;
    wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
    if (!w) return NULL;
    if (MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n) <= 0) { free(w); return NULL; }
    return w;
}

static void append_win_quoted(McpBuf *b, const char *arg) {
    if (b->len > 0) mb_ch(b, ' ');
    mb_ch(b, '"');
    size_t n = strlen(arg);
    size_t bs = 0;
    for (size_t i = 0; i < n; i++) {
        if (arg[i] == '\\') {
            bs++;
        } else if (arg[i] == '"') {
            for (size_t j = 0; j < bs * 2u + 1u; j++) mb_ch(b, '\\');
            mb_ch(b, '"');
            bs = 0;
        } else {
            for (size_t j = 0; j < bs; j++) mb_ch(b, '\\');
            mb_ch(b, arg[i]);
            bs = 0;
        }
    }
    for (size_t j = 0; j < bs * 2u; j++) mb_ch(b, '\\');
    mb_ch(b, '"');
}

static int write_all_win_handle(HANDLE h, const uint8_t *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        DWORD chunk = (len - off > 65536u) ? 65536u : (DWORD)(len - off);
        DWORD written = 0;
        if (!WriteFile(h, buf + off, chunk, &written, NULL)) return -1;
        if (written == 0) return -1;
        off += (size_t)written;
    }
    return 0;
}

static int spawn_and_handoff(const char *exe_path,
                             int quiet, int no_color,
                             const char *families, const char *tools, int compact,
                             const char *first_line, size_t first_len,
                             LineReader *lr) {
    char core_path[MCP_PATH_MAX];
    int is_dev = 0;
    if (frdc_resolve_core_path(exe_path, core_path, sizeof(core_path), &is_dev) != 0 || is_dev) {
        fprintf(stderr, "Error: frdc-core.exe not found next to %s\n", exe_path);
        return 1;
    }

    SetEnvironmentVariableW(L"FRDC_MCP_SILENT_BANNER", L"1");
    SetEnvironmentVariableW(L"FRIEDMAN_MCP_SILENT_BANNER", L"1");
    SetEnvironmentVariableW(L"FRDC_NO_FASTPATH", L"1");

    SECURITY_ATTRIBUTES sa;
    memset(&sa, 0, sizeof(sa));
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;

    HANDLE pipe_r = NULL, pipe_w = NULL;
    if (!CreatePipe(&pipe_r, &pipe_w, &sa, 0)) return 1;
    SetHandleInformation(pipe_w, HANDLE_FLAG_INHERIT, 0);

    McpBuf cmd_u8;
    mb_init(&cmd_u8);
    append_win_quoted(&cmd_u8, core_path);
    if (quiet) append_win_quoted(&cmd_u8, "--quiet");
    if (no_color) append_win_quoted(&cmd_u8, "--no-color");
    append_win_quoted(&cmd_u8, "serve");
    append_win_quoted(&cmd_u8, "--mcp");
    if (families && families[0]) {
        append_win_quoted(&cmd_u8, "--families");
        append_win_quoted(&cmd_u8, families);
    }
    if (tools && tools[0]) {
        append_win_quoted(&cmd_u8, "--tools");
        append_win_quoted(&cmd_u8, tools);
    }
    if (compact) append_win_quoted(&cmd_u8, "--compact");

    wchar_t *wcore = mcp_utf8_to_wide(core_path);
    wchar_t *wcmd  = mcp_utf8_to_wide(cmd_u8.data ? cmd_u8.data : "");
    mb_free(&cmd_u8);
    if (!wcore || !wcmd) {
        free(wcore); free(wcmd);
        CloseHandle(pipe_r); CloseHandle(pipe_w);
        return 1;
    }

    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (job) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli;
        memset(&jeli, 0, sizeof(jeli));
        jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        SetInformationJobObject(job, JobObjectExtendedLimitInformation, &jeli, sizeof(jeli));
    }

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput  = pipe_r;
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError  = GetStdHandle(STD_ERROR_HANDLE);

    BOOL ok = CreateProcessW(wcore, wcmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi);
    free(wcore);
    free(wcmd);
    CloseHandle(pipe_r);
    if (!ok) {
        CloseHandle(pipe_w);
        if (job) CloseHandle(job);
        return 1;
    }
    if (job) AssignProcessToJobObject(job, pi.hProcess);

    /* Forward triggering line + '\n', buffered unread bytes, then pump raw stdin */
    int werr = write_all_win_handle(pipe_w, (const uint8_t *)first_line, first_len);
    const uint8_t nl = '\n';
    if (werr == 0) werr = write_all_win_handle(pipe_w, &nl, 1);
    if (werr == 0 && lr->rpos < lr->rlen) {
        werr = write_all_win_handle(pipe_w, lr->rbuf + lr->rpos, lr->rlen - lr->rpos);
        lr->rpos = lr->rlen;
    }
    if (werr == 0 && !lr->eof) {
        uint8_t pump[8192];
        for (;;) {
            ssize_t n = read_stdin_raw(pump, sizeof(pump));
            if (n <= 0) break;
            if (write_all_win_handle(pipe_w, pump, (size_t)n) != 0) break;
        }
    }
    CloseHandle(pipe_w);

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    if (job) CloseHandle(job);
    return (int)exit_code;
}
#else
static int write_all_fd(int fd, const uint8_t *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(fd, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (n == 0) return -1;
        off += (size_t)n;
    }
    return 0;
}

static int file_exists_posix(const char *p) {
    struct stat st;
    return (stat(p, &st) == 0 && S_ISREG(st.st_mode)) ? 1 : 0;
}

static int spawn_and_handoff(const char *exe_path,
                             int quiet, int no_color,
                             const char *families, const char *tools, int compact,
                             const char *first_line, size_t first_len,
                             LineReader *lr) {
    char core_path[MCP_PATH_MAX];
    int is_dev = 0;
    if (frdc_resolve_core_path(exe_path, core_path, sizeof(core_path), &is_dev) != 0) {
        fprintf(stderr, "Error: frdc-core not found next to %s\n", exe_path);
        return 1;
    }

    int pfd[2];
    if (pipe(pfd) != 0) return 1;

    pid_t pid = fork();
    if (pid < 0) {
        close(pfd[0]);
        close(pfd[1]);
        return 1;
    }
    if (pid == 0) {
        /* Child: bind stdin to pipe read-end, inherit stdout & stderr directly */
        close(pfd[1]);
        if (pfd[0] != STDIN_FILENO) {
            dup2(pfd[0], STDIN_FILENO);
            close(pfd[0]);
        }
        setenv("FRDC_MCP_SILENT_BANNER", "1", 1);
        setenv("FRIEDMAN_MCP_SILENT_BANNER", "1", 1);
        setenv("FRDC_NO_FASTPATH", "1", 1);

        const char *cargv[24];
        int k = 0;
        char proj_flag[MCP_PATH_MAX + 16];
        char script_path[MCP_PATH_MAX + 16];
        char sysimg_path[MCP_PATH_MAX + 32];
        char sysimg_flag[MCP_PATH_MAX + 48];

        if (!is_dev) {
            cargv[k++] = core_path;
        } else {
            snprintf(proj_flag, sizeof(proj_flag), "--project=%s", core_path);
            snprintf(script_path, sizeof(script_path), "%s/bin/frdc", core_path);
            snprintf(sysimg_path, sizeof(sysimg_path), "%s/frdc.so", core_path);
            int has_so = file_exists_posix(sysimg_path);
            cargv[k++] = "julia";
            cargv[k++] = proj_flag;
            if (has_so) {
                snprintf(sysimg_flag, sizeof(sysimg_flag), "--sysimage=%s", sysimg_path);
                cargv[k++] = sysimg_flag;
            }
            cargv[k++] = script_path;
            cargv[k++] = "--";
        }
        if (quiet) cargv[k++] = "--quiet";
        if (no_color) cargv[k++] = "--no-color";
        cargv[k++] = "serve";
        cargv[k++] = "--mcp";
        if (families && families[0]) {
            cargv[k++] = "--families";
            cargv[k++] = families;
        }
        if (tools && tools[0]) {
            cargv[k++] = "--tools";
            cargv[k++] = tools;
        }
        if (compact) cargv[k++] = "--compact";
        cargv[k] = NULL;

        if (!is_dev) {
            execv(core_path, (char *const *)cargv);
        } else {
            execvp("julia", (char *const *)cargv);
        }
        _exit(127);
    }

    /* Parent: close read end, forward triggering line + buffered unread bytes, pump stdin */
    close(pfd[0]);
    int werr = write_all_fd(pfd[1], (const uint8_t *)first_line, first_len);
    const uint8_t nl = '\n';
    if (werr == 0) werr = write_all_fd(pfd[1], &nl, 1);
    if (werr == 0 && lr->rpos < lr->rlen) {
        werr = write_all_fd(pfd[1], lr->rbuf + lr->rpos, lr->rlen - lr->rpos);
        lr->rpos = lr->rlen;
    }
    if (werr == 0 && !lr->eof) {
        uint8_t pump[8192];
        for (;;) {
            ssize_t n = read_stdin_raw(pump, sizeof(pump));
            if (n <= 0) break;
            if (write_all_fd(pfd[1], pump, (size_t)n) != 0) break;
        }
    }
    close(pfd[1]);

    int status = 0;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) return 1;
    }
    if (WIFEXITED(status)) return WEXITSTATUS(status);
    if (WIFSIGNALED(status)) return 128 + WTERMSIG(status);
    return 1;
}
#endif

/* ── Helper: extract optional integer from yyjson_val ──────────────────── */

static int yy_to_int(yyjson_val *v, int def_val) {
    if (!v || yyjson_is_null(v)) return def_val;
    if (yyjson_is_sint(v)) return (int)yyjson_get_sint(v);
    if (yyjson_is_uint(v)) return (int)yyjson_get_uint(v);
    if (yyjson_is_str(v)) {
        const char *s = yyjson_get_str(v);
        if (!s) return def_val;
        while (*s && isspace((unsigned char)*s)) s++;
        if (!*s) return def_val;
        char *end = NULL;
        long val = strtol(s, &end, 10);
        if (end == s) return def_val;
        while (*end && isspace((unsigned char)*end)) end++;
        if (*end != '\0') return def_val;
        return (int)val;
    }
    return def_val;
}

/* ── Main lazy MCP proxy entry point ───────────────────────────────────── */

int frdc_mcp_proxy_main(const FrdcPack *pack, const char *exe_path,
                        int argc, char **argv,
                        int quiet, int no_color,
                        const char *families, const char *tools, int compact) {
    (void)argc;
    (void)argv;

    FrdcSlice proto = { (const uint8_t *)"2024-11-05", 10 };
    FrdcSlice cli_name = { (const uint8_t *)"frdc", 4 };
    FrdcSlice cli_ver  = { (const uint8_t *)"0.0.0", 5 };
    frdc_pack_meta(pack, "mcp_protocol_version", &proto);
    frdc_pack_meta(pack, "cli_name", &cli_name);
    frdc_pack_meta(pack, "cli_version", &cli_ver);

    /* Emit stderr startup banner unless --quiet or FRDC_MCP_SILENT_BANNER=1 */
    const char *silent_env = frdc_env_get("FRDC_MCP_SILENT_BANNER", "FRIEDMAN_MCP_SILENT_BANNER");
    if (!quiet && !(silent_env && strcmp(silent_env, "1") == 0)) {
        McpBuf ban;
        mb_init(&ban);
        mb_str(&ban, "frdc MCP server on stdio (JSON-RPC 2.0, protocol ");
        mb_mem(&ban, proto.ptr, proto.len);
        mb_str(&ban, "); one line per message; Ctrl-D to stop\n");
        if (!ban.oom) frdc_write_all_stderr((const uint8_t *)ban.data, ban.len);
        mb_free(&ban);
    }

    StrList cli_fam_pats, cli_tool_pats;
    sl_split_csv_lower(families, &cli_fam_pats);
    sl_split_csv_lower(tools, &cli_tool_pats);

    McpCatalog cat;
    memset(&cat, 0, sizeof(cat));

    LineReader lr;
    lr_init(&lr);

    int exit_code = 0;
    const char *raw_line = NULL;
    size_t raw_len = 0;

    while (lr_next_line(&lr, &raw_line, &raw_len) == 1) {
        /* Trim leading/trailing ASCII whitespace */
        const char *s = raw_line;
        size_t slen = raw_len;
        while (slen > 0 && isspace((unsigned char)*s)) { s++; slen--; }
        while (slen > 0 && isspace((unsigned char)s[slen - 1])) { slen--; }
        if (slen == 0) continue;

        yyjson_doc *doc = yyjson_read(s, slen, 0);
        if (!doc) {
            rpc_send_error(NULL, -32700, "parse error");
            continue;
        }
        yyjson_val *root = yyjson_doc_get_root(doc);
        if (!root || !yyjson_is_obj(root)) {
            yyjson_doc_free(doc);
            rpc_send_error(NULL, -32700, "parse error");
            continue;
        }

        yyjson_val *id_val = yyjson_obj_get(root, "id");
        yyjson_val *meth_val = yyjson_obj_get(root, "method");
        const char *method = (meth_val && yyjson_is_str(meth_val)) ? yyjson_get_str(meth_val) : "";

        if (strcmp(method, "initialize") == 0) {
            McpBuf out;
            mb_init(&out);
            mb_str(&out, "{\"jsonrpc\":\"2.0\",\"id\":");
            rpc_append_id(&out, id_val);
            mb_str(&out, ",\"result\":{\"protocolVersion\":");
            mb_json_str(&out, (const char *)proto.ptr, proto.len);
            mb_str(&out, ",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":");
            mb_json_str(&out, (const char *)cli_name.ptr, cli_name.len);
            mb_str(&out, ",\"version\":");
            mb_json_str(&out, (const char *)cli_ver.ptr, cli_ver.len);
            mb_str(&out, "}}}\n");
            if (!out.oom) frdc_write_all_stdout((const uint8_t *)out.data, out.len);
            fflush(stdout);
            mb_free(&out);
        } else if (strncmp(method, "notifications/", 14) == 0) {
            /* Notifications receive no response */
        } else if (strcmp(method, "ping") == 0) {
            McpBuf out;
            mb_init(&out);
            mb_str(&out, "{\"jsonrpc\":\"2.0\",\"id\":");
            rpc_append_id(&out, id_val);
            mb_str(&out, ",\"result\":{}}\n");
            if (!out.oom) frdc_write_all_stdout((const uint8_t *)out.data, out.len);
            fflush(stdout);
            mb_free(&out);
        } else if (strcmp(method, "tools/list") == 0) {
            if (catalog_ensure_index(pack, &cat) != 0 ||
                catalog_ensure_payload(pack, &cat, compact) != 0) {
                /* Pack missing MCP blocks -> hand off cleanly to frdc-core */
                yyjson_doc_free(doc);
                fflush(stdout);
                exit_code = spawn_and_handoff(exe_path, quiet, no_color,
                                              families, tools, compact,
                                              raw_line, raw_len, &lr);
                break;
            }
            yyjson_val *params = yyjson_obj_get(root, "params");
            if (params && !yyjson_is_obj(params)) params = NULL;

            const char *prefix = "";
            const char *req_fam = families ? families : "";
            const char *req_tools = tools ? tools : "";
            yyjson_val *cursor_val = NULL;
            yyjson_val *limit_val = NULL;

            if (params) {
                yyjson_val *pv = yyjson_obj_get(params, "prefix");
                if (pv && yyjson_is_str(pv)) prefix = yyjson_get_str(pv);
                yyjson_val *fv = yyjson_obj_get(params, "families");
                if (fv && yyjson_is_str(fv)) req_fam = yyjson_get_str(fv);
                yyjson_val *tv = yyjson_obj_get(params, "tools");
                if (tv && yyjson_is_str(tv)) req_tools = yyjson_get_str(tv);
                cursor_val = yyjson_obj_get(params, "cursor");
                if (cursor_val && yyjson_is_null(cursor_val)) cursor_val = NULL;
                limit_val = yyjson_obj_get(params, "limit");
                if (limit_val && yyjson_is_null(limit_val)) limit_val = NULL;
            }

            StrList eff_fam, eff_tools;
            sl_split_csv_lower(req_fam, &eff_fam);
            sl_split_csv_lower(req_tools, &eff_tools);

            uint32_t *matched = (uint32_t *)malloc((cat.n_tools ? cat.n_tools : 1u) * sizeof(uint32_t));
            uint32_t n_matched = 0;
            if (matched) {
                for (uint32_t idx = 0; idx < cat.n_tools; idx++) {
                    if (mcp_path_matches(&cat.recs[idx], prefix) &&
                        mcp_matches_filters(&cat.recs[idx], &eff_fam, &eff_tools)) {
                        matched[n_matched++] = idx;
                    }
                }
            }

            uint32_t page_lo = 0, page_hi = n_matched;
            int has_next = 0;
            if (cursor_val != NULL || limit_val != NULL) {
                int off = yy_to_int(cursor_val, 0);
                if (off < 0) off = 0;
                int lim = yy_to_int(limit_val, 50);
                if (lim < 1) lim = 1;
                page_lo = (uint32_t)off;
                uint64_t end64 = (uint64_t)page_lo + (uint64_t)lim;
                page_hi = end64 < (uint64_t)n_matched ? (uint32_t)end64 : n_matched;
                if (page_lo >= n_matched) { page_lo = 0; page_hi = 0; }
                else if (page_hi < n_matched) { has_next = 1; }
            }

            McpBuf out;
            mb_init(&out);
            mb_str(&out, "{\"jsonrpc\":\"2.0\",\"id\":");
            rpc_append_id(&out, id_val);
            mb_str(&out, ",\"result\":{");
            if (has_next) {
                char ncbuf[32];
                snprintf(ncbuf, sizeof(ncbuf), "\"nextCursor\":\"%u\",", page_hi);
                mb_str(&out, ncbuf);
            }
            mb_str(&out, "\"tools\":[");
            for (uint32_t j = page_lo; j < page_hi; j++) {
                if (j > page_lo) mb_ch(&out, ',');
                const McpToolRec *r = &cat.recs[matched[j]];
                uint32_t off = compact ? r->compact_off : r->full_off;
                uint32_t len = compact ? r->compact_len : r->full_len;
                if ((uint64_t)off + (uint64_t)len <= (uint64_t)cat.payload_len) {
                    mb_mem(&out, cat.payload_buf + off, len);
                }
            }
            mb_str(&out, "]}}\n");
            if (!out.oom) frdc_write_all_stdout((const uint8_t *)out.data, out.len);
            fflush(stdout);
            mb_free(&out);
            free(matched);
            sl_free(&eff_fam);
            sl_free(&eff_tools);
        } else if (strcmp(method, "tools/call") == 0) {
            if (catalog_ensure_index(pack, &cat) != 0) {
                yyjson_doc_free(doc);
                fflush(stdout);
                exit_code = spawn_and_handoff(exe_path, quiet, no_color,
                                              families, tools, compact,
                                              raw_line, raw_len, &lr);
                break;
            }
            yyjson_val *params = yyjson_obj_get(root, "params");
            const char *tname = "";
            if (params && yyjson_is_obj(params)) {
                yyjson_val *nv = yyjson_obj_get(params, "name");
                if (nv && yyjson_is_str(nv)) tname = yyjson_get_str(nv);
            }
            int found = 0;
            size_t tlen = strlen(tname);
            for (uint32_t idx = 0; idx < cat.n_tools; idx++) {
                const McpToolRec *r = &cat.recs[idx];
                if (r->name_len == tlen && memcmp(r->name, tname, tlen) == 0 &&
                    mcp_matches_filters(r, &cli_fam_pats, &cli_tool_pats)) {
                    found = 1;
                    break;
                }
            }
            if (!found) {
                McpBuf em;
                mb_init(&em);
                mb_str(&em, "unknown tool: ");
                mb_str(&em, tname);
                rpc_send_error(id_val, -32602, em.data ? em.data : "unknown tool");
                mb_free(&em);
            } else {
                /* State 1: valid tools/call -> lazily spawn frdc-core & hand off! */
                yyjson_doc_free(doc);
                fflush(stdout);
                exit_code = spawn_and_handoff(exe_path, quiet, no_color,
                                              families, tools, compact,
                                              raw_line, raw_len, &lr);
                break;
            }
        } else {
            if (id_val && !yyjson_is_null(id_val)) {
                McpBuf em;
                mb_init(&em);
                mb_str(&em, "method not found: ");
                mb_str(&em, method);
                rpc_send_error(id_val, -32601, em.data ? em.data : "method not found");
                mb_free(&em);
            }
        }

        yyjson_doc_free(doc);
    }

    lr_free(&lr);
    catalog_free(&cat);
    sl_free(&cli_fam_pats);
    sl_free(&cli_tool_pats);
    return exit_code;
}
