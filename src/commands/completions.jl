# `frdc completions bash|zsh|fish` — print shell completion scripts (C029, #283, #300)

const _COMPLETION_FILES = Dict(
    "bash" => "frdc.bash",
    "zsh"  => "frdc.zsh",
    "fish" => "_frdc.fish",
)

function _completions_root()::String
    # completions/ next to Project.toml (package root)
    return joinpath(dirname(dirname(@__DIR__)), "completions")
end

const _BUNDLED_COMPLETIONS = let
    d = Dict{String,String}()
    root = joinpath(dirname(dirname(@__DIR__)), "completions")
    for (sh, fname) in _COMPLETION_FILES
        p = joinpath(root, fname)
        if isfile(p)
            include_dependency(p)
            d[sh] = read(p, String)
        end
    end
    d
end

function _completion_tree_data(app::Entry)
    nodes = Dict{Vector{String},Vector{String}}()
    leaves = Tuple{Vector{String},LeafCommand}[]
    leaf_paths = Set{Vector{String}}()

    function walk(node::NodeCommand, path::Vector{String})
        kids = sort!(collect(keys(node.subcmds)))
        if isempty(path) && !("repl" in kids)
            push!(kids, "repl")
            sort!(kids)
        end
        nodes[copy(path)] = kids
        for k in sort!(collect(keys(node.subcmds)))
            sub = node.subcmds[k]
            p = vcat(path, [k])
            if sub isa NodeCommand
                walk(sub, p)
            else
                push!(leaves, (p, sub))
                push!(leaf_paths, p)
            end
        end
    end
    walk(app.root, String[])
    sort!(leaves; by=first)
    datasets = isdefined(@__MODULE__, :EXAMPLE_DATASETS) ?
        sort!(String[":" * string(k) for k in EXAMPLE_DATASETS]) :
        String[]
    return nodes, leaves, leaf_paths, datasets
end

function _leaf_flag_tokens(leaf::LeafCommand)::Vector{String}
    toks = String[]
    for o in leaf.options
        push!(toks, "--" * o.name)
        isempty(o.short) || push!(toks, "-" * o.short)
    end
    for f in leaf.flags
        push!(toks, "--" * f.name)
        isempty(f.short) || push!(toks, "-" * f.short)
    end
    push!(toks, "--help", "-h")
    return unique(toks)
end

function _shell_sq_esc(s::AbstractString)::String
    return replace(String(s), "'" => "'\\''")
end

