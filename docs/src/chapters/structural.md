# [Structural ID, LP & Innovation Accounting](@id chap-structural)

Recovering structural economic shocks $\varepsilon_t$ from reduced-form residuals $u_t = B_0 \varepsilon_t$—and quantifying propagation via impulse response functions ([`irf`](@ref ref-irf)), forecast error variance decompositions ([`fevd`](@ref ref-fevd)), and historical decompositions ([`hd`](@ref ref-hd))—connects reduced-form VARs/BVARs/VECMs/FAVARs/SDFMs/TVP-VARs, parametric SVAR/SVEC (`estimate multivariate svar|svec`), non-Gaussian ICA/ML (`estimate factor fastica`, `estimate regression ml`), and direct local projections (`estimate multivariate lp`). See [MacroEconometricModels.jl — Structural Identification](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/svar/) and [Local Projections](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/lp/).

## Quick Start

Estimate Cholesky-identified impulse responses with Kilian bias-corrected or iid bootstrap bands on `:denmark`, and decompose forecast error variance over 4 horizons:

<!-- capture -->
```bash
friedman --seed 42 irf var :denmark --lags 2 --shock 1 --horizons 4 --id cholesky --ci bootstrap --replications 100
```
```text
                IRF to LRM shock (cholesky identification)
┌─────────┬──────────┬───────┬──────────────┬──────────────┬──────────────┐
│ horizon │ variable │ shock │    value     │    lower     │    upper     │
├─────────┼──────────┼───────┼──────────────┼──────────────┼──────────────┤
│    1    │   LRM    │  LRM  │  0.0211523   │  0.0145576   │  0.0244901   │
│    1    │   LRY    │  LRM  │  0.00867905  │ -0.000593786 │  0.0149644   │
│    1    │   LPY    │  LRM  │ -0.00301527  │ -0.00437929  │ -0.000293079 │
│    1    │   IBO    │  LRM  │ -0.00275231  │ -0.00381717  │ -0.00103838  │
│    1    │   IDE    │  LRM  │ -0.000271827 │ -0.00125767  │  0.00114693  │
│    2    │   LRM    │  LRM  │  0.0125777   │  0.00295332  │  0.0191809   │
│    2    │   LRY    │  LRM  │  0.0111191   │ 0.000876417  │  0.0170556   │
│    2    │   LPY    │  LRM  │ -0.00343509  │ -0.00422956  │ -0.00017111  │
│    2    │   IBO    │  LRM  │ -0.00214358  │ -0.00466626  │  0.00138564  │
│    2    │   IDE    │  LRM  │ -0.000878119 │  -0.001752   │  0.00188218  │
│    3    │   LRM    │  LRM  │  0.0143858   │  0.00506242  │  0.0208122   │
│    3    │   LRY    │  LRM  │  0.0067444   │ -0.00195175  │  0.0126523   │
│    3    │   LPY    │  LRM  │  -0.0032946  │ -0.00437779  │ -0.000199654 │
│    3    │   IBO    │  LRM  │ -0.00134605  │ -0.00411059  │  0.0029667   │
│    3    │   IDE    │  LRM  │ -0.00103512  │ -0.00229263  │  0.00151425  │
│    4    │   LRM    │  LRM  │  0.0102766   │ -0.000986411 │  0.0178746   │
│    4    │   LRY    │  LRM  │  0.00552347  │ -0.000688686 │  0.0106339   │
│    4    │   LPY    │  LRM  │ -0.00329447  │ -0.00459664  │ -0.000224224 │
│    4    │   IBO    │  LRM  │ -0.00141897  │ -0.00423117  │  0.00358894  │
│    4    │   IDE    │  LRM  │ -0.000667991 │ -0.00198736  │  0.0018703   │
└─────────┴──────────┴───────┴──────────────┴──────────────┴──────────────┘
```

