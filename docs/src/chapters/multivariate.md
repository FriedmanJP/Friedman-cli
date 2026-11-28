# [VAR, BVAR, VECM & Factor Models](@id chap-multivariate)

Reduced-form and high-dimensional multivariate time-series models capture joint lag feedback, Bayesian shrinkage, long-run cointegration, mixed-frequency ragged edges, drifting parameters, and pervasive factor comovement across [`estimate multivariate`](@ref ref-fam-estimate-multivariate) and [`estimate factor`](@ref ref-fam-estimate-factor), paired with [`forecast`](@ref ref-forecast), [`predict`](@ref ref-predict), and [`residuals`](@ref ref-residuals). All multivariate estimators, IRFs, FEVDs, HDs, and forecasts report **68%** confidence/credible bands by default (`-L`/`--conf-level 0.68`, `-Q`/`--quantiles 0.16,0.5,0.84`). See [MacroEconometricModels.jl — VAR & VECM](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/var/) and [Factor Models](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/factors/).

## Quick Start

Import the five-series Danish money demand panel (`:denmark`), fit a reduced-form `VAR(2)` saving the model handle, and compute a 4-step analytical forecast without re-estimating:

<!-- capture -->
```bash
frdc --quiet data import :denmark -o macro
frdc --seed 42 --quiet estimate multivariate var macro --lags 2 --save-model var_fit
frdc forecast multivariate var --model var_fit.jld2 --horizons 4 --ci-method analytical
```
```text
          VAR(2) Forecast (h=4, 68% CI)
┌─────────┬──────────┬────────┬────────┬────────┐
│ horizon │ variable │ value  │ lower  │ upper  │
├─────────┼──────────┼────────┼────────┼────────┤
│    1    │   LRM    │ 12.043 │ 12.022 │ 12.064 │
│    1    │   LRY    │ 6.063  │ 6.044  │ 6.082  │
│    1    │   LPY    │ 0.477  │ 0.471  │ 0.484  │
│    1    │   IBO    │ 0.116  │ 0.108  │ 0.124  │
│    1    │   IDE    │ 0.075  │ 0.070  │ 0.080  │
│    2    │   LRM    │ 12.044 │ 12.017 │ 12.072 │
│    2    │   LRY    │ 6.079  │ 6.052  │ 6.105  │
│    2    │   LPY    │ 0.486  │ 0.476  │ 0.496  │
│    2    │   IBO    │ 0.117  │ 0.103  │ 0.130  │
│    2    │   IDE    │ 0.075  │ 0.068  │ 0.083  │
│    3    │   LRM    │ 12.055 │ 12.019 │ 12.092 │
│    3    │   LRY    │ 6.086  │ 6.056  │ 6.116  │
│    3    │   LPY    │ 0.495  │ 0.483  │ 0.508  │
│    3    │   IBO    │ 0.119  │ 0.101  │ 0.137  │
│    3    │   IDE    │ 0.076  │ 0.066  │ 0.085  │
│    4    │   LRM    │ 12.055 │ 12.008 │ 12.101 │
│    4    │   LRY    │ 6.091  │ 6.059  │ 6.123  │
│    4    │   LPY    │ 0.505  │ 0.490  │ 0.519  │
│    4    │   IBO    │ 0.121  │ 0.100  │ 0.141  │
│    4    │   IDE    │ 0.077  │ 0.067  │ 0.088  │
└─────────┴──────────┴────────┴────────┴────────┘
```

The command populates `var_forecast` in `--format json` (`LRM = 12.043` with 68% analytical CI `[12.022, 12.064]` and `LRY = 6.063` at horizon 1), while saving `var_fit.jld2` avoids redundant OLS estimation when moving to [`irf var`](@ref ref-irf-var), [`fevd var`](@ref ref-fevd-var), and [`hd var`](@ref ref-hd-var).

---

