/* Friedman-cli (frdc) — Multi-agent-safe opt-in resident daemon C99 client ([PERF-W3] #357)
 * Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
 * SPDX-License-Identifier: GPL-3.0-only
 *
 * Strictly opt-in (FRDC_DAEMON=1, OFF by default). Implements:
 *   - Deterministic isolation key: (uid/user, build_stamp, threads, hash(FRDC_DATA_ROOT))
 *   - Single-rendezvous anti-spawn-storm bootstrap lock (flock LOCK_EX / CreateMutexW)
 *     with double-checked connect() and detached daemon spawn (stdio -> /dev/null)
 *   - Two-phase {"ack":true} bounded acquire (FRDC_DAEMON_ACQUIRE_MS=200) failing
 *     open directly to one-shot frdc-core when the warm worker is busy
 *   - Clean exit (zero hangs) on mid-request SIGKILL
 */

#ifdef __APPLE__
#ifndef _DARWIN_C_SOURCE
#define _DARWIN_C_SOURCE
#endif
#elif !defined(_WIN32)
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#endif

#include "frdc_thin.h"
#include "yyjson.h"

#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <wchar.h>
#else
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/file.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>
#endif

#define DAEMON_PATH_MAX 4096
#define DAEMON_MAX_FRAME (64u * 1024u * 1024u)

#ifndef _WIN32
extern char **environ;
#endif

static int dc_env_is_true(const char *val) {
    if (!val || val[0] == '\0') return 0;
    while (*val == ' ' || *val == '\t' || *val == '\r' || *val == '\n') val++;
    if (strcmp(val, "1") == 0) return 1;
    char low[16];
    size_t i = 0;
    while (val[i] != '\0' && i + 1 < sizeof(low)) {
        low[i] = (char)tolower((unsigned char)val[i]);
        i++;
    }
    low[i] = '\0';
    return (strcmp(low, "true") == 0 || strcmp(low, "on") == 0 || strcmp(low, "yes") == 0);
}

static int dc_env_is_false(const char *val) {
    if (!val || val[0] == '\0') return 0;
    while (*val == ' ' || *val == '\t' || *val == '\r' || *val == '\n') val++;
    if (strcmp(val, "0") == 0) return 1;
    char low[16];
    size_t i = 0;
    while (val[i] != '\0' && i + 1 < sizeof(low)) {
        low[i] = (char)tolower((unsigned char)val[i]);
        i++;
    }
    low[i] = '\0';
    return (strcmp(low, "false") == 0 || strcmp(low, "off") == 0 || strcmp(low, "no") == 0);
}

static int dc_parse_pos_int_env(const char *name, int def_val, int max_val) {
    const char *v = getenv(name);
    if (!v || v[0] == '\0') return def_val;
    char *endp = NULL;
    long x = strtol(v, &endp, 10);
    if (!endp || *endp != '\0' || x <= 0) return def_val;
    if (x > max_val) return max_val;
    return (int)x;
}

static uint32_t dc_fnv1a32(const char *s, size_t len) {
    uint32_t h = 0x811c9dc5u;
    for (size_t i = 0; i < len; i++) {
        h ^= (uint32_t)(unsigned char)s[i];
        h *= 0x01000193u;
    }
    return h;
}

static void dc_trim_copy(const char *src, char *dst, size_t cap) {
    if (!src) {
        dst[0] = '\0';
        return;
    }
    while (*src == ' ' || *src == '\t' || *src == '\r' || *src == '\n') src++;
    size_t len = strlen(src);
    while (len > 0 && (src[len - 1] == ' ' || src[len - 1] == '\t' ||
                       src[len - 1] == '\r' || src[len - 1] == '\n')) {
        len--;
    }
    if (len >= cap) len = cap - 1;
    if (len > 0) memcpy(dst, src, len);
    dst[len] = '\0';
}

