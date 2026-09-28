# forecast

Point and conditional forecasts across multivariate, univariate, regime-switching, factor, and volatility models, plus a nested `forecast evaluate` sub-family for post-hoc evaluation and combination of already-computed forecasts. The full per-leaf option surface lives in the [generated forecast reference](generated/forecast.md); this guide explains which leaf to reach for, what each one assumes, and how to read the result.

---

## Output format

Multivariate, factor, `arima`, `sarima`, `sdfm`, `favar`, `lp`, and `vecm` leaves render through the tidy MEMs `long_table`: one row per `(horizon, variable)` cell with columns `horizon | variable | value | lower | upper`. `lower`/`upper` carry `missing` when the forecast ships no interval (for example under a `none` interval method). Regime-switching `setar`/`star` forecasts are typed `AbstractForecastResult`s and render through the same tidy path.

Three deliberate exceptions keep information the generic schema would drop. `arfima` uses the single-series form (`horizon | forecast | lower | upper`); `midas` adds a standard error (`horizon | forecast | lower | upper | se`) beside a key–value summary table. Volatility forecasts use a domain-specific `horizon | variance | volatility` table (`volatility` is the square root of `variance`). The `evaluate` leaves wrap model-agnostic vector statistics rather than MEMs forecast types, so their tables are hand-built key–value and weight tables described under [`forecast evaluate`](#forecast-evaluate).

---

## forecast multivariate var

H-step-ahead forecasts from a fitted **vector autoregression (VAR)**. The handler fits the VAR first (lag order selected automatically unless `--lags` is given) and reports the point path with analytical or bootstrap intervals at the requested confidence level.

```bash
friedman forecast multivariate var :denmark --horizons 6
friedman forecast multivariate var :denmark --lags 2 --horizons 6
friedman forecast multivariate var :denmark --ci-method bootstrap --horizons 6
```

**Output:** tidy `var_forecast` table (`horizon | variable | value | lower | upper`). Full option set: [generated reference](generated/forecast.md#friedman-forecast-multivariate-var).

---

## forecast multivariate bvar

Forecasts from a fitted **Bayesian VAR**, with posterior credible bands around the point path. `--sampler` selects the posterior simulator and `--config` supplies a TOML file with prior hyperparameters; without it the leaf runs on the default prior.

```bash
friedman forecast multivariate bvar :denmark --horizons 6 --draws 500
friedman forecast multivariate bvar :denmark --horizons 6 --draws 500 --sampler gibbs
```

**Output:** tidy `bvar_forecast` table (`horizon | variable | value | lower | upper`). Full option set: [generated reference](generated/forecast.md#friedman-forecast-multivariate-bvar).

---

## forecast multivariate scenario

**Waggoner–Zha conditional forecasts:** pin some variables to chosen paths and let the model work out everything else, together with the structural shocks that deliver the scenario. `--method` selects which model is fitted first (`var` or `bvar`); the conditional forecast dispatches on that fit.

```bash
cat > scenario.csv <<'EOF'
variable,period,value,sd
LRM,1,0.5,0
LRM,2,0.4,0
LRY,4,0.3,0.5
EOF
friedman forecast multivariate scenario :denmark --conditions-file scenario.csv --horizons 6
friedman forecast multivariate scenario :denmark --conditions-file scenario.csv --method bvar --draws 500 --horizons 6
```

**Conditions file.** A long-format CSV with columns `variable,period,value` and an optional `sd`:

```csv
variable,period,value,sd
LRM,1,0.5,0
LRM,2,0.4,0
LRY,4,0.3,0.5
```

`variable` accepts a CSV column name or a 1-based index; names resolve against the data header to an index before the forecast is conditioned, so either spelling constrains the same series. `period` counts forward from the first forecast period and must lie inside `--horizons`. `sd` controls hardness: `0` (the default when the column is absent or blank) is a **hard condition** pinned exactly with a point interval at that horizon, while a positive `sd` is **soft** and lets the path deviate at a cost. Each `(variable, period)` pair admits at most one condition; unknown names, out-of-range periods, duplicates, and non-finite values are typed data errors.

**Why `--conditions-file`.** `--conditions` is a reserved pre-dispatch global: it prints the GPL conditions notice and is matched as the leading token before leaf parsing, so no leaf option may claim that name. The scenario leaf therefore spells it `--conditions-file`, and `--config` (BVAR prior TOML under `--method bvar`) keeps its usual meaning alongside it. `--lags` defaults to automatic selection under `var` and to 4 under `bvar`; `--replications` sizes the simulation behind the conditional bands and `--confidence` sets their level.

**Paths.** The conditions file passes through the standard input-path validation: with `FRIEDMAN_DATA_ROOT` unset it is an ordinary filesystem path (parent-relative paths and `~` resolve normally); when `FRIEDMAN_DATA_ROOT` is set, the resolved, normalized path must stay inside that root or the leaf exits with `data/bad-path`.

**Output:** three tables — the `conditional_forecast` path carrying the `unconditional` baseline from the same fit beside each conditioned value, the `implied_structural_shocks` delivering it, and the `scenario_settings` diagnostics. Read the scenario against its baseline: both come from the same draws, so the gap is the scenario and nothing else. Then check the shock table before believing the path — a scenario that needs structural shocks far outside their historical range is arithmetically consistent but economically incredible. Full option set: [generated reference](generated/forecast.md#friedman-forecast-multivariate-scenario).

---

## forecast multivariate lp

Direct **local-projection (LP)** forecasts along an impulse path: the handler fits horizon-by-horizon projections for a one-unit (by default) shock to one variable and traces the response. `--shock` selects the shocked variable by index, `--shock-size` scales the impulse, `--lags` sets the control lags, and `--vcov` selects the covariance estimator behind the bands.

```bash
friedman forecast multivariate lp :denmark --shock 1 --horizons 6 --shock-size 1.0
friedman forecast multivariate lp :denmark --shock 1 --horizons 6 --ci-method bootstrap --n-boot 200
```

**Output:** tidy `lp_forecast` table (`horizon | variable | value | lower | upper`); `LPForecast` carries its point path in `.forecast`. Full option set: [generated reference](generated/forecast.md#friedman-forecast-multivariate-lp).

---

## forecast univariate arima

ARIMA forecasts for a single series. Omit `--p` and the leaf selects the AR and MA orders automatically (bounded by `--max-p`/`--max-d`/`--max-q` under `--criterion`); pass `--p`/`--d`/`--q` explicitly to fix the specification. `--method` selects the estimator and `--column` selects the series.

```bash
friedman forecast univariate arima :nile --horizons 6 --confidence 0.95
friedman forecast univariate arima :nile --p 1 --d 1 --q 1 --horizons 6
friedman forecast univariate arima :nile --criterion aic --horizons 6
```

**Output:** tidy `arima_forecast` table (`horizon | variable | value | lower | upper`) with interval bounds. Full option set: [generated reference](generated/forecast.md#friedman-forecast-univariate-arima).

---

## forecast regime setar

Bootstrap-simulation forecasts from a re-estimated **self-exciting threshold autoregression (SETAR)**. The handler fits the two-regime model, simulates forward paths through the fitted dynamics by resampling residuals, and reports the mean path with percentile bands. `--d` accepts an integer delay or `auto` (a `1:p` grid); `--ci-level` must be exactly `0.90`, `0.95`, or `0.99`, the tabulation behind the re-estimated threshold interval.

```bash
friedman forecast regime setar :gnp_hamilton --p 1 --d 1 --horizons 6
friedman forecast regime setar :gnp_hamilton --p 2 --d auto --horizons 6 --ci-level 0.90 --reps 500
```

**Output:** tidy `setar_forecast` table with a single series. This leaf offers no `--plot`/`--plot-save`: upstream ships no plot recipe for the forecast type (only the fitted model plots), so the flags stay undeclared rather than advertised-but-broken. Full option set: [generated reference](generated/forecast.md#friedman-forecast-regime-setar).

---

## forecast regime star

Bootstrap-simulation forecasts from a re-estimated self-exciting **smooth-transition autoregression (STAR)**. `--type` selects the transition shape (`lstr1`, `lstr2`, `estr`, or `auto`). Only self-exciting STARs are forecastable — an external transition variable would need its own future path — so no transition-column option is offered.

```bash
friedman forecast regime star :gnp_hamilton --p 1 --d 1 --horizons 6
friedman forecast regime star :gnp_hamilton --p 2 --type lstr1 --horizons 6 --ci-level 0.90 --reps 500
```

**Output:** tidy `star_forecast` table with a single series. Like `setar`, no `--plot`/`--plot-save`: the forecast type has no upstream plot recipe. Full option set: [generated reference](generated/forecast.md#friedman-forecast-regime-star).

---

## forecast factor static

Forecasts of many observables from a **static factor model (PCA)**: compress the panel to `--nfactors` factors (selected by information criteria when omitted), project forward, and reconstruct the observables. `--ci-method` controls the bands (`none`, `bootstrap`, `parametric`).

```bash
friedman forecast factor static :denmark --horizons 6
friedman forecast factor static :denmark --nfactors 2 --ci-method bootstrap --horizons 6
```

**Output:** tidy `static_factor_forecast` table (`horizon | variable | value | lower | upper`) over the observables. Full option set: [generated reference](generated/forecast.md#friedman-forecast-factor-static).

---

## forecast factor dynamic

Forecasts from a **dynamic factor model**, where the factors themselves follow a VAR of order `--factor-lags`. `--method` selects the factor estimator (`twostep` or `em`); the factor count is automatic unless `--nfactors` is given.

```bash
friedman forecast factor dynamic :denmark --nfactors 2 --factor-lags 1 --horizons 6
```

**Output:** tidy `dynamic_factor_forecast` table over the observables. Full option set: [generated reference](generated/forecast.md#friedman-forecast-factor-dynamic).

---

## forecast factor gdfm

Forecasts from a **generalized dynamic factor model**. `--method` selects the factor projection: `ar` fits an AR(1) on each two-sided factor, while `one-sided` and `spectral` use the Forni–Hallin–Lippi–Reichlin one-sided projection. `--dynamic-rank` and `--nfactors` default to automatic selection, and `--spectral` selects the spectrum estimator behind the decomposition.

```bash
friedman forecast factor gdfm :denmark --dynamic-rank 2 --horizons 6
friedman forecast factor gdfm :denmark --dynamic-rank 2 --horizons 6 --method one-sided
```

**Output:** tidy `gdfm_forecast` table over the observables. Full option set: [generated reference](generated/forecast.md#friedman-forecast-factor-gdfm).

---

## Volatility forecasts

One leaf per volatility model — `arch`, `garch`, `egarch`, `gjr-garch`, and `sv`, plus the extended family (`aparch`, `cgarch`, `figarch`, `fiegarch`, `igarch`, `garch-midas`). Each leaf re-estimates its model on the selected column and projects the conditional variance forward. The GARCH-family leaves accept a conditional innovation distribution (`normal`, `student`, `ged`); `arch` and `sv` are Gaussian-only upstream and declare no such option. `sv` takes MCMC draws instead of lag orders.

```bash
friedman data simulate garch --kind garch --periods 300 -o returns.csv --format csv
friedman forecast volatility garch returns.csv --column 2 --p 1 --q 1 --horizons 6
friedman forecast volatility sv returns.csv --column 2 --draws 500 --horizons 6
```

**Output:** the domain-specific `horizon | variance | volatility` table kept as a deliberate exception to the tidy schema. `garch-midas` instead splits the path into `total_variance | long_run | short_run | volatility` components and declares no interval level or plot flags. Per-leaf option sets (orders and distributions differ across the family): [generated reference](generated/forecast.md).

---

## forecast multivariate vecm

Forecasts from a fitted **vector error-correction model (VECM)** for cointegrated panels. `--lags` is the lag order in levels, `--rank` is the cointegration rank (`auto` selects via the Johansen procedure), and `--deterministic` sets the deterministic terms. Intervals are off by default; `--ci-method` (`bootstrap` or `parametric`) enables them with `--replications` sizing the bootstrap and `--confidence` setting the level.

```bash
friedman forecast multivariate vecm :denmark --horizons 6
friedman forecast multivariate vecm :denmark --rank 1 --deterministic constant --lags 2
friedman forecast multivariate vecm :denmark --ci-method bootstrap --confidence 0.90 --replications 200 --horizons 6
```

**Output:** tidy `vecm_forecast` level forecasts with optional bounds. Full option set: [generated reference](generated/forecast.md#friedman-forecast-multivariate-vecm).

---

## forecast evaluate

Post-hoc evaluation and combination of **already-computed** forecasts. These leaves are model-agnostic: they take realized values plus competing forecast series and wrap the upstream forecast-evaluation toolkit. Every leaf shares one input convention: `data` carries the realized column named by `--actual` (required), and the forecasts arrive either as `--forecasts` columns in the same file or as `--result` forecast-handle stems — never both. `--result` is a comma-separated stem string (not a single-handle option), so `--result fcst_var,fcst_bvar` loads two saved forecasts. Handlers form whatever each statistic needs: errors `e = actual − forecast`, the nested-model gap `f_adj = f_small − f_big` (squared internally), or the `T×M` forecast matrix. Each leaf validates its forecast-count arity (a wrong count is a usage error), unknown columns are `data/bad-column`, and length mismatches are `data/shape`.

```bash
cat > eval.csv <<'EOF'
y,f1,f2,f3
2.10,2.00,2.20,2.05
1.80,1.90,1.70,1.85
2.40,2.30,2.50,2.35
1.50,1.60,1.40,1.55
2.00,1.95,2.10,2.02
2.60,2.50,2.70,2.58
1.90,2.00,1.80,1.92
2.20,2.10,2.30,2.18
1.70,1.75,1.65,1.72
2.50,2.40,2.60,2.48
2.30,2.25,2.35,2.31
1.60,1.65,1.55,1.62
2.05,2.00,2.10,2.04
1.95,1.90,2.00,1.93
EOF
friedman forecast evaluate metrics eval.csv --actual y --forecasts f1,f2,f3
friedman forecast evaluate dm eval.csv --actual y --forecasts f1,f2 --loss se --horizon 1
friedman forecast evaluate clark-west eval.csv --actual y --forecasts f1,f2
friedman forecast evaluate mincer-zarnowitz eval.csv --actual y --forecasts f1 --lags 4
friedman forecast evaluate combine eval.csv --actual y --forecasts f1,f2,f3 --method bates-granger
```

Saved result handles work the same way, with the forecast length matching the realized column:

```bash
friedman data simulate var --periods 60 -o macro.csv --format csv
friedman forecast multivariate var macro.csv --horizons 60 --save-result fcst_var
friedman forecast multivariate var macro.csv --horizons 60 --lags 1 --save-result fcst_bvar
friedman forecast evaluate metrics macro.csv --actual y1 --result fcst_var,fcst_bvar
```

### forecast evaluate metrics

Point-accuracy metrics per forecast — **ME**, **MAE**, **RMSE**, **MAPE**, **sMAPE**, **MASE**, and Theil **U1**/**U2** — plus the Theil mean-squared-error decomposition into **bias**, **variance**, and **covariance** proportions (summing to 1). Errors follow `e = actual − forecast`; MAPE and sMAPE skip near-zero denominators, and `--seasonal-period` sets the naive-forecast lag behind the MASE scaling. Takes one or more forecasts. This is the only `evaluate` leaf with plot flags.

**Output:** a wide accuracy table (one row per forecast) and the Theil decomposition table. Full option set: [generated reference](generated/forecast.md#friedman-forecast-evaluate-metrics).

### forecast evaluate dm

The **Diebold–Mariano (1995)** test of equal predictive accuracy between exactly two forecasts. The loss differential is `d = g(e1) − g(e2)` with `--loss` selecting squared (`se`) or absolute (`ad`) loss; the null is equal accuracy (`E[d] = 0`). A positive statistic means the first forecast carries the larger average loss. `--horizon` sets the truncation lag `h − 1` of the long-run variance. By default the Harvey–Leybourne–Newbold small-sample correction applies (statistic referenced to `t_{T−1}`); `--no-hln` disables it in favour of `N(0,1)`. The test is invalid for nested models — use `clark-west` there.

**Output:** a `metric | value` table (statistic, p-value, mean loss differential, long-run variance, horizon, HLN flag, alternative, n). Full option set: [generated reference](generated/forecast.md#friedman-forecast-evaluate-dm).

### forecast evaluate clark-west

The **Clark–West (2007)** adjusted-MSPE test for **nested** models, taking exactly two forecasts ordered small (restricted) then big (unrestricted). It forms the adjusted differential `f̂ = e_small² − (e_big² − f_adj²)` with `f_adj = f_small − f_big`, and tests the null that the big model does not improve MSPE (`E[f̂] ≤ 0`) against the one-sided `greater` alternative, referenced to the standard normal. This is the correct test exactly where Diebold–Mariano is invalid.

**Output:** a `metric | value` table (statistic, p-value, mean adjusted differential, long-run variance, horizon, alternative, n). Full option set: [generated reference](generated/forecast.md#friedman-forecast-evaluate-clark-west).

### forecast evaluate mincer-zarnowitz

The **Mincer–Zarnowitz (1969)** forecast-efficiency regression `actual = a + b·fc + u` on exactly one forecast, jointly testing `(a, b) = (0, 1)`: a weakly efficient forecast needs intercept 0 and slope 1. `--lags` sets the Newey–West HAC truncation lag (`0` gives the White covariance) with `--kernel` selecting the kernel. Reports both the χ²(2) Wald statistic and the equivalent `F(2, T−2)`.

**Output:** a `metric | value` table (`a`, `b`, HAC standard errors, Wald χ²(2) and p-value, `F` and p-value, HAC lags, kernel, n). Full option set: [generated reference](generated/forecast.md#friedman-forecast-evaluate-mincer-zarnowitz).

### forecast evaluate encompassing

The regression-based **forecast-encompassing test (Harvey–Leybourne–Newbold 1998)** on exactly two forecasts. It estimates `actual = a + b₁·fc1 + b₂·fc2 + u` with a Newey–West HAC covariance (`--lags`, `--kernel`; `0` gives White) and tests `b₂ = 0` with a two-sided `t_{T−3}` p-value. Non-rejection means the first forecast encompasses the second — the second carries no incremental information.

**Output:** a `metric | value` table (`b1`, `b2`, HAC `se(b2)`, t-statistic, p-value, HAC lags, kernel, n). Full option set: [generated reference](generated/forecast.md#friedman-forecast-evaluate-encompassing).

### forecast evaluate combine

Combines two or more forecasts into one series. `equal` averages; `bates-granger` uses inverse-MSE weights (ignoring cross-forecast error correlation); `granger-ramanathan` runs constrained least squares minimizing `‖actual − F·w‖²` subject to weights summing to 1 — those weights may be negative, by construction. `--emit-series` additionally emits the combined series itself.

**Output:** a `model | weight | mse` table (weights sum to 1), plus an `index | combined` table under `--emit-series`. Full option set: [generated reference](generated/forecast.md#friedman-forecast-evaluate-combine).

---

## Beyond this page

`forecast` also serves `univariate arfima`, `univariate sarima`, `univariate midas`, `regime ms`, `regime ms-ar`, `factor sdfm`, and `multivariate favar` — the same tidy forecast table, except that `arfima` uses the single-series `horizon | forecast | lower | upper` form, `midas` adds a standard error with a summary table, and the `ms` leaves add a predicted-regime-probabilities table. Per-leaf options live in the [generated forecast reference](generated/forecast.md). FAVAR and structural-DFM forecasting are additionally covered from the model side in the [favar & sdfm guide](favar.md); DSGE forecasting runs through simulation in the [dsge guide](dsge.md#dsge-simulate).

---

## References

- [Generated forecast reference](generated/forecast.md) — authoritative per-leaf options, defaults, and output-table keys.
- [Command overview](overview.md) — the full action-first tree.
- [favar & sdfm guide](favar.md) — FAVAR and structural-DFM forecasting alongside identification and decomposition.
- [dsge guide](dsge.md#dsge-simulate) — DSGE forecasting via simulation.
- Diebold, F. X. and Mariano, R. S. (1995). Comparing predictive accuracy. *Journal of Business & Economic Statistics*.
- Clark, T. E. and West, K. D. (2007). Approximately normal tests for equal predictive accuracy in nested models. *Journal of Econometrics*.
- Mincer, J. A. and Zarnowitz, V. (1969). The evaluation of economic forecasts. In *Economic Forecasts and Expectations*.
- Harvey, D., Leybourne, S. and Newbold, P. (1997). Testing the equality of prediction mean squared errors. *International Journal of Forecasting*.
- Harvey, D., Leybourne, S. and Newbold, P. (1998). Tests for forecast encompassing. *Journal of Business & Economic Statistics*.
- Bates, J. M. and Granger, C. W. J. (1969). The combination of forecasts. *Operational Research Quarterly*.
- Granger, C. W. J. and Ramanathan, R. (1984). Improved methods of combining forecasts. *Journal of Forecasting*.
- Waggoner, D. F. and Zha, T. (1999). Conditional forecasts in dynamic multivariate models. *Review of Economics and Statistics*.
- Forni, M., Hallin, M., Lippi, M. and Reichlin, L. (2005). The generalized dynamic factor model. *Journal of the American Statistical Association*.
