/* Friedman-cli (frdc) — Pure C99 thin CLI front-end ([FASTPATH-W2] #294)
 * Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
 * SPDX-License-Identifier: GPL-3.0-only
 *
 * Serves static metadata commands (<10 ms) directly from ../share/frdc/cli_cache.bin
 * (FRDCACHE v1) and fails open to sibling bin/frdc-core(.exe) (or `julia --project`
 * in dev trees) for compute commands or any pack/argument anomaly.
 */

#ifndef _WIN32
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#endif

#include "frdc_thin.h"

#define MINIZ_TINFL_IMPLEMENTATION
#include "miniz_tinfl.h"

#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <sys/stat.h>
#ifndef ENABLE_VIRTUAL_TERMINAL_PROCESSING
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#endif
#define FRDC_PATH_SEP '\\'
#else
#include <dirent.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif
#define FRDC_PATH_SEP '/'
#endif

#define FRDC_PATH_MAX 4096

/* ── IEEE CRC32 ────────────────────────────────────────────────────────── */

static uint32_t g_crc32_table[256];
static int g_crc32_init = 0;

static void crc32_init_table(void) {
    for (uint32_t i = 0; i < 256u; i++) {
        uint32_t c = i;
        for (int j = 0; j < 8; j++) {
            c = (c & 1u) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
        }
        g_crc32_table[i] = c;
    }
    g_crc32_init = 1;
}

uint32_t frdc_crc32(const uint8_t *data, size_t len) {
    if (!g_crc32_init) crc32_init_table();
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++) {
        c = g_crc32_table[(c ^ data[i]) & 0xFFu] ^ (c >> 8);
    }
    return c ^ 0xFFFFFFFFu;
}

/* ── Platform console / IO / env ───────────────────────────────────────── */

void frdc_setup_console(void) {
#ifdef _WIN32
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
    _setmode(_fileno(stdout), _O_BINARY);
    _setmode(_fileno(stderr), _O_BINARY);
    HANDLE h_out = GetStdHandle(STD_OUTPUT_HANDLE);
    if (h_out != INVALID_HANDLE_VALUE && h_out != NULL) {
        DWORD mode = 0;
        if (GetConsoleMode(h_out, &mode)) {
            SetConsoleMode(h_out, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        }
    }
    HANDLE h_err = GetStdHandle(STD_ERROR_HANDLE);
    if (h_err != INVALID_HANDLE_VALUE && h_err != NULL) {
        DWORD mode = 0;
        if (GetConsoleMode(h_err, &mode)) {
            SetConsoleMode(h_err, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
        }
    }
#else
    signal(SIGPIPE, SIG_IGN);
#endif
}

int frdc_stdout_is_tty(void) {
#ifdef _WIN32
    DWORD mode = 0;
    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    return (h != INVALID_HANDLE_VALUE && h != NULL && GetConsoleMode(h, &mode)) ? 1 : 0;
#else
    return isatty(STDOUT_FILENO) ? 1 : 0;
#endif
}

int frdc_stderr_is_tty(void) {
#ifdef _WIN32
    DWORD mode = 0;
    HANDLE h = GetStdHandle(STD_ERROR_HANDLE);
    return (h != INVALID_HANDLE_VALUE && h != NULL && GetConsoleMode(h, &mode)) ? 1 : 0;
#else
    return isatty(STDERR_FILENO) ? 1 : 0;
#endif
}

const char *frdc_env_get(const char *primary, const char *legacy) {
    const char *v = primary ? getenv(primary) : NULL;
    if (v && v[0] != '\0') return v;
    v = legacy ? getenv(legacy) : NULL;
    if (v && v[0] != '\0') return v;
    return NULL;
}

void frdc_write_all_stdout(const uint8_t *buf, size_t len) {
    if (!buf || len == 0) return;
#ifdef _WIN32
    size_t off = 0;
    while (off < len) {
        size_t chunk = len - off;
        size_t n = fwrite(buf + off, 1, chunk, stdout);
        if (n == 0) {
            if (ferror(stdout)) exit(0);
            break;
        }
        off += n;
    }
    fflush(stdout);
#else
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(STDOUT_FILENO, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) continue;
            if (errno == EPIPE) _exit(0);
            _exit(1);
        }
        if (n == 0) break;
        off += (size_t)n;
    }
#endif
}

void frdc_write_all_stderr(const uint8_t *buf, size_t len) {
    if (!buf || len == 0) return;
#ifdef _WIN32
    fwrite(buf, 1, len, stderr);
    fflush(stderr);
#else
    size_t off = 0;
    while (off < len) {
        ssize_t n = write(STDERR_FILENO, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) continue;
            break;
        }
        if (n == 0) break;
        off += (size_t)n;
    }
#endif
}

/* Strip ANSI CSI SGR sequences (\x1b[...m) when !use_color */
void frdc_emit_help_bytes(const uint8_t *buf, size_t len, int use_color) {
    if (use_color) {
        frdc_write_all_stdout(buf, len);
        return;
    }
    uint8_t *out = (uint8_t *)malloc(len ? len : 1);
    if (!out) {
        frdc_write_all_stdout(buf, len);
        return;
    }
    size_t j = 0;
    size_t i = 0;
    while (i < len) {
        if (buf[i] == 0x1b && i + 1 < len && buf[i + 1] == '[') {
            size_t k = i + 2;
            while (k < len && ((buf[k] >= '0' && buf[k] <= '9') || buf[k] == ';')) {
                k++;
            }
            if (k < len && buf[k] == 'm') {
                i = k + 1;
                continue;
            }
        }
        out[j++] = buf[i++];
    }
    frdc_write_all_stdout(out, j);
    free(out);
}

/* ── Path helpers & self-location ──────────────────────────────────────── */

static int path_exists_file(const char *p) {
#ifdef _WIN32
    DWORD attr = GetFileAttributesA(p);
    return (attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY)) ? 1 : 0;
#else
    struct stat st;
    return (stat(p, &st) == 0 && S_ISREG(st.st_mode)) ? 1 : 0;
#endif
}

static int strip_last_component(char *path) {
    size_t len = strlen(path);
    while (len > 1 && (path[len - 1] == '/' || path[len - 1] == '\\')) {
        path[--len] = '\0';
    }
    char *s1 = strrchr(path, '/');
    char *s2 = strrchr(path, '\\');
    char *sep = (s1 > s2) ? s1 : s2;
    if (!sep) return -1;
    if (sep == path) {
        sep[1] = '\0';
    } else {
        *sep = '\0';
    }
    return 0;
}

int frdc_get_self_exe(char *buf, size_t cap) {
    if (!buf || cap < 16) return -1;
#ifdef _WIN32
    wchar_t wbuf[FRDC_PATH_MAX];
    DWORD n = GetModuleFileNameW(NULL, wbuf, (DWORD)(sizeof(wbuf) / sizeof(wbuf[0])));
    if (n == 0 || n >= (DWORD)(sizeof(wbuf) / sizeof(wbuf[0]))) return -1;
    int u8len = WideCharToMultiByte(CP_UTF8, 0, wbuf, -1, buf, (int)cap, NULL, NULL);
    return (u8len > 0) ? 0 : -1;
#elif defined(__APPLE__)
    uint32_t sz = (uint32_t)cap;
    char raw[FRDC_PATH_MAX];
    uint32_t rsz = sizeof(raw);
    if (_NSGetExecutablePath(raw, &rsz) != 0) return -1;
    char resolved[PATH_MAX];
    if (realpath(raw, resolved) == NULL) {
        if (strlen(raw) >= cap) return -1;
        strcpy(buf, raw);
        return 0;
    }
    (void)sz;
    if (strlen(resolved) >= cap) return -1;
    strcpy(buf, resolved);
    return 0;
#else
    ssize_t n = readlink("/proc/self/exe", buf, cap - 1);
    if (n <= 0 || (size_t)n >= cap) return -1;
    buf[n] = '\0';
    return 0;
#endif
}

int frdc_resolve_core_path(const char *exe_path, char *out_buf, size_t out_cap, int *is_dev_out) {
    if (is_dev_out) *is_dev_out = 0;
    char dir[FRDC_PATH_MAX];
    if (strlen(exe_path) >= sizeof(dir)) return -1;
    strcpy(dir, exe_path);
    if (strip_last_component(dir) != 0) return -1;

#ifdef _WIN32
    int nw = snprintf(out_buf, out_cap, "%s\\frdc-core.exe", dir);
#else
    int nw = snprintf(out_buf, out_cap, "%s/frdc-core", dir);
#endif
    if (nw > 0 && (size_t)nw < out_cap && path_exists_file(out_buf)) {
        return 0;
    }

    /* Check dev/source layout: parent has Project.toml and bin/frdc */
    char root[FRDC_PATH_MAX];
    strcpy(root, dir);
    if (strip_last_component(root) == 0) {
        char proj[FRDC_PATH_MAX];
        char script[FRDC_PATH_MAX];
        int np = snprintf(proj, sizeof(proj), "%s%cProject.toml", root, FRDC_PATH_SEP);
        int ns = snprintf(script, sizeof(script), "%s%cbin%cfrdc", root, FRDC_PATH_SEP, FRDC_PATH_SEP);
        if (np > 0 && (size_t)np < sizeof(proj) && path_exists_file(proj) &&
            ns > 0 && (size_t)ns < sizeof(script) && path_exists_file(script)) {
            if (is_dev_out) *is_dev_out = 1;
            if (strlen(root) < out_cap) {
                strcpy(out_buf, root);
                return 0;
            }
        }
    }
    return -1;
}

