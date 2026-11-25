# Atomic single-pass storage codec, magic-byte sniffer & metadata ([STORAGE-W1] #305)

import JLD2
using Logging: NullLogger, with_logger
using Dates: Dates

const _JLS_MAGIC = UInt8[0x37, 0x4a, 0x4c] # "7JL" Julia Serialization header
const _FRDC_META_SCHEMA_VERSION = 1

"""
    FrdcJlsEnvelope

Metadata-carrying wrapper for `.jls` handles. Preserves CLI/MEMs versions,
kind, dimensions, varnames, free-form `note`, `seed`, and `source_model`
provenance while allowing backward-compatible reads of raw legacy `.jls` files.
"""
struct FrdcJlsEnvelope
    schema_version::Int
    cli_version::String
    mems_version::String
    kind::String
    type_name::String
    dims::Dict{String,Any}
    varnames::Vector{String}
    note::String
    seed::Any
    source_model::Any
    created_utc::String
    payload::Any
    provenance::Dict{String,Any}
end

# Backward-compatible 12-arg constructor
FrdcJlsEnvelope(sv, cv, mv, k, tn, d, vn, note, seed, sm, ts, payload) =
    FrdcJlsEnvelope(sv, cv, mv, k, tn, d, vn, note, seed, sm, ts, payload, Dict{String,Any}())

"""Run `fn()` with `JLD2` internal warnings (e.g. MmapIO fallback) suppressed."""
function _with_quiet_jld2(fn::Function)
    return with_logger(NullLogger()) do
        fn()
    end
end

"""
    _atomic_write(dest, fn) → dest

Write via a sibling temp file `.<basename>.<pid>.<rand>.tmp`, flush/close,
then commit atomically with `mv(tmp, dest; force=true)` (with bounded Windows
`EBUSY`/AV retries). On any error, cleans up `tmp` and leaves any existing
`dest` untouched.
"""
function _atomic_write(dest::String, fn::Function)::String
    abs_dest = abspath(dest)
    dir = dirname(abs_dest)
    isempty(dir) || mkpath(dir)
    tmp = joinpath(dir, ".$(basename(abs_dest)).$(getpid()).$(string(rand(UInt32); base=16)).tmp")
    try
        fn(tmp)
        isfile(tmp) || error("atomic write callback did not create temp file: $tmp")
        # Bounded retry for Windows AV/file-handle transient locks
        max_tries = Sys.iswindows() ? 8 : 2
        for attempt in 1:max_tries
            try
                mv(tmp, abs_dest; force=true)
                break
            catch e
                if attempt == max_tries
                    rethrow()
                end
                sleep(0.05 * attempt)
            end
        end
    finally
        if isfile(tmp)
            try; rm(tmp; force=true); catch; end
        end
    end
    return dest
end

"""
    sniff_handle_format(path) → Symbol

Inspect a handle file's magic bytes safely WITHOUT invoking `JLD2.jldopen`
(preventing noisy `JLD2.MmapIO` stderr warnings on empty/corrupt files).
Returns one of: `:missing`, `:empty`, `:hdf5`, `:jls`, `:unknown`.
"""
function sniff_handle_format(path::String)::Symbol
    isfile(path) || return :missing
    sz = try
        filesize(path)
    catch
        return :unknown
    end
    sz < 8 && return :empty
    hdr = try
        open(path, "r") do io
            read(io, 32)
        end
    catch
        return :unknown
    end
    length(hdr) < 8 && return :empty
    if @view(hdr[1:8]) == _HDF5_MAGIC ||
       (length(hdr) >= length(_JLD2_MAGIC) && @view(hdr[1:length(_JLD2_MAGIC)]) == _JLD2_MAGIC)
        return :hdf5
    end
    if length(hdr) >= 3 && @view(hdr[1:3]) == _JLS_MAGIC
        return :jls
    end
    return :unknown
end

"""Classify an object's high-level storage kind for `_frdc_meta`."""
function _storage_kind_tag(obj)::String
    if obj isa AbstractDict
        return "bundle"
    end
    n = nameof(typeof(obj))
    n === :TimeSeriesData && return "timeseries"
    n === :PanelData && return "panel"
    n === :CrossSectionData && return "cross_section"
    n === :IOData && return "io"
    if obj isa DataFrame || obj isa AbstractMatrix{<:Union{Real,Missing}} ||
       obj isa AbstractVector{<:Union{Real,Missing}}
        return "tabular"
    end
    if obj isa NamedTuple && !isempty(keys(obj)) &&
       !(haskey(obj, :model) && haskey(obj, :result)) &&
       all(v -> v isa AbstractVector, values(obj)) &&
       allequal(length, values(obj))
        return "tabular"
    end
    s = String(n)
    if occursin(r"(Result|ImpulseResponse|FEVD|Decomposition|Forecast|Test|Summary|Diagnostic|Accuracy|Map|Profile|Audit|Comparison|Overlap|Check|Effect|Counterfactual|Loss|History|Moments|Multipliers|Linkage|Footprint|Extraction|Impact|Stats|Specialization|Equilibrium|Transition|Path|IRF|Band|CI)$", s)
        return "result"
    end
    return "model"
end

