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
