# Friedman-cli v0.3.0 — MEMs v0.3.1 Integration Design

Date: 2026-03-03

## Overview

Integrate MacroEconometricModels.jl v0.3.1 into Friedman-cli v0.3.0. Primary addition: full DSGE module (7 CLI subcommands). Secondary: SMM estimation, VARForecast/BVARForecast typed returns, FFTW weak-dep migration, constrained solver dependencies.

## Scope

1. **New `dsge` top-level command group** — 7 subcommands
2. **New `estimate smm` leaf** — 18th estimation command
3. **Breaking change adaptations** — VARForecast/BVARForecast types, LPForecast field rename, BVAR posterior median default, FFTW extension
4. **New dependencies** — SparseArrays (direct), JuMP/Ipopt/PATHSolver (optional, conditionally imported)
5. **Config parser extensions** — DSGE model TOML, constraints TOML, SMM config
6. **Test mocks** — ~15 new mock types + functions
7. **CLAUDE.md update** — command tree, API reference, deps

## Command Tree

```
friedman dsge
├── solve              # Solve DSGE model (standard + OccBin via --constraints)
├── irf                # IRF (standard + OccBin via --constraints)
├── fevd               # FEVD
├── simulate           # Simulate time series from solved model
├── estimate           # Estimate params (4 methods)
├── perfect-foresight  # Perfect foresight transition path
└── steady-state       # Compute/display steady state

friedman estimate
├── ... (existing 17 leaves)
└── smm                # Simulated Method of Moments (NEW)
```

Total: 12 top-level commands, ~116 subcommands.

## DSGE Subcommand Options

### dsge solve

```
friedman dsge solve <model> [options]
  <model>          Path to .toml or .jl model file (required)
  --method         gensys|blanchard_kahn|klein|perturbation|projection|pfi (default: gensys)
  --order          Perturbation order: 1|2|3 (default: 1)
  --degree         Chebyshev degree (default: 5, projection/pfi only)
  --grid           tensor|smolyak|auto (default: auto, projection only)
  --constraints    Path to constraints TOML (enables OccBin solving)
  --periods        OccBin simulation periods (default: 40)
  --format/-f      table|csv|json
  --output/-o      Export file path
  --plot           Open interactive plot
  --plot-save      Save plot to HTML
```

### dsge irf

```
friedman dsge irf <model> [options]
  <model>          Path to .toml or .jl model file
  --method         Solver method (default: gensys)
  --order          Perturbation order (default: 1)
  --horizon        IRF horizon (default: 40)
  --shock-size     Shock size in std devs (default: 1.0)
  --n-sim          MC simulations for nonlinear IRFs (default: 500)
  --constraints    OccBin constraints TOML (enables piecewise-linear IRF)
  --format/-f, --output/-o, --plot, --plot-save
```

### dsge fevd

```
friedman dsge fevd <model> [options]
  <model>          Path to .toml or .jl model file
  --method         Solver method (default: gensys)
  --order          Perturbation order (default: 1)
  --horizon        FEVD horizon (default: 40)
  --format/-f, --output/-o, --plot, --plot-save
```

### dsge simulate

```
friedman dsge simulate <model> [options]
  <model>          Model file
  --method         Solver method (default: gensys)
  --order          Perturbation order (default: 1)
  --periods        Simulation length (default: 200)
  --burn           Burn-in periods (default: 100)
  --antithetic     Use antithetic shocks (flag, perturbation only)
  --seed           RNG seed
  --format/-f, --output/-o, --plot, --plot-save
```

### dsge estimate

```
friedman dsge estimate <model> [options]
  <model>          Model file
  --data/-d        Observed data CSV (required)
  --method         irf_matching|euler_gmm|smm|analytical_gmm (default: irf_matching)
  --params         Comma-separated parameter names to estimate (required)
  --solve-method   DSGE solver for estimation (default: gensys)
  --solve-order    Perturbation order (default: 1)
  --weighting      identity|optimal|two_step|iterated (default: two_step)
  --irf-horizon    For irf_matching (default: 20)
  --var-lags       VAR lags for target IRFs (default: 4)
  --sim-ratio      Simulation ratio for SMM (default: 5)
  --bounds         Bounds TOML for parameter transforms
  --format/-f, --output/-o
```

