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
    OptionSpec(name="id-col", type=String, default="", description="Panel unit ID column (default: first column)"),
    OptionSpec(name="time-col", type=String, default="", description="Time column (default: second column)"),
]

function _did_panel_cols(df, id_col::String, time_col::String)
    cols = names(df)
    id = isempty(id_col) ? cols[1] : id_col
    tc = isempty(time_col) ? cols[2] : time_col
    return id, tc
end

"""Map CLI DiD method shorts to upstream `estimate_did` symbols.

Upstream (MEMs 1.0.0 `did/estimation.jl`) routes only on the long names
(`:twfe`, `:callaway_santanna`, `:sun_abraham`, `:bjs`, `:did_multiplegt`) and
throws an untyped `ArgumentError` otherwise — forwarding `Symbol(method)`
directly made every `--method cs|sa|dcdh` invocation die with exit 1."""
const DID_METHOD_MAP = Dict(
    "twfe" => :twfe,
    "cs"   => :callaway_santanna,
    "sa"   => :sun_abraham,
    "bjs"  => :bjs,
    "dcdh" => :did_multiplegt,
)

function _did_method_sym(s::String)
    haskey(DID_METHOD_MAP, s) && return DID_METHOD_MAP[s]
    throw(CliError("usage/invalid",
        "unknown DiD method '$s' (expected twfe|cs|sa|bjs|dcdh)"))
end

# ─── Handlers ────────────────────────────────────────────────────

function _did_estimate(; data::String, outcome::String, treatment::String,
        method::String="twfe", id_col::String="", time_col::String="",
        leads::Int=0, horizon::Int=5, covariates::String="",
        control_group::String="never_treated", cluster::String="unit",
        conf_level::Float64=0.90, n_boot::Int=200,
        base_period::String="varying",
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && throw(CliError("usage/missing-option", "--outcome is required"))
    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))
    conf_level = _validate_conf_level(conf_level, "did estimate")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    covs = isempty(covariates) ? String[] : String.(split(covariates, ","))

    result = estimate_did(pd, outcome, treatment;
        method=_did_method_sym(method), leads=leads, horizon=horizon,
        covariates=covs, control_group=Symbol(control_group),
        cluster=Symbol(cluster), conf_level=conf_level, n_boot=n_boot,
        base_period=Symbol(base_period), _fwd_seed()...)

    # #216: the C051 exception is overturned — upstream `_coef_nt(::DIDResult)` is a
    # strict superset (event_time|term|estimate|std_error|stat|p_value|ci_lower|ci_upper),
    # so the event-time block routes through the central helper. Key frozen (`did_estimation`).
    fmt = Symbol(lowercase(format))
    _emit_result(result; title="DID Estimation — $(uppercase(method))", key="did_estimation",
        format=fmt, output=output, conf_level=conf_level)

    _status()
    _status_styled("  Overall ATT: "; bold=true)
    _status("$(round(result.overall_att; digits=6))  (SE: $(round(result.overall_se; digits=6)))")
    _status_styled("  Method: "; bold=true)
    _status(method)
    _status_styled("  N: "; bold=true)
    _status("$(result.n_obs) obs, $(result.n_groups) groups ($(result.n_treated) treated, $(result.n_control) control)")

    if !isnothing(result.group_time_att) && !isnothing(result.cohorts) &&
            size(result.group_time_att, 1) == length(result.cohorts)
        # Upstream group_time_att is cohorts × CALENDAR periods (n_times), not
        # cohorts × event times — labeling columns with event_times crashed with
        # DimensionMismatch whenever n_times != length(event_times).
        _status()
        gt = result.group_time_att
        gt_df = DataFrame(gt, ["period_$(t)" for t in 1:size(gt, 2)])
        insertcols!(gt_df, 1, :Cohort => result.cohorts)
        output_result(gt_df; format=fmt, output=_per_var_output_path(output, "group_time"),
            title="Group-Time ATT (Callaway-Sant'Anna)")
    end

    _maybe_plot(result; plot=plot, plot_save=plot_save, conf_level=conf_level)
    return result
