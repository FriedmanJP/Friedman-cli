# [Regression, Systems & GMM/SMM](@id chap-regression)

Continuous cross-sectional, cointegrating, regularized, quantile, nonparametric, multi-equation simultaneous, and moment-based estimators live under [`estimate regression`](@ref ref-fam-estimate-regression) (`reg`, `iv`, `qreg`, `rdd`, `lasso`, `ridge`, `elastic-net`, `robust`, `cointreg`, `kde`, `kernel-reg`, `lowess`, `sur`, `3sls`, `gmm`, `smm`), with fitted predictions ([`predict regression`](@ref ref-fam-predict-regression)) and residuals ([`residuals regression`](@ref ref-fam-residuals-regression)) for `reg`, `sur`, and `3sls`. (Discrete choice, Tobit, truncated, and Heckman selection estimators are covered in [Discrete Choice, Count & Selection](@ref chap-choice).) See [MacroEconometricModels.jl — Cross-Sectional & GMM](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/regression/) for upstream details.

## Quick Start

Simulate an instrumental-variables dataset (`lp-iv`) with endogenous regressor `s`, control `x2`, and excluded instrument `z1`, then fit 2SLS (`--method tsls`) with HC1 covariance:

<!-- capture -->
```bash
frdc --quiet data simulate lp-iv --periods 200 --seed 42 --save-data iv_sim
frdc estimate regression iv iv_sim --dep y --endogenous s --instruments z1 --method tsls --cov-type hc1
```
```text
                      IV (2SLS) Regression Coefficients
┌──────┬──────────┬───────────┬─────────┬─────────────┬──────────┬──────────┐
│ term │ estimate │ std_error │  stat   │   p_value   │ ci_lower │ ci_upper │
├──────┼──────────┼───────────┼─────────┼─────────────┼──────────┼──────────┤
│  s   │ 0.751309 │ 0.0981391 │ 7.65555 │ 8.29559e-13 │ 0.557777 │ 0.944841 │
│  x2  │ 0.647819 │ 0.128301  │ 5.04922 │  1.0032e-6  │ 0.394807 │ 0.90083  │
└──────┴──────────┴───────────┴─────────┴─────────────┴──────────┴──────────┘
       IV Diagnostics
┌───────────────┬──────────┐
│    metric     │  value   │
├───────────────┼──────────┤
│      R²       │ 0.600961 │
│    Adj. R²    │ 0.598946 │
│    method     │   tsls   │
│ First-stage F │ 298.231  │
└───────────────┴──────────┘
```

The command returns `iv_coefficients` (`s = 0.751309`, SE `0.0981391`; `x2 = 0.647819`) and `iv_diagnostics` (`R² = 0.600961`, `First-stage F = 298.231`, alongside `--method liml|fuller|kclass`); follow up with [`test iv weak-instrument`](@ref ref-test-iv-weak-instrument) and weak-IV-robust [`test iv anderson-rubin`](@ref ref-test-iv-anderson-rubin).

---

## Linear OLS, IV/2SLS, Quantile & Treatment Effects (`reg`, `iv`, `qreg`, `rdd`)

Standard cross-sectional linear and quasi-experimental regressions cover heteroskedasticity-, cluster-, and Conley spatial-HAC inference as well as causal discontinuities:

```math
y_i = x_i'\beta + \varepsilon_i, \qquad \widehat{\beta}_{\text{GMM/2SLS}} = (X' P_Z X)^{-1} X' P_Z y.
```

| Estimator Leaf | Core Specification | Key Diagnostics / Tests |
|---|---|---|
| [`reg`](@ref ref-estimate-regression-reg) | OLS / WLS (`--weights`) with `ols`, `hc0`–`hc3`, `cluster`, or spatial `conley` (`--lat`, `--lon`, `--dist-cutoff`, `--time-col`) | [`test vif`](@ref ref-test-vif), [`test influence`](@ref ref-test-influence), [`test serial white`](@ref ref-test-serial-white) |
| [`iv`](@ref ref-estimate-regression-iv) | `tsls`, `liml`, `fuller` (`--fuller-a`), `kclass` (`--k`) | [`test iv weak-instrument`](@ref ref-test-iv-weak-instrument), [`test iv anderson-rubin`](@ref ref-test-iv-anderson-rubin), [`test iv wild-cluster`](@ref ref-test-iv-wild-cluster) |
| [`qreg`](@ref ref-estimate-regression-qreg) | Quantile regression at `--tau` (`0.5` median or comma list) with `iid`, `robust`, or `--n-boot` SEs | `quantile_regression_coefficients`, `quantile_fit_diagnostics` |
| [`rdd`](@ref ref-estimate-regression-rdd) | Sharp or fuzzy (`--fuzzy`) local polynomial RD at `--cutoff` (`triangular`, `epanechnikov`, `uniform`) | `rdd_treatment_effect`, `rdd_settings_diagnostics` |

