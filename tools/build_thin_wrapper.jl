#!/usr/bin/env julia
# Optional local dev thin-wrapper builder for macOS/Linux source developers ([FASTPATH-W5] #297).
#
# Builds a native fast-path wrapper under build/dev-wrapper/ (leaving bin/frdc untouched)
# with a source-tree mtime stamp embedded in share/frdc/cli_cache.bin so edits to src/ or
# Project.toml automatically fall back to `julia --project bin/frdc`.
#
# Usage:
#   julia --project tools/build_thin_wrapper.jl [--output-dir build/dev-wrapper]

using Pkg

const _ROOT = normpath(joinpath(@__DIR__, ".."))
const _WRAPPER_DIR = joinpath(_ROOT, "packaging", "thin_wrapper")
const _GEN_SCRIPT  = joinpath(_ROOT, "tools", "gen_fastpath_pack.jl")

function _latest_source_mtime(root::String)::UInt64
    best = floor(UInt64, mtime(joinpath(root, "Project.toml")))
    for (dir, _, files) in walkdir(joinpath(root, "src"))
        for f in files
            t = floor(UInt64, mtime(joinpath(dir, f)))
            t > best && (best = t)
        end
    end
    return best
end

function _find_cc()
    if Sys.isapple() && isfile("/usr/bin/cc")
        return "/usr/bin/cc"
    end
    for c in ("cc", "gcc", "clang")
        p = Sys.which(c)
        p === nothing || return p
    end
    error("No C compiler found on PATH (tried cc, gcc, clang)")
end

function main(args::Vector{String}=ARGS)
    out_dir = joinpath(_ROOT, "build", "dev-wrapper")
    i = 1
    while i <= length(args)
        if args[i] == "--output-dir" && i + 1 <= length(args)
            out_dir = abspath(args[i + 1])
            i += 2
        elseif startswith(args[i], "--output-dir=")
            out_dir = abspath(args[i][14:end])
            i += 1
        else
            error("Usage: julia --project tools/build_thin_wrapper.jl [--output-dir <dir>]")
        end
    end

    bin_dir   = joinpath(out_dir, "bin")
    share_dir = joinpath(out_dir, "share", "frdc")
    mkpath(bin_dir); mkpath(share_dir)

    stamp = _latest_source_mtime(_ROOT)
    cache_path = joinpath(share_dir, "cli_cache.bin")
    println("Generating stamped FRDCACHE v1 pack (source_stamp=$stamp)...")
    run(`$(Base.julia_cmd()) --project=$(_ROOT) $(_GEN_SCRIPT) --output $(cache_path) --source-stamp $(stamp) --source-root $(_ROOT)`)

    cc = _find_cc()
    ext = Sys.iswindows() ? ".exe" : ""
    exe_path = joinpath(bin_dir, "frdc" * ext)
    flags = String["-std=c99", "-O2", "-Wall", "-Wextra", "-I$(_WRAPPER_DIR)"]
    srcs = String[joinpath(_WRAPPER_DIR, "frdc_thin.c")]
    mcp_src = joinpath(_WRAPPER_DIR, "mcp_proxy.c")
    yy_src  = joinpath(_WRAPPER_DIR, "yyjson.c")
    dc_src  = joinpath(_WRAPPER_DIR, "daemon_client.c")
    if isfile(mcp_src) && isfile(yy_src)
        append!(flags, [
            "-DFRDC_ENABLE_MCP_PROXY",
            "-DYYJSON_DISABLE_UTILS=1",
            "-DYYJSON_DISABLE_NON_STANDARD=1",
            "-DYYJSON_DISABLE_INCR_READER=1",
            "-DYYJSON_DISABLE_FAST_FP_CONV=1",
        ])
        push!(srcs, mcp_src, yy_src)
        if isfile(dc_src)
            push!(flags, "-DFRDC_ENABLE_DAEMON_CLIENT")
            push!(srcs, dc_src)
        end
    end
    Sys.iswindows() && push!(flags, "-municode")
    run(`$cc $flags $srcs -o $exe_path`)

    # Create a tiny sibling shim frdc-core -> `julia --project=<root> <root>/bin/frdc`
    # so the wrapper works from any output directory on POSIX.
    if !Sys.iswindows()
        core_shim = joinpath(bin_dir, "frdc-core")
        sysimg = isfile(joinpath(_ROOT, "frdc.so")) ? "--sysimage=$(joinpath(_ROOT, "frdc.so")) " : ""
        write(core_shim, "#!/bin/sh\nexec julia --project=\"$(_ROOT)\" $(sysimg)\"$(joinpath(_ROOT, "bin", "frdc"))\" \"\$@\"\n")
        chmod(core_shim, 0o755)
    end

    println("Built local dev thin wrapper:")
    println("  Wrapper: $(exe_path) ($(round(filesize(exe_path) / 1024; digits=1)) KiB)")
    println("  Cache:   $(cache_path) ($(round(filesize(cache_path) / 1024; digits=1)) KiB)")
    println("  Add $(bin_dir) to PATH, or run: $(exe_path) --help")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
