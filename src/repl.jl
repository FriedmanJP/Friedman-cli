# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# REPL / interactive session mode


"""
    Session

Mutable state for the interactive REPL session.
"""
mutable struct Session
    data_path::String
    df::Union{DataFrame,Nothing}
    Y::Union{Matrix{Float64},Nothing}
    varnames::Vector{String}
    results::Dict{Symbol,Any}
    last_model::Symbol
end

Session() = Session("", nothing, nothing, String[], Dict{Symbol,Any}(), :none)

function session_load_data!(s::Session, path::String)
    # `~` has no shell to expand it inside the REPL; store the expanded path so
    # every downstream command that receives it via inject_session_data resolves.
    # Stem `macro` injects `macro.jld2` when that file exists (resolve_stem).
    path = startswith(path, ":") ? path : resolve_stem(_expanduser(path); slot=:data)
    df = load_data(path)
    Y = df_to_matrix(df)
    vnames = variable_names(df)
    s.data_path = path
    s.df = df
    s.Y = Y
    s.varnames = vnames
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end

function session_clear!(s::Session)
    s.data_path = ""
    s.df = nothing
    s.Y = nothing
    s.varnames = String[]
    s.results = Dict{Symbol,Any}()
    s.last_model = :none
    return s
end

function session_store_result!(s::Session, model_type::Symbol, result)
    s.results[model_type] = result
    s.last_model = model_type
    return s
end

session_has_data(s::Session) = !isempty(s.data_path)

session_get_result(s::Session, model_type::Symbol) = get(s.results, model_type, nothing)

"""
    parse_data_source(source) → (:builtin, Symbol) | (:file, String)

Classify a `data use` argument. A leading `:` marks a bundled example dataset,
resolved through the shared `parse_dataset_name` so the REPL accepts exactly the
names `data list`/`data load` advertise (either separator spelling).
"""
function parse_data_source(source::String)
    startswith(source, ":") && return (:builtin, parse_dataset_name(source))
    return (:file, source)
end

"""
    session_load_builtin!(session, name)

Load a bundled example dataset into the session. Delegates to `session_load_data!`
via the canonical `:name` reference so builtins and files take one code path —
in particular panel datasets keep their `group`/`time` id columns.
"""
function session_load_builtin!(s::Session, name::Symbol)
    return session_load_data!(s, ":$(name)")
end

"""
    _walk_command_path(app, args) → (node_or_leaf, depth)

Consume leading tokens while they match subcommand names on the registry tree.
Returns the node/leaf reached and the number of tokens consumed as the command path.
The first non-matching non-option token is a positional (data/model path) — not sniffed by extension.
"""
function _walk_command_path(app::Entry, args::Vector{String})
    node = app.root
    depth = 0
    for arg in args
        startswith(arg, "-") && break
        if node isa NodeCommand
            sub = get(node.subcmds, arg, nothing)
            isnothing(sub) && break
            depth += 1
            if sub isa LeafCommand
                return (sub, depth)
            end
            node = sub
        else
            break
        end
    end
    return (node, depth)
end

"""
    inject_session_data(session, args, app) → args

If session has data loaded and the leaf has no positional yet, inject the session
data path after the command path and before options.

Tree-walks `app.root` (no `.csv`/extension sniffing) so extensionless paths and
`:builtin` datasets are treated as positionals correctly (F27).
"""
function inject_session_data(s::Session, args::Vector{String}, app::Entry)
    session_has_data(s) || return args
    isempty(args) && return args

    node_or_leaf, depth = _walk_command_path(app, args)
    depth == 0 && return args
    # Incomplete path still on a NodeCommand — nothing to inject yet
    node_or_leaf isa LeafCommand || return args

    positionals_start = depth + 1
    for i in positionals_start:length(args)
        startswith(args[i], "-") && break
        return args  # already has a positional
    end

    spec = @isdefined(_spec_for_path) ? _spec_for_path(args[1:depth]) : nothing
    model_is_handle = spec === nothing || !isempty(spec.model_types)
    result_is_handle = spec === nothing || !isempty(spec.result_types)
    for i in positionals_start:length(args)
        tok = args[i]
        tok == "--" && break
        if model_is_handle && (tok == "--model" || startswith(tok, "--model="))
            mval = tok == "--model" ? (i < length(args) ? args[i + 1] : "") : tok[9:end]
            if !(args[1:depth] == ["test", "multivariate", "granger"] && mval in ("var", "vecm"))
                return args
            end
        end
        if result_is_handle && (tok == "--result" || startswith(tok, "--result="))
            return args
        end
    end

    new_args = copy(args)
    insert!(new_args, positionals_start, s.data_path)
    return new_args
