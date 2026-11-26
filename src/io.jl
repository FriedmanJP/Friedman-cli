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
const _COMPACT = Ref(false)
const _FORCE_JSON = Ref(false)
const _ENVELOPE_JSON_TO_FILE = Ref(false)
const _DEFAULT_DISPLAY_DIGITS = 3
const _DISPLAY_DIGITS = Ref{Union{Int,Nothing}}(_DEFAULT_DISPLAY_DIGITS)

"""
    _parse_display_digits(raw) → Union{Int,Nothing}

Parse a `--digits` / `FRDC_DIGITS` value: `"full"` (case-insensitive) → `nothing`
(unrounded table floats), or a strict decimal integer `0..16`. Rejects everything
else with typed `CliError("usage/bad-digits", ...)` (exit `2`).
"""
function _parse_display_digits(raw::AbstractString)::Union{Int,Nothing}
    s = strip(String(raw))
    isempty(s) && throw(CliError("usage/bad-digits",
        "invalid --digits value ''";
        hint="pass an integer 0..16 or 'full'"))
    lowercase(s) == "full" && return nothing
    if !all(c -> '0' <= c <= '9', s)
        throw(CliError("usage/bad-digits",
            "invalid --digits value '$raw'";
            hint="pass an integer 0..16 or 'full'"))
    end
    d = tryparse(Int, s)
    (d === nothing || d < 0 || d > 16) && throw(CliError("usage/bad-digits",
        "invalid --digits value '$raw' (must be 0..16 or 'full')";
        hint="pass an integer 0..16 or 'full'"))
    return d
end

function _default_display_digits()::Union{Int,Nothing}
    raw = get(ENV, "FRDC_DIGITS", "")
    isempty(strip(raw)) && return _DEFAULT_DISPLAY_DIGITS
    return _parse_display_digits(raw)
end

_status(parts...) = _QUIET[] || println(stderr, parts...)
function _status_styled(args...; kwargs...)
    _QUIET[] && return nothing
    if !_COLOR[]
        print(stderr, args...)
        return nothing
    end
    printstyled(stderr, args...; kwargs...)
end
"""
Run `f` with stdout redirected to stderr unless quiet (MEMs `report()` dumps).

A failure inside `f` is swallowed with a note on stderr rather than propagated. This is a
**human-readable convenience summary**; the data the agent contract promises has already
been (or is about to be) written to stdout, so a broken pretty-printer must not fail the
command.

That is not hypothetical: at MEMs 0.7.2 `_select_horizons(H)` returns `[1, 4, 8, H]` for
`5 < H <= 12`, so `show(::ImpulseResponse)` indexes horizon 8 of an H-horizon array and
`irf var --horizons 6|7` died with an untyped `BoundsError` (exit 1, "likely a bug") even
though `long_table` produced a perfectly good result. Upstream display bugs are now a
missing summary, not a failed run.
"""
function _status_report(f::Function)
    _QUIET[] && return nothing
    isdefined(@__MODULE__, :_IN_DISPATCH) && _IN_DISPATCH[] && return nothing
    try
        redirect_stdout(f, stderr)
    catch e
        _status("(summary display failed: $(sprint(showerror, e)); results are unaffected)")
    end
    return nothing
end

"""
Run `f` with stdout captured and replay any text via `_status` (stderr).

Always runs `f` (including `--quiet`) so the return value is kept. Julia 1.13
has no `redirect_stdout(IOBuffer)` method — capture uses a tempfile.
"""
function _status_stdout(f::Function)
    path, io = mktemp()
    try
        val = redirect_stdout(io) do
            f()
        end
        close(io)
        txt = String(strip(read(path, String)))
        !isempty(txt) && _status(txt)
        return val
    finally
        try; close(io); catch; end
        try; rm(path; force=true); catch; end
    end
end