"""Extract variable/series names from any MEMs data/model/result object safely."""
function _extract_varnames(obj)::Vector{String}
    try
        if obj isa DataFrame
            return String.(names(obj))
        elseif hasproperty(obj, :varnames)
            v = getproperty(obj, :varnames)
            v isa AbstractVector && return String[string(x) for x in v]
        elseif hasproperty(obj, :variables)
            v = getproperty(obj, :variables)
            v isa AbstractVector && return String[string(x) for x in v]
        elseif hasproperty(obj, :endog)
            v = getproperty(obj, :endog)
            v isa AbstractVector && return String[string(x) for x in v]
        elseif hasproperty(obj, :spec) && hasproperty(obj.spec, :varnames)
            v = obj.spec.varnames
            v isa AbstractVector && return String[string(x) for x in v]
        elseif hasproperty(obj, :spec) && hasproperty(obj.spec, :endog)
            v = obj.spec.endog
            v isa AbstractVector && return String[string(x) for x in v]
        elseif hasproperty(obj, :response_names)
            v = getproperty(obj, :response_names)
            v isa AbstractVector && return String[string(x) for x in v]
        elseif hasproperty(obj, :sectors)
            v = getproperty(obj, :sectors)
            v isa AbstractVector && return String[string(x) for x in v]
        end
    catch
    end
    return String[]
end