static int resolve_pack_path(const char *exe_path, char *out_buf, size_t out_cap) {
    const char *env_p = frdc_env_get("FRDC_CACHE_PATH", "FRIEDMAN_CACHE_PATH");
    if (env_p) {
        if (strlen(env_p) >= out_cap) return -1;
        strcpy(out_buf, env_p);
        return 0;
    }
    char root[FRDC_PATH_MAX];
    if (strlen(exe_path) >= sizeof(root)) return -1;
    strcpy(root, exe_path);
    if (strip_last_component(root) != 0) return -1; /* bin */
    if (strip_last_component(root) != 0) return -1; /* app root */
#ifdef _WIN32
    int n = snprintf(out_buf, out_cap, "%s\\share\\frdc\\cli_cache.bin", root);
#else
    int n = snprintf(out_buf, out_cap, "%s/share/frdc/cli_cache.bin", root);
#endif
    return (n > 0 && (size_t)n < out_cap) ? 0 : -1;
}

#ifndef _WIN32
static int tree_newer_than(const char *dir_path, uint64_t stamp, int depth) {
    if (depth > 8) return 0;
    DIR *d = opendir(dir_path);
    if (!d) return 0;
    struct dirent *de;
    char child[FRDC_PATH_MAX];
    while ((de = readdir(d)) != NULL) {
        if (de->d_name[0] == '.' &&
            (de->d_name[1] == '\0' || (de->d_name[1] == '.' && de->d_name[2] == '\0'))) {
            continue;
        }
        int n = snprintf(child, sizeof(child), "%s/%s", dir_path, de->d_name);
        if (n <= 0 || (size_t)n >= sizeof(child)) continue;
        struct stat st;
        if (stat(child, &st) != 0) continue;
        if (S_ISDIR(st.st_mode)) {
            if (tree_newer_than(child, stamp, depth + 1)) {
                closedir(d);
                return 1;
            }
        } else if (S_ISREG(st.st_mode)) {
            if ((uint64_t)st.st_mtime > stamp) {
                closedir(d);
                return 1;
            }
        }
    }
    closedir(d);
    return 0;
}

static int dev_pack_is_stale(const char *repo_root, uint64_t stamp) {
    if (stamp == 0) return 0;
    char p[FRDC_PATH_MAX];
    struct stat st;
    if (snprintf(p, sizeof(p), "%s/Project.toml", repo_root) < (int)sizeof(p) &&
        stat(p, &st) == 0 && (uint64_t)st.st_mtime > stamp) {
        return 1;
    }
    if (snprintf(p, sizeof(p), "%s/src", repo_root) < (int)sizeof(p) &&
        tree_newer_than(p, stamp, 0)) {
        return 1;
    }
    return 0;
}
#endif

/* ── FRDCACHE v1 loader & lookups ──────────────────────────────────────── */

static int pool_slice(const FrdcPack *p, uint32_t off, uint32_t len, FrdcSlice *out) {
    if ((uint64_t)off + (uint64_t)len >= (uint64_t)p->key_pool_len) return -1;
    const uint8_t *base = p->buf + p->key_pool_off + off;
    if (base[len] != 0) return -1;
    out->ptr = base;
    out->len = (size_t)len;
    return 0;
}

int frdc_pack_load(FrdcPack *p, const char *path) {
    memset(p, 0, sizeof(*p));
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    if (fseek(f, 0, SEEK_END) != 0) { fclose(f); return -1; }
    long sz = ftell(f);
    if (sz < (long)FRDCACHE_HEADER_SIZE || sz > 64L * 1024L * 1024L) {
        fclose(f);
        return -1;
    }
    if (fseek(f, 0, SEEK_SET) != 0) { fclose(f); return -1; }
    uint8_t *buf = (uint8_t *)malloc((size_t)sz);
    if (!buf) { fclose(f); return -1; }
    if (fread(buf, 1, (size_t)sz, f) != (size_t)sz) {
        free(buf);
        fclose(f);
        return -1;
    }
    fclose(f);

    if (memcmp(buf, FRDCACHE_MAGIC_STR, FRDCACHE_MAGIC_LEN) != 0) {
        free(buf);
        return -1;
    }
    uint32_t version    = frdc_rd_u32(buf + 8);
    uint32_t flags      = frdc_rd_u32(buf + 12);
    uint32_t header_crc = frdc_rd_u32(buf + 16);
    if (version != FRDCACHE_VERSION) {
        free(buf);
        return -1;
    }

    uint32_t n_meta       = frdc_rd_u32(buf + 20);
    uint32_t n_nodes      = frdc_rd_u32(buf + 24);
    uint32_t n_repls      = frdc_rd_u32(buf + 28);
    uint32_t n_blocks     = frdc_rd_u32(buf + 32);
    uint32_t n_entries    = frdc_rd_u32(buf + 36);
    uint32_t meta_off     = frdc_rd_u32(buf + 40);
    uint32_t meta_len     = frdc_rd_u32(buf + 44);
    uint32_t node_off     = frdc_rd_u32(buf + 48);
    uint32_t node_len     = frdc_rd_u32(buf + 52);
    uint32_t repl_off     = frdc_rd_u32(buf + 56);
    uint32_t repl_len     = frdc_rd_u32(buf + 60);
    uint32_t block_off    = frdc_rd_u32(buf + 64);
    uint32_t block_len    = frdc_rd_u32(buf + 68);
    uint32_t entry_off    = frdc_rd_u32(buf + 72);
    uint32_t entry_len    = frdc_rd_u32(buf + 76);
    uint32_t key_pool_off = frdc_rd_u32(buf + 80);
    uint32_t key_pool_len = frdc_rd_u32(buf + 84);
    uint64_t source_stamp = frdc_rd_u64(buf + 88);

    uint64_t index_end = (uint64_t)key_pool_off + (uint64_t)key_pool_len;
    if (index_end > (uint64_t)sz || index_end < FRDCACHE_HEADER_SIZE ||
        (uint64_t)meta_off  + (uint64_t)meta_len  > index_end ||
        (uint64_t)node_off  + (uint64_t)node_len  > index_end ||
        (uint64_t)repl_off  + (uint64_t)repl_len  > index_end ||
        (uint64_t)block_off + (uint64_t)block_len > index_end ||
        (uint64_t)entry_off + (uint64_t)entry_len > index_end ||
        meta_len  != n_meta    * 16u ||
        node_len  != n_nodes   * 12u ||
        repl_len  != n_repls   * 16u ||
        block_len != n_blocks  * 16u ||
        entry_len != n_entries * 20u ||
        key_pool_len == 0) {
        free(buf);
        return -1;
    }

    uint32_t actual_crc = frdc_crc32(buf + 20, (size_t)(index_end - 20));
    if (actual_crc != header_crc) {
        free(buf);
        return -1;
    }

    p->buf          = buf;
    p->buf_len      = (size_t)sz;
    p->version      = version;
    p->flags        = flags;
    p->n_meta       = n_meta;
    p->n_nodes      = n_nodes;
    p->n_repls      = n_repls;
    p->n_blocks     = n_blocks;
    p->n_entries    = n_entries;
    p->meta_off     = meta_off;
    p->node_off     = node_off;
    p->repl_off     = repl_off;
    p->block_off    = block_off;
    p->entry_off    = entry_off;
    p->key_pool_off = key_pool_off;
    p->key_pool_len = key_pool_len;
    p->index_end    = (uint32_t)index_end;
    p->source_stamp = source_stamp;
    return 0;
}

void frdc_pack_free(FrdcPack *p) {
    if (p && p->buf) {
        free(p->buf);
        memset(p, 0, sizeof(*p));
    }
}

static int slice_cmp(const uint8_t *a, size_t alen, const uint8_t *b, size_t blen) {
    size_t m = alen < blen ? alen : blen;
    int r = m ? memcmp(a, b, m) : 0;
    if (r != 0) return r;
    return (alen < blen) ? -1 : ((alen > blen) ? 1 : 0);
}

int frdc_pack_meta(const FrdcPack *p, const char *key, FrdcSlice *out) {
    size_t klen = strlen(key);
    uint32_t lo = 0, hi = p->n_meta;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2u;
        const uint8_t *rec = p->buf + p->meta_off + mid * 16u;
        FrdcSlice k;
        if (pool_slice(p, frdc_rd_u32(rec), frdc_rd_u32(rec + 4), &k) != 0) return -1;
        int c = slice_cmp(k.ptr, k.len, (const uint8_t *)key, klen);
        if (c == 0) {
            return pool_slice(p, frdc_rd_u32(rec + 8), frdc_rd_u32(rec + 12), out);
        }
        if (c < 0) lo = mid + 1u; else hi = mid;
    }
    return -1;
}

