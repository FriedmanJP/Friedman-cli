# MCP server over stdio (C057/#61, W7/#142) — a PROJECTION of the registry,
# not a second implementation. Minimal JSON-RPC 2.0 (JSON3, no external MCP
# dep): initialize · tools/list (every registry leaf; inputSchema from the W5
# generator) · tools/call (argv reconstruction → run_cli with format=json
# forced; the result is the envelope JSON verbatim as text content, isError on
# nonzero exit class). Serial request handling — handlers are not
# thread-audited, and MCP clients serialize by default.
#
# stdout discipline: the JSON-RPC channel owns stdout. Every tool call runs
# under redirect_stdout to a TEMPFILE (Julia 1.13: redirect_stdout(IOBuffer)
# does not work) while responses are written to the `output` IO captured at
# loop start — so a redirected global stdout never swallows a response. MEMs
# logging and all CLI status already target stderr.

const _MCP_PROTOCOL_VERSION = "2024-11-05"

"""
    _mcp_path_matches(path, family, prefix) → Bool

`prefix` is a space-separated command path. It matches a leading slice of
`path`, or `verb family` while the leaf's family is that second token
(`estimate volatility` matches `estimate volatility garch` and, before
promotion, a leaf whose family is `volatility`).
"""
function _mcp_path_matches(path::Vector{String}, family::String, prefix::AbstractString)
    toks = split(strip(String(prefix)))
    isempty(toks) && return true
    if length(toks) <= length(path) && path[1:length(toks)] == String.(toks)
        return true
    end
    if length(toks) >= 2 && !isempty(path) && path[1] == String(toks[1]) && family == String(toks[2])
        length(toks) == 2 && return true
        rest = String.(toks[3:end])
        return length(path) >= 2 + length(rest) && path[3:2+length(rest)] == rest
    end
    return false
end

function _mcp_matches_filters(tname::String, p::Vector{String}, family::String,
                              fam_pats::Vector{String}, tool_pats::Vector{String})::Bool
    if !isempty(fam_pats)
        p1 = isempty(p) ? "" : lowercase(p[1])
        p12 = length(p) >= 2 ? lowercase("$(p[1]) $(p[2])") : ""
        fl = lowercase(family)
        pf = isempty(fl) ? p1 : "$p1 $fl"
        any(f -> f == p1 || f == fl || f == pf || f == p12, fam_pats) || return false
    end
    if !isempty(tool_pats)
        tl = lowercase(tname)
        matched = any(tool_pats) do pat
            endswith(pat, "*") ? startswith(tl, pat[1:end-1]) : tl == pat
        end
        matched || return false
    end
    return true
end

function _mcp_tools(; prefix::AbstractString="", families::AbstractString="",
                    tools::AbstractString="")
    out = Vector{Tuple{String,LeafCommand,Vector{String}}}()
    fam_pats = String[lowercase(strip(s)) for s in split(String(families), ",") if !isempty(strip(s))]
    tool_pats = String[lowercase(strip(s)) for s in split(String(tools), ",") if !isempty(strip(s))]
    function walk(node::NodeCommand, path::Vector{String})
        for name in sort!(collect(keys(node.subcmds)))
            sub = node.subcmds[name]
            # Exclude serve (stdio loop) and schema (raw meta-doc, matches agent_guide.md:216)
            isempty(path) && (name == "serve" || name == "schema") && continue
            p = vcat(path, [name])
            if sub isa LeafCommand
                tname = join(p, "_")
                _mcp_path_matches(p, sub.family, prefix) || continue
                _mcp_matches_filters(tname, p, sub.family, fam_pats, tool_pats) || continue
                push!(out, (tname, sub, p))
            else
                walk(sub, p)
            end
        end
    end
    walk(APP.root, String[])
    return out
end

function _mcp_tool_description(leaf::LeafCommand; compact::Bool=false)
    desc = leaf.description
    full = isempty(leaf.family) || startswith(desc, leaf.family) ? desc : leaf.family * " — " * desc
    if compact && length(full) > 120
        return first(full, 117) * "..."
    end
    return full
