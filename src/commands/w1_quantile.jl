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

# Wave 1 ([MEM111-W1] #313):
#   - Quantile Factor Models (estimate/predict/residuals/forecast factor qfm)
#   - Growth-at-Risk (forecast factor growth-at-risk)
#   - QFM diagnostics (test factor qfm-spanning, test factor qfm-constancy)
#   - Interactive panel quantile regression (estimate/predict/residuals panel xtqreg)
#   - Quantile VAR & QIRF (estimate/residuals multivariate qvar, irf qvar)
#   - Quantile FAVAR (estimate/forecast multivariate qfavar, irf qfavar)

# ── Shared Wave-1 Parsing & Validation Helpers ───────────────

const _W1_QFM_METHODS = Dict("iqr" => :iqr, "smoothed" => :smoothed_iqr)
const _W1_QFM_KERNELS = ("gaussian", "epanechnikov", "logistic")
const _W1_QFM_INITS = Dict("pca" => :pca, "quantile-svd" => :quantile_svd, "random" => :random)
const _W1_QFM_CRITERIA = ("rank", "ic1", "ic2", "ic3")
const _W1_QFM_SE_TYPES = ("none", "asymptotic", "bootstrap")
const _W1_GAR_DENSITIES = Dict("skewed-t" => :skewed_t, "normal" => :normal, "none" => :none)
const _W1_QIRF_METHODS = Dict("analytical" => :analytical, "simulation" => :simulation, "monte-carlo" => :simulation)

function _w1_check_tau(v::Real, flag::String, leaf::String)::Float64
    (isfinite(v) && 0.0 < Float64(v) < 1.0) || throw(CliError("usage/invalid",
        "$leaf: $flag must lie strictly in (0, 1) (got $v)"))
    return Float64(v)
end

function _w1_parse_taus(raw::String, flag::String, leaf::String)::Vector{Float64}
    parts = [strip(p) for p in split(raw, ",") if !isempty(strip(p))]
    isempty(parts) && throw(CliError("usage/invalid", "$leaf: $flag must not be empty"))
    taus = Float64[]
    for p in parts
        v = tryparse(Float64, p)
        (v === nothing || !isfinite(v) || !(0.0 < v < 1.0)) && throw(CliError("usage/invalid",
            "$leaf: $flag values must lie strictly in (0, 1) (got '$p' in '$raw')"))
        push!(taus, v)
    end
    length(unique(round.(taus; digits=12))) == length(taus) || throw(CliError("usage/invalid",
        "$leaf: $flag contains duplicate quantile values ($raw)"))
    return taus
end

function _w1_parse_factors_or_auto(raw::String, flag::String, leaf::String)::Union{Int,Symbol}
    s = lowercase(strip(raw))
    (isempty(s) || s == "auto") && return :auto
    n = tryparse(Int, s)
    (n === nothing || n < 1) && throw(CliError("usage/invalid",
        "$leaf: $flag must be a positive integer or 'auto' (got '$raw')"))
    return n
end

function _w1_parse_qfm_bandwidth(raw::String, leaf::String)::Union{Symbol,Float64}
    s = lowercase(strip(raw))
    (isempty(s) || s == "auto") && return :auto
    v = tryparse(Float64, s)
    (v === nothing || !isfinite(v) || v <= 0.0) && throw(CliError("usage/invalid",
        "$leaf: --bandwidth must be 'auto' or a positive number (got '$raw')"))
    return v
end

function _w1_parse_hac_bandwidth(raw::String, leaf::String)::Union{Symbol,Int}
    s = lowercase(strip(raw))
    (isempty(s) || s == "auto") && return :auto
    n = tryparse(Int, s)
    (n === nothing || n < 0) && throw(CliError("usage/invalid",
        "$leaf: --hac-bandwidth must be 'auto' or a non-negative integer (got '$raw')"))
    return n
end

function _w1_ic_rank(ic, criterion::String)::Int
    c = lowercase(strip(criterion))
    r = if c == "rank"
        ic.r_rank
    elseif c == "ic1"
        ic.r_IC1
    elseif c == "ic2"
        ic.r_IC2
    elseif c == "ic3"
        ic.r_IC3
    else
        throw(CliError("usage/invalid-option",
            "invalid --criterion '$criterion'; must be rank|ic1|ic2|ic3"))
    end
    return max(Int(r), 1)
end

function _w1_grid_pick_tau(grid::QuantileFactorGrid, tau::Float64, leaf::String)
    idx = findfirst(t -> abs(Float64(t) - tau) <= 1e-8, grid.taus)
    idx === nothing && throw(CliError("usage/invalid",
        "$leaf: tau=$tau not found in QuantileFactorGrid (available: $(join(round.(Float64.(grid.taus); digits=4), ", ")))"))
    return grid.models[idx]
end

function _w1_parse_ordering(raw::String, varnames::Vector{String}, leaf::String)::Vector{Int}
    n = length(varnames)
    isempty(strip(raw)) && return collect(1:n)
    parts = [strip(p) for p in split(raw, ",") if !isempty(strip(p))]
    ord = Int[]
    for p in parts
        idx = tryparse(Int, p)
        if idx !== nothing
            (1 <= idx <= n) || throw(CliError("data/column-range",
                "$leaf: --ordering index $idx out of range 1:$n"))
            push!(ord, idx)
        else
            found = findfirst(==(p), varnames)
            found === nothing && throw(CliError("data/column-range",
                "$leaf: --ordering variable '$p' not found in $(join(varnames, ", "))"))
            push!(ord, found)
        end
    end
    (length(ord) == n && sort(ord) == collect(1:n)) || throw(CliError("usage/invalid",
        "$leaf: --ordering must be a permutation of all $n variables (got '$raw')"))
    return ord
end

function _w1_parse_key_indices(raw::String, varnames::Vector{String}, leaf::String)::Vector{Int}
    n = length(varnames)
    parts = [strip(p) for p in split(raw, ",") if !isempty(strip(p))]
    isempty(parts) && throw(CliError("usage/missing",
        "$leaf: --key-vars is required";
        hint="comma-separated column names or 1-based indices, e.g. --key-vars y1,y2"))
    idxs = Int[]
    for p in parts
        idx = tryparse(Int, p)
        if idx !== nothing
            (1 <= idx <= n) || throw(CliError("data/column-range",
                "$leaf: --key-vars index $idx out of range 1:$n"))
            push!(idxs, idx)
        else
            found = findfirst(==(p), varnames)
            found === nothing && throw(CliError("data/column-range",
                "$leaf: --key-vars variable '$p' not found in $(join(varnames, ", "))"))
            push!(idxs, found)
        end
    end
    length(unique(idxs)) == length(idxs) || throw(CliError("usage/invalid",
        "$leaf: --key-vars must not contain duplicate columns ($raw)"))
    return idxs
end

function _w1_parse_tau_profile(raw::String, leaf::String)
    parts = [strip(p) for p in split(raw, ",") if !isempty(strip(p))]
    isempty(parts) && throw(CliError("usage/invalid", "$leaf: --tau-profile must not be empty"))
    vals = Float64[]
    for p in parts
        v = tryparse(Float64, p)
        (v === nothing || !isfinite(v) || !(0.0 < v < 1.0)) && throw(CliError("usage/invalid",
            "$leaf: --tau-profile entries must lie strictly in (0, 1) (got '$p')"))
        push!(vals, v)
    end
    return length(vals) == 1 ? vals[1] : vals
end

function _w1_qirf_method(raw::String, leaf::String)::Symbol
    m = lowercase(strip(raw))
    haskey(_W1_QIRF_METHODS, m) || throw(CliError("usage/invalid-option",
        "$leaf: --method must be analytical|simulation|monte-carlo (got '$raw')"))
    return _W1_QIRF_METHODS[m]
end

function _w1_resolve_target_ref(raw::String, varnames::Vector{String}, leaf::String)
    s = strip(raw)
    isempty(s) && return 1
    idx = tryparse(Int, s)
    if idx !== nothing
        (1 <= idx <= length(varnames)) || throw(CliError("data/column-range",
            "$leaf: --target index $idx out of range 1:$(length(varnames))"))
        return idx
    end
    s in varnames && return s
    throw(CliError("data/column-range",
        "$leaf: --target '$s' not found; available: $(join(varnames, ", "))"))
end

function _w1_load_panel_xtqreg(data::String, id_col::String, time_col::String,
                               dep::String, indep::String, leaf::String)
    pd = _load_panel_for_preg(data, id_col, time_col)
    vars = pd.varnames
    isempty(vars) && throw(CliError("data/invalid", "$leaf: no panel variable columns found"))
    dep_col = _resolve_panel_dep(pd, dep)
    dep_col in vars || throw(CliError("data/column-range",
        "$leaf: --dep '$dep_col' not found in panel variables: $(join(vars, ", "))"))
    indep_syms = _parse_indep_vars(pd, dep_col, indep)
    isempty(indep_syms) && throw(CliError("data/invalid",
        "$leaf: need at least one regressor via --indep"))
    for s in indep_syms
        nm = String(s)
        nm in vars || throw(CliError("data/column-range",
            "$leaf: --indep variable '$nm' not found in panel variables: $(join(vars, ", "))"))
        nm == dep_col && throw(CliError("usage/invalid",
            "$leaf: --indep variable '$nm' cannot equal --dep '$dep_col'"))
    end
    return pd, Symbol(dep_col), indep_syms, dep_col
end