end

# Actions that accept a cached in-memory model handle from Session.results (F15 twin of .fmod)
const MODEL_CACHE_ACTIONS = Set(["irf", "fevd", "hd", "forecast", "predict", "residuals"])

is_downstream_command(args::Vector{String}) =
    !isempty(args) && args[1] in MODEL_CACHE_ACTIONS

function detect_model_type(args::Vector{String})
    length(args) >= 2 || return :none
    # v1.0.0 family paths: estimate|predict|residuals|forecast|test <family> <model>
    if length(args) >= 3 && args[1] in ("estimate", "predict", "residuals", "forecast", "test") &&
       !startswith(args[3], "-") && !occursin(".", args[3]) && !occursin("/", args[3]) &&
       !startswith(args[3], ":")
        return Symbol(args[3])
    end
    return Symbol(args[2])
end

function is_estimate_command(args::Vector{String})
    !isempty(args) && args[1] == "estimate"
end

# Options/flags on downstream leaves (irf/fevd/hd/forecast/predict/residuals) that apply to an
# ALREADY-estimated model (#253). Any other option/flag (such as --model, --result, --lags/-p,
# --draws/-n, --prior, --rank/-r, --column/-c, --dep, etc.) indicates an explicit handle or a
# re-estimation specification and suppresses Session.results model-cache injection.
const _DOWNSTREAM_ONLY_OPTS = Set([
    "horizons", "ci", "ci-level", "ci-method", "conf-level", "confidence", "level",
    "replications", "reps", "boot-draws", "irf-draws",
    "id", "config-json", "set",
    "shock", "shock-size", "shocks", "irf-type", "summary",
    "conditions-file", "x-future", "hf-data", "hf-column", "threshold",
    "format", "output", "plot-save", "save-result", "save-model",
])

const _DOWNSTREAM_ONLY_FLAGS = Set([
    "plot", "strict", "cumulative", "generalized", "identified-set", "normalize",
    "marginal-effects", "odds-ratio", "classification-table", "standardized", "emit-series",
])

function _can_inject_cached_model(app::Entry, args::Vector{String})::Bool
    is_downstream_command(args) || return false
    any(a -> a in ("--help", "-h"), args) && return false
    node_or_leaf, depth = _walk_command_path(app, args)
    (depth > 0 && node_or_leaf isa LeafCommand) || return false
    has_id_opt = any(t -> t == "--id" || startswith(t, "--id="), @view args[(depth + 1):end])
    i = depth + 1
    n = length(args)
    while i <= n
        tok = args[i]
        if tok == "--"
            return i == n
        elseif startswith(tok, "--")
            eq = findfirst('=', tok)
            oname = eq === nothing ? tok[3:end] : tok[3:(eq - 1)]
            if oname in _DOWNSTREAM_ONLY_OPTS || (oname == "config" && has_id_opt)
                is_flag = any(f -> f.name == oname, node_or_leaf.flags)
                i += (eq === nothing && !is_flag) ? 2 : 1
            elseif oname in _DOWNSTREAM_ONLY_FLAGS && eq === nothing
                i += 1
            else
                return false
            end
        elseif startswith(tok, "-") && length(tok) >= 2
            if tok in ("-H", "-f", "-o")
                i += 2
            elseif startswith(tok, "-H=") || startswith(tok, "-f=") || startswith(tok, "-o=")
                i += 1
            else
                return false
            end
        else
            # Explicit positional (<data> or <model>) supplied by the user
            return false
        end
    end
    return true
end

