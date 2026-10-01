# HA-DSGE workflow

Heterogeneous-agent DSGE from the terminal: stationarity, linearization (SSJ / Reiter / Krusell–Smith), aggregate and distributional IRFs, and panel simulation. Builtins ship with MacroEconometricModels — no model file required to start.

Option tables: [generated `dsge` reference](generated/dsge.md). Representative-agent DSGE (gensys, OccBin, bayes): [dsge guide](dsge.md).

---

## Goal

Compute a stationary equilibrium for a small incomplete-markets economy, solve a linear HA system, inspect aggregate and distributional impulse responses, and summarize a simulated agent panel.

---

## Builtins

| Token | Model | Notes |
|-------|--------|--------|
| `huggett` | Huggett (1993) | Smallest; start here |
| `krusell-smith` | Krusell–Smith (1998) | Aggregate capital PLM |
| `one-asset-hank` | One-asset HANK | Medium |
| `two-asset-hank` | Two-asset HANK | Largest |
| `endogenous-labor` | Endogenous labour (GHH / separable) | Labour-margin variant |
Any of these tokens may be written with a leading colon (`:huggett`). A `.jl` file that evaluates to a heterogeneous-agent `ModelSpec` (household population) is also accepted.

### Custom models from a `.jl` file

An HA spec file is an `@dsge begin … end` block carrying the three heterogeneous-agent
declarations. The file needs no `using MacroEconometricModels` of its own — the loader
evaluates it in a sandbox where the package's exports are already in scope:

```julia
@dsge begin
    parameters: alpha = 0.36, beta_hh = 0.96, delta = 0.025, rho_z = 0.95, sigma_z = 0.007
    endogenous: Y, K, r, w, Z
    exogenous: eps_Z

    heterogeneous: a in [0.0, 400.0],
                   n_grid = 60,
                   utility = log,
                   discount = beta_hh,
                   borrowing = 0.0
    idiosyncratic: e ~ Rouwenhorst(0.966, 0.5, 5)
    aggregation: K = sum(a)

    Y[t] = Z[t] * K[t-1]^alpha
    r[t] = alpha * Z[t] * K[t-1]^(alpha-1) - delta
    w[t] = (1 - alpha) * Z[t] * K[t-1]^alpha
    Z[t] = rho_z * Z[t-1] + sigma_z * eps_Z[t]
end
```

`heterogeneous:` is one Julia statement, so it can be broken across lines — the
continuation lines are aligned under the first argument, with the commas kept
at the end of each line. Written on one line it is equally valid; use
whichever reads better.