function _w1_load_and_estimate_qvar(data::String, lags::Int, taus_str::String,
                                    ordering_str::String, se_str::String, n_boot::Int,
                                    leaf::String)
    lags >= 1 || throw(CliError("usage/invalid", "$leaf: --lags must be ≥ 1 (got $lags)"))
    taus_vec = _w1_parse_taus(taus_str, "--taus", leaf)
    se_l = lowercase(strip(se_str))
    se_l in _W1_QFM_SE_TYPES || throw(CliError("usage/invalid-option",
        "$leaf: --se must be asymptotic|bootstrap|none (got '$se_str')"))
    n_boot >= (se_l == "bootstrap" ? 2 : 1) || throw(CliError("usage/invalid",
        "$leaf: --n-boot must be ≥ $(se_l == "bootstrap" ? 2 : 1) (got $n_boot)"))

    Y, varnames = load_multivariate_data(data)
    ord = _w1_parse_ordering(ordering_str, varnames, leaf)
    _status("Estimating QVAR($lags): $(length(varnames)) variables, τ=$(join(taus_vec, ", ")), se=$se_l")
    _status()
    model = try
        estimate_qvar(Y, lags, taus_vec; ordering=ord, se=Symbol(se_l),
                      n_boot=n_boot, varnames=varnames, _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "$leaf"))
    end
    return model, varnames
end

function _w1_load_and_estimate_qfavar(data::String, factors::Int, lags::Int,
                                      key_vars::String, taus_str::String, method_str::String,
                                      se_str::String, vb_maxiter::Int, vb_tol::Float64,
                                      n_draws::Int, no_standardize::Bool, leaf::String)
    factors >= 1 || throw(CliError("usage/invalid", "$leaf: --factors must be ≥ 1 (got $factors)"))
    lags >= 1 || throw(CliError("usage/invalid", "$leaf: --lags must be ≥ 1 (got $lags)"))
    taus_vec = _w1_parse_taus(taus_str, "--taus", leaf)
    meth_l = lowercase(strip(method_str))
    meth_l in ("twostep", "vb") || throw(CliError("usage/invalid-option",
        "$leaf: --method must be twostep|vb (got '$method_str')"))
    se_l = lowercase(strip(se_str))
    se_l in _W1_QFM_SE_TYPES || throw(CliError("usage/invalid-option",
        "$leaf: --se must be none|asymptotic|bootstrap (got '$se_str')"))
    vb_maxiter >= 1 || throw(CliError("usage/invalid", "$leaf: --vb-maxiter must be ≥ 1 (got $vb_maxiter)"))
    (isfinite(vb_tol) && vb_tol > 0.0) || throw(CliError("usage/invalid", "$leaf: --vb-tol must be > 0 (got $vb_tol)"))
    n_draws >= 1 || throw(CliError("usage/invalid", "$leaf: --n-draws must be ≥ 1 (got $n_draws)"))

    X, varnames = load_multivariate_data(data)
    key_idx = _w1_parse_key_indices(key_vars, varnames, leaf)
    key_names = [varnames[i] for i in key_idx]

    _status("Estimating Quantile FAVAR: r=$factors, p=$lags, method=$meth_l, key_vars=$(join(key_names, ", ")), τ=$(join(taus_vec, ", "))")
    _status()
    model = try
        estimate_qfavar(X, key_idx, factors, lags, taus_vec;
                        method=Symbol(meth_l), standardize=!no_standardize,
                        panel_varnames=varnames, key_names=key_names,
                        se=Symbol(se_l), vb_maxiter=vb_maxiter, vb_tol=vb_tol,
                        n_draws=n_draws, _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, "$leaf"))
    end
    return model, varnames
end

function _w1_emit_qfavar_forecast(fc; format::String="table", output::String="",
                                  title::String="Quantile FAVAR Forecast",
                                  key::String="qfavar_forecast")
    pq = fc.quantiles
    H, N, M = size(pq)
    vns = (hasproperty(fc, :varnames) && length(fc.varnames) == N) ?
        String.(fc.varnames) : ["X$i" for i in 1:N]
    taus = Float64.(fc.taus)
    horizon = Int[]; variable = String[]; tau = Float64[]; value = Float64[]
    for mi in 1:M, h in 1:H, i in 1:N
        push!(horizon, h); push!(variable, vns[i])
        push!(tau, taus[mi]); push!(value, Float64(pq[h, i, mi]))
    end
    df = DataFrame(; horizon, variable, tau, value)
    output_result(df; format=Symbol(format), output=output, title=title, key=key)
    return fc
end

# ── Handlers: Quantile Factor Models (QFM) ───────────────────

function _estimate_qfm(; data::String, tau::Float64=0.5, taus::String="",
                       factors::String="auto", r_max::Int=0, criterion::String="rank",
                       threshold_scale::Float64=1.0, method::String="iqr",
                       bandwidth::String="auto", kernel::String="gaussian",
                       se::String="none", hac_bandwidth::String="auto", n_boot::Int=200,
                       init::String="pca", n_starts::Int=3, max_iter::Int=200,
                       tol::Float64=1e-7, standardize::Bool=false,
                       no_robust_scale::Bool=false,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="")
    leaf = "estimate factor qfm"
    r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
    r_max >= 0 || throw(CliError("usage/invalid", "$leaf: --r-max must be ≥ 0 (got $r_max)"))
    crit_l = lowercase(strip(criterion))
    crit_l in _W1_QFM_CRITERIA || throw(CliError("usage/invalid-option",
        "$leaf: --criterion must be rank|ic1|ic2|ic3 (got '$criterion')"))
    (isfinite(threshold_scale) && threshold_scale > 0.0) || throw(CliError("usage/invalid",
        "$leaf: --threshold-scale must be > 0 (got $threshold_scale)"))
    meth_l = lowercase(strip(method))
    haskey(_W1_QFM_METHODS, meth_l) || throw(CliError("usage/invalid-option",
        "$leaf: --method must be iqr|smoothed (got '$method')"))
    meth_sym = _W1_QFM_METHODS[meth_l]
    bw_val = _w1_parse_qfm_bandwidth(bandwidth, leaf)
    kern_l = lowercase(strip(kernel))
    kern_l in _W1_QFM_KERNELS || throw(CliError("usage/invalid-option",
        "$leaf: --kernel must be gaussian|epanechnikov|logistic (got '$kernel')"))
    se_l = lowercase(strip(se))
    se_l in _W1_QFM_SE_TYPES || throw(CliError("usage/invalid-option",
        "$leaf: --se must be none|asymptotic|bootstrap (got '$se')"))
    hac_bw = _w1_parse_hac_bandwidth(hac_bandwidth, leaf)
    n_boot >= (se_l == "bootstrap" ? 2 : 1) || throw(CliError("usage/invalid",
        "$leaf: --n-boot must be ≥ $(se_l == "bootstrap" ? 2 : 1) (got $n_boot)"))
    init_l = lowercase(strip(init))
    haskey(_W1_QFM_INITS, init_l) || throw(CliError("usage/invalid-option",
        "$leaf: --init must be pca|quantile-svd|random (got '$init')"))
    init_sym = _W1_QFM_INITS[init_l]
    n_starts >= 1 || throw(CliError("usage/invalid", "$leaf: --n-starts must be ≥ 1 (got $n_starts)"))
    max_iter >= 1 || throw(CliError("usage/invalid", "$leaf: --max-iter must be ≥ 1 (got $max_iter)"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid", "$leaf: --tol must be > 0 (got $tol)"))

    is_grid = !isempty(strip(taus))
    taus_vec = is_grid ? _w1_parse_taus(taus, "--taus", leaf) : Float64[_w1_check_tau(tau, "--tau", leaf)]

    X, varnames = load_multivariate_data(data)
    T_obs, N = size(X)
    rmax_eff = r_max > 0 ? r_max : min(10, max(1, min(T_obs, N) - 1))
    robust_scale = !no_robust_scale

    shared_kw = (
        standardize = standardize,
        robust_scale = robust_scale,
        init = init_sym,
        n_starts = n_starts,
        max_iter = max_iter,
        tol = tol,
        method = meth_sym,
        bandwidth = bw_val,
        kernel = Symbol(kern_l),
    )

    model = try
        if is_grid
            r_fit = if r_spec === :auto
                _status("Selecting quantile factor rank per τ via ic_criteria_qfm (r_max=$rmax_eff, criterion=$crit_l)...")
                ics = [ic_criteria_qfm(X, rmax_eff, tj; threshold_scale=threshold_scale,
                                       shared_kw..., _fwd_seed()...) for tj in taus_vec]
                mid_idx = argmin(abs.(taus_vec .- 0.5))
                _emit_result(ics[mid_idx];
                             title="QFM Rank Selection (τ=$(taus_vec[mid_idx]), r_max=$rmax_eff)",
                             key="qfm_ic", format=Symbol(format),
                             output=_per_var_output_path(output, "ic"))
                Int[_w1_ic_rank(icj, crit_l) for icj in ics]
            else
                r_spec
            end
            _status("Estimating Quantile Factor Grid: τ=$(join(taus_vec, ", ")), r=$r_fit, method=$meth_l, T=$T_obs, N=$N")
            _status()
            estimate_qfm(X, r_fit, taus_vec;
                         shared_kw..., se=Symbol(se_l), hac_bandwidth=hac_bw,
                         n_boot=n_boot, varnames=varnames, _fwd_seed()...)
        else
            t1 = taus_vec[1]
            r_fit = if r_spec === :auto
                _status("Selecting quantile factor rank via ic_criteria_qfm (τ=$t1, r_max=$rmax_eff, criterion=$crit_l)...")
                ic = ic_criteria_qfm(X, rmax_eff, t1; threshold_scale=threshold_scale,
                                     shared_kw..., _fwd_seed()...)
                _emit_result(ic;
                             title="QFM Rank Selection (τ=$t1, r_max=$rmax_eff)",
                             key="qfm_ic", format=Symbol(format),
                             output=_per_var_output_path(output, "ic"))
                _w1_ic_rank(ic, crit_l)
            else
                r_spec
            end
            _status("Estimating Quantile Factor Model: r=$r_fit, τ=$t1, method=$meth_l, T=$T_obs, N=$N")
            _status()
            estimate_qfm(X, r_fit, t1;
                         shared_kw..., se=Symbol(se_l), hac_bandwidth=hac_bw,
                         n_boot=n_boot, varnames=varnames, _fwd_seed()...)
        end
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, leaf))
    end

    title_str = model isa QuantileFactorGrid ?
        "Quantile Factor Grid Loadings ($(length(model.taus)) quantiles)" :
        "Quantile Factor Model Loadings (r=$(model.r), τ=$(model.tau))"
    _emit_result(model; title=title_str, key="qfm_loadings",
                 format=Symbol(format), output=output)
    _maybe_plot(model; plot=plot, plot_save=plot_save)
    return model