function generate_bash_completion(app::Entry)::String
    nodes, leaves, leaf_paths, datasets = _completion_tree_data(app)
    ds_words = join(datasets, " ")
    io = IOBuffer()
    println(io, "# Friedman-cli (frdc) bash completion (generated from APP)")
    println(io, "_frdc() {")
    println(io, "  local cur prev")
    println(io, "  cur=\"\${COMP_WORDS[COMP_CWORD]}\"")
    println(io, "  prev=\"\"")
    println(io, "  if [[ \$COMP_CWORD -gt 0 ]]; then")
    println(io, "    prev=\"\${COMP_WORDS[COMP_CWORD-1]}\"")
    println(io, "  fi")
    println(io, "")
    println(io, "  local path=\"\"")
    println(io, "  local is_leaf=0")
    println(io, "  local expect_val=0")
    println(io, "  local i=1")
    println(io, "  while [[ \$i -lt \$COMP_CWORD ]]; do")
    println(io, "    local w=\"\${COMP_WORDS[\$i]}\"")
    println(io, "    if [[ \$expect_val -eq 1 ]]; then")
    println(io, "      expect_val=0")
    println(io, "      ((i++))")
    println(io, "      continue")
    println(io, "    fi")
    println(io, "    case \"\$w\" in")
    println(io, "      --seed|--digits) expect_val=1; ((i++)); continue ;;")
    println(io, "      --*=*|-f=*|-H=*|-o=*|-p=*) ((i++)); continue ;;")
    println(io, "      --*|-*) ((i++)); continue ;;")
    println(io, "    esac")
    println(io, "    if [[ \$is_leaf -eq 0 ]]; then")
    println(io, "      local cand=\"\"")
    println(io, "      if [[ -z \"\$path\" ]]; then cand=\"\$w\"; else cand=\"\$path \$w\"; fi")
    println(io, "      case \"\$cand\" in")
    for p in sort!(collect(keys(nodes)); by=p -> join(p, " "))
        isempty(p) && continue
        pk = join(p, " ")
        println(io, "        \"$pk\") path=\"$pk\" ;;")
    end
    for (p, _) in leaves
        pk = join(p, " ")
        println(io, "        \"$pk\") path=\"$pk\"; is_leaf=1 ;;")
    end
    println(io, "        \"repl\") path=\"repl\"; is_leaf=1 ;;")
    println(io, "      esac")
    println(io, "    fi")
    println(io, "    ((i++))")
    println(io, "  done")
    println(io, "")
    println(io, "  case \"\$path\" in")
    for p in sort!(collect(keys(nodes)); by=p -> join(p, " "))
        pk = join(p, " ")
        kids = join(nodes[p], " ")
        println(io, "    \"$pk\")")
        if isempty(p)
            println(io, "      if [[ \"\$prev\" == \"--digits\" ]]; then")
            println(io, "        COMPREPLY=( \$(compgen -W \"0 1 2 3 4 6 full\" -- \"\$cur\") )")
            println(io, "      elif [[ \"\$cur\" == -* ]]; then")
            println(io, "        COMPREPLY=( \$(compgen -W \"--help -h --version -V --warranty --conditions --quiet -q --no-color --json -J --compact --seed --digits\" -- \"\$cur\") )")
            println(io, "      else")
            println(io, "        COMPREPLY=( \$(compgen -W \"$kids\" -- \"\$cur\") )")
            println(io, "      fi ;;")
        else
            println(io, "      if [[ \"\$cur\" == -* ]]; then")
            println(io, "        COMPREPLY=( \$(compgen -W \"--help -h\" -- \"\$cur\") )")
            println(io, "      else")
            println(io, "        COMPREPLY=( \$(compgen -W \"$kids\" -- \"\$cur\") )")
            println(io, "      fi ;;")
        end
    end
    top_str = join(nodes[String[]], " ")
    for (p, leaf) in leaves
        pk = join(p, " ")
        opts_str = join(_leaf_flag_tokens(leaf), " ")
        println(io, "    \"$pk\")")
        choices_opts = [o for o in leaf.options if o.choices !== nothing && !isempty(o.choices)]
        if !isempty(choices_opts)
            println(io, "      case \"\$prev\" in")
            for o in choices_opts
                pats = isempty(o.short) ? "--$(o.name)" : "--$(o.name)|-$(o.short)"
                ch = join(o.choices, " ")
                println(io, "        $pats) COMPREPLY=( \$(compgen -W \"$ch\" -- \"\$cur\") ); return ;;")
            end
            println(io, "      esac")
        end
        println(io, "      if [[ \"\$cur\" == -* ]]; then")
        println(io, "        COMPREPLY=( \$(compgen -W \"$opts_str\" -- \"\$cur\") )")
        if pk == "schema"
            println(io, "      else")
            println(io, "        COMPREPLY=( \$(compgen -W \"$top_str\" -- \"\$cur\") )")
        else
            println(io, "      elif [[ \"\$cur\" == :* ]]; then")
            println(io, "        COMPREPLY=( \$(compgen -W \"$ds_words\" -- \"\$cur\") )")
            println(io, "      else")
            println(io, "        COMPREPLY=( \$(compgen -f -- \"\$cur\") )")
        end
        println(io, "      fi ;;")
    end
    println(io, "    \"repl\")")
    println(io, "      COMPREPLY=( \$(compgen -W \"--help -h --no-color\" -- \"\$cur\") ) ;;")
    println(io, "  esac")
    println(io, "}")
    println(io, "complete -F _frdc frdc")
    return String(take!(io))
end