end

function _did_event_study(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        leads::Int=3, horizon::Int=5, lags::Int=4,
        covariates::String="", cluster::String="unit",
        conf_level::Float64=0.90,
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && throw(CliError("usage/missing-option", "--outcome is required"))
    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))
    conf_level = _validate_conf_level(conf_level, "did event-study")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    covs = isempty(covariates) ? String[] : String.(split(covariates, ","))

    result = estimate_event_study_lp(pd, outcome, treatment, horizon;
        leads=leads, lags=lags, covariates=covs,
        cluster=Symbol(cluster), conf_level=conf_level)

    fmt = Symbol(lowercase(format))
    _emit_result(result; title="Event Study LP — $(result.outcome_var)",
                 key="event_study_lp", format=fmt, output=output, conf_level=conf_level)

    _status()
    _status_styled("  N: "; bold=true)
    _status("$(result.n_obs) obs, $(result.n_groups) groups")
    _status_styled("  Lags: "; bold=true)
    _status_styled("$(result.lags)  ")
    _status_styled("Leads: "; bold=true)
    _status_styled("$(result.leads)  ")
    _status_styled("Horizon: "; bold=true)
    _status("$(result.horizon)")

    _maybe_plot(result; plot=plot, plot_save=plot_save, conf_level=conf_level)
    return result
end

function _did_lp_did(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        horizon::Int=5, pre_window::Int=3, post_window::Int=0,
        ylags::Int=0, dylags::Int=0,
        covariates::String="", cluster::String="unit",
        conf_level::Float64=0.68,
        pmd::String="", nonabsorbing::String="",
        reweight::Bool=false, nocomp::Bool=false,
        notyet::Bool=false, nevertreated::Bool=false,
        firsttreat::Bool=false, oneoff::Bool=false,
        only_pooled::Bool=false, only_event::Bool=false,
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && throw(CliError("usage/missing-option", "--outcome is required"))
    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))
    conf_level = _validate_conf_level(conf_level, "did lp-did")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    covs = isempty(covariates) ? String[] : String.(split(covariates, ","))

    # Parse pmd: empty→nothing, "ccs"→:ccs, "ipw"→:ipw, integer string→Int
    pmd_val::Union{Nothing,Symbol,Int} = if isempty(pmd)
        nothing
    elseif pmd in ("ccs", "ipw")
        Symbol(pmd)
    else
        v = tryparse(Int, strip(pmd))
        v === nothing && throw(CliError("usage/invalid",
            "estimate panel lp-did: --pmd must be 'ccs', 'ipw', or an integer (got '$pmd')"))
        v
    end

    # Parse nonabsorbing: empty→nothing, else→parse Int
    nonabs_val = if isempty(nonabsorbing)
        nothing
    else
        v = tryparse(Int, strip(nonabsorbing))
        v === nothing && throw(CliError("usage/invalid",
            "estimate panel lp-did: --nonabsorbing must be an integer (got '$nonabsorbing')"))
        v
    end

    pw = post_window == 0 ? horizon : post_window

    result = try
        estimate_lp_did(pd, outcome, treatment, horizon;
            pre_window=pre_window, post_window=pw,
            ylags=ylags, dylags=dylags,
            covariates=covs, nonabsorbing=nonabs_val,
            notyet=notyet, nevertreated=nevertreated,
            firsttreat=firsttreat, oneoff=oneoff,
            pmd=pmd_val, reweight=reweight, nocomp=nocomp,
            cluster=Symbol(cluster), conf_level=conf_level,
            only_pooled=only_pooled, only_event=only_event)
    catch e
        throw(_domain_or_data_error(e, "LP-DiD estimation"))
    end

    fmt = Symbol(lowercase(format))
    _emit_result(result; title="LP-DiD (Dube et al. 2023) — $(result.outcome_var)",
                 key="lp_did_dube_et_al_2023", format=fmt, output=output)

    _status()
    _status_styled("  Specification: "; bold=true)
    _status(result.specification)
    _status_styled("  N: "; bold=true)
    _status("$(result.T_obs) obs, $(result.n_groups) groups")
    _status_styled("  Window: "; bold=true)
    _status("pre=$(result.pre_window), post=$(result.post_window)")

    if !isnothing(result.pooled_post)
        pp = result.pooled_post
        _status()
        _status_styled("  Pooled post-treatment: "; bold=true)
        _status("coef=$(round(pp.coef; digits=6))  SE=$(round(pp.se; digits=6))  CI=[$(round(pp.ci_lower; digits=6)), $(round(pp.ci_upper; digits=6))]")
    end
    if !isnothing(result.pooled_pre)
        pp = result.pooled_pre
        _status_styled("  Pooled pre-treatment:  "; bold=true)
        _status("coef=$(round(pp.coef; digits=6))  SE=$(round(pp.se; digits=6))  CI=[$(round(pp.ci_lower; digits=6)), $(round(pp.ci_upper; digits=6))]")
    end

    _maybe_plot(result; plot=plot, plot_save=plot_save, conf_level=conf_level)
    return result