end

function _predict_qfm(; data::String="", tau::Float64=0.5, factors::String="auto",
                      method::String="iqr", standardize::Bool=false,
                      output::String="", format::String="table",
                      model=nothing)
    leaf = "predict factor qfm"
    _w1_check_tau(tau, "--tau", leaf)
    qfm = if isnothing(model)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        meth_l = lowercase(strip(method))
        haskey(_W1_QFM_METHODS, meth_l) || throw(CliError("usage/invalid-option",
            "$leaf: --method must be iqr|smoothed (got '$method')"))
        X, varnames = load_multivariate_data(data)
        try
            estimate_qfm(X, r_spec, tau; method=_W1_QFM_METHODS[meth_l],
                         standardize=standardize, varnames=varnames, _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    elseif model isa QuantileFactorGrid
        _w1_grid_pick_tau(model, tau, leaf)
    else
        model
    end

    varnames = _model_varnames(qfm)
    fitted = predict(qfm)
    T_obs, N = size(fitted)
    length(varnames) == N || (varnames = ["Var $i" for i in 1:N])

    _status("Quantile Factor Model common component: r=$(qfm.r), τ=$(qfm.tau), T=$T_obs, N=$N")
    _status()
    pred_df = DataFrame()
    pred_df.t = 1:T_obs
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end
    output_result(pred_df; format=Symbol(format), output=output,
                  title="QFM Common Component (r=$(qfm.r), τ=$(qfm.tau), T=$T_obs)",
                  key="qfm_common_component")
    return fitted
end

function _residuals_qfm(; data::String="", tau::Float64=0.5, factors::String="auto",
                        method::String="iqr", standardize::Bool=false,
                        output::String="", format::String="table",
                        model=nothing)
    leaf = "residuals factor qfm"
    _w1_check_tau(tau, "--tau", leaf)
    qfm = if isnothing(model)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        meth_l = lowercase(strip(method))
        haskey(_W1_QFM_METHODS, meth_l) || throw(CliError("usage/invalid-option",
            "$leaf: --method must be iqr|smoothed (got '$method')"))
        X, varnames = load_multivariate_data(data)
        try
            estimate_qfm(X, r_spec, tau; method=_W1_QFM_METHODS[meth_l],
                         standardize=standardize, varnames=varnames, _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    elseif model isa QuantileFactorGrid
        _w1_grid_pick_tau(model, tau, leaf)
    else
        model
    end

    varnames = _model_varnames(qfm)
    resid = residuals(qfm)
    T_obs, N = size(resid)
    length(varnames) == N || (varnames = ["Var $i" for i in 1:N])

    _status("Quantile Factor Model residuals: r=$(qfm.r), τ=$(qfm.tau), T=$T_obs, N=$N")
    _status()
    res_df = DataFrame()
    res_df.t = 1:T_obs
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end
    output_result(res_df; format=Symbol(format), output=output,
                  title="QFM Residuals (r=$(qfm.r), τ=$(qfm.tau), T=$T_obs)",
                  key="qfm_residuals")
    return resid
end

function _forecast_qfm(; data::String="", result=nothing, model=nothing,
                       tau::Float64=0.5, taus::String="", factors::String="auto",
                       horizons::Int=12, lags::Int=1, no_rearrange::Bool=false,
                       ci_method::String="none", n_boot::Int=299,
                       conf_level::Float64=0.95, standardize::Bool=false,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="")
    leaf = "forecast factor qfm"
    loaded = _loaded_result(result; data, model, leaf=leaf, horizons, horizons_default=12)
    loaded === nothing || return _rerender_long_table(loaded; format, output,
        title="QFM Forecast", key="qfm_forecast", plot, plot_save)

    horizons >= 1 || throw(CliError("usage/invalid", "$leaf: --horizons must be ≥ 1 (got $horizons)"))
    lags >= 1 || throw(CliError("usage/invalid", "$leaf: --lags must be ≥ 1 (got $lags)"))
    ci_l = lowercase(strip(ci_method))
    ci_l in ("none", "bootstrap") || throw(CliError("usage/invalid-option",
        "$leaf: --ci-method must be none|bootstrap (got '$ci_method')"))
    (isfinite(conf_level) && 0.0 < conf_level < 1.0) || throw(CliError("usage/invalid",
        "$leaf: --conf-level must lie strictly in (0, 1) (got $conf_level)"))
    n_boot >= (ci_l == "bootstrap" ? 2 : 1) || throw(CliError("usage/invalid",
        "$leaf: --n-boot must be ≥ $(ci_l == "bootstrap" ? 2 : 1) (got $n_boot)"))

    fm = if isnothing(model)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        X, varnames = load_multivariate_data(data)
        try
            if !isempty(strip(taus))
                taus_vec = _w1_parse_taus(taus, "--taus", leaf)
                estimate_qfm(X, r_spec, taus_vec; standardize=standardize,
                             varnames=varnames, _fwd_seed()...)
            else
                t1 = _w1_check_tau(tau, "--tau", leaf)
                estimate_qfm(X, r_spec, t1; standardize=standardize,
                             varnames=varnames, _fwd_seed()...)
            end
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    else
        model
    end

    if fm isa QuantileFactorGrid
        _status("Forecasting Quantile Factor Grid: $(length(fm.taus)) quantiles, h=$horizons, p=$lags, rearrange=$(!no_rearrange)")
        _status()
        fcs = try
            forecast(fm, horizons; p=lags, rearrange=!no_rearrange,
                     ci_method=Symbol(ci_l), conf_level=conf_level, n_boot=n_boot,
                     _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
        parts = DataFrame[]
        for (j, fcj) in enumerate(fcs)
            dfj = long_table(fcj)
            insertcols!(dfj, 1, :tau => fill(Float64(fm.taus[j]), nrow(dfj)))
            push!(parts, dfj)
        end
        all_df = reduce(vcat, parts)
        output_result(all_df; format=Symbol(format), output=output,
                      title="QFM Grid Forecast (h=$horizons, $(length(fm.taus)) quantiles)",
                      key="qfm_forecast")
        med_idx = argmin(abs.(Float64.(fm.taus) .- 0.5))
        _maybe_plot(fcs[med_idx]; plot=plot, plot_save=plot_save)
        return (; model=fm, result=fcs[med_idx])
    else
        _status("Forecasting Quantile Factor Model: r=$(fm.r), τ=$(fm.tau), h=$horizons, p=$lags, CI=$ci_l")
        _status()
        fc = try
            forecast(fm, horizons; p=lags, ci_method=Symbol(ci_l),
                     conf_level=conf_level, n_boot=n_boot, _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
        _emit_result(fc; title="QFM Forecast (r=$(fm.r), τ=$(fm.tau), h=$horizons)",
                     key="qfm_forecast", format=Symbol(format), output=output)
        _maybe_plot(fc; plot=plot, plot_save=plot_save)
        return (; model=fm, result=fc)
    end
end

# ── Handlers: Growth-at-Risk (GaR) ───────────────────────────

function _forecast_growth_at_risk(; data::String="", result=nothing, model=nothing,
                                  target::String="", horizons::Int=1, factors::String="2",
                                  taus::String="0.05,0.10,0.25,0.50,0.75,0.90,0.95",
                                  lags::Int=1, no_rearrange::Bool=false,
                                  alpha::Float64=0.05, density::String="skewed-t",
                                  oos_split::Int=0, no_standardize::Bool=false,
                                  output::String="", format::String="table",
                                  plot::Bool=false, plot_save::String="")
    leaf = "forecast factor growth-at-risk"
    loaded = _loaded_result(result; data, model, leaf=leaf, horizons, horizons_default=1)
    loaded === nothing || return _rerender_long_table(loaded; format, output,
        title="Growth-at-Risk", key="growth_at_risk", plot, plot_save)

    horizons >= 1 || throw(CliError("usage/invalid", "$leaf: --horizons must be ≥ 1 (got $horizons)"))
    lags >= 0 || throw(CliError("usage/invalid", "$leaf: --lags must be ≥ 0 (got $lags)"))
    (isfinite(alpha) && 0.0 < alpha < 1.0) || throw(CliError("usage/invalid",
        "$leaf: --alpha must lie strictly in (0, 1) (got $alpha)"))
    dens_l = lowercase(strip(density))
    haskey(_W1_GAR_DENSITIES, dens_l) || throw(CliError("usage/invalid-option",
        "$leaf: --density must be skewed-t|normal|none (got '$density')"))
    dens_sym = _W1_GAR_DENSITIES[dens_l]
    oos_split >= 0 || throw(CliError("usage/invalid", "$leaf: --oos-split must be ≥ 0 (got $oos_split)"))
    oos_arg = oos_split == 0 ? nothing : oos_split

    grid, gar = if isnothing(model)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        taus_vec = _w1_parse_taus(taus, "--taus", leaf)
        if dens_sym === :skewed_t && length(taus_vec) < 4
            throw(CliError("usage/invalid",
                "$leaf: --density skewed-t requires at least 4 quantiles in --taus (got $(length(taus_vec)))"))
        elseif dens_sym === :normal && length(taus_vec) < 2
            throw(CliError("usage/invalid",
                "$leaf: --density normal requires at least 2 quantiles in --taus (got $(length(taus_vec)))"))
        end
        X, varnames = load_multivariate_data(data)
        target_ref = _w1_resolve_target_ref(target, varnames, leaf)
        _status("Estimating Growth-at-Risk: target=$target_ref, h=$horizons, r=$r_spec, density=$dens_l, α=$alpha")
        _status()
        try
            g = estimate_qfm(X, r_spec, taus_vec; standardize=!no_standardize,
                             varnames=varnames, _fwd_seed()...)
            res = growth_at_risk(g, target_ref, horizons;
                                 taus=taus_vec, lags=lags, rearrange=!no_rearrange,
                                 alpha=alpha, density=dens_sym, oos_split=oos_arg,
                                 _fwd_seed()...)
            g, res
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    else
        vns = _model_varnames(model)
        target_ref = _w1_resolve_target_ref(target, vns, leaf)
        taus_opt = isempty(strip(taus)) ? nothing : _w1_parse_taus(taus, "--taus", leaf)
        _status("Computing Growth-at-Risk from saved QuantileFactorGrid: target=$target_ref, h=$horizons, density=$dens_l, α=$alpha")
        _status()
        res = try
            growth_at_risk(model, target_ref, horizons;
                           taus=taus_opt, lags=lags, rearrange=!no_rearrange,
                           alpha=alpha, density=dens_sym, oos_split=oos_arg,
                           _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
        model, res
    end

    _emit_result(gar; title="Growth-at-Risk ($(gar.target_name), h=$horizons, α=$alpha, $dens_l)",
                 key="growth_at_risk", format=Symbol(format), output=output)
    _maybe_plot(gar; plot=plot, plot_save=plot_save)
    return (; model=grid, result=gar)
end

# ── Handlers: QFM Diagnostics Tests ──────────────────────────

function _test_qfm_spanning(; data::String="", tau::Float64=0.5, taus::String="",
                            factors::String="auto", r_pca::String="auto",
                            r_max::Int=0, criterion::String="ic2",
                            threshold::Float64=0.5, standardize::Bool=false,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="",
                            model=nothing)
    leaf = "test factor qfm-spanning"
    r_pca_spec = _w1_parse_factors_or_auto(r_pca, "--r-pca", leaf)
    r_max >= 0 || throw(CliError("usage/invalid", "$leaf: --r-max must be ≥ 0 (got $r_max)"))
    crit_l = lowercase(strip(criterion))
    crit_l in ("ic1", "ic2", "ic3") || throw(CliError("usage/invalid-option",
        "$leaf: --criterion must be ic1|ic2|ic3 (got '$criterion')"))
    (isfinite(threshold) && 0.0 <= threshold <= 1.0) || throw(CliError("usage/invalid",
        "$leaf: --threshold must lie in [0, 1] (got $threshold)"))

    res = if isnothing(model)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        X, varnames = load_multivariate_data(data)
        T_obs, N = size(X)
        rmax_eff = r_max > 0 ? r_max : min(10, max(1, min(T_obs, N) - 1))
        try
            qfm_obj = if !isempty(strip(taus))
                taus_vec = _w1_parse_taus(taus, "--taus", leaf)
                estimate_qfm(X, r_spec, taus_vec; standardize=standardize,
                             varnames=varnames, _fwd_seed()...)
            else
                t1 = _w1_check_tau(tau, "--tau", leaf)
                estimate_qfm(X, r_spec, t1; standardize=standardize,
                             varnames=varnames, _fwd_seed()...)
            end
            _status("QFM-vs-PCA Factor Spanning Test: r_pca=$r_pca_spec, threshold=$threshold")
            _status()
            test_qfm_spanning(qfm_obj, X; r_pca=r_pca_spec, r_max=rmax_eff,
                              criterion=Symbol(crit_l), standardize=standardize,
                              threshold=threshold)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    else
        X_ref = model isa QuantileFactorGrid ? model.models[1].X : model.X
        T_obs, N = size(X_ref)
        rmax_eff = r_max > 0 ? r_max : min(10, max(1, min(T_obs, N) - 1))
        _status("QFM-vs-PCA Factor Spanning Test (saved model): r_pca=$r_pca_spec, threshold=$threshold")
        _status()
        try
            test_qfm_spanning(model; r_pca=r_pca_spec, r_max=rmax_eff,
                              criterion=Symbol(crit_l), threshold=threshold)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    end

    _emit_result(res; title="QFM Factor Spanning Diagnostic (threshold=$threshold)",
                 key="qfm_spanning_test", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

function _test_qfm_constancy(; data::String="", tau1::Float64=0.1, tau2::Float64=0.9,
                             factors::String="auto", n_boot::Int=299,
                             block_length::Int=0, bootstrap::String="block",
                             max_iter::Int=60, tol::Float64=1e-5,
                             standardize::Bool=false,
                             output::String="", format::String="table",
                             plot::Bool=false, plot_save::String="",
                             model=nothing)
    leaf = "test factor qfm-constancy"
    _w1_check_tau(tau1, "--tau1", leaf)
    _w1_check_tau(tau2, "--tau2", leaf)
    n_boot >= 1 || throw(CliError("usage/invalid", "$leaf: --n-boot must be ≥ 1 (got $n_boot)"))
    block_length >= 0 || throw(CliError("usage/invalid", "$leaf: --block-length must be ≥ 0 (got $block_length)"))
    boot_l = lowercase(strip(bootstrap))
    boot_l in ("block", "wild") || throw(CliError("usage/invalid-option",
        "$leaf: --bootstrap must be block|wild (got '$bootstrap')"))
    max_iter >= 1 || throw(CliError("usage/invalid", "$leaf: --max-iter must be ≥ 1 (got $max_iter)"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid", "$leaf: --tol must be > 0 (got $tol)"))

    res = if isnothing(model)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        X, _ = load_multivariate_data(data)
        _status("QFM Loading Constancy Test: τ₁=$tau1 vs τ₂=$tau2, bootstrap=$boot_l, n_boot=$n_boot")
        _status()
        try
            test_qfm_loading_constancy(X, tau1, tau2; r=r_spec, n_boot=n_boot,
                                       block_length=block_length, bootstrap=Symbol(boot_l),
                                       max_iter=max_iter, tol=tol, standardize=standardize,
                                       _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    else
        # Validate both quantiles exist in the saved QuantileFactorGrid before calling upstream
        _w1_grid_pick_tau(model, tau1, leaf)
        _w1_grid_pick_tau(model, tau2, leaf)
        _status("QFM Loading Constancy Test (saved grid): τ₁=$tau1 vs τ₂=$tau2, bootstrap=$boot_l, n_boot=$n_boot")
        _status()
        try
            test_qfm_loading_constancy(model, tau1, tau2; n_boot=n_boot,
                                       block_length=block_length, bootstrap=Symbol(boot_l),
                                       max_iter=max_iter, tol=tol, _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    end

    _emit_result(res; title="QFM Loading Constancy Test (τ₁=$tau1 vs τ₂=$tau2)",
                 key="qfm_constancy_test", format=Symbol(format), output=output)
    interpret_test_result(res.pvalue,
        "Reject H₀: quantile-varying factor loadings (p=$(round(res.pvalue; digits=4)))",
        "Fail to reject H₀: loading space consistent with constancy (p=$(round(res.pvalue; digits=4)))")
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

# ── Handlers: Interactive Panel Quantile Regression (xtqreg) ─

function _estimate_xtqreg(; data::String, dep::String="", indep::String="",
                          id_col::String="", time_col::String="",
                          factors::String="1", tau::Float64=0.5,
                          slope::String="homogeneous", se::String="asymptotic",
                          n_boot::Int=199, r_max::Int=6, max_iter::Int=100,
                          tol::Float64=1e-5, no_bias_correct::Bool=false,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    leaf = "estimate panel xtqreg"
    _w1_check_tau(tau, "--tau", leaf)
    r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
    slope_l = lowercase(strip(slope))
    slope_l in ("homogeneous", "heterogeneous") || throw(CliError("usage/invalid-option",
        "$leaf: --slope must be homogeneous|heterogeneous (got '$slope')"))
    se_l = lowercase(strip(se))
    se_l in ("asymptotic", "bootstrap") || throw(CliError("usage/invalid-option",
        "$leaf: --se must be asymptotic|bootstrap (got '$se')"))
    n_boot >= (se_l == "bootstrap" ? 2 : 1) || throw(CliError("usage/invalid",
        "$leaf: --n-boot must be ≥ $(se_l == "bootstrap" ? 2 : 1) (got $n_boot)"))
    r_max >= 1 || throw(CliError("usage/invalid", "$leaf: --r-max must be ≥ 1 (got $r_max)"))
    max_iter >= 1 || throw(CliError("usage/invalid", "$leaf: --max-iter must be ≥ 1 (got $max_iter)"))
    (isfinite(tol) && tol > 0.0) || throw(CliError("usage/invalid", "$leaf: --tol must be > 0 (got $tol)"))

    pd, dep_sym, indep_syms, dep_col = _w1_load_panel_xtqreg(data, id_col, time_col, dep, indep, leaf)
    _status("Interactive Panel Quantile Regression (xtqreg): $dep_col ~ $(join(indep_syms, " + "))")
    _status("  τ=$tau, factors=$r_spec, slope=$slope_l, se=$se_l")
    _status()

    model = try
        estimate_xtqreg_factors(pd, dep_sym, indep_syms, r_spec, tau;
                                slope=Symbol(slope_l), se=Symbol(se_l),
                                n_boot=n_boot, r_max=r_max, maxiter=max_iter,
                                tol=tol, bias_correct=!no_bias_correct,
                                _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, leaf))
    end

    _emit_result(model;
                 title="Interactive Panel Quantile Regression (τ=$tau, r=$(model.r), $slope_l)",
                 key="xtqreg_coefficients", format=Symbol(format), output=output)
    _maybe_plot(model; plot=plot, plot_save=plot_save)
    return model
end

function _predict_xtqreg(; data::String="", dep::String="", indep::String="",
                         id_col::String="", time_col::String="",
                         factors::String="1", tau::Float64=0.5,
                         slope::String="homogeneous",
                         output::String="", format::String="table",
                         model=nothing)
    leaf = "predict panel xtqreg"
    m = if isnothing(model)
        _w1_check_tau(tau, "--tau", leaf)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        slope_l = lowercase(strip(slope))
        slope_l in ("homogeneous", "heterogeneous") || throw(CliError("usage/invalid-option",
            "$leaf: --slope must be homogeneous|heterogeneous (got '$slope')"))
        pd, dep_sym, indep_syms, _ = _w1_load_panel_xtqreg(data, id_col, time_col, dep, indep, leaf)
        try
            estimate_xtqreg_factors(pd, dep_sym, indep_syms, r_spec, tau;
                                    slope=Symbol(slope_l), _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    else
        model
    end

    fitted = predict(m)
    N, T_obs = size(fitted)
    _status("Interactive panel quantile regression fitted values: N=$N, T=$T_obs, τ=$(m.tau), r=$(m.r)")
    _status()
    unit = Int[]; period = Int[]; val = Float64[]
    for i in 1:N, t in 1:T_obs
        push!(unit, i); push!(period, t); push!(val, Float64(fitted[i, t]))
    end
    df = DataFrame(unit=unit, period=period, fitted_value=round.(val; digits=6))
    output_result(df; format=Symbol(format), output=output,
                  title="Panel Quantile Regression Fitted Values (τ=$(m.tau), r=$(m.r))",
                  key="xtqreg_fitted_values")
    return fitted
end

function _residuals_xtqreg(; data::String="", dep::String="", indep::String="",
                           id_col::String="", time_col::String="",
                           factors::String="1", tau::Float64=0.5,
                           slope::String="homogeneous",
                           output::String="", format::String="table",
                           model=nothing)
    leaf = "residuals panel xtqreg"
    m = if isnothing(model)
        _w1_check_tau(tau, "--tau", leaf)
        r_spec = _w1_parse_factors_or_auto(factors, "--factors", leaf)
        slope_l = lowercase(strip(slope))
        slope_l in ("homogeneous", "heterogeneous") || throw(CliError("usage/invalid-option",
            "$leaf: --slope must be homogeneous|heterogeneous (got '$slope')"))
        pd, dep_sym, indep_syms, _ = _w1_load_panel_xtqreg(data, id_col, time_col, dep, indep, leaf)
        try
            estimate_xtqreg_factors(pd, dep_sym, indep_syms, r_spec, tau;
                                    slope=Symbol(slope_l), _fwd_seed()...)
        catch e
            e isa CliError && rethrow()
            throw(_domain_or_data_error(e, leaf))
        end
    else
        model
    end

    resid = residuals(m)
    N, T_obs = size(resid)
    _status("Interactive panel quantile regression residuals: N=$N, T=$T_obs, τ=$(m.tau), r=$(m.r)")
    _status()
    unit = Int[]; period = Int[]; val = Float64[]
    for i in 1:N, t in 1:T_obs
        push!(unit, i); push!(period, t); push!(val, Float64(resid[i, t]))
    end
    df = DataFrame(unit=unit, period=period, residual=round.(val; digits=6))
    output_result(df; format=Symbol(format), output=output,
                  title="Panel Quantile Regression Residuals (τ=$(m.tau), r=$(m.r))",
                  key="xtqreg_residuals")
    return resid
end

# ── Handlers: Quantile VAR & QIRF ────────────────────────────

function _estimate_qvar(; data::String, lags::Int=1, taus::String="0.1,0.5,0.9",
                        ordering::String="", se::String="asymptotic", n_boot::Int=199,
                        output::String="", format::String="table")
    model, _ = _w1_load_and_estimate_qvar(data, lags, taus, ordering, se, n_boot,
                                          "estimate multivariate qvar")
    _emit_result(model; title="Quantile VAR($(model.p)) Coefficients",
                 key="qvar_coefficients", format=Symbol(format), output=output)
    return model
end

function _residuals_qvar(; data::String="", lags::Int=1, taus::String="0.1,0.5,0.9",
                         ordering::String="",
                         output::String="", format::String="table",
                         model=nothing)
    leaf = "residuals multivariate qvar"
    m, varnames = if isnothing(model)
        _w1_load_and_estimate_qvar(data, lags, taus, ordering, "none", 1, leaf)
    else
        model, _model_varnames(model)
    end
    n = size(m.Y, 2)
    length(varnames) == n || (varnames = ["y$i" for i in 1:n])
    T_eff = size(m.resid_list[1], 1)

    _status("Quantile VAR($(m.p)) residuals: $(length(m.taus)) quantile(s), T_eff=$T_eff, n=$n")
    _status()
    tau_col = Float64[]; t_col = Int[]
    val_cols = [Float64[] for _ in 1:n]
    for (ti, tval) in enumerate(m.taus)
        R = m.resid_list[ti]
        for t in 1:T_eff
            push!(tau_col, Float64(tval)); push!(t_col, t)
            for j in 1:n
                push!(val_cols[j], Float64(R[t, j]))
            end
        end
    end
    df = DataFrame(tau=tau_col, t=t_col)
    for (j, vn) in enumerate(varnames)
        df[!, vn] = val_cols[j]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="Quantile VAR($(m.p)) Residuals (T_eff=$T_eff)",
                  key="qvar_residuals")
    return residuals(m)
end

function _irf_qvar(; data::String="", result=nothing, model=nothing,
                   lags::Int=1, taus::String="0.1,0.5,0.9", ordering::String="",
                   horizons::Int=20, shock::Int=0, shock_size::Float64=1.0,
                   tau_profile::String="0.1", baseline_tau::Float64=0.5,
                   method::String="analytical", ci_type::String="none",
                   n_boot::Int=199, conf_level::Float64=0.95,
                   output::String="", format::String="table",
                   plot::Bool=false, plot_save::String="")
    leaf = "irf qvar"
    loaded = _loaded_result(result; data, model, leaf=leaf, horizons, horizons_default=20)
    loaded === nothing || return _rerender_irf_result(loaded; format, output,
        title="Quantile VAR IRF", key="qvar_irf", plot, plot_save,
        shock=shock > 0 ? shock : nothing)

    horizons >= 1 || throw(CliError("usage/invalid", "$leaf: --horizons must be ≥ 1 (got $horizons)"))
    shock >= 0 || throw(CliError("usage/invalid", "$leaf: --shock must be ≥ 0 (0 = all shocks, got $shock)"))
    isfinite(shock_size) || throw(CliError("usage/invalid", "$leaf: --shock-size must be finite"))
    tp_arg = _w1_parse_tau_profile(tau_profile, leaf)
    _w1_check_tau(baseline_tau, "--baseline-tau", leaf)
    meth_sym = _w1_qirf_method(method, leaf)
    ci_l = lowercase(strip(ci_type))
    ci_l in ("none", "bootstrap") || throw(CliError("usage/invalid-option",
        "$leaf: --ci-type must be none|bootstrap (got '$ci_type')"))
    n_boot >= (ci_l == "bootstrap" ? 2 : 1) || throw(CliError("usage/invalid",
        "$leaf: --n-boot must be ≥ $(ci_l == "bootstrap" ? 2 : 1) (got $n_boot)"))
    (isfinite(conf_level) && 0.0 < conf_level < 1.0) || throw(CliError("usage/invalid",
        "$leaf: --conf-level must lie strictly in (0, 1) (got $conf_level)"))

    qv = if isnothing(model)
        m, _ = _w1_load_and_estimate_qvar(data, lags, taus, ordering, "none", 1, leaf)
        m
    else
        model
    end
    shock_arg = shock == 0 ? nothing : shock
    if shock_arg !== nothing
        n_v = size(qv.Y, 2)
        (1 <= shock_arg <= n_v) || throw(CliError("usage/invalid",
            "$leaf: --shock $shock_arg out of range 1:$n_v"))
    end

    _status("Computing Quantile VAR IRF: H=$horizons, method=$meth_sym, ci=$ci_l, baseline_tau=$baseline_tau")
    _status()
    irf_res = try
        qirf(qv, horizons; shock=shock_arg, shock_size=shock_size,
             tau_profile=tp_arg, baseline_tau=baseline_tau,
             method=meth_sym, ci_type=Symbol(ci_l), n_boot=n_boot,
             conf_level=conf_level, _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, leaf))
    end

    _emit_result(irf_res; title="Quantile VAR Impulse Responses (H=$horizons, $meth_sym)",
                 key="qvar_irf", format=Symbol(format), output=output)
    _maybe_plot(irf_res; plot=plot, plot_save=plot_save)
    return (; model=qv, result=irf_res)
end

# ── Handlers: Quantile FAVAR ─────────────────────────────────

function _estimate_qfavar(; data::String, factors::Int=2, lags::Int=1,
                          key_vars::String="", taus::String="0.1,0.5,0.9",
                          method::String="twostep", se::String="none",
                          vb_maxiter::Int=100, vb_tol::Float64=1e-4,
                          n_draws::Int=200, no_standardize::Bool=false,
                          output::String="", format::String="table")
    model, _ = _w1_load_and_estimate_qfavar(
        data, factors, lags, key_vars, taus, method, se,
        vb_maxiter, vb_tol, n_draws, no_standardize,
        "estimate multivariate qfavar")
    lbl = model isa VBQuantileFAVAR ? "VB Quantile FAVAR" : "Quantile FAVAR"
    _emit_result(model; title="$lbl Loadings (r=$(model.n_factors), p=$(model.p))",
                 key="qfavar_loadings", format=Symbol(format), output=output)
    return model
end

function _irf_qfavar(; data::String="", result=nothing, model=nothing,
                     factors::Int=2, lags::Int=1, key_vars::String="",
                     taus::String="0.1,0.5,0.9", est_method::String="twostep",
                     no_standardize::Bool=false,
                     horizons::Int=20, shock::Int=0, shock_size::Float64=1.0,
                     tau_profile::String="0.1", baseline_tau::Float64=0.5,
                     method::String="analytical", ci_type::String="none",
                     n_boot::Int=199, conf_level::Float64=0.95,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    leaf = "irf qfavar"
    loaded = _loaded_result(result; data, model, leaf=leaf, horizons, horizons_default=20)
    loaded === nothing || return _rerender_irf_result(loaded; format, output,
        title="Quantile FAVAR IRF", key="qfavar_irf", plot, plot_save,
        shock=shock > 0 ? shock : nothing)

    horizons >= 1 || throw(CliError("usage/invalid", "$leaf: --horizons must be ≥ 1 (got $horizons)"))
    shock >= 0 || throw(CliError("usage/invalid", "$leaf: --shock must be ≥ 0 (0 = all shocks, got $shock)"))
    isfinite(shock_size) || throw(CliError("usage/invalid", "$leaf: --shock-size must be finite"))
    tp_arg = _w1_parse_tau_profile(tau_profile, leaf)
    _w1_check_tau(baseline_tau, "--baseline-tau", leaf)
    meth_sym = _w1_qirf_method(method, leaf)
    ci_l = lowercase(strip(ci_type))
    ci_l in ("none", "bootstrap", "credible") || throw(CliError("usage/invalid-option",
        "$leaf: --ci-type must be none|bootstrap|credible (got '$ci_type')"))
    n_boot >= (ci_l == "bootstrap" ? 2 : 1) || throw(CliError("usage/invalid",
        "$leaf: --n-boot must be ≥ $(ci_l == "bootstrap" ? 2 : 1) (got $n_boot)"))
    (isfinite(conf_level) && 0.0 < conf_level < 1.0) || throw(CliError("usage/invalid",
        "$leaf: --conf-level must lie strictly in (0, 1) (got $conf_level)"))

    qf = if isnothing(model)
        m, _ = _w1_load_and_estimate_qfavar(
            data, factors, lags, key_vars, taus, est_method, "none",
            100, 1e-4, 200, no_standardize, leaf)
        m
    else
        model
    end
    if ci_l == "credible" && !(qf isa VBQuantileFAVAR)
        throw(CliError("usage/invalid",
            "$leaf: --ci-type credible is only supported for VBQuantileFAVAR (--est-method vb or a saved VBQuantileFAVAR handle)"))
    end
    shock_arg = shock == 0 ? nothing : shock
    if shock_arg !== nothing
        n_aug = qf.n_factors + qf.n_key
        (1 <= shock_arg <= n_aug) || throw(CliError("usage/invalid",
            "$leaf: --shock $shock_arg out of range 1:$n_aug"))
    end

    _status("Computing Quantile FAVAR panel IRF: H=$horizons, method=$meth_sym, ci=$ci_l")
    _status()
    irf_res = try
        qfavar_panel_irf(qf, horizons; shock=shock_arg, shock_size=shock_size,
                         tau_profile=tp_arg, baseline_tau=baseline_tau,
                         method=meth_sym, ci_type=Symbol(ci_l), n_boot=n_boot,
                         conf_level=conf_level, _fwd_seed()...)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, leaf))
    end

    _emit_result(irf_res; title="Quantile FAVAR Panel Impulse Responses (H=$horizons)",
                 key="qfavar_irf", format=Symbol(format), output=output)
    _maybe_plot(irf_res; plot=plot, plot_save=plot_save)
    return (; model=qf, result=irf_res)
end

function _forecast_qfavar(; data::String="", result=nothing, model=nothing,
                          factors::Int=2, lags::Int=1, key_vars::String="",
                          taus::String="0.1,0.5,0.9", method::String="twostep",
                          horizons::Int=12, no_rearrange::Bool=false,
                          no_standardize::Bool=false,
                          output::String="", format::String="table")
    leaf = "forecast multivariate qfavar"
    loaded = _loaded_result(result; data, model, leaf=leaf, horizons, horizons_default=12)
    loaded === nothing || return _w1_emit_qfavar_forecast(loaded; format, output,
        title="Quantile FAVAR Forecast", key="qfavar_forecast")

    horizons >= 1 || throw(CliError("usage/invalid", "$leaf: --horizons must be ≥ 1 (got $horizons)"))
    qf = if isnothing(model)
        m, _ = _w1_load_and_estimate_qfavar(
            data, factors, lags, key_vars, taus, method, "none",
            100, 1e-4, 200, no_standardize, leaf)
        m
    else
        model
    end

    _status("Computing Quantile FAVAR panel forecast: h=$horizons, rearrange=$(!no_rearrange)")
    _status()
    fc = try
        qfavar_panel_forecast(qf, horizons; rearrange=!no_rearrange)
    catch e
        e isa CliError && rethrow()
        throw(_domain_or_data_error(e, leaf))
    end

    _w1_emit_qfavar_forecast(fc; format=format, output=output,
                             title="Quantile FAVAR Panel Forecast (h=$horizons)",
                             key="qfavar_forecast")
    return (; model=qf, result=fc)
end

# ── Declarative CommandSpec Builders ─────────────────────────

function w1_estimate_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["estimate", "qfm"],
            summary="Quantile Factor Model (Chen-Dolado-Gonzalo IQR / convolution-smoothed QFA)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="tau", type=Float64, default=0.5, description="Single quantile level in (0, 1) (used when --taus is empty)"),
                OptionSpec(name="taus", type=String, default="", description="Comma-separated quantiles in (0, 1) to fit a QuantileFactorGrid (overrides --tau)"),
                OptionSpec(name="factors", type=String, default="auto", description="Number of quantile factors (positive integer or 'auto' via ic_criteria_qfm)"),
                OptionSpec(name="r-max", type=Int, default=0, description="Max factors for auto selection (0 = min(10, min(T,N)-1))"),
                OptionSpec(name="criterion", type=String, default="rank", description="Auto rank selection criterion: rank|ic1|ic2|ic3", choices=["rank", "ic1", "ic2", "ic3"]),
                OptionSpec(name="threshold-scale", type=Float64, default=1.0, description="Positive multiplier c on CDG rank threshold P_NT"),
                OptionSpec(name="method", type=String, default="iqr", description="Estimator: iqr (alternating IPM) | smoothed (convolution-smoothed L-BFGS)", choices=["iqr", "smoothed"]),
                OptionSpec(name="bandwidth", type=String, default="auto", description="Smoothing bandwidth for --method smoothed ('auto' or positive number)"),
                OptionSpec(name="kernel", type=String, default="gaussian", description="Smoothing kernel for --method smoothed: gaussian|epanechnikov|logistic", choices=["gaussian", "epanechnikov", "logistic"]),
                OptionSpec(name="se", type=String, default="none", description="Standard errors: none|asymptotic|bootstrap", choices=["none", "asymptotic", "bootstrap"]),
                OptionSpec(name="hac-bandwidth", type=String, default="auto", description="Newey-West HAC lag truncation for --se asymptotic ('auto' or integer >= 0)"),
                OptionSpec(name="n-boot", type=Int, default=200, description="Bootstrap replications for --se bootstrap"),
                OptionSpec(name="init", type=String, default="pca", description="Start-1 initialization: pca|quantile-svd|random", choices=["pca", "quantile-svd", "random"]),
                OptionSpec(name="n-starts", type=Int, default=3, description="Number of multi-start initializations (>= 1)"),
                OptionSpec(name="max-iter", type=Int, default=200, description="Maximum outer iterations (>= 1)"),
                OptionSpec(name="tol", type=Float64, default=1e-7, description="Convergence tolerance (> 0)"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="standardize", description="Standardize panel columns before estimation"),
                FlagSpec(name="no-robust-scale", description="Use mean/SD instead of median/IQR when --standardize is set"),
                PLOT_FLAGS...,
            ],
            tables=[
                TableSpec(name=:qfm_ic, description="QFM rank selection criteria when --factors auto: r | tau | sigma_sq | loss | IC1 | IC2 | IC3 | r_IC1 | r_IC2 | r_IC3 | r_rank"),
                TableSpec(name=:qfm_loadings, description="Quantile factor loadings via upstream long_table: variable | factor | tau | loading | std_error | pseudo_r2 (single tau) or tau | variable | factor | loading | r_at_tau (grid)"),
            ],
            category="estimate",
            handler=wrap_legacy(_estimate_qfm),
        ),
        CommandSpec(
            path=["estimate", "xtqreg"],
            summary="Interactive panel quantile regression with latent quantile factors (Ando-Bai)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first panel variable)"),
                OptionSpec(name="indep", type=String, default="", description="Independent regressor columns (comma-separated; default: all non-dep panel variables)"),
                OptionSpec(name="id-col", type=String, default="", description="Panel group ID column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column (default: second column)"),
                OptionSpec(name="factors", type=String, default="1", description="Number of latent quantile factors (positive integer or 'auto')"),
                OptionSpec(name="tau", type=Float64, default=0.5, description="Quantile level strictly in (0, 1)"),
                OptionSpec(name="slope", type=String, default="homogeneous", description="Slope specification: homogeneous|heterogeneous", choices=["homogeneous", "heterogeneous"]),
                OptionSpec(name="se", type=String, default="asymptotic", description="Standard error method: asymptotic|bootstrap", choices=["asymptotic", "bootstrap"]),
                OptionSpec(name="n-boot", type=Int, default=199, description="Bootstrap replications for --se bootstrap"),
                OptionSpec(name="r-max", type=Int, default=6, description="Max factor count when --factors auto"),
                OptionSpec(name="max-iter", type=Int, default=100, description="Maximum outer alternating iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-5, description="Convergence tolerance (> 0)"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-bias-correct", description="Disable split-panel jackknife bias correction for homogeneous slopes"),
                PLOT_FLAGS...,
            ],
            tables=[
                TableSpec(name=:xtqreg_coefficients, description="Interactive panel quantile regression slopes via Tables.jl: term | estimate | std_error | stat | p_value | ci_lower | ci_upper"),
            ],
            category="estimate",
            handler=wrap_legacy(_estimate_xtqreg),
        ),
        # Plot discipline: QuantileVARModel has plot_result=false upstream — NO --plot/--plot-save.
        CommandSpec(
            path=["estimate", "qvar"],
            summary="Recursive structural Quantile VAR(p) (Chavleishvili-Manganelli)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=1, description="VAR lag order (>= 1)"),
                OptionSpec(name="taus", type=String, default="0.1,0.5,0.9", description="Comma-separated quantile levels strictly in (0, 1)"),
                OptionSpec(name="ordering", type=String, default="", description="Recursive Cholesky variable ordering (comma-separated names or 1-based indices)"),
                OptionSpec(name="se", type=String, default="asymptotic", description="Standard error method: asymptotic|bootstrap|none", choices=["asymptotic", "bootstrap", "none"]),
                OptionSpec(name="n-boot", type=Int, default=199, description="Bootstrap replications for --se bootstrap"),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:qvar_coefficients, description="Quantile VAR coefficients via Tables.jl: tau | equation | term | estimate | std_error"),
            ],
            category="estimate",
            handler=wrap_legacy(_estimate_qvar),
        ),
        # Plot discipline: QuantileFAVAR / VBQuantileFAVAR have plot_result=false upstream — NO --plot/--plot-save.
        CommandSpec(
            path=["estimate", "qfavar"],
            summary="Quantile Factor-Augmented VAR (two-step IQR or Variational Bayes, Korobilis-Schroder)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="factors", type=Int, default=2, description="Number of latent quantile factors r (>= 1)"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="QVAR lag order p (>= 1)"),
                OptionSpec(name="key-vars", type=String, default="", description="Key observed variables (comma-separated names or 1-based indices, required)"),
                OptionSpec(name="taus", type=String, default="0.1,0.5,0.9", description="Comma-separated quantile levels strictly in (0, 1)"),
                OptionSpec(name="method", type=String, default="twostep", description="Estimation method: twostep|vb", choices=["twostep", "vb"]),
                OptionSpec(name="se", type=String, default="none", description="Two-step QVAR standard errors: none|asymptotic|bootstrap", choices=["none", "asymptotic", "bootstrap"]),
                OptionSpec(name="vb-maxiter", type=Int, default=100, description="Max CAVI iterations for --method vb"),
                OptionSpec(name="vb-tol", type=Float64, default=1e-4, description="CAVI convergence tolerance for --method vb"),
                OptionSpec(name="n-draws", type=Int, default=200, description="Variational posterior draws for --method vb"),
                OUTPUT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-standardize", description="Do not standardize panel columns before factor extraction"),
            ],
            tables=[
                TableSpec(name=:qfavar_loadings, description="Quantile FAVAR measurement loadings via upstream long_table: tau | variable | component | estimate"),
            ],
            category="estimate",
            handler=wrap_legacy(_estimate_qfavar),
        ),
    ]
