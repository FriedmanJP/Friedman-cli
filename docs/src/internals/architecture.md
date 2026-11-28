# [Architecture](@id int-architecture)

Friedman-cli is a Julia CLI application built around a custom declarative command engine adapted from Comonicon.jl, a typed-handle persistence layer over `MacroEconometricModels.jl`, and a versioned JSON/table/CSV output pipeline.

---

## Execution Flow

Standalone release builds ship a **two-binary Pure C99 thin front-end** (`bin/frdc` → `bin/frdc-core` + `share/frdc/cli_cache.bin`) so static metadata invocations avoid booting `libjulia` and decompressing the PackageCompiler sysimage:

```text
bin/frdc ARGS  (Pure C99 thin wrapper; ~55 KiB; bypassed if FRDC_NO_FASTPATH=1 or --julia-args)
  ├─ Tier 1–4 fast paths (<10 ms) from single-source FRDCACHE v2 pack (share/frdc/cli_cache.bin):
  │    --version/-V, --warranty, --conditions, root/node/leaf/repl --help (with full alias resolution),
  │    schema [path...] [--docs], completions bash|zsh|fish,
  │    data list, io sources (table|csv|json envelope), unknown-command fast-fail (exit 2),
  │    serve --mcp State 0 lazy JSON-RPC proxy (initialize with instructions, ping, scoped tools/list,
  │    unknown-tool -32602; lazily spawns frdc-core on first valid tools/call with half-duplex stdin pump)
  └─ Fail-open execv / CreateProcessW → bin/frdc-core ARGS  (or julia --project bin/frdc in source dev)
       → Friedman.main(ARGS) → run_cli(ARGS)
         → Friedman.APP                         # Entry built once (const APP = build_app())
           # build_app() registers every top-level command group + coexisting alias tables once
         → dispatch(APP, args)
           → dispatch_node()                    # walks NodeCommand tree resolving canonical names & aliases
           → dispatch_leaf()                    # tokenize → bind_args → leaf.handler(; bound...)
```

`cli_cache.bin` uses the deterministic little-endian **`FRDCACHE` v2** format generated directly from `Friedman.APP` and `Friedman.REGISTRY` by `tools/gen_fastpath_pack.jl` with a sorted binary-search `alias_tbl` (command, family, and long-leaf abbreviations), per-block zlib compression, and IEEE CRC32 verification; any missing, version-mismatched, or corrupt pack fails open directly to `frdc-core`. Set `FRDC_NO_FASTPATH=1` (legacy fallback `FRIEDMAN_NO_FASTPATH=1`) to force every invocation through `frdc-core`.

See [Automated Pipelines & JSON Envelopes](@ref gs-pipelines) for exit codes and envelope schemas.

---

## Data Flow & Handle Resolution

CSV is the **import** format, not the working format. Commands accept a **stem**: `.jld2` stores native typed models and datasets (`MacroEconometricModels.save_model` / `load_model` plus plain `.jld2` tabular payloads), `.jls` supports Julia `Serialization` handles, `.fmod` serves compiled closure-bearing DSGE/HA solution objects excluded from native serialization, and `model://name` targets the in-memory session store under [`frdc serve`](@ref ref-serve). Result handles (`--result` / `--save-result`) and [`frdc show`](@ref ref-show) follow the same stem rules.

```text
CSV | :example | data simulate --save-data STEM
        │
        ▼
data import --kind timeseries|panel|cross-section [-o STEM]
        │
        ▼
STEM.jld2 | STEM.jls     TimeSeriesData | PanelData | CrossSectionData | DataFrame
        │
        ├─ data describe|diagnose|validate     (read, real type)
        ├─ data fix|transform|dropna|keeprows|balance
        │       -o STEM'     →  same type, STEM'.jld2 | STEM'.jls
        │       -o file.csv  →  CSV export; stderr: metadata dropped
        ├─ data export STEM  →  CSV (inverse of import)
        │
        ▼
estimate multivariate var STEM --save-model var         # stem → var.jld2
        │
        ▼
irf var --model var --save-result irf      # or positional: irf var var.jld2
frdc show irf                          # stem → irf.jld2 (no CSV fallback)
frdc show var                          # fitted model table / fields
forecast evaluate metrics STEM --actual gdp --result fcst_var,fcst_bvar
# evaluate --result is a comma-separated string (not RESULT_OPTION)
```

