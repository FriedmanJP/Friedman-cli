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

# [MEM111-W3] #315 — LMS non-Gaussian SVAR, 7-type hypothesis battery,
# Lanne-Luoto co-kurtosis GMM, moment selection, non-fundamental Strong SVARMA,
# and fundamentalness / sufficient-information tests.

# ── Shared Wave-3 Parsers & Helpers ────────────────────────────────────────

const _W3_LMS_DIST_MAP = Dict{String,Symbol}(
    "student-t"            => :student_t,
    "student_t"            => :student_t,
    "skewed-t"             => :skewed_t,
    "skewed_t"             => :skewed_t,
    "mixture-normal"       => :mixture_normal_asym,
    "mixture_normal"       => :mixture_normal_asym,
    "mixture-normal-asym"  => :mixture_normal_asym,
    "mixture_normal_asym"  => :mixture_normal_asym,
    "skew-normal"          => :skew_normal,
    "skew_normal"          => :skew_normal,
    "pearson-iv"           => :pearson_iv,
    "pearson_iv"           => :pearson_iv,
    "pml"                  => :pearson_iv,
    "ged"                  => :ged,
    "laplace-generalized"  => :ged,
    "laplace_generalized"  => :ged,
)

function _w3_parse_lms_distributions(raw::String, n::Int, leaf::String)
    toks = String[lowercase(strip(s)) for s in split(raw, ",") if !isempty(strip(s))]
    isempty(toks) && throw(CliError("usage/invalid",
        "$leaf: --distributions must specify at least one distribution (student-t|skewed-t|mixture-normal|skew-normal|pearson-iv|ged)"))
    syms = Symbol[]
    for tok in toks
        haskey(_W3_LMS_DIST_MAP, tok) || throw(CliError("usage/invalid",
            "$leaf: unknown distribution '$tok'; expected student-t|skewed-t|mixture-normal|skew-normal|pearson-iv|ged"))
        push!(syms, _W3_LMS_DIST_MAP[tok])
    end
    length(syms) == 1 && return syms[1]
    length(syms) == n || throw(CliError("usage/invalid",
        "$leaf: --distributions list has $(length(syms)) entries for $n variables (provide 1 or $n)"))
    return syms
end

function _w3_parse_shock_names(raw::String, n::Int, leaf::String)
    isempty(strip(raw)) && return nothing
    names = String[strip(s) for s in split(raw, ",") if !isempty(strip(s))]
    length(names) == n || throw(CliError("usage/invalid",
        "$leaf: --shock-names has $(length(names)) entries, expected $n"))
    return names
end

function _w3_parse_kernel(raw::String, leaf::String)::Symbol
    k = lowercase(strip(raw))
    k == "bartlett" && return :bartlett
    k == "parzen" && return :parzen
    (k == "qs" || k == "quadratic-spectral" || k == "quadratic_spectral") && return :quadratic_spectral
    (k == "tukey-hanning" || k == "tukey_hanning") && return :tukey_hanning
    throw(CliError("usage/invalid",
        "$leaf: --kernel must be bartlett|parzen|qs|quadratic-spectral|tukey-hanning (got '$raw')"))
end

function _w3_parse_bandwidth(raw::String, leaf::String)
    s = lowercase(strip(raw))
    s == "auto" && return :auto
    s == "nw94" && return :nw94
    s == "andrews" && return :andrews
    n = tryparse(Int, s)
    if n !== nothing && n >= 0
        return n
    end
    throw(CliError("usage/invalid",
        "$leaf: --bandwidth must be auto|nw94|andrews or a non-negative integer (got '$raw')"))
end

function _w3_lms_method(raw::String, leaf::String)::Symbol
    m = lowercase(strip(raw))
    m in ("three-step", "three_step") && return :three_step
    m in ("one-step", "one_step", "full-ml", "full_ml") && return :full_ml
    throw(CliError("usage/invalid",
        "$leaf: --method must be three-step|one-step|full-ml (got '$raw')"))
end

function _w3_ssvarma_method(raw::String, leaf::String)::Symbol
    m = lowercase(strip(raw))
    m == "pml" && return :pml
    m == "ml" && return :ml
    m in ("gmm", "gmm-2sls", "gmm_2sls") && return :gmm
    throw(CliError("usage/invalid",
        "$leaf: --method must be pml|ml|gmm|gmm-2sls (got '$raw')"))
end

function _w3_ssvarma_dist(raw::String, leaf::String)::Symbol
    d = replace(lowercase(strip(raw)), "-" => "_")
    d in ("student_t", "mixture_normal", "mixture_normal_asym", "pearson_iv", "pml", "skew_normal") && return Symbol(d)
    throw(CliError("usage/invalid",
        "$leaf: --distribution must be student-t|mixture-normal|mixture-normal-asym|pearson-iv|skew-normal (got '$raw')"))
end

function _w3_shock_df(shocks::AbstractMatrix, shock_names::Vector{String})
    T_eff, n = size(shocks)
    cols = length(shock_names) == n ? shock_names : ["shock_$j" for j in 1:n]
    df = DataFrame()
    df.t = 1:T_eff
    for (j, col) in enumerate(cols)
        df[!, col] = shocks[:, j]
    end
    return df
end

function _w3_build_sub_hypothesis(spec::Dict{String,Any}, n::Int)
    htype = spec["type"]
    ord = get(spec, "ordering", nothing)
    try
        if htype == "recursiveness"
            return recursiveness_hypothesis(n; ordering=ord)
        elseif htype == "impact_zero"
            return impact_zero_hypothesis(n, spec["zeros"]; ordering=ord)
        elseif htype == "impact_linear"
            return impact_linear_hypothesis(spec["R"], spec["r"]; ordering=ord)
        elseif htype == "long_run"
            return long_run_hypothesis(n, spec["zeros"]; ordering=ord)
        elseif htype == "horizon_irf"
            return horizon_irf_hypothesis(n, spec["restrictions"]; ordering=ord)
        elseif htype == "mixed"
            sr = spec["short_run"] === nothing ? nothing : _w3_build_sub_hypothesis(spec["short_run"], n)
            lr = spec["long_run"] === nothing ? nothing : _w3_build_sub_hypothesis(spec["long_run"], n)
            hz = spec["horizon"] === nothing ? nothing : _w3_build_sub_hypothesis(spec["horizon"], n)
            return mixed_svar_hypothesis(; short_run=sr, long_run=lr, horizon=hz)
        else
            throw(CliError("config/invalid", "unknown [svar_hypothesis].type '$htype'"))
        end
    catch e
        e isa CliError && rethrow()
        throw(CliError("config/invalid",
            "invalid SVAR hypothesis specification: $(sprint(showerror, e))"))
    end
end

function _w3_build_svar_hypothesis(hyp_type::String, config::String, n::Int)
    norm_type = isempty(strip(hyp_type)) ? "" : replace(lowercase(strip(hyp_type)), "-" => "_")
    if isempty(config)
        if isempty(norm_type) || norm_type == "recursiveness"
            return try
                recursiveness_hypothesis(n)
            catch e
                throw(CliError("config/invalid", "invalid recursiveness hypothesis: $(sprint(showerror, e))"))
            end
        end
        throw(CliError("usage/missing-option",
            "test multivariate svar-hypothesis: --type $hyp_type requires --config <toml> with a [svar_hypothesis] stanza"))
    end
    cfg = load_config(config)
    spec = get_svar_hypothesis(cfg)
    if !isempty(norm_type) && norm_type != spec["type"]
        throw(CliError("config/invalid",
            "test multivariate svar-hypothesis: --type '$hyp_type' conflicts with [svar_hypothesis].type = '$(spec["type"])'"))
    end
    return _w3_build_sub_hypothesis(spec, n)
