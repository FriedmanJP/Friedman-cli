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

        # 2. Generate FRDCACHE v2 pack from live Friedman and verify pack invariants
        stats = generate_fastpath_pack(pack_path)
        @test isfile(pack_path)
        @test stats.n_nodes >= 600
        @test stats.n_aliases >= 190
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
                    exp = _capture_help_plain(io -> Friedman.print_help(io, sub; prog=prog,
                                                                        aliases=Friedman._aliases_for(node, name)))
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

        @test has_mcp == true

        # 10. Lazy MCP Proxy (#299): zero-spawn discovery parity + multi-call live handoff
        @testset "Lazy MCP Proxy (#299)" begin
            # Helper to run live Julia _serve_loop for differential comparison
            function run_julia_mcp(input_str::String; families::String="", tools::String="", compact::Bool=false)
                in_io = IOBuffer(input_str)
                out_io = IOBuffer()
                Friedman._serve_loop(in_io, out_io; families=families, tools=tools, compact=compact)
                return [JSON3.read(l) for l in split(String(take!(out_io)), '\n') if !isempty(strip(l))]
            end

            # 10a. Pure discovery session (asserts ZERO frdc-core spawns — core stub exits 42!)
            discovery_lines = join([
                """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}""",
                """{"jsonrpc":"2.0","method":"notifications/initialized"}""",
                """{"jsonrpc":"2.0","id":"p-1","method":"ping"}""",
                """{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"prefix":"estimate multivariate","limit":5}}""",
                """{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{"prefix":"estimate multivariate","cursor":"5","limit":5}}""",
                """{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{"families":"ri"}}""",
                """{"jsonrpc":"2.0","id":5,"method":"tools/list","params":{"tools":"irf_*"}}""",
                """{"jsonrpc":"2.0","id":6,"method":"tools/list","params":{"prefix":"nonexistent_prefix"}}""",
                """not valid json""",
                """{"jsonrpc":"2.0","id":7,"method":"unknown/method"}""",
                """{"jsonrpc":"2.0","method":"unknown/notification_no_id"}""",
                """{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"totally_bogus_tool","arguments":{}}}""",
            ], "\n") * "\n"

            fp_disc = _run_proc(wrapper_exe, ["serve", "--mcp"]; stdin_data=discovery_lines)
            @test fp_disc.code == 0
            @test occursin("frdc MCP server on stdio", fp_disc.stderr)
            @test !occursin("CORE_FALLBACK", fp_disc.stdout)
            fp_msgs = [JSON3.read(l) for l in split(fp_disc.stdout, '\n') if !isempty(strip(l))]
            jl_msgs = run_julia_mcp(discovery_lines)
            @test length(fp_msgs) == length(jl_msgs) == 10
            for (fm, jm) in zip(fp_msgs, jl_msgs)
                @test fm == jm
            end

            # --quiet suppresses banner; --compact & CLI --families/--tools filter both tools/list & unknown-tool check
            scoped_lines = join([
                """{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}""",
                """{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"irf_var","arguments":{}}}""",
            ], "\n") * "\n"
            fp_sc = _run_proc(wrapper_exe, ["serve", "--mcp", "--quiet", "--compact", "--families", "ri"];
                              stdin_data=scoped_lines)
            @test fp_sc.code == 0
            @test fp_sc.stderr == ""
            sc_msgs = [JSON3.read(l) for l in split(fp_sc.stdout, '\n') if !isempty(strip(l))]
            jl_sc = run_julia_mcp(scoped_lines; families="ri", compact=true)
            @test length(sc_msgs) == 2
            @test sc_msgs[1] == jl_sc[1]
            # irf_var is outside --families ri -> rejected as -32602 WITHOUT spawning frdc-core!
            @test Int(sc_msgs[2].error.code) == -32602
            @test String(sc_msgs[2].error.message) == "unknown tool: irf_var"

            # 10b. Pin Julia _serve_loop invariant: accepts tools/call without prior initialize
            direct_call = """{"jsonrpc":"2.0","id":99,"method":"tools/call","params":{"name":"data_list","arguments":{}}}\n"""
            direct_res = run_julia_mcp(direct_call)
            @test length(direct_res) == 1
            @test !direct_res[1].result.isError
            @test String(JSON3.read(String(direct_res[1].result.content[1].text)).status) == "ok"

            # 10c. Full multi-call lazy handoff into live Julia backend (POSIX: piped batch + interactive)
            # Verifies: zero duplicate banner, zero lost buffered bytes, model:// session persistence across calls
            if !Sys.iswindows()
                mktempdir() do d2
                    b2 = joinpath(d2, "bin")
                    s2 = joinpath(d2, "share", "frdc")
                    mkpath(b2); mkpath(s2)
                    cp(wrapper_exe, joinpath(b2, "frdc"))
                    cp(pack_path, joinpath(s2, "cli_cache.bin"))
                    # Wire frdc-core to live Julia CLI
                    core_sh = joinpath(b2, "frdc-core")
                    write(core_sh, "#!/bin/sh\nexec \"$(joinpath(Sys.BINDIR, "julia"))\" --project=\"$(_ROOT)\" \"$(joinpath(_ROOT, "bin", "frdc"))\" \"\$@\"\n")
                    chmod(core_sh, 0o755)

                    # Fixture CSV for VAR + IRF session test
                    csv_p = joinpath(d2, "var_mcp.csv")
                    open(csv_p, "w") do io
                        println(io, "y1,y2")
                        for t in 1:40
                            println(io, "$(sin(t/3)),$(cos(t/4))")
                        end
                    end

                    batch = join([
                        """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}""",
                        """{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"prefix":"irf","limit":2}}""",
                        """{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"estimate_multivariate_var","arguments":{"data":"$csv_p","lags":1,"save-model":"model://m1"}}}""",
                        """{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"irf_var","arguments":{"model":"model://m1","horizons":4}}}""",
                        """{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"model_info","arguments":{"path":"model://m1"}}}""",
                        """{"jsonrpc":"2.0","id":6,"method":"tools/list","params":{"prefix":"ri","limit":2}}""",
                    ], "\n") * "\n"

                    res = _run_proc(joinpath(b2, "frdc"), ["serve", "--mcp"]; stdin_data=batch)
                    @test res.code == 0
                    # Exactly ONE startup banner on stderr (Julia core silenced via FRDC_MCP_SILENT_BANNER=1)
                    @test count("frdc MCP server on stdio", res.stderr) == 1
                    msgs = [JSON3.read(l) for l in split(res.stdout, '\n') if !isempty(strip(l))]
                    @test length(msgs) == 6
                    @test Int(msgs[1].id) == 1 && String(msgs[1].result.serverInfo.name) == "frdc"
                    @test Int(msgs[2].id) == 2 && length(msgs[2].result.tools) == 2
                    for k in 3:5
                        @test Int(msgs[k].id) == k
                        @test !msgs[k].result.isError
                        env_doc = JSON3.read(String(msgs[k].result.content[1].text))
                        @test String(env_doc.status) == "ok"
                    end
                    @test Int(msgs[6].id) == 6 && length(msgs[6].result.tools) == 2

                    # Interactive line-by-line session (write -> flush -> read each response before next write)
                    py = Sys.which("python3")
                    if py !== nothing
                        inter = read(`$py -c "
import json, subprocess, sys
p = subprocess.Popen([sys.argv[1], 'serve', '--mcp', '--quiet'],
                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
def ask(obj):
    p.stdin.write(json.dumps(obj) + '\n'); p.stdin.flush()
    return json.loads(p.stdout.readline())
r1 = ask({'jsonrpc':'2.0','id':1,'method':'initialize','params':{}})
assert r1['result']['serverInfo']['name'] == 'frdc'
r2 = ask({'jsonrpc':'2.0','id':2,'method':'tools/list','params':{'prefix':'data','limit':3}})
assert len(r2['result']['tools']) == 3
r3 = ask({'jsonrpc':'2.0','id':3,'method':'tools/call','params':{'name':'data_list','arguments':{}}})
assert not r3['result']['isError']
r4 = ask({'jsonrpc':'2.0','id':4,'method':'ping'})
assert r4['id'] == 4 and r4['result'] == {}
p.stdin.close()
err = p.stderr.read()
rc = p.wait()
assert rc == 0 and err == '', (rc, err)
print('INTERACTIVE_OK')
" $(joinpath(b2, "frdc"))`, String)
                        @test strip(inter) == "INTERACTIVE_OK"
                    end
                end
            end
            # 10d. [UX-W2/W3] & [DISPLAY-W5] & [ABBREV-W4] differential parity gates (#327, #339, #343, #344, #346)
            @testset "MCP scope intersection, instructions & schema parity (#343, #344, #346)" begin
                # initialize.result.instructions byte-for-byte parity (C99 proxy <-> Julia)
                init_line = """{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n"""
                fp_init = _run_proc(wrapper_exe, ["serve", "--mcp", "--quiet"]; stdin_data=init_line)
                @test fp_init.code == 0
                j_init = run_julia_mcp(init_line)
                c_init = JSON3.read(strip(fp_init.stdout))
                @test haskey(c_init.result, :instructions)
                @test String(c_init.result.instructions) == String(j_init[1].result.instructions)
                @test String(c_init.result.instructions) == Friedman._MCP_INSTRUCTIONS

                # Scoped tools/list intersection: --families ri cannot be widened by params.families="dsge"
                scope_probe = join([
                    """{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"families":"dsge"}}""",
                    """{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{"tools":"dsge_*"}}""",
                    """{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{"prefix":"dsge"}}""",
                    """{"jsonrpc":"2.0","id":4,"method":"tools/list","params":{"tools":"ri_solve"}}""",
                ], "\n") * "\n"
                fp_sp = _run_proc(wrapper_exe, ["serve", "--mcp", "--quiet", "--families", "ri"]; stdin_data=scope_probe)
                @test fp_sp.code == 0
                c_sp = [JSON3.read(l) for l in split(fp_sp.stdout, '\n') if !isempty(strip(l))]
                j_sp = run_julia_mcp(scope_probe; families="ri")
                @test length(c_sp) == 4
                for k in 1:4
                    @test c_sp[k] == j_sp[k]
                end
                @test isempty(c_sp[1].result.tools)
                @test isempty(c_sp[2].result.tools)
                @test isempty(c_sp[3].result.tools)
                @test [String(t.name) for t in c_sp[4].result.tools] == ["ri_solve"]

                # Slim MCP schemas served from C99 cache: 0 ignored format, 0 plot, 0 x-cli.aliases, 26 anyOf
                all_req = """{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}\n"""
                fp_all = _run_proc(wrapper_exe, ["serve", "--mcp", "--quiet"]; stdin_data=all_req)
                fp_cmp = _run_proc(wrapper_exe, ["serve", "--mcp", "--quiet", "--compact"]; stdin_data=all_req)
                @test fp_all.code == 0 && fp_cmp.code == 0
                all_tools = JSON3.read(strip(fp_all.stdout)).result.tools
                cmp_tools = JSON3.read(strip(fp_cmp.stdout)).result.tools
                @test all(t -> !haskey(t.inputSchema.properties, :format), all_tools)
                @test all(t -> !haskey(t.inputSchema.properties, :plot), all_tools)
                @test all(t -> !haskey(t.inputSchema.properties, :format), cmp_tools)
                @test all(t -> all(pv -> !(pv isa JSON3.Object && haskey(pv, Symbol("x-cli")) && haskey(pv[Symbol("x-cli")], :aliases)),
                                   values(t.inputSchema.properties)), all_tools)
                # Leading --seed on serve fails open cleanly to frdc-core (core stub returns 42)
                fp_seed_srv = _run_proc(wrapper_exe, ["--seed", "42", "serve", "--mcp"])
                @test fp_seed_srv.code == 42
                @test startswith(fp_seed_srv.stdout, "CORE_FALLBACK:")
            end

            @testset "Global --digits, FRDC_DIGITS, -J & FRDCACHE v2 alias fast-paths (#327, #339)" begin
                # Valid --digits / -J fast-path parity with Julia core
                for argv in (
                    ["--digits", "6", "data", "list"],
                    ["--digits=full", "data", "list", "--format", "json"],
                    ["data", "list", "--digits", "4"],
                    ["--digits", "6", "--help"],
                    ["--digits=3", "estimate", "--help"],
                    ["-J", "data", "list"],
                    # FRDCACHE v2 coexisting command/family/leaf aliases (Tier 1, 2, 3, 4)
                    ["est", "--help"],
                    ["est", "mv", "--help"],
                    ["est", "mv", "var", "-h"],
                    ["d", "ls"],
                    ["d", "ls", "-f", "json"],
                    ["sch", "est", "mv", "var"],
                    ["schema", "est", "mv", "var"],
                    ["comp", "zsh"],
                    ["est", "mv", "nope"],
                    ["est", "mv", "nope", "-J"],
                    ["est", "var", "bvar"],
                )
                    fp = _run_proc(wrapper_exe, argv)
                    jl = _run_julia_cli(argv)
                    @test fp.code == jl.code
                    @test fp.stderr == jl.stderr
                    if any(t -> t in ("json", "--json", "-J") || endswith(t, "=json"), argv) ||
                       first(argv) in ("sch", "schema")
                        # Compare parsed JSON (ignoring elapsed_ms / timestamp)
                        fd = JSON3.read(strip(fp.stdout))
                        jd = JSON3.read(strip(jl.stdout))
                        if haskey(fd, :status)
                            @test fd.status == jd.status
                            @test fd.command == jd.command
                            @test fd.data == jd.data
                            @test fd.error == jd.error
                            @test collect(String.(fd.meta.argv)) == collect(String.(jd.meta.argv))
                        else
                            @test fd == jd
                        end
                    else
                        @test fp.stdout == jl.stdout
                    end
                end

                # Invalid --digits and invalid FRDC_DIGITS fail open to frdc-core (stub exit 42)
                for bad_argv in (
                    ["--digits", "invalid", "data", "list"],
                    ["--digits=99", "data", "list"],
                    ["--digits", "invalid", "--json", "data", "list"],
                )
                    r = _run_proc(wrapper_exe, bad_argv)
                    @test r.code == 42 && startswith(r.stdout, "CORE_FALLBACK:")
                end
                r_env = _run_proc(wrapper_exe, ["data", "list"]; env_extra=Dict("FRDC_DIGITS" => "bad"))
                @test r_env.code == 42 && startswith(r_env.stdout, "CORE_FALLBACK:")
                # Valid CLI --digits overrides bad FRDC_DIGITS (matches src/io.jl:272)
                r_ovr = _run_proc(wrapper_exe, ["--digits", "4", "data", "list"]; env_extra=Dict("FRDC_DIGITS" => "bad"))
                @test r_ovr.code == 0 && !startswith(r_ovr.stdout, "CORE_FALLBACK:")
            end
        end
    end
end
