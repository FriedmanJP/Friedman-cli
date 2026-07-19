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

# Estimate commands: var, bvar, lp, arima, gmm, smm, static, dynamic, gdfm, arch, garch, egarch, gjr_garch, sv, fastica, ml, favar, sdfm, reg, iv, logit, probit, preg, piv, plogit, pprobit, ologit, oprobit, mlogit

# C044: kebab primary CLI name; snake kept as hidden alias where renamed
const _VOL_CLI_NAMES = Dict("gjr_garch" => ("gjr-garch", ["gjr_garch"]))

"""Generate CommandSpecs for the volatility family (estimate / forecast / predict / residuals)."""
function _vol_specs(verb::Symbol)::Vector{CommandSpec}
    handlers = if verb === :estimate
        _VOL_ESTIMATE_HANDLERS
    elseif verb === :forecast
        _VOL_FORECAST_HANDLERS
    elseif verb === :predict
        _VOL_PREDICT_HANDLERS
    elseif verb === :residuals
        _VOL_RESIDUALS_HANDLERS
    else
        error("unknown vol verb: $verb")
    end
    with_horizons = verb === :forecast
    with_plot = verb === :estimate || verb === :forecast
    order_opts = Dict{Symbol,Vector{OptionSpec}}(
        :q_only => [OptionSpec(name="q", type=Int, default=1, description="ARCH order")],
        :pq => [
            OptionSpec(name="p", type=Int, default=1, description="GARCH order"),
            OptionSpec(name="q", type=Int, default=1, description="ARCH order"),
        ],
        :sv => [OptionSpec(name="draws", short="n", type=Int, default=5000, description="MCMC draws")],
    )
    # estimate/forecast keep historical option order: output before format, then plot-save
    out_opts = if with_plot
        [
            OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
            OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
            OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
        ]
    else
        # predict/residuals: format then output (OUTPUT_OPTIONS order)
        collect(OUTPUT_OPTIONS)
    end
    flags = with_plot ? [FlagSpec(name="plot", description="Open interactive plot in browser")] : FlagSpec[]
    specs = CommandSpec[]
    for vol in VOL_MODELS
        opts = OptionSpec[
            OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
            order_opts[vol.order]...,
        ]
        if with_horizons
            push!(opts, OptionSpec(name="horizons", short="h", type=Int, default=12, description="Forecast horizon"))
        end
        append!(opts, out_opts)
        # predict/residuals historically omit p/q/draws from schema (defaults only)
        if verb === :predict || verb === :residuals
            opts = OptionSpec[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index"),
                OUTPUT_OPTIONS...,
            ]
        end
        cli_name, aliases = get(_VOL_CLI_NAMES, vol.name, (vol.name, String[]))
        push!(specs, CommandSpec(
            path=[string(verb), cli_name],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=opts,
            flags=flags,
            tables=[TableSpec(name=Symbol("$(verb)_$(replace(cli_name, "-" => "_"))"), description="Path to CSV data file")],
            category=string(verb),
            aliases=aliases,
            handler=wrap_legacy(handlers[vol.name]),
        ))
    end
    return specs
end

