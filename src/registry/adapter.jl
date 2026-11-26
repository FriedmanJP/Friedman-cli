# CommandSpec → LeafCommand / NodeCommand adapter (P2-1)

# Names/shorts the pre-dispatch layer owns (#117): `--help`/`-h` fire before
# tokenization on every leaf (`_wants_help`), and `--version`/`-V`, `--warranty`,
# `--conditions` are leading-only globals. A spec claiming one would be dead or
# shadowed on every invocation — refuse at registration (build_app), not in
# production. 48 leaves shipped an unreachable `-h` horizon short this way.
const _RESERVED_OPTION_NAMES = ("help", "version", "warranty", "conditions")
const _RESERVED_SHORTS = ("h", "V", "J")

# Centralized canonical short flags & long option/flag abbreviations (#338 / [ABBREV-W3]).
# Verified 0 intra-leaf collisions across all 560 leaves:
# - `-h`/`-V`/`-J` stay reserved for global `--help`/`--version`/`--json`.
# - `-g`/`-G` for `--plot`/`--plot-save` avoid SARIMA single-letter `--P`.
# - `--seed` has no `-z` short (avoids DSGE `--z`).
# - `-K` binds to `--shock` only (disjoint from `--shocks` on `irf lp`).
# - `-q` binds to `--factors` only (never `--nfactors`; Landmine L4).
# - `--drank` binds to `--dynamic-rank` only (never `--factors`; Landmine L4).
const _CANONICAL_SHORTS = Dict{String,String}(
    # I/O & handles
    "output"      => "o",
    "format"      => "f",
    "model"       => "M",
    "result"      => "R",
    "save-model"  => "S",
    "save-result" => "W",
    "plot-save"   => "G",
    "config"      => "C",
    # Core econometrics
    "lags"        => "p",
    "horizons"    => "H",
    "horizon"     => "H",
    "method"      => "m",
    "column"      => "c",
    "data"        => "d",
    "draws"       => "n",
    "rank"        => "r",
    "lambda"      => "l",
    "weighting"   => "w",
    "dep"         => "y",
    "indep"       => "x",
    "conf-level"  => "L",
    "quantiles"   => "Q",
    "factors"     => "q",
    "id"          => "i",
    "cov-type"    => "v",
    "clusters"    => "U",
    "id-col"      => "u",
    "time-col"    => "t",
    "instruments" => "Z",
    "bandwidth"   => "b",
    "kernel"      => "k",
    "solver"      => "s",
    "order"       => "O",
    "periods"     => "N",
    "max-iter"    => "I",
    "tol"         => "T",
    "burnin"      => "B",
    "burn"        => "B",
    "trend"       => "e",
    "shock"       => "K",
)

const _CANONICAL_FLAG_SHORTS = Dict{String,String}(
    "plot"   => "g",
    "strict" => "X",
)

const _CANONICAL_OPTION_ALIASES = Dict{String,Vector{String}}(
    "horizons"          => ["hor"],
    "horizon"           => ["hor"],
    "conf-level"        => ["cl", "ci-level"],
    "save-model"        => ["sm"],
    "save-result"       => ["sr"],
    "save-data"         => ["sd"],
    "plot-save"         => ["ps"],
    "config"            => ["cfg"],
    "config-json"       => ["cj"],
    "max-iter"          => ["miter"],
    "cov-type"          => ["cov"],
    "time-col"          => ["tcol"],
    "id-col"            => ["idcol"],
    "observables"       => ["obs"],
    "bandwidth"         => ["bw"],
    "instruments"       => ["iv"],
    "clusters"          => ["clst"],
    "measurement-error" => ["me"],
    "deterministic"     => ["det"],
    "dynamic-rank"      => ["drank"],
    "shock-size"        => ["ssize"],
    "constraint-solver" => ["csolv"],
    "distribution"      => ["dist"],
    "n-particles"       => ["npart"],
    "criterion"         => ["crit"],
    "quantiles"         => ["qtl"],
    "prefilter"         => ["pf"],
    "hp-lambda"         => ["hplam"],
    "max-lags"          => ["mlags"],
)

