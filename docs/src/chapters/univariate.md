# [Univariate, Filters & Spectral](@id chap-univariate)

Single-series macroeconomic analysis in `Friedman-cli` spans trend-cycle decomposition ([`friedman filter`](@ref ref-filter)), nonparametric and filter frequency-domain diagnostics ([`friedman spectral`](@ref ref-spectral)), Box–Jenkins, fractional, mixed-frequency, and distributed-lag estimators ([`estimate univariate`](@ref ref-fam-estimate-univariate)), general Gaussian state-space filtering ([`estimate regression statespace`](@ref ref-estimate-regression-statespace)), and time-varying parameter regressions ([`estimate regime tvp`](@ref ref-estimate-regime-tvp)). See [MacroEconometricModels.jl — Univariate & Filters](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/filters/) for mathematical details.

## Quick Start

Decompose U.S. real GNP (`:gnp_hamilton`) with the Hamilton regression filter, inspect spectral power, and fit an automatic BIC ARIMA model with 4-step forecasts:

<!-- capture -->
```bash
friedman estimate univariate arima :gnp_hamilton --criterion bic
```
```text
            AR(1) Coefficients (gnp_growth)
┌───────────┬──────────┬───────────┬─────────┬─────────┐
│ parameter │ estimate │ std_error │ z_stat  │ p_value │
│  String   │ Float64  │  Float64  │ Float64 │ Float64 │
├───────────┼──────────┼───────────┼─────────┼─────────┤
│    ar1    │ 0.493056 │ 0.146847  │  3.358  │ 0.0008  │
│  const2   │ 0.34205  │ 0.089359  │  3.828  │ 0.0001  │
└───────────┴──────────┴───────────┴─────────┴─────────┘
    Information Criteria
┌────────────────┬──────────┐
│     metric     │  value   │
│     String     │ Float64  │
├────────────────┼──────────┤
│      AIC       │ 390.029  │
│      BIC       │ 398.744  │
│ Log-likelihood │ -192.014 │
└────────────────┴──────────┘
```

The command returns both `arima_coefficients` and `information_criteria` in `--format json` (pass `--save-model arima_fit` to reuse the fitted object in [`predict univariate arima`](@ref ref-predict-univariate-arima), [`residuals univariate arima`](@ref ref-residuals-univariate-arima), and [`forecast univariate arima`](@ref ref-forecast-univariate-arima)).

---

## Economic Time-Series Filters

A trend-cycle decomposition separates an observable series $y_t$ into a stochastic or smooth trend $\tau_t$ and a stationary cyclical component $c_t = y_t - \tau_t$. The Hodrick–Prescott (HP) filter solves

```math
\min_{\{\tau_t\}} \sum_{t=1}^T (y_t - \tau_t)^2 + \lambda \sum_{t=2}^{T-1} \left[(\tau_{t+1}-\tau_t) - (\tau_t-\tau_{t-1})\right]^2,
```

while Hamilton (2018) avoids spurious end-of-sample cycles by projecting $y_{t+h}$ onto $(1, y_t, \dots, y_{t-p+1})$, boosted HP (`bhp`) iterates HP to whiten cycles until ADF or BIC convergence, Beveridge–Nelson (`bn`) extracts long-horizon conditional expectations, Baxter–King (`bk`) isolates business-cycle frequencies, and X-13ARIMA-SEATS (`x13`) extracts seasonal factors.

| Filter Leaf | Key Hyperparameters | Output Table Key (`--format json`) |
|---|---|---|
| [`filter hp`](@ref ref-filter-hp) | `--lambda` (`1600.0` quarterly) | `hp_filter` |
| [`filter bhp`](@ref ref-filter-bhp) | `--stopping BIC\|ADF\|fixed`, `--max-iter` | `boosted_hp_filter` |
| [`filter hamilton`](@ref ref-filter-hamilton) | `--horizon 8`, `--lags 4` | `hamilton_filter` |
| [`filter bn`](@ref ref-filter-bn) | `--method arima\|statespace`, `--p`, `--q` | `beveridge_nelson_decomposition` |
| [`filter bk`](@ref ref-filter-bk) | `--pl 6`, `--pu 32`, `--K 12` | `baxter_king_filter` |
| [`filter x13`](@ref ref-filter-x13) | `--frequency 12`, `--method seats\|x11` | `x_13_seasonally_adjusted` (and 4 sibling tables) |

