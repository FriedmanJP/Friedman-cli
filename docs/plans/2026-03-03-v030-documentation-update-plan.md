# v0.3.0 Documentation Update — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update all 15 Documenter.jl source files and create 1 new file to reflect v0.3.0 changes (DSGE module, estimate smm, VARForecast/BVARForecast typed returns, LPForecast field rename, new dependencies, Julia 1.12 requirement).

**Architecture:** Direct edits to markdown files in `docs/src/` and the `docs/make.jl` build script. All changes are documentation-only; no source code modifications. Verification is via `julia --project=docs docs/make.jl` build.

**Tech Stack:** Documenter.jl, Markdown

---

### Task 1: Create `docs/src/commands/dsge.md`

**Files:**
- Create: `docs/src/commands/dsge.md`

**Step 1: Write the new dsge.md reference page**

```markdown
# dsge

DSGE modeling from the terminal. 7 subcommands: `solve`, `irf`, `fevd`, `simulate`, `estimate`, `perfect-foresight`, `steady-state`.

Friedman supports DSGE models specified as TOML files or Julia scripts. See [Configuration](../configuration.md#dsge-model) for TOML format details.

## Model Input Formats

### TOML (`.toml`)

The model is defined in the `[model]` section with `endogenous`, `exogenous`, `parameters`, and `[[model.equations]]` entries. An optional `[solver]` section specifies the solution method.

```toml
[model]
endogenous = ["y", "c", "k", "n"]
exogenous = ["eps_a"]

[model.parameters]
alpha = 0.36
beta = 0.99
delta = 0.025
sigma = 1.0
phi_n = 1.0

[[model.equations]]
expr = "c^(-sigma) = beta * c(+1)^(-sigma) * (alpha * exp(eps_a(+1)) * k^(alpha-1) * n(+1)^(1-alpha) + 1 - delta)"

[[model.equations]]
expr = "phi_n * n^phi_n = c^(-sigma) * (1-alpha) * exp(eps_a) * k(-1)^alpha * n^(-alpha)"

[[model.equations]]
expr = "k = (1-delta)*k(-1) + y - c"

[[model.equations]]
expr = "y = exp(eps_a) * k(-1)^alpha * n^(1-alpha)"

[solver]
method = "gensys"
order = 1
```

### Julia Script (`.jl`)

The file must define a `model` variable of type `DSGESpec`:

```julia
using MacroEconometricModels
model = DSGESpec(...)
```

The CLI auto-detects the format by file extension.

## dsge solve

Solve a DSGE model. Supports 5 solution methods and OccBin occasionally binding constraints.

```bash
friedman dsge solve rbc.toml
friedman dsge solve rbc.toml --method=perturbation --order=2
friedman dsge solve rbc.toml --method=projection --degree=7 --grid=chebyshev
friedman dsge solve rbc.toml --constraints=occbin.toml --periods=60
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | `gensys`, `klein`, `perturbation`, `projection`, `pfi` |
| `--order` | | Int | 1 | Perturbation order (1 or 2) |
| `--degree` | | Int | 5 | Polynomial degree (projection/pfi) |
| `--grid` | | String | `auto` | Grid type: `auto`, `chebyshev`, `smolyak` |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--periods` | | Int | 40 | Number of periods for OccBin simulation |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output (standard):** Policy function matrices. Format depends on solution method — `DSGESolution` shows G1 policy matrix, `PerturbationSolution` shows gx control-state policy, `ProjectionSolution` shows coefficients with convergence diagnostics.

**Output (OccBin):** Piecewise-linear transition path for all endogenous variables.

See [Configuration](../configuration.md#occbin-constraints) for the OccBin constraints TOML format.

## dsge irf

Impulse response functions from a solved DSGE model.

```bash
friedman dsge irf rbc.toml --horizon=40
friedman dsge irf rbc.toml --shock-size=0.5 --n-sim=1000
friedman dsge irf rbc.toml --constraints=occbin.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--horizon` | `-h` | Int | 40 | IRF horizon |
| `--shock-size` | | Float64 | 1.0 | Shock size (std devs) |
| `--n-sim` | | Int | 0 | Simulation-based IRF draws (0 = analytical) |
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output (standard):** Per-shock IRF tables with columns for each endogenous variable.

**Output (OccBin):** Per-variable tables comparing linear vs piecewise-linear IRFs.

## dsge fevd

Forecast error variance decomposition from a solved DSGE model.

```bash
friedman dsge fevd rbc.toml --horizon=40
friedman dsge fevd rbc.toml --method=perturbation --order=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--horizon` | `-h` | Int | 40 | FEVD horizon |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable FEVD proportions table (columns = shocks, rows = horizons).

## dsge simulate

Simulate from a solved DSGE model.

```bash
friedman dsge simulate rbc.toml --periods=500 --burn=200
friedman dsge simulate rbc.toml --seed=42 --antithetic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `gensys` | Solution method |
| `--order` | | Int | 1 | Perturbation order |
| `--periods` | | Int | 200 | Simulation periods (after burn-in) |
| `--burn` | | Int | 100 | Burn-in periods to discard |
| `--seed` | | Int | 0 | Random seed (0 = no seed) |
| `--antithetic` | | Flag | | Use antithetic sampling for variance reduction |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Simulated data table with a column per endogenous variable, periods after burn-in.

