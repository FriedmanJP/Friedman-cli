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
    "scenario" => "multivariate", "qvar" => "multivariate", "qfavar" => "multivariate",
    "lms-svar" => "multivariate", "lanne-luoto" => "multivariate", "ssvarma" => "multivariate",
    "arch" => "volatility", "garch" => "volatility", "egarch" => "volatility",
    "gjr-garch" => "volatility", "igarch" => "volatility", "cgarch" => "volatility",
    "aparch" => "volatility", "figarch" => "volatility", "fiegarch" => "volatility",
    "garch-midas" => "volatility", "sv" => "volatility", "bekk" => "volatility",
    "ccc" => "volatility", "dcc" => "volatility",
    "static" => "factor", "dynamic" => "factor", "gdfm" => "factor",
    "sdfm" => "factor", "fastica" => "factor", "qfm" => "factor", "growth-at-risk" => "factor",
    "fhlz" => "factor", "gdfm-i1" => "factor", "tv-gdfm" => "factor",
    "arima" => "univariate", "sarima" => "univariate", "arfima" => "univariate",
    "ardl" => "univariate", "nardl" => "univariate", "midas" => "univariate",
    "setar" => "regime", "star" => "regime", "ms" => "regime",
    "ms-ar" => "regime", "threshold" => "regime", "tvp" => "regime",
    "preg" => "panel", "piv" => "panel", "plogit" => "panel", "pprobit" => "panel",
    "pmg" => "panel", "pvar" => "panel", "xtcointreg" => "panel", "xtqreg" => "panel",
    "logit" => "choice", "probit" => "choice", "ologit" => "choice",
    "oprobit" => "choice", "mlogit" => "choice", "poisson" => "choice",
    "nbreg" => "choice", "ri-logit" => "choice",
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
    "qfm-spanning" => "factor", "qfm-constancy" => "factor",
    "onatski-q" => "factor", "ahn-horenstein" => "factor", "onatski-ed" => "factor",
    "svar-hypothesis" => "multivariate", "nongaussian-diag" => "multivariate",
    "gmm-moments" => "multivariate", "fundamentalness" => "multivariate",
    "sufficient-info" => "multivariate",
    "brant" => "other", "dispersion" => "other", "edf" => "other", "fisher" => "other",
    "gph" => "other", "hansen-linearity" => "other", "hausman-iia" => "other",
    "identifiability" => "other", "influence" => "other", "local-whittle" => "other",
    "nardl-symmetry" => "other", "normality" => "other", "park-added" => "other",
    "star-linearity" => "other", "variance-ratio" => "other", "vif" => "other",
)

# Old argv path → v1.0.0 path. Filled by `_finalize_spec` plus the multipliers fold.
const _PATH_REPLACEMENTS = Dict{Vector{String},Vector{String}}()

