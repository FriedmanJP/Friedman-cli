# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Wave 4 (#316): Canonical ABCD invertibility suite (`dsge abcd *`) and
# Del Negro-Schorfheide Bayesian DSGE-VAR(λ) (`dsge var *`).

# ── Shared Wave-4 Parsing & Resolution Helpers ──────────────

const _W4_ABCD_INPUT_TYPES = Symbol[
    :ABCDSystem, :DSGESolution, :PerturbationSolution, :HADSGESolution, :StateSpaceModel,
]
const _W4_EXTRACT_INPUT_TYPES = Symbol[
    :DSGESolution, :PerturbationSolution, :HADSGESolution, :StateSpaceModel,
]
const _W4_DSGEVAR_INPUT_TYPES = Symbol[
    :ABCDSystem, :DSGESolution, :PerturbationSolution, :HADSGESolution, :StateSpaceModel, :ModelSpec,
]
const _W4_DSGEVAR_POST_INPUT_TYPES = Symbol[
    :DSGEVARPosterior, :ABCDSystem, :DSGESolution, :PerturbationSolution,
    :HADSGESolution, :StateSpaceModel, :ModelSpec,
]
const _W4_SOLVER_CHOICES = ["gensys", "klein", "perturbation", "blanchard-kahn"]

function _w4_parse_observables(raw::AbstractString)::Vector{Symbol}
    isempty(strip(raw)) && return Symbol[]
    return Symbol[Symbol(strip(tok)) for tok in split(raw, ",") if !isempty(strip(tok))]
end

function _w4_parse_measurement_error(raw::AbstractString, leaf::String)
    s = strip(raw)
    (isempty(s) || lowercase(s) == "none") && return nothing
    vals = Float64[]
    for tok in split(s, ",")
        t = strip(tok)
        isempty(t) && continue
        v = tryparse(Float64, t)
        (v === nothing || !isfinite(v) || v < 0.0) && throw(CliError("usage/invalid-option",
            "$leaf: --measurement-error expects non-negative comma-separated numbers (got '$raw')"))
        push!(vals, v)
    end
    isempty(vals) && return nothing
    return vals
end

function _w4_parse_reduction(raw::AbstractString, leaf::String)::Symbol
    sym = Symbol(lowercase(strip(raw)))
    sym in (:predetermined, :minimal, :none) || throw(CliError("usage/invalid-option",
        "$leaf: --reduction must be predetermined|minimal|none (got '$raw')"))
    return sym
end

function _w4_parse_lambda(raw::AbstractString, leaf::String; allow_auto::Bool=false)
    s = lowercase(strip(raw))
    if allow_auto && s == "auto"
        return :auto
    elseif s in ("inf", "+inf", "infinity")
        return Inf
    end
    v = tryparse(Float64, s)
    if v === nothing || isnan(v) || v <= 0.0
        hint = allow_auto ? "use 'auto', 'inf', or a positive number >= lambda_min" :
                            "use 'inf' or a positive number >= lambda_min"
        throw(CliError("usage/invalid-option",
            "$leaf: invalid --lambda '$raw' ($hint)"))
    end
    return v
end

function _w4_parse_lambda_grid(raw::AbstractString, leaf::String)::Vector{Float64}
    vals = Float64[]
    for tok in split(raw, ",")
        t = strip(tok)
        isempty(t) && continue
        v = _w4_parse_lambda(t, leaf; allow_auto=false)
        push!(vals, Float64(v))
    end
    isempty(vals) && throw(CliError("usage/invalid-option",
        "$leaf: --lambda-grid cannot be empty (got '$raw')"))
    return vals
end

function _w4_parse_quantiles(raw::AbstractString, leaf::String)::Vector{Float64}
    vals = Float64[]
    for tok in split(raw, ",")
        t = strip(tok)
        isempty(t) && continue
        v = tryparse(Float64, t)
        (v === nothing || !isfinite(v) || v <= 0.0 || v >= 1.0) && throw(CliError("usage/invalid-option",
            "$leaf: --quantiles must be comma-separated probabilities in (0, 1) (got '$raw')"))
        push!(vals, v)
    end
    isempty(vals) && throw(CliError("usage/invalid-option",
        "$leaf: --quantiles must contain at least one probability in (0, 1)"))
    return sort!(vals)
end

function _w4_parse_target_shocks(raw::AbstractString)
    toks = String[String(strip(t)) for t in split(raw, ",") if !isempty(strip(t))]
    isempty(toks) && return nothing
    ints = [tryparse(Int, t) for t in toks]
    if all(!isnothing, ints)
        return Int[Int(i) for i in ints]
    end
    return Symbol[Symbol(t) for t in toks]
end

"""Subset an `ABCDSystem` to requested observable names when `--observables` is given."""
function _w4_subset_abcd(sys::MacroEconometricModels.ABCDSystem{T}, obs::Vector{Symbol}, leaf::String) where {T}
    isempty(obs) && return sys
    all_syms = Symbol.(sys.obs_names)
    idx = Int[]
    for s in obs
        pos = findfirst(==(s), all_syms)
        pos === nothing && throw(CliError("data/invalid",
            "$leaf: observable :$s not found in ABCDSystem observables ($(join(sys.obs_names, ", ")))"))
        push!(idx, pos)
    end
    return MacroEconometricModels.ABCDSystem{T}(
        copy(sys.A), copy(sys.B),
        Matrix{T}(sys.C[idx, :]), Matrix{T}(sys.D[idx, :]),
        copy(sys.c_state), Vector{T}(sys.d_obs[idx]),
        copy(sys.state_names), String[sys.obs_names[i] for i in idx],
        copy(sys.shock_names),
    )
end

function _w4_is_handle_arg(path::String)::Bool
    isempty(path) && return false
    _is_handle_path(path) && return true
    exp_p = _expanduser(path)
    return !startswith(path, ":") &&
           !occursin(r"\.[A-Za-z0-9]+$", basename(exp_p)) &&
           any(ext -> isfile(exp_p * ext), (".jld2", ".jls", ".fmod"))
end

"""Resolve either positional DSGE `file` (.toml/.jl or handle) or `--model` handle."""
function _w4_resolve_dsge_source(file::String, model;
                                 allowed_types::Vector{Symbol},
                                 solver::String="gensys", order::Int=1,
                                 allow_priors::Bool=false,
                                 keep_spec::Bool=false,
                                 leaf::String="dsge")
    !isempty(file) && model !== nothing && throw(CliError("usage/conflicting-options",
        "$leaf: pass either a positional model file or --model, not both"))
    isempty(file) && model === nothing && throw(CliError("usage/missing",
        "$leaf: a DSGE model file (.toml/.jl) or --model handle is required"))

    if model !== nothing
        if !keep_spec && model isa MacroEconometricModels.ModelSpec
            return _solve_dsge(model; method=solver, order=order)
        end
        return model
    end

    if _w4_is_handle_arg(file)
        resolved = resolve_stem(file; slot=:result)
        obj = _load_typed_handle(resolved, allowed_types, "model/wrong-kind"; slot="model")
        if !keep_spec && obj isa MacroEconometricModels.ModelSpec
            return _solve_dsge(obj; method=solver, order=order)
        end
        return obj
    end

    spec = _load_dsge_model(file; allow_priors=allow_priors)
    keep_spec && return spec
    return _solve_dsge(spec; method=solver, order=order)
end

function _w4_reject_result_conflicts(result, file::String, model, data::String, leaf::String)
    result === nothing && return nothing
    (!isempty(file) || model !== nothing || !isempty(data)) && throw(CliError("usage/invalid",
        "$leaf: --result cannot be combined with a model file, --model, or --data";
        hint="omit --result to compute, or pass only --result to re-render"))
    return result
end

"""Load multivariate data for DSGE-VAR, aligning columns to `--observables` when named."""
function _w4_load_dsgevar_data(data::String, obs::Vector{Symbol}, leaf::String)
    isempty(data) && throw(CliError("usage/missing",
        "$leaf: --data is required (path to CSV or TimeSeriesData handle)"))
    Y, col_names = load_multivariate_data(data)
    if !isempty(obs) && size(Y, 2) != length(obs)
        obs_strs = String.(obs)
        if all(s -> s in col_names, obs_strs)
            idx = Int[findfirst(==(s), col_names) for s in obs_strs]
            return Matrix{Float64}(Y[:, idx]), obs_strs
        end
    end
    return Y, col_names
end

function _w4_guard_ss_measurement_error(src, me, leaf::String)
    if src isa MacroEconometricModels.StateSpaceModel && me !== nothing
        throw(CliError("usage/invalid-option",
            "$leaf: --measurement-error is not supported for StateSpaceModel (observation noise H is already in the state-space model)"))
    end
    return nothing
end

function _w4_reduction_for(src, reduction::String, default_non_ss::Symbol, leaf::String)::Symbol
    red = _w4_parse_reduction(reduction, leaf)
    if src isa MacroEconometricModels.StateSpaceModel &&
       !(isdefined(@__MODULE__, :_CURRENT_EXPLICIT_OPTS) && ("reduction" in _CURRENT_EXPLICIT_OPTS[]))
        return :none
    end
    return red
