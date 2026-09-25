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

# Help text generation adapted from Comonicon.jl printing (see COMONICON_LICENSE)

const INDENT = "  "
const COL_WIDTH = 24

"""
    print_help(io, entry)

Print top-level help for the CLI entry point.
"""
function print_help(io::IO, entry::Entry)
    print_help(io, entry.root; prog=entry.name, version=entry.version)
end

"""
    print_help(io, node; prog, version)

Print help for a NodeCommand (command group).
"""
function print_help(io::IO, node::NodeCommand; prog::String=node.name, version::Union{VersionNumber,Nothing}=nothing)
    # Header
    if !isnothing(version)
        printstyled(io, prog, " v", version, "\n"; bold=true)
    else
        printstyled(io, prog, "\n"; bold=true)
    end
    if !isempty(node.description)
        println(io)
        println(io, node.description)
    end

    # Usage
    println(io)
    printstyled(io, "Usage:\n"; bold=true, color=:yellow)
    println(io, INDENT, prog, " <command> [args...] [options...]")

    # Child nodes are family groups after the v1.0.0 promotion. Direct leaves
    # with a family (test's `other` heading) are grouped; empty-family leaves
    # stay one flat list.
    nodes = Pair{String,NodeCommand}[]
    leaves = Pair{String,LeafCommand}[]
    for name in sort!(collect(keys(node.subcmds)))
        cmd = node.subcmds[name]
        if cmd isa NodeCommand
            push!(nodes, name => cmd)
        else
            push!(leaves, name => cmd)
        end
    end
    if !isempty(nodes)
        println(io)
        printstyled(io, "Commands:\n"; bold=true, color=:yellow)
        for (name, cmd) in nodes
            print_entry_line(io, name, cmd.description)
        end
    end
    if !isempty(leaves)
        grouped = any(!isempty, (cmd.family for (_, cmd) in leaves))
        if !grouped
            println(io)
            printstyled(io, "Commands:\n"; bold=true, color=:yellow)
            for (name, cmd) in leaves
                print_entry_line(io, name, cmd.description)
            end
        else
            fams = Dict{String,Vector{Pair{String,LeafCommand}}}()
            for pair in leaves
                push!(get!(fams, pair.second.family, Pair{String,LeafCommand}[]), pair)
            end
            for fam in sort!(collect(keys(fams)))
                println(io)
                label = isempty(fam) ? "Commands" : fam
                printstyled(io, label, ":\n"; bold=true, color=:yellow)
                for (name, cmd) in fams[fam]
                    print_entry_line(io, name, cmd.description)
                end
            end
        end
    end

    # Footer
    println(io)
    println(io, "Use '", prog, " <command> --help' for more information on a command.")
end

"""
    print_help(io, leaf; prog)

Print help for a LeafCommand (terminal command).
"""
function print_help(io::IO, leaf::LeafCommand; prog::String=leaf.name)
    # Header
    printstyled(io, prog, "\n"; bold=true)
    if !isempty(leaf.description)
        println(io)
        println(io, leaf.description)
    end
    if !isempty(leaf.family)
        println(io)
        println(io, "Family: ", leaf.family)
    end

    # Usage line
    println(io)
    printstyled(io, "Usage:\n"; bold=true, color=:yellow)
    usage = prog
    for arg in leaf.args
        usage *= arg.required ? " <$(arg.name)>" : " [$(arg.name)]"
    end
    if !isempty(leaf.options) || !isempty(leaf.flags)
        usage *= " [options...]"
    end
    println(io, INDENT, usage)

    # Arguments
    if !isempty(leaf.args)
        println(io)
        printstyled(io, "Arguments:\n"; bold=true, color=:yellow)
        for arg in leaf.args
            label = arg.required ? "<$(arg.name)>" : "[$(arg.name)]"
            desc = arg.description
            if !arg.required && !isnothing(arg.default)
                desc *= " (default: $(arg.default))"
            end
            print_entry_line(io, label, desc)
        end
    end

    # Options
    if !isempty(leaf.options)
        println(io)
        printstyled(io, "Options:\n"; bold=true, color=:yellow)
        for opt in leaf.options
            label = isempty(opt.short) ? "--$(opt.name)" : "-$(opt.short), --$(opt.name)"
            label *= "=<$(lowercase(string(opt.type)))>"
            desc = opt.description
            if !isnothing(opt.default)
                desc *= " (default: $(opt.default))"
            end
            print_entry_line(io, label, desc)
        end
    end

    # Flags
    if !isempty(leaf.flags)
        println(io)
        printstyled(io, "Flags:\n"; bold=true, color=:yellow)
        for flag in leaf.flags
            label = isempty(flag.short) ? "--$(flag.name)" : "-$(flag.short), --$(flag.name)"
            print_entry_line(io, label, flag.description)
        end
    end
end

"""
    print_entry_line(io, label, description)

Print a single help entry: `  label    description` with column alignment.
"""
function print_entry_line(io::IO, label::String, description::String)
    print(io, INDENT)
    printstyled(io, label; color=:green)
    if length(label) >= COL_WIDTH
        # Label too long — wrap description to next line
        println(io)
        print(io, INDENT, " "^COL_WIDTH)
    else
        padding = max(2, COL_WIDTH - length(label))
        print(io, " "^padding)
    end
    println(io, description)
end