static void dc_compute_stamp(const FrdcPack *pack, const char *exe_path, char *out, size_t cap) {
    const char *ov = getenv("FRDC_DAEMON_STAMP");
    if (ov && ov[0] != '\0') {
        dc_trim_copy(ov, out, cap);
        if (out[0] != '\0') return;
    }
    /* Read CRC32 from cli_cache.bin header bytes 16..19 when pack is loaded */
    if (pack && pack->buf && pack->buf_len >= 20u &&
        memcmp(pack->buf, "FRDCACHE", 8) == 0) {
        uint32_t crc = frdc_rd_u32(pack->buf + 16);
        snprintf(out, cap, "%08x", (unsigned int)crc);
        return;
    }
    (void)exe_path;
    FrdcSlice cli_ver;
    if (pack && frdc_pack_meta(pack, "cli_version", &cli_ver) == 0 && cli_ver.len > 0) {
        uint32_t h = dc_fnv1a32((const char *)cli_ver.ptr, cli_ver.len);
        snprintf(out, cap, "%08x", (unsigned int)h);
        return;
    }
    snprintf(out, cap, "%08x", (unsigned int)dc_fnv1a32("frdc", 4));
}

static int dc_is_propagated_env_name(const char *name, size_t len) {
    if (len >= 5 && memcmp(name, "FRDC_", 5) == 0) return 1;
    if (len >= 9 && memcmp(name, "FRIEDMAN_", 9) == 0) return 1;
    if ((len == 8 && memcmp(name, "NO_COLOR", 8) == 0) ||
        (len == 7 && memcmp(name, "COLUMNS", 7) == 0) ||
        (len == 5 && memcmp(name, "LINES", 5) == 0) ||
        (len == 2 && memcmp(name, "TZ", 2) == 0)) {
        return 1;
    }
    return 0;
}

static int dc_should_bypass_cmd(const char *cmd_path) {
    if (!cmd_path || cmd_path[0] == '\0') return 0;
    if (strcmp(cmd_path, "repl") == 0 ||
        strcmp(cmd_path, "serve") == 0 ||
        strncmp(cmd_path, "daemon", 6) == 0) {
        return 1;
    }
    if (!dc_env_is_false(getenv("FRDC_DAEMON_BYPASS_HEAVY"))) {
        if (strncmp(cmd_path, "dsge bayes", 10) == 0 ||
            strcmp(cmd_path, "hadsge solve") == 0 ||
            strcmp(cmd_path, "hadsge transition") == 0) {
            return 1;
        }
    }
    return 0;
}

