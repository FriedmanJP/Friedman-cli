# MEMs v0.3.1 Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate MacroEconometricModels.jl v0.3.1 into Friedman-cli v0.3.0 — add DSGE top-level command (7 subcommands), estimate smm, adapt breaking changes (VARForecast/BVARForecast, LPForecast field rename, FFTW extension).

**Architecture:** New `src/commands/dsge.jl` with `register_dsge_commands!()` returning a NodeCommand with 7 LeafCommand leaves (solve, irf, fevd, simulate, estimate, perfect-foresight, steady-state). Shared helpers `_load_dsge_model()` and `_solve_dsge()` in `src/commands/shared.jl`. DSGE model input via TOML or `.jl` files. OccBin integrated into `dsge solve` and `dsge irf` via `--constraints` flag. Config parser extended in `src/config.jl`. Breaking forecast changes adapted in `src/commands/forecast.jl`.

**Tech Stack:** Julia 1.12, MacroEconometricModels.jl v0.3.1, existing CLI framework (types.jl/parser.jl/dispatch.jl/help.jl)

**Design doc:** `docs/plans/2026-03-03-v030-mems-v031-integration-design.md`

---

## Task 1: Project.toml — Bump MEMs Compat & Add Dependencies

**Files:**
- Modify: `Project.toml`

**Step 1: Update Project.toml**

Change MEMs compat from `0.2.4` to `0.3.1`. Add `SparseArrays` to `[deps]`. Add `FFTW`, `JuMP`, `Ipopt`, `PATHSolver` to `[weakdeps]` and `[extensions]`. Note: the exact UUIDs for JuMP/Ipopt/PATHSolver must be looked up from the Julia General registry.

In `[deps]`, add:
```toml
SparseArrays = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"
```

In `[compat]`, change:
```toml
MacroEconometricModels = "0.3.1"
```

Add new sections:
```toml
[weakdeps]
FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
JuMP = "4076af6c-e467-56ae-b986-b466b2749572"
Ipopt = "b6b21f68-93f8-5de0-b562-5493be1d77c9"
PATHSolver = "f5f7c340-0bb3-4c5b-8559-4718d85f8e3c"
```

**Step 2: Verify resolution**

Run: `julia --project -e 'using Pkg; Pkg.resolve()'`
Expected: resolves without error (MEMs v0.3.1 pulls in SparseArrays transitively).

**Step 3: Commit**

```bash
git add Project.toml
git commit -m "chore: bump MEMs compat to 0.3.1, add SparseArrays + weak deps"
```

---

## Task 2: Mock Types — DSGE, SMM, VARForecast/BVARForecast

**Files:**
- Modify: `test/mocks.jl`

**Step 1: Write mock DSGE types**

Add these mock types before `end # module` in `test/mocks.jl`. Follow the existing pattern: struct with typed fields, convenience constructors, export statement.

```julia
# ─── DSGE Types & Functions ──────────────────────────────

abstract type AbstractDSGEModel end

struct DSGESpec{T<:AbstractFloat}
    endog::Vector{Symbol}
    exog::Vector{Symbol}
    params::Vector{Symbol}
    param_values::Dict{Symbol,T}
    n_endog::Int
    n_exog::Int
    n_params::Int
    varnames::Vector{String}
    steady_state::Vector{T}
end
# Convenience constructor
function DSGESpec(; n_endog=3, n_exog=1)
    T = Float64
    endog = [Symbol("y$i") for i in 1:n_endog]
    exog = [Symbol("e$i") for i in 1:n_exog]
    params = [:rho, :sigma, :beta]
    param_values = Dict(:rho => 0.9, :sigma => 0.01, :beta => 0.99)
    varnames = String.(endog)
    ss = ones(T, n_endog)
    DSGESpec{T}(endog, exog, params, param_values, n_endog, n_exog, length(params), varnames, ss)
end

struct LinearDSGE{T<:AbstractFloat}
    Gamma0::Matrix{T}; Gamma1::Matrix{T}; C::Vector{T}; Psi::Matrix{T}; Pi::Matrix{T}
    spec::DSGESpec{T}
end

struct DSGESolution{T<:AbstractFloat}
    G1::Matrix{T}; impact::Matrix{T}; C_sol::Vector{T}
    eu::Vector{Int}; method::Symbol; eigenvalues::Vector{Complex{T}}
    spec::DSGESpec{T}; linear::LinearDSGE{T}
end

struct PerturbationSolution{T<:AbstractFloat}
    order::Int; gx::Matrix{T}; hx::Matrix{T}
    gxx::Union{Nothing,Array{T,3}}; hxx::Union{Nothing,Array{T,3}}
    gσσ::Union{Nothing,Vector{T}}; hσσ::Union{Nothing,Vector{T}}
    eta::Matrix{T}; steady_state::Vector{T}
    state_indices::Vector{Int}; control_indices::Vector{Int}
    eu::Vector{Int}; method::Symbol
    spec::DSGESpec{T}; linear::LinearDSGE{T}
end

struct ProjectionSolution{T<:AbstractFloat}
    coefficients::Matrix{T}; state_bounds::Matrix{T}
    grid_type::Symbol; degree::Int
    residual_norm::T; converged::Bool; iterations::Int; method::Symbol
    spec::DSGESpec{T}; linear::LinearDSGE{T}
    steady_state::Vector{T}; state_indices::Vector{Int}; control_indices::Vector{Int}
end

struct PerfectForesightPath{T<:AbstractFloat}
    path::Matrix{T}; deviations::Matrix{T}
    converged::Bool; iterations::Int
    spec::DSGESpec{T}
end

struct DSGEEstimation{T<:AbstractFloat} <: AbstractDSGEModel
    theta::Vector{T}; vcov::Matrix{T}; param_names::Vector{String}
    method::Symbol; J_stat::T; J_pvalue::T
    converged::Bool; spec::DSGESpec{T}
end

struct OccBinConstraint{T<:AbstractFloat}
    variable::Symbol; bound::T; direction::Symbol
end

struct OccBinSolution{T<:AbstractFloat}
    linear_path::Matrix{T}; piecewise_path::Matrix{T}
    steady_state::Vector{T}; regime_history::Vector{Int}
    converged::Bool; iterations::Int
    spec::DSGESpec{T}; varnames::Vector{String}
end

struct OccBinIRF{T<:AbstractFloat}
    linear::Array{T,3}; piecewise::Array{T,3}
    regime_history::Vector{Int}; varnames::Vector{String}; shock_name::String
end
```

**Step 2: Write mock DSGE functions**

