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

# TOML config file parsing for complex model specifications

# ── Schema (F65 / C030) ───────────────────────────────────────

"""Known top-level sections → allowed keys (unknown → warning / --strict error)."""
const CONFIG_SCHEMA = Dict{String,Vector{String}}(
    "prior" => ["type", "hyperparameters", "optimization"],
    "identification" => ["method", "sign_matrix", "narrative", "zero_restrictions",
                         "sign_restrictions", "a0_zero_restrictions",
                         "a0_sign_restrictions", "elasticity_bounds",
                         "magnitude_bounds", "cumulative_restrictions",
                         "narrative_shocks", "narrative_contributions", "uhlig",
                         "lewis_tvv", "sv_svar"],
    "svar" => ["recursive", "A", "B", "long_run", "n_starts", "max_iter"],
    "svec" => ["long_run_zeros", "short_run_zeros"],
    "gmm" => ["moment_conditions", "instruments", "weighting",
             "dep", "endogenous", "exogenous", "theta0"],
    "smm" => ["model", "theta0", "lags", "p", "lower", "upper",
              "weighting", "sim_ratio", "burn"],
    "nongaussian" => ["method", "contrast", "distribution", "n_regimes",
                      "transition_variable", "regime_variable"],
    "model" => ["parameters", "endogenous", "exogenous", "equations",
                "linear", "utility", "beta", "controls"],
    "solver" => ["method", "order", "degree", "grid"],
    "constraints" => ["bounds", "nonlinear"],
    "priors" => String[],  # free param names under [priors]
    "svar_hypothesis" => ["type", "ordering", "zeros", "R", "r", "restrictions",
                          "short_run", "long_run", "horizon"],
)

"""Nested tables under known sections."""
const CONFIG_NESTED_SCHEMA = Dict{String,Vector{String}}(
    "prior.hyperparameters" => ["lambda1", "lambda2", "lambda3", "lambda4"],
    "prior.optimization" => ["enabled"],
    "identification.sign_matrix" => ["matrix", "horizons"],
    "identification.narrative" => ["shock_index", "periods", "signs"],
    "identification.uhlig" => ["n_starts", "n_refine", "max_iter_coarse",
                               "max_iter_fine", "tol_coarse", "tol_fine", "scale"],
    "identification.lewis_tvv" => ["weighting"],
    "identification.sv_svar" => ["hetero_shocks", "maxiter", "gibbs_burn",
                                 "gibbs_draws", "init"],
    "svar_hypothesis.short_run" => ["type", "ordering", "zeros", "R", "r", "recursiveness"],
    "svar_hypothesis.long_run" => ["ordering", "zeros"],
    "svar_hypothesis.horizon" => ["ordering", "restrictions"],
)

"""Enum-like string fields validated against allow-lists."""
const CONFIG_ENUMS = Dict{String,Vector{String}}(
    "prior.type" => ["minnesota"],
    "identification.method" => ["cholesky", "sign", "narrative", "longrun", "long-run", "arias", "uhlig",
                                "narrative-adrr", "proxy", "max-share", "gmm-moments",
                                "svec", "svar",
                                "fastica", "jade", "sobi", "dcov", "hsic", "cvm",
                                "student_t", "student-t",
                                "mixture_normal", "mixture-normal",
                                "mixture_normal_asym", "mixture-normal-asym",
                                "pml",
                                "skew_normal", "skew-normal",
                                "lms",
                                "markov_switching", "markov-switching",
                                "garch_id", "garch-id",
                                "lewis-tvv", "sv-em"],
    "gmm.weighting" => ["identity", "optimal", "twostep", "iterated", "two_step", "cue"],
    "smm.weighting" => ["identity", "optimal", "two_step", "iterated", "twostep"],
    "smm.model" => ["ar1", "arp", "var1", "iid_normal"],
    "nongaussian.method" => ["fastica", "jade", "ml", "markov", "garch",
                             "smooth_transition", "external"],
    "nongaussian.contrast" => ["logcosh", "exp", "kurtosis"],
    "nongaussian.distribution" => ["student_t", "skew_t", "ghd"],
    "solver.method" => ["gensys", "klein", "perturbation", "projection", "pfi"],
    "svar_hypothesis.type" => ["recursiveness", "impact_zero", "impact-zero",
                               "impact_linear", "impact-linear",
                               "long_run", "long-run",
                               "horizon_irf", "horizon-irf", "mixed"],
)

# Thread/task-local strict flag set by wrap_legacy from --strict
const _CONFIG_STRICT = Ref(false)
# Merged temp config paths created by write_merged_config_toml (already validated & unconfined)
const _MERGED_CONFIG_PATHS = Set{String}()

"""
    load_config(path) → Dict

Load and validate a TOML configuration file.
"""
function load_config(path::String)
    is_merged = path in _MERGED_CONFIG_PATHS
    is_merged || _validate_input_path(path)
    resolved = _expanduser(path)
    isfile(resolved) ||
        throw(CliError("config/file-not-found", "config file not found: $path"))
    cfg = try
        TOML.parsefile(resolved)
    catch e
        e isa CliError && rethrow()
        if !is_merged && isdefined(@__MODULE__, :_text_looks_like_card) &&
           isdefined(@__MODULE__, :_slurp_ignoring) &&
           _text_looks_like_card(_slurp_ignoring(resolved))
            throw(CliError("config/malformed-toml",
                           "failed to parse config file '$path': $(sprint(showerror, e))";
                           hint="'$(basename(path))' is written as a model card; rename it to .card, or write the config as TOML"))
        end
        throw(CliError("config/malformed-toml",
                       "failed to parse config file '$path': $(sprint(showerror, e))"))
    end
    is_merged || validate_config_schema!(cfg; strict=_CONFIG_STRICT[])
    return cfg
end

function _check_no_toml_null(x, keypath::String="")
    if x === nothing
        throw(CliError("config/malformed-json",
            "null value at '$(isempty(keypath) ? "<root>" : keypath)' is not supported in TOML config";
            hint="omit the null key or pass a concrete value"))
    elseif x isa AbstractDict
        for (k, v) in x
            ks = string(k)
            _check_no_toml_null(v, isempty(keypath) ? ks : "$keypath.$ks")
        end
    elseif x isa AbstractVector
        for (idx, v) in enumerate(x)
            _check_no_toml_null(v, "$keypath[$idx]")
        end
    end
end

"""
    merge_config(path; config_json="", set=String[], strict=false) → Dict

Merge config layers: file < config-json < --set (C030).
Validates the merged result.
"""
function merge_config(path::String=""; config_json::String="",
                      set::Vector{String}=String[], strict::Bool=false)
    cfg = Dict{String,Any}()
    if !isempty(path)
        # load without double-validating intermediate — validate once at end
        _validate_input_path(path)
        resolved = _expanduser(path)
        isfile(resolved) ||
            throw(CliError("config/file-not-found", "config file not found: $path"))
        file_cfg = try
            TOML.parsefile(resolved)
        catch e
            e isa CliError && rethrow()
            if isdefined(@__MODULE__, :_text_looks_like_card) &&
               isdefined(@__MODULE__, :_slurp_ignoring) &&
               _text_looks_like_card(_slurp_ignoring(resolved))
                throw(CliError("config/malformed-toml",
                               "failed to parse config file '$path': $(sprint(showerror, e))";
                               hint="'$(basename(path))' is written as a model card; rename it to .card, or write the config as TOML"))
            end
            throw(CliError("config/malformed-toml",
                           "failed to parse config file '$path': $(sprint(showerror, e))"))
        end
        deep_merge!(cfg, _string_key_dict(file_cfg))
    end
    if !isempty(config_json)
        j = try
            JSON3.read(config_json)
        catch e
            throw(CliError("config/malformed-json",
                           "failed to parse --config-json: $(sprint(showerror, e))"))
        end
        j isa AbstractDict || throw(CliError("config/malformed-json",
            "--config-json must be a JSON object, got $(typeof(j))"))
        jdict = _json_to_dict(j)
        _check_no_toml_null(jdict)
        deep_merge!(cfg, jdict)
    end
    for assignment in set
        apply_set!(cfg, assignment)
    end
    validate_config_schema!(cfg; strict=strict)
    return cfg
end

"""Write a merged config Dict to a temp TOML path (for handlers that call load_config)."""
function write_merged_config_toml(cfg::AbstractDict)::String
    _check_no_toml_null(cfg)
    path = tempname() * ".toml"
    open(path, "w") do io
        TOML.print(io, cfg)
    end
    length(_MERGED_CONFIG_PATHS) > 128 && empty!(_MERGED_CONFIG_PATHS)
    push!(_MERGED_CONFIG_PATHS, path)
    return path
end

function deep_merge!(base::Dict, over::AbstractDict)
    for (k, v) in over
        key = string(k)
        if v isa AbstractDict && get(base, key, nothing) isa AbstractDict
            deep_merge!(base[key], v)
        else
            base[key] = v isa AbstractDict ? _string_key_dict(v) : v
        end
    end
    return base
end

function _string_key_dict(d::AbstractDict)
    out = Dict{String,Any}()
    for (k, v) in d
        out[string(k)] = v isa AbstractDict ? _string_key_dict(v) : v
    end
    return out
end

function _json_to_dict(j)
    if j isa AbstractDict
        return Dict{String,Any}(string(k) => _json_to_dict(v) for (k, v) in j)
    elseif j isa AbstractVector
        return Any[_json_to_dict(x) for x in j]
    else
        return j
    end
end

"""
    apply_set!(cfg, \"dotted.key=value\")

Apply a single --set override (dotted path).
"""
function apply_set!(cfg::Dict, assignment::AbstractString)
    eq = findfirst('=', assignment)
    isnothing(eq) && throw(CliError("config/bad-set",
        "--set expects key=value, got '$assignment'",
        hint="example: --set prior.hyperparameters.lambda1=0.2"))
    keypath = String(assignment[1:prevind(assignment, eq)])
    rawval = String(assignment[nextind(assignment, eq):end])
    isempty(keypath) && throw(CliError("config/bad-set", "empty key in --set '$assignment'"))
    parts = split(keypath, '.')
    node = cfg
    for p in parts[1:end-1]
        child = get(node, p, nothing)
        if !(child isa AbstractDict)
            child = Dict{String,Any}()
            node[p] = child
        end
        node = child
    end
    node[parts[end]] = _parse_set_value(rawval)
    return cfg
end

function _parse_set_value(s::AbstractString)
    ls = lowercase(strip(s))
    ls == "true" && return true
    ls == "false" && return false
    if occursin(r"^-?\d+$", strip(s))
        return parse(Int, strip(s))
    end
    f = tryparse(Float64, strip(s))
    f !== nothing && return f
    return String(s)
end

function _config_unknown!(code::String, msg::String; strict::Bool)
    if strict
        throw(CliError(code, msg, hint="fix the key or drop --strict"))
    end
    if _QUIET[]
        # Stay silent under --quiet for non-strict stderr, still attach to envelope
    else
        _status_styled("Warning: "; bold=true, color=:yellow)
        println(stderr, code, ": ", msg)
    end
    if envelope_active()
        isdefined(@__MODULE__, :_add_warning_once!) ?
            _add_warning_once!(_ENVELOPE[], code, msg) :
            add_warning!(_ENVELOPE[], code, msg)
    end
    return nothing
end

"""
    validate_config_schema!(cfg; strict=false)

Warn (or error under --strict) on unknown keys; suggest nearest known name (F65).
"""
function validate_config_schema!(cfg::AbstractDict; strict::Bool=false)
    for (section, body) in cfg
        sec = string(section)
        haskey(CONFIG_SCHEMA, sec) || continue  # free-form top-level ignored
        known = CONFIG_SCHEMA[sec]
        body isa AbstractDict || continue
        if !isempty(known)
            _validate_level!(body, known, sec; strict)
        end
        # nested tables
        for (sub, subknown) in CONFIG_NESTED_SCHEMA
            startswith(sub, sec * ".") || continue
            subname = sub[length(sec)+2:end]
            if haskey(body, subname) && body[subname] isa AbstractDict
                _validate_level!(body[subname], subknown, sub; strict)
            end
        end
        # enums at this section
        for (ek, allowed) in CONFIG_ENUMS
            startswith(ek, sec * ".") || continue
            field = ek[length(sec)+2:end]
            if haskey(body, field)
                val = string(body[field])
                if !(val in allowed)
                    _config_unknown!("config/bad-enum",
                        "invalid value '$val' for $ek (allowed: $(join(allowed, ", ")))";
                        strict)
                end
            end
        end
    end
    return cfg
