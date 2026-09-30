# dsge

Representative-agent DSGE leaves (`solve`, `irf`, `fevd`, `hd`, `simulate`, `moments`, `estimate`, `perfect-foresight`, `steady-state`, `determinacy-map`), a `bayes` node with 15 sub-leaves, and heterogeneous-agent nodes whose detail lives in the [HA-DSGE workflow guide](ha-dsge.md):

| Node | Role | Guide |
|------|------|--------|
| (top-level leaves) | Linear / nonlinear RA-DSGE, OccBin, estimation | this page |
| `dsge bayes` | Full Bayesian RA-DSGE workflow | [Bayesian DSGE](#dsge-bayes) |
| `hadsge` | One-household HA-DSGE (builtins or a `.jl` household spec) | **[HA-DSGE workflow](ha-dsge.md)** |
| `dsge ct` | Continuous-time household problems | [Pointer](#continuous-time-ha-dsge-ct) |
| `dsge olg` | Blanchard perpetual-youth OLG | [Pointer](#blanchard-olg-dsge-olg) |

Friedman loads RA models from TOML or Julia files (see [Model input formats](#model-input-formats)). One-household HA models are builtins or `.jl` files and run under `hadsge`, not `dsge`. TOML field reference: [Configuration](../configuration.md#dsge-model). Option tables: [generated `dsge` reference](generated/dsge.md) and [generated `hadsge` reference](generated/hadsge.md).

Every `bash` fence below is standalone: each one first writes the model file it needs (a minimal linear AR(1)-style spec — the same shape the integration suite pins — via heredoc), so fences run independently in any order. Bayesian and estimation fences additionally build their data CSV and priors file in-block; sampler flags are kept small so the examples finish quickly (shipped defaults are larger — see the generated reference).

---

## Model Input Formats

The CLI auto-detects the format by file extension (`.toml` or `.jl`; anything else is `usage/invalid-option`). Both paths compile the spec's residual functions at load time, so every downstream MEMs call that evaluates them runs through an `invokelatest` barrier (`_dsge_call`) — a world-age detail that never surfaces in the interface.

### TOML (`.toml`)

The `[model]` section carries `endogenous`, `exogenous`, `parameters`, and `[[model.equations]]` entries (equations already in `var[t]` form); `linear = true` marks a pre-linearized model. There is no keyword RA-spec constructor upstream, so the loader synthesizes an `@dsge begin … end` block from those fields and expands it through the macro. An empty `endogenous` or `equations` list is `config/invalid` (exit 4).

```toml
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true

[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"

[[model.equations]]
expr = "C[t] = Y[t]"
```

### Julia Script (`.jl`)

The file must evaluate to a representative-agent `ModelSpec` — typically an `@dsge begin … end` block. The CLI evaluates it with `Base.include` inside a sandbox module that pre-imports MEMs' exports, so `@dsge` resolves unqualified (an explicit `using MacroEconometricModels` is harmless but not required):

```julia
@dsge begin
    parameters: rho = 0.9, sigma = 0.01
    endogenous: Y, C
    exogenous: e
    linear: true

    Y[t] = rho * Y[t-1] + sigma * e[t]
    C[t] = Y[t]
end
```

### Model cards in a model file

A `.jl` model file may carry a **model card** above its `@dsge` block: a
`priors:` stanza, a `constraints:` stanza, or both, with each body line
indented. The stanzas must be written **above** the block — a stanza below it
is a typed `config/invalid` naming the line. The seven stanza headers, the
grammar, and the `.toml`-is-always-TOML rule are documented in
[Configuration](../configuration.md#model-cards-and-toml-files).

```julia
priors:
  rho ~ beta(2, 2)
  sigma ~ inv_gamma(2, 0.5)

constraints:
  C[t] >= 0.0

@dsge begin
    parameters: rho = 0.9, sigma = 0.01
    endogenous: Y, C
    exogenous: e
    linear: true

    Y[t] = rho * Y[t-1] + sigma * e[t]
    C[t] = Y[t]
end
```

**A stanza the command cannot use is refused, not ignored.** `dsge bayes` leaves
read `priors:` and refuse a `constraints:` stanza; `dsge solve`, `dsge irf`,
`dsge steady-state` and `dsge perfect-foresight` read `constraints:` and refuse a
`priors:` stanza. So the file above is the *shape*, and each command uses the
stanza it was written for — in practice you keep the two stanzas in separate
files. The error names the stanza, the commands that can read it, and the
alternative, so nothing is silently dropped.

The same settings can also come from `--prior` / `--constraint` (both
repeatable), or from a TOML file via `--priors` / `--constraints`. Those three
sources are one set: naming the same prior or the same constraint in two of
them is a `config/invalid` error naming the parameter and both sources.

Two things that look similar but are not: an `@dsge constraint:` declaration
**inside** the block is the binding-regime marker stored on an equation, not an
OccBin argument; and OccBin bounds written for a variable that has no defining
equation fail inside the solver with a message about regimes, not a parse
error.

Three outcomes, three exit classes. A file that does not evaluate is `config/invalid` (exit 4). A file that evaluates to something other than a `ModelSpec` is `config/invalid` (exit 4). A file that evaluates to a spec *with* agent populations — a heterogeneous-agent or other agent-kind model — is `usage/wrong-command` (exit 2), never silently remapped into an RA solver; run it under `hadsge` (or the matching `dsge` family command) instead. The mirror rule holds on the HA side: an RA spec passed to `hadsge` is rejected the same way.

Equations use `@dsge` `var[t]` syntax throughout — index every variable by time (`x[t]`, `x[t-1]`, `x[t+1]`); `x[t+1]` is `E_t x_{t+1}`. The `E[t](...)` operator no longer exists upstream and is a typed `config/invalid` (exit 4) on both `.toml` and `.jl` — there is no auto-rewrite.

---

## dsge solve

Solve a DSGE model. Supports 7 solution methods and OccBin occasionally binding constraints.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge solve rbc.toml
friedman dsge solve rbc.toml --method=perturbation --order=2
friedman dsge solve rbc.toml --method=perturbation --order=3
friedman dsge solve rbc.toml --method=pfi
friedman dsge solve rbc.toml --method=blanchard-kahn
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | `gensys`, `klein`, `perturbation`, `projection`, `pfi`, `vfi`, `blanchard-kahn` |
| `--order` | | Int | 1 | Perturbation order (`1`, `2`, or `3`) |
| `--degree` | | Int | 5 | Polynomial degree (projection/pfi/vfi; on VFI, tensor-path export only — rejected beside `--grid smolyak`, whose degree comes from `--smolyak-mu`) |
| `--grid` | | String | `auto` | Grid type: `auto`, `chebyshev`, `smolyak` (`vfi`: `auto`, `tensor`, `smolyak`) |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--periods` | | Int | 40 | Number of periods for OccBin simulation |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output (standard):** Policy function matrices. Format depends on solution method — `DSGESolution` shows G1 policy matrix, `PerturbationSolution` shows gx control-state policy, `ProjectionSolution` shows coefficients with convergence diagnostics.

**Output (OccBin):** Piecewise-linear transition path for all endogenous variables.

OccBin needs a constraints file alongside the model — both are built in-block here:

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > occbin.toml <<'EOF'
[[constraints.bounds]]
variable = "Y"
lower = -10.0
EOF
friedman dsge solve rbc.toml --constraints=occbin.toml --periods=8
```

VFI needs Bellman components (`utility:` / `beta:` / `controls:`), so it takes its own nonlinear model file:

```bash
cat > rbc_vfi.jl <<'EOF'
@dsge begin
    parameters: beta = 0.99, alpha = 0.36, delta = 0.025, rho = 0.9, sigma = 0.01
    endogenous: c, k, a
    exogenous: e
    utility: log(c)
    beta: beta
    controls: c
    euler: 1 / c[t] = beta * (1 / c[t+1]) * (alpha * exp(a[t+1]) * k[t]^(alpha - 1) + 1 - delta)
    c[t] + k[t] = exp(a[t]) * k[t-1]^alpha + (1 - delta) * k[t-1]
    a[t] = rho * a[t-1] + sigma * e[t]
end
EOF
friedman dsge solve rbc_vfi.jl --method=vfi --n-grid=8 --n-choice=15 --degree=3 --max-iter=200 --tol=1e-4 --howard-steps=10 --next-state=residual
```

**Determinacy verdict.** Every solve that produces a solution carrying the Sims `eu` pair also emits a **Determinacy Verdict** table: `existence | uniqueness | verdict | solver`. As in [`dsge determinacy-map`](#dsge-determinacy-map), the pair is reported rather than collapsed into a single boolean — `existence = 0` (no stable equilibrium exists) and `uniqueness = 0` (equilibria exist but are not unique) call for different changes to the model. Anything other than a determinate verdict is also flagged on stderr.

See [Configuration](../configuration.md#occbin-constraints) for the OccBin constraints TOML format.

### VFI options (`--method vfi`)

Value-function iteration needs Bellman components in the model: `@dsge`
`utility:` / `beta:` / `controls:` declarations (or TOML `[model]`
`utility` / `beta` / `controls`). The same knobs are accepted by
:`dsge solve`, `dsge irf`, and `dsge simulate` (`fevd`/`hd` reject `projection`/`pfi`/`vfi` with a typed `usage/invalid`).

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--grid` | String | `auto` | `auto`, `tensor`, or `smolyak`. `auto` routes `nx ≤ 3` states to the tensor grid and `nx ≥ 4` to Smolyak (upstream default; the tensor grid is intractable past ~4 states at the default `--n-grid 12`). |
| `--smolyak-mu` | String | (unset) | Smolyak level: scalar `μ ≥ 0` or comma-separated per-dimension levels, e.g. `--smolyak-mu 2,3`. Smolyak path only; unset = upstream default `μ=2`. Anisotropic (`μ=0` pins that dimension at level 0). |
| `--optimizer` | String | (unset) | Bellman maximizer: `auto`, `grid1d`, `fminbox-nm`, `fminbox-lbfgs`. `auto` uses the 1-D line scan for one control and derivative-free `Fminbox(NelderMead())` for control vectors; `fminbox-lbfgs` suits smooth problems. Unset = `auto`. |
| `--n-grid` | Int | 0 | Tensor-grid nodes per state (tensor path only; `≥ 3`; 0 = default 12). |
| `--n-choice` | Int | 0 | Line-search points (`grid1d` only; `≥ 3`; 0 = default 41). |
| `--next-state` | String | (unset) | Transition inference: `auto`, `linear`, `residual`. |
| `--howard-steps` | Int | -1 | Howard policy-improvement sub-steps (-1 = default). |
| `--evaluate-at` | String | (empty) | Comma-separated state levels at which to report the value function. |

Knob scope is enforced: VFI-only knobs on another method, and dead
combinations (`--n-grid` or `--degree` with `--grid smolyak`,
`--smolyak-mu` with `--grid tensor`, `--n-choice` with an `fminbox`
optimizer, `--optimizer grid1d` on a multi-control model), are usage
errors. The `auto` corners
(`--grid auto`, `--optimizer auto`/unset) stay permissive — resolution
needs the solved model. Upstream `optimizer_opts` (iteration caps,
tolerances) are not exposed; upstream defaults apply.

Accuracy note: the default `μ=2` is coarse on wide state grids (expect
single-digit-percent value gaps vs tensor on a default RBC calibration;
raising `--smolyak-mu` refines monotonically). The diagnostics table
reports `n_nodes` and `smolyak_blocks` (`0` off the Smolyak path) so the
active grid is always visible. Multi-control models declare a
`controls:` list; residual transition inference needs one defining equation per control.

---

## dsge irf

Impulse response functions from a solved DSGE model.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge irf rbc.toml --horizon=12
friedman dsge irf rbc.toml --shock-size=0.5 --n-sim=1000
```

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > occbin.toml <<'EOF'
[[constraints.bounds]]
variable = "Y"
lower = -10.0
EOF
friedman dsge irf rbc.toml --constraints=occbin.toml --horizon=6
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--horizon` | | Int | 40 | IRF horizon |
| `--shock-size` | | Float64 | 1.0 | Shock size (std devs) |
| `--n-sim` | | Int | 0 | Simulation-based IRF draws (0 = analytical) |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output (standard):** Per-shock IRF tables with columns for each endogenous variable.

**Output (OccBin):** Per-variable tables comparing linear vs piecewise-linear IRFs.

With `--method vfi` the solve accepts the [VFI options](#vfi-options-method-vfi) above.

---

## dsge fevd

Forecast error variance decomposition from a solved DSGE model.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge fevd rbc.toml --horizon=12
friedman dsge fevd rbc.toml --method=perturbation --order=2
friedman dsge fevd rbc.toml --method=perturbation --order=2 --unconditional
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order (`1`, `2`, or `3`) |
| `--horizon` | | Int | 40 | FEVD horizon (ignored for asymptotic `--unconditional`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--unconditional` | | Flag | | Unconditional (asymptotic) FEVD via Andreasen et al. (2018); requires `--method=perturbation` and `--order` ≥ 2 |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable FEVD proportions table (columns = shocks, rows = horizons). With `--unconditional`, horizon is asymptotic (H=1).

---

## dsge hd

Historical decomposition from a solved DSGE model.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2 sim.csv > obs.csv
friedman dsge hd rbc.toml --data=obs.csv --observables=Y --horizon=12
```

The decomposition needs observed data: the fence above simulates it from the same model first (the `cut` keeps the `Y` observable column; the leading `time` index is not data).

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2 sim.csv > obs.csv
friedman dsge hd rbc.toml --method=perturbation --order=2 --data=obs.csv --observables=Y --horizon=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--data` | `-d` | String | (required) | Path to CSV data file |
| `--observables` | | String | (required) | Observable variable names (comma-separated) |
| `--horizon` | | Int | 40 | HD horizon |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable historical decomposition tables (columns = shocks, rows = time periods).

---

## dsge simulate

Simulate from a solved DSGE model.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge simulate rbc.toml --periods=200 --burn=50
friedman dsge simulate rbc.toml --seed=42 --antithetic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--periods` | | Int | 200 | Simulation periods (after burn-in) |
| `--burn` | | Int | 100 | Burn-in periods to discard |
| `--seed` | | Int | 0 | Random seed (0 = no seed) |
| `--antithetic` | | Flag | | Use antithetic sampling for variance reduction (linear methods only; ignored with a stderr note for `projection`/`pfi`/`vfi`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Simulated data table with a column per endogenous variable, periods after burn-in.

With `--method vfi` the solve accepts the [VFI options](#vfi-options-method-vfi) above. `--seed` forwards to the nonlinear-policy simulator on `projection`/`pfi`/`vfi` solves.

---

## dsge moments

Closed-form theoretical moments of a solved model at perturbation order 1, 2 or 3. Simulation-free: at order ≥ 2 these come from the pruned state-space recursion (Andreasen, Fernández-Villaverde & Rubio-Ramírez 2018), not from a long simulation, so they are exact rather than Monte-Carlo.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge moments rbc.toml                            # order 2 (default)
friedman dsge moments rbc.toml --order=2 --lags=4
friedman dsge moments rbc.toml --order=3 --lags=8 -f json
```

Order 1 reads correctly (≤0.13.x): an earlier upstream order-1 build dropped the contemporaneous shock term from the state↔control covariance, and the re-enabled path is pinned by a closed-form AR(1) test. `--order 2` stays the default — for a linear model it reproduces the first-order moments exactly, and at higher order the risk-adjusted mean is the headline result.

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `perturbation` | Solution method (moments need a perturbation solution) |
| `--order` | | Int | 2 | Perturbation order: 1, 2 or 3 (see note above) |
| `--lags` | | Int | 1 | Autocovariance lags to report (≥ 1) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** three tables.

* **DSGE Theoretical Moments** — `variable | steady_state | mean | mean_minus_ss | std_dev`
* **Variance-Covariance** — `variable1 | variable2 | covariance | correlation` (upper triangle)
* **Autocovariances** — `variable | lag | autocovariance | autocorrelation`

`mean_minus_ss` is the column to look at. For a linear model it is identically zero — the certainty-equivalent mean *is* the steady state. For a nonlinear model at order ≥ 2 it is the **risk correction**: precautionary behaviour shifts the ergodic mean away from the deterministic steady state, and that shift is precisely what a higher-order solve buys you. Reporting the mean beside the steady state makes it visible rather than leaving it to be re-derived.

!!! note "Augmented models"
    Specs that the parser augments (to handle leads/lags beyond one period) report moments over the **original** variables only, and the labels are filtered to match. A moment table that silently used the augmented variable order would attribute every number to the wrong variable.

There is deliberately **no `--pruned` switch**. Upstream's simulation of a perturbation solution is *always* pruned (Kim, Kim, Schaumburg & Sims 2008) and exposes no unpruned path, so a flag would advertise a choice that does not exist. `dsge simulate --order 2|3` is likewise pruned.

---

## dsge determinacy-map

Sweep one or two parameters and record the Blanchard–Kahn/Sims determinacy verdict at each grid point. Answers "over what region of the parameter space does this model have a unique stable equilibrium?" — the Taylor principle being the textbook case.

The sweep is config-driven, because it is two parameter names plus grids plus a resolution — past the point where flags stay readable. This fence sweeps the persistence parameter of the running example (a one-parameter sweep also emits a boundary table):

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > determinacy.toml <<'EOF'
[determinacy]
params = ["rho"]     # 1 or 2 parameter names
lower  = [0.5]
upper  = [1.5]
points = [11]
# optional
method = "gensys"                # gensys | klein | blanchard-kahn
div    = 1.00000001              # stable/unstable eigenvalue boundary
EOF
friedman dsge determinacy-map rbc.toml --config=determinacy.toml
friedman dsge determinacy-map rbc.toml --config=determinacy.toml --threaded
```

`grids = [[...], [...]]` supplies explicit grid values instead of `lower`/`upper`/`points`. A scalar is accepted wherever a one-element list would do.

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | (required) | TOML with a `[determinacy]` section |
| `--rank-rtol` | | Float64 | 1e-8 | Relative tolerance of the Sims rank tests |
| `--threaded` | | Flag | | Evaluate grid points on all threads (results identical to the serial sweep) |
| `--verbose-solver` | | Flag | | Do **not** suppress per-grid-point solver warnings |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive heatmap in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** a tidy long table with one row per grid cell — `<param1> | [<param2>] | verdict | label | existence | uniqueness` — plus a **Determinacy Region Summary** (`n_determinate`, `n_indeterminate`, `n_no_solution`, `n_failed`, `method`, `div`), and for a one-parameter sweep a **Determinacy Boundary** table.

Verdict codes and their labels:

| `verdict` | `label` | `existence` | `uniqueness` | Meaning |
|-----------|---------|-------------|--------------|---------|
| `1` | determinate | 1 | 1 | Unique stable equilibrium |
| `0` | indeterminate | 1 | 0 | Stable equilibria exist but are not unique (sunspots) |
| `-1` | no solution | 0 | — | No stable equilibrium exists |
| `-2` | failed | -1 | -1 | The model could not be solved at this point |

**The raw `existence`/`uniqueness` pair is reported, not just the collapsed verdict**, because `existence = 0` and `uniqueness = 0` are different diagnoses with different fixes — no stable equilibrium at all, versus sunspot indeterminacy — and an agent should not have to re-derive which one it hit.

`failed` cells are counted separately and warned about on stderr. A grid point that would not solve is a **hole in the sweep, not a fourth region**: treating it as indeterminacy would invent a frontier out of a numerical gap. For the same reason the boundary calculation skips any pair involving a failed point.

The boundary is located to the resolution of the grid — refine `points` to sharpen it. For a two-parameter sweep no boundary table is emitted, since the frontier is a curve rather than a set of points; read the map (or plot it).

---

## dsge estimate

Estimate DSGE model parameters from data. 4 estimation methods. The data CSV is simulated from the same model in-block (the `cut` keeps the `Y,C` observable columns; the leading `time` index is not data).

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge estimate rbc.toml --data=obs.csv --params=rho --method=irf_matching
friedman dsge estimate rbc.toml --data=obs.csv --params=rho --method=smm --sim-ratio=10
friedman dsge estimate rbc.toml --data=obs.csv --params=rho --method=likelihood
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--data` | `-d` | String | (required) | Path to CSV data file |
| `--method` | | String | `irf_matching` | `irf_matching`, `likelihood`, `bayesian`, `smm` |
| `--params` | | String | (required) | Comma-separated parameter names to estimate |
| `--solve-method` | | String | `gensys` | DSGE solution method |
| `--solve-order` | | Int | 1 | Perturbation order for solution |
| `--weighting` | | String | `optimal` | `identity`, `optimal`, `diagonal` |
| `--irf-horizon` | | Int | 20 | IRF horizon for matching |
| `--var-lags` | | Int | 4 | VAR lags for empirical IRF |
| `--sim-ratio` | | Int | 5 | Simulation-to-data ratio (SMM) |
| `--bounds` | | String | | Path to parameter bounds TOML |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates with standard errors, t-statistics, and p-values. Includes J-statistic and convergence status.

---

## dsge perfect-foresight

Perfect foresight (deterministic) simulation for transition paths. The shock CSV needs a header naming each exogenous shock plus one row per transition period (`--periods` rows).

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
printf 'e\n0.01\n0.0\n0.0\n0.0\n0.0\n0.0\n0.0\n0.0\n0.0\n0.0\n' > shocks.csv
friedman dsge perfect-foresight rbc.toml --shocks=shocks.csv --periods=10
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--shocks` | | String | (required) | Path to shock sequence CSV |
| `--periods` | | Int | 100 | Simulation periods |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--sparsity` | | String | `auto` | Jacobian: `auto` (sparse block-tridiagonal) or `dense` |
| `--max-iter` | | Int | 100 | Newton iterations (≥ 1) |
| `--tol` | | Float64 | 1e-8 | Convergence tolerance (> 0) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

The shock CSV must have one row per transition period (`--periods` rows) and one column per exogenous shock of the model; a shape mismatch is `data/shape` (exit 3). The spec is brought to steady state first, then the deterministic path is solved.

**Output:** Transition path for all endogenous variables, with convergence status. There is no `--prefilter` here — perfect foresight solves a deterministic path from a shock sequence, it does not filter observables; trending-observable handling lives on the Bayesian leaves ([Trending observables](#trending-observables-prefilter)).

---

## dsge steady-state

Compute the steady state of a DSGE model.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge steady-state rbc.toml
```

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > occbin.toml <<'EOF'
[[constraints.bounds]]
variable = "Y"
lower = -10.0
EOF
friedman dsge steady-state rbc.toml --constraints=occbin.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Variable names and steady-state values.

---

## dsge bayes

Bayesian DSGE workflow. `bayes` is a **nested command group** with 15 sub-leaves: `estimate`, `irf`, `fevd`, `hd`, `simulate`, `summary`, `compare`, `predictive`, `mcmc-diag`, `identification`, `learning-rate`, `overlap`, `marginal-lik`, `posterior-mode`, `prior-predictive`. Twelve share the full `BAYES_OPTIONS` set below; three take strict subsets — `identification` runs no MCMC and takes only `--params`/`--observables`/`--solver`/`--order`/`--n-lags`, `posterior-mode` takes no sampler options, and `prior-predictive` draws from the prior so it takes no `--data`.

Every fence below builds the same three inputs in-block: the model file, a priors file, and an observables CSV simulated from the model (the `cut` keeps the `Y,C` columns; the leading `time` index is not data). The model has one structural shock and two observables, so the fences pass `--measurement-error=auto` — without it the likelihood is stochastically singular (`model/stochastic-singularity`, exit 5). Sampler flags are kept small so the examples finish quickly.

### Common Options (the `BAYES_OPTIONS` set)

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--data` | `-d` | String | (required) | Path to CSV data file |
| `--params` | | String | (required) | Comma-separated parameter names to estimate |
| `--priors` | | String | (required) | Path to priors TOML file |
| `--sampler` | | String | `smc` | `smc`, `smc2`, `mh` |
| `--n-smc` | | Int | 5000 | SMC particles |
| `--n-particles` | | Int | 500 | Particle filter particles (smc2) |
| `--n-draws` | | Int | 10000 | Total posterior draws |
| `--burnin` | | Int | 5000 | Burn-in draws |
| `--ess-target` | | Float64 | 0.5 | ESS target for resampling |
| `--observables` | | String | (all endogenous) | Observable variable names (comma-separated) |
| `--solver` | | String | `gensys` | `gensys`, `klein`, `perturbation` |
| `--order` | | Int | 1 | Perturbation order (1, 2, or 3) |
| `--constraint-solver` | | String | (empty) | Constraint solver backend: `nonlinearsolve`, `optim`, `nlopt`, `ipopt`, `path` (empty = legacy OccBin path) |
| `--prefilter` | | String | `none` | `none`, `demean`, `first-difference`, `linear-detrend`, `hp` — observable transform applied before estimation |
| `--hp-lambda` | | Float64 | 1600.0 | HP smoothing parameter, `--prefilter hp` only |
| `--measurement-error` | | String | `none` | `none`, `auto`, or comma-separated std devs (one per observable) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

The `--params` names must match the parameter keys in the `[priors]` TOML. Start values pass as a name→value mapping, so the order of `--params` is immaterial; a name in `--params` with no matching prior is rejected.

### Trending observables (`--prefilter`)

A DSGE model is solved in stationary deviations from steady state, but macro data is not stationary. `--prefilter` reconciles the two by transforming the observables before the Kalman filter sees them — Dynare's `prefilter`.

| Mode | What it removes |
|------|-----------------|
| `none` | Nothing (default). Correct only if your observables are *already* stationary deviations |
| `demean` | Each observable's sample mean |
| `first-difference` | `Δyₜ = yₜ − yₜ₋₁`; **drops the first observation** |
| `linear-detrend` | The OLS fit on `[1, t]`, per observable |
| `hp` | The Hodrick–Prescott trend, keeping the cycle. `--hp-lambda` is 1600 quarterly, 129600 monthly, 6.25 annual |

Two scoping facts worth knowing:

* The option rides the **shared** runner, so it is honoured by every `dsge bayes` leaf that re-estimates — not just `bayes estimate`. The CLI is stateless, so each leaf re-estimates from scratch; a prefilter available only on `bayes estimate` could not be carried into `bayes irf`/`fevd`/`hd`, and those results would silently come from a differently-specified estimate.
* It is **not** available on the frequentist `dsge estimate`, on `dsge perfect-foresight`, or on the three subset leaves (`identification`, `posterior-mode`, `prior-predictive`). `estimate_dsge` upstream takes no prefilter argument, and declaring an option a handler cannot honour would fail on every invocation. If you need prefiltering outside the Bayesian path, transform the CSV first (`data transform`).

`--hp-lambda` under any mode other than `hp` is a typed usage error rather than a silent no-op.

### dsge bayes estimate

Bayesian DSGE posterior estimation.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes estimate rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10
friedman dsge bayes estimate rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=smc --n-smc=20
```

**Output:** Posterior summary table (mean, median, std, CI per parameter) + log marginal likelihood.

### dsge bayes irf

Bayesian DSGE impulse responses with posterior uncertainty.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes irf rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --horizon=12
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--horizon` | Int | 40 | IRF horizon |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes fevd

Bayesian DSGE forecast error variance decomposition.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes fevd rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --horizon=12
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--horizon` | Int | 40 | FEVD horizon |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes hd

Bayesian DSGE historical decomposition with posterior uncertainty.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes hd rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --horizon=12
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--horizon` | Int | 40 | HD horizon |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes simulate

Simulate from the posterior of a Bayesian DSGE.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes simulate rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --periods=50
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--periods` | Int | 100 | Simulation periods |
| `--plot` | Flag | | Open interactive plot |
| `--plot-save` | String | | Save plot to HTML |

### dsge bayes summary

Detailed posterior summary statistics.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes summary rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10
```

**Output:** Posterior table (mean, median, std, 68%/90% CI).

### dsge bayes compare

Compare two Bayesian DSGE models via the log Bayes factor. Both models are estimated with the shared sampler/solver settings; `--model2`/`--params2`/`--priors2` supply the second model. Here the second model is a lower-persistence variant of the first, estimated on the same data with the same priors file.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > model2.toml <<'EOF'
[model]
parameters = { rho = 0.5, sigma = 0.02 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes compare rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 \
    --model2=model2.toml --params2=rho,sigma --priors2=priors.toml
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--model2` | String | (required) | Path to second model file |
| `--params2` | String | (required) | Parameters for second model |
| `--priors2` | String | (required) | Priors TOML for second model |

**Output:** Per-model log marginal likelihoods and acceptance rates, plus the Bayes factor on stderr. Upstream `bayes_factor` returns the **log** Bayes factor directly (`log BF₁₂ = logML₁ − logML₂`); the decision is `log_bf > 0` favors Model 1 — never `log()` it again. `2·log BF > 6` is strong evidence (Kass and Raftery 1995).

### dsge bayes predictive

Posterior predictive checks.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes predictive rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --n-sim=10 --periods=20
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--n-sim` | Int | 100 | Predictive simulations |
| `--periods` | Int | 100 | Simulation periods |

**Output:** Predictive summary (mean, std) vs observed data moments.

### dsge bayes mcmc-diag

Per-parameter MCMC convergence diagnostics on the retained posterior draws: rank-normalized split-R̂, bulk/tail effective sample size (Vehtari et al. 2021), and the Geweke (1992) z-statistic. Values of R̂ ≲ 1.01 and ESS ≥ 400 indicate convergence.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes mcmc-diag rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10
```

**Output:** Table `parameter | rhat | ess_bulk | ess_tail | geweke_z | geweke_p` + a summary (`n_draws`, `method`). SMC/importance draws are weighted particle systems (not chains) — autocorrelation-based quantities are approximate and a note is emitted on stderr.

### dsge bayes identification

Iskrev (2010) local-identification rank test at the steady state. Builds the Jacobian of the observables' steady-state means and autocovariances (lags `1..n-lags`) with respect to the estimated parameters and inspects its column rank via SVD — the parameters are locally identified iff the Jacobian has full column rank. **No MCMC and no data/priors** are needed.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
friedman dsge bayes identification rbc.toml --params=rho,sigma --observables=Y --n-lags=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--params` | | String | (required) | Comma-separated estimated parameter names |
| `--observables` | | String | (all endogenous) | Observed variable names |
| `--solver` | | String | `gensys` | `gensys`, `klein`, `perturbation` |
| `--order` | | Int | 1 | Perturbation order |
| `--n-lags` | | Int | 2 | Autocovariance lags in the Iskrev moment vector |

**Output:** Summary kv (`rank`, `n_params`, `n_moments`, `n_lags`, `identified`, `tol`) + a `index | singular_value` table.

### dsge bayes learning-rate

Koop-Pesaran-Smith (2013) posterior-variance learning-rate check. Re-estimates on nested subsamples `⌊f·T⌋` and regresses `log(posterior variance)` on `log T`; for an identified parameter the slope `α ≈ 1` (the posterior variance shrinks at the `1/T` rate), while a weakly identified parameter barely updates (`α ≈ 0`, flagged).

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes learning-rate rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --fractions=0.5,1.0 --refit-n-smc=20
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--fractions` | String | `0.5,1.0` | Nested subsample fractions in (0,1] (≥ 2 values) |
| `--threshold` | Float64 | 0.2 | Flag threshold on the learning rate α |
| `--refit-n-smc` | Int | 100 | SMC particles per subsample refit |

**Output:** Table `parameter | learning_rate | flagged` + a summary (`threshold`, `sample_sizes`). This is a Monte Carlo screening device — expect noise in `α`.

### dsge bayes overlap

Prior/posterior overlap coefficient `∫ min(π(θᵢ), p(θᵢ|Y)) dθᵢ ∈ [0,1]` per parameter. An overlap near 1 means the data barely moved the prior — the practical symptom of weak identification (flagged at `≥ --threshold`).

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes overlap rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --threshold=0.8
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--threshold` | Float64 | 0.8 | Flag threshold on the overlap |
| `--n-grid` | Int | 0 | Histogram bins (0 = auto ≈ √N) |

**Output:** Table `parameter | overlap | flagged` + a summary (`threshold`).

### dsge bayes marginal-lik

Marginal likelihood via bridge sampling (Meng-Wong 1996; Gronau et al. 2017) from the stored posterior draws — markedly more stable than the modified harmonic mean. The additive constant matches the SMC tempering-path estimate, so the two are directly comparable.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes marginal-lik rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y,C --measurement-error=auto --sampler=mh --n-draws=50 --burnin=10 --proposal=normal
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--proposal` | String | `normal` | Bridge proposal family: `normal` or `t` |
| `--df` | Float64 | 5.0 | Degrees of freedom for the `t` proposal |

**Output:** Summary kv `log_marginal_likelihood_bridge`, `log_marginal_likelihood_smc` (for comparison), `proposal`, `df`. Bridge sampling returns `NaN` (rendered as such, never a silently wrong number) when the chain is too short or the proposal too diffuse.

### dsge bayes posterior-mode

Posterior mode by optimization, with Laplace standard errors — the fast scout before full sampling. Takes the data/priors/observables/solver subset of the common options (no sampler knobs, no prefilter); `--max-iter` and `--f-reltol` control the optimizer.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman data simulate dsge rbc.toml --periods=120 --burn=20 --seed=1 -f csv -o sim.csv
cut -d, -f2,3 sim.csv > obs.csv
friedman dsge bayes posterior-mode rbc.toml --data=obs.csv --params=rho,sigma --priors=priors.toml --observables=Y
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--max-iter` | Int | 500 | Maximum optimizer iterations (≥ 1) |
| `--f-reltol` | Float64 | 1e-8 | Relative function tolerance (> 0) |

**Output:** Posterior mode and Laplace standard error per parameter, plus diagnostics (log posterior/likelihood, Laplace log ML, convergence flag, iteration count).

### dsge bayes prior-predictive

Simulates summary statistics from the prior (no data, no MCMC) — the check that the prior implies reasonable economics before estimation. Takes the params/priors/observables/solver subset plus `--n-draws` and `--periods`.

```bash
cat > rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
cat > priors.toml <<'EOF'
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0
[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
EOF
friedman dsge bayes prior-predictive rbc.toml --params=rho,sigma --priors=priors.toml --observables=Y --n-draws=20 --periods=50
```

| Additional Option | Type | Default | Description |
|-------------------|------|---------|-------------|
| `--periods` | Int | 200 | Periods to simulate per draw (≥ 1) |

**Output:** Distribution (mean, std, median, 5/95% quantiles) of each summary statistic across prior draws, plus a summary (draws requested, draws that solved, periods per draw).

### Priors TOML Format

```toml
[priors.rho]
dist = "beta"
a = 2.0
b = 2.0

[priors.sigma]
dist = "inv_gamma"
a = 2.0
b = 0.1
```

Each parameter must have a `dist` key (distribution name — `beta`, `normal`, `inv_gamma`, `gamma`, `uniform`) and shape parameters `a`, `b` (the distribution's positional constructor arguments).

---

## Solution Methods

| Method | `--method` value | When to use |
|--------|-----------------|-------------|
| Gensys (Sims 2002) | `gensys` | Default. Linear rational expectations models |
| Klein (2000) | `klein` | Alternative generalized Schur decomposition solver |
| Perturbation | `perturbation` | Higher-order approximations (order 1, 2, or 3) |
| Projection | `projection` | Global solutions, nonlinear models, accuracy matters |
| Policy Function Iteration | `pfi` | Global solutions, value function problems |
| Value Function Iteration | `vfi` | Bellman problems; needs `utility:`/`beta:`/`controls:` ([VFI options](#vfi-options-method-vfi)) |
| Blanchard-Kahn | `blanchard-kahn` | Linear models via the Blanchard–Kahn eigendecomposition |

Projection, PFI, and VFI accept `--degree` (polynomial degree) and `--grid` (grid type); VFI additionally takes the solver knobs in [VFI options](#vfi-options-method-vfi). `fevd` and `hd` accept only the linear/perturbation methods.

---

## HA-DSGE (`hadsge`)

Heterogeneous-agent DSGE runs under `hadsge`, not `dsge` — builtins or a `.jl` household spec, solved by `ssj`, `reiter`, or `krusell-smith`. Full progressive examples: **[HA-DSGE workflow guide](ha-dsge.md)**. Option tables: [generated `hadsge` reference](generated/hadsge.md).

```bash
friedman hadsge steady-state huggett
friedman hadsge solve huggett --method=reiter --n-reduced=20
friedman hadsge irf huggett --method=reiter --horizon=40
```

---

## Continuous-time HA (`dsge ct`)

Continuous-time household problems (`solve`, `transition`, plus the `bank`, `firm`, `dcegm`, and `lifecycle` family nodes) are documented in the **[HA-DSGE workflow guide](ha-dsge.md)** — this page does not duplicate their options.

```bash
friedman dsge ct solve --grid-size=100
friedman dsge ct transition --periods=40 --shock-size=0.95 --dt=0.25
```

---

## Blanchard OLG (`dsge olg`)

Perpetual-youth OLG (`solve`, `simulate`) is documented in the **[HA-DSGE workflow guide](ha-dsge.md)** — this page does not duplicate its options.

```bash
friedman dsge olg solve
friedman dsge olg simulate --horizon=50
```

---

## References

* Sims, C. A. (2002). Solving linear rational expectations models. *Computational Economics*.
* Klein, P. (2000). Using the generalized Schur form to solve a multivariate linear rational expectations model. *Journal of Economic Dynamics and Control*.
* Kim, J., Kim, S., Schaumburg, E., and Sims, C. A. (2008). Calculating and using second-order accurate solutions of discrete time dynamic equilibrium models. *Journal of Economic Dynamics and Control*.
* Andreasen, M. M., Fernández-Villaverde, J., and Rubio-Ramírez, J. F. (2018). The pruned state-space system for non-linear DSGE models. *Review of Economic Studies*.
* Iskrev, N. (2010). Local identification in DSGE models. *Journal of Monetary Economics*.
* Koop, G., Pesaran, M. H., and Smith, R. P. (2013). On identification of Bayesian DSGE models. *Journal of Business & Economic Statistics*.
* Kass, R. E., and Raftery, A. E. (1995). Bayes factors. *Journal of the American Statistical Association*.
* Blanchard, O. J. (1985). Debt, deficits, and finite horizons. *Journal of Political Economy*.
* Option tables: [generated `dsge` reference](generated/dsge.md).
