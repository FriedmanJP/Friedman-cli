# Friedman-cli v0.3.4 (MEMs v0.3.5) Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bump Friedman-cli to v0.3.4 wrapping MEMs v0.3.5, adding `--warranty`/`--conditions` root flags and updating OccBinSolution mock for new `constraints` field.

**Architecture:** Two changes — (1) version bump across 4 files + mock update for OccBinSolution.constraints field, (2) pre-dispatch flag handling in `main()` for `--warranty`/`--conditions` that call through to MEMs functions.

**Tech Stack:** Julia 1.12, MacroEconometricModels.jl v0.3.5, existing CLI framework

---

### Task 1: Update mock OccBinSolution with constraints field

**Files:**
- Modify: `test/mocks.jl:1547-1551` (OccBinSolution struct)
- Modify: `test/mocks.jl:1659-1666` (occbin_solve function)

**Step 1: Update OccBinSolution struct to include constraints field**

In `test/mocks.jl`, find the struct at line 1547:

```julia
struct OccBinSolution{T<:Real}
    linear_path::Matrix{T}; piecewise_path::Matrix{T}; steady_state::Vector{T}
    regime_history::Vector{Int}; converged::Bool; iterations::Int
    spec::DSGESpec{T}; varnames::Vector{String}
end
```

Replace with:

```julia
struct OccBinSolution{T<:Real}
    linear_path::Matrix{T}; piecewise_path::Matrix{T}; steady_state::Vector{T}
    regime_history::Vector{Int}; converged::Bool; iterations::Int
    spec::DSGESpec{T}; varnames::Vector{String}
    constraints::Vector{OccBinConstraint{T}}
end
```

**Step 2: Update occbin_solve to pass constraints through**

In `test/mocks.jl`, find the function at line 1659:

```julia
function occbin_solve(spec::DSGESpec{T}, shocks, constraints; T_periods=40, kwargs...) where T
    n = spec.n_endog
    lp = zeros(T, T_periods, n)
    pp = zeros(T, T_periods, n)
    ss = zeros(T, n)
    regimes = ones(Int, T_periods)
    OccBinSolution{T}(lp, pp, ss, regimes, true, 15, spec, spec.varnames)
end
```

Replace the last line with:

```julia
    cons = constraints isa Vector ? constraints : [constraints]
    OccBinSolution{T}(lp, pp, ss, regimes, true, 15, spec, spec.varnames, cons)
```

**Step 3: Run tests to verify mocks still work**

Run: `julia --project test/runtests.jl`
Expected: All tests pass (existing OccBin/DSGE tests use occbin_solve which now constructs with the extra field)

**Step 4: Commit**

```
git add test/mocks.jl
git commit -m "test: add constraints field to mock OccBinSolution for MEMs v0.3.5"
```

---

### Task 2: Add warranty() and conditions() mocks

**Files:**
- Modify: `test/mocks.jl:2643-2645` (before final `end`)

**Step 1: Add mock functions and exports**

Before the final `end # module` at line 2645, add:

```julia
# ─── GPL Notice Functions ────────────────────────────────────

function warranty()
    println("THERE IS NO WARRANTY FOR THE PROGRAM (mock)")
    nothing
end

function conditions()
    println("You may convey verbatim copies of the Program (mock)")
    nothing
end

export warranty, conditions
```

**Step 2: Run tests to verify**

Run: `julia --project test/runtests.jl`
Expected: All existing tests still pass

**Step 3: Commit**

```
git add test/mocks.jl
git commit -m "test: add warranty/conditions mock functions for MEMs v0.3.5"
```

---

### Task 3: Add --warranty/--conditions flag handling in dispatch

**Files:**
- Modify: `src/cli/dispatch.jl:31-36` (dispatch function)

**Step 1: Write the failing test**

In `test/runtests.jl`, find the dispatch testset (around line 486). After the existing `-V` short flag test (around line 553), add:

```julia
        # --warranty flag prints warranty text
        warranty_output = capture_stdout(() -> dispatch(entry, ["--warranty"]))
        @test contains(warranty_output, "WARRANTY")

        # --conditions flag prints conditions text
        conditions_output = capture_stdout(() -> dispatch(entry, ["--conditions"]))
        @test contains(conditions_output, "copies")
```