/* Build length-prefixed JSON request frame for op="exec" */
static uint8_t *dc_build_exec_frame(int argc, char **argv, int acquire_ms, size_t *out_len) {
    yyjson_mut_doc *doc = yyjson_mut_doc_new(NULL);
    if (!doc) return NULL;
    yyjson_mut_val *root = yyjson_mut_obj(doc);
    yyjson_mut_doc_set_root(doc, root);

    yyjson_mut_obj_add_str(doc, root, "op", "exec");
    yyjson_mut_obj_add_int(doc, root, "acquire_ms", acquire_ms);
    yyjson_mut_obj_add_bool(doc, root, "is_tty", frdc_stdout_is_tty() != 0);

    yyjson_mut_val *jargv = yyjson_mut_arr(doc);
    for (int i = 1; i < argc; i++) {
        yyjson_mut_arr_add_str(doc, jargv, argv[i] ? argv[i] : "");
    }
    yyjson_mut_obj_add_val(doc, root, "argv", jargv);

    char cwd[DAEMON_PATH_MAX];
    cwd[0] = '\0';
#ifdef _WIN32
    wchar_t wcwd[DAEMON_PATH_MAX];
    DWORD wclen = GetCurrentDirectoryW(DAEMON_PATH_MAX, wcwd);
    if (wclen > 0 && wclen < DAEMON_PATH_MAX) {
        if (WideCharToMultiByte(CP_UTF8, 0, wcwd, -1, cwd, (int)sizeof(cwd), NULL, NULL) <= 0) {
            cwd[0] = '\0';
        }
    }
#else
    if (getcwd(cwd, sizeof(cwd)) == NULL) cwd[0] = '\0';
#endif
    yyjson_mut_obj_add_strcpy(doc, root, "cwd", cwd);

    yyjson_mut_val *jenv = yyjson_mut_obj(doc);
#ifdef _WIN32
    LPWCH env_block = GetEnvironmentStringsW();
    if (env_block) {
        for (const wchar_t *wentry = env_block; *wentry != L'\0'; wentry += wcslen(wentry) + 1) {
            int u8len = WideCharToMultiByte(CP_UTF8, 0, wentry, -1, NULL, 0, NULL, NULL);
            if (u8len <= 1 || u8len > 65536) continue;
            char *entry = (char *)malloc((size_t)u8len);
            if (!entry) continue;
            if (WideCharToMultiByte(CP_UTF8, 0, wentry, -1, entry, u8len, NULL, NULL) > 0) {
                const char *eq = strchr(entry, '=');
                if (eq && eq != entry) {
                    size_t klen = (size_t)(eq - entry);
                    if (dc_is_propagated_env_name(entry, klen)) {
                        yyjson_mut_val *jk = yyjson_mut_strncpy(doc, entry, klen);
                        yyjson_mut_val *jv = yyjson_mut_strcpy(doc, eq + 1);
                        if (jk && jv) yyjson_mut_obj_add(jenv, jk, jv);
                    }
                }
            }
            free(entry);
        }
        FreeEnvironmentStringsW(env_block);
    }
#else
    if (environ) {
        for (char **ep = environ; *ep != NULL; ep++) {
            const char *entry = *ep;
            const char *eq = strchr(entry, '=');
            if (!eq || eq == entry) continue;
            size_t klen = (size_t)(eq - entry);
            if (!dc_is_propagated_env_name(entry, klen)) continue;
            yyjson_mut_val *jk = yyjson_mut_strncpy(doc, entry, klen);
            yyjson_mut_val *jv = yyjson_mut_strcpy(doc, eq + 1);
            if (jk && jv) yyjson_mut_obj_add(jenv, jk, jv);
        }
    }
#endif
    yyjson_mut_obj_add_val(doc, root, "env", jenv);

    size_t jlen = 0;
    char *json = yyjson_mut_write(doc, 0, &jlen);
    yyjson_mut_doc_free(doc);
    if (!json || jlen == 0 || jlen > DAEMON_MAX_FRAME) {
        free(json);
        return NULL;
    }

    uint8_t *frame = (uint8_t *)malloc(4u + jlen);
    if (!frame) {
        free(json);
        return NULL;
    }
    frame[0] = (uint8_t)(jlen & 0xffu);
    frame[1] = (uint8_t)((jlen >> 8) & 0xffu);
    frame[2] = (uint8_t)((jlen >> 16) & 0xffu);
    frame[3] = (uint8_t)((jlen >> 24) & 0xffu);
    memcpy(frame + 4, json, jlen);
    free(json);
    *out_len = 4u + jlen;
    return frame;
}

#ifndef _WIN32
/* ── POSIX Unix Domain Socket + flock implementation ───────────────────── */

static uint64_t dc_mono_ms(void) {
    struct timespec ts;
    memset(&ts, 0, sizeof(ts));
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0) {
        return (uint64_t)ts.tv_sec * 1000ull + (uint64_t)(ts.tv_nsec / 1000000l);
    }
    return 0;
}

static int dc_mkdir_0700(const char *dir) {
    if (!dir || dir[0] == '\0') return -1;
    char tmp[DAEMON_PATH_MAX];
    size_t len = strlen(dir);
    if (len >= sizeof(tmp)) return -1;
    memcpy(tmp, dir, len + 1);
    while (len > 1 && tmp[len - 1] == '/') tmp[--len] = '\0';
    for (size_t i = 1; i <= len; i++) {
        if (tmp[i] == '/' || tmp[i] == '\0') {
            char saved = tmp[i];
            tmp[i] = '\0';
            if (mkdir(tmp, 0700) != 0 && errno != EEXIST) return -1;
            tmp[i] = saved;
        }
    }
    struct stat st;
    memset(&st, 0, sizeof(st));
    if (stat(tmp, &st) != 0 || !S_ISDIR(st.st_mode)) return -1;
    chmod(tmp, 0700);
    return 0;
}

static int dc_posix_runtime_dir(char *out, size_t cap) {
    const char *ov = getenv("FRDC_DAEMON_DIR");
    if (ov && ov[0] != '\0') {
        dc_trim_copy(ov, out, cap);
        if (out[0] != '\0') return dc_mkdir_0700(out);
    }
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (xdg && xdg[0] != '\0') {
        struct stat st;
        memset(&st, 0, sizeof(st));
        if (stat(xdg, &st) == 0 && S_ISDIR(st.st_mode)) {
            int n = snprintf(out, cap, "%s/frdc", xdg);
            if (n > 0 && (size_t)n < cap && dc_mkdir_0700(out) == 0) return 0;
        }
    }
    const char *tmp = getenv("TMPDIR");
    char tbase[DAEMON_PATH_MAX];
    if (tmp && tmp[0] != '\0') {
        dc_trim_copy(tmp, tbase, sizeof(tbase));
        size_t tl = strlen(tbase);
        while (tl > 1 && tbase[tl - 1] == '/') tbase[--tl] = '\0';
    } else {
        strcpy(tbase, "/tmp");
    }
    int n = snprintf(out, cap, "%s/frdc-%lu", tbase, (unsigned long)geteuid());
    if (n <= 0 || (size_t)n >= cap) return -1;
    return dc_mkdir_0700(out);
}