end

function w1_predict_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["predict", "qfm"],
            summary="Quantile factor model in-sample common component",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="tau", type=Float64, default=0.5, description="Quantile level in (0, 1)"),
                OptionSpec(name="factors", type=String, default="auto", description="Number of quantile factors (integer or 'auto')"),
                OptionSpec(name="method", type=String, default="iqr", description="Estimator: iqr|smoothed", choices=["iqr", "smoothed"]),
                OUTPUT_OPTIONS...,
            ],
            flags=[FlagSpec(name="standardize", description="Standardize panel columns before estimation")],
            tables=[TableSpec(name=:qfm_common_component, description="Quantile factor common component fitted values: t | variable columns")],
            category="predict",
            handler=_predict_qfm,
        ),
        CommandSpec(
            path=["predict", "xtqreg"],
            summary="Interactive panel quantile regression in-sample fitted values",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name"),
                OptionSpec(name="indep", type=String, default="", description="Independent regressor columns (comma-separated)"),
                OptionSpec(name="id-col", type=String, default="", description="Panel group ID column"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column"),
                OptionSpec(name="factors", type=String, default="1", description="Number of latent quantile factors (integer or 'auto')"),
                OptionSpec(name="tau", type=Float64, default=0.5, description="Quantile level strictly in (0, 1)"),
                OptionSpec(name="slope", type=String, default="homogeneous", description="Slope specification: homogeneous|heterogeneous", choices=["homogeneous", "heterogeneous"]),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:xtqreg_fitted_values, description="Interactive panel quantile regression fitted values: unit | period | fitted_value")],
            category="predict",
            handler=_predict_xtqreg,
        ),
    ]
