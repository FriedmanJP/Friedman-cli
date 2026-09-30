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

# Model card format — line scanner and grammar (W0 / #206)
#
# A card is a plain-text, stanza-oriented config file:
#
#     priors:
#       rho ~ beta(2, 2)
#
#     gmm lp:
#       moments: output, inflation
#
# This file holds the scanner. Value interpretation lives in the lowerers
# that follow it; a stanza line is never evaluated as code.

"""One stanza of a model card: its header, the line it starts on, and its body.

`lines` holds `(lineno, trimmed_line)` for every body line — comments and
blank lines are dropped by the scanner, so a lowerer sees only content."""
struct CardStanza
    header::String
    lineno::Int
    lines::Vector{Tuple{Int,String}}
end

const _CARD_HEADER = r"^([A-Za-z][A-Za-z0-9_-]*(?:[ \t]+[A-Za-z][A-Za-z0-9_-]*)?):[ \t]*$"

"""Every stanza header the format defines. Anything else is `config/invalid`."""
const CARD_HEADERS = Set([
    "priors", "constraints",
    "gmm lp", "gmm iv",
    "smm",
    "equations", "instruments",
])

_card_error(path, lineno, reason) =
    CliError("config/invalid", "$(path) line $(lineno): $(reason)")

"""Split a card into lines, dropping a leading UTF-8 BOM and surrounding blanks.

Notepad on Windows has written a BOM by default since 1903, and a card is
user-authored text, so the byte-order mark would otherwise fail the first header
with a message naming a cause the user cannot see."""
_card_lines(src::AbstractString) =
    [endswith(l, '\r') ? chop(l) : l for l in split(lstrip(src, '\ufeff'), '\n')]

"""True when `line`'s leading whitespace is at least two spaces wide, or a tab.

Editors differ on what they emit for an indent (Review Focus 4), so both a tab
and two or more spaces open a body line."""
function _card_is_body_indent(line::AbstractString)
    ws = match(r"^[ \t]*", line).match      # always matches, empty string included
    return occursin('\t', ws) || count(==(' '), ws) >= 2
end

"""Does `line` open a `@dsge` block at column 0?"""
_card_is_dsge_open(line) = startswith(line, "@dsge")

"""Does `line` close a `@dsge` block? Only a column-0 `end` does.

An inner block's `end` is indented; treating the first one as the close would
end the skip early and let the rest of the model be absorbed as body lines."""
_card_is_dsge_close(line) = occursin(r"^end\b", line)

"""
    parse_card(src, path="<card>") -> Vector{CardStanza}

Scan `src` into stanzas.

A line at column 0 that looks like `word:` or `word word:` opens a stanza;
inside a stanza a line indented by at least two spaces (or a tab) is a body
line. Blank lines and `#` comments are skipped anywhere, a `@dsge` block is
passed over untouched so a model file's preamble can hold both, and every line
arrives free of a trailing `\\r` or leading BOM so a Windows-authored card
parses identically (Review Focus 2).

Every rejection is a `config/invalid` `CliError` naming the 1-based line —
including an unterminated `@dsge` block, which would otherwise silently drop
the rest of the file.
"""
function parse_card(src::AbstractString, path::AbstractString="<card>")
    stanzas = CardStanza[]
    open = CardStanza[]            # at most one stanza is open at a time
    seen = Set{String}()
    in_dsge = false
    dsge_line = 0

    for (i, line) in enumerate(_card_lines(src))
        stripped = strip(line)

        if in_dsge
            if _card_is_dsge_close(line)
                in_dsge = false
            end
            continue
        end
        isempty(stripped) && continue
        startswith(stripped, '#') && continue

        m = match(_CARD_HEADER, line)
        if m !== nothing
            # The header pattern accepts any whitespace between the two words,
            # so `gmm<TAB>lp:` must normalise to the canonical space form.
            header = String(m.captures[1])
            occursin(r"[ \t]", header) && (header = join(split(header), " "))
            header in CARD_HEADERS ||
                throw(_card_error(path, i, "unknown stanza header '$(header)'"))
            header in seen &&
                throw(_card_error(path, i, "duplicate stanza header '$(header)'"))
            push!(seen, header)
            isempty(open) || push!(stanzas, pop!(open))
            push!(open, CardStanza(header, i, Tuple{Int,String}[]))
            continue
        end

        # A `@dsge` block is ordinary Julia, not card content (Task 9).
        if _card_is_dsge_open(stripped)
            in_dsge = true
            dsge_line = i
            continue
        end

        if !isempty(open)
            if _card_is_body_indent(line)
                push!(open[1].lines, (i, stripped))
                continue
            end
            # Column 0 inside a stanza closes it, then is re-examined above;
            # a non-header at column 0 is not a card at all.
            push!(stanzas, pop!(open))
        end

        throw(_card_error(path, i,
            _card_is_body_indent(line) ?
                "indented line outside a stanza; stanza headers start at the left margin" :
                "expected a stanza header or an indented body line"))
    end

    in_dsge &&
        throw(_card_error(path, dsge_line, "unterminated '@dsge' block; no closing 'end'"))
    isempty(open) || push!(stanzas, pop!(open))
    return stanzas
