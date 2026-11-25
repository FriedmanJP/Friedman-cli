# [GMM, SMM, Systems, State-Space & Policy](@id cfg-models-policy)

Reference schema for GMM (`gmm lp:`/`gmm iv:`/`[gmm]`), SMM (`smm:`/`[smm]`), multi-equation SUR/3SLS (`equations:`/`instruments:`/`[[equations]]`/`[instruments]`), state-space matrices (`[statespace]`), GARCH-MIDAS macro drivers (`[garch_midas]`), policy counterfactual rules & quadratic loss functions (`[rule]`, `[loss]`, `[loss.smoothing]`), and OPP floor/ZLB constraints (`[[constraint]]`).

---

## GMM Specification (`gmm lp:`, `gmm iv:`, `[gmm]`)

Used by [`estimate regression gmm`](@ref ref-estimate-regression-gmm) ([Regression, Systems & GMM/SMM](@ref chap-regression)). In a model card passed via `--config`, the stanza header explicitly picks between horizon-0 LP-GMM (`gmm lp:`, accepting only `moments` and `weighting`) and linear IV-GMM (`gmm iv:`, requiring `dep`, `endogenous`, and `theta0`, with optional `exogenous` and `instruments`):

```text
gmm lp:
  moments: output, inflation
  weighting: twostep
```

```text
gmm iv:
  dep: cons
  endogenous: income
  exogenous: wealth
  theta0: 0.1, 0.5, 0.2
  instruments: gov
```

For linear IV-GMM, `theta0` length must equal `1` (intercept) + number of endogenous + number of exogenous variables. In the equivalent `[gmm]` TOML form, specifying both `dep` and `theta0` selects IV-GMM (storing Stock–Yogo first-stage F); omitting both selects LP-GMM; supplying only one fails with `config/invalid`:

| Field | TOML / Card Role | Description |
|---|---|---|
| `moment_conditions` / `moments` | LP-GMM | Column names used as horizon-0 moment conditions |
| `instruments` | IV-GMM | Excluded instrument columns |
| `weighting` | Both | Weighting scheme (overridden if `--weighting` is set) |
| `dep` | IV-GMM | Dependent-variable column name |
| `endogenous` | IV-GMM | Endogenous regressor columns |
| `exogenous` | IV-GMM | Optional included exogenous regressor columns |
| `theta0` | IV-GMM | Starting vector of length `1 + n_endog + n_exog` |

---

## SMM Specification (`smm:`, `[smm]`)

Used by [`estimate regression smm`](@ref ref-estimate-regression-smm) ([Regression, Systems & GMM/SMM](@ref chap-regression)). Matches simulated autocovariance moments from built-in simulators (`ar1`, `arp`, `var1`, `iid_normal`) to data moments:

```text
smm:
  model: ar1
  theta0: 0.4, 0.5
  lags: 2
  lower: -0.99, 1.0e-4
  upper: 0.99, 10.0
```

| Field | Default | Description |
|---|---|---|
| `model` | — (required) | Built-in simulator: `ar1`, `arp`, `var1`, `iid_normal` |
| `theta0` | — (required) | Initial parameter vector matching simulator layout below |
| `lags` | `1` | Autocovariance moment lags (`k(k+1)/2 + k*lags` moments) |
| `p` | — | AR order (required for `model = "arp"`) |
| `weighting` | `two_step` | `identity` or `two_step` (`optimal`/`iterated`/`twostep` map to `two_step`) |
| `sim_ratio` | `5` | Simulated observations per sample observation |
| `burn` | `100` | Initial simulated periods discarded as burn-in |
| `lower` / `upper` | — | Optional parameter bounds (must appear together with length equal to `theta0`) |

| Simulator `model` | Sample Dimension | `theta0` Layout | Parameter Count |
|---|---|---|---|
| `ar1` | Univariate (`k = 1`) | `[phi, sigma]` | `2` |
| `arp` | Univariate (`k = 1`) | `[phi_1, ..., phi_p, sigma]` | `p + 1` |
| `var1` | Multivariate (`k`) | `[vec(A) (k^2 column-major); sigma_1, ..., sigma_k]` | `k^2 + k` |
| `iid_normal` | Multivariate (`k`) | `[sigma_1, ..., sigma_k]` | `k` |

Identification requires `k(k+1)/2 + k*lags >= #params` (e.g., `var1` with `k = 2` needs `lags >= 2`). Pass leading `--seed` for reproducible two-step SMM draws.

---

## Systems Specification: SUR / 3SLS (`equations:`, `instruments:`, `[[equations]]`)

Used by [`estimate regression sur`](@ref ref-estimate-regression-sur) and [`estimate regression 3sls`](@ref ref-estimate-regression-3sls). A per-equation intercept is included unless `--no-intercept` is specified.

