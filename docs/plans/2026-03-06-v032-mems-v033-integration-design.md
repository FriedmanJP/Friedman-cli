# Design: Friedman-cli v0.3.2 — MEMs v0.3.3 Adoption

**Date:** 2026-03-06
**Scope:** 17 new subcommand leaves + 1 existing enhancement across 6 feature areas
**Version:** v0.3.2 (Friedman-cli), MEMs compat v0.3.3
**Subcommands:** ~124 → ~141

## Feature Areas

### 1. FAVAR (7 new leaves)

Full action coverage matching var/bvar/vecm pattern.

| Command | Handler | MEMs call |
|---------|---------|-----------|
| `estimate favar` | `_estimate_favar` | `estimate_favar(X, Y_key, r, p)` |
| `irf favar` | `_irf_favar` | `irf(favar, h)` + `favar_panel_irf(favar, irf_result)` |
| `fevd favar` | `_fevd_favar` | `fevd(favar, h)` |
| `hd favar` | `_hd_favar` | `historical_decomposition(favar, h)` |
| `forecast favar` | `_forecast_favar` | `forecast(favar, h)` + `favar_panel_forecast(favar, fc)` |
| `predict favar` | `_predict_favar` | `predict(favar)` via `to_var` |
| `residuals favar` | `_residuals_favar` | `residuals(favar)` via `to_var` |

**Options:** `--factors` (r), `--lags` (p), `--key-vars` (comma-separated), `--method=two_step|bayesian`, `--draws` (Bayesian), `--id` (IRF identification), `--panel-irf` flag (N-dim panel IRFs via loadings), `--config`, standard format/output/plot.

**shared.jl:** `_load_and_estimate_favar(data, factors, lags, key_vars, method, draws)` helper.

### 2. Structural DFM (3 new leaves)

Separate from existing gdfm. Cholesky/sign identification on GDFM + factor VAR.

| Command | Handler | MEMs call |
|---------|---------|-----------|
| `estimate sdfm` | `_estimate_sdfm` | `estimate_structural_dfm(X, q; identification, p, H, sign_check)` |
| `irf sdfm` | `_irf_sdfm` | `irf(sdfm, h)` — pre-computed panel IRFs |
| `fevd sdfm` | `_fevd_sdfm` | `fevd(sdfm, h)` |

**Options:** `--factors` (q), `--id=cholesky|sign`, `--var-lags` (p), `--config` (sign restrictions), `--bandwidth`, `--kernel`, standard format/output/plot.

### 3. Bayesian DSGE (1 new leaf)

New `dsge bayes` subcommand, separate from existing `dsge estimate` point estimation.

| Command | Handler | MEMs call |
|---------|---------|-----------|
| `dsge bayes` | `_dsge_bayes` | `estimate_dsge_bayes(spec, data, θ0; priors, method, ...)` |

**Options:** `<model>` positional, `--data`, `--params`, `--priors` (TOML), `--sampler=smc|smc2|mh`, `--n-smc` (5000), `--n-particles` (500), `--n-draws` (10000), `--burnin` (5000), `--ess-target` (0.5), `--observables` (comma-separated), `--solver=gensys|klein|perturbation`, `--delayed-acceptance` flag, `--order` (1/2/3).

**Output:** Posterior summary table (param, mean, std, 5%, 50%, 95%), log marginal likelihood, acceptance rate, ESS.

**Priors TOML:**
```toml
[priors]
rho = { dist = "beta", a = 0.5, b = 0.2 }
sigma = { dist = "inv_gamma", a = 2.0, b = 0.1 }
```

**config.jl:** Add `get_dsge_priors()` parser.

### 4. Structural Break Tests (2 new leaves)

| Command | Handler | MEMs call |
|---------|---------|-----------|
| `test andrews` | `_test_andrews` | `andrews_test(y, X; test, trimming)` |
| `test bai-perron` | `_test_bai_perron` | `bai_perron_test(y, X; max_breaks, trimming, criterion)` |

**Andrews options:** `--test=supwald|suplr|suplm|expwald|explr|explm|meanwald|meanlr|meanlm`, `--trimming` (0.15), `--response` (dependent var column).

**Bai-Perron options:** `--max-breaks` (5), `--trimming` (0.15), `--criterion=bic|lwz`, `--response`.

Both support `--plot`/`--plot-save`.