## Reduced-Form & Bayesian VARs (`var`, `bvar`, `mfvar`, `tvpvar`, `scenario`)

A vector autoregression of order $p$ models an $N \times 1$ endogenous vector $y_t$ jointly across its own lags:

```math
y_t = c + A_1 y_{t-1} + \dots + A_p y_{t-p} + u_t, \qquad u_t \sim (0, \Sigma).
```

- **Frequentist VAR ([`estimate multivariate var`](@ref ref-estimate-multivariate-var)):** Estimates equation-by-equation OLS (`--lags` auto-selected by AIC when omitted), outputting `var_coefficients` and `information_criteria`. Check lag criteria and companion eigenvalue stability via [`chap-tests`](@ref chap-tests) ([`test multivariate lagselect`](@ref ref-test-multivariate-lagselect), [`test multivariate stability`](@ref ref-test-multivariate-stability)).
- **Bayesian VAR ([`estimate multivariate bvar`](@ref ref-estimate-multivariate-bvar)):** Combines Gaussian-inverse-Wishart or Minnesota shrinkage ([Priors, SVAR & VECM Identification](@ref cfg-identification)) with Giannone–Lenza–Primiceri hierarchical optimization (`--hyperopt glp|grid`) and direct or Gibbs posterior sampling (`--sampler direct|gibbs`), emitting `bvar_coefficients`, `minnesota_hyperparameters`, and `information_criteria`.
- **Mixed-Frequency BVAR ([`estimate multivariate mfvar`](@ref ref-estimate-multivariate-mfvar)):** Bridges high-frequency monthly indicators with low-frequency quarterly targets (`--low-freq`, `--freq-ratio 3`, `--aggregation growth`) via state-space Kalman sampling (`--prior minnesota|diffuse`).
- **Time-Varying Parameter VAR ([`estimate multivariate tvpvar`](@ref ref-estimate-multivariate-tvpvar)):** Primiceri drifting-coefficient VAR with stochastic volatility (disable via `--no-tvp` or `--no-sv`; tune priors `--k-q`, `--k-s`, `--k-w`).
- **Conditional Scenarios ([`forecast multivariate scenario`](@ref ref-forecast-multivariate-scenario)):** Computes Waggoner–Zha conditional paths (`conditional_forecast`, `implied_structural_shocks`) given `--conditions-file` and `--method var|bvar`.

<!-- capture -->
```bash
frdc --seed 42 estimate multivariate bvar :denmark --lags 2 --draws 300 --sampler direct
```
```text
                                      BVAR(2) Posterior Mean Coefficients
┌──────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┬────────┐
│ equation │ const  │ LRM_L1 │ LRY_L1 │ LPY_L1 │ IBO_L1 │ IDE_L1 │ LRM_L2 │ LRY_L2 │ LPY_L2 │ IBO_L2 │ IDE_L2 │
├──────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┼────────┤
│   LRM    │ 0.012  │ 0.877  │ 0.068  │ -0.171 │ -0.244 │ -0.162 │ 0.123  │ -0.068 │ 0.171  │ 0.242  │ 0.161  │
│   LRY    │ 0.005  │ 0.171  │ 0.879  │ -0.105 │ -0.056 │ -0.103 │ -0.171 │ 0.121  │ 0.105  │ 0.056  │ 0.101  │
│   LPY    │ 0.026  │ -0.052 │ -0.017 │ 0.696  │ 0.054  │ 0.020  │ 0.052  │ 0.017  │ 0.303  │ -0.053 │ -0.018 │
│   IBO    │ -0.001 │ -0.020 │ 0.078  │ 0.010  │ 0.714  │ 0.036  │ 0.020  │ -0.078 │ -0.010 │ 0.285  │ -0.037 │
│   IDE    │ -0.001 │ -0.014 │ 0.014  │ 0.036  │ 0.093  │ 0.590  │ 0.014  │ -0.014 │ -0.036 │ -0.093 │ 0.408  │
└──────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┴────────┘
Minnesota Hyperparameters (glp)
┌────────────────┬─────────┐
│   parameter    │  value  │
├────────────────┼─────────┤
│      tau       │  0.358  │
│     decay      │  0.500  │
│     lambda     │  0.058  │
│       mu       │  0.988  │
│     omega      │  1.000  │
│     log_ml     │ 766.070 │
│ log_ml_default │ 697.472 │
│ log_posterior  │ 761.733 │
│   converged    │  true   │
│    at_bound    │  false  │
│   iterations   │   273   │
└────────────────┴─────────┘
Information Criteria (Posterior Mean)
┌────────────────┬─────────┐
│     metric     │  value  │
├────────────────┼─────────┤
│      AIC       │ -39.468 │
│      BIC       │ -37.424 │
│      HQC       │ -38.682 │
│ Log-likelihood │ 724.887 │
└────────────────┴─────────┘
```

