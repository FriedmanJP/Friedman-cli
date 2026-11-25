#!/usr/bin/env julia
# Generate CLI reference docs, completions, and inventory from the registry.
#
# Usage:
#   julia --project docs/generate_cli_reference.jl              # write artifacts
#   julia --project docs/generate_cli_reference.jl --check      # fail if stale
#   julia --project docs/generate_cli_reference.jl --claude-md  # also patch CLAUDE.md if present

using Friedman
using Dates

const ROOT = dirname(@__DIR__)
const CHECK = "--check" in ARGS
const DO_CLAUDE = "--claude-md" in ARGS || !CHECK

# ── Collect specs ──────────────────────────────────────────────

function _all_specs()::Vector{Friedman.CommandSpec}
    specs = copy(Friedman.REGISTRY)
    if isempty(specs)
        error("REGISTRY is empty — was build_app() run?")
    end
    seen = Set{Vector{String}}()
    out = Friedman.CommandSpec[]
    for s in specs
        s.path in seen && continue
        push!(seen, s.path)
        push!(out, s)
    end
    return out
end

function _group_by_top(specs::Vector{Friedman.CommandSpec})
    groups = Dict{String,Vector{Friedman.CommandSpec}}()
    for s in specs
        isempty(s.path) && continue
        top = s.path[1]
        push!(get!(groups, top, Friedman.CommandSpec[]), s)
    end
    return groups
end

_fmt_default(d) = isnothing(d) ? "—" : (d isa String && isempty(d) ? "`\"\"`" : "`$(d)`")
_fmt_choices(c) = isnothing(c) ? "—" : join("`" .* c .* "`", ", ")
_type_name(t::Type) = t === Nothing ? "Any" : string(t)

"""
    _md_cell(s) -> String

Escape a value destined for a markdown table cell so literal `|` tokens
(e.g. `table|csv|json`) do not split columns.
"""
_md_cell(s) = replace(string(s), "|" => "\\|")

# ── Bidirectional workflow guide mapping ──────────────────────

const _CHAPTER_REF_LABELS = Dict{String,String}(
    "gs-installation" => "[Installation & Quickstart](@ref gs-installation)",
    "gs-pipelines"    => "[Pipelines, Handles & Reproducibility](@ref gs-pipelines)",
    "agent-guide"     => "[Agent Guide](../../agent-guide.md)",
    "chap-data"       => "[Data Management & Simulation](@ref chap-data)",
    "chap-univariate" => "[Univariate, Filters & Spectral](@ref chap-univariate)",
    "chap-volatility" => "[Volatility & Multivariate GARCH](@ref chap-volatility)",
    "chap-nonlinear"  => "[Regime-Switching & Nonlinear TS](@ref chap-nonlinear)",
    "chap-multivariate" => "[VAR, BVAR, VECM & Factor Models](@ref chap-multivariate)",
    "chap-structural" => "[Structural ID, LP & Innovation Accounting](@ref chap-structural)",
    "chap-nowcast"    => "[Nowcasting & Forecast Evaluation](@ref chap-nowcast)",
    "chap-regression" => "[Regression, Systems & GMM/SMM](@ref chap-regression)",
    "chap-choice"     => "[Discrete Choice, Count & Selection](@ref chap-choice)",
    "chap-panel"      => "[Panel Data, Panel VAR & Causal DiD](@ref chap-panel)",
    "chap-dsge"       => "[Representative-Agent & Bayesian DSGE](@ref chap-dsge)",
    "chap-hadsge"     => "[Heterogeneous-Agent, CT & OLG Models](@ref chap-hadsge)",
    "chap-policy"     => "[Policy Counterfactuals & Optimal Policy](@ref chap-policy)",
    "chap-ri"         => "[Rational Inattention](@ref chap-ri)",
    "chap-io"         => "[Input-Output & Production Networks](@ref chap-io)",
    "chap-tests"      => "[Hypothesis Testing & Diagnostics](@ref chap-tests)",
)