end

function w1_residuals_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["residuals", "qfm"],
            summary="Quantile factor model idiosyncratic residuals",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="tau", type=Float64, default=0.5, description="Quantile level in (0, 1)"),
                OptionSpec(name="factors", type=String, default="auto", description="Number of quantile factors (integer or 'auto')"),
                OptionSpec(name="method", type=String, default="iqr", description="Estimator: iqr|smoothed", choices=["iqr", "smoothed"]),
                OUTPUT_OPTIONS...,
            ],
            flags=[FlagSpec(name="standardize", description="Standardize panel columns before estimation")],
            tables=[TableSpec(name=:qfm_residuals, description="Quantile factor idiosyncratic residuals: t | variable columns")],
            category="residuals",
            handler=_residuals_qfm,
        ),
        CommandSpec(
            path=["residuals", "xtqreg"],
            summary="Interactive panel quantile regression idiosyncratic residuals",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to panel data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name"),
                OptionSpec(name="indep", type=String, default="", description="Independent regressor columns (comma-separated)"),
                OptionSpec(name="id-col", type=String, default="", description="Panel group ID column"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column"),
                OptionSpec(name="factors", type=String, default="1", description="Number of latent quantile factors (integer or 'auto')"),
                OptionSpec(name="tau", type=Float64, default=0.5, description="Quantile level strictly in (0, 1)"),
                OptionSpec(name="slope", type=String, default="homogeneous", description="Slope specification: homogeneous|heterogeneous", choices=["homogeneous", "heterogeneous"]),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:xtqreg_residuals, description="Interactive panel quantile regression residuals: unit | period | residual")],
            category="residuals",
            handler=_residuals_xtqreg,
        ),
        CommandSpec(
            path=["residuals", "qvar"],
            summary="Quantile VAR structural quantile residuals",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=1, description="VAR lag order (>= 1)"),
                OptionSpec(name="taus", type=String, default="0.1,0.5,0.9", description="Comma-separated quantile levels in (0, 1)"),
                OptionSpec(name="ordering", type=String, default="", description="Recursive Cholesky variable ordering"),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:qvar_residuals, description="Quantile VAR structural residuals across quantiles: tau | t | variable columns")],
            category="residuals",
            handler=_residuals_qvar,
        ),
    ]
