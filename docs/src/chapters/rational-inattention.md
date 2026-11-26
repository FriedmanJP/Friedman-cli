# [Rational Inattention](@id chap-ri)

Information-constrained decision making—covering linear-quadratic-Gaussian (LQG) dynamic tracking, finite-horizon attention transitions, state-space & structural estimation, Coibion–Gorodnichenko expectation-rigidity tests, Maćkowiak–Wiederholt multi-block attention allocation, Matějka–McKay discrete choice, and structural RI-logit—lives across the 11 leaves under [`frdc ri`](@ref ref-ri) together with [`estimate choice ri-logit`](@ref ref-estimate-choice-ri-logit) and [`predict choice ri-logit`](@ref ref-predict-choice-ri-logit). Macro RI estimation and expectation-rigidity leaves (`ri estimate`, `ri cg-test`) default to **68%** confidence intervals (`-L`/`--conf-level 0.68`), while discrete-choice `estimate choice ri-logit` defaults to **90%**. Configure `[ri]`, `[ri.mw]`, `[ri.discrete]`, and `[ri.logit]` TOML sections via [GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy). See [MacroEconometricModels.jl — Rational Inattention](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/ri/) for full derivations.

## Quick Start

Define a scalar LQG tracking problem (`x_t = 0.85 x_{t-1} + 0.5 \varepsilon_t`) under a mutual-information constraint of `capacity = 0.5` bits per period, solve the optimal Sims–Kalman noisy signal structure with [`frdc ri solve`](@ref ref-ri-solve), save the solved model handle, and inspect the implied impulse responses:

<!-- capture -->
```bash
cat > ri_lqg.toml <<'EOF'
[ri]
A = [[0.85]]
B = [[0.5]]
H = [[1.0]]
beta = 0.99
capacity = 0.5
units = "bits"
state_names = ["x"]
action_names = ["a"]
shock_names = ["eps"]
EOF
frdc ri solve --config ri_lqg.toml --save-model ri_sol
```
```text
                         Sims (2003) RI Kalman Solution
┌───────┬────────┬────────┬───────┬───────────────┬─────────────┬───────────────┐
│ state │ signal │ K_gain │ omega │ capacity_bits │ signal_rank │ expected_loss │
├───────┼────────┼────────┼───────┼───────────────┼─────────────┼───────────────┤
│   x   │   1    │ 0.500  │ 0.609 │     0.500     │      1      │     0.196     │
└───────┴────────┴────────┴───────┴───────────────┴─────────────┴───────────────┘
           RI Summary
┌───────────────┬───────────────┐
│    metric     │     value     │
├───────────────┼───────────────┤
│    method     │ water_filling │
│   converged   │     true      │
│  iterations   │       1       │
│     omega     │     0.609     │
│ capacity_bits │     0.500     │
│ capacity_nats │     0.347     │
│  signal_rank  │       1       │
│ expected_loss │     0.196     │
└───────────────┴───────────────┘
```

Under `--format json`, [`frdc ri solve`](@ref ref-ri-solve) emits `ri_kalman_solution` (signal loading, Kalman gain, and steady-state posterior covariance) alongside `ri_summary` (shadow cost `omega`, achieved `capacity_bits`, `signal_rank`, and `expected_loss`). Saving `--save-model ri_sol` persists a native `SimsKalmanSolution` `.jld2` handle that feeds [`ri irf`](@ref ref-ri-irf), [`ri fevd`](@ref ref-ri-fevd), [`ri statespace`](@ref ref-ri-statespace), [`ri transition`](@ref ref-ri-transition), [`ri simulate`](@ref ref-ri-simulate), and [`ri cg-test`](@ref ref-ri-cg-test) without re-solving.

---

## LQG Dynamic Tracking & Structural Estimation (`solve`, `transition`, `statespace`, `estimate`)

In the Sims (2003) / Afrouzi–Yang (2021) dynamic LQG problem, an agent tracks a latent Gaussian state $x_t = A x_{t-1} + B \varepsilon_t$ with optimal target $a_t^* = H' x_t$, trading off quadratic tracking loss against Shannon mutual-information flow $\mathcal{I}(x_t; s_t \mid s^{t-1})$ priced at shadow cost $\omega > 0$ (or capped at capacity $\kappa > 0$):

