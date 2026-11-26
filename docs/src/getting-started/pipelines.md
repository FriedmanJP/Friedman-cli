# [Pipelines, Handles & Reproducibility](@id gs-pipelines)

Friedman-cli passes typed econometric containers between commands using on-disk handles (`.jld2`, `.jls`, or `.fmod`) or in-memory `model://` / `result://` handles inside `serve --mcp` sessions. Chaining commands via `--save-model` and `--model` avoids redundant estimation while preserving frequency metadata, date labels, transformation codes, and reproducibility manifests.

## Typed Handles & Formats

Three handle roles govern the CLI boundary:

| Role | CLI Slot | Persistence Formats | Inspection Commands |
|---|---|---|---|
| Data | Positional `<data>` | `.csv`, `.jld2` (via `data import -o STEM`), `.jls`, `:example` | `data describe`, `show <stem>` |
| Model | `--save-model` / `--model` (or positional shorthand) | `.jld2` (native HDF5/JLD2), `.jls`, `.fmod` (interim) | [`model info`](@ref ref-model-info), `show <stem>` |
| Result | `--save-result` / `--result` | `.jld2`, `.jls`, `.fmod` | `show <stem>`, [`model reproduce`](@ref ref-model-reproduce) |

When resolving a bare stem `STEM`, Friedman-cli checks `STEM.jld2`, then `STEM.jls`, then `STEM.fmod`, and finally `STEM.csv` (matching the order documented in [Architecture & Internals](@ref int-architecture)). Any builtin example dataset can be passed directly with a leading colon (`:denmark`, `:fred_qd`, `:pwt`, `:mpdta`, etc.) or materialized into a typed handle with [`frdc data import`](@ref ref-data-import).

If you pass a saved handle directly as the positional argument to `frdc show <path>` ([`show`](@ref ref-show)), or omit `--model` when passing a model stem to post-estimation verbs such as `irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`, `dsge abcd`/`dsge var`, or `ri`, the router automatically binds the loaded object into `--model` or `--result` without re-estimating. Metadata inspection (`--help`, `schema`, `completions`, `data list`, `io sources`) and MCP `initialize`/`tools/list` discovery are served in **< 10 ms** by the native thin wrapper before spawning the Julia core only on compute calls (`FRDC_NO_FASTPATH=1` bypasses directly to `frdc-core`).

---

## End-to-End Pipeline Example (Table Output)

The workflow below imports `:denmark` (55 quarterly observations across `LRM`, `LRY`, `LPY`, `IBO`, `IDE`), fits a seeded `VAR(2)` saving `var_fit.jld2`, inspects handle metadata with [`frdc model info`](@ref ref-model-info), and computes Cholesky impulse responses without re-fitting the VAR:

<!-- capture -->
```bash
frdc --quiet data import :denmark -o macro
frdc --seed 42 --quiet estimate multivariate var macro --lags 2 --save-model var_fit
frdc --quiet model info var_fit.jld2
frdc irf var --model var_fit.jld2 --horizons 4 --shock 1 --ci none
```
```text
        IRF to LRM shock (cholesky identification)
┌─────────┬──────────┬───────┬────────┬─────────┬─────────┐
│ horizon │ variable │ shock │ value  │  lower  │  upper  │
├─────────┼──────────┼───────┼────────┼─────────┼─────────┤
│    1    │   LRM    │  LRM  │ 0.021  │ missing │ missing │
│    1    │   LRY    │  LRM  │ 0.009  │ missing │ missing │
│    1    │   LPY    │  LRM  │ -0.003 │ missing │ missing │
│    1    │   IBO    │  LRM  │ -0.003 │ missing │ missing │
│    1    │   IDE    │  LRM  │ 0.000  │ missing │ missing │
│    2    │   LRM    │  LRM  │ 0.013  │ missing │ missing │
│    2    │   LRY    │  LRM  │ 0.011  │ missing │ missing │
│    2    │   LPY    │  LRM  │ -0.003 │ missing │ missing │
│    2    │   IBO    │  LRM  │ -0.002 │ missing │ missing │
│    2    │   IDE    │  LRM  │ -0.001 │ missing │ missing │
│    3    │   LRM    │  LRM  │ 0.014  │ missing │ missing │
│    3    │   LRY    │  LRM  │ 0.007  │ missing │ missing │
│    3    │   LPY    │  LRM  │ -0.003 │ missing │ missing │
│    3    │   IBO    │  LRM  │ -0.001 │ missing │ missing │
│    3    │   IDE    │  LRM  │ -0.001 │ missing │ missing │
│    4    │   LRM    │  LRM  │ 0.010  │ missing │ missing │
│    4    │   LRY    │  LRM  │ 0.006  │ missing │ missing │
│    4    │   LPY    │  LRM  │ -0.003 │ missing │ missing │
│    4    │   IBO    │  LRM  │ -0.001 │ missing │ missing │
│    4    │   IDE    │  LRM  │ -0.001 │ missing │ missing │
└─────────┴──────────┴───────┴────────┴─────────┴─────────┘
```

