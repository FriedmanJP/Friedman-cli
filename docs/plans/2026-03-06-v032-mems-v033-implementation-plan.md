# v0.3.2 MEMs v0.3.3 Integration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Wrap MEMs v0.3.3 new APIs (FAVAR, Structural DFM, Bayesian DSGE, structural break tests, panel unit root tests, 3rd-order perturbation) in 17 new CLI subcommands + 1 enhancement.

**Architecture:** Each feature area adds LeafCommands to existing `register_X_commands!()` functions, with handler functions following the `_action_model(; kwargs...)` pattern. Shared helpers in `shared.jl`. Mocks in `test/mocks.jl`, handler tests in `test/test_commands.jl`. All follow existing codebase patterns exactly.

**Tech Stack:** Julia 1.12, MacroEconometricModels.jl v0.3.3, existing CLI framework (types.jl/parser.jl/dispatch.jl)

---

## Task 1: Version Bump + Project.toml

**Files:**
- Modify: `Project.toml` — version and MEMs compat
- Modify: `src/Friedman.jl:53` — FRIEDMAN_VERSION

**Step 1: Bump Project.toml version to 0.3.2 and MEMs compat to 0.3.3**

In `Project.toml`, change:
```
version = "0.3.2"
```
And under `[compat]`:
```
MacroEconometricModels = "0.3.3"
```

**Step 2: Bump FRIEDMAN_VERSION in src/Friedman.jl**

At `src/Friedman.jl:53`, change:
```julia
const FRIEDMAN_VERSION = v"0.3.2"
```

**Step 3: Commit**

```bash
git add Project.toml src/Friedman.jl
git commit -m "$(cat <<'EOF'
chore: bump to v0.3.2, MEMs compat 0.3.3
EOF
)"
```

---

## Task 2: Shared Helpers

**Files:**
- Modify: `src/commands/shared.jl` — append 3 new helpers
- Modify: `src/config.jl` — append `get_dsge_priors()`

**Step 1: Add `_load_and_estimate_favar` to shared.jl**

Append before the `# ── Plot Helpers ──` section (before line 596):

```julia
# ── FAVAR Helpers ─────────────────────────────────────────

"""
    _load_and_estimate_favar(data, factors, lags, key_vars, method, draws) → (favar, Y, varnames)
"""
function _load_and_estimate_favar(data::String, factors, lags::Int,
                                   key_vars::String, method::String, draws::Int)
    Y, varnames = load_multivariate_data(data)
    T_obs, n = size(Y)

    # Parse key variables (comma-separated names or indices)
    key_indices = Int[]
    if !isempty(key_vars)
        for kv in split(key_vars, ",")
            kv = strip(kv)
            idx = tryparse(Int, kv)
            if idx !== nothing
                push!(key_indices, idx)
            else
                found = findfirst(==(kv), varnames)
                found === nothing && error("key variable '$kv' not found in data columns: $varnames")
                push!(key_indices, found)
            end
        end
    end
    isempty(key_indices) && error("--key-vars is required for FAVAR (comma-separated column names or indices)")

    # Auto-select factors if not specified
    r = if factors === nothing
        auto_r = ic_criteria(Y, min(10, n - 1))
        printstyled("  Auto-selected factors: $(auto_r.r_IC1) (IC1)\n"; color=:cyan)
        auto_r.r_IC1
    else
        factors
    end

    println("Estimating FAVAR: $r factors, $lags lags, method=$method, $(length(key_indices)) key variables")

    favar = estimate_favar(Y, key_indices, r, lags;
                           method=Symbol(method),
                           n_draws=draws)
    return favar, Y, varnames
end

# ── Panel/Matrix Loading Helper ──────────────────────────

"""
    _load_panel_or_matrix(data; id_col, time_col) → (result, is_panel)

Load data as PanelData if id_col/time_col are provided, else as Matrix.
"""
function _load_panel_or_matrix(data::String; id_col::String="", time_col::String="")
    if !isempty(id_col) && !isempty(time_col)
        pd = load_panel_data(data, id_col, time_col)
        printstyled("  Panel: $(pd.n_groups) units, $(div(pd.T_obs, pd.n_groups)) periods\n"; color=:cyan)
        return pd, true
    else
        Y, varnames = load_multivariate_data(data)
        println("  Matrix: $(size(Y, 1)) obs × $(size(Y, 2)) units")
        return Y, false
    end
end
```

**Step 2: Add `get_dsge_priors` to config.jl**

Append after `get_smm()` (after line 208):

```julia
"""
    get_dsge_priors(config) → Dict{String,Any}

Parse Bayesian DSGE prior specification from [priors] TOML section.
Each parameter maps to {dist, a, b} (distribution name + 2 shape params).
"""
function get_dsge_priors(config::Dict)
    priors_raw = get(config, "priors", Dict())
    isempty(priors_raw) && error("TOML must have [priors] section with parameter distributions")
    result = Dict{String,Any}()
    for (param, spec) in priors_raw
        spec isa Dict || error("prior for '$param' must be a table with dist, a, b keys")
        haskey(spec, "dist") || error("prior for '$param' missing 'dist' key")
        result[param] = Dict{String,Any}(
            "dist" => spec["dist"],
            "a"    => get(spec, "a", 0.0),
            "b"    => get(spec, "b", 1.0),
        )
    end
    return result
end
```

**Step 3: Run tests to verify nothing is broken**

```bash
julia --project test/runtests.jl
```

Expected: all existing tests pass (no new tests yet).

**Step 4: Commit**

```bash
git add src/commands/shared.jl src/config.jl
git commit -m "$(cat <<'EOF'
feat: add shared helpers for FAVAR, panel/matrix loading, and DSGE priors config
EOF
)"
```

---

## Task 3: Mock Types & Functions

**Files:**
- Modify: `test/mocks.jl` — append before `end # module` (line 1957)

**Step 1: Add FAVAR mock types and functions**

Insert before `end # module` at line 1957:

