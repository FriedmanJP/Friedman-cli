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

# Subcommand dispatch engine

const _BUNDLED_MEMS_VERSION = if isdefined(@__MODULE__, :MacroEconometricModels)
    let pv = try pkgversion(MacroEconometricModels) catch; nothing end
        pv === nothing ? "" : string(pv)
    end
else
    ""
end

const _BUNDLED_MANIFEST_STATIC = if isdefined(@__MODULE__, :MacroEconometricModels) &&
                                    isdefined(MacroEconometricModels, :capture_manifest)
    try
        m = MacroEconometricModels.capture_manifest()
        (
            deps = Dict{String,String}(string(k) => string(v) for (k, v) in m.dependency_versions),
            git_sha = string(m.git_sha),
        )
    catch
        (deps = Dict{String,String}(), git_sha = "unknown")
    end
else
    (deps = Dict{String,String}(), git_sha = "unknown")
end

const _BUNDLED_CLI_GIT_SHA = let root = dirname(dirname(@__DIR__))
    try
        s = strip(read(pipeline(`git -C $root rev-parse --short HEAD`; stderr=devnull), String))
        isempty(s) ? "unknown" : String(s)
    catch
        "unknown"
    end
end

const _MEMS_VERSION_CACHE = Ref{String}("")
const _CURRENT_EXPLICIT_OPTS = Ref{Set{String}}(Set{String}())
const _IN_DISPATCH = Ref{Bool}(false)

function _cached_mems_version()::String
    v = _MEMS_VERSION_CACHE[]
    !isempty(v) && return v
    v = if !isempty(_BUNDLED_MEMS_VERSION)
        _BUNDLED_MEMS_VERSION
    elseif isdefined(@__MODULE__, :MacroEconometricModels)
        try
            pv = pkgversion(MacroEconometricModels)
            pv === nothing ? "unknown" : string(pv)
        catch
            "unknown"
        end
    else
        "unknown"
    end
    _MEMS_VERSION_CACHE[] = v
    return v
end

"""
    _wants_help(args) → Bool

Check if help is requested anywhere in the argument list.
"""
_wants_help(args::Vector{String}) = "--help" in args || "-h" in args

"""
    dispatch(entry, args)

Main dispatch: walk the command tree from `entry` using `args`, then execute the matched leaf.
"""
function dispatch(entry::Entry, args::Vector{String}=ARGS; extra_kwargs...)
    # Pre-dispatch globals are LEADING-ONLY (#117): they fire only as the FIRST
    # token, before any subcommand path is consumed. The old whole-argv match
    # swallowed a leaf option of the same name — the GPL notice printed instead
    # of the command running, silently, exit 0 (found in W8; `forecast multivariate
    # scenario` spells its option `--conditions-file` to dodge the old behaviour).
    if !isempty(args)
        if args[1] == "--version" || args[1] == "-V"
            println(entry.name, " v", entry.version)
            return
        elseif args[1] == "--warranty"
            MacroEconometricModels.warranty()
            return
        elseif args[1] == "--conditions"
            MacroEconometricModels.conditions()
            return
        end
    end

    # Handle --help at top level only (not when a subcommand follows)
    if isempty(args) || args[1] in ("--help", "-h")
        print_help(stdout, entry)
        return
    end

    return dispatch_node(entry.root, args; prog=entry.name, extra_kwargs...)
end

