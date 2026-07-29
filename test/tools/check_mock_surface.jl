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
const KWARGS_ABSORBER_BUDGET = 23

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
        catch e
            println("SKIP struct $sname fields: $e")
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