---

## Shrinkage, Robust, Cointegrating & Nonparametric Regressions

- **Penalized Linear Models ([`lasso`](@ref ref-estimate-regression-lasso), [`ridge`](@ref ref-estimate-regression-ridge), [`elastic-net`](@ref ref-estimate-regression-elastic-net)):** Select regularization weight `--lambda` automatically by cross-validation, AIC, BIC, or EBIC (`--select cv|aic|bic|ebic`; `--alpha` blends $\ell_1/\ell_2$ penalties).
- **Outlier-Resistant Regression ([`robust`](@ref ref-estimate-regression-robust)):** Computes IRLS M-estimates or high-breakdown MM-estimates using Huber (`--psi huber`) or Tukey biweight (`--psi bisquare`) loss (`robust_regression_coefficients`, `robust_regression_diagnostics`).
- **Single-Equation Cointegrating Regression ([`cointreg`](@ref ref-estimate-regression-cointreg)):** Eliminates endogeneity and serial-correlation bias among $I(1)$ variables via Fully Modified OLS (`fmols`), Canonical Cointegrating Regression (`ccr`), or Dynamic OLS (`dols`) with automatic leads/lags and Andrews HAC kernels; validate stability using [`test park-added`](@ref ref-test-park-added) and [`test stability hansen-instability`](@ref ref-test-stability-hansen-instability).
- **Nonparametric Curves ([`kde`](@ref ref-estimate-regression-kde), [`kernel-reg`](@ref ref-estimate-regression-kernel-reg), [`lowess`](@ref ref-estimate-regression-lowess)):** Estimate univariate kernel densities (`silverman`/custom bandwidth), Nadaraya–Watson / local linear / local polynomial regressions (`--method nw|ll|lp`), and robust locally weighted scatter smoothing (`--frac`, `--iter`).

<!-- capture -->
```bash
frdc estimate regression robust :stackloss --dep stack.loss --psi huber --method mm
```
```text
              Robust Regression Coefficients
┌────────────┬───────────┬───────────┬─────────┬─────────┐
│ parameter  │ estimate  │ std_error │ z_stat  │ p_value │
├────────────┼───────────┼───────────┼─────────┼─────────┤
│  Air.Flow  │  0.81035  │ 0.174304  │ 4.6491  │   0.0   │
│ Water.Temp │  1.01971  │ 0.478114  │ 2.1328  │ 0.0329  │
│ Acid.Conc. │ -0.611146 │ 0.088822  │ -6.8806 │   0.0   │
└────────────┴───────────┴───────────┴─────────┴─────────┘
Robust Regression Diagnostics
┌────────────┬──────────┐
│   metric   │  value   │
├────────────┼──────────┤
│    psi     │ bisquare │
│   method   │    mm    │
│   scale    │ 3.19175  │
│ robust_r2  │ 0.553015 │
│   tuning   │  4.685   │
│ converged  │   true   │
│ iterations │    14    │
└────────────┴──────────┘
```

Fitted on `:stackloss`, the MM-estimator reports `Air.Flow = 0.81035`, `Water.Temp = 1.01971`, and `Acid.Conc. = -0.611146` in `robust_regression_coefficients` (`robust_r2 = 0.553015`, `scale = 3.19175`, converged in `14` iterations in `robust_regression_diagnostics`).

---

## Simultaneous Equations & Moment Estimators (`sur`, `3sls`, `gmm`, `smm`)

Multi-equation linear systems and generalized method-of-moments / simulated method-of-moments estimators accept concise **model card** files (`--config`) or TOML configs defined in [GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy):

```math
\hat{\theta}_{\text{GMM}} = \arg\min_\theta \bar{g}_T(\theta)' W \bar{g}_T(\theta), \qquad \bar{g}_T(\theta) = \frac{1}{T}\sum_{t=1}^T g(z_t, \theta).
```

