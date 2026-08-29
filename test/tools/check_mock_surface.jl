#!/usr/bin/env julia
# Mock surface conformance vs real MacroEconometricModels (TS-3 / F32).
#
# Usage (repo root, real MEMs in project env):
#   julia --project test/tools/check_mock_surface.jl
#
# Hard failures: missing real symbols (not allowlisted), kwargs-absorber budget growth,
# and field-subset violations on CORE_TYPES.
# Soft worklist: field drift on non-core types → printed + written to
#   test/tools/mock_conformance_worklist.txt (feeds C039 / P4-2).

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))
using MacroEconometricModels

const ROOT = dirname(dirname(@__DIR__))
const MOCKS_PATH = joinpath(ROOT, "test", "mocks.jl")
const MOCK_SRC = read(MOCKS_PATH, String)
const WORKLIST_PATH = joinpath(@__DIR__, "mock_conformance_worklist.txt")

# Documented divergences — keep < 10 (C020).
const MOCK_ALLOWLIST = Dict{String,String}(
    "MockChains" => "test-only stand-in for MCMC chain objects",
    "_mock_var" => "mock factory helper (not a MEMs export)",
    "_MOCK_FLAGS" => "test control flags (not a MEMs export)",
    "PlotOutput" => "mock plot handle for --plot tests",
    "std_mock" => "test helper, not a MEMs export",
    "CCFResult" => "mock alias surface for spectral CCF; real API uses ACFResult fields",
    "BayesianDSGEHistoricalDecomposition" => "CLI-side composition type; real API may use BayesianHistoricalDecomposition",
)

# Field-subset enforcement only for these (core VAR/IRF path used everywhere).
const CORE_TYPES = Set([
    "VARModel", "VECMModel", "ImpulseResponse", "FEVD", "HistoricalDecomposition",
    "MinnesotaHyperparameters", "LPModel",
])

# Freeze kwargs-absorber budget (`; kwargs...)` forms).
# 27 after v0.11.0 family mocks (explicit HA distribution forwarding; call-site
# `; kwargs...)` matches on pre-existing DSGE/FAVAR wrappers still count).
const KWARGS_ABSORBER_BUDGET = 27

function _mock_struct_names(src::String)
    unique(String[m.captures[1] for m in eachmatch(r"(?m)^struct\s+(\w+)", src)])
end

function _mock_function_names(src::String)
    names = String[]
    for m in eachmatch(r"(?m)^function\s+([A-Za-z_][\w!]*)\s*[\({]", src)
        push!(names, m.captures[1])
    end
    for m in eachmatch(r"(?m)^([A-Za-z_][\w!]*)\s*\([^)=]*\)\s*=", src)
        push!(names, m.captures[1])
    end
    return unique(names)
end

function _mock_struct_fields(src::String, name::String)
    m = match(Regex("(?s)struct\\s+" * name * "(?:\\{[^}]*\\})?\\s*(.*?)\\nend"), src)
    m === nothing && return String[]
    fields = String[]
    for line in split(m.captures[1], '\n')
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        for fm in eachmatch(r"([A-Za-z_][\w]*)\s*::", s)
            push!(fields, fm.captures[1])
        end
    end
    return unique(fields)
end

_count_kwargs_absorbers(src::String) = length(collect(eachmatch(r";\s*kwargs\.\.\.\)", src)))

"""
    _mock_struct_field_types(src, name) → Dict{String,String}

Field name → declared type string for a mock struct (source text, may contain `{}`).
"""
function _mock_struct_field_types(src::String, name::String)
    m = match(Regex("(?s)struct\\s+" * name * "(?:\\{[^}]*\\})?\\s*(.*?)\\nend"), src)
    m === nothing && return Dict{String,String}()
    out = Dict{String,String}()
    for line in split(m.captures[1], '\n')
        s = strip(line)
        (isempty(s) || startswith(s, "#")) && continue
        s = replace(s, r"#.*$" => "")
        # mocks pack several fields per line: `Y::Matrix{T}; horizon::Int; …`
        for seg in split(s, ';')
            fm = match(r"^\s*([A-Za-z_][\w]*)\s*::\s*(.+?)\s*$", seg)
            fm === nothing && continue
            out[fm.captures[1]] = fm.captures[2]
        end
    end
    return out
end

"""Type params declared on a mock struct (`struct Name{T,S<:Real}` → ["T","S"])."""
function _mock_struct_typeparams(src::String, name::String)
    m = match(Regex("struct\\s+" * name * "\\{([^}]*)\\}"), src)
    m === nothing && return String[]
    return [String(strip(first(split(p, "<:")))) for p in split(m.captures[1], ",")]
