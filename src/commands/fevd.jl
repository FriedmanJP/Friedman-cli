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

# FEVD commands: var, bvar, lp, vecm, pvar, favar, sdfm (action-first: friedman fevd var ...)

function fevd_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["fevd", "var"],
            summary="Compute forecast error variance decomposition",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="Forecast horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun|arias|uhlig"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_var, description="Compute forecast error variance decomposition")],
            category="fevd",
            handler=wrap_legacy(_fevd_var),
        ),
        CommandSpec(
            path=["fevd", "bvar"],
            summary="Compute Bayesian forecast error variance decomposition",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Lag order"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="Forecast horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun"),
                OptionSpec(name="draws", short="n", type=Int, default=2000, description="MCMC draws"),
                OptionSpec(name="sampler", type=String, default="direct", description="direct|gibbs"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification/prior"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_bvar, description="Compute Bayesian forecast error variance decomposition")],
            category="fevd",
            handler=wrap_legacy(_fevd_bvar),
        ),
        CommandSpec(
            path=["fevd", "lp"],
            summary="Compute forecast error variance decomposition via structural LP",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="Forecast horizon"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="LP control lags"),
                OptionSpec(name="var-lags", type=Int, default=nothing, description="VAR lag order for identification"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun"),
                OptionSpec(name="vcov", type=String, default="newey_west", description="newey_west|white|driscoll_kraay"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_lp, description="Compute forecast error variance decomposition via structural LP")],
            category="fevd",
            handler=wrap_legacy(_fevd_lp),
        ),
        CommandSpec(
            path=["fevd", "vecm"],
            summary="Compute FEVD via VECM → VAR representation",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="Forecast horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign|narrative|longrun"),
                OptionSpec(name="config", type=String, default="", description="TOML config for identification"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_vecm, description="Compute FEVD via VECM → VAR representation")],
            category="fevd",
            handler=wrap_legacy(_fevd_vecm),
        ),
        CommandSpec(
            path=["fevd", "pvar"],
            summary="Compute Panel VAR forecast error variance decomposition",
            args=[ArgSpec(name="data", description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="Lag order"),
                OptionSpec(name="horizons", short="h", type=Int, default=10, description="Forecast horizon"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_pvar, description="Compute Panel VAR forecast error variance decomposition")],
            category="fevd",
            handler=wrap_legacy(_fevd_pvar),
        ),
        CommandSpec(
            path=["fevd", "favar"],
            summary="FAVAR forecast error variance decomposition",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="r", type=Int, default=nothing, description="Number of factors"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="VAR lag order"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variable names or indices"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="FEVD horizon"),
                OptionSpec(name="id", type=String, default="cholesky", description="Identification method"),
                OptionSpec(name="config", type=String, default="", description="TOML config for restrictions"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_favar, description="FAVAR forecast error variance decomposition")],
            category="fevd",
            handler=wrap_legacy(_fevd_favar),
        ),
        CommandSpec(
            path=["fevd", "sdfm"],
            summary="Structural DFM forecast error variance decomposition",
            args=[ArgSpec(name="data", description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="q", type=Int, default=nothing, description="Number of dynamic factors"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign"),
                OptionSpec(name="var-lags", type=Int, default=1, description="Factor VAR lag order"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="FEVD horizon"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd_sdfm, description="Structural DFM forecast error variance decomposition")],
            category="fevd",
            handler=wrap_legacy(_fevd_sdfm),
        )
    ]
end

function register_fevd_commands!()
    specs = with_config_ergonomics(with_model_option(fevd_specs()))
    register!(specs)
    return build_node("fevd", specs; description="Forecast Error Variance Decomposition")
end


# ── VAR FEVD ─────────────────────────────────────────────