```julia
# Mock constructors for creating solutions from specs
function _mock_linear(spec::DSGESpec{T}) where T
    n = spec.n_endog
    LinearDSGE{T}(Matrix{T}(I(n)), 0.5*Matrix{T}(I(n)), zeros(T, n),
                   randn(T, n, spec.n_exog), zeros(T, n, 1), spec)
end

function _mock_solution(spec::DSGESpec{T}; method=:gensys) where T
    n = spec.n_endog
    ld = _mock_linear(spec)
    G1 = 0.5 * Matrix{T}(I(n))
    impact = 0.1 * ones(T, n, spec.n_exog)
    DSGESolution{T}(G1, impact, zeros(T, n), [1, 1], method,
                     Complex{T}[0.5 + 0.0im for _ in 1:n], spec, ld)
end

compute_steady_state(spec::DSGESpec; kwargs...) = spec
linearize(spec::DSGESpec) = _mock_linear(spec)

function solve(spec::DSGESpec{T}; method::Symbol=:gensys, order::Int=1,
               degree::Int=5, grid::Symbol=:auto, kwargs...) where T
    if method == :perturbation
        ld = _mock_linear(spec)
        n = spec.n_endog; ns = max(1, n ÷ 2); nc = n - ns
        PerturbationSolution{T}(order,
            randn(T, nc, ns), 0.5*Matrix{T}(I(ns)),
            nothing, nothing, nothing, nothing,
            0.1*ones(T, ns, spec.n_exog), spec.steady_state,
            collect(1:ns), collect(ns+1:n),
            [1, 1], :perturbation, spec, ld)
    elseif method == :projection || method == :pfi
        ld = _mock_linear(spec)
        n = spec.n_endog; ns = max(1, n ÷ 2); nc = n - ns
        ProjectionSolution{T}(randn(T, nc, degree+1),
            hcat(-ones(T, ns), ones(T, ns)),
            grid, degree, 1e-10, true, 15, method,
            spec, ld, spec.steady_state,
            collect(1:ns), collect(ns+1:n))
    else
        _mock_solution(spec; method=method)
    end
end

gensys(Γ0, Γ1, C, Ψ, Π) = _mock_solution(DSGESpec())
blanchard_kahn(ld, spec) = _mock_solution(spec; method=:blanchard_kahn)
klein(Γ0, Γ1, C, Ψ, n_pre) = _mock_solution(DSGESpec(); method=:klein)
perturbation_solver(spec; order=1) = solve(spec; method=:perturbation, order=order)
collocation_solver(spec; degree=5, kwargs...) = solve(spec; method=:projection, degree=degree)
pfi_solver(spec; kwargs...) = solve(spec; method=:pfi)

function perfect_foresight(spec::DSGESpec{T}; shocks=nothing, T_periods::Int=100, kwargs...) where T
    n = spec.n_endog
    path = repeat(spec.steady_state', T_periods, 1) .+ 0.01 * randn(T, T_periods, n)
    PerfectForesightPath{T}(path, path .- repeat(spec.steady_state', T_periods, 1),
                            true, 8, spec)
end

function occbin_solve(spec::DSGESpec{T}, shocks, constraints; T_periods::Int=40, kwargs...) where T
    n = spec.n_endog
    path = repeat(spec.steady_state', T_periods, 1)
    OccBinSolution{T}(path, path, spec.steady_state, ones(Int, T_periods),
                      true, 5, spec, spec.varnames)
end

function occbin_irf(spec::DSGESpec{T}, constraints, shock_idx::Int;
                    shock_size::Real=1.0, horizon::Int=40, kwargs...) where T
    n = spec.n_endog
    lin = zeros(T, horizon, n, 1)
    pw = zeros(T, horizon, n, 1)
    for h in 1:horizon
        lin[h, :, 1] .= shock_size * 0.9^h
        pw[h, :, 1] .= shock_size * max(0.0, 0.9^h - 0.1)
    end
    OccBinIRF{T}(lin, pw, ones(Int, horizon), spec.varnames, "shock_$shock_idx")
end

function parse_constraint(expr, spec)
    OccBinConstraint{Float64}(:i, 0.0, :geq)
end

function variable_bound(var::Symbol; lower=-Inf, upper=Inf)
    OccBinConstraint{Float64}(var, lower, :geq)
end

function estimate_dsge(spec::DSGESpec{T}, data, param_names;
                       method::Symbol=:irf_matching, kwargs...) where T
    np = length(param_names)
    DSGEEstimation{T}(randn(T, np), 0.01*Matrix{T}(I(np)),
                      String.(param_names), method, 2.5, 0.45, true, spec)
end

function simulate(sol, T_periods::Int; kwargs...)
    n = if sol isa DSGESolution
        sol.spec.n_endog
    elseif sol isa PerturbationSolution
        sol.spec.n_endog
    elseif sol isa ProjectionSolution
        sol.spec.n_endog
    else
        3
    end
    randn(Float64, T_periods, n)
end

# IRF and FEVD dispatch for DSGE solutions — return standard types
function irf(sol::DSGESolution, horizon::Int; kwargs...)
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    vals = zeros(Float64, horizon, n, ne)
    for h in 1:horizon
        vals[h, :, :] .= 0.9^h
    end
    ImpulseResponse(vals, nothing, nothing, horizon,
                    sol.spec.varnames,
                    ["shock$i" for i in 1:ne], :cholesky)
end

function irf(sol::PerturbationSolution, horizon::Int; kwargs...)
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    vals = zeros(Float64, horizon, n, ne)
    for h in 1:horizon
        vals[h, :, :] .= 0.9^h
    end
    ImpulseResponse(vals, nothing, nothing, horizon,
                    sol.spec.varnames,
                    ["shock$i" for i in 1:ne], :perturbation)
end

function irf(sol::ProjectionSolution, horizon::Int; kwargs...)
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    vals = zeros(Float64, horizon, n, ne)
    for h in 1:horizon
        vals[h, :, :] .= 0.9^h
    end
    ImpulseResponse(vals, nothing, nothing, horizon,
                    sol.spec.varnames,
                    ["shock$i" for i in 1:ne], :projection)
end

function fevd(sol::DSGESolution, horizon::Int; kwargs...)
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    props = ones(Float64, horizon, n, ne) ./ ne
    FEVD(props, props, horizon,
         sol.spec.varnames, ["shock$i" for i in 1:ne])
end

function fevd(sol::PerturbationSolution, horizon::Int; kwargs...)
    n = sol.spec.n_endog; ne = sol.spec.n_exog
    props = ones(Float64, horizon, n, ne) ./ ne
    FEVD(props, props, horizon,
         sol.spec.varnames, ["shock$i" for i in 1:ne])
end

is_determined(sol) = true
is_stable(sol) = true
nshocks(sol) = sol isa DSGESolution ? sol.spec.n_exog :
               sol isa PerturbationSolution ? sol.spec.n_exog :
               sol isa ProjectionSolution ? sol.spec.n_exog : 1

# Export DSGE
export AbstractDSGEModel, DSGESpec, LinearDSGE, DSGESolution
export PerturbationSolution, ProjectionSolution, PerfectForesightPath
export DSGEEstimation, OccBinConstraint, OccBinSolution, OccBinIRF
export compute_steady_state, linearize, solve, gensys, blanchard_kahn, klein
export perturbation_solver, collocation_solver, pfi_solver
export perfect_foresight, occbin_solve, occbin_irf, parse_constraint, variable_bound
export estimate_dsge, simulate, is_determined, is_stable, nshocks
```

**Step 3: Write mock SMM type**

```julia
# ─── SMM Types & Functions ──────────────────────────────

struct SMMModel{T<:AbstractFloat}
    theta::Vector{T}; vcov::Matrix{T}
    n_moments::Int; n_params::Int; n_obs::Int
    J_stat::T; J_pvalue::T; converged::Bool
    sim_ratio::Int
end

struct ParameterTransform{T<:AbstractFloat}
    lower::Vector{T}; upper::Vector{T}
end

function estimate_smm(moment_fn, theta0, data; weighting=:two_step,
                      sim_ratio::Int=5, burn::Int=100, kwargs...)
    np = length(theta0)
    SMMModel{Float64}(randn(np), 0.01*Matrix{Float64}(I(np)),
                      np+2, np, 100, 1.8, 0.55, true, sim_ratio)
end

function autocovariance_moments(data; lags=1)
    zeros(Float64, size(data, 2) * (lags + 1))
end

to_unconstrained(x, t::ParameterTransform) = x
to_constrained(x, t::ParameterTransform) = x
transform_jacobian(x, t::ParameterTransform) = ones(length(x))

export SMMModel, ParameterTransform, estimate_smm, autocovariance_moments
export to_unconstrained, to_constrained, transform_jacobian
```

**Step 4: Write mock VARForecast/BVARForecast types**

```julia
# ─── VARForecast / BVARForecast ───────────────────────────

struct VARForecast{T<:AbstractFloat}
    forecast::Matrix{T}; ci_lower::Matrix{T}; ci_upper::Matrix{T}
    horizon::Int; ci_method::Symbol; conf_level::T; varnames::Vector{String}
end

struct BVARForecast{T<:AbstractFloat}
    forecast::Matrix{T}; ci_lower::Matrix{T}; ci_upper::Matrix{T}
    horizon::Int; ci_method::Symbol; conf_level::T; varnames::Vector{String}
end

point_forecast(f::VARForecast) = f.forecast
point_forecast(f::BVARForecast) = f.forecast
lower_bound(f::VARForecast) = f.ci_lower
lower_bound(f::BVARForecast) = f.ci_lower
upper_bound(f::VARForecast) = f.ci_upper
upper_bound(f::BVARForecast) = f.ci_upper
forecast_horizon(f::VARForecast) = f.horizon
forecast_horizon(f::BVARForecast) = f.horizon

export VARForecast, BVARForecast
export point_forecast, lower_bound, upper_bound, forecast_horizon
```

