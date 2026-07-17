# CommandSpec → LeafCommand / NodeCommand adapter (P2-1)

function _to_argument(a::ArgSpec)
    return Argument(a.name; type=a.type, required=a.required,
                    default=a.default, description=a.description)
end

function _to_option(o::OptionSpec)
    return Option(o.name; short=o.short, type=o.type, default=o.default,
                  description=o.description, choices=o.choices)
end

function _to_flag(f::FlagSpec)
    return Flag(f.name; short=f.short, description=f.description)
end

"""
    wrap_legacy(handler) → (ctx::CmdContext) -> Any

Adapt a legacy kwargs handler `_foo(; data, lags, ...)` to the CmdContext style.

Also implements model-handle I/O (C029):
- `--model PATH.fmod` → load handle, inject as `model=` object
- `--save-model PATH.fmod` → serialize handler return value after success
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

        # --save-model is never a handler kwarg
        save_path = string(get(kwargs, :save_model, ""))
        delete!(kwargs, :save_model)

        # --model PATH.fmod → loaded object; empty → drop so handler default applies.
        # Only `.fmod` paths are handles (C029). Builtin names and .jl/.toml model
        # files (e.g. `dsge ha huggett`, `dsge solve rbc.toml`) must pass through
        # as strings (C040).
        if haskey(kwargs, :model)
            mp = kwargs[:model]
            if mp isa AbstractString
                if isempty(mp)
                    delete!(kwargs, :model)
                elseif endswith(lowercase(String(mp)), ".fmod")
                    kwargs[:model] = load_model_handle(String(mp))
                    # allow missing data positional when handle supplies the model
                    get!(kwargs, :data, "")
                end
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
            if !isempty(config_path) || !isempty(config_json) || !isempty(set_vals)
                merged = merge_config(config_path; config_json=config_json,
                                      set=set_vals, strict=strict)
                kwargs[:config] = write_merged_config_toml(merged)
            end

            result = handler(; kwargs...)

            if !isempty(save_path)
                isnothing(result) && throw(CliError(
                    "model/no-result",
                    "cannot --save-model: handler returned nothing",
                    hint="only estimate/solve commands produce savable models",
                ))
                save_model_handle(save_path, result)
            end
            return result
        finally
            _CONFIG_STRICT[] = prev_strict
        end
    end
end

"""
    to_leaf(spec::CommandSpec) → LeafCommand

Bridge a declarative CommandSpec to the existing LeafCommand engine.
"""
function to_leaf(spec::CommandSpec)
    leaf_name = isempty(spec.path) ? "command" : spec.path[end]
    args = [_to_argument(a) for a in spec.args]
    options = [_to_option(o) for o in spec.options]
    flags = [_to_flag(f) for f in spec.flags]

    function wrapper(; kwargs...)
        # Partition bound kwargs into args / opts / flags
        arg_names = Set(Symbol(a.name) for a in spec.args)
        # option names use underscore form from bind_args
        opt_map = Dict{Symbol,String}()  # bound_key => option name
        for o in spec.options
            opt_map[Symbol(replace(o.name, "-" => "_"))] = o.name
        end
        flag_keys = Set(Symbol(replace(f.name, "-" => "_")) for f in spec.flags)

        a = Dict{Symbol,Any}()
        o = Dict{Symbol,Any}()
        fl = Dict{Symbol,Bool}()
        for (k, v) in pairs(kwargs)
            if k in arg_names
                a[k] = v
            elseif k in flag_keys
                fl[k] = v === true
            elseif haskey(opt_map, k)
                o[k] = v
            else
                o[k] = v  # extras (e.g. format from globals)
            end
        end
        fmt = Symbol(get(o, :format, get(kwargs, :format, "table")))
        output = string(get(o, :output, get(kwargs, :output, "")))
        env = envelope_active() ? _ENVELOPE[] : Envelope(command=join(spec.path, " "))
        status_fn = (parts...) -> _status(parts...)
        ctx = CmdContext(a, o, fl, fmt, output, env, status_fn)
        return spec.handler(ctx)
    end

    return LeafCommand(leaf_name, wrapper;
        args=args, options=options, flags=flags, description=spec.summary)
end

"""
    build_node(name, specs; description="") → NodeCommand

Build a node from CommandSpecs sharing path prefix `name`.
Supports depth-2 (`["estimate","var"]`) and depth-3 (`["dsge","bayes","irf"]`) paths.
"""
function build_node(name::String, specs::Vector{CommandSpec}; description::String="")
    subcmds = Dict{String,Union{NodeCommand,LeafCommand}}()
    # Group depth-3 specs by middle segment
    nested = Dict{String,Vector{CommandSpec}}()
    for spec in specs
        length(spec.path) >= 2 || error("spec path must be [node, leaf, ...]: $(spec.path)")
        spec.path[1] == name || error("spec path[1]=$(spec.path[1]) != node $name")
        if length(spec.path) == 2
            subcmds[spec.path[2]] = to_leaf(spec)
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
        for spec in nspecs
            child_cmds[spec.path[3]] = to_leaf(spec)
        end
        # description from first child category or mid name
        subcmds[mid] = NodeCommand(mid, child_cmds, mid)
    end
    return NodeCommand(name, subcmds, description)
end
