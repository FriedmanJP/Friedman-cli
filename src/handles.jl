function resolve_save_path(path::String)::String
    isempty(path) && return path
    occursin(r"\.[A-Za-z0-9]+$", basename(path)) && return path
    return path * ".jld2"
end

function resolve_stem(path::String; slot::Symbol=:data)::String
    startswith(path, ":") && return path
    startswith(path, "model://") && return path
    path = _expanduser(path)
    if occursin(r"\.[A-Za-z0-9]+$", basename(path))
        return path
    end
    jld = path * ".jld2"
    isfile(jld) && return jld
    if slot === :data
        csv = path * ".csv"
        isfile(csv) && return csv
    end
    isfile(path) && return path
    hint = slot === :data ? "tried $(basename(path)).jld2 and $(basename(path)).csv" :
                            "tried $(basename(path)).jld2"
    throw(CliError("data/file-not-found", "file not found: $path"; hint=hint))
end

function _data_kind_of(obj)::Symbol
    n = nameof(typeof(obj))
    n === :TimeSeriesData && return :timeseries
    n === :PanelData && return :panel
    n === :CrossSectionData && return :cross_section
    n === :IOData && return :io
    return :unknown
end

function _is_handle_path(path::String)::Bool
    startswith(path, "model://") && return true
    lc = lowercase(path)
    return endswith(lc, ".jld2") || endswith(lc, ".fmod")
end

function resolve_data(path::String)
    resolved = resolve_stem(path; slot=:data)
    if startswith(resolved, ":") || !_is_handle_path(resolved)
        return load_data(resolved)
    end
    return load_model_dispatch(resolved)
end
