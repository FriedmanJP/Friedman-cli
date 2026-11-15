function resolve_save_path(path::String)::String
    isempty(path) && return path
    startswith(path, "model://") && return path
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
    jls = path * ".jls"
    isfile(jls) && return jls
    if slot === :data
        csv = path * ".csv"
        isfile(csv) && return csv
    else
        fmod = path * ".fmod"
        isfile(fmod) && return fmod
    end
    isfile(path) && return path
    bn = basename(path)
    hint = slot === :data ? "tried $(bn).jld2, $(bn).jls, and $(bn).csv" :
                            "tried $(bn).jld2, $(bn).jls, and $(bn).fmod"
    throw(CliError("data/file-not-found", "file not found: $path"; hint=hint))
end

function _data_kind_of(obj)::Symbol
    n = nameof(typeof(obj))
    n === :TimeSeriesData && return :timeseries
    n === :PanelData && return :panel
    n === :CrossSectionData && return :cross_section
    n === :IOData && return :io
    obj isa DataFrame && return :tabular
    obj isa AbstractMatrix{<:Union{Real,Missing}} && return :tabular
    obj isa AbstractVector{<:Union{Real,Missing}} && return :tabular
    if obj isa NamedTuple && !isempty(keys(obj)) &&
       !(haskey(obj, :model) && haskey(obj, :result)) &&
       all(v -> v isa AbstractVector, values(obj)) &&
       allequal(length, values(obj))
        return :tabular
    end
    return :unknown
end

function _is_handle_path(path::String)::Bool
    startswith(path, "model://") && return true
    lc = lowercase(path)
    return endswith(lc, ".jld2") || endswith(lc, ".jls") || endswith(lc, ".fmod")
end

function resolve_data(path::String)
    resolved = resolve_stem(path; slot=:data)
    if startswith(resolved, ":") || !_is_handle_path(resolved)
        return load_data(resolved)
    end
    obj = load_model_dispatch(resolved)
    if _data_kind_of(obj) === :tabular
        return _coerce_tabular_dataframe(obj, resolved)
    end
    return obj
end

function _default_edit_output(input::String, suffix::String)
    stem = dataset_stem(input)
    resolved = try
        resolve_stem(input; slot=:data)
    catch
        input
    end
    dir = startswith(resolved, ":") ? "" : dirname(resolved)
    base = (isempty(dir) || dir == ".") ? (stem * suffix) : joinpath(dir, stem * suffix)
    if endswith(lowercase(resolved), ".jls")
        return base * ".jls"
    elseif _is_handle_path(resolved)
        return resolve_save_path(base)
    else
        return base * ".csv"
    end
end

function _write_macro_data(obj, output::String; input_path::String, default_stem::String="",
                          warn_metadata::Bool=false)
    resolved_in = try
        resolve_stem(input_path; slot=:data)
    catch
        input_path
    end
    input_handle = _is_handle_path(resolved_in)
    if isempty(output)
        output = default_stem
        output = input_handle ? resolve_save_path(output) :
                 (endswith(lowercase(output), ".csv") ? output : output * ".csv")
    else
        output = input_handle ? resolve_save_path(output) : (
            occursin(r"\.[A-Za-z0-9]+$", basename(output)) ? output : output * ".csv")
    end
    want_jld = endswith(lowercase(output), ".jld2")
    if want_jld && !input_handle
        throw(CliError("usage/invalid",
            "refusing to write a .jld2 from CSV; run 'data import' first";
            hint="friedman data import $input_path --kind timeseries -o $(dataset_stem(input_path))"))
    end
    _validate_output_path(output)
    if input_handle
        try
            if isfile(output) && _resolve_path(output) == _resolve_path(resolved_in)
                _status("replacing $output")
            end
        catch
        end
    end
    if want_jld || _is_handle_path(output)
        save_model_dispatch(output, obj)
    else
        df = DataFrame(to_matrix(obj), varnames(obj))
        if nameof(typeof(obj)) === :PanelData
            insertcols!(df, 1, :group => obj.group_id, :time => obj.time_id; makeunique=true)
        end
        CSV.write(output, df)
        (input_handle || warn_metadata) && _status("CSV export dropped frequency/tcode/dates metadata")
    end
    _status("Written to $output")
    return output
end
