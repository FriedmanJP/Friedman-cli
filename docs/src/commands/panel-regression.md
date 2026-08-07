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
