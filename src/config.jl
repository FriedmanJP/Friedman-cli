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
            "instr" => haskey(e, "instr") ? _system_strvec(e["instr"], "[[equations]] entry $j `instr`") : nothing,
        ))
    end
    common = nothing
    instr_tbl = get(config, "instruments", nothing)
    if instr_tbl isa AbstractDict && haskey(instr_tbl, "common")
        common = _system_strvec(instr_tbl["common"], "[instruments] `common`")
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

"""
    get_statespace(config) -> NamedTuple

Parse a `[statespace]` section describing a GENERAL linear-Gaussian state-space system, for
`estimate statespace --config`. The system is the standard single-block form

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
        "estimate statespace --config requires a [statespace] section with Z, H, T and Q"))

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

    return (Z=Z, H=H, T=Tm, Q=Q, R=R, d=d, c=c, a1=a1, P1=P1,
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