end

"""Classify a mock field's SOURCE type string as :array, :scalar or :unknown.

A bare type param (`x::T`) classifies as :scalar — mock params are element
types (`Float64`) throughout, so `x::T` against a real `Vector` field is
exactly the LPIV `first_stage_F` drift this check exists to catch."""
function _mock_shape_class(tstr::AbstractString, typeparams::Vector{String})
    t = strip(tstr)
    occursin(r"^(Abstract)?(Vector|Matrix|Array|VecOrMat|BitVector|BitMatrix|UnitRange|StepRange|Range)\b", t) && return :array
    (t == "Any" || startswith(t, "Union{") || startswith(t, "Dict") ||
     startswith(t, "Tuple") || startswith(t, "NamedTuple") || startswith(t, "Function") ||
     t == "Nothing") && return :unknown
    return :scalar
end

"""Classify a real fieldtype as :array, :scalar or :unknown."""
function _real_shape_class(ft)
    ft isa TypeVar && return :unknown
    ft isa Type || return :unknown
    ft === Any && return :unknown
    ft isa Union && return :unknown
    T = Base.unwrap_unionall(ft)
    T isa DataType || return :unknown
    try
        ft <: AbstractArray && return :array
        (ft <: Function || ft <: AbstractDict || ft <: Tuple || ft <: NamedTuple) && return :unknown
    catch
        return :unknown
    end
    return :scalar
end

# --- NamedTuple-return conformance (#118) -------------------------------------
#
# A mock function that returns a NamedTuple literal can invent keys real MEMs
# never produces — invisible to the struct/getproperty checks because an NT is
# neither. `estimate lp --method iv` shipped dead this way (mock invented
# `F_stat`/`is_weak`; real returns `(F_stats, weak_horizons, min_F,
# passes_threshold, threshold)`).

"""
    _nt_keys_at(s, i) → Vector{String} or nothing

Top-level keys of a NamedTuple literal whose `(` is at index `i` (paren-depth
scan, so kwargs in nested calls are not mistaken for keys). Returns nothing for
a non-NT parenthesized expression.
"""
function _nt_keys_at(s::AbstractString, i::Int)
    keys = String[]
    depth = 0
    expecting = true
    j = i
    n = lastindex(s)
    while j <= n
        c = s[j]
        if c == '('
            depth += 1
        elseif c == ')'
            depth -= 1
            depth == 0 && return (isempty(keys) ? nothing : keys)
        elseif depth == 1
            if c == ','
                expecting = true
            elseif expecting && (isletter(c) || c == '_')
                m = match(r"\G([A-Za-z_]\w*)\s*=(?!=)", s, j)
                m !== nothing && push!(keys, String(m.captures[1]))
                expecting = false
            elseif !isspace(c)
                expecting = false
            end
        end
        j = nextind(s, j)
    end
    return nothing
end

"""
    _mock_namedtuple_returns(src) → Dict{String,Set{String}}

Function name → union of keys over every NamedTuple literal it returns
(`return (k=…,…)` inside long-form bodies, and `f(args) = (k=…,…)` one-liners).
"""
function _mock_namedtuple_returns(src::String)
    out = Dict{String,Set{String}}()
    add!(name, keys) = union!(get!(out, name, Set{String}()), keys)
    # long form: body up to the first column-0 `end`
    for m in eachmatch(r"(?ms)^function\s+([A-Za-z_][\w!]*)\s*\(.*?^end", src)
        name = String(m.captures[1])
        startswith(name, "_") && continue
        body = m.match
        for rm in eachmatch(r"return\s*\(", body)
            keys = _nt_keys_at(body, rm.offset + length(rm.match) - 1)
            keys !== nothing && add!(name, keys)
        end
    end
    # short form one-liners (possibly line-wrapped after `=`)
    for m in eachmatch(r"(?m)^([A-Za-z_][\w!]*)\s*\([^)\n]*\)\s*=\s*(\()", src)
        name = String(m.captures[1])
        startswith(name, "_") && continue
        keys = _nt_keys_at(src, m.offsets[2])
        keys !== nothing && add!(name, keys)
    end
    return out
end