end

function _did_test_bacon(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && throw(CliError("usage/missing-option", "--outcome is required"))
    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    result = bacon_decomposition(pd, outcome, treatment)

    fmt = Symbol(lowercase(format))
    _emit_result(result; title="Bacon Decomposition (Goodman-Bacon 2021)",
                 key="bacon_decomposition_goodman_bacon_2021", format=fmt, output=output)

    _status()
    _status_styled("  Overall ATT (TWFE): "; bold=true)
    _status(round(result.overall_att; digits=6))

    _maybe_plot(result; plot=plot, plot_save=plot_save)
    return result
end

function _did_test_pretrend(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        leads::Int=3, horizon::Int=5, lags::Int=4,
        cluster::String="unit", conf_level::Float64=0.90,
        method::String="did", did_method::String="twfe",
        output::String="", format::String="table")

    isempty(outcome) && throw(CliError("usage/missing-option", "--outcome is required"))
    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))
    conf_level = _validate_conf_level(conf_level, "test did pretrend")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    if method == "event-study"
        est = estimate_event_study_lp(pd, outcome, treatment, horizon;
            leads=leads, lags=lags, cluster=Symbol(cluster), conf_level=conf_level)
        result = pretrend_test(est)
    else
        est = estimate_did(pd, outcome, treatment;
            method=_did_method_sym(did_method), leads=leads, horizon=horizon,
            cluster=Symbol(cluster), conf_level=conf_level, _fwd_seed()...)
        result = pretrend_test(est)
    end

    output_kv([
        "Test type" => String(result.test_type),
        "F-statistic" => result.statistic,
        "p-value" => result.pvalue,
        "Degrees of freedom" => result.df,
        "Verdict" => result.pvalue > 0.05 ?
            "Cannot reject parallel trends (p > 0.05)" :
            "Reject parallel trends (p ≤ 0.05)"
    ]; format=format, output=output, title="Pre-Trend Test")
    return result
end

function _did_test_negweight(; data::String, treatment::String,
        id_col::String="", time_col::String="",
        output::String="", format::String="table")

    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    result = negative_weight_check(pd, treatment)

    fmt = Symbol(lowercase(format))
    output_kv([
        "Negative weights found" => result.has_negative_weights ? "yes" : "no",
        "Number of negative weights" => result.n_negative,
        "Total negative weight" => result.total_negative_weight,
    ]; format=format, output=output, title="Negative Weight Check (de Chaisemartin-D'Haultfoeuille 2020)")

    if result.has_negative_weights && !isempty(result.cohort_time_pairs)
        wt_df = DataFrame(
            Cohort = [p[1] for p in result.cohort_time_pairs],
            Time = [p[2] for p in result.cohort_time_pairs],
            Weight = result.weights
        )
        _status()
        output_result(wt_df; format=fmt, output=_per_var_output_path(output, "weights"),
            title="Weight Details")
    end
    return result
