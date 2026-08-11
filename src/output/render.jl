# Envelope renderers: :json | :table | :csv (P1-1; F17, F20, F66)

function _table_payload(df::DataFrame)
    cols = string.(names(df))
    rows = Any[]
    for r in eachrow(df)
        push!(rows, Any[_json_safe(r[c]) for c in names(df)])
    end
    return Dict{String,Any}("columns" => cols, "rows" => rows)
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
        for (name, df) in env.tables
            pretty_table(out, df; title=string(name), alignment=:c)
        end
    end
    return nothing
end