end

# ── Downstream IRF / FEVD / HD Bridges for LMS-SVAR & Lanne-Luoto GMM ─────

function _w3_preidentified_irf(model::Union{LMSSVARResult,LanneLuotoGMMResult};
                               horizons::Int, shock::Int, id::String,
                               ci::String, replications::Int,
                               bootstrap::String, block_length::Int,
                               wild_dist::String, bias_correct::Bool,
                               bias_reps::Int, stationary_only::Bool,
                               cumulative::Bool, identified_set::Bool,
                               bootstrap_across_rotations::Bool, summary::String,
                               format::String, output::String,
                               plot::Bool, plot_save::String)
    label = model isa LMSSVARResult ? "lms-svar" : "lanne-luoto"
    id in ("cholesky", "svar", "lms", "lanne-luoto") || throw(CliError("usage/invalid",
        "irf var: $(nameof(typeof(model))) is already structurally identified; omit --id (got --id $id)"))
    identified_set && throw(CliError("usage/invalid",
        "irf var: --identified-set does not apply to $(nameof(typeof(model)))"))
    bootstrap_across_rotations && throw(CliError("usage/invalid",
        "irf var: --bootstrap-across-rotations does not apply to $(nameof(typeof(model)))"))
    summary == "none" || throw(CliError("usage/invalid",
        "irf var: --summary does not apply to $(nameof(typeof(model)))"))
    boot = lowercase(strip(bootstrap))
    boot in ("iid", "wild", "block") || throw(CliError("usage/invalid-option",
        "invalid --bootstrap '$bootstrap'; must be iid, wild or block"))
    wdist = lowercase(strip(wild_dist))
    wdist in ("rademacher", "mammen") || throw(CliError("usage/invalid-option",
        "invalid --wild-dist '$wild_dist'; must be rademacher or mammen"))
    block_length >= 0 || throw(CliError("usage/invalid", "--block-length must be ≥ 0 (got $block_length)"))
    bias_reps >= 0 || throw(CliError("usage/invalid", "--bias-reps must be ≥ 0 (got $bias_reps)"))
    n = size(model.B0, 1)
    1 <= shock <= n || throw(CliError("usage/invalid",
        "irf var: --shock index $shock out of 1:$n"))

    kw = Dict{Symbol,Any}(:ci_type => Symbol(ci), :reps => replications)
    if ci == "bootstrap"
        kw[:bootstrap] = Symbol(boot)
        kw[:block_length] = block_length
        kw[:wild_dist] = Symbol(wdist)
        kw[:bias_correct] = bias_correct
        kw[:bias_reps] = bias_reps
    end
    stationary_only && (kw[:stationary_only] = true)
    isnothing(_SEED[]) || (kw[:seed] = _SEED[])

    irf_result = try
        if model isa LMSSVARResult
            irf(model.var_ols, horizons; method=:svar, _svar_Q=model.Q,
                shock_names=model.shock_names, kw...)
        else
            irf(model, horizons; kw...)
        end
    catch e
        throw(_domain_or_data_error(e, "$(uppercase(label)) IRF"))
    end
    cumulative && (irf_result = cumulative_irf(irf_result))
    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)
    _status_report(() -> report(irf_result))
    shock_name = irf_result.shocks[shock]
    _emit_result(irf_result; title="IRF to $shock_name shock ($label identification)", key="irf",
                 format=Symbol(format), output=output, shocks=shock_name)
    return (; model, result=irf_result)
end

function _w3_preidentified_fevd(model::Union{LMSSVARResult,LanneLuotoGMMResult};
                                horizons::Int, id::String, generalized::Bool,
                                format::String, output::String,
                                plot::Bool, plot_save::String)
    label = model isa LMSSVARResult ? "lms-svar" : "lanne-luoto"
    id in ("cholesky", "svar", "lms", "lanne-luoto") || throw(CliError("usage/invalid",
        "fevd var: $(nameof(typeof(model))) is already structurally identified; omit --id (got --id $id)"))
    generalized && throw(CliError("usage/invalid",
        "fevd var: --generalized does not apply to $(nameof(typeof(model)))"))
    fevd_result = try
        if model isa LMSSVARResult
            fevd(model.var_ols, horizons; method=:svar, _svar_Q=model.Q,
                 shock_names=model.shock_names)
        else
            fevd(model, horizons)
        end
    catch e
        throw(_domain_or_data_error(e, "$(uppercase(label)) FEVD"))
    end
    _status_report(() -> report(fevd_result))
    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)
    _emit_result(fevd_result; title="FEVD ($label identification)", key="fevd",
                 format=Symbol(format), output=output)
    return (; model, result=fevd_result)
end

function _w3_preidentified_hd(model::Union{LMSSVARResult,LanneLuotoGMMResult};
                              id::String, format::String, output::String,
                              plot::Bool, plot_save::String)
    label = model isa LMSSVARResult ? "lms-svar" : "lanne-luoto"
    id in ("cholesky", "svar", "lms", "lanne-luoto") || throw(CliError("usage/invalid",
        "hd var: $(nameof(typeof(model))) is already structurally identified; omit --id (got --id $id)"))
    varnames = model isa LMSSVARResult ? _model_varnames(model.var_ols) : _model_varnames(model)
    hd_result = try
        if model isa LMSSVARResult
            historical_decomposition(model.var_ols, size(model.shocks, 1);
                                     method=:svar, _svar_Q=model.Q,
                                     shock_names=model.shock_names)
        else
            historical_decomposition(model)
        end
    catch e
        throw(_domain_or_data_error(e, "$(uppercase(label)) historical decomposition"))
    end
    _status_report(() -> report(hd_result))
    _maybe_plot(hd_result; plot=plot, plot_save=plot_save)
    verify_decomposition(hd_result)
    _output_hd_tables((vi, si) -> contribution(hd_result, vi, si), varnames, hd_result.T_eff;
                      id=label, title_prefix="Historical Decomposition",
                      format=format, output=output,
                      actual=hd_result.actual, initial=hd_result.initial_conditions,
                      key_prefix="historical_decomposition")
    return (; model, result=hd_result)
end

# ── Estimation Handlers ────────────────────────────────────────────────────

