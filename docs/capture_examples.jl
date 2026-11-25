#!/usr/bin/env julia
# Capture / verify bash example blocks tagged <!-- capture --> in docs.
#
# Usage:
#   julia --project docs/capture_examples.jl                  # refresh all captures
#   julia --project docs/capture_examples.jl --check          # fail if any capture is stale
#   julia --project docs/capture_examples.jl path/to/doc.md   # refresh specific file(s)
#
# Supported bash-fence features (executed in-process inside a per-file mktempdir):
#   - `frdc ...` commands (multi-line blocks execute top-to-bottom; stdout of the
#     FINAL `frdc` invocation is captured)
#   - trailing `\` line continuations and `#` comments
#   - heredoc fixtures: `cat > file <<'EOF' ... EOF` (or `<<EOF`)
#
# Formats:
#   - `--format json` → `json` fence (volatile meta stripped; rows kept single-line)
#   - `--format csv`  → `csv` fence
#   - default/table   → `text` fence

using Dates
using JSON3
using Friedman

const ROOT = dirname(@__DIR__)
const CHECK = "--check" in ARGS
const TARGET_PATHS = filter(a -> !startswith(a, "-"), ARGS)
const FLOAT_SIGDIGITS = 8
const COMPARE_RTOL = 1e-4
const COMPARE_ATOL = 1e-8
const TABLE_RTOL = 2e-3
const TABLE_ATOL = 2e-4

# ── Normalization & formatting ────────────────────────────────

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
        return Int(x)
    elseif x isa AbstractFloat
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
        for k in ("elapsed_ms", "argv", "julia", "cli_version", "mems_version", "seed",
                  "manifest")
            delete!(meta, k)
        end
        d["meta"] = _sort_keys(meta)
    end
    return d
end

_is_scalar_json(v) = v === nothing || v isa Bool || v isa Number || v isa AbstractString

function _write_compact_json(io::IO, val, indent::Int=0; compact_arrays::Bool=false)
    if val isa AbstractDict
        ks = sort!(collect(String.(keys(val))))
        if isempty(ks)
            print(io, "{}")
            return
        end
        println(io, "{")
        for (idx, k) in enumerate(ks)
            print(io, " " ^ (indent + 2))
            JSON3.write(io, k)
            print(io, ": ")
            _write_compact_json(io, val[k], indent + 2; compact_arrays=(k == "rows" || compact_arrays))
            idx < length(ks) && print(io, ",")
            println(io)
        end
        print(io, " " ^ indent, "}")
    elseif val isa AbstractVector
        if isempty(val)
            print(io, "[]")
            return
        end
        if all(_is_scalar_json, val)
            print(io, "[")
            for (idx, x) in enumerate(val)
                JSON3.write(io, x)
                idx < length(val) && print(io, ", ")
            end
            print(io, "]")
            return
        end
        println(io, "[")
        for (idx, x) in enumerate(val)
            print(io, " " ^ (indent + 2))
            _write_compact_json(io, x, indent + 2; compact_arrays=compact_arrays)
            idx < length(val) && print(io, ",")
            println(io)
        end
        print(io, " " ^ indent, "]")
    else
        JSON3.write(io, val)
    end
end

function _format_capture(raw::AbstractString, lang_hint::String)::Tuple{String,String}
    s = strip(replace(String(raw), "\r\n" => "\n"))
    isempty(s) && return ("", lang_hint)
    if startswith(s, "{") || startswith(s, "[")
        try
            d = _json_to_dict(JSON3.read(s))
            d isa AbstractDict && _strip_volatile_meta!(d)
            d = _canon_value(d)
            formatted = sprint(io -> _write_compact_json(io, d))
            return (formatted, "json")
        catch
        end
    end
    cleaned = join(rstrip.(split(replace(String(raw), "\r\n" => "\n"), '\n')), "\n")
    return (rstrip(cleaned), lang_hint)
end

function _normalize_table_text(s::AbstractString)::String
    lines = rstrip.(split(replace(String(s), "\r\n" => "\n"), '\n'))
    while !isempty(lines) && isempty(lines[end])
        pop!(lines)
    end
    return join(lines, "\n")