end

function _validate_level!(d::AbstractDict, known::Vector{String}, path::String; strict::Bool)
    for k in keys(d)
        ks = string(k)
        ks in known && continue
        sugg = _nearest(ks, known)
        msg = "unknown config key '$path.$ks'"
        if sugg !== nothing
            msg *= " — did you mean '$sugg'?"
        end
        _config_unknown!("config/unknown-key", msg; strict)
    end
end

"""
    get_identification(config) → Dict

Extract identification settings from a config dict.
Returns method, sign_matrix, narrative constraints, etc.
"""
function get_identification(config::Dict)
    id_cfg = get(config, "identification", Dict())
    method = get(id_cfg, "method", "cholesky")
    result = Dict{String,Any}("method" => method)

    if method == "sign" || haskey(id_cfg, "sign_matrix")
        sm = get(id_cfg, "sign_matrix", Dict())
        if sm isa AbstractDict
            if haskey(sm, "matrix")
                result["sign_matrix"] = _parse_matrix(sm["matrix"])
            end
            if haskey(sm, "horizons")
                hs = sm["horizons"]
                hs isa AbstractVector && all(x -> x isa Integer, hs) || throw(CliError(
                    "config/invalid", "identification.sign_matrix.horizons must be an array of integers"))
                result["horizons"] = Int.(hs)
            end
        elseif !isnothing(sm)
            throw(CliError("config/invalid",
                "identification.sign_matrix must be a table with matrix/horizons"))
        end
    end

    if method == "narrative" || haskey(id_cfg, "narrative")
        narr = get(id_cfg, "narrative", Dict())
        result["narrative"] = Dict{String,Any}(
            "shock_index" => get(narr, "shock_index", 1),
            "periods" => get(narr, "periods", Int[]),
            "signs" => get(narr, "signs", Int[])
        )
    end

    return result
end

"""
    get_prior(config) → Dict

Extract Bayesian prior settings from a config dict.
"""
function get_prior(config::Dict)
    pr = get(config, "prior", Dict())
    prior_type = get(pr, "type", "minnesota")
    result = Dict{String,Any}("type" => prior_type)

    hyper = get(pr, "hyperparameters", Dict())
    if !isempty(hyper)
        result["lambda1"] = get(hyper, "lambda1", 0.2)
        result["lambda2"] = get(hyper, "lambda2", 0.5)
        result["lambda3"] = get(hyper, "lambda3", 1.0)
        result["lambda4"] = get(hyper, "lambda4", 1e5)
    end

    opt = get(pr, "optimization", Dict())
    result["optimize"] = get(opt, "enabled", false)

    return result
end

"""
    get_gmm(config) → Dict

Extract GMM specification from a config dict.
"""
function get_gmm(config::Dict)
    gmm = get(config, "gmm", Dict())
    result = Dict{String,Any}()

    result["moment_conditions"] = _gmm_string_vec(get(gmm, "moment_conditions", String[]))
    result["instruments"] = _gmm_string_vec(get(gmm, "instruments", String[]))
    result["weighting"] = get(gmm, "weighting", "twostep")
    result["dep"] = strip(string(get(gmm, "dep", "")))
    result["endogenous"] = _gmm_string_vec(get(gmm, "endogenous", String[]))
    result["exogenous"] = _gmm_string_vec(get(gmm, "exogenous", String[]))
    result["theta0"] = _gmm_theta0(get(gmm, "theta0", Float64[]))

    return result
end

_gmm_string_vec(x::AbstractVector) = String[string(v) for v in x]
_gmm_string_vec(x::AbstractString) = isempty(strip(x)) ? String[] : String[String(x)]
_gmm_string_vec(::Any) = String[]

function _gmm_theta0(x)
    x isa AbstractVector && return Float64[Float64(v) for v in x]
    x isa Number && return Float64[Float64(x)]
    return Float64[]
end

"""
    get_nongaussian(config) → Dict

Extract non-Gaussian SVAR settings from a config dict.
"""
function get_nongaussian(config::Dict)
    ng = get(config, "nongaussian", Dict())
    result = Dict{String,Any}()

    result["method"] = get(ng, "method", "fastica")
    result["contrast"] = get(ng, "contrast", "logcosh")
    result["distribution"] = get(ng, "distribution", "student_t")
    result["n_regimes"] = get(ng, "n_regimes", 2)
    result["transition_variable"] = get(ng, "transition_variable", "")
    result["regime_variable"] = get(ng, "regime_variable", "")

    return result
end

const _UHLIG_SCALE_SYMBOLS = (
    "diff", "first_difference", "residual", "sigma", "none", "unit",
)

function _parse_uhlig_scale(raw)
    if raw isa AbstractString
        raw in _UHLIG_SCALE_SYMBOLS || throw(CliError(
            "config/invalid",
            "identification.uhlig.scale must be diff|first_difference|residual|sigma|" *
            "none|unit or a positive numeric vector (got '$raw')",
        ))
        return Symbol(raw)
    elseif raw isa Symbol
        string(raw) in _UHLIG_SCALE_SYMBOLS || throw(CliError(
            "config/invalid",
            "identification.uhlig.scale must be diff|first_difference|residual|sigma|" *
            "none|unit or a positive numeric vector (got :$raw)",
        ))
        return raw
    elseif raw isa AbstractVector
        !isempty(raw) || throw(CliError(
            "config/invalid",
            "identification.uhlig.scale vector must not be empty",
        ))
        out = Float64[]
        for v in raw
            (v isa Real && !(v isa Bool) && isfinite(v) && v > 0) || throw(CliError(
                "config/invalid",
                "identification.uhlig.scale vector must hold positive finite numbers " *
                "(got $v)",
            ))
            push!(out, Float64(v))
        end
        return out
    end
    throw(CliError(
        "config/invalid",
        "identification.uhlig.scale must be a string or positive numeric vector " *
        "(got $raw)",
    ))
end

function _validate_uhlig_scale(scale, n::Int, leaf::String)
    if scale isa AbstractVector && length(scale) != n
        throw(CliError(
            "config/invalid",
            "$leaf: identification.uhlig.scale vector has length $(length(scale)), " *
            "expected $n (number of variables)",
        ))
    end
    return scale
end

"""
    get_uhlig_params(config) → Dict

Extract Uhlig SVAR identification tuning parameters from a config dict.
"""
function get_uhlig_params(config::Dict)
    id_cfg = get(config, "identification", Dict())
    uhlig = get(id_cfg, "uhlig", Dict())
    uhlig isa AbstractDict || throw(CliError(
        "config/invalid",
        "[identification.uhlig] must be a table (got $uhlig)",
    ))
    scale = haskey(uhlig, "scale") ? _parse_uhlig_scale(uhlig["scale"]) : :diff
    return Dict{String,Any}(
        "n_starts" => get(uhlig, "n_starts", 50),
        "n_refine" => get(uhlig, "n_refine", 10),
        "max_iter_coarse" => get(uhlig, "max_iter_coarse", 500),
        "max_iter_fine" => get(uhlig, "max_iter_fine", 2000),
        "tol_coarse" => get(uhlig, "tol_coarse", 1e-4),
        "tol_fine" => get(uhlig, "tol_fine", 1e-8),
        "scale" => scale,
    )
end

"""
    get_lewis_tvv_params(config) → Dict

Extract Lewis (2021) TVV-ID estimator knobs from
`[identification.lewis_tvv]`. Upstream `identify_lewis_tvv`
takes `weighting` as a Symbol and throws a bare
`ArgumentError` on anything else (exit 3 for a TOML-authored
value), so validate here → `config/invalid` (exit 4).
Remaining estimator knobs (K/lags/n_starts/max_iter/hac/
bandwidth/tol) stay on upstream defaults (deferred with
record, W1/#186 appendix).
"""
function get_lewis_tvv_params(config::Dict)
    id_cfg = get(config, "identification", Dict())
    tvv = get(id_cfg, "lewis_tvv", Dict{String,Any}())
    tvv isa AbstractDict || throw(CliError("config/invalid",
        "[identification.lewis_tvv] must be a table (got $tvv)"))
    w = string(get(tvv, "weighting", "two_step"))
    w in ("one_step", "two_step", "cue") || throw(CliError("config/invalid",
        "identification.lewis_tvv.weighting must be one_step|two_step|cue (got '$w')"))
    Dict{String,Any}("weighting" => Symbol(w))
end

"""
    get_sv_svar_params(config) → Dict

Extract Bertsche–Braun (2022) SV-SVAR EM knobs from
`[identification.sv_svar]`. `hetero_shocks` holds 1-based
shock indices (resolved against the data width at the call
site → `usage/invalid` there); empty (default) means every
shock gets SV treatment. `smoother` is deliberately NOT
exposed: upstream supports only `:ksc`, so there is no
choice to offer. Remaining knobs (tol/b_iter/theta_grid/
phi_init/s_init/c) stay on upstream defaults (deferred with
record, W1/#186 appendix).
"""
function get_sv_svar_params(config::Dict)
    id_cfg = get(config, "identification", Dict())
    sv = get(id_cfg, "sv_svar", Dict{String,Any}())
    sv isa AbstractDict || throw(CliError("config/invalid",
        "[identification.sv_svar] must be a table (got $sv)"))
    raw_hs = get(sv, "hetero_shocks", Int[])
    raw_hs isa AbstractVector || throw(CliError("config/invalid",
        "identification.sv_svar.hetero_shocks must be a list of 1-based shock indices (got $raw_hs)"))
    hetero_shocks = Int[]
    for v in raw_hs
        (v isa Integer && !(v isa Bool) && v >= 1) || throw(CliError("config/invalid",
            "identification.sv_svar.hetero_shocks must hold integers ≥ 1 (got $v)"))
        push!(hetero_shocks, Int(v))
    end
    maxiter = get(sv, "maxiter", 500)
    (maxiter isa Integer && !(maxiter isa Bool) && maxiter >= 1) || throw(CliError("config/invalid",
        "identification.sv_svar.maxiter must be an integer ≥ 1 (got $maxiter)"))
    gibbs_burn = get(sv, "gibbs_burn", 5)
    (gibbs_burn isa Integer && !(gibbs_burn isa Bool) && gibbs_burn >= 0) || throw(CliError("config/invalid",
        "identification.sv_svar.gibbs_burn must be an integer ≥ 0 (got $gibbs_burn)"))
    gibbs_draws = get(sv, "gibbs_draws", 100)
    (gibbs_draws isa Integer && !(gibbs_draws isa Bool) && gibbs_draws >= 1) || throw(CliError("config/invalid",
        "identification.sv_svar.gibbs_draws must be an integer ≥ 1 (got $gibbs_draws)"))
    init = string(get(sv, "init", "ols_chol"))
    init in ("ols_chol", "haar") || throw(CliError("config/invalid",
        "identification.sv_svar.init must be ols_chol|haar (got '$init')"))
    Dict{String,Any}("hetero_shocks" => hetero_shocks,
                     "maxiter" => Int(maxiter),
                     "gibbs_burn" => Int(gibbs_burn),
                     "gibbs_draws" => Int(gibbs_draws),
                     "init" => Symbol(init))
end

