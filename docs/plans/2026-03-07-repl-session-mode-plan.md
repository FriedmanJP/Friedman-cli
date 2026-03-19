# REPL / Interactive Session Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `friedman repl` command that launches an interactive REPL with in-memory data caching, result caching, and tab completion — resolving issue #4.

**Architecture:** New `src/repl.jl` file contains Session struct, REPL loop (Julia `REPL.LineEdit`), dispatch wrapper, and tab completion. Estimate handlers (~24) get `return model` at end. Downstream handlers (~65 across irf/fevd/hd/forecast/predict/residuals) get `model=nothing` kwarg with early-exit branch. REPL wrapper injects session data path and cached models before dispatching. One-shot CLI completely unchanged.

**Tech Stack:** Julia 1.12, `REPL.LineEdit` (stdlib), existing CLI dispatch engine

---

### Task 1: Session struct and state management

**Files:**
- Create: `src/repl.jl`
- Test: `test/test_repl.jl`

**Step 1: Write failing tests for Session struct**

Create `test/test_repl.jl`:

```julia
using Test

# Include CLI engine + IO files (same as runtests.jl)
include("mocks.jl")

# Will include repl.jl after it exists
# For now, test Session struct API

@testset "Session state management" begin
    @testset "Session initialization" begin
        s = Friedman.Session()
        @test s.data_path == ""
        @test isnothing(s.df)
        @test isnothing(s.Y)
        @test isempty(s.varnames)
        @test isempty(s.results)
        @test s.last_model == :none
    end

    @testset "session_load_data!" begin
        s = Friedman.Session()
        # Create temp CSV
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "x,y,z")
            println(io, "1.0,2.0,3.0")
            println(io, "4.0,5.0,6.0")
            println(io, "7.0,8.0,9.0")
        end

        Friedman.session_load_data!(s, tmpfile)
        @test s.data_path == tmpfile
        @test !isnothing(s.df)
        @test size(s.Y) == (3, 3)
        @test s.varnames == ["x", "y", "z"]
        @test isempty(s.results)

        rm(tmpfile; force=true)
    end

    @testset "session_load_data! clears results" begin
        s = Friedman.Session()
        s.results[:var] = "fake_model"
        s.last_model = :var

        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "a,b")
            println(io, "1.0,2.0")
            println(io, "3.0,4.0")
        end

        Friedman.session_load_data!(s, tmpfile)
        @test isempty(s.results)
        @test s.last_model == :none

        rm(tmpfile; force=true)
    end

    @testset "session_clear!" begin
        s = Friedman.Session()
        s.data_path = "test.csv"
        s.results[:var] = "fake"
        s.last_model = :var

        Friedman.session_clear!(s)
        @test s.data_path == ""
        @test isnothing(s.df)
        @test isnothing(s.Y)
        @test isempty(s.varnames)
        @test isempty(s.results)
        @test s.last_model == :none
    end

    @testset "session_store_result!" begin
        s = Friedman.Session()
        Friedman.session_store_result!(s, :var, "var_model")
        @test s.results[:var] == "var_model"
        @test s.last_model == :var

        Friedman.session_store_result!(s, :bvar, "bvar_model")
        @test s.results[:bvar] == "bvar_model"
        @test s.last_model == :bvar
        @test s.results[:var] == "var_model"  # still there

        # Re-estimate same model replaces
        Friedman.session_store_result!(s, :var, "var_model_v2")
        @test s.results[:var] == "var_model_v2"
        @test s.last_model == :var
    end

    @testset "session_has_data" begin
        s = Friedman.Session()
        @test !Friedman.session_has_data(s)
        s.data_path = "test.csv"
        @test Friedman.session_has_data(s)
    end

    @testset "session_get_result" begin
        s = Friedman.Session()
        @test isnothing(Friedman.session_get_result(s, :var))

        Friedman.session_store_result!(s, :var, "model")
        @test Friedman.session_get_result(s, :var) == "model"
        @test isnothing(Friedman.session_get_result(s, :bvar))
    end
end
```

**Step 2: Run tests to verify they fail**

Run: `julia --project -e 'include("test/test_repl.jl")'`
Expected: FAIL — `Friedman.Session` not defined

**Step 3: Implement Session struct**

Create `src/repl.jl`:

```julia
# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# REPL / interactive session mode

"""
    Session

Mutable state for the interactive REPL session.
"""
mutable struct Session
    data_path::String
    df::Union{DataFrame,Nothing}
    Y::Union{Matrix{Float64},Nothing}
    varnames::Vector{String}
    results::Dict{Symbol,Any}
    last_model::Symbol
end

Session() = Session("", nothing, nothing, String[], Dict{Symbol,Any}(), :none)

function session_load_data!(s::Session, path::String)
    df = load_data(path)
    Y = df_to_matrix(df)
    vnames = variable_names(df)
    s.data_path = path
    s.df = df
    s.Y = Y
    s.varnames = vnames
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end

function session_clear!(s::Session)
    s.data_path = ""
    s.df = nothing
    s.Y = nothing
    s.varnames = String[]
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end

function session_store_result!(s::Session, model_type::Symbol, result)
    s.results[model_type] = result
    s.last_model = model_type
    return s
end

session_has_data(s::Session) = !isempty(s.data_path)

session_get_result(s::Session, model_type::Symbol) = get(s.results, model_type, nothing)

const SESSION = Session()
```

Add to `src/Friedman.jl`, after the commands includes and before `FRIEDMAN_VERSION`:

```julia
# REPL (interactive session)
include("repl.jl")
```

**Step 4: Run tests to verify they pass**

Run: `julia --project -e 'include("test/test_repl.jl")'`
Expected: All pass

**Step 5: Run existing tests to verify no regression**

Run: `julia --project test/runtests.jl`
Expected: All ~2,162 tests pass

**Step 6: Commit**

```bash
git add src/repl.jl src/Friedman.jl test/test_repl.jl
git commit -m "feat: add Session struct and state management for REPL mode"
```

---

### Task 2: Built-in dataset loading via :name syntax

**Files:**
- Modify: `src/repl.jl`
- Modify: `test/test_repl.jl`

**Step 1: Write failing test**

Add to `test/test_repl.jl`:

```julia
    @testset "session_load_builtin!" begin
        s = Friedman.Session()
        # Mock load_example exists in mocks.jl
        Friedman.session_load_builtin!(s, :fred_md)
        @test s.data_path == ":fred-md"
        @test !isnothing(s.df)
        @test !isnothing(s.Y)
    end

    @testset "parse_data_source" begin
        @test Friedman.parse_data_source(":fred-md") == (:builtin, :fred_md)
        @test Friedman.parse_data_source(":fred-qd") == (:builtin, :fred_qd)
        @test Friedman.parse_data_source(":pwt") == (:builtin, :pwt)
        @test Friedman.parse_data_source(":mpdta") == (:builtin, :mpdta)
        @test Friedman.parse_data_source(":ddcg") == (:builtin, :ddcg)
        @test Friedman.parse_data_source("myfile.csv") == (:file, "myfile.csv")
    end
```

**Step 2: Implement**

Add to `src/repl.jl`:

```julia
const BUILTIN_DATASETS = Dict(
    "fred-md" => :fred_md, "fred-qd" => :fred_qd,
    "pwt" => :pwt, "mpdta" => :mpdta, "ddcg" => :ddcg,
)

function parse_data_source(source::String)
    if startswith(source, ":")
        name = source[2:end]
        haskey(BUILTIN_DATASETS, name) || error("unknown built-in dataset ':$name'. Available: $(join(keys(BUILTIN_DATASETS), ", "))")
        return (:builtin, BUILTIN_DATASETS[name])
    else
        return (:file, source)
    end
end

function session_load_builtin!(s::Session, name::Symbol)
    ts = load_example(name)
    df = DataFrame(ts.data, ts.varnames)
    Y = Matrix{Float64}(ts.data)
    s.data_path = ":$(replace(string(name), "_" => "-"))"
    s.df = df
    s.Y = Y
    s.varnames = ts.varnames
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end
```

**Step 3: Run tests, verify pass**

Run: `julia --project -e 'include("test/test_repl.jl")'`

**Step 4: Commit**

```bash
git add src/repl.jl test/test_repl.jl
git commit -m "feat: add built-in dataset loading via :name syntax"
```

---

### Task 3: REPL dispatch wrapper (data injection)

**Files:**
- Modify: `src/repl.jl`
- Modify: `test/test_repl.jl`

**Step 1: Write failing tests**

Add to `test/test_repl.jl`:

```julia
@testset "REPL dispatch wrapper" begin
    @testset "inject_session_data" begin
        s = Friedman.Session()
        s.data_path = "/tmp/test.csv"

        # Args with no data positional — inject before options
        args = ["estimate", "var", "--lags", "4"]
        result = Friedman.inject_session_data(s, args)
        @test result == ["estimate", "var", "/tmp/test.csv", "--lags", "4"]

        # Args already have data (a .csv path) — don't inject
        args2 = ["estimate", "var", "mydata.csv", "--lags", "4"]
        result2 = Friedman.inject_session_data(s, args2)
        @test result2 == args2

        # No session data — return unchanged
        s2 = Friedman.Session()
        result3 = Friedman.inject_session_data(s2, args)
        @test result3 == args
    end

    @testset "detect_model_type" begin
        @test Friedman.detect_model_type(["estimate", "var"]) == :var
        @test Friedman.detect_model_type(["estimate", "bvar"]) == :bvar
        @test Friedman.detect_model_type(["irf", "var"]) == :var
        @test Friedman.detect_model_type(["test", "adf"]) == :adf
        @test Friedman.detect_model_type(["data", "use"]) == :none
    end

    @testset "is_estimate_command" begin
        @test Friedman.is_estimate_command(["estimate", "var", "d.csv"])
        @test !Friedman.is_estimate_command(["irf", "var", "d.csv"])
        @test !Friedman.is_estimate_command(["data", "use", "d.csv"])
    end
end
```

