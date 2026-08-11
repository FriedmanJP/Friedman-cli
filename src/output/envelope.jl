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
    warnings::Vector{Dict{String,String}} = Dict{String,String}[]
    artifacts::Vector{Dict{String,String}} = Dict{String,String}[]
    error::Union{Nothing,Dict{String,Any}} = nothing
end
# `data` values are tables ONLY (envelope-v1 contract, W1/#136). The old
# add_scalar!/scalars sibling path never gained a caller (output_kv renders a
# metric/value table instead) and was deleted so emission cannot drift under
# the strict schema.

add_table!(env::Envelope, name::Symbol, df::DataFrame) = (push!(env.tables, name => df); env)
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
    # exit_code is derived from the code prefix by the SAME function that maps
    # the process exit (W2/#137) — envelope and exit status cannot disagree.
    # An empty hint is omitted, not serialized as "".
    err = Dict{String,Any}("code" => code, "message" => msg,
                           "exit_code" => exit_class(code))
    isempty(hint) || (err["hint"] = hint)
    env.error = err
    env
end

# One-shot latch: has THIS invocation already rendered an envelope to stdout?
# Set by dispatch_leaf at both render sites, reset by run_cli at entry; the
# run_cli usage-error net (W2/#137) checks it so an error can never produce two
# envelopes (dispatch_leaf renders-then-rethrows on handler errors).
const _ENVELOPE_EMITTED = Ref{Bool}(false)

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