"""
    get_dsge(config) → Dict

Extract DSGE model specification from a config dict.
Returns parameters, endogenous/exogenous variables, equations.
"""
function get_dsge(config::Dict)
    model = get(config, "model", Dict())
    result = Dict{String,Any}()

    result["parameters"] = get(model, "parameters", Dict{String,Any}())
    result["endogenous"] = get(model, "endogenous", String[])
    result["exogenous"] = get(model, "exogenous", String[])

    eqs_raw = get(model, "equations", Dict[])
    result["equations"] = String[eq["expr"] for eq in eqs_raw if haskey(eq, "expr")]

    # Pre-linearized model flag (MEMs ModelSpec.linear / @dsge `linear: true`)
    lin_raw = get(model, "linear", false)
    result["linear"] = lin_raw isa Bool ? lin_raw :
                       lowercase(string(lin_raw)) in ("true", "1", "yes")

    # Bellman VFI payload (MEMs 0.9.0): synthesized as `@dsge utility:` / `beta:` / `controls:`.
    result["utility"] = string(get(model, "utility", ""))
    result["beta"] = string(get(model, "beta", ""))
    ctrls_raw = get(model, "controls", String[])
    result["controls"] = if ctrls_raw isa AbstractVector
        String[string(c) for c in ctrls_raw]
    elseif ctrls_raw isa AbstractString && !isempty(strip(ctrls_raw))
        String[strip(s) for s in split(string(ctrls_raw), ",") if !isempty(strip(s))]
    else
        String[]
    end

    # Optional solver section
    solver = get(config, "solver", Dict())
    result["solver_method"] = get(solver, "method", "gensys")
    result["solver_order"] = get(solver, "order", 1)
    result["solver_degree"] = get(solver, "degree", 5)
    result["solver_grid"] = get(solver, "grid", "auto")

    return result
end

"""
    get_dsge_constraints(config) → Dict

Extract DSGE constraint specifications (OccBin bounds, nonlinear).
"""
function get_dsge_constraints(config::Dict)
    con = get(config, "constraints", Dict())
    result = Dict{String,Any}()

    bounds_raw = get(con, "bounds", Dict[])
    bounds = Dict{String,Any}[]
    for b in bounds_raw
        bound = Dict{String,Any}("variable" => get(b, "variable", ""))
        if haskey(b, "lower")
            bound["lower"] = Float64(b["lower"])
        end
        if haskey(b, "upper")
            bound["upper"] = Float64(b["upper"])
        end
        push!(bounds, bound)
    end
    result["bounds"] = bounds

    nonlinear_raw = get(con, "nonlinear", Dict[])
    nonlinear = Dict{String,Any}[]
    for nl in nonlinear_raw
        entry = Dict{String,Any}("expr" => get(nl, "expr", ""))
        if haskey(nl, "label")
            entry["label"] = String(nl["label"])
        end
        push!(nonlinear, entry)
    end
    result["nonlinear"] = nonlinear

    return result
end

_smm_floatvec(x, name) = begin
    x isa AbstractVector || throw(CliError("config/type", "[smm] `$name` must be an array of numbers"))
    out = Float64[]
    for v in x
        v isa Real || throw(CliError("config/type", "[smm] `$name` must contain only numbers, got $(typeof(v))"))
        push!(out, Float64(v))
    end
    out
end

_smm_int(x, name) = begin
    x isa Integer && return Int(x)
    (x isa Real && isinteger(x)) && return Int(x)
    throw(CliError("config/type", "[smm] `$name` must be an integer"))
end

"""
    get_smm(config) → Dict

Extract the SMM specification from a config dict. Lenient parser: absent optional keys
return `nothing` (the handler validates what SMM actually needs — a data-generating
`model` and `theta0`). SMM matches simulated moments to sample moments, so it requires
BOTH a simulator (built from the named built-in `model`) and the moment function.

Keys:
- `model`     — built-in simulator: `ar1` | `arp` | `var1` | `iid_normal` (required by handler)
- `theta0`    — initial parameter vector, layout depends on `model` (required by handler)
- `lags`      — autocovariance-moment lags (default 1)
- `p`         — AR order (required only for `model = "arp"`)
- `lower`/`upper` — optional parameter bounds → `ParameterTransform` (both, same length as `theta0`)
- `weighting` — `identity` | `two_step` (aliases `optimal`/`iterated`/`twostep` → `two_step`)
- `sim_ratio` — simulation-to-sample ratio (default 5)
- `burn`      — burn-in periods (default 100)
"""
function get_smm(config::Dict)
    smm = get(config, "smm", Dict())
    # A `nothing` value means "this card does not set the key".  TOML cannot
    # spell that, but a lowered model card carries every key with `nothing` for
    # the ones it omits, so it is read as an ABSENT key — never as a value.
    _v(k, fallback) = (haskey(smm, k) && smm[k] !== nothing) ? smm[k] : fallback
    _vec(k) = (x = _v(k, nothing)) === nothing ? nothing : _smm_floatvec(x, k)
    model = _v("model", nothing)
    Dict{String,Any}(
        "model"     => model === nothing ? nothing : String(model),
        "theta0"    => _vec("theta0"),
        "lags"      => _smm_int(_v("lags", 1), "lags"),
        "p"         => (_pk = _v("p", nothing)) === nothing ? nothing : _smm_int(_pk, "p"),
        "lower"     => _vec("lower"),
        "upper"     => _vec("upper"),
        "weighting" => String(_v("weighting", "two_step")),
        "sim_ratio" => _smm_int(_v("sim_ratio", 5), "sim_ratio"),
        "burn"      => _smm_int(_v("burn", 100), "burn"),
    )
end

# Column-name list from a TOML value (a [[equations]] `indep`/`instr` or [instruments] `common`).
_system_strvec(x, ctx) = begin
    x isa AbstractVector || throw(CliError("config/type", "$ctx must be an array of column names"))
    out = String[]
    for v in x
        (v isa AbstractString) || throw(CliError("config/type", "$ctx must contain only column-name strings, got $(typeof(v))"))
        s = strip(String(v))
        isempty(s) && throw(CliError("config/shape", "$ctx contains an empty column name"))
        push!(out, s)
    end
    isempty(out) && throw(CliError("config/shape", "$ctx must list at least one column"))
    out
end

"""
    get_system(config) → Dict

Extract a multi-equation **systems** specification (SUR / 3SLS) from a config dict.
Each `[[equations]]` block names a dependent column (`dep`) and regressor columns
(`indep`); a block may add its own instruments (`instr`) and/or a shared
`[instruments].common` set may be given (3SLS).

Returns `Dict("equations" => [Dict("name","dep","indep","instr"), ...],
"common_instruments" => Vector{String} | nothing)`. Column *names* only — the
handler resolves them against the data CSV. Raises typed `config/*` CliErrors.

A model card lowers to the same shape with two differences this function
accepts: the shared set arrives under `common_instruments` rather than
`[instruments].common`, and an equation with no `|` arrives with `instr =>
nothing`. A config carrying BOTH spellings of the shared set is refused
(`config/invalid`) rather than resolved by an invisible precedence.
"""
function get_system(config::Dict)
    eqs_raw = get(config, "equations", nothing)
    (eqs_raw isa AbstractVector && !isempty(eqs_raw)) || throw(CliError("config/missing",
        "systems estimation requires at least one [[equations]] block with `dep` and `indep`"))
    equations = Vector{Dict{String,Any}}()
    for (j, e) in enumerate(eqs_raw)
        e isa AbstractDict || throw(CliError("config/type", "[[equations]] entry $j must be a table"))
        haskey(e, "dep") || throw(CliError("config/missing-key", "[[equations]] entry $j missing `dep`"))
        haskey(e, "indep") || throw(CliError("config/missing-key", "[[equations]] entry $j missing `indep`"))
        dep = strip(String(e["dep"]))
        isempty(dep) && throw(CliError("config/shape", "[[equations]] entry $j has an empty `dep`"))
        push!(equations, Dict{String,Any}(
            "name"  => haskey(e, "name") ? String(e["name"]) : "eq$(j)",
            "dep"   => dep,
            "indep" => _system_strvec(e["indep"], "[[equations]] entry $j `indep`"),
            # `instr => nothing` means "no instruments on this equation".  A
            # TOML `[[equations]]` block cannot spell that (no such value), but
            # a model card lowers to it, so it is treated as an absent key.
            "instr" => (haskey(e, "instr") && e["instr"] !== nothing) ?
                       _system_strvec(e["instr"], "[[equations]] entry $j `instr`") : nothing,
        ))
    end
    common = nothing
    # `instruments.common` is the documented TOML spelling; `common_instruments`
    # is the key a model card lowers to.  Both are accepted, and the documented
    # one is read FIRST: a config carrying both is a contradiction, so it is
    # refused rather than resolved by precedence the user cannot see.  (A card
    # lowers to the direct key alone, so this never fires on the card path.)
    instr_tbl = get(config, "instruments", nothing)
    nested = (instr_tbl isa AbstractDict && haskey(instr_tbl, "common")) ?
             instr_tbl["common"] : nothing
    direct = get(config, "common_instruments", nothing)
    if nested !== nothing && direct !== nothing
        throw(CliError("config/invalid",
            "shared instruments are given twice: `[instruments] common` and `common_instruments`. " *
            "Keep one."))
    end
    if nested !== nothing
        common = _system_strvec(nested, "[instruments] `common`")
    elseif direct !== nothing
        common = _system_strvec(direct, "`common_instruments`")
    end
    Dict{String,Any}("equations" => equations, "common_instruments" => common)
end

"""
    get_vecm_restriction(config, key) → Matrix{Float64}

Extract a `p × k` restriction matrix (row-major arrays-of-arrays) named `key`
(`"H"`, `"A"`, or `"b"`) from a `[vecm_restriction]` TOML section, for VECM
cointegration restriction tests (C071). Raises typed `config/*` CliErrors on a
missing section/key, a malformed (ragged / non-numeric / empty) matrix, so bad
config surfaces as an exit-4 config error rather than an internal exit-1.
"""
function get_vecm_restriction(config::Dict, key::String)
    sec = get(config, "vecm_restriction", nothing)
    sec isa AbstractDict || throw(CliError("config/missing",
        "VECM restriction test requires a [vecm_restriction] section with $key = [[...],[...]]"))
    haskey(sec, key) || throw(CliError("config/missing-key",
        "[vecm_restriction] must define $key = [[...],[...]] (row-major $key matrix)"))
    rows = sec[key]
    (rows isa AbstractVector && !isempty(rows) && all(r -> r isa AbstractVector, rows)) ||
        throw(CliError("config/type",
            "[vecm_restriction] $key must be a non-empty array of equal-length numeric rows"))
    ncol = length(first(rows))
    (ncol >= 1 && all(r -> length(r) == ncol, rows)) ||
        throw(CliError("config/shape",
            "[vecm_restriction] $key rows must all have the same length ≥ 1"))
    M = try
        [Float64(rows[i][j]) for i in 1:length(rows), j in 1:ncol]
    catch
        throw(CliError("config/type", "[vecm_restriction] $key must contain only numbers"))
    end
    return M
end

"""
    get_garch_midas(config) → Vector{Float64}

Extract the low-frequency driver series `x_lf` for a GARCH-MIDAS fit (C064a) from a
config dict. Required only for `--rv macro` (an exogenous macro / realized-variance
series, one value per calendar block); `--rv realized` derives the long-run
component from the returns themselves and needs no config. Expects a `[garch_midas]`
section with `x_lf = [...]`. Raises typed `config/*` CliErrors.
"""
function get_garch_midas(config::Dict)
    sec = get(config, "garch_midas", nothing)
    sec isa AbstractDict || throw(CliError("config/missing",
        "garch-midas --rv macro requires a [garch_midas] section with x_lf = [...]"))
    haskey(sec, "x_lf") || throw(CliError("config/missing-key",
        "[garch_midas] must define x_lf = [...] (low-frequency driver, one value per block)"))
    raw = sec["x_lf"]
    raw isa AbstractVector || throw(CliError("config/type",
        "[garch_midas] x_lf must be an array of numbers"))
    isempty(raw) && throw(CliError("config/shape",
        "[garch_midas] x_lf must list at least one value"))
    xlf = try
        Float64[Float64(v) for v in raw]
    catch
        throw(CliError("config/type", "[garch_midas] x_lf must contain only numbers"))
    end
    return xlf
end

"""
    get_dsge_priors(config) → Dict{String,Any}

Parse Bayesian DSGE prior specification from [priors] TOML section.
Each parameter maps to {dist, a, b} (distribution name + 2 shape params).
"""
function get_dsge_priors(config::Dict)
    priors_raw = get(config, "priors", Dict())
    isempty(priors_raw) && throw(CliError("config/missing-key", "TOML must have [priors] section with parameter distributions"))
    result = Dict{String,Any}()
    for (param, spec) in priors_raw
        spec isa Dict || error("prior for '$param' must be a table with dist, a, b keys")
        haskey(spec, "dist") || error("prior for '$param' missing 'dist' key")
        result[param] = Dict{String,Any}(
            "dist" => spec["dist"],
            "a"    => get(spec, "a", 0.0),
            "b"    => get(spec, "b", 1.0),
        )
    end
    return result
