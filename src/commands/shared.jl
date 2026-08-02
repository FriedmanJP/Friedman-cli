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

# Shared utilities for command handlers

# ── Data Loading Helpers ───────────────────────────────────

"""
    load_multivariate_data(data) → (Y::Matrix{Float64}, varnames::Vector{String})

Load CSV, convert to numeric matrix and extract variable names.
"""
function load_multivariate_data(data::String)
    df = load_data(data)
    varnames = variable_names(df)
    # Guard missing cells as a typed data error BEFORE df_to_matrix's Matrix{Float64}
    # conversion (which throws an untyped ArgumentError → uncaught exit-1). Mirrors the
    # univariate `load_univariate_series` guard so every multivariate estimator surfaces
    # a `data/missing-values` (exit 3) instead of an internal error.
    for c in varnames
        any(ismissing, df[!, c]) && throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them (e.g. via `data dropna`/`data fix`) first"))
    end
    Y = df_to_matrix(df)
    return Y, varnames
end

"""
    load_univariate_series(data, column) → (y::Vector{Float64}, vname::String)

Load CSV and extract a single numeric column by index.
"""
function load_univariate_series(data::String, column::Int)
    df = load_data(data)
    varnames = variable_names(df)
    (column < 1 || column > length(varnames)) && throw(CliError("data/column-range",
        "column $column out of range (data has $(length(varnames)) numeric column(s))";
        hint="--column is 1-based; pick 1..$(length(varnames))"))
    col = df[!, varnames[column]]
    any(ismissing, col) && throw(CliError("data/missing-values",
        "column '$(varnames[column])' contains missing values; drop or impute them (e.g. via `data dropna`/`data fix`) first"))
    y = Vector{Float64}(col)
    return y, varnames[column]
end

"""
    _load_midas_data(data, column, hf_data, hf_column; m) → (y_lf, x_hf, ynm, xnm)

Load a mixed-frequency MIDAS dataset from two CSVs: the low-frequency target
(`data`, numeric column `column`) and the high-frequency indicator (`hf_data`,
numeric column `hf_column`). Both are read through the already-hardened
`load_univariate_series`, so a missing/non-numeric cell or an out-of-range column
surfaces a typed `data/missing-values`/`data/column-range` (never an untyped
exit-1 from a `Vector{Float64}` conversion — the standing shared-loader lesson;
this is the 5th hardened shared loader after univariate/multivariate/reg/panel).

The HF series must supply AT LEAST `m` observations per low-frequency period,
i.e. `length(x_hf) >= m * length(y_lf)`. The estimator's internal `_align_hf`
anchors the *last* HF observation to the *last* low-frequency period and works
backwards, so any *leading* ragged edge (extra early HF history) is dropped
automatically — the natural nowcasting layout (a long high-frequency indicator
against a shorter low-frequency target) is fully supported. Only a HF series
*shorter* than `m×LF` is rejected as a typed `data/shape` (exit 3), since
end-anchoring would then silently drop low-frequency target periods. A `K`
larger than the available aligned HF history surfaces via the estimator's own
typed error, mapped by `_midas_error`.
"""
function _load_midas_data(data::String, column::Int, hf_data::String, hf_column::Int; m::Int)
    y_lf, ynm = load_univariate_series(data, column)
    x_hf, xnm = load_univariate_series(hf_data, hf_column)
    nlf = length(y_lf); nhf = length(x_hf)
    nhf >= m * nlf || throw(CliError("data/shape",
        "high-frequency series '$xnm' has only $nhf observation(s) but the low-frequency target '$ynm' has $nlf and --m=$m needs at least m×LF = $(m * nlf) high-frequency observations (≥ $m aligned per low-frequency period)";
        hint="check --m, --hf-column, and that the HF file covers at least the target window"))
    nhf > m * nlf && _status("MIDAS alignment: dropping $(nhf - m * nlf) leading high-frequency observation(s) of '$xnm' (anchoring the last HF obs to the last low-frequency period)")
    return y_lf, x_hf, ynm, xnm
end

# ── Naming Helpers ─────────────────────────────────────────

"""Safe shock name: uses variable name if in range, else "shock_N"."""
_shock_name(varnames::Vector{String}, idx::Int) =
    idx <= length(varnames) ? varnames[idx] : "shock_$idx"

"""Safe variable name: uses variable name if in range, else "var_N"."""
_var_name(varnames::Vector{String}, idx::Int) =
    idx <= length(varnames) ? varnames[idx] : "var_$idx"

"""Generate per-variable output path by inserting suffix before extension."""
function _per_var_output_path(output::String, suffix::String)
    isempty(output) && return ""
    _validate_output_path(output)
    return replace(output, "." => "_$(suffix).")
end

# ── Output Helpers ─────────────────────────────────────────

"""Build a coefficient table DataFrame for VAR/BVAR models."""
function _build_var_coef_table(coef_mat::AbstractMatrix, varnames::Vector{String}, p::Int)
    n = length(varnames)
    n_rows = size(coef_mat, 1)
    row_names = String[]
    for lag in 1:p
        for v in varnames
            push!(row_names, "$(v)_L$(lag)")
        end
    end
    if n_rows > n * p
        push!(row_names, "const")
    end
    coef_df = DataFrame(permutedims(coef_mat), row_names)
    insertcols!(coef_df, 1, :equation => varnames)
    return coef_df
end

"""Output AIC/BIC/HQC/loglik for a VAR-like model."""
function output_model_criteria(model; format::String="table", output::String="", title::String="Information Criteria")
    pairs = Pair{String,Any}[
        "AIC" => model.aic,
        "BIC" => model.bic,
        "HQC" => model.hqic,
    ]
    if hasproperty(model, :loglik) || hasmethod(loglikelihood, (typeof(model),))
        try
            push!(pairs, "Log-likelihood" => loglikelihood(model))
        catch; end
    end
    output_kv(pairs; format=format, title=title)
end

"""Output per-variable FEVD tables."""
function _output_fevd_tables(proportions::AbstractArray, varnames::Vector{String},
                              horizons::Int; id::String="cholesky",
                              title_prefix::String="FEVD",
                              format::String="table", output::String="")
    n = length(varnames)
    for vi in 1:n
        fevd_df = DataFrame()
        fevd_df.horizon = 1:horizons
        for si in 1:n
            fevd_df[!, _shock_name(varnames, si)] = proportions[vi, si, :]
        end
        vname = _var_name(varnames, vi)
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="$title_prefix for $vname ($id identification)")
        _status()
    end
end

"""Output per-variable HD tables."""
function _output_hd_tables(get_contrib::Function, varnames::Vector{String},
                            T_eff::Int; id::String="cholesky",
                            title_prefix::String="Historical Decomposition",
                            format::String="table", output::String="",
                            actual=nothing, initial=nothing)
    n = length(varnames)
    for vi in 1:n
        hd_df = DataFrame()
        hd_df.period = 1:T_eff
        if !isnothing(actual)
            hd_df.actual = actual[:, vi]
        end
        if !isnothing(initial)
            hd_df.initial = initial[:, vi]
        end
        for si in 1:n
            hd_df[!, "contrib_$(_shock_name(varnames, si))"] = get_contrib(vi, si)
        end
        vname = _var_name(varnames, vi)
        output_result(hd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="$title_prefix: $vname ($id identification)")
        _status()
    end
end

# ── Validation Helpers ─────────────────────────────────────

"""Validate that a method string is in the allowed set."""
function validate_method(method::String, allowed::Vector{String}, context::String)
    method in allowed || error("unknown $context: $method (expected $(join(allowed, "|")))")
    return method
end

# ── Test Helpers ───────────────────────────────────────────

"""Print colored p-value interpretation for hypothesis tests."""
function interpret_test_result(pvalue::Real, reject_msg::String, accept_msg::String; level::Float64=0.05)
    _status()
    if pvalue < level
        _status_styled("-> $reject_msg\n"; color=:yellow)
    else
        _status_styled("-> $accept_msg\n"; color=:green)
    end
end

"""
Map an untyped MEMs `ArgumentError`/`DomainError` from the long-memory family
(ARFIMA / GPH / local Whittle) to a typed `CliError`, so bad input surfaces as a
`data`-class exit (3) rather than an uncaught internal exit-1 (standing lesson).
Typed MEMs domain errors are already handled centrally by `_domain_error_class`.
"""
function _long_memory_error(e, what::String)
    e isa CliError && return e
    if e isa ArgumentError || e isa DomainError
        return CliError("data/invalid", "$what: $(sprint(showerror, e))";
            hint="need a longer numeric series (>= 8 obs) and valid p/q/bandwidth")
    end
    return CliError("model/error", "$what failed: $(sprint(showerror, e))")
end

"""Convert trend string to Symbol for test regression kwarg."""
function to_regression_symbol(trend::String)
    trend == "none" && return :none
    trend == "both" && return :both
    return Symbol(trend)
end

# ── Volatility Output Helpers ──────────────────────────────

