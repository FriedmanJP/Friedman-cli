# Fitted values / residuals — collapsed family (C025 / P2-3 / F9)
# Surface unchanged: `predict <model>` and `residuals <model>` remain distinct paths.

# Model kinds shared by predict + residuals (23). Specs generated from this table.
# Per-kind extra options stay on the relevant leaves only.



# ── VAR Predict ─────────────────────────────────────────

function _predict_var(; data::String="", lags=nothing,
                       output::String="", format::String="table",
                       model=nothing)
    if isnothing(model)
        model, Y, varnames, p = _load_and_estimate_var(data, lags)
    else
        varnames = model.varnames
        p = model.p
    end
    _status("Computing VAR($p) in-sample predictions: $(length(varnames)) variables")
    _status()

    fitted = predict(model)
    T_eff = size(fitted, 1)

    pred_df = DataFrame()
    pred_df.t = 1:T_eff
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end

    output_result(pred_df; format=Symbol(format), output=output,
                  title="VAR($p) In-Sample Predictions (T_eff=$T_eff)")
end

# ── BVAR Predict ────────────────────────────────────────

function _predict_bvar(; data::String="", lags::Int=4, draws::Int=2000,
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

    _status("Computing BVAR($p) in-sample predictions (posterior mean)")
    _status("  Sampler: $sampler, Draws: $draws")
    _status()

    var_model = posterior_mean_model(post; data=Y)
    fitted = predict(var_model)
    T_eff = size(fitted, 1)

    pred_df = DataFrame()
    pred_df.t = 1:T_eff
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end

    output_result(pred_df; format=Symbol(format), output=output,
                  title="BVAR($p) In-Sample Predictions (posterior mean, T_eff=$T_eff)")
end

# ── ARIMA Predict ───────────────────────────────────────

function _predict_arima(; data::String="", column::Int=1, p=nothing, d::Int=0, q::Int=0,
                          method::String="css_mle", auto::Bool=false,
                          output::String="", format::String="table",
                          model=nothing)
    # Bound BEFORE the branch: on the `--model <handle>` path there is no CSV to read a
    # column name from, and the title below is emitted on BOTH paths. Leaving it to the
    # branch made every `predict arima --model …` die with an UndefVarError (exit 1).
    vname = "model"
    if isnothing(model)
        y, vname = load_univariate_series(data, column)
        method_sym = Symbol(method)
        safe_method = method_sym == :css_mle ? :mle : method_sym

        model = if isnothing(p) || auto
            _status("Auto ARIMA predict: variable=$vname, observations=$(length(y))")
            _status()
            m = auto_arima(y; method=safe_method)
            label = _model_label(ar_order(m), diff_order(m), ma_order(m))
            _status_styled("Selected model: $label\n"; bold=true)
            _status()
            m
        else
            label = _model_label(p, d, q)
            _status("$label predict: variable=$vname")
            _status()
            _estimate_arima_model(y, p, d, q; method=method_sym)
        end
    end

    fitted = predict(model)

    p_sel = ar_order(model)
    d_sel = diff_order(model)
    q_sel = ma_order(model)
    label = _model_label(p_sel, d_sel, q_sel)

    pred_df = DataFrame(
        t=1:length(fitted),
        fitted=round.(fitted; digits=6)
    )

    output_result(pred_df; format=Symbol(format), output=output,
                  title="$label In-Sample Predictions for $vname")
end

# ── VECM Predict ───────────────────────────────────────

function _predict_vecm(; data::String="", lags::Int=2, rank::String="auto",
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

    _status("Computing VECM in-sample predictions: rank=$r, lags=$p")
    _status()

    var_model = to_var(vecm)
    fitted = predict(var_model)
    T_eff = size(fitted, 1)

    pred_df = DataFrame()
    pred_df.t = 1:T_eff
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end

    output_result(pred_df; format=Symbol(format), output=output,
                  title="VECM In-Sample Predictions (rank=$r, T_eff=$T_eff)")
end

# ── Static Factor Predict ─────────────────────────────

function _predict_static(; data::String="", nfactors=nothing,
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
    fitted = predict(fm)
    T = size(fitted, 1)

    _status("Static factor model: $r factors, common component (T=$T)")
    _status()

    pred_df = DataFrame()
    pred_df.t = 1:T
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end

    output_result(pred_df; format=Symbol(format), output=output,
                  title="Static Factor Common Component ($r factors, T=$T)")
end

# ── Dynamic Factor Predict ────────────────────────────

function _predict_dynamic(; data::String="", nfactors=nothing, factor_lags::Int=1,
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
    fitted = predict(fm)
    T = size(fitted, 1)

    _status("Dynamic factor model: $r factors, p=$factor_lags, common component (T=$T)")
    _status()

    pred_df = DataFrame()
    pred_df.t = 1:T
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end

    output_result(pred_df; format=Symbol(format), output=output,
                  title="Dynamic Factor Common Component ($r factors, p=$factor_lags, T=$T)")
end

# ── GDFM Predict ──────────────────────────────────────

function _predict_gdfm(; data::String="", nfactors=nothing, dynamic_rank=nothing,
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
    fitted = predict(gm)
    T = size(fitted, 1)

    _status("GDFM: q=$q dynamic factors, common component (T=$T)")
    _status()

    pred_df = DataFrame()
    pred_df.t = 1:T
    for (vi, vname) in enumerate(varnames)
        pred_df[!, vname] = fitted[:, vi]
    end

    output_result(pred_df; format=Symbol(format), output=output,
                  title="GDFM Common Component (q=$q, T=$T)")
end

# Volatility predict handlers live in shared.jl (VOL_MODELS / _VOL_PREDICT_HANDLERS).

# ── FAVAR Predict ─────────────────────────────────────────

function _predict_favar(; data::String="", factors=nothing, lags::Int=2,
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

    _status("FAVAR In-Sample Prediction")
    _status()

    fitted = predict(var_model)
    T_eff = size(fitted, 1)

    pred_df = DataFrame()
    pred_df.t = 1:T_eff
    for v in 1:size(fitted, 2)
        vname = v <= length(favar.varnames) ? favar.varnames[v] : "var_$v"
        pred_df[!, vname] = round.(fitted[:, v]; digits=6)
    end
    output_result(pred_df; format=Symbol(format), output=output,
                  title="FAVAR In-Sample Predictions (T_eff=$T_eff)")
end

# ── Regression Predict ────────────────────────────────────

function _predict_reg(; data::String="", dep::String="", cov_type::String="hc1",
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
    _status("$wls_tag Fitted Values: $dep_name ~ $(join(xcols, " + "))")
    _status()

    fitted = predict(model)
    pred_df = DataFrame(observation=1:length(fitted), fitted_value=round.(fitted; digits=6))
    output_result(pred_df; format=Symbol(format), output=output, title="$wls_tag Fitted Values")
end

# ── Logit Predict ─────────────────────────────────────────

function _predict_logit(; data::String="", dep::String="", cov_type::String="hc1",
                         clusters::String="", threshold::Float64=0.5,
                         marginal_effects::Bool=false, odds_ratio::Bool=false,
                         classification_table::Bool=false,
                         output::String="", format::String="table",
                         model=nothing)
    if isnothing(model)
        y, X, xcols = _load_reg_data(data, dep; clusters_col=clusters)
        cl = _load_clusters(data, clusters)
        model = estimate_logit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)
        dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    else
        dep_name = "y"
    end

    if marginal_effects
        me = MacroEconometricModels.marginal_effects(model)
        me_df = DataFrame(Variable=me.varnames, Effect=round.(me.effects; digits=6),
            SE=round.(me.se; digits=6), z=round.(me.z_stat; digits=4),
            p_value=round.(me.p_values; digits=4),
            CI_Lower=round.(me.ci_lower; digits=6), CI_Upper=round.(me.ci_upper; digits=6))
        output_result(me_df; format=Symbol(format), output=output,
                      title="Average Marginal Effects (Logit)")
    elseif odds_ratio
        or = MacroEconometricModels.odds_ratio(model)
        or_df = DataFrame(Variable=or.varnames, Odds_Ratio=round.(or.or; digits=6),
            CI_Lower=round.(or.ci_lower; digits=6), CI_Upper=round.(or.ci_upper; digits=6))
        output_result(or_df; format=Symbol(format), output=output,
                      title="Odds Ratios (Logit)")
    elseif classification_table
        ct = MacroEconometricModels.classification_table(model; threshold=threshold)
        _status("Classification Table (threshold=$threshold):")
        # Sort by KEY: the dict mixes scalars with a `confusion` matrix, so sorting
        # the pairs themselves compares a Matrix against a Float (exit 1).
        scalars = Pair{String,Any}[]
        confusion = nothing
        for k in sort(collect(keys(ct)))
            v = ct[k]
            if v isa AbstractMatrix
                confusion = v
            else
                push!(scalars, k => v isa AbstractFloat ? round(v; digits=6) : v)
            end
        end
        output_kv(scalars; format=format, output=output,
                  title="Classification Metrics (threshold=$threshold)")
        if confusion !== nothing
            conf_df = DataFrame(confusion, ["predicted_$j" for j in 0:size(confusion, 2) - 1];
                                makeunique=true)
            insertcols!(conf_df, 1, :actual => ["actual_$i" for i in 0:size(confusion, 1) - 1];
                        makeunique=true)
            output_result(conf_df; format=Symbol(format),
                          output=_per_var_output_path(output, "confusion"),
                          title="Confusion Matrix")
        end
    else
        _status("Logit Fitted Probabilities: $dep_name")
        _status()
        fitted = predict(model)
        pred_df = DataFrame(observation=1:length(fitted), fitted_prob=round.(fitted; digits=6))
        output_result(pred_df; format=Symbol(format), output=output,
                      title="Logit Fitted Probabilities")
    end
end

# ── Probit Predict ────────────────────────────────────────

function _predict_probit(; data::String="", dep::String="", cov_type::String="hc1",
                          clusters::String="", threshold::Float64=0.5,
                          marginal_effects::Bool=false,
                          classification_table::Bool=false,
                          output::String="", format::String="table",
                          model=nothing)
    if isnothing(model)
        y, X, xcols = _load_reg_data(data, dep; clusters_col=clusters)
        cl = _load_clusters(data, clusters)
        model = estimate_probit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)
        dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    else
        dep_name = "y"
    end

    if marginal_effects
        me = MacroEconometricModels.marginal_effects(model)
        me_df = DataFrame(Variable=me.varnames, Effect=round.(me.effects; digits=6),
            SE=round.(me.se; digits=6), z=round.(me.z_stat; digits=4),
            p_value=round.(me.p_values; digits=4),
            CI_Lower=round.(me.ci_lower; digits=6), CI_Upper=round.(me.ci_upper; digits=6))
        output_result(me_df; format=Symbol(format), output=output,
                      title="Average Marginal Effects (Probit)")
    elseif classification_table
        ct = MacroEconometricModels.classification_table(model; threshold=threshold)
        _status("Classification Table (threshold=$threshold):")
        # Sort by KEY: the dict mixes scalars with a `confusion` matrix, so sorting
        # the pairs themselves compares a Matrix against a Float (exit 1).
        scalars = Pair{String,Any}[]
        confusion = nothing
        for k in sort(collect(keys(ct)))
            v = ct[k]
            if v isa AbstractMatrix
                confusion = v
            else
                push!(scalars, k => v isa AbstractFloat ? round(v; digits=6) : v)
            end
        end
        output_kv(scalars; format=format, output=output,
                  title="Classification Metrics (threshold=$threshold)")
        if confusion !== nothing
            conf_df = DataFrame(confusion, ["predicted_$j" for j in 0:size(confusion, 2) - 1];
                                makeunique=true)
            insertcols!(conf_df, 1, :actual => ["actual_$i" for i in 0:size(confusion, 1) - 1];
                        makeunique=true)
            output_result(conf_df; format=Symbol(format),
                          output=_per_var_output_path(output, "confusion"),
                          title="Confusion Matrix")
        end
    else
        _status("Probit Fitted Probabilities: $dep_name")
        _status()
        fitted = predict(model)
        pred_df = DataFrame(observation=1:length(fitted), fitted_prob=round.(fitted; digits=6))
        output_result(pred_df; format=Symbol(format), output=output,
                      title="Probit Fitted Probabilities")
    end
end

# ── Panel Regression Predict ────────────────────────────

function _predict_preg(; data::String, dep::String="", indep::String="",
                        method::String="fe", cov_type::String="cluster",
                        id_col::String="", time_col::String="",
                        output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel Regression Fitted Values ($method): $dep")
    _status()

    fitted = predict(model)
    pred_df = DataFrame(observation=1:length(fitted), fitted_value=round.(fitted; digits=6))
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Panel Regression Fitted Values ($method)")
end

function _predict_piv(; data::String, dep::String="", exog::String="",
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

    _status("Panel IV Fitted Values ($method): $dep")
    _status()

    fitted = predict(model)
    pred_df = DataFrame(observation=1:length(fitted), fitted_value=round.(fitted; digits=6))
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Panel IV Fitted Values ($method)")
end

function _predict_plogit(; data::String, dep::String="", indep::String="",
                          method::String="pooled", cov_type::String="cluster",
                          id_col::String="", time_col::String="",
                          output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtlogit(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel Logit Fitted Probabilities ($method): $dep")
    _status()

    fitted = predict(model)
    pred_df = DataFrame(observation=1:length(fitted), fitted_prob=round.(fitted; digits=6))
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Panel Logit Fitted Probabilities ($method)")
end

function _predict_pprobit(; data::String, dep::String="", indep::String="",
                           method::String="pooled", cov_type::String="cluster",
                           id_col::String="", time_col::String="",
                           output::String="", format::String="table")
    isempty(dep) && error("--dep is required")
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtprobit(pd, Symbol(dep), indep_syms;
        model=_to_sym(method), cov_type=_to_sym(cov_type))

    _status("Panel Probit Fitted Probabilities ($method): $dep")
    _status()

    fitted = predict(model)
    pred_df = DataFrame(observation=1:length(fitted), fitted_prob=round.(fitted; digits=6))
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Panel Probit Fitted Probabilities ($method)")
end

# ── Ordered/Multinomial Predict ─────────────────────────

"""
    _choice_prob_table(probs, categories) → DataFrame

Tidy per-category predicted probabilities.

`predict` on an ordered/multinomial model returns an `n x n_categories` matrix, not a
vector — feeding it straight to `DataFrame` raised "adding AbstractArray other than
AbstractVector as a column" (exit 1) on every call (#85).
"""
function _choice_prob_table(probs::AbstractMatrix, categories)
    df = DataFrame(observation=1:size(probs, 1))
    labels = length(categories) == size(probs, 2) ? string.(categories) :
             string.(1:size(probs, 2))
    for (j, lab) in enumerate(labels)
        df[!, "prob_$lab"] = round.(probs[:, j]; digits=6)
    end
    return df
end

# A univariate result still renders as a single fitted-probability column.
_choice_prob_table(probs::AbstractVector, categories) =
    DataFrame(observation=1:length(probs), fitted_prob=round.(probs; digits=6))

function _predict_ologit(; data::String="", dep::String="", cov_type::String="hc1",
                          clusters::String="",
                          output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_ologit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    _status("Ordered Logit Predicted Probabilities: $dep_name")
    _status()

    fitted = predict(model)
    pred_df = _choice_prob_table(fitted, model.categories)
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Ordered Logit Predicted Probabilities")
end

function _predict_oprobit(; data::String="", dep::String="", cov_type::String="hc1",
                           clusters::String="",
                           output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_oprobit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    _status("Ordered Probit Predicted Probabilities: $dep_name")
    _status()

    fitted = predict(model)
    pred_df = _choice_prob_table(fitted, model.categories)
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Ordered Probit Predicted Probabilities")
end

function _predict_mlogit(; data::String="", dep::String="", cov_type::String="ols",
                          clusters::String="",
                          output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_mlogit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    _status("Multinomial Logit Predicted Probabilities: $dep_name")
    _status()

    fitted = predict(model)
    pred_df = _choice_prob_table(fitted, model.categories)
    output_result(pred_df; format=Symbol(format), output=output,
                  title="Multinomial Logit Predicted Probabilities")
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
    # See _predict_arima: bound before the branch so the shared title below cannot hit an
    # UndefVarError on the `--model <handle>` path.
    vname = "model"
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

# Volatility residual handlers live in shared.jl (VOL_MODELS / _VOL_RESIDUALS_HANDLERS).

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

"""
    _unsupported_residuals(label, leaf)

Ordered/multinomial choice models have no `residuals` method in MEMs 0.7.0, and there
is no single standard residual definition for them (the test mock used to invent
`y - fitted[:, 1]`, which is not a recognised statistic). Fail with a typed error
rather than fabricate one — `predict` gives the per-category probabilities.

Filed upstream as MacroEconometricModels.jl#507 (which also asks them to settle the
return shape: an `n x K` response-residual matrix vs a length-`n` generalised
residual). Re-enabling these leaves is gated on that: CLI issue #87. If upstream
declines, remove the three leaves at v1.0 (C055) instead of shipping leaves that
can only error.
"""
_unsupported_residuals(label::String, leaf::String) =
    throw(CliError("model/unsupported",
        "$label residuals are not defined upstream (MEMs 0.7.0 has no residuals method)";
        hint="use 'friedman predict $leaf' for per-category predicted probabilities"))

function _residuals_ologit(; data::String="", dep::String="", cov_type::String="hc1",
                            clusters::String="",
                            output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    cl = _load_clusters(data, clusters)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_ologit(y, X; cov_type=Symbol(cov_type), varnames=xcols, clusters=cl)

    _status("Ordered Logit Residuals: $dep_name")
    _status()

    _unsupported_residuals("Ordered Logit", "ologit")
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

    _unsupported_residuals("Ordered Probit", "oprobit")
end

function _residuals_mlogit(; data::String="", dep::String="", cov_type::String="ols",
                            clusters::String="",
                            output::String="", format::String="table")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_mlogit(y, X; cov_type=Symbol(cov_type), varnames=xcols)

    _status("Multinomial Logit Residuals: $dep_name")
    _status()

    _unsupported_residuals("Multinomial Logit", "mlogit")
end


function _fitted_data_arg()
    return [ArgSpec(name="data", description="Path to CSV data file")]
end

# Extra option sets for discrete choice / special leaves
# The handlers take `marginal_effects`/`odds_ratio`/`classification_table` as `Bool`,
# so these MUST be flags. Declaring them as String options made the default `""`
# fail Bool conversion on every call ("non-boolean (String) used in boolean
# context" -> exit 1), breaking predict logit|probit|ologit|oprobit|mlogit
# outright; none had T3 coverage (#85).
const _LOGIT_EXTRA = [
    OptionSpec(name="threshold", type=Float64, default=0.5, description="Classification threshold"),
]
const _LOGIT_EXTRA_FLAGS = [
    FlagSpec(name="marginal-effects", description="Report average marginal effects"),
    FlagSpec(name="odds-ratio", description="Report odds ratios (logit)"),
    FlagSpec(name="classification-table", description="Report the classification table"),
]
# NOTE: no extras for the ordered/multinomial leaves. `_predict_ologit`,
# `_predict_oprobit` and `_predict_mlogit` accept no `marginal_effects`,
# `category` or `base_category` kwargs, so declaring them produced a
# MethodError -> exit 1 on every call. Add the options back only together with
# handler support.
const _ORDERED_EXTRA = OptionSpec[]
const _MLOGIT_EXTRA = OptionSpec[]

"""Flags for a fitted leaf — only `predict` exposes the discrete-choice reports."""
function _flags_for_kind(kind::Symbol, verb::Symbol)
    verb === :predict || return FlagSpec[]
    kind === :logit && return _LOGIT_EXTRA_FLAGS
    kind === :probit && return filter(f -> f.name != "odds-ratio", _LOGIT_EXTRA_FLAGS)
    return FlagSpec[]
end

# kind => (handler_predict, handler_residuals, opts_builder_symbol)
const FITTED_MODEL_KINDS = [
    (; name="var",        pred=_predict_var,        res=_residuals_var,        kind=:var),
    (; name="bvar",       pred=_predict_bvar,       res=_residuals_bvar,       kind=:bvar),
    (; name="arima",      pred=_predict_arima,      res=_residuals_arima,      kind=:arima),
    (; name="vecm",       pred=_predict_vecm,       res=_residuals_vecm,       kind=:vecm),
    (; name="static",     pred=_predict_static,     res=_residuals_static,     kind=:factor),
    (; name="dynamic",    pred=_predict_dynamic,    res=_residuals_dynamic,    kind=:factor),
    (; name="gdfm",       pred=_predict_gdfm,       res=_residuals_gdfm,       kind=:factor),
    (; name="arch",       pred=_VOL_PREDICT_HANDLERS["arch"],       res=_VOL_RESIDUALS_HANDLERS["arch"],       kind=:vol),
    (; name="garch",      pred=_VOL_PREDICT_HANDLERS["garch"],      res=_VOL_RESIDUALS_HANDLERS["garch"],      kind=:vol),
    (; name="egarch",     pred=_VOL_PREDICT_HANDLERS["egarch"],     res=_VOL_RESIDUALS_HANDLERS["egarch"],     kind=:vol),
    # C044: kebab primary; snake alias applied in _specs_for_verb
    (; name="gjr-garch",  pred=_VOL_PREDICT_HANDLERS["gjr_garch"],  res=_VOL_RESIDUALS_HANDLERS["gjr_garch"],  kind=:vol),
    (; name="sv",         pred=_VOL_PREDICT_HANDLERS["sv"],         res=_VOL_RESIDUALS_HANDLERS["sv"],         kind=:vol),
    (; name="favar",      pred=_predict_favar,      res=_residuals_favar,      kind=:favar),
    (; name="reg",        pred=_predict_reg,        res=_residuals_reg,        kind=:reg),
    (; name="logit",      pred=_predict_logit,      res=_residuals_logit,      kind=:logit),
    (; name="probit",     pred=_predict_probit,     res=_residuals_probit,     kind=:probit),
    (; name="preg",       pred=_predict_preg,       res=_residuals_preg,       kind=:preg),
    (; name="piv",        pred=_predict_piv,        res=_residuals_piv,        kind=:preg),
    (; name="plogit",     pred=_predict_plogit,     res=_residuals_plogit,     kind=:preg),
    (; name="pprobit",    pred=_predict_pprobit,    res=_residuals_pprobit,    kind=:preg),
    (; name="ologit",     pred=_predict_ologit,     res=_residuals_ologit,     kind=:ologit),
    (; name="oprobit",    pred=_predict_oprobit,    res=_residuals_oprobit,    kind=:oprobit),
    (; name="mlogit",     pred=_predict_mlogit,     res=_residuals_mlogit,     kind=:mlogit),
]

function _opts_for_kind(kind::Symbol, verb::Symbol)
    if kind === :reg
        opts = copy(REG_OPTIONS)
        # weights for reg
        push!(opts, OptionSpec(name="weights", type=String, default="", description="Weights column"))
        return opts
    elseif kind === :preg
        return copy(PREG_OPTIONS)
    elseif kind === :vol || kind === :arima
        return [
            OptionSpec(name="column", short="c", type=Int, default=1, description="Column index"),
            OUTPUT_OPTIONS...,
        ]
    elseif kind === :factor
        return [
            OptionSpec(name="nfactors", type=Int, default=nothing, description="Number of factors"),
            OptionSpec(name="lags", short="p", type=Int, default=1, description="Lags"),
            OUTPUT_OPTIONS...,
        ]
    elseif kind === :logit
        return [REG_OPTIONS...; (verb === :predict ? _LOGIT_EXTRA : OptionSpec[])]
    elseif kind === :probit
        return [REG_OPTIONS...; (verb === :predict ? _LOGIT_EXTRA : OptionSpec[])]
    elseif kind === :ologit || kind === :oprobit
        return [REG_OPTIONS...; (verb === :predict ? _ORDERED_EXTRA : OptionSpec[])]
    elseif kind === :mlogit
        return [REG_OPTIONS...; (verb === :predict ? _MLOGIT_EXTRA : OptionSpec[])]
    elseif kind === :bvar
        return [
            OptionSpec(name="lags", short="p", type=Int, default=4, description="Lag order"),
            OptionSpec(name="draws", short="n", type=Int, default=2000, description="MCMC draws"),
            OptionSpec(name="sampler", type=String, default="direct", description="Sampler"),
            OptionSpec(name="config", type=String, default="", description="TOML prior config"),
            OUTPUT_OPTIONS...,
        ]
    elseif kind === :favar
        return [
            OptionSpec(name="factors", short="r", type=Int, default=nothing, description="Number of factors"),
            OptionSpec(name="lags", short="p", type=Int, default=2, description="VAR lags"),
            OptionSpec(name="key-vars", type=String, default="", description="Key variables"),
            OUTPUT_OPTIONS...,
        ]
    elseif kind === :vecm
        return [
            OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order"),
            OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank"),
            OUTPUT_OPTIONS...,
        ]
    else # :var default
        return [
            OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto)"),
            OUTPUT_OPTIONS...,
        ]
    end
end

# C044 snake→kebab aliases for fitted leaves
const _FITTED_CLI_ALIASES = Dict("gjr-garch" => ["gjr_garch"])

function _specs_for_verb(verb::Symbol, title_prefix::String)
    specs = CommandSpec[]
    for m in FITTED_MODEL_KINDS
        handler = verb === :predict ? m.pred : m.res
        path0 = verb === :predict ? "predict" : "residuals"
        aliases = get(_FITTED_CLI_ALIASES, m.name, String[])
        tbl = replace(m.name, "-" => "_")
        push!(specs, CommandSpec(
            path=[path0, m.name],
            summary="$title_prefix ($(m.name))",
            args=_fitted_data_arg(),
            options=_opts_for_kind(m.kind, verb),
            flags=_flags_for_kind(m.kind, verb),
            tables=[TableSpec(name=Symbol("$(path0)_$tbl"), description=title_prefix)],
            category=path0,
            aliases=aliases,
            handler=wrap_legacy(handler),
        ))
    end
    return specs
end

function predict_specs()::Vector{CommandSpec}
    # The six C064a GARCH variants are NOT in VOL_MODELS (their option sets differ), so
    # _specs_for_verb cannot generate them — append their hand-written specs (#69).
    return vcat(_specs_for_verb(:predict, "In-sample fitted values"), CommandSpec[
        # #71: state-space state paths / innovations, read from the model's fields.
        CommandSpec(
            path=["predict", "statespace"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                # `--model` is reserved for the model HANDLE on predict/residuals (injected
                # by with_model_option, which does NOT dedupe), so the model TYPE is --kind
                # here — same value set as `estimate statespace --model`.
                OptionSpec(name="kind", type=String, default="local-level", description="State-space model", choices=["local-level","local-linear-trend"]),
                OptionSpec(name="init-mode", type=String, default="kappa", description="Diffuse initialisation", choices=["kappa","diffuse"]),
                OptionSpec(name="kappa", type=Float64, default=1e6, description="Large-kappa diffuse prior variance"),
                OptionSpec(name="state", type=String, default="both", description="Which state path to emit", choices=["filtered","smoothed","both"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_statespace, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_statespace),
        ),
        # #68: SUR/3SLS carry PER-EQUATION fitted/residuals fields. Both mirror their
        # `estimate` sibling's options because the equation system lives in --config —
        # without it the model cannot be refit.
        CommandSpec(
            path=["predict", "sur"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML with [[equations]] blocks (required)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="iterate", description="Iterate the SUR feasible-GLS step to convergence"),
                   FlagSpec(name="no-intercept", description="Do not add an intercept to each equation")],
            tables=[TableSpec(name=:predict_sur, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_sur),
        ),
        CommandSpec(
            path=["predict", "3sls"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML with [[equations]] and instruments (required)"),
                OptionSpec(name="instruments", type=String, default="common", description="Instrument mode", choices=["common","perequation"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="no-intercept", description="Do not add an intercept to each equation")],
            tables=[TableSpec(name=:predict_3sls, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_3sls),
        ),
        # #73: ARFIMA mirrors `estimate arfima`'s full option set — the :arima kind in
        # FITTED_MODEL_KINDS supplies only --column, which would silently pin p=q=0.
        CommandSpec(
            path=["predict", "arfima"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=0, description="AR order"),
                OptionSpec(name="q", type=Int, default=0, description="MA order"),
                OptionSpec(name="method", short="m", type=String, default="css", description="css|mle (fractional-integration estimator)", choices=["css","mle"]),
                OptionSpec(name="d0", type=Float64, default=nothing, description="Starting value for d (default: GPH pre-estimate)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_arfima, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_arfima),
        ),
        CommandSpec(
            path=["predict", "igarch"],
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
            tables=[TableSpec(name=:predict_igarch, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_igarch),
        ),
        CommandSpec(
            path=["predict", "cgarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_cgarch, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_cgarch),
        ),
        CommandSpec(
            path=["predict", "aparch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="fix-delta", type=Float64, default=nothing, description="Fix the power parameter delta"),
                OptionSpec(name="fix-gamma", type=Float64, default=nothing, description="Fix the asymmetry parameter gamma"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_aparch, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_aparch),
        ),
        CommandSpec(
            path=["predict", "figarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="d0", type=Float64, default=0.4, description="Initial fractional differencing parameter"),
                OptionSpec(name="truncation", type=Int, default=1000, description="Truncation lag for the ARCH(inf) expansion"),
                OptionSpec(name="dist", type=String, default="normal", description="Innovation distribution"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_figarch, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_figarch),
        ),
        CommandSpec(
            path=["predict", "fiegarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="d0", type=Float64, default=0.4, description="Initial fractional differencing parameter"),
                OptionSpec(name="truncation", type=Int, default=1000, description="Truncation lag for the ARCH(inf) expansion"),
                OptionSpec(name="dist", type=String, default="normal", description="Innovation distribution"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_fiegarch, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_fiegarch),
        ),
        CommandSpec(
            path=["predict", "garch-midas"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="m-freq", type=Int, default=0, description="High-frequency observations per low-frequency block (required, ≥ 1)"),
                OptionSpec(name="k", type=Int, default=12, description="Number of MIDAS lags"),
                OptionSpec(name="rv", type=String, default="realized", description="Long-run driver", choices=["realized","macro"]),
                OptionSpec(name="span", type=String, default="fixed", description="Span", choices=["fixed","rolling"]),
                OptionSpec(name="config", type=String, default="", description="TOML with [garch_midas] x_lf (required for --rv macro)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:predict_garch_midas, description="Path to CSV data file")],
            category="predict",
            handler=wrap_legacy(_predict_garch_midas),
        ),
    ])
end

function residuals_specs()::Vector{CommandSpec}
    return vcat(_specs_for_verb(:residuals, "Model residuals"), CommandSpec[
        # #70 remainder: the nonlinear-TS models all define StatsAPI.residuals upstream
        # (ThresholdModel/STARModel/MSRegModel). NO matching `predict` — none of them EXPOSES
        # predict/fitted. For the MS models the fitted series is well defined (the
        # regime-probability-weighted conditional mean) and MEMs already computes it internally
        # to form these very residuals — it just doesn't store it. Filed as MEMs#510; adding a
        # leaf that recomputes it risks diverging from the definition upstream publishes.
        # Options mirror the `estimate` sibling MINUS the ones that drive only the attached
        # inference (SETAR's --reps/--ci-level/--het feed the Hansen bootstrap and threshold
        # CI, never the residuals); the refit passes linearity=false to skip that bootstrap.
        CommandSpec(
            path=["residuals", "setar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="d", type=String, default="1", description="Delay lag: an integer ≥ 1, or 'auto' (=1:p grid)"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming fraction for the threshold grid (0 < trim < 0.5)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_setar, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_setar),
        ),
        CommandSpec(
            path=["residuals", "star"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="d", type=Int, default=1, description="Delay lag for the self-exciting transition var (≥ 1)"),
                OptionSpec(name="type", type=String, default="auto", description="Transition shape: lstr1|lstr2|estr|auto", choices=["lstr1","lstr2","estr","auto"]),
                OptionSpec(name="n-gamma", type=Int, default=15, description="Grid points for the γ start values (≥ 2)"),
                OptionSpec(name="n-c", type=Int, default=15, description="Grid points for the c start values (≥ 2)"),
                OptionSpec(name="transition-col", type=Int, default=0, description="Column index of an external transition var s (0 = self-exciting y[t-d])"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_star, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_star),
        ),
        CommandSpec(
            path=["residuals", "ms-ar"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="k-regimes", type=Int, default=2, description="Number of regimes (≥ 2)"),
                OptionSpec(name="max-iter", type=Int, default=1000, description="Max EM iterations (≥ 1)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            # NOTE the OPPOSITE default from `residuals ms` below — ms-ar's switching_variance
            # is FALSE upstream (Hamilton form), ms regression's is TRUE. Do not unify them.
            flags=[FlagSpec(name="switching-variance", description="Let σ² switch across regimes (default: off, Hamilton form)")],
            tables=[TableSpec(name=:residuals_ms_ar, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_ms_ar),
        ),
        CommandSpec(
            path=["residuals", "ms"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="k-regimes", type=Int, default=2, description="Number of regimes (≥ 2)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Max EM iterations (≥ 1)"),
                OptionSpec(name="tol", type=Float64, default=1e-8, description="EM convergence tolerance (> 0)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="no-switching-variance", description="Force common σ² across regimes (default: σ² switches)")],
            tables=[TableSpec(name=:residuals_ms, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_ms),
        ),
        # #71: state-space state paths / innovations, read from the model's fields.
        CommandSpec(
            path=["residuals", "statespace"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                # `--model` is reserved for the model HANDLE on predict/residuals (injected
                # by with_model_option, which does NOT dedupe), so the model TYPE is --kind
                # here — same value set as `estimate statespace --model`.
                OptionSpec(name="kind", type=String, default="local-level", description="State-space model", choices=["local-level","local-linear-trend"]),
                OptionSpec(name="init-mode", type=String, default="kappa", description="Diffuse initialisation", choices=["kappa","diffuse"]),
                OptionSpec(name="kappa", type=Float64, default=1e6, description="Large-kappa diffuse prior variance"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="standardized", description="Emit standardized innovations v_t/sqrt(F_t) instead of raw v_t")],
            tables=[TableSpec(name=:residuals_statespace, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_statespace),
        ),
        # #68: SUR/3SLS carry PER-EQUATION fitted/residuals fields. Both mirror their
        # `estimate` sibling's options because the equation system lives in --config —
        # without it the model cannot be refit.
        CommandSpec(
            path=["residuals", "sur"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML with [[equations]] blocks (required)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="iterate", description="Iterate the SUR feasible-GLS step to convergence"),
                   FlagSpec(name="no-intercept", description="Do not add an intercept to each equation")],
            tables=[TableSpec(name=:residuals_sur, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_sur),
        ),
        CommandSpec(
            path=["residuals", "3sls"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML with [[equations]] and instruments (required)"),
                OptionSpec(name="instruments", type=String, default="common", description="Instrument mode", choices=["common","perequation"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=[FlagSpec(name="no-intercept", description="Do not add an intercept to each equation")],
            tables=[TableSpec(name=:residuals_3sls, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_3sls),
        ),
        # #73: ARFIMA mirrors `estimate arfima`'s full option set — the :arima kind in
        # FITTED_MODEL_KINDS supplies only --column, which would silently pin p=q=0.
        CommandSpec(
            path=["residuals", "arfima"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=0, description="AR order"),
                OptionSpec(name="q", type=Int, default=0, description="MA order"),
                OptionSpec(name="method", short="m", type=String, default="css", description="css|mle (fractional-integration estimator)", choices=["css","mle"]),
                OptionSpec(name="d0", type=Float64, default=nothing, description="Starting value for d (default: GPH pre-estimate)"),
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_arfima, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_arfima),
        ),
        CommandSpec(
            path=["residuals", "igarch"],
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
            tables=[TableSpec(name=:residuals_igarch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_igarch),
        ),
        CommandSpec(
            path=["residuals", "cgarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_cgarch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_cgarch),
        ),
        CommandSpec(
            path=["residuals", "aparch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="fix-delta", type=Float64, default=nothing, description="Fix the power parameter delta"),
                OptionSpec(name="fix-gamma", type=Float64, default=nothing, description="Fix the asymmetry parameter gamma"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_aparch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_aparch),
        ),
        CommandSpec(
            path=["residuals", "figarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="d0", type=Float64, default=0.4, description="Initial fractional differencing parameter"),
                OptionSpec(name="truncation", type=Int, default=1000, description="Truncation lag for the ARCH(inf) expansion"),
                OptionSpec(name="dist", type=String, default="normal", description="Innovation distribution"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_figarch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_figarch),
        ),
        CommandSpec(
            path=["residuals", "fiegarch"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="d0", type=Float64, default=0.4, description="Initial fractional differencing parameter"),
                OptionSpec(name="truncation", type=Int, default=1000, description="Truncation lag for the ARCH(inf) expansion"),
                OptionSpec(name="dist", type=String, default="normal", description="Innovation distribution"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_fiegarch, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_fiegarch),
        ),
        CommandSpec(
            path=["residuals", "garch-midas"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index (1-based)"),
                OptionSpec(name="m-freq", type=Int, default=0, description="High-frequency observations per low-frequency block (required, ≥ 1)"),
                OptionSpec(name="k", type=Int, default=12, description="Number of MIDAS lags"),
                OptionSpec(name="rv", type=String, default="realized", description="Long-run driver", choices=["realized","macro"]),
                OptionSpec(name="span", type=String, default="fixed", description="Span", choices=["fixed","rolling"]),
                OptionSpec(name="config", type=String, default="", description="TOML with [garch_midas] x_lf (required for --rv macro)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:residuals_garch_midas, description="Path to CSV data file")],
            category="residuals",
            handler=wrap_legacy(_residuals_garch_midas),
        ),
    ])
end

function register_predict_commands!()
    specs = with_config_ergonomics(with_model_option(predict_specs()))
    register!(specs)
    return build_node("predict", specs; description="In-sample fitted values / predictions")
end

function register_residuals_commands!()
    specs = with_config_ergonomics(with_model_option(residuals_specs()))
    register!(specs)
    return build_node("residuals", specs; description="Model residuals")
end