const _TOP_GUIDES = Dict{String,Vector{String}}(
    "completions" => ["gs-installation"],
    "data"        => ["chap-data"],
    "did"         => ["chap-panel"],
    "dsge"        => ["chap-dsge", "chap-hadsge"],
    "estimate"    => ["chap-univariate", "chap-volatility", "chap-nonlinear", "chap-multivariate",
                      "chap-structural", "chap-regression", "chap-choice", "chap-panel", "chap-ri"],
    "fevd"        => ["chap-structural", "chap-dsge", "chap-panel"],
    "filter"      => ["chap-univariate", "chap-nowcast"],
    "forecast"    => ["chap-univariate", "chap-volatility", "chap-nonlinear", "chap-multivariate", "chap-nowcast"],
    "hadsge"      => ["chap-hadsge"],
    "hd"          => ["chap-structural", "chap-dsge"],
    "io"          => ["chap-io"],
    "irf"         => ["chap-structural", "chap-panel"],
    "model"       => ["gs-pipelines"],
    "nowcast"     => ["chap-nowcast"],
    "policy"      => ["chap-policy"],
    "predict"     => ["chap-univariate", "chap-volatility", "chap-nonlinear", "chap-multivariate",
                      "chap-regression", "chap-choice", "chap-panel", "chap-ri"],
    "residuals"   => ["chap-univariate", "chap-volatility", "chap-nonlinear", "chap-multivariate",
                      "chap-regression", "chap-choice", "chap-panel"],
    "ri"          => ["chap-ri"],
    "serve"       => ["agent-guide"],
    "show"        => ["gs-pipelines"],
    "spectral"    => ["chap-univariate", "chap-structural"],
    "test"        => ["chap-tests", "chap-regression", "chap-panel", "chap-univariate", "chap-multivariate"],
)

const _FAMILY_GUIDES = Dict{Tuple{String,String},Vector{String}}(
    ("dsge", "ra")            => ["chap-dsge"],
    ("dsge", "abcd")          => ["chap-dsge"],
    ("dsge", "var")           => ["chap-dsge"],
    ("dsge", "ct")            => ["chap-hadsge"],
    ("dsge", "olg")           => ["chap-hadsge"],
    ("dsge", "dcegm")         => ["chap-hadsge"],
    ("dsge", "lifecycle")     => ["chap-hadsge"],
    ("dsge", "firm")          => ["chap-hadsge"],
    ("dsge", "bank")          => ["chap-hadsge"],
    ("estimate", "choice")       => ["chap-choice", "chap-ri"],
    ("estimate", "factor")       => ["chap-multivariate", "chap-structural"],
    ("estimate", "multivariate") => ["chap-multivariate", "chap-structural"],
    ("estimate", "panel")        => ["chap-panel"],
    ("estimate", "regime")       => ["chap-nonlinear", "chap-univariate"],
    ("estimate", "regression")   => ["chap-regression", "chap-choice", "chap-univariate", "chap-structural"],
    ("estimate", "univariate")   => ["chap-univariate"],
    ("estimate", "volatility")   => ["chap-volatility"],
    ("forecast", "evaluate")     => ["chap-nowcast"],
    ("forecast", "factor")       => ["chap-multivariate"],
    ("forecast", "multivariate") => ["chap-multivariate"],
    ("forecast", "regime")       => ["chap-nonlinear"],
    ("forecast", "univariate")   => ["chap-univariate"],
    ("forecast", "volatility")   => ["chap-volatility"],
    ("predict", "choice")        => ["chap-choice", "chap-ri"],
    ("predict", "factor")        => ["chap-multivariate"],
    ("predict", "multivariate")  => ["chap-multivariate"],
    ("predict", "panel")         => ["chap-panel"],
    ("predict", "regime")        => ["chap-nonlinear"],
    ("predict", "regression")    => ["chap-regression", "chap-univariate"],
    ("predict", "univariate")    => ["chap-univariate"],
    ("predict", "volatility")    => ["chap-volatility"],
    ("residuals", "choice")      => ["chap-choice"],
    ("residuals", "factor")      => ["chap-multivariate"],
    ("residuals", "multivariate") => ["chap-multivariate"],
    ("residuals", "panel")       => ["chap-panel"],
    ("residuals", "regime")      => ["chap-nonlinear"],
    ("residuals", "regression")  => ["chap-regression", "chap-univariate"],
    ("residuals", "univariate")  => ["chap-univariate"],
    ("residuals", "volatility")  => ["chap-volatility"],
    ("test", "coint")         => ["chap-tests", "chap-multivariate", "chap-panel", "chap-univariate"],
    ("test", "did")           => ["chap-tests", "chap-panel"],
    ("test", "factor")        => ["chap-tests", "chap-multivariate", "chap-structural"],
    ("test", "iv")            => ["chap-tests", "chap-regression"],
    ("test", "multivariate")  => ["chap-tests", "chap-multivariate", "chap-structural"],
    ("test", "panel")         => ["chap-tests", "chap-panel"],
    ("test", "pvar")          => ["chap-tests", "chap-panel"],
    ("test", "serial")        => ["chap-tests", "chap-volatility"],
    ("test", "stability")     => ["chap-tests"],
    ("test", "unit-root")     => ["chap-tests"],
    ("test", "vecm")          => ["chap-tests", "chap-multivariate"],
    ("test", "other")         => ["chap-tests", "chap-choice", "chap-univariate", "chap-nonlinear"],
)

