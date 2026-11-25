# Unified HandleRef & path/confinement resolver ([STORAGE-W1] #305)

const KNOWN_HANDLE_EXTS = (".jld2", ".jls", ".fmod")
const KNOWN_DATA_EXTS = (".csv", ".tsv", ".parquet", ".xlsx", ".xls", ".dta", ".sav", ".sas7bdat", ".json")
const KNOWN_ALL_EXTS = (KNOWN_HANDLE_EXTS..., KNOWN_DATA_EXTS...)

const _SESSION_PREFIX_MAP = (
    ("model://",  :model),
    ("data://",   :data),
    ("result://", :result),
    ("mem://",    :mem),
)

"""
    HandleRef

Unified reference to a CLI data, model, or result handle across filesystem paths
(with optional `#key` archive selector), bundled `:example` datasets, and
in-memory session URIs (`model://`, `data://`, `result://`, `mem://`).
"""
struct HandleRef
    scheme::Symbol                       # :file | :example | :session
    raw::String                          # original CLI token for diagnostics
    path::Union{String,Nothing}          # expanded filesystem path (:file) or URI/name
    key::Union{String,Nothing}           # optional #key selector (stripped from path)
    session_ns::Union{Symbol,Nothing}    # :model | :data | :result | :mem
    format::Union{Symbol,Nothing}        # :jld2 | :jls | :fmod | :csv | ... | nothing
end

function _is_session_uri(s::AbstractString)::Bool
    for (pref, _) in _SESSION_PREFIX_MAP
        startswith(s, pref) && return true
    end
    return false
end

function _session_namespace(s::AbstractString)::Union{Symbol,Nothing}
    for (pref, ns) in _SESSION_PREFIX_MAP
        startswith(s, pref) && return ns
    end
    return nothing
end

"""
    _known_ext(path) → String

Return the lowercase known extension from `KNOWN_ALL_EXTS` if `basename(path)`
ends with one; otherwise return `""`. Arbitrary dotted stems such as `macro.v1`,
`model_v1.2`, or `series.2026Q1` return `""` so they are never misclassified as
unknown extensions.
"""
function _known_ext(path::AbstractString)::String
    bn = lowercase(basename(String(path)))
    for ext in KNOWN_ALL_EXTS
        if endswith(bn, ext) && length(bn) > length(ext)
            return ext
        end
    end
    return ""
end

function _ext_to_format(ext::AbstractString)::Union{Symbol,Nothing}
    isempty(ext) && return nothing
    e = lowercase(String(ext))
    startswith(e, ".") && (e = e[2:end])
    return Symbol(e)
end

"""Split optional `#key` selector from a filesystem handle string."""
function _split_key_selector(raw::AbstractString)::Tuple{String,Union{String,Nothing}}
    s = String(raw)
    (startswith(s, ":") || _is_session_uri(s)) && return (s, nothing)
    idx = findlast('#', s)
    idx === nothing && return (s, nothing)
    # Only treat `#key` as a selector if `#` is after the last path separator and key is non-empty
    sep_idx = max(something(findlast('/', s), 0), something(findlast('\\', s), 0))
    idx > sep_idx || return (s, nothing)
    base = s[1:prevind(s, idx)]
    key = s[nextind(s, idx):end]
    (isempty(base) || isempty(key)) && return (s, nothing)
    # If the literal filename with `#` exists on disk, prefer the literal file
    isfile(_expanduser(s)) && return (s, nothing)
    return (base, key)
end

"""
    parse_handle_ref(raw) → HandleRef

Parse a CLI argument string into a structured `HandleRef` (without touching disk
for stem probing). Always expands `~` on `:file` references.
"""
function parse_handle_ref(raw::AbstractString)::HandleRef
    s = String(raw)
    if startswith(s, ":")
        return HandleRef(:example, s, s, nothing, nothing, :example)
    end
    ns = _session_namespace(s)
    if ns !== nothing
        return HandleRef(:session, s, s, nothing, ns, :session)
    end
    base, key = _split_key_selector(s)
    exp = _expanduser(base)
    ext = _known_ext(exp)
    fmt = _ext_to_format(ext)
    return HandleRef(:file, s, exp, key, nothing, fmt)
end

"""Resolve symlinks on an existing path or its deepest existing ancestor."""
function _canonical_path_for_confinement(path::String)::String
    resolved = _resolve_path(path)
    if ispath(resolved) || islink(resolved)
        try
            return realpath(resolved)
        catch
            return resolved
        end
    end
    # Walk upward until an existing ancestor is found, canonicalize it, and reattach tail
    parts = String[]
    cur = resolved
    while true
        parent = dirname(cur)
        if parent == cur
            break
        end
        pushfirst!(parts, basename(cur))
        cur = parent
        if ispath(cur)
            base_real = try
                realpath(cur)
            catch
                cur
            end
            return normpath(joinpath(base_real, parts...))
        end
    end
    return resolved
