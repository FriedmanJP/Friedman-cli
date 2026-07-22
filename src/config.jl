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
                         "sign_restrictions", "uhlig"],
    "gmm" => ["moment_conditions", "instruments", "weighting"],
    "smm" => ["model", "theta0", "lags", "p", "lower", "upper",
              "weighting", "sim_ratio", "burn"],
    "nongaussian" => ["method", "contrast", "distribution", "n_regimes",
                      "transition_variable", "regime_variable"],
    "model" => ["parameters", "endogenous", "exogenous", "equations"],
    "solver" => ["method", "order", "degree", "grid"],
    "constraints" => ["bounds", "nonlinear"],
    "priors" => String[],  # free param names under [priors]
)

"""Nested tables under known sections."""
const CONFIG_NESTED_SCHEMA = Dict{String,Vector{String}}(
    "prior.hyperparameters" => ["lambda1", "lambda2", "lambda3", "lambda4"],
    "prior.optimization" => ["enabled"],
    "identification.sign_matrix" => ["matrix", "horizons"],
    "identification.narrative" => ["shock_index", "periods", "signs"],
    "identification.uhlig" => ["n_starts", "n_refine", "max_iter_coarse",
                               "max_iter_fine", "tol_coarse", "tol_fine"],
)

"""Enum-like string fields validated against allow-lists."""
const CONFIG_ENUMS = Dict{String,Vector{String}}(
    "prior.type" => ["minnesota"],
    "identification.method" => ["cholesky", "sign", "narrative", "longrun", "arias", "uhlig",
                                "fastica", "jade", "sobi", "dcov", "hsic", "student_t",
                                "mixture_normal", "pml", "skew_normal", "markov_switching",
                                "garch_id"],
    "gmm.weighting" => ["identity", "optimal", "twostep", "iterated", "two_step"],
    "smm.weighting" => ["identity", "optimal", "two_step", "iterated", "twostep"],
    "smm.model" => ["ar1", "arp", "var1", "iid_normal"],
    "nongaussian.method" => ["fastica", "jade", "ml", "markov", "garch",
                             "smooth_transition", "external"],
    "nongaussian.contrast" => ["logcosh", "exp", "kurtosis"],
    "nongaussian.distribution" => ["student_t", "skew_t", "ghd"],
    "solver.method" => ["gensys", "klein", "perturbation", "projection", "pfi"],
)

# Thread/task-local strict flag set by wrap_legacy from --strict
const _CONFIG_STRICT = Ref(false)

"""
    load_config(path) → Dict

Load and validate a TOML configuration file.
"""
function load_config(path::String)
    _validate_input_path(path)
    isfile(path) || throw(CliError("config/file-not-found", "config file not found: $path"))
    cfg = try
        TOML.parsefile(path)
    catch e
        e isa CliError && rethrow()
        throw(CliError("config/malformed-toml", "failed to parse config file '$path': $(sprint(showerror, e))"))
    end
    validate_config_schema!(cfg; strict=_CONFIG_STRICT[])
    return cfg
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
        isfile(path) || throw(CliError("config/file-not-found", "config file not found: $path"))
        file_cfg = try
            TOML.parsefile(path)
        catch e
            e isa CliError && rethrow()
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
        deep_merge!(cfg, _json_to_dict(j))
    end
    for assignment in set
        apply_set!(cfg, assignment)
    end
    validate_config_schema!(cfg; strict=strict)
    return cfg
end

"""Write a merged config Dict to a temp TOML path (for handlers that call load_config)."""
function write_merged_config_toml(cfg::AbstractDict)::String
    path = tempname() * ".toml"
    open(path, "w") do io
        TOML.print(io, cfg)
    end
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
    _status_styled("Warning: "; bold=true, color=:yellow)
    println(stderr, code, ": ", msg)
    if envelope_active()
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

    if method == "sign"
        sm = get(id_cfg, "sign_matrix", Dict())
        if haskey(sm, "matrix")
            result["sign_matrix"] = _parse_matrix(sm["matrix"])
        end
        if haskey(sm, "horizons")
            result["horizons"] = Int.(sm["horizons"])
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

    result["moment_conditions"] = get(gmm, "moment_conditions", String[])
    result["instruments"] = get(gmm, "instruments", String[])
    result["weighting"] = get(gmm, "weighting", "twostep")

    return result
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

"""
    get_uhlig_params(config) → Dict

Extract Uhlig SVAR identification tuning parameters from a config dict.
"""
function get_uhlig_params(config::Dict)
    id_cfg = get(config, "identification", Dict())
    uhlig = get(id_cfg, "uhlig", Dict())
    Dict{String,Any}(
        "n_starts"        => get(uhlig, "n_starts", 50),
        "n_refine"        => get(uhlig, "n_refine", 10),
        "max_iter_coarse" => get(uhlig, "max_iter_coarse", 500),
        "max_iter_fine"   => get(uhlig, "max_iter_fine", 2000),
        "tol_coarse"      => get(uhlig, "tol_coarse", 1e-4),
        "tol_fine"        => get(uhlig, "tol_fine", 1e-8),
    )
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

    # Pre-linearized model flag (MEMs DSGESpec.linear / @dsge `linear: true`)
    lin_raw = get(model, "linear", false)
    result["linear"] = lin_raw isa Bool ? lin_raw :
                       lowercase(string(lin_raw)) in ("true", "1", "yes")

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
    model = get(smm, "model", nothing)
    Dict{String,Any}(
        "model"     => model === nothing ? nothing : String(model),
        "theta0"    => haskey(smm, "theta0") ? _smm_floatvec(smm["theta0"], "theta0") : nothing,
        "lags"      => haskey(smm, "lags") ? _smm_int(smm["lags"], "lags") : 1,
        "p"         => haskey(smm, "p") ? _smm_int(smm["p"], "p") : nothing,
        "lower"     => haskey(smm, "lower") ? _smm_floatvec(smm["lower"], "lower") : nothing,
        "upper"     => haskey(smm, "upper") ? _smm_floatvec(smm["upper"], "upper") : nothing,
        "weighting" => String(get(smm, "weighting", "two_step")),
        "sim_ratio" => _smm_int(get(smm, "sim_ratio", 5), "sim_ratio"),
        "burn"      => _smm_int(get(smm, "burn", 100), "burn"),
    )
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
    m = length(rows[1])
    for i in 2:n
        length(rows[i]) == m || error("matrix row $i has $(length(rows[i])) elements, expected $m")
    end
    mat = Matrix{Float64}(undef, n, m)
    for i in 1:n
        for j in 1:m
            mat[i, j] = Float64(rows[i][j])
        end
    end
    return mat
end
