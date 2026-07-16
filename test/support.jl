# Shared test helpers (TS-1). Included by runtests / test_commands / test_e2e.

using Test
using CSV, DataFrames, JSON3, PrettyTables, TOML
using Random

# ─── Test Helpers ───────────────────────────────────────────────

"""Create a temp CSV file with synthetic multivariate data."""
function _make_csv(dir; T=100, n=3, colnames=nothing)
    cols = isnothing(colnames) ? ["var$i" for i in 1:n] : colnames
    data = Dict{String,Vector{Float64}}()
    for (i, name) in enumerate(cols)
        data[name] = randn(T) .+ Float64(i)
    end
    path = joinpath(dir, "data.csv")
    CSV.write(path, DataFrame(data))
    return path
end

"""Create a temp instruments CSV file."""
function _make_instruments_csv(dir; T=100, n_inst=2)
    data = Dict{String,Vector{Float64}}()
    for i in 1:n_inst
        data["z$i"] = randn(T)
    end
    path = joinpath(dir, "instruments.csv")
    CSV.write(path, DataFrame(data))
    return path
end

"""Capture stdout (and stderr) from a function call, returning the string.

After P1-2, status prose goes to stderr; tests that assert on status text
need both streams. Data remains on stdout; merging keeps assertions stable.
"""
function _capture(f)
    path, io = mktemp()
    try
        redirect_stdio(f; stdout=io, stderr=io)
        close(io)
        return read(path, String)
    finally
        try; close(io); catch; end
        try; rm(path; force=true); catch; end
    end
end

"""Capture stdout and stderr separately as a NamedTuple `(out, err)`."""
function _capture_all(f)
    outp, outio = mktemp()
    errp, errio = mktemp()
    try
        redirect_stdio(f; stdout=outio, stderr=errio)
        close(outio); close(errio)
        return (out=read(outp, String), err=read(errp, String))
    finally
        try; close(outio); catch; end
        try; close(errio); catch; end
        try; rm(outp; force=true); catch; end
        try; rm(errp; force=true); catch; end
    end
end

"""Dispatch via a minimal Entry built from register_* (mock-bound)."""
function _dispatch_via_app(args::Vector{String})
    root_cmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "estimate" => register_estimate_commands!(),
        "test"     => register_test_commands!(),
        "irf"      => register_irf_commands!(),
        "fevd"     => register_fevd_commands!(),
        "hd"       => register_hd_commands!(),
        "forecast"  => register_forecast_commands!(),
        "predict"   => register_predict_commands!(),
        "residuals" => register_residuals_commands!(),
        "filter"    => register_filter_commands!(),
        "data"      => register_data_commands!(),
        "nowcast"   => register_nowcast_commands!(),
        "dsge"      => register_dsge_commands!(),
        "did"       => register_did_commands!(),
        "spectral"  => register_spectral_commands!(),
    )
    root = NodeCommand("friedman", root_cmds, "test tree")
    entry = Entry("friedman", root; version=v"0.4.3")
    return dispatch(entry, args)
end

"""Create a temp CSV file with synthetic panel data (group + time columns)."""
function _make_panel_csv(dir; G=5, T_per=20, n=3, colnames=nothing)
    cols = isnothing(colnames) ? ["var$i" for i in 1:n] : colnames
    rows = G * T_per
    data = Dict{String,Vector}()
    data["group"] = repeat(1:G, inner=T_per)
    data["time"] = repeat(1:T_per, outer=G)
    for (i, name) in enumerate(cols)
        data[name] = randn(rows) .+ Float64(i)
    end
    path = joinpath(dir, "panel.csv")
    CSV.write(path, DataFrame(data))
    return path
end

"""Create a TOML config for prior settings."""
function _make_prior_config(dir; optimize=false)
    path = joinpath(dir, "prior.toml")
    open(path, "w") do io
        write(io, """
        [prior]
        type = "minnesota"
        [prior.hyperparameters]
        lambda1 = 0.2
        lambda2 = 0.5
        lambda3 = 1.0
        lambda4 = 100000.0
        [prior.optimization]
        enabled = $optimize
        """)
    end
    return path
end

"""Create a TOML config for sign identification."""
function _make_sign_config(dir)
    path = joinpath(dir, "sign.toml")
    open(path, "w") do io
        write(io, """
        [identification]
        method = "sign"
        [identification.sign_matrix]
        matrix = [[1, -1, 1], [0, 1, -1], [0, 0, 1]]
        horizons = [0, 1, 2]
        """)
    end
    return path
end

"""Create a TOML config for narrative identification."""
function _make_narrative_config(dir)
    path = joinpath(dir, "narrative.toml")
    open(path, "w") do io
        write(io, """
        [identification]
        method = "narrative"
        [identification.sign_matrix]
        matrix = [[1, -1, 1], [0, 1, -1], [0, 0, 1]]
        horizons = [0]
        [identification.narrative]
        shock_index = 1
        periods = [10, 15]
        signs = [1, -1]
        """)
    end
    return path
end