## dsge estimate

Estimate DSGE model parameters from data. 4 estimation methods.

```bash
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --method=irf_matching
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --method=smm --sim-ratio=10
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --method=likelihood
friedman dsge estimate rbc.toml --data=macro.csv --params=alpha,beta --bounds=bounds.toml
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

## dsge perfect-foresight

Perfect foresight (deterministic) simulation for transition paths.

```bash
friedman dsge perfect-foresight rbc.toml --shocks=shocks.csv --periods=200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--shocks` | | String | (required) | Path to shock sequence CSV |
| `--periods` | | Int | 100 | Simulation periods |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

The shock CSV must have columns matching the model's exogenous variables and rows for each shock period.

**Output:** Transition path for all endogenous variables, with convergence status.

## dsge steady-state

Compute the steady state of a DSGE model.

```bash
friedman dsge steady-state rbc.toml
friedman dsge steady-state rbc.toml --constraints=occbin.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--constraints` | | String | | Path to OccBin constraints TOML |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Variable names and steady-state values.

## Solution Methods

| Method | `--method` value | When to use |
|--------|-----------------|-------------|
| Gensys (Sims 2002) | `gensys` | Default. Linear rational expectations models |
| Klein (2000) | `klein` | Alternative generalized Schur decomposition solver |
| Perturbation | `perturbation` | Higher-order approximations (order 1 or 2) |
| Projection | `projection` | Global solutions, nonlinear models, accuracy matters |
| Policy Function Iteration | `pfi` | Global solutions, value function problems |

Projection and PFI methods support `--degree` (polynomial degree) and `--grid` (grid type) options.
```

**Step 2: Verify file was created correctly**

Run: `wc -l docs/src/commands/dsge.md`
Expected: ~250 lines

**Step 3: Commit**

```bash
git add docs/src/commands/dsge.md
git commit -m "docs: add dsge.md command reference page"
```

---

### Task 2: Update `docs/make.jl`

**Files:**
- Modify: `docs/make.jl:22` (add dsge page after nowcast)

**Step 1: Add dsge page to pages array**

In `docs/make.jl`, after the `"nowcast"` line (line 22), add:

```julia
            "dsge" => "commands/dsge.md",
```

The pages array should now end with:
```julia
            "nowcast" => "commands/nowcast.md",
            "dsge" => "commands/dsge.md",
        ],
```

**Step 2: Commit**

```bash
git add docs/make.jl
git commit -m "docs: add dsge page to make.jl"
```

---

### Task 3: Update `docs/src/index.md`

**Files:**
- Modify: `docs/src/index.md`

**Step 1: Add DSGE and SMM rows to feature table**

After the Nowcasting row (line 24), add:

```markdown
| **DSGE** | Solve, IRF, FEVD, simulate, estimate, perfect foresight, steady state | `dsge solve`, `dsge irf`, `dsge simulate`, ... |
| **SMM** | Simulated Method of Moments estimation | `estimate smm` |
```

**Step 2: Update command counts**

Change line 31 from:
```markdown
**11 top-level commands, ~103 subcommands.**
```
to:
```markdown
**12 top-level commands, ~117 subcommands.**
```

**Step 3: Add DSGE Quick Start examples**

After the nowcast line in Quick Start (line 58), add:

```bash
# Solve a DSGE model
julia --project bin/friedman dsge solve rbc.toml

# DSGE impulse responses
julia --project bin/friedman dsge irf rbc.toml --horizon=40
```

**Step 4: Add dsge.md to Contents block**

In the `@contents` block, after `"commands/nowcast.md",`, add:
```
    "commands/dsge.md",
```

**Step 5: Commit**

```bash
git add docs/src/index.md
git commit -m "docs: update index.md with DSGE, SMM, new counts"
```

---

### Task 4: Update `docs/src/installation.md`

**Files:**
- Modify: `docs/src/installation.md`

