# [Regime-Switching & Nonlinear TS](@id chap-nonlinear)

Nonlinear dynamics where autoregressive persistence, intercepts, or residual variances shift across unobserved Markov chains or observable threshold transitions are estimated under [`estimate regime`](@ref ref-fam-estimate-regime) (`ms`, `ms-ar`, `setar`, `star`, `threshold`, plus Kalman-smoothed `tvp` covered in [Univariate, Filters & Spectral](@ref chap-univariate)). Linearity specification tests under [`test`](@ref ref-test) evaluate threshold and smooth-transition alternatives before estimation. See [MacroEconometricModels.jl — Regime Switching & Thresholds](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/nonlinear/) for upstream formulations.

## Quick Start

Simulate a 2-regime Markov-switching series with a fixed seed, estimate regime-dependent AR parameters and transition matrix via EM, and inspect multi-step forecasts weighted by predicted regime probabilities:

<!-- capture -->
```bash
friedman --quiet data simulate regime --kind ms --periods 180 --burn 40 --seed 12 --save-data ms_sim
friedman --quiet estimate regime ms-ar ms_sim --p 1 --k-regimes 2 --switching-variance --save-model ms_fit
friedman forecast regime ms-ar ms_sim --model ms_fit.jld2 --horizons 4 --reps 100
```
```text
        MS-AR(1) Forecast for model (h=4, 90% CI)
┌─────────┬──────────┬────────────┬──────────┬──────────┐
│ horizon │ variable │   value    │  lower   │  upper   │
│  Int64  │  String  │  Float64   │ Float64? │ Float64? │
├─────────┼──────────┼────────────┼──────────┼──────────┤
│    1    │    y1    │ -0.410744  │ -1.47825 │ 3.04695  │
│    2    │    y1    │ -0.320108  │ -1.74492 │ 3.61703  │
│    3    │    y1    │ -0.184797  │ -1.78647 │ 3.22296  │
│    4    │    y1    │ -0.0569165 │ -2.09821 │ 3.73971  │
└─────────┴──────────┴────────────┴──────────┴──────────┘
MS-AR(1) Predicted Regime Probabilities
┌─────────┬──────────┬──────────┐
│ horizon │ regime1  │ regime2  │
│  Int64  │ Float64  │ Float64  │
├─────────┼──────────┼──────────┤
│    1    │ 0.910561 │ 0.089439 │
│    2    │ 0.843968 │ 0.156032 │
│    3    │ 0.794386 │ 0.205614 │
│    4    │ 0.757469 │ 0.242531 │
└─────────┴──────────┴──────────┘
```

Pass `--save-model ms_fit` once and reuse `--model ms_fit.jld2` across [`predict regime ms-ar`](@ref ref-predict-regime-ms-ar), [`residuals regime ms-ar`](@ref ref-residuals-regime-ms-ar), and [`forecast regime ms-ar`](@ref ref-forecast-regime-ms-ar) (`ms_ar_forecast`, `ms_ar_predicted_regime_probabilities`), which starts at horizon-1 forecast `-0.410744` with regime 1 probability `0.910561` decaying toward `0.757469` by horizon 4.

---

## Markov-Switching AR & Regression (`ms-ar`, `ms`)

In a Hamilton Markov-switching process, an unobserved ergodic $K$-state chain $s_t \in \{1, \dots, K\}$ with transition matrix $P_{ij} = \Pr(s_t = j \mid s_{t-1} = i)$ governs regime-specific regression coefficients and optional regime variances:

```math
y_t = \mu_{s_t} + \sum_{\ell=1}^p \phi_{\ell, s_t} y_{t-\ell} + \sigma_{s_t} \varepsilon_t \quad (\text{or } x_t'\beta_{s_t} + \sigma_{s_t}\varepsilon_t), \qquad \varepsilon_t \sim \mathcal{N}(0, 1).
```

- [`estimate regime ms-ar`](@ref ref-estimate-regime-ms-ar): Univariate $K$-regime switching AR($p$); use `--switching-variance` to allow regime heteroskedasticity.
- [`estimate regime ms`](@ref ref-estimate-regime-ms): Multivariate-regressor switching model selecting dependent column `--dep`; heteroskedastic regimes are on by default (`--no-switching-variance` disables them).

Both return regime coefficients, regime variances, transition matrices, Kim-smoothed probabilities, and log-likelihood/AIC/BIC (`ms_ar_*` and `ms_regression_*` tables), paired cleanly with [`predict regime`](@ref ref-fam-predict-regime) (`--probs smoothed|filtered`), [`residuals regime`](@ref ref-fam-residuals-regime), and [`forecast regime`](@ref ref-fam-forecast-regime).

---

## Threshold & Smooth Transition Models (`setar`, `threshold`, `star`)

Unlike Markov switching where regimes are latent, threshold (`setar`, `threshold`) and smooth-transition (`star`) models switch regimes when an observable transition variable $q_t$ (either lagged dependent variable $y_{t-d}$ or external `--threshold-col` / `--transition-col`) crosses a threshold $\gamma$ sharply or smoothly via logistic/exponential transition weights $G(q_t; \gamma, c)$:

```math
y_t = x_t'\theta_1 + x_t'\theta_2 \, G(q_t; \gamma, c) + \varepsilon_t, \qquad G_{\text{LSTR1}}(q_t; \gamma, c) = \left[1 + \exp\{-\gamma (q_t - c)\}\right]^{-1}.
```