end

# Internal helpers

function _parse_matrix(rows::Vector)
    n = length(rows)
    n == 0 && return Matrix{Float64}(undef, 0, 0)
    rows[1] isa AbstractVector || throw(CliError("config/invalid",
        "matrix must be an array of rows (arrays), got $(typeof(rows[1])) in row 1"))
    m = length(rows[1])
    m == 0 && throw(CliError("config/invalid", "matrix rows must be non-empty"))
    for i in 2:n
        rows[i] isa AbstractVector || throw(CliError("config/invalid",
            "matrix row $i must be an array, got $(typeof(rows[i]))"))
        length(rows[i]) == m || throw(CliError("config/invalid",
            "matrix row $i has $(length(rows[i])) elements, expected $m"))
    end
    mat = Matrix{Float64}(undef, n, m)
    for i in 1:n
        for j in 1:m
            v = rows[i][j]
            v isa Real || throw(CliError("config/invalid",
                "matrix cell [$i,$j] must be a number, got $(repr(v))"))
            mat[i, j] = Float64(v)
        end
    end
    return mat
end

"""
    get_statespace(config) -> NamedTuple

Parse a `[statespace]` section describing a GENERAL linear-Gaussian state-space system, for
`estimate regression statespace --config`. The system is the standard single-block form

    yₜ   = Z αₜ + d + εₜ,     εₜ ~ N(0, H)
    αₜ₊₁ = T αₜ + c + R ηₜ,   ηₜ ~ N(0, Q)

Required keys: `Z` (n_obs × n_state), `H` (n_obs × n_obs), `T` (n_state × n_state), `Q` (r × r).
Optional: `d` (n_obs), `c` (n_state), `R` (n_state × r), `a1`/`P1` (explicit initialisation,
BOTH or NEITHER), `init_mode` (`kappa`|`diffuse`|`stationary`).

Matrices are row-major arrays of arrays; vectors are flat arrays. Note the TOML key is `T`
(standard notation) while the MEMs field is `Tt` and the constructor keyword is `T_mat` — `T` is
the type parameter in Julia, so the three names cannot be unified.

Dimensional consistency is checked HERE rather than left to the MEMs constructor, so a bad
config surfaces as `config/shape` (exit 4, pointing at the file the user wrote) instead of an
untyped `ArgumentError`.
"""
function get_statespace(config::Dict)
    sec = get(config, "statespace", nothing)
    sec isa AbstractDict || throw(CliError("config/missing",
        "estimate regression statespace --config requires a [statespace] section with Z, H, T and Q"))

    _mat(key) = begin
        haskey(sec, key) || throw(CliError("config/missing-key",
            "[statespace] must define $key = [[...],[...]] (row-major matrix)"))
        rows = sec[key]
        (rows isa AbstractVector && !isempty(rows) && all(r -> r isa AbstractVector, rows)) ||
            throw(CliError("config/type",
                "[statespace] $key must be a non-empty array of equal-length numeric rows"))
        ncol = length(first(rows))
        (ncol >= 1 && all(r -> length(r) == ncol, rows)) ||
            throw(CliError("config/shape",
                "[statespace] $key rows must all have the same length ≥ 1"))
        try
            [Float64(rows[i][j]) for i in 1:length(rows), j in 1:ncol]
        catch
            throw(CliError("config/type", "[statespace] $key must contain only numbers"))
        end
    end
    _optmat(key) = haskey(sec, key) ? _mat(key) : nothing
    _optvec(key) = begin
        haskey(sec, key) || return nothing
        v = sec[key]
        (v isa AbstractVector && !isempty(v) && all(x -> x isa Real, v)) ||
            throw(CliError("config/type", "[statespace] $key must be a non-empty flat array of numbers"))
        Float64[Float64(x) for x in v]
    end

    Z = _mat("Z"); H = _mat("H"); Tm = _mat("T"); Q = _mat("Q")
    n_obs, n_state = size(Z)
    size(H) == (n_obs, n_obs) || throw(CliError("config/shape",
        "[statespace] H must be n_obs×n_obs = ($n_obs, $n_obs) to match Z, got $(size(H))"))
    size(Tm) == (n_state, n_state) || throw(CliError("config/shape",
        "[statespace] T must be n_state×n_state = ($n_state, $n_state) to match Z, got $(size(Tm))"))

    R = _optmat("R")
    if R === nothing
        # MEMs defaults R to I(n_state, size(Q,1)); Q must then be r×r with r = size(Q,1),
        # and r cannot exceed n_state or the implied loading matrix is not well formed.
        size(Q, 1) == size(Q, 2) || throw(CliError("config/shape",
            "[statespace] Q must be square, got $(size(Q))"))
        size(Q, 1) <= n_state || throw(CliError("config/shape",
            "[statespace] Q is $(size(Q,1))×$(size(Q,1)) but the state has dimension $n_state; " *
            "supply R (n_state × r) explicitly for r > n_state"))
    else
        size(R, 1) == n_state || throw(CliError("config/shape",
            "[statespace] R must have n_state=$n_state rows to match Z, got $(size(R, 1))"))
        size(Q) == (size(R, 2), size(R, 2)) || throw(CliError("config/shape",
            "[statespace] Q must be r×r with r = size(R,2) = $(size(R, 2)), got $(size(Q))"))
    end

    r_shock = R === nothing ? size(Q, 1) : size(R, 2)
    G = _optmat("G")
    if G !== nothing
        size(G) == (r_shock, n_obs) || throw(CliError("config/shape",
            "[statespace] G must be r×n_obs = ($r_shock, $n_obs) to match Q/R and Z, got $(size(G))"))
        all(isfinite, G) || throw(CliError("config/invalid",
            "[statespace] G must contain only finite numbers"))
    end

    d = _optvec("d"); c = _optvec("c")
    d === nothing || length(d) == n_obs || throw(CliError("config/shape",
        "[statespace] d must have length n_obs=$n_obs, got $(length(d))"))
    c === nothing || length(c) == n_state || throw(CliError("config/shape",
        "[statespace] c must have length n_state=$n_state, got $(length(c))"))

    a1 = _optvec("a1"); P1 = _optmat("P1")
    # MEMs switches to init_mode=:explicit only when BOTH are supplied; supplying one alone
    # would be silently ignored, so reject it here rather than let the user think it applied.
    ((a1 === nothing) == (P1 === nothing)) || throw(CliError("config/shape",
        "[statespace] a1 and P1 must be supplied together (explicit initialisation) or not at all"))
    if a1 !== nothing
        length(a1) == n_state || throw(CliError("config/shape",
            "[statespace] a1 must have length n_state=$n_state, got $(length(a1))"))
        size(P1) == (n_state, n_state) || throw(CliError("config/shape",
            "[statespace] P1 must be n_state×n_state = ($n_state, $n_state), got $(size(P1))"))
    end

    im = get(sec, "init_mode", "kappa")
    im isa AbstractString || throw(CliError("config/type",
        "[statespace] init_mode must be a string (kappa|diffuse|stationary)"))
    String(im) in ("kappa", "diffuse", "stationary") || throw(CliError("config/invalid",
        "[statespace] init_mode must be kappa|diffuse|stationary, got '$im'"))

    return (Z=Z, H=H, T=Tm, Q=Q, R=R, G=G, d=d, c=c, a1=a1, P1=P1,
            init_mode=Symbol(String(im)), n_obs=n_obs, n_state=n_state)
end

"""
    get_determinacy(config) → NamedTuple

Parse a `[determinacy]` section for `dsge determinacy-map` (W12/#114).

`determinacy_region` sweeps ONE or TWO parameters over grids and records the Sims
existence/uniqueness verdict at each point, so the section names the parameters and their
grids:

```toml
[determinacy]
params = ["phi_pi", "phi_y"]        # 1 or 2 parameter names
lower  = [0.0, 0.0]                 # per-parameter grid start
upper  = [3.0, 1.0]                 # per-parameter grid end
points = [61, 41]                   # per-parameter grid resolution (>= 2)
# optional
method = "gensys"                   # gensys | klein | blanchard-kahn
div    = 1.00000001                 # stable/unstable eigenvalue boundary
```

A scalar is accepted wherever a one-element list would do, and `points` may be a single
integer applied to every parameter. `grids = [[...], [...]]` supplies explicit grid values
instead of lower/upper/points.

Every failure is a typed `config/*` CliError — a malformed sweep is user input, not a bug.
"""
function get_determinacy(config::Dict)
    sec = get(config, "determinacy", Dict())
    isempty(sec) && throw(CliError("config/missing-key",
        "TOML must have a [determinacy] section naming the swept parameter(s) and their grids";
        hint="params = [\"phi_pi\"], lower = [0.0], upper = [3.0], points = [61]"))

    _aslist(x) = x isa AbstractVector ? collect(x) : [x]

    praw = get(sec, "params", nothing)
    praw === nothing && throw(CliError("config/missing-key",
        "[determinacy] must set params (1 or 2 parameter names)"))
    params = String[]
    for p in _aslist(praw)
        p isa AbstractString || throw(CliError("config/type",
            "[determinacy] params entries must be strings, got $(typeof(p))"))
        push!(params, String(p))
    end
    np = length(params)
    (1 <= np <= 2) || throw(CliError("config/invalid",
        "[determinacy] sweeps 1 or 2 parameters, got $np ($(join(params, ", ")))"))
    length(unique(params)) == np || throw(CliError("config/invalid",
        "[determinacy] the swept parameters must be distinct, got $(join(params, ", "))"))

    grids = Vector{Vector{Float64}}()
    if haskey(sec, "grids")
        graw = sec["grids"]
        graw isa AbstractVector || throw(CliError("config/type",
            "[determinacy] grids must be a list of value lists, one per parameter"))
        # A single flat list is the natural spelling for one parameter.
        gl = (np == 1 && !(first(graw) isa AbstractVector)) ? [graw] : collect(graw)
        length(gl) == np || throw(CliError("config/shape",
            "[determinacy] grids has $(length(gl)) entry/entries but $np parameter(s)"))
        for (i, g) in enumerate(gl)
            g isa AbstractVector || throw(CliError("config/type",
                "[determinacy] grids[$i] must be a list of numbers"))
            vals = Float64[]
            for v in g
                v isa Real || throw(CliError("config/type",
                    "[determinacy] grids[$i] must contain numbers, got $(typeof(v))"))
                push!(vals, Float64(v))
            end
            length(vals) >= 2 || throw(CliError("config/invalid",
                "[determinacy] grids[$i] needs at least 2 values (got $(length(vals)))"))
            push!(grids, vals)
        end
    else
        lo = _aslist(get(sec, "lower", nothing))
        hi = _aslist(get(sec, "upper", nothing))
        (lo == [nothing] || hi == [nothing]) && throw(CliError("config/missing-key",
            "[determinacy] needs lower and upper (or an explicit grids list)"))
        length(lo) == np || throw(CliError("config/shape",
            "[determinacy] lower has $(length(lo)) entry/entries but $np parameter(s)"))
        length(hi) == np || throw(CliError("config/shape",
            "[determinacy] upper has $(length(hi)) entry/entries but $np parameter(s)"))
        praw_n = get(sec, "points", 41)
        pts = praw_n isa AbstractVector ? collect(praw_n) : fill(praw_n, np)
        length(pts) == np || throw(CliError("config/shape",
            "[determinacy] points has $(length(pts)) entry/entries but $np parameter(s)"))
        for i in 1:np
            (lo[i] isa Real && hi[i] isa Real) || throw(CliError("config/type",
                "[determinacy] lower/upper entries must be numbers"))
            pts[i] isa Integer || throw(CliError("config/type",
                "[determinacy] points entries must be integers"))
            Float64(lo[i]) < Float64(hi[i]) || throw(CliError("config/invalid",
                "[determinacy] lower[$i] must be < upper[$i] (got $(lo[i]) ≥ $(hi[i]))"))
            Int(pts[i]) >= 2 || throw(CliError("config/invalid",
                "[determinacy] points[$i] must be ≥ 2 (got $(pts[i]))"))
            push!(grids, collect(range(Float64(lo[i]), Float64(hi[i]); length=Int(pts[i]))))
        end
    end

    meth = String(get(sec, "method", "gensys"))
    meth in ("gensys", "klein", "blanchard-kahn", "blanchard_kahn") ||
        throw(CliError("config/invalid",
            "[determinacy] method must be gensys|klein|blanchard-kahn, got '$meth'"))

    divv = get(sec, "div", 1.0 + 1e-8)
    divv isa Real || throw(CliError("config/type", "[determinacy] div must be a number"))
    Float64(divv) > 0 || throw(CliError("config/invalid",
        "[determinacy] div must be > 0 (got $divv)"))

    return (params=params, grids=grids, method=Symbol(replace(meth, '-' => '_')),
            div=Float64(divv))