```julia
# ─── FAVAR Types & Functions ─────────────────────────────────

struct FAVARModel{T<:Real}
    Y::Matrix{T}; p::Int; B::Matrix{T}; U::Matrix{T}; Sigma::Matrix{T}
    factors::Matrix{T}; loadings::Matrix{T}; n_factors::Int; n_key::Int
    aic::T; bic::T; loglik::T
    varnames::Vector{String}; panel_varnames::Vector{String}
end

struct BayesianFAVAR{T<:Real}
    Y::Matrix{T}; p::Int; n_factors::Int; n_key::Int
    factors::Matrix{T}; loadings::Matrix{T}
    varnames::Vector{String}; panel_varnames::Vector{String}
    n_draws::Int
end

function estimate_favar(X::Matrix{T}, key_indices::Vector{Int}, r::Int, p::Int;
                        method=:two_step, n_draws=5000, panel_varnames=nothing) where T
    n_obs, n_vars = size(X)
    n_key = length(key_indices)
    n_aug = r + n_key
    Y = X[p+1:end, 1:min(n_aug, n_vars)]
    B = ones(T, n_aug * p + 1, n_aug) * T(0.1)
    U = randn(T, n_obs - p, n_aug)
    Sigma = Matrix{T}(I(n_aug)) * T(0.5)
    factors = randn(T, n_obs, r)
    loadings = randn(T, n_vars, r)
    vnames = ["aug$i" for i in 1:n_aug]
    pvnames = panel_varnames === nothing ? ["var$i" for i in 1:n_vars] : panel_varnames
    if method == :bayesian
        return BayesianFAVAR{T}(Y, p, r, n_key, factors, loadings, vnames, pvnames, n_draws)
    end
    FAVARModel{T}(Y, p, B, U, Sigma, factors, loadings, r, n_key,
                   T(-100.0), T(-95.0), T(-90.0), vnames, pvnames)
end

function to_var(favar::FAVARModel{T}) where T
    n = size(favar.Y, 2)
    VARModel{T}(favar.Y, favar.p, favar.B, favar.U, favar.Sigma,
                favar.aic, favar.bic, T(-92.0))
end

function favar_panel_irf(favar::FAVARModel{T}, irf_result::ImpulseResponse{T}) where T
    N = size(favar.loadings, 1)
    H = irf_result.horizon
    n_shocks = length(irf_result.shocks)
    vals = ones(T, H + 1, N, n_shocks) * T(0.05)
    ImpulseResponse(vals, nothing, nothing, H,
        favar.panel_varnames, irf_result.shocks, :favar_panel)
end

function favar_panel_forecast(favar::FAVARModel{T}, fc::VARForecast{T}) where T
    N = size(favar.loadings, 1)
    h = fc.horizon
    panel_fc = ones(T, h, N) * T(0.1)
    VARForecast{T}(panel_fc, panel_fc .- T(0.5), panel_fc .+ T(0.5),
                    h, :none, T(0.95), favar.panel_varnames)
end

# FAVAR dispatches for irf/fevd/hd — delegate to VAR internals
function irf(favar::FAVARModel{T}, horizon::Int; kwargs...) where T
    var_model = to_var(favar)
    irf(var_model, horizon; kwargs...)
end
function fevd(favar::FAVARModel{T}, horizon::Int; kwargs...) where T
    var_model = to_var(favar)
    fevd(var_model, horizon; kwargs...)
end
function historical_decomposition(favar::FAVARModel{T}, horizon::Int; kwargs...) where T
    var_model = to_var(favar)
    historical_decomposition(var_model, horizon; kwargs...)
end
function forecast(favar::FAVARModel{T}, h::Int; kwargs...) where T
    var_model = to_var(favar)
    forecast(var_model, h; kwargs...)
end

export FAVARModel, BayesianFAVAR, estimate_favar, favar_panel_irf, favar_panel_forecast

# ─── Structural DFM Types & Functions ────────────────────────

struct StructuralDFM{T<:Real}
    gdfm::GeneralizedDynamicFactorModel{T}
    factor_var::VARModel{T}
    B0::Matrix{T}; Q::Matrix{T}
    identification::Symbol
    structural_irf::Array{T,3}
    loadings_td::Matrix{T}
    p_var::Int; shock_names::Vector{String}
end

function estimate_structural_dfm(X::Matrix{T}, q::Int;
        identification=:cholesky, p=1, H=40, sign_check=nothing,
        max_draws=1000, standardize=true, bandwidth=0, kernel=:bartlett) where T
    n_obs, n_vars = size(X)
    gdfm = estimate_gdfm(X, q; standardize=standardize, bandwidth=bandwidth, kernel=kernel)
    factor_Y = randn(T, n_obs - p, q)
    B_fvar = ones(T, q * p + 1, q) * T(0.1)
    U_fvar = randn(T, n_obs - p, q)
    Sigma_fvar = Matrix{T}(I(q)) * T(0.5)
    fvar = VARModel{T}(factor_Y, p, B_fvar, U_fvar, Sigma_fvar, T(-50.0), T(-48.0), T(-45.0))
    B0 = Matrix{T}(I(q))
    Q_mat = Matrix{T}(I(q))
    loadings_td = randn(T, n_vars, q)
    s_irf = ones(T, H + 1, n_vars, q) * T(0.05)
    snames = ["structural_shock_$i" for i in 1:q]
    StructuralDFM{T}(gdfm, fvar, B0, Q_mat, identification, s_irf, loadings_td, p, snames)
end

function irf(sdfm::StructuralDFM{T}, horizon::Int; kwargs...) where T
    n_vars = size(sdfm.loadings_td, 1)
    q = size(sdfm.B0, 1)
    h = min(horizon, size(sdfm.structural_irf, 1) - 1)
    vals = sdfm.structural_irf[1:h+1, :, :]
    vnames = ["var$i" for i in 1:n_vars]
    ImpulseResponse(vals, nothing, nothing, h, vnames, sdfm.shock_names, :structural_dfm)
end

function fevd(sdfm::StructuralDFM{T}, horizon::Int; kwargs...) where T
    q = size(sdfm.B0, 1)
    props = ones(T, q, q, horizon) / T(q)
    FEVD(props, props)
end

export StructuralDFM, estimate_structural_dfm

# ─── Bayesian DSGE Types & Functions ─────────────────────────

struct BayesianDSGE{T<:Real}
    theta_draws::Matrix{T}
    log_posterior::Vector{T}
    param_names::Vector{String}
    log_marginal_likelihood::T
    method::Symbol
    acceptance_rate::T
    ess_history::Vector{T}
end

function estimate_dsge_bayes(spec::DSGESpec{T}, data::Matrix, theta0::Vector;
        priors=Dict(), method=:smc, observables=Symbol[],
        n_smc=5000, n_particles=500, n_mh_steps=1,
        n_draws=10000, burnin=5000, ess_target=0.5,
        measurement_error=nothing, solver=:gensys,
        solver_kwargs=NamedTuple(), delayed_acceptance=false,
        n_screen=200, rng=nothing) where T
    np = length(theta0)
    draws = randn(T, n_draws, np) .* T(0.01) .+ theta0'
    log_post = fill(T(-100.0), n_draws)
    pnames = ["param_$i" for i in 1:np]
    ess_hist = fill(T(n_smc * 0.8), 20)
    BayesianDSGE{T}(draws, log_post, pnames, T(-500.0), method, T(0.25), ess_hist)
end

export BayesianDSGE, estimate_dsge_bayes

# ─── Structural Break Test Types & Functions ─────────────────

struct AndrewsResult{T<:AbstractFloat}
    statistic::T; pvalue::T; break_index::Int; break_fraction::T
    test_type::Symbol; critical_values::Dict{Int,T}
    stat_sequence::Vector{T}; trimming::T; nobs::Int; n_params::Int
end

struct BaiPerronResult{T<:AbstractFloat}
    n_breaks::Int; break_dates::Vector{Int}; break_cis::Vector{Tuple{Int,Int}}
    regime_coefs::Vector{Vector{T}}; regime_ses::Vector{Vector{T}}
    supf_stats::Vector{T}; supf_pvalues::Vector{T}
    sequential_stats::Vector{T}; sequential_pvalues::Vector{T}
    bic_values::Vector{T}; lwz_values::Vector{T}
    trimming::T; nobs::Int
end

function andrews_test(y::AbstractVector{T}, X::AbstractMatrix;
        test=:supwald, trimming=0.15) where T
    n = length(y)
    n_params = size(X, 2)
    bp = div(n, 2)
    seq = fill(T(5.0), n - 2 * round(Int, n * trimming))
    seq[div(length(seq), 2)] = T(12.0)
    cvs = Dict(1 => T(8.85), 5 => T(7.04), 10 => T(6.28))
    AndrewsResult{T}(T(12.0), T(0.02), bp, T(bp / n),
        test, cvs, seq, T(trimming), n, n_params)
end

function bai_perron_test(y::AbstractVector{T}, X::AbstractMatrix;
        max_breaks=5, trimming=0.15, criterion=:bic) where T
    n = length(y)
    k = size(X, 2)
    BaiPerronResult{T}(
        1, [div(n, 2)], [(div(n, 2) - 5, div(n, 2) + 5)],
        [ones(T, k) * T(2.0), ones(T, k) * T(5.0)],
        [ones(T, k) * T(0.3), ones(T, k) * T(0.4)],
        [T(15.0)], [T(0.01)], [T(12.0)], [T(0.03)],
        fill(T(-100.0), max_breaks + 1), fill(T(-98.0), max_breaks + 1),
        T(trimming), n)
end

export AndrewsResult, BaiPerronResult, andrews_test, bai_perron_test

# ─── Panel Unit Root Test Types & Functions ──────────────────

struct PANICResult{T<:AbstractFloat}
    factor_adf_stats::Vector{T}; factor_adf_pvalues::Vector{T}
    pooled_statistic::T; pooled_pvalue::T
    individual_stats::Vector{T}; individual_pvalues::Vector{T}
    n_factors::Int; method::Symbol; nobs::Int; n_units::Int
end

struct PesaranCIPSResult{T<:AbstractFloat}
    cips::T; pvalue::T; individual_cadf::Vector{T}
    critical_values::Dict{Int,T}; lags::Int; deterministic::Symbol
    nobs::Int; n_units::Int
end

struct MoonPerronResult{T<:AbstractFloat}
    t_a_statistic::T; t_b_statistic::T; pvalue_a::T; pvalue_b::T
    n_factors::Int; nobs::Int; n_units::Int
end

struct FactorBreakResult{T<:AbstractFloat}
    statistic::T; pvalue::T; break_date::Int; method::Symbol
    r::Int; nobs::Int; n_units::Int
end

function panic_test(X::AbstractMatrix{T}; r=:auto, method=:pooled) where T
    n_obs, n_units = size(X)
    n_r = r == :auto ? 2 : r
    PANICResult{T}(
        fill(T(-3.0), n_r), fill(T(0.01), n_r),
        T(-5.0), T(0.001),
        fill(T(-2.5), n_units), fill(T(0.05), n_units),
        n_r, method, n_obs, n_units)
end
function panic_test(pd::PanelData{T}; r=:auto, method=:pooled) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    panic_test(X; r=r, method=method)
end

function pesaran_cips_test(X::AbstractMatrix{T}; lags=:auto, deterministic=:constant) where T
    n_obs, n_units = size(X)
    p = lags == :auto ? max(1, round(Int, n_obs^(1/3))) : lags
    cvs = Dict(1 => T(-2.16), 5 => T(-2.04), 10 => T(-1.97))
    PesaranCIPSResult{T}(T(-2.5), T(0.01), fill(T(-2.3), n_units),
        cvs, p, deterministic, n_obs, n_units)
end
function pesaran_cips_test(pd::PanelData{T}; lags=:auto, deterministic=:constant) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    pesaran_cips_test(X; lags=lags, deterministic=deterministic)
end

function moon_perron_test(X::AbstractMatrix{T}; r=:auto) where T
    n_obs, n_units = size(X)
    n_r = r == :auto ? 2 : r
    MoonPerronResult{T}(T(-3.5), T(-4.0), T(0.001), T(0.0005), n_r, n_obs, n_units)
end
function moon_perron_test(pd::PanelData{T}; r=:auto) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    moon_perron_test(X; r=r)
end

function factor_break_test(X::AbstractMatrix{T}, r::Int; method=:breitung_eickmeier) where T
    n_obs, n_units = size(X)
    FactorBreakResult{T}(T(8.5), T(0.03), div(n_obs, 2), method, r, n_obs, n_units)
end
function factor_break_test(pd::PanelData{T}, r::Int; method=:breitung_eickmeier) where T
    X = hcat([pd.data[:, i] for i in 1:pd.n_vars]...)
    factor_break_test(X, r; method=method)
end

function panel_unit_root_summary(X; tests=[:panic, :cips, :moon_perron])
    println("Panel unit root summary ($(length(tests)) tests)")
end

export PANICResult, PesaranCIPSResult, MoonPerronResult, FactorBreakResult
export panic_test, pesaran_cips_test, moon_perron_test, factor_break_test
export panel_unit_root_summary
```

