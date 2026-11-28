# [Resident Worker Daemon Architecture](@id int-daemon-adr)

This Architecture Decision Record (ADR) documents the design, multi-agent safety invariants, cross-platform IPC protocol, and chaos-testing gates for `frdc`'s strictly **opt-in** resident worker daemon (`FRDC_DAEMON=1`), managed via `frdc daemon start|stop|status` and routed transparently through the C99 thin wrapper (`packaging/thin_wrapper/frdc_thin.c`).

---

## Context & Latency Motivation

Even after expanding `build_release.jl`'s multivariate precompile workload and enabling the per-user writable `JULIA_OBJCACHE=1` LMDB object cache, every cold invocation of `frdc-core` must initialize `libjulia` and map the compiled PackageCompiler sysimage (`~750–840 ms` on Apple Silicon macOS and `~900–1,400 ms` on Linux/Windows). For interactive shells and multi-step LLM agent tool loops calling `data describe`, `show`, `model info`, `estimate multivariate var`, `filter`, or `test` in rapid succession, eliminating repeated `libjulia` boot overhead reduces wall-clock latency to `~15–30 ms` (a `25–50×` speedup).

At the same time, naive resident CLI daemons fail catastrophically when multiple LLM agents or shell pipelines invoke `frdc` concurrently. This ADR specifies the hard architectural guardrails required so that opting into `FRDC_DAEMON=1` can **never** trigger daemon-spawn storms, OOM crashes, head-of-line hangs, or cross-request state leaks.

---

## Multi-Agent Failure Modes

Four concrete concurrency hazards constrain any resident Julia worker design:

1. **Daemon-spawn storms (thundering herd):** When `N` agents invoke `frdc` simultaneously on a cold host, a naive `connect() failed → spawn daemon` sequence spawns `N` independent `~350–450 MiB` Julia workers concurrently (`10–30 × 400 MiB = 4–12 GiB`), exhausting RAM and triggering OS OOM killers or swap thrashing.
2. **Process-global mutable state races:** `Friedman-cli` maintains **23 invocation-scoped module-level `Ref`s** (envelope accumulator, emission latch, quiet/color/compact/JSON/digits/threads/seed/config-strict flags, invocation handle cache, next-save metadata, and session-store refs) alongside process-global `Base.cd`, default `Random` RNG state, and `redirect_stdout`/`redirect_stderr` streams. Two commands **cannot** execute concurrently inside the same Julia worker without corrupting envelopes, seeds, working directories, or output streams.
3. **Head-of-line starvation:** If Agent A submits a multi-second estimation (such as a large Bayesian DSGE SMC run or high-draw BVAR) to a single serial daemon, Agent B executing a `10 ms` `data describe` or `model info` must neither block for 20 seconds nor trigger unbounded spawning of new resident workers.
4. **Long-lived RSS creep:** Repeated `@dsge` sandboxed module evaluations, large posterior arrays, and fragmented heap pages can cause resident RSS to drift upward over hours of continuous agent operation.

---

## Architectural Option Analysis

Three candidate concurrency architectures were evaluated against the four failure modes:

| Dimension | Option A: Single Warm Worker + Fast Fail-Open | Option B: Capped 2-Worker Pool + Fail-Open | Option C: Fast-Lane / Heavy-Command Bypass |
|---|---|---|---|
| **Max resident workers** | Strictly `1` per isolation key | `min(2, physical_cores ÷ 2)` | Pairs with Option A or B |
| **Worst-case resident RAM** | Bounded by `FRDC_DAEMON_MAX_RSS_MB` (`2048 MiB`) | Bounded by `FRDC_DAEMON_TOTAL_RSS_MB` (`4096 MiB`) | Minimizes heap spikes inside warm worker |
| **Head-of-line behavior** | Second caller waits `<= FRDC_DAEMON_ACQUIRE_MS` (`200 ms`), then fails open to one-shot `frdc-core` | Absorbs 2 simultaneous requests; 3rd fails open after `acquire_ms` | Multi-second heavy leaves bypass daemon immediately, keeping the warm worker free for fast loops |
| **Spawn-storm risk** | Eliminated via single OS bootstrap lock + double-checked `connect()` | Eliminated via per-slot bootstrap lock + aggregate RSS pre-check | Same as underlying worker pool |
| **Operational complexity** | Low (single socket/pipe, simple lifecycle) | Medium (slot routing + aggregate RSS accounting) | Low (declarative command-prefix filter in C99 wrapper) |

### Decision