**Step 2: Implement**

Add to `src/repl.jl`:

```julia
"""
    inject_session_data(session, args) → args

If session has data loaded and the command args don't already include a data file,
inject the session data path after the subcommand token and before any options.
"""
function inject_session_data(s::Session, args::Vector{String})
    session_has_data(s) || return args
    length(args) < 2 && return args

    # Check if any positional arg looks like a file path (not starting with -)
    # Position: after command + subcommand, before first option
    cmd_depth = _command_depth(args)
    positionals_start = cmd_depth + 1

    # Check if there's already a positional arg (non-option) after the subcommand
    has_positional = false
    for i in positionals_start:length(args)
        arg = args[i]
        startswith(arg, "-") && break
        has_positional = true
        break
    end

    has_positional && return args

    # Inject data path after the subcommand tokens
    new_args = copy(args)
    insert!(new_args, positionals_start, s.data_path)
    return new_args
end

"""
    _command_depth(args) → Int

Count how many leading tokens are command/subcommand names (not options or data files).
Returns 2 for "estimate var", 3 for "dsge bayes estimate", etc.
"""
function _command_depth(args::Vector{String})
    depth = 0
    for arg in args
        startswith(arg, "-") && break
        # Heuristic: if it looks like a file path, stop
        (endswith(arg, ".csv") || endswith(arg, ".toml") || endswith(arg, ".jl") || contains(arg, "/") || contains(arg, "\\")) && break
        depth += 1
        depth >= 4 && break  # max nesting: friedman dsge bayes estimate
    end
    return depth
end

function detect_model_type(args::Vector{String})
    length(args) >= 2 || return :none
    return Symbol(args[2])
end

function is_estimate_command(args::Vector{String})
    !isempty(args) && args[1] == "estimate"
end
```

**Step 3: Run tests, verify pass**

**Step 4: Commit**

```bash
git add src/repl.jl test/test_repl.jl
git commit -m "feat: add REPL dispatch wrapper with data injection"
```

---

### Task 4: REPL loop with LineEdit

**Files:**
- Modify: `src/repl.jl`
- Modify: `src/Friedman.jl`
- Modify: `src/cli/dispatch.jl`

**Step 1: Implement the REPL loop**

Add to `src/repl.jl`:

```julia
using REPL
using REPL.LineEdit

"""
    repl_dispatch(session, app, args)

Dispatch a command within the REPL. Handles REPL-specific commands
(data use/current/clear, exit/quit), injects session data, captures
estimation results. Never calls exit().
"""
function repl_dispatch(s::Session, app::Entry, args::Vector{String})
    isempty(args) && return

    # REPL-only commands
    if args[1] == "exit" || args[1] == "quit"
        throw(InterruptException())
    end

    # data use / data current / data clear
    if length(args) >= 2 && args[1] == "data"
        if args[2] == "use" && length(args) >= 3
            source = args[3]
            kind, val = parse_data_source(source)
            if kind == :builtin
                session_load_builtin!(s, val)
            else
                session_load_data!(s, val)
            end
            printstyled("✓ "; color=:green)
            println("Loaded $(s.data_path) ($(size(s.Y, 1))×$(size(s.Y, 2)), vars: $(join(s.varnames, ", ")))")
            return
        elseif args[2] == "current"
            if session_has_data(s)
                println("$(s.data_path) ($(size(s.Y, 1))×$(size(s.Y, 2)))")
                if !isempty(s.results)
                    println("Cached results: $(join(keys(s.results), ", "))")
                end
            else
                println("No data loaded")
            end
            return
        elseif args[2] == "clear"
            session_clear!(s)
            printstyled("✓ "; color=:green)
            println("Data and results cleared")
            return
        end
    end

    # Inject session data if needed
    args = inject_session_data(s, args)

    # Dispatch through existing engine
    dispatch(app, args)

    # Note: result capture (Task 6) will hook in here
end

"""
    start_repl()

Launch the interactive REPL with a `friedman>` prompt.
"""
function start_repl()
    app = build_app()
    s = SESSION
    session_clear!(s)

    printstyled("Friedman REPL v$(FRIEDMAN_VERSION)\n"; bold=true)
    println("Type commands as you would on the command line. Type 'exit' to quit.")
    println()

    # Use basic readline loop (LineEdit integration in Task 9)
    while true
        try
            printstyled("friedman> "; color=:blue, bold=true)
            line = readline(stdin)
            isempty(strip(line)) && continue

            args = _split_repl_line(line)
            try
                repl_dispatch(s, app, args)
            catch e
                if e isa InterruptException
                    println("Goodbye!")
                    return
                elseif e isa ParseError || e isa DispatchError
                    printstyled(stderr, "Error: "; bold=true, color=:red)
                    println(stderr, e.message)
                else
                    printstyled(stderr, "Error: "; bold=true, color=:red)
                    println(stderr, sprint(showerror, e))
                end
            end
        catch e
            if e isa EOFError || e isa InterruptException
                println("\nGoodbye!")
                return
            end
            rethrow()
        end
    end
end

"""
    _split_repl_line(line) → Vector{String}

Split a REPL input line into tokens, respecting quoted strings.
"""
function _split_repl_line(line::String)
    tokens = String[]
    i = 1
    while i <= length(line)
        # Skip whitespace
        while i <= length(line) && isspace(line[i])
            i += 1
        end
        i > length(line) && break

        if line[i] == '"'
            # Quoted string
            j = findnext('"', line, i + 1)
            if isnothing(j)
                push!(tokens, line[i+1:end])
                break
            end
            push!(tokens, line[i+1:j-1])
            i = j + 1
        else
            # Unquoted token
            j = findnext(isspace, line, i)
            if isnothing(j)
                push!(tokens, line[i:end])
                break
            end
            push!(tokens, line[i:j-1])
            i = j
        end
    end
    return tokens
end
```