### 5. Panel Unit Root Tests (4 new leaves)

All accept `<data>` positional. Default: matrix (rows=T, cols=N). If `--id-col`/`--time-col` provided, load as PanelData.

| Command | Handler | MEMs call |
|---------|---------|-----------|
| `test panic` | `_test_panic` | `panic_test(X; r, method)` |
| `test cips` | `_test_cips` | `pesaran_cips_test(X; lags, deterministic)` |
| `test moon-perron` | `_test_moon_perron` | `moon_perron_test(X; r)` |
| `test factor-break` | `_test_factor_break` | `factor_break_test(X, r; method)` |

**Shared helper:** `_load_panel_or_matrix(data; id_col, time_col)` — returns `(data_for_mems, is_panel)`.

**PANIC:** `--factors=auto|N`, `--method=pooled|individual`.
**CIPS:** `--lags=auto|N`, `--deterministic=constant|trend`.
**Moon-Perron:** `--factors=auto|N`.
**Factor-break:** `--factors`, `--method=breitung_eickmeier|chen_dolado_gonzalo|han_inoue`.

### 6. 3rd-Order Perturbation (existing enhancement)

No new leaves. Update `dsge solve` to accept `--order=3`. Also available in `dsge bayes --order=3`.

## File Changes

| File | Changes |
|------|---------|
| `src/commands/shared.jl` | `_load_and_estimate_favar()`, `_load_panel_or_matrix()`, `_parse_priors_toml()` |
| `src/commands/estimate.jl` | +2 leaves (favar, sdfm) |
| `src/commands/irf.jl` | +2 leaves (favar, sdfm) |
| `src/commands/fevd.jl` | +2 leaves (favar, sdfm) |
| `src/commands/hd.jl` | +1 leaf (favar) |
| `src/commands/forecast.jl` | +1 leaf (favar) |
| `src/commands/predict.jl` | +1 leaf (favar) |
| `src/commands/residuals.jl` | +1 leaf (favar) |
| `src/commands/test.jl` | +6 leaves (andrews, bai-perron, panic, cips, moon-perron, factor-break) |
| `src/commands/dsge.jl` | +1 leaf (bayes), update solve order validation |
| `src/config.jl` | Add `get_dsge_priors()` |
| `src/Friedman.jl` | Bump FRIEDMAN_VERSION to v0.3.2 |
| `Project.toml` | Bump version, MEMs compat to 0.3.3 |
| `test/mocks.jl` | 10 new mock types + ~15 mock functions |
| `test/test_commands.jl` | Handler tests for all 17 new leaves |

## New Mock Types

`FAVARModel`, `BayesianFAVAR`, `StructuralDFM`, `BayesianDSGE`, `AndrewsResult`, `BaiPerronResult`, `PANICResult`, `PesaranCIPSResult`, `MoonPerronResult`, `FactorBreakResult`

## New MEMs Types (exported)

`FAVARModel{T}`, `BayesianFAVAR{T}`, `StructuralDFM{T}`, `BayesianDSGE{T}`, `AndrewsResult{T}`, `BaiPerronResult{T}`, `PANICResult{T}`, `PesaranCIPSResult{T}`, `MoonPerronResult{T}`, `FactorBreakResult{T}`

## New MEMs Functions (exported)

`estimate_favar`, `favar_panel_irf`, `favar_panel_forecast`, `estimate_structural_dfm`, `estimate_dsge_bayes`, `andrews_test`, `bai_perron_test`, `panic_test`, `pesaran_cips_test`, `moon_perron_test`, `factor_break_test`, `panel_unit_root_summary`

## Key Implementation Notes

- FAVAR delegates to internal VAR via `to_var(favar)` for predict/residuals/StatsAPI
- Panel IRFs via `favar_panel_irf` multiply loadings by factor-level IRFs (H × N × q)
- Structural DFM `irf()` returns pre-computed panel IRFs at estimation time
- Bayesian DSGE priors parsed from dedicated TOML section; DSGEPrior/SMCState/PFWorkspace are internal types (not exported)
- Panel unit root tests: `_load_panel_or_matrix()` branches on presence of `--id-col`
- 3rd-order perturbation: PerturbationSolution gains hxxx/gxxx/hσσx/gσσx/hσσσ/gσσσ fields (nothing if order < 3)
