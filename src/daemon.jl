# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Multi-agent-safe opt-in resident worker daemon ([PERF-W3] #357).
# See docs/src/internals/daemon-adr.md for the full ADR and safety invariants.

const _DAEMON_DEFAULT_TTL = 600
const _DAEMON_DEFAULT_MAX_RSS_MB = 2048
const _DAEMON_DEFAULT_TOTAL_RSS_MB = 4096
const _DAEMON_DEFAULT_ACQUIRE_MS = 200
const _DAEMON_MAX_FRAME_BYTES = 64 * 1024 * 1024
const _DAEMON_EXEC_LOCK = ReentrantLock()

# Environment variables propagated across the daemon IPC boundary and restored
# verbatim in the state-reset barrier after every request.
const _DAEMON_EXACT_ENV_KEYS = ("NO_COLOR", "COLUMNS", "LINES", "TZ")

function _daemon_is_propagated_env(k::AbstractString)::Bool
    startswith(k, "FRDC_") && return true
    startswith(k, "FRIEDMAN_") && return true
    return k in _DAEMON_EXACT_ENV_KEYS
end

"""FNV-1a 32-bit hash matching `packaging/thin_wrapper/daemon_client.c` 1:1."""
function _daemon_fnv1a32(s::AbstractString)::UInt32
    h = UInt32(0x811c9dc5)
    for b in codeunits(String(s))
        h = xor(h, UInt32(b))
        h = h * UInt32(0x01000193)
    end
    return h
end

function _daemon_hex8(v::UInt32)::String
    return lpad(string(v; base=16), 8, '0')
end

function _daemon_parse_pos_int_env(key::String, default::Int; max_val::Int=10_000_000)::Int
    raw = strip(get(ENV, key, ""))
    isempty(raw) && return default
    v = tryparse(Int, raw)
    (v === nothing || v <= 0) && return default
    return min(v, max_val)
end

function _daemon_max_workers()::Int
    hard_cap = max(1, min(2, div(max(1, Int(Sys.CPU_THREADS)), 2)))
    req = _daemon_parse_pos_int_env("FRDC_DAEMON_MAX_WORKERS", 1; max_val=hard_cap)
    return clamp(req, 1, hard_cap)
end

_daemon_max_rss_mb()::Int = _daemon_parse_pos_int_env("FRDC_DAEMON_MAX_RSS_MB", _DAEMON_DEFAULT_MAX_RSS_MB)
_daemon_total_rss_mb()::Int = _daemon_parse_pos_int_env("FRDC_DAEMON_TOTAL_RSS_MB", _DAEMON_DEFAULT_TOTAL_RSS_MB)
_daemon_ttl_sec()::Int = _daemon_parse_pos_int_env("FRDC_DAEMON_TTL", _DAEMON_DEFAULT_TTL)
_daemon_acquire_ms()::Int = _daemon_parse_pos_int_env("FRDC_DAEMON_ACQUIRE_MS", _DAEMON_DEFAULT_ACQUIRE_MS)

"""Resolve build stamp matching `daemon_client.c` (8-hex CRC32 from cli_cache.bin or version FNV-1a)."""
function _daemon_build_stamp()::String
    ov = strip(get(ENV, "FRDC_DAEMON_STAMP", ""))
    !isempty(ov) && return ov
    # Check sibling ../share/frdc/cli_cache.bin relative to executable (standalone bundle)
    try
        exe = Base.julia_cmd().exec[1]
        for base in (dirname(dirname(exe)), dirname(@__DIR__))
            pack = joinpath(base, "share", "frdc", "cli_cache.bin")
            if isfile(pack)
                hdr = open(io -> read(io, 20), pack, "r")
                if length(hdr) == 20 && String(hdr[1:8]) == "FRDCACHE"
                    crc = UInt32(hdr[17]) | (UInt32(hdr[18]) << 8) |
                          (UInt32(hdr[19]) << 16) | (UInt32(hdr[20]) << 24)
                    return _daemon_hex8(crc)
                end
            end
        end
    catch
    end
    return _daemon_hex8(_daemon_fnv1a32(string(FRIEDMAN_VERSION)))