### dsge perfect-foresight

```
friedman dsge perfect-foresight <model> [options]
  <model>          Model file
  --shocks         Shock path CSV (required)
  --periods        Transition periods (default: 100)
  --format/-f, --output/-o, --plot, --plot-save
```

### dsge steady-state

```
friedman dsge steady-state <model> [options]
  <model>          Model file
  --constraints    Constraints TOML for constrained steady state
  --format/-f, --output/-o
```

### estimate smm

```
friedman estimate smm <data> [options]
  <data>           CSV file (required)
  --config         TOML with moment conditions + simulator spec
  --weighting      identity|optimal|two_step|iterated (default: two_step)
  --sim-ratio      Simulation-to-sample ratio (default: 5)
  --burn           Burn-in periods (default: 100)
  --format/-f, --output/-o
```

## Model Input Formats

### TOML model file (.toml)

```toml
[model]
parameters = { rho = 0.9, sigma = 0.01, beta = 0.99, alpha = 0.36, delta = 0.025 }
endogenous = ["C", "K", "Y", "A"]
exogenous = ["e_A"]

[[model.equations]]
expr = "C[t] + K[t] = (1-delta)*K[t-1] + Y[t]"
[[model.equations]]
expr = "Y[t] = A[t] * K[t-1]^alpha"
[[model.equations]]
expr = "1/C[t] = beta * E[t](1/C[t+1] * (alpha*A[t+1]*K[t]^(alpha-1) + 1-delta))"
[[model.equations]]
expr = "A[t] = rho * A[t-1] + sigma * e_A[t]"

[solver]
method = "gensys"

[constraints]
[[constraints.bounds]]
variable = "i"
lower = 0.0

[estimation]
method = "irf_matching"
params = ["rho", "sigma"]
```

### Julia model file (.jl)

```julia
using MacroEconometricModels
model = @dsge begin
    parameters: rho = 0.9, sigma = 0.01, beta = 0.99, alpha = 0.36, delta = 0.025
    endogenous: C, K, Y, A
    exogenous: e_A
    C[t] + K[t] = (1-delta)*K[t-1] + Y[t]
    Y[t] = A[t] * K[t-1]^alpha
    1/C[t] = beta * E[t](1/C[t+1] * (alpha*A[t+1]*K[t]^(alpha-1) + 1-delta))
    A[t] = rho * A[t-1] + sigma * e_A[t]
    steady_state = begin
        A_ss = 1.0
        K_ss = ((1/beta - 1 + delta) / (alpha * A_ss))^(1/(alpha-1))
        Y_ss = A_ss * K_ss^alpha
        C_ss = Y_ss - delta * K_ss
        [C_ss, K_ss, Y_ss, A_ss]
    end
end
```

CLI detects input format by file extension. `.jl` files are `include()`d and must define a `model` variable.

## Handler Flow

### dsge solve

```
model file (.toml or .jl)
  → _load_dsge_model(path) → DSGESpec
  → compute_steady_state(spec; constraints=...)
  → linearize(spec) → LinearDSGE
  → solve(spec; method, order, degree, grid, ...) → solution
  → if --constraints: occbin_solve(spec, shocks, constraints; T_periods)
  → output: eigenvalues, determinacy, stability, policy matrices
  → _maybe_plot()
```

### dsge irf

```
model file → _load_dsge_model() → DSGESpec
  → _solve_dsge(spec; method, order, ...) → solution
  → if --constraints: occbin_irf(spec, constraints, shock_idx; shock_size, horizon)
  → else: irf(solution, horizon; n_sim, shock_size) → ImpulseResponse
  → output_result(df)
  → _maybe_plot()
```

### dsge estimate

