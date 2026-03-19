# v0.3.1 DID & Event Study LP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a new top-level `did` command (7 leaves) wrapping MEMs v0.3.2 DID and event study LP features.

**Architecture:** Single new file `src/commands/did.jl` with `register_did_commands!()` returning a NodeCommand containing 3 estimation leaves + a nested `test` NodeCommand with 4 diagnostic leaves. Shared helper `_load_panel_for_did()` added to `shared.jl`. All handlers follow the `_did_action` naming convention and the standard data flow: CSV → `load_panel_data` → MEMs function → DataFrame → `output_result`.

**Tech Stack:** Julia 1.12, MacroEconometricModels.jl v0.3.2, existing CLI framework (LeafCommand/NodeCommand/Entry), PanelData type.

---

### Task 1: Add DID mock types to test/mocks.jl

**Files:**
- Modify: `test/mocks.jl` (append before `end # module`, currently line 1808)

**Step 1: Add the 6 DID mock types and 8 mock functions**

Append the following block just before the final `end # module` line in `test/mocks.jl`:

```julia
# ─── DID & Event Study LP Types & Functions ─────────────────

struct DIDResult{T<:Real}
    att::Vector{T}; se::Vector{T}; ci_lower::Vector{T}; ci_upper::Vector{T}
    event_times::Vector{Int}; reference_period::Int
    group_time_att::Union{Matrix{T}, Nothing}; cohorts::Union{Vector{Int}, Nothing}
    overall_att::T; overall_se::T
    n_obs::Int; n_groups::Int; n_treated::Int; n_control::Int
    method::Symbol; outcome_var::String; treatment_var::String
    control_group::Symbol; cluster::Symbol; conf_level::T
end

struct EventStudyLP{T<:Real}
    coefficients::Vector{T}; se::Vector{T}; ci_lower::Vector{T}; ci_upper::Vector{T}
    event_times::Vector{Int}; reference_period::Int
    B::Vector{Matrix{T}}; residuals_per_h::Vector{Matrix{T}}
    vcov::Vector{Matrix{T}}; T_eff::Vector{Int}
    outcome_var::String; treatment_var::String
    n_obs::Int; n_groups::Int; lags::Int; leads::Int; horizon::Int
    clean_controls::Bool; cluster::Symbol; conf_level::T
    data::PanelData{T}
end

struct BaconDecomposition{T<:Real}
    estimates::Vector{T}; weights::Vector{T}
    comparison_type::Vector{Symbol}; cohort_i::Vector{Int}; cohort_j::Vector{Int}
    overall_att::T
end

struct PretrendTestResult{T<:Real}
    statistic::T; pvalue::T; df::Int
    pre_coefficients::Vector{T}; pre_se::Vector{T}; test_type::Symbol
end

struct NegativeWeightResult{T<:Real}
    has_negative_weights::Bool; n_negative::Int; total_negative_weight::T
    weights::Vector{T}; cohort_time_pairs::Vector{Tuple{Int,Int}}
end

struct HonestDiDResult{T<:Real}
    Mbar::T
    robust_ci_lower::Vector{T}; robust_ci_upper::Vector{T}
    original_ci_lower::Vector{T}; original_ci_upper::Vector{T}
    breakdown_value::T; post_event_times::Vector{Int}; post_att::Vector{T}
    conf_level::T
end

# ─── DID Mock Functions ─────────────────────────────────────

function estimate_did(pd::PanelData{T}, outcome, treatment;
        method=:twfe, leads=0, horizon=5, covariates=String[],
        control_group=:never_treated, cluster=:unit,
        conf_level=0.95, n_boot=200) where T
    et = collect(-leads:horizon)
    n_et = length(et)
    att = fill(T(0.5), n_et)
    se = fill(T(0.1), n_et)
    ci_lo = att .- T(1.96) .* se
    ci_hi = att .+ T(1.96) .* se
    gt_att = method == :callaway_santanna ? ones(T, 3, n_et) * T(0.4) : nothing
    cohorts = method == :callaway_santanna ? [5, 10, 15] : nothing
    DIDResult{T}(att, se, ci_lo, ci_hi, et, -1, gt_att, cohorts,
        T(0.45), T(0.08), pd.T_obs, pd.n_groups,
        div(pd.n_groups, 2), pd.n_groups - div(pd.n_groups, 2),
        method, String(outcome), String(treatment),
        control_group, cluster, T(conf_level))
end

function estimate_event_study_lp(pd::PanelData{T}, outcome, treatment, H::Int;
        leads=3, lags=4, covariates=String[], cluster=:unit, conf_level=0.95) where T
    et = collect(-leads:H)
    n_et = length(et)
    coefs = fill(T(0.3), n_et)
    se = fill(T(0.1), n_et)
    n_h = leads + H + 1
    B_mats = [ones(T, pd.n_vars, pd.n_vars) * T(0.1) for _ in 1:n_h]
    resid = [randn(T, div(pd.T_obs, pd.n_groups), pd.n_vars) for _ in 1:n_h]
    vcov_mats = [Matrix{T}(I(pd.n_vars)) * T(0.01) for _ in 1:n_h]
    t_eff = fill(div(pd.T_obs, pd.n_groups) - lags, n_h)
    EventStudyLP{T}(coefs, se, coefs .- T(1.96) .* se, coefs .+ T(1.96) .* se,
        et, -1, B_mats, resid, vcov_mats, t_eff,
        String(outcome), String(treatment),
        pd.T_obs, pd.n_groups, lags, leads, H, false, cluster, T(conf_level), pd)
end

function estimate_lp_did(pd::PanelData{T}, outcome, treatment, H::Int;
        leads=3, lags=4, covariates=String[], cluster=:unit, conf_level=0.95) where T
    result = estimate_event_study_lp(pd, outcome, treatment, H;
        leads=leads, lags=lags, covariates=covariates, cluster=cluster, conf_level=conf_level)
    # Return with clean_controls=true
    EventStudyLP{T}(result.coefficients, result.se, result.ci_lower, result.ci_upper,
        result.event_times, result.reference_period,
        result.B, result.residuals_per_h, result.vcov, result.T_eff,
        result.outcome_var, result.treatment_var,
        result.n_obs, result.n_groups, result.lags, result.leads, result.horizon,
        true, result.cluster, result.conf_level, result.data)
end

function bacon_decomposition(pd::PanelData{T}, outcome, treatment) where T
    BaconDecomposition{T}(
        [T(0.6), T(0.4), T(0.3)],
        [T(0.5), T(0.3), T(0.2)],
        [:treated_vs_untreated, :earlier_vs_later, :later_vs_earlier],
        [5, 5, 10], [0, 10, 5],
        T(0.47))
end

function pretrend_test(result::DIDResult{T}) where T
    pre_idx = findall(t -> t < 0, result.event_times)
    PretrendTestResult{T}(T(1.2), T(0.35), length(pre_idx),
        result.att[pre_idx], result.se[pre_idx], :f_test)
end

function pretrend_test(result::EventStudyLP{T}) where T
    pre_idx = findall(t -> t < 0, result.event_times)
    PretrendTestResult{T}(T(0.8), T(0.55), length(pre_idx),
        result.coefficients[pre_idx], result.se[pre_idx], :f_test)
end

function negative_weight_check(pd::PanelData{T}, treatment) where T
    NegativeWeightResult{T}(true, 2, T(-0.15),
        [T(0.4), T(0.3), T(-0.1), T(0.5), T(-0.05), T(-0.05)],
        [(5, 3), (5, 4), (10, 3), (10, 4), (10, 5), (10, 6)])
end

function honest_did(result::DIDResult{T}; Mbar=1.0, conf_level=0.95) where T
    post_idx = findall(t -> t >= 0, result.event_times)
    post_et = result.event_times[post_idx]
    post_att = result.att[post_idx]
    HonestDiDResult{T}(T(Mbar),
        post_att .- T(0.3), post_att .+ T(0.3),
        result.ci_lower[post_idx], result.ci_upper[post_idx],
        T(2.5), post_et, post_att, T(conf_level))
end

function honest_did(result::EventStudyLP{T}; Mbar=1.0, conf_level=0.95) where T
    post_idx = findall(t -> t >= 0, result.event_times)
    post_et = result.event_times[post_idx]
    post_att = result.coefficients[post_idx]
    HonestDiDResult{T}(T(Mbar),
        post_att .- T(0.3), post_att .+ T(0.3),
        result.ci_lower[post_idx], result.ci_upper[post_idx],
        T(2.5), post_et, post_att, T(conf_level))
end

export DIDResult, EventStudyLP, BaconDecomposition
export PretrendTestResult, NegativeWeightResult, HonestDiDResult
export estimate_did, estimate_event_study_lp, estimate_lp_did
export bacon_decomposition, pretrend_test, negative_weight_check, honest_did
```

