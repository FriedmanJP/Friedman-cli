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
#   ```
#   <captured stdout>
#   ```
#
# Notes:
# - Only the first non-comment line of the bash fence is executed.
# - `friedman …` is rewritten to `julia --project bin/friedman …` from the repo root.
# - Status/prose goes to stderr and is discarded; stdout is the capture body.
# - JSON envelopes are normalized (drop meta.elapsed_ms / meta.argv) before compare.

using Dates
using JSON3

const ROOT = dirname(@__DIR__)
const CHECK = "--check" in ARGS
const BIN = joinpath(ROOT, "bin", "friedman")

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

"""Pretty JSON for docs; strip volatile meta fields."""
function _pretty_json(s::AbstractString)::String
    s = strip(String(s))
    isempty(s) && return s
    try
        obj = JSON3.read(s)
        d = _json_to_dict(obj)
        if d isa AbstractDict && haskey(d, "meta") && d["meta"] isa AbstractDict
            meta = d["meta"]
            delete!(meta, "elapsed_ms")
            delete!(meta, "argv")
        end
        return sprint(io -> JSON3.pretty(io, d))
    catch
        return join(rstrip.(split(s, '\n')), "\n")
    end
end

function _normalize_for_compare(s::AbstractString)
    # re-parse both sides so pretty vs compact compare equal
    try
        a = _json_to_dict(JSON3.read(strip(String(s))))
        if a isa AbstractDict && haskey(a, "meta") && a["meta"] isa AbstractDict
            delete!(a["meta"], "elapsed_ms")
            delete!(a["meta"], "argv")
        end
        return String(JSON3.write(a))
    catch
        return replace(strip(String(s)), r"\s+" => " ")
    end
end

# ── Run one friedman command ──────────────────────────────────

function _friedman_cmd(line::AbstractString)::Cmd
    line = strip(String(line))
    startswith(line, "friedman ") || error("capture runner expects a `friedman …` command, got: $line")
    rest = line[length("friedman ")+1:end]
    args = String.(split(rest))
    # Base.julia_cmd() is a Cmd; take the julia binary path
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

"""
Parse a markdown file into segments alternating prose and capture blocks.

A capture block is:
  <!-- capture -->
  ```bash
  ...
  ```
  ```
  ...output...
  ```
  (output fence language optional; bare ``` also accepted)
"""
struct CaptureBlock
    bash::String
    output::String
    start_idx::Int   # index of <!-- capture --> in original text
    end_idx::Int     # exclusive end after output fence
end

function _find_captures(text::String)::Vector{CaptureBlock}
    blocks = CaptureBlock[]
    # Regex: capture tag, bash fence, output fence
    re = r"<!--\s*capture\s*-->\s*```bash\n(.*?)```\s*```(?:\w*)\n(.*?)```"s
    for m in eachmatch(re, text)
        bash = String(m.captures[1])
        out = String(m.captures[2])
        push!(blocks, CaptureBlock(bash, out, m.offset, m.offset + length(m.match)))
    end
    return blocks
end

function _replace_block(text::String, block::CaptureBlock, new_output::String)::String
    # Rebuild the whole capture unit
    # Keep bash fence exactly as in source (from match)
    re = r"<!--\s*capture\s*-->\s*```bash\n(.*?)```\s*```(?:\w*)\n(.*?)```"s
    # Replace only the matched region for this block by offset
    head = text[1:block.start_idx-1]
    # Find original match string length
    m = match(re, text, block.start_idx)
    m === nothing && error("capture block vanished during rewrite")
    tail = text[m.offset + length(m.match):end]
    bash = String(m.captures[1])
    # Prefer ```json when output looks like JSON
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
    n_stale = 0
    n_refreshed = 0
    failures = String[]

    for f in files
        text = read(f, String)
        blocks = _find_captures(text)
        isempty(blocks) && continue
        n_blocks += length(blocks)
        rel = relpath(f, ROOT)
        # Process from end so earlier offsets stay valid when rewriting
        for block in reverse(blocks)
            try
                fresh_raw = _run_capture(block.bash)
                fresh = _pretty_json(fresh_raw)
                if CHECK
                    if _normalize_for_compare(fresh) != _normalize_for_compare(block.output)
                        n_stale += 1
                        push!(failures, "$rel: stale capture for `$(strip(split(block.bash, '\n')[1]))`")
                    end
                else
                    # Refresh when semantic content OR pretty formatting differs
                    if _normalize_for_compare(fresh) != _normalize_for_compare(block.output) ||
                       strip(block.output) != strip(fresh)
                        text = _replace_block(text, block, fresh)
                        n_refreshed += 1
                    end
                end
            catch e
                push!(failures, "$rel: $(sprint(showerror, e))")
            end
        end
        if !CHECK && n_refreshed > 0
            # Only write if we changed this file (recount refreshed is global; check content)
            # Re-read whether text differs from disk
            if text != read(f, String)
                write(f, text)
                println("updated $rel")
            end
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