```
model file → _load_dsge_model() → DSGESpec
  → load_data(data_path) → DataFrame → Matrix
  → param_names = split(params, ",")
  → estimate_dsge(spec, Y, param_names; method, solve_method, solve_order,
      weighting, irf_horizon, var_lags, sim_ratio, bounds) → DSGEEstimation
  → output: coefficients, std errors, J-stat, p-value
```

## Breaking Changes Adaptation

### 1. VARForecast / BVARForecast typed returns

`forecast var` and `forecast bvar` handlers: use `point_forecast()`, `lower_bound()`, `upper_bound()`, `forecast_horizon()` accessors instead of raw matrix fields.

### 2. LPForecast field rename

`forecast lp` handler: `.forecasts` → `.forecast`.

### 3. FFTW weak dependency

`estimate gdfm` and related commands: if GDFM call fails due to missing FFTW, catch the error and print a clear message:
```
Error: GDFM requires FFTW.jl. Install with: julia -e 'using Pkg; Pkg.add("FFTW")'
```

### 4. BVAR posterior median default

No CLI change needed — MEMs now uses `posterior_median_model` by default. Our handlers pass through to MEMs, so this is automatic. Document the change.

## Dependencies

### Project.toml additions

```toml
[deps]
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"  # required by MEMs v0.3.1

[weakdeps]
FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
PATHSolver = "........-....-....-....-............"
```

At runtime, DSGE `--constraints` handler uses `try @eval import JuMP, Ipopt catch` to conditionally load extensions. If import fails, prints clear installation instructions.

### MEMs compat bump

```toml
[compat]
MacroEconometricModels = "0.3.1"
```

## New Files

| File | Purpose | Est. lines |
|------|---------|-----------|
| `src/commands/dsge.jl` | `register_dsge_commands!()` + 7 handlers | ~800 |

## Modified Files

| File | Changes |
|------|---------|
| `src/Friedman.jl` | `include("commands/dsge.jl")`, register in `build_app()` |
| `src/commands/estimate.jl` | Add `_estimate_smm` handler + SMM leaf |
| `src/commands/forecast.jl` | Adapt for VARForecast/BVARForecast, fix LPForecast.forecast |
| `src/commands/shared.jl` | Add `_load_dsge_model()`, `_solve_dsge()` helpers |
| `src/config.jl` | Add `get_dsge()`, `get_dsge_constraints()`, `get_smm()` |
| `Project.toml` | MEMs compat 0.3.1, new deps |
| `test/mocks.jl` | ~15 mock types + functions |
| `test/test_commands.jl` | Tests for all new/modified handlers |
| `CLAUDE.md` | Command tree, API reference, deps |

## Mock Types Needed

DSGE: `DSGESpec`, `LinearDSGE`, `DSGESolution`, `PerturbationSolution`, `ProjectionSolution`, `PerfectForesightPath`, `DSGEEstimation`, `OccBinConstraint`, `OccBinSolution`, `OccBinIRF`

GMM: `SMMModel`, `ParameterTransform`

VAR Forecast: `VARForecast`, `BVARForecast`

Mock functions: `compute_steady_state`, `linearize`, `solve`, `gensys`, `blanchard_kahn`, `klein`, `perturbation_solver`, `collocation_solver`, `pfi_solver`, `perfect_foresight`, `occbin_solve`, `occbin_irf`, `estimate_dsge`, `estimate_smm`, `simulate`, `solve_lyapunov`, `analytical_moments`, `point_forecast`, `lower_bound`, `upper_bound`, `forecast_horizon`, `parse_constraint`, `variable_bound`, `is_determined`, `is_stable`, `nshocks`

## Testing Strategy

- All DSGE handlers tested via mocks (no MEMs dependency)
- Each subcommand: success path + error cases (missing model file, invalid method, etc.)
- TOML model parsing: valid model, missing fields, malformed equations
- .jl model loading: valid file, missing `model` variable
- OccBin: --constraints flag enables OccBin path
- SMM: standard estimation flow test
- Forecast breaking changes: verify new accessor usage
- Estimated ~200 new test assertions
