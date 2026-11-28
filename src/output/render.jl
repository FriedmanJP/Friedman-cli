# Envelope renderers: :json | :table | :csv (P1-1; F17, F20, F66)
import Printf

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

const _FLOAT_FMT_F = ntuple(i -> Printf.Format("%.$(i - 1)f"), 17)
const _FLOAT_FMT_E = ntuple(i -> Printf.Format("%.$(i - 1)e"), 17)

"""
    _format_display_float(x::AbstractFloat, digits::Int) → String

Presentation-only numeric cell formatter (`[DISPLAY-W1]` #323). Formats finite floats
to fixed `digits` decimal places (default `3`), switches to scientific notation (`%.de`)
for extreme magnitudes `|x| >= 1e9`, normalizes signed zeros (`"-0.000"` → `"0.000"`),
and renders `NaN` / `Inf` / `-Inf` cleanly. Never mutates underlying `DataFrame` cells.
"""
function _format_display_float(x::AbstractFloat, digits::Int)::String
    isnan(x) && return "NaN"
    isinf(x) && return x > 0 ? "Inf" : "-Inf"
    d = clamp(digits, 0, 16)
    xf = Float64(x)
    xf == 0.0 && (xf = 0.0)
    s = abs(xf) >= 1e9 ? Printf.format(_FLOAT_FMT_E[d + 1], xf) :
                         Printf.format(_FLOAT_FMT_F[d + 1], xf)
    if startswith(s, "-") && all(c -> c == '0' || c == '.', @view s[2:end])
        return s[2:end]
    end
    return s
end

"""
    _make_table_formatter(digits) → Union{Nothing,Function}

Build a non-mutating PrettyTables v3 cell formatter dispatched strictly on
`v isa AbstractFloat`. Leaves `Int`, `Bool`, `String`, `Missing`, `Nothing`, and
other non-float values untouched (critical for integer columns and heterogeneous
`output_kv` tables).
"""
function _make_table_formatter(digits::Union{Int,Nothing})
    if digits === nothing
        return (v, i, j) -> if v isa AbstractFloat
            vf = (v == 0 && !isnan(v)) ? zero(v) : v
            string(vf)
        else
            v
        end
    end
    d = clamp(digits, 0, 16)
    return (v, i, j) -> v isa AbstractFloat ? _format_display_float(v, d) : v
end

"""
    _render_table(io, df; title="", fit_tty=false, digits=...)

Canonical non-mutating `:table` renderer shared by `render(env, :table, io)` and
`_write_table`. Applies presentation-only float formatting via PrettyTables v3
`formatters` without mutating or copying `df`.
"""
function _render_table(io::IO, df::DataFrame; title::String="", fit_tty::Bool=false,
                       digits::Union{Int,Nothing}=(isdefined(@__MODULE__, :_DISPLAY_DIGITS) ? _DISPLAY_DIGITS[] : 3))
    fmt = _make_table_formatter(digits)
    if fmt === nothing
        pretty_table(io, df;
            title=title,
            alignment=:c,
            column_labels=names(df),
            fit_table_in_display_horizontally=fit_tty,
            fit_table_in_display_vertically=fit_tty)
    else
        pretty_table(io, df;
            title=title,
            alignment=:c,
            column_labels=names(df),
            formatters=[fmt],
            fit_table_in_display_horizontally=fit_tty,
            fit_table_in_display_vertically=fit_tty)
    end
    return nothing
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
            _render_table(out, df; title=string(name), fit_tty=fit_tty)
        end
    end
    return nothing
end
