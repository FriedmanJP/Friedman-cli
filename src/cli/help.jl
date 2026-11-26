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
const HELP_MAX_WIDTH = 100

"""Target wrap width for help prose (#346): deterministic 100 columns on non-TTY/cache,
capped at 100 (floor 60) on narrow interactive TTYs."""
function _help_width(io::IO)::Int
    if io isa Base.TTY
        cols = try displaysize(io)[2] catch; HELP_MAX_WIDTH end
        return min(max(60, cols), HELP_MAX_WIDTH)
    end
    return HELP_MAX_WIDTH
end

"""Split an overlong whitespace-free pipe-list token cleanly AFTER `|` characters so
no individual choice name is ever broken mid-token."""
function _split_pipe_token(tok::AbstractString, width::Int)::Vector{String}
    parts = split(tok, '|')
    out = String[]
    cur = ""
    for (idx, part) in enumerate(parts)
        seg = idx < length(parts) ? string(part, "|") : string(part)
        if isempty(cur)
            cur = seg
        elseif length(cur) + length(seg) <= width
            cur *= seg
        else
            push!(out, cur)
            cur = seg
        end
    end
    isempty(cur) || push!(out, cur)
    return out
end

"""Word-wrap `text` to at most `width` display columns, preserving explicit newlines and
never splitting choice names mid-token (#346)."""
function _wrap_text(text::AbstractString, width::Int)::Vector{String}
    lines = String[]
    for para in split(String(text), '\n')
        if isempty(para)
            push!(lines, "")
            continue
        end
        if length(para) <= width
            push!(lines, String(para))
            continue
        end
        cur = ""
        for raw_word in split(para)
            w = String(raw_word)
            if length(w) > width && contains(w, '|')
                sub_parts = _split_pipe_token(w, width)
                for sp in sub_parts
                    if isempty(cur)
                        cur = sp
                    elseif length(cur) + 1 + length(sp) <= width
                        cur = cur * " " * sp
                    else
                        push!(lines, cur)
                        cur = sp
                    end
                end
            elseif isempty(cur)
                cur = w
            elseif length(cur) + 1 + length(w) <= width
                cur = cur * " " * w
            else
                push!(lines, cur)
                cur = w
            end
        end
        isempty(cur) || push!(lines, cur)
    end
    return isempty(lines) ? String[""] : lines
end

function _subcmd_label(node::NodeCommand, name::String)::String
    als = String[]
    for (al, target) in node.aliases
        target == name && push!(als, al)
    end
    isempty(als) && return name
    sort!(als)
    return "$name ($(join(als, ", ")))"
end

_has_printable_default(d) = d !== nothing &&
    !(d isa AbstractString && isempty(d)) &&
    !(d isa AbstractVector && isempty(d)) &&
    !(d isa AbstractFloat && (isnan(d) || isinf(d)))

_desc_mentions_default(desc::AbstractString) = occursin(r"\(default[:\s]"i, desc)

"""
    print_repl_help(io=stdout; prog="frdc repl")

Print help for the interactive `frdc repl` subcommand.
"""
function print_repl_help(io::IO=stdout; prog::String="frdc repl")
    printstyled(io, prog, "\n"; bold=true)
    println(io)
    println(io, "Start an interactive session with persistent arrow-key history, line editing, and tab completion.")
    println(io)
    printstyled(io, "Usage:\n"; bold=true, color=:yellow)
    println(io, INDENT, prog)
    println(io)
    printstyled(io, "Session Commands:\n"; bold=true, color=:yellow)
    print_entry_line(io, "data use <source>", "Bind a dataset (.csv, .jld2, .jls, stem, or :example) to the session")
    print_entry_line(io, "data current", "Show the active session dataset and cached estimation results")
    print_entry_line(io, "data clear", "Clear the active session dataset and cached results")
    print_entry_line(io, "exit, quit", "Exit the interactive session (or press Ctrl-D)")
    println(io)
    printstyled(io, "Environment:\n"; bold=true, color=:yellow)
    print_entry_line(io, "FRDC_HISTFILE", "History file path (default: ~/.frdc_history; fallback: FRIEDMAN_HISTFILE; set to none to disable)")
end

"""
    print_help(io, entry)

Print top-level help for the CLI entry point.
"""
function print_help(io::IO, entry::Entry)
    print_help(io, entry.root; prog=entry.name, version=entry.version)
    println(io)
    printstyled(io, "Interactive:\n"; bold=true, color=:yellow)
    print_entry_line(io, "$(entry.name) repl",
        "Start an interactive session with persistent history and tab completion")
    println(io)
    printstyled(io, "Global Flags:\n"; bold=true, color=:yellow)
    print_entry_line(io, "--seed=<int>", "Set deterministic RNG seed for estimation/simulation")
    print_entry_line(io, "--digits=<int|full>", "Decimal places for table display (0..16 or 'full'; default: 3; env: FRDC_DIGITS)")
    print_entry_line(io, "-q, --quiet", "Suppress status prose on stderr")
    print_entry_line(io, "-J, --json", "Print compact JSON output")
    print_entry_line(io, "--compact", "Fit wide/tall tables to interactive TTYs (precision controlled by --digits)")
    print_entry_line(io, "--no-color", "Disable ANSI color formatting")
    print_entry_line(io, "-V, --version", "Print version and exit")
    print_entry_line(io, "-h, --help", "Show this help message and exit")
    print_entry_line(io, "--warranty, --conditions", "Show GNU GPL v3 warranty and license conditions")