```math
\min_{\{s_t, a_t\}} \mathbb{E}_0 \sum_{t=0}^{\infty} \beta^t \left[ (a_t - H' x_t)' M (a_t - H' x_t) + \omega \, \mathcal{I}(x_t; s_t \mid s^{t-1}) \right].
```

| Command | Mathematical Role | Key Outputs (`--format json`) |
|---|---|---|
| [`ri solve`](@ref ref-ri-solve) | Steady-state Sims–Kalman water-filling (`--method afrouzi-yang\|reverse-waterfilling`, `--capacity` or `--omega`) | `ri_kalman_solution`, `ri_summary` (or `ri_problem` under `--problem-only`) |
| [`ri transition`](@ref ref-ri-transition) | Finite-horizon attention dynamics from `Sigma_init` or time-varying `omega_path`/`capacity_path` (`--t-path`) | `ri_transition_path`, `ri_transition_summary` |
| [`ri statespace`](@ref ref-ri-statespace) | Convert solved RI dynamics into a canonical `StateSpaceModel` (`--as statespace`) or `ABCDSystem` (`--as abcd`) | `ri_statespace_system` / `abcd_summary` |
| [`ri irf`](@ref ref-ri-irf), [`ri fevd`](@ref ref-ri-fevd) | Structural action/state impulse responses and forecast-error variance shares (`--horizons`, `--observables`) | `ri_irf`, `ri_fevd` |
| [`ri simulate`](@ref ref-ri-simulate) | Seeded synthetic state, signal, and action series (`--periods`, `--burn`, `--save-data`) | `ri_simulation` |
| [`ri estimate`](@ref ref-ri-estimate) | Estimate $\kappa$ or $\omega$ via state-space MLE or Bayesian MH (`--method mle\|bayes`, `--estimate-param capacity\|omega`) | `ri_estimation`, `ri_estimation_summary` |

Notice that every solved LQG object converts cleanly into an econometric state-space or canonical ABCD representation via [`ri statespace`](@ref ref-ri-statespace), letting you test invertibility and shock recoverability with [`dsge abcd`](@ref ref-fam-dsge-abcd) ([Representative-Agent & Bayesian DSGE](@ref chap-dsge)) or pass RI attention gains (`--behavioral-ri-gain`, `--behavioral-ri-rho`) into [`policy news dsge`](@ref ref-policy-news-dsge) ([Policy Counterfactuals & Optimal Policy](@ref chap-policy)).

---

## Multi-Block Attention Allocation & Coibion–Gorodnichenko Tests (`mw`, `cg-test`)

When firms allocate a scarce total attention budget $\kappa = \kappa_{\text{agg}} + \kappa_{\text{idio}}$ across aggregate macro shocks and larger, less persistent idiosyncratic shocks (Maćkowiak & Wiederholt 2009), optimal pricing places most attention on idiosyncratic conditions and responds sluggishly to monetary shocks—generating positive Coibion–Gorodnichenko (2015) forecast-error-on-forecast-revision regressions:

```math
y_{t+h} - F_t y_{t+h} = \alpha + \beta_{\text{CG}} \left( F_t y_{t+h} - F_{t-1} y_{t+h} \right) + u_{t+h}, \qquad \beta_{\text{CG}} = \frac{1 - G}{G}.
```

- **Aggregate vs. Idiosyncratic Attention ([`ri mw`](@ref ref-ri-mw)):** Solves optimal block attention shares (`kappa_agg`, `kappa_idio`, `agg_attention_share`) with optional `--strategic-complementarity` feedback under `[ri.mw.agg_block]` and `[ri.mw.idio_block]`.
- **Expectations Rigidity Test ([`ri cg-test`](@ref ref-ri-cg-test)):** Regresses forecast errors on forecast revisions with Newey–West HAC standard errors (`--realized`, `--forecast-now`, `--forecast-lag`, `--hac-lags`), reporting the implied Kalman gain $G$ and information capacity; pass `--model ri_sol.jld2` to compare the empirical slope directly against `model_implied_cg_slope`.

