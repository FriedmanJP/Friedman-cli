# predict & residuals

In-sample fitted values (`predict`) and model **residuals** (`residuals`) complete the fit–diagnose loop: `estimate` fits the model, `predict` returns what the fitted model implies for the estimation sample, and `residuals` returns what it leaves unexplained. Every leaf re-estimates the model from the given data file (or reuses a `--model` handle) and then extracts one tidy table.

Shown on the bundled stack-loss dataset (`:stackloss`); status lines go to stderr, the table below is stdout only.

<!-- capture -->
```bash
friedman predict regression reg :stackloss --dep stack.loss
```
```
      OLS Fitted Values
┌─────────────┬──────────────┐
│ observation │ fitted_value │
│    Int64    │   Float64    │
├─────────────┼──────────────┤
│      1      │   38.1252    │
│      2      │   38.7502    │
│      3      │   31.2936    │
│      4      │   21.6992    │
│      5      │   19.4763    │
│      6      │   20.5877    │
│      7      │   17.9492    │
│      8      │   17.9492    │
│      9      │   17.4007    │
│     10      │   16.2185    │
│     11      │   10.5936    │
│     12      │   10.1072    │
│     13      │   14.9685    │
│     14      │   9.20504    │
│      ⋮      │      ⋮       │
└─────────────┴──────────────┘
                7 rows omitted
```

The table carries one fitted value per observation — observation 1 fits 38.1252. The matching `residuals regression reg` invocation returns `y − fitted` on the same refit, so the two verbs reproduce each other exactly for this leaf.

---

## Supported models

Each row names a real leaf — the full registry path reads `predict <family> <model>` (for example `predict multivariate var`). Cross-check any option against the [generated predict reference](generated/predict.md) and the [generated residuals reference](generated/residuals.md).

| Path under `predict` / `residuals` | Model |
|------------------------------------|-------|
| `choice logit` | Binary logit |
| `choice probit` | Binary probit |
| `choice ologit` | Ordered logit |
| `choice oprobit` | Ordered probit |
| `choice mlogit` | Multinomial logit |
| `choice poisson` | Poisson count regression |
| `choice nbreg` | Negative binomial count regression |
| `factor static` | Static factor model (PCA) |
| `factor dynamic` | Dynamic factor model |
| `factor gdfm` | Generalized dynamic factor model |
| `multivariate var` | Frequentist VAR |
| `multivariate bvar` | Bayesian VAR (posterior mean) |
| `multivariate vecm` | Vector error correction model |
| `multivariate favar` | Factor-augmented VAR |
| `panel preg` | Panel regression (FE/RE/pooled) |
| `panel piv` | Panel IV (2SLS) regression |
| `panel plogit` | Panel logit |
| `panel pprobit` | Panel probit |
| `regime setar` † | Self-exciting threshold autoregression |
| `regime star` † | Smooth-transition autoregression |
| `regime ms-ar` | Markov-switching autoregression |
| `regime ms` | Markov-switching regression |
| `regression reg` | OLS/WLS regression |
| `regression statespace` | Structural state-space model |
| `regression sur` | Seemingly unrelated regressions |
| `regression 3sls` | Three-stage least squares |
| `univariate arima` | ARIMA (automatic order selection) |
| `univariate sarima` | Seasonal ARIMA |
| `univariate arfima` | Fractionally integrated ARMA |
| `volatility arch` | ARCH |
| `volatility garch` | GARCH |
| `volatility egarch` | EGARCH |
| `volatility gjr-garch` | GJR-GARCH |
| `volatility igarch` | IGARCH |
| `volatility cgarch` | Component GARCH |
| `volatility aparch` | Asymmetric power ARCH |
| `volatility figarch` | Fractionally integrated GARCH |
| `volatility fiegarch` | Fractionally integrated EGARCH |
| `volatility garch-midas` | GARCH-MIDAS |
| `volatility sv` | Stochastic volatility |
† `regime setar` and `regime star` offer `residuals` only — no `predict` leaf exists for them. Every other row names both verbs.

---

## predict