end

"""
    print_help(io, node; prog, version)

Print help for a NodeCommand (command group).
"""
function print_help(io::IO, node::NodeCommand; prog::String=node.name,
                    version::Union{VersionNumber,Nothing}=nothing,
                    aliases::Vector{String}=String[])
    w = _help_width(io)
    # Header
    if !isnothing(version)
        printstyled(io, prog, " v", version, "\n"; bold=true)
    else
        printstyled(io, prog, "\n"; bold=true)
    end
    if !isempty(node.description)
        println(io)
        for ln in _wrap_text(node.description, w)
            println(io, ln)
        end
    end
    if !isempty(aliases)
        println(io)
        println(io, "Aliases: ", join(aliases, ", "))
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
    if !isnothing(version) && !isempty(node.subcmds)
        println(io)
        printstyled(io, "Commands:\n"; bold=true, color=:yellow)
        for name in sort!(collect(keys(node.subcmds)))
            print_entry_line(io, _subcmd_label(node, name), node.subcmds[name].description)
        end
    else
        if !isempty(nodes)
            println(io)
            printstyled(io, "Commands:\n"; bold=true, color=:yellow)
            for (name, cmd) in nodes
                print_entry_line(io, _subcmd_label(node, name), cmd.description)
            end
        end
        if !isempty(leaves)
            grouped = any(!isempty, (cmd.family for (_, cmd) in leaves))
            if !grouped
                println(io)
                printstyled(io, "Commands:\n"; bold=true, color=:yellow)
                for (name, cmd) in leaves
                    print_entry_line(io, _subcmd_label(node, name), cmd.description)
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
                        print_entry_line(io, _subcmd_label(node, name), cmd.description)
                    end
                end
            end
        end
    end

    # Footer
    println(io)
    println(io, "Use '", prog, " <command> --help' for more information on a command.")
end

"""
    print_help(io, leaf; prog, aliases)

Print help for a LeafCommand (terminal command).
"""
function print_help(io::IO, leaf::LeafCommand; prog::String=leaf.name,
                    aliases::Vector{String}=String[])
    w = _help_width(io)
    # Header
    printstyled(io, prog, "\n"; bold=true)
    if !isempty(leaf.description)
        println(io)
        for ln in _wrap_text(leaf.description, w)
            println(io, ln)
        end
    end
    if !isempty(aliases)
        println(io)
        println(io, "Aliases: ", join(aliases, ", "))
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
        has_mod_handle = any(o -> o.name == "model" && o.default === "" && o.choices === nothing, leaf.options)
        has_res_handle = any(o -> o.name == "result" && o.default === "" && o.choices === nothing, leaf.options)
        println(io)
        printstyled(io, "Arguments:\n"; bold=true, color=:yellow)
        for arg in leaf.args
            label = arg.required ? "<$(arg.name)>" : "[$(arg.name)]"
            desc = arg.description
            if arg.required && arg.name in ("data", "model") && (has_mod_handle || has_res_handle) &&
               !occursin("optional when", lowercase(desc))
                if has_mod_handle && has_res_handle
                    desc *= " (optional when --model or --result is given)"
                elseif has_mod_handle
                    desc *= " (optional when --model is given)"
                else
                    desc *= " (optional when --result is given)"
                end
            end
            if !arg.required && _has_printable_default(arg.default) && !_desc_mentions_default(desc)
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
            if opt.choices !== nothing && !isempty(opt.choices) && !all(c -> occursin(c, desc), opt.choices)
                desc *= " [choices: $(join(opt.choices, "|"))]"
            end
            if opt.repeatable && !occursin("repeatable", lowercase(desc))
                desc *= " (repeatable)"
            end
            if _has_printable_default(opt.default) && !_desc_mentions_default(desc)
                desc *= " (default: $(opt.default))"
            end
            if !isempty(opt.aliases)
                desc *= " [aliases: $(join(["--" * a for a in opt.aliases], ", "))]"
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
            desc = flag.description
            if !isempty(flag.aliases)
                desc *= " [aliases: $(join(["--" * a for a in flag.aliases], ", "))]"
            end
            print_entry_line(io, label, desc)
        end
    end
end

"""
    print_entry_line(io, label, description)

Print a single help entry: `  label    description` with column alignment and
hanging-indent word wrapping at `_help_width(io)` (≤ 100 cols) (#346).
"""
function print_entry_line(io::IO, label::String, description::String)
    cont_indent = INDENT * " "^COL_WIDTH
    desc_width = max(30, _help_width(io) - length(cont_indent))
    wrapped = _wrap_text(description, desc_width)
    print(io, INDENT)
    printstyled(io, label; color=:green)
    if length(label) >= COL_WIDTH - 1
        # Label too long (would leave <2 spaces before COL_WIDTH) — wrap description to next line
        println(io)
        print(io, cont_indent)
    else
        padding = COL_WIDTH - length(label)
        print(io, " "^padding)
    end
    println(io, wrapped[1])
    for i in 2:length(wrapped)
        println(io, cont_indent, wrapped[i])
    end
end