"""
    _extract_dims(obj) → Dict{String,Any}

Universal lightweight dimension extractor covering all MEMs families (data
containers, VAR/BVAR/VECM/LP/Factor/ARIMA/Vol/Reg/Panel/DSGE/HA/Nowcast/DiD/
Spectral/IO/IRF/FEVD/HD/Forecast/Filter/Test). Invoked at save time so
`model info` stays strictly header-only without loading the payload.
"""
function _extract_dims(obj)::Dict{String,Any}
    d = Dict{String,Any}()
    try
        if obj isa DataFrame
            d["rows"] = nrow(obj)
            d["cols"] = ncol(obj)
            return d
        elseif obj isa AbstractMatrix
            d["rows"] = size(obj, 1)
            d["cols"] = size(obj, 2)
            return d
        elseif obj isa AbstractVector
            d["length"] = length(obj)
            return d
        elseif obj isa AbstractArray{<:Union{Real,Missing}}
            d["shape"] = join(size(obj), "×")
            d["ndims"] = ndims(obj)
            return d
        elseif obj isa AbstractDict
            d["entries"] = length(obj)
            return d
        end
        # Data containers
        n = nameof(typeof(obj))
        if n === :PanelData
            hasproperty(obj, :n_groups) && (d["groups"] = Int(obj.n_groups))
            hasproperty(obj, :T_obs) && (d["T"] = Int(obj.T_obs))
            hasproperty(obj, :data) && (d["rows"] = size(obj.data, 1); d["vars"] = size(obj.data, 2))
            return d
        elseif n in (:TimeSeriesData, :CrossSectionData) && hasproperty(obj, :data)
            d["T"] = size(obj.data, 1)
            d["n"] = size(obj.data, 2)
            return d
        elseif n === :IOData
            hasproperty(obj, :Z) && (d["sectors"] = size(obj.Z, 1))
            return d
        elseif n === :StructuralLP
            hasproperty(obj, :var_model) && hasproperty(obj.var_model, :Y) &&
                (d["T"] = size(obj.var_model.Y, 1); d["n"] = size(obj.var_model.Y, 2))
            hasproperty(obj, :irf) && hasproperty(obj.irf, :horizon) &&
                (d["horizon"] = Int(obj.irf.horizon))
            hasproperty(obj, :lags) && (d["lags"] = Int(obj.lags))
            return d
        elseif n in (:NowcastDFM, :NowcastBVAR, :NowcastBridge)
            hasproperty(obj, :data) && obj.data isa AbstractMatrix && (d["T"] = size(obj.data, 1); d["n"] = size(obj.data, 2))
            hasproperty(obj, :nM) && (d["nM"] = Int(obj.nM))
            hasproperty(obj, :nQ) && (d["nQ"] = Int(obj.nQ))
            hasproperty(obj, :r) && (d["r"] = Int(obj.r))
            hasproperty(obj, :p) && (d["p"] = Int(obj.p))
            hasproperty(obj, :lags) && (d["lags"] = Int(obj.lags))
            hasproperty(obj, :n_equations) && (d["n_equations"] = Int(obj.n_equations))
            !isempty(d) && return d
        elseif n === :NowcastResult
            hasproperty(obj, :target_index) && (d["target_index"] = Int(obj.target_index))
            hasproperty(obj, :X_sm) && obj.X_sm isa AbstractMatrix && (d["T"] = size(obj.X_sm, 1); d["n"] = size(obj.X_sm, 2))
            !isempty(d) && return d
        elseif n === :NowcastNews
            hasproperty(obj, :variable_names) && (d["n_vars"] = length(obj.variable_names))
            hasproperty(obj, :impact_news) && (d["n_news"] = length(obj.impact_news))
            !isempty(d) && return d
        elseif n in (:DIDResult, :EventStudyLP, :LPDiDResult)
            hasproperty(obj, :n_obs) && (d["n_obs"] = Int(obj.n_obs))
            hasproperty(obj, :T_obs) && (d["T"] = Int(obj.T_obs))
            hasproperty(obj, :n_groups) && (d["groups"] = Int(obj.n_groups))
            hasproperty(obj, :event_times) && (d["event_times"] = length(obj.event_times))
            !isempty(d) && return d
        elseif n in (:SpectralDensityResult, :CrossSpectrumResult, :TransferFunctionResult)
            hasproperty(obj, :freq) && (d["n_freq"] = length(obj.freq))
            !isempty(d) && return d
        elseif n === :ABCDSystem
            hasproperty(obj, :A) && obj.A isa AbstractMatrix && (d["n_states"] = size(obj.A, 1))
            hasproperty(obj, :C) && obj.C isa AbstractMatrix && (d["n_obs"] = size(obj.C, 1))
            hasproperty(obj, :B) && obj.B isa AbstractMatrix && (d["n_shocks"] = size(obj.B, 2))
            !isempty(d) && return d
        elseif n === :InnovationsRepresentation
            hasproperty(obj, :K) && obj.K isa AbstractMatrix && (d["n_states"] = size(obj.K, 1); d["n_obs"] = size(obj.K, 2))
            !isempty(d) && return d
        elseif n === :InvertibilityResult
            hasproperty(obj, :zero_re) && (d["n_zeros"] = length(obj.zero_re))
            !isempty(d) && return d
        elseif n === :DSGEVARPosterior
            hasproperty(obj, :B_draws) && obj.B_draws isa AbstractArray && (d["k"] = size(obj.B_draws, 1); d["n"] = size(obj.B_draws, 2); d["draws"] = size(obj.B_draws, 3))
            hasproperty(obj, :p) && obj.p isa Integer && (d["p"] = Int(obj.p))
            !isempty(d) && return d
        elseif n === :DSGEVARPrior
            hasproperty(obj, :Phi_star) && obj.Phi_star isa AbstractMatrix && (d["k"] = size(obj.Phi_star, 1); d["n"] = size(obj.Phi_star, 2))
            !isempty(d) && return d
        elseif n === :DSGEVARLambdaProfile
            hasproperty(obj, :lambdas) && (d["grid"] = length(obj.lambdas))
            !isempty(d) && return d
        elseif n === :SimsKalmanSolution
            hasproperty(obj, :K_gain) && obj.K_gain isa AbstractMatrix && (d["n_states"] = size(obj.K_gain, 1); d["n_signals"] = size(obj.K_gain, 2))
            hasproperty(obj, :signal_rank) && (d["rank"] = Int(obj.signal_rank))
            !isempty(d) && return d
        elseif n === :RationalInattentionProblem
            hasproperty(obj, :A) && obj.A isa AbstractMatrix && (d["n_states"] = size(obj.A, 1))
            hasproperty(obj, :B) && obj.B isa AbstractMatrix && (d["n_shocks"] = size(obj.B, 2))
            !isempty(d) && return d
        elseif n === :DynamicRISolution
            hasproperty(obj, :T_path) && (d["T_path"] = Int(obj.T_path))
            !isempty(d) && return d
        elseif n === :SteadyStateKalman
            hasproperty(obj, :K_gain) && obj.K_gain isa AbstractMatrix && (d["n_states"] = size(obj.K_gain, 1); d["n_obs"] = size(obj.K_gain, 2))
            !isempty(d) && return d
        elseif n === :RIDiscreteChoiceSolution
            hasproperty(obj, :cond_probs) && obj.cond_probs isa AbstractMatrix && (d["n_actions"] = size(obj.cond_probs, 1); d["n_states"] = size(obj.cond_probs, 2))
            !isempty(d) && return d
        elseif n === :RILogitModel
            hasproperty(obj, :beta) && (d["params"] = length(obj.beta))
            hasproperty(obj, :n_obs) && (d["n_obs"] = Int(obj.n_obs))
            !isempty(d) && return d
        elseif n === :MWAttentionResult
            hasproperty(obj, :agg_price_irf) && (d["horizon"] = length(obj.agg_price_irf))
            !isempty(d) && return d
        end
        # Standard matrix/sample properties
        if hasproperty(obj, :Y) && obj.Y isa AbstractMatrix
            d["T"] = size(obj.Y, 1)
            d["n"] = size(obj.Y, 2)
        elseif hasproperty(obj, :y) && obj.y isa AbstractVector
            d["T"] = length(obj.y)
        elseif hasproperty(obj, :X) && obj.X isa AbstractMatrix
            d["n_obs"] = size(obj.X, 1)
            d["k"] = size(obj.X, 2)
        elseif hasproperty(obj, :data) && obj.data isa AbstractMatrix
            d["T"] = size(obj.data, 1)
            d["n"] = size(obj.data, 2)
        elseif hasproperty(obj, :theta_draws) && obj.theta_draws isa AbstractMatrix
            d["draws"] = size(obj.theta_draws, 1)
            d["params"] = size(obj.theta_draws, 2)
        elseif hasproperty(obj, :draws) && obj.draws isa AbstractMatrix
            d["draws"] = size(obj.draws, 1)
            d["params"] = size(obj.draws, 2)
        elseif hasproperty(obj, :a_grid) && obj.a_grid isa AbstractVector
            d["n_a"] = length(obj.a_grid)
            hasproperty(obj, :z_grid) && obj.z_grid isa AbstractVector && (d["n_z"] = length(obj.z_grid))
        elseif hasproperty(obj, :k_grid) && obj.k_grid isa AbstractVector
            d["n_k"] = length(obj.k_grid)
        elseif hasproperty(obj, :n_grid) && obj.n_grid isa AbstractVector
            d["n_grid"] = length(obj.n_grid)
        elseif hasproperty(obj, :grid) && hasproperty(obj.grid, :a_grid)
            d["n_a"] = length(obj.grid.a_grid)
        elseif hasproperty(obj, :steady_state) && hasproperty(obj.steady_state, :a_grid)
            d["n_a"] = length(obj.steady_state.a_grid)
        elseif hasproperty(obj, :n_full_states) && obj.n_full_states isa Integer
            d["n_full_states"] = Int(obj.n_full_states)
            hasproperty(obj, :n_reduced) && obj.n_reduced isa Integer && (d["n_reduced"] = Int(obj.n_reduced))
        elseif hasproperty(obj, :M) && obj.M isa AbstractMatrix
            d["n_states"] = size(obj.M, 1)
        elseif hasproperty(obj, :distribution) && obj.distribution isa AbstractArray
            d["grid"] = join(size(obj.distribution), "×")
        elseif hasproperty(obj, :c_policy) && obj.c_policy isa AbstractArray
            d["grid"] = join(size(obj.c_policy), "×")
        elseif hasproperty(obj, :value) && obj.value isa AbstractArray
            d["grid"] = join(size(obj.value), "×")
        elseif hasproperty(obj, :a) && obj.a isa AbstractVector
            d["n_a"] = length(obj.a)
        elseif hasproperty(obj, :solution) && obj.solution !== nothing
            sub = _extract_dims(obj.solution)
            merge!(d, sub)
        end
        # Model order / factors / draws / horizon
        hasproperty(obj, :p) && obj.p isa Integer && (d["p"] = Int(obj.p))
        hasproperty(obj, :q) && obj.q isa Integer && (d["q"] = Int(obj.q))
        hasproperty(obj, :n) && obj.n isa Integer && !haskey(d, "n") && (d["n"] = Int(obj.n))
        hasproperty(obj, :m) && obj.m isa Integer && !haskey(d, "n") && (d["m"] = Int(obj.m))
        hasproperty(obj, :r) && obj.r isa Integer && (d["r"] = Int(obj.r))
        hasproperty(obj, :k) && obj.k isa Integer && !haskey(d, "k") && (d["k"] = Int(obj.k))
        hasproperty(obj, :horizon) && obj.horizon isa Integer && (d["horizon"] = Int(obj.horizon))
        hasproperty(obj, :H) && obj.H isa Integer && !haskey(d, "horizon") && (d["horizon"] = Int(obj.H))
        hasproperty(obj, :T_obs) && obj.T_obs isa Integer && !haskey(d, "T") && (d["T"] = Int(obj.T_obs))
        hasproperty(obj, :n_obs) && obj.n_obs isa Integer && !haskey(d, "n_obs") && (d["n_obs"] = Int(obj.n_obs))
        hasproperty(obj, :n_groups) && obj.n_groups isa Integer && !haskey(d, "groups") && (d["groups"] = Int(obj.n_groups))
        hasproperty(obj, :n_draws) && obj.n_draws isa Integer && (d["draws"] = Int(obj.n_draws))
        hasproperty(obj, :n_periods) && obj.n_periods isa Integer && (d["periods"] = Int(obj.n_periods))
        # Array-shaped derived results
        if hasproperty(obj, :values) && obj.values isa AbstractArray
            sz = size(obj.values)
            length(sz) >= 1 && !haskey(d, "horizon") && (d["horizon"] = sz[1])
            length(sz) >= 2 && !haskey(d, "n") && (d["n"] = sz[2])
        elseif hasproperty(obj, :point_estimate) && obj.point_estimate isa AbstractArray
            sz = size(obj.point_estimate)
            length(sz) >= 1 && !haskey(d, "horizon") && (d["horizon"] = sz[1])
            length(sz) >= 2 && !haskey(d, "n") && (d["n"] = sz[2])
        elseif hasproperty(obj, :irf) && obj.irf isa AbstractArray
            sz = size(obj.irf)
            length(sz) >= 1 && !haskey(d, "horizon") && (d["horizon"] = sz[1])
            length(sz) >= 2 && !haskey(d, "n") && (d["n"] = sz[2])
        elseif hasproperty(obj, :forecast) && obj.forecast isa AbstractArray
            d["horizon"] = size(obj.forecast, 1)
            ndims(obj.forecast) >= 2 && (d["n"] = size(obj.forecast, 2))
        elseif hasproperty(obj, :proportions) && obj.proportions isa AbstractArray
            sz = size(obj.proportions)
            length(sz) >= 1 && !haskey(d, "horizon") && (d["horizon"] = sz[1])
            length(sz) >= 2 && !haskey(d, "n") && (d["n"] = sz[2])
        elseif hasproperty(obj, :contributions) && obj.contributions isa AbstractArray
            sz = size(obj.contributions)
            length(sz) >= 1 && (d["T"] = sz[1])
            length(sz) >= 2 && !haskey(d, "n") && (d["n"] = sz[2])
        elseif hasproperty(obj, :trend) && obj.trend isa AbstractVector
            d["T"] = length(obj.trend)
        elseif hasproperty(obj, :density) && obj.density isa AbstractArray
            d["n_freq"] = size(obj.density, 1)
        elseif hasproperty(obj, :acf) && obj.acf isa AbstractVector
            d["lags"] = length(obj.acf)
        elseif hasproperty(obj, :G1) && obj.G1 isa AbstractMatrix
            d["n_endog"] = size(obj.G1, 1)
            hasproperty(obj, :impact) && obj.impact isa AbstractMatrix && (d["n_exog"] = size(obj.impact, 2))
        elseif hasproperty(obj, :gx) && obj.gx isa AbstractMatrix
            d["n_controls"] = size(obj.gx, 1)
            d["n_states"] = size(obj.gx, 2)
        elseif hasproperty(obj, :beta) && obj.beta isa AbstractVector
            d["params"] = length(obj.beta)
        elseif hasproperty(obj, :coefficients) && obj.coefficients isa AbstractArray
            d["params"] = length(obj.coefficients)
        elseif hasproperty(obj, :att) && obj.att isa AbstractArray
            d["n_att"] = length(obj.att)
        elseif hasproperty(obj, :path) && obj.path isa AbstractMatrix
            d["T"] = size(obj.path, 1)
            d["n"] = size(obj.path, 2)
        elseif hasproperty(obj, :steady_state) && obj.steady_state isa AbstractVector
            d["n_vars"] = length(obj.steady_state)
        elseif hasproperty(obj, :V) && obj.V isa AbstractArray
            d["grid"] = join(size(obj.V), "×")
        elseif hasproperty(obj, :policy) && obj.policy isa AbstractArray
            d["grid"] = join(size(obj.policy), "×")
        elseif hasproperty(obj, :C) && obj.C isa AbstractVector
            d["T"] = length(obj.C)
        elseif hasproperty(obj, :Y) && obj.Y isa AbstractVector
            d["T"] = length(obj.Y)
        elseif hasproperty(obj, :K) && obj.K isa AbstractVector
            d["T"] = length(obj.K)
        elseif hasproperty(obj, :L) && obj.L isa AbstractVector
            d["T"] = length(obj.L)
        elseif hasproperty(obj, :theta) && obj.theta isa AbstractVector
            d["params"] = length(obj.theta)
        elseif hasproperty(obj, :statistic)
            d["scalar_test"] = 1
        end
        # Fallback: varnames count or field count if nothing else matched
        if isempty(d)
            vn = _extract_varnames(obj)
            if !isempty(vn)
                d["n_vars"] = length(vn)
            elseif hasproperty(obj, :spec) && hasproperty(obj.spec, :n_endog)
                d["n_endog"] = Int(obj.spec.n_endog)
            end
        end
    catch
    end
    return d
