/* Friedman-cli (frdc) — Pure C99 thin front-end shared header ([FASTPATH] #294, #295, #299)
 * Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
 * SPDX-License-Identifier: GPL-3.0-only
 */
#ifndef FRDC_THIN_H
#define FRDC_THIN_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* FRDCACHE v2 constants (must match tools/gen_fastpath_pack.jl) */
#define FRDCACHE_MAGIC_STR   "FRDCACHE"
#define FRDCACHE_MAGIC_LEN   8u
#define FRDCACHE_VERSION     2u
#define FRDCACHE_HEADER_SIZE 112u

/* node_tbl bitflags */
#define FRDC_NODE_IS_LEAF          (1u << 0)
#define FRDC_NODE_HAS_REQUIRED_ARG (1u << 1)
#define FRDC_NODE_OWNS_SEED        (1u << 2)
#define FRDC_NODE_OWNS_SHORT_Q     (1u << 3)
#define FRDC_NODE_OWNS_COMPACT     (1u << 4)
#define FRDC_NODE_HAS_FORMAT_OPT   (1u << 5)

typedef struct {
    const uint8_t *ptr;
    size_t len;
} FrdcSlice;

typedef struct {
    uint8_t *buf;
    size_t buf_len;

    uint32_t version;
    uint32_t flags;
    uint32_t n_meta;
    uint32_t n_nodes;
    uint32_t n_repls;
    uint32_t n_aliases;
    uint32_t n_blocks;
    uint32_t n_entries;

    uint32_t meta_off;
    uint32_t node_off;
    uint32_t repl_off;
    uint32_t alias_off;
    uint32_t block_off;
    uint32_t entry_off;
    uint32_t key_pool_off;
    uint32_t key_pool_len;
    uint32_t index_end;
    uint64_t source_stamp;
} FrdcPack;

/* Little-endian helpers */
static inline uint32_t frdc_rd_u32(const uint8_t *p) {
    return ((uint32_t)p[0]) |
           ((uint32_t)p[1] << 8) |
           ((uint32_t)p[2] << 16) |
           ((uint32_t)p[3] << 24);
}

static inline uint64_t frdc_rd_u64(const uint8_t *p) {
    return ((uint64_t)frdc_rd_u32(p)) |
           (((uint64_t)frdc_rd_u32(p + 4)) << 32);
}

/* IEEE CRC32 (matches Zlib_jll crc32) */
uint32_t frdc_crc32(const uint8_t *data, size_t len);

/* Pack lifecycle & lookups (return 0 on success, -1 on missing/invalid) */
int  frdc_pack_load(FrdcPack *p, const char *path);
void frdc_pack_free(FrdcPack *p);
int  frdc_pack_meta(const FrdcPack *p, const char *key, FrdcSlice *out);
int  frdc_pack_node(const FrdcPack *p, const char *path, size_t path_len, uint32_t *flags_out);
int  frdc_pack_repl(const FrdcPack *p, const char *old_path, size_t old_len, FrdcSlice *new_out);
int  frdc_pack_alias(const FrdcPack *p, const char *parent_path, size_t parent_len,
                     const char *tok, size_t tok_len, FrdcSlice *canon_out);
int  frdc_pack_read_entry(const FrdcPack *p, const char *key, size_t key_len,
                          uint8_t **out_buf, size_t *out_len);

/* Platform / console / IO / env utilities */
void        frdc_setup_console(void);
int         frdc_stdout_is_tty(void);
int         frdc_stderr_is_tty(void);
const char *frdc_env_get(const char *primary, const char *legacy);
int         frdc_get_self_exe(char *buf, size_t cap);
int         frdc_resolve_core_path(const char *exe_path, char *out_buf, size_t out_cap,
                                   int *is_dev_out);
void        frdc_write_all_stdout(const uint8_t *buf, size_t len);
void        frdc_write_all_stderr(const uint8_t *buf, size_t len);
void        frdc_emit_help_bytes(const uint8_t *buf, size_t len, int use_color);
int         frdc_exec_core(const char *exe_path, int argc, char **argv);

#ifdef FRDC_ENABLE_MCP_PROXY
int frdc_mcp_proxy_main(const FrdcPack *pack, const char *exe_path,
                        int argc, char **argv,
                        int quiet, int no_color,
                        const char *families, const char *tools, int compact);
#endif

#ifdef __cplusplus
}
#endif

#endif /* FRDC_THIN_H */
