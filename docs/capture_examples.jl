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
        for k in ("elapsed_ms", "argv", "julia", "cli_version", "mems_version", "seed")
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
                    if _normalize_for_compare(fresh) != _normalize_for_compare(block.output)
                        n_diff_preview = begin
                            a = _normalize_for_compare(fresh)
                            b = _normalize_for_compare(block.output)
                            "len actual=$(length(a)) golden=$(length(b))"
                        end
                        push!(failures, "$rel: stale capture for `$(strip(split(block.bash, '\n')[1]))` ($n_diff_preview)")
                    end
                else
                    if _normalize_for_compare(fresh) != _normalize_for_compare(block.output) ||
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