At horizon `1`, a one-standard-deviation Cholesky shock to `LRM` raises `LRM` by `0.021` and `LRY` by `0.009` while lowering `IBO` by `-0.003` (displayed at 3 decimal places; `--format json` and `--format csv` preserve full IEEE-754 precision). Chaining `--save-model` to `--model` skips OLS estimation during `irf`, guarantees the exact same lag structure and covariance matrix across `irf`, `fevd`, `hd`, and `forecast` (JSON key `irf`), and accepts `-f json` or `-f csv` identically on every leaf.

---

## Reproducibility, Precision & JSON Envelopes

Under `--seed <int>`, Friedman-cli seeds the process RNG, forwards `seed=` to stochastic estimators, records `meta.seed` and `meta.manifest` (package versions, thread count, OS, git state, and RNG seed) in both native `.jld2` handles and JSON output, and allows bit-for-bit verification with [`frdc model reproduce`](@ref ref-model-reproduce).

Human `--format table` output applies a presentation-only 3-decimal formatter by default (override per call with `--digits <0..16|full>` or globally with `FRDC_DIGITS`), whereas `--format json` (`-J`), `--format csv`, MCP tool responses, and saved `.jld2`/`.jls` handles always persist **exact unrounded IEEE-754 `Float64`** values. For automated pipelines and archiving, prefer `--format json`, `--format csv`, or `.jld2` handles rather than scraping formatted table text.

Every command emitting `--format json` (or `--json` / `-J`) produces exactly **one JSON object on stdout** while keeping progress messages on **stderr**. The example below extracts two variables (`LRM`, `LRY`) from `denmark` and emits the complete JSON v1 envelope for a `VAR(1)`:

<!-- capture -->
```bash
frdc --quiet data load denmark --vars LRM,LRY -o tiny.csv
frdc --seed 42 --json estimate multivariate var tiny.csv --lags 1
```
```json
{
  "artifacts": [],
  "command": "frdc estimate multivariate var",
  "data": {
    "information_criteria": {
      "columns": ["metric", "value"],
      "rows": [
        ["AIC", -14.41023],
        ["BIC", -14.189232],
        ["HQC", -14.325],
        ["Log-likelihood", 241.83086]
      ]
    },
    "var_coefficients": {
      "columns": ["equation", "term", "estimate", "std_error", "stat", "p_value", "ci_lower", "ci_upper"],
      "rows": [
        ["LRM", "(Intercept)", 0.22484791, 0.36958612, 0.60837758, 0.54563721, -0.14630839, 0.59600421],
        ["LRM", "LRM.L1", 1.0767316, 0.058551789, 18.389388, 0, 1.017931, 1.1355321],
        ["LRM", "LRY.L1", -0.1881037, 0.12128629, -1.5509066, 0.12710806, -0.30990527, -0.066302128],
        ["LRY", "(Intercept)", 0.15830798, 0.2675591, 0.59167481, 0.55668216, -0.11038784, 0.42700379],
        ["LRY", "LRM.L1", 0.12027868, 0.042388128, 2.8375559, 0.0065080586, 0.077710468, 0.16284689],
        ["LRY", "LRY.L1", 0.73636016, 0.087804296, 8.3863796, 3.6341818e-11, 0.64818283, 0.82453749]
      ]
    }
  },
  "error": null,
  "meta": {},
  "schema_version": 1,
  "status": "ok",
  "warnings": []
}
```

In the captured `VAR(1)` fit, `information_criteria` records `AIC = -14.41023` and `BIC = -14.189232`, while `var_coefficients` estimates an own-lag coefficient of `1.0767316` on `LRM.L1` in the `LRM` equation. Automated scripts and MCP tools rely on this guaranteed top-level envelope shape (`schema_version`, `status`, `command`, `data`, and `meta`), stable table keys documented per leaf in the [CLI Reference Overview](@ref cli-overview), and typed exit codes detailed in the [Agent Guide](../agent-guide.md).

---

## See Also

- Full JSON envelope schema, error codes (`model/convergence`, `data/wrong-kind`, etc.), and `frdc serve --mcp`: [Agent Guide](../agent-guide.md)
- Four-layer storage contract (`.jld2`/`.jls`/`.fmod`, `#key`, `data://`/`model://`/`result://`/`mem://`, atomic writes, `FRDC_DATA_ROOT`): [Storage & Handle Architecture](@ref int-storage)
- Machine-readable draft-07 per-leaf schemas: `frdc schema <verb> [<family>] <model>`
- Handle inspection, key listing, conversion, and verification: [`frdc model`](@ref ref-model), [`frdc show`](@ref ref-show)