**Step 2: Run test to verify it fails**

Run: `julia --project test/runtests.jl`
Expected: FAIL — dispatch doesn't handle `--warranty`/`--conditions` yet

**Step 3: Implement in dispatch.jl**

In `src/cli/dispatch.jl`, inside the `dispatch()` function (line 31), after the `--version` check (lines 33-36) and before the `--help` check (line 39), add:

```julia
    # Handle --warranty / --conditions (GPL notice)
    if "--warranty" in args
        MacroEconometricModels.warranty()
        return
    end
    if "--conditions" in args
        MacroEconometricModels.conditions()
        return
    end
```

Note: `dispatch.jl` is included inside the `Friedman` module which has `using MacroEconometricModels`, so `MacroEconometricModels.warranty()` is accessible. In the test context, the mock module provides these functions.

**Step 4: Run tests to verify they pass**

Run: `julia --project test/runtests.jl`
Expected: All tests pass including the new --warranty/--conditions tests

**Step 5: Commit**

```
git add src/cli/dispatch.jl test/runtests.jl
git commit -m "feat: add --warranty and --conditions root flags for GPL notice"
```

---

### Task 4: Version bump

**Files:**
- Modify: `Project.toml:3` (version) and `Project.toml:25` (compat)
- Modify: `src/Friedman.jl:53` (FRIEDMAN_VERSION)
- Modify: `src/cli/types.jl:111` (Entry default version)
- Modify: `test/runtests.jl` (6 version string refs)

**Step 1: Update Project.toml**

Line 3: `version = "0.3.3"` → `version = "0.3.4"`
Line 25: `MacroEconometricModels = "0.3.4"` → `MacroEconometricModels = "0.3.5"`

**Step 2: Update FRIEDMAN_VERSION**

In `src/Friedman.jl` line 53: `const FRIEDMAN_VERSION = v"0.3.3"` → `const FRIEDMAN_VERSION = v"0.3.4"`

**Step 3: Update Entry default version**

In `src/cli/types.jl` line 111: `version::VersionNumber=v"0.3.1"` → `version::VersionNumber=v"0.3.4"`

**Step 4: Update test version refs**

In `test/runtests.jl`, replace all 6 occurrences:
- Line 384: `version=v"0.3.3"` → `version=v"0.3.4"`
- Line 388: `"0.3.3"` → `"0.3.4"`
- Line 503: `version=v"0.3.3"` → `version=v"0.3.4"`
- Line 505: `"0.3.3"` → `"0.3.4"`
- Line 553: `"0.3.3"` → `"0.3.4"`
- Line 1485: `version=v"0.3.3"` → `version=v"0.3.4"`

**Step 5: Run tests**

Run: `julia --project test/runtests.jl`
Expected: All tests pass

**Step 6: Commit**

```
git add Project.toml src/Friedman.jl src/cli/types.jl test/runtests.jl
git commit -m "chore: bump version to v0.3.4, MEMs compat to v0.3.5"
```

---

### Task 5: Documentation updates

**Files:**
- Modify: `CLAUDE.md` — version in Project Overview, Common Options mention --warranty/--conditions
- Modify: `README.md` — version refs, global flags table
- Modify: `API_REFERENCE.md` — version ref line 3
- Modify: `docs/` — relevant Documenter pages

**Step 1: Update CLAUDE.md**

- Line 9 (Project Overview): change `v0.3.3` → `v0.3.4` and `v0.3.4` → `v0.3.5` for MEMs
- In Common Options table, add `--warranty` and `--conditions` flags
- Update any other version references

**Step 2: Update README.md**

- Update version references from `0.3.3` → `0.3.4`
- Add `--warranty`/`--conditions` to the global flags section (near `--version`/`--help`)

**Step 3: Update API_REFERENCE.md**

- Line 3: `v0.3.3` → `v0.3.5` (upstream MEMs version)

**Step 4: Update docs/ pages**

- `docs/src/index.md`: version references
- `docs/src/commands/overview.md`: add --warranty/--conditions to global flags if listed
- `docs/src/architecture.md`: update version refs if present

**Step 5: Commit**

```
git add CLAUDE.md README.md API_REFERENCE.md docs/
git commit -m "docs: update documentation for v0.3.4 — MEMs v0.3.5, --warranty/--conditions flags"
```