# Human-readable summaries for all depth-2 NodeCommands created in `build_node`.
const _NODE_DESCRIPTIONS = Dict{Tuple{String,String},String}(
    ("data", "simulate") => "Simulate synthetic datasets from econometric, panel, cross-section, and DSGE/OLG models",
    ("dsge", "abcd") => "Canonical ABCD state-space extraction, FVRSW invertibility, innovations, recoverability, and DSGE-vs-SVAR IRF audits",
    ("dsge", "bank") => "Intermediary banking DSGE models: steady state, partial equilibrium, transition, and IRFs",
    ("dsge", "bayes") => "Bayesian DSGE estimation, posterior IRFs/FEVD/HD, marginal likelihood, and simulation",
    ("dsge", "ct") => "Continuous-time heterogeneous-agent models (Aiyagari, Poisson income, two-asset HANK)",
    ("dsge", "dcegm") => "Discrete-continuous endogenous grid method (DC-EGM) household and equilibrium models",
    ("dsge", "firm") => "Heterogeneous-firm dynamics (Khan-Thomas) steady state and transition paths",
    ("dsge", "lifecycle") => "Overlapping-generations life-cycle household steady state and transition dynamics",
    ("dsge", "olg") => "Blanchard perpetual-youth OLG solve, steady state, IRFs, and simulation",
    ("dsge", "var") => "Del Negro-Schorfheide Bayesian DSGE-VAR(lambda) prior, marginal likelihood profiling, estimation, and innovation accounting",
    ("estimate", "choice") => "Discrete and limited dependent variable estimators (logit, probit, multinomial, ordered)",
    ("estimate", "factor") => "Static, dynamic, generalized dynamic, and Factor-Augmented VAR (FAVAR) factor models",
    ("estimate", "multivariate") => "Multivariate time-series estimators (VAR, BVAR, VECM, LP, FAVAR, MF-VAR, GVAR, SMM, GMM)",
    ("estimate", "panel") => "Panel data estimators (FE/RE/FD, IV, logit/probit, Tobit, dynamic, PVAR, interactive FE, SUR/3SLS)",
    ("estimate", "regime") => "Regime-switching and nonlinear time-series estimators (Markov-switching, STAR, TAR)",
    ("estimate", "regression") => "Cross-section and time-series regressions (OLS, IV, quantile, Tobit, Heckman, count, nonparametric, survival)",
    ("estimate", "univariate") => "Univariate time-series estimators (ARIMA, ARFIMA, ARDL, NARDL, MIDAS, GP)",
    ("estimate", "volatility") => "Conditional volatility estimators (ARCH, GARCH, EGARCH, GJR, APARCH, FIGARCH, MGARCH, SV)",
    ("forecast", "evaluate") => "Forecast accuracy, encompassing, calibration, and combination diagnostics",
    ("forecast", "factor") => "Factor and FAVAR multi-step forecasts",
    ("forecast", "multivariate") => "Multivariate point and density forecasts (VAR, BVAR, VECM, LP)",
    ("forecast", "regime") => "Regime-weighted multi-step forecasts for Markov-switching, STAR, and TAR models",
    ("forecast", "univariate") => "Univariate multi-step forecasts (ARIMA, ARFIMA, ARDL, NARDL, MIDAS, GP)",
    ("forecast", "volatility") => "Conditional variance and volatility forecasts across GARCH and SV families",
    ("io", "bf") => "Baqaee-Farhi nonlinear production-network equilibrium, elasticities, wedges, and misallocation",
    ("policy", "counterfactual") => "Counterfactual rule swaps on historical paths, theoretical moments, and shock propagation",
    ("policy", "effects") => "Causal policy effects and optimal policy counterfactuals from empirical propagation matrices",
    ("policy", "history") => "Historical shock decomposition and shock-removal counterfactual paths",
    ("policy", "jacobian") => "Sequence-space policy Jacobians and dynamic causal propagation matrices",
    ("policy", "moments") => "Unconditional variance, shock-share, and welfare moment decompositions under policy rules",
    ("policy", "news") => "Anticipated policy news IRFs, variance shares, and expectations revisions",
    ("policy", "opp") => "Linear-quadratic optimal policy projections (OPP) in sequence space",
    ("policy", "opp-sequence") => "Constrained multi-instrument sequence-space optimal policy paths and loss frontiers",
    ("policy", "optimal") => "Ramsey, timeless-perspective, and simple-rule optimal monetary/fiscal policy solvers",
    ("policy", "spanning") => "Instrument spanning diagnostics across target impulse paths",
    ("policy", "sufficiency") => "Sufficient-statistic checks for empirical vs structural policy counterfactuals",
    ("predict", "choice") => "In-sample fitted probabilities and linear predictors for discrete-choice models",
    ("predict", "factor") => "Common-component in-sample fitted values for factor models",
    ("predict", "multivariate") => "In-sample fitted values for multivariate VAR and VECM systems",
    ("predict", "panel") => "In-sample fitted values for linear, nonlinear, and system panel estimators",
    ("predict", "regime") => "Regime-weighted in-sample fitted values for nonlinear regime models",
    ("predict", "regression") => "In-sample fitted values and conditional expectations for regression models",
    ("predict", "univariate") => "In-sample one-step fitted values for univariate time-series models",
    ("predict", "volatility") => "In-sample conditional variance series from estimated volatility models",
    ("residuals", "choice") => "Deviance, Pearson, and response residuals for discrete-choice models",
    ("residuals", "factor") => "Idiosyncratic residual components from estimated factor models",
    ("residuals", "multivariate") => "Reduced-form and structural innovations for multivariate models",
    ("residuals", "panel") => "Idiosyncratic and equation residuals for panel and system models",
    ("residuals", "regime") => "Regime-weighted residuals for Markov-switching, STAR, and TAR models",
    ("residuals", "regression") => "Regression, deviance, and martingale residuals for cross-section and count models",
    ("residuals", "univariate") => "Innovation residuals from univariate time-series models",
    ("residuals", "volatility") => "Standardized innovations from estimated conditional volatility models",
    ("test", "coint") => "Cointegration and long-run equilibrium tests (Johansen, Engle-Granger, Gregory-Hansen, Phillips-Ouliaris)",
    ("test", "did") => "Difference-in-differences pre-trend, Bacon decomposition, HonestDiD, and diagnostics",
    ("test", "factor") => "Static, dynamic, and quantile factor rank selection, spanning, and constancy tests",
    ("test", "iv") => "Instrumental-variables weak-ID, overidentification, endogeneity, and Anderson-Rubin tests",
    ("test", "multivariate") => "VAR/VECM lag selection, Granger causality, residual diagnostics, and SVAR identification tests",
    ("test", "panel") => "Panel specification, Hausman, cross-sectional dependence, serial correlation, and unit-root tests",
    ("test", "pvar") => "Panel VAR lag selection, Granger causality, stability, and Hansen J tests",
    ("test", "serial") => "Autocorrelation, white-noise, ARCH-LM, independence, and long-memory tests",
    ("test", "stability") => "Structural break, parameter constancy, linearity, and functional-form tests",
    ("test", "unit-root") => "Unit-root and stationarity tests (ADF, KPSS, PP, ZA, Ng-Perron, DF-GLS, ERS, structural breaks)",
    ("test", "vecm") => "VECM Granger causality and cointegrating-rank specification tests",
)