function _repl_extract_globals!(args::Vector{String})
    if @isdefined(_extract_global_flags!)
        return _extract_global_flags!(copy(args))
    end
    @isdefined(_QUIET) && (_QUIET[] = false)
    @isdefined(_COLOR) && (_COLOR[] = !haskey(ENV, "NO_COLOR"))
    @isdefined(_SEED)  && (_SEED[] = nothing)
    force_json = false
    i = 1
    n = length(args)
    while i <= n
        tok = args[i]
        if tok == "--quiet" || tok == "-q"
            @isdefined(_QUIET) && (_QUIET[] = true)
            i += 1
        elseif tok == "--no-color"
            @isdefined(_COLOR) && (_COLOR[] = false)
            i += 1
        elseif tok == "--json"
            force_json = true
            i += 1
        elseif tok == "--seed"
            i + 1 <= n || throw(CliError("usage/bad-seed", "--seed requires an integer argument"))
            sval = tryparse(Int, args[i + 1])
            sval === nothing && throw(CliError("usage/bad-seed", "invalid --seed value '$(args[i + 1])'"))
            @isdefined(_SEED) && (_SEED[] = sval)
            i += 2
        elseif startswith(tok, "--seed=")
            raw = tok[8:end]
            sval = tryparse(Int, raw)
            sval === nothing && throw(CliError("usage/bad-seed", "invalid --seed value '$raw'"))
            @isdefined(_SEED) && (_SEED[] = sval)
            i += 1
        else
            break
        end
    end
    remaining = args[i:end]
    if force_json
        has_fmt = any(t -> startswith(t, "--format") || t == "-f", remaining)
        if !has_fmt
            remaining = vcat(remaining, String["--format", "json"])
        end
    end
    return remaining
end

"""
    repl_dispatch(session, app, args; err=stderr)

Dispatch a command within the REPL. Handles REPL-specific commands
(data use/current/clear, exit/quit), per-command leading global flags,
session data injection, and cached estimation results. Never calls exit().
"""
function repl_dispatch(s::Session, app::Entry, args::Vector{String}; err::IO=stderr)
    isempty(args) && return

    prev_quiet = @isdefined(_QUIET) ? _QUIET[] : false
    prev_color = @isdefined(_COLOR) ? _COLOR[] : true
    prev_seed  = @isdefined(_SEED)  ? _SEED[]  : nothing
    raw_args = copy(args)
    try
        args = _repl_extract_globals!(args)
        isempty(args) && return
        @isdefined(_LAST_ARGV) && (_LAST_ARGV[] = raw_args)

        # REPL-only commands
        if args[1] == "exit" || args[1] == "quit"
            throw(InterruptException())
        end

        # data use / data current / data clear
        if length(args) >= 2 && args[1] == "data"
            if args[2] == "use" && length(args) >= 3
                source = args[3]
                kind, val = parse_data_source(source)
                if kind == :builtin
                    session_load_builtin!(s, val)
                else
                    session_load_data!(s, val)
                end
                printstyled("✓ "; color=:green)
                println("Loaded $(s.data_path) ($(size(s.Y, 1))×$(size(s.Y, 2)), vars: $(join(s.varnames, ", ")))")
                return
            elseif args[2] == "current"
                if session_has_data(s)
                    println("$(s.data_path) ($(size(s.Y, 1))×$(size(s.Y, 2)))")
                    if !isempty(s.results)
                        println("Cached results: $(join(keys(s.results), ", "))")
                    end
                else
                    println("No data loaded")
                end
                return
            elseif args[2] == "clear"
                session_clear!(s)
                printstyled("✓ "; color=:green)
                println("Data and results cleared")
                return
            end
        end

        # Check BEFORE inject_session_data whether downstream command should use cached model (#253)
        extra_kw = Dict{Symbol,Any}()
        if _can_inject_cached_model(app, args)
            model_type = detect_model_type(args)
            cached = session_get_result(s, model_type)
            if !isnothing(cached)
                extra_kw[:model] = cached
            end
        end

        # Only inject session data when no cached model is being used
        if !haskey(extra_kw, :model)
            args = inject_session_data(s, args, app)
        end

        # Dispatch (under _mems_logger when available) and capture result
        result = if @isdefined(_mems_logger)
            Logging.with_logger(_mems_logger(err)) do
                dispatch(app, args; extra_kw...)
            end
        else
            dispatch(app, args; extra_kw...)
        end

        # Cache estimation results
        if is_estimate_command(args) && !isnothing(result)
            model_type = detect_model_type(args)
            if model_type != :none
                cached_obj = (result isa NamedTuple && haskey(result, :model)) ? result.model : result
                isnothing(cached_obj) || session_store_result!(s, model_type, cached_obj)
            end
        end
    finally
        @isdefined(_QUIET) && (_QUIET[] = prev_quiet)
        @isdefined(_COLOR) && (_COLOR[] = prev_color)
        @isdefined(_SEED)  && (_SEED[] = prev_seed)
    end