function _estimate_lms_svar(; data::String, lags=nothing,
                            distributions::String="student-t",
                            method::String="three-step",
                            se::String="hessian",
                            n_starts::Int=5,
                            max_iter::Int=500,
                            tol=nothing,
                            shock_names::String="",
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
    n_starts >= 1 || throw(CliError("usage/invalid",
        "estimate multivariate lms-svar: --n-starts must be ≥ 1 (got $n_starts)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "estimate multivariate lms-svar: --max-iter must be ≥ 1 (got $max_iter)"))
    tol === nothing || tol > 0 || throw(CliError("usage/invalid",
        "estimate multivariate lms-svar: --tol must be > 0 (got $tol)"))
    method_sym = _w3_lms_method(method, "estimate multivariate lms-svar")
    se_sym = Symbol(replace(lowercase(strip(se)), "-" => "_"))
    se_sym in (:hessian, :sandwich, :opg) || throw(CliError("usage/invalid",
        "estimate multivariate lms-svar: --se must be hessian|sandwich|opg (got '$se')"))

    var_model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)
    dists = _w3_parse_lms_distributions(distributions, n, "estimate multivariate lms-svar")
    snames = _w3_parse_shock_names(shock_names, n, "estimate multivariate lms-svar")

    _status("LMS Non-Gaussian SVAR: VAR($p), $n variables, method=$method_sym, se=$se_sym")
    _status()

    res = try
        estimate_lms_svar(var_model;
            distributions=dists, method=method_sym, se=se_sym,
            n_starts=n_starts, max_iter=max_iter, tol=tol,
            shock_names=snames, _fwd_seed()...)
    catch e
        throw(_domain_or_data_error(e, "LMS SVAR"))
    end

    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="LMS Non-Gaussian SVAR", key="lms_svar_estimates",
                 format=Symbol(format), output=output)
    return res
end

function _estimate_lanne_luoto(; data::String, lags=nothing,
                               form::String="b-model",
                               weighting::String="two-step",
                               moment_selection::String="msc-rmsc",
                               kernel::String="bartlett",
                               bandwidth::String="auto",
                               max_iter::Int=100,
                               tol::Float64=1e-7,
                               n_starts::Int=5,
                               shock_names::String="",
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    max_iter >= 1 || throw(CliError("usage/invalid",
        "estimate multivariate lanne-luoto: --max-iter must be ≥ 1 (got $max_iter)"))
    tol > 0 || throw(CliError("usage/invalid",
        "estimate multivariate lanne-luoto: --tol must be > 0 (got $tol)"))
    n_starts >= 1 || throw(CliError("usage/invalid",
        "estimate multivariate lanne-luoto: --n-starts must be ≥ 1 (got $n_starts)"))
    form_sym = _to_sym(lowercase(strip(form)))
    form_sym in (:b_model, :a_model) || throw(CliError("usage/invalid",
        "estimate multivariate lanne-luoto: --form must be b-model|a-model (got '$form')"))
    w_sym = _to_sym(lowercase(strip(weighting)))
    w_sym in (:two_step, :iterated, :cue) || throw(CliError("usage/invalid",
        "estimate multivariate lanne-luoto: --weighting must be two-step|iterated|cue (got '$weighting')"))
    ms_sym = _to_sym(lowercase(strip(moment_selection)))
    ms_sym in (:msc_rmsc, :rmsc_seq, :none) || throw(CliError("usage/invalid",
        "estimate multivariate lanne-luoto: --moment-selection must be msc-rmsc|rmsc-seq|none (got '$moment_selection')"))
    k_sym = _w3_parse_kernel(kernel, "estimate multivariate lanne-luoto")
    bw = _w3_parse_bandwidth(bandwidth, "estimate multivariate lanne-luoto")

    var_model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)
    snames = _w3_parse_shock_names(shock_names, n, "estimate multivariate lanne-luoto")

    _status("Lanne-Luoto Co-Kurtosis GMM SVAR: VAR($p), $n variables, form=$form_sym, weighting=$w_sym")
    _status()

    res = try
        estimate_lanne_luoto_gmm(var_model;
            form=form_sym, weighting=w_sym, moment_selection=ms_sym,
            kernel=k_sym, bandwidth=bw, max_iter=max_iter, tol=tol,
            n_starts=n_starts, shock_names=snames, _fwd_seed()...)
    catch e
        throw(_domain_or_data_error(e, "Lanne-Luoto GMM"))
    end

    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="Lanne-Luoto Co-Kurtosis GMM SVAR",
                 key="lanne_luoto_gmm_estimates",
                 format=Symbol(format), output=output)
    return res
end

function _estimate_ssvarma(; data::String,
                           ar_lags::Int=1, ma_lags::Int=1,
                           method::String="pml",
                           distribution::String="student-t",
                           k_iv=nothing,
                           se::String="auto",
                           n_starts::Int=3,
                           max_iter::Int=500,
                           tol::Float64=1e-6,
                           shock_names::String="",
                           blaschke::Bool=false,
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    ar_lags >= 0 || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --ar-lags must be ≥ 0 (got $ar_lags)"))
    ma_lags >= 0 || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --ma-lags must be ≥ 0 (got $ma_lags)"))
    n_starts >= 1 || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --n-starts must be ≥ 1 (got $n_starts)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --max-iter must be ≥ 1 (got $max_iter)"))
    tol > 0 || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --tol must be > 0 (got $tol)"))
    k_iv_eff = k_iv === nothing ? (ar_lags + 3) : Int(k_iv)
    k_iv_eff >= ar_lags || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --k-iv ($k_iv_eff) must be ≥ --ar-lags ($ar_lags)"))
    method_sym = _w3_ssvarma_method(method, "estimate multivariate ssvarma")
    dist_sym = _w3_ssvarma_dist(distribution, "estimate multivariate ssvarma")
    se_sym = _to_sym(lowercase(strip(se)))
    se_sym in (:auto, :hessian, :sandwich, :opg) || throw(CliError("usage/invalid",
        "estimate multivariate ssvarma: --se must be auto|hessian|sandwich|opg (got '$se')"))

    Y, varnames = load_multivariate_data(data)
    n = length(varnames)
    snames = _w3_parse_shock_names(shock_names, n, "estimate multivariate ssvarma")

    _status("Strong SVARMA($ar_lags, $ma_lags): $n variables, method=$method_sym, dist=$dist_sym")
    _status()

    m = try
        estimate_ssvarma(Y, ar_lags, ma_lags;
            method=method_sym, distribution=dist_sym, k_iv=k_iv_eff,
            se=se_sym, max_iter=max_iter, tol=tol, n_starts=n_starts,
            varnames=varnames, shock_names=snames, _fwd_seed()...)
    catch e
        throw(_domain_or_data_error(e, "Strong SVARMA"))
    end

    _status_report(() -> report(m))
    _maybe_plot(m; plot=plot, plot_save=plot_save)
    _emit_result(m; title="Strong SVARMA($ar_lags, $ma_lags)", key="ssvarma_estimates",
                 format=Symbol(format), output=output)

    if blaschke
        reg = try
            fundamentalness_regime(m)
        catch e
            throw(_domain_or_data_error(e, "SVARMA regime"))
        end
        output_kv(Pair{String,Any}[
            "regime" => string(reg.regime),
            "gmr_region" => string(reg.gmr_region),
            "n_fundamental" => reg.n_fundamental,
            "n_nonfundamental" => reg.n_nonfundamental,
            "n_eigenvalues" => length(reg.eigenvalues),
        ]; format=format, output=_per_var_output_path(output, "regime"),
           title="SVARMA Fundamentalness Regime", key="ssvarma_regime")

        reps = try
            blaschke_representations(m)
        catch e
            throw(_domain_or_data_error(e, "SVARMA Blaschke representations"))
        end
        bl_df = DataFrame(
            representation = collect(1:length(reps)),
            regime = [string(r.regime) for r in reps],
            gmr_region = [string(r.gmr_region) for r in reps],
            n_nonfundamental = [Int(r.n_nonfundamental) for r in reps],
            max_abs_eig = [isempty(r.eigenvalues) ? 0.0 : maximum(abs, r.eigenvalues) for r in reps],
        )
        output_result(bl_df; format=Symbol(format),
                      output=_per_var_output_path(output, "blaschke"),
                      title="Blaschke Equivalent Representations",
                      key="ssvarma_blaschke")
    end
    return m
end

# ── Residuals Handlers ─────────────────────────────────────────────────────

function _residuals_lms_svar(; data::String="", lags=nothing,
                             distributions::String="student-t",
                             method::String="three-step",
                             se::String="hessian",
                             n_starts::Int=5,
                             max_iter::Int=500,
                             tol=nothing,
                             shock_names::String="",
                             output::String="", format::String="table",
                             model=nothing)
    if isnothing(model)
        var_model, _, varnames, _ = _load_and_estimate_var(data, lags)
        n = length(varnames)
        dists = _w3_parse_lms_distributions(distributions, n, "residuals multivariate lms-svar")
        snames = _w3_parse_shock_names(shock_names, n, "residuals multivariate lms-svar")
        method_sym = _w3_lms_method(method, "residuals multivariate lms-svar")
        se_sym = _to_sym(lowercase(strip(se)))
        model = try
            estimate_lms_svar(var_model;
                distributions=dists, method=method_sym, se=se_sym,
                n_starts=n_starts, max_iter=max_iter, tol=tol,
                shock_names=snames, _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "LMS SVAR residuals"))
        end
    end
    shocks = residuals(model)
    df = _w3_shock_df(shocks, model.shock_names)
    output_result(df; format=Symbol(format), output=output,
                  title="LMS SVAR Structural Shocks (T_eff=$(size(shocks, 1)))",
                  key="lms_svar_residuals")