```bash
friedman predict multivariate var :denmark --lags 2
friedman predict univariate arima :nile --p 1 --d 1 --q 1
friedman predict volatility garch :nile --p 1 --q 1
friedman predict multivariate vecm :denmark --lags 2 --rank 1 --deterministic constant
```

`predict` emits fitted values (conditional means, conditional variances, state paths, or per-category probabilities, depending on the model). The exact table per leaf is declared in the [generated predict reference](generated/predict.md).

---

## residuals

```bash
friedman residuals multivariate var :denmark --lags 2
friedman residuals univariate arima :nile --p 1 --d 1 --q 1
friedman residuals volatility garch :nile --p 1 --q 1
friedman residuals multivariate vecm :denmark --lags 2 --rank 1 --deterministic constant
```

`residuals` emits the matching residual vector: response residuals for regressions and choice models, standardized innovations for volatility models, one-step prediction errors for state-space models, and per-category matrices for ordered and multinomial models. Table keys live in the [generated residuals reference](generated/residuals.md).

---

## Common options

Every leaf accepts `--format`/`-f` (`table`, `csv`, `json`), `--output`/`-o` (export path), and `--model` (a saved-model handle that skips re-estimation). Pass handles as stems without a suffix (`--model var`, never `--model var.jld2`); stdout carries data only, diagnostics go to stderr. The tables below name the model-specific options; defaults and choices live in the [generated predict reference](generated/predict.md) and the [generated residuals reference](generated/residuals.md), never here.

### VAR / BVAR

| Option | Short | Description |
|--------|-------|-------------|
| `--lags` | `-p` | Lag order (VAR auto-selects when omitted) |
| `--draws` | `-n` | BVAR posterior draws |
| `--sampler` | | BVAR sampler |
| `--config` | | BVAR TOML prior config |

### ARIMA

| Option | Short | Description |
|--------|-------|-------------|
| `--column` | `-c` | Column index |
| `--p` | | AR order (omit for automatic selection) |
| `--d` | | Differencing order |
| `--q` | | MA order |
| `--method` | `-m` | `ols`, `css`, `mle`, or `css_mle` |

| Flag | Description |
|------|-------------|
| `--auto` | Force automatic order selection even when orders are given |

Omitting `--p` (or passing `--auto`) runs automatic order selection and reports the selected orders on stderr. The `sarima` and `arfima` leaves carry their full estimator option sets (seasonal and fractional-integration options) — see the generated reference.

### VECM

| Option | Short | Description |
|--------|-------|-------------|
| `--lags` | `-p` | Lag order |
| `--rank` | `-r` | Cointegration rank (`auto` selects) |
| `--deterministic` | | `none`, `constant`, or `trend` |

### Volatility models

| Option | Leaves | Description |
|--------|--------|-------------|
| `--column` | all | Column index (`-c`) |
| `--q` | `arch` | ARCH order |
| `--p`, `--q` | `garch`/`egarch`/`gjr-garch` | GARCH and ARCH orders |
| `--draws` | `sv` | MCMC draws (`-n`) |

The plain leaves refit at Gaussian-QMLE defaults with no `--dist` option (matches `estimate`: only `garch`/`egarch`/`gjr-garch` take a conditional distribution there, and the fitted refit path always uses the default). The extended GARCH leaves (`igarch`, `cgarch`, `aparch`, `figarch`, `fiegarch`, `garch-midas`) declare their own estimator options; see the generated reference. `predict` returns conditional variances with implied volatilities; `residuals` returns standardized residuals.

### Factor models

| Option | Short | Description |
|--------|-------|-------------|
| `--nfactors` | `-r` | Number of factors (static and dynamic; auto via IC when omitted) |
| `--factor-lags` | `-p` | Factor VAR lag order (dynamic only) |
| `--method` | | `twostep` or `qml` estimation (dynamic only) |
| `--dynamic-rank` | `-q` | Dynamic rank (gdfm; auto when omitted) |

### FAVAR

| Option | Short | Description |
|--------|-------|-------------|
| `--factors` | `-r` | Number of factors |
| `--lags` | `-p` | VAR lags |
| `--key-vars` | | Key observed variables |

### Regression and binary choice (`reg`, `logit`, `probit`)

