# CliError taxonomy + stable exit codes (P1-4; F23, F24, F62)

"""
    CliError(code, message; hint="")

Typed CLI error. Exit class is derived from the code prefix:

| Prefix   | Exit code | Meaning        |
|----------|-----------|----------------|
| usage/*  | 2         | CLI usage      |
| data/*   | 3         | Input data     |
| config/* | 4         | Config/TOML    |
| model/*  | 5         | Model/domain   |
| env/*    | 6         | Environment    |
| other    | 1         | Internal/bug   |
"""
struct CliError <: Exception
    code::String
    message::String
    hint::String
end
CliError(code::String, message::String; hint::String="") = CliError(code, message, hint)

const _EXIT_CLASSES = Dict(
    "usage" => 2,
    "data" => 3,
    "config" => 4,
    "model" => 5,
    "env" => 6,
)

"""Map a CliError to its process exit code (2–6, or 1 for unprefixed)."""
function exit_class(e::CliError)
    prefix = first(split(e.code, '/'; limit=2))
    return get(_EXIT_CLASSES, prefix, 1)
end

function Base.showerror(io::IO, e::CliError)
    print(io, e.code, ": ", e.message)
    isempty(e.hint) || print(io, " (hint: ", e.hint, ")")
end

# ── MEMs domain-error mapping (C050 / MEMs#245) ───────────
# MEMs 0.7.0 introduced a typed exception hierarchy rooted at `MacroModelError`.
# Before C050, these fell through `run_cli`'s generic branch → exit 1 (internal
# bug). Map them to the model class (exit 5) so agents can distinguish a genuine
# model/domain failure from a CLI bug.
#
# Matching is by runtime type NAME, not `isa MacroEconometricModels.X`, so this
# stays correct whether the real package or the test mock is the in-scope
# `MacroEconometricModels` (src files are `include`d into the test scope).

"""Human-readable message for a caught exception; prefers a `.msg` field (all
`MacroModelError` subtypes carry one) and falls back to `showerror`."""
function _err_message(e)
    if hasproperty(e, :msg)
        m = getproperty(e, :msg)
        m isa AbstractString && return String(m)
    end
    return sprint(showerror, e)
end

"""True if `T` or any of its supertypes is named `sym` (module-agnostic isa)."""
function _has_supertype_named(::Type{T}, sym::Symbol) where {T}
    S = T
    while S !== Any
        nameof(S) === sym && return true
        S = supertype(S)
    end
    return false
end

"""
    _domain_error_class(e) → Union{CliError,Nothing}

Translate a MacroEconometricModels domain exception into a typed `CliError`.
Returns `nothing` when `e` is not a recognized MEMs domain error, so the caller
falls back to the generic internal-error path (exit 1).

- `ConvergenceError`     → `model/convergence` (5)
- `IdentificationError`  → `model/identification` (5)
- `SingularSystemError`  → `model/singular` (5)
- `SerializationError`   → `data/serialization` (3) — a saved artifact/handle is
  unreadable or version-incompatible, i.e. a bad input artifact, not a model bug.
- any other `MacroModelError` subtype → `model/error` (5)
"""
function _domain_error_class(e)
    e isa Exception || return nothing
    tn = nameof(typeof(e))
    if tn === :ConvergenceError
        return CliError("model/convergence", _err_message(e);
                        hint="raise --max-iter, try a different start, or rescale the data")
    elseif tn === :IdentificationError
        return CliError("model/identification", _err_message(e);
                        hint="check identifying restrictions / instruments")
    elseif tn === :SingularSystemError
        return CliError("model/singular", _err_message(e);
                        hint="near-singular system — drop collinear series or add observations")
    elseif tn === :SerializationError
        return CliError("data/serialization", _err_message(e);
                        hint="the saved artifact is unreadable or version-incompatible")
    elseif _has_supertype_named(typeof(e), :MacroModelError)
        return CliError("model/error", _err_message(e))
    end
    return nothing
end
