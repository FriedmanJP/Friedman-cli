#!/usr/bin/env julia
# Differential parity, sanitizer (ASan+UBSan), and fail-open CI suite for the
# pure C99 thin wrapper ([FASTPATH-W5] #297, extended with MCP proxy in #299).
# Run: julia --project test/test_fastpath.jl

using Test
using JSON3
using Friedman

const _ROOT = normpath(joinpath(@__DIR__, ".."))
const _WRAPPER_DIR = joinpath(_ROOT, "packaging", "thin_wrapper")
const _GEN_SCRIPT  = joinpath(_ROOT, "tools", "gen_fastpath_pack.jl")
const _CHECK_PACK  = joinpath(_ROOT, "test", "tools", "check_fastpath_pack.jl")
const _SCHEMA_PATH = joinpath(_ROOT, "schema", "envelope-v1.json")

include(_GEN_SCRIPT)

function _find_c_compiler()
    if Sys.isapple() && isfile("/usr/bin/cc")
        return "/usr/bin/cc"
    end
    for c in ("cc", "gcc", "clang")
        p = Sys.which(c)
        p === nothing || return p
    end
    error("No C compiler found on PATH (tried cc, gcc, clang)")
end

function _compile_wrapper(out_exe::String; sanitize::Bool=!Sys.iswindows())
    cc = _find_c_compiler()
    flags = String["-std=c99", "-Wall", "-Wextra", "-Werror", "-I$(_WRAPPER_DIR)"]
    if sanitize
        append!(flags, ["-O1", "-g", "-fsanitize=address,undefined", "-fno-omit-frame-pointer"])
    else
        push!(flags, "-O2")
    end
    srcs = String[joinpath(_WRAPPER_DIR, "frdc_thin.c")]
    mcp_src = joinpath(_WRAPPER_DIR, "mcp_proxy.c")
    yy_src  = joinpath(_WRAPPER_DIR, "yyjson.c")
    has_mcp = isfile(mcp_src) && isfile(yy_src)
    if has_mcp
        append!(flags, [
            "-DFRDC_ENABLE_MCP_PROXY",
            "-DYYJSON_DISABLE_UTILS=1",
            "-DYYJSON_DISABLE_NON_STANDARD=1",
            "-DYYJSON_DISABLE_INCR_READER=1",
            "-DYYJSON_DISABLE_FAST_FP_CONV=1",
        ])
        push!(srcs, mcp_src, yy_src)
    end
    if Sys.iswindows()
        push!(flags, "-municode")
    end
    cmd = `$cc $flags $srcs -o $out_exe`
    run(cmd)
    return has_mcp
end

function _build_core_stub(core_exe::String)
    cc = _find_c_compiler()
    src = joinpath(dirname(core_exe), "_stub_core.c")
    write(src, """
    #include <stdio.h>
    int main(int argc, char **argv) {
        fputs("CORE_FALLBACK:", stdout);
        for (int i = 1; i < argc; i++) {
            if (i > 1) fputc(' ', stdout);
            fputs(argv[i], stdout);
        }
        fputc('\\n', stdout);
        return 42;
    }
    """)
    run(`$cc -std=c99 -O2 $src -o $core_exe`)
    rm(src; force=true)
end

function _run_proc(exe::String, args::Vector{String}; env_extra::Dict{String,String}=Dict{String,String}(),
                   stdin_data::Union{Nothing,String}=nothing)
    out_p, out_io = mktemp()
    err_p, err_io = mktemp()
    in_p = nothing
    try
        env = copy(ENV)
        delete!(env, "FRDC_NO_FASTPATH")
        delete!(env, "FRIEDMAN_NO_FASTPATH")
        delete!(env, "FRDC_CACHE_PATH")
        delete!(env, "FRIEDMAN_CACHE_PATH")
        delete!(env, "NO_COLOR")
        for (k, v) in env_extra
            env[k] = v
        end
        cmd = setenv(Cmd(vcat([exe], args)), env)
        proc = if stdin_data !== nothing
            in_p = tempname()
            write(in_p, stdin_data)
            open(in_p, "r") do in_io
                run(pipeline(cmd; stdin=in_io, stdout=out_io, stderr=err_io); wait=false)
            end
        else
            run(pipeline(cmd; stdin=devnull, stdout=out_io, stderr=err_io); wait=false)
        end
        wait(proc)
        close(out_io); close(err_io)
        so = read(out_p, String)
        se = read(err_p, String)
        return (code=proc.exitcode, stdout=so, stderr=se)
    finally
        try; close(out_io); catch; end
        try; close(err_io); catch; end
        try; rm(out_p; force=true); catch; end
        try; rm(err_p; force=true); catch; end
        in_p === nothing || try; rm(in_p; force=true); catch; end
    end
