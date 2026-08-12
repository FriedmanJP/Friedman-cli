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

"""Map an error-code string to its process exit code (2–6, or 1 for unprefixed).
Shared by `exit_class(::CliError)` and `set_error!`'s `exit_code` field (W2/#137)
so the envelope's `error.exit_code` can never disagree with the process exit."""
exit_class(code::AbstractString) = get(_EXIT_CLASSES, first(split(code, '/'; limit=2)), 1)

"""Map a CliError to its process exit code (2–6, or 1 for unprefixed)."""
exit_class(e::CliError) = exit_class(e.code)

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
- `StochasticSingularityError` → `model/stochastic-singularity` (5) — W4/#139:
  a direct `Exception` (NOT under `MacroModelError`), thrown by the DSGE Kalman
  likelihood when observables exceed structural shocks with no measurement error.
- `DSGESolveError`       → `model/solve` (5) — W4/#139: also a direct `Exception`;
  thrown when the numerical steady state fails the equilibrium conditions or the
  constrained NLopt solver does not converge.
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
    elseif tn === :StochasticSingularityError
        return CliError("model/stochastic-singularity", _err_message(e);
                        hint="the state-space is stochastically singular — add measurement " *
                             "error or reduce the number of observables")
    elseif tn === :DSGESolveError
        return CliError("model/solve", _err_message(e);
                        hint="no valid solution at these parameters — check the steady-state " *
                             "guess/bounds, or the parameterization (try `dsge determinacy-map`)")
    elseif _has_supertype_named(typeof(e), :MacroModelError)
        return CliError("model/error", _err_message(e))
    elseif e isa ArgumentError && _is_orientation_error(_err_message(e))
        # MEMs' `_orient_data` (DSGE bayes/HA paths, #142) throws a plain
        # ArgumentError when no data dimension matches the observable count.
        # It is untyped upstream, so match its distinctive message.
        return CliError("data/orientation", _err_message(e);
                        hint="pass data as T×n (time in rows, variables in columns); transpose if it is n×T")
    end
    return nothing
end

"""True if `msg` is MEMs' data-orientation ArgumentError (#142). Matched on a
stable ASCII substring since upstream does not give it a typed exception."""
_is_orientation_error(msg::AbstractString) =
    occursin("neither dimension equals the number of observables", msg)
