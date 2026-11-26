# [Structural ID, LP & Innovation Accounting](@id chap-structural)

Recovering structural economic shocks $\varepsilon_t$ from reduced-form residuals $u_t = B_0 \varepsilon_t$—and quantifying propagation via impulse response functions ([`irf`](@ref ref-irf)), forecast error variance decompositions ([`fevd`](@ref ref-fevd)), and historical decompositions ([`hd`](@ref ref-hd))—connects reduced-form VARs/BVARs/VECMs/FAVARs/SDFMs/TVP-VARs, parametric SVAR/SVEC (`estimate multivariate svar|svec`), non-Gaussian ICA/ML (`estimate factor fastica`, `estimate regression ml`), and direct local projections (`estimate multivariate lp`). See [MacroEconometricModels.jl — Structural Identification](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/svar/) and [Local Projections](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/lp/).

## Quick Start

Estimate Cholesky-identified impulse responses with Kilian bias-corrected or iid bootstrap bands on `:denmark`, and decompose forecast error variance over 4 horizons:

<!-- capture -->
```bash
frdc --seed 42 irf var :denmark --lags 2 --shock 1 --horizons 4 --id cholesky --ci bootstrap --replications 100
```
```text
       IRF to LRM shock (cholesky identification)
┌─────────┬──────────┬───────┬────────┬────────┬────────┐
│ horizon │ variable │ shock │ value  │ lower  │ upper  │
├─────────┼──────────┼───────┼────────┼────────┼────────┤
│    1    │   LRM    │  LRM  │ 0.021  │ 0.016  │ 0.022  │
│    1    │   LRY    │  LRM  │ 0.009  │ 0.004  │ 0.012  │
│    1    │   LPY    │  LRM  │ -0.003 │ -0.004 │ -0.002 │
│    1    │   IBO    │  LRM  │ -0.003 │ -0.003 │ -0.001 │
│    1    │   IDE    │  LRM  │ 0.000  │ -0.001 │ 0.001  │
│    2    │   LRM    │  LRM  │ 0.013  │ 0.007  │ 0.014  │
│    2    │   LRY    │  LRM  │ 0.011  │ 0.005  │ 0.013  │
│    2    │   LPY    │  LRM  │ -0.003 │ -0.004 │ -0.002 │
│    2    │   IBO    │  LRM  │ -0.002 │ -0.003 │ 0.000  │
│    2    │   IDE    │  LRM  │ -0.001 │ -0.001 │ 0.000  │
│    3    │   LRM    │  LRM  │ 0.014  │ 0.008  │ 0.016  │
│    3    │   LRY    │  LRM  │ 0.007  │ 0.002  │ 0.007  │
│    3    │   LPY    │  LRM  │ -0.003 │ -0.003 │ -0.001 │
│    3    │   IBO    │  LRM  │ -0.001 │ -0.002 │ 0.001  │
│    3    │   IDE    │  LRM  │ -0.001 │ -0.001 │ 0.000  │
│    4    │   LRM    │  LRM  │ 0.010  │ 0.003  │ 0.014  │
│    4    │   LRY    │  LRM  │ 0.006  │ 0.001  │ 0.007  │
│    4    │   LPY    │  LRM  │ -0.003 │ -0.004 │ -0.001 │
│    4    │   IBO    │  LRM  │ -0.001 │ -0.002 │ 0.001  │
│    4    │   IDE    │  LRM  │ -0.001 │ -0.001 │ 0.001  │
└─────────┴──────────┴───────┴────────┴────────┴────────┘
```

The command outputs tidy bands under the JSON table key `irf` (`LRM` responds on impact by `0.021` with 68% CI `[0.016, 0.022]` while `IBO` dips by `-0.003`); pair with `--save-model` / `--model` from [`estimate multivariate var`](@ref ref-estimate-multivariate-var) ([Pipelines, Handles & Reproducibility](@ref gs-pipelines)) to lock reduced-form estimates across `irf`, `fevd`, and `hd`.

---

## Classical, Set-Identified & Narrative SVAR Identification

