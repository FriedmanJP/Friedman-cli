# Request-scoped handle cache ([STORAGE-W2] #306)
#
# Prevents double/triple deserialization when `wrap_legacy` inspects a handle's
# data/model kind and downstream loaders (`load_multivariate_data`,
# `load_univariate_series`, `load_panel_data`, `_load_panel_reg`, `_load_io`,
# `resolve_data`, etc.) load the same path during the same CLI invocation.

const _INVOCATION_HANDLE_CACHE = Ref{Union{Nothing,Dict{String,Any}}}(nothing)
const _HANDLE_LOAD_COUNTER = Ref{Int}(0)

function _handle_cache_key(ref::HandleRef)::String
    if ref.scheme === :session
        return "session:" * ref.raw
    elseif ref.scheme === :example
        return "example:" * ref.raw
    end
    canon = _resolve_path(ref.path::String)
    return ref.key === nothing ? "file:" * canon : "file:" * canon * "#" * ref.key
end

"""
    with_handle_cache(fn)

Execute `fn()` inside an invocation-scoped handle deserialization cache.
Reentrant: nested calls share the enclosing invocation cache and only the
outermost frame clears it in a `finally` block.
"""
function with_handle_cache(fn::Function)
    if _INVOCATION_HANDLE_CACHE[] !== nothing
        return fn()
    end
    _INVOCATION_HANDLE_CACHE[] = Dict{String,Any}()
    try
        return fn()
    finally
        _INVOCATION_HANDLE_CACHE[] = nothing
    end
end

"""
    load_handle_cached(ref::HandleRef) → Any

Load `ref` at most once per CLI invocation. Always enforces `FRDC_DATA_ROOT`
confinement on `:file` references, increments `_HANDLE_LOAD_COUNTER` on every
actual deserialization miss, and caches the resulting object until the
invocation completes or `invalidate_handle_cache!` evicts it.
"""
function load_handle_cached(ref::HandleRef)
    ref.scheme === :file && _enforce_data_root!(ref; kind="input")
    cache = _INVOCATION_HANDLE_CACHE[]
    if cache !== nothing
        key = _handle_cache_key(ref)
        if haskey(cache, key)
            return cache[key]
        end
        obj = load_handle(ref)
        _HANDLE_LOAD_COUNTER[] += 1
        cache[key] = obj
        return obj
    end
    obj = load_handle(ref)
    _HANDLE_LOAD_COUNTER[] += 1
    return obj
end

"""
    invalidate_handle_cache!(ref_or_path)

Evict cached entries for `ref_or_path` (including any `#key` sub-entries for
the same underlying file path). Invoked automatically by `save_handle!`.
"""
function invalidate_handle_cache!(ref::HandleRef)
    cache = _INVOCATION_HANDLE_CACHE[]
    cache === nothing && return nothing
    if ref.scheme === :session
        delete!(cache, "session:" * ref.raw)
        return nothing
    elseif ref.scheme === :example
        delete!(cache, "example:" * ref.raw)
        return nothing
    end
    p = ref.path
    (p === nothing || isempty(p)) && return nothing
    prefix = "file:" * _resolve_path(p)
    prefix_hash = prefix * "#"
    for k in collect(keys(cache))
        if k == prefix || startswith(k, prefix_hash)
            delete!(cache, k)
        end
    end
    return nothing
end

function invalidate_handle_cache!(path::AbstractString)
    isempty(path) && return nothing
    return invalidate_handle_cache!(parse_handle_ref(String(path)))
end