<!-- capture -->
```bash
friedman filter hp :gnp_hamilton --lambda 1600
```
```text
             HP Filter (λ=1600.0)
┌───────┬──────────────────┬──────────────────┐
│   t   │ gnp_growth_trend │ gnp_growth_cycle │
│ Int64 │     Float64      │     Float64      │
├───────┼──────────────────┼──────────────────┤
│   1   │     1.34338      │     1.24982      │
│   2   │     1.26205      │     0.940153     │
│   3   │     1.18149      │    -0.723191     │
│   4   │     1.10309      │    -0.134385     │
│   5   │     1.02775      │     -1.26905     │
│   6   │     0.956306     │    -0.059806     │
│   7   │     0.888805     │     1.16509      │
│   8   │     0.825245     │     0.908255     │
│   9   │     0.766356     │     0.172344     │
│  10   │     0.713437     │     -1.17824     │
│  11   │     0.667894     │     -1.47769     │
│  12   │     0.630395     │      -2.028      │
│  13   │     0.600687     │    -0.999587     │
│  14   │     0.577247     │     0.614553     │
│   ⋮   │        ⋮         │        ⋮         │
└───────┴──────────────────┴──────────────────┘
                               121 rows omitted
```

Check filter frequency response directly via [`spectral transfer`](@ref ref-spectral-transfer) (output key `filter_transfer_function`) before applying high-pass smoothers to short samples.

---

## Spectral & Cross-Spectral Analysis

For covariance-stationary $y_t$ with autocovariances $\gamma(k)$, the power spectral density concentrates variance across angular frequencies $\omega \in [0, \pi]$:

```math
f_{yy}(\omega) = \frac{1}{2\pi} \sum_{k=-\infty}^{\infty} \gamma(k) e^{-i \omega k}.
```

Compute time-domain ACF/PACF and bivariate cross-correlations via [`spectral acf`](@ref ref-spectral-acf) (`acf_pacf`, `cross_correlation`), unsmoothed FFT ordinates via [`spectral periodogram`](@ref ref-spectral-periodogram) (`periodogram`), Welch/lag-window/AR smoothed spectra via [`spectral density`](@ref ref-spectral-density) (`spectral_density`), and coherency, gain, and phase between two series via [`spectral cross`](@ref ref-spectral-cross) (`cross_spectral_analysis`).

<!-- capture -->
```bash
friedman spectral cross :denmark --var1 1 --var2 2
```
```text
                           Cross-Spectral Analysis
┌───────────┬─────────────┬───────────────┬───────────┬───────────┬──────────┐
│ Frequency │ Co_spectrum │ Quad_spectrum │ Coherence │   Phase   │   Gain   │
│  Float64  │   Float64   │    Float64    │  Float64  │  Float64  │ Float64  │
├───────────┼─────────────┼───────────────┼───────────┼───────────┼──────────┤
│    0.0    │  0.002855   │     -0.0      │ 0.435035  │   -0.0    │ 0.290588 │
│ 0.392699  │  0.001637   │   -0.000172   │ 0.424653  │ -0.104873 │ 0.310623 │
│ 0.785398  │  0.000407   │    -4.6e-5    │  0.58111  │ -0.113101 │ 0.627315 │
│  1.1781   │   7.9e-5    │    -4.5e-5    │  0.48426  │ -0.517418 │ 0.750605 │
│  1.5708   │   3.5e-5    │    -1.8e-5    │ 0.585437  │ -0.47284  │ 0.858236 │
│  1.96349  │   3.1e-5    │    -1.5e-5    │ 0.666699  │ -0.443546 │ 0.769946 │
│  2.35619  │   6.0e-6    │    -3.0e-6    │ 0.082682  │ -0.39883  │ 0.321991 │
│  2.74889  │   1.0e-5    │    -1.3e-5    │ 0.190867  │ -0.927004 │ 0.325152 │
│  3.14159  │   2.1e-5    │     -0.0      │ 0.246509  │   -0.0    │ 0.158573 │
└───────────┴─────────────┴───────────────┴───────────┴───────────┴──────────┘
```

