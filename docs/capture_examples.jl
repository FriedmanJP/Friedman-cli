#!/usr/bin/env julia
# Capture / verify bash example blocks tagged <!-- capture --> in docs.
#
# Usage:
#   julia --project docs/capture_examples.jl           # refresh capture fences
#   julia --project docs/capture_examples.jl --check   # fail if any capture is stale
#
# Convention in markdown:
#   <!-- capture -->
#   ```bash
#   friedman dsge ha steady-state huggett --format json
#   ```
#   ```json
#   <captured stdout>
#   ```
#
# Notes:
# - Only the first non-comment line of the bash fence is executed.
# - `friedman …` is rewritten to `julia --project bin/friedman …` from the repo root.
# - Status/prose goes to stderr and is discarded; stdout is the capture body.
# - Compare normalizes: strip volatile meta, sort keys, round floats (cross-OS HA solvers).

using Dates
using JSON3

const ROOT = dirname(@__DIR__)
const CHECK = "--check" in ARGS
const BIN = joinpath(ROOT, "bin", "friedman")
const FLOAT_SIGDIGITS = 8

# ── Normalization ─────────────────────────────────────────────

function _json_to_dict(obj)
    if obj isa JSON3.Object || obj isa AbstractDict
        return Dict{String,Any}(String(k) => _json_to_dict(v) for (k, v) in pairs(obj))
    elseif obj isa AbstractVector
        return Any[_json_to_dict(x) for x in obj]
    else
        return obj
    end
end

function _sort_keys(d::AbstractDict)
    out = Dict{String,Any}()
    for k in sort!(collect(String.(keys(d))))
        out[k] = d[k]
    end
    return out
end

"""Canonicalize numbers for cross-platform compare (HA solvers differ in ULPs)."""
function _canon_value(x)
    if x isa Bool
        return x
    elseif x isa Integer
        return Float64(x)
    elseif x isa AbstractFloat
        # round to fixed sigdigits; map tiny values near zero
        v = Float64(x)
        abs(v) < 1e-14 && return 0.0
        return round(v; sigdigits=FLOAT_SIGDIGITS)
    elseif x isa AbstractString
        return String(x)
    elseif x isa AbstractDict
        d = Dict{String,Any}()
        for (k, v) in pairs(x)
            d[String(k)] = _canon_value(v)
        end
        return _sort_keys(d)
    elseif x isa AbstractVector
        return Any[_canon_value(v) for v in x]
    elseif x === nothing
        return nothing
    else
        return x
    end
end

function _strip_volatile_meta!(d::AbstractDict)
    if haskey(d, "meta") && d["meta"] isa AbstractDict
        meta = Dict{String,Any}(String(k) => v for (k, v) in pairs(d["meta"]))
        # `manifest` (C052/#345) is a reproducibility record: wall-clock timestamp,
        # machine triple, thread count, git sha and resolved dep versions. Writing it
        # into a committed docs capture bakes one contributor's machine into the page
        # and churns on every regen — and the structural compare drops `meta` wholesale,
        # so no gate would ever flag it. Strip it here, exactly as the golden
        # normalizer pins `meta.manifest="GOLDEN"` (test/support.jl).
        for k in ("elapsed_ms", "argv", "julia", "cli_version", "mems_version", "seed",
                  "manifest")
            delete!(meta, k)
        end
        d["meta"] = _sort_keys(meta)
    end
    return d
end

"""Pretty JSON for docs; strip volatile meta fields."""
function _pretty_json(s::AbstractString)::String
    s = strip(String(s))
    isempty(s) && return s
    try
        d = _json_to_dict(JSON3.read(s))
        d isa AbstractDict && _strip_volatile_meta!(d)
        d = _canon_value(d)
        return sprint(io -> JSON3.pretty(io, d))
    catch
        return join(rstrip.(split(replace(s, "\r\n" => "\n"), '\n')), "\n")
    end
end