| Option | Short | Description |
|--------|-------|-------------|
| `--dep` | | Dependent variable column name |
| `--cov-type` | | Covariance estimator |
| `--clusters` | | Cluster variable column name |
| `--weights` | | Weights column (`reg` only; WLS) |

### Logit / probit predict flags

`predict choice logit` and `predict choice probit` support additional flags for alternative output:

| Flag | Description |
|------|-------------|
| `--marginal-effects` | Output average marginal effects instead of fitted probabilities |
| `--odds-ratio` | Output odds ratio table (logit only) |
| `--classification-table` | Output classification metrics plus the confusion matrix |
| `--threshold` | Classification threshold (option, default `0.5`; used with `--classification-table`) |

`--marginal-effects`, `--odds-ratio` and `--classification-table` are boolean flags —
pass them bare, without a value. They are mutually exclusive with the default
fitted-values output. `--threshold` takes a value. `probit` offers everything except `--odds-ratio`.

### Panel models (`preg`, `piv`, `plogit`, `pprobit`)

`preg` takes the shared panel set:

| Option | Short | Description |
|--------|-------|-------------|
| `--dep` | | Dependent variable column name |
| `--indep` | | Independent variables (comma-separated) |
| `--id-col` | | Panel group identifier column |
| `--time-col` | | Panel time identifier column |
| `--cov-type` | | Covariance estimator |
| `--method` | `-m` | Estimation method (default `fe`) |

`piv` replaces `--indep` with the IV split (mirrors `estimate panel piv`):

| Option | Short | Description |
|--------|-------|-------------|
| `--dep` | | Dependent variable column name |
| `--exog` | | Exogenous variables (comma-separated) |
| `--endog` | | Endogenous variables (comma-separated, required) |
| `--instruments` | | Instruments (comma-separated) |
| `--id-col` | | Panel group identifier column |
| `--time-col` | | Panel time identifier column |
| `--cov-type` | | Covariance estimator |
| `--method` | `-m` | `fe`, `re`, `fd`, or `hausman-taylor` (default `fe`) |

`plogit`/`pprobit` take the shared panel set with `--method` defaulting to `pooled` (upstream default; probit has no fixed-effects estimator at all).

### Ordered and multinomial models (`ologit`, `oprobit`, `mlogit`)

| Option | Short | Description |
|--------|-------|-------------|
| `--dep` | | Dependent variable column name |
| `--cov-type` | | Covariance estimator |
| `--clusters` | | Cluster variable column name |

`predict choice ologit`, `predict choice oprobit` and `predict choice mlogit` return one predicted-probability
column per category (`prob_<category>`), plus an `observation` index. Each also accepts a bare `--marginal-effects`
flag that appends per-category average marginal effects (delta-method standard errors).

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