end

# ── W4/#126: policy-counterfactual rule & loss schemas (MEMs 0.8.0 CF module) ──

const _POLICY_RULE_TYPES = ("rate-peg", "rate-target", "inflation-target",
                            "output-gap", "ngdp", "taylor")

"""
    get_policy_rule(config::Dict) → NamedTuple

Parse a `[rule]` section into a validated rule spec. The actual `PolicyRule` is
built later (`_build_policy_rule`) because the truncation horizon `H` comes from
the command line, not the TOML.

Traps this schema exists to defuse (each ships a wrong number if misread):
- `taylor` WITHOUT parameters uses upstream's TEXTBOOK defaults
  (ρ=0.5, φπ=1.5, φy=1.0) — NOT the Caravello–McKay–Wolf calibration.
  `cmw = true` sets ρ=0.85, φπ=2.0, φy=0.25 and REFUSES to combine with
  explicit ρ/φ entries (a half-override is neither rule).
- Rules are stabilization around the model's FIXED steady state — a different
  inflation-target *level* is out of scope by construction.
"""
function get_policy_rule(config::Dict)
    sec = get(config, "rule", Dict())
    isempty(sec) && throw(CliError("config/missing-key",
        "TOML must have a [rule] section";
        hint="e.g. type = \"taylor\", cmw = true"))

    rtype = String(get(sec, "type", ""))
    rtype in _POLICY_RULE_TYPES || throw(CliError("config/invalid",
        "[rule] type must be one of $(join(_POLICY_RULE_TYPES, "|")), got '$rtype'"))

    _syms(key, default) = begin
        raw = get(sec, key, default)
        raw isa AbstractVector || throw(CliError("config/type",
            "[rule] $key must be a list of variable names"))
        out = Symbol[]
        for v in raw
            v isa AbstractString || throw(CliError("config/type",
                "[rule] $key entries must be strings, got $(typeof(v))"))
            push!(out, Symbol(v))
        end
        isempty(out) && throw(CliError("config/invalid", "[rule] $key must not be empty"))
        out
    end
    outcomes = _syms("outcomes", ["infl", "ygap"])
    instruments = _syms("instruments", ["rate"])

    _num(key, default) = begin
        v = get(sec, key, default)
        v isa Real || throw(CliError("config/type", "[rule] $key must be a number"))
        Float64(v)
    end
    pi_var = Symbol(String(get(sec, "pi_var", "infl")))
    y_var = Symbol(String(get(sec, "y_var", "ygap")))

    params = if rtype == "taylor"
        cmw = get(sec, "cmw", false)
        cmw isa Bool || throw(CliError("config/type", "[rule] cmw must be true/false"))
        explicit = [k for k in ("rho", "phi_pi", "phi_y") if haskey(sec, k)]
        if cmw
            isempty(explicit) || throw(CliError("config/invalid",
                "[rule] cmw = true sets rho/phi_pi/phi_y itself; remove $(join(explicit, ", ")) (a half-override is neither rule)"))
            (rho=0.85, phi_pi=2.0, phi_y=0.25, z_lag=_num("z_lag", 0.0),
             pi_var=pi_var, y_var=y_var)
        else
            # Upstream's TEXTBOOK defaults — deliberately restated here so the
            # schema, not the reader's memory, owns them.
            (rho=_num("rho", 0.5), phi_pi=_num("phi_pi", 1.5),
             phi_y=_num("phi_y", 1.0), z_lag=_num("z_lag", 0.0),
             pi_var=pi_var, y_var=y_var)
        end
    elseif rtype == "rate-target"
        praw = get(sec, "path", nothing)
        praw isa AbstractVector || throw(CliError("config/missing-key",
            "[rule] type = \"rate-target\" needs path = [..] (the instrument path, length H)"))
        path = Float64[]
        for v in praw
            v isa Real || throw(CliError("config/type",
                "[rule] path must contain numbers, got $(typeof(v))"))
            push!(path, Float64(v))
        end
        (path=path,)
    elseif rtype == "inflation-target"
        (pi_var=pi_var,)
    elseif rtype == "output-gap"
        (y_var=y_var,)
    elseif rtype == "ngdp"
        pi_var == y_var && throw(CliError("config/invalid",
            "[rule] ngdp needs distinct pi_var and y_var (both are '$pi_var')"))
        (pi_var=pi_var, y_var=y_var)
    else  # rate-peg
        NamedTuple()
    end

    return (type=Symbol(replace(rtype, '-' => '_')), outcomes=outcomes,
            instruments=instruments, params=params)
end

"""
    get_policy_loss(config::Dict) → NamedTuple

Parse a `[loss]` section into a validated loss spec (built with `H` later).

- **`lambda` is REQUIRED for the diagonal loss** — upstream `policy_loss` has no
  default, and silently assuming 1.0 changes every optimal-policy result.
- `type = "ait"` (average-inflation targeting) defaults `beta` to `1/1.01`
  (≈0.990099, the McKay–Wolf `set_polpref.m` replication value — NOT 0.99), and
  its defaults do NOT reproduce the paper-text λπ = λy = 1.
- `[loss.smoothing]` is the `smoothing_penalty` builder: it returns a NamedTuple
  whose `.W_z` feeds `policy_loss(W_z=…)` and whose `.wedge_term` feeds the
  engines' `z_wedge=` — the loader records it as one unit so handlers cannot
  split it wrong.
"""
function get_policy_loss(config::Dict)
    sec = get(config, "loss", Dict())
    isempty(sec) && throw(CliError("config/missing-key",
        "TOML must have a [loss] section";
        hint="e.g. outcomes = [\"infl\", \"ygap\"], lambda = [1.0, 0.5]"))

    ltype = String(get(sec, "type", "diagonal"))
    ltype in ("diagonal", "ait") || throw(CliError("config/invalid",
        "[loss] type must be diagonal|ait, got '$ltype'"))

    _num(key, default) = begin
        v = get(sec, key, default)
        v isa Real || throw(CliError("config/type", "[loss] $key must be a number"))
        Float64(v)
    end

    smoothing = nothing
    if haskey(sec, "smoothing")
        sm = sec["smoothing"]
        sm isa AbstractDict || throw(CliError("config/type",
            "[loss.smoothing] must be a table (lambda/beta/z_lag)"))
        _smnum(key, default) = begin
            v = get(sm, key, default)
            v isa Real || throw(CliError("config/type",
                "[loss.smoothing] $key must be a number"))
            Float64(v)
        end
        sl = _smnum("lambda", 1.0)
        sl > 0 || throw(CliError("config/invalid",
            "[loss.smoothing] lambda must be > 0 (got $sl)"))
        sb = _smnum("beta", 1.0)
        (0 < sb <= 1) || throw(CliError("config/invalid",
            "[loss.smoothing] beta must be in (0, 1] (got $sb)"))
        smoothing = (lambda=sl, beta=sb, z_lag=_smnum("z_lag", 0.0))
    end

    if ltype == "ait"
        beta = _num("beta", 1 / 1.01)
        (0 < beta <= 1) || throw(CliError("config/invalid",
            "[loss] beta must be in (0, 1] (got $beta)"))
        K = get(sec, "K", 19)
        K isa Integer || throw(CliError("config/type", "[loss] K must be an integer"))
        K >= 1 || throw(CliError("config/invalid", "[loss] K must be ≥ 1 (got $K)"))
        pi_var = Symbol(String(get(sec, "pi_var", "infl")))
        y_var = Symbol(String(get(sec, "y_var", "ygap")))
        pi_var == y_var && throw(CliError("config/invalid",
            "[loss] ait needs distinct pi_var and y_var (both are '$pi_var')"))
        return (type=:ait, beta=beta,
                lambda_avg=_num("lambda_avg", 0.6), lambda_t=_num("lambda_t", 0.4),
                lambda_y=_num("lambda_y", 1.0), delta=_num("delta", 0.1), K=Int(K),
                pi_var=pi_var, y_var=y_var, smoothing=smoothing)
    end

    oraw = get(sec, "outcomes", nothing)
    oraw isa AbstractVector || throw(CliError("config/missing-key",
        "[loss] must set outcomes = [..] (the loss variables)"))
    outcomes = Symbol[]
    for v in oraw
        v isa AbstractString || throw(CliError("config/type",
            "[loss] outcomes entries must be strings, got $(typeof(v))"))
        push!(outcomes, Symbol(v))
    end
    isempty(outcomes) && throw(CliError("config/invalid", "[loss] outcomes must not be empty"))

    # REQUIRED — upstream policy_loss has no default and defaulting silently
    # to 1.0 would change every result.
    lraw = get(sec, "lambda", nothing)
    lraw isa AbstractVector || throw(CliError("config/missing-key",
        "[loss] must set lambda = [..], one weight per outcome (upstream has NO default)"))
    lambda = Float64[]
    for v in lraw
        v isa Real || throw(CliError("config/type",
            "[loss] lambda must contain numbers, got $(typeof(v))"))
        push!(lambda, Float64(v))
    end
    length(lambda) == length(outcomes) || throw(CliError("config/shape",
        "[loss] lambda has $(length(lambda)) entries but $(length(outcomes)) outcomes"))
    all(>=(0), lambda) || throw(CliError("config/invalid",
        "[loss] lambda weights must be ≥ 0"))

    beta = _num("beta", 1.0)
    (0 < beta <= 1) || throw(CliError("config/invalid",
        "[loss] beta must be in (0, 1] (got $beta)"))

    return (type=:diagonal, outcomes=outcomes, lambda=lambda, beta=beta,
            smoothing=smoothing)
end

"""
    get_opp_constraints(config::Dict) → Vector{NamedTuple}

Parse `[[constraint]]` tables for `constrained_opp` (W6/#128). Covers the
path-floor family (`zlb_constraint`); `FunctionConstraint` takes a Julia
closure and is closure-gated (W8) — a `type = "function"` entry is refused
with a pointer rather than silently ignored.
"""
function get_opp_constraints(config::Dict)
    raw = get(config, "constraint", nothing)
    raw isa AbstractVector || throw(CliError("config/missing-key",
        "TOML must have [[constraint]] tables";
        hint="e.g. [[constraint]]\\ntype = \"floor\"\\nfloor = 0.0\\ninstrument = \"rate\""))
    out = NamedTuple[]
    for (i, c) in enumerate(raw)
        c isa AbstractDict || throw(CliError("config/type",
            "[[constraint]] #$i must be a table"))
        ctype = String(get(c, "type", "floor"))
        ctype == "function" && throw(CliError("config/invalid",
            "[[constraint]] #$i: type = \"function\" needs a Julia closure — closure-taking constraints are not scriptable from TOML (see the v0.9.2 W8 decision record)"))
        ctype in ("floor", "zlb") || throw(CliError("config/invalid",
            "[[constraint]] #$i: type must be floor|zlb (got '$ctype')"))
        fl = get(c, "floor", 0.0)
        fl isa Real || throw(CliError("config/type",
            "[[constraint]] #$i: floor must be a number"))
        inst = get(c, "instrument", "rate")
        inst isa AbstractString || throw(CliError("config/type",
            "[[constraint]] #$i: instrument must be a string"))
        hraw = get(c, "horizons", "all")
        horizons = if hraw isa AbstractString
            s = String(strip(hraw))
            if s == "all"
                1:typemax(Int)
            else
                m = match(r"^(\d+):(\d+)$", s)
                m === nothing && throw(CliError("config/invalid",
                    "[[constraint]] #$i: horizons must be \"all\" or \"lo:hi\" (got '$s')"))
                lo, hi = parse(Int, m[1]), parse(Int, m[2])
                (1 <= lo <= hi) || throw(CliError("config/invalid",
                    "[[constraint]] #$i: horizons needs 1 ≤ lo ≤ hi (got $s)"))
                lo:hi
            end
        else
            throw(CliError("config/type",
                "[[constraint]] #$i: horizons must be a string (\"all\" or \"lo:hi\")"))
        end
        push!(out, (type=:floor, floor=Float64(fl), instrument=Symbol(inst),
                    horizons=horizons))
    end
    isempty(out) && throw(CliError("config/invalid",
        "at least one [[constraint]] table is required"))
    return out