const _FAMILY_TITLES = Dict{String,String}(
    "commands"     => "Commands",
    "ra"           => "Representative-Agent & Bayesian DSGE",
    "abcd"         => "Canonical ABCD State-Space & Invertibility (`dsge abcd`)",
    "var"          => "Bayesian DSGE-VAR (`dsge var`)",
    "ct"           => "Continuous-Time HA-DSGE (`dsge ct`)",
    "olg"          => "Blanchard Perpetual-Youth OLG (`dsge olg`)",
    "dcegm"        => "Discrete-Continuous EGM (`dsge dcegm`)",
    "lifecycle"    => "Overlapping-Generations Life-Cycle (`dsge lifecycle`)",
    "firm"         => "Heterogeneous-Firm Dynamics (`dsge firm`)",
    "bank"         => "Intermediary Banking (`dsge bank`)",
    "ri"           => "Rational Inattention (`ri`)",
    "bf"           => "Baqaee–Farhi Production Networks (`io bf`)",
    "factor"       => "Factor & Quantile-Factor Diagnostics",
    "iv"           => "Instrumental-Variable Diagnostics",
    "did"          => "Difference-in-Differences Diagnostics",
    "pvar"         => "Panel VAR Diagnostics",
    "coint"        => "Cointegration Tests",
    "unit-root"    => "Unit Root Tests",
    "opp-sequence" => "Optimal Policy Perturbation Sequences (`opp-sequence`)",
    "other"        => "Other Diagnostics",
)

function _family_title(fam::String)::String
    haskey(_FAMILY_TITLES, fam) && return _FAMILY_TITLES[fam]
    words = split(replace(fam, "-" => " "))
    return join(uppercasefirst.(words), " ")
end

function _leaf_family(spec::Friedman.CommandSpec)::String
    !isempty(spec.family) && return spec.family
    length(spec.path) >= 3 && return spec.path[2]
    return "commands"
end

function _anchor_slug(s::AbstractString)::String
    return String(strip(replace(lowercase(replace(String(s), r"[^A-Za-z0-9-]+" => "-")), r"--+" => "-"), '-'))
end

function _fmt_guide_links(keys::Vector{String})::String
    isempty(keys) && return ""
    return join([_CHAPTER_REF_LABELS[k] for k in keys if haskey(_CHAPTER_REF_LABELS, k)], " · ")
end

# ── Markdown emitters ─────────────────────────────────────────