**Step 1: Update Julia version requirement**

Change line 5 from:
```markdown
- **Julia 1.10+** (tested on 1.10, 1.11, and 1.12)
```
to:
```markdown
- **Julia 1.12+**
```

**Step 2: Add optional dependencies note**

After the install block (after line 18), add:

```markdown
### Optional Dependencies

For DSGE constrained solvers (OccBin), install JuMP and Ipopt:

```bash
julia --project -e 'using Pkg; Pkg.add(["JuMP", "Ipopt"])'
```

For GDFM spectral methods, install FFTW:

```bash
julia --project -e 'using Pkg; Pkg.add("FFTW")'
```
```

**Step 3: Commit**

```bash
git add docs/src/installation.md
git commit -m "docs: update installation.md — Julia 1.12+, optional deps"
```

---

### Task 5: Update `docs/src/commands/overview.md`

**Files:**
- Modify: `docs/src/commands/overview.md`

**Step 1: Add dsge row to command tree**

After the `nowcast` line (line 27), add:
```
├── dsge         solve | irf | fevd | simulate | estimate |
│                perfect-foresight | steady-state
```

Also add `smm` to the estimate row (line 9):
```
├── estimate     var | bvar | lp | arima | gmm | static | dynamic | gdfm |
│                arch | garch | egarch | gjr_garch | sv | fastica | ml | vecm | pvar | smm
```

**Step 2: Update command counts**

Change line 30 from:
```markdown
**Total: 11 top-level commands, ~103 subcommands.**
```
to:
```markdown
**Total: 12 top-level commands, ~117 subcommands.**
```

**Step 3: Commit**

```bash
git add docs/src/commands/overview.md
git commit -m "docs: update overview.md — add dsge, smm, update counts"
```

---

### Task 6: Update `docs/src/commands/estimate.md`

**Files:**
- Modify: `docs/src/commands/estimate.md`

**Step 1: Update intro**

Change line 1 description from "17 subcommands" to "18 subcommands":
```markdown
Estimate econometric models. 18 subcommands covering VAR, BVAR, VECM, Panel VAR, local projections, ARIMA, GMM, SMM, factor models, volatility models, and non-Gaussian SVAR identification.
```

**Step 2: Add estimate smm section after estimate gmm (after line 158)**

```markdown
## estimate smm

Estimate via Simulated Method of Moments. Can use TOML config for specification overrides.

```bash
friedman estimate smm data.csv --weighting=two_step --sim-ratio=5
friedman estimate smm data.csv --config=smm_spec.toml
friedman estimate smm data.csv --weighting=optimal --burn=200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | | TOML config file for SMM specification |
| `--weighting` | | String | `two_step` | `identity`, `optimal`, `two_step`, `iterated` |
| `--sim-ratio` | | Int | 5 | Simulation-to-sample ratio |
| `--burn` | | Int | 100 | Burn-in periods |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates with standard errors, t-statistics, and p-values. Includes J-statistic and convergence status.