end

function _residuals_lanne_luoto(; data::String="", lags=nothing,
                                form::String="b-model",
                                weighting::String="two-step",
                                moment_selection::String="msc-rmsc",
                                kernel::String="bartlett",
                                bandwidth::String="auto",
                                max_iter::Int=100,
                                tol::Float64=1e-7,
                                n_starts::Int=5,
                                shock_names::String="",
                                output::String="", format::String="table",
                                model=nothing)
    if isnothing(model)
        var_model, _, varnames, _ = _load_and_estimate_var(data, lags)
        n = length(varnames)
        snames = _w3_parse_shock_names(shock_names, n, "residuals multivariate lanne-luoto")
        form_sym = _to_sym(lowercase(strip(form)))
        w_sym = _to_sym(lowercase(strip(weighting)))
        ms_sym = _to_sym(lowercase(strip(moment_selection)))
        k_sym = _w3_parse_kernel(kernel, "residuals multivariate lanne-luoto")
        bw = _w3_parse_bandwidth(bandwidth, "residuals multivariate lanne-luoto")
        model = try
            estimate_lanne_luoto_gmm(var_model;
                form=form_sym, weighting=w_sym, moment_selection=ms_sym,
                kernel=k_sym, bandwidth=bw, max_iter=max_iter, tol=tol,
                n_starts=n_starts, shock_names=snames, _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "Lanne-Luoto GMM residuals"))
        end
    end
    shocks = residuals(model)
    df = _w3_shock_df(shocks, model.shock_names)
    output_result(df; format=Symbol(format), output=output,
                  title="Lanne-Luoto GMM Structural Shocks (T_eff=$(size(shocks, 1)))",
                  key="lanne_luoto_residuals")
end

function _residuals_ssvarma(; data::String="",
                            ar_lags::Int=1, ma_lags::Int=1,
                            method::String="pml",
                            distribution::String="student-t",
                            k_iv=nothing,
                            se::String="auto",
                            n_starts::Int=3,
                            max_iter::Int=500,
                            tol::Float64=1e-6,
                            shock_names::String="",
                            output::String="", format::String="table",
                            model=nothing)
    if isnothing(model)
        Y, varnames = load_multivariate_data(data)
        n = length(varnames)
        snames = _w3_parse_shock_names(shock_names, n, "residuals multivariate ssvarma")
        k_iv_eff = k_iv === nothing ? (ar_lags + 3) : Int(k_iv)
        method_sym = _w3_ssvarma_method(method, "residuals multivariate ssvarma")
        dist_sym = _w3_ssvarma_dist(distribution, "residuals multivariate ssvarma")
        se_sym = _to_sym(lowercase(strip(se)))
        model = try
            estimate_ssvarma(Y, ar_lags, ma_lags;
                method=method_sym, distribution=dist_sym, k_iv=k_iv_eff,
                se=se_sym, max_iter=max_iter, tol=tol, n_starts=n_starts,
                varnames=varnames, shock_names=snames, _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "Strong SVARMA residuals"))
        end
    end
    shocks = try
        ssvarma_filter_shocks(model).shocks
    catch
        residuals(model)
    end
    df = _w3_shock_df(shocks, model.shock_names)
    output_result(df; format=Symbol(format), output=output,
                  title="Strong SVARMA Filtered Shocks (T_eff=$(size(shocks, 1)))",
                  key="ssvarma_residuals")
end

# ── SSVARMA IRF & FEVD Handlers ───────────────────────────────────────────

function _irf_ssvarma(; data::String="", result=nothing, model=nothing,
                      ar_lags::Int=1, ma_lags::Int=1,
                      method::String="pml",
                      distribution::String="student-t",
                      k_iv=nothing,
                      se::String="auto",
                      n_starts::Int=3,
                      max_iter::Int=500,
                      tol::Float64=1e-6,
                      shock::Int=1, horizons::Int=20,
                      cumulative::Bool=false,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, model, leaf="irf ssvarma",
                            horizons, horizons_default=20)
    loaded === nothing || return _rerender_irf_result(loaded; format, output,
        title="Strong SVARMA Impulse Responses", key="ssvarma_irf",
        plot, plot_save, shock)
    if isnothing(model)
        Y, varnames = load_multivariate_data(data)
        k_iv_eff = k_iv === nothing ? (ar_lags + 3) : Int(k_iv)
        method_sym = _w3_ssvarma_method(method, "irf ssvarma")
        dist_sym = _w3_ssvarma_dist(distribution, "irf ssvarma")
        se_sym = _to_sym(lowercase(strip(se)))
        model = try
            estimate_ssvarma(Y, ar_lags, ma_lags;
                method=method_sym, distribution=dist_sym, k_iv=k_iv_eff,
                se=se_sym, max_iter=max_iter, tol=tol, n_starts=n_starts,
                varnames=varnames, _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "Strong SVARMA IRF"))
        end
    end
    n = size(model.C, 1)
    1 <= shock <= n || throw(CliError("usage/invalid",
        "irf ssvarma: --shock index $shock out of 1:$n"))
    irf_result = try
        irf(model, horizons)
    catch e
        throw(_domain_or_data_error(e, "Strong SVARMA IRF"))
    end
    cumulative && (irf_result = cumulative_irf(irf_result))
    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)
    _status_report(() -> report(irf_result))
    shock_name = irf_result.shocks[shock]
    _emit_result(irf_result; title="Strong SVARMA IRF to $shock_name shock",
                 key="ssvarma_irf", format=Symbol(format), output=output,
                 shocks=shock_name)
    return (; model, result=irf_result)
end

function _fevd_ssvarma(; data::String="", result=nothing, model=nothing,
                       ar_lags::Int=1, ma_lags::Int=1,
                       method::String="pml",
                       distribution::String="student-t",
                       k_iv=nothing,
                       se::String="auto",
                       n_starts::Int=3,
                       max_iter::Int=500,
                       tol::Float64=1e-6,
                       horizons::Int=20,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="")
    loaded = _loaded_result(result; data, model, leaf="fevd ssvarma",
                            horizons, horizons_default=20)
    loaded === nothing || return _rerender_fevd_result(loaded; format, output,
        title="Strong SVARMA FEVD", key="ssvarma_fevd", plot, plot_save)
    if isnothing(model)
        Y, varnames = load_multivariate_data(data)
        k_iv_eff = k_iv === nothing ? (ar_lags + 3) : Int(k_iv)
        method_sym = _w3_ssvarma_method(method, "fevd ssvarma")
        dist_sym = _w3_ssvarma_dist(distribution, "fevd ssvarma")
        se_sym = _to_sym(lowercase(strip(se)))
        model = try
            estimate_ssvarma(Y, ar_lags, ma_lags;
                method=method_sym, distribution=dist_sym, k_iv=k_iv_eff,
                se=se_sym, max_iter=max_iter, tol=tol, n_starts=n_starts,
                varnames=varnames, _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "Strong SVARMA FEVD"))
        end
    end
    fevd_result = try
        fevd(model, horizons)
    catch e
        throw(_domain_or_data_error(e, "Strong SVARMA FEVD"))
    end
    _status_report(() -> report(fevd_result))
    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)
    _emit_result(fevd_result; title="Strong SVARMA FEVD", key="ssvarma_fevd",
                 format=Symbol(format), output=output)
    return (; model, result=fevd_result)
