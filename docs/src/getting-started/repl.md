# [Interactive REPL](@id gs-repl)

Launch an interactive exploratory session inside `Friedman-cli` where datasets stay loaded in memory across commands and estimated models are cached automatically by model type for follow-up post-estimation.

## Starting & Navigating the REPL

Start the REPL from any terminal:

```bash
friedman repl
```

Run any `Friedman-cli` command without the `friedman` prefix:

```text
friedman> data use :denmark
  Loaded :denmark (55 × 5, vars: LRM, LRY, LPY, IBO, IDE)
friedman> estimate multivariate var --lags 2
friedman> irf var --shock 1 --horizons 8
friedman> fevd var --horizons 8
friedman> exit
```

Press **Tab** at any point to complete command verbs, family names, subcommands, and options, or press **Up/Down** to search persistent history saved at `~/.friedman_history` (overridable via `FRIEDMAN_HISTORY_FILE`). Type `exit`, `quit`, or press `Ctrl-D` to leave.

---

## Session Data & Model Caching

The REPL tracks an active dataset binding and a per-model-type session cache so iterative workflows omit repeated file paths and redundant estimation:

- `data use <path|stem|:example>` — loads a dataset once into memory (supports CSV files, typed handles, and bundled `:example` datasets).
- `data current` — prints the currently active dataset, dimensions, variables, and type.
- `data clear` — unloads the active session dataset and clears session model bindings.

Once an estimator runs during a session (`estimate multivariate var`, `estimate panel preg`, etc.), post-estimation commands (`irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`) reuse the cached model object for that model type. Pass an explicit `<data>` path or `--model <handle>` at any prompt to override the session binding for that single call.

---

## Plotting & File Export in the REPL

All standard output and plot modifiers work directly inside the REPL:

```text
friedman> irf var --shock 1 --horizons 12 --plot
friedman> irf var --shock 1 --horizons 12 --plot-save irf_plot.html
friedman> irf var --shock 1 --horizons 12 -f csv -o irf_table.csv
```

Use [Interactive REPL](@ref gs-repl) for interactive model exploration, then move tested commands into reproducible scripts or `.jld2` handle pipelines via [Pipelines, Handles & Reproducibility](@ref gs-pipelines).