end

# ── [svar_hypothesis] TOML parser ([MEM111-W3] #315) ───────────────────────

const _SVAR_HYP_TYPE_MAP = Dict{String,String}(
    "recursiveness" => "recursiveness",
    "impact_zero"   => "impact_zero",
    "impact-zero"   => "impact_zero",
    "impact_linear" => "impact_linear",
    "impact-linear" => "impact_linear",
    "long_run"      => "long_run",
    "long-run"      => "long_run",
    "horizon_irf"   => "horizon_irf",
    "horizon-irf"   => "horizon_irf",
    "mixed"         => "mixed",
)

function _parse_svar_hyp_ordering(raw, ctx::String)
    raw === nothing && return nothing
    if raw isa AbstractString
        s = lowercase(strip(String(raw)))
        s == "canonical" && return :canonical
        (s == "best_match" || s == "best-match") && return :best_match
        throw(CliError("config/invalid",
            "$ctx.ordering must be \"canonical\", \"best_match\", or a permutation array of 1..n (got '$raw')"))
    elseif raw isa Symbol
        raw in (:canonical, :best_match) && return raw
        throw(CliError("config/invalid",
            "$ctx.ordering must be :canonical, :best_match, or a permutation array (got :$raw)"))
    elseif raw isa AbstractVector
        isempty(raw) && throw(CliError("config/invalid",
            "$ctx.ordering permutation array must not be empty"))
        ord = Int[]
        for v in raw
            (v isa Integer && !(v isa Bool) && v >= 1) || throw(CliError("config/invalid",
                "$ctx.ordering must hold positive integers 1..n (got $v)"))
            push!(ord, Int(v))
        end
        sort(ord) == collect(1:length(ord)) || throw(CliError("config/invalid",
            "$ctx.ordering must be a permutation of 1:$(length(ord)) (got $ord)"))
        return ord
    end
    throw(CliError("config/invalid",
        "$ctx.ordering must be \"canonical\", \"best_match\", or a permutation array (got $(typeof(raw)))"))
end

function _parse_svar_hyp_pairs(raw, ctx::String)
    (raw isa AbstractVector && !isempty(raw)) || throw(CliError("config/invalid",
        "$ctx.zeros must be a non-empty array of [var, shock] index pairs"))
    pairs = Tuple{Int,Int}[]
    for (idx, item) in enumerate(raw)
        (item isa AbstractVector && length(item) == 2) || throw(CliError("config/invalid",
            "$ctx.zeros[$idx] must be a 2-element [var, shock] array (got $item)"))
        a, b = item[1], item[2]
        (a isa Integer && !(a isa Bool) && a >= 1 &&
         b isa Integer && !(b isa Bool) && b >= 1) || throw(CliError("config/invalid",
            "$ctx.zeros[$idx] must hold positive integers [var, shock] (got $item)"))
        push!(pairs, (Int(a), Int(b)))
    end
    length(unique(pairs)) == length(pairs) || throw(CliError("config/invalid",
        "$ctx.zeros contains duplicate [var, shock] entries"))
    return pairs
end

function _parse_svar_hyp_linear(tbl::AbstractDict, ctx::String)
    haskey(tbl, "R") || throw(CliError("config/invalid",
        "$ctx requires matrix `R` for impact_linear hypothesis"))
    raw_R = tbl["R"]
    (raw_R isa AbstractVector && !isempty(raw_R)) || throw(CliError("config/invalid",
        "$ctx.R must be a non-empty 2D array of finite numbers"))
    nrows = length(raw_R)
    first_row = raw_R[1]
    (first_row isa AbstractVector && !isempty(first_row)) || throw(CliError("config/invalid",
        "$ctx.R rows must be non-empty numeric arrays"))
    ncols = length(first_row)
    R = Matrix{Float64}(undef, nrows, ncols)
    for (i, row) in enumerate(raw_R)
        (row isa AbstractVector && length(row) == ncols) || throw(CliError("config/invalid",
            "$ctx.R row $i has length $(row isa AbstractVector ? length(row) : -1), expected $ncols"))
        for (j, v) in enumerate(row)
            (v isa Real && !(v isa Bool) && isfinite(v)) || throw(CliError("config/invalid",
                "$ctx.R[$i,$j] must be a finite number (got $v)"))
            R[i, j] = Float64(v)
        end
    end
    r = if haskey(tbl, "r") && tbl["r"] !== nothing
        raw_r = tbl["r"]
        (raw_r isa AbstractVector && length(raw_r) == nrows) || throw(CliError("config/invalid",
            "$ctx.r must be a numeric array of length $nrows (matching rows of R)"))
        out_r = Vector{Float64}(undef, nrows)
        for (i, v) in enumerate(raw_r)
            (v isa Real && !(v isa Bool) && isfinite(v)) || throw(CliError("config/invalid",
                "$ctx.r[$i] must be a finite number (got $v)"))
            out_r[i] = Float64(v)
        end
        out_r
    else
        zeros(Float64, nrows)
    end
    return R, r
end

function _parse_svar_hyp_horizon(raw, ctx::String)
    (raw isa AbstractVector && !isempty(raw)) || throw(CliError("config/invalid",
        "$ctx.restrictions must be a non-empty array of {horizon, var, shock} tables or [h, i, j] triples"))
    out = Tuple{Int,Int,Int}[]
    for (idx, item) in enumerate(raw)
        if item isa AbstractDict
            (haskey(item, "horizon") && haskey(item, "var") && haskey(item, "shock")) ||
                throw(CliError("config/invalid",
                    "$ctx.restrictions[$idx] must specify `horizon`, `var`, and `shock`"))
            h, v, s = item["horizon"], item["var"], item["shock"]
            if haskey(item, "value") && item["value"] !== nothing
                val = item["value"]
                (val isa Real && !(val isa Bool) && isfinite(val)) || throw(CliError("config/invalid",
                    "$ctx.restrictions[$idx].value must be a finite number (got $val)"))
                Float64(val) == 0.0 || throw(CliError("config/invalid",
                    "$ctx.restrictions[$idx].value must be 0.0 (upstream horizon_irf_hypothesis imposes zero restrictions, got $val)"))
            end
        elseif item isa AbstractVector && length(item) == 3
            h, v, s = item[1], item[2], item[3]
        else
            throw(CliError("config/invalid",
                "$ctx.restrictions[$idx] must be a {horizon, var, shock} table or 3-element [h, i, j] array"))
        end
        (h isa Integer && !(h isa Bool) && h >= 0) || throw(CliError("config/invalid",
            "$ctx.restrictions[$idx] horizon must be an integer ≥ 0 (got $h)"))
        (v isa Integer && !(v isa Bool) && v >= 1) || throw(CliError("config/invalid",
            "$ctx.restrictions[$idx] var must be an integer ≥ 1 (got $v)"))
        (s isa Integer && !(s isa Bool) && s >= 1) || throw(CliError("config/invalid",
            "$ctx.restrictions[$idx] shock must be an integer ≥ 1 (got $s)"))
        push!(out, (Int(h), Int(v), Int(s)))
    end
    length(unique(out)) == length(out) || throw(CliError("config/invalid",
        "$ctx.restrictions contains duplicate (horizon, var, shock) entries"))
    return out
end

function _parse_svar_hyp_short_run(sr::AbstractDict, parent_ord, ctx::String)
    ord = haskey(sr, "ordering") ? _parse_svar_hyp_ordering(sr["ordering"], ctx) : parent_ord
    explicit_type = haskey(sr, "type") ? lowercase(strip(string(sr["type"]))) : ""
    is_rec = get(sr, "recursiveness", false) === true || explicit_type == "recursiveness"
    has_zeros = haskey(sr, "zeros")
    has_R = haskey(sr, "R")
    n_modes = Int(is_rec) + Int(has_zeros) + Int(has_R)
    n_modes == 1 || throw(CliError("config/invalid",
        "$ctx must specify exactly one of `recursiveness = true`, `zeros`, or `R`"))
    if is_rec
        return Dict{String,Any}("type" => "recursiveness", "ordering" => ord)
    elseif has_zeros
        return Dict{String,Any}("type" => "impact_zero", "ordering" => ord,
                                "zeros" => _parse_svar_hyp_pairs(sr["zeros"], ctx))
    else
        R, r = _parse_svar_hyp_linear(sr, ctx)
        return Dict{String,Any}("type" => "impact_linear", "ordering" => ord, "R" => R, "r" => r)
    end
end

"""
    get_svar_hypothesis(config::Dict) → Dict{String,Any}

Parse a `[svar_hypothesis]` TOML stanza for `test multivariate svar-hypothesis`.
Supports all 6 structured restriction types (`recursiveness`, `impact_zero`,
`impact_linear`, `long_run`, `horizon_irf`, `mixed`), throwing typed
`CliError("config/invalid", ...)` on any malformed specification.
"""
function get_svar_hypothesis(config::Dict)
    haskey(config, "svar_hypothesis") || throw(CliError("config/invalid",
        "TOML config must contain a [svar_hypothesis] table";
        hint="add `[svar_hypothesis]` with `type = \"recursiveness\"|\"impact_zero\"|\"impact_linear\"|\"long_run\"|\"horizon_irf\"|\"mixed\"`"))
    sh = config["svar_hypothesis"]
    sh isa AbstractDict || throw(CliError("config/invalid",
        "[svar_hypothesis] must be a table (got $(typeof(sh)))"))
    haskey(sh, "type") || throw(CliError("config/invalid",
        "[svar_hypothesis] missing required `type` key";
        hint="set type = \"recursiveness\"|\"impact_zero\"|\"impact_linear\"|\"long_run\"|\"horizon_irf\"|\"mixed\""))
    raw_type = lowercase(strip(string(sh["type"])))
    haskey(_SVAR_HYP_TYPE_MAP, raw_type) || throw(CliError("config/invalid",
        "[svar_hypothesis].type must be recursiveness|impact_zero|impact_linear|long_run|horizon_irf|mixed (got '$(sh["type"])')"))
    htype = _SVAR_HYP_TYPE_MAP[raw_type]
    ord = haskey(sh, "ordering") ? _parse_svar_hyp_ordering(sh["ordering"], "[svar_hypothesis]") : nothing

    if htype == "recursiveness"
        return Dict{String,Any}("type" => "recursiveness", "ordering" => ord)
    elseif htype == "impact_zero"
        haskey(sh, "zeros") || throw(CliError("config/invalid",
            "[svar_hypothesis] impact_zero requires `zeros = [[i, j], ...]`"))
        return Dict{String,Any}("type" => "impact_zero", "ordering" => ord,
                                "zeros" => _parse_svar_hyp_pairs(sh["zeros"], "[svar_hypothesis]"))
    elseif htype == "impact_linear"
        R, r = _parse_svar_hyp_linear(sh, "[svar_hypothesis]")
        return Dict{String,Any}("type" => "impact_linear", "ordering" => ord, "R" => R, "r" => r)
    elseif htype == "long_run"
        haskey(sh, "zeros") || throw(CliError("config/invalid",
            "[svar_hypothesis] long_run requires `zeros = [[i, j], ...]`"))
        return Dict{String,Any}("type" => "long_run", "ordering" => ord,
                                "zeros" => _parse_svar_hyp_pairs(sh["zeros"], "[svar_hypothesis]"))
    elseif htype == "horizon_irf"
        haskey(sh, "restrictions") || throw(CliError("config/invalid",
            "[svar_hypothesis] horizon_irf requires `restrictions = [{horizon=h, var=i, shock=j}, ...]`"))
        return Dict{String,Any}("type" => "horizon_irf", "ordering" => ord,
                                "restrictions" => _parse_svar_hyp_horizon(sh["restrictions"], "[svar_hypothesis]"))
    else # "mixed"
        sr_raw = get(sh, "short_run", nothing)
        lr_raw = get(sh, "long_run", nothing)
        hz_raw = get(sh, "horizon", nothing)
        (sr_raw === nothing && lr_raw === nothing && hz_raw === nothing) && throw(CliError(
            "config/invalid",
            "[svar_hypothesis] mixed requires at least one of `short_run`, `long_run`, or `horizon` sub-tables"))
        sr = if sr_raw === nothing
            nothing
        else
            sr_raw isa AbstractDict || throw(CliError("config/invalid",
                "[svar_hypothesis.short_run] must be a table"))
            _parse_svar_hyp_short_run(sr_raw, ord, "[svar_hypothesis.short_run]")
        end
        lr = if lr_raw === nothing
            nothing
        else
            lr_raw isa AbstractDict || throw(CliError("config/invalid",
                "[svar_hypothesis.long_run] must be a table"))
            haskey(lr_raw, "zeros") || throw(CliError("config/invalid",
                "[svar_hypothesis.long_run] requires `zeros = [[i, j], ...]`"))
            lr_ord = haskey(lr_raw, "ordering") ?
                _parse_svar_hyp_ordering(lr_raw["ordering"], "[svar_hypothesis.long_run]") : ord
            Dict{String,Any}("type" => "long_run", "ordering" => lr_ord,
                             "zeros" => _parse_svar_hyp_pairs(lr_raw["zeros"], "[svar_hypothesis.long_run]"))
        end
        hz = if hz_raw === nothing
            nothing
        else
            hz_raw isa AbstractDict || throw(CliError("config/invalid",
                "[svar_hypothesis.horizon] must be a table"))
            haskey(hz_raw, "restrictions") || throw(CliError("config/invalid",
                "[svar_hypothesis.horizon] requires `restrictions`"))
            hz_ord = haskey(hz_raw, "ordering") ?
                _parse_svar_hyp_ordering(hz_raw["ordering"], "[svar_hypothesis.horizon]") : ord
            Dict{String,Any}("type" => "horizon_irf", "ordering" => hz_ord,
                             "restrictions" => _parse_svar_hyp_horizon(hz_raw["restrictions"], "[svar_hypothesis.horizon]"))
        end
        return Dict{String,Any}("type" => "mixed", "ordering" => ord,
                                "short_run" => sr, "long_run" => lr, "horizon" => hz)
    end