The command outputs tidy bands under the JSON table key `irf` (`LRM` responds on impact by `0.0211523` with 95% CI `[0.0145576, 0.0244901]` while `IBO` dips by `-0.00275231`); pair with `--save-model` / `--model` from [`estimate multivariate var`](@ref ref-estimate-multivariate-var) ([Pipelines, Handles & Reproducibility](@ref gs-pipelines)) to lock reduced-form estimates across `irf`, `fevd`, and `hd`.

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
friedman fevd var :denmark --lags 2 --horizons 4 --id cholesky --normalize
```
```text
       FEVD (cholesky identification)
┌─────────┬──────────┬───────┬─────────────┐
│ horizon │ variable │ shock │    value    │
├─────────┼──────────┼───────┼─────────────┤
│    1    │   LRM    │  LRM  │     1.0     │
│    1    │   LRM    │  LRY  │     0.0     │
│    1    │   LRM    │  LPY  │     0.0     │
│    1    │   LRM    │  IBO  │     0.0     │
│    1    │   LRM    │  IDE  │     0.0     │
│    1    │   LRY    │  LRM  │  0.203699   │
│    1    │   LRY    │  LRY  │  0.796301   │
│    1    │   LRY    │  LPY  │     0.0     │
│    1    │   LRY    │  IBO  │     0.0     │
│    1    │   LRY    │  IDE  │     0.0     │
│    1    │   LPY    │  LRM  │  0.194962   │
│    1    │   LPY    │  LRY  │  0.131405   │
│    1    │   LPY    │  LPY  │  0.673633   │
│    1    │   LPY    │  IBO  │     0.0     │
│    1    │   LPY    │  IDE  │     0.0     │
│    1    │   IBO    │  LRM  │   0.12045   │
│    1    │   IBO    │  LRY  │  0.0486733  │
│    1    │   IBO    │  LPY  │  0.0323073  │
│    1    │   IBO    │  IBO  │  0.798569   │
│    1    │   IBO    │  IDE  │     0.0     │
│    1    │   IDE    │  LRM  │ 0.00314658  │
│    1    │   IDE    │  LRY  │  0.018846   │
│    1    │   IDE    │  LPY  │  0.140533   │
│    1    │   IDE    │  IBO  │  0.0304142  │
│    1    │   IDE    │  IDE  │   0.80706   │
│    2    │   LRM    │  LRM  │   0.79194   │
│    2    │   LRM    │  LRY  │ 6.96963e-5  │
│    2    │   LRM    │  LPY  │  0.144305   │
│    2    │   LRM    │  IBO  │  0.0635943  │
│    2    │   LRM    │  IDE  │ 9.07817e-5  │
│    2    │   LRY    │  LRM  │  0.280651   │
│    2    │   LRY    │  LRY  │  0.646804   │
│    2    │   LRY    │  LPY  │  0.0512843  │
│    2    │   LRY    │  IBO  │ 0.00304924  │
│    2    │   LRY    │  IDE  │  0.0182119  │
│    2    │   LPY    │  LRM  │  0.215232   │
│    2    │   LPY    │  LRY  │  0.0774844  │
│    2    │   LPY    │  LPY  │  0.679291   │
│    2    │   LPY    │  IBO  │  0.0277796  │
│    2    │   LPY    │  IDE  │ 0.000212661 │
│    2    │   IBO    │  LRM  │  0.0671584  │
│    2    │   IBO    │  LRY  │  0.149218   │
│    2    │   IBO    │  LPY  │  0.050199   │
│    2    │   IBO    │  IBO  │  0.733324   │
│    2    │   IBO    │  IDE  │ 0.000100637 │
│    2    │   IDE    │  LRM  │  0.0149267  │
│    2    │   IDE    │  LRY  │ 0.00817326  │
│    2    │   IDE    │  LPY  │  0.212248   │
│    2    │   IDE    │  IBO  │   0.18644   │
│    2    │   IDE    │  IDE  │  0.578212   │
│    3    │   LRM    │  LRM  │  0.606629   │
│    3    │   LRM    │  LRY  │  0.062959   │
│    3    │   LRM    │  LPY  │  0.108708   │
│    3    │   LRM    │  IBO  │  0.221365   │
│    3    │   LRM    │  IDE  │ 0.000338146 │
│    3    │   LRY    │  LRM  │  0.268286   │
│    3    │   LRY    │  LRY  │  0.564544   │
│    3    │   LRY    │  LPY  │  0.101708   │
│    3    │   LRY    │  IBO  │ 0.00310928  │
│    3    │   LRY    │  IDE  │  0.0623533  │
│    3    │   LPY    │  LRM  │   0.2089    │
│    3    │   LPY    │  LRY  │  0.0495755  │
│    3    │   LPY    │  LPY  │  0.672969   │
│    3    │   LPY    │  IBO  │  0.0681731  │
│    3    │   LPY    │  IDE  │ 0.000382857 │
│    3    │   IBO    │  LRM  │  0.0442841  │
│    3    │   IBO    │  LRY  │   0.18683   │
│    3    │   IBO    │  LPY  │  0.038079   │
│    3    │   IBO    │  IBO  │  0.728356   │
│    3    │   IBO    │  IDE  │ 0.00245121  │
│    3    │   IDE    │  LRM  │  0.021658   │
│    3    │   IDE    │  LRY  │  0.045163   │
│    3    │   IDE    │  LPY  │  0.199195   │
│    3    │   IDE    │  IBO  │  0.312829   │
│    3    │   IDE    │  IDE  │  0.421155   │
│    4    │   LRM    │  LRM  │  0.425503   │
│    4    │   LRM    │  LRY  │  0.115163   │
│    4    │   LRM    │  LPY  │  0.098792   │
│    4    │   LRM    │  IBO  │  0.360227   │
│    4    │   LRM    │  IDE  │ 0.000314881 │
│    4    │   LRY    │  LRM  │  0.261693   │
│    4    │   LRY    │  LRY  │  0.493207   │
│    4    │   LRY    │  LPY  │  0.126325   │
│    4    │   LRY    │  IBO  │  0.0168237  │
│    4    │   LRY    │  IDE  │  0.101951   │
│    4    │   LPY    │  LRM  │  0.199524   │
│    4    │   LPY    │  LRY  │  0.039507   │
│    4    │   LPY    │  LPY  │  0.641232   │
│    4    │   LPY    │  IBO  │  0.118366   │
│    4    │   LPY    │  IDE  │ 0.00137069  │
│    4    │   IBO    │  LRM  │  0.0365118  │
│    4    │   IBO    │  LRY  │  0.196039   │
│    4    │   IBO    │  LPY  │  0.0296192  │
│    4    │   IBO    │  IBO  │   0.72932   │
│    4    │   IBO    │  IDE  │  0.0085098  │
│    4    │   IDE    │  LRM  │  0.0205193  │
│    4    │   IDE    │  LRY  │  0.0861123  │
│    4    │   IDE    │  LPY  │  0.173052   │
│    4    │   IDE    │  IBO  │  0.392924   │
│    4    │   IDE    │  IDE  │  0.327393   │
└─────────┴──────────┴───────┴─────────────┘
```

With `--normalize`, variance shares across structural shocks sum to `1.0` at every horizon (`fevd`, or `generalized_fevd` with `--generalized`): at horizon `1`, the `LRM` shock explains `1.0` of `LRM` and `0.203699` of `LRY` (`0.796301` own shock). Notice `--cumulative` integrates impulse responses over horizons when series enter in first differences.

---

## Non-Gaussian ICA & Heteroskedastic SVARs

When structural innovations are mutually independent and at most one shock is Gaussian (or conditional volatility varies across regimes or stochastic volatility states), $B_0$ is point-identified up to column permutation and sign without zero/sign timing assumptions:

- **Non-Gaussian Independence:** Run [`estimate factor fastica`](@ref ref-estimate-factor-fastica) (`--method fastica|jade|sobi|dcov|hsic`, `--contrast logcosh|exp|kurtosis`) or parametric skewed/heavy-tailed MLE [`estimate regression ml`](@ref ref-estimate-regression-ml) (`--distribution student_t|mixture_normal|pml|skew_normal`), or pass `--id fastica|jade|sobi|dcov|hsic|student_t|mixture_normal|pml|skew_normal` directly to `irf`/`fevd`/`hd`.
- **Heteroskedasticity Identification:** Pass `--id markov_switching`, `--id garch_id`, `--id lewis-tvv` (Lewis 2021 GMM via time-varying volatility), or `--id sv-em` (Bertsche–Braun stochastic volatility EM; config schema in [Priors, SVAR & VECM Identification](@ref cfg-identification)).

<!-- capture -->
```bash
friedman --quiet data simulate svar --dist t --nu 5.0 --periods 160 --burn 50 --seed 9 --save-data svar_sim
friedman estimate factor fastica svar_sim --lags 1 --method fastica --contrast logcosh
```
```text
         Structural Impact Matrix (B0)
