# [Nowcasting & Forecast Evaluation](@id chap-nowcast)

Real-time mixed-frequency nowcasting with ragged-edge data releases and formal multi-model forecast evaluation live in [`frdc nowcast`](@ref ref-nowcast) (`dfm`, `bvar`, `bridge`, `news`, `forecast`) and [`frdc forecast evaluate`](@ref ref-fam-forecast-evaluate) (`metrics`, `dm`, `clark-west`, `mincer-zarnowitz`, `encompassing`, `combine`). See [MacroEconometricModels.jl — Nowcasting](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/nowcasting/) and [Forecast Evaluation](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/forecast_evaluation/) for upstream derivations.

## Quick Start

Estimate a mixed-frequency dynamic factor nowcast (`nowcast dfm`) on a monthly-quarterly ragged-edge panel with two monthly indicators (`m1`, `m2`) and one quarterly target (`gdp`) observed every third month with missing trailing months (`NaN`):

<!-- capture -->
```bash
cat > ragged.csv <<'EOF'
m1,m2,gdp
0.12,-0.08,NaN
0.25,0.10,NaN
0.40,0.22,0.55
0.18,0.05,NaN
-0.10,-0.15,NaN
-0.22,-0.18,-0.25
0.05,0.12,NaN
0.31,0.28,NaN
0.44,0.35,0.62
0.29,0.19,NaN
0.11,-0.04,NaN
-0.08,-0.12,0.02
0.14,0.09,NaN
0.37,0.24,NaN
0.49,0.40,0.71
0.21,0.11,NaN
0.02,-0.06,NaN
-0.15,-0.19,-0.18
0.19,0.14,NaN
0.34,0.26,NaN
0.52,0.38,0.78
0.28,0.17,NaN
0.09,0.03,NaN
0.16,0.11,NaN
EOF
frdc nowcast dfm ragged.csv --monthly-vars 2 --quarterly-vars 1 --factors 1 --lags 1 --max-iter 50 --target-var 3
```
```text
Nowcast DFM (r=1, p=1, target=gdp)
┌────────────────┬──────────┐
│     metric     │  value   │
├────────────────┼──────────┤
│    nowcast     │ 0.197516 │
│    forecast    │ 0.34259  │
│ log-likelihood │  -39.06  │
│ EM iterations  │   50.0   │
└────────────────┴──────────┘
```

Under `--format json`, the estimator writes filtered latent factors and the reconstructed low-frequency `gdp` path into `nowcast_dfm` (`nowcast = 0.197516`, `forecast = 0.34259`, `log-likelihood = -39.06`).

---

## Mixed-Frequency Nowcasting & News Decomposition (`nowcast`)

Real-time monthly indicators $x_t^M$ arrive weeks ahead of quarterly GDP $y_t^Q$, creating staggered missing blocks at the sample end (the **ragged edge**). Mixed-frequency nowcasting links monthly latent states $F_t$ to quarterly flow observations via Mariano–Murasawa temporal aggregation weights:

```math
y_t^Q \approx \frac{1}{3}y_t^* + \frac{2}{3}y_{t-1}^* + y_{t-2}^* + \frac{2}{3}y_{t-3}^* + \frac{1}{3}y_{t-4}^*, \qquad F_t = \sum_{\ell=1}^p A_\ell F_{t-\ell} + u_t.
```

| Command | Estimator & Inputs | Output Tables (`--format json`) |
|---|---|---|
| [`nowcast dfm`](@ref ref-nowcast-dfm) | Kalman–EM dynamic factors (`--factors`, `--lags`, `--idio`) | `nowcast_dfm` |
| [`nowcast bvar`](@ref ref-nowcast-bvar) | Mixed-frequency Minnesota BVAR (`--prior conjugate\|litterman`, `--lambda0`) | `nowcast_bvar`, `nowcast_bvar_hyperparameters` |
| [`nowcast bridge`](@ref ref-nowcast-bridge) | Bridge OLS equations (`--lag-m`, `--lag-q`, `--lag-y`) | `nowcast_bridge` |
| [`nowcast forecast`](@ref ref-nowcast-forecast) | Multi-step quarterly projection (`--method dfm\|bvar\|bridge`, `--horizons`) | `nowcast_forecast` |
| [`nowcast news`](@ref ref-nowcast-news) | Banbura–Modugno release impact decomposition between `--data-old` and `--data-new` | `nowcast_news_decomposition` |

Always supply contiguous CSV/handle columns ordered monthly indicators first (`--monthly-vars`) followed by quarterly series (`--quarterly-vars`), with `NaN` filling unobserved monthly quarters. When `--monthly-vars 0` and `--quarterly-vars 0` (defaults), Friedman-cli infers the block split automatically from the pattern of missing rows.

---

## Forecast Accuracy, Hypothesis Tests & Combination (`forecast evaluate`)

Given realized series $y_t$ (`--actual`) and competing out-of-sample forecasts $\hat{y}_{1,t}, \hat{y}_{2,t}, \dots$ (`--forecasts`), `forecast evaluate` computes point accuracy and Theil MSE decompositions alongside equal-accuracy, nested-model, efficiency, and combination estimators:

