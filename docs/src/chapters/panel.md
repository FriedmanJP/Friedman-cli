# [Panel Data, Panel VAR & Causal DiD](@id chap-panel)

Longitudinal micro- and macro-panel estimators ([`estimate panel`](@ref ref-fam-estimate-panel)), panel vector autoregressions ([`estimate panel pvar`](@ref ref-estimate-panel-pvar), [`irf pvar`](@ref ref-irf-pvar), [`fevd pvar`](@ref ref-fevd-pvar)), staggered difference-in-differences and local-projection DiD ([`did`](@ref ref-did)), and panel/DiD specification diagnostics ([`test panel`](@ref ref-fam-test-panel), [`test pvar`](@ref ref-fam-test-pvar), [`test did`](@ref ref-fam-test-did)) handle correlated unit effects, dynamic GMM instruments, and heterogeneous treatment timing. Micro-panel estimators (`preg`, `piv`, `plogit`, `pprobit`, `xtqreg`) and standard DiD (`did estimate`, `did event-study`, `test did honest|pretrend`) default to **90%** confidence intervals, whereas macro-panel leaves (`pvar`, `pmg`, `xtcointreg`) and macro local-projection DiD ([`did lp-did`](@ref ref-did-lp-did)) default to **68%** (override any leaf via `-L`/`--conf-level`). See [MacroEconometricModels.jl — Panel & DiD](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/panel/).

## Quick Start

Estimate a panel regression on Grunfeld's firm investment dataset (`:grunfeld`) using fixed effects (`--method fe`) with clustered standard errors, or estimate group-time ATTs under staggered adoption:

<!-- capture -->
```bash
frdc --quiet data simulate panel --kind linear --n 20 --periods 10 --seed 1 --save-data pan_sim
frdc estimate panel preg pan_sim --dep y --indep x1,x2 --id-col id --time-col time --method fe --cov-type cluster
```
```text
                   Panel Regression Coefficients (fe)
┌──────┬──────────┬───────────┬────────┬─────────┬──────────┬──────────┐
│ term │ estimate │ std_error │  stat  │ p_value │ ci_lower │ ci_upper │
├──────┼──────────┼───────────┼────────┼─────────┼──────────┼──────────┤
│  x1  │  0.979   │   0.087   │ 11.227 │  0.000  │  0.835   │  1.123   │
│  x2  │  0.510   │   0.102   │ 4.987  │  0.000  │  0.341   │  0.679   │
└──────┴──────────┴───────────┴────────┴─────────┴──────────┴──────────┘
    Model Statistics
┌──────────────┬────────┐
│    metric    │ value  │
├──────────────┼────────┤
│ R2 (within)  │ 0.518  │
│ R2 (between) │ 0.027  │
│ R2 (overall) │ 0.350  │
│ F-statistic  │ 65.038 │
│  F p-value   │ 0.000  │
│    N obs     │  200   │
│   N groups   │   20   │
└──────────────┴────────┘
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
| [`xtqreg`](@ref ref-estimate-panel-xtqreg) | Interactive-factor panel quantile regression (`--tau`, `--factors`, `--slope`, bias correction) | [`predict`/`residuals panel xtqreg`](@ref ref-predict-panel-xtqreg) |

---

## Panel Vector Autoregressions (`pvar`)

Abrigo–Love GMM Panel VAR estimates a $K$-variable dynamic panel system after forward orthogonal deviations or first differencing (`--transformation fd|fod`), eliminating fixed effects without Nickell bias (`--system` adds level moment conditions; `--collapse` caps instrument proliferation):

<!-- capture -->
```bash
frdc --quiet data simulate pvar --n 15 --periods 12 --seed 42 --save-data pvar_sim
frdc estimate panel pvar pvar_sim --id-col id --time-col time --lags 1 --dependent y1,y2 --steps twostep
```
```text
                                               Panel VAR(1) Coefficients (gmm)
┌───────────┬─────────┬───────┬─────────┬─────────────┬─────────────┬─────────┬───────┬─────────┬─────────────┬─────────────┐
│ parameter │ y1_coef │ y1_se │ y1_pval │ y1_ci_lower │ y1_ci_upper │ y2_coef │ y2_se │ y2_pval │ y2_ci_lower │ y2_ci_upper │
├───────────┼─────────┼───────┼─────────┼─────────────┼─────────────┼─────────┼───────┼─────────┼─────────────┼─────────────┤
│   y1_L1   │ -0.001  │ 0.578 │  0.998  │   -0.576    │    0.573    │  0.124  │ 1.070 │  0.908  │   -0.941    │    1.188    │
│   y2_L1   │  0.279  │ 0.569 │  0.624  │   -0.287    │    0.845    │ -0.067  │ 0.471 │  0.886  │   -0.535    │    0.401    │
└───────────┴─────────┴───────┴─────────┴─────────────┴─────────────┴─────────┴───────┴─────────┴─────────────┴─────────────┘
         Panel Summary
┌────────────────────┬────────┐
│       metric       │ value  │
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
frdc --quiet data simulate did --n 60 --periods 12 --seed 17 --save-data did_sim
frdc did estimate did_sim --outcome y --treatment cohort --id-col id --time-col time --method cs --control-group never_treated
```
```text
                                DID Estimation — CS
┌────────────┬──────┬──────────┬───────────┬───────┬─────────┬──────────┬──────────┐
│ event_time │ term │ estimate │ std_error │ stat  │ p_value │ ci_lower │ ci_upper │
├────────────┼──────┼──────────┼───────────┼───────┼─────────┼──────────┼──────────┤
│     0      │ e=0  │  0.764   │   0.351   │ 2.177 │  0.029  │  0.187   │  1.341   │
│     1      │ e=1  │  0.958   │   0.345   │ 2.773 │  0.006  │  0.390   │  1.526   │
│     2      │ e=2  │  1.164   │   0.391   │ 2.975 │  0.003  │  0.520   │  1.808   │
│     3      │ e=3  │  0.893   │   0.455   │ 1.962 │  0.050  │  0.144   │  1.642   │
│     4      │ e=4  │  1.237   │   0.366   │ 3.377 │  0.001  │  0.634   │  1.839   │
│     5      │ e=5  │  1.025   │   0.400   │ 2.566 │  0.010  │  0.368   │  1.683   │
└────────────┴──────┴──────────┴───────────┴───────┴─────────┴──────────┴──────────┘
                                                       Group-Time ATT (Callaway-Sant'Anna)
┌────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬───────────┬───────────┬───────────┐
│ Cohort │ period_1 │ period_2 │ period_3 │ period_4 │ period_5 │ period_6 │ period_7 │ period_8 │ period_9 │ period_10 │ period_11 │ period_12 │
├────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼──────────┼───────────┼───────────┼───────────┤
│   6    │   NaN    │  -0.570  │  -0.166  │  0.085   │  0.314   │  0.637   │  0.880   │  1.164   │  0.893   │   1.237   │   1.025   │   1.124   │
│   11   │   NaN    │  0.603   │  -0.372  │  -0.674  │  0.326   │  0.241   │  -0.137  │  0.394   │  -0.281  │  -0.105   │   0.970   │   1.083   │
└────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴───────────┴───────────┴───────────┘
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
- CLI reference: [`frdc estimate panel`](@ref ref-fam-estimate-panel), [`frdc did`](@ref ref-did), [`frdc irf pvar`](@ref ref-irf-pvar), [`frdc test did`](@ref ref-fam-test-did), [`frdc test panel`](@ref ref-fam-test-panel)
