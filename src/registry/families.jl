# Family labels (#199) and the v1.0.0 path promotion (#202–#204).
#
# A depth-2 leaf under estimate/predict/residuals/forecast/test gains `family`
# as its middle segment, except family `other` (those test leaves stay flat).
# `did test <name>` moves to `test did <name>`. `dsge ha <op>` moves to
# `hadsge <op>`. The old spelling does not dispatch; the usage error names
# the new path via `_PATH_REPLACEMENTS`. The `var`→`multivariate` rename
# registers the same way: each finalized `<verb> multivariate <leaf>` path
# remembers its `<verb> var <leaf>` spelling, so the removed paths keep
# naming the new one (the exact entry beats the depth-2 prefix hint).

const _PROMOTE_VERBS = ("estimate", "predict", "residuals", "forecast", "test")
const _EXEMPT_TOPS = ("serve", "show", "completions", "model")

# Shared by estimate / predict / residuals / forecast. A token missing from a
# verb simply has no leaf there (star and setar have no predict leaf).
const _MODEL_FAMILY = Dict{String,String}(
    "var" => "multivariate", "bvar" => "multivariate", "vecm" => "multivariate",
    "svar" => "multivariate", "svec" => "multivariate", "tvpvar" => "multivariate",
    "mfvar" => "multivariate", "favar" => "multivariate", "lp" => "multivariate",
    "scenario" => "multivariate",
    "arch" => "volatility", "garch" => "volatility", "egarch" => "volatility",
    "gjr-garch" => "volatility", "igarch" => "volatility", "cgarch" => "volatility",
    "aparch" => "volatility", "figarch" => "volatility", "fiegarch" => "volatility",
    "garch-midas" => "volatility", "sv" => "volatility", "bekk" => "volatility",
    "ccc" => "volatility", "dcc" => "volatility",
    "static" => "factor", "dynamic" => "factor", "gdfm" => "factor",
    "sdfm" => "factor", "fastica" => "factor",
    "arima" => "univariate", "sarima" => "univariate", "arfima" => "univariate",
    "ardl" => "univariate", "nardl" => "univariate", "midas" => "univariate",
    "setar" => "regime", "star" => "regime", "ms" => "regime",
    "ms-ar" => "regime", "threshold" => "regime", "tvp" => "regime",
    "preg" => "panel", "piv" => "panel", "plogit" => "panel", "pprobit" => "panel",
    "pmg" => "panel", "pvar" => "panel", "xtcointreg" => "panel",
    "logit" => "choice", "probit" => "choice", "ologit" => "choice",
    "oprobit" => "choice", "mlogit" => "choice", "poisson" => "choice",
    "nbreg" => "choice",
    "reg" => "regression", "iv" => "regression", "sur" => "regression",
    "3sls" => "regression", "elastic-net" => "regression", "heckman" => "regression",
    "lasso" => "regression", "ridge" => "regression", "robust" => "regression",
    "qreg" => "regression", "rdd" => "regression", "ml" => "regression",
    "kde" => "regression", "kernel-reg" => "regression", "lowess" => "regression",
    "tobit" => "regression", "truncreg" => "regression", "select" => "regression",
    "gmm" => "regression", "smm" => "regression", "cointreg" => "regression",
    "statespace" => "regression",
)