### Stem Resolution Rules

**Save paths** (`data import -o`, data-edit `-o`, `data simulate --save-data`, and a present `--save-model`):

- **Data-edit `-o` only:** empty or omitted falls back to a leaf-specific default stem; omitted `--save-model` never writes a handle.
- No suffix appends `.jld2` and writes native storage.
- `.jld2` invokes native `save_model` (or plain JLD2 tabular write during `data import ... -o out.jld2`).
- `.jls` invokes Julia `Serialization` (datasets, models, results).
- `.fmod` writes an interim Serialization handle (reserved for unregistered types such as compiled DSGE/HA solutions).
- `.csv` on a **data-edit** output exports flat CSV (dropping frequency, tcodes, and date metadata).
- **Data-edit** on a raw CSV with `-o out.jld2` raises `usage/invalid` (run `data import` first).

**Load paths** (data slot, `--model`, `--result`, `show`):

1. **Data slots:** resolve `path.jld2` if present (preferred), else `path.csv`, else `path.jls` / exact `path` (`.fmod`, `.toml`, extensionless paths). Missing files raise `data/file-not-found` (exit `3`).
2. **`--model` and positional model auto-routing:** when the leaf declares non-empty `model_types`, `resolve_stem(; slot=:result)` prefers `STEM.jld2` without CSV fallback and validates the decoded type before dispatch (`model/wrong-kind`, exit `5`). Passing a model/solution handle positionally on such leaves auto-routes it into `--model`, while explicit `<data>` plus domain `--model var|vecm` flags (such as `test multivariate granger`) remain untouched. Leaves with empty `model_types` require explicit extensions or `model://`.
3. **`--result` and `frdc show STEM`:** `resolve_stem(; slot=:result)` checks `STEM.jld2` then the exact path (no CSV fallback). Bundles emit a key summary (`show_payload`); typed `:timeseries` / `:panel` / `:cross_section` datasets emit descriptive stats; `:io` and arbitrary result structs render via `long_table`, `DataFrame`, or field summaries. Passing `--plot` / `--plot-save` routes through `_maybe_plot`, raising `model/unsupported` (exit `5`) if the result type lacks a plotting recipe.

If both `macro.jld2` and `macro.csv` exist, the typed handle wins on data slots. Explicit suffixes bypass stem search, while `:example` datasets (such as `:denmark` and `:fred_md`) resolve directly. Central resolution and validation live in `src/handles.jl` and `src/model_handle.jl`.

### Result Rendering & Presentation-Only Display Rounding

Every handler emits unrounded IEEE-754 `Float64` `DataFrame`s through `output_result` (`:table` via PrettyTables, `:csv` via CSV.jl, `:json` via the frozen v1 envelope) after converting structs in `_emit_result` (`src/commands/shared.jl`) using explicit type unions matching `MacroEconometricModels.jl` 1:1:

1. **`long_table(result)`:** Tidy long-format converter for array-valued outputs (`irf`, `fevd`, `forecast` across VAR/BVAR/VECM/LP/TVPVAR/FAVAR/SDFM, univariate ARIMA/SARIMA/ARFIMA/MIDAS, factor models, and nonlinear forecasting).
2. **`DataFrame(model)`:** Upstream coefficient-table converter for regression, VAR, choice, panel, and event-study estimators yielding uniform `term|estimate|std_error|stat|p_value|ci_lower|ci_upper` schemas.
3. **Hand-built `DataFrame(...)`:** Used only where upstream omits a `Tables.jl` registration (for example `pvar` dynamics, `hd`, `predict`/`residuals`, Arias/Uhlig/sign set-identified IRFs, the entire `io` family, `mgarch` conditional correlations, penalized/tobit/heckman/quantile/GMM/SMM regressions, state-space/TVP, nonparametric smoothers, cointegrating/ARDL/NARDL/PMG models, nonlinear regime summaries, and `volatility` forecast variance/volatility tables).

