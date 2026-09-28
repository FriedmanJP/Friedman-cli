# policy

McKay–Wolf and Barnichon–Mesters policy counterfactuals across the verbs
(`counterfactual`, `effects`, `history`, `jacobian`, `moments`, `news`, `opp`,
`opp-sequence`, `optimal`, `spanning`, `sufficiency`).

The core idea: the causal effects of identified **policy shocks** form a *menu*; a rule
counterfactual re-weights that menu so an alternative policy rule holds along the
response to one **non-policy** shock. Because only the policy-shock composition changes,
the exercise is Lucas-robust — no model re-estimation under the new rule.

Full option lists live in the generated reference ([generated/policy.md](generated/policy.md));
the TOML schemas live in [configuration.md](../configuration.md#policy-rule--loss-policy-family).
Every leaf below is covered there by its exact name.

Empirical fences run on the bundled Denmark money dataset (`:denmark`, 55
observations of `LRM, LRY, LPY, IBO, IDE`); each fence is standalone — copy-paste
the whole block. Status lines go to stderr; stdout stays data-only.

| Command | Description |
|---------|-------------|
| `policy effects var/bvar/lp/sign` | Build and display the policy causal-effects menu |
| `policy counterfactual var/bvar/lp` | McKay–Wolf rule counterfactual on that menu |
| `policy optimal var/bvar/lp` | Optimal policy under a quadratic loss (`--loss-config`) |
| `policy moments var/bvar` | Unconditional second moments under a counterfactual rule or loss |
| `policy opp var/bvar` | Barnichon–Mesters optimal policy perturbation (point/simulated/constrained) |
| `policy opp-sequence var/bvar` | OPP across forecast vintages with the exact revision decomposition |
| `policy news dsge/ha` | **Square** model news menus (DSGE via one QZ of dimension n+H−1; HA via sequence-space jacobians) |
| `policy jacobian ha` | Standalone household sequence-space jacobian (bare `T²`-row tidy matrix; no plot) |
| `policy history var/bvar` | Historical counterfactual over an observation window — from **forecast revisions**, never identified shocks (raw forecasts double-count) |
| `policy spanning var` | Does the model choice matter for THIS counterfactual? (thin empirical vs full news menu) |
| `policy sufficiency dsge` | Population forecast-sufficiency laboratory (no data; invertibility is sufficient, not necessary) |

**Square vs thin is the module's central axis.** A *square* menu (as many policy shocks
as horizons, `is_square = true`) supports an exact solve — the rule holds exactly. A
*thin* menu (the empirical case: a few identified shocks) gives a least-squares
projection, and the **implementation error** is the honesty signal. Every result carries
`rel_residual` (+ bands), `spanned`, and the full `error_path` **in the output data** —
a thin menu that cannot enforce an H-period rule is visible in the envelope, not just on
stderr.

Structural-route notes: the DSGE/HA maps are `name=model_symbol`
(`--outcomes c=C`), not column indices. `--behavioral-m`/`--behavioral-theta`
(both ∈ [0,1]) apply Gabaix cognitive discounting / sticky expectations on the **news
leaves only** — behavioral operators refuse thin empirical menus (already
behavior-inclusive), and applying them to a GE-closed menu is an approximation (CMW
apply per block before closure). On `policy news ha`, `--rule-closure market` is
huggett-only and its wedge is exactly neutral **by construction** (the analytic GE
check — the flat output is correct, not broken); `--t-horizon < H+50` adds a
truncation warning to the summary. `policy history` requires the window length
`≤ H−1`; `wedge_builder` customization is closure-gated (see
[not-wrapped](not-wrapped.md)).

---

## Referring to variables and shocks

- `--outcomes` / `--instruments` map *module names* to data variables:
  `--outcomes infl=1,ygap=2` (by 1-based column index) or `--outcomes infl=LRM` (by
  column name). Rules reference these names; matching is by name, never by position.
  A `[rule]` TOML section may only reference names the command-line maps define.
- `--shocks` selects the identified **policy** shock columns (indices or names);
  `--nonpolicy-shock` selects the ONE disturbance the rule responds to.
- On the structural routes (`policy news`, `policy spanning`'s `--model-outcomes` /
  `--model-instruments`), the maps are `name=model_symbol` pairs resolving to model
  variables — a different shape from the empirical column maps.

---

## policy effects

Each leaf estimates its own menu from the data positional (no `--model` handle —
menus are re-derived per invocation) and prints a tidy menu table
(`variable|role|shock|horizon|value`) plus a summary (`H`, `n_shocks`,
`shock_labels`, `is_square`, `source`, `normalize`, `n_draws`).

<!-- capture -->
```bash
friedman policy effects var :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --horizon 8 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "policy_causal_effects_menu": {
            "columns": [
                "variable",
                "role",
                "shock",
                "horizon",
                "value"
            ],
            "rows": [
                [
                    "infl",
                    "outcome",
                    "LPY",
                    1,
                    0
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    2,
                    -0.002818
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    3,
                    -0.004563
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    4,
                    -0.005434
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    5,
                    -0.005619
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    6,
                    -0.00529
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    7,
                    -0.004602
                ],
                [
                    "infl",
                    "outcome",
                    "LPY",
                    8,
                    -0.003687
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    1,
                    0
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    2,
                    -0.001247
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    3,
                    -0.002115
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    4,
                    -0.002612
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    5,
                    -0.002788
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    6,
                    -0.002707
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    7,
                    -0.002437
                ],
                [
                    "ygap",
                    "outcome",
                    "LPY",
                    8,
                    -0.002038
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    1,
                    0.005894
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    2,
                    0.006051
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    3,
                    0.006164
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    4,
                    0.006229
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    5,
                    0.006247
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    6,
                    0.006222
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    7,
                    0.00616
                ],
                [
                    "rate",
                    "instrument",
                    "LPY",
                    8,
                    0.006067
                ]
            ]
        },
        "policy_causal_effects_summary": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "H (horizon)",
                    8
                ],
                [
                    "n_shocks",
                    1
                ],
                [
                    "shock_labels",
                    "LPY"
                ],
                [
                    "is_square",
                    false
                ],
                [
                    "source",
                    "var"
                ],
                [
                    "normalize",
                    "none"
                ],
                [
                    "n_draws",
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
    "command": "friedman policy effects var",
    "meta": {
    },
    "error": null
}
```

```bash
friedman policy effects bvar :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --horizon 8 --draws 500
friedman policy effects lp :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --horizon 8
```

Sign restrictions arrive via `--config` (the matrix is square in the VAR dimension —
five series on `:denmark`, so 5×5); `--replications` sets the candidate count:

```bash
cat > signs.toml <<'EOF'
[identification]
method = "sign"
[identification.sign_matrix]
matrix = [
  [1, 0, 0, 0, 0],
  [0, 1, 0, 0, 0],
  [0, 0, 1, 0, 0],
  [0, 0, 0, 1, 0],
  [0, 0, 0, 0, 1],
]
horizons = [0]
EOF
friedman policy effects sign :denmark --lags 1 --shocks 1 --outcomes infl=1,ygap=2 --instruments rate=3 --config signs.toml --replications 200 --horizon 8
```

Route notes:

- **var**: `--replications N` adds bootstrap draws (bands downstream); `0` = point only.
  Lag order defaults to AIC (`--lags 1` above keeps the demo small and clean).
- **bvar**: posterior draws are carried over automatically (the draw-storing main
  `irf(post, h)` path — the Bayesian adapter *errors* on a draw-free IRF by design).
  Lag order defaults to 4; `--config` supplies the prior TOML.