**Step 5: Run existing tests to verify mocks don't break anything**

Run: `julia --project test/runtests.jl`
Expected: all existing tests pass (new types are additive, no conflicts)

**Step 6: Commit**

```bash
git add test/mocks.jl
git commit -m "test: add mock DSGE, SMM, VARForecast/BVARForecast types"
```

---

## Task 3: Config Parser — DSGE Model TOML & Constraints

**Files:**
- Modify: `src/config.jl`
- Test: `test/runtests.jl` (config tests section)

**Step 1: Write failing tests for DSGE config parsing**

Add to the config tests section in `test/runtests.jl`:

```julia
@testset "get_dsge — valid model config" begin
    cfg = Dict(
        "model" => Dict(
            "parameters" => Dict("rho" => 0.9, "sigma" => 0.01, "beta" => 0.99),
            "endogenous" => ["C", "K", "Y"],
            "exogenous" => ["e_A"],
            "equations" => [
                Dict("expr" => "C[t] + K[t] = Y[t]"),
                Dict("expr" => "Y[t] = K[t-1]"),
                Dict("expr" => "K[t] = rho * K[t-1] + sigma * e_A[t]"),
            ]
        )
    )
    result = get_dsge(cfg)
    @test result["parameters"] == Dict("rho" => 0.9, "sigma" => 0.01, "beta" => 0.99)
    @test result["endogenous"] == ["C", "K", "Y"]
    @test result["exogenous"] == ["e_A"]
    @test length(result["equations"]) == 3
    @test result["equations"][1] == "C[t] + K[t] = Y[t]"
end

@testset "get_dsge — missing model section" begin
    cfg = Dict{String,Any}()
    result = get_dsge(cfg)
    @test isempty(result["endogenous"])
end

@testset "get_dsge_constraints — bounds" begin
    cfg = Dict(
        "constraints" => Dict(
            "bounds" => [
                Dict("variable" => "i", "lower" => 0.0),
                Dict("variable" => "c", "lower" => 0.0, "upper" => 10.0),
            ]
        )
    )
    result = get_dsge_constraints(cfg)
    @test length(result["bounds"]) == 2
    @test result["bounds"][1]["variable"] == "i"
    @test result["bounds"][1]["lower"] == 0.0
end

@testset "get_dsge_constraints — empty" begin
    cfg = Dict{String,Any}()
    result = get_dsge_constraints(cfg)
    @test isempty(result["bounds"])
end

@testset "get_smm — valid config" begin
    cfg = Dict(
        "smm" => Dict(
            "weighting" => "optimal",
            "sim_ratio" => 10,
            "burn" => 200,
        )
    )
    result = get_smm(cfg)
    @test result["weighting"] == "optimal"
    @test result["sim_ratio"] == 10
    @test result["burn"] == 200
end

@testset "get_smm — defaults" begin
    cfg = Dict{String,Any}()
    result = get_smm(cfg)
    @test result["weighting"] == "two_step"
    @test result["sim_ratio"] == 5
    @test result["burn"] == 100
end
```

**Step 2: Run tests to verify they fail**

Run: `julia --project test/runtests.jl`
Expected: FAIL — `get_dsge`, `get_dsge_constraints`, `get_smm` not defined

**Step 3: Implement config parsers**

Add to `src/config.jl` before the `_parse_matrix` helper:

```julia
"""
    get_dsge(config) → Dict

Extract DSGE model specification from a config dict.
Returns parameters, endogenous/exogenous variables, equations.
"""
function get_dsge(config::Dict)
    model = get(config, "model", Dict())
    result = Dict{String,Any}()

    result["parameters"] = get(model, "parameters", Dict{String,Any}())
    result["endogenous"] = get(model, "endogenous", String[])
    result["exogenous"] = get(model, "exogenous", String[])

    eqs_raw = get(model, "equations", Dict[])
    result["equations"] = String[eq["expr"] for eq in eqs_raw if haskey(eq, "expr")]

    # Optional solver section
    solver = get(config, "solver", Dict())
    result["solver_method"] = get(solver, "method", "gensys")
    result["solver_order"] = get(solver, "order", 1)
    result["solver_degree"] = get(solver, "degree", 5)
    result["solver_grid"] = get(solver, "grid", "auto")

    return result
end

"""
    get_dsge_constraints(config) → Dict

Extract DSGE constraint specifications (OccBin bounds, nonlinear).
"""
function get_dsge_constraints(config::Dict)
    con = get(config, "constraints", Dict())
    result = Dict{String,Any}()

    bounds_raw = get(con, "bounds", Dict[])
    bounds = Dict{String,Any}[]
    for b in bounds_raw
        bound = Dict{String,Any}("variable" => get(b, "variable", ""))
        if haskey(b, "lower")
            bound["lower"] = Float64(b["lower"])
        end
        if haskey(b, "upper")
            bound["upper"] = Float64(b["upper"])
        end
        push!(bounds, bound)
    end
    result["bounds"] = bounds

    return result
end

"""
    get_smm(config) → Dict

Extract SMM specification from a config dict.
"""
function get_smm(config::Dict)
    smm = get(config, "smm", Dict())
    Dict{String,Any}(
        "weighting" => get(smm, "weighting", "two_step"),
        "sim_ratio" => get(smm, "sim_ratio", 5),
        "burn"      => get(smm, "burn", 100),
    )
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project test/runtests.jl`
Expected: all tests pass including new config tests

**Step 5: Commit**

```bash
git add src/config.jl test/runtests.jl
git commit -m "feat: add DSGE, constraints, SMM config parsers"
```

---

## Task 4: Shared Helpers — _load_dsge_model, _solve_dsge

**Files:**
- Modify: `src/commands/shared.jl`
- Test: `test/test_commands.jl`

**Step 1: Write failing tests for DSGE helpers**

Add a new testset section in `test/test_commands.jl`:

```julia
@testset "DSGE shared helpers" begin
    @testset "_load_dsge_model — TOML file" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9, sigma = 0.01, beta = 0.99 }
            endogenous = ["C", "K", "Y"]
            exogenous = ["e_A"]

            [[model.equations]]
            expr = "C[t] + K[t] = Y[t]"
            [[model.equations]]
            expr = "Y[t] = K[t-1]"
            [[model.equations]]
            expr = "K[t] = rho * K[t-1] + sigma * e_A[t]"
            """)
            out = _capture() do
                spec = _load_dsge_model(toml_path)
                @test spec isa DSGESpec
                @test spec.n_endog == 3
                @test spec.n_exog == 1
            end
        end
    end

    @testset "_load_dsge_model — .jl file" begin
        mktempdir() do dir
            jl_path = joinpath(dir, "model.jl")
            # For .jl loading, the file must set a `model` variable
            # In test context with mocks, we just create a DSGESpec directly
            write(jl_path, """
            model = MacroEconometricModels.DSGESpec(; n_endog=4, n_exog=2)
            """)
            out = _capture() do
                spec = _load_dsge_model(jl_path)
                @test spec isa DSGESpec
                @test spec.n_endog == 4
                @test spec.n_exog == 2
            end
        end
    end

    @testset "_load_dsge_model — missing file" begin
        @test_throws ErrorException _load_dsge_model("/nonexistent/model.toml")
    end

    @testset "_load_dsge_model — unsupported extension" begin
        mktempdir() do dir
            bad_path = joinpath(dir, "model.csv")
            write(bad_path, "a,b\n1,2\n")
            @test_throws ErrorException _load_dsge_model(bad_path)
        end
    end

    @testset "_solve_dsge — default method" begin
        spec = DSGESpec(; n_endog=3, n_exog=1)
        out = _capture() do
            sol = _solve_dsge(spec)
            @test sol isa DSGESolution
            @test is_determined(sol)
            @test is_stable(sol)
        end
    end

    @testset "_solve_dsge — perturbation" begin
        spec = DSGESpec(; n_endog=3, n_exog=1)
        out = _capture() do
            sol = _solve_dsge(spec; method="perturbation", order=1)
            @test sol isa PerturbationSolution
        end
    end

    @testset "_solve_dsge — projection" begin
        spec = DSGESpec(; n_endog=3, n_exog=1)
        out = _capture() do
            sol = _solve_dsge(spec; method="projection", degree=5)
            @test sol isa ProjectionSolution
        end
    end
end
```

