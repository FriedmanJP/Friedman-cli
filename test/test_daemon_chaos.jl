#!/usr/bin/env julia
# Multi-agent chaos & soak verification suite for the opt-in resident worker
# daemon (FRDC_DAEMON=1, [PERF-W3] #357).
#
# Usage:
#   julia --project test/test_daemon_chaos.jl              # compiles dev thin wrapper
#   FRDC_BIN=build/frdc/bin/frdc julia --project test/test_daemon_chaos.jl

using Test
using JSON3

const _ROOT = normpath(joinpath(@__DIR__, ".."))
const _WRAPPER_DIR = joinpath(_ROOT, "packaging", "thin_wrapper")
const _GEN_SCRIPT  = joinpath(_ROOT, "tools", "gen_fastpath_pack.jl")

function _find_cc()
    if Sys.isapple() && isfile("/usr/bin/cc")
        return "/usr/bin/cc"
    end
    for c in ("cc", "gcc", "clang")
        p = Sys.which(c)
        p === nothing || return p
    end
    error("No C compiler found on PATH")
end

function _prepare_test_bin(tmpdir::String)::String
    env_bin = strip(get(ENV, "FRDC_BIN", ""))
    if !isempty(env_bin) && isfile(env_bin)
        return abspath(env_bin)
    end
    # Build an isolated thin wrapper + dev frdc-core shim inside tmpdir
    bin_dir = joinpath(tmpdir, "app", "bin")
    share_dir = joinpath(tmpdir, "app", "share", "frdc")
    mkpath(bin_dir); mkpath(share_dir)

    pack_path = joinpath(share_dir, "cli_cache.bin")
    run(`$(Base.julia_cmd()) --project=$(_ROOT) $(_GEN_SCRIPT) --output $(pack_path)`)

    cc = _find_cc()
    ext = Sys.iswindows() ? ".exe" : ""
    exe = joinpath(bin_dir, "frdc" * ext)
    flags = String[
        "-std=c99", "-O2", "-Wall", "-Wextra", "-Werror",
        "-I$(_WRAPPER_DIR)",
        "-DFRDC_ENABLE_MCP_PROXY",
        "-DFRDC_ENABLE_DAEMON_CLIENT",
        "-DYYJSON_DISABLE_UTILS=1",
        "-DYYJSON_DISABLE_NON_STANDARD=1",
        "-DYYJSON_DISABLE_INCR_READER=1",
        "-DYYJSON_DISABLE_FAST_FP_CONV=1",
    ]
    Sys.iswindows() && push!(flags, "-municode")
    srcs = [
        joinpath(_WRAPPER_DIR, "frdc_thin.c"),
        joinpath(_WRAPPER_DIR, "mcp_proxy.c"),
        joinpath(_WRAPPER_DIR, "daemon_client.c"),
        joinpath(_WRAPPER_DIR, "yyjson.c"),
    ]
    run(`$cc $flags $srcs -o $exe`)

    if !Sys.iswindows()
        core_shim = joinpath(bin_dir, "frdc-core")
        jexe = Base.julia_cmd().exec[1]
        script = joinpath(_ROOT, "bin", "frdc")
        write(core_shim, "#!/bin/sh\nexec \"$jexe\" --project=\"$(_ROOT)\" \"$script\" \"\$@\"\n")
        chmod(core_shim, 0o755)
    end
    return exe
end

function _run_frdc(exe::String, args::Vector{String};
                   env_extra::Dict{String,String}=Dict{String,String}(),
                   cwd::String=_ROOT)
    out_p, out_io = mktemp()
    err_p, err_io = mktemp()
    try
        env = copy(ENV)
        for k in ("FRDC_NO_FASTPATH", "FRIEDMAN_NO_FASTPATH", "FRDC_NO_DAEMON",
                  "FRDC_DAEMON", "FRDC_DIGITS", "NO_COLOR")
            delete!(env, k)
        end
        for (k, v) in env_extra
            env[k] = v
        end
        cmd = setenv(Cmd(Cmd(vcat([exe], args)); dir=cwd), env)
        proc = run(pipeline(cmd; stdin=devnull, stdout=out_io, stderr=err_io); wait=false)
        wait(proc)
        close(out_io); close(err_io)
        return (code=proc.exitcode, stdout=read(out_p, String), stderr=read(err_p, String))
    finally
        try; close(out_io); catch; end
        try; close(err_io); catch; end
        try; rm(out_p; force=true); catch; end
        try; rm(err_p; force=true); catch; end
    end
end

function _kv_dict(json_str::String, table_key::Symbol)
    j = JSON3.read(json_str)
    rows = j.data[table_key].rows
    return Dict(String(r[1]) => r[2] for r in rows)
end