function _probe_target_command(args::Vector{String}, stop_idx::Int)
    isdefined(@__MODULE__, :APP) || return (nothing, String[], stop_idx + 1)
    node = APP.root
    path = String[]
    first_cmd_idx = stop_idx + 1
    i = 1
    while i <= stop_idx
        tok = args[i]
        if tok == "--quiet" || tok == "--no-color" || tok == "--json" || tok == "--compact" ||
           startswith(tok, "--seed=") || startswith(tok, "--digits=") ||
           (tok == "-q" && isempty(path))
            i += 1
        elseif tok == "--seed" || tok == "--digits"
            i += 2
        elseif startswith(tok, "-")
            i += 1
        elseif isdefined(@__MODULE__, :NodeCommand) && node isa NodeCommand
            canon = hasproperty(node, :aliases) ? get(node.aliases, tok, tok) : tok
            if isempty(path) && canon == "schema"
                first_cmd_idx == stop_idx + 1 && (first_cmd_idx = i)
                push!(path, "schema")
                return (nothing, path, first_cmd_idx)
            end
            sub = get(node.subcmds, canon, nothing)
            if sub === nothing
                break
            end
            first_cmd_idx == stop_idx + 1 && (first_cmd_idx = i)
            push!(path, canon)
            if isdefined(@__MODULE__, :LeafCommand) && sub isa LeafCommand
                return (sub, path, first_cmd_idx)
            end
            node = sub
            i += 1
        else
            break
        end
    end
    return (nothing, path, first_cmd_idx)
end

function _explicit_format_in(args::Vector{String}, stop_idx::Int)
    fmt_val = nothing
    for i in 1:stop_idx
        tok = args[i]
        if startswith(tok, "--format=")
            fmt_val = tok[10:end]
        elseif startswith(tok, "-f=")
            fmt_val = tok[4:end]
        elseif (tok == "--format" || tok == "-f") && i + 1 <= stop_idx
            fmt_val = args[i + 1]
        end
    end
    return fmt_val
end