"""Standard normal CDF approximation (Abramowitz & Stegun)."""
function _normal_cdf(x::Real)
    t = 1.0 / (1.0 + 0.2316419 * abs(x))
    d = 0.3989422804014327  # 1/sqrt(2*pi)
    p = d * exp(-x * x / 2.0) * t *
        (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
    x >= 0.0 ? 1.0 - p : p
end

"""Standard normal quantile (inverse CDF), Acklam's rational approximation.

Companion to `_normal_cdf` so CI half-widths can be formed without a Distributions
dependency. Accurate to ~1e-9 over the range, which is far finer than the 6-digit
rounding every renderer applies.
"""
function _normal_quantile(p::Real)
    (0 < p < 1) || throw(DomainError(p, "_normal_quantile requires 0 < p < 1"))
    a = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
         1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
    b = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
         6.680131188771972e+01, -1.328068155288572e+01)
    c = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
         -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
    d = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
         3.754408661907416e+00)
    plow = 0.02425
    if p < plow
        q = sqrt(-2 * log(p))
        return (((((c[1]*q + c[2])*q + c[3])*q + c[4])*q + c[5])*q + c[6]) /
               ((((d[1]*q + d[2])*q + d[3])*q + d[4])*q + 1)
    elseif p > 1 - plow
        q = sqrt(-2 * log(1 - p))
        return -(((((c[1]*q + c[2])*q + c[3])*q + c[4])*q + c[5])*q + c[6]) /
                ((((d[1]*q + d[2])*q + d[3])*q + d[4])*q + 1)
    end
    q = p - 0.5; r = q * q
    return (((((a[1]*r + a[2])*r + a[3])*r + a[4])*r + a[5])*r + a[6]) * q /
           (((((b[1]*r + b[2])*r + b[3])*r + b[4])*r + b[5])*r + 1)
end

"""Shared volatility model estimation output: coefficients + persistence."""
function _vol_estimate_output(model, vname::String, param_names::Vector{String},
                               model_label::String; format::String="table", output::String="")
    c = coef(model)
    names = param_names[1:length(c)]
    coef_df = try
        # SVModel has no vcov/stderror — StatsAPI defaults cause infinite recursion
        model isa SVModel && throw(ErrorException("no SE for SV"))
        se = stderror(model)
        z = c ./ se
        pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
        DataFrame(parameter=names, estimate=round.(c; digits=6),
                  std_error=round.(se; digits=6),
                  z_stat=round.(z; digits=3), p_value=round.(pv; digits=4))
    catch
        DataFrame(parameter=names, estimate=round.(c; digits=6))
    end
    output_result(coef_df; format=Symbol(format), output=output,
                  title="$model_label Coefficients ($vname)")
    _status()
    p_val = persistence(model)
    _status("Persistence: $(round(p_val; digits=4))")
end

"""Shared volatility forecast output: horizon/variance/volatility table."""
function _vol_forecast_output(fc, vname::String, model_label::String,
                               horizons::Int; format::String="table", output::String="")
    fc_df = DataFrame(
        horizon=1:horizons,
        variance=round.(fc.forecast; digits=6),
        volatility=round.(sqrt.(fc.forecast); digits=6)
    )
    output_result(fc_df; format=Symbol(format), output=output,
                  title="$model_label Volatility Forecast ($vname, h=$horizons)")
end

# ── Volatility model table (F10: 5 rows × 4 verbs = 20 leaves) ──

"""
One row drives estimate / predict / residuals / forecast for a volatility model.
`order`: `:q_only` (ARCH), `:pq` (GARCH family), `:sv` (stochastic vol).
`post_est`: extras after estimate — `:uc`, `:halflife`, `:halflife_uc`, or `:none`.
`post_fc`: extras after forecast — `:uc` or `:none`.
"""
const VOL_MODELS = [
    (
        name = "arch",
        order = :q_only,
        estimate = (y; p=1, q=1, draws=5000) -> estimate_arch(y, q),
        param_names = (p, q) -> String["mu"; "omega"; ["alpha$i" for i in 1:q]],
        label = (p, q) -> "ARCH($q)",
        post_est = :uc,
        post_fc = :none,
        predict_title = (p, q) -> "ARCH($q) Conditional Variance",
        resid_title = (p, q) -> "ARCH($q) Standardized Residuals",
    ),
    (
        name = "garch",
        order = :pq,
        estimate = (y; p=1, q=1, draws=5000) -> estimate_garch(y, p, q),
        param_names = (p, q) -> String["mu"; "omega"; ["alpha$i" for i in 1:q]; ["beta$i" for i in 1:p]],
        label = (p, q) -> "GARCH($p,$q)",
        post_est = :halflife_uc,
        post_fc = :uc,
        predict_title = (p, q) -> "GARCH($p,$q) Conditional Variance",
        resid_title = (p, q) -> "GARCH($p,$q) Standardized Residuals",
    ),
    (
        name = "egarch",
        order = :pq,
        estimate = (y; p=1, q=1, draws=5000) -> estimate_egarch(y, p, q),
        param_names = (p, q) -> String["mu"; "omega"; ["alpha$i" for i in 1:q]; ["gamma$i" for i in 1:q]; ["beta$i" for i in 1:p]],
        label = (p, q) -> "EGARCH($p,$q)",
        post_est = :none,
        post_fc = :none,
        predict_title = (p, q) -> "EGARCH($p,$q) Conditional Variance",
        resid_title = (p, q) -> "EGARCH($p,$q) Standardized Residuals",
    ),
    (
        name = "gjr_garch",
        order = :pq,
        estimate = (y; p=1, q=1, draws=5000) -> estimate_gjr_garch(y, p, q),
        param_names = (p, q) -> String["mu"; "omega"; ["alpha$i" for i in 1:q]; ["gamma$i" for i in 1:q]; ["beta$i" for i in 1:p]],
        label = (p, q) -> "GJR-GARCH($p,$q)",
        post_est = :halflife,
        post_fc = :none,
        predict_title = (p, q) -> "GJR-GARCH($p,$q) Conditional Variance",
        resid_title = (p, q) -> "GJR-GARCH($p,$q) Standardized Residuals",
    ),
    (
        name = "sv",
        order = :sv,
        estimate = (y; p=1, q=1, draws=5000) -> estimate_sv(y; n_samples=draws),
        param_names = (p, q) -> String["mu", "phi", "sigma_eta"],
        label = (p, q) -> "SV",
        post_est = :none,
        post_fc = :none,
        predict_title = (p, q) -> "SV Posterior Mean Volatility",
        resid_title = (p, q) -> "SV Standardized Residuals",
    ),
]

function _vol_resolve_model(vol, data::String, column::Int; p::Int=1, q::Int=1,
                             draws::Int=5000, model=nothing)
    if !isnothing(model)
        return model, "series"
    end
    y, vname = load_univariate_series(data, column)
    return vol.estimate(y; p=p, q=q, draws=draws), vname
end

function _vol_post_status(model, kind::Symbol)
    if kind === :halflife || kind === :halflife_uc
        hl = halflife(model)
        _status("Half-life: $(round(hl; digits=2)) periods")
    end
    if kind === :uc || kind === :halflife_uc
        uc = unconditional_variance(model)
        _status("Unconditional variance: $(round(uc; digits=4))")
    end
end