end

# ── Float-tolerant comparison ─────────────────────────────────

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

const _TOKEN_RE = r"(?<![A-Za-z_])[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?(?![A-Za-z_])|[^,\s]+|,"

function _line_tokens(line::AbstractString)::Vector{String}
    return String[m.match for m in eachmatch(_TOKEN_RE, line)]
end

_is_border_line(s::AbstractString) = !isempty(strip(s)) && occursin(r"^[┌├└─┬┼┴┐┤┘\s]+$", s)
_is_cropped_border(s::AbstractString) = _is_border_line(s) && !endswith(strip(s), ('┐', '┤', '┘'))
_norm_border_line(s::AbstractString) = replace(strip(s), r"─+" => "─")
const _OMITTED_COLS_RE = r"^\s*(\d+)\s+columns?\s+omitted\s*$"

function _complete_cells(line::AbstractString)::Vector{String}
    s = strip(line)
    parts = collect(split(s, '│'))
    !isempty(parts) && isempty(strip(first(parts))) && popfirst!(parts)
    !isempty(parts) && (endswith(s, '│') || endswith(s, "⋯")) && pop!(parts)
    return String[String(p) for p in parts]
end

function _compare_tokens(ta::Vector{String}, tg::Vector{String}, idx::Int,
                         ra::AbstractString, rg::AbstractString)
    length(ta) == length(tg) || return "line $idx token count $(length(ta)) vs $(length(tg))\n      actual: $ra\n      golden: $rg"
    for (xa, xg) in zip(ta, tg)
        xa == xg && continue
        fa = tryparse(Float64, xa)
        fg = tryparse(Float64, xg)
        if fa !== nothing && fg !== nothing && isfinite(fa) && isfinite(fg)
            isapprox(fa, fg; rtol=TABLE_RTOL, atol=TABLE_ATOL) && continue
            (abs(fa) >= 1e12 && abs(fg) >= 1e12 && sign(fa) == sign(fg)) && continue
        end
        return "line $idx: '$xa' vs '$xg'\n      actual: $ra\n      golden: $rg"
    end
    return nothing
end

function _compare_text_tables(actual::AbstractString, golden::AbstractString)
    la = split(_normalize_table_text(actual), '\n')
    lg = split(_normalize_table_text(golden), '\n')
    length(la) == length(lg) || return "line count $(length(la)) vs $(length(lg))"
    for (idx, (ra, rg)) in enumerate(zip(la, lg))
        if _is_border_line(ra) && _is_border_line(rg)
            na = _norm_border_line(ra)
            ng = _norm_border_line(rg)
            na == ng && continue
            if _is_cropped_border(ra) || _is_cropped_border(rg)
                ba = rstrip(na, '─')
                bg = rstrip(ng, '─')
                if !isempty(ba) && !isempty(bg) && (startswith(ba, bg) || startswith(bg, ba)) &&
                   abs(length(ba) - length(bg)) <= 4
                    continue
                end
            end
            return "line $idx border structure mismatch\n      actual: $ra\n      golden: $rg"
        end
        ma = match(_OMITTED_COLS_RE, ra)
        mg = match(_OMITTED_COLS_RE, rg)
        if ma !== nothing && mg !== nothing
            abs(parse(Int, ma.captures[1]) - parse(Int, mg.captures[1])) <= 1 && continue
            return "line $idx omitted columns $(ma.captures[1]) vs $(mg.captures[1])"
        end
        if endswith(strip(ra), "⋯") || endswith(strip(rg), "⋯")
            ca = _complete_cells(ra)
            cg = _complete_cells(rg)
            if isempty(ca) || isempty(cg) || abs(length(ca) - length(cg)) > 1
                return "line $idx cropped-cell count $(length(ca)) vs $(length(cg))\n      actual: $ra\n      golden: $rg"
            end
            for c in 1:min(length(ca), length(cg))
                err = _compare_tokens(_line_tokens(ca[c]), _line_tokens(cg[c]), idx, ra, rg)
                err === nothing || return err
            end
            continue
        end
        err = _compare_tokens(_line_tokens(ra), _line_tokens(rg), idx, ra, rg)
        err === nothing || return err
    end
    return nothing