- **lp**: draws are an **independent-normal `N(value, se)` approximation** — fine for
  pointwise bands, *not* a joint posterior. No `--normalize` (the LP route keeps the
  estimator's scale). Lag order defaults to 4.
- **sign**: requires `--config` with `[identification]` sign restrictions; draws are the
  accepted rotations (`--replications` sets the candidate count).
- `--normalize instrument-impact` rescales every shock column so the first instrument's
  impact is `+1`; it needs at least one mapped instrument, and draws with near-zero
  impact are dropped (count in the summary).

`policy effects` has **no plot flags**: upstream ships no `plot_result` recipe for the
menu container. `policy counterfactual` is plot-capable (the recipe auto-appends an
implementation-error panel when `rel_residual` exceeds `--spanned-tol`).

---

## policy counterfactual

Give exactly one of `--rule` (builtin: `rate-peg`, `inflation-target`, `output-gap`,
`ngdp`, `taylor`) or `--rule-config` (TOML `[rule]` section; the only route to
`rate-target`, whose pegged path lives in the TOML). `--method` selects the projection
(`auto` solves exactly when square, otherwise least-squares); `--use-draws` propagates
menu draws into bands; `--baseline-draws` pairs draw *d* with draw *d* under `match`
(equal counts enforced) or holds the MW `fixed` convention; `--quantiles` sets the band
levels; `--spanned-tol` sets the `rel_residual` threshold behind the `spanned` flag;
`--negate` flips the non-policy shock's sign.

`rate-peg` and `taylor` need exactly one mapped instrument. The baseline comes from the
SAME estimate that supplies the menu.

<!-- capture -->
```bash
friedman policy counterfactual var :denmark --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --horizon 8 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "enforcing_policy_shocks_nu": {
            "columns": [
                "shock",
                "nu"
            ],
            "rows": [
                [
                    "LPY",
                    0.548759
                ]
            ]
        },
        "counterfactual_summary": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "rule",
                    "rate peg"
                ],
                [
                    "H",
                    8
                ],
                [
                    "rel_residual",
                    0.084756
                ],
                [
                    "spanned",
                    false
                ],
                [
                    "n_draws_used",
                    0
                ],
                [
                    "n_draws_failed",
                    0
                ],
                [
                    "quantile_levels",
                    "0.16, 0.5, 0.84"
                ],
                [
                    "note",
                    "rule NOT enforceable within the span of the supplied policy shocks; the counterfactual is a least-squares approximation — read error_path"
                ]
            ]
        },
        "implementation_error_path": {
            "columns": [
                "index",
                "error"
            ],
            "rows": [
                [
                    1,
                    0.00052
                ],
                [
                    2,
                    0.000313
                ],
                [
                    3,
                    0.000145
                ],
                [
                    4,
                    7.0e-6
                ],
                [
                    5,
                    -0.000108
                ],
                [
                    6,
                    -0.000205
                ],
                [
                    7,
                    -0.000288
                ],
                [
                    8,
                    -0.000358
                ]
            ]
        },
        "policy_counterfactual_paths": {
            "columns": [
                "variable",
                "role",
                "horizon",
                "baseline",
                "counterfactual"
            ],
            "rows": [
                [
                    "infl",
                    "outcome",
                    1,
                    0.025085,
                    0.025085
                ],
                [
                    "infl",
                    "outcome",
                    2,
                    0.02173,
                    0.020184
                ],
                [
                    "infl",
                    "outcome",
                    3,
                    0.018693,
                    0.016189
                ],
                [
                    "infl",
                    "outcome",
                    4,
                    0.01594,
                    0.012958
                ],
                [
                    "infl",
                    "outcome",
                    5,
                    0.013449,
                    0.010366
                ],
                [
                    "infl",
                    "outcome",
                    6,
                    0.011203,
                    0.008301
                ],
                [
                    "infl",
                    "outcome",
                    7,
                    0.009192,
                    0.006667
                ],
                [
                    "infl",
                    "outcome",
                    8,
                    0.007404,
                    0.005381
                ],
                [
                    "ygap",
                    "outcome",
                    1,
                    0.007893,
                    0.007893
                ],
                [
                    "ygap",
                    "outcome",
                    2,
                    0.006905,
                    0.006221
                ],
                [
                    "ygap",
                    "outcome",
                    3,
                    0.00602,
                    0.004859
                ],
                [
                    "ygap",
                    "outcome",
                    4,
                    0.0052,
                    0.003767
                ],
                [
                    "ygap",
                    "outcome",
                    5,
                    0.004433,
                    0.002903
                ],
                [
                    "ygap",
                    "outcome",
                    6,
                    0.003716,
                    0.00223
                ],
                [
                    "ygap",
                    "outcome",
                    7,
                    0.00305,
                    0.001712
                ],
                [
                    "ygap",
                    "outcome",
                    8,
                    0.002439,
                    0.00132
                ],
                [
                    "rate",
                    "instrument",
                    1,
                    -0.002714,
                    0.00052
                ],
                [
                    "rate",
                    "instrument",
                    2,
                    -0.003007,
                    0.000313
                ],
                [
                    "rate",
                    "instrument",
                    3,
                    -0.003238,
                    0.000145
                ],
                [
                    "rate",
                    "instrument",
                    4,
                    -0.003412,
                    7.0e-6
                ],
                [
                    "rate",
                    "instrument",
                    5,
                    -0.003537,
                    -0.000108
                ],
                [
                    "rate",
                    "instrument",
                    6,
                    -0.00362,
                    -0.000205
                ],
                [
                    "rate",
                    "instrument",
                    7,
                    -0.003668,
                    -0.000288
                ],
                [
                    "rate",
                    "instrument",
                    8,
                    -0.003688,
                    -0.000358
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman policy counterfactual var",
    "meta": {
    },
    "error": null
}
```

```bash
friedman policy counterfactual bvar :denmark --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --rule taylor --draws 500 --horizon 8
```

The TOML route carries the CMW Taylor calibration (ρ=0.85, φπ=2.0, φy=0.25) and the
`rate-target` path; the schema (including the `[loss]` section below) lives in
[configuration.md](../configuration.md#policy-rule--loss-policy-family):

```bash
cat > rule.toml <<'EOF'
[rule]
type = "taylor"
cmw = true
EOF
friedman policy counterfactual lp :denmark --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --rule-config rule.toml --horizon 8
```

**Output (4 tables):** counterfactual paths (`variable|role|horizon|baseline|`
`counterfactual` + `qNN` band columns when draws propagate), the enforcing date-0
policy-shock vector `ν*`, the implementation-error path, and the summary
(`rule`, `rel_residual` (+ bands), `spanned`, `n_draws_used`/`n_draws_failed`).
With `--output`, the 2nd+ tables go to `_nu`/`_error` sibling files.

!!! warning "Builtin rules use upstream's variable-name defaults"
    `--rule taylor` (and `inflation-target`/`output-gap`/`ngdp`) expect outcomes
    literally named `infl`/`ygap` — name them so in `--outcomes`, or use `--rule-config`
    to pick `pi_var`/`y_var` freely. And `--rule taylor` is the **textbook**
    calibration (ρ=0.5, φπ=1.5, φy=1.0) — the Caravello–McKay–Wolf values need
    `cmw = true` in the TOML.

### Rule TOML (`--rule-config`)

```toml
[rule]
type = "taylor"        # rate-peg | rate-target | inflation-target | output-gap | ngdp | taylor
cmw = true             # taylor only: sets rho=0.85, phi_pi=2.0, phi_y=0.25 (refuses partial overrides)
# rho = 0.5            # taylor, textbook defaults when cmw is absent
# phi_pi = 1.5
# phi_y = 1.0
# z_lag = 0.0
# pi_var = "infl"      # taylor / inflation-target / ngdp
# y_var = "ygap"       # taylor / output-gap / ngdp
# path = [4.0, 4.0]    # rate-target: the pegged instrument path, length --horizon
# outcomes = ["infl", "ygap"]
# instruments = ["rate"]
```

Rules are **stabilization around the model's fixed steady state** — a different
inflation-target *level* is out of scope by construction. A `rate-target` path must
have exactly `--horizon` entries. Full schema (including the `[loss]` section below)
lives in [configuration.md](../configuration.md#policy-rule--loss-policy-family).

---

## policy optimal

Same plumbing as `policy counterfactual`, with a **quadratic loss** (`--loss-config`,
required — `lambda` has no upstream default) in place of a rule. Instrument smoothing
comes from `[loss.smoothing]`; the config loader owns the `W_z`/`wedge_term` split, and
smoothing requires exactly one mapped instrument.

```bash
cat > loss.toml <<'EOF'
[loss]
outcomes = ["infl", "ygap"]
lambda = [1.0, 0.5]
EOF
friedman policy optimal var :denmark --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --horizon 8
friedman policy optimal bvar :denmark --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --draws 500 --horizon 8
friedman policy optimal lp :denmark --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --horizon 8
```

The summary adds the loss accounting: `loss_base`, `loss_cf`, and `foc_norm` — the
first-order-condition norm, ≈ 0 at the optimum (the optimality certificate). If the
loss ever *increases*, a warning row appears in the summary (upstream flags it as a
kernel/sign bug — do not use those paths). There is **no `--spanned-tol`** on this
leaf: upstream hardcodes 0.05.

---

## policy moments

Second-moment (Wold) counterfactual: the unconditional covariance of the mapped
variables under the baseline and under an alternative rule (`--rule`/`--rule-config`)
**or** loss (`--loss-config`) — exactly one of the two.

<!-- capture -->
```bash
friedman policy moments var :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --horizon 40 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "counterfactual_correlations": {
            "columns": [
                "var1",
                "var2",
                "corr_base",
                "corr_cf"
            ],
            "rows": [
                [
                    "infl",
                    "ygap",
                    0.75153,
                    0.699296
                ],
                [
                    "infl",
                    "rate",
                    -0.402732,
                    -0.017316
                ],
                [
                    "ygap",
                    "rate",
                    -0.321027,
                    -0.532125
                ]
            ]
        },
        "moments_summary": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "policy",
                    "rate peg"
                ],
                [
                    "H",
                    40
                ],
                [
                    "tail_share (VMA truncation; > 0.01 means grow --horizon)",
                    0.062509
                ],
                [
                    "draw_source",
                    "ce"
                ],
                [
                    "freq_band",
                    "full spectrum"
                ]
            ]
        },
        "counterfactual_standard_deviations": {
            "columns": [
                "variable",
                "sd_base",
                "sd_cf"
            ],
            "rows": [
                [
                    "infl",
                    0.114443,
                    0.103404
                ],
                [
                    "ygap",
                    0.047711,
                    0.045781
                ],
                [
                    "rate",
                    0.056741,
                    0.020318
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman policy moments var",
    "meta": {
    },
    "error": null
}
```

```bash
friedman policy moments var :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --horizon 40 --frequencies business-cycle
friedman policy moments bvar :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --horizon 40 --draws 500
```

**Output:** a standard-deviations table (`sd_base`/`sd_cf` + band columns under
draws), tidy pairwise correlations, and a summary whose **`tail_share`** is the VMA
truncation honesty number — above 0.01 means `--horizon` must grow. `--frequencies`
band-limits the variance (`business-cycle` = periods 6–32; or `lo,hi` in radians,
`0 ≤ lo < hi ≤ π`). `--draw-source ce|wold|both` picks the uncertainty source
(`both` enforces matching draw counts). `--plot-view sd|corr` selects the plot panel.

!!! warning "This is the one engine that assumes invertibility"
    Second-moment counterfactuals require the Wold innovations to span the structural
    shocks (invertibility / forecast sufficiency). Level counterfactuals
    (`policy counterfactual`) do not need this. Upstream warns once per session; the
    Wold orthogonalization itself carries **no identification content** — moments are
    rotation-invariant.

---

## policy opp

The Barnichon–Mesters OPP asks: *is the announced policy optimal, and if not, by how
much should it move?* The answer `δ*` is a perturbation per identified policy-shock
direction, from two sufficient statistics — the forecast **gaps** and the shock's
causal effects.

```bash
cat > loss.toml <<'EOF'
[loss]
outcomes = ["infl", "ygap"]
lambda = [1.0, 0.5]
EOF
friedman policy opp var :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --targets infl=2.0,ygap=0 --horizon 8
friedman policy opp bvar :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --targets infl=2.0,ygap=0 --horizon 8 --draws 500
```

!!! danger "Gaps, not levels"
    The OPP consumes deviations from target. **`--targets` is required and must cover
    every outcome** — an omitted outcome would default to a zero target, and feeding a
    *level* forecast with an implicit zero target silently drives the level to zero
    (wrong answer, no error). On the external route (`--values-file`) the paths are
    gaps already, so `--targets` is refused there. And per BM S0.5, the forecast must
    be conditional on the **baseline** rule even under repeated OPP adoption.

- **Model-forecast route** (`var`/`bvar`): the same estimate supplies the menu and the
  forecast; the BVAR forecast is drawn with `store_draws` so posterior bands are real
  (without it upstream silently falls back to narrower IRF-only bands).
- **External route**: `--values-file` (gap paths CSV) + `--sd`/`--rho` (BM damped
  covariance `Σ[j,k]=sd_j·sd_k·ρ^|j−k|`) **or** `--cross-corr-file` (a full covariance
  — upstream then ignores `sd`/`rho`, so the CLI makes them mutually exclusive);
  `--min-sd` floors the sds; `--interp-quarterly` expands annual SEP paths. External
  gap paths need forecast uncertainty: `--sd` or `--cross-corr-file` is required.
- With draws and `--n-sim > 0`, `estimate_opp` runs: `delta` is the draw **median**
  (BM convention), `delta_plugin` keeps the point — both rendered. `--matched-draws`
  pairs draw *d* across sources (equal counts enforced).

!!! note "Reversed band polarity"
    Bands are at **60/75/90%** and the polarity is deliberate (BM §5.1): rejection at
    the *lower* level rejects more readily — the conservative choice for a policymaker
    averse to running non-optimal policy. The renderer labels them exactly as upstream
    does and repeats the note as an envelope field; no joint statistic is invented.

**Constrained OPP** (`--constraints-file`, TOML `[[constraint]]` floors/ZLB; requires
`--instrument-path`, the announced path the constraints act on): SLSQP by default with
`method_used`/`binding`/`kkt_residual`/`warm_start_feasible` in the summary;
`--method projection` is the crude floor-only fallback (feasible but NOT the
constrained optimum — the warning stays visible). An infeasible set errors naming the
most-violated constraint. Closure-taking `FunctionConstraint`s are not scriptable from
TOML and are refused with a pointer (see [not-wrapped](not-wrapped.md)). Cost note:
`--n-sim > 0` re-solves the SLSQP per simulation draw. The constraint schema lives in
[configuration.md](../configuration.md#opp-constraints).

---

## policy opp-sequence

OPP across forecast vintages: `--forecasts-dir` holds one gap-path CSV per date
(sorted filenames become the date labels; at least two dates — a single date is plain
`policy opp`), `--sd` is required (the external forecast containers need uncertainty;
one value per outcome). Each CSV names one column per outcome and every path must run
exactly `--horizon` rows. Output: `δ` by date and the **exact three-part revision
decomposition** — news + preference + aging sum to `δ_t − δ_{t−1}` exactly (a
deliberate finite-H deviation from BM eq. 32). `--matched-draws` pairs draws across
sources; `--plot-view fan|decomposition` selects the plot panel. With constraints the
per-date SLSQP cost compounds.

```bash
cat > loss.toml <<'EOF'
[loss]
outcomes = ["infl", "ygap"]
lambda = [1.0, 0.5]
EOF
mkdir -p vintages
printf 'infl,ygap\n0.5,0.2\n0.4,0.1\n0.3,0.0\n0.2,-0.1\n' > vintages/2024Q1.csv
printf 'infl,ygap\n0.6,0.3\n0.5,0.2\n0.4,0.1\n0.3,0.0\n' > vintages/2024Q2.csv
friedman policy opp-sequence var :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --forecasts-dir vintages --sd 0.5,0.5 --horizon 4
friedman policy opp-sequence bvar :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml --forecasts-dir vintages --sd 0.5,0.5 --horizon 4 --draws 500
```

---

## policy history var/bvar

Re-runs an observation window `--t-range lo:hi` (required, `1 ≤ lo ≤ hi`, window
length `≤ H−1`) under a counterfactual rule (`--rule`/`--rule-config`) or loss
(`--loss-config`) — exactly one of the two. Built from **forecast revisions**, never
identified shocks, and rests on forecast sufficiency (see `policy sufficiency dsge`
below).

<!-- capture -->
```bash
friedman policy history var :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --t-range 20:25 --horizon 12 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "history_summary": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "policy",
                    "rate peg"
                ],
                [
                    "H",
                    12
                ],
                [
                    "n_dates",
                    6
                ],
                [
                    "n_draws_used",
                    0
                ],
                [
                    "n_draws_failed",
                    0
                ],
                [
                    "note",
                    "built from forecast revisions, never identified shocks (raw forecasts double-count); rests on forecast sufficiency — see policy sufficiency"
                ]
            ]
        },
        "counterfactual_history": {
            "columns": [
                "date",
                "variable",
                "realized",
                "counterfactual",
                "rel_residual"
            ],
            "rows": [
                [
                    "t20",
                    "infl",
                    11.703673,
                    11.703673,
                    0.797166
                ],
                [
                    "t20",
                    "ygap",
                    5.968729,
                    5.968729,
                    0.797166
                ],
                [
                    "t20",
                    "rate",
                    -0.162763,
                    -0.166693,
                    0.797166
                ],
                [
                    "t21",
                    "infl",
                    11.678903,
                    11.680782,
                    0.280648
                ],
                [
                    "t21",
                    "ygap",
                    5.962473,
                    5.963304,
                    0.280648
                ],
                [
                    "t21",
                    "rate",
                    -0.138596,
                    -0.13395,
                    0.280648
                ],
                [
                    "t22",
                    "infl",
                    11.707782,
                    11.706674,
                    0.220649
                ],
                [
                    "t22",
                    "ygap",
                    5.986486,
                    5.98606,
                    0.220649
                ],
                [
                    "t22",
                    "rate",
                    -0.120612,
                    -0.110188,
                    0.220649
                ],
                [
                    "t23",
                    "infl",
                    11.676155,
                    11.670371,
                    0.09126
                ],
                [
                    "t23",
                    "ygap",
                    5.984788,
                    5.982226,
                    0.09126
                ],
                [
                    "t23",
                    "rate",
                    -0.087186,
                    -0.085905,
                    0.09126
                ],
                [
                    "t24",
                    "infl",
                    11.685921,
                    11.681813,
                    0.693239
                ],
                [
                    "t24",
                    "ygap",
                    5.977044,
                    5.975031,
                    0.693239
                ],
                [
                    "t24",
                    "rate",
                    -0.059363,
                    -0.054563,
                    0.693239
                ],
                [
                    "t25",
                    "infl",
                    11.641606,
                    11.637255,
                    0.531063
                ],
                [
                    "t25",
                    "ygap",
                    5.985101,
                    5.982931,
                    0.531063
                ],
                [
                    "t25",
                    "rate",
                    -0.035865,
                    -0.036445,
                    0.531063
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman policy history var",
    "meta": {
    },
    "error": null
}
```

```bash
friedman policy history bvar :denmark --lags 1 --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --t-range 20:25 --horizon 12 --draws 500 --use-draws off
```

!!! note "Draw propagation runs a point pass plus a draws pass"
    With draws (`--replications` on `var`, posterior draws on `bvar` with
    `--use-draws auto|on`), the handler renders the point-pass panels and takes
    the draw counts from the draws pass: MEMs 1.0.0's draws branch re-runs its
    per-date solver closure once per draw, and those assignments write through
    to the enclosing scope, so a single draws call comes back with empty
    `nu`/`rel_residual`. Per-date bands are not tabulated; the summary's
    `n_draws_used`/`n_draws_failed` is the propagation honesty signal.

**Output:** realized vs counterfactual value per date and variable, plus a history
summary naming the policy, window, and draw counts.

---

## policy news

Square model menus for structural counterfactuals — the exact-solve side of the
square-vs-thin axis. Both routes emit the same menu + summary tables as
`policy effects`. The DSGE block below writes a three-equation New Keynesian model;
the HA route uses the bundled `huggett` model (no files needed).

### policy news dsge

```bash
cat > nk.toml <<'EOF'
[model]
parameters = { rho = 0.8, kappa = 0.3, phi = 1.5, sigma = 0.01 }
endogenous = ["ygap", "infl", "rate"]
exogenous = ["e", "mp"]
linear = true
[[model.equations]]
expr = "ygap[t] = rho * ygap[t-1] - 0.2 * rate[t] + sigma * e[t]"
[[model.equations]]
expr = "infl[t] = 0.5 * infl[t-1] + kappa * ygap[t]"
[[model.equations]]
expr = "rate[t] = phi * infl[t] + 0.01 * mp[t]"
EOF
friedman policy news dsge nk.toml --policy-shock mp --outcomes infl=infl,ygap=ygap --instruments rate=rate --horizon 8
```

`--policy-shock` (the exogenous the menu perturbs) and `--outcomes` are required; the
maps resolve to model symbols. `--solver` stays linear (`gensys`/`klein`/
`blanchard-kahn` — nonlinear menus are unsupported upstream); `--chunk` splits the
shock columns across solves (`0` = all at once). The menu build evaluates the
runtime-loaded spec, so it runs behind the same world-age barrier as the RA solve path.

### policy news ha

<!-- capture -->
```bash
friedman policy news ha huggett --outcomes c=C --horizon 4 --t-horizon 40 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "policy_causal_effects_menu": {
            "columns": [
                "variable",
                "role",
                "shock",
                "horizon",
                "value"
            ],
            "rows": [
                [
                    "c",
                    "outcome",
                    "m (s=0)",
                    1,
                    -0.573116
                ],
                [
                    "c",
                    "outcome",
                    "m (s=0)",
                    2,
                    0.035033
                ],
                [
                    "c",
                    "outcome",
                    "m (s=0)",
                    3,
                    0.037289
                ],
                [
                    "c",
                    "outcome",
                    "m (s=0)",
                    4,
                    0.036767
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=1)",
                    1,
                    -0.519528
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=1)",
                    2,
                    -0.519593
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=1)",
                    3,
                    0.079393
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=1)",
                    4,
                    0.075739
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=2)",
                    1,
                    -0.479958
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=2)",
                    2,
                    -0.4715
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=2)",
                    3,
                    -0.478303
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=2)",
                    4,
                    0.115086
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=3)",
                    1,
                    -0.44487
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=3)",
                    2,
                    -0.436703
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=3)",
                    3,
                    -0.433661
                ],
                [
                    "c",
                    "outcome",
                    "m news (s=3)",
                    4,
                    -0.445097
                ],
                [
                    "rate",
                    "instrument",
                    "m (s=0)",
                    1,
                    1
                ],
                [
                    "rate",
                    "instrument",
                    "m (s=0)",
                    2,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m (s=0)",
                    3,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m (s=0)",
                    4,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=1)",
                    1,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=1)",
                    2,
                    1
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=1)",
                    3,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=1)",
                    4,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=2)",
                    1,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=2)",
                    2,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=2)",
                    3,
                    1
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=2)",
                    4,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=3)",
                    1,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=3)",
                    2,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=3)",
                    3,
                    0
                ],
                [
                    "rate",
                    "instrument",
                    "m news (s=3)",
                    4,
                    1
                ]
            ]
        },
        "policy_causal_effects_summary": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "H (horizon)",
                    4
                ],
                [
                    "n_shocks",
                    4
                ],
                [
                    "shock_labels",
                    "m (s=0), m news (s=1), m news (s=2), m news (s=3)"
                ],
                [
                    "is_square",
                    true
                ],
                [
                    "source",
                    "hank"
                ],
                [
                    "normalize",
                    "none"
                ],
                [
                    "n_draws",
                    0
                ],
                [
                    "truncation_warning",
                    "T_horizon = 40 < H + 50 — the sequence-space truncation may bite; grow --t-horizon"
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman policy news ha",
    "meta": {
    },
    "error": null
}
```

Takes a builtin HA model name or a `.jl` HA spec. Outcomes resolve to household
aggregates (`C` consumption, `A` assets, `N`/`L` labor — a GDP-style name such as `pi`
is refused with the recognized list). `--t-horizon` is the sequence-space
truncation (must clear `--horizon`; below `H+50` warns); `--instruments` defaults to
`rate=r`; `--rule-closure` is `administered` or `market` (market is huggett-only, and
its wedge is exactly neutral by construction); `--dx` is the finite-difference step.
The HA path never invokes the aggregate spec's residual closures, so no world-age
barrier applies here. `--behavioral-m`/`--behavioral-theta` apply on both news routes.

---

## policy jacobian ha

The standalone household sequence-space jacobian behind `policy news ha`: `dJ/dinput`
for `--input r|w` against the household aggregate named by `--jac-output` (required,
`C` consumption, `A` assets, or a labor aggregate), rendered as a tidy `row|col|value`
table with `T²` rows at `--t-horizon T`. A bare upstream matrix — no report or plot
recipes. `--dx` is the finite-difference step.

<!-- capture -->
```bash
friedman policy jacobian ha huggett --input r --jac-output C --t-horizon 20 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "sequence_space_jacobian": {
            "columns": [
                "row",
                "col",
                "value"
            ],
            "rows": [
                [
                    1,
                    1,
                    -0.57311629
                ],
                [
                    2,
                    1,
                    0.03503252
                ],
                [
                    3,
                    1,
                    0.03728904
                ],
                [
                    4,
                    1,
                    0.03676746
                ],
                [
                    5,
                    1,
                    0.03492371
                ],
                [
                    6,
                    1,
                    0.0325144
                ],
                [
                    7,
                    1,
                    0.02993829
                ],
                [
                    8,
                    1,
                    0.02739426
                ],
                [
                    9,
                    1,
                    0.0249755
                ],
                [
                    10,
                    1,
                    0.02271283
                ],
                [
                    11,
                    1,
                    0.02061506
                ],
                [
                    12,
                    1,
                    0.01868262
                ],
                [
                    13,
                    1,
                    0.01691096
                ],
                [
                    14,
                    1,
                    0.01529258
                ],
                [
                    15,
                    1,
                    0.0138182
                ],
                [
                    16,
                    1,
                    0.01247791
                ],
                [
                    17,
                    1,
                    0.01126167
                ],
                [
                    18,
                    1,
                    0.01015955
                ],
                [
                    19,
                    1,
                    0.00916197
                ],
                [
                    20,
                    1,
                    0.00825985
                ],
                [
                    1,
                    2,
                    -0.51952849
                ],
                [
                    2,
                    2,
                    -0.5195928
                ],
                [
                    3,
                    2,
                    0.07939349
                ],
                [
                    4,
                    2,
                    0.07573868
                ],
                [
                    5,
                    2,
                    0.07062426
                ],
                [
                    6,
                    2,
                    0.06493269
                ],
                [
                    7,
                    2,
                    0.05920031
                ],
                [
                    8,
                    2,
                    0.05371418
                ],
                [
                    9,
                    2,
                    0.04860657
                ],
                [
                    10,
                    2,
                    0.04392125
                ],
                [
                    11,
                    2,
                    0.03964968
                ],
                [
                    12,
                    2,
                    0.0357676
                ],
                [
                    13,
                    2,
                    0.03224751
                ],
                [
                    14,
                    2,
                    0.029061
                ],
                [
                    15,
                    2,
                    0.02618031
                ],
                [
                    16,
                    2,
                    0.02357862
                ],
                [
                    17,
                    2,
                    0.02123072
                ],
                [
                    18,
                    2,
                    0.01911319
                ],
                [
                    19,
                    2,
                    0.01720437
                ],
                [
                    20,
                    2,
                    0.01548437
                ],
                [
                    1,
                    3,
                    -0.47995779
                ],
                [
                    2,
                    3,
                    -0.47150004
                ],
                [
                    3,
                    3,
                    -0.4783026
                ],
                [
                    4,
                    3,
                    0.11508591
                ],
                [
                    5,
                    3,
                    0.10712482
                ],
                [
                    6,
                    3,
                    0.09842803
                ],
                [
                    7,
                    3,
                    0.08965033
                ],
                [
                    8,
                    3,
                    0.08122141
                ],
                [
                    9,
                    3,
                    0.07336075
                ],
                [
                    10,
                    3,
                    0.06615354
                ],
                [
                    11,
                    3,
                    0.0596077
                ],
                [
                    12,
                    3,
                    0.05368362
                ],
                [
                    13,
                    3,
                    0.04833117
                ],
                [
                    14,
                    3,
                    0.0435007
                ],
                [
                    15,
                    3,
                    0.03914515
                ],
                [
                    16,
                    3,
                    0.03522043
                ],
                [
                    17,
                    3,
                    0.03168555
                ],
                [
                    18,
                    3,
                    0.02850293
                ],
                [
                    19,
                    3,
                    0.02563827
                ],
                [
                    20,
                    3,
                    0.02306036
                ],
                [
                    1,
                    4,
                    -0.44486964
                ],
                [
                    2,
                    4,
                    -0.43670318
                ],
                [
                    3,
                    4,
                    -0.43366079
                ],
                [
                    4,
                    4,
                    -0.44509734
                ],
                [
                    5,
                    4,
                    0.1442795
                ],
                [
                    6,
                    4,
                    0.13299377
                ],
                [
                    7,
                    4,
                    0.12143214
                ],
                [
                    8,
                    4,
                    0.11015079
                ],
                [
                    9,
                    4,
                    0.09951537
                ],
                [
                    10,
                    4,
                    0.08970299
                ],
                [
                    11,
                    4,
                    0.08076532
                ],
                [
                    12,
                    4,
                    0.07268198
                ],
                [
                    13,
                    4,
                    0.0653893
                ],
                [
                    14,
                    4,
                    0.05881696
                ],
                [
                    15,
                    4,
                    0.05289794
                ],
                [
                    16,
                    4,
                    0.04757007
                ],
                [
                    17,
                    4,
                    0.04277613
                ],
                [
                    18,
                    4,
                    0.03846364
                ],
                [
                    19,
                    4,
                    0.03458492
                ],
                [
                    20,
                    4,
                    0.03109679
                ],
                [
                    1,
                    5,
                    -0.41034449
                ],
                [
                    2,
                    5,
                    -0.40630475
                ],
                [
                    3,
                    5,
                    -0.40241971
                ],
                [
                    4,
                    5,
                    -0.40324131
                ],
                [
                    5,
                    5,
                    -0.41811063
                ],
                [
                    6,
                    5,
                    0.16822438
                ],
                [
                    7,
                    5,
                    0.15431532
                ],
                [
                    8,
                    5,
                    0.1404512
                ],
                [
                    9,
                    5,
                    0.12713514
                ],
                [
                    10,
                    5,
                    0.11469702
                ],
                [
                    11,
                    5,
                    0.10328397
                ],
                [
                    12,
                    5,
                    0.09292221
                ],
                [
                    13,
                    5,
                    0.08356997
                ],
                [
                    14,
                    5,
                    0.07514545
                ],
                [
                    15,
                    5,
                    0.06756249
                ],
                [
                    16,
                    5,
                    0.06074024
                ],
                [
                    17,
                    5,
                    0.05460452
                ],
                [
                    18,
                    5,
                    0.04908756
                ],
                [
                    19,
                    5,
                    0.0441276
                ],
                [
                    20,
                    5,
                    0.03966882
                ],
                [
                    1,
                    6,
                    -0.37585952
                ],
                [
                    2,
                    6,
                    -0.37618552
                ],
                [
                    3,
                    6,
                    -0.37554481
                ],
                [
                    4,
                    6,
                    -0.37485506
                ],
                [
                    5,
                    6,
                    -0.3786138
                ],
                [
                    6,
                    6,
                    -0.39613117
                ],
                [
                    7,
                    6,
                    0.18783076
                ],
                [
                    8,
                    6,
                    0.17183141
                ],
                [
                    9,
                    6,
                    0.1561128
                ],
                [
                    10,
                    6,
                    0.14114828
                ],
                [
                    11,
                    6,
                    0.12724269
                ],
                [
                    12,
                    6,
                    0.11452165
                ],
                [
                    13,
                    6,
                    0.10299271
                ],
                [
                    14,
                    6,
                    0.09259796
                ],
                [
                    15,
                    6,
                    0.08324155
                ],
                [
                    16,
                    6,
                    0.07482495
                ],
                [
                    17,
                    6,
                    0.06725648
                ],
                [
                    18,
                    6,
                    0.06045243
                ],
                [
                    19,
                    6,
                    0.05433669
                ],
                [
                    20,
                    6,
                    0.04884007
                ],
                [
                    1,
                    7,
                    -0.34098669
                ],
                [
                    2,
                    7,
                    -0.34572999
                ],
                [
                    3,
                    7,
                    -0.34882134
                ],
                [
                    4,
                    7,
                    -0.35083533
                ],
                [
                    5,
                    7,
                    -0.35264506
                ],
                [
                    6,
                    7,
                    -0.35870495
                ],
                [
                    7,
                    7,
                    -0.37830626
                ],
                [
                    8,
                    7,
                    0.2037836
                ],
                [
                    9,
                    7,
                    0.18611651
                ],
                [
                    10,
                    7,
                    0.16890989
                ],
                [
                    11,
                    7,
                    0.15261701
                ],
                [
                    12,
                    7,
                    0.13752448
                ],
                [
                    13,
                    7,
                    0.12374215
                ],
                [
                    14,
                    7,
                    0.11126373
                ],
                [
                    15,
                    7,
                    0.10001901
                ],
                [
                    16,
                    7,
                    0.08990139
                ],
                [
                    17,
                    7,
                    0.08080278
                ],
                [
                    18,
                    7,
                    0.07262305
                ],
                [
                    19,
                    7,
                    0.06527096
                ],
                [
                    20,
                    7,
                    0.05866375
                ],
                [
                    1,
                    8,
                    -0.30650064
                ],
                [
                    2,
                    8,
                    -0.31438426
                ],
                [
                    3,
                    8,
                    -0.32146135
                ],
                [
                    4,
                    8,
                    -0.32681434
                ],
                [
                    5,
                    8,
                    -0.3309808
                ],
                [
                    6,
                    8,
                    -0.33479357
                ],
                [
                    7,
                    8,
                    -0.3426855
                ],
                [
                    8,
                    8,
                    -0.36394179
                ],
                [
                    9,
                    8,
                    0.21666203
                ],
                [
                    10,
                    8,
                    0.19766522
                ],
                [
                    11,
                    8,
                    0.17926867
                ],
                [
                    12,
                    8,
                    0.16191057
                ],
                [
                    13,
                    8,
                    0.14586405
                ],
                [
                    14,
                    8,
                    0.13122709
                ],
                [
                    15,
                    8,
                    0.11798277
                ],
                [
                    16,
                    8,
                    0.10605142
                ],
                [
                    17,
                    8,
                    0.09531809
                ],
                [
                    18,
                    8,
                    0.08566723
                ],
                [
                    19,
                    8,
                    0.07699207
                ],
                [
                    20,
                    8,
                    0.06919543
                ],
                [
                    1,
                    9,
                    -0.27346883
                ],
                [
                    2,
                    9,
                    -0.28297272
                ],
                [
                    3,
                    9,
                    -0.29287192
                ],
                [
                    4,
                    9,
                    -0.30191471
                ],
                [
                    5,
                    9,
                    -0.30914883
                ],
                [
                    6,
                    9,
                    -0.31507496
                ],
                [
                    7,
                    9,
                    -0.32050462
                ],
                [
                    8,
                    9,
                    -0.32986222
                ],
                [
                    9,
                    9,
                    -0.35243723
                ],
                [
                    10,
                    9,
                    0.2269844
                ],
                [
                    11,
                    9,
                    0.20692833
                ],
                [
                    12,
                    9,
                    0.18758254
                ],
                [
                    13,
                    9,
                    0.16937363
                ],
                [
                    14,
                    9,
                    0.15256434
                ],
                [
                    15,
                    9,
                    0.13724337
                ],
                [
                    16,
                    9,
                    0.12338553
                ],
                [
                    17,
                    9,
                    0.11090377
                ],
                [
                    18,
                    9,
                    0.09967654
                ],
                [
                    19,
                    9,
                    0.08958245
                ],
                [
                    20,
                    9,
                    0.08050945
                ],
                [
                    1,
                    10,
                    -0.24382472
                ],
                [
                    2,
                    10,
                    -0.25262649
                ],
                [
                    3,
                    10,
                    -0.26388283
                ],
                [
                    4,
                    10,
                    -0.2755003
                ],
                [
                    5,
                    10,
                    -0.28619512
                ],
                [
                    6,
                    10,
                    -0.29498087
                ],
                [
                    7,
                    10,
                    -0.30233731
                ],
                [
                    8,
                    10,
                    -0.30906677
                ],
                [
                    9,
                    10,
                    -0.31959583
                ],
                [
                    10,
                    10,
                    -0.34322213
                ],
                [
                    11,
                    10,
                    0.23525664
                ],
                [
                    12,
                    10,
                    0.21435501
                ],
                [
                    13,
                    10,
                    0.19425085
                ],
                [
                    14,
                    10,
                    0.17536169
                ],
                [
                    15,
                    10,
                    0.15794213
                ],
                [
                    16,
                    10,
                    0.14207359
                ],
                [
                    17,
                    10,
                    0.12772432
                ],
                [
                    18,
                    10,
                    0.11480147
                ],
                [
                    19,
                    10,
                    0.10317829
                ],
                [
                    20,
                    10,
                    0.09272872
                ],
                [
                    1,
                    11,
                    -0.21738436
                ],
                [
                    2,
                    11,
                    -0.22533714
                ],
                [
                    3,
                    11,
                    -0.23567076
                ],
                [
                    4,
                    11,
                    -0.24843538
                ],
                [
                    5,
                    11,
                    -0.26150816
                ],
                [
                    6,
                    11,
                    -0.27357434
                ],
                [
                    7,
                    11,
                    -0.28362687
                ],
                [
                    8,
                    11,
                    -0.29213702
                ],
                [
                    9,
                    11,
                    -0.2999077
                ],
                [
                    10,
                    11,
                    -0.31137201
                ],
                [
                    11,
                    11,
                    -0.33583766
                ],
                [
                    12,
                    11,
                    0.24188787
                ],
                [
                    13,
                    11,
                    0.22031033
                ],
                [
                    14,
                    11,
                    0.19959962
                ],
                [
                    15,
                    11,
                    0.18016611
                ],
                [
                    16,
                    11,
                    0.16225795
                ],
                [
                    17,
                    11,
                    0.14595081
                ],
                [
                    18,
                    11,
                    0.13120778
                ],
                [
                    19,
                    11,
                    0.11793137
                ],
                [
                    20,
                    11,
                    0.10599072
                ],
                [
                    1,
                    12,
                    -0.19380405
                ],
                [
                    2,
                    12,
                    -0.20097174
                ],
                [
                    3,
                    12,
                    -0.21026845
                ],
                [
                    4,
                    12,
                    -0.22192934
                ],
                [
                    5,
                    12,
                    -0.23597857
                ],
                [
                    6,
                    12,
                    -0.25026469
                ],
                [
                    7,
                    12,
                    -0.2634541
                ],
                [
                    8,
                    12,
                    -0.2745312
                ],
                [
                    9,
                    12,
                    -0.28396718
                ],
                [
                    10,
                    12,
                    -0.29257009
                ],
                [
                    11,
                    12,
                    -0.30478176
                ],
                [
                    12,
                    12,
                    -0.32991841
                ],
                [
                    13,
                    12,
                    0.24720473
                ],
                [
                    14,
                    12,
                    0.2250864
                ],
                [
                    15,
                    12,
                    0.20389021
                ],
                [
                    16,
                    12,
                    0.18402082
                ],
                [
                    17,
                    12,
                    0.1657213
                ],
                [
                    18,
                    12,
                    0.14906272
                ],
                [
                    19,
                    12,
                    0.1340041
                ],
                [
                    20,
                    12,
                    0.12044425
                ],
                [
                    1,
                    13,
                    -0.17278779
                ],
                [
                    2,
                    13,
                    -0.17922546
                ],
                [
                    3,
                    13,
                    -0.18757428
                ],
                [
                    4,
                    13,
                    -0.19804087
                ],
                [
                    5,
                    13,
                    -0.21083689
                ],
                [
                    6,
                    13,
                    -0.22596071
                ],
                [
                    7,
                    13,
                    -0.24124345
                ],
                [
                    8,
                    13,
                    -0.25534331
                ],
                [
                    9,
                    13,
                    -0.26724395
                ],
                [
                    10,
                    13,
                    -0.27742071
                ],
                [
                    11,
                    13,
                    -0.28668919
                ],
                [
                    12,
                    13,
                    -0.2994987
                ],
                [
                    13,
                    13,
                    -0.32517227
                ],
                [
                    14,
                    13,
                    0.25146872
                ],
                [
                    15,
                    13,
                    0.22891741
                ],
                [
                    16,
                    13,
                    0.20733239
                ],
                [
                    17,
                    13,
                    0.18711381
                ],
                [
                    18,
                    13,
                    0.16850067
                ],
                [
                    19,
                    13,
                    0.15156041
                ],
                [
                    20,
                    13,
                    0.13624877
                ],
                [
                    1,
                    14,
                    -0.15408031
                ],
                [
                    2,
                    14,
                    -0.1598287
                ],
                [
                    3,
                    14,
                    -0.16730656
                ],
                [
                    4,
                    14,
                    -0.17668833
                ],
                [
                    5,
                    14,
                    -0.18815955
                ],
                [
                    6,
                    14,
                    -0.20190844
                ],
                [
                    7,
                    14,
                    -0.21791741
                ],
                [
                    8,
                    14,
                    -0.23400974
                ],
                [
                    9,
                    14,
                    -0.24884255
                ],
                [
                    10,
                    14,
                    -0.26140285
                ],
                [
                    11,
                    14,
                    -0.27217257
                ],
                [
                    12,
                    14,
                    -0.28197387
                ],
                [
                    13,
                    14,
                    -0.29526203
                ],
                [
                    14,
                    14,
                    -0.32136555
                ],
                [
                    15,
                    14,
                    0.25488923
                ],
                [
                    16,
                    14,
                    0.23199103
                ],
                [
                    17,
                    14,
                    0.21009444
                ],
                [
                    18,
                    14,
                    0.18959597
                ],
                [
                    19,
                    14,
                    0.17073142
                ],
                [
                    20,
                    14,
                    0.1535653
                ],
                [
                    1,
                    15,
                    -0.13741781
                ],
                [
                    2,
                    15,
                    -0.14255304
                ],
                [
                    3,
                    15,
                    -0.14921951
                ],
                [
                    4,
                    15,
                    -0.1576111
                ],
                [
                    5,
                    15,
                    -0.16788322
                ],
                [
                    6,
                    15,
                    -0.1802003
                ],
                [
                    7,
                    15,
                    -0.194736
                ],
                [
                    8,
                    15,
                    -0.21146524
                ],
                [
                    9,
                    15,
                    -0.22821018
                ],
                [
                    10,
                    15,
                    -0.24363062
                ],
                [
                    11,
                    15,
                    -0.25671934
                ],
                [
                    12,
                    15,
                    -0.26796402
                ],
                [
                    13,
                    15,
                    -0.27819211
                ],
                [
                    14,
                    15,
                    -0.29186374
                ],
                [
                    15,
                    15,
                    -0.31831176
                ],
                [
                    16,
                    15,
                    0.25763354
                ],
                [
                    17,
                    15,
                    0.23445732
                ],
                [
                    18,
                    15,
                    0.21231094
                ],
                [
                    19,
                    15,
                    0.19158808
                ],
                [
                    20,
                    15,
                    0.17252192
                ],
                [
                    1,
                    16,
                    -0.1225737
                ],
                [
                    2,
                    16,
                    -0.12715885
                ],
                [
                    3,
                    16,
                    -0.13310584
                ],
                [
                    4,
                    16,
                    -0.14058166
                ],
                [
                    5,
                    16,
                    -0.14976312
                ],
                [
                    6,
                    16,
                    -0.16078668
                ],
                [
                    7,
                    16,
                    -0.17380353
                ],
                [
                    8,
                    16,
                    -0.18898034
                ],
                [
                    9,
                    16,
                    -0.20629083
                ],
                [
                    10,
                    16,
                    -0.22355937
                ],
                [
                    11,
                    16,
                    -0.23945081
                ],
                [
                    12,
                    16,
                    -0.252963
                ],
                [
                    13,
                    16,
                    -0.26458829
                ],
                [
                    14,
                    16,
                    -0.27515841
                ],
                [
                    15,
                    16,
                    -0.28913737
                ],
                [
                    16,
                    16,
                    -0.31586152
                ],
                [
                    17,
                    16,
                    0.25983567
                ],
                [
                    18,
                    16,
                    0.23643653
                ],
                [
                    19,
                    16,
                    0.21408987
                ],
                [
                    20,
                    16,
                    0.19318705
                ],
                [
                    1,
                    17,
                    -0.10934381
                ],
                [
                    2,
                    17,
                    -0.11343987
                ],
                [
                    3,
                    17,
                    -0.11874376
                ],
                [
                    4,
                    17,
                    -0.12540843
                ],
                [
                    5,
                    17,
                    -0.13358554
                ],
                [
                    6,
                    17,
                    -0.14343496
                ],
                [
                    7,
                    17,
                    -0.15508111
                ],
                [
                    8,
                    17,
                    -0.1686688
                ],
                [
                    9,
                    17,
                    -0.18436343
                ],
                [
                    10,
                    17,
                    -0.20214056
                ],
                [
                    11,
                    17,
                    -0.21982898
                ],
                [
                    12,
                    17,
                    -0.23609803
                ],
                [
                    13,
                    17,
                    -0.24994968
                ],
                [
                    14,
                    17,
                    -0.26188007
                ],
                [
                    15,
                    17,
                    -0.27272439
                ],
                [
                    16,
                    17,
                    -0.28694974
                ],
                [
                    17,
                    17,
                    -0.31389529
                ],
                [
                    18,
                    17,
                    0.26160295
                ],
                [
                    19,
                    17,
                    0.23802504
                ],
                [
                    20,
                    17,
                    0.21551774
                ],
                [
                    1,
                    18,
                    -0.09754989
                ],
                [
                    2,
                    18,
                    -0.10120908
                ],
                [
                    3,
                    18,
                    -0.10594225
                ],
                [
                    4,
                    18,
                    -0.11188306
                ],
                [
                    5,
                    18,
                    -0.1191708
                ],
                [
                    6,
                    18,
                    -0.12794196
                ],
                [
                    7,
                    18,
                    -0.13834547
                ],
                [
                    8,
                    18,
                    -0.15050001
                ],
                [
                    9,
                    18,
                    -0.16454912
                ],
                [
                    10,
                    18,
                    -0.1806597
                ],
                [
                    11,
                    18,
                    -0.19881119
                ],
                [
                    12,
                    18,
                    -0.21683636
                ],
                [
                    13,
                    18,
                    -0.23340819
                ],
                [
                    14,
                    18,
                    -0.24753203
                ],
                [
                    15,
                    18,
                    -0.25970706
                ],
                [
                    16,
                    18,
                    -0.27077124
                ],
                [
                    17,
                    18,
                    -0.28519418
                ],
                [
                    18,
                    18,
                    -0.3123173
                ],
                [
                    19,
                    18,
                    0.26302138
                ],
                [
                    20,
                    18,
                    0.23930008
                ],
                [
                    1,
                    19,
                    -0.08703457
                ],
                [
                    2,
                    19,
                    -0.09030309
                ],
                [
                    3,
                    19,
                    -0.09452751
                ],
                [
                    4,
                    19,
                    -0.0998263
                ],
                [
                    5,
                    19,
                    -0.10632096
                ],
                [
                    6,
                    19,
                    -0.11413718
                ],
                [
                    7,
                    19,
                    -0.12340164
                ],
                [
                    8,
                    19,
                    -0.13425803
                ],
                [
                    9,
                    19,
                    -0.14682381
                ],
                [
                    10,
                    19,
                    -0.16124373
                ],
                [
                    11,
                    19,
                    -0.17768813
                ],
                [
                    12,
                    19,
                    -0.19613997
                ],
                [
                    13,
                    19,
                    -0.21443524
                ],
                [
                    14,
                    19,
                    -0.23124991
                ],
                [
                    15,
                    19,
                    -0.24559203
                ],
                [
                    16,
                    19,
                    -0.25796327
                ],
                [
                    17,
                    19,
                    -0.26920379
                ],
                [
                    18,
                    19,
                    -0.2837852
                ],
                [
                    19,
                    19,
                    -0.31105075
                ],
                [
                    20,
                    19,
                    0.26415992
                ],
                [
                    1,
                    20,
                    -0.07765986
                ],
                [
                    2,
                    20,
                    -0.08057746
                ],
                [
                    3,
                    20,
                    -0.08434765
                ],
                [
                    4,
                    20,
                    -0.08907458
                ],
                [
                    5,
                    20,
                    -0.09486584
                ],
                [
                    6,
                    20,
                    -0.10183081
                ],
                [
                    7,
                    20,
                    -0.11008634
                ],
                [
                    8,
                    20,
                    -0.11975432
                ],
                [
                    9,
                    20,
                    -0.13097729
                ],
                [
                    10,
                    20,
                    -0.1438737
                ],
                [
                    11,
                    20,
                    -0.15859135
                ],
                [
                    12,
                    20,
                    -0.17530366
                ],
                [
                    13,
                    20,
                    -0.19399647
                ],
                [
                    14,
                    20,
                    -0.21250841
                ],
                [
                    15,
                    20,
                    -0.22951788
                ],
                [
                    16,
                    20,
                    -0.2440351
                ],
                [
                    17,
                    20,
                    -0.25656372
                ],
                [
                    18,
                    20,
                    -0.26794571
                ],
                [
                    19,
                    20,
                    -0.28265426
                ],
                [
                    20,
                    20,
                    -0.31003408
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman policy jacobian ha",
    "meta": {
    },
    "error": null
}
```

---

## policy spanning var

Does the model choice matter for THIS counterfactual? Compares the counterfactual path
under the thin empirical menu against the path under a full DSGE news menu: the
empirical side always runs the `var` route on the data; the model side builds a
news menu from the DSGE model positional behind `--policy-shock`. `--nonpolicy-shock`
is required, and `--model-outcomes`/`--model-instruments` must use the SAME names in
the SAME order as `--outcomes`/`--instruments` (typed usage error otherwise — the
diagnostic compares by exact symbol equality).

```bash
cat > nk.toml <<'EOF'
[model]
parameters = { rho = 0.8, kappa = 0.3, phi = 1.5, sigma = 0.01 }
endogenous = ["ygap", "infl", "rate"]
exogenous = ["e", "mp"]
linear = true
[[model.equations]]
expr = "ygap[t] = rho * ygap[t-1] - 0.2 * rate[t] + sigma * e[t]"
[[model.equations]]
expr = "infl[t] = 0.5 * infl[t-1] + kappa * ygap[t]"
[[model.equations]]
expr = "rate[t] = phi * infl[t] + 0.01 * mp[t]"
EOF
friedman policy spanning var :denmark nk.toml --lags 1 --shocks 3 --nonpolicy-shock 1 --outcomes infl=1,ygap=2 --instruments rate=3 --model-outcomes infl=infl,ygap=ygap --model-instruments rate=rate --policy-shock mp --rule rate-peg --horizon 8
```

**Output:** thin-vs-full counterfactual paths per variable and horizon, plus a verdict
(`spanned`, max `gap_rel` against `--tol`, `loading_inside`, `rel_residual_emp`).
`spanned=true` means the thin empirical menu already carries this counterfactual.

---

## policy sufficiency dsge

The population forecast-sufficiency laboratory: consumes **no data**, solves the DSGE
model, and reports per-observable forecast-error-variance ratios of Wold-info over
full-info FEV across horizons. `--observables` is required (comma-separated model
variables the econometrician sees). `fev_ratio ≥ 1` throughout means the observables
span the shocks for forecasting; invertibility is SUFFICIENT for forecast sufficiency,
not necessary.

```bash
cat > nk.toml <<'EOF'
[model]
parameters = { rho = 0.8, kappa = 0.3, phi = 1.5, sigma = 0.01 }
endogenous = ["ygap", "infl", "rate"]
exogenous = ["e", "mp"]
linear = true
[[model.equations]]
expr = "ygap[t] = rho * ygap[t-1] - 0.2 * rate[t] + sigma * e[t]"
[[model.equations]]
expr = "infl[t] = 0.5 * infl[t-1] + kappa * ygap[t]"
[[model.equations]]
expr = "rate[t] = phi * infl[t] + 0.01 * mp[t]"
EOF
friedman policy sufficiency dsge nk.toml --observables infl,rate --horizon 12
```

---

## Not wrapped: the closure-taking entry points

Five upstream entry points take a **Julia function argument** and are deliberately not
scriptable from flags or TOML: `irf_match` (`menu_builder`, and with it the whole
model-bank strand — `posterior_model_probs`/`model_average`/`stacked_irf_target`/
`ctw_covariance`), `opp_sensitivity` (`build_loss`), `robust_weights` (`seq_builder`),
`FunctionConstraint` pledges in `constrained_opp`, and `counterfactual_history`'s
`wedge_builder`. Use the Julia API directly for these; the CLI refuses the reachable
combinations with a pointer. Disposition and rationale per case are recorded in
[not-wrapped](not-wrapped.md) — `opp_sensitivity` is earmarked as the first candidate
for TOML specialization (a loss template swept over a lambda grid needs no closure).

---

## Statelessness and reproducibility

None of the counterfactual containers is serializable — there is **no
`--save-model`/`--model`** on any `policy` leaf; containers are re-derived per
invocation. Reproducibility rides the global `--seed`, forwarded as the estimator and
CF seed wherever upstream accepts one (the CF functions are `rng`-only upstream, so no
per-estimator manifest seed applies on these leaves).

---

## References

- McKay, A., & Wolf, C. K. (2023). "What Can Time-Series Regressions Tell Us About
  Policy Counterfactuals?" *Econometrica*, 91(5), 1695–1725.
- Barnichon, R., & Mesters, G. (2023). "A Sufficient Statistics Approach for
  Macro Policy." *American Economic Review*, 113(11), 2809–2845.
- Caravello, T., McKay, A., & Wolf, C. K. (2025). "Evaluating Policy Counterfactuals:
  A VAR-Plus Approach."
