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
        # C065a: SETAR bootstrap-simulation forecast. Re-estimates the SETAR then simulates
        # `forecast(::ThresholdModel, h)` → ThresholdForecast (AbstractForecastResult → tidy
        # long_table). `forecast` is SETAR-only upstream, but `estimate_setar` always sets
        # is_setar=true, so no extra guard; `--transition-col` is NOT offered (that path exists
        # only for STAR external-s models, which are not forecastable). `--ci-level` MUST be
        # exactly 0.90/0.95/0.99 (Hansen 2000 tabulation used by the re-estimated threshold CI).
        # NO `--plot`/`--plot-save`: MEMs 0.7.0 ships NO `plot_result(::ThresholdForecast)` recipe
        # (only `ThresholdModel`/`STARModel` + the 8 registered forecast types are plottable), so
        # advertising the flag would drive `_maybe_plot` into an uncaught MethodError → exit 1. Per
        # the C051 convention only plot-capable leaves add the flags; revisit if MEMs adds one.
        CommandSpec(
            path=["forecast", "setar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="d", type=String, default="1", description="Delay lag: an integer ≥ 1, or 'auto' (=1:p grid)"),
                OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon (≥ 1)"),
                OptionSpec(name="reps", type=Int, default=1000, description="Bootstrap simulation paths (≥ 1)"),
                OptionSpec(name="ci-level", type=Float64, default=0.95, description="Band coverage: 0.90|0.95|0.99", choices=["0.90", "0.95", "0.99"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table", "csv", "json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:forecast_setar, description="Path to CSV data file")],
            category="forecast",
            handler=wrap_legacy(_forecast_setar),
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
        ),
        # ── forecast evaluate: forecast evaluation & combination (C072, M5c) ──
        # Nested depth-3 sub-node. Uniform input: a CSV + --actual <col> +
        # --forecasts <c1,c2,...>; the handler forms errors / f_adj / the matrix.
        CommandSpec(
            path=["forecast", "evaluate", "metrics"],
            summary="Point forecast-accuracy metrics (ME/MAE/RMSE/MAPE/sMAPE/MASE/U1/U2) + Theil decomposition",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=vcat([
                OptionSpec(name="actual", type=String, default="", description="Realized-values column name (required)"),
                OptionSpec(name="forecasts", type=String, default="", description="Forecast column names, comma-separated (required, >=1)"),
                OptionSpec(name="seasonal-period", type=Int, default=1, description="Seasonal lag for MASE naive-forecast scaling"),
            ], OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[TableSpec(name=:forecast_accuracy_metrics, description="Point accuracy metrics, one row per forecast")],
            category="forecast",
            handler=wrap_legacy(_forecast_eval_metrics),
        ),
        CommandSpec(
            path=["forecast", "evaluate", "dm"],
            summary="Diebold-Mariano (1995) equal-predictive-accuracy test (exactly 2 forecasts)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=vcat([
                OptionSpec(name="actual", type=String, default="", description="Realized-values column name (required)"),
                OptionSpec(name="forecasts", type=String, default="", description="Two forecast column names, comma-separated (required)"),
                OptionSpec(name="loss", type=String, default="se", choices=["se","ad"], description="Loss: se (squared) | ad (absolute)"),
                OptionSpec(name="horizon", short="h", type=Int, default=1, description="Forecast horizon (sets truncation lag h-1)"),
                OptionSpec(name="alternative", type=String, default="two-sided", choices=["two-sided","less","greater"], description="Alternative hypothesis"),
            ], OUTPUT_OPTIONS),
            flags=[FlagSpec(name="no-hln", description="Disable the Harvey-Leybourne-Newbold small-sample correction (use N(0,1))")],
            tables=[TableSpec(name=:diebold_mariano_test, description="DM statistic / p-value")],
            category="forecast",
            handler=wrap_legacy(_forecast_eval_dm),
        ),
        CommandSpec(
            path=["forecast", "evaluate", "clark-west"],
            summary="Clark-West (2007) adjusted-MSPE test for nested models (exactly 2 forecasts: small then big)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=vcat([
                OptionSpec(name="actual", type=String, default="", description="Realized-values column name (required)"),
                OptionSpec(name="forecasts", type=String, default="", description="Two forecast columns: small (restricted), big (unrestricted)"),
                OptionSpec(name="horizon", short="h", type=Int, default=1, description="Forecast horizon (sets truncation lag h-1)"),
                OptionSpec(name="alternative", type=String, default="greater", choices=["two-sided","less","greater"], description="Alternative hypothesis"),
            ], OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[TableSpec(name=:clark_west_test, description="CW statistic / one-sided p-value")],
            category="forecast",
            handler=wrap_legacy(_forecast_eval_clark_west),
        ),
        CommandSpec(
            path=["forecast", "evaluate", "mincer-zarnowitz"],
            summary="Mincer-Zarnowitz (1969) forecast-efficiency regression (exactly 1 forecast)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=vcat([
                OptionSpec(name="actual", type=String, default="", description="Realized-values column name (required)"),
                OptionSpec(name="forecasts", type=String, default="", description="One forecast column name (required)"),
                OptionSpec(name="lags", type=Int, default=0, description="Newey-West HAC truncation lag (0 = White)"),
                OptionSpec(name="kernel", type=String, default="bartlett", choices=["bartlett","parzen","quadratic_spectral","tukey_hanning"], description="HAC kernel"),
            ], OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[TableSpec(name=:mincer_zarnowitz_test, description="a, b, HAC SEs, joint Wald/F")],
            category="forecast",
            handler=wrap_legacy(_forecast_eval_mincer_zarnowitz),
        ),
        CommandSpec(
            path=["forecast", "evaluate", "encompassing"],
            summary="Harvey-Leybourne-Newbold (1998) forecast-encompassing test (exactly 2 forecasts)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=vcat([
                OptionSpec(name="actual", type=String, default="", description="Realized-values column name (required)"),
                OptionSpec(name="forecasts", type=String, default="", description="Two forecast column names, comma-separated (required)"),
                OptionSpec(name="lags", type=Int, default=0, description="Newey-West HAC truncation lag (0 = White)"),
                OptionSpec(name="kernel", type=String, default="bartlett", choices=["bartlett","parzen","quadratic_spectral","tukey_hanning"], description="HAC kernel"),
            ], OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[TableSpec(name=:forecast_encompassing_test, description="b1, b2, t-stat on b2")],
            category="forecast",
            handler=wrap_legacy(_forecast_eval_encompassing),
        ),
        CommandSpec(
            path=["forecast", "evaluate", "combine"],
            summary="Forecast combination (equal / Bates-Granger / Granger-Ramanathan weights; >=2 forecasts)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=vcat([
                OptionSpec(name="actual", type=String, default="", description="Realized-values column name (required)"),
                OptionSpec(name="forecasts", type=String, default="", description="Forecast column names, comma-separated (required, >=2)"),
                OptionSpec(name="method", type=String, default="equal", choices=["equal","bates-granger","granger-ramanathan"], description="Combination method"),
            ], OUTPUT_OPTIONS),
            flags=[FlagSpec(name="emit-series", description="Also emit the combined forecast series (index|combined)")],
            tables=[TableSpec(name=:forecast_combination_weights, description="model | weight | mse")],
            category="forecast",
            handler=wrap_legacy(_forecast_eval_combine),
        )
    ]
