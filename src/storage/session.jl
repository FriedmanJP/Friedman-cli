# Unified in-memory session object store ([STORAGE-W2] #306)
#
# Supports `model://`, `data://`, `result://`, and `mem://` URIs uniformly
# across both the interactive REPL (`frdc repl`) and the MCP server
# (`frdc serve --mcp`). Each entry carries the same `_frdc_meta` metadata
# dictionary written to disk so `model info result://r1` and `show data://d1`
# behave identically to on-disk `.jld2`/`.jls` handles.

"""
    SessionEntry

Typed in-memory handle entry stored in the active REPL / MCP session.
"""
struct SessionEntry
    uri::String
    namespace::Symbol
    payload::Any
    meta::Dict{String,Any}
    source_model::Any
end

const _SESSION_STORE = Ref{Union{Nothing,Dict{String,SessionEntry}}}(nothing)

"""True when an interactive REPL or `serve --mcp` session store is active."""
function session_active()::Bool
    return _SESSION_STORE[] !== nothing || _SERVE_MODEL_STORE[] !== nothing
end

"""Throw structured exit-2 `usage/session-uri-requires-session` outside a session."""
function _require_session_store!(uri::AbstractString)
    session_active() && return nothing
    throw(CliError("usage/session-uri-requires-session",
        "$uri: session URIs (model://, data://, result://, mem://) are only available inside `frdc repl` or `frdc serve --mcp`";
        hint="Use inside 'frdc repl' or 'frdc serve --mcp', or pass a file path (.jld2 / .jls)"))
end

"""Open a fresh session object store (synced with legacy `_SERVE_MODEL_STORE`)."""
function open_session_store!()
    _SESSION_STORE[] = Dict{String,SessionEntry}()
    _SERVE_MODEL_STORE[] = Dict{String,Any}()
    _SERVE_SOURCE_MODELS[] = Dict{String,Any}()
    return _SESSION_STORE[]
end

"""Close and clear the active session object store."""
function close_session_store!()
    _SESSION_STORE[] = nothing
    _SERVE_MODEL_STORE[] = nothing
    _SERVE_SOURCE_MODELS[] = nothing
    return nothing
end

"""Run `fn()` with an active session store (reentrant if one is already open)."""
function with_session_store(fn::Function)
    if session_active()
        return fn()
    end
    open_session_store!()
    try
        return fn()
    finally
        close_session_store!()
    end
end

"""Store `obj` under a session URI (`model://`, `data://`, `result://`, `mem://`)."""
function session_store_put!(uri::String, obj; note::String="", source_model=nothing)::SessionEntry
    _require_session_store!(uri)
    ns = something(_session_namespace(uri), :mem)
    meta = _build_frdc_meta(obj; note=note,
        source_model=(source_model isa AbstractDict ? source_model : nothing))
    entry = SessionEntry(uri, ns, obj, meta, source_model)
    if _SESSION_STORE[] !== nothing
        _SESSION_STORE[][uri] = entry
    end
    if _SERVE_MODEL_STORE[] !== nothing
        _SERVE_MODEL_STORE[][uri] = obj
    end
    if source_model !== nothing && _SERVE_SOURCE_MODELS[] !== nothing
        _SERVE_SOURCE_MODELS[][uri] = source_model
    end
    return entry
end

"""Look up a `SessionEntry` by URI, throwing typed errors when outside session or missing."""
function session_store_get_entry(uri::String)::SessionEntry
    _require_session_store!(uri)
    ss = _SESSION_STORE[]
    if ss !== nothing && haskey(ss, uri)
        return ss[uri]
    end
    legacy = _SERVE_MODEL_STORE[]
    if legacy !== nothing && haskey(legacy, uri)
        obj = legacy[uri]
        ns = something(_session_namespace(uri), :model)
        src = (_SERVE_SOURCE_MODELS[] !== nothing) ? get(_SERVE_SOURCE_MODELS[], uri, nothing) : nothing
        meta = _build_frdc_meta(obj)
        return SessionEntry(uri, ns, obj, meta, src)
    end
    throw(CliError("data/file-not-found",
        "no session handle stored at $uri";
        hint="save one first with --save-model $uri, --save-result $uri, or -o $uri"))
end

"""Fetch the payload stored at a session URI."""
session_store_get(uri::String) = session_store_get_entry(uri).payload

"""Attach a source model to an already-stored session URI."""
function session_store_set_source_model!(uri::String, src)
    ss = _SESSION_STORE[]
    if ss !== nothing && haskey(ss, uri)
        old = ss[uri]
        ss[uri] = SessionEntry(old.uri, old.namespace, old.payload, old.meta, src)
    end
    if _SERVE_SOURCE_MODELS[] !== nothing
        _SERVE_SOURCE_MODELS[][uri] = src
    end
    return nothing
end

"""Retrieve the attached source model for a session URI, if any."""
function session_store_source_model(uri::String)
    ss = _SESSION_STORE[]
    if ss !== nothing && haskey(ss, uri)
        return ss[uri].source_model
    end
    sm = _SERVE_SOURCE_MODELS[]
    return sm === nothing ? nothing : get(sm, uri, nothing)
end

"""List sorted URIs currently in the active session store."""
function session_store_keys()::Vector{String}
    ks = Set{String}()
    _SESSION_STORE[] !== nothing && union!(ks, keys(_SESSION_STORE[]))
    _SERVE_MODEL_STORE[] !== nothing && union!(ks, keys(_SERVE_MODEL_STORE[]))
    return sort!(collect(ks))
end
