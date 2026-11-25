# Top-level `show` — render bounded structured summaries for any loadable handle
# (data, model, result, archive, or session URI) ([STORAGE-W5] #309)

"""Format an arbitrary Julia field value concisely so `frdc show` never dumps
megabytes of raw matrix text to stdout."""
function _format_field_preview(v; max_chars::Int=80)::String
    if v === nothing
        return "nothing"
    elseif v === missing
        return "missing"
    elseif v isa Bool
        return string(v)
    elseif v isa Integer
        return string(v)
    elseif v isa AbstractFloat
        return isfinite(v) ? string(round(Float64(v); digits=6)) : string(v)
    elseif v isa Symbol
        return ":" * string(v)
    elseif v isa AbstractString
        s = String(v)
        return length(s) > max_chars ? (first(s, max_chars - 1) * "…") : s
    elseif v isa AbstractVector{<:AbstractString}
        n = length(v)
        n <= 6 && return "[" * join(v, ", ") * "]"
        return "[" * join(v[1:4], ", ") * ", … ($n total)]"
    elseif v isa AbstractArray
        el = nameof(eltype(v))
        shp = join(size(v), "×")
        if v isa AbstractArray{<:Real} && !isempty(v)
            fin = filter(isfinite, vec(v))
            if !isempty(fin)
                lo = round(Float64(minimum(fin)); digits=4)
                hi = round(Float64(maximum(fin)); digits=4)
                return "$(el)[$shp] (min=$lo, max=$hi)"
            end
        end
        return "$(el)[$shp]"
    elseif v isa AbstractDict
        return "Dict($(length(v)) entries)"
    elseif v isa Tuple
        length(v) <= 4 && all(x -> x isa Union{Real,Symbol,AbstractString,Bool,Nothing}, v) &&
            return string(v)
        return "Tuple($(length(v)) items)"
    else
        tn = string(nameof(typeof(v)))
        dims = isdefined(@__MODULE__, :_extract_dims) ? _extract_dims(v) : Dict{String,Any}()
        return isempty(dims) ? "$tn(...)" : "$tn($(join(["$k=$val" for (k, val) in sort!(collect(dims); by=first)], ", ")))"
    end
end

"""Bound a DataFrame preview to at most `max_rows` rows and `max_cols` columns."""
function _bound_preview_df(df::DataFrame, max_rows::Int, max_cols::Int)
    nr, nc = nrow(df), ncol(df)
    r_keep = max_rows > 0 ? min(nr, max_rows) : nr
    c_keep = max_cols > 0 ? min(nc, max_cols) : nc
    sub = df[1:r_keep, 1:c_keep]
    truncated = (r_keep < nr) || (c_keep < nc)
    return sub, nr, nc, truncated
end

