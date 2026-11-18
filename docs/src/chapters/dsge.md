# [Representative-Agent & Bayesian DSGE](@id chap-dsge)

Representative-agent dynamic stochastic general equilibrium solving, deterministic transition paths, occasionally binding constraints (OccBin), parameter estimation, and full Bayesian SMC / Random-Walk Metropolis–Hastings inference live across the representative-agent leaves under [`friedman dsge`](@ref ref-dsge) (`ra` family, [`ref-fam-dsge-ra`](@ref ref-fam-dsge-ra)). Heterogeneous-agent, continuous-time, OLG, DCEGM, firm, and banking equilibrium models (`hadsge` and `dsge ct|olg|dcegm|lifecycle|firm|bank`) are covered separately in [Heterogeneous-Agent, CT & OLG Models](@ref chap-hadsge). See [MacroEconometricModels.jl — DSGE](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/dsge/).

## Quick Start

Write an `@dsge begin ... end` `.jl` model file (or TOML `[model]` spec in [DSGE Specs, Priors & OccBin Constraints](@ref cfg-dsge)), solve linear rational expectations via Sims (`gensys`), and inspect policy and transition matrices:

<!-- capture -->
```bash
cat > rbc_lin.jl <<'EOF'
@dsge begin
    parameters: rho = 0.85, sigma = 0.02, kappa = 0.25
    endogenous: y, pi
    exogenous: e_a
    linear: true

    y[t] = rho * y[t-1] + sigma * e_a[t]
    pi[t] = 0.99 * pi[t+1] + kappa * y[t]
end
EOF
friedman dsge solve rbc_lin.jl --method gensys --periods 6
```
```text
                 Determinacy Verdict
┌────────────┬──────────────────────────────────────┐
│   metric   │                value                 │
├────────────┼──────────────────────────────────────┤
│ existence  │                  1                   │
│ uniqueness │                  1                   │
│  verdict   │ determinate (unique stable solution) │
│   solver   │                gensys                │
└────────────┴──────────────────────────────────────┘
DSGE Solution (method=gensys)
┌──────────┬─────────┬───────┐
│ variable │  G1_y   │ G1_pi │
├──────────┼─────────┼───────┤
│    y     │  0.85   │ -0.0  │
│    pi    │ 1.34069 │ -0.0  │
└──────────┴─────────┴───────┘
```

Under `--format json`, [`dsge solve`](@ref ref-dsge-solve) emits `dsge_solution`, `perturbation_policy_gx`, and `determinacy_verdict` (unique stable equilibrium with `G1_y = 0.85` and `G1_pi = 1.34069` under `gensys`).

---

## Steady States, Perturbation, Projection & OccBin (`solve`, `irf`, `perfect-foresight`)

A nonlinear rational-expectations equilibrium satisfies conditional Euler and market-clearing conditions around deterministic steady state $\bar{y}$:

```math
\mathbb{E}_t\left[f(y_{t+1}, y_t, y_{t-1}, \varepsilon_t; \theta)\right] = 0, \qquad \varepsilon_t \sim (0, \Sigma_\varepsilon).
```

| Command | Solution Algorithm & Scope | Key Options & Output Tables (`--format json`) |
|---|---|---|
| [`dsge steady-state`](@ref ref-dsge-steady-state) | Deterministic steady state solving $f(\bar{y},\bar{y},\bar{y},0) = 0$ | Optional two-sided constraints; `dsge_steady_state` |
| [`dsge solve`](@ref ref-dsge-solve) | Linear (`gensys`, `klein`, `blanchard-kahn`), pruned higher-order `perturbation` (`--order 1\|2\|3`), Chebyshev `projection`, `pfi`, Bellman `vfi`, and piecewise OccBin (`--constraints`, `--constraint`) | `dsge_solution`, `perturbation_policy_gx`, `projection_solution`, `vfi_value_function`, `dsge_occbin_solution` |
| [`dsge irf`](@ref ref-dsge-irf), [`fevd`](@ref ref-dsge-fevd), [`hd`](@ref ref-dsge-hd) | Theoretical or nonlinear simulation (`--n-sim`) IRFs, variance shares, and Kalman-smoothed historical shock decompositions | `dsge_irf`, `occbin_irf`, `dsge_fevd`, `dsge_historical_decomposition` |
| [`dsge simulate`](@ref ref-dsge-simulate), [`moments`](@ref ref-dsge-moments) | Synthetic time series (`--antithetic`) and theoretical autocovariances | `dsge_simulation`, `dsge_theoretical_moments` |
| [`dsge perfect-foresight`](@ref ref-dsge-perfect-foresight) | Deterministic nonlinear stacked-time Newton path (`--shocks`, `--sparsity`) | `perfect_foresight_path` |
| [`dsge determinacy-map`](@ref ref-dsge-determinacy-map) | 1D / 2D parameter grid sweep over `[determinacy]` (`--threaded`) | `dsge_determinacy_map`, `determinacy_region_summary`, `determinacy_boundary` |