"""
    _extract_global_flags!(args) → remaining

Scan argv before `--` for global flags (`--quiet`/`-q`, `--no-color`, `--json`,
`--compact`, `--seed`). Mutates global state and strips hoisted globals from the
returned vector while preserving leaf-owned mid-argv `--seed`/`-q`/`--compact`.
"""
function _extract_global_flags!(args::Vector{String})
    _QUIET[] = false
    _COLOR[] = !haskey(ENV, "NO_COLOR")
    _SEED[] = nothing
    _COMPACT[] = false
    _FORCE_JSON[] = false
    _DISPLAY_DIGITS[] = _DEFAULT_DISPLAY_DIGITS

    dd = findfirst(==("--"), args)
    stop_idx = dd === nothing ? length(args) : dd - 1

    leaf, cmd_path, first_cmd_idx = _probe_target_command(args, stop_idx)
    leaf_owns_seed = leaf !== nothing && any(o -> o.name == "seed", leaf.options)
    leaf_owns_q = leaf !== nothing && (
        any(o -> o.short == "q", leaf.options) || any(f -> f.short == "q", leaf.flags)
    )
    leaf_owns_compact = leaf !== nothing && (
        any(o -> o.name == "compact", leaf.options) || any(f -> f.name == "compact", leaf.flags)
    )
    leaf_has_format = leaf === nothing ? true : any(o -> o.name == "format", leaf.options)
    leaf_is_serve = cmd_path == ["serve"]
    leaf_is_completions = !isempty(cmd_path) && cmd_path[1] == "completions"
    leaf_is_schema = !isempty(cmd_path) && cmd_path[1] == "schema"

    remaining = String[]
    sizehint!(remaining, length(args))
    force_json = false
    explicit_digits = false
    cli_digits = _DEFAULT_DISPLAY_DIGITS
    i = 1
    while i <= stop_idx
        tok = args[i]
        is_leading = i < first_cmd_idx
        if tok == "--quiet"
            _QUIET[] = true
            i += 1
        elseif tok == "-q" && (is_leading || !leaf_owns_q)
            _QUIET[] = true
            i += 1
        elseif tok == "--no-color"
            _COLOR[] = false
            i += 1
        elseif tok == "--compact" && (is_leading || !leaf_owns_compact)
            _COMPACT[] = true
            i += 1
        elseif tok == "--json"
            force_json = true
            i += 1
        elseif tok == "--digits"
            i + 1 <= stop_idx || throw(CliError("usage/bad-digits",
                "--digits requires a value (0..16 or 'full')";
                hint="pass an integer 0..16 or 'full'"))
            cli_digits = _parse_display_digits(args[i + 1])
            explicit_digits = true
            i += 2
        elseif startswith(tok, "--digits=")
            cli_digits = _parse_display_digits(tok[10:end])
            explicit_digits = true
            i += 1
        elseif tok == "--seed"
            i + 1 <= stop_idx || throw(CliError("usage/bad-seed", "--seed requires an integer argument"))
            s = tryparse(Int, args[i + 1])
            s === nothing && throw(CliError("usage/bad-seed", "invalid --seed value '$(args[i + 1])'"))
            _SEED[] = s
            Random.seed!(s)
            if !is_leading && leaf_owns_seed
                push!(remaining, tok)
                push!(remaining, args[i + 1])
            end
            i += 2
        elseif startswith(tok, "--seed=")
            raw = tok[8:end]
            s = tryparse(Int, raw)
            s === nothing && throw(CliError("usage/bad-seed", "invalid --seed value '$raw'"))
            _SEED[] = s
            Random.seed!(s)
            if !is_leading && leaf_owns_seed
                push!(remaining, tok)
            end
            i += 1
        else
            push!(remaining, tok)
            i += 1
        end
    end
    if dd !== nothing
        append!(remaining, @view args[dd:end])
    end

    _DISPLAY_DIGITS[] = explicit_digits ? cli_digits : _default_display_digits()
    _FORCE_JSON[] = force_json
    if force_json
        rem_stop = dd === nothing ? length(remaining) : findfirst(==("--"), remaining) - 1
        explicit_fmt = _explicit_format_in(remaining, rem_stop)
        if explicit_fmt !== nothing
            if lowercase(explicit_fmt) != "json"
                throw(CliError("usage/invalid",
                    "conflicting output flags: --json cannot be combined with --format $explicit_fmt";
                    hint="pass either --json or --format $explicit_fmt, not both"))
            end
        elseif leaf_is_serve
            throw(CliError("usage/invalid",
                "--json cannot be used with `frdc serve` (stdout is reserved for JSON-RPC)"))
        elseif leaf_is_completions || leaf_is_schema
            # Handled natively by completions envelope wrapper or schema's raw JSON output
        elseif leaf_has_format
            # Insert before `--` if present so it's parsed as an option
            if dd === nothing
                push!(remaining, "--format", "json")
            else
                pos_dd = findfirst(==("--"), remaining)
                splice!(remaining, pos_dd:pos_dd-1, String["--format", "json"])
            end
        end
    end
    return remaining
end

"""
    _argv_wants_json(args) → Bool

True when the RAW argv (before `--`) asks for JSON output: an exact `--format json` /
`--format=json` / `-f json` / `-f=json` / `--json` token (pair) anywhere before `--`.
Used by `run_cli`'s error net, which must decide BEFORE tokenize/bind_args run.
"""
function _argv_wants_json(args::Vector{String})
    dd = findfirst(==("--"), args)
    stop_idx = dd === nothing ? length(args) : dd - 1
    for i in 1:stop_idx
        tok = args[i]
        (tok == "--format=json" || tok == "-f=json" || tok == "--json") && return true
        (tok == "--format" || tok == "-f") && i + 1 <= stop_idx && args[i+1] == "json" && return true
    end
    return false
end

# ── Path Validation ──────────────────────────────────────