function _make_estimate_vol(vol)
    return function (; data::String, column::Int=1, p::Int=1, q::Int=1, draws::Int=5000,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
        y, vname = load_univariate_series(data, column)
        label = vol.label(p, q)
        if vol.order === :sv
            _status("Estimating Stochastic Volatility: variable=$vname, observations=$(length(y)), draws=$draws")
        else
            _status("Estimating $label: variable=$vname, observations=$(length(y))")
        end
        _status()
        model = vol.estimate(y; p=p, q=q, draws=draws)
        _maybe_plot(model; plot=plot, plot_save=plot_save)
        _vol_estimate_output(model, vname, vol.param_names(p, q), label; format=format, output=output)
        _vol_post_status(model, vol.post_est)
        return model
    end
end

function _make_forecast_vol(vol)
    return function (; data::String="", column::Int=1, p::Int=1, q::Int=1, draws::Int=5000,
                      horizons::Int=12, output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="", model=nothing)
        m, vname = _vol_resolve_model(vol, data, column; p=p, q=q, draws=draws, model=model)
        label = vol.label(p, q)
        if vol.order === :sv
            _status("Stochastic Volatility Forecast: variable=$vname, horizons=$horizons, draws=$draws")
        else
            _status("$label Volatility Forecast: variable=$vname, horizons=$horizons")
        end
        _status()
        fc = forecast(m, horizons)
        _maybe_plot(fc; plot=plot, plot_save=plot_save)
        _vol_forecast_output(fc, vname, label, horizons; format=format, output=output)
        if vol.post_fc !== :none
            _status()
            _vol_post_status(m, vol.post_fc)
        end
        return fc
    end
end

function _make_predict_vol(vol)
    return function (; data::String="", column::Int=1, p::Int=1, q::Int=1, draws::Int=5000,
                      output::String="", format::String="table", model=nothing)
        m, vname = _vol_resolve_model(vol, data, column; p=p, q=q, draws=draws, model=model)
        cond_var = predict(m)
        if vol.order === :sv
            _status("SV posterior mean volatility: variable=$vname, draws=$draws")
        else
            _status("$(vol.label(p, q)) conditional variance: variable=$vname")
        end
        _status()
        pred_df = DataFrame(t=1:length(cond_var), variance=round.(cond_var; digits=6),
                            volatility=round.(sqrt.(cond_var); digits=6))
        output_result(pred_df; format=Symbol(format), output=output,
                      title="$(vol.predict_title(p, q)) ($vname)")
        return cond_var
    end
end

function _make_residuals_vol(vol)
    return function (; data::String="", column::Int=1, p::Int=1, q::Int=1, draws::Int=5000,
                      output::String="", format::String="table", model=nothing)
        m, vname = _vol_resolve_model(vol, data, column; p=p, q=q, draws=draws, model=model)
        resid = residuals(m)
        if vol.order === :sv
            _status("SV standardized residuals: variable=$vname, draws=$draws")
        else
            _status("$(vol.label(p, q)) standardized residuals: variable=$vname")
        end
        _status()
        res_df = DataFrame(t=1:length(resid), residual=round.(resid; digits=6))
        output_result(res_df; format=Symbol(format), output=output,
                      title="$(vol.resid_title(p, q)) ($vname)")
        return resid
    end
end

# Cached per-model handlers (built once at load)
const _VOL_ESTIMATE_HANDLERS = Dict(v.name => _make_estimate_vol(v) for v in VOL_MODELS)
const _VOL_FORECAST_HANDLERS = Dict(v.name => _make_forecast_vol(v) for v in VOL_MODELS)
const _VOL_PREDICT_HANDLERS = Dict(v.name => _make_predict_vol(v) for v in VOL_MODELS)
const _VOL_RESIDUALS_HANDLERS = Dict(v.name => _make_residuals_vol(v) for v in VOL_MODELS)

# Back-compat aliases used by tests / direct handler calls
const _estimate_arch = _VOL_ESTIMATE_HANDLERS["arch"]
const _estimate_garch = _VOL_ESTIMATE_HANDLERS["garch"]
const _estimate_egarch = _VOL_ESTIMATE_HANDLERS["egarch"]
const _estimate_gjr_garch = _VOL_ESTIMATE_HANDLERS["gjr_garch"]
const _estimate_sv = _VOL_ESTIMATE_HANDLERS["sv"]
const _forecast_arch = _VOL_FORECAST_HANDLERS["arch"]
const _forecast_garch = _VOL_FORECAST_HANDLERS["garch"]
const _forecast_egarch = _VOL_FORECAST_HANDLERS["egarch"]
const _forecast_gjr_garch = _VOL_FORECAST_HANDLERS["gjr_garch"]
const _forecast_sv = _VOL_FORECAST_HANDLERS["sv"]
const _predict_arch = _VOL_PREDICT_HANDLERS["arch"]
const _predict_garch = _VOL_PREDICT_HANDLERS["garch"]
const _predict_egarch = _VOL_PREDICT_HANDLERS["egarch"]
const _predict_gjr_garch = _VOL_PREDICT_HANDLERS["gjr_garch"]
const _predict_sv = _VOL_PREDICT_HANDLERS["sv"]
const _residuals_arch = _VOL_RESIDUALS_HANDLERS["arch"]
const _residuals_garch = _VOL_RESIDUALS_HANDLERS["garch"]
const _residuals_egarch = _VOL_RESIDUALS_HANDLERS["egarch"]
const _residuals_gjr_garch = _VOL_RESIDUALS_HANDLERS["gjr_garch"]
const _residuals_sv = _VOL_RESIDUALS_HANDLERS["sv"]

# ── IRF table assembly (F11) ───────────────────────────────

"""
    build_irf_table(irf_data, ci_lower, ci_upper, varnames, shock, horizons=nothing;
                    lower_suffix="_lower", upper_suffix="_upper", digits=nothing) -> DataFrame

Build a single-shock IRF table: `horizon` + one column per variable, optionally with CI bands.

`irf_data` is `H×n×S` (3D) or `H×n` (2D). When 3D, `shock` indexes the third dimension.
`horizons` defaults to `0:(H-1)`; pass an integer `Hmax` for `0:Hmax`, or any iterable of length H.
"""
function build_irf_table(irf_data::AbstractArray, ci_lower, ci_upper,
                         varnames::AbstractVector{<:AbstractString}, shock::Int,
                         horizons=nothing;
                         lower_suffix::String="_lower",
                         upper_suffix::String="_upper",
                         digits::Union{Nothing,Int}=nothing)
    nd = ndims(irf_data)
    nd == 2 || nd == 3 || error("irf_data must be 2D (H×n) or 3D (H×n×S), got ndims=$nd")
    n_h = size(irf_data, 1)
    n_v = length(varnames)

    slice = if nd == 3
        (arr, vi) -> arr[:, vi, shock]
    else
        (arr, vi) -> arr[:, vi]
    end

    hvals = if isnothing(horizons)
        0:(n_h - 1)
    elseif horizons isa Integer
        0:horizons
    else
        horizons
    end
    length(hvals) == n_h || error("horizons length $(length(hvals)) != IRF length $n_h")

    _maybe_round(x) = isnothing(digits) ? x : round.(x; digits=digits)

    irf_df = DataFrame(horizon=collect(hvals))
    for (vi, vname) in enumerate(varnames)
        vi > size(irf_data, 2) && break
        irf_df[!, String(vname)] = _maybe_round(slice(irf_data, vi))
    end
    if !isnothing(ci_lower)
        for (vi, vname) in enumerate(varnames)
            vi > size(ci_lower, 2) && break
            irf_df[!, "$(vname)$(lower_suffix)"] = _maybe_round(slice(ci_lower, vi))
        end
    end
    if !isnothing(ci_upper)
        for (vi, vname) in enumerate(varnames)
            vi > size(ci_upper, 2) && break
            irf_df[!, "$(vname)$(upper_suffix)"] = _maybe_round(slice(ci_upper, vi))
        end
    end
    return irf_df
end

# ── Constants ──────────────────────────────────────────────

"""
    ID_METHOD_MAP

Maps CLI identification method strings to MacroEconometricModels symbols.
"""
const ID_METHOD_MAP = Dict(
    "cholesky"          => :cholesky,
    "sign"              => :sign,
    "narrative"         => :narrative,
    "longrun"           => :long_run,
    "fastica"           => :fastica,
    "jade"              => :jade,
    "sobi"              => :sobi,
    "dcov"              => :dcov,
    "hsic"              => :hsic,
    "student_t"         => :student_t,
    "mixture_normal"    => :mixture_normal,
    "pml"               => :pml,
    "skew_normal"       => :skew_normal,
    "markov_switching"  => :markov_switching,
    "garch_id"          => :garch,
    "uhlig"             => :uhlig,
)

"""
    _load_and_estimate_var(data, lags) -> (model, Y, varnames, p)

Load data from CSV, optionally auto-select lag order, and estimate a frequentist VAR.
"""
function _load_and_estimate_var(data::String, lags)
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    p = if isnothing(lags)
        select_lag_order(Y, min(12, size(Y,1) ÷ (3*n)); criterion=:aic)
    else
        lags
    end

    model = estimate_var(Y, p)
    return model, Y, varnames, p
end

"""
    _load_and_estimate_bvar(data, lags, config, draws, sampler) -> (post, Y, varnames, p, n)

Load data from CSV, build prior, and estimate a Bayesian VAR.
Returns a BVARPosterior (which carries p, n, data internally).
"""
function _load_and_estimate_bvar(data::String, lags::Int, config::String,
                                  draws::Int, sampler::String)
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)
    p = lags

    prior_obj = _build_prior(config, Y, p)
    prior_sym = isnothing(prior_obj) ? :normal : :minnesota

    # Forward --seed as the estimator's own seed (C052/#243): estimate_bvar seeds a
    # fresh MersenneTwister(seed) and records it in the BVARPosterior ReproManifest,
    # so a saved posterior reproduces bit-for-bit. `nothing` → library default RNG.
    post = estimate_bvar(Y, p;
        sampler=Symbol(sampler), n_draws=draws,
        prior=prior_sym, hyper=prior_obj, seed=_SEED[])

    return post, Y, varnames, p, n
end

"""
    _build_prior(config_path, Y, p) -> MinnesotaHyperparameters or nothing

Build a Minnesota prior from TOML config, or return nothing for default prior.
"""
function _build_prior(config_path::String, Y::AbstractMatrix, p::Int)
    if isempty(config_path)
        return nothing
    end
    cfg = load_config(config_path)
    prior_cfg = get_prior(cfg)

    if prior_cfg["type"] == "minnesota"
        if prior_cfg["optimize"]
            _status("Optimizing Minnesota prior hyperparameters...")
            return optimize_hyperparameters(Y, p)
        else
            sigma_ar = ones(size(Y, 2))
            for i in 1:size(Y, 2)
                y = Y[:, i]
                if length(y) > 2
                    X = y[1:end-1]
                    y_dep = y[2:end]
                    b = X \ y_dep
                    resid = y_dep .- X .* b
                    sigma_ar[i] = sqrt(sum(resid .^ 2) / (length(resid) - 1))
                end
            end
            return MinnesotaHyperparameters(;
                tau=prior_cfg["lambda1"],
                decay=prior_cfg["lambda3"],
                lambda=prior_cfg["lambda2"],
                omega=sigma_ar
            )
        end
    end
    return nothing
end