# Depth-2 `test` leaves. Already-nested `test multivariate|vecm|pvar *` take the middle
# segment as their family and are not listed here. `other` is a help heading
# only — those paths stay `test <leaf>`.
const _TEST_FAMILY = Dict{String,String}(
    "adf" => "unit-root", "adf-2break" => "unit-root", "breitung" => "unit-root",
    "cips" => "unit-root", "dfgls" => "unit-root", "ers" => "unit-root",
    "fourier-adf" => "unit-root", "fourier-kpss" => "unit-root", "hadri" => "unit-root",
    "hegy" => "unit-root", "ips" => "unit-root", "kpss" => "unit-root",
    "llc" => "unit-root", "lm-unitroot" => "unit-root", "moon-perron" => "unit-root",
    "np" => "unit-root", "pp" => "unit-root", "za" => "unit-root",
    "engle-granger" => "coint", "gregory-hansen" => "coint", "johansen" => "coint",
    "kao" => "coint", "pedroni" => "coint", "phillips-ouliaris" => "coint",
    "westerlund" => "coint", "fisher-johansen" => "coint", "ardl-bounds" => "coint",
    "andrews" => "stability", "bai-perron" => "stability", "chow" => "stability",
    "cusum" => "stability", "cusumsq" => "stability", "factor-break" => "stability",
    "gsadf" => "stability", "hansen-instability" => "stability", "nyblom" => "stability",
    "recursive-residuals" => "stability", "sadf" => "stability",
    "arch-lm" => "serial", "bartlett-wn" => "serial", "bds" => "serial",
    "box-pierce" => "serial", "durbin-watson" => "serial", "ljung-box" => "serial",
    "sign-bias" => "serial", "white" => "serial", "breusch-pagan" => "serial",
    "glejser" => "serial", "harvey" => "serial", "heteroskedasticity" => "serial",
    "anderson-rubin" => "iv", "weak-instrument" => "iv", "wild-cluster" => "iv",
    "f-fe" => "panel", "hausman" => "panel", "modified-wald" => "panel",
    "pesaran-cd" => "panel", "wooldridge-ar" => "panel", "pmg-hausman" => "panel",
    "dh-causality" => "panel", "panic" => "panel",
    "granger" => "multivariate", "lr" => "multivariate", "lm" => "multivariate",
    "brant" => "other", "dispersion" => "other", "edf" => "other", "fisher" => "other",
    "gph" => "other", "hansen-linearity" => "other", "hausman-iia" => "other",
    "identifiability" => "other", "influence" => "other", "local-whittle" => "other",
    "nardl-symmetry" => "other", "normality" => "other", "park-added" => "other",
    "star-linearity" => "other", "variance-ratio" => "other", "vif" => "other",
)

# Old argv path → v1.0.0 path. Filled by `_finalize_spec` plus the multipliers fold.
const _PATH_REPLACEMENTS = Dict{Vector{String},Vector{String}}()

"""Family label for a pre-promotion path. Empty for the four exempt tops."""
function _family_for(path::Vector{String})
    isempty(path) && return ""
    path[1] in _EXEMPT_TOPS && return ""
    if path[1] in ("estimate", "predict", "residuals", "forecast") && length(path) == 2
        haskey(_MODEL_FAMILY, path[2]) ||
            error("no model family for $(join(path, " "))")
        return _MODEL_FAMILY[path[2]]
    end
    if path[1] == "forecast" && length(path) >= 2 && path[2] == "evaluate"
        return "evaluate"
    end
    if path[1] == "test"
        if length(path) >= 3
            return path[2]
        end
        haskey(_TEST_FAMILY, path[2]) ||
            error("no test family for $(join(path, " "))")
        return _TEST_FAMILY[path[2]]
    end
    if path[1] == "dsge"
        if length(path) == 2 || (length(path) >= 2 && path[2] == "bayes")
            return "ra"
        elseif length(path) >= 2 && path[2] == "ha"
            return "hadsge"
        elseif length(path) >= 2
            return path[2]
        end
    end
    if path[1] == "did"
        return "did"
    end
    if path[1] == "hadsge"
        return "hadsge"
    end
    if length(path) >= 3
        return path[2]
    end
    length(path) >= 1 ? path[1] : ""
end

"""Rewrite a pre-promotion path. Returns `(newpath, changed)`."""
function _promote_path(path::Vector{String}, fam::String)
    if length(path) >= 3 && path[1] == "did" && path[2] == "test"
        return ["test", "did", path[3]], true
    end
    if length(path) >= 3 && path[1] == "dsge" && path[2] == "ha"
        return ["hadsge", path[3]], true
    end
    if length(path) == 2 && path[1] in _PROMOTE_VERBS && !isempty(fam) && fam != "other"
        return [path[1], fam, path[2]], true
    end
    return path, false
end

function _remember_replacement(old::Vector{String}, new::Vector{String})
    _PATH_REPLACEMENTS[old] = new
    # #204: the removed top-level points at the NARDL leaf that absorbed it.
    if old == ["estimate", "nardl"]
        _PATH_REPLACEMENTS[["multipliers"]] = new
        _PATH_REPLACEMENTS[["multipliers", "nardl"]] = new
    end
    return new
end

"""Stamp `family` and apply the v1.0.0 path move. Idempotent on an already-final spec."""
function _finalize_spec(s::CommandSpec)
    fam = isempty(s.family) ? _family_for(s.path) : s.family
    newpath, changed = _promote_path(s.path, fam)
    changed && _remember_replacement(s.path, newpath)
    if length(newpath) == 3 && newpath[2] == "multivariate" &&
       newpath[1] in ("estimate", "predict", "residuals", "forecast", "test")
        _remember_replacement([newpath[1], "var", newpath[3]], newpath)
    end
    (newpath == s.path && fam == s.family) && return s
    return _copy_spec(s; path=newpath, family=fam)
