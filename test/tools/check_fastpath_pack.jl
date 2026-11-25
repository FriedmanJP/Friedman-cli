#!/usr/bin/env julia
# FRDCACHE v1 pack integrity, determinism, and byte-for-byte parity verifier ([FASTPATH-W1] #293, #299).
# Run: julia --project test/tools/check_fastpath_pack.jl [path/to/cli_cache.bin]

using Test
using SHA
using JSON3
using Zlib_jll
using Friedman

const _GEN_SCRIPT = normpath(joinpath(@__DIR__, "..", "..", "tools", "gen_fastpath_pack.jl"))

function _crc32(data::AbstractVector{UInt8})::UInt32
    isempty(data) && return UInt32(0)
    c = ccall((:crc32, Zlib_jll.libz), Culong,
              (Culong, Ptr{UInt8}, Cuint),
              Culong(0), data, Cuint(length(data)))
    return UInt32(c & 0xffffffff)
end

function _inflate_block(comp::AbstractVector{UInt8}, raw_len::Integer)::Vector{UInt8}
    dst = Vector{UInt8}(undef, Int(raw_len))
    destlen = Ref{Culong}(Culong(raw_len))
    rc = ccall((:uncompress, Zlib_jll.libz), Cint,
               (Ptr{UInt8}, Ref{Culong}, Ptr{UInt8}, Culong),
               dst, destlen, comp, Culong(length(comp)))
    rc == 0 || error("zlib uncompress failed with code $rc")
    Int(destlen[]) == Int(raw_len) || error("inflated length mismatch: $(destlen[]) != $raw_len")
    return dst
end

function _read_u32(buf::Vector{UInt8}, off0::Int)::UInt32
    b0 = UInt32(buf[off0 + 1])
    b1 = UInt32(buf[off0 + 2]) << 8
    b2 = UInt32(buf[off0 + 3]) << 16
    b3 = UInt32(buf[off0 + 4]) << 24
    return b0 | b1 | b2 | b3
end

function _read_u64(buf::Vector{UInt8}, off0::Int)::UInt64
    lo = UInt64(_read_u32(buf, off0))
    hi = UInt64(_read_u32(buf, off0 + 4))
    return lo | (hi << 32)
end

function _pool_str(buf::Vector{UInt8}, pool_off::Int, off::UInt32, len::UInt32)::String
    s0 = pool_off + Int(off)
    @assert buf[s0 + Int(len) + 1] == 0x00 "pool string not NUL-terminated at off=$off len=$len"
    return String(buf[(s0 + 1):(s0 + Int(len))])
end

function _pool_cstr(buf::Vector{UInt8}, pool_off::Int, off::UInt32)::String
    s0 = pool_off + Int(off) + 1
    e = findnext(==(0x00), buf, s0)
    @assert e !== nothing "unterminated pool cstr at off=$off"
    return String(buf[s0:(e - 1)])
end

