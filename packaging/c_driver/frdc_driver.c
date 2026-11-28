// Standalone C entry-point driver for Friedman-cli.
// Derived from PackageCompiler.jl's src/embedding_wrapper.c (MIT License,
// Copyright (c) 2018-2026 Kristoffer Carlsson and contributors).
//
// Modifications for Friedman-cli ([PERF-W2] #356):
//   - Resolves a version+build-stamp-keyed per-user writable local cache dir
//     (overridable via FRDC_CACHE_DIR) and validates recursive mkdir, local
//     filesystem (rejecting NFS/SMB/CIFS/FUSE/network drives), and an actual
//     write probe before enabling JULIA_OBJCACHE=1 and prepending the cache
//     dir ahead of JULIA_DEPOT_PATH.
//   - Respects FRDC_OBJCACHE=0 and JULIA_OBJCACHE=0 opt-outs with zero disk
//     writes.
//   - Fails open silently to JULIA_OBJCACHE=0 with ZERO stderr on any
//     read-only, MSIX, sandboxed, network-FS, or unset-HOME environment.
//   - Best-effort prunes stale `objcache-*` directories from older builds.

#ifdef __APPLE__
#ifndef _DARWIN_C_SOURCE
#define _DARWIN_C_SOURCE
#endif
#elif !defined(_WIN32)
#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif
#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif

// Standard headers
#include <ctype.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Julia headers
#include "julia.h"
#include "uv.h"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <direct.h>
#include <sys/stat.h>
#else
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef __APPLE__
#include <sys/param.h>
#include <sys/mount.h>
#include <sys/sysctl.h>
#elif defined(__linux__)
#include <sys/vfs.h>
#endif
#endif

#ifdef _MSC_VER
JL_DLLEXPORT char *dirname(char *);
#else
#include <libgen.h>
#endif

#ifdef NEW_DEFINE_FAST_TLS_SYNTAX
JULIA_DEFINE_FAST_TLS
#else
JULIA_DEFINE_FAST_TLS()
#endif

#define FRDC_DRV_PATH_MAX 4096

static void drv_set_env(const char *name, const char *val) {
#ifdef _WIN32
    _putenv_s(name, val);
    wchar_t wname[128];
    wchar_t wval[FRDC_DRV_PATH_MAX];
    if (MultiByteToWideChar(CP_UTF8, 0, name, -1, wname, 128) > 0 &&
        MultiByteToWideChar(CP_UTF8, 0, val, -1, wval, FRDC_DRV_PATH_MAX) > 0) {
        SetEnvironmentVariableW(wname, wval);
    }
#else
    setenv(name, val, 1);
#endif
}