end

function w1_forecast_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["forecast", "qfm"],
            summary="Multi-step Quantile Factor Model forecast via QAR/QVAR with optional rearrangement",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="tau", type=Float64, default=0.5, description="Single quantile level in (0, 1) (when --taus is empty)"),
                OptionSpec(name="taus", type=String, default="", description="Comma-separated quantiles in (0, 1) for grid forecasting"),
                OptionSpec(name="factors", type=String, default="auto", description="Number of quantile factors (integer or 'auto')"),
                OptionSpec(name="horizons", type=Int, default=12, description="Forecast horizon (>= 1)"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="QAR/QVAR lag order on quantile factors (>= 1)"),
                OptionSpec(name="ci-method", type=String, default="none", description="Interval method: none|bootstrap", choices=["none", "bootstrap"]),
                OptionSpec(name="n-boot", type=Int, default=299, description="Bootstrap replications for --ci-method bootstrap"),
                OptionSpec(name="conf-level", type=Float64, default=0.95, description="Confidence level in (0, 1)"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-rearrange", description="Disable Chernozhukov-Fernandez-Val-Galichon monotone quantile rearrangement"),
                FlagSpec(name="standardize", description="Standardize panel columns when estimating inline"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:qfm_forecast, description="Quantile factor multi-step forecast: horizon | variable | value | lower | upper (with leading tau for grid)")],
            category="forecast",
            handler=wrap_legacy(_forecast_qfm),
        ),
        CommandSpec(
            path=["forecast", "growth-at-risk"],
            summary="Growth-at-Risk (GaR) distributional forecast with skewed-t / normal density & expected shortfall",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="target", type=String, default="", description="Target column name or 1-based index (default: column 1)"),
                OptionSpec(name="horizons", type=Int, default=1, description="Direct forecast horizon h (>= 1)"),
                OptionSpec(name="factors", type=String, default="2", description="Number of quantile factors (integer or 'auto')"),
                OptionSpec(name="taus", type=String, default="0.05,0.10,0.25,0.50,0.75,0.90,0.95", description="Comma-separated quantile grid in (0, 1)"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="Number of target lags in direct quantile regression (>= 0)"),
                OptionSpec(name="alpha", type=Float64, default=0.05, description="Tail probability in (0, 1) for GaR and Expected Shortfall"),
                OptionSpec(name="density", type=String, default="skewed-t", description="Predictive density fit: skewed-t|normal|none", choices=["skewed-t", "normal", "none"]),
                OptionSpec(name="oos-split", type=Int, default=0, description="Origin index for expanding-window OOS evaluation (0 = disabled)"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-rearrange", description="Disable monotone quantile rearrangement across taus"),
                FlagSpec(name="no-standardize", description="Do not standardize panel columns before QFM estimation"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:growth_at_risk, description="Growth-at-Risk predictive quantiles via upstream long_table: period | tau | fitted_quantile | gar | expected_shortfall | actual")],
            category="forecast",
            handler=wrap_legacy(_forecast_growth_at_risk),
        ),
        # Plot discipline: qfavar_panel_forecast returns a NamedTuple with NO plot_result upstream.
        CommandSpec(
            path=["forecast", "qfavar"],
            summary="Quantile FAVAR panel-wide multi-step quantile forecast with optional rearrangement",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="factors", type=Int, default=2, description="Number of latent quantile factors r (>= 1)"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="QVAR lag order p (>= 1)"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variable column names or 1-based indices (comma-separated, required without --model)"),
                OptionSpec(name="taus", type=String, default="0.1,0.5,0.9", description="Comma-separated quantile levels in (0, 1)"),
                OptionSpec(name="method", type=String, default="twostep", description="Estimation method: twostep|vb", choices=["twostep", "vb"]),
                OptionSpec(name="horizons", type=Int, default=12, description="Forecast horizon (>= 1)"),
                OUTPUT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-rearrange", description="Disable monotone quantile rearrangement across taus"),
                FlagSpec(name="no-standardize", description="Do not standardize panel columns before factor extraction"),
            ],
            tables=[TableSpec(name=:qfavar_forecast, description="Quantile FAVAR panel-wide multi-step forecasts: horizon | variable | tau | value")],
            category="forecast",
            handler=wrap_legacy(_forecast_qfavar),
        ),
    ]
