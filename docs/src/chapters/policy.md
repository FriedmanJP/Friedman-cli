# [Policy Counterfactuals & Optimal Policy](@id chap-policy)

Forward-looking monetary/fiscal policy counterfactuals, structural-vs-sufficient causal effect menus, counterfactual history decompositions, sequence-space HA/DSGE news shocks, and quadratic-loss optimal policy projections (McKay & Wolf 2023; de Groot et al. 2021) span [`friedman policy`](@ref ref-policy). Configure `[rule]`, `[loss]`, `[loss.smoothing]`, and OPP floor/ZLB `[[constraint]]` blocks via [GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy). See [MacroEconometricModels.jl — Policy Counterfactuals](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/policy/).

## Quick Start

Simulate a 3-variable macro VAR (`--seed 7`), map causal policy effects over outcomes (`y1=1,y2=2`) and policy instrument (`y3=3`), and evaluate a counterfactual interest-rate peg (`--rule rate-peg`) against a non-policy shock over 6 horizons:

<!-- capture -->
```bash
friedman --quiet data simulate var --periods 150 --burn 50 --seed 7 --save-data pol_sim
friedman policy counterfactual var pol_sim --shocks 3 --nonpolicy-shock 1 --outcomes y1=1,y2=2 --instruments y3=3 --horizon 6 --rule rate-peg
```
```text
                  Policy Counterfactual Paths
┌──────────┬────────────┬─────────┬──────────┬────────────────┐
│ variable │    role    │ horizon │ baseline │ counterfactual │
├──────────┼────────────┼─────────┼──────────┼────────────────┤
│    y1    │  outcome   │    1    │ 1.05875  │    1.05875     │
│    y1    │  outcome   │    2    │ 0.553439 │    0.594849    │
│    y1    │  outcome   │    3    │ 0.386411 │    0.406534    │
│    y1    │  outcome   │    4    │ 0.269918 │    0.281265    │
│    y1    │  outcome   │    5    │ 0.189571 │    0.19652     │
│    y1    │  outcome   │    6    │ 0.133503 │    0.13802     │
│    y2    │  outcome   │    1    │ 0.424755 │    0.424755    │
│    y2    │  outcome   │    2    │ 0.478048 │    0.457307    │
│    y2    │  outcome   │    3    │ 0.346778 │    0.345005    │
│    y2    │  outcome   │    4    │ 0.24945  │    0.252524    │
│    y2    │  outcome   │    5    │ 0.177835 │    0.181609    │
│    y2    │  outcome   │    6    │ 0.126217 │    0.129473    │
│    y3    │ instrument │    1    │ 0.336632 │   -0.001015    │
│    y3    │ instrument │    2    │ 0.05319  │   -0.018851    │
│    y3    │ instrument │    3    │ 0.070097 │    0.044004    │
│    y3    │ instrument │    4    │ 0.059453 │    0.050898    │
│    y3    │ instrument │    5    │ 0.045698 │    0.043277    │
│    y3    │ instrument │    6    │ 0.033642 │    0.033267    │
└──────────┴────────────┴─────────┴──────────┴────────────────┘
Enforcing Policy Shocks (nu)
┌───────┬───────────┐
│ shock │    nu     │
├───────┼───────────┤
│  y3   │ -0.370186 │
└───────┴───────────┘
Implementation Error Path
┌───────┬───────────┐
│ index │   error   │
├───────┼───────────┤
│   1   │ -0.001015 │
│   2   │ -0.018851 │
│   3   │ 0.044004  │
│   4   │ 0.050898  │
│   5   │ 0.043277  │
│   6   │ 0.033267  │
└───────┴───────────┘
                                                                    Counterfactual Summary
┌─────────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│     metric      │                                                                   value                                                                   │
├─────────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│      rule       │                                                                 rate peg                                                                  │
│        H        │                                                                     6                                                                     │
│  rel_residual   │                                                                 0.248025                                                                  │
│     spanned     │                                                                   false                                                                   │
│  n_draws_used   │                                                                     0                                                                     │
│ n_draws_failed  │                                                                     0                                                                     │
│ quantile_levels │                                                              0.16, 0.5, 0.84                                                              │
│      note       │ rule NOT enforceable within the span of the supplied policy shocks; the counterfactual is a least-squares approximation — read error_path │
└─────────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

The command returns `policy_counterfactual_paths` (`y1` shifts from baseline `0.553439` to `0.594849` at $h=2$ under enforcing shock `nu = -0.370186`), `enforcing_policy_shocks_nu`, `implementation_error_path` (`-0.001015` at $h=1$), and `counterfactual_summary` (including spanning residual diagnostics `rel_residual` and `spanned`).

---

## Policy-Conforming Counterfactuals (`effects`, `counterfactual`, `history`, `moments`)

Under the McKay–Wolf (2023) policy-news representation, counterfactual rule paths around a non-policy shock $\Theta_{y,s}$ combine observed baseline responses with a linear combination $\nu$ of $K_p$ policy shocks $\Psi_y$ satisfying linear rule residuals $\mathcal{R}_x (\Theta_{x,s} + \Psi_x \nu) = 0$:

```math
y_s^{\text{cf}} = \Theta_{y,s} + \Psi_y \nu, \qquad \nu = \arg\min_\nu \left\|\mathcal{R}\left(\Theta_{\cdot,s} + \Psi\nu\right)\right\|_2^2.
```

Because empirical policy shocks are only asymptotically equivalent to structural rules when $K_p < H$ or the causal menu is incomplete, Friedman-cli reports exact implementation residuals alongside counterfactual outcome trajectories:

| Verb Group | Estimator Backends | Inputs & Key Output Tables (`--format json`) |
|---|---|---|
| [`effects`](@ref ref-fam-policy-effects) | `var`, `bvar`, `lp`, `sign` | Causal menu $\Psi$ across `--shocks`, `--outcomes`, `--instruments` (`policy_causal_effects_menu`, `policy_causal_effects_summary`) |
| [`counterfactual`](@ref ref-fam-policy-counterfactual) | `var`, `bvar`, `lp` | Rule-enforcing response path `--rule` / `--rule-config` (`policy_counterfactual_paths`, `enforcing_policy_shocks_nu`, `counterfactual_summary`) |
| [`history`](@ref ref-fam-policy-history) | `var`, `bvar` | Historical counterfactual simulation (`--t-range`, `[loss]` / `[rule]`; `counterfactual_history`, `history_summary`) |
| [`moments`](@ref ref-fam-policy-moments) | `var`, `bvar` | Unconditional counterfactual volatilities and correlations (`counterfactual_standard_deviations`, `counterfactual_correlations`) |

<!-- capture -->
```bash
friedman --quiet data simulate var --periods 150 --burn 50 --seed 7 --save-data pol_sim2
friedman policy effects var pol_sim2 --shocks 3 --outcomes y1=1,y2=2 --instruments y3=3 --horizon 6 --normalize instrument-impact
```
```text
              Policy Causal Effects Menu