"""
    _real_field_surface(f) → (keys::Set{String}, informative::Bool)

Union of field/key names a real function can return, from non-executing
inference (`Base.return_types`): NamedTuple names, or fieldnames for a concrete
struct return. `informative=false` when inference says nothing usable (Any /
abstract), in which case the caller must not hard-fail.
"""
function _real_field_surface(f)
    keys = Set{String}()
    informative = false
    rts = try
        Base.return_types(f)
    catch
        return (keys, false)
    end
    for rt in rts
        for u in Base.uniontypes(rt)
            t = Base.unwrap_unionall(u)
            t isa DataType || continue
            if t <: NamedTuple
                if length(t.parameters) >= 1 && t.parameters[1] isa Tuple
                    for s in t.parameters[1]
                        push!(keys, string(s))
                    end
                    informative = true
                end
            elseif t === Any || isabstracttype(t)
                # uninformative for this method
            elseif isstructtype(t)
                for s in fieldnames(t)
                    push!(keys, string(s))
                end
                informative = true
            else
                informative = true  # concrete non-fielded return (Bool, Float64, …)
            end
        end
    end
    return (keys, informative)
end

"""
    _mock_getproperty_aliases(src) → Dict{String,Vector{String}}

Type name → the property symbols a mock `Base.getproperty` method special-cases.

Field-subset checking is blind to these: an alias is a *method*, not a field, so a
mock can invent `result.cips` while its declared fields stay a perfect subset of
real. That is exactly how `test cips` shipped reading a field real MEMs does not
have (`cips_statistic`) and still passed every gate (#84).
"""
function _mock_getproperty_aliases(src::String)
    out = Dict{String,Vector{String}}()
    # Matches both `m::T` and `m::Union{A,B}` receivers — a Union form hides just as
    # many invented properties as a single-type one.
    pat = r"(?s)function\s+Base\.getproperty\(\s*\w+\s*::\s*(\w+(?:\{[^}]*\})?)\s*,\s*\w+\s*::\s*Symbol\s*\)(.*?)\n\s*end"
    for m in eachmatch(pat, src)
        recv = m.captures[1]
        syms = String[sm.captures[1] for sm in eachmatch(r"===\s*:(\w+)", m.captures[2])]
        isempty(syms) && continue
        tnames = if startswith(recv, "Union{")
            split(recv[7:end-1], ",")
        else
            [recv]
        end
        for t in tnames
            tn = String(strip(t))
            isempty(tn) && continue
            out[tn] = unique(vcat(get(out, tn, String[]), syms))
        end
    end
    return out
end

"""True if the real package defines a `Base.getproperty` method specific to `T`."""
function _real_has_custom_getproperty(T::Type)
    for m in methods(Base.getproperty)
        sig = m.sig
        sig isa DataType || continue
        length(sig.parameters) >= 2 || continue
        argT = sig.parameters[2]
        argT === Any && continue
        argT isa Type || continue
        try
            T <: argT && return true
        catch
        end
    end
    return false
end

