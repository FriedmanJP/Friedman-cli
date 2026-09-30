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

Read and scan the card at `path`. The path is confined and resolved first, then
checked for existence, so a typo'd card is the same typed `data/file-not-found`
as any other missing input — never an untyped `SystemError` (exit 1).
"""
function read_card(path::AbstractString)
    p = _validate_input_path(String(path))
    isfile(p) ||
        throw(CliError("data/file-not-found", "file not found: $p"; hint="check the path"))
    return parse_card(read(p, String), p)
end
