# Machine-readable self-description (P1-5; F6)
# Output is raw JSON (not an Envelope) — agents parse it as the schema document.

function _type_str(T)
    return string(T)
end

function _default_json(x)
    return _json_safe(x)
end

function _schema_arg(a::Argument)
    return Dict{String,Any}(
        "name" => a.name,
        "type" => _type_str(a.type),
        "required" => a.required,
        "default" => _default_json(a.default),
        "description" => a.description,
    )
end

function _schema_opt(o::Option)
    return Dict{String,Any}(
        "name" => o.name,
        "short" => o.short,
        "type" => _type_str(o.type),
        "default" => _default_json(o.default),
        "choices" => o.choices,
        "description" => o.description,
    )
end

function _schema_flag(f::Flag)
    return Dict{String,Any}(
        "name" => f.name,
        "short" => f.short,
        "description" => f.description,
    )
end

function _schema_leaf(leaf::LeafCommand, path::Vector{String})
    return Dict{String,Any}(
        "path" => path,
        "name" => leaf.name,
        "description" => leaf.description,
        "args" => [_schema_arg(a) for a in leaf.args],
        "options" => [_schema_opt(o) for o in leaf.options],
        "flags" => [_schema_flag(f) for f in leaf.flags],
    )
end

function _schema_node(node::NodeCommand, path::Vector{String})
    cmds = Any[]
    for name in sort!(collect(keys(node.subcmds)))
        sub = node.subcmds[name]
        sp = vcat(path, [name])
        if sub isa LeafCommand
            push!(cmds, Dict{String,Any}(
                "name" => name,
                "kind" => "leaf",
                "description" => sub.description,
            ))
        else
            push!(cmds, Dict{String,Any}(
                "name" => name,
                "kind" => "node",
                "description" => sub.description,
                "commands" => _schema_node(sub, sp)["commands"],
            ))
        end
    end
    return Dict{String,Any}(
        "name" => node.name,
        "path" => path,
        "description" => node.description,
        "commands" => cmds,
    )
end

function _resolve_schema_path(root::NodeCommand, parts::Vector{String})
    isempty(parts) && return root, String[]
    node = root
    path = String[]
    for (i, p) in enumerate(parts)
        haskey(node.subcmds, p) || throw(CliError("usage/unknown-command",
            "schema: unknown command path segment '$p' under $(join(path, " "))"))
        sub = node.subcmds[p]
        push!(path, p)
        if sub isa LeafCommand
            i < length(parts) && throw(CliError("usage/unknown-command",
                "schema: '$p' is a leaf; extra path $(join(parts[i+1:end], " "))"))
            return sub, path
        end
        node = sub
    end
    return node, path
end

function _schema_cmd(; path_parts::Vector{String}=String[], format::String="json", output::String="", kwargs...)
    # path_parts injected by dispatch_schema (all positional tokens after `schema`)
    target, resolved = _resolve_schema_path(APP.root, path_parts)
    doc = if target isa LeafCommand
        _schema_leaf(target, resolved)
    else
        _schema_node(target, resolved)
    end
    # Raw JSON — bypass envelope (schema document is the payload)
    json_str = JSON3.write(doc)
    if isempty(output)
        println(json_str)
    else
        _validate_output_path(output)
        open(output, "w") do io
            write(io, json_str)
            println(io)
        end
        _status("Results written to $output")
    end
    return nothing
end

"""Dispatch `schema [path…] [--output=…]` without fixed arity (path is varargs)."""
function dispatch_schema(args::Vector{String}; prog::String="friedman schema")
    if _wants_help(args)
        print_help(stdout, register_schema_command!(); prog=prog)
        return
    end
    # Split path tokens from options
    path_parts = String[]
    opt_tokens = String[]
    i = 1
    while i <= length(args)
        tok = args[i]
        if startswith(tok, "-")
            push!(opt_tokens, tok)
            # consume option value if present
            if !contains(tok, "=") && i + 1 <= length(args) && _looks_like_value(args[i+1])
                push!(opt_tokens, args[i+1])
                i += 1
            end
        else
            push!(path_parts, tok)
        end
        i += 1
    end
    parsed = tokenize(opt_tokens)
    leaf = register_schema_command!()
    bound = bind_args(parsed, leaf)
    return _schema_cmd(; path_parts=path_parts, format=bound.format, output=bound.output)
end

function register_schema_command!()
    return LeafCommand("schema", _schema_cmd;
        args=Argument[],
        options=[
            Option("format"; short="f", type=String, default="json",
                description="Always json (raw schema document)",
                choices=["json"]),
            Option("output"; short="o", type=String, default="",
                description="Write schema JSON to file"),
        ],
        description="Machine-readable CLI self-description (raw JSON, no envelope)")
end