end

function _build_frdc_meta(obj; note::String="", source_model=nothing)::Dict{String,Any}
    seed_val = isdefined(@__MODULE__, :_SEED) ? _SEED[] : nothing
    src_dict = Dict{String,Any}()
    if source_model isa AbstractDict
        for (k, v) in source_model
            src_dict[String(k)] = v
        end
    end
    hint_vn, hint_kind = isdefined(@__MODULE__, :_consume_save_meta!) ?
        _consume_save_meta!() : (nothing, "")
    extracted_vn = _extract_varnames(obj)
    vn = if hint_vn !== nothing && !isempty(hint_vn) &&
            (isempty(extracted_vn) || obj isa AbstractDict)
        hint_vn
    else
        extracted_vn
    end
    kind_str = !isempty(hint_kind) ? hint_kind : _storage_kind_tag(obj)
    prov = isdefined(@__MODULE__, :_capture_provenance) ?
        _capture_provenance(; source_model_path=string(get(src_dict, "path", ""))) :
        Dict{String,Any}()
    return Dict{String,Any}(
        "schema_version" => _FRDC_META_SCHEMA_VERSION,
        "cli_version"    => _cli_version_string(),
        "mems_version"   => _mems_version_string(),
        "kind"           => kind_str,
        "type_name"      => string(nameof(typeof(obj))),
        "dims"           => _extract_dims(obj),
        "varnames"       => vn,
        "note"           => String(note),
        "seed"           => seed_val,
        "source_model"   => src_dict,
        "provenance"     => prov,
        "created_utc"    => Dates.format(Dates.now(Dates.UTC), "yyyy-mm-ddTHH:MM:SSZ"),
    )