```math
d_t = L(e_{1,t}) - L(e_{2,t}), \qquad \mathrm{DM} = \frac{\bar{d}}{\sqrt{\widehat{\mathrm{Var}}(\bar{d})}},
```

with Harvey–Leybourne–Newbold small-sample adjustment enabled by default (disable via `--no-hln`), squared or absolute loss (`--loss se|ad`), and Clark–West drift adjustment for nested models (`clark-west`).

<!-- capture -->
```bash
cat > eval.csv <<'EOF'
y,f1,f2
5.12,5.08,5.55
4.85,4.91,4.20
6.10,6.01,5.45
5.40,5.33,6.12
4.95,5.02,4.35
5.75,5.68,5.10
6.30,6.22,5.80
5.05,5.10,4.55
5.60,5.55,6.05
4.90,4.88,4.40
5.85,5.91,5.20
6.05,5.98,6.50
EOF
frdc forecast evaluate metrics eval.csv --actual y --forecasts f1,f2
```
```text
                                   Forecast Accuracy Metrics
┌───────┬──────────┬──────────┬──────────┬─────────┬─────────┬──────────┬──────────┬──────────┐
│ model │    ME    │   MAE    │   RMSE   │  MAPE   │  sMAPE  │   MASE   │    U1    │    U2    │
├───────┼──────────┼──────────┼──────────┼─────────┼─────────┼──────────┼──────────┼──────────┤
│  f1   │ 0.020833 │ 0.060833 │ 0.063443 │ 1.0971  │ 1.09893 │ 0.087245 │ 0.005764 │ 0.084453 │
│  f2   │ 0.220833 │  0.5625  │ 0.570694 │ 10.3201 │ 10.5967 │ 0.806714 │ 0.05265  │ 0.754038 │
└───────┴──────────┴──────────┴──────────┴─────────┴─────────┴──────────┴──────────┴──────────┘
          Theil MSE Decomposition
┌───────┬──────────┬──────────┬────────────┐
│ model │   bias   │ variance │ covariance │
├───────┼──────────┼──────────┼────────────┤
│  f1   │ 0.107833 │ 0.315233 │  0.576934  │
│  f2   │ 0.149735 │ 0.181492 │  0.668774  │
└───────┴──────────┴──────────┴────────────┘
```

[`forecast evaluate metrics`](@ref ref-forecast-evaluate-metrics) emits `forecast_accuracy_metrics` (`f1` achieves `RMSE = 0.063443` and `MAE = 0.060833` vs. `f2`'s `0.570694` and `0.5625`) together with `theil_mse_decomposition` (`bias = 0.107833`, `variance = 0.315233`, `covariance = 0.576934` shares summing to `1.0`). Follow up with [`dm`](@ref ref-forecast-evaluate-dm), [`clark-west`](@ref ref-forecast-evaluate-clark-west) (nested models), [`mincer-zarnowitz`](@ref ref-forecast-evaluate-mincer-zarnowitz) (bias/efficiency), [`encompassing`](@ref ref-forecast-evaluate-encompassing), or [`combine`](@ref ref-forecast-evaluate-combine) (`--method equal|bates-granger|granger-ramanathan`).

---

## Common Pitfalls

1. **Passing quarterly columns ahead of monthly columns in `nowcast`:** The nowcasting block layout assumes the first `--monthly-vars` columns are monthly indicators and the final `--quarterly-vars` columns are low-frequency targets; scrambling column order fails validation or corrupts aggregation weights.
2. **Using standard `dm` instead of `clark-west` on nested models:** Under nested models where excess parameters introduce estimation noise under the null, Diebold–Mariano statistics are undersized; prefer [`forecast evaluate clark-west`](@ref ref-forecast-evaluate-clark-west) with `--alternative greater`.
3. **Providing fewer than two models to `dm`, `clark-west`, or `encompassing`:** Pairwise comparison tests require at least two column names in `--forecasts` (single forecast raises exit `2`, `usage/arity`).

---

## References

- Giannone, D., Reichlin, L., & Small, D. (2008). Nowcasting: The real-time informational content of macroeconomic data. *Journal of Monetary Economics*, 55(4), 665–676.
- Banbura, M., & Modugno, M. (2014). Maximum likelihood estimation of factor models on datasets with arbitrary pattern of missing data. *Journal of Applied Econometrics*, 29(1), 133–160.
- Diebold, F. X., & Mariano, R. S. (1995). Comparing predictive accuracy. *Journal of Business & Economic Statistics*, 13(3), 253–263.
- Clark, T. E., & West, K. D. (2007). Approximately normal tests for equal predictive accuracy in nested models. *Journal of Econometrics*, 138(1), 291–311.
- Upstream manuals: [MacroEconometricModels.jl — Nowcasting](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/nowcasting/), [Forecast Evaluation](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/forecast_evaluation/)
- CLI reference: [`frdc nowcast`](@ref ref-nowcast), [`frdc forecast evaluate`](@ref ref-fam-forecast-evaluate)