end

function register_forecast_commands!()
    all_specs = forecast_specs()
    # The `forecast evaluate` leaves are model-agnostic (plain CSV columns) and take
    # no model handle — don't inject --model onto them, or a stray `--model foo`
    # would MethodError the handler (exit 1) instead of a clean unknown-option usage error.
    is_eval(s) = length(s.path) >= 2 && s.path[2] == "evaluate"
    specs = with_config_ergonomics(vcat(
        with_model_option(filter(!is_eval, all_specs)),
        filter(is_eval, all_specs)))
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

# ── C065a: SETAR bootstrap forecast ─────────────────────────
# Re-estimate the SETAR (no attached linearity test — unused here), then simulate
# `forecast(::ThresholdModel, h)`. Both MEMs calls are try-wrapped → typed CliError via
# the shared `_nonlinear_error`; every option is guarded up-front → usage/invalid. The
# ThresholdForecast is an AbstractForecastResult, so it renders via the generic long_table.
function _forecast_setar(; data::String="", column::Int=1, p::Int=1, d::String="1",
                          horizons::Int=12, reps::Int=1000, ci_level::Float64=0.95,
                          format::String="table", output::String="")
    p >= 1 || throw(CliError("usage/invalid", "forecast setar: --p must be ≥ 1 (got $p)"))
    (ci_level == 0.90 || ci_level == 0.95 || ci_level == 0.99) || throw(CliError("usage/invalid",
        "forecast setar: --ci-level must be exactly 0.90, 0.95, or 0.99 (got $ci_level)"))
    horizons >= 1 || throw(CliError("usage/invalid", "forecast setar: --horizons must be ≥ 1 (got $horizons)"))
    reps >= 1 || throw(CliError("usage/invalid", "forecast setar: --reps must be ≥ 1 (got $reps)"))
    d_arg = _parse_setar_delay(d)
    y, vname = load_univariate_series(data, column)
    _status("SETAR forecast (h=$horizons): variable=$vname, obs=$(length(y)), d=$d, ci=$ci_level"); _status()
    model = try
        estimate_setar(y, p, d_arg; reps=reps, ci_level=ci_level, linearity=false)
    catch e
        throw(_nonlinear_error(e, "SETAR forecast"))
    end
    fc = try
        forecast(model, horizons; reps=reps, level=ci_level)
    catch e
        throw(_nonlinear_error(e, "SETAR forecast"))
    end
    # ThresholdForecast <: AbstractForecastResult → MEMs tidy long_table (horizon|variable|value|lower|upper).
    # No _maybe_plot: MEMs ships no plot_result(::ThresholdForecast) recipe (see the CommandSpec note).
    output_result(long_table(fc); format=Symbol(format), output=output,
                  title="SETAR Forecast for $vname (h=$horizons, $(Int(round(ci_level*100)))% CI)")
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