end

# ── Shared Renderers (strictly via _emit_result / upstream tables) ──────────

function _w4_render_audit(audit::MacroEconometricModels.DSGEVARIRFAudit;
                          format::String="table", output::String="",
                          plot::Bool=false, plot_save::String="")
    _status_report(() -> report(audit))
    _maybe_plot(audit; plot=plot, plot_save=plot_save)
    _emit_result(audit;
        title="DSGE vs. Population SVAR($(audit.p)) IRF Audit ($(audit.identification), H=$(audit.horizon))",
        key="dsge_var_irf_audit", format=Symbol(format), output=output)
    output_result(DataFrame(audit);
        format=Symbol(format), output=_per_var_output_path(output, "wedges"),
        title="DSGE-vs-SVAR IRF Distortion Wedges (RMSE by Horizon)",
        key="dsge_var_irf_wedges")
    return audit
end

function _w4_render_dsge_var_fevd(bfevd; id::String="", format::String="table", output::String="",
                                  plot::Bool=false, plot_save::String="")
    _status_report(() -> report(bfevd))
    _maybe_plot(bfevd; plot=plot, plot_save=plot_save)
    props = bfevd.point_estimate
    nv, ns, nh = size(props)
    vnames = bfevd.variables
    snames = bfevd.shocks
    id_suffix = isempty(id) ? "" : " ($id identification)"
    for vi in 1:nv
        vname = vi <= length(vnames) ? vnames[vi] : "var_$vi"
        df = DataFrame(horizon=collect(1:nh))
        for si in 1:ns
            sname = si <= length(snames) ? snames[si] : "shock_$si"
            df[!, sname] = props[vi, si, :]
        end
        output_result(df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="DSGE-VAR FEVD for $vname$id_suffix",
                      key=_table_key("dsge_var_fevd", vname))
        _status()
    end
    return bfevd
end

function _w4_render_dsge_var_hd(bhd; id::String="", format::String="table", output::String="",
                                plot::Bool=false, plot_save::String="")
    _status_report(() -> report(bhd))
    _maybe_plot(bhd; plot=plot, plot_save=plot_save)
    mean_contrib = bhd.point_estimate
    T_eff = size(mean_contrib, 1)
    _output_hd_tables((vi, si) -> mean_contrib[:, vi, si],
                      bhd.variables, T_eff;
                      id=id, title_prefix="DSGE-VAR Historical Decomposition",
                      format=format, output=output,
                      actual=isempty(bhd.actual) ? nothing : bhd.actual,
                      initial=isempty(bhd.initial_point_estimate) ? nothing : bhd.initial_point_estimate,
                      key_prefix="dsge_var_hd",
                      shock_names=bhd.shock_names)
    return bhd
end

# ── 1. `dsge abcd` Handlers (7 leaves) ──────────────────────

function _dsge_abcd_extract(; file::String="", model=nothing,
                            observables::String="", reduction::String="predetermined",
                            measurement_error::String="", tol::Float64=1e-10,
                            solver::String="gensys", order::Int=1,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd extract"
    tol > 0 || throw(CliError("usage/invalid-option", "$leaf: --tol must be > 0 (got $tol)"))
    obs = _w4_parse_observables(observables)
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_EXTRACT_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :predetermined, leaf)

    sys = try
        if src isa MacroEconometricModels.StateSpaceModel
            abcd_representation(src, obs; reduction=red, tol=tol)
        else
            abcd_representation(src, obs; measurement_error=me, reduction=red, tol=tol)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "ABCD extraction"))
    end

    _status("ABCD System: n_states=$(nstates(sys)), n_obs=$(nobservables(sys)), n_shocks=$(nshocks(sys))")
    _status_report(() -> report(sys))
    _maybe_plot(sys; plot=plot, plot_save=plot_save)
    _emit_result(sys; title="ABCD State-Space System (n=$(nstates(sys)), k=$(nobservables(sys)), m=$(nshocks(sys)))",
                 key="abcd_system", format=Symbol(format), output=output)
    return sys
end

function _w4_invertibility_extra_cols(inv_res::MacroEconometricModels.InvertibilityResult)
    return Pair{String,Any}[
        "n_states" => Int(inv_res.n_states),
        "n_obs"    => Int(inv_res.n_obs),
        "n_shocks" => Int(inv_res.n_shocks),
        "rank_D"   => Int(inv_res.rank_D),
    ]
end

function _dsge_abcd_invertibility(; file::String="", model=nothing, result=nothing,
                                  observables::String="", reduction::String="predetermined",
                                  measurement_error::String="", tol::Float64=1e-8,
                                  max_var_lags::Int=50,
                                  solver::String="gensys", order::Int=1,
                                  output::String="", format::String="table",
                                  plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd invertibility"
    if _w4_reject_result_conflicts(result, file, model, "", leaf) !== nothing
        _status_report(() -> report(result))
        _maybe_plot(result; plot=plot, plot_save=plot_save)
        _emit_result(result; title="FVRSW Poor Man's Invertibility Test ($(result.status))",
                     key="abcd_invertibility", format=Symbol(format), output=output,
                     extra_cols=_w4_invertibility_extra_cols(result))
        return result
    end
    tol >= 0 || throw(CliError("usage/invalid-option", "$leaf: --tol must be >= 0 (got $tol)"))
    max_var_lags >= 0 || throw(CliError("usage/invalid-option", "$leaf: --max-var-lags must be >= 0 (got $max_var_lags)"))
    obs = _w4_parse_observables(observables)
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_ABCD_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :predetermined, leaf)

    inv_res = try
        if src isa MacroEconometricModels.ABCDSystem
            sys = _w4_subset_abcd(src, obs, leaf)
            poor_mans_invertibility(sys; tol=tol, max_var_lags=max_var_lags)
        elseif src isa MacroEconometricModels.StateSpaceModel
            poor_mans_invertibility(src, obs; reduction=red, tol=tol, max_var_lags=max_var_lags)
        else
            poor_mans_invertibility(src, obs; measurement_error=me, reduction=red,
                                    tol=tol, max_var_lags=max_var_lags)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "FVRSW invertibility test"))
    end

    verdict = is_invertible(inv_res) ? "invertible" : "non-invertible"
    _status("Invertibility verdict: $verdict (status=$(inv_res.status), max_modulus=$(inv_res.max_modulus), " *
            "n_states=$(inv_res.n_states), n_obs=$(inv_res.n_obs), n_shocks=$(inv_res.n_shocks), rank_D=$(inv_res.rank_D))")
    _status_report(() -> report(inv_res))
    _maybe_plot(inv_res; plot=plot, plot_save=plot_save)
    _emit_result(inv_res; title="FVRSW Poor Man's Invertibility Test ($(inv_res.status))",
                 key="abcd_invertibility", format=Symbol(format), output=output,
                 extra_cols=_w4_invertibility_extra_cols(inv_res))
    return inv_res
end

function _dsge_abcd_innovations(; file::String="", model=nothing,
                                observables::String="", reduction::String="predetermined",
                                measurement_error::String="", rcond_tol::Float64=1e-12,
                                as_abcd::Bool=false,
                                solver::String="gensys", order::Int=1,
                                output::String="", format::String="table",
                                plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd innovations"
    rcond_tol > 0 || throw(CliError("usage/invalid-option", "$leaf: --rcond-tol must be > 0 (got $rcond_tol)"))
    obs = _w4_parse_observables(observables)
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_ABCD_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :predetermined, leaf)

    innov = try
        if src isa MacroEconometricModels.ABCDSystem
            sys = _w4_subset_abcd(src, obs, leaf)
            innovations_representation(sys; rcond_tol=rcond_tol)
        elseif src isa MacroEconometricModels.StateSpaceModel
            innovations_representation(src, obs; reduction=red, rcond_tol=rcond_tol)
        else
            innovations_representation(src, obs; measurement_error=me, reduction=red,
                                       rcond_tol=rcond_tol)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "Wold innovations representation"))
    end

    out_obj = as_abcd ? to_abcd(innov) : innov
    title = as_abcd ? "Wold Innovations Canonical ABCDSystem" :
                      "Hansen-Sargent Wold Innovations Representation"
    _status_report(() -> report(out_obj))
    _maybe_plot(out_obj; plot=plot, plot_save=plot_save)
    _emit_result(out_obj; title=title, key="abcd_innovations",
                 format=Symbol(format), output=output)
    return out_obj
end