"""
    _build_check_func(config_path) -> (check_func, narrative_check)

Build sign restriction and narrative restriction check functions from TOML config.
Returns `(nothing, nothing)` if no config or no restrictions.
"""
function _build_check_func(config_path::String)
    if isempty(config_path)
        return nothing, nothing
    end
    cfg = load_config(config_path)
    id_cfg = get_identification(cfg)

    check_func = nothing
    narrative_check = nothing

    if haskey(id_cfg, "sign_matrix")
        sign_mat = id_cfg["sign_matrix"]
        horizons = get(id_cfg, "horizons", [0])
        check_func = function(irf_values)
            for h_idx in 1:length(horizons)
                h = horizons[h_idx] + 1  # 1-based indexing
                if h > size(irf_values, 1)
                    continue
                end
                for i in 1:size(sign_mat, 1)
                    for j in 1:size(sign_mat, 2)
                        s = sign_mat[i, j]
                        if s != 0
                            if s > 0 && irf_values[h, j, i] < 0
                                return false
                            elseif s < 0 && irf_values[h, j, i] > 0
                                return false
                            end
                        end
                    end
                end
            end
            return true
        end
    end

    if haskey(id_cfg, "narrative")
        narr = id_cfg["narrative"]
        shock_idx = narr["shock_index"]
        periods = narr["periods"]
        signs = narr["signs"]
        narrative_check = function(structural_shocks)
            for (t, s) in zip(periods, signs)
                if t > size(structural_shocks, 1)
                    continue
                end
                if s > 0 && structural_shocks[t, shock_idx] < 0
                    return false
                elseif s < 0 && structural_shocks[t, shock_idx] > 0
                    return false
                end
            end
            return true
        end
    end

    return check_func, narrative_check
end

"""
    _build_identification_kwargs(id, config) -> Dict{Symbol,Any}

Build the kwargs dict for irf/fevd/historical_decomposition calls
based on identification method and config file.
"""
function _build_identification_kwargs(id::String, config::String)
    method = get(ID_METHOD_MAP, id, :cholesky)
    kwargs = Dict{Symbol,Any}(:method => method)

    check_func, narrative_check = _build_check_func(config)
    if !isnothing(check_func)
        kwargs[:check_func] = check_func
    end
    if !isnothing(narrative_check)
        kwargs[:narrative_check] = narrative_check
    end

    return kwargs
end

"""
    _load_and_structural_lp(data, horizons, lags, var_lags, id, vcov, config;
                            ci_type=:none, reps=200, conf_level=0.95)

Load data, build identification kwargs, and compute structural LP.
Returns `(slp, Y, varnames)`.
"""
function _load_and_structural_lp(data::String, horizons::Int, lags::Int,
                                  var_lags, id::String, vcov::String,
                                  config::String;
                                  ci_type::Symbol=:none, reps::Int=200,
                                  conf_level::Float64=0.95)
    Y, varnames = load_multivariate_data(data)

    method = get(ID_METHOD_MAP, id, :cholesky)
    check_func, narrative_check = _build_check_func(config)

    vp = isnothing(var_lags) ? lags : var_lags

    kwargs = Dict{Symbol,Any}(
        :method => method,
        :lags => lags,
        :var_lags => vp,
        :cov_type => Symbol(vcov),
        :ci_type => ci_type,
        :reps => reps,
        :conf_level => conf_level,
    )
    if !isnothing(check_func)
        kwargs[:check_func] = check_func
    end
    if !isnothing(narrative_check)
        kwargs[:narrative_check] = narrative_check
    end

    slp = structural_lp(Y, horizons; kwargs...)
    return slp, Y, varnames
end

"""
    _load_and_estimate_vecm(data, lags, rank, deterministic, method, significance)
        -> (vecm, Y, varnames, p)

Load data from CSV and estimate a VECM. When rank=="auto", uses select_vecm_rank().
"""
function _load_and_estimate_vecm(data::String, lags::Int, rank::String,
                                  deterministic::String, method::String,
                                  significance::Float64)
    Y, varnames = load_multivariate_data(data)

    r = if rank == "auto"
        select_vecm_rank(Y, lags; significance=significance)
    else
        parse(Int, rank)
    end

    vecm = estimate_vecm(Y, lags; rank=r, deterministic=Symbol(deterministic),
                         method=Symbol(method), significance=significance)
    return vecm, Y, varnames, lags
end

"""
    _var_forecast_point(B, Y, p, horizons) -> Matrix{Float64}

Iterate the VAR(p) equation h steps ahead to produce point forecasts.
B is the coefficient matrix (k × n), Y is the data matrix (T × n).
Returns a (horizons × n) matrix of forecast values.
"""
function _var_forecast_point(B::AbstractMatrix, Y::AbstractMatrix, p::Int, horizons::Int)
    T, n = size(Y)
    has_const = size(B, 1) > n * p

    forecasts = zeros(horizons, n)

    # lag_buf: [Y_T, Y_{T-1}, ..., Y_{T-p+1}] flattened to np vector
    lag_buf = zeros(n * p)
    for lag in 1:p
        lag_buf[(lag-1)*n+1:lag*n] = Y[T-lag+1, :]
    end

    for h in 1:horizons
        x = has_const ? vcat(lag_buf, 1.0) : lag_buf
        y_hat = B' * x
        forecasts[h, :] = y_hat

        # Shift lag buffer forward
        if p > 1
            lag_buf[n+1:end] = lag_buf[1:end-n]
        end
        lag_buf[1:n] = y_hat
    end

    return forecasts
end

# ── Panel VAR Helpers ─────────────────────────────────────

"""
    _parse_varlist(str) -> Vector{String}

Parse a comma-separated variable list string. Returns empty vector for empty input.
"""
function _parse_varlist(str::String)
    isempty(str) && return String[]
    return [strip(s) for s in split(str, ",") if !isempty(strip(s))]
end

"""
    _parse_lag_spec(s, flag; min=0) -> :auto | Int | Vector{Int}

Parse an ARDL/NARDL `--p`/`--q` lag spec: `"auto"` → `:auto`; a bare integer `≥ min` →
`Int`; a comma-separated list `"2,1,3"` → `Vector{Int}` (each `≥ min`). A bad token → typed
`usage/invalid` (never a raw parse throw). `min` is the smallest admissible value (`1` for an
AR order `--p`, `0` for a DL order `--q`). The per-regressor length check (`== k`) is done by
the caller, which knows the regressor count. (C062b)
"""
function _parse_lag_spec(s::AbstractString, flag::String; min::Int=0)
    s == "auto" && return :auto
    if occursin(',', s)
        toks = [strip(t) for t in split(s, ",") if !isempty(strip(t))]
        isempty(toks) && throw(CliError("usage/invalid", "$flag: empty list"))
        out = Int[]
        for t in toks
            v = tryparse(Int, t)
            (v === nothing || v < min) && throw(CliError("usage/invalid",
                "$flag: '$t' must be an integer ≥ $min"))
            push!(out, v)
        end
        return out
    end
    v = tryparse(Int, s)
    (v === nothing || v < min) && throw(CliError("usage/invalid",
        "$flag must be 'auto', an integer ≥ $min, or a comma-separated list of such; got '$s'"))
    return v
end

"""
    _parse_asym_spec(s) -> :all | Vector{Int}

Parse a NARDL `--asymmetric` spec: `"all"` → `:all` (split every regressor); else a
comma-separated list of 1-based regressor indices → `Vector{Int}` (non-empty, each `≥ 1`).
An empty result → typed `usage/invalid` (a fully-symmetric model → use `estimate ardl`). The
upper bound (`≤ k₀`) is checked by the caller, which knows the regressor count. (C062b)
"""
function _parse_asym_spec(s::AbstractString)
    s == "all" && return :all
    idxs = Int[]
    for t in split(s, ",")
        ts = strip(t)
        isempty(ts) && continue
        v = tryparse(Int, ts)
        (v === nothing || v < 1) && throw(CliError("usage/invalid",
            "--asymmetric: '$ts' must be a positive 1-based regressor index (or 'all')"))
        push!(idxs, v)
    end
    isempty(idxs) && throw(CliError("usage/invalid",
        "--asymmetric resolved to no indices; pass 'all' or 1-based indices like '1,3' " *
        "(a fully-symmetric model → use `estimate ardl`)"))
    return idxs
end

"""
    load_panel_data(data, id_col, time_col; varnames=nothing) -> PanelData

Load CSV data and set panel structure using xtset().
"""
function load_panel_data(data::String, id_col::String, time_col::String)
    df = load_data(data)
    id_col in names(df) || throw(CliError("data/missing-column", "id column '$id_col' not found in data (columns: $(join(names(df), ", ")))"))
    time_col in names(df) || throw(CliError("data/missing-column", "time column '$time_col' not found in data (columns: $(join(names(df), ", ")))"))
    # Get numeric variable columns excluding id and time (matches xtset's own
    # num_cols filter; passed explicitly so the panel keeps CLI-facing names).
    varnames = [n for n in variable_names(df) if n != id_col && n != time_col]
    isempty(varnames) && throw(CliError("data/invalid",
        "no numeric variable columns found after excluding id='$id_col'/time='$time_col'; a panel needs at least one numeric variable column"))
    # MEMs 0.7.0 xtset takes (df, group_col::Symbol, time_col::Symbol; ...) and
    # resolves group/time ID mapping internally (C054: the old Matrix/Vector
    # signature was removed upstream). It throws untyped ArgumentErrors on a bad panel
    # structure (duplicate (group,time) pairs, degenerate ids) — map those to a typed
    # data error so bad user input never surfaces as an internal exit-1 (benefits the whole
    # panel family: pvar/cips/hausman/pedroni/kao/westerlund).
    return try
        xtset(df, Symbol(id_col), Symbol(time_col); varnames=varnames)
    catch e
        e isa CliError && rethrow()
        e isa ArgumentError && throw(CliError("data/invalid", "invalid panel structure: $(e.msg)";
            hint="ensure (id, time) pairs are unique and variable columns are numeric"))
        rethrow()
    end