The `bvar_coefficients`, `minnesota_hyperparameters`, and `information_criteria` tables show shrunk cross-lag responses alongside GLP-optimized overall tightness `tau = 0.358498` (`log_ml = 766.07` vs default `697.472`, `Log-likelihood = 724.887`).

---

## Cointegrated Systems (`vecm`)

When $I(1)$ series share $r < N$ stationary linear equilibrium relations $\beta' y_t$, the Granger Representation Theorem rewrites the level VAR($p$) in error-correction form:

```math
\Delta y_t = \Pi y_{t-1} + \sum_{i=1}^{p-1} \Gamma_i \Delta y_{t-i} + c_0 + c_1 t + \varepsilon_t, \qquad \Pi = \alpha \beta',
```

where $\beta$ ($N \times r$) holds cointegrating vectors and $\alpha$ ($N \times r$) measures error-correction adjustment speeds.

[`estimate multivariate vecm`](@ref ref-estimate-multivariate-vecm) supports Johansen trace/eigenvalue MLE (`--method johansen`, automatic rank selection via `--rank auto` and `--significance`) as well as single-equation `engle_granger`, configurable deterministics (`--deterministic none|constant|trend`), and full post-estimation (`forecast`, `predict`, `residuals`, `irf`, `fevd`, `hd` `vecm`) plus likelihood-ratio hypothesis tests under [`test vecm`](@ref ref-fam-test-vecm).

<!-- capture -->
```bash
frdc estimate multivariate vecm :denmark --lags 2 --deterministic constant
```
```text
 Cointegrating Vectors (beta)
┌──────────┬────────┬────────┐
│ variable │  CV1   │  CV2   │
├──────────┼────────┼────────┤
│   LRM    │ 1.000  │ 0.000  │
│   LRY    │ 0.000  │ 1.000  │
│   LPY    │ -0.072 │ 0.060  │
│   IBO    │ 4.385  │ -1.115 │
│   IDE    │ -1.341 │ 0.738  │
└──────────┴────────┴────────┘
Adjustment Coefficients (alpha)
┌──────────┬────────┬────────┐
│ equation │  CV1   │  CV2   │
├──────────┼────────┼────────┤
│   LRM    │ -0.333 │ 0.066  │
│   LRY    │ -0.023 │ -0.048 │
│   LPY    │ 0.022  │ -0.063 │
│   IBO    │ 0.001  │ 0.013  │
│   IDE    │ 0.010  │ 0.007  │
└──────────┴────────┴────────┘
    Information Criteria
┌────────────────┬─────────┐
│     metric     │  value  │
├────────────────┼─────────┤
│      AIC       │ -44.950 │
│      BIC       │ -43.463 │
│      HQC       │ -44.378 │
│ Log-likelihood │ 855.159 │
└────────────────┴─────────┘
```