end

# ── Statistical Test Handlers ──────────────────────────────────────────────

function _test_svar_hypothesis(; data::String="", model=nothing, lags=nothing,
                               estimator::String="lms",
                               distributions::String="student-t",
                               type::String="",
                               config::String="",
                               method::String="wald",
                               bootstrap::String="none",
                               n_boot::Int=499,
                               max_iter::Int=500,
                               tol::Float64=1e-7,
                               vcov_type::String="",
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    n_boot >= 1 || throw(CliError("usage/invalid",
        "test multivariate svar-hypothesis: --n-boot must be ≥ 1 (got $n_boot)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "test multivariate svar-hypothesis: --max-iter must be ≥ 1 (got $max_iter)"))
    tol > 0 || throw(CliError("usage/invalid",
        "test multivariate svar-hypothesis: --tol must be > 0 (got $tol)"))
    method_sym = _to_sym(lowercase(strip(method)))
    method_sym in (:wald, :lr, :lm, :gmm_lr) || throw(CliError("usage/invalid",
        "test multivariate svar-hypothesis: --method must be wald|lr|lm|gmm-lr (got '$method')"))
    boot_sym = _to_sym(lowercase(strip(bootstrap)))
    boot_sym in (:none, :wild, :iid) || throw(CliError("usage/invalid",
        "test multivariate svar-hypothesis: --bootstrap must be none|wild|iid (got '$bootstrap')"))
    vcov_sym = isempty(strip(vcov_type)) ? nothing : _to_sym(lowercase(strip(vcov_type)))
    vcov_sym === nothing || vcov_sym in (:hessian, :sandwich, :opg) || throw(CliError("usage/invalid",
        "test multivariate svar-hypothesis: --vcov-type must be hessian|sandwich|opg (got '$vcov_type')"))

    fit = if !isnothing(model)
        model
    else
        var_model, _, varnames, _ = _load_and_estimate_var(data, lags)
        n = length(varnames)
        est = lowercase(strip(estimator))
        if est == "lms"
            dists = _w3_parse_lms_distributions(distributions, n, "test multivariate svar-hypothesis")
            try
                estimate_lms_svar(var_model; distributions=dists, _fwd_seed()...)
            catch e
                throw(_domain_or_data_error(e, "LMS SVAR"))
            end
        elseif est in ("lanne-luoto", "lanne_luoto")
            try
                estimate_lanne_luoto_gmm(var_model; _fwd_seed()...)
            catch e
                throw(_domain_or_data_error(e, "Lanne-Luoto GMM"))
            end
        else
            throw(CliError("usage/invalid",
                "test multivariate svar-hypothesis: --estimator must be lms|lanne-luoto (got '$estimator')"))
        end
    end

    n = size(fit.B0, 1)
    hyp = _w3_build_svar_hypothesis(type, config, n)

    res = if fit isa LMSSVARResult
        method_sym == :gmm_lr && throw(CliError("usage/invalid",
            "test multivariate svar-hypothesis: --method gmm-lr applies only to LanneLuotoGMMResult (use wald|lr|lm for LMS-SVAR)"))
        try
            test_svar_hypothesis(fit, hyp;
                method=method_sym, bootstrap=boot_sym, n_boot=n_boot,
                max_iter=max_iter, g_tol=tol, vcov_type=vcov_sym,
                _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "SVAR hypothesis test"))
        end
    elseif fit isa LanneLuotoGMMResult
        method_sym in (:gmm_lr, :wald) || throw(CliError("usage/invalid",
            "test multivariate svar-hypothesis: LanneLuotoGMMResult supports --method gmm-lr|wald (got '$method')"))
        boot_sym === :none || throw(CliError("usage/invalid",
            "test multivariate svar-hypothesis: --bootstrap applies only to LMSSVARResult, not LanneLuotoGMMResult"))
        try
            test_svar_hypothesis(fit, hyp;
                method=method_sym, max_iter=max_iter, tol=tol,
                _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "SVAR GMM hypothesis test"))
        end
    else
        throw(CliError("model/wrong-kind",
            "test multivariate svar-hypothesis: expected LMSSVARResult or LanneLuotoGMMResult, got $(nameof(typeof(fit)))"))
    end

    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="Structural SVAR Hypothesis Test",
                 key="svar_hypothesis_test",
                 format=Symbol(format), output=output)
    return res
end

function _test_nongaussian_diag(; data::String="", model=nothing, lags=nothing,
                                distributions::String="student-t",
                                diag_lags::Int=4,
                                output::String="", format::String="table",
                                plot::Bool=false, plot_save::String="")
    diag_lags >= 1 || throw(CliError("usage/invalid",
        "test multivariate nongaussian-diag: --diag-lags must be ≥ 1 (got $diag_lags)"))
    fit = if !isnothing(model)
        model
    else
        var_model, _, varnames, _ = _load_and_estimate_var(data, lags)
        n = length(varnames)
        dists = _w3_parse_lms_distributions(distributions, n, "test multivariate nongaussian-diag")
        try
            estimate_lms_svar(var_model; distributions=dists, _fwd_seed()...)
        catch e
            throw(_domain_or_data_error(e, "LMS SVAR"))
        end
    end
    diag = try
        diagnose_nongaussian_svar(fit; lags=diag_lags)
    catch e
        throw(_domain_or_data_error(e, "Non-Gaussian SVAR diagnostics"))
    end
    _status_report(() -> report(diag))
    _maybe_plot(diag; plot=plot, plot_save=plot_save)
    _emit_result(diag; title="Non-Gaussian SVAR Diagnostics",
                 key="nongaussian_diagnostics",
                 format=Symbol(format), output=output)
    return diag
end

function _test_gmm_moments(; data::String="", model=nothing, lags=nothing,
                           form::String="b-model",
                           weighting::String="two-step",
                           method::String="msc-rmsc",
                           kernel::String="bartlett",
                           bandwidth::String="auto",
                           alpha::Float64=0.05,
                           max_iter::Int=100,
                           tol::Float64=1e-7,
                           n_starts::Int=5,
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    (0 < alpha < 1) || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --alpha must be in (0, 1) (got $alpha)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --max-iter must be ≥ 1 (got $max_iter)"))
    tol > 0 || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --tol must be > 0 (got $tol)"))
    n_starts >= 1 || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --n-starts must be ≥ 1 (got $n_starts)"))
    form_sym = _to_sym(lowercase(strip(form)))
    form_sym in (:b_model, :a_model) || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --form must be b-model|a-model (got '$form')"))
    w_sym = _to_sym(lowercase(strip(weighting)))
    w_sym in (:two_step, :iterated, :cue) || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --weighting must be two-step|iterated|cue (got '$weighting')"))
    m_sym = _to_sym(lowercase(strip(method)))
    m_sym in (:msc_rmsc, :rmsc_seq) || throw(CliError("usage/invalid",
        "test multivariate gmm-moments: --method must be msc-rmsc|rmsc-seq (got '$method')"))
    k_sym = _w3_parse_kernel(kernel, "test multivariate gmm-moments")
    bw = _w3_parse_bandwidth(bandwidth, "test multivariate gmm-moments")

    var_model = if !isnothing(model)
        model
    else
        vm, _, _, _ = _load_and_estimate_var(data, lags)
        vm
    end

    res = try
        select_gmm_moments(var_model;
            form=form_sym, weighting=w_sym, method=m_sym,
            kernel=k_sym, bandwidth=bw, alpha=alpha,
            max_iter=max_iter, tol=tol, n_starts=n_starts,
            _fwd_seed()...)
    catch e
        throw(_domain_or_data_error(e, "GMM moment selection"))
    end
    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="Lanne-Luoto GMM Moment Selection",
                 key="gmm_moment_selection",
                 format=Symbol(format), output=output)
    return res