**Step 2: Run tests**

```bash
julia --project test/runtests.jl
```

Expected: all existing tests pass. New mock types are defined but not yet tested.

**Step 3: Commit**

```bash
git add test/mocks.jl
git commit -m "$(cat <<'EOF'
test: add mock types for FAVAR, StructuralDFM, BayesianDSGE, structural break, and panel unit root tests
EOF
)"
```

---

## Task 4: FAVAR Commands — estimate + irf + fevd

**Files:**
- Modify: `src/commands/estimate.jl` — add favar + sdfm leaves + handlers
- Modify: `src/commands/irf.jl` — add favar + sdfm leaves + handlers
- Modify: `src/commands/fevd.jl` — add favar + sdfm leaves + handlers

**Step 1: Add `estimate favar` and `estimate sdfm` leaves in register_estimate_commands!()**

In `src/commands/estimate.jl`, add two new LeafCommand definitions before the `subcmds = Dict(...)` line, and add `"favar" => est_favar, "sdfm" => est_sdfm` to the subcmds Dict.

New leaf definitions:
```julia
    est_favar = LeafCommand("favar", _estimate_favar;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("factors"; short="r", type=Int, default=nothing, description="Number of factors (default: auto via IC)"),
            Option("lags"; short="p", type=Int, default=2, description="VAR lag order"),
            Option("key-vars"; type=String, default="", description="Key variable names or indices (comma-separated)"),
            Option("method"; type=String, default="two_step", description="two_step|bayesian"),
            Option("draws"; short="n", type=Int, default=5000, description="MCMC draws (bayesian only)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Estimate Factor-Augmented VAR (Bernanke, Boivin & Eliasz 2005)")

    est_sdfm = LeafCommand("sdfm", _estimate_sdfm;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("factors"; short="q", type=Int, default=nothing, description="Number of dynamic factors (default: auto)"),
            Option("id"; type=String, default="cholesky", description="cholesky|sign"),
            Option("var-lags"; type=Int, default=1, description="Factor VAR lag order"),
            Option("horizon"; short="h", type=Int, default=40, description="Structural IRF horizon"),
            Option("config"; type=String, default="", description="TOML config for sign restrictions"),
            Option("bandwidth"; type=Int, default=0, description="Spectral bandwidth (0=auto)"),
            Option("kernel"; type=String, default="bartlett", description="bartlett|parzen|quadratic_spectral"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Estimate Structural Dynamic Factor Model (Forni et al. 2009)")
```