# ── forecast evaluate: forecast evaluation & combination (C072, M5c) ──
# Wraps the MEMs `fceval/` module (model-agnostic, plain vectors). The result
# types (ForecastEvaluation/DMTestResult/…) are NOT Tables.jl-registered upstream,
# so tables are hand-built (a documented C051 exception, like the io and SUR/3SLS
# families). Uniform input for every leaf: a CSV + --actual <col> +
# --forecasts <c1,c2,...>; the handler forms the errors / f_adj / forecast matrix.
#
# Convention notes (mirrored in docs): DM consumes forecast ERRORS e=actual-fc;
# Clark-West needs f_adj = f_small - f_big (the forecast difference; the library
# squares it internally).

"""Resolve the actual + forecast columns by name; return (y, fnames, fcols)."""
function _fceval_load(data::String, actual::String, forecasts::String; leaf::String)
    isempty(actual) && throw(CliError("usage/missing-actual",
        "forecast evaluate $leaf requires --actual <column> (the realized-values column)"))
    isempty(strip(forecasts)) && throw(CliError("usage/missing-forecasts",
        "forecast evaluate $leaf requires --forecasts <col1,col2,...>"))
    df = load_data(data)
    numcols = variable_names(df)
    actual in numcols || throw(CliError("data/bad-column",
        "actual column '$actual' not found in numeric columns: $(join(numcols, ", "))"))
    fnames = String[String(strip(s)) for s in split(forecasts, ",") if !isempty(strip(s))]
    isempty(fnames) && throw(CliError("usage/missing-forecasts",
        "forecast evaluate $leaf requires at least one --forecasts column"))
    for c in fnames
        c in numcols || throw(CliError("data/bad-column",
            "forecast column '$c' not found in numeric columns: $(join(numcols, ", "))"))
    end
    # `variable_names` admits Union{Number,Missing} columns, so guard for missing
    # values → typed data error (a blank cell would otherwise MethodError → exit 1).
    _col(c) = any(ismissing, df[!, c]) ?
        throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them (e.g. via `data dropna`) before forecast evaluation")) :
        Vector{Float64}(df[!, c])
    y = _col(actual)
    fcols = Vector{Float64}[_col(c) for c in fnames]
    return (y, fnames, fcols)
end

# Enforce the per-leaf forecast-count arity → usage error (never a downstream crash).
function _fceval_arity(fnames::Vector{String}, leaf::String, want::String, ok::Bool)
    ok || throw(CliError("usage/arity",
        "forecast evaluate $leaf needs $want --forecasts column(s); got $(length(fnames))"))
    return nothing
end

# Map an fceval failure to a typed CliError (never an uncaught exit-1 — io-family lesson).
function _fceval_error(e, what::String)
    e isa CliError && return e
    (e isa ArgumentError || e isa DimensionMismatch) && return CliError("data/fceval",
        sprint(showerror, e);
        hint="check --actual/--forecasts refer to equal-length numeric columns with >=2 observations")
    return CliError("model/error", "$what failed: $(sprint(showerror, e))")