end

function _mcp_input_schema(leaf::LeafCommand, path::Vector{String}; compact::Bool=false)
    s = _input_schema(leaf, path)
    props = s["properties"]
    haskey(props, "seed") || (props["seed"] = Dict{String,Any}(
        "type" => "integer",
        "description" => "RNG seed scoped to this call",
    ))
    haskey(props, "quiet") || (props["quiet"] = Dict{String,Any}(
        "type" => "boolean",
        "default" => false,
        "description" => "Suppress stderr status output",
    ))
    if compact
        for pv in values(props)
            pv isa AbstractDict || continue
            delete!(pv, "x-cli")
            delete!(pv, "x-handle")
            if haskey(pv, "description")
                d = String(pv["description"])
                length(d) > 100 && (pv["description"] = first(d, 97) * "...")
            end
        end
    end
    return s
end

function _mcp_list_prefix(params)::String
    params === nothing && return ""
    p = get(params, :prefix, nothing)
    p === nothing && return ""
    return strip(string(p))
end

"""
    _mcp_argv(leaf, path, arguments) → Vector{String}

Reconstruct an exact argv from a tools/call `arguments` object (the inverse of
the `x-cli` annotations): positionals in declared order (stopping at the first
absent one — later positionals cannot follow a gap), then options as
`--name value`, then flags when `true`. Unknown keys are appended as options so
the strict parser answers with its typed did-you-mean usage error. `--format
json` is forced last (when the leaf declares `--format`) so every result — and
every failure — is exactly one envelope.
"""
function _mcp_argv(leaf::LeafCommand, path::Vector{String}, arguments)
    prefix_globals = String[]
    consumed = Set{Symbol}()
    has_seed_opt = any(o -> o.name == "seed", leaf.options)
    has_quiet_flag = any(f -> f.name == "quiet", leaf.flags)
    if !has_seed_opt && haskey(arguments, :seed)
        sv = arguments[:seed]
        sv === nothing || append!(prefix_globals, String["--seed", string(sv)])
        push!(consumed, :seed)
    end
    if !has_quiet_flag && haskey(arguments, :quiet)
        arguments[:quiet] === true && push!(prefix_globals, "--quiet")
        push!(consumed, :quiet)
    end

    argv = vcat(prefix_globals, path)
    for a in leaf.args
        k = Symbol(a.name)
        (!haskey(arguments, k) || arguments[k] === nothing) && break
        push!(argv, string(arguments[k]))
        push!(consumed, k)
    end
    has_format = false
    for o in leaf.options
        o.name == "format" && (has_format = true)
        k = Symbol(o.name)
        (k in consumed || !haskey(arguments, k)) && continue
        v = arguments[k]
        push!(consumed, k)
        v === nothing && continue
        if o.repeatable && o.name in _CARD_REPEATABLE
            for item in (v isa AbstractVector ? v : Any[v])
                item === nothing || push!(argv, "--" * o.name, string(item))
            end
        else
            o.name == "format" || push!(argv, "--" * o.name, string(v))
        end
    end
    for f in leaf.flags
        k = Symbol(f.name)
        (k in consumed || !haskey(arguments, k)) && continue
        arguments[k] === true && push!(argv, "--" * f.name)
        push!(consumed, k)
    end
    # Unknown keys → let the strict parser reject them with a suggestion
    for (k, v) in pairs(arguments)
        k in consumed && continue
        v === nothing && continue
        v === true ? push!(argv, "--" * string(k)) :
                     push!(argv, "--" * string(k), string(v))
    end
    has_format && append!(argv, ["--format", "json"])
    return argv
end

