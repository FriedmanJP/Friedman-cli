# Architecture

Friedman-cli is a Julia CLI application with a custom command-line framework adapted from Comonicon.jl.

---

## Execution Flow

```
bin/friedman ARGS
  → Pkg.activate(project_dir) (+ instantiate when the Manifest is absent)
  → Friedman.main(ARGS) → run_cli(ARGS)
    → Friedman.APP                         # Entry built once (const APP = build_app())
      # build_app() registers every top-level command group once
    → dispatch(APP, args)
      → dispatch_node()                    # walks the NodeCommand tree by matching tokens
      → dispatch_leaf()                    # tokenize → bind_args → leaf.handler(; bound...)
```

---

## Data Flow

CSV is the **import** format, not the working format. Commands take a **stem**;
`.jld2` is native storage (MEMs `save_model` / `load_model`), not part of the
argv contract. **Result** handles (`--result` / `--save-result`) and
`friedman show STEM` (render any loadable handle) work the same stem way.

```
CSV | :example
        │
        ▼
data import --kind timeseries|panel|cross-section [-o STEM]
        │
        ▼
STEM.jld2     TimeSeriesData | PanelData | CrossSectionData
        │
        ├─ data describe|diagnose|validate     (read, real type)
        ├─ data fix|transform|dropna|keeprows|balance
        │       -o STEM'     →  same type, STEM'.jld2
        │       -o file.csv  →  CSV export; stderr: metadata dropped
        ├─ data export STEM  →  CSV (inverse of import)
        │
        ▼
estimate multivariate var STEM --save-model var         # stem → var.jld2
        │
        ▼
irf var --model var --save-result irf      # --model stem → var.jld2
friedman show irf                          # stem → irf.jld2 (no CSV fallback)
friedman show var                          # fitted model table / fields
forecast evaluate metrics STEM --actual gdp --result fcst_var,fcst_bvar
# evaluate --result is a comma-separated string (not RESULT_OPTION)

CSV shortcut (a CSV path works wherever a data stem does on leaves that list `:csv` (all estimator leaves do; handle-only leaves such as `data export` do not)):
estimate multivariate var macro.csv --lags 2
```

### Stem resolution

**Save** (`data import -o`, data-edit `-o`, and a *present* `--save-model`):

- **Data-edit `-o` only:** empty / omitted → leaf-specific default stem, then
  the rule below. (`--save-model` omitted means do not save — it is not a
  default stem.)
- No suffix → append `.jld2` and use native `save_model`.
- `.jld2` → native `save_model` (including `data import … -o out.jld2`, the
  intended CSV→typed conversion).
- `.fmod` → interim Serialization handle (unregistered types).
- `.csv` on a **data-edit** output → CSV export (frequency/tcode/dates dropped).
- **Data-edit** of a CSV with `-o out.jld2` → `usage/invalid` (run
  `data import` first). This edit refusal does **not** apply to `data import`
  itself.

**Load** (data positional / `data export`; `--model` / `--result` / `show`):

1. **Data slots:** resolve stem — `path.jld2` if that file exists (preferred),
   else `path.csv`, else exact `path` (`.fmod`, `.toml` DSGE specs,
   extensionless files). Else `data/file-not-found` (exit 3).
2. **`--model`:** when the leaf's `model_types` is nonempty,
   `resolve_stem(; slot=:result)` — `STEM.jld2` if that file exists (no CSV
   fallback), then type-check. Empty `model_types` (DSGE builtins,
   `data validate --model`) still requires an explicit suffix / URI.
   `model info` still wants `.jld2` / `.fmod` / `model://`.
3. **`--result` / `friedman show STEM`:** `resolve_stem(; slot=:result)` —
   `STEM.jld2` if that file exists, else the exact path. No CSV fallback
   (show is for loadable handles, not import). Bundles emit a keys-only
   table (`show_payload`); `:timeseries`/`:panel`/`:cross_section` emit
   descriptive stats; `:io` and other kinds fall through to `long_table` /
   `DataFrame` / field dump (never `to_matrix` an IOData). `--plot` /
   `--plot-save` call `_maybe_plot` on every path; missing recipe →
   `model/unsupported` (exit 5).

If both `macro.jld2` and `macro.csv` exist, the handle wins on data slots.
Explicit suffixes skip the search (`macro.csv` is CSV, `var.jld2` is a
handle). `model://name` is the serve-session URI and is not stem-expanded.
`:fred_md` example names are unchanged.

