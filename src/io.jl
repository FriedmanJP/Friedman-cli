# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# IO utilities: CSV reading, table/CSV/JSON output

# ── Quiet-aware status helpers (P1-2; F21, F22) ───────────
# Status/progress goes to stderr so stdout stays data-only.
# `_QUIET` is set by the global-flag pre-pass (C014).

const _QUIET = Ref(false)
const _COLOR = Ref(true)
const _SEED = Ref{Union{Nothing,Int}}(nothing)
const _LAST_ARGV = Ref{Vector{String}}(String[])

_status(parts...) = _QUIET[] || println(stderr, parts...)
function _status_styled(args...; kwargs...)
    _QUIET[] && return nothing
    if !_COLOR[]
        print(stderr, args...)
        return nothing
    end
    printstyled(stderr, args...; kwargs...)
end
"""Run `f` with stdout redirected to stderr unless quiet (MEMs report() dumps)."""
_status_report(f::Function) = _QUIET[] || redirect_stdout(f, stderr)

"""
    _extract_global_flags!(args) → (remaining, force_json)

Scan argv left-to-right until the first non-flag token (P1-6). Mutates quiet/color/seed
state and strips global flags from the returned vector.
"""
function _extract_global_flags!(args::Vector{String})
    _QUIET[] = false
    _COLOR[] = !haskey(ENV, "NO_COLOR")
    _SEED[] = nothing
    force_json = false
    i = 1
    n = length(args)
    # Only leading globals (until first non-global token) — F61
    while i <= n
        tok = args[i]
        if tok == "--quiet" || tok == "-q"
            _QUIET[] = true
            i += 1
        elseif tok == "--no-color"
            _COLOR[] = false
            i += 1
        elseif tok == "--json"
            force_json = true
            i += 1
        elseif tok == "--seed"
            i + 1 <= n || throw(CliError("usage/bad-seed", "--seed requires an integer argument"))
            s = tryparse(Int, args[i + 1])
            s === nothing && throw(CliError("usage/bad-seed", "invalid --seed value '$(args[i + 1])'"))
            _SEED[] = s
            Random.seed!(s)
            i += 2
        elseif startswith(tok, "--seed=")
            raw = tok[8:end]
            s = tryparse(Int, raw)
            s === nothing && throw(CliError("usage/bad-seed", "invalid --seed value '$raw'"))
            _SEED[] = s
            Random.seed!(s)
            i += 1
        else
            break
        end
    end
    remaining = args[i:end]
    if force_json
        has_fmt = any(t -> startswith(t, "--format") || t == "-f", remaining)
        if !has_fmt
            remaining = vcat(remaining, String["--format", "json"])
        end
    end
    return remaining
end

# ── Path Validation ──────────────────────────────────────

"""
    _data_root() → String

Directory that file access is confined to, from `FRIEDMAN_DATA_ROOT`; empty when unset.

Confinement is opt-in. The old guard rejected any path whose *string* contained `..`,
which blocked ordinary relative paths (`../shared/data.csv` — with no workaround in
the REPL, which has no shell to resolve them) and even absolute paths whose filename
merely contained two dots, while still permitting any absolute path to anywhere. That
is not containment. Set `FRIEDMAN_DATA_ROOT` to get real containment; leave it unset
for normal filesystem access (#83).
"""
_data_root() = get(ENV, "FRIEDMAN_DATA_ROOT", "")

"""
    _resolve_path(path) → String

Expand `~`, make absolute, and normalize away `.`/`..` segments.
"""
_resolve_path(path::String) = normpath(abspath(expanduser(path)))

"""
    _validate_path(path, kind) → String

Confine `path` to `FRIEDMAN_DATA_ROOT` when that is set, comparing *normalized*
paths so `..` segments are resolved rather than pattern-matched. Returns `path`
unchanged (callers keep using the string the user gave).
"""
function _validate_path(path::String, kind::String)
    isempty(path) && return path
    root = _data_root()
    isempty(root) && return path

    resolved = _resolve_path(path)
    root_resolved = _resolve_path(root)
    sep = Base.Filesystem.path_separator
    inside = resolved == root_resolved ||
             startswith(resolved, endswith(root_resolved, sep) ? root_resolved : root_resolved * sep)
    inside || throw(CliError("data/bad-path",
        "$kind path escapes FRIEDMAN_DATA_ROOT: $path";
        hint="resolved to $resolved, which is outside $root_resolved"))
    return path
end

"""
    _validate_input_path(path) → String

Validate an input file path. See [`_validate_path`](@ref).
"""
_validate_input_path(path::String) = _validate_path(path, "input")

