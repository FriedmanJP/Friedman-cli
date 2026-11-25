#!/usr/bin/env julia
# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# Single-source FRDCACHE v1 binary metadata pack generator ([FASTPATH-W1] #293, #299).
# Pure Julia using only stdlib Zlib_jll + Friedman (zero new Project.toml dependencies).
#
# Usage:
#   julia --project tools/gen_fastpath_pack.jl --output <path> [--source-stamp <unix_secs>]
#
# Binary layout (little-endian, deterministic):
#   Header (100 bytes):
#     [0..7]   magic = "FRDCACHE" (8 bytes)
#     [8..11]  format_version::UInt32 = 1
#     [12..15] flags::UInt32 = 0
#     [16..19] header_index_crc32::UInt32 (IEEE CRC32 over bytes [20 .. index_end-1])
#     [20..23] n_meta::UInt32
#     [24..27] n_nodes::UInt32
#     [28..31] n_repls::UInt32
#     [32..35] n_blocks::UInt32
#     [36..39] n_entries::UInt32
#     [40..47] meta_off::UInt32,     meta_len::UInt32
#     [48..55] node_off::UInt32,     node_len::UInt32
#     [56..63] repl_off::UInt32,     repl_len::UInt32
#     [64..71] block_off::UInt32,    block_len::UInt32
#     [72..79] entry_off::UInt32,    entry_len::UInt32
#     [80..87] key_pool_off::UInt32, key_pool_len::UInt32
#     [88..95] source_stamp_unix::UInt64 (0 for reproducible release packs)
#     [96..99] reserved::UInt32 = 0
#
#   Sections (contiguous immediately after header, ending at index_end):
#     meta_tbl  : n_meta    × 16B (key_off, key_len, val_off, val_len) — sorted by key
#     node_tbl  : n_nodes   × 12B (path_off, path_len, flags) — sorted by path
#     repl_tbl  : n_repls   × 16B (old_off, old_len, new_off, new_len) — sorted by old
#     block_tbl : n_blocks  × 16B (file_off, comp_len, raw_len, raw_crc32)
#     entry_tbl : n_entries × 20B (key_off, key_len, block_idx, raw_off, raw_len) — sorted by key
#     key_pool  : deduplicated NUL-terminated UTF-8 strings (offset 0 is "")
#
#   Compressed payload blocks (starting at index_end):
#     RFC 1950 zlib level-9 compressed blocks indexed by block_tbl.

using Friedman
using JSON3
using Zlib_jll

const FRDCACHE_MAGIC = Vector{UInt8}("FRDCACHE")
const FRDCACHE_VERSION = UInt32(1)
const FRDCACHE_HEADER_SIZE = UInt32(100)

# node_tbl bitflags
const NODE_IS_LEAF          = UInt32(1 << 0)
const NODE_HAS_REQUIRED_ARG = UInt32(1 << 1)
const NODE_OWNS_SEED        = UInt32(1 << 2)
const NODE_OWNS_SHORT_Q     = UInt32(1 << 3)
const NODE_OWNS_COMPACT     = UInt32(1 << 4)
const NODE_HAS_FORMAT_OPT   = UInt32(1 << 5)

function _zlib_crc32(data::AbstractVector{UInt8})::UInt32
    isempty(data) && return UInt32(0)
    c = ccall((:crc32, Zlib_jll.libz), Culong,
              (Culong, Ptr{UInt8}, Cuint),
              Culong(0), data, Cuint(length(data)))
    return UInt32(c & 0xffffffff)
end

function _zlib_compress9(src::Vector{UInt8})::Vector{UInt8}
    srclen = Culong(length(src))
    bound = ccall((:compressBound, Zlib_jll.libz), Culong, (Culong,), srclen)
    dst = Vector{UInt8}(undef, Int(bound))
    destlen = Ref{Culong}(bound)
    rc = ccall((:compress2, Zlib_jll.libz), Cint,
               (Ptr{UInt8}, Ref{Culong}, Ptr{UInt8}, Culong, Cint),
               dst, destlen, src, srclen, Cint(9))
    rc == 0 || error("zlib compress2 failed with code $rc")
    resize!(dst, Int(destlen[]))
    return dst
end

mutable struct _StringPool
    buf::Vector{UInt8}
    index::Dict{String,Tuple{UInt32,UInt32}}
end