"""Create a TOML config for Arias identification."""
function _make_arias_config(dir)
    path = joinpath(dir, "arias.toml")
    open(path, "w") do io
        write(io, """
        [[identification.zero_restrictions]]
        var = 1
        shock = 1
        horizon = 0
        [[identification.sign_restrictions]]
        var = 2
        shock = 1
        sign = "positive"
        horizon = 0
        """)
    end
    return path
end

"""Create a TOML config for Uhlig identification."""
function _make_uhlig_config(dir)
    path = joinpath(dir, "uhlig.toml")
    open(path, "w") do io
        write(io, """
        [[identification.zero_restrictions]]
        var = 1
        shock = 1
        horizon = 0
        [[identification.sign_restrictions]]
        var = 2
        shock = 1
        sign = "positive"
        horizon = 0
        [identification.uhlig]
        n_starts = 50
        n_refine = 10
        """)
    end
    return path
end

"""Create a TOML config for GMM."""
function _make_gmm_config(dir; colnames=["var1","var2","var3"])
    path = joinpath(dir, "gmm.toml")
    open(path, "w") do io
        write(io, """
        [gmm]
        moment_conditions = ["$(colnames[1])", "$(colnames[2])"]
        instruments = ["lag_$(colnames[1])", "lag_$(colnames[2])"]
        weighting = "twostep"
        """)
    end
    return path
end

"""Create a TOML config for nongaussian smooth_transition."""
function _make_ng_smooth_config(dir; transition_var="var2")
    path = joinpath(dir, "ng_smooth.toml")
    open(path, "w") do io
        write(io, """
        [nongaussian]
        method = "smooth_transition"
        transition_variable = "$transition_var"
        """)
    end
    return path
end

"""Create a TOML config for nongaussian external volatility."""
function _make_ng_external_config(dir; regime_var="var3")
    path = joinpath(dir, "ng_external.toml")
    open(path, "w") do io
        write(io, """
        [nongaussian]
        method = "external"
        regime_variable = "$regime_var"
        """)
    end
    return path
end

# ─── Golden envelopes + JSON Schema (C022 / TS-5) ─────────────

const _GOLDEN_DIR = joinpath(@__DIR__, "golden")
const _ENVELOPE_SCHEMA_PATH = joinpath(dirname(@__DIR__), "schema", "envelope-v1.json")

"""Normalize envelope JSON for stable golden compare (strip volatile meta, sort keys, LF)."""
function _normalize_envelope_json(json_str::AbstractString)
    doc = JSON3.read(json_str)
    d = _json_to_sorted_dict(doc)
    if haskey(d, "meta") && d["meta"] isa AbstractDict
        m = Dict{String,Any}(d["meta"])
        delete!(m, "elapsed_ms")
        delete!(m, "argv")
        # pin volatile version strings for cross-env goldens
        m["cli_version"] = "GOLDEN"
        m["mems_version"] = "GOLDEN"
        m["julia"] = "GOLDEN"
        d["meta"] = _sort_keys(m)
    end
    if haskey(d, "command")
        # strip leading "friedman " for stability across prog prefixes
        d["command"] = replace(string(d["command"]), r"^friedman\s+" => "")
    end
    return _stable_json(d)
end

function _json_to_sorted_dict(x)
    if x isa JSON3.Object || x isa AbstractDict
        d = Dict{String,Any}()
        for (k, v) in pairs(x)
            d[string(k)] = _json_to_sorted_dict(v)
        end
        return _sort_keys(d)
    elseif x isa JSON3.Array || x isa AbstractVector
        return Any[_json_to_sorted_dict(v) for v in x]
    else
        return x
    end
end

function _sort_keys(d::AbstractDict)
    out = Dict{String,Any}()
    for k in sort!(collect(keys(d)); by=string)
        out[string(k)] = d[k]
    end
    return out
end

function _stable_json(x)
    # Deterministic compact JSON (keys already sorted at each object level)
    return replace(JSON3.write(x), "\r\n" => "\n") * "\n"
end

"""Return true if actual JSON matches the golden file after normalization."""
function _golden_compare(actual_json::AbstractString, golden_path::AbstractString)
    isfile(golden_path) || return false
    a = _normalize_envelope_json(actual_json)
    g = _normalize_envelope_json(read(golden_path, String))
    return a == g
end

"""Write normalized golden from actual JSON string."""
function _write_golden(actual_json::AbstractString, golden_path::AbstractString)
    mkpath(dirname(golden_path))
    open(golden_path, "w") do io
        write(io, _normalize_envelope_json(actual_json))
    end
    return golden_path
end

function _golden_path(cmd_path::Vector{String})
    return joinpath(_GOLDEN_DIR, join(cmd_path, ".") * ".json")
end

# ── Pure-Julia JSON Schema draft-07 subset (type/required/enum/const/properties/items/additionalProperties/oneOf) ──