const _CANONICAL_FLAG_ALIASES = Dict{String,Vector{String}}(
    "marginal-effects"     => ["meff"],
    "odds-ratio"           => ["or"],
    "classification-table" => ["ctab"],
    "no-intercept"         => ["noint"],
    "no-standardize"       => ["nostd"],
    "delayed-acceptance"   => ["da"],
    "cumulative"           => ["cum"],
    "generalized"          => ["gen"],
    "standardize"          => ["std"],
    "allow-missing"        => ["amiss"],
)

"""Inject canonical short flags and long option/flag abbreviations onto a `CommandSpec`
without mutating shared `OptionSpec`/`FlagSpec` instances or creating intra-leaf
collisions or shadowing single-letter long options (`--P`, `--Q`, `--z`, `--s`, etc.) (#338)."""
function _apply_canonical_abbrevs(spec::CommandSpec)::CommandSpec
    claimed = Set{String}()
    single_letter_longs = Set{String}()
    for o in spec.options
        push!(claimed, o.name)
        ncodeunits(o.name) == 1 && push!(single_letter_longs, o.name)
        isempty(o.short) || push!(claimed, o.short)
        for a in o.aliases
            push!(claimed, a)
        end
    end
    for f in spec.flags
        push!(claimed, f.name)
        ncodeunits(f.name) == 1 && push!(single_letter_longs, f.name)
        isempty(f.short) || push!(claimed, f.short)
        for a in f.aliases
            push!(claimed, a)
        end
    end

    new_opts = OptionSpec[]
    sizehint!(new_opts, length(spec.options))
    for o in spec.options
        sh = o.short
        if isempty(sh) && haskey(_CANONICAL_SHORTS, o.name)
            cand = _CANONICAL_SHORTS[o.name]
            if !(cand in claimed) && !(cand in _RESERVED_SHORTS) &&
               (!(cand in single_letter_longs) || cand == o.name)
                sh = cand
                push!(claimed, cand)
            end
        end
        als = copy(o.aliases)
        if haskey(_CANONICAL_OPTION_ALIASES, o.name)
            for cand in _CANONICAL_OPTION_ALIASES[o.name]
                if !(cand in als) && cand != o.name &&
                   !(cand in claimed) && !(cand in _RESERVED_OPTION_NAMES)
                    push!(als, cand)
                    push!(claimed, cand)
                end
            end
        end
        if sh == o.short && als == o.aliases
            push!(new_opts, o)
        else
            push!(new_opts, OptionSpec(
                name=o.name, short=sh, type=o.type, default=o.default,
                choices=o.choices, description=o.description, since=o.since,
                handle=o.handle, repeatable=o.repeatable, aliases=als, kwarg=o.kwarg,
            ))
        end
    end

    new_flags = FlagSpec[]
    sizehint!(new_flags, length(spec.flags))
    for f in spec.flags
        sh = f.short
        if isempty(sh) && haskey(_CANONICAL_FLAG_SHORTS, f.name)
            cand = _CANONICAL_FLAG_SHORTS[f.name]
            if !(cand in claimed) && !(cand in _RESERVED_SHORTS) &&
               (!(cand in single_letter_longs) || cand == f.name)
                sh = cand
                push!(claimed, cand)
            end
        end
        als = copy(f.aliases)
        if haskey(_CANONICAL_FLAG_ALIASES, f.name)
            for cand in _CANONICAL_FLAG_ALIASES[f.name]
                if !(cand in als) && cand != f.name &&
                   !(cand in claimed) && !(cand in _RESERVED_OPTION_NAMES)
                    push!(als, cand)
                    push!(claimed, cand)
                end
            end
        end
        if sh == f.short && als == f.aliases
            push!(new_flags, f)
        else
            push!(new_flags, FlagSpec(
                name=f.name, short=sh, description=f.description,
                aliases=als, kwarg=f.kwarg,
            ))
        end
    end

    return _copy_spec(spec; options=new_opts, flags=new_flags)
end

function _check_reserved(kind::String, name::String, short::String)
    name in _RESERVED_OPTION_NAMES && error(
        "registry: $kind '--$name' collides with a pre-dispatch global; " *
        "pick another name (e.g. '--$name-file')")
    short in _RESERVED_SHORTS && error(
        "registry: $kind '--$name' claims reserved short '-$short' " *
        "(help/version fire before tokenization, so the short can never bind); drop it")
    return nothing
end

# REPL built-ins that must never be shadowed by a command alias at their parent node (#336)
const _REPL_BUILTIN_NAMES = Dict{Vector{String},Tuple{Vararg{String}}}(
    String[] => ("repl", "exit", "quit"),
    ["data"] => ("use", "current", "clear"),
)