┌──────────┬────────────┬───────┬─────────┬───────────┐
│ variable │    role    │ shock │ horizon │   value   │
├──────────┼────────────┼───────┼─────────┼───────────┤
│    y1    │  outcome   │  y3   │    1    │    0.0    │
│    y1    │  outcome   │  y3   │    2    │ -0.12264  │
│    y1    │  outcome   │  y3   │    3    │ -0.059599 │
│    y1    │  outcome   │  y3   │    4    │ -0.033609 │
│    y1    │  outcome   │  y3   │    5    │ -0.020582 │
│    y1    │  outcome   │  y3   │    6    │ -0.013376 │
│    y2    │  outcome   │  y3   │    1    │    0.0    │
│    y2    │  outcome   │  y3   │    2    │ 0.061427  │
│    y2    │  outcome   │  y3   │    3    │ 0.005253  │
│    y2    │  outcome   │  y3   │    4    │ -0.009104 │
│    y2    │  outcome   │  y3   │    5    │ -0.011176 │
│    y2    │  outcome   │  y3   │    6    │ -0.009641 │
│    y3    │ instrument │  y3   │    1    │    1.0    │
│    y3    │ instrument │  y3   │    2    │ 0.213361  │
│    y3    │ instrument │  y3   │    3    │ 0.077276  │
│    y3    │ instrument │  y3   │    4    │ 0.025338  │
│    y3    │ instrument │  y3   │    5    │ 0.007169  │
│    y3    │ instrument │  y3   │    6    │ 0.001111  │
└──────────┴────────────┴───────┴─────────┴───────────┘
   Policy Causal Effects Summary