end

"""
    read_card(path) -> Vector{CardStanza}

Read and scan the card at `path`. A leading `~` is expanded first, then the
path is confined, then checked for existence, so a typo'd card is the same
typed `data/file-not-found` as any other missing input — never an untyped
`SystemError` (exit 1).
"""
function read_card(path::AbstractString)
    p = _validate_input_path(_expanduser(String(path)))
    isfile(p) ||
        throw(CliError("data/file-not-found", "file not found: $p"; hint="check the path"))
    return parse_card(read(p, String), p)
end

# ─── Lowerers (W0 / #206) ──────────────────────────────────────────────────────

"""Drop a trailing `#` comment and surrounding blanks from a body line."""
_card_strip_comment(s::AbstractString) = strip(first(split(s, '#'; limit=2)))

"""The single stanza named `header`, or `config/invalid` when the card has none.

A lowerer handed a card for a different family is a user error, not an empty
result: an empty dict would silently configure nothing."""
function _card_stanza(stanzas, header::AbstractString, path::AbstractString)
    for s in stanzas
        s.header == header && return s
    end
    throw(_card_error(path, 1, "card has no '$(header)' stanza"))
end

"""
    _card_vec(s) -> Vector{String}

A bare card value is a length-1 vector; a comma-separated one has one element
per comma. Shared by the GMM/SMM lowerers.
"""
function _card_vec(s::AbstractString)
    t = strip(s)
    isempty(t) && return String[]
    return String[String(strip(x)) for x in split(t, ',')]
end

# ─── A hand-written numeric-literal evaluator ─────────────────────────────────
# Stanza text is NEVER executed. `Meta.parse`/`eval` are exactly what the format
# forbids; this is a recursive-descent reader over a numeric grammar instead.
#
#   expr  := term (('+' | '-') term)*
#   term  := power (('*' | '/') power)*
#   power := unary ('^' power)?          -- right-associative
#   unary := ('+' | '-') unary | number

const _CARD_NUM_RE = r"^[0-9]+(\.[0-9]*)?([eE][+-]?[0-9]+)?$|^[0-9]*\.[0-9]+([eE][+-]?[0-9]+)?$"

"""Split a numeric expression into tokens, or return `nothing` if it is not numeric."""
function _card_num_tokens(s::AbstractString)
    toks = String[]
    i = firstindex(s)
    last_ = lastindex(s)
    while i <= last_
        c = s[i]
        if isspace(c)
            i = nextind(s, i)
        elseif c in ('+', '-', '*', '/', '^')
            push!(toks, string(c))
            i = nextind(s, i)
        elseif isdigit(c) || c == '.'
            j = i
            while j <= last_ && (isdigit(s[j]) || s[j] == '.' || s[j] in ('e', 'E'))
                # An exponent sign belongs to the number, not to a binary op.
                if s[j] in ('e', 'E') && j > i && j < last_ &&
                   s[nextind(s, j)] in ('+', '-')
                    k = nextind(s, nextind(s, j))
                    (k <= last_ && isdigit(s[k])) || return nothing
                    j = k
                end
                j = nextind(s, j)
            end
            lit = s[i:prevind(s, j)]
            occursin(_CARD_NUM_RE, lit) || return nothing
            push!(toks, lit)
            i = j
        else
            return nothing
        end
    end
    return toks
end

mutable struct _CardNumParser
    toks::Vector{String}
    i::Int
end

function _card_num_expr(p::_CardNumParser)
    v = _card_num_term(p)
    v === nothing && return nothing
    while p.i <= length(p.toks) && p.toks[p.i] in ("+", "-")
        op = p.toks[p.i]; p.i += 1
        r = _card_num_term(p)
        r === nothing && return nothing
        v = op == "+" ? v + r : v - r
    end
    return v
end

function _card_num_term(p::_CardNumParser)
    v = _card_num_power(p)
    v === nothing && return nothing
    while p.i <= length(p.toks) && p.toks[p.i] in ("*", "/")
        op = p.toks[p.i]; p.i += 1
        r = _card_num_power(p)
        (r === nothing || (op == "/" && r == 0.0)) && return nothing
        v = op == "*" ? v * r : v / r
    end
    return v
end

function _card_num_power(p::_CardNumParser)
    v = _card_num_unary(p)
    v === nothing && return nothing
    if p.i <= length(p.toks) && p.toks[p.i] == "^"
        p.i += 1
        r = _card_num_power(p)
        r === nothing && return nothing
        v = v^r
    end
    return v
end

function _card_num_unary(p::_CardNumParser)
    p.i <= length(p.toks) || return nothing
    t = p.toks[p.i]
    if t == "-" || t == "+"
        p.i += 1
        v = _card_num_unary(p)
        v === nothing && return nothing
        return t == "-" ? -v : v
    end
    occursin(_CARD_NUM_RE, t) || return nothing
    p.i += 1
    return parse(Float64, t)
end