end

function _run_julia_cli(args::Vector{String})
    out_p, out_io = mktemp()
    err_p, err_io = mktemp()
    code = try
        redirect_stdout(out_io) do
            redirect_stderr(err_io) do
                Friedman.run_cli(copy(args))
            end
        end
    finally
        try; close(out_io); catch; end
        try; close(err_io); catch; end
    end
    so = read(out_p, String)
    se = read(err_p, String)
    rm(out_p; force=true); rm(err_p; force=true)
    return (code=Int(code), stdout=so, stderr=se)
end

function _capture_help_plain(f::Function)::String
    io = IOBuffer()
    ctx = IOContext(io, :color => false)
    f(ctx)
    return String(take!(io))
end

@testset "Thin Wrapper Fast-Path Differential Parity & Sanitizers (#297)" begin
    mktempdir() do tmp
        bin_dir = joinpath(tmp, "bin")
        share_dir = joinpath(tmp, "share", "frdc")
        mkpath(bin_dir); mkpath(share_dir)

        ext = Sys.iswindows() ? ".exe" : ""
        wrapper_exe = joinpath(bin_dir, "frdc" * ext)
        core_exe    = joinpath(bin_dir, "frdc-core" * ext)
        pack_path   = joinpath(share_dir, "cli_cache.bin")

        # 1. Compile wrapper (ASan+UBSan on Linux/macOS, -Werror everywhere) + core stub
        has_mcp = _compile_wrapper(wrapper_exe; sanitize=!Sys.iswindows())
        @test isfile(wrapper_exe)
        _build_core_stub(core_exe)
        @test isfile(core_exe)

        # 2. Generate FRDCACHE v1 pack from live Friedman and verify pack invariants
        stats = generate_fastpath_pack(pack_path)
        @test isfile(pack_path)
        @test stats.n_nodes >= 600
        @test stats.n_repls >= 300
        @test stats.n_mcp_tools >= 500

        # 3. Tier 1: --version, -V, --warranty, --conditions, root & repl help
        @testset "Tier 1 static notices & root/repl help" begin
            for argv in (["--version"], ["-V"], ["--warranty"], ["--conditions"],
                         ["--json", "--version"], ["--seed", "7", "--version"],
                         String[], ["--help"], ["-h"], ["repl", "--help"], ["repl", "-h"])
                fp = _run_proc(wrapper_exe, argv)
                jl = _run_julia_cli(argv)
                @test fp.code == jl.code == 0
                @test fp.stderr == ""
                @test fp.stdout == jl.stdout
            end
        end

        # 4. Tier 1: ALL 644+ node & leaf help screens (100% differential parity)
        @testset "Tier 1 exhaustive node & leaf help parity" begin
            app = Friedman.APP
            checked = 0
            function walk_help(node::Friedman.NodeCommand, path::Vector{String})
                for name in sort!(collect(keys(node.subcmds)))
                    sub = node.subcmds[name]
                    p = vcat(path, [name])
                    prog = "$(app.name) $(join(p, " "))"
                    fp = _run_proc(wrapper_exe, vcat(p, ["--help"]))
                    exp = _capture_help_plain(io -> Friedman.print_help(io, sub; prog=prog))
                    @test fp.code == 0
                    @test fp.stderr == ""
                    @test fp.stdout == exp
                    checked += 1
                    if sub isa Friedman.NodeCommand
                        walk_help(sub, p)
                    end
                end
            end
            walk_help(app.root, String[])
            @test checked >= 640

            # Required-arg bare leaf prints help; `-- --help` prints help; NO_COLOR strips ANSI
            for argv in (
                ["estimate", "multivariate", "var"],
                ["estimate", "multivariate", "var", "--", "--help"],
                ["--no-color", "estimate", "multivariate", "var", "--help"],
                ["estimate"],
                ["estimate", "multivariate"],
            )
                fp = _run_proc(wrapper_exe, argv)
                jl = _run_julia_cli(argv)
                @test fp.code == 0
                @test fp.stderr == ""
                @test fp.stdout == jl.stdout
            end
            fp_nc = _run_proc(wrapper_exe, ["--help"]; env_extra=Dict("NO_COLOR" => "1"))
            @test !occursin("\x1b[", fp_nc.stdout)
        end

        # 5. Tier 1 POSIX PTY color & SIGPIPE tests
        if !Sys.iswindows()
            @testset "POSIX PTY ANSI color & SIGPIPE" begin
                py = Sys.which("python3")
                if py !== nothing
                    pty_out = read(`$py -c "
import os, pty, select, subprocess, sys
m, s = pty.openpty()
env = os.environ.copy(); env.pop('NO_COLOR', None)
p = subprocess.Popen([sys.argv[1], '--help'], stdout=s, stderr=s, env=env)
os.close(s)
chunks = []
while True:
    r, _, _ = select.select([m], [], [], 2.0)
    if not r: break
    try:
        d = os.read(m, 4096)
        if not d: break
        chunks.append(d)
    except OSError:
        break
os.close(m); p.wait()
sys.stdout.buffer.write(b''.join(chunks))
" $wrapper_exe`, String)
                    @test occursin("\x1b[", pty_out)

                    # --no-color on PTY must strip ANSI
                    pty_nc = read(`$py -c "
import os, pty, select, subprocess, sys
m, s = pty.openpty()
env = os.environ.copy(); env.pop('NO_COLOR', None)
p = subprocess.Popen([sys.argv[1], '--no-color', '--help'], stdout=s, stderr=s, env=env)
os.close(s)
chunks = []
while True:
    r, _, _ = select.select([m], [], [], 2.0)
    if not r: break
    try:
        d = os.read(m, 4096)
        if not d: break
        chunks.append(d)
    except OSError:
        break
os.close(m); p.wait()
sys.stdout.buffer.write(b''.join(chunks))
" $wrapper_exe`, String)
                    @test !occursin("\x1b[", pty_nc)

                    # SIGPIPE exit 0 check
                    rc = read(`$py -c "
import os, subprocess, sys
p = subprocess.Popen([sys.argv[1], 'completions', 'fish'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
p.stdout.read(64)
p.stdout.close()
p.wait()
print(p.returncode)
" $wrapper_exe`, String)
                    @test strip(rc) == "0"
                end
            end
        end

        # 6. Tier 2: schema [--docs] & completions bash|zsh|fish
        @testset "Tier 2 schema & completions parity" begin
            for argv in (
                ["schema"],
                ["schema", "--docs"],
                ["schema", "estimate"],
                ["schema", "estimate", "multivariate", "var"],
                ["schema", "--docs", "estimate", "multivariate", "var"],
                ["schema", "ri", "solve"],
                ["schema", "--help"],
                ["completions", "bash"],
                ["completions", "zsh"],
                ["completions", "fish"],
            )
                fp = _run_proc(wrapper_exe, argv)
                jl = _run_julia_cli(argv)
                @test fp.code == 0
                @test fp.stderr == ""
                if argv[1] == "schema" && !("--help" in argv)
                    @test JSON3.read(fp.stdout) == JSON3.read(jl.stdout)
                else
                    @test fp.stdout == jl.stdout
                end
            end
        end

        # 7. Tier 3: static catalogs (`data list` & `io sources`)
        @testset "Tier 3 static catalogs parity & schema compliance" begin
            for cmd in (["data", "list"], ["io", "sources"])
                for fmt_args in (String[], ["--format", "table"], ["--format", "csv"])
                    argv = vcat(cmd, fmt_args)
                    fp = _run_proc(wrapper_exe, argv)
                    jl = _run_julia_cli(vcat(["--quiet"], argv))
                    @test fp.code == 0 && fp.stderr == ""
                    @test fp.stdout == jl.stdout
                end
                for json_args in (vcat(cmd, ["--format", "json"]), vcat(["--json", "--seed", "42"], cmd))
                    fp = _run_proc(wrapper_exe, json_args)
                    jl = _run_julia_cli(vcat(["--quiet"], json_args))
                    @test fp.code == 0 && fp.stderr == ""
                    fd = JSON3.read(fp.stdout)
                    jd = JSON3.read(jl.stdout)
                    @test fd.schema_version == 1
                    @test String(fd.command) == String(jd.command)
                    @test String(fd.status) == "ok"
                    @test fd.error === nothing
                    @test fd.data == jd.data
                    @test String(fd.meta.cli_version) == String(jd.meta.cli_version)
                    @test String(fd.meta.mems_version) == String(jd.meta.mems_version)
                    @test fd.meta.seed == jd.meta.seed
                    @test collect(String, fd.meta.argv) == json_args
                end
            end
        end

        # 8. Tier 4: fast-fail unknown commands, hints, repl extra, bare serve
        @testset "Tier 4 fast-fail unknown commands & envelopes" begin
            for argv in (
                ["nosuchcmd"],
                ["nosuchcmd", "--json"],
                ["--quiet", "nosuchcmd"],
                ["estimate", "var"],
                ["estimate", "var", "--json"],
                ["estimate", "--version"],
                ["dsge", "ha", "solve"],
                ["completions", "nosuch"],
                ["schema", "nosuchcmd"],
                ["schema", "estimate", "var"],
                ["schema", "estimate", "var", "--json"],
                ["schema", "estimate", "multivariate", "var", "extra"],
                ["repl", "extra"],
                ["serve"],
            )
                fp = _run_proc(wrapper_exe, argv)
                jl = _run_julia_cli(argv)
                @test fp.code == jl.code == 2
                @test fp.stderr == jl.stderr
                if isempty(jl.stdout)
                    @test isempty(fp.stdout)
                else
                    fd = JSON3.read(fp.stdout)
                    jd = JSON3.read(jl.stdout)
                    @test String(fd.status) == "error"
                    @test String(fd.command) == String(jd.command)
                    @test String(fd.error.code) == String(jd.error.code)
                    @test String(fd.error.message) == String(jd.error.message)
                    @test Int(fd.error.exit_code) == 2
                end
            end

            # RFC 8259 JSON escaping stress test
            fp_esc = _run_proc(wrapper_exe, ["bad\"cmd\\x\t1", "--json"])
            @test fp_esc.code == 2
            esc_doc = JSON3.read(fp_esc.stdout)
            @test String(esc_doc.status) == "error"
            @test occursin("bad\"cmd\\x\t1", String(esc_doc.error.message))
        end

        # 9. Fail-open & explicit bypass handoff to frdc-core
        @testset "Fail-open & explicit bypass handoff" begin
            for (argv, env_extra) in (
                (["estimate", "multivariate", "var", "foo.csv"], Dict{String,String}()),
                (["--version"], Dict("FRDC_NO_FASTPATH" => "1")),
                (["--version"], Dict("FRIEDMAN_NO_FASTPATH" => "1")),
                (["--version", "--julia-args", "-t1"], Dict{String,String}()),
                (["--seed", "abc", "--version"], Dict{String,String}()),
                (["estimate", "multivariate", "var", "--json"], Dict{String,String}()),
                (["--quiet", "repl", "--help"], Dict{String,String}()),
                (["completions", "bash", "--json"], Dict{String,String}()),
                (["--json", "--format", "table", "data", "list"], Dict{String,String}()),
                (["data", "list", "-o", "out.csv"], Dict{String,String}()),
                (["data", "list", "--format", "bogus"], Dict{String,String}()),
                (["schema", "-o", "out.json"], Dict{String,String}()),
            )
                fp = _run_proc(wrapper_exe, argv; env_extra=env_extra)
                @test fp.code == 42
                @test startswith(fp.stdout, "CORE_FALLBACK:")
            end

            # Corrupt CRC, truncated pack, bad magic, missing pack -> all fail open
            orig_bytes = read(pack_path)
            # Bad CRC
            bad_crc = copy(orig_bytes); bad_crc[24] ⊻= 0xff
            write(pack_path, bad_crc)
            @test _run_proc(wrapper_exe, ["--version"]).code == 42
            # Bad magic
            bad_magic = copy(orig_bytes); bad_magic[1] = UInt8('X')
            write(pack_path, bad_magic)
            @test _run_proc(wrapper_exe, ["--version"]).code == 42
            # Bad version
            bad_ver = copy(orig_bytes); bad_ver[9] = 99
            write(pack_path, bad_ver)
            @test _run_proc(wrapper_exe, ["--version"]).code == 42
            # Truncated
            write(pack_path, orig_bytes[1:50])
            @test _run_proc(wrapper_exe, ["--version"]).code == 42
            # Missing
            rm(pack_path)
            @test _run_proc(wrapper_exe, ["--version"]).code == 42
            # Restore pack for any subsequent tests
            write(pack_path, orig_bytes)
        end

        @test has_mcp isa Bool
    end
end
