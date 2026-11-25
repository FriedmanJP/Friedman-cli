# [Univariate, Filters & Spectral](@id chap-univariate)

Single-series macroeconomic analysis in `Friedman-cli` spans trend-cycle decomposition ([`frdc filter`](@ref ref-filter)), nonparametric and filter frequency-domain diagnostics ([`frdc spectral`](@ref ref-spectral)), Box–Jenkins, fractional, mixed-frequency, and distributed-lag estimators ([`estimate univariate`](@ref ref-fam-estimate-univariate)), general Gaussian state-space filtering ([`estimate regression statespace`](@ref ref-estimate-regression-statespace)), and time-varying parameter regressions ([`estimate regime tvp`](@ref ref-estimate-regime-tvp)). See [MacroEconometricModels.jl — Univariate & Filters](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/filters/) for mathematical details.

## Quick Start

Decompose U.S. real GNP (`:gnp_hamilton`) with the Hamilton regression filter, inspect spectral power, and fit an automatic BIC ARIMA model with 4-step forecasts:

<!-- capture -->
```bash
frdc estimate univariate arima :gnp_hamilton --criterion bic
```
```text
            AR(1) Coefficients (gnp_growth)
┌───────────┬──────────┬───────────┬────────┬─────────┐
│ parameter │ estimate │ std_error │ z_stat │ p_value │
├───────────┼──────────┼───────────┼────────┼─────────┤
│    ar1    │ 0.493056 │ 0.146847  │ 3.358  │ 0.0008  │
│  const2   │ 0.34205  │ 0.089359  │ 3.828  │ 0.0001  │
└───────────┴──────────┴───────────┴────────┴─────────┘
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
│  1  │     1.34338      │     1.24982      │
│  2  │     1.26205      │     0.940153     │
│  3  │     1.18149      │    -0.723191     │
│  4  │     1.10309      │    -0.134385     │
│  5  │     1.02775      │     -1.26905     │
│  6  │     0.956306     │    -0.059806     │
│  7  │     0.888805     │     1.16509      │
│  8  │     0.825245     │     0.908255     │
│  9  │     0.766356     │     0.172344     │
│ 10  │     0.713437     │     -1.17824     │
│ 11  │     0.667894     │     -1.47769     │
│ 12  │     0.630395     │      -2.028      │
│ 13  │     0.600687     │    -0.999587     │
│ 14  │     0.577247     │     0.614553     │
│ 15  │     0.55793      │     0.89827      │
│ 16  │     0.540974     │     1.57713      │
│ 17  │     0.525176     │     0.564424     │
│ 18  │     0.510323     │     0.813577     │
│ 19  │     0.496551     │     0.376449     │
│ 20  │     0.484506     │    -0.682206     │
│ 21  │     0.475071     │    -0.020871     │
│ 22  │     0.468699     │    -0.396499     │
│ 23  │     0.465834     │     0.637166     │
│ 24  │     0.466668     │     0.354332     │
│ 25  │     0.471794     │    -0.529794     │
│ 26  │     0.482026     │     0.102474     │
│ 27  │     0.497847     │     -2.05975     │
│ 28  │     0.519804     │     -2.5702      │
│ 29  │     0.547155     │    -0.010755     │
│ 30  │     0.577553     │     1.75925      │
│ 31  │     0.608646     │     1.73145      │
│ 32  │     0.639178     │     0.594722     │
│ 33  │     0.668978     │     1.21802      │
│ 34  │     0.698246     │     -1.15745     │
│ 35  │     0.727941     │     0.121459     │
│ 36  │     0.758303     │     0.943097     │
│ 37  │     0.789643     │     -1.07724     │
│ 38  │     0.822866     │    -0.726966     │
│ 39  │      0.8582      │      -1.719      │
│ 40  │     0.895421     │     0.139079     │
│ 41  │     0.933229     │     0.303671     │
│ 42  │     0.970414     │     0.449586     │
│ 43  │     1.00595      │     1.21815      │
│ 44  │      1.0391      │      0.263       │
│ 45  │     1.06988      │     -0.03468     │
│ 46  │     1.09848      │    -0.173176     │
│ 47  │     1.12505      │     -1.29065     │
│ 48  │     1.14966      │     0.194742     │
│ 49  │     1.17155      │     0.203455     │
│ 50  │     1.19008      │     0.542117     │
│ 51  │     1.20477      │    -0.488667     │
│ 52  │     1.21543      │     0.994867     │
│ 53  │     1.22161      │    -0.368311     │
│ 54  │     1.22345      │    -0.221053     │
│ 55  │     1.22088      │     -0.79358     │
│ 56  │     1.21368      │     0.930025     │
│ 57  │     1.20113      │     0.236773     │
│ 58  │      1.1831      │     0.396497     │
│ 59  │     1.15962      │     1.11508      │
│ 60  │     1.13095      │     0.828654     │
│ 61  │     1.09804      │    -0.838138     │
│ 62  │     1.06238      │    -0.042876     │
│ 63  │     1.02492      │    -0.534717     │
│ 64  │     0.986589     │    -0.422989     │
│ 65  │     0.947986     │    -0.351986     │
│ 66  │     0.90944      │     0.52136      │
│ 67  │     0.871059     │    -0.308759     │
│ 68  │     0.833279     │     0.320621     │
│ 69  │     0.796345     │     0.890855     │
│ 70  │     0.760699     │     0.013701     │
│ 71  │     0.727341     │    -0.823841     │
│ 72  │     0.697281     │     0.698719     │
│ 73  │     0.671011     │    -0.534511     │
│ 74  │     0.649464     │    -0.097264     │
│ 75  │     0.633234     │     -1.03263     │
│ 76  │     0.622858     │     -1.23956     │
│ 77  │     0.618227     │    -0.705427     │
│ 78  │     0.618455     │     0.591745     │
│ 79  │     0.622217     │     -1.52952     │
│ 80  │     0.628558     │     2.02064      │
│ 81  │     0.635567     │    -0.643667     │
│ 82  │     0.642595     │    -0.131495     │
│ 83  │     0.648591     │    -0.652591     │
│ 84  │     0.652422     │     1.51578      │
│ 85  │     0.652547     │     1.27335      │
│ 86  │     0.648373     │     0.386627     │
│ 87  │     0.640102     │      1.2189      │
│ 88  │     0.628179     │     1.69182      │
│ 89  │     0.613808     │    -0.358108     │
│ 90  │     0.599253     │    -0.697853     │
│ 91  │     0.586554     │     0.304146     │
│ 92  │     0.577313     │     -1.13631     │
│ 93  │     0.573325     │    -0.289825     │
│ 94  │     0.575671     │     -1.88727     │
│ 95  │     0.585255     │     -1.46806     │
│ 96  │     0.601797     │     -2.5763      │
│ 97  │     0.624105     │     0.388695     │
│ 98  │     0.649371     │     1.03323      │
│ 99  │     0.675034     │     0.707666     │
│ 100 │     0.699177     │     1.16152      │
│ 101 │     0.720325     │    -0.275625     │
│ 102 │     0.737731     │    -0.323231     │
│ 103 │     0.750474     │     0.241526     │
│ 104 │     0.757431     │     0.605369     │
│ 105 │     0.75763      │     0.84207      │
│ 106 │     0.750479     │     1.23802      │
│ 107 │     0.735909     │    -0.992709     │
│ 108 │     0.714629     │     0.163271     │
│ 109 │     0.686723     │     2.42288      │
│ 110 │     0.652381     │     0.200819     │
│ 111 │     0.613304     │     0.620096     │
│ 112 │     0.571322     │    -0.568222     │
│ 113 │     0.52865      │     -0.62295     │
│ 114 │     0.487148     │     0.411652     │
│ 115 │     0.448288     │    -0.638688     │
│ 116 │     0.413798     │     0.583902     │
│ 117 │     0.385007     │     -2.77621     │
│ 118 │     0.36361      │     -0.29711     │
│ 119 │     0.349566     │     0.911834     │
│ 120 │     0.342648     │     1.57375      │
│ 121 │      0.3432      │      -0.678      │
│ 122 │     0.352548     │     0.089552     │
│ 123 │     0.371595     │     -1.77819     │
│ 124 │     0.401302     │     -1.9226      │
│ 125 │     0.441515     │    -0.142315     │
│ 126 │     0.490881     │     -1.29288     │
│ 127 │     0.547956     │    -0.395956     │
│ 128 │     0.610491     │     0.375409     │
│ 129 │     0.675987     │     1.45431      │
│ 130 │     0.742179     │     0.601821     │
│ 131 │     0.807714     │     0.807786     │
│ 132 │     0.871612     │     1.83769      │
│ 133 │     0.933401     │     0.311199     │
│ 134 │     0.993754     │    -0.485354     │
│ 135 │     1.05354      │    -0.905541     │
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
┌───────────┬─────────────┬───────────────┬───────────┬───────────┬──────────┐
│ Frequency │ Co_spectrum │ Quad_spectrum │ Coherence │   Phase   │   Gain   │
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
│   15   │ state1 │ 1040.36  │
│   16   │ state1 │ 1037.91  │
│   17   │ state1 │ 1043.01  │
│   18   │ state1 │ 1034.84  │
│   19   │ state1 │ 1049.51  │
│   20   │ state1 │ 1073.04  │
│   21   │ state1 │ 1090.09  │
│   22   │ state1 │ 1106.18  │
│   23   │ state1 │ 1112.22  │
│   24   │ state1 │ 1114.59  │
│   25   │ state1 │ 1103.85  │
│   26   │ state1 │ 1077.98  │
│   27   │ state1 │ 1038.36  │
│   28   │ state1 │ 999.547  │
│   29   │ state1 │ 951.005  │
│   30   │ state1 │ 919.607  │
│   31   │ state1 │  895.92  │
│   32   │ state1 │ 874.356  │
│   33   │ state1 │ 870.261  │
│   34   │ state1 │ 859.411  │
│   35   │ state1 │  851.12  │
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
│   50   │ state1 │  834.78  │
│   51   │ state1 │  829.58  │
│   52   │ state1 │ 830.345  │
│   53   │ state1 │  829.69  │
│   54   │ state1 │ 825.712  │
│   55   │ state1 │ 818.219  │
│   56   │ state1 │ 822.371  │
│   57   │ state1 │  824.33  │
│   58   │ state1 │ 834.071  │
│   59   │ state1 │ 847.498  │
│   60   │ state1 │ 842.281  │
│   61   │ state1 │ 845.129  │
│   62   │ state1 │  854.19  │
│   63   │ state1 │ 862.203  │
│   64   │ state1 │ 871.882  │
│   65   │ state1 │ 874.576  │
│   66   │ state1 │ 866.672  │
│   67   │ state1 │  855.83  │
│   68   │ state1 │ 848.264  │
│   69   │ state1 │ 825.034  │
│   70   │ state1 │ 807.036  │
│   71   │ state1 │ 801.731  │
│   72   │ state1 │  811.22  │
│   73   │ state1 │ 817.339  │
│   74   │ state1 │ 823.975  │
│   75   │ state1 │ 838.552  │
│   76   │ state1 │ 856.766  │
│   77   │ state1 │ 857.232  │
│   78   │ state1 │  857.43  │
│   79   │ state1 │ 856.022  │
│   80   │ state1 │ 855.392  │
│   81   │ state1 │  851.41  │
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
