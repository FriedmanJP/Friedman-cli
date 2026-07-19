# Agent Guide

Contract for agents driving Friedman-cli (CLI v0.5.0+; package v0.7.0 targets MEMs v0.7.0).

## One envelope on stdout

With `--format=json`, **stdout is exactly one JSON document** (the result envelope). Status and diagnostics go to **stderr**.

```bash
friedman estimate var data.csv --lags 1 --format json | jq .
```

Example shape (fields abbreviated):

```json
{
  "schema_version": 1,
  "command": "friedman estimate var",
  "status": "ok",
  "meta": {
    "cli_version": "0.7.0",
    "mems_version": "0.7.0",
    "julia": "1.12.x",
    "seed": null,
    "argv": ["estimate", "var", "data.csv", "--lags", "1", "--format", "json"],
    "elapsed_ms": 12.3
  },
  "data": {
    "var_1_coefficients": {
      "columns": ["variable", "..."],
      "rows": [["y1", 0.5]]
    }
  },
  "warnings": [],
  "artifacts": [],
  "error": null
}
```

Non-finite floats appear as strings (`"NaN"`, `"Inf"`, `"-Inf"`), never silent JSON `null`.

Envelope schema v1 is **draft until CLI v1.0**. Normative JSON Schema: `schema/envelope-v1.json`.

## Exit codes

| Code | Class | Example |
|------|-------|---------|
| 0 | ok | successful command |
| 2 | usage | unknown command/option, bad `--format` |
| 3 | data | file not found, empty CSV, bad path |
| 4 | config | missing/malformed TOML config |
| 5 | model | domain/estimation failures (typed when available) |
| 6 | env | network/environment failures |
| 1 | internal | unexpected errors (report as bugs) |

```bash
friedman nosuchcmd; echo $?          # 2
friedman estimate var /nope.csv; echo $?   # 3
```

## Strict parsing & self-correction

Unknown options throw with a suggestion when the edit distance is small:

```text
Error: friedman estimate var: unknown option --lgas — did you mean --lags?
```

`--format` is restricted to `table|csv|json`. Negative numerics bind: `--threshold -0.5`.

## Self-description: `friedman schema`

```bash
friedman schema | jq '.commands | length'          # top-level command count
friedman schema estimate var | jq '.options[].name'  # leaf options
```

Output is **raw JSON** (not wrapped in an envelope).

## Determinism

```bash
friedman --seed 42 estimate var data.csv --format json
```

`meta.seed` echoes the seed. Use the same seed for reproducible stochastic paths.

## Quiet / no-color / json alias

| Flag | Effect |
|------|--------|
| `--quiet` / `-q` | suppress CLI status on stderr |
| `--no-color` | disable ANSI (also honors `NO_COLOR`) |
| `--json` | alias that injects `--format json` if missing |

Leading globals only (before the first subcommand token).

## Legacy output

```bash
FRIEDMAN_LEGACY_OUTPUT=1 friedman estimate var data.csv --format json
```

Restores pre-0.5 multi-document / non-envelope JSON for one minor release.

## Handler rules (for contributors)

- Status/progress: `_status` / `_status_styled` (stderr), never bare `println` for status
- Data tables: `output_result` / `output_kv`
- Typed failures: `throw(CliError("class/code", "message"; hint="…"))`
