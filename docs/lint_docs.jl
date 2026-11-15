#!/usr/bin/env julia
# Mechanical documentation linter enforcing docs/docrule.md.
#
# Usage:
#   julia --project docs/lint_docs.jl

const ROOT = dirname(@__DIR__)
const SRCDOCS = joinpath(ROOT, "docs", "src")

const LANDING = Set(["index.md"])
const GETTING_STARTED = Set([
    "getting-started/installation.md",
    "getting-started/pipelines.md",
    "getting-started/method-guide.md",
    "getting-started/repl.md",
])
const CHAPTER = Set([
    "chapters/data.md",
    "chapters/univariate.md",
    "chapters/volatility.md",
    "chapters/nonlinear.md",
    "chapters/multivariate.md",
    "chapters/structural.md",
    "chapters/nowcast.md",
    "chapters/regression.md",
    "chapters/choice.md",
    "chapters/panel.md",
    "chapters/dsge.md",
    "chapters/hadsge.md",
    "chapters/policy.md",
    "chapters/io.md",
    "chapters/tests.md",
])
const CONFIG = Set([
    "config/overview.md",
    "config/identification.md",
    "config/dsge.md",
    "config/models-policy.md",
])
const INTERNALS = Set([
    "internals/architecture.md",
    "internals/api.md",
    "internals/not-wrapped.md",
])
const EXPECTED_STATIC = union(LANDING, GETTING_STARTED, CHAPTER, CONFIG, INTERNALS, Set(["commands/overview.md"]))

struct Violation
    file::String
    line::Int
    rule::String
    msg::String
end

function _strip_fences(lines::Vector{String})
    out = Tuple{Int,String}[]
    in_fence = false
    fence_char = '`'
    fence_len = 0
    for (i, line) in enumerate(lines)
        s = lstrip(line)
        m = match(r"^(`{3,}|~{3,})", s)
        if m !== nothing
            tok = m.captures[1]
            ch = tok[1]
            len = length(tok)
            if !in_fence
                in_fence = true
                fence_char = ch
                fence_len = len
                continue
            elseif ch == fence_char && len >= fence_len && isempty(strip(s[len+1:end]))
                in_fence = false
                continue
            end
        end
        in_fence || push!(out, (i, line))
    end
    return out
end

function _lint_file!(violations::Vector{Violation}, rel::String, path::String, all_ids::Dict{String,Vector{String}}, refs_used::Vector{Tuple{String,Int,String}})
    lines = readlines(path)
    prose = _strip_fences(lines)
    is_gen = startswith(rel, "commands/generated/")
    is_chap = rel in CHAPTER
    is_hand = !is_gen

    # H1, depth, and @id collection
    seen_h1 = false
    seen_h2 = false
    h2_lines = Int[]
    has_quick_start = false
    has_pitfalls = false
    has_refs = false

    for (ln, line) in prose
        m_id = match(r"^#{1,3}\s+\[.+?\]\(@id\s+([^)\s]+)\)\s*$", line)
        if m_id !== nothing
            push!(get!(all_ids, String(m_id.captures[1]), String[]), "$rel:$ln")
        elseif occursin("(@id", line)
            push!(violations, Violation(rel, ln, "BAD-ID-SYNTAX", "Documenter @id must wrap the entire heading as # [Title](@id slug)"))
        end
        for m in eachmatch(r"\]\(@ref\s+([^)\s]+)\)", line)
            push!(refs_used, (rel, ln, String(m.captures[1])))
        end

        if startswith(line, "####")
            push!(violations, Violation(rel, ln, "DEPTH", "H4+ heading forbidden by docrule.md: $(strip(line))"))
        elseif startswith(line, "### ")
            if !seen_h2
                push!(violations, Violation(rel, ln, "DEPTH", "H3 heading before any H2 heading: $(strip(line))"))
            end
        elseif startswith(line, "## ")
            seen_h2 = true
            push!(h2_lines, ln)
            raw_h2 = strip(line[4:end])
            m_h2 = match(r"^\[(.+?)\]\(@id\s+[^)]+\)$", raw_h2)
            h2 = m_h2 === nothing ? raw_h2 : strip(m_h2.captures[1])
            h2 == "Quick Start" && (has_quick_start = true)
            h2 == "Common Pitfalls" && (has_pitfalls = true)
            h2 == "References" && (has_refs = true)
        elseif startswith(line, "# ")
            if seen_h1
                push!(violations, Violation(rel, ln, "H1", "multiple H1 headings on page"))
            end
            seen_h1 = true
            if is_hand && ln != 1
                push!(violations, Violation(rel, ln, "H1", "H1 on hand-written page must be on line 1 (got line $ln)"))
            end
            if !occursin(r"^#\s+\[.+?\]\(@id\s+[^)\s]+\)\s*$", line)
                push!(violations, Violation(rel, ln, "H1", "H1 missing canonical `[Title](@id ...)` anchor"))
            end
        end

        if is_hand && occursin(r"^\|\s*(Option|Flag|Argument)\s*\|"i, line)
            push!(violations, Violation(rel, ln, "NO-FLAG-TABLE", "hand-copied CLI flag/option/argument table forbidden outside commands/generated/"))
        end

        if occursin(r"\b(TODO|FIXME)\b|not yet implemented"i, line) && !(rel == "internals/not-wrapped.md")
            push!(violations, Violation(rel, ln, "NO-TODO", "placeholder / TODO / FIXME marker found outside code block"))
        end
    end

    seen_h1 || push!(violations, Violation(rel, 1, "H1", "page has no `# ` H1 title"))

    # Check --- separator before H2 sections (after Quick Start / first H2) on chapters & getting-started
    if is_chap || rel in GETTING_STARTED
        for k in 2:length(h2_lines)
            idx = h2_lines[k]
            prev_nonblank = ""
            p = idx - 1
            while p >= 1 && isempty(strip(lines[p]))
                p -= 1
            end
            p >= 1 && (prev_nonblank = strip(lines[p]))
            prev_nonblank == "---" || push!(violations, Violation(rel, idx, "SECTION-RULE", "missing `---` horizontal rule before H2 heading"))
        end
    end

    if is_chap
        has_quick_start || push!(violations, Violation(rel, 1, "SKELETON", "chapter missing `## Quick Start`"))
        has_pitfalls    || push!(violations, Violation(rel, 1, "SKELETON", "chapter missing `## Common Pitfalls`"))
        has_refs        || push!(violations, Violation(rel, 1, "SKELETON", "chapter missing `## References`"))

        text = read(path, String)
        occursin("<!-- capture -->", text) || push!(violations, Violation(rel, 1, "SKELETON", "chapter has no `<!-- capture -->` verified example"))
        occursin("(@ref ref-", text) || push!(violations, Violation(rel, 1, "SKELETON", "chapter has no `(@ref ref-...)` link to Generated CLI Reference"))
        occursin("MacroEconometricModels.jl", text) || push!(violations, Violation(rel, 1, "SKELETON", "chapter missing link/citation to MacroEconometricModels.jl"))
        nlines = length(lines)
        (120 <= nlines <= 1150) || push!(violations, Violation(rel, nlines, "SIZE", "chapter line count $nlines outside [120, 1150] target band"))
    end