Because covariance symmetry $\Sigma_u = B_0 B_0'$ leaves $n(n-1)/2$ free parameters of an orthogonal rotation $Q$ ($QQ' = I_n$) undetermined, structural identification requires theory-guided restrictions passed via `--id` and (for matrices/inequalities/dates) `--config` ([Priors, SVAR & VECM Identification](@ref cfg-identification)):

```math
u_t = B_0 \varepsilon_t, \qquad \mathrm{Var}(\varepsilon_t) = I_n, \qquad \Theta_h = \Phi_h B_0 Q.
```

| Identification Strategy | `--id` Value(s) | Restriction Mechanism & Output Notes |
|---|---|---|
| Recursive & Long-Run | `cholesky`, `longrun` | Impact lower-triangular ($B_0 = \mathrm{chol}(\Sigma_u)$) or Blanchard–Quah long-run zeros (`estimate multivariate svar` patterns `recursive`, `blanchard-quah`, `a-model`, `b-model`, `ab-model`; cointegrated `svec`) |
| Sign & Narrative | `sign`, `narrative` | `[identification.sign_matrix]` signs on responses plus `[identification.narrative]` shock signs; add `--identified-set` + `--summary` (`median-target`\|`modal-model`\|`joint-band`\|`sup-t-band`) |
| Zero + Sign & Penalty | `arias`, `uhlig`, `narrative-adrr` | Importance sampling on $Q$ (Arias et al. 2018; ADRR narrative shares) or penalty optimization (Mountford–Uhlig 2009); emits `arias_importance_sampling_diagnostics` |
| External Instrument / Max-Share / Moments | `proxy`, `max-share`, `gmm-moments` | Proxy SVAR via `--instrument`; Uhlig business-cycle variance share via `--target-var`; non-Gaussian skewness/kurtosis GMM |
| Robust Set-Identified BVAR | `robust-bayes` | Giacomini–Kitagawa multiple-prior bounds under [`irf bvar`](@ref ref-irf-bvar) (`robust_bayes_bands`, `robust_bayes_diagnostics`) |

