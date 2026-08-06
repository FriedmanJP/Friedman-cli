# policy

McKay–Wolf and Barnichon–Mesters policy counterfactuals (MEMs 0.8.0 counterfactual
module). 23 subcommands across eleven verbs.

The core idea: the causal effects of identified **policy shocks** form a *menu*; a rule
counterfactual re-weights that menu so an alternative policy rule holds along the
response to one **non-policy** shock. Because only the policy-shock composition changes,
the exercise is Lucas-robust — no model re-estimation under the new rule.

| Command | Description |
|---------|-------------|
| `policy effects var/bvar/lp/sign` | Build and display the policy causal-effects menu |
| `policy counterfactual var/bvar/lp` | McKay–Wolf rule counterfactual on that menu |
| `policy optimal var/bvar/lp` | Optimal policy under a quadratic loss (TOML `[loss]`) |
| `policy moments var/bvar` | Unconditional second moments under a counterfactual rule/loss |
| `policy opp var/bvar` | Barnichon–Mesters optimal policy perturbation (point/simulated/constrained) |
| `policy opp-sequence var/bvar` | OPP across forecast vintages with the exact revision decomposition |
| `policy news dsge/ha` | **Square** model news menus (DSGE via one QZ of dimension n+H−1; HA via sequence-space jacobians) |
| `policy jacobian ha` | Standalone household sequence-space jacobian (bare `T²`-row tidy matrix; no plot) |
| `policy history var/bvar` | Historical counterfactual over an observation window — from **forecast revisions**, never identified shocks (raw forecasts double-count) |
| `policy spanning var` | Does the model choice matter for THIS counterfactual? (thin empirical vs full news menu) |
| `policy sufficiency dsge` | Population forecast-sufficiency laboratory (no data; invertibility is sufficient, not necessary) |

Structural-route notes (v0.9.2 W7): the DSGE/HA maps are `name=model_symbol`
(`--outcomes infl=pi`), not column indices. `--behavioral-m`/`--behavioral-theta`
(both ∈ [0,1]) apply Gabaix cognitive discounting / sticky expectations on the **news
leaves only** — behavioral operators refuse thin empirical menus (already
behavior-inclusive), and applying them to a GE-closed menu is an approximation (CMW
apply per block before closure). On `policy news ha`, `--rule-closure market` is
huggett-only and its wedge is exactly neutral **by construction** (the analytic GE
check — the flat output is correct, not broken); `--t-horizon < H+50` adds a
truncation warning to the summary. `policy history` requires the window length
`≤ H−1`; `wedge_builder` customization is closure-gated (see the W8 decision record).

**Square vs thin is the module's central axis.** A *square* menu (as many policy shocks
as horizons, `is_square = true`) supports an exact solve — the rule holds exactly. A
*thin* menu (the empirical case: a few identified shocks) gives a least-squares
projection, and the **implementation error** is the honesty signal. Every result carries
`rel_residual` (+ bands), `spanned`, and the full `error_path` **in the output data** —
a thin menu that cannot enforce an H-period rule is visible in the envelope, not just on
stderr.

## Referring to variables and shocks

- `--outcomes` / `--instruments` map *module names* to IRF variables:
  `--outcomes infl=2,ygap=1` (by 1-based column index) or `--outcomes infl=cpi` (by
  column name). Rules reference these names; matching is by name, never by position.
- `--shocks` selects the identified **policy** shock columns (indices or names);
  `--nonpolicy-shock` selects the ONE disturbance the rule responds to.

## policy effects

```bash
friedman policy effects var data.csv --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 --horizon 20
friedman policy effects bvar data.csv --shocks 3 --outcomes infl=1,ygap=2 --draws 2000
friedman policy effects lp data.csv --shocks 3 --outcomes infl=1,ygap=2 --n-draws 500
friedman policy effects sign data.csv --shocks 1 --outcomes infl=1,ygap=2 --config signs.toml
```

**Output:** a tidy menu table (`variable|role|shock|horizon|value`) plus a summary
(`H`, `n_shocks`, `shock_labels`, `is_square`, `source`, `normalize`, `n_draws`).

Route notes:

- **var**: `--replications N` adds bootstrap draws (bands downstream); `0` = point only.
- **bvar**: posterior draws are carried over automatically (the draw-storing main
  `irf(post, h)` path — the Bayesian adapter *errors* on a draw-free IRF by design).