end

function main()
    violations = Violation[]
    all_ids = Dict{String,Vector{String}}()
    refs_used = Tuple{String,Int,String}[]

    actual_files = Set{String}()
    for (root, _, names) in walkdir(SRCDOCS)
        for n in names
            endswith(n, ".md") || continue
            rel = replace(relpath(joinpath(root, n), SRCDOCS), '\\' => '/')
            rel == "agent-guide.md" && continue  # build-time copy of src/commands/agent_guide.md
            push!(actual_files, rel)
        end
    end

    for exp in sort(collect(EXPECTED_STATIC))
        exp in actual_files || push!(violations, Violation(exp, 0, "MISSING", "expected doc page missing from docs/src/"))
    end

    for rel in sort(collect(actual_files))
        is_known = rel in EXPECTED_STATIC || startswith(rel, "commands/generated/")
        if !is_known
            push!(violations, Violation(rel, 0, "ORPHAN", "unclassified markdown page under docs/src/ (not in make.jl sidebar plan)"))
            continue
        end
        _lint_file!(violations, rel, joinpath(SRCDOCS, rel), all_ids, refs_used)
    end

    # Check agent_guide.md source directly
    ag_path = joinpath(ROOT, "src", "commands", "agent_guide.md")
    if !isfile(ag_path)
        push!(violations, Violation("src/commands/agent_guide.md", 0, "MISSING", "agent_guide.md missing"))
    else
        ag_lines = readlines(ag_path)
        startswith(ag_lines[1], "# Agent Guide") || push!(violations, Violation("src/commands/agent_guide.md", 1, "AGENT-GUIDE", "line 1 must start with `# Agent Guide`"))
        for (ln, line) in _strip_fences(ag_lines)
            if occursin("@id", line) || occursin("@ref", line)
                push!(violations, Violation("src/commands/agent_guide.md", ln, "AGENT-GUIDE", "Documenter `@id`/`@ref` directives forbidden in schema --docs source"))
            end
            if occursin(r"^\|\s*(Option|Flag|Argument)\s*\|"i, line)
                push!(violations, Violation("src/commands/agent_guide.md", ln, "NO-FLAG-TABLE", "hand-copied option table forbidden in agent_guide.md"))
            end
        end
    end

    # Cross-file @id uniqueness & @ref resolution
    for (id, locs) in sort!(collect(pairs(all_ids)))
        length(locs) == 1 || push!(violations, Violation(first(locs), 0, "DUP-ID", "duplicate @id '$id' also at: " * join(locs[2:end], ", ")))
    end
    for (rel, ln, target) in refs_used
        haskey(all_ids, target) || push!(violations, Violation(rel, ln, "BROKEN-REF", "unresolved `@ref $target`"))
    end

    if !isempty(violations)
        println(stderr, "lint_docs: $(length(violations)) violation(s):")
        for v in violations
            println(stderr, "  $(v.file):$(v.line) [$(v.rule)] $(v.msg)")
        end
        exit(1)
    end
    println("lint_docs: OK ($(length(actual_files)) docs/src pages + src/commands/agent_guide.md, $(length(all_ids)) @id anchors, $(length(refs_used)) @ref links)")
end

main()
