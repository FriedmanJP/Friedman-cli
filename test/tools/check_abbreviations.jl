#!/usr/bin/env julia
# Automated CI drift gate for coexisting abbreviations & short-flag uniformity (#340).
#
# Enforces permanently across the entire Friedman.APP command tree:
#   1. Command alias hygiene:
#      - Every target in `NodeCommand.aliases` exists in `NodeCommand.subcmds` (`alias != target`).
#      - Zero collisions with sibling primaries, sibling aliases, REPL built-ins
#        (`repl`/`exit`/`quit`, `data use|current|clear`), or `_PATH_REPLACEMENTS`
#        (neither exact nor prefix match).
#      - Every declared alias in `_TOP_ALIASES`, `_FAMILY_ALIASES`, and `_LEAF_ALIASES`
#        is actually mounted on its parent `NodeCommand` (zero orphan declarations).
#   2. Option & flag hygiene across all leaves:
#      - Zero intra-leaf collisions across `o.name`, `o.short`, `o.aliases`,
#        `f.name`, `f.short`, `f.aliases`.
#      - Zero claims on reserved pre-dispatch shorts (`-h`, `-V`, `-J`) or names
#        (`help`, `version`, `warranty`, `conditions`).
#      - Zero short flags shadowing a single-letter long option (`--p`, `--P`, `--Q`,
#        `--z`, `--K`, `--s`, etc.) on the same leaf.
#      - 100% short-flag uniformity: every leaf declaring a canonical option in
#        `_CANONICAL_SHORTS` (or flag in `_CANONICAL_FLAG_SHORTS`) carries its exact
#        canonical short flag (preventing regression to fragmented shorts).
#   3. Canonical dispatch & envelope command-name invariant:
#      - Every mounted command/family/leaf alias resolves via `_resolve_subcmd` to the
#        identical (`===`) target node/leaf, and `_net_command` returns the canonical
#        command string for aliased invocations.
#
# Usage (from repo root):
#   julia --project test/tools/check_abbreviations.jl

using Friedman

function _check_node_aliases!(violations::Vector{String}, node::Friedman.NodeCommand,
                              path::Vector{String}, counts::Dict{Symbol,Int})
    ctx = isempty(path) ? "root" : join(path, " ")
    repl_reserved = get(Friedman._REPL_BUILTIN_NAMES, path, ())
    seen_targets = Set{String}()

    for (al, target) in sort!(collect(pairs(node.aliases)); by=first)
        counts[:node_aliases] += 1
        if isempty(al)
            push!(violations, "node '$ctx': empty alias for target '$target'")
            continue
        end
        if al == target
            push!(violations, "node '$ctx': alias '$al' equals its own canonical target")
        end
        if !haskey(node.subcmds, target)
            push!(violations, "node '$ctx': alias '$al' points to unknown subcommand '$target'")
            continue
        end
        if haskey(node.subcmds, al)
            push!(violations, "node '$ctx': alias '$al' (for '$target') collides with sibling primary '$al'")
        end
        if al in repl_reserved
            push!(violations, "node '$ctx': alias '$al' (for '$target') collides with REPL built-in '$al'")
        end
        cand = vcat(path, [al])
        for old in keys(Friedman._PATH_REPLACEMENTS)
            if length(old) >= length(cand) && old[1:length(cand)] == cand
                push!(violations, "node '$ctx': alias '$al' (for '$target') collides with _PATH_REPLACEMENTS entry '$(join(old, " "))'")
            end
        end
        # Canonical resolution & _net_command parity
        resolved_name, resolved_sub = Friedman._resolve_subcmd(node, al)
        if resolved_name != target || resolved_sub !== node.subcmds[target]
            push!(violations, "node '$ctx': _resolve_subcmd('$al') returned '$resolved_name' (expected '$target')")
        end
        sub = node.subcmds[target]
        if sub isa Friedman.LeafCommand
            canon_argv = vcat(path, [target])
            alias_argv = vcat(path, [al])
            canon_cmd = Friedman._net_command(canon_argv)
            alias_cmd = Friedman._net_command(alias_argv)
            if canon_cmd != alias_cmd
                push!(violations, "node '$ctx': _net_command mismatch for alias '$al' -> '$alias_cmd' vs canonical '$canon_cmd'")
            end
        end
        push!(seen_targets, target)
    end

    for k in sort!(collect(keys(node.subcmds)))
        sub = node.subcmds[k]
        sub isa Friedman.NodeCommand && _check_node_aliases!(violations, sub, vcat(path, [k]), counts)
    end
end

