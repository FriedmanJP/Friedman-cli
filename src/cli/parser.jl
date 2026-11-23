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

# Runtime argument parser inspired by Comonicon.jl codegen (see COMONICON_LICENSE)

struct ParseError <: Exception
    message::String
end

Base.showerror(io::IO, e::ParseError) = print(io, "ParseError: ", e.message)

struct DispatchError <: Exception
    message::String
end

Base.showerror(io::IO, e::DispatchError) = print(io, "DispatchError: ", e.message)

struct ParsedArgs
    positional::Vector{String}
    options::Dict{String,String}
    flags::Set{String}
    multi::Dict{String,Vector{String}}  # every valued option occurrence, in order (superset of `options`; the repeatable subset is read by name) (CARD-W1 #209)
end
ParsedArgs(pos, opts, flags) = ParsedArgs(pos, opts, flags, Dict{String,Vector{String}}())

"""True if `t` looks like an option value (not a flag), including negative numbers (F2)."""
function _looks_like_value(t::AbstractString)
    n = ncodeunits(t)
    n == 0 && return true
    codeunit(t, 1) != UInt8('-') && return true
    n >= 2 || return false
    b = codeunit(t, 2)
    (UInt8('0') <= b <= UInt8('9')) && return true
    return b == UInt8('.') && n >= 3 && (UInt8('0') <= codeunit(t, 3) <= UInt8('9'))
end

"""
    tokenize(tokens, [cmd]) → ParsedArgs

Parse raw CLI tokens into positional args, options, and flags.
Handles: `--option=value`, `--option value`, `-o=value`, `-o value`, `--flag`, `-f`, positional args.
When `cmd` is provided, known boolean flags never consume the next positional token.
`--` stops option parsing (everything after is positional).
Negative numeric values (`-0.5`, `-3`) bind as option values (F2).
"""
function tokenize(tokens::Vector{String}, cmd::Union{Nothing,LeafCommand}=nothing)
    positional = String[]
    options = Dict{String,String}()
    flags = Set{String}()
    multi = Dict{String,Vector{String}}()
    is_flag(k::AbstractString) = cmd !== nothing && (String(k) in cmd.known_flags)
    i = 1
    stop_parsing = false
    while i <= length(tokens)
        tok = tokens[i]
        if stop_parsing
            push!(positional, tok)
            i += 1
        elseif tok == "--"
            stop_parsing = true
            i += 1
        elseif startswith(tok, "--")
            body = tok[3:end]
            if contains(body, '=')
                k, v = split(body, '='; limit=2)
                options[k] = v
                push!(get!(multi, k, String[]), v)
            elseif is_flag(body)
                push!(flags, body)
            elseif i + 1 <= length(tokens) && _looks_like_value(tokens[i+1])
                options[body] = tokens[i+1]
                push!(get!(multi, body, String[]), tokens[i+1])
                i += 1
            else
                # Treat as flag
                push!(flags, body)
            end
            i += 1
        elseif startswith(tok, "-") && length(tok) > 1
            short = tok[2:end]
            if length(short) >= 2 && short[2] == '='
                # Short option with '=': -f=json
                k = string(short[1])
                v = short[3:end]
                options[k] = v
                push!(get!(multi, k, String[]), v)
            elseif length(short) == 1
                # Single short option / flag
                if is_flag(short)
                    push!(flags, short)
                elseif i + 1 <= length(tokens) && _looks_like_value(tokens[i+1])
                    options[short] = tokens[i+1]
                    push!(get!(multi, short, String[]), tokens[i+1])
                    i += 1
                else
                    push!(flags, short)
                end
            else
                # Bundled short flags: -abc → flags a, b, c
                for ch in short
                    push!(flags, string(ch))
                end
            end
            i += 1
        else
            push!(positional, tok)
            i += 1
        end
    end
    return ParsedArgs(positional, options, flags, multi)
end

_fmt_opt_name(k::AbstractString) = ncodeunits(k) == 1 ? "-$k" : "--$k"

function _choice_match(raw::String, choices::Vector{String})
    raw in choices && return raw
    norm_raw = replace(raw, "_" => "-")
    for c in choices
        replace(c, "_" => "-") == norm_raw && return c
    end
    return nothing
end

"""
    resolve_option(parsed, opt) → value or default

Look up an Option by its long name, short alias, or long aliases and convert to the target type.
"""
function resolve_option(parsed::ParsedArgs, opt::Option)
    spellings = String[opt.name]
    isempty(opt.short) || push!(spellings, opt.short)
    append!(spellings, opt.aliases)

    found_keys = String[]
    found_vals = String[]
    for sp in spellings
        if haskey(parsed.options, sp)
            push!(found_keys, sp)
            push!(found_vals, parsed.options[sp])
        end
    end
    if length(found_keys) > 1
        throw(ParseError("conflicting options: specify only one of $(join(_fmt_opt_name.(found_keys), ", "))"))
    end
    isempty(found_vals) && return opt.default
    raw = found_vals[1]
    if opt.choices !== nothing
        matched = _choice_match(raw, opt.choices)
        if matched === nothing
            throw(ParseError("option --$(opt.name) must be one of $(join(opt.choices, "|")), got '$raw'"))
        end
        raw = matched
    end
    return convert_value(opt.type, raw, opt.name)
end

"""
    resolve_flag(parsed, flag) → Bool

Check if a Flag was set (by long name, short alias, or long aliases).
"""
function resolve_flag(parsed::ParsedArgs, flag::Flag)
    flag.name in parsed.flags && return true
    !isempty(flag.short) && flag.short in parsed.flags && return true
    for a in flag.aliases
        a in parsed.flags && return true
    end
    return false
end