end

"""Dynamic check against MacroEconometricModels._SERIALIZABLE_TYPES (zero stale copy)."""
function is_mems_serializable(obj)::Bool
    tname = string(nameof(typeof(obj)))
    if isdefined(MacroEconometricModels, :_SERIALIZABLE_TYPES)
        return haskey(getfield(MacroEconometricModels, :_SERIALIZABLE_TYPES), tname)
    end
    return tname in _NATIVE_SAVE_TYPES_FALLBACK
end

"""
    save_handle!(ref::HandleRef, obj; note="", source_model=nothing, compress=false) → String

Unified atomic single-pass handle writer.
- `.jld2`: writes native MEMs container + `_frdc_meta` + legacy `_friedman_cli_version`
  (and optional `_friedman_source_model`) in ONE atomic temp-file write. Plain tabular
  objects (`DataFrame`, `Matrix`, `Vector`, `NamedTuple`) write under `"data"`.
- `.jls`: writes `FrdcJlsEnvelope` atomically (preserving `note`, `dims`, `varnames`,
  `source_model` without ever overwriting `.jls` with HDF5).
- `.fmod`: writes legacy `ModelHandleHeader` atomically for backwards compatibility.
"""
function _artifact_kind_for(obj, override::String)::String
    !isempty(override) && return override
    tag = _storage_kind_tag(obj)
    tag in ("timeseries", "panel", "cross_section", "io", "tabular") && return "data"
    tag == "result" && return "result"
    return "model"
end

function _is_plain_jld2_payload(obj)::Bool
    _storage_kind_tag(obj) == "tabular" && return true
    obj isa AbstractArray{<:Union{Real,Missing}} && return true
    if obj isa NamedTuple && !isempty(keys(obj)) &&
       !(haskey(obj, :model) && haskey(obj, :result)) &&
       all(v -> v isa Union{AbstractArray,Real,AbstractString,Bool,Nothing}, values(obj))
        return true
    end
    return false