end

function _forecast_eval_metrics(; data::String, actual::String="", forecasts::String="",
                                 seasonal_period::Int=1, output::String="", format::String="table")
    y, fnames, fcols = _fceval_load(data, actual, forecasts; leaf="metrics")
    _status("Forecast evaluation: $(length(fnames)) forecast(s), n=$(length(y)), seasonal_period=$seasonal_period")
    _status()
    Fmat = reduce(hcat, fcols)
    ev = try
        forecast_evaluate(y, Fmat; seasonal_period=seasonal_period, model_names=fnames)
    catch e
        throw(_fceval_error(e, "forecast evaluation"))
    end
    # C051 exception: hand-built WIDE accuracy table model | ME | MAE | ... | U2.
    acc = DataFrame(model = ev.models)
    for (k, mname) in enumerate(ev.metrics)
        acc[!, mname] = round.(ev.values[:, k]; digits=6)
    end
    output_result(acc; format=Symbol(format), output=output, title="Forecast Accuracy Metrics")
    # Theil MSE decomposition (proportions sum to 1): model | bias | variance | covariance.
    dec = DataFrame(model = ev.models,
                    bias = round.(ev.decomp[:, 1]; digits=6),
                    variance = round.(ev.decomp[:, 2]; digits=6),
                    covariance = round.(ev.decomp[:, 3]; digits=6))
    output_result(dec; format=Symbol(format), output=output, title="Theil MSE Decomposition")
    return ev
end

function _forecast_eval_dm(; data::String, actual::String="", forecasts::String="",
                            loss::String="se", horizon::Int=1, alternative::String="two-sided",
                            no_hln::Bool=false, output::String="", format::String="table")
    y, fnames, fcols = _fceval_load(data, actual, forecasts; leaf="dm")
    _fceval_arity(fnames, "dm", "exactly 2", length(fnames) == 2)
    e1 = y .- fcols[1]; e2 = y .- fcols[2]
    alt = Symbol(replace(alternative, "-" => "_"))
    _status("Diebold-Mariano: $(fnames[1]) vs $(fnames[2]), loss=$loss, h=$horizon, HLN=$(!no_hln), alt=$alternative")
    _status()
    r = try
        diebold_mariano(e1, e2; h=horizon, loss=Symbol(loss), hln=!no_hln, alternative=alt)
    catch e
        throw(_fceval_error(e, "Diebold-Mariano test"))
    end
    output_kv(Pair{String,Any}[
        "test"           => "Diebold-Mariano",
        "model_1"        => fnames[1],
        "model_2"        => fnames[2],
        "loss"           => string(r.loss),
        "statistic"      => round(r.statistic; digits=4),
        "p_value"        => round(r.pvalue; digits=4),
        "mean_loss_diff" => round(r.dbar; digits=6),
        "lrvar"          => round(r.lrvar; digits=6),
        "horizon"        => r.h,
        "hln"            => r.hln,
        "alternative"    => string(r.alternative),
        "n"              => r.T_obs,
    ]; format=format, output=output, title="Diebold-Mariano Test")
    return r
end

function _forecast_eval_clark_west(; data::String, actual::String="", forecasts::String="",
                                    horizon::Int=1, alternative::String="greater",
                                    output::String="", format::String="table")
    y, fnames, fcols = _fceval_load(data, actual, forecasts; leaf="clark-west")
    _fceval_arity(fnames, "clark-west", "exactly 2 (small then big)", length(fnames) == 2)
    f_small = fcols[1]; f_big = fcols[2]
    e_small = y .- f_small; e_big = y .- f_big; f_adj = f_small .- f_big
    alt = Symbol(replace(alternative, "-" => "_"))
    _status("Clark-West (nested): small=$(fnames[1]) big=$(fnames[2]), h=$horizon, alt=$alternative")
    _status()
    r = try
        clark_west(e_small, e_big, f_adj; h=horizon, alternative=alt)
    catch e
        throw(_fceval_error(e, "Clark-West test"))
    end
    output_kv(Pair{String,Any}[
        "test"          => "Clark-West",
        "model_small"   => fnames[1],
        "model_big"     => fnames[2],
        "statistic"     => round(r.statistic; digits=4),
        "p_value"       => round(r.pvalue; digits=4),
        "mean_adj_diff" => round(r.fbar; digits=6),
        "lrvar"         => round(r.lrvar; digits=6),
        "horizon"       => r.h,
        "alternative"   => string(r.alternative),
        "n"             => r.T_obs,
    ]; format=format, output=output, title="Clark-West Test")
    return r
