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

# IRF commands: var, bvar, lp, vecm, pvar, favar, sdfm (action-first: friedman irf var ...)

function irf_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["irf", "var"],
            summary="Compute frequentist impulse response functions",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto)"),
                OptionSpec(name="shock", type=Int, default=1, description="Shock variable index (1-based)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="IRF horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun|arias|uhlig|fastica|jade|sobi|dcov|hsic|student_t|mixture_normal|pml|skew_normal|markov_switching|garch_id"),
                OptionSpec(name="ci", type=String, default="bootstrap", description="none|bootstrap|theoretical"),
                OptionSpec(name="replications", type=Int, default=1000, description="Bootstrap replications"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser"),
                FlagSpec(name="cumulative", description="Compute cumulative IRFs (for differenced data)"),
                FlagSpec(name="identified-set", description="Return full identified set for sign restrictions"),
                FlagSpec(name="stationary-only", description="Filter non-stationary bootstrap draws")
            ],
            tables=[TableSpec(name=:irf_var, description="Compute frequentist impulse response functions")],
            category="irf",
            handler=wrap_legacy(_irf_var),
        ),
        CommandSpec(
            path=["irf", "bvar"],
            summary="Compute Bayesian impulse response functions with credible intervals",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Lag order"),
                OptionSpec(name="shock", type=Int, default=1, description="Shock variable index (1-based)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="IRF horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun"),
                OptionSpec(name="draws", short="n", type=Int, default=2000, description="MCMC draws"),
                OptionSpec(name="sampler", type=String, default="direct", description="direct|gibbs"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification/prior"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser"),
                FlagSpec(name="cumulative", description="Compute cumulative IRFs (for differenced data)")
            ],
            tables=[TableSpec(name=:irf_bvar, description="Compute Bayesian impulse response functions with credible intervals")],
            category="irf",
            handler=wrap_legacy(_irf_bvar),
        ),
        CommandSpec(
            path=["irf", "lp"],
            summary="Compute structural LP impulse response functions",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="shock", type=Int, default=1, description="Single shock index (1-based)"),
                OptionSpec(name="shocks", type=String, default="", description="Comma-separated shock indices (e.g. 1,2,3)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="IRF horizon"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="LP control lags"),
                OptionSpec(name="var-lags", type=Int, default=nothing, description="VAR lag order for identification (default: same as --lags)"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun"),
                OptionSpec(name="ci", type=String, default="none", description="none|bootstrap"),
                OptionSpec(name="replications", type=Int, default=200, description="Bootstrap replications"),
                OptionSpec(name="conf-level", type=Float64, default=0.95, description="Confidence level"),
                OptionSpec(name="vcov", type=String, default="newey_west", description="newey_west|white|driscoll_kraay"),
                OptionSpec(name="config", type=String, default="", description="TOML config for sign/narrative restrictions"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser"),
                FlagSpec(name="cumulative", description="Compute cumulative IRFs (for differenced data)")
            ],
            tables=[TableSpec(name=:irf_lp, description="Compute structural LP impulse response functions")],
            category="irf",
            handler=wrap_legacy(_irf_lp),
        ),
        CommandSpec(
            path=["irf", "vecm"],
            summary="Compute impulse response functions via VECM → VAR representation",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="shock", type=Int, default=1, description="Shock variable index (1-based)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="IRF horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun"),
                OptionSpec(name="ci", type=String, default="bootstrap", description="none|bootstrap|theoretical"),
                OptionSpec(name="replications", type=Int, default=1000, description="Bootstrap replications"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:irf_vecm, description="Compute impulse response functions via VECM → VAR representation")],
            category="irf",
            handler=wrap_legacy(_irf_vecm),
        ),
        CommandSpec(
            path=["irf", "pvar"],
            summary="Compute Panel VAR impulse response functions (OIRF/GIRF)",
            args=[ArgSpec(name="data", description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="Lag order"),
                OptionSpec(name="horizons", short="h", type=Int, default=10, description="IRF horizon"),
                OptionSpec(name="irf-type", type=String, default="oirf", description="oirf|girf"),
                OptionSpec(name="boot-draws", type=Int, default=500, description="Bootstrap draws for CIs"),
                OptionSpec(name="confidence", type=Float64, default=0.95, description="Confidence level"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:irf_pvar, description="Compute Panel VAR impulse response functions (OIRF/GIRF)")],
            category="irf",
            handler=wrap_legacy(_irf_pvar),
        ),
        CommandSpec(
            path=["irf", "favar"],
            summary="FAVAR impulse response functions",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="VAR lag order"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variable names or indices (comma-separated)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="IRF horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="Identification method"),
                OptionSpec(name="config", type=String, default="", description="TOML config for restrictions"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="panel-irf", description="Output panel-wide IRFs (N variables) instead of factor-level"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:irf_favar, description="FAVAR impulse response functions")],
            category="irf",
            handler=wrap_legacy(_irf_favar),
        ),
        CommandSpec(
            path=["irf", "sdfm"],
            summary="Structural DFM impulse response functions (panel-wide)",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="q", type=Int, default=nothing, description="Number of dynamic factors"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign"),
                OptionSpec(name="var-lags", type=Int, default=1, description="Factor VAR lag order"),
                OptionSpec(name="horizons", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="config", type=String, default="", description="TOML config for sign restrictions"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:irf_sdfm, description="Structural DFM impulse response functions (panel-wide)")],
            category="irf",
            handler=wrap_legacy(_irf_sdfm),
        )
    ]