int frdc_pack_node(const FrdcPack *p, const char *path, size_t path_len, uint32_t *flags_out) {
    uint32_t lo = 0, hi = p->n_nodes;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2u;
        const uint8_t *rec = p->buf + p->node_off + mid * 12u;
        FrdcSlice k;
        if (pool_slice(p, frdc_rd_u32(rec), frdc_rd_u32(rec + 4), &k) != 0) return -1;
        int c = slice_cmp(k.ptr, k.len, (const uint8_t *)path, path_len);
        if (c == 0) {
            if (flags_out) *flags_out = frdc_rd_u32(rec + 8);
            return 0;
        }
        if (c < 0) lo = mid + 1u; else hi = mid;
    }
    return -1;
}

int frdc_pack_repl(const FrdcPack *p, const char *old_path, size_t old_len, FrdcSlice *new_out) {
    uint32_t lo = 0, hi = p->n_repls;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2u;
        const uint8_t *rec = p->buf + p->repl_off + mid * 16u;
        FrdcSlice k;
        if (pool_slice(p, frdc_rd_u32(rec), frdc_rd_u32(rec + 4), &k) != 0) return -1;
        int c = slice_cmp(k.ptr, k.len, (const uint8_t *)old_path, old_len);
        if (c == 0) {
            return pool_slice(p, frdc_rd_u32(rec + 8), frdc_rd_u32(rec + 12), new_out);
        }
        if (c < 0) lo = mid + 1u; else hi = mid;
    }
    return -1;
}

int frdc_pack_read_entry(const FrdcPack *p, const char *key, size_t key_len,
                         uint8_t **out_buf, size_t *out_len) {
    uint32_t lo = 0, hi = p->n_entries;
    while (lo < hi) {
        uint32_t mid = lo + (hi - lo) / 2u;
        const uint8_t *rec = p->buf + p->entry_off + mid * 20u;
        FrdcSlice k;
        if (pool_slice(p, frdc_rd_u32(rec), frdc_rd_u32(rec + 4), &k) != 0) return -1;
        int c = slice_cmp(k.ptr, k.len, (const uint8_t *)key, key_len);
        if (c == 0) {
            uint32_t bidx = frdc_rd_u32(rec + 8);
            uint32_t roff = frdc_rd_u32(rec + 12);
            uint32_t rlen = frdc_rd_u32(rec + 16);
            if (bidx >= p->n_blocks) return -1;
            const uint8_t *brec = p->buf + p->block_off + bidx * 16u;
            uint32_t foff = frdc_rd_u32(brec);
            uint32_t clen = frdc_rd_u32(brec + 4);
            uint32_t blen = frdc_rd_u32(brec + 8);
            uint32_t bcrc = frdc_rd_u32(brec + 12);
            if (foff < p->index_end || (uint64_t)foff + (uint64_t)clen > (uint64_t)p->buf_len) {
                return -1;
            }
            if ((uint64_t)roff + (uint64_t)rlen > (uint64_t)blen) return -1;

            uint8_t *raw = (uint8_t *)malloc(blen ? (size_t)blen : 1);
            if (!raw) return -1;
            size_t got = tinfl_decompress_mem_to_mem(
                raw, (size_t)blen, p->buf + foff, (size_t)clen,
                TINFL_FLAG_PARSE_ZLIB_HEADER | TINFL_FLAG_USING_NON_WRAPPING_OUTPUT_BUF);
            if (got != (size_t)blen) {
                free(raw);
                return -1;
            }
            if (frdc_crc32(raw, (size_t)blen) != bcrc) {
                free(raw);
                return -1;
            }
            uint8_t *slice = (uint8_t *)malloc((size_t)rlen + 1u);
            if (!slice) {
                free(raw);
                return -1;
            }
            if (rlen > 0) memcpy(slice, raw + roff, (size_t)rlen);
            slice[rlen] = '\0';
            free(raw);
            *out_buf = slice;
            *out_len = (size_t)rlen;
            return 0;
        }
        if (c < 0) lo = mid + 1u; else hi = mid;
    }
    return -1;
}

/* ── Cross-platform handoff to frdc-core (or julia --project in dev) ───── */

#ifdef _WIN32
static BOOL WINAPI win_ctrl_handler(DWORD ctrl_type) {
    if (ctrl_type == CTRL_C_EVENT || ctrl_type == CTRL_BREAK_EVENT) {
        return TRUE; /* let child handle Ctrl-C cleanly */
    }
    return FALSE;
}

static wchar_t *utf8_to_wide(const char *s) {
    int n = MultiByteToWideChar(CP_UTF8, 0, s, -1, NULL, 0);
    if (n <= 0) return NULL;
    wchar_t *w = (wchar_t *)malloc((size_t)n * sizeof(wchar_t));
    if (!w) return NULL;
    if (MultiByteToWideChar(CP_UTF8, 0, s, -1, w, n) <= 0) {
        free(w);
        return NULL;
    }
    return w;
}

static wchar_t *build_win_cmdline(const wchar_t *core_wpath) {
    const wchar_t *raw = GetCommandLineW();
    if (!raw) return NULL;
    /* Skip argv[0] in raw command line, preserving exact quoting of arguments */
    const wchar_t *p = raw;
    while (*p == L' ' || *p == L'\t') p++;
    if (*p == L'"') {
        p++;
        while (*p && *p != L'"') p++;
        if (*p == L'"') p++;
    } else {
        while (*p && *p != L' ' && *p != L'\t') p++;
    }
    size_t core_len = wcslen(core_wpath);
    size_t tail_len = wcslen(p);
    wchar_t *cmd = (wchar_t *)malloc((core_len + tail_len + 4) * sizeof(wchar_t));
    if (!cmd) return NULL;
    cmd[0] = L'"';
    memcpy(cmd + 1, core_wpath, core_len * sizeof(wchar_t));
    cmd[1 + core_len] = L'"';
    memcpy(cmd + 2 + core_len, p, (tail_len + 1) * sizeof(wchar_t));
    return cmd;
}

int frdc_exec_core(const char *exe_path, int argc, char **argv) {
    (void)argc;
    (void)argv;
    char core_path[FRDC_PATH_MAX];
    int is_dev = 0;
    if (frdc_resolve_core_path(exe_path, core_path, sizeof(core_path), &is_dev) != 0) {
        fprintf(stderr, "Error: frdc-core.exe not found next to %s\n", exe_path);
        return 1;
    }
    if (is_dev) {
        fprintf(stderr, "Error: dev fallback via julia is not supported on Windows thin wrapper without frdc-core.exe\n");
        return 1;
    }
    wchar_t *wcore = utf8_to_wide(core_path);
    if (!wcore) return 1;
    wchar_t *wcmd = build_win_cmdline(wcore);
    if (!wcmd) { free(wcore); return 1; }

    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (job) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli;
        memset(&jeli, 0, sizeof(jeli));
        jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        SetInformationJobObject(job, JobObjectExtendedLimitInformation, &jeli, sizeof(jeli));
    }

    SetConsoleCtrlHandler(win_ctrl_handler, TRUE);

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);

    BOOL ok = CreateProcessW(wcore, wcmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi);
    free(wcmd);
    free(wcore);
    if (!ok) {
        if (job) CloseHandle(job);
        fprintf(stderr, "Error: failed to launch %s (Win32 error %lu)\n", core_path, (unsigned long)GetLastError());
        return 1;
    }
    if (job) AssignProcessToJobObject(job, pi.hProcess);

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    if (job) CloseHandle(job);
    return (int)exit_code;
}
#else
int frdc_exec_core(const char *exe_path, int argc, char **argv) {
    char core_path[FRDC_PATH_MAX];
    int is_dev = 0;
    if (frdc_resolve_core_path(exe_path, core_path, sizeof(core_path), &is_dev) != 0) {
        fprintf(stderr, "Error: frdc-core not found next to %s\n", exe_path);
        return 1;
    }
    if (!is_dev) {
        char **nargv = (char **)malloc(((size_t)argc + 1u) * sizeof(char *));
        if (!nargv) return 1;
        nargv[0] = core_path;
        for (int i = 1; i < argc; i++) nargv[i] = argv[i];
        nargv[argc] = NULL;
        execv(core_path, nargv);
        fprintf(stderr, "Error: execv(%s) failed: %s\n", core_path, strerror(errno));
        free(nargv);
        return 1;
    }

    /* Dev/source fallback: execvp("julia", ["--project=<root>", ...]) */
    char proj_flag[FRDC_PATH_MAX + 16];
    char script_path[FRDC_PATH_MAX + 16];
    char sysimg_path[FRDC_PATH_MAX + 32];
    char sysimg_flag[FRDC_PATH_MAX + 48];
    snprintf(proj_flag, sizeof(proj_flag), "--project=%s", core_path);
    snprintf(script_path, sizeof(script_path), "%s/bin/frdc", core_path);
    snprintf(sysimg_path, sizeof(sysimg_path), "%s/frdc.so", core_path);
    int has_sysimg = path_exists_file(sysimg_path);
    if (!has_sysimg) {
        snprintf(sysimg_path, sizeof(sysimg_path), "%s/friedman.so", core_path);
        has_sysimg = path_exists_file(sysimg_path);
    }

    size_t extra = has_sysimg ? 5u : 4u;
    char **jargv = (char **)malloc(((size_t)argc + extra + 1u) * sizeof(char *));
    if (!jargv) return 1;
    size_t k = 0;
    jargv[k++] = (char *)"julia";
    jargv[k++] = proj_flag;
    if (has_sysimg) {
        snprintf(sysimg_flag, sizeof(sysimg_flag), "--sysimage=%s", sysimg_path);
        jargv[k++] = sysimg_flag;
    }
    jargv[k++] = script_path;
    jargv[k++] = (char *)"--";
    for (int i = 1; i < argc; i++) jargv[k++] = argv[i];
    jargv[k] = NULL;
    execvp("julia", jargv);
    fprintf(stderr, "Error: execvp(julia) failed: %s\n", strerror(errno));
    free(jargv);
    return 1;
}
#endif