end

"""
    _strip_csi_escapes(s) → String

Remove ANSI CSI escape sequences (such as raw arrow keys `\\e[A`..`\\e[D`) that
reach the fallback line reader when no cooked/LineEdit terminal is active.
"""
_strip_csi_escapes(s::AbstractString) = replace(String(s), r"\e\[[0-9;]*[A-Za-z~]" => "")

"""
    _exec_repl_line!(s, app, raw_line; output=stdout, err=stderr) → Bool

Execute a single REPL line. Returns `true` to keep the session running, or
`false` when `exit`/`quit` terminates the session.
"""
function _exec_repl_line!(
    s::Session,
    app::Entry,
    raw_line::AbstractString;
    output::IO=stdout,
    err::IO=stderr,
)::Bool
    line = _strip_csi_escapes(raw_line)
    isempty(strip(line)) && return true

    args = _split_repl_line(line)
    try
        repl_dispatch(s, app, args; err=err)
    catch e
        if e isa InterruptException
            println(output, "Goodbye!")
            return false
        elseif e isa ParseError || e isa DispatchError || e isa CliError
            printstyled(err, "Error: "; bold=true, color=:red)
            println(err, e.message)
        else
            printstyled(err, "Error: "; bold=true, color=:red)
            println(err, sprint(showerror, e))
        end
    end
    return true
end

"""
    _resolve_histfile() → String

Resolve the persistent REPL history file path. Defaults to `~/.friedman_history`;
override via `FRIEDMAN_HISTFILE`. Setting `FRIEDMAN_HISTFILE` to `""`, `"none"`,
`"off"`, `"false"`, or `"0"` disables disk persistence for the session.
"""
function _resolve_histfile()::String
    raw = get(ENV, "FRIEDMAN_HISTFILE", nothing)
    if raw === nothing
        return joinpath(_expanduser("~"), ".friedman_history")
    end
    s = strip(raw)
    (isempty(s) || lowercase(s) in ("none", "off", "false", "0")) && return ""
    return _expanduser(String(s))
end

"""
    start_repl()

Launch the interactive REPL with a `friedman>` prompt.
"""
function start_repl()
    app = APP
    s = SESSION
    session_clear!(s)
    # F63: build completion candidates once at session start
    idx = _reset_completion_index!(app)
    lineedit_ready = try
        _init_completion_provider()
        true
    catch
        # REPL stdlib not available; fall back to readline loop
        false
    end
    # Keep index on provider if LineEdit path is active (rebuild after init)
    _COMPLETION_INDEX[] = idx

    printstyled("Friedman REPL v$(FRIEDMAN_VERSION)\n"; bold=true)
    println("Type commands as you would on the command line. Type 'exit' to quit.")
    println()

    if lineedit_ready && stdin isa Base.TTY && stdout isa Base.TTY &&
       stderr isa Base.TTY && lowercase(get(ENV, "TERM", "")) != "dumb"
        term = try
            Base.invokelatest(_make_tty_terminal)
        catch
            nothing
        end
        if term !== nothing
            Base.invokelatest(_run_lineedit_repl, app, s, idx; term=term)
            return nothing
        end
    end
    _repl_readline_loop(app, s)
    return nothing
end

function _repl_readline_loop(
    app::Entry,
    s::Session;
    input::IO=stdin,
    output::IO=stdout,
    err::IO=stderr,
)
    while true
        try
            printstyled(output, "friedman> "; color=:blue, bold=true)
            flush(output)
            if eof(input)
                println(output, "\nGoodbye!")
                return nothing
            end
            line = readline(input)
            _exec_repl_line!(s, app, line; output=output, err=err) || return nothing
        catch e
            if e isa EOFError || e isa InterruptException
                println(output, "\nGoodbye!")
                return nothing
            end
            rethrow()
        end
    end
end