<!-- capture -->
```bash
frdc fevd var :denmark --lags 2 --horizons 4 --id cholesky --normalize
```
```text
    FEVD (cholesky identification)
┌─────────┬──────────┬───────┬───────┐
│ horizon │ variable │ shock │ value │
├─────────┼──────────┼───────┼───────┤
│    1    │   LRM    │  LRM  │ 1.000 │
│    1    │   LRM    │  LRY  │ 0.000 │
│    1    │   LRM    │  LPY  │ 0.000 │
│    1    │   LRM    │  IBO  │ 0.000 │
│    1    │   LRM    │  IDE  │ 0.000 │
│    1    │   LRY    │  LRM  │ 0.204 │
│    1    │   LRY    │  LRY  │ 0.796 │
│    1    │   LRY    │  LPY  │ 0.000 │
│    1    │   LRY    │  IBO  │ 0.000 │
│    1    │   LRY    │  IDE  │ 0.000 │
│    1    │   LPY    │  LRM  │ 0.195 │
│    1    │   LPY    │  LRY  │ 0.131 │
│    1    │   LPY    │  LPY  │ 0.674 │
│    1    │   LPY    │  IBO  │ 0.000 │
│    1    │   LPY    │  IDE  │ 0.000 │
│    1    │   IBO    │  LRM  │ 0.120 │
│    1    │   IBO    │  LRY  │ 0.049 │
│    1    │   IBO    │  LPY  │ 0.032 │
│    1    │   IBO    │  IBO  │ 0.799 │
│    1    │   IBO    │  IDE  │ 0.000 │
│    1    │   IDE    │  LRM  │ 0.003 │
│    1    │   IDE    │  LRY  │ 0.019 │
│    1    │   IDE    │  LPY  │ 0.141 │
│    1    │   IDE    │  IBO  │ 0.030 │
│    1    │   IDE    │  IDE  │ 0.807 │
│    2    │   LRM    │  LRM  │ 0.792 │
│    2    │   LRM    │  LRY  │ 0.000 │
│    2    │   LRM    │  LPY  │ 0.144 │
│    2    │   LRM    │  IBO  │ 0.064 │
│    2    │   LRM    │  IDE  │ 0.000 │
│    2    │   LRY    │  LRM  │ 0.281 │
│    2    │   LRY    │  LRY  │ 0.647 │
│    2    │   LRY    │  LPY  │ 0.051 │
│    2    │   LRY    │  IBO  │ 0.003 │
│    2    │   LRY    │  IDE  │ 0.018 │
│    2    │   LPY    │  LRM  │ 0.215 │
│    2    │   LPY    │  LRY  │ 0.077 │
│    2    │   LPY    │  LPY  │ 0.679 │
│    2    │   LPY    │  IBO  │ 0.028 │
│    2    │   LPY    │  IDE  │ 0.000 │
│    2    │   IBO    │  LRM  │ 0.067 │
│    2    │   IBO    │  LRY  │ 0.149 │
│    2    │   IBO    │  LPY  │ 0.050 │
│    2    │   IBO    │  IBO  │ 0.733 │
│    2    │   IBO    │  IDE  │ 0.000 │
│    2    │   IDE    │  LRM  │ 0.015 │
│    2    │   IDE    │  LRY  │ 0.008 │
│    2    │   IDE    │  LPY  │ 0.212 │
│    2    │   IDE    │  IBO  │ 0.186 │
│    2    │   IDE    │  IDE  │ 0.578 │
│    3    │   LRM    │  LRM  │ 0.607 │
│    3    │   LRM    │  LRY  │ 0.063 │
│    3    │   LRM    │  LPY  │ 0.109 │
│    3    │   LRM    │  IBO  │ 0.221 │
│    3    │   LRM    │  IDE  │ 0.000 │
│    3    │   LRY    │  LRM  │ 0.268 │
│    3    │   LRY    │  LRY  │ 0.565 │
│    3    │   LRY    │  LPY  │ 0.102 │
│    3    │   LRY    │  IBO  │ 0.003 │
│    3    │   LRY    │  IDE  │ 0.062 │
│    3    │   LPY    │  LRM  │ 0.209 │
│    3    │   LPY    │  LRY  │ 0.050 │
│    3    │   LPY    │  LPY  │ 0.673 │
│    3    │   LPY    │  IBO  │ 0.068 │
│    3    │   LPY    │  IDE  │ 0.000 │
│    3    │   IBO    │  LRM  │ 0.044 │
│    3    │   IBO    │  LRY  │ 0.187 │
│    3    │   IBO    │  LPY  │ 0.038 │
│    3    │   IBO    │  IBO  │ 0.728 │
│    3    │   IBO    │  IDE  │ 0.002 │
│    3    │   IDE    │  LRM  │ 0.022 │
│    3    │   IDE    │  LRY  │ 0.045 │
│    3    │   IDE    │  LPY  │ 0.199 │
│    3    │   IDE    │  IBO  │ 0.313 │
│    3    │   IDE    │  IDE  │ 0.421 │
│    4    │   LRM    │  LRM  │ 0.426 │
│    4    │   LRM    │  LRY  │ 0.115 │
│    4    │   LRM    │  LPY  │ 0.099 │
│    4    │   LRM    │  IBO  │ 0.360 │
│    4    │   LRM    │  IDE  │ 0.000 │
│    4    │   LRY    │  LRM  │ 0.262 │
│    4    │   LRY    │  LRY  │ 0.493 │
│    4    │   LRY    │  LPY  │ 0.126 │
│    4    │   LRY    │  IBO  │ 0.017 │
│    4    │   LRY    │  IDE  │ 0.102 │
│    4    │   LPY    │  LRM  │ 0.200 │
│    4    │   LPY    │  LRY  │ 0.040 │
│    4    │   LPY    │  LPY  │ 0.641 │
│    4    │   LPY    │  IBO  │ 0.118 │
│    4    │   LPY    │  IDE  │ 0.001 │
│    4    │   IBO    │  LRM  │ 0.037 │
│    4    │   IBO    │  LRY  │ 0.196 │
│    4    │   IBO    │  LPY  │ 0.030 │
│    4    │   IBO    │  IBO  │ 0.729 │
│    4    │   IBO    │  IDE  │ 0.009 │
│    4    │   IDE    │  LRM  │ 0.021 │
│    4    │   IDE    │  LRY  │ 0.086 │
│    4    │   IDE    │  LPY  │ 0.173 │
│    4    │   IDE    │  IBO  │ 0.393 │
│    4    │   IDE    │  IDE  │ 0.327 │
└─────────┴──────────┴───────┴───────┘
```