end

function _test_fundamentalness(; data::String="", model=nothing, lags=nothing,
                               max_lag::Int=6,
                               moments::String="skew,kurt",
                               n_boot::Int=499,
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    max_lag >= 1 || throw(CliError("usage/invalid",
        "test multivariate fundamentalness: --max-lag must be ≥ 1 (got $max_lag)"))
    n_boot >= 1 || throw(CliError("usage/invalid",
        "test multivariate fundamentalness: --n-boot must be ≥ 1 (got $n_boot)"))
    mom_syms = Symbol[]
    for tok in split(moments, ",")
        s = lowercase(strip(tok))
        isempty(s) && continue
        s in ("skew", "kurt") || throw(CliError("usage/invalid",
            "test multivariate fundamentalness: --moments tokens must be skew|kurt (got '$s')"))
        push!(mom_syms, Symbol(s))
    end
    isempty(mom_syms) && throw(CliError("usage/invalid",
        "test multivariate fundamentalness: --moments must list at least one of skew,kurt"))
    mom_syms = unique(mom_syms)

    fit = if !isnothing(model)
        model
    else
        vm, _, _, _ = _load_and_estimate_var(data, lags)
        vm
    end

    res = try
        test_fundamentalness(fit; max_lag=max_lag, moments=mom_syms,
                             n_boot=n_boot, _fwd_seed()...)
    catch e
        throw(_domain_or_data_error(e, "Fundamentalness test"))
    end
    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="Chen-Choi-Escanciano Fundamentalness Test",
                 key="fundamentalness_test",
                 format=Symbol(format), output=output)
    return res
end

function _test_sufficient_info(; data::String="", model=nothing, lags=nothing,
                               panel::String="",
                               factors::String="",
                               r_max::Int=4,
                               p_f::Int=4,
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    r_max >= 1 || throw(CliError("usage/invalid",
        "test multivariate sufficient-info: --r-max must be ≥ 1 (got $r_max)"))
    p_f >= 1 || throw(CliError("usage/invalid",
        "test multivariate sufficient-info: --p-f must be ≥ 1 (got $p_f)"))
    has_panel = !isempty(strip(panel))
    has_factors = !isempty(strip(factors))
    if has_panel && has_factors
        throw(CliError("usage/invalid",
            "test multivariate sufficient-info: specify either --panel or --factors, not both"))
    elseif !has_panel && !has_factors
        throw(CliError("usage/missing-option",
            "test multivariate sufficient-info: requires either --panel <panel.csv> or --factors <FactorModel.jld2>"))
    end

    info_source = if has_factors
        resolved_f = resolve_stem(factors; slot=:result)
        _load_typed_handle(resolved_f, [:FactorModel], "model/wrong-kind"; slot="factors")
    else
        X_panel, _ = load_multivariate_data(panel)
        X_panel
    end

    fit = if !isnothing(model)
        model
    else
        isempty(strip(data)) && throw(CliError("usage/missing-option",
            "test multivariate sufficient-info: provide <data> or --model <handle>"))
        vm, _, _, _ = _load_and_estimate_var(data, lags)
        vm
    end

    res = try
        test_sufficient_information(fit, info_source; r_max=r_max, p_f=p_f)
    catch e
        throw(_domain_or_data_error(e, "Sufficient-information test"))
    end
    _status_report(() -> report(res))
    _maybe_plot(res; plot=plot, plot_save=plot_save)
    _emit_result(res; title="Forni-Gambetti Sufficient-Information Test",
                 key="sufficient_information_test",
                 format=Symbol(format), output=output)
    return res
end

# ── Declarative CommandSpec Builders ──────────────────────────────────────

function w3_estimate_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["estimate", "lms-svar"],
            summary="Lanne-Meitz-Saikkonen (2017) complete non-Gaussian ML SVAR with 16-block Hessian SEs",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order (default: auto via AIC)"),
                OptionSpec(name="distributions", type=String, default="student-t", description="Single token or comma-separated per-shock list: student-t|skewed-t|mixture-normal|skew-normal|pearson-iv|ged"),
                OptionSpec(name="method", type=String, default="three-step", choices=["three-step", "one-step", "full-ml"], description="Estimation algorithm: three-step|one-step|full-ml"),
                OptionSpec(name="se", type=String, default="hessian", choices=["hessian", "sandwich", "opg"], description="Asymptotic SE covariance estimator: hessian|sandwich|opg"),
                OptionSpec(name="n-starts", type=Int, default=5, description="Multi-start basin count for non-Gaussian optimization"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum L-BFGS iterations per stage"),
                OptionSpec(name="tol", type=Float64, default=nothing, description="Gradient convergence tolerance (default: library precision)"),
                OptionSpec(name="shock-names", type=String, default="", description="Comma-separated structural shock labels"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:lms_svar_estimates,
                              description="LMS non-Gaussian SVAR impact matrix B0 and scale estimates with standard errors")],
            category="estimate",
            handler=wrap_legacy(_estimate_lms_svar),
        ),
        CommandSpec(
            path=["estimate", "lanne-luoto"],
            summary="Lanne-Luoto (2021) co-kurtosis GMM non-Gaussian SVAR with MSC/RMSC moment selection",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order (default: auto via AIC)"),
                OptionSpec(name="form", type=String, default="b-model", choices=["b-model", "a-model"], description="Structural parameterization: b-model|a-model"),
                OptionSpec(name="weighting", type=String, default="two-step", choices=["two-step", "iterated", "cue"], description="GMM weighting scheme: two-step|iterated|cue"),
                OptionSpec(name="moment-selection", type=String, default="msc-rmsc", choices=["msc-rmsc", "rmsc-seq", "none"], description="Co-kurtosis moment selection: msc-rmsc|rmsc-seq|none"),
                OptionSpec(name="kernel", type=String, default="bartlett", choices=["bartlett", "parzen", "qs", "quadratic-spectral", "tukey-hanning"], description="HAC kernel: bartlett|parzen|qs|quadratic-spectral|tukey-hanning"),
                OptionSpec(name="bandwidth", type=String, default="auto", description="HAC truncation lag: auto|nw94|andrews or integer ≥ 0"),
                OptionSpec(name="max-iter", type=Int, default=100, description="Maximum GMM optimization iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-7, description="Convergence tolerance"),
                OptionSpec(name="n-starts", type=Int, default=5, description="Multi-start count for initial Givens basin search"),
                OptionSpec(name="shock-names", type=String, default="", description="Comma-separated structural shock labels"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:lanne_luoto_gmm_estimates,
                              description="Lanne-Luoto co-kurtosis GMM impact matrix B0 estimates with standard errors and Hansen J-test")],
            category="estimate",
            handler=wrap_legacy(_estimate_lanne_luoto),
        ),
        CommandSpec(
            path=["estimate", "ssvarma"],
            summary="Gouriéroux-Monfort-Renne (2020) non-fundamental Strong SVARMA estimation",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="ar-lags", type=Int, default=1, description="Autoregressive order p (≥ 0)"),
                OptionSpec(name="ma-lags", type=Int, default=1, description="Moving-average order q (≥ 0)"),
                OptionSpec(name="method", type=String, default="pml", choices=["pml", "ml", "gmm", "gmm-2sls"], description="Estimator: pml|ml|gmm|gmm-2sls"),
                OptionSpec(name="distribution", type=String, default="student-t", choices=["student-t", "mixture-normal", "mixture-normal-asym", "pearson-iv", "skew-normal"], description="Marginal shock distribution for PML/ML"),
                OptionSpec(name="k-iv", type=Int, default=nothing, description="Lagged instrument count for 2SLS step (default: ar-lags + 3)"),
                OptionSpec(name="se", type=String, default="auto", choices=["auto", "hessian", "sandwich", "opg"], description="Standard error covariance: auto|hessian|sandwich|opg"),
                OptionSpec(name="n-starts", type=Int, default=3, description="Additional orthogonal rotations per Blaschke regime"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations per regime"),
                OptionSpec(name="tol", type=Float64, default=1e-6, description="Gradient convergence tolerance"),
                OptionSpec(name="shock-names", type=String, default="", description="Comma-separated structural shock labels"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="blaschke", description="Also emit Blaschke root-flip representations and fundamentalness regime summary"),
                PLOT_FLAGS...,
            ],
            tables=[
                TableSpec(name=:ssvarma_estimates,
                          description="Strong SVARMA parameter estimates (mu, Phi, Theta, C), regime and log-likelihood"),
                TableSpec(name=:ssvarma_regime,
                          description="Fundamentalness regime and GMR region summary (emitted with --blaschke)"),
                TableSpec(name=:ssvarma_blaschke,
                          description="Blaschke root-flipped equivalent representations (emitted with --blaschke)"),
            ],
            category="estimate",
            handler=wrap_legacy(_estimate_ssvarma),
        ),
    ]