function _leaf_md(spec::Friedman.CommandSpec)::String
    io = IOBuffer()
    path = join(spec.path, " ")
    slug = _anchor_slug(join(spec.path, "-"))
    leaf_id = length(spec.path) == 1 ? "ref-leaf-$slug" : "ref-$slug"
    println(io, "### [`frdc $path`](@id $leaf_id)")
    println(io)
    println(io, spec.summary)
    println(io)
    if !isempty(spec.args)
        println(io, "| Argument | Type | Required | Default | Description |")
        println(io, "|----------|------|----------|---------|-------------|")
        for a in spec.args
            req = a.required ? "yes" : "no"
            println(io, "| `$(a.name)` | `$(_type_name(a.type))` | $req | $(_fmt_default(a.default)) | $(_md_cell(a.description)) |")
        end
        println(io)
    end
    if !isempty(spec.options)
        println(io, "| Option | Short | Type | Default | Choices | Description |")
        println(io, "|--------|-------|------|---------|---------|-------------|")
        for o in spec.options
            short = isempty(o.short) ? "—" : "`-$(o.short)`"
            typ = "`$(_type_name(o.type))`" * (o.repeatable ? " *(repeatable)*" : "")
            choices = _md_cell(_fmt_choices(o.choices))
            println(io, "| `--$(o.name)` | $short | $typ | $(_fmt_default(o.default)) | $choices | $(_md_cell(o.description)) |")
        end
        println(io)
    end
    if !isempty(spec.flags)
        println(io, "| Flag | Short | Description |")
        println(io, "|------|-------|-------------|")
        for f in spec.flags
            short = isempty(f.short) ? "—" : "`-$(f.short)`"
            println(io, "| `--$(f.name)` | $short | $(_md_cell(f.description)) |")
        end
        println(io)
    end
    handle_parts = String[]
    isempty(spec.data_kinds)   || push!(handle_parts, "data kinds: " * join(["`:$(k)`" for k in spec.data_kinds], ", "))
    isempty(spec.model_types)  || push!(handle_parts, "model types: " * join(["`$(m)`" for m in spec.model_types], ", "))
    isempty(spec.result_types) || push!(handle_parts, "result types: " * join(["`$(r)`" for r in spec.result_types], ", "))
    if !isempty(handle_parts)
        println(io, "**Handles:** ", join(handle_parts, "; "))
        println(io)
    end
    if !isempty(spec.tables)
        println(io, "**Output tables:** ",
                join(["`$(t.name)$(t.family ? "_*" : "")` ($(t.description))" for t in spec.tables], "; "))
        println(io)
    end
    return String(take!(io))
end

function _top_page(top::String, leaves::Vector{Friedman.CommandSpec})::String
    io = IOBuffer()
    top_slug = _anchor_slug(top)
    println(io, "<!-- GENERATED by docs/generate_cli_reference.jl — do not hand-edit -->")
    println(io, "# [`$top`](@id ref-$top_slug)")
    println(io)
    println(io, "Generated command reference for `frdc $top` (`$(length(leaves))` $(length(leaves) == 1 ? "leaf" : "leaves")). Back to [CLI Reference Overview](@ref cli-overview).")
    top_guides = _fmt_guide_links(get(_TOP_GUIDES, top, String[]))
    if !isempty(top_guides)
        println(io)
        println(io, "**Workflow guides:** ", top_guides)
    end
    println(io)

    by_fam = Dict{String,Vector{Friedman.CommandSpec}}()
    for s in leaves
        push!(get!(by_fam, _leaf_family(s), Friedman.CommandSpec[]), s)
    end
    fams = sort(collect(keys(by_fam)); by=f -> begin
        f == "commands" && return (0, f)
        f == top        && return (1, f)
        f == "other"    && return (3, f)
        return (2, f)
    end)

    for fam in fams
        fam_slug = _anchor_slug("$(top)-$(fam)")
        println(io, "---")
        println(io)
        println(io, "## [$(_family_title(fam))](@id ref-fam-$fam_slug)")
        println(io)
        desc = get(Friedman._NODE_DESCRIPTIONS, (top, fam), "")
        isempty(desc) || (println(io, desc); println(io))
        fam_guides = _fmt_guide_links(get(_FAMILY_GUIDES, (top, fam), get(_TOP_GUIDES, top, String[])))
        isempty(fam_guides) || (println(io, "**See guide:** ", fam_guides); println(io))
        for spec in sort(by_fam[fam]; by=s -> join(s.path, " "))
            print(io, _leaf_md(spec))
        end
    end
    return String(take!(io))