Add to subcmds: `"favar" => est_favar, "sdfm" => est_sdfm,`

**Step 2: Add estimate handlers at end of estimate.jl**

```julia
# ── FAVAR ──────────────────────────────────────────────

function _estimate_favar(; data::String, factors=nothing, lags::Int=2,
                          key_vars::String="", method::String="two_step",
                          draws::Int=5000, output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, method, draws)

    if favar isa MacroEconometricModels.BayesianFAVAR
        println("Bayesian FAVAR: $(favar.n_factors) factors, $(favar.n_key) key vars, $(favar.n_draws) draws")
        pairs = Pair{String,Any}[
            "Factors" => favar.n_factors,
            "Key variables" => favar.n_key,
            "Lags" => favar.p,
            "MCMC draws" => favar.n_draws,
        ]
        output_kv(pairs; format=format, output=output, title="Bayesian FAVAR")
        return
    end

    var_model = to_var(favar)
    coef_df = _build_var_coef_table(coef(var_model), favar.varnames, favar.p)
    output_result(coef_df; format=Symbol(format), output=output, title="FAVAR($lags) Coefficients")

    println()
    printstyled("  Factors: $(favar.n_factors), Key variables: $(favar.n_key)\n"; color=:cyan)
    printstyled("  AIC: $(round(favar.aic; digits=2)), BIC: $(round(favar.bic; digits=2))\n"; color=:cyan)

    _maybe_plot(favar; plot=plot, plot_save=plot_save)
end

# ── Structural DFM ────────────────────────────────────

function _estimate_sdfm(; data::String, factors=nothing, id::String="cholesky",
                         var_lags::Int=1, horizon::Int=40,
                         config::String="", bandwidth::Int=0,
                         kernel::String="bartlett",
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    q = if factors === nothing
        auto_q = ic_criteria_gdfm(Y, min(10, n - 1))
        printstyled("  Auto-selected dynamic factors: $(auto_q.q_opt)\n"; color=:cyan)
        auto_q.q_opt
    else
        factors
    end

    sign_check = nothing
    if id == "sign" && !isempty(config)
        cfg = load_config(config)
        id_cfg = get_identification(cfg)
        sign_check = _build_check_func(cfg)
    end

    println("Estimating Structural DFM: $q factors, id=$id, VAR lags=$var_lags, horizon=$horizon")

    sdfm = estimate_structural_dfm(Y, q;
        identification=Symbol(id), p=var_lags, H=horizon,
        sign_check=sign_check, bandwidth=bandwidth, kernel=Symbol(kernel))

    println("  Identification: $(sdfm.identification)")
    println("  Factor VAR lags: $(sdfm.p_var)")
    println("  Shocks: $(join(sdfm.shock_names, ", "))")

    _maybe_plot(sdfm; plot=plot, plot_save=plot_save)
end
```

**Step 3: Add `irf favar` and `irf sdfm` leaves in register_irf_commands!()**

In `src/commands/irf.jl`, add two new LeafCommands before the subcmds Dict and register them:

```julia
    irf_favar = LeafCommand("favar", _irf_favar;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("factors"; short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
            Option("lags"; short="p", type=Int, default=2, description="VAR lag order"),
            Option("key-vars"; type=String, default="", description="Key variable names or indices (comma-separated)"),
            Option("horizons"; short="h", type=Int, default=20, description="IRF horizon"),
            Option("id"; type=String, default="cholesky", description="Identification method"),
            Option("config"; type=String, default="", description="TOML config for restrictions"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[
            Flag("panel-irf"; description="Output panel-wide IRFs (N variables) instead of factor-level"),
            Flag("plot"; description="Open interactive plot in browser"),
        ],
        description="FAVAR impulse response functions")

    irf_sdfm = LeafCommand("sdfm", _irf_sdfm;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("factors"; short="q", type=Int, default=nothing, description="Number of dynamic factors"),
            Option("id"; type=String, default="cholesky", description="cholesky|sign"),
            Option("var-lags"; type=Int, default=1, description="Factor VAR lag order"),
            Option("horizons"; short="h", type=Int, default=40, description="IRF horizon"),
            Option("config"; type=String, default="", description="TOML config for sign restrictions"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Structural DFM impulse response functions (panel-wide)")
```

Add to subcmds: `"favar" => irf_favar, "sdfm" => irf_sdfm,`

**Step 4: Add irf handlers at end of irf.jl**

```julia
# ── FAVAR IRF ──────────────────────────────────────────

function _irf_favar(; data::String, factors=nothing, lags::Int=2,
                     key_vars::String="", horizons::Int=20,
                     id::String="cholesky", config::String="",
                     panel_irf::Bool=false,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, "two_step", 5000)
    n = size(favar.Y, 2)

    id_kwargs = _build_identification_kwargs(id, config)

    println("FAVAR IRF: horizon=$horizons, id=$id" * (panel_irf ? ", panel-wide" : ""))
    println()

    irf_result = irf(favar, horizons; id_kwargs...)

    if panel_irf
        irf_result = favar_panel_irf(favar, irf_result)
    end

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    n_vars = size(irf_result.values, 2)
    n_shocks = size(irf_result.values, 3)
    for s in 1:n_shocks
        shock_name = s <= length(irf_result.shocks) ? irf_result.shocks[s] : "shock_$s"
        irf_df = DataFrame()
        irf_df.horizon = 0:horizons
        for v in 1:n_vars
            vname = v <= length(irf_result.variables) ? irf_result.variables[v] : "var_$v"
            irf_df[!, vname] = round.(irf_result.values[:, v, s]; digits=6)
        end
        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock_name),
                      title="FAVAR IRF — shock: $shock_name")
    end
end

# ── Structural DFM IRF ────────────────────────────────

function _irf_sdfm(; data::String, factors=nothing, id::String="cholesky",
                    var_lags::Int=1, horizons::Int=40,
                    config::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    q = factors === nothing ? ic_criteria_gdfm(Y, min(10, size(Y, 2) - 1)).q_opt : factors

    sdfm = estimate_structural_dfm(Y, q; identification=Symbol(id), p=var_lags, H=horizons)

    println("Structural DFM IRF: $q factors, id=$id, horizon=$horizons")
    println()

    irf_result = irf(sdfm, horizons)

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    n_vars = size(irf_result.values, 2)
    n_shocks = size(irf_result.values, 3)
    for s in 1:n_shocks
        shock_name = s <= length(irf_result.shocks) ? irf_result.shocks[s] : "shock_$s"
        irf_df = DataFrame()
        irf_df.horizon = 0:size(irf_result.values, 1)-1
        for v in 1:n_vars
            vname = v <= length(irf_result.variables) ? irf_result.variables[v] : "var_$v"
            irf_df[!, vname] = round.(irf_result.values[:, v, s]; digits=6)
        end
        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock_name),
                      title="SDFM IRF — shock: $shock_name")
    end
end
```

