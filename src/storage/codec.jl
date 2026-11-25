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
end

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
        end
        # Model order / factors / draws / horizon
        hasproperty(obj, :p) && obj.p isa Integer && (d["p"] = Int(obj.p))
        hasproperty(obj, :q) && obj.q isa Integer && (d["q"] = Int(obj.q))
        hasproperty(obj, :n) && obj.n isa Integer && !haskey(d, "n") && (d["n"] = Int(obj.n))
        hasproperty(obj, :r) && obj.r isa Integer && (d["r"] = Int(obj.r))
        hasproperty(obj, :k) && obj.k isa Integer && !haskey(d, "k") && (d["k"] = Int(obj.k))
        hasproperty(obj, :horizon) && obj.horizon isa Integer && (d["horizon"] = Int(obj.horizon))
        hasproperty(obj, :H) && obj.H isa Integer && !haskey(d, "horizon") && (d["horizon"] = Int(obj.H))
        hasproperty(obj, :n_draws) && obj.n_draws isa Integer && (d["draws"] = Int(obj.n_draws))
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
        end
        # Fallback: varnames count if nothing else matched
        if isempty(d)
            vn = _extract_varnames(obj)
            isempty(vn) || (d["n_vars"] = length(vn))
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
    return Dict{String,Any}(
        "schema_version" => _FRDC_META_SCHEMA_VERSION,
        "cli_version"    => _cli_version_string(),
        "mems_version"   => _mems_version_string(),
        "kind"           => _storage_kind_tag(obj),
        "type_name"      => string(nameof(typeof(obj))),
        "dims"           => _extract_dims(obj),
        "varnames"       => _extract_varnames(obj),
        "note"           => String(note),
        "seed"           => seed_val,
        "source_model"   => src_dict,
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
function save_handle!(ref::HandleRef, obj; note::String="", source_model=nothing,
                      compress::Bool=false)::String
    if ref.scheme === :session
        store = _serve_store_or_throw(ref.raw)
        store[ref.raw] = obj
        if source_model !== nothing && isdefined(@__MODULE__, :_SERVE_SOURCE_MODELS) &&
           _SERVE_SOURCE_MODELS[] !== nothing
            _SERVE_SOURCE_MODELS[][ref.raw] = source_model
        end
        _status("Stored in session as $(ref.raw) ($(nameof(typeof(obj))))")
        return ref.raw
    end

    dest = ref.path::String
    _enforce_data_root!(ref; kind="output")
    fmt = ref.format
    if fmt === nothing
        # Extensionless path: default to .jld2 when native-saveable or tabular, else .jls
        if is_mems_serializable(obj) || _storage_kind_tag(obj) == "tabular"
            dest = dest * ".jld2"
            fmt = :jld2
        else
            dest = dest * ".jls"
            fmt = :jls
            _status("Note: $(nameof(typeof(obj))) is outside the native .jld2 registry; writing .jls ($dest)")
        end
    end

    meta = _build_frdc_meta(obj; note=note,
        source_model=(source_model isa AbstractDict ? source_model : nothing))
    cli_ver = _cli_version_string()

    if fmt === :jld2
        is_native = is_mems_serializable(obj)
        is_tabular = _storage_kind_tag(obj) == "tabular"
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
        )
        _atomic_write(dest, tmp -> begin
            open(tmp, "w") do io
                serialize(io, env_obj)
            end
        end)
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
function load_handle(ref::HandleRef)
    if ref.scheme === :session
        store = _serve_store_or_throw(ref.raw)
        haskey(store, ref.raw) || throw(CliError("data/file-not-found",
            "no session handle stored at $(ref.raw)";
            hint="save one first with --save-model $(ref.raw) or -o $(ref.raw)"))
        return store[ref.raw]
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
            haskey(user_dict, "data") && return user_dict["data"]
            length(user_dict) == 1 && return only(values(user_dict))
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
