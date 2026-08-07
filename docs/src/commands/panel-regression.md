# Panel Regression

Panel regression commands are available under `estimate`, `predict`, `residuals`, and `test`.

## Estimation

| Command | Description |
|---------|-------------|
| `estimate preg` | Panel regression (FE/RE/FD/between/CRE, twoway, and `--absorb` HDFE) |
| `estimate piv` | Panel IV (2SLS) regression |
| `estimate plogit` | Panel logit (pooled/RE) |
| `estimate pprobit` | Panel probit (pooled/RE) |

## Diagnostics

| Command | Description |
|---------|-------------|
| `predict preg/piv/plogit/pprobit` | In-sample fitted values |
| `residuals preg/piv/plogit/pprobit` | Model residuals |

## Specification Tests

| Command | Description |
|---------|-------------|
| `test hausman` | Hausman specification test (FE vs RE) |
| `test breusch-pagan` | Breusch-Pagan LM test for random effects |
| `test f-fe` | F-test for individual fixed effects |
| `test pesaran-cd` | Pesaran CD test for cross-sectional dependence |
| `test wooldridge-ar` | Wooldridge test for serial correlation |
| `test modified-wald` | Modified Wald test for groupwise heteroskedasticity |

## High-dimensional fixed effects (`--absorb`)

`estimate preg --absorb` absorbs any number of non-nested fixed-effect dimensions by alternating projections (Guimarães-Portugal / Correia `reghdfe`), without ever forming dummy columns. Dimension names resolve to a panel variable column, or to the reserved indices `entity` (aliases `id`/`unit`/`group`), `time` (alias `period`) and `cohort`.

```bash
# Entity × time × region, no dummies formed
friedman estimate preg panel.csv --dep y --indep x1,x2 --absorb entity,time,region

# `--absorb entity` reproduces plain one-way FE
friedman estimate preg panel.csv --dep y --indep x1,x2 --absorb entity
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--absorb` | String | | Comma-separated FE dimensions; `--method fe` only |
| `--hdfe-tol` | Float64 | 1e-8 | Absorption convergence tolerance |
| `--hdfe-maxiter` | Int | 1000 | Maximum alternating-projection iterations |

**Use `--absorb entity,time`, not `--twoway`, on an unbalanced panel.** The two are mutually exclusive and the CLI rejects the pair with a typed `usage/invalid` pointing at `--absorb entity,time`. The reason is substantive: the additive two-way within transformation `y - ȳᵢ - ȳₜ + ȳ` is the correct projection only when the panel is balanced. On an unbalanced panel it is not, and the resulting coefficients are biased — upstream's PWT benchmark recovers a capital coefficient of **0.297 against a truth of 0.514**. Absorption by alternating projections is exact either way, which is why `--absorb` is the route the CLI offers.

With `--absorb`, one extra table is emitted, **HDFE Absorption**: `absorb`, `n_absorbed`, `n_levels`, `n_components`, `converged`, `iterations`, `final_change`, `tol`. `n_absorbed` is the degrees of freedom the transformation consumed (levels net of the connected components the dimensions share), and `converged=false` means the reported coefficients came from a **truncated** projection loop — a silent accuracy loss otherwise invisible, so it also warns on stderr. Raise `--hdfe-maxiter` or loosen `--hdfe-tol` if you see it.

## Usage

```bash
# Fixed effects regression
friedman estimate preg panel.csv --dep gdp --indep investment,trade --method fe

# Hausman test
friedman test hausman panel.csv --dep gdp --indep investment,trade

# Panel IV
friedman estimate piv panel.csv --dep gdp --exog trade --endog investment --instruments lag_inv
```

## Dynamic panel GMM (`--method ab|bb`)

`--method ab` (Arellano–Bond difference GMM) and `--method bb` (Blundell–Bond system
GMM) regress the dependent variable on its own first lag plus `--indep`, instrumenting
the lag with its deeper history. Since v0.9.2 (MEMs#549) the Roodman/`xtabond2`
instrument-proliferation controls are exposed:

```bash
friedman estimate preg panel.csv --dep y --indep x --method ab --collapse
friedman estimate preg panel.csv --dep y --indep x --method bb --min-lag-endo 2 --max-lag-endo 4
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
    pushes the Hansen J toward spurious non-rejection (Roodman 2009). Upstream warns on
    stderr when `n_instruments > N`; `--collapse` (or a narrow `--max-lag-endo`) is the
    standard fix, and `n_instruments` in the diagnostics table is how you verify it worked.

## Panel IV weak-instrument diagnostics (v0.9.2)

`estimate piv` always emits a **Weak-Instrument Diagnostics** table (populated upstream
since MEMs#553): the minimum excluded-instrument partial first-stage F across the
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