end

function register_irf_commands!()
    specs = irf_specs()
    register!(specs)
    return build_node("irf", specs; description="Impulse Response Functions")
end


# ── VAR IRF ──────────────────────────────────────────────

function _irf_var(; data::String="", lags=nothing, shock::Int=1, horizons::Int=20,
                   id::String="cholesky", ci::String="bootstrap", replications::Int=1000,
                   config::String="",
                   output::String="", format::String="table",
                   plot::Bool=false, plot_save::String="",
                   cumulative::Bool=false, identified_set::Bool=false,
                   stationary_only::Bool=false,
                   model=nothing)
    if isnothing(model)
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
    else
        varnames = model.varnames
        p = model.p
    end
    n = length(varnames)

    _status("Computing IRFs: VAR($p), shock=$shock, horizons=$horizons, id=$id, ci=$ci")
    _status()

    # Arias identification handled separately
    if id == "arias"
        _var_irf_arias(model, config, horizons, varnames, shock; format=format, output=output)
        return
    end

    # Uhlig identification handled separately
    if id == "uhlig"
        _var_irf_uhlig(model, config, horizons, varnames, shock; format=format, output=output)
        return
    end

    # Sign-identified set: return full draw set instead of point estimates
    if identified_set && id == "sign"
        check_func, _ = _build_check_func(config)
        isnothing(check_func) && error("--identified-set requires a --config file with sign restrictions")
        set = identify_sign(model, horizons, check_func; max_draws=replications, store_all=true)
        lower, upper = irf_bounds(set)
        med = irf_median(set)
        _status("Sign-Identified Set: $(set.n_accepted)/$(set.n_total) accepted ($(round(set.acceptance_rate*100; digits=1))%)")
        irf_df = DataFrame()
        irf_df.horizon = 0:horizons
        for (vi, vname) in enumerate(varnames)
            irf_df[!, vname] = med[:, vi, shock]
            irf_df[!, "$(vname)_lower"] = lower[:, vi, shock]
            irf_df[!, "$(vname)_upper"] = upper[:, vi, shock]
        end
        shock_name = _shock_name(varnames, shock)
        output_result(irf_df; format=Symbol(format), output=output,
                      title="IRF Identified Set (sign, $shock_name shock)")
        return
    end

    kwargs = _build_identification_kwargs(id, config)
    kwargs[:ci_type] = Symbol(ci)
    kwargs[:reps] = replications
    if stationary_only
        kwargs[:stationary_only] = true
    end

    irf_result = irf(model, horizons; kwargs...)

    if cumulative
        irf_result = cumulative_irf(irf_result)
        _status_styled("  Cumulative IRFs computed\n"; color=:cyan)
    end

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    _status_report(() -> report(irf_result))

    irf_vals = irf_result.values  # H x n x n
    n_h = size(irf_vals, 1)

    irf_df = DataFrame()
    irf_df.horizon = 0:(n_h-1)
    for (vi, vname) in enumerate(varnames)
        irf_df[!, vname] = irf_vals[:, vi, shock]
    end

    if ci != "none" && !isnothing(irf_result.ci_lower)
        for (vi, vname) in enumerate(varnames)
            irf_df[!, "$(vname)_lower"] = irf_result.ci_lower[:, vi, shock]
            irf_df[!, "$(vname)_upper"] = irf_result.ci_upper[:, vi, shock]
        end
    end

    shock_name = _shock_name(varnames, shock)
    output_result(irf_df; format=Symbol(format), output=output,
                  title="IRF to $shock_name shock ($id identification)")
end

