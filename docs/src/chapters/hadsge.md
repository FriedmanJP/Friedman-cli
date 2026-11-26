# [Heterogeneous-Agent, CT & OLG Models](@id chap-hadsge)

Models with uninsured idiosyncratic income risk, borrowing constraints, wealth distributions, finite lifetimes, and firm/bank heterogeneity live across [`frdc hadsge`](@ref ref-hadsge) (`HouseholdSystem` general sequence-space and Reiter/Krusell–Smith models) and the six specialized heterogeneous/overlapping/corporate/banking families under `dsge`: `ct` (continuous-time Huggett/Aiyagari/two-asset HANK), `olg` (Blanchard perpetual-youth OLG), `dcegm` (discrete-continuous EGM), `lifecycle` (finite-horizon incomplete-markets life cycle), `firm` (Khan–Thomas non-convex investment), and `bank` (heterogeneous banks). See [MacroEconometricModels.jl — Heterogeneous Agents](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/ha/).

## Quick Start

Load a `HouseholdSystem` example via `MacroEconometricModels.load_ha_example(:huggett)` inside a `.jl` file, compute its stationary wealth distribution and market-clearing interest rate via [`hadsge steady-state`](@ref ref-hadsge-steady-state), and solve general-equilibrium dynamics via sequence-space Jacobians (`--method ssj`):

<!-- capture -->
```bash
cat > ha_huggett.jl <<'EOF'
MacroEconometricModels.load_ha_example(:huggett)
EOF
frdc hadsge solve ha_huggett.jl --method ssj --n-reduced 10 --t-horizon 100
```
```text
HA-DSGE Solve Diagnostics (method=ssj)
┌────────────────────┬───────┐
│       metric       │ value │
├────────────────────┼───────┤
│       method       │  ssj  │
│   n_full_states    │  100  │
│     n_reduced      │  10   │
│ explained_variance │  1.0  │
│      obs_rows      │   1   │
│      obs_cols      │  10   │
└────────────────────┴───────┘
HA Steady-State Aggregates
┌───────────────┬───────┐
│     name      │ value │
├───────────────┼───────┤
│   K_demand    │ 0.000 │
│   A_policy    │ 0.000 │
│  A_residual   │ 0.000 │
│       K       │ 0.000 │
│       Y       │ 0.883 │
│ excess_demand │ 0.000 │
└───────────────┴───────┘
HA Steady-State Prices
┌──────┬────────┐
│ name │ value  │
├──────┼────────┤
│  w   │ 1.000  │
│  r   │ -0.013 │
└──────┴────────┘
HA Steady-State Diagnostics
┌───────────────┬────────┐
│    metric     │ value  │
├───────────────┼────────┤
│   converged   │ 1.000  │
│  iterations   │ 28.000 │
│  euler_error  │ -1.936 │
│ excess_demand │ 0.000  │
└───────────────┴────────┘
                 HA Euler Accuracy (log10, by convention)
┌────────────┬────────┬────────┬─────────────┬───────────────┬───────────┐
│ convention │  max   │  mean  │ n_evaluated │ n_constrained │ n_offgrid │
├────────────┼────────┼────────┼─────────────┼───────────────┼───────────┤
│ midpoints  │ -1.936 │ -4.540 │     584     │      14       │     0     │
│   nodes    │ -4.470 │ -5.656 │     585     │      15       │     0     │
└────────────┴────────┴────────┴─────────────┴───────────────┴───────────┘
```

The command outputs `ha_dsge_solve_diagnostics` (`explained_variance = 1.0`, `n_reduced = 10`), `ha_steady_state_aggregates` (`Y = 0.882609`, `excess_demand = -5.91356e-9`), `ha_steady_state_prices` (`r = -0.0130703`), `ha_steady_state_diagnostics` (`28.0` iterations), and Euler equation residuals (`ha_euler_accuracy_log10_by_convention`, midpoint max `-1.93627` vs node max `-4.46995`).

---

