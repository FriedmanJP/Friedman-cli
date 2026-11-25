# [Priors, SVAR & VECM Identification](@id cfg-identification)

Reference schema for Bayesian VAR priors, structural VAR/SVEC identification restrictions, heteroskedastic and non-Gaussian SVAR settings, and VECM cointegration restriction matrices. See [Model Cards & Config Grammar](@ref cfg-overview) for precedence (`--config` < `--config-json` < `--set`) and `--strict` behavior.

---

## Minnesota Prior (`[prior]`)

Used by [`estimate multivariate bvar`](@ref ref-estimate-multivariate-bvar), [`irf bvar`](@ref ref-irf-bvar), [`fevd bvar`](@ref ref-fevd-bvar), [`hd bvar`](@ref ref-hd-bvar), and [`forecast multivariate bvar`](@ref ref-forecast-multivariate-bvar).

```toml
[prior]
type = "minnesota"

[prior.hyperparameters]
lambda1 = 0.2       # tau (overall tightness)
lambda2 = 0.5       # cross-variable shrinkage
lambda3 = 1.0       # lag decay
lambda4 = 100000.0  # constant term variance (accepted for compat; not forwarded)

[prior.optimization]
enabled = true      # grid-search optimize hyperparameters when true
```

| Parameter | Upstream Field | Description | Typical Range |
|---|---|---|---|
| `lambda1` | `tau` | Overall tightness of the prior | `0.01` – `1.0` |
| `lambda2` | `lambda` | Cross-variable shrinkage on other variables' lags | `0.1` – `1.0` |
| `lambda3` | `decay` | Lag decay exponent | `0.5` – `2.0` |
| `lambda4` | — | Accepted for backward compatibility, not forwarded (`mu`/`omega` use upstream defaults) | — |

When `[prior.optimization] enabled = true`, grid search determines optimal hyperparameters automatically via `optimize_hyperparameters()`, overriding `[prior.hyperparameters]`.

---

## Sign & Narrative Restrictions

Used by [`irf var`](@ref ref-irf-var), [`irf bvar`](@ref ref-irf-bvar), [`irf lp`](@ref ref-irf-lp), [`fevd`](@ref ref-fevd), and [`hd`](@ref ref-hd) under `--id sign` or `--id narrative`.

```toml
[identification]
method = "narrative"

[identification.sign_matrix]
# Rows = variables, columns = shocks (1 = positive, -1 = negative, 0 = unrestricted)
matrix = [
  [1, -1, 1],
  [0,  1, -1],
  [0,  0, 1]
]
horizons = [0, 1, 2, 3]  # 0-based horizons

[identification.narrative]
shock_index = 1          # 1-based shock index
periods = [10, 15, 20]   # sample periods constrained
signs = [1, -1, 1]       # required sign (+1 / -1) at each period
```

| Key | Section | Description |
|---|---|---|
| `matrix` | `[identification.sign_matrix]` | `N × N` matrix with entries in `{-1, 0, 1}` |
| `horizons` | `[identification.sign_matrix]` | 0-based horizon indices where sign restrictions apply |
| `shock_index` | `[identification.narrative]` | 1-based shock index for sign constraint |
| `periods` | `[identification.narrative]` | Period indices constrained |
| `signs` | `[identification.narrative]` | Required sign (`1` or `-1`) aligned with `periods` |

---

## Arias, Uhlig & Narrative ADRR Identification

Used by `--id arias`, `--id uhlig`, and `--id narrative-adrr` pipelines (Arias et al. 2018 importance sampler; Mountford & Uhlig 2009 penalty objective; Antolin-Diaz & Rubio-Ramirez 2018 narrative contribution restrictions).

```toml
[[identification.zero_restrictions]]
var = 1
shock = 1
horizon = 0            # integer horizon or "long_run"

[[identification.sign_restrictions]]
var = 2
shock = 1
sign = "positive"      # positive | negative
horizon = 0            # or horizons = [lo, hi] range

[[identification.narrative_contributions]]
variable = 1
shock = 1
window = [1, 4]        # 2-element [lo, hi] horizon window
kind = "most_important" # most_important | overwhelming

[identification.uhlig]
n_starts = 100         # default: 50
n_refine = 20          # default: 10
max_iter_coarse = 1000 # default: 500
max_iter_fine = 5000   # default: 2000
tol_coarse = 1e-5      # default: 1e-4
tol_fine = 1e-10       # default: 1e-8
scale = "diff"         # diff | first_difference | residual | sigma | none | unit | [s1, ..., sn]
```

