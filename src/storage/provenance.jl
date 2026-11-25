# Provenance capture & cross-format / multi-family reproduction ([STORAGE-W5] #309)

"""Build lightweight command provenance metadata recorded into `_frdc_meta` and
`FrdcJlsEnvelope` during single-pass save."""
function _capture_provenance(; source_model_path::String="")::Dict{String,Any}
    argv = isdefined(@__MODULE__, :_LAST_ARGV) ? copy(_LAST_ARGV[]) : String[]
    cmd = if isdefined(@__MODULE__, :_ENVELOPE) && _ENVELOPE[] !== nothing
        _ENVELOPE[].command
    elseif isdefined(@__MODULE__, :_net_command) && !isempty(argv)
        _net_command(argv)
    else
        ""
    end
    d = Dict{String,Any}(
        "command"      => cmd,
        "argv"         => argv,
        "seed"         => (isdefined(@__MODULE__, :_SEED) ? _SEED[] : nothing),
        "cli_version"  => _cli_version_string(),
        "mems_version" => _mems_version_string(),
    )
    !isempty(source_model_path) && (d["source_model_path"] = source_model_path)
    return d
end

"""Read provenance dictionary stored inside a handle without loading large payloads
when possible (`.jld2` `_frdc_meta`, `.jls` `FrdcJlsEnvelope`, or session entry)."""
function load_handle_provenance(path::String)::Dict{String,Any}
    isempty(path) && return Dict{String,Any}()
    if _is_session_uri(path)
        entry = try; session_store_get_entry(path); catch; return Dict{String,Any}(); end
        prov = get(entry.meta, "provenance", Dict{String,Any}())
        return prov isa AbstractDict ? Dict{String,Any}(String(k) => v for (k, v) in prov) : Dict{String,Any}()
    end
    base, _ = _split_key_selector(path)
    isfile(base) || return Dict{String,Any}()
    magic = sniff_handle_format(base)
    if magic === :hdf5
        meta = _read_jld2_frdc_meta(base)
        if meta isa AbstractDict
            prov = get(meta, "provenance", nothing)
            if prov isa AbstractDict
                return Dict{String,Any}(String(k) => v for (k, v) in prov)
            end
            src = get(meta, "source_model", nothing)
            if src isa AbstractDict && !isempty(src)
                return Dict{String,Any}(String(k) => v for (k, v) in src)
            end
        end
    elseif magic === :jls
        payload = try; open(deserialize, base); catch; nothing; end
        if payload isa FrdcJlsEnvelope
            d = Dict{String,Any}(
                "seed" => payload.seed,
                "cli_version" => payload.cli_version,
                "mems_version" => payload.mems_version,
            )
            if hasproperty(payload, :provenance) && payload.provenance isa AbstractDict
                for (k, v) in payload.provenance
                    d[String(k)] = v
                end
            end
            return d
        elseif payload isa AbstractDict && haskey(payload, "_frdc_meta")
            meta = payload["_frdc_meta"]
            if meta isa AbstractDict && haskey(meta, "provenance") && meta["provenance"] isa AbstractDict
                return Dict{String,Any}(String(k) => v for (k, v) in meta["provenance"])
            end
        end
    end
    return Dict{String,Any}()
end

"""Compare two arrays/scalars field-by-field up to `tol`."""
function _compare_repro_field(name::Symbol, a, b, tol::Float64)
    if a isa AbstractArray && b isa AbstractArray
        if size(a) != size(b)
            return (name=name, matched=false, max_abs_diff=Inf)
        end
        diff = 0.0
        for (x, y) in zip(a, b)
            if isnan(x) && isnan(y)
                continue
            end
            d = abs(Float64(x) - Float64(y))
            d > diff && (diff = d)
        end
        return (name=name, matched=(diff <= tol), max_abs_diff=diff)
    elseif a isa Real && b isa Real
        d = (isnan(a) && isnan(b)) ? 0.0 : abs(Float64(a) - Float64(b))
        return (name=name, matched=(d <= tol), max_abs_diff=d)
    end
    return nothing
end