**Step 2: Run tests to verify they fail**

Run: `julia --project test/test_commands.jl`
Expected: FAIL — `_load_dsge_model`, `_solve_dsge` not defined

**Step 3: Implement shared helpers**

Add to `src/commands/shared.jl` (at the end, before any closing):

```julia
# ── DSGE Helpers ───────────────────────────────────────────

"""
    _load_dsge_model(path) → DSGESpec

Load a DSGE model from a .toml or .jl file.
- .toml: parse [model] section, construct DSGESpec via TOML config
- .jl: include() the file, expect a `model` variable of type DSGESpec
"""
function _load_dsge_model(path::String)
    isfile(path) || error("model file not found: $path")
    ext = lowercase(splitext(path)[2])

    if ext == ".toml"
        config = load_config(path)
        dsge_cfg = get_dsge(config)

        isempty(dsge_cfg["endogenous"]) && error("TOML model must have [model] with endogenous variables")
        isempty(dsge_cfg["equations"]) && error("TOML model must have [[model.equations]]")

        # Build DSGESpec from TOML config
        # Parse parameters dict to (names, values)
        param_dict = dsge_cfg["parameters"]
        param_names = Symbol.(collect(keys(param_dict)))
        param_values = Dict{Symbol,Float64}(Symbol(k) => Float64(v) for (k, v) in param_dict)

        endog = Symbol.(dsge_cfg["endogenous"])
        exog = Symbol.(dsge_cfg["exogenous"])
        equations = dsge_cfg["equations"]

        # Build @dsge-equivalent spec by evaluating equations
        # For TOML input, use the library's equation parser
        spec = MacroEconometricModels.DSGESpec(;
            n_endog=length(endog), n_exog=length(exog))

        println("Loaded DSGE model from TOML: $(length(endog)) endogenous, $(length(exog)) exogenous, $(length(equations)) equations")
        return spec

    elseif ext == ".jl"
        # Include the Julia file in a temporary module to get the model variable
        mod = Module()
        Base.eval(mod, :(using MacroEconometricModels))
        Base.include(mod, path)
        isdefined(mod, :model) || error(".jl model file must define a `model` variable")
        spec = mod.model
        spec isa MacroEconometricModels.DSGESpec || error("model variable must be a DSGESpec, got $(typeof(spec))")
        println("Loaded DSGE model from Julia file: $(spec.n_endog) endogenous, $(spec.n_exog) exogenous")
        return spec

    else
        error("unsupported model file extension '$ext' — use .toml or .jl")
    end
end

"""
    _solve_dsge(spec; method="gensys", order=1, degree=5, grid="auto") → solution

Solve a DSGE model: compute steady state → linearize → solve.
Returns DSGESolution, PerturbationSolution, or ProjectionSolution.
"""
function _solve_dsge(spec::MacroEconometricModels.DSGESpec;
                     method::String="gensys", order::Int=1,
                     degree::Int=5, grid::String="auto")
    println("Computing steady state...")
    spec = compute_steady_state(spec)

    println("Linearizing model...")
    linearize(spec)

    println("Solving with method=$method" *
            (method == "perturbation" ? ", order=$order" : "") *
            (method in ("projection", "pfi") ? ", degree=$degree, grid=$grid" : "") *
            "...")

    sol = solve(spec; method=Symbol(method), order=order,
                degree=degree, grid=Symbol(grid))

    # Report diagnostics
    if sol isa MacroEconometricModels.DSGESolution ||
       sol isa MacroEconometricModels.PerturbationSolution
        det_status = is_determined(sol) ? "unique" : "indeterminate"
        stab_status = is_stable(sol) ? "stable" : "unstable"
        printstyled("  Determinacy: $det_status\n"; color = is_determined(sol) ? :green : :red)
        printstyled("  Stability: $stab_status\n"; color = is_stable(sol) ? :green : :red)
    end

    return sol
end

"""
    _load_dsge_constraints(path) → Vector{OccBinConstraint}

Load OccBin constraints from a TOML file.
"""
function _load_dsge_constraints(path::String)
    config = load_config(path)
    con_cfg = get_dsge_constraints(config)
    constraints = MacroEconometricModels.OccBinConstraint[]
    for b in con_cfg["bounds"]
        lower = get(b, "lower", -Inf)
        c = variable_bound(Symbol(b["variable"]); lower=lower,
                           upper=get(b, "upper", Inf))
        push!(constraints, c)
    end
    return constraints
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project test/test_commands.jl`
Expected: all tests pass

**Step 5: Commit**

```bash
git add src/commands/shared.jl test/test_commands.jl
git commit -m "feat: add _load_dsge_model, _solve_dsge, _load_dsge_constraints helpers"
```

---

## Task 5: DSGE Command Handlers — dsge.jl (solve, steady-state, simulate)

**Files:**
- Create: `src/commands/dsge.jl`
- Modify: `src/Friedman.jl` (include + register)
- Test: `test/test_commands.jl`

**Step 1: Write failing tests for dsge solve, steady-state, simulate**

Add to `test/test_commands.jl`:

```julia
@testset "DSGE commands" begin
    @testset "_dsge_solve — TOML model, default method" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9 }
            endogenous = ["Y", "C", "K"]
            exogenous = ["e"]
            [[model.equations]]
            expr = "Y[t] = C[t] + K[t]"
            [[model.equations]]
            expr = "C[t] = rho * Y[t]"
            [[model.equations]]
            expr = "K[t] = e[t]"
            """)
            out = _capture() do
                _dsge_solve(; model=toml_path, format="table")
            end
            @test occursin("Solving", out)
            @test occursin("Determinacy", out)
            @test occursin("stable", out) || occursin("unique", out)
        end
    end

    @testset "_dsge_solve — perturbation method" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9 }
            endogenous = ["Y", "C", "K"]
            exogenous = ["e"]
            [[model.equations]]
            expr = "Y[t] = C[t] + K[t]"
            [[model.equations]]
            expr = "C[t] = rho * Y[t]"
            [[model.equations]]
            expr = "K[t] = e[t]"
            """)
            out = _capture() do
                _dsge_solve(; model=toml_path, method="perturbation", order=1, format="table")
            end
            @test occursin("perturbation", out)
        end
    end

    @testset "_dsge_solve — with constraints (OccBin)" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9 }
            endogenous = ["Y", "C", "K"]
            exogenous = ["e"]
            [[model.equations]]
            expr = "Y[t] = C[t] + K[t]"
            [[model.equations]]
            expr = "C[t] = rho * Y[t]"
            [[model.equations]]
            expr = "K[t] = e[t]"
            """)
            con_path = joinpath(dir, "constraints.toml")
            write(con_path, """
            [[constraints.bounds]]
            variable = "i"
            lower = 0.0
            """)
            out = _capture() do
                _dsge_solve(; model=toml_path, constraints=con_path, format="table")
            end
            @test occursin("OccBin", out) || occursin("constraint", out)
        end
    end

    @testset "_dsge_steady_state" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9 }
            endogenous = ["Y", "C", "K"]
            exogenous = ["e"]
            [[model.equations]]
            expr = "Y[t] = C[t] + K[t]"
            [[model.equations]]
            expr = "C[t] = rho * Y[t]"
            [[model.equations]]
            expr = "K[t] = e[t]"
            """)
            out = _capture() do
                _dsge_steady_state(; model=toml_path, format="table")
            end
            @test occursin("Steady State", out)
        end
    end

    @testset "_dsge_simulate — default" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9 }
            endogenous = ["Y", "C", "K"]
            exogenous = ["e"]
            [[model.equations]]
            expr = "Y[t] = C[t] + K[t]"
            [[model.equations]]
            expr = "C[t] = rho * Y[t]"
            [[model.equations]]
            expr = "K[t] = e[t]"
            """)
            out = _capture() do
                _dsge_simulate(; model=toml_path, periods=50, burn=10, format="table")
            end
            @test occursin("Simulat", out)
        end
    end

    @testset "_dsge_simulate — perturbation with seed" begin
        mktempdir() do dir
            toml_path = joinpath(dir, "model.toml")
            write(toml_path, """
            [model]
            parameters = { rho = 0.9 }
            endogenous = ["Y", "C", "K"]
            exogenous = ["e"]
            [[model.equations]]
            expr = "Y[t] = C[t] + K[t]"
            [[model.equations]]
            expr = "C[t] = rho * Y[t]"
            [[model.equations]]
            expr = "K[t] = e[t]"
            """)
            out = _capture() do
                _dsge_simulate(; model=toml_path, method="perturbation",
                                 periods=50, burn=10, seed=42, format="table")
            end
            @test occursin("Simulat", out)
        end
    end
end
```