end

function _did_test_honest(; data::String, outcome::String, treatment::String,
        id_col::String="", time_col::String="",
        mbar::Float64=1.0,
        leads::Int=3, horizon::Int=5, lags::Int=4,
        cluster::String="unit", conf_level::Float64=0.90,
        method::String="did", did_method::String="twfe",
        output::String="", format::String="table",
        plot::Bool=false, plot_save::String="")

    isempty(outcome) && throw(CliError("usage/missing-option", "--outcome is required"))
    isempty(treatment) && throw(CliError("usage/missing-option", "--treatment is required"))
    conf_level = _validate_conf_level(conf_level, "test did honest")

    df = load_data(data)
    id, tc = _did_panel_cols(df, id_col, time_col)
    pd = _load_panel_for_did(data, id, tc)

    if method == "event-study"
        est = estimate_event_study_lp(pd, outcome, treatment, horizon;
            leads=leads, lags=lags, cluster=Symbol(cluster), conf_level=conf_level)
        result = honest_did(est; Mbar=mbar, conf_level=conf_level)
    else
        est = estimate_did(pd, outcome, treatment;
            method=_did_method_sym(did_method), leads=leads, horizon=horizon,
            cluster=Symbol(cluster), conf_level=conf_level, _fwd_seed()...)
        result = honest_did(est; Mbar=mbar, conf_level=conf_level)
    end

    hon_df = DataFrame(
        Event_Time = result.post_event_times,
        ATT = result.post_att,
        Robust_CI_Lower = result.robust_ci_lower,
        Robust_CI_Upper = result.robust_ci_upper,
        Original_CI_Lower = result.original_ci_lower,
        Original_CI_Upper = result.original_ci_upper
    )
    fmt = Symbol(lowercase(format))
    output_result(hon_df; format=fmt, output=output,
        title="HonestDiD Sensitivity (Rambachan-Roth 2023, M̄=$(mbar))",
        key="honestdid_sensitivity_rambachan_roth_2023")

    _status()
    _status_styled("  Breakdown value: "; bold=true)
    _status(round(result.breakdown_value; digits=4))

    _maybe_plot(result; plot=plot, plot_save=plot_save, conf_level=conf_level)
    return result
end

# ─── Command Registration ───────────────────────────────────────