end

# ── Rational Inattention TOML parsers ([MEM111-W5] #317) ────────────────────

function _ri_parse_mat(val, label::String; allow_scalar::Bool=true, allow_vec::Bool=false)
    if allow_scalar && val isa Real
        f = Float64(val)
        isfinite(f) || throw(CliError("config/invalid", "$label must be finite, got $val"))
        return fill(f, 1, 1)
    elseif allow_vec && val isa AbstractVector && !isempty(val) && all(x -> x isa Real, val)
        v = Float64[Float64(x) for x in val]
        all(isfinite, v) || throw(CliError("config/invalid", "$label contains non-finite values"))
        return reshape(v, :, 1)
    elseif val isa AbstractVector && !isempty(val) && all(r -> r isa AbstractVector, val)
        ncol = length(first(val))
        (ncol >= 1 && all(r -> length(r) == ncol, val)) ||
            throw(CliError("config/shape", "$label rows must all have equal length ≥ 1"))
        mat = try
            Float64[Float64(val[i][j]) for i in 1:length(val), j in 1:ncol]
        catch
            throw(CliError("config/type", "$label must contain only numbers"))
        end
        all(isfinite, mat) || throw(CliError("config/invalid", "$label contains non-finite values"))
        return mat
    end
    throw(CliError("config/type",
        "$label must be a row-major numeric matrix" *
        (allow_scalar ? " (or scalar)" : "") *
        (allow_vec ? " (or vector)" : "")))
end

function _ri_parse_vec(val, label::String)
    (val isa AbstractVector && !isempty(val) && all(x -> x isa Real, val)) ||
        throw(CliError("config/type", "$label must be a non-empty array of numbers"))
    v = Float64[Float64(x) for x in val]
    all(isfinite, v) || throw(CliError("config/invalid", "$label contains non-finite values"))
    return v
end

function _ri_parse_strvec(val, label::String, expected_len::Int)
    (val isa AbstractVector && all(x -> x isa AbstractString, val)) ||
        throw(CliError("config/type", "$label must be an array of strings"))
    length(val) == expected_len || throw(CliError("config/shape",
        "$label must have length $expected_len, got $(length(val))"))
    return String[String(x) for x in val]
end

function _ri_parse_units(sec::AbstractDict, prefix::String, default::Symbol=:bits)
    haskey(sec, "units") || return default
    u = sec["units"]
    u isa AbstractString || throw(CliError("config/type", "$prefix units must be a string (bits|nats)"))
    String(u) in ("bits", "nats") || throw(CliError("config/invalid",
        "$prefix units must be bits or nats, got '$u'"))
    return Symbol(String(u))
end

function _ri_parse_pos_opt(sec::AbstractDict, key::String, prefix::String; allow_zero::Bool=false)
    haskey(sec, key) || return nothing
    v = sec[key]
    v isa Real || throw(CliError("config/type", "$prefix $key must be a number"))
    f = Float64(v)
    ok = allow_zero ? (isfinite(f) && f >= 0.0) : (isfinite(f) && f > 0.0)
    ok || throw(CliError("config/invalid",
        "$prefix $key must be finite and $(allow_zero ? "≥ 0" : "> 0"), got $f"))
    return f
end

function _ri_parse_path_opt(sec::AbstractDict, key::String, prefix::String; allow_zero::Bool=false)
    haskey(sec, key) || return nothing
    raw = sec[key]
    if raw isa Real
        f = Float64(raw)
        ok = allow_zero ? (isfinite(f) && f >= 0.0) : (isfinite(f) && f > 0.0)
        ok || throw(CliError("config/invalid",
            "$prefix $key must be finite and $(allow_zero ? "≥ 0" : "> 0"), got $f"))
        return f
    elseif raw isa AbstractVector && !isempty(raw) && all(x -> x isa Real, raw)
        v = Float64[Float64(x) for x in raw]
        ok = allow_zero ? all(x -> isfinite(x) && x >= 0.0, v) : all(x -> isfinite(x) && x > 0.0, v)
        ok || throw(CliError("config/invalid",
            "$prefix $key entries must be finite and $(allow_zero ? "≥ 0" : "> 0")"))
        return v
    end
    throw(CliError("config/type", "$prefix $key must be a number or non-empty numeric array"))
end

"""
    get_ri_problem(config::Dict) -> NamedTuple

Parse a `[ri]` section describing an LQG Rational Inattention tracking problem
(`A`, `B`, `H`, optional `M`, `B_u`, `beta`, `capacity`/`omega`, `units`,
`state_names`, `action_names`, `shock_names`, and optional dynamic transition
fields `Sigma_init`, `omega_path`, `capacity_path`).
"""
function get_ri_problem(config::Dict)
    sec = get(config, "ri", nothing)
    sec isa AbstractDict || throw(CliError("config/missing",
        "RI command requires a [ri] section with A, B, and H"))

    haskey(sec, "A") || throw(CliError("config/missing-key", "[ri] must define A (n×n transition matrix or scalar)"))
    haskey(sec, "B") || throw(CliError("config/missing-key", "[ri] must define B (n×m shock loading matrix, vector, or scalar)"))
    haskey(sec, "H") || throw(CliError("config/missing-key", "[ri] must define H (n×d action target loading matrix, vector, or scalar)"))

    A = _ri_parse_mat(sec["A"], "[ri] A"; allow_scalar=true, allow_vec=false)
    n = size(A, 1)
    size(A, 2) == n || throw(CliError("config/shape",
        "[ri] A must be square n×n, got $(size(A))"))

    B = _ri_parse_mat(sec["B"], "[ri] B"; allow_scalar=true, allow_vec=true)
    size(B, 1) == n || throw(CliError("config/shape",
        "[ri] B must have n=$n rows to match A, got $(size(B))"))
    m = size(B, 2)

    H = _ri_parse_mat(sec["H"], "[ri] H"; allow_scalar=true, allow_vec=true)
    size(H, 1) == n || throw(CliError("config/shape",
        "[ri] H must have n=$n rows to match A, got $(size(H))"))
    d = size(H, 2)

    M = if haskey(sec, "M")
        Mmat = _ri_parse_mat(sec["M"], "[ri] M"; allow_scalar=(d == 1), allow_vec=false)
        size(Mmat) == (d, d) || throw(CliError("config/shape",
            "[ri] M must be d×d = ($d, $d) to match H, got $(size(Mmat))"))
        Mmat
    else
        nothing
    end

    B_u = if haskey(sec, "B_u")
        Bumat = _ri_parse_mat(sec["B_u"], "[ri] B_u"; allow_scalar=(n == 1 && d == 1), allow_vec=(d == 1))
        size(Bumat) == (n, d) || throw(CliError("config/shape",
            "[ri] B_u must be n×d = ($n, $d) to match A and H, got $(size(Bumat))"))
        Bumat
    else
        nothing
    end

    beta = if haskey(sec, "beta")
        b = sec["beta"]
        b isa Real || throw(CliError("config/type", "[ri] beta must be a number"))
        bf = Float64(b)
        (isfinite(bf) && 0.0 < bf <= 1.0) || throw(CliError("config/invalid",
            "[ri] beta must lie in (0, 1], got $bf"))
        bf
    else
        1.0
    end

    capacity = _ri_parse_pos_opt(sec, "capacity", "[ri]")
    omega = _ri_parse_pos_opt(sec, "omega", "[ri]")
    (capacity !== nothing && omega !== nothing) && throw(CliError("config/invalid",
        "[ri] specify at most one of capacity or omega (mutually exclusive)"))

    units = _ri_parse_units(sec, "[ri]")
    state_names = haskey(sec, "state_names") ? _ri_parse_strvec(sec["state_names"], "[ri] state_names", n) : nothing
    action_names = haskey(sec, "action_names") ? _ri_parse_strvec(sec["action_names"], "[ri] action_names", d) : nothing
    shock_names = haskey(sec, "shock_names") ? _ri_parse_strvec(sec["shock_names"], "[ri] shock_names", m) : nothing

    Sigma_init = if haskey(sec, "Sigma_init")
        S0 = _ri_parse_mat(sec["Sigma_init"], "[ri] Sigma_init"; allow_scalar=(n == 1), allow_vec=false)
        size(S0) == (n, n) || throw(CliError("config/shape",
            "[ri] Sigma_init must be n×n = ($n, $n) to match A, got $(size(S0))"))
        S0
    else
        nothing
    end

    omega_path = _ri_parse_path_opt(sec, "omega_path", "[ri]"; allow_zero=false)
    capacity_path = _ri_parse_path_opt(sec, "capacity_path", "[ri]"; allow_zero=true)
    (omega_path !== nothing && capacity_path !== nothing) && throw(CliError("config/invalid",
        "[ri] omega_path and capacity_path are mutually exclusive"))

    return (A=A, B=B, H=H, M=M, B_u=B_u, beta=beta,
            capacity=capacity, omega=omega, units=units,
            state_names=state_names, action_names=action_names, shock_names=shock_names,
            Sigma_init=Sigma_init, omega_path=omega_path, capacity_path=capacity_path,
            n=n, m=m, d=d)
end