Follow [`dsge steady-state`](@ref ref-dsge-steady-state) directly with [`dsge solve`](@ref ref-dsge-solve) or pass `--save-model` so [`dsge irf`](@ref ref-dsge-irf) and [`dsge simulate`](@ref ref-dsge-simulate) reuse the solved policy functions. Notice `--constraint 'i[t] >= 0.0'` (one-sided) activates OccBin regime switching in `solve` and `irf`, while `perfect-foresight` and `steady-state` also support two-sided bounds `lo <= x[t] <= hi`.

<!-- capture -->
```bash
cat > nk_occ.jl <<'EOF'
@dsge begin
    parameters: rho = 0.8, sigma = 0.01
    endogenous: y, c
    exogenous: e
    linear: true

    y[t] = rho * y[t-1] + sigma * e[t]
    c[t] = y[t]
end
EOF
friedman dsge irf nk_occ.jl --method gensys --horizon 6 --constraint 'c[t] >= 0.0'
```
```text
         OccBin IRF: y ← e
┌─────────┬───────────┬───────────┐
│ horizon │  linear   │ piecewise │
├─────────┼───────────┼───────────┤
│    0    │   0.01    │   0.01    │
│    1    │   0.008   │   0.008   │
│    2    │  0.0064   │  0.0064   │
│    3    │  0.00512  │  0.00512  │
│    4    │ 0.004096  │ 0.004096  │
│    5    │ 0.0032768 │ 0.0032768 │
└─────────┴───────────┴───────────┘
         OccBin IRF: c ← e
┌─────────┬───────────┬───────────┐
│ horizon │  linear   │ piecewise │
├─────────┼───────────┼───────────┤
│    0    │   0.01    │   0.01    │
│    1    │   0.008   │   0.008   │
│    2    │  0.0064   │  0.0064   │
│    3    │  0.00512  │  0.00512  │
│    4    │ 0.004096  │ 0.004096  │
│    5    │ 0.0032768 │ 0.0032768 │
└─────────┴───────────┴───────────┘
```

Applying the one-sided OccBin floor keeps `c` bounded from below across horizons in `occbin_irf` (`dsge_irf` for unconstrained IRFs).

---

## Classical & Bayesian DSGE Estimation (`estimate`, `dsge bayes *`)

Friedman-cli estimates structural parameters $\theta$ by matching impulse responses, moments, or state-space Gaussian likelihood $p(Y_{1:T} \mid \theta) p(\theta)$ using Sequential Monte Carlo (`--sampler smc|smc2`) or Random-Walk Metropolis–Hastings (`--sampler mh`).

- **Frequentist Structural Estimation ([`dsge estimate`](@ref ref-dsge-estimate)):** Choose `--method irf_matching|euler_gmm|smm|analytical_gmm` over observable `--data`, listing calibrated/estimated symbols in `--params` (`dsge_estimation`).
- **Bayesian Workflow ([`dsge bayes`](@ref ref-fam-dsge-ra)):** Write priors in a `priors:` preamble above `@dsge`, repeat `--prior 'rho ~ beta(2, 2)'`, or supply a `[priors.*]` TOML file ([DSGE Specs, Priors & OccBin Constraints](@ref cfg-dsge)), choosing observational transforms (`--prefilter none|demean|first-difference|linear-detrend|hp`) and measurement noise (`--measurement-error`).

