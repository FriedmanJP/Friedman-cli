# dsge

DSGE modeling from the terminal. Representative-agent leaves (`solve`, `irf`, `fevd`, `hd`, `simulate`, `estimate`, `perfect-foresight`, `steady-state`), a `bayes` node (13 sub-leaves), plus heterogeneous-agent / OLG nodes:

| Node | Role | Guide |
|------|------|--------|
| (top-level leaves) | Linear / nonlinear RA-DSGE, OccBin, estimation | this page |
| `dsge bayes` | Full Bayesian RA-DSGE workflow | [Bayesian DSGE](#dsge-bayes) |
| `dsge ha` | Incomplete-markets HA-DSGE (builtins + `HADSGESpec`) | **[HA-DSGE workflow](ha-dsge.md)** |
| `dsge ct` | Continuous-time Aiyagari / two-asset KMV | [CT section](#continuous-time-ha-dsge-ct--c041) |
| `dsge olg` | Blanchard perpetual-youth OLG | [OLG section](#blanchard-olg-dsge-olg--c041) |

**`dsge ha estimate`** (v0.6.0) — Bayesian estimation of HA-DSGE parameters via RWMH, shipped once [MEMs#228](https://github.com/FriedmanJP/MacroEconometricModels.jl/issues/228) fixed the Kalman observation matrix. See the [HA-DSGE workflow guide](ha-dsge.md#6-bayesian-estimation).

Friedman supports RA models as TOML or Julia (`DSGESpec`) files, and HA models as builtins or `.jl` (`HADSGESpec`). See [Configuration](../configuration.md#dsge-model) for TOML format details. Option tables: [generated `dsge` reference](generated/dsge.md).

## Model Input Formats

### TOML (`.toml`)

The model is defined in the `[model]` section with `endogenous`, `exogenous`, `parameters`, and `[[model.equations]]` entries. Set `linear = true` for pre-linearized models (variables are deviations from steady state). An optional `[solver]` section specifies the solution method. Equations are written in MEMs' `@dsge` syntax — index every variable by time (`x[t]`, `x[t-1]`, `x[t+1]`); `x[t+1]` is `E_t x_{t+1}`. The `E[t](...)` operator was removed at MEMs 0.9.0 and is a typed `config/invalid` (exit 4) on both `.toml` and `.jl` — there is no auto-rewrite. The CLI feeds the equations to the `@dsge` macro to build the spec.

```toml
[model]
endogenous = ["y", "c", "k", "n"]
exogenous = ["eps_a"]
# linear = true

[model.parameters]
alpha = 0.36
beta = 0.99
delta = 0.025
sigma = 1.0
phi_n = 1.0

[[model.equations]]
expr = "c[t]^(-sigma) = beta * c[t+1]^(-sigma) * (alpha * exp(eps_a[t+1]) * k[t]^(alpha-1) * n[t+1]^(1-alpha) + 1 - delta)"

[[model.equations]]
expr = "phi_n * n[t]^phi_n = c[t]^(-sigma) * (1-alpha) * exp(eps_a[t]) * k[t-1]^alpha * n[t]^(-alpha)"

[[model.equations]]
expr = "k[t] = (1-delta)*k[t-1] + y[t] - c[t]"

[[model.equations]]
expr = "y[t] = exp(eps_a[t]) * k[t-1]^alpha * n[t]^(1-alpha)"

[solver]
method = "gensys"
order = 1
```

### Julia Script (`.jl`)

The file's **last expression** must evaluate to a `DSGESpec` — typically an `@dsge begin … end` block. The CLI evaluates the file in a sandbox that already imports MEMs, so you may use `@dsge`/`DSGESpec` unqualified (an explicit `using MacroEconometricModels` is harmless but not required):

```julia
@dsge begin
    parameters: rho = 0.9, sigma = 0.01
    endogenous: y, c
    exogenous: eps
    # linear: true   # optional — pre-linearized (deviations from SS)

    y[t] = rho * y[t-1] + sigma * eps[t]
    c[t] = y[t]
end
```

The CLI auto-detects the format by file extension. (A `.jl` file that evaluates to an `HADSGESpec` is rejected with a pointer to `dsge ha …`.)

## dsge solve

Solve a DSGE model. Supports 5 solution methods and OccBin occasionally binding constraints.

```bash
friedman dsge solve rbc.toml
friedman dsge solve rbc.toml --method=perturbation --order=2
friedman dsge solve rbc.toml --method=perturbation --order=3
friedman dsge solve rbc.toml --method=projection --degree=7 --grid=chebyshev
friedman dsge solve rbc.toml --constraints=occbin.toml --periods=60
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | `gensys`, `klein`, `perturbation`, `projection`, `pfi` |
| `--order` | | Int | 1 | Perturbation order (`1`, `2`, or `3`) |
| `--degree` | | Int | 5 | Polynomial degree (projection/pfi) |
| `--grid` | | String | `auto` | Grid type: `auto`, `chebyshev`, `smolyak` |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--periods` | | Int | 40 | Number of periods for OccBin simulation |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output (standard):** Policy function matrices. Format depends on solution method — `DSGESolution` shows G1 policy matrix, `PerturbationSolution` shows gx control-state policy, `ProjectionSolution` shows coefficients with convergence diagnostics.

**Output (OccBin):** Piecewise-linear transition path for all endogenous variables.

**Determinacy verdict (W12/#114).** Every solve that produces a solution carrying the Sims `eu` pair also emits a **Determinacy Verdict** table: `existence | uniqueness | verdict | solver`. As in [`dsge determinacy-map`](#dsge-determinacy-map), the pair is reported rather than collapsed into a single boolean — `existence = 0` (no stable equilibrium exists) and `uniqueness = 0` (equilibria exist but are not unique) call for different changes to the model. Anything other than a determinate verdict is also flagged on stderr.

See [Configuration](../configuration.md#occbin-constraints) for the OccBin constraints TOML format.

## dsge irf

Impulse response functions from a solved DSGE model.

```bash
friedman dsge irf rbc.toml --horizon=40
friedman dsge irf rbc.toml --shock-size=0.5 --n-sim=1000
friedman dsge irf rbc.toml --constraints=occbin.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--horizon` | `-h` | Int | 40 | IRF horizon |
| `--shock-size` | | Float64 | 1.0 | Shock size (std devs) |
| `--n-sim` | | Int | 0 | Simulation-based IRF draws (0 = analytical) |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output (standard):** Per-shock IRF tables with columns for each endogenous variable.

**Output (OccBin):** Per-variable tables comparing linear vs piecewise-linear IRFs.

## dsge fevd

Forecast error variance decomposition from a solved DSGE model.

```bash
friedman dsge fevd rbc.toml --horizon=40
friedman dsge fevd rbc.toml --method=perturbation --order=2
friedman dsge fevd rbc.toml --method=perturbation --order=2 --unconditional
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order (`1`, `2`, or `3`) |
| `--horizon` | `-h` | Int | 40 | FEVD horizon (ignored for asymptotic `--unconditional`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--unconditional` | | Flag | | Unconditional (asymptotic) FEVD via Andreasen et al. (2018); requires `--method=perturbation` and `--order` ≥ 2 |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable FEVD proportions table (columns = shocks, rows = horizons). With `--unconditional`, horizon is asymptotic (H=1).

## dsge hd

Historical decomposition from a solved DSGE model.

```bash
friedman dsge hd rbc.toml --horizon=40
friedman dsge hd rbc.toml --method=perturbation --order=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--horizon` | `-h` | Int | 40 | HD horizon |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable historical decomposition tables (columns = shocks, rows = time periods).

## dsge simulate

Simulate from a solved DSGE model.

```bash
friedman dsge simulate rbc.toml --periods=500 --burn=200
friedman dsge simulate rbc.toml --seed=42 --antithetic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--periods` | | Int | 200 | Simulation periods (after burn-in) |
| `--burn` | | Int | 100 | Burn-in periods to discard |
| `--seed` | | Int | 0 | Random seed (0 = no seed) |
| `--antithetic` | | Flag | | Use antithetic sampling for variance reduction |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Simulated data table with a column per endogenous variable, periods after burn-in.

## dsge moments

Closed-form theoretical moments of a solved model at perturbation order 1, 2 or 3. Simulation-free: at order ≥ 2 these come from the pruned state-space recursion (Andreasen, Fernández-Villaverde & Rubio-Ramírez 2018), not from a long simulation, so they are exact rather than Monte-Carlo.

```bash
friedman dsge moments rbc.toml                            # order 2 (default)
friedman dsge moments rbc.toml --order=2 --lags=4
friedman dsge moments rbc.toml --order=3 --lags=8 -f json
```

!!! note "`--order 1` supported since v0.9.2"
    Order 1 was refused through v0.9.1: upstream's order-1 analytical moments dropped the contemporaneous shock term from the state↔control covariance, reporting `corr(z, y)` as **ρ instead of 1.0** on an exactly-scaled control and control autocorrelations as **ρ^(k+2) instead of ρ^k** ([issue #116](https://github.com/FriedmanJP/Friedman-cli/issues/116), fixed upstream in MEMs 0.7.3 as [MEMs#607](https://github.com/FriedmanJP/MacroEconometricModels.jl/issues/607)). The re-enabled path is proven by a closed-form AR(1) integration test asserting exactly those numbers. `--order 2` remains the default — for a linear model it reproduces the first-order moments precisely, and at higher order the risk-adjusted mean is the headline result.

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `perturbation` | Solution method (moments need a perturbation solution) |
| `--order` | | Int | 2 | Perturbation order: 1, 2 or 3 (see note above) |
| `--lags` | | Int | 1 | Autocovariance lags to report (≥ 1) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** three tables.

* **DSGE Theoretical Moments** — `variable | steady_state | mean | mean_minus_ss | std_dev`
* **Variance-Covariance** — `variable1 | variable2 | covariance | correlation` (upper triangle)
* **Autocovariances** — `variable | lag | autocovariance | autocorrelation`

`mean_minus_ss` is the column to look at. For a linear model it is identically zero — the certainty-equivalent mean *is* the steady state. For a nonlinear model at order ≥ 2 it is the **risk correction**: precautionary behaviour shifts the ergodic mean away from the deterministic steady state, and that shift is precisely what a higher-order solve buys you. Reporting the mean beside the steady state makes it visible rather than leaving it to be re-derived.

!!! note "Augmented models"
    Specs that the parser augments (to handle leads/lags beyond one period) report moments over the **original** variables only, and the labels are filtered to match. A moment table that silently used the augmented variable order would attribute every number to the wrong variable.

There is deliberately **no `--pruned` switch**. Upstream's simulation of a perturbation solution is *always* pruned (Kim, Kim, Schaumburg & Sims 2008) and exposes no unpruned path, so a flag would advertise a choice that does not exist. `dsge simulate --order 2|3` is likewise pruned.

## dsge determinacy-map

Sweep one or two parameters and record the Blanchard–Kahn/Sims determinacy verdict at each grid point. Answers "over what region of the parameter space does this model have a unique stable equilibrium?" — the Taylor principle being the textbook case.

The sweep is config-driven, because it is two parameter names plus grids plus a resolution — past the point where flags stay readable.

```toml
# determinacy.toml
[determinacy]
params = ["phi_pi", "phi_y"]     # 1 or 2 parameter names
lower  = [0.0, 0.0]
upper  = [3.0, 1.0]
points = [61, 41]
# optional
method = "gensys"                # gensys | klein | blanchard-kahn
div    = 1.00000001              # stable/unstable eigenvalue boundary
```

```bash
friedman dsge determinacy-map nk.toml --config=determinacy.toml
friedman dsge determinacy-map nk.toml --config=determinacy.toml --threaded --plot
```

`grids = [[...], [...]]` supplies explicit grid values instead of `lower`/`upper`/`points`. A scalar is accepted wherever a one-element list would do.

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | (required) | TOML with a `[determinacy]` section |
| `--rank-rtol` | | Float64 | 1e-8 | Relative tolerance of the Sims rank tests |
| `--threaded` | | Flag | | Evaluate grid points on all threads (results identical to the serial sweep) |
| `--verbose-solver` | | Flag | | Do **not** suppress per-grid-point solver warnings |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive heatmap in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** a tidy long table with one row per grid cell — `<param1> | [<param2>] | verdict | label | existence | uniqueness` — plus a **Determinacy Region Summary** (`n_determinate`, `n_indeterminate`, `n_no_solution`, `n_failed`, `method`, `div`), and for a one-parameter sweep a **Determinacy Boundary** table.

Verdict codes and their labels:

| `verdict` | `label` | `existence` | `uniqueness` | Meaning |
|-----------|---------|-------------|--------------|---------|
| `1` | determinate | 1 | 1 | Unique stable equilibrium |
| `0` | indeterminate | 1 | 0 | Stable equilibria exist but are not unique (sunspots) |
| `-1` | no solution | 0 | — | No stable equilibrium exists |
| `-2` | failed | -1 | -1 | The model could not be solved at this point |

**The raw `existence`/`uniqueness` pair is reported, not just the collapsed verdict**, because `existence = 0` and `uniqueness = 0` are different diagnoses with different fixes — no stable equilibrium at all, versus sunspot indeterminacy — and an agent should not have to re-derive which one it hit.

`failed` cells are counted separately and warned about on stderr. A grid point that would not solve is a **hole in the sweep, not a fourth region**: treating it as indeterminacy would invent a frontier out of a numerical gap. For the same reason the boundary calculation skips any pair involving a failed point.

The boundary is located to the resolution of the grid — refine `points` to sharpen it. For a two-parameter sweep no boundary table is emitted, since the frontier is a curve rather than a set of points; read the map (or plot it).

## dsge estimate

Estimate DSGE model parameters from data. 4 estimation methods.

```bash
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --method=irf_matching
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --method=smm --sim-ratio=10
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --method=likelihood
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --bounds=bounds.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--data` | `-d` | String | (required) | Path to CSV data file |
| `--method` | | String | `irf_matching` | `irf_matching`, `likelihood`, `bayesian`, `smm` |
| `--params` | | String | (required) | Comma-separated parameter names to estimate |
| `--solve-method` | | String | `gensys` | DSGE solution method |
| `--solve-order` | | Int | 1 | Perturbation order for solution |
| `--weighting` | | String | `optimal` | `identity`, `optimal`, `diagonal` |
| `--irf-horizon` | | Int | 20 | IRF horizon for matching |
| `--var-lags` | | Int | 4 | VAR lags for empirical IRF |
| `--sim-ratio` | | Int | 5 | Simulation-to-data ratio (SMM) |
| `--bounds` | | String | | Path to parameter bounds TOML |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates with standard errors, t-statistics, and p-values. Includes J-statistic and convergence status.

## dsge perfect-foresight

Perfect foresight (deterministic) simulation for transition paths.

```bash
friedman dsge perfect-foresight rbc.toml --shocks=shocks.csv --periods=200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--shocks` | | String | (required) | Path to shock sequence CSV |
| `--periods` | | Int | 100 | Simulation periods |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--prefilter` | | String | `none` | `none`, `demean`, `first-difference`, `linear-detrend`, `hp` — observable transform applied before estimation |
| `--hp-lambda` | | Float64 | 1600.0 | HP smoothing parameter, `--prefilter hp` only |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

#### Trending observables (`--prefilter`)

A DSGE model is solved in stationary deviations from steady state, but macro data is not stationary. `--prefilter` reconciles the two by transforming the observables before the Kalman filter sees them — Dynare's `prefilter`.

| Mode | What it removes |
|------|-----------------|
| `none` | Nothing (default). Correct only if your observables are *already* stationary deviations |
| `demean` | Each observable's sample mean |
| `first-difference` | `Δyₜ = yₜ − yₜ₋₁`; **drops the first observation** |
| `linear-detrend` | The OLS fit on `[1, t]`, per observable |
| `hp` | The Hodrick–Prescott trend, keeping the cycle. `--hp-lambda` is 1600 quarterly, 129600 monthly, 6.25 annual |

Two things worth knowing:

* The option is on **every `dsge bayes` leaf that estimates**, not just `bayes estimate`. The CLI is stateless, so each leaf re-estimates from scratch — a prefilter available only on `bayes estimate` could not be carried into `bayes irf`/`fevd`/`hd`, and those results would silently come from a differently-specified estimate.
* It is **not** available on the frequentist `dsge estimate`. `estimate_dsge` upstream takes no prefilter argument, and declaring an option the handler cannot honour would fail on every invocation. If you need prefiltering, use the Bayesian path or transform the CSV first (`data transform`).

`--hp-lambda` under any mode other than `hp` is a typed usage error rather than a silent no-op.
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

The shock CSV must have columns matching the model's exogenous variables and rows for each shock period.

**Output:** Transition path for all endogenous variables, with convergence status.

## dsge steady-state

Compute the steady state of a DSGE model.

```bash
friedman dsge steady-state rbc.toml
friedman dsge steady-state rbc.toml --constraints=occbin.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Variable names and steady-state values.

## dsge bayes

Bayesian DSGE workflow. `bayes` is a **nested command group** with 15 sub-leaves: `estimate`, `irf`, `fevd`, `hd`, `simulate`, `summary`, `compare`, `predictive`, plus five diagnostics (C073) — `mcmc-diag`, `identification`, `learning-rate`, `overlap`, `marginal-lik`. All share common options for model specification, data, parameters, and priors (`identification` is the exception — it runs no MCMC and takes only `--params`/`--observables`/`--solver`/`--order`/`--n-lags`).

### Common Options (all dsge bayes sub-commands)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--data` | `-d` | String | (required) | Path to CSV data file |
| `--params` | | String | (required) | Comma-separated parameter names to estimate |
| `--priors` | | String | (required) | Path to priors TOML file |
| `--method` | | String | `smc` | `smc`, `rwmh`, `csmc`, `smc2`, `importance` |
| `--n-draws` | | Int | 10000 | Posterior draws |
| `--burnin` | | Int | 5000 | Burn-in draws |
| `--n-particles` | | Int | 500 | Particle filter particles (smc2) |
| `--solver` | | String | `gensys` | `gensys`, `klein`, `perturbation` |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

!!! note "`--params` and `--priors`"
    The `--params` names must match the parameter keys in the `[priors]` TOML.
    Start values are passed to MacroEconometricModels as a name→value mapping, so
    the order of `--params` is immaterial and never silently realigned against the
    (internally sorted) prior keys (MEMs #136). A name in `--params` with no
    matching prior is rejected.

### dsge bayes estimate

Bayesian DSGE posterior estimation.

```bash
friedman dsge bayes estimate rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml
friedman dsge bayes estimate rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --method=rwmh --n-draws=20000
```

**Output:** Posterior summary table (mean, median, std, CI per parameter) + log marginal likelihood.

### dsge bayes irf

Bayesian DSGE impulse responses with posterior uncertainty.

```bash
friedman dsge bayes irf rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --horizon=40 --n-draws=200
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--horizon` | Int | 40 | IRF horizon |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes fevd

Bayesian DSGE forecast error variance decomposition.

```bash
friedman dsge bayes fevd rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --horizon=40
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--horizon` | Int | 40 | FEVD horizon |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes hd

Bayesian DSGE historical decomposition with posterior uncertainty.

```bash
friedman dsge bayes hd rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --horizon=40
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--horizon` | Int | 40 | HD horizon |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes simulate

Simulate from the posterior of a Bayesian DSGE.

```bash
friedman dsge bayes simulate rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --periods=200
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--periods` | Int | 100 | Simulation periods |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes summary

Detailed posterior summary statistics.

```bash
friedman dsge bayes summary rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml
```

**Output:** Posterior table (mean, median, std, 68%/90% CI).

### dsge bayes compare

Compare two Bayesian DSGE models via Bayes factors and marginal likelihoods.

```bash
friedman dsge bayes compare model1.toml --data=macro.csv --params=rho,sigma --priors=priors.toml \
    --model2=model2.toml --params2=rho2,sigma2 --priors2=priors2.toml
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--model2` | String | (required) | Path to second model file |
| `--params2` | String | (required) | Parameters for second model |
| `--priors2` | String | (required) | Priors TOML for second model |

**Output:** Bayes factor, marginal likelihoods for both models, posterior odds.

### dsge bayes predictive

Posterior predictive checks.

```bash
friedman dsge bayes predictive rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --n-sim=100
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--n-sim` | Int | 100 | Predictive simulations |
| `--periods` | Int | 100 | Simulation periods |

**Output:** Predictive summary (mean, std) vs observed data moments.

### dsge bayes mcmc-diag

Per-parameter MCMC convergence diagnostics on the retained posterior draws: rank-normalized split-R̂, bulk/tail effective sample size (Vehtari et al. 2021), and the Geweke (1992) z-statistic. Values of R̂ ≲ 1.01 and ESS ≥ 400 indicate convergence.

```bash
friedman dsge bayes mcmc-diag rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml
```

**Output:** Table `parameter | rhat | ess_bulk | ess_tail | geweke_z | geweke_p` + a summary (`n_draws`, `method`). SMC/importance draws are weighted particle systems (not chains) — autocorrelation-based quantities are approximate and a note is emitted on stderr.

### dsge bayes identification

Iskrev (2010) local-identification rank test at the steady state. Builds the Jacobian of the observables' steady-state means and autocovariances (lags `1..n-lags`) with respect to the estimated parameters and inspects its column rank via SVD — the parameters are locally identified iff the Jacobian has full column rank. **No MCMC and no data/priors** are needed.

```bash
friedman dsge bayes identification rbc.toml --params=alpha,beta --observables=Y,C --n-lags=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--params` | | String | (required) | Comma-separated estimated parameter names |
| `--observables` | | String | (all endogenous) | Observed variable names |
| `--solver` | | String | `gensys` | `gensys`, `klein`, `perturbation` |
| `--order` | | Int | 1 | Perturbation order |
| `--n-lags` | | Int | 2 | Autocovariance lags in the Iskrev moment vector |

**Output:** Summary kv (`rank`, `n_params`, `n_moments`, `n_lags`, `identified`, `tol`) + a `index | singular_value` table.

### dsge bayes learning-rate

Koop-Pesaran-Smith (2013) posterior-variance learning-rate check. Re-estimates on nested subsamples `⌊f·T⌋` and regresses `log(posterior variance)` on `log T`; for an identified parameter the slope `α ≈ 1` (the posterior variance shrinks at the `1/T` rate), while a weakly identified parameter barely updates (`α ≈ 0`, flagged).

```bash
friedman dsge bayes learning-rate rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --fractions=0.5,1.0 --refit-n-smc=100
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--fractions` | String | `0.5,1.0` | Nested subsample fractions in (0,1] (≥ 2 values) |
| `--threshold` | Float64 | 0.2 | Flag threshold on the learning rate α |
| `--refit-n-smc` | Int | 100 | SMC particles per subsample refit |

**Output:** Table `parameter | learning_rate | flagged` + a summary (`threshold`, `sample_sizes`). This is a Monte Carlo screening device — expect noise in `α`.

### dsge bayes overlap

Prior/posterior overlap coefficient `∫ min(π(θᵢ), p(θᵢ|Y)) dθᵢ ∈ [0,1]` per parameter. An overlap near 1 means the data barely moved the prior — the practical symptom of weak identification (flagged at `≥ --threshold`).

```bash
friedman dsge bayes overlap rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --threshold=0.8
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--threshold` | Float64 | 0.8 | Flag threshold on the overlap |
| `--n-grid` | Int | 0 | Histogram bins (0 = auto ≈ √N) |

**Output:** Table `parameter | overlap | flagged` + a summary (`threshold`).

### dsge bayes marginal-lik

Marginal likelihood via bridge sampling (Meng-Wong 1996; Gronau et al. 2017) from the stored posterior draws — markedly more stable than the modified harmonic mean. The additive constant matches the SMC tempering-path estimate, so the two are directly comparable.

```bash
friedman dsge bayes marginal-lik rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml --proposal=normal
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--proposal` | String | `normal` | Bridge proposal family: `normal` or `t` |
| `--df` | Float64 | 5.0 | Degrees of freedom for the `t` proposal |

**Output:** Summary kv `log_marginal_likelihood_bridge`, `log_marginal_likelihood_smc` (for comparison), `proposal`, `df`. Bridge sampling returns `NaN` (rendered as such, never a silently wrong number) when the chain is too short or the proposal too diffuse.

### Priors TOML Format

```toml
[priors.alpha]
dist = "beta"
a = 2.0
b = 5.0

[priors.beta]
dist = "normal"
a = 0.99    # mean
b = 0.01    # std

[priors.sigma]
dist = "inverse_gamma"
a = 2.0
b = 0.1
```

Each parameter must have a `dist` key (distribution name) and shape parameters `a`, `b`.

## Solution Methods

| Method | `--method` value | When to use |
|--------|-----------------|-------------|
| Gensys (Sims 2002) | `gensys` | Default. Linear rational expectations models |
| Klein (2000) | `klein` | Alternative generalized Schur decomposition solver |
| Perturbation | `perturbation` | Higher-order approximations (order 1, 2, or 3) |
| Projection | `projection` | Global solutions, nonlinear models, accuracy matters |
| Policy Function Iteration | `pfi` | Global solutions, value function problems |

Projection and PFI methods support `--degree` (polynomial degree) and `--grid` (grid type) options.

## HA-DSGE (`dsge ha`) — C040 / MEMs v0.6.7

Heterogeneous-agent DSGE: **builtins** (`huggett`, `krusell-smith`, `one-asset-hank`, `two-asset-hank`) or a `.jl` file evaluating to `HADSGESpec`.

**Methods:** `ssj` · `reiter` · `krusell-smith`

`dsge ha estimate` (RWMH Bayesian estimation) shipped in v0.6.0 after MEMs#228. Full progressive examples with captured JSON: **[HA-DSGE workflow guide](ha-dsge.md)**.

```bash
friedman dsge ha steady-state huggett
friedman dsge ha solve huggett --method=reiter --n-reduced=20
friedman dsge ha irf huggett --method=reiter --horizon=40
friedman dsge ha estimate krusell-smith --data aggregates.csv --priors priors.toml --observables K
friedman dsge ha distribution-irf huggett --method=reiter   # Reiter only
friedman dsge ha simulate-panel huggett --n-agents=1000 --seed=1
```

| Subcommand | Method constraint | Notes |
|------------|-------------------|-------|
| `solve` | ssj \| reiter \| krusell-smith | KS returns PLM coefficients, not G1 |
| `steady-state` | — | Stationary equilibrium |
| `irf` / `fevd` / `simulate` | ssj \| reiter | Aggregate linear system |
| `distribution-irf` | reiter | Wealth distribution mass deviations |
| `inequality-irf` | reiter | Gini + p10…p90 paths |
| `simulate-panel` | — | Summary mean/sd assets over time |

## Continuous-time HA (`dsge ct`) — C041

Continuous-time Aiyagari equilibrium and MIT-shock transitions. Optional `--two-asset` uses the Kaplan–Moll–Violante two-asset solver.

```bash
# Stationary equilibrium (smaller --grid-size for interactive work)
friedman dsge ct solve --grid-size=100
friedman dsge ct solve --two-asset

# MIT-shock perfect-foresight path (impact TFP = shock-size × z)
friedman dsge ct transition --periods=40 --shock-size=0.95 --dt=0.25
```

| Subcommand | API | Output tables |
|------------|-----|---------------|
| `solve` | `ct_steady_state` / `ct_two_asset_solve` | prices, aggregates |
| `transition` | `ct_mit_shock` | t, Z, K, r, w, C path |

## Blanchard OLG (`dsge olg`) — C041

Perpetual-youth OLG (Blanchard 1985). Debt `b ≠ 0` surfaces a soft note (MEMs #237 history).

```bash
friedman dsge olg solve
friedman dsge olg solve --debt=0.1 --gamma=0.98
friedman dsge olg simulate --horizon=50          # k0 defaults to 0.8 k*
friedman dsge olg simulate --k0=3.0 --horizon=40
```

| Subcommand | API | Output |
|------------|-----|--------|
| `solve` | `blanchard_solve` | steady state + saddle-path diagnostics |
| `simulate` | `blanchard_transition` | k, C, r, w path |
