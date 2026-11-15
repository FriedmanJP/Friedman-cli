# [VAR, BVAR, VECM & Factor Models](@id chap-multivariate)

Reduced-form and high-dimensional multivariate time-series models capture joint lag feedback, Bayesian shrinkage, long-run cointegration, mixed-frequency ragged edges, drifting parameters, and pervasive factor comovement across [`estimate multivariate`](@ref ref-fam-estimate-multivariate) and [`estimate factor`](@ref ref-fam-estimate-factor), paired with [`forecast`](@ref ref-forecast), [`predict`](@ref ref-predict), and [`residuals`](@ref ref-residuals). See [MacroEconometricModels.jl — VAR & VECM](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/var/) and [Factor Models](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/factors/).

## Quick Start

Import the five-series Danish money demand panel (`:denmark`), fit a reduced-form `VAR(2)` saving the model handle, and compute a 4-step analytical forecast without re-estimating:

<!-- capture -->
```bash
friedman --quiet data import :denmark -o macro
friedman --seed 42 --quiet estimate multivariate var macro --lags 2 --save-model var_fit
friedman forecast multivariate var macro --model var_fit.jld2 --horizons 4 --ci-method analytical
```
```text
              VAR(2) Forecast (h=4, 95% CI)
┌─────────┬──────────┬───────────┬───────────┬───────────┐
│ horizon │ variable │   value   │   lower   │   upper   │
│  Int64  │  String  │  Float64  │ Float64?  │ Float64?  │
├─────────┼──────────┼───────────┼───────────┼───────────┤
│    1    │   LRM    │  12.0431  │  12.0017  │  12.0846  │
│    1    │   LRY    │  6.06282  │  6.02513  │  6.10051  │
│    1    │   LPY    │ 0.477316  │ 0.463932  │ 0.490701  │
│    1    │   IBO    │ 0.116264  │  0.10072  │ 0.131807  │
│    1    │   IDE    │ 0.074713  │ 0.0652152 │ 0.0842107 │
│    2    │   LRM    │  12.0441  │  11.9899  │  12.0983  │
│    2    │   LRY    │  6.07882  │  6.02663  │  6.13101  │
│    2    │   LPY    │ 0.485872  │ 0.466562  │ 0.505182  │
│    2    │   IBO    │ 0.116847  │ 0.0904624 │ 0.143231  │
│    2    │   IDE    │ 0.0751382 │ 0.0603916 │ 0.0898848 │
│    3    │   LRM    │  12.0551  │  11.9834  │  12.1269  │
│    3    │   LRY    │  6.08565  │  6.02649  │  6.14481  │
│    3    │   LPY    │ 0.495256  │ 0.471094  │ 0.519417  │
│    3    │   IBO    │  0.11898  │ 0.0841536 │ 0.153806  │
│    ⋮    │    ⋮     │     ⋮     │     ⋮     │     ⋮     │
└─────────┴──────────┴───────────┴───────────┴───────────┘
                                            6 rows omitted
```

The command populates `var_forecast` in `--format json` (`LRM = 12.0431` with 95% analytical CI `[12.0017, 12.0846]` and `LRY = 6.06282` at horizon 1), while saving `var_fit.jld2` avoids redundant OLS estimation when moving to [`irf var`](@ref ref-irf-var), [`fevd var`](@ref ref-fevd-var), and [`hd var`](@ref ref-hd-var).

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
friedman --seed 42 estimate multivariate bvar :denmark --lags 2 --draws 300 --sampler direct
```
```text
                      BVAR(2) Posterior Mean Coefficients
┌──────────┬──────────────┬────────────┬───────────┬────────────┬────────────┬──
│ equation │    LRM_L1    │   LRY_L1   │  LPY_L1   │   IBO_L1   │   IDE_L1   │ ⋯
│  String  │   Float64    │  Float64   │  Float64  │  Float64   │  Float64   │ ⋯
├──────────┼──────────────┼────────────┼───────────┼────────────┼────────────┼──
│   LRM    │  0.0119857   │  0.877118  │ 0.067989  │ -0.170647  │ -0.243739  │ ⋯
│   LRY    │  0.00464019  │  0.170573  │ 0.878546  │ -0.104794  │ -0.0559101 │ ⋯
│   LPY    │   0.025765   │ -0.0522971 │ -0.017193 │  0.695814  │ 0.0536953  │ ⋯
│   IBO    │ -0.00111207  │ -0.0203468 │ 0.0780604 │ 0.00957638 │  0.714109  │ ⋯
│   IDE    │ -0.000842009 │ -0.014142  │ 0.0138447 │ 0.0359852  │  0.092833  │ ⋯
└──────────┴──────────────┴────────────┴───────────┴────────────┴────────────┴──
                                                               6 columns omitted