| Estimation Stage | Subcommands under `friedman dsge bayes` | Key Purpose & Output Tables |
|---|---|---|
| Pre-estimation & Mode | `prior-predictive`, `identification`, `posterior-mode` | Check synthetic prior plausibility (`prior_predictive_summary`), local Iskrev/Komunjer–Ng identification rank (`identification_diagnostics`), and MAP mode (`posterior_mode`) |
| Posterior Sampling | `estimate`, `summary`, `mcmc-diag`, `overlap`, `learning-rate` | SMC/MH sampling (`bayesian_dsge_posterior`), Geweke/ESS/R-hat convergence (`mcmc_convergence_diagnostics`), prior-posterior overlap, and subsample stability |
| Posterior Inference & Models | `irf`, `fevd`, `hd`, `simulate`, `predictive`, `marginal-lik`, `compare` | Posterior fan IRFs (`bayesian_dsge_irf`), FEVD/HD, posterior predictive checks, bridge-sampling marginal likelihood, and Bayes factors (`bayesian_model_comparison`) |

<!-- capture -->
```bash
cat > ar_id.jl <<'EOF'
@dsge begin
    parameters: rho = 0.75, sigma = 0.02
    endogenous: y
    exogenous: e
    linear: true

    y[t] = rho * y[t-1] + sigma * e[t]
end
EOF
friedman dsge bayes identification ar_id.jl --params rho,sigma --observables y
```
```text
Identification Diagnostics
┌────────────┬────────────┐
│   metric   │   value    │
├────────────┼────────────┤
│    rank    │     2      │
│  n_params  │     2      │
│ n_moments  │     4      │
│   n_lags   │     2      │
│ identified │    true    │
│    tol     │ 1.86918e-9 │
└────────────┴────────────┘
     Singular Values
┌───────┬────────────────┐
│ index │ singular_value │
├───────┼────────────────┤
│   1   │    0.125439    │
│   2   │   0.00125848   │
└───────┴────────────────┘
```

Running [`dsge bayes identification`](@ref ref-dsge-bayes-identification) evaluates the Iskrev (2010) moment-Jacobian column rank (`rank = 2` for `n_params = 2`, `identified = true`, singular values `0.125439` and `0.00125848`) directly around the calibrated `@dsge` baseline without consuming priors (`identification_diagnostics`, `singular_values`), so you can confirm identifiability before switching to a Bayesian estimation card and launching expensive SMC/MH chains.

---

## Common Pitfalls

1. **Passing `--config`, mixing `priors:` with `constraints:`, or putting `priors:` on `bayes identification`:** No `dsge` leaf takes `--config`. Place priors above `@dsge` (for sampling commands such as `prior-predictive`, `posterior-mode`, and `estimate`) or pass repeatable `--prior`/`--constraint` flags and `--priors`/`--constraints` TOML files—never combine `priors:` and `constraints:` in one `.jl` file, and omit `priors:` when running `dsge bayes identification` ([DSGE Specs, Priors & OccBin Constraints](@ref cfg-dsge)).
2. **Omitting `[t]` timing or writing `E[t](...)`:** Bare symbols or `(+1)`/`(-1)` syntax trigger `config/invalid` (exit `4`); index every endogenous variable by `[t]`, `[t-1]`, or `[t+1]` and exogenous shocks strictly by `[t]`.
3. **Stochastic singularity (`model/stochastic-singularity`, exit `5`) in Bayesian estimation:** When `--observables` lists more data series than structural shocks in `exogenous:`, either add measurement error (`--measurement-error auto` / explicit values) or reduce the observable subset.

---

## References

- Sims, C. A. (2002). Solving linear rational expectations models. *Computational Economics*, 20(1), 1–20.
- Guerrieri, L., & Iacoviello, M. (2015). OccBin: A toolkit for solving dynamic models with occasionally binding constraints. *Journal of Monetary Economics*, 70, 22–38.
- Herbst, E. P., & Schorfheide, F. (2015). *Bayesian Estimation of DSGE Models*. Princeton University Press.
- Upstream manual: [MacroEconometricModels.jl — DSGE](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/dsge/)
- CLI reference: [`friedman dsge`](@ref ref-dsge), [`friedman dsge solve`](@ref ref-dsge-solve), [`friedman dsge bayes estimate`](@ref ref-dsge-bayes-estimate), [`friedman dsge determinacy-map`](@ref ref-dsge-determinacy-map)