"""Build-time intra-leaf collision guard (#336): reject any duplicate token across
option/flag primary names, shorts, and aliases, including any short `-x` colliding
with a single-letter long option `--x` (e.g. SARIMA `--P`/`--Q`/`--s`, DSGE `--z`)."""
function _check_leaf_collisions(path_str::String, options::Vector{Option}, flags::Vector{Flag})
    seen = Dict{String,String}()
    single_letter_longs = Set{String}()
    for o in options
        ncodeunits(o.name) == 1 && push!(single_letter_longs, o.name)
    end
    for f in flags
        ncodeunits(f.name) == 1 && push!(single_letter_longs, f.name)
    end
    function _claim!(tok::String, who::String; is_short::Bool=false, owner_name::String="")
        isempty(tok) && return
        if is_short && tok in single_letter_longs && tok != owner_name
            error("registry: leaf '$path_str': $who collides with single-letter long option '--$tok'")
        end
        if haskey(seen, tok)
            error("registry: leaf '$path_str': $who collides with $(seen[tok]) on token '$tok'")
        end
        seen[tok] = who
    end
    for o in options
        _check_reserved("option", o.name, o.short)
        _claim!(o.name, "option '--$(o.name)'")
        isempty(o.short) || _claim!(o.short, "short '-$(o.short)' of option '--$(o.name)'";
                                    is_short=true, owner_name=o.name)
        for a in o.aliases
            _check_reserved("option", a, "")
            _claim!(a, "alias '--$a' of option '--$(o.name)'")
        end
    end
    for f in flags
        _check_reserved("flag", f.name, f.short)
        _claim!(f.name, "flag '--$(f.name)'")
        isempty(f.short) || _claim!(f.short, "short '-$(f.short)' of flag '--$(f.name)'";
                                    is_short=true, owner_name=f.name)
        for a in f.aliases
            _check_reserved("flag", a, "")
            _claim!(a, "alias '--$a' of flag '--$(f.name)'")
        end
    end
    return nothing
end

"""Register a single coexisting alias `alias => target` on `node`, enforcing hard
build-time collision guards against sibling primaries, sibling aliases, REPL built-ins,
and removed-path entries in `_PATH_REPLACEMENTS` (#336)."""
function _register_node_alias!(node::NodeCommand, alias::String, target::String,
                               path_prefix::Vector{String})
    ctx_path = isempty(path_prefix) ? "root" : join(path_prefix, " ")
    isempty(alias) && error("registry: empty alias for '$target' under '$ctx_path'")
    haskey(node.subcmds, target) || error(
        "registry: alias '$alias' under '$ctx_path' points to unknown subcommand '$target'")
    alias == target && error(
        "registry: alias '$alias' under '$ctx_path' equals its own canonical target '$target'")
    haskey(node.subcmds, alias) && error(
        "registry: alias '$alias' (for '$target') under '$ctx_path' collides with sibling subcommand '$alias'")
    if haskey(node.aliases, alias)
        prev = node.aliases[alias]
        prev == target && return node
        error("registry: alias '$alias' under '$ctx_path' collides: claimed by both '$prev' and '$target'")
    end
    if alias in get(_REPL_BUILTIN_NAMES, path_prefix, ())
        error("registry: alias '$alias' (for '$target') under '$ctx_path' collides with REPL built-in '$alias'")
    end
    if isdefined(@__MODULE__, :_PATH_REPLACEMENTS)
        cand = vcat(path_prefix, [alias])
        for old in keys(_PATH_REPLACEMENTS)
            if length(old) >= length(cand) && old[1:length(cand)] == cand
                error("registry: alias '$alias' (for '$target') under '$ctx_path' collides with " *
                      "_PATH_REPLACEMENTS entry $(join(old, " ")) -> $(join(_PATH_REPLACEMENTS[old], " "))")
            end
        end
    end
    node.aliases[alias] = target
    return node
end

"""Attach a `target => aliases` map to `node` through `_register_node_alias!`."""
function _attach_node_aliases!(node::NodeCommand, target_to_aliases::AbstractDict{String,Vector{String}},
                               path_prefix::Vector{String})
    for (target, als) in target_to_aliases
        haskey(node.subcmds, target) || continue
        for al in als
            _register_node_alias!(node, al, target, path_prefix)
        end
    end
    return node
