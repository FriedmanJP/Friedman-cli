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
┌─────────┬──────────┬────────┬──────────────┬──────────────┬──────────────┐
│ horizon │ variable │ shock  │    value     │    lower     │    upper     │
│  Int64  │  String  │ String │   Float64    │   Float64?   │   Float64?   │
├─────────┼──────────┼────────┼──────────────┼──────────────┼──────────────┤
│    1    │   LRM    │  LRM   │  0.0211523   │  0.0145576   │  0.0244901   │
│    1    │   LRY    │  LRM   │  0.00867905  │ -0.000593786 │  0.0149644   │
│    1    │   LPY    │  LRM   │ -0.00301527  │ -0.00437929  │ -0.000293079 │
│    1    │   IBO    │  LRM   │ -0.00275231  │ -0.00381717  │ -0.00103838  │
│    1    │   IDE    │  LRM   │ -0.000271827 │ -0.00125767  │  0.00114693  │
│    2    │   LRM    │  LRM   │  0.0125777   │  0.00295332  │  0.0191809   │
│    2    │   LRY    │  LRM   │  0.0111191   │ 0.000876417  │  0.0170556   │
│    2    │   LPY    │  LRM   │ -0.00343509  │ -0.00422956  │ -0.00017111  │
│    2    │   IBO    │  LRM   │ -0.00214358  │ -0.00466626  │  0.00138564  │
│    2    │   IDE    │  LRM   │ -0.000878119 │  -0.001752   │  0.00188218  │
│    3    │   LRM    │  LRM   │  0.0143858   │  0.00506242  │  0.0208122   │
│    3    │   LRY    │  LRM   │  0.0067444   │ -0.00195175  │  0.0126523   │
│    3    │   LPY    │  LRM   │  -0.0032946  │ -0.00437779  │ -0.000199654 │
│    3    │   IBO    │  LRM   │ -0.00134605  │ -0.00411059  │  0.0029667   │
│    ⋮    │    ⋮     │   ⋮    │      ⋮       │      ⋮       │      ⋮       │
└─────────┴──────────┴────────┴──────────────┴──────────────┴──────────────┘
                                                              6 rows omitted
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
┌─────────┬──────────┬────────┬──────────┐
│ horizon │ variable │ shock  │  value   │
│  Int64  │  String  │ String │ Float64  │
├─────────┼──────────┼────────┼──────────┤
│    1    │   LRM    │  LRM   │   1.0    │
│    1    │   LRM    │  LRY   │   0.0    │
│    1    │   LRM    │  LPY   │   0.0    │
│    1    │   LRM    │  IBO   │   0.0    │
│    1    │   LRM    │  IDE   │   0.0    │
│    1    │   LRY    │  LRM   │ 0.203699 │
│    1    │   LRY    │  LRY   │ 0.796301 │
│    1    │   LRY    │  LPY   │   0.0    │
│    1    │   LRY    │  IBO   │   0.0    │
│    1    │   LRY    │  IDE   │   0.0    │
│    1    │   LPY    │  LRM   │ 0.194962 │
│    1    │   LPY    │  LRY   │ 0.131405 │
│    1    │   LPY    │  LPY   │ 0.673633 │
│    1    │   LPY    │  IBO   │   0.0    │
│    ⋮    │    ⋮     │   ⋮    │    ⋮     │
└─────────┴──────────┴────────┴──────────┘
                           86 rows omitted
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
┌──────────┬───────────┬──────────┬───────────┐
│ equation │    y1     │    y2    │    y3     │
│  String  │  Float64  │ Float64  │  Float64  │
├──────────┼───────────┼──────────┼───────────┤
│    y1    │ 0.118324  │ 1.06505  │ -0.130196 │
│    y2    │ -0.063854 │ 0.50754  │ 0.953083  │
│    y3    │ -1.00853  │ 0.343845 │ 0.049505  │
└──────────┴───────────┴──────────┴───────────┘
   Structural Shocks (first 10 observations)
┌───────┬────────────┬────────────┬────────────┐
│   t   │  shock_1   │  shock_2   │  shock_3   │
│ Int64 │  Float64   │  Float64   │  Float64   │
├───────┼────────────┼────────────┼────────────┤
│   1   │ -0.848685  │ -0.161063  │ 0.0871259  │
│   2   │ -0.834646  │ -0.260794  │ -0.671477  │
│   3   │   1.665    │  -1.21219  │  -1.41215  │
│   4   │ -0.0290357 │ -0.836811  │ -0.0111377 │
│   5   │ -0.573449  │  0.746891  │  -1.65268  │
│   6   │ -0.867661  │  0.597269  │ 0.0835293  │
│   7   │  0.354348  │  -1.39286  │  0.690061  │
│   8   │  0.673803  │ -0.987998  │  0.962419  │
│   9   │  1.18784   │ -0.0631614 │  0.107748  │
│  10   │  -1.24372  │  -2.54648  │ -0.500738  │
└───────┴────────────┴────────────┴────────────┘
```

The FastICA estimator reports the identified impact matrix `structural_impact_matrix_b0` (e.g., `(y3, y1) = -1.00853`, `(y1, y2) = 1.06505`, `(y2, y3) = 0.953083`) and extracted independent shock series `structural_shocks` directly without Cholesky ordering assumptions.

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
┌─────────┬──────────┬──────────┬────────────┬───────────┬──────────┬───────────
│ Horizon │   ygap   │ ygap_se  │   ygap_t   │   infl    │ infl_se  │ infl_t   ⋯
│  Int64  │ Float64  │ Float64  │  Float64   │  Float64  │ Float64  │ Float64  ⋯
├─────────┼──────────┼──────────┼────────────┼───────────┼──────────┼───────────
│    0    │   1.0    │   0.0    │ 2.22846e13 │ -0.193604 │ 0.186981 │ -1.035   ⋯
│    1    │ 0.971576 │ 0.096313 │   10.088   │ 0.170243  │ 0.166419 │  1.023   ⋯
│    2    │ 1.00017  │ 0.082733 │   12.089   │ 0.325519  │ 0.139456 │  2.334   ⋯
│    3    │ 0.720463 │ 0.144656 │   4.981    │ 0.239605  │ 0.173289 │  1.383   ⋯
│    4    │ 0.635344 │ 0.172899 │   3.675    │ 0.488156  │ 0.176556 │  2.765   ⋯
└─────────┴──────────┴──────────┴────────────┴───────────┴──────────┴───────────
                                                              18 columns omitted
             Estimation Summary
┌──────────────────────────────┬────────────┐
│            metric            │   value    │
│            String            │    Any     │
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
