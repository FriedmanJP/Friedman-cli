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

# Forecast commands: var, bvar, lp, arima, static, dynamic, gdfm,
#                    arch, garch, egarch, gjr_garch, sv

function forecast_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["forecast", "var"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="confidence", type=Float64, default=0.95, description="Confidence level for intervals"),
                OptionSpec(name="ci-method", type=String, default="analytical", description="analytical|bootstrap"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_var, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_var),
        ),
        CommandSpec(
            path=["forecast", "bvar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Lag order"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="draws", short="n", type=Int, default=2000, description="MCMC draws"),
                OptionSpec(name="sampler", type=String, default="direct", description="direct|gibbs"),
                OptionSpec(name="config", type=String, default="", description="TOML config for prior hyperparameters"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:forecast_bvar, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_bvar),
        ),
        CommandSpec(
            path=["forecast", "lp"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="shock", type=Int, default=1, description="Shock variable index (1-based)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="shock-size", type=Float64, default=1.0, description="Impulse shock size"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="LP control lags"),
                OptionSpec(name="vcov", type=String, default="newey_west", description="newey_west|white|driscoll_kraay"),
                OptionSpec(name="ci-method", type=String, default="analytical", description="analytical|bootstrap|none"),
                OptionSpec(name="conf-level", type=Float64, default=0.95, description="Confidence level"),
                OptionSpec(name="n-boot", type=Int, default=500, description="Bootstrap replications"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_lp, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_lp),
        ),
        CommandSpec(
            path=["forecast", "arima"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=nothing, description="AR order (default: auto selection)"),
                OptionSpec(name="d", type=Int, default=0, description="Differencing order"),
                OptionSpec(name="q", type=Int, default=0, description="MA order"),
                OptionSpec(name="max-p", type=Int, default=5, description="Max AR order for auto selection"),
                OptionSpec(name="max-d", type=Int, default=2, description="Max differencing order for auto selection"),
                OptionSpec(name="max-q", type=Int, default=5, description="Max MA order for auto selection"),
                OptionSpec(name="criterion", type=String, default="bic", description="aic|bic"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="confidence", type=Float64, default=0.95, description="Confidence level"),
                OptionSpec(name="method", short="m", type=String, default="css_mle", description="ols|css|mle|css_mle"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_arima, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_arima),
        ),
        CommandSpec(
            path=["forecast", "static"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of factors (default: auto via IC)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="ci-method", type=String, default="none", description="none|bootstrap|parametric"),
                OptionSpec(name="conf-level", type=Float64, default=0.95, description="Confidence level for intervals"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_static, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_static),
        ),
        CommandSpec(
            path=["forecast", "dynamic"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="factor-lags", short="p", type=Int, default=1, description="Factor VAR lag order"),
                OptionSpec(name="method", type=String, default="twostep", description="twostep|em"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_dynamic, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_dynamic),
        ),
        CommandSpec(
            path=["forecast", "gdfm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of static factors (default: auto)"),
                OptionSpec(name="dynamic-rank", short="q", type=Int, default=nothing, description="Dynamic rank (default: auto)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_gdfm, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_gdfm),
        ),
        # Volatility 20-plex (forecast side): generated from VOL_MODELS
        _vol_specs(:forecast)...,
        CommandSpec(
            path=["forecast", "vecm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="ci-method", type=String, default="none", description="none|bootstrap|parametric"),
                OptionSpec(name="replications", type=Int, default=500, description="Bootstrap replications"),
                OptionSpec(name="confidence", type=Float64, default=0.95, description="Confidence level for intervals"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_vecm, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_vecm),
        ),
        CommandSpec(
            path=["forecast", "favar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="VAR lag order"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variable names or indices (comma-separated)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="panel-forecast", description="Output panel-wide forecast instead of factor-level"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:forecast_favar, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_favar),
        )
    ]
end

function register_forecast_commands!()
    specs = with_config_ergonomics(with_model_option(forecast_specs()))
    register!(specs)
    return build_node("forecast", specs; description="Forecasting")
end


# ── VAR Forecast ─────────────────────────────────────────

function _forecast_var(; data::String="", lags=nothing, horizons::Int=12,
                        confidence::Float64=0.95, ci_method::String="analytical",
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="",
                        model=nothing)
    if isnothing(model)
        model, _, _, p = _load_and_estimate_var(data, lags)
    else
        p = model.p
    end

    # C051: render the forecast (point + CI) through MEMs' uniform tidy long_table
    # (horizon | variable | value | lower | upper), replacing the hand-built wide table
    # and the hand-rolled companion-matrix MSE. MEMs' symbol is :analytic (not :analytical).
    ci_sym = ci_method == "bootstrap" ? :bootstrap :
             ci_method == "none"      ? :none : :analytic

    _status("Computing VAR($p) forecast: horizons=$horizons, confidence=$confidence, ci=$ci_method")
    _status()

    fc_kw = ci_sym == :bootstrap ?
        (; ci_method=:bootstrap, reps=500, conf_level=confidence) :
        (; ci_method=ci_sym, conf_level=confidence)
    fc_result = forecast(model, horizons; fc_kw...)
    fc_df = long_table(fc_result)

    ci_label = ci_sym == :bootstrap ? "bootstrap $(Int(round(confidence*100)))% CI" :
               ci_sym == :none      ? "point forecast" :
               "$(Int(round(confidence*100)))% CI"
    output_result(fc_df; format=Symbol(format), output=output,
                  title="VAR($p) Forecast (h=$horizons, $ci_label)")
    _maybe_plot(fc_result; plot=plot, plot_save=plot_save)
end

# Normal quantile without importing Distributions (Abramowitz & Stegun 26.2.23)
function quantile_normal(p::Float64)
    if p < 0.5
        return -quantile_normal(1.0 - p)
    end
    t = sqrt(-2.0 * log(1.0 - p))
    c0, c1, c2 = 2.515517, 0.802853, 0.010328
    d1, d2, d3 = 1.432788, 0.189269, 0.001308
    return t - (c0 + c1*t + c2*t^2) / (1.0 + d1*t + d2*t^2 + d3*t^3)
end

# ── BVAR Forecast ────────────────────────────────────────

function _forecast_bvar(; data::String="", lags::Int=4, horizons::Int=12,
                         draws::Int=2000, sampler::String="direct",
                         config::String="",
                         output::String="", format::String="table",
                         model=nothing)
    if isnothing(model)
        post, Y, varnames, p, n = _load_and_estimate_bvar(data, lags, config, draws, sampler)
    else
        post = model
        varnames = post.varnames
        p = post.p
        n = length(varnames)
        Y = post.Y
    end

    _status("Computing Bayesian forecast: BVAR($p), horizons=$horizons")
    _status("  Sampler: $sampler, Draws: $draws")
    _status()

    # C051: route the posterior forecast through MEMs (→ BVARForecast with the posterior
    # mean + credible bands) and render its tidy long_table (horizon|variable|value|lower|
    # upper), replacing the hand-rolled per-draw simulation and quantile computation.
    fc = forecast(post, horizons; conf_level=0.68)
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="Bayesian VAR($p) Forecast (h=$horizons, 68% credible interval)")
end

# ── LP Forecast ──────────────────────────────────────────

function _forecast_lp(; data::String="", shock::Int=1, horizons::Int=12,
                       shock_size::Float64=1.0, lags::Int=4,
                       vcov::String="newey_west",
                       ci_method::String="analytical", conf_level::Float64=0.95,
                       n_boot::Int=500,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="",
                       model=nothing)
    if isnothing(model)
        Y, varnames = load_multivariate_data(data)
        model = estimate_lp(Y, shock, horizons;
            lags=lags, cov_type=Symbol(vcov))
    else
        varnames = model.varnames
    end

    _status("Computing LP forecast: shock=$shock, horizons=$horizons, shock_size=$shock_size, ci=$ci_method")
    _status()

    shock_path = fill(shock_size, horizons)

    fc = forecast(model, shock_path;
        ci_method=Symbol(ci_method), conf_level=conf_level, n_boot=n_boot)

    _maybe_plot(fc; plot=plot, plot_save=plot_save)

    shock_name = _shock_name(varnames, shock)
    # C051: MEMs tidy long_table (horizon|variable|value|lower|upper).
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="LP Forecast (shock=$shock_name, h=$horizons, $(Int(round(conf_level*100)))% CI)")
end

# ── ARIMA Forecast ───────────────────────────────────────

function _forecast_arima(; data::String="", column::Int=1, p=nothing, d::Int=0, q::Int=0,
                           max_p::Int=5, max_d::Int=2, max_q::Int=5,
                           criterion::String="bic", horizons::Int=12,
                           confidence::Float64=0.95, method::String="css_mle",
                           format::String="table", output::String="",
                           plot::Bool=false, plot_save::String="",
                           model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        method_sym = Symbol(method)
        safe_method = method_sym == :css_mle ? :mle : method_sym

        model = if isnothing(p)
            crit_sym = Symbol(lowercase(criterion))
            _status("Auto ARIMA forecast: variable=$vname, observations=$(length(y))")
            _status("  Search: p=0:$max_p, d=0:$max_d, q=0:$max_q, criterion=$criterion")
            _status()
            m = auto_arima(y; max_p=max_p, max_q=max_q, max_d=max_d, criterion=crit_sym, method=safe_method)
            label = _model_label(ar_order(m), diff_order(m), ma_order(m))
            _status_styled("Selected model: $label\n"; bold=true)
            _status()
            m
        else
            label = _model_label(p, d, q)
            _status("$label forecast: variable=$vname, horizons=$horizons")
            _status()
            _estimate_arima_model(y, p, d, q; method=method_sym)
        end
    end

    fc = forecast(model, horizons; conf_level=confidence)

    _maybe_plot(fc; plot=plot, plot_save=plot_save)

    p_sel = ar_order(model)
    d_sel = diff_order(model)
    q_sel = ma_order(model)
    label = _model_label(p_sel, d_sel, q_sel)

    # C051: MEMs tidy long_table (horizon|variable|value|lower|upper).
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="$label Forecast for $vname (h=$horizons, $(Int(round(confidence*100)))% CI)")
end

# ── Factor Model Forecasts ───────────────────────────────

function _forecast_static(; data::String="", nfactors=nothing, horizons::Int=12,
                            ci_method::String="none", conf_level::Float64=0.95,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="",
                            model=nothing)
    if isnothing(model)
        X, varnames = load_multivariate_data(data)

        r = if isnothing(nfactors)
            _status("Selecting number of factors via Bai-Ng information criteria...")
            ic = ic_criteria(X, min(20, size(X, 2)))
            optimal_r = ic.r_IC1
            _status("  IC1 suggests $optimal_r factors")
            optimal_r
        else
            nfactors
        end

        _status("Forecasting with static factor model: $r factors, horizon=$horizons, CI=$ci_method")
        _status()

        fm = estimate_factors(X, r)
    else
        fm = model
        varnames = fm.varnames
    end
    fc = forecast(fm, horizons; ci_method=Symbol(ci_method), conf_level=conf_level)

    _maybe_plot(fc; plot=plot, plot_save=plot_save)

    # C051: MEMs tidy long_table (horizon|variable|value|lower|upper).
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="Static Factor Forecast (h=$horizons, $(length(varnames)) variables)")

    if !isnothing(fc.observables_se)
        _status()
        avg_se = round.(mean(fc.observables_se; dims=1)[1, :]; digits=4)
        _status("Average forecast standard errors:")
        for (vi, vname) in enumerate(varnames)
            _status("  $vname: $(avg_se[vi])")
        end
    end
