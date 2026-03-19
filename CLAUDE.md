# CLAUDE.md — Friedman-cli

Work strictly on dev branch unless otherwise specified.

CLAUDE.md is always .gitignored. DO NOT UPLOAD TO REMOTE REPO EVER.

**STRICT:** `docs/plans/` and `docs/superpowers/` MUST NEVER appear in the remote repo. They are gitignored and contain local-only specs/plans. If files are accidentally tracked, `git rm --cached` them immediately.

**STRICT:** `.gitignore` itself is gitignored and must NOT appear in the remote repo.

**MUST:** After implementing any feature, command, or structural change, you MUST update ALL documentation:
1. `CLAUDE.md` — project overview, command hierarchy, command details, API reference, testing sections
2. `README.md` — commands table, usage examples, version references
3. `docs/` — Documenter.jl pages: `make.jl`, `index.md`, `commands/overview.md`, `architecture.md`, `api.md`, and create/update relevant `commands/*.md` page

**MUST:** Before every `git push`, run both security scanners and fix any findings:
1. `gitleaks detect --source . -v` — scan for leaked secrets/credentials in git history
2. `semgrep scan --config auto` — scan for code security vulnerabilities
Do NOT push if either tool reports findings. Fix issues first.

## Project Overview

Friedman-cli (v0.4.0) is a Julia CLI for macroeconometric analysis, wrapping [MacroEconometricModels.jl](https://github.com/chung9207/MacroEconometricModels.jl) (v0.4.1). It provides terminal-based VAR/BVAR/Panel VAR estimation, impulse response analysis, DSGE modeling (solve, IRF, FEVD, HD, simulate, estimate, OccBin, perfect foresight, full Bayesian DSGE workflow), FAVAR, structural DFM, cross-sectional regression (OLS/WLS/IV/Logit/Probit), panel regression (FE/RE/pooled with IV and logit/probit), ordered/multinomial choice models (ordered logit/probit, multinomial logit), factor models, local projections, difference-in-differences (TWFE, CS, SA, BJS, dCdH), event study LP, LP-DiD (Dube et al. 2025), unit root/cointegration tests (including Fourier ADF/KPSS, DF-GLS, LM with breaks, ADF 2-break, Gregory-Hansen), structural break tests, panel unit root tests, VIF multicollinearity diagnostics, GMM/SMM estimation, ARIMA modeling/forecasting, volatility models (ARCH/GARCH/EGARCH/GJR-GARCH/SV), non-Gaussian SVAR identification, time series filtering, spectral analysis (ACF, periodogram, spectral density, cross-spectrum, transfer function), nowcasting, interactive REPL session mode with data/result caching and tab completion, and data management. Action-first CLI: 14 top-level commands organized by action (`estimate`, `test`, `irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`, `filter`, `data`, `nowcast`, `dsge`, `did`, `spectral`), ~199 subcommands. GPL-3.0 licensed. ~15,000 lines across 21 source files.

## Quick Reference

```bash
# Quick install (macOS/Linux)
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash

# Quick install (Windows PowerShell)
# irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex

# Install from source (uses MacroEconometricModels.jl from GitHub by default)
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e '
using Pkg
Pkg.rm("MacroEconometricModels")
Pkg.add(url="https://github.com/FriedmanJP/MacroEconometricModels.jl.git")
'

# Run (installed via installer)
friedman [command] [subcommand] [args] [options]

# Run (development mode)
julia --project bin/friedman [command] [subcommand] [args] [options]

# Interactive REPL
friedman repl

# Build compiled executable (sysimage + bundled launcher, ~0.4s startup)
julia build_app.jl          # local dev build (macOS only, gitignored)
julia build_release.jl      # cross-platform release build (committed)
# Installs to build/friedman/; symlink to ~/.local/bin or use installer

# Test (CLI engine + IO + config + command handlers; no MacroEconometricModels needed)
julia --project test/runtests.jl
```

## Project Structure

```
bin/
  friedman                # Entry point — activates project, calls Friedman.main(ARGS)
src/
  Friedman.jl             # Main module (~120 lines) — imports, includes, build_app(), main(), julia_main()
  config.jl               # TOML loader (~250 lines): load_config, get_prior, get_identification, get_gmm, get_nongaussian, get_uhlig_params, get_dsge, get_dsge_constraints, get_smm, get_dsge_priors
  io.jl                   # Data I/O (142 lines): load_data, df_to_matrix, variable_names, output_result, output_kv
  cli/
    types.jl              # 6 structs (112 lines): Argument, Option, Flag, LeafCommand, NodeCommand, Entry
    parser.jl             # tokenize() → ParsedArgs, bind_args(), convert_value() (190 lines)
    dispatch.jl           # dispatch() walks Entry→NodeCommand→LeafCommand, calls handler (105 lines)
    help.jl               # print_help() generates colored, column-aligned help text (150 lines)
    COMONICON_LICENSE      # License for adapted Comonicon.jl code
  commands/
    shared.jl             # Shared utilities (~1000 lines): ID_METHOD_MAP (16 entries), _load_and_estimate_var/bvar/vecm/pvar/favar, _build_prior, _maybe_plot, _load_dsge_model, _solve_dsge, _load_dsge_constraints, _load_panel_for_did, _load_panel_or_matrix, _REG_COMMON_OPTIONS, _load_reg_data, _load_clusters, _load_weights, _reg_coef_table, _load_panel_reg_data, etc.
    estimate.jl           # Estimation (~1800 lines): 31 leaves (9 with --plot/--plot-save)
    test.jl               # Testing (~2050 lines): 41 leaves + nested var/pvar
    irf.jl                # IRF (~625 lines): 7 leaves, --plot/--plot-save
    fevd.jl               # FEVD (~395 lines): 7 leaves, --plot/--plot-save
    hd.jl                 # HD (~330 lines): 5 leaves, --plot/--plot-save
    forecast.jl           # Forecast (~800 lines): 14 leaves (12 with --plot/--plot-save)
    predict.jl            # Predict (~800 lines): 23 leaves
    residuals.jl          # Residuals (~730 lines): 23 leaves
    filter.jl             # Filter (~375 lines): 5 leaves, --plot/--plot-save
    data.jl               # Data (~530 lines): 11 leaves (+ mpdta, ddcg datasets)
    nowcast.jl            # Nowcast (~315 lines): 5 leaves
    dsge.jl               # DSGE (~950 lines): 8 leaves + bayes node (8 sub-leaves), --plot/--plot-save
    did.jl                # DID & Event Study LP (~510 lines): 3 estimation + 4 test leaves, --plot/--plot-save
    spectral.jl           # Spectral analysis (~220 lines): 5 leaves
  repl.jl               # REPL session mode (~360 lines): Session struct, state management, dispatch wrapper, tab completion, LineEdit integration
test/
  runtests.jl             # CLI engine + IO + config tests (~3,470 lines)
  mocks.jl                # Mock MacroEconometricModels module (~2,234 lines)
  test_commands.jl        # Command handler tests (~6,280 lines)
  test_repl.jl           # REPL session tests (~120 lines)
Project.toml              # Julia project — deps and compat
docs/API_REFERENCE.md     # MacroEconometricModels.jl types & functions reference
build_app.jl              # Local dev build script: macOS sysimage + launcher (gitignored)
build_release.jl          # Cross-platform release build: auto-detect OS, runtime Julia discovery
install.sh                # macOS/Linux installer: juliaup setup, download, ~/.friedman-cli/
install.ps1               # Windows installer: winget/juliaup, download, ~/.friedman-cli/
.github/workflows/
  CI.yml                  # Test CI: Ubuntu/macOS/Windows matrix
  Documentation.yml       # Documenter.jl deployment to GitHub Pages
  release.yml             # Release CI: matrix sysimage build on tag push, GitHub Release
```

## Dependencies (Project.toml)

Direct: `CSV`, `DataFrames`, `Dates`, `FFTW`, `JSON3`, `MacroEconometricModels`, `NonlinearSolve`, `PrettyTables`, `Random`, `SparseArrays`
Stdlib (imported in Friedman.jl): `TOML`, `LinearAlgebra` (eigvals, diag, I, svd), `Statistics` (mean, median, var)
Weak deps: `JuMP`, `Ipopt`, `PATHSolver` (DSGE constrained solvers)
Julia compat: `1.12`  MacroEconometricModels compat: `0.4.1`

**Note:** Always install `MacroEconometricModels` from GitHub (`https://github.com/chung9207/MacroEconometricModels.jl.git`) unless a specific registry version is requested. The Project.toml UUID (`14a6ec33`) matches the registry UUID. Use `Pkg.rm` + `Pkg.add(url=...)` as shown in Quick Reference.

## Command Hierarchy

```
friedman
├── repl         (interactive session mode — not a subcommand, handled in main())
├── estimate     var | bvar | lp | arima | gmm | smm | static | dynamic | gdfm |
│                arch | garch | egarch | gjr_garch | sv | fastica | ml | vecm | pvar |
│                favar | sdfm | reg | iv | logit | probit |
│                preg | piv | plogit | pprobit | ologit | oprobit | mlogit
├── test         adf | kpss | pp | za | np | johansen | normality |
│                identifiability | heteroskedasticity | arch_lm | ljung_box |
│                granger | lr | lm | andrews | bai-perron |
│                panic | cips | moon-perron | factor-break |
│                fourier-adf | fourier-kpss | dfgls | lm-unitroot |
│                adf-2break | gregory-hansen | vif |
│                hausman | breusch-pagan | f-fe | pesaran-cd | wooldridge-ar |
│                modified-wald | fisher | bartlett-wn | box-pierce | durbin-watson |
│                brant | hausman-iia |
│                var (lagselect | stability) |
│                pvar (hansen_j | mmsc | lagselect | stability)
├── irf          var | bvar | lp | vecm | pvar | favar | sdfm
├── fevd         var | bvar | lp | vecm | pvar | favar | sdfm
├── hd           var | bvar | lp | vecm | favar
├── forecast     var | bvar | lp | arima | static | dynamic | gdfm |
│                arch | garch | egarch | gjr_garch | sv | vecm | favar
├── predict      var | bvar | arima | vecm | static | dynamic | gdfm |
│                arch | garch | egarch | gjr_garch | sv | favar | reg | logit | probit |
│                preg | piv | plogit | pprobit | ologit | oprobit | mlogit
├── residuals    var | bvar | arima | vecm | static | dynamic | gdfm |
│                arch | garch | egarch | gjr_garch | sv | favar | reg | logit | probit |
│                preg | piv | plogit | pprobit | ologit | oprobit | mlogit
├── filter       hp | hamilton | bn | bk | bhp
├── data         list | load | describe | diagnose | fix | transform | filter | validate | balance |
│                dropna | keeprows
├── nowcast      dfm | bvar | bridge | news | forecast
├── dsge         solve | irf | fevd | hd | simulate | estimate | perfect-foresight | steady-state |
│                bayes (estimate | irf | fevd | hd | simulate | summary | compare | predictive)
├── did          estimate | event-study | lp-did |
│                test (bacon | pretrend | negweight | honest)
└── spectral     acf | periodogram | density | cross | transfer
```

Total: 14 top-level commands, ~199 subcommands. Plottable commands (`irf`, `fevd`, `hd`, `forecast`, `filter`, `dsge`, `did`, `spectral`, `estimate` vol/factor/favar/sdfm) support `--plot`/`--plot-save` flags.

## Architecture

### Execution Flow

```
bin/friedman ARGS
  → Pkg.activate(project_dir)
  → Friedman.main(ARGS)
    → build_app()                          # constructs Entry with full command tree
      → register_estimate_commands!()      # 14 register functions, one per top-level command
      → register_test_commands!() ... register_dsge_commands!() ... register_did_commands!() ... register_spectral_commands!()
    → dispatch(entry, args)
      → check --version/--help/--warranty/--conditions  # handled pre-dispatch at Entry level
      → dispatch_node()                    # walks NodeCommand tree by matching arg tokens
      → dispatch_leaf()                    # tokenize → bind_args → leaf.handler(; bound...)
```

### Data Flow

```
CSV file → load_data(path)                 # → DataFrame, validates exists & non-empty
         → df_to_matrix(df)                # → Matrix{Float64}, selects numeric columns only
         → variable_names(df)              # → Vector{String}, numeric column names
                ↓
    MacroEconometricModels.jl functions     # estimate_var, estimate_bvar, irf, etc.
                ↓
    Results → DataFrame                     # command builds result DataFrame
           → output_result(df; format, output, title)
                ↓
              :table → PrettyTables (alignment=:c, title only — PrettyTables v3 compat)
              :csv   → CSV.write
              :json  → JSON3.write (array of row dicts)
```

### CLI Framework

Custom-built, adapted from Comonicon.jl. Key types:
- `Entry` — top-level: name + root NodeCommand + version
- `NodeCommand` — command group: name + `Dict{String, Union{NodeCommand, LeafCommand}}`
- `LeafCommand` — executable: name + handler function + args/options/flags
- `Argument` — positional (name, type, required, default)
- `Option` — named `--opt=val` or `-o val` (name, short, type, default)
- `Flag` — boolean `--flag` or `-f` (name, short)

Parser features: `--opt=val`, `--opt val`, `-o val`, bundled `-abc`, `--` stops parsing.

## Code Conventions

- **Naming:** functions `snake_case`, types `PascalCase`, internal handlers prefixed `_` (e.g. `_estimate_var`, `_irf_bvar`)
- **Handler naming:** `_action_model(; kwargs...)` pattern (e.g. `_estimate_var`, `_irf_bvar`, `_forecast_arch`, `_test_adf`, `_dsge_solve`)
- **Command pattern:** Each `src/commands/X.jl` defines `register_X_commands!()` → `NodeCommand`
- **Handler signature:** `_action_model(; data::String, option1=default, ...)` — keyword args match declared Options
- **Option hyphen→underscore:** `--control-lags` binds to `control_lags` kwarg (parser replaces `-` with `_`)
- **Config-driven complexity:** TOML files for priors, restrictions, GMM specs, DSGE models — keeps CLI flags clean
- **Auto-selection:** lag orders via `select_lag_order(...; criterion=:aic)`, factor counts via `ic_criteria()`, smoothing λ via cross-validation — when user doesn't specify
- **Output:** `println()` for status, `printstyled(; color=:green/:yellow/:red)` for diagnostics, `output_result()` for data tables
- **Error handling:** `error()` for missing required config, `ParseError` for CLI parsing failures
- **Empty args → help:** `dispatch_leaf` shows help (not ParseError) when called with no args on a command with required positional arguments. All subcommands with `<data>` etc. print usage when invoked bare.

## Command Details

### shared.jl (~1000 lines)
- `ID_METHOD_MAP` — maps 16 CLI id strings to library symbols: cholesky, sign, narrative, longrun, fastica, jade, sobi, dcov, hsic, student_t, mixture_normal, pml, skew_normal, markov_switching, garch_id, uhlig
- `_load_and_estimate_var(data, lags)` — load CSV, auto lag selection, estimate frequentist VAR
- `_load_and_estimate_bvar(data, lags, config, draws, sampler)` — load CSV, build prior, estimate BVAR via MCMC
- `_load_and_estimate_vecm(data, lags, rank, deterministic, method, significance)` — auto/explicit rank
- `_load_and_structural_lp(data, horizons, lags, var_lags, id, vcov, config)` — returns `(slp, Y, varnames)`
- `_build_prior(config, Y, p)` — `MinnesotaHyperparameters` from TOML or auto AR(1) σ
- `_build_check_func(config)` — sign_matrix and narrative check closures from TOML
- `_build_identification_kwargs(id, config)` — kwargs dict (method, check_func, narrative_check)
- `_var_forecast_point(B, Y, p, horizons)` — h-step ahead point forecasts
- `_normal_cdf(x)` — pure-Julia normal CDF approximation (Abramowitz & Stegun) for SE p-values
- `_vol_estimate_output(...)` — shared output builder for volatility estimate commands (includes SE/p-value columns; SVModel guard prevents infinite recursion from StatsAPI defaults)
- `_parse_varlist(str)`, `load_panel_data(data, id_col, time_col)`, `_load_and_estimate_pvar(...)`, `_build_pvar_coef_table(...)`
- `_load_dsge_model(path)` — load DSGE spec from .toml or .jl file
- `_solve_dsge(spec; method, order, degree, grid)` — steady state → linearize → solve, with determinacy/stability diagnostics
- `_load_dsge_constraints(path)` — parse OccBin constraints TOML → Vector{OccBinConstraint}
- `_load_panel_for_did(data, id_col, time_col)` — load CSV as PanelData, print panel summary
- `_load_and_estimate_favar(data, key_vars, factors, lags, method, draws)` — load CSV, parse key vars, auto factor selection, estimate FAVAR
- `_load_panel_or_matrix(data; id_col, time_col)` — dual-mode loader (PanelData or Matrix)
- `_REG_COMMON_OPTIONS` — shared Option array for regression commands (dep, cov-type, clusters, output, format)
- `_load_reg_data(data, dep; weights_col, clusters_col)` — load CSV, split into y, X, varnames
- `_load_clusters(data, clusters_col)` — load cluster assignments or nothing
- `_load_weights(data, weights_col)` — load observation weights or nothing
- `_reg_coef_table(model, varnames)` — build coefficient DataFrame (beta, SE, t, p, CI)
- `_load_panel_reg_data(data, dep; id_col, time_col, instruments_col, weights_col, clusters_col)` — load CSV as PanelData for panel regression commands

### estimate.jl (~1800 lines) — 31 leaves
- **var** — OLS VAR(p), auto lag, coefficients + IC  |  **bvar** — MCMC (nuts/hmc/smc), Minnesota prior
- **lp** — `--method=standard|iv|smooth|state|propensity|robust`  |  **arima** — auto via `auto_arima()`
- **gmm** — LP-GMM, identity/optimal/twostep/iterated  |  **smm** — Simulated Method of Moments (NEW in v0.3.0)
- **static/dynamic/gdfm** — factor models (PCA/dynamic/spectral)
- **arch/garch/egarch/gjr_garch/sv** — volatility models
- **fastica** — ICA-based SVAR (FastICA/JADE/SOBI/dCov/HSIC)  |  **ml** — ML non-Gaussian SVAR
- **vecm** — Johansen MLE, auto/explicit rank  |  **pvar** — Panel VAR with GMM/FE-OLS
- **favar** — FAVAR (two-step/Bayesian), auto factor selection (NEW in v0.3.2)  |  **sdfm** — Structural DFM (Cholesky/sign identification) (NEW in v0.3.2)
- **reg** — OLS/WLS regression with HC0-HC3/clustered SE (NEW in v0.3.3)  |  **iv** — IV (2SLS) regression with first-stage F and Sargan test (NEW in v0.3.3)
- **logit** — Logistic regression for binary choice (NEW in v0.3.3)  |  **probit** — Probit regression for binary choice (NEW in v0.3.3)
- **preg** — Panel OLS/WLS/FE/RE regression (NEW in v0.4.0)  |  **piv** — Panel IV (2SLS) regression with FE/RE (NEW in v0.4.0)
- **plogit** — Panel logistic regression with FE/RE (NEW in v0.4.0)  |  **pprobit** — Panel probit regression with FE/RE (NEW in v0.4.0)
- **ologit** — Ordered logistic regression for ordinal outcomes (NEW in v0.4.0)  |  **oprobit** — Ordered probit regression (NEW in v0.4.0)
- **mlogit** — Multinomial logistic regression for unordered outcomes (NEW in v0.4.0)

### test.jl (~2050 lines) — 41 leaves + nested var/pvar
- **adf/kpss/pp/za/np** — unit root  |  **johansen** — cointegration  |  **normality** — VAR residuals
- **identifiability** — strength/Gaussianity/independence/overid  |  **heteroskedasticity** — MS/GARCH/ST/external
- **arch_lm/ljung_box** — conditional heteroskedasticity / serial autocorrelation
- **granger** — VECM or VAR (`--model=vecm|var`)  |  **lr/lm** — model comparison (data1/data2/lags1/lags2 interface)
- **andrews** — structural break (sup/exp/mean Wald/LR/LM) (NEW in v0.3.2)  |  **bai-perron** — multiple breaks (BIC/LWZ) (NEW in v0.3.2)
- **panic/cips/moon-perron** — panel unit root (NEW in v0.3.2)  |  **factor-break** — factor structure stability (NEW in v0.3.2)
- **fourier-adf** — Fourier ADF with smooth breaks (Enders & Lee 2012) (NEW in v0.3.3)  |  **fourier-kpss** — Fourier KPSS stationarity test (Becker et al. 2006) (NEW in v0.3.3)
- **dfgls** — Elliott-Rothenberg-Stock DF-GLS test (NEW in v0.3.3)  |  **lm-unitroot** — LM unit root with 0/1/2 breaks (Lee & Strazicich) (NEW in v0.3.3)
- **adf-2break** — ADF with two endogenous breaks (NEW in v0.3.3)  |  **gregory-hansen** — cointegration with regime shift (Gregory & Hansen 1996) (NEW in v0.3.3)
- **vif** — Variance Inflation Factors for multicollinearity (NEW in v0.3.3)
- **hausman** — Hausman test for FE vs RE panel model specification (NEW in v0.4.0)
- **breusch-pagan** — Breusch-Pagan LM test for random effects (NEW in v0.4.0)
- **f-fe** — F-test for fixed effects significance (NEW in v0.4.0)
- **pesaran-cd** — Pesaran cross-sectional dependence test (NEW in v0.4.0)
- **wooldridge-ar** — Wooldridge test for serial correlation in panel data (NEW in v0.4.0)
- **modified-wald** — Modified Wald test for groupwise heteroskedasticity (NEW in v0.4.0)
- **fisher** — Fisher-type panel unit root test (NEW in v0.4.0)
- **bartlett-wn** — Bartlett white noise test for residuals (NEW in v0.4.0)
- **box-pierce** — Box-Pierce portmanteau test (NEW in v0.4.0)
- **durbin-watson** — Durbin-Watson test for first-order serial correlation (NEW in v0.4.0)
- **brant** — Brant test for proportional odds assumption (ordered logit) (NEW in v0.4.0)
- **hausman-iia** — Hausman-McFadden IIA test for multinomial logit (NEW in v0.4.0)
- **var lagselect/stability** — lag selection (AIC/BIC/HQC), companion eigenvalues
- **pvar hansen_j/mmsc/lagselect/stability** — Panel VAR diagnostics

### irf.jl (~625 lines) — 7 leaves
var (16 id schemes incl. Arias/Uhlig, bootstrap/theoretical CIs, --cumulative, --identified-set, --stationary-only), bvar (68% credible intervals), lp (structural, multi-shock), vecm (via `to_var`), pvar (OIRF/GIRF), favar (--panel-irf flag for panel-wide IRF via loadings) (NEW in v0.3.2), sdfm (structural DFM IRF) (NEW in v0.3.2)

### fevd.jl (~395 lines) — 7 leaves
var/bvar/lp (bias-corrected, Gorodnichenko & Lee 2019)/vecm/pvar/favar/sdfm — proportions tables (Arias/Uhlig support). FAVAR and SDFM leaves NEW in v0.3.2.

### hd.jl (~330 lines) — 5 leaves
var/bvar/lp/vecm/favar — shock contributions, initial conditions, verify decomposition (Arias/Uhlig support). FAVAR leaf NEW in v0.3.2.

### forecast.jl (~800 lines) — 14 leaves
var (analytical CIs, --ci-method=bootstrap uses VARForecast accessors), bvar (credible intervals, BVARForecast accessors), lp (`--shock-size`, LPForecast.forecast field), arima (auto), static/dynamic/gdfm, arch/garch/egarch/gjr_garch/sv, vecm (bootstrap CIs), favar (--panel-forecast flag for panel-wide forecast via loadings) (NEW in v0.3.2)

### predict.jl / residuals.jl (~800/~730 lines each) — 23 leaves each
var/bvar/arima/vecm/static/dynamic/gdfm/arch/garch/egarch/gjr_garch/sv/favar/reg/logit/probit — in-sample fitted values / model residuals. FAVAR leaf NEW in v0.3.2. reg/logit/probit NEW in v0.3.3. Logit/probit predict supports `--marginal-effects`, `--odds-ratio` (logit only), `--classification-table`, `--threshold`. preg/piv/plogit/pprobit/ologit/oprobit/mlogit NEW in v0.4.0. Ordered logit/probit predict supports `--marginal-effects`, `--category`. Multinomial logit predict supports `--marginal-effects`, `--base-category`.

### filter.jl (~375 lines) — 5 leaves
hp (λ), hamilton (h,p), bn (auto ARIMA, --method=statespace), bk (band-pass), bhp (BIC/ADF stopping) — trend + cycle + variance ratios. Length-safe trend()/cycle() indexing for Hamilton/BK valid ranges.

### data.jl (~530 lines) — 11 leaves
list (FRED-MD/FRED-QD/PWT/mpdta/ddcg), load (`--transform/--vars/--country/--dates`), describe (summary stats), diagnose (NaN/Inf/constant), fix (listwise/interpolate/mean), transform (tcodes), filter (direct filter calls), validate (model suitability), balance (panel balancing), dropna (drop rows with missing values, `--cols` to target specific columns) (NEW in v0.4.0), keeprows (filter rows by condition expression, `--where` flag) (NEW in v0.4.0). Uses keyword `TimeSeriesData(Y; varnames=..., tcode=..., time_index=...)` constructor.

### nowcast.jl (~315 lines) — 5 leaves
dfm (dynamic factor nowcast), bvar (BVAR-based), bridge (bridge equations), news (nowcast news decomposition), forecast (from fitted nowcast model). Uses AbstractNowcastModel types.

### dsge.jl (~950 lines) — 8 leaves + bayes node (8 sub-leaves) (NEW in v0.3.0, bayes expanded in v0.3.3, hd added in v0.4.0)
- **solve** — Solve DSGE model (gensys/klein/perturbation/projection/pfi), outputs policy matrices + determinacy/stability diagnostics. `--constraints` enables OccBin solving. `--constraint-solver` selects solver backend (ipopt/path/nlsolve, default: nlsolve). Supports `--order=3` for 3rd-order perturbation (NEW in v0.3.2).
- **irf** — IRF from solved DSGE. Standard analytical or simulation-based (--n-sim). `--constraints` enables OccBin piecewise-linear IRF. Outputs per-shock tables.
- **fevd** — FEVD from solved DSGE. Outputs per-variable tables.
- **hd** — Historical decomposition from solved DSGE. Requires `--data`. Outputs shock contributions per variable per period. Supports --plot/--plot-save. (NEW in v0.4.0)
- **simulate** — Simulate time series from solved DSGE. `--burn` for burn-in, `--seed` for reproducibility, `--antithetic` for variance reduction.
- **estimate** — Estimate DSGE parameters (--method=irf_matching|likelihood|bayesian|smm). Requires `--data` and `--params`. Outputs coefficient table with SE/t-stat/p-value + J-stat.
- **perfect-foresight** — Deterministic transition path. Requires `--shocks` CSV. `--constraint-solver` selects solver backend.
- **steady-state** — Compute/display steady state. Optional `--constraints` for constrained SS. `--constraint-solver` selects solver backend.
- **bayes** — Bayesian DSGE workflow (NodeCommand with 8 sub-leaves). All require `--data`, `--params`, `--priors` TOML. (leaf in v0.3.2 → expanded NodeCommand in v0.3.3)
  - **estimate** — Posterior sampling (--method=smc|rwmh|csmc|smc2|importance). `--constraint-solver` selects solver backend. Outputs posterior summary + log marginal likelihood.
  - **irf** — Bayesian DSGE impulse responses with posterior uncertainty. Supports --plot/--plot-save.
  - **fevd** — Bayesian DSGE forecast error variance decomposition. Supports --plot/--plot-save.
  - **hd** — Bayesian DSGE historical decomposition with posterior uncertainty. Requires `--data`. Supports --plot/--plot-save. (NEW in v0.4.0)
  - **simulate** — Simulate from posterior. Supports --plot/--plot-save.
  - **summary** — Detailed posterior summary (mean, median, std, 68%/90% CI).
  - **compare** — Compare two models via Bayes factor + marginal likelihoods. Requires --model2, --params2, --priors2.
  - **predictive** — Posterior predictive checks. Outputs predictive vs observed moments.

All DSGE subcommands accept `<model>` positional arg (path to `.toml` or `.jl` model file). TOML parsed via `get_dsge()` config, `.jl` loaded via `Base.include` in sandboxed Module (must evaluate to `DSGESpec`).

### did.jl (~510 lines) — 7 leaves (NEW in v0.3.1, lp-did updated in v0.3.3)
- **estimate** — DID estimation with 5 methods: `--method=twfe|cs|sa|bjs|dcdh`. TWFE (two-way fixed effects), CS (Callaway-Sant'Anna 2021), SA (Sun-Abraham 2021), BJS (Borusyak-Jaravel-Spiess 2024), dCdH (de Chaisemartin-D'Haultfoeuille 2020). Outputs ATT table + overall ATT. CS method shows group-time ATT. Options: `--outcome`, `--treatment` (required), `--leads`, `--horizon`, `--covariates`, `--control-group`, `--cluster`, `--conf-level`, `--n-boot`, `--base-period` (varying|universal, CS only, NEW in v0.3.3).
- **event-study** — Panel event study LP (Jordà 2005 + panel FE). Outputs coefficient table with pre/post-treatment event-time dummies. Options: `--leads`, `--horizon`, `--lags`.
- **lp-did** — LP-DiD (Dube, Girardi, Jorda & Taylor 2025). Returns `LPDiDResult` API. Options: `--outcome`, `--treatment`, `--horizon`, `--pre-window`, `--post-window`, `--ylags`, `--dylags`, `--covariates`, `--cluster`, `--pmd`, `--reweight`, `--nocomp`, `--nonabsorbing`, `--notyet`, `--nevertreated`, `--firsttreat`, `--oneoff`, `--only-pooled`, `--only-event`. (Replaced in v0.3.3)
- **test bacon** — Bacon decomposition (Goodman-Bacon 2021). Diagnoses TWFE heterogeneity bias by decomposing overall ATT into 2×2 DID comparisons with weights.
- **test pretrend** — Pre-trend test for parallel trends assumption. F-test on pre-treatment coefficients. `--method=did|event-study` selects estimation path.
- **test negweight** — Negative weight check (de Chaisemartin-D'Haultfoeuille 2020). Detects problematic negative weights in TWFE.
- **test honest** — HonestDiD sensitivity analysis (Rambachan-Roth 2023). Robust confidence intervals allowing for violations of parallel trends bounded by `--mbar`.

All DID subcommands accept panel CSV data as positional arg with `--id-col`/`--time-col` options (default: first/second columns). Estimation and diagnostic commands support `--plot`/`--plot-save` flags.

### spectral.jl (~220 lines) — 5 leaves (NEW in v0.4.0)
- **acf** — Autocorrelation and partial autocorrelation functions. Options: `--lags`, `--partial` (flag), `--conf-level`. Supports --plot/--plot-save.
- **periodogram** — Raw periodogram (discrete Fourier transform squared magnitudes). Options: `--log` (flag for log-scale), `--detrend`. Supports --plot/--plot-save.
- **density** — Spectral density estimate using Bartlett/Parzen/Tukey-Hanning kernel smoothing. Options: `--window` (kernel type), `--bandwidth`. Supports --plot/--plot-save.
- **cross** — Cross-spectrum between two series: coherence, phase, gain. Options: `--vars` (two variable names), `--bandwidth`. Supports --plot/--plot-save.
- **transfer** — Transfer function estimation between input and output series. Options: `--input`, `--output`, `--bandwidth`. Supports --plot/--plot-save.

All spectral subcommands accept a CSV data file as positional arg and support `--format`/`--output` options.

## TOML Configuration

```toml
# Minnesota prior (for bvar)
[prior]
type = "minnesota"
[prior.hyperparameters]
lambda1 = 0.2    # tau (tightness)
lambda2 = 0.5    # cross-variable shrinkage
lambda3 = 1.0    # lag decay
lambda4 = 100000.0
[prior.optimization]
enabled = true

# Sign restrictions
[identification]
method = "sign"
[identification.sign_matrix]
matrix = [[1, -1, 1], [0, 1, -1], [0, 0, 1]]
horizons = [0, 1, 2, 3]
[identification.narrative]
shock_index = 1
periods = [10, 15, 20]
signs = [1, -1, 1]

# Arias identification
[[identification.zero_restrictions]]
var = 1; shock = 1; horizon = 0
[[identification.sign_restrictions]]
var = 2; shock = 1; sign = "positive"; horizon = 0

# Uhlig tuning
[identification.uhlig]
n_starts = 100; n_refine = 20; max_iter_coarse = 1000; max_iter_fine = 5000; tol_coarse = 1e-5; tol_fine = 1e-10

# Non-Gaussian SVAR
[nongaussian]
method = "fastica"          # fastica/jade/ml/markov/garch/smooth_transition/external
contrast = "logcosh"        # logcosh/exp/kurtosis
distribution = "student_t"  # student_t/skew_t/ghd
n_regimes = 2
transition_variable = "spread"
regime_variable = "nber"

# GMM / SMM
[gmm]
moment_conditions = ["output", "inflation"]
instruments = ["lag_output", "lag_inflation"]
weighting = "twostep"
[smm]
weighting = "two_step"  # identity|optimal|two_step|iterated
sim_ratio = 5
burn = 100

# DSGE model (see docs/ for full equation examples)
[model]
parameters = { rho = 0.9, sigma = 0.01, beta = 0.99, alpha = 0.36, delta = 0.025 }
endogenous = ["C", "K", "Y", "A"]
exogenous = ["e_A"]
[[model.equations]]
expr = "C[t] + K[t] = (1-delta)*K[t-1] + Y[t]"
[solver]
method = "gensys"

# OccBin constraints
[[constraints.bounds]]
variable = "i"; lower = 0.0

# Nonlinear constraints (MEMs v0.4.1)
[[constraints.nonlinear]]
expr = "K[t] + C[t] <= Y[t]"
label = "resource constraint"

# Bayesian DSGE priors (for dsge bayes --priors)
[priors]
[priors.rho]
dist = "beta"
a = 0.5
b = 0.2
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
```

## Building & Installation

### Cross-Platform Install (recommended)

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex

# Specific version
curl -fsSL https://...install.sh | bash -s -- --version 0.4.0
```

The installer:
1. Checks for Julia 1.12 — installs `juliaup` if needed, runs `juliaup add 1.12` (never changes default)
2. Downloads precompiled sysimage from GitHub Releases (~670 MB)
3. Installs to `~/.friedman-cli/` (self-contained: sysimage + source + launcher)
4. Creates PATH shim: symlink in `~/.local/bin/` (macOS/Linux) or adds to user PATH (Windows)
5. Launcher uses `juliaup run +1.12 julia` (with fallback to bare `julia` if >= 1.12)

**Upgrade:** re-run the install command. **Uninstall:** `rm -rf ~/.friedman-cli ~/.local/bin/friedman`

### Release CI (`release.yml`)

On tag push (`v*`), GitHub Actions builds sysimages on 3 platforms (macOS ARM, Linux x64, Windows x64), archives them, and creates a GitHub Release with:
- `friedman-v{VERSION}-darwin-arm64.tar.gz`
- `friedman-v{VERSION}-linux-x86_64.tar.gz`
- `friedman-v{VERSION}-windows-x86_64.zip`
- `checksums.sha256`, `install.sh`, `install.ps1`

### Build Scripts

**`build_release.jl`** (committed) — cross-platform release build:
- Auto-detects sysimage extension (`.dylib`/`.so`/`.dll`)
- Excludes JuMP/Ipopt/PATHSolver weak deps (EPL-2.0 incompatible with GPL-3.0)
- Generates platform-appropriate launcher (bash or `.cmd`)
- Launcher finds Julia at runtime via `juliaup run +1.12` (no hardcoded `Sys.BINDIR`)
- Used by CI and can be run locally

**`build_app.jl`** (gitignored) — local macOS dev build:
- Hardcodes `.dylib` extension and `Sys.BINDIR` julia path
- For quick local iteration only

Both scripts share the same structure:
1. Creates isolated `build_env/` with all deps (moves weak deps JuMP/Ipopt/PATHSolver to real deps)
2. Builds incremental sysimage via `PackageCompiler.create_sysimage()`
3. Bundles sysimage + project + launcher script into `build/friedman/`
4. Cleans up `build_env/`

**Known issues:**
- `PackageCompiler.create_app()` fails on Julia 1.12 (`FieldError: type Symbol has no field julia_main`) — use sysimage approach instead
- `--strip-metadata` causes `StructUtils` precompilation failure on Julia 1.12 — disabled
- PATHSolver UUID in Project.toml `[weakdeps]` is wrong (`f5f7c340-0bb3-4c5b-...` vs registry `f5f7c340-0bb3-5c69-...`); build script resolves by `Pkg.add` by name

## Testing

No MacroEconometricModels dependency needed.

- **CLI engine** (runtests.jl): types, tokenizer, binding, help, dispatch, all command structures
- **IO** (runtests.jl): load_data, df_to_matrix, variable_names, output_result, output_kv
- **Config** (runtests.jl): load_config, get_identification, get_prior, get_gmm, get_nongaussian, get_dsge, get_dsge_constraints, get_smm, get_dsge_priors
- **Handlers** (test_commands.jl): uses test/mocks.jl (~3,000 lines). Stdout capture via `mktemp()` (Julia 1.12 compat). Covers FAVAR, SDFM, structural breaks, panel unit root, Bayesian DSGE, regression (OLS/IV/logit/probit), advanced unit root (Fourier ADF/KPSS, DF-GLS, LM, ADF 2-break, Gregory-Hansen), VIF, LP-DiD (LPDiDResult API), panel regression (FE/RE/pooled, IV, logit/probit), ordered/multinomial choice models, spectral analysis (ACF, periodogram, density, cross, transfer), DSGE HD (frequentist + Bayesian), data dropna/keeprows, panel diagnostics (Hausman, Breusch-Pagan, Pesaran CD, etc.) handlers.

Run: `julia --project -e 'using Pkg; Pkg.test()'` or `julia --project test/runtests.jl`

## Adding a New Command

### Adding a new model to an existing action
1. Add a `LeafCommand` in the appropriate `src/commands/action.jl`
2. Define handler `_estimate_mymodel(; data::String, ...options)` following `_action_model` pattern
3. Add mock type in `test/mocks.jl` and tests in `test/test_commands.jl`

### Adding a new top-level action
1. Create `src/commands/myaction.jl` with `register_myaction_commands!()` → `NodeCommand`
2. Define handler: `load_data` → `df_to_matrix` → MacroEconometricModels call → `output_result`
3. In `src/Friedman.jl`: add `include("commands/myaction.jl")` and register in `build_app()`
4. Add tests in `test/test_commands.jl` using mocks

## Common Options (all commands)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--format` | `-f` | String | `"table"` | table\|csv\|json |
| `--output` | `-o` | String | `""` | Export file path (empty = stdout) |
| `--lags` | `-p` | Int | varies | Lag order (often auto via AIC) |
| `--config` | — | String | `""` | TOML config file path |
| `--plot` | — | Flag | `false` | Open interactive D3.js plot in browser (irf/fevd/hd/forecast/filter/dsge/estimate vol+factor) |
| `--plot-save` | — | String | `""` | Save interactive plot to HTML file (same commands as --plot) |
| `--warranty` | — | Flag | `false` | Display GPL warranty disclaimer |
| `--conditions` | — | Flag | `false` | Display GPL distribution conditions |

## MacroEconometricModels.jl API Reference

See [`docs/API_REFERENCE.md`](docs/API_REFERENCE.md) for full types and functions (350+ exports, 22+ domains).

## Upstream Docs & CI/CD

Full docs: https://chung9207.github.io/MacroEconometricModels.jl/dev/
Not wrapped: `compare_var_lp`, `unit_root_summary`, `test_all_variables` (convenience utilities).

- **CI:** GitHub Actions on push/PR — Julia 1.12 + latest on Ubuntu/macOS/Windows
- **Docs:** auto-deployed to GitHub Pages via Documenter.jl on push to main
- **Coverage:** Codecov integration, threshold 1%
