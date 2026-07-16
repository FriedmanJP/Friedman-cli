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
        return handler(; kwargs...)
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

Build a node from CommandSpecs that share a common path prefix of length 1
(the node name) and differ in the leaf name (path[2]).
"""
function build_node(name::String, specs::Vector{CommandSpec}; description::String="")
    subcmds = Dict{String,Union{NodeCommand,LeafCommand}}()
    for spec in specs
        length(spec.path) >= 2 || error("spec path must be [node, leaf, ...]: $(spec.path)")
        spec.path[1] == name || error("spec path[1]=$(spec.path[1]) != node $name")
        leaf = to_leaf(spec)
        # support deeper paths later; pilot is depth-2
        if length(spec.path) == 2
            subcmds[spec.path[2]] = leaf
        else
            error("nested registry paths depth>2 not yet implemented: $(spec.path)")
        end
    end
    return NodeCommand(name, subcmds, description)
end
