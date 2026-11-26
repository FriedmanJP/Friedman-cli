#!/usr/bin/env julia
# Static CI drift gate for [DISPLAY] lossless handler & persistence invariant (#328).
#
# Enforces that NO handler or persistence file under:
#   - src/commands/*.jl
#   - src/storage/*.jl
#   - src/model_handle.jl
#   - src/handles.jl
# performs lossy float rounding (`round(...)`, `round.(...)`, or local `*_round*`
# helpers) on data cells emitted to DataFrames, JSON envelopes, CSV files, MCP
# responses, or saved handles. All human table rounding happens strictly at the
# presentation boundary (`src/output/render.jl:_render_table`).
#
# Usage (from repo root):
#   julia --project test/tools/check_lossless_handlers.jl

const ROOT = dirname(dirname(@__DIR__))

function _collect_target_files()::Vector{String}
    files = String[]
    for dir in (joinpath(ROOT, "src", "commands"), joinpath(ROOT, "src", "storage"))
        isdir(dir) || continue
        for f in sort!(readdir(dir))
            endswith(f, ".jl") && push!(files, joinpath(dir, f))
        end
    end
    for rel in ("src/model_handle.jl", "src/handles.jl")
        p = joinpath(ROOT, rel)
        isfile(p) && push!(files, p)
    end
    return files
end

# Contexts where `round(...)` is explicitly non-data (integer conversions, stderr prose,
# error messages, table titles, or explicitly audited algorithmic calls).
const _ALLOW_PATTERNS = Regex[
    r"#\s*lossless-ok:",                           # explicitly audited algorithmic dedup/grid
    r"\bround\(\s*Int\b",                          # integer conversion: round(Int, ...)
    r"\bInt\.?\(\s*round\.?\(",                    # integer conversion: Int(round(...))
    r"==\s*round\(",                               # integrality check: v == round(v)
    r"\b_status(?:_styled)?\s*\(",                 # stderr status prose
    r"\b_cli_warn!\s*\(",                          # stderr/envelope warning prose
    r"\binterpret_test_result\s*\(",               # stderr interpretation prose
    r"\bthrow\(\s*CliError\s*\(",                  # error message prose
    r"\btitle\s*=",                                # display table title string
    r"\bacc_pct\s*=",                              # stderr acceptance-rate percentage
    r"\br2_note\s*=",                              # stderr R^2 status prose (dsge.jl)
    r"\"[^\"]*\$\([^)]*round\([^)]*\)[^\"]*\"",    # interpolated display string/prose
]

# Multi-line call contexts where the opening call (e.g. `_status(`, `_cli_warn!(`,
# `throw(CliError(`, `interpret_test_result(`, `title =`) sits on a recent preceding line.
const _PROSE_CTX_RE = r"\b(_status|_status_styled|_cli_warn!|interpret_test_result|throw\s*\(\s*CliError|CliError\s*\(|title\s*=|hint\s*=)\b"

function _is_allowed_round(lines::Vector{String}, idx::Int)::Bool
    line = lines[idx]
    stripped = lstrip(line)
    startswith(stripped, "#") && return true
    # Ignore pure docstring / comment prose mentioning "round-trip" or "round-safe"
    !occursin(r"\bround\.?\s*\(", line) && !occursin(r"\b\w*_round\w*\s*\(", line) && return true
    for pat in _ALLOW_PATTERNS
        occursin(pat, line) && return true
    end
    # Check up to 4 preceding non-empty lines for enclosing stderr/error/title prose calls
    lo = max(1, idx - 4)
    for k in (idx - 1):-1:lo
        prev = lstrip(lines[k])
        startswith(prev, "#") && continue
        if occursin(_PROSE_CTX_RE, prev)
            return true
        end
        # Stop scanning back once we cross a clear statement boundary (e.g. `end` or `=`)
        (prev == "end" || endswith(prev, ")")) && break
    end
    return false
end

function main()
    files = _collect_target_files()
    violations = Tuple{String,Int,String}[]

    for path in files
        rel = relpath(path, ROOT)
        lines = readlines(path)
        in_docstring = false
        for (idx, line) in enumerate(lines)
            # Track triple-quoted docstrings cleanly
            n_tri = length(collect(eachmatch(r"\"\"\"", line)))
            if n_tri % 2 == 1
                in_docstring = !in_docstring
                continue
            end
            in_docstring && continue
            # Skip full-line comments
            startswith(lstrip(line), "#") && continue
            # Strip trailing inline comment before scanning (unless lossless-ok marker present)
            if occursin(r"#\s*lossless-ok:", line)
                continue
            end
            if occursin(r"\bround\.?\s*\(", line) || occursin(r"\b\w*_round\w*\s*\(", line)
                if !_is_allowed_round(lines, idx)
                    push!(violations, (rel, idx, strip(line)))
                end
            end
        end
    end

    if isempty(violations)
        println("PASS: check_lossless_handlers.jl — scanned $(length(files)) files, 0 lossy data-cell rounding calls found.")
        return 0
    end

    println("FAIL: check_lossless_handlers.jl — found $(length(violations)) forbidden rounding call(s) in handler/persistence files:")
    for (rel, idx, text) in violations
        println("  $rel:$idx  $text")
    end
    println("\nAll table float rounding belongs strictly in src/output/render.jl:_render_table.")
    println("If an algorithmic call is genuinely non-display (e.g. grid dedup), annotate with `# lossless-ok: <reason>`.")
    return 1
end

exit(main())
