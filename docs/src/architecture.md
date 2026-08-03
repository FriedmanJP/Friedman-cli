# Architecture

Friedman-cli is a Julia CLI application with a custom command-line framework adapted from Comonicon.jl.

## Execution Flow

```
bin/friedman ARGS
  → Pkg.activate(project_dir)
  → Friedman.main(ARGS) → run_cli(ARGS)
    → Friedman.APP                         # memoized Entry (const APP = build_app() at precompile)
      # build_app() registers all top-level command groups once
    → dispatch(APP, args)
      → dispatch_node()                    # walks NodeCommand tree by matching tokens
      → dispatch_leaf()                    # tokenize → bind_args → leaf.handler(; bound...)
```

## Data Flow

```
CSV file → load_data(path)                 # → DataFrame, validates exists & non-empty
         → df_to_matrix(df)                # → Matrix{Float64}, selects numeric columns
         → variable_names(df)              # → Vector{String}, numeric column names
                ↓
    MacroEconometricModels.jl functions     # estimate_var, irf, forecast, etc.
                ↓
    Results → DataFrame                     # command renders the result to a DataFrame
           → output_result(df; format, output, title)
                ↓
              :table → PrettyTables (center-aligned)
              :csv   → CSV.write
              :json  → JSON3.write (array of row dicts)
```

**Rendering the result to a DataFrame (C051)** goes through one of three paths, in order of
preference:

1. **`long_table(result)`** — MEMs' tidy renderer for array-valued results (IRF, FEVD,
   forecasts): one row per `(horizon, variable[, shock])` cell. Used by `irf`/`fevd`
   var/vecm/bvar/lp/favar/sdfm and `forecast` var/vecm/lp/arima/static/bvar/dynamic/gdfm/favar.
2. **`DataFrame(model)`** — MEMs' tidy renderer for coefficient-bearing models: one row per
   term, columns `term|estimate|std_error|stat|p_value|ci_lower|ci_upper` (plus an
   `equation`/`alternative`/`block` prefix for VAR/multinomial/ordered models). Used by
   `estimate` var/reg/iv/logit/probit/preg/piv/plogit/pprobit/ologit/oprobit/mlogit.
3. **Hand-built `DataFrame(...)`** — the pre-C051 fallback, kept only where MEMs has no
   matching result type (`irf`/`fevd pvar`, `hd`, `predict`/`residuals`, Arias/Uhlig/sign
   IRF paths, the whole `io` family, the SUR/3SLS systems and MGARCH (CCC/DCC/BEKK) leaves,
   the penalized/robust/Tobit/truncated/Heckman regression leaves, the state-space/TVP and
   nonparametric (KDE/kernel-reg/LOWESS) leaves, the single-equation/panel cointegrating
   regression leaves (`CointRegModel`/`PanelCointRegModel`), the ARDL/NARDL family
   (`ARDLModel`/`NARDLModel`/`ARDLLongRun`/`ARDLBoundsTest`/`NARDLSymmetryTest`/`NARDLMultipliers`
   — `estimate ardl`/`nardl`, `test ardl-bounds`/`nardl-symmetry`, `multipliers nardl`), and the
   dynamic heterogeneous-panel ARDL family (`PMGModel` — `estimate pmg`, `test pmg-hausman`), and the
   nonlinear-TS family (`ThresholdModel`/`STARModel`/`MSRegModel` — `estimate setar`/`star`/`ms-ar`/`ms`;
   the two `*Forecast` types ARE registered and render via `long_table`) — none of
   these result types are Tables.jl-registered upstream) or where the tidy schema would lose information the command
   needs to convey (volatility `forecast`'s `variance|volatility` table, `did estimate`'s ATT
   summary). The `io` matrices (Leontief/Ghosh inverses, coefficients), MGARCH conditional
   correlations, and the Markov-switching K×K regime-transition matrix (`estimate ms-ar`/`ms`) render
   **wide** (sector×sector / series×series / regime×regime); vector results render one row
   per sector/term.

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

1. Entry-level: check `--version` / `--help` / `--warranty` / `--conditions`, then delegate to root node
2. Node-level: match first arg token as subcommand name, recurse into child
3. Leaf-level: tokenize remaining args, bind to declared params, call `handler(; bound...)`

Unknown subcommands print an error and show help. `--help` at any level prints context-appropriate help.

## Module Structure

```
src/
  Friedman.jl             # Main module: imports, includes, build_app(), const APP, run_cli, main()
  cli/
    types.jl              # 6 CLI structs (Argument, Option, Flag, Leaf/Node/Entry)
    parser.jl             # tokenize(), bind_args(), convert_value()
    dispatch.jl           # dispatch() → dispatch_node() → dispatch_leaf()
    help.jl               # print_help() with colored, column-aligned output
  io.jl                   # load_data, df_to_matrix, variable_names, output_result
  config.jl               # TOML loader for priors, identification, GMM, non-Gaussian
  commands/
    shared.jl             # ID_METHOD_MAP, shared estimation/output helpers
    estimate.jl           # 24 estimation subcommands
    test.jl               # 29+ test subcommands (+ nested var 2, pvar 4)
    irf.jl                # 7 IRF subcommands
    fevd.jl               # 7 FEVD subcommands
    hd.jl                 # 5 HD subcommands
    forecast.jl           # 14 forecast subcommands
    predict.jl            # 16 predict subcommands
    residuals.jl          # 16 residuals subcommands
    filter.jl             # 5 filter subcommands
    data.jl               # 9 data subcommands
    nowcast.jl            # 5 nowcast subcommands
    dsge.jl               # DSGE subcommands + bayes node (13 sub-leaves) + HA/CT/OLG nodes
    did.jl                # 7 DID subcommands (3 estimation + 4 test)
    multipliers.jl        # multipliers nardl — new top-level (C062b, action-first)
```

The ARDL/NARDL family (`estimate ardl`/`nardl` in `estimate.jl`, `test ardl-bounds`/`nardl-symmetry`
in `test.jl`, and `multipliers nardl` in the new top-level `multipliers.jl`) all fit via the shared
`_load_reg_data` (`y` + `X`) loader and the `_fit_ardl`/`_fit_nardl` wrappers in `estimate.jl`, so
the four leaves share one estimation path and one set of hand-built renderers. The dynamic
heterogeneous-panel ARDL family (`estimate pmg` in `estimate.jl`, `test pmg-hausman` in `test.jl`)
similarly shares the hardened `_load_panel_reg` panel loader (`shared.jl`): both resolve `--dep`/`--indep`
to `Symbol`s over a `PanelData` and splat the regressors into `estimate_pmg(pd, dep, xs...)`; the test
leaf fits the panel twice (efficient vs Mean Group) and runs the PMG-typed `hausman_test`.

## Handler Conventions

- **Naming**: `_action_model(; kwargs...)` (e.g., `_estimate_var`, `_irf_bvar`, `_forecast_arch`, `_nowcast_dfm`)
- **Signature**: keyword arguments match declared `Option` names (with hyphen-to-underscore)
- **Pattern**: load data → call library → build DataFrame → `output_result()`
- **Registration**: each command file defines `register_X_commands!()` returning a `NodeCommand`

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
| `Logging` (stdlib) | Route MEMs `@info`/`@warn` to stderr; `--quiet` drops info (C050) |

## Compatibility

| | Version |
|---|---------|
| Julia | `>= 1.12` |
| MacroEconometricModels | `0.7.0` |

## Totals

18 top-level commands, 385 subcommands (registry-generated — see the inventory at the bottom of `CLAUDE.md`).