end

function _forecast_eval_mincer_zarnowitz(; data::String, actual::String="", forecasts::String="",
                                          lags::Int=0, kernel::String="bartlett",
                                          output::String="", format::String="table")
    y, fnames, fcols = _fceval_load(data, actual, forecasts; leaf="mincer-zarnowitz")
    _fceval_arity(fnames, "mincer-zarnowitz", "exactly 1", length(fnames) == 1)
    _status("Mincer-Zarnowitz efficiency: forecast=$(fnames[1]), lags=$lags, kernel=$kernel")
    _status()
    r = try
        mincer_zarnowitz(y, fcols[1]; lags=lags, kernel=Symbol(kernel))
    catch e
        throw(_fceval_error(e, "Mincer-Zarnowitz test"))
    end
    output_kv(Pair{String,Any}[
        "test"         => "Mincer-Zarnowitz",
        "forecast"     => fnames[1],
        "a"            => round(r.a; digits=6),
        "b"            => round(r.b; digits=6),
        "se_a"         => round(r.se[1]; digits=6),
        "se_b"         => round(r.se[2]; digits=6),
        "wald_chi2"    => round(r.wald; digits=4),
        "p_value_wald" => round(r.pvalue_wald; digits=4),
        "fstat"        => round(r.fstat; digits=4),
        "p_value_f"    => round(r.pvalue_f; digits=4),
        "hac_lags"     => r.lags,
        "kernel"       => string(r.kernel),
        "n"            => r.T_obs,
    ]; format=format, output=output, title="Mincer-Zarnowitz Efficiency Test")
    return r
end

function _forecast_eval_encompassing(; data::String, actual::String="", forecasts::String="",
                                      lags::Int=0, kernel::String="bartlett",
                                      output::String="", format::String="table")
    y, fnames, fcols = _fceval_load(data, actual, forecasts; leaf="encompassing")
    _fceval_arity(fnames, "encompassing", "exactly 2", length(fnames) == 2)
    _status("Forecast encompassing: fc1=$(fnames[1]) fc2=$(fnames[2]), lags=$lags, kernel=$kernel")
    _status()
    r = try
        forecast_encompassing(y, fcols[1], fcols[2]; lags=lags, kernel=Symbol(kernel))
    catch e
        throw(_fceval_error(e, "forecast encompassing test"))
    end
    output_kv(Pair{String,Any}[
        "test"     => "Forecast-Encompassing",
        "model_1"  => fnames[1],
        "model_2"  => fnames[2],
        "b1"       => round(r.b1; digits=6),
        "b2"       => round(r.b2; digits=6),
        "se_b2"    => round(r.se_b2; digits=6),
        "t_stat"   => round(r.tstat; digits=4),
        "p_value"  => round(r.pvalue; digits=4),
        "hac_lags" => r.lags,
        "kernel"   => string(r.kernel),
        "n"        => r.T_obs,
    ]; format=format, output=output, title="Forecast Encompassing Test")
    return r
end

function _forecast_eval_combine(; data::String, actual::String="", forecasts::String="",
                                 method::String="equal", emit_series::Bool=false,
                                 output::String="", format::String="table")
    y, fnames, fcols = _fceval_load(data, actual, forecasts; leaf="combine")
    _fceval_arity(fnames, "combine", "at least 2", length(fnames) >= 2)
    F = reduce(hcat, fcols)
    meth = Symbol(replace(method, "-" => "_"))
    _status("Forecast combination: $(length(fnames)) forecasts, method=$method")
    _status()
    r = try
        combine_forecasts(F, y; method=meth, model_names=fnames)
    catch e
        throw(_fceval_error(e, "forecast combination"))
    end
    # C051 exception: hand-built weights table model | weight | mse (weights sum to 1).
    wtab = DataFrame(model = r.models,
                     weight = round.(r.weights; digits=6),
                     mse = round.(r.mse; digits=6))
    output_result(wtab; format=Symbol(format), output=output, title="Forecast Combination Weights")
    if emit_series
        stab = DataFrame(index = collect(1:length(r.combined)),
                         combined = round.(r.combined; digits=6))
        output_result(stab; format=Symbol(format), output=output, title="Combined Forecast Series")
    end
    return r
end