The `cross_spectral_analysis` JSON table reports frequency-by-frequency squared coherence (`0.435035` at frequency `0.0`, peaking near `0.666699` at `1.96349`) and phase lead/lag between `LRM` and `LRY`.

---

## ARIMA, SARIMA, ARFIMA, ARDL, NARDL & MIDAS

Univariate dynamic models span short-memory differenced processes, seasonal multiplicative forms, fractional integration $(1-L)^d$, mixed-frequency regressors, and bounds-tested cointegrating lag structures:

```math
\phi(L)(1-L)^d (y_t - \mu) = \theta(L)\varepsilon_t, \qquad \varepsilon_t \sim (0, \sigma^2).
```

- **Short & Seasonal Memory:** [`estimate univariate arima`](@ref ref-estimate-univariate-arima) (pass `--d 0 --q 0` for pure AR, `--p 0 --d 0` for MA, or omit `--p` for automatic criterion search) and [`estimate univariate sarima`](@ref ref-estimate-univariate-sarima) (`--auto` selects $(p,d,q)(P,D,Q)_s$). Both pair with [`forecast`](@ref ref-forecast), [`predict`](@ref ref-predict), and [`residuals`](@ref ref-residuals).
- **Fractional Integration:** [`estimate univariate arfima`](@ref ref-estimate-univariate-arfima) jointly estimates $d \in (-0.5, 0.5)$ alongside ARMA dynamics via CSS or exact MLE.
- **Mixed-Frequency Regressions:** [`estimate univariate midas`](@ref ref-estimate-univariate-midas) projects low-frequency targets on high-frequency lags using Almon, Beta (`beta2`/`beta3`), Exponential Almon, or U-MIDAS polynomial weights (`midas_weight_curve`, `midas_coefficients`, `midas_diagnostics`).
- **Cointegrating ARDL & Asymmetric NARDL:** [`estimate univariate ardl`](@ref ref-estimate-univariate-ardl) estimates optimal $(p, q_1, \dots, q_k)$ lag lengths alongside levels-relationship long-run multipliers (`ardl_long_run_coefficients`), testable via [`test coint ardl-bounds`](@ref ref-test-coint-ardl-bounds). [`estimate univariate nardl`](@ref ref-estimate-univariate-nardl) decomposes explanatory series into partial sum positive and negative cumulative shocks $x_t^+, x_t^-$, computing bootstrap cumulative dynamic multipliers (`nardl_cumulative_dynamic_multipliers`) testable via [`test nardl-symmetry`](@ref ref-test-nardl-symmetry).

---

## State-Space & Time-Varying Parameters

Linear Gaussian state-space systems filter and smooth latent states $\alpha_t$ given observation equations $y_t = Z \alpha_t + d + \varepsilon_t$ and transition equations $\alpha_{t+1} = T \alpha_t + c + R \eta_t$.