The output surfaces `cointegrating_vectors_beta`, `adjustment_coefficients_alpha` (`LRM` error-corrects significantly to `CV1` with `alpha = -0.332801`), and `information_criteria` (`AIC = -44.9501`, `Log-likelihood = 855.159`); verify Johansen rank selection independently with [`test coint johansen`](@ref ref-test-coint-johansen).

---

## Factor & Factor-Augmented Models (`factor`, `favar`)

High-dimensional panels of macroeconomic series can be compressed into $r \ll N$ latent factors $F_t$ capturing pervasive comovement before feeding VARs:

```math
X_t = \Lambda F_t + e_t, \qquad \begin{bmatrix} F_t \\ Y_t \end{bmatrix} = \Phi_0 + \sum_{\ell=1}^p \Phi_\ell \begin{bmatrix} F_{t-\ell} \\ Y_{t-\ell} \end{bmatrix} + u_t.
```

| Model Family | Estimation Command | Core Methodology & Output Tables |
|---|---|---|
| Static PCA Factor | [`estimate factor static`](@ref ref-estimate-factor-static) | Bai–Ng `ic1`\|`ic2`\|`ic3` rank selection; `scree_data_eigenvalues_variance_shares`, `factor_loadings` |
| Dynamic Factor | [`estimate factor dynamic`](@ref ref-estimate-factor-dynamic) | Two-step PCA+VAR or Kalman EM (`--method twostep\|em`); `dynamic_factor_loadings` |
| Generalized Dynamic | [`estimate factor gdfm`](@ref ref-estimate-factor-gdfm) | Forni–Hallin–Lippi–Reichlin frequency-domain dynamic rank (`--spectral`); `gdfm_common_variance_shares` |
| One-Sided FHLZ / $I(1)$ / TV-GDFM | [`fhlz`](@ref ref-estimate-factor-fhlz), [`gdfm-i1`](@ref ref-estimate-factor-gdfm-i1), [`tv-gdfm`](@ref ref-estimate-factor-tv-gdfm) | One-sided FHLZ (`--dynamic-rank`), $I(1)$ permanent-transitory GDFM (`irf`/`fevd`/`hd`/`forecast gdfm-i1`), and time-varying spectral GDFM |
| Structural DFM | [`estimate factor sdfm`](@ref ref-estimate-factor-sdfm) | Hallin–Liška / Bai–Ng / Amengual–Watson dynamic shocks (`sdfm_estimation_summary`, `irf`/`fevd`/`hd sdfm`) |
| Quantile Factor & Growth-at-Risk | [`estimate factor qfm`](@ref ref-estimate-factor-qfm), [`forecast factor growth-at-risk`](@ref ref-forecast-factor-growth-at-risk) | Chen–Dolado–Gonzalo quantile factors (`--tau`/`--taus`, `forecast`/`predict`/`residuals factor qfm`) and Adrian–Boyarchenko–Giannone skewed-$t$ Growth-at-Risk |
| Factor-Augmented VAR | [`estimate multivariate favar`](@ref ref-estimate-multivariate-favar) | Bernanke–Boivin–Eliasz `--key-vars` combined with slow/fast factor block (`two_step` or `bayesian`) |
| Quantile VAR & QFAVAR | [`estimate multivariate qvar`](@ref ref-estimate-multivariate-qvar), [`qfavar`](@ref ref-estimate-multivariate-qfavar) | Quantile-specific VAR/FAVAR dynamics (`--taus`, VB or frequentist; structural paths via [`irf qvar`](@ref ref-irf-qvar) and [`irf qfavar`](@ref ref-irf-qfavar)) |
| Non-Gaussian / Structural VARMA | [`lms-svar`](@ref ref-estimate-multivariate-lms-svar), [`lanne-luoto`](@ref ref-estimate-multivariate-lanne-luoto), [`ssvarma`](@ref ref-estimate-multivariate-ssvarma) | Lanne–Meitz–Saikkonen MLE SVAR, Lanne–Luoto co-kurtosis GMM, and structural SVARMA (`--ar-lags`, `--ma-lags`, `--blaschke`, [`irf`/`fevd ssvarma`](@ref ref-irf-ssvarma)) |