The `--id arias`, `--id uhlig`, and `--id narrative-adrr` pipeline on `irf`/`fevd`/`hd var` also accepts six additional `[[identification.*]]` array-of-table blocks:

| Block | Required Keys | Optional Keys |
|---|---|---|
| `a0_zero_restrictions` | `equation`, `shock` | — |
| `a0_sign_restrictions` | `equation`, `shock`, `sign` | — |
| `elasticity_bounds` | `numerator`, `denominator`, `shock` | `horizon` (`0`), `lower` (`-Inf`), `upper` (`+Inf`) |
| `magnitude_bounds` | `variable`, `shock`, `lower`, `upper` | `horizon` (`0`) |
| `cumulative_restrictions` | `variable`, `shock`, `sign`, `horizons` | — |
| `narrative_shocks` | `shock`, `dates`, `sign` | — |

---

## Heteroskedastic SVAR (`lewis_tvv`, `sv_svar`)

Used by [`irf var`](@ref ref-irf-var), [`irf bvar`](@ref ref-irf-bvar), [`irf lp`](@ref ref-irf-lp), [`fevd`](@ref ref-fevd), and [`hd`](@ref ref-hd) with `--id lewis-tvv` (Lewis 2021 GMM via time-varying volatility) or `--id sv-em` (Bertsche–Braun 2022 stochastic volatility SVAR by EM):

```toml
[identification.lewis_tvv]
weighting = "two_step"   # one_step | two_step (default) | cue

[identification.sv_svar]
hetero_shocks = [1, 2]   # 1-based shock indices (default: all shocks)
maxiter = 500            # >= 1 (default: 500)
gibbs_burn = 5           # >= 0 (default: 5)
gibbs_draws = 100        # >= 1 (default: 100)
init = "ols_chol"        # ols_chol | haar (default: ols_chol)
```

---

## SVAR AB-Model & SVEC Restrictions (`[svar]`, `[svec]`)

Used by [`estimate multivariate svar`](@ref ref-estimate-multivariate-svar) (`--pattern a-model|b-model|ab-model`, where `nan` marks a free parameter and numeric entries fix values; `recursive` and `blanchard-quah` require no config) and [`estimate multivariate svec`](@ref ref-estimate-multivariate-svec) (default KPSW restrictions apply when keys are omitted):

```toml
[svar]
A = [[1.0, 0.0], [nan, 1.0]]
# B = [[nan, 0.0], [0.0, nan]]
# long_run = [[nan, 0.0], [nan, nan]]
# recursive = false
# n_starts = 10
# max_iter = 1000

[svec]
long_run_zeros = [[nan, 0.0], [nan, nan]]
short_run_zeros = [[nan, 0.0], [nan, nan]]
```

| Key | Section | Description |
|---|---|---|
| `A`, `B`, `long_run` | `[svar]` | `n × n` pattern matrices (`nan` = free parameter) |
| `recursive` | `[svar]` | Boolean flag selecting recursive structure |
| `n_starts`, `max_iter` | `[svar]` | Random multi-starts and iteration cap |
| `long_run_zeros`, `short_run_zeros` | `[svec]` | `n × n` `nan`-free zero restriction matrices |

---

## Non-Gaussian Heteroskedasticity (`[nongaussian]`)

Used by [`test serial heteroskedasticity`](@ref ref-test-serial-heteroskedasticity) with `--method smooth_transition` or `--method external` (note that `estimate factor fastica` and `estimate regression ml` accept `--contrast`/`--distribution` CLI flags directly):

