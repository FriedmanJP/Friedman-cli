# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Per-user Julia 1.14 LMDB object-cache inspection & management ([PERF-W2] #356).

const _DEFAULT_CACHE_MAX_MB = 256

function _cache_max_mb()::Int
    raw = strip(get(ENV, "FRDC_CACHE_MAX_MB", ""))
    isempty(raw) && return _DEFAULT_CACHE_MAX_MB
    v = tryparse(Int, raw)
    (v === nothing || v <= 0) && throw(CliError("usage/invalid",
        "invalid FRDC_CACHE_MAX_MB value '$raw' (expected positive integer MiB)";
        hint="set FRDC_CACHE_MAX_MB=256 or unset to use the default"))
    return v
end

"""Resolve the per-user objcache base directory matching `packaging/c_driver/frdc_driver.c`."""
function _default_cache_base_dir()::String
    override = strip(get(ENV, "FRDC_CACHE_DIR", ""))
    !isempty(override) && return _expanduser(override)
    if Sys.iswindows()
        la = strip(get(ENV, "LOCALAPPDATA", ""))
        isempty(la) && return ""
        return joinpath(la, "frdc", "cache")
    elseif Sys.isapple()
        home = strip(get(ENV, "HOME", ""))
        isempty(home) && return ""
        return joinpath(home, "Library", "Caches", "frdc")
    else
        xdg = strip(get(ENV, "XDG_CACHE_HOME", ""))
        if !isempty(xdg)
            return joinpath(xdg, "frdc")
        end
        home = strip(get(ENV, "HOME", ""))
        isempty(home) && return ""
        return joinpath(home, ".cache", "frdc")
    end
end

function _dir_size_bytes(path::String)::Int64
    isdir(path) || return Int64(0)
    total = Int64(0)
    try
        for (root, _, files) in walkdir(path; onerror=_ -> nothing)
            for f in files
                fp = joinpath(root, f)
                try
                    total += Int64(filesize(fp))
                catch
                end
            end
        end
    catch
    end
    return total
end

function _list_objcache_dirs(base_dir::String)::Vector{String}
    (isempty(base_dir) || !isdir(base_dir)) && return String[]
    out = String[]
    try
        for entry in sort!(readdir(base_dir))
            startswith(entry, "objcache-") || continue
            full = joinpath(base_dir, entry)
            isdir(full) && push!(out, full)
        end
    catch
    end
    return out
end

function _cache_info(; format::String="table", output::String="")
    base_dir = _default_cache_base_dir()
    active_dir = strip(get(ENV, "FRDC_ACTIVE_OBJCACHE_DIR", ""))
    objcache_env = strip(get(ENV, "JULIA_OBJCACHE", ""))
    frdc_objcache_env = strip(get(ENV, "FRDC_OBJCACHE", ""))
    max_mb = _cache_max_mb()

    dirs = _list_objcache_dirs(base_dir)
    entries = NamedTuple{(:name, :active, :size_bytes, :size_mb, :path),
                         Tuple{String,Bool,Int64,Float64,String}}[]
    total_bytes = Int64(0)
    for d in dirs
        sz = _dir_size_bytes(d)
        total_bytes += sz
        is_act = !isempty(active_dir) && (normpath(abspath(d)) == normpath(abspath(active_dir)))
        push!(entries, (
            name = basename(d),
            active = is_act,
            size_bytes = sz,
            size_mb = sz / 1048576.0,
            path = d,
        ))
    end
    total_mb = total_bytes / 1048576.0
    enabled = (lowercase(frdc_objcache_env) ∉ ("0", "false", "off", "no")) &&
              (objcache_env != "0") &&
              (!isempty(active_dir) || objcache_env == "1")

    summary_pairs = Pair{String,Any}[
        "status"         => enabled ? "enabled" : "disabled",
        "base_dir"       => isempty(base_dir) ? "(unavailable)" : base_dir,
        "active_dir"     => isempty(active_dir) ? "(none)" : active_dir,
        "julia_objcache" => isempty(objcache_env) ? "(unset)" : objcache_env,
        "frdc_objcache"  => isempty(frdc_objcache_env) ? "(unset)" : frdc_objcache_env,
        "max_mb"         => max_mb,
        "entry_count"    => length(entries),
        "total_bytes"    => total_bytes,
        "total_mb"       => total_mb,
        "over_budget"    => total_mb > max_mb,
    ]
    _status("Object Cache Info: $(enabled ? "enabled" : "disabled"), $(length(entries)) stamp(s), $(round(total_mb; digits=2)) / $(max_mb) MiB")
    output_kv(summary_pairs; format=format, output=output, title="Object Cache Info", key="cache_info")
    if !isempty(entries)
        entries_df = DataFrame(
            name = [e.name for e in entries],
            active = [e.active for e in entries],
            size_bytes = [e.size_bytes for e in entries],
            size_mb = [e.size_mb for e in entries],
            path = [e.path for e in entries],
        )
        output_result(entries_df; format=Symbol(format),
                      output=_per_var_output_path(output, "entries"),
                      title="Object Cache Entries", key="cache_entries")
    end
    return (enabled=enabled, base_dir=base_dir, active_dir=active_dir,
            total_bytes=total_bytes, entries=entries)
