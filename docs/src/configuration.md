# Configuration

Friedman uses TOML configuration files for complex model specifications. Pass them via the `--config` option.

Every `toml` block below is a **fragment**, not something to run: save it to a
file (e.g. `model.toml`) and pass it with `--config model.toml`. Only `bash`
blocks are runnable commands. Every key shown is read by a `get_*` parser in
`src/config.jl`; unknown keys warn (error under `--strict`). For command flags and defaults, see the [generated command reference](commands/overview.md).

---

## Minnesota Prior

Used by `estimate multivariate bvar`, `irf bvar`, `fevd bvar`, `hd bvar`, `forecast multivariate bvar`.

```toml
[prior]
type = "minnesota"

[prior.hyperparameters]
lambda1 = 0.2       # tau (overall tightness)
lambda2 = 0.5       # cross-variable shrinkage
lambda3 = 1.0       # lag decay
lambda4 = 100000.0  # constant term variance

[prior.optimization]
enabled = true       # auto-optimize hyperparameters via grid search
```

### Hyperparameters

| Parameter | Field | Description | Typical Range |
|-----------|-------|-------------|---------------|
| `lambda1` | `tau` | Overall tightness of the prior | 0.01 -- 1.0 |
| `lambda2` | `lambda` | Cross-variable shrinkage (how much other variables' lags matter) | 0.1 -- 1.0 |
| `lambda3` | `decay` | Lag decay rate (higher = faster decay of lag importance) | 0.5 -- 2.0 |
| `lambda4` | — | Accepted for backward compatibility but **not forwarded** — `mu` and `omega` keep MEMs' own defaults | — |

When `optimization.enabled = true`, Friedman ignores the manual hyperparameters and uses `optimize_hyperparameters()` to find optimal values via grid search over tau.

When optimization is disabled, `lambda1`/`lambda2`/`lambda3` map to MEMs' `tau`/`lambda`/`decay`; `mu` and `omega` are left at upstream defaults (`omega` is the replication weight of the `diag(σ̂)` residual-covariance dummy, default 1.0).

---

## Sign Restrictions

Used by `irf var`, `irf bvar`, `irf lp`, `fevd`, `hd` with `--id=sign`.

```toml
[identification]
method = "sign"

[identification.sign_matrix]
# Each row = variable, each column = shock
# 1 = positive, -1 = negative, 0 = unrestricted
matrix = [
  [1, -1, 1],
  [0, 1, -1],
  [0, 0, 1]
]
horizons = [0, 1, 2, 3]  # horizons at which restrictions apply (0-based)
```

The sign matrix dimensions must match the number of variables. Restrictions are checked at each specified horizon.

---

## Narrative Restrictions

Used with `--id=narrative`. Can be combined with sign restrictions.

```toml
[identification]
method = "narrative"

[identification.sign_matrix]
matrix = [[1, -1], [0, 1]]
horizons = [0]

[identification.narrative]
shock_index = 1              # which shock to constrain (1-based)
periods = [10, 15, 20]      # time periods where restrictions apply
signs = [1, -1, 1]          # required sign at each period
```

---

## Arias Identification

Arias et al. (2018) zero and sign restrictions. Used with `--id=arias`.

```toml
# Zero restrictions: variable-shock-horizon triples forced to zero
[[identification.zero_restrictions]]
var = 1
shock = 1
horizon = 0

[[identification.zero_restrictions]]
var = 1
shock = 2
horizon = "long_run"   # or an integer horizon; default 0

# Sign restrictions: variable-shock pairs with sign constraints
[[identification.sign_restrictions]]
var = 2
shock = 1
sign = "positive"      # positive | negative
horizon = 0

# ...or a horizon range (expands to one restriction per horizon)
[[identification.sign_restrictions]]
var = 3
shock = 2
sign = "negative"
horizons = [0, 4]
```

Multiple `[[identification.zero_restrictions]]` and `[[identification.sign_restrictions]]` blocks can be specified (TOML array of tables syntax).

---

## Uhlig Identification

Uhlig (Mountford & Uhlig 2009) penalty-based identification. Uses the same zero/sign restriction format as Arias, plus optional tuning parameters. Used with `--id=uhlig`.

```toml
# Uses same restriction format as Arias
[[identification.zero_restrictions]]
var = 1
shock = 1
horizon = 0

[[identification.sign_restrictions]]
var = 2
shock = 1
sign = "positive"
horizon = 0

# Uhlig-specific tuning parameters (all optional)
[identification.uhlig]
n_starts = 100          # number of random starting points (default: 50)
n_refine = 20           # best starts to refine (default: 10)
max_iter_coarse = 1000  # coarse optimization iterations (default: 500)
max_iter_fine = 5000    # fine optimization iterations (default: 2000)
tol_coarse = 1e-5       # coarse tolerance (default: 1e-4)
tol_fine = 1e-10        # fine tolerance (default: 1e-8)
```

---

## Narrative ADRR Identification

Antolín-Díaz / Rubio-Ramírez narrative contribution restrictions, run through the Arias importance-sampling pipeline. Used with `--id=narrative-adrr` on the `irf`/`fevd`/`hd` `var` leaves. Takes the same zero/sign restriction blocks as Arias, plus at least one `narrative_contributions` block (Type A `most_important` or Type B `overwhelming`; default `most_important`).

```toml
[[identification.sign_restrictions]]
var = 2
shock = 1
sign = "positive"
horizon = 0

[[identification.narrative_contributions]]
variable = 1
shock = 1
window = [1, 4]          # 2-element [lo, hi] horizon range
kind = "most_important"  # or "overwhelming"
```

---

## Further SVAR Restriction Kinds

The same `--id=arias` / `--id=uhlig` / `--id=narrative-adrr` pipeline on the `irf`/`fevd`/`hd` `var` leaves accepts these additional `[[identification.*]]` block kinds alongside the Arias zero/sign blocks above.

```toml
# Restrictions on the impact (A0) matrix
[[identification.a0_zero_restrictions]]
equation = 1
shock = 1

[[identification.a0_sign_restrictions]]
equation = 2
shock = 1
sign = "positive"

# Elasticity bound: (numerator/denominator) response ratio at a horizon
[[identification.elasticity_bounds]]
numerator = 1
denominator = 2
shock = 1
horizon = 0
lower = 0.5    # optional (default -Inf)
upper = 2.0    # optional (default +Inf)

# Magnitude bound: response level at a horizon (both required)
[[identification.magnitude_bounds]]
variable = 1
shock = 1
horizon = 0
lower = -1.0
upper = 1.0

# Cumulative restriction over a horizon range
[[identification.cumulative_restrictions]]
variable = 1
shock = 1
sign = "positive"
horizons = [0, 4]

# Narrative shock restriction (Antolín-Díaz / Rubio-Ramírez)
[[identification.narrative_shocks]]
shock = 1
dates = [10, 15]
sign = "positive"
```

| Block | Required keys | Optional keys |
|-------|---------------|---------------|
| `a0_zero_restrictions` | `equation`, `shock` | — |
| `a0_sign_restrictions` | `equation`, `shock`, `sign` | — |
| `elasticity_bounds` | `numerator`, `denominator`, `shock` | `horizon` (default 0), `lower`, `upper` |
| `magnitude_bounds` | `variable`, `shock`, `lower`, `upper` | `horizon` (default 0) |
| `cumulative_restrictions` | `variable`, `shock`, `sign`, `horizons` | — |
| `narrative_shocks` | `shock`, `dates`, `sign` | — |

---

## Lewis TVV Identification

Lewis (2021) identification through time-varying volatility. Used with `--id=lewis-tvv`.

```toml
[identification]
method = "lewis-tvv"

[identification.lewis_tvv]
weighting = "two_step"   # one_step | two_step (default) | cue
```

---

## SV-SVAR Identification

Bertsche–Braun (2022) stochastic-volatility SVAR estimated by EM. Used with `--id=sv-em`.

```toml
[identification]
method = "sv-em"

[identification.sv_svar]
hetero_shocks = [1, 2]  # 1-based shock indices with SV treatment (default: all shocks)
maxiter = 500           # EM iterations, ≥ 1 (default: 500)
gibbs_burn = 5          # Gibbs burn-in draws, ≥ 0 (default: 5)
gibbs_draws = 100       # Gibbs draws, ≥ 1 (default: 100)
init = "ols_chol"       # ols_chol | haar (default: ols_chol)
```

---

## SVAR AB-model Patterns

Patterns for `estimate multivariate svar --pattern`. `recursive` and `blanchard-quah` need no config; the matrix kinds read n×n arrays from the `[svar]` table, where TOML `nan` marks a free parameter and any fixed number a calibrated entry.

```toml
[svar]
# a-model reads A (B = I); b-model reads B (A = I);
# ab-model reads A and B, with an optional long_run matrix
A = [[1.0, 0.0], [nan, 1.0]]
# B = [[nan, 0.0], [0.0, nan]]
# long_run = [[nan, 0.0], [nan, nan]]

# Solver tuning for the AB-model estimator (all optional)
# recursive = false
# n_starts = 10
# max_iter = 1000
```

| Key | Where | Description |
|-----|-------|-------------|
| `A` / `B` / `long_run` | `[svar]` | n×n pattern matrices (`nan` = free parameter) |
| `recursive` | `[svar]` | Boolean flag for the recursive pattern |
| `n_starts` / `max_iter` | `[svar]` | Random starts and iteration cap for the estimator |

---

## SVEC Restrictions

Optional zero matrices for `estimate multivariate svec --config`. Either key absent keeps upstream's KPSW default for that side; no `--config` at all gives the fully default KPSW identification. Same n×n `nan`-means-free convention as `[svar]`.

```toml
[svec]
long_run_zeros = [[nan, 0.0], [nan, nan]]
short_run_zeros = [[nan, 0.0], [nan, nan]]
```

---

## Non-Gaussian SVAR

Used by `test serial heteroskedasticity` with `--method=smooth_transition` or `--method=external`. (`estimate fastica` / `estimate ml` take `--method`/`--contrast`/`--distribution` as flags instead — see the generated reference.)

```toml
[nongaussian]
method = "smooth_transition"
transition_variable = "spread"   # column name in data CSV
n_regimes = 2
contrast = "logcosh"       # logcosh | exp | kurtosis (FastICA contrast)
distribution = "student_t" # student_t | skew_t | ghd (ML distribution)
```

For external volatility:

```toml
[nongaussian]
method = "external"
regime_variable = "nber"         # column name for regime indicator
n_regimes = 2
```

| Key | Where | Description |
|-----|-------|-------------|
| `method` | `[nongaussian]` | `fastica` (default) \| `jade` \| `ml` \| `markov` \| `garch` \| `smooth_transition` \| `external` |
| `contrast` | `[nongaussian]` | `logcosh` (default) \| `exp` \| `kurtosis` |
| `distribution` | `[nongaussian]` | `student_t` (default) \| `skew_t` \| `ghd` |
| `n_regimes` | `[nongaussian]` | Number of volatility regimes (default 2) |
| `transition_variable` | `[nongaussian]` | Column name (smooth-transition path) |
| `regime_variable` | `[nongaussian]` | Column name (external path) |

---

## GMM Specification

Used by `estimate regression gmm`.

```toml
[gmm]
moment_conditions = ["output", "inflation"]
instruments = ["lag_output", "lag_inflation"]
weighting = "twostep"
```

| Field | Description |
|-------|-------------|
| `moment_conditions` | Column names used as LP-GMM moment variables (default path) |
| `instruments` | Excluded instrument columns (IV path) or unused LP-GMM names (default path) |
| `weighting` | Weighting matrix method (overridden by `--weighting` flag) |
| `dep` | Dependent-variable column. **Together with `theta0`, switches to IV-GMM** |
| `endogenous` | Endogenous regressor columns (IV path) |
| `exogenous` | Optional included exogenous regressors (IV path) |
| `theta0` | Starting values, length = 1 (intercept) + endogenous + exogenous |

Omit both `dep` and `theta0` to keep the default LP-GMM (horizon-0) estimator.
Set both to call `estimate_gmm` with a linear-IV moment `Z'(y − Xθ)` so the
Stock–Yogo first-stage F is stored and rendered. One without the other is
`config/invalid`.

---

## DSGE Model

Used by `dsge solve`, `dsge irf`, `dsge fevd`, `dsge simulate`, `dsge estimate`, `dsge perfect-foresight`, `dsge steady-state`, `dsge determinacy-map` (plus `[priors]` for the `dsge bayes` leaves).

```toml
[model]
endogenous = ["y", "c", "k", "n"]
exogenous = ["eps_a"]
# linear = true   # optional: pre-linearized model (variables are deviations from SS)
# utility = "log(c[t])"  # optional: Bellman VFI felicity
# beta = "0.99"          # optional: VFI discount expression
# controls = ["c"]       # optional: VFI choice variables

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
method = "gensys"    # gensys|klein|perturbation|projection|pfi
order = 1            # perturbation order (1, 2, or 3)
degree = 5           # polynomial degree (projection/pfi)
grid = "auto"        # auto|chebyshev|smolyak
```

| Section | Description |
|---------|-------------|
| `[model]` | Lists endogenous/exogenous variables; optional `linear = true` for pre-linearized specs (MEMs `ModelSpec.linear`); optional `utility` / `beta` / `controls` for the Bellman VFI payload |
| `[model.parameters]` | Deep parameters with values |
| `[[model.equations]]` | Model equations (one per block, `expr` field) |
| `[solver]` | Solution method and settings |

Equations use MEMs' `@dsge` syntax — the CLI builds the spec by feeding them to that
macro. Time notation: `x[t]` = current, `x[t-1]` = lag, `x[t+1]` = lead
(`x[t+1]` is `E_t x_{t+1}`). The expectations operator `E[t](expr)` was removed
upstream — both `.toml` and `.jl` fail as typed `config/invalid`
with that message. There is no auto-rewrite shim. (Bare `x` and the older
`x(+1)`/`x(-1)` forms are **not** accepted — always index by `[t]`.)

---

## DSGE Priors

Bayesian prior for each estimated DSGE parameter. Used by the `dsge bayes` leaves (`bayes estimate`, `bayes posterior-mode`, and every leaf that re-estimates). Each `[priors.<name>]` table gives a distribution name plus its two positional constructor arguments (MEMs/Dynare convention: `beta` → `Beta(a,b)`, `normal` → `Normal(mean,sd)`, `inv_gamma` → `InverseGamma(a,b)`).

```toml
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0

[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.5
```

| Key | Where | Description |
|-----|-------|-------------|
| `dist` | each `[priors.<name>]` | Distribution name (required) |
| `a` | each `[priors.<name>]` | First shape parameter (default 0.0) |
| `b` | each `[priors.<name>]` | Second shape parameter (default 1.0) |

---

## Determinacy Map

Parameter sweep for `dsge determinacy-map`, recording the Sims existence/uniqueness verdict at each grid point. A scalar works wherever a one-element list would; `points` may be a single integer applied to every parameter.

```toml
[determinacy]
params = ["phi_pi", "phi_y"]  # 1 or 2 distinct parameter names
lower = [0.0, 0.0]            # per-parameter grid start
upper = [3.0, 1.0]            # per-parameter grid end
points = [61, 41]             # per-parameter grid resolution (≥ 2 each)
method = "gensys"             # gensys | klein | blanchard-kahn (default: gensys)
div = 1.00000001              # stable/unstable eigenvalue boundary (default 1.0 + 1e-8)
```

Use `grids = [[...], [...]]` (one value list per parameter, ≥ 2 values each; a single flat list for one parameter) instead of `lower`/`upper`/`points` for explicit grids.

---

## OccBin Constraints

Used by `dsge solve --constraints=...`, `dsge irf --constraints=...`, `dsge steady-state --constraints=...`. The `--constraint-solver` flag selects the backend (`nonlinearsolve|optim|nlopt|ipopt|path`).

```toml
[constraints]

[[constraints.bounds]]
variable = "i_rate"
lower = 0.0

[[constraints.bounds]]
variable = "investment"
lower = 0.0
upper = 100.0

# Optional nonlinear constraints (each needs an expression; label optional)
[[constraints.nonlinear]]
expr = "i_rate[t] - 0.5 * y[t]"
label = "taylor-gap"
```

Each `[[constraints.bounds]]` block specifies a variable with optional `lower` and/or `upper` bounds. The OccBin algorithm solves the piecewise-linear system respecting these occasionally binding constraints.

| Key | Where | Description |
|-----|-------|-------------|
| `variable` | each `[[constraints.bounds]]` | Constrained variable name (required) |
| `lower` / `upper` | each `[[constraints.bounds]]` | Optional bounds (at least the block itself is required) |
| `expr` | each `[[constraints.nonlinear]]` | Nonlinear constraint expression (required) |
| `label` | each `[[constraints.nonlinear]]` | Optional label |

---

## SMM Specification

Used by `estimate regression smm --config=...` (required — SMM matches simulated moments to sample
moments, so it needs a data-generating `model` and an initial parameter vector `theta0`).

```toml
[smm]
model     = "ar1"          # ar1 | arp | var1 | iid_normal
theta0    = [0.4, 0.5]     # initial parameters (layout depends on model)
lags      = 2              # autocovariance-moment lags (default 1)
weighting = "two_step"     # identity | two_step (optimal/iterated/twostep → two_step)
sim_ratio = 5              # simulation-to-sample ratio
burn      = 100            # burn-in periods for the simulator
lower     = [-0.99, 1.0e-4]  # optional parameter bounds (both required together)
upper     = [0.99, 10.0]     # → ParameterTransform; same length as theta0
```

| Field | Default | Description |
|-------|---------|-------------|
| `model` | — (required) | Built-in simulator: `ar1`, `arp`, `var1`, `iid_normal` |
| `theta0` | — (required) | Initial parameter vector; layout depends on `model` |
| `lags` | `1` | Autocovariance-moment lags (moments = `k(k+1)/2 + k·lags`) |
| `p` | — | AR order — required only for `model = "arp"` |
| `weighting` | `two_step` | `identity` or `two_step` (aliases `optimal`/`iterated`/`twostep`) |
| `sim_ratio` | `5` | How many simulated observations per data observation |
| `burn` | `100` | Discard this many initial simulation periods |
| `lower` / `upper` | — | Optional bounds (both together, length = `theta0`) |

### Built-in simulator models

Each simulator draws Gaussian innovations and is matched via autocovariance moments. The
number of variables `k` is taken from the data; `theta0` must have the length shown:

| `model` | Data | `theta0` layout | Params |
|---------|------|-----------------|--------|
| `ar1` | univariate (`k=1`) | `[phi, sigma]` | 2 |
| `arp` | univariate (`k=1`) | `[phi_1, …, phi_p, sigma]` (needs `p`) | `p+1` |
| `var1` | multivariate | `[vec(A) (k², column-major); sigma_1, …, sigma_k]` | `k²+k` |
| `iid_normal` | multivariate | `[sigma_1, …, sigma_k]` | `k` |

The moment count must be at least the parameter count (`k(k+1)/2 + k·lags ≥ #params`); raise
`lags` if a model is under-identified (e.g. `var1` with `k=2` needs `lags ≥ 2`). `--seed`
forwards to the simulator's RNG so a two-step fit is byte-reproducible.

Example (AR(1)):

```toml
[smm]
model  = "ar1"
theta0 = [0.4, 0.5]
lags   = 2
lower  = [-0.99, 1.0e-4]
upper  = [0.99, 10.0]
```

---

## Systems Specification (SUR / 3SLS)

Used by `estimate regression sur --config=...` and `estimate regression 3sls --config=...`. Each `[[equations]]`
block defines one equation of the system by naming a dependent column (`dep`) and its
regressor columns (`indep`) — all column names come from the data CSV. A per-equation
constant is added unless `--no-intercept` is passed.

```toml
[[equations]]
name  = "consumption"        # optional label (default eq1, eq2, ...)
dep   = "cons"
indep = ["income", "wealth"]

[[equations]]
name  = "investment"
dep   = "inv"
indep = ["income", "interest"]
```

For **3SLS**, instruments are either a shared set:

```toml
[instruments]
common = ["gov", "taxes", "lag_income"]
```

or per-equation (run with `--instruments perequation`), giving each `[[equations]]` block its
own `instr` list:

```toml
[[equations]]
dep   = "cons"
indep = ["income", "wealth"]
instr = ["gov", "lag_income"]
```

| Key | Where | Description |
|-----|-------|-------------|
| `dep` | each `[[equations]]` | Dependent-variable column (required) |
| `indep` | each `[[equations]]` | Regressor columns (required, ≥1) |
| `name` | each `[[equations]]` | Optional equation label |
| `instr` | each `[[equations]]` | Per-equation instruments (3SLS `--instruments perequation`) |
| `common` | `[instruments]` | Shared instrument set (3SLS `--instruments common`, the default) |

---

## State-Space System

A general linear-Gaussian state-space system for `estimate regression statespace --config`:

```text
yₜ   = Z αₜ + d + εₜ,   εₜ ~ N(0, H)
αₜ₊₁ = T αₜ + c + R ηₜ, ηₜ ~ N(0, Q)
```

Matrices are row-major arrays of arrays; vectors are flat arrays. The TOML key is `T` (standard notation); the MEMs field is `Tt` and the constructor keyword `T_mat`.

```toml
[statespace]
Z = [[1.0, 0.0]]     # n_obs × n_state (required)
H = [[0.5]]          # n_obs × n_obs (required)
T = [[0.9, 0.0], [0.0, 0.9]]  # n_state × n_state (required)
Q = [[1.0, 0.0], [0.0, 1.0]]  # r × r (required)
# d = [0.0]          # n_obs observation intercept (optional)
# c = [0.0, 0.0]     # n_state state intercept (optional)
# R = [[1.0, 0.0], [0.0, 1.0]]  # n_state × r loadings (optional; default selects first r states)
# a1 = [0.0, 0.0]    # initial state mean (optional; needs P1)
# P1 = [[1.0, 0.0], [0.0, 1.0]] # initial state covariance (optional; needs a1)
# init_mode = "kappa"  # kappa | diffuse | stationary (default: kappa)
```

| Key | Where | Description |
|-----|-------|-------------|
| `Z` | `[statespace]` | Observation loadings, n_obs × n_state (required) |
| `H` | `[statespace]` | Observation covariance, n_obs × n_obs (required) |
| `T` | `[statespace]` | State transition, n_state × n_state (required) |
| `Q` | `[statespace]` | Shock covariance, r × r (required) |
| `R` | `[statespace]` | State loadings, n_state × r (optional) |
| `d` | `[statespace]` | Observation intercept, length n_obs (optional) |
| `c` | `[statespace]` | State intercept, length n_state (optional) |
| `a1` / `P1` | `[statespace]` | Explicit initialisation — both or neither (optional) |
| `init_mode` | `[statespace]` | `kappa` (default) \| `diffuse` \| `stationary` |

---

## GARCH-MIDAS Driver

Used by `estimate volatility garch-midas --config=...`, and **only required for `--rv macro`** (an
exogenous low-frequency driver). With the default `--rv realized`, the long-run component
is derived from the returns themselves and no config is needed. The `[garch_midas]` section
supplies `x_lf`, the low-frequency driver series — one value per calendar block (its length
must be at least the number of complete blocks, `⌊n / m_freq⌋`). All other parameters
(`--m-freq`, `--k`, `--rv`, `--span`) are passed as flags.

```toml
[garch_midas]
# low-frequency macro / realized-variance driver, one value per block
x_lf = [1.02, 0.98, 1.15, 1.07, 0.91, 1.20, 1.05]
```

| Key | Where | Description |
|-----|-------|-------------|
| `x_lf` | `[garch_midas]` | Low-frequency driver series (required for `--rv macro`; array of numbers, one per block) |

---

## VECM Restriction Matrices

Used by the `test vecm beta | alpha | known-beta | joint` cointegration restriction
tests. Each supplies a restriction matrix on the estimated VECM's cointegrating
structure via a `[vecm_restriction]` section, given **row-major** as an array of
equal-length numeric rows. Let `p` be the number of series and `r` the (fitted or
`--rank`-forced) cointegrating rank.

- `H` — `β = Hφ` restriction (`test vecm beta`, `test vecm joint`). `H` is `p × s`
  with `s ≥ r`. The non-binding case `H = Iₚ` (`s = p`) yields `LR ≈ 0`, `df = 0`.
- `A` — `α = Aψ` restriction (`test vecm alpha`, `test vecm joint`). `A` is `p × a`
  with `a ≥ r`.
- `b` — fully specified cointegrating space `β = b` (`test vecm known-beta`). `b` is
  `p × r` (exactly `r` columns). Setting `b` to the estimated β yields `LR ≈ 0`.

`test vecm joint` reads **both** `H` and `A`. `test vecm weak-exog` needs no config —
it takes `--vars` (comma-separated indices or names) instead.

```toml
[vecm_restriction]
# p = 2 series, r = 1 cointegrating vector
H = [[1.0], [-1.0]]   # β = Hφ  (p×s, s ≥ r)
A = [[1.0], [0.0]]    # α = Aψ  (p×a, a ≥ r)
b = [[1.0], [-1.0]]   # β = b   (p×r, exactly r columns)
```

| Key | Where | Description |
|-----|-------|-------------|
| `H` | `[vecm_restriction]` | `β = Hφ` matrix (`p × s`, `s ≥ r`; `beta`/`joint`) |
| `A` | `[vecm_restriction]` | `α = Aψ` matrix (`p × a`, `a ≥ r`; `alpha`/`joint`) |
| `b` | `[vecm_restriction]` | Known cointegrating space (`p × r`, exactly `r` cols; `known-beta`) |

---

## Policy Rule & Loss (`policy` family)

`policy counterfactual --rule-config` reads a `[rule]` section; the `[loss]` section
feeds the optimal-policy leaves built on the same family.

```toml
[rule]
type = "taylor"     # rate-peg | rate-target | inflation-target | output-gap | ngdp | taylor
cmw = true          # taylor: rho=0.85, phi_pi=2.0, phi_y=0.25 — refuses partial overrides
# rho/phi_pi/phi_y/z_lag   # taylor, textbook defaults (0.5/1.5/1.0/0.0) when cmw absent
# pi_var/y_var             # variable names among the outcomes
# path = [4.0, 4.0]        # rate-target: pegged instrument path, length --horizon
# outcomes/instruments     # default ["infl","ygap"] / ["rate"]

[loss]
outcomes = ["infl", "ygap"]
lambda = [1.0, 0.5]  # REQUIRED — upstream has no default; one weight per outcome
beta = 1.0           # discount, (0, 1]
# type = "ait"       # average-inflation targeting: beta defaults to 1/1.01
#                    # (McKay–Wolf replication value, NOT 0.99);
#                    # lambda_avg/lambda_t/lambda_y/delta/K/pi_var/y_var below

[loss.smoothing]     # optional Δz penalty — parsed as ONE unit: its W_z part feeds
lambda = 1.0         # policy_loss(W_z=...), its wedge_term the engines' z_wedge=
beta = 1.0
z_lag = 0.0
```

| Key | Where | Description |
|-----|-------|-------------|
| `type` | `[rule]` | `rate-peg` \| `rate-target` \| `inflation-target` \| `output-gap` \| `ngdp` \| `taylor` (required) |
| `cmw` | `[rule]` | Taylor only: `true` sets rho=0.85, phi_pi=2.0, phi_y=0.25 and refuses explicit rho/phi_pi/phi_y |
| `rho` / `phi_pi` / `phi_y` / `z_lag` | `[rule]` | Taylor coefficients (defaults 0.5/1.5/1.0/0.0 without `cmw`) |
| `pi_var` / `y_var` | `[rule]` | Variable names (defaults `infl`/`ygap`; `ngdp` needs them distinct) |
| `path` | `[rule]` | Rate-target instrument path, length H (required for `rate-target`) |
| `outcomes` / `instruments` | `[rule]` | Rule variable names (defaults `["infl","ygap"]` / `["rate"]`) |
| `type` | `[loss]` | `diagonal` (default) \| `ait` |
| `outcomes` | `[loss]` | Loss variables (required for `diagonal`) |
| `lambda` | `[loss]` | One weight per outcome, all ≥ 0 (required for `diagonal`) |
| `beta` | `[loss]` | Discount in (0, 1] (default 1.0; `ait` default 1/1.01) |
| `lambda_avg` / `lambda_t` / `lambda_y` / `delta` / `K` | `[loss]` | AIT weights and averaging window (defaults 0.6/0.4/1.0/0.1/19) |
| `pi_var` / `y_var` | `[loss]` | AIT variable names, must be distinct (defaults `infl`/`ygap`) |
| `lambda` / `beta` / `z_lag` | `[loss.smoothing]` | Optional Δz penalty (defaults 1.0/1.0/0.0; lambda > 0, beta in (0, 1]) |

Rules are stabilization around the model's fixed steady state; different target
*levels* are out of scope by construction. See the [`policy` guide](commands/policy.md).

---

## OPP Constraints

Floor/ZLB path constraints for `policy opp --constraints-file` (requires `--instrument-path`, the announced path the constraints act on).

```toml
[[constraint]]
type = "floor"       # floor | zlb (default: floor)
floor = 0.0          # bound level (default: 0.0)
instrument = "rate"  # constrained instrument (default: "rate")
horizons = "all"     # "all" or "lo:hi" with 1 ≤ lo ≤ hi (default: "all")
```

`type = "function"` (Julia-closure constraints) is refused with a pointer — closures are not scriptable from TOML.

---

## Output Formats

All commands support three output formats (see the generated reference for each leaf's tables). Pass `--format` (`-f`) with `--output` (`-o`) to select and redirect:

```bash
# Simulate demo data first — the estimate lines below read it
friedman data simulate var --periods 200 --seed 7 --format csv --output config_demo.csv
friedman estimate multivariate var config_demo.csv
friedman estimate multivariate var config_demo.csv --format csv
friedman estimate multivariate var config_demo.csv --format csv --output results.csv
friedman estimate multivariate var config_demo.csv --format json --output results.json
```

Table is the default (terminal-formatted via PrettyTables). JSON renders the envelope data tables; CSV writes one file per table (the 2nd+ tables go to sibling files).

---

## References

None — reference page; keys are verified against `src/config.jl` parsers.