function parse_frdcache(path::AbstractString)
    buf = read(path)
    @assert length(buf) >= 100 "pack too small: $(length(buf))"
    @assert String(buf[1:8]) == "FRDCACHE" "bad magic: $(repr(String(buf[1:8])))"
    version = _read_u32(buf, 8)
    flags = _read_u32(buf, 12)
    header_crc = _read_u32(buf, 16)
    @assert version == 1 "unsupported format_version: $version"

    n_meta    = Int(_read_u32(buf, 20))
    n_nodes   = Int(_read_u32(buf, 24))
    n_repls   = Int(_read_u32(buf, 28))
    n_blocks  = Int(_read_u32(buf, 32))
    n_entries = Int(_read_u32(buf, 36))

    meta_off     = Int(_read_u32(buf, 40)); meta_len     = Int(_read_u32(buf, 44))
    node_off     = Int(_read_u32(buf, 48)); node_len     = Int(_read_u32(buf, 52))
    repl_off     = Int(_read_u32(buf, 56)); repl_len     = Int(_read_u32(buf, 60))
    block_off    = Int(_read_u32(buf, 64)); block_len    = Int(_read_u32(buf, 68))
    entry_off    = Int(_read_u32(buf, 72)); entry_len    = Int(_read_u32(buf, 76))
    key_pool_off = Int(_read_u32(buf, 80)); key_pool_len = Int(_read_u32(buf, 84))
    source_stamp = _read_u64(buf, 88)

    index_end = key_pool_off + key_pool_len
    @assert index_end <= length(buf) "index_end out of bounds"
    actual_crc = _crc32(@view buf[21:index_end])
    @assert actual_crc == header_crc "header_index_crc32 mismatch: got $(string(actual_crc; base=16)) expected $(string(header_crc; base=16))"

    @assert meta_len  == 16 * n_meta
    @assert node_len  == 12 * n_nodes
    @assert repl_len  == 16 * n_repls
    @assert block_len == 16 * n_blocks
    @assert entry_len == 20 * n_entries

    meta = Dict{String,String}()
    meta_keys = String[]
    for i in 0:(n_meta - 1)
        p = meta_off + 16 * i
        k = _pool_str(buf, key_pool_off, _read_u32(buf, p), _read_u32(buf, p + 4))
        v = _pool_str(buf, key_pool_off, _read_u32(buf, p + 8), _read_u32(buf, p + 12))
        push!(meta_keys, k)
        meta[k] = v
    end
    @assert issorted(meta_keys) "meta_tbl not sorted"

    nodes = Dict{String,UInt32}()
    node_keys = String[]
    for i in 0:(n_nodes - 1)
        p = node_off + 12 * i
        k = _pool_str(buf, key_pool_off, _read_u32(buf, p), _read_u32(buf, p + 4))
        fl = _read_u32(buf, p + 8)
        push!(node_keys, k)
        nodes[k] = fl
    end
    @assert issorted(node_keys) "node_tbl not sorted"

    repls = Dict{String,String}()
    repl_keys = String[]
    for i in 0:(n_repls - 1)
        p = repl_off + 16 * i
        ok = _pool_str(buf, key_pool_off, _read_u32(buf, p), _read_u32(buf, p + 4))
        nv = _pool_str(buf, key_pool_off, _read_u32(buf, p + 8), _read_u32(buf, p + 12))
        push!(repl_keys, ok)
        repls[ok] = nv
    end
    @assert issorted(repl_keys) "repl_tbl not sorted"

    blocks = Vector{Vector{UInt8}}(undef, n_blocks)
    for i in 0:(n_blocks - 1)
        p = block_off + 16 * i
        foff = Int(_read_u32(buf, p))
        clen = Int(_read_u32(buf, p + 4))
        rlen = Int(_read_u32(buf, p + 8))
        rcrc = _read_u32(buf, p + 12)
        @assert foff >= index_end && foff + clen <= length(buf) "block $i bounds invalid"
        raw = _inflate_block(@view(buf[(foff + 1):(foff + clen)]), rlen)
        @assert _crc32(raw) == rcrc "block $i CRC32 mismatch"
        blocks[i + 1] = raw
    end

    entries = Dict{String,Vector{UInt8}}()
    entry_keys = String[]
    for i in 0:(n_entries - 1)
        p = entry_off + 20 * i
        k = _pool_str(buf, key_pool_off, _read_u32(buf, p), _read_u32(buf, p + 4))
        bidx = Int(_read_u32(buf, p + 8)) + 1
        roff = Int(_read_u32(buf, p + 12))
        rlen = Int(_read_u32(buf, p + 16))
        @assert 1 <= bidx <= n_blocks "entry $k block_idx out of bounds"
        blk = blocks[bidx]
        @assert roff + rlen <= length(blk) "entry $k slice out of bounds"
        push!(entry_keys, k)
        entries[k] = blk[(roff + 1):(roff + rlen)]
    end
    @assert issorted(entry_keys) "entry_tbl not sorted"

    return (
        version=version, flags=flags, source_stamp=source_stamp,
        meta=meta, nodes=nodes, repls=repls, blocks=blocks, entries=entries,
        total_bytes=length(buf),
    )
end

function _strip_ansi(s::AbstractString)::String
    return replace(String(s), r"\x1b\[[0-9;]*m" => "")
end

function _capture_help(f::Function; color::Bool)
    io = IOBuffer()
    ctx = IOContext(io, :color => color)
    f(ctx)
    return String(take!(io))
end

function _capture_stdout(f::Function)::String
    path, io = mktemp()
    try
        redirect_stdout(io) do
            f()
        end
        close(io)
        return read(path, String)
    finally
        try; close(io); catch; end
        try; rm(path; force=true); catch; end
    end
end