end

function _cache_clear(; stale_only::Bool=false, format::String="table", output::String="")
    base_dir = _default_cache_base_dir()
    active_dir = strip(get(ENV, "FRDC_ACTIVE_OBJCACHE_DIR", ""))
    active_norm = isempty(active_dir) ? "" : normpath(abspath(active_dir))

    dirs = _list_objcache_dirs(base_dir)
    removed = 0
    kept = 0
    freed_bytes = Int64(0)
    for d in dirs
        is_act = !isempty(active_norm) && (normpath(abspath(d)) == active_norm)
        if stale_only && is_act
            kept += 1
            continue
        end
        sz = _dir_size_bytes(d)
        try
            rm(d; force=true, recursive=true)
            removed += 1
            freed_bytes += sz
        catch e
            _status("Warning: could not remove $d ($(sprint(showerror, e)))")
            kept += 1
        end
    end
    freed_mb = freed_bytes / 1048576.0
    _status("Cleared $removed object cache stamp(s) ($(round(freed_mb; digits=2)) MiB freed, $kept kept)")
    output_kv(Pair{String,Any}[
        "base_dir"     => isempty(base_dir) ? "(unavailable)" : base_dir,
        "stale_only"   => stale_only,
        "removed_dirs" => removed,
        "kept_dirs"    => kept,
        "freed_bytes"  => freed_bytes,
        "freed_mb"     => freed_mb,
    ]; format=format, output=output, title="Object Cache Clear", key="cache_clear_summary")
    return (removed=removed, kept=kept, freed_bytes=freed_bytes)
end

function cache_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["cache", "info"],
            summary="Inspect per-user Julia 1.14 LMDB object cache location, status, and footprint",
            args=ArgSpec[],
            options=copy(OUTPUT_OPTIONS),
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:cache_info,
                          description="Cache status, base/active directory, budget (FRDC_CACHE_MAX_MB), entry count, and total size"),
                TableSpec(name=:cache_entries,
                          description="Per-build-stamp objcache directories and sizes (when entries exist)"),
            ],
            category="cache",
            handler=wrap_legacy(_cache_info),
        ),
        CommandSpec(
            path=["cache", "clear"],
            summary="Remove cached per-user Julia 1.14 LMDB object cache directories",
            args=ArgSpec[],
            options=copy(OUTPUT_OPTIONS),
            flags=[
                FlagSpec(name="stale-only",
                         description="Remove only inactive build-stamp caches, keeping the current stamp"),
            ],
            tables=[
                TableSpec(name=:cache_clear_summary,
                          description="Cache base directory, removed/kept stamp counts, and bytes freed"),
            ],
            category="cache",
            handler=wrap_legacy(_cache_clear),
        ),
    ]
end

function register_cache_commands!()
    specs = with_default_csv_kinds(cache_specs())
    specs = register!(specs)
    return build_node("cache", specs;
        description="Manage the per-user Julia 1.14 JIT object cache (FRDC_OBJCACHE, FRDC_CACHE_DIR, FRDC_CACHE_MAX_MB)")
end