end

function _daemon_uid_str()::String
    if Sys.iswindows()
        u = strip(get(ENV, "USERNAME", "user"))
        return isempty(u) ? "user" : replace(u, r"[^A-Za-z0-9_-]" => "_")
    end
    return string(ccall(:geteuid, UInt32, ()))
end

"""User-private runtime directory (0700 on POSIX), matching `daemon_client.c`."""
function _daemon_runtime_dir()::String
    ov = strip(get(ENV, "FRDC_DAEMON_DIR", ""))
    dir = if !isempty(ov)
        _expanduser(ov)
    elseif Sys.iswindows()
        la = strip(get(ENV, "LOCALAPPDATA", ""))
        base = isempty(la) ? tempdir() : joinpath(la, "frdc")
        joinpath(base, "run")
    else
        xdg = strip(get(ENV, "XDG_RUNTIME_DIR", ""))
        if !isempty(xdg) && isdir(xdg)
            joinpath(xdg, "frdc")
        else
            tmp = strip(get(ENV, "TMPDIR", ""))
            base = isempty(tmp) ? "/tmp" : rstrip(tmp, '/')
            joinpath(base, "frdc-" * _daemon_uid_str())
        end
    end
    mkpath(dir)
    if !Sys.iswindows()
        try; chmod(dir, 0o700); catch; end
    end
    return dir
end

function _daemon_endpoint_tag(; threads::Int=Threads.nthreads())::String
    stamp = _daemon_build_stamp()
    rhash = _daemon_hex8(_daemon_fnv1a32(strip(get(ENV, "FRDC_DATA_ROOT", ""))))
    return "d-$(stamp)-t$(threads)-$(rhash)"
end

"""Deterministic daemon IPC endpoint (Unix socket path on POSIX, Named Pipe on Windows)."""
function _daemon_endpoint(; threads::Int=Threads.nthreads())::String
    tag = _daemon_endpoint_tag(; threads=threads)
    if Sys.iswindows()
        return "\\\\.\\pipe\\frdc-$(_daemon_uid_str())-$(tag)"
    end
    return joinpath(_daemon_runtime_dir(), "$(tag).sock")
end

function _daemon_lock_path(; threads::Int=Threads.nthreads())::String
    tag = _daemon_endpoint_tag(; threads=threads)
    return joinpath(_daemon_runtime_dir(), "$(tag).lock")
end

# ── Current process RSS measurement (MiB) ───────────────────────────────

function _daemon_rss_mb()::Float64
    try
        if Sys.islinux() && isfile("/proc/self/statm")
            parts = split(strip(read("/proc/self/statm", String)))
            if length(parts) >= 2
                pages = parse(Int64, parts[2])
                pgsz = ccall(:sysconf, Clong, (Cint,), 30)  # _SC_PAGESIZE = 30 on Linux
                pgsz = pgsz > 0 ? Int64(pgsz) : Int64(4096)
                return (pages * pgsz) / 1048576.0
            end
        elseif Sys.isapple()
            # mach_task_basic_info (flavor=20): resident_size is UInt64 at slot 2 (1-based)
            task = ccall(:mach_task_self, UInt32, ())
            buf = zeros(UInt64, 12)
            cnt = Ref{UInt32}(UInt32(10))  # MACH_TASK_BASIC_INFO_COUNT = 10 natural_t (40 bytes)
            kr = ccall(:task_info, Cint,
                       (UInt32, UInt32, Ptr{Cvoid}, Ptr{UInt32}),
                       task, UInt32(20), pointer(buf), cnt)
            if kr == 0 && buf[2] > 0
                return Float64(buf[2]) / 1048576.0
            end
        elseif Sys.iswindows()
            # PROCESS_MEMORY_COUNTERS: WorkingSetSize is UInt64 at offset 16 (index 3 of UInt64[10]) on x86_64
            hproc = ccall((:GetCurrentProcess, "kernel32"), Ptr{Cvoid}, ())
            pmc = zeros(UInt64, 10)
            pmc[1] = UInt64(sizeof(pmc))
            ok = ccall((:K32GetProcessMemoryInfo, "kernel32"), Cint,
                       (Ptr{Cvoid}, Ptr{Cvoid}, UInt32),
                       hproc, pointer(pmc), UInt32(sizeof(pmc)))
            if ok != 0 && pmc[3] > 0
                return Float64(pmc[3]) / 1048576.0
            end
        end
    catch
    end
    return Float64(Sys.maxrss()) / 1048576.0