function _var_irf_arias(model, config::String, horizons::Int,
                        varnames::Vector{String}, shock::Int; format::String="table", output::String="")
    isempty(config) && error("Arias identification requires a --config file with restrictions")
    cfg = load_config(config)
    id_cfg = get(cfg, "identification", Dict())

    zeros_list = get(id_cfg, "zero_restrictions", [])
    signs_list = get(id_cfg, "sign_restrictions", [])

    n = nvars(model)
    zero_restrs = [zero_restriction(r["var"], r["shock"]; horizon=r["horizon"]) for r in zeros_list]
    sign_restrs = [sign_restriction(r["var"], r["shock"], Symbol(r["sign"]); horizon=r["horizon"]) for r in signs_list]

    restrictions = SVARRestrictions(n; zeros=zero_restrs, signs=sign_restrs)
    result = identify_arias(model, restrictions, horizons)

    irf_vals = irf_mean(result)  # H x n x n
    n_h = size(irf_vals, 1)

    irf_df = DataFrame()
    irf_df.horizon = 0:(n_h-1)
    for (vi, vname) in enumerate(varnames)
        irf_df[!, vname] = irf_vals[:, vi, shock]
    end

    shock_name = _shock_name(varnames, shock)
    output_result(irf_df; format=Symbol(format), output=output,
                  title="IRF to $shock_name shock (Arias et al. identification)")
end

function _var_irf_uhlig(model, config::String, horizons::Int,
                        varnames::Vector{String}, shock::Int; format::String="table", output::String="")
    isempty(config) && error("Uhlig identification requires a --config file with restrictions")
    cfg = load_config(config)
    id_cfg = get(cfg, "identification", Dict())

    zeros_list = get(id_cfg, "zero_restrictions", [])
    signs_list = get(id_cfg, "sign_restrictions", [])

    n = nvars(model)
    zero_restrs = [zero_restriction(r["var"], r["shock"]; horizon=r["horizon"]) for r in zeros_list]
    sign_restrs = [sign_restriction(r["var"], r["shock"], Symbol(r["sign"]); horizon=r["horizon"]) for r in signs_list]

    restrictions = SVARRestrictions(n; zeros=zero_restrs, signs=sign_restrs)

    uhlig_params = get_uhlig_params(cfg)
    result = identify_uhlig(model, restrictions, horizons;
        n_starts=uhlig_params["n_starts"], n_refine=uhlig_params["n_refine"],
        max_iter_coarse=uhlig_params["max_iter_coarse"], max_iter_fine=uhlig_params["max_iter_fine"],
        tol_coarse=uhlig_params["tol_coarse"], tol_fine=uhlig_params["tol_fine"])

    # Convergence info
    _status("Uhlig identification: penalty=$(round(result.penalty; digits=6)), converged=$(result.converged)")
    for (si, sp) in enumerate(result.shock_penalties)
        _status("  Shock $si penalty: $(round(sp; digits=6))")
    end
    _status()

    irf_vals = result.irf  # H x n x n
    n_h = size(irf_vals, 1)

    irf_df = DataFrame()
    irf_df.horizon = 0:(n_h-1)
    for (vi, vname) in enumerate(varnames)
        irf_df[!, vname] = irf_vals[:, vi, shock]
    end

    shock_name = _shock_name(varnames, shock)
    output_result(irf_df; format=Symbol(format), output=output,
                  title="IRF to $shock_name shock (Uhlig identification)")
end

# ── BVAR IRF ─────────────────────────────────────────────