```text
equations:
  consumption: cons = income, wealth
  investment: inv = income, interest

instruments:
  common: gov, taxes, lag_income
```

For per-equation 3SLS instruments (`--instruments perequation`), append `| instr1, instr2` directly on each equation line and omit `instruments:` (mixing both forms triggers `config/invalid`). The TOML equivalent uses `[[equations]]` (`dep`, `indep`, optional `name`, optional `instr`) and `[instruments]` (`common`).

| Key | Where | Description |
|---|---|---|
| `dep` | `[[equations]]` | Dependent column name (required) |
| `indep` | `[[equations]]` | Regressor column names (`>= 1`; required) |
| `name` | `[[equations]]` | Optional equation label (defaults to `eq1`, `eq2`, ...) |
| `instr` | `[[equations]]` | Per-equation excluded instruments (`--instruments perequation`) |
| `common` | `[instruments]` | Shared excluded instruments (`--instruments common`, default) |

---

## State-Space System (`[statespace]`)

Used by [`estimate regression statespace`](@ref ref-estimate-regression-statespace) ([Univariate, Filters & Spectral](@ref chap-univariate)). Row-major arrays parameterize `y_t = Z alpha_t + d + eps_t` (`eps_t ~ N(0, H)`) and `alpha_{t+1} = T alpha_t + c + R eta_t` (`eta_t ~ N(0, Q)`):

| Key | Section | Description |
|---|---|---|
| `Z` | `[statespace]` | `n_obs × n_state` observation matrix (required) |
| `H` | `[statespace]` | `n_obs × n_obs` observation error covariance (required) |
| `T` | `[statespace]` | `n_state × n_state` transition matrix (required; maps to `Tt`) |
| `Q` | `[statespace]` | `r × r` state shock covariance (required) |
| `R` | `[statespace]` | Optional `n_state × r` shock loading matrix |
| `G` | `[statespace]` | Optional `r × n_obs` state–observation shock cross-covariance `Cov(eta_t, eps_t)` |
| `d`, `c` | `[statespace]` | Optional observation (`n_obs`) and state (`n_state`) intercepts |
| `a1`, `P1` | `[statespace]` | Optional explicit initial state mean and covariance (must appear together) |
| `init_mode` | `[statespace]` | `kappa` (default) \| `diffuse` \| `stationary` |

---

## GARCH-MIDAS Driver (`[garch_midas]`)

Used by [`estimate volatility garch-midas`](@ref ref-estimate-volatility-garch-midas) only under `--rv macro` ([Volatility & Multivariate GARCH](@ref chap-volatility)); the default `--rv realized` needs no config:

| Key | Section | Description |
|---|---|---|
| `x_lf` | `[garch_midas]` | Low-frequency driver vector, at least `floor(n / m_freq)` entries |

---

## Policy Rules, Loss Functions & OPP Constraints (`[rule]`, `[loss]`, `[[constraint]]`)

Used across [`policy`](@ref ref-policy) counterfactual and optimal-policy leaves ([Policy Counterfactuals & Optimal Policy](@ref chap-policy)):

```toml
[rule]
type = "taylor"         # rate-peg | rate-target | inflation-target | output-gap | ngdp | taylor
cmw = true              # sets rho=0.85, phi_pi=2.0, phi_y=0.25 (refuses manual overrides)

[loss]
outcomes = ["infl", "ygap"]
lambda = [1.0, 0.5]     # required under default type = "diagonal"
beta = 1.0              # discount in (0, 1] (ait defaults to 1/1.01)

[loss.smoothing]        # optional delta-z penalty (parsed together as one unit)
lambda = 1.0
beta = 1.0
z_lag = 0.0

[[constraint]]
type = "floor"          # floor | zlb (type = "function" rejected)
floor = 0.0
instrument = "rate"
horizons = "all"        # "all" or "lo:hi" (1 <= lo <= hi)
```