end

# ── Peer identity check (SO_PEERCRED / getpeereid) ──────────────────────

function _daemon_verify_peer(sock)::Bool
    Sys.iswindows() && return true  # Named Pipe runs under owner-scoped Windows session
    try
        fd = Base._fd(sock)
        fd_i = Base.cconvert(Cint, fd)
        my_uid = ccall(:geteuid, UInt32, ())
        if Sys.isapple()
            euid = Ref{UInt32}(typemax(UInt32))
            egid = Ref{UInt32}(typemax(UInt32))
            rc = ccall(:getpeereid, Cint, (Cint, Ptr{UInt32}, Ptr{UInt32}), fd_i, euid, egid)
            return rc == 0 && euid[] == my_uid
        elseif Sys.islinux()
            # struct ucred { pid_t pid; uid_t uid; gid_t gid; } (3 x Int32)
            # SOL_SOCKET = 1, SO_PEERCRED = 17 on Linux x86_64/aarch64
            cred = zeros(Int32, 3)
            len = Ref{UInt32}(UInt32(sizeof(cred)))
            rc = ccall(:getsockopt, Cint,
                       (Cint, Cint, Cint, Ptr{Cvoid}, Ptr{UInt32}),
                       fd_i, Cint(1), Cint(17), pointer(cred), len)
            return rc == 0 && UInt32(cred[2]) == my_uid
        end
    catch
        return false
    end
    return true
end

# ── Length-prefixed JSON wire framing ───────────────────────────────────

function _daemon_write_frame(io::IO, obj)
    payload = Vector{UInt8}(codeunits(JSON3.write(obj)))
    n = length(payload)
    (n == 0 || n > _DAEMON_MAX_FRAME_BYTES) && error("daemon frame size out of bounds: $n")
    hdr = UInt8[
        UInt8(n & 0xff),
        UInt8((n >> 8) & 0xff),
        UInt8((n >> 16) & 0xff),
        UInt8((n >> 24) & 0xff),
    ]
    write(io, hdr)
    write(io, payload)
    flush(io)
    return nothing
end

function _daemon_read_frame(io::IO)
    hdr = Vector{UInt8}(undef, 4)
    nb = readbytes!(io, hdr, 4)
    nb == 4 || return nothing
    n = Int(hdr[1]) | (Int(hdr[2]) << 8) | (Int(hdr[3]) << 16) | (Int(hdr[4]) << 24)
    (n <= 0 || n > _DAEMON_MAX_FRAME_BYTES) && return nothing
    buf = Vector{UInt8}(undef, n)
    got = readbytes!(io, buf, n)
    got == n || return nothing
    return JSON3.read(String(buf))
end

# ── Exhaustive 23-Ref state-reset barrier ───────────────────────────────

