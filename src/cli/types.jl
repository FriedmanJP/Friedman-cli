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

# CLI type system adapted from Comonicon.jl AST (see COMONICON_LICENSE)

"""
    Argument(name, type, required, default, description)

A positional command-line argument.
"""
struct Argument
    name::String
    type::Type
    required::Bool
    default::Any
    description::String
end

Argument(name::String; type::Type=String, required::Bool=true, default=nothing, description::String="") =
    Argument(name, type, required, default, description)

"""
    Option(name, short, type, default, description, choices, repeatable)

A named command-line option (e.g. `--lags=2` or `-l 2`).
`repeatable` marks an option that may be given more than once; the handler then
receives a `Vector{String}` of every occurrence (in order) (CARD-W1 #209).
`choices` is an optional allow-list of raw string values (F4).
"""
struct Option
    name::String
    short::String
    type::Type
    default::Any
    description::String
    choices::Union{Nothing,Vector{String}}
    repeatable::Bool
    aliases::Vector{String}
    kwarg::Symbol
end

Option(name::String; short::String="", type::Type=String, default=nothing,
       description::String="", choices::Union{Nothing,Vector{String}}=nothing,
       repeatable::Bool=false, aliases::Vector{String}=String[], kwarg::Symbol=Symbol("")) =
    Option(name, short, type, default, description, choices, repeatable, aliases, kwarg)

# Backward-compatible positional forms (pre-`repeatable` call sites).
Option(name::String, short::String, type::Type, default, description::String) =
    Option(name, short, type, default, description, nothing, false, String[], Symbol(""))
Option(name::String, short::String, type::Type, default, description::String,
       choices::Union{Nothing,Vector{String}}, repeatable::Bool) =
    Option(name, short, type, default, description, choices, repeatable, String[], Symbol(""))

"""
    Flag(name, short, description, aliases, kwarg)

A boolean command-line flag (e.g. `--verbose` or `-v`).
"""
struct Flag
    name::String
    short::String
    description::String
    aliases::Vector{String}
    kwarg::Symbol
end

Flag(name::String; short::String="", description::String="",
     aliases::Vector{String}=String[], kwarg::Symbol=Symbol("")) =
    Flag(name, short, description, aliases, kwarg)
Flag(name::String, short::String, description::String) =
    Flag(name, short, description, String[], Symbol(""))

"""
    LeafCommand(name, handler, args, options, flags, description)

A terminal command that executes a handler function.
"""
struct LeafCommand
    name::String
    handler::Function
    args::Vector{Argument}
    options::Vector{Option}
    flags::Vector{Flag}
    description::String
    family::String
    thread_mode::Symbol
    known_opts::Set{String}
    known_flags::Set{String}
    arg_syms::Vector{Symbol}
    opt_syms::Vector{Symbol}
    flag_syms::Vector{Symbol}
end

function _leaf_lookup_tables(args::Vector{Argument}, options::Vector{Option}, flags::Vector{Flag})
    known = Set{String}()
    known_flags = Set{String}()
    sizehint!(known, 2 * (length(options) + length(flags)) + 2)
    push!(known, "help", "h")
    push!(known_flags, "help", "h")
    opt_syms = Vector{Symbol}(undef, length(options))
    for i in eachindex(options)
        o = options[i]
        push!(known, o.name)
        isempty(o.short) || push!(known, o.short)
        for a in o.aliases
            push!(known, a)
        end
        opt_syms[i] = o.kwarg === Symbol("") ? Symbol(replace(o.name, "-" => "_")) : o.kwarg
    end
    flag_syms = Vector{Symbol}(undef, length(flags))
    for i in eachindex(flags)
        f = flags[i]
        push!(known, f.name)
        push!(known_flags, f.name)
        if !isempty(f.short)
            push!(known, f.short)
            push!(known_flags, f.short)
        end
        for a in f.aliases
            push!(known, a)
            push!(known_flags, a)
        end
        flag_syms[i] = f.kwarg === Symbol("") ? Symbol(replace(f.name, "-" => "_")) : f.kwarg
    end
    arg_syms = Symbol[Symbol(a.name) for a in args]
    return known, known_flags, arg_syms, opt_syms, flag_syms
end

function LeafCommand(name::String, handler::Function,
                     args::Vector{Argument}, options::Vector{Option},
                     flags::Vector{Flag}, description::String,
                     family::String="", thread_mode::Symbol=:julia_threads)
    known, known_flags, arg_syms, opt_syms, flag_syms = _leaf_lookup_tables(args, options, flags)
    return LeafCommand(name, handler, args, options, flags, description, family, thread_mode,
                       known, known_flags, arg_syms, opt_syms, flag_syms)
end

LeafCommand(name::String, handler::Function;
    args::Vector{Argument}=Argument[],
    options::Vector{Option}=Option[],
    flags::Vector{Flag}=Flag[],
    description::String="",
    family::String="",
    thread_mode::Symbol=:julia_threads) =
    LeafCommand(name, handler, args, options, flags, description, family, thread_mode)

"""
    NodeCommand(name, subcmds, description[, aliases])

A command group that dispatches to subcommands. `subcmds` holds canonical primary
names only; `aliases` maps coexisting shorthand tokens to canonical keys in `subcmds`.
"""
struct NodeCommand
    name::String
    subcmds::Dict{String,Union{NodeCommand,LeafCommand}}
    description::String
    aliases::Dict{String,String}
end

NodeCommand(name::String, subcmds::Dict{String,Union{NodeCommand,LeafCommand}}, description::String) =
    NodeCommand(name, subcmds, description, Dict{String,String}())

NodeCommand(name::String;
            subcmds::Dict{String,Union{NodeCommand,LeafCommand}}=Dict{String,Union{NodeCommand,LeafCommand}}(),
            description::String="",
            aliases::Dict{String,String}=Dict{String,String}()) =
    NodeCommand(name, subcmds, description, aliases)

"""
    Entry(name, root, version)

The top-level CLI entry point.
"""
struct Entry
    name::String
    root::NodeCommand
    version::VersionNumber
end

Entry(name::String, root::NodeCommand; version::VersionNumber) =
    Entry(name, root, version)
