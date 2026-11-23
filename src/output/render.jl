# Envelope renderers: :json | :table | :csv (P1-1; F17, F20, F66)

_json_cell_safe(x) = string(x)
_json_cell_safe(x::Nothing) = nothing
_json_cell_safe(x::Missing) = nothing
_json_cell_safe(x::Bool) = x
_json_cell_safe(x::Integer) = x
_json_cell_safe(x::AbstractFloat) = _json_safe(x)
_json_cell_safe(x::AbstractString) = x
_json_cell_safe(x::Symbol) = string(x)
_json_cell_safe(x::Tuple) = join(string.(x), ", ")
_json_cell_safe(x::AbstractVector) = join(string.(x), ", ")

function _table_payload(df::DataFrame)
    col_syms = names(df)
    ncols = length(col_syms)
    nrows = nrow(df)
    cols = Vector{String}(undef, ncols)
    col_vecs = Vector{AbstractVector}(undef, ncols)
    @inbounds for j in 1:ncols
        cols[j] = string(col_syms[j])
        col_vecs[j] = df[!, j]
    end
    rows = Vector{Vector{Any}}(undef, nrows)
    @inbounds for i in 1:nrows
        row = Vector{Any}(undef, ncols)
        for j in 1:ncols
            row[j] = _json_cell_safe(col_vecs[j][i])
        end
        rows[i] = row
    end
    return Dict{String,Any}("columns" => cols, "rows" => rows)
end

function _compact_df(df::DataFrame)
    (_COMPACT[]) || return df
    out = DataFrame()
    for name in names(df)
        col = df[!, name]
        out[!, name] = [v isa AbstractFloat && isfinite(v) ? round(Float64(v); sigdigits=4) : v for v in col]
    end
    return out
end

function _envelope_to_dict(env::Envelope)
    # Every `data` value is a table payload — the envelope-v1 schema enforces
    # exactly this shape (columns × rows), so nothing else may land here.
    data = Dict{String,Any}()
    for (name, df) in env.tables
        data[string(name)] = _table_payload(df)
    end

    doc = Dict{String,Any}(
        "schema_version" => env.schema_version,
        "command" => env.command,
        "status" => string(env.status),
        "meta" => Dict{String,Any}(string(k) => _json_safe(v) for (k, v) in env.meta),
        "data" => data,
        "warnings" => env.warnings,
        "artifacts" => env.artifacts,
    )
    if env.error !== nothing
        doc["error"] = env.error
    else
        doc["error"] = nothing
    end
    return doc
end

"""
    render(env::Envelope, fmt::Symbol, out::IO)

Render the envelope. `fmt` ∈ `_VALID_FORMATS` (`:json`, `:table`, `:csv`).
`:json` writes exactly one document + trailing newline.
`:table` pretty-prints every table.
`:csv` writes the first (primary) table only.
"""
function render(env::Envelope, fmt::Symbol, out::IO)
    fmt = _parse_format(fmt)
    if env.status == :error && env.error !== nothing && fmt != :json
        # Error path for human formats: message to stderr (exit code in C012)
        code = get(env.error, "code", "error")
        msg = get(env.error, "message", "")
        println(stderr, "$code: $msg")
        return
    end
    if fmt == :json
        doc = _envelope_to_dict(env)
        println(out, JSON3.write(doc))
    elseif fmt == :csv
        if isempty(env.tables)
            return
        end
        CSV.write(out, env.tables[1].second)
    else  # :table
        is_tty = out isa Base.TTY
        fit_tty = isdefined(@__MODULE__, :_COMPACT) && _COMPACT[] && is_tty
        for (name, df) in env.tables
            disp = isdefined(@__MODULE__, :_COMPACT) ? _compact_df(df) : df
            pretty_table(out, disp;
                title=string(name),
                alignment=:c,
                column_labels=names(disp),
                fit_table_in_display_horizontally=fit_tty,
                fit_table_in_display_vertically=fit_tty)
        end
    end
    return nothing
end