function _check_leaf_options!(violations::Vector{String}, node::Friedman.NodeCommand,
                              path::Vector{String}, counts::Dict{Symbol,Int})
    for k in sort!(collect(keys(node.subcmds)))
        sub = node.subcmds[k]
        p = vcat(path, [k])
        if sub isa Friedman.NodeCommand
            _check_leaf_options!(violations, sub, p, counts)
            continue
        end
        counts[:leaves] += 1
        pstr = join(p, " ")
        seen = Dict{String,String}()
        single_letter_longs = Set{String}()
        for o in sub.options
            ncodeunits(o.name) == 1 && push!(single_letter_longs, o.name)
        end
        for f in sub.flags
            ncodeunits(f.name) == 1 && push!(single_letter_longs, f.name)
        end

        function claim!(tok::String, who::String; is_short::Bool=false, owner::String="")
            isempty(tok) && return
            if is_short && tok in single_letter_longs && tok != owner
                push!(violations, "leaf '$pstr': $who shadows single-letter long option '--$tok'")
            end
            if haskey(seen, tok)
                push!(violations, "leaf '$pstr': $who collides with $(seen[tok]) on token '$tok'")
            else
                seen[tok] = who
            end
        end

        for o in sub.options
            if o.name in Friedman._RESERVED_OPTION_NAMES
                push!(violations, "leaf '$pstr': option '--$(o.name)' claims reserved pre-dispatch name")
            end
            if !isempty(o.short) && o.short in Friedman._RESERVED_SHORTS
                push!(violations, "leaf '$pstr': option '--$(o.name)' claims reserved short '-$(o.short)'")
            end
            claim!(o.name, "option '--$(o.name)'")
            isempty(o.short) || claim!(o.short, "short '-$(o.short)' of '--$(o.name)'"; is_short=true, owner=o.name)
            for a in o.aliases
                if a in Friedman._RESERVED_OPTION_NAMES
                    push!(violations, "leaf '$pstr': option alias '--$a' of '--$(o.name)' claims reserved name")
                end
                claim!(a, "alias '--$a' of '--$(o.name)'")
            end
            # 100% canonical short-flag uniformity
            if haskey(Friedman._CANONICAL_SHORTS, o.name)
                counts[:canonical_opt_slots] += 1
                exp_short = Friedman._CANONICAL_SHORTS[o.name]
                if o.short != exp_short
                    push!(violations, "leaf '$pstr': option '--$(o.name)' has short $(repr(o.short)) (expected canonical '-$exp_short')")
                end
            end
        end

        for f in sub.flags
            if f.name in Friedman._RESERVED_OPTION_NAMES
                push!(violations, "leaf '$pstr': flag '--$(f.name)' claims reserved pre-dispatch name")
            end
            if !isempty(f.short) && f.short in Friedman._RESERVED_SHORTS
                push!(violations, "leaf '$pstr': flag '--$(f.name)' claims reserved short '-$(f.short)'")
            end
            claim!(f.name, "flag '--$(f.name)'")
            isempty(f.short) || claim!(f.short, "short '-$(f.short)' of '--$(f.name)'"; is_short=true, owner=f.name)
            for a in f.aliases
                if a in Friedman._RESERVED_OPTION_NAMES
                    push!(violations, "leaf '$pstr': flag alias '--$a' of '--$(f.name)' claims reserved name")
                end
                claim!(a, "alias '--$a' of '--$(f.name)'")
            end
            # 100% canonical flag short uniformity
            if haskey(Friedman._CANONICAL_FLAG_SHORTS, f.name)
                counts[:canonical_flag_slots] += 1
                exp_short = Friedman._CANONICAL_FLAG_SHORTS[f.name]
                if f.short != exp_short
                    push!(violations, "leaf '$pstr': flag '--$(f.name)' has short $(repr(f.short)) (expected canonical '-$exp_short')")
                end
            end
        end
    end
end

function _check_alias_tables_mounted!(violations::Vector{String})
    root = Friedman.APP.root
    # 1. _TOP_ALIASES (schema is special — not a subcmd in root.subcmds, resolved via _resolve_subcmd)
    for (target, als) in sort!(collect(pairs(Friedman._TOP_ALIASES)); by=first)
        if target == "schema"
            for al in als
                get(root.aliases, al, "") == "schema" ||
                    push!(violations, "_TOP_ALIASES: schema alias '$al' not mounted on root")
            end
            continue
        end
        if !haskey(root.subcmds, target)
            push!(violations, "_TOP_ALIASES: orphan target '$target' not in root.subcmds")
            continue
        end
        for al in als
            get(root.aliases, al, "") == target ||
                push!(violations, "_TOP_ALIASES: alias '$al' => '$target' not mounted on root")
        end
    end
    # 2. _FAMILY_ALIASES
    for ((top, mid), als) in sort!(collect(pairs(Friedman._FAMILY_ALIASES)); by=first)
        n1 = get(root.subcmds, top, nothing)
        if !(n1 isa Friedman.NodeCommand) || !haskey(n1.subcmds, mid)
            push!(violations, "_FAMILY_ALIASES: orphan target ($top, $mid)")
            continue
        end
        for al in als
            get(n1.aliases, al, "") == mid ||
                push!(violations, "_FAMILY_ALIASES: alias '$al' => '$mid' not mounted under '$top'")
        end
    end
    # 3. _LEAF_ALIASES
    for ((top, mid, leaf), als) in sort!(collect(pairs(Friedman._LEAF_ALIASES)); by=first)
        n1 = get(root.subcmds, top, nothing)
        n2 = n1 isa Friedman.NodeCommand ? get(n1.subcmds, mid, nothing) : nothing
        if !(n2 isa Friedman.NodeCommand) || !haskey(n2.subcmds, leaf)
            push!(violations, "_LEAF_ALIASES: orphan target ($top, $mid, $leaf)")
            continue
        end
        for al in als
            get(n2.aliases, al, "") == leaf ||
                push!(violations, "_LEAF_ALIASES: alias '$al' => '$leaf' not mounted under '$top $mid'")
        end
    end