end
function _register_handle_artifact!(obj, written_path::String, artifact_kind::String)
    if isdefined(@__MODULE__, :envelope_active) && envelope_active() &&
       isdefined(@__MODULE__, :_add_artifact_once!)
        _add_artifact_once!(_ENVELOPE[], _artifact_kind_for(obj, artifact_kind), written_path)
    end
    return nothing
end

function save_handle!(ref::HandleRef, obj; note::String="", source_model=nothing,
                      source_model_path::String="", compress::Bool=false,
                      artifact_kind::String="")::String
    if ref.scheme === :session
        session_store_put!(ref.raw, obj; note=note, source_model=source_model)
        isdefined(@__MODULE__, :invalidate_handle_cache!) && invalidate_handle_cache!(ref)
        _register_handle_artifact!(obj, ref.raw, artifact_kind)
        _status("Stored in session as $(ref.raw) ($(nameof(typeof(obj))))")
        return ref.raw
    end

    dest = ref.path::String
    _enforce_data_root!(ref; kind="output")
    fmt = ref.format
    if fmt === nothing
        # Extensionless path: default to .jld2 when native-saveable or plain JLD2-safe, else .jls
        if is_mems_serializable(obj) || _is_plain_jld2_payload(obj) ||
           (obj isa AbstractDict{String} && !isempty(obj) && all(is_mems_serializable, values(obj)))
            dest = dest * ".jld2"
            fmt = :jld2
        else
            dest = dest * ".jls"
            fmt = :jls
            _status("Note: $(nameof(typeof(obj))) is outside the native .jld2 registry; writing .jls ($dest)")
        end
    end

    src_meta = if source_model isa AbstractDict
        Dict{String,Any}(String(k) => v for (k, v) in source_model)
    else
        Dict{String,Any}()
    end
    if !isempty(source_model_path)
        src_meta["path"] = source_model_path
    end
    if source_model !== nothing && !(source_model isa AbstractDict)
        src_meta["type_name"] = string(nameof(typeof(source_model)))
    end
    meta = _build_frdc_meta(obj; note=note, source_model=src_meta)
    cli_ver = _cli_version_string()

    if fmt === :jld2
        is_native = is_mems_serializable(obj)
        is_tabular = _is_plain_jld2_payload(obj)
        is_bundle = obj isa AbstractDict{String} && !isempty(obj) && all(is_mems_serializable, values(obj))
        if !is_native && !is_tabular && !is_bundle
            n_reg = isdefined(MacroEconometricModels, :_SERIALIZABLE_TYPES) ?
                length(getfield(MacroEconometricModels, :_SERIALIZABLE_TYPES)) :
                length(_NATIVE_SAVE_TYPES_FALLBACK)
            throw(CliError(
                "model/unsupported-save",
                "native .jld2 save does not support $(typeof(obj))",
                hint="re-run with a .jls path — this type is outside the $(n_reg)-type " *
                     "native registry, so it uses Julia Serialization instead",
            ))
        end

        _atomic_write(dest, tmp -> begin
            if is_native && isdefined(MacroEconometricModels, :_build_container)
                # Real MEMs single-pass atomic HDF5/JLD2 write (zero r+ reopens!)
                container = MacroEconometricModels._build_container(obj)
                container["note"] = String(note)
                src_container = if source_model !== nothing && !(source_model isa AbstractDict) &&
                                   is_mems_serializable(source_model)
                    try
                        MacroEconometricModels._build_container(source_model)
                    catch
                        nothing
                    end
                else
                    nothing
                end
                _with_quiet_jld2() do
                    JLD2.jldopen(tmp, "w"; compress=compress) do f
                        f["container"] = container
                        f["_frdc_meta"] = meta
                        f["_friedman_cli_version"] = cli_ver
                        if src_container !== nothing
                            f["_friedman_source_model"] = src_container
                        end
                    end
                end
            elseif is_bundle && isdefined(MacroEconometricModels, :save_model) &&
                   isdefined(MacroEconometricModels, :_build_container)
                MacroEconometricModels.save_model(obj, tmp; note=note, compress=compress)
                _with_quiet_jld2() do
                    JLD2.jldopen(tmp, "r+") do f
                        f["_frdc_meta"] = meta
                        f["_friedman_cli_version"] = cli_ver
                    end
                end
            elseif is_native
                # Mock MEMs fallback (test suite uses serialized Dict container)
                MacroEconometricModels.save_model(obj, tmp)
                if sniff_handle_format(tmp) === :hdf5
                    _with_quiet_jld2() do
                        JLD2.jldopen(tmp, "r+") do f
                            f["_frdc_meta"] = meta
                            f["_friedman_cli_version"] = cli_ver
                        end
                    end
                else
                    d = open(deserialize, tmp)
                    if d isa AbstractDict
                        d["_frdc_meta"] = meta
                        d["_friedman_cli_version"] = cli_ver
                        !isempty(note) && (d["note"] = String(note))
                        if source_model !== nothing && !(source_model isa AbstractDict)
                            d["_friedman_source_model"] = source_model
                        end
                        open(io -> serialize(io, d), tmp, "w")
                    end
                end
            else
                # Plain tabular object saved as .jld2
                _with_quiet_jld2() do
                    JLD2.jldopen(tmp, "w"; compress=compress) do f
                        f["data"] = obj
                        f["_frdc_meta"] = meta
                        f["_friedman_cli_version"] = cli_ver
                    end
                end
            end
        end)
        isdefined(@__MODULE__, :invalidate_handle_cache!) && (invalidate_handle_cache!(ref); invalidate_handle_cache!(dest))
        _register_handle_artifact!(obj, dest, artifact_kind)
        _status("Model saved to $dest (native jld2, $(nameof(typeof(obj))))")
        return dest
    elseif fmt === :jls
        env_obj = FrdcJlsEnvelope(
            _FRDC_META_SCHEMA_VERSION,
            cli_ver,
            _mems_version_string(),
            meta["kind"],
            meta["type_name"],
            meta["dims"],
            meta["varnames"],
            String(note),
            meta["seed"],
            source_model,
            meta["created_utc"],
            obj,
            get(meta, "provenance", Dict{String,Any}()),
        )
        _atomic_write(dest, tmp -> begin
            open(tmp, "w") do io
                serialize(io, env_obj)
            end
        end)
        isdefined(@__MODULE__, :invalidate_handle_cache!) && (invalidate_handle_cache!(ref); invalidate_handle_cache!(dest))
        _register_handle_artifact!(obj, dest, artifact_kind)
        _status("Serialized to $dest ($(nameof(typeof(obj))))")
        return dest
    else
        # Explicit .fmod path (legacy compatibility)
        header = ModelHandleHeader(
            FMOD_MAGIC,
            cli_ver,
            _mems_version_string(),
            string(typeof(obj)),
        )
        _atomic_write(dest, tmp -> begin
            open(tmp, "w") do io
                serialize(io, (header, obj))
            end
        end)
        isdefined(@__MODULE__, :invalidate_handle_cache!) && (invalidate_handle_cache!(ref); invalidate_handle_cache!(dest))
        _register_handle_artifact!(obj, dest, artifact_kind)
        _status("Model handle written to $dest ($(typeof(obj)))")
        return dest
    end