static int drv_env_is_disabled(const char *val) {
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

static uint32_t drv_rd_u32_le(const uint8_t *p) {
    return ((uint32_t)p[0]) |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

// Derive a deterministic build stamp from cli_cache.bin header CRC32 + sysimage size
// so upgrades automatically isolate their LMDB object caches.
static void drv_compute_build_stamp(const char *root_dir, char *out, size_t cap) {
    uint32_t pack_crc = 0;
    uint64_t sys_size = 0;
    char pbuf[FRDC_DRV_PATH_MAX];

#ifdef _WIN32
    int n1 = snprintf(pbuf, sizeof(pbuf), "%s\\share\\frdc\\cli_cache.bin", root_dir);
#else
    int n1 = snprintf(pbuf, sizeof(pbuf), "%s/share/frdc/cli_cache.bin", root_dir);
#endif
    if (n1 > 0 && (size_t)n1 < sizeof(pbuf)) {
        FILE *fp = fopen(pbuf, "rb");
        if (fp) {
            uint8_t hdr[20];
            memset(hdr, 0, sizeof(hdr));
            if (fread(hdr, 1, sizeof(hdr), fp) == sizeof(hdr) &&
                memcmp(hdr, "FRDCACHE", 8) == 0) {
                pack_crc = drv_rd_u32_le(hdr + 16);
            }
            fclose(fp);
        }
    }

#ifdef _WIN32
    int n2 = snprintf(pbuf, sizeof(pbuf), "%s\\lib\\julia\\sys.dll", root_dir);
#elif defined(__APPLE__)
    int n2 = snprintf(pbuf, sizeof(pbuf), "%s/lib/julia/sys.dylib", root_dir);
#else
    int n2 = snprintf(pbuf, sizeof(pbuf), "%s/lib/julia/sys.so", root_dir);
#endif
    if (n2 > 0 && (size_t)n2 < sizeof(pbuf)) {
        struct stat st;
        memset(&st, 0, sizeof(st));
        if (stat(pbuf, &st) == 0 && st.st_size > 0) {
            sys_size = (uint64_t)st.st_size;
        }
    }

    if (pack_crc == 0 && sys_size == 0) {
        snprintf(out, cap, "objcache-v%d_%d", JULIA_VERSION_MAJOR, JULIA_VERSION_MINOR);
    } else {
        snprintf(out, cap, "objcache-j%d_%d-%08x-%llx",
                 JULIA_VERSION_MAJOR, JULIA_VERSION_MINOR,
                 (unsigned int)pack_crc, (unsigned long long)sys_size);
    }
}

static int drv_mkdir_p(const char *dir) {
    if (!dir || dir[0] == '\0') return -1;
    char tmp[FRDC_DRV_PATH_MAX];
    size_t len = strlen(dir);
    if (len >= sizeof(tmp)) return -1;
    memcpy(tmp, dir, len + 1);

#ifdef _WIN32
    // Normalize slashes and create each component
    for (size_t i = 0; i < len; i++) {
        if (tmp[i] == '/') tmp[i] = '\\';
    }
    while (len > 3 && tmp[len - 1] == '\\') {
        tmp[--len] = '\0';
    }
    size_t start = 0;
    if (len >= 2 && tmp[1] == ':') start = 3;
    else if (len >= 2 && tmp[0] == '\\' && tmp[1] == '\\') return -1; // reject UNC network paths
    for (size_t i = start; i <= len; i++) {
        if (tmp[i] == '\\' || tmp[i] == '\0') {
            char saved = tmp[i];
            tmp[i] = '\0';
            if (tmp[0] != '\0') {
                wchar_t wtmp[FRDC_DRV_PATH_MAX];
                if (MultiByteToWideChar(CP_UTF8, 0, tmp, -1, wtmp, FRDC_DRV_PATH_MAX) <= 0) {
                    return -1;
                }
                if (!CreateDirectoryW(wtmp, NULL)) {
                    DWORD err = GetLastError();
                    if (err != ERROR_ALREADY_EXISTS) {
                        return -1;
                    }
                    DWORD attrs = GetFileAttributesW(wtmp);
                    if (attrs == INVALID_FILE_ATTRIBUTES || !(attrs & FILE_ATTRIBUTE_DIRECTORY)) {
                        return -1;
                    }
                }
            }
            tmp[i] = saved;
        }
    }
    return 0;
#else
    while (len > 1 && tmp[len - 1] == '/') {
        tmp[--len] = '\0';
    }
    for (size_t i = 1; i <= len; i++) {
        if (tmp[i] == '/' || tmp[i] == '\0') {
            char saved = tmp[i];
            tmp[i] = '\0';
            if (mkdir(tmp, 0700) != 0 && errno != EEXIST) {
                return -1;
            }
            if (saved == '\0') {
                struct stat st;
                memset(&st, 0, sizeof(st));
                if (stat(tmp, &st) != 0 || !S_ISDIR(st.st_mode)) {
                    return -1;
                }
            }
            tmp[i] = saved;
        }
    }
    return 0;
#endif
}

// Verify cache directory resides on a local filesystem (LMDB mmap+locking is unsafe on NFS/SMB/FUSE).
static int drv_is_local_fs(const char *path) {
#ifdef _WIN32
    wchar_t wpath[FRDC_DRV_PATH_MAX];
    wchar_t wvol[FRDC_DRV_PATH_MAX];
    if (MultiByteToWideChar(CP_UTF8, 0, path, -1, wpath, FRDC_DRV_PATH_MAX) <= 0) {
        return 0;
    }
    if (!GetVolumePathNameW(wpath, wvol, FRDC_DRV_PATH_MAX)) {
        return 0;
    }
    UINT dtype = GetDriveTypeW(wvol);
    return (dtype == DRIVE_FIXED) ? 1 : 0;
#elif defined(__APPLE__)
    struct statfs sfs;
    memset(&sfs, 0, sizeof(sfs));
    if (statfs(path, &sfs) != 0) return 0;
    if ((sfs.f_flags & MNT_LOCAL) == 0) return 0;
    if (strcmp(sfs.f_fstypename, "nfs") == 0 ||
        strcmp(sfs.f_fstypename, "smbfs") == 0 ||
        strcmp(sfs.f_fstypename, "afpfs") == 0 ||
        strcmp(sfs.f_fstypename, "webdav") == 0 ||
        strcmp(sfs.f_fstypename, "autofs") == 0 ||
        strstr(sfs.f_fstypename, "fuse") != NULL) {
        return 0;
    }
    return 1;
#elif defined(__linux__)
    struct statfs sfs;
    memset(&sfs, 0, sizeof(sfs));
    if (statfs(path, &sfs) != 0) return 0;
    unsigned long ftype = (unsigned long)sfs.f_type;
    switch (ftype) {
        case 0x00006969ul: /* NFS_SUPER_MAGIC */
        case 0xFF534D42ul: /* CIFS_MAGIC_NUMBER */
        case 0xFE534D42ul: /* SMB2_MAGIC_NUMBER */
        case 0x0000517Bul: /* SMB_SUPER_MAGIC */
        case 0x65735546ul: /* FUSE_SUPER_MAGIC */
        case 0x65735543ul: /* FUSE_CTL_SUPER_MAGIC */
        case 0x01021997ul: /* V9FS_MAGIC */
        case 0x5346414Ful: /* AFS_SUPER_MAGIC */
        case 0x6B414653ul: /* AFS_FS_MAGIC */
        case 0x0000564Cul: /* NCP_SUPER_MAGIC */
        case 0x73757245ul: /* CODA_SUPER_MAGIC */
        case 0x47504653ul: /* GPFS */
        case 0x0BD00BD0ul: /* LUSTRE */
        case 0x00C36400ul: /* CEPH */
            return 0;
        default:
            return 1;
    }
#else
    (void)path;
    return 0;
#endif
}

// Prove actual write+unlink permission (handles read-only mounts, ACLs, MSIX sandboxes).
static int drv_write_probe(const char *dir) {
    char probe[FRDC_DRV_PATH_MAX];
#ifdef _WIN32
    DWORD pid = GetCurrentProcessId();
    int n = snprintf(probe, sizeof(probe), "%s\\.frdc_probe_%lu", dir, (unsigned long)pid);
    if (n <= 0 || (size_t)n >= sizeof(probe)) return -1;
    wchar_t wprobe[FRDC_DRV_PATH_MAX];
    if (MultiByteToWideChar(CP_UTF8, 0, probe, -1, wprobe, FRDC_DRV_PATH_MAX) <= 0) return -1;
    HANDLE h = CreateFileW(wprobe, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
                           FILE_ATTRIBUTE_TEMPORARY, NULL);
    if (h == INVALID_HANDLE_VALUE) return -1;
    CloseHandle(h);
    DeleteFileW(wprobe);
    return 0;
#else
    unsigned long pid = (unsigned long)getpid();
    int n = snprintf(probe, sizeof(probe), "%s/.frdc_probe_%lu", dir, pid);
    if (n <= 0 || (size_t)n >= sizeof(probe)) return -1;
    int fd = open(probe, O_CREAT | O_WRONLY | O_TRUNC, 0600);
    if (fd < 0) return -1;
    close(fd);
    unlink(probe);
    return 0;
#endif
}

// Best-effort recursive remove for stale objcache-* stamp directories (bounded depth).
static void drv_rm_tree_bounded(const char *path, int depth) {
    if (depth > 8) return;
#ifdef _WIN32
    char pattern[FRDC_DRV_PATH_MAX];
    int n = snprintf(pattern, sizeof(pattern), "%s\\*", path);
    if (n <= 0 || (size_t)n >= sizeof(pattern)) return;
    wchar_t wpat[FRDC_DRV_PATH_MAX];
    if (MultiByteToWideChar(CP_UTF8, 0, pattern, -1, wpat, FRDC_DRV_PATH_MAX) <= 0) return;
    WIN32_FIND_DATAW fd;
    memset(&fd, 0, sizeof(fd));
    HANDLE h = FindFirstFileW(wpat, &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            if (wcscmp(fd.cFileName, L".") == 0 || wcscmp(fd.cFileName, L"..") == 0) continue;
            char child_name[512];
            if (WideCharToMultiByte(CP_UTF8, 0, fd.cFileName, -1, child_name, sizeof(child_name), NULL, NULL) <= 0) continue;
            char child[FRDC_DRV_PATH_MAX];
            int cn = snprintf(child, sizeof(child), "%s\\%s", path, child_name);
            if (cn <= 0 || (size_t)cn >= sizeof(child)) continue;
            if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
                drv_rm_tree_bounded(child, depth + 1);
            } else {
                wchar_t wchild[FRDC_DRV_PATH_MAX];
                if (MultiByteToWideChar(CP_UTF8, 0, child, -1, wchild, FRDC_DRV_PATH_MAX) > 0) {
                    DeleteFileW(wchild);
                }
            }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    wchar_t wdir[FRDC_DRV_PATH_MAX];
    if (MultiByteToWideChar(CP_UTF8, 0, path, -1, wdir, FRDC_DRV_PATH_MAX) > 0) {
        RemoveDirectoryW(wdir);
    }
#else
    DIR *dp = opendir(path);
    if (!dp) return;
    struct dirent *de;
    while ((de = readdir(dp)) != NULL) {
        if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;
        char child[FRDC_DRV_PATH_MAX];
        int cn = snprintf(child, sizeof(child), "%s/%s", path, de->d_name);
        if (cn <= 0 || (size_t)cn >= sizeof(child)) continue;
        struct stat st;
        memset(&st, 0, sizeof(st));
        if (lstat(child, &st) == 0 && S_ISDIR(st.st_mode)) {
            drv_rm_tree_bounded(child, depth + 1);
        } else {
            unlink(child);
        }
    }
    closedir(dp);
    rmdir(path);
#endif
}

static void drv_prune_stale_stamps(const char *base_dir, const char *keep_name) {
    int pruned = 0;
#ifdef _WIN32
    char pattern[FRDC_DRV_PATH_MAX];
    int n = snprintf(pattern, sizeof(pattern), "%s\\objcache-*", base_dir);
    if (n <= 0 || (size_t)n >= sizeof(pattern)) return;
    wchar_t wpat[FRDC_DRV_PATH_MAX];
    if (MultiByteToWideChar(CP_UTF8, 0, pattern, -1, wpat, FRDC_DRV_PATH_MAX) <= 0) return;
    WIN32_FIND_DATAW fd;
    memset(&fd, 0, sizeof(fd));
    HANDLE h = FindFirstFileW(wpat, &fd);
    if (h != INVALID_HANDLE_VALUE) {
        do {
            if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;
            char name[512];
            if (WideCharToMultiByte(CP_UTF8, 0, fd.cFileName, -1, name, sizeof(name), NULL, NULL) <= 0) continue;
            if (strcmp(name, keep_name) == 0) continue;
            char full[FRDC_DRV_PATH_MAX];
            int fn = snprintf(full, sizeof(full), "%s\\%s", base_dir, name);
            if (fn > 0 && (size_t)fn < sizeof(full)) {
                drv_rm_tree_bounded(full, 0);
                if (++pruned >= 8) break;
            }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
#else
    DIR *dp = opendir(base_dir);
    if (!dp) return;
    struct dirent *de;
    while ((de = readdir(dp)) != NULL) {
        if (strncmp(de->d_name, "objcache-", 9) != 0) continue;
        if (strcmp(de->d_name, keep_name) == 0) continue;
        char full[FRDC_DRV_PATH_MAX];
        int fn = snprintf(full, sizeof(full), "%s/%s", base_dir, de->d_name);
        if (fn > 0 && (size_t)fn < sizeof(full)) {
            struct stat st;
            memset(&st, 0, sizeof(st));
            if (lstat(full, &st) == 0 && S_ISDIR(st.st_mode)) {
                drv_rm_tree_bounded(full, 0);
                if (++pruned >= 8) break;
            }
        }
    }
    closedir(dp);
#endif
}

// Resolve and validate a per-user writable local cache dir for JULIA_OBJCACHE=1.
// Returns 1 and writes cache_dir_out when safe to enable; returns 0 to fall back to JULIA_OBJCACHE=0.
static int drv_setup_objcache(const char *root_dir, char *cache_dir_out, size_t cap) {
    cache_dir_out[0] = '\0';

    const char *frdc_oc = getenv("FRDC_OBJCACHE");
    const char *jl_oc = getenv("JULIA_OBJCACHE");
    if (drv_env_is_disabled(frdc_oc) || drv_env_is_disabled(jl_oc)) {
        drv_set_env("JULIA_OBJCACHE", "0");
        return 0;
    }

    const char *override_dir = getenv("FRDC_CACHE_DIR");
    const char *curr_depot = getenv("JULIA_DEPOT_PATH");
    // If caller explicitly opted into JULIA_OBJCACHE=1 AND supplied a custom JULIA_DEPOT_PATH
    // (without FRDC_CACHE_DIR), honor their explicit depot directly.
    if (jl_oc && jl_oc[0] != '\0' && curr_depot && curr_depot[0] != '\0' &&
        (!override_dir || override_dir[0] == '\0')) {
        return 0;
    }

    char base_dir[FRDC_DRV_PATH_MAX];
    base_dir[0] = '\0';
    if (override_dir && override_dir[0] != '\0') {
        int n = snprintf(base_dir, sizeof(base_dir), "%s", override_dir);
        if (n <= 0 || (size_t)n >= sizeof(base_dir)) {
            drv_set_env("JULIA_OBJCACHE", "0");
            return 0;
        }
    } else {
#ifdef _WIN32
        const char *la = getenv("LOCALAPPDATA");
        if (!la || la[0] == '\0') {
            drv_set_env("JULIA_OBJCACHE", "0");
            return 0;
        }
        int n = snprintf(base_dir, sizeof(base_dir), "%s\\frdc\\cache", la);
        if (n <= 0 || (size_t)n >= sizeof(base_dir)) {
            drv_set_env("JULIA_OBJCACHE", "0");
            return 0;
        }
#elif defined(__APPLE__)
        const char *home = getenv("HOME");
        if (!home || home[0] == '\0') {
            drv_set_env("JULIA_OBJCACHE", "0");
            return 0;
        }
        int n = snprintf(base_dir, sizeof(base_dir), "%s/Library/Caches/frdc", home);
        if (n <= 0 || (size_t)n >= sizeof(base_dir)) {
            drv_set_env("JULIA_OBJCACHE", "0");
            return 0;
        }
#else
        const char *xdg = getenv("XDG_CACHE_HOME");
        int n = 0;
        if (xdg && xdg[0] != '\0') {
            n = snprintf(base_dir, sizeof(base_dir), "%s/frdc", xdg);
        } else {
            const char *home = getenv("HOME");
            if (!home || home[0] == '\0') {
                drv_set_env("JULIA_OBJCACHE", "0");
                return 0;
            }
            n = snprintf(base_dir, sizeof(base_dir), "%s/.cache/frdc", home);
        }
        if (n <= 0 || (size_t)n >= sizeof(base_dir)) {
            drv_set_env("JULIA_OBJCACHE", "0");
            return 0;
        }
#endif
    }

    char stamp[128];
    drv_compute_build_stamp(root_dir, stamp, sizeof(stamp));

    char full_dir[FRDC_DRV_PATH_MAX];
#ifdef _WIN32
    int fn = snprintf(full_dir, sizeof(full_dir), "%s\\%s", base_dir, stamp);
#else
    int fn = snprintf(full_dir, sizeof(full_dir), "%s/%s", base_dir, stamp);
#endif
    if (fn <= 0 || (size_t)fn >= sizeof(full_dir) || (size_t)fn >= cap) {
        drv_set_env("JULIA_OBJCACHE", "0");
        return 0;
    }

    if (drv_mkdir_p(full_dir) != 0 || !drv_is_local_fs(full_dir) || drv_write_probe(full_dir) != 0) {
        drv_set_env("JULIA_OBJCACHE", "0");
        return 0;
    }

    // Best-effort cleanup of stale stamps from previous frdc builds
    drv_prune_stale_stamps(base_dir, stamp);

    memcpy(cache_dir_out, full_dir, (size_t)fn + 1);
    drv_set_env("JULIA_OBJCACHE", "1");
    drv_set_env("FRDC_ACTIVE_OBJCACHE_DIR", cache_dir_out);
    return 1;
}

// Container- and P-core-aware `auto` thread budget: min(physical/P-cores, cgroup quota, 4) ([PERF-W4] #358).
static int drv_detect_auto_threads(void) {
    int cores = 1;
#ifdef _WIN32
    DWORD len = 0;
    GetLogicalProcessorInformationEx(RelationProcessorCore, NULL, &len);
    if (len > 0 && GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
        uint8_t *buf = (uint8_t *)malloc(len);
        if (buf) {
            if (GetLogicalProcessorInformationEx(RelationProcessorCore,
                    (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)buf, &len)) {
                int pcores = 0;
                DWORD off = 0;
                while (off + sizeof(SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX) <= len) {
                    PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX info =
                        (PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX)(buf + off);
                    if (info->Size == 0) break;
                    if (info->Relationship == RelationProcessorCore) pcores++;
                    off += info->Size;
                }
                if (pcores > 0) cores = pcores;
            }
            free(buf);
        }
    }
    if (cores <= 1) {
        SYSTEM_INFO si;
        memset(&si, 0, sizeof(si));
        GetSystemInfo(&si);
        if (si.dwNumberOfProcessors > 1) cores = (int)si.dwNumberOfProcessors;
    }
#elif defined(__APPLE__)
    int val = 0;
    size_t sz = sizeof(val);
    if (sysctlbyname("hw.perflevel0.physicalcpu", &val, &sz, NULL, 0) == 0 && val > 0) {
        cores = val;
    } else {
        sz = sizeof(val);
        if (sysctlbyname("hw.physicalcpu", &val, &sz, NULL, 0) == 0 && val > 0) {
            cores = val;
        } else {
            long n = sysconf(_SC_NPROCESSORS_ONLN);
            if (n > 0) cores = (int)n;
        }
    }
#else
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    if (n > 0) cores = (int)n;
#ifdef __linux__
    FILE *fp = fopen("/sys/fs/cgroup/cpu.max", "r");
    if (fp) {
        char qbuf[64];
        long long period = 0;
        if (fscanf(fp, "%63s %lld", qbuf, &period) == 2 &&
            strcmp(qbuf, "max") != 0 && period > 0) {
            char *endp = NULL;
            long long quota = strtoll(qbuf, &endp, 10);
            if (endp && *endp == '\0' && quota > 0) {
                int cg = (int)(quota / period);
                if (cg < 1) cg = 1;
                if (cg < cores) cores = cg;
            }
        }
        fclose(fp);
    } else {
        FILE *fq = fopen("/sys/fs/cgroup/cpu/cpu.cfs_quota_us", "r");
        FILE *fper = fopen("/sys/fs/cgroup/cpu/cpu.cfs_period_us", "r");
        if (fq && fper) {
            long long quota = -1, period = 0;
            if (fscanf(fq, "%lld", &quota) == 1 &&
                fscanf(fper, "%lld", &period) == 1 &&
                quota > 0 && period > 0) {
                int cg = (int)(quota / period);
                if (cg < 1) cg = 1;
                if (cg < cores) cores = cg;
            }
        }
        if (fq) fclose(fq);
        if (fper) fclose(fper);
    }
#endif
#endif
    if (cores < 1) cores = 1;
    if (cores > 4) cores = 4;
    return cores;
}

static int drv_parse_threads_val(const char *raw, int *out_n) {
    if (!raw) return -1;
    while (*raw == ' ' || *raw == '\t' || *raw == '\r' || *raw == '\n') raw++;
    size_t len = strlen(raw);
    while (len > 0 && (raw[len - 1] == ' ' || raw[len - 1] == '\t' ||
                       raw[len - 1] == '\r' || raw[len - 1] == '\n')) {
        len--;
    }
    if (len == 0) return -1;
    if (len == 4 &&
        tolower((unsigned char)raw[0]) == 'a' &&
        tolower((unsigned char)raw[1]) == 'u' &&
        tolower((unsigned char)raw[2]) == 't' &&
        tolower((unsigned char)raw[3]) == 'o') {
        *out_n = drv_detect_auto_threads();
        return 0;
    }
    int val = 0;
    for (size_t i = 0; i < len; i++) {
        if (raw[i] < '0' || raw[i] > '9') return -1;
        val = val * 10 + (raw[i] - '0');
        if (val > 1024) return -1;
    }
    if (val < 1) return -1;
    *out_n = val;
    return 0;
}

// Parse --threads / FRDC_THREADS / JULIA_NUM_THREADS BEFORE jl_init() ([PERF-W4] #358).
// Invalid values are left untouched so Julia's _extract_global_flags! emits schema-valid usage/bad-threads (exit 2).
static void drv_setup_threads(int argc, char **argv) {
    const char *cli_val = NULL;
    int cli_bad = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--") == 0) break;
        if (strcmp(argv[i], "--threads") == 0) {
            if (i + 1 < argc && strcmp(argv[i + 1], "--") != 0) {
                cli_val = argv[++i];
            } else {
                cli_bad = 1;
            }
        } else if (strncmp(argv[i], "--threads=", 10) == 0) {
            cli_val = argv[i] + 10;
        }
    }

    int effective = 1;
    int set_julia_env = 0;
    if (!cli_bad && cli_val != NULL) {
        if (drv_parse_threads_val(cli_val, &effective) == 0) {
            set_julia_env = 1;
        } else {
            return;
        }
    } else if (!cli_bad) {
        const char *env_frdc = getenv("FRDC_THREADS");
        if (env_frdc && env_frdc[0] != '\0') {
            if (drv_parse_threads_val(env_frdc, &effective) == 0) {
                set_julia_env = 1;
            } else {
                return;
            }
        } else {
            const char *env_jl = getenv("JULIA_NUM_THREADS");
            if (env_jl && env_jl[0] != '\0') {
                int tmp = 1;
                if (drv_parse_threads_val(env_jl, &tmp) == 0) {
                    effective = tmp;
                }
            }
        }
    }

    if (set_julia_env) {
        char nbuf[32];
        snprintf(nbuf, sizeof(nbuf), "%d", effective);
        drv_set_env("JULIA_NUM_THREADS", nbuf);
    }
    if (effective > 1) {
        const char *ob = getenv("OPENBLAS_NUM_THREADS");
        if (!ob || ob[0] == '\0') {
            drv_set_env("OPENBLAS_NUM_THREADS", "1");
        }
    }
}

jl_value_t *checked_eval_string(const char *code) {
    jl_value_t *result = jl_eval_string(code);
    if (jl_exception_occurred()) {
        // none of these allocate, so a gc-root (JL_GC_PUSH) is not necessary
        jl_call2(jl_get_function(jl_base_module, "showerror"), jl_stderr_obj(),
                 jl_exception_occurred());
        jl_printf(jl_stderr_stream(), "\n");
        jl_atexit_hook(1);
        exit(1);
    }
    assert(result && "Missing return value but no exception occurred!");
    return result;
}

void set_depot_load_path(const char *root_dir, const char *objcache_dir) {
#ifdef _WIN32
    const char *path_sep = ";";
    const char *julia_share_subdir = "\\share\\julia";
#else
    const char *path_sep = ":";
    const char *julia_share_subdir = "/share/julia";
#endif
    size_t share_path_len = strlen(root_dir) + strlen(julia_share_subdir) + 1;
    size_t cache_len = (objcache_dir && objcache_dir[0] != '\0') ? strlen(objcache_dir) : 0;

    const char *curr_depot_path = getenv("JULIA_DEPOT_PATH");
    size_t curr_depot_path_len = curr_depot_path == NULL ? 0 : strlen(curr_depot_path);
    size_t new_depot_path_len = cache_len + 1 + curr_depot_path_len + 1 + share_path_len + 2;
    char *new_depot_path = (char *)calloc(new_depot_path_len, sizeof(char));
    if (new_depot_path) {
        if (cache_len > 0) {
            strcat(new_depot_path, objcache_dir);
            strcat(new_depot_path, path_sep);
        }
        if (curr_depot_path_len > 0) {
            strcat(new_depot_path, curr_depot_path);
            strcat(new_depot_path, path_sep);
        }
        strcat(new_depot_path, root_dir);
        strcat(new_depot_path, julia_share_subdir);
        drv_set_env("JULIA_DEPOT_PATH", new_depot_path);
        free(new_depot_path);
    }

    const char *curr_load_path = getenv("JULIA_LOAD_PATH");
    size_t curr_load_path_len = curr_load_path == NULL ? 0 : strlen(curr_load_path);
    size_t new_load_path_len = curr_load_path_len + 1 + share_path_len + 2;
    char *new_load_path = (char *)calloc(new_load_path_len, sizeof(char));
    if (new_load_path) {
        if (curr_load_path_len > 0) {
            strcat(new_load_path, curr_load_path);
            strcat(new_load_path, path_sep);
        }
        strcat(new_load_path, root_dir);
        strcat(new_load_path, julia_share_subdir);
        drv_set_env("JULIA_LOAD_PATH", new_load_path);
        free(new_load_path);
    }
}

// main function (windows UTF16 -> UTF8 argument conversion code copied from
// julia's ui/repl.c)
#ifdef _WIN32
int wmain(int argc, wchar_t *wargv[], wchar_t *envp[]) {
    (void)envp;
    char **argv = (char **)malloc(sizeof(char *) * argc);
    if (!argv) return 1;

    for (int i = 0; i < argc; i++) { // write the command line to UTF8
        wchar_t *warg = wargv[i];
        size_t len = WideCharToMultiByte(CP_UTF8, 0, warg, -1, NULL, 0, NULL, NULL);
        if (!len) return 1;
        char *arg = (char *)malloc(len);
        if (!WideCharToMultiByte(CP_UTF8, 0, warg, -1, arg, (int)len, NULL, NULL)) return 1;
        argv[i] = arg;
    }
#else
int main(int argc, char *argv[]) {
    argv = uv_setup_args(argc, argv);
#endif

    // Find where eventual julia arguments start
    int program_argc = argc;
    for (int i = 0; i < argc; i++) {
        if (strcmp(argv[i], "--julia-args") == 0) {
            program_argc = i;
            break;
        }
    }
    int julia_argc = argc - program_argc;
    if (julia_argc > 0) {
        // Replace `--julia-args` with the program name
        argv[program_argc] = argv[0];
        char **julia_argv = &argv[program_argc];
        jl_parse_opts(&julia_argc, &julia_argv);
    }

    // Get the current exe path so we can compute a relative depot path
    char *exe_path = (char *)malloc(PATH_MAX);
    size_t path_size = PATH_MAX;
    if (!exe_path) {
        jl_errorf("fatal error: failed to allocate memory: %s",
                  strerror(errno));
        free(exe_path);
        return 1;
    }
    if (uv_exepath(exe_path, &path_size)) {
        jl_error("fatal error: unexpected error while retrieving exepath");
        free(exe_path);
        return 1;
    }

    // Configure JULIA_NUM_THREADS / OPENBLAS_NUM_THREADS before jl_init() (#358)
    drv_setup_threads(program_argc, argv);

    // Resolve safe per-user writable local objcache dir before configuring DEPOT_PATH
    char *root_dir = dirname(dirname(exe_path));
    char objcache_dir[FRDC_DRV_PATH_MAX];
    objcache_dir[0] = '\0';
    drv_setup_objcache(root_dir, objcache_dir, sizeof(objcache_dir));

    // Set up LOAD_PATH and DEPOT_PATH (prepending objcache_dir when enabled)
    set_depot_load_path(root_dir, objcache_dir);

    jl_init();

    // Initialize Core.ARGS with the full argv.
    jl_set_ARGS(program_argc, argv);

    // Update ARGS and PROGRAM_FILE
    checked_eval_string("append!(empty!(Base.ARGS), Core.ARGS)");

#if JULIA_VERSION_MAJOR == 1 && JULIA_VERSION_MINOR >= 12
    checked_eval_string("Core.eval(Base, :(global PROGRAM_FILE))");
    checked_eval_string("Base.PROGRAM_FILE = popfirst!(ARGS)");
#else
    jl_value_t *firstarg = checked_eval_string("popfirst!(ARGS)");
    JL_GC_PUSH1(&firstarg);
    jl_sym_t *var = jl_symbol("PROGRAM_FILE");
    #if JULIA_VERSION_MAJOR == 1 && JULIA_VERSION_MINOR >= 11
        jl_binding_t *bp = jl_get_binding_wr(jl_base_module, var, /* alloc */ 1);
        jl_checked_assignment(bp, jl_base_module, var, firstarg);
    #elif JULIA_VERSION_MAJOR == 1 && JULIA_VERSION_MINOR >= 10
        jl_binding_t *bp = jl_get_binding_wr(jl_base_module, var);
        jl_checked_assignment(bp, jl_base_module, var, firstarg);
    #elif JULIA_VERSION_MAJOR == 1 && JULIA_VERSION_MINOR >= 9
        jl_binding_t *bp = jl_get_binding_wr(jl_base_module, var, 1);
        jl_checked_assignment(bp, firstarg);
    #else
        jl_set_global(jl_base_module, jl_symbol("PROGRAM_FILE"), firstarg);
    #endif
    JL_GC_POP();
#endif

    // call the work function, and get back a value
    jl_value_t *jl_retcode = checked_eval_string(JULIA_MAIN "()");
    int32_t retcode = 0;
    if (!jl_typeis(jl_retcode, jl_int32_type)) {
        fprintf(stderr,
                "ERROR: expected a Cint return value from function " JULIA_MAIN
                "\n");
        retcode = 1;
    } else {
        retcode = jl_unbox_int32(jl_retcode);
    }

    // Cleanup and gracefully exit
    free(exe_path);
    jl_atexit_hook(retcode);
    return retcode;
}