static int dc_posix_connect(const char *sock_path) {
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    if (strlen(sock_path) >= sizeof(addr.sun_path)) return -1;
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, sock_path);

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        close(fd);
        return -1;
    }
    return fd;
}

static int dc_posix_write_all(int fd, const uint8_t *buf, size_t len) {
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

/* Read exactly `len` bytes with optional timeout_ms (< 0 means block indefinitely). */
static int dc_posix_read_exact(int fd, uint8_t *buf, size_t len, int timeout_ms) {
    size_t off = 0;
    uint64_t deadline = (timeout_ms >= 0) ? (dc_mono_ms() + (uint64_t)timeout_ms) : 0;
    while (off < len) {
        if (timeout_ms >= 0) {
            uint64_t now = dc_mono_ms();
            if (now >= deadline) return -2; /* timeout */
            int rem = (int)(deadline - now);
            struct pollfd pfd;
            memset(&pfd, 0, sizeof(pfd));
            pfd.fd = fd;
            pfd.events = POLLIN;
            int pr = poll(&pfd, 1, rem);
            if (pr == 0) return -2;
            if (pr < 0) {
                if (errno == EINTR) continue;
                return -1;
            }
        }
        ssize_t n = read(fd, buf + off, len - off);
        if (n < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        if (n == 0) return -1; /* EOF */
        off += (size_t)n;
    }
    return 0;
}

/* Read one length-prefixed JSON frame. Returns 0 on success, -2 on timeout, -1 on EOF/error. */
static int dc_posix_read_frame(int fd, int timeout_ms, char **out_json, size_t *out_len) {
    uint8_t hdr[4];
    int rc = dc_posix_read_exact(fd, hdr, 4, timeout_ms);
    if (rc != 0) return rc;
    uint32_t flen = frdc_rd_u32(hdr);
    if (flen == 0 || flen > DAEMON_MAX_FRAME) return -1;
    char *buf = (char *)malloc((size_t)flen + 1u);
    if (!buf) return -1;
    rc = dc_posix_read_exact(fd, (uint8_t *)buf, (size_t)flen, timeout_ms);
    if (rc != 0) {
        free(buf);
        return rc;
    }
    buf[flen] = '\0';
    *out_json = buf;
    *out_len = (size_t)flen;
    return 0;
}

static int dc_posix_ping(const char *sock_path, int timeout_ms) {
    int fd = dc_posix_connect(sock_path);
    if (fd < 0) return -1;
    const char *ping_json = "{\"op\":\"ping\"}";
    size_t plen = strlen(ping_json);
    uint8_t frame[4 + 32];
    frame[0] = (uint8_t)(plen & 0xffu);
    frame[1] = (uint8_t)((plen >> 8) & 0xffu);
    frame[2] = (uint8_t)((plen >> 16) & 0xffu);
    frame[3] = (uint8_t)((plen >> 24) & 0xffu);
    memcpy(frame + 4, ping_json, plen);
    if (dc_posix_write_all(fd, frame, 4u + plen) != 0) {
        close(fd);
        return -1;
    }
    char *resp = NULL;
    size_t rlen = 0;
    int rc = dc_posix_read_frame(fd, timeout_ms, &resp, &rlen);
    close(fd);
    if (rc != 0 || !resp) {
        free(resp);
        return -1;
    }
    int ok = (strstr(resp, "\"ok\":true") != NULL) ? 0 : -1;
    free(resp);
    return ok;
}

static int dc_posix_spawn_daemon(const char *exe_path, const char *sock_path, const char *stamp) {
    char core_path[DAEMON_PATH_MAX];
    int is_dev = 0;
    if (frdc_resolve_core_path(exe_path, core_path, sizeof(core_path), &is_dev) != 0) {
        return -1;
    }
    pid_t pid = fork();
    if (pid < 0) return -1;
    if (pid == 0) {
        /* Detach cleanly into new session + redirect stdio to /dev/null so caller pipes close immediately */
        setsid();
        int devnull = open("/dev/null", O_RDWR);
        if (devnull >= 0) {
            dup2(devnull, STDIN_FILENO);
            dup2(devnull, STDOUT_FILENO);
            dup2(devnull, STDERR_FILENO);
            if (devnull > 2) close(devnull);
        }
        /* Double-fork so init/launchd reaps the daemon (zero zombies in caller) */
        pid_t pid2 = fork();
        if (pid2 < 0) _exit(1);
        if (pid2 > 0) _exit(0);

        if (stamp && stamp[0] != '\0') setenv("FRDC_DAEMON_STAMP", stamp, 1);

        if (!is_dev) {
            char *dargv[4];
            dargv[0] = core_path;
            dargv[1] = (char *)"--daemon-serve";
            dargv[2] = (char *)sock_path;
            dargv[3] = NULL;
            execv(core_path, dargv);
            _exit(127);
        } else {
            char proj_flag[DAEMON_PATH_MAX + 16];
            char script_path[DAEMON_PATH_MAX + 16];
            snprintf(proj_flag, sizeof(proj_flag), "--project=%s", core_path);
            snprintf(script_path, sizeof(script_path), "%s/bin/frdc", core_path);
            char *jargv[7];
            jargv[0] = (char *)"julia";
            jargv[1] = proj_flag;
            jargv[2] = (char *)"--";
            jargv[3] = script_path;
            jargv[4] = (char *)"--daemon-serve";
            jargv[5] = (char *)sock_path;
            jargv[6] = NULL;
            execvp("julia", jargv);
            _exit(127);
        }
    }
    /* Reap intermediate child immediately */
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {}
    return 0;
}

/* Ensure daemon is listening using single-rendezvous flock(LOCK_EX) + double-checked connect. */
static int dc_posix_ensure_daemon(const char *exe_path, const char *sock_path,
                                  const char *lock_path, const char *stamp) {
    /* Fast path: already listening */
    int fd = dc_posix_connect(sock_path);
    if (fd >= 0) return fd;

    /* Slow path: acquire exclusive bootstrap lock to prevent spawn storms */
    int lfd = open(lock_path, O_CREAT | O_RDWR, 0600);
    if (lfd < 0) return -1;
    while (flock(lfd, LOCK_EX) != 0) {
        if (errno == EINTR) continue;
        close(lfd);
        return -1;
    }

    /* Double-checked connect: another agent may have spawned while we waited */
    fd = dc_posix_connect(sock_path);
    if (fd >= 0) {
        flock(lfd, LOCK_UN);
        close(lfd);
        return fd;
    }

    /* Clean dead stale socket and spawn exactly one worker */
    unlink(sock_path);
    if (dc_posix_spawn_daemon(exe_path, sock_path, stamp) == 0) {
        int boot_wait_ms = dc_parse_pos_int_env("FRDC_DAEMON_BOOT_MS", 20000, 60000);
        uint64_t deadline = dc_mono_ms() + (uint64_t)boot_wait_ms;
        while (dc_mono_ms() < deadline) {
            if (dc_posix_ping(sock_path, 500) == 0) {
                fd = dc_posix_connect(sock_path);
                break;
            }
            struct timespec sl;
            sl.tv_sec = 0;
            sl.tv_nsec = 40 * 1000 * 1000; /* 40 ms */
            nanosleep(&sl, NULL);
        }
    }

    flock(lfd, LOCK_UN);
    close(lfd);
    return fd;
}

#else
/* ── Windows Named Pipe + CreateMutexW implementation ──────────────────── */

static int dc_win_write_all(HANDLE h, const uint8_t *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        DWORD chunk = (DWORD)((len - off) > 0x100000u ? 0x100000u : (len - off));
        DWORD written = 0;
        if (!WriteFile(h, buf + off, chunk, &written, NULL) || written == 0) return -1;
        off += (size_t)written;
    }
    return 0;
}

static int dc_win_read_exact(HANDLE h, uint8_t *buf, size_t len) {
    size_t off = 0;
    while (off < len) {
        DWORD chunk = (DWORD)((len - off) > 0x100000u ? 0x100000u : (len - off));
        DWORD got = 0;
        if (!ReadFile(h, buf + off, chunk, &got, NULL) || got == 0) return -1;
        off += (size_t)got;
    }
    return 0;
}

static int dc_win_read_frame(HANDLE h, int timeout_ms, char **out_json, size_t *out_len) {
    if (timeout_ms >= 0) {
        ULONGLONG deadline = GetTickCount64() + (ULONGLONG)timeout_ms;
        for (;;) {
            DWORD avail = 0;
            if (!PeekNamedPipe(h, NULL, 0, NULL, &avail, NULL)) return -1;
            if (avail >= 4) break;
            if (GetTickCount64() >= deadline) return -2;
            Sleep(5);
        }
    }
    uint8_t hdr[4];
    if (dc_win_read_exact(h, hdr, 4) != 0) return -1;
    uint32_t flen = frdc_rd_u32(hdr);
    if (flen == 0 || flen > DAEMON_MAX_FRAME) return -1;
    char *buf = (char *)malloc((size_t)flen + 1u);
    if (!buf) return -1;
    if (dc_win_read_exact(h, (uint8_t *)buf, (size_t)flen) != 0) {
        free(buf);
        return -1;
    }
    buf[flen] = '\0';
    *out_json = buf;
    *out_len = (size_t)flen;
    return 0;
}

static HANDLE dc_win_connect(const wchar_t *wpipe, int wait_ms) {
    HANDLE h = CreateFileW(wpipe, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (h != INVALID_HANDLE_VALUE) return h;
    if (GetLastError() == ERROR_PIPE_BUSY && wait_ms > 0) {
        if (WaitNamedPipeW(wpipe, (DWORD)wait_ms)) {
            h = CreateFileW(wpipe, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
            if (h != INVALID_HANDLE_VALUE) return h;
        }
    }
    return INVALID_HANDLE_VALUE;
}

static int dc_win_spawn_daemon(const char *exe_path, const char *pipe_name, const char *stamp) {
    char core_path[DAEMON_PATH_MAX];
    int is_dev = 0;
    if (frdc_resolve_core_path(exe_path, core_path, sizeof(core_path), &is_dev) != 0 || is_dev) {
        return -1;
    }
    if (stamp && stamp[0] != '\0') {
        wchar_t wstamp[128];
        if (MultiByteToWideChar(CP_UTF8, 0, stamp, -1, wstamp, 128) > 0) {
            SetEnvironmentVariableW(L"FRDC_DAEMON_STAMP", wstamp);
        }
    }
    char cmd_u8[DAEMON_PATH_MAX * 2];
    int n = snprintf(cmd_u8, sizeof(cmd_u8), "\"%s\" --daemon-serve \"%s\"", core_path, pipe_name);
    if (n <= 0 || (size_t)n >= sizeof(cmd_u8)) return -1;

    wchar_t wcore[DAEMON_PATH_MAX];
    wchar_t wcmd[DAEMON_PATH_MAX * 2];
    if (MultiByteToWideChar(CP_UTF8, 0, core_path, -1, wcore, DAEMON_PATH_MAX) <= 0 ||
        MultiByteToWideChar(CP_UTF8, 0, cmd_u8, -1, wcmd, DAEMON_PATH_MAX * 2) <= 0) {
        return -1;
    }
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    memset(&si, 0, sizeof(si));
    memset(&pi, 0, sizeof(pi));
    si.cb = sizeof(si);
    BOOL ok = CreateProcessW(wcore, wcmd, NULL, NULL, FALSE,
                             DETACHED_PROCESS | CREATE_NO_WINDOW,
                             NULL, NULL, &si, &pi);
    if (!ok) return -1;
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
#endif

/* Process final response JSON frame. Returns exit code >= 0, or -1 to fail open. */
static int dc_handle_done_json(const char *json, size_t jlen) {
    yyjson_doc *doc = yyjson_read(json, jlen, 0);
    if (!doc) return -1;
    yyjson_val *root = yyjson_doc_get_root(doc);
    yyjson_val *v_done = yyjson_obj_get(root, "done");
    if (!v_done || !yyjson_get_bool(v_done)) {
        yyjson_doc_free(doc);
        return -1;
    }
    yyjson_val *v_out = yyjson_obj_get(root, "stdout");
    yyjson_val *v_err = yyjson_obj_get(root, "stderr");
    yyjson_val *v_rc  = yyjson_obj_get(root, "exit_code");

    if (v_out && yyjson_is_str(v_out)) {
        const char *s = yyjson_get_str(v_out);
        size_t slen = yyjson_get_len(v_out);
        if (s && slen > 0) frdc_write_all_stdout((const uint8_t *)s, slen);
    }
    if (v_err && yyjson_is_str(v_err)) {
        const char *s = yyjson_get_str(v_err);
        size_t slen = yyjson_get_len(v_err);
        if (s && slen > 0) frdc_write_all_stderr((const uint8_t *)s, slen);
    }
    int rc = (v_rc && yyjson_is_int(v_rc)) ? (int)yyjson_get_sint(v_rc) : 1;
    yyjson_doc_free(doc);
    return rc;
}

/* Try executing via the opt-in resident worker daemon (FRDC_DAEMON=1).
 * Returns process exit code (>= 0) when handled by daemon, or -1 to fail open to frdc-core.
 */
int frdc_daemon_try_exec(const FrdcPack *pack, const char *exe_path,
                         int argc, char **argv,
                         const char *cmd_path, int effective_threads) {
    if (!dc_env_is_true(getenv("FRDC_DAEMON"))) return -1;
    if (dc_env_is_true(getenv("FRDC_NO_DAEMON"))) return -1;
    if (dc_should_bypass_cmd(cmd_path)) return -1;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--julia-args") == 0 || strcmp(argv[i], "--daemon-serve") == 0) {
            return -1;
        }
    }

    int acquire_ms = dc_parse_pos_int_env("FRDC_DAEMON_ACQUIRE_MS", 200, 30000);
    if (effective_threads < 1) effective_threads = 1;

    char stamp[64];
    dc_compute_stamp(pack, exe_path, stamp, sizeof(stamp));

    char root_buf[DAEMON_PATH_MAX];
    dc_trim_copy(getenv("FRDC_DATA_ROOT"), root_buf, sizeof(root_buf));
    uint32_t rhash = dc_fnv1a32(root_buf, strlen(root_buf));

    size_t req_len = 0;
    uint8_t *req_frame = dc_build_exec_frame(argc, argv, acquire_ms, &req_len);
    if (!req_frame) return -1;

#ifndef _WIN32
    char rdir[DAEMON_PATH_MAX];
    if (dc_posix_runtime_dir(rdir, sizeof(rdir)) != 0) {
        free(req_frame);
        return -1;
    }
    char sock_path[DAEMON_PATH_MAX];
    char lock_path[DAEMON_PATH_MAX];
    int sn = snprintf(sock_path, sizeof(sock_path), "%s/d-%s-t%d-%08x.sock",
                      rdir, stamp, effective_threads, (unsigned int)rhash);
    int ln = snprintf(lock_path, sizeof(lock_path), "%s/d-%s-t%d-%08x.lock",
                      rdir, stamp, effective_threads, (unsigned int)rhash);
    if (sn <= 0 || (size_t)sn >= sizeof(sock_path) ||
        ln <= 0 || (size_t)ln >= sizeof(lock_path)) {
        free(req_frame);
        return -1;
    }

    int fd = dc_posix_ensure_daemon(exe_path, sock_path, lock_path, stamp);
    if (fd < 0) {
        free(req_frame);
        return -1;
    }

    if (dc_posix_write_all(fd, req_frame, req_len) != 0) {
        close(fd);
        free(req_frame);
        return -1;
    }
    free(req_frame);

    /* Phase 1: wait up to acquire_ms + 50 ms for {"ack":true} or {"busy":true} */
    char *p1 = NULL;
    size_t p1_len = 0;
    int r1 = dc_posix_read_frame(fd, acquire_ms + 50, &p1, &p1_len);
    if (r1 != 0 || !p1) {
        free(p1);
        close(fd);
        return -1; /* timeout or worker dropped before ack -> fail open */
    }
    int got_ack = (strstr(p1, "\"ack\":true") != NULL);
    free(p1);
    if (!got_ack) {
        /* Worker replied {"busy":true} -> fail open cleanly to one-shot frdc-core */
        close(fd);
        return -1;
    }

    /* Phase 2: daemon owns execution; block until {"done":true,...} or EOF (e.g. SIGKILL) */
    char *p2 = NULL;
    size_t p2_len = 0;
    int r2 = dc_posix_read_frame(fd, -1, &p2, &p2_len);
    close(fd);
    if (r2 != 0 || !p2) {
        free(p2);
        const char *emsg = "Error: daemon worker terminated unexpectedly\n";
        frdc_write_all_stderr((const uint8_t *)emsg, strlen(emsg));
        return 1;
    }
    int rc = dc_handle_done_json(p2, p2_len);
    free(p2);
    return rc;
#else
    char user_buf[128];
    dc_trim_copy(getenv("USERNAME"), user_buf, sizeof(user_buf));
    if (user_buf[0] == '\0') strcpy(user_buf, "user");
    for (size_t i = 0; user_buf[i] != '\0'; i++) {
        unsigned char c = (unsigned char)user_buf[i];
        if (!isalnum(c) && c != '_' && c != '-') user_buf[i] = '_';
    }
    char pipe_u8[512];
    int pn = snprintf(pipe_u8, sizeof(pipe_u8), "\\\\.\\pipe\\frdc-%s-d-%s-t%d-%08x",
                      user_buf, stamp, effective_threads, (unsigned int)rhash);
    if (pn <= 0 || (size_t)pn >= sizeof(pipe_u8)) {
        free(req_frame);
        return -1;
    }
    wchar_t wpipe[512];
    if (MultiByteToWideChar(CP_UTF8, 0, pipe_u8, -1, wpipe, 512) <= 0) {
        free(req_frame);
        return -1;
    }

    HANDLE h = dc_win_connect(wpipe, acquire_ms);
    if (h == INVALID_HANDLE_VALUE) {
        char mtx_u8[256];
        snprintf(mtx_u8, sizeof(mtx_u8), "Local\\frdc-boot-%s-t%d-%08x",
                 stamp, effective_threads, (unsigned int)rhash);
        wchar_t wmtx[256];
        if (MultiByteToWideChar(CP_UTF8, 0, mtx_u8, -1, wmtx, 256) <= 0) {
            free(req_frame);
            return -1;
        }
        HANDLE mtx = CreateMutexW(NULL, FALSE, wmtx);
        if (!mtx) {
            free(req_frame);
            return -1;
        }
        DWORD wr = WaitForSingleObject(mtx, 30000);
        if (wr == WAIT_OBJECT_0 || wr == WAIT_ABANDONED) {
            h = dc_win_connect(wpipe, 50);
            if (h == INVALID_HANDLE_VALUE &&
                dc_win_spawn_daemon(exe_path, pipe_u8, stamp) == 0) {
                int boot_wait_ms = dc_parse_pos_int_env("FRDC_DAEMON_BOOT_MS", 20000, 60000);
                ULONGLONG deadline = GetTickCount64() + (ULONGLONG)boot_wait_ms;
                while (GetTickCount64() < deadline) {
                    h = dc_win_connect(wpipe, 100);
                    if (h != INVALID_HANDLE_VALUE) break;
                    Sleep(50);
                }
            }
            ReleaseMutex(mtx);
        }
        CloseHandle(mtx);
    }

    if (h == INVALID_HANDLE_VALUE) {
        free(req_frame);
        return -1;
    }
    if (dc_win_write_all(h, req_frame, req_len) != 0) {
        CloseHandle(h);
        free(req_frame);
        return -1;
    }
    free(req_frame);

    char *p1 = NULL;
    size_t p1_len = 0;
    int r1 = dc_win_read_frame(h, acquire_ms + 50, &p1, &p1_len);
    if (r1 != 0 || !p1) {
        free(p1);
        CloseHandle(h);
        return -1;
    }
    int got_ack = (strstr(p1, "\"ack\":true") != NULL);
    free(p1);
    if (!got_ack) {
        CloseHandle(h);
        return -1;
    }

    char *p2 = NULL;
    size_t p2_len = 0;
    int r2 = dc_win_read_frame(h, -1, &p2, &p2_len);
    CloseHandle(h);
    if (r2 != 0 || !p2) {
        free(p2);
        const char *emsg = "Error: daemon worker terminated unexpectedly\n";
        frdc_write_all_stderr((const uint8_t *)emsg, strlen(emsg));
        return 1;
    }
    int rc = dc_handle_done_json(p2, p2_len);
    free(p2);
    return rc;
#endif
}