"""Reset all 23 invocation-scoped module-level Refs and re-randomize RNG state (#357)."""
function _daemon_reset_state!()
    _ENVELOPE[] = nothing
    _ENVELOPE_EMITTED[] = false
    _CURRENT_EXPLICIT_OPTS[] = Set{String}()
    _IN_DISPATCH[] = false
    _THREAD_MODE[] = :julia_threads
    isdefined(@__MODULE__, :_SESSION_STORE) && (_SESSION_STORE[] = nothing)
    isdefined(@__MODULE__, :_INVOCATION_HANDLE_CACHE) && (_INVOCATION_HANDLE_CACHE[] = nothing)
    isdefined(@__MODULE__, :_INVOCATION_HANDLE_META) && (_INVOCATION_HANDLE_META[] = nothing)
    isdefined(@__MODULE__, :_NEXT_SAVE_VARNAMES) && (_NEXT_SAVE_VARNAMES[] = nothing)
    isdefined(@__MODULE__, :_NEXT_SAVE_KIND) && (_NEXT_SAVE_KIND[] = "")
    isdefined(@__MODULE__, :_HANDLE_LOAD_COUNTER) && (_HANDLE_LOAD_COUNTER[] = 0)
    _SEED[] = nothing
    _LAST_ARGV[] = String[]
    _DISPLAY_DIGITS[] = _DEFAULT_DISPLAY_DIGITS
    _REQUESTED_THREADS[] = nothing
    isdefined(@__MODULE__, :_SERVE_MODEL_STORE) && (_SERVE_MODEL_STORE[] = nothing)
    isdefined(@__MODULE__, :_SERVE_SOURCE_MODELS) && (_SERVE_SOURCE_MODELS[] = nothing)
    _QUIET[] = false
    _COLOR[] = !haskey(ENV, "NO_COLOR")
    _COMPACT[] = false
    _FORCE_JSON[] = false
    _ENVELOPE_JSON_TO_FILE[] = false
    isdefined(@__MODULE__, :_CONFIG_STRICT) && (_CONFIG_STRICT[] = false)
    Random.seed!()
    return nothing
end

function _daemon_exec_isolated(argv::Vector{String}, req_cwd::String, req_env::Dict{String,String})
    orig_cwd = pwd()
    # Snapshot all propagated env keys currently set in worker process
    orig_env = Dict{String,Union{String,Nothing}}()
    for k in collect(keys(ENV))
        _daemon_is_propagated_env(k) && (orig_env[k] = ENV[k])
    end
    for k in keys(req_env)
        _daemon_is_propagated_env(k) && !haskey(orig_env, k) && (orig_env[k] = nothing)
    end

    out_path, out_io = mktemp()
    err_path, err_io = mktemp()
    rc = Cint(1)
    try
        # Apply whitelisted request env
        for k in keys(orig_env)
            if haskey(req_env, k)
                ENV[k] = req_env[k]
            else
                delete!(ENV, k)
            end
        end
        for (k, v) in req_env
            _daemon_is_propagated_env(k) && (ENV[k] = v)
        end

        _daemon_reset_state!()

        if !isempty(req_cwd)
            if !isdir(req_cwd)
                return (exit_code=Int(3), stdout="", stderr="Error: working directory not found: $req_cwd\n")
            end
            cd(req_cwd)
        end

        rc = redirect_stdout(out_io) do
            redirect_stderr(err_io) do
                run_cli(argv)
            end
        end
        flush(out_io); flush(err_io)
        close(out_io); close(err_io)
        so = isfile(out_path) ? read(out_path, String) : ""
        se = isfile(err_path) ? read(err_path, String) : ""
        return (exit_code=Int(rc), stdout=so, stderr=se)
    catch e
        try; flush(out_io); flush(err_io); catch; end
        try; close(out_io); close(err_io); catch; end
        so = isfile(out_path) ? read(out_path, String) : ""
        se = (isfile(err_path) ? read(err_path, String) : "") * "Error: " * sprint(showerror, e) * "\n"
        return (exit_code=1, stdout=so, stderr=se)
    finally
        try; close(out_io); catch; end
        try; close(err_io); catch; end
        try; rm(out_path; force=true); catch; end
        try; rm(err_path; force=true); catch; end
        try; cd(orig_cwd); catch; end
        for (k, v) in orig_env
            if v === nothing
                delete!(ENV, k)
            else
                ENV[k] = v
            end
        end
        _daemon_reset_state!()
    end
end

# ── Resident worker server loop ─────────────────────────────────────────