"""
    _validate_output_path(path) → String

Validate an output file path. See [`_validate_path`](@ref).
"""
_validate_output_path(path::String) = _validate_path(path, "output")

# ── Example datasets ─────────────────────────────────────

"""
Bundled MEMs example datasets that load as a rectangular table.

Single source of truth for `data list`, `data load <name>`, `load_data(":name")`
and the REPL's `data use :name` — keep every dataset-name surface derived from
this tuple so they cannot drift apart again.

`:wiot` is deliberately absent: it is an `IOData` archive with no `data`/`varnames`
and is served by the `io` command family instead.
"""
const EXAMPLE_DATASETS = (
    :fred_md, :fred_qd, :pwt, :mpdta, :ddcg,
    :denmark, :gnp_hamilton, :grunfeld, :mroz, :nile, :stackloss,
)

"""
    parse_dataset_name(name) → Symbol

Normalize a user-supplied example-dataset name to its MEMs symbol.

Accepts an optional leading `:` and either spelling of the separator, so
`fred_md`, `fred-md`, `:fred_md` and `:fred-md` all resolve to `:fred_md`.
Throws a typed `data/unknown-dataset` (exit 3) with a nearest-match hint for
anything else — never let the raw `ArgumentError` from `load_example` escape,
which surfaces as an exit-1 "likely a bug".
"""
function parse_dataset_name(name::AbstractString)
    stem = String(strip(name))
    startswith(stem, ":") && (stem = stem[2:end])
    sym = Symbol(replace(lowercase(stem), "-" => "_"))
    sym in EXAMPLE_DATASETS && return sym

    known = String[String(d) for d in EXAMPLE_DATASETS]
    hint = if sym === :wiot
        "the wiot input-output table is served by the 'io' family, e.g. 'friedman io leontief'"
    else
        sugg = _nearest(replace(lowercase(stem), "-" => "_"), known)
        isnothing(sugg) ? "run 'friedman data list' to see the available datasets" :
                          "did you mean '$sugg'?"
    end
    throw(CliError("data/unknown-dataset",
                   "unknown dataset '$name' (available: $(join(known, ", ")))"; hint=hint))
end

"""
    dataset_to_dataframe(dataset) → DataFrame

Convert a loaded MEMs example dataset to a DataFrame.

Panel datasets keep their identifiers as leading `group`/`time` columns — without
them every panel command (`estimate pvar`, `test cips`, …) fails on a bundled
panel because `--id-col`/`--time-col` have nothing to bind to.
"""
function dataset_to_dataframe(dataset)
    df = DataFrame(to_matrix(dataset), varnames(dataset); makeunique=true)
    if dataset isa PanelData
        insertcols!(df, 1, :group => dataset.group_id, :time => dataset.time_id;
                    makeunique=true)
    end
    return df
end

"""
    dataset_stem(source) → String

Filename stem for a data source, used to build default output paths.

Strips the `:` marker from a dataset reference (so `:fred-md` yields `fred_md`,
not a file literally named `:fred-md_clean.csv`) and the extension from a path.
"""
function dataset_stem(source::AbstractString)
    s = String(source)
    startswith(s, ":") && return replace(lowercase(s[2:end]), "-" => "_")
    return replace(basename(s), r"\.[^.]+$" => "")
end

"""
    load_data(path) → DataFrame

Read a CSV file and return a DataFrame. Validates that the file exists and is non-empty.

A `:name` reference (e.g. `:fred_md`) loads a bundled example dataset instead.
`~` is expanded here rather than relying on the shell, because the REPL has none.
"""
function load_data(path::String)
    if startswith(path, ":")
        return dataset_to_dataframe(load_example(parse_dataset_name(path)))
    end
    path = expanduser(path)
    _validate_input_path(path)
    isfile(path) || throw(CliError("data/file-not-found", "file not found: $path"; hint="check the path"))
    df = CSV.read(path, DataFrame)
    nrow(df) == 0 && throw(CliError("data/empty", "empty dataset: $path"))
    return df
end

"""
    _numeric_column_names(df) → Vector{String}

Return the names of numeric columns in a DataFrame.
"""
_numeric_column_names(df::DataFrame) =
    [n for n in names(df) if eltype(df[!, n]) <: Union{Number, Missing}]

"""
    df_to_matrix(df) → Matrix{Float64}

Convert a DataFrame to a numeric matrix, selecting only numeric columns.
"""
function df_to_matrix(df::DataFrame)
    numeric_cols = _numeric_column_names(df)
    isempty(numeric_cols) && throw(CliError("data/no-numeric-columns", "no numeric columns found in data"))
    mat = Matrix{Float64}(df[!, numeric_cols])
    return mat
end