function _node_description(top::String, mid::String)::String
    return get(_NODE_DESCRIPTIONS, (top, mid), mid)
end

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

const _OOS_PREDICT_TOKENS = Set(["reg", "logit", "probit", "ologit", "oprobit", "mlogit"])

function _prepared_predict_specs()
    specs = _overlay_estimator_data_kinds(
        with_result_handles(with_config_ergonomics(with_model_option(
            _wrap_fitted_specs(predict_specs())))))
    return [s.path[end] in _OOS_PREDICT_TOKENS ? _copy_spec(s; allow_data_with_model=true) : s
            for s in specs]
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
    specs = with_save_model(with_config_ergonomics(with_result_handles(with_model_option(producing))))
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

# ── Coexisting command, family & long-leaf abbreviation tables (#337) ───
# Single-source alias dicts consumed by `build_app()` (`_TOP_ALIASES`) and
# `build_node()` (`_FAMILY_ALIASES`, `_LEAF_ALIASES`) through the hard
# build-time collision guard `_register_node_alias!`:
#   1. zero sibling primary collisions,
#   2. zero sibling alias collisions,
#   3. zero REPL built-in collisions (`repl`/`exit`/`quit`; `data use|current|clear`),
#   4. zero `_PATH_REPLACEMENTS` overlaps (notably `<verb> regression` uses
#      `"regr"`, keeping removed `<verb> reg` as a migration hint).