function did_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["did", "estimate"],
            summary="Staggered-adoption DiD estimation (twfe|cs|sa|bjs|dcdh) with event-time and overall ATT",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="outcome", type=String, default="", description="Outcome variable column name (required)"),
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                OptionSpec(name="method", type=String, default="twfe", choices=["twfe", "cs", "sa", "bjs", "dcdh"], description="twfe|cs|sa|bjs|dcdh"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="leads", type=Int, default=0, description="Pre-treatment periods"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=5, description="Post-treatment periods"),
                OptionSpec(name="covariates", type=String, default="", description="Comma-separated covariate column names"),
                OptionSpec(name="control-group", type=String, default="never_treated", description="never_treated|not_yet_treated", choices=["never_treated","not_yet_treated"]),
                OptionSpec(name="cluster", type=String, default="unit", description="unit|time|twoway", choices=["unit","time","twoway"]),
                CONF_LEVEL_MICRO_OPTION,
                OptionSpec(name="n-boot", type=Int, default=200, description="Bootstrap replications (dcdh only)"),
                OptionSpec(name="base-period", type=String, default="varying", description="varying|universal (Callaway-Sant'Anna only)", choices=["varying","universal"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[
                TableSpec(name=:did_estimation,
                          description="ATT with standard error and confidence band by event time"),
                TableSpec(name=:group_time_att_callaway_sant_anna,
                          description="Cohort-by-calendar-period effects table (shown whenever the method reports group-time effects)"),
            ],
            category="did",
            handler=wrap_legacy(_did_estimate),
        ),
        CommandSpec(
            path=["did", "event-study"],
            summary="Local-projection event-study DiD with pre-trend leads and post-treatment horizon",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="outcome", type=String, default="", description="Outcome variable column name (required)"),
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="leads", type=Int, default=3, description="Pre-treatment leads"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=5, description="Post-treatment horizon"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Control lags"),
                OptionSpec(name="covariates", type=String, default="", description="Comma-separated covariate column names"),
                OptionSpec(name="cluster", type=String, default="unit", description="unit|time|twoway"),
                CONF_LEVEL_MICRO_OPTION,
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:event_study_lp,
                              description="Local-projection event-study coefficient, SE and confidence band by event time")],
            category="did",
            handler=wrap_legacy(_did_event_study),
        ),
        CommandSpec(
            path=["did", "lp-did"],
            summary="LP-DiD estimation (Dube et al. 2023) with pre/post windows and clean-control options",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="outcome", type=String, default="", description="Outcome variable column name (required)"),
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=5, description="Post-treatment horizon"),
                OptionSpec(name="pre-window", type=Int, default=3, description="Pre-treatment window"),
                OptionSpec(name="post-window", type=Int, default=0, description="Post-treatment window (0 = use horizon)"),
                OptionSpec(name="ylags", type=Int, default=0, description="Outcome lags"),
                OptionSpec(name="dylags", type=Int, default=0, description="Differenced outcome lags"),
                OptionSpec(name="covariates", type=String, default="", description="Comma-separated covariate column names"),
                OptionSpec(name="cluster", type=String, default="unit", description="unit|time|twoway"),
                CONF_LEVEL_MACRO_OPTION,
                OptionSpec(name="pmd", type=String, default="", description="Pre-treatment matching: ccs|ipw|<integer>"),
                OptionSpec(name="nonabsorbing", type=String, default="", description="Non-absorbing treatment (integer periods)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser"),
                FlagSpec(name="reweight", description="Reweight observations"),
                FlagSpec(name="nocomp", description="No composition adjustment"),
                FlagSpec(name="notyet", description="Use not-yet-treated as controls"),
                FlagSpec(name="nevertreated", description="Use never-treated as controls"),
                FlagSpec(name="firsttreat", description="Use first-treatment timing"),
                FlagSpec(name="oneoff", description="One-off treatment specification"),
                FlagSpec(name="only-pooled", description="Only estimate pooled effects (the event-time table is still shown)"),
                FlagSpec(name="only-event", description="Only estimate event-time effects (the event-time table is still shown)"),
            ],
            tables=[TableSpec(name=:lp_did_dube_et_al_2023,
                              description="LP-DiD coefficient, SE, confidence band and observation count by event time")],
            category="did",
            handler=wrap_legacy(_did_lp_did),
        ),
        CommandSpec(
            path=["did", "test", "bacon"],
            summary="Goodman-Bacon (2021) decomposition of TWFE into 2x2 DiD comparisons with weights",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="outcome", type=String, default="", description="Outcome variable column name (required)"),
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bacon_decomposition_goodman_bacon_2021,
                              description="Estimate and weight of every 2x2 DiD comparison by cohort pair and type")],
            category="did",
            handler=wrap_legacy(_did_test_bacon),
        ),
        CommandSpec(
            path=["did", "test", "pretrend"],
            summary="Joint pre-trend (parallel-trends) test from a DiD or event-study fit",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="outcome", type=String, default="", description="Outcome variable column name (required)"),
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="leads", type=Int, default=3, description="Pre-treatment leads"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=5, description="Post-treatment horizon"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Control lags (event-study only)"),
                OptionSpec(name="cluster", type=String, default="unit", description="unit|time|twoway"),
                CONF_LEVEL_MICRO_OPTION,
                OptionSpec(name="method", type=String, default="did", description="did|event-study", choices=["did","event-study"]),
                OptionSpec(name="did-method", type=String, default="twfe", choices=["twfe", "cs", "sa", "bjs", "dcdh"], description="twfe|cs|sa|bjs|dcdh (did method only)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pre_trend_test,
                              description="Joint pre-trend test type, statistic, p-value, degrees of freedom and verdict")],
            category="did",
            handler=wrap_legacy(_did_test_pretrend),
        ),
        CommandSpec(
            path=["did", "test", "negweight"],
            summary="Negative-weight diagnostic for TWFE (de Chaisemartin-D'Haultfoeuille 2020)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:negative_weight_check_de_chaisemartin_d_haultfoeuille_2020,
                          description="Whether TWFE assigns negative weights, how many, and their total"),
                TableSpec(name=:weight_details,
                          description="The offending cohort-time cells and their weights (only when negative weights exist)"),
            ],
            category="did",
            handler=wrap_legacy(_did_test_negweight),
        ),
        CommandSpec(
            path=["did", "test", "honest"],
            summary="HonestDiD sensitivity analysis (Rambachan-Roth 2023) with violation bound Mbar",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="outcome", type=String, default="", description="Outcome variable column name (required)"),
                OptionSpec(name="treatment", type=String, default="", description="Treatment indicator column name (required)"),
                _DID_PANEL_OPTIONS...,
                OptionSpec(name="mbar", type=Float64, default=1.0, description="Violation bound M̄"),
                OptionSpec(name="leads", type=Int, default=3, description="Pre-treatment leads"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=5, description="Post-treatment horizon"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Control lags (event-study only)"),
                OptionSpec(name="cluster", type=String, default="unit", description="unit|time|twoway"),
                CONF_LEVEL_MICRO_OPTION,
                OptionSpec(name="method", type=String, default="did", description="did|event-study", choices=["did","event-study"]),
                OptionSpec(name="did-method", type=String, default="twfe", choices=["twfe", "cs", "sa", "bjs", "dcdh"], description="twfe|cs|sa|bjs|dcdh (did method only)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:honestdid_sensitivity_rambachan_roth_2023,
                              description="Post-treatment ATT with robust and original confidence bands by event time")],
            category="did",
            handler=wrap_legacy(_did_test_honest),
        )
    ]