**A TOML encoding of an HA model is not a model card.** A
[model card](../configuration.md#model-cards-and-toml-files) has exactly seven
stanza headers, and none of them declares a household: there is no `model:` or
`heterogeneous:` header, and no TOML section expresses one either. The
heterogeneous-agent declarations stay inside `@dsge`, and a model card
preamble above the block is accepted for the `priors:` stanza the `hadsge
estimate` leaf reads. Writing `heterogeneous:` into a card is a typed
`config/invalid` naming the line.

Pass the file path where a builtin token would go (for example `friedman hadsge steady-state mymodel.jl`).

Set `a in [0.0, a_max]` generously. If too much of the stationary distribution piles up at
`a_max`, the asset market does not really clear and `excess_demand` cannot detect it,
because it is measured on the clamped aggregate; the library warns about this on stderr, and
the warning is worth acting on rather than ignoring.

The loader evaluates the file in a sandbox where the package exports are already in scope,
so the file needs no `using` line of its own. A file that cannot be evaluated is a typed
`config/invalid` (exit 4); a file that evaluates to anything other than a `ModelSpec`
carrying a `HouseholdSystem` is `usage/wrong-command` (exit 2), pointing at the other DSGE
node. Written aggregate equations are compiled into the spec; `E[t](...)` is a typed
`config/invalid` — write the lead directly.

---

## Method choice

| `--method` | Use when | Aggregate IRF/FEVD/sim | Distribution / inequality IRF |
|------------|----------|------------------------|-------------------------------|
| `ssj` | Sequence-space Jacobians; default for `solve` | yes | no (no distribution basis) |
| `reiter` | Linearized distribution + aggregates | yes | **yes** (Reiter only) |
| `krusell-smith` | PLM fixed point for capital | no linear IRF path | no |

`--n-reduced` controls the reduced distribution dimension for SSJ/Reiter (use a small value interactively; larger for accuracy).

---

## 1. Stationary equilibrium

Start with the Huggett builtin. Status lines go to stderr; JSON below is stdout only.

<!-- capture -->
```bash
friedman hadsge steady-state huggett --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "ha_steady_state_aggregates": {
            "columns": [
                "name",
                "value"
            ],
            "rows": [
                [
                    "K_demand",
                    0
                ],
                [
                    "A_policy",
                    -5.9135575e-9
                ],
                [
                    "A_residual",
                    0
                ],
                [
                    "K",
                    -5.9135573e-9
                ],
                [
                    "Y",
                    0.8826087
                ],
                [
                    "excess_demand",
                    -5.9135573e-9
                ]
            ]
        },
        "ha_steady_state_prices": {
            "columns": [
                "name",
                "value"
            ],
            "rows": [
                [
                    "w",
                    1
                ],
                [
                    "r",
                    -0.013070272
                ]
            ]
        },
        "ha_steady_state_diagnostics": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "converged",
                    1
                ],
                [
                    "iterations",
                    28
                ],
                [
                    "euler_error",
                    -1.9362687
                ],
                [
                    "excess_demand",
                    -5.9135573e-9
                ]
            ]
        },
        "ha_euler_accuracy_log10_by_convention": {
            "columns": [
                "convention",
                "max",
                "mean",
                "n_evaluated",
                "n_constrained",
                "n_offgrid"
            ],
            "rows": [
                [
                    "midpoints",
                    -1.9362687,
                    -4.5398656,
                    584,
                    14,
                    0
                ],
                [
                    "nodes",
                    -4.4699492,
                    -5.6558001,
                    585,
                    15,
                    0
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman hadsge steady-state",
    "meta": {
    },
    "error": null
}
```

**Interpretation.** Envelope `status` is `ok`. Tables under `data` report prices (`w`, `r`), aggregates (`Y`, `K`, …), and diagnostics (`converged`, `iterations`, `euler_error`, `excess_demand`). A near-zero excess demand and `converged = 1` indicate a successful fixed point.

### Euler accuracy and `--euler-points`

`euler_error` is `log10` of the maximum Euler residual — `-2` means about 1%, `-4` about
0.01%; more negative is better. It is a maximum over *unconstrained* points only, since the
Euler equation holds with inequality where the borrowing constraint binds.

**Where the residual is measured changes it by orders of magnitude.** EGM solves the Euler
equation essentially exactly *at the grid nodes*, so evaluating there scores the solver
rather than the approximation. Measuring off-node, at the cell midpoints, exposes the
interpolation error that a user of the policy function actually incurs:

```bash
friedman hadsge steady-state huggett                       # midpoints (default)
friedman hadsge steady-state huggett --euler-points nodes  # the older convention
```

On `huggett` the same steady state reports `-1.94` at midpoints and `-4.47` at nodes (both
visible in the capture above) — a gap of 2.5 log₁₀ units, i.e. the node figure is
optimistic by a factor of about 300.

Because that gap is so wide, the `Euler Accuracy` table reports **both** conventions
regardless of which one you select, with `n_evaluated` / `n_constrained` / `n_offgrid`
alongside. `--euler-points` selects only which of the two the scalar `euler_error`
diagnostic reports.

!!! warning "Comparing against published numbers"
    Older published figures use the **node** convention, which is now the non-default.
    Check which convention a number came from before comparing; `midpoints` looks
    dramatically worse for the same solution without anything having got worse. The
    capture above exists so the comparison can always be made on like terms.

---

## 2. Solve (Reiter)

Linearize with a small reduced basis for a fast interactive solve.

<!-- capture -->
```bash
friedman hadsge solve huggett --method reiter --n-reduced 8 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "ha_steady_state_aggregates": {
            "columns": [
                "name",
                "value"
            ],
            "rows": [
                [
                    "K_demand",
                    0
                ],
                [
                    "A_policy",
                    -5.9135575e-9
                ],
                [
                    "A_residual",
                    0
                ],
                [
                    "K",
                    -5.9135573e-9
                ],
                [
                    "Y",
                    0.8826087
                ],
                [
                    "excess_demand",
                    -5.9135573e-9
                ]
            ]
        },
        "ha_steady_state_prices": {
            "columns": [
                "name",
                "value"
            ],
            "rows": [
                [
                    "w",
                    1
                ],
                [
                    "r",
                    -0.013070272
                ]
            ]
        },
        "ha_dsge_solve_diagnostics": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "method",
                    "reiter"
                ],
                [
                    "n_full_states",
                    "600"
                ],
                [
                    "n_reduced",
                    "8"
                ],
                [
                    "explained_variance",
                    "0.9999999999994043"
                ],
                [
                    "obs_rows",
                    "9"
                ],
                [
                    "obs_cols",
                    "9"
                ]
            ]
        },
        "ha_steady_state_diagnostics": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "converged",
                    1
                ],
                [
                    "iterations",
                    28
                ],
                [
                    "euler_error",
                    -1.9362687
                ],
                [
                    "excess_demand",
                    -5.9135573e-9
                ]
            ]
        },
        "ha_euler_accuracy_log10_by_convention": {
            "columns": [
                "convention",
                "max",
                "mean",
                "n_evaluated",
                "n_constrained",
                "n_offgrid"
            ],
            "rows": [
                [
                    "midpoints",
                    -1.9362687,
                    -4.5398656,
                    584,
                    14,
                    0
                ],
                [
                    "nodes",
                    -4.4699492,
                    -5.6558001,
                    585,
                    15,
                    0
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman hadsge solve",
    "meta": {
    },
    "error": null
}
```

**Interpretation.** Diagnostics name the method (`reiter`) and reduced dimension. Aggregates/prices match the steady-state block above up to solver noise. For production runs, raise `--n-reduced` above the small interactive value used here; option defaults live in the [generated reference](generated/dsge.md).

---

## 3. Aggregate IRF

Impulse responses on the linearized aggregate system (Reiter or SSJ).

```bash
friedman hadsge irf huggett --method reiter --n-reduced 8 --horizon 5 --format json
```

**Interpretation.** The IRF table stacks horizons × observables for each aggregate shock. The short horizon above keeps the output compact; typical analysis uses longer horizons. `--method krusell-smith` is rejected here (exit 2) — a PLM is not a linear state space.

Related:

```bash
friedman hadsge fevd huggett --method reiter --n-reduced 8 --horizon 40
friedman hadsge simulate huggett --method reiter --n-reduced 8 --periods 200 --seed 1
```

---

## 4. Distribution and inequality IRFs (Reiter only)

Wealth-distribution mass deviations and Gini / percentile paths require Reiter’s distribution basis. SSJ returns a usage error for these leaves.

```bash
friedman hadsge distribution-irf huggett --method reiter --n-reduced 8 --horizon 40
friedman hadsge inequality-irf huggett --method reiter --n-reduced 8 --horizon 40
```

Use `--shock-index` / `--shock-size` to pick the aggregate shock and scale.

---

## 5. Panel simulation

Draw individual asset paths from steady-state policies (no linearization method required).

```bash
friedman hadsge simulate-panel huggett --n-agents 100 --periods 20 --seed 1 --format json
```

**Interpretation.** The panel summary tracks mean and dispersion of asset holdings over time for the requested agent count. Fix `--seed` for reproducibility.

---

## Continuous-time HA and Blanchard OLG

Sibling nodes for continuous-time Aiyagari (optional two-asset KMV via `--two-asset`, with
general equilibrium under `--two-asset --ge`) and perpetual-youth OLG:

```bash
friedman dsge ct solve --format json
friedman dsge ct transition --periods 40 --shock-size 0.95 --dt 0.25
friedman dsge olg solve --format json
friedman dsge olg simulate --horizon 50
```

Keep the leaf default grid size; never go below 16 — coarser asset grids fail inside the
Linux sparse factorisation rather than merely losing accuracy. See the [dsge guide](dsge.md#continuous-time-ha-dsge-ct--c041) for options.

---

## 6. Bayesian estimation

`hadsge estimate` estimates HA-DSGE parameters with the posterior sampler (`--sampler mh|smc`, RWMH or SMC). Each posterior draw **re-solves the full HA model** (steady state → linearization → Kalman likelihood), the Auclert-Bardóczy-Rognlie-Straub (2021) "offline" approach — so keep `--n-draws` modest and prefer small `--n-reduced` / `--t-horizon` while prototyping.

Priors live in a `[priors]` TOML; the two numbers are the distribution's constructor args (`normal` → mean, sd). Create both files inside the same block before estimating (prototype draw counts shown):

```bash
cat > priors.toml <<'EOF'
[priors]
[priors.alpha]
dist = "normal"
a = 0.36
b = 0.05
EOF
awk 'BEGIN{print "K"; for(i=1;i<=350;i++) print 1+0.01*i}' > aggregates.csv
friedman hadsge estimate krusell-smith \
  --data aggregates.csv --priors priors.toml \
  --observables K --method ssj \
  --n-draws 2000 --burnin 500 --t-horizon 300 --n-reduced 15 \
  --seed 1 --format json
```

Output is a posterior summary table (`mean`, `std`, `q05`, `median`, `q95` per parameter); the acceptance rate and effective draw count go to stderr. `--measurement-error auto` adds per-observable measurement error at 10% of each series' variance (needed when observables exceed structural shocks). `--method krusell-smith` is rejected — the Kalman filter needs a linear state space, so use `ssj` or `reiter`.

---

## Solution accuracy: `hadsge accuracy`

Den Haan (2010) accuracy of the aggregate law of motion. The law is only an approximation of
the true aggregate dynamics, and this is the standard way to score how far the two drift
apart: it simulates the economy twice from the same shocks — once tracking the full
cross-sectional distribution (the *reference* path) and once letting the law forecast the
aggregate on its own — and reports the percentage deviation between them.

```bash
friedman hadsge accuracy krusell-smith --t-sim 10000 --t-burn 1000
friedman hadsge accuracy krusell-smith --method reiter --t-fit 4000
```

Full option list (simulation lengths, shock persistence and scale, seed, plot flags) lives in the [generated reference](generated/dsge.md). `--t-sim` must exceed `--t-burn` by at least 10, and `--t-fit` (linearized methods only) must exceed 100 — both are guarded as `usage/invalid`.

**Output:** `dh_max` and `dh_mean` (maximum and mean percentage deviation — smaller is
better), the two simulation standard deviations `sigma_ref`/`sigma_plm`, the full reference
and law-only aggregate paths as a second table, and the simulation settings (which record
the method that produced the number).

Two different laws can be scored. Under `krusell-smith` it is the *fitted* perceived law of
motion. Under `ssj`/`reiter` there is no PLM, so the implied law is **recovered by regression**
from a `--t-fit`-period simulation of the linearized solution.

!!! warning "Do not compare across methods"
    The linearized statistic is much larger than the Krusell–Smith one and is
    method-dependent. Upstream measures `dh_max` at 0.07% for the fitted Krusell–Smith PLM
    against **12.2% for `ssj` and 5.5% for `reiter`** — two solutions of the *same* model
    differing by more than a factor of two.

    Three errors are superimposed and this statistic does not separate them: a two-state
    aggregate law, linearization around the steady state, and a law recovered by regression
    rather than fitted as a fixed point. Treat it as a **relative** diagnostic — same model,
    same `sigma_z`, `--t-sim` and `--seed`, comparing a solution against itself under
    different settings — not as an absolute accuracy certificate.

    `sigma_ref` vs `sigma_plm` is the more interpretable output, and is the actual Den Haan
    point: a high solution `R²` routinely hides a volatility miss.

**Undefined for `huggett`.** Its clearing rate is driven by the wealth distribution rather
than the aggregate shock alone, so a meaningful test there needs a distribution-augmented
law. The CLI refuses before running the (expensive) solve rather than after it.

---

## Upstream feature coverage (audit)

Upstream ships a block of heterogeneous-agent / OLG / continuous-time features. Not all of
them warrant CLI surface; this records where each stands, so the absence of a command is a
decision rather than an oversight.

| Upstream feature | Status in the CLI |
|---|---|
| Den Haan accuracy | **Exposed** as `hadsge accuracy` (above), for all three solution methods |
| Winberry parametric distribution dynamics | Reachable via `--distribution winberry` on the existing `hadsge` leaves; note the library's convergence flag is scale-relative, and its four-moment basis is not numerically portable across platforms — do not compare that flag between machines |
| SSJ DAG / second-order SSJ | **Deferred.** Block-composition types (`SimpleBlock`/`HetBlock`/`SSJModel`) are a model-*construction* API. Exposing them means a config schema for wiring blocks, which is a design task in its own right, not an option on an existing leaf |
| DCEGM (discrete–continuous choice) | **Exposed** as `dsge dcegm` (solve, steady-state, irf, fevd, simulate, transition); see the [generated reference](generated/dsge.md) |
| Life-cycle OLG (age-EGM) | **Exposed** as `dsge lifecycle` (steady-state, transition, irf, fevd, simulate); see the [generated reference](generated/dsge.md) |
| Endogenous labour (GHH / separable) | **Exposed** as the `endogenous-labor` builtin (above) |
| Adaptive Smolyak / adaptive grids | **No new surface.** Grid construction is internal to solving; the existing `--n-reduced` already governs the accuracy/cost trade-off users actually tune |
| KMV two-asset GE + MIT transitions | **Exposed** as `dsge ct solve --two-asset [--ge]` and `dsge ct transition --z-path`; see the [generated reference](generated/dsge.md) |

Deferred rows are gated on a concrete use case rather than on upstream — the methods exist
today and can be reached from Julia directly.

Two related items settled with the same audit:

- **Euler-error convention.** Surfaced as `--euler-points midpoints|nodes` on
  `hadsge steady-state`, and both statistics are reported unconditionally from
  `HASteadyState.euler`. See [Euler accuracy](#Euler-accuracy-and---euler-points).
- **HA `.jl` loader.** Loads through the same helper as `hadsge accuracy`.
  See [Custom models from a `.jl` file](#Custom-models-from-a-.jl-file).

---

## Pitfalls

1. **Distribution / inequality IRF with SSJ** — fails closed; switch to `--method reiter`.
2. **Large builtins** — `two-asset-hank` is expensive; prototype on `huggett`.
3. **Agent contract** — with `--format json`, stdout is one envelope; status is stderr ([Agent Guide](../agent-guide.md)).
4. **Wrong command for HA specs** — a `.jl` file with one `HouseholdSystem` under `dsge solve|irf|…` raises `usage/wrong-command` (exit 2) pointing at `hadsge solve`. Conversely, a representative-agent spec under `hadsge` is rejected the same way.
5. **Coarse CT grids** — keep the leaf default grid size and never go below 16; smaller grids fail in the Linux sparse factorisation.

---

## References

- Generated options: [`dsge` reference](generated/dsge.md)
- Representative-agent DSGE: [dsge guide](dsge.md)
- MEMs HA docs: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/)