end

function w3_residuals_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["residuals", "lms-svar"],
            summary="Standardized structural shocks from an LMS non-Gaussian SVAR",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order (default: auto via AIC)"),
                OptionSpec(name="distributions", type=String, default="student-t", description="Single token or comma-separated per-shock list"),
                OptionSpec(name="method", type=String, default="three-step", choices=["three-step", "one-step", "full-ml"], description="three-step|one-step|full-ml"),
                OptionSpec(name="se", type=String, default="hessian", choices=["hessian", "sandwich", "opg"], description="hessian|sandwich|opg"),
                OptionSpec(name="n-starts", type=Int, default=5, description="Multi-start count"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="tol", type=Float64, default=nothing, description="Gradient convergence tolerance"),
                OptionSpec(name="shock-names", type=String, default="", description="Comma-separated structural shock labels"),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:lms_svar_residuals,
                              description="Standardized LMS structural shocks: t | one column per shock")],
            category="residuals",
            handler=_residuals_lms_svar,
        ),
        CommandSpec(
            path=["residuals", "lanne-luoto"],
            summary="Structural shocks from a Lanne-Luoto co-kurtosis GMM SVAR",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order (default: auto via AIC)"),
                OptionSpec(name="form", type=String, default="b-model", choices=["b-model", "a-model"], description="b-model|a-model"),
                OptionSpec(name="weighting", type=String, default="two-step", choices=["two-step", "iterated", "cue"], description="two-step|iterated|cue"),
                OptionSpec(name="moment-selection", type=String, default="msc-rmsc", choices=["msc-rmsc", "rmsc-seq", "none"], description="msc-rmsc|rmsc-seq|none"),
                OptionSpec(name="kernel", type=String, default="bartlett", choices=["bartlett", "parzen", "qs", "quadratic-spectral", "tukey-hanning"], description="HAC kernel"),
                OptionSpec(name="bandwidth", type=String, default="auto", description="HAC truncation lag"),
                OptionSpec(name="max-iter", type=Int, default=100, description="Maximum iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-7, description="Convergence tolerance"),
                OptionSpec(name="n-starts", type=Int, default=5, description="Multi-start count"),
                OptionSpec(name="shock-names", type=String, default="", description="Comma-separated structural shock labels"),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:lanne_luoto_residuals,
                              description="Lanne-Luoto GMM structural shocks: t | one column per shock")],
            category="residuals",
            handler=_residuals_lanne_luoto,
        ),
        CommandSpec(
            path=["residuals", "ssvarma"],
            summary="Schur-filtered structural shocks from a Strong SVARMA model",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="ar-lags", type=Int, default=1, description="Autoregressive order p (≥ 0)"),
                OptionSpec(name="ma-lags", type=Int, default=1, description="Moving-average order q (≥ 0)"),
                OptionSpec(name="method", type=String, default="pml", choices=["pml", "ml", "gmm", "gmm-2sls"], description="pml|ml|gmm|gmm-2sls"),
                OptionSpec(name="distribution", type=String, default="student-t", choices=["student-t", "mixture-normal", "mixture-normal-asym", "pearson-iv", "skew-normal"], description="Marginal shock distribution"),
                OptionSpec(name="k-iv", type=Int, default=nothing, description="Lagged instrument count"),
                OptionSpec(name="se", type=String, default="auto", choices=["auto", "hessian", "sandwich", "opg"], description="Standard error covariance"),
                OptionSpec(name="n-starts", type=Int, default=3, description="Multi-start rotations per regime"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-6, description="Convergence tolerance"),
                OptionSpec(name="shock-names", type=String, default="", description="Comma-separated structural shock labels"),
                OUTPUT_OPTIONS...,
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:ssvarma_residuals,
                              description="Strong SVARMA Schur-filtered structural shocks: t | one column per shock")],
            category="residuals",
            handler=_residuals_ssvarma,
        ),
    ]
end

function w3_irf_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["irf", "ssvarma"],
            summary="Compute causal structural impulse response functions for a Strong SVARMA model",
            args=[ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="ar-lags", type=Int, default=1, description="Autoregressive order p (≥ 0)"),
                OptionSpec(name="ma-lags", type=Int, default=1, description="Moving-average order q (≥ 0)"),
                OptionSpec(name="method", type=String, default="pml", choices=["pml", "ml", "gmm", "gmm-2sls"], description="pml|ml|gmm|gmm-2sls"),
                OptionSpec(name="distribution", type=String, default="student-t", choices=["student-t", "mixture-normal", "mixture-normal-asym", "pearson-iv", "skew-normal"], description="Marginal shock distribution"),
                OptionSpec(name="k-iv", type=Int, default=nothing, description="Lagged instrument count"),
                OptionSpec(name="se", type=String, default="auto", choices=["auto", "hessian", "sandwich", "opg"], description="Standard error covariance"),
                OptionSpec(name="n-starts", type=Int, default=3, description="Multi-start rotations per regime"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-6, description="Convergence tolerance"),
                OptionSpec(name="shock", type=Int, default=1, description="Shock variable index (1-based)"),
                OptionSpec(name="horizons", type=Int, default=20, description="IRF horizon"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[
                FlagSpec(name="cumulative", description="Compute cumulative IRFs"),
                PLOT_FLAGS...,
            ],
            tables=[TableSpec(name=:ssvarma_irf,
                              description="Causal structural SVARMA responses to the selected shock: horizon | variable | shock | value | lower | upper")],
            category="irf",
            handler=wrap_legacy(_irf_ssvarma),
        ),
    ]
end