end

function _to_argument(a::ArgSpec)
    return Argument(a.name; type=a.type, required=a.required,
                    default=a.default, description=a.description)
end

function _to_option(o::OptionSpec)
    _check_reserved("option", o.name, o.short)
    for a in o.aliases
        _check_reserved("option", a, "")
    end
    return Option(o.name; short=o.short, type=o.type, default=o.default,
                  description=o.description, choices=o.choices,
                  repeatable=o.repeatable, aliases=o.aliases, kwarg=o.kwarg)
end

function _to_flag(f::FlagSpec)
    _check_reserved("flag", f.name, f.short)
    for a in f.aliases
        _check_reserved("flag", a, "")
    end
    return Flag(f.name; short=f.short, description=f.description,
                aliases=f.aliases, kwarg=f.kwarg)
end

"""True when `v` is a nonempty string (handle path) or a loaded object."""
_slot_set(v) = v isa AbstractString ? !isempty(v) : v !== nothing

function _kw_str(kwargs::Dict{Symbol,Any}, key::Symbol)
    v = get(kwargs, key, "")
    return v isa AbstractString ? String(v) : ""
end

# Display / rendering options permitted alongside `--result` replay (#306).
# Any other explicitly passed option/flag is a compute-only option and rejected
# declaratively with exit-2 `usage/conflicting-options`.
const _RESULT_REPLAY_ALLOWED_OPTS = Set([
    "result", "format", "output", "plot-save", "plot",
    "shock", "shocks", "summary", "emit-series",
    "quiet", "no-color", "compact", "json", "seed", "digits",
    "strict", "max-rows", "max-cols",
])

function _load_typed_handle(path::String, allowed::Vector{Symbol}, code::String;
                            slot::String, other_allowed::Vector{Symbol}=Symbol[])
    if !startswith(path, ":") && !_is_session_uri(path)
        _validate_input_path(path)
    end
    obj = load_model_dispatch(path)
    n = nameof(typeof(obj))
    if n ∉ allowed
        # Allow homogeneous result/model collections (e.g. multi-column filter bundles)
        # when every value matches an allowed type (#308).
        if obj isa AbstractDict && !isempty(obj) &&
           all(v -> nameof(typeof(v)) in allowed, values(obj))
            return obj
        end
        other = code == "model/wrong-kind" ? "--result" : "--model"
        hint = if n in other_allowed
            "this is a $n; pass it as $other, not --$slot"
        else
            "this command expects $(join(allowed, ", ")) in --$slot"
        end
        throw(CliError(code,
            "$path is a $n handle; this command accepts $(join(allowed, ", "))";
            hint=hint))
    end
    return obj
end

function _nt_save_slot(nt, key::Symbol, path::String, flag::String;
                       source_model=nothing, source_model_path::String="",
                       artifact_kind::String="")
    haskey(nt, key) || throw(CliError("model/no-result",
        "cannot $flag: handler NamedTuple has no $key field";
        hint="return (; model, result) or omit $flag"))
    obj = getfield(nt, key)
    isnothing(obj) && throw(CliError("model/no-result",
        "cannot $flag: handler returned nothing";
        hint="only estimate/solve commands produce savable models"))
    return save_model_dispatch(path, obj; source_model=source_model,
                               source_model_path=source_model_path,
                               artifact_kind=artifact_kind)
end

function _save_bare(path::String, obj, flag::String; artifact_kind::String="")
    isnothing(obj) && throw(CliError("model/no-result",
        "cannot $flag: handler returned nothing";
        hint="only estimate/solve commands produce savable models"))
    return save_model_dispatch(path, obj; artifact_kind=artifact_kind)
end

