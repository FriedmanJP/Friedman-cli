# [Panel Data, Panel VAR & Causal DiD](@id chap-panel)

Longitudinal micro- and macro-panel estimators ([`estimate panel`](@ref ref-fam-estimate-panel)), panel vector autoregressions ([`estimate panel pvar`](@ref ref-estimate-panel-pvar), [`irf pvar`](@ref ref-irf-pvar), [`fevd pvar`](@ref ref-fevd-pvar)), staggered difference-in-differences and local-projection DiD ([`did`](@ref ref-did)), and panel/DiD specification diagnostics ([`test panel`](@ref ref-fam-test-panel), [`test pvar`](@ref ref-fam-test-pvar), [`test did`](@ref ref-fam-test-did)) handle correlated unit effects, dynamic GMM instruments, and heterogeneous treatment timing. See [MacroEconometricModels.jl — Panel & DiD](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/panel/).

## Quick Start

Estimate a panel regression on Grunfeld's firm investment dataset (`:grunfeld`) using fixed effects (`--method fe`) with clustered standard errors, or estimate group-time ATTs under staggered adoption:

<!-- capture -->
```bash
friedman --quiet data simulate panel --kind linear --n 20 --periods 10 --seed 1 --save-data pan_sim
friedman estimate panel preg pan_sim --dep y --indep x1,x2 --id-col id --time-col time --method fe --cov-type cluster
```
```text
                      Panel Regression Coefficients (fe)
┌────────┬──────────┬───────────┬─────────┬────────────┬──────────┬──────────┐
│  term  │ estimate │ std_error │  stat   │  p_value   │ ci_lower │ ci_upper │
│ String │ Float64  │  Float64  │ Float64 │  Float64   │ Float64  │ Float64  │
├────────┼──────────┼───────────┼─────────┼────────────┼──────────┼──────────┤
│   x1   │ 0.978915 │ 0.0871942 │ 11.2268 │    0.0     │ 0.806847 │ 1.15098  │
│   x2   │ 0.509885 │ 0.102251  │ 4.98659 │ 1.45153e-6 │ 0.308105 │ 0.711666 │
└────────┴──────────┴───────────┴─────────┴────────────┴──────────┴──────────┘
     Model Statistics
┌──────────────┬──────────┐
│    metric    │  value   │
│    String    │   Real   │
├──────────────┼──────────┤
│ R2 (within)  │ 0.518109 │
│ R2 (between) │ 0.027024 │
│ R2 (overall) │ 0.349904 │
│ F-statistic  │ 65.0384  │
│  F p-value   │   0.0    │
│    N obs     │   200    │
│   N groups   │    20    │
└──────────────┴──────────┘
```

The command returns `panel_regression_coefficients` (`x1 = 0.978915`, `x2 = 0.509885`) and `model_statistics` (`R2 (within) = 0.518109`, `F = 65.0384` across `20` groups); pass `--save-model` to reuse the panel fit in [`predict panel preg`](@ref ref-predict-panel-preg) and [`residuals panel preg`](@ref ref-residuals-panel-preg), or switch `--cov-type` to `twoway`, `driscoll-kraay`, or `pcse`.

---

## Static, Dynamic & Cointegrated Panel Models (`estimate panel`)

A two-way panel model separates time-invariant unit heterogeneity $\alpha_i$, common time shocks $\gamma_t$, and time-varying covariates $x_{it}$:

```math
y_{it} = \alpha_i + \gamma_t + x_{it}'\beta + \varepsilon_{it},
```

requiring sequential moment conditions (Arellano–Bond / Blundell–Bond GMM) when lagged dependent variables enter, or common correlated / interactive fixed effects under cross-sectional dependence.

| Panel Leaf | Estimators & Methods | Paired Post-Estimation & Tests |
|---|---|---|
| [`preg`](@ref ref-estimate-panel-preg) | Within FE, RE, FD, HDFE (`--absorb`), `--twoway`, `--ar1`, Arellano–Bond dynamic GMM (`--collapse`) | [`predict`/`residuals panel preg`](@ref ref-predict-panel-preg); [`test panel f-fe \| hausman \| modified-wald \| pesaran-cd \| wooldridge-ar`](@ref ref-fam-test-panel) |
| [`piv`](@ref ref-estimate-panel-piv) | Panel FE-IV, RE-IV, EC2SLS, FD-IV, Hausman–Taylor (`--exog`, `--endog`, `--instruments`) | `panel_iv_coefficients`, `weak_instrument_diagnostics` |
| [`plogit`](@ref ref-estimate-panel-plogit), [`pprobit`](@ref ref-estimate-panel-pprobit) | Pooled, random-effects, and Mundlak–Chamberlain CRE (`--method pooled\|re\|cre`) | [`predict`/`residuals panel plogit \| pprobit`](@ref ref-fam-predict-panel) |
| [`pmg`](@ref ref-estimate-panel-pmg) | Pesaran–Shin–Smith Mean Group (`mg`), Pooled Mean Group (`pmg`), Dynamic FE (`dfe`) | [`test panel pmg-hausman`](@ref ref-test-panel-pmg-hausman) |
| [`xtcointreg`](@ref ref-estimate-panel-xtcointreg) | Panel FMOLS / DOLS (`--pooling group\|pooled`) | [`test coint kao \| pedroni \| westerlund \| fisher-johansen`](@ref ref-fam-test-coint) |