end

"""
    _load_panel_reg(data, id_col, time_col, dep, indep) → (pd, depsym, indepsyms, depc, indeps)

Load a long-format panel CSV and resolve `--dep`/`--indep` to `Symbol`s for the panel
estimators that take `(PanelData, dep, xs...)` — `estimate xtcointreg` (C062a) and, later,
`estimate pmg` / `test pmg-hausman` (C062c). Generalizes `_panel_coint_inputs` (test.jl):
`id`/`time` default to the first/second DATA column, `--dep` defaults to the first panel
variable, and `--indep` defaults to every other variable. Reuses the hardened
`load_panel_data` (typed duplicate-`(id,time)` / non-numeric / missing-column guards) and
validates every resolved name → `usage/invalid`, so bad input never reaches MEMs as an
untyped exit-1.
"""
function _load_panel_reg(data::String, id_col::String, time_col::String,
                         dep::String, indep::String)
    df = load_data(data)
    cols = names(df)
    length(cols) >= 3 || throw(CliError("usage/invalid",
        "panel cointegrating regression needs id, time, and variable column(s) (found $(length(cols)))"))
    id = isempty(id_col) ? cols[1] : id_col
    tc = isempty(time_col) ? cols[2] : time_col
    pd = load_panel_data(data, id, tc)          # typed: data/missing-column, data/invalid
    vars = pd.varnames                          # numeric cols minus id/time (non-empty — load_panel_data guards)
    depc = isempty(dep) ? vars[1] : dep
    depc in vars || throw(CliError("usage/invalid",
        "--dep '$depc' is not a panel variable (have: $(join(vars, ", ")))"))
    indeps = isempty(indep) ? filter(!=(depc), vars) : _parse_varlist(indep)
    isempty(indeps) && throw(CliError("usage/invalid", "need at least one regressor via --indep"))
    for v in indeps
        v in vars || throw(CliError("usage/invalid",
            "--indep '$v' is not a panel variable (have: $(join(vars, ", ")))"))
    end
    # Guard missing cells in the dep + regressor columns: `xtset`/`load_panel_data` silently
    # NaN-fills a blank cell (data/panel.jl `ismissing(v) ? NaN : …`), which would propagate to
    # NaN coefficients at exit 0 — inconsistent with `estimate cointreg`'s `_load_reg_data`,
    # which rejects the same input. Reject it here too (adversarial review C062a).
    for c in vcat([depc], indeps)
        any(ismissing, df[!, c]) && throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them (e.g. via `data dropna`/`data fix`) first"))
    end
    return pd, Symbol(depc), Symbol.(indeps), depc, indeps
end

"""
    _load_and_estimate_pvar(data, id_col, time_col, lags; kwargs...) -> (model, panel, varnames)

Combined load + estimate for Panel VAR.
"""
function _load_and_estimate_pvar(data::String, id_col::String, time_col::String,
                                  lags::Int; method::String="gmm",
                                  transformation::String="fd", steps::String="twostep",
                                  system::Bool=false, collapse::Bool=false,
                                  dependent::String="", predet::String="", exog::String="",
                                  min_lag_endo::Int=2, max_lag_endo::Int=99)
    panel = load_panel_data(data, id_col, time_col)

    dep = _parse_varlist(dependent)
    pre = _parse_varlist(predet)
    exo = _parse_varlist(exog)

    # MEMs 0.7.0 renamed the variable-role kwargs (C054): dependent→dependent_vars,
    # predetermined→predet_vars, exogenous→exog_vars, system→system_instruments.
    # predet_vars/exog_vars are now plain String vectors (empty = none).
    model = if method == "feols"
        estimate_pvar_feols(panel, lags;
            dependent_vars=isempty(dep) ? nothing : dep,
            exog_vars=exo)
    else
        estimate_pvar(panel, lags;
            transformation=Symbol(transformation), steps=Symbol(steps),
            system_instruments=system, collapse=collapse,
            dependent_vars=isempty(dep) ? nothing : dep,
            predet_vars=pre,
            exog_vars=exo,
            min_lag_endo=min_lag_endo, max_lag_endo=max_lag_endo)
    end
    return model, panel, panel.varnames
end

"""
    _build_pvar_coef_table(model, varnames, p) -> DataFrame

Build a coefficient table for Panel VAR model with SE and p-values.
"""
function _build_pvar_coef_table(model, varnames::Vector{String}, p::Int)
    n = length(varnames)
    n_rows = size(model.Phi, 1)
    row_names = String[]
    for lag in 1:p
        for v in varnames
            push!(row_names, "$(v)_L$(lag)")
        end
    end
    if n_rows > n * p
        push!(row_names, "const")
    end

    coef_df = DataFrame()
    for (vi, vname) in enumerate(varnames)
        coef_df[!, Symbol("$(vname)_coef")] = round.(model.Phi[1:length(row_names), vi]; digits=6)
        coef_df[!, Symbol("$(vname)_se")] = round.(model.se[1:length(row_names), vi]; digits=6)
        coef_df[!, Symbol("$(vname)_pval")] = round.(model.pvalues[1:length(row_names), vi]; digits=4)
    end
    insertcols!(coef_df, 1, :parameter => row_names)
    return coef_df
end

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
    isempty(key_indices) && throw(CliError("usage/missing",
        "--key-vars is required for FAVAR";
        hint="comma-separated column names or indices, e.g. --key-vars y,x"))

    # Auto-select factors if not specified
    r = if factors === nothing
        auto_r = ic_criteria(Y, min(10, n - 1))
        _status_styled("  Auto-selected factors: $(auto_r.r_IC1) (IC1)\n"; color=:cyan)
        auto_r.r_IC1
    else
        factors
    end

    _status("Estimating FAVAR: $r factors, $lags lags, method=$method, $(length(key_indices)) key variables")

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
        _status_styled("  Panel: $(pd.n_groups) units, $(div(pd.T_obs, pd.n_groups)) periods\n"; color=:cyan)
        return pd, true
    else
        Y, varnames = load_multivariate_data(data)
        _status("  Matrix: $(size(Y, 1)) obs × $(size(Y, 2)) units")
        return Y, false
    end
end

# ── Plot Helpers ──────────────────────────────────────────

"""
    _maybe_plot(result; plot, plot_save, kwargs...)

Optionally plot a result using MacroEconometricModels' interactive D3.js plotting.
If `plot` is true, opens in browser. If `plot_save` is non-empty, saves to HTML file.
"""
function _maybe_plot(result; plot::Bool=false, plot_save::String="", kwargs...)
    !plot && isempty(plot_save) && return
    _validate_output_path(plot_save)
    # W5/#95 — defence in depth. The rule is still "only advertise --plot when a real
    # plot_result(::that type) EXISTS" (grep the real plotting/ before adding the flags;
    # the mock's generic fallback will not tell you). But an unguarded call here turns any
    # gap — a leaf whose result type lost its recipe at a bump, a plot kwarg the recipe
    # does not accept — into a raw MethodError, i.e. exit 1 "likely a bug", which blames
    # the CLI for a missing upstream method. Map that ONE case to a typed refusal and let
    # every other failure (save/display) propagate untouched so real bugs stay visible.
    p = try
        plot_result(result; kwargs...)
    catch e
        e isa MethodError && (e.f === plot_result) && throw(CliError(
            "model/unsupported",
            "no plot is defined for $(typeof(result))";
            hint="this result type has no plot_result recipe in MacroEconometricModels " *
                 "$(_mems_version_string()); drop --plot/--plot-save, or use --format json " *
                 "and plot the tables yourself"))
        rethrow()
    end
    if !isempty(plot_save)
        save_plot(p, plot_save)
        _status_styled("  Plot saved: $plot_save\n"; color=:green)
    end
    if plot
        display_plot(p)
        _status_styled("  Plot opened in browser\n"; color=:cyan)
    end
end

# ── DSGE Helpers ───────────────────────────────────────────

"""
    _dsge_call(f, args...; kwargs...)

Invoke `f` at the latest world age (`Base.invokelatest`). A representative-agent DSGE
spec loaded from a `.toml`/`.jl` file carries `@dsge`-generated residual functions that
are compiled at load time — i.e. in a *newer* world age than the running handler's
frame. Any MEMs call that **evaluates** those residual functions (steady state,
linearize, solve, DSGE estimation, perfect foresight, OccBin, Bayesian re-solves) must
go through this, or Julia throws a "method too new to be called from this world context"
`MethodError`. Calls that only consume an already-solved solution object (irf/fevd/
simulate/historical_decomposition on a `*Solution`) operate on numeric matrices and do
NOT need this. See the "RA DSGE loader" durable gotcha in CLAUDE.md.
"""
_dsge_call(f, args...; kwargs...) = Base.invokelatest(f, args...; kwargs...)