function estimate_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["estimate", "var"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="trend", type=String, default="constant", description="none|constant|trend|both"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_var, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_var),
        ),
        CommandSpec(
            path=["estimate", "bvar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Lag order"),
                OptionSpec(name="prior", type=String, default="minnesota", description="Prior type: minnesota"),
                OptionSpec(name="draws", short="n", type=Int, default=2000, description="MCMC draws"),
                OptionSpec(name="sampler", type=String, default="direct", description="direct|gibbs"),
                OptionSpec(name="method", type=String, default="mean", description="mean|median (posterior extraction)"),
                OptionSpec(name="config", type=String, default="", description="TOML config for prior hyperparameters"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_bvar, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_bvar),
        ),
        CommandSpec(
            path=["estimate", "lp"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="method", type=String, default="standard", description="standard|iv|smooth|state|propensity|robust"),
                OptionSpec(name="shock", type=Int, default=1, description="Shock variable index (1-based)"),
                OptionSpec(name="horizons", short="h", type=Int, default=20, description="IRF horizon"),
                OptionSpec(name="control-lags", type=Int, default=4, description="Number of control lags"),
                OptionSpec(name="vcov", type=String, default="newey_west", description="newey_west|white|driscoll_kraay"),
                OptionSpec(name="instruments", type=String, default="", description="Path to instruments CSV (iv only)"),
                OptionSpec(name="knots", type=Int, default=3, description="Number of B-spline knots (smooth only)"),
                OptionSpec(name="lambda", type=Float64, default=0.0, description="Smoothing penalty, 0=auto CV (smooth only)"),
                OptionSpec(name="state-var", type=Int, default=nothing, description="State variable index (state only)"),
                OptionSpec(name="gamma", type=Float64, default=1.5, description="Transition steepness (state only)"),
                OptionSpec(name="transition", type=String, default="logistic", description="logistic|exponential|indicator (state only)"),
                OptionSpec(name="treatment", type=Int, default=1, description="Treatment variable index (propensity/robust only)"),
                OptionSpec(name="score-method", type=String, default="logit", description="logit|probit (propensity/robust only)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_lp, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_lp),
        ),
        CommandSpec(
            path=["estimate", "arima"],
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
                OptionSpec(name="criterion", type=String, default="bic", description="aic|bic (for auto selection)"),
                OptionSpec(name="method", short="m", type=String, default="css_mle", description="ols|css|mle|css_mle"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_arima, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_arima),
        ),
        CommandSpec(
            path=["estimate", "gmm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config for moment conditions and instruments"),
                OptionSpec(name="weighting", short="w", type=String, default="twostep", description="identity|optimal|twostep|iterated"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_gmm, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_gmm),
        ),
        CommandSpec(
            path=["estimate", "static"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of factors (default: auto via IC)"),
                OptionSpec(name="criterion", type=String, default="ic1", description="ic1|ic2|ic3 for auto selection"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:estimate_static, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_static),
        ),
        CommandSpec(
            path=["estimate", "dynamic"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
                OptionSpec(name="factor-lags", short="p", type=Int, default=1, description="Factor VAR lag order"),
                OptionSpec(name="method", type=String, default="twostep", description="twostep|em"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:estimate_dynamic, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_dynamic),
        ),
        CommandSpec(
            path=["estimate", "gdfm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of static factors (default: auto)"),
                OptionSpec(name="dynamic-rank", short="q", type=Int, default=nothing, description="Dynamic rank (default: auto)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_gdfm, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_gdfm),
        ),
        # Volatility 20-plex (estimate side): generated from VOL_MODELS
        _vol_specs(:estimate)...,
        CommandSpec(
            path=["estimate", "fastica"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="method", type=String, default="fastica", description="fastica|jade|sobi|dcov|hsic"),
                OptionSpec(name="contrast", type=String, default="logcosh", description="logcosh|exp|kurtosis (for FastICA)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_fastica, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_fastica),
        ),
        CommandSpec(
            path=["estimate", "ml"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="distribution", short="d", type=String, default="student_t", description="student_t|skew_t|ghd|mixture_normal|pml|skew_normal"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_ml, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ml),
        ),
        CommandSpec(
            path=["estimate", "pvar"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column (required)"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column (required)"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="Lag order"),
                OptionSpec(name="dependent", type=String, default="", description="Dependent variables (comma-separated)"),
                OptionSpec(name="predet", type=String, default="", description="Predetermined variables (comma-separated)"),
                OptionSpec(name="exog", type=String, default="", description="Exogenous variables (comma-separated)"),
                OptionSpec(name="transformation", type=String, default="fd", description="fd|fod (first-difference or forward orthogonal)"),
                OptionSpec(name="steps", type=String, default="twostep", description="onestep|twostep"),
                OptionSpec(name="method", type=String, default="gmm", description="gmm|feols"),
                OptionSpec(name="min-lag-endo", type=Int, default=2, description="Minimum lag for endogenous instruments"),
                OptionSpec(name="max-lag-endo", type=Int, default=99, description="Maximum lag for endogenous instruments"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[
                FlagSpec(name="system", description="Use system GMM (adds level equations)"),
                FlagSpec(name="collapse", description="Collapse instruments to limit count")
            ],
            tables=[TableSpec(name=:estimate_pvar, description="Path to CSV panel data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_pvar),
        ),
        CommandSpec(
            path=["estimate", "vecm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels, VECM uses p-1)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="method", type=String, default="johansen", description="johansen|engle_granger"),
                OptionSpec(name="significance", type=Float64, default=0.05, description="Significance level for rank selection"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_vecm, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_vecm),
        ),
        CommandSpec(
            path=["estimate", "smm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config for SMM specification"),
                OptionSpec(name="weighting", type=String, default="two_step", description="identity|optimal|two_step|iterated"),
                OptionSpec(name="sim-ratio", type=Int, default=5, description="Simulation-to-sample ratio"),
                OptionSpec(name="burn", type=Int, default=100, description="Burn-in periods"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_smm, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_smm),
        ),
        CommandSpec(
            path=["estimate", "favar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="r", type=Int, default=nothing, description="Number of factors (default: auto via IC)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="VAR lag order"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variable names or indices (comma-separated)"),
                OptionSpec(name="method", type=String, default="two_step", description="two_step|bayesian"),
                OptionSpec(name="draws", short="n", type=Int, default=5000, description="MCMC draws (bayesian only)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:estimate_favar, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_favar),
        ),
        CommandSpec(
            path=["estimate", "sdfm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="q", type=Int, default=nothing, description="Number of dynamic factors (default: auto)"),
                OptionSpec(name="id", type=String, default="cholesky", description="cholesky|sign"),
                OptionSpec(name="var-lags", type=Int, default=1, description="Factor VAR lag order"),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="Structural IRF horizon"),
                OptionSpec(name="config", type=String, default="", description="TOML config for sign restrictions"),
                OptionSpec(name="bandwidth", type=Int, default=0, description="Spectral bandwidth (0=auto)"),
                OptionSpec(name="kernel", type=String, default="bartlett", description="bartlett|parzen|quadratic_spectral"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:estimate_sdfm, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_sdfm),
        ),
        CommandSpec(
            path=["estimate", "reg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...,
                OptionSpec(name="weights", type=String, default="", description="Weight column name (WLS)")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_reg, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_reg),
        ),
        CommandSpec(
            path=["estimate", "iv"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="endogenous", type=String, default="", description="Endogenous column names, comma-separated (required)"),
                OptionSpec(name="instruments", type=String, default="", description="Instrument column names, comma-separated (required)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="ols|hc0|hc1|hc2|hc3"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_iv, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_iv),
        ),
        CommandSpec(
            path=["estimate", "logit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...,
                OptionSpec(name="maxiter", type=Int, default=100, description="Maximum IRLS iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-8, description="Convergence tolerance")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_logit, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_logit),
        ),
        CommandSpec(
            path=["estimate", "probit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...,
                OptionSpec(name="maxiter", type=Int, default=100, description="Maximum IRLS iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-8, description="Convergence tolerance")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_probit, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_probit),
        ),
        CommandSpec(
            path=["estimate", "preg"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                PREG_OPTIONS...
            ],
            flags=[
                FlagSpec(name="twoway", description="Include time fixed effects")
            ],
            tables=[TableSpec(name=:estimate_preg, description="Path to CSV panel data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_preg),
        ),
        CommandSpec(
            path=["estimate", "piv"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name"),
                OptionSpec(name="exog", type=String, default="", description="Exogenous variables (comma-separated)"),
                OptionSpec(name="endog", type=String, default="", description="Endogenous variables (comma-separated)"),
                OptionSpec(name="instruments", type=String, default="", description="Instruments (comma-separated)"),
                OptionSpec(name="method", short="m", type=String, default="fe", description="fe|re|fd|hausman-taylor"),
                OptionSpec(name="cov-type", type=String, default="cluster", description="ols|cluster|twoway|driscoll-kraay"),
                OptionSpec(name="id-col", type=String, default="", description="Panel group ID column"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_piv, description="Path to CSV panel data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_piv),
        ),
        CommandSpec(
            path=["estimate", "plogit"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=with_default(PREG_OPTIONS, "method", "pooled"),
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_plogit, description="Path to CSV panel data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_plogit),
        ),
        CommandSpec(
            path=["estimate", "pprobit"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=with_default(PREG_OPTIONS, "method", "pooled"),
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_pprobit, description="Path to CSV panel data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_pprobit),
        ),
        CommandSpec(
            path=["estimate", "ologit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_ologit, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ologit),
        ),
        CommandSpec(
            path=["estimate", "oprobit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_oprobit, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_oprobit),
        ),
        CommandSpec(
            path=["estimate", "mlogit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name"),
                OptionSpec(name="cov-type", type=String, default="ols", description="ols|hc0|hc1|hc2|hc3"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_mlogit, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_mlogit),
        )
    ]
end

function register_estimate_commands!()
    specs = with_config_ergonomics(with_save_model(estimate_specs()))
    register!(specs)
    return build_node("estimate", specs; description="Model estimation")
end


# ── VAR ────────────────────────────────────────────────────

function _estimate_var(; data::String, lags=nothing, trend::String="constant",
                        output::String="", format::String="table")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    p = if isnothing(lags)
        select_lag_order(Y, min(12, size(Y,1) ÷ (3*n)); criterion=:aic)
    else
        lags
    end

    _status("Estimating VAR($p) with $n variables: $(join(varnames, ", "))")
    _status("Trend: $trend, Observations: $(size(Y, 1))")
    _status()

    model = estimate_var(Y, p)
    _status_report(() -> report(model))

    # C051: MEMs renders coefficient-bearing models as a tidy coef table via Tables.jl
    # (equation|term|estimate|std_error|stat|p_value|ci_lower|ci_upper).
    output_result(DataFrame(model); format=Symbol(format), output=output, title="VAR($p) Coefficients")

    _status()
    output_model_criteria(model; format=format, title="Information Criteria")
    return model
end

# ── BVAR ───────────────────────────────────────────────────

function _estimate_bvar(; data::String, lags::Int=4, prior::String="minnesota",
                         draws::Int=2000, sampler::String="direct", method::String="mean",
                         config::String="", output::String="", format::String="table")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)
    p = lags

    _status("Estimating Bayesian VAR($p) with $n variables: $(join(varnames, ", "))")
    _status("Prior: $prior, Sampler: $sampler, Draws: $draws, Posterior: $method")
    _status()

    prior_obj = _build_prior(config, Y, p)
    prior_sym = isnothing(prior_obj) ? Symbol(prior) : :minnesota

    post = estimate_bvar(Y, p;
        sampler=Symbol(sampler), n_draws=draws,
        prior=prior_sym, hyper=prior_obj)

    model = if method == "median"
        posterior_median_model(post)
    else
        posterior_mean_model(post)
    end

    _status_report(() -> report(model))

    coef_df = _build_var_coef_table(coef(model), varnames, p)
    output_result(coef_df; format=Symbol(format), output=output,
                  title="BVAR($p) Posterior $(titlecase(method)) Coefficients")

    _status()
    output_model_criteria(model; format=format, title="Information Criteria (Posterior $(titlecase(method)))")
    return model
end

# ── LP ─────────────────────────────────────────────────────

function _estimate_lp(; data::String, method::String="standard", shock::Int=1,
                       horizons::Int=20, control_lags::Int=4, vcov::String="newey_west",
                       instruments::String="", knots::Int=3, lambda::Float64=0.0,
                       state_var=nothing, gamma::Float64=1.5, transition::String="logistic",
                       treatment::Int=1, score_method::String="logit",
                       output::String="", format::String="table")
    validate_method(method, ["standard", "iv", "smooth", "state", "propensity", "robust"], "LP method")
    if method == "standard"
        return _estimate_lp_standard(data, shock, horizons, control_lags, vcov, output, format)
    elseif method == "iv"
        return _estimate_lp_iv(data, shock, horizons, control_lags, vcov, instruments, output, format)
    elseif method == "smooth"
        return _estimate_lp_smooth(data, shock, horizons, knots, lambda, output, format)
    elseif method == "state"
        return _estimate_lp_state(data, shock, horizons, state_var, gamma, transition, output, format)
    elseif method == "propensity"
        return _estimate_lp_propensity(data, treatment, horizons, score_method, output, format)
    elseif method == "robust"
        return _estimate_lp_robust(data, treatment, horizons, score_method, output, format)
    end
end

"""Output LP coefficient table: shock coefficients + SEs per horizon per response variable."""
function _output_lp_coef_table(irf_result, varnames, horizons;
                               title::String="", format::String="table", output::String="")
    n_h = size(irf_result.values, 1)
    n_resp = size(irf_result.values, 2)
    has_se = hasproperty(irf_result, :se) && !isnothing(irf_result.se) &&
             size(irf_result.se) == size(irf_result.values)

    coef_df = DataFrame()
    coef_df.Horizon = 0:(n_h - 1)
    for vi in 1:n_resp
        vname = vi <= length(varnames) ? varnames[vi] : "var_$vi"
        coeffs = irf_result.values[:, vi]
        coef_df[!, Symbol(vname)] = round.(coeffs; digits=6)
        if has_se
            ses = irf_result.se[:, vi]
            tstats = coeffs ./ ses
            coef_df[!, Symbol("$(vname)_se")] = round.(ses; digits=6)
            coef_df[!, Symbol("$(vname)_t")] = round.(tstats; digits=3)
        end
    end

    output_result(coef_df; format=Symbol(format), output=output, title=title)
end

function _estimate_lp_standard(data, shock, horizons, control_lags, vcov, output, format)
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)
    shock_name = _shock_name(varnames, shock)

    _status("Estimating Local Projections: method=standard")
    _status("  Shock: $shock_name, Horizons: $horizons, Lags: $control_lags, VCov: $vcov")
    _status("  Variables: $(join(varnames, ", "))")
    _status()

    model = estimate_lp(Y, shock, horizons; lags=control_lags, cov_type=Symbol(vcov))
    irf_result = lp_irf(model)

    _output_lp_coef_table(irf_result, varnames, horizons;
        title="LP Coefficients ($shock_name → responses)", format=format, output=output)

    _status()
    output_kv(Pair{String,Any}[
        "Effective observations" => model.T_eff,
        "Covariance estimator" => vcov,
        "Horizons" => horizons,
        "Control lags" => control_lags,
    ]; format=format, title="Estimation Summary")
    return model
end

function _estimate_lp_iv(data, shock, horizons, control_lags, vcov, instruments, output, format)
    isempty(instruments) && error("LP-IV requires --instruments=<file.csv>")

    Y, varnames = load_multivariate_data(data)
    Z, _ = load_multivariate_data(instruments)
    n = size(Y, 2)
    shock_name = _shock_name(varnames, shock)

    _status("Estimating LP-IV: shock=$shock_name, horizons=$horizons, instruments=$(size(Z, 2))")
    _status()

    model = estimate_lp_iv(Y, shock, Z, horizons; lags=control_lags, cov_type=Symbol(vcov))

    # First-stage diagnostics
    wi = weak_instrument_test(model)
    _status("First-stage diagnostics:")
    _status("  F-statistic: $(round(wi.F_stat; digits=2))")
    if wi.F_stat < 10
        _status_styled("  Warning: Weak instruments (F < 10)\n"; color=:yellow)
    else
        _status_styled("  Instruments appear strong (F >= 10)\n"; color=:green)
    end
    _status()

    irf_result = lp_iv_irf(model)

    _output_lp_coef_table(irf_result, varnames, horizons;
        title="LP-IV Coefficients ($shock_name → responses)", format=format, output=output)

    _status()
    output_kv(Pair{String,Any}[
        "Effective observations" => model.T_eff,
        "Covariance estimator" => vcov,
        "First-stage F" => round(wi.F_stat; digits=2),
        "Instruments" => size(Z, 2),
    ]; format=format, title="LP-IV Estimation Summary")
    return model
end

function _estimate_lp_smooth(data, shock, horizons, knots, lambda, output, format)
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    lam = if lambda == 0.0
        _status("Cross-validating smoothing parameter...")
        cross_validate_lambda(Y, shock, horizons)
    else
        lambda
    end

    shock_name = _shock_name(varnames, shock)
    _status("Estimating Smooth LP: shock=$shock_name, horizons=$horizons, knots=$knots, λ=$(round(lam; digits=4))")
    _status()

    model = estimate_smooth_lp(Y, shock, horizons; n_knots=knots, lambda=lam)
    irf_result = smooth_lp_irf(model)

    _output_lp_coef_table(irf_result, varnames, horizons;
        title="Smooth LP Coefficients ($shock_name → responses)", format=format, output=output)

    _status()
    output_kv(Pair{String,Any}[
        "Smoothing parameter (λ)" => round(lam; digits=6),
        "B-spline knots" => knots,
        "Horizons" => horizons,
    ]; format=format, title="Smooth LP Estimation Summary")
    return model
end

function _estimate_lp_state(data, shock, horizons, state_var, gamma, transition, output, format)
    isnothing(state_var) && error("state-dependent LP requires --state-var=<idx>")

    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)
    shock_name = _shock_name(varnames, shock)
    state_name = _var_name(varnames, state_var)

    _status("Estimating State-Dependent LP: shock=$shock_name, state=$state_name, γ=$gamma, transition=$transition")
    _status()

    state_vec = Y[:, state_var]
    model = estimate_state_lp(Y, shock, state_vec, horizons; gamma=gamma)
    results = state_irf(model)

    for (regime, label) in [(:expansion, "Expansion"), (:recession, "Recession")]
        irf_result = getfield(results, regime)
        _output_lp_coef_table(irf_result, varnames, horizons;
            title="State LP Coefficients — $label ($shock_name → responses)",
            format=format,
            output=isempty(output) ? "" : replace(output, "." => "_$(lowercase(label))."))
        _status()
    end

    diff_test = test_regime_difference(model)
    jt = diff_test.joint_test
    _status("Regime Difference Test:")
    _status("  Avg t-statistic: $(round(jt.avg_t_stat; digits=3))")
    _status("  p-value: $(round(jt.p_value; digits=4))")
    if jt.p_value < 0.05
        _status_styled("  → Significant regime differences at 5%\n"; color=:green)
    else
        _status_styled("  → No significant regime differences at 5%\n"; color=:yellow)
    end
    return model
end

function _estimate_lp_propensity(data, treatment, horizons, score_method, output, format)
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)
    treat_name = _var_name(varnames, treatment)

    _status("Estimating Propensity Score LP: treatment=$treat_name, horizons=$horizons, method=$score_method")
    _status()

    treatment_bool = Bool.(Y[:, treatment] .> median(Y[:, treatment]))
    covariates = Y[:, setdiff(1:size(Y,2), [treatment])]

    model = estimate_propensity_lp(Y, treatment_bool, covariates, horizons;
        ps_method=Symbol(score_method))

    # Propensity score diagnostics
    diag = propensity_diagnostics(model)
    ps = diag.propensity_summary
    _status("Propensity Score Diagnostics:")
    _status("  Treated mean score: $(round(ps.treated.mean; digits=4))")
    _status("  Control mean score: $(round(ps.control.mean; digits=4))")
    _status("  Max weighted SMD: $(round(diag.balance.max_weighted; digits=4))")
    _status()

    irf_result = propensity_irf(model)

    _output_lp_coef_table(irf_result, varnames, horizons;
        title="Propensity Score LP: ATE Estimates ($treat_name)", format=format, output=output)
    return model
end

function _estimate_lp_robust(data, treatment, horizons, score_method, output, format)
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)
    treat_name = _var_name(varnames, treatment)

    _status("Estimating Doubly Robust LP: treatment=$treat_name, horizons=$horizons, method=$score_method")
    _status()

    treatment_bool = Bool.(Y[:, treatment] .> median(Y[:, treatment]))
    covariates = Y[:, setdiff(1:size(Y,2), [treatment])]

    model = doubly_robust_lp(Y, treatment_bool, covariates, horizons;
        ps_method=Symbol(score_method))

    # Diagnostics
    diag = propensity_diagnostics(model)
    ps = diag.propensity_summary
    _status("Doubly Robust Diagnostics:")
    _status("  Treated mean score: $(round(ps.treated.mean; digits=4))")
    _status("  Control mean score: $(round(ps.control.mean; digits=4))")
    _status("  Max weighted SMD: $(round(diag.balance.max_weighted; digits=4))")
    _status()

    irf_result = propensity_irf(model)

    _output_lp_coef_table(irf_result, varnames, horizons;
        title="Doubly Robust LP: ATE Estimates ($treat_name)", format=format, output=output)
    return model
end

# ── ARIMA ──────────────────────────────────────────────────

function _estimate_arima(; data::String, column::Int=1, p=nothing, d::Int=0, q::Int=0,
                          max_p::Int=5, max_d::Int=2, max_q::Int=5,
                          criterion::String="bic", method::String="css_mle",
                          format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    method_sym = Symbol(method)
    safe_method = method_sym == :css_mle ? :mle : method_sym

    model = if isnothing(p)
        crit_sym = Symbol(lowercase(criterion))
        _status("Auto ARIMA: variable=$vname, observations=$(length(y))")
        _status("  Search: p=0:$max_p, d=0:$max_d, q=0:$max_q, criterion=$criterion, method=$method")
        _status()
        m = auto_arima(y; max_p=max_p, max_q=max_q, max_d=max_d, criterion=crit_sym, method=safe_method)
        label = _model_label(ar_order(m), diff_order(m), ma_order(m))
        _status_styled("Selected model: $label\n"; bold=true)
        _status()
        m
    else
        label = _model_label(p, d, q)
        _status("Estimating $label: variable=$vname, observations=$(length(y)), method=$method")
        _status()
        _estimate_arima_model(y, p, d, q; method=method_sym)
    end

    p_sel = ar_order(model)
    d_sel = diff_order(model)
    q_sel = ma_order(model)
    label = _model_label(p_sel, d_sel, q_sel)

    _arima_coef_table(model; format=format, output=output, title="$label Coefficients ($vname)")

    _status()
    output_kv(Pair{String,Any}[
        "AIC" => round(aic(model); digits=4),
        "BIC" => round(bic(model); digits=4),
        "Log-likelihood" => round(loglikelihood(model); digits=4),
    ]; format=format, title="Information Criteria")
    return model
end

# ARIMA helpers (from old arima.jl)
function _estimate_arima_model(y::Vector{Float64}, p::Int, d::Int, q::Int; method::Symbol=:css_mle)
    if d == 0 && q == 0
        ar_method = method in (:ols, :mle) ? method : :mle
        return estimate_ar(y, p; method=ar_method)
    elseif d == 0 && p == 0
        return estimate_ma(y, q; method=method)
    elseif d == 0
        return estimate_arma(y, p, q; method=method)
    else
        return estimate_arima(y, p, d, q; method=method)
    end
end

function _model_label(p::Int, d::Int, q::Int)
    if d == 0 && q == 0
        return "AR($p)"
    elseif d == 0 && p == 0
        return "MA($q)"
    elseif d == 0
        return "ARMA($p,$q)"
    else
        return "ARIMA($p,$d,$q)"
    end
end

function _arima_coef_table(model; format::String="table", output::String="", title::String="Coefficients")
    c = coef(model)
    p_order = ar_order(model)
    q_order = ma_order(model)
    param_names = String[]
    for i in 1:p_order
        push!(param_names, "ar$i")
    end
    for i in 1:q_order
        push!(param_names, "ma$i")
    end
    n_named = p_order + q_order
    for i in (n_named+1):length(c)
        push!(param_names, "const$i")
    end

    coef_df = try
        se = stderror(model)
        z = c ./ se
        pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
        DataFrame(parameter=param_names, estimate=round.(c; digits=6),
                  std_error=round.(se; digits=6),
                  z_stat=round.(z; digits=3), p_value=round.(pv; digits=4))
    catch
        DataFrame(parameter=param_names, estimate=round.(c; digits=6))
    end

    output_result(coef_df; format=Symbol(format), output=output, title=title)
end

# ── GMM ────────────────────────────────────────────────────

function _estimate_gmm(; data::String, config::String="",
                        weighting::String="twostep",
                        output::String="", format::String="table")
    isempty(config) && error("GMM requires a --config=<file.toml> specifying moment conditions and instruments")

    Y, varnames = load_multivariate_data(data)

    cfg = load_config(config)
    gmm_cfg = get_gmm(cfg)

    weighting_map = Dict("identity" => :identity, "optimal" => :optimal,
                         "twostep" => :two_step, "iterated" => :iterated)
    w = get(weighting_map, lowercase(weighting), :two_step)

    _status("Estimating GMM: weighting=$weighting")
    _status("  Moment conditions: $(length(gmm_cfg["moment_conditions"]))")
    _status()

    moment_cols = gmm_cfg["moment_conditions"]
    shock_var = if !isempty(moment_cols)
        idx = findfirst(==(moment_cols[1]), varnames)
        isnothing(idx) ? 1 : idx
    else
        1
    end

    models = estimate_lp_gmm(Y, shock_var, 0; lags=4, weighting=w)

    if !isempty(models)
        model = models[1]
        summ = gmm_summary(model)
        jtest = j_test(model)
        _status()
        _status("Hansen's J-test for overidentification:")
        _status("  J-statistic: $(round(jtest.J_stat; digits=4))")
        _status("  p-value: $(round(jtest.p_value; digits=4))")
        _status("  Degrees of freedom: $(jtest.df)")

        if jtest.p_value < 0.05
            _status_styled("  -> Reject valid moment conditions at 5%\n"; color=:yellow)
        else
            _status_styled("  -> Cannot reject valid moment conditions\n"; color=:green)
        end

        if !isempty(output)
            se = stderror(model)
            param_df = DataFrame(parameter=["theta$i" for i in 1:length(model.theta)],
                                 estimate=model.theta, std_error=se)
            output_result(param_df; format=Symbol(format), output=output, title="GMM Estimates")
        end
        return model
    end
end

# ── Factor Models ──────────────────────────────────────────

function _estimate_static(; data::String, nfactors=nothing, criterion::String="ic1",
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    X, varnames = load_multivariate_data(data)

    r = if isnothing(nfactors)
        _status("Selecting number of factors via Bai-Ng information criteria...")
        ic = ic_criteria(X, min(20, size(X, 2)))
        r_sym = Symbol("r_", uppercase(criterion))
        optimal_r = getfield(ic, r_sym)
        _status("  $criterion suggests $optimal_r factors")
        optimal_r
    else
        nfactors
    end

    _status("Estimating static factor model: $r factors, $(size(X, 2)) variables, $(size(X, 1)) observations")
    _status()

    model = estimate_factors(X, r)
    _maybe_plot(model; plot=plot, plot_save=plot_save)

    scree = scree_plot_data(model)
    scree_df = DataFrame(component=scree.factors, eigenvalue=scree.explained_variance,
                         cumulative=scree.cumulative_variance)
    output_result(scree_df; format=Symbol(format), title="Scree Data (Eigenvalues & Variance Shares)")
    _status()

    loadings = model.loadings
    loading_df = DataFrame(loadings, ["F$i" for i in 1:r])
    insertcols!(loading_df, 1, :variable => varnames)
    output_result(loading_df; format=Symbol(format), output=output, title="Factor Loadings")
    return model
end

function _estimate_dynamic(; data::String, nfactors=nothing, factor_lags::Int=1,
                            method::String="twostep", output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
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

    _status("Estimating dynamic factor model: $r factors, $factor_lags lags, method=$method")
    _status()

    model = estimate_dynamic_factors(X, r, factor_lags; method=Symbol(method))
    _maybe_plot(model; plot=plot, plot_save=plot_save)

    stable_result = is_stationary(model)
    stable = stable_result isa Bool ? stable_result : stable_result.is_stationary
    if stable
        _status_styled("Factor VAR is stationary\n"; color=:green)
    else
        _status_styled("Factor VAR is not stationary\n"; color=:yellow)
    end
    _status()

    loadings = model.loadings
    loading_df = DataFrame(loadings, ["F$i" for i in 1:r])
    insertcols!(loading_df, 1, :variable => varnames)
    output_result(loading_df; format=Symbol(format), output=output, title="Dynamic Factor Loadings")

    _status()
    _status("Factor VAR Companion Matrix eigenvalues:")
    comp = companion_matrix_factors(model)
    eig_moduli = abs.(eigvals(comp))
    for (i, ev) in enumerate(sort(eig_moduli; rev=true))
        _status("  lambda$i = $(round(ev; digits=6))")
    end
    return model
end

function _estimate_gdfm(; data::String, nfactors=nothing, dynamic_rank=nothing,
                         output::String="", format::String="table")
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

    _status("Estimating GDFM: static rank=$r, dynamic rank=$q")
    _status()

    model = estimate_gdfm(X, q; r=r)

    var_shares = common_variance_share(model)
    var_df = DataFrame(variable=varnames, common_variance_share=round.(var_shares; digits=4))
    output_result(var_df; format=Symbol(format), output=output,
                  title="GDFM Common Variance Shares")

    _status()
    _status("Average common variance share: $(round(mean(var_shares); digits=4))")
    return model
end

# Volatility estimate handlers live in shared.jl (VOL_MODELS / _VOL_ESTIMATE_HANDLERS).

# ── Non-Gaussian ICA ──────────────────────────────────────

function _estimate_fastica(; data::String, lags=nothing, method::String="fastica",
                             contrast::String="logcosh", output::String="", format::String="table")
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)

    _status("Non-Gaussian SVAR: method=$method, contrast=$contrast, VAR($p), $n variables")
    _status()

    result = if method == "jade"
        identify_jade(model)
    elseif method == "sobi"
        identify_sobi(model)
    elseif method == "dcov"
        identify_dcov(model)
    elseif method == "hsic"
        identify_hsic(model)
    else
        identify_fastica(model; contrast=Symbol(contrast))
    end

    if hasproperty(result, :converged)
        if result.converged
            _status_styled("Converged in $(result.iterations) iterations\n"; color=:green)
        else
            _status_styled("Did not converge after $(result.iterations) iterations\n"; color=:yellow)
        end
    end
    _status()

    b0_df = DataFrame(result.B0, varnames)
    insertcols!(b0_df, 1, :equation => varnames)
    output_result(b0_df; format=Symbol(format), title="Structural Impact Matrix (B0)")
    _status()

    shocks = result.shocks
    T_shocks = size(shocks, 1)
    n_show = min(T_shocks, 10)
    shock_df = DataFrame(shocks[1:n_show, :], ["shock_$i" for i in 1:n])
    insertcols!(shock_df, 1, :t => 1:n_show)
    output_result(shock_df; format=Symbol(format), output=output,
                  title="Structural Shocks (first $n_show observations)")
    return result
end

# ── Non-Gaussian ML ───────────────────────────────────────

function _estimate_ml(; data::String, lags=nothing, distribution::String="student_t",
                        output::String="", format::String="table")
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)

    _status("Non-Gaussian ML SVAR: distribution=$distribution, VAR($p), $n variables")
    _status()

    result = if distribution == "mixture_normal"
        identify_mixture_normal(model)
    elseif distribution == "pml"
        identify_pml(model)
    elseif distribution == "skew_normal"
        identify_skew_normal(model)
    else
        identify_nongaussian_ml(model; distribution=Symbol(distribution))
    end

    b0_df = DataFrame(result.B0, varnames)
    insertcols!(b0_df, 1, :equation => varnames)
    output_result(b0_df; format=Symbol(format), title="Structural Impact Matrix (B0)")
    _status()

    output_kv(Pair{String,Any}[
        "Log-likelihood" => round(result.loglik; digits=4),
        "Log-likelihood (Gaussian)" => round(result.loglik_gaussian; digits=4),
        "AIC" => round(result.aic; digits=4),
        "BIC" => round(result.bic; digits=4),
        "Distribution" => string(result.distribution),
    ]; format=format, title="Model Fit")

    if !isempty(result.dist_params)
        _status()
        _status("Distribution parameters:")
        for (k, v) in pairs(result.dist_params)
            if v isa AbstractArray
                _status("  $k = $(round.(v; digits=4))")
            else
                _status("  $k = $(round(v; digits=4))")
            end
        end
    end

    if !isnothing(result.se) && length(result.se) > 0
        _status()
        se_df = DataFrame(
            parameter=["B0[$i,$j]" for i in 1:n for j in 1:n],
            estimate=vec(result.B0),
            std_error=result.se[1:min(length(result.se), n*n)]
        )
        output_result(se_df; format=Symbol(format), output=output,
                      title="Parameter Estimates with Standard Errors")
    end
    return result
end

# ── VECM ─────────────────────────────────────────────────

function _estimate_vecm(; data::String, lags::Int=2, rank::String="auto",
                          deterministic::String="constant", method::String="johansen",
                          significance::Float64=0.05,
                          output::String="", format::String="table")
    vecm, Y, varnames, p = _load_and_estimate_vecm(data, lags, rank, deterministic, method, significance)
    n = size(Y, 2)
    r = cointegrating_rank(vecm)

    _status("Estimating VECM($(p-1)) with $n variables: $(join(varnames, ", "))")
    _status("Cointegration rank: $r, Deterministic: $deterministic, Method: $method")
    _status("Observations: $(size(Y, 1))")
    _status()

    _status_report(() -> report(vecm))

    # Cointegrating vectors (beta)
    beta_df = DataFrame(vecm.beta, ["CV$i" for i in 1:r])
    insertcols!(beta_df, 1, :variable => varnames)
    output_result(beta_df; format=Symbol(format), output=output, title="Cointegrating Vectors (beta)")
    _status()

    # Adjustment coefficients (alpha)
    alpha_df = DataFrame(vecm.alpha, ["CV$i" for i in 1:r])
    insertcols!(alpha_df, 1, :equation => varnames)
    output_result(alpha_df; format=Symbol(format), output=output, title="Adjustment Coefficients (alpha)")
    _status()

    output_kv(Pair{String,Any}[
        "AIC" => round(vecm.aic; digits=4),
        "BIC" => round(vecm.bic; digits=4),
        "HQC" => round(vecm.hqic; digits=4),
        "Log-likelihood" => round(loglikelihood(vecm); digits=4),
    ]; format=format, title="Information Criteria")
    return vecm
end

# ── Panel VAR ─────────────────────────────────────────────

function _estimate_pvar(; data::String, id_col::String="", time_col::String="",
                         lags::Int=1, dependent::String="", predet::String="", exog::String="",
                         transformation::String="fd", steps::String="twostep",
                         method::String="gmm", system::Bool=false, collapse::Bool=false,
                         min_lag_endo::Int=2, max_lag_endo::Int=99,
                         output::String="", format::String="table")
    isempty(id_col) && error("Panel VAR requires --id-col to specify the group identifier column")
    isempty(time_col) && error("Panel VAR requires --time-col to specify the time period column")
    validate_method(method, ["gmm", "feols"], "PVAR estimation method")
    validate_method(transformation, ["fd", "fod"], "PVAR transformation")
    validate_method(steps, ["onestep", "twostep"], "PVAR steps")

    model, panel, varnames = _load_and_estimate_pvar(data, id_col, time_col, lags;
        method=method, transformation=transformation, steps=steps,
        system=system, collapse=collapse,
        dependent=dependent, predet=predet, exog=exog,
        min_lag_endo=min_lag_endo, max_lag_endo=max_lag_endo)

    n = length(varnames)
    p = lags

    _status("Estimating Panel VAR($p) with $n variables: $(join(varnames, ", "))")
    _status("  Method: $method, Transformation: $transformation, Steps: $steps")
    _status("  Groups: $(panel.n_groups), Observations: $(panel.T_obs)")
    if system
        _status("  System GMM (level + difference equations)")
    end
    if collapse
        _status("  Instruments collapsed")
    end
    _status()

    _status_report(() -> report(model))

    coef_df = _build_pvar_coef_table(model, varnames, p)
    output_result(coef_df; format=Symbol(format), output=output,
                  title="Panel VAR($p) Coefficients ($method)")

    _status()
    output_kv(Pair{String,Any}[
        "Groups" => panel.n_groups,
        "Total observations" => panel.T_obs,
        "Instruments" => model.n_instruments,
        "Method" => string(model.method),
        "Transformation" => string(model.transformation),
    ]; format=format, title="Panel Summary")
    return model
end

# ── SMM ───────────────────────────────────────────────────

function _estimate_smm(; data::String, config::String="",
                        weighting::String="two_step", sim_ratio::Int=5,
                        burn::Int=100,
                        output::String="", format::String="table")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    # Load config overrides if provided
    if !isempty(config)
        cfg = load_config(config)
        smm_cfg = get_smm(cfg)
        weighting = smm_cfg["weighting"]
        sim_ratio = smm_cfg["sim_ratio"]
        burn = smm_cfg["burn"]
    end

    _status("Estimating SMM: $n variables, weighting=$weighting, sim_ratio=$sim_ratio")
    _status()

    # Compute sample moments
    moments = autocovariance_moments(Y; lags=1)
    theta0 = zeros(Float64, n)

    moment_fn(theta, data) = autocovariance_moments(data; lags=1) .- moments

    model = estimate_smm(moment_fn, theta0, Y;
                         weighting=Symbol(weighting), sim_ratio=sim_ratio, burn=burn)

    se = sqrt.(abs.(diag(model.vcov)))
    t_stats = model.theta ./ se
    p_vals = [2.0 * (1.0 - _normal_cdf(abs(t))) for t in t_stats]

    est_df = DataFrame(
        parameter = ["param_$i" for i in 1:length(model.theta)],
        estimate = round.(model.theta; digits=6),
        std_error = round.(se; digits=6),
        t_stat = round.(t_stats; digits=4),
        p_value = round.(p_vals; digits=4),
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="SMM Estimation (weighting=$weighting, sim_ratio=$sim_ratio)")

    _status()
    _status_styled("  J-statistic: $(round(model.J_stat; digits=4))\n"; color=:cyan)
    _status_styled("  J p-value:   $(round(model.J_pvalue; digits=4))\n"; color=:cyan)
    _status_styled("  Converged:   $(model.converged)\n";
                color = model.converged ? :green : :red)
    return model
end

# ── FAVAR ──────────────────────────────────────────────

function _estimate_favar(; data::String, factors=nothing, lags::Int=2,
                          key_vars::String="", method::String="two_step",
                          draws::Int=5000, output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, method, draws)

    if favar isa MacroEconometricModels.BayesianFAVAR
        _status("Bayesian FAVAR: $(favar.n_factors) factors, $(favar.n_key) key vars, $(favar.n_draws) draws")
        pairs = Pair{String,Any}[
            "Factors" => favar.n_factors,
            "Key variables" => favar.n_key,
            "Lags" => favar.p,
            "MCMC draws" => favar.n_draws,
        ]
        output_kv(pairs; format=format, output=output, title="Bayesian FAVAR")
        return favar
    end

    var_model = to_var(favar)
    coef_df = _build_var_coef_table(coef(var_model), favar.varnames, favar.p)
    output_result(coef_df; format=Symbol(format), output=output, title="FAVAR($lags) Coefficients")

    _status()
    _status_styled("  Factors: $(favar.n_factors), Key variables: $(favar.n_key)\n"; color=:cyan)
    _status_styled("  AIC: $(round(favar.aic; digits=2)), BIC: $(round(favar.bic; digits=2))\n"; color=:cyan)

    _maybe_plot(favar; plot=plot, plot_save=plot_save)
    return favar
end

# ── Structural DFM ────────────────────────────────────

function _estimate_sdfm(; data::String, factors=nothing, id::String="cholesky",
                         var_lags::Int=1, horizon::Int=40,
                         config::String="", bandwidth::Int=0,
                         kernel::String="bartlett",
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    q = if factors === nothing
        auto_q = ic_criteria_gdfm(Y, min(10, n - 1))
        _status_styled("  Auto-selected dynamic factors: $(auto_q.q_opt)\n"; color=:cyan)
        auto_q.q_opt
    else
        factors
    end

    sign_check = nothing
    if id == "sign" && !isempty(config)
        sign_check, _ = _build_check_func(config)
    end

    _status("Estimating Structural DFM: $q factors, id=$id, VAR lags=$var_lags, horizon=$horizon")

    sdfm = estimate_structural_dfm(Y, q;
        identification=Symbol(id), p=var_lags, H=horizon,
        sign_check=sign_check, bandwidth=bandwidth, kernel=Symbol(kernel))

    _status("  Identification: $(sdfm.identification)")
    _status("  Factor VAR lags: $(sdfm.p_var)")
    _status("  Shocks: $(join(sdfm.shock_names, ", "))")

    _maybe_plot(sdfm; plot=plot, plot_save=plot_save)
    return sdfm
end

# ── OLS/WLS Regression ────────────────────────────────

function _estimate_reg(; data::String, dep::String="", cov_type::String="hc1",
                        weights::String="", clusters::String="",
                        output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep; weights_col=weights, clusters_col=clusters)
    w = _load_weights(data, weights)
    cl = _load_clusters(data, clusters)

    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    wls_tag = isnothing(w) ? "OLS" : "WLS"
    _status("$wls_tag Regression: $dep_name ~ $(join(xcols, " + "))")
    _status("  Observations: $(length(y)), Regressors: $(length(xcols)), Cov type: $cov_type")
    _status()

    model = estimate_reg(y, X; cov_type=Symbol(cov_type), weights=w,
                         varnames=xcols, clusters=cl)

    coef_df = _reg_coef_table(model, xcols)
    output_result(coef_df; format=Symbol(format), output=output, title="$wls_tag Regression Coefficients")

    _status()
    f_pv = hasproperty(model, :f_pval) ? model.f_pval :
           (hasproperty(model, :f_pvalue) ? model.f_pvalue : NaN)
    pairs = Pair{String,Any}[
        "R²"              => round(r2(model); digits=6),
        "Adj. R²"         => round(model.adj_r2; digits=6),
        "F-statistic"     => round(model.f_stat; digits=4),
        "F p-value"       => round(f_pv; digits=4),
        "Log-likelihood"  => round(loglikelihood(model); digits=4),
        "AIC"             => round(aic(model); digits=4),
        "BIC"             => round(bic(model); digits=4),
    ]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end

# ── IV (2SLS) Regression ──────────────────────────────

function _estimate_iv(; data::String, dep::String="", endogenous::String="",
                       instruments::String="", cov_type::String="hc1",
                       output::String="", format::String="table")
    isempty(endogenous) && error("--endogenous is required for IV estimation")
    isempty(instruments) && error("--instruments is required for IV estimation")

    df = load_data(data)
    numcols = variable_names(df)

    dep_col = isempty(dep) ? numcols[1] : dep
    !isempty(dep) && !(dep_col in numcols) && error("dependent variable '$dep_col' not found in numeric columns: $numcols")

    endog_names = [strip(s) for s in split(endogenous, ",")]
    inst_names = [strip(s) for s in split(instruments, ",")]

    for nm in endog_names
        nm in numcols || error("endogenous variable '$nm' not found in numeric columns: $numcols")
    end
    for nm in inst_names
        nm in numcols || error("instrument '$nm' not found in numeric columns: $numcols")
    end

    exclude = Set([dep_col])
    xcols = filter(c -> !(c in exclude), numcols)
    isempty(xcols) && error("no regressor columns remaining after excluding dep='$dep_col'")

    endog_idx = [findfirst(==(nm), xcols) for nm in endog_names]
    any(isnothing, endog_idx) && error("endogenous variable(s) not found among regressors")

    y = Vector{Float64}(df[!, dep_col])
    X = Matrix{Float64}(df[!, xcols])
    Z = Matrix{Float64}(df[!, inst_names])

    _status("IV (2SLS) Regression: $dep_col ~ $(join(xcols, " + "))")
    _status("  Endogenous: $(join(endog_names, ", "))")
    _status("  Instruments: $(join(inst_names, ", "))")
    _status("  Observations: $(length(y)), Cov type: $cov_type")
    _status()

    model = estimate_iv(y, X, Z; endogenous=endog_idx, cov_type=Symbol(cov_type), varnames=xcols)

    coef_df = _reg_coef_table(model, xcols)
    output_result(coef_df; format=Symbol(format), output=output, title="IV (2SLS) Regression Coefficients")

    _status()
    pairs = Pair{String,Any}[
        "R²"              => round(r2(model); digits=6),
        "Adj. R²"         => round(model.adj_r2; digits=6),
    ]
    if !isnothing(model.first_stage_f)
        push!(pairs, "First-stage F" => round(model.first_stage_f; digits=4))
    end
    if !isnothing(model.sargan_stat)
        push!(pairs, "Sargan statistic" => round(model.sargan_stat; digits=4))
        push!(pairs, "Sargan p-value"   => round(model.sargan_pval; digits=4))
    end
    output_kv(pairs; format=format, title="IV Diagnostics")
    return model
end

# ── Logit Regression ──────────────────────────────────

function _estimate_logit(; data::String, dep::String="", cov_type::String="hc1",
                          clusters::String="", maxiter::Int=100, tol::Float64=1e-8,
                          output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep; clusters_col=clusters)
    cl = _load_clusters(data, clusters)

    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Logit Regression: $dep_name ~ $(join(xcols, " + "))")
    _status("  Observations: $(length(y)), Regressors: $(length(xcols)), Cov type: $cov_type")
    _status()

    model = estimate_logit(y, X; cov_type=Symbol(cov_type), varnames=xcols,
                           clusters=cl, maxiter=maxiter, tol=tol)

    coef_df = _reg_coef_table(model, xcols)
    output_result(coef_df; format=Symbol(format), output=output, title="Logit Regression Coefficients")

    _status()
    pr2 = hasproperty(model, :pseudo_r2) ? model.pseudo_r2 :
          (try r2(model) catch; NaN end)
    pairs = Pair{String,Any}[
        "Pseudo R²"       => round(pr2; digits=6),
        "Log-likelihood"  => round(loglikelihood(model); digits=4),
        "Log-lik (null)"  => round(model.loglik_null; digits=4),
        "AIC"             => round(aic(model); digits=4),
        "BIC"             => round(bic(model); digits=4),
        "Converged"       => model.converged,
        "Iterations"      => model.iterations,
    ]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end

# ── Probit Regression ─────────────────────────────────

function _estimate_probit(; data::String, dep::String="", cov_type::String="hc1",
                           clusters::String="", maxiter::Int=100, tol::Float64=1e-8,
                           output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep; clusters_col=clusters)
    cl = _load_clusters(data, clusters)

    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Probit Regression: $dep_name ~ $(join(xcols, " + "))")
    _status("  Observations: $(length(y)), Regressors: $(length(xcols)), Cov type: $cov_type")
    _status()

    model = estimate_probit(y, X; cov_type=Symbol(cov_type), varnames=xcols,
                            clusters=cl, maxiter=maxiter, tol=tol)

    coef_df = _reg_coef_table(model, xcols)
    output_result(coef_df; format=Symbol(format), output=output, title="Probit Regression Coefficients")

    _status()
    pr2 = hasproperty(model, :pseudo_r2) ? model.pseudo_r2 :
          (try r2(model) catch; NaN end)
    pairs = Pair{String,Any}[
        "Pseudo R²"       => round(pr2; digits=6),
        "Log-likelihood"  => round(loglikelihood(model); digits=4),
        "Log-lik (null)"  => round(model.loglik_null; digits=4),
        "AIC"             => round(aic(model); digits=4),
        "BIC"             => round(bic(model); digits=4),
        "Converged"       => model.converged,
        "Iterations"      => model.iterations,
    ]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end

# ── Panel Regression ──────────────────────────────────

function _estimate_preg(; data::String, dep::String="", indep::String="",
                         method::String="fe", twoway::Bool=false,
                         cov_type::String="cluster",
                         id_col::String="", time_col::String="",
                         output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model_sym = _to_sym(method)
    cov_sym = _to_sym(cov_type)
    _status("Panel Regression ($method): $dep ~ $(join(indep_syms, " + "))")
    _status()

    model = estimate_xtreg(pd, Symbol(dep), indep_syms;
        model=model_sym, twoway=twoway, cov_type=cov_sym)

    coef_df = _preg_coef_table(model, model.varnames)
    output_result(coef_df; format=Symbol(format), output=output,
        title="Panel Regression Coefficients ($method)")

    _status()
    pairs = Pair{String,Any}[
        "R2 (within)"  => round(model.within_r2; digits=6),
        "R2 (between)" => round(model.between_r2; digits=6),
        "R2 (overall)" => round(model.overall_r2; digits=6),
        "F-statistic"  => round(model.f_stat; digits=4),
        "F p-value"    => round(hasproperty(model, :f_pval) ? model.f_pval :
                                (hasproperty(model, :f_pvalue) ? model.f_pvalue : NaN); digits=4),
        "N obs"        => model.nobs,
        "N groups"     => model.n_groups,
    ]
    output_kv(pairs; format=format, title="Model Statistics")
    return model
end

function _estimate_piv(; data::String, dep::String="", exog::String="",
                        endog::String="", instruments::String="",
                        method::String="fe", cov_type::String="cluster",
                        id_col::String="", time_col::String="",
                        output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    isempty(endog) && error("--endog is required")
    pd = _load_panel_for_preg(data, id_col, time_col)

    exog_syms = isempty(exog) ? Symbol[] : Symbol[Symbol(strip(s)) for s in split(exog, ",")]
    endog_syms = Symbol[Symbol(strip(s)) for s in split(endog, ",")]
    inst_syms = isempty(instruments) ? Symbol[] : Symbol[Symbol(strip(s)) for s in split(instruments, ",")]

    _status("Panel IV ($method): $dep ~ $(join([exog_syms; endog_syms], " + "))")
    _status("  Instruments: $(join(inst_syms, ", "))")
    _status()

    model = estimate_xtiv(pd, Symbol(dep), exog_syms, endog_syms;
        instruments=inst_syms, model=_to_sym(method), cov_type=_to_sym(cov_type))

    all_vars = [string.(exog_syms); string.(endog_syms)]
    coef_df = _preg_coef_table(model, all_vars)
    output_result(coef_df; format=Symbol(format), output=output, title="Panel IV Coefficients")
    return model
end

function _estimate_plogit(; data::String, dep::String="", indep::String="",
                           method::String="pooled", cov_type::String="cluster",
                           id_col::String="", time_col::String="",
                           output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    _status("Panel Logit ($method): $dep ~ $(join(indep_syms, " + "))")
    _status()

    model = estimate_xtlogit(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    coef_df = _preg_coef_table(model, model.varnames)
    output_result(coef_df; format=Symbol(format), output=output,
        title="Panel Logit Coefficients ($method)")

    _status()
    pairs = Pair{String,Any}[
        "Pseudo R2"       => round(model.pseudo_r2; digits=6),
        "Log-likelihood"  => round(model.loglik; digits=4),
        "AIC"             => round(model.aic; digits=4),
        "BIC"             => round(model.bic; digits=4),
        "Converged"       => model.converged,
        "N obs"           => model.nobs,
        "N groups"        => model.n_groups,
    ]
    output_kv(pairs; format=format, title="Model Statistics")
    return model
end

function _estimate_pprobit(; data::String, dep::String="", indep::String="",
                            method::String="pooled", cov_type::String="cluster",
                            id_col::String="", time_col::String="",
                            output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    _status("Panel Probit ($method): $dep ~ $(join(indep_syms, " + "))")
    _status()

    model = estimate_xtprobit(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    coef_df = _preg_coef_table(model, model.varnames)
    output_result(coef_df; format=Symbol(format), output=output,
        title="Panel Probit Coefficients ($method)")

    _status()
    pairs = Pair{String,Any}[
        "Pseudo R2"       => round(model.pseudo_r2; digits=6),
        "Log-likelihood"  => round(model.loglik; digits=4),
        "AIC"             => round(model.aic; digits=4),
        "BIC"             => round(model.bic; digits=4),
        "Converged"       => model.converged,
        "N obs"           => model.nobs,
        "N groups"        => model.n_groups,
    ]
    output_kv(pairs; format=format, title="Model Statistics")
    return model
end

# ── Ordered Logit ──────────────────────────────────────

function _estimate_ologit(; data::String, dep::String="", cov_type::String="ols",
                           clusters::String="",
                           output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    _status("Ordered Logit: $dep_name ~ $(join(xcols, " + "))")
    _status()

    model = estimate_ologit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    J = length(model.cutpoints)
    cut_df = DataFrame(
        Cutpoint = ["cut$i" for i in 1:J],
        Value = round.(model.cutpoints; digits=6),
    )
    output_result(cut_df; format=Symbol(format), output="", title="Cutpoints")

    b = model.beta; se = stderror(model)[1:length(b)]
    z = b ./ se
    p = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    coef_df = DataFrame(
        Variable = xcols,
        Coefficient = round.(b; digits=6),
        Std_Error = round.(se; digits=6),
        z_stat = round.(z; digits=4),
        p_value = round.(p; digits=4),
    )
    _status()
    output_result(coef_df; format=Symbol(format), output=output, title="Ordered Logit Coefficients")

    _status()
    pairs = Pair{String,Any}[
        "Pseudo R2"       => round(model.pseudo_r2; digits=6),
        "Log-likelihood"  => round(model.loglik; digits=4),
        "AIC"             => round(model.aic; digits=4),
        "BIC"             => round(model.bic; digits=4),
        "Categories"      => length(model.categories),
    ]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end

# ── Ordered Probit ─────────────────────────────────────

function _estimate_oprobit(; data::String, dep::String="", cov_type::String="ols",
                            clusters::String="",
                            output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    _status("Ordered Probit: $dep_name ~ $(join(xcols, " + "))")
    _status()

    model = estimate_oprobit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    J = length(model.cutpoints)
    cut_df = DataFrame(Cutpoint = ["cut$i" for i in 1:J], Value = round.(model.cutpoints; digits=6))
    output_result(cut_df; format=Symbol(format), output="", title="Cutpoints")

    b = model.beta; se = stderror(model)[1:length(b)]
    z = b ./ se
    p = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    coef_df = DataFrame(
        Variable = xcols, Coefficient = round.(b; digits=6),
        Std_Error = round.(se; digits=6), z_stat = round.(z; digits=4), p_value = round.(p; digits=4))
    _status()
    output_result(coef_df; format=Symbol(format), output=output, title="Ordered Probit Coefficients")

    _status()
    pairs = Pair{String,Any}[
        "Pseudo R2" => round(model.pseudo_r2; digits=6),
        "Log-likelihood" => round(model.loglik; digits=4),
        "AIC" => round(model.aic; digits=4), "BIC" => round(model.bic; digits=4),
        "Categories" => length(model.categories)]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end

# ── Multinomial Logit ──────────────────────────────────

function _estimate_mlogit(; data::String, dep::String="", cov_type::String="ols",
                           output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    _status("Multinomial Logit: $dep_name ~ $(join(xcols, " + "))")
    _status()

    model = estimate_mlogit(y, X; cov_type=Symbol(cov_type), varnames=xcols)

    J = size(model.fitted, 2)
    for j in 2:J
        cat_beta = model.beta[:, j-1]
        k = length(cat_beta)
        se_all = stderror(model)
        se_j = se_all[((j-2)*k+1):((j-1)*k)]
        z = cat_beta ./ se_j
        p = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
        cat_df = DataFrame(
            Variable = xcols, Coefficient = round.(cat_beta; digits=6),
            Std_Error = round.(se_j; digits=6), z_stat = round.(z; digits=4),
            p_value = round.(p; digits=4))
        output_result(cat_df; format=Symbol(format), output=output,
            title="Category $(model.categories[j]) vs $(model.categories[1])")
        _status()
    end

    pairs = Pair{String,Any}[
        "Pseudo R2" => round(model.pseudo_r2; digits=6),
        "Log-likelihood" => round(model.loglik; digits=4),
        "AIC" => round(model.aic; digits=4), "BIC" => round(model.bic; digits=4),
        "Categories" => J]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end