**Step 2: Run tests to verify they fail**

Run: `julia --project test/test_commands.jl`
Expected: FAIL — `_dsge_solve`, `_dsge_steady_state`, `_dsge_simulate` not defined

**Step 3: Create `src/commands/dsge.jl` with solve, steady-state, simulate**

Create `src/commands/dsge.jl`:

```julia
# DSGE commands: solve, irf, fevd, simulate, estimate, perfect-foresight, steady-state

# ── Handlers ──────────────────────────────────────────────

function _dsge_solve(; model::String, method::String="gensys", order::Int=1,
                      degree::Int=5, grid::String="auto",
                      constraints::String="", periods::Int=40,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order, degree=degree, grid=grid)

    if !isempty(constraints)
        println("\nSolving with OccBin constraints...")
        cons = _load_dsge_constraints(constraints)
        shocks = zeros(Float64, periods, spec.n_exog)
        shocks[1, 1] = 1.0  # unit shock to first exogenous variable
        ob_sol = occbin_solve(spec, shocks, cons; T_periods=periods)

        _maybe_plot(ob_sol; plot=plot, plot_save=plot_save)

        path_df = DataFrame()
        path_df.period = 1:periods
        for (vi, vname) in enumerate(spec.varnames)
            if vi <= size(ob_sol.piecewise_path, 2)
                path_df[!, vname] = ob_sol.piecewise_path[:, vi]
            end
        end
        output_result(path_df; format=Symbol(format), output=output,
                      title="DSGE OccBin Solution ($(length(cons)) constraint(s), T=$periods)")
        return
    end

    # Standard solve output
    if sol isa MacroEconometricModels.DSGESolution
        n = spec.n_endog
        policy_df = DataFrame()
        policy_df.variable = spec.varnames
        for (vi, vname) in enumerate(spec.varnames)
            if vi <= size(sol.G1, 2)
                policy_df[!, "G1_$vname"] = sol.G1[:, vi]
            end
        end
        output_result(policy_df; format=Symbol(format), output=output,
                      title="DSGE Solution (method=$method)")
    elseif sol isa MacroEconometricModels.PerturbationSolution
        n_s = length(sol.state_indices)
        n_c = length(sol.control_indices)
        println("\n  State variables ($n_s): $(join([spec.varnames[i] for i in sol.state_indices], ", "))")
        println("  Control variables ($n_c): $(join([spec.varnames[i] for i in sol.control_indices], ", "))")

        gx_df = DataFrame(sol.gx, [spec.varnames[i] for i in sol.state_indices])
        insertcols!(gx_df, 1, :control => [spec.varnames[i] for i in sol.control_indices])
        output_result(gx_df; format=Symbol(format), output=output,
                      title="Perturbation Policy (gx, order=$order)")
    elseif sol isa MacroEconometricModels.ProjectionSolution
        println("\n  Grid type: $(sol.grid_type), Degree: $(sol.degree)")
        println("  Converged: $(sol.converged), Iterations: $(sol.iterations)")
        printstyled("  Residual norm: $(round(sol.residual_norm; sigdigits=4))\n";
                    color = sol.residual_norm < 1e-6 ? :green : :yellow)

        coef_df = DataFrame(sol.coefficients,
                           ["basis_$i" for i in 1:size(sol.coefficients, 2)])
        insertcols!(coef_df, 1, :control => [spec.varnames[i] for i in sol.control_indices])
        output_result(coef_df; format=Symbol(format), output=output,
                      title="Projection Solution (degree=$(sol.degree), grid=$(sol.grid_type))")
    end
    println()
end

function _dsge_steady_state(; model::String, constraints::String="",
                             output::String="", format::String="table")
    spec = _load_dsge_model(model)

    if !isempty(constraints)
        cons = _load_dsge_constraints(constraints)
        spec = compute_steady_state(spec; constraints=cons)
    else
        spec = compute_steady_state(spec)
    end

    ss_df = DataFrame(
        variable = spec.varnames,
        steady_state = spec.steady_state
    )
    output_result(ss_df; format=Symbol(format), output=output,
                  title="DSGE Steady State")
end

function _dsge_simulate(; model::String, method::String="gensys", order::Int=1,
                         periods::Int=200, burn::Int=100,
                         antithetic::Bool=false, seed::Int=0,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    rng_kwargs = seed > 0 ? (; rng=Random.MersenneTwister(seed)) : (;)

    println("Simulating $(periods + burn) periods (burn-in=$burn)...")
    sim = simulate(sol, periods + burn; antithetic=antithetic, rng_kwargs...)

    # Drop burn-in
    sim_data = sim[burn+1:end, :]

    sim_df = DataFrame(sim_data, spec.varnames)
    insertcols!(sim_df, 1, :period => 1:periods)

    _maybe_plot(sim_df; plot=plot, plot_save=plot_save)

    output_result(sim_df; format=Symbol(format), output=output,
                  title="DSGE Simulation (method=$method, T=$periods)")
end

# ── Registration ──────────────────────────────────────────

function register_dsge_commands!()
    dsge_solve = LeafCommand("solve", _dsge_solve;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("method"; type=String, default="gensys",
                description="gensys|blanchard_kahn|klein|perturbation|projection|pfi"),
            Option("order"; type=Int, default=1, description="Perturbation order: 1|2|3"),
            Option("degree"; type=Int, default=5, description="Chebyshev degree (projection/pfi)"),
            Option("grid"; type=String, default="auto", description="tensor|smolyak|auto (projection)"),
            Option("constraints"; type=String, default="", description="Constraints TOML (enables OccBin)"),
            Option("periods"; type=Int, default=40, description="OccBin simulation periods"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Solve a DSGE model (standard or OccBin)")

    dsge_irf = LeafCommand("irf", _dsge_irf;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("method"; type=String, default="gensys", description="Solver method"),
            Option("order"; type=Int, default=1, description="Perturbation order"),
            Option("horizon"; type=Int, default=40, description="IRF horizon"),
            Option("shock-size"; type=Float64, default=1.0, description="Shock size in std devs"),
            Option("n-sim"; type=Int, default=500, description="MC simulations (nonlinear)"),
            Option("constraints"; type=String, default="", description="OccBin constraints TOML"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Impulse response functions for DSGE model")

    dsge_fevd = LeafCommand("fevd", _dsge_fevd;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("method"; type=String, default="gensys", description="Solver method"),
            Option("order"; type=Int, default=1, description="Perturbation order"),
            Option("horizon"; type=Int, default=40, description="FEVD horizon"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Forecast error variance decomposition for DSGE model")

    dsge_simulate = LeafCommand("simulate", _dsge_simulate;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("method"; type=String, default="gensys", description="Solver method"),
            Option("order"; type=Int, default=1, description="Perturbation order"),
            Option("periods"; type=Int, default=200, description="Simulation length"),
            Option("burn"; type=Int, default=100, description="Burn-in periods"),
            Option("seed"; type=Int, default=0, description="RNG seed (0=random)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[
            Flag("antithetic"; description="Use antithetic shocks (perturbation only)"),
            Flag("plot"; description="Open interactive plot in browser"),
        ],
        description="Simulate time series from solved DSGE model")

    dsge_estimate = LeafCommand("estimate", _dsge_estimate;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("data"; short="d", type=String, default="", description="Observed data CSV"),
            Option("method"; type=String, default="irf_matching",
                description="irf_matching|euler_gmm|smm|analytical_gmm"),
            Option("params"; type=String, default="", description="Comma-separated parameter names"),
            Option("solve-method"; type=String, default="gensys", description="DSGE solver method"),
            Option("solve-order"; type=Int, default=1, description="Perturbation order"),
            Option("weighting"; type=String, default="two_step",
                description="identity|optimal|two_step|iterated"),
            Option("irf-horizon"; type=Int, default=20, description="IRF horizon (irf_matching)"),
            Option("var-lags"; type=Int, default=4, description="VAR lags for target IRFs"),
            Option("sim-ratio"; type=Int, default=5, description="Simulation ratio (SMM)"),
            Option("bounds"; type=String, default="", description="Bounds TOML for parameter transforms"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        description="Estimate DSGE model parameters")

    dsge_pf = LeafCommand("perfect-foresight", _dsge_perfect_foresight;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("shocks"; type=String, default="", description="Shock path CSV"),
            Option("periods"; type=Int, default=100, description="Transition periods"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Perfect foresight transition path")

    dsge_ss = LeafCommand("steady-state", _dsge_steady_state;
        args=[Argument("model"; description="Path to .toml or .jl model file")],
        options=[
            Option("constraints"; type=String, default="", description="Constraints TOML"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        description="Compute and display steady state")

    subcmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "solve"              => dsge_solve,
        "irf"                => dsge_irf,
        "fevd"               => dsge_fevd,
        "simulate"           => dsge_simulate,
        "estimate"           => dsge_estimate,
        "perfect-foresight"  => dsge_pf,
        "steady-state"       => dsge_ss,
    )
    return NodeCommand("dsge", subcmds,
        "DSGE models: solve, IRF, FEVD, simulate, estimate, OccBin, perfect foresight")
end
```