"""
    wrap_legacy(handler) → (ctx::CmdContext) -> Any

Adapt a legacy kwargs handler `_foo(; data, lags, ...)` to the CmdContext style.

Handle I/O (C029 + typed-handles):
- `--model` / `--result` stems → load, type-check, inject as objects
- `--save-model` / `--save-result` → persist the handler return (or NamedTuple fields)
"""
function wrap_legacy(handler::Function)
    return function (ctx::CmdContext)
        kwargs = Dict{Symbol,Any}()
        for (k, v) in ctx.args
            kwargs[k] = v
        end
        for (k, v) in ctx.opts
            kwargs[k] = v
        end
        for (k, v) in ctx.flags
            kwargs[k] = v
        end
        # format/output may live only in opts already; ensure present
        kwargs[:format] = string(ctx.fmt)
        kwargs[:output] = ctx.output

        # --result XOR --model XOR compute-from-data (producing leaves only).
        result_str = _kw_str(kwargs, :result)
        if !isempty(ctx.spec.result_types) && !isempty(result_str)
            if _slot_set(get(kwargs, :model, "")) || _slot_set(get(kwargs, :data, ""))
                throw(CliError("usage/invalid",
                    "--result cannot be combined with --model or a data path";
                    hint="omit --result to compute, or pass only --result to re-render"))
            end
            # Declarative compute-flag rejection for `--result` replay (#306).
            if isdefined(@__MODULE__, :_CURRENT_EXPLICIT_OPTS) && !isempty(_CURRENT_EXPLICIT_OPTS[])
                bad_opts = sort!(String[o for o in _CURRENT_EXPLICIT_OPTS[] if !(o in _RESULT_REPLAY_ALLOWED_OPTS)])
                if !isempty(bad_opts)
                    flags_str = join(["--" * o for o in bad_opts], ", ")
                    throw(CliError("usage/conflicting-options",
                        "$(join(ctx.spec.path, " ")): $flags_str cannot be combined with --result (the saved result is already computed)";
                        hint="omit $flags_str to re-render the saved result, or omit --result to recompute"))
                end
            end
        end

        # Stem-resolve + type-check the data slot (or auto-route a model handle to kwargs[:model]).
        has_pos_model = any(a -> a.name == "model", ctx.spec.args)
        can_autoroute_model = !isempty(ctx.spec.model_types) && !has_pos_model
        if can_autoroute_model && !ctx.spec.allow_data_with_model &&
           _slot_set(get(kwargs, :model, "")) && _slot_set(get(kwargs, :data, ""))
            mp_raw = get(kwargs, :model, "")
            is_domain_choice = mp_raw isa AbstractString &&
                ctx.spec.path == ["test", "multivariate", "granger"] &&
                String(mp_raw) in ("var", "vecm")
            if !is_domain_choice
                throw(CliError("usage/invalid",
                    "--model cannot be combined with a <data> argument; the saved model already carries its sample";
                    hint="omit <data> to use --model, or omit --model to estimate from <data>"))
            end
        end
        if haskey(kwargs, :data) && kwargs[:data] isa AbstractString && !isempty(kwargs[:data])
            raw_data = String(kwargs[:data])
            resolved = try
                resolve_stem(raw_data; slot=:data)
            catch e
                if e isa CliError && e.code == "data/file-not-found" &&
                   can_autoroute_model && !_slot_set(get(kwargs, :model, ""))
                    resolve_stem(raw_data; slot=:result)
                else
                    rethrow()
                end
            end
            kwargs[:data] = resolved
            kinds = ctx.spec.data_kinds
            if (!isempty(kinds) || can_autoroute_model) && _is_handle_path(resolved)
                # Confine filesystem handles on the resolved path; skip :example and session URIs.
                if !startswith(resolved, ":") && !_is_session_uri(resolved)
                    _validate_input_path(resolved)
                end
                obj = load_model_dispatch(resolved)
                if can_autoroute_model && nameof(typeof(obj)) in ctx.spec.model_types
                    if _slot_set(get(kwargs, :model, ""))
                        throw(CliError("usage/invalid",
                            "positional <data> resolved to a $(nameof(typeof(obj))) model handle while --model was also given";
                            hint="pass a data path in <data> with --model, or pass only the model handle"))
                    end
                    kwargs[:model] = obj
                    kwargs[:data] = ""
                elseif !isempty(kinds)
                    k = _data_kind_of(obj)
                    accepted = (k in kinds) || (k === :tabular && :csv in kinds)
                    if !accepted
                        acc_desc = !can_autoroute_model ? join(kinds, ", ") :
                            "$(join(kinds, ", ")) (or model handles: $(join(ctx.spec.model_types, ", ")))"
                        throw(CliError("data/wrong-kind",
                            "$resolved is a $k handle ($(nameof(typeof(obj)))); this command accepts $acc_desc";
                            hint="data import --kind timeseries, or pick a leaf that accepts $k"))
                    end
                end
            elseif !isempty(kinds) && !_is_handle_path(resolved) && !startswith(resolved, ":")
                :csv ∉ kinds && throw(CliError("data/wrong-kind",
                    "$resolved is CSV; this command does not accept :csv";
                    hint="data import first"))
            end
        end

        # --save-model / --save-result are never handler kwargs
        save_path = resolve_save_path(string(get(kwargs, :save_model, "")))
        save_result_path = resolve_save_path(string(get(kwargs, :save_result, "")))
        delete!(kwargs, :save_model)
        delete!(kwargs, :save_result)

        # Reject --save-model when a pre-fitted --model handle was already supplied (#306),
        # except on transform/estimation leaves where --model is an input model and
        # --save-model writes a newly derived model (e.g. DSGESolution -> ABCDSystem/DSGEVARPosterior).
        if !isempty(save_path) && !has_pos_model && _slot_set(get(kwargs, :model, ""))
            mp_raw = get(kwargs, :model, "")
            has_handle_model_opt = !isempty(ctx.spec.model_types) ||
                any(o -> o.name == "model" && o.handle, ctx.spec.options) ||
                !(mp_raw isa AbstractString) || _is_handle_path(String(mp_raw))
            is_domain_choice = mp_raw isa AbstractString &&
                ctx.spec.path == ["test", "multivariate", "granger"] &&
                String(mp_raw) in ("var", "vecm")
            is_model_transform = ctx.spec.path in (
                ["dsge", "abcd", "extract"],
                ["dsge", "abcd", "innovations"],
                ["dsge", "abcd", "population-var"],
                ["dsge", "var", "prior"],
                ["dsge", "var", "estimate"],
                ["ri", "transition"],
                ["ri", "statespace"],
                ["ri", "estimate"],
            )
            if has_handle_model_opt && !is_domain_choice && !is_model_transform
                throw(CliError("usage/conflicting-options",
                    "$(join(ctx.spec.path, " ")): --save-model cannot be combined with --model (the model is already loaded from a handle)";
                    hint="omit --save-model when supplying --model, or estimate from <data>"))
            end
        end

        # --result STEM → loaded object when this leaf declares result_types.
        if haskey(kwargs, :result)
            rp = kwargs[:result]
            if rp isa AbstractString
                if isempty(rp)
                    delete!(kwargs, :result)
                elseif !isempty(ctx.spec.result_types)
                    resolved = resolve_stem(String(rp); slot=:result)
                    kwargs[:result] = _load_typed_handle(resolved, ctx.spec.result_types,
                        "data/wrong-result"; slot="result", other_allowed=ctx.spec.model_types)
                    _has_data_slot(ctx.spec) && get!(kwargs, :data, "")
                    any(a -> a.name == "model", ctx.spec.args) && get!(kwargs, :model, "")
                end
            end
        end

        # --model / positional <model> → loaded object; empty → drop (unless positional <model>)
        # so handler default applies. `.jld2`, `.jls`, `.fmod`, and `model://` paths are
        # handles; builtin names and .jl/.toml model files (e.g. `hadsge irf huggett`,
        # `dsge solve rbc.toml`) pass through as strings when positional <model> is used.
        if haskey(kwargs, :model)
            mp = kwargs[:model]
            has_pos_model = any(a -> a.name == "model", ctx.spec.args)
            if mp isa AbstractString
                if isempty(mp)
                    has_pos_model || delete!(kwargs, :model)
                elseif has_pos_model
                    mp_str = String(mp)
                    exp_mp = _expanduser(mp_str)
                    is_handle_tok = _is_handle_path(mp_str) ||
                        (!startswith(mp_str, ":") &&
                         !occursin(r"\.[A-Za-z0-9]+$", basename(exp_mp)) &&
                         any(ext -> isfile(exp_mp * ext), (".jld2", ".jls", ".fmod")))
                    if !isempty(ctx.spec.model_types) && is_handle_tok
                        resolved_mp = resolve_stem(mp_str; slot=:result)
                        kwargs[:model] = _load_typed_handle(resolved_mp, ctx.spec.model_types,
                            "model/wrong-kind"; slot="model", other_allowed=ctx.spec.result_types)
                    end
                else
                    mp_str = String(mp)
                    is_domain_choice = ctx.spec.path == ["test", "multivariate", "granger"] &&
                        mp_str in ("var", "vecm") &&
                        _slot_set(get(kwargs, :data, ""))
                    if !isempty(ctx.spec.model_types) && !is_domain_choice
                        resolved_mp = resolve_stem(mp_str; slot=:result)
                        kwargs[:model] = _load_typed_handle(resolved_mp, ctx.spec.model_types,
                            "model/wrong-kind"; slot="model", other_allowed=ctx.spec.result_types)
                        _has_data_slot(ctx.spec) && get!(kwargs, :data, "")
                    elseif _is_handle_path(mp_str)
                        if !startswith(mp_str, ":") && !_is_session_uri(mp_str)
                            _validate_input_path(mp_str)
                        end
                        kwargs[:model] = load_model_dispatch(mp_str)
                        _has_data_slot(ctx.spec) && get!(kwargs, :data, "")
                    end
                end
            else
                _has_data_slot(ctx.spec) && get!(kwargs, :data, "")
            end
        end

        # Config ergonomics (C030): merge file < config-json < --set; --strict
        config_json = string(get(kwargs, :config_json, ""))
        set_raw = get(kwargs, :set, String[])
        set_vals = set_raw isa AbstractString ?
            (isempty(set_raw) ? String[] : String[String(set_raw)]) :
            String[String(s) for s in set_raw]
        strict = get(kwargs, :strict, false) === true
        delete!(kwargs, :config_json)
        delete!(kwargs, :set)
        delete!(kwargs, :strict)
        prev_strict = _CONFIG_STRICT[]
        _CONFIG_STRICT[] = strict
        try
            config_path = string(get(kwargs, :config, ""))
            if !isempty(config_path) && _is_card_path(config_path)
                # Card (W3/#208): pass the path through untouched. The TOML
                # branch below is unchanged, so --set / --config-json keep
                # merging exactly as they do today.
                kwargs[:config] = _card_config_path(config_path, set_vals, config_json)
            elseif !isempty(config_path) || !isempty(config_json) || !isempty(set_vals)
                merged = merge_config(config_path; config_json=config_json,
                                      set=set_vals, strict=strict)
                kwargs[:config] = write_merged_config_toml(merged)
            end

            result = handler(; kwargs...)

            nt_split = result isa NamedTuple &&
                (haskey(result, :model) || haskey(result, :result))
            if nt_split
                saved_m_path = isempty(save_path) ? "" :
                    string(something(_nt_save_slot(result, :model, save_path, "--save-model";
                                                   artifact_kind="model"), ""))
                if !isempty(save_result_path)
                    src_m = (haskey(result, :model) && result.model !== nothing) ? result.model : nothing
                    _nt_save_slot(result, :result, save_result_path, "--save-result";
                                  source_model=src_m, source_model_path=saved_m_path,
                                  artifact_kind="result")
                end
            elseif !isempty(save_path) && !isempty(save_result_path)
                throw(CliError("usage/invalid",
                    "handler returned a single object; use a NamedTuple (; model, result)";
                    hint="pass only --save-model or only --save-result, or return (; model, result)"))
            else
                isempty(save_path) || _save_bare(save_path, result, "--save-model"; artifact_kind="model")
                isempty(save_result_path) || _save_bare(save_result_path, result, "--save-result"; artifact_kind="result")
            end
            return result
        finally
            _CONFIG_STRICT[] = prev_strict
        end
    end
