# Friedman-cli REPL / Interactive Session Mode — Design

Resolves: https://github.com/FriedmanJP/Friedman-cli/issues/4

## Entry Point

`friedman repl` launches the REPL. `friedman` (no args) continues to show help. The REPL is a persistent Julia process with a `friedman>` prompt using Julia's `REPL.LineEdit` for readline keybindings, history, and tab completion.

## Session State

A mutable `Session` struct held as a module-level `const SESSION`:

```julia
mutable struct Session
    data_path::String              # "" if no data loaded
    df::Union{DataFrame,Nothing}   # cached DataFrame
    Y::Union{Matrix{Float64},Nothing}  # cached numeric matrix
    varnames::Vector{String}       # cached variable names
    results::Dict{Symbol,Any}      # :var => VARModel, :bvar => Chains, etc.
    last_model::Symbol             # most recently estimated model type
end
```

Handlers don't access `SESSION` directly. The REPL dispatch wrapper is the only code that reads/writes it.

## Data Flow

REPL dispatch wrapper sits between the prompt and existing `dispatch()`:

1. Parses input line into args
2. Intercepts `data use`/`data current`/`data clear`/`exit`/`quit`
3. For other commands: if `<data>` positional is missing and session has data, injects `SESSION.data_path` into args
4. For downstream commands (`irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`): if session has a cached result matching the model subcommand, passes it via `model` kwarg
5. Calls `dispatch()` in a try/catch (errors print and continue, never `exit`)
6. After `estimate *` commands: captures returned result, stores in `SESSION.results[model_type]`, updates `SESSION.last_model`

## Handler Changes

**Estimate handlers (~24):** Add `return model` at the end. Currently return `nothing`. One-shot CLI ignores the return value.

**Downstream handlers (irf/fevd/hd/forecast ~43):** Add `model=nothing` kwarg. At the top, `if isnothing(model)` → existing load+estimate path. If model provided → skip to analysis.

```julia
function _irf_var(; data::String="", lags=nothing, ..., model=nothing)
    if isnothing(model)
        model, varnames = _load_and_estimate_var(data, lags)
    else
        varnames = variable_names_from_model(model)
    end
    # ... existing IRF logic unchanged ...
end
```

`data` positional stays `required=true` in LeafCommand definitions (one-shot CLI still requires it). The REPL wrapper injects it before dispatch.

## REPL-Only Commands

- `data use mydata.csv` — loads CSV, caches DataFrame/matrix/varnames, clears cached results
- `data use :fred-md` — loads built-in dataset (`:fred-md`, `:fred-qd`, `:pwt`, `:mpdta`, `:ddcg`)
- `data current` — prints active dataset name, dimensions
- `data clear` — clears data and all cached results
- `exit` / `quit` / Ctrl-D — leaves REPL

Handled by the REPL wrapper before reaching `dispatch()`.

## Tab Completion

Plugs into `LineEdit`'s completion callback. Completes:
- Top-level commands (`estimate`, `test`, `irf`, ...)
- Subcommands (`var`, `bvar`, `adf`, ...)
- Options (`--lags`, `--horizon`, `--format`, ...)
- File paths (for `data use` and `<data>` args)
- Built-in dataset names (`:fred-md`, `:fred-qd`, ...)

Built from the `Entry` command tree — no hardcoded lists.

## Error Handling

REPL wraps every dispatch in try/catch. Errors print to stderr with red styling and return to prompt. Never calls `exit()`. Stack traces shown only for unexpected errors (not ParseError/DispatchError).

## New Files

- `src/repl.jl` — Session struct, REPL loop, dispatch wrapper, tab completion, `data use/current/clear` handlers

## Testing

- Unit tests for Session state management (use/current/clear/result caching)
- Unit tests for REPL dispatch wrapper (data injection, result capture)
- Integration tests for tab completion (command tree walking)
- Existing one-shot CLI tests unchanged

## Backward Compatibility

- One-shot CLI completely unchanged
- All existing tests pass without modification
- `friedman` (no args) still shows help
- New behavior only via `friedman repl`

## Decisions Log

| Question | Decision |
|----------|----------|
| `friedman` (no args) behavior | Shows help (unchanged). `friedman repl` launches REPL |
| REPL error handling | Separate dispatch path, catch errors and print, never `exit(1)` |
| Line editing | Julia's `REPL.LineEdit` (stdlib, readline, history, completion hooks) |
| Session state access | Module-level global, but only REPL wrapper touches it — handlers unchanged |
| Estimate handler returns | Handlers return result objects. One-shot CLI ignores return value |
| Downstream cached results | `model=nothing` kwarg on handlers. `if isnothing(model)` branches |
| Session option defaults | No. Options always specified per command |
| Built-in datasets | `data use :name` syntax (`:fred-md`, `:fred-qd`, `:pwt`, `:mpdta`, `:ddcg`) |
| Result caching | Keep all model types. Replace only on re-estimate of same type. Clear on data change |
| Tab completion | Yes. Commands, subcommands, options, file paths from Entry tree |