function _StringPool()
    # Reserve offset 0 for "" (NUL-terminated)
    p = _StringPool(UInt8[0x00], Dict{String,Tuple{UInt32,UInt32}}("" => (UInt32(0), UInt32(0))))
    return p
end

function _intern!(pool::_StringPool, s::AbstractString)::Tuple{UInt32,UInt32}
    str = String(s)
    hit = get(pool.index, str, nothing)
    hit === nothing || return hit
    off = UInt32(length(pool.buf))
    cu = codeunits(str)
    len = UInt32(length(cu))
    append!(pool.buf, cu)
    push!(pool.buf, 0x00)
    res = (off, len)
    pool.index[str] = res
    return res
end

function _capture_stdout_bytes(f::Function)::Vector{UInt8}
    path, io = mktemp()
    try
        redirect_stdout(io) do
            f()
        end
        close(io)
        return read(path)
    finally
        try; close(io); catch; end
        try; rm(path; force=true); catch; end
    end
end

function _capture_help_color(f::Function)::Vector{UInt8}
    io = IOBuffer()
    ctx = IOContext(io, :color => true)
    f(ctx)
    return take!(io)
end

function _capture_catalog(cmd::Vector{String})
    # Capture table, csv, and json `data` payload directly through run_cli / dispatch
    # so formatting matches live execution byte-for-byte.
    table_bytes = _capture_stdout_bytes() do
        Friedman.run_cli(vcat(["--quiet"], cmd, ["--format", "table"]))
    end
    csv_bytes = _capture_stdout_bytes() do
        Friedman.run_cli(vcat(["--quiet"], cmd, ["--format", "csv"]))
    end
    json_bytes = _capture_stdout_bytes() do
        Friedman.run_cli(vcat(["--quiet"], cmd, ["--format", "json"]))
    end
    # Extract exact `data` JSON object string for Tier 3 envelope assembly
    doc = JSON3.read(String(json_bytes))
    data_json = Vector{UInt8}(JSON3.write(doc.data))
    return (table=table_bytes, csv=csv_bytes, json_data=data_json)
end

function _build_mcp_payloads()
    tools = Friedman._mcp_tools()
    n_tools = UInt32(length(tools))
    str_pool_off = UInt32(8 + 52 * length(tools))
    full_buf = UInt8[]
    compact_buf = UInt8[]
    pool = _StringPool()
    idx_io = IOBuffer()
    write(idx_io, htol(n_tools))
    write(idx_io, htol(str_pool_off))

    for (tname, leaf, path) in tools
        length(path) <= 4 || error("MCP tool path exceeds 4 segments: $path")
        name_off, name_len = _intern!(pool, tname)
        fam_off, fam_len = _intern!(pool, leaf.family)
        seg_offs = ntuple(4) do j
            j <= length(path) ? _intern!(pool, path[j])[1] : UInt32(0)
        end

        full_obj = Dict{String,Any}(
            "name" => tname,
            "description" => Friedman._mcp_tool_description(leaf; compact=false),
            "family" => leaf.family,
            "inputSchema" => Friedman._mcp_input_schema(leaf, path; compact=false),
        )
        full_str = JSON3.write(full_obj)
        full_off = UInt32(length(full_buf))
        full_len = UInt32(ncodeunits(full_str))
        append!(full_buf, codeunits(full_str))

        compact_obj = Dict{String,Any}(
            "name" => tname,
            "description" => Friedman._mcp_tool_description(leaf; compact=true),
            "family" => leaf.family,
            "inputSchema" => Friedman._mcp_input_schema(leaf, path; compact=true),
        )
        compact_str = JSON3.write(compact_obj)
        compact_off = UInt32(length(compact_buf))
        compact_len = UInt32(ncodeunits(compact_str))
        append!(compact_buf, codeunits(compact_str))

        for v in (name_off, name_len, fam_off, fam_len, UInt32(length(path)),
                  seg_offs[1], seg_offs[2], seg_offs[3], seg_offs[4],
                  full_off, full_len, compact_off, compact_len)
            write(idx_io, htol(v))
        end
    end
    write(idx_io, pool.buf)
    return (index=take!(idx_io), full=full_buf, compact=compact_buf, count=length(tools))
end

function _write_sorted_json_dict(d::AbstractDict{String,String})::String
    io = IOBuffer()
    write(io, '{')
    ks = sort!(collect(keys(d)))
    for (i, k) in enumerate(ks)
        i > 1 && write(io, ',')
        write(io, JSON3.write(k))
        write(io, ':')
        write(io, JSON3.write(d[k]))
    end
    write(io, '}')
    return String(take!(io))