| Key | Section | Description |
|---|---|---|
| `method` | `[nongaussian]` | `fastica` (default) \| `jade` \| `ml` \| `markov` \| `garch` \| `smooth_transition` \| `external` |
| `contrast` | `[nongaussian]` | `logcosh` (default) \| `exp` \| `kurtosis` |
| `distribution` | `[nongaussian]` | `student_t` (default) \| `skew_t` \| `ghd` |
| `n_regimes` | `[nongaussian]` | Number of volatility regimes (default `2`) |
| `transition_variable` | `[nongaussian]` | Data column name for `smooth_transition` |
| `regime_variable` | `[nongaussian]` | Data column name for `external` |

---

## VECM Restriction Matrices (`[vecm_restriction]`)

Used by [`test vecm beta`](@ref ref-test-vecm-beta), [`test vecm alpha`](@ref ref-test-vecm-alpha), [`test vecm known-beta`](@ref ref-test-vecm-known-beta), and [`test vecm joint`](@ref ref-test-vecm-joint) ([Hypothesis Testing & Diagnostics](@ref chap-tests); `test vecm weak-exog` uses `--vars` instead of config). For `p` series and cointegrating rank `r`:

```toml
[vecm_restriction]
H = [[1.0], [-1.0]]   # beta = H * phi  (p x s, s >= r)
A = [[1.0], [0.0]]    # alpha = A * psi (p x a, a >= r)
b = [[1.0], [-1.0]]   # beta = b        (p x r, exactly r columns)
```

| Key | Used By | Dimension & Meaning |
|---|---|---|
| `H` | `test vecm beta`, `test vecm joint` | `p × s` matrix with `s >= r` (`beta = H*phi`) |
| `A` | `test vecm alpha`, `test vecm joint` | `p × a` matrix with `a >= r` (`alpha = A*psi`) |
| `b` | `test vecm known-beta` | `p × r` known cointegrating matrix (`beta = b`) |

---

## SVAR Structural Hypothesis Restrictions (`[svar_hypothesis]`)

Used by [`test multivariate svar-hypothesis`](@ref ref-test-multivariate-svar-hypothesis) ([Structural ID, LP & Innovation Accounting](@ref chap-structural), [Hypothesis Testing & Diagnostics](@ref chap-tests)) to test exact structural restrictions on non-Gaussian or LMS-SVAR impact, long-run, and finite-horizon responses:

```toml
[svar_hypothesis]
type = "impact_zero"             # recursiveness | impact_zero | impact_linear | long_run | horizon_irf | mixed
zeros = [[1, 2], [1, 3]]         # 1-based [var, shock] zero entries (impact_zero / long_run)
# ordering = [1, 2, 3]           # optional variable/shock ordering permutation
# R = [[0.0, 1.0, 0.0, 0.0]]     # linear constraint R * vec(B0) = r (impact_linear)
# r = [0.0]
# restrictions = [{ horizon = 1, var = 1, shock = 2 }]   # horizon_irf

# For type = "mixed", combine one or more sub-tables:
# [svar_hypothesis.short_run]
# type = "impact_zero"
# zeros = [[1, 2]]
# [svar_hypothesis.long_run]
# zeros = [[2, 1]]
# [svar_hypothesis.horizon]
# restrictions = [{ horizon = 4, var = 1, shock = 2 }]
```

| Key | Section | Description |
|---|---|---|
| `type` | `[svar_hypothesis]` | `recursiveness` \| `impact_zero` \| `impact_linear` \| `long_run` \| `horizon_irf` \| `mixed` (required) |
| `ordering` | `[svar_hypothesis]` / sub-tables | Optional 1-based permutation vector for ordering-sensitive restrictions |
| `zeros` | `impact_zero`, `long_run`, sub-tables | Array of `[var, shock]` 1-based index pairs constrained to zero |
| `R`, `r` | `impact_linear`, `short_run` | Linear restriction matrix `R` and right-hand-side vector `r` on `vec(B0)` |
| `restrictions` | `horizon_irf`, `horizon` | Array of `{ horizon = h, var = i, shock = j }` finite-horizon zero restrictions |
| `short_run`, `long_run`, `horizon` | `[svar_hypothesis.*]` | Sub-tables combined when `type = "mixed"` (at least one required) |