/* ── Global flag pre-scan & command probing (mirrors src/io.jl) ────────── */

static int streq_ci(const char *a, const char *b) {
    while (*a && *b) {
        if (tolower((unsigned char)*a) != tolower((unsigned char)*b)) return 0;
        a++; b++;
    }
    return (*a == '\0' && *b == '\0');
}

static int parse_strict_i64(const char *s, int64_t *out) {
    if (!s || !*s) return -1;
    while (*s == ' ' || *s == '\t' || *s == '\n' || *s == '\r') s++;
    if (!*s) return -1;
    char *end = NULL;
    errno = 0;
    long long v = strtoll(s, &end, 10);
    if (errno != 0 || end == s) return -1;
    while (*end == ' ' || *end == '\t' || *end == '\n' || *end == '\r') end++;
    if (*end != '\0') return -1;
    *out = (int64_t)v;
    return 0;
}

typedef struct {
    char cmd_path[256];
    size_t cmd_path_len;
    int has_leaf;
    uint32_t leaf_flags;
    int first_cmd_idx;
} ProbeResult;

static void probe_target_command(const FrdcPack *pack, int argc, char **argv, int stop_idx,
                                 ProbeResult *res) {
    memset(res, 0, sizeof(*res));
    res->first_cmd_idx = stop_idx;
    int i = 1;
    while (i < stop_idx) {
        const char *tok = argv[i];
        if (strcmp(tok, "--quiet") == 0 || strcmp(tok, "--no-color") == 0 ||
            strcmp(tok, "--json") == 0 || strcmp(tok, "--compact") == 0 ||
            strncmp(tok, "--seed=", 7) == 0 ||
            (strcmp(tok, "-q") == 0 && res->cmd_path_len == 0)) {
            i++;
        } else if (strcmp(tok, "--seed") == 0) {
            i += 2;
        } else if (tok[0] == '-') {
            i++;
        } else {
            if (res->cmd_path_len == 0 && strcmp(tok, "schema") == 0) {
                if (res->first_cmd_idx == stop_idx) res->first_cmd_idx = i;
                strcpy(res->cmd_path, "schema");
                res->cmd_path_len = 6;
                return;
            }
            char cand[256];
            int n = res->cmd_path_len == 0
                ? snprintf(cand, sizeof(cand), "%s", tok)
                : snprintf(cand, sizeof(cand), "%s %s", res->cmd_path, tok);
            if (n <= 0 || (size_t)n >= sizeof(cand)) break;
            uint32_t fl = 0;
            if (frdc_pack_node(pack, cand, (size_t)n, &fl) != 0) {
                break;
            }
            if (res->first_cmd_idx == stop_idx) res->first_cmd_idx = i;
            memcpy(res->cmd_path, cand, (size_t)n + 1);
            res->cmd_path_len = (size_t)n;
            if (fl & FRDC_NODE_IS_LEAF) {
                res->has_leaf = 1;
                res->leaf_flags = fl;
                return;
            }
            i++;
        }
    }
    (void)argc;
}

static const char *explicit_format_in(char **args, int stop_idx) {
    const char *fmt = NULL;
    for (int i = 0; i < stop_idx; i++) {
        const char *tok = args[i];
        if (strncmp(tok, "--format=", 9) == 0) {
            fmt = tok + 9;
        } else if (strncmp(tok, "-f=", 3) == 0) {
            fmt = tok + 3;
        } else if ((strcmp(tok, "--format") == 0 || strcmp(tok, "-f") == 0) && i + 1 < stop_idx) {
            fmt = args[i + 1];
        }
    }
    return fmt;
}

static int wants_help_in(char **args, int start, int n) {
    for (int i = start; i < n; i++) {
        if (strcmp(args[i], "--help") == 0 || strcmp(args[i], "-h") == 0) return 1;
    }
    return 0;
}

static int looks_like_value(const char *s) {
    if (!s || !*s) return 1;
    if (s[0] != '-') return 1;
    /* Negative numbers like -1 or -0.5 look like values */
    if (s[1] >= '0' && s[1] <= '9') return 1;
    if (s[1] == '.' && s[2] >= '0' && s[2] <= '9') return 1;
    return 0;
}

/* ── Growable buffer, RFC 8259 JSON string escaper, clock & envelopes ──── */

typedef struct {
    char *data;
    size_t len;
    size_t cap;
    int oom;
} FrdcBuf;

static void buf_init(FrdcBuf *b) {
    b->data = NULL;
    b->len = 0;
    b->cap = 0;
    b->oom = 0;
}

static void buf_free(FrdcBuf *b) {
    free(b->data);
    b->data = NULL;
    b->len = 0;
    b->cap = 0;
    b->oom = 0;
}

static int buf_reserve(FrdcBuf *b, size_t extra) {
    if (b->oom) return -1;
    if (extra > SIZE_MAX - b->len - 1u) { b->oom = 1; return -1; }
    size_t need = b->len + extra + 1u;
    if (need <= b->cap) return 0;
    size_t ncap = b->cap ? b->cap : 256u;
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

static void buf_append_mem(FrdcBuf *b, const void *src, size_t n) {
    if (n == 0) return;
    if (buf_reserve(b, n) != 0) return;
    memcpy(b->data + b->len, src, n);
    b->len += n;
    b->data[b->len] = '\0';
}

static void buf_append_str(FrdcBuf *b, const char *s) {
    if (s) buf_append_mem(b, s, strlen(s));
}

static void buf_append_ch(FrdcBuf *b, char c) {
    if (buf_reserve(b, 1u) != 0) return;
    b->data[b->len++] = c;
    b->data[b->len] = '\0';
}

static void buf_append_json_str(FrdcBuf *b, const char *s, size_t len) {
    static const char HEX[] = "0123456789abcdef";
    buf_append_ch(b, '"');
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char)s[i];
        switch (c) {
            case '"':  buf_append_mem(b, "\\\"", 2); break;
            case '\\': buf_append_mem(b, "\\\\", 2); break;
            case '\b': buf_append_mem(b, "\\b", 2); break;
            case '\f': buf_append_mem(b, "\\f", 2); break;
            case '\n': buf_append_mem(b, "\\n", 2); break;
            case '\r': buf_append_mem(b, "\\r", 2); break;
            case '\t': buf_append_mem(b, "\\t", 2); break;
            default:
                if (c < 0x20u) {
                    char esc[6];
                    esc[0] = '\\'; esc[1] = 'u'; esc[2] = '0'; esc[3] = '0';
                    esc[4] = HEX[(c >> 4) & 0x0Fu];
                    esc[5] = HEX[c & 0x0Fu];
                    buf_append_mem(b, esc, 6);
                } else {
                    buf_append_ch(b, (char)c);
                }
                break;
        }
    }
    buf_append_ch(b, '"');
}

static void buf_append_json_cstr(FrdcBuf *b, const char *s) {
    if (!s) s = "";
    buf_append_json_str(b, s, strlen(s));
}

static uint64_t monotonic_ns(void) {
#ifdef _WIN32
    LARGE_INTEGER freq, ctr;
    if (QueryPerformanceFrequency(&freq) && QueryPerformanceCounter(&ctr) && freq.QuadPart > 0) {
        return (uint64_t)((double)ctr.QuadPart * 1e9 / (double)freq.QuadPart);
    }
    return 0;
#else
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0) {
        return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec;
    }
    return 0;
#endif
}

static void format_utc_iso8601(char out[32]) {
    time_t now = time(NULL);
    struct tm gmt;
    memset(&gmt, 0, sizeof(gmt));
#ifdef _WIN32
    gmtime_s(&gmt, &now);
#else
    gmtime_r(&now, &gmt);
#endif
    snprintf(out, 32, "%04d-%02d-%02dT%02d:%02d:%02dZ",
             gmt.tm_year + 1900, gmt.tm_mon + 1, gmt.tm_mday,
             gmt.tm_hour, gmt.tm_min, gmt.tm_sec);
}

static int argv_wants_json(int argc, char **argv, int stop_idx) {
    for (int i = 1; i < stop_idx; i++) {
        const char *tok = argv[i];
        if (strcmp(tok, "--format=json") == 0 ||
            strcmp(tok, "-f=json") == 0 ||
            strcmp(tok, "--json") == 0) {
            return 1;
        }
        if ((strcmp(tok, "--format") == 0 || strcmp(tok, "-f") == 0) &&
            i + 1 < stop_idx && strcmp(argv[i + 1], "json") == 0) {
            return 1;
        }
    }
    (void)argc;
    return 0;
}