**Step 2: Add `repl` command to dispatch and entry point**

In `src/Friedman.jl`, modify `main()`:

```julia
function main(args::Vector{String}=ARGS)
    # Launch REPL if "repl" is the first argument
    if !isempty(args) && args[1] == "repl"
        start_repl()
        return
    end

    app = build_app()
    try
        dispatch(app, args)
    catch e
        if e isa ParseError || e isa DispatchError
            printstyled(stderr, "Error: "; bold=true, color=:red)
            println(stderr, e.message)
            exit(1)
        else
            rethrow()
        end
    end
end
```

**Step 3: Run existing tests**

Run: `julia --project test/runtests.jl`
Expected: All tests pass (main() behavior unchanged when args don't start with "repl")

**Step 4: Commit**

```bash
git add src/repl.jl src/Friedman.jl
git commit -m "feat: add REPL loop with data use/current/clear commands"
```

---

### Task 5: Estimate handlers return results

**Files:**
- Modify: `src/commands/estimate.jl` (~24 handlers)
- Modify: `src/commands/shared.jl` (LP dispatcher)

This is a mechanical change. For each handler function `_estimate_X`, add `return <result_var>` as the last line. The result variable is identified per handler below.

**Step 1: Add return statements to all estimate handlers**

In `src/commands/estimate.jl`, add `return` at the end of each handler:

| Handler | Line | Add | Return variable |
|---------|------|-----|-----------------|
| `_estimate_var` | ~384 | `return model` | `model` |
| `_estimate_bvar` | ~420 | `return model` | `model` |
| `_estimate_lp` (dispatcher) | ~444 | `return result` | see below |
| `_estimate_lp_standard` | ~495 | `return slp` | `slp` |
| `_estimate_lp_iv` | ~532 | `return slp` | `slp` |
| `_estimate_lp_smooth` | ~562 | `return slp` | `slp` |
| `_estimate_lp_state` | ~598 | `return slp` | `slp` |
| `_estimate_lp_propensity` | ~627 | `return slp` | `slp` |
| `_estimate_lp_robust` | ~658 | `return slp` | `slp` |
| `_estimate_arima` | ~697 | `return model` | `model` |
| `_estimate_gmm` | ~808 | `return model` | `model` |
| `_estimate_static` | ~844 | `return model` | `model` |
| `_estimate_dynamic` | ~888 | `return model` | `model` |
| `_estimate_gdfm` | ~926 | `return model` | `model` |
| `_estimate_arch` | ~942 | `return model` | `model` |
| `_estimate_garch` | ~958 | `return model` | `model` |
| `_estimate_egarch` | ~970 | `return model` | `model` |
| `_estimate_gjr_garch` | ~984 | `return model` | `model` |
| `_estimate_sv` | ~996 | `return model` | `model` |
| `_estimate_fastica` | ~1041 | `return result` | `result` |
| `_estimate_ml` | ~1098 | `return result` | `result` |
| `_estimate_vecm` | ~1135 | `return vecm` | `vecm` |
| `_estimate_pvar` | ~1185 | `return model` | `model` |
| `_estimate_smm` | ~1236 | `return model` | `model` |
| `_estimate_favar` | ~1267 | `return favar` | `favar` |
| `_estimate_sdfm` | ~1304 | `return sdfm` | `sdfm` |
| `_estimate_reg` | ~1338 | `return model` | `model` |
| `_estimate_iv` | ~1399 | `return model` | `model` |
| `_estimate_logit` | ~1431 | `return model` | `model` |
| `_estimate_probit` | ~1463 | `return model` | `model` |

For the LP dispatcher `_estimate_lp`, capture the return from sub-handlers:

```julia
# At the end of _estimate_lp, change the dispatch calls to capture returns:
    result = if method == "standard"
        _estimate_lp_standard(; data, lags, ...)
    elseif method == "iv"
        # ... etc
    end
    return result
```

**Step 2: Run existing tests**

Run: `julia --project test/runtests.jl`
Expected: All pass — adding `return` doesn't change output behavior, one-shot dispatch ignores return values.

**Step 3: Commit**

```bash
git add src/commands/estimate.jl
git commit -m "feat: estimate handlers return result objects for REPL caching"
```

---

### Task 6: REPL result capture after estimation

**Files:**
- Modify: `src/repl.jl`
- Modify: `src/cli/dispatch.jl`
- Modify: `test/test_repl.jl`

**Step 1: Modify dispatch to return handler result**

In `src/cli/dispatch.jl`, change `dispatch_leaf` to return the handler's result:

```julia
function dispatch_leaf(leaf::LeafCommand, args::Vector{String}; prog::String=leaf.name)
    # ... existing help/empty checks unchanged ...

    try
        parsed = tokenize(args)
        bound = bind_args(parsed, leaf)
        return leaf.handler(; bound...)  # was just: leaf.handler(; bound...)
    catch e
        if e isa ParseError
            throw(ParseError("$prog: $(e.message)"))
        else
            rethrow()
        end
    end
end
```

Similarly, `dispatch_node` should return what `dispatch_leaf`/`dispatch_node` returns:

```julia
function dispatch_node(node::NodeCommand, args::Vector{String}; prog::String=node.name)
    # ... existing checks ...
    if haskey(node.subcmds, subcmd_name)
        subcmd = node.subcmds[subcmd_name]
        subprog = prog * " " * subcmd_name
        if subcmd isa NodeCommand
            return dispatch_node(subcmd, rest; prog=subprog)
        else
            return dispatch_leaf(subcmd, rest; prog=subprog)
        end
    end
    # ... rest unchanged ...
end
```

And `dispatch` returns:

```julia
function dispatch(entry::Entry, args::Vector{String}=ARGS)
    # ... existing --version/--warranty/--conditions/--help checks (these return nothing) ...
    return dispatch_node(entry.root, args; prog=entry.name)
end
```

**Step 2: Update repl_dispatch to capture and store results**

In `src/repl.jl`, update `repl_dispatch`:

```julia
function repl_dispatch(s::Session, app::Entry, args::Vector{String})
    # ... existing REPL-only command handling ...

    # Inject session data
    args = inject_session_data(s, args)

    # Dispatch and capture result
    result = dispatch(app, args)

    # Cache estimation results
    if is_estimate_command(args) && !isnothing(result)
        model_type = detect_model_type(args)
        if model_type != :none
            session_store_result!(s, model_type, result)
            printstyled("✓ "; color=:green)
            if haskey(s.results, model_type) && s.results[model_type] !== result
                println("Result cached as :$model_type (replaced)")
            else
                println("Result cached as :$model_type")
            end
        end
    end
end
```

**Step 3: Run all tests**

Run: `julia --project test/runtests.jl`
Expected: All pass — dispatch now returns values but one-shot `main()` ignores them.

**Step 4: Commit**

```bash
git add src/repl.jl src/cli/dispatch.jl test/test_repl.jl
git commit -m "feat: dispatch returns handler results, REPL captures estimation results"
```

---

### Task 7: Downstream handlers accept model kwarg (irf, fevd, hd)

**Files:**
- Modify: `src/commands/irf.jl` (7 handlers)
- Modify: `src/commands/fevd.jl` (7 handlers)
- Modify: `src/commands/hd.jl` (5 handlers)

For each downstream handler, add `model=nothing` kwarg and wrap the existing load+estimate block in `if isnothing(model)`.

**Pattern for VAR-based handlers** (irf_var, fevd_var, hd_var, etc.):

```julia
# Before:
function _irf_var(; data::String, lags=nothing, ...)
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    # ... rest ...

# After:
function _irf_var(; data::String="", lags=nothing, ..., model=nothing)
    if isnothing(model)
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
    else
        varnames = model.varnames
        p = model.p
        Y = model.Y
    end
    # ... rest unchanged ...
```

**Pattern for BVAR handlers** (irf_bvar, etc.):

```julia
function _irf_bvar(; data::String="", ..., model=nothing)
    if isnothing(model)
        post, Y, varnames, p, n = _load_and_estimate_bvar(data, lags, config, draws, sampler)
    else
        post = model  # cached result is the BVARPosterior
        # extract Y, varnames, p, n from post
    end
```

Apply this pattern to all 19 handlers across the 3 files:

**irf.jl:** `_irf_var`, `_irf_bvar`, `_irf_lp`, `_irf_vecm`, `_irf_pvar`, `_irf_favar`, `_irf_sdfm`
**fevd.jl:** `_fevd_var`, `_fevd_bvar`, `_fevd_lp`, `_fevd_vecm`, `_fevd_pvar`, `_fevd_favar`, `_fevd_sdfm`
**hd.jl:** `_hd_var`, `_hd_bvar`, `_hd_lp`, `_hd_vecm`, `_hd_favar`

**Important:** Make `data::String=""` (default empty) instead of `data::String` (required) so the kwarg works when model is provided from cache.

**Step 1: Implement changes across all 3 files**

Read each handler, add `model=nothing` kwarg, wrap load+estimate in `if isnothing(model)`.

**Step 2: Run tests**

Run: `julia --project test/runtests.jl`
Expected: All pass — existing tests always provide `data=` so `model` stays `nothing`.

**Step 3: Commit**

```bash
git add src/commands/irf.jl src/commands/fevd.jl src/commands/hd.jl
git commit -m "feat: irf/fevd/hd handlers accept model kwarg for REPL caching"
```

---

### Task 8: Downstream handlers accept model kwarg (forecast, predict, residuals)

**Files:**
- Modify: `src/commands/forecast.jl` (14 handlers)
- Modify: `src/commands/predict.jl` (16 handlers)
- Modify: `src/commands/residuals.jl` (16 handlers)

Same pattern as Task 7. Apply `model=nothing` kwarg and `if isnothing(model)` branch to all 46 handlers.

**Step 1: Implement**

Apply the same pattern from Task 7 to all handlers in forecast.jl, predict.jl, and residuals.jl.

**Step 2: Run tests**

Run: `julia --project test/runtests.jl`
Expected: All pass

**Step 3: Commit**

```bash
git add src/commands/forecast.jl src/commands/predict.jl src/commands/residuals.jl
git commit -m "feat: forecast/predict/residuals handlers accept model kwarg for REPL caching"
```

---

### Task 9: REPL model injection for downstream commands

**Files:**
- Modify: `src/repl.jl`
- Modify: `test/test_repl.jl`

**Step 1: Write tests**

Add to `test/test_repl.jl`:

```julia
@testset "REPL model injection" begin
    @testset "is_downstream_command" begin
        @test Friedman.is_downstream_command(["irf", "var"])
        @test Friedman.is_downstream_command(["fevd", "bvar"])
        @test Friedman.is_downstream_command(["hd", "var"])
        @test Friedman.is_downstream_command(["forecast", "var"])
        @test Friedman.is_downstream_command(["predict", "var"])
        @test Friedman.is_downstream_command(["residuals", "var"])
        @test !Friedman.is_downstream_command(["estimate", "var"])
        @test !Friedman.is_downstream_command(["test", "adf"])
        @test !Friedman.is_downstream_command(["data", "use"])
    end
end
```

**Step 2: Implement model injection in repl_dispatch**

Add to `src/repl.jl`:

```julia
const DOWNSTREAM_ACTIONS = Set(["irf", "fevd", "hd", "forecast", "predict", "residuals"])

is_downstream_command(args::Vector{String}) =
    !isempty(args) && args[1] in DOWNSTREAM_ACTIONS
```

Update `repl_dispatch` to inject cached model for downstream commands. This requires modifying dispatch to accept extra kwargs. Add to `dispatch_leaf`:

In `src/cli/dispatch.jl`, modify `dispatch_leaf` to accept extra kwargs:

```julia
function dispatch_leaf(leaf::LeafCommand, args::Vector{String}; prog::String=leaf.name, extra_kwargs...)
    # ... existing help/empty checks ...
    try
        parsed = tokenize(args)
        bound = bind_args(parsed, leaf)
        merged = merge(Dict{Symbol,Any}(bound), Dict{Symbol,Any}(extra_kwargs))
        return leaf.handler(; merged...)
    catch e
        # ...
    end
end
```

Thread `extra_kwargs` through `dispatch_node` and `dispatch` as well.

Then in `repl_dispatch`, when a downstream command has a matching cached result:

```julia
    # Check if downstream command can use cached model
    extra_kw = Dict{Symbol,Any}()
    if is_downstream_command(args)
        model_type = detect_model_type(args)
        cached = session_get_result(s, model_type)
        if !isnothing(cached)
            extra_kw[:model] = cached
        elseif s.last_model != :none
            cached = session_get_result(s, s.last_model)
            if !isnothing(cached)
                extra_kw[:model] = cached
            end
        end
    end

    result = dispatch(app, args; extra_kw...)
```

**Step 3: Run tests**

**Step 4: Commit**

```bash
git add src/repl.jl src/cli/dispatch.jl test/test_repl.jl
git commit -m "feat: REPL injects cached models into downstream commands"
```

---

### Task 10: Tab completion

**Files:**
- Modify: `src/repl.jl`
- Modify: `test/test_repl.jl`

**Step 1: Write tests**

```julia
@testset "Tab completion" begin
    app = Friedman.build_app()

    @testset "complete_command" begin
        # Top-level completions
        completions = Friedman.complete_command(app, "est")
        @test "estimate" in completions

        # Subcommand completions
        completions2 = Friedman.complete_command(app, "estimate v")
        @test "var" in completions2
        @test "vecm" in completions2

        # Option completions
        completions3 = Friedman.complete_command(app, "estimate var --la")
        @test "--lags" in completions3
    end
end
```

**Step 2: Implement completion function**

Add to `src/repl.jl`:

```julia
"""
    complete_command(app, partial_line) → Vector{String}

Return completion candidates for the current partial input line.
"""
function complete_command(app::Entry, partial::String)
    tokens = _split_repl_line(partial)
    isempty(tokens) && return sort(collect(keys(app.root.subcmds)))

    # Walk the command tree
    node = app.root
    for (i, tok) in enumerate(tokens[1:end-1])
        if haskey(node.subcmds, tok)
            sub = node.subcmds[tok]
            if sub isa NodeCommand
                node = sub
            else
                # At a leaf — complete options
                return _complete_leaf_options(sub, tokens[end])
            end
        else
            return String[]
        end
    end

    prefix = tokens[end]

    # Complete subcommand names
    if node isa NodeCommand
        if startswith(prefix, "-")
            return String[]  # No options at node level
        end
        return sort([k for k in keys(node.subcmds) if startswith(k, prefix)])
    end

    return String[]
end

function _complete_leaf_options(leaf::LeafCommand, prefix::String)
    startswith(prefix, "-") || return String[]
    options = ["--" * o.name for o in leaf.options]
    flags = ["--" * f.name for f in leaf.flags]
    all_opts = vcat(options, flags)
    return sort([o for o in all_opts if startswith(o, prefix)])
end
```

**Step 3: Upgrade REPL loop to use LineEdit with completion**

Replace the basic `readline` loop in `start_repl()` with a `LineEdit`-based REPL:

```julia
function start_repl()
    app = build_app()
    s = SESSION
    session_clear!(s)

    printstyled("Friedman REPL v$(FRIEDMAN_VERSION)\n"; bold=true)
    println("Type commands as you would on the command line. Type 'exit' to quit.")
    println()

    # Set up LineEdit
    term = REPL.Terminals.TTYTerminal("", stdin, stdout, stderr)

    prompt = LineEdit.Prompt("friedman> ";
        prompt_prefix = "\e[1;34m",  # bold blue
        prompt_suffix = "\e[0m",
        complete = FriedmanCompletionProvider(app),
        on_enter = s -> true,  # single-line input
    )

    prompt.on_done = (s, buf, ok) -> begin
        ok || return
        line = String(take!(buf))
        isempty(strip(line)) && return

        args = _split_repl_line(line)
        try
            repl_dispatch(SESSION, app, args)
        catch e
            if e isa InterruptException
                println("Goodbye!")
                return :quit
            elseif e isa ParseError || e isa DispatchError
                printstyled(stderr, "Error: "; bold=true, color=:red)
                println(stderr, e.message)
            else
                printstyled(stderr, "Error: "; bold=true, color=:red)
                println(stderr, sprint(showerror, e))
            end
        end
    end

    # Fallback: use simple readline loop if LineEdit setup fails
    # (e.g., non-interactive terminal, piped input)
    if !isa(stdin, Base.TTY)
        _repl_readline_loop(app, s)
        return
    end

    _repl_readline_loop(app, s)
end

struct FriedmanCompletionProvider <: LineEdit.CompletionProvider
    app::Entry
end

function LineEdit.complete_line(c::FriedmanCompletionProvider, state)
    partial = String(LineEdit.buffer(state))
    completions = complete_command(c.app, partial)
    # Return (completions, partial_to_replace, should_complete)
    tokens = _split_repl_line(partial)
    last_token = isempty(tokens) ? "" : tokens[end]
    return completions, last_token, !isempty(completions)
end

function _repl_readline_loop(app::Entry, s::Session)
    while true
        try
            printstyled("friedman> "; color=:blue, bold=true)
            line = readline(stdin)
            isempty(strip(line)) && continue

            args = _split_repl_line(line)
            try
                repl_dispatch(s, app, args)
            catch e
                if e isa InterruptException
                    println("Goodbye!")
                    return
                elseif e isa ParseError || e isa DispatchError
                    printstyled(stderr, "Error: "; bold=true, color=:red)
                    println(stderr, e.message)
                else
                    printstyled(stderr, "Error: "; bold=true, color=:red)
                    println(stderr, sprint(showerror, e))
                end
            end
        catch e
            if e isa EOFError || e isa InterruptException
                println("\nGoodbye!")
                return
            end
            rethrow()
        end
    end
end
```

**Step 4: Run tests**

Run: `julia --project -e 'include("test/test_repl.jl")'`
Run: `julia --project test/runtests.jl`

**Step 5: Commit**

```bash
git add src/repl.jl test/test_repl.jl
git commit -m "feat: add tab completion for commands, subcommands, and options"
```

---

### Task 11: Integration tests

**Files:**
- Modify: `test/test_repl.jl`

**Step 1: Write integration tests for full REPL workflows**

```julia
@testset "REPL integration" begin
    @testset "data use → estimate → irf workflow" begin
        s = Friedman.Session()

        # Create test data
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "x,y,z")
            for i in 1:50
                println(io, "$(rand()),$(rand()),$(rand())")
            end
        end

        Friedman.session_load_data!(s, tmpfile)
        @test Friedman.session_has_data(s)

        # Simulate estimate → store
        Friedman.session_store_result!(s, :var, "mock_var_model")
        @test Friedman.session_get_result(s, :var) == "mock_var_model"
        @test s.last_model == :var

        # Simulate second estimate
        Friedman.session_store_result!(s, :bvar, "mock_bvar_model")
        @test s.last_model == :bvar
        @test Friedman.session_get_result(s, :var) == "mock_var_model"  # still cached

        # Data change clears results
        Friedman.session_load_data!(s, tmpfile)
        @test isempty(s.results)
        @test s.last_model == :none

        rm(tmpfile; force=true)
    end

    @testset "data injection into args" begin
        s = Friedman.Session()
        s.data_path = "/tmp/macro.csv"
        s.Y = zeros(10, 3)
        s.varnames = ["a", "b", "c"]

        # estimate var --lags 4 → estimate var /tmp/macro.csv --lags 4
        injected = Friedman.inject_session_data(s, ["estimate", "var", "--lags", "4"])
        @test injected[3] == "/tmp/macro.csv"

        # dsge solve model.toml → unchanged (has positional)
        unchanged = Friedman.inject_session_data(s, ["dsge", "solve", "model.toml"])
        @test unchanged == ["dsge", "solve", "model.toml"]
    end
end
```

**Step 2: Run all tests**

Run: `julia --project -e 'include("test/test_repl.jl")'`
Run: `julia --project test/runtests.jl`

**Step 3: Commit**

```bash
git add test/test_repl.jl
git commit -m "test: add REPL integration tests"
```

---

### Task 12: Version bump and documentation

**Files:**
- Modify: `Project.toml` (version → 0.4.0)
- Modify: `src/Friedman.jl` (FRIEDMAN_VERSION)
- Modify: `src/cli/types.jl` (Entry default version)
- Modify: `test/runtests.jl` (version refs)
- Modify: `CLAUDE.md`
- Modify: `README.md`
- Modify: `docs/src/index.md`
- Create: `docs/src/repl.md`

**Step 1: Bump version to v0.4.0** (major feature warrants minor version bump)

- `Project.toml` line 3: `"0.3.4"` → `"0.4.0"`
- `src/Friedman.jl` line 53: `v"0.3.4"` → `v"0.4.0"`
- `src/cli/types.jl` line 111: `v"0.3.4"` → `v"0.4.0"`
- `test/runtests.jl`: all `"0.3.4"` → `"0.4.0"` and `v"0.3.4"` → `v"0.4.0"`

**Step 2: Update CLAUDE.md**

- Project Overview: version, add REPL description
- Project Structure: add `src/repl.jl`, `test/test_repl.jl`
- Command Hierarchy: add `repl` entry
- Architecture: add REPL section

**Step 3: Update README.md**

- Add REPL section with usage examples
- Update version refs

**Step 4: Create docs/src/repl.md**

Document the REPL mode: entry, commands, workflow examples, tab completion.

**Step 5: Run all tests**

Run: `julia --project test/runtests.jl`
Run: `julia --project -e 'include("test/test_repl.jl")'`

**Step 6: Commit**

```bash
git add Project.toml src/Friedman.jl src/cli/types.jl test/runtests.jl CLAUDE.md README.md docs/
git commit -m "feat: add REPL interactive session mode (v0.4.0) — closes #4"
```