end

const _DEFAULT_STATUS_FN = (parts...) -> _status(parts...)

"""
    to_leaf(spec::CommandSpec) → LeafCommand

Bridge a declarative CommandSpec to the existing LeafCommand engine.
"""
function to_leaf(spec::CommandSpec)
    spec = _apply_canonical_abbrevs(spec)
    leaf_name = isempty(spec.path) ? "command" : spec.path[end]
    args = [_to_argument(a) for a in spec.args]
    options = [_to_option(o) for o in spec.options]
    flags = [_to_flag(f) for f in spec.flags]

    # Hoist partitioning tables and command string once at tree construction time
    arg_names = Set{Symbol}(Symbol(a.name) for a in spec.args)
    opt_keys = Set{Symbol}(
        (o.kwarg === Symbol("") ? Symbol(replace(o.name, "-" => "_")) : o.kwarg)
        for o in spec.options
    )
    flag_keys = Set{Symbol}(
        (f.kwarg === Symbol("") ? Symbol(replace(f.name, "-" => "_")) : f.kwarg)
        for f in spec.flags
    )
    cmd_str = join(spec.path, " ")
    _check_leaf_collisions(cmd_str, options, flags)
    handler = spec.handler

    function wrapper(; kwargs...)
        a = Dict{Symbol,Any}()
        sizehint!(a, length(arg_names))
        o = Dict{Symbol,Any}()
        sizehint!(o, length(opt_keys) + 2)
        fl = Dict{Symbol,Bool}()
        sizehint!(fl, length(flag_keys))
        for (k, v) in pairs(kwargs)
            if k in arg_names
                a[k] = v
            elseif k in flag_keys
                fl[k] = v === true
            else
                o[k] = v
            end
        end
        fmt = Symbol(get(o, :format, get(kwargs, :format, "table")))
        output = string(get(o, :output, get(kwargs, :output, "")))
        env = envelope_active() ? _ENVELOPE[] : Envelope(command=cmd_str)
        ctx = CmdContext(a, o, fl, fmt, output, env, _DEFAULT_STATUS_FN, spec)
        return handler(ctx)
    end

    return LeafCommand(leaf_name, wrapper;
        args=args, options=options, flags=flags, description=spec.summary,
        family=spec.family)