"""
    _dsge_sandbox() → Module

Fresh module for evaluating a runtime DSGE spec (a `.jl` file or a synthesized `@dsge`
block). The in-scope `MacroEconometricModels` object is injected as a const and its
exports are brought in via a *relative* `using .MacroEconometricModels` — so the bare
`@dsge`/`DSGESpec` names the macro expands to resolve against the injected object rather
than the load path. This is what makes the loader work identically under the real
package and the test mock (which shadows `MacroEconometricModels` in the test session).
"""
function _dsge_sandbox()
    mod = Module()
    Base.eval(mod, :(const MacroEconometricModels = $(MacroEconometricModels)))
    Base.eval(mod, :(using .MacroEconometricModels))
    return mod
end

"""
    _dsge_toml_block(dsge_cfg) → String

Synthesize an `@dsge begin … end` source block from the parsed `[model]` TOML fields
(`get_dsge`): `parameters` (name→value), `endogenous`, `exogenous`, `equations` (already
in `var[t]` form), and the optional `linear` flag. Real MEMs has no keyword `DSGESpec`
constructor — specs are built by the `@dsge` macro, which parses the equations into
callable residual functions — so the TOML path must route through the macro too.
"""
function _dsge_toml_block(dsge_cfg::Dict)
    params = dsge_cfg["parameters"]     # Dict name => value
    endog  = dsge_cfg["endogenous"]     # Vector{String}
    exog   = dsge_cfg["exogenous"]      # Vector{String}
    eqs    = dsge_cfg["equations"]      # Vector{String}
    is_linear = Bool(get(dsge_cfg, "linear", false))

    lines = String[]
    if !isempty(params)
        push!(lines, "    parameters: " * join(["$k = $v" for (k, v) in params], ", "))
    end
    push!(lines, "    endogenous: " * join(endog, ", "))
    isempty(exog) || push!(lines, "    exogenous: " * join(exog, ", "))
    is_linear && push!(lines, "    linear: true")
    push!(lines, "")
    for eq in eqs
        push!(lines, "    " * eq)
    end
    return "@dsge begin\n" * join(lines, "\n") * "\nend"
end

"""
    _load_dsge_model(path) → DSGESpec

Load a representative-agent DSGE model from a `.toml` or `.jl` file.

- `.toml`: parse `[model]` (incl. optional `linear = true` → `DSGESpec.linear`) and
  build the spec by synthesizing an `@dsge` block from the equations ([`_dsge_toml_block`]).
- `.jl`: last expression must be a `DSGESpec` — typically the file is an `@dsge begin … end`
  block. The sandbox pre-imports MEMs' exports, so the file may use `@dsge`/`DSGESpec`
  unqualified without its own `using MacroEconometricModels`.

Both paths compile the spec's residual functions at load time; every downstream MEMs
call that evaluates them must go through [`_dsge_call`] (world-age barrier).

If a `.jl` file evaluates to `HADSGESpec`, throw `usage/wrong-command` (exit 2)
pointing the user at `dsge ha …` — never crash downstream (C046 / P4-9).
"""
function _load_dsge_model(path::String)
    _validate_input_path(path)
    isfile(path) || throw(CliError("data/file-not-found", "model file not found: $path"))
    ext = lowercase(splitext(path)[2])

    if ext == ".toml"
        config = load_config(path)
        dsge_cfg = get_dsge(config)

        isempty(dsge_cfg["endogenous"]) && throw(CliError("config/invalid",
            "TOML model must have [model] with endogenous variables"))
        isempty(dsge_cfg["equations"]) && throw(CliError("config/invalid",
            "TOML model must have [[model.equations]]"))

        is_linear = Bool(get(dsge_cfg, "linear", false))
        block = _dsge_toml_block(dsge_cfg)
        mod = _dsge_sandbox()
        spec = try
            include_string(mod, block)
        catch e
            throw(CliError("config/invalid",
                "could not build a DSGE spec from the TOML model — check [[model.equations]]" *
                " and [model] parameters/endogenous/exogenous: $(sprint(showerror, e))"))
        end
        spec isa MacroEconometricModels.DSGESpec || throw(CliError("config/invalid",
            "TOML model did not build a DSGESpec (got $(typeof(spec)))"))

        lin_note = is_linear ? ", linear=true" : ""
        _status("Loaded DSGE model from TOML: $(length(dsge_cfg["endogenous"])) endogenous, $(length(dsge_cfg["exogenous"])) exogenous, $(length(dsge_cfg["equations"])) equations$lin_note")
        return spec

    elseif ext == ".jl"
        mod = _dsge_sandbox()
        result = Base.include(mod, path)
        if result isa MacroEconometricModels.HADSGESpec
            throw(CliError("usage/wrong-command",
                "this is a heterogeneous-agent spec — use `dsge ha …`",
                hint="e.g. friedman dsge ha solve $(path) --method reiter"))
        end
        result isa MacroEconometricModels.DSGESpec || throw(CliError("config/invalid",
            ".jl model file must evaluate to a DSGESpec (last expression), got $(typeof(result))"))
        spec = result
        lin_note = (hasproperty(spec, :linear) && spec.linear) ? ", linear=true" : ""
        _status("Loaded DSGE model from Julia file: $(spec.n_endog) endogenous, $(spec.n_exog) exogenous$lin_note")
        return spec

    else
        throw(CliError("usage/invalid-option",
            "unsupported model file extension '$ext' — use .toml or .jl"))
    end
end

# ── HA-DSGE Helpers (C040 / MEMs 0.6.7) ───────────────────

const _HA_BUILTIN_MODELS = (
    "krusell-smith" => :krusell_smith,
    "one-asset-hank" => :one_asset_hank,
    "two-asset-hank" => :two_asset_hank,
    "huggett" => :huggett,
)

const _HA_METHOD_MAP = Dict(
    "ssj" => :ssj,
    "reiter" => :reiter,
    "krusell-smith" => :krusell_smith,
    "krusell_smith" => :krusell_smith,
)

"""
    _parse_ha_method(method) → Symbol

Map CLI method string to MEMs symbol (`:ssj`, `:reiter`, `:krusell_smith`).
"""
function _parse_ha_method(method::String)
    key = lowercase(strip(method))
    haskey(_HA_METHOD_MAP, key) || throw(CliError("usage/invalid-option",
        "invalid --method '$method'; must be one of: ssj, reiter, krusell-smith"))
    return _HA_METHOD_MAP[key]
end

"""
    _ha_builtin_symbol(name) → Union{Symbol,Nothing}

Normalize CLI builtin model token (`huggett`, `:huggett`, `krusell-smith`) to MEMs Symbol.
"""
function _ha_builtin_symbol(name::String)
    s = lowercase(strip(name))
    startswith(s, ":") && (s = s[2:end])
    s = replace(s, "_" => "-")
    for (cli, sym) in _HA_BUILTIN_MODELS
        s == cli && return sym
    end
    return nothing
end

"""
    _load_ha_model(model) → HADSGESpec

Load HA-DSGE model from a builtin name (`huggett`, `krusell-smith`, …) or a `.jl`
file that evaluates to `HADSGESpec`.
"""
function _load_ha_model(model::String)
    isempty(strip(model)) && throw(CliError("usage/missing-arg",
        "HA model is required (builtin name or path to .jl HADSGESpec)"))

    bsym = _ha_builtin_symbol(model)
    if bsym !== nothing
        _status("Loading HA-DSGE builtin :$bsym via load_ha_example")
        return MacroEconometricModels.load_ha_example(bsym)
    end

    _validate_input_path(model)
    isfile(model) || throw(CliError("data/file-not-found",
        "HA model file not found: $model (hint: use a builtin name like huggett, " *
        "or a .jl file evaluating to HADSGESpec)"))
    ext = lowercase(splitext(model)[2])
    ext == ".jl" || throw(CliError("usage/invalid-option",
        "HA model file must be .jl (got '$ext'); builtins: " *
        join(first.( _HA_BUILTIN_MODELS), ", ")))

    mod = Module()
    Base.eval(mod, :(const MacroEconometricModels = $(MacroEconometricModels)))
    result = Base.include(mod, model)
    if result isa MacroEconometricModels.DSGESpec
        throw(CliError("usage/wrong-command",
            "this is a representative-agent DSGESpec — use `dsge solve|irf|…`, not `dsge ha`",
            hint="e.g. friedman dsge solve $(model)"))
    end
    result isa MacroEconometricModels.HADSGESpec || throw(CliError("config/invalid",
        ".jl HA model must evaluate to HADSGESpec, got $(typeof(result))"))
    _status("Loaded HADSGESpec from Julia file (model=$(result.model))")
    return result
end