- **Seemingly Unrelated & Three-Stage Least Squares ([`sur`](@ref ref-estimate-regression-sur), [`3sls`](@ref ref-estimate-regression-3sls)):** Supply an `equations:` card (plus `instruments:` or per-equation `| instr` for `3sls`); pass `--iterate` on `sur` for iterative Zellner GLS (`sur_coefficients`, `3sls_coefficients`).
- **GMM ([`gmm`](@ref ref-estimate-regression-gmm)):** Use `gmm lp:` cards for horizon-0 moment conditions or `gmm iv:` cards for linear IV-GMM (`--weighting identity|optimal|twostep|iterated`); output keys are `gmm_estimates` and `gmm_diagnostics`.
- **SMM ([`smm`](@ref ref-estimate-regression-smm)):** Matches simulated autocovariance moments (`ar1`, `arp`, `var1`, `iid_normal`) to sample moments (`--sim-ratio`, `--burn`, leading `--seed`).

<!-- capture -->
```bash
frdc --quiet data simulate arima --phi 0.6 --sigma 0.8 --periods 150 --burn 50 --seed 9 --save-data ar1_sim
cat > smm_card <<'EOF'
smm:
  model: ar1
  theta0: 0.4, 0.5
  lags: 2
  lower: -0.99, 1.0e-4
  upper: 0.99, 10.0
EOF
frdc --seed 9 estimate regression smm ar1_sim --config smm_card --sim-ratio 4 --burn 50
```
```text
     SMM Estimation (model=ar1, weighting=two_step)
┌───────────┬──────────┬───────────┬─────────┬─────────┐
│ parameter │ estimate │ std_error │ t_stat  │ p_value │
├───────────┼──────────┼───────────┼─────────┼─────────┤
│    phi    │ 0.641416 │ 0.071546  │ 8.9651  │   0.0   │
│   sigma   │ 0.799064 │ 0.055001  │ 14.5282 │   0.0   │
└───────────┴──────────┴───────────┴─────────┴─────────┘
```

Two-step SMM (`smm_estimates`) recovers persistence `phi = 0.641416` (true `0.6`) and innovation scale `sigma = 0.799064` (true `0.8`) using the simulated autocovariance conditions at lags 1–2.

---

## Common Pitfalls

1. **Passing `--set` or `--config-json` alongside a model card file:** Overrides merge only into `.toml` configs; place overrides directly in the card or convert to `[gmm]`/`[smm]`/`[[equations]]` TOML ([Model Cards & Config Grammar](@ref cfg-overview)).
2. **Neglecting `id` / non-regressor columns (`obs`) in simulated cross-sections:** When running `--dep y` without formula subsetting on [`reg`](@ref ref-estimate-regression-reg), ensure CSV/handles exclude non-explanatory ID indices or use clean predictor columns.
3. **Under-identified `smm` lag count (`var1` or `arp`):** SMM identification requires $k(k+1)/2 + k \cdot \text{lags} \ge \#\theta$; increase `lags` inside the `smm:` card when fitting higher-order models.
4. **Conflating weak IVs with valid overidentification:** Always inspect first-stage partial F in [`test iv weak-instrument`](@ref ref-test-iv-weak-instrument); when instruments are weak, switch to `--method liml` or construct [`test iv anderson-rubin`](@ref ref-test-iv-anderson-rubin) sets instead of 2SLS Wald intervals.

---

## References

- Hansen, L. P. (1982). Large sample properties of generalized method of moments estimators. *Econometrica*, 50(4), 1029–1054.
- Duffie, D., & Singleton, K. J. (1993). Simulated moments estimation of Markov models of asset prices. *Econometrica*, 61(4), 929–952.
- Phillips, P. C., & Hansen, B. E. (1990). Statistical inference in instrumental variables regression with I(1) processes. *Review of Economic Studies*, 57(1), 99–125.
- Upstream manual: [MacroEconometricModels.jl — Cross-Sectional & GMM](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/regression/)
- CLI reference: [`frdc estimate regression`](@ref ref-fam-estimate-regression), [`frdc predict regression`](@ref ref-fam-predict-regression), [`frdc residuals regression`](@ref ref-fam-residuals-regression)