function _ri_parse_mw_block(blk, label::String, default_units::Symbol)
    blk isa AbstractDict || throw(CliError("config/type", "$label must be a TOML table"))
    beta = if haskey(blk, "beta")
        b = blk["beta"]
        b isa Real || throw(CliError("config/type", "$label beta must be a number"))
        bf = Float64(b)
        (isfinite(bf) && 0.0 < bf <= 1.0) || throw(CliError("config/invalid",
            "$label beta must lie in (0, 1], got $bf"))
        bf
    else
        0.99
    end
    units = _ri_parse_units(blk, label, default_units)
    if haskey(blk, "A")
        A = _ri_parse_mat(blk["A"], "$label A"; allow_scalar=true, allow_vec=false)
        n = size(A, 1)
        size(A, 2) == n || throw(CliError("config/shape", "$label A must be square, got $(size(A))"))
        haskey(blk, "H") || throw(CliError("config/missing-key", "$label matrix block must define H"))
        H = _ri_parse_mat(blk["H"], "$label H"; allow_scalar=true, allow_vec=true)
        size(H, 1) == n || throw(CliError("config/shape", "$label H must have n=$n rows, got $(size(H))"))
        size(H, 2) == 1 || throw(CliError("config/shape", "$label H must have 1 column (scalar target), got $(size(H, 2))"))
        M_val = if haskey(blk, "M")
            _ri_parse_mat(blk["M"], "$label M"; allow_scalar=true, allow_vec=false)
        elseif haskey(blk, "weight")
            fill(_ri_parse_pos_opt(blk, "weight", label)::Float64, 1, 1)
        else
            ones(Float64, 1, 1)
        end
        if haskey(blk, "B")
            B = _ri_parse_mat(blk["B"], "$label B"; allow_scalar=true, allow_vec=true)
            size(B, 1) == n || throw(CliError("config/shape", "$label B must have n=$n rows, got $(size(B))"))
            return (A=A, B=B, H=H, M=M_val, beta=beta, units=units)
        elseif haskey(blk, "Q")
            Q = _ri_parse_mat(blk["Q"], "$label Q"; allow_scalar=true, allow_vec=false)
            if haskey(blk, "G")
                G = _ri_parse_mat(blk["G"], "$label G"; allow_scalar=true, allow_vec=true)
                size(G, 1) == n || throw(CliError("config/shape", "$label G must have n=$n rows, got $(size(G))"))
                return (A=A, G=G, Q=Q, H=H, M=M_val, beta=beta, units=units)
            end
            size(Q) == (n, n) || throw(CliError("config/shape", "$label Q must be $n×$n, got $(size(Q))"))
            return (A=A, Q=Q, H=H, M=M_val, beta=beta, units=units)
        else
            throw(CliError("config/missing-key", "$label matrix block must define B or Q"))
        end
    elseif haskey(blk, "rho") && haskey(blk, "sigma")
        rho_raw = blk["rho"]
        rho = if rho_raw isa Real
            f = Float64(rho_raw)
            isfinite(f) || throw(CliError("config/invalid", "$label rho must be finite"))
            f
        elseif rho_raw isa AbstractVector && length(rho_raw) == 2 && all(x -> x isa Real, rho_raw)
            v = Float64[Float64(x) for x in rho_raw]
            all(isfinite, v) || throw(CliError("config/invalid", "$label rho entries must be finite"))
            v
        else
            throw(CliError("config/type", "$label rho must be a number or 2-element numeric array"))
        end
        sigma = _ri_parse_pos_opt(blk, "sigma", label)::Float64
        weight = haskey(blk, "weight") ? _ri_parse_pos_opt(blk, "weight", label)::Float64 :
                 (haskey(blk, "payoff_weight") ? _ri_parse_pos_opt(blk, "payoff_weight", label)::Float64 : 1.0)
        proc_raw = get(blk, "process", "level")
        proc_raw isa AbstractString || throw(CliError("config/type", "$label process must be a string (level|growth)"))
        String(proc_raw) in ("level", "growth") || throw(CliError("config/invalid",
            "$label process must be level or growth, got '$proc_raw'"))
        return (rho=rho, sigma=sigma, weight=weight, process=Symbol(String(proc_raw)), beta=beta, units=units)
    else
        throw(CliError("config/missing-key",
            "$label must define either (rho, sigma) or matrix fields (A, B|Q, H)"))
    end
end

"""
    get_ri_mw(config::Dict) -> NamedTuple

Parse a `[ri.mw]` section for `ri mw` (Maćkowiak–Wiederholt 2009 multi-block
attention allocation). Requires `[ri.mw.agg_block]` and `[ri.mw.idio_block]`.
"""
function get_ri_mw(config::Dict)
    ri_sec = get(config, "ri", nothing)
    sec = ri_sec isa AbstractDict ? get(ri_sec, "mw", nothing) : nothing
    sec isa AbstractDict || throw(CliError("config/missing",
        "ri mw requires a [ri.mw] section with agg_block and idio_block"))
    haskey(sec, "agg_block") || throw(CliError("config/missing-key",
        "[ri.mw] must define [ri.mw.agg_block]"))
    haskey(sec, "idio_block") || throw(CliError("config/missing-key",
        "[ri.mw] must define [ri.mw.idio_block]"))

    units = _ri_parse_units(sec, "[ri.mw]")
    agg_block = _ri_parse_mw_block(sec["agg_block"], "[ri.mw.agg_block]", units)
    idio_block = _ri_parse_mw_block(sec["idio_block"], "[ri.mw.idio_block]", units)

    capacity = _ri_parse_pos_opt(sec, "capacity", "[ri.mw]")
    omega = _ri_parse_pos_opt(sec, "omega", "[ri.mw]")
    (capacity !== nothing && omega !== nothing) && throw(CliError("config/invalid",
        "[ri.mw] capacity and omega are mutually exclusive"))

    sc = if haskey(sec, "strategic_complementarity")
        v = sec["strategic_complementarity"]
        v isa Real || throw(CliError("config/type", "[ri.mw] strategic_complementarity must be a number"))
        f = Float64(v)
        (isfinite(f) && 0.0 <= f < 1.0) || throw(CliError("config/invalid",
            "[ri.mw] strategic_complementarity must lie in [0, 1), got $f"))
        f
    else
        nothing
    end

    horizon = if haskey(sec, "horizon")
        h = sec["horizon"]
        h isa Integer || throw(CliError("config/type", "[ri.mw] horizon must be an integer"))
        Int(h) >= 1 || throw(CliError("config/invalid", "[ri.mw] horizon must be ≥ 1, got $h"))
        Int(h)
    else
        nothing
    end

    return (agg_block=agg_block, idio_block=idio_block,
            capacity=capacity, omega=omega,
            strategic_complementarity=sc, horizon=horizon)
end

"""
    get_ri_discrete(config::Dict) -> NamedTuple

Parse a `[ri.discrete]` section for `ri discrete` and `ri iia-test`
(Matějka–McKay 2015 discrete-choice RI). Requires `U` (`J × S` payoff matrix)
and `mu` (length-`S` prior vector); optional `new_option_payoffs` (length-`S`),
`omega`/`capacity`, and `units`.
"""
function get_ri_discrete(config::Dict)
    ri_sec = get(config, "ri", nothing)
    sec = ri_sec isa AbstractDict ? get(ri_sec, "discrete", nothing) : nothing
    sec isa AbstractDict || throw(CliError("config/missing",
        "ri discrete / iia-test requires a [ri.discrete] section with U and mu"))
    haskey(sec, "U") || throw(CliError("config/missing-key",
        "[ri.discrete] must define U = [[...], [...]] (J×S payoff matrix)"))
    haskey(sec, "mu") || throw(CliError("config/missing-key",
        "[ri.discrete] must define mu = [...] (length-S prior vector)"))

    U = _ri_parse_mat(sec["U"], "[ri.discrete] U"; allow_scalar=false, allow_vec=false)
    J, S = size(U)
    mu = _ri_parse_vec(sec["mu"], "[ri.discrete] mu")
    length(mu) == S || throw(CliError("config/shape",
        "[ri.discrete] mu must have length S=$S matching columns of U, got $(length(mu))"))
    all(>=(0.0), mu) || throw(CliError("config/invalid",
        "[ri.discrete] mu entries must be non-negative"))
    sum(mu) > 0.0 || throw(CliError("config/invalid",
        "[ri.discrete] mu must have positive sum"))

    new_opt = if haskey(sec, "new_option_payoffs")
        v = _ri_parse_vec(sec["new_option_payoffs"], "[ri.discrete] new_option_payoffs")
        length(v) == S || throw(CliError("config/shape",
            "[ri.discrete] new_option_payoffs must have length S=$S matching columns of U, got $(length(v))"))
        v
    else
        nothing
    end

    omega = _ri_parse_pos_opt(sec, "omega", "[ri.discrete]")
    capacity = _ri_parse_pos_opt(sec, "capacity", "[ri.discrete]")
    (omega !== nothing && capacity !== nothing) && throw(CliError("config/invalid",
        "[ri.discrete] omega and capacity are mutually exclusive"))
    units = _ri_parse_units(sec, "[ri.discrete]")

    return (U=U, mu=mu, new_option_payoffs=new_opt,
            omega=omega, capacity=capacity, units=units, J=J, S=S)
end

"""
    get_ri_logit_config(config::Dict, J::Int, S::Int, M::Int) -> NamedTuple

Parse optional `[ri.logit]` (or `[ri_logit]`) config carrying `priors` (`S × M`
matrix or `"empirical"`) and/or `base_payoff` (`M`-element array of `J × S`
matrices, or `J × S` when `M == 1`) for `estimate/predict choice ri-logit`.
"""
function get_ri_logit_config(config::Dict, J::Int, S::Int, M::Int)
    ri_sec = get(config, "ri", nothing)
    sec = if ri_sec isa AbstractDict && haskey(ri_sec, "logit") && ri_sec["logit"] isa AbstractDict
        ri_sec["logit"]
    elseif haskey(config, "ri_logit") && config["ri_logit"] isa AbstractDict
        config["ri_logit"]
    elseif ri_sec isa AbstractDict
        ri_sec
    else
        Dict{String,Any}()
    end

    priors = if haskey(sec, "priors")
        pr = sec["priors"]
        if pr isa AbstractString
            String(pr) == "empirical" || throw(CliError("config/invalid",
                "[ri.logit] string priors must be \"empirical\", got '$pr'"))
            :empirical
        elseif pr isa AbstractVector && !isempty(pr) && all(x -> x isa Real, pr)
            v = _ri_parse_vec(pr, "[ri.logit] priors")
            length(v) == S || throw(CliError("config/shape",
                "[ri.logit] vector priors must have length S=$S, got $(length(v))"))
            all(>=(0.0), v) && sum(v) > 0.0 || throw(CliError("config/invalid",
                "[ri.logit] priors must be non-negative with positive sum"))
            repeat(v ./ sum(v), 1, M)
        else
            pm = _ri_parse_mat(pr, "[ri.logit] priors"; allow_scalar=false, allow_vec=false)
            size(pm) == (S, M) || throw(CliError("config/shape",
                "[ri.logit] priors must be S×M = ($S, $M), got $(size(pm))"))
            all(>=(0.0), pm) || throw(CliError("config/invalid",
                "[ri.logit] priors entries must be non-negative"))
            for m in 1:M
                sum(@view pm[:, m]) > 0.0 || throw(CliError("config/invalid",
                    "[ri.logit] column $m of priors must have positive sum"))
            end
            pm
        end
    else
        nothing
    end

    base_payoff = if haskey(sec, "base_payoff")
        bp = sec["base_payoff"]
        bp isa AbstractVector && !isempty(bp) || throw(CliError("config/type",
            "[ri.logit] base_payoff must be a J×S matrix (M=1) or length-M array of J×S matrices"))
        if bp[1] isa AbstractVector && !isempty(bp[1]) && bp[1][1] isa AbstractVector
            length(bp) == M || throw(CliError("config/shape",
                "[ri.logit] base_payoff must have M=$M environment slices, got $(length(bp))"))
            arr = Array{Float64,3}(undef, J, S, M)
            for m in 1:M
                mat = _ri_parse_mat(bp[m], "[ri.logit] base_payoff[$m]"; allow_scalar=false, allow_vec=false)
                size(mat) == (J, S) || throw(CliError("config/shape",
                    "[ri.logit] base_payoff[$m] must be J×S = ($J, $S), got $(size(mat))"))
                arr[:, :, m] .= mat
            end
            arr
        else
            M == 1 || throw(CliError("config/shape",
                "[ri.logit] 2D base_payoff only allowed for M=1 environment (got M=$M); pass array of $M J×S matrices"))
            mat = _ri_parse_mat(bp, "[ri.logit] base_payoff"; allow_scalar=false, allow_vec=false)
            size(mat) == (J, S) || throw(CliError("config/shape",
                "[ri.logit] base_payoff must be J×S = ($J, $S), got $(size(mat))"))
            reshape(mat, J, S, 1)
        end
    else
        nothing
    end

    return (priors=priors, base_payoff=base_payoff)
end