end

"""Register a leaf under its primary name in a subcmds dict. (C055: the C044
hidden snake_case aliases were removed at v1.0.0 — every key is primary.)"""
function _register_leaf!(cmds::Dict{String,Union{NodeCommand,LeafCommand}},
                         primary::String, leaf::LeafCommand)
    cmds[primary] = leaf
    return cmds
end

"""
    build_node(name, specs; description="") → NodeCommand

Build a node from CommandSpecs sharing path prefix `name`.
Supports depth-2 (`["estimate","var"]`) and depth-3 (`["dsge","bayes","irf"]`) paths.
"""
function build_node(name::String, specs::Vector{CommandSpec}; description::String="")
    subcmds = Dict{String,Union{NodeCommand,LeafCommand}}()
    direct_aliases = Tuple{String,String}[]
    # Group depth-3 specs by middle segment
    nested = Dict{String,Vector{CommandSpec}}()
    for spec in specs
        length(spec.path) >= 2 || error("spec path must be [node, leaf, ...]: $(spec.path)")
        spec.path[1] == name || error("spec path[1]=$(spec.path[1]) != node $name")
        if length(spec.path) == 2
            leaf = to_leaf(spec)
            _register_leaf!(subcmds, spec.path[2], leaf)
            for al in spec.aliases
                push!(direct_aliases, (al, spec.path[2]))
            end
        elseif length(spec.path) == 3
            mid = spec.path[2]
            push!(get!(nested, mid, CommandSpec[]), spec)
        else
            error("registry paths deeper than 3 not yet implemented: $(spec.path)")
        end
    end
    for (mid, nspecs) in nested
        # child leaves: path[3] becomes leaf name under mid node
        child_cmds = Dict{String,Union{NodeCommand,LeafCommand}}()
        child_aliases = Tuple{String,String}[]
        for spec in nspecs
            leaf = to_leaf(spec)
            _register_leaf!(child_cmds, spec.path[3], leaf)
            for al in spec.aliases
                push!(child_aliases, (al, spec.path[3]))
            end
        end
        child_node = NodeCommand(
            mid, child_cmds,
            isdefined(@__MODULE__, :_node_description) ? _node_description(name, mid) : mid,
        )
        for (al, target) in child_aliases
            _register_node_alias!(child_node, al, target, [name, mid])
        end
        if isdefined(@__MODULE__, :_LEAF_ALIASES)
            for (leaf_name, _) in child_cmds
                als = get(_LEAF_ALIASES, (name, mid, leaf_name),
                          get(_LEAF_ALIASES, ("*", "*", leaf_name), String[]))
                for al in als
                    _register_node_alias!(child_node, al, leaf_name, [name, mid])
                end
            end
        end
        subcmds[mid] = child_node
    end
    node = NodeCommand(name, subcmds, description)
    for (al, target) in direct_aliases
        _register_node_alias!(node, al, target, [name])
    end
    if isdefined(@__MODULE__, :_FAMILY_ALIASES)
        for (sub_name, _) in subcmds
            als = get(_FAMILY_ALIASES, (name, sub_name), String[])
            for al in als
                _register_node_alias!(node, al, sub_name, [name])
            end
        end
    end
    return node
end
