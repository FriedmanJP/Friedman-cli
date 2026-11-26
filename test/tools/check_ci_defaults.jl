#!/usr/bin/env julia
# Automated CI drift gate for the [CI] 68% macro / 90% micro confidence interval policy (#334).
#
# Enforces across the entire Friedman.APP command tree:
#   1. 100% classification coverage of every leaf carrying `--conf-level` or `--quantiles`
#      (no new leaf can silently inherit a 0.95 default).
#   2. Every microeconometric leaf (39 leaves) declares `--conf-level` with default 0.90
#      and canonical aliases ["ci-level", "confidence", "level"].
#   3. Every macroeconometric leaf (111 leaves, incl. `did lp-did`, `estimate regime setar`,
#      `test stability bai-perron`) declares `--conf-level` with default 0.68 and canonical
#      aliases, and every posterior/quantile-band leaf declares `--quantiles` default
#      "0.16,0.5,0.84".
#   4. Landmine L8 invariants: 5% hypothesis tests (`test coint ardl-bounds`, `test stability
#      chow|cusum|cusumsq`) keep `--level 0.05` (no `--conf-level`), SARIMA leaves never gain
#      `--quantiles`, and `forecast factor growth-at-risk` keeps `--alpha 0.05`.
#   5. Zero hardcoded 95% z-critical values (`1.95996` / `1.96`) remain in `src/commands/*.jl`.
#
# Usage (from repo root):
#   julia --project test/tools/check_ci_defaults.jl

using Friedman

const ROOT = dirname(dirname(@__DIR__))

const EXPECTED_MICRO_LEAVES = Set{String}([
    # Non-LP DiD (4)
    "did estimate",
    "did event-study",
    "test did honest",
    "test did pretrend",
    # Cross-sectional regressions & nonparametric/GMM/SMM (14)
    "estimate regression 3sls",
    "estimate regression gmm",
    "estimate regression heckman",
    "estimate regression iv",
    "estimate regression kernel-reg",
    "estimate regression lowess",
    "estimate regression qreg",
    "estimate regression rdd",
    "estimate regression reg",
    "estimate regression robust",
    "estimate regression smm",
    "estimate regression sur",
    "estimate regression tobit",
    "estimate regression truncreg",
    # Discrete choice & count estimators (8)
    "estimate choice logit",
    "estimate choice mlogit",
    "estimate choice nbreg",
    "estimate choice ologit",
    "estimate choice oprobit",
    "estimate choice poisson",
    "estimate choice probit",
    "estimate choice ri-logit",
    # Micro panel (5)
    "estimate panel piv",
    "estimate panel plogit",
    "estimate panel pprobit",
    "estimate panel preg",
    "estimate panel xtqreg",
    # Cross-sectional threshold regression (1)
    "estimate regime threshold",
    # Discrete choice marginal effects / odds ratio predict leaves (5)
    "predict choice logit",
    "predict choice mlogit",
    "predict choice ologit",
    "predict choice oprobit",
    "predict choice probit",
    # Cross-sectional IV confidence sets (2)
    "test iv anderson-rubin",
    "test iv wild-cluster",
])

