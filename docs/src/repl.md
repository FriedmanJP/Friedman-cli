# Interactive REPL

Friedman-cli includes an interactive REPL (Read-Eval-Print Loop) session mode for exploratory analysis.

## Launching

```bash
friedman repl
```

Or in development mode:

```bash
julia --project bin/friedman repl
```

## Session Data

Load data once and use it across multiple commands:

```
friedman> data use mydata.csv
Loaded mydata.csv (200x5, vars: GDP, CPI, FFR, UE, IP)

friedman> data use :fred-md
Loaded :fred-md (804x126, vars: INDPRO, CPIAUCSL, ...)
```

Built-in datasets: `:fred-md`, `:fred-qd`, `:pwt`, `:mpdta`, `:ddcg`.

Check or clear the current dataset:

```
friedman> data current
mydata.csv (200x5)
Cached results: var, bvar

friedman> data clear
Data and results cleared
```

## Result Caching

Estimation results are automatically cached in memory. Downstream commands (`irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`) reuse cached models:

```
friedman> estimate var --lags 4
[VAR estimation output]

friedman> irf var --horizons 20
[uses cached VAR -- no re-estimation needed]

friedman> fevd var --horizons 20
[uses same cached VAR]
```

Results are keyed by model type. Multiple model types coexist:

```
friedman> estimate var --lags 4
friedman> estimate bvar --lags 4 --draws 2000
friedman> irf var   # uses cached VAR
friedman> irf bvar  # uses cached BVAR
```

Re-estimating the same model type replaces the cached result. Loading new data clears all cached results.

## Tab Completion

Press Tab to complete commands, subcommands, and options:

```
friedman> est<Tab>     -> estimate
friedman> estimate v<Tab>  -> var, vecm
friedman> estimate var --la<Tab>  -> --lags
```

## REPL-Only Commands

| Command | Description |
|---------|-------------|
| `data use <path>` | Load CSV file into session |
| `data use :<name>` | Load built-in dataset (`:fred-md`, `:fred-qd`, `:pwt`, `:mpdta`, `:ddcg`) |
| `data current` | Show current dataset and cached results |
| `data clear` | Clear data and all cached results |
| `exit` / `quit` | Leave the REPL (also Ctrl-D) |

## Error Handling

Errors in the REPL print a message and return to the prompt -- they never exit the session. Parse errors and dispatch errors show clean messages. Unexpected errors show the exception message.