"""Stable compare string: sorted keys, rounded floats, no volatile meta."""
function _normalize_for_compare(s::AbstractString)
    s = strip(replace(String(s), "\r\n" => "\n"))
    isempty(s) && return s
    try
        d = _json_to_dict(JSON3.read(s))
        d isa AbstractDict && _strip_volatile_meta!(d)
        d = _canon_value(d)
        return String(JSON3.write(d))
    catch
        return replace(s, r"\s+" => " ")
    end
end

const COMPARE_RTOL = 1e-4
const COMPARE_ATOL = 1e-8

"""
First structural difference between a fresh capture and the committed one, as a
`path: live vs committed` string — or `nothing` when they match. Floats compare with
`isapprox` (HA solvers differ across OS/BLAS beyond fixed rounding).

It returns the *reason* rather than a Bool because `--check` reports it: a bare "stale
capture" says nothing about which field moved, and the two failure modes look identical in
CI while having opposite fixes. A missing/extra key means a leaf gained or lost a table and
the capture simply needs regenerating (this is what W13 did to `dsge ha steady-state`); a
numeric drift past the tolerance means the model output actually changed, or the tolerance
is too tight for cross-OS BLAS, and regenerating would paper over it.
"""
function _first_difference(a, b; path::String="\$")
    if a isa Bool && b isa Bool
        return a === b ? nothing : "$path: $a vs $b"
    elseif a isa Real && b isa Real && !(a isa Bool) && !(b isa Bool)
        return isapprox(Float64(a), Float64(b); rtol=COMPARE_RTOL, atol=COMPARE_ATOL) ?
               nothing : "$path: $(Float64(a)) vs $(Float64(b))"
    elseif a isa AbstractString && b isa AbstractString
        return String(a) == String(b) ? nothing : "$path: \"$a\" vs \"$b\""
    elseif a === nothing && b === nothing
        return nothing
    elseif (a isa AbstractDict || a isa JSON3.Object) && (b isa AbstractDict || b isa JSON3.Object)
        da = Dict{String,Any}(String(k) => v for (k, v) in pairs(a))
        db = Dict{String,Any}(String(k) => v for (k, v) in pairs(b))
        # ignore volatile meta entirely in structural compare
        delete!(da, "meta"); delete!(db, "meta")
        added = sort!(collect(setdiff(keys(da), keys(db))))
        gone = sort!(collect(setdiff(keys(db), keys(da))))
        if !isempty(added) || !isempty(gone)
            parts = String[]
            isempty(added) || push!(parts, "new: " * join(added, ", "))
            isempty(gone) || push!(parts, "missing: " * join(gone, ", "))
            return "$path: keys differ (" * join(parts, "; ") * ")"
        end
        for k in sort!(collect(keys(da)))
            d = _first_difference(da[k], db[k]; path="$path.$k")
            d === nothing || return d
        end
        return nothing
    elseif (a isa AbstractVector || a isa JSON3.Array) && (b isa AbstractVector || b isa JSON3.Array)
        length(a) == length(b) || return "$path: length $(length(a)) vs $(length(b))"
        for i in eachindex(a)
            d = _first_difference(a[i], b[i]; path="$path[$i]")
            d === nothing || return d
        end
        return nothing
    else
        return a == b ? nothing : "$path: $(repr(a)) vs $(repr(b))"
    end
end

"""Why a capture is stale, or `nothing` if it is current."""
function _capture_mismatch(actual::AbstractString, golden::AbstractString)
    a = strip(replace(String(actual), "\r\n" => "\n"))
    g = strip(replace(String(golden), "\r\n" => "\n"))
    ja, jg = try
        (JSON3.read(a), JSON3.read(g))
    catch
        # Not JSON (table/CSV capture): fall back to normalized text equality.
        return _normalize_for_compare(a) == _normalize_for_compare(g) ? nothing :
               "capture text differs (non-JSON output)"
    end
    return _first_difference(ja, jg)
end

_captures_match(actual::AbstractString, golden::AbstractString)::Bool =
    _capture_mismatch(actual, golden) === nothing

# ── Run one friedman command ──────────────────────────────────

function _friedman_cmd(line::AbstractString)::Cmd
    line = strip(String(line))
    startswith(line, "friedman ") || error("capture runner expects a `friedman …` command, got: $line")
    rest = line[length("friedman ")+1:end]
    args = String.(split(rest))
    julia = Base.julia_cmd().exec[1]
    return Cmd([julia, "--project=$(ROOT)", BIN, args...])