With `--normalize`, variance shares across structural shocks sum to `1.0` at every horizon (`fevd`, or `generalized_fevd` with `--generalized`): at horizon `1`, the `LRM` shock explains `1.0` of `LRM` and `0.203699` of `LRY` (`0.796301` own shock). Notice `--cumulative` integrates impulse responses over horizons when series enter in first differences.

---

## Non-Gaussian ICA & Heteroskedastic SVARs

When structural innovations are mutually independent and at most one shock is Gaussian (or conditional volatility varies across regimes or stochastic volatility states), $B_0$ is point-identified up to column permutation and sign without zero/sign timing assumptions:

- **Non-Gaussian Independence & Parametric Non-Gaussian SVAR:** Run [`estimate factor fastica`](@ref ref-estimate-factor-fastica) (`--method fastica|jade|sobi|dcov|hsic|cvm`, including Cramér–von Mises `cvm` ICA, `--contrast logcosh|exp|kurtosis`), parametric skewed/heavy-tailed MLE [`estimate regression ml`](@ref ref-estimate-regression-ml) (`--distribution student_t|mixture_normal|pml|skew_normal`), Lanne–Meitz–Saikkonen (2017) per-shock distributional MLE [`estimate multivariate lms-svar`](@ref ref-estimate-multivariate-lms-svar) (`--distributions`), Lanne–Luoto co-kurtosis GMM [`estimate multivariate lanne-luoto`](@ref ref-estimate-multivariate-lanne-luoto), or structural SVARMA [`estimate multivariate ssvarma`](@ref ref-estimate-multivariate-ssvarma) (`--blaschke` non-fundamental roots; paired with [`irf ssvarma`](@ref ref-irf-ssvarma) and [`fevd ssvarma`](@ref ref-fevd-ssvarma)). Pass `--id fastica|jade|sobi|dcov|hsic|cvm|student_t|mixture_normal|pml|skew_normal` directly to `irf`/`fevd`/`hd`.
- **SVAR Hypothesis, Fundamentalness & Non-Gaussian Diagnostics:** Test 7 structural restriction classes (`recursiveness`, `impact_zero`, `impact_linear`, `long_run`, `horizon_irf`, `mixed`, plus parametric invariance) with [`test multivariate svar-hypothesis`](@ref ref-test-multivariate-svar-hypothesis) (`[svar_hypothesis]` in [Priors, SVAR & VECM Identification](@ref cfg-identification)), verify residual independence with [`test multivariate nongaussian-diag`](@ref ref-test-multivariate-nongaussian-diag) and [`test multivariate gmm-moments`](@ref ref-test-multivariate-gmm-moments), and test VAR invertibility / informational sufficiency via [`test multivariate fundamentalness`](@ref ref-test-multivariate-fundamentalness) and [`test multivariate sufficient-info`](@ref ref-test-multivariate-sufficient-info).
- **Dynamic Factor & Frequency-Domain Structural Accounting:** Estimate one-sided FHLZ dynamic factors ([`estimate factor fhlz`](@ref ref-estimate-factor-fhlz)) or $I(1)$ permanent-transitory GDFMs ([`estimate factor gdfm-i1`](@ref ref-estimate-factor-gdfm-i1), paired with [`irf gdfm-i1`](@ref ref-irf-gdfm-i1), [`fevd gdfm-i1`](@ref ref-fevd-gdfm-i1), and [`hd gdfm-i1`](@ref ref-hd-gdfm-i1)), and compute band-specific frequency-domain variance decompositions with [`spectral fevd`](@ref ref-spectral-fevd).
- **Heteroskedasticity Identification:** Pass `--id markov_switching`, `--id garch_id`, `--id lewis-tvv` (Lewis 2021 GMM via time-varying volatility), or `--id sv-em` (Bertsche–Braun stochastic volatility EM; config schema in [Priors, SVAR & VECM Identification](@ref cfg-identification)).