"""Run one tool call through the full CLI pipeline (`run_cli`) with global
stdout redirected to a tempfile — the envelope comes back verbatim as the text
content; a nonzero exit class sets `isError`."""
function _mcp_call(leaf::LeafCommand, path::Vector{String}, arguments)
    argv = _mcp_argv(leaf, path, arguments)
    prev_seed = _SEED[]
    prev_quiet = _QUIET[]
    out_path, out_io = mktemp()
    code = try
        redirect_stdout(out_io) do
            run_cli(argv)
        end
    finally
        _SEED[] = prev_seed
        _QUIET[] = prev_quiet
        try; close(out_io); catch; end
    end
    text = try
        read(out_path, String)
    finally
        try; rm(out_path; force=true); catch; end
    end
    return Dict{String,Any}(
        "content" => [Dict{String,Any}("type" => "text", "text" => String(strip(text)))],
        "isError" => Int(code) != 0,
    )
end

_rpc_send(io::IO, msg) = (write(io, JSON3.write(msg)); write(io, '\n'); flush(io))
_rpc_result(id, result) = Dict{String,Any}("jsonrpc" => "2.0", "id" => id, "result" => result)
_rpc_error(id, code::Int, msg::String) = Dict{String,Any}(
    "jsonrpc" => "2.0", "id" => id,
    "error" => Dict{String,Any}("code" => code, "message" => msg))

"""
    _serve_loop(input, output)

Line-delimited JSON-RPC 2.0 loop. `output` is captured up front, so the
per-call global-stdout redirection can never swallow a response. The session
`model://` store lives exactly as long as the loop (`_SERVE_MODEL_STORE`).
"""
function _serve_loop(input::IO, output::IO; families::AbstractString="",
                     tools::AbstractString="", compact::Bool=false)
    if isdefined(@__MODULE__, :open_session_store!)
        open_session_store!()
    else
        _SERVE_MODEL_STORE[] = Dict{String,Any}()
        isdefined(@__MODULE__, :_SERVE_SOURCE_MODELS) && (_SERVE_SOURCE_MODELS[] = Dict{String,Any}())
    end
    scoped_tools = _mcp_tools(; families=families, tools=tools)
    by_name = Dict{String,Tuple{LeafCommand,Vector{String}}}(
        n => (l, p) for (n, l, p) in scoped_tools)
    try
        for line in eachline(input)
            s = strip(line)
            isempty(s) && continue
            req = try
                JSON3.read(s)
            catch
                _rpc_send(output, _rpc_error(nothing, -32700, "parse error"))
                continue
            end
            id = get(req, :id, nothing)
            method = String(get(req, :method, ""))
            if method == "initialize"
                _rpc_send(output, _rpc_result(id, Dict{String,Any}(
                    "protocolVersion" => _MCP_PROTOCOL_VERSION,
                    "capabilities" => Dict{String,Any}("tools" => Dict{String,Any}()),
                    "serverInfo" => Dict{String,Any}(
                        "name" => "frdc", "version" => string(FRIEDMAN_VERSION)))))
            elseif startswith(method, "notifications/")
                # notifications carry no id and get no response
            elseif method == "ping"
                _rpc_send(output, _rpc_result(id, Dict{String,Any}()))
            elseif method == "tools/list"
                params = get(req, :params, nothing)
                p_fam = params === nothing ? families :
                    let pf = get(params, :families, nothing)
                        pf === nothing ? families : strip(string(pf))
                    end
                p_tools = params === nothing ? tools :
                    let pt = get(params, :tools, nothing)
                        pt === nothing ? tools : strip(string(pt))
                    end
                listed = _mcp_tools(; prefix=_mcp_list_prefix(params), families=p_fam, tools=p_tools)
                cursor_raw = params === nothing ? nothing : get(params, :cursor, nothing)
                limit_raw = params === nothing ? nothing : get(params, :limit, nothing)
                res_dict = Dict{String,Any}()
                page = if cursor_raw !== nothing || limit_raw !== nothing
                    off = cursor_raw === nothing ? 0 : something(tryparse(Int, strip(string(cursor_raw))), 0)
                    off = max(0, off)
                    lim = limit_raw === nothing ? 50 : max(1, Int(limit_raw))
                    hi = min(length(listed), off + lim)
                    hi < length(listed) && (res_dict["nextCursor"] = string(hi))
                    off >= length(listed) ? listed[1:0] : listed[(off + 1):hi]
                else
                    listed
                end
                res_dict["tools"] = [Dict{String,Any}(
                    "name" => n,
                    "description" => _mcp_tool_description(l; compact=compact),
                    "family" => l.family,
                    "inputSchema" => _mcp_input_schema(l, p; compact=compact))
                    for (n, l, p) in page]
                _rpc_send(output, _rpc_result(id, res_dict))
            elseif method == "tools/call"
                params = get(req, :params, nothing)
                name = params === nothing ? "" : String(get(params, :name, ""))
                entry = get(by_name, name, nothing)
                if entry === nothing
                    _rpc_send(output, _rpc_error(id, -32602, "unknown tool: $name"))
                else
                    raw_args = params === nothing ? nothing : get(params, :arguments, nothing)
                    arguments = raw_args === nothing ? Dict{Symbol,Any}() : raw_args
                    _rpc_send(output, _rpc_result(id, _mcp_call(entry[1], entry[2], arguments)))
                end
            else
                id === nothing ||
                    _rpc_send(output, _rpc_error(id, -32601, "method not found: $method"))
            end
        end
    finally
        if isdefined(@__MODULE__, :close_session_store!)
            close_session_store!()
        else
            _SERVE_MODEL_STORE[] = nothing
            isdefined(@__MODULE__, :_SERVE_SOURCE_MODELS) && (_SERVE_SOURCE_MODELS[] = nothing)
        end
    end
    return nothing