function _schema_type_ok(x, t::AbstractString)
    t == "object"  && return x isa AbstractDict || x isa JSON3.Object
    t == "array"   && return x isa AbstractVector || x isa JSON3.Array
    t == "string"  && return x isa AbstractString
    t == "integer" && return x isa Integer && !(x isa Bool)
    t == "number"  && return x isa Real && !(x isa Bool)
    t == "boolean" && return x isa Bool
    t == "null"    && return x === nothing
    return false
end

function _schema_type_ok(x, types::AbstractVector)
    return any(t -> _schema_type_ok(x, string(t)), types)
end

"""Validate `doc` against a JSON Schema (draft-07 subset). Returns list of error strings (empty = ok)."""
function validate_json_schema(doc, schema; path::String="\$")
    errors = String[]
    _validate_schema!(errors, doc, schema, path)
    return errors
end

function _validate_schema!(errors, doc, schema, path)
    schema isa AbstractDict || schema isa JSON3.Object || return
    sch = schema

    if haskey(sch, "const") || haskey(sch, :const)
        c = haskey(sch, "const") ? sch["const"] : sch[:const]
        (doc == c || string(doc) == string(c)) ||
            push!(errors, "$path: expected const $c, got $doc")
    end

    if haskey(sch, "enum") || haskey(sch, :enum)
        enum = haskey(sch, "enum") ? sch["enum"] : sch[:enum]
        vals = collect(enum)
        ok = any(e -> e == doc || string(e) == string(doc), vals)
        ok || push!(errors, "$path: value $doc not in enum $vals")
    end

    if haskey(sch, "type") || haskey(sch, :type)
        t = haskey(sch, "type") ? sch["type"] : sch[:type]
        if t isa AbstractVector || t isa JSON3.Array
            _schema_type_ok(doc, collect(t)) || push!(errors, "$path: type mismatch, expected one of $t")
        else
            _schema_type_ok(doc, string(t)) || push!(errors, "$path: type mismatch, expected $t")
        end
    end

    if (haskey(sch, "required") || haskey(sch, :required)) && (doc isa AbstractDict || doc isa JSON3.Object)
        req = haskey(sch, "required") ? sch["required"] : sch[:required]
        for r in req
            rk = string(r)
            haskey(doc, rk) || haskey(doc, Symbol(rk)) || push!(errors, "$path: missing required property '$rk'")
        end
    end

    if (haskey(sch, "properties") || haskey(sch, :properties)) && (doc isa AbstractDict || doc isa JSON3.Object)
        props = haskey(sch, "properties") ? sch["properties"] : sch[:properties]
        for (k, v) in pairs(doc)
            ks = string(k)
            if haskey(props, ks) || haskey(props, Symbol(ks))
                sub = haskey(props, ks) ? props[ks] : props[Symbol(ks)]
                _validate_schema!(errors, v, sub, "$path.$ks")
            elseif haskey(sch, "additionalProperties") || haskey(sch, :additionalProperties)
                ap = haskey(sch, "additionalProperties") ? sch["additionalProperties"] : sch[:additionalProperties]
                if ap === false
                    push!(errors, "$path: additional property '$ks' not allowed")
                elseif ap isa AbstractDict || ap isa JSON3.Object
                    _validate_schema!(errors, v, ap, "$path.$ks")
                end
            end
        end
    end

    if (haskey(sch, "items") || haskey(sch, :items)) && (doc isa AbstractVector || doc isa JSON3.Array)
        items = haskey(sch, "items") ? sch["items"] : sch[:items]
        for (i, el) in enumerate(doc)
            _validate_schema!(errors, el, items, "$path[$i]")
        end
    end

    if haskey(sch, "oneOf") || haskey(sch, :oneOf)
        alts = haskey(sch, "oneOf") ? sch["oneOf"] : sch[:oneOf]
        matched = 0
        for alt in alts
            sub_err = String[]
            _validate_schema!(sub_err, doc, alt, path)
            isempty(sub_err) && (matched += 1)
        end
        matched == 1 || push!(errors, "$path: oneOf matched $matched alternatives (want 1)")
    end
end

function validate_envelope_json(json_str::AbstractString; schema_path::String=_ENVELOPE_SCHEMA_PATH)
    schema = JSON3.read(read(schema_path, String))
    # validate the raw document (not normalized) for schema
    doc = JSON3.read(json_str)
    return validate_json_schema(doc, schema)
end

"""Extract first JSON object from mixed stdout (status may be co-captured)."""
function _extract_json_object(s::AbstractString)
    i = findfirst('{', s)
    i === nothing && return nothing
    return s[i:end]
end

"""
    _run_leaf(args) → Envelope

Dispatch a command with `--format=json`, parse the single envelope, return as
`Envelope`-like NamedTuple of the JSON document (TS-4 helper).
"""
function _run_leaf(args::Vector{String})
    argv = copy(args)
    any(a -> startswith(a, "--format"), argv) || push!(argv, "--format", "json")
    out = _capture() do
        _dispatch_via_app(argv)
    end
    js = _extract_json_object(out)
    js === nothing && error("no JSON envelope from args=$argv\n$out")
    return JSON3.read(js)
end
