# Friedman-cli v0.3.0 Documentation Update — Design

Date: 2026-03-03

## Overview

Full update of all 15 Documenter.jl source files + 1 new file to reflect v0.3.0 changes: DSGE module (7 subcommands), estimate smm, VARForecast/BVARForecast typed returns, LPForecast field rename, new dependencies, Julia 1.12 requirement.

## Scope

All files in `docs/src/` plus `docs/make.jl`. Reference-only style matching existing pages (no tutorials or theory sections).

## New File

### `docs/src/commands/dsge.md`

New command reference page for the `dsge` top-level command group. Structure:

1. **Intro** — DSGE modeling from the terminal, model input formats (.toml and .jl)
2. **Model Input Formats** — TOML example (RBC model), .jl example, how CLI detects format
3. **Subcommand reference** (7 sections):
   - `dsge solve` — options (method, order, degree, grid, constraints, periods), OccBin path, output description
   - `dsge irf` — options (horizon, shock-size, n-sim, constraints), standard vs OccBin IRFs
   - `dsge fevd` — options (horizon), per-variable output tables
   - `dsge simulate` — options (periods, burn, seed, antithetic), burn-in behavior
   - `dsge estimate` — options (data, method, params, solve-method, solve-order, weighting, irf-horizon, var-lags, sim-ratio, bounds), 4 estimation methods
   - `dsge perfect-foresight` — options (shocks, periods), shock CSV input requirement
   - `dsge steady-state` — options (constraints), constrained vs unconstrained
4. **Solution Methods** — table of methods (gensys, klein, perturbation, projection, pfi) with when to use each
5. **OccBin Constraints** — TOML format reference, link to configuration.md
6. **Examples** — bash examples for each subcommand

## Updated Files

### `docs/make.jl`

- Add `"dsge" => "commands/dsge.md"` to pages array (after nowcast)

### `docs/src/index.md`

- Add DSGE row to feature table: `| **DSGE** | Solve, IRF, FEVD, simulate, estimate, perfect foresight, steady state | dsge solve, dsge irf, ... |`
- Add SMM row: `| **SMM** | Simulated Method of Moments | estimate smm |`
- Update counts: "12 top-level commands, ~117 subcommands"
- Add `dsge` to Quick Start examples
- Add `commands/dsge.md` to Contents block

### `docs/src/installation.md`

- Julia 1.12+ (not 1.10+)
- Add note about optional dependencies: "For DSGE constrained solvers (OccBin), install JuMP and Ipopt. For GDFM spectral methods, install FFTW."

### `docs/src/commands/overview.md`

- Update command tree: add `dsge` row with 7 subcommands, add `smm` to estimate row
- Update counts: "12 top-level commands, ~117 subcommands"
- Add `dsge` to common options table if relevant

### `docs/src/commands/estimate.md`

- Add `estimate smm` section (after gmm): options (config, weighting, sim-ratio, burn, format, output), TOML config reference, example
- Update intro count: "18 estimation subcommands"

### `docs/src/commands/test.md`

- No v0.3.0 changes needed. Refresh for consistency: verify LR/LM interface matches current (data1/data2/lags1/lags2).

### `docs/src/commands/irf.md`

- No v0.3.0 changes for VAR/BVAR/LP/VECM/PVAR IRF pages. Add note: "For DSGE model IRFs, see [dsge irf](dsge.md#dsge-irf)."

### `docs/src/commands/fevd.md`

- Add cross-reference: "For DSGE model FEVD, see [dsge fevd](dsge.md#dsge-fevd)."

### `docs/src/commands/hd.md`

- No changes needed. No DSGE HD subcommand exists.

### `docs/src/commands/forecast.md`

- Add note about VARForecast/BVARForecast typed returns (v0.3.0): "VAR and BVAR forecasts now return typed VARForecast/BVARForecast objects with accessor functions: `point_forecast()`, `lower_bound()`, `upper_bound()`, `forecast_horizon()`."
- Note LPForecast field: `.forecast` (renamed from `.forecasts` in v0.3.0)
- Add cross-reference: "For DSGE model forecasting via simulation, see [dsge simulate](dsge.md#dsge-simulate)."

### `docs/src/commands/predict_residuals.md`

- No v0.3.0 changes. Refresh: verify model list matches current state.

### `docs/src/commands/filter.md`

- No v0.3.0 changes. Refresh: verify bn --method=statespace is documented.

### `docs/src/commands/data.md`

- No v0.3.0 changes. Refresh: verify 9 subcommands including balance.

### `docs/src/commands/nowcast.md`

- No v0.3.0 changes. Refresh for consistency.

### `docs/src/configuration.md`

- Add DSGE model TOML section (full RBC example with [model], [[model.equations]], [solver])
- Add OccBin constraints TOML section ([constraints], [[constraints.bounds]])
- Add SMM configuration section ([smm] with weighting, sim_ratio, burn)

### `docs/src/api.md`

- Add docstrings for new exported/internal functions:
  - `get_dsge`, `get_dsge_constraints`, `get_smm` (config.jl)
  - `_load_dsge_model`, `_solve_dsge`, `_load_dsge_constraints` (shared.jl)
  - `register_dsge_commands!` (dsge.jl)
  - DSGE handler functions (_dsge_solve, _dsge_irf, etc.)
  - `_estimate_smm` (estimate.jl)

### `docs/src/architecture.md`

- Update module structure: add dsge.jl (~410 lines, 7 leaves)
- Update shared.jl description: add _load_dsge_model, _solve_dsge, _load_dsge_constraints
- Update config.jl description: add get_dsge, get_dsge_constraints, get_smm
- Update estimate.jl: 18 leaves (was 17)
- Update dependencies: SparseArrays, Random (direct), FFTW/JuMP/Ipopt/PATHSolver (weak)
- Update MEMs compat: 0.3.1
- Update Julia compat: 1.12
- Update total: 12 top-level commands, ~117 subcommands, ~8,200 lines across 18 source files

## File Count Summary

- 1 new file: `docs/src/commands/dsge.md`
- 15 updated files: `make.jl` + all 14 `docs/src/*.md` files
- Estimated new content: ~300 lines (dsge.md), ~150 lines updates across other files