static void resolve_net_command(const FrdcPack *pack, int argc, char **argv,
                                char *out, size_t cap) {
    FrdcSlice cname;
    const char *prog = "frdc";
    if (frdc_pack_meta(pack, "cli_name", &cname) == 0 && cname.len > 0) {
        prog = (const char *)cname.ptr;
    }
    char path[256];
    size_t plen = 0;
    path[0] = '\0';
    for (int i = 1; i < argc; i++) {
        const char *tok = argv[i];
        if (tok[0] == '-') continue;
        char cand[256];
        int n = plen == 0
            ? snprintf(cand, sizeof(cand), "%s", tok)
            : snprintf(cand, sizeof(cand), "%s %s", path, tok);
        if (n <= 0 || (size_t)n >= sizeof(cand)) break;
        uint32_t fl = 0;
        if (frdc_pack_node(pack, cand, (size_t)n, &fl) != 0) break;
        memcpy(path, cand, (size_t)n + 1);
        plen = (size_t)n;
        if (fl & FRDC_NODE_IS_LEAF) break;
    }
    if (plen == 0) {
        snprintf(out, cap, "%s", prog);
    } else {
        snprintf(out, cap, "%s %s", prog, path);
    }
}

static void emit_stderr_error(const char *msg, int quiet, int stderr_use_color) {
    if (!quiet) {
        if (stderr_use_color) {
            const char *styled = "\x1b[31m\x1b[1mError: \x1b[22m\x1b[39m";
            frdc_write_all_stderr((const uint8_t *)styled, strlen(styled));
        } else {
            const char *plain = "Error: ";
            frdc_write_all_stderr((const uint8_t *)plain, strlen(plain));
        }
    }
    frdc_write_all_stderr((const uint8_t *)msg, strlen(msg));
    const uint8_t nl = '\n';
    frdc_write_all_stderr(&nl, 1);
}

static void buf_append_argv_array(FrdcBuf *b, int argc, char **argv) {
    buf_append_ch(b, '[');
    for (int i = 1; i < argc; i++) {
        if (i > 1) buf_append_ch(b, ',');
        buf_append_json_cstr(b, argv[i]);
    }
    buf_append_ch(b, ']');
}

static void emit_error_envelope(const FrdcPack *pack, int argc, char **argv,
                                const char *code, const char *msg, const char *hint,
                                int exit_code, int has_seed, int64_t seed_val,
                                uint64_t t0_ns) {
    FrdcSlice cli_ver = { (const uint8_t *)"0.0.0", 5 };
    FrdcSlice jl_ver  = { (const uint8_t *)"unknown", 7 };
    FrdcSlice mems_ver = { (const uint8_t *)"unknown", 7 };
    frdc_pack_meta(pack, "cli_version", &cli_ver);
    frdc_pack_meta(pack, "julia_version", &jl_ver);
    frdc_pack_meta(pack, "mems_version", &mems_ver);

    char cmd[300];
    resolve_net_command(pack, argc, argv, cmd, sizeof(cmd));

    uint64_t t1_ns = monotonic_ns();
    double elapsed_ms = (t1_ns >= t0_ns) ? ((double)(t1_ns - t0_ns) / 1e6) : 0.0;
    char numbuf[64];

    FrdcBuf b;
    buf_init(&b);
    buf_append_str(&b, "{\"schema_version\":1,\"command\":");
    buf_append_json_cstr(&b, cmd);
    buf_append_str(&b, ",\"status\":\"error\",\"meta\":{\"cli_version\":");
    buf_append_json_str(&b, (const char *)cli_ver.ptr, cli_ver.len);
    buf_append_str(&b, ",\"julia\":");
    buf_append_json_str(&b, (const char *)jl_ver.ptr, jl_ver.len);
    buf_append_str(&b, ",\"seed\":");
    if (has_seed) {
        snprintf(numbuf, sizeof(numbuf), "%" PRId64, seed_val);
        buf_append_str(&b, numbuf);
    } else {
        buf_append_str(&b, "null");
    }
    buf_append_str(&b, ",\"argv\":");
    buf_append_argv_array(&b, argc, argv);
    snprintf(numbuf, sizeof(numbuf), "%.6f", elapsed_ms);
    buf_append_str(&b, ",\"elapsed_ms\":");
    buf_append_str(&b, numbuf);
    buf_append_str(&b, ",\"mems_version\":");
    buf_append_json_str(&b, (const char *)mems_ver.ptr, mems_ver.len);
    buf_append_str(&b, "},\"data\":{},\"warnings\":[],\"artifacts\":[],\"error\":{\"code\":");
    buf_append_json_cstr(&b, code);
    buf_append_str(&b, ",\"message\":");
    buf_append_json_cstr(&b, msg);
    if (hint && hint[0] != '\0') {
        buf_append_str(&b, ",\"hint\":");
        buf_append_json_cstr(&b, hint);
    }
    snprintf(numbuf, sizeof(numbuf), "%d", exit_code);
    buf_append_str(&b, ",\"exit_code\":");
    buf_append_str(&b, numbuf);
    buf_append_str(&b, "}}\n");
    if (!b.oom) {
        frdc_write_all_stdout((const uint8_t *)b.data, b.len);
    }
    buf_free(&b);
}

/* Format unknown-command message matching _unknown_command_message in src/cli/dispatch.jl */
static void build_unknown_cmd_msg(const FrdcPack *pack, const char *cur_path,
                                  const char *subcmd, const char *const *rest, int n_rest,
                                  FrdcBuf *out) {
    FrdcSlice cname;
    const char *prog = "frdc";
    if (frdc_pack_meta(pack, "cli_name", &cname) == 0 && cname.len > 0) {
        prog = (const char *)cname.ptr;
    }

    /* Build base: "<prog>[ <cur_path>]: unknown command '<subcmd>'" */
    buf_append_str(out, prog);
    if (cur_path && cur_path[0] != '\0') {
        buf_append_ch(out, ' ');
        buf_append_str(out, cur_path);
    }
    buf_append_str(out, ": unknown command '");
    buf_append_str(out, subcmd);
    buf_append_ch(out, '\'');

    /* Longest-prefix lookup in repl_tbl over [cur_path_segs..., subcmd, rest...] */
    const char *toks[8];
    int ntoks = 0;
    char cur_copy[256];
    if (cur_path && cur_path[0] != '\0' && strlen(cur_path) < sizeof(cur_copy)) {
        strcpy(cur_copy, cur_path);
        char *p = cur_copy;
        while (*p && ntoks < 6) {
            while (*p == ' ') p++;
            if (!*p) break;
            toks[ntoks++] = p;
            while (*p && *p != ' ') p++;
            if (*p == ' ') *p++ = '\0';
        }
    }
    if (ntoks < 8) toks[ntoks++] = subcmd;
    for (int i = 0; i < n_rest && ntoks < 8; i++) {
        toks[ntoks++] = rest[i];
    }

    int max_len = ntoks < 4 ? ntoks : 4;
    for (int len = max_len; len >= 1; len--) {
        char cand[300];
        size_t clen = 0;
        cand[0] = '\0';
        int ok = 1;
        for (int j = 0; j < len; j++) {
            size_t tl = strlen(toks[j]);
            if (clen + (j > 0 ? 1u : 0u) + tl >= sizeof(cand)) { ok = 0; break; }
            if (j > 0) cand[clen++] = ' ';
            memcpy(cand + clen, toks[j], tl);
            clen += tl;
            cand[clen] = '\0';
        }
        if (!ok) continue;
        FrdcSlice repl;
        if (frdc_pack_repl(pack, cand, clen, &repl) == 0 && repl.len > 0) {
            /* UTF-8 em-dash: " — use `<new>`" */
            buf_append_str(out, " \xe2\x80\x94 use `");
            buf_append_mem(out, repl.ptr, repl.len);
            buf_append_ch(out, '`');
            return;
        }
    }
}

/* ── Tier 1, Tier 2, Tier 3 & Tier 4 Fast-Path Handlers ────────────────── */

static int handle_help_key(const FrdcPack *pack, const char *path, size_t path_len, int use_color) {
    char key[300];
    if (path_len + 3 > sizeof(key)) return -1;
    key[0] = 'H';
    key[1] = ':';
    if (path_len > 0) memcpy(key + 2, path, path_len);
    key[2 + path_len] = '\0';

    uint8_t *buf = NULL;
    size_t len = 0;
    if (frdc_pack_read_entry(pack, key, 2 + path_len, &buf, &len) != 0) return -1;
    frdc_emit_help_bytes(buf, len, use_color);
    free(buf);
    return 0;
}