const EXPECTED_MACRO_LEAVES = Set{String}([
    # Macro LP-DiD (1)
    "did lp-did",
    # DSGE Bayesian & HA-DSGE (8)
    "dsge bayes estimate",
    "dsge bayes fevd",
    "dsge bayes hd",
    "dsge bayes irf",
    "dsge bayes prior-predictive",
    "dsge bayes simulate",
    "dsge bayes summary",
    "hadsge estimate",
    # DSGE-VAR (5)
    "dsge var estimate",
    "dsge var fevd",
    "dsge var forecast",
    "dsge var hd",
    "dsge var irf",
    # Multivariate macro estimators (14)
    "estimate multivariate bvar",
    "estimate multivariate favar",
    "estimate multivariate lanne-luoto",
    "estimate multivariate lms-svar",
    "estimate multivariate lp",
    "estimate multivariate mfvar",
    "estimate multivariate qfavar",
    "estimate multivariate qvar",
    "estimate multivariate ssvarma",
    "estimate multivariate svar",
    "estimate multivariate svec",
    "estimate multivariate tvpvar",
    "estimate multivariate var",
    "estimate multivariate vecm",
    # Macro panel & cointegrating regression (4)
    "estimate panel pmg",
    "estimate panel pvar",
    "estimate panel xtcointreg",
    "estimate regression cointreg",
    # Time-series regime (1)
    "estimate regime setar",
    # Univariate time-series estimators (6)
    "estimate univariate ardl",
    "estimate univariate arfima",
    "estimate univariate arima",
    "estimate univariate midas",
    "estimate univariate nardl",
    "estimate univariate sarima",
    # Volatility estimators (11)
    "estimate volatility aparch",
    "estimate volatility arch",
    "estimate volatility cgarch",
    "estimate volatility egarch",
    "estimate volatility fiegarch",
    "estimate volatility figarch",
    "estimate volatility garch",
    "estimate volatility garch-midas",
    "estimate volatility gjr-garch",
    "estimate volatility igarch",
    "estimate volatility sv",
    # FEVD & HD (3)
    "fevd bvar",
    "fevd lp",
    "hd bvar",
    # Forecasts (30)
    "forecast factor dynamic",
    "forecast factor gdfm",
    "forecast factor gdfm-i1",
    "forecast factor qfm",
    "forecast factor sdfm",
    "forecast factor static",
    "forecast multivariate bvar",
    "forecast multivariate favar",
    "forecast multivariate lp",
    "forecast multivariate scenario",
    "forecast multivariate var",
    "forecast multivariate vecm",
    "forecast regime ms",
    "forecast regime ms-ar",
    "forecast regime setar",
    "forecast regime star",
    "forecast univariate arfima",
    "forecast univariate arima",
    "forecast univariate midas",
    "forecast univariate sarima",
    "forecast volatility aparch",
    "forecast volatility arch",
    "forecast volatility cgarch",
    "forecast volatility egarch",
    "forecast volatility fiegarch",
    "forecast volatility figarch",
    "forecast volatility garch",
    "forecast volatility gjr-garch",
    "forecast volatility igarch",
    "forecast volatility sv",
    # IRFs (10)
    "irf bvar",
    "irf favar",
    "irf lp",
    "irf pvar",
    "irf qfavar",
    "irf qvar",
    "irf sdfm",
    "irf tvpvar",
    "irf var",
    "irf vecm",
    # Policy counterfactuals & optimal policy (11)
    "policy counterfactual bvar",
    "policy counterfactual lp",
    "policy counterfactual var",
    "policy history bvar",
    "policy history var",
    "policy moments bvar",
    "policy moments var",
    "policy optimal bvar",
    "policy optimal lp",
    "policy optimal var",
    "policy spanning var",
    # Rational inattention (2)
    "ri cg-test",
    "ri estimate",
    # Spectral analysis (4)
    "spectral acf",
    "spectral cross",
    "spectral density",
    "spectral periodogram",
    # Bai-Perron structural break date CIs (1)
    "test stability bai-perron",
])

const EXPECTED_FIVE_PCT_TESTS = Set{String}([
    "test coint ardl-bounds",
    "test stability chow",
    "test stability cusum",
    "test stability cusumsq",
])

const SARIMA_LEAVES = Set{String}([
    "estimate univariate sarima",
    "forecast univariate sarima",
    "predict univariate sarima",
    "residuals univariate sarima",
])

const REQUIRED_CONF_ALIASES = ("ci-level", "confidence", "level")

function _collect_leaves(node::Friedman.NodeCommand, prefix::String, out::Dict{String,Friedman.LeafCommand})
    for k in sort!(collect(keys(node.subcmds)))
        sub = node.subcmds[k]
        p = isempty(prefix) ? k : "$prefix $k"
        if sub isa Friedman.LeafCommand
            out[p] = sub
        else
            _collect_leaves(sub, p, out)
        end
    end
    return out
end

function _find_opt(leaf::Friedman.LeafCommand, name::String)
    idx = findfirst(o -> o.name == name, leaf.options)
    return idx === nothing ? nothing : leaf.options[idx]
end

