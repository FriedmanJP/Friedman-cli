# Model handles (.fmod) — interim Serialization format (P2-7 / C029)
# Replaced by MEMs save_model/load_model (#347) in C052 — keep the boundary local.

const FMOD_MAGIC = "FRIEDMAN_FMOD_v1"

"""Header stored ahead of the serialized model payload."""
struct ModelHandleHeader
    magic::String
    cli_version::String
    mems_version::String
    model_type::String
end

function _mems_version_string()::String
    try
        return string(pkgversion(MacroEconometricModels))
    catch
        return "unknown"
    end
end

function _cli_version_string()::String
    return string(FRIEDMAN_VERSION)
end

"""
    save_model_handle(path, model; model_type="")

Write a `.fmod` handle: header + serialized model.
"""
function save_model_handle(path::String, model; model_type::String="")
    isempty(path) && return nothing
    _validate_output_path(path)
    mtype = isempty(model_type) ? string(typeof(model)) : model_type
    header = ModelHandleHeader(
        FMOD_MAGIC,
        _cli_version_string(),
        _mems_version_string(),
        mtype,
    )
    open(path, "w") do io
        serialize(io, (header, model))
    end
    _status("Model handle written to $path ($mtype)")
    return path
end

"""
    load_model_handle(path) → model

Load a `.fmod` handle. Throws `CliError` with code `env/model-version` on
magic/version mismatch (exit class 6).
"""
function load_model_handle(path::String)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path",
                                   hint="check --model path"))
    payload = try
        open(path, "r") do io
            deserialize(io)
        end
    catch e
        throw(CliError("env/model-corrupt", "failed to read model handle: $path",
                       hint=sprint(showerror, e)))
    end
    header, model = _unpack_fmod(payload, path)
    _check_handle_versions!(header, path)
    return model
end

function _unpack_fmod(payload, path::String)
    if payload isa Tuple && length(payload) == 2 && payload[1] isa ModelHandleHeader
        return payload[1], payload[2]
    end
    throw(CliError("env/model-version", "not a Friedman model handle: $path",
                   hint="expected $FMOD_MAGIC header"))
end

function _check_handle_versions!(header::ModelHandleHeader, path::String)
    header.magic == FMOD_MAGIC || throw(CliError(
        "env/model-version",
        "bad model handle magic in $path (got $(header.magic))",
        hint="re-estimate and --save-model with this CLI version",
    ))
    cli_now = _cli_version_string()
    mems_now = _mems_version_string()
    if header.cli_version != cli_now || header.mems_version != mems_now
        throw(CliError(
            "env/model-version",
            "model handle version mismatch for $path: " *
            "handle CLI=$(header.cli_version) MEMs=$(header.mems_version); " *
            "runtime CLI=$cli_now MEMs=$mems_now",
            hint="re-estimate with --save-model under the current versions",
        ))
    end
    return nothing
end

"""
    model_handle_info(path) → NamedTuple

Read header (and light model summary) without re-running estimation.
"""
function model_handle_info(path::String)
    isfile(path) || throw(CliError("data/file-not-found", "model handle not found: $path"))
    payload = open(deserialize, path)
    header, model = _unpack_fmod(payload, path)
    dims = _model_dims(model)
    return (
        path = path,
        magic = header.magic,
        cli_version = header.cli_version,
        mems_version = header.mems_version,
        model_type = header.model_type,
        runtime_cli = _cli_version_string(),
        runtime_mems = _mems_version_string(),
        dimensions = dims,
    )
end

function _model_dims(model)
    try
        if hasproperty(model, :Y)
            Y = model.Y
            return Dict("T" => size(Y, 1), "n" => size(Y, 2))
        elseif hasproperty(model, :p) && hasproperty(model, :n)
            return Dict("p" => model.p, "n" => model.n)
        end
    catch
    end
    return Dict{String,Any}()
end
