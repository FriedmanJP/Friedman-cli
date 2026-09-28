# Panel Regression

**Goal:** estimate linear and discrete-choice panel models and test the specification that chooses between them. Full option tables live in the [generated estimate reference](generated/estimate.md); every test leaf is tabled in the [generated test reference](generated/test.md). Decision logic for the test battery also sits in [test](test.md), which pairs back here.

---

## Estimation

| Command | Estimators (`--method`) | Description |
|---------|-------------------------|-------------|
| `estimate panel preg` | `fe`, `re`, `fd`, `between`, `cre`, `ab`, `bb` (plus `--twoway`, `--absorb`) | Linear panel: within/GLS/first-difference/between/CRE, two-way, HDFE, dynamic GMM |
| `estimate panel piv` | `fe`, `re`, `fd`, `hausman-taylor` | Panel IV 2SLS: within-IV, EC2SLS, first-difference IV, Hausman–Taylor |
| `estimate panel plogit` | `pooled`, `fe`, `re`, `cre` | Panel logit |
| `estimate panel pprobit` | `pooled`, `re`, `cre` | Panel probit (no fixed-effects estimator upstream) |

Long-format panels resolve `--id-col`/`--time-col` to the first/second columns by default. Reference: [generated estimate reference](generated/estimate.md).

---

## Diagnostics

| Command | Description |
|---------|-------------|
| `predict panel preg/piv/plogit/pprobit` | In-sample fitted values (fitted probabilities for `plogit`/`pprobit`) |
| `residuals panel preg/piv/plogit/pprobit` | Model residuals |

Reference: [generated predict reference](generated/predict.md), [generated residuals reference](generated/residuals.md).

---

## Specification tests

Each leaf fits the model itself, then reports the statistic, p-value, and decision. The **null** is the point — Hausman and Breusch–Pagan point in opposite directions, so rejecting both picks fixed effects with a reason to re-check the specification, not a contradiction.

| Command | H0 | Rejection means |
|---------|----|-----------------|
| `test panel hausman` | **RE consistent** (effects uncorrelated with regressors; both FE and RE consistent) | use FE |
| `test serial breusch-pagan` | **no random effects** (σᵤ² = 0; pooled OLS adequate) | use RE. This is the panel LM test, unrelated to cross-section heteroskedasticity |
| `test panel f-fe` | **no fixed effects** (all αᵢ = 0; pooled OLS adequate) | use FE |
| `test panel pesaran-cd` | **no cross-sectional dependence** | dependence present; first-generation panel tests do not apply |
| `test panel wooldridge-ar` | **no serial correlation** in the idiosyncratic errors (differenced residuals regress on their lag with slope −0.5) | serial correlation present |
| `test panel modified-wald` | **homoskedasticity across groups** (σᵢ² = σ² for all i) on the FE fit | groupwise heteroskedasticity present |

Reference: [generated test reference](generated/test.md).

---

## High-dimensional fixed effects (`--absorb`)

`estimate panel preg --absorb` absorbs any number of non-nested fixed-effect dimensions by alternating projections (Guimarães–Portugal / Correia `reghdfe`), without ever forming dummy columns. Dimension names resolve to a panel variable column, or to the reserved indices `entity` (aliases `id`/`unit`/`group`), `time` (alias `period`) and `cohort`.

```bash
# Entity × time absorption on the shipped Grunfeld panel, no dummies formed
friedman estimate panel preg :grunfeld --dep invest --indep value,capital --id-col group --time-col time --absorb entity,time

# `--absorb entity` reproduces plain one-way FE
friedman estimate panel preg :grunfeld --dep invest --indep value,capital --id-col group --time-col time --absorb entity
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--absorb` | String | | Comma-separated FE dimensions; `--method fe` only |
| `--hdfe-tol` | Float64 | 1e-8 | Absorption convergence tolerance |
| `--hdfe-maxiter` | Int | 1000 | Maximum alternating-projection iterations |

**Use `--absorb entity,time`, not `--twoway`, for two-way effects.** Upstream computes `--twoway` through the same alternating-projections path, so the two spell the same estimator — but the CLI keeps them mutually exclusive and refuses the pair with a typed `usage/invalid` pointing at `--absorb entity,time`. The projection is exact on unbalanced panels either way, where the textbook additive within identity `y − ȳᵢ − ȳₜ + ȳ` stops being the correct projection.