function _irf_bvar(; data::String="", lags::Int=4, shock::Int=1, horizons::Int=20,
                    id::String="cholesky", draws::Int=2000, sampler::String="direct",
                    config::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="",
                    cumulative::Bool=false,
                    model=nothing)
    if isnothing(model)
        post, Y, varnames, p, n = _load_and_estimate_bvar(data, lags, config, draws, sampler)
    else
        post = model
        varnames = post.varnames
        p = post.p
        n = length(varnames)
    end
    method = get(ID_METHOD_MAP, id, :cholesky)

    _status("Computing Bayesian IRFs: BVAR($p), shock=$shock, horizons=$horizons, id=$id")
    _status("  Sampler: $sampler, Draws: $draws")
    _status()

    check_func, narrative_check = _build_check_func(config)

    kwargs = Dict{Symbol,Any}(
        :method => method,
        :quantiles => [0.16, 0.5, 0.84],
    )
    if !isnothing(check_func)
        kwargs[:check_func] = check_func
    end
    if !isnothing(narrative_check)
        kwargs[:narrative_check] = narrative_check
    end

    birf = irf(post, horizons; kwargs...)

    if cumulative
        birf = cumulative_irf(birf)
        _status_styled("  Cumulative IRFs computed\n"; color=:cyan)
    end

    _maybe_plot(birf; plot=plot, plot_save=plot_save)

    _status_report(() -> report(birf))

    irf_mean_vals = birf.mean
    n_h = size(irf_mean_vals, 1)
    q_levels = birf.quantile_levels
    q_idx_lo = findfirst(==(0.16), q_levels)
    q_idx_med = findfirst(==(0.5), q_levels)
    q_idx_hi = findfirst(==(0.84), q_levels)

    irf_df = DataFrame()
    irf_df.horizon = 0:(n_h-1)

    for (vi, vname) in enumerate(varnames)
        if !isnothing(q_idx_med)
            irf_df[!, vname] = birf.quantiles[:, vi, shock, q_idx_med]
        else
            irf_df[!, vname] = irf_mean_vals[:, vi, shock]
        end
        if !isnothing(q_idx_lo)
            irf_df[!, "$(vname)_16pct"] = birf.quantiles[:, vi, shock, q_idx_lo]
        end
        if !isnothing(q_idx_hi)
            irf_df[!, "$(vname)_84pct"] = birf.quantiles[:, vi, shock, q_idx_hi]
        end
    end

    shock_name = _shock_name(varnames, shock)
    output_result(irf_df; format=Symbol(format), output=output,
                  title="Bayesian IRF to $shock_name shock ($id, 68% credible interval)")
end

# ── LP IRF ───────────────────────────────────────────────

function _irf_lp(; data::String="", shock::Int=1, shocks::String="",
                  horizons::Int=20, lags::Int=4, var_lags=nothing,
                  id::String="cholesky", ci::String="none",
                  replications::Int=200, conf_level::Float64=0.95,
                  vcov::String="newey_west", config::String="",
                  output::String="", format::String="table",
                  plot::Bool=false, plot_save::String="",
                  cumulative::Bool=false,
                  model=nothing)
    # Multi-shock mode
    if !isempty(shocks)
        shock_indices = parse.(Int, split(shocks, ","))
    else
        shock_indices = [shock]
    end

    if isnothing(model)
        slp, Y, varnames = _load_and_structural_lp(data, horizons, lags, var_lags,
            id, vcov, config; ci_type=Symbol(ci), reps=replications, conf_level=conf_level)
        n = size(Y, 2)
    else
        slp = model
        varnames = slp.varnames
        n = length(varnames)
    end
    irf_result = slp.irf

    if cumulative
        irf_result = cumulative_irf(irf_result)
        _status_styled("  Cumulative IRFs computed\n"; color=:cyan)
    end

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    _status("Computing LP IRFs: horizons=$horizons, id=$id, ci=$ci")
    _status()

    for shock_idx in shock_indices
        (shock_idx < 1 || shock_idx > n) && error("shock index $shock_idx out of range (data has $n variables)")
        shock_name = _shock_name(varnames, shock_idx)

        irf_vals = irf_result.values  # H x n x n
        n_h = size(irf_vals, 1)

        irf_df = DataFrame()
        irf_df.horizon = 0:(n_h-1)
        for (vi, vname) in enumerate(varnames)
            irf_df[!, vname] = irf_vals[:, vi, shock_idx]
        end

        if ci != "none" && !isnothing(irf_result.ci_lower)
            for (vi, vname) in enumerate(varnames)
                irf_df[!, "$(vname)_lower"] = irf_result.ci_lower[:, vi, shock_idx]
                irf_df[!, "$(vname)_upper"] = irf_result.ci_upper[:, vi, shock_idx]
            end
        end

        output_result(irf_df; format=Symbol(format),
                      output=isempty(output) ? "" : (length(shock_indices) > 1 ? replace(output, "." => "_$(shock_name).") : output),
                      title="LP IRF to $shock_name shock ($id identification)")
        _status()
    end
end

# ── VECM IRF ────────────────────────────────────────────