function w3_fevd_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["fevd", "ssvarma"],
            summary="Compute structural forecast error variance decomposition for a Strong SVARMA model",
            args=[ArgSpec(name="data", description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="ar-lags", type=Int, default=1, description="Autoregressive order p (≥ 0)"),
                OptionSpec(name="ma-lags", type=Int, default=1, description="Moving-average order q (≥ 0)"),
                OptionSpec(name="method", type=String, default="pml", choices=["pml", "ml", "gmm", "gmm-2sls"], description="pml|ml|gmm|gmm-2sls"),
                OptionSpec(name="distribution", type=String, default="student-t", choices=["student-t", "mixture-normal", "mixture-normal-asym", "pearson-iv", "skew-normal"], description="Marginal shock distribution"),
                OptionSpec(name="k-iv", type=Int, default=nothing, description="Lagged instrument count"),
                OptionSpec(name="se", type=String, default="auto", choices=["auto", "hessian", "sandwich", "opg"], description="Standard error covariance"),
                OptionSpec(name="n-starts", type=Int, default=3, description="Multi-start rotations per regime"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-6, description="Convergence tolerance"),
                OptionSpec(name="horizons", type=Int, default=20, description="FEVD horizon"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:ssvarma_fevd,
                              description="Structural SVARMA forecast error variance shares, tidy long form: horizon | variable | shock | value")],
            category="fevd",
            handler=wrap_legacy(_fevd_ssvarma),
        ),
    ]
end

function w3_test_specs()::Vector{CommandSpec}
    return CommandSpec[
        CommandSpec(
            path=["test", "svar-hypothesis"],
            summary="Structural SVAR hypothesis tests (recursiveness, impact, long-run, horizon-IRF, mixed)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order (default: auto via AIC)"),
                OptionSpec(name="estimator", type=String, default="lms", choices=["lms", "lanne-luoto"], description="Inline SVAR estimator when --model is omitted: lms|lanne-luoto"),
                OptionSpec(name="distributions", type=String, default="student-t", description="Shock distribution(s) for inline LMS estimation"),
                OptionSpec(name="type", type=String, default="", choices=["recursiveness", "impact-zero", "impact-linear", "long-run", "horizon-irf", "mixed"], description="Hypothesis type (default: recursiveness or [svar_hypothesis].type from --config)"),
                OptionSpec(name="config", type=String, default="", description="TOML config containing [svar_hypothesis] restriction specification"),
                OptionSpec(name="method", type=String, default="wald", choices=["wald", "lr", "lm", "gmm-lr"], description="Test statistic: wald|lr|lm (LMS-SVAR) or gmm-lr|wald (Lanne-Luoto GMM)"),
                OptionSpec(name="bootstrap", type=String, default="none", choices=["none", "wild", "iid"], description="Residual bootstrap scheme under H0 (LMS-SVAR only): none|wild|iid"),
                OptionSpec(name="n-boot", type=Int, default=499, description="Bootstrap replications (with --bootstrap wild|iid)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum constrained optimizer iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-7, description="Gradient / optimizer convergence tolerance"),
                OptionSpec(name="vcov-type", type=String, default="", choices=["hessian", "sandwich", "opg"], description="Optional covariance override for LMS-SVAR: hessian|sandwich|opg"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:svar_hypothesis_test,
                              description="Structural SVAR hypothesis test statistic, asymptotic/bootstrap p-value, df and convergence")],
            category="test",
            handler=_test_svar_hypothesis,
        ),
        CommandSpec(
            path=["test", "nongaussian-diag"],
            summary="LMS (2017) non-Gaussian SVAR residual specification & identification diagnostics",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order for inline LMS fit (default: auto via AIC)"),
                OptionSpec(name="distributions", type=String, default="student-t", description="Shock distribution(s) for inline LMS fit"),
                OptionSpec(name="diag-lags", type=Int, default=4, description="Lag order for Ljung-Box and multivariate Portmanteau diagnostics"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:nongaussian_diagnostics,
                              description="Per-shock LMS Jarque-Bera, skewness, kurtosis, Ljung-Box and BDS diagnostic battery")],
            category="test",
            handler=_test_nongaussian_diag,
        ),
        CommandSpec(
            path=["test", "gmm-moments"],
            summary="Lanne-Luoto (2021) co-kurtosis GMM moment selection (Andrews MSC + Hall RMSC)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order (default: auto via AIC)"),
                OptionSpec(name="form", type=String, default="b-model", choices=["b-model", "a-model"], description="Structural form: b-model|a-model"),
                OptionSpec(name="weighting", type=String, default="two-step", choices=["two-step", "iterated", "cue"], description="GMM weighting: two-step|iterated|cue"),
                OptionSpec(name="method", type=String, default="msc-rmsc", choices=["msc-rmsc", "rmsc-seq"], description="Selection algorithm: msc-rmsc|rmsc-seq"),
                OptionSpec(name="kernel", type=String, default="bartlett", choices=["bartlett", "parzen", "qs", "quadratic-spectral", "tukey-hanning"], description="HAC kernel"),
                OptionSpec(name="bandwidth", type=String, default="auto", description="HAC truncation lag: auto|nw94|andrews or integer ≥ 0"),
                OptionSpec(name="alpha", type=Float64, default=0.05, description="Hansen J significance level for RMSC screening (0 < alpha < 1)"),
                OptionSpec(name="max-iter", type=Int, default=100, description="Maximum optimization iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-7, description="Convergence tolerance"),
                OptionSpec(name="n-starts", type=Int, default=5, description="Multi-start count"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:gmm_moment_selection,
                              description="Candidate co-kurtosis moment sets with MSC/RMSC scores, Hansen J statistics and rank flags")],
            category="test",
            handler=_test_gmm_moments,
        ),
        CommandSpec(
            path=["test", "fundamentalness"],
            summary="Chen-Choi-Escanciano (2017) non-Gaussian fundamentalness test",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order when --model is omitted (default: auto via AIC)"),
                OptionSpec(name="max-lag", type=Int, default=6, description="Maximum past lag k tested"),
                OptionSpec(name="moments", type=String, default="skew,kurt", description="Comma-separated moment transforms: subset of skew,kurt"),
                OptionSpec(name="n-boot", type=Int, default=499, description="Bootstrap replications"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:fundamentalness_test,
                              description="Per-lag and overall Chen-Choi-Escanciano fundamentalness test statistics and bootstrap p-values")],
            category="test",
            handler=_test_fundamentalness,
        ),
        CommandSpec(
            path=["test", "sufficient-info"],
            summary="Forni-Gambetti (2014) informational sufficiency test against panel factors",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to VAR data file or handle stem (.csv, .jld2, .jls)")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="VAR lag order when --model is omitted (default: auto via AIC)"),
                OptionSpec(name="panel", type=String, default="", description="Large informational panel CSV/handle (mutually exclusive with --factors)"),
                OptionSpec(name="factors", type=String, default="", description="Saved FactorModel handle (mutually exclusive with --panel)"),
                OptionSpec(name="r-max", type=Int, default=4, description="Maximum number of principal components r tested"),
                OptionSpec(name="p-f", type=Int, default=4, description="Number of lagged factor blocks included in orthogonality regression"),
                OUTPUT_OPTIONS...,
                PLOT_OPTIONS...,
            ],
            flags=[PLOT_FLAGS...],
            tables=[TableSpec(name=:sufficient_information_test,
                              description="Forni-Gambetti F and Wald orthogonality test statistics and p-values across factor counts r")],
            category="test",
            handler=_test_sufficient_info,
            allow_data_with_model=true,
        ),
    ]
end