end

"""Why a capture is stale, or `nothing` if it is current."""
function _capture_mismatch(actual::AbstractString, golden::AbstractString)
    a = strip(replace(String(actual), "\r\n" => "\n"))
    g = strip(replace(String(golden), "\r\n" => "\n"))
    if (startswith(a, "{") || startswith(a, "[")) && (startswith(g, "{") || startswith(g, "["))
        try
            return _first_difference(JSON3.read(a), JSON3.read(g))
        catch
        end
    end
    return _compare_text_tables(a, g)
end

# ── In-process bash-block runner ──────────────────────────────

function _run_cli_inprocess(argv::Vector{String}, label::AbstractString)::String
    out_path = tempname()
    err_path = tempname()
    code = Cint(1)
    try
        code = open(out_path, "w") do out_io
            open(err_path, "w") do err_io
                redirect_stdout(out_io) do
                    redirect_stderr(err_io) do
                        withenv("NO_COLOR" => "1") do
                            return Friedman.run_cli(argv)
                        end
                    end
                end
            end
        end
        out = read(out_path, String)
        err = read(err_path, String)
        code == 0 || error("capture command failed (exit $code): frdc $(join(argv, ' '))\n$err")
        return out
    finally
        rm(out_path; force=true)
        rm(err_path; force=true)
    end
end

function _infer_lang(argv::Vector{String})::String
    for i in eachindex(argv)
        a = argv[i]
        a == "--format=csv" && return "csv"
        a == "--format=json" && return "json"
        if (a == "--format" || a == "-f") && i < length(argv)
            v = argv[i+1]
            v == "csv" && return "csv"
            v == "json" && return "json"
        end
    end
    return "text"
end

function _run_capture(bash_body::AbstractString)::Tuple{String,String}
    raw_lines = split(replace(String(bash_body), "\r\n" => "\n"), '\n')
    # Join trailing backslash continuations (outside heredocs)
    lines = String[]
    buf = ""
    i = 1
    while i <= length(raw_lines)
        line = String(raw_lines[i])
        stripped = strip(line)
        if !isempty(buf)
            if endswith(rstrip(line), "\\")
                buf *= " " * strip(rstrip(line)[1:prevind(rstrip(line), lastindex(rstrip(line)))])
            else
                push!(lines, strip(buf * " " * strip(line)))
                buf = ""
            end
            i += 1
            continue
        end
        # Heredocs stay verbatim
        if occursin(r"^cat\s*>\s*\S+\s*<<", stripped)
            push!(lines, line)
            i += 1
            continue
        end
        if endswith(rstrip(line), "\\")
            r = rstrip(line)
            buf = String(r[1:prevind(r, lastindex(r))])
            i += 1
            continue
        end
        push!(lines, line)
        i += 1
    end
    isempty(strip(buf)) || push!(lines, strip(buf))

    last_out = ""
    last_lang = "text"
    idx = 1
    ran_any = false
    while idx <= length(lines)
        raw = lines[idx]
        s = strip(raw)
        if isempty(s) || startswith(s, "#")
            idx += 1
            continue
        end
        m = match(r"^cat\s*>\s*(\S+)\s*<<\s*(['\"]?)([A-Za-z0-9_]+)\2\s*$", s)
        if m !== nothing
            fname = String(m.captures[1])
            delim = String(m.captures[3])
            idx += 1
            body = String[]
            while idx <= length(lines) && strip(lines[idx]) != delim
                push!(body, lines[idx])
                idx += 1
            end
            idx <= length(lines) || error("unterminated heredoc '$delim' for $fname")
            idx += 1
            mkpath(dirname(abspath(fname)))
            write(fname, join(body, "\n") * "\n")
            continue
        end
        if startswith(s, "rm ") || startswith(s, "mkdir ")
            parts = Base.shell_split(s)
            if parts[1] == "mkdir"
                for p in parts[2:end]
                    startswith(p, "-") || mkpath(p)
                end
            elseif parts[1] == "rm"
                for p in parts[2:end]
                    startswith(p, "-") || rm(p; force=true, recursive=true)
                end
            end
            idx += 1
            continue
        end
        tokens = String.(Base.shell_split(s))
        isempty(tokens) && (idx += 1; continue)
        tokens[1] == "frdc" || error("capture runner expects `frdc ...` or `cat > file <<'EOF'`, got: $s")
        argv = tokens[2:end]
        last_lang = _infer_lang(argv)
        last_out = _run_cli_inprocess(argv, s)
        ran_any = true
        idx += 1
    end
    ran_any || error("no `frdc` invocation found in <!-- capture --> block")
    return (last_out, last_lang)
