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

# Residuals commands: model residuals for var, bvar, arima, vecm,
#                     static, dynamic, gdfm, arch, garch, egarch, gjr_garch, sv

function residuals_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["residuals", "var"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_var, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_var),
        ),
        CommandSpec(
            path=["residuals", "bvar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Lag order"),
                OptionSpec(name="draws", short="n", type=Int, default=2000, description="MCMC draws"),
                OptionSpec(name="sampler", type=String, default="direct", description="direct|gibbs"),
                OptionSpec(name="config", type=String, default="", description="TOML config for prior hyperparameters"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_bvar, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_bvar),
        ),
        CommandSpec(
            path=["residuals", "arima"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=nothing, description="AR order (default: auto selection)"),
                OptionSpec(name="d", type=Int, default=0, description="Differencing order"),
                OptionSpec(name="q", type=Int, default=0, description="MA order"),
                OptionSpec(name="method", short="m", type=String, default="css_mle", description="ols|css|mle|css_mle"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_arima, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_arima),
        ),
        CommandSpec(
            path=["residuals", "vecm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_vecm, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_vecm),
        ),
        CommandSpec(
            path=["residuals", "static"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of factors (default: auto via IC)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_static, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_static),
        ),
        CommandSpec(
            path=["residuals", "dynamic"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
                OptionSpec(name="factor-lags", short="p", type=Int, default=1, description="Factor VAR lag order"),
                OptionSpec(name="method", type=String, default="twostep", description="twostep|em"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_dynamic, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_dynamic),
        ),
        CommandSpec(
            path=["residuals", "gdfm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="nfactors", short="r", type=Int, default=nothing, description="Number of static factors (default: auto)"),
                OptionSpec(name="dynamic-rank", short="q", type=Int, default=nothing, description="Dynamic rank (default: auto)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_gdfm, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_gdfm),
        ),
        CommandSpec(
            path=["residuals", "arch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_arch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_arch),
        ),
        CommandSpec(
            path=["residuals", "garch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_garch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_garch),
        ),
        CommandSpec(
            path=["residuals", "egarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="EGARCH order"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_egarch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_egarch),
        ),
        CommandSpec(
            path=["residuals", "gjr_garch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GJR-GARCH order"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_gjr_garch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_gjr_garch),
        ),
        CommandSpec(
            path=["residuals", "sv"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="draws", short="n", type=Int, default=5000, description="MCMC draws"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_sv, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_sv),
        ),
        CommandSpec(
            path=["residuals", "favar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="factors", short="r", type=Int, default=nothing, description="Number of factors (default: auto)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="VAR lag order"),
                OptionSpec(name="key-vars", type=String, default="", description="Key variable names or indices (comma-separated)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_favar, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_favar),
        ),
        CommandSpec(
            path=["residuals", "reg"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...,
                OptionSpec(name="weights", type=String, default="", description="Weight column name (WLS)")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_reg, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_reg),
        ),
        CommandSpec(
            path=["residuals", "logit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_logit, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_logit),
        ),
        CommandSpec(
            path=["residuals", "probit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_probit, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_probit),
        ),
        CommandSpec(
            path=["residuals", "preg"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                PREG_OPTIONS[1:2]...,
                PREG_OPTIONS[3:4]...,
                PREG_OPTIONS[5:6]...,
                PREG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_preg, description="Path to CSV panel data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_preg),
        ),
        CommandSpec(
            path=["residuals", "piv"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable"),
                OptionSpec(name="exog", type=String, default="", description="Exogenous regressors (comma-separated)"),
                OptionSpec(name="endog", type=String, default="", description="Endogenous regressors (comma-separated)"),
                OptionSpec(name="instruments", type=String, default="", description="Instruments (comma-separated)"),
                PREG_OPTIONS[3:4]...,
                PREG_OPTIONS[5:6]...,
                PREG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_piv, description="Path to CSV panel data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_piv),
        ),
        CommandSpec(
            path=["residuals", "plogit"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                PREG_OPTIONS[1:2]...,
                PREG_OPTIONS[3:4]...,
                PREG_OPTIONS[5:6]...,
                PREG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_plogit, description="Path to CSV panel data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_plogit),
        ),
        CommandSpec(
            path=["residuals", "pprobit"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                PREG_OPTIONS[1:2]...,
                PREG_OPTIONS[3:4]...,
                PREG_OPTIONS[5:6]...,
                PREG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_pprobit, description="Path to CSV panel data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_pprobit),
        ),
        CommandSpec(
            path=["residuals", "ologit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_ologit, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_ologit),
        ),
        CommandSpec(
            path=["residuals", "oprobit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_oprobit, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_oprobit),
        ),
        CommandSpec(
            path=["residuals", "mlogit"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                REG_OPTIONS...
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_mlogit, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_mlogit),
        )
    ]
end

function register_residuals_commands!()
    specs = residuals_specs()
    register!(specs)
    return build_node("residuals", specs; description="Model residuals")
end


# ── VAR Residuals ───────────────────────────────────────

function _residuals_var(; data::String="", lags=nothing,
                          output::String="", format::String="table",
                          model=nothing)
    if isnothing(model)
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
    else
        varnames = model.varnames
        p = model.p
    end
    _status("Computing VAR($p) residuals: $(length(varnames)) variables")
    _status()

    resid = residuals(model)
    T_eff = size(resid, 1)

    res_df = DataFrame()
    res_df.t = 1:T_eff
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end

    output_result(res_df; format=Symbol(format), output=output,
                  title="VAR($p) Residuals (T_eff=$T_eff)")
end

# ── BVAR Residuals ──────────────────────────────────────

function _residuals_bvar(; data::String="", lags::Int=4, draws::Int=2000,
                           sampler::String="direct", config::String="",
                           output::String="", format::String="table",
                           model=nothing)
    if isnothing(model)
        post, Y, varnames, p, n = _load_and_estimate_bvar(data, lags, config, draws, sampler)
    else
        post = model
        varnames = post.varnames
        p = post.p
        Y = post.Y
    end

    _status("Computing BVAR($p) residuals (posterior mean)")
    _status("  Sampler: $sampler, Draws: $draws")
    _status()

    var_model = posterior_mean_model(post; data=Y)
    resid = residuals(var_model)
    T_eff = size(resid, 1)

    res_df = DataFrame()
    res_df.t = 1:T_eff
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end

    output_result(res_df; format=Symbol(format), output=output,
                  title="BVAR($p) Residuals (posterior mean, T_eff=$T_eff)")
end

# ── ARIMA Residuals ─────────────────────────────────────

function _residuals_arima(; data::String="", column::Int=1, p=nothing, d::Int=0, q::Int=0,
                            method::String="css_mle", auto::Bool=false,
                            output::String="", format::String="table",
                            model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        method_sym = Symbol(method)
        safe_method = method_sym == :css_mle ? :mle : method_sym

        model = if isnothing(p) || auto
            _status("Auto ARIMA residuals: variable=$vname, observations=$(length(y))")
            _status()
            m = auto_arima(y; method=safe_method)
            label = _model_label(ar_order(m), diff_order(m), ma_order(m))
            _status_styled("Selected model: $label\n"; bold=true)
            _status()
            m
        else
            label = _model_label(p, d, q)
            _status("$label residuals: variable=$vname")
            _status()
            _estimate_arima_model(y, p, d, q; method=method_sym)
        end
    end

    resid = residuals(model)

    p_sel = ar_order(model)
    d_sel = diff_order(model)
    q_sel = ma_order(model)
    label = _model_label(p_sel, d_sel, q_sel)

    res_df = DataFrame(
        t=1:length(resid),
        residual=round.(resid; digits=6)
    )

    output_result(res_df; format=Symbol(format), output=output,
                  title="$label Residuals for $vname")
end

# ── VECM Residuals ─────────────────────────────────────

function _residuals_vecm(; data::String="", lags::Int=2, rank::String="auto",
                           deterministic::String="constant",
                           output::String="", format::String="table",
                           model=nothing)
    if isnothing(model)
        vecm, Y, varnames, p = _load_and_estimate_vecm(data, lags, rank, deterministic, "johansen", 0.05)
    else
        vecm = model
        varnames = vecm.varnames
        p = vecm.p
    end
    r = cointegrating_rank(vecm)

    _status("Computing VECM residuals: rank=$r, lags=$p")
    _status()

    var_model = to_var(vecm)
    resid = residuals(var_model)
    T_eff = size(resid, 1)

    res_df = DataFrame()
    res_df.t = 1:T_eff
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end

    output_result(res_df; format=Symbol(format), output=output,
                  title="VECM Residuals (rank=$r, T_eff=$T_eff)")
end

# ── Static Factor Residuals ───────────────────────────

function _residuals_static(; data::String="", nfactors=nothing,
                             output::String="", format::String="table",
                             model=nothing)
    if isnothing(model)
        X, varnames = load_multivariate_data(data)

        r = if isnothing(nfactors)
            ic = ic_criteria(X, min(20, size(X, 2)))
            ic.r_IC1
        else
            nfactors
        end

        fm = estimate_factors(X, r)
    else
        fm = model
        varnames = fm.varnames
    end
    resid = residuals(fm)
    T = size(resid, 1)

    _status("Static factor model residuals: $r factors, idiosyncratic component (T=$T)")
    _status()

    res_df = DataFrame()
    res_df.t = 1:T
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end

    output_result(res_df; format=Symbol(format), output=output,
                  title="Static Factor Idiosyncratic Component ($r factors, T=$T)")
end

# ── Dynamic Factor Residuals ──────────────────────────

function _residuals_dynamic(; data::String="", nfactors=nothing, factor_lags::Int=1,
                              method::String="twostep",
                              output::String="", format::String="table",
                              model=nothing)
    if isnothing(model)
        X, varnames = load_multivariate_data(data)

        r = if isnothing(nfactors)
            ic = ic_criteria(X, min(10, size(X, 2)))
            ic.r_IC1
        else
            nfactors
        end

        fm = estimate_dynamic_factors(X, r, factor_lags; method=Symbol(method))
    else
        fm = model
        varnames = fm.varnames
    end
    resid = residuals(fm)
    T = size(resid, 1)

    _status("Dynamic factor model residuals: $r factors, p=$factor_lags, idiosyncratic component (T=$T)")
    _status()

    res_df = DataFrame()
    res_df.t = 1:T
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end

    output_result(res_df; format=Symbol(format), output=output,
                  title="Dynamic Factor Idiosyncratic Component ($r factors, p=$factor_lags, T=$T)")
end

# ── GDFM Residuals ────────────────────────────────────

function _residuals_gdfm(; data::String="", nfactors=nothing, dynamic_rank=nothing,
                           output::String="", format::String="table",
                           model=nothing)
    if isnothing(model)
        X, varnames = load_multivariate_data(data)

        q = if isnothing(dynamic_rank)
            ic = ic_criteria_gdfm(X, min(5, size(X, 2)))
            ic.q_ratio
        else
            dynamic_rank
        end

        gm = estimate_gdfm(X, q)
    else
        gm = model
        varnames = gm.varnames
    end
    resid = residuals(gm)
    T = size(resid, 1)

    _status("GDFM residuals: q=$q dynamic factors, idiosyncratic component (T=$T)")
    _status()

    res_df = DataFrame()
    res_df.t = 1:T
    for (vi, vname) in enumerate(varnames)
        res_df[!, vname] = resid[:, vi]
    end

    output_result(res_df; format=Symbol(format), output=output,
                  title="GDFM Idiosyncratic Component (q=$q, T=$T)")
end

# ── ARCH Residuals ────────────────────────────────────

function _residuals_arch(; data::String="", column::Int=1, q::Int=1,
                           output::String="", format::String="table",
                           model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        model = estimate_arch(y, q)
    else
        vname = "series"
    end
    resid = residuals(model)

    _status("ARCH($q) standardized residuals: variable=$vname")
    _status()

    res_df = DataFrame(t=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="ARCH($q) Standardized Residuals ($vname)")
end

# ── GARCH Residuals ───────────────────────────────────

function _residuals_garch(; data::String="", column::Int=1, p::Int=1, q::Int=1,
                            output::String="", format::String="table",
                            model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        model = estimate_garch(y, p, q)
    else
        vname = "series"
    end
    resid = residuals(model)

    _status("GARCH($p,$q) standardized residuals: variable=$vname")
    _status()

    res_df = DataFrame(t=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="GARCH($p,$q) Standardized Residuals ($vname)")
end

# ── EGARCH Residuals ──────────────────────────────────

function _residuals_egarch(; data::String="", column::Int=1, p::Int=1, q::Int=1,
                             output::String="", format::String="table",
                             model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        model = estimate_egarch(y, p, q)
    else
        vname = "series"
    end
    resid = residuals(model)

    _status("EGARCH($p,$q) standardized residuals: variable=$vname")
    _status()

    res_df = DataFrame(t=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="EGARCH($p,$q) Standardized Residuals ($vname)")
end

# ── GJR-GARCH Residuals ──────────────────────────────

function _residuals_gjr_garch(; data::String="", column::Int=1, p::Int=1, q::Int=1,
                                output::String="", format::String="table",
                                model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        model = estimate_gjr_garch(y, p, q)
    else
        vname = "series"
    end
    resid = residuals(model)

    _status("GJR-GARCH($p,$q) standardized residuals: variable=$vname")
    _status()

    res_df = DataFrame(t=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="GJR-GARCH($p,$q) Standardized Residuals ($vname)")
end

# ── SV Residuals ──────────────────────────────────────

function _residuals_sv(; data::String="", column::Int=1, draws::Int=5000,
                         output::String="", format::String="table",
                         model=nothing)
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        model = estimate_sv(y; n_samples=draws)
    else
        vname = "series"
    end
    resid = residuals(model)

    _status("SV standardized residuals: variable=$vname, draws=$draws")
    _status()

    res_df = DataFrame(t=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="SV Standardized Residuals ($vname)")
end

# ── FAVAR Residuals ───────────────────────────────────────

function _residuals_favar(; data::String="", factors=nothing, lags::Int=2,
                           key_vars::String="",
                           output::String="", format::String="table",
                           model=nothing)
    if isnothing(model)
        favar, Y, varnames = _load_and_estimate_favar(data, factors, lags, key_vars, "two_step", 5000)
    else
        favar = model
        varnames = favar.varnames
    end
    var_model = to_var(favar)

    _status("FAVAR Residuals")
    _status()

    resid = residuals(var_model)
    T_eff = size(resid, 1)

    res_df = DataFrame()
    res_df.t = 1:T_eff
    for v in 1:size(resid, 2)
        vname = v <= length(favar.varnames) ? favar.varnames[v] : "var_$v"
        res_df[!, vname] = round.(resid[:, v]; digits=6)
    end
    output_result(res_df; format=Symbol(format), output=output,
                  title="FAVAR Residuals (T_eff=$T_eff)")
end

# ── Regression Residuals ──────────────────────────────────

function _residuals_reg(; data::String="", dep::String="", cov_type::String="hc1",
                         weights::String="", clusters::String="",
                         output::String="", format::String="table",
                         model=nothing)
    if isnothing(model)
        y, X, xcols = _load_reg_data(data, dep; weights_col=weights, clusters_col=clusters)
        w = _load_weights(data, weights)
        cl = _load_clusters(data, clusters)
        model = estimate_reg(y, X; cov_type=Symbol(cov_type), weights=w, varnames=xcols, clusters=cl)
        dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
        wls_tag = isnothing(w) ? "OLS" : "WLS"
    else
        xcols = model.varnames
        dep_name = "y"
        wls_tag = "OLS"
    end
    _status("$wls_tag Residuals: $dep_name ~ $(join(xcols, " + "))")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output, title="$wls_tag Residuals")
end

# ── Logit Residuals ───────────────────────────────────────

function _residuals_logit(; data::String="", dep::String="", cov_type::String="hc1",
                           clusters::String="",
                           output::String="", format::String="table",
                           model=nothing)
    if isnothing(model)
        y, X, xcols = _load_reg_data(data, dep; clusters_col=clusters)
        cl = _load_clusters(data, clusters)
        model = estimate_logit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)
        dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    else
        xcols = model.varnames
        dep_name = "y"
    end
    _status("Logit Residuals: $dep_name ~ $(join(xcols, " + "))")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output, title="Logit Residuals")
end

# ── Probit Residuals ──────────────────────────────────────

function _residuals_probit(; data::String="", dep::String="", cov_type::String="hc1",
                            clusters::String="",
                            output::String="", format::String="table",
                            model=nothing)
    if isnothing(model)
        y, X, xcols = _load_reg_data(data, dep; clusters_col=clusters)
        cl = _load_clusters(data, clusters)
        model = estimate_probit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)
        dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    else
        xcols = model.varnames
        dep_name = "y"
    end
    _status("Probit Residuals: $dep_name ~ $(join(xcols, " + "))")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output, title="Probit Residuals")
end

# ── Panel Regression Residuals ──────────────────────────

function _residuals_preg(; data::String="", dep::String="", indep::String="",
                          method::String="fe", cov_type::String="cluster",
                          id_col::String="", time_col::String="",
                          output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel Regression Residuals ($method): $dep")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Panel Regression Residuals ($method)")
end

function _residuals_piv(; data::String="", dep::String="", exog::String="",
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

    model = estimate_xtiv(pd, Symbol(dep), exog_syms, endog_syms;
        instruments=inst_syms, model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel IV Residuals ($method): $dep")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Panel IV Residuals ($method)")
end

function _residuals_plogit(; data::String="", dep::String="", indep::String="",
                            method::String="pooled", cov_type::String="cluster",
                            id_col::String="", time_col::String="",
                            output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtlogit(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel Logit Residuals ($method): $dep")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Panel Logit Residuals ($method)")
end

function _residuals_pprobit(; data::String="", dep::String="", indep::String="",
                             method::String="pooled", cov_type::String="cluster",
                             id_col::String="", time_col::String="",
                             output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtprobit(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel Probit Residuals ($method): $dep")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Panel Probit Residuals ($method)")
end

# ── Ordered/Multinomial Residuals ───────────────────────

function _residuals_ologit(; data::String="", dep::String="", cov_type::String="hc1",
                            clusters::String="",
                            output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_ologit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    _status("Ordered Logit Residuals: $dep_name")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Ordered Logit Residuals")
end

function _residuals_oprobit(; data::String="", dep::String="", cov_type::String="hc1",
                             clusters::String="",
                             output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_oprobit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    _status("Ordered Probit Residuals: $dep_name")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Ordered Probit Residuals")
end

function _residuals_mlogit(; data::String="", dep::String="", cov_type::String="ols",
                            clusters::String="",
                            output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_mlogit(y, X; cov_type=Symbol(cov_type), varnames=xcols)

    _status("Multinomial Logit Residuals: $dep_name")
    _status()

    resid = residuals(model)
    res_df = DataFrame(observation=1:length(resid), residual=round.(resid; digits=6))
    output_result(res_df; format=Symbol(format), output=output,
                  title="Multinomial Logit Residuals")
end
