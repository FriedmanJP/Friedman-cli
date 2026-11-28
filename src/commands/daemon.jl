# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Resident worker daemon management commands: `frdc daemon start|stop|status` ([PERF-W3] #357).

function _daemon_start_cmd(; ttl::Int=_DAEMON_DEFAULT_TTL, max_rss_mb::Int=_DAEMON_DEFAULT_MAX_RSS_MB,
                           format::String="table", output::String="")
    ttl > 0 || throw(CliError("usage/invalid", "--ttl must be a positive integer (got $ttl)"))
    max_rss_mb > 0 || throw(CliError("usage/invalid", "--max-rss-mb must be a positive integer (got $max_rss_mb)"))
    eff_threads = _REQUESTED_THREADS[] === nothing ? Threads.nthreads() : _REQUESTED_THREADS[]
    ep = _daemon_endpoint(; threads=eff_threads)
    res = _daemon_start_detached(ep; ttl=ttl, max_rss_mb=max_rss_mb)
    info = res.info
    status_str = res.started ? "started" : "already_running"
    _status("Daemon $(res.started ? "started" : "already running") (pid=$(info.pid), endpoint=$(ep))")
    output_kv(Pair{String,Any}[
        "status"      => status_str,
        "pid"         => Int(info.pid),
        "endpoint"    => ep,
        "stamp"       => string(info.stamp),
        "threads"     => Int(info.threads),
        "rss_mb"      => Float64(info.rss_mb),
        "max_rss_mb"  => Int(info.max_rss_mb),
        "ttl_s"       => ttl,
        "max_workers" => _daemon_max_workers(),
    ]; format=format, output=output, title="Resident Worker Daemon", key="daemon_status")
    return info
end

function _daemon_stop_cmd(; format::String="table", output::String="")
    eff_threads = _REQUESTED_THREADS[] === nothing ? Threads.nthreads() : _REQUESTED_THREADS[]
    ep = _daemon_endpoint(; threads=eff_threads)
    resp = _daemon_stop_endpoint(ep)
    if resp === nothing
        _status("Daemon is not running ($ep)")
        output_kv(Pair{String,Any}[
            "status"   => "not_running",
            "pid"      => 0,
            "endpoint" => ep,
        ]; format=format, output=output, title="Resident Worker Daemon", key="daemon_status")
        return nothing
    end
    pid = Int(get(resp, :pid, 0))
    _status("Daemon stopped (pid=$pid)")
    output_kv(Pair{String,Any}[
        "status"   => "stopped",
        "pid"      => pid,
        "endpoint" => ep,
    ]; format=format, output=output, title="Resident Worker Daemon", key="daemon_status")
    return resp
end

function _daemon_status_cmd(; format::String="table", output::String="")
    eff_threads = _REQUESTED_THREADS[] === nothing ? Threads.nthreads() : _REQUESTED_THREADS[]
    ep = _daemon_endpoint(; threads=eff_threads)
    info = _daemon_ping(ep)
    if info === nothing
        _status("Daemon status: stopped ($ep)")
        output_kv(Pair{String,Any}[
            "status"      => "stopped",
            "pid"         => 0,
            "endpoint"    => ep,
            "stamp"       => _daemon_build_stamp(),
            "threads"     => eff_threads,
            "max_workers" => _daemon_max_workers(),
            "max_rss_mb"  => _daemon_max_rss_mb(),
            "ttl_s"       => _daemon_ttl_sec(),
            "acquire_ms"  => _daemon_acquire_ms(),
        ]; format=format, output=output, title="Resident Worker Daemon", key="daemon_status")
        return nothing
    end
    _status("Daemon status: running (pid=$(info.pid), rss=$(info.rss_mb) MiB, requests=$(info.requests))")
    output_kv(Pair{String,Any}[
        "status"      => "running",
        "pid"         => Int(info.pid),
        "endpoint"    => ep,
        "stamp"       => string(info.stamp),
        "threads"     => Int(info.threads),
        "rss_mb"      => Float64(info.rss_mb),
        "max_rss_mb"  => Int(info.max_rss_mb),
        "requests"    => Int(info.requests),
        "uptime_s"    => Float64(info.uptime_s),
        "max_workers" => _daemon_max_workers(),
        "ttl_s"       => _daemon_ttl_sec(),
        "acquire_ms"  => _daemon_acquire_ms(),
    ]; format=format, output=output, title="Resident Worker Daemon", key="daemon_status")
    return info
end

function daemon_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["daemon", "start"],
            summary="Start the opt-in resident worker daemon (FRDC_DAEMON=1) for the current build stamp and thread count",
            args=ArgSpec[],
            options=vcat([
                OptionSpec(name="ttl", type=Int, default=_DAEMON_DEFAULT_TTL,
                           description="Idle shutdown timeout in seconds (default: 600; env: FRDC_DAEMON_TTL)"),
                OptionSpec(name="max-rss-mb", type=Int, default=_DAEMON_DEFAULT_MAX_RSS_MB,
                           description="Per-worker soft RSS recycle ceiling in MiB (default: 2048; env: FRDC_DAEMON_MAX_RSS_MB)"),
            ], copy(OUTPUT_OPTIONS)),
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:daemon_status,
                          description="Daemon lifecycle status, PID, IPC endpoint, build stamp, threads, RSS, and limits"),
            ],
            category="daemon",
            handler=wrap_legacy(_daemon_start_cmd),
        ),
        CommandSpec(
            path=["daemon", "stop"],
            summary="Gracefully stop the resident worker daemon for the current build stamp and thread count",
            args=ArgSpec[],
            options=copy(OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:daemon_status,
                          description="Daemon stop status, former PID, and IPC endpoint"),
            ],
            category="daemon",
            handler=wrap_legacy(_daemon_stop_cmd),
        ),
        CommandSpec(
            path=["daemon", "status"],
            summary="Inspect resident worker daemon health, PID, RSS, served request count, and safety caps",
            args=ArgSpec[],
            options=copy(OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:daemon_status,
                          description="Daemon health status, PID, endpoint, threads, RSS MiB, requests served, and limits"),
            ],
            category="daemon",
            handler=wrap_legacy(_daemon_status_cmd),
        ),
    ]
end

function register_daemon_commands!()
    specs = with_default_csv_kinds(daemon_specs())
    specs = register!(specs)
    return build_node("daemon", specs;
        description="Manage the opt-in multi-agent-safe resident worker daemon (FRDC_DAEMON=1)")
end