function generate_zsh_completion(app::Entry)::String
    nodes, leaves, _, datasets = _completion_tree_data(app)
    ds_quoted = join(["'" * d * "'" for d in datasets], " ")
    io = IOBuffer()
    println(io, "#compdef frdc")
    println(io, "# Friedman-cli (frdc) zsh completion (generated from APP)")
    println(io, "_frdc() {")
    println(io, "  local cur prev path_str is_leaf expect_val w cand")
    println(io, "  cur=\"\${words[\$CURRENT]}\"")
    println(io, "  prev=\"\"")
    println(io, "  (( CURRENT > 1 )) && prev=\"\${words[\$((CURRENT-1))]}\"")
    println(io, "  path_str=\"\"")
    println(io, "  is_leaf=0")
    println(io, "  expect_val=0")
    println(io, "  typeset -A _fn_nodes _fn_leaves _fn_opts _fn_choices")
    for p in sort!(collect(keys(nodes)); by=p -> join(p, " "))
        pk = join(p, " ")
        isempty(pk) && continue
        println(io, "  _fn_nodes[$pk]=\"$(join(nodes[p], " "))\"")
    end
    for (p, leaf) in leaves
        pk = join(p, " ")
        println(io, "  _fn_leaves[$pk]=1")
        println(io, "  _fn_opts[$pk]=\"$(join(_leaf_flag_tokens(leaf), " "))\"")
        for o in leaf.options
            o.choices === nothing && continue
            isempty(o.choices) && continue
            ch = join(o.choices, " ")
            println(io, "  _fn_choices[\"$pk|--$(o.name)\"]=\"$ch\"")
            isempty(o.short) || println(io, "  _fn_choices[\"$pk|-$(o.short)\"]=\"$ch\"")
        end
    end
    println(io, "  _fn_leaves[repl]=1")
    println(io, "  _fn_opts[repl]=\"--help -h --no-color\"")
    println(io, "")
    println(io, "  local -i i=2")
    println(io, "  while (( i < CURRENT )); do")
    println(io, "    w=\"\${words[\$i]}\"")
    println(io, "    if (( expect_val )); then")
    println(io, "      expect_val=0; ((i++)); continue")
    println(io, "    fi")
    println(io, "    case \"\$w\" in")
    println(io, "      --seed|--digits) expect_val=1; ((i++)); continue ;;")
    println(io, "      -*) ((i++)); continue ;;")
    println(io, "    esac")
    println(io, "    if (( ! is_leaf )); then")
    println(io, "      cand=\${path_str:+\$path_str }\$w")
    println(io, "      if [[ -n \"\${_fn_leaves[\$cand]-}\" ]]; then")
    println(io, "        path_str=\"\$cand\"; is_leaf=1")
    println(io, "      elif [[ -n \"\${_fn_nodes[\$cand]-}\" ]]; then")
    println(io, "        path_str=\"\$cand\"")
    println(io, "      fi")
    println(io, "    fi")
    println(io, "    ((i++))")
    println(io, "  done")
    println(io, "")
    println(io, "  local -a cands")
    println(io, "  if (( is_leaf )); then")
    println(io, "    local ckey=\"\${path_str}|\${prev}\"")
    println(io, "    if [[ -n \"\${_fn_choices[\$ckey]-}\" ]]; then")
    println(io, "      cands=(\${=_fn_choices[\$ckey]})")
    println(io, "      _describe 'value' cands")
    println(io, "    elif [[ \"\$cur\" == -* ]]; then")
    println(io, "      cands=(\${=_fn_opts[\$path_str]})")
    println(io, "      _describe 'option' cands")
    println(io, "    elif [[ \"\$cur\" == :* ]]; then")
    println(io, "      cands=($ds_quoted)")
    println(io, "      _describe 'dataset' cands")
    println(io, "    else")
    println(io, "      _files")
    println(io, "    fi")
    println(io, "  else")
    println(io, "    if [[ \"\$prev\" == \"--digits\" ]]; then")
    println(io, "      cands=(0 1 2 3 4 6 full)")
    println(io, "      _describe 'digits' cands")
    println(io, "    elif [[ \"\$cur\" == -* ]]; then")
    println(io, "      if [[ -z \"\$path_str\" ]]; then")
    println(io, "        cands=(--help -h --version -V --warranty --conditions --quiet -q --no-color --json -J --compact --seed --digits)")
    println(io, "      else")
    println(io, "        cands=(--help -h)")
    println(io, "      fi")
    println(io, "      _describe 'option' cands")
    println(io, "    elif [[ -z \"\$path_str\" ]]; then")
    top_q = join(["'" * k * "'" for k in nodes[String[]]], " ")
    println(io, "      cands=($top_q)")
    println(io, "      _describe 'command' cands")
    println(io, "    else")
    println(io, "      cands=(\${=_fn_nodes[\$path_str]})")
    println(io, "      _describe 'subcommand' cands")
    println(io, "    fi")
    println(io, "  fi")
    println(io, "}")
    println(io, "_frdc \"\$@\"")
    return String(take!(io))