**Presentation-only rounding boundary:** All table display formatting lives exclusively inside `_render_table` / `_format_display_float` (`src/output/render.jl`), using a non-mutating PrettyTables formatter dispatched strictly on `AbstractFloat` (default 3 decimal places, `-0.000 → 0.000`, scientific `%.3e` at `>= 1e9`, configurable via global `--digits <0..16|full>` and `FRDC_DIGITS`). `--compact` adjusts TTY table width only and never mutates cell values. Handlers must never pre-round data columns; this invariant is enforced permanently in CI by `test/tools/check_lossless_handlers.jl`.

### Coexisting Abbreviations & Uniform Short Flags

Command, family, and long-leaf aliases live in single-source tables (`_TOP_ALIASES`, `_FAMILY_ALIASES`, `_LEAF_ALIASES` in `src/registry/families.jl`) mounted onto `NodeCommand.aliases` through the hard build-time collision guard `_register_node_alias!` (rejecting overlaps with sibling primaries, sibling aliases, REPL built-ins, and `_PATH_REPLACEMENTS` migration hints). Canonical option and flag short flags (`_CANONICAL_SHORTS`, `_CANONICAL_FLAG_SHORTS`) and long aliases (`_CANONICAL_OPTION_ALIASES`, `_CANONICAL_FLAG_ALIASES` in `src/registry/adapter.jl`) are injected uniformly across all leaves at registration without shadowing single-letter long options (`--P`, `--Q`, `--z`) or reserved globals (`-h`, `-V`, `-J`), and enforced in CI by `test/tools/check_abbreviations.jl`. Both `dispatch_node` and `FRDCACHE` v2 resolve aliases to canonical names before executing or reporting `command` in envelopes.

---

## CLI Framework

The command engine under `src/cli/` is self-contained:

### Type Hierarchy

- **`Entry`** — Root container holding program name, root `NodeCommand`, and package version (`Project.toml`).
- **`NodeCommand`** — Interior command group holding `Dict{String, Union{NodeCommand, LeafCommand}}`.
- **`LeafCommand`** — Executable leaf binding handler function, `Argument` vector, `Option` vector, and `Flag` vector.
- **`Argument`** — Positional argument specification (name, type, required, default).
- **`Option`** — Named `--opt=val` / `-o val` parameter (name, short flag, type, default).
- **`Flag`** — Boolean `--flag` / `-f` switch.

### Parser & Dispatch

`tokenize()` transforms raw CLI tokens into `ParsedArgs`:

```text
--opt=val     → options["opt"] = "val"
--opt val     → options["opt"] = "val"
-o val        → options["o"] = "val"
--flag        → flags = Set(["flag"])
-abc          → flags = Set(["a", "b", "c"])
--            → stops option parsing
other         → positional arguments
```

`bind_args()` maps tokens to declared leaf parameters via `convert_value()`. `dispatch()` resolves three tiers:

1. **Entry-level:** `--version` / `-V`, `--warranty`, and `--conditions` trigger only as the leading token; empty argv or leading `-h` / `--help` prints top-level help.
2. **Node-level:** Consumes matching group tokens recursively; empty remaining tokens print node help.
3. **Leaf-level:** `-h` / `--help` anywhere prints leaf help; empty required positionals print leaf help rather than erroring; otherwise binds and calls `leaf.handler(; bound...)`.

Unknown subcommands emit `DispatchError` (exit `2`), and unknown flags/options or invalid choices raise `ParseError` (exit `2`) with nearest-match suggestions. Stdout carries data only (one table, CSV, or JSON envelope), while status logs route strictly to stderr. JSON errors emit a valid error envelope on stdout alongside non-zero exit codes.

---

## Module Layout