<!-- capture -->
```bash
frdc --quiet data simulate svar --dist t --nu 5.0 --periods 160 --burn 50 --seed 9 --save-data svar_sim
frdc estimate factor fastica svar_sim --lags 1 --method fastica --contrast logcosh
```
```text
    Structural Impact Matrix (B0)
┌──────────┬────────┬────────┬───────┐
│ equation │   y1   │   y2   │  y3   │
├──────────┼────────┼────────┼───────┤
│    y1    │ 0.118  │ -0.039 │ 1.072 │
│    y2    │ -0.064 │ 0.993  │ 0.424 │
│    y3    │ -1.009 │ 0.079  │ 0.338 │
└──────────┴────────┴────────┴───────┘
 Structural Impact Standard Errors
┌───────────┬──────────┬───────────┐
│ parameter │ estimate │ std_error │
├───────────┼──────────┼───────────┤
│  B0[1,1]  │  0.118   │   0.087   │
│  B0[2,1]  │  -0.064  │   0.121   │
│  B0[3,1]  │  -1.009  │   0.080   │
│  B0[1,2]  │  -0.039  │   0.122   │
│  B0[2,2]  │  0.993   │   0.071   │
│  B0[3,2]  │  0.079   │   0.110   │
│  B0[1,3]  │  1.072   │   0.089   │
│  B0[2,3]  │  0.424   │   0.105   │
│  B0[3,3]  │  0.338   │   0.088   │
└───────────┴──────────┴───────────┘
Structural Shocks (first 10 observations)
┌────┬─────────┬─────────┬─────────┐
│ t  │ shock_1 │ shock_2 │ shock_3 │
├────┼─────────┼─────────┼─────────┤
│ 1  │ -0.849  │  0.073  │ -0.168  │
│ 2  │ -0.835  │ -0.691  │ -0.202  │
│ 3  │  1.665  │ -1.511  │ -1.087  │
│ 4  │ -0.029  │ -0.083  │ -0.833  │
│ 5  │ -0.573  │ -1.583  │  0.885  │
│ 6  │ -0.868  │  0.134  │  0.588  │
│ 7  │  0.354  │  0.569  │ -1.447  │
│ 8  │  0.674  │  0.875  │ -1.067  │
│ 9  │  1.188  │  0.102  │ -0.072  │
│ 10 │ -1.244  │ -0.716  │ -2.494  │
└────┴─────────┴─────────┴─────────┘
```

The FastICA estimator reports the identified impact matrix `structural_impact_matrix_b0` (e.g., `(y1, y1) = 0.118429`, `(y1, y3) = 1.07227`, `(y3, y1) = -1.0085`), asymptotic standard errors (`Structural Impact Standard Errors`), and extracted independent shock series `structural_shocks` directly without Cholesky ordering assumptions.

---

## Local Projections (`estimate multivariate lp`, `irf/fevd/hd lp`)

Jordà (2005) local projections estimate dynamic causal responses horizon-by-horizon via direct regressions of $y_{t+h}$ on the shock/instrument and control lags, avoiding VAR lag misspecification:

```math
y_{t+h} = \alpha_h + \beta_h \, s_t + \gamma_h' W_{t-1} + u_{t+h}, \qquad h = 0, \dots, H.
```

[`estimate multivariate lp`](@ref ref-estimate-multivariate-lp) supports six variants via `--method`: `standard`, `iv` (external instrument LP-IV with `--instruments`, Montiel Olea–Pflueger effective F `--mop-f`, and weak-IV Anderson–Rubin bands `--ar-bands`), penalized `smooth` B-splines (`--knots`, `--lambda`), Auerbach–Gorodnichenko `state`-dependent logistic transitions (`--state-var`, `--gamma`), inverse-probability `propensity` weighting, and doubly `robust` AIPW estimators. Follow up directly with [`irf lp`](@ref ref-irf-lp), [`fevd lp`](@ref ref-fevd-lp), [`hd lp`](@ref ref-hd-lp), or [`forecast multivariate lp`](@ref ref-forecast-multivariate-lp).