function run_daemon_server(endpoint::String;
                           ttl::Int=_daemon_ttl_sec(),
                           max_rss_mb::Int=_daemon_max_rss_mb())::Cint
    if !Sys.iswindows()
        mkpath(dirname(endpoint))
        try; chmod(dirname(endpoint), 0o700); catch; end
        if ispath(endpoint)
            # Refuse to clobber a live healthy daemon on the same endpoint
            if _daemon_ping(endpoint) !== nothing
                return Cint(0)
            end
            try; rm(endpoint; force=true); catch; end
        end
    end

    server = try
        Sockets.listen(endpoint)
    catch
        # Lost a race to another worker — exit cleanly
        return Cint(0)
    end
    if !Sys.iswindows()
        try; chmod(endpoint, 0o600); catch; end
    end

    running = Ref(true)
    active_reqs = Ref(0)
    total_reqs = Ref(0)
    started_at = time()
    last_active = Ref(started_at)
    stamp = _daemon_build_stamp()

    # Idle TTL watchdog
    @async begin
        while running[]
            sleep(1.0)
            if running[] && active_reqs[] == 0 && (time() - last_active[]) >= ttl
                running[] = false
                try; close(server); catch; end
                break
            end
        end
    end

    try
        while running[]
            conn = try
                Sockets.accept(server)
            catch
                break
            end
            @async begin
                try
                    if !_daemon_verify_peer(conn)
                        close(conn)
                        return
                    end
                    req = _daemon_read_frame(conn)
                    req === nothing && return
                    op = string(get(req, :op, ""))
                    if op == "ping"
                        _daemon_write_frame(conn, Dict{String,Any}(
                            "ok" => true,
                            "pid" => Int(getpid()),
                            "stamp" => stamp,
                            "threads" => Threads.nthreads(),
                            "rss_mb" => round(_daemon_rss_mb(); digits=2),
                            "max_rss_mb" => max_rss_mb,
                            "requests" => total_reqs[],
                            "uptime_s" => round(time() - started_at; digits=2),
                            "endpoint" => endpoint,
                        ))
                    elseif op == "stop"
                        running[] = false
                        _daemon_write_frame(conn, Dict{String,Any}(
                            "ok" => true,
                            "pid" => Int(getpid()),
                            "stopping" => true,
                        ))
                        try; close(server); catch; end
                    elseif op == "exec"
                        acq_ms = Int(get(req, :acquire_ms, _daemon_acquire_ms()))
                        deadline = time() + max(10, acq_ms) / 1000.0
                        acquired = false
                        while true
                            if trylock(_DAEMON_EXEC_LOCK)
                                acquired = true
                                break
                            end
                            if time() >= deadline || !running[]
                                break
                            end
                            sleep(0.005)
                        end
                        if !acquired
                            _daemon_write_frame(conn, Dict{String,Any}("busy" => true))
                            return
                        end
                        should_recycle = false
                        try
                            active_reqs[] += 1
                            last_active[] = time()
                            # Phase-1 ACK: tell client we own execution (no more acquire timeout)
                            _daemon_write_frame(conn, Dict{String,Any}("ack" => true))

                            raw_argv = get(req, :argv, Any[])
                            argv = String[string(a) for a in raw_argv]
                            req_cwd = string(get(req, :cwd, ""))
                            raw_env = get(req, :env, Dict{String,Any}())
                            req_env = Dict{String,String}()
                            if raw_env isa AbstractDict
                                for (k, v) in raw_env
                                    req_env[string(k)] = string(v)
                                end
                            end

                            res = _daemon_exec_isolated(argv, req_cwd, req_env)
                            _daemon_write_frame(conn, Dict{String,Any}(
                                "done" => true,
                                "exit_code" => res.exit_code,
                                "stdout" => res.stdout,
                                "stderr" => res.stderr,
                            ))
                            total_reqs[] += 1
                            last_active[] = time()
                            if _daemon_rss_mb() > max_rss_mb
                                should_recycle = true
                            end
                        finally
                            active_reqs[] -= 1
                            unlock(_DAEMON_EXEC_LOCK)
                        end
                        if should_recycle
                            running[] = false
                            try; close(server); catch; end
                        end
                    end
                catch
                finally
                    try; close(conn); catch; end
                end
            end
        end
    finally
        running[] = false
        try; close(server); catch; end
        if !Sys.iswindows()
            try; rm(endpoint; force=true); catch; end
        end
    end
    return Cint(0)