"""
    _expanduser(path) → String

Expand a leading `~` on every platform.

`Base.expanduser` is a no-op on Windows (there `~` historically marks a temporary
file), so relying on it would make `~/data.csv` work on macOS/Linux and fail with a
bare file-not-found on Windows — the CLI is agent-first and must behave identically
on all three. `~user` forms are returned untouched: Base throws an untyped
`ArgumentError` for them, which would surface as an internal error (exit 1) instead
of the normal typed `data/file-not-found`.
"""
function _expanduser(path::AbstractString)
    p = String(path)
    startswith(p, "~") || return p
    length(p) == 1 && return homedir()
    if Sys.iswindows()
        c = p[2]
        (c == '/' || c == '\\') || return p          # `~user\...` — leave for the caller to report
        return joinpath(homedir(), lstrip(ch -> ch == '/' || ch == '\\', p[3:end]))
    end
    return try
        expanduser(p)
    catch e
        e isa ArgumentError ? p : rethrow()          # `~user/...` is unimplemented in Base
    end
end

"""
    _env_get(primary, legacy, default=nothing)
    _env_get(keys::Tuple{Vararg{String}}, default=nothing)

Read a runtime environment variable preferring `FRDC_*` with silent fallback to
legacy `FRIEDMAN_*` names (#300).
"""
function _env_get(primary::String, legacy::String, default=nothing)
    haskey(ENV, primary) && return ENV[primary]
    haskey(ENV, legacy) && return ENV[legacy]
    return default
end
function _env_get(keys::Tuple{Vararg{String}}, default=nothing)
    for k in keys
        haskey(ENV, k) && return ENV[k]
    end
    return default
end

"""
    _data_root() → String

Directory that file access is confined to, from `FRDC_DATA_ROOT` (fallback:
`FRIEDMAN_DATA_ROOT`); empty when unset.

Confinement is opt-in. The old guard rejected any path whose *string* contained `..`,
which blocked ordinary relative paths (`../shared/data.csv` — with no workaround in
the REPL, which has no shell to resolve them) and even absolute paths whose filename
merely contained two dots, while still permitting any absolute path to anywhere. That
is not containment. Set `FRDC_DATA_ROOT` to get real containment; leave it unset
for normal filesystem access (#83, #300).
"""
_data_root() = String(something(_env_get("FRDC_DATA_ROOT", "FRIEDMAN_DATA_ROOT", ""), ""))

"""
    _resolve_path(path) → String

Expand `~`, make absolute, and normalize away `.`/`..` segments.
"""
_resolve_path(path::String) = normpath(abspath(_expanduser(path)))

"""Resolve symlinks on an existing path or its deepest existing ancestor."""
function _canonical_for_confinement(path::String)::String
    resolved = _resolve_path(path)
    if ispath(resolved) || islink(resolved)
        try; return realpath(resolved); catch; return resolved; end
    end
    parts = String[]
    cur = resolved
    while true
        parent = dirname(cur)
        parent == cur && break
        pushfirst!(parts, basename(cur))
        cur = parent
        if ispath(cur)
            base_real = try; realpath(cur); catch; cur; end
            return normpath(joinpath(base_real, parts...))
        end
    end
    return resolved
end

"""
    _validate_path(path, kind) → String

Confine `path` to `FRDC_DATA_ROOT` when that is set, comparing *normalized*
symlink-resolved paths so `..` segments and symlinks cannot escape. Returns the
expanded path string.
"""
function _validate_path(path::String, kind::String)
    isempty(path) && return path
    exp = _expanduser(path)
    root = _data_root()
    isempty(root) && return exp

    resolved = _canonical_for_confinement(exp)
    root_resolved = _canonical_for_confinement(root)
    sep = Base.Filesystem.path_separator
    inside = resolved == root_resolved ||
             startswith(resolved, endswith(root_resolved, sep) ? root_resolved : root_resolved * sep)
    inside || throw(CliError("data/bad-path",
        "$kind path escapes FRDC_DATA_ROOT: $path";
        hint="resolved to $resolved, which is outside $root_resolved"))
    return exp