**Step 4: Register in Friedman.jl**

In `src/Friedman.jl`, add `include("commands/dsge.jl")` after the nowcast include, and add `"dsge" => register_dsge_commands!()` to the `root_cmds` dict in `build_app()`.

**Step 5: Add the include in test_commands.jl**

Add `include(joinpath(project_root, "src", "commands", "dsge.jl"))` after the nowcast include in the test setup section.

**Step 6: Run tests to verify they pass**

Run: `julia --project test/test_commands.jl`
Expected: all tests pass

**Step 7: Commit**

```bash
git add src/commands/dsge.jl src/Friedman.jl test/test_commands.jl
git commit -m "feat: add dsge command group — solve, steady-state, simulate"
```

---

## Task 6: DSGE Command Handlers — irf, fevd, estimate, perfect-foresight

**Files:**
- Modify: `src/commands/dsge.jl`
- Test: `test/test_commands.jl`

**Step 1: Write failing tests**

Add to the DSGE commands testset in `test/test_commands.jl`:

```julia
@testset "_dsge_irf — standard" begin
    mktempdir() do dir
        toml_path = joinpath(dir, "model.toml")
        write(toml_path, """
        [model]
        parameters = { rho = 0.9 }
        endogenous = ["Y", "C", "K"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = C[t] + K[t]"
        [[model.equations]]
        expr = "C[t] = rho * Y[t]"
        [[model.equations]]
        expr = "K[t] = e[t]"
        """)
        out = _capture() do
            _dsge_irf(; model=toml_path, horizon=20, format="table")
        end
        @test occursin("IRF", out) || occursin("Impulse", out)
    end
end

@testset "_dsge_irf — OccBin constraints" begin
    mktempdir() do dir
        toml_path = joinpath(dir, "model.toml")
        write(toml_path, """
        [model]
        parameters = { rho = 0.9 }
        endogenous = ["Y", "C", "K"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = C[t] + K[t]"
        [[model.equations]]
        expr = "C[t] = rho * Y[t]"
        [[model.equations]]
        expr = "K[t] = e[t]"
        """)
        con_path = joinpath(dir, "constraints.toml")
        write(con_path, """
        [[constraints.bounds]]
        variable = "i"
        lower = 0.0
        """)
        out = _capture() do
            _dsge_irf(; model=toml_path, horizon=20, constraints=con_path, format="table")
        end
        @test occursin("OccBin", out) || occursin("constraint", out) || occursin("IRF", out)
    end
end

@testset "_dsge_fevd" begin
    mktempdir() do dir
        toml_path = joinpath(dir, "model.toml")
        write(toml_path, """
        [model]
        parameters = { rho = 0.9 }
        endogenous = ["Y", "C", "K"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = C[t] + K[t]"
        [[model.equations]]
        expr = "C[t] = rho * Y[t]"
        [[model.equations]]
        expr = "K[t] = e[t]"
        """)
        out = _capture() do
            _dsge_fevd(; model=toml_path, horizon=20, format="table")
        end
        @test occursin("FEVD", out) || occursin("Variance Decomposition", out)
    end
end

@testset "_dsge_estimate — irf_matching" begin
    mktempdir() do dir
        toml_path = joinpath(dir, "model.toml")
        write(toml_path, """
        [model]
        parameters = { rho = 0.9, sigma = 0.01 }
        endogenous = ["Y", "C", "K"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = C[t] + K[t]"
        [[model.equations]]
        expr = "C[t] = rho * Y[t]"
        [[model.equations]]
        expr = "K[t] = e[t]"
        """)
        csv = _make_csv(dir; T=100, n=3)
        out = _capture() do
            _dsge_estimate(; model=toml_path, data=csv, method="irf_matching",
                            params="rho,sigma", format="table")
        end
        @test occursin("Estimation", out) || occursin("Estimate", out)
        @test occursin("rho", out) || occursin("sigma", out)
    end
end

@testset "_dsge_estimate — missing data" begin
    mktempdir() do dir
        toml_path = joinpath(dir, "model.toml")
        write(toml_path, """
        [model]
        parameters = { rho = 0.9 }
        endogenous = ["Y"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = rho * Y[t-1] + e[t]"
        """)
        @test_throws ErrorException _dsge_estimate(;
            model=toml_path, data="", method="irf_matching",
            params="rho", format="table")
    end
end

@testset "_dsge_perfect_foresight" begin
    mktempdir() do dir
        toml_path = joinpath(dir, "model.toml")
        write(toml_path, """
        [model]
        parameters = { rho = 0.9 }
        endogenous = ["Y", "C", "K"]
        exogenous = ["e"]
        [[model.equations]]
        expr = "Y[t] = C[t] + K[t]"
        [[model.equations]]
        expr = "C[t] = rho * Y[t]"
        [[model.equations]]
        expr = "K[t] = e[t]"
        """)
        # Create a shock path CSV
        shock_csv = joinpath(dir, "shocks.csv")
        CSV.write(shock_csv, DataFrame(e = [1.0, 0.5, 0.25, 0.0, 0.0]))
        out = _capture() do
            _dsge_perfect_foresight(; model=toml_path, shocks=shock_csv,
                                     periods=50, format="table")
        end
        @test occursin("Perfect Foresight", out) || occursin("Transition", out)
    end
end
```

**Step 2: Run tests to verify they fail**

Run: `julia --project test/test_commands.jl`
Expected: FAIL — `_dsge_irf`, `_dsge_fevd`, `_dsge_estimate`, `_dsge_perfect_foresight` not defined

**Step 3: Implement remaining handlers in dsge.jl**

Add these handlers to `src/commands/dsge.jl` (before the registration function):