function _dsge_abcd_recoverability(; file::String="", model=nothing, result=nothing,
                                   observables::String="", max_lead::Int=12,
                                   reduction::String="minimal", measurement_error::String="",
                                   rcond_tol::Float64=1e-12,
                                   solver::String="gensys", order::Int=1,
                                   output::String="", format::String="table",
                                   plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd recoverability"
    if _w4_reject_result_conflicts(result, file, model, "", leaf) !== nothing
        _status_report(() -> report(result))
        _maybe_plot(result; plot=plot, plot_save=plot_save)
        _emit_result(result; title="Shock Recoverability R^2_j(k) (max_lead=$(result.max_lead))",
                     key="abcd_recoverability", format=Symbol(format), output=output)
        return result
    end
    max_lead >= 0 || throw(CliError("usage/invalid-option", "$leaf: --max-lead must be >= 0 (got $max_lead)"))
    rcond_tol > 0 || throw(CliError("usage/invalid-option", "$leaf: --rcond-tol must be > 0 (got $rcond_tol)"))
    obs = _w4_parse_observables(observables)
    obs_kw = isempty(obs) ? nothing : obs
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_ABCD_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :minimal, leaf)

    rec = try
        if src isa MacroEconometricModels.ABCDSystem
            shock_recoverability(src; max_lead=max_lead, observables=obs_kw, rcond_tol=rcond_tol)
        elseif src isa MacroEconometricModels.StateSpaceModel
            shock_recoverability(src; max_lead=max_lead, observables=obs_kw,
                                 reduction=red, rcond_tol=rcond_tol)
        else
            shock_recoverability(src; max_lead=max_lead, observables=obs_kw,
                                 measurement_error=me, reduction=red, rcond_tol=rcond_tol)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "shock recoverability"))
    end

    _status_report(() -> report(rec))
    _maybe_plot(rec; plot=plot, plot_save=plot_save)
    _emit_result(rec; title="Shock Recoverability R^2_j(k) (max_lead=$max_lead)",
                 key="abcd_recoverability", format=Symbol(format), output=output)
    return rec
end

function _dsge_abcd_population_var(; file::String="", model=nothing,
                                   lags::Int=4, observables::String="",
                                   n_obs_effective::Int=1000, unit_root_damping::Float64=1e-5,
                                   reduction::String="minimal", measurement_error::String="",
                                   solver::String="gensys", order::Int=1,
                                   output::String="", format::String="table",
                                   plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd population-var"
    lags >= 1 || throw(CliError("usage/invalid-option", "$leaf: --lags must be >= 1 (got $lags)"))
    n_obs_effective >= 1 || throw(CliError("usage/invalid-option", "$leaf: --n-obs-effective must be >= 1 (got $n_obs_effective)"))
    (0.0 < unit_root_damping < 1.0) || throw(CliError("usage/invalid-option", "$leaf: --unit-root-damping must lie in (0, 1) (got $unit_root_damping)"))
    obs = _w4_parse_observables(observables)
    obs_kw = isempty(obs) ? nothing : obs
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_ABCD_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :minimal, leaf)

    pvar = try
        if src isa MacroEconometricModels.ABCDSystem
            population_var(src, lags; observables=obs_kw,
                           n_obs_effective=n_obs_effective,
                           unit_root_damping=unit_root_damping)
        elseif src isa MacroEconometricModels.StateSpaceModel
            population_var(src, lags; observables=obs_kw, reduction=red,
                           n_obs_effective=n_obs_effective,
                           unit_root_damping=unit_root_damping)
        else
            population_var(src, lags; observables=obs_kw, measurement_error=me,
                           reduction=red, n_obs_effective=n_obs_effective,
                           unit_root_damping=unit_root_damping)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "population VAR projection"))
    end

    _status("Population VAR($lags): $(length(pvar.varnames)) observable(s), T_eff=$n_obs_effective")
    _maybe_plot(pvar; plot=plot, plot_save=plot_save)
    _emit_result(pvar; title="Population VAR($lags) Projection Coefficients",
                 key="population_var", format=Symbol(format), output=output)
    return pvar
end

function _w4_build_sign_check_func(config_path::String, leaf::String)
    check_func, _ = _build_check_func(config_path)
    check_func !== nothing && return check_func
    cfg = load_config(config_path)
    id_tbl = get(cfg, "identification", Dict{String,Any}())
    raw_srs = get(id_tbl, "sign_restrictions", nothing)
    if raw_srs isa AbstractVector && !isempty(raw_srs)
        parsed = Tuple{Int,Int,Int,Int}[]
        for entry in raw_srs
            entry isa AbstractDict || throw(CliError("config/invalid",
                "$leaf: each [[identification.sign_restrictions]] entry must be a table"))
            v = Int(get(entry, "var", 0))
            s = Int(get(entry, "shock", 0))
            h = Int(get(entry, "horizon", 0))
            (v >= 1 && s >= 1 && h >= 0) || throw(CliError("config/invalid",
                "$leaf: sign_restrictions require var >= 1, shock >= 1, horizon >= 0"))
            sgn_raw = get(entry, "sign", 0)
            sgn = if sgn_raw isa Integer
                Int(sgn_raw)
            else
                ls = lowercase(strip(string(sgn_raw)))
                ls in ("positive", "+", "1", "+1") ? 1 :
                ls in ("negative", "-", "-1") ? -1 : 0
            end
            sgn in (-1, 1) || throw(CliError("config/invalid",
                "$leaf: sign_restrictions sign must be positive|negative|1|-1 (got '$sgn_raw')"))
            push!(parsed, (h + 1, v, s, sgn))
        end
        return function (irf_values)
            for (h1, v, s, sgn) in parsed
                h1 > size(irf_values, 1) && continue
                v > size(irf_values, 2) && continue
                s > size(irf_values, 3) && continue
                val = irf_values[h1, v, s]
                if sgn > 0 && val < 0
                    return false
                elseif sgn < 0 && val > 0
                    return false
                end
            end
            return true
        end
    end
    throw(CliError("config/invalid",
        "$leaf: --config '$config_path' contains no [identification.sign_matrix] or [[identification.sign_restrictions]]"))
end

function _dsge_abcd_audit_irf(; file::String="", model=nothing, result=nothing,
                              lags::Int=4, horizon::Int=20,
                              id::String="best-rotation", config::String="",
                              observables::String="",
                              n_obs_effective::Int=1000, unit_root_damping::Float64=1e-5,
                              rcond_tol::Float64=1e-12, max_draws::Int=1000,
                              reduction::String="minimal", measurement_error::String="",
                              solver::String="gensys", order::Int=1,
                              output::String="", format::String="table",
                              plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd audit-irf"
    if _w4_reject_result_conflicts(result, file, model, "", leaf) !== nothing
        return _w4_render_audit(result; format=format, output=output, plot=plot, plot_save=plot_save)
    end
    lags >= 1 || throw(CliError("usage/invalid-option", "$leaf: --lags must be >= 1 (got $lags)"))
    horizon >= 1 || throw(CliError("usage/invalid-option", "$leaf: --horizons must be >= 1 (got $horizon)"))
    max_draws >= 1 || throw(CliError("usage/invalid-option", "$leaf: --max-draws must be >= 1 (got $max_draws)"))
    id_map = Dict("best-rotation" => :best_rotation, "cholesky" => :cholesky,
                  "long-run" => :long_run, "sign" => :sign)
    haskey(id_map, id) || throw(CliError("usage/invalid-option",
        "$leaf: --id must be best-rotation|cholesky|long-run|sign (got '$id')"))
    id_sym = id_map[id]

    check_func = nothing
    if id_sym === :sign
        isempty(config) && throw(CliError("usage/missing",
            "$leaf: --id sign requires --config with [identification] sign restrictions"))
        check_func = _w4_build_sign_check_func(config, leaf)
    elseif !isempty(config)
        throw(CliError("usage/invalid-option",
            "$leaf: --config applies only to --id sign (got --id $id)"))
    end

    obs = _w4_parse_observables(observables)
    obs_kw = isempty(obs) ? nothing : obs
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_ABCD_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :minimal, leaf)

    audit = try
        if src isa MacroEconometricModels.ABCDSystem
            compare_dsge_svar_irf(src, lags, horizon;
                identification=id_sym, observables=obs_kw,
                n_obs_effective=n_obs_effective, unit_root_damping=unit_root_damping,
                rcond_tol=rcond_tol, check_func=check_func, max_draws=max_draws,
                _fwd_seed()...)
        elseif src isa MacroEconometricModels.StateSpaceModel
            compare_dsge_svar_irf(src, lags, horizon;
                identification=id_sym, observables=obs_kw, reduction=red,
                n_obs_effective=n_obs_effective, unit_root_damping=unit_root_damping,
                rcond_tol=rcond_tol, check_func=check_func, max_draws=max_draws,
                _fwd_seed()...)
        else
            compare_dsge_svar_irf(src, lags, horizon;
                identification=id_sym, observables=obs_kw, measurement_error=me,
                reduction=red, n_obs_effective=n_obs_effective,
                unit_root_damping=unit_root_damping, rcond_tol=rcond_tol,
                check_func=check_func, max_draws=max_draws, _fwd_seed()...)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-vs-SVAR IRF audit"))
    end

    return _w4_render_audit(audit; format=format, output=output, plot=plot, plot_save=plot_save)
end

