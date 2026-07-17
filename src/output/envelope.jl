# Envelope accumulator for agent-contract JSON/table/CSV output (P1-1)

"""
    Envelope

Mutable result accumulator for a single CLI invocation. Handlers feed tables
and scalars; `render` writes exactly one document (json) or table/csv stream.
"""
Base.@kwdef mutable struct Envelope
    schema_version::Int = 1
    command::String = ""
    status::Symbol = :ok
    meta::Dict{String,Any} = Dict{String,Any}()
    tables::Vector{Pair{Symbol,DataFrame}} = Pair{Symbol,DataFrame}[]  # ordered; first = primary
    scalars::Dict{String,Any} = Dict{String,Any}()
    warnings::Vector{Dict{String,String}} = Dict{String,String}[]
    artifacts::Vector{Dict{String,String}} = Dict{String,String}[]
    error::Union{Nothing,Dict{String,Any}} = nothing
end

add_table!(env::Envelope, name::Symbol, df::DataFrame) = (push!(env.tables, name => df); env)
add_scalar!(env::Envelope, key::String, value) = (env.scalars[key] = value; env)
add_warning!(env::Envelope, code::String, msg::String) =
    (push!(env.warnings, Dict("code" => code, "message" => msg)); env)

"""
    validity_warning!(code, msg)

Emit an **upstream-validity warning** (C047): the output is produced but a known
upstream defect makes it not-yet-trustworthy. Unlike status/progress messages,
a validity warning is *data about output correctness*, so it is:

- printed to `stderr` **unconditionally** — never suppressed by `--quiet`
  (contrast `_status`, which is quiet-aware); and
- attached to the JSON envelope via [`add_warning!`] when one is active, so
  agents reading `--format=json` see it under `warnings`.

`code` is a slash-namespaced string (e.g. `"upstream/naive-honest-did"`) and the
message should cite the upstream issue and the removal trigger. There are no
active callers at the 0.6.7 pin (every targeted defect is fixed upstream — see
C047); this is the reusable mechanism for the next such case.
"""
function validity_warning!(code::String, msg::String)
    # stderr: bypasses _QUIET on purpose (validity ≠ status)
    if _COLOR[]
        printstyled(stderr, "warning: "; bold=true, color=:yellow)
        println(stderr, code, ": ", msg)
    else
        println(stderr, "warning: ", code, ": ", msg)
    end
    envelope_active() && add_warning!(_ENVELOPE[], code, msg)
    return nothing
end
add_artifact!(env::Envelope, kind::String, path::String) =
    (push!(env.artifacts, Dict("kind" => kind, "path" => path)); env)

function set_error!(env::Envelope, code::String, msg::String; hint::String="")
    env.status = :error
    env.error = Dict{String,Any}("code" => code, "message" => msg, "hint" => hint)
    env
end

# JSON-safe value mapping (F20): non-finite floats → strings, never silent null
_json_safe(x) = x
_json_safe(x::AbstractFloat) = isfinite(x) ? x : string(x)   # "NaN"/"Inf"/"-Inf"
_json_safe(x::AbstractVector) = map(_json_safe, x)
_json_safe(x::AbstractDict) = Dict(string(k) => _json_safe(v) for (k, v) in x)
_json_safe(x::Symbol) = string(x)
_json_safe(x::Nothing) = nothing
_json_safe(x::Missing) = nothing

# Active envelope context (wired in C010)
const _ENVELOPE = Ref{Union{Nothing,Envelope}}(nothing)
envelope_active() = _ENVELOPE[] !== nothing