function _kill_pid_hard(pid::Int)
    pid <= 0 && return
    try
        if Sys.iswindows()
            run(pipeline(`taskkill /F /PID $pid`; stdout=devnull, stderr=devnull); wait=true)
        else
            ccall(:kill, Cint, (Cint, Cint), Cint(pid), Cint(9))  # SIGKILL
        end
    catch
    end
end

@testset "Multi-Agent Resident Worker Daemon Chaos & Soak (#357)" begin
    if Sys.iswindows() && isempty(strip(get(ENV, "FRDC_BIN", "")))
        @info "Skipping Windows dev-shim daemon chaos (requires compiled FRDC_BIN standalone binary)"
        @test true
    else
        mktempdir() do tmpdir
            exe = _prepare_test_bin(tmpdir)
            # Keep daemon runtime dir short (macOS sun_path <= 104 bytes)
            rdir = mktempdir(Sys.isapple() ? "/tmp" : tmpdir; prefix="frdc_ch_")
            stamp = "ch$(string(UInt32(getpid()) & 0xffff; base=16, pad=4))"
            base_env = Dict(
                "FRDC_DAEMON" => "1",
                "FRDC_DAEMON_DIR" => rdir,
                "FRDC_DAEMON_STAMP" => stamp,
                "FRDC_DAEMON_TTL" => "120",
                "FRDC_DAEMON_BOOT_MS" => "30000",
            )

            try
                @testset "1. 30-way cold thundering herd (single rendezvous, <= 1 daemon)" begin
                    herd_env = merge(base_env, Dict("FRDC_DAEMON_ACQUIRE_MS" => "25000"))
                    tasks = [
                        @async _run_frdc(exe, ["-J", "--seed", string(100 + k), "data", "describe", ":denmark"];
                                         env_extra=herd_env)
                        for k in 1:30
                    ]
                    results = fetch.(tasks)
                    @test length(results) == 30
                    for (k, r) in enumerate(results)
                        @test r.code == 0
                        j = JSON3.read(r.stdout)
                        @test j.status == "ok"
                        @test j.meta.seed == 100 + k
                    end

                    # Inspect daemon status: single resident worker served the herd
                    st = _run_frdc(exe, ["-J", "daemon", "status"]; env_extra=base_env)
                    @test st.code == 0
                    kv = _kv_dict(st.stdout, :daemon_status)
                    @test kv["status"] == "running"
                    @test Int(kv["pid"]) > 0
                    @test Int(kv["max_workers"]) <= 2
                    @test Int(kv["requests"]) == 30
                    if !Sys.iswindows()
                        socks = filter(f -> endswith(f, ".sock"), readdir(rdir))
                        @test length(socks) == 1
                    end
                end

                @testset "2. Mixed slow + fast concurrency, fail-open & zero state leakage" begin
                    # Two distinct CWDs with different local.csv contents
                    cwd_a = joinpath(tmpdir, "cwd_a"); mkpath(cwd_a)
                    cwd_b = joinpath(tmpdir, "cwd_b"); mkpath(cwd_b)
                    write(joinpath(cwd_a, "local.csv"), "alpha,beta\n1.0,2.0\n3.0,4.0\n5.0,6.0\n7.0,8.0\n")
                    write(joinpath(cwd_b, "local.csv"), "gamma,delta\n10.0,20.0\n30.0,40.0\n50.0,60.0\n70.0,80.0\n")

                    # Start a heavier request holding the warm worker (force on-daemon)
                    slow_env = merge(base_env, Dict(
                        "FRDC_DAEMON_BYPASS_HEAVY" => "0",
                        "FRDC_DAEMON_ACQUIRE_MS" => "5000",
                    ))
                    slow_task = @async _run_frdc(
                        exe,
                        ["-J", "--seed", "777", "estimate", "multivariate", "bvar", ":denmark", "--lags", "2", "--draws", "400"];
                        env_extra=slow_env,
                    )
                    sleep(0.15)

                    # Fire 10 concurrent fast requests with distinct seeds, digits, FRDC_DIGITS, and CWDs
                    fast_env = merge(base_env, Dict("FRDC_DAEMON_ACQUIRE_MS" => "150"))
                    fast_tasks = Task[]
                    for k in 1:10
                        use_a = isodd(k)
                        cdir = use_a ? cwd_a : cwd_b
                        e = merge(fast_env, Dict("FRDC_DIGITS" => string(mod1(k, 6))))
                        push!(fast_tasks, @async _run_frdc(
                            exe,
                            ["-J", "--seed", string(200 + k), "data", "describe", "local.csv"];
                            env_extra=e, cwd=cdir,
                        ))
                    end

                    slow_res = fetch(slow_task)
                    @test slow_res.code == 0
                    sj = JSON3.read(slow_res.stdout)
                    @test sj.status == "ok"
                    @test sj.meta.seed == 777

                    fast_results = fetch.(fast_tasks)
                    for (k, r) in enumerate(fast_results)
                        @test r.code == 0
                        j = JSON3.read(r.stdout)
                        @test j.status == "ok"
                        @test j.meta.seed == 200 + k
                        tbl = j.data[:descriptive_statistics]
                        var_col = [String(row[1]) for row in tbl.rows]
                        if isodd(k)
                            @test "alpha" in var_col
                            @test !("gamma" in var_col)
                        else
                            @test "gamma" in var_col
                            @test !("alpha" in var_col)
                        end
                    end

                    # Verify FRDC_DIGITS / --seed did not bleed into a subsequent clean call
                    clean_r = _run_frdc(exe, ["-J", "data", "describe", ":denmark"]; env_extra=base_env)
                    @test clean_r.code == 0
                    cj = JSON3.read(clean_r.stdout)
                    @test cj.status == "ok"
                    @test cj.meta.seed === nothing
                end

                @testset "3. Mid-request SIGKILL crash & clean respawn recovery" begin
                    st1 = _run_frdc(exe, ["-J", "daemon", "status"]; env_extra=base_env)
                    @test st1.code == 0
                    old_pid = Int(_kv_dict(st1.stdout, :daemon_status)["pid"])
                    @test old_pid > 0

                    # Launch an in-flight daemon request and SIGKILL the worker mid-request
                    kill_env = merge(base_env, Dict("FRDC_DAEMON_ACQUIRE_MS" => "5000"))
                    inflight = @async _run_frdc(
                        exe,
                        ["-J", "--seed", "55", "estimate", "multivariate", "bvar", ":denmark", "--lags", "2", "--draws", "1500"];
                        env_extra=kill_env,
                    )
                    sleep(0.15)
                    _kill_pid_hard(old_pid)

                    # Client must not hang (exits cleanly with error or completed result)
                    kr = fetch(inflight)
                    @test kr.code in (0, 1)

                    # Wait briefly for OS process cleanup, then next command must respawn cleanly
                    sleep(0.2)
                    rec = _run_frdc(exe, ["-J", "data", "describe", ":denmark"]; env_extra=base_env)
                    @test rec.code == 0
                    rj = JSON3.read(rec.stdout)
                    @test rj.status == "ok"

                    st2 = _run_frdc(exe, ["-J", "daemon", "status"]; env_extra=base_env)
                    @test st2.code == 0
                    kv2 = _kv_dict(st2.stdout, :daemon_status)
                    @test kv2["status"] == "running"
                    @test Int(kv2["pid"]) > 0
                    @test Int(kv2["pid"]) != old_pid
                end

                @testset "4. RSS ceiling clean recycle between requests (zero dropped requests)" begin
                    # Stop existing daemon first
                    stop_r = _run_frdc(exe, ["-J", "daemon", "stop"]; env_extra=base_env)
                    @test stop_r.code == 0

                    # Restart with 1 MiB ceiling so worker recycles after serving request 1
                    rss_env = merge(base_env, Dict("FRDC_DAEMON_MAX_RSS_MB" => "1"))
                    start_r = _run_frdc(exe, ["-J", "daemon", "start", "--max-rss-mb", "1"]; env_extra=rss_env)
                    @test start_r.code == 0
                    pid1 = Int(_kv_dict(start_r.stdout, :daemon_status)["pid"])
                    @test pid1 > 0

                    # Request 1 succeeds completely, then worker recycles itself cleanly
                    r1 = _run_frdc(exe, ["-J", "data", "describe", ":denmark"]; env_extra=rss_env)
                    @test r1.code == 0
                    @test JSON3.read(r1.stdout).status == "ok"

                    # Wait for worker 1 to finish exiting after recycle
                    for _ in 1:40
                        st = _run_frdc(exe, ["-J", "daemon", "status"]; env_extra=rss_env)
                        if st.code == 0 && _kv_dict(st.stdout, :daemon_status)["status"] == "stopped"
                            break
                        end
                        sleep(0.05)
                    end

                    # Request 2 spawns fresh worker with a new PID and succeeds
                    r2 = _run_frdc(exe, ["-J", "estimate", "multivariate", "var", ":denmark", "--lags", "1"]; env_extra=rss_env)
                    @test r2.code == 0
                    @test JSON3.read(r2.stdout).status == "ok"

                    # Clean stop
                    _run_frdc(exe, ["-J", "daemon", "stop"]; env_extra=rss_env)
                end
            finally
                try
                    _run_frdc(exe, ["-J", "daemon", "stop"]; env_extra=base_env)
                catch
                end
                try; rm(rdir; force=true, recursive=true); catch; end
            end
        end
    end
end