┌──────────────┬───────────────────┐
│    metric    │       value       │
├──────────────┼───────────────────┤
│ H (horizon)  │         6         │
│   n_shocks   │         1         │
│ shock_labels │        y3         │
│  is_square   │       false       │
│    source    │        var        │
│  normalize   │ instrument_impact │
│   n_draws    │         0         │
└──────────────┴───────────────────┘
```

Setting `--normalize instrument-impact` rescales each policy shock column so its contemporaneous effect on `y3` equals `1.0` (`y1` falls by `-0.12264` at $h=2$ in `policy_causal_effects_menu`).

---

## Optimal Policy, Projections & Structural Tests (`optimal`, `opp`, `opp-sequence`)

When `[loss]` specifies quadratic welfare weights $\lambda$ over target deviations ([GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy)), optimal policy chooses enforcing policy shocks $\nu^*$ to minimize expected discounted quadratic loss $L = \sum_{h=0}^{H-1} \beta^h (\tilde{y}_h' W_y \tilde{y}_h + \tilde{z}_h' W_z \tilde{z}_h)$:

- **Unconstrained Optimal Counterfactuals ([`policy optimal`](@ref ref-fam-policy-optimal)):** Computes $\nu^*$ for a specified non-policy shock across `var`, `bvar`, or `lp` backends (`policy_counterfactual_paths`).
- **Optimal Policy Projections ([`policy opp`](@ref ref-fam-policy-opp) & [`opp-sequence`](@ref ref-fam-policy-opp-sequence)):** Implements de Groot et al. (2021) outlook recommendations (`opp_recommendation_delta`, `objective_gap_paths`, `instrument_paths_announced_vs_recommended`) relative to an announced `--instrument-path` under optional floor/ZLB `[[constraint]]` blocks (`--constraints-file`), or tracks policy revisions over forecast vintages (`--forecasts-dir`).

---

## Sequence-Space HA/DSGE News & Policy Spanning (`news`, `jacobian`, `spanning`, `sufficiency`)

Connect empirical VAR/LP policy menus directly to structural equilibrium models:

- **Equilibrium Jacobian & News ([`policy jacobian ha`](@ref ref-policy-jacobian-ha), [`policy news dsge|ha`](@ref ref-fam-policy-news)):** Computes heterogeneous-agent sequence-space Jacobians (`--input r|w`, `sequence_space_jacobian`) and structural anticipated policy news matrices for `dsge` (with optional `--behavioral-m`, `--behavioral-theta` myopia/discounting) or `hadsge` (`--rule-closure administered|market`).
- **Empirical Testability ([`policy spanning var`](@ref ref-policy-spanning-var), [`policy sufficiency dsge`](@ref ref-policy-sufficiency-dsge)):** Compares empirical "thin" vs. structural "full" counterfactual paths (`spanning_verdict`) and tests whether observable macro indicators satisfy forecast-variance sufficiency (`forecast_sufficiency_fev_ratios`).

---

## Common Pitfalls

1. **Expecting separate level targeting in `[rule]`:** McKay–Wolf counterfactual rules govern linear *stabilization* around the baseline steady state; shifting permanent inflation/output targets violates linearity and is unsupported.
2. **Omitting `--nonpolicy-shock` on `counterfactual` or `optimal`:** `effects` accepts only `--shocks`, whereas `counterfactual`, `optimal`, and `spanning` require both `--shocks` (policy instruments/shocks) and `--nonpolicy-shock` (the propagation shock being offset).
3. **Supplying `[loss.smoothing]` partially:** `[loss.smoothing]` is validated atomically (`lambda > 0`, `beta in (0, 1]`, optional `z_lag`); omitting required weights inside `[loss]` under default `type = "diagonal"` returns exit `4` (`config/invalid`).

---

## References

- McKay, A., & Wolf, C. K. (2023). What can time-series regressions tell us about policy counterfactuals? *Econometrica*, 91(5), 1695–1725.
- de Groot, O., Mazelis, F., Motto, R., & Ristiniemi, A. (2021). A toolkit for computing constrained optimal policy projections (OPP). *ECB Working Paper* 2555.
- Wolf, C. K. (2025). The missing intercept: Demand shocks in general equilibrium. *Review of Economic Studies* (spanning / sufficiency applications).
- Upstream manual: [MacroEconometricModels.jl — Policy Counterfactuals](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/policy/)
- CLI reference: [`friedman policy`](@ref ref-policy), [`friedman policy counterfactual`](@ref ref-fam-policy-counterfactual), [`friedman policy effects`](@ref ref-fam-policy-effects), [`friedman policy opp`](@ref ref-fam-policy-opp), [`friedman policy optimal`](@ref ref-fam-policy-optimal)