end

function _forecast_dynamic(; data::String="", nfactors=nothing, horizons::Int=12,
                             factor_lags::Int=1, method::String="twostep",
                             output::String="", format::String="table",
                             plot::Bool=false, plot_save::String="",
                             model=nothing)
    if isnothing(model)
        X, varnames = load_multivariate_data(data)

        r = if isnothing(nfactors)
            _status("Selecting number of factors...")
            ic = ic_criteria(X, min(10, size(X, 2)))
            optimal_r = ic.r_IC1
            _status("  Auto-selected $optimal_r factors")
            optimal_r
        else
            nfactors
        end

        _status("Forecasting with dynamic factor model: $r factors, $factor_lags lags, method=$method, horizon=$horizons")
        _status()

        fm = estimate_dynamic_factors(X, r, factor_lags; method=Symbol(method))
    else
        fm = model
        varnames = fm.varnames
    end
    fc = forecast(fm, horizons)

    _maybe_plot(fc; plot=plot, plot_save=plot_save)

    # C051: render the FactorForecast's observable forecasts through MEMs' tidy
    # long_table (horizon|variable|value|lower|upper), replacing the hand-rolled
    # loadings reconstruction.
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="Dynamic Factor Forecast (h=$horizons, $(length(varnames)) variables)")
end