end

function generate_fastpath_pack(output_path::AbstractString; source_stamp::UInt64=UInt64(0))
    app = Friedman.APP
    root = app.root

    # 1. Collect metadata table
    manifest = Friedman._envelope_manifest()
    deps_str = Dict{String,String}(String(k) => String(v) for (k, v) in manifest["dependency_versions"])
    warranty_bytes = _capture_stdout_bytes() do
        Friedman.dispatch(app, ["--warranty"])
    end
    conditions_bytes = _capture_stdout_bytes() do
        Friedman.dispatch(app, ["--conditions"])
    end

    meta_pairs = Pair{String,String}[
        "agent_guide_json_escaped" => JSON3.write(Friedman._AGENT_GUIDE_MD),
        "cli_git_sha"              => String(manifest["git_sha"]),
        "cli_name"                 => String(app.name),
        "cli_version"              => string(Friedman.FRIEDMAN_VERSION),
        "conditions_text"          => String(conditions_bytes),
        "julia_version"            => string(VERSION),
        "machine"                  => String(manifest["machine"]),
        "manifest_deps_json"       => _write_sorted_json_dict(deps_str),
        "mcp_protocol_version"     => String(Friedman._MCP_PROTOCOL_VERSION),
        "mems_git_sha"             => String(Friedman._BUNDLED_MANIFEST_STATIC.git_sha),
        "mems_version"             => String(Friedman._cached_mems_version()),
        "os"                       => String(manifest["os"]),
        "version_line"             => "$(app.name) v$(app.version)\n",
        "warranty_text"            => String(warranty_bytes),
    ]
    sort!(meta_pairs; by=first)

    # 2. Walk command tree for node_tbl, help payloads, and schema payloads
    node_rows = Tuple{String,UInt32}[]
    # group_name => Vector{Tuple{entry_key, payload_bytes}}
    groups = Dict{String,Vector{Tuple{String,Vector{UInt8}}}}()
    push_entry!(grp::String, key::String, bytes::Vector{UInt8}) =
        push!(get!(groups, grp, Tuple{String,Vector{UInt8}}[]), (key, bytes))

    # Root entry
    push!(node_rows, ("", UInt32(0)))
    push_entry!("help:_root", "H:", _capture_help_color(io -> Friedman.print_help(io, app)))
    push_entry!("help:_root", "H:repl", _capture_help_color(io -> Friedman.print_repl_help(io; prog="$(app.name) repl")))
    push_entry!("schema:_root", "S:", Vector{UInt8}(JSON3.write(Friedman._schema_node(root, String[]))))

    function walk_tree(node::Friedman.NodeCommand, path::Vector{String})
        for name in sort!(collect(keys(node.subcmds)))
            sub = node.subcmds[name]
            p = vcat(path, [name])
            pstr = join(p, " ")
            prog = isempty(p) ? app.name : "$(app.name) $pstr"
            top = p[1]
            if sub isa Friedman.NodeCommand
                push!(node_rows, (pstr, UInt32(0)))
                push_entry!("help:$top", "H:$pstr",
                            _capture_help_color(io -> Friedman.print_help(io, sub; prog=prog)))
                push_entry!("schema:$top", "S:$pstr",
                            Vector{UInt8}(JSON3.write(Friedman._schema_node(sub, p))))
                walk_tree(sub, p)
            else
                fl = NODE_IS_LEAF
                any(a -> a.required, sub.args) && (fl |= NODE_HAS_REQUIRED_ARG)
                any(o -> o.name == "seed", sub.options) && (fl |= NODE_OWNS_SEED)
                (any(o -> o.short == "q", sub.options) || any(f -> f.short == "q", sub.flags)) &&
                    (fl |= NODE_OWNS_SHORT_Q)
                (any(o -> o.name == "compact", sub.options) || any(f -> f.name == "compact", sub.flags)) &&
                    (fl |= NODE_OWNS_COMPACT)
                any(o -> o.name == "format", sub.options) && (fl |= NODE_HAS_FORMAT_OPT)
                push!(node_rows, (pstr, fl))
                push_entry!("help:$top", "H:$pstr",
                            _capture_help_color(io -> Friedman.print_help(io, sub; prog=prog)))
                push_entry!("schema:$top", "S:$pstr",
                            Vector{UInt8}(JSON3.write(Friedman._schema_leaf(sub, p))))
            end
        end
    end
    walk_tree(root, String[])
    sort!(node_rows; by=first)

    # 3. Path replacements table
    repl_rows = Tuple{String,String}[
        (join(old_p, " "), join(new_p, " "))
        for (old_p, new_p) in Friedman._PATH_REPLACEMENTS
    ]
    sort!(repl_rows; by=first)

    # 4. Shell completions (1 block per shell)
    push_entry!("comp:bash", "C:bash", Vector{UInt8}(Friedman.generate_bash_completion(app)))
    push_entry!("comp:zsh",  "C:zsh",  Vector{UInt8}(Friedman.generate_zsh_completion(app)))
    push_entry!("comp:fish", "C:fish", Vector{UInt8}(Friedman.generate_fish_completion(app)))

    # 5. Static offline catalogs (Tier 3: data list & io sources)
    dl = _capture_catalog(["data", "list"])
    push_entry!("data:catalogs", "D:data_list:table",     dl.table)
    push_entry!("data:catalogs", "D:data_list:csv",       dl.csv)
    push_entry!("data:catalogs", "D:data_list:json_data", dl.json_data)
    ios = _capture_catalog(["io", "sources"])
    push_entry!("data:catalogs", "D:io_sources:table",     ios.table)
    push_entry!("data:catalogs", "D:io_sources:csv",       ios.csv)
    push_entry!("data:catalogs", "D:io_sources:json_data", ios.json_data)

    # 6. MCP tool discovery blocks (#299)
    mcp = _build_mcp_payloads()
    push_entry!("mcp:index",   "M:index",   mcp.index)
    push_entry!("mcp:full",    "M:full",    mcp.full)
    push_entry!("mcp:compact", "M:compact", mcp.compact)

    # 7. Compress groups into deterministic sorted block list & build entry records
    group_names = sort!(collect(keys(groups)))
    comp_blocks = Vector{Vector{UInt8}}(undef, length(group_names))
    block_meta = Vector{Tuple{UInt32,UInt32,UInt32}}(undef, length(group_names)) # (comp_len, raw_len, raw_crc32)
    raw_entries = Tuple{String,UInt32,UInt32,UInt32}[] # (key, block_idx0, raw_off, raw_len)

    for (bi, gname) in enumerate(group_names)
        items = sort!(groups[gname]; by=first)
        raw_buf = UInt8[]
        for (ekey, payload) in items
            roff = UInt32(length(raw_buf))
            rlen = UInt32(length(payload))
            append!(raw_buf, payload)
            push!(raw_entries, (ekey, UInt32(bi - 1), roff, rlen))
        end
        rcrc = _zlib_crc32(raw_buf)
        cbuf = _zlib_compress9(raw_buf)
        comp_blocks[bi] = cbuf
        block_meta[bi] = (UInt32(length(cbuf)), UInt32(length(raw_buf)), rcrc)
    end
    sort!(raw_entries; by=first)

    # 8. Intern all strings into shared key_pool (deterministic order)
    pool = _StringPool()
    meta_encoded = NTuple{4,UInt32}[]
    for (k, v) in meta_pairs
        ko, kl = _intern!(pool, k)
        vo, vl = _intern!(pool, v)
        push!(meta_encoded, (ko, kl, vo, vl))
    end
    node_encoded = NTuple{3,UInt32}[]
    for (p, fl) in node_rows
        po, pl = _intern!(pool, p)
        push!(node_encoded, (po, pl, fl))
    end
    repl_encoded = NTuple{4,UInt32}[]
    for (old_s, new_s) in repl_rows
        oo, ol = _intern!(pool, old_s)
        no, nl = _intern!(pool, new_s)
        push!(repl_encoded, (oo, ol, no, nl))
    end
    entry_encoded = NTuple{5,UInt32}[]
    for (ekey, bidx, roff, rlen) in raw_entries
        ko, kl = _intern!(pool, ekey)
        push!(entry_encoded, (ko, kl, bidx, roff, rlen))
    end

    # 9. Compute exact section offsets
    meta_off = FRDCACHE_HEADER_SIZE
    meta_len = UInt32(16 * length(meta_encoded))
    node_off = meta_off + meta_len
    node_len = UInt32(12 * length(node_encoded))
    repl_off = node_off + node_len
    repl_len = UInt32(16 * length(repl_encoded))
    block_off = repl_off + repl_len
    block_len = UInt32(16 * length(block_meta))
    entry_off = block_off + block_len
    entry_len = UInt32(20 * length(entry_encoded))
    key_pool_off = entry_off + entry_len
    key_pool_len = UInt32(length(pool.buf))
    index_end = key_pool_off + key_pool_len

    # Assign block file offsets starting at index_end
    block_encoded = Vector{NTuple{4,UInt32}}(undef, length(block_meta))
    cur_off = index_end
    for (i, (clen, rlen, rcrc)) in enumerate(block_meta)
        block_encoded[i] = (cur_off, clen, rlen, rcrc)
        cur_off += clen
    end

    # 10. Serialize header + index region [20 .. index_end-1] to compute CRC32
    idx_body = IOBuffer()
    for v in (
        UInt32(length(meta_encoded)),
        UInt32(length(node_encoded)),
        UInt32(length(repl_encoded)),
        UInt32(length(block_encoded)),
        UInt32(length(entry_encoded)),
        meta_off, meta_len,
        node_off, node_len,
        repl_off, repl_len,
        block_off, block_len,
        entry_off, entry_len,
        key_pool_off, key_pool_len,
    )
        write(idx_body, htol(v))
    end
    write(idx_body, htol(source_stamp))
    write(idx_body, htol(UInt32(0))) # reserved

    for rec in meta_encoded, v in rec
        write(idx_body, htol(v))
    end
    for rec in node_encoded, v in rec
        write(idx_body, htol(v))
    end
    for rec in repl_encoded, v in rec
        write(idx_body, htol(v))
    end
    for rec in block_encoded, v in rec
        write(idx_body, htol(v))
    end
    for rec in entry_encoded, v in rec
        write(idx_body, htol(v))
    end
    write(idx_body, pool.buf)

    idx_bytes = take!(idx_body)
    length(idx_bytes) == Int(index_end - 20) ||
        error("internal size mismatch: $(length(idx_bytes)) != $(index_end - 20)")
    header_crc = _zlib_crc32(idx_bytes)

    # 11. Write final binary file atomically
    out_dir = dirname(abspath(output_path))
    isdir(out_dir) || mkpath(out_dir)
    tmp_path = output_path * ".tmp." * string(getpid())
    open(tmp_path, "w") do io
        write(io, FRDCACHE_MAGIC)
        write(io, htol(FRDCACHE_VERSION))
        write(io, htol(UInt32(0))) # flags
        write(io, htol(header_crc))
        write(io, idx_bytes)
        for cbuf in comp_blocks
            write(io, cbuf)
        end
    end
    mv(tmp_path, output_path; force=true)

    return (
        path = String(output_path),
        total_bytes = filesize(output_path),
        index_bytes = Int(index_end),
        n_meta = length(meta_encoded),
        n_nodes = length(node_encoded),
        n_repls = length(repl_encoded),
        n_blocks = length(block_encoded),
        n_entries = length(entry_encoded),
        n_mcp_tools = mcp.count,
    )