| Subcommand | Transition Mechanism | Nonlinearity Tests |
|---|---|---|
| [`estimate regime setar`](@ref ref-estimate-regime-setar) | Hard indicator $\mathbb{I}\{y_{t-d} \le c\}$ (lag delay `--d`) | Built-in Hansen bootstrap (`--no-linearity` skips) and [`test hansen-linearity`](@ref ref-test-hansen-linearity) |
| [`estimate regime threshold`](@ref ref-estimate-regime-threshold) | General regressor regression switching on `--threshold-col` | `--het` heteroskedastic Wald/LM test; `--trim` trims candidate quantile grid |
| [`estimate regime star`](@ref ref-estimate-regime-star) | Smooth logistic (`lstr1`, `lstr2`) or exponential (`estr`, or `auto`) | Teräsvirta LM nonlinearity sequence via [`test star-linearity`](@ref ref-test-star-linearity) |

<!-- capture -->
```bash
friedman --quiet data simulate regime --kind lstar --periods 180 --burn 40 --seed 5 --save-data star_sim
friedman test star-linearity star_sim --p 1 --d 1
friedman --seed 5 estimate regime star star_sim --p 1 --d 1 --type auto
```
```text
                   STAR(1) Regime Coefficients (y)
┌───────────────┬────────┬──────────┬───────────┬──────────┬─────────┐
│    regime     │  term  │ estimate │ std_error │  z_stat  │ p_value │
│    String     │ String │ Float64  │  Float64  │ Float64  │ Float64 │
├───────────────┼────────┼──────────┼───────────┼──────────┼─────────┤
│ regime1 (G→0) │ const  │ -168.892 │ 0.068274  │ -2473.74 │   0.0   │
│ regime1 (G→0) │ y[t-1] │ -13.922  │ 0.674528  │ -20.6396 │   0.0   │
│ regime2 (G→1) │ const  │ 261.986  │ 0.051892  │ 5048.71  │   0.0   │
│ regime2 (G→1) │ y[t-1] │ -29.2889 │ 0.487658  │ -60.0604 │   0.0   │
└───────────────┴────────┴──────────┴───────────┴──────────┴─────────┘
             STAR(1) Transition Parameters
┌───────────┬──────────┬───────────┬─────────┬─────────┐
│ parameter │ estimate │ std_error │ z_stat  │ p_value │
│  String   │ Float64  │  Float64  │ Float64 │ Float64 │
├───────────┼──────────┼───────────┼─────────┼─────────┤
│     γ     │ 0.154685 │ 0.002031  │ 76.1458 │   0.0   │
│     c     │  2.2034  │ 0.025033  │ 88.021  │   0.0   │
└───────────┴──────────┴───────────┴─────────┴─────────┘
   STAR(1) Diagnostics
┌─────────────┬──────────┐
│   metric    │  value   │
│   String    │   Any    │
├─────────────┼──────────┤
│ trans_type  │  lstr1   │
│    sname    │  y[t-1]  │
│   sigma_s   │ 0.776434 │
│      n      │   179    │
│      p      │    1     │
│      d      │    1     │
│     ssr     │ 66.4801  │
│   sigma2    │ 0.384278 │
│     aic     │ 342.684  │
│     bic     │ 361.808  │
│  lm3_stat   │ 15.6749  │
│ lm3_pvalue  │  0.0013  │
│  lm3_fstat  │  5.5665  │
│ lm3_fpvalue │  0.0011  │
│      ⋮      │    ⋮     │
└─────────────┴──────────┘
            4 rows omitted
```

The estimation tables (`star_regime_coefficients`, `star_transition_parameters`, `star_diagnostics`) recover smoothness speed $\gamma = 0.154685$ and threshold $c = 2.2034$ under selected family `lstr1` alongside strong Teräsvirta LM3 nonlinearity rejection (`lm3_stat = 15.6749`, $p = 0.0013$).

---

## Common Pitfalls

1. **Label switching and tiny regime shares in small samples:** Markov-switching EM can converge to local optima or corner regimes with near-zero transition counts when $T$ is short relative to `k-regimes * p`; start with `--k-regimes 2` and verify non-degenerate regime durations in `ms_*_transition_matrix`.
2. **Omitting `--dep` on `ms` or `--threshold-col` on `threshold`:** Univariate `ms-ar`, `setar`, and `star` take `--column 1`, whereas regression-style [`estimate regime ms`](@ref ref-estimate-regime-ms) and [`estimate regime threshold`](@ref ref-estimate-regime-threshold) require explicit column names or indices via `--dep` and `--threshold-col`.
3. **Skip heavy Hansen bootstrap draws during grid exploration:** [`estimate regime setar`](@ref ref-estimate-regime-setar) and [`threshold`](@ref ref-estimate-regime-threshold) run `1000` bootstrap linearity replications by default; pass `--no-linearity` during rapid model selection or fix leading `--seed` and moderate `--reps` for reproducible p-values.

---

## References

- Hamilton, J. D. (1989). A new approach to the economic analysis of nonstationary time series and the business cycle. *Econometrica*, 57(2), 357–384.
- Hansen, B. E. (2000). Sample splitting and threshold estimation. *Econometrica*, 68(3), 575–603.
- Teräsvirta, T. (1994). Specification, estimation, and evaluation of smooth transition autoregressive models. *Journal of the American Statistical Association*, 89(425), 208–218.
- Upstream manual: [MacroEconometricModels.jl — Nonlinear & Regime-Switching](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/nonlinear/)
- CLI reference: [`friedman estimate regime`](@ref ref-fam-estimate-regime), [`friedman forecast regime`](@ref ref-fam-forecast-regime), [`friedman test hansen-linearity`](@ref ref-test-hansen-linearity), [`friedman test star-linearity`](@ref ref-test-star-linearity)