end

function _tree_text(specs::Vector{Friedman.CommandSpec})::String
    groups = _group_by_top(specs)
    tops = sort(collect(keys(groups)))
    io = IOBuffer()
    println(io, "frdc")
    for (i, top) in enumerate(tops)
        leaves = groups[top]
        names = String[]
        for s in leaves
            if length(s.path) == 2
                push!(names, s.path[2])
            elseif length(s.path) >= 3
                push!(names, join(s.path[2:end], " "))
            end
        end
        unique!(names)
        sort!(names)
        branch = i == length(tops) ? "└──" : "├──"
        line = "$branch $top"
        if !isempty(names)
            line *= "     " * join(names, " | ")
        end
        println(io, line)
    end
    n_leaves = length(specs)
    n_tops = length(tops)
    println(io)
    println(io, "Total: $n_tops top-level commands, $n_leaves leaves (from registry).")
    return String(take!(io))
end

function _overview_md(specs::Vector{Friedman.CommandSpec})::String
    io = IOBuffer()
    println(io, "# [CLI Reference Overview](@id cli-overview)")
    println(io)
    println(io, "Friedman-cli uses an **action-first** command hierarchy (`verb [family] model`). For pipeline-oriented walkthroughs organized by econometric domain, start from the domain chapters in the sidebar or [Choosing a Method](@ref gs-method-guide).")
    println(io)
    println(io, "<!-- BEGIN GENERATED: do not hand-edit; run julia --project docs/generate_cli_reference.jl -->")
    println(io)
    println(io, "## Command Tree")
    println(io)
    println(io, "```text")
    print(io, _tree_text(specs))
    println(io, "```")
    println(io)
    println(io, "Additionally, `frdc repl` launches an interactive REPL session ([Interactive REPL](@ref gs-repl)).")
    println(io)
    println(io, "---")
    println(io)
    println(io, "## Generated Reference Pages")
    println(io)
    groups = _group_by_top(specs)
    for top in sort(collect(keys(groups)))
        top_slug = _anchor_slug(top)
        println(io, "- [`$top`](@ref ref-$top_slug) — $(length(groups[top])) leaves")
    end
    println(io)
    println(io, "<!-- END GENERATED -->")
    println(io)
    println(io, "---")
    println(io)
    println(io, "## Common Options & Globals")
    println(io)
    println(io, "Every leaf that produces tabular output supports `--format`/`-f` (`table`|`csv`|`json`) and `--output`/`-o` (`<path>` to write to a file instead of stdout). Leaves accepting structured specifications add `--config <path>` (see [Model Cards & Config Grammar](@ref cfg-overview)); plot-capable leaves add `--plot` and `--plot-save <path>`.")
    println(io)
    println(io, "Leading agent globals go **before** the command: `--seed N`, `--quiet`/`-q`, `--json`, and `--no-color`. See [Pipelines, Handles & Reproducibility](@ref gs-pipelines) and the [Agent Guide](../agent-guide.md) for the complete JSON envelope and typed handle contract.")
    println(io)
    println(io, "---")
    println(io)
    println(io, "## Help & Machine Schema")
    println(io)
    println(io, "Every node and leaf accepts `--help` (`-h`). Machine-readable draft-07 input schemas and declared table keys come from `frdc schema`:")
    println(io)
    println(io, "```bash")
    println(io, "frdc schema estimate multivariate var")
    println(io, "```")
    return String(take!(io))
end

function _claude_block(specs::Vector{Friedman.CommandSpec})::String
    io = IOBuffer()
    println(io, "<!-- BEGIN GENERATED: do not hand-edit; run julia --project docs/generate_cli_reference.jl --claude-md -->")
    println(io, "Generated: $(Dates.now()) UTC")
    println(io)
    println(io, "### Registry inventory")
    println(io)
    println(io, "- Leaves: **$(length(specs))**")
    groups = _group_by_top(specs)
    println(io, "- Top-level: **$(length(groups))** — ", join(sort(collect(keys(groups))), ", "))
    println(io)
    println(io, "### Command tree")
    println(io)
    println(io, "```")
    print(io, _tree_text(specs))
    println(io, "```")
    println(io, "<!-- END GENERATED -->")
    return String(take!(io))