**Step 5: Add `fevd favar` and `fevd sdfm` analogously in fevd.jl**

In `src/commands/fevd.jl`, add two new LeafCommands:

```julia
    fevd_favar = LeafCommand("favar", _fevd_favar;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("factors"; short="r", type=Int, default=nothing, description="Number of factors"),
            Option("lags"; short="p", type=Int, default=2, description="VAR lag order"),
            Option("key-vars"; type=String, default="", description="Key variable names or indices"),
            Option("horizons"; short="h", type=Int, default=20, description="FEVD horizon"),
            Option("id"; type=String, default="cholesky", description="Identification method"),
            Option("config"; type=String, default="", description="TOML config for restrictions"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="FAVAR forecast error variance decomposition")

    fevd_sdfm = LeafCommand("sdfm", _fevd_sdfm;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("factors"; short="q", type=Int, default=nothing, description="Number of dynamic factors"),
            Option("id"; type=String, default="cholesky", description="cholesky|sign"),
            Option("var-lags"; type=Int, default=1, description="Factor VAR lag order"),
            Option("horizons"; short="h", type=Int, default=20, description="FEVD horizon"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Structural DFM forecast error variance decomposition")
```

Add to subcmds: `"favar" => fevd_favar, "sdfm" => fevd_sdfm,`

Handlers follow the same FEVD output pattern as existing `_fevd_var`:

```julia
# ── FAVAR FEVD ─────────────────────────────────────────

function _fevd_favar(; data::String, factors=nothing, lags::Int=2,
                      key_vars::String="", horizons::Int=20,
                      id::String="cholesky", config::String="",
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, "two_step", 5000)
    id_kwargs = _build_identification_kwargs(id, config)

    println("FAVAR FEVD: horizon=$horizons, id=$id")
    println()

    result = fevd(favar, horizons; id_kwargs...)
    _maybe_plot(result; plot=plot, plot_save=plot_save)

    n_vars = size(result.proportions, 1)
    n_shocks = size(result.proportions, 2)
    for v in 1:n_vars
        vname = _var_name(favar.varnames, v)
        fevd_df = DataFrame()
        fevd_df.horizon = 1:horizons
        for s in 1:n_shocks
            sname = _shock_name(favar.varnames, s)
            fevd_df[!, sname] = round.(result.proportions[v, s, :]; digits=4)
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="FAVAR FEVD — variable: $vname")
    end
end

# ── Structural DFM FEVD ──────────────────────────────

function _fevd_sdfm(; data::String, factors=nothing, id::String="cholesky",
                     var_lags::Int=1, horizons::Int=20,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    q = factors === nothing ? ic_criteria_gdfm(Y, min(10, size(Y, 2) - 1)).q_opt : factors

    sdfm = estimate_structural_dfm(Y, q; identification=Symbol(id), p=var_lags, H=horizons)

    println("SDFM FEVD: $q factors, horizon=$horizons")
    println()

    result = fevd(sdfm, horizons)
    _maybe_plot(result; plot=plot, plot_save=plot_save)

    n_vars = size(result.proportions, 1)
    n_shocks = size(result.proportions, 2)
    for v in 1:n_vars
        vname = "factor_$v"
        fevd_df = DataFrame()
        fevd_df.horizon = 1:horizons
        for s in 1:n_shocks
            sname = "shock_$s"
            fevd_df[!, sname] = round.(result.proportions[v, s, :]; digits=4)
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="SDFM FEVD — factor: $vname")
    end
end
```

**Step 6: Commit**

```bash
git add src/commands/estimate.jl src/commands/irf.jl src/commands/fevd.jl
git commit -m "$(cat <<'EOF'
feat: add FAVAR and Structural DFM estimate/irf/fevd commands
EOF
)"
```

---

## Task 5: FAVAR Commands — hd + forecast + predict + residuals

**Files:**
- Modify: `src/commands/hd.jl` — add favar leaf + handler
- Modify: `src/commands/forecast.jl` — add favar leaf + handler
- Modify: `src/commands/predict.jl` — add favar leaf + handler
- Modify: `src/commands/residuals.jl` — add favar leaf + handler

**Step 1: Add leaves and handlers**

For each file, follow the existing pattern: add a LeafCommand with options matching the favar estimate pattern (data, factors, lags, key-vars, plus action-specific options like horizons, id, panel-irf), register in subcmds Dict, add handler function.

The handlers follow the same structure:
1. Call `_load_and_estimate_favar()` to get the model
2. Call the appropriate MEMs function (e.g., `historical_decomposition(favar, h)`, `forecast(favar, h)`, `predict(to_var(favar))`, `residuals(to_var(favar))`)
3. Format and output results

**hd.jl** handler: `_hd_favar` — same as `_hd_var` but using `_load_and_estimate_favar()`.
**forecast.jl** handler: `_forecast_favar` — includes `--panel-forecast` flag for `favar_panel_forecast()`.
**predict.jl** handler: `_predict_favar` — via `to_var(favar)` then `predict()`.
**residuals.jl** handler: `_residuals_favar` — via `to_var(favar)` then `residuals()`.

Each leaf adds `"favar" => X_favar` to its subcmds Dict.

**Step 2: Commit**

```bash
git add src/commands/hd.jl src/commands/forecast.jl src/commands/predict.jl src/commands/residuals.jl
git commit -m "$(cat <<'EOF'
feat: add FAVAR hd/forecast/predict/residuals commands
EOF
)"
```

---

## Task 6: Structural Break Tests

**Files:**
- Modify: `src/commands/test.jl` — add andrews + bai-perron leaves + handlers

**Step 1: Add leaves in register_test_commands!()**

Add before the `subcmds = Dict(...)` line:

```julia
    test_andrews = LeafCommand("andrews", _test_andrews;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("response"; type=Int, default=1, description="Response variable column index (1-based)"),
            Option("test"; type=String, default="supwald", description="supwald|suplr|suplm|expwald|explr|explm|meanwald|meanlr|meanlm"),
            Option("trimming"; type=Float64, default=0.15, description="Trimming proportion"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Andrews (1993) structural break test")

    test_bai_perron = LeafCommand("bai-perron", _test_bai_perron;
        args=[Argument("data"; description="Path to CSV data file")],
        options=[
            Option("response"; type=Int, default=1, description="Response variable column index (1-based)"),
            Option("max-breaks"; type=Int, default=5, description="Maximum number of breaks"),
            Option("trimming"; type=Float64, default=0.15, description="Trimming proportion"),
            Option("criterion"; type=String, default="bic", description="bic|lwz"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Bai-Perron (1998) multiple structural break test")
```

Add to subcmds: `"andrews" => test_andrews, "bai-perron" => test_bai_perron,`

**Step 2: Add handlers at end of test.jl**