function main()
    leaves = _collect_leaves(Friedman.APP.root, "", Dict{String,Friedman.LeafCommand}())
    violations = String[]

    # 0. Sanity: micro & macro sets must be disjoint
    overlap = intersect(EXPECTED_MICRO_LEAVES, EXPECTED_MACRO_LEAVES)
    if !isempty(overlap)
        push!(violations, "EXPECTED_MICRO_LEAVES and EXPECTED_MACRO_LEAVES overlap: $(join(sort!(collect(overlap)), ", "))")
    end

    # 1. Check every expected micro leaf
    for p in sort!(collect(EXPECTED_MICRO_LEAVES))
        leaf = get(leaves, p, nothing)
        if leaf === nothing
            push!(violations, "missing expected micro leaf: $p")
            continue
        end
        cl = _find_opt(leaf, "conf-level")
        if cl === nothing
            push!(violations, "micro leaf `$p` missing --conf-level option")
        else
            if cl.default !== 0.90
                push!(violations, "micro leaf `$p` --conf-level default is $(repr(cl.default)) (expected 0.90)")
            end
            for al in REQUIRED_CONF_ALIASES
                al in cl.aliases || push!(violations, "micro leaf `$p` --conf-level missing alias --$al")
            end
        end
    end

    # 2. Check every expected macro leaf
    for p in sort!(collect(EXPECTED_MACRO_LEAVES))
        leaf = get(leaves, p, nothing)
        if leaf === nothing
            push!(violations, "missing expected macro leaf: $p")
            continue
        end
        cl = _find_opt(leaf, "conf-level")
        qt = _find_opt(leaf, "quantiles")
        if cl === nothing && qt === nothing
            push!(violations, "macro leaf `$p` missing both --conf-level and --quantiles")
            continue
        end
        if cl !== nothing
            if cl.default !== 0.68
                push!(violations, "macro leaf `$p` --conf-level default is $(repr(cl.default)) (expected 0.68)")
            end
            for al in REQUIRED_CONF_ALIASES
                al in cl.aliases || push!(violations, "macro leaf `$p` --conf-level missing alias --$al")
            end
        end
        if qt !== nothing && qt.default != "0.16,0.5,0.84"
            push!(violations, "macro leaf `$p` --quantiles default is $(repr(qt.default)) (expected \"0.16,0.5,0.84\")")
        end
    end

    # 3. 100% classification coverage: no unclassified leaf may carry --conf-level or --quantiles
    n_quantiles = 0
    for (p, leaf) in sort!(collect(leaves); by=first)
        cl = _find_opt(leaf, "conf-level")
        qt = _find_opt(leaf, "quantiles")
        qt !== nothing && (n_quantiles += 1)
        if cl !== nothing || qt !== nothing
            if !(p in EXPECTED_MICRO_LEAVES) && !(p in EXPECTED_MACRO_LEAVES)
                push!(violations, "unclassified CI leaf `$p` (conf-level=$(cl === nothing ? "-" : repr(cl.default)), quantiles=$(qt === nothing ? "-" : repr(qt.default))) — classify as micro (0.90) or macro (0.68) in check_ci_defaults.jl")
            end
        end
    end

    # 4. Landmine L8 guards: 5% hypothesis tests & SARIMA & Growth-at-Risk
    for p in sort!(collect(EXPECTED_FIVE_PCT_TESTS))
        leaf = get(leaves, p, nothing)
        if leaf === nothing
            push!(violations, "missing 5% hypothesis test leaf: $p")
            continue
        end
        _find_opt(leaf, "conf-level") === nothing ||
            push!(violations, "5% hypothesis test `$p` must NOT carry --conf-level (Landmine L8)")
        lv = _find_opt(leaf, "level")
        if lv === nothing || lv.default !== 0.05
            push!(violations, "5% hypothesis test `$p` --level default must be 0.05 (got $(lv === nothing ? "missing" : repr(lv.default)))")
        end
    end
    for p in sort!(collect(SARIMA_LEAVES))
        leaf = get(leaves, p, nothing)
        leaf === nothing && continue
        _find_opt(leaf, "quantiles") === nothing ||
            push!(violations, "SARIMA leaf `$p` must NOT carry --quantiles (Landmine L8: clashes with seasonal MA --Q)")
    end
    gar = get(leaves, "forecast factor growth-at-risk", nothing)
    if gar !== nothing
        al = _find_opt(gar, "alpha")
        (al !== nothing && al.default === 0.05) ||
            push!(violations, "forecast factor growth-at-risk --alpha must remain 0.05 (tail risk probability)")
    end

    # 5. Static scan: zero hardcoded 95% z-critical values (1.95996 / 1.96) in src/commands/*.jl
    cmd_dir = joinpath(ROOT, "src", "commands")
    for fname in sort!(readdir(cmd_dir))
        endswith(fname, ".jl") || continue
        fpath = joinpath(cmd_dir, fname)
        lines = readlines(fpath)
        in_doc = false
        for (idx, line) in enumerate(lines)
            if length(collect(eachmatch(r"\"\"\"", line))) % 2 == 1
                in_doc = !in_doc
                continue
            end
            in_doc && continue
            code = split(line, "#"; limit=2)[1]
            if occursin(r"(?<![0-9.])(1\.95996\d*|1\.96)(?![0-9])", code)
                push!(violations, "hardcoded 95% z-critical value in src/commands/$fname:$idx: $(strip(line))")
            end
        end
    end

    if isempty(violations)
        println("PASS: check_ci_defaults.jl — $(length(EXPECTED_MICRO_LEAVES)) micro (90%), $(length(EXPECTED_MACRO_LEAVES)) macro (68%), $n_quantiles quantile-band (\"0.16,0.5,0.84\") leaves verified; 0 unclassified CI leaves, 0 hardcoded 1.96/1.95996.")
        return 0
    end

    println("FAIL: check_ci_defaults.jl — $(length(violations)) violation(s):")
    for v in violations
        println("  - $v")
    end
    return 1
end

exit(main())