end

# ── Shell completions ─────────────────────────────────────────

_bash_completion(specs::Vector{Friedman.CommandSpec})::String =
    Friedman.generate_bash_completion(Friedman.APP)

_zsh_completion(specs::Vector{Friedman.CommandSpec})::String =
    Friedman.generate_zsh_completion(Friedman.APP)

_fish_completion(specs::Vector{Friedman.CommandSpec})::String =
    Friedman.generate_fish_completion(Friedman.APP)

# ── Write / check ─────────────────────────────────────────────

function _write_or_check(path::String, content::String; check::Bool)
    mkpath(dirname(path))
    if check
        if !isfile(path)
            @error "missing generated file" path
            return false
        end
        old = read(path, String)
        if replace(old, "\r\n" => "\n") != replace(content, "\r\n" => "\n")
            @error "stale generated file" path
            return false
        end
        return true
    else
        open(path, "w") do io
            write(io, content)
        end
        println("wrote $path")
        return true
    end
end

function _patch_claude_md(block::String; check::Bool)
    path = joinpath(ROOT, "CLAUDE.md")
    isfile(path) || return true  # gitignored / absent in CI — skip
    text = read(path, String)
    begin_m = "<!-- BEGIN GENERATED"
    end_m = "<!-- END GENERATED -->"
    bi = findfirst(begin_m, text)
    ei = findfirst(end_m, text)
    if isnothing(bi) || isnothing(ei)
        new_text = text * "\n\n## Generated Inventory\n\n" * block * "\n"
    else
        start_i = first(bi)
        end_i = last(ei)
        new_text = text[1:start_i-1] * block * text[end_i+1:end]
    end
    if check
        return replace(text, "\r\n" => "\n") == replace(new_text, "\r\n" => "\n")
    end
    open(path, "w") do io
        write(io, new_text)
    end
    println("updated $path generated block")
    return true
end

function main()
    specs = _all_specs()
    @info "registry leaves" count=length(specs)
    ok = true

    overview_path = joinpath(ROOT, "docs", "src", "commands", "overview.md")
    ok &= _write_or_check(overview_path, _overview_md(specs); check=CHECK)

    gen_dir = joinpath(ROOT, "docs", "src", "commands", "generated")
    groups = _group_by_top(specs)
    for top in sort(collect(keys(groups)))
        path = joinpath(gen_dir, "$top.md")
        ok &= _write_or_check(path, _top_page(top, groups[top]); check=CHECK)
    end

    expected = Set("$top.md" for top in keys(groups))
    for fname in sort(readdir(gen_dir))
        endswith(fname, ".md") || continue
        fname in expected && continue
        stale = joinpath(gen_dir, fname)
        if CHECK
            println(stderr, "generate_cli_reference: stale page $stale (no such top-level)")
            ok = false
        else
            rm(stale)
            println("pruned $stale")
        end
    end

    comp_dir = joinpath(ROOT, "completions")
    ok &= _write_or_check(joinpath(comp_dir, "frdc.bash"), _bash_completion(specs); check=CHECK)
    ok &= _write_or_check(joinpath(comp_dir, "frdc.zsh"), _zsh_completion(specs); check=CHECK)
    ok &= _write_or_check(joinpath(comp_dir, "_frdc.fish"), _fish_completion(specs); check=CHECK)

    if DO_CLAUDE
        ok &= _patch_claude_md(_claude_block(specs); check=CHECK)
    end

    if CHECK
        if ok
            println("generate_cli_reference: OK (up to date)")
            exit(0)
        else
            println(stderr, "generate_cli_reference: STALE — run: julia --project docs/generate_cli_reference.jl")
            exit(1)
        end
    end
end

main()