"""
    _solve_ha(spec; method=:ssj, kwargs...) → HADSGESolution | KrusellSmithSolution

Compute steady state (unless `ss` supplied) then solve with the HA method.
"""
function _solve_ha(spec::MacroEconometricModels.HADSGESpec;
                   method::Symbol=:ssj,
                   ss=nothing,
                   n_reduced::Int=30,
                   T_horizon::Int=300,
                   kwargs...)
    if ss === nothing
        _status("Computing HA steady state...")
        # Only pass steady-state kwargs (MEMs filters the rest inside solve,
        # but we call compute_steady_state separately and must not forward
        # n_reduced / T_horizon here).
        ss_keys = (:K_init, :r_bounds, :max_iter, :tol, :verbose, :price_fn, :clearing)
        ss_kw = Dict{Symbol,Any}()
        for k in ss_keys
            haskey(kwargs, k) && (ss_kw[k] = kwargs[k])
        end
        ss = MacroEconometricModels.compute_steady_state(spec; ss_kw...)
        if hasproperty(ss, :converged)
            _status_styled("  Steady state converged: $(ss.converged)\n";
                           color = ss.converged ? :green : :yellow)
        end
    end
    _status("Solving HA-DSGE with method=$method...")
    sol = MacroEconometricModels.solve(spec; method=method, ss=ss,
                                       n_reduced=n_reduced, T_horizon=T_horizon,
                                       kwargs...)
    return sol
end

"""
    _solve_dsge(spec; method="gensys", order=1, degree=5, grid="auto", constraint_solver="") → solution

Solve a DSGE model: compute steady state → linearize → solve.
Returns DSGESolution, PerturbationSolution, or ProjectionSolution.
"""
function _solve_dsge(spec::MacroEconometricModels.DSGESpec;
                     method::String="gensys", order::Int=1,
                     degree::Int=5, grid::String="auto",
                     constraint_solver::String="")
    _status("Computing steady state...")
    ss_kw = isempty(constraint_solver) ? (;) : (; solver=Symbol(constraint_solver))
    # World-age barrier: a runtime-loaded spec's @dsge residual fns are "too new" for
    # this frame — every MEMs call that evaluates them must go through _dsge_call.
    spec = _dsge_call(compute_steady_state, spec; ss_kw...)

    _status("Linearizing model...")
    _dsge_call(linearize, spec)

    _status("Solving with method=$method" *
            (method == "perturbation" ? ", order=$order" : "") *
            (method in ("projection", "pfi") ? ", degree=$degree, grid=$grid" : "") *
            "...")

    solve_kw = isempty(constraint_solver) ? (;) : (; solver=Symbol(constraint_solver))
    sol = _dsge_call(solve, spec; method=Symbol(method), order=order,
                degree=degree, grid=Symbol(grid), solve_kw...)

    # Report diagnostics
    if sol isa MacroEconometricModels.DSGESolution ||
       sol isa MacroEconometricModels.PerturbationSolution
        det_status = is_determined(sol) ? "unique" : "indeterminate"
        stab_status = is_stable(sol) ? "stable" : "unstable"
        _status_styled("  Determinacy: $det_status\n"; color = is_determined(sol) ? :green : :red)
        _status_styled("  Stability: $stab_status\n"; color = is_stable(sol) ? :green : :red)
    end

    return sol
end

"""
    _load_dsge_constraints(path; spec=nothing) → Vector{constraint}

Load OccBin and/or nonlinear constraints from a TOML file.
Nonlinear constraints require a loaded DSGE spec.
"""
function _load_dsge_constraints(path::String; spec=nothing)
    config = load_config(path)
    con_cfg = get_dsge_constraints(config)

    has_bounds = !isempty(get(con_cfg, "bounds", []))
    has_nonlinear = !isempty(get(con_cfg, "nonlinear", []))

    if has_nonlinear && spec === nothing
        error("nonlinear constraints require a loaded DSGE spec (pass spec keyword)")
    end

    constraints = Any[]

    if has_bounds
        for b in con_cfg["bounds"]
            lower = get(b, "lower", -Inf)
            c = variable_bound(Symbol(b["variable"]); lower=lower,
                               upper=get(b, "upper", Inf))
            push!(constraints, c)
        end
    end

    if has_nonlinear
        for nl in con_cfg["nonlinear"]
            # parse_constraint compiles against the spec's residual fns → world-age barrier
            c = _dsge_call(parse_constraint, nl["expr"], spec)
            push!(constraints, c)
        end
    end

    return constraints
end

"""
    _load_panel_for_did(data, id_col, time_col) -> PanelData

Load panel CSV and print summary for DID/event study commands.
"""
function _load_panel_for_did(data::String, id_col::String, time_col::String)
    pd = load_panel_data(data, id_col, time_col)
    _status_styled("  Panel: $(pd.n_groups) groups, $(div(pd.T_obs, pd.n_groups)) periods, " *
                "$(pd.n_vars) variables"; color=:cyan)
    pd.balanced && _status_styled(" (balanced)"; color=:cyan)
    _status()
    return pd
end

# ── Regression Helpers ────────────────────────────────────

"""
    _load_reg_data(data, dep; weights_col="", clusters_col="") → (y, X, varnames)

Load CSV, split into dependent variable y and regressor matrix X.
If dep is empty, uses first numeric column as y.
"""
function _load_reg_data(data::String, dep::String; weights_col::String="", clusters_col::String="")
    df = load_data(data)
    numcols = variable_names(df)
    # Guard an all-non-numeric CSV before defaulting `--dep` to numcols[1] (else BoundsError →
    # untyped exit-1). Mirrors the same fix in `_load_xy_data`/`_load_iv_data` (adversarial review).
    isempty(numcols) && throw(CliError("data/invalid", "no numeric columns found in the data"))

    dep_col = isempty(dep) ? numcols[1] : dep
    # C067a: typed errors, not bare `error()` — a bad `--dep` or a degenerate column set
    # is user input (exit 3), not a CLI bug (exit 1). Benefits the whole cross-section reg
    # family (reg/iv/logit/probit/ologit/oprobit/mlogit/predict/residuals) that shares this.
    !isempty(dep) && !(dep_col in numcols) && throw(CliError("data/column-range",
        "dependent variable '$dep_col' not found in numeric columns: $(join(numcols, ", "))"))

    exclude = Set([dep_col])
    !isempty(weights_col) && push!(exclude, weights_col)
    !isempty(clusters_col) && push!(exclude, clusters_col)
    xcols = filter(c -> !(c in exclude), numcols)
    isempty(xcols) && throw(CliError("data/invalid",
        "no regressor columns remaining after excluding dep='$dep_col'"))

    # Guard missing cells BEFORE the Vector/Matrix{Float64} conversion (which throws an
    # untyped ArgumentError → exit-1). `_numeric_column_names` admits Union{Missing,…}
    # columns, so a single blank cell in dep or any regressor reaches here. Mirror the
    # univariate/multivariate loaders' typed guard for the whole reg family.
    for c in vcat([dep_col], xcols)
        any(ismissing, df[!, c]) && throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them (e.g. via `data dropna`/`data fix`) first"))
    end
    y = Vector{Float64}(df[!, dep_col])
    X = Matrix{Float64}(df[!, xcols])
    return y, X, xcols
end