"""
    _split_repl_line(line) → Vector{String}

Split a REPL input line into tokens, respecting quoted strings.
"""
function _split_repl_line(line::String)
    tokens = String[]
    i = 1
    while i <= length(line)
        while i <= length(line) && isspace(line[i])
            i += 1
        end
        i > length(line) && break

        if line[i] == '"'
            j = findnext('"', line, i + 1)
            if isnothing(j)
                push!(tokens, line[(i + 1):end])
                break
            end
            push!(tokens, line[(i + 1):(j - 1)])
            i = j + 1
        else
            j = findnext(isspace, line, i)
            if isnothing(j)
                push!(tokens, line[i:end])
                break
            end
            push!(tokens, line[i:(j - 1)])
            i = j
        end
    end
    return tokens
end

# ── Completion index (F63: precomputed once per session, not per keystroke) ──

"""
Sorted candidate vectors for tab completion, built once from the registry tree.
"""
struct CompletionIndex
    children::Dict{Vector{String},Vector{String}}  # path → sorted subcommand names
    leaf_opts::Dict{Vector{String},Vector{String}} # path → sorted --option/--flag names
end

function build_completion_index(app::Entry)::CompletionIndex
    children = Dict{Vector{String},Vector{String}}()
    leaf_opts = Dict{Vector{String},Vector{String}}()
    function walk(node::NodeCommand, path::Vector{String})
        kids = sort!(collect(keys(node.subcmds)))
        children[copy(path)] = kids
        for name in kids
            sub = node.subcmds[name]
            p = vcat(path, name)
            if sub isa NodeCommand
                walk(sub, p)
            else
                opts = String["--" * o.name for o in sub.options]
                append!(opts, ["--" * f.name for f in sub.flags])
                sort!(opts)
                leaf_opts[p] = opts
            end
        end
    end
    walk(app.root, String[])
    return CompletionIndex(children, leaf_opts)
end

# Session-scoped index; rebuilt in start_repl / when APP changes
const _COMPLETION_INDEX = Ref{Union{Nothing,CompletionIndex}}(nothing)

function _completion_index(app::Entry)::CompletionIndex
    idx = _COMPLETION_INDEX[]
    if isnothing(idx)
        idx = build_completion_index(app)
        _COMPLETION_INDEX[] = idx
    end
    return idx
end

function _reset_completion_index!(app::Entry)
    _COMPLETION_INDEX[] = build_completion_index(app)
    return _COMPLETION_INDEX[]
end

"""
    complete_command(app, partial_line; index=nothing) → Vector{String}

Return completion candidates for the current partial input line.
Uses a precomputed `CompletionIndex` (F63) when available.
"""
function complete_command(
    app::Entry,
    partial::String;
    index::Union{Nothing,CompletionIndex}=nothing,
)
    idx = isnothing(index) ? _completion_index(app) : index
    tokens = _split_repl_line(partial)
    isempty(tokens) && return get(idx.children, String[], String[])

    has_trailing_space = !isempty(partial) && isspace(last(partial))
    consumed = has_trailing_space ? tokens : tokens[1:(end - 1)]
    prefix = has_trailing_space ? "" : tokens[end]

    path = String[]
    for tok in consumed
        if haskey(idx.leaf_opts, path)
            continue
        end
        startswith(tok, "-") && return String[]
        if haskey(idx.children, path) && tok in idx.children[path]
            push!(path, tok)
        else
            return String[]
        end
    end

    if haskey(idx.leaf_opts, path)
        return _filter_prefix(idx.leaf_opts[path], prefix)
    end
    startswith(prefix, "-") && return String[]
    kids = get(idx.children, path, String[])
    return _filter_prefix(kids, prefix)
end

_filter_prefix(candidates::Vector{String}, prefix::String) =
    isempty(prefix) ? candidates : filter(c -> startswith(c, prefix), candidates)

function _complete_leaf_options(leaf::LeafCommand, prefix::String)
    startswith(prefix, "-") || return String[]
    options = ["--" * o.name for o in leaf.options]
    flags = ["--" * f.name for f in leaf.flags]
    all_opts = sort(vcat(options, flags))
    return _filter_prefix(all_opts, prefix)
end

# FriedmanCompletionProvider is defined at runtime when REPL is loaded
# to avoid requiring REPL as a compile-time dependency
const _REPL_PKG_ID = Base.PkgId(
    Base.UUID("3fa0cd96-eef1-5676-8a61-b3b8758bbffb"),
    "REPL",
)