function _compare_repro_objects(orig, rerun, field_candidates::Tuple, tol::Float64)
    fields = NamedTuple{(:name, :matched, :max_abs_diff),Tuple{Symbol,Bool,Float64}}[]
    for fn in field_candidates
        (hasproperty(orig, fn) && hasproperty(rerun, fn)) || continue
        a = getproperty(orig, fn)
        b = getproperty(rerun, fn)
        (a === nothing || b === nothing) && continue
        cmp = _compare_repro_field(fn, a, b, tol)
        cmp !== nothing && push!(fields, cmp)
    end
    isempty(fields) && return nothing
    max_d = maximum(f.max_abs_diff for f in fields)
    all_ok = all(f.matched for f in fields)
    return (matched=all_ok, max_abs_diff=max_d, fields=fields)
end

function _detect_handle_format_label(path::String)::String
    _is_session_uri(path) && return "session"
    base, _ = _split_key_selector(path)
    lc = lowercase(base)
    endswith(lc, ".jld2") && return "jld2"
    endswith(lc, ".jls") && return "jls"
    endswith(lc, ".fmod") && return "fmod"
    return string(sniff_handle_format(base))
end

"""Try CLI-level deterministic/seeded reproduction from an attached `src` model
for derived results (VAR/BVAR/LP/StructuralLP/VECM/ARIMA/SARIMA/Factor IRF,
FEVD, HD, and forecasts) when upstream `reproduce(obj)` has no 1-arg recipe."""
function _reproduce_from_source(obj, src, seed_val, tol::Float64)
    src === nothing && return nothing
    tn = nameof(typeof(obj))
    stn = nameof(typeof(src))

    # Helper to run with optional RNG seed
    run_seeded(fn) = begin
        if seed_val isa Integer
            Random.seed!(Int(seed_val))
        end
        fn()
    end

    rerun = try
        if tn === :ImpulseResponse
            h = _model_horizon(obj)
            if stn === :StructuralLP
                src.irf
            elseif stn === :SVARModel || stn === :SVECResult
                run_seeded(() -> irf(src, h))
            elseif stn === :VECMModel
                run_seeded(() -> irf(to_var(src), h))
            else
                nothing
            end
        elseif tn === :BayesianImpulseResponse && stn === :BVARPosterior
            h = _model_horizon(obj)
            run_seeded(() -> irf(src, h))
        elseif tn === :FEVD
            h = _model_horizon(obj)
            if stn === :VARModel || stn === :SVARModel || stn === :SVECResult
                fevd(src, h)
            elseif stn === :VECMModel
                fevd(to_var(src), h)
            else
                nothing
            end
        elseif tn === :LPFEVD && stn === :StructuralLP
            h = _model_horizon(obj)
            run_seeded(() -> lp_fevd(src, h))
        elseif tn === :BayesianFEVD && stn === :BVARPosterior
            h = _model_horizon(obj)
            run_seeded(() -> fevd(src, h))
        elseif tn === :HistoricalDecomposition
            if stn === :VARModel || stn === :SVARModel || stn === :SVECResult
                historical_decomposition(src)
            elseif stn === :StructuralLP
                historical_decomposition(src, _model_horizon(src))
            elseif stn === :VECMModel
                historical_decomposition(to_var(src))
            else
                nothing
            end
        elseif tn === :BayesianHistoricalDecomposition && stn === :BVARPosterior
            run_seeded(() -> historical_decomposition(src))
        elseif tn === :VARForecast && stn === :VARModel
            h = _model_horizon(obj)
            kw = Dict{Symbol,Any}()
            hasproperty(obj, :ci_method) && (kw[:ci_method] = obj.ci_method)
            hasproperty(obj, :conf_level) && (kw[:conf_level] = obj.conf_level)
            run_seeded(() -> forecast(src, h; kw...))
        elseif tn === :BVARForecast && stn === :BVARPosterior
            h = _model_horizon(obj)
            kw = Dict{Symbol,Any}()
            hasproperty(obj, :conf_level) && (kw[:conf_level] = obj.conf_level)
            hasproperty(obj, :point_estimate) && (kw[:point_estimate] = obj.point_estimate)
            run_seeded(() -> forecast(src, h; kw...))
        elseif tn === :ARIMAForecast && stn in (:ARIMAModel, :SARIMAModel, :ARModel, :MAModel, :ARMAModel)
            h = _model_horizon(obj)
            kw = Dict{Symbol,Any}()
            hasproperty(obj, :conf_level) && (kw[:conf_level] = obj.conf_level)
            run_seeded(() -> forecast(src, h; kw...))
        elseif tn === :FactorForecast && stn in (:FactorModel, :DynamicFactorModel, :GeneralizedDynamicFactorModel, :StructuralDFM)
            h = _model_horizon(obj)
            kw = Dict{Symbol,Any}()
            hasproperty(obj, :ci_method) && (kw[:ci_method] = obj.ci_method)
            hasproperty(obj, :conf_level) && (kw[:conf_level] = obj.conf_level)
            run_seeded(() -> forecast(src, h; kw...))
        elseif tn === :VECMForecast && stn === :VECMModel
            h = _model_horizon(obj)
            kw = Dict{Symbol,Any}()
            hasproperty(obj, :ci_method) && (kw[:ci_method] = obj.ci_method)
            hasproperty(obj, :conf_level) && (kw[:conf_level] = obj.conf_level)
            run_seeded(() -> forecast(src, h; kw...))
        else
            nothing
        end
    catch
        nothing
    end
    rerun === nothing && return nothing

    cands = (:values, :point_estimate, :proportions, :bias_corrected, :contributions,
             :forecast, :levels, :differences, :observables, :factors,
             :ci_lower, :ci_upper, :lower, :upper, :se,
             :factors_lower, :factors_upper, :observables_lower, :observables_upper)
    return _compare_repro_objects(obj, rerun, cands, tol)