end

# ── Julia control client (used by `frdc daemon start|stop|status`) ──────

function _daemon_ping(endpoint::String)
    (!Sys.iswindows() && !ispath(endpoint)) && return nothing
    return try
        conn = Sockets.connect(endpoint)
        try
            _daemon_write_frame(conn, Dict{String,Any}("op" => "ping"))
            resp = _daemon_read_frame(conn)
            (resp !== nothing && get(resp, :ok, false) === true) ? resp : nothing
        finally
            try; close(conn); catch; end
        end
    catch
        nothing
    end
end

function _daemon_stop_endpoint(endpoint::String)
    (!Sys.iswindows() && !ispath(endpoint)) && return nothing
    resp = try
        conn = Sockets.connect(endpoint)
        try
            _daemon_write_frame(conn, Dict{String,Any}("op" => "stop"))
            _daemon_read_frame(conn)
        finally
            try; close(conn); catch; end
        end
    catch
        nothing
    end
    # Wait briefly for clean socket teardown
    for _ in 1:40
        _daemon_ping(endpoint) === nothing && break
        sleep(0.05)
    end
    return resp
end

function _daemon_spawn_cmd(endpoint::String; ttl::Int, max_rss_mb::Int)
    # Prefer sibling frdc-core in standalone bundles; fall back to current julia + bin/frdc in dev.
    exe = Base.julia_cmd().exec[1]
    cand_core = joinpath(dirname(exe), Sys.iswindows() ? "frdc-core.exe" : "frdc-core")
    args = String["--daemon-serve", endpoint, "--ttl", string(ttl), "--max-rss-mb", string(max_rss_mb)]
    if isfile(cand_core)
        return Cmd(vcat([cand_core], args))
    end
    pkg_root = dirname(@__DIR__)
    script = joinpath(pkg_root, "bin", "frdc")
    jcmd = Base.julia_cmd().exec
    return Cmd(vcat(jcmd, ["--project=$pkg_root", "--", script], args))
end

function _daemon_start_detached(endpoint::String; ttl::Int=_daemon_ttl_sec(),
                                max_rss_mb::Int=_daemon_max_rss_mb(),
                                wait_sec::Float64=_daemon_parse_pos_int_env("FRDC_DAEMON_BOOT_MS", 30000; max_val=120000) / 1000.0)
    existing = _daemon_ping(endpoint)
    existing !== nothing && return (started=false, info=existing)

    cmd = _daemon_spawn_cmd(endpoint; ttl=ttl, max_rss_mb=max_rss_mb)
    run(pipeline(detach(cmd); stdin=devnull, stdout=devnull, stderr=devnull); wait=false)

    deadline = time() + wait_sec
    while time() < deadline
        info = _daemon_ping(endpoint)
        info !== nothing && return (started=true, info=info)
        sleep(0.05)
    end
    throw(CliError("env/daemon-start-timeout",
        "daemon worker did not become ready within $(round(Int, wait_sec))s at $endpoint";
        hint="check FRDC_DAEMON_DIR permissions or run without FRDC_DAEMON=1"))
end

"""Handle internal hidden `--daemon-serve <endpoint> [--ttl N] [--max-rss-mb N]` mode."""
function _run_daemon_serve_cli(args::Vector{String})::Cint
    length(args) >= 2 || return Cint(2)
    endpoint = args[2]
    ttl = _daemon_ttl_sec()
    max_rss_mb = _daemon_max_rss_mb()
    i = 3
    while i <= length(args)
        if args[i] == "--ttl" && i + 1 <= length(args)
            v = tryparse(Int, args[i + 1])
            (v !== nothing && v > 0) && (ttl = v)
            i += 2
        elseif args[i] == "--max-rss-mb" && i + 1 <= length(args)
            v = tryparse(Int, args[i + 1])
            (v !== nothing && v > 0) && (max_rss_mb = v)
            i += 2
        else
            i += 1
        end
    end
    return run_daemon_server(endpoint; ttl=ttl, max_rss_mb=max_rss_mb)
end