| Key | Section | Description |
|---|---|---|
| `type` | `[rule]` | `rate-peg` \| `rate-target` \| `inflation-target` \| `output-gap` \| `ngdp` \| `taylor` (required) |
| `cmw` | `[rule]` | For `taylor`: `true` sets `rho=0.85, phi_pi=2.0, phi_y=0.25` and forbids manual overrides |
| `rho`, `phi_pi`, `phi_y`, `z_lag` | `[rule]` | Taylor rule parameters (defaults `0.5`, `1.5`, `1.0`, `0.0` when `cmw` is absent) |
| `pi_var`, `y_var` | `[rule]` / `[loss]` | Variable names (defaults `"infl"`, `"ygap"`; must be distinct for `ngdp` and `ait`) |
| `path` | `[rule]` | Instrument target vector of length `--horizon` (required for `rate-target`) |
| `outcomes`, `instruments` | `[rule]` | Outcome and instrument variable lists (defaults `["infl", "ygap"]` / `["rate"]`) |
| `type` | `[loss]` | `diagonal` (default) \| `ait` |
| `outcomes`, `lambda` | `[loss]` | Target variable names and matching non-negative weights (required for `diagonal`) |
| `beta` | `[loss]` | Discount factor in `(0, 1]` (default `1.0`; `ait` default `1/1.01`) |
| `lambda_avg`, `lambda_t`, `lambda_y`, `delta`, `K` | `[loss]` | AIT weights and window (defaults `0.6`, `0.4`, `1.0`, `0.1`, `19`) |
| `lambda`, `beta`, `z_lag` | `[loss.smoothing]` | Instrument change penalty (`lambda > 0`, `beta` in `(0, 1]`, `z_lag` default `0.0`) |
| `type`, `floor`, `instrument`, `horizons` | `[[constraint]]` | Path bounds for [`policy opp`](@ref ref-fam-policy-opp) (`--constraints-file` paired with `--instrument-path`) |

---

## Rational Inattention Specifications (`[ri]`, `[ri.mw]`, `[ri.discrete]`, `[ri.logit]`)

Used across [`frdc ri`](@ref ref-ri) and [`estimate choice ri-logit`](@ref ref-estimate-choice-ri-logit) ([Rational Inattention](@ref chap-ri), [Discrete Choice, Count & Selection](@ref chap-choice)). In every section, `capacity` and `omega` are mutually exclusive, and CLI `--capacity` / `--omega` / `--units` flags override TOML entries.

```toml
# 1. LQG Dynamic Rational Inattention (`ri solve|transition|statespace|irf|fevd|simulate|estimate`)
[ri]
A = [[0.85]]                 # n x n state transition (scalar allowed for n=1)
B = [[0.5]]                  # n x m shock loading
H = [[1.0]]                  # n x d target loading
beta = 0.99                  # discount factor in (0, 1] (default 1.0)
capacity = 0.5               # mutual-information cap (or set `omega = ...`, not both)
units = "bits"               # bits | nats
state_names = ["x"]
action_names = ["a"]
shock_names = ["eps"]
# Optional dynamic transition fields (`ri transition`):
# Sigma_init = [[1.0]]
# capacity_path = [0.25, 0.5, 0.75]   # or omega_path = [...]

# 2. Maćkowiak–Wiederholt multi-block attention (`ri mw`)
[ri.mw]
capacity = 2.0               # total capacity (or omega)
strategic_complementarity = 0.25
units = "bits"
[ri.mw.agg_block]
rho = 0.90                   # AR(1)/AR(2) persistence, or matrix fields A, B|Q, H
sigma = 0.01
weight = 1.0
[ri.mw.idio_block]
rho = 0.50
sigma = 0.10
weight = 1.0

# 3. Matějka–McKay discrete-choice RI (`ri discrete`, `ri iia-test`)
[ri.discrete]
U = [[2.0, 0.0], [0.0, 2.0]] # J x S payoff matrix
mu = [0.5, 0.5]              # length-S state prior vector
omega = 0.8                  # shadow cost (or capacity)
units = "nats"
# new_option_payoffs = [1.0, 1.0]     # length-S vector for `ri iia-test`

# 4. Optional priors / base payoffs for `estimate|predict choice ri-logit`
[ri.logit]
priors = "empirical"         # "empirical", length-S vector, or S x M matrix
# base_payoff = [[0.0, 0.0], [0.0, 0.0]]
```

| Key | Section | Description |
|---|---|---|
| `A`, `B`, `H` | `[ri]` | Required state transition (`n × n`), shock (`n × m`), and target (`n × d`) matrices |
| `M`, `B_u`, `beta` | `[ri]` | Optional loss weight (`d × d`), endogenous control matrix (`n × d`), and discount factor in `(0, 1]` |
| `capacity`, `omega`, `units` | `[ri]`, `[ri.mw]`, `[ri.discrete]` | Mutually exclusive attention cap or shadow cost (`> 0`), plus `bits` or `nats` |
| `Sigma_init`, `omega_path`, `capacity_path` | `[ri]` | Optional initial prior covariance (`n × n`) and time-varying transition schedules for `ri transition` |
| `agg_block`, `idio_block` | `[ri.mw.*]` | Required aggregate and idiosyncratic blocks via `(rho, sigma, weight, process)` or `(A, B\|Q, H, M)` |
| `U`, `mu`, `new_option_payoffs` | `[ri.discrete]` | Payoff matrix (`J × S`), state prior (`S`), and expanded-menu payoff vector (`S`) for `ri iia-test` |
| `priors`, `base_payoff` | `[ri.logit]` | Optional environment state priors (`"empirical"`, `S`, or `S × M`) and baseline payoff matrices (`J × S` or `M × J × S`) |