"""
    _card_bounds_expr(s) -> Union{Float64,Nothing}

Evaluate a bound expression written in the numeric-literal grammar (`literal`
with `+ - * / ^` and unary signs), or return `nothing` when `s` names
something that is not a literal.

The evaluator is hand-written recursive descent; it never calls `eval`,
`include_string`, or `Meta.parse` on stanza text.
"""
function _card_bounds_expr(s::AbstractString)
    toks = _card_num_tokens(s)
    toks === nothing && return nothing
    isempty(toks) && return nothing
    p = _CardNumParser(toks, 1)
    v = _card_num_expr(p)
    (v === nothing || p.i <= length(p.toks)) && return nothing
    return v
end

const _CARD_DIST_ALIASES = Dict(
    "gaussian"      => "normal",
    "inverse_gamma" => "inv_gamma",
    "invgamma"      => "inv_gamma",
)

const _CARD_DISTS = Set(["beta", "normal", "inv_gamma", "gamma", "uniform"])

"""
    lower_priors(stanzas, path) -> Dict{String,Any}

Lower the `priors:` stanza into exactly what `get_dsge_priors` returns, so a
card and the equivalent TOML reach the estimator by one path.

Each body line is `name ~ dist(a, b)`. An unknown distribution, a wrong arity,
or a non-numeric argument is `config/invalid` naming its line.
"""
function lower_priors(stanzas, path::AbstractString)
    out = Dict{String,Any}()
    for (lineno, raw) in _card_stanza(stanzas, "priors", path).lines
        m = match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*~\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(([^()]*)\)$",
                  _card_strip_comment(raw))
        m === nothing &&
            throw(_card_error(path, lineno, "expected 'name ~ dist(a, b)' in a priors stanza"))
        name = String(m.captures[1])
        dist = String(m.captures[2])
        dist = get(_CARD_DIST_ALIASES, dist, dist)
        dist in _CARD_DISTS ||
            throw(_card_error(path, lineno, "unknown prior distribution '$(dist)'"))
        args = _card_vec(String(m.captures[3]))
        length(args) == 2 ||
            throw(_card_error(path, lineno, "prior '$(dist)' takes exactly 2 arguments, got $(length(args))"))
        vals = Float64[]
        for (k, a) in enumerate(args)
            v = _card_bounds_expr(a)
            v === nothing &&
                throw(_card_error(path, lineno, "prior argument $(k) of '$(name)' is not a number"))
            push!(vals, v)
        end
        out[name] = Dict{String,Any}("dist" => dist, "a" => vals[1], "b" => vals[2])
    end
    isempty(out) &&
        throw(_card_error(path, _card_stanza(stanzas, "priors", path).lineno,
                          "priors stanza is empty"))
    return out
end

const _CARD_BOUND_RE = r"^(?:(.*?)\s*(<=|>=)\s*)?([A-Za-z_][A-Za-z0-9_]*)\[t\]\s*(<=|>=)\s*(.*)$"

"""
    lower_constraints(stanzas, path) -> Dict{String,Any}

Lower the `constraints:` stanza into exactly what `get_dsge_constraints`
returns: a `bounds` list of `{variable, lower?, upper?}` and an empty
`nonlinear` list.

Each body line is `lo <= var[t] <= hi`, `var[t] >= expr`, or `var[t] <= expr`.
`var[t]` is required — an unbounded or mis-spelled constraint is a silent
no-op otherwise — and `expr` must be a numeric literal. Anything else is
`config/invalid` naming its line.
"""
function lower_constraints(stanzas, path::AbstractString)
    bounds = Dict{String,Any}[]
    for (lineno, raw) in _card_stanza(stanzas, "constraints", path).lines
        line = _card_strip_comment(raw)
        m = match(_CARD_BOUND_RE, line)
        m === nothing &&
            throw(_card_error(path, lineno,
                "expected 'lo <= var[t] <= hi', 'var[t] >= bound' or 'var[t] <= bound' in a constraints stanza"))
        var = String(m.captures[3])
        d = Dict{String,Any}("variable" => var)
        if m.captures[1] === nothing          # var[t] >= expr / var[t] <= expr
            if m.captures[4] == ">="
                v = _card_bounds_expr(String(m.captures[5]))
                v === nothing &&
                    throw(_card_error(path, lineno, "the lower bound of '$(var)' is not a numeric literal"))
                d["lower"] = v
            else
                v = _card_bounds_expr(String(m.captures[5]))
                v === nothing &&
                    throw(_card_error(path, lineno, "the upper bound of '$(var)' is not a numeric literal"))
                d["upper"] = v
            end
        else                                   # lo <= var[t] <= hi
            lo = _card_bounds_expr(String(m.captures[1]))
            hi = _card_bounds_expr(String(m.captures[5]))
            (lo === nothing || hi === nothing) &&
                throw(_card_error(path, lineno, "both bounds of '$(var)' must be numeric literals"))
            d["lower"] = lo
            d["upper"] = hi
        end
        push!(bounds, d)
    end
    return Dict{String,Any}("bounds" => bounds, "nonlinear" => Dict{String,Any}[])
end