Adopt **Option A combined with Option C heavy-command bypass** as the default opt-in architecture (`FRDC_DAEMON=1`, `FRDC_DAEMON_MAX_WORKERS=1`, `FRDC_DAEMON_BYPASS_HEAVY=1`), while bounding `FRDC_DAEMON_MAX_WORKERS` strictly at `min(2, max(1, physical_cores ÷ 2))` so Option B remains available only within a hard upper ceiling and can never spawn unbounded workers.

The daemon stays **strictly opt-in (`FRDC_DAEMON=1`, OFF by default)** in `v1.2.1`. All `< 10 ms` C99 `FRDCACHE` v2 fast paths (`--version`, `--help`, `schema`, `completions`, `data list`, `io sources`, `serve --mcp` proxy) execute **before** the daemon hook, ensuring default `frdc` latency and zero-daemon safety are completely unaffected.

---

## Concurrency Guardrails & State-Reset Barrier

### Anti-Spawn-Storm Bootstrap Lock (Single Rendezvous)

Clients use a two-step rendezvous before ever spawning `frdc-core --daemon-serve`:

1. **Fast path (`~0.2 ms`):** Attempt a non-blocking `connect()` to the deterministic user-scoped socket/pipe path.
2. **Serialized cold bootstrap:** On `ENOENT` or `ECONNREFUSED`:
   - Acquire an OS-level exclusive bootstrap lock (`flock(LOCK_EX)` on a `0600` lockfile on macOS/Linux; user-scoped `CreateMutexW` on Windows).
   - Perform a **double-checked `connect()`**: if a peer agent finished starting the daemon while we waited for the lock, immediately reuse that daemon without spawning.
   - Verify host memory headroom before spawning; clean any dead stale socket file; spawn **exactly one** detached `frdc-core --daemon-serve <endpoint>` process; poll readiness (`ping` frame) up to the bootstrap deadline; release the lock.

### Bounded Acquire & Two-Phase ACK Fail-Open

To prevent head-of-line blocking even when a single-threaded Julia worker is saturated inside native BLAS/C code and cannot promptly yield to libuv:

1. The client sends the `exec` request frame and waits at most `FRDC_DAEMON_ACQUIRE_MS` (default `200 ms`) via `poll()` / `WaitNamedPipeW` for either `{"ack":true}` or `{"busy":true}`.
2. Inside the daemon, the handler acquires `_DAEMON_EXEC_LOCK` (`ReentrantLock` checked non-blockingly) and **immediately** writes `{"ack":true}` before running `run_cli`.
3. Once `{"ack":true}` is received, the client waits without artificial timeout for the final `{"done":true,"exit_code":...,"stdout":...,"stderr":...}` frame, so legitimate long-running estimations never time out prematurely.
4. If the daemon responds `{"busy":true}` or the `acquire_ms` deadline expires before `{"ack":true}`, the client closes the socket immediately and **fails open** directly to one-shot `frdc-core`, guaranteeing zero hangs and zero additional persistent daemons.

### Exhaustive 23-Ref State-Reset Barrier

Every request runs serially inside `_DAEMON_EXEC_LOCK` wrapped in a `try ... finally` barrier that saves and restores:

- **Working directory & environment:** `pwd()` restored via `cd(orig_cwd)`; whitelisted environment variables (`FRDC_*`, `FRIEDMAN_*`, `NO_COLOR`, `COLUMNS`, `LINES`, `TZ`) snapshotted, applied from the client frame, and restored verbatim.
- **Module-level mutable `Ref`s (all 23 invocation-scoped refs):** `_ENVELOPE`, `_ENVELOPE_EMITTED`, `_QUIET`, `_COLOR`, `_SEED`, `_LAST_ARGV`, `_COMPACT`, `_FORCE_JSON`, `_ENVELOPE_JSON_TO_FILE`, `_DISPLAY_DIGITS`, `_REQUESTED_THREADS`, `_CURRENT_EXPLICIT_OPTS`, `_IN_DISPATCH`, `_THREAD_MODE`, `_CONFIG_STRICT`, `_SESSION_STORE`, `_INVOCATION_HANDLE_CACHE`, `_INVOCATION_HANDLE_META`, `_NEXT_SAVE_VARNAMES`, `_NEXT_SAVE_KIND`, `_HANDLE_LOAD_COUNTER`, `_SERVE_MODEL_STORE`, and `_SERVE_SOURCE_MODELS`.
- **RNG & I/O isolation:** `Random.seed!()` re-randomizes the default RNG after every request so a previous caller's `--seed` cannot leak into a subsequent unseeded call; `stdout` and `stderr` are redirected to isolated request-scoped temp files cleaned up unconditionally in `finally`.

### RSS Ceilings, Idle TTL & Bypass Rules