end

function generate_fish_completion(app::Entry)::String
    nodes, leaves, _, datasets = _completion_tree_data(app)
    io = IOBuffer()
    println(io, "# Friedman-cli (frdc) fish completion (generated from APP)")
    println(io, "function __frdc_path_is")
    println(io, "  set -l tokens (commandline -opc)")
    println(io, "  set -e tokens[1]")
    println(io, "  set -l p")
    println(io, "  set -l skip 0")
    println(io, "  for t in \$tokens")
    println(io, "    if test \$skip -eq 1")
    println(io, "      set skip 0")
    println(io, "      continue")
    println(io, "    end")
    println(io, "    switch \$t")
    println(io, "      case --seed --digits")
    println(io, "        set skip 1")
    println(io, "      case '-*'")
    println(io, "        continue")
    println(io, "      case ':*'")
    println(io, "        break")
    println(io, "      case '*'")
    println(io, "        set p \$p \$t")
    println(io, "        test (count \$p) -ge 3; and break")
    println(io, "    end")
    println(io, "  end")
    println(io, "  test \"\$p\" = \"\$argv[1]\"")
    println(io, "end")
    println(io, "")
    # Top-level commands
    println(io, "# Depth-1 commands")
    for k in nodes[String[]]
        desc = k == "repl" ? "Interactive session REPL" :
               (haskey(app.root.subcmds, k) ? app.root.subcmds[k].description : k)
        println(io, "complete -c frdc -n \"__frdc_path_is ''\" -f -a $k -d '$(_shell_sq_esc(desc))'")
    end
    # Depth-2 and depth-3 subcommands
    for p in sort!(collect(keys(nodes)); by=p -> join(p, " "))
        isempty(p) && continue
        pk = join(p, " ")
        # Walk app.root to node to fetch descriptions
        cur_node = app.root
        for seg in p
            cur_node = cur_node.subcmds[seg]
        end
        for k in nodes[p]
            sub = cur_node.subcmds[k]
            println(io, "complete -c frdc -n \"__frdc_path_is '$pk'\" -f -a $k -d '$(_shell_sq_esc(sub.description))'")
        end
    end
    # Leaf options, flags, choices, datasets
    ds_list = join(datasets, " ")
    for (p, leaf) in leaves
        pk = join(p, " ")
        cond = "__frdc_path_is '$pk'"
        for o in leaf.options
            short_arg = length(o.short) == 1 ? " -s $(o.short)" : ""
            ch_arg = (o.choices !== nothing && !isempty(o.choices)) ?
                " -x -a '$(join(o.choices, " "))'" : " -r"
            desc = _shell_sq_esc(o.description)
            println(io, "complete -c frdc -n \"$cond\" -l $(o.name)$short_arg$ch_arg -d '$desc'")
        end
        for f in leaf.flags
            short_arg = length(f.short) == 1 ? " -s $(f.short)" : ""
            desc = _shell_sq_esc(f.description)
            println(io, "complete -c frdc -n \"$cond\" -l $(f.name)$short_arg -d '$desc'")
        end
        println(io, "complete -c frdc -n \"$cond\" -l help -s h -d 'Show command help'")
        if !isempty(datasets) && (any(a -> a.name == "data", leaf.args) || leaf.name == "show")
            println(io, "complete -c frdc -n \"$cond; and string match -q ':*' -- (commandline -ct)\" -f -a '$ds_list'")
        end
    end
    println(io, "complete -c frdc -n \"__frdc_path_is 'repl'\" -l help -s h -d 'Show REPL help'")
    println(io, "# Global flags")
    println(io, "complete -c frdc -l digits -x -a '0 1 2 3 4 6 full' -d 'Decimal places for table display (0..16 or full)'")
    println(io, "complete -c frdc -l seed -r -d 'Set deterministic RNG seed'")
    println(io, "complete -c frdc -l quiet -s q -d 'Suppress status prose on stderr'")
    println(io, "complete -c frdc -l json -s J -d 'Print compact JSON output'")
    println(io, "complete -c frdc -l compact -d 'Fit wide/tall tables to interactive TTYs'")
    println(io, "complete -c frdc -l no-color -d 'Disable ANSI color formatting'")
    return String(take!(io))
