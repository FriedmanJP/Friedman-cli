# Agent Guide

Contract for agents driving Friedman-cli. This document is the single source: it
ships inside the binary and is served verbatim by `friedman schema --docs`, and
the documentation site renders the same file.

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
    "cli_version": "0.9.2",
    "mems_version": "0.8.0",
    "julia": "1.12.x",
    "seed": null,
    "argv": ["estimate", "var", "data.csv", "--lags", "1", "--format", "json"],
    "elapsed_ms": 12.3
  },
  "data": {
    "var_coefficients": {
      "columns": ["equation", "term", "estimate", "..."],
      "rows": [["y1", "y1.l1", 0.5]]
    }
  },
  "warnings": [],
  "artifacts": [],
  "error": null
}
```

The shape is strict (v0.10.0, W1/#136):

- **Every `data` value is a table** — an object with exactly `columns` (array of
  string) and `rows` (array of arrays). Cell values are number, string, boolean,
  or null; non-finite floats appear as the strings `"NaN"`/`"Inf"`/`"-Inf"`,
  never silent JSON `null`; `missing` cells appear as `null`.
- `meta` always carries `cli_version`, `julia`, and `mems_version`; `seed`,
  `argv`, `elapsed_ms`, and `manifest` are typed-optional, and new meta keys may
  be added over time (additive).
- `status` and `error` co-occur: `"ok"` implies `error: null`; `"error"` implies
  an error object whose `code` matches `class/code` from the exit-code taxonomy
  below.

Envelope schema v1 is **draft until CLI v1.0** and **additive-only from
v0.10.0**: no key is removed or retyped within `schema_version` 1; a breaking
change bumps `schema_version` to 2 and is a major release. Normative JSON
Schema: `schema/envelope-v1.json` — it validates under any conformant draft-07
validator (CI cross-checks every golden and every T3-captured envelope with
python-jsonschema), so you can validate responses with ajv / jsonschema
directly.

## Stable table keys (v0.10.0)

`data` keys are **predictable before you run the command**: they come from each
leaf's registry-declared table names, never from runtime values.

- **Singleton tables** use the declared name verbatim: `estimate var` always
  answers under `var_coefficients` + `information_criteria` — regardless of
  `--lags`, your column names, or anything estimated. (Before v0.10.0 the same
  table was `var_2_coefficients` — the lag order baked into the address.)
- **Family tables** appear when one invocation emits several sibling tables
  (per-shock IRFs, per-variable historical decompositions). Their keys are
  `<declared-name>_<variable-slug>` — e.g. `irf var` on columns `gdp,cpi`
  answers under `irf_gdp` and `irf_cpi`. The declared name is the stable
  prefix; the suffix is a slug of *your own* variable name, so you can still
  compute every key in advance.
- Option values, horizons, CI levels, method names, and estimated parameters
  never appear in keys — they stay in the human-readable table titles.
- A CI drift gate (`check_table_keys`) validates every emitted key against the
  registry declarations, so this contract cannot silently rot.

## Every failure is an envelope too (v0.10.0)

When the argv asks for JSON (`--format json` / `-f json`, or the leading
`--json` global), **every failure also emits exactly one envelope on stdout** —
including usage/parse errors that fail before a command resolves, which used to
leave stdout empty. `status` is `"error"`, `data` is `{}`, and the `error`
object carries the machine-readable failure:

```json
{
  "schema_version": 1,
  "command": "friedman estimate var",
  "status": "error",
  "data": {},
  "error": {
    "code": "usage/parse",
    "message": "friedman estimate var: unknown option --lgas — did you mean --lags?",
    "exit_code": 2
  }
}
```

- `error.code` is `class/code` from the taxonomy below; `error.exit_code`
  **always equals the process exit code** — both derive from the same class
  mapping, so they cannot disagree.
- `error.hint` is present only when there is something to say; it is omitted
  rather than emitted empty.
- Under `--format table`/`csv`, failures keep stdout **empty** — human-readable
  error text goes to stderr, as always.
- The interactive REPL dispatches outside this path and is not part of the
  agent contract.

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

Domain failures carry **typed codes** where the underlying failure mode is
recognized (all are stable identifiers; the set only grows):

| `error.code` | Exit | Meaning |
|--------------|------|---------|
| `model/convergence` | 5 | estimator failed to converge |
| `model/identification` | 5 | identifying restrictions/instruments insufficient |
| `model/singular` | 5 | near-singular system |
| `model/stochastic-singularity` | 5 | more observables than shocks with no measurement error (DSGE likelihood) |
| `model/solve` | 5 | DSGE steady state / solver failure |
| `model/error` | 5 | other recognized domain failure |
| `data/serialization` | 3 | saved model handle unreadable or version-incompatible |
| `data/orientation` | 3 | data matrix transposed relative to the observables |

Anything else surfaces as `usage/*`, `data/*`, `config/*`, or `env/*` per the
class table above; `internal/error` (exit 1) means a CLI bug — report it.

## Strict parsing & self-correction

Unknown options throw with a suggestion when the edit distance is small:

```text
Error: friedman estimate var: unknown option --lgas — did you mean --lags?
```

`--format` is restricted to `table|csv|json`. Negative numerics bind: `--threshold -0.5`.

## Self-description: `friedman schema`

```bash
friedman schema | jq '.commands | length'            # top-level command count
friedman schema estimate var | jq '.options[].name'  # leaf options
friedman schema estimate var | jq '.input_schema'    # draft-07 invocation schema
friedman schema estimate var | jq '.tables'          # declared result-table keys
friedman schema | jq '.contract.exit_codes'          # exit-code taxonomy
friedman schema | jq -r '.docs'                      # this guide (--docs)
```

Output is **raw JSON** (not wrapped in an envelope). Since v0.10.0 (W5/#140)
the document is fully machine-actionable:

- **`input_schema`** (leaf docs): a draft-07 JSON Schema over the invocation
  surface — one property per argument/option/flag under the CLI's kebab-case
  names (`string`/`integer`/`number`/`boolean`, `enum` from declared choices,
  defaults, `required` = required positionals, `additionalProperties: false`).
  Each property carries an **`x-cli`** annotation (`kind`:
  `argument|option|flag`, `position` for positionals, `long`/`short` spellings)
  so an exact argv can be reconstructed from a validated object.
- **`tables`** (leaf docs): the registry-declared result-table keys — `name`,
  `description`, and `family` (`true` means keys are `<name>_<variable-slug>`,
  one per variable/shock; see *Stable table keys*). This is the same
  declaration set the CI drift gate enforces, so it is exactly what the
  envelope's `data` will use.
- **`contract`** (root doc): `envelope_schema` embeds the full normative
  `envelope-v1.json`, and `exit_codes` lists the class taxonomy — an agent can
  bootstrap the entire output contract from one call.
- **`--docs`**: adds this guide verbatim as a `docs` markdown string (works on
  the root and on any command path).

The `schema` command itself is deliberately absent from the command inventory
(its variable-length path does not fit the leaf model); it is discoverable from
the top-level help and from this guide.

## Determinism & reproducibility

```bash
friedman --seed 42 estimate var data.csv --format json
```

`meta.seed` echoes the seed; use the same seed for reproducible stochastic paths. Every JSON
envelope also carries `meta.manifest` — the MacroEconometricModels.jl reproducibility manifest
(seed, threads, OS, Julia + package + dependency versions, git, timestamp) — for provenance.
`--seed` is additionally forwarded as the estimator's own `seed=` for the BVAR family and
VAR/VECM IRFs, so their `ReproManifest` records it and the draws reproduce bit-for-bit.

## Model handles

`--save-model PATH` persists a fitted model; `--model PATH` reloads it (skipping re-estimation).
`.jld2` is the native, versioned format and since CLI v0.9.1 covers the full upstream
serialization registry (56 types at MacroEconometricModels 0.7.2) — in practice every model
`estimate` can fit. `.fmod` is the interim handle, now needed only for the DSGE/heterogeneous-agent
*solutions* reachable via `dsge solve --save-model`, whose compiled model closures cannot be
stored portably; saving one of those to `.jld2` fails with `model/unsupported-save` (exit 5) and
writes nothing. `friedman model info PATH` inspects either format without re-running estimation.

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