`wrap_legacy` type-checks a loaded data handle against the leaf's
registry-declared `data_kinds` **before** the handler runs. A mismatch is
`data/wrong-kind` (exit 3) — e.g. a `PanelData` handle on `estimate multivariate var`. CSV
remains legal on every leaf that lists `:csv`. On leaves declaring `result_types`, `--result` of a type not in
`result_types` is `data/wrong-result` (exit 3); `--model` of a type not in
`model_types` is `model/wrong-kind` (exit 5). `--result` cannot be combined
with `--model` or a data path (`usage/invalid`) — except `forecast evaluate`'s `--result`, which is a comma-separated string (not a result handle).

Central resolver: `src/handles.jl`. Native persist: `src/model_handle.jl`.

### Rendering

After the library call, results still go through `output_result` (`:table` →
PrettyTables, `:csv` → CSV.write, `:json` → the versioned envelope).

**Rendering the result to a DataFrame** goes through the central `_emit_result` router
(`src/commands/shared.jl`), which dispatches on explicit type unions mirroring upstream
1:1 (never trait probes — the mock must mirror real exactly):

1. `long_table(result)` — MEMs' tidy renderer for array-valued results (IRF, FEVD, forecasts): one row per `(horizon, variable[, shock])` cell. Used by `irf` var/vecm/bvar/lp/tvpvar/favar/sdfm (cholesky-family paths; Arias/Uhlig/sign-identified-set paths are hand-built, see 3), `fevd` var/vecm/favar/sdfm (cholesky-family paths; bvar/lp/pvar are hand-built, see 3), and `forecast` var/vecm/lp/arima/sarima/arfima/static/bvar/dynamic/gdfm/favar/sdfm/setar/star/ms-ar/ms/scenario (scenario appends the `unconditional` baseline via the helper's `extra_cols`; `forecast midas` and the volatility forecasts are hand-built, see 3).
2. **`DataFrame(model)`** — MEMs' tidy renderer for coefficient-bearing models: one row per
   term, columns `term|estimate|std_error|stat|p_value|ci_lower|ci_upper` (plus an
   `equation`/`alternative`/`block` prefix for VAR/multinomial/ordered models, and an
   `event_time` key for DiD). Used by
   `estimate` var/reg/iv/logit/probit/preg/piv/plogit/pprobit/ologit/oprobit/mlogit,
   `did estimate` (event-time block; the group-time block is hand-built, see 3), and
   `predict choice logit|probit --marginal-effects` (vector-form `MarginalEffects`; the
   ordered/multinomial matrix forms stay hand-built, see 3).