function main()
    real_mod = MacroEconometricModels
    hard = String[]
    soft = String[]

    n_kw = _count_kwargs_absorbers(MOCK_SRC)
    println("kwargs absorbers (; kwargs...): $n_kw (budget $KWARGS_ABSORBER_BUDGET)")
    n_kw > KWARGS_ABSORBER_BUDGET &&
        push!(hard, "kwargs-absorber count $n_kw exceeds budget $KWARGS_ABSORBER_BUDGET")

    structs = _mock_struct_names(MOCK_SRC)
    for sname in structs
        if haskey(MOCK_ALLOWLIST, sname)
            println("ALLOW struct $sname — $(MOCK_ALLOWLIST[sname])")
            continue
        end
        if !isdefined(real_mod, Symbol(sname))
            push!(hard, "struct $sname: not defined in real MacroEconometricModels")
            continue
        end
        real_T = getfield(real_mod, Symbol(sname))
        real_T isa Type || continue
        mock_fields = Set(_mock_struct_fields(MOCK_SRC, sname))
        try
            real_fields = Set(string.(fieldnames(real_T)))
            extra = setdiff(mock_fields, real_fields)
            if !isempty(extra)
                msg = "struct $sname: mock fields not in real: $(join(sort!(collect(extra)), ", "))"
                if sname in CORE_TYPES
                    push!(hard, msg)
                else
                    push!(soft, msg)
                end
            else
                println("OK struct $sname (fields ⊆ real)")
            end
            # Scalar-vs-collection drift (#118 item 2): a mock scalar where real
            # declares Vector/Matrix (or vice versa) ships shape bugs T1/T2 can't
            # see (LPIVModel.first_stage_F was a scalar in the mock, a per-horizon
            # Vector upstream). Hard everywhere when both sides classify cleanly.
            tparams = _mock_struct_typeparams(MOCK_SRC, sname)
            for (fname, tstr) in _mock_struct_field_types(MOCK_SRC, sname)
                fname in real_fields || continue
                mc = _mock_shape_class(tstr, tparams)
                mc === :unknown && continue
                rc = _real_shape_class(fieldtype(real_T, Symbol(fname)))
                rc === :unknown && continue
                if mc !== rc
                    push!(hard, "struct $sname.$fname: mock is $(mc) ($tstr) but real is $(rc) " *
                                "($(fieldtype(real_T, Symbol(fname)))) — handlers written against " *
                                "the mock shape crash or mis-render on real MEMs")
                end
            end
        catch e
            println("SKIP struct $sname fields: $e")
        end
    end

    # NamedTuple-return conformance (#118 item 1): a mock may return NT keys only
    # if real's inferred return surface (NT names / struct fieldnames) has them.
    nt_returns = _mock_namedtuple_returns(MOCK_SRC)
    for fname in sort!(collect(keys(nt_returns)))
        haskey(MOCK_ALLOWLIST, fname) && continue
        isdefined(real_mod, Symbol(fname)) || continue  # function-existence check reports it
        real_f = getfield(real_mod, Symbol(fname))
        real_f isa Function || continue
        surface, informative = _real_field_surface(real_f)
        if !informative
            push!(soft, "namedtuple $fname: real return not inferrable — verify keys by hand: " *
                        "$(join(sort!(collect(nt_returns[fname])), ", "))")
            continue
        end
        bogus = sort!([k for k in nt_returns[fname] if !(k in surface)])
        if isempty(bogus)
            println("OK namedtuple $fname (keys ⊆ real return surface)")
        else
            push!(hard, "namedtuple $fname: mock returns keys real never produces: " *
                        "$(join(bogus, ", ")) — a handler reading these is dead on real MEMs " *
                        "(real surface: $(isempty(surface) ? "<no fields — non-fielded return>" : join(sort!(collect(surface)), ", ")))")
        end
    end

    # Property aliases invented by mock `Base.getproperty` methods (#84).
    aliases = _mock_getproperty_aliases(MOCK_SRC)
    for tname in sort!(collect(keys(aliases)))
        haskey(MOCK_ALLOWLIST, tname) && continue
        isdefined(real_mod, Symbol(tname)) || continue   # struct check already reported it
        real_T = getfield(real_mod, Symbol(tname))
        real_T isa Type || continue
        real_fields = try
            Set(string.(fieldnames(real_T)))
        catch
            continue
        end
        # If real defines its own getproperty for this type, its property surface
        # cannot be read statically — report as soft rather than fail the gate.
        custom = _real_has_custom_getproperty(real_T)
        bogus = [a for a in aliases[tname] if !(a in real_fields)]
        if isempty(bogus)
            println("OK getproperty $tname (aliases ⊆ real fields)")
        elseif custom
            push!(soft, "getproperty $tname: aliases not real fields (real defines a custom " *
                        "getproperty, verify by hand): $(join(sort(bogus), ", "))")
        else
            push!(hard, "getproperty $tname: mock invents properties real does not have: " *
                        "$(join(sort(bogus), ", ")) — a handler reading these crashes on real MEMs")
        end
    end

    for fname in _mock_function_names(MOCK_SRC)
        haskey(MOCK_ALLOWLIST, fname) && continue
        fname in structs && continue
        startswith(fname, "_") && continue  # private mock helpers
        if !isdefined(real_mod, Symbol(fname))
            push!(hard, "function $fname: not defined in real MacroEconometricModels")
            continue
        end
        real_f = getfield(real_mod, Symbol(fname))
        (real_f isa Function || real_f isa Type) || continue
        try
            n = length(methods(real_f))
            n == 0 && push!(hard, "function $fname: real has zero methods")
        catch
        end
    end

    open(WORKLIST_PATH, "w") do io
        println(io, "# Soft mock field-drift worklist (C039 / P4-2). Generated by check_mock_surface.jl")
        println(io, "# These are non-core simplifications; not hard CI failures.")
        for v in soft
            println(io, v)
        end
    end
    println("wrote soft worklist ($(length(soft)) entries) → $WORKLIST_PATH")

    println()
    println("=== Hard violations ($(length(hard))) ===")
    foreach(v -> println("  - $v"), hard)
    println("allowlist size: $(length(MOCK_ALLOWLIST)) (max 10)")
    length(MOCK_ALLOWLIST) > 10 && push!(hard, "MOCK_ALLOWLIST too large")

    if isempty(hard)
        println("PASS: mock surface hard checks OK")
        return 0
    else
        println("FAIL: hard mock surface drift")
        return 1
    end
end

exit(main())