---

## Panel Vector Autoregressions (`pvar`)

Abrigo–Love GMM Panel VAR estimates a $K$-variable dynamic panel system after forward orthogonal deviations or first differencing (`--transformation fd|fod`), eliminating fixed effects without Nickell bias (`--system` adds level moment conditions; `--collapse` caps instrument proliferation):

<!-- capture -->
```bash
friedman --quiet data simulate pvar --n 15 --periods 12 --seed 42 --save-data pvar_sim
friedman estimate panel pvar pvar_sim --id-col id --time-col time --lags 1 --dependent y1,y2 --steps twostep
```
```text
                        Panel VAR(1) Coefficients (gmm)
┌───────────┬───────────┬──────────┬─────────┬───────────┬──────────┬─────────┐
│ parameter │  y1_coef  │  y1_se   │ y1_pval │  y2_coef  │  y2_se   │ y2_pval │
│  String   │  Float64  │ Float64  │ Float64 │  Float64  │ Float64  │ Float64 │
├───────────┼───────────┼──────────┼─────────┼───────────┼──────────┼─────────┤
│   y1_L1   │ -0.001107 │ 0.577666 │ 0.9985  │ 0.123591  │ 1.07025  │ 0.9081  │
│   y2_L1   │  0.27905  │ 0.569436 │ 0.6241  │ -0.067277 │ 0.470728 │ 0.8864  │
└───────────┴───────────┴──────────┴─────────┴───────────┴──────────┴─────────┘
         Panel Summary
┌────────────────────┬────────┐
│       metric       │ value  │
│       String       │  Any   │
├────────────────────┼────────┤
│       Groups       │   15   │
│ Total observations │  180   │
│    Instruments     │  110   │
│       Method       │ fd_gmm │
│   Transformation   │   fd   │
└────────────────────┴────────┘
```

Two-step FD-GMM emits coefficient and `panel_summary` tables (`15` groups, `180` observations, `110` instruments). Validate instrument validity with [`test pvar hansen-j`](@ref ref-test-pvar-hansen-j), Andrews–Lu MMSC lag selection via [`test pvar mmsc`](@ref ref-test-pvar-mmsc) / [`lagselect`](@ref ref-test-pvar-lagselect), and companion stability via [`test pvar stability`](@ref ref-test-pvar-stability), then compute orthogonalized/generalized responses via [`irf pvar`](@ref ref-irf-pvar) and [`fevd pvar`](@ref ref-fevd-pvar).

---

## Difference-in-Differences & Event Studies (`did`)

Under staggered treatment timing across cohorts $g$, conventional two-way fixed effects (`twfe`) averages negative comparison weights whenever treatment effects are dynamic. [`did estimate`](@ref ref-did-estimate) provides five estimators (`--method twfe|cs|sa|bjs|dcdh` covering Callaway–Sant'Anna, Sun–Abraham, Borusyak–Jaravel–Spiess imputation, and de Chaisemartin–D'Haultfœuille), supplemented by direct local-projection event studies ([`did event-study`](@ref ref-did-event-study)) and clean-control LP-DiD ([`did lp-did`](@ref ref-did-lp-did)):

```math
\widehat{\mathrm{ATT}}(g, t) = \mathbb{E}[Y_{it} - Y_{i,g-1} \mid G_i = g] - \mathbb{E}[Y_{it} - Y_{i,g-1} \mid C_{it} = 1],
```

where $C_{it}$ selects `never_treated` or `not_yet_treated` comparison units (`--control-group`).