end

"""
    reproduce_handle(obj, path; source_model="", tol=1e-10) → NamedTuple

Cross-format (`.jld2`, `.jls`, `.fmod`, session URI) and multi-family
reproduction verifier. Combines upstream `MacroEconometricModels.reproduce`
(1-arg and 2-arg `ImpulseResponse + VARModel`) with source-model fallback for
BVAR/LP/StructuralLP/VECM/FEVD/HD/Forecast handles.
"""
function reproduce_handle(obj, path::String; source_model::String="", tol::Float64=1e-10)
    prov = load_handle_provenance(path)
    fmt = _detect_handle_format_label(path)
    src_cmd = string(get(prov, "command", ""))

    # Resolve source model (explicit --model wins, else embedded/stored source_model)
    src = if !isempty(source_model)
        sp = _is_session_uri(source_model) ? source_model :
             resolve_stem(source_model; slot=:model)
        load_model_dispatch(sp)
    else
        load_source_model(path)
    end

    if obj isa ImpulseResponse && !isempty(source_model) && !(src isa VARModel || src isa StructuralLP || src isa SVARModel || src isa VECMModel)
        throw(CliError("model/wrong-kind",
            "source model must be a VARModel/SVARModel/StructuralLP/VECMModel for ImpulseResponse reproduction (got $(nameof(typeof(src))))"))
    end

    rep = try
        if obj isa ImpulseResponse && src isa VARModel
            MacroEconometricModels.reproduce(obj, src)
        else
            MacroEconometricModels.reproduce(obj)
        end
    catch e
        e isa CliError && rethrow()
        e isa MethodError && (e.f === MacroEconometricModels.reproduce) && throw(CliError(
            "model/unsupported",
            "reproduce is not defined for $(typeof(obj))";
            hint="only randomized results estimated with seed= carry a ReproManifest " *
                 "that reproduce can re-run — re-estimate with --seed"))
        rethrow()
    end

    seed_val = rep.seed === nothing ? get(prov, "seed", nothing) : rep.seed
    fields = rep.fields
    matched = rep.matched
    note = rep.note
    max_abs_diff = isempty(fields) ? 0.0 : maximum(Float64(d.max_abs_diff) for d in fields)

    # Fallback: if upstream returned matched === missing and we have a source model,
    # attempt CLI-level derived reproduction (VAR/BVAR/LP/VECM/ARIMA/Factor).
    if matched === missing && src !== nothing
        cli_cmp = _reproduce_from_source(obj, src, seed_val, tol)
        if cli_cmp !== nothing
            matched = cli_cmp.matched
            max_abs_diff = cli_cmp.max_abs_diff
            fields = cli_cmp.fields
            note = "reproduced from attached $(nameof(typeof(src)))"
        end
    end

    return (
        matched = matched,
        max_abs_diff = max_abs_diff,
        seed = seed_val,
        source_command = src_cmd,
        format = fmt,
        tol = tol,
        threads_captured = rep.threads_captured,
        threads_current = rep.threads_current,
        note = note,
        fields = fields,
    )
end