---

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
[`estimate regression statespace`](estimate.md#estimate-regression-statespace).

| Option | Short | Description |
|--------|-------|-------------|
| `--column` | `-c` | Column index (1-based) |
| `--kind` | | `local-level`, `local-linear-trend` |
| `--init-mode` | | `kappa`, `diffuse` |
| `--kappa` | | Large-κ diffuse prior variance |
| `--state` | | `filtered`, `smoothed`, `both` (predict only) |
| `--standardized` | | Standardized innovations `v_t/√F_t` (residuals flag) |

```bash
friedman predict regression statespace :nile --kind local-linear-trend
friedman predict regression statespace :nile --state smoothed
friedman residuals regression statespace :nile --standardized
```

---

## Nonlinear regime: `residuals regime setar | star | ms-ar | ms`, `predict regime ms | ms-ar`

All four regime models have a `residuals` leaf. **`predict` exists for the Markov-switching
models only** (`ms`, `ms-ar`) — SETAR and STAR have no `predict` leaf, because upstream
exposes fitted values for `MSRegModel` but not for `ThresholdModel` or `STARModel`.
All four have `forecast` leaves under [forecast](forecast.md) (SETAR/STAR via
bootstrap simulation, MS/MS-AR via regime-path simulation).

### `predict regime ms | ms-ar`

Emits the regime-probability-weighted conditional mean `ŷₜ = Σₖ Pr(sₜ=k) · E[yₜ | sₜ=k]` as a
tidy `t | fitted` table. `--probs` chooses the weighting:

| `--probs` | Meaning |
|---|---|
| `smoothed` (default) | uses the full sample; `y − fitted` reproduces `residuals` exactly |
| `filtered` | the real-time analogue, using information up to `t` only |

The two are genuinely different series, so `predict --probs filtered` is **not** a restatement
of `residuals`: only the smoothed weighting satisfies the residual identity.

`ms-ar` accepts a `--switching-variance` flag (variances switch across regimes when passed;
the Hamilton constant-variance form is the default). `ms` takes the opposite polarity —
variance switches by default, and `--no-switching-variance` forces a common `σ²`.

```bash
friedman predict regime ms-ar :nile --p 1 --probs filtered
friedman residuals regime setar :nile --p 1 --d auto
friedman residuals regime star :nile --p 1 --type lstr1
friedman residuals regime ms-ar :nile --p 1 --k-regimes 3
friedman residuals regime ms :stackloss --dep stack.loss --k-regimes 2
```

Each `residuals` leaf mirrors its `estimate` sibling's fit options so any fit that changes the residuals can be
reproduced. Options that affect **only** the attached inference are omitted: `estimate regime setar`'s
`--reps`, `--ci-level` and `--het` drive the Hansen bootstrap and the threshold confidence
interval, neither of which touches the residuals, so `residuals regime setar` does not accept them and
skips that bootstrap entirely.

Output is one tidy `period | residual` table. **`period` is the effective-sample index**, not
calendar time: SETAR, STAR and MS-AR all drop leading observations to build their lag matrices,
so `residuals regime setar --p 3` returns three fewer rows than the input. The MS *regression* is fit on
levels and drops nothing.

---

## Count models: `predict choice poisson | nbreg`, `residuals choice poisson | nbreg`

`predict` returns the conditional mean `μ̂ᵢ = exp(xᵢ'β̂ + offsetᵢ)` as an `observation | fitted`
table; `residuals` returns `yᵢ − μ̂ᵢ` as `observation | residual`.

Both leaves mirror their `estimate` sibling's fit options so the refit matches
([`estimate choice poisson`](estimate.md#estimate-choice-poisson) /
[`estimate choice nbreg`](estimate.md#estimate-choice-nbreg)), including `--offset` / `--exposure`. The
reporting-only options are omitted: `--irr` and `--conf-level` affect the incidence-rate-ratio
table, which neither verb emits.

There is **no `--kind`**: MacroEconometricModels exposes a single residual vector for these
models, so offering a choice would be advertising something the library cannot honour.

```bash
friedman predict choice poisson :mroz --dep kidslt6
friedman residuals choice nbreg :mroz --dep kidslt6
```

---

## Systems: `predict regression sur | 3sls`, `residuals regression sur | 3sls`

SUR and 3SLS carry **per-equation** fitted values and residuals. Both verbs render them as
**one tidy long table** — `equation | t | fitted` (resp. `residual`) — rather than one
table per equation, so the envelope key set does not change with the number of equations
in your config.

The equation system lives in the `--config` TOML, so **`--config` is required**: without it
there is nothing to refit. The other options mirror the matching `estimate` leaf
(`--iterate`/`--no-intercept` for SUR, `--instruments`/`--no-intercept` for 3SLS).

```bash
cat > system.toml <<'EOF'
[[equations]]
name = "loss"
dep = "stack.loss"
indep = ["Air.Flow", "Water.Temp"]
[[equations]]
name = "acid"
dep = "Acid.Conc."
indep = ["Air.Flow", "Water.Temp"]

[instruments]
common = ["Air.Flow", "Water.Temp"]
EOF
friedman predict regression sur :stackloss --config system.toml
friedman residuals regression 3sls :stackloss --config system.toml --instruments common
```

---

## References

- Full option sets and envelope table keys: [generated predict reference](generated/predict.md), [generated residuals reference](generated/residuals.md).
- Fitting the same models: [estimate](estimate.md). Projecting them forward: [forecast](forecast.md).
- Chesher, A., & Irish, M. (1987). Residual analysis in the grouped and censored normal linear model. *Journal of Econometrics*.