All PCA, spectral, and quantile factor models support common-component fitted values via [`predict factor`](@ref ref-fam-predict-factor), idiosyncratic residuals via [`residuals factor`](@ref ref-fam-residuals-factor), and multi-step forecasts via [`forecast factor`](@ref ref-fam-forecast-factor). Test factor dimension and quantile-factor spanning via [`test factor`](@ref ref-fam-test-factor) ([Hypothesis Testing & Diagnostics](@ref chap-tests)). Note that [`estimate multivariate qvar`](@ref ref-estimate-multivariate-qvar) and [`estimate multivariate qfavar`](@ref ref-estimate-multivariate-qfavar) emit tabular estimation output only (no `--plot`), while [`irf qvar`](@ref ref-irf-qvar), [`irf qfavar`](@ref ref-irf-qfavar), and [`estimate factor qfm`](@ref ref-estimate-factor-qfm) support interactive `--plot` / `--plot-save`.

<!-- capture -->
```bash
frdc --quiet data simulate factors --series 10 --periods 80 --burn 20 --seed 9 --save-data fac_sim
frdc estimate factor static fac_sim --nfactors 2
```
```text
Scree Data (Eigenvalues & Variance Shares)
┌───────────┬────────────┬────────────┐
│ component │ eigenvalue │ cumulative │
├───────────┼────────────┼────────────┤
│     1     │   0.511    │   0.511    │
│     2     │   0.284    │   0.796    │
│     3     │   0.050    │   0.845    │
│     4     │   0.034    │   0.879    │
│     5     │   0.028    │   0.907    │
│     6     │   0.026    │   0.932    │
│     7     │   0.020    │   0.953    │
│     8     │   0.019    │   0.972    │
│     9     │   0.017    │   0.989    │
│    10     │   0.011    │   1.000    │
└───────────┴────────────┴────────────┘
       Factor Loadings
┌──────────┬────────┬────────┐
│ variable │   F1   │   F2   │
├──────────┼────────┼────────┤
│    x1    │ 0.796  │ -0.394 │
│    x2    │ 0.255  │ 0.866  │
│    x3    │ -0.847 │ -0.342 │
│    x4    │ 0.900  │ 0.100  │
│    x5    │ 0.669  │ -0.536 │
│    x6    │ 0.450  │ -0.695 │
│    x7    │ -0.612 │ -0.683 │
│    x8    │ 0.887  │ -0.088 │
│    x9    │ -0.752 │ -0.516 │
│   x10    │ -0.667 │ 0.516  │
└──────────┴────────┴────────┘
```

Extracting two static factors (`--nfactors 2`; omit `--nfactors` to select rank automatically via `--criterion ic1|ic2|ic3`), the first two components explain `0.795612` (`0.511257` + `0.284355`) cumulative variance share in `scree_data_eigenvalues_variance_shares` alongside loadings in `factor_loadings`.

To capture tail-specific comovement missed by mean-variance PCA, simulate a quantile-factor DGP ([`data simulate qfm`](@ref ref-data-simulate-qfm)) and fit [`estimate factor qfm`](@ref ref-estimate-factor-qfm) at $\tau = 0.5$:

<!-- capture -->
```bash
frdc --quiet data simulate qfm --periods 60 --series 8 --seed 11 --save-data qfm_sim
frdc estimate factor qfm qfm_sim --tau 0.5 --factors 2 --standardize
```
```text
          Quantile Factor Model Loadings (r=2, τ=0.5)
┌──────────┬────────┬───────┬─────────┬───────────┬───────────┐
│ variable │ factor │  tau  │ loading │ std_error │ pseudo_r2 │
├──────────┼────────┼───────┼─────────┼───────────┼───────────┤
│    x1    │   1    │ 0.500 │  0.891  │  missing  │   0.650   │
│    x2    │   1    │ 0.500 │  0.827  │  missing  │   0.443   │
│    x3    │   1    │ 0.500 │ -1.383  │  missing  │   1.000   │
│    x4    │   1    │ 0.500 │  0.918  │  missing  │   0.589   │
│    x5    │   1    │ 0.500 │  0.891  │  missing  │   0.327   │
│    x6    │   1    │ 0.500 │ -0.649  │  missing  │   0.266   │
│    x7    │   1    │ 0.500 │ -0.898  │  missing  │   0.503   │
│    x8    │   1    │ 0.500 │  0.680  │  missing  │   0.385   │
│    x1    │   2    │ 0.500 │  0.464  │  missing  │   0.650   │
│    x2    │   2    │ 0.500 │  0.459  │  missing  │   0.443   │
│    x3    │   2    │ 0.500 │  1.692  │  missing  │   1.000   │
│    x4    │   2    │ 0.500 │  0.419  │  missing  │   0.589   │
│    x5    │   2    │ 0.500 │  0.265  │  missing  │   0.327   │
│    x6    │   2    │ 0.500 │ -0.300  │  missing  │   0.266   │
│    x7    │   2    │ 0.500 │ -0.465  │  missing  │   0.503   │
│    x8    │   2    │ 0.500 │  0.460  │  missing  │   0.385   │
└──────────┴────────┴───────┴─────────┴───────────┴───────────┘
```

The quantile factor fit emits `qfm_summary` and `qfm_loadings` at the requested quantile(s), feeding [`forecast factor qfm`](@ref ref-forecast-factor-qfm), [`forecast factor growth-at-risk`](@ref ref-forecast-factor-growth-at-risk), and [`test factor qfm-spanning`](@ref ref-test-factor-qfm-spanning).

---

## Common Pitfalls

1. **Supplying $I(1)$ levels directly to BVAR vs VECM without transformation:** Use [`estimate multivariate vecm`](@ref ref-estimate-multivariate-vecm) when testing equilibrium cointegrating vectors $\beta$ on levels; if fitting a large reduced-form VAR or factor model (`:fred_md`), apply FRED transformations first ([Data Management & Simulation](@ref chap-data)).
2. **Omitting `--key-vars` or `--low-freq`:** [`estimate multivariate favar`](@ref ref-estimate-multivariate-favar) needs observable slow/policy series listed in `--key-vars` (comma-separated names or 1-based indices), and [`mfvar`](@ref ref-estimate-multivariate-mfvar) requires `--low-freq` alongside `--freq-ratio`.
3. **Confusing `forecast` and `irf` horizons/CI options:** Conditional [`forecast multivariate var`](@ref ref-forecast-multivariate-var) takes `--ci-method analytical|bootstrap|none` with `--confidence 0.95`, whereas structural [`irf var`](@ref ref-irf-var) uses `--ci` and `--replications` (Chapter [Structural ID, LP & Innovation Accounting](@ref chap-structural)).

---

## References

- Stock, J. H., & Watson, M. W. (2002). Forecasting using principal components from a large number of predictors. *JASA*, 97(460), 1167–1179.
- Giannone, D., Lenza, M., & Primiceri, G. E. (2015). Prior selection for vector autoregressions. *Review of Economics and Statistics*, 97(2), 436–451.
- Bernanke, B. S., Boivin, J., & Eliasz, P. (2005). Measuring the effects of monetary policy: A factor-augmented vector autoregressive (FAVAR) approach. *QJE*, 120(1), 387–422.
- Upstream manuals: [MacroEconometricModels.jl — VAR & VECM](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/var/), [Factor Models](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/factors/)
- CLI reference: [`frdc estimate multivariate`](@ref ref-fam-estimate-multivariate), [`frdc estimate factor`](@ref ref-fam-estimate-factor), [`frdc forecast multivariate`](@ref ref-fam-forecast-multivariate)