"""
    dispatch_node(node, args; prog)

Walk into a NodeCommand, matching the first token as a subcommand name.
"""
function dispatch_node(node::NodeCommand, args::Vector{String}; prog::String=node.name, extra_kwargs...)
    if isempty(args)
        print_help(stdout, node; prog=prog)
        return
    end

    subcmd_name = args[1]
    rest = args[2:end]

    # schema takes a variable-length command path — dedicated dispatcher (P1-5)
    if subcmd_name == "schema" && haskey(node.subcmds, "schema")
        return dispatch_schema(rest; prog=prog * " schema")
    end

    # If first arg is a known subcommand, recurse into it (carries --help through)
    # F62: single get() instead of haskey+index pair
    subcmd = get(node.subcmds, subcmd_name, nothing)
    if subcmd !== nothing
        subprog = prog * " " * subcmd_name
        if subcmd isa NodeCommand
            return dispatch_node(subcmd, rest; prog=subprog, extra_kwargs...)
        else
            return dispatch_leaf(subcmd, rest; prog=subprog, extra_kwargs...)
        end
    end

    # First arg isn't a subcommand — show help if requested, otherwise error
    if _wants_help(args)
        print_help(stdout, node; prog=prog)
        return
    end

    throw(DispatchError(_unknown_command_message(prog, subcmd_name, rest)))
end

"""
Usage message for an unknown subcommand. Once the registry's replacement map
exists (#202), a removed v0.13 spelling names the v1.0.0 path. Engine tests
include this file before that map, so the fallback is the bare message.
"""
function _unknown_command_message(prog::AbstractString, subcmd::AbstractString,
                                  rest::Vector{String}=String[])
    if isdefined(@__MODULE__, :_replacement_for)
        parts = String.(split(String(prog)))
        consumed = length(parts) <= 1 ? String[] : parts[2:end]
        tokens = vcat(consumed, [String(subcmd)], rest)
        newp = _replacement_for(tokens)
        base = "$prog: unknown command '$subcmd'"
        newp === nothing && return base
        return base * " — use `$(join(newp, " "))`"
    end
    return "$prog: unknown command '$subcmd'"
end

_slot_set_cli(v) = v isa AbstractString ? !isempty(v) : v !== nothing

function _collect_explicit_opts(parsed::ParsedArgs, leaf::LeafCommand)
    explicit = Set{String}()
    for o in leaf.options
        if haskey(parsed.options, o.name) ||
           (!isempty(o.short) && haskey(parsed.options, o.short)) ||
           any(a -> haskey(parsed.options, a), o.aliases) ||
           haskey(parsed.multi, o.name) ||
           (!isempty(o.short) && haskey(parsed.multi, o.short)) ||
           any(a -> haskey(parsed.multi, a), o.aliases)
            push!(explicit, o.name)
        end
    end
    for f in leaf.flags
        if (f.name in parsed.flags) ||
           (!isempty(f.short) && (f.short in parsed.flags)) ||
           any(a -> (a in parsed.flags), f.aliases)
            push!(explicit, f.name)
        end
    end
    return explicit
end

