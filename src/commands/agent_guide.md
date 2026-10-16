# Agent Guide

Contract for agents driving Friedman-cli. This document is the single source: it
ships inside the binary and is served verbatim by `friedman schema --docs`, and
the documentation site renders the same file. The per-leaf command reference
lives under `commands/` on the site; this guide covers the output contract
shared by every leaf.

## One envelope on stdout

With `--format json`, **stdout is exactly one JSON document** (the result envelope). Status and diagnostics go to **stderr**.

```bash
friedman estimate multivariate var data.csv --lags 1 --format json | jq .
```

Model commands are `verb family model` (`estimate volatility garch`,
`test unit-root adf`). `hadsge solve` is the HouseholdSystem command;
`dsge solve` stays representative-agent. `friedman schema estimate`
groups leaves by `family`. `tools/list` takes an optional `prefix`
(`estimate volatility`, `hadsge`).

Example shape (fields abbreviated):

```json
{
  "schema_version": 1,
  "command": "friedman estimate multivariate var",
  "status": "ok",
  "meta": {
    "cli_version": "1.0.0",
    "mems_version": "1.0.0",
    "julia": "1.13.0",
    "seed": null,
    "argv": ["estimate", "multivariate", "var", "data.csv", "--lags", "1", "--format", "json"],
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

The shape is strict:

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

Envelope schema v1 is **frozen**: no key is removed or retyped within
`schema_version` 1; a breaking change bumps `schema_version` to 2 and is a
major release. Normative JSON Schema: `schema/envelope-v1.json` — it validates
under any conformant draft-07 validator, so you can validate responses with
ajv / jsonschema directly.

---

## Stable table keys

`data` keys are **predictable before you run the command**: they come from each
leaf's registry-declared table names, never from runtime values.

- **Singleton tables** use the declared name verbatim: `estimate multivariate var` always
  answers under `var_coefficients` + `information_criteria` — regardless of
  `--lags`, your column names, or anything estimated.
- **Family tables** appear when one invocation emits several sibling tables
  (per-shock IRFs, per-variable historical decompositions). Their keys are
  `<declared-name>_<variable-slug>` — e.g. `irf var` on columns `gdp,cpi`
  answers under `irf_gdp` and `irf_cpi`. The declared name is the stable
  prefix; the suffix is a slug of *your own* variable name, so you can still
  compute every key in advance.
- Option values, horizons, CI levels, method names, and estimated parameters
  never appear in keys — they stay in the human-readable table titles.

---

## Every failure is an envelope too

When the argv asks for JSON (`--format json` / `-f json`, or the leading
`--json` global), **every failure also emits exactly one envelope on stdout** —
including usage/parse errors that fail before a command resolves. `status` is
`"error"`, `data` is `{}`, and the `error` object carries the machine-readable
failure:

```json
{
  "schema_version": 1,
  "command": "friedman estimate multivariate var",
  "status": "error",
  "data": {},
  "error": {
    "code": "usage/parse",
    "message": "friedman estimate multivariate var: unknown option --lgas — did you mean --lags?",
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

---

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
friedman estimate multivariate var /nope.csv; echo $?   # 3
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
| `data/wrong-kind` | 3 | data slot loaded a container not in the leaf's `data_kinds` (e.g. `PanelData` on `estimate multivariate var`) |
| `data/wrong-result` | 3 | `--result` loaded a type not in the leaf's `result_types` (e.g. a `VARModel` on `irf var --result`) |
| `model/wrong-kind` | 5 | `--model` loaded a type not in the leaf's `model_types` (e.g. an `ImpulseResponse` on `irf var --model`) |

Anything else surfaces as `usage/*`, `data/*`, `config/*`, or `env/*` per the
class table above; `internal/error` (exit 1) means a CLI bug — report it.

---

## Strict parsing & self-correction

Unknown options throw with a suggestion when the edit distance is small:

```text
Error: friedman estimate multivariate var: unknown option --lgas — did you mean --lags?
```

`--format` is restricted to `table|csv|json`. Negative numerics bind: `--threshold -0.5`.

---

## Self-description: `friedman schema`

```bash
friedman schema | jq '.commands | length'            # top-level command count
friedman schema estimate multivariate var | jq '.options[].name'  # leaf options
friedman schema estimate multivariate var | jq '.input_schema'    # draft-07 invocation schema
friedman schema estimate multivariate var | jq '.tables'          # declared result-table keys
friedman schema | jq '.contract.exit_codes'          # exit-code taxonomy
friedman schema | jq -r '.docs'                      # this guide (--docs)
```

Output is **raw JSON** (not wrapped in an envelope). The document is fully
machine-actionable:

- **`input_schema`** (leaf docs): a draft-07 JSON Schema over the invocation
  surface — one property per argument/option/flag under the CLI's kebab-case
  names (`string`/`integer`/`number`/`boolean`, `enum` from declared choices,
  defaults, `required` = required positionals, `additionalProperties: false`).
  Each property carries an **`x-cli`** annotation (`kind`:
  `argument|option|flag`, `position` for positionals, `long`/`short` spellings)
  so an exact argv can be reconstructed from a validated object. Handle slots
  also carry **`x-handle`** (`role`: `data|model|result`, plus `kinds` /
  `types` from the registry) — see *Typed handles* below.
  An option you may give more than once also carries **`x-cli.repeatable:
  true`**, and its property is typed `"array"` with a single-element `items`
  schema instead of a scalar. Repeat the array entry once per occurrence to
  build the argv — `["rho ~ beta(2, 2)", "sigma ~ inv_gamma(2, 0.5)"]` for
  `--prior` becomes `--prior 'rho ~ beta(2, 2)' --prior 'sigma ~
  inv_gamma(2, 0.5)'`, not a comma-joined string and not one value that wins.
  An option without the key takes one value; repeating it keeps the last.
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

---

## MCP server: `friedman serve --mcp`

```bash
friedman serve --mcp    # JSON-RPC 2.0 / Model Context Protocol on stdio
```

`serve` requires `--mcp` (the only supported mode). Every other command becomes
an MCP **tool** — one process, no per-call spawn:

- **`tools/list`** mirrors the registry: tool name = command path joined with
  `_` (`estimate_multivariate_var`, `estimate_volatility_garch`, `dsge_bayes_estimate`).
  Each tool has a `family` field, and its description starts with that family.
  `inputSchema` is the same draft-07 schema `friedman schema` reports.
  Pass `params.prefix` to keep one slice (`"estimate volatility"` returns only
  that family's estimate leaves; `"hadsge"` returns the household leaves).
  An unknown prefix returns `"tools": []` and a successful RPC result, not a
  JSON-RPC error. Omit `prefix`, or pass `""`, to list every leaf except `serve`.
- **`tools/call`** reconstructs the exact argv from your arguments object and
  returns the **envelope verbatim** as text content — same bytes as the CLI,
  same stable `data` keys, same typed `error.code`/`exit_code` on failure
  (`isError` mirrors a nonzero exit class). `--format json` is appended when
  the leaf declares `--format`, so results and failures are exactly one
  envelope. Unknown argument keys are forwarded so the strict parser answers
  with its typed did-you-mean usage error. Everything in this guide about
  envelopes applies unchanged.
- **`model://` handles**: within a serve session, `--save-model model://name`
  stores the fitted model **in memory** and `--model model://name` reuses it —
  estimate once, then run irf/fevd/forecast against the handle with no
  re-estimation and no files. Handles live exactly as long as the session;
  file handles (`.jld2`/`.fmod`) also work as usual. Outside a serve session a
  `model://` handle is a typed `usage/invalid` error.
- Requests are handled **serially** (handlers are not thread-audited); stdout
  carries only the JSON-RPC stream — status and library logs stay on stderr.

---

## Determinism & reproducibility

```bash
friedman --seed 42 estimate multivariate var data.csv --format json
```

`--seed` is a leading global: it seeds the process RNG (`Random.seed!`) on
every invocation, and `meta.seed` echoes it. On leaves whose estimator accepts
its own `seed=` keyword, the CLI additionally forwards `--seed` as that
keyword, so the estimator's recorded reproducibility manifest carries it and
the draws reproduce bit-for-bit; estimators that expose only an `rng` keyword
stay reproducible through the global seed alone. Every JSON envelope also
carries `meta.manifest` — the MacroEconometricModels.jl reproducibility
manifest (seed, threads, OS, Julia + package + dependency versions, git,
timestamp) — for provenance. `friedman model reproduce HANDLE` re-runs the
recorded estimator and reports a match verdict plus per-field diffs
(`unverifiable` when no seed was recorded — not a pass).

---

## Typed handles (data, model, result)

Three object kinds, each with its own slot. `--result` / `--save-result` skip
compute and re-render a saved result; `friedman show STEM` renders any loadable
handle (data, model, result, or a keys-only bundle listing).

| Kind | Argv slot | Native persist |
|------|-----------|----------------|
| data | positional `<data>` / `--data` | `data import -o STEM` → `STEM.jld2` |
| model | `--model` / `--save-model` | `--save-model STEM` → `STEM.jld2` |
| result | `--result` / `--save-result` | `--save-result STEM` → `STEM.jld2` |

**Stems vs suffixes.** Data positionals, `--save-model`, `--save-result`,
`--model` (when the leaf declares `model_types`), `--result`, and
`friedman show` accept suffix-less stems (`macro`, `--save-model var` →
`var.jld2`, `--model var` loads `var.jld2`). Data load prefers `path.jld2`
over `path.csv` when both exist; `--model` / `--result` / `show` have no CSV
fallback. An explicit suffix skips the search. `model://name` is the
in-session URI (serve) and is not stem-expanded. `:fred_md` example names are
unchanged.

```bash
friedman data import macro.csv --kind timeseries -o macro
friedman estimate multivariate var macro --lags 2 --save-model var   # stem → var.jld2
friedman irf var --model var --horizons 12 --save-result irf
friedman irf var --result irf                            # re-render; no data
friedman show macro          # TimeSeriesData descriptive stats
friedman show var            # fitted model table
friedman show irf            # re-render the saved ImpulseResponse
friedman forecast evaluate metrics macro --actual gdp --result fcst_var,fcst_bvar
friedman model info var.jld2
# CSV shortcut still works:
friedman estimate multivariate var macro.csv --lags 2
```

`data import --kind` is required for CSV (no autodetection). Edits do not
promote CSV to `.jld2` (`usage/invalid` — import first; `data import` itself
is the intended CSV→`.jld2` conversion). A handle whose type is not in the
leaf's `data_kinds` is `data/wrong-kind` (exit 3). `--result` of the wrong
result type is `data/wrong-result` (exit 3); `--model` of the wrong model
type is `model/wrong-kind` (exit 5). `--result` cannot be combined with
`--model` or a data path (`usage/invalid`).

`friedman schema <leaf>` annotates handle slots with **`x-handle`**:
`{role: "data"|"model"|"result", kinds: [...], types: [...]}` next to the
existing `x-cli` argv annotations. **Presence vs absence of `x-handle` is the
signal** — not whether `kinds`/`types` are empty. Empty `types` on a data slot
is normal (data uses `kinds`); producing-leaf `--model` / `--result` slots
carry `types` from the registry. `data validate --model` has **no**
`x-handle` (it is a type *string*, not a model handle). Evaluate `--result`
is a comma-separated string (`handle=false`, no `x-handle`).

### Model handles

`--save-model PATH` persists a fitted model (suffix-less stem → `.jld2`);
`--model STEM` (or `.jld2` / `.fmod` / `model://`) reloads it (skipping
re-estimation) on leaves that declare `model_types`. `.jld2` is the native,
versioned format covering the full upstream serialization registry — every
model `estimate` can fit, including DSGE/HA solutions (`dsge solve`,
`hadsge solve`, `hadsge steady-state`, `dsge bayes estimate` all take
`--save-model`). `.fmod` remains as the interim handle for unregistered
payloads. `friedman model info PATH` reads the container header (writing
versions, note, bundle layout) without re-running estimation — header-only, it
never executes stored code.
Trust caveat (mirrors upstream): a `--model` handle carrying DSGE/HA equations recompiles
them at load through an AST allowlist (`Core.eval`), the same risk class as
`Serialization.deserialize` — only load files you trust. Programmatic payloads with
anonymous closures (household utilities, `ss_fn`) fail at `--save-model` time with
`data/serialization`; persist named functions or callable structs (`CRRAUtility`) instead.

---

## Model cards

Complex model specifications come in two formats, and both lower to the same
settings, so the estimator sees one set of values either way. A **model card**
is plain text with named stanzas; **TOML** is still fully supported everywhere,
with its precedence rules unchanged.

**The extension decides the format: a `.toml` file is always TOML**, even when
it fails to parse, so a broken TOML file keeps its `config/malformed-toml`
error with the parser's own message — a card misnamed `config.toml` is reported
as broken TOML, and the message shows the `stanza:` line the parser tripped on.
The reverse — a TOML file under a non-`.toml` name — is a typed error whose hint
names the format you actually wrote. A file with **no** extension is read as a
card. `--set` and `--config-json` merge into TOML files only — against a card
they are refused with a hint, not silently ignored.

Exactly seven stanza headers exist. Any other `word:` at the start of a line is
a `config/invalid` error naming the line, never a silently ignored section:
`priors:`, `constraints:`, `gmm lp:`, `gmm iv:`, `smm:`, `equations:`,
`instruments:`. Body lines must be indented (two spaces, or a tab); a stanza
ends at the first line at column 0; `#` starts a comment; numbers are plain
decimal literals, and card text is never run as code. An empty stanza is
refused — a stanza that says nothing is a mistake, not a default.

`gmm lp:` and `gmm iv:` are **alternatives** — one card carries one of them,
never both. Giving both is a `config/invalid` error naming both headers and the
line of the second one, instead of quietly keeping whichever came first.

**A stanza the command cannot use is refused, not ignored.** `dsge bayes` reads
`priors:` and refuses `constraints:`; `dsge solve` / `irf` / `steady-state` /
`perfect-foresight` read `constraints:` and refuse `priors:`. The error names
the stanza and the commands that can read it, so nothing is silently dropped.

### Where an option can go
1. **Inside `@dsge`** — model structure, on the equation or as a declaration.
2. **In a card line, or a repeatable flag** — `--prior 'name ~ dist(a, b)'`
   and `--constraint 'var[t] >= expr'` may each be given several times, and add
   to the matching stanza and TOML file. Those three sources are **one set**:
   the same prior or constraint in two of them is `config/invalid`, naming the
   parameter and both sources.
3. **On an existing run flag** — `--method`, `--order`, `--prior-scale`, and
   the rest of the run surface override nothing; they are the way to vary a
   setting between runs of the same model.
4. **As a file** — `--config <path>` is the only flag that takes a whole card,
   and only `estimate regression gmm`, `smm`, `sur` and `3sls` declare it
   (it carries `gmm lp:`, `gmm iv:`, `smm:`, `equations:` and `instruments:`).
   No `dsge` command takes `--config`: a `priors:` or `constraints:` card goes
   in the model file's preamble above the `@dsge` block, or on the command line
   with `--prior` / `--constraint`. `--constraints` reads TOML only.

Grammar: a prior is `name ~ dist(a, b)`; a constraint is `var[t] >= expr` or
`var[t] <= expr`. The two-sided form `lo <= var[t] <= hi` is accepted only by
`dsge perfect-foresight` and `dsge steady-state`; `dsge solve` and `dsge irf`
refuse it with `config/invalid`.
`gmm lp:` refuses `instruments`, `dep`, `endogenous`, `exogenous` and `theta0`;
the TOML form has no header, so it still infers IV-vs-LP from `dep` and `theta0`
together. An `@dsge constraint:` declaration inside a block is the
binding-regime marker on an equation, not an OccBin argument. Heterogeneous-agent
declarations (`heterogeneous:`, `idiosyncratic:`, `aggregation:`) have no card
header and no TOML section — they stay inside `@dsge`.

### Example

```bash
cat > model.jl <<'EOF'
priors:
  rho ~ beta(2, 2)
  sigma ~ inv_gamma(2, 0.5)

@dsge begin
    parameters: rho = 0.9, sigma = 0.01
    endogenous: Y
    exogenous: e
    linear: true

    Y[t] = rho * Y[t-1] + sigma * e[t]
end
EOF
friedman dsge bayes posterior-mode model.jl --data data.csv --params rho,sigma
```

The same two priors on the command line, or in a `[priors]` TOML file, with the
card stanza deleted:

```bash
friedman dsge bayes posterior-mode model.jl --data data.csv --params rho,sigma \
  --prior 'rho ~ beta(2, 2)' --prior 'sigma ~ inv_gamma(2, 0.5)'
```

Full per-family card reference: the `Model cards and TOML files` section of
the configuration page on the docs site.

---

## Leading globals

| Flag | Effect |
|------|--------|
| `--seed <int>` / `--seed=<int>` | seed the process RNG; forwarded as the estimator's own `seed=` where supported; echoed in `meta.seed` |
| `--quiet` / `-q` | suppress CLI status on stderr |
| `--no-color` | disable ANSI (also honors `NO_COLOR`) |
| `--json` | alias that appends `--format json` when the leaf declares `--format` and no explicit format was given |

Leading globals only (before the first subcommand token). A mid-argv `--quiet`,
`--seed`, or `--json` belongs to the leaf parser, not to the global pre-pass.

---

## Removed in v1.0

- `FRIEDMAN_LEGACY_OUTPUT` (pre-0.5 multi-document JSON): the variable is
  ignored; `--format json` always emits exactly one envelope.
- Hidden snake_case command aliases (7 total): use the kebab-case primaries;
  the old spellings are now unknown commands (exit 2).

---

## Handler rules (for contributors)

- Status/progress: `_status` / `_status_styled` (stderr), never bare `println` for status
- Data tables: `output_result` / `output_kv`; upstream-registered results go through the `_emit_result` router (`DataFrame(model)` / `long_table`), never a hand-build
- Typed failures: `throw(CliError("class/code", "message"; hint="…"))`

---

## References

- Per-leaf reference: the generated command pages under `commands/` on the docs
  site (same registry this guide describes; `friedman schema` exposes it
  machine-readably).
- Normative envelope schema: `schema/envelope-v1.json`.
- Exit-code taxonomy: `friedman schema | jq '.contract.exit_codes'`.