function _fevd_var(; data::String="", lags=nothing, horizons::Int=20,
                    id::String="cholesky", config::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="",
                    model=nothing)
    if isnothing(model)
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
    else
        varnames = model.varnames
        p = model.p
    end
    n = length(varnames)

    _status("Computing FEVD: VAR($p), horizons=$horizons, id=$id")
    _status()

    # Arias identification: use identify_arias → irf_mean → compute FEVD from structural IRFs
    if id == "arias"
        isempty(config) && error("Arias identification requires a --config file with restrictions")
        cfg = load_config(config)
        id_cfg = get(cfg, "identification", Dict())
        zeros_list = get(id_cfg, "zero_restrictions", [])
        signs_list = get(id_cfg, "sign_restrictions", [])
        zero_restrs = [zero_restriction(r["var"], r["shock"]; horizon=r["horizon"]) for r in zeros_list]
        sign_restrs = [sign_restriction(r["var"], r["shock"], Symbol(r["sign"]); horizon=r["horizon"]) for r in signs_list]
        restrictions = SVARRestrictions(n; zeros=zero_restrs, signs=sign_restrs)
        arias_result = identify_arias(model, restrictions, horizons)
        irf_vals = irf_mean(arias_result)  # H x n x n
        n_h = size(irf_vals, 1)
        # Compute FEVD proportions from structural IRFs
        proportions = zeros(n, n, n_h)
        for h in 1:n_h
            total_var = zeros(n)
            for vi in 1:n
                for si in 1:n
                    cum_sq = sum(irf_vals[t, vi, si]^2 for t in 1:h)
                    proportions[vi, si, h] = cum_sq
                    total_var[vi] += cum_sq
                end
            end
            for vi in 1:n
                if total_var[vi] > 0
                    proportions[vi, :, h] ./= total_var[vi]
                end
            end
        end
        _output_fevd_tables(proportions, varnames, n_h;
                            id="arias", title_prefix="FEVD", format=format, output=output)
        return
    end

    # Uhlig identification: use identify_uhlig → compute FEVD from structural IRFs
    if id == "uhlig"
        isempty(config) && error("Uhlig identification requires a --config file with restrictions")
        cfg = load_config(config)
        id_cfg = get(cfg, "identification", Dict())
        zeros_list = get(id_cfg, "zero_restrictions", [])
        signs_list = get(id_cfg, "sign_restrictions", [])
        zero_restrs = [zero_restriction(r["var"], r["shock"]; horizon=r["horizon"]) for r in zeros_list]
        sign_restrs = [sign_restriction(r["var"], r["shock"], Symbol(r["sign"]); horizon=r["horizon"]) for r in signs_list]
        restrictions = SVARRestrictions(n; zeros=zero_restrs, signs=sign_restrs)
        uhlig_params = get_uhlig_params(cfg)
        uhlig_result = identify_uhlig(model, restrictions, horizons;
            n_starts=uhlig_params["n_starts"], n_refine=uhlig_params["n_refine"],
            max_iter_coarse=uhlig_params["max_iter_coarse"], max_iter_fine=uhlig_params["max_iter_fine"],
            tol_coarse=uhlig_params["tol_coarse"], tol_fine=uhlig_params["tol_fine"])
        irf_vals = uhlig_result.irf  # H x n x n
        n_h = size(irf_vals, 1)
        # Compute FEVD proportions from structural IRFs
        proportions = zeros(n, n, n_h)
        for h in 1:n_h
            total_var = zeros(n)
            for vi in 1:n
                for si in 1:n
                    cum_sq = sum(irf_vals[t, vi, si]^2 for t in 1:h)
                    proportions[vi, si, h] = cum_sq
                    total_var[vi] += cum_sq
                end
            end
            for vi in 1:n
                if total_var[vi] > 0
                    proportions[vi, :, h] ./= total_var[vi]
                end
            end
        end
        _output_fevd_tables(proportions, varnames, n_h;
                            id="uhlig", title_prefix="FEVD", format=format, output=output)
        return
    end

    kwargs = _build_identification_kwargs(id, config)
    fevd_result = fevd(model, horizons; kwargs...)

    _status_report(() -> report(fevd_result))

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    _output_fevd_tables(fevd_result.proportions, varnames, horizons;
                        id=id, title_prefix="FEVD", format=format, output=output)
end

# ── BVAR FEVD ────────────────────────────────────────────

function _fevd_bvar(; data::String="", lags::Int=4, horizons::Int=20,
                     id::String="cholesky", draws::Int=2000, sampler::String="direct",
                     config::String="",
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="",
                     model=nothing)
    if isnothing(model)
        post, Y, varnames, p, n = _load_and_estimate_bvar(data, lags, config, draws, sampler)
    else
        post = model
        varnames = post.varnames
        p = post.p
        n = length(varnames)
    end

    _status("Computing Bayesian FEVD: BVAR($p), horizons=$horizons, id=$id")
    _status("  Sampler: $sampler, Draws: $draws")
    _status()

    bfevd = fevd(post, horizons;
        quantiles=[0.16, 0.5, 0.84])

    _status_report(() -> report(bfevd))

    _maybe_plot(bfevd; plot=plot, plot_save=plot_save)

    _output_fevd_tables(bfevd.mean, varnames, horizons;
                        id=id, title_prefix="Bayesian FEVD", format=format, output=output)