end

function main()
    violations = String[]
    counts = Dict{Symbol,Int}(
        :node_aliases => 0,
        :leaves => 0,
        :canonical_opt_slots => 0,
        :canonical_flag_slots => 0,
    )

    # Check root schema alias separately since schema is registry-hidden
    root = Friedman.APP.root
    if get(root.aliases, "sch", "") != "schema"
        push!(violations, "root: missing 'sch' => 'schema' alias")
    end

    # Temporarily walk all non-schema node aliases cleanly
    function check_root_and_children!()
        repl_reserved = get(Friedman._REPL_BUILTIN_NAMES, String[], ())
        for (al, target) in sort!(collect(pairs(root.aliases)); by=first)
            counts[:node_aliases] += 1
            if target == "schema"
                haskey(root.subcmds, al) &&
                    push!(violations, "root: schema alias '$al' collides with subcommand '$al'")
                al in repl_reserved &&
                    push!(violations, "root: schema alias '$al' collides with REPL built-in")
                first(Friedman._resolve_subcmd(root, al)) == "schema" ||
                    push!(violations, "root: _resolve_subcmd('$al') != 'schema'")
                continue
            end
            haskey(root.subcmds, target) ||
                push!(violations, "root: alias '$al' points to unknown subcommand '$target'")
            haskey(root.subcmds, al) &&
                push!(violations, "root: alias '$al' (for '$target') collides with sibling primary '$al'")
            al in repl_reserved &&
                push!(violations, "root: alias '$al' (for '$target') collides with REPL built-in '$al'")
            for old in keys(Friedman._PATH_REPLACEMENTS)
                if !isempty(old) && old[1] == al
                    push!(violations, "root: alias '$al' (for '$target') collides with _PATH_REPLACEMENTS entry '$(join(old, " "))'")
                end
            end
            r_name, r_sub = Friedman._resolve_subcmd(root, al)
            (r_name == target && r_sub === root.subcmds[target]) ||
                push!(violations, "root: _resolve_subcmd('$al') != '$target'")
        end
        for k in sort!(collect(keys(root.subcmds)))
            sub = root.subcmds[k]
            sub isa Friedman.NodeCommand && _check_node_aliases!(violations, sub, [k], counts)
        end
    end

    check_root_and_children!()
    _check_leaf_options!(violations, root, String[], counts)
    _check_alias_tables_mounted!(violations)

    # Multi-segment canonical path equivalence spot checks
    for (aliased, canon) in (
        (["est", "mv", "var"],               "frdc estimate multivariate var"),
        (["e", "regr", "qreg"],              "frdc estimate regression qreg"),
        (["fc", "uv", "arima"],              "frdc forecast univariate arima"),
        (["fcst", "fac", "gar"],             "frdc forecast factor growth-at-risk"),
        (["t", "ur", "adf"],                 "frdc test unit-root adf"),
        (["t", "ci", "eg"],                  "frdc test coint engle-granger"),
        (["t", "stab", "bp"],                "frdc test stability bai-perron"),
        (["t", "ser", "het"],                "frdc test serial heteroskedasticity"),
        (["d", "desc"],                      "frdc data describe"),
        (["dsge", "b", "mode"],              "frdc dsge bayes posterior-mode"),
        (["ha", "ss"],                       "frdc hadsge steady-state"),
        (["pol", "cf", "var"],               "frdc policy counterfactual var"),
        (["mod", "repro"],                   "frdc model reproduce"),
        (["sp", "dens"],                     "frdc spectral density"),
    )
        got = Friedman._net_command(aliased)
        got == canon || push!(violations, "multi-segment _net_command($(join(aliased, ' '))) = '$got' (expected '$canon')")
    end

    if isempty(violations)
        println("PASS: check_abbreviations.jl — $(counts[:node_aliases]) command/family/leaf aliases, $(counts[:leaves]) leaves, $(counts[:canonical_opt_slots]) canonical option shorts + $(counts[:canonical_flag_slots]) canonical flag shorts verified (100% uniformity, 0 collisions, 0 orphans).")
        return 0
    end

    println("FAIL: check_abbreviations.jl — $(length(violations)) violation(s):")
    for v in violations
        println("  - $v")
    end
    return 1
end

exit(main())