end

"""
    _validate_input_path(path) → String

Validate an input file path and return its `~`-expanded form. See [`_validate_path`](@ref).
"""
_validate_input_path(path::String) = _validate_path(path, "input")

"""
    _validate_output_path(path; create_parents=false) → String

Validate an output file path, returning its `~`-expanded form. Creates missing
parent directories when `create_parents=true`. See [`_validate_path`](@ref).
"""
function _validate_output_path(path::String; create_parents::Bool=false)
    isempty(path) && return path
    exp = _validate_path(path, "output")
    parent = dirname(abspath(exp))
    if !isempty(parent) && !isdir(parent)
        if create_parents
            mkpath(parent)
        else
            throw(CliError("data/file-not-found",
                "output directory does not exist: $parent";
                hint="create the directory first (e.g. mkdir -p $parent)"))
        end
    end
    return exp
end

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
    :denmark, :gnp_hamilton, :grunfeld, :mp_shocks, :mroz, :nile, :stackloss,
)

# Precompile-time bundle of all MEMs example datasets (+ :wiot for `io`), ~2.86 MB total.
# PackageCompiler clears `Base.pkgorigins` in sysimages, making `pkgdir(MacroEconometricModels)`
# return `nothing` at runtime so raw `load_example` fails to locate `<pkg>/data/*.toml`.
# Under `test/runtests.jl` (`mocks.jl`), `pkgdir(MacroEconometricModels) === nothing`, so this
# Dict stays empty at zero cost and `_load_example` delegates to mock `load_example`.
const _BUNDLED_EXAMPLES = let
    d = Dict{Symbol,Any}()
    if isdefined(@__MODULE__, :MacroEconometricModels)
        pkg_root = pkgdir(MacroEconometricModels)
        if pkg_root !== nothing
            data_dir = joinpath(pkg_root, "data")
            if isdir(data_dir)
                for f in readdir(data_dir; join=true)
                    endswith(f, ".toml") && Base.include_dependency(f)
                end
            end
            for sym in (EXAMPLE_DATASETS..., :wiot)
                d[sym] = load_example(sym)
            end
        end
    end
    d
end

"""
    _load_example(name::Symbol)

Load a bundled MEMs example dataset, returning a fresh `deepcopy` from `_BUNDLED_EXAMPLES`
when precompiled (works in relocated sysimages with zero disk/depot dependency) and
falling back to `load_example(name)` otherwise (unit-test mocks and unknown-name errors).
"""
function _load_example(name::Symbol)
    haskey(_BUNDLED_EXAMPLES, name) && return deepcopy(_BUNDLED_EXAMPLES[name])
    return load_example(name)
end

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
        "the wiot input-output table is served by the 'io' family, e.g. 'frdc io leontief'"
    else
        sugg = _nearest(replace(lowercase(stem), "-" => "_"), known)
        isnothing(sugg) ? "run 'frdc data list' to see the available datasets" :
                          "did you mean '$sugg'?"
    end
    throw(CliError("data/unknown-dataset",
                   "unknown dataset '$name' (available: $(join(known, ", ")))"; hint=hint))
end

"""
    dataset_to_dataframe(dataset) → DataFrame

Convert a loaded MEMs example dataset to a DataFrame.

Panel datasets keep their identifiers as leading `group`/`time` columns — without
them every panel command (`estimate panel pvar`, `test unit-root cips`, …) fails on a bundled
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
    # Strip optional #key selector before basename
    if isdefined(@__MODULE__, :_split_key_selector)
        s, _ = _split_key_selector(s)
    end
    bn = basename(s)
    # Strip only known handle/data extensions so dotted stems like macro.v1.csv -> macro.v1
    lbn = lowercase(bn)
    for ext in (".jld2", ".jls", ".fmod", ".csv", ".tsv", ".parquet", ".xlsx", ".xls", ".dta", ".sav", ".sas7bdat", ".json")
        if endswith(lbn, ext) && length(bn) > length(ext)
            return bn[1:prevind(bn, end - ncodeunits(ext) + 1)]
        end
    end
    return bn
end

"""
    load_data(path) → DataFrame

