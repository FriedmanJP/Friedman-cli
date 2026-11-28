function resolve_save_path(path::String; default_ext::String=".jld2")::String
    isempty(path) && return path
    _is_session_uri(path) && return path
    base, key = _split_key_selector(path)
    p = _expanduser(base)
    out = !isempty(_known_ext(p)) ? p : (p * default_ext)
    return key === nothing ? out : "$(out)#$(key)"
end

function resolve_stem(path::String; slot::Symbol=:data)::String
    ref = resolve_read_ref(path; slot=slot)
    return ref_string(ref)
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
    _is_session_uri(path) && return true
    ref = parse_handle_ref(path)
    return ref.format in (:jld2, :jls, :fmod)
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
    base_res, _ = _split_key_selector(resolved)
    dir = (startswith(resolved, ":") || _is_session_uri(resolved)) ? "" : dirname(base_res)
    base = (isempty(dir) || dir == ".") ? (stem * suffix) : joinpath(dir, stem * suffix)
    if endswith(lowercase(base_res), ".jls")
        return base * ".jls"
    elseif _is_handle_path(resolved)
        return resolve_save_path(base)
    else
        return base * ".csv"
    end
end

function _write_macro_data(obj, output::String; input_path::String, default_stem::String="",
                          warn_metadata::Bool=false, include_dates::Bool=true)
    resolved_in = try
        resolve_stem(input_path; slot=:data)
    catch
        input_path
    end
    input_handle = _is_handle_path(resolved_in) || startswith(resolved_in, ":")
    if isempty(output)
        output = default_stem
        output = input_handle ? resolve_save_path(output) :
                 (endswith(lowercase(output), ".csv") ? _expanduser(output) : _expanduser(output) * ".csv")
    elseif _is_session_uri(output)
        # Session URI handled directly by save_model_dispatch
    else
        output = input_handle ? resolve_save_path(output) : (
            !isempty(_known_ext(_expanduser(output))) ? _expanduser(output) : _expanduser(output) * ".csv")
    end
    want_jld = !_is_session_uri(output) && endswith(lowercase(output), ".jld2")
    if want_jld && !input_handle
        throw(CliError("usage/invalid",
            "refusing to write a .jld2 from CSV; run 'data import' first";
            hint="frdc data import $input_path --kind timeseries -o $(dataset_stem(input_path))"))
    end
    if !_is_session_uri(output)
        output = _validate_output_path(output; create_parents=true)
    end
    if input_handle && !_is_session_uri(output) && !_is_session_uri(resolved_in)
        try
            base_in, _ = _split_key_selector(resolved_in)
            if isfile(output) && _resolve_path(output) == _resolve_path(base_in)
                _status("replacing $output")
            end
        catch
        end
    end
    if want_jld || _is_handle_path(output)
        save_model_dispatch(output, obj; artifact_kind="data")
    else
        df = _coerce_tabular_dataframe(obj, input_path; include_dates=include_dates)
        _atomic_write(output, tmp -> CSV.write(tmp, df))
        (input_handle || warn_metadata) && _status("CSV export dropped frequency/tcode metadata")
    end
    _status("Written to $output")
    return output
end
