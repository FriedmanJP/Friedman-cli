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

# Wave 2 (#314 / MEMs v1.1.1 GDFM expansion):
#   - estimate/predict/residuals factor fhlz        (FHLZModel)
#   - estimate/predict/residuals/forecast factor gdfm-i1
#     + irf/fevd/hd gdfm-i1                         (CointegratedGDFM)
#   - estimate/predict/residuals factor tv-gdfm     (TimeVaryingGDFM)
#   - test factor onatski-q|ahn-horenstein|onatski-ed
#     (OnatskiQTestResult, AhnHorensteinResult, OnatskiEDResult)
#   - filter bandpass-gdfm|eurocoin                 (BandPassGDFMResult, EurocoinResult)
#   - spectral fevd                                 (SpectralFEVDResult)
#   - nowcast gdfm                                  (GDFMNowcastResult)

# ── Shared Wave-2 Helpers ─────────────────────────────────────

const _W2_GDFM_KERNELS = ("bartlett", "parzen", "tukey")
const _W2_ONATSKI_KERNELS = Dict(
    "bartlett"      => :bartlett,
    "parzen"        => :parzen,
    "tukey-hanning" => :tukey_hanning,
)
const _W2_TV_TIME_KERNELS = ("epanechnikov", "gaussian", "uniform")
const _W2_GDFM_I1_IDS = Dict(
    "permanent-transitory" => :permanent_transitory,
    "cholesky"             => :cholesky,
    "longrun"              => :long_run,
    "long-run"             => :long_run,
    "sign"                 => :sign,
    "proxy"                => :proxy,
)
const _W2_GDFM_I1_DET_TRENDS = Dict(
    "none"     => :none,
    "constant" => :constant,
    "linear"   => :linear,
    "trend"    => :linear,
)

"""Return a finite copy of `X` strictly for automatic factor-rank IC selection when
`X` contains missing/NaN entries (ragged edges). Complete rows are preferred when
at least `max(10, N + 2)` rows are complete; otherwise NaN cells are replaced by
their finite column means (or 0.0). The original ragged `X` is still passed to
the EM estimator."""
function _w2_complete_for_ic(X::Matrix{Float64})::Matrix{Float64}
    any(isnan, X) || return X
    T_obs, N = size(X)
    complete = [all(isfinite, @view(X[t, :])) for t in 1:T_obs]
    if count(complete) >= max(10, N + 2)
        return X[complete, :]
    end
    X_fill = copy(X)
    for j in 1:N
        col = @view X_fill[:, j]
        fin = [v for v in col if isfinite(v)]
        mu = isempty(fin) ? 0.0 : mean(fin)
        @inbounds for i in 1:T_obs
            isfinite(X_fill[i, j]) || (X_fill[i, j] = mu)
        end
    end
    return X_fill
end

"""Auto-select dynamic factor rank `q` via `ic_criteria_gdfm`."""
function _w2_auto_q(X::Matrix{Float64})::Int
    X_ic = _w2_complete_for_ic(X)
    max_q = min(5, max(1, size(X_ic, 2) - 1))
    ic = ic_criteria_gdfm(X_ic, max_q)
    return max(1, Int(ic.q_ratio))
end

"""Auto-select static factor rank `r` via `ic_criteria`, floored at `q`."""
function _w2_auto_r(X::Matrix{Float64}, q::Int)::Int
    X_ic = _w2_complete_for_ic(X)
    max_r = min(20, max(1, size(X_ic, 2) - 1))
    ic = ic_criteria(X_ic, max_r)
    return max(q, min(size(X, 2), Int(ic.r_IC1)))
end

"""Resolve angular frequency band `(w_lo, w_hi) ⊆ [0, π]` from explicit
`--band-low`/`--band-high` radians or period bounds `--pl`/`--pu` (`[2π/pu, 2π/pl]`)."""
function _w2_parse_band(pl, pu, band_low, band_high,
                        default_pl::Float64, default_pu::Float64,
                        leaf::String)::Tuple{Float64,Float64}
    if band_low !== nothing || band_high !== nothing
        (band_low !== nothing && band_high !== nothing) || throw(CliError("usage/invalid",
            "$leaf: --band-low and --band-high must be supplied together"))
        lo = Float64(band_low)
        hi = Float64(band_high)
        (isfinite(lo) && isfinite(hi) && 0.0 <= lo < hi <= Float64(π) + 1e-12) || throw(CliError(
            "usage/invalid",
            "$leaf: angular band must satisfy 0 <= --band-low < --band-high <= pi (got [$lo, $hi])"))
        return (lo, min(hi, Float64(π)))
    end
    p_lo = pl === nothing ? default_pl : Float64(pl)
    p_hi = pu === nothing ? default_pu : Float64(pu)
    (isfinite(p_lo) && isfinite(p_hi) && p_lo >= 2.0 && p_hi > p_lo) || throw(CliError(
        "usage/invalid",
        "$leaf: period bounds must satisfy 2 <= --pl < --pu (got pl=$p_lo, pu=$p_hi)"))
    return (2.0 * Float64(π) / p_hi, min(2.0 * Float64(π) / p_lo, Float64(π)))
end

function _w2_resolve_seed(seed)
    seed === nothing ? _SEED[] : Int(seed)
end

function _w2_validate_kernel(kernel::String, leaf::String)::Symbol
    kernel in _W2_GDFM_KERNELS || throw(CliError("usage/invalid",
        "$leaf: --kernel must be bartlett|parzen|tukey (got '$kernel')"))
    return Symbol(kernel)
end

function _w2_validate_lag_criterion(crit::String, leaf::String)::Symbol
    crit in ("bic", "aic") || throw(CliError("usage/invalid",
        "$leaf: --lag-criterion must be bic|aic (got '$crit')"))
    return Symbol(crit)
end

"""Shared data-loading and estimation helper for `FHLZModel`."""
function _w2_load_and_estimate_fhlz(data::String, dynamic_rank, bandwidth::Int,
                                    kernel::String, p_max::Int, lag_criterion::String,
                                    n_perm::Int, irf_horizon::Int,
                                    allow_missing::Bool, em_max_iter::Int,
                                    em_tol::Float64, no_standardize::Bool,
                                    seed, leaf::String)
    k_sym = _w2_validate_kernel(kernel, leaf)
    lc_sym = _w2_validate_lag_criterion(lag_criterion, leaf)
    bandwidth >= 0 || throw(CliError("usage/invalid", "$leaf: --bandwidth must be >= 0 (got $bandwidth)"))
    p_max >= 1 || throw(CliError("usage/invalid", "$leaf: --p-max must be >= 1 (got $p_max)"))
    n_perm >= 1 || throw(CliError("usage/invalid", "$leaf: --n-perm must be >= 1 (got $n_perm)"))
    irf_horizon >= 1 || throw(CliError("usage/invalid", "$leaf: --irf-horizon must be >= 1 (got $irf_horizon)"))
    em_max_iter >= 1 || throw(CliError("usage/invalid", "$leaf: --em-max-iter must be >= 1 (got $em_max_iter)"))
    em_tol > 0 || throw(CliError("usage/invalid", "$leaf: --em-tol must be > 0 (got $em_tol)"))

    X, varnames = load_multivariate_data(data; allow_nan=allow_missing)
    q = if dynamic_rank === nothing
        _status("Selecting dynamic rank...")
        q_opt = _w2_auto_q(X)
        _status("  Auto-selected $q_opt dynamic factors")
        q_opt
    else
        Int(dynamic_rank)
    end
    q >= 1 || throw(CliError("usage/invalid", "$leaf: --dynamic-rank must be >= 1 (got $q)"))

    eff_seed = _w2_resolve_seed(seed)
    model = try
        estimate_gdfm_fhlz(X, q;
            bandwidth=bandwidth, kernel=k_sym, p_max=p_max, lag_criterion=lc_sym,
            n_perm=n_perm, irf_horizon=irf_horizon, standardize=!no_standardize,
            varnames=varnames, seed=eff_seed, allow_missing=allow_missing,
            em_max_iter=em_max_iter, em_tol=em_tol)
    catch e
        throw(_domain_or_data_error(e, "FHLZ GDFM estimation"))
    end
    return model, X, varnames, q
end