## Sequence-Space HA (`hadsge`)

Auclert–Bardóczy–Rognlie–Straub sequence-space Jacobians (SSJ) compute linear general-equilibrium impulse responses directly around the stationary cross-sectional distribution $D_{ss}$ without reducing state heterogeneity to moments:

```math
H_t(\mathbf{X}, \mathbf{Z}) = 0 \implies d\mathbf{X} = -\mathcal{H}_{\mathbf{X}}^{-1}\mathcal{H}_{\mathbf{Z}} \, d\mathbf{Z},
```

where household blocks propagate backward via Endogenous Grid Method (`--hh-solver egm|vfi`) and forward along Young (`young`) or Winberry (`winberry`) histogram/polynomial distributions (`--distribution`).

| `hadsge` Command | Capabilities & Options | Output Tables (`--format json`) |
|---|---|---|
| [`steady-state`](@ref ref-hadsge-steady-state), [`solve`](@ref ref-hadsge-solve) | Stationary equilibrium (`--euler-points midpoints\|nodes`) and GE solution (`--method ssj\|reiter\|krusell-smith`, `--n-reduced`, `--t-horizon`) | `ha_steady_state_*`, `ha_dsge_solve_diagnostics`, `krusell_smith_plm_coefficients` |
| [`irf`](@ref ref-hadsge-irf), [`fevd`](@ref ref-hadsge-fevd), [`hd`](@ref ref-hadsge-hd) | Aggregate impulse responses, variance shares, and historical decompositions | `ha_dsge_irf`, `ha_dsge_fevd`, `ha_historical_decomposition` |
| [`distribution-irf`](@ref ref-hadsge-distribution-irf), [`inequality-irf`](@ref ref-hadsge-inequality-irf) | Dynamic evolution of wealth/consumption quantiles, Gini, and Top-10% share (`--shock-index`, `--shock-size`) | `ha_distribution_irf`, `ha_inequality_irf` |
| [`simulate`](@ref ref-hadsge-simulate), [`simulate-panel`](@ref ref-hadsge-simulate-panel), [`accuracy`](@ref ref-hadsge-accuracy) | Aggregate macro simulation, household panel (`--n-agents`), and Den Haan accuracy audit | `ha_dsge_simulation`, `ha_panel_simulation_summary`, `den_haan_accuracy` |
| [`estimate`](@ref ref-hadsge-estimate) | Full Bayesian SSJ/Reiter estimation via MH or SMC (`--sampler mh\|smc`, `--prior`) | `ha_dsge_bayesian_posterior`, `ha_dsge_bayesian_settings` |

Cross-check sequence-space fiscal and monetary transmission directly with `policy jacobian ha` and `policy news ha` in [Policy Counterfactuals & Optimal Policy](@ref chap-policy).

---

## Continuous-Time HA, OLG, Life-Cycle, Firm & Bank Models (`dsge ct|olg|...`)

Six built-in structural families under [`frdc dsge`](@ref ref-dsge) require minimal or zero external model files, parameterizing grids and preferences directly via flags:

```math
\rho V(a, z) = u(c^*) + \partial_a V(a, z)(r a + w z - c^*) + \sum_{z'\neq z}\lambda_{z z'}\left[V(a, z') - V(a, z)\right].
```

- **Continuous-Time HACT / Two-Asset HANK ([`dsge ct`](@ref ref-fam-dsge-ct)):** Upwind finite-difference HJB + Kolmogorov forward equation (`solve`, `irf`, `fevd`, `transition`); pass `--two-asset` and `--ge` for Kaplan–Moll–Violante liquid/illiquid portfolio dynamics.
- **Perpetual-Youth OLG ([`dsge olg`](@ref ref-fam-dsge-olg)):** Blanchard–Yaari overlapping generations with optional public debt (`--debt`, survival `--gamma`) and New Keynesian block (`--nk`).
- **Discrete-Continuous & Life-Cycle ([`dsge dcegm`](@ref ref-fam-dsge-dcegm), [`dsge lifecycle`](@ref ref-fam-dsge-lifecycle)):** Iskhakov–Rust–Schjerning upper-envelope DC-EGM with retirement/work choice (`--work-option`), kinks, and finite-horizon overlapping-generations transitions (`--j`, `--j-retire`, `--no-annuities`).
- **Non-Convex Firms & Heterogeneous Banks ([`dsge firm`](@ref ref-fam-dsge-firm), [`dsge bank`](@ref ref-fam-dsge-bank)):** Khan–Thomas $(S,s)$ capital adjustment (`steady-state`, `irf`, `transition`) and Bewley heterogeneous-bank partial/general equilibrium (`steady-state`, `pe`, `irf`, `transition`).