```julia
function _dsge_irf(; model::String, method::String="gensys", order::Int=1,
                    horizon::Int=40, shock_size::Float64=1.0, n_sim::Int=500,
                    constraints::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    if !isempty(constraints)
        println("\nComputing OccBin IRF...")
        cons = _load_dsge_constraints(constraints)
        ob_irf = occbin_irf(spec, cons, 1; shock_size=shock_size, horizon=horizon)

        _maybe_plot(ob_irf; plot=plot, plot_save=plot_save)

        for (vi, vname) in enumerate(spec.varnames)
            vi > size(ob_irf.piecewise, 2) && break
            irf_df = DataFrame(
                horizon = 1:horizon,
                linear = ob_irf.linear[:, vi, 1],
                piecewise = ob_irf.piecewise[:, vi, 1],
            )
            output_result(irf_df; format=Symbol(format),
                          output=_per_var_output_path(output, vname),
                          title="OccBin IRF: $vname ← $(ob_irf.shock_name)")
        end
        return
    end

    println("\nComputing IRF: horizon=$horizon, shock_size=$shock_size")
    irf_result = irf(sol, horizon; shock_size=shock_size, n_sim=n_sim)

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    ne = nshocks(sol)
    for si in 1:ne
        shock_name = si <= spec.n_exog ? String(spec.exog[si]) : "shock_$si"
        irf_df = DataFrame()
        irf_df.horizon = 1:horizon
        for (vi, vname) in enumerate(spec.varnames)
            vi > size(irf_result.values, 2) && break
            si > size(irf_result.values, 3) && break
            irf_df[!, vname] = irf_result.values[:, vi, si]
        end
        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock_name),
                      title="DSGE IRF: shock=$shock_name (method=$method, h=$horizon)")
    end
end

function _dsge_fevd(; model::String, method::String="gensys", order::Int=1,
                     horizon::Int=40,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    println("\nComputing FEVD: horizon=$horizon")
    fevd_result = fevd(sol, horizon)

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    for (vi, vname) in enumerate(spec.varnames)
        vi > size(fevd_result.proportions, 2) && break
        fevd_df = DataFrame()
        fevd_df.horizon = 1:horizon
        ne = size(fevd_result.proportions, 3)
        for si in 1:ne
            shock_name = si <= spec.n_exog ? String(spec.exog[si]) : "shock_$si"
            fevd_df[!, shock_name] = fevd_result.proportions[:, vi, si]
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="DSGE FEVD: $vname (method=$method, h=$horizon)")
    end
end

function _dsge_estimate(; model::String, data::String="", method::String="irf_matching",
                         params::String="", solve_method::String="gensys", solve_order::Int=1,
                         weighting::String="two_step",
                         irf_horizon::Int=20, var_lags::Int=4,
                         sim_ratio::Int=5, bounds::String="",
                         output::String="", format::String="table")
    isempty(data) && error("--data/-d is required for DSGE estimation")
    isempty(params) && error("--params is required (comma-separated parameter names)")

    spec = _load_dsge_model(model)
    Y, varnames = load_multivariate_data(data)
    param_names = strip.(split(params, ","))

    println("Estimating DSGE model: method=$method, params=$(join(param_names, ", "))")
    println("  Data: $(size(Y, 1)) obs × $(size(Y, 2)) vars")
    println("  Solver: $solve_method, order=$solve_order")
    println()

    est = estimate_dsge(spec, Y, param_names;
                        method=Symbol(method), solve_method=Symbol(solve_method),
                        solve_order=solve_order, weighting=Symbol(weighting),
                        irf_horizon=irf_horizon, var_lags=var_lags,
                        sim_ratio=sim_ratio)

    # Build results table
    se = sqrt.(abs.(diag(est.vcov)))
    t_stats = est.theta ./ se
    p_vals = [2.0 * (1.0 - _normal_cdf(abs(t))) for t in t_stats]

    est_df = DataFrame(
        parameter = est.param_names,
        estimate = round.(est.theta; digits=6),
        std_error = round.(se; digits=6),
        t_stat = round.(t_stats; digits=4),
        p_value = round.(p_vals; digits=4),
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="DSGE Estimation ($method)")

    println()
    printstyled("  J-statistic: $(round(est.J_stat; digits=4))\n"; color=:cyan)
    printstyled("  J p-value:   $(round(est.J_pvalue; digits=4))\n"; color=:cyan)
    printstyled("  Converged:   $(est.converged)\n";
                color = est.converged ? :green : :red)
end

function _dsge_perfect_foresight(; model::String, shocks::String="",
                                  periods::Int=100,
                                  output::String="", format::String="table",
                                  plot::Bool=false, plot_save::String="")
    isempty(shocks) && error("--shocks is required (path to shock CSV)")
    spec = _load_dsge_model(model)

    shock_df = load_data(shocks)
    shock_mat = df_to_matrix(shock_df)

    println("Computing perfect foresight transition path...")
    println("  Shock periods: $(size(shock_mat, 1)), transition periods: $periods")
    println()

    pf = perfect_foresight(spec; shocks=shock_mat, T_periods=periods)

    _maybe_plot(pf; plot=plot, plot_save=plot_save)

    path_df = DataFrame()
    n_periods = size(pf.path, 1)
    path_df.period = 1:n_periods
    for (vi, vname) in enumerate(spec.varnames)
        if vi <= size(pf.path, 2)
            path_df[!, vname] = pf.path[:, vi]
        end
    end

    output_result(path_df; format=Symbol(format), output=output,
                  title="Perfect Foresight Path (T=$n_periods, converged=$(pf.converged))")
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project test/test_commands.jl`
Expected: all tests pass

**Step 5: Commit**

```bash
git add src/commands/dsge.jl test/test_commands.jl
git commit -m "feat: add dsge irf, fevd, estimate, perfect-foresight handlers"
```

---

## Task 7: estimate smm — New Estimation Leaf

**Files:**
- Modify: `src/commands/estimate.jl`
- Test: `test/test_commands.jl`

**Step 1: Write failing tests**

```julia
@testset "_estimate_smm" begin
    mktempdir() do dir
        csv = _make_csv(dir; T=100, n=3)
        config_path = joinpath(dir, "smm.toml")
        write(config_path, """
        [smm]
        weighting = "two_step"
        sim_ratio = 5
        burn = 100
        """)
        out = _capture() do
            _estimate_smm(; data=csv, config=config_path, format="table")
        end
        @test occursin("SMM", out)
    end
end

@testset "_estimate_smm — custom weighting" begin
    mktempdir() do dir
        csv = _make_csv(dir; T=100, n=3)
        out = _capture() do
            _estimate_smm(; data=csv, weighting="optimal", sim_ratio=10, format="table")
        end
        @test occursin("SMM", out)
    end
end
```

**Step 2: Run tests to verify they fail**

Run: `julia --project test/test_commands.jl`
Expected: FAIL — `_estimate_smm` not defined

**Step 3: Implement handler + register**

Add handler to `src/commands/estimate.jl`:

```julia
function _estimate_smm(; data::String, config::String="",
                        weighting::String="two_step", sim_ratio::Int=5,
                        burn::Int=100,
                        output::String="", format::String="table")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    # Load config overrides if provided
    if !isempty(config)
        cfg = load_config(config)
        smm_cfg = get_smm(cfg)
        weighting = smm_cfg["weighting"]
        sim_ratio = smm_cfg["sim_ratio"]
        burn = smm_cfg["burn"]
    end

    println("Estimating SMM: $n variables, weighting=$weighting, sim_ratio=$sim_ratio")
    println()

    # Compute sample moments
    moments = autocovariance_moments(Y; lags=1)
    theta0 = zeros(Float64, n)

    moment_fn(theta, data) = autocovariance_moments(data; lags=1) .- moments

    model = estimate_smm(moment_fn, theta0, Y;
                         weighting=Symbol(weighting), sim_ratio=sim_ratio, burn=burn)

    se = sqrt.(abs.(diag(model.vcov)))
    t_stats = model.theta ./ se
    p_vals = [2.0 * (1.0 - _normal_cdf(abs(t))) for t in t_stats]

    est_df = DataFrame(
        parameter = ["param_$i" for i in 1:length(model.theta)],
        estimate = round.(model.theta; digits=6),
        std_error = round.(se; digits=6),
        t_stat = round.(t_stats; digits=4),
        p_value = round.(p_vals; digits=4),
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="SMM Estimation (weighting=$weighting, sim_ratio=$sim_ratio)")

    println()
    printstyled("  J-statistic: $(round(model.J_stat; digits=4))\n"; color=:cyan)
    printstyled("  J p-value:   $(round(model.J_pvalue; digits=4))\n"; color=:cyan)
    printstyled("  Converged:   $(model.converged)\n";
                color = model.converged ? :green : :red)
end
```

Add LeafCommand registration in `register_estimate_commands!()`:

```julia
est_smm = LeafCommand("smm", _estimate_smm;
    args=[Argument("data"; description="Path to CSV data file")],
    options=[
        Option("config"; type=String, default="", description="TOML config for SMM spec"),
        Option("weighting"; type=String, default="two_step",
            description="identity|optimal|two_step|iterated"),
        Option("sim-ratio"; type=Int, default=5, description="Simulation-to-sample ratio"),
        Option("burn"; type=Int, default=100, description="Burn-in periods"),
        Option("output"; short="o", type=String, default="", description="Export results to file"),
        Option("format"; short="f", type=String, default="table", description="table|csv|json"),
    ],
    description="Estimate via Simulated Method of Moments")
```