end

"""Longest removed-path prefix of `tokens`, or `nothing`."""
function _replacement_for(tokens::Vector{String})
    best = nothing
    bestlen = 0
    for (old, new) in _PATH_REPLACEMENTS
        if length(old) <= length(tokens) && length(old) > bestlen &&
           tokens[1:length(old)] == old
            best = new
            bestlen = length(old)
        end
    end
    return best
end

# ── Model catalog (#200) ────────────────────────────────────────────────
# One row per model token. Each verb stores the prepared (pre-promotion)
# CommandSpec: options, flags, tables, data kinds, model types, handler.
# `forecast evaluate` is not a row.

struct ModelRow
    token::String
    family::String
    verbs::Dict{String,CommandSpec}
end

const _MODEL_CATALOG = Ref{Union{Nothing,Vector{ModelRow}}}(nothing)

function _prepared_estimate_specs()
    specs = with_config_ergonomics(with_save_model(estimate_specs()))
    out = CommandSpec[]
    for s in specs
        push!(out, _copy_spec(s; data_kinds=_data_kinds_for_estimator(s.path[end])))
    end
    return with_default_csv_kinds(out)
end

function _prepared_predict_specs()
    return _overlay_estimator_data_kinds(
        with_result_handles(with_config_ergonomics(with_model_option(
            _wrap_fitted_specs(predict_specs())))))
end

function _prepared_residuals_specs()
    return _overlay_estimator_data_kinds(
        with_result_handles(with_config_ergonomics(with_model_option(
            _wrap_fitted_specs(residuals_specs())))))
end

"""Forecast model leaves (not `forecast evaluate`), with the same option and kind stamps as before the catalog."""
function _prepared_forecast_model_specs()
    all_specs = forecast_specs()
    is_eval(s) = length(s.path) >= 2 && s.path[2] == "evaluate"
    producing = _tag_slot_types(filter(!is_eval, all_specs), _FORECAST_SLOT_TYPES)
    specs = with_config_ergonomics(with_result_handles(with_model_option(producing)))
    out = CommandSpec[]
    for s in specs
        push!(out, _copy_spec(s; data_kinds=[:timeseries, :csv]))
    end
    return with_default_csv_kinds(out)
end

function _prepared_forecast_eval_specs()
    evals = filter(s -> length(s.path) >= 2 && s.path[2] == "evaluate", forecast_specs())
    specs = with_config_ergonomics(evals)
    out = CommandSpec[]
    for s in specs
        push!(out, _copy_spec(s; data_kinds=[:csv, :timeseries, :panel, :cross_section]))
    end
    return with_default_csv_kinds(out)
end

function _assemble_model_catalog()
    groups = Dict{String,Dict{String,CommandSpec}}()
    families = Dict{String,String}()
    bundles = (
        "estimate" => _prepared_estimate_specs(),
        "predict" => _prepared_predict_specs(),
        "residuals" => _prepared_residuals_specs(),
        "forecast" => _prepared_forecast_model_specs(),
    )
    for (verb, specs) in bundles
        for s in specs
            length(s.path) == 2 || error("catalog spec is not depth-2: $(s.path)")
            s.path[1] == verb || error("catalog verb $(s.path[1]) != $verb")
            token = s.path[2]
            haskey(_MODEL_FAMILY, token) || error("no model family for $verb $token")
            fam = _MODEL_FAMILY[token]
            if haskey(families, token) && families[token] != fam
                error("family mismatch for $token")
            end
            families[token] = fam
            g = get!(groups, token, Dict{String,CommandSpec}())
            haskey(g, verb) && error("duplicate catalog row $verb $token")
            g[verb] = _copy_spec(s; family=fam)
        end
    end
    rows = ModelRow[]
    for token in sort!(collect(keys(groups)))
        push!(rows, ModelRow(token, families[token], groups[token]))
    end
    return rows
end

function model_catalog()::Vector{ModelRow}
    if _MODEL_CATALOG[] === nothing
        _MODEL_CATALOG[] = _assemble_model_catalog()
    end
    return _MODEL_CATALOG[]::Vector{ModelRow}
end

"""Prepared, not-yet-promoted specs for one verb, taken from the catalog rows."""
function catalog_specs(verb::String)
    out = CommandSpec[]
    for row in model_catalog()
        haskey(row.verbs, verb) || continue
        push!(out, row.verbs[verb])
    end
    return out
end