const _TOP_ALIASES = Dict{String,Vector{String}}(
    "estimate"    => ["est", "e"],
    "forecast"    => ["fc", "fcst"],
    "predict"     => ["pred", "pr"],
    "residuals"   => ["resid", "res"],
    "test"        => ["t"],
    "data"        => ["d"],
    "model"       => ["mod", "m"],
    "filter"      => ["flt"],
    "spectral"    => ["spec", "sp"],
    "policy"      => ["pol"],
    "nowcast"     => ["nc"],
    "hadsge"      => ["ha"],
    "completions" => ["comp"],
    "schema"      => ["sch"],
    "serve"       => ["srv"],
    "show"        => ["sh"],
)

const _MODEL_FAMILY_SHORTS = (
    "multivariate" => ["mv"],
    "univariate"   => ["uv"],
    "regression"   => ["regr"],  # avoids `_PATH_REPLACEMENTS` collision with removed `<verb> reg`
    "volatility"   => ["vol"],
    "factor"       => ["fac"],
    "panel"        => ["pan"],
    "choice"       => ["ch"],
    "regime"       => ["rgm"],
)

const _FAMILY_ALIASES = let d = Dict{Tuple{String,String},Vector{String}}(
    # Forecast-specific families (no regression/panel/choice; adds evaluate)
    ("forecast", "multivariate") => ["mv"],
    ("forecast", "univariate")   => ["uv"],
    ("forecast", "volatility")   => ["vol"],
    ("forecast", "factor")       => ["fac"],
    ("forecast", "regime")       => ["rgm"],
    ("forecast", "evaluate")     => ["eval"],
    # Test families (did/iv/pvar/vecm already short)
    ("test", "unit-root")    => ["ur"],
    ("test", "coint")        => ["ci"],
    ("test", "stability")    => ["stab"],
    ("test", "serial")       => ["ser"],
    ("test", "multivariate") => ["mv"],
    ("test", "factor")       => ["fac"],
    ("test", "panel")        => ["pan"],
    # Data subcommands (disjoint from REPL `use`, `current`, `clear`)
    ("data", "describe")  => ["desc"],
    ("data", "diagnose")  => ["diag"],
    ("data", "simulate")  => ["sim"],
    ("data", "transform") => ["tr"],
    ("data", "validate")  => ["val"],
    ("data", "balance")   => ["bal"],
    ("data", "export")    => ["exp"],
    ("data", "import")    => ["imp"],
    ("data", "list")      => ["ls"],
    # DSGE depth-2 subgroups & direct leaves
    ("dsge", "bayes")             => ["b"],
    ("dsge", "steady-state")      => ["ss"],
    ("dsge", "perfect-foresight") => ["pf"],
    ("dsge", "determinacy-map")   => ["detmap"],
    ("dsge", "lifecycle")         => ["lc"],
    ("dsge", "simulate")          => ["sim"],
    ("dsge", "estimate")          => ["est"],
    # HADSGE depth-2 leaves
    ("hadsge", "steady-state")     => ["ss"],
    ("hadsge", "distribution-irf") => ["dist-irf"],
    ("hadsge", "inequality-irf")   => ["ineq-irf"],
    ("hadsge", "simulate-panel")   => ["sim-panel"],
    ("hadsge", "accuracy")         => ["acc"],
    ("hadsge", "simulate")         => ["sim"],
    ("hadsge", "estimate")         => ["est"],
    # Policy depth-2 subgroups
    ("policy", "counterfactual") => ["cf"],
    ("policy", "effects")        => ["eff"],
    ("policy", "history")        => ["hist"],
    ("policy", "jacobian")       => ["jac"],
    ("policy", "moments")        => ["mom"],
    ("policy", "optimal")        => ["opt"],
    ("policy", "opp-sequence")   => ["opp-seq"],
    ("policy", "spanning")       => ["span"],
    ("policy", "sufficiency")    => ["suff"],
    # DiD, Model, Spectral, Filter, RI, IO depth-2 subcommands
    ("did", "event-study") => ["es"],
    ("did", "lp-did")      => ["lp"],
    ("did", "estimate")    => ["est"],
    ("model", "convert")   => ["conv"],
    ("model", "reproduce") => ["repro"],
    ("spectral", "periodogram") => ["pgram"],
    ("spectral", "density")     => ["dens"],
    ("spectral", "transfer")    => ["tf"],
    ("filter", "bandpass-gdfm") => ["bp-gdfm"],
    ("ri", "transition") => ["trans"],
    ("ri", "statespace") => ["ss"],
    ("ri", "discrete")   => ["disc"],
    ("ri", "estimate")   => ["est"],
    ("ri", "simulate")   => ["sim"],
    ("io", "baqaee-farhi")            => ["bf-full"],  # preserves sibling `io bf`
    ("io", "bilateral-trade")         => ["bilat"],
    ("io", "export-decomposition")    => ["exp-decomp"],
    ("io", "key-sectors")             => ["keys"],
    ("io", "linkages")                => ["link"],
    ("io", "multipliers")             => ["mult"],
    ("io", "network-stats")           => ["net"],
    ("io", "vertical-specialization") => ["vs"],
    ("io", "footprint")               => ["fp"],
    ("io", "download")                => ["dl"],
    ("io", "aggregate")               => ["agg"],
    ("io", "extract")                 => ["ext"],
)
    for verb in ("estimate", "predict", "residuals")
        for (fam, als) in _MODEL_FAMILY_SHORTS
            d[(verb, fam)] = copy(als)
        end
    end
    d
