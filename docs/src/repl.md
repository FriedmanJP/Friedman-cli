# Interactive REPL

Friedman-cli provides an interactive REPL (**Read-Eval-Print Loop**) for exploratory analysis. The REPL wraps the same registry as the command line: every `friedman <args>` invocation also runs as `<args>` at the `friedman>` prompt, plus session state described below.

---
## Launching

Start the session with `friedman repl`. The REPL prints a `friedman>` prompt and
accepts every `friedman <args>` invocation as `<args>` — type commands exactly
as on the command line, without the leading `friedman`. Leave with `exit`,
`quit`, or Ctrl-D.

---
## Session Data

`data use` loads a dataset once; later commands omit the positional and the REPL injects the session path automatically. An explicit positional on any command overrides the session value for that invocation.

Load a CSV or typed `.jld2`/`.jls` handle with `data use mydata.csv` (or `data use mydata` / `data use mydata.jld2`), or a bundled example with `data use :fred-md`.
A leading `:` loads a bundled example dataset through the same names `data list` advertises, with either separator spelling (`:fred-md` or `:fred_md`). A bare path or stem resolves `.jld2`/`.csv`/`.jls` files (`~` is expanded on every platform, Windows included) and resolves short **stems** the same way `data load` does. Panel datasets keep their `group`/`time` identifier columns.

Check the session with `data current` or clear it with `data clear`.
`data current` prints the session path, its dimensions, and the cached model types. `data clear` clears the dataset and all cached results.

---
## Command History

The REPL keeps persistent line-editing history via Julia `REPL.LineEdit`:

- **Up / Down arrows** recall previous commands in the session and across restarts.
- **Left / Right arrows** and standard readline bindings edit the current input line in place.
- **Ctrl-R** searches history incrementally.
- History persists across sessions at `~/.friedman_history` (override via the `FRIEDMAN_HISTORY_FILE` environment variable).

---
## Result Caching

**Estimation results** are automatically cached in memory, keyed by model type. Downstream commands (`irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`) reuse the cached model instead of re-estimating: estimating with `estimate multivariate var --lags 4` and then running `irf var --horizons 20` followed by `fevd var --horizons 20` fits the VAR once and reuses it twice. Explicit `--model` flags or positional model handles (`irf var saved_var.jld2`) override session caching for that call.

Multiple model types coexist: estimating `var` and then `bvar` caches both, and `irf var` uses the cached VAR while `irf bvar` uses the cached BVAR. Re-estimating the same model type replaces the cached result. Loading new data clears all cached results.

---
## What Persists

Typed session data and cached in-memory models clear when the REPL exits, while your command line history persists in `~/.friedman_history` (`FRIEDMAN_HISTORY_FILE`). To save models, data, or results across sessions, use `--save-model` on an `estimate`/`dsge`/`hadsge` leaf, `--save-data` on `data simulate`, `data import -o`, or `--save-result`, then pass `--model`/`--result` or positional handle paths later. Outside the REPL every invocation is stateless and takes explicit data or handle arguments.

---
## Tab Completion

Tab completes subcommand names from the registry tree and `--option`/`--flag` names on leaves — typing `est` then Tab offers `estimate`, narrowing to `estimate multivariate v` then Tab offers the family leaves, and `estimate multivariate var --la` then Tab offers the matching options.

Completion candidates are precomputed once per session from the registry. Quoted strings are respected when splitting input lines.

---
## REPL-Only Commands

| Command | Description |
|---------|-------------|
| `data use <path>` | Load a CSV, `.jld2`, or `.jls` dataset into the session |
| `data use :<name>` | Load a bundled dataset (any name from `data list`, either separator) |
| `data current` | Show current dataset and cached results |
| `data clear` | Clear data and all cached results |
| `exit` / `quit` | Leave the REPL (also Ctrl-D) |

---
## Error Handling

Errors in the REPL print a message and return to the prompt; they never exit the session. Parse and dispatch errors show their clean messages, and unexpected errors show the exception message. The REPL never calls `exit()`, so process exit codes do not apply inside a session.

---
## References

- Generated command reference: `commands/overview.md`
- Session dataset source of truth: `src/io.jl` (`EXAMPLE_DATASETS`, `parse_dataset_name`)
- Session implementation: `src/repl.jl` (`repl_dispatch`, `inject_session_data`, `session_store_result!`)