"""Shared data-loading and estimation helper for `CointegratedGDFM`."""
function _w2_load_and_estimate_gdfm_i1(data::String, dynamic_rank, n_permanent,
                                       id::String, det_trend::String, p_max::Int,
                                       n_perm::Int, bandwidth::Int, kernel::String,
                                       lag_criterion::String, irf_horizon::Int,
                                       config::String, instrument_col::String,
                                       no_standardize::Bool, seed, leaf::String)
    haskey(_W2_GDFM_I1_IDS, id) || throw(CliError("usage/invalid",
        "$leaf: --id must be permanent-transitory|cholesky|longrun|sign|proxy (got '$id')"))
    haskey(_W2_GDFM_I1_DET_TRENDS, det_trend) || throw(CliError("usage/invalid",
        "$leaf: --det-trend must be none|constant|linear|trend (got '$det_trend')"))
    k_sym = _w2_validate_kernel(kernel, leaf)
    lc_sym = _w2_validate_lag_criterion(lag_criterion, leaf)
    p_max >= 1 || throw(CliError("usage/invalid", "$leaf: --p-max must be >= 1 (got $p_max)"))
    n_perm >= 1 || throw(CliError("usage/invalid", "$leaf: --n-perm must be >= 1 (got $n_perm)"))
    bandwidth >= 0 || throw(CliError("usage/invalid", "$leaf: --bandwidth must be >= 0 (got $bandwidth)"))
    irf_horizon >= 1 || throw(CliError("usage/invalid", "$leaf: --irf-horizon must be >= 1 (got $irf_horizon)"))
    n_permanent === nothing || n_permanent >= 0 || throw(CliError("usage/invalid",
        "$leaf: --n-permanent must be >= 0 (got $n_permanent)"))

    if !isempty(instrument_col) && id != "proxy"
        throw(CliError("usage/invalid",
            "$leaf: --instrument applies only to --id proxy (got --id $id)"))
    end
    if id == "proxy" && isempty(instrument_col)
        throw(CliError("usage/missing",
            "$leaf: --id proxy requires --instrument <column>";
            hint="name a numeric, missing-free proxy column"))
    end
    if id == "sign" && isempty(config)
        throw(CliError("usage/missing",
            "$leaf: --id sign requires --config <toml> (or --config-json)";
            hint="define [identification.sign_matrix] for --id sign"))
    end

    X, varnames = load_multivariate_data(data)
    q = if dynamic_rank === nothing
        _status("Selecting dynamic rank on first differences...")
        dX = size(X, 1) >= 4 ? diff(X; dims=1) : X
        q_opt = _w2_auto_q(dX)
        _status("  Auto-selected $q_opt dynamic factors")
        q_opt
    else
        Int(dynamic_rank)
    end
    q >= 1 || throw(CliError("usage/invalid", "$leaf: --dynamic-rank must be >= 1 (got $q)"))
    if n_permanent !== nothing && Int(n_permanent) > q
        throw(CliError("usage/invalid",
            "$leaf: --n-permanent ($n_permanent) cannot exceed dynamic rank q ($q)"))
    end

    sign_check = nothing
    if id == "sign" && !isempty(config)
        sign_check, _ = _build_check_func(config)
        _check_sign_narrative_config_match(id, config, sign_check, nothing, leaf)
    end
    instrument = isempty(instrument_col) ? nothing : _load_instrument(data, instrument_col)
    eff_seed = _w2_resolve_seed(seed)

    model = try
        estimate_gdfm_i1(X, q;
            p_max=p_max, n_perm=n_perm, bandwidth=bandwidth, kernel=k_sym,
            det_trend=_W2_GDFM_I1_DET_TRENDS[det_trend], irf_horizon=irf_horizon,
            identification=_W2_GDFM_I1_IDS[id], sign_check=sign_check,
            n_permanent=n_permanent === nothing ? nothing : Int(n_permanent),
            instrument=instrument, lag_criterion=lc_sym,
            standardize=!no_standardize, varnames=varnames, seed=eff_seed)
    catch e
        throw(_domain_or_data_error(e, "I(1) cointegrated GDFM estimation"))
    end
    return model, X, varnames, q
end

"""Shared data-loading and estimation helper for `TimeVaryingGDFM`."""
function _w2_load_and_estimate_tv_gdfm(data::String, dynamic_rank,
                                       time_bandwidth::Float64, lag_bandwidth::Int,
                                       time_kernel::String, lag_kernel::String,
                                       n_grid::Int, no_standardize::Bool, leaf::String)
    time_kernel in _W2_TV_TIME_KERNELS || throw(CliError("usage/invalid",
        "$leaf: --time-kernel must be epanechnikov|gaussian|uniform (got '$time_kernel')"))
    lk_sym = _w2_validate_kernel(lag_kernel, leaf)
    (isfinite(time_bandwidth) && time_bandwidth >= 0.0) || throw(CliError("usage/invalid",
        "$leaf: --time-bandwidth must be finite and >= 0 (got $time_bandwidth)"))
    lag_bandwidth >= 0 || throw(CliError("usage/invalid",
        "$leaf: --lag-bandwidth must be >= 0 (got $lag_bandwidth)"))
    n_grid >= 1 || throw(CliError("usage/invalid",
        "$leaf: --n-grid must be >= 1 (got $n_grid)"))

    X, varnames = load_multivariate_data(data)
    q = if dynamic_rank === nothing
        _status("Selecting dynamic rank...")
        q_opt = _w2_auto_q(X)
        _status("  Auto-selected $q_opt dynamic factors")
        q_opt
    else
        Int(dynamic_rank)
    end
    q >= 1 || throw(CliError("usage/invalid", "$leaf: --dynamic-rank must be >= 1 (got $q)"))

    model = try
        estimate_tv_gdfm(X, q;
            time_bandwidth=time_bandwidth, lag_bandwidth=lag_bandwidth,
            time_kernel=Symbol(time_kernel), lag_kernel=lk_sym,
            n_grid=n_grid, standardize=!no_standardize, varnames=varnames)
    catch e
        throw(_domain_or_data_error(e, "TV-GDFM estimation"))
    end
    return model, X, varnames, q
end

# ── Shared Option Groups ──────────────────────────────────────