Minnesota Hyperparameters (glp)
┌────────────────┬───────────┐
│   parameter    │   value   │
│     String     │  Float64  │
├────────────────┼───────────┤
│      tau       │ 0.358498  │
│     decay      │    0.5    │
│     lambda     │ 0.0577708 │
│       mu       │ 0.987902  │
│     omega      │    1.0    │
│     log_ml     │  766.07   │
│ log_ml_default │  697.472  │
│ log_posterior  │  761.733  │
│   converged    │    1.0    │
│    at_bound    │    0.0    │
│   iterations   │   273.0   │
└────────────────┴───────────┘
Information Criteria (Posterior Mean)
┌────────────────┬─────────┐
│     metric     │  value  │
│     String     │ Float64 │
├────────────────┼─────────┤
│      AIC       │   0.0   │
│      BIC       │   0.0   │
│      HQC       │   0.0   │
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
friedman estimate multivariate vecm :denmark --lags 2 --deterministic constant
```
```text
      Cointegrating Vectors (beta)
┌──────────┬─────────────┬─────────────┐
│ variable │     CV1     │     CV2     │
│  String  │   Float64   │   Float64   │
├──────────┼─────────────┼─────────────┤
│   LRM    │     1.0     │ 5.24407e-17 │
│   LRY    │ -1.2858e-16 │     1.0     │
│   LPY    │ -0.0723162  │  0.0598584  │
│   IBO    │   4.38496   │  -1.11514   │
│   IDE    │   -1.3413   │   0.73811   │
└──────────┴─────────────┴─────────────┘
   Adjustment Coefficients (alpha)
┌──────────┬────────────┬────────────┐
│ equation │    CV1     │    CV2     │
│  String  │  Float64   │  Float64   │
├──────────┼────────────┼────────────┤
│   LRM    │ -0.332801  │ 0.0659877  │
│   LRY    │ -0.0234682 │ -0.0481643 │
│   LPY    │ 0.0223528  │ -0.0634239 │
│   IBO    │ 0.00148706 │ 0.0127652  │
│   IDE    │ 0.0103393  │ 0.00686566 │
└──────────┴────────────┴────────────┘
    Information Criteria
┌────────────────┬──────────┐
│     metric     │  value   │
│     String     │ Float64  │
├────────────────┼──────────┤
│      AIC       │ -44.9501 │
│      BIC       │ -43.4631 │
│      HQC       │ -44.3783 │
│ Log-likelihood │ 855.159  │
└────────────────┴──────────┘
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
| Structural DFM | [`estimate factor sdfm`](@ref ref-estimate-factor-sdfm) | Hallin–Liška / Bai–Ng / Amengual–Watson dynamic shocks (`sdfm_estimation_summary`, `irf`/`fevd`/`hd sdfm`) |
| Factor-Augmented VAR | [`estimate multivariate favar`](@ref ref-estimate-multivariate-favar) | Bernanke–Boivin–Eliasz `--key-vars` combined with slow/fast factor block (`two_step` or `bayesian`) |

All three PCA/spectral factor models support common-component fitted values via [`predict factor`](@ref ref-fam-predict-factor), idiosyncratic residuals via [`residuals factor`](@ref ref-fam-residuals-factor), and multi-step forecasts via [`forecast factor`](@ref ref-fam-forecast-factor).

<!-- capture -->
```bash
friedman --quiet data simulate factors --series 10 --periods 80 --burn 20 --seed 9 --save-data fac_sim
friedman estimate factor static fac_sim --nfactors 2
```
```text
Scree Data (Eigenvalues & Variance Shares)
┌───────────┬────────────┬────────────┐
│ component │ eigenvalue │ cumulative │
│   Int64   │  Float64   │  Float64   │
├───────────┼────────────┼────────────┤
│     1     │  0.511257  │  0.511257  │
│     2     │  0.284355  │  0.795612  │
│     3     │ 0.0495776  │  0.845189  │
│     4     │ 0.0340355  │  0.879225  │
│     5     │ 0.0277125  │  0.906937  │
│     6     │ 0.0255505  │  0.932488  │
│     7     │ 0.0200195  │  0.952507  │
│     8     │ 0.0191272  │  0.971635  │
│     9     │ 0.0168665  │  0.988501  │
│    10     │  0.011499  │    1.0     │
└───────────┴────────────┴────────────┘
           Factor Loadings
┌──────────┬───────────┬────────────┐
│ variable │    F1     │     F2     │
│  String  │  Float64  │  Float64   │
├──────────┼───────────┼────────────┤
│    x1    │ 0.795769  │ -0.393819  │
│    x2    │ 0.254682  │  0.865641  │
│    x3    │ -0.847457 │ -0.342054  │
│    x4    │ 0.900288  │ 0.0999792  │
│    x5    │ 0.668674  │ -0.535883  │
│    x6    │ 0.450025  │ -0.695123  │
│    x7    │ -0.612411 │ -0.682591  │
│    x8    │  0.88683  │ -0.0876232 │
│    x9    │ -0.75204  │ -0.516101  │
│   x10    │ -0.667175 │  0.515989  │
└──────────┴───────────┴────────────┘
```

Extracting two static factors (`--nfactors 2`; omit `--nfactors` to select rank automatically via `--criterion ic1|ic2|ic3`), the first two components explain `0.795612` (`0.511257` + `0.284355`) cumulative variance share in `scree_data_eigenvalues_variance_shares` alongside loadings in `factor_loadings`.

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
- CLI reference: [`friedman estimate multivariate`](@ref ref-fam-estimate-multivariate), [`friedman estimate factor`](@ref ref-fam-estimate-factor), [`friedman forecast multivariate`](@ref ref-fam-forecast-multivariate)