end

function w1_irf_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["irf", "qvar"],
            summary="Quantile VAR impulse response functions (Chavleishvili-Manganelli)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=1, description="QVAR lag order (>= 1)"),
                OptionSpec(name="taus", type=String, default="0.1,0.5,0.9", description="Comma-separated QVAR quantile levels in (0, 1)"),
                OptionSpec(name="ordering", type=String, default="", description="Recursive Cholesky variable ordering"),
                OptionSpec(name="horizons", type=Int, default=20, description="IRF horizon H (>= 1)"),
                OptionSpec(name="shock", type=Int, default=0, description="Structural shock index (1..n, or 0 for all shocks)"),
                OptionSpec(name="shock-size", type=Float64, default=1.0, description="Structural shock magnitude"),
                OptionSpec(name="tau-profile", type=String, default="0.1", description="Scalar quantile or comma-separated horizon quantile profile in (0, 1)"),
                OptionSpec(name="baseline-tau", type=Float64, default=0.5, description="Baseline quantile in (0, 1) for initial conditions & padding"),
                OptionSpec(name="method", type=String, default="analytical", description="Propagation method: analytical|simulation|monte-carlo", choices=["analytical", "simulation", "monte-carlo"]),
                OptionSpec(name="ci-type", type=String, default="none", description="Interval type: none|bootstrap", choices=["none", "bootstrap"]),
                OptionSpec(name="n-boot", type=Int, default=199, description="Bootstrap replications (also simulation draws)"),
                OptionSpec(name="conf-level", type=Float64, default=0.95, description="Confidence level in (0, 1)"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:qvar_irf, description="Quantile VAR impulse responses via upstream long_table: horizon | variable | shock | tau | value | lower | upper")],
            category="irf",
            handler=wrap_legacy(_irf_qvar),
        ),
        CommandSpec(
            path=["irf", "qfavar"],
            summary="Quantile FAVAR panel-wide impulse response functions",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="factors", type=Int, default=2, description="Number of latent quantile factors r (>= 1)"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="QVAR lag order p (>= 1)"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variables (comma-separated names or 1-based indices, required without --model)"),
                OptionSpec(name="taus", type=String, default="0.1,0.5,0.9", description="Comma-separated QFAVAR quantile levels in (0, 1)"),
                OptionSpec(name="est-method", type=String, default="twostep", description="Inline QFAVAR estimation method: twostep|vb", choices=["twostep", "vb"]),
                OptionSpec(name="horizons", type=Int, default=20, description="IRF horizon H (>= 1)"),
                OptionSpec(name="shock", type=Int, default=0, description="Augmented shock index (1..(r+n_key), or 0 for all shocks)"),
                OptionSpec(name="shock-size", type=Float64, default=1.0, description="Structural shock magnitude"),
                OptionSpec(name="tau-profile", type=String, default="0.1", description="Scalar quantile or comma-separated horizon quantile profile in (0, 1)"),
                OptionSpec(name="baseline-tau", type=Float64, default=0.5, description="Baseline quantile in (0, 1)"),
                OptionSpec(name="method", type=String, default="analytical", description="Propagation method: analytical|simulation|monte-carlo", choices=["analytical", "simulation", "monte-carlo"]),
                OptionSpec(name="ci-type", type=String, default="none", description="Interval type: none|bootstrap|credible (credible for VBQuantileFAVAR only)", choices=["none", "bootstrap", "credible"]),
                OptionSpec(name="n-boot", type=Int, default=199, description="Bootstrap replications"),
                OptionSpec(name="conf-level", type=Float64, default=0.95, description="Confidence / credible level in (0, 1)"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-standardize", description="Do not standardize panel columns when estimating inline"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:qfavar_irf, description="Quantile FAVAR panel-wide impulse responses via upstream long_table: horizon | variable | shock | tau | value | lower | upper")],
            category="irf",
            handler=wrap_legacy(_irf_qfavar),
        ),
    ]