**Step 2: Run tests to verify mocks compile**

Run: `julia --project test/runtests.jl`
Expected: All 1,747 existing tests PASS (mocks append doesn't break anything).

**Step 3: Commit**

```bash
git add test/mocks.jl
git commit -m "test: add DID & event study LP mock types and functions"
```

---

### Task 2: Add `_load_panel_for_did` helper to shared.jl

**Files:**
- Modify: `src/commands/shared.jl` (append near end of file, after existing panel helpers)

**Step 1: Write the failing test**

In `test/test_commands.jl`, append before the final `end  # Command Handlers` (line 5680):

```julia
# ─── DID Shared Helpers ─────────────────────────────────────────

@testset "DID shared helpers" begin
    @testset "_load_panel_for_did — basic" begin
        mktempdir() do dir
            csv = _make_panel_csv(dir; G=5, T_per=20, n=3,
                colnames=["outcome", "treat", "covar1"])
            out = _capture() do
                pd = _load_panel_for_did(csv, "group", "time")
                @test pd isa MacroEconometricModels.PanelData
                @test pd.n_groups == 5
                @test pd.n_vars == 3
            end
            @test occursin("Panel", out) || occursin("panel", out)
        end
    end

    @testset "_load_panel_for_did — custom id/time cols" begin
        mktempdir() do dir
            csv = _make_panel_csv(dir; G=3, T_per=10, n=2,
                colnames=["y", "d"])
            out = _capture() do
                pd = _load_panel_for_did(csv, "group", "time")
                @test pd.n_groups == 3
            end
        end
    end
end
```

**Step 2: Run test to verify it fails**

Run: `julia --project test/runtests.jl`
Expected: FAIL with `UndefVarError: _load_panel_for_did not defined`

**Step 3: Write the implementation**

Append to `src/commands/shared.jl` (after the existing `_build_pvar_coef_table` or similar panel helpers):

```julia
"""
    _load_panel_for_did(data, id_col, time_col) -> PanelData

Load panel CSV and print summary for DID/event study commands.
"""
function _load_panel_for_did(data::String, id_col::String, time_col::String)
    pd = load_panel_data(data, id_col, time_col)
    printstyled("  Panel: $(pd.n_groups) groups, $(div(pd.T_obs, pd.n_groups)) periods, " *
                "$(pd.n_vars) variables"; color=:cyan)
    pd.balanced && printstyled(" (balanced)"; color=:cyan)
    println()
    return pd
end
```

**Step 4: Run tests to verify they pass**

Run: `julia --project test/runtests.jl`
Expected: PASS — all tests including the 2 new DID helper tests.

**Step 5: Commit**

```bash
git add src/commands/shared.jl test/test_commands.jl
git commit -m "feat: add _load_panel_for_did shared helper"
```

---

### Task 3: Create `src/commands/did.jl` — LeafCommand definitions and register function

**Files:**
- Create: `src/commands/did.jl`

**Step 1: Write the failing CLI structure test**

Append to `test/runtests.jl` before the final closing (after line 3183):

```julia
@testset "DID command structure" begin
    did_node = register_did_commands!()
    @test did_node isa NodeCommand
    @test did_node.name == "did"

    # Top-level: estimate, event-study, lp-did, test (NodeCommand)
    @test haskey(did_node.subcmds, "estimate")
    @test haskey(did_node.subcmds, "event-study")
    @test haskey(did_node.subcmds, "lp-did")
    @test haskey(did_node.subcmds, "test")
    @test length(did_node.subcmds) == 4

    # estimate, event-study, lp-did are LeafCommands
    @test did_node.subcmds["estimate"] isa LeafCommand
    @test did_node.subcmds["event-study"] isa LeafCommand
    @test did_node.subcmds["lp-did"] isa LeafCommand

    # test is a NodeCommand with 4 leaves
    test_node = did_node.subcmds["test"]
    @test test_node isa NodeCommand
    @test haskey(test_node.subcmds, "bacon")
    @test haskey(test_node.subcmds, "pretrend")
    @test haskey(test_node.subcmds, "negweight")
    @test haskey(test_node.subcmds, "honest")
    @test length(test_node.subcmds) == 4
    for (name, cmd) in test_node.subcmds
        @test cmd isa LeafCommand
    end

    # estimate has data arg + key options
    est_cmd = did_node.subcmds["estimate"]
    @test length(est_cmd.args) == 1
    @test est_cmd.args[1].name == "data"
    opt_names = [o.name for o in est_cmd.options]
    @test "outcome" in opt_names
    @test "treatment" in opt_names
    @test "method" in opt_names
    @test "id-col" in opt_names
    @test "time-col" in opt_names
    @test "control-group" in opt_names
    @test "cluster" in opt_names
    flag_names = [f.name for f in est_cmd.flags]
    @test "plot" in flag_names

    # event-study has leads, horizon, lags
    es_cmd = did_node.subcmds["event-study"]
    opt_names = [o.name for o in es_cmd.options]
    @test "outcome" in opt_names
    @test "treatment" in opt_names
    @test "leads" in opt_names
    @test "horizon" in opt_names
    @test "lags" in opt_names

    # lp-did has same structure as event-study
    lp_cmd = did_node.subcmds["lp-did"]
    opt_names = [o.name for o in lp_cmd.options]
    @test "outcome" in opt_names
    @test "treatment" in opt_names
    @test "leads" in opt_names

    # bacon has outcome, treatment
    bacon_cmd = test_node.subcmds["bacon"]
    opt_names = [o.name for o in bacon_cmd.options]
    @test "outcome" in opt_names
    @test "treatment" in opt_names

    # pretrend has method and did-method
    pt_cmd = test_node.subcmds["pretrend"]
    opt_names = [o.name for o in pt_cmd.options]
    @test "method" in opt_names
    @test "did-method" in opt_names

    # negweight has treatment but not outcome
    nw_cmd = test_node.subcmds["negweight"]
    opt_names = [o.name for o in nw_cmd.options]
    @test "treatment" in opt_names

    # honest has mbar
    h_cmd = test_node.subcmds["honest"]
    opt_names = [o.name for o in h_cmd.options]
    @test "mbar" in opt_names
    @test "method" in opt_names
end
```

**Step 2: Run test to verify it fails**

Run: `julia --project test/runtests.jl`
Expected: FAIL with `UndefVarError: register_did_commands! not defined`

**Step 3: Write the `src/commands/did.jl` file**

Create `src/commands/did.jl` with the full command tree and all 7 handlers:

```julia
# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# ─── DID & Event Study LP Commands ──────────────────────────────

# ─── Common option builders ─────────────────────────────────────

const _DID_PANEL_OPTIONS = [
    Option("id-col"; type=String, default="", description="Panel unit ID column (default: first column)"),
    Option("time-col"; type=String, default="", description="Time column (default: second column)"),
]

function _did_panel_cols(df, id_col::String, time_col::String)
    cols = names(df)
    id = isempty(id_col) ? cols[1] : id_col
    tc = isempty(time_col) ? cols[2] : time_col
    return id, tc
end

# ─── Handlers ────────────────────────────────────────────────────

function _did_estimate(; data::String, outcome::String, treatment::String,
        method::String="twfe", id_col::String="", time_col::String="",
        leads::Int=0, horizon::Int=5, covariates::String="",
        control_group::String="never_treated", cluster::String="unit",
        conf_level::Float64=0.95, n_boot::Int=200,
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && error("--outcome is required")
    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    covs = isempty(covariates) ? String[] : String.(split(covariates, ","))

    result = estimate_did(pd, outcome, treatment;
        method=Symbol(method), leads=leads, horizon=horizon,
        covariates=covs, control_group=Symbol(control_group),
        cluster=Symbol(cluster), conf_level=conf_level, n_boot=n_boot)

    # Event-time ATT table
    att_df = DataFrame(
        Event_Time = result.event_times,
        ATT = round.(result.att; digits=6),
        SE = round.(result.se; digits=6),
        CI_Lower = round.(result.ci_lower; digits=6),
        CI_Upper = round.(result.ci_upper; digits=6)
    )
    output_result(att_df; format=format, output=output,
        title="DID Estimation — $(uppercase(method))")

    # Overall ATT
    println()
    printstyled("  Overall ATT: "; bold=true)
    println("$(round(result.overall_att; digits=6))  (SE: $(round(result.overall_se; digits=6)))")
    printstyled("  Method: "; bold=true)
    println(method)
    printstyled("  N: "; bold=true)
    println("$(result.n_obs) obs, $(result.n_groups) groups ($(result.n_treated) treated, $(result.n_control) control)")

    # Group-time ATT for Callaway-Sant'Anna
    if !isnothing(result.group_time_att) && !isnothing(result.cohorts)
        println()
        gt_df = DataFrame(result.group_time_att, ["t=$(t)" for t in result.event_times])
        insertcols!(gt_df, 1, :Cohort => result.cohorts)
        output_result(gt_df; format=format, output="",
            title="Group-Time ATT (Callaway-Sant'Anna)")
    end

    _maybe_plot(result; plot=plot, plot_save=plot_save)
end

function _did_event_study(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        leads::Int=3, horizon::Int=5, lags::Int=4,
        covariates::String="", cluster::String="unit",
        conf_level::Float64=0.95,
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && error("--outcome is required")
    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    covs = isempty(covariates) ? String[] : String.(split(covariates, ","))

    result = estimate_event_study_lp(pd, outcome, treatment, horizon;
        leads=leads, lags=lags, covariates=covs,
        cluster=Symbol(cluster), conf_level=conf_level)

    coef_df = DataFrame(
        Event_Time = result.event_times,
        Coefficient = round.(result.coefficients; digits=6),
        SE = round.(result.se; digits=6),
        CI_Lower = round.(result.ci_lower; digits=6),
        CI_Upper = round.(result.ci_upper; digits=6)
    )
    output_result(coef_df; format=format, output=output,
        title="Event Study LP — $(result.outcome_var)")

    println()
    printstyled("  N: "; bold=true)
    println("$(result.n_obs) obs, $(result.n_groups) groups")
    printstyled("  Lags: "; bold=true)
    print("$(result.lags)  ")
    printstyled("Leads: "; bold=true)
    print("$(result.leads)  ")
    printstyled("Horizon: "; bold=true)
    println("$(result.horizon)")

    _maybe_plot(result; plot=plot, plot_save=plot_save)
end

function _did_lp_did(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        leads::Int=3, horizon::Int=5, lags::Int=4,
        covariates::String="", cluster::String="unit",
        conf_level::Float64=0.95,
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && error("--outcome is required")
    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    covs = isempty(covariates) ? String[] : String.(split(covariates, ","))

    result = estimate_lp_did(pd, outcome, treatment, horizon;
        leads=leads, lags=lags, covariates=covs,
        cluster=Symbol(cluster), conf_level=conf_level)

    coef_df = DataFrame(
        Event_Time = result.event_times,
        Coefficient = round.(result.coefficients; digits=6),
        SE = round.(result.se; digits=6),
        CI_Lower = round.(result.ci_lower; digits=6),
        CI_Upper = round.(result.ci_upper; digits=6)
    )
    output_result(coef_df; format=format, output=output,
        title="LP-DiD (Dube et al. 2023) — $(result.outcome_var)")

    println()
    printstyled("  Clean controls: "; bold=true)
    println(result.clean_controls ? "yes (not-yet-treated)" : "no")
    printstyled("  N: "; bold=true)
    println("$(result.n_obs) obs, $(result.n_groups) groups")

    _maybe_plot(result; plot=plot, plot_save=plot_save)
end

function _did_test_bacon(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && error("--outcome is required")
    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    result = bacon_decomposition(pd, outcome, treatment)

    dec_df = DataFrame(
        Comparison = String.(result.comparison_type),
        Cohort_i = result.cohort_i,
        Cohort_j = result.cohort_j,
        Estimate = round.(result.estimates; digits=6),
        Weight = round.(result.weights; digits=6)
    )
    output_result(dec_df; format=format, output=output,
        title="Bacon Decomposition (Goodman-Bacon 2021)")

    println()
    printstyled("  Overall ATT (TWFE): "; bold=true)
    println(round(result.overall_att; digits=6))

    _maybe_plot(result; plot=plot, plot_save=plot_save)
end

function _did_test_pretrend(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        leads::Int=3, horizon::Int=5, lags::Int=4,
        cluster::String="unit", conf_level::Float64=0.95,
        method::String="did", did_method::String="twfe",
        output::String="", format::String="table")

    isempty(outcome) && error("--outcome is required")
    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    if method == "event-study"
        est = estimate_event_study_lp(pd, outcome, treatment, horizon;
            leads=leads, lags=lags, cluster=Symbol(cluster), conf_level=conf_level)
        result = pretrend_test(est)
    else
        est = estimate_did(pd, outcome, treatment;
            method=Symbol(did_method), leads=leads, horizon=horizon,
            cluster=Symbol(cluster), conf_level=conf_level)
        result = pretrend_test(est)
    end

    output_kv("Pre-Trend Test", [
        "Test type" => String(result.test_type),
        "F-statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Degrees of freedom" => result.df,
        "Verdict" => result.pvalue > 0.05 ?
            "Cannot reject parallel trends (p > 0.05)" :
            "Reject parallel trends (p ≤ 0.05)"
    ]; format=format, output=output)
end

function _did_test_negweight(; data::String, treatment::String,
        id_col::String="", time_col::String="",
        output::String="", format::String="table")

    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    result = negative_weight_check(pd, treatment)

    output_kv("Negative Weight Check (de Chaisemartin-D'Haultfoeuille 2020)", [
        "Negative weights found" => result.has_negative_weights ? "yes" : "no",
        "Number of negative weights" => result.n_negative,
        "Total negative weight" => round(result.total_negative_weight; digits=6),
    ]; format=format, output=output)

    if result.has_negative_weights && !isempty(result.cohort_time_pairs)
        wt_df = DataFrame(
            Cohort = [p[1] for p in result.cohort_time_pairs],
            Time = [p[2] for p in result.cohort_time_pairs],
            Weight = round.(result.weights; digits=6)
        )
        println()
        output_result(wt_df; format=format, output="",
            title="Weight Details")
    end
end

function _did_test_honest(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        mbar::Float64=1.0,
        leads::Int=3, horizon::Int=5, lags::Int=4,
        cluster::String="unit", conf_level::Float64=0.95,
        method::String="did", did_method::String="twfe",
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && error("--outcome is required")
    isempty(treatment) && error("--treatment is required")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    if method == "event-study"
        est = estimate_event_study_lp(pd, outcome, treatment, horizon;
            leads=leads, lags=lags, cluster=Symbol(cluster), conf_level=conf_level)
        result = honest_did(est; Mbar=mbar, conf_level=conf_level)
    else
        est = estimate_did(pd, outcome, treatment;
            method=Symbol(did_method), leads=leads, horizon=horizon,
            cluster=Symbol(cluster), conf_level=conf_level)
        result = honest_did(est; Mbar=mbar, conf_level=conf_level)
    end

    hon_df = DataFrame(
        Event_Time = result.post_event_times,
        ATT = round.(result.post_att; digits=6),
        Robust_CI_Lower = round.(result.robust_ci_lower; digits=6),
        Robust_CI_Upper = round.(result.robust_ci_upper; digits=6),
        Original_CI_Lower = round.(result.original_ci_lower; digits=6),
        Original_CI_Upper = round.(result.original_ci_upper; digits=6)
    )
    output_result(hon_df; format=format, output=output,
        title="HonestDiD Sensitivity (Rambachan-Roth 2023, M̄=$(mbar))")

    println()
    printstyled("  Breakdown value: "; bold=true)
    println(round(result.breakdown_value; digits=4))

    _maybe_plot(result; plot=plot, plot_save=plot_save)
end

# ─── Command Registration ───────────────────────────────────────

function register_did_commands!()
    # Estimation leaves
    did_estimate = LeafCommand("estimate", _did_estimate;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("outcome"; type=String, default="", description="Outcome variable column name (required)"),
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            Option("method"; type=String, default="twfe", description="twfe|cs|sa|bjs|dcdh"),
            _DID_PANEL_OPTIONS...,
            Option("leads"; type=Int, default=0, description="Pre-treatment periods"),
            Option("horizon"; type=Int, default=5, description="Post-treatment periods"),
            Option("covariates"; type=String, default="", description="Comma-separated covariate column names"),
            Option("control-group"; type=String, default="never_treated", description="never_treated|not_yet_treated"),
            Option("cluster"; type=String, default="unit", description="unit|time|twoway"),
            Option("conf-level"; type=Float64, default=0.95, description="Confidence level"),
            Option("n-boot"; type=Int, default=200, description="Bootstrap replications (dcdh only)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Estimate DID (twfe|cs|sa|bjs|dcdh)")

    did_event_study = LeafCommand("event-study", _did_event_study;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("outcome"; type=String, default="", description="Outcome variable column name (required)"),
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            _DID_PANEL_OPTIONS...,
            Option("leads"; type=Int, default=3, description="Pre-treatment leads"),
            Option("horizon"; type=Int, default=5, description="Post-treatment horizon"),
            Option("lags"; short="p", type=Int, default=4, description="Control lags"),
            Option("covariates"; type=String, default="", description="Comma-separated covariate column names"),
            Option("cluster"; type=String, default="unit", description="unit|time|twoway"),
            Option("conf-level"; type=Float64, default=0.95, description="Confidence level"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Panel event study LP (Jordà 2005 + panel FE)")

    did_lp_did = LeafCommand("lp-did", _did_lp_did;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("outcome"; type=String, default="", description="Outcome variable column name (required)"),
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            _DID_PANEL_OPTIONS...,
            Option("leads"; type=Int, default=3, description="Pre-treatment leads"),
            Option("horizon"; type=Int, default=5, description="Post-treatment horizon"),
            Option("lags"; short="p", type=Int, default=4, description="Control lags"),
            Option("covariates"; type=String, default="", description="Comma-separated covariate column names"),
            Option("cluster"; type=String, default="unit", description="unit|time|twoway"),
            Option("conf-level"; type=Float64, default=0.95, description="Confidence level"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="LP-DiD with clean controls (Dube et al. 2023)")

    # Test leaves
    did_test_bacon = LeafCommand("bacon", _did_test_bacon;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("outcome"; type=String, default="", description="Outcome variable column name (required)"),
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            _DID_PANEL_OPTIONS...,
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Bacon decomposition (Goodman-Bacon 2021)")

    did_test_pretrend = LeafCommand("pretrend", _did_test_pretrend;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("outcome"; type=String, default="", description="Outcome variable column name (required)"),
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            _DID_PANEL_OPTIONS...,
            Option("leads"; type=Int, default=3, description="Pre-treatment leads"),
            Option("horizon"; type=Int, default=5, description="Post-treatment horizon"),
            Option("lags"; short="p", type=Int, default=4, description="Control lags (event-study only)"),
            Option("cluster"; type=String, default="unit", description="unit|time|twoway"),
            Option("conf-level"; type=Float64, default=0.95, description="Confidence level"),
            Option("method"; type=String, default="did", description="did|event-study"),
            Option("did-method"; type=String, default="twfe", description="twfe|cs|sa|bjs|dcdh (did method only)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        description="Pre-trend test for parallel trends assumption")

    did_test_negweight = LeafCommand("negweight", _did_test_negweight;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            _DID_PANEL_OPTIONS...,
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        description="Negative weight check (de Chaisemartin-D'Haultfoeuille 2020)")

    did_test_honest = LeafCommand("honest", _did_test_honest;
        args=[Argument("data"; description="Path to panel CSV data file")],
        options=[
            Option("outcome"; type=String, default="", description="Outcome variable column name (required)"),
            Option("treatment"; type=String, default="", description="Treatment indicator column name (required)"),
            _DID_PANEL_OPTIONS...,
            Option("mbar"; type=Float64, default=1.0, description="Violation bound M̄"),
            Option("leads"; type=Int, default=3, description="Pre-treatment leads"),
            Option("horizon"; type=Int, default=5, description="Post-treatment horizon"),
            Option("lags"; short="p", type=Int, default=4, description="Control lags (event-study only)"),
            Option("cluster"; type=String, default="unit", description="unit|time|twoway"),
            Option("conf-level"; type=Float64, default=0.95, description="Confidence level"),
            Option("method"; type=String, default="did", description="did|event-study"),
            Option("did-method"; type=String, default="twfe", description="twfe|cs|sa|bjs|dcdh (did method only)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="HonestDiD sensitivity analysis (Rambachan-Roth 2023)")

    # Test NodeCommand
    test_subcmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "bacon"    => did_test_bacon,
        "pretrend" => did_test_pretrend,
        "negweight" => did_test_negweight,
        "honest"   => did_test_honest,
    )
    did_test = NodeCommand("test", test_subcmds,
        "DID diagnostics: Bacon decomposition, pre-trend tests, negative weights, HonestDiD")

    # Root NodeCommand
    subcmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "estimate"    => did_estimate,
        "event-study" => did_event_study,
        "lp-did"      => did_lp_did,
        "test"        => did_test,
    )
    return NodeCommand("did", subcmds,
        "Difference-in-differences: estimation, event study LP, diagnostics")
end
```

**Step 4: Include in Friedman.jl and test_commands.jl**

In `src/Friedman.jl`, add after the `include("commands/dsge.jl")` line (line 50):
```julia
include("commands/did.jl")
```

In `test/test_commands.jl`, add after the `include(... "dsge.jl")` line (line 72):
```julia
include(joinpath(project_root, "src", "commands", "did.jl"))
```

**Step 5: Run tests**

Run: `julia --project test/runtests.jl`
Expected: All tests PASS including the new DID structure tests.

**Step 6: Commit**

```bash
git add src/commands/did.jl src/Friedman.jl test/test_commands.jl test/runtests.jl
git commit -m "feat: add did command with 7 subcommands (estimate, event-study, lp-did, test/*)"
```

---

### Task 4: Add DID handler tests to test/test_commands.jl

**Files:**
- Modify: `test/test_commands.jl` (append before final `end  # Command Handlers`)

**Step 1: Write handler tests**

Append the following test block before the final `end  # Command Handlers` line in `test/test_commands.jl`:

```julia
# ─── DID Commands ────────────────────────────────────────────────

@testset "DID commands" begin

    # Helper: create panel CSV with treatment column
    function _make_did_csv(dir; G=5, T_per=20)
        rows = G * T_per
        data = Dict{String,Vector}()
        data["unit"] = repeat(1:G, inner=T_per)
        data["time"] = repeat(1:T_per, outer=G)
        data["outcome"] = randn(rows) .+ 1.0
        # Staggered treatment: groups 1-2 treated at t=10, group 3 at t=15, groups 4-5 never
        treat = zeros(Int, rows)
        for i in 1:rows
            g = data["unit"][i]
            t = data["time"][i]
            if g <= 2 && t >= 10
                treat[i] = 1
            elseif g == 3 && t >= 15
                treat[i] = 1
            end
        end
        data["treat"] = treat
        data["covar1"] = randn(rows)
        path = joinpath(dir, "did_panel.csv")
        CSV.write(path, DataFrame(data))
        return path
    end

    @testset "_did_estimate — twfe default" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_estimate(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", format="table")
            end
            @test occursin("DID Estimation", out)
            @test occursin("TWFE", out)
            @test occursin("ATT", out)
            @test occursin("Overall ATT", out)
        end
    end

    @testset "_did_estimate — callaway_santanna with group-time" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_estimate(; data=csv, outcome="outcome", treatment="treat",
                    method="cs", id_col="unit", time_col="time", format="table")
            end
            @test occursin("DID Estimation", out)
            @test occursin("CS", out)
            @test occursin("Group-Time ATT", out)
        end
    end

    @testset "_did_estimate — methods cycle" begin
        for m in ["twfe", "sa", "bjs", "dcdh"]
            mktempdir() do dir
                csv = _make_did_csv(dir)
                out = _capture() do
                    _did_estimate(; data=csv, outcome="outcome", treatment="treat",
                        method=m, id_col="unit", time_col="time", format="table")
                end
                @test occursin("DID Estimation", out)
            end
        end
    end

    @testset "_did_estimate — missing outcome" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            @test_throws ErrorException _did_estimate(;
                data=csv, outcome="", treatment="treat",
                id_col="unit", time_col="time", format="table")
        end
    end

    @testset "_did_estimate — csv output" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out_path = joinpath(dir, "result.csv")
            out = _capture() do
                _did_estimate(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", output=out_path, format="csv")
            end
            @test isfile(out_path)
        end
    end

    @testset "_did_event_study — default" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_event_study(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", format="table")
            end
            @test occursin("Event Study LP", out)
            @test occursin("Coefficient", out)
            @test occursin("Lags", out)
        end
    end

    @testset "_did_event_study — custom leads/horizon" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_event_study(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", leads=5, horizon=10, lags=2,
                    format="table")
            end
            @test occursin("Event Study LP", out)
        end
    end

    @testset "_did_lp_did — default" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_lp_did(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", format="table")
            end
            @test occursin("LP-DiD", out)
            @test occursin("Clean controls", out) || occursin("clean", out)
        end
    end

    @testset "_did_test_bacon — default" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_test_bacon(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", format="table")
            end
            @test occursin("Bacon Decomposition", out)
            @test occursin("Weight", out)
            @test occursin("Overall ATT", out)
        end
    end

    @testset "_did_test_pretrend — did method" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_test_pretrend(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", method="did",
                    did_method="twfe", format="table")
            end
            @test occursin("Pre-Trend Test", out)
            @test occursin("p-value", out) || occursin("pvalue", out)
        end
    end

    @testset "_did_test_pretrend — event-study method" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_test_pretrend(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", method="event-study",
                    format="table")
            end
            @test occursin("Pre-Trend Test", out)
        end
    end

    @testset "_did_test_negweight — default" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_test_negweight(; data=csv, treatment="treat",
                    id_col="unit", time_col="time", format="table")
            end
            @test occursin("Negative Weight", out)
            @test occursin("Weight Details", out) || occursin("weight", out)
        end
    end

    @testset "_did_test_honest — did method" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_test_honest(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", mbar=1.5,
                    method="did", did_method="twfe", format="table")
            end
            @test occursin("HonestDiD", out)
            @test occursin("Breakdown", out) || occursin("breakdown", out)
        end
    end

    @testset "_did_test_honest — event-study method" begin
        mktempdir() do dir
            csv = _make_did_csv(dir)
            out = _capture() do
                _did_test_honest(; data=csv, outcome="outcome", treatment="treat",
                    id_col="unit", time_col="time", mbar=2.0,
                    method="event-study", format="table")
            end
            @test occursin("HonestDiD", out)
        end
    end

    @testset "register_did_commands! — structure" begin
        node = register_did_commands!()
        @test node isa NodeCommand
        @test node.name == "did"
        @test haskey(node.subcmds, "estimate")
        @test haskey(node.subcmds, "event-study")
        @test haskey(node.subcmds, "lp-did")
        @test haskey(node.subcmds, "test")
        @test length(node.subcmds) == 4
        test_node = node.subcmds["test"]
        @test test_node isa NodeCommand
        @test haskey(test_node.subcmds, "bacon")
        @test haskey(test_node.subcmds, "pretrend")
        @test haskey(test_node.subcmds, "negweight")
        @test haskey(test_node.subcmds, "honest")
        @test length(test_node.subcmds) == 4
    end
end
```

**Step 2: Run tests**

Run: `julia --project test/runtests.jl`
Expected: All tests PASS including ~18 new DID handler tests.

**Step 3: Commit**

```bash
git add test/test_commands.jl
git commit -m "test: add DID command handler tests"
```

---

### Task 5: Wire up Friedman.jl and version bump

**Files:**
- Modify: `src/Friedman.jl` (line 52, line 60-73, line 78)
- Modify: `src/cli/types.jl` (line 111)
- Modify: `Project.toml` (lines 3, 25)

**Step 1: Update `src/Friedman.jl`**

Change `FRIEDMAN_VERSION` (line 52):
```julia
const FRIEDMAN_VERSION = v"0.3.1"
```

Add `"did"` to `build_app()` root_cmds dict (after `"dsge"` entry, line 72):
```julia
        "did"       => register_did_commands!(),
```

Note: The `include("commands/did.jl")` was already added in Task 3.

**Step 2: Update `src/cli/types.jl`**

Change Entry default version (line 111):
```julia
Entry(name::String, root::NodeCommand; version::VersionNumber=v"0.3.1") =
```

**Step 3: Update `Project.toml`**

Change version (line 3):
```
version = "0.3.1"
```

Change MacroEconometricModels compat (line 25):
```
MacroEconometricModels = "0.3.2"
```

**Step 4: Update version references in runtests.jl**

Search for `v"0.3.0"` in `test/runtests.jl` and replace with `v"0.3.1"`. Also search for the string `"0.3.0"` used in version display tests and replace with `"0.3.1"`.

**Step 5: Run tests**

Run: `julia --project test/runtests.jl`
Expected: All tests PASS with updated version numbers.

**Step 6: Commit**

```bash
git add src/Friedman.jl src/cli/types.jl Project.toml test/runtests.jl
git commit -m "chore: bump to v0.3.1, MEMs compat 0.3.2, register did command"
```

---

### Task 6: Final verification

**Step 1: Run full test suite**

Run: `julia --project test/runtests.jl`
Expected: All tests PASS. Total count should be ~1,747 + ~70 new = ~1,817.

**Step 2: Verify build_app includes did**

Run: `julia --project -e 'using Pkg; Pkg.instantiate()'` (may need MEMs v0.3.2 — skip if not available locally)

Or verify structurally:
```bash
grep -n "did" src/Friedman.jl
```
Expected: Shows `include("commands/did.jl")` and `"did" => register_did_commands!()`.

**Step 3: Verify command count**

```bash
grep -c "LeafCommand" src/commands/did.jl
```
Expected: 7

**Step 4: Commit (if any fixes needed)**

Only if fixes were required in steps 1-3.