<!-- capture -->
```bash
frdc dsge olg solve --alpha 0.36 --beta 0.96 --delta 0.08 --gamma 0.98 --debt 0.2
frdc dsge ct solve --grid-size 25 --max-iter 40 --a-max 20.0
```
```text
CT Aiyagari Prices
┌──────┬───────┐
│ name │ value │
├──────┼───────┤
│  r   │ 0.040 │
│  w   │ 1.399 │
└──────┴───────┘
CT Aiyagari Aggregates
┌───────────┬───────┐
│   name    │ value │
├───────────┼───────┤
│     K     │ 1.316 │
│     L     │ 0.150 │
│ converged │ 1.000 │
└───────────┴───────┘
```

The continuous-time solver iterates the upwind HJB–KFE fixed point to print `ct_aiyagari_prices` (`r = 0.0396901`, `w = 1.39856`) and `ct_aiyagari_aggregates` (`K = 1.31568`, `converged = 1.0`).

---

## Common Pitfalls

1. **Passing a `HouseholdSystem` file to `dsge solve` or vice versa:** Representative-agent [`dsge solve`](@ref ref-dsge-solve) rejects `HouseholdSystem` models (`usage/wrong-command`, exit `2`) pointing to [`hadsge solve`](@ref ref-hadsge-solve); conversely `hadsge` rejects representative-agent `@dsge` specs.
2. **Keeping default `--n-reduced 30` on `reiter` distribution-IRFs with coarse `--t-horizon`:** Use `--method ssj` when only aggregate Jacobians and IRFs are required; reserve `reiter` with Winberry/Young polynomial reduction for distributional/inequality moments and keep grids balanced relative to computing budget.
3. **Mixing `--two-asset` continuous-time grids with coarse `--max-iter`:** Two-asset Kaplan–Moll–Violante GE loops take substantially more upwind sweeps than one-asset Aiyagari (`--two-asset` absent); increase `--max-iter` when checking convergence diagnostics.

---

## References

- Auclert, A., Bardóczy, B., Rognlie, M., & Straub, L. (2021). Using the sequence-space Jacobian to solve and estimate heterogeneous-agent models. *Econometrica*, 89(5), 2375–2408.
- Achdou, Y., Han, J., Lasry, J.-M., Lions, P.-L., & Moll, B. (2022). Income and wealth distribution in macroeconomics: A continuous-time approach. *Review of Economic Studies*, 89(1), 45–86.
- Khan, A., & Thomas, J. K. (2008). Idiosyncratic shocks and the role of nonconvexities in plant and aggregate investment dynamics. *Econometrica*, 76(2), 395–436.
- Upstream manual: [MacroEconometricModels.jl — Heterogeneous Agents](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/ha/)
- CLI reference: [`frdc hadsge`](@ref ref-hadsge), [`frdc dsge ct`](@ref ref-fam-dsge-ct), [`frdc dsge olg`](@ref ref-fam-dsge-olg), [`frdc dsge dcegm`](@ref ref-fam-dsge-dcegm), [`frdc dsge lifecycle`](@ref ref-fam-dsge-lifecycle), [`frdc dsge firm`](@ref ref-fam-dsge-firm), [`frdc dsge bank`](@ref ref-fam-dsge-bank)