<!-- capture -->
```bash
cat > ri_mw.toml <<'EOF'
[ri.mw]
capacity = 2.0
strategic_complementarity = 0.25
units = "bits"

[ri.mw.agg_block]
rho = 0.90
sigma = 0.01
weight = 1.0

[ri.mw.idio_block]
rho = 0.50
sigma = 0.10
weight = 1.0
EOF
frdc ri mw --config ri_mw.toml --horizons 6
```
```text
                       Maćkowiak-Wiederholt (2009) Attention Allocation
┌─────────┬───────────────┬────────────────┬─────────────────┬───────────┬────────────┬───────┐
│ horizon │ agg_price_irf │ idio_price_irf │ real_output_irf │ kappa_agg │ kappa_idio │ omega │
├─────────┼───────────────┼────────────────┼─────────────────┼───────────┼────────────┼───────┤
│    0    │     0.001     │     0.093      │      0.009      │   0.096   │   1.904    │ 0.001 │
│    1    │     0.002     │     0.050      │      0.007      │   0.096   │   1.904    │ 0.001 │
│    2    │     0.002     │     0.025      │      0.006      │   0.096   │   1.904    │ 0.001 │
│    3    │     0.003     │     0.012      │      0.005      │   0.096   │   1.904    │ 0.001 │
│    4    │     0.003     │     0.006      │      0.004      │   0.096   │   1.904    │ 0.001 │
│    5    │     0.003     │     0.003      │      0.003      │   0.096   │   1.904    │ 0.001 │
└─────────┴───────────────┴────────────────┴─────────────────┴───────────┴────────────┴───────┘
        MW Attention Summary
┌───────────────────────────┬───────┐
│          metric           │ value │
├───────────────────────────┼───────┤
│         kappa_agg         │ 0.096 │
│        kappa_idio         │ 1.904 │
│        total_kappa        │ 2.000 │
│    agg_attention_share    │ 0.048 │
│           omega           │ 0.001 │
│ strategic_complementarity │ 0.250 │
│           units           │ bits  │
│         converged         │ true  │
│        iterations         │   7   │
└───────────────────────────┴───────┘
```

The `ri_mw_allocation` and `ri_mw_summary` tables report how the `2.0`-bit budget splits between aggregate and idiosyncratic blocks (`kappa_agg`, `kappa_idio`, `agg_attention_share`) together with the equilibrium shadow cost `omega`.

---

## Discrete-Choice Rational Inattention (`discrete`, `iia-test`, `ri-logit`)

In Matějka & McKay (2015), a rationally inattentive agent choosing among $J$ discrete options across $S$ payoff states with prior $\mu$ solves the Blahut–Arimoto / generalized multinomial-logit fixed point:

```math
P(a = j \mid s) = \frac{P_0(j) \exp\left(u(j, s) / \omega\right)}{\sum_{k=1}^J P_0(k) \exp\left(u(k, s) / \omega\right)}, \qquad P_0(j) = \sum_{s=1}^S \mu(s) P(a = j \mid s),
```

where endogenous unconditional choice weights $P_0(j)$ can shrink to zero (forming a sparse **consideration set**) and violate McFadden's Independence of Irrelevant Alternatives (IIA) whenever correlated alternatives enter the choice menu.

- **Equilibrium Choice Probabilities ([`ri discrete`](@ref ref-ri-discrete)):** Solves unconditional and state-conditional choice probabilities, mutual information, expected utility, net welfare, and active `consideration_set` from `[ri.discrete]` (`U`, `mu`, plus `--omega` or `--capacity`).
- **IIA Violation Diagnostic ([`ri iia-test`](@ref ref-ri-iia-test)):** Compares base choices against an expanded menu with `new_option_payoffs`, reporting `max_uncond_odds_shift`, `cond_odds_ratio_max_diff`, and `max_iia_violation`.
- **Empirical Structural RI-Logit ([`estimate choice ri-logit`](@ref ref-estimate-choice-ri-logit), [`predict choice ri-logit`](@ref ref-predict-choice-ri-logit)):** Estimates preference weights and attention-cost ratios directly from observed multi-environment choice panels (both observed-state and `--unobserved-state` mixtures; see also [Discrete Choice, Count & Selection](@ref chap-choice)).