See [Configuration](../configuration.md#smm-specification) for TOML format.
```

**Step 3: Commit**

```bash
git add docs/src/commands/estimate.md
git commit -m "docs: add estimate smm section, update subcommand count"
```

---

### Task 7: Update `docs/src/commands/forecast.md`

**Files:**
- Modify: `docs/src/commands/forecast.md`

**Step 1: Add VARForecast/BVARForecast typed return note**

After the `forecast var` output line (after line 26), add:

```markdown
!!! note "v0.3.0"
    VAR forecasts now return typed `VARForecast` objects with accessor functions: `point_forecast()`, `lower_bound()`, `upper_bound()`, `forecast_horizon()`.
```

After the `forecast bvar` options table (after line 45), add:

```markdown
!!! note "v0.3.0"
    BVAR forecasts now return typed `BVARForecast` objects with the same accessor interface as `VARForecast`.
```

**Step 2: Add LPForecast field rename note**

After the `forecast lp` description (around line 49), add:

```markdown
!!! note "v0.3.0"
    `LPForecast` field renamed: `.forecast` (was `.forecasts` in earlier versions).
```

**Step 3: Add DSGE cross-reference**

At the end of the file, add:

```markdown
## See Also

For DSGE model forecasting via simulation, see [dsge simulate](dsge.md#dsge-simulate).
```

**Step 4: Commit**

```bash
git add docs/src/commands/forecast.md
git commit -m "docs: update forecast.md — typed returns, LPForecast rename, DSGE xref"
```

---

### Task 8: Update `docs/src/commands/irf.md` and `docs/src/commands/fevd.md`

**Files:**
- Modify: `docs/src/commands/irf.md`
- Modify: `docs/src/commands/fevd.md`

**Step 1: Add DSGE cross-reference to irf.md**

At the end of `docs/src/commands/irf.md`, add:

```markdown
## See Also

For DSGE model IRFs, see [dsge irf](dsge.md#dsge-irf).
```

**Step 2: Add DSGE cross-reference to fevd.md**

At the end of `docs/src/commands/fevd.md`, add:

```markdown
## See Also

For DSGE model FEVD, see [dsge fevd](dsge.md#dsge-fevd).
```

**Step 3: Commit**

```bash
git add docs/src/commands/irf.md docs/src/commands/fevd.md
git commit -m "docs: add DSGE cross-references to irf.md and fevd.md"
```

---

### Task 9: Update `docs/src/configuration.md`

**Files:**
- Modify: `docs/src/configuration.md`

**Step 1: Add DSGE Model TOML section**

After the GMM section (after line 169), add:

```markdown
## DSGE Model

Used by `dsge solve`, `dsge irf`, `dsge fevd`, `dsge simulate`, `dsge estimate`, `dsge perfect-foresight`, `dsge steady-state`.

```toml
[model]
endogenous = ["y", "c", "k", "n"]
exogenous = ["eps_a"]

[model.parameters]
alpha = 0.36
beta = 0.99
delta = 0.025
sigma = 1.0
phi_n = 1.0

[[model.equations]]
expr = "c^(-sigma) = beta * c(+1)^(-sigma) * (alpha * exp(eps_a(+1)) * k^(alpha-1) * n(+1)^(1-alpha) + 1 - delta)"

[[model.equations]]
expr = "phi_n * n^phi_n = c^(-sigma) * (1-alpha) * exp(eps_a) * k(-1)^alpha * n^(-alpha)"

[[model.equations]]
expr = "k = (1-delta)*k(-1) + y - c"

[[model.equations]]
expr = "y = exp(eps_a) * k(-1)^alpha * n^(1-alpha)"

[solver]
method = "gensys"    # gensys|klein|perturbation|projection|pfi
order = 1            # perturbation order
degree = 5           # polynomial degree (projection/pfi)
grid = "auto"        # auto|chebyshev|smolyak
```

| Section | Description |
|---------|-------------|
| `[model]` | Lists endogenous/exogenous variables |
| `[model.parameters]` | Deep parameters with values |
| `[[model.equations]]` | Model equations (one per block, `expr` field) |
| `[solver]` | Solution method and settings |

Time notation: `x(+1)` = lead, `x(-1)` = lag, `x` = current.

## OccBin Constraints

Used by `dsge solve --constraints=...`, `dsge irf --constraints=...`, `dsge steady-state --constraints=...`.

```toml
[constraints]

[[constraints.bounds]]
variable = "i_rate"
lower = 0.0

[[constraints.bounds]]
variable = "investment"
lower = 0.0
upper = 100.0
```

Each `[[constraints.bounds]]` block specifies a variable with optional `lower` and/or `upper` bounds. The OccBin algorithm solves the piecewise-linear system respecting these occasionally binding constraints.

## SMM Specification

Used by `estimate smm --config=...`.

```toml
[smm]
weighting = "two_step"    # identity|optimal|two_step|iterated
sim_ratio = 5             # simulation-to-sample ratio
burn = 100                # burn-in periods for simulation
```

| Field | Default | Description |
|-------|---------|-------------|
| `weighting` | `two_step` | Weighting matrix method |
| `sim_ratio` | `5` | How many simulated observations per data observation |
| `burn` | `100` | Discard this many initial simulation periods |
```

**Step 2: Commit**

```bash
git add docs/src/configuration.md
git commit -m "docs: add DSGE model, OccBin constraints, SMM config sections"
```

---

### Task 10: Update `docs/src/api.md`

**Files:**
- Modify: `docs/src/api.md`

**Step 1: Add DSGE config functions**

After the `Friedman.get_uhlig_params` line (line 67), add:

```markdown
Friedman.get_dsge
Friedman.get_dsge_constraints
Friedman.get_smm
```

**Step 2: Add DSGE shared utilities**

After the `Friedman.load_panel_data` line (line 86), add:

```markdown
Friedman._load_dsge_model
Friedman._solve_dsge
Friedman._load_dsge_constraints
Friedman._per_var_output_path
```

**Step 3: Add DSGE command registration**

After the Shared Utilities section (after the closing ` ``` `), add:

```markdown
## DSGE Commands

```@docs
Friedman.register_dsge_commands!
```
```

**Step 4: Commit**

```bash
git add docs/src/api.md
git commit -m "docs: add DSGE and SMM functions to api.md"
```

---

### Task 11: Update `docs/src/architecture.md`

**Files:**
- Modify: `docs/src/architecture.md`

**Step 1: Update register function count and add dsge**

In the Execution Flow section, change line 12 from:
```
      → register_estimate_commands!()      # 11 register functions, one per top-level command
```
to:
```
      → register_estimate_commands!()      # 12 register functions, one per top-level command
```

Add after `register_nowcast_commands!()` (line 22):
```
      → register_dsge_commands!()
```

**Step 2: Add dsge.jl to Module Structure**

In the Module Structure section, after `nowcast.jl` (line 108), add:
```
    dsge.jl               # 7 DSGE subcommands
```

Update `estimate.jl` line to say "18" instead of "17":
```
    estimate.jl           # 18 estimation subcommands
```

**Step 3: Update Dependencies table**

Add these rows to the dependencies table (after line 129):

```markdown
| `SparseArrays` (stdlib) | Sparse matrix operations |
| `Random` (stdlib) | Random number generation (DSGE simulation) |
```

**Step 4: Commit**

```bash
git add docs/src/architecture.md
git commit -m "docs: update architecture.md — dsge.jl, 12 commands, new deps"
```

---

### Task 12: Refresh unchanged pages

**Files:**
- Verify: `docs/src/commands/test.md` — confirm LR/LM use data1/data2/lags1/lags2 interface ✓ (lines 267-304)
- Verify: `docs/src/commands/hd.md` — no DSGE HD subcommand, no changes needed ✓
- Verify: `docs/src/commands/predict_residuals.md` — verify 12 model types listed ✓ (lines 9-22)
- Verify: `docs/src/commands/filter.md` — verify bn --method=statespace documented ✓ (lines 48-68)
- Verify: `docs/src/commands/data.md` — verify 9 subcommands including balance ✓ (lines 1, 162-178)
- Verify: `docs/src/commands/nowcast.md` — verify 5 subcommands documented ✓ (lines 1-128)

**Step 1: Verify each unchanged page against source code**

Read each file and confirm:
- `test.md`: LR test uses `<data1>` and `<data2>` positional args with `--lags1`/`--lags2` options — matches current source. ✓
- `hd.md`: 4 subcommands (var, bvar, lp, vecm) — correct, no DSGE HD exists. ✓
- `predict_residuals.md`: 12 subcommands each — correct. ✓
- `filter.md`: 5 subcommands, bn has `--method` with `arima`/`statespace` — correct. ✓
- `data.md`: 9 subcommands (list, load, describe, diagnose, fix, transform, filter, validate, balance) — correct. ✓
- `nowcast.md`: 5 subcommands (dfm, bvar, bridge, news, forecast) — correct. ✓

No edits needed for these files. They are already current.

---

### Task 13: Build and verify docs

**Step 1: Install docs dependencies**

Run: `julia --project=docs -e 'using Pkg; Pkg.instantiate()'`

**Step 2: Build docs**

Run: `julia --project=docs docs/make.jl`
Expected: Build succeeds with no errors. Warnings about missing docstrings (already in `warnonly`) are acceptable.

**Step 3: Verify dsge page exists**

Run: `ls docs/build/commands/dsge/`
Expected: `index.html` exists

**Step 4: Commit all changes and push**

```bash
git add -A docs/
git commit -m "docs: complete v0.3.0 documentation update"
```

---

## Summary

| Task | File(s) | Action |
|------|---------|--------|
| 1 | `docs/src/commands/dsge.md` | Create (~250 lines) |
| 2 | `docs/make.jl` | Add dsge page |
| 3 | `docs/src/index.md` | DSGE/SMM rows, counts, examples, contents |
| 4 | `docs/src/installation.md` | Julia 1.12+, optional deps |
| 5 | `docs/src/commands/overview.md` | dsge row, smm, counts |
| 6 | `docs/src/commands/estimate.md` | estimate smm section, count |
| 7 | `docs/src/commands/forecast.md` | Typed returns, LPForecast rename, DSGE xref |
| 8 | `docs/src/commands/irf.md`, `fevd.md` | DSGE cross-references |
| 9 | `docs/src/configuration.md` | DSGE, OccBin, SMM config sections |
| 10 | `docs/src/api.md` | DSGE/SMM function references |
| 11 | `docs/src/architecture.md` | dsge.jl, 12 commands, deps |
| 12 | 6 unchanged pages | Verify consistency (no edits) |
| 13 | All | Build verification |

**Estimated total: ~350 new lines (dsge.md) + ~200 lines updates across 10 files.**
