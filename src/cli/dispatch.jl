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
    # of the command running, silently, exit 0 (found in W8; `forecast scenario`
    # spells its option `--conditions-file` to dodge the old behaviour).
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

    throw(DispatchError("$prog: unknown command '$subcmd_name'"))
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

    if isempty(args) && any(a -> a.required, leaf.args)
        print_help(stdout, leaf; prog=prog)
        return
    end

    try
        parsed = tokenize(args)
        bound = bind_args(parsed, leaf)
        merged = merge(Dict{Symbol,Any}(pairs(bound)), Dict{Symbol,Any}(extra_kwargs))
        # Single-envelope JSON accumulation (P1-1 / F17); legacy path when env set
        fmt = get(Dict(pairs(bound)), :format, nothing)
        use_env = fmt == "json" && get(ENV, "FRIEDMAN_LEGACY_OUTPUT", "") != "1"
        t0 = time_ns()
        if use_env
            env = Envelope(command=prog)
            env.meta = Dict{String,Any}(
                "cli_version"  => string(FRIEDMAN_VERSION),
                "julia"        => string(VERSION),
                "seed"         => _SEED[],
                "argv"         => copy(_LAST_ARGV[]),
            )
            try
                env.meta["mems_version"] = string(pkgversion(MacroEconometricModels))
            catch
                env.meta["mems_version"] = "unknown"
            end
            try
                env.meta["manifest"] = _envelope_manifest()
            catch
                # provenance is best-effort — never break the envelope over it
            end
            _ENVELOPE[] = env
        end
        try
            result = leaf.handler(; merged...)
            if use_env && _ENVELOPE[] !== nothing
                _ENVELOPE[].meta["elapsed_ms"] = (time_ns() - t0) / 1e6
                render(_ENVELOPE[], :json, stdout)
            end
            return result
        catch e
            # In JSON mode, attach error to envelope, render, then rethrow for exit code
            if use_env && _ENVELOPE[] !== nothing
                if e isa CliError
                    set_error!(_ENVELOPE[], e.code, e.message; hint=e.hint)
                else
                    set_error!(_ENVELOPE[], "internal/error", sprint(showerror, e))
                end
                _ENVELOPE[].meta["elapsed_ms"] = (time_ns() - t0) / 1e6
                render(_ENVELOPE[], :json, stdout)
            end
            rethrow()
        finally
            _ENVELOPE[] = nothing
        end
    catch e
        if e isa ParseError
            throw(ParseError("$prog: $(e.message)"))
        else
            rethrow()
        end
    end
end