- **Per-worker RSS ceiling (`FRDC_DAEMON_MAX_RSS_MB=2048`):** After completing and replying to a request, the worker inspects its own resident set size (`mach_task_basic_info` on macOS, `/proc/self/statm` on Linux, `GetProcessMemoryInfo` on Windows). If RSS exceeds the ceiling, it closes its listener, removes its socket, and exits `0` cleanly so the next request spawns a fresh worker without dropping any in-flight work.
- **Aggregate RSS ceiling (`FRDC_DAEMON_TOTAL_RSS_MB=4096`) & idle TTL (`FRDC_DAEMON_TTL=600` s):** Idle workers self-terminate cleanly after `ttl` seconds of inactivity.
- **Automatic bypasses:** `repl`, `serve` (`--mcp`), `daemon *`, `--julia-args`, `FRDC_NO_DAEMON=1`, `FRDC_NO_FASTPATH=1`, and (when `FRDC_DAEMON_BYPASS_HEAVY=1`) heavy long-running subcommands (`dsge bayes`, `hadsge solve`, `hadsge transition`) always bypass the daemon directly to `frdc-core`.

---

## Cross-Platform IPC Framing & Security

### Endpoint Isolation Key

Endpoints live inside a strictly user-private runtime directory (`$XDG_RUNTIME_DIR/frdc/` or `$TMPDIR/frdc-<uid>/` created with mode `0700` on POSIX; Windows Named Pipe `\\.\pipe\frdc-<user>-<key>` with owner-only security descriptor). The endpoint name is keyed by the tuple:

```text
(uid/user, build_stamp, effective_threads, hash(FRDC_DATA_ROOT))
```

Keying by `build_stamp` (derived from `cli_cache.bin` CRC32 and sysimage size, or source-tree version in dev) ensures binary upgrades automatically route to a new worker without mixing incompatible sysimages. Keying by `effective_threads` ensures `--threads=4` requests never collide with 1-thread workers, and keying by `FRDC_DATA_ROOT` preserves sandbox confinement.

### Peer Identity Verification

- **Linux:** `SO_PEERCRED` (`getsockopt` on `SOL_SOCKET`) verifies `cred.uid == geteuid()` before accepting any request frame.
- **macOS:** `getpeereid(fd, &euid, &egid)` verifies `euid == geteuid()` in addition to `0700` parent directory and `0600` socket permissions.
- **Windows:** Named Pipe server uses a user-scoped DACL granting access exclusively to the current user SID.

### Wire Framing Protocol

Each message consists of a 4-byte unsigned little-endian length prefix `L` (`1 <= L <= 64 MiB`) followed by `L` UTF-8 JSON bytes:

- **Control requests:** `{"op":"ping"}` and `{"op":"stop"}`.
- **Execution request:** `{"op":"exec","argv":[...],"cwd":"...","env":{...},"is_tty":false,"acquire_ms":200}`.
- **Execution responses:** Phase-1 `{"ack":true}` (or immediate `{"busy":true}`), followed on completion by `{"done":true,"exit_code":0,"stdout":"...","stderr":"..."}`.

Future iterations may adopt Unix `SCM_RIGHTS` file-descriptor passing for zero-copy streaming of large stdout payloads and real `Base.TTY` width detection; length-prefixed framing is selected first because it is uniform across macOS, Linux, and Windows Named Pipes with zero platform divergence.

---

## Chaos & Soak Verification Gate

Before any future change promotes `FRDC_DAEMON` beyond opt-in, the following multi-agent chaos suite (`test/test_daemon_chaos.jl`) must pass cleanly across macOS, Linux, and Windows:

1. **30-way cold thundering herd:** Launch 30 simultaneous cold `frdc` invocations against an empty runtime directory and assert `<= FRDC_DAEMON_MAX_WORKERS` resident daemon PIDs ever spawn, all 30/30 exit `0`, and every JSON envelope validates cleanly.
2. **Mixed slow + fast concurrency & state isolation:** Run a slow estimation concurrently with 10 parallel fast queries carrying distinct `--seed`, `--digits`, `cwd`, and `FRDC_DIGITS` values; assert zero hangs (bounded fail-open), zero cross-request leakage of seeds/digits/env/cwd/stdout, and 100% schema-valid envelopes.
3. **Mid-request `SIGKILL` recovery:** Terminate the resident worker with `SIGKILL` mid-flight and assert the in-flight caller exits cleanly (no hang) while the next invocation cleans the stale socket via bootstrap lock and spawns a healthy replacement worker.
4. **RSS ceiling recycle:** Run repeated estimations under a lowered `FRDC_DAEMON_MAX_RSS_MB` ceiling and assert the worker completes every active request with `exit 0` and cleanly recycles to a new PID without dropping requests.