```julia
# ── Andrews Structural Break Test ─────────────────────

function _test_andrews(; data::String, response::Int=1,
                        test::String="supwald", trimming::Float64=0.15,
                        format::String="table", output::String="",
                        plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 1)

    y = Y[:, response]
    X = hcat(ones(n), Y[:, setdiff(1:size(Y, 2), response)])

    println("Andrews Structural Break Test: $(varnames[response]), test=$test, trimming=$trimming")
    println()

    result = andrews_test(y, X; test=Symbol(test), trimming=trimming)

    _maybe_plot(result; plot=plot, plot_save=plot_save)

    pairs = Pair{String,Any}[
        "Test type" => result.test_type,
        "Statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Break date (index)" => result.break_index,
        "Break fraction" => round(result.break_fraction; digits=4),
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Andrews Break Test")

    interpret_test_result(result.pvalue,
        "Reject H0: structural break detected at index $(result.break_index)",
        "Cannot reject H0: no structural break detected")
end

# ── Bai-Perron Multiple Break Test ────────────────────

function _test_bai_perron(; data::String, response::Int=1,
                           max_breaks::Int=5, trimming::Float64=0.15,
                           criterion::String="bic",
                           format::String="table", output::String="",
                           plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 1)

    y = Y[:, response]
    X = hcat(ones(n), Y[:, setdiff(1:size(Y, 2), response)])

    println("Bai-Perron Multiple Break Test: $(varnames[response]), max_breaks=$max_breaks, criterion=$criterion")
    println()

    result = bai_perron_test(y, X; max_breaks=max_breaks, trimming=trimming,
                             criterion=Symbol(criterion))

    _maybe_plot(result; plot=plot, plot_save=plot_save)

    pairs = Pair{String,Any}[
        "Number of breaks" => result.n_breaks,
        "Break dates" => join(result.break_dates, ", "),
        "Trimming" => result.trimming,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Bai-Perron Test")

    if !isempty(result.regime_coefs)
        for (i, coefs) in enumerate(result.regime_coefs)
            println("  Regime $i: $(join(round.(coefs; digits=4), ", "))")
        end
    end
end
```

**Step 3: Commit**

```bash
git add src/commands/test.jl
git commit -m "$(cat <<'EOF'
feat: add Andrews and Bai-Perron structural break test commands
EOF
)"
```

---

## Task 7: Panel Unit Root Tests

**Files:**
- Modify: `src/commands/test.jl` — add panic, cips, moon-perron, factor-break leaves + handlers

**Step 1: Add 4 new leaves in register_test_commands!()**

```julia
    test_panic = LeafCommand("panic", _test_panic;
        args=[Argument("data"; description="Path to CSV data file (rows=T, cols=N)")],
        options=[
            Option("factors"; type=String, default="auto", description="Number of factors (auto|N)"),
            Option("method"; type=String, default="pooled", description="pooled|individual"),
            Option("id-col"; type=String, default="", description="Panel unit ID column (optional)"),
            Option("time-col"; type=String, default="", description="Time column (optional)"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
        ],
        description="PANIC panel unit root test (Bai & Ng 2004)")

    test_cips = LeafCommand("cips", _test_cips;
        args=[Argument("data"; description="Path to CSV data file (rows=T, cols=N)")],
        options=[
            Option("lags"; type=String, default="auto", description="Lag order (auto|N)"),
            Option("deterministic"; type=String, default="constant", description="constant|trend"),
            Option("id-col"; type=String, default="", description="Panel unit ID column (optional)"),
            Option("time-col"; type=String, default="", description="Time column (optional)"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
        ],
        description="Pesaran CIPS panel unit root test (2007)")

    test_moon_perron = LeafCommand("moon-perron", _test_moon_perron;
        args=[Argument("data"; description="Path to CSV data file (rows=T, cols=N)")],
        options=[
            Option("factors"; type=String, default="auto", description="Number of factors (auto|N)"),
            Option("id-col"; type=String, default="", description="Panel unit ID column (optional)"),
            Option("time-col"; type=String, default="", description="Time column (optional)"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
        ],
        description="Moon-Perron panel unit root test (2004)")

    test_factor_break = LeafCommand("factor-break", _test_factor_break;
        args=[Argument("data"; description="Path to CSV data file (rows=T, cols=N)")],
        options=[
            Option("factors"; type=Int, default=2, description="Number of factors"),
            Option("method"; type=String, default="breitung_eickmeier", description="breitung_eickmeier|chen_dolado_gonzalo|han_inoue"),
            Option("id-col"; type=String, default="", description="Panel unit ID column (optional)"),
            Option("time-col"; type=String, default="", description="Time column (optional)"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
        ],
        description="Factor break test (Breitung-Eickmeier / Chen-Dolado-Gonzalo / Han-Inoue)")
```

Add to subcmds: `"panic" => test_panic, "cips" => test_cips, "moon-perron" => test_moon_perron, "factor-break" => test_factor_break,`

**Step 2: Add handlers at end of test.jl**

```julia
# ── Panel Unit Root Tests ─────────────────────────────

function _test_panic(; data::String, factors::String="auto",
                      method::String="pooled", id_col::String="", time_col::String="",
                      format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    r_arg = factors == "auto" ? :auto : parse(Int, factors)

    println("PANIC Panel Unit Root Test: factors=$(factors), method=$method")
    println()

    result = panic_test(dat; r=r_arg, method=Symbol(method))

    pairs = Pair{String,Any}[
        "Pooled statistic" => round(result.pooled_statistic; digits=4),
        "Pooled p-value" => round(result.pooled_pvalue; digits=4),
        "Number of factors" => result.n_factors,
        "Units" => result.n_units,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="PANIC Test (Bai-Ng)")

    interpret_test_result(result.pooled_pvalue,
        "Reject H0: panel has unit roots (after removing common factors)",
        "Cannot reject H0: panel is stationary (after removing common factors)")
end

function _test_cips(; data::String, lags::String="auto",
                     deterministic::String="constant",
                     id_col::String="", time_col::String="",
                     format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    lags_arg = lags == "auto" ? :auto : parse(Int, lags)

    println("Pesaran CIPS Panel Unit Root Test: lags=$lags, deterministic=$deterministic")
    println()

    result = pesaran_cips_test(dat; lags=lags_arg, deterministic=Symbol(deterministic))

    pairs = Pair{String,Any}[
        "CIPS statistic" => round(result.cips; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Lags" => result.lags,
        "Deterministic" => result.deterministic,
        "Units" => result.n_units,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Pesaran CIPS Test")

    interpret_test_result(result.pvalue,
        "Reject H0: panel has unit roots",
        "Cannot reject H0: panel is stationary")
end

function _test_moon_perron(; data::String, factors::String="auto",
                            id_col::String="", time_col::String="",
                            format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    r_arg = factors == "auto" ? :auto : parse(Int, factors)

    println("Moon-Perron Panel Unit Root Test: factors=$factors")
    println()

    result = moon_perron_test(dat; r=r_arg)

    pairs = Pair{String,Any}[
        "t_a* statistic" => round(result.t_a_statistic; digits=4),
        "t_b* statistic" => round(result.t_b_statistic; digits=4),
        "p-value (t_a*)" => round(result.pvalue_a; digits=4),
        "p-value (t_b*)" => round(result.pvalue_b; digits=4),
        "Factors" => result.n_factors,
        "Units" => result.n_units,
    ]
    output_kv(pairs; format=format, output=output, title="Moon-Perron Test")

    interpret_test_result(min(result.pvalue_a, result.pvalue_b),
        "Reject H0: panel has unit roots",
        "Cannot reject H0: panel is stationary")
end

function _test_factor_break(; data::String, factors::Int=2,
                              method::String="breitung_eickmeier",
                              id_col::String="", time_col::String="",
                              format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    println("Factor Break Test: factors=$factors, method=$method")
    println()

    result = factor_break_test(dat, factors; method=Symbol(method))

    pairs = Pair{String,Any}[
        "Statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Break date (index)" => result.break_date,
        "Method" => result.method,
        "Factors" => result.r,
        "Units" => result.n_units,
    ]
    output_kv(pairs; format=format, output=output, title="Factor Break Test")

    interpret_test_result(result.pvalue,
        "Reject H0: factor structure instability detected at index $(result.break_date)",
        "Cannot reject H0: factor structure appears stable")
end
```

