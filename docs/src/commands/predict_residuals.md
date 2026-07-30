# predict & residuals

In-sample fitted values (`predict`) and model residuals (`residuals`). 23 subcommands each, covering time series, volatility, factor, cross-sectional regression, panel regression, and ordered/multinomial choice models.

Both commands share identical subcommand structure and options. Each subcommand estimates the model and extracts fitted values or residuals.

## Supported Models

| Subcommand | Model |
|------------|-------|
| `var` | Frequentist VAR |
| `bvar` | Bayesian VAR |
| `arima` | ARIMA |
| `vecm` | Vector Error Correction Model |
| `static` | Static factor model (PCA) |
| `dynamic` | Dynamic factor model |
| `gdfm` | Generalized dynamic factor model |
| `arch` | ARCH volatility |
| `garch` | GARCH volatility |
| `egarch` | EGARCH volatility |
| `gjr_garch` | GJR-GARCH volatility |
| `sv` | Stochastic volatility |
| `favar` | Factor-Augmented VAR |
| `reg` | OLS/WLS regression |
| `logit` | Logit regression |
| `probit` | Probit regression |
| `preg` | Panel regression (FE/RE/BE/pooled) |
| `piv` | Panel IV (2SLS) regression |
| `plogit` | Panel logit |
| `pprobit` | Panel probit |
| `ologit` | Ordered logit |
| `oprobit` | Ordered probit |
| `mlogit` | Multinomial logit |
| `statespace` | Structural state-space model (local level / local linear trend) |
| `sur` | Seemingly unrelated regressions |
| `3sls` | Three-stage least squares |

## predict

```bash
friedman predict var data.csv --lags=2
friedman predict arima data.csv --p=1 --d=1 --q=1
friedman predict garch data.csv --column=1 --p=1 --q=1
friedman predict vecm data.csv --lags=4 --rank=2
```

## residuals

```bash
friedman residuals var data.csv --lags=2
friedman residuals arima data.csv --p=1 --d=1 --q=1
friedman residuals garch data.csv --column=1 --p=1 --q=1
friedman residuals vecm data.csv --lags=4 --rank=2
```

## Common Options

Options match those in the corresponding `estimate` command for each model type. All subcommands support:

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### VAR / BVAR

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto/4 | Lag order |

### ARIMA

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--p` | | Int | auto | AR order |
| `--d` | | Int | 0 | Differencing order |
| `--q` | | Int | 0 | MA order |

### VECM

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--rank` | `-r` | Int | auto | Cointegration rank |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |

### Volatility Models (arch, garch, egarch, gjr\_garch, sv)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--p` | | Int | 1 | GARCH order (not for arch) |
| `--q` | | Int | 1 | ARCH order |

### Factor Models (static, dynamic, gdfm)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto | Number of factors |

### Regression Models (reg, logit, probit)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--cov-type` | | String | `hc1` | Covariance type |
| `--clusters` | | String | | Cluster variable column name |

### Logit/Probit Predict Flags

`predict logit` and `predict probit` support additional flags for alternative output:

| Flag | Description |
|------|-------------|
| `--marginal-effects` | Output average marginal effects instead of fitted probabilities |
| `--odds-ratio` | Output odds ratio table (logit only) |
| `--classification-table` | Output classification metrics plus the confusion matrix |
| `--threshold` | Classification threshold (option, default `0.5`; used with `--classification-table`) |

`--marginal-effects`, `--odds-ratio` and `--classification-table` are boolean flags —
pass them bare, without a value. They are mutually exclusive with the default
fitted-values output. `--threshold` takes a value.

### Panel Regression Models (preg, piv, plogit, pprobit)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--method` | | String | (varies) | Estimation method (fe/re/pooled for preg/piv) |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |

For `piv`, also requires `--endog` and `--instruments`.

### Ordered & Multinomial Models (ologit, oprobit, mlogit)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--cov-type` | | String | `hc1` | Covariance type |

`predict ologit`, `predict oprobit`, and `predict mlogit` return one predicted-probability
column per category (`prob_<category>`), plus an `observation` index.

`residuals ologit`, `residuals oprobit` and `residuals mlogit` exit with
`model/unsupported` (exit 5): MacroEconometricModels 0.7.0 defines no `residuals` method
for ordered or multinomial models, and there is no single standard residual definition
for them. Use `predict` for the per-category probabilities instead.

This is tracked upstream as
[MacroEconometricModels.jl#507](https://github.com/FriedmanJP/MacroEconometricModels.jl/issues/507);
the leaves will be enabled once it ships.

## State space: `predict statespace`, `residuals statespace`

A structural state-space model has no single vector of "fitted values": it has a **state
path**, one series per state (a local level has one state, a local linear trend has two).
`predict statespace` therefore emits a tidy long table `period | state | filtered | smoothed`
— the Kalman-filtered `a_{t|t}` and the smoothed `a_{t|T}` side by side, so the same table
shape serves both models and the row count grows with the number of states rather than the
column set. `--state filtered|smoothed` restricts the output to one of the two.

`residuals statespace` emits the one-step-ahead prediction errors `v_t = y_t − Z a_{t|t−1}`
(`period | residual`). `--standardized` divides by `sqrt(F_t)` instead, which is the form to
use for diagnostic checking — the raw innovations are heteroskedastic while the filter
converges out of its diffuse initialisation.

The model type is selected with **`--kind`**, not `--model`: on `predict`/`residuals`,
`--model` is reserved for a saved model handle. Options otherwise mirror
[`estimate statespace`](estimate.md#estimate-statespace).

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--kind` | | String | `local-level` | `local-level`, `local-linear-trend` |
| `--init-mode` | | String | `kappa` | `kappa`, `diffuse` |
| `--kappa` | | Float | `1e6` | Large-κ diffuse prior variance |
| `--state` | | String | `both` | `filtered`, `smoothed`, `both` (predict only) |
| `--standardized` | | Flag | off | Standardized innovations `v_t/√F_t` (residuals only) |

```bash
friedman predict statespace y.csv --kind local-linear-trend
friedman predict statespace y.csv --state smoothed
friedman residuals statespace y.csv --standardized
```

## Systems: `predict sur | 3sls`, `residuals sur | 3sls`

SUR and 3SLS carry **per-equation** fitted values and residuals. Both verbs render them as
**one tidy long table** — `equation | t | fitted` (resp. `residual`) — rather than one
table per equation, so the envelope key set does not change with the number of equations
in your config.

The equation system lives in the `--config` TOML, so **`--config` is required**: without it
there is nothing to refit. The other options mirror the matching `estimate` leaf
(`--iterate`/`--no-intercept` for SUR, `--instruments`/`--no-intercept` for 3SLS).

```bash
friedman predict sur data.csv --config system.toml
friedman residuals 3sls data.csv --config system.toml --instruments=common
```