┌──────────┬───────────┬──────────┬────────────┐
│ equation │    y1     │    y2    │     y3     │
├──────────┼───────────┼──────────┼────────────┤
│    y1    │ 0.120698  │  1.0694  │ 0.0841927  │
│    y2    │ -0.963088 │ 0.492227 │ -0.0146661 │
│    y3    │ -0.226159 │ 0.169375 │  1.02858   │
└──────────┴───────────┴──────────┴────────────┘
Structural Shocks (first 10 observations)
┌────┬───────────┬───────────┬───────────┐
│ t  │  shock_1  │  shock_2  │  shock_3  │
├────┼───────────┼───────────┼───────────┤
│ 1  │ -0.223541 │ -0.301329 │ 0.782962  │
│ 2  │ 0.529053  │ -0.399401 │ 0.880971  │
│ 3  │  1.70121  │ -0.918688 │  -1.5804  │
│ 4  │ 0.0276503 │ -0.829793 │ -0.109084 │
│ 5  │  1.51386  │ 0.635114  │ 0.960682  │
│ 6  │ -0.242673 │ 0.442985  │ 0.928126  │
│ 7  │ -0.58509  │ -1.31144  │ -0.692542 │
│ 8  │ -0.810562 │ -0.85783  │ -0.98159  │
│ 9  │ 0.0939118 │ 0.137918  │ -1.18268  │
│ 10 │ 0.351211  │ -2.72084  │ 0.869372  │
└────┴───────────┴───────────┴───────────┘
```

The FastICA estimator reports the identified impact matrix `structural_impact_matrix_b0` (e.g., `(y1, y1) = 0.120698`, `(y1, y2) = 1.0694`, `(y3, y3) = 1.02858`) and extracted independent shock series `structural_shocks` directly without Cholesky ordering assumptions.

---

## Local Projections (`estimate multivariate lp`, `irf/fevd/hd lp`)

Jordà (2005) local projections estimate dynamic causal responses horizon-by-horizon via direct regressions of $y_{t+h}$ on the shock/instrument and control lags, avoiding VAR lag misspecification:

```math
y_{t+h} = \alpha_h + \beta_h \, s_t + \gamma_h' W_{t-1} + u_{t+h}, \qquad h = 0, \dots, H.
```

[`estimate multivariate lp`](@ref ref-estimate-multivariate-lp) supports six variants via `--method`: `standard`, `iv` (external instrument LP-IV with `--instruments`, Montiel Olea–Pflueger effective F `--mop-f`, and weak-IV Anderson–Rubin bands `--ar-bands`), penalized `smooth` B-splines (`--knots`, `--lambda`), Auerbach–Gorodnichenko `state`-dependent logistic transitions (`--state-var`, `--gamma`), inverse-probability `propensity` weighting, and doubly `robust` AIPW estimators. Follow up directly with [`irf lp`](@ref ref-irf-lp), [`fevd lp`](@ref ref-fevd-lp), [`hd lp`](@ref ref-hd-lp), or [`forecast multivariate lp`](@ref ref-forecast-multivariate-lp).

<!-- capture -->
```bash
friedman --quiet data dropna :mp_shocks -f csv -o mp_clean.csv
friedman estimate multivariate lp mp_clean.csv --method standard --shock 1 --horizons 4 --control-lags 2 --vcov newey_west
```
```text
                                                                                                                      LP Coefficients (ygap → responses)