end

"""Extract `#key` entry from a Dict/bundle or plain JLD2 dict."""
function _extract_key_from_dict(d::AbstractDict, key::String, raw::String)
    haskey(d, key) && return d[key]
    user_keys = sort!(String[string(k) for k in keys(d) if !startswith(string(k), "_")])
    throw(CliError("data/key-not-found",
        "key '$key' not found in '$raw' (available: $(join(user_keys, ", ")))";
        hint="inspect available keys with `frdc model info $(split(raw, '#')[1])`"))
end

"""
    load_handle(ref::HandleRef) → Any

Magic-byte-first handle loader with preflight corruption checks (zero
`JLD2.MmapIO` stderr warnings), format-vs-extension mismatch detection,
`#key` extraction, and legacy `.fmod` deprecation read support.
"""
function _read_jld2_frdc_meta(path::String)
    return try
        _with_quiet_jld2() do
            JLD2.jldopen(path, "r") do f
                haskey(f, "_frdc_meta") ? f["_frdc_meta"] : nothing
            end
        end
    catch
        nothing
    end
end

function load_handle(ref::HandleRef)
    if ref.scheme === :session
        entry = session_store_get_entry(ref.raw)
        isdefined(@__MODULE__, :_record_handle_meta!) && _record_handle_meta!(entry.payload, entry.meta)
        return entry.payload
    end

    _enforce_data_root!(ref; kind="input")
    path = ref.path::String
    isfile(path) || throw(CliError("data/file-not-found", "model file not found: $(ref.raw)",
                                   hint="check handle path"))

    magic = sniff_handle_format(path)
    if magic === :empty
        throw(CliError("data/corrupt-handle",
            "handle file is empty or truncated (< 8 bytes): $(ref.raw)";
            hint="re-create the handle (file size is $(filesize(path)) bytes)"))
    end

    fmt = ref.format
    # Detect explicit format-vs-extension mismatches
    if fmt === :jls && magic === :hdf5
        throw(CliError("data/corrupt-handle",
            "format mismatch: '$(ref.raw)' has .jls extension but contains HDF5/JLD2 data";
            hint="rename to .jld2 or re-save in .jls format"))
    end
    if fmt === :fmod && magic === :hdf5
        throw(CliError("data/corrupt-handle",
            "format mismatch: '$(ref.raw)' has .fmod extension but contains HDF5/JLD2 data";
            hint="rename to .jld2"))
    end
    if magic === :unknown
        throw(CliError("data/corrupt-handle",
            "unrecognized or corrupt handle file: $(ref.raw)";
            hint="expected valid JLD2/HDF5 (.jld2) or Julia Serialization (.jls/.fmod) bytes"))
    end

    # HDF5/JLD2 file
    if magic === :hdf5
        # Try native MEMs container first
        if ref.key === nothing
            native_res = try
                _with_quiet_jld2() do
                    MacroEconometricModels.load_model(path)
                end
            catch e
                e
            end
            if !(native_res isa Exception)
                if isdefined(@__MODULE__, :_record_handle_meta!)
                    meta = _read_jld2_frdc_meta(path)
                    meta !== nothing && _record_handle_meta!(native_res, meta)
                end
                return native_res
            end
            # Inspect plain JLD2 or report native SerializationError / corruption
            d = try
                _with_quiet_jld2() do
                    JLD2.load(path)
                end
            catch err_jld
                throw(CliError("data/corrupt-handle",
                    "corrupt or unreadable JLD2 file: $(ref.raw)";
                    hint=sprint(showerror, err_jld)))
            end
            if _is_mems_jld2_dict(d)
                _has_supertype_named(typeof(native_res), :MacroModelError) && throw(native_res)
                throw(CliError("data/corrupt-handle",
                    "failed to read native model file: $(ref.raw)";
                    hint=sprint(showerror, native_res)))
            end
            # Filter out internal CLI metadata keys when inspecting plain JLD2 user keys
            user_dict = Dict{String,Any}(string(k) => v for (k, v) in d if !startswith(string(k), "_"))
            plain_meta = get(d, "_frdc_meta", nothing)
            if haskey(user_dict, "data")
                val = user_dict["data"]
                isdefined(@__MODULE__, :_record_handle_meta!) && plain_meta !== nothing && _record_handle_meta!(val, plain_meta)
                return val
            end
            if length(user_dict) == 1
                val = only(values(user_dict))
                isdefined(@__MODULE__, :_record_handle_meta!) && plain_meta !== nothing && _record_handle_meta!(val, plain_meta)
                return val
            end
            ks = join(sort!(collect(keys(user_dict))), ", ")
            throw(CliError("data/serialization",
                "ambiguous JLD2 archive '$(ref.raw)' (keys: $ks)";
                hint="select an entry with '$(ref.raw)#<key>' or save under key \"data\""))
        else
            # `#key` selector on HDF5/JLD2 (supports MEMs bundle AND plain multi-key JLD2)
            d = try
                _with_quiet_jld2() do
                    JLD2.load(path)
                end
            catch err_jld
                throw(CliError("data/corrupt-handle",
                    "corrupt or unreadable JLD2 file: $(ref.raw)";
                    hint=sprint(showerror, err_jld)))
            end
            if _is_mems_jld2_dict(d)
                # Reconstruct MEMs bundle and pick the requested key
                obj = try
                    _with_quiet_jld2() do
                        MacroEconometricModels.load_model(path)
                    end
                catch e
                    _has_supertype_named(typeof(e), :MacroModelError) && rethrow()
                    throw(CliError("data/corrupt-handle",
                        "failed to read native bundle: $(ref.raw)";
                        hint=sprint(showerror, e)))
                end
                obj isa AbstractDict || throw(CliError("data/key-not-found",
                    "handle '$(ref.raw)' is not a multi-entry bundle (got $(nameof(typeof(obj))))";
                    hint="omit '#$(ref.key)' to load the single object"))
                return _extract_key_from_dict(obj, ref.key::String, ref.raw)
            end
            return _extract_key_from_dict(d, ref.key::String, ref.raw)
        end
    end

    # Julia Serialization bytes (:jls — covers .jls, legacy .fmod, and mock .jld2 containers)
    if fmt === :jld2
        # Mock .jld2 container in unit tests (non-HDF5 serialized Dict written by mock save_model)
        if !isdefined(MacroEconometricModels, :_build_container)
            try
                obj = MacroEconometricModels.load_model(path)
                if isdefined(@__MODULE__, :_record_handle_meta!)
                    raw_d = try; open(deserialize, path); catch; nothing; end
                    if raw_d isa AbstractDict && haskey(raw_d, "_frdc_meta")
                        _record_handle_meta!(obj, raw_d["_frdc_meta"])
                    end
                end
                if ref.key !== nothing && obj isa AbstractDict
                    return _extract_key_from_dict(obj, ref.key::String, ref.raw)
                end
                return obj
            catch e
                _has_supertype_named(typeof(e), :MacroModelError) && rethrow()
                throw(CliError("data/corrupt-handle",
                    "failed to read native model file: $(ref.raw)";
                    hint=sprint(showerror, e)))
            end
        end
        throw(CliError("data/corrupt-handle",
            "format mismatch: '$(ref.raw)' has .jld2 extension but contains Julia Serialization bytes";
            hint="rename to .jls or re-save as native .jld2"))
    end

    payload = try
        open(deserialize, path)
    catch e
        throw(CliError("data/corrupt-handle",
            "failed to deserialize handle file: $(ref.raw)";
            hint=sprint(showerror, e)))
    end

    if payload isa FrdcJlsEnvelope
        val = payload.payload
        if isdefined(@__MODULE__, :_record_handle_meta!)
            _record_handle_meta!(val, Dict{String,Any}(
                "kind" => payload.kind,
                "type_name" => payload.type_name,
                "dims" => payload.dims,
                "varnames" => payload.varnames,
                "note" => payload.note,
                "seed" => payload.seed,
                "source_model" => payload.source_model,
            ))
        end
        return (ref.key !== nothing && val isa AbstractDict) ?
            _extract_key_from_dict(val, ref.key::String, ref.raw) : val
    elseif payload isa Tuple && length(payload) == 2 && payload[1] isa ModelHandleHeader
        header, model = payload
        if fmt === :fmod
            _check_handle_versions!(header, path)
            _status("Note: legacy .fmod handle read from $(ref.raw); migrate to .jld2 with `frdc model convert`")
        end
        return (ref.key !== nothing && model isa AbstractDict) ?
            _extract_key_from_dict(model, ref.key::String, ref.raw) : model
    elseif fmt === :fmod
        throw(CliError("env/model-version", "not a Friedman model handle: $(ref.raw)",
                       hint="expected $FMOD_MAGIC header"))
    end

    return (ref.key !== nothing && payload isa AbstractDict) ?
        _extract_key_from_dict(payload, ref.key::String, ref.raw) : payload
end