**Step 3: Commit**

```bash
git add src/commands/test.jl
git commit -m "$(cat <<'EOF'
feat: add PANIC, CIPS, Moon-Perron, and factor break test commands
EOF
)"
```

---

## Task 8: Bayesian DSGE + 3rd-Order Perturbation

**Files:**
- Modify: `src/commands/dsge.jl` — add bayes leaf + handler, update solve order description

**Step 1: Update dsge solve description to allow order=3**

At `src/commands/dsge.jl:24`, change the description for `--order`:
```julia
Option("order"; type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
```

Do the same for dsge irf (line ~41), dsge fevd (line ~56), dsge simulate (line ~69).

**Step 2: Add `dsge bayes` leaf in register_dsge_commands!()**

Add before the `subcmds = Dict(...)` line:

```julia
    dsge_bayes = LeafCommand("bayes", _dsge_bayes;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("data"; short="d", type=String, default="", description="Path to CSV data file"),
            Option("params"; type=String, default="", description="Comma-separated parameter names"),
            Option("priors"; type=String, default="", description="Path to priors TOML file"),
            Option("sampler"; type=String, default="smc", description="smc|smc2|mh"),
            Option("n-smc"; type=Int, default=5000, description="SMC particles"),
            Option("n-particles"; type=Int, default=500, description="Particle filter particles (smc2)"),
            Option("n-draws"; type=Int, default=10000, description="Total posterior draws (mh)"),
            Option("burnin"; type=Int, default=5000, description="Burn-in draws (mh)"),
            Option("ess-target"; type=Float64, default=0.5, description="ESS target for resampling"),
            Option("observables"; type=String, default="", description="Observable variable names (comma-separated)"),
            Option("solver"; type=String, default="gensys", description="gensys|klein|perturbation"),
            Option("order"; type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        flags=[
            Flag("delayed-acceptance"; description="Use delayed acceptance for MH (Christen & Fox 2005)"),
        ],
        description="Bayesian DSGE estimation (SMC / SMC² / Metropolis-Hastings)")
```

Add to subcmds: `"bayes" => dsge_bayes,`

**Step 3: Add handler at end of dsge.jl**

```julia
# ── Bayesian DSGE ─────────────────────────────────────

function _dsge_bayes(; model::String, data::String="", params::String="",
                      priors::String="", sampler::String="smc",
                      n_smc::Int=5000, n_particles::Int=500,
                      n_draws::Int=10000, burnin::Int=5000,
                      ess_target::Float64=0.5, observables::String="",
                      solver::String="gensys", order::Int=1,
                      delayed_acceptance::Bool=false,
                      output::String="", format::String="table")
    isempty(data) && error("--data is required")
    isempty(params) && error("--params is required (comma-separated parameter names)")
    isempty(priors) && error("--priors is required (path to priors TOML)")

    spec = _load_dsge_model(model)

    df = load_data(data)
    Y = df_to_matrix(df)
    varnames = variable_names(df)

    param_names = [strip(p) for p in split(params, ",")]
    theta0 = ones(Float64, length(param_names)) * 0.5

    priors_config = load_config(priors)
    priors_dict = get_dsge_priors(priors_config)

    obs_syms = isempty(observables) ? Symbol[] : Symbol.(strip.(split(observables, ",")))

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    println("Bayesian DSGE Estimation:")
    println("  Sampler: $sampler")
    println("  Parameters: $(join(param_names, ", "))")
    println("  Data: $(size(Y, 1)) obs × $(size(Y, 2)) vars")
    println("  Solver: $solver" * (order > 1 ? ", order=$order" : ""))
    println()

    result = estimate_dsge_bayes(spec, Y, theta0;
        priors=priors_dict, method=Symbol(sampler),
        observables=obs_syms,
        n_smc=n_smc, n_particles=n_particles,
        n_draws=n_draws, burnin=burnin, ess_target=ess_target,
        solver=Symbol(solver), solver_kwargs=solver_kwargs,
        delayed_acceptance=delayed_acceptance)

    # Posterior summary table
    draws = result.theta_draws
    np = size(draws, 2)
    est_df = DataFrame(
        parameter = result.param_names,
        mean = [round(mean(draws[:, i]); digits=6) for i in 1:np],
        std = [round(sqrt(var(draws[:, i])); digits=6) for i in 1:np],
        q05 = [round(quantile(draws[:, i], 0.05); digits=6) for i in 1:np],
        median = [round(median(draws[:, i]); digits=6) for i in 1:np],
        q95 = [round(quantile(draws[:, i], 0.95); digits=6) for i in 1:np],
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="Bayesian DSGE Posterior ($sampler)")

    println()
    printstyled("  Log marginal likelihood: $(round(result.log_marginal_likelihood; digits=4))\n"; color=:cyan)
    printstyled("  Acceptance rate: $(round(result.acceptance_rate; digits=4))\n"; color=:cyan)
    printstyled("  Method: $(result.method)\n"; color=:cyan)
end
```

Note: `quantile` needs `using Statistics` which is already imported in Friedman.jl. However, `quantile` specifically is not imported — it comes from `Statistics`. We need to add it to the import. In `src/Friedman.jl:22`, change:
```julia
using Statistics: mean, median, var, quantile
```

**Step 4: Commit**

```bash
git add src/commands/dsge.jl src/Friedman.jl
git commit -m "$(cat <<'EOF'
feat: add Bayesian DSGE estimation command and 3rd-order perturbation support
EOF
)"
```

---

## Task 9: Handler Tests

**Files:**
- Modify: `test/test_commands.jl` — add tests for all 17 new leaves

**Step 1: Add tests for all new commands**

Append test sections for each new handler following existing test patterns. Each test:
1. Creates a temp CSV with `mktemp()`
2. Redirects stdout to temp file
3. Calls the handler with minimal required args
4. Verifies output contains expected strings