end

# ── LP FEVD ──────────────────────────────────────────────

function _fevd_lp(; data::String="", horizons::Int=20, lags::Int=4, var_lags=nothing,
                   id::String="cholesky", vcov::String="newey_west", config::String="",
                   output::String="", format::String="table",
                   plot::Bool=false, plot_save::String="",
                   model=nothing)
    if isnothing(model)
        slp, Y, varnames = _load_and_structural_lp(data, horizons, lags, var_lags,
            id, vcov, config)
        n = size(Y, 2)
    else
        slp = model
        varnames = slp.varnames
        n = length(varnames)
    end

    _status("Computing LP FEVD: horizons=$horizons, id=$id")
    _status()

    fevd_result = lp_fevd(slp, horizons)

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    _output_fevd_tables(fevd_result.bias_corrected, varnames, horizons;
                        id=id, title_prefix="LP FEVD", format=format, output=output)
end

# ── VECM FEVD ───────────────────────────────────────────

function _fevd_vecm(; data::String="", lags::Int=2, rank::String="auto",
                     deterministic::String="constant", horizons::Int=20,
                     id::String="cholesky", config::String="",
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

    _status("Computing VECM FEVD: rank=$r, VAR($p), horizons=$horizons, id=$id")
    _status()

    kwargs = _build_identification_kwargs(id, config)
    fevd_result = fevd(var_model, horizons; kwargs...)

    _status_report(() -> report(fevd_result))

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    _output_fevd_tables(fevd_result.proportions, varnames, horizons;
                        id=id, title_prefix="VECM FEVD", format=format, output=output)
end

# ── Panel VAR FEVD ─────────────────────────────────────────

function _fevd_pvar(; data::String="", id_col::String="", time_col::String="",
                     lags::Int=1, horizons::Int=10,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="",
                     model=nothing)
    if isnothing(model)
        isempty(id_col) && error("Panel VAR FEVD requires --id-col")
        isempty(time_col) && error("Panel VAR FEVD requires --time-col")
        model, panel, varnames = _load_and_estimate_pvar(data, id_col, time_col, lags)
    else
        varnames = model.varnames
    end
    n = length(varnames)

    _status("Computing Panel VAR FEVD: horizons=$horizons")
    _status()

    # MEMs 0.7.0 (C054): pvar_fevd now returns a raw (H+1)×n×n array indexed
    # [horizon, variable, shock] (was a struct with `.proportions`). Permute to
    # [variable, shock, horizon] and drop horizon 0 to keep the 1..H tables.
    fevd_arr = pvar_fevd(model, horizons)

    _maybe_plot(fevd_arr; plot=plot, plot_save=plot_save)

    proportions = permutedims(fevd_arr[2:end, :, :], (2, 3, 1))
    _output_fevd_tables(proportions, varnames, horizons;
                        id="cholesky", title_prefix="Panel VAR FEVD",
                        format=format, output=output)
end

# ── FAVAR FEVD ─────────────────────────────────────────

function _fevd_favar(; data::String="", factors=nothing, lags::Int=2,
                      key_vars::String="", horizons::Int=20,
                      id::String="cholesky", config::String="",
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="",
                      model=nothing)
    if isnothing(model)
        favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, "two_step", 5000)
    else
        favar = model
        varnames = favar.varnames
    end
    id_kwargs = _build_identification_kwargs(id, config)

    _status("FAVAR FEVD: horizon=$horizons, id=$id")
    _status()

    result = fevd(favar, horizons; id_kwargs...)
    _maybe_plot(result; plot=plot, plot_save=plot_save)

    n_vars = size(result.proportions, 1)
    n_shocks = size(result.proportions, 2)
    for v in 1:n_vars
        vname = v <= length(favar.varnames) ? favar.varnames[v] : "var_$v"
        fevd_df = DataFrame()
        fevd_df.horizon = 1:horizons
        for s in 1:n_shocks
            sname = s <= length(favar.varnames) ? favar.varnames[s] : "shock_$s"
            fevd_df[!, sname] = round.(result.proportions[v, s, :]; digits=4)
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="FAVAR FEVD — variable: $vname")
    end
end

# ── Structural DFM FEVD ──────────────────────────────

function _fevd_sdfm(; data::String="", factors=nothing, id::String="cholesky",
                     var_lags::Int=1, horizons::Int=20,
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

    _status("SDFM FEVD: $q factors, horizon=$horizons")
    _status()

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