function verify_pack(pack_path::AbstractString)
    pack = parse_frdcache(pack_path)
    app = Friedman.APP

    @testset "FRDCACHE v1 integrity & live parity" begin
        @test pack.version == 1
        @test pack.meta["cli_name"] == app.name
        @test pack.meta["cli_version"] == string(Friedman.FRIEDMAN_VERSION)
        @test pack.meta["julia_version"] == string(VERSION)
        @test pack.meta["mems_version"] == Friedman._cached_mems_version()
        @test pack.meta["mcp_protocol_version"] == Friedman._MCP_PROTOCOL_VERSION
        @test pack.meta["version_line"] == "$(app.name) v$(app.version)\n"
        @test pack.meta["warranty_text"] == _capture_stdout(() -> Friedman.dispatch(app, ["--warranty"]))
        @test pack.meta["conditions_text"] == _capture_stdout(() -> Friedman.dispatch(app, ["--conditions"]))
        @test JSON3.read(pack.meta["agent_guide_json_escaped"]) == Friedman._AGENT_GUIDE_MD

        # Root + REPL help (color + stripped plain)
        h_root = String(copy(pack.entries["H:"]))
        @test h_root == _capture_help(io -> Friedman.print_help(io, app); color=true)
        @test _strip_ansi(h_root) == _capture_help(io -> Friedman.print_help(io, app); color=false)
        h_repl = String(copy(pack.entries["H:repl"]))
        @test h_repl == _capture_help(io -> Friedman.print_repl_help(io; prog="$(app.name) repl"); color=true)
        @test _strip_ansi(h_repl) == _capture_help(io -> Friedman.print_repl_help(io; prog="$(app.name) repl"); color=false)

        # Root schema + --docs splice parity
        root_s = String(copy(pack.entries["S:"]))
        @test root_s == JSON3.write(Friedman._schema_node(app.root, String[]))
        @test endswith(root_s, "}")
        spliced = root_s[1:prevind(root_s, end)] * ",\"docs\":" * pack.meta["agent_guide_json_escaped"] * "}"
        spliced_doc = JSON3.read(spliced)
        @test String(spliced_doc.docs) == Friedman._AGENT_GUIDE_MD

        # Walk every node and leaf in APP.root
        n_checked = 0
        function check_walk(node::Friedman.NodeCommand, path::Vector{String})
            for name in sort!(collect(keys(node.subcmds)))
                sub = node.subcmds[name]
                p = vcat(path, [name])
                pstr = join(p, " ")
                prog = "$(app.name) $pstr"
                n_checked += 1
                @test haskey(pack.nodes, pstr)
                @test haskey(pack.entries, "H:$pstr")
                @test haskey(pack.entries, "S:$pstr")
                h_txt = String(copy(pack.entries["H:$pstr"]))
                s_txt = String(copy(pack.entries["S:$pstr"]))
                if sub isa Friedman.NodeCommand
                    @test pack.nodes[pstr] == UInt32(0)
                    @test h_txt == _capture_help(io -> Friedman.print_help(io, sub; prog=prog); color=true)
                    @test _strip_ansi(h_txt) == _capture_help(io -> Friedman.print_help(io, sub; prog=prog); color=false)
                    @test s_txt == JSON3.write(Friedman._schema_node(sub, p))
                    check_walk(sub, p)
                else
                    fl = UInt32(1 << 0)
                    any(a -> a.required, sub.args) && (fl |= UInt32(1 << 1))
                    any(o -> o.name == "seed", sub.options) && (fl |= UInt32(1 << 2))
                    (any(o -> o.short == "q", sub.options) || any(f -> f.short == "q", sub.flags)) && (fl |= UInt32(1 << 3))
                    (any(o -> o.name == "compact", sub.options) || any(f -> f.name == "compact", sub.flags)) && (fl |= UInt32(1 << 4))
                    any(o -> o.name == "format", sub.options) && (fl |= UInt32(1 << 5))
                    @test pack.nodes[pstr] == fl
                    @test h_txt == _capture_help(io -> Friedman.print_help(io, sub; prog=prog); color=true)
                    @test _strip_ansi(h_txt) == _capture_help(io -> Friedman.print_help(io, sub; prog=prog); color=false)
                    @test s_txt == JSON3.write(Friedman._schema_leaf(sub, p))
                end
            end
        end
        check_walk(app.root, String[])
        @test n_checked == length(pack.nodes) - 1

        # Replacements table exact parity
        @test length(pack.repls) == length(Friedman._PATH_REPLACEMENTS)
        for (old_p, new_p) in Friedman._PATH_REPLACEMENTS
            @test pack.repls[join(old_p, " ")] == join(new_p, " ")
        end

        # Completions exact parity
        @test String(pack.entries["C:bash"]) == Friedman.generate_bash_completion(app)
        @test String(pack.entries["C:zsh"])  == Friedman.generate_zsh_completion(app)
        @test String(pack.entries["C:fish"]) == Friedman.generate_fish_completion(app)

        # Tier 3 static catalogs exact parity
        for (tag, cmd) in (("data_list", ["data", "list"]), ("io_sources", ["io", "sources"]))
            live_tbl = _capture_stdout(() -> Friedman.run_cli(vcat(["--quiet"], cmd, ["--format", "table"])))
            live_csv = _capture_stdout(() -> Friedman.run_cli(vcat(["--quiet"], cmd, ["--format", "csv"])))
            live_json = JSON3.read(_capture_stdout(() -> Friedman.run_cli(vcat(["--quiet"], cmd, ["--format", "json"]))))
            @test String(pack.entries["D:$tag:table"]) == live_tbl
            @test String(pack.entries["D:$tag:csv"]) == live_csv
            @test String(pack.entries["D:$tag:json_data"]) == JSON3.write(live_json.data)
        end

        # MCP blocks exact parity (#299)
        mcp_idx = pack.entries["M:index"]
        mcp_full = pack.entries["M:full"]
        mcp_compact = pack.entries["M:compact"]
        live_tools = Friedman._mcp_tools()
        n_tools = Int(_read_u32(mcp_idx, 0))
        sp_off = Int(_read_u32(mcp_idx, 4))
        @test n_tools == length(live_tools)
        @test sp_off == 8 + 52 * n_tools
        for (i, (tname, leaf, path)) in enumerate(live_tools)
            p = 8 + 52 * (i - 1)
            nm = _pool_str(mcp_idx, sp_off, _read_u32(mcp_idx, p), _read_u32(mcp_idx, p + 4))
            fam = _pool_str(mcp_idx, sp_off, _read_u32(mcp_idx, p + 8), _read_u32(mcp_idx, p + 12))
            scnt = Int(_read_u32(mcp_idx, p + 16))
            segs = [_pool_cstr(mcp_idx, sp_off, _read_u32(mcp_idx, p + 20 + 4 * (j - 1))) for j in 1:scnt]
            foff = Int(_read_u32(mcp_idx, p + 36)); flen = Int(_read_u32(mcp_idx, p + 40))
            coff = Int(_read_u32(mcp_idx, p + 44)); clen = Int(_read_u32(mcp_idx, p + 48))

            @test nm == tname
            @test fam == leaf.family
            @test segs == path

            expected_full = JSON3.write(Dict{String,Any}(
                "name" => tname,
                "description" => Friedman._mcp_tool_description(leaf; compact=false),
                "family" => leaf.family,
                "inputSchema" => Friedman._mcp_input_schema(leaf, path; compact=false),
            ))
            expected_compact = JSON3.write(Dict{String,Any}(
                "name" => tname,
                "description" => Friedman._mcp_tool_description(leaf; compact=true),
                "family" => leaf.family,
                "inputSchema" => Friedman._mcp_input_schema(leaf, path; compact=true),
            ))
            @test String(mcp_full[(foff + 1):(foff + flen)]) == expected_full
            @test String(mcp_compact[(coff + 1):(coff + clen)]) == expected_compact
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if !isempty(ARGS)
        verify_pack(ARGS[1])
        println("PASS: check_fastpath_pack verified $(ARGS[1])")
    else
        mktempdir() do d
            p1 = joinpath(d, "pack1.bin")
            p2 = joinpath(d, "pack2.bin")
            proj = normpath(joinpath(@__DIR__, "..", ".."))
            run(`$(Base.julia_cmd()) --project=$proj $_GEN_SCRIPT --output $p1`)
            run(`$(Base.julia_cmd()) --project=$proj $_GEN_SCRIPT --output $p2`)
            h1 = bytes2hex(sha256(read(p1)))
            h2 = bytes2hex(sha256(read(p2)))
            @test h1 == h2
            verify_pack(p1)
            println("PASS: check_fastpath_pack deterministic SHA-256=$h1 ($(round(filesize(p1) / 1024; digits=1)) KiB)")
        end
    end
end