/* Returns: 0 = handled (exit 0), 2 = handled fast-fail (exit 2), -1 = fail open */
static int handle_schema_cmd(const FrdcPack *pack, int orig_argc, char **orig_argv,
                             char **args, int nargs, int use_color,
                             int quiet, int stderr_use_color, int wants_json,
                             int has_seed, int64_t seed_val, uint64_t t0_ns) {
    if (wants_help_in(args, 0, nargs)) {
        return handle_help_key(pack, "schema", 6, use_color);
    }

    int docs = 0;
    const char *format = "json";
    const char *path_parts[8];
    int n_parts = 0;

    int i = 0;
    while (i < nargs) {
        const char *tok = args[i];
        if (strcmp(tok, "--docs") == 0) {
            docs = 1;
            i++;
        } else if (strcmp(tok, "--format") == 0 || strcmp(tok, "-f") == 0) {
            if (i + 1 >= nargs || !looks_like_value(args[i + 1])) return -1;
            format = args[i + 1];
            i += 2;
        } else if (strncmp(tok, "--format=", 9) == 0) {
            format = tok + 9;
            i++;
        } else if (strncmp(tok, "-f=", 3) == 0) {
            format = tok + 3;
            i++;
        } else if (strcmp(tok, "--output") == 0 || strcmp(tok, "-o") == 0 ||
                   strncmp(tok, "--output=", 9) == 0 || strncmp(tok, "-o=", 3) == 0) {
            /* Delegate -o to frdc-core so path confinement & status prose stay single-sourced */
            return -1;
        } else if (tok[0] == '-') {
            /* Unknown option -> fail open to frdc-core */
            return -1;
        } else {
            if (n_parts >= 8) return -1;
            path_parts[n_parts++] = tok;
            i++;
        }
    }

    if (strcmp(format, "json") != 0) return -1;

    /* Walk path_parts replicating _resolve_schema_path() in src/commands/schema.jl */
    char cur[256];
    size_t clen = 0;
    cur[0] = '\0';
    for (int p = 0; p < n_parts; p++) {
        char cand[256];
        int n = clen == 0
            ? snprintf(cand, sizeof(cand), "%s", path_parts[p])
            : snprintf(cand, sizeof(cand), "%s %s", cur, path_parts[p]);
        if (n <= 0 || (size_t)n >= sizeof(cand)) return -1;

        uint32_t fl = 0;
        if (frdc_pack_node(pack, cand, (size_t)n, &fl) != 0) {
            /* Tier 4 fast-fail: unknown schema path */
            FrdcBuf msg;
            buf_init(&msg);
            build_unknown_cmd_msg(pack, cur, path_parts[p],
                                  path_parts + p + 1, n_parts - p - 1, &msg);
            FrdcBuf emsg;
            buf_init(&emsg);
            buf_append_str(&emsg, "usage/unknown-command: ");
            buf_append_mem(&emsg, msg.data, msg.len);
            if (!emsg.oom) emit_stderr_error(emsg.data, quiet, stderr_use_color);
            if (wants_json && !msg.oom) {
                emit_error_envelope(pack, orig_argc, orig_argv,
                                    "usage/unknown-command", msg.data, NULL,
                                    2, has_seed, seed_val, t0_ns);
            }
            buf_free(&emsg);
            buf_free(&msg);
            return 2;
        }
        memcpy(cur, cand, (size_t)n + 1);
        clen = (size_t)n;
        if ((fl & FRDC_NODE_IS_LEAF) && p + 1 < n_parts) {
            /* Extra tokens after a leaf */
            FrdcBuf msg;
            buf_init(&msg);
            buf_append_str(&msg, "schema: '");
            buf_append_str(&msg, path_parts[p]);
            buf_append_str(&msg, "' is a leaf; extra path ");
            for (int q = p + 1; q < n_parts; q++) {
                if (q > p + 1) buf_append_ch(&msg, ' ');
                buf_append_str(&msg, path_parts[q]);
            }
            FrdcBuf emsg;
            buf_init(&emsg);
            buf_append_str(&emsg, "usage/unknown-command: ");
            buf_append_mem(&emsg, msg.data, msg.len);
            if (!emsg.oom) emit_stderr_error(emsg.data, quiet, stderr_use_color);
            if (wants_json && !msg.oom) {
                emit_error_envelope(pack, orig_argc, orig_argv,
                                    "usage/unknown-command", msg.data, NULL,
                                    2, has_seed, seed_val, t0_ns);
            }
            buf_free(&emsg);
            buf_free(&msg);
            return 2;
        }
    }

    char key[300];
    key[0] = 'S';
    key[1] = ':';
    if (clen > 0) memcpy(key + 2, cur, clen);
    key[2 + clen] = '\0';

    uint8_t *raw = NULL;
    size_t rlen = 0;
    if (frdc_pack_read_entry(pack, key, 2 + clen, &raw, &rlen) != 0) return -1;

    if (!docs) {
        frdc_write_all_stdout(raw, rlen);
        const uint8_t nl = '\n';
        frdc_write_all_stdout(&nl, 1);
        free(raw);
        return 0;
    }

    if (rlen < 2 || raw[rlen - 1] != '}') {
        free(raw);
        return -1;
    }
    FrdcSlice guide;
    if (frdc_pack_meta(pack, "agent_guide_json_escaped", &guide) != 0) {
        free(raw);
        return -1;
    }
    frdc_write_all_stdout(raw, rlen - 1);
    const char *mid = ",\"docs\":";
    frdc_write_all_stdout((const uint8_t *)mid, strlen(mid));
    frdc_write_all_stdout(guide.ptr, guide.len);
    const char *tail = "}\n";
    frdc_write_all_stdout((const uint8_t *)tail, 2);
    free(raw);
    return 0;
}

static int handle_completions_cmd(const FrdcPack *pack, const char *shell,
                                  int leaf_argc, int force_json) {
    if (leaf_argc != 0 || force_json) return -1;
    char key[32];
    int n = snprintf(key, sizeof(key), "C:%s", shell);
    if (n <= 0 || (size_t)n >= sizeof(key)) return -1;
    uint8_t *buf = NULL;
    size_t len = 0;
    if (frdc_pack_read_entry(pack, key, (size_t)n, &buf, &len) != 0) return -1;
    frdc_write_all_stdout(buf, len);
    free(buf);
    return 0;
}

/* Tier 3: Static offline catalogs (`data list` and `io sources`) */
static int handle_catalog_cmd(const FrdcPack *pack, const char *tag, const char *cmd_label,
                              int orig_argc, char **orig_argv,
                              char **leaf_args, int leaf_argc,
                              int compact, int has_seed, int64_t seed_val,
                              uint64_t t0_ns) {
    const char *format = "table";
    int i = 0;
    while (i < leaf_argc) {
        const char *tok = leaf_args[i];
        if (strcmp(tok, "--format") == 0 || strcmp(tok, "-f") == 0) {
            if (i + 1 >= leaf_argc) return -1;
            format = leaf_args[i + 1];
            i += 2;
        } else if (strncmp(tok, "--format=", 9) == 0) {
            format = tok + 9;
            i++;
        } else if (strncmp(tok, "-f=", 3) == 0) {
            format = tok + 3;
            i++;
        } else {
            /* -o/--output, unknown options, or positionals -> fail open */
            return -1;
        }
    }

    if (strcmp(format, "table") == 0) {
        if (compact && frdc_stdout_is_tty()) return -1;
        char key[64];
        int n = snprintf(key, sizeof(key), "D:%s:table", tag);
        if (n <= 0 || (size_t)n >= sizeof(key)) return -1;
        uint8_t *buf = NULL;
        size_t len = 0;
        if (frdc_pack_read_entry(pack, key, (size_t)n, &buf, &len) != 0) return -1;
        frdc_write_all_stdout(buf, len);
        free(buf);
        return 0;
    }

    if (strcmp(format, "csv") == 0) {
        char key[64];
        int n = snprintf(key, sizeof(key), "D:%s:csv", tag);
        if (n <= 0 || (size_t)n >= sizeof(key)) return -1;
        uint8_t *buf = NULL;
        size_t len = 0;
        if (frdc_pack_read_entry(pack, key, (size_t)n, &buf, &len) != 0) return -1;
        frdc_write_all_stdout(buf, len);
        free(buf);
        return 0;
    }

    if (strcmp(format, "json") == 0) {
        char key[64];
        int n = snprintf(key, sizeof(key), "D:%s:json_data", tag);
        if (n <= 0 || (size_t)n >= sizeof(key)) return -1;
        uint8_t *data_json = NULL;
        size_t data_len = 0;
        if (frdc_pack_read_entry(pack, key, (size_t)n, &data_json, &data_len) != 0) return -1;

        FrdcSlice cli_ver, jl_ver, mems_ver, deps_json, os_s, mach_s, git_sha;
        if (frdc_pack_meta(pack, "cli_version", &cli_ver) != 0 ||
            frdc_pack_meta(pack, "julia_version", &jl_ver) != 0 ||
            frdc_pack_meta(pack, "mems_version", &mems_ver) != 0 ||
            frdc_pack_meta(pack, "manifest_deps_json", &deps_json) != 0 ||
            frdc_pack_meta(pack, "os", &os_s) != 0 ||
            frdc_pack_meta(pack, "machine", &mach_s) != 0 ||
            frdc_pack_meta(pack, "cli_git_sha", &git_sha) != 0) {
            free(data_json);
            return -1;
        }

        char ts[32];
        format_utc_iso8601(ts);
        uint64_t t1_ns = monotonic_ns();
        double elapsed_ms = (t1_ns >= t0_ns) ? ((double)(t1_ns - t0_ns) / 1e6) : 0.0;
        char seed_buf[64];
        char ms_buf[64];
        if (has_seed) {
            snprintf(seed_buf, sizeof(seed_buf), "%" PRId64, seed_val);
        } else {
            strcpy(seed_buf, "null");
        }
        snprintf(ms_buf, sizeof(ms_buf), "%.6f", elapsed_ms);

        FrdcBuf b;
        buf_init(&b);
        buf_append_str(&b, "{\"schema_version\":1,\"command\":");
        buf_append_json_cstr(&b, cmd_label);
        buf_append_str(&b, ",\"status\":\"ok\",\"meta\":{\"cli_version\":");
        buf_append_json_str(&b, (const char *)cli_ver.ptr, cli_ver.len);
        buf_append_str(&b, ",\"julia\":");
        buf_append_json_str(&b, (const char *)jl_ver.ptr, jl_ver.len);
        buf_append_str(&b, ",\"seed\":");
        buf_append_str(&b, seed_buf);
        buf_append_str(&b, ",\"argv\":");
        buf_append_argv_array(&b, orig_argc, orig_argv);
        buf_append_str(&b, ",\"mems_version\":");
        buf_append_json_str(&b, (const char *)mems_ver.ptr, mems_ver.len);
        buf_append_str(&b, ",\"manifest\":{\"seed\":");
        buf_append_str(&b, seed_buf);
        buf_append_str(&b, ",\"n_threads\":1,\"julia_version\":");
        buf_append_json_str(&b, (const char *)jl_ver.ptr, jl_ver.len);
        buf_append_str(&b, ",\"package_version\":");
        buf_append_json_str(&b, (const char *)mems_ver.ptr, mems_ver.len);
        buf_append_str(&b, ",\"dependency_versions\":");
        buf_append_mem(&b, deps_json.ptr, deps_json.len);
        buf_append_str(&b, ",\"os\":");
        buf_append_json_str(&b, (const char *)os_s.ptr, os_s.len);
        buf_append_str(&b, ",\"machine\":");
        buf_append_json_str(&b, (const char *)mach_s.ptr, mach_s.len);
        buf_append_str(&b, ",\"timestamp\":");
        buf_append_json_cstr(&b, ts);
        buf_append_str(&b, ",\"git_sha\":");
        buf_append_json_str(&b, (const char *)git_sha.ptr, git_sha.len);
        buf_append_str(&b, ",\"git_dirty\":false,\"settings\":{}},\"elapsed_ms\":");
        buf_append_str(&b, ms_buf);
        buf_append_str(&b, "},\"data\":");
        buf_append_mem(&b, data_json, data_len);
        buf_append_str(&b, ",\"warnings\":[],\"artifacts\":[],\"error\":null}\n");

        free(data_json);
        if (b.oom) { buf_free(&b); return -1; }
        frdc_write_all_stdout((const uint8_t *)b.data, b.len);
        buf_free(&b);
        return 0;
    }

    return -1;
}