function _forecast_gdfm(; data::String="", nfactors=nothing, dynamic_rank=nothing,
                          horizons::Int=12,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="",
                          model=nothing)
    if isnothing(model)
        X, varnames = load_multivariate_data(data)

        q = if isnothing(dynamic_rank)
            _status("Selecting dynamic rank...")
            ic = ic_criteria_gdfm(X, min(5, size(X, 2)))
            q_opt = ic.q_ratio
            _status("  Auto-selected $q_opt dynamic factors")
            q_opt
        else
            dynamic_rank
        end

        r = if isnothing(nfactors)
            _status("Selecting static rank...")
            ic_static = ic_criteria(X, min(20, size(X, 2)))
            r_opt = ic_static.r_IC1
            _status("  Auto-selected $r_opt static factors")
            r_opt
        else
            nfactors
        end

        _status("Forecasting with GDFM: static rank=$r, dynamic rank=$q, horizon=$horizons")
        _status()

        fm = estimate_gdfm(X, q; r=r)
    else
        fm = model
        varnames = fm.varnames
    end

    # C051: route through MEMs' GDFM forecast (→ FactorForecast) and render its tidy
    # long_table (horizon|variable|value|lower|upper), replacing the hand-rolled AR(1)
    # extrapolation on the common-component factors.
    fc = forecast(fm, horizons)
    _maybe_plot(fc; plot=plot, plot_save=plot_save)
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="GDFM Forecast (h=$horizons, $(length(varnames)) variables)")

    _status()
    var_shares = common_variance_share(fm)
    _status("Average common variance share: $(round(mean(var_shares); digits=4))")