end

function _parse_cli_args(args::Vector{String})
    out = ""
    stamp = UInt64(0)
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--output" || a == "-o"
            i + 1 <= length(args) || error("$a requires a path")
            out = args[i + 1]
            i += 2
        elseif startswith(a, "--output=")
            out = a[10:end]
            i += 1
        elseif a == "--source-stamp"
            i + 1 <= length(args) || error("--source-stamp requires a unix integer")
            stamp = parse(UInt64, args[i + 1])
            i += 2
        elseif startswith(a, "--source-stamp=")
            stamp = parse(UInt64, a[16:end])
            i += 1
        else
            error("unknown argument: $a")
        end
    end
    isempty(out) && error("usage: julia --project tools/gen_fastpath_pack.jl --output <path> [--source-stamp <unix>]")
    return out, stamp
end

if abspath(PROGRAM_FILE) == @__FILE__
    out, stamp = _parse_cli_args(ARGS)
    stats = generate_fastpath_pack(out; source_stamp=stamp)
    println("Generated FRDCACHE v1: $(stats.path) ($(round(stats.total_bytes / 1024; digits=1)) KiB; " *
            "index=$(round(stats.index_bytes / 1024; digits=1)) KiB, " *
            "blocks=$(stats.n_blocks), entries=$(stats.n_entries), " *
            "nodes=$(stats.n_nodes), repls=$(stats.n_repls), mcp=$(stats.n_mcp_tools))")
end
