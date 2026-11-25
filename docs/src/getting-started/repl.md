# [Interactive REPL](@id gs-repl)

Launch an interactive exploratory session inside `Friedman-cli` where datasets stay loaded in memory across commands and estimated models are cached automatically by model type for follow-up post-estimation.

## Starting & Navigating the REPL

Start the REPL from any terminal:

```bash
frdc repl
```

Run any `Friedman-cli` command without the `frdc` prefix (single- and double-quoted paths with UTF-8 spaces or characters are preserved):

```text
frdc> data use :denmark
  Loaded :denmark (55 × 5, vars: LRM, LRY, LPY, IBO, IDE)
frdc> estimate multivariate var --lags 2
frdc> irf var --shock 1 --horizons 8
frdc> fevd var --horizons 8
frdc> exit
```

Press **Tab** at any point to complete command verbs, family names, subcommands (depth 1–3), options/flags, built-in `:datasets`, `data use`/`current`/`clear`, `exit`/`quit`, and filesystem paths, or press **Up/Down** to search persistent history saved at `~/.frdc_history` (overridable via `FRDC_HISTFILE`, with `FRDC_HISTORY_FILE` fallback). Type `exit`, `quit`, or press `Ctrl-D` to leave. For scripted multi-step workflows, keep `frdc repl` or a persistent `frdc serve --mcp` session active to amortize Julia startup and JIT compilation overhead.

---

## Session Data & Model Caching

The REPL tracks an active dataset binding and a per-model-type session cache so iterative workflows omit repeated file paths and redundant estimation:

- `data use <path|stem|:example>` — loads a dataset once into memory (supports CSV files, typed handles, and bundled `:example` datasets); bare `data use` / `data use --help` shows usage without mutating session state. Supports `--json` (returns a v1 envelope) and `--quiet`.
- `data current` — prints the currently active dataset, dimensions, variables, and type (supports `--json` and `--quiet`).
- `data clear` — unloads the active session dataset and clears session model bindings (supports `--json` and `--quiet`).

Once an estimator runs during a session (`estimate multivariate var`, `estimate panel preg`, etc.), post-estimation commands (`irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`) reuse the cached model object for that model type. Pass an explicit `<data>` path or `--model <handle>` at any prompt to override the session binding for that single call. You can also address explicit in-memory session handles using `data://`, `model://`, `result://`, and `mem://` URIs (for example `--save-model model://m1`, `--save-result result://r1`, `model info model://m1`, or `model convert model://m1 -o saved.jld2`), documented in [Storage & Handle Architecture](@ref int-storage).

---

## Plotting & File Export in the REPL

All standard output and plot modifiers work directly inside the REPL:

```text
frdc> irf var --shock 1 --horizons 12 --plot
frdc> irf var --shock 1 --horizons 12 --plot-save irf_plot.html
frdc> irf var --shock 1 --horizons 12 -f csv -o irf_table.csv
```

Use [Interactive REPL](@ref gs-repl) for interactive model exploration, then move tested commands into reproducible scripts or `.jld2` handle pipelines via [Pipelines, Handles & Reproducibility](@ref gs-pipelines).