┌─────────┬──────────┬──────────┬────────────┬───────────┬──────────┬────────┬──────────┬──────────┬───────┬──────────┬──────────┬─────────┬───────────┬──────────┬────────┬───────────┬──────────┬────────┬──────────┬──────────┬───────┬───────────┬────────────┬───────────┐
│ Horizon │   ygap   │ ygap_se  │   ygap_t   │   infl    │ infl_se  │ infl_t │   ffr    │  ffr_se  │ ffr_t │  lpcom   │ lpcom_se │ lpcom_t │    rr     │  rr_se   │  rr_t  │    mp1    │  mp1_se  │ mp1_t  │    ad    │  ad_se   │ ad_t  │  bzk_ist  │ bzk_ist_se │ bzk_ist_t │
├─────────┼──────────┼──────────┼────────────┼───────────┼──────────┼────────┼──────────┼──────────┼───────┼──────────┼──────────┼─────────┼───────────┼──────────┼────────┼───────────┼──────────┼────────┼──────────┼──────────┼───────┼───────────┼────────────┼───────────┤
│    0    │   1.0    │   0.0    │ 2.22846e13 │ -0.193604 │ 0.186981 │ -1.035 │ 0.113355 │ 0.067352 │ 1.683 │ 0.003989 │ 0.006728 │  0.593  │ -0.02334  │ 0.056006 │ -0.417 │ 0.010802  │ 0.007328 │ 1.474  │ 0.010218 │ 0.007596 │ 1.345 │ 0.069111  │  0.192394  │   0.359   │
│    1    │ 0.971576 │ 0.096313 │   10.088   │ 0.170243  │ 0.166419 │ 1.023  │ 0.381794 │ 0.126377 │ 3.021 │ 0.01219  │ 0.010853 │  1.123  │ -0.027813 │ 0.06034  │ -0.461 │ 0.021732  │ 0.00797  │ 2.727  │  0.0027  │ 0.009884 │ 0.273 │  0.11055  │  0.204328  │   0.541   │
│    2    │ 1.00017  │ 0.082733 │   12.089   │ 0.325519  │ 0.139456 │ 2.334  │ 0.561284 │ 0.161007 │ 3.486 │ 0.012835 │ 0.016653 │  0.771  │ 0.030553  │ 0.052967 │ 0.577  │ -0.002596 │ 0.006659 │ -0.39  │ 0.006961 │ 0.010785 │ 0.645 │ -0.318137 │  0.178372  │  -1.784   │
│    3    │ 0.720463 │ 0.144656 │   4.981    │ 0.239605  │ 0.173289 │ 1.383  │ 0.666724 │ 0.203977 │ 3.269 │ 0.014775 │ 0.018265 │  0.809  │  0.01256  │ 0.059355 │ 0.212  │ -0.004865 │ 0.00755  │ -0.644 │ 0.001958 │ 0.010854 │ 0.18  │  0.05818  │  0.207032  │   0.281   │
│    4    │ 0.635344 │ 0.172899 │   3.675    │ 0.488156  │ 0.176556 │ 2.765  │ 0.676003 │ 0.235692 │ 2.868 │ 0.011853 │ 0.018127 │  0.654  │ 0.013197  │ 0.062496 │ 0.211  │ -0.020772 │ 0.010123 │ -2.052 │ 0.002314 │ 0.00944  │ 0.245 │ 0.126854  │  0.171382  │   0.74    │
└─────────┴──────────┴──────────┴────────────┴───────────┴──────────┴────────┴──────────┴──────────┴───────┴──────────┴──────────┴─────────┴───────────┴──────────┴────────┴───────────┴──────────┴────────┴──────────┴──────────┴───────┴───────────┴────────────┴───────────┘
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
- CLI reference: [`friedman irf`](@ref ref-irf), [`friedman fevd`](@ref ref-fevd), [`friedman hd`](@ref ref-hd), [`friedman estimate multivariate lp`](@ref ref-estimate-multivariate-lp)