end

function w1_test_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["test", "qfm-spanning"],
            summary="Test whether quantile factors are spanned by conditional-mean PCA factors (CDG 2021)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="tau", type=Float64, default=0.5, description="Single quantile level in (0, 1) (when --taus is empty)"),
                OptionSpec(name="taus", type=String, default="", description="Comma-separated quantiles in (0, 1) to test a QFM grid"),
                OptionSpec(name="factors", type=String, default="auto", description="QFM factor count (integer or 'auto')"),
                OptionSpec(name="r-pca", type=String, default="auto", description="PCA factor count (integer or 'auto' via Bai-Ng)"),
                OptionSpec(name="r-max", type=Int, default=0, description="Max PCA factors when --r-pca auto (0 = library default)"),
                OptionSpec(name="criterion", type=String, default="ic2", description="Bai-Ng criterion for --r-pca auto: ic1|ic2|ic3", choices=["ic1", "ic2", "ic3"]),
                OptionSpec(name="threshold", type=Float64, default=0.5, description="OLS R² cutoff in [0, 1] flagging unspanned tail factors"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="standardize", description="Standardize panel columns before factor extraction"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:qfm_spanning_test, description="PCA-vs-QFM factor spanning diagnostics via Tables.jl: tau | factor | ols_r2 | quantile_r1 | cancor | unspanned")],
            category="test",
            handler=_test_qfm_spanning,
        ),
        CommandSpec(
            path=["test", "qfm-constancy"],
            summary="Bootstrap test of quantile factor loading-space constancy across two quantiles",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="tau1", type=Float64, default=0.1, description="First quantile level in (0, 1)"),
                OptionSpec(name="tau2", type=Float64, default=0.9, description="Second quantile level in (0, 1)"),
                OptionSpec(name="factors", type=String, default="auto", description="QFM factor rank (integer or 'auto') when estimating from data"),
                OptionSpec(name="n-boot", type=Int, default=299, description="Bootstrap replications (>= 1)"),
                OptionSpec(name="block-length", type=Int, default=0, description="Moving-block length (0 = ceil(T^(1/3)))"),
                OptionSpec(name="bootstrap", type=String, default="block", description="Bootstrap scheme: block|wild", choices=["block", "wild"]),
                OptionSpec(name="max-iter", type=Int, default=60, description="Max IQR iterations per bootstrap draw"),
                OptionSpec(name="tol", type=Float64, default=1e-5, description="Convergence tolerance per bootstrap draw"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="standardize", description="Standardize panel columns before factor extraction"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:qfm_constancy_test, description="QFM loading constancy test via Tables.jl: test | tau1 | tau2 | statistic | p_value | n_boot | dof")],
            category="test",
            handler=_test_qfm_constancy,
        ),
    ]
end