```text
src/
  Friedman.jl             # Main module: imports, includes, build_app(), const APP, run_cli, main()
  cli/
    types.jl              # Entry, NodeCommand, LeafCommand, Argument, Option, Flag
    parser.jl             # tokenize(), bind_args(), convert_value()
    dispatch.jl           # dispatch() → dispatch_node() → dispatch_leaf()
    help.jl               # Colored column-aligned terminal help printer
  io.jl                   # Data loaders, EXAMPLE_DATASETS registry, output_result / output_kv
  output/
    errors.jl             # CliError taxonomy + exit-code map
    envelope.jl           # Frozen v1 JSON envelope builder
    render.jl             # Table / CSV / JSON stdout renderers
  config.jl               # TOML loaders (priors, identification, GMM/SMM, DSGE, systems)
  model_card.jl           # Model Card Markdown/TOML card reader
  model_handle.jl         # save_model_dispatch / load_model_dispatch (.jld2 | .jls | .fmod | model://)
  handles.jl              # Stem resolver, data_kinds check, typed handle persistence
  registry/
    spec.jl               # CommandSpec (data_kinds / model_types / result_types / tables)
    adapter.jl            # wrap_legacy: stem resolution, positional model routing, type checks
    families.jl           # Shared family option sets, _NODE_DESCRIPTIONS, _PATH_REPLACEMENTS
  commands/
    shared.jl             # Shared estimation loaders, _emit_result, plotting helpers
    <action>.jl           # Action-first handlers & register_<action>_commands!() builders
    multipliers.jl        # Shared NARDL cumulative-multiplier table emitters
    agent_guide.md        # Single-source agent contract embedded at precompile time
  repl.jl                 # Interactive REPL session mode
```

Include order in `src/Friedman.jl` is load-bearing: `output/errors.jl`, `io.jl`, `commands/shared.jl`, and `registry/*` precede every command module. Command totals and inventory live strictly in [CLI Reference Overview](@ref cli-overview) and generated files.

---

## Handler Conventions & Dependencies

- **Handler naming:** `_action_model(; kwargs...)` (for instance `_estimate_var`, `_irf_bvar`, `_forecast_sarima`, `_nowcast_dfm`), with keyword argument names mirroring kebab-to-snake declared options.
- **Registration:** Each action file exports `register_<action>_commands!()` returning a `NodeCommand` (except singleton leaves such as [`show`](@ref ref-show), [`serve`](@ref ref-serve), and registry-hidden `schema`).
- **Core dependencies:** `MacroEconometricModels` (exact pin in `Project.toml`), `CSV`, `DataFrames`, `PrettyTables`, `JSON3`, `TOML`, `JLD2` (explicitly imported to trigger native `.jld2` save/load extensions), `LinearAlgebra`, `Statistics`, `SparseArrays`, `Random`, `Serialization`, `Sockets`, and `Logging` (`LocalPreferences.toml` pins `LinearSolve.LoadMKL_JLL = false` and `FFTW.provider = "fftw"` for GPL-3.0 compliance).
- **Concurrency & caching layer:** Pre-`jl_init()` `--threads` / `FRDC_THREADS` coordination (in `frdc_thin.c` and `frdc_driver.c`), per-leaf declarative `CommandSpec.thread_mode` (`:julia_threads`, `:blas_threads`, `:serial_safe`) enforced by `with_thread_budget()`, `_LOG_LOCK`-guarded `_MemsCliLogger` / warning emission, fail-open per-user local `JULIA_OBJCACHE=1` setup (`frdc_driver.c` + [`cache`](@ref ref-cache)), and the opt-in resident worker daemon (`src/daemon.jl` + `daemon_client.c`, documented in [Resident Worker Daemon Architecture](@ref int-daemon-adr)).
- **Stability policy:** The machine surface — command tree, options/flags, `schema/envelope-v1.json`, `data` table keys, error taxonomy, and exit codes — follows strict semver. Envelope v1 is frozen; minor releases are additive-only.

---

## References

- [Storage & Handle Architecture](@ref int-storage) — canonical `.jld2`/`.jls`/`.fmod` formats, URI grammar, atomic writes, and provenance
- [Resident Worker Daemon Architecture](@ref int-daemon-adr) — multi-agent-safe opt-in daemon ADR, IPC framing, and chaos gates
- [CLI Reference Overview](@ref cli-overview) — generated command inventory and option schemas
- [Automated Pipelines & JSON Envelopes](@ref gs-pipelines) — envelope structure and handle workflows
- [API Reference](@ref int-api) — Julia entry points for embedding
- [Unwrapped Upstream Surface](@ref int-not-wrapped) — intentional boundaries vs `MacroEconometricModels.jl`
- [Agent Guide](../agent-guide.md) — machine-actionable execution contract