Read a CSV file or a typed data handle (`.jld2`/`.fmod`/`model://`) and return a
DataFrame. Validates that the file exists and is non-empty.

A `:name` reference (e.g. `:fred_md`) loads a bundled example dataset instead.
`~` is expanded here rather than relying on the shell, because the REPL has none.

Handle suffix is checked inline (not `_is_handle_path`): `handles.jl` is included
after `io.jl` and must not be reordered. `load_model_dispatch` / `_data_kind_of`
resolve at call time. `model://` skips `FRIEDMAN_DATA_ROOT` confinement (same as
wrap_legacy). Only `:timeseries` / `:panel` / `:cross_section` convert to a
DataFrame; `:io` and other payloads are `data/wrong-kind`.
"""
function _coerce_tabular_dataframe(obj, path::String; include_dates::Bool=false)::DataFrame
    k = _data_kind_of(obj)
    if k in (:timeseries, :panel, :cross_section)
        df = DataFrame(to_matrix(obj), varnames(obj); makeunique=true)
        if k === :panel
            insertcols!(df, 1, :group => obj.group_id, :time => obj.time_id; makeunique=true)
        elseif k === :timeseries && include_dates && hasproperty(obj, :dates)
            dts = obj.dates
            if dts isa AbstractVector && length(dts) == nrow(df) && !all(isempty, dts)
                insertcols!(df, 1, :dates => String[string(d) for d in dts]; makeunique=true)
            end
        end
        nrow(df) == 0 && throw(CliError("data/empty", "empty dataset: $path"))
        return df
    elseif k === :tabular
        df = if obj isa DataFrame
            copy(obj)
        elseif obj isa AbstractMatrix
            DataFrame(obj, ["x$j" for j in 1:size(obj, 2)]; makeunique=true)
        elseif obj isa AbstractVector
            DataFrame(:y => obj)
        elseif obj isa NamedTuple
            DataFrame(obj)
        else
            throw(CliError("data/wrong-kind", "$path is not a data container (got $(typeof(obj)))"))
        end
        (nrow(df) == 0 || ncol(df) == 0) && throw(CliError("data/empty", "empty dataset: $path"))
        return df
    end
    throw(CliError("data/wrong-kind",
        "$path is not a data container (got $(typeof(obj)))"))
end

function load_data(path::String)
    if startswith(path, ":")
        return dataset_to_dataframe(_load_example(parse_dataset_name(path)))
    end
    is_sess = startswith(path, "model://") || startswith(path, "data://") ||
              startswith(path, "result://") || startswith(path, "mem://")
    if is_sess
        obj = load_model_dispatch(path)
        return _coerce_tabular_dataframe(obj, path)
    end
    base_path, key_sel = isdefined(@__MODULE__, :_split_key_selector) ?
        _split_key_selector(path) : (path, nothing)
    exp_base = _validate_input_path(base_path)
    lc = lowercase(exp_base)
    if endswith(lc, ".jld2") || endswith(lc, ".jls") || endswith(lc, ".fmod")
        full_ref = key_sel === nothing ? exp_base : "$(exp_base)#$(key_sel)"
        obj = load_model_dispatch(full_ref)
        return _coerce_tabular_dataframe(obj, path)
    end
    isfile(exp_base) || throw(CliError("data/file-not-found", "file not found: $exp_base"; hint="check the path"))
    df = CSV.read(exp_base, DataFrame)
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
function _fill_matrix_col!(mat::AbstractMatrix{Float64}, j::Int, col::AbstractVector)
    @inbounds for i in eachindex(col)
        mat[i, j] = Float64(col[i])
    end
    return nothing
end

function df_to_matrix(df::DataFrame)
    numeric_cols = _numeric_column_names(df)
    isempty(numeric_cols) && throw(CliError("data/no-numeric-columns", "no numeric columns found in data"))
    nr = nrow(df)
    nc = length(numeric_cols)
    mat = Matrix{Float64}(undef, nr, nc)
    for (j, colname) in enumerate(numeric_cols)
        _fill_matrix_col!(mat, j, df[!, colname])
    end
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
                       format::Union{String,Symbol}="table", output::String="", title::String="Results",
                       key::AbstractString="")
    df = DataFrame(result, varnames)
    output_result(df; format=format, output=output, title=title, key=key)
end

"""Slug a table title for envelope keys: lowercase, non-alnum → `_`."""
function _slug(title::AbstractString)
    io = IOBuffer(; sizehint=ncodeunits(title))
    need_sep = false
    wrote = false
    for c in title
        lc = lowercase(c)
        if ('a' <= lc <= 'z') || ('0' <= lc <= '9')
            if need_sep && wrote
                write(io, '_')
            end
            write(io, lc)
            wrote = true
            need_sep = false
        else
            need_sep = true
        end
    end
    return wrote ? String(take!(io)) : "table"
end

"""
    _table_key(prefix, discriminator) → String

