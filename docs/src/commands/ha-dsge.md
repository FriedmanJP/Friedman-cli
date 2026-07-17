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
| `huggett` | Huggett (1993) | Smallest; preferred for CI and quick starts |
| `krusell-smith` | Krusell–Smith (1998) | Aggregate capital PLM |
| `one-asset-hank` | One-asset HANK | Medium |
| `two-asset-hank` | Two-asset HANK | Largest |

Any of these tokens may be written with a leading colon (`:huggett`). A `.jl` file that evaluates to `HADSGESpec` is also accepted.

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
friedman dsge ha steady-state huggett --format json
```
```json
{
    "meta": {
    },
    "error": null,
    "status": "ok",
    "command": "friedman dsge ha steady-state",
    "data": {
        "ha_steady_state_diagnostics": {
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
                    -4.4699492
                ],
                [
                    "excess_demand",
                    -5.913559e-9
                ]
            ],
            "columns": [
                "metric",
                "value"
            ]
        },
        "ha_steady_state_prices": {
            "rows": [
                [
                    "w",
                    1
                ],
                [
                    "r",
                    -0.013070272
                ]
            ],
            "columns": [
                "name",
                "value"
            ]
        },
        "ha_steady_state_aggregates": {
            "rows": [
                [
                    "K_demand",
                    0
                ],
                [
                    "K",
                    -5.913559e-9
                ],
                [
                    "Y",
                    0.8826087
                ],
                [
                    "excess_demand",
                    -5.913559e-9
                ]
            ],
            "columns": [
                "name",
                "value"
            ]
        }
    },
    "warnings": [
    ],
    "schema_version": 1,
    "artifacts": [
    ]
}
```

**Interpretation.** Envelope `status` is `ok`. Tables under `data` report prices (`w`, `r`), aggregates (`Y`, `K`, …), and diagnostics (`converged`, `iterations`, `euler_error`, `excess_demand`). A near-zero excess demand and `converged = 1` indicate a successful fixed point.

---

## 2. Solve (Reiter)

Linearize with a small reduced basis for a fast interactive solve.

<!-- capture -->
```bash
friedman dsge ha solve huggett --method reiter --n-reduced 8 --format json
```
```json
{
    "meta": {
    },
    "error": null,
    "status": "ok",
    "command": "friedman dsge ha solve",
    "data": {
        "ha_dsge_solve_diagnostics_method_reiter": {
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
                    "0.9999999999994282"
                ],
                [
                    "obs_rows",
                    "9"
                ],
                [
                    "obs_cols",
                    "9"
                ]
            ],
            "columns": [
                "metric",
                "value"
            ]
        },
        "ha_steady_state_diagnostics": {
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
                    -4.4699492
                ],
                [
                    "excess_demand",
                    -5.913559e-9
                ]
            ],
            "columns": [
                "metric",
                "value"
            ]
        },
        "ha_steady_state_prices": {
            "rows": [
                [
                    "w",
                    1
                ],
                [
                    "r",
                    -0.013070272
                ]
            ],
            "columns": [
                "name",
                "value"
            ]
        },
        "ha_steady_state_aggregates": {
            "rows": [
                [
                    "K_demand",
                    0
                ],
                [
                    "K",
                    -5.913559e-9
                ],
                [
                    "Y",
                    0.8826087
                ],
                [
                    "excess_demand",
                    -5.913559e-9
                ]
            ],
            "columns": [
                "name",
                "value"
            ]
        }
    },
    "warnings": [
    ],
    "schema_version": 1,
    "artifacts": [
    ]
}
```

**Interpretation.** Diagnostics name the method (`reiter`) and reduced dimension. Aggregates/prices match the steady-state block above up to solver noise. For production runs, raise `--n-reduced` (default 30).

---

## 3. Aggregate IRF

Impulse responses on the linearized aggregate system (Reiter or SSJ).

<!-- capture -->
```bash
friedman dsge ha irf huggett --method reiter --n-reduced 8 --horizon 5 --format json
```
```json
{
    "meta": {
    },
    "error": null,
    "status": "ok",
    "command": "friedman dsge ha irf",
    "data": {
        "ha_dsge_irf_shock_epsilon_method_reiter_h_5": {
            "rows": [
                [
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0
                ],
                [
                    1,
                    0.00011352359,
                    0.00039011323,
                    0.00032736955,
                    -0.0017093784,
                    2.3099145e-5,
                    0.00051854147,
                    -0.00021961882,
                    0.00057375851,
                    1
                ],
                [
                    2,
                    0.00017924288,
                    0.00061151741,
                    0.00047777205,
                    -0.0024747127,
                    0.00013533925,
                    0.0002728106,
                    1.6736213e-5,
                    0.0003966407,
                    0.9
                ],
                [
                    3,
                    0.00020299653,
                    0.00068884024,
                    0.00051007232,
                    -0.0026145215,
                    7.1739359e-5,
                    -0.00028695039,
                    2.9265911e-5,
                    0.00034358471,
                    0.81
                ],
                [
                    4,
                    0.0002036366,
                    0.0006886159,
                    0.00049284669,
                    -0.0025114572,
                    -0.00016252479,
                    -0.00068615162,
                    0.00011802344,
                    0.00032973828,
                    0.729
                ]
            ],
            "columns": [
                "horizon",
                "x_1",
                "x_2",
                "x_3",
                "x_4",
                "x_5",
                "x_6",
                "x_7",
                "x_8",
                "x_9"
            ]
        }
    },
    "warnings": [
    ],
    "schema_version": 1,
    "artifacts": [
    ]
}
```

**Interpretation.** The IRF table stacks horizons × observables for each aggregate shock. Horizon here is short (`5`) for a compact capture; typical analysis uses the default (`40`).

Related:

```bash
friedman dsge ha fevd huggett --method reiter --n-reduced 8 --horizon 40
friedman dsge ha simulate huggett --method reiter --n-reduced 8 --periods 200 --seed 1
```

---

## 4. Distribution and inequality IRFs (Reiter only)

Wealth-distribution mass deviations and Gini / percentile paths require Reiter’s distribution basis. SSJ returns a usage error for these leaves.

```bash
friedman dsge ha distribution-irf huggett --method reiter --n-reduced 8 --horizon 40
friedman dsge ha inequality-irf huggett --method reiter --n-reduced 8 --horizon 40
```

Use `--shock-index` / `--shock-size` to pick the aggregate shock and scale.

---

## 5. Panel simulation

Draw individual asset paths from steady-state policies (no linearization method required).

<!-- capture -->
```bash
friedman dsge ha simulate-panel huggett --n-agents 100 --periods 20 --seed 1 --format json
```
```json
{
    "meta": {
    },
    "error": null,
    "status": "ok",
    "command": "friedman dsge ha simulate-panel",
    "data": {
        "ha_panel_simulation_summary_n_100_t_20": {
            "rows": [
                [
                    1,
                    -0.035992766,
                    0.73885762,
                    100
                ],
                [
                    2,
                    -0.030462912,
                    0.69384416,
                    100
                ],
                [
                    3,
                    -0.025137983,
                    0.66307689,
                    100
                ],
                [
                    4,
                    -0.010305077,
                    0.66949271,
                    100
                ],
                [
                    5,
                    -0.0010538745,
                    0.68262336,
                    100
                ],
                [
                    6,
                    0.021488586,
                    0.68257806,
                    100
                ],
                [
                    7,
                    0.063707879,
                    0.63921679,
                    100
                ],
                [
                    8,
                    0.046261666,
                    0.6428119,
                    100
                ],
                [
                    9,
                    0.061113696,
                    0.66001583,
                    100
                ],
                [
                    10,
                    0.037473753,
                    0.66600819,
                    100
                ],
                [
                    11,
                    0.050215433,
                    0.64892452,
                    100
                ],
                [
                    12,
                    -0.0051117798,
                    0.6838137,
                    100
                ],
                [
                    13,
                    0.0063927045,
                    0.704722,
                    100
                ],
                [
                    14,
                    0.0384567,
                    0.70135607,
                    100
                ],
                [
                    15,
                    0.074085061,
                    0.66855733,
                    100
                ],
                [
                    16,
                    0.10643318,
                    0.65086954,
                    100
                ],
                [
                    17,
                    0.13342213,
                    0.63093263,
                    100
                ],
                [
                    18,
                    0.16279669,
                    0.59830539,
                    100
                ],
                [
                    19,
                    0.15147237,
                    0.56102337,
                    100
                ],
                [
                    20,
                    0.12273524,
                    0.59750907,
                    100
                ]
            ],
            "columns": [
                "period",
                "mean_assets",
                "sd_assets",
                "n_agents"
            ]
        }
    },
    "warnings": [
    ],
    "schema_version": 1,
    "artifacts": [
    ]
}
```

**Interpretation.** The panel summary tracks mean (and related) asset holdings over time for `n-agents` agents. Fix `--seed` for reproducibility.

---

## Continuous-time HA and Blanchard OLG

Sibling nodes for continuous-time Aiyagari (optional two-asset KMV) and perpetual-youth OLG:

<!-- capture -->
```bash
friedman dsge ct solve --grid-size 50 --format json
```
```json
{
    "meta": {
    },
    "error": null,
    "status": "ok",
    "command": "friedman dsge ct solve",
    "data": {
        "ct_aiyagari_aggregates": {
            "rows": [
                [
                    "K",
                    1.2912617
                ],
                [
                    "L",
                    0.15
                ],
                [
                    "converged",
                    1
                ]
            ],
            "columns": [
                "name",
                "value"
            ]
        },
        "ct_aiyagari_prices": {
            "rows": [
                [
                    "r",
                    0.040771932
                ],
                [
                    "w",
                    1.3891603
                ]
            ],
            "columns": [
                "name",
                "value"
            ]
        }
    },
    "warnings": [
    ],
    "schema_version": 1,
    "artifacts": [
    ]
}
```

<!-- capture -->
```bash
friedman dsge olg solve --format json
```
```json
{
    "meta": {
    },
    "error": null,
    "status": "ok",
    "command": "friedman dsge olg solve",
    "data": {
        "blanchard_olg_steady_state": {
            "rows": [
                [
                    "k",
                    5.1239604
                ],
                [
                    "C",
                    1.3908525
                ],
                [
                    "r",
                    0.046518726
                ],
                [
                    "w",
                    1.1524923
                ],
                [
                    "H",
                    18.131809
                ],
                [
                    "mpc",
                    0.0592
                ],
                [
                    "b",
                    0
                ],
                [
                    "converged",
                    1
                ]
            ],
            "columns": [
                "variable",
                "value"
            ]
        },
        "blanchard_olg_dynamics": {
            "rows": [
                [
                    "stable_eig",
                    0.88375665
                ],
                [
                    "policy_slope",
                    0.16276208
                ],
                [
                    "determinate",
                    1
                ],
                [
                    "eig1_mod",
                    0.88375665
                ],
                [
                    "eig2_mod",
                    1.1896865
                ]
            ],
            "columns": [
                "metric",
                "value"
            ]
        }
    },
    "warnings": [
    ],
    "schema_version": 1,
    "artifacts": [
    ]
}
```

```bash
friedman dsge ct transition --periods 40 --shock-size 0.95 --dt 0.25
friedman dsge olg simulate --horizon 50
```

See [dsge guide — CT and OLG](dsge.md#continuous-time-ha-dsge-ct--c041) for options.

---

## 6. Bayesian estimation

`dsge ha estimate` estimates HA-DSGE parameters by Random-Walk Metropolis-Hastings. This shipped in CLI v0.6.0 once upstream **MEMs#228** was fixed (the Kalman observation matrix `Z` is now built from the reduction `C` rows, so observables map to the right reduced states). Each RWMH draw **re-solves the full HA model** (steady state → linearization → Kalman likelihood), the Auclert-Bardóczy-Rognlie-Straub (2021) "offline" approach — so keep `--n-draws` modest and prefer small `--n-reduced` / `--t-horizon` while prototyping.

Priors live in a `[priors]` TOML; the two numbers are the distribution's constructor args (`normal` → mean, sd):

```toml
[priors]
[priors.alpha]
dist = "normal"
a = 0.36
b = 0.05
```

```bash
friedman dsge ha estimate krusell-smith \
  --data aggregates.csv --priors priors.toml \
  --observables K --method ssj \
  --n-draws 2000 --burnin 500 --t-horizon 300 --n-reduced 15 \
  --seed 1 --format json
```

Output is a posterior summary table (`mean`, `std`, `q05`, `median`, `q95` per parameter); the acceptance rate and effective draw count go to stderr. `--measurement-error auto` adds per-observable measurement error at 10% of each series' variance (needed when observables exceed structural shocks). `--method krusell-smith` is rejected — the Kalman filter needs a linear state space, so use `ssj` or `reiter`.

---

## Pitfalls

1. **Distribution / inequality IRF with SSJ** — fails closed; switch to `--method reiter`.
2. **Large builtins** — `two-asset-hank` is expensive; prototype on `huggett`.
3. **Agent contract** — with `--format json`, stdout is one envelope; status is stderr ([Agent Guide](../agent-guide.md)).
4. **Wrong command for HA specs** — a `.jl` file returning `HADSGESpec` under `dsge solve|irf|…` raises `usage/wrong-command` (exit 2) pointing at `dsge ha …`. Conversely, a RA `DSGESpec` under `dsge ha` is rejected the same way.

---

## References

- Generated options: [`dsge` reference](generated/dsge.md)
- Representative-agent DSGE: [dsge guide](dsge.md)
- MEMs HA docs: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/)