<!-- capture -->
```bash
cat > ri_disc.toml <<'EOF'
[ri.discrete]
U = [[2.0, 0.0], [0.0, 2.0], [0.5, 0.5]]
mu = [0.5, 0.5]
omega = 0.8
units = "nats"
EOF
frdc ri discrete --config ri_disc.toml
```
```text
      Matějka-McKay Discrete-Choice RI Solution
┌───────┬────────┬────────┬───────────┬─────────────┐
│ state │ action │ payoff │ cond_prob │ uncond_prob │
├───────┼────────┼────────┼───────────┼─────────────┤
│   1   │   1    │ 2.000  │   0.924   │    0.500    │
│   2   │   1    │ 0.000  │   0.076   │    0.500    │
│   3   │   1    │ 0.500  │   0.000   │    0.500    │
│   1   │   2    │ 0.000  │   0.076   │    0.500    │
│   2   │   2    │ 2.000  │   0.924   │    0.500    │
│   3   │   2    │ 0.500  │   0.000   │    0.500    │
└───────┴────────┴────────┴───────────┴─────────────┘
     Discrete RI Summary
┌───────────────────┬───────┐
│      metric       │ value │
├───────────────────┼───────┤
│   alternatives    │   3   │
│      states       │   2   │
│       omega       │ 0.800 │
│ consideration_set │  1,2  │
│ mutual_info_bits  │ 0.613 │
│ mutual_info_nats  │ 0.425 │
│ expected_utility  │ 1.848 │
│    net_welfare    │ 1.509 │
│     converged     │ true  │
│    iterations     │   3   │
└───────────────────┴───────┘
```

The `ri_discrete_choice` and `ri_discrete_summary` tables display the endogenous consideration set, conditional choice probabilities across payoff states, achieved mutual information (`mutual_info_bits`, `mutual_info_nats`), and `net_welfare`.

---

## Common Pitfalls

1. **Passing both `--capacity` and `--omega` (or setting both in `[ri]`):** Information capacity $\kappa$ and shadow cost $\omega$ are dual parameterizations and strictly mutually exclusive; supplying both raises exit `2` (`usage/invalid`) or `4` (`config/invalid`).
2. **Mixing `bits` and `nats` when comparing capacities:** Specify `--units bits` (base-2 log, default in Sims / Maćkowiak–Wiederholt) or `--units nats` (natural log, standard in Matějka–McKay discrete choice) consistently across `[ri]` configs and CLI overrides; summary tables report both `capacity_bits` and `capacity_nats`.
3. **Expecting `--plot` on `ri simulate`:** All 10 analytical/diagnostic `ri` leaves (`solve`, `transition`, `statespace`, `irf`, `fevd`, `estimate`, `cg-test`, `mw`, `discrete`, `iia-test`) plus `estimate choice ri-logit` support `--plot` / `--plot-save`; [`ri simulate`](@ref ref-ri-simulate) emits raw simulated paths (`--save-data`) and intentionally omits `--plot`.

---

## References

- Sims, C. A. (2003). Implications of rational inattention. *Journal of Monetary Economics*, 50(3), 665–690.
- Maćkowiak, B., & Wiederholt, M. (2009). Optimal sticky prices under rational inattention. *American Economic Review*, 99(3), 769–803.
- Matějka, F., & McKay, A. (2015). Rational inattention to discrete choices: A new foundation for the multinomial logit model. *American Economic Review*, 105(1), 272–298.
- Coibion, O., & Gorodnichenko, Y. (2015). Information rigidity and the expectations formation process: A simple framework and new facts. *American Economic Review*, 105(8), 2644–2678.
- Afrouzi, H., & Yang, C. (2021). Dynamic rational inattention and the Phillips curve. *NBER Working Paper* / *Journal of Monetary Economics*.
- Upstream manual: [MacroEconometricModels.jl — Rational Inattention](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/ri/)
- CLI reference: [`frdc ri`](@ref ref-ri), [`frdc ri solve`](@ref ref-ri-solve), [`frdc ri mw`](@ref ref-ri-mw), [`frdc ri discrete`](@ref ref-ri-discrete), [`frdc estimate choice ri-logit`](@ref ref-estimate-choice-ri-logit)