3. **Hand-built `DataFrame(...)`** — kept only where MEMs has no
   matching result type (notably `irf`/`fevd pvar`, `hd`, `predict`/`residuals`, Arias/Uhlig/sign
   IRF paths, the whole `io` family, the SUR/3SLS systems and MGARCH (CCC/DCC/BEKK) commands,
   the penalized/robust/Tobit/truncated/Heckman regression commands, the qreg/RDD/gmm/smm/ml/midas estimate leaves, SVAR/SVEC estimate (`DataFrame` on svar.A/B, svec.B0/Xi), the state-space/TVP and
   nonparametric (KDE/kernel-reg/LOWESS) commands, the single-equation/panel cointegrating
   regression models (`CointRegModel`/`PanelCointRegModel`), the ARDL/NARDL family
   (`ARDLModel`/`NARDLModel`/`ARDLLongRun`/`ARDLBoundsTest`/`NARDLSymmetryTest`/`NARDLMultipliers`
   — `estimate univariate ardl`/`nardl`, `test coint ardl-bounds`/`nardl-symmetry`, `estimate univariate nardl`), and the
   dynamic heterogeneous-panel ARDL family (`PMGModel` — `estimate panel pmg`, `test panel pmg-hausman`), and the
   nonlinear-TS family (`ThresholdModel`/`STARModel`/`MSRegModel` — `estimate regime setar`/`star`/`ms-ar`/`ms`; all three `*Forecast` types (`ThresholdForecast`/`STARForecast`/`MSForecast`) render via `long_table`, with ms-ar/ms adding a hand-built predicted-regime-probabilities table) — none of
   these result types are Tables.jl-registered upstream) or where the tidy schema would lose information the command
   needs to convey (volatility `forecast`'s `variance|volatility` table — a sqrt transform,
   different data; `forecast midas` — the generic `long_table` would mislabel the direct
   horizon as 1 and drop `se`; `did estimate`'s group-time block). The `io` matrices (Leontief/Ghosh inverses, coefficients), MGARCH conditional
   correlations, and the Markov-switching K×K regime-transition matrix (`estimate regime ms-ar`/`ms`) render
   **wide** (sector×sector / series×series / regime×regime); vector results render one row
   per sector/term.

---

## CLI Framework

The CLI framework is custom-built (adapted from Comonicon.jl). Key types:

### Type Hierarchy

- **`Entry`** -- Top-level: name + root `NodeCommand` + version
- **`NodeCommand`** -- Command group: name + `Dict{String, Union{NodeCommand, LeafCommand}}`
- **`LeafCommand`** -- Executable: name + handler function + args/options/flags
- **`Argument`** -- Positional parameter (name, type, required, default)
- **`Option`** -- Named `--opt=val` or `-o val` (name, short, type, default)
- **`Flag`** -- Boolean `--flag` or `-f` (name, short)

### Parser

The `tokenize()` function converts raw argument strings into `ParsedArgs`:

```
--opt=val     → options["opt"] = "val"
--opt val     → options["opt"] = "val"
-o val        → options["o"] = "val"
--flag        → flags = Set(["flag"])
-abc          → flags = Set(["a", "b", "c"])     # bundled
--            → stops option parsing
other         → positional arguments
```

Then `bind_args()` maps parsed tokens to the `LeafCommand`'s declared arguments, options, and flags, with type conversion via `convert_value()`.

### Dispatch

`dispatch()` walks the command tree:

1. Entry-level: `--version` / `-V` / `--warranty` / `--conditions` fire only as
   the **first** token (leading-only); an empty argv or a leading
   `--help` / `-h` prints top-level help. Then control passes to the root node.
2. Node-level: match the first arg token as a group name, recurse into the child.
   An empty token list prints that group's help.
3. Leaf-level: `-h` / `--help` anywhere in the remaining argv prints leaf help;
   an empty invocation with required positionals prints leaf help instead of
   erroring. Otherwise tokenize, bind to declared params, call `handler(; bound...)`.

Unknown command names raise `DispatchError` (exit 2);
unknown options and bad values raise `ParseError` (exit 2) with a nearest-match hint. stdout carries data
only — one JSON envelope, one table, or one CSV; all status and diagnostics go
to stderr. JSON failures additionally emit a single error envelope on stdout.

---

## Module Structure

```
src/
  Friedman.jl             # Main module: imports, includes, build_app(), const APP, run_cli, main()
  cli/
    types.jl              # CLI structs (Argument, Option, Flag, Leaf/Node/Entry)
    parser.jl             # tokenize(), bind_args(), convert_value()
    dispatch.jl           # dispatch() → dispatch_node() → dispatch_leaf()
    help.jl               # print_help() with colored, column-aligned output
  io.jl                   # data loading + output: EXAMPLE_DATASETS / parse_dataset_name / dataset_to_dataframe / dataset_stem (example-dataset single source), load_data, df_to_matrix, variable_names, output_result / output_kv, global-flag and stderr status helpers
  output/
    errors.jl             # CliError taxonomy + exit-code map
    envelope.jl           # versioned JSON envelope
    render.jl             # table / CSV / JSON renderers
  config.jl               # TOML loaders (priors, identification, GMM/SMM, DSGE, systems)
  model_handle.jl         # save_model_dispatch / load_model_dispatch (.jld2 | .fmod | model://)
  handles.jl              # stem resolver, data-kind check, typed persist
  registry/
    spec.jl               # CommandSpec (data_kinds / model_types / result_types)
    adapter.jl            # wrap_legacy: stem-resolve + type-check + save
    families.jl           # shared family option sets + regroup replacements
  commands/
    shared.jl             # shared estimation/output helpers
    estimate.jl           # estimate family
    test.jl               # test family
    irf.jl                # irf family
    fevd.jl               # fevd family
    hd.jl                 # hd family
    forecast.jl           # forecast family (incl. scenario + evaluate)
    fitted.jl             # predict + residuals families
    filter.jl             # filter family
    data.jl               # data management
    data_simulate.jl      # data simulate DGPs (appended by register_data)
    io.jl                 # io input-output family
    nowcast.jl            # nowcast family
    dsge.jl               # dsge RA + bayes + closed-agent families
    hadsge.jl             # hadsge heterogeneous-agent family
    did.jl                # did estimation (tests live under test did)
    spectral.jl           # spectral family
    policy.jl             # policy counterfactual / optimal-policy family
    completions.jl        # completions bash|fish|zsh
    model.jl              # model info + reproduce
    serve.jl              # serve --mcp
    show.jl               # show HANDLE
    schema.jl             # schema self-description (registry-hidden)
    multipliers.jl        # shared NARDL multiplier-table emitters (no top-level group)
    agent_guide.md        # agent guide single source, baked in at precompile
  repl.jl                 # interactive REPL session mode
```

Include order in `Friedman.jl` matters: `shared.jl` precedes every command
file, and the registry precedes the command files that emit specs. Command
totals live only in the generated [CLI reference overview](commands/overview.md).

The ARDL/NARDL family (`estimate univariate ardl`/`nardl` in `estimate.jl`, `test coint ardl-bounds`/`nardl-symmetry`
in `test.jl`, and the cumulative-multiplier tables on `estimate univariate nardl`) all fit via the shared
`_load_reg_data` (`y` + `X`) loader and the `_fit_ardl`/`_fit_nardl` wrappers in `estimate.jl`, so
the four commands share one estimation path and one set of hand-built renderers. The dynamic
heterogeneous-panel ARDL family (`estimate panel pmg` in `estimate.jl`, `test panel pmg-hausman` in `test.jl`)
similarly shares the hardened `_load_panel_reg` panel loader (`shared.jl`): both resolve `--dep`/`--indep`
to `Symbol`s over a `PanelData` and splat the regressors into `estimate_pmg(pd, dep, xs...)`; the test
command fits the panel twice (efficient vs Mean Group) and runs the PMG-typed `hausman_test`.

---

## Handler Conventions

- **Naming**: `_action_model(; kwargs...)` (e.g., `_estimate_var`, `_irf_bvar`, `_forecast_sarima`, `_nowcast_dfm`) — note the volatility forecasts are factory-generated const aliases (`_forecast_arch`, shared.jl), not hand-written functions.
- **Signature**: keyword arguments match declared `Option` names (with hyphen-to-underscore)
- **Pattern**: load data → call library → build DataFrame → `output_result()`
- **Registration**: each command file defines `register_X_commands!()` returning a `NodeCommand` (fitted.jl defines two; schema/serve/show are singleton leaves returning a `LeafCommand` via `to_leaf`; multipliers.jl defines none).

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `MacroEconometricModels` | Core econometric library |
| `CSV` | Data loading |
| `DataFrames` | Tabular data manipulation |
| `PrettyTables` | Terminal table formatting |
| `JSON3` | JSON output format |
| `TOML` (stdlib) | Configuration file parsing |
| `LinearAlgebra` (stdlib) | Matrix operations |
| `Statistics` (stdlib) | Mean, median calculations |
| `SparseArrays` (stdlib) | Sparse matrix operations |
| `Random` (stdlib) | Random number generation (DSGE simulation) |
| `Logging` (stdlib) | Route MEMs `@info`/`@warn` to stderr; `--quiet` drops info |
| JLD2 | Native .jld2 persist (imported explicitly to activate the MEMs JLD2 extension) |
| FFTW | Activates the MEMs FFTW extension (GDFM/spectral) |
| Serialization (stdlib) | Interim .fmod handles |
| Dates (stdlib) | Date/time support |

---

## Compatibility

| | Version |
|---|---------|
| Julia | `>= 1.13` |
| MacroEconometricModels | `1.0.0` |

---

## Exit codes

| Code | Class | Meaning |
|---|---|---|
| 0 | — | Success |
| 2 | `usage/*` | CLI usage (unknown command, parse error, invalid option) |
| 3 | `data/*` | Input data (missing file, wrong kind, bad values) |
| 4 | `config/*` | Config/TOML |
| 5 | `model/*` | Model/domain (convergence, identification, solve) |
| 6 | `env/*` | Environment (model-version mismatch) |
| 1 | other | Internal/bug |

---

## Stability policy

The machine surface is the API — the command tree, the
option/flag surface, the envelope schema (`schema/envelope-v1.json`), the
stable `data` table keys, the error-code taxonomy, and the exit codes.
Envelope schema v1 is **frozen at v1.0.0** (a breaking envelope change bumps
`schema_version` to 2 and is a major release). Minors are additive-only:
removals and renames happen only at majors after at least one minor of
deprecation alias. Kebab-case command names only, envelope JSON only.

---

## Totals

Command totals are registry-generated — see the [CLI reference overview](commands/overview.md).

---

## References

- [CLI reference overview](commands/overview.md) — generated command totals and per-command pages
- [Agent guide](agent-guide.md) — machine-actionable usage contract