<!-- capture -->
```bash
friedman --quiet data simulate did --n 60 --periods 12 --seed 17 --save-data did_sim
friedman did estimate did_sim --outcome y --treatment cohort --id-col id --time-col time --method cs --control-group never_treated
```
```text
                              DID Estimation — CS
┌────────────┬────────┬──────────┬───────────┬─────────┬─────────────┬──────────
│ event_time │  term  │ estimate │ std_error │  stat   │   p_value   │  ci_low ⋯
│   Int64    │ String │ Float64  │  Float64  │ Float64 │   Float64   │   Float ⋯
├────────────┼────────┼──────────┼───────────┼─────────┼─────────────┼──────────
│     0      │  e=0   │ 0.763798 │ 0.350845  │ 2.17703 │  0.0294786  │  0.0761 ⋯
│     1      │  e=1   │ 0.957665 │ 0.345358  │ 2.77297 │ 0.00555477  │  0.2807 ⋯
│     2      │  e=2   │ 1.16403  │ 0.391289  │ 2.97487 │ 0.00293115  │  0.3971 ⋯
│     3      │  e=3   │ 0.893037 │ 0.455184  │ 1.96192 │  0.0497712  │ 0.00089 ⋯
│     4      │  e=4   │ 1.23652  │  0.36613  │ 3.37728 │ 0.000732074 │   0.518 ⋯
│     5      │  e=5   │ 1.02538  │ 0.399674  │ 2.56553 │  0.0103019  │  0.2420 ⋯
└────────────┴────────┴──────────┴───────────┴─────────┴─────────────┴──────────
                                                               2 columns omitted
                      Group-Time ATT (Callaway-Sant'Anna)
┌────────┬──────────┬───────────┬───────────┬───────────┬──────────┬────────────
│ Cohort │ period_1 │ period_2  │ period_3  │ period_4  │ period_5 │ period_6  ⋯
│ Int64  │ Float64  │  Float64  │  Float64  │  Float64  │ Float64  │ Float64   ⋯
├────────┼──────────┼───────────┼───────────┼───────────┼──────────┼────────────
│   6    │   NaN    │ -0.569572 │ -0.166391 │ 0.0853322 │ 0.313836 │ 0.636727  ⋯
│   11   │   NaN    │ 0.602757  │ -0.372398 │ -0.673512 │ 0.326186 │ 0.24115   ⋯
└────────┴──────────┴───────────┴───────────┴───────────┴──────────┴────────────
                                                               6 columns omitted
```

The command populates `did_estimation` (positive ATT rising from `0.763798` at `e=0` to `1.23652` at `e=4`) and cohort-period cells in `group_time_att_callaway_sant_anna` (`Cohorts` `6` and `11`). Diagnose negative TWFE weights via [`test did negweight`](@ref ref-test-did-negweight), Goodman–Bacon 2×2 variance decomposition via [`test did bacon`](@ref ref-test-did-bacon), joint pre-trends via [`test did pretrend`](@ref ref-test-did-pretrend), and Rambachan–Roth bounded sensitivity via [`test did honest`](@ref ref-test-did-honest).

---

## Common Pitfalls

1. **Omitting `--id-col` and `--time-col` on CSV/panel inputs:** When columns are not already named/registered during `data import --kind panel`, always pass explicit `--id-col` and `--time-col` on every `panel`, `pvar`, and `did` command.
2. **Overfitting GMM instruments in `pvar` and dynamic `preg`:** Long $T$ panels generate quadratically many internal lag instruments, weakening Hansen $J$ overidentification power; pass `--collapse` and `--max-lag-endo` cleanly.
3. **Passing binary indicator `D` instead of adoption-cohort column `cohort` to `did estimate --method cs`:** Callaway–Sant'Anna (`cs`) and Sun–Abraham (`sa`) expect `--treatment` to identify each unit's *first treatment period* (`0` for never-treated units, `g > 0` for adopters; passing the binary post-treatment indicator `D` treats `1` as universal period-1 adoption and produces `NaN` cells). Inspect cohorts cleanly in `group_time_att_callaway_sant_anna`.

---

## References

- Arellano, M., & Bond, S. (1991). Some tests of specification for panel data. *Review of Economic Studies*, 58(2), 277–297.
- Abrigo, M. R., & Love, I. (2016). Estimation of panel vector autoregression in Stata. *Stata Journal*, 16(3), 778–804.
- Callaway, B., & Sant'Anna, P. H. (2021). Difference-in-differences with multiple time periods. *Journal of Econometrics*, 225(2), 200–230.
- Dube, A., Girardi, D., Jordà, Ò., & Taylor, A. M. (2023). A local projections approach to difference-in-differences. *Journal of Applied Econometrics*, 40(1), 1–24.
- Upstream manual: [MacroEconometricModels.jl — Panel & DiD](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/panel/)
- CLI reference: [`friedman estimate panel`](@ref ref-fam-estimate-panel), [`friedman did`](@ref ref-did), [`friedman irf pvar`](@ref ref-irf-pvar), [`friedman test did`](@ref ref-fam-test-did), [`friedman test panel`](@ref ref-fam-test-panel)