function _dsge_abcd_search_observables(; file::String="", model=nothing, result=nothing,
                                       k::Int=0, candidates::String="", must_include::String="",
                                       target_shocks::String="", max_combinations::Int=2000,
                                       measurement_error::String="", reduction::String="minimal",
                                       tol::Float64=1e-8, rcond_tol::Float64=1e-12,
                                       solver::String="gensys", order::Int=1,
                                       output::String="", format::String="table",
                                       plot::Bool=false, plot_save::String="")
    leaf = "dsge abcd search-observables"
    if _w4_reject_result_conflicts(result, file, model, "", leaf) !== nothing
        _status_report(() -> report(result))
        _maybe_plot(result; plot=plot, plot_save=plot_save)
        _emit_result(result; title="Observable-Set Invertibility Search (k=$(result.k))",
                     key="abcd_observable_search", format=Symbol(format), output=output)
        return result
    end
    k >= 0 || throw(CliError("usage/invalid-option", "$leaf: --k must be >= 0 (0 = default nshocks; got $k)"))
    max_combinations >= 1 || throw(CliError("usage/invalid-option", "$leaf: --max-combinations must be >= 1 (got $max_combinations)"))
    tol >= 0 || throw(CliError("usage/invalid-option", "$leaf: --tol must be >= 0 (got $tol)"))
    rcond_tol > 0 || throw(CliError("usage/invalid-option", "$leaf: --rcond-tol must be > 0 (got $rcond_tol)"))

    cand_syms = _w4_parse_observables(candidates)
    must_syms = _w4_parse_observables(must_include)
    tshocks = _w4_parse_target_shocks(target_shocks)
    me = _w4_parse_measurement_error(measurement_error, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_ABCD_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _w4_guard_ss_measurement_error(src, me, leaf)
    red = _w4_reduction_for(src, reduction, :minimal, leaf)

    kw = Dict{Symbol,Any}(
        :must_include => must_syms,
        :max_combinations => max_combinations,
        :measurement_error => me,
        :reduction => red,
        :tol => tol,
        :rcond_tol => rcond_tol,
    )
    isempty(cand_syms) || (kw[:candidates] = cand_syms)
    tshocks === nothing || (kw[:target_shocks] = tshocks)

    res = try
        k == 0 ? search_invertible_observables(src; kw...) :
                 search_invertible_observables(src, k; kw...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "observable invertibility search"))
    end

    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="Observable-Set Invertibility Search (k=$(res.k), evaluated=$(res.n_evaluated))",
                 key="abcd_observable_search", format=Symbol(format), output=output)
    return res
end

# ── 2. `dsge var` Handlers (7 leaves) ───────────────────────

function _dsge_var_prior(; file::String="", model=nothing,
                         lags::Int=4, lambda::String="1.0", t_obs::Int=200,
                         observables::String="", no_intercept::Bool=false,
                         measurement_jitter::Float64=1e-8,
                         solver::String="gensys", order::Int=1,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    leaf = "dsge var prior"
    lags >= 1 || throw(CliError("usage/invalid-option", "$leaf: --lags must be >= 1 (got $lags)"))
    t_obs >= 1 || throw(CliError("usage/invalid-option", "$leaf: --t-obs must be >= 1 (got $t_obs)"))
    measurement_jitter >= 0 || throw(CliError("usage/invalid-option", "$leaf: --measurement-jitter must be >= 0 (got $measurement_jitter)"))
    lam = _w4_parse_lambda(lambda, leaf; allow_auto=false)
    obs = _w4_parse_observables(observables)
    obs_kw = isempty(obs) ? nothing : obs

    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_DSGEVAR_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)

    prior = try
        dsge_var_prior(src, lags, lam, t_obs;
            observables=obs_kw,
            include_intercept=!no_intercept,
            measurement_jitter=measurement_jitter)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR prior"))
    end

    _status_report(() -> report(prior))
    _maybe_plot(prior; plot=plot, plot_save=plot_save)
    _emit_result(prior; title="DSGE-VAR($lags) Prior (lambda=$lambda, T=$t_obs)",
                 key="dsge_var_prior", format=Symbol(format), output=output)
    return prior
end

function _dsge_var_lambda(; file::String="", model=nothing, result=nothing,
                          data::String="", lags::Int=4,
                          lambda::String="", lambda_grid::String="",
                          no_refine::Bool=false, no_intercept::Bool=false,
                          observables::String="", measurement_jitter::Float64=1e-8,
                          solver::String="gensys", order::Int=1,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    leaf = "dsge var lambda"
    if _w4_reject_result_conflicts(result, file, model, data, leaf) !== nothing
        _status_report(() -> report(result))
        _maybe_plot(result; plot=plot, plot_save=plot_save)
        _emit_result(result; title="DSGE-VAR($(result.p)) Marginal Likelihood Profile (lambda_hat=$(result.lambda_hat))",
                     key="dsge_var_lambda_profile", format=Symbol(format), output=output)
        return result
    end
    lags >= 1 || throw(CliError("usage/invalid-option", "$leaf: --lags must be >= 1 (got $lags)"))
    measurement_jitter >= 0 || throw(CliError("usage/invalid-option", "$leaf: --measurement-jitter must be >= 0 (got $measurement_jitter)"))
    !isempty(strip(lambda)) && !isempty(strip(lambda_grid)) && throw(CliError("usage/conflicting-options",
        "$leaf: pass either --lambda or --lambda-grid, not both"))

    obs = _w4_parse_observables(observables)
    obs_kw = isempty(obs) ? nothing : obs
    Y, _ = _w4_load_dsgevar_data(data, obs, leaf)
    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_DSGEVAR_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)

    prof = try
        if !isempty(strip(lambda))
            lam_val = _w4_parse_lambda(lambda, leaf; allow_auto=false)
            T_eff = size(Y, 1) - lags
            T_eff >= 1 || throw(ArgumentError("Not enough observations (T=$(size(Y, 1))) for p=$lags lags"))
            pr = dsge_var_prior(src, lags, lam_val, T_eff;
                                observables=obs_kw, include_intercept=!no_intercept,
                                measurement_jitter=measurement_jitter)
            lml = Float64(dsge_var_logml(pr, Y))
            lml_inf = isinf(lam_val) ? lml : Float64(dsge_var_logml(src, Y, lags, Inf;
                                                                    observables=obs_kw,
                                                                    include_intercept=!no_intercept,
                                                                    measurement_jitter=measurement_jitter))
            lams = isinf(lam_val) ? Float64[] : Float64[Float64(lam_val)]
            lmls = isinf(lam_val) ? Float64[] : Float64[lml]
            MacroEconometricModels.DSGEVARLambdaProfile{Float64}(
                lams, lmls, Float64(lam_val), lml, lml_inf,
                Float64(pr.lambda_min), lags, T_eff, copy(pr.obs_names))
        else
            grid = isempty(strip(lambda_grid)) ? nothing : _w4_parse_lambda_grid(lambda_grid, leaf)
            select_dsge_var_lambda(src, Y, lags;
                lambda_grid=grid, observables=obs_kw,
                refine=!no_refine, include_intercept=!no_intercept,
                measurement_jitter=measurement_jitter)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR lambda selection"))
    end

    _status("Optimal lambda_hat = $(prof.lambda_hat), log ML = $(round(prof.logml_hat; digits=4)) (dogmatic Inf = $(round(prof.logml_inf; digits=4)))")
    _status_report(() -> report(prof))
    _maybe_plot(prof; plot=plot, plot_save=plot_save)
    _emit_result(prof; title="DSGE-VAR($lags) Marginal Likelihood Profile (lambda_hat=$(prof.lambda_hat))",
                 key="dsge_var_lambda_profile", format=Symbol(format), output=output)
    return prof
end