end

const _LEAF_ALIASES = Dict{Tuple{String,String,String},Vector{String}}(
    # Test cointegration
    ("test", "coint", "engle-granger")     => ["eg"],
    ("test", "coint", "phillips-ouliaris") => ["po"],
    ("test", "coint", "gregory-hansen")    => ["gh"],
    ("test", "coint", "fisher-johansen")   => ["fj"],
    ("test", "coint", "ardl-bounds")       => ["bounds"],
    ("test", "coint", "westerlund")        => ["west"],
    # Test stability
    ("test", "stability", "bai-perron")          => ["bp"],
    ("test", "stability", "factor-break")        => ["fbreak"],
    ("test", "stability", "hansen-instability")  => ["hansen"],
    ("test", "stability", "recursive-residuals") => ["rec-resid"],
    # Test serial / heteroskedasticity
    ("test", "serial", "durbin-watson")      => ["dw"],
    ("test", "serial", "breusch-pagan")      => ["bp"],
    ("test", "serial", "ljung-box")          => ["lb"],
    ("test", "serial", "box-pierce")         => ["boxp"],
    ("test", "serial", "bartlett-wn")        => ["bwn"],
    ("test", "serial", "heteroskedasticity") => ["het"],
    # Test IV
    ("test", "iv", "anderson-rubin")  => ["ar"],
    ("test", "iv", "weak-instrument") => ["weak-iv"],
    ("test", "iv", "wild-cluster")    => ["wc"],
    # Test panel
    ("test", "panel", "wooldridge-ar") => ["war"],
    ("test", "panel", "pesaran-cd")    => ["pcd"],
    ("test", "panel", "modified-wald") => ["mwald"],
    ("test", "panel", "pmg-hausman")   => ["pmgh"],
    ("test", "panel", "dh-causality")  => ["dh"],
    # Test unit-root
    ("test", "unit-root", "adf-2break")   => ["adf2"],
    ("test", "unit-root", "fourier-adf")  => ["fadf"],
    ("test", "unit-root", "fourier-kpss") => ["fkpss"],
    ("test", "unit-root", "moon-perron")  => ["mp"],
    ("test", "unit-root", "lm-unitroot")  => ["lm"],
    # Test VECM
    ("test", "vecm", "known-beta") => ["kbeta"],
    # Test factor
    ("test", "factor", "ahn-horenstein") => ["ah"],
    ("test", "factor", "onatski-ed")     => ["oed"],
    ("test", "factor", "qfm-spanning")   => ["qspan"],
    ("test", "factor", "qfm-constancy")  => ["qconst"],
    # Test multivariate
    ("test", "multivariate", "svar-hypothesis")  => ["svar-hyp"],
    ("test", "multivariate", "nongaussian-diag") => ["ng-diag"],
    ("test", "multivariate", "gmm-moments")      => ["gmm-mom"],
    ("test", "multivariate", "fundamentalness")  => ["fund"],
    ("test", "multivariate", "sufficient-info")  => ["suff-info"],
    # Estimators, forecasts, predict & residuals long leaves
    ("forecast", "factor", "growth-at-risk")     => ["gar"],
    ("estimate", "regression", "elastic-net")    => ["enet"],
    ("estimate", "regression", "kernel-reg")     => ["kreg"],
    ("estimate", "regression", "statespace")     => ["ss"],
    ("predict", "regression", "statespace")      => ["ss"],
    ("residuals", "regression", "statespace")    => ["ss"],
    ("estimate", "volatility", "garch-midas")    => ["gm"],
    ("forecast", "volatility", "garch-midas")    => ["gm"],
    ("predict", "volatility", "garch-midas")     => ["gm"],
    ("residuals", "volatility", "garch-midas")   => ["gm"],
    ("estimate", "multivariate", "lanne-luoto")  => ["ll"],
    ("residuals", "multivariate", "lanne-luoto") => ["ll"],
    ("estimate", "panel", "xtcointreg")          => ["xtcr"],
    ("forecast", "evaluate", "mincer-zarnowitz") => ["mz"],
    ("forecast", "evaluate", "clark-west")       => ["cw"],
    ("forecast", "evaluate", "encompassing")     => ["enc"],
    # Data simulate long leaves
    ("data", "simulate", "cross-section")       => ["cs"],
    ("data", "simulate", "gdfm-infinite")       => ["gdfm-inf"],
    ("data", "simulate", "heteroskedastic-var") => ["het-var"],
    # DSGE depth-3 long leaves
    ("dsge", "bank", "steady-state")       => ["ss"],
    ("dsge", "dcegm", "steady-state")      => ["ss"],
    ("dsge", "firm", "steady-state")       => ["ss"],
    ("dsge", "lifecycle", "steady-state")  => ["ss"],
    ("dsge", "bank", "transition")         => ["tr"],
    ("dsge", "ct", "transition")           => ["tr"],
    ("dsge", "dcegm", "transition")        => ["tr"],
    ("dsge", "firm", "transition")         => ["tr"],
    ("dsge", "lifecycle", "transition")    => ["tr"],
    ("dsge", "bayes", "posterior-mode")    => ["mode"],
    ("dsge", "bayes", "marginal-lik")      => ["mlik"],
    ("dsge", "bayes", "identification")    => ["id"],
    ("dsge", "bayes", "learning-rate")     => ["lr"],
    ("dsge", "bayes", "predictive")        => ["pred"],
    ("dsge", "bayes", "prior-predictive")  => ["prior-pred"],
    ("dsge", "abcd", "innovations")        => ["innov"],
    ("dsge", "abcd", "invertibility")      => ["inv"],
    ("dsge", "abcd", "recoverability")     => ["rec"],
    ("dsge", "abcd", "population-var")     => ["pop-var"],
    ("dsge", "abcd", "search-observables") => ["search"],
    # IO Baqaee-Farhi depth-3 long leaves
    ("io", "bf", "equilibrium")   => ["eq"],
    ("io", "bf", "elasticities")  => ["elast"],
    ("io", "bf", "misallocation") => ["misalloc"],
    ("io", "bf", "shock-curve")   => ["scurve"],
)