const _LINEEDIT_INITIALIZED = Ref(false)
function _make_tty_terminal end
function _run_lineedit_repl end

function _init_completion_provider()
    _LINEEDIT_INITIALIZED[] && return nothing
    REPLmod = isdefined(@__MODULE__, :REPL) ? getfield(@__MODULE__, :REPL) : Base.require(_REPL_PKG_ID)
    LineEditmod = getfield(REPLmod, :LineEdit)
    Terminalsmod = getfield(REPLmod, :Terminals)
    CompletionProvider = getfield(LineEditmod, :CompletionProvider)

    @eval begin
        const _REPL = $REPLmod
        const _LineEdit = $LineEditmod
        const _Terminals = $Terminalsmod

        struct FriedmanCompletionProvider <: $CompletionProvider
            app::Entry
            index::CompletionIndex
        end

        function $LineEditmod.complete_line(c::FriedmanCompletionProvider, state; hint::Bool=false)
            buf = $LineEditmod.buffer(state)
            pos = position(buf)
            partial = pos > 0 ? String(buf.data[1:pos]) : ""
            completions = complete_command(c.app, partial; index=c.index)
            has_trailing_space = !isempty(partial) && isspace(last(partial))
            tokens = _split_repl_line(partial)
            last_token = (isempty(tokens) || has_trailing_space) ? "" : tokens[end]
            return completions, last_token, !isempty(completions)
        end
        $LineEditmod.complete_line(c::FriedmanCompletionProvider, state, ::Module; hint::Bool=false) =
            $LineEditmod.complete_line(c, state; hint=hint)

        _make_tty_terminal() = _Terminals.TTYTerminal(get(ENV, "TERM", "xterm"), stdin, stdout, stderr)

        function _run_lineedit_repl(
            app::Entry,
            s::Session,
            idx::CompletionIndex;
            term=nothing,
            histfile::Union{Nothing,String}=nothing,
        )
            term_obj = term === nothing ? _make_tty_terminal() : term
            out_io = hasproperty(term_obj, :out_stream) ? term_obj.out_stream : stdout
            err_io = hasproperty(term_obj, :err_stream) ? term_obj.err_stream : stderr
            has_color = _Terminals.hascolor(term_obj)

            panel = _LineEdit.Prompt(
                "friedman> ";
                prompt_prefix=has_color ? "\e[1m\e[34m" : "",
                prompt_suffix=has_color ? "\e[0m" : "",
                complete=FriedmanCompletionProvider(app, idx),
                on_enter=Returns(true),
            )

            hp = _REPL.REPLHistoryProvider(Dict{Symbol,_LineEdit.Prompt}(:friedman => panel))
            hpath = histfile === nothing ? _resolve_histfile() : histfile
            if !isempty(hpath)
                try
                    mkpath(dirname(abspath(hpath)))
                    hp.history = _REPL.History.HistoryFile(hpath)
                    _REPL.history_do_initialize(hp)
                catch
                    hp.history = _REPL.History.HistoryFile()
                end
            end
            _REPL.history_reset_state(hp)
            panel.hist = hp

            panel.on_done = (mi, buf, ok) -> begin
                if !ok
                    _LineEdit.transition(mi, :abort)
                    println(out_io, "Goodbye!")
                    return nothing
                end
                line = String(take!(buf))
                _LineEdit.reset_state(mi)
                try; _Terminals.raw!(term_obj, false); catch; end
                if !_exec_repl_line!(s, app, line; output=out_io, err=err_io)
                    _LineEdit.transition(mi, :abort)
                end
                return nothing
            end

            prefix_prompt, prefix_keymap = _LineEdit.setup_prefix_keymap(hp, panel)
            main_keymap = _LineEdit.keymap(Dict{Any,Any}[
                prefix_keymap,
                _LineEdit.history_keymap,
                _LineEdit.default_keymap,
                _LineEdit.escape_defaults,
            ])
            panel.keymap_dict = main_keymap
            modal = _LineEdit.ModalInterface(_LineEdit.TextInterface[panel, prefix_prompt])
            try
                _LineEdit.run_interface(term_obj, modal)
            finally
                try; _Terminals.raw!(term_obj, false); catch; end
                try; close(hp.history); catch; end
            end
            return nothing
        end
    end
    _LINEEDIT_INITIALIZED[] = true
    return nothing
end

const SESSION = Session()