function _w2_fhlz_options()
    return OptionSpec[
        OptionSpec(name="dynamic-rank", type=Int, default=nothing, description="Number of dynamic shocks q (default: auto)"),
        OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral lag-window bandwidth M (0=auto)"),
        OptionSpec(name="kernel", type=String, default="bartlett", description="Spectral kernel: bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
        OptionSpec(name="p-max", type=Int, default=5, description="Maximum block VAR lag order"),
        OptionSpec(name="lag-criterion", type=String, default="bic", description="Block VAR lag criterion: bic|aic", choices=["bic", "aic"]),
        OptionSpec(name="n-perm", type=Int, default=30, description="Cross-sectional permutations to average"),
        OptionSpec(name="irf-horizon", type=Int, default=40, description="Number of one-sided MA impulse filter lags"),
        OptionSpec(name="em-max-iter", type=Int, default=50, description="Maximum EM iterations when --allow-missing is set"),
        OptionSpec(name="em-tol", type=Float64, default=1e-4, description="EM convergence tolerance when --allow-missing is set"),
        OptionSpec(name="seed", type=Int, default=nothing, description="Optional RNG seed for cross-sectional permutations"),
    ]
end

function _w2_fhlz_flags()
    return FlagSpec[
        FlagSpec(name="allow-missing", description="Allow missing/NaN entries via EM-FHLZ imputation"),
        FlagSpec(name="no-standardize", description="Do not standardize series before estimation"),
    ]
end

function _w2_gdfm_i1_options()
    return OptionSpec[
        OptionSpec(name="dynamic-rank", type=Int, default=nothing, description="Number of dynamic shocks q (default: auto on first differences)"),
        OptionSpec(name="n-permanent", type=Int, default=nothing, description="Number of permanent I(1) stochastic trends (0..q; default: auto)"),
        OptionSpec(name="id", type=String, default="permanent-transitory", description="Identification: permanent-transitory|cholesky|longrun|sign|proxy", choices=["permanent-transitory", "cholesky", "longrun", "sign", "proxy"]),
        OptionSpec(name="det-trend", type=String, default="constant", description="Deterministic trend: none|constant|linear|trend (trend aliases linear)", choices=["none", "constant", "linear", "trend"]),
        OptionSpec(name="p-max", type=Int, default=4, description="Maximum block VECM VAR lag order in levels"),
        OptionSpec(name="n-perm", type=Int, default=25, description="Cross-sectional permutations to average"),
        OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral lag-window bandwidth M (0=auto)"),
        OptionSpec(name="kernel", type=String, default="bartlett", description="Spectral kernel: bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
        OptionSpec(name="lag-criterion", type=String, default="bic", description="Block VECM lag criterion: bic|aic", choices=["bic", "aic"]),
        OptionSpec(name="irf-horizon", type=Int, default=40, description="Maximum stored level IRF horizon"),
        OptionSpec(name="config", type=String, default="", description="TOML config for sign restrictions (--id sign)"),
        OptionSpec(name="instrument", type=String, default="", description="External instrument CSV column (--id proxy)"),
        OptionSpec(name="seed", type=Int, default=nothing, description="Optional RNG seed"),
    ]
end

function _w2_tv_gdfm_options()
    return OptionSpec[
        OptionSpec(name="dynamic-rank", type=Int, default=nothing, description="Number of dynamic common factors q (default: auto)"),
        OptionSpec(name="time-bandwidth", type=Float64, default=0.0, description="Local time-kernel bandwidth b_T (0=auto)"),
        OptionSpec(name="lag-bandwidth", type=Int, default=0, description="Spectral lag-window truncation M_T (0=auto)"),
        OptionSpec(name="time-kernel", type=String, default="epanechnikov", description="Local time kernel: epanechnikov|gaussian|uniform", choices=["epanechnikov", "gaussian", "uniform"]),
        OptionSpec(name="lag-kernel", type=String, default="bartlett", description="Spectral lag kernel: bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
        OptionSpec(name="n-grid", type=Int, default=25, description="Number of rescaled time grid points in (0, 1)"),
    ]
end

# ── Handlers: FHLZ ────────────────────────────────────────────

function _estimate_fhlz(; data::String, dynamic_rank=nothing, bandwidth::Int=0,
                        kernel::String="bartlett", p_max::Int=5,
                        lag_criterion::String="bic", n_perm::Int=30,
                        irf_horizon::Int=40, em_max_iter::Int=50,
                        em_tol::Float64=1e-4, allow_missing::Bool=false,
                        no_standardize::Bool=false, seed=nothing,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    model, _, varnames, q = _w2_load_and_estimate_fhlz(
        data, dynamic_rank, bandwidth, kernel, p_max, lag_criterion,
        n_perm, irf_horizon, allow_missing, em_max_iter, em_tol,
        no_standardize, seed, "estimate factor fhlz")

    _status("FHLZ One-Sided GDFM: q=$q, N=$(length(varnames)), n_perm=$(model.n_perm), bandwidth=$(model.bandwidth)")
    _status()
    _emit_result(model; title="FHLZ One-Sided GDFM Impulse Filters (q=$q, n_perm=$(model.n_perm))",
                 key="fhlz_impulse_filters", format=Symbol(format), output=output)
    _maybe_plot(model; plot=plot, plot_save=plot_save)
    return model
end

function _predict_fhlz(; data::String="", dynamic_rank=nothing, bandwidth::Int=0,
                       kernel::String="bartlett", p_max::Int=5,
                       lag_criterion::String="bic", n_perm::Int=30,
                       irf_horizon::Int=40, em_max_iter::Int=50,
                       em_tol::Float64=1e-4, allow_missing::Bool=false,
                       no_standardize::Bool=false, seed=nothing,
                       output::String="", format::String="table", model=nothing)
    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_fhlz(
            data, dynamic_rank, bandwidth, kernel, p_max, lag_criterion,
            n_perm, irf_horizon, allow_missing, em_max_iter, em_tol,
            no_standardize, seed, "predict factor fhlz")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end
    fitted = predict(m)
    T_eff = size(fitted, 1)
    _status("FHLZ One-Sided GDFM: q=$q, common component (T_eff=$T_eff)")
    _status()
    df = DataFrame(t=1:T_eff)
    for (vi, vname) in enumerate(varnames)
        df[!, vname] = fitted[:, vi]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="FHLZ Common Component (q=$q, T_eff=$T_eff)",
                  key="fhlz_common_component")
    return fitted
end

function _residuals_fhlz(; data::String="", dynamic_rank=nothing, bandwidth::Int=0,
                         kernel::String="bartlett", p_max::Int=5,
                         lag_criterion::String="bic", n_perm::Int=30,
                         irf_horizon::Int=40, em_max_iter::Int=50,
                         em_tol::Float64=1e-4, allow_missing::Bool=false,
                         no_standardize::Bool=false, seed=nothing,
                         output::String="", format::String="table", model=nothing)
    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_fhlz(
            data, dynamic_rank, bandwidth, kernel, p_max, lag_criterion,
            n_perm, irf_horizon, allow_missing, em_max_iter, em_tol,
            no_standardize, seed, "residuals factor fhlz")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end
    resid = residuals(m)
    T_eff = size(resid, 1)
    _status("FHLZ One-Sided GDFM: q=$q, idiosyncratic component (T_eff=$T_eff)")
    _status()
    df = DataFrame(t=1:T_eff)
    for (vi, vname) in enumerate(varnames)
        df[!, vname] = resid[:, vi]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="FHLZ Idiosyncratic Component (q=$q, T_eff=$T_eff)",
                  key="fhlz_idiosyncratic_component")
    return resid
end

# ── Handlers: I(1) Cointegrated GDFM ──────────────────────────

function _estimate_gdfm_i1(; data::String, dynamic_rank=nothing, n_permanent=nothing,
                           id::String="permanent-transitory", det_trend::String="constant",
                           p_max::Int=4, n_perm::Int=25, bandwidth::Int=0,
                           kernel::String="bartlett", lag_criterion::String="bic",
                           irf_horizon::Int=40, config::String="",
                           instrument::String="", no_standardize::Bool=false,
                           seed=nothing, output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    model, _, varnames, q = _w2_load_and_estimate_gdfm_i1(
        data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
        bandwidth, kernel, lag_criterion, irf_horizon, config, instrument,
        no_standardize, seed, "estimate factor gdfm-i1")

    _status("Cointegrated I(1) GDFM: q=$q, permanent=$(model.n_permanent), id=$(model.identification), N=$(length(varnames))")
    _status()
    _emit_result(model;
                 title="Cointegrated I(1) GDFM Level IRFs (q=$q, permanent=$(model.n_permanent), $(model.identification))",
                 key="gdfm_i1_irf", format=Symbol(format), output=output)
    _maybe_plot(model; plot=plot, plot_save=plot_save)
    return model
end

function _predict_gdfm_i1(; data::String="", dynamic_rank=nothing, n_permanent=nothing,
                          id::String="permanent-transitory", det_trend::String="constant",
                          p_max::Int=4, n_perm::Int=25, bandwidth::Int=0,
                          kernel::String="bartlett", lag_criterion::String="bic",
                          irf_horizon::Int=40, config::String="",
                          instrument::String="", no_standardize::Bool=false,
                          seed=nothing, output::String="", format::String="table",
                          model=nothing)
    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_gdfm_i1(
            data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
            bandwidth, kernel, lag_criterion, irf_horizon, config, instrument,
            no_standardize, seed, "predict factor gdfm-i1")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end
    fitted = predict(m)
    T_obs = size(fitted, 1)
    _status("Cointegrated I(1) GDFM: q=$q, common levels (T=$T_obs)")
    _status()
    df = DataFrame(t=1:T_obs)
    for (vi, vname) in enumerate(varnames)
        df[!, vname] = fitted[:, vi]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="Cointegrated I(1) GDFM Common Levels (q=$q, T=$T_obs)",
                  key="gdfm_i1_common_levels")
    return fitted
end

function _residuals_gdfm_i1(; data::String="", dynamic_rank=nothing, n_permanent=nothing,
                            id::String="permanent-transitory", det_trend::String="constant",
                            p_max::Int=4, n_perm::Int=25, bandwidth::Int=0,
                            kernel::String="bartlett", lag_criterion::String="bic",
                            irf_horizon::Int=40, config::String="",
                            instrument::String="", no_standardize::Bool=false,
                            seed=nothing, output::String="", format::String="table",
                            model=nothing)
    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_gdfm_i1(
            data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
            bandwidth, kernel, lag_criterion, irf_horizon, config, instrument,
            no_standardize, seed, "residuals factor gdfm-i1")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end
    resid = residuals(m)
    T_obs = size(resid, 1)
    _status("Cointegrated I(1) GDFM: q=$q, idiosyncratic component (T=$T_obs)")
    _status()
    df = DataFrame(t=1:T_obs)
    for (vi, vname) in enumerate(varnames)
        df[!, vname] = resid[:, vi]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="Cointegrated I(1) GDFM Idiosyncratic Component (q=$q, T=$T_obs)",
                  key="gdfm_i1_idiosyncratic")
    return resid
end

function _forecast_gdfm_i1(; data::String="", result=nothing, dynamic_rank=nothing,
                           n_permanent=nothing, id::String="permanent-transitory",
                           det_trend::String="constant", p_max::Int=4, n_perm::Int=25,
                           bandwidth::Int=0, kernel::String="bartlett",
                           lag_criterion::String="bic", irf_horizon::Int=40,
                           config::String="", instrument::String="",
                           no_standardize::Bool=false, seed=nothing,
                           horizons::Int=12, ci::String="none", reps::Int=200,
                           conf_level::Float64=0.68,
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="", model=nothing)
    loaded = _loaded_result(result; data, model, leaf="forecast factor gdfm-i1")
    loaded === nothing || return _rerender_long_table(loaded; format, output,
        title="Cointegrated I(1) GDFM Forecast", key="gdfm_i1_forecast", plot, plot_save)
    horizons >= 1 || throw(CliError("usage/invalid",
        "forecast factor gdfm-i1: --horizons must be >= 1 (got $horizons)"))
    ci in ("none", "theoretical", "bootstrap") || throw(CliError("usage/invalid",
        "forecast factor gdfm-i1: --ci must be none|theoretical|bootstrap (got '$ci')"))
    reps >= 1 || throw(CliError("usage/invalid",
        "forecast factor gdfm-i1: --draws must be >= 1 (got $reps)"))
    conf_level = _validate_conf_level(conf_level, "forecast factor gdfm-i1")

    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_gdfm_i1(
            data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
            bandwidth, kernel, lag_criterion, max(irf_horizon, horizons),
            config, instrument, no_standardize, seed, "forecast factor gdfm-i1")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end

    _status("Cointegrated I(1) GDFM Forecast: q=$q, permanent=$(m.n_permanent), h=$horizons, ci=$ci")
    _status()
    eff_seed = _w2_resolve_seed(seed)
    fc = try
        forecast(m, horizons; ci_method=Symbol(ci), reps=reps,
                 conf_level=conf_level, seed=eff_seed)
    catch e
        throw(_domain_or_data_error(e, "I(1) GDFM forecast"))
    end
    _maybe_plot(fc; plot=plot, plot_save=plot_save, conf_level=conf_level)
    _emit_result(fc; title="Cointegrated I(1) GDFM Forecast (h=$horizons, $(length(varnames)) variables)",
                 key="gdfm_i1_forecast", format=Symbol(format), output=output)
    return (; model=m, result=fc)
end

function _irf_gdfm_i1(; data::String="", result=nothing, dynamic_rank=nothing,
                      n_permanent=nothing, id::String="permanent-transitory",
                      det_trend::String="constant", p_max::Int=4, n_perm::Int=25,
                      bandwidth::Int=0, kernel::String="bartlett",
                      lag_criterion::String="bic", irf_horizon::Int=40,
                      config::String="", instrument::String="",
                      no_standardize::Bool=false, seed=nothing,
                      horizons::Int=20, output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="", model=nothing)
    loaded = _loaded_result(result; data, model, leaf="irf gdfm-i1",
                            id, id_default="permanent-transitory",
                            horizons, horizons_default=20)
    loaded === nothing || return _rerender_irf_result(loaded; format, output,
        title="Cointegrated I(1) GDFM IRF", key="gdfm_i1_irf", plot, plot_save)
    horizons >= 1 || throw(CliError("usage/invalid",
        "irf gdfm-i1: --horizons must be >= 1 (got $horizons)"))

    if isnothing(model)
        m, _, _, _ = _w2_load_and_estimate_gdfm_i1(
            data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
            bandwidth, kernel, lag_criterion, max(irf_horizon, horizons),
            config, instrument, no_standardize, seed, "irf gdfm-i1")
    else
        m = model
    end

    _status("Cointegrated I(1) GDFM IRF: id=$(m.identification), permanent=$(m.n_permanent), horizon=$horizons")
    _status()
    irf_res = try
        irf(m, horizons)
    catch e
        throw(_domain_or_data_error(e, "I(1) GDFM IRF"))
    end
    _maybe_plot(irf_res; plot=plot, plot_save=plot_save)
    _emit_result(irf_res; title="Cointegrated I(1) GDFM IRF ($(m.identification))",
                 key="gdfm_i1_irf", format=Symbol(format), output=output)
    return (; model=m, result=irf_res)
end

function _fevd_gdfm_i1(; data::String="", result=nothing, dynamic_rank=nothing,
                       n_permanent=nothing, id::String="permanent-transitory",
                       det_trend::String="constant", p_max::Int=4, n_perm::Int=25,
                       bandwidth::Int=0, kernel::String="bartlett",
                       lag_criterion::String="bic", irf_horizon::Int=40,
                       config::String="", instrument::String="",
                       no_standardize::Bool=false, seed=nothing,
                       horizons::Int=20, include_idiosyncratic::Bool=false,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="", model=nothing)
    loaded = _loaded_result(result; data, model, leaf="fevd gdfm-i1",
                            id, id_default="permanent-transitory",
                            horizons, horizons_default=20)
    loaded === nothing || return _rerender_fevd_result(loaded; format, output,
        title="Cointegrated I(1) GDFM FEVD", key="gdfm_i1_fevd", plot, plot_save)
    horizons >= 1 || throw(CliError("usage/invalid",
        "fevd gdfm-i1: --horizons must be >= 1 (got $horizons)"))

    if isnothing(model)
        m, _, _, _ = _w2_load_and_estimate_gdfm_i1(
            data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
            bandwidth, kernel, lag_criterion, max(irf_horizon, horizons),
            config, instrument, no_standardize, seed, "fevd gdfm-i1")
    else
        m = model
    end

    _status("Cointegrated I(1) GDFM FEVD: id=$(m.identification), horizon=$horizons, include_idiosyncratic=$include_idiosyncratic")
    _status()
    fevd_res = try
        fevd(m, horizons; include_idiosyncratic=include_idiosyncratic)
    catch e
        throw(_domain_or_data_error(e, "I(1) GDFM FEVD"))
    end
    _maybe_plot(fevd_res; plot=plot, plot_save=plot_save)
    _emit_result(fevd_res; title="Cointegrated I(1) GDFM FEVD",
                 key="gdfm_i1_fevd", format=Symbol(format), output=output)
    return (; model=m, result=fevd_res)
end

function _hd_gdfm_i1(; data::String="", result=nothing, dynamic_rank=nothing,
                     n_permanent=nothing, id::String="permanent-transitory",
                     det_trend::String="constant", p_max::Int=4, n_perm::Int=25,
                     bandwidth::Int=0, kernel::String="bartlett",
                     lag_criterion::String="bic", irf_horizon::Int=40,
                     config::String="", instrument::String="",
                     no_standardize::Bool=false, seed=nothing,
                     horizons=nothing, include_idiosyncratic::Bool=false,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="", model=nothing)
    loaded = _loaded_result(result; data, model, leaf="hd gdfm-i1",
                            id, id_default="permanent-transitory")
    if loaded !== nothing
        _output_hd_tables((vi, si) -> contribution(loaded, vi, si),
                          loaded.variables, loaded.T_eff;
                          id=string(loaded.method),
                          title_prefix="Cointegrated I(1) GDFM Historical Decomposition",
                          format=format, output=output,
                          actual=loaded.actual, initial=loaded.initial_conditions,
                          key_prefix="gdfm_i1_historical_decomposition",
                          shock_names=loaded.shock_names)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end
    horizons === nothing || Int(horizons) >= 1 || throw(CliError("usage/invalid",
        "hd gdfm-i1: --horizons must be >= 1 (got $horizons)"))

    if isnothing(model)
        m, _, _, _ = _w2_load_and_estimate_gdfm_i1(
            data, dynamic_rank, n_permanent, id, det_trend, p_max, n_perm,
            bandwidth, kernel, lag_criterion, irf_horizon,
            config, instrument, no_standardize, seed, "hd gdfm-i1")
    else
        m = model
    end

    h_use = horizons === nothing ? size(m.shocks, 1) : Int(horizons)
    _status("Cointegrated I(1) GDFM HD: id=$(m.identification), horizon=$h_use, include_idiosyncratic=$include_idiosyncratic")
    _status()
    hd_res = try
        historical_decomposition(m, h_use; include_idiosyncratic=include_idiosyncratic)
    catch e
        throw(_domain_or_data_error(e, "I(1) GDFM historical decomposition"))
    end
    _maybe_plot(hd_res; plot=plot, plot_save=plot_save)

    _output_hd_tables((vi, si) -> contribution(hd_res, vi, si),
                      hd_res.variables, hd_res.T_eff;
                      id=string(m.identification),
                      title_prefix="Cointegrated I(1) GDFM Historical Decomposition",
                      format=format, output=output,
                      actual=hd_res.actual, initial=hd_res.initial_conditions,
                      key_prefix="gdfm_i1_historical_decomposition",
                      shock_names=hd_res.shock_names)
    return (; model=m, result=hd_res)
end

# ── Handlers: Time-Varying GDFM ───────────────────────────────

function _estimate_tv_gdfm(; data::String, dynamic_rank=nothing,
                           time_bandwidth::Float64=0.0, lag_bandwidth::Int=0,
                           time_kernel::String="epanechnikov",
                           lag_kernel::String="bartlett", n_grid::Int=25,
                           no_standardize::Bool=false,
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    model, _, varnames, q = _w2_load_and_estimate_tv_gdfm(
        data, dynamic_rank, time_bandwidth, lag_bandwidth,
        time_kernel, lag_kernel, n_grid, no_standardize, "estimate factor tv-gdfm")

    _status("Time-Varying GDFM: q=$q, N=$(length(varnames)), n_grid=$(model.n_grid), b_T=$(round(model.time_bandwidth; digits=4)), M_T=$(model.lag_bandwidth)")
    _status()
    _emit_result(model; title="Time-Varying GDFM Variance Share Path (q=$q, n_grid=$(model.n_grid))",
                 key="tv_gdfm_variance_share_path", format=Symbol(format), output=output)
    _maybe_plot(model; plot=plot, plot_save=plot_save)
    return model
end

function _predict_tv_gdfm(; data::String="", dynamic_rank=nothing,
                          time_bandwidth::Float64=0.0, lag_bandwidth::Int=0,
                          time_kernel::String="epanechnikov",
                          lag_kernel::String="bartlett", n_grid::Int=25,
                          no_standardize::Bool=false,
                          output::String="", format::String="table", model=nothing)
    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_tv_gdfm(
            data, dynamic_rank, time_bandwidth, lag_bandwidth,
            time_kernel, lag_kernel, n_grid, no_standardize, "predict factor tv-gdfm")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end
    fitted = predict(m)
    T_obs = size(fitted, 1)
    _status("Time-Varying GDFM: q=$q, common component (T=$T_obs)")
    _status()
    df = DataFrame(t=1:T_obs)
    for (vi, vname) in enumerate(varnames)
        df[!, vname] = fitted[:, vi]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="Time-Varying GDFM Common Component (q=$q, T=$T_obs)",
                  key="tv_gdfm_common_component")
    return fitted
end

function _residuals_tv_gdfm(; data::String="", dynamic_rank=nothing,
                            time_bandwidth::Float64=0.0, lag_bandwidth::Int=0,
                            time_kernel::String="epanechnikov",
                            lag_kernel::String="bartlett", n_grid::Int=25,
                            no_standardize::Bool=false,
                            output::String="", format::String="table", model=nothing)
    if isnothing(model)
        m, _, varnames, q = _w2_load_and_estimate_tv_gdfm(
            data, dynamic_rank, time_bandwidth, lag_bandwidth,
            time_kernel, lag_kernel, n_grid, no_standardize, "residuals factor tv-gdfm")
    else
        m = model
        q = m.q
        varnames = _model_varnames(m)
    end
    resid = residuals(m)
    T_obs = size(resid, 1)
    _status("Time-Varying GDFM: q=$q, idiosyncratic component (T=$T_obs)")
    _status()
    df = DataFrame(t=1:T_obs)
    for (vi, vname) in enumerate(varnames)
        df[!, vname] = resid[:, vi]
    end
    output_result(df; format=Symbol(format), output=output,
                  title="Time-Varying GDFM Idiosyncratic Component (q=$q, T=$T_obs)",
                  key="tv_gdfm_idiosyncratic_component")
    return resid
end

# ── Handlers: Factor Rank Selection Tests ─────────────────────

function _test_onatski_q(; data::String="", result=nothing,
                         k0=nothing, k1=nothing, k_max=nothing,
                         alpha::Float64=0.05, select::Bool=false,
                         bandwidth=nothing, n_blocks=nothing,
                         kernel::String="bartlett", freq=nothing,
                         n_sim::Int=5000, no_standardize::Bool=false,
                         no_demean::Bool=false, seed=nothing,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, leaf="test factor onatski-q")
    if loaded !== nothing
        _emit_result(loaded; title="Onatski (2009) Dynamic Rank q-Test",
                     key="onatski_q_test", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    haskey(_W2_ONATSKI_KERNELS, kernel) || throw(CliError("usage/invalid",
        "test factor onatski-q: --kernel must be bartlett|parzen|tukey-hanning (got '$kernel')"))
    k_sym = _W2_ONATSKI_KERNELS[kernel]
    (0.0 < alpha < 1.0) || throw(CliError("usage/invalid",
        "test factor onatski-q: --alpha must lie in (0, 1) (got $alpha)"))
    n_sim >= 100 || throw(CliError("usage/invalid",
        "test factor onatski-q: --n-sim must be >= 100 (got $n_sim)"))
    bandwidth === nothing || Int(bandwidth) >= 1 || throw(CliError("usage/invalid",
        "test factor onatski-q: --bandwidth must be >= 1 (got $bandwidth)"))
    n_blocks === nothing || Int(n_blocks) >= 1 || throw(CliError("usage/invalid",
        "test factor onatski-q: --n-blocks must be >= 1 (got $n_blocks)"))
    if freq !== nothing
        fv = Float64(freq)
        (isfinite(fv) && 0.0 < fv < Float64(π)) || throw(CliError("usage/invalid",
            "test factor onatski-q: --freq must lie in (0, pi) (got $freq)"))
    end

    X, _ = load_multivariate_data(data)
    T_obs, N = size(X)
    eff_seed = _w2_resolve_seed(seed)

    use_select = select || (k0 === nothing)
    if use_select
        km = k_max === nothing ? min(8, N - 2) : Int(k_max)
        (1 <= km && km + 2 <= N) || throw(CliError("usage/invalid",
            "test factor onatski-q: --k-max must satisfy 1 <= k_max <= N - 2 ($(N - 2)) (got $km)"))
        q_hat, tests = try
            onatski_q_select(X; k_max=km, alpha=alpha,
                bandwidth=bandwidth === nothing ? nothing : Int(bandwidth),
                n_blocks=n_blocks === nothing ? nothing : Int(n_blocks),
                kernel=k_sym, freq=freq === nothing ? nothing : Float64(freq),
                standardize=!no_standardize, demean=!no_demean,
                n_sim=n_sim, seed=eff_seed)
        catch e
            throw(_domain_or_data_error(e, "Onatski dynamic rank selection"))
        end
        _status("Onatski (2009) Sequential Dynamic Rank Selection (T=$T_obs, N=$N, k_max=$km, alpha=$alpha):")
        for tr in tests
            _status("  H0: q=$(tr.k0) vs $(tr.k0) < q <= $(tr.k1): R=$(round(tr.statistic; digits=4)), p=$(round(tr.pvalue; digits=4))")
        end
        _status("Selected dynamic rank: q = $q_hat")
        _status()
        res = tests[end]
        _emit_result(res; title="Onatski (2009) Dynamic Rank q-Test (selected q=$q_hat)",
                     key="onatski_q_test", format=Symbol(format), output=output)
        _maybe_plot(res; plot=plot, plot_save=plot_save)
        return res
    else
        k0_i = Int(k0)
        k1_i = k1 === nothing ? min(k0_i + 4, N - 2) : Int(k1)
        (k0_i >= 0 && k1_i > k0_i && k1_i + 2 <= N) || throw(CliError("usage/invalid",
            "test factor onatski-q: require 0 <= --k0 < --k1 <= N - 2 ($(N - 2)) (got k0=$k0_i, k1=$k1_i)"))
        res = try
            onatski_q_test(X, k0_i, k1_i;
                bandwidth=bandwidth === nothing ? nothing : Int(bandwidth),
                n_blocks=n_blocks === nothing ? nothing : Int(n_blocks),
                kernel=k_sym, freq=freq === nothing ? nothing : Float64(freq),
                standardize=!no_standardize, demean=!no_demean,
                n_sim=n_sim, seed=eff_seed)
        catch e
            throw(_domain_or_data_error(e, "Onatski dynamic rank q-test"))
        end
        _status("Onatski (2009) Dynamic Rank q-Test: H0: q=$k0_i vs $k0_i < q <= $k1_i (T=$T_obs, N=$N)")
        _status()
        _emit_result(res; title="Onatski (2009) Dynamic Rank q-Test (H0: q=$k0_i vs q <= $k1_i)",
                     key="onatski_q_test", format=Symbol(format), output=output)
        _maybe_plot(res; plot=plot, plot_save=plot_save)
        return res
    end
end

function _test_ahn_horenstein(; data::String="", result=nothing, k_max=nothing,
                              no_demean::Bool=false, no_standardize::Bool=false,
                              output::String="", format::String="table",
                              plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, leaf="test factor ahn-horenstein")
    if loaded !== nothing
        _emit_result(loaded; title="Ahn-Horenstein (2013) Factor Rank Test",
                     key="ahn_horenstein_test", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    X, _ = load_multivariate_data(data)
    T_obs, N = size(X)
    m = min(T_obs, N)
    km = k_max === nothing ? min(10, m - 2) : Int(k_max)
    (1 <= km <= m - 2) || throw(CliError("usage/invalid",
        "test factor ahn-horenstein: --k-max must satisfy 1 <= k_max <= min(T, N) - 2 ($(m - 2)) (got $km)"))

    res = try
        ahn_horenstein(X, km; demean=!no_demean, standardize=!no_standardize)
    catch e
        throw(_domain_or_data_error(e, "Ahn-Horenstein factor rank test"))
    end
    _status("Ahn-Horenstein (2013) Static Factor Rank Test (T=$T_obs, N=$N, k_max=$km): r_ER=$(res.r_er), r_GR=$(res.r_gr)")
    _status()
    _emit_result(res; title="Ahn-Horenstein (2013) ER/GR Test (r_ER=$(res.r_er), r_GR=$(res.r_gr))",
                 key="ahn_horenstein_test", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

function _test_onatski_ed(; data::String="", result=nothing, k_max=nothing,
                          max_iter::Int=20, no_standardize::Bool=false,
                          no_demean::Bool=false,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, leaf="test factor onatski-ed")
    if loaded !== nothing
        _emit_result(loaded; title="Onatski (2010) Edge Distribution Rank Test",
                     key="onatski_ed_test", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    max_iter >= 1 || throw(CliError("usage/invalid",
        "test factor onatski-ed: --max-iter must be >= 1 (got $max_iter)"))
    X, _ = load_multivariate_data(data)
    T_obs, N = size(X)
    m = min(T_obs, N)
    km = k_max === nothing ? min(10, m - 2) : Int(k_max)
    (1 <= km <= m - 2) || throw(CliError("usage/invalid",
        "test factor onatski-ed: --k-max must satisfy 1 <= k_max <= min(T, N) - 2 ($(m - 2)) (got $km)"))

    res = try
        onatski_ed(X, km; max_iter=max_iter, standardize=!no_standardize, demean=!no_demean)
    catch e
        throw(_domain_or_data_error(e, "Onatski ED factor rank test"))
    end
    _status("Onatski (2010) Edge Distribution Test (T=$T_obs, N=$N, k_max=$km): r_ED=$(res.r_ed), delta=$(round(res.delta; digits=4)), converged=$(res.converged)")
    _status()
    _emit_result(res; title="Onatski (2010) Edge Distribution Test (r_ED=$(res.r_ed))",
                 key="onatski_ed_test", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

# ── Handlers: Band-Pass GDFM & Eurocoin ───────────────────────

function _filter_bandpass_gdfm(; data::String="", result=nothing, model=nothing,
                               dynamic_rank=nothing, nfactors=nothing,
                               pl::Float64=6.0, pu::Float64=32.0,
                               band_low=nothing, band_high=nothing,
                               bandwidth::Int=0, kernel::String="bartlett",
                               spectral::String="lag-window",
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, model, leaf="filter bandpass-gdfm")
    if loaded !== nothing
        _emit_result(loaded; title="Band-Pass GDFM Decomposition",
                     key="bandpass_gdfm", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    band = _w2_parse_band(pl, pu, band_low, band_high, 6.0, 32.0, "filter bandpass-gdfm")
    if isnothing(model)
        k_sym = _w2_validate_kernel(kernel, "filter bandpass-gdfm")
        haskey(_GDFM_SPECTRAL, spectral) || throw(CliError("usage/invalid",
            "filter bandpass-gdfm: --spectral must be lag-window|smoothed-periodogram (got '$spectral')"))
        bandwidth >= 0 || throw(CliError("usage/invalid",
            "filter bandpass-gdfm: --bandwidth must be >= 0 (got $bandwidth)"))
        X, varnames = load_multivariate_data(data)
        q = dynamic_rank === nothing ? _w2_auto_q(X) : Int(dynamic_rank)
        r_est = nfactors === nothing ? _w2_auto_r(X, q) : Int(nfactors)
        gdfm = try
            estimate_gdfm(X, q; r=r_est, spectral=_GDFM_SPECTRAL[spectral],
                          bandwidth=bandwidth, kernel=k_sym, varnames=varnames)
        catch e
            throw(_domain_or_data_error(e, "GDFM estimation for band-pass filter"))
        end
    else
        gdfm = model
    end

    r_bp = nfactors === nothing ? gdfm.r : Int(nfactors)
    res = try
        bandpass_gdfm(gdfm, band; r=r_bp)
    catch e
        throw(_domain_or_data_error(e, "Band-pass GDFM decomposition"))
    end
    _status("Band-Pass GDFM: band=[$(round(band[1]; digits=4)), $(round(band[2]; digits=4))] rad, r=$r_bp, mean share=$(round(mean(res.variance_share); digits=4))")
    _status()
    _emit_result(res; title="Band-Pass GDFM [$(round(band[1]; digits=4)), $(round(band[2]; digits=4))] rad",
                 key="bandpass_gdfm", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return (; model=gdfm, result=res)
end

function _filter_eurocoin(; data::String="", result=nothing, target::String="",
                          dynamic_rank=nothing, nfactors::Int=0,
                          cutoff::Float64=Float64(π / 6),
                          bandwidth::Int=0, kernel::String="bartlett",
                          no_standardize::Bool=false,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, leaf="filter eurocoin")
    if loaded !== nothing
        _emit_result(loaded; title="Eurocoin Low-Frequency Indicator",
                     key="eurocoin_indicator", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    k_sym = _w2_validate_kernel(kernel, "filter eurocoin")
    bandwidth >= 0 || throw(CliError("usage/invalid",
        "filter eurocoin: --bandwidth must be >= 0 (got $bandwidth)"))
    nfactors >= 0 || throw(CliError("usage/invalid",
        "filter eurocoin: --nfactors must be >= 0 (got $nfactors)"))
    (isfinite(cutoff) && 0.0 < cutoff < Float64(π)) || throw(CliError("usage/invalid",
        "filter eurocoin: --cutoff must satisfy 0 < cutoff < pi (got $cutoff)"))

    X, varnames = load_multivariate_data(data)
    t_idx = if isempty(target)
        1
    else
        t_res = _resolve_target_var(target, varnames, "filter eurocoin")
        t_res isa Int ? t_res : something(findfirst(==(t_res), varnames), 1)
    end
    tname = varnames[t_idx]
    target_vec = vec(X[:, t_idx])

    q = dynamic_rank === nothing ? _w2_auto_q(X) : Int(dynamic_rank)
    q >= 1 || throw(CliError("usage/invalid",
        "filter eurocoin: --dynamic-rank must be >= 1 (got $q)"))

    res = try
        eurocoin_indicator(X, target_vec, q;
            cutoff=cutoff, r=nfactors, bandwidth=bandwidth,
            kernel=k_sym, standardize=!no_standardize)
    catch e
        throw(_domain_or_data_error(e, "Eurocoin indicator"))
    end
    _status("Eurocoin Indicator: target=$tname, q=$q, r=$(res.r), cutoff=$(round(res.cutoff; digits=4)) rad, R2=$(round(res.r2; digits=4))")
    _status()
    _emit_result(res; title="Eurocoin Indicator (target=$tname, q=$q, R2=$(round(res.r2; digits=4)))",
                 key="eurocoin_indicator", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return res
end

# ── Handler: Spectral FEVD ────────────────────────────────────

function _spectral_fevd(; data::String="", result=nothing, model=nothing,
                        factors=nothing, id::String="cholesky",
                        q_method::String="hallin-liska", method::String="fglr",
                        spectral::String="lag-window", instrument::String="",
                        var_lags="auto", n_perm::Int=30, p_max=nothing,
                        target::String="", horizons::Int=40, config::String="",
                        bandwidth::Int=0, kernel::String="bartlett",
                        pl::Float64=6.0, pu::Float64=32.0,
                        band_low=nothing, band_high=nothing,
                        include_idiosyncratic::Bool=false,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, model, leaf="spectral fevd")
    if loaded !== nothing
        _emit_result(loaded; title="Spectral FEVD",
                     key="spectral_fevd", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    band = _w2_parse_band(pl, pu, band_low, band_high, 6.0, 32.0, "spectral fevd")
    if isnothing(model)
        sdfm, _, _, _ = _load_and_estimate_sdfm(data, factors, id, var_lags, horizons,
            config, method, spectral, instrument, q_method;
            bandwidth=bandwidth, kernel=kernel, n_perm=n_perm,
            p_max=p_max === nothing ? nothing : Int(p_max), target=target)
    else
        sdfm = model
    end

    res = try
        spectral_fevd(sdfm, band; include_idiosyncratic=include_idiosyncratic)
    catch e
        throw(_domain_or_data_error(e, "Spectral FEVD"))
    end
    _status("Spectral FEVD: band=[$(round(band[1]; digits=4)), $(round(band[2]; digits=4))] rad, include_idiosyncratic=$include_idiosyncratic")
    _status()
    _emit_result(res; title="Spectral FEVD [$(round(band[1]; digits=4)), $(round(band[2]; digits=4))] rad",
                 key="spectral_fevd", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return (; model=sdfm, result=res)
end

# ── Handler: Ragged-Edge GDFM Nowcasting ──────────────────────

function _nowcast_gdfm(; data::String="", result=nothing, model=nothing,
                       dynamic_rank=nothing, nfactors=nothing,
                       horizons::Int=0, n_lags::Int=2,
                       bandwidth::Int=0, kernel::String="bartlett",
                       spectral::String="lag-window",
                       em_max_iter::Int=50, em_tol::Float64=1e-4,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, model, leaf="nowcast gdfm")
    if loaded !== nothing
        _emit_result(loaded; title="GDFM Ragged-Edge Nowcast",
                     key="nowcast_gdfm", format=Symbol(format), output=output)
        _maybe_plot(loaded; plot=plot, plot_save=plot_save)
        return loaded
    end

    n_lags >= 0 || throw(CliError("usage/invalid",
        "nowcast gdfm: --n-lags must be >= 0 (got $n_lags)"))
    em_max_iter >= 1 || throw(CliError("usage/invalid",
        "nowcast gdfm: --em-max-iter must be >= 1 (got $em_max_iter)"))
    em_tol > 0 || throw(CliError("usage/invalid",
        "nowcast gdfm: --em-tol must be > 0 (got $em_tol)"))
    bandwidth >= 0 || throw(CliError("usage/invalid",
        "nowcast gdfm: --bandwidth must be >= 0 (got $bandwidth)"))

    if isnothing(model)
        isempty(data) && throw(CliError("usage/missing",
            "nowcast gdfm: provide <data> or --model <GeneralizedDynamicFactorModel.jld2>"))
        k_sym = _w2_validate_kernel(kernel, "nowcast gdfm")
        haskey(_GDFM_SPECTRAL, spectral) || throw(CliError("usage/invalid",
            "nowcast gdfm: --spectral must be lag-window|smoothed-periodogram (got '$spectral')"))
        X_ragged, varnames = load_multivariate_data(data; allow_nan=true)
        q = dynamic_rank === nothing ? _w2_auto_q(X_ragged) : Int(dynamic_rank)
        r = nfactors === nothing ? _w2_auto_r(X_ragged, q) : Int(nfactors)
        gdfm = try
            estimate_gdfm(X_ragged, q; r=r, spectral=_GDFM_SPECTRAL[spectral],
                          bandwidth=bandwidth, kernel=k_sym, varnames=varnames,
                          allow_missing=true, em_max_iter=em_max_iter, em_tol=em_tol)
        catch e
            throw(_domain_or_data_error(e, "Ragged-edge GDFM estimation"))
        end
    else
        gdfm = model
        X_ragged = if isempty(data)
            Matrix{Float64}(gdfm.X)
        else
            Xr, _ = load_multivariate_data(data; allow_nan=true)
            Xr
        end
    end

    res = try
        nowcast_gdfm(gdfm, X_ragged, horizons; n_lags=n_lags)
    catch e
        throw(_domain_or_data_error(e, "GDFM nowcast"))
    end
    n_miss = count(!, res.observed_mask)
    _status("GDFM Ragged-Edge Nowcast: h=$horizons, n_lags=$n_lags, missing_cells=$n_miss/$(length(res.observed_mask))")
    _status()
    _emit_result(res; title="GDFM Ragged-Edge Nowcast (h=$horizons, n_lags=$n_lags)",
                 key="nowcast_gdfm", format=Symbol(format), output=output)
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    return (; model=gdfm, result=res)
end

# ── CommandSpec Builders ──────────────────────────────────────

function w2_estimate_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", type=String, required=true, default=nothing,
                        description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    out_plot = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    return CommandSpec[
        CommandSpec(
            path=["estimate", "fhlz"],
            summary="FHLZ (2015, 2017) one-sided infinite-dimensional GDFM",
            args=data_arg,
            options=[_w2_fhlz_options(); out_plot],
            flags=[_w2_fhlz_flags(); PLOT_FLAGS],
            tables=[TableSpec(name=:fhlz_impulse_filters,
                              description="One-sided FHLZ impulse filters and variance explained, tidy long form: horizon | variable | shock | value | var_explained")],
            category="estimate",
            handler=wrap_legacy(_estimate_fhlz),
        ),
        CommandSpec(
            path=["estimate", "gdfm-i1"],
            summary="Barigozzi-Lippi-Luciani (2021) non-stationary I(1) cointegrated GDFM",
            args=data_arg,
            options=[_w2_gdfm_i1_options(); out_plot],
            flags=[FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation"); PLOT_FLAGS],
            tables=[TableSpec(name=:gdfm_i1_irf,
                              description="Cointegrated I(1) GDFM level impulse responses, tidy long form: horizon | variable | shock | value")],
            category="estimate",
            handler=wrap_legacy(_estimate_gdfm_i1),
        ),
        CommandSpec(
            path=["estimate", "tv-gdfm"],
            summary="Locally stationary time-varying spectral GDFM (Eichler-Motta-von Sachs)",
            args=data_arg,
            options=[_w2_tv_gdfm_options(); out_plot],
            flags=[FlagSpec(name="no-standardize", description="Do not standardize panel columns before filtering"); PLOT_FLAGS],
            tables=[TableSpec(name=:tv_gdfm_variance_share_path,
                              description="Time-varying common variance share path, tidy long form: time | factor | variance_share")],
            category="estimate",
            handler=wrap_legacy(_estimate_tv_gdfm),
        ),
    ]
end

function w2_predict_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", type=String, required=true, default=nothing,
                        description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    return CommandSpec[
        CommandSpec(
            path=["predict", "fhlz"],
            summary="In-sample one-sided common component from FHLZ GDFM",
            args=data_arg,
            options=[_w2_fhlz_options(); OUTPUT_OPTIONS],
            flags=_w2_fhlz_flags(),
            tables=[TableSpec(name=:fhlz_common_component,
                              description="One-sided FHLZ common component by period, one column per variable")],
            category="predict",
            handler=_predict_fhlz,
        ),
        CommandSpec(
            path=["predict", "gdfm-i1"],
            summary="In-sample common levels from I(1) cointegrated GDFM",
            args=data_arg,
            options=[_w2_gdfm_i1_options(); OUTPUT_OPTIONS],
            flags=[FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation")],
            tables=[TableSpec(name=:gdfm_i1_common_levels,
                              description="Cointegrated I(1) GDFM common component in levels, one column per variable")],
            category="predict",
            handler=_predict_gdfm_i1,
        ),
        CommandSpec(
            path=["predict", "tv-gdfm"],
            summary="In-sample time-varying common component from TV-GDFM",
            args=data_arg,
            options=[_w2_tv_gdfm_options(); OUTPUT_OPTIONS],
            flags=[FlagSpec(name="no-standardize", description="Do not standardize panel columns before filtering")],
            tables=[TableSpec(name=:tv_gdfm_common_component,
                              description="Time-varying GDFM common component by period, one column per variable")],
            category="predict",
            handler=_predict_tv_gdfm,
        ),
    ]
end

function w2_residuals_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", type=String, required=true, default=nothing,
                        description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    return CommandSpec[
        CommandSpec(
            path=["residuals", "fhlz"],
            summary="Idiosyncratic residuals from FHLZ one-sided GDFM",
            args=data_arg,
            options=[_w2_fhlz_options(); OUTPUT_OPTIONS],
            flags=_w2_fhlz_flags(),
            tables=[TableSpec(name=:fhlz_idiosyncratic_component,
                              description="FHLZ idiosyncratic residual component by period, one column per variable")],
            category="residuals",
            handler=_residuals_fhlz,
        ),
        CommandSpec(
            path=["residuals", "gdfm-i1"],
            summary="Stationary idiosyncratic residuals from I(1) cointegrated GDFM",
            args=data_arg,
            options=[_w2_gdfm_i1_options(); OUTPUT_OPTIONS],
            flags=[FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation")],
            tables=[TableSpec(name=:gdfm_i1_idiosyncratic,
                              description="Cointegrated I(1) GDFM idiosyncratic component by period, one column per variable")],
            category="residuals",
            handler=_residuals_gdfm_i1,
        ),
        CommandSpec(
            path=["residuals", "tv-gdfm"],
            summary="Idiosyncratic residuals from time-varying GDFM",
            args=data_arg,
            options=[_w2_tv_gdfm_options(); OUTPUT_OPTIONS],
            flags=[FlagSpec(name="no-standardize", description="Do not standardize panel columns before filtering")],
            tables=[TableSpec(name=:tv_gdfm_idiosyncratic_component,
                              description="Time-varying GDFM idiosyncratic residual component by period, one column per variable")],
            category="residuals",
            handler=_residuals_tv_gdfm,
        ),
    ]
end

function w2_forecast_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", type=String, required=true, default=nothing,
                        description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    return CommandSpec[
        CommandSpec(
            path=["forecast", "gdfm-i1"],
            summary="Level forecasts from I(1) cointegrated GDFM",
            args=data_arg,
            options=[
                _w2_gdfm_i1_options()...,
                OptionSpec(name="horizons", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="ci", type=String, default="none", description="Interval method: none|theoretical|bootstrap", choices=["none", "theoretical", "bootstrap"]),
                OptionSpec(name="draws", aliases=["reps"], kwarg=:reps, type=Int, default=200, description="Bootstrap replications (with --ci bootstrap)"),
                CONF_LEVEL_MACRO_OPTION,
                OUTPUT_OPTIONS..., PLOT_OPTIONS...,
            ],
            flags=[FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation"); PLOT_FLAGS],
            tables=[TableSpec(name=:gdfm_i1_forecast,
                              description="Level forecasts from cointegrated I(1) GDFM, tidy long form: horizon | variable | value | lower | upper")],
            category="forecast",
            handler=wrap_legacy(_forecast_gdfm_i1),
        ),
    ]
end

function w2_irf_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    return CommandSpec[
        CommandSpec(
            path=["irf", "gdfm-i1"],
            summary="Level structural IRFs from I(1) cointegrated GDFM",
            args=data_arg,
            options=[
                _w2_gdfm_i1_options()...,
                OptionSpec(name="horizons", type=Int, default=20, description="IRF horizon"),
                OUTPUT_OPTIONS..., PLOT_OPTIONS...,
            ],
            flags=[FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation"); PLOT_FLAGS],
            tables=[TableSpec(name=:gdfm_i1_irf,
                              description="Cointegrated I(1) GDFM level structural IRFs: horizon | variable | shock | value | lower | upper")],
            category="irf",
            handler=wrap_legacy(_irf_gdfm_i1),
        ),
    ]
end

function w2_fevd_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    return CommandSpec[
        CommandSpec(
            path=["fevd", "gdfm-i1"],
            summary="Panel FEVD from I(1) cointegrated GDFM level IRFs",
            args=data_arg,
            options=[
                _w2_gdfm_i1_options()...,
                OptionSpec(name="horizons", type=Int, default=20, description="FEVD horizon"),
                OUTPUT_OPTIONS..., PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation"),
                FlagSpec(name="include-idiosyncratic", description="Append idiosyncratic variance share column"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:gdfm_i1_fevd,
                              description="Cointegrated I(1) GDFM variance shares, tidy long form: horizon | variable | shock | value")],
            category="fevd",
            handler=wrap_legacy(_fevd_gdfm_i1),
        ),
    ]
end

function w2_hd_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    return CommandSpec[
        CommandSpec(
            path=["hd", "gdfm-i1"],
            summary="Historical decomposition from I(1) cointegrated GDFM",
            args=data_arg,
            options=[
                _w2_gdfm_i1_options()...,
                OptionSpec(name="horizons", type=Int, default=nothing, description="Periods decomposed (default: effective sample length)"),
                OUTPUT_OPTIONS..., PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="no-standardize", description="Do not scale series by first-difference standard deviation"),
                FlagSpec(name="include-idiosyncratic", description="Include idiosyncratic remainder column"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:gdfm_i1_historical_decomposition, family=true,
                              description="One table per variable: period | actual | initial | one shock-contribution column per shock")],
            category="hd",
            handler=wrap_legacy(_hd_gdfm_i1),
        ),
    ]
end

function w2_test_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", type=String, required=true, default=nothing,
                        description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    out_plot = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    raw = CommandSpec[
        CommandSpec(
            path=["test", "onatski-q"],
            summary="Onatski (2009) dynamic factor rank test and sequential selector",
            args=data_arg,
            options=[
                OptionSpec(name="k0", type=Int, default=nothing, description="Null dynamic rank k0 (omit for sequential selection)"),
                OptionSpec(name="k1", type=Int, default=nothing, description="Alternative max dynamic rank k1 (> k0, <= N-2)"),
                OptionSpec(name="k-max", type=Int, default=nothing, description="Maximum candidate dynamic rank for sequential selection"),
                OptionSpec(name="alpha", type=Float64, default=0.05, description="Significance level for sequential selection"),
                OptionSpec(name="bandwidth", type=Int, default=nothing, description="Lag-window bandwidth M (default: auto)"),
                OptionSpec(name="n-blocks", type=Int, default=nothing, description="Number of disjoint frequency blocks in (0, pi)"),
                OptionSpec(name="kernel", type=String, default="bartlett", description="Spectral kernel: bartlett|parzen|tukey-hanning", choices=["bartlett", "parzen", "tukey-hanning"]),
                OptionSpec(name="freq", type=Float64, default=nothing, description="Optional single angular frequency in (0, pi)"),
                OptionSpec(name="n-sim", type=Int, default=5000, description="GUE Monte Carlo draws when k1 - k0 > 15"),
                OptionSpec(name="seed", type=Int, default=nothing, description="Optional RNG seed"),
                out_plot...,
            ],
            flags=[
                FlagSpec(name="select", description="Run sequential upward selection (onatski_q_select)"),
                FlagSpec(name="no-standardize", description="Do not standardize columns"),
                FlagSpec(name="no-demean", description="Do not demean columns"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:onatski_q_test,
                              description="Onatski (2009) dynamic rank q-test statistic, p-value, critical value, and rejection flag")],
            category="test",
            data_kinds=[:timeseries, :csv],
            result_types=[:OnatskiQTestResult],
            handler=wrap_legacy(_test_onatski_q),
        ),
        CommandSpec(
            path=["test", "ahn-horenstein"],
            summary="Ahn-Horenstein (2013) ER and GR static factor rank selection criteria",
            args=data_arg,
            options=[
                OptionSpec(name="k-max", type=Int, default=nothing, description="Maximum candidate static factors (default: min(10, min(T,N)-2))"),
                out_plot...,
            ],
            flags=[
                FlagSpec(name="no-demean", description="Do not demean columns"),
                FlagSpec(name="no-standardize", description="Do not standardize columns"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:ahn_horenstein_test,
                              description="Ahn-Horenstein (2013) eigenvalues, ER and GR criteria, and selected static ranks r_er and r_gr")],
            category="test",
            data_kinds=[:timeseries, :csv],
            result_types=[:AhnHorensteinResult],
            handler=wrap_legacy(_test_ahn_horenstein),
        ),
        CommandSpec(
            path=["test", "onatski-ed"],
            summary="Onatski (2010) Edge Distribution (ED) static factor rank estimator",
            args=data_arg,
            options=[
                OptionSpec(name="k-max", type=Int, default=nothing, description="Maximum candidate static factors (default: min(10, min(T,N)-2))"),
                OptionSpec(name="max-iter", type=Int, default=20, description="Maximum fixed-point iterations"),
                out_plot...,
            ],
            flags=[
                FlagSpec(name="no-standardize", description="Do not standardize columns"),
                FlagSpec(name="no-demean", description="Do not demean columns"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:onatski_ed_test,
                              description="Onatski (2010) eigenvalues, calibrated delta threshold, selected rank r_ed, and convergence")],
            category="test",
            data_kinds=[:timeseries, :csv],
            result_types=[:OnatskiEDResult],
            handler=wrap_legacy(_test_onatski_ed),
        ),
    ]
    return CommandSpec[_finalize_spec(s) for s in with_result_handles(raw)]
end

function w2_filter_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    out_plot = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    bp = CommandSpec(
        path=["filter", "bandpass-gdfm"],
        summary="Frequency-band GDFM decomposition (two-sided and one-sided FHLR)",
        args=data_arg,
        options=[
            OptionSpec(name="dynamic-rank", type=Int, default=nothing, description="Dynamic rank q when estimating from data (default: auto)"),
            OptionSpec(name="nfactors", type=Int, default=nothing, description="Static rank r for one-sided projection (default: gdfm.r or auto)"),
            OptionSpec(name="pl", type=Float64, default=6.0, description="Minimum period of oscillation (converted to 2pi/pl)"),
            OptionSpec(name="pu", type=Float64, default=32.0, description="Maximum period of oscillation (converted to 2pi/pu)"),
            OptionSpec(name="band-low", type=Float64, default=nothing, description="Explicit lower angular frequency in [0, pi) (radians)"),
            OptionSpec(name="band-high", type=Float64, default=nothing, description="Explicit upper angular frequency in (0, pi] (radians)"),
            OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral lag-window bandwidth when estimating from data (0=auto)"),
            OptionSpec(name="kernel", type=String, default="bartlett", description="Spectral kernel: bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
            OptionSpec(name="spectral", type=String, default="lag-window", description="GDFM spectrum: lag-window|smoothed-periodogram", choices=["lag-window", "smoothed-periodogram"]),
            out_plot...,
        ],
        flags=copy(PLOT_FLAGS),
        tables=[TableSpec(name=:bandpass_gdfm,
                          description="Band-pass GDFM two-sided and one-sided common components: time | variable | twosided | onesided")],
        category="filter",
        data_kinds=[:timeseries, :csv],
        model_types=[:GeneralizedDynamicFactorModel],
        result_types=[:BandPassGDFMResult],
        handler=wrap_legacy(_filter_bandpass_gdfm),
    )
    ec = CommandSpec(
        path=["filter", "eurocoin"],
        summary="Altissimo et al. (2010) real-time Eurocoin low-frequency growth indicator",
        args=data_arg,
        options=[
            OptionSpec(name="target", type=String, default="", description="Target series column name or 1-based index (default: 1)"),
            OptionSpec(name="dynamic-rank", type=Int, default=nothing, description="Number of dynamic common shocks q (default: auto)"),
            OptionSpec(name="nfactors", type=Int, default=0, description="Static rank r for one-sided projection (0 defaults to q)"),
            OptionSpec(name="cutoff", type=Float64, default=Float64(π / 6), description="Angular frequency low-pass cutoff in (0, pi) (default: pi/6)"),
            OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral lag-window bandwidth (0=auto)"),
            OptionSpec(name="kernel", type=String, default="bartlett", description="Spectral kernel: bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
            out_plot...,
        ],
        flags=[FlagSpec(name="no-standardize", description="Do not standardize panel columns"); PLOT_FLAGS],
        tables=[TableSpec(name=:eurocoin_indicator,
                          description="Real-time Eurocoin indicator, benchmark low-pass target, R2 and cutoff by period")],
        category="filter",
        data_kinds=[:timeseries, :csv],
        result_types=[:EurocoinResult],
        handler=wrap_legacy(_filter_eurocoin),
    )
    bp_ready = with_save_model(with_model_option(with_result_handles([bp])))[1]
    ec_ready = with_result_handles([ec])[1]
    return CommandSpec[bp_ready, ec_ready]
end

function w2_spectral_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")]
    out_plot = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    sp = CommandSpec(
        path=["spectral", "fevd"],
        summary="Frequency-band structural FEVD for a Structural DFM",
        args=data_arg,
        options=[
            OptionSpec(name="factors", short="q", type=Int, default=nothing, description="Number of dynamic factors (default: auto via --q-method)"),
            OptionSpec(name="id", type=String, default="cholesky", choices=_ID_CHOICES_SDFM, description=_SDFM_ID_DESC),
            OptionSpec(name="q-method", type=String, default="hallin-liska", description="Auto factor selection: hallin-liska|bai-ng|amengual-watson", choices=["hallin-liska", "bai-ng", "amengual-watson"]),
            OptionSpec(name="method", type=String, default="fglr", description="Structural estimator: fglr|fhlz|gdfm-var", choices=["fglr", "fhlz", "gdfm-var"]),
            OptionSpec(name="spectral", type=String, default="lag-window", description="GDFM spectrum: lag-window|smoothed-periodogram", choices=["lag-window", "smoothed-periodogram"]),
            OptionSpec(name="instrument", type=String, default="", description="Proxy-instrument CSV column (only with --id proxy)"),
            OptionSpec(name="var-lags", type=String, default="auto", description="Factor VAR lag order (positive integer or auto|aic|bic|hq)"),
            OptionSpec(name="n-perm", type=Int, default=30, description="Cross-sectional permutations for --method fhlz"),
            OptionSpec(name="p-max", type=Int, default=nothing, description="Maximum lag order for automatic/FHLZ lag selection"),
            OptionSpec(name="target", type=String, default="", description="Target variable name or 1-based index (for --id max-share)"),
            OptionSpec(name="horizons", type=Int, default=40, description="Structural IRF horizon for SDFM estimation"),
            OptionSpec(name="config", type=String, default="", description="TOML config for sign restrictions or lewis-tvv/sv-em"),
            OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral bandwidth (0=auto)"),
            OptionSpec(name="kernel", type=String, default="bartlett", description="bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
            OptionSpec(name="pl", type=Float64, default=6.0, description="Minimum period of oscillation (default: 6)"),
            OptionSpec(name="pu", type=Float64, default=32.0, description="Maximum period of oscillation (default: 32)"),
            OptionSpec(name="band-low", type=Float64, default=nothing, description="Explicit lower angular frequency in [0, pi) (radians)"),
            OptionSpec(name="band-high", type=Float64, default=nothing, description="Explicit upper angular frequency in (0, pi] (radians)"),
            out_plot...,
        ],
        flags=[
            FlagSpec(name="include-idiosyncratic", description="Append idiosyncratic band variance share column"),
            PLOT_FLAGS...,
        ],
        tables=[TableSpec(name=:spectral_fevd,
                          description="Frequency-band structural FEVD shares and band power: variable | shock | share | power_band")],
        category="spectral",
        data_kinds=[:timeseries, :csv],
        model_types=[:StructuralDFM],
        result_types=[:SpectralFEVDResult],
        handler=wrap_legacy(_spectral_fevd),
    )
    return with_save_model(with_config_ergonomics(with_result_handles(with_model_option([sp]))))
end

function w2_nowcast_specs()::Vector{CommandSpec}
    data_arg = [ArgSpec(name="data", description="Path to ragged-edge data file or handle stem (.csv, .jld2, .jls)")]
    out_plot = [OUTPUT_OPTIONS; PLOT_OPTIONS]
    ng = CommandSpec(
        path=["nowcast", "gdfm"],
        summary="Ragged-edge Wiener-Kolmogorov nowcasting from a Generalized Dynamic Factor Model",
        args=data_arg,
        options=[
            OptionSpec(name="dynamic-rank", type=Int, default=nothing, description="Dynamic rank q when estimating from data (default: auto)"),
            OptionSpec(name="nfactors", type=Int, default=nothing, description="Static rank r when estimating from data (default: auto)"),
            OptionSpec(name="horizons", aliases=["horizon"], kwarg=:horizons, type=Int, default=0, description="Horizon h relative to T_r (0=nowcast, >0=forecast, <0=backcast)"),
            OptionSpec(name="n-lags", type=Int, default=2, description="Past lags included in Wiener-Kolmogorov conditioning window (>= 0)"),
            OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral lag-window bandwidth when estimating from data (0=auto)"),
            OptionSpec(name="kernel", type=String, default="bartlett", description="Spectral kernel: bartlett|parzen|tukey", choices=["bartlett", "parzen", "tukey"]),
            OptionSpec(name="spectral", type=String, default="lag-window", description="GDFM spectrum: lag-window|smoothed-periodogram", choices=["lag-window", "smoothed-periodogram"]),
            OptionSpec(name="em-max-iter", type=Int, default=50, description="Maximum EM iterations for ragged-edge estimation"),
            OptionSpec(name="em-tol", type=Float64, default=1e-4, description="EM convergence tolerance for ragged-edge estimation"),
            out_plot...,
        ],
        flags=copy(PLOT_FLAGS),
        tables=[TableSpec(name=:nowcast_gdfm,
                          description="GDFM ragged-edge nowcasts, predictive standard errors, horizon, and observation mask by variable")],
        category="nowcast",
        data_kinds=[:timeseries, :csv],
        model_types=[:GeneralizedDynamicFactorModel],
        result_types=[:GDFMNowcastResult],
        allow_data_with_model=true,
        handler=wrap_legacy(_nowcast_gdfm),
    )
    return with_save_model(with_result_handles(with_model_option([ng])))
end