/* ── Main thin entry point ─────────────────────────────────────────────── */

static int run_thin(int argc, char **argv) {
    uint64_t t0_ns = monotonic_ns();
    frdc_setup_console();

    char exe_path[FRDC_PATH_MAX];
    if (frdc_get_self_exe(exe_path, sizeof(exe_path)) != 0) {
        if (argc > 0 && argv[0] && strlen(argv[0]) < sizeof(exe_path)) {
            strcpy(exe_path, argv[0]);
        } else {
            return 1;
        }
    }

    /* 1. Explicit bypass: FRDC_NO_FASTPATH=1 / FRIEDMAN_NO_FASTPATH=1 or --julia-args */
    const char *no_fp = frdc_env_get("FRDC_NO_FASTPATH", "FRIEDMAN_NO_FASTPATH");
    if (no_fp && strcmp(no_fp, "1") == 0) {
        return frdc_exec_core(exe_path, argc, argv);
    }
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--julia-args") == 0) {
            return frdc_exec_core(exe_path, argc, argv);
        }
    }

    /* 2. Locate and validate FRDCACHE v1 pack (fail open on any error) */
    char pack_path[FRDC_PATH_MAX];
    if (resolve_pack_path(exe_path, pack_path, sizeof(pack_path)) != 0) {
        return frdc_exec_core(exe_path, argc, argv);
    }
    FrdcPack pack;
    if (frdc_pack_load(&pack, pack_path) != 0) {
        return frdc_exec_core(exe_path, argc, argv);
    }

#ifndef _WIN32
    /* Dev-mode staleness check: if running in source tree without frdc-core,
       fall back to julia when src/ or Project.toml is newer than source_stamp. */
    {
        char core_tmp[FRDC_PATH_MAX];
        int is_dev = 0;
        if (frdc_resolve_core_path(exe_path, core_tmp, sizeof(core_tmp), &is_dev) == 0 &&
            is_dev && dev_pack_is_stale(core_tmp, pack.source_stamp)) {
            frdc_pack_free(&pack);
            return frdc_exec_core(exe_path, argc, argv);
        }
    }