"""
    dispatch_leaf(leaf, args; prog)

Parse arguments for a LeafCommand and call its handler.
"""
function dispatch_leaf(leaf::LeafCommand, args::Vector{String}; prog::String=leaf.name, extra_kwargs...)
    # Handle --help or no arguments when required args exist
    if _wants_help(args)
        print_help(stdout, leaf; prog=prog)
        return
    end

    extra_dict = Dict{Symbol,Any}(extra_kwargs)
    has_extra_model = haskey(extra_dict, :model) && _slot_set_cli(extra_dict[:model])

    if isempty(args) && any(a -> a.required, leaf.args) && !has_extra_model
        print_help(stdout, leaf; prog=prog)
        return
    end

    try
        parsed = tokenize(args, leaf)
        bound = bind_args(parsed, leaf; has_extra_model=has_extra_model)
        # Single-envelope JSON accumulation (P1-1 / F17; C055: the
        # FRIEDMAN_LEGACY_OUTPUT escape hatch was removed at v1.0.0)
        fmt = get(bound, :format, _FORCE_JSON[] ? "json" : nothing)
        out_path = string(get(bound, :output, ""))
        is_comp = startswith(prog, "friedman completions")
        use_json_env = (fmt == "json") || (_FORCE_JSON[] && is_comp)
        use_csv_env = (fmt == "csv") && isempty(out_path)
        use_env = use_json_env || use_csv_env
        t0 = time_ns()
        if use_env
            env = Envelope(command=prog)
            env.meta = Dict{String,Any}(
                "cli_version"  => string(FRIEDMAN_VERSION),
                "julia"        => string(VERSION),
                "seed"         => _SEED[],
                "argv"         => copy(_LAST_ARGV[]),
                "mems_version" => _cached_mems_version(),
            )
            try
                env.meta["manifest"] = _envelope_manifest()
            catch
                # provenance is best-effort — never break the envelope over it
            end
            _ENVELOPE[] = env
        end
        prev_explicit = _CURRENT_EXPLICIT_OPTS[]
        prev_in_dispatch = _IN_DISPATCH[]
        prev_json_to_file = _ENVELOPE_JSON_TO_FILE[]
        _CURRENT_EXPLICIT_OPTS[] = _collect_explicit_opts(parsed, leaf)
        _IN_DISPATCH[] = true
        _ENVELOPE_JSON_TO_FILE[] = false
        try
            result = if isempty(extra_dict)
                leaf.handler(; bound...)
            else
                merged = Dict{Symbol,Any}(pairs(bound))
                for (k, v) in extra_dict
                    cur = get(merged, k, nothing)
                    if !_slot_set_cli(cur)
                        merged[k] = v
                    end
                end
                leaf.handler(; merged...)
            end
            if use_json_env && _ENVELOPE[] !== nothing
                _ENVELOPE[].meta["elapsed_ms"] = (time_ns() - t0) / 1e6
                if _ENVELOPE_JSON_TO_FILE[] && !isempty(out_path)
                    _validate_output_path(out_path)
                    open(_expanduser(out_path), "w") do io
                        render(_ENVELOPE[], :json, io)
                    end
                    _status("Results written to $out_path")
                    _ENVELOPE_EMITTED[] = true
                else
                    render(_ENVELOPE[], :json, stdout)
                    _ENVELOPE_EMITTED[] = true
                end
            elseif use_csv_env && _ENVELOPE[] !== nothing
                render(_ENVELOPE[], :csv, stdout)
                if length(_ENVELOPE[].tables) > 1
                    extra_names = join(string.(first.(_ENVELOPE[].tables[2:end])), ", ")
                    _status("Note: CSV stdout emitted primary table '$(_ENVELOPE[].tables[1].first)' only; " *
                            "omitted secondary table(s): $extra_names (use -o <file.csv> for per-table files or --format json)")
                end
            end
            return result
        catch e
            if e isa Base.IOError && e.code == Base.UV_EPIPE
                rethrow()
            end
            # In JSON mode, attach error to envelope, render, then rethrow for exit code
            if use_json_env && _ENVELOPE[] !== nothing
                if e isa CliError
                    set_error!(_ENVELOPE[], e.code, e.message; hint=e.hint)
                else
                    # W2/#137 (D-4): consult the MEMs domain mapping FIRST so the
                    # envelope's error.code agrees with the exit class run_cli
                    # derives from the same mapping — a raw ConvergenceError used
                    # to be enveloped internal/error while the process exited 5.
                    mapped = _domain_error_class(e)
                    if mapped !== nothing
                        set_error!(_ENVELOPE[], mapped.code, mapped.message; hint=mapped.hint)
                    else
                        set_error!(_ENVELOPE[], "internal/error", sprint(showerror, e))
                    end
                end
                _ENVELOPE[].meta["elapsed_ms"] = (time_ns() - t0) / 1e6
                render(_ENVELOPE[], :json, stdout)
                _ENVELOPE_EMITTED[] = true
            end
            rethrow()
        finally
            _ENVELOPE[] = nothing
            _CURRENT_EXPLICIT_OPTS[] = prev_explicit
            _IN_DISPATCH[] = prev_in_dispatch
            _ENVELOPE_JSON_TO_FILE[] = prev_json_to_file
        end
    catch e
        if e isa ParseError
            throw(ParseError("$prog: $(e.message)"))
        else
            rethrow()
        end
    end
end