end

"""
    _enforce_data_root!(ref::HandleRef; kind="input") → HandleRef

Central confinement guard for `FRDC_DATA_ROOT` (with silent fallback to
`FRIEDMAN_DATA_ROOT`). No-op for `:example`, `:session`, or when unset.
Canonicalizes symlinks so symlink traversal cannot escape the confined root.
"""
function _enforce_data_root!(ref::HandleRef; kind::String="input")::HandleRef
    ref.scheme === :file || return ref
    p = ref.path
    (p === nothing || isempty(p)) && return ref
    root = _data_root()
    isempty(root) && return ref

    resolved = _canonical_path_for_confinement(p)
    root_resolved = _canonical_path_for_confinement(root)
    sep = Base.Filesystem.path_separator
    inside = resolved == root_resolved ||
             startswith(resolved, endswith(root_resolved, sep) ? root_resolved : root_resolved * sep)
    inside || throw(CliError("data/bad-path",
        "$kind path escapes FRDC_DATA_ROOT: $(ref.raw)";
        hint="resolved to $resolved, which is outside $root_resolved"))
    return ref
end

"""
    resolve_read_ref(raw; slot=:data) → HandleRef

Resolve an input handle/data reference, enforcing `FRDC_DATA_ROOT` confinement
and unambiguous bare-stem resolution.

When `raw` has no known extension and multiple matching candidates exist on disk
(e.g., both `shared.jld2` and `shared.csv`), throws `data/ambiguous-path` (exit 3)
naming the candidates so the caller never silently reads the wrong artifact.
"""
function resolve_read_ref(raw::AbstractString; slot::Symbol=:data)::HandleRef
    ref = parse_handle_ref(raw)
    ref.scheme === :file || return ref
    p = ref.path::String
    _enforce_data_root!(ref; kind="input")

    # Explicit known extension — check confinement and return directly
    if ref.format !== nothing
        return ref
    end

    # Bare stem (including dotted stems like `macro.v1` or `model_v1.2`)
    exts = slot === :data ? (".jld2", ".jls", ".csv", ".fmod") :
                            (".jld2", ".jls", ".fmod")
    matches = String[]
    for ext in exts
        cand = p * ext
        isfile(cand) && push!(matches, cand)
    end
    if length(matches) > 1
        cnames = join(basename.(matches), ", ")
        throw(CliError("data/ambiguous-path",
            "ambiguous path '$(ref.raw)': multiple matching files exist ($cnames)";
            hint="specify the extension explicitly, e.g. $(matches[1])"))
    elseif length(matches) == 1
        hit = matches[1]
        hit_ref = HandleRef(:file, ref.raw, hit, ref.key, nothing, _ext_to_format(_known_ext(hit)))
        return _enforce_data_root!(hit_ref; kind="input")
    end

    # Exact extensionless file already exists on disk (e.g. legacy extensionless file)
    if isfile(p)
        return _enforce_data_root!(ref; kind="input")
    end

    bn = basename(p)
    hint = slot === :data ? "tried $(bn).jld2, $(bn).jls, $(bn).csv, and $(bn).fmod" :
                            "tried $(bn).jld2, $(bn).jls, and $(bn).fmod"
    throw(CliError("data/file-not-found", "file not found: $(ref.raw)"; hint=hint))
end

"""
    resolve_write_ref(raw; default_ext=".jld2", create_parents=true) → HandleRef

Resolve an output handle/data reference: expands `~`, appends `default_ext` when
no known extension is present (preserving dotted stems like `model_v1.2`),
enforces `FRDC_DATA_ROOT` confinement, and creates parent directories when
`create_parents=true`.
"""
function resolve_write_ref(raw::AbstractString; default_ext::String=".jld2",
                           create_parents::Bool=true)::HandleRef
    ref = parse_handle_ref(raw)
    ref.scheme === :file || return ref
    p = ref.path::String
    isempty(p) && return ref
    out_path = ref.format === nothing && !isempty(default_ext) ? (p * default_ext) : p
    out_fmt = _ext_to_format(_known_ext(out_path))
    out_ref = HandleRef(:file, ref.raw, out_path, ref.key, nothing, out_fmt)
    _enforce_data_root!(out_ref; kind="output")
    parent = dirname(abspath(out_path))
    if !isempty(parent) && !isdir(parent)
        if create_parents
            mkpath(parent)
        else
            throw(CliError("data/file-not-found",
                "output directory does not exist: $parent";
                hint="create the directory first (e.g. mkdir -p $parent)"))
        end
    end
    return out_ref
end

"""Format a `HandleRef` back to a canonical string path (reattaching `#key` if any)."""
function ref_string(ref::HandleRef)::String
    ref.scheme === :file || return ref.raw
    p = something(ref.path, ref.raw)
    return ref.key === nothing ? p : "$(p)#$(ref.key)"
end