Key test groups:
- `@testset "estimate favar"` — test `_estimate_favar` with key_vars, factors, lags
- `@testset "estimate sdfm"` — test `_estimate_sdfm` with factors, id
- `@testset "irf favar"` — test `_irf_favar` with and without panel_irf
- `@testset "irf sdfm"` — test `_irf_sdfm`
- `@testset "fevd favar"` — test `_fevd_favar`
- `@testset "fevd sdfm"` — test `_fevd_sdfm`
- `@testset "hd favar"` — test `_hd_favar`
- `@testset "forecast favar"` — test `_forecast_favar`
- `@testset "predict favar"` — test `_predict_favar`
- `@testset "residuals favar"` — test `_residuals_favar`
- `@testset "test andrews"` — test `_test_andrews`
- `@testset "test bai-perron"` — test `_test_bai_perron`
- `@testset "test panic"` — test `_test_panic` with matrix and panel input
- `@testset "test cips"` — test `_test_cips`
- `@testset "test moon-perron"` — test `_test_moon_perron`
- `@testset "test factor-break"` — test `_test_factor_break`
- `@testset "dsge bayes"` — test `_dsge_bayes`

Follow existing test pattern from test_commands.jl. Example for one test:

```julia
@testset "estimate favar" begin
    csv_path, csv_io = mktemp()
    write(csv_io, "a,b,c,d,e\n" * join(["$(rand()),$(rand()),$(rand()),$(rand()),$(rand())" for _ in 1:50], "\n"))
    close(csv_io)
    tmp_path, tmp_io = mktemp()
    try
        redirect_stdout(tmp_io) do
            Friedman._estimate_favar(; data=csv_path, factors=2, lags=1,
                key_vars="1,2", method="two_step", draws=5000,
                output="", format="table", plot=false, plot_save="")
        end
        close(tmp_io)
        out = read(tmp_path, String)
        @test contains(out, "FAVAR")
    finally
        try close(tmp_io) catch end
        try rm(csv_path) catch end
        try rm(tmp_path) catch end
    end
end
```

**Step 2: Run all tests**

```bash
julia --project test/runtests.jl
```

Expected: all tests pass.

**Step 3: Commit**

```bash
git add test/test_commands.jl
git commit -m "$(cat <<'EOF'
test: add handler tests for all 17 new v0.3.2 commands
EOF
)"
```

---

## Task 10: Command Structure Tests + Version Tests

**Files:**
- Modify: `test/runtests.jl` — update version refs, add structure tests for new leaves

**Step 1: Update version string tests**

Search for `"0.3.1"` in runtests.jl and replace with `"0.3.2"`.

**Step 2: Add structure tests for new commands**

In the command structure test section, add tests verifying the new leaves exist:

```julia
@testset "FAVAR command structure" begin
    @test haskey(app.root.subcmds["estimate"].subcmds, "favar")
    @test haskey(app.root.subcmds["estimate"].subcmds, "sdfm")
    @test haskey(app.root.subcmds["irf"].subcmds, "favar")
    @test haskey(app.root.subcmds["irf"].subcmds, "sdfm")
    @test haskey(app.root.subcmds["fevd"].subcmds, "favar")
    @test haskey(app.root.subcmds["fevd"].subcmds, "sdfm")
    @test haskey(app.root.subcmds["hd"].subcmds, "favar")
    @test haskey(app.root.subcmds["forecast"].subcmds, "favar")
    @test haskey(app.root.subcmds["predict"].subcmds, "favar")
    @test haskey(app.root.subcmds["residuals"].subcmds, "favar")
end

@testset "Test command new leaves" begin
    @test haskey(app.root.subcmds["test"].subcmds, "andrews")
    @test haskey(app.root.subcmds["test"].subcmds, "bai-perron")
    @test haskey(app.root.subcmds["test"].subcmds, "panic")
    @test haskey(app.root.subcmds["test"].subcmds, "cips")
    @test haskey(app.root.subcmds["test"].subcmds, "moon-perron")
    @test haskey(app.root.subcmds["test"].subcmds, "factor-break")
end

@testset "DSGE bayes command structure" begin
    @test haskey(app.root.subcmds["dsge"].subcmds, "bayes")
    bayes = app.root.subcmds["dsge"].subcmds["bayes"]
    @test bayes isa LeafCommand
    @test any(o -> o.name == "sampler", bayes.options)
    @test any(o -> o.name == "priors", bayes.options)
end
```

**Step 3: Run all tests**

```bash
julia --project test/runtests.jl
```

**Step 4: Commit**

```bash
git add test/runtests.jl
git commit -m "$(cat <<'EOF'
test: add structure tests and version bump for v0.3.2 commands
EOF
)"
```

---

## Task 11: Documentation Update

**Files:**
- Modify: `CLAUDE.md` — update overview, command hierarchy, command details, API reference
- Modify: `README.md` — update commands table, version refs
- Modify: `docs/make.jl` — add new pages
- Create: `docs/src/commands/favar.md`, `docs/src/commands/structural-breaks.md`, `docs/src/commands/panel-unit-root.md`
- Modify: `docs/src/commands/overview.md`, `docs/src/api.md`, `docs/src/architecture.md`

**Step 1: Update CLAUDE.md**

Key changes:
- Project Overview: v0.3.2, MEMs v0.3.3, add FAVAR/Structural DFM/Bayesian DSGE/structural breaks/panel unit root to feature list, ~141 subcommands, ~10,200 lines across 19 source files
- Command Hierarchy: add favar/sdfm to estimate/irf/fevd/hd/forecast/predict/residuals; add andrews/bai-perron/panic/cips/moon-perron/factor-break to test; add bayes to dsge
- Command Details: add subsections for new commands
- API Reference: add new types and functions
- Testing: update test counts

**Step 2: Update README.md**

Update commands table and version references.

**Step 3: Add docs pages**

Create documentation pages for the new command groups.

**Step 4: Commit**

```bash
git add CLAUDE.md README.md docs/
git commit -m "$(cat <<'EOF'
docs: full v0.3.2 documentation update — FAVAR, SDFM, Bayesian DSGE, structural breaks, panel unit root
EOF
)"
```

---

## Summary

| Task | Description | Files | Est. Lines |
|------|-------------|-------|------------|
| 1 | Version bump | Project.toml, Friedman.jl | ~4 |
| 2 | Shared helpers | shared.jl, config.jl | ~80 |
| 3 | Mock types | mocks.jl | ~250 |
| 4 | FAVAR+SDFM estimate/irf/fevd | estimate.jl, irf.jl, fevd.jl | ~350 |
| 5 | FAVAR hd/forecast/predict/residuals | hd.jl, forecast.jl, predict.jl, residuals.jl | ~200 |
| 6 | Structural break tests | test.jl | ~100 |
| 7 | Panel unit root tests | test.jl | ~150 |
| 8 | Bayesian DSGE + 3rd-order | dsge.jl, Friedman.jl | ~120 |
| 9 | Handler tests | test_commands.jl | ~400 |
| 10 | Structure + version tests | runtests.jl | ~50 |
| 11 | Documentation | CLAUDE.md, README.md, docs/ | ~300 |
| **Total** | | | **~2,000** |