- **Local Level & General `[statespace]`:** Pass [`estimate regression statespace`](@ref ref-estimate-regression-statespace) with a TOML `[statespace]` config ([GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy)), or inspect local-level / local-linear-trend filtered and smoothed state paths directly with [`predict regression statespace`](@ref ref-predict-regression-statespace) (`--kind local-level|local-linear-trend`) and standardized innovations with [`residuals regression statespace`](@ref ref-residuals-regression-statespace).
- **Time-Varying Parameter Regression:** [`estimate regime tvp`](@ref ref-estimate-regime-tvp) treats regression slopes $\beta_t = \beta_{t-1} + \eta_t$ as random walks estimated via exact Kalman filtering and Rauch–Tung–Striebel smoothing (`tvp_hyper_parameters`, `tvp_coefficient_paths`, `tvp_diagnostics`).

<!-- capture -->
```bash
friedman predict regression statespace :nile --kind local-level --state smoothed
```
```text
State-Space State Paths (local-level, Nile)
┌────────┬────────┬──────────┐
│ period │ state  │ smoothed │
│ Int64  │ String │ Float64  │
├────────┼────────┼──────────┤
│   1    │ state1 │  1107.2  │
│   2    │ state1 │ 1107.57  │
│   3    │ state1 │ 1102.87  │
│   4    │ state1 │ 1111.72  │
│   5    │ state1 │ 1111.05  │
│   6    │ state1 │ 1105.64  │
│   7    │ state1 │ 1094.96  │
│   8    │ state1 │ 1111.59  │
│   9    │ state1 │ 1116.76  │
│   10   │ state1 │ 1097.39  │
│   11   │ state1 │  1073.9  │
│   12   │ state1 │ 1058.06  │
│   13   │ state1 │ 1054.13  │
│   14   │ state1 │ 1044.79  │
│   ⋮    │   ⋮    │    ⋮     │
└────────┴────────┴──────────┘
               86 rows omitted
```

The `state_space_state_paths` table aligns the annual Nile discharge series (`:nile`) with its RTS smoothed level (starting at `1107.2` in period `1`), reflecting the abrupt hydrological drop near observation 28 (Aswan dam).

---

## Common Pitfalls

1. **Omitting `--dep` on `ardl` and `nardl`:** Unlike univariate `arima` (`--column 1`), [`estimate univariate ardl`](@ref ref-estimate-univariate-ardl) and [`estimate univariate nardl`](@ref ref-estimate-univariate-nardl) require an explicit dependent column name or index via `--dep`.
2. **Expecting separate `ar` / `ma` subcommands:** Pure AR($p$) and MA($q$) models use [`estimate univariate arima`](@ref ref-estimate-univariate-arima) with `--d 0` and `--q 0` (or `--p 0`) rather than separate leaves.
3. **Interpreting HP endpoints mechanically:** Standard [`filter hp`](@ref ref-filter-hp) exhibits severe end-of-sample bias; compare against [`filter hamilton`](@ref ref-filter-hamilton) or [`filter bhp`](@ref ref-filter-bhp) and verify transfer attenuation via [`spectral transfer`](@ref ref-spectral-transfer).
4. **Missing `--hf-data` in `midas`:** Supplying a single dataset without `--hf-data` triggers a usage error unless both low-frequency (`<data>`) and high-frequency (`--hf-data`) inputs plus `--m` frequency ratio are passed.

---

## References

- Hamilton, J. D. (2018). Why you should never use the Hodrick-Prescott filter. *Review of Economics and Statistics*, 100(5), 831–843.
- Phillips, P. C., & Shi, Z. (2021). Boosting: Why you can use the HP filter. *International Economic Review*, 62(2), 521–570.
- Pesaran, M. H., Shin, Y., & Smith, R. J. (2001). Bounds testing approaches to the analysis of level relationships. *Journal of Applied Econometrics*, 16(3), 289–326.
- Upstream manual: [MacroEconometricModels.jl — Univariate & Filters](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/filters/)
- CLI reference: [`friedman filter`](@ref ref-filter), [`friedman spectral`](@ref ref-spectral), [`friedman estimate univariate`](@ref ref-fam-estimate-univariate), [`friedman forecast univariate`](@ref ref-fam-forecast-univariate)