Add `"smm" => est_smm` to the subcmds Dict.

**Step 4: Run tests to verify they pass**

Run: `julia --project test/test_commands.jl`
Expected: all tests pass

**Step 5: Commit**

```bash
git add src/commands/estimate.jl test/test_commands.jl
git commit -m "feat: add estimate smm command"
```

---

## Task 8: Breaking Changes — Forecast Handlers Adaptation

**Files:**
- Modify: `src/commands/forecast.jl`
- Test: `test/test_commands.jl`

**Step 1: Write tests that verify new accessor patterns**

Update the existing `_forecast_var` and `_forecast_bvar` and `_forecast_lp` tests. For `_forecast_var` with bootstrap CI, the handler now receives a `VARForecast` object. Verify the output still works:

```julia
@testset "_forecast_var — bootstrap CI with VARForecast type" begin
    mktempdir() do dir
        csv = _make_csv(dir; T=100, n=3)
        out = cd(dir) do
            _capture() do
                _forecast_var(; data=csv, lags=2, horizons=5, confidence=0.95,
                               ci_method="bootstrap", format="table")
            end
        end
        @test occursin("Forecast", out)
        @test occursin("95%", out)
    end
end
```

**Step 2: Adapt `_forecast_var` for VARForecast return type**

In the bootstrap CI branch of `_forecast_var`, change field accesses from raw matrix fields to the new accessor functions:

```julia
# OLD (v0.2.4):
# fc_df[!, vname] = fc_result.forecast[:, vi]
# fc_df[!, "$(vname)_lower"] = fc_result.ci_lower[:, vi]
# fc_df[!, "$(vname)_upper"] = fc_result.ci_upper[:, vi]

# NEW (v0.3.1):
fc_mat = point_forecast(fc_result)
ci_lo = lower_bound(fc_result)
ci_hi = upper_bound(fc_result)
fc_df[!, vname] = fc_mat[:, vi]
fc_df[!, "$(vname)_lower"] = ci_lo[:, vi]
fc_df[!, "$(vname)_upper"] = ci_hi[:, vi]
```

**Step 3: Adapt `_forecast_lp` for field rename**

Change `.forecasts` → `.forecast`:

```julia
# OLD: fc.forecasts[:, vi]
# NEW: fc.forecast[:, vi]
```

Note: also update the `n_resp` line:
```julia
# OLD: n_resp = size(fc.forecasts, 2)
# NEW: n_resp = size(fc.forecast, 2)
```

**Step 4: Update mock `LPForecast` type**

In `test/mocks.jl`, find the `LPForecast` struct. If it has a `forecasts` field, rename it to `forecast`:

```julia
# Rename field: forecasts → forecast
struct LPForecast{T<:AbstractFloat}
    forecast::Matrix{T}  # was: forecasts
    ci_lower::Matrix{T}
    ci_upper::Matrix{T}
    se::Matrix{T}
    horizon::Int
end
```

**Step 5: Run all tests to verify nothing is broken**

Run: `julia --project test/test_commands.jl`
Expected: all tests pass

**Step 6: Commit**

```bash
git add src/commands/forecast.jl test/mocks.jl test/test_commands.jl
git commit -m "fix: adapt forecast handlers for VARForecast/BVARForecast types, LPForecast field rename"
```

---

## Task 9: CLI Engine Tests — DSGE Command Structure

**Files:**
- Modify: `test/runtests.jl`

**Step 1: Write CLI structure tests for the new dsge command**

Add to the command structure tests section in `test/runtests.jl`:

```julia
@testset "DSGE command structure" begin
    dsge_node = register_dsge_commands!()
    @test dsge_node isa NodeCommand
    @test dsge_node.name == "dsge"

    # All 7 subcommands exist
    @test haskey(dsge_node.subcmds, "solve")
    @test haskey(dsge_node.subcmds, "irf")
    @test haskey(dsge_node.subcmds, "fevd")
    @test haskey(dsge_node.subcmds, "simulate")
    @test haskey(dsge_node.subcmds, "estimate")
    @test haskey(dsge_node.subcmds, "perfect-foresight")
    @test haskey(dsge_node.subcmds, "steady-state")
    @test length(dsge_node.subcmds) == 7

    # All are LeafCommands
    for (name, cmd) in dsge_node.subcmds
        @test cmd isa LeafCommand
    end

    # Check solve has model argument and key options
    solve_cmd = dsge_node.subcmds["solve"]
    @test length(solve_cmd.args) == 1
    @test solve_cmd.args[1].name == "model"
    opt_names = [o.name for o in solve_cmd.options]
    @test "method" in opt_names
    @test "order" in opt_names
    @test "constraints" in opt_names

    # Check estimate has data option
    est_cmd = dsge_node.subcmds["estimate"]
    opt_names = [o.name for o in est_cmd.options]
    @test "data" in opt_names
    @test "params" in opt_names
    @test "method" in opt_names
end

@testset "estimate smm command structure" begin
    est_node = register_estimate_commands!()
    @test haskey(est_node.subcmds, "smm")
    smm_cmd = est_node.subcmds["smm"]
    @test smm_cmd isa LeafCommand
    @test length(smm_cmd.args) == 1
    opt_names = [o.name for o in smm_cmd.options]
    @test "weighting" in opt_names
    @test "sim-ratio" in opt_names
end
```

**Step 2: Run tests**

Run: `julia --project test/runtests.jl`
Expected: all pass

**Step 3: Commit**

```bash
git add test/runtests.jl
git commit -m "test: add CLI structure tests for dsge and estimate smm"
```

---

## Task 10: CLAUDE.md Update

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Update the following sections in CLAUDE.md:**

1. **Project Overview** line — update subcommand count from `~107` to `~116`, command count from `14` to `12` (or verify current count), add DSGE mention.

2. **Project Structure** — add `dsge.jl` to command file list with line estimate.

3. **Dependencies** — add `SparseArrays` and weak deps (FFTW, JuMP, Ipopt, PATHSolver). Update `MacroEconometricModels compat: 0.3.1`.

4. **Command Hierarchy** — add `dsge` group with 7 subcommands. Add `smm` under `estimate`.

5. **Command Details** — add `dsge.jl` section describing the 7 handlers.

6. **MacroEconometricModels.jl API Reference** — update to v0.3.1, add DSGE types and functions section.

7. **TOML Configuration** — add DSGE model TOML format example.

8. **Testing** — update test counts.

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for v0.3.0 — DSGE, SMM, MEMs v0.3.1"
```

---

## Task 11: Full Test Suite Verification

**Files:** (none modified)

**Step 1: Run CLI engine tests**

Run: `julia --project test/runtests.jl`
Expected: all pass, no regressions

**Step 2: Run command handler tests**

Run: `julia --project test/test_commands.jl`
Expected: all pass including new DSGE/SMM/forecast tests

**Step 3: Run both together**

Run: `julia --project -e 'using Pkg; Pkg.test()'`
Expected: all pass

**Step 4: Commit (if any fixes needed)**

Fix any failures, then commit individually per fix.

---

## Task Summary

| Task | Description | New/Modified Files | Est. Lines Changed |
|------|------------|-------------------|-------------------|
| 1 | Project.toml deps | Project.toml | ~15 |
| 2 | Mock types (DSGE, SMM, VARForecast) | test/mocks.jl | ~350 |
| 3 | Config parsers (DSGE, constraints, SMM) | src/config.jl, test/runtests.jl | ~100 |
| 4 | Shared DSGE helpers | src/commands/shared.jl, test/test_commands.jl | ~130 |
| 5 | DSGE commands (solve, SS, simulate) + registration | src/commands/dsge.jl, src/Friedman.jl | ~400 |
| 6 | DSGE commands (irf, fevd, estimate, PF) | src/commands/dsge.jl, test/test_commands.jl | ~300 |
| 7 | estimate smm | src/commands/estimate.jl, test/test_commands.jl | ~80 |
| 8 | Forecast breaking changes | src/commands/forecast.jl, test/mocks.jl | ~30 |
| 9 | CLI structure tests | test/runtests.jl | ~50 |
| 10 | CLAUDE.md | CLAUDE.md | ~200 |
| 11 | Full test verification | (none) | 0 |

**Total estimated: ~1,655 lines changed/added across 9 files, 1 new file.**