end

function _serve(; mcp::Bool=false, families::String="", tools::String="", compact::Bool=false,
                format::String="table", output::String="", kwargs...)
    mcp || throw(CliError("usage/missing",
        "serve requires --mcp (the only supported mode)";
        hint="frdc serve --mcp speaks JSON-RPC 2.0 / Model Context Protocol on stdio"))
    silent_banner = isdefined(@__MODULE__, :_env_get) ?
        (_env_get("FRDC_MCP_SILENT_BANNER", "FRIEDMAN_MCP_SILENT_BANNER") == "1") :
        (get(ENV, "FRDC_MCP_SILENT_BANNER", get(ENV, "FRIEDMAN_MCP_SILENT_BANNER", "")) == "1")
    silent_banner || _status("frdc MCP server on stdio (JSON-RPC 2.0, protocol $_MCP_PROTOCOL_VERSION); " *
                             "one line per message; Ctrl-D to stop")
    _serve_loop(stdin, stdout; families=families, tools=tools, compact=compact)
    return nothing
end

function serve_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["serve"],
            summary="Serve every other command as a Model Context Protocol tool over stdio (--mcp)",
            args=ArgSpec[],
            options=[
                OptionSpec(name="families", type=String, default="",
                           description="Comma-separated command groups/families to expose in MCP tools/list"),
                OptionSpec(name="tools", type=String, default="",
                           description="Comma-separated tool names or prefixes* to expose in MCP tools/list"),
            ],
            flags=[
                FlagSpec(name="mcp",
                         description="MCP server: JSON-RPC 2.0 on stdio; tools/list mirrors the commands, tools/call returns each command's plain output (JSON for commands that produce JSON)"),
                FlagSpec(name="compact",
                         description="Omit x-cli/x-handle annotations and shorten descriptions in tools/list schemas"),
            ],
            # No envelope tables: stdout is the JSON-RPC channel (gate-exempt).
            tables=TableSpec[],
            category="serve",
            handler=wrap_legacy(_serve),
        ),
    ]
end

function register_serve_commands!()
    specs = with_default_csv_kinds(serve_specs())
    specs = register!(specs)
    return to_leaf(specs[1])
end