function _irf_vecm(; data::String="", lags::Int=2, rank::String="auto",
                    deterministic::String="constant",
                    shock::Int=1, horizons::Int=20,
                    id::String="cholesky", ci::String="bootstrap", replications::Int=1000,
                    config::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="",
                    model=nothing)
    if isnothing(model)
        vecm, Y, varnames, p = _load_and_estimate_vecm(data, lags, rank, deterministic, "johansen", 0.05)
        var_model = to_var(vecm)
    else
        vecm = model
        var_model = to_var(vecm)
        varnames = vecm.varnames
        p = vecm.p
    end
    n = length(varnames)
    r = cointegrating_rank(vecm)

    _status("Computing VECM IRFs: rank=$r, VAR($p), shock=$shock, horizons=$horizons, id=$id, ci=$ci")
    _status()

    kwargs = _build_identification_kwargs(id, config)
    kwargs[:ci_type] = Symbol(ci)
    kwargs[:reps] = replications

    irf_result = irf(var_model, horizons; kwargs...)

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    _status_report(() -> report(irf_result))

    irf_vals = irf_result.values
    n_h = size(irf_vals, 1)

    irf_df = DataFrame()
    irf_df.horizon = 0:(n_h-1)
    for (vi, vname) in enumerate(varnames)
        irf_df[!, vname] = irf_vals[:, vi, shock]
    end

    if ci != "none" && !isnothing(irf_result.ci_lower)
        for (vi, vname) in enumerate(varnames)
            irf_df[!, "$(vname)_lower"] = irf_result.ci_lower[:, vi, shock]
            irf_df[!, "$(vname)_upper"] = irf_result.ci_upper[:, vi, shock]
        end
    end

    shock_name = _shock_name(varnames, shock)
    output_result(irf_df; format=Symbol(format), output=output,
                  title="VECM IRF to $shock_name shock ($id identification)")
end

# ── Panel VAR IRF ──────────────────────────────────────────

function _irf_pvar(; data::String="", id_col::String="", time_col::String="",
                    lags::Int=1, horizons::Int=10,
                    irf_type::String="oirf", boot_draws::Int=500,
                    confidence::Float64=0.95,
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="",
                    model=nothing)
    validate_method(irf_type, ["oirf", "girf"], "IRF type")

    if isnothing(model)
        isempty(id_col) && error("Panel VAR IRF requires --id-col")
        isempty(time_col) && error("Panel VAR IRF requires --time-col")
        model, panel, varnames = _load_and_estimate_pvar(data, id_col, time_col, lags)
    else
        varnames = model.varnames
    end
    n = length(varnames)

    _status("Computing Panel VAR IRFs: type=$irf_type, horizons=$horizons, bootstrap=$boot_draws")
    _status()

    # Compute IRFs with bootstrap CIs
    irf_result = pvar_bootstrap_irf(model, horizons;
        n_boot=boot_draws, conf_level=confidence, irf_type=Symbol(irf_type))

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    # Output per-shock IRF tables
    for shock in 1:n
        shock_name = _shock_name(varnames, shock)
        irf_vals = irf_result.values
        n_h = size(irf_vals, 1)

        irf_df = DataFrame()
        irf_df.horizon = 0:(n_h-1)
        for (vi, vname) in enumerate(varnames)
            irf_df[!, vname] = irf_vals[:, vi, shock]
        end
        if !isnothing(irf_result.ci_lower)
            for (vi, vname) in enumerate(varnames)
                irf_df[!, "$(vname)_lower"] = irf_result.ci_lower[:, vi, shock]
                irf_df[!, "$(vname)_upper"] = irf_result.ci_upper[:, vi, shock]
            end
        end

        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock_name),
                      title="Panel VAR $(uppercase(irf_type)) to $shock_name shock")
        _status()
    end
end

# ── FAVAR IRF ──────────────────────────────────────────

function _irf_favar(; data::String="", factors=nothing, lags::Int=2,
                     key_vars::String="", horizons::Int=20,
                     id::String="cholesky", config::String="",
                     panel_irf::Bool=false,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="",
                     model=nothing)
    if isnothing(model)
        favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, "two_step", 5000)
    else
        favar = model
        varnames = favar.varnames
    end
    n = size(favar.Y, 2)

    id_kwargs = _build_identification_kwargs(id, config)

    _status("FAVAR IRF: horizon=$horizons, id=$id" * (panel_irf ? ", panel-wide" : ""))
    _status()

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

function _irf_sdfm(; data::String="", factors=nothing, id::String="cholesky",
                    var_lags::Int=1, horizons::Int=40,
                    config::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="",
                    model=nothing)
    if isnothing(model)
        Y, varnames = load_multivariate_data(data)
        q = factors === nothing ? ic_criteria_gdfm(Y, min(10, size(Y, 2) - 1)).q_opt : factors
        sdfm = estimate_structural_dfm(Y, q; identification=Symbol(id), p=var_lags, H=horizons)
    else
        sdfm = model
    end

    _status("Structural DFM IRF: $q factors, id=$id, horizon=$horizons")
    _status()

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