end

function _run_capture(bash_body::AbstractString)::String
    lines = filter(!isempty, strip.(split(String(bash_body), '\n')))
    lines = filter(l -> !startswith(l, "#"), lines)
    isempty(lines) && error("empty bash fence under <!-- capture -->")
    cmd_line = String(lines[1])
    cmd = _friedman_cmd(cmd_line)

    out = IOBuffer()
    err = IOBuffer()
    proc = run(pipeline(cmd; stdout=out, stderr=err); wait=true)
    success(proc) || error("capture command failed ($(proc.exitcode)): $cmd_line\n$(String(take!(err)))")
    return String(take!(out))
end

# ── Markdown parse / rewrite ───────────────────────────────────

struct CaptureBlock
    bash::String
    output::String
    start_idx::Int
    end_idx::Int
end

function _find_captures(text::String)::Vector{CaptureBlock}
    blocks = CaptureBlock[]
    re = r"<!--\s*capture\s*-->\s*```bash\n(.*?)```\s*```(?:\w*)\n(.*?)```"s
    for m in eachmatch(re, text)
        push!(blocks, CaptureBlock(String(m.captures[1]), String(m.captures[2]),
                                   m.offset, m.offset + length(m.match)))
    end
    return blocks
end

function _replace_block(text::String, block::CaptureBlock, new_output::String)::String
    re = r"<!--\s*capture\s*-->\s*```bash\n(.*?)```\s*```(?:\w*)\n(.*?)```"s
    head = text[1:block.start_idx-1]
    m = match(re, text, block.start_idx)
    m === nothing && error("capture block vanished during rewrite")
    tail = text[m.offset + length(m.match):end]
    bash = String(m.captures[1])
    lang = startswith(strip(new_output), "{") || startswith(strip(new_output), "[") ? "json" : ""
    unit = string(
        "<!-- capture -->\n",
        "```bash\n", bash, "```\n",
        "```", lang, "\n", rstrip(new_output), "\n```",
    )
    return head * unit * tail
end

# ── Main ──────────────────────────────────────────────────────

function main()
    src = joinpath(ROOT, "docs", "src")
    files = String[]
    for (root, _, names) in walkdir(src)
        for n in names
            endswith(n, ".md") && push!(files, joinpath(root, n))
        end
    end
    sort!(files)

    n_blocks = 0
    n_refreshed = 0
    failures = String[]

    for f in files
        text = read(f, String)
        blocks = _find_captures(text)
        isempty(blocks) && continue
        n_blocks += length(blocks)
        rel = relpath(f, ROOT)
        original = text
        for block in reverse(blocks)
            try
                fresh_raw = _run_capture(block.bash)
                fresh = _pretty_json(fresh_raw)
                if CHECK
                    why = _capture_mismatch(fresh, block.output)
                    if why !== nothing
                        push!(failures, "$rel: stale capture for " *
                                        "`$(strip(split(block.bash, '\n')[1]))`\n      $why")
                    end
                else
                    # Refresh when structural content drifts or pretty text differs a lot
                    if !_captures_match(fresh, block.output) ||
                       strip(replace(block.output, "\r\n" => "\n")) != strip(fresh)
                        text = _replace_block(text, block, fresh)
                        n_refreshed += 1
                    end
                end
            catch e
                push!(failures, "$rel: $(sprint(showerror, e))")
            end
        end
        if !CHECK && text != original
            write(f, text)
            println("updated $rel")
        end
    end

    if n_blocks == 0
        println("capture_examples: no <!-- capture --> blocks found (ok)")
        exit(0)
    end

    if !isempty(failures)
        println(stderr, "capture_examples: $(length(failures)) failure(s):")
        for msg in failures
            println(stderr, "  - ", msg)
        end
        exit(1)
    end

    if CHECK
        println("capture_examples: OK ($n_blocks block(s) current)")
    else
        println("capture_examples: $n_blocks block(s), $n_refreshed refreshed")
    end
end

main()