function _show_handle(; path::String="", data::String="",
                       max_rows::Int=20, max_cols::Int=12,
                       format::String="table", output::String="",
                       plot::Bool=false, plot_save::String="")
    p = !isempty(path) ? path : data
    isempty(p) && throw(CliError("usage/missing-arg", "show requires a handle stem"))
    max_rows >= 0 || throw(CliError("usage/invalid", "show: --max-rows must be ≥ 0 (got $max_rows)"))
    max_cols >= 0 || throw(CliError("usage/invalid", "show: --max-cols must be ≥ 0 (got $max_cols)"))

    if startswith(p, ":") || endswith(lowercase(_expanduser(p)), ".csv")
        df = load_data(p)
        sub, nr, nc, trunc = _bound_preview_df(df, max_rows, max_cols)
        trunc && _status("Showing $(nrow(sub))×$(ncol(sub)) of $(nr)×$(nc) (override with --max-rows/--max-cols)")
        output_result(sub; format=Symbol(format), output=output,
                      title="Data Preview ($(nr)×$(nc))", key="show_payload")
        _maybe_plot(df; plot=plot, plot_save=plot_save)
        return df
    end
    resolved = try
        resolve_stem(p; slot=:result)
    catch e
        if e isa CliError && e.code == "data/file-not-found" && isfile(_expanduser(p) * ".csv")
            df = load_data(_expanduser(p) * ".csv")
            sub, nr, nc, trunc = _bound_preview_df(df, max_rows, max_cols)
            trunc && _status("Showing $(nrow(sub))×$(ncol(sub)) of $(nr)×$(nc) (override with --max-rows/--max-cols)")
            output_result(sub; format=Symbol(format), output=output,
                          title="Data Preview ($(nr)×$(nc))", key="show_payload")
            _maybe_plot(df; plot=plot, plot_save=plot_save)
            return df
        end
        rethrow()
    end
    obj = load_model_dispatch(resolved)
    if obj isa AbstractDict
        keys_ = sort!(String[string(k) for k in keys(obj)])
        types = [string(nameof(typeof(obj[k]))) for k in keys_]
        dims  = [string(_extract_dims(obj[k])) for k in keys_]
        df = DataFrame(entry=keys_, type=types, dims=dims)
        sub, nr, nc, _ = _bound_preview_df(df, max_rows, max_cols)
        output_result(sub; format=Symbol(format),
                      output=output, title="Bundle Entries ($nr)", key="show_payload")
        _status("Bundle ($nr entries) not unpacked — use `frdc show $(resolved)#<entry>` to inspect an individual entry")
    else
        k = _data_kind_of(obj)
        # Only rectangular data containers have to_matrix / describe_data.
        # :io (IOData) and other kinds fall through — never to_matrix an IOData.
        if k in (:timeseries, :panel, :cross_section)
            Y = to_matrix(obj)
            vn = Vector{String}(MacroEconometricModels.varnames(obj))
            n_obs, n_vars = size(Y)
            summary = _status_stdout() do
                describe_data(obj)
            end
            fv = [something(findfirst(isfinite, @view Y[:, j]), 0) for j in 1:n_vars]
            lv = [something(findlast(isfinite, @view Y[:, j]), 0) for j in 1:n_vars]
            full_df = DataFrame(
                variable=vn, n=summary.n, first_valid=fv, last_valid=lv,
                mean=summary.mean, std=summary.std, min=summary.min,
                p25=summary.p25, median=summary.median, p75=summary.p75,
                max=summary.max, skewness=summary.skewness, kurtosis=summary.kurtosis,
            )
            sub, nr, nc, trunc = _bound_preview_df(full_df, max_rows, max(max_cols, 13))
            trunc && _status("Showing $(nrow(sub)) of $(nr) variables (override with --max-rows)")
            output_result(sub; format=Symbol(format), output=output,
                          title="Descriptive Statistics ($(n_obs)×$(n_vars))",
                          key="show_payload")
        elseif k === :tabular
            tbl = _coerce_tabular_dataframe(obj, resolved)
            sub, nr, nc, trunc = _bound_preview_df(tbl, max_rows, max_cols)
            trunc && _status("Showing $(nrow(sub))×$(ncol(sub)) of $(nr)×$(nc) (override with --max-rows/--max-cols)")
            output_result(sub; format=Symbol(format), output=output,
                          title="Data Preview ($(nr)×$(nc))",
                          key="show_payload")
        else
            tbl = try
                long_table(obj)
            catch
                try
                    DataFrame(obj)
                catch
                    nothing
                end
            end
            if tbl === nothing
                dims = _extract_dims(obj)
                vns = _model_varnames(obj)
                fields = String["type", "kind", "dimensions"]
                values = String[
                    string(nameof(typeof(obj))),
                    _storage_kind_tag(obj),
                    isempty(dims) ? "{}" : join(["$dk=$dv" for (dk, dv) in sort!(collect(dims); by=first)], ", "),
                ]
                if !isempty(vns)
                    push!(fields, "varnames")
                    push!(values, _format_field_preview(vns))
                end
                for pn in propertynames(obj)
                    s = string(pn)
                    startswith(s, "_") && continue
                    val_str = try
                        _format_field_preview(getproperty(obj, pn))
                    catch
                        "<unreadable>"
                    end
                    push!(fields, s)
                    push!(values, val_str)
                end
                df = DataFrame(field=fields, value=values)
                sub, nr, _, trunc = _bound_preview_df(df, max_rows > 0 ? max(max_rows, 25) : 0, 2)
                trunc && _status("Showing $(nrow(sub)) of $(nr) fields (override with --max-rows)")
                output_result(sub; format=Symbol(format), output=output,
                              title="Handle Summary ($(nameof(typeof(obj))))",
                              key="show_payload")
            else
                sub, nr, nc, trunc = _bound_preview_df(tbl, max_rows, max_cols)
                trunc && _status("Showing $(nrow(sub))×$(ncol(sub)) of $(nr)×$(nc) (override with --max-rows/--max-cols)")
                output_result(sub; format=Symbol(format), output=output,
                              title="Handle ($(nameof(typeof(obj))), $(nr)×$(nc))",
                              key="show_payload")
            end
        end
    end
    _maybe_plot(obj; plot=plot, plot_save=plot_save)
    return obj
end

function register_show_commands!()
    specs = [CommandSpec(
        path=["show"],
        summary="Render bounded structured summary of any loadable handle (data, model, result, archive#key, or session URI)",
        args=[ArgSpec(name="path", type=String, required=true,
                      description="Handle stem, path, archive.jld2#key, or session URI")],
        options=[
            OptionSpec(name="max-rows", type=Int, default=20,
                       description="Maximum preview rows to display (0 = unlimited; default: 20)"),
            OptionSpec(name="max-cols", type=Int, default=12,
                       description="Maximum preview columns to display (0 = unlimited; default: 12)"),
            OptionSpec(name="output", short="o", type=String, default="",
                       description="Write to file instead of stdout"),
            OptionSpec(name="format", short="f", type=String, default="table",
                       choices=["table","csv","json"], description="table|csv|json"),
            OptionSpec(name="plot-save", type=String, default="",
                       description="Save interactive plot to HTML file"),
        ],
        flags=[FlagSpec(name="plot", description="Open interactive plot if a recipe exists")],
        tables=[TableSpec(name=:show_payload, description="Bounded structured summary or preview of the handle")],
        category="show",
        handler=wrap_legacy(_show_handle),
    )]
    specs = register!(specs)
    return to_leaf(specs[1])
end