<!-- capture -->
```bash
frdc --quiet data dropna :mp_shocks -f csv -o mp_clean.csv
frdc estimate multivariate lp mp_clean.csv --method standard --shock 1 --horizons 4 --control-lags 2 --vcov newey_west
```
```text
                                                                                                                                                                                                                                  LP Coefficients (ygap → responses)
┌─────────┬───────┬─────────┬───────────┬───────────────┬───────────────┬────────┬─────────┬────────┬───────────────┬───────────────┬───────┬────────┬───────┬──────────────┬──────────────┬───────┬──────────┬─────────┬────────────────┬────────────────┬────────┬───────┬────────┬─────────────┬─────────────┬────────┬────────┬────────┬──────────────┬──────────────┬───────┬───────┬───────┬─────────────┬─────────────┬─────────┬────────────┬───────────┬──────────────────┬──────────────────┐
│ Horizon │ ygap  │ ygap_se │  ygap_t   │ ygap_ci_lower │ ygap_ci_upper │  infl  │ infl_se │ infl_t │ infl_ci_lower │ infl_ci_upper │  ffr  │ ffr_se │ ffr_t │ ffr_ci_lower │ ffr_ci_upper │ lpcom │ lpcom_se │ lpcom_t │ lpcom_ci_lower │ lpcom_ci_upper │   rr   │ rr_se │  rr_t  │ rr_ci_lower │ rr_ci_upper │  mp1   │ mp1_se │ mp1_t  │ mp1_ci_lower │ mp1_ci_upper │  ad   │ ad_se │ ad_t  │ ad_ci_lower │ ad_ci_upper │ bzk_ist │ bzk_ist_se │ bzk_ist_t │ bzk_ist_ci_lower │ bzk_ist_ci_upper │
├─────────┼───────┼─────────┼───────────┼───────────────┼───────────────┼────────┼─────────┼────────┼───────────────┼───────────────┼───────┼────────┼───────┼──────────────┼──────────────┼───────┼──────────┼─────────┼────────────────┼────────────────┼────────┼───────┼────────┼─────────────┼─────────────┼────────┼────────┼────────┼──────────────┼──────────────┼───────┼───────┼───────┼─────────────┼─────────────┼─────────┼────────────┼───────────┼──────────────────┼──────────────────┤
│    0    │ 1.000 │  0.000  │ 2.228e+13 │     1.000     │     1.000     │ -0.194 │  0.187  │ -1.035 │    -0.380     │    -0.008     │ 0.113 │ 0.067  │ 1.683 │    0.046     │    0.180     │ 0.004 │  0.007   │  0.593  │     -0.003     │     0.011      │ -0.023 │ 0.056 │ -0.417 │   -0.079    │    0.032    │ 0.011  │ 0.007  │ 1.474  │    0.004     │    0.018     │ 0.010 │ 0.008 │ 1.345 │    0.003    │    0.018    │  0.069  │   0.192    │   0.359   │      -0.122      │      0.260       │
│    1    │ 0.972 │  0.096  │  10.088   │     0.876     │     1.067     │ 0.170  │  0.166  │ 1.023  │     0.005     │     0.336     │ 0.382 │ 0.126  │ 3.021 │    0.256     │    0.507     │ 0.012 │  0.011   │  1.123  │     0.001      │     0.023      │ -0.028 │ 0.060 │ -0.461 │   -0.088    │    0.032    │ 0.022  │ 0.008  │ 2.727  │    0.014     │    0.030     │ 0.003 │ 0.010 │ 0.273 │   -0.007    │    0.013    │  0.111  │   0.204    │   0.541   │      -0.093      │      0.314       │
│    2    │ 1.000 │  0.083  │  12.089   │     0.918     │     1.082     │ 0.326  │  0.139  │ 2.334  │     0.187     │     0.464     │ 0.561 │ 0.161  │ 3.486 │    0.401     │    0.721     │ 0.013 │  0.017   │  0.771  │     -0.004     │     0.029      │ 0.031  │ 0.053 │ 0.577  │   -0.022    │    0.083    │ -0.003 │ 0.007  │ -0.390 │    -0.009    │    0.004     │ 0.007 │ 0.011 │ 0.645 │   -0.004    │    0.018    │ -0.318  │   0.178    │  -1.784   │      -0.496      │      -0.141      │
│    3    │ 0.720 │  0.145  │   4.981   │     0.577     │     0.864     │ 0.240  │  0.173  │ 1.383  │     0.067     │     0.412     │ 0.667 │ 0.204  │ 3.269 │    0.464     │    0.870     │ 0.015 │  0.018   │  0.809  │     -0.003     │     0.033      │ 0.013  │ 0.059 │ 0.212  │   -0.046    │    0.072    │ -0.005 │ 0.008  │ -0.644 │    -0.012    │    0.003     │ 0.002 │ 0.011 │ 0.180 │   -0.009    │    0.013    │  0.058  │   0.207    │   0.281   │      -0.148      │      0.264       │
│    4    │ 0.635 │  0.173  │   3.675   │     0.463     │     0.807     │ 0.488  │  0.177  │ 2.765  │     0.313     │     0.664     │ 0.676 │ 0.236  │ 2.868 │    0.442     │    0.910     │ 0.012 │  0.018   │  0.654  │     -0.006     │     0.030      │ 0.013  │ 0.062 │ 0.211  │   -0.049    │    0.075    │ -0.021 │ 0.010  │ -2.052 │    -0.031    │    -0.011    │ 0.002 │ 0.009 │ 0.245 │   -0.007    │    0.012    │  0.127  │   0.171    │   0.740   │      -0.044      │      0.297       │
└─────────┴───────┴─────────┴───────────┴───────────────┴───────────────┴────────┴─────────┴────────┴───────────────┴───────────────┴───────┴────────┴───────┴──────────────┴──────────────┴───────┴──────────┴─────────┴────────────────┴────────────────┴────────┴───────┴────────┴─────────────┴─────────────┴────────┴────────┴────────┴──────────────┴──────────────┴───────┴───────┴───────┴─────────────┴─────────────┴─────────┴────────────┴───────────┴──────────────────┴──────────────────┘
             Estimation Summary
┌──────────────────────────────┬────────────┐
│            metric            │   value    │
├──────────────────────────────┼────────────┤
│ Effective observations (h=0) │     75     │
│ Effective observations (min) │     71     │
│     Covariance estimator     │ newey_west │
│           Horizons           │     4      │
│         Control lags         │     2      │
└──────────────────────────────┴────────────┘
```