end

# ── Markdown parse / rewrite ───────────────────────────────────

struct CaptureBlock
    bash::String
    output::String
    lang::String
    start_idx::Int
    end_idx::Int
end

const _CAPTURE_RE = r"<!--\s*capture\s*-->\s*```bash\n(.*?)```\s*```(\w*)\n(.*?)```"s

function _find_captures(text::String)::Vector{CaptureBlock}
    blocks = CaptureBlock[]
    for m in eachmatch(_CAPTURE_RE, text)
        push!(blocks, CaptureBlock(
            String(m.captures[1]),
            String(m.captures[3]),
            String(m.captures[2]),
            m.offset,
            m.offset + ncodeunits(m.match),
        ))
    end
    return blocks
end

function _rewrite_page(text::String, results::Vector{Tuple{CaptureBlock,String,String}})::String
    out = IOBuffer()
    pos = 1
    for (block, new_output, lang) in results
        block.start_idx > pos && write(out, text[pos:prevind(text, block.start_idx)])
        unit = string(
            "<!-- capture -->\n",
            "```bash\n", block.bash, "```\n",
            "```", lang, "\n", rstrip(new_output), "\n```",
        )
        write(out, unit)
        pos = block.end_idx
    end
    write(out, text[pos:end])
    return String(take!(out))
end

# ── Main ──────────────────────────────────────────────────────

function _collect_files()::Vector{String}
    if !isempty(TARGET_PATHS)
        return sort!(unique!(abspath.(TARGET_PATHS)))
    end
    src = joinpath(ROOT, "docs", "src")
    gen_dir = joinpath(src, "commands", "generated")
    files = String[]
    for (root, _, names) in walkdir(src)
        startswith(root, gen_dir) && continue
        for n in names
            endswith(n, ".md") || continue
            p = joinpath(root, n)
            p == joinpath(src, "agent-guide.md") && continue
            push!(files, p)
        end
    end
    return sort!(files)
end

function main()
    files = _collect_files()
    n_blocks = 0
    n_refreshed = 0
    failures = String[]

    for f in files
        isfile(f) || error("file not found: $f")
        text = read(f, String)
        blocks = _find_captures(text)
        isempty(blocks) && continue
        n_blocks += length(blocks)
        rel = relpath(f, ROOT)
        results = Tuple{CaptureBlock,String,String}[]
        page_changed = false

        mktempdir() do tmpdir
            cd(tmpdir) do
                for (bidx, block) in enumerate(blocks)
                    try
                        fresh_raw, lang_hint = _run_capture(block.bash)
                        fresh, lang = _format_capture(fresh_raw, lang_hint)
                        if CHECK
                            why = _capture_mismatch(fresh, block.output)
                            if why !== nothing
                                push!(failures, "$rel [#$bidx]: stale capture\n      $why")
                            elseif lang != block.lang
                                push!(failures, "$rel [#$bidx]: fence language '$(block.lang)' != '$lang'")
                            end
                        else
                            if _capture_mismatch(fresh, block.output) !== nothing ||
                               strip(replace(block.output, "\r\n" => "\n")) != strip(fresh) ||
                               lang != block.lang
                                page_changed = true
                                n_refreshed += 1
                            end
                            push!(results, (block, fresh, lang))
                        end
                    catch e
                        push!(failures, "$rel [#$bidx]: $(sprint(showerror, e))")
                        push!(results, (block, block.output, block.lang))
                    end
                end
            end
        end

        if !CHECK && page_changed
            write(f, _rewrite_page(text, results))
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