#endif

    int env_no_color = (getenv("NO_COLOR") != NULL) ? 1 : 0;

    /* 3. Handle argv[1] == "repl" BEFORE global-flag scanning (matches run_cli:230) */
    if (argc >= 2 && strcmp(argv[1], "repl") == 0) {
        if (wants_help_in(argv, 2, argc)) {
            int use_color = frdc_stdout_is_tty() && !env_no_color;
            int rc = handle_help_key(&pack, "repl", 4, use_color);
            frdc_pack_free(&pack);
            if (rc == 0) return 0;
            return frdc_exec_core(exe_path, argc, argv);
        }
        if (argc > 2) {
            /* Tier 4 fast-fail: repl takes no positional arguments */
            FrdcBuf msg;
            buf_init(&msg);
            buf_append_str(&msg, "frdc repl takes no positional arguments (got '");
            buf_append_str(&msg, argv[2]);
            buf_append_str(&msg, "'); run 'frdc repl --help'");
            if (!msg.oom) emit_stderr_error(msg.data, 0, frdc_stderr_is_tty() && !env_no_color);
            buf_free(&msg);
            frdc_pack_free(&pack);
            return 2;
        }
        frdc_pack_free(&pack);
        return frdc_exec_core(exe_path, argc, argv);
    }

    /* 4. Replicate _probe_target_command() + _extract_global_flags!() */
    int dd = argc;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--") == 0) { dd = i; break; }
    }
    int stop_idx = dd;
    int wants_json = argv_wants_json(argc, argv, stop_idx);

    ProbeResult probe;
    probe_target_command(&pack, argc, argv, stop_idx, &probe);

    int leaf_owns_seed    = probe.has_leaf && ((probe.leaf_flags & FRDC_NODE_OWNS_SEED) != 0);
    int leaf_owns_q       = probe.has_leaf && ((probe.leaf_flags & FRDC_NODE_OWNS_SHORT_Q) != 0);
    int leaf_owns_compact = probe.has_leaf && ((probe.leaf_flags & FRDC_NODE_OWNS_COMPACT) != 0);
    int leaf_has_format   = probe.has_leaf ? ((probe.leaf_flags & FRDC_NODE_HAS_FORMAT_OPT) != 0) : 1;
    int leaf_is_serve       = (strcmp(probe.cmd_path, "serve") == 0);
    int leaf_is_completions = (strncmp(probe.cmd_path, "completions", 11) == 0 &&
                               (probe.cmd_path[11] == '\0' || probe.cmd_path[11] == ' '));
    int leaf_is_schema      = (strcmp(probe.cmd_path, "schema") == 0);

    int quiet = 0;
    int no_color = env_no_color;
    int compact = 0;
    int force_json = 0;
    int has_seed = 0;
    int64_t seed_val = 0;

    char **rem = (char **)malloc(((size_t)argc + 4u) * sizeof(char *));
    if (!rem) {
        frdc_pack_free(&pack);
        return frdc_exec_core(exe_path, argc, argv);
    }
    int rem_n = 0;
    int i = 1;
    while (i < stop_idx) {
        const char *tok = argv[i];
        int is_leading = (i < probe.first_cmd_idx);
        if (strcmp(tok, "--quiet") == 0) {
            quiet = 1;
            i++;
        } else if (strcmp(tok, "-q") == 0 && (is_leading || !leaf_owns_q)) {
            quiet = 1;
            i++;
        } else if (strcmp(tok, "--no-color") == 0) {
            no_color = 1;
            i++;
        } else if (strcmp(tok, "--compact") == 0 && (is_leading || !leaf_owns_compact)) {
            compact = 1;
            i++;
        } else if (strcmp(tok, "--json") == 0) {
            force_json = 1;
            i++;
        } else if (strcmp(tok, "--seed") == 0) {
            if (i + 1 >= stop_idx || parse_strict_i64(argv[i + 1], &seed_val) != 0) {
                free(rem);
                frdc_pack_free(&pack);
                return frdc_exec_core(exe_path, argc, argv);
            }
            has_seed = 1;
            if (!is_leading && leaf_owns_seed) {
                rem[rem_n++] = argv[i];
                rem[rem_n++] = argv[i + 1];
            }
            i += 2;
        } else if (strncmp(tok, "--seed=", 7) == 0) {
            if (parse_strict_i64(tok + 7, &seed_val) != 0) {
                free(rem);
                frdc_pack_free(&pack);
                return frdc_exec_core(exe_path, argc, argv);
            }
            has_seed = 1;
            if (!is_leading && leaf_owns_seed) {
                rem[rem_n++] = argv[i];
            }
            i++;
        } else {
            rem[rem_n++] = argv[i];
            i++;
        }
    }
    int rem_dd = rem_n;
    if (dd < argc) {
        for (int j = dd; j < argc; j++) rem[rem_n++] = argv[j];
    }

    if (force_json) {
        const char *efmt = explicit_format_in(rem, rem_dd);
        if (efmt != NULL) {
            if (!streq_ci(efmt, "json")) {
                free(rem);
                frdc_pack_free(&pack);
                return frdc_exec_core(exe_path, argc, argv);
            }
        } else if (leaf_is_serve) {
            free(rem);
            frdc_pack_free(&pack);
            return frdc_exec_core(exe_path, argc, argv);
        } else if (leaf_is_completions || leaf_is_schema) {
            /* handled natively */
        } else if (leaf_has_format) {
            /* Insert --format json before -- */
            for (int j = rem_n - 1; j >= rem_dd; j--) rem[j + 2] = rem[j];
            rem[rem_dd]     = (char *)"--format";
            rem[rem_dd + 1] = (char *)"json";
            rem_n += 2;
            rem_dd += 2;
        }
    }

    int use_color = frdc_stdout_is_tty() && !no_color;
    int stderr_use_color = frdc_stderr_is_tty() && !no_color;

    /* 5. Tier 1: Leading-only --version/-V, --warranty, --conditions */
    if (rem_n >= 1) {
        if (strcmp(rem[0], "--version") == 0 || strcmp(rem[0], "-V") == 0) {
            FrdcSlice v;
            if (frdc_pack_meta(&pack, "version_line", &v) == 0) {
                frdc_write_all_stdout(v.ptr, v.len);
                free(rem);
                frdc_pack_free(&pack);
                return 0;
            }
        } else if (strcmp(rem[0], "--warranty") == 0) {
            FrdcSlice w;
            if (frdc_pack_meta(&pack, "warranty_text", &w) == 0) {
                frdc_write_all_stdout(w.ptr, w.len);
                free(rem);
                frdc_pack_free(&pack);
                return 0;
            }
        } else if (strcmp(rem[0], "--conditions") == 0) {
            FrdcSlice c;
            if (frdc_pack_meta(&pack, "conditions_text", &c) == 0) {
                frdc_write_all_stdout(c.ptr, c.len);
                free(rem);
                frdc_pack_free(&pack);
                return 0;
            }
        }
    }

    /* 6. Tier 1: Root Entry help */
    if (rem_n == 0 || strcmp(rem[0], "--help") == 0 || strcmp(rem[0], "-h") == 0) {
        int rc = handle_help_key(&pack, "", 0, use_color);
        free(rem);
        frdc_pack_free(&pack);
        if (rc == 0) return 0;
        return frdc_exec_core(exe_path, argc, argv);
    }

    /* 7. Tier 2 & 4: Dedicated schema dispatcher */
    if (strcmp(rem[0], "schema") == 0) {
        int rc = handle_schema_cmd(&pack, argc, argv, rem + 1, rem_n - 1,
                                   use_color, quiet, stderr_use_color,
                                   wants_json, has_seed, seed_val, t0_ns);
        free(rem);
        frdc_pack_free(&pack);
        if (rc >= 0) return rc;
        return frdc_exec_core(exe_path, argc, argv);
    }

    /* 8. Walk NodeCommand / LeafCommand tree */
    char cur_path[256];
    size_t cur_len = 0;
    cur_path[0] = '\0';

    for (int k = 0; k < rem_n; k++) {
        char cand[256];
        int n = cur_len == 0
            ? snprintf(cand, sizeof(cand), "%s", rem[k])
            : snprintf(cand, sizeof(cand), "%s %s", cur_path, rem[k]);
        if (n <= 0 || (size_t)n >= sizeof(cand)) break;

        uint32_t fl = 0;
        if (frdc_pack_node(&pack, cand, (size_t)n, &fl) != 0) {
            if (wants_help_in(rem, k, rem_n)) {
                /* When cur_len == 0 (e.g. `--quiet repl --help`), Julia prints NodeCommand
                   root without Entry footer; fail open to match byte-for-byte. */
                if (cur_len > 0) {
                    int rc = handle_help_key(&pack, cur_path, cur_len, use_color);
                    free(rem);
                    frdc_pack_free(&pack);
                    if (rc == 0) return 0;
                    return frdc_exec_core(exe_path, argc, argv);
                }
                break;
            }
            /* Tier 4 fast-fail: unknown command with longest-prefix _PATH_REPLACEMENTS hint */
            FrdcBuf msg;
            buf_init(&msg);
            build_unknown_cmd_msg(&pack, cur_path, rem[k],
                                  (const char *const *)(rem + k + 1), rem_n - k - 1, &msg);
            if (!msg.oom) {
                emit_stderr_error(msg.data, quiet, stderr_use_color);
                if (wants_json) {
                    emit_error_envelope(&pack, argc, argv, "usage/unknown-command",
                                        msg.data, NULL, 2, has_seed, seed_val, t0_ns);
                }
            }
            buf_free(&msg);
            free(rem);
            frdc_pack_free(&pack);
            return 2;
        }

        memcpy(cur_path, cand, (size_t)n + 1);
        cur_len = (size_t)n;

        if (!(fl & FRDC_NODE_IS_LEAF)) {
            /* NodeCommand with no further tokens -> print node help */
            if (k == rem_n - 1) {
                int rc = handle_help_key(&pack, cur_path, cur_len, use_color);
                free(rem);
                frdc_pack_free(&pack);
                if (rc == 0) return 0;
                return frdc_exec_core(exe_path, argc, argv);
            }
            continue;
        }

        /* Matched LeafCommand */
        int leaf_start = k + 1;
        int leaf_argc = rem_n - leaf_start;

        /* Leaf help: --help / -h anywhere in leaf args, or empty args with required arg */
        if (wants_help_in(rem, leaf_start, rem_n) ||
            (leaf_argc == 0 && (fl & FRDC_NODE_HAS_REQUIRED_ARG))) {
            int rc = handle_help_key(&pack, cur_path, cur_len, use_color);
            free(rem);
            frdc_pack_free(&pack);
            if (rc == 0) return 0;
            return frdc_exec_core(exe_path, argc, argv);
        }

        /* Tier 2: completions bash|zsh|fish */
        if (strcmp(cur_path, "completions bash") == 0) {
            int rc = handle_completions_cmd(&pack, "bash", leaf_argc, force_json);
            if (rc == 0) { free(rem); frdc_pack_free(&pack); return 0; }
        } else if (strcmp(cur_path, "completions zsh") == 0) {
            int rc = handle_completions_cmd(&pack, "zsh", leaf_argc, force_json);
            if (rc == 0) { free(rem); frdc_pack_free(&pack); return 0; }
        } else if (strcmp(cur_path, "completions fish") == 0) {
            int rc = handle_completions_cmd(&pack, "fish", leaf_argc, force_json);
            if (rc == 0) { free(rem); frdc_pack_free(&pack); return 0; }
        }

        /* Tier 3: static offline catalogs (data list & io sources) */
        if (strcmp(cur_path, "data list") == 0) {
            int rc = handle_catalog_cmd(&pack, "data_list", "frdc data list",
                                        argc, argv, rem + leaf_start, leaf_argc,
                                        compact, has_seed, seed_val, t0_ns);
            if (rc == 0) { free(rem); frdc_pack_free(&pack); return 0; }
        } else if (strcmp(cur_path, "io sources") == 0) {
            int rc = handle_catalog_cmd(&pack, "io_sources", "frdc io sources",
                                        argc, argv, rem + leaf_start, leaf_argc,
                                        compact, has_seed, seed_val, t0_ns);
            if (rc == 0) { free(rem); frdc_pack_free(&pack); return 0; }
        }

        /* Tier 4: bare `serve` missing --mcp (and #299 lazy MCP proxy hook) */
        if (strcmp(cur_path, "serve") == 0) {
            if (leaf_argc == 0 && !force_json) {
                const char *msg  = "serve requires --mcp (the only supported mode)";
                const char *hint = "frdc serve --mcp speaks JSON-RPC 2.0 / Model Context Protocol on stdio";
                const char *emsg = "usage/missing: serve requires --mcp (the only supported mode) "
                                   "(hint: frdc serve --mcp speaks JSON-RPC 2.0 / Model Context Protocol on stdio)";
                emit_stderr_error(emsg, quiet, stderr_use_color);
                if (wants_json) {
                    emit_error_envelope(&pack, argc, argv, "usage/missing",
                                        msg, hint, 2, has_seed, seed_val, t0_ns);
                }
                free(rem);
                frdc_pack_free(&pack);
                return 2;
            }
        }
        break;
    }

    free(rem);
    frdc_pack_free(&pack);
    return frdc_exec_core(exe_path, argc, argv);
}

#ifdef _WIN32
int wmain(int argc, wchar_t *wargv[]) {
    char **argv = (char **)malloc(((size_t)argc + 1u) * sizeof(char *));
    if (!argv) return 1;
    for (int i = 0; i < argc; i++) {
        int len = WideCharToMultiByte(CP_UTF8, 0, wargv[i], -1, NULL, 0, NULL, NULL);
        if (len <= 0) return 1;
        argv[i] = (char *)malloc((size_t)len);
        if (!argv[i]) return 1;
        if (WideCharToMultiByte(CP_UTF8, 0, wargv[i], -1, argv[i], len, NULL, NULL) <= 0) {
            return 1;
        }
    }
    argv[argc] = NULL;
    int rc = run_thin(argc, argv);
    for (int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    return rc;
}
#else
int main(int argc, char **argv) {
    return run_thin(argc, argv);
}
#endif
