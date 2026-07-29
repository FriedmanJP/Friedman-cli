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
            path=["estimate", "arfima"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=0, description="AR order"),
                OptionSpec(name="q", type=Int, default=0, description="MA order"),
                OptionSpec(name="method", short="m", type=String, default="css", description="css|mle (fractional-integration estimator)", choices=["css","mle"]),
                OptionSpec(name="d0", type=Float64, default=nothing, description="Starting value for d (default: GPH pre-estimate)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_arfima, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_arfima),
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
        # C064a: univariate GARCH variants (grouped with the volatility family).
        # Estimate-only leaves — result types are NOT in MEMs _COEF_TABLE_TYPES, so
        # the coefficient table is hand-built (the documented C051 exception).
        CommandSpec(
            path=["estimate", "igarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_igarch, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_igarch),
        ),
        CommandSpec(
            path=["estimate", "cgarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_cgarch, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_cgarch),
        ),
        CommandSpec(
            path=["estimate", "aparch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="fix-delta", type=Float64, default=nothing, description="Pin power δ (>0); default estimates it"),
                OptionSpec(name="fix-gamma", type=Float64, default=nothing, description="Pin leverage γ ∈ (-1,1); default estimates it"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_aparch, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_aparch),
        ),
        CommandSpec(
            path=["estimate", "figarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH β(L) order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH φ(L) order q"),
                OptionSpec(name="d0", type=Float64, default=0.4, description="Initial fractional-integration order d ∈ (0,1)"),
                OptionSpec(name="truncation", type=Int, default=1000, description="ARCH(∞) truncation lag"),
                OptionSpec(name="dist", type=String, default="normal", description="Innovation distribution (Gaussian QMLE)", choices=["normal"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_figarch, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_figarch),
        ),
        CommandSpec(
            path=["estimate", "fiegarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH β(L) order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH φ(L) order q"),
                OptionSpec(name="d0", type=Float64, default=0.4, description="Initial fractional-integration order d ∈ (0,1)"),
                OptionSpec(name="truncation", type=Int, default=1000, description="MA(∞) truncation lag"),
                OptionSpec(name="dist", type=String, default="normal", description="Innovation distribution (Gaussian QMLE)", choices=["normal"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_fiegarch, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_fiegarch),
        ),
        CommandSpec(
            path=["estimate", "garch-midas"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="High-frequency return series column (1-based)"),
                OptionSpec(name="m-freq", type=Int, default=0, description="High-frequency observations per low-frequency block (required)"),
                OptionSpec(name="k", type=Int, default=12, description="Number of MIDAS lags (K ≥ 2)"),
                OptionSpec(name="rv", type=String, default="realized", description="Long-run driver: realized (from returns) | macro (exogenous)", choices=["realized","macro"]),
                OptionSpec(name="span", type=String, default="fixed", description="τ span: fixed (per block) | rolling (rolling RV)", choices=["fixed","rolling"]),
                OptionSpec(name="config", type=String, default="", description="TOML with [garch_midas] x_lf = [...] (required for --rv macro)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_garch_midas, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_garch_midas),
        ),
        # C064b: multivariate GARCH (CCC / DCC-cDCC / scalar-diagonal BEKK).
        # Multivariate — no --column; input is the full numeric matrix (T×n).
        CommandSpec(
            path=["estimate", "ccc"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p for the univariate margins"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q for the univariate margins"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_ccc, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ccc),
        ),
        CommandSpec(
            path=["estimate", "dcc"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p for the univariate margins"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q for the univariate margins"),
                OptionSpec(name="correction", type=String, default="none", description="DCC targeting correction: none | aielli (cDCC)", choices=["none","aielli"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_dcc, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_dcc),
        ),
        CommandSpec(
            path=["estimate", "bekk"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="kind", type=String, default="scalar", description="BEKK(1,1) parameterization: scalar | diagonal", choices=["scalar","diagonal"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_bekk, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_bekk),
        ),
        # C067a: penalized (lasso/ridge/elastic-net) & limited-dependent (robust/tobit)
        # cross-section regression. All share the `_load_reg_data` (y, X) loader — X = all
        # numeric columns except --dep, no constant prepended (same as `estimate reg`).
        CommandSpec(
            path=["estimate", "lasso"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="lambda", type=String, default="auto", description="L1 penalty: auto (CV path) or a non-negative number"),
                OptionSpec(name="select", type=String, default="cv", description="Lambda selection rule: cv|aic|bic|ebic", choices=["cv","aic","bic","ebic"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_lasso, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_lasso),
        ),
        CommandSpec(
            path=["estimate", "ridge"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="lambda", type=String, default="auto", description="L2 penalty: auto (CV path) or a non-negative number"),
                OptionSpec(name="select", type=String, default="cv", description="Lambda selection rule: cv|aic|bic|ebic", choices=["cv","aic","bic","ebic"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_ridge, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ridge),
        ),
        CommandSpec(
            path=["estimate", "elastic-net"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="alpha", type=Float64, default=0.5, description="L1/L2 mixing in [0,1] (1=lasso, 0=ridge)"),
                OptionSpec(name="lambda", type=String, default="auto", description="Penalty: auto (CV path) or a non-negative number"),
                OptionSpec(name="select", type=String, default="cv", description="Lambda selection rule: cv|aic|bic|ebic", choices=["cv","aic","bic","ebic"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_elastic_net, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_elastic_net),
        ),
        CommandSpec(
            path=["estimate", "robust"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="psi", type=String, default="huber", description="ψ (weight) function: huber|bisquare", choices=["huber","bisquare"]),
                OptionSpec(name="method", type=String, default="m", description="Estimator: m|mm (MM = high-breakdown)", choices=["m","mm"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_robust, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_robust),
        ),
        CommandSpec(
            path=["estimate", "tobit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="lower", type=Float64, default=0.0, description="Lower censoring bound"),
                OptionSpec(name="upper", type=Float64, default=Inf, description="Upper censoring bound (default: none)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_tobit, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_tobit),
        ),
        # C067b: truncated-normal regression (Hausman-Wise). Mirrors `estimate tobit` but
        # the sample is truncated (no censored mass): every y must lie strictly inside
        # (lower, upper) or MEMs throws → mapped to data/invalid.
        CommandSpec(
            path=["estimate", "truncreg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="lower", type=Float64, default=0.0, description="Lower truncation bound"),
                OptionSpec(name="upper", type=Float64, default=Inf, description="Upper truncation bound (default: none)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_truncreg, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_truncreg),
        ),
        # C067b: Heckman sample-selection model (two-step or FIML). Two equations —
        # outcome `--dep ~ --outcome-vars` observed only when the binary `--select`
        # indicator is 1, selection `--select ~ --select-vars` (probit). Include a `const`
        # column in each var list if you want an intercept (same no-auto-intercept
        # convention as `estimate reg`). Exclusion restriction: --select-vars should hold a
        # variable not in --outcome-vars (else MEMs warns and identification is nonlinear).
        CommandSpec(
            path=["estimate", "heckman"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Outcome variable column name (default: first numeric column)"),
                OptionSpec(name="select", type=String, default="", description="Binary selection-indicator column (0/1), required"),
                OptionSpec(name="outcome-vars", type=String, default="", description="Outcome-equation regressor columns, comma-separated (required)"),
                OptionSpec(name="select-vars", type=String, default="", description="Selection-equation regressor columns, comma-separated (required)"),
                OptionSpec(name="method", type=String, default="twostep", description="twostep (Heckit) | mle (FIML)", choices=["twostep","mle"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_heckman, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_heckman),
        ),
        # ── C066: state-space + nonparametric estimation (M5c) ──────────────
        # StateSpaceModel / KernelDensity / KernelRegression / LowessFit are NOT registered
        # in MEMs `_COEF_TABLE_TYPES`, so every table is hand-built (documented C051 exception,
        # like io/mgarch/sur). All MEMs calls are wrapped → typed CliError via
        # `_garch_variant_error` (never an uncaught exit-1 on bad input).
        CommandSpec(
            path=["estimate", "statespace"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="1-based numeric column to model"),
                OptionSpec(name="model", type=String, default="local-level", description="local-level | local-linear-trend", choices=["local-level","local-linear-trend"]),
                OptionSpec(name="init-mode", type=String, default="kappa", description="Kalman initialization: kappa | diffuse", choices=["kappa","diffuse"]),
                OptionSpec(name="kappa", type=Float64, default=1e6, description="Large-variance diffuse-init constant (init-mode=kappa)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_statespace, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_statespace),
        ),
        CommandSpec(
            path=["estimate", "tvp"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="init-mode", type=String, default="kappa", description="Kalman initialization: kappa | diffuse", choices=["kappa","diffuse"]),
                OptionSpec(name="kappa", type=Float64, default=1e6, description="Large-variance diffuse-init constant (init-mode=kappa)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="no-intercept", description="Do NOT prepend a time-varying intercept coefficient")],
            tables=[TableSpec(name=:estimate_tvp, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_tvp),
        ),
        CommandSpec(
            path=["estimate", "kde"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="1-based numeric column"),
                OptionSpec(name="kernel", type=String, default="gaussian", description="gaussian | epanechnikov | triangular | uniform", choices=["gaussian","epanechnikov","triangular","uniform"]),
                OptionSpec(name="bw", type=String, default="silverman", description="Bandwidth: silverman | sj | a positive number"),
                OptionSpec(name="npoints", type=Int, default=512, description="Number of grid points"),
                OptionSpec(name="cut", type=Float64, default=3.0, description="Grid extends cut·h beyond the data range each side"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_kde, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_kde),
        ),
        CommandSpec(
            path=["estimate", "kernel-reg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Response variable column name (default: first numeric column)"),
                OptionSpec(name="indep", type=String, default="", description="Single predictor column name (required)"),
                OptionSpec(name="method", type=String, default="ll", description="nw (Nadaraya-Watson) | ll (local linear) | lp (local polynomial)", choices=["nw","ll","lp"]),
                OptionSpec(name="degree", type=Int, default=1, description="Local-polynomial degree (method=lp)"),
                OptionSpec(name="bw", type=String, default="cv", description="Bandwidth: cv | rot | a positive number"),
                OptionSpec(name="kernel", type=String, default="gaussian", description="gaussian | epanechnikov | triangular | uniform", choices=["gaussian","epanechnikov","triangular","uniform"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_kernel_reg, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_kernel_reg),
        ),
        CommandSpec(
            path=["estimate", "lowess"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Response variable column name (default: first numeric column)"),
                OptionSpec(name="indep", type=String, default="", description="Single predictor column name (required)"),
                OptionSpec(name="frac", type=Float64, default=0.6667, description="Smoother span f ∈ (0,1] (fraction of points per window)"),
                OptionSpec(name="iter", type=Int, default=3, description="Number of bisquare robustifying passes"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_lowess, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_lowess),
        ),
        # ── C062a: cointegrating regression (FMOLS / CCR / DOLS) ──────────────
        # `estimate cointreg` (single-equation, `_load_reg_data`) + `estimate xtcointreg`
        # (panel, `_load_panel_reg`). Hand-built coef table (C051 exception). NOTE the trend
        # vocabulary is cointreg-specific: none|const|linear (do NOT share the OptionSpec —
        # PMG uses :constant, ARDL uses :const/:trend). Dual-type --bandwidth/--leads/--lags
        # are declared String and parsed in-handler (`_parse_cointreg_*`).
        CommandSpec(
            path=["estimate", "cointreg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent (levels) column name (default: first numeric column)"),
                OptionSpec(name="method", type=String, default="fmols", description="fmols|ccr|dols", choices=["fmols","ccr","dols"]),
                OptionSpec(name="trend", type=String, default="const", description="Deterministics: none|const|linear", choices=["none","const","linear"]),
                OptionSpec(name="kernel", type=String, default="bartlett", description="HAC kernel: bartlett|parzen|qs|tukey-hanning", choices=["bartlett","parzen","qs","tukey-hanning"]),
                OptionSpec(name="bandwidth", type=String, default="andrews", description="andrews|nw94 or a fixed truncation lag (>=0)"),
                OptionSpec(name="leads", type=String, default="auto", description="DOLS leads: auto or a non-negative integer"),
                OptionSpec(name="lags", type=String, default="auto", description="DOLS lags: auto or a non-negative integer"),
                OptionSpec(name="ic", type=String, default="aic", description="DOLS lead/lag selection: aic|bic", choices=["aic","bic"]),
                OptionSpec(name="dols-se", type=String, default="lrv", description="DOLS standard errors: lrv|robust", choices=["lrv","robust"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_cointreg, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_cointreg),
        ),
        CommandSpec(
            path=["estimate", "xtcointreg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group id column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column (default: second column)"),
                OptionSpec(name="dep", type=String, default="", description="Dependent panel variable (default: first variable)"),
                OptionSpec(name="indep", type=String, default="", description="Regressors, comma-separated (default: all other variables)"),
                OptionSpec(name="method", type=String, default="fmols", description="fmols|dols (no ccr for panels)", choices=["fmols","dols"]),
                OptionSpec(name="pooling", type=String, default="group", description="group (between) | pooled (within)", choices=["group","pooled"]),
                OptionSpec(name="trend", type=String, default="const", description="Per-unit deterministics: none|const|linear", choices=["none","const","linear"]),
                OptionSpec(name="kernel", type=String, default="bartlett", description="HAC kernel: bartlett|parzen|qs|tukey-hanning", choices=["bartlett","parzen","qs","tukey-hanning"]),
                OptionSpec(name="bandwidth", type=String, default="andrews", description="andrews|nw94 or a fixed truncation lag (>=0)"),
                OptionSpec(name="leads", type=String, default="auto", description="DOLS leads: auto or a non-negative integer"),
                OptionSpec(name="lags", type=String, default="auto", description="DOLS lags: auto or a non-negative integer"),
                OptionSpec(name="ic", type=String, default="aic", description="DOLS lead/lag selection: aic|bic", choices=["aic","bic"]),
                OptionSpec(name="dols-se", type=String, default="lrv", description="DOLS standard errors: lrv|robust", choices=["lrv","robust"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_xtcointreg, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_xtcointreg),
        ),
        # ── C062b: single-equation ARDL / NARDL (autoregressive distributed lag) ──
        # `estimate ardl` (linear ARDL, folds long-run + ECM speed of adjustment) +
        # `estimate nardl` (nonlinear/asymmetric ARDL, folds θ⁺/θ⁻ long-run + the cached
        # enlarged-k bounds decision). Both load y+X via `_load_reg_data` (no intercept
        # prepended — ARDL adds its own deterministics per PSS `--case`). ARDLModel/NARDLModel
        # are StatsAPI models but NOT in MEMs `_COEF_TABLE_TYPES` → hand-built tidy tables
        # (C051 exception). NOTE the trend vocab is ARDL-specific: none|const|trend (NOT the
        # cointreg none|const|linear, NOT PMG's :constant). `--p`/`--q` accept auto|int|list.
        CommandSpec(
            path=["estimate", "ardl"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent column name (default: first numeric column)"),
                OptionSpec(name="p", type=String, default="auto", description="AR order: auto or an integer ≥ 1"),
                OptionSpec(name="q", type=String, default="auto", description="DL order: auto, an integer (all regressors), or a comma-separated per-regressor list"),
                OptionSpec(name="max-p", type=Int, default=4, description="Max AR order for auto IC selection"),
                OptionSpec(name="max-q", type=Int, default=4, description="Max DL order for auto IC selection"),
                OptionSpec(name="ic", type=String, default="aic", description="Selection criterion: aic|bic", choices=["aic","bic"]),
                OptionSpec(name="case", type=Int, default=3, description="Pesaran-Shin-Smith deterministic case (1..5)"),
                OptionSpec(name="trend", type=String, default="none", description="Informational trend label: none|const|trend", choices=["none","const","trend"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_ardl, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ardl),
        ),
        CommandSpec(
            path=["estimate", "nardl"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent column name (default: first numeric column)"),
                OptionSpec(name="asymmetric", type=String, default="all", description="'all' or comma-separated 1-based regressor indices to split into +/- partial sums"),
                OptionSpec(name="p", type=String, default="auto", description="AR order: auto or an integer ≥ 1"),
                OptionSpec(name="q", type=String, default="auto", description="DL order: auto, an integer (all split regressors), or a comma-separated list"),
                OptionSpec(name="max-p", type=Int, default=4, description="Max AR order for auto IC selection"),
                OptionSpec(name="max-q", type=Int, default=4, description="Max DL order for auto IC selection"),
                OptionSpec(name="ic", type=String, default="aic", description="Selection criterion: aic|bic", choices=["aic","bic"]),
                OptionSpec(name="case", type=Int, default=3, description="Pesaran-Shin-Smith deterministic case (1..5)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_nardl, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_nardl),
        ),
        # ── C062c: dynamic heterogeneous-panel ARDL (PMG / MG / DFE) ──────────
        # `estimate pmg` fits Pooled Mean Group (common long-run θ), Mean Group, or Dynamic
        # Fixed Effects on a long-format panel via the shared `_load_panel_reg` loader; folds a
        # long-run θ table + a short-run/EC (φ) table + diagnostics. PMGModel is a StatsAPI model
        # but NOT in MEMs `_COEF_TABLE_TYPES` → hand-built tables (C051 exception). NOTE the trend
        # vocab is PMG-specific: none|constant|trend (`:constant` spelled out — NOT ARDL's :const).
        CommandSpec(
            path=["estimate", "pmg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group id column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column (default: second column)"),
                OptionSpec(name="dep", type=String, default="", description="Dependent panel variable (default: first variable)"),
                OptionSpec(name="indep", type=String, default="", description="Long-run regressors, comma-separated (default: all other variables)"),
                OptionSpec(name="method", type=String, default="pmg", description="pmg (pooled mean group) | mg (mean group) | dfe (dynamic fixed effects)", choices=["pmg","mg","dfe"]),
                OptionSpec(name="trend", type=String, default="constant", description="Per-unit EC deterministics: none|constant|trend", choices=["none","constant","trend"]),
                OptionSpec(name="p", type=Int, default=1, description="Autoregressive order (≥ 1)"),
                OptionSpec(name="q", type=Int, default=1, description="Distributed-lag order for all regressors (≥ 0)"),
                OptionSpec(name="maxiter", type=Int, default=100, description="PMG outer-loop max iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-8, description="PMG outer-loop convergence tolerance"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_pmg, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_pmg),
        ),
        # ── C062d: MIDAS mixed-frequency regression ──────────────────────────
        # `estimate midas` fits a (restricted) MIDAS / ADL-MIDAS / U-MIDAS regression of a
        # low-frequency target (--data, --column) on --k high-frequency lags of a single indicator
        # (--hf-data, --hf-column) aggregated through a parsimonious weight function. The only new
        # plumbing is the mixed-frequency `_load_midas_data` loader (5th shared-loader hardening:
        # BOTH inputs go through the hardened `load_univariate_series`, and the aligned
        # len(HF)>=m×len(LF) rule is a typed `data/shape`, leading ragged edge dropped). `MidasModel` is a StatsAPI model but NOT
        # in MEMs `_COEF_TABLE_TYPES` → hand-built weight-curve + coef tables (C051 exception).
        # `forecast midas` is DEFERRED (needs a fresh-HF-block UX + non-native .fmod round-trip; v1.1).
        CommandSpec(
            path=["estimate", "midas"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to the low-frequency target CSV")],
            options=[
                OptionSpec(name="column", type=Int, default=1, description="Low-frequency target column in --data (1-based)"),
                OptionSpec(name="hf-data", type=String, default="", description="High-frequency indicator CSV (REQUIRED)"),
                OptionSpec(name="hf-column", type=Int, default=1, description="High-frequency indicator column in --hf-data (1-based)"),
                OptionSpec(name="m", type=Int, default=0, description="Frequency ratio HF/LF, e.g. 3 = monthly→quarterly (REQUIRED, ≥ 1)"),
                OptionSpec(name="k", type=Int, default=0, description="Number of high-frequency lags (REQUIRED, ≥ 1)"),
                OptionSpec(name="weights", type=String, default="expalmon", description="Weight scheme: expalmon|beta2|beta3|almon|umidas", choices=["expalmon","beta2","beta3","almon","umidas"]),
                OptionSpec(name="p-ar", type=Int, default=0, description="Autoregressive lags of the target (ADL-MIDAS, ≥ 0)"),
                OptionSpec(name="poly-degree", type=Int, default=2, description="Polynomial degree for --weights almon"),
                OptionSpec(name="horizon", type=Int, default=1, description="Direct forecast horizon h stored in the model (1 = nowcast)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="LBFGS iteration cap per NLS start"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_midas, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_midas),
        ),
        # ── C065a: SETAR (self-exciting threshold autoregression) ──
        # Two-regime SETAR via `estimate_setar` (Hansen 2000 threshold CI + attached
        # Hansen 1996 linearity test). Hand-built two-regime coef table + kv diagnostics
        # (ThresholdModel is NOT in MEMs `_COEF_TABLE_TYPES`). `--d` is a `Int|:auto`
        # sentinel; `--ci-level` MUST be exactly 0.90/0.95/0.99 (Hansen 2000 tabulation).
        CommandSpec(
            path=["estimate", "setar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="d", type=String, default="1", description="Delay lag: an integer ≥ 1, or 'auto' (=1:p grid)"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming fraction for the threshold grid (0 < trim < 0.5)"),
                OptionSpec(name="reps", type=Int, default=1000, description="Bootstrap reps for the Hansen test / threshold CI (≥ 1)"),
                OptionSpec(name="ci-level", type=Float64, default=0.95, description="Threshold CI level: 0.90|0.95|0.99", choices=["0.90", "0.95", "0.99"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table", "csv", "json"])
            ],
            flags=[
                FlagSpec(name="het", description="Heteroskedastic (White) bootstrap for the linearity test / CI"),
                FlagSpec(name="no-linearity", description="Skip the attached Hansen (1996) linearity test")
            ],
            tables=[TableSpec(name=:estimate_setar, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_setar),
        ),
        # ── C065b: STAR (smooth-transition autoregression) ──
        # Two-regime STAR via `estimate_star` (Teräsvirta 1994 NLS). Hand-built two-regime
        # weight tables (1−G / G) + a transition-parameters block (γ, c) + kv diagnostics
        # (STARModel is NOT in MEMs `_COEF_TABLE_TYPES`). `--type` selects the transition
        # shape (lstr1|lstr2|estr) or `auto` (Teräsvirta sequential selection); an external
        # transition variable can be supplied via `--transition-col` (else self-exciting y[t-d]).
        CommandSpec(
            path=["estimate", "star"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="d", type=Int, default=1, description="Delay lag for the self-exciting transition var (≥ 1)"),
                OptionSpec(name="type", type=String, default="auto", description="Transition shape: lstr1|lstr2|estr|auto", choices=["lstr1", "lstr2", "estr", "auto"]),
                OptionSpec(name="n-gamma", type=Int, default=15, description="Grid points for the γ start values (≥ 2)"),
                OptionSpec(name="n-c", type=Int, default=15, description="Grid points for the c start values (≥ 2)"),
                OptionSpec(name="transition-col", type=Int, default=0, description="Column index of an external transition var s (0 = self-exciting y[t-d])"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table", "csv", "json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_star, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_star),
        ),
        # ── C065c: MS-AR (Markov-switching autoregression, Hamilton 1989 mean-switching) ──
        # `estimate_ms_ar` → MSRegModel(model_type=:ms_ar). Only the level μ switches across
        # regimes; the AR coefficients φ are COMMON. Hand-built per-regime coef table (μ rows +
        # a common-AR block) + a per-regime variance table + a WIDE K×K transition matrix +
        # diagnostics kv (MSRegModel is NOT in MEMs `_COEF_TABLE_TYPES`). NOTE the Hamilton form's
        # `switching_variance` default is FALSE (the `--switching-variance` flag turns it ON) —
        # the OPPOSITE polarity of `estimate ms`; do not unify.
        CommandSpec(
            path=["estimate", "ms-ar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="k-regimes", type=Int, default=2, description="Number of regimes (≥ 2)"),
                OptionSpec(name="max-iter", type=Int, default=1000, description="Max EM iterations (≥ 1)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table", "csv", "json"])
            ],
            flags=[FlagSpec(name="switching-variance", description="Let σ² switch across regimes (default: off, Hamilton form)")],
            tables=[TableSpec(name=:estimate_ms_ar, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ms_ar),
        ),
        # ── C065c: MS regression (K-state Markov-switching regression) ──
        # `estimate_ms` → MSRegModel(model_type=:regression) — every coefficient switches with the
        # latent regime. Loaded via `_load_reg_data` (y + numeric regressors, NO auto-intercept —
        # include a `const` column, like `estimate reg`); when the dependent variable is the ONLY
        # numeric column, routes to the single-arg intercept-only dispatch `estimate_ms(y; …)`.
        # Same hand-built rendering as ms-ar via the shared `_ms_render`. NOTE the regression form's
        # `switching_variance` default is TRUE (the `--no-switching-variance` flag turns it OFF) —
        # the OPPOSITE polarity of `estimate ms-ar`.
        CommandSpec(
            path=["estimate", "ms"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="k-regimes", type=Int, default=2, description="Number of regimes (≥ 2)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Max EM iterations (≥ 1)"),
                OptionSpec(name="tol", type=Float64, default=1e-8, description="EM convergence tolerance (> 0)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table", "csv", "json"])
            ],
            flags=[FlagSpec(name="no-switching-variance", description="Force common σ² across regimes (default: σ² switches)")],
            tables=[TableSpec(name=:estimate_ms, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_ms),
        ),
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
            path=["estimate", "select"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="method", type=String, default="bidirectional", description="Search strategy", choices=["forward","backward","bidirectional","best-subset","gets"]),
                OptionSpec(name="criterion", type=String, default="pvalue", description="Selection criterion", choices=["pvalue","aic","bic"]),
                OptionSpec(name="p-enter", type=Float64, default=0.05, description="p-value to enter a regressor (0,1)"),
                OptionSpec(name="p-remove", type=Float64, default=0.10, description="p-value to remove a regressor (0,1); must be ≥ --p-enter for bidirectional pvalue"),
                OptionSpec(name="keep", type=String, default="", description="Comma-separated regressor names always retained"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_select, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_select),
        ),
        CommandSpec(
            path=["estimate", "iv"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="endogenous", type=String, default="", description="Endogenous regressor column names, comma-separated (required)"),
                OptionSpec(name="instruments", type=String, default="", description="EXCLUDED instrument column names, comma-separated (required; other numeric cols are exogenous regressors — include a `const` for an intercept)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="ols|hc0|hc1|hc2|hc3"),
                OptionSpec(name="method", type=String, default="tsls", description="k-class estimator", choices=["tsls","liml","fuller","kclass"]),
                OptionSpec(name="k", type=String, default="", description="k-class scalar (required with --method kclass; k=0 is OLS, k=1 is 2SLS)"),
                OptionSpec(name="fuller-a", type=Float64, default=1.0, description="Fuller adjustment a > 0 (--method fuller only; a=1 is approximately unbiased)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate_iv, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_iv),
        ),
        CommandSpec(
            path=["estimate", "sur"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config: [[equations]] blocks (dep + indep) (required)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[
                FlagSpec(name="iterate", description="Iterate FGLS to the Gaussian MLE"),
                FlagSpec(name="no-intercept", description="Do not add a per-equation constant"),
            ],
            tables=[TableSpec(name=:estimate_sur, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_sur),
        ),
        CommandSpec(
            path=["estimate", "3sls"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config: [[equations]] + instruments (required)"),
                OptionSpec(name="instruments", type=String, default="common", choices=["common","perequation"], description="common|perequation instrument sets"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[
                FlagSpec(name="no-intercept", description="Do not add a per-equation constant"),
            ],
            tables=[TableSpec(name=:estimate_3sls, description="Path to CSV data file")],
            category="estimate",
            handler=wrap_legacy(_estimate_3sls),
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
                # cov-type is WIDENED to include pcse for THIS leaf only, and the two new
                # options are appended HERE rather than to PREG_OPTIONS: that const is
                # shared with piv/plogit/pprobit, predict/residuals and several `test`
                # leaves whose estimators take no :pcse and whose handlers accept no
                # ar1/pcse_unbalanced kwarg (declaring an option a handler cannot take is
                # an exit-1 MethodError on every invocation — see #85).
                map(o -> o.name == "cov-type" ?
                        OptionSpec(name="cov-type", type=String, default="cluster",
                                   choices=["ols","cluster","twoway","driscoll-kraay","pcse"],
                                   description="ols|cluster|twoway|driscoll-kraay|pcse (Beck-Katz panel-corrected SEs)") : o,
                    PREG_OPTIONS)...;
                OptionSpec(name="ar1", type=String, default="none", description="Prais-Winsten AR(1) correction", choices=["none","common","panel-specific"]);
                OptionSpec(name="pcse-unbalanced", type=String, default="casewise", description="Unbalanced-panel handling for --cov-type pcse", choices=["casewise","pairwise"])
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

# ── ARFIMA (fractional integration / long memory) ──────────

function _estimate_arfima(; data::String, column::Int=1, p::Int=0, q::Int=0,
                           method::String="css", d0=nothing, max_iter::Int=500,
                           format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    method_sym = Symbol(method)

    _status("Estimating ARFIMA($p,d,$q): variable=$vname, observations=$(length(y)), method=$method")
    _status()

    model = try
        d0v = isnothing(d0) ? nothing : Float64(d0)
        estimate_arfima(y, p, q; method=method_sym, d0=d0v, max_iter=max_iter)
    catch e
        throw(_long_memory_error(e, "ARFIMA estimation"))
    end

    label = "ARFIMA($(model.p),$(round(model.d; digits=4)),$(model.q))"

    # Coefficient table: hand-built. ARFIMAModel is not a MEMs coef-table type
    # (`DataFrame(model)`), so the tidy coefficient path does not apply — this is a
    # documented C051 exception (like ARIMA/volatility). Ordering is [c, d, phi.., theta..].
    _arfima_coef_table(model; format=format, output=output,
                       title="$label Coefficients ($vname)")

    _status()
    output_kv(Pair{String,Any}[
        "d (frac. integ.)" => round(model.d; digits=6),
        "d std. error"     => round(model.d_se; digits=6),
        "Log-likelihood"   => round(model.loglik; digits=4),
        "AIC"              => round(model.aic; digits=4),
        "BIC"              => round(model.bic; digits=4),
        "Converged"        => model.converged,
    ]; format=format, title="ARFIMA Diagnostics ($vname)")
    return model
end

function _arfima_coef_table(model; format::String="table", output::String="", title::String="Coefficients")
    c = coef(model)                                 # [c, d, phi.., theta..]
    p_order = ar_order(model)
    q_order = ma_order(model)
    param_names = String["const", "d"]
    for i in 1:p_order
        push!(param_names, "ar$i")
    end
    for i in 1:q_order
        push!(param_names, "ma$i")
    end
    # Guard against any length mismatch (keep the table well-formed).
    for i in (length(param_names)+1):length(c)
        push!(param_names, "param$i")
    end
    param_names = param_names[1:length(c)]

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

# Map the CLI/config weighting string to the two symbols real MEMs' `estimate_smm`
# understands. `optimal`/`iterated`/`twostep` are aliases of the two-step optimal
# weighting matrix (Ω⁻¹); anything else is a usage/config error.
function _smm_weighting_symbol(w::AbstractString)
    wl = lowercase(w)
    wl == "identity" && return :identity
    wl in ("two_step", "twostep", "optimal", "iterated") && return :two_step
    throw(CliError("config/enum", "unknown smm weighting `$w` (identity|two_step)"))
end

# Optional bounds → ParameterTransform (both lower and upper, matching θ length).
function _smm_bounds(smm, n_params::Int)
    lower = smm["lower"]; upper = smm["upper"]
    (lower === nothing && upper === nothing) && return nothing
    (lower === nothing || upper === nothing) &&
        throw(CliError("config/shape", "[smm] bounds require BOTH `lower` and `upper`"))
    (length(lower) == n_params && length(upper) == n_params) ||
        throw(CliError("config/shape",
            "[smm] `lower`/`upper` must each have $n_params entries (one per θ), " *
            "got $(length(lower))/$(length(upper))"))
    ParameterTransform(lower, upper)
end

# Build a built-in SMM data-generating simulator. Returns (simulator_fn, param_names);
# simulator_fn(θ, T_periods, burn; rng) → a (T_periods × k) matrix (burn already discarded),
# matching real MEMs' `estimate_smm` simulator contract. θ layout depends on the model.
function _smm_simulator(model::AbstractString, k::Int, theta0, smm)
    m = lowercase(model)
    if m == "ar1"
        k == 1 || throw(CliError("config/shape", "smm model `ar1` needs univariate data (1 column), got $k"))
        length(theta0) == 2 || throw(CliError("config/shape",
            "ar1 `theta0` must be [phi, sigma] (2 params), got $(length(theta0))"))
        sim = (theta, Tp, burn; rng=Random.default_rng()) -> begin
            phi = theta[1]; sigma = abs(theta[2])
            n = Tp + burn
            y = zeros(Float64, n)
            @inbounds for t in 2:n
                y[t] = phi * y[t-1] + sigma * randn(rng)
            end
            reshape(y[(burn+1):end], :, 1)
        end
        return sim, ["phi", "sigma"]
    elseif m == "arp"
        k == 1 || throw(CliError("config/shape", "smm model `arp` needs univariate data (1 column), got $k"))
        p = smm["p"]
        p === nothing && throw(CliError("config/missing-key", "smm model `arp` requires `p` (AR order) in [smm]"))
        p >= 1 || throw(CliError("config/shape", "smm model `arp` requires p >= 1, got $p"))
        length(theta0) == p + 1 || throw(CliError("config/shape",
            "arp `theta0` must be [phi_1..phi_$p, sigma] ($(p+1) params), got $(length(theta0))"))
        sim = (theta, Tp, burn; rng=Random.default_rng()) -> begin
            phis = @view theta[1:p]; sigma = abs(theta[p+1])
            n = Tp + burn
            y = zeros(Float64, n)
            @inbounds for t in (p+1):n
                s = 0.0
                for j in 1:p
                    s += phis[j] * y[t-j]
                end
                y[t] = s + sigma * randn(rng)
            end
            reshape(y[(burn+1):end], :, 1)
        end
        return sim, String[["phi_$j" for j in 1:p]; "sigma"]
    elseif m == "var1"
        length(theta0) == k * k + k || throw(CliError("config/shape",
            "var1 `theta0` must be [vec(A) ($(k*k) entries, column-major); sigma_1..sigma_$k] " *
            "($(k*k + k) params), got $(length(theta0))"))
        sim = (theta, Tp, burn; rng=Random.default_rng()) -> begin
            A = reshape(theta[1:k*k], k, k)
            sigmas = abs.(theta[k*k+1:k*k+k])
            n = Tp + burn
            Ymat = zeros(Float64, n, k)
            @inbounds for t in 2:n
                Ymat[t, :] = A * Ymat[t-1, :] .+ sigmas .* randn(rng, k)
            end
            Ymat[(burn+1):end, :]
        end
        # column-major to match reshape(theta[1:k²], k, k): A[1,1],A[2,1],…,A[k,1],A[1,2],…
        names = String[]
        for j in 1:k, i in 1:k
            push!(names, "A[$i,$j]")
        end
        for i in 1:k
            push!(names, "sigma_$i")
        end
        return sim, names
    elseif m == "iid_normal"
        length(theta0) == k || throw(CliError("config/shape",
            "iid_normal `theta0` must be [sigma_1..sigma_$k] ($k params), got $(length(theta0))"))
        sim = (theta, Tp, burn; rng=Random.default_rng()) -> begin
            sigmas = abs.(theta)
            n = Tp + burn
            Ymat = randn(rng, n, k) .* sigmas'
            Ymat[(burn+1):end, :]
        end
        return sim, ["sigma_$i" for i in 1:k]
    else
        throw(CliError("config/enum", "unknown smm model `$model` (ar1|arp|var1|iid_normal)"))
    end
end

function _estimate_smm(; data::String, config::String="",
                        weighting::String="two_step", sim_ratio::Int=5,
                        burn::Int=100,
                        output::String="", format::String="table")
    Y, varnames = load_multivariate_data(data)
    k = size(Y, 2)

    # SMM needs a data-generating model to simulate from — that lives in the [smm] config,
    # so --config is required (unlike the other estimate leaves).
    isempty(config) && throw(CliError("config/missing",
        "estimate smm requires --config <toml> with an [smm] section specifying a " *
        "data-generating `model` (ar1|arp|var1|iid_normal) and `theta0`. SMM matches " *
        "simulated moments to sample moments, so it needs a model to simulate."))

    cfg = load_config(config)
    smm = get_smm(cfg)
    weighting = smm["weighting"]
    sim_ratio = smm["sim_ratio"]
    burn      = smm["burn"]
    lags      = smm["lags"]

    modelname = smm["model"]
    modelname === nothing && throw(CliError("config/missing-key",
        "[smm] must set `model` = one of ar1|arp|var1|iid_normal"))
    theta0 = smm["theta0"]
    theta0 === nothing && throw(CliError("config/missing-key",
        "[smm] must set `theta0` (initial parameter vector; layout depends on `model`)"))

    simulator_fn, param_names = _smm_simulator(modelname, k, theta0, smm)
    moments_fn       = d -> autocovariance_moments(d; lags=lags)
    contributions_fn = d -> autocovariance_moment_contributions(d; lags=lags)

    n_params  = length(theta0)
    n_moments = k * (k + 1) ÷ 2 + k * lags
    n_moments >= n_params || throw(CliError("config/underidentified",
        "SMM needs at least as many moments as parameters: $n_moments moments " *
        "(k(k+1)/2 + k·lags, k=$k, lags=$lags) < $n_params params. Increase `lags`."))

    bounds = _smm_bounds(smm, n_params)
    wsym   = _smm_weighting_symbol(weighting)
    # Determinism (C052/#243): the global Random.seed! already makes runs reproducible;
    # forward --seed as the estimator's own rng so simulation draws are pinned too.
    rng = _SEED[] === nothing ? Random.default_rng() : Random.MersenneTwister(_SEED[])

    _status("Estimating SMM: model=$modelname, $k variable(s), $n_params params, " *
            "$n_moments moments; weighting=$weighting, sim_ratio=$sim_ratio, burn=$burn")
    _status()

    model = try
        estimate_smm(simulator_fn, moments_fn, theta0, Y;
                     weighting=wsym, sim_ratio=sim_ratio, burn=burn,
                     contributions_fn=contributions_fn, bounds=bounds, rng=rng)
    catch e
        e isa CliError && rethrow()
        (e isa ArgumentError || e isa AssertionError || e isa BoundsError ||
         e isa DimensionMismatch) ||
            rethrow()
        throw(CliError("model/error", "SMM estimation failed: $(sprint(showerror, e))"))
    end

    se = sqrt.(abs.(diag(model.vcov)))
    t_stats = model.theta ./ se
    p_vals = [2.0 * (1.0 - _normal_cdf(abs(t))) for t in t_stats]

    est_df = DataFrame(
        parameter = param_names,
        estimate = round.(model.theta; digits=6),
        std_error = round.(se; digits=6),
        t_stat = round.(t_stats; digits=4),
        p_value = round.(p_vals; digits=4),
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="SMM Estimation (model=$modelname, weighting=$weighting)")

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
        _status("Bayesian FAVAR: $(favar.n_factors) factors, $(favar.n_key) key vars, $(size(favar.B_draws, 3)) draws")
        pairs = Pair{String,Any}[
            "Factors" => favar.n_factors,
            "Key variables" => favar.n_key,
            "Lags" => favar.p,
            "MCMC draws" => size(favar.B_draws, 3),
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

# C067 (#72): general-to-specific / stepwise variable selection. A DEDICATED LEAF
# rather than an `estimate reg --select` flag, so `estimate reg`'s envelope tables stay
# fixed — a leaf whose table set changes with a flag forces every agent consuming it to
# branch. `select_variables` returns a SelectionResult that CARRIES the refitted
# `final::RegModel`, so this renders the same coefficient table as `estimate reg` plus
# the selection path.
function _estimate_select(; data::String, dep::String="", method::String="bidirectional",
                           criterion::String="pvalue", p_enter::Float64=0.05,
                           p_remove::Float64=0.10, keep::String="",
                           output::String="", format::String="table")
    (0.0 < p_enter < 1.0) || throw(CliError("usage/invalid",
        "estimate select: --p-enter must be in (0, 1) (got $p_enter)"))
    (0.0 < p_remove < 1.0) || throw(CliError("usage/invalid",
        "estimate select: --p-remove must be in (0, 1) (got $p_remove)"))
    # Upstream requires p_remove >= p_enter for the bidirectional p-value search; guard
    # it here so the common mistake is a usage error, not a bare ArgumentError.
    (method != "bidirectional" || criterion != "pvalue" || p_remove >= p_enter) ||
        throw(CliError("usage/invalid",
            "estimate select: bidirectional pvalue search needs --p-remove ≥ --p-enter (got $p_remove < $p_enter)"))
    y, X, xcols = _load_reg_data(data, dep)
    keep_idx = nothing
    if !isempty(keep)
        names = [strip(t) for t in split(keep, ",") if !isempty(strip(t))]
        isempty(names) && throw(CliError("usage/invalid", "estimate select: --keep is empty"))
        keep_idx = Int[]
        for nm in names
            i = findfirst(==(String(nm)), xcols)
            i === nothing && throw(CliError("data/column-range",
                "estimate select: --keep column '$nm' is not a regressor";
                hint="available: $(join(xcols, ", "))"))
            push!(keep_idx, i)
        end
    end
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Variable Selection ($method/$criterion): $dep_name ~ $(join(xcols, " + "))"); _status()
    res = try
        select_variables(y, X; method=Symbol(replace(method, '-' => '_')),
                         criterion=Symbol(criterion), p_enter=p_enter,
                         p_remove=p_remove, keep=keep_idx, varnames=xcols)
    catch e
        throw(_garch_variant_error(e, "variable selection"))
    end
    # The refitted final model renders exactly like `estimate reg`.
    output_result(_reg_coef_table(res.final, res.varnames[res.selected]);
        format=Symbol(format), output=output,
        title="Selected Model Coefficients ($dep_name)")
    # The search path is the audit trail: each step is (action, column, statistic).
    if !isempty(res.path)
        output_result(DataFrame(
                step = collect(1:length(res.path)),
                action = [String(p[1]) for p in res.path],
                variable = [res.varnames[p[2]] for p in res.path],
                statistic = [round(Float64(p[3]); digits=6) for p in res.path]);
            format=Symbol(format), output=_per_var_output_path(output, "path"),
            title="Selection Path ($dep_name)")
    end
    pairs = Pair{String,Any}[
        "method" => String(res.method),
        "criterion" => String(res.criterion),
        "selected" => isempty(res.selected) ? "none" : join(res.varnames[res.selected], ", "),
        "n selected" => length(res.selected),
        "kept (forced)" => isempty(res.keep) ? "none" : join(res.varnames[res.keep], ", "),
        "candidates (GUM)" => res.n_gum,
        "terminal models" => length(res.terminal_models),
    ]
    res.encompassing_f === nothing || push!(pairs, "encompassing F" => _finite_or_str_reg(Float64(res.encompassing_f)))
    res.encompassing_pval === nothing || push!(pairs, "encompassing p-value" => _finite_or_str_reg(Float64(res.encompassing_pval)))
    output_kv(pairs; format=format, title="Selection Summary")
    return res
end

"""Round for display but render a non-finite value as a string (legacy JSON writer)."""
_finite_or_str_reg(x) = isfinite(x) ? round(Float64(x); digits=6) : string(Float64(x))

function _estimate_iv(; data::String, dep::String="", endogenous::String="",
                       instruments::String="", cov_type::String="hc1",
                       method::String="tsls", k::String="", fuller_a::Float64=1.0,
                       output::String="", format::String="table")
    # C067b: typed shared loader (`_load_iv_data`) replaces the old bare `error()` sites
    # (untyped exit-1) — a missing/unknown column is user input, not a CLI bug. Shared with
    # `test weak-instrument` so the two never drift.
    # k-class family (#72): :tsls | :liml | :fuller | :kclass. `k` is REQUIRED for
    # kclass and meaningless otherwise; guard both up front so a bad combination is a
    # usage error rather than a bare upstream ArgumentError.
    kval = nothing
    if method == "kclass"
        isempty(k) && throw(CliError("usage/missing",
            "estimate iv: --method kclass requires --k";
            hint="give the k-class scalar, e.g. --k 1 (k=0 is OLS, k=1 is 2SLS)"))
        kv = tryparse(Float64, k)
        (kv === nothing || !isfinite(kv)) && throw(CliError("usage/invalid",
            "estimate iv: --k must be a finite number, got '$k'"))
        kval = kv
    elseif !isempty(k)
        throw(CliError("usage/invalid",
            "estimate iv: --k applies only to --method kclass (got --method $method)"))
    end
    method == "fuller" || fuller_a == 1.0 || throw(CliError("usage/invalid",
        "estimate iv: --fuller-a applies only to --method fuller (got --method $method)"))
    method != "fuller" || fuller_a > 0 || throw(CliError("usage/invalid",
        "estimate iv: --fuller-a must be > 0 (got $fuller_a)"))

    d = _load_iv_data(data, dep, endogenous, instruments)
    y, X, Z, xcols, endog_idx = d.y, d.X, d.Z, d.xcols, d.endog_idx

    label = uppercase(method == "tsls" ? "2SLS" : method)
    _status("IV ($label) Regression: $(d.dep_col) ~ $(join(xcols, " + "))")
    _status("  Endogenous: $(join(d.endog_names, ", "))")
    _status("  Excluded instruments: $(join(d.inst_names, ", "))  (instrument set Z: $(join(d.zcols, ", ")))")
    _status("  Observations: $(length(y)), Cov type: $cov_type")
    _status()

    model = try
        estimate_iv(y, X, Z; endogenous=endog_idx, cov_type=Symbol(cov_type),
                    method=Symbol(method), k=kval, fuller_a=fuller_a, varnames=xcols)
    catch e
        throw(_garch_variant_error(e, "IV ($label) estimation"))
    end

    coef_df = _reg_coef_table(model, xcols)
    output_result(coef_df; format=Symbol(format), output=output, title="IV ($label) Regression Coefficients")

    _status()
    pairs = Pair{String,Any}[
        "R²"              => round(r2(model); digits=6),
        "Adj. R²"         => round(model.adj_r2; digits=6),
    ]
    push!(pairs, "method" => method)
    isnothing(model.kclass_k)   || push!(pairs, "k-class k" => round(Float64(model.kclass_k); digits=6))
    isnothing(model.kappa_hat)  || push!(pairs, "kappa_hat" => round(Float64(model.kappa_hat); digits=6))
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

# ── Systems: SUR & 3SLS (C063, M5c) ─────────────────────────
# SURModel/ThreeSLSModel are not Tables.jl-registered upstream, so the coefficient
# table is hand-built (documented C051 exception, like the io family): one tidy row
# per (equation, term). Both are asymptotic (FGLS / 3SLS) → normal-approx p-values/CIs.

# Build a (y, X, names) equation tuple from column names; optionally prepend a constant.
function _system_eq_matrix(df, numcols::Vector{String}, eq::AbstractDict, intercept::Bool)
    eq["dep"] in numcols || throw(CliError("config/bad-column",
        "equation '$(eq["name"])': dependent column '$(eq["dep"])' not found in numeric columns: $(join(numcols, ", "))"))
    for c in eq["indep"]
        c in numcols || throw(CliError("config/bad-column",
            "equation '$(eq["name"])': regressor column '$c' not found in numeric columns: $(join(numcols, ", "))"))
    end
    y = Vector{Float64}(df[!, eq["dep"]])
    Xcols = [Vector{Float64}(df[!, c]) for c in eq["indep"]]
    X = intercept ? hcat(ones(Float64, length(y)), Xcols...) : reduce(hcat, Xcols)
    names = intercept ? String["const"; eq["indep"]...] : String[eq["indep"]...]
    return (y, X, names)   # (y, X, names) tuple for estimate_sur/estimate_3sls
end

# Per-equation instrument matrix (3SLS instruments=perequation); optional constant.
function _system_instr_matrix(df, numcols::Vector{String}, eq::AbstractDict, intercept::Bool)
    eq["instr"] === nothing && throw(CliError("config/missing-key",
        "instruments=perequation requires each [[equations]] block to set `instr`; equation '$(eq["name"])' has none"))
    for c in eq["instr"]
        c in numcols || throw(CliError("config/bad-column",
            "equation '$(eq["name"])': instrument '$c' not found in numeric columns"))
    end
    Zcols = [Vector{Float64}(df[!, c]) for c in eq["instr"]]
    intercept ? hcat(ones(Float64, size(df, 1)), Zcols...) : hcat(Zcols...)
end

# Tidy coefficient table for a SUR/ThreeSLS model: equation|term|estimate|std_error|stat|p_value|ci_lower|ci_upper.
function _system_coef_table(model)
    eqc = String[]; term = String[]; est = Float64[]; sec = Float64[]
    stat = Float64[]; pval = Float64[]; lo = Float64[]; hi = Float64[]
    z95 = 1.959964
    for j in eachindex(model.eqnames)
        b = model.betas[j]; s = model.ses[j]; vn = model.varnames[j]
        for i in eachindex(b)
            zi = s[i] == 0 ? 0.0 : b[i] / s[i]
            push!(eqc, model.eqnames[j]); push!(term, vn[i])
            push!(est, round(b[i]; digits=6)); push!(sec, round(s[i]; digits=6))
            push!(stat, round(zi; digits=4)); push!(pval, round(2.0 * (1.0 - _normal_cdf(abs(zi))); digits=4))
            push!(lo, round(b[i] - z95 * s[i]; digits=6)); push!(hi, round(b[i] + z95 * s[i]; digits=6))
        end
    end
    DataFrame(equation=eqc, term=term, estimate=est, std_error=sec,
              stat=stat, p_value=pval, ci_lower=lo, ci_upper=hi)
end

# Map an estimation failure to a typed CliError (never an uncaught exit-1 — io-family lesson).
function _system_estimation_error(e, what::String)
    e isa CliError && return e
    e isa ArgumentError && return CliError("config/system", sprint(showerror, e);
        hint="check equation specs: all equations need equal T, valid columns, and enough observations")
    return CliError("model/error", "$what estimation failed: $(sprint(showerror, e))";
        hint="near-singular system — drop collinear regressors or add observations")
end

function _estimate_sur(; data::String, config::String="", iterate::Bool=false,
                        no_intercept::Bool=false, output::String="", format::String="table")
    isempty(config) && throw(CliError("config/missing",
        "estimate sur requires --config <toml> with [[equations]] blocks (each `dep` + `indep`)"))
    df = load_data(data)
    numcols = variable_names(df)
    spec = get_system(load_config(config))
    intercept = !no_intercept
    eqs = [_system_eq_matrix(df, numcols, eq, intercept) for eq in spec["equations"]]
    eqnames = String[eq["name"] for eq in spec["equations"]]

    _status("SUR: $(length(eqs)) equations, $(intercept ? "with" : "no") intercept, iterate=$iterate")
    _status()
    model = try
        estimate_sur(eqs; iterate=iterate, eqnames=eqnames)
    catch e
        throw(_system_estimation_error(e, "SUR"))
    end

    output_result(_system_coef_table(model); format=Symbol(format), output=output,
                  title="SUR Coefficients")
    kind = model.iterated ? "Iterated SUR" : "SUR"
    output_kv(Pair{String,Any}[
        "estimator"  => model.restricted ? "$kind (restricted)" : kind,
        "equations"  => length(model.eqnames),
        "obs_per_eq" => model.nobs,
        "det_sigma"  => round(model.det_sigma; digits=6),
        "mcelroy_r2" => round(model.mcelroy_r2; digits=6),
        "loglik"     => round(model.loglik; digits=4),
        "iterations" => model.iterations,
    ]; format=format, title="SUR System Statistics")
    return model
end

function _estimate_3sls(; data::String, config::String="", instruments::String="common",
                         no_intercept::Bool=false, output::String="", format::String="table")
    isempty(config) && throw(CliError("config/missing",
        "estimate 3sls requires --config <toml> with [[equations]] and instruments"))
    df = load_data(data)
    numcols = variable_names(df)
    spec = get_system(load_config(config))
    intercept = !no_intercept
    eqs = [_system_eq_matrix(df, numcols, eq, intercept) for eq in spec["equations"]]
    eqnames = String[eq["name"] for eq in spec["equations"]]
    imode = Symbol(instruments)

    Z = if imode == :common
        spec["common_instruments"] === nothing && throw(CliError("config/missing",
            "instruments=common requires an [instruments] section with a `common` list"))
        for c in spec["common_instruments"]
            c in numcols || throw(CliError("config/bad-column",
                "instrument '$c' not found in numeric columns: $(join(numcols, ", "))"))
        end
        Zcols = [Vector{Float64}(df[!, c]) for c in spec["common_instruments"]]
        intercept ? hcat(ones(Float64, size(df, 1)), Zcols...) : hcat(Zcols...)
    else
        [_system_instr_matrix(df, numcols, eq, intercept) for eq in spec["equations"]]
    end

    _status("3SLS: $(length(eqs)) equations, instruments=$instruments, $(intercept ? "with" : "no") intercept")
    _status()
    model = try
        estimate_3sls(eqs, Z; instruments=imode, eqnames=eqnames)
    catch e
        throw(_system_estimation_error(e, "3SLS"))
    end

    output_result(_system_coef_table(model); format=Symbol(format), output=output,
                  title="3SLS Coefficients")
    output_kv(Pair{String,Any}[
        "estimator"          => "3SLS",
        "equations"          => length(model.eqnames),
        "obs_per_eq"         => model.nobs,
        "det_sigma"          => round(model.det_sigma; digits=6),
        "mcelroy_r2"         => round(model.mcelroy_r2; digits=6),
        "instruments_per_eq" => join(model.n_instruments, ", "),
    ]; format=format, title="3SLS System Statistics")
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
                         cov_type::String="cluster", ar1::String="none",
                         pcse_unbalanced::String="casewise",
                         id_col::String="", time_col::String="",
                         output::String="", format::String="table")
    # was a bare error() -> internal/error exit 1 for an ordinary usage mistake
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    # #75: Beck-Katz PCSE + Prais-Winsten AR(1). --pcse-unbalanced only affects the PCSE
    # covariance, so a mismatch is a usage error rather than a silent no-op.
    (cov_type == "pcse" || pcse_unbalanced == "casewise") || throw(CliError("usage/invalid",
        "estimate preg: --pcse-unbalanced applies only to --cov-type pcse (got --cov-type $cov_type)"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model_sym = _to_sym(method)
    cov_sym = _to_sym(cov_type)
    _status("Panel Regression ($method): $dep ~ $(join(indep_syms, " + "))")
    ar1 == "none" || _status("  Prais-Winsten AR(1): $ar1")
    cov_type == "pcse" && _status("  PCSE unbalanced handling: $pcse_unbalanced")
    _status()

    # Previously unwrapped: an upstream ArgumentError surfaced as exit 1.
    model = try
        estimate_xtreg(pd, Symbol(dep), indep_syms;
            model=model_sym, twoway=twoway, cov_type=cov_sym,
            ar1=_to_sym(replace(ar1, '-' => '_')),
            pcse_unbalanced=_to_sym(pcse_unbalanced))
    catch e
        throw(_garch_variant_error(e, "panel regression"))
    end

    coef_df = _preg_coef_table(model, model.varnames)
    output_result(coef_df; format=Symbol(format), output=output,
        title="Panel Regression Coefficients ($method)")

    _status()
    pairs = Pair{String,Any}[
        "R2 (within)"  => round(model.r2_within; digits=6),
        "R2 (between)" => round(model.r2_between; digits=6),
        "R2 (overall)" => round(model.r2_overall; digits=6),
        "F-statistic"  => round(model.f_stat; digits=4),
        "F p-value"    => round(hasproperty(model, :f_pval) ? model.f_pval :
                                (hasproperty(model, :f_pvalue) ? model.f_pvalue : NaN); digits=4),
        "N obs"        => model.n_obs,
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
        "N obs"           => model.n_obs,
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
        "N obs"           => model.n_obs,
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

    _status()
    # C051: MEMs tidy coef table (term|estimate|std_error|stat|p_value|ci_lower|ci_upper).
    output_result(DataFrame(model); format=Symbol(format), output=output, title="Ordered Logit Coefficients")

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

    _status()
    # C051: MEMs tidy coef table (term|estimate|std_error|stat|p_value|ci_lower|ci_upper).
    output_result(DataFrame(model); format=Symbol(format), output=output, title="Ordered Probit Coefficients")

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

    # C051: MEMs tidy coef table keyed by alternative — all categories in one table
    # (alternative|term|estimate|std_error|stat|p_value|ci_lower|ci_upper), replacing the
    # per-category loop of wide tables.
    output_result(DataFrame(model); format=Symbol(format), output=output,
                  title="Multinomial Logit Coefficients")
    _status()

    pairs = Pair{String,Any}[
        "Pseudo R2" => round(model.pseudo_r2; digits=6),
        "Log-likelihood" => round(model.loglik; digits=4),
        "AIC" => round(model.aic; digits=4), "BIC" => round(model.bic; digits=4),
        "Categories" => size(model.fitted, 2)]
    output_kv(pairs; format=format, title="Fit Statistics")
    return model
end

# ── C064a: univariate GARCH variants ─────────────────────────
# igarch / cgarch / aparch / figarch / fiegarch / garch-midas (MEMs 0.7.0 src/garch).
# None of these result types is registered in MEMs `_COEF_TABLE_TYPES`, so — per the
# C051 convention — their coefficient table is HAND-BUILT here (the same documented
# exception used by the SUR/3SLS systems leaves), not via `DataFrame(model)`.

"""Hand-built coefficient table for a GARCH-variant volatility model:
`parameter | estimate | std_error | z_stat | p_value`. Falls back to estimate-only
when the QMLE covariance is unavailable (non-finite SEs)."""
function _garch_variant_coef_table(model, param_names::Vector{String})
    c = Float64.(coef(model))
    names = param_names[1:length(c)]
    try
        se = Float64.(stderror(model))
        (length(se) == length(c) && all(isfinite, se)) || error("unavailable SEs")
        z = [se[i] == 0 ? 0.0 : c[i] / se[i] for i in eachindex(c)]
        pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
        return DataFrame(parameter=names, estimate=round.(c; digits=6),
                         std_error=round.(se; digits=6),
                         z_stat=round.(z; digits=4), p_value=round.(pv; digits=4))
    catch
        return DataFrame(parameter=names, estimate=round.(c; digits=6))
    end
end

"""Diagnostics kv for a GARCH-variant fit: log-lik, AIC/BIC, persistence,
convergence, iterations, plus any model-specific `extra` rows."""
function _garch_variant_diag(model; extra::Vector{<:Pair}=Pair{String,Any}[])
    pairs = Pair{String,Any}[
        "log_likelihood" => round(Float64(loglikelihood(model)); digits=4),
        "aic"            => round(Float64(model.aic); digits=4),
        "bic"            => round(Float64(model.bic); digits=4),
        "persistence"    => round(Float64(persistence(model)); digits=6),
        "converged"      => model.converged,
        "iterations"     => model.iterations,
    ]
    append!(pairs, extra)
    return pairs
end

"""Map an untyped MEMs volatility-estimation failure to a typed CliError — never an
uncaught exit-1 (io-family lesson). Bad-input `ArgumentError`/`DomainError` →
`data/invalid` (3); shape mismatch → `data/shape` (3); anything else → `model/error` (5)."""
function _garch_variant_error(e, label::String)
    e isa CliError && return e
    if e isa ArgumentError || e isa DomainError
        return CliError("data/invalid", "$label: $(sprint(showerror, e))";
            hint="check series length, orders (p/q), and parameter bounds")
    elseif e isa DimensionMismatch
        return CliError("data/shape", "$label: $(sprint(showerror, e))")
    end
    return CliError("model/error", "$label estimation failed: $(sprint(showerror, e))";
        hint="the QMLE optimizer did not converge — try a longer or cleaner return series")
end

# ── C065 nonlinear-TS shared renderers/mappers (reused by SETAR/STAR/MS sub-waves) ──
# The three nonlinear model types are NOT in MEMs `_COEF_TABLE_TYPES`, so every
# coefficient table is hand-built (the documented C051 exception, like io/mgarch/sur).

"""Tidy per-regime coefficient table for a nonlinear-TS model regime block:
`regime | term | estimate | std_error | z_stat | p_value` (large-sample normal
z/p, matching the `_garch_variant`/`dsge` `_normal_cdf` convention). Callers `vcat`
the two regime blocks into one table (C065a SETAR, reused by C065b STAR)."""
function _threshold_coef_table(betas::AbstractVector, ses::AbstractVector,
                               terms::Vector{String}, regime_label::String)
    b = Float64.(betas); s = Float64.(ses)
    n = length(b)
    tm = length(terms) == n ? terms : String["term$i" for i in 1:n]
    z  = [s[i] == 0.0 ? 0.0 : b[i] / s[i] for i in 1:n]
    pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    return DataFrame(regime=fill(regime_label, n), term=tm[1:n],
                     estimate=round.(b; digits=6), std_error=round.(s; digits=6),
                     z_stat=round.(z; digits=4), p_value=round.(pv; digits=4))
end

"""Map an untyped MEMs nonlinear-TS failure (SETAR/STAR/MS estimator, test, or
forecast) to a typed CliError — never an uncaught exit-1 on bad input (the standing
shared lesson). Same shape as `_garch_variant_error`: bad-input `ArgumentError`/
`DomainError` → `data/invalid` (3); external-series length mismatch → `data/shape`
(3); anything else (optimizer failure) → `model/error` (5); a `CliError` passes
through."""
function _nonlinear_error(e, label::String)
    e isa CliError && return e
    if e isa ArgumentError || e isa DomainError
        return CliError("data/invalid", "$label: $(sprint(showerror, e))";
            hint="check the series length, AR order p, delay d, trimming, and any external transition series")
    elseif e isa DimensionMismatch
        return CliError("data/shape", "$label: $(sprint(showerror, e))")
    end
    return CliError("model/error", "$label failed: $(sprint(showerror, e))";
        hint="the nonlinear optimizer did not converge — try a longer or cleaner series")
end

"""Parse a SETAR `--d` delay argument: the sentinel `"auto"` → `:auto` (=1:p grid
inside MEMs), else a positive integer. Junk or a non-positive integer → a typed
`usage/invalid` (never a raw parse throw). Shared by `estimate setar`/`forecast setar`."""
function _parse_setar_delay(d::AbstractString)
    lowercase(strip(d)) == "auto" && return :auto
    v = tryparse(Int, strip(d))
    v === nothing && throw(CliError("usage/invalid",
        "--d must be 'auto' or a positive integer (got '$d')"))
    v >= 1 || throw(CliError("usage/invalid", "--d must be ≥ 1 (got $v)"))
    return v
end

function _estimate_igarch(; data::String, column::Int=1, p::Int=1, q::Int=1,
                           output::String="", format::String="table")
    y, vname = load_univariate_series(data, column)
    _status("Estimating IGARCH($p,$q): variable=$vname, observations=$(length(y))")
    _status()
    model = try
        estimate_igarch(y, p, q)
    catch e
        throw(_garch_variant_error(e, "IGARCH"))
    end
    names = String["mu"; "omega"; ["alpha$i" for i in 1:q]; ["beta$i" for i in 1:p]]
    output_result(_garch_variant_coef_table(model, names); format=Symbol(format),
                  output=output, title="IGARCH($p,$q) Coefficients ($vname)")
    output_kv(_garch_variant_diag(model); format=format, title="IGARCH($p,$q) Diagnostics")
    return model
end

function _estimate_cgarch(; data::String, column::Int=1,
                           output::String="", format::String="table")
    y, vname = load_univariate_series(data, column)
    _status("Estimating Component-GARCH(1,1): variable=$vname, observations=$(length(y))")
    _status()
    model = try
        estimate_cgarch(y)
    catch e
        throw(_garch_variant_error(e, "CGARCH"))
    end
    names = String["mu", "omega", "rho", "phi", "alpha", "beta"]
    output_result(_garch_variant_coef_table(model, names); format=Symbol(format),
                  output=output, title="Component-GARCH(1,1) Coefficients ($vname)")
    output_kv(_garch_variant_diag(model; extra=Pair{String,Any}[
        "transitory_persistence" => round(Float64(model.alpha + model.beta); digits=6),
        "unconditional_variance" => round(Float64(unconditional_variance(model)); digits=6),
    ]); format=format, title="Component-GARCH Diagnostics")
    return model
end

function _estimate_aparch(; data::String, column::Int=1, p::Int=1, q::Int=1,
                           fix_delta=nothing, fix_gamma=nothing,
                           output::String="", format::String="table")
    y, vname = load_univariate_series(data, column)
    fd = fix_delta === nothing ? nothing : Float64(fix_delta)
    fg = fix_gamma === nothing ? nothing : Float64(fix_gamma)
    _status("Estimating APARCH($p,$q): variable=$vname, observations=$(length(y))" *
            (fd === nothing ? "" : ", fix_delta=$fd") * (fg === nothing ? "" : ", fix_gamma=$fg"))
    _status()
    model = try
        estimate_aparch(y, p, q; fix_delta=fd, fix_gamma=fg)
    catch e
        throw(_garch_variant_error(e, "APARCH"))
    end
    names = String["mu"; "omega"; ["alpha$i" for i in 1:q]; ["gamma$i" for i in 1:q]; ["beta$i" for i in 1:p]; "delta"]
    output_result(_garch_variant_coef_table(model, names); format=Symbol(format),
                  output=output, title="APARCH($p,$q) Coefficients ($vname)")
    output_kv(_garch_variant_diag(model; extra=Pair{String,Any}[
        "delta" => round(Float64(model.delta); digits=6),
        "n_params" => model.n_params,
    ]); format=format, title="APARCH Diagnostics")
    return model
end

function _estimate_figarch(; data::String, column::Int=1, p::Int=1, q::Int=1,
                            d0::Float64=0.4, truncation::Int=1000, dist::String="normal",
                            output::String="", format::String="table")
    y, vname = load_univariate_series(data, column)
    _status("Estimating FIGARCH($p,d,$q): variable=$vname, observations=$(length(y)), d0=$d0, truncation=$truncation")
    _status()
    model = try
        estimate_figarch(y; p=p, q=q, d0=d0, truncation=truncation, dist=Symbol(dist))
    catch e
        throw(_garch_variant_error(e, "FIGARCH"))
    end
    names = String["mu"; "omega"; ["phi$i" for i in 1:q]; ["beta$i" for i in 1:p]; "d"]
    output_result(_garch_variant_coef_table(model, names); format=Symbol(format),
                  output=output, title="FIGARCH($p,d,$q) Coefficients ($vname)")
    output_kv(_garch_variant_diag(model; extra=Pair{String,Any}[
        "d" => round(Float64(model.d); digits=6),
        "truncation" => model.truncation,
        "n_neg_lambda" => model.n_neg_lambda,
    ]); format=format, title="FIGARCH Diagnostics")
    return model
end

function _estimate_fiegarch(; data::String, column::Int=1, p::Int=1, q::Int=1,
                             d0::Float64=0.4, truncation::Int=1000, dist::String="normal",
                             output::String="", format::String="table")
    y, vname = load_univariate_series(data, column)
    _status("Estimating FIEGARCH($p,d,$q): variable=$vname, observations=$(length(y)), d0=$d0, truncation=$truncation")
    _status()
    model = try
        estimate_fiegarch(y; p=p, q=q, d0=d0, truncation=truncation, dist=Symbol(dist))
    catch e
        throw(_garch_variant_error(e, "FIEGARCH"))
    end
    names = String["mu"; "omega"; "theta"; "gamma"; ["phi$i" for i in 1:q]; ["beta$i" for i in 1:p]; "d"]
    output_result(_garch_variant_coef_table(model, names); format=Symbol(format),
                  output=output, title="FIEGARCH($p,d,$q) Coefficients ($vname)")
    output_kv(_garch_variant_diag(model; extra=Pair{String,Any}[
        "d" => round(Float64(model.d); digits=6),
        "truncation" => model.truncation,
    ]); format=format, title="FIEGARCH Diagnostics")
    return model
end

function _estimate_garch_midas(; data::String, column::Int=1, m_freq::Int=0, k::Int=12,
                                rv::String="realized", span::String="fixed", config::String="",
                                output::String="", format::String="table")
    m_freq >= 1 || throw(CliError("usage/missing-option",
        "estimate garch-midas requires --m-freq ≥ 1 (high-frequency observations per low-frequency block)"))
    rv_sym = Symbol(rv); span_sym = Symbol(span)
    rv_sym in (:realized, :macro) || throw(CliError("usage/bad-value", "--rv must be realized|macro, got $rv"))
    span_sym in (:fixed, :rolling) || throw(CliError("usage/bad-value", "--span must be fixed|rolling, got $span"))
    y, vname = load_univariate_series(data, column)
    x_lf = Float64[]
    if rv_sym === :macro
        isempty(config) && throw(CliError("config/missing",
            "--rv macro requires --config <toml> with a [garch_midas] x_lf = [...] low-frequency driver"))
        x_lf = get_garch_midas(load_config(config))
    end
    _status("Estimating GARCH-MIDAS: variable=$vname, observations=$(length(y)), K=$k, m_freq=$m_freq, rv=$rv, span=$span")
    _status()
    model = try
        estimate_garch_midas(y, x_lf; K=k, m_freq=m_freq, rv=rv_sym, span=span_sym)
    catch e
        throw(_garch_variant_error(e, "GARCH-MIDAS"))
    end
    names = String["mu", "alpha", "beta", "m", "theta", "w"]
    output_result(_garch_variant_coef_table(model, names); format=Symbol(format),
                  output=output, title="GARCH-MIDAS Coefficients ($vname)")
    output_kv(_garch_variant_diag(model; extra=Pair{String,Any}[
        "variance_ratio" => round(Float64(model.variance_ratio); digits=6),
        "K" => model.K, "m_freq" => model.m_freq, "n_blocks" => model.n_blocks,
        "rv" => String(model.rv), "span" => String(model.span),
    ]); format=format, title="GARCH-MIDAS Diagnostics")
    return model
end

# ── C064b: multivariate GARCH (MGARCH) ───────────────────────
# ccc / dcc (cDCC) / bekk (MEMs 0.7.0 src/mgarch). `MGARCHModel` is not registered in
# MEMs `_COEF_TABLE_TYPES`; the second-stage dynamics table is hand-built via the shared
# `_garch_variant_coef_table`, and the conditional-correlation matrix renders WIDE
# (sector×sector) — the documented C051 exception, same as the io family.

"""Wide sector×sector correlation DataFrame with a leading `series` label column.
`makeunique=true` guards the case where an input column is literally named `series`
(the label would otherwise collide → uncaught `ArgumentError` → exit-1) and any duplicate
input headers; the colliding label is renamed (`series_1`) rather than crashing."""
_mgarch_corr_df(R::AbstractMatrix, names::Vector{String}) =
    insertcols!(DataFrame(round.(R; digits=6), names; makeunique=true), 1,
                :series => names; makeunique=true)

"""Shared renderer for an MGARCH fit: headline conditional-correlation matrix (wide),
second-stage dynamics coefficients (skipped for CCC, which has none), and a diagnostics
kv block. Follows the repo convention of routing `--output` to the headline table only
(same as the C064a / mlogit handlers) so a `-o file` export is not overwritten by the
subsequent blocks."""
function _mgarch_output(model, varnames::Vector{String}, label::String;
                        format::String="table", output::String="")
    R = correlations(model)[:, :, end]   # constant matrix for CCC/BEKK; last DCC slice
    n = size(R, 1)
    names = length(varnames) >= n ? varnames[1:n] : String["series_$i" for i in 1:n]
    output_result(_mgarch_corr_df(R, names); format=Symbol(format), output=output,
                  title="$label Conditional Correlation")
    if !isempty(coef(model))
        output_result(_garch_variant_coef_table(model, model.param_names);
                      format=Symbol(format), title="$label Dynamics Parameters")
    end
    pairs = Pair{String,Any}[
        "loglik"       => round(Float64(loglikelihood(model)); digits=4),
        "aic"          => round(Float64(model.aic); digits=4),
        "bic"          => round(Float64(model.bic); digits=4),
        "series"       => model.n,
        "observations" => size(model.Y, 1),
        "converged"    => model.converged,
        "kind"         => string(model.kind),
    ]
    if model.kind === :dcc
        push!(pairs, "correction" => string(model.correction))
        push!(pairs, "persistence" => round(Float64(sum(coef(model))); digits=6))
    elseif model.kind === :bekk
        push!(pairs, "bekk_kind" => string(model.bekk_kind))
    end
    output_kv(pairs; format=format, title="$label Diagnostics")
    return nothing
end

function _estimate_ccc(; data::String, p::Int=1, q::Int=1,
                        output::String="", format::String="table")
    Y, varnames = load_multivariate_data(data)
    _status("Estimating CCC-GARCH: series=$(size(Y,2)), observations=$(size(Y,1)), margins=GARCH($p,$q)")
    _status()
    model = try
        estimate_ccc(Y; p=p, q=q)
    catch e
        throw(_garch_variant_error(e, "CCC-GARCH"))
    end
    _mgarch_output(model, varnames, "CCC-GARCH"; format=format, output=output)
    return model
end

function _estimate_dcc(; data::String, p::Int=1, q::Int=1, correction::String="none",
                        output::String="", format::String="table")
    correction in ("none", "aielli") || throw(CliError("usage/invalid",
        "estimate dcc: --correction must be none|aielli, got $correction"))
    Y, varnames = load_multivariate_data(data)
    _status("Estimating DCC-GARCH: series=$(size(Y,2)), observations=$(size(Y,1)), margins=GARCH($p,$q), correction=$correction")
    _status()
    model = try
        estimate_dcc(Y; p=p, q=q, correction=Symbol(correction))
    catch e
        throw(_garch_variant_error(e, "DCC-GARCH"))
    end
    label = correction == "aielli" ? "cDCC-GARCH" : "DCC-GARCH"
    _mgarch_output(model, varnames, label; format=format, output=output)
    return model
end

function _estimate_bekk(; data::String, kind::String="scalar",
                         output::String="", format::String="table")
    kind in ("scalar", "diagonal") || throw(CliError("usage/invalid",
        "estimate bekk: --kind must be scalar|diagonal, got $kind"))
    Y, varnames = load_multivariate_data(data)
    _status("Estimating BEKK-$kind GARCH: series=$(size(Y,2)), observations=$(size(Y,1))")
    _status()
    model = try
        estimate_bekk(Y; kind=Symbol(kind))
    catch e
        throw(_garch_variant_error(e, "BEKK-GARCH"))
    end
    _mgarch_output(model, varnames, "BEKK-$kind"; format=format, output=output)
    return model
end

# ── C067a: penalized & limited-dependent cross-section regression ─────────────
# lasso / ridge / elastic-net (→ PenalizedRegModel), robust (→ RobustRegModel),
# tobit (→ TobitModel), MEMs 0.7.0 src/reg/{penalized,robust,tobit}. All take (y, X)
# via the shared `_load_reg_data` loader (X = numeric columns except --dep; no constant
# prepended, mirroring `estimate reg`). None of the three result types is registered in
# MEMs `_COEF_TABLE_TYPES`, so their coefficient tables are HAND-BUILT (the documented
# C051 exception, same as the systems/volatility waves).

"""Hand-built coefficient table for a penalized (Lasso/Ridge/Elastic-Net) fit:
`term | estimate | nonzero`, with the intercept (`beta0`) prepended. Penalized fits
carry no standard errors (`stderror(::PenalizedRegModel)` is undefined upstream), so this
is estimate-only — the C051-documented hand-built exception."""
function _penalized_coef_table(model, xcols::Vector{String})
    names = String["(Intercept)"; xcols[1:length(model.beta)]]
    est = Float64[model.beta0; model.beta]
    DataFrame(term=names, estimate=round.(est; digits=6), nonzero=(est .!= 0.0))
end

"""Diagnostics kv for a penalized fit: mixing `alpha`, selected `lambda`, active-set
size, fit `r2`, information criteria, and the selection rule."""
function _penalized_diag(model)
    Pair{String,Any}[
        "alpha"    => round(Float64(model.alpha); digits=4),
        "lambda"   => round(Float64(model.lambda); digits=6),
        "n_active" => count(!=(0.0), model.beta),
        "r2"       => round(Float64(model.r2); digits=6),
        "aic"      => round(Float64(model.aic); digits=4),
        "bic"      => round(Float64(model.bic); digits=4),
        "ebic"     => round(Float64(model.ebic); digits=4),
        "select"   => string(model.select),
    ]
end

"""Parse a penalized-regression `--lambda`: `auto`/`cv` → `:cv` (auto-select a path);
otherwise a non-negative number. Junk or a negative value → a typed usage error (never a
raw MEMs `ArgumentError`)."""
function _parse_penalty_lambda(s::AbstractString)
    (s == "auto" || s == "cv") && return :cv
    v = tryparse(Float64, s)
    v === nothing && throw(CliError("usage/invalid",
        "--lambda must be `auto` or a non-negative number, got '$s'"))
    v < 0 && throw(CliError("usage/invalid",
        "--lambda must be non-negative, got $v"))
    return v
end

function _estimate_lasso(; data::String, dep::String="", lambda::String="auto",
                          select::String="cv", output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    lam = _parse_penalty_lambda(lambda)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("LASSO (L1) regression: $dep_name ~ $(join(xcols, " + ")), n=$(length(y)), lambda=$lambda")
    _status()
    model = try
        estimate_lasso(y, X; lambda=lam, select=Symbol(select), varnames=xcols)
    catch e
        throw(_garch_variant_error(e, "LASSO"))
    end
    output_result(_penalized_coef_table(model, xcols); format=Symbol(format), output=output,
                  title="LASSO Coefficients")
    output_kv(_penalized_diag(model); format=format, title="LASSO Diagnostics")
    return model
end

function _estimate_ridge(; data::String, dep::String="", lambda::String="auto",
                          select::String="cv", output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    lam = _parse_penalty_lambda(lambda)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Ridge (L2) regression: $dep_name ~ $(join(xcols, " + ")), n=$(length(y)), lambda=$lambda")
    _status()
    model = try
        estimate_ridge(y, X; lambda=lam, select=Symbol(select), varnames=xcols)
    catch e
        throw(_garch_variant_error(e, "Ridge"))
    end
    output_result(_penalized_coef_table(model, xcols); format=Symbol(format), output=output,
                  title="Ridge Coefficients")
    output_kv(_penalized_diag(model); format=format, title="Ridge Diagnostics")
    return model
end

function _estimate_elastic_net(; data::String, dep::String="", alpha::Float64=0.5,
                                lambda::String="auto", select::String="cv",
                                output::String="", format::String="table")
    (0.0 <= alpha <= 1.0) || throw(CliError("usage/invalid",
        "estimate elastic-net: --alpha must be in [0,1], got $alpha"))
    y, X, xcols = _load_reg_data(data, dep)
    lam = _parse_penalty_lambda(lambda)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Elastic-Net regression (alpha=$alpha): $dep_name ~ $(join(xcols, " + ")), n=$(length(y)), lambda=$lambda")
    _status()
    model = try
        estimate_elastic_net(y, X; alpha=alpha, lambda=lam, select=Symbol(select), varnames=xcols)
    catch e
        throw(_garch_variant_error(e, "Elastic-Net"))
    end
    output_result(_penalized_coef_table(model, xcols); format=Symbol(format), output=output,
                  title="Elastic-Net Coefficients")
    output_kv(_penalized_diag(model); format=format, title="Elastic-Net Diagnostics")
    return model
end

function _estimate_robust(; data::String, dep::String="", psi::String="huber",
                           method::String="m", output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Robust regression ($psi $method-estimator): $dep_name ~ $(join(xcols, " + ")), n=$(length(y))")
    _status()
    model = try
        estimate_robust(y, X; psi=Symbol(psi), method=Symbol(method))
    catch e
        throw(_garch_variant_error(e, "Robust regression"))
    end
    output_result(_garch_variant_coef_table(model, xcols); format=Symbol(format), output=output,
                  title="Robust Regression Coefficients")
    output_kv(Pair{String,Any}[
        "psi"        => string(model.psi),
        "method"     => string(model.method),
        "scale"      => round(Float64(model.scale); digits=6),
        "robust_r2"  => round(Float64(model.robust_r2); digits=6),
        "tuning"     => round(Float64(model.tuning); digits=6),
        "converged"  => model.converged,
        "iterations" => model.iterations,
    ]; format=format, title="Robust Regression Diagnostics")
    return model
end

function _estimate_tobit(; data::String, dep::String="", lower::Float64=0.0,
                          upper::Float64=Inf, output::String="", format::String="table")
    lower < upper || throw(CliError("usage/invalid",
        "estimate tobit: --lower ($lower) must be < --upper ($upper)"))
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Tobit regression (lower=$lower, upper=$upper): $dep_name ~ $(join(xcols, " + ")), n=$(length(y))")
    _status()
    model = try
        estimate_tobit(y, X; lower=lower, upper=upper)
    catch e
        throw(_garch_variant_error(e, "Tobit regression"))
    end
    output_result(_garch_variant_coef_table(model, xcols); format=Symbol(format), output=output,
                  title="Tobit Coefficients")
    output_kv(Pair{String,Any}[
        "sigma"            => round(Float64(model.sigma); digits=6),
        "loglik"           => round(Float64(model.loglik); digits=4),
        "aic"              => round(Float64(model.aic); digits=4),
        "bic"              => round(Float64(model.bic); digits=4),
        # Render ±Inf bounds as strings: a raw Inf/-Inf Float crashes the legacy
        # (FRIEDMAN_LEGACY_OUTPUT) JSON writer, which — unlike the envelope path — does not
        # apply `_json_safe` ("Inf not allowed in JSON spec"). Matches the envelope output.
        "lower"            => isfinite(model.lower) ? Float64(model.lower) : string(model.lower),
        "upper"            => isfinite(model.upper) ? Float64(model.upper) : string(model.upper),
        "n_censored_left"  => model.n_censored_left,
        "n_censored_right" => model.n_censored_right,
        "converged"        => model.converged,
    ]; format=format, title="Tobit Diagnostics")
    return model
end

# ── C067b: truncated-normal regression (Hausman-Wise) ──────────
# TruncRegModel shares TobitModel's `coef`/`stderror` (StatsAPI) so the coefficient table
# reuses `_garch_variant_coef_table`. It is NOT in MEMs `_COEF_TABLE_TYPES` (same documented
# C051 hand-built exception as Tobit/robust). Bad input (any y outside (lower,upper), or a
# missing cell) is mapped to a typed data error via `_garch_variant_error`/`_load_reg_data`.
function _estimate_truncreg(; data::String, dep::String="", lower::Float64=0.0,
                             upper::Float64=Inf, output::String="", format::String="table")
    lower < upper || throw(CliError("usage/invalid",
        "estimate truncreg: --lower ($lower) must be < --upper ($upper)"))
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Truncated regression (lower=$lower, upper=$upper): $dep_name ~ $(join(xcols, " + ")), n=$(length(y))")
    _status()
    model = try
        estimate_truncreg(y, X; lower=lower, upper=upper)
    catch e
        throw(_garch_variant_error(e, "Truncated regression"))
    end
    output_result(_garch_variant_coef_table(model, xcols); format=Symbol(format), output=output,
                  title="Truncated Regression Coefficients")
    output_kv(Pair{String,Any}[
        "sigma"        => round(Float64(model.sigma); digits=6),
        "sigma_se"     => round(Float64(model.sigma_se); digits=6),
        "loglik"       => round(Float64(model.loglik); digits=4),
        "aic"          => round(Float64(model.aic); digits=4),
        "bic"          => round(Float64(model.bic); digits=4),
        # ±Inf bounds → strings (legacy JSON writer rejects non-finite floats; see Tobit).
        "lower"        => isfinite(model.lower) ? Float64(model.lower) : string(model.lower),
        "upper"        => isfinite(model.upper) ? Float64(model.upper) : string(model.upper),
        "n_truncated"  => model.n_truncated,
        "converged"    => model.converged,
    ]; format=format, title="Truncated Regression Diagnostics")
    return model
end

# ── C067b: Heckman sample-selection model (two-step / FIML) ─────
# HeckmanModel is a TWO-equation result (outcome β + selection γ) → the coefficient table is
# hand-built as one tidy `equation|term|estimate|std_error|z_stat|p_value` frame (C051 tidy
# convention: the `equation` column carries outcome/selection, like VAR/panel prepend one).
# SEs come from the stored vcov blocks; z/p are normal-approx (both estimators are asymptotic).
function _heckman_coef_table(model)
    eqc = String[]; term = String[]; est = Float64[]; sec = Float64[]
    _append! = (eqname, names, beta, vcov) -> begin
        se = sqrt.(max.(diag(vcov), 0.0))
        for i in eachindex(beta)
            push!(eqc, eqname); push!(term, names[i])
            push!(est, Float64(beta[i])); push!(sec, Float64(se[i]))
        end
    end
    _append!("outcome",   model.outcome_names, model.beta,  model.vcov_beta)
    _append!("selection", model.select_names,  model.gamma, model.vcov_gamma)
    z  = [sec[i] == 0.0 ? 0.0 : est[i] / sec[i] for i in eachindex(est)]
    pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    DataFrame(equation=eqc, term=term, estimate=round.(est; digits=6),
              std_error=round.(sec; digits=6), z_stat=round.(z; digits=4),
              p_value=round.(pv; digits=4))
end

function _estimate_heckman(; data::String, dep::String="", select::String="",
                            outcome_vars::String="", select_vars::String="",
                            method::String="twostep", output::String="", format::String="table")
    method in ("twostep", "mle") || throw(CliError("usage/invalid",
        "estimate heckman: --method must be twostep or mle, got '$method'"))
    isempty(select) && throw(CliError("usage/missing",
        "--select is required (the binary 0/1 selection-indicator column)"))
    isempty(outcome_vars) && throw(CliError("usage/missing",
        "--outcome-vars is required (comma-separated outcome-equation regressor columns)"))
    isempty(select_vars) && throw(CliError("usage/missing",
        "--select-vars is required (comma-separated selection-equation regressor columns)"))

    df = load_data(data)
    numcols = variable_names(df)
    dep_col = isempty(dep) ? numcols[1] : dep
    !isempty(dep) && !(dep_col in numcols) && throw(CliError("data/column-range",
        "outcome variable '$dep_col' not found in numeric columns: $(join(numcols, ", "))"))
    select in numcols || throw(CliError("data/column-range",
        "selection indicator '$select' not found in numeric columns: $(join(numcols, ", "))"))

    ovars = String[strip(s) for s in split(outcome_vars, ",") if !isempty(strip(s))]
    svars = String[strip(s) for s in split(select_vars, ",") if !isempty(strip(s))]
    isempty(ovars) && throw(CliError("usage/missing", "--outcome-vars resolved to no columns"))
    isempty(svars) && throw(CliError("usage/missing", "--select-vars resolved to no columns"))
    for nm in ovars
        nm in numcols || throw(CliError("data/column-range",
            "outcome regressor '$nm' not found in numeric columns: $(join(numcols, ", "))"))
    end
    for nm in svars
        nm in numcols || throw(CliError("data/column-range",
            "selection regressor '$nm' not found in numeric columns: $(join(numcols, ", "))"))
    end
    # Guard missing cells in the selection indicator and BOTH regressor sets (needed for every
    # row) BEFORE the Matrix{Float64} conversion (untyped ArgumentError → exit-1). The OUTCOME
    # column is handled separately below: it is unobserved by design for non-selected rows.
    for c in unique(vcat([select], ovars, svars))
        any(ismissing, df[!, c]) && throw(CliError("data/missing-values",
            "column '$c' contains missing values; drop or impute them first"))
    end

    d = Vector{Float64}(df[!, select])
    # Binary-indicator guard up front → typed usage error (MEMs also checks, but this gives a
    # clearer message than the wrapped ArgumentError).
    all(v -> v == 0.0 || v == 1.0, d) || throw(CliError("data/invalid",
        "selection indicator '$select' must be binary 0/1"))
    sel = findall(==(1.0), d)

    # The outcome is observed ONLY for selected (d==1) rows — MEMs uses `y[sel]` and only
    # requires those to be finite (heckman.jl). So a blank/missing outcome for NON-selected
    # rows is the canonical incidental-truncation layout, not an error: require the outcome
    # present for selected rows, and fill unselected cells with a finite placeholder (0.0,
    # ignored downstream). This makes real selection CSVs usable without pre-imputing.
    yraw = df[!, dep_col]
    any(ismissing, yraw[sel]) && throw(CliError("data/missing-values",
        "outcome '$dep_col' has missing values among SELECTED ($select==1) rows; the outcome must be observed wherever the unit is selected"))
    y = Float64[ismissing(v) ? 0.0 : Float64(v) for v in yraw]
    X = Matrix{Float64}(df[!, ovars])
    Z = Matrix{Float64}(df[!, svars])

    n_sel = length(sel)
    _status("Heckman selection ($method): $dep_col ~ $(join(ovars, " + ")) | select $select ~ $(join(svars, " + "))")
    _status("  Observations: $(length(y)) ($n_sel selected), exclusion vars in selection: $(join(setdiff(svars, ovars), ", "))")
    _status()

    model = try
        estimate_heckman(y, X, d, Z; method=Symbol(method),
                         outcome_names=ovars, select_names=svars)
    catch e
        throw(_garch_variant_error(e, "Heckman selection model"))
    end

    output_result(_heckman_coef_table(model); format=Symbol(format), output=output,
                  title="Heckman Coefficients (outcome + selection)")
    output_kv(Pair{String,Any}[
        "method"      => string(model.method),
        "rho"         => round(Float64(model.rho); digits=6),
        "rho_se"      => isfinite(model.rho_se) ? round(Float64(model.rho_se); digits=6) : string(model.rho_se),
        "sigma"       => round(Float64(model.sigma); digits=6),
        "sigma_se"    => isfinite(model.sigma_se) ? round(Float64(model.sigma_se); digits=6) : string(model.sigma_se),
        "lambda"      => round(Float64(model.lambda); digits=6),
        "lambda_se"   => isfinite(model.lambda_se) ? round(Float64(model.lambda_se); digits=6) : string(model.lambda_se),
        "loglik"      => round(Float64(model.loglik); digits=4),
        "aic"         => round(Float64(model.aic); digits=4),
        "bic"         => round(Float64(model.bic); digits=4),
        "n_selected"  => model.n_selected,
        "n_total"     => model.n_total,
        "converged"   => model.converged,
    ]; format=format, title="Heckman Diagnostics")
    return model
end

# ── C066: state-space + nonparametric estimation (M5c) ─────────
# None of StateSpaceModel/KernelDensity/KernelRegression/LowessFit is registered in MEMs
# `_COEF_TABLE_TYPES`, so all tables are HAND-BUILT (the documented C051 exception, like
# io/mgarch/sur). MEMs calls are wrapped → typed CliError via `_garch_variant_error`.

"""Hand-built parameter table for a fitted `StateSpaceModel`: `parameter | estimate`,
pairing `param_names` with the estimated (natural-scale) hyper-parameters `theta`. No SEs —
theta standard errors are not exposed upstream."""
function _statespace_param_table(model)
    names = String.(model.param_names)
    th = Float64.(model.theta)
    m = min(length(names), length(th))
    DataFrame(parameter=names[1:m], estimate=round.(th[1:m]; digits=6))
end

"""Tidy LONG coefficient-path table for a TVP regression: one row per (period, coefficient)
from the `smoothed_state` (T×k) — `period | coefficient | estimate` — the time-varying βₜ."""
function _tvp_path_table(model, coefnames::Vector{String})
    S = model.smoothed_state
    Tn, k = size(S)
    kk = min(k, length(coefnames))
    period = Int[]; coefficient = String[]; estimate = Float64[]
    for t in 1:Tn, j in 1:kk
        push!(period, t); push!(coefficient, coefnames[j])
        push!(estimate, round(Float64(S[t, j]); digits=6))
    end
    DataFrame(period=period, coefficient=coefficient, estimate=estimate)
end

# estimate statespace — structural univariate state-space (local level / local linear trend)
function _estimate_statespace(; data::String, column::Int=1, model::String="local-level",
                               init_mode::String="kappa", kappa::Float64=1e6,
                               output::String="", format::String="table")
    model in ("local-level", "local-linear-trend") || throw(CliError("usage/invalid",
        "estimate statespace: --model must be local-level or local-linear-trend, got '$model'"))
    init_mode in ("kappa", "diffuse") || throw(CliError("usage/invalid",
        "estimate statespace: --init-mode must be kappa or diffuse, got '$init_mode'"))
    y, vname = load_univariate_series(data, column)
    _status("State-space $model: variable=$vname, observations=$(length(y)), init_mode=$init_mode")
    _status()
    im = Symbol(init_mode)
    ssm = try
        model == "local-level" ? local_level(y; init_mode=im, kappa=kappa) :
                                 local_linear_trend(y; init_mode=im, kappa=kappa)
    catch e
        throw(_garch_variant_error(e, "State-space estimation"))
    end
    output_result(_statespace_param_table(ssm); format=Symbol(format), output=output,
                  title="State-Space Hyper-Parameters ($model, $vname)")
    output_kv(Pair{String,Any}[
        "model"     => model,
        # loglik/theta can be non-finite if the optimizer stalls — string-render (legacy-JSON
        # writer rejects non-finite floats; see the C067a Inf gotcha).
        "loglik"    => isfinite(ssm.loglik) ? round(Float64(ssm.loglik); digits=4) : string(ssm.loglik),
        "converged" => ssm.converged,
        "n_state"   => ssm.n_state,
        "n_obs"     => ssm.T_obs,   # T_obs = number of time observations (the user-facing "n_obs")
        "method"    => string(ssm.method),
    ]; format=format, title="State-Space Diagnostics")
    return ssm
end

# estimate tvp — time-varying-parameter regression (random-walk coefficients)
function _estimate_tvp(; data::String, dep::String="", init_mode::String="kappa",
                        kappa::Float64=1e6, no_intercept::Bool=false,
                        output::String="", format::String="table")
    init_mode in ("kappa", "diffuse") || throw(CliError("usage/invalid",
        "estimate tvp: --init-mode must be kappa or diffuse, got '$init_mode'"))
    y, X, xcols = _load_reg_data(data, dep)   # X = numeric cols except --dep; estimate_tvp_reg adds its own intercept
    intercept = !no_intercept
    coefnames = intercept ? vcat(["intercept"], xcols) : xcols
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Time-varying-parameter regression: $dep_name ~ $(join(xcols, " + "))" *
            (intercept ? " (+ intercept)" : "") * ", n=$(length(y)), init_mode=$init_mode")
    _status()
    ssm = try
        estimate_tvp_reg(y, X; intercept=intercept, init_mode=Symbol(init_mode), kappa=kappa)
    catch e
        throw(_garch_variant_error(e, "TVP regression"))
    end
    output_result(_statespace_param_table(ssm); format=Symbol(format), output=output,
                  title="TVP Hyper-Parameters")
    output_result(_tvp_path_table(ssm, coefnames); format=Symbol(format),
                  output=_per_var_output_path(output, "path"), title="TVP Coefficient Paths")
    output_kv(Pair{String,Any}[
        "loglik"    => isfinite(ssm.loglik) ? round(Float64(ssm.loglik); digits=4) : string(ssm.loglik),
        "converged" => ssm.converged,
        "n_coef"    => ssm.n_state,
        "intercept" => intercept,
        "method"    => string(ssm.method),
    ]; format=format, title="TVP Diagnostics")
    return ssm
end

# estimate kde — univariate kernel density estimate
_kde_table(kd) = DataFrame(x=round.(Float64.(kd.x); digits=6),
                           density=round.(Float64.(kd.density); digits=6))

function _estimate_kde(; data::String, column::Int=1, kernel::String="gaussian",
                        bw::String="silverman", npoints::Int=512, cut::Float64=3.0,
                        output::String="", format::String="table")
    kernel in ("gaussian", "epanechnikov", "triangular", "uniform") || throw(CliError("usage/invalid",
        "estimate kde: --kernel must be gaussian|epanechnikov|triangular|uniform, got '$kernel'"))
    npoints >= 2 || throw(CliError("usage/invalid",
        "estimate kde: --npoints must be ≥ 2, got $npoints"))
    y, vname = load_univariate_series(data, column)
    bwv = _parse_bandwidth(bw, (:silverman, :sj))
    _status("Kernel density: variable=$vname, observations=$(length(y)), kernel=$kernel, bw=$bw")
    _status()
    kd = try
        kernel_density(y; kernel=Symbol(kernel), bw=bwv, npoints=npoints, cut=cut)
    catch e
        throw(_garch_variant_error(e, "Kernel density"))
    end
    output_result(_kde_table(kd); format=Symbol(format), output=output,
                  title="Kernel Density Estimate ($vname)")
    output_kv(Pair{String,Any}[
        "kernel"    => string(kd.kernel),
        "bw_method" => string(kd.bw_method),
        "bandwidth" => round(Float64(kd.bandwidth); digits=6),
        "nobs"      => kd.nobs,
    ]; format=format, title="Kernel Density Diagnostics")
    return kd
end

# estimate kernel-reg — Nadaraya-Watson / local-linear / local-polynomial regression
_kernel_reg_table(kr) = DataFrame(x=round.(Float64.(kr.x); digits=6),
                                  fitted=round.(Float64.(kr.fitted); digits=6),
                                  se=round.(Float64.(kr.se); digits=6))

function _estimate_kernel_reg(; data::String, dep::String="", indep::String="",
                               method::String="ll", degree::Int=1, bw::String="cv",
                               kernel::String="gaussian", output::String="", format::String="table")
    method in ("nw", "ll", "lp") || throw(CliError("usage/invalid",
        "estimate kernel-reg: --method must be nw|ll|lp, got '$method'"))
    kernel in ("gaussian", "epanechnikov", "triangular", "uniform") || throw(CliError("usage/invalid",
        "estimate kernel-reg: --kernel must be gaussian|epanechnikov|triangular|uniform, got '$kernel'"))
    degree >= 0 || throw(CliError("usage/invalid",
        "estimate kernel-reg: --degree must be ≥ 0, got $degree"))
    y, x, ynm, xnm = _load_xy_data(data, dep, indep)
    bwv = _parse_bandwidth(bw, (:cv, :rot))
    _status("Kernel regression ($method): $ynm ~ $xnm, n=$(length(y)), bw=$bw, kernel=$kernel")
    _status()
    kr = try
        kernel_reg(y, x; method=Symbol(method), degree=degree, bw=bwv, kernel=Symbol(kernel))
    catch e
        throw(_garch_variant_error(e, "Kernel regression"))
    end
    output_result(_kernel_reg_table(kr); format=Symbol(format), output=output,
                  title="Kernel Regression Fit ($ynm ~ $xnm)")
    output_kv(Pair{String,Any}[
        "method"    => string(kr.method),
        "degree"    => kr.degree,
        "kernel"    => string(kr.kernel),
        "bw_method" => string(kr.bw_method),
        "bandwidth" => round(Float64(kr.bandwidth); digits=6),
        "nobs"      => kr.nobs,
    ]; format=format, title="Kernel Regression Diagnostics")
    return kr
end

# estimate lowess — Cleveland (1979) locally-weighted scatterplot smoother
_lowess_table(lf) = DataFrame(x=round.(Float64.(lf.x); digits=6),
                              fitted=round.(Float64.(lf.fitted); digits=6))

function _estimate_lowess(; data::String, dep::String="", indep::String="",
                           frac::Float64=0.6667, iter::Int=3,
                           output::String="", format::String="table")
    (0.0 < frac <= 1.0) || throw(CliError("usage/invalid",
        "estimate lowess: --frac must be in (0,1], got $frac"))
    iter >= 0 || throw(CliError("usage/invalid",
        "estimate lowess: --iter must be ≥ 0, got $iter"))
    y, x, ynm, xnm = _load_xy_data(data, dep, indep)
    _status("LOWESS: $ynm ~ $xnm, n=$(length(y)), f=$frac, iter=$iter")
    _status()
    lf = try
        lowess(y, x; f=frac, iter=iter)
    catch e
        throw(_garch_variant_error(e, "LOWESS"))
    end
    output_result(_lowess_table(lf); format=Symbol(format), output=output,
                  title="LOWESS Fit ($ynm ~ $xnm)")
    output_kv(Pair{String,Any}[
        "frac" => round(Float64(lf.span); digits=6),
        "iter" => lf.iter,
        "nobs" => lf.nobs,
    ]; format=format, title="LOWESS Diagnostics")
    return lf
end

# ── C062a: cointegrating regression (FMOLS / CCR / DOLS) ─────────────
# Single-equation `estimate cointreg` (`_load_reg_data`, y = --dep levels, X = other numeric
# columns, no intercept prepended — cointreg adds its own deterministics via --trend) and
# panel `estimate xtcointreg` (`_load_panel_reg`). `CointRegModel`/`PanelCointRegModel` are
# StatsAPI RegressionModels but NOT registered in MEMs `_COEF_TABLE_TYPES`, so the tidy coef
# table is hand-built (documented C051 exception, like io/mgarch/sur). Every MEMs call is
# wrapped → typed CliError via `_garch_variant_error`; enums are guarded up front (`choices=`
# on the spec). The cointreg trend vocabulary is `none|const|linear` (NOT shared with other
# leaves — PMG uses `:constant`, ARDL uses `:const`/`:trend`).

"""Parse a cointreg `--bandwidth`: `andrews`|`nw94` → Symbol, else a non-negative number
(a fixed HAC truncation lag). A bad token → typed `usage/invalid` (never a raw MEMs error)."""
function _parse_cointreg_bandwidth(s::AbstractString)
    (s == "andrews" || s == "nw94") && return Symbol(s)
    v = tryparse(Float64, s)
    (v === nothing || !isfinite(v) || v < 0) && throw(CliError("usage/invalid",
        "--bandwidth must be andrews|nw94 or a non-negative number, got '$s'"))
    return v
end

"""Parse a DOLS `--leads`/`--lags`: `auto` → `:auto`, else a non-negative integer.
A bad token → typed `usage/invalid` (0 is valid — do NOT route through `_parse_bandwidth`,
which rejects 0)."""
function _parse_cointreg_leadlag(s::AbstractString, flag::String)
    s == "auto" && return :auto
    v = tryparse(Int, s)
    (v === nothing || v < 0) && throw(CliError("usage/invalid",
        "$flag must be 'auto' or a non-negative integer, got '$s'"))
    return v
end

"""Hand-built coefficient table for a single-equation cointegrating regression
(`CointRegModel`): `term|estimate|std_error|stat|p_value|ci_lower|ci_upper`. p-values/CIs use
the large-sample normal approximation (the estimators are asymptotically mixed-normal; same
convention as `_garch_variant_coef_table`/`dsge` using `_normal_cdf`)."""
function _cointreg_coef_table(model)
    est = Float64.(coef(model))
    se = Float64.(stderror(model))
    names = String.(model.varnames)[1:length(est)]
    z = [se[i] == 0 ? 0.0 : est[i] / se[i] for i in eachindex(est)]
    pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    zc = 1.959963984540054   # Φ⁻¹(0.975)
    return DataFrame(term=names, estimate=round.(est; digits=6),
                     std_error=round.(se; digits=6), stat=round.(z; digits=4),
                     p_value=round.(pv; digits=4),
                     ci_lower=round.(est .- zc .* se; digits=6),
                     ci_upper=round.(est .+ zc .* se; digits=6))
end

"""Hand-built coefficient table for a panel cointegrating regression
(`PanelCointRegModel`): reads the PRECOMPUTED `coef`/`se`/`tstats`/`pvalues` fields directly.
The group-mean SE is a back-solved display SE and can be `Inf` — do NOT recompute from
`vcov`; non-finite entries are kept (round-safe) and rendered by the non-finite-safe output
path (C067a/C073)."""
function _panel_cointreg_coef_table(model)
    est = Float64.(model.coef)
    se = Float64.(model.se)
    names = String.(model.varnames)[1:length(est)]
    zc = 1.959963984540054
    return DataFrame(term=names, estimate=round.(est; digits=6),
                     std_error=round.(se; digits=6), stat=round.(Float64.(model.tstats); digits=4),
                     p_value=round.(Float64.(model.pvalues); digits=4),
                     ci_lower=round.(est .- zc .* se; digits=6),
                     ci_upper=round.(est .+ zc .* se; digits=6))
end

function _estimate_cointreg(; data::String, dep::String="", method::String="fmols",
                             trend::String="const", kernel::String="bartlett",
                             bandwidth::String="andrews", leads::String="auto",
                             lags::String="auto", ic::String="aic", dols_se::String="lrv",
                             output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    bw = _parse_cointreg_bandwidth(bandwidth)
    ld = _parse_cointreg_leadlag(leads, "--leads")
    lg = _parse_cointreg_leadlag(lags, "--lags")
    _status("Cointegrating regression ($(uppercase(method))): $dep_name ~ $(join(xcols, " + ")), n=$(length(y))")
    _status()
    model = try
        estimate_cointreg(y, X; method=Symbol(method), trend=Symbol(trend),
            kernel=Symbol(replace(kernel, '-' => '_')), bandwidth=bw,
            leads=ld, lags=lg, ic=Symbol(ic), dols_se=Symbol(dols_se))
    catch e
        throw(_garch_variant_error(e, "cointreg"))
    end
    output_result(_cointreg_coef_table(model); format=Symbol(format), output=output,
                  title="Cointegrating Regression Coefficients ($dep_name)")
    pairs = Pair{String,Any}[
        "method"    => String(model.method),
        "trend"     => String(model.trend),
        "kernel"    => String(model.kernel),
        "bandwidth" => round(Float64(model.bandwidth); digits=4),
        "omega_uv"  => round(Float64(model.omega_uv); digits=6),
        "nobs"      => model.nobs,
        "d"         => model.d,
        "k"         => model.k,
    ]
    if model.method === :dols
        push!(pairs, "leads" => model.leads)
        push!(pairs, "lags"  => model.lags)
    end
    output_kv(pairs; format=format, title="Cointegrating Regression Diagnostics")
    return model
end

function _estimate_xtcointreg(; data::String, id_col::String="", time_col::String="",
                               dep::String="", indep::String="", method::String="fmols",
                               pooling::String="group", trend::String="const",
                               kernel::String="bartlett", bandwidth::String="andrews",
                               leads::String="auto", lags::String="auto", ic::String="aic",
                               dols_se::String="lrv", output::String="", format::String="table")
    pd, depsym, indepsyms, depc, indeps = _load_panel_reg(data, id_col, time_col, dep, indep)
    bw = _parse_cointreg_bandwidth(bandwidth)
    ld = _parse_cointreg_leadlag(leads, "--leads")
    lg = _parse_cointreg_leadlag(lags, "--lags")
    _status("Panel cointegrating regression ($(uppercase(method)), $pooling): $depc ~ $(join(indeps, " + ")), units=$(pd.n_groups)")
    _status()
    model = try
        estimate_xtcointreg(pd, depsym, indepsyms...; method=Symbol(method),
            pooling=Symbol(pooling), trend=Symbol(trend),
            kernel=Symbol(replace(kernel, '-' => '_')), bandwidth=bw,
            leads=ld, lags=lg, ic=Symbol(ic), dols_se=Symbol(dols_se))
    catch e
        throw(_garch_variant_error(e, "xtcointreg"))
    end
    title = model.pooling === :group ? "Group-mean" : "Pooled"
    output_result(_panel_cointreg_coef_table(model); format=Symbol(format), output=output,
                  title="Panel Cointegrating Regression $title Coefficients ($depc)")
    tspan = model.balanced ? string(first(model.T_i)) :
            "$(minimum(model.T_i))-$(maximum(model.T_i))"
    output_kv(Pair{String,Any}[
        "method"   => String(model.method),
        "pooling"  => String(model.pooling),
        "trend"    => String(model.trend),
        "kernel"   => String(model.kernel),
        "N"        => model.N,
        "nobs"     => model.nobs,
        "T_i"      => tspan,
        "balanced" => model.balanced,
        "k"        => model.k,
        "d"        => model.d,
    ]; format=format, title="Panel Cointegrating Regression Diagnostics")
    return model
end

# ── C062b: single-equation ARDL / NARDL ──────────────────────────────
# `estimate ardl` / `estimate nardl`, plus `test ardl-bounds` / `test nardl-symmetry`
# (test.jl) and `multipliers nardl` (multipliers.jl) all fit via these shared helpers.
# ARDLModel/NARDLModel are StatsAPI RegressionModels but NOT in MEMs `_COEF_TABLE_TYPES`,
# so the tidy coef/long-run tables are hand-built (documented C051 exception, like
# io/mgarch/sur/cointreg). p-values use the normal approximation (`_normal_cdf`) — the CLI
# convention everywhere (the ARDL OLS t-ratios are asymptotically standard-normal, and the
# mock has no TDist); the ARDL/NARDL trend vocabulary is none|const|trend (ARDL-specific).

"""Hand-built levels-form coefficient table for a fitted `ARDLModel` (pass `m` for
`estimate ardl` or `m.ardl` for NARDL): `term|estimate|std_error|stat|p_value`."""
function _ardl_coef_table(a)
    est = Float64.(coef(a))
    se = Float64.(stderror(a))
    names = String.(a.coefnames)[1:length(est)]
    z = [se[i] == 0 ? 0.0 : est[i] / se[i] for i in eachindex(est)]
    pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    return DataFrame(term=names, estimate=round.(est; digits=6),
                     std_error=round.(se; digits=6), stat=round.(z; digits=4),
                     p_value=round.(pv; digits=4))
end

"""Hand-built long-run (level) multiplier table from an `ARDLLongRun`:
`term|estimate|std_error|stat|p_value` (delta-method SEs; normal-approx stat/p — MEMs uses
`dist=:z` for the long-run block). Serves `estimate ardl` (symmetric) and `estimate nardl`
(θ⁺/θ⁻ on the enlarged regressor set)."""
function _ardl_longrun_table(lr)
    est = Float64.(lr.theta)
    se = Float64.(lr.se)
    names = String.(lr.varnames)[1:length(est)]
    z = [se[i] == 0 ? 0.0 : est[i] / se[i] for i in eachindex(est)]
    pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    return DataFrame(term=names, estimate=round.(est; digits=6),
                     std_error=round.(se; digits=6), stat=round.(z; digits=4),
                     p_value=round.(pv; digits=4))
end

"""Fit an `ARDLModel` from a loaded `(y, X, xcols)` + a resolved dep name, with all
argument validation done up front (`--case`/`--max-p`/`--max-q` + `--p`/`--q` parse and the
per-regressor `--q` length check). Every MEMs call is wrapped → typed `CliError` via
`_garch_variant_error` (bad case/q → `data/invalid`, shape → `data/shape`). Shared by
`estimate ardl` and `test ardl-bounds`."""
function _fit_ardl(y, X, xcols, dep_name; p::String, q::String, max_p::Int, max_q::Int,
                   ic::String, case::Int, trend::String, label::String)
    (1 <= case <= 5) || throw(CliError("usage/invalid", "$label: --case must be in 1:5, got $case"))
    max_p >= 1 || throw(CliError("usage/invalid", "$label: --max-p must be ≥ 1, got $max_p"))
    max_q >= 0 || throw(CliError("usage/invalid", "$label: --max-q must be ≥ 0, got $max_q"))
    pp = _parse_lag_spec(p, "--p"; min=1)
    qq = _parse_lag_spec(q, "--q"; min=0)
    k = length(xcols)
    (qq isa Vector{Int} && length(qq) != k) && throw(CliError("usage/invalid",
        "$label: --q has $(length(qq)) entries but there are $k regressor(s); pass one per regressor, a single int, or auto"))
    return try
        estimate_ardl(y, X; p=pp, q=qq, max_p=max_p, max_q=max_q, ic=Symbol(ic),
                      case=case, trend=Symbol(trend), xnames=xcols, yname=dep_name)
    catch e
        throw(_garch_variant_error(e, label))
    end
end

"""Fit a `NARDLModel` from a loaded `(y, X, xcols)` + a resolved dep name. Validates
`--case`/orders, parses `--p`/`--q`, and resolves/bounds-checks `--asymmetric` (each index ∈
`1:k₀`). Wrapped → typed `CliError`. Shared by `estimate nardl`, `test nardl-symmetry`, and
`multipliers nardl`."""
function _fit_nardl(y, X, xcols, dep_name; asymmetric::String, p::String, q::String,
                    max_p::Int, max_q::Int, ic::String, case::Int, label::String)
    (1 <= case <= 5) || throw(CliError("usage/invalid", "$label: --case must be in 1:5, got $case"))
    max_p >= 1 || throw(CliError("usage/invalid", "$label: --max-p must be ≥ 1, got $max_p"))
    max_q >= 0 || throw(CliError("usage/invalid", "$label: --max-q must be ≥ 0, got $max_q"))
    k0 = length(xcols)
    asym = _parse_asym_spec(asymmetric)
    (asym isa Vector{Int} && !all(j -> 1 <= j <= k0, asym)) && throw(CliError("usage/invalid",
        "$label: --asymmetric indices must be in 1:$k0, got $asym"))
    pp = _parse_lag_spec(p, "--p"; min=1)
    qq = _parse_lag_spec(q, "--q"; min=0)
    # Up-front `--q` length check on the ENLARGED split design (each asymmetric regressor →
    # POS/NEG), mirroring `_fit_ardl`'s guard → a wrong-length list is usage/invalid (exit 2)
    # with a clean CLI message, not MEMs' data/invalid referencing the internal split count
    # (adversarial review C062b).
    kk = asym === :all ? 2 * k0 : k0 + length(asym)
    (qq isa Vector{Int} && length(qq) != kk) && throw(CliError("usage/invalid",
        "$label: --q has $(length(qq)) entries but the NARDL split design has $kk regressor(s) (each asymmetric regressor is split into POS/NEG); pass one per split regressor, a single int, or auto"))
    return try
        estimate_nardl(y, X; asymmetric=asym, p=pp, q=qq, max_p=max_p, max_q=max_q,
                       ic=Symbol(ic), case=case, xnames=xcols, yname=dep_name)
    catch e
        throw(_garch_variant_error(e, label))
    end
end

"""Round a scalar for kv output, string-rendering non-finite values (the legacy-JSON writer
rejects Inf/NaN — the C067a gotcha; `alpha_t` can be Inf when `alpha_se==0`)."""
_ardl_kv(x; digits::Int=6) = isfinite(x) ? round(Float64(x); digits=digits) : string(x)

function _estimate_ardl(; data::String, dep::String="", p::String="auto", q::String="auto",
                         max_p::Int=4, max_q::Int=4, ic::String="aic", case::Int=3,
                         trend::String="none", output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("ARDL: $dep_name ~ $(join(xcols, " + ")) (p=$p, q=$q, case=$case, ic=$ic), n=$(length(y))"); _status()
    m = _fit_ardl(y, X, xcols, dep_name; p=p, q=q, max_p=max_p, max_q=max_q,
                  ic=ic, case=case, trend=trend, label="ARDL")
    output_result(_ardl_coef_table(m); format=Symbol(format), output=output,
                  title="ARDL Coefficients (levels form) ($dep_name)")
    lr = long_run(m)
    output_result(_ardl_longrun_table(lr); format=Symbol(format),
                  output=_per_var_output_path(output, "longrun"),
                  title="ARDL Long-Run Coefficients ($dep_name)")
    ecm = MacroEconometricModels.ecm_form(m)   # ecm_form is not exported → qualify
    output_kv(Pair{String,Any}[
        "p"             => m.p,
        "q"             => join(m.q, ","),
        "case"          => m.case,
        "trend"         => String(m.trend),
        "ic"            => String(m.ic),
        "selected"      => m.selected,
        "nobs"          => m.n,
        "K"             => m.K,
        "sigma2"        => _ardl_kv(m.sigma2),
        "loglik"        => _ardl_kv(m.loglik; digits=4),
        "aic"           => _ardl_kv(m.aic; digits=4),
        "bic"           => _ardl_kv(m.bic; digits=4),
        "alpha"         => _ardl_kv(ecm.alpha),           # ECM speed of adjustment (Σφ − 1)
        "alpha_se"      => _ardl_kv(ecm.alpha_se),
        "alpha_t"       => _ardl_kv(ecm.alpha_t; digits=4),
        "longrun_denom" => _ardl_kv(lr.denom),            # 1 − Σφ̂ = −alpha
    ]; format=format, title="ARDL Diagnostics")
    return m
end

function _estimate_nardl(; data::String, dep::String="", asymmetric::String="all",
                          p::String="auto", q::String="auto", max_p::Int=4, max_q::Int=4,
                          ic::String="aic", case::Int=3, output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("NARDL: $dep_name ~ $(join(xcols, " + ")) (asym=$asymmetric, p=$p, q=$q, case=$case), n=$(length(y))"); _status()
    m = _fit_nardl(y, X, xcols, dep_name; asymmetric=asymmetric, p=p, q=q,
                   max_p=max_p, max_q=max_q, ic=ic, case=case, label="NARDL")
    a = m.ardl
    output_result(_ardl_coef_table(a); format=Symbol(format), output=output,
                  title="NARDL Coefficients (levels form, split regressors) ($dep_name)")
    lr = long_run(m)   # ARDLLongRun on the enlarged (θ⁺/θ⁻) regressor set
    output_result(_ardl_longrun_table(lr); format=Symbol(format),
                  output=_per_var_output_path(output, "longrun"),
                  title="NARDL Asymmetric Long-Run Coefficients (θ⁺ / θ⁻) ($dep_name)")
    # Cached enlarged-k bounds decision (NO p-value — non-standard PSS test).
    b = m.bounds
    li = findfirst(x -> isapprox(x, b.level), b.levels)
    output_kv(Pair{String,Any}[
        "k_orig"       => m.k_orig,
        "k"            => m.k,                 # enlarged: each asymmetric regressor counts twice
        "asym"         => join(m.asym, ","),
        "p"            => a.p,
        "q"            => join(a.q, ","),
        "case"         => a.case,
        "ic"           => String(a.ic),
        "nobs"         => a.n,
        "f_stat"       => _ardl_kv(b.fstat; digits=4),
        "t_stat"       => _ardl_kv(b.tstat; digits=4),
        "bounds_level" => b.level,
        "f_lower"      => li === nothing ? "n/a" : _ardl_kv(b.f_lower[li]; digits=4),
        "f_upper"      => li === nothing ? "n/a" : _ardl_kv(b.f_upper[li]; digits=4),
        "f_decision"   => String(b.f_decision),
        "t_decision"   => String(b.t_decision),
    ]; format=format, title="NARDL Diagnostics + Bounds (enlarged k=$(m.k))")
    return m
end

# ── C062c: dynamic heterogeneous-panel ARDL (PMG / MG / DFE) ──────────────────
# `estimate pmg` (Pooled Mean Group + Mean Group + Dynamic Fixed Effects; Pesaran-Shin-Smith
# 1999) and `test pmg-hausman` (test.jl) fit via the shared hardened `_load_panel_reg` panel
# loader (typed dup-(id,time) / missing-cell / bad-column guards). `PMGModel` is a StatsAPI
# model but NOT in MEMs `_COEF_TABLE_TYPES` → hand-built long-run + short-run/EC tables
# (documented C051 exception, like io/mgarch/sur/cointreg/ardl). Long-run p-values use the
# normal approximation (`_normal_cdf`, the CLI convention — the pooled θ is asymptotically
# normal). NOTE the trend vocabulary is PMG-specific: none|constant|trend — `:constant` is
# SPELLED OUT (NOT ARDL's :const, NOT cointreg's :linear); do not copy another leaf's trend
# OptionSpec here. Display SEs (φ, θ) can be Inf → the kv path string-renders non-finite
# scalars (`_ardl_kv`) and the table path is non-finite-safe (C067a/C073).

"""Hand-built long-run coefficient table for a fitted `PMGModel`:
`term|estimate|std_error|stat|p_value` from the common (`:pmg`/`:dfe`) or averaged (`:mg`)
long-run block `theta`/`theta_se`; `term = m.xnames`. Normal-approx stat/p."""
function _pmg_longrun_table(m)
    est = Float64.(m.theta)
    se = Float64.(m.theta_se)
    names = String.(m.xnames)[1:length(est)]
    z = [se[i] == 0 ? 0.0 : est[i] / se[i] for i in eachindex(est)]
    pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    return DataFrame(term=names, estimate=round.(est; digits=6),
                     std_error=round.(se; digits=6), stat=round.(z; digits=4),
                     p_value=round.(pv; digits=4))
end

"""Hand-built short-run / error-correction table for a fitted `PMGModel`:
`term|estimate|std_error`. The error-correction speed φ (mean for `:pmg`/`:mg`, common for
`:dfe`) is the first row, followed by the averaged/common short-run block (`m.sr`/`m.sr_se`,
`term = m.srnames`). For a DFE fit the unit intercept is absorbed → `srnames` may be empty, in
which case only the φ row is emitted."""
function _pmg_shortrun_table(m)
    terms = String["EC speed (phi)"]
    est = Float64[m.phi]
    se = Float64[m.phi_se]
    srnames = String.(m.srnames)
    for j in eachindex(srnames)
        push!(terms, srnames[j]); push!(est, Float64(m.sr[j])); push!(se, Float64(m.sr_se[j]))
    end
    return DataFrame(term=terms, estimate=round.(est; digits=6), std_error=round.(se; digits=6))
end

function _estimate_pmg(; data::String, id_col::String="", time_col::String="",
                        dep::String="", indep::String="", method::String="pmg",
                        trend::String="constant", p::Int=1, q::Int=1,
                        maxiter::Int=100, tol::Float64=1e-8,
                        output::String="", format::String="table")
    p >= 1 || throw(CliError("usage/invalid", "--p must be ≥ 1, got $p"))
    q >= 0 || throw(CliError("usage/invalid", "--q must be ≥ 0, got $q"))
    maxiter >= 1 || throw(CliError("usage/invalid", "--maxiter must be ≥ 1, got $maxiter"))
    tol > 0 || throw(CliError("usage/invalid", "--tol must be > 0, got $tol"))
    pd, depsym, indepsyms, depc, indeps = _load_panel_reg(data, id_col, time_col, dep, indep)
    _status("Panel ARDL ($(uppercase(method)), EC form): $depc ~ $(join(indeps, " + ")) (p=$p, q=$q, trend=$trend), units=$(pd.n_groups)"); _status()
    m = try
        estimate_pmg(pd, depsym, indepsyms...; p=p, q=q, method=Symbol(method),
                     trend=Symbol(trend), maxiter=maxiter, tol=tol)
    catch e
        throw(_garch_variant_error(e, "PMG"))
    end
    output_result(_pmg_longrun_table(m); format=Symbol(format), output=output,
                  title="Panel ARDL Long-Run Coefficients (theta) ($depc)")
    output_result(_pmg_shortrun_table(m); format=Symbol(format),
                  output=_per_var_output_path(output, "shortrun"),
                  title="Panel ARDL Short-Run + EC Coefficients ($depc)")
    tspan = length(unique(m.T_i)) == 1 ? string(first(m.T_i)) :
            "$(minimum(m.T_i))-$(maximum(m.T_i))"
    output_kv(Pair{String,Any}[
        "method"    => String(m.method),
        "N"         => m.N,
        "p"         => m.p,
        "q"         => m.q,
        "T_i"       => tspan,
        "phi"       => _ardl_kv(m.phi),
        "phi_se"    => _ardl_kv(m.phi_se),
        "loglik"    => _ardl_kv(m.loglik; digits=4),
        "converged" => m.converged,
        "iters"     => m.iters,
        "n_nonconv" => m.n_nonconv,
    ]; format=format, title="Panel ARDL Diagnostics")
    return m
end

# ── C062d: MIDAS mixed-frequency regression ──────────────────────────
# `estimate midas` fits a (restricted) MIDAS / ADL-MIDAS / U-MIDAS regression of a low-frequency
# target on `--k` high-frequency lags of a single indicator, aggregated through a weight function.
# The mixed-frequency inputs are loaded via the hardened `_load_midas_data` (both series through
# `load_univariate_series`; len(HF)>=m×len(LF), leading ragged edge dropped → typed data/shape). `MidasModel` is a
# StatsAPI RegressionModel but NOT in MEMs `_COEF_TABLE_TYPES` → the weight-curve + coefficient
# tables are hand-built (documented C051 exception, like io/mgarch/sur/cointreg/ardl). p-values use
# the normal approximation (`_normal_cdf`) — the CLI convention (the NLS t-ratios are asymptotically
# standard-normal). `forecast midas` is DEFERRED (fresh-HF-block UX + non-native save/load; v1.1).

"""Map an untyped MEMs MIDAS-estimation failure to a typed CliError — never an uncaught exit-1
(the standing shared-loader lesson). Bad-input `ArgumentError`/`DomainError` (bad m/K, no complete
HF blocks, no AR periods, K<2 for a Beta weight, wrong θ length) → `data/invalid` (3); shape
mismatch → `data/shape` (3); the NLS 'failed to converge from any start' → `model/convergence` (5);
anything else → `model/error` (5)."""
function _midas_error(e, label::String)
    e isa CliError && return e
    if e isa ArgumentError || e isa DomainError
        return CliError("data/invalid", "$label: $(sprint(showerror, e))";
            hint="check --m, --k, --p-ar and the series lengths (HF ≈ m×LF)")
    elseif e isa DimensionMismatch
        return CliError("data/shape", "$label: $(sprint(showerror, e))")
    elseif occursin("converge", lowercase(sprint(showerror, e)))
        return CliError("model/convergence", "$label failed to converge from any start";
            hint="try --weights umidas, a smaller --k, or a larger --max-iter")
    end
    return CliError("model/error", "$label estimation failed: $(sprint(showerror, e))")
end

"""Headline MIDAS weight-curve table `lag|weight` from `midas_weights(m)` (== `m.w`, length K,
most-recent-first). For `:umidas` these are the unrestricted lag coefficients (raw, not normalized)."""
function _midas_weight_table(model)
    w = Float64.(midas_weights(model))
    return DataFrame(lag=collect(1:length(w)), weight=round.(w; digits=6))
end

"""Hand-built MIDAS coefficient table (`term|estimate|std_error|stat|p_value`) over the full
parameter vector `[β; θ]` (`coef(m)`), with `term = m.varnames`. Falls back to estimate-only when
the Gauss-Newton SEs are unavailable/non-finite (mirrors `_garch_variant_coef_table`). For
`:umidas` the θ block is empty and the K lag coefficients enter as the linear block; θ labels are
padded if `varnames` is shorter than `coef` (defensive)."""
function _midas_coef_table(model)
    est = Float64.(coef(model))
    nm = String.(model.varnames)
    names = length(nm) == length(est) ? nm :
            String[i <= length(nm) ? nm[i] : "theta$(i - length(model.beta))" for i in eachindex(est)]
    try
        se = Float64.(stderror(model))
        (length(se) == length(est) && all(isfinite, se)) || error("unavailable SEs")
        z = [se[i] == 0 ? 0.0 : est[i] / se[i] for i in eachindex(est)]
        pv = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
        return DataFrame(term=names, estimate=round.(est; digits=6),
                         std_error=round.(se; digits=6), stat=round.(z; digits=4),
                         p_value=round.(pv; digits=4))
    catch
        return DataFrame(term=names, estimate=round.(est; digits=6))
    end
end

function _estimate_midas(; data::String, column::Int=1, hf_data::String="", hf_column::Int=1,
                          m::Int=0, k::Int=0, weights::String="expalmon", p_ar::Int=0,
                          poly_degree::Int=2, horizon::Int=1, max_iter::Int=500,
                          output::String="", format::String="table")
    # Up-front guards → usage/invalid (before any load or estimator call).
    isempty(hf_data) && throw(CliError("usage/missing-option",
        "estimate midas requires --hf-data <csv> (the high-frequency indicator series)"))
    m >= 1 || throw(CliError("usage/invalid", "--m (HF/LF frequency ratio) must be ≥ 1, got $m"))
    k >= 1 || throw(CliError("usage/invalid", "--k (number of high-frequency lags) must be ≥ 1, got $k"))
    p_ar >= 0 || throw(CliError("usage/invalid", "--p-ar must be ≥ 0, got $p_ar"))
    max_iter >= 1 || throw(CliError("usage/invalid", "--max-iter must be ≥ 1, got $max_iter"))
    # --poly-degree feeds the `:almon` polynomial (real `_n_theta(:almon, d)=d+1`); a negative degree
    # is never meaningful and, unguarded, reaches `_midas_theta_starts` OUTSIDE the estimator try/catch
    # → a bare `BoundsError` on real MEMs (`base[1]=…` on `zeros(0)`) mapped to model/error, while the
    # mock throws `ArgumentError` → data/invalid: a latent mock/real exit-class divergence. Reject up
    # front → usage/invalid (poly_degree=0 = constant/equal weights is valid on both).
    poly_degree >= 0 || throw(CliError("usage/invalid", "--poly-degree must be ≥ 0, got $poly_degree"))
    # Beta weights need a ≥2-point grid; pre-guard for a friendly message (real `_beta_grid` throws).
    (weights in ("beta2", "beta3") && k < 2) && throw(CliError("data/invalid",
        "--weights $weights requires --k ≥ 2 (the Beta weight grid needs ≥ 2 lags), got k=$k"))
    y_lf, x_hf, ynm, xnm = _load_midas_data(data, column, hf_data, hf_column; m=m)
    _status("Estimating MIDAS: target=$ynm (n=$(length(y_lf))), indicator=$xnm (HF n=$(length(x_hf))), m=$m, K=$k, weights=$weights, p_ar=$p_ar")
    _status()
    model = try
        estimate_midas(y_lf, x_hf; m=m, K=k, weights=Symbol(weights), p_ar=p_ar,
                       poly_degree=poly_degree, h=horizon, max_iter=max_iter)
    catch e
        throw(_midas_error(e, "MIDAS"))
    end
    output_result(_midas_weight_table(model); format=Symbol(format), output=output,
                  title="MIDAS Weight Curve ($xnm, most-recent-first)")
    output_result(_midas_coef_table(model); format=Symbol(format),
                  output=_per_var_output_path(output, "coef"),
                  title="MIDAS Coefficients ($ynm)")
    output_kv(Pair{String,Any}[
        "weights_kind" => String(model.weights_kind),
        "m"            => model.m,
        "K"            => model.K,
        "p_ar"         => model.p_ar,
        "poly_degree"  => model.poly_degree,
        "h"            => model.h,
        "nobs"         => nobs(model),
        "r2"           => _ardl_kv(model.r2),
        "adj_r2"       => _ardl_kv(model.adj_r2),
        "ssr"          => _ardl_kv(model.ssr; digits=4),
        "sigma2"       => _ardl_kv(model.sigma2),
        "aic"          => _ardl_kv(model.aic; digits=4),
        "bic"          => _ardl_kv(model.bic; digits=4),
        "loglik"       => _ardl_kv(model.loglik; digits=4),
        "converged"    => model.converged,
    ]; format=format, title="MIDAS Diagnostics")
    return model
end

# ── C065a: SETAR handler ───────────────────────────────────────
# Every user option is guarded up-front → usage/invalid (before any MEMs call); the
# estimator is try-wrapped → typed CliError via `_nonlinear_error` (never exit-1). The
# two regime blocks render via the shared `_threshold_coef_table`; the Hansen (1996)
# linearity test, attached iff `linearity`, folds into the diagnostics kv.
function _estimate_setar(; data::String, column::Int=1, p::Int=1, d::String="1",
                          trim::Float64=0.15, reps::Int=1000, ci_level::Float64=0.95,
                          het::Bool=false, no_linearity::Bool=false,
                          output::String="", format::String="table")
    p >= 1 || throw(CliError("usage/invalid", "estimate setar: --p must be ≥ 1 (got $p)"))
    (0.0 < trim < 0.5) || throw(CliError("usage/invalid",
        "estimate setar: --trim must be in (0, 0.5) (got $trim)"))
    reps >= 1 || throw(CliError("usage/invalid", "estimate setar: --reps must be ≥ 1 (got $reps)"))
    # Hansen (2000) critical values are tabulated ONLY for these three levels — anything
    # else makes `_hansen2000_crit` throw an uncaught ArgumentError, so guard exactly.
    (ci_level == 0.90 || ci_level == 0.95 || ci_level == 0.99) || throw(CliError("usage/invalid",
        "estimate setar: --ci-level must be exactly 0.90, 0.95, or 0.99 (got $ci_level)"))
    d_arg = _parse_setar_delay(d)
    y, vname = load_univariate_series(data, column)
    _status("Estimating SETAR(2;$p,$p): variable=$vname, obs=$(length(y)), d=$d, ci=$ci_level" *
            (het ? ", het bootstrap" : "") * (no_linearity ? ", linearity test skipped" : ""))
    _status()
    model = try
        estimate_setar(y, p, d_arg; trim=trim, linearity=!no_linearity, reps=reps,
                       ci_level=ci_level, het=het)
    catch e
        throw(_nonlinear_error(e, "SETAR"))
    end
    coef = vcat(
        _threshold_coef_table(model.beta1, model.se1, model.xnames, "regime1 (q≤γ)"),
        _threshold_coef_table(model.beta2, model.se2, model.xnames, "regime2 (q>γ)"),
    )
    output_result(coef; format=Symbol(format), output=output,
                  title="SETAR(2;$p,$p) Coefficients ($vname)")
    diag = Pair{String,Any}[
        "gamma"          => round(Float64(model.gamma); digits=6),
        "gamma_ci_lower" => round(Float64(model.gamma_ci[1]); digits=6),
        "gamma_ci_upper" => round(Float64(model.gamma_ci[2]); digits=6),
        "gamma_ci_level" => Float64(model.gamma_ci_level),
        "n"              => model.n,
        "n1"             => model.n1,
        "n2"             => model.n2,
        "ssr"            => round(Float64(model.ssr); digits=6),
        "sigma2"         => round(Float64(model.sigma2); digits=6),
        "aic"            => round(Float64(model.aic); digits=4),
        "bic"            => round(Float64(model.bic); digits=4),
        "p"              => model.p,
        "d"              => model.d,
        "is_setar"       => model.is_setar,
    ]
    if model.linearity !== nothing
        lt = model.linearity
        append!(diag, Pair{String,Any}[
            "sup_lm"      => round(Float64(lt.sup_lm); digits=4),
            "pvalue_lm"   => round(Float64(lt.pvalue_lm); digits=4),
            "sup_wald"    => round(Float64(lt.sup_wald); digits=4),
            "pvalue_wald" => round(Float64(lt.pvalue_wald); digits=4),
            "gamma_sup"   => round(Float64(lt.gamma_sup); digits=6),
        ])
    end
    output_kv(diag; format=format, title="SETAR(2;$p,$p) Diagnostics")
    return model
end

# ── C065b: STAR handler ─────────────────────────────────────────
# Tidy transition-parameters table for a STARModel: `parameter | estimate | std_error |
# z_stat | p_value` (γ then the location(s) c — length 1 for lstr1/estr, 2 for lstr2), with
# large-sample normal z/p (the `_garch_variant`/`dsge` `_normal_cdf` convention). Rendered
# as its own table, distinct from the two regime-weight blocks.
function _star_transition_table(model)
    cnames = length(model.c) == 1 ? String["c"] : String["c$i" for i in 1:length(model.c)]
    params = vcat("γ", cnames)
    est = Float64.(vcat(model.gamma, model.c))
    se  = Float64.(vcat(model.se_gamma, model.se_c))
    z   = [se[i] == 0.0 ? 0.0 : est[i] / se[i] for i in eachindex(est)]
    pv  = [2.0 * (1.0 - _normal_cdf(abs(zi))) for zi in z]
    return DataFrame(parameter=params, estimate=round.(est; digits=6),
                     std_error=round.(se; digits=6),
                     z_stat=round.(z; digits=4), p_value=round.(pv; digits=4))
end

# Every user option is guarded up-front → usage/invalid (before any MEMs call); the estimator
# is try-wrapped → typed CliError via the shared `_nonlinear_error` (never uncaught exit-1). The
# two regime-weight blocks (1−G / G) render via the shared `_threshold_coef_table`; the transition
# parameters (γ, c) via `_star_transition_table`; the LM3 linearity statistics + the optional
# Teräsvirta sequential-selection triple (only for `--type auto`) fold into the diagnostics kv.
function _estimate_star(; data::String, column::Int=1, p::Int=1, d::Int=1,
                         type::String="auto", n_gamma::Int=15, n_c::Int=15,
                         transition_col::Int=0, output::String="", format::String="table")
    p >= 1 || throw(CliError("usage/invalid", "estimate star: --p must be ≥ 1 (got $p)"))
    d >= 1 || throw(CliError("usage/invalid", "estimate star: --d must be ≥ 1 (got $d)"))
    n_gamma >= 2 || throw(CliError("usage/invalid", "estimate star: --n-gamma must be ≥ 2 (got $n_gamma)"))
    n_c >= 2 || throw(CliError("usage/invalid", "estimate star: --n-c must be ≥ 2 (got $n_c)"))
    ttype = Symbol(type)
    ttype in (:lstr1, :lstr2, :estr, :auto) || throw(CliError("usage/invalid",
        "estimate star: --type must be one of lstr1|lstr2|estr|auto (got '$type')"))
    y, vname = load_univariate_series(data, column)
    s = nothing
    if transition_col > 0
        s, _ = load_univariate_series(data, transition_col)
        length(s) == length(y) || throw(CliError("data/shape",
            "estimate star: transition variable (column $transition_col) has length $(length(s)), " *
            "but the series has length $(length(y))"))
        std(s) > 0 || throw(CliError("data/invalid",
            "estimate star: transition variable (column $transition_col) is constant; cannot scale γ"))
    end
    _status("Estimating STAR($p) [$type]: variable=$vname, obs=$(length(y)), d=$d" *
            (transition_col > 0 ? ", external transition col=$transition_col" : ", self-exciting")); _status()
    model = try
        estimate_star(y, p; s=s, d=d, type=ttype, n_gamma=n_gamma, n_c=n_c)
    catch e
        throw(_nonlinear_error(e, "STAR"))
    end
    coef = vcat(
        _threshold_coef_table(model.phi1, model.se_phi1, model.znames, "regime1 (G→0)"),
        _threshold_coef_table(model.phi2, model.se_phi2, model.znames, "regime2 (G→1)"),
    )
    output_result(coef; format=Symbol(format), output=output,
                  title="STAR($p) Regime Coefficients ($vname)")
    # Second table to a DISTINCT --output path (mirrors ardl/pmg): a shared file path would let
    # the transition table overwrite the regime-coefficient file. No-op for stdout/envelope.
    output_result(_star_transition_table(model); format=Symbol(format),
                  output=_per_var_output_path(output, "transition"),
                  title="STAR($p) Transition Parameters")
    diag = Pair{String,Any}[
        "trans_type"  => string(model.trans_type),
        "sname"       => model.sname,
        "sigma_s"     => round(Float64(model.sigma_s); digits=6),
        "n"           => model.n,
        "p"           => model.p,
        "d"           => model.d,
        "ssr"         => round(Float64(model.ssr); digits=6),
        "sigma2"      => round(Float64(model.sigma2); digits=6),
        "aic"         => round(Float64(model.aic); digits=4),
        "bic"         => round(Float64(model.bic); digits=4),
        "lm3_stat"    => round(Float64(model.lm3_stat); digits=4),
        "lm3_pvalue"  => round(Float64(model.lm3_pvalue); digits=4),
        "lm3_fstat"   => round(Float64(model.lm3_fstat); digits=4),
        "lm3_fpvalue" => round(Float64(model.lm3_fpvalue); digits=4),
        "converged"   => model.converged,
    ]
    if model.sel_pvalues !== nothing
        sp = model.sel_pvalues
        append!(diag, Pair{String,Any}[
            "sel_H04" => round(Float64(sp[1]); digits=4),
            "sel_H03" => round(Float64(sp[2]); digits=4),
            "sel_H02" => round(Float64(sp[3]); digits=4),
        ])
    end
    output_kv(diag; format=format, title="STAR($p) Diagnostics")
    return model
end

# ── C065c: Markov-switching (MSRegModel) shared renderer ─────────
# `estimate_ms_ar` (Hamilton mean-switching) and `estimate_ms` (K-state regression) both
# return an MSRegModel, which is NOT in MEMs `_COEF_TABLE_TYPES` → every table is hand-built
# (the documented C051 exception, like io/mgarch/sur). The transition matrix P renders WIDE
# (regime×regime), the parallel of the MGARCH conditional-correlation matrix.

"""Wide K×K transition-matrix DataFrame with a leading `from_regime` label column and
`to_regime\$j` value columns (`P[i,j] = Pr(sₜ=j | s_{t−1}=i)`, rows sum to 1). `makeunique=true`
on BOTH the matrix constructor AND the `insertcols!` guards the recurring wide-matrix
header/label collision (a duplicate/colliding header would otherwise crash the UNWRAPPED
renderer → exit-1), exactly as `_mgarch_corr_df` does for the MGARCH correlation matrix."""
function _ms_transition_df(P::AbstractMatrix)
    K = size(P, 1)
    df = DataFrame(round.(Float64.(P); digits=6), String["to_regime$j" for j in 1:K]; makeunique=true)
    insertcols!(df, 1, :from_regime => String["regime$i" for i in 1:K]; makeunique=true)
    return df
end

"""Shared renderer for a Markov-switching fit (`estimate ms-ar` / `estimate ms`). Emits, in
order: a tidy per-regime coefficient table, a per-regime variance table, the WIDE K×K
transition matrix, and a diagnostics kv. Branches on `model.model_type`:

- `:ms_ar` (Hamilton mean-switching) — one switching-`mu` row per regime (from `model.mu` /
  `model.se_coefs[1,k]`) PLUS a single `common-AR` block for the shared AR coefficients φ
  (from `model.ar` / `model.se_ar`), since only the level switches.
- `:regression` — the full per-regime switching coefficients over `model.xnames` (from
  `model.coefs[:,k]` / `model.se_coefs[:,k]`).

Each `output_result`/`output_kv` uses a DISTINCT title → distinct envelope slug; the 2nd/3rd
tables route `--output` to a distinct `_per_var_output_path` so a `-o file` export is not
overwritten by the subsequent table (the C065b multi-table lesson; no-op for stdout/envelope)."""
function _ms_render(model, format::String, output::String)
    K = model.k_regimes
    label = model.model_type == :ms_ar ? "MS-AR($(model.p))" : "MS Regression"
    yname = String(model.yname)
    blocks = DataFrame[]
    if model.model_type == :ms_ar
        for k in 1:K
            push!(blocks, _threshold_coef_table(
                Float64[model.mu[k]], Float64[model.se_coefs[1, k]],
                String["mu"], "regime$k"))
        end
        # AR coefficients φ are COMMON across regimes → one separate block
        if !isempty(model.ar)
            push!(blocks, _threshold_coef_table(
                Float64.(model.ar), Float64.(model.se_ar),
                String["φ$i" for i in 1:length(model.ar)], "common-AR"))
        end
    else
        for k in 1:K
            push!(blocks, _threshold_coef_table(
                Float64.(model.coefs[:, k]), Float64.(model.se_coefs[:, k]),
                model.xnames, "regime$k"))
        end
    end
    output_result(vcat(blocks...); format=Symbol(format), output=output,
                  title="$label Regime Coefficients ($yname)")
    vardf = DataFrame(regime=String["regime$k" for k in 1:K],
                      sigma2=round.(Float64.(model.sigma2); digits=6),
                      std_error=round.(Float64.(model.se_sigma2); digits=6))
    output_result(vardf; format=Symbol(format),
                  output=_per_var_output_path(output, "variance"),
                  title="$label Regime Variances")
    output_result(_ms_transition_df(model.P); format=Symbol(format),
                  output=_per_var_output_path(output, "transition"),
                  title="$label Transition Matrix")
    diag = Pair{String,Any}[
        "loglik"   => round(Float64(model.loglik); digits=4),
        "n_params" => model.n_params,
        "aic"      => round(Float64(model.aic); digits=4),
        "bic"      => round(Float64(model.bic); digits=4),
    ]
    for k in 1:K
        push!(diag, "ergodic_$k" => round(Float64(model.ergodic[k]); digits=6))
    end
    for k in 1:K
        push!(diag, "expected_duration_$k" => round(Float64(model.expected_durations[k]); digits=4))
    end
    append!(diag, Pair{String,Any}[
        "switching_var" => model.switching_var,
        "switching_ar"  => model.switching_ar,
        "converged"     => model.converged,
        "iterations"    => model.iterations,
    ])
    output_kv(diag; format=format, title="$label Diagnostics")
    return model
end

# ── C065c: MS-AR handler ─────────────────────────────────────────
# Every option guarded up-front → usage/invalid (before any MEMs call); the estimator is
# try-wrapped → typed CliError via the shared `_nonlinear_error` (never uncaught exit-1).
# `switching_variance` default FALSE (Hamilton) — the `--switching-variance` flag turns it on.
function _estimate_ms_ar(; data::String, column::Int=1, p::Int=1, k_regimes::Int=2,
                          switching_variance::Bool=false, max_iter::Int=1000,
                          output::String="", format::String="table")
    p >= 1 || throw(CliError("usage/invalid", "estimate ms-ar: --p must be ≥ 1 (got $p)"))
    k_regimes >= 2 || throw(CliError("usage/invalid",
        "estimate ms-ar: --k-regimes must be ≥ 2 (got $k_regimes)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "estimate ms-ar: --max-iter must be ≥ 1 (got $max_iter)"))
    y, vname = load_univariate_series(data, column)
    _status("Estimating MS-AR($p) [$k_regimes regimes]: variable=$vname, obs=$(length(y))" *
            (switching_variance ? ", switching variance" : ", common variance")); _status()
    model = try
        estimate_ms_ar(y, p; k_regimes=k_regimes, switching_variance=switching_variance,
                       max_iter=max_iter, yname=vname)
    catch e
        throw(_nonlinear_error(e, "MS-AR"))
    end
    return _ms_render(model, format, output)
end

# ── C065c: MS regression handler ─────────────────────────────────
# Loaded via the hardened `_load_reg_data` (y + numeric regressors, NO auto-intercept). When
# the dependent variable is the ONLY numeric column, `_load_reg_data` raises data/invalid
# ("no regressor columns remaining") — that specific case routes to the single-arg intercept-only
# dispatch `estimate_ms(y; …)` (X === nothing). Every option guarded up-front → usage/invalid;
# the estimator is try-wrapped → typed CliError. `switching_variance` default TRUE — the
# `--no-switching-variance` flag turns it off.
function _estimate_ms(; data::String, dep::String="", k_regimes::Int=2,
                       no_switching_variance::Bool=false, max_iter::Int=500,
                       tol::Float64=1e-8, output::String="", format::String="table")
    k_regimes >= 2 || throw(CliError("usage/invalid",
        "estimate ms: --k-regimes must be ≥ 2 (got $k_regimes)"))
    max_iter >= 1 || throw(CliError("usage/invalid",
        "estimate ms: --max-iter must be ≥ 1 (got $max_iter)"))
    tol > 0 || throw(CliError("usage/invalid", "estimate ms: --tol must be > 0 (got $tol)"))
    sv = !no_switching_variance
    y = Float64[]; X = nothing; xcols = String[]; intercept_only = false
    try
        y, X, xcols = _load_reg_data(data, dep)
    catch e
        if e isa CliError && e.code == "data/invalid" && occursin("no regressor columns", e.message)
            df = load_data(data)
            numcols = variable_names(df)
            dep_col = isempty(dep) ? numcols[1] : dep
            idx = findfirst(==(dep_col), numcols)
            idx === nothing && rethrow(e)
            y, _ = load_univariate_series(data, idx)
            X = nothing; xcols = String["const"]; intercept_only = true
        else
            rethrow(e)
        end
    end
    _status("Estimating MS regression [$k_regimes regimes]: obs=$(length(y)), " *
            (intercept_only ? "intercept-only" : "regressors=$(length(xcols))") *
            (sv ? ", switching variance" : ", common variance")); _status()
    model = try
        X === nothing ?
            estimate_ms(y; k_regimes=k_regimes, switching_variance=sv, max_iter=max_iter, tol=tol) :
            estimate_ms(y, X; k_regimes=k_regimes, switching_variance=sv, max_iter=max_iter,
                        tol=tol, xnames=xcols)
    catch e
        throw(_nonlinear_error(e, "MS regression"))
    end
    return _ms_render(model, format, output)
end