end

# Volatility forecast handlers live in shared.jl (VOL_MODELS / _VOL_FORECAST_HANDLERS).

# ── VECM Forecast ───────────────────────────────────────

function _forecast_vecm(; data::String="", lags::Int=2, rank::String="auto",
                          deterministic::String="constant", horizons::Int=12,
                          ci_method::String="none", replications::Int=500,
                          confidence::Float64=0.95,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="",
                          model=nothing)
    if isnothing(model)
        vecm, Y, varnames, p = _load_and_estimate_vecm(data, lags, rank, deterministic, "johansen", 0.05)
    else
        vecm = model
        varnames = vecm.varnames
        p = vecm.p
    end
    r = cointegrating_rank(vecm)

    _status("Computing VECM forecast: rank=$r, horizons=$horizons, CI=$ci_method")
    _status()

    fc = forecast(vecm, horizons; ci_method=Symbol(ci_method), reps=replications, conf_level=confidence)

    _maybe_plot(fc; plot=plot, plot_save=plot_save)

    ci_label = ci_method == "none" ? "" : ", $(Int(round(confidence*100)))% CI"
    # C051: MEMs tidy long_table (horizon|variable|value|lower|upper).
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="VECM Forecast (rank=$r, h=$horizons$ci_label)")
end

# ── FAVAR Forecast ────────────────────────────────────────

function _forecast_favar(; data::String="", factors=nothing, lags::Int=2,
                          key_vars::String="", horizons::Int=12,
                          panel_forecast::Bool=false,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="",
                          model=nothing)
    if isnothing(model)
        favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, "two_step", 5000)
    else
        favar = model
        varnames = favar.varnames
    end

    _status("FAVAR Forecast: horizon=$horizons" * (panel_forecast ? ", panel-wide" : ""))
    _status()

    fc = forecast(favar, horizons)

    if panel_forecast
        fc = favar_panel_forecast(favar, fc)
    end

    _maybe_plot(fc; plot=plot, plot_save=plot_save)

    # C051: MEMs tidy long_table (horizon|variable|value|lower|upper).
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="FAVAR Forecast (h=$horizons)")
end
