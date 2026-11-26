# [Univariate, Filters & Spectral](@id chap-univariate)

Single-series macroeconomic analysis in `Friedman-cli` spans trend-cycle decomposition ([`frdc filter`](@ref ref-filter)), nonparametric and filter frequency-domain diagnostics ([`frdc spectral`](@ref ref-spectral)), Box–Jenkins, fractional, mixed-frequency, and distributed-lag estimators ([`estimate univariate`](@ref ref-fam-estimate-univariate)), general Gaussian state-space filtering ([`estimate regression statespace`](@ref ref-estimate-regression-statespace)), and time-varying parameter regressions ([`estimate regime tvp`](@ref ref-estimate-regime-tvp)). Univariate time-series estimators, forecasts, and spectral bands default to **68%** confidence intervals (`-L`/`--conf-level 0.68`). See [MacroEconometricModels.jl — Univariate & Filters](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/filters/) for mathematical details.

## Quick Start

Decompose U.S. real GNP (`:gnp_hamilton`) with the Hamilton regression filter, inspect spectral power, and fit an automatic BIC ARIMA model with 4-step forecasts:

<!-- capture -->
```bash
frdc estimate univariate arima :gnp_hamilton --criterion bic
```
```text
                       AR(1) Coefficients (gnp_growth)
┌───────────┬──────────┬───────────┬────────┬─────────┬──────────┬──────────┐
│ parameter │ estimate │ std_error │ z_stat │ p_value │ ci_lower │ ci_upper │
├───────────┼──────────┼───────────┼────────┼─────────┼──────────┼──────────┤
│    ar1    │  0.493   │   0.147   │ 3.358  │  0.001  │  0.347   │  0.639   │
│  const2   │  0.342   │   0.089   │ 3.828  │  0.000  │  0.253   │  0.431   │
└───────────┴──────────┴───────────┴────────┴─────────┴──────────┴──────────┘
    Information Criteria
┌────────────────┬──────────┐
│     metric     │  value   │
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
frdc filter hp :gnp_hamilton --lambda 1600
```
```text
            HP Filter (λ=1600.0)
┌─────┬──────────────────┬──────────────────┐
│  t  │ gnp_growth_trend │ gnp_growth_cycle │
├─────┼──────────────────┼──────────────────┤
│  1  │      1.343       │      1.250       │
│  2  │      1.262       │      0.940       │
│  3  │      1.181       │      -0.723      │
│  4  │      1.103       │      -0.134      │
│  5  │      1.028       │      -1.269      │
│  6  │      0.956       │      -0.060      │
│  7  │      0.889       │      1.165       │
│  8  │      0.825       │      0.908       │
│  9  │      0.766       │      0.172       │
│ 10  │      0.713       │      -1.178      │
│ 11  │      0.668       │      -1.478      │
│ 12  │      0.630       │      -2.028      │
│ 13  │      0.601       │      -1.000      │
│ 14  │      0.577       │      0.615       │
│ 15  │      0.558       │      0.898       │
│ 16  │      0.541       │      1.577       │
│ 17  │      0.525       │      0.564       │
│ 18  │      0.510       │      0.814       │
│ 19  │      0.497       │      0.376       │
│ 20  │      0.485       │      -0.682      │
│ 21  │      0.475       │      -0.021      │
│ 22  │      0.469       │      -0.396      │
│ 23  │      0.466       │      0.637       │
│ 24  │      0.467       │      0.354       │
│ 25  │      0.472       │      -0.530      │
│ 26  │      0.482       │      0.102       │
│ 27  │      0.498       │      -2.060      │
│ 28  │      0.520       │      -2.570      │
│ 29  │      0.547       │      -0.011      │
│ 30  │      0.578       │      1.759       │
│ 31  │      0.609       │      1.731       │
│ 32  │      0.639       │      0.595       │
│ 33  │      0.669       │      1.218       │
│ 34  │      0.698       │      -1.157      │
│ 35  │      0.728       │      0.121       │
│ 36  │      0.758       │      0.943       │
│ 37  │      0.790       │      -1.077      │
│ 38  │      0.823       │      -0.727      │
│ 39  │      0.858       │      -1.719      │
│ 40  │      0.895       │      0.139       │
│ 41  │      0.933       │      0.304       │
│ 42  │      0.970       │      0.450       │
│ 43  │      1.006       │      1.218       │
│ 44  │      1.039       │      0.263       │
│ 45  │      1.070       │      -0.035      │
│ 46  │      1.098       │      -0.173      │
│ 47  │      1.125       │      -1.291      │
│ 48  │      1.150       │      0.195       │
│ 49  │      1.172       │      0.203       │
│ 50  │      1.190       │      0.542       │
│ 51  │      1.205       │      -0.489      │
│ 52  │      1.215       │      0.995       │
│ 53  │      1.222       │      -0.368      │
│ 54  │      1.223       │      -0.221      │
│ 55  │      1.221       │      -0.794      │
│ 56  │      1.214       │      0.930       │
│ 57  │      1.201       │      0.237       │
│ 58  │      1.183       │      0.396       │
│ 59  │      1.160       │      1.115       │
│ 60  │      1.131       │      0.829       │
│ 61  │      1.098       │      -0.838      │
│ 62  │      1.062       │      -0.043      │
│ 63  │      1.025       │      -0.535      │
│ 64  │      0.987       │      -0.423      │
│ 65  │      0.948       │      -0.352      │
│ 66  │      0.909       │      0.521       │
│ 67  │      0.871       │      -0.309      │
│ 68  │      0.833       │      0.321       │
│ 69  │      0.796       │      0.891       │
│ 70  │      0.761       │      0.014       │
│ 71  │      0.727       │      -0.824      │
│ 72  │      0.697       │      0.699       │
│ 73  │      0.671       │      -0.535      │
│ 74  │      0.649       │      -0.097      │
│ 75  │      0.633       │      -1.033      │
│ 76  │      0.623       │      -1.240      │
│ 77  │      0.618       │      -0.705      │
│ 78  │      0.618       │      0.592       │
│ 79  │      0.622       │      -1.530      │
│ 80  │      0.629       │      2.021       │
│ 81  │      0.636       │      -0.644      │
│ 82  │      0.643       │      -0.131      │
│ 83  │      0.649       │      -0.653      │
│ 84  │      0.652       │      1.516       │
│ 85  │      0.653       │      1.273       │
│ 86  │      0.648       │      0.387       │
│ 87  │      0.640       │      1.219       │
│ 88  │      0.628       │      1.692       │
│ 89  │      0.614       │      -0.358      │
│ 90  │      0.599       │      -0.698      │
│ 91  │      0.587       │      0.304       │
│ 92  │      0.577       │      -1.136      │
│ 93  │      0.573       │      -0.290      │
│ 94  │      0.576       │      -1.887      │
│ 95  │      0.585       │      -1.468      │
│ 96  │      0.602       │      -2.576      │
│ 97  │      0.624       │      0.389       │
│ 98  │      0.649       │      1.033       │
│ 99  │      0.675       │      0.708       │
│ 100 │      0.699       │      1.162       │
│ 101 │      0.720       │      -0.276      │
│ 102 │      0.738       │      -0.323      │
│ 103 │      0.750       │      0.242       │
│ 104 │      0.757       │      0.605       │
│ 105 │      0.758       │      0.842       │
│ 106 │      0.750       │      1.238       │
│ 107 │      0.736       │      -0.993      │
│ 108 │      0.715       │      0.163       │
│ 109 │      0.687       │      2.423       │
│ 110 │      0.652       │      0.201       │
│ 111 │      0.613       │      0.620       │
│ 112 │      0.571       │      -0.568      │
│ 113 │      0.529       │      -0.623      │
│ 114 │      0.487       │      0.412       │
│ 115 │      0.448       │      -0.639      │
│ 116 │      0.414       │      0.584       │
│ 117 │      0.385       │      -2.776      │
│ 118 │      0.364       │      -0.297      │
│ 119 │      0.350       │      0.912       │
│ 120 │      0.343       │      1.574       │
│ 121 │      0.343       │      -0.678      │
│ 122 │      0.353       │      0.090       │
│ 123 │      0.372       │      -1.778      │
│ 124 │      0.401       │      -1.923      │
│ 125 │      0.442       │      -0.142      │
│ 126 │      0.491       │      -1.293      │
│ 127 │      0.548       │      -0.396      │
│ 128 │      0.610       │      0.375       │
│ 129 │      0.676       │      1.454       │
│ 130 │      0.742       │      0.602       │
│ 131 │      0.808       │      0.808       │
│ 132 │      0.872       │      1.838       │
│ 133 │      0.933       │      0.311       │
│ 134 │      0.994       │      -0.485      │
│ 135 │      1.054       │      -0.906      │
└─────┴──────────────────┴──────────────────┘
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
frdc spectral cross :denmark --var1 1 --var2 2
```
```text
                        Cross-Spectral Analysis
┌───────────┬─────────────┬───────────────┬───────────┬────────┬───────┐
│ Frequency │ Co_spectrum │ Quad_spectrum │ Coherence │ Phase  │ Gain  │
├───────────┼─────────────┼───────────────┼───────────┼────────┼───────┤
│   0.000   │    0.003    │     0.000     │   0.435   │ 0.000  │ 0.291 │
│   0.393   │    0.002    │     0.000     │   0.425   │ -0.105 │ 0.311 │
│   0.785   │    0.000    │     0.000     │   0.581   │ -0.113 │ 0.627 │
│   1.178   │    0.000    │     0.000     │   0.484   │ -0.517 │ 0.751 │
│   1.571   │    0.000    │     0.000     │   0.585   │ -0.473 │ 0.858 │
│   1.963   │    0.000    │     0.000     │   0.667   │ -0.444 │ 0.770 │
│   2.356   │    0.000    │     0.000     │   0.083   │ -0.399 │ 0.322 │
│   2.749   │    0.000    │     0.000     │   0.191   │ -0.927 │ 0.325 │
│   3.142   │    0.000    │     0.000     │   0.247   │ 0.000  │ 0.159 │
└───────────┴─────────────┴───────────────┴───────────┴────────┴───────┘
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

- **Local Level, General `[statespace]` & Steady-State Kalman:** Pass [`estimate regression statespace`](@ref ref-estimate-regression-statespace) with a TOML `[statespace]` config (including optional correlated measurement–state shock cross-covariance `G` in [GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy)), or add `--steady-state` to solve the time-invariant DARE steady-state Kalman gain and Riccati covariance directly. Inspect local-level / local-linear-trend filtered and smoothed state paths with [`predict regression statespace`](@ref ref-predict-regression-statespace) (`--kind local-level|local-linear-trend`) and standardized innovations with [`residuals regression statespace`](@ref ref-residuals-regression-statespace). (Related regression upgrades—interior-point quantile regression [`estimate regression qreg`](@ref ref-estimate-regression-qreg) `--solver ipm` and continuously updated GMM [`estimate regression gmm`](@ref ref-estimate-regression-gmm) `--weighting cue`—are detailed in [Regression, Systems & GMM/SMM](@ref chap-regression).)
- **Time-Varying Parameter Regression:** [`estimate regime tvp`](@ref ref-estimate-regime-tvp) treats regression slopes $\beta_t = \beta_{t-1} + \eta_t$ as random walks estimated via exact Kalman filtering and Rauch–Tung–Striebel smoothing (`tvp_hyper_parameters`, `tvp_coefficient_paths`, `tvp_diagnostics`).

<!-- capture -->
```bash
frdc predict regression statespace :nile --kind local-level --state smoothed
```
```text
State-Space State Paths (local-level, Nile)
┌────────┬────────┬──────────┐
│ period │ state  │ smoothed │
├────────┼────────┼──────────┤
│   1    │ state1 │ 1107.197 │
│   2    │ state1 │ 1107.574 │
│   3    │ state1 │ 1102.874 │
│   4    │ state1 │ 1111.722 │
│   5    │ state1 │ 1111.051 │
│   6    │ state1 │ 1105.639 │
│   7    │ state1 │ 1094.962 │
│   8    │ state1 │ 1111.595 │
│   9    │ state1 │ 1116.759 │
│   10   │ state1 │ 1097.395 │
│   11   │ state1 │ 1073.904 │
│   12   │ state1 │ 1058.056 │
│   13   │ state1 │ 1054.126 │
│   14   │ state1 │ 1044.785 │
│   15   │ state1 │ 1040.363 │
│   16   │ state1 │ 1037.913 │
│   17   │ state1 │ 1043.010 │
│   18   │ state1 │ 1034.838 │
│   19   │ state1 │ 1049.509 │
│   20   │ state1 │ 1073.043 │
│   21   │ state1 │ 1090.092 │
│   22   │ state1 │ 1106.182 │
│   23   │ state1 │ 1112.216 │
│   24   │ state1 │ 1114.590 │
│   25   │ state1 │ 1103.848 │
│   26   │ state1 │ 1077.981 │
│   27   │ state1 │ 1038.359 │
│   28   │ state1 │ 999.547  │
│   29   │ state1 │ 951.005  │
│   30   │ state1 │ 919.607  │
│   31   │ state1 │ 895.920  │
│   32   │ state1 │ 874.356  │
│   33   │ state1 │ 870.261  │
│   34   │ state1 │ 859.411  │
│   35   │ state1 │ 851.120  │
│   36   │ state1 │ 857.368  │
│   37   │ state1 │ 857.938  │
│   38   │ state1 │ 874.581  │
│   39   │ state1 │ 877.138  │
│   40   │ state1 │ 862.952  │
│   41   │ state1 │ 838.494  │
│   42   │ state1 │ 814.763  │
│   43   │ state1 │ 799.628  │
│   44   │ state1 │ 817.778  │
│   45   │ state1 │ 835.324  │
│   46   │ state1 │ 865.784  │
│   47   │ state1 │ 871.621  │
│   48   │ state1 │ 855.337  │
│   49   │ state1 │ 841.314  │
│   50   │ state1 │ 834.780  │
│   51   │ state1 │ 829.580  │
│   52   │ state1 │ 830.345  │
│   53   │ state1 │ 829.690  │
│   54   │ state1 │ 825.712  │
│   55   │ state1 │ 818.219  │
│   56   │ state1 │ 822.371  │
│   57   │ state1 │ 824.330  │
│   58   │ state1 │ 834.071  │
│   59   │ state1 │ 847.498  │
│   60   │ state1 │ 842.281  │
│   61   │ state1 │ 845.129  │
│   62   │ state1 │ 854.190  │
│   63   │ state1 │ 862.203  │
│   64   │ state1 │ 871.882  │
│   65   │ state1 │ 874.576  │
│   66   │ state1 │ 866.672  │
│   67   │ state1 │ 855.830  │
│   68   │ state1 │ 848.264  │
│   69   │ state1 │ 825.034  │
│   70   │ state1 │ 807.036  │
│   71   │ state1 │ 801.731  │
│   72   │ state1 │ 811.220  │
│   73   │ state1 │ 817.339  │
│   74   │ state1 │ 823.975  │
│   75   │ state1 │ 838.552  │
│   76   │ state1 │ 856.766  │
│   77   │ state1 │ 857.232  │
│   78   │ state1 │ 857.430  │
│   79   │ state1 │ 856.022  │
│   80   │ state1 │ 855.392  │
│   81   │ state1 │ 851.410  │
│   82   │ state1 │ 857.832  │
│   83   │ state1 │ 874.795  │
│   84   │ state1 │ 895.321  │
│   85   │ state1 │ 900.866  │
│   86   │ state1 │ 904.751  │
│   87   │ state1 │ 900.766  │
│   88   │ state1 │ 906.832  │
│   89   │ state1 │ 911.332  │
│   90   │ state1 │ 909.666  │
│   91   │ state1 │ 917.168  │
│   92   │ state1 │ 914.711  │
│   93   │ state1 │ 913.097  │
│   94   │ state1 │ 912.655  │
│   95   │ state1 │ 887.287  │
│   96   │ state1 │ 859.525  │
│   97   │ state1 │ 842.758  │
│   98   │ state1 │ 818.607  │
│   99   │ state1 │ 804.201  │
│  100   │ state1 │ 798.532  │
└────────┴────────┴──────────┘
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
- CLI reference: [`frdc filter`](@ref ref-filter), [`frdc spectral`](@ref ref-spectral), [`frdc estimate univariate`](@ref ref-fam-estimate-univariate), [`frdc forecast univariate`](@ref ref-fam-forecast-univariate)