Newey–West HAC standard errors control for moving-average serial correlation across horizons (`Effective observations (h=0): 75` to `71`, inflation response rising from `-0.193604` at $h=0$ to `0.488156`, SE `0.176556`, at $h=4$) in `lp_coefficients` and `lp_estimation_summary`.

---

## Common Pitfalls

1. **Passing `--ci bootstrap` together with `--id arias|uhlig|narrative-adrr` or `--identified-set`:** Those set-identified Bayesian/importance samplers manage posterior bands internally, so bootstrap flags (`--ci`, `--bootstrap`, `--bias-correct`, `--cumulative`) are ignored there.
2. **Omitting `--instrument` (`proxy`) or `--target-var` (`max-share`):** [`irf var`](@ref ref-irf-var) requires `--instrument` pointing to the external instrument column when `--id proxy` is active, and `--target-var` when `--id max-share` is selected.
3. **Weak instruments in LP-IV (`--method iv`):** Always enable `--mop-f` and `--ar-bands` on [`estimate multivariate lp`](@ref ref-estimate-multivariate-lp) (`montiel_olea_pflueger_effective_f`, `lp_iv_anderson_rubin_bands`) whenever external macro instruments have borderline first-stage power.

---

## References

- Sims, C. A. (1980). Macroeconomics and reality. *Econometrica*, 48(1), 1–48.
- Arias, J. E., Rubio-Ramírez, J. F., & Waggoner, D. F. (2018). Inference based on structural vector autoregressions identified with sign and zero restrictions: Theory and applications. *Econometrica*, 86(2), 685–720.
- Jordà, Ò. (2005). Estimation and inference of impulse responses by local projections. *American Economic Review*, 95(1), 161–182.
- Stock, J. H., & Watson, M. W. (2018). Identification and estimation of dynamic causal effects in macroeconomics using external instruments. *Economic Journal*, 128(610), 917–948.
- Upstream manuals: [MacroEconometricModels.jl — SVAR](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/svar/), [Local Projections](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/lp/)
- CLI reference: [`frdc irf`](@ref ref-irf), [`frdc fevd`](@ref ref-fevd), [`frdc hd`](@ref ref-hd), [`frdc estimate multivariate lp`](@ref ref-estimate-multivariate-lp)