"""Shared DSGE-VAR(λ) estimator used by `dsge var estimate` and inline `irf|fevd|hd|forecast`."""
function _w4_run_dsge_var_estimate(; file::String="", model=nothing,
                                   data::String="", lags::Int=4,
                                   lambda::String="auto", n_draws::Int=1000,
                                   priors::String="", prior::Vector{String}=String[],
                                   method::String="rwmh", burnin::Int=150,
                                   n_particles::Int=150, step_scale::Float64=0.05,
                                   observables::String="", no_intercept::Bool=false,
                                   measurement_jitter::Float64=1e-8,
                                   solver::String="gensys", order::Int=1,
                                   leaf::String="dsge var estimate")
    lags >= 1 || throw(CliError("usage/invalid-option", "$leaf: --lags must be >= 1 (got $lags)"))
    n_draws >= 1 || throw(CliError("usage/invalid-option", "$leaf: --draws must be >= 1 (got $n_draws)"))
    burnin >= 0 || throw(CliError("usage/invalid-option", "$leaf: --burnin must be >= 0 (got $burnin)"))
    n_particles >= 1 || throw(CliError("usage/invalid-option", "$leaf: --n-particles must be >= 1 (got $n_particles)"))
    step_scale > 0 || throw(CliError("usage/invalid-option", "$leaf: --step-scale must be > 0 (got $step_scale)"))
    measurement_jitter >= 0 || throw(CliError("usage/invalid-option", "$leaf: --measurement-jitter must be >= 0 (got $measurement_jitter)"))
    method in ("rwmh", "smc") || throw(CliError("usage/invalid-option",
        "$leaf: --method must be rwmh|smc (got '$method')"))

    lam_arg = _w4_parse_lambda(lambda, leaf; allow_auto=true)
    obs = _w4_parse_observables(observables)
    obs_kw = isempty(obs) ? nothing : obs
    Y, _ = _w4_load_dsgevar_data(data, obs, leaf)

    stanzas = (!isempty(file) && !_w4_is_handle_arg(file)) ?
        _model_card_stanza_policy(_model_card_stanzas_for(file);
                                  allow_priors=true, allow_constraints=false) :
        Dict{Symbol,Any}()
    has_priors = !isempty(priors) || !isempty(prior) || haskey(stanzas, :priors)

    if has_priors
        if model !== nothing && !(model isa MacroEconometricModels.ModelSpec)
            throw(CliError("usage/conflicting-options",
                "$leaf: --priors/--prior requires a DSGE model file (.toml/.jl) or ModelSpec handle, not $(nameof(typeof(model)))"))
        end
        spec = _w4_resolve_dsge_source(file, model; allowed_types=[:ModelSpec],
                                       solver=solver, order=order,
                                       allow_priors=true, keep_spec=true, leaf=leaf)
        priors_dict = _dsge_prior_distributions(_resolve_dsge_priors(priors, prior; stanzas=stanzas))
        solver_sym = Symbol(replace(solver, "-" => "_"))
        solver_kwargs = order > 1 ? (order=order,) : NamedTuple()
        _status("Estimating joint Bayesian DSGE-VAR($lags): method=$method, lambda=$lambda, draws=$n_draws")
        post = try
            _dsge_call(estimate_dsge_var, spec, Y, lags;
                priors=priors_dict,
                lambda=lam_arg,
                method=Symbol(method),
                observables=obs_kw,
                include_intercept=!no_intercept,
                measurement_jitter=measurement_jitter,
                n_draws=n_draws,
                burnin=burnin,
                n_particles=n_particles,
                step_scale=step_scale,
                solver=solver_sym,
                solver_kwargs=solver_kwargs,
                _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, "joint Bayesian DSGE-VAR estimation"))
        end
        return post
    end

    src = _w4_resolve_dsge_source(file, model; allowed_types=_W4_DSGEVAR_INPUT_TYPES,
                                  solver=solver, order=order, leaf=leaf)
    _status("Estimating fixed-parameter DSGE-VAR($lags): lambda=$lambda, draws=$n_draws")
    post = try
        estimate_dsge_var(src, Y, lags;
            lambda=lam_arg,
            observables=obs_kw,
            include_intercept=!no_intercept,
            measurement_jitter=measurement_jitter,
            n_draws=n_draws,
            _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR estimation"))
    end
    return post
end

function _dsge_var_estimate(; file::String="", model=nothing,
                            data::String="", lags::Int=4,
                            lambda::String="auto", n_draws::Int=1000,
                            priors::String="", prior::Vector{String}=String[],
                            method::String="rwmh", burnin::Int=150,
                            n_particles::Int=150, step_scale::Float64=0.05,
                            observables::String="", no_intercept::Bool=false,
                            measurement_jitter::Float64=1e-8,
                            solver::String="gensys", order::Int=1,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
    post = _w4_run_dsge_var_estimate(;
        file, model, data, lags, lambda, n_draws, priors, prior, method,
        burnin, n_particles, step_scale, observables, no_intercept,
        measurement_jitter, solver, order, leaf="dsge var estimate")
    _status("DSGE-VAR($(post.p)) posterior: method=$(post.method), lambda=$(post.lambda), log ML=$(round(post.log_marginal_likelihood; digits=4)), draws=$(post.n_draws)")
    _status_report(() -> report(post))
    _maybe_plot(post; plot=plot, plot_save=plot_save)
    _emit_result(post; title="Bayesian DSGE-VAR($(post.p)) Posterior (lambda=$(post.lambda), method=$(post.method))",
                 key="dsge_var_posterior", format=Symbol(format), output=output)
    return post
end

function _w4_resolve_dsge_var_posterior(; file::String="", model=nothing,
                                        data::String="", lags::Int=4,
                                        lambda::String="auto", n_draws::Int=1000,
                                        priors::String="", prior::Vector{String}=String[],
                                        method::String="rwmh", burnin::Int=150,
                                        n_particles::Int=150, step_scale::Float64=0.05,
                                        observables::String="", no_intercept::Bool=false,
                                        measurement_jitter::Float64=1e-8,
                                        solver::String="gensys", order::Int=1,
                                        allow_extra_data::Bool=false,
                                        leaf::String="dsge var")
    if model isa MacroEconometricModels.DSGEVARPosterior
        !isempty(file) && throw(CliError("usage/conflicting-options",
            "$leaf: pass either a positional model file or --model, not both"))
        if !allow_extra_data && !isempty(data)
            throw(CliError("usage/conflicting-options",
                "$leaf: --data cannot be combined with a saved DSGEVARPosterior --model handle"))
        end
        return model
    end
    if isempty(file) && model === nothing
        throw(CliError("usage/missing",
            "$leaf: pass --model <DSGEVARPosterior.jld2> or a DSGE model + --data for inline estimation"))
    end
    if !isempty(file) && model === nothing && _w4_is_handle_arg(file)
        resolved = resolve_stem(file; slot=:result)
        obj = _load_typed_handle(resolved, _W4_DSGEVAR_POST_INPUT_TYPES, "model/wrong-kind"; slot="model")
        if obj isa MacroEconometricModels.DSGEVARPosterior
            if !allow_extra_data && !isempty(data)
                throw(CliError("usage/conflicting-options",
                    "$leaf: --data cannot be combined with a saved DSGEVARPosterior handle"))
            end
            return obj
        end
        model = obj
        file = ""
    end
    return _w4_run_dsge_var_estimate(;
        file, model, data, lags, lambda, n_draws, priors, prior, method,
        burnin, n_particles, step_scale, observables, no_intercept,
        measurement_jitter, solver, order, leaf=leaf)
end

function _w4_parse_dsgevar_id(id::String, leaf::String)::Symbol
    id_map = Dict("dsge-qr" => :dsge_qr, "cholesky" => :cholesky, "long-run" => :long_run)
    haskey(id_map, id) || throw(CliError("usage/invalid-option",
        "$leaf: --id must be dsge-qr|cholesky|long-run (got '$id')"))
    return id_map[id]
end

function _dsge_var_irf(; file::String="", model=nothing, result=nothing,
                       data::String="", lags::Int=4,
                       id::String="dsge-qr", horizon::Int=20, shock::Int=0,
                       quantiles::String="0.16,0.5,0.84", point_estimate::String="mean",
                       lambda::String="auto", n_draws::Int=1000,
                       priors::String="", prior::Vector{String}=String[],
                       method::String="rwmh", burnin::Int=150,
                       n_particles::Int=150, step_scale::Float64=0.05,
                       observables::String="", no_intercept::Bool=false,
                       measurement_jitter::Float64=1e-8,
                       solver::String="gensys", order::Int=1,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="")
    leaf = "dsge var irf"
    if _w4_reject_result_conflicts(result, file, model, data, leaf) !== nothing
        shock_filter = if shock > 0
            shock <= length(result.shocks) || throw(CliError("usage/invalid-option",
                "$leaf: --shock $shock out of 1:$(length(result.shocks))"))
            result.shocks[shock]
        else
            nothing
        end
        _maybe_plot(result; plot=plot, plot_save=plot_save)
        _emit_result(result; title="DSGE-VAR Impulse Responses", key="dsge_var_irf",
                     format=Symbol(format), output=output, shocks=shock_filter)
        return result
    end
    horizon >= 1 || throw(CliError("usage/invalid-option", "$leaf: --horizons must be >= 1 (got $horizon)"))
    shock >= 0 || throw(CliError("usage/invalid-option", "$leaf: --shock must be >= 0 (0 = all shocks; got $shock)"))
    id_sym = _w4_parse_dsgevar_id(id, leaf)
    q_vec = _w4_parse_quantiles(quantiles, leaf)
    pe_sym = Symbol(point_estimate)
    pe_sym in (:mean, :median) || throw(CliError("usage/invalid-option",
        "$leaf: --point-estimate must be mean|median (got '$point_estimate')"))

    post = _w4_resolve_dsge_var_posterior(;
        file, model, data, lags, lambda, n_draws, priors, prior, method,
        burnin, n_particles, step_scale, observables, no_intercept,
        measurement_jitter, solver, order, allow_extra_data=false, leaf=leaf)

    birf = try
        irf(post, horizon; method=id_sym, quantiles=q_vec, point_estimate=pe_sym)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR IRF"))
    end

    shock_filter = if shock > 0
        shock <= length(birf.shocks) || throw(CliError("usage/invalid-option",
            "$leaf: --shock $shock out of 1:$(length(birf.shocks))"))
        birf.shocks[shock]
    else
        nothing
    end
    _status_report(() -> report(birf))
    _maybe_plot(birf; plot=plot, plot_save=plot_save)
    _emit_result(birf; title="DSGE-VAR($(post.p)) Impulse Responses ($id, h=$horizon)",
                 key="dsge_var_irf", format=Symbol(format), output=output,
                 shocks=shock_filter)
    return (; model=post, result=birf)
end

function _dsge_var_fevd(; file::String="", model=nothing, result=nothing,
                        data::String="", lags::Int=4,
                        id::String="dsge-qr", horizon::Int=20,
                        quantiles::String="0.16,0.5,0.84", point_estimate::String="mean",
                        lambda::String="auto", n_draws::Int=1000,
                        priors::String="", prior::Vector{String}=String[],
                        method::String="rwmh", burnin::Int=150,
                        n_particles::Int=150, step_scale::Float64=0.05,
                        observables::String="", no_intercept::Bool=false,
                        measurement_jitter::Float64=1e-8,
                        solver::String="gensys", order::Int=1,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    leaf = "dsge var fevd"
    if _w4_reject_result_conflicts(result, file, model, data, leaf) !== nothing
        return _w4_render_dsge_var_fevd(result; format=format, output=output,
                                        plot=plot, plot_save=plot_save)
    end
    horizon >= 1 || throw(CliError("usage/invalid-option", "$leaf: --horizons must be >= 1 (got $horizon)"))
    id_sym = _w4_parse_dsgevar_id(id, leaf)
    q_vec = _w4_parse_quantiles(quantiles, leaf)
    pe_sym = Symbol(point_estimate)
    pe_sym in (:mean, :median) || throw(CliError("usage/invalid-option",
        "$leaf: --point-estimate must be mean|median (got '$point_estimate')"))

    post = _w4_resolve_dsge_var_posterior(;
        file, model, data, lags, lambda, n_draws, priors, prior, method,
        burnin, n_particles, step_scale, observables, no_intercept,
        measurement_jitter, solver, order, allow_extra_data=false, leaf=leaf)

    bfevd = try
        fevd(post, horizon; method=id_sym, quantiles=q_vec, point_estimate=pe_sym)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR FEVD"))
    end

    _w4_render_dsge_var_fevd(bfevd; id=id, format=format, output=output,
                             plot=plot, plot_save=plot_save)
    return (; model=post, result=bfevd)
end

function _dsge_var_hd(; file::String="", model=nothing, result=nothing,
                      data::String="", lags::Int=4,
                      id::String="dsge-qr", horizon::Int=0,
                      quantiles::String="0.16,0.5,0.84", point_estimate::String="mean",
                      lambda::String="auto", n_draws::Int=1000,
                      priors::String="", prior::Vector{String}=String[],
                      method::String="rwmh", burnin::Int=150,
                      n_particles::Int=150, step_scale::Float64=0.05,
                      observables::String="", no_intercept::Bool=false,
                      measurement_jitter::Float64=1e-8,
                      solver::String="gensys", order::Int=1,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    leaf = "dsge var hd"
    if _w4_reject_result_conflicts(result, file, model, data, leaf) !== nothing
        return _w4_render_dsge_var_hd(result; format=format, output=output,
                                      plot=plot, plot_save=plot_save)
    end
    horizon >= 0 || throw(CliError("usage/invalid-option", "$leaf: --horizons must be >= 0 (0 = full sample; got $horizon)"))
    id_sym = _w4_parse_dsgevar_id(id, leaf)
    q_vec = _w4_parse_quantiles(quantiles, leaf)
    pe_sym = Symbol(point_estimate)
    pe_sym in (:mean, :median) || throw(CliError("usage/invalid-option",
        "$leaf: --point-estimate must be mean|median (got '$point_estimate')"))

    passed_post = model isa MacroEconometricModels.DSGEVARPosterior
    post = _w4_resolve_dsge_var_posterior(;
        file, model, data, lags, lambda, n_draws, priors, prior, method,
        burnin, n_particles, step_scale, observables, no_intercept,
        measurement_jitter, solver, order, allow_extra_data=true, leaf=leaf)

    # Mirror upstream default: if user didn't explicitly pass --id on a rectangular system, fall back to :cholesky
    if id_sym === :dsge_qr && size(post.B0_draws, 3) != post.n &&
       !(isdefined(@__MODULE__, :_CURRENT_EXPLICIT_OPTS) && ("id" in _CURRENT_EXPLICIT_OPTS[]))
        id_sym = :cholesky
        id = "cholesky"
    end

    extra_data_kw = if passed_post && !isempty(data)
        obs = _w4_parse_observables(observables)
        Y_hd, _ = _w4_load_dsgevar_data(data, obs, leaf)
        (; data=Y_hd)
    else
        NamedTuple()
    end

    bhd = try
        historical_decomposition(post, horizon;
            method=id_sym, quantiles=q_vec, point_estimate=pe_sym,
            extra_data_kw..., _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR historical decomposition"))
    end

    _w4_render_dsge_var_hd(bhd; id=id, format=format, output=output,
                           plot=plot, plot_save=plot_save)
    return (; model=post, result=bhd)
end

function _dsge_var_forecast(; file::String="", model=nothing, result=nothing,
                            data::String="", lags::Int=4,
                            horizon::Int=12,
                            quantiles::String="0.16,0.5,0.84",
                            conf_level::Float64=0.0,
                            point_estimate::String="mean",
                            lambda::String="auto", n_draws::Int=1000,
                            priors::String="", prior::Vector{String}=String[],
                            method::String="rwmh", burnin::Int=150,
                            n_particles::Int=150, step_scale::Float64=0.05,
                            observables::String="", no_intercept::Bool=false,
                            measurement_jitter::Float64=1e-8,
                            solver::String="gensys", order::Int=1,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
    leaf = "dsge var forecast"
    if _w4_reject_result_conflicts(result, file, model, data, leaf) !== nothing
        _maybe_plot(result; plot=plot, plot_save=plot_save)
        _emit_result(result; title="DSGE-VAR Forecast", key="dsge_var_forecast",
                     format=Symbol(format), output=output)
        return result
    end
    horizon >= 1 || throw(CliError("usage/invalid-option", "$leaf: --horizons must be >= 1 (got $horizon)"))
    pe_sym = Symbol(point_estimate)
    pe_sym in (:mean, :median) || throw(CliError("usage/invalid-option",
        "$leaf: --point-estimate must be mean|median (got '$point_estimate')"))
    q_vec = _w4_parse_quantiles(quantiles, leaf)
    eff_conf = if conf_level > 0.0
        (0.0 < conf_level < 1.0) || throw(CliError("usage/invalid-option",
            "$leaf: --conf-level must lie in (0, 1) (got $conf_level)"))
        conf_level
    elseif length(q_vec) >= 2 && (last(q_vec) - first(q_vec)) > 0.0
        clamp(last(q_vec) - first(q_vec), 0.01, 0.999)
    else
        0.68
    end

    post = _w4_resolve_dsge_var_posterior(;
        file, model, data, lags, lambda, n_draws, priors, prior, method,
        burnin, n_particles, step_scale, observables, no_intercept,
        measurement_jitter, solver, order, allow_extra_data=false, leaf=leaf)

    fc = try
        forecast(post, horizon; conf_level=eff_conf, point_estimate=pe_sym, _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "DSGE-VAR forecast"))
    end

    _maybe_plot(fc; plot=plot, plot_save=plot_save)
    _emit_result(fc; title="DSGE-VAR($(post.p)) Forecast (h=$horizon, $(round(Int, 100 * eff_conf))% credible interval)",
                 key="dsge_var_forecast", format=Symbol(format), output=output)
    return (; model=post, result=fc)
end

# ── Shared Option Lists & CommandSpecs ──────────────────────

const _W4_FILE_ARG = ArgSpec(
    name="file", type=String, required=false, default="",
    description="Path to DSGE model file (.toml or .jl) or saved handle (.jld2/.jls/.fmod)",
)

const _W4_SOLVER_OPTIONS = [
    OptionSpec(name="solver", type=String, default="gensys",
               choices=_W4_SOLVER_CHOICES,
               description="DSGE linear solver when given a model file: gensys|klein|perturbation|blanchard-kahn"),
    OptionSpec(name="order", type=Int, default=1,
               description="Perturbation order when --solver perturbation (1, 2, or 3)"),
]

const _W4_DSGEVAR_INLINE_OPTIONS = [
    OptionSpec(name="data", short="d", type=String, default="",
               description="Path to data file or handle stem (.csv, .jld2, .jls)"),
    OptionSpec(name="lags", short="p", type=Int, default=4,
               description="VAR lag order p (>= 1)"),
    OptionSpec(name="lambda", type=String, default="auto",
               description="DSGE prior weight: auto, positive float >= lambda_min, or inf"),
    OptionSpec(name="draws", aliases=["n-draws"], kwarg=:n_draws, type=Int, default=1000,
               description="Number of posterior draws"),
    OptionSpec(name="priors", type=String, default="",
               description="Path to priors TOML file (enables full Bayesian ModelSpec route)"),
    PRIOR_OPTION,
    OptionSpec(name="method", type=String, default="rwmh", choices=["rwmh", "smc"],
               description="Joint-mode posterior sampler over DSGE parameters: rwmh|smc"),
    OptionSpec(name="burnin", type=Int, default=150,
               description="Burn-in draws for RWMH (joint mode)"),
    OptionSpec(name="n-particles", type=Int, default=150,
               description="SMC particle count for --method smc (joint mode)"),
    OptionSpec(name="step-scale", type=Float64, default=0.05,
               description="RWMH proposal step scale in unconstrained space (joint mode)"),
    OptionSpec(name="observables", type=String, default="",
               description="Observable variable names (comma-separated)"),
    OptionSpec(name="measurement-jitter", type=Float64, default=1e-8,
               description="Minimal diagonal regularization when n > m or singular"),
    _W4_SOLVER_OPTIONS...,
]

function w4_dsge_specs()::Vector{CommandSpec}
    specs = CommandSpec[
        # ── dsge abcd * (7 leaves) ──
        CommandSpec(
            path=["dsge", "abcd", "extract"],
            summary="Extract the canonical FVRSW (2007) ABCD state-space representation from a DSGE or StateSpace model",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated; empty = all observables)"),
                OptionSpec(name="reduction", type=String, default="predetermined",
                           choices=["predetermined", "minimal", "none"],
                           description="State-space reduction mode: predetermined|minimal|none"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                OptionSpec(name="tol", type=Float64, default=1e-10,
                           description="Tolerance for predetermined-column detection and staircase SVD"),
                _W4_SOLVER_OPTIONS...,
                SAVE_MODEL_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:abcd_system,
                              description="Canonical ABCD state-space eigenvalues and system dimensions (n_states, n_obs, n_shocks)")],
            category="dsge",
            model_types=_W4_EXTRACT_INPUT_TYPES,
            handler=wrap_legacy(_dsge_abcd_extract),
        ),
        CommandSpec(
            path=["dsge", "abcd", "invertibility"],
            summary="Evaluate FVRSW (2007) Poor Man's Invertibility Condition and Komunjer-Ng (2011) transmission zeros",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="reduction", type=String, default="predetermined",
                           choices=["predetermined", "minimal", "none"],
                           description="State-space reduction mode: predetermined|minimal|none"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                OptionSpec(name="tol", type=Float64, default=1e-8,
                           description="Unit-circle classification tolerance (>= 0)"),
                OptionSpec(name="max-var-lags", type=Int, default=50,
                           description="Maximum convergent VAR(inf) lag matrices to compute when invertible"),
                _W4_SOLVER_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:abcd_invertibility,
                              description="Finite eigenvalues / transmission zeros, spectral radius, status, invertibility verdict, and ABCD dimensions (n_states, n_obs, n_shocks, rank_D)")],
            category="dsge",
            model_types=_W4_ABCD_INPUT_TYPES,
            result_types=[:InvertibilityResult],
            handler=wrap_legacy(_dsge_abcd_invertibility),
        ),
        CommandSpec(
            path=["dsge", "abcd", "innovations"],
            summary="Compute the Hansen-Sargent DARE Wold innovations representation (and optional canonical ABCDSystem)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="reduction", type=String, default="predetermined",
                           choices=["predetermined", "minimal", "none"],
                           description="State-space reduction mode: predetermined|minimal|none"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                OptionSpec(name="rcond-tol", type=Float64, default=1e-12,
                           description="Conditioning threshold for the generalized Schur DARE solver"),
                _W4_SOLVER_OPTIONS...,
                SAVE_MODEL_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="as-abcd", description="Convert the InnovationsRepresentation to a canonical ABCDSystem via to_abcd"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:abcd_innovations,
                              description="Steady-state Kalman gain entries, DARE residual, and invertibility flag (or ABCD eigenvalues with --as-abcd)")],
            category="dsge",
            model_types=_W4_ABCD_INPUT_TYPES,
            handler=wrap_legacy(_dsge_abcd_innovations),
        ),
        CommandSpec(
            path=["dsge", "abcd", "recoverability"],
            summary="Compute Sims (2012) / Forni-Gambetti-Sala shock recoverability R^2_j(k) across lead horizons",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="max-lead", type=Int, default=12,
                           description="Maximum future observable lead horizon k (>= 0)"),
                OptionSpec(name="reduction", type=String, default="minimal",
                           choices=["minimal", "predetermined", "none"],
                           description="State-space reduction mode: minimal|predetermined|none"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                OptionSpec(name="rcond-tol", type=Float64, default=1e-12,
                           description="Conditioning threshold for the Wold innovations DARE solver"),
                _W4_SOLVER_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:abcd_recoverability,
                              description="Shock recoverability R^2_j(k) by lead horizon and structural shock")],
            category="dsge",
            model_types=_W4_ABCD_INPUT_TYPES,
            result_types=[:ShockRecoverabilityResult],
            handler=wrap_legacy(_dsge_abcd_recoverability),
        ),
        CommandSpec(
            path=["dsge", "abcd", "population-var"],
            summary="Compute the exact population VAR(p) Yule-Walker projection of a DSGE or ABCD system",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="lags", short="p", type=Int, default=4,
                           description="Population VAR lag order p (>= 1)"),
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="n-obs-effective", type=Int, default=1000,
                           description="Effective sample size carried by the population VARModel"),
                OptionSpec(name="unit-root-damping", type=Float64, default=1e-5,
                           description="Stationary damping applied when A contains unit roots"),
                OptionSpec(name="reduction", type=String, default="minimal",
                           choices=["minimal", "predetermined", "none"],
                           description="State-space reduction mode: minimal|predetermined|none"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                _W4_SOLVER_OPTIONS...,
                SAVE_MODEL_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:population_var,
                              description="Population VAR(p) coefficient estimates in tidy format")],
            category="dsge",
            model_types=_W4_ABCD_INPUT_TYPES,
            handler=wrap_legacy(_dsge_abcd_population_var),
        ),
        CommandSpec(
            path=["dsge", "abcd", "audit-irf"],
            summary="Audit DSGE true IRFs against Wold innovations and population SVAR(p) IRFs (Ravenna 2007 three-way wedges)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="lags", short="p", type=Int, default=4,
                           description="Population VAR lag order p (>= 1)"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=20,
                           description="IRF horizon H (>= 1)"),
                OptionSpec(name="id", type=String, default="best-rotation",
                           choices=["best-rotation", "cholesky", "long-run", "sign"],
                           description="SVAR identification scheme: best-rotation|cholesky|long-run|sign"),
                OptionSpec(name="config", type=String, default="",
                           description="TOML identification config with sign restrictions (required for --id sign)"),
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="n-obs-effective", type=Int, default=1000,
                           description="Effective sample size for population VAR(p)"),
                OptionSpec(name="unit-root-damping", type=Float64, default=1e-5,
                           description="Stationary damping applied when A contains unit roots"),
                OptionSpec(name="rcond-tol", type=Float64, default=1e-12,
                           description="Conditioning threshold for the Wold innovations DARE solver"),
                OptionSpec(name="max-draws", type=Int, default=1000,
                           description="Maximum Haar draws for --id sign"),
                OptionSpec(name="reduction", type=String, default="minimal",
                           choices=["minimal", "predetermined", "none"],
                           description="State-space reduction mode: minimal|predetermined|none"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                _W4_SOLVER_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[
                TableSpec(name=:dsge_var_irf_audit,
                          description="Three-way IRF comparison across horizon, variable, and shock (DSGE, Wold best/id, SVAR(p))"),
                TableSpec(name=:dsge_var_irf_wedges,
                          description="Per-horizon RMSE decomposition into non-invertibility, truncation, and identification wedges"),
            ],
            category="dsge",
            model_types=_W4_ABCD_INPUT_TYPES,
            result_types=[:DSGEVARIRFAudit],
            handler=wrap_legacy(_dsge_abcd_audit_irf),
        ),
        CommandSpec(
            path=["dsge", "abcd", "search-observables"],
            summary="Search and rank candidate k-element observable subsets by invertibility and shock recoverability",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="k", type=Int, default=0,
                           description="Observable subset size k (0 = default nshocks)"),
                OptionSpec(name="candidates", type=String, default="",
                           description="Candidate observable variable names (comma-separated; empty = all model observables)"),
                OptionSpec(name="must-include", type=String, default="",
                           description="Observables required in every candidate subset (comma-separated)"),
                OptionSpec(name="target-shocks", type=String, default="",
                           description="Target structural shock names or 1-based indices to score (comma-separated)"),
                OptionSpec(name="max-combinations", type=Int, default=2000,
                           description="Maximum exhaustive combinations before greedy/beam search fallback"),
                OptionSpec(name="measurement-error", type=String, default="",
                           description="Measurement error standard deviations (comma-separated)"),
                OptionSpec(name="reduction", type=String, default="minimal",
                           choices=["minimal", "predetermined", "none"],
                           description="State-space reduction mode: minimal|predetermined|none"),
                OptionSpec(name="tol", type=Float64, default=1e-8,
                           description="Unit-circle classification tolerance"),
                OptionSpec(name="rcond-tol", type=Float64, default=1e-12,
                           description="Conditioning threshold for shock recoverability"),
                _W4_SOLVER_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:abcd_observable_search,
                              description="Ranked candidate observable subsets by invertibility, min/mean R^2(0), spectral radius, and cond(D)")],
            category="dsge",
            model_types=_W4_ABCD_INPUT_TYPES,
            result_types=[:ObservableSearchResult],
            handler=wrap_legacy(_dsge_abcd_search_observables),
        ),

        # ── dsge var * (7 leaves) ──
        CommandSpec(
            path=["dsge", "var", "prior"],
            summary="Construct the Del Negro-Schorfheide (2004) Normal-Inverse-Wishart DSGE-VAR(lambda) prior",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="lags", short="p", type=Int, default=4,
                           description="VAR lag order p (>= 1)"),
                OptionSpec(name="lambda", type=String, default="1.0",
                           description="DSGE prior weight (>= lambda_min, or inf for dogmatic DSGE limit)"),
                OptionSpec(name="t-obs", type=Int, default=200,
                           description="Effective VAR sample size T_obs (>= 1)"),
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="measurement-jitter", type=Float64, default=1e-8,
                           description="Minimal diagonal regularization when n > m or singular"),
                _W4_SOLVER_OPTIONS...,
                SAVE_MODEL_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Exclude the constant intercept from the VAR design matrix"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_prior,
                              description="Population VAR projection Phi*, prior weight lambda, and minimum proper-prior threshold lambda_min")],
            category="dsge",
            model_types=_W4_DSGEVAR_INPUT_TYPES,
            handler=wrap_legacy(_dsge_var_prior),
        ),
        CommandSpec(
            path=["dsge", "var", "lambda"],
            summary="Profile the closed-form DSGE-VAR(lambda) log marginal likelihood and select optimal lambda_hat",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="data", short="d", type=String, default="",
                           description="Path to data file or handle stem (.csv, .jld2, .jls)"),
                OptionSpec(name="lags", short="p", type=Int, default=4,
                           description="VAR lag order p (>= 1)"),
                OptionSpec(name="lambda", type=String, default="",
                           description="Single lambda value (or inf) to evaluate directly via dsge_var_logml"),
                OptionSpec(name="lambda-grid", type=String, default="",
                           description="Comma-separated candidate lambda grid values"),
                OptionSpec(name="observables", type=String, default="",
                           description="Observable variable names (comma-separated)"),
                OptionSpec(name="measurement-jitter", type=Float64, default=1e-8,
                           description="Minimal diagonal regularization when n > m or singular"),
                _W4_SOLVER_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-refine", description="Disable Brent refinement around the best finite grid point"),
                FlagSpec(name="no-intercept", description="Exclude the constant intercept from the VAR design matrix"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_lambda_profile,
                              description="Closed-form log marginal likelihood across lambda values with optimal lambda_hat and dogmatic limit")],
            category="dsge",
            data_kinds=[:timeseries, :csv],
            model_types=_W4_DSGEVAR_INPUT_TYPES,
            result_types=[:DSGEVARLambdaProfile],
            allow_data_with_model=true,
            handler=wrap_legacy(_dsge_var_lambda),
        ),
        CommandSpec(
            path=["dsge", "var", "estimate"],
            summary="Estimate a Bayesian DSGE-VAR(lambda) posterior (fixed-parameter conjugate NIW or joint hierarchical ModelSpec)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                _W4_DSGEVAR_INLINE_OPTIONS...,
                SAVE_MODEL_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Exclude the constant intercept from the VAR design matrix"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_posterior,
                              description="Bayesian DSGE-VAR(lambda) posterior parameter summary (mean, std, 5%/50%/95% quantiles)")],
            category="dsge",
            data_kinds=[:timeseries, :csv],
            model_types=_W4_DSGEVAR_INPUT_TYPES,
            allow_data_with_model=true,
            handler=wrap_legacy(_dsge_var_estimate),
        ),
        CommandSpec(
            path=["dsge", "var", "irf"],
            summary="Compute Bayesian structural impulse responses from a DSGE-VAR(lambda) posterior (or inline estimation)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="id", type=String, default="dsge-qr",
                           choices=["dsge-qr", "cholesky", "long-run"],
                           description="Structural identification: dsge-qr|cholesky|long-run"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=20,
                           description="IRF horizon H (>= 1)"),
                OptionSpec(name="shock", type=Int, default=0,
                           description="Filter output to 1-based shock index (0 = all shocks)"),
                OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
                           description="Comma-separated posterior credible quantiles in (0, 1)"),
                OptionSpec(name="point-estimate", type=String, default="mean",
                           choices=["mean", "median"],
                           description="Central posterior summary: mean|median"),
                _W4_DSGEVAR_INLINE_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Exclude the constant intercept when estimating inline"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_irf,
                              description="Bayesian DSGE-VAR(lambda) impulse responses with posterior credible bands")],
            category="dsge",
            data_kinds=[:timeseries, :csv],
            model_types=_W4_DSGEVAR_POST_INPUT_TYPES,
            result_types=[:BayesianImpulseResponse],
            allow_data_with_model=true,
            handler=wrap_legacy(_dsge_var_irf),
        ),
        CommandSpec(
            path=["dsge", "var", "fevd"],
            summary="Compute Bayesian forecast error variance decomposition from a DSGE-VAR(lambda) posterior (or inline estimation)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="id", type=String, default="dsge-qr",
                           choices=["dsge-qr", "cholesky", "long-run"],
                           description="Structural identification: dsge-qr|cholesky|long-run"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=20,
                           description="FEVD horizon H (>= 1)"),
                OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
                           description="Comma-separated posterior credible quantiles in (0, 1)"),
                OptionSpec(name="point-estimate", type=String, default="mean",
                           choices=["mean", "median"],
                           description="Central posterior summary: mean|median"),
                _W4_DSGEVAR_INLINE_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Exclude the constant intercept when estimating inline"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_fevd,
                              description="Bayesian DSGE-VAR(lambda) variance shares by shock across horizons, one table per variable",
                              family=true)],
            category="dsge",
            data_kinds=[:timeseries, :csv],
            model_types=_W4_DSGEVAR_POST_INPUT_TYPES,
            result_types=[:BayesianFEVD],
            allow_data_with_model=true,
            handler=wrap_legacy(_dsge_var_fevd),
        ),
        CommandSpec(
            path=["dsge", "var", "hd"],
            summary="Compute Bayesian historical shock decomposition from a DSGE-VAR(lambda) posterior (or inline estimation)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="id", type=String, default="dsge-qr",
                           choices=["dsge-qr", "cholesky", "long-run"],
                           description="Structural identification: dsge-qr|cholesky|long-run"),
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=0,
                           description="Truncation horizon (0 = full effective sample)"),
                OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
                           description="Comma-separated posterior credible quantiles in (0, 1)"),
                OptionSpec(name="point-estimate", type=String, default="mean",
                           choices=["mean", "median"],
                           description="Central posterior summary: mean|median"),
                _W4_DSGEVAR_INLINE_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Exclude the constant intercept when estimating inline"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_hd,
                              description="Bayesian DSGE-VAR(lambda) historical shock contributions per variable",
                              family=true)],
            category="dsge",
            data_kinds=[:timeseries, :csv],
            model_types=_W4_DSGEVAR_POST_INPUT_TYPES,
            result_types=[:BayesianHistoricalDecomposition],
            allow_data_with_model=true,
            handler=wrap_legacy(_dsge_var_hd),
        ),
        CommandSpec(
            path=["dsge", "var", "forecast"],
            summary="Compute out-of-sample multi-step density forecasts from a DSGE-VAR(lambda) posterior (or inline estimation)",
            args=[_W4_FILE_ARG],
            options=[
                MODEL_OPTION,
                OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizon, type=Int, default=12,
                           description="Forecast horizon h (>= 1)"),
                OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84",
                           description="Credible band quantiles in (0, 1) (outer span sets conf_level unless --conf-level is given)"),
                OptionSpec(name="conf-level", type=Float64, default=0.0,
                           description="Explicit credible interval width in (0, 1) (0 = derive from --quantiles)"),
                OptionSpec(name="point-estimate", type=String, default="mean",
                           choices=["mean", "median"],
                           description="Central posterior summary: mean|median"),
                _W4_DSGEVAR_INLINE_OPTIONS...,
                RESULT_OPTION,
                SAVE_RESULT_OPTION,
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Exclude the constant intercept when estimating inline"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:dsge_var_forecast,
                              description="Bayesian DSGE-VAR(lambda) multi-step forecasts with credible intervals")],
            category="dsge",
            data_kinds=[:timeseries, :csv],
            model_types=_W4_DSGEVAR_POST_INPUT_TYPES,
            result_types=[:BVARForecast],
            allow_data_with_model=true,
            handler=wrap_legacy(_dsge_var_forecast),
        ),
    ]
    return with_config_ergonomics(specs)
end