"""
    convert_value(T, raw, name) → T

Convert a raw string to the target type.
"""
function convert_value(::Type{T}, raw::String, name::String) where T <: Integer
    v = tryparse(T, raw)
    isnothing(v) && throw(ParseError("option --$name expects an integer, got '$raw'"))
    return v
end

function convert_value(::Type{T}, raw::String, name::String) where T <: AbstractFloat
    v = tryparse(T, raw)
    isnothing(v) && throw(ParseError("option --$name expects a number, got '$raw'"))
    return v
end

function convert_value(::Type{String}, raw::String, ::String)
    return raw
end

function convert_value(::Type{Symbol}, raw::String, ::String)
    return Symbol(raw)
end

function convert_value(::Type{Bool}, raw::String, name::String)
    s = lowercase(raw)
    s in ("true", "1", "yes", "y") && return true
    s in ("false", "0", "no", "n") && return false
    throw(ParseError("option --$name expects a boolean (true/false/1/0/yes/no), got '$raw'"))
end

function convert_value(::Type{T}, raw::String, name::String) where T
    if !hasmethod(tryparse, Tuple{Type{T}, String})
        throw(ParseError("option --$name: cannot convert '$raw' to $T"))
    end
    v = tryparse(T, raw)
    isnothing(v) && throw(ParseError("option --$name: cannot convert '$raw' to $T"))
    return v
end

"""Levenshtein distance (F1 suggestions)."""
function _levenshtein(a::AbstractString, b::AbstractString)
    ca = collect(a)
    cb = collect(b)
    m, n = length(ca), length(cb)
    m == 0 && return n
    n == 0 && return m
    prev = collect(0:n)
    curr = Vector{Int}(undef, n + 1)
    for i in 1:m
        curr[1] = i
        ai = ca[i]
        for j in 1:n
            cost = ai == cb[j] ? 0 : 1
            curr[j+1] = min(prev[j+1] + 1, curr[j] + 1, prev[j] + cost)
        end
        prev, curr = curr, prev
    end
    return prev[n+1]
end

"""Nearest known option within distance 2, else `nothing`."""
function _nearest(word::AbstractString, cands)
    best = nothing
    best_d = 3
    for c in cands
        d = _levenshtein(word, c)
        if d < best_d
            best_d = d
            best = c
        end
    end
    return best_d <= 2 ? best : nothing
end

"""
    bind_args(parsed, cmd) → NamedTuple

Bind parsed tokens to a LeafCommand's declared arguments, options, and flags.
Unknown options throw ParseError with a did-you-mean hint (F1).
"""
function bind_args(parsed::ParsedArgs, cmd::LeafCommand; has_extra_model::Bool=false)
    # Unknown option / flag detection (F1)
    known = cmd.known_opts
    for k in keys(parsed.options)
        if !(k in known)
            sugg = _nearest(k, known)
            hint = sugg === nothing ? "" : " — did you mean $(_fmt_opt_name(sugg))?"
            throw(ParseError("unknown option $(_fmt_opt_name(k))$hint"))
        end
    end
    for k in parsed.flags
        if !(k in known)
            sugg = _nearest(k, known)
            hint = sugg === nothing ? "" : " — did you mean $(_fmt_opt_name(sugg))?"
            throw(ParseError("unknown option $(_fmt_opt_name(k))$hint"))
        end
    end
    if !isempty(parsed.multi)
        for k in keys(parsed.multi)
            if !(k in known)
                sugg = _nearest(k, known)
                hint = sugg === nothing ? "" : " — did you mean $(_fmt_opt_name(sugg))?"
                throw(ParseError("unknown option $(_fmt_opt_name(k))$hint"))
            end
        end
    end

    # Single Dict holds positional + option + flag bindings (converted to NamedTuple)
    bound = Dict{Symbol,Any}()
    sizehint!(bound, length(cmd.args) + length(cmd.options) + length(cmd.flags))

    # --model PATH.fmod (or REPL extra_kwargs model) makes <data> optional (C029 / #253):
    # only handle-style --model options (no fixed choices, empty/nothing default) relax <data>.
    has_mod_handle = any(o -> o.name == "model" && (o.default === "" || o.default === nothing) && o.choices === nothing, cmd.options)
    model_val = get(parsed.options, "model", "")
    result_val = get(parsed.options, "result", "")
    model_set = has_extra_model || (has_mod_handle && !isempty(model_val))
    result_set = !isempty(result_val)

    n_pos = length(parsed.positional)
    for (idx, arg) in enumerate(cmd.args)
        asym = cmd.arg_syms[idx]
        if idx <= n_pos
            bound[asym] = convert_value(arg.type, parsed.positional[idx], arg.name)
        elseif arg.required
            if (model_set && arg.name == "data") || (result_set && arg.name in ("data", "model"))
                bound[asym] = something(arg.default, "")
            else
                throw(ParseError("missing required argument: <$(arg.name)>"))
            end
        else
            bound[asym] = arg.default
        end
    end

    # Check for excess positional args
    if n_pos > length(cmd.args)
        extras = parsed.positional[length(cmd.args)+1:end]
        throw(ParseError("unexpected arguments: $(join(extras, ", "))"))
    end

    # Bind options
    for (idx, opt) in enumerate(cmd.options)
        key = cmd.opt_syms[idx]
        if opt.repeatable
            vals = String[]
            for sp in vcat([opt.name], isempty(opt.short) ? String[] : [opt.short], opt.aliases)
                append!(vals, get(parsed.multi, sp, String[]))
            end
            bound[key] = vals
        else
            bound[key] = resolve_option(parsed, opt)
        end
    end

    # Bind flags
    for (idx, flag) in enumerate(cmd.flags)
        bound[cmd.flag_syms[idx]] = resolve_flag(parsed, flag)
    end

    return (; bound...)
end