"""
    variable_names(df) → Vector{String}

Extract numeric column names from a DataFrame.
"""
variable_names(df::DataFrame) = _numeric_column_names(df)

const _VALID_FORMATS = (:table, :csv, :json)

"""
    _parse_format(format) → Symbol

Normalize and validate an output format. Errors on anything not in table|csv|json.
"""
function _parse_format(format::Union{String,Symbol})
    fmt = Symbol(lowercase(String(format)))
    fmt in _VALID_FORMATS || throw(CliError("usage/bad-format", "unknown format '$(format)' (expected: table|csv|json)"))
    return fmt
end

"""
    output_result(result, varnames; format, output, title)

Route output to table (terminal), CSV, or JSON based on `format`.
- `result`: a Matrix or DataFrame
- `varnames`: column names
- `format`: table, csv, or json (String or Symbol)
- `output`: file path (empty string = stdout)
- `title`: table title for terminal display
"""
function output_result(result::AbstractMatrix, varnames::Vector{String};
                       format::Union{String,Symbol}="table", output::String="", title::String="Results")
    df = DataFrame(result, varnames)
    output_result(df; format=format, output=output, title=title)
end

"""Slug a table title for envelope keys: lowercase, non-alnum → `_`."""
function _slug(title::String)
    s = lowercase(title)
    s = replace(s, r"[^a-z0-9]+" => "_")
    s = replace(s, r"^_+|_+$" => "")
    s = replace(s, r"_+" => "_")
    return isempty(s) ? "table" : s
end

function output_result(df::DataFrame; format::Union{String,Symbol}=:table, output::String="", title::String="Results")
    fmt = _parse_format(format)
    _validate_output_path(output)
    # Accumulate into active JSON envelope instead of printing (C010 / F17)
    if envelope_active() && fmt == :json
        if isempty(output)
            add_table!(_ENVELOPE[], Symbol(_slug(title)), df)
            return
        else
            _write_json(df, output)
            add_artifact!(_ENVELOPE[], "file", output)
            return
        end
    end
    if fmt == :csv
        _write_csv(df, output)
    elseif fmt == :json
        _write_json(df, output)
    else
        _write_table(df, output, title)
    end
end

"""
    output_kv(pairs; format, output, title)

Output key-value results (e.g., test statistics).
"""
function output_kv(pairs::Vector{<:Pair{String}}; format::Union{String,Symbol}="table", output::String="", title::String="Results")
    fmt = _parse_format(format)
    _validate_output_path(output)
    if envelope_active() && fmt == :json
        df = DataFrame(; metric=first.(pairs), value=last.(pairs))
        if isempty(output)
            add_table!(_ENVELOPE[], Symbol(_slug(title)), df)
            return
        else
            _write_json(df, output)
            add_artifact!(_ENVELOPE[], "file", output)
            return
        end
    end
    if fmt == :json
        d = Dict(pairs)
        _write_json_raw(d, output)
    elseif fmt == :csv
        df = DataFrame(; metric=first.(pairs), value=last.(pairs))
        _write_csv(df, output)
    else
        df = DataFrame(; metric=first.(pairs), value=last.(pairs))
        _write_table(df, output, title)
    end
end

# Internal helpers

function _write_table(df::DataFrame, output::String, title::String)
    io = isempty(output) ? stdout : open(output, "w")
    try
        pretty_table(io, df;
            title=title,
            alignment=:c)
    finally
        isempty(output) || close(io)
    end
    isempty(output) || _status("Results written to $output")
end

function _write_csv(df::DataFrame, output::String)
    if isempty(output)
        CSV.write(stdout, df)
    else
        CSV.write(output, df)
        _status("Results written to $output")
    end
end

function _write_json(df::DataFrame, output::String)
    rows = [Dict(string(k) => v for (k, v) in zip(names(df), r)) for r in eachrow(df)]
    _write_json_raw(rows, output)
end

function _write_json_raw(data, output::String)
    # Sanitize non-finite floats (Inf/NaN → "Inf"/"NaN" strings) BEFORE JSON3.write, which
    # rejects them ("… not allowed in JSON spec") and would crash the legacy-output path
    # (FRIEDMAN_LEGACY_OUTPUT=1 -f json) — unlike the envelope path, which already applies
    # `_json_safe`. This is the class-fix flagged since C067a: any handler emitting an Inf/NaN
    # in a kv/table is now rendered gracefully on BOTH json paths, not just the envelope.
    json_str = JSON3.write(_json_safe(data))
    if isempty(output)
        println(json_str)  # data path — stays on stdout
    else
        open(output, "w") do io
            write(io, json_str)
        end
        _status("Results written to $output")
    end
end