end

function _print_completions(;
    shell::String="bash", output::String="", format::String="table",
)
    haskey(_COMPLETION_FILES, shell) || throw(CliError(
        "usage/bad-shell",
        "unknown shell '$shell' (want bash|zsh|fish)",
    ))
    text = if isdefined(@__MODULE__, :APP) && APP isa Entry
        shell == "bash" ? generate_bash_completion(APP) :
        shell == "zsh"  ? generate_zsh_completion(APP) :
                          generate_fish_completion(APP)
    else
        path = joinpath(_completions_root(), _COMPLETION_FILES[shell])
        if isfile(path)
            read(path, String)
        elseif haskey(_BUNDLED_COMPLETIONS, shell)
            _BUNDLED_COMPLETIONS[shell]
        else
            throw(CliError(
                "env/completions-missing",
                "completion file not found: $path",
                hint="run: julia --project docs/generate_cli_reference.jl",
            ))
        end
    end
    if envelope_active() && _FORCE_JSON[]
        df = DataFrame(shell = [shell], script = [text])
        output_result(df; format=:json, output=output, title="Shell Completion Script ($shell)",
                      key="completion_script")
        return nothing
    end
    if !isempty(output)
        _validate_output_path(output)
        open(_expanduser(output), "w") do io
            write(io, text)
        end
        _status("Completions written to $output")
    else
        # completions are a script, not a table — print to stdout (not envelope)
        print(text)
    end
    return nothing
end

function completions_specs()::Vector{CommandSpec}
    comp_tables = [TableSpec(name=:completion_script, description="Generated shell completion script (under --json)")]
    return [
        CommandSpec(
            path=["completions", "bash"],
            summary="Print bash completion script",
            args=ArgSpec[],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Write script to file instead of stdout"),
            ],
            flags=FlagSpec[],
            tables=comp_tables,
            category="completions",
            handler=wrap_legacy((; kwargs...) -> _print_completions(; shell="bash", kwargs...)),
        ),
        CommandSpec(
            path=["completions", "zsh"],
            summary="Print zsh completion script",
            args=ArgSpec[],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Write script to file instead of stdout"),
            ],
            flags=FlagSpec[],
            tables=comp_tables,
            category="completions",
            handler=wrap_legacy((; kwargs...) -> _print_completions(; shell="zsh", kwargs...)),
        ),
        CommandSpec(
            path=["completions", "fish"],
            summary="Print fish completion script",
            args=ArgSpec[],
            options=[
                OptionSpec(name="output", short="o", type=String, default="",
                           description="Write script to file instead of stdout"),
            ],
            flags=FlagSpec[],
            tables=comp_tables,
            category="completions",
            handler=wrap_legacy((; kwargs...) -> _print_completions(; shell="fish", kwargs...)),
        ),
    ]
end

function register_completions_commands!()
    specs = with_default_csv_kinds(completions_specs())
    specs = register!(specs)
    return build_node("completions", specs; description="Shell completion scripts (bash|zsh|fish)")
end
