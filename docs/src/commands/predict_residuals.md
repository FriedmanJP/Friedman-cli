# predict & residuals

In-sample fitted values (`predict`) and model residuals (`residuals`), covering time series, volatility, factor, cross-sectional regression, panel regression, and ordered/multinomial choice models.

Both commands share identical subcommand structure and options. Each subcommand estimates the model and extracts fitted values or residuals.

## Supported Models

| Path under `predict` / `residuals` | Model |
|------------|-------|
| `var var` | Frequentist VAR |
| `var bvar` | Bayesian VAR |
| `univariate arima` | ARIMA |
| `var vecm` | Vector Error Correction Model |
| `factor static` | Static factor model (PCA) |
| `factor dynamic` | Dynamic factor model |
| `factor gdfm` | Generalized dynamic factor model |
| `volatility arch` | ARCH volatility |
| `volatility garch` | GARCH volatility |
| `volatility egarch` | EGARCH volatility |
| `volatility gjr-garch` | GJR-GARCH volatility |
| `volatility sv` | Stochastic volatility |
| `var favar` | Factor-Augmented VAR |
| `regression reg` | OLS/WLS regression |
| `choice logit` | Logit regression |
| `choice probit` | Probit regression |
| `panel preg` | Panel regression (FE/RE/BE/pooled) |
| `panel piv` | Panel IV (2SLS) regression |
| `panel plogit` | Panel logit |
| `panel pprobit` | Panel probit |
| `choice ologit` | Ordered logit |
| `choice oprobit` | Ordered probit |
| `choice mlogit` | Multinomial logit |
| `regression statespace` | Structural state-space model (local level / local linear trend) |
| `regression sur` | Seemingly unrelated regressions |
| `regression 3sls` | Three-stage least squares |

## predict

```bash
friedman predict var var data.csv --lags=2
friedman predict univariate arima data.csv --p=1 --d=1 --q=1
friedman predict volatility garch data.csv --column=1 --p=1 --q=1
friedman predict var vecm data.csv --lags=4 --rank=2
```

## residuals