end

const _DID_RESULT_TYPES = Dict{Vector{String},Vector{Symbol}}(
    ["did", "estimate"]          => [:DIDResult],
    ["did", "event-study"]       => [:EventStudyLP],
    ["did", "lp-did"]            => [:LPDiDResult],
    ["did", "test", "bacon"]     => [:BaconDecomposition],
    ["did", "test", "pretrend"]  => [:PretrendTestResult],
    ["did", "test", "negweight"] => [:NegativeWeightResult],
    ["did", "test", "honest"]    => [:HonestDiDResult],
)

function _rerender_did_result(result; format::String="table", output::String="",
                              title::String="", key::String="",
                              plot::Bool=false, plot_save::String="")
    tn = nameof(typeof(result))
    fmt = Symbol(lowercase(format))
    if tn === :DIDResult
        _emit_result(result; title="DID Estimation", key="did_estimation",
                     format=fmt, output=output)
        if hasproperty(result, :group_time_att) && !isnothing(result.group_time_att) &&
           hasproperty(result, :cohorts) && !isnothing(result.cohorts) &&
           size(result.group_time_att, 1) == length(result.cohorts)
            gt = result.group_time_att
            gt_df = DataFrame(gt, ["period_$(t)" for t in 1:size(gt, 2)])
            insertcols!(gt_df, 1, :Cohort => result.cohorts)
            output_result(gt_df; format=fmt, output=_per_var_output_path(output, "group_time"),
                          title="Group-Time ATT (Callaway-Sant'Anna)")
        end
    elseif tn === :EventStudyLP
        _emit_result(result; title="Event Study LP", key="event_study_lp",
                     format=fmt, output=output)
    elseif tn === :LPDiDResult
        _emit_result(result; title="LP-DiD (Dube et al. 2023)", key="lp_did_dube_et_al_2023",
                     format=fmt, output=output)
    elseif tn === :BaconDecomposition
        _emit_result(result; title="Bacon Decomposition (Goodman-Bacon 2021)",
                     key="bacon_decomposition_goodman_bacon_2021",
                     format=fmt, output=output)
    elseif tn === :PretrendTestResult
        output_kv([
            "Test type" => String(result.test_type),
            "F-statistic" => result.statistic,
            "p-value" => result.pvalue,
            "Degrees of freedom" => result.df,
            "Verdict" => result.pvalue > 0.05 ?
                "Cannot reject parallel trends (p > 0.05)" :
                "Reject parallel trends (p ≤ 0.05)",
        ]; format=format, output=output, title="Pre-Trend Test")
    elseif tn === :NegativeWeightResult
        output_kv([
            "Negative weights found" => result.has_negative_weights ? "yes" : "no",
            "Number of negative weights" => result.n_negative,
            "Total negative weight" => result.total_negative_weight,
        ]; format=format, output=output,
            title="Negative Weight Check (de Chaisemartin-D'Haultfoeuille 2020)")
        if result.has_negative_weights && !isempty(result.cohort_time_pairs)
            wt_df = DataFrame(
                Cohort = [p[1] for p in result.cohort_time_pairs],
                Time = [p[2] for p in result.cohort_time_pairs],
                Weight = result.weights,
            )
            output_result(wt_df; format=fmt, output=_per_var_output_path(output, "weights"),
                          title="Weight Details")
        end
    elseif tn === :HonestDiDResult
        hon_df = DataFrame(
            Event_Time = result.post_event_times,
            ATT = result.post_att,
            Robust_CI_Lower = result.robust_ci_lower,
            Robust_CI_Upper = result.robust_ci_upper,
            Original_CI_Lower = result.original_ci_lower,
            Original_CI_Upper = result.original_ci_upper,
        )
        output_result(hon_df; format=fmt, output=output,
                      title="HonestDiD Sensitivity (Rambachan-Roth 2023)",
                      key="honestdid_sensitivity_rambachan_roth_2023")
    else
        _rerender_kv(result; format=format, output=output, title=title, key=key)
    end
    _maybe_plot(result; plot=plot, plot_save=plot_save)
    return result