"""
    _load_iv_data(data, dep, endogenous, instruments)
        → (; y, X, Z, xcols, zcols, endog_idx, endog_names, inst_names, dep_col)

Shared IV/2SLS data loader for `estimate iv` and `test weak-instrument`, using the standard
(Stata `ivregress`) column partition. `--instruments` lists the **excluded** instruments
only; every other numeric column (besides `--dep` and `--endogenous`) is an exogenous
regressor (include a `const` column of ones for an intercept, matching `estimate reg`). So:

* `X` (regressors) = all numeric \\ ({dep} ∪ excluded-instruments) — exogenous + endogenous;
* `Z` (instruments) = all numeric \\ ({dep} ∪ endogenous) — exogenous + excluded instruments.

This keeps the excluded instruments OUT of the structural regressor matrix. The previous
`X = all-except-dep` layout let them leak into `X`, so MEMs raised an untyped
`Order condition violated (m < k)` on any real multi-instrument IV → uncaught exit-1 (C067b
fix; there was no T3 coverage for `estimate iv`).

All failure modes are TYPED CliErrors, never a bare `error()`: missing `--endogenous`/
`--instruments` → `usage/missing` (2); an unknown column, dep listed as endog/instr, a
column named as both endogenous and instrument, or an endogenous not among the regressors →
`data/column-range` (3); fewer excluded instruments than endogenous regressors (order
condition) or a degenerate regressor set → `data/invalid` (3); a missing cell in any
consumed column → `data/missing-values` (3), guarded BEFORE the `Matrix{Float64}`
conversion that would otherwise throw an untyped `ArgumentError`.
"""
function _load_iv_data(data::String, dep::String, endogenous::String, instruments::String)
    isempty(endogenous) && throw(CliError("usage/missing",
        "--endogenous is required (comma-separated endogenous regressor column names)"))
    isempty(instruments) && throw(CliError("usage/missing",
        "--instruments is required (comma-separated EXCLUDED instrument column names)"))

    df = load_data(data)
    numcols = variable_names(df)
    isempty(numcols) && throw(CliError("data/invalid", "no numeric columns found in the data"))

    dep_col = isempty(dep) ? numcols[1] : dep
    !isempty(dep) && !(dep_col in numcols) && throw(CliError("data/column-range",
        "dependent variable '$dep_col' not found in numeric columns: $(join(numcols, ", "))"))

    endog_names = String[strip(s) for s in split(endogenous, ",") if !isempty(strip(s))]
    inst_names  = String[strip(s) for s in split(instruments, ",") if !isempty(strip(s))]
    isempty(endog_names) && throw(CliError("usage/missing",
        "--endogenous is required (comma-separated endogenous regressor column names)"))
    isempty(inst_names) && throw(CliError("usage/missing",
        "--instruments is required (comma-separated EXCLUDED instrument column names)"))
    for nm in endog_names
        nm in numcols || throw(CliError("data/column-range",
            "endogenous variable '$nm' not found in numeric columns: $(join(numcols, ", "))"))
        nm == dep_col && throw(CliError("data/column-range",
            "endogenous variable '$nm' cannot be the dependent variable"))
    end
    for nm in inst_names
        nm in numcols || throw(CliError("data/column-range",
            "instrument '$nm' not found in numeric columns: $(join(numcols, ", "))"))
        nm == dep_col && throw(CliError("data/column-range",
            "instrument '$nm' cannot be the dependent variable"))
    end
    overlap = intersect(endog_names, inst_names)
    isempty(overlap) || throw(CliError("data/column-range",
        "column(s) $(join(overlap, ", ")) listed as both --endogenous and --instruments (an endogenous regressor cannot be its own excluded instrument)"))
    # Order condition (m ≥ k reduces to |excluded| ≥ |endogenous| here): a clearer message
    # than the wrapped MEMs `Order condition violated`.
    length(inst_names) >= length(endog_names) || throw(CliError("data/invalid",
        "under-identified: need at least as many excluded instruments ($(length(inst_names))) as endogenous regressors ($(length(endog_names)))"))

    # X = exogenous + endogenous (exclude dep and the excluded instruments).
    xcols = filter(c -> c != dep_col && !(c in inst_names), numcols)
    isempty(xcols) && throw(CliError("data/invalid",
        "no regressor columns remaining after excluding dep='$dep_col' and the instruments"))
    # Z = exogenous + excluded instruments (exclude dep and the endogenous regressors).
    zcols = filter(c -> c != dep_col && !(c in endog_names), numcols)

    endog_idx = Int[]
    for nm in endog_names
        i = findfirst(==(nm), xcols)
        i === nothing && throw(CliError("data/column-range",
            "endogenous variable '$nm' is not among the regressors"))
        push!(endog_idx, i)
    end

    for c in unique(vcat([dep_col], xcols, zcols))
        any(ismissing, df[!, c]) && throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them (e.g. via `data dropna`/`data fix`) first"))
    end

    y = Vector{Float64}(df[!, dep_col])
    X = Matrix{Float64}(df[!, xcols])
    Z = Matrix{Float64}(df[!, zcols])
    # Guard the degenerate more-instruments-than-observations regime up front: with m ≥ n the
    # first-stage F has non-positive df → MEMs returns a NaN diagnostic (and `robust_inv`
    # silently pinv's the rank-deficient Z'Z rather than throwing), yielding meaningless
    # estimates. A clear typed error beats a NaN verdict downstream (adversarial-review fix).
    size(Z, 2) < length(y) || throw(CliError("data/invalid",
        "too many instruments: the instrument set Z has $(size(Z, 2)) columns but only $(length(y)) observations (need m < n for an identified first stage)"))
    return (; y, X, Z, xcols, zcols, endog_idx, endog_names, inst_names, dep_col)
end

"""
    _load_xy_data(data, dep, indep) → (y, x, ynm, xnm)

Shared response/single-predictor loader for the nonparametric-regression leaves
(`estimate kernel-reg`, `estimate lowess`, C066). `--dep` (default: first numeric column)
is the response `y`; `--indep` (required) is a SINGLE predictor `x`. The 6th shared-loader
hardening: every failure is a TYPED `CliError`, never a bare `error()` (untyped exit-1).
Missing `--indep` → `usage/missing`; an unknown dep/indep column, or dep==indep →
`data/column-range`; a missing cell in either column → `data/missing-values`, guarded
BEFORE the `Vector{Float64}` conversion that would otherwise throw an untyped
`ArgumentError`. Returns `(Vector{Float64} y, Vector{Float64} x, dep_name, indep_name)`.
"""
function _load_xy_data(data::String, dep::String, indep::String)
    isempty(indep) && throw(CliError("usage/missing",
        "--indep is required (the single predictor column name)"))
    df = load_data(data)
    numcols = variable_names(df)
    isempty(numcols) && throw(CliError("data/invalid",
        "no numeric columns found in the data"))
    dep_col = isempty(dep) ? numcols[1] : dep
    !isempty(dep) && !(dep_col in numcols) && throw(CliError("data/column-range",
        "response variable '$dep_col' not found in numeric columns: $(join(numcols, ", "))"))
    indep in numcols || throw(CliError("data/column-range",
        "predictor '$indep' not found in numeric columns: $(join(numcols, ", "))"))
    indep == dep_col && throw(CliError("data/column-range",
        "predictor '$indep' cannot equal the response '$dep_col'"))
    for c in (dep_col, indep)
        any(ismissing, df[!, c]) && throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them (e.g. via `data dropna`/`data fix`) first"))
    end
    y = Vector{Float64}(df[!, dep_col])
    x = Vector{Float64}(df[!, indep])
    return y, x, dep_col, indep
end

"""
    _parse_bandwidth(s, syms) → Union{Symbol,Real}

Parse a `--bw` argument for the nonparametric leaves (C066): a string matching one of the
allowed rule names in `syms` (e.g. `(:silverman, :sj)` or `(:cv, :rot)`) → that `Symbol`;
otherwise a positive number. Junk, a non-number, or a non-positive value → a typed
`usage/invalid` error (never a raw MEMs `ArgumentError`). Mirrors `_parse_penalty_lambda`.
"""
function _parse_bandwidth(s::AbstractString, syms::Tuple)
    for sym in syms
        s == string(sym) && return sym
    end
    v = tryparse(Float64, s)
    # Reject non-finite too: `Inf`/`NaN` slip past a bare `v <= 0` (both compare false), then
    # either produce a degenerate fit with a non-finite bandwidth or hit MEMs' `h > 0` with the
    # WRONG error class (a bad CLI arg must be usage/invalid, not data/invalid).
    (v === nothing || !isfinite(v) || v <= 0) && throw(CliError("usage/invalid",
        "--bw must be one of $(join(syms, '|')) or a positive number, got '$s'"))
    return v
end

"""Load cluster assignments from a CSV column, or return nothing."""
function _load_clusters(data::String, clusters_col::String)
    isempty(clusters_col) && return nothing
    df = load_data(data)
    clusters_col in names(df) || error("cluster column '$clusters_col' not found")
    return Vector{Int}(df[!, clusters_col])
end

"""Load observation weights from a CSV column, or return nothing."""
function _load_weights(data::String, weights_col::String)
    isempty(weights_col) && return nothing
    df = load_data(data)
    weights_col in names(df) || error("weights column '$weights_col' not found")
    return Vector{Float64}(df[!, weights_col])
end

"""Build coefficient table DataFrame from a regression model."""
function _reg_coef_table(model, varnames::Vector{String})
    # C051: MEMs renders coefficient-bearing models (RegModel/Logit/Probit/IV, which the
    # CLI estimates with varnames=xcols) as a tidy coef table via Tables.jl — term|estimate|
    # std_error|stat|p_value|ci_lower|ci_upper. `varnames` is retained for the call sites
    # but the names now come from the model itself.
    DataFrame(model)
end

# --- Panel Regression Shared Helpers (v0.4.0) ---

"""Load panel CSV for panel regression. Returns PanelData."""
function _load_panel_for_preg(data::String, id_col::String, time_col::String)
    df = load_data(data)
    cols = names(df)
    id = isempty(id_col) ? cols[1] : id_col
    tc = isempty(time_col) ? cols[2] : time_col
    pd = load_panel_data(data, id, tc)
    _status_styled("  Panel: $(pd.n_groups) groups, $(pd.n_vars) variables"; color=:cyan)
    pd.balanced && _status_styled(" (balanced)"; color=:cyan)
    _status()
    return pd
end

"""Parse indep vars from comma-separated string. If empty, infer from all non-dep numeric cols."""
function _parse_indep_vars(pd, dep::String, indep_str::String)
    if isempty(indep_str)
        all_vars = pd.varnames
        return Symbol[Symbol(v) for v in all_vars if v != dep]
    else
        return Symbol[Symbol(strip(s)) for s in split(indep_str, ",")]
    end
end

"""Convert CLI option value with hyphens to MEMs Symbol with underscores."""
_to_sym(s::String) = Symbol(replace(s, "-" => "_"))

"""Build coefficient table from panel regression model."""
function _preg_coef_table(model, varnames::Vector{String})
    # C051: MEMs renders panel coefficient models (PanelReg/IV/Logit/Probit) as a tidy
    # coef table via Tables.jl (term|estimate|std_error|stat|p_value|ci_lower|ci_upper).
    # `varnames` retained for the call sites; names now come from the model.
    DataFrame(model)
end