```bash
friedman residuals var var data.csv --lags=2
friedman residuals univariate arima data.csv --p=1 --d=1 --q=1
friedman residuals volatility garch data.csv --column=1 --p=1 --q=1
friedman residuals var vecm data.csv --lags=4 --rank=2
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

### Volatility Models (`volatility arch`, `garch`, `egarch`, `gjr-garch`, `sv`)

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

`predict choice logit` and `predict choice probit` support additional flags for alternative output:

| Flag | Description |
|------|-------------|
| `--marginal-effects` | Output average marginal effects instead of fitted probabilities |
| `--odds-ratio` | Output odds ratio table (logit only) |
| `--classification-table` | Output classification metrics plus the confusion matrix |
| `--threshold` | Classification threshold (option, default `0.5`; used with `--classification-table`) |

`--marginal-effects`, `--odds-ratio` and `--classification-table` are boolean flags —
pass them bare, without a value. They are mutually exclusive with the default
fitted-values output. `--threshold` takes a value.

### Panel Regression Models (`panel preg`, `piv`, `plogit`, `pprobit`)

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

`predict choice ologit`, `predict choice oprobit`, and `predict choice mlogit` return one predicted-probability
column per category (`prob_<category>`), plus an `observation` index.

`residuals choice ologit`, `residuals choice oprobit` and `residuals choice mlogit` return one residual column
per category (`resid_<category>`), plus an `observation` index — a `J`-category response
has `J` residuals per observation, so there is no meaningful single `residual` column.
`--kind` selects the definition:

| `--kind` | Meaning |
|---|---|
| `response` (default) | `dᵢⱼ − P̂ᵢⱼ`; each row sums to zero |
| `pearson` | `rᵢⱼ / sqrt(P̂ᵢⱼ(1−P̂ᵢⱼ))` |
| `deviance` | signed contributions whose sum of squares is `−2·loglik` |

For the **ordered** models only, `--generalized` replaces that matrix with the length-`n`
generalized (score) residual of Chesher & Irish (1987) — `eᵢ = ∂ℓᵢ/∂(xᵢ'β)`, the quantity
that makes outer-product-of-gradients LM specification tests work, and the direct analogue
of the binary models' `yᵢ − p̂ᵢ`. The flag is deliberately **not** offered on `mlogit`:
an unordered response has no meaningful length-`n` scalar residual, and its per-alternative
`response` residuals already *are* its generalized residuals. Passing it there is a usage
error (exit 2).

!!! note "Enabled in CLI v0.9.1"
    These three leaves previously exited `model/unsupported` (exit 5) because
    MacroEconometricModels 0.7.0 defined no `residuals` method for ordered or multinomial
    models. [MEMs#507](https://github.com/FriedmanJP/MacroEconometricModels.jl/issues/507)
    settled both the definition and the return shape in 0.7.2.

## State space: `predict regression statespace`, `residuals regression statespace`

A structural state-space model has no single vector of "fitted values": it has a **state
path**, one series per state (a local level has one state, a local linear trend has two).
`predict regression statespace` therefore emits a tidy long table `period | state | filtered | smoothed`
— the Kalman-filtered `a_{t|t}` and the smoothed `a_{t|T}` side by side, so the same table
shape serves both models and the row count grows with the number of states rather than the
column set. `--state filtered|smoothed` restricts the output to one of the two.

`residuals regression statespace` emits the one-step-ahead prediction errors `v_t = y_t − Z a_{t|t−1}`
(`period | residual`). `--standardized` divides by `sqrt(F_t)` instead, which is the form to
use for diagnostic checking — the raw innovations are heteroskedastic while the filter
converges out of its diffuse initialisation.

The model type is selected with **`--kind`**, not `--model`: on `predict`/`residuals`,
`--model` is reserved for a saved model handle. Options otherwise mirror
[`estimate regression statespace`](estimate.md#estimate-statespace).

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--kind` | | String | `local-level` | `local-level`, `local-linear-trend` |
| `--init-mode` | | String | `kappa` | `kappa`, `diffuse` |
| `--kappa` | | Float | `1e6` | Large-κ diffuse prior variance |
| `--state` | | String | `both` | `filtered`, `smoothed`, `both` (predict only) |
| `--standardized` | | Flag | off | Standardized innovations `v_t/√F_t` (residuals only) |

```bash
friedman predict regression statespace y.csv --kind local-linear-trend
friedman predict regression statespace y.csv --state smoothed
friedman residuals regression statespace y.csv --standardized
```

## Nonlinear time series: `residuals regime setar | star | ms-ar | ms`, `predict`/`forecast regime ms | ms-ar`

All four have a `residuals` leaf. **`predict` and `forecast` exist for the Markov-switching
models only** (`ms`, `ms-ar`) — SETAR and STAR still have neither, and that asymmetry is
upstream, not a design choice here: MacroEconometricModels defines `predict`/`forecast` for
`MSRegModel` but not for `ThresholdModel` or `STARModel`.

!!! note "Added in CLI v0.9.1"
    `predict regime ms|ms-ar` and `forecast regime ms|ms-ar` were previously absent because upstream stored
    no fitted values and offered no Markov-switching forecast.
    [MEMs#510](https://github.com/FriedmanJP/MacroEconometricModels.jl/issues/510) shipped both
    in 0.7.2.

### `predict regime ms | ms-ar`

Emits the regime-probability-weighted conditional mean `ŷₜ = Σₖ Pr(sₜ=k) · E[yₜ | sₜ=k]` as a
tidy `t | fitted` table. `--probs` chooses the weighting:

| `--probs` | Meaning |
|---|---|
| `smoothed` (default) | uses the full sample; `y − fitted` reproduces `residuals` exactly |
| `filtered` | the real-time analogue, using information up to `t` only |

The two are genuinely different series, so `predict --probs filtered` is **not** a restatement
of `residuals`: only the smoothed weighting satisfies the residual identity.

### `forecast regime ms | ms-ar`

`forecast regime ms-ar` projects the model itself over `--horizons`. The path is the exact analytic
conditional mean; because the predictive density is a Gaussian *mixture* over regime paths, the
bands come from simulating `--reps` regime paths at `--ci-level`. Two tables are emitted: the
tidy forecast path, and the `h × K` **predicted regime probabilities** `ξ_{t+h|t} = (P')ʰ ξ_{t|t}`.

`forecast regime ms` is a switching **regression**, which cannot project itself — it needs future
regressors. Pass them with `--x-future <csv>` (`h` rows × `k` columns, matching the fitted
design). The one exception is an intercept-only fit, where the future design is just a column of
ones and `--horizons` alone is enough. A model with regressors and no `--x-future` is a usage
error rather than a guess.

Neither forecast leaf offers `--plot`/`--plot-save`: MacroEconometricModels 0.7.2 ships no
`plot_result` recipe for `MSForecast` (the same gap as `ThresholdForecast`/`STARForecast`).

```bash
friedman predict regime ms-ar y.csv --p 1 --probs filtered
friedman forecast regime ms-ar y.csv --p 1 --horizons 8 --ci-level 0.90
friedman forecast regime ms    data.csv --dep y --x-future future_x.csv
```

Each leaf mirrors its `estimate` sibling's options so any fit that changes the residuals can be
reproduced. Options that affect **only** the attached inference are omitted: `estimate regime setar`'s
`--reps`, `--ci-level` and `--het` drive the Hansen bootstrap and the threshold confidence
interval, neither of which touches the residuals, so `residuals regime setar` does not accept them and
skips that bootstrap entirely.

Output is one tidy `period | residual` table. **`period` is the effective-sample index**, not
calendar time: SETAR, STAR and MS-AR all drop leading observations to build their lag matrices,
so `residuals regime setar --p 3` returns three fewer rows than the input. The MS *regression* is fit on
levels and drops nothing.

```bash
friedman residuals regime setar y.csv --p 1 --d auto
friedman residuals regime star  y.csv --p 1 --type lstr1
friedman residuals regime ms-ar y.csv --p 1 --k-regimes 3
friedman residuals regime ms    data.csv --dep y
```

## Count models: `predict choice poisson | nbreg`, `residuals choice poisson | nbreg`

`predict` returns the conditional mean `μ̂ᵢ = exp(xᵢ'β̂ + offsetᵢ)` as an `observation | fitted`
table; `residuals` returns `yᵢ − μ̂ᵢ` as `observation | residual`.

Both leaves mirror their `estimate` sibling's fit options so the refit matches
([`estimate choice poisson`](estimate.md#estimate-poisson) /
[`estimate choice nbreg`](estimate.md#estimate-nbreg)), including `--offset` / `--exposure`. The
reporting-only options are omitted: `--irr` and `--conf-level` affect the incidence-rate-ratio
table, which neither verb emits.

There is **no `--kind`**: MacroEconometricModels exposes a single residual vector for these
models, so offering a choice would be advertising something the library cannot honour.

```bash
friedman predict choice poisson data.csv --dep claims --exposure policy_years
friedman residuals choice nbreg   data.csv --dep claims
```

## Systems: `predict regression sur | 3sls`, `residuals regression sur | 3sls`

SUR and 3SLS carry **per-equation** fitted values and residuals. Both verbs render them as
**one tidy long table** — `equation | t | fitted` (resp. `residual`) — rather than one
table per equation, so the envelope key set does not change with the number of equations
in your config.

The equation system lives in the `--config` TOML, so **`--config` is required**: without it
there is nothing to refit. The other options mirror the matching `estimate` leaf
(`--iterate`/`--no-intercept` for SUR, `--instruments`/`--no-intercept` for 3SLS).

```bash
friedman predict regression sur data.csv --config system.toml
friedman residuals regression 3sls data.csv --config system.toml --instruments=common
```