With `--absorb`, one extra table is emitted, **HDFE Absorption**: `absorb`, `n_absorbed`, `n_levels`, `n_components`, `converged`, `iterations`, `final_change`, `tol`. `n_absorbed` is the degrees of freedom the transformation consumed (levels net of the connected components the dimensions share), and `converged=false` means the reported coefficients came from a **truncated** projection loop — a silent accuracy loss otherwise invisible, so it also warns on stderr. Raise `--hdfe-maxiter` or loosen `--hdfe-tol` if you see it.

---

## Usage

```bash
# Fixed effects regression on the shipped Grunfeld panel
friedman estimate panel preg :grunfeld --dep invest --indep value,capital --id-col group --time-col time --method fe

# Hausman test on the same panel
friedman test panel hausman :grunfeld --dep invest --indep value,capital --id-col group --time-col time
```

Panel IV needs excluded instruments present as CSV columns alongside the
regressors — with an instrument column `z` alongside `y`, `x`, and `endo`, the
call is `friedman estimate panel piv <panel> --dep y --exog x --endog endo`
`--instruments z` (drop `--exog` when the model has no exogenous regressors).
The run always emits the **Weak-Instrument Diagnostics** table described below.

---

## Dynamic panel GMM (`--method ab|bb`)

`--method ab` (Arellano–Bond difference GMM) and `--method bb` (Blundell–Bond system
GMM) regress the dependent variable on its own first lag plus `--indep`, instrumenting
the lag with its deeper history. The Roodman/`xtabond2`
instrument-proliferation controls are exposed:

```bash
# Arellano–Bond difference GMM on the shipped Grunfeld panel
friedman estimate panel preg :grunfeld --dep invest --indep value,capital --id-col group --time-col time --method ab --collapse
# Blundell–Bond system GMM with a narrowed instrument lag window
friedman estimate panel preg :grunfeld --dep invest --indep value,capital --id-col group --time-col time --method bb --min-lag-endo 2 --max-lag-endo 4
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--collapse` | Flag | off | Collapse the GMM instrument matrix (one column per lag distance) |
| `--min-lag-endo` | Int | 2 | First instrument lag for endogenous regressors |
| `--max-lag-endo` | Int | 99 | Last instrument lag for endogenous regressors |

They apply **only** to `--method ab|bb`; on any other method the CLI refuses with a
typed `usage/invalid` (upstream would silently ignore them). The GMM run emits an extra
**Dynamic Panel Diagnostics** table: Arellano–Bond AR(1)/AR(2) tests on the
first-difference residuals, Hansen J with df and p-value, `n_instruments`, and the
settings that produced it (`collapse`, the instrument lag window).

!!! warning "Too many instruments"
    With the default `2:99` window the instrument count grows quadratically in T and
    quickly exceeds the number of groups — which overfits the endogenous regressors and
    pushes the Hansen J toward spurious non-rejection (Roodman 2009). `--collapse` (or a narrow `--max-lag-endo`) is the
    standard fix, and `n_instruments` in the diagnostics table is how you verify it worked.

---

## Panel IV weak-instrument diagnostics

`estimate panel piv` always emits a **Weak-Instrument Diagnostics** table: the minimum excluded-instrument partial first-stage F across the
endogenous regressors, Cragg–Donald F, Kleibergen–Paap F, the Stock–Yogo 10% critical
value, and the Sargan overidentification statistic with its p-value.

Two honest-labelling notes baked into the output:

- A cell reading `unavailable (failed or underidentified)` means exactly that — upstream
  wraps Cragg–Donald and Kleibergen–Paap in a bare try/catch, and Sargan has no degrees
  of freedom in a just-identified model, so `nothing` cannot be distinguished into a
  clean "N/A".
- Under `--cov-type cluster` the Kleibergen–Paap F is computed with an HC1 covariance
  (upstream implements no cluster-robust rk statistic), so it ignores within-entity
  dependence — a stderr note flags this on every clustered run.

---

## References

Full option tables: [generated estimate reference](generated/estimate.md), [generated test reference](generated/test.md). Specification logic: [test](test.md).

Arellano, M. and Bond, S. (1991). Some tests of specification for panel data. *Review of Economic Studies*.

Baltagi, B. H. (2021). *Econometric Analysis of Panel Data*. 6th ed. Springer.

Blundell, R. and Bond, S. (1998). Initial conditions and moment restrictions in dynamic panel data models. *Journal of Econometrics*.

Hausman, J. A. (1978). Specification tests in econometrics. *Econometrica*.

Hausman, J. A. and Taylor, W. E. (1981). Panel data and unobservable individual effects. *Econometrica*.

Roodman, D. (2009). A note on the theme of too many instruments. *Oxford Bulletin of Economics and Statistics*.