end

"""Prepared DiD specs. `did test *` is rewritten to `test did *` by `_finalize_spec`."""
function _prepared_did_specs()
    raw_handlers = Dict(
        ["did", "estimate"]          => _did_estimate,
        ["did", "event-study"]       => _did_event_study,
        ["did", "lp-did"]            => _did_lp_did,
        ["did", "test", "bacon"]     => _did_test_bacon,
        ["did", "test", "pretrend"]  => _did_test_pretrend,
        ["did", "test", "negweight"] => _did_test_negweight,
        ["did", "test", "honest"]    => _did_test_honest,
    )
    specs = CommandSpec[]
    for s in did_specs()
        rt = get(_DID_RESULT_TYPES, s.path, Symbol[])
        key = isempty(s.tables) ? "" : string(s.tables[1].name)
        raw_fn = raw_handlers[s.path]
        h = wrap_legacy(_with_result(raw_fn, join(s.path, " "); key=key,
                                     render_fn=_rerender_did_result))
        push!(specs, _copy_spec(s; handler=h, result_types=rt))
    end
    specs = with_result_handles(with_default_csv_kinds(with_data_kinds(specs, [:panel, :csv])))
    return CommandSpec[_finalize_spec(s) for s in specs]
end

"""The four diagnostic leaves, already moved under `test did`."""
function _did_test_specs()
    return filter(s -> s.path[1] == "test", _prepared_did_specs())
end

function register_did_commands!()
    stay = register!(filter(s -> s.path[1] == "did", _prepared_did_specs()))
    return build_node("did", stay; description="Difference-in-differences: estimation, event-study LP, LP-DiD (diagnostics under test did)")
end

