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
        "julia": "1.12.6",
        "mems_version": "0.6.7",
        "cli_version": "0.6.0",
        "seed": null
    },
    "status": "ok",
    "error": null,
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
                    -4.469949230524131
                ],
                [
                    "excess_demand",
                    -5.913558960229493e-9
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
                    -0.013070272068231087
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
                    -5.913558960229493e-9
                ],
                [
                    "Y",
                    0.882608695652174
                ],
                [
                    "excess_demand",
                    -5.913558960229493e-9
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
        "julia": "1.12.6",
        "mems_version": "0.6.7",
        "cli_version": "0.6.0",
        "seed": null
    },
    "status": "ok",
    "error": null,
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
                    -4.469949230524131
                ],
                [
                    "excess_demand",
                    -5.913558960229493e-9
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
                    -0.013070272068231087
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
                    -5.913558960229493e-9
                ],
                [
                    "Y",
                    0.882608695652174
                ],
                [
                    "excess_demand",
                    -5.913558960229493e-9
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
        "julia": "1.12.6",
        "mems_version": "0.6.7",
        "cli_version": "0.6.0",
        "seed": null
    },
    "status": "ok",
    "error": null,
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
                    0.00011352359225324203,
                    0.0003901132276909895,
                    0.0003273695526284017,
                    -0.0017093784224167814,
                    2.3099144779850818e-5,
                    0.0005185414677343547,
                    -0.00021961881623608803,
                    0.0005737585120125944,
                    1
                ],
                [
                    2,
                    0.000179242883637693,
                    0.0006115174130990947,
                    0.0004777720458058027,
                    -0.002474712695218253,
                    0.00013533925451710309,
                    0.00027281059859506404,
                    1.6736212983621893e-5,
                    0.0003966406953055055,
                    0.9
                ],
                [
                    3,
                    0.00020299653212208602,
                    0.0006888402374773035,
                    0.0005100723201172134,
                    -0.002614521456942295,
                    7.173935896183156e-5,
                    -0.0002869503940054327,
                    2.9265910949384754e-5,
                    0.00034358470732536405,
                    0.81
                ],
                [
                    4,
                    0.0002036365977985349,
                    0.0006886158969985234,
                    0.0004928466872881149,
                    -0.0025114572279250594,
                    -0.00016252479277943004,
                    -0.0006861516174650969,
                    0.0001180234410032029,
                    0.0003297382802080334,
                    0.7290000000000001
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
        "julia": "1.12.6",
        "mems_version": "0.6.7",
        "cli_version": "0.6.0",
        "seed": null
    },
    "status": "ok",
    "error": null,
    "command": "friedman dsge ha simulate-panel",
    "data": {
        "ha_panel_simulation_summary_n_100_t_20": {
            "rows": [
                [
                    1,
                    -0.035992765918215056,
                    0.7388576166872681,
                    100
                ],
                [
                    2,
                    -0.03046291240843424,
                    0.6938441618889586,
                    100
                ],
                [
                    3,
                    -0.0251379831904393,
                    0.6630768860386541,
                    100
                ],
                [
                    4,
                    -0.010305076619674445,
                    0.6694927056794969,
                    100
                ],
                [
                    5,
                    -0.0010538745055979674,
                    0.6826233552274062,
                    100
                ],
                [
                    6,
                    0.021488585692493675,
                    0.6825780566119104,
                    100
                ],
                [
                    7,
                    0.06370787907815086,
                    0.6392167881052426,
                    100
                ],
                [
                    8,
                    0.04626166625824475,
                    0.6428118979063107,
                    100
                ],
                [
                    9,
                    0.061113696007551004,
                    0.6600158270910369,
                    100
                ],
                [
                    10,
                    0.037473752612509154,
                    0.6660081905254944,
                    100
                ],
                [
                    11,
                    0.05021543256815922,
                    0.6489245195384116,
                    100
                ],
                [
                    12,
                    -0.005111779805816253,
                    0.6838137033873886,
                    100
                ],
                [
                    13,
                    0.006392704526171927,
                    0.7047220034203453,
                    100
                ],
                [
                    14,
                    0.038456699989866554,
                    0.7013560740878912,
                    100
                ],
                [
                    15,
                    0.0740850606264238,
                    0.6685573291824238,
                    100
                ],
                [
                    16,
                    0.10643317754646361,
                    0.6508695439482577,
                    100
                ],
                [
                    17,
                    0.13342213409855358,
                    0.6309326316945258,
                    100
                ],
                [
                    18,
                    0.16279668654867868,
                    0.5983053923620527,
                    100
                ],
                [
                    19,
                    0.15147237115359813,
                    0.5610233660925855,
                    100
                ],
                [
                    20,
                    0.12273524309941956,
                    0.5975090722162739,
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
        "julia": "1.12.6",
        "mems_version": "0.6.7",
        "cli_version": "0.6.0",
        "seed": null
    },
    "status": "ok",
    "error": null,
    "command": "friedman dsge ct solve",
    "data": {
        "ct_aiyagari_aggregates": {
            "rows": [
                [
                    "K",
                    1.291261721125703
                ],
                [
                    "L",
                    0.15000000000000002
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
                    0.04077193217277526
                ],
                [
                    "w",
                    1.3891603114498372
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
        "julia": "1.12.6",
        "mems_version": "0.6.7",
        "cli_version": "0.6.0",
        "seed": null
    },
    "status": "ok",
    "error": null,
    "command": "friedman dsge olg solve",
    "data": {
        "blanchard_olg_steady_state": {
            "rows": [
                [
                    "k",
                    5.12396042460556
                ],
                [
                    "C",
                    1.390852457536624
                ],
                [
                    "r",
                    0.04651872598952182
                ],
                [
                    "w",
                    1.152492346563244
                ],
                [
                    "H",
                    18.131808814679154
                ],
                [
                    "mpc",
                    0.05920000000000003
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
                    0.8837566464388784
                ],
                [
                    "policy_slope",
                    0.16276207955064353
                ],
                [
                    "determinate",
                    1
                ],
                [
                    "eig1_mod",
                    0.8837566464388784
                ],
                [
                    "eig2_mod",
                    1.1896865390823155
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

## Deferred: `dsge ha estimate`

**Not shipped.** Upstream MEMs#228 maps observables onto arbitrary reduced states, so Bayesian HA estimation is not meaningful yet. When that issue closes, the estimate leaf lands as a rider (same registry discipline as the rest of `dsge ha`).

---

## Pitfalls

1. **Distribution / inequality IRF with SSJ** — fails closed; switch to `--method reiter`.
2. **Large builtins** — `two-asset-hank` is expensive; prototype on `huggett`.
3. **Agent contract** — with `--format json`, stdout is one envelope; status is stderr ([Agent Guide](../agent-guide.md)).
4. **Wrong command for HA specs** — a `.jl` file returning `HADSGESpec` belongs under `dsge ha …`, not `dsge solve` (loader hardening routes or errors cleanly).

---

## References

- Generated options: [`dsge` reference](generated/dsge.md)
- Representative-agent DSGE: [dsge guide](dsge.md)
- MEMs HA docs: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/)