- **lp**: draws are an **independent-normal `N(value, se)` approximation** — fine for
  pointwise bands, *not* a joint posterior. No `--normalize` (the LP route keeps the
  estimator's scale).
- **sign**: requires `--config` with `[identification]` sign restrictions; draws are the
  accepted rotations.
- `--normalize instrument-impact` rescales every shock column so the first instrument's
  impact is `+1`; draws with near-zero impact are dropped (count in the summary).

`policy effects` has **no plot flags**: upstream ships no `plot_result` recipe for the
menu container. `policy counterfactual` is plot-capable (the recipe auto-appends an
implementation-error panel when `rel_residual` exceeds `--spanned-tol`).

## policy counterfactual

```bash
# A rate peg along the response to shock 1 (thin menu → least-squares + honesty)
friedman policy counterfactual var data.csv --shocks 3 --nonpolicy-shock 1 \
    --outcomes infl=1,ygap=2 --instruments rate=3 --rule rate-peg --horizon 20

# Textbook Taylor rule on the BVAR route with posterior bands
friedman policy counterfactual bvar data.csv --shocks 3 --nonpolicy-shock 1 \
    --outcomes infl=1,ygap=2 --instruments rate=3 --rule taylor --draws 2000

# CMW Taylor calibration via TOML (rho=0.85, phi_pi=2.0, phi_y=0.25)
friedman policy counterfactual lp data.csv --shocks 3 --nonpolicy-shock 1 \
    --outcomes infl=1,ygap=2 --instruments rate=3 --rule-config rule.toml
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--nonpolicy-shock` | String | (required) | The one non-policy shock (index or name) |
| `--rule` | String | | Builtin: `rate-peg`, `inflation-target`, `output-gap`, `ngdp`, `taylor` |
| `--rule-config` | String | | TOML `[rule]` section (see below); mutually exclusive with `--rule` |
| `--method` | String | `auto` | Projection: `auto` (exact when square), `ls`, `exact` |
| `--use-draws` | String | `auto` | Propagate menu draws into bands: `auto`/`on`/`off` |
| `--baseline-draws` | String | `fixed` | `fixed` (MW convention for separately estimated menus) or `match` (pair draw *d* with draw *d*; equal counts enforced) |
| `--quantiles` | String | `0.16,0.5,0.84` | Band quantiles in (0, 1) |
| `--spanned-tol` | Float | `0.05` | `rel_residual` threshold for the `spanned` flag |
| `--negate` | Flag | | Flip the non-policy shock's sign |

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
inflation-target *level* is out of scope by construction.

A `[loss]` schema (`get_policy_loss`: `lambda` required, `type = "ait"` with
`beta = 1/1.01`, `[loss.smoothing]`) ships with this family for the optimal-policy
leaves that build on it.

## policy optimal

Same plumbing as `policy counterfactual`, with a **quadratic loss** (`--loss-config`,
required — `lambda` has no upstream default) in place of a rule. Instrument smoothing
comes from `[loss.smoothing]`; the config loader owns the `W_z`/`wedge_term` split, and
smoothing requires exactly one mapped instrument.

```bash
friedman policy optimal var data.csv --shocks 3 --nonpolicy-shock 1 \
    --outcomes infl=1,ygap=2 --instruments rate=3 --loss-config loss.toml
```

The summary adds the loss accounting: `loss_base`, `loss_cf`, and `foc_norm` — the
first-order-condition norm, ≈ 0 at the optimum (the optimality certificate). If the
loss ever *increases*, a warning row appears in the summary (upstream flags it as a
kernel/sign bug — do not use those paths). There is **no `--spanned-tol`** on this
leaf: upstream hardcodes 0.05.

## policy moments

Second-moment (Wold) counterfactual: the unconditional covariance of the mapped
variables under the baseline and under an alternative rule (`--rule`/`--rule-config`)
**or** loss (`--loss-config`) — exactly one of the two.

```bash
friedman policy moments var data.csv --shocks 3 --outcomes infl=1,ygap=2 \
    --instruments rate=3 --rule rate-peg --horizon 40
friedman policy moments var data.csv --shocks 3 --outcomes infl=1,ygap=2 \
    --instruments rate=3 --rule rate-peg --frequencies business-cycle
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

## policy opp

The Barnichon–Mesters OPP asks: *is the announced policy optimal, and if not, by how
much should it move?* The answer `δ*` is a perturbation per identified policy-shock
direction, from two sufficient statistics — the forecast **gaps** and the shock's
causal effects.

```bash
friedman policy opp var data.csv --shocks 3 --outcomes infl=1,ygap=2 --instruments rate=3 \
    --loss-config loss.toml --targets infl=2.0,ygap=0
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
  `--min-sd` floors the sds; `--interp-quarterly` expands annual SEP paths.
- With draws and `--n-sim > 0`, `estimate_opp` runs: `delta` is the draw **median**
  (BM convention), `delta_plugin` keeps the point — both rendered.

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
TOML and are refused with a pointer. Cost note: `--n-sim > 0` re-solves the SLSQP per
simulation draw.

## policy opp-sequence

OPP across forecast vintages: `--forecasts-dir` holds one gap-path CSV per date
(sorted filenames become the date labels), `--sd` is required (the external forecast
containers need uncertainty). Output: `δ` by date and the **exact three-part revision
decomposition** — news + preference + aging sum to `δ_t − δ_{t−1}` exactly (a
deliberate finite-H deviation from BM eq. 32). With constraints the per-date SLSQP
cost compounds.

## Statelessness and reproducibility

None of the counterfactual containers is serializable — there is **no
`--save-model`/`--model`** on any `policy` leaf; containers are re-derived per
invocation. Reproducibility rides the global `--seed` (the CF functions are `rng`-only
upstream, so no per-estimator manifest seed).

## References

- McKay, A., & Wolf, C. K. (2023). "What Can Time-Series Regressions Tell Us About
  Policy Counterfactuals?" *Econometrica*, 91(5), 1695–1725.
- Barnichon, R., & Mesters, G. (2023). "A Sufficient Statistics Approach for
  Macro Policy." *American Economic Review*, 113(11), 2809–2845.
- Caravello, T., McKay, A., & Wolf, C. K. (2025). "Evaluating Policy Counterfactuals:
  A VAR-Plus Approach."