W3/#138 family key: `<declared-prefix>_<discriminator-slug>` for leaves whose
one invocation emits multiple sibling tables (per-shock IRFs, per-variable
HDs). `prefix` must be the leaf's registry-declared `TableSpec` name with
`family=true`; the discriminator is a runtime variable name.
"""
_table_key(prefix::AbstractString, discriminator) = string(prefix, "_", _slug(string(discriminator)))

function output_result(df::DataFrame; format::Union{String,Symbol}=:table, output::String="", title::String="Results",
                       key::AbstractString="")
    fmt = _parse_format(format)
    _validate_output_path(output)
    # Accumulate into active JSON envelope instead of printing (C010 / F17)
    if envelope_active() && fmt == :json
        add_table!(_ENVELOPE[], Symbol(isempty(key) ? _slug(title) : String(key)), df)
        isempty(output) || (_ENVELOPE_JSON_TO_FILE[] = true)
        return
    end
    # Accumulate into active CSV envelope on stdout so multi-table commands emit one RFC 4180 table (F-18)
    if envelope_active() && fmt == :csv && isempty(output)
        add_table!(_ENVELOPE[], Symbol(isempty(key) ? _slug(title) : String(key)), df)
        return
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
function output_kv(pairs::Vector{<:Pair{String}}; format::Union{String,Symbol}="table", output::String="", title::String="Results",
                   key::AbstractString="")
    fmt = _parse_format(format)
    _validate_output_path(output)
    if envelope_active() && fmt == :json
        df = DataFrame(; metric=first.(pairs), value=last.(pairs))
        add_table!(_ENVELOPE[], Symbol(isempty(key) ? _slug(title) : String(key)), df)
        isempty(output) || (_ENVELOPE_JSON_TO_FILE[] = true)
        return
    end
    if envelope_active() && fmt == :csv && isempty(output)
        df = DataFrame(; metric=first.(pairs), value=last.(pairs))
        add_table!(_ENVELOPE[], Symbol(isempty(key) ? _slug(title) : String(key)), df)
        return
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
    is_tty = isempty(output) && (stdout isa Base.TTY)
    fit_tty = _COMPACT[] && is_tty
    io = isempty(output) ? stdout : open(output, "w")
    try
        _render_table(io, df; title=title, fit_tty=fit_tty)
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
    # rejects them ("… not allowed in JSON spec") and would crash direct -f json
    # rendering (no envelope) — unlike the envelope path, which already applies
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
