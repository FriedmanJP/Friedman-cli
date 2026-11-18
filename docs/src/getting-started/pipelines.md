# [Pipelines, Handles & Reproducibility](@id gs-pipelines)

Friedman-cli passes typed econometric containers between commands using on-disk handles (`.jld2`, `.jls`, or `.fmod`) or in-memory `model://` / `result://` handles inside `serve --mcp` sessions. Chaining commands via `--save-model` and `--model` avoids redundant estimation while preserving frequency metadata, date labels, transformation codes, and reproducibility manifests.

## Typed Handles & Formats

Three handle roles govern the CLI boundary:

| Role | CLI Slot | Persistence Formats | Inspection Commands |
|---|---|---|---|
| Data | Positional `<data>` | `.csv`, `.jld2` (via `data import -o STEM`), `.jls`, `:example` | `data describe`, `show <stem>` |
| Model | `--save-model` / `--model` (or positional shorthand) | `.jld2` (native HDF5/JLD2), `.jls`, `.fmod` (interim) | [`model info`](@ref ref-model-info), `show <stem>` |
| Result | `--save-result` / `--result` | `.jld2`, `.jls`, `.fmod` | `show <stem>`, [`model reproduce`](@ref ref-model-reproduce) |

When resolving a bare stem `STEM`, Friedman-cli checks `STEM.jld2`, then `STEM.jls`, then `STEM.fmod`, and finally `STEM.csv` (matching the order documented in [Architecture & Internals](@ref int-architecture)). Any builtin example dataset can be passed directly with a leading colon (`:denmark`, `:fred_qd`, `:pwt`, `:mpdta`, etc.) or materialized into a typed handle with [`friedman data import`](@ref ref-data-import).

If you pass a saved handle directly as the positional argument to `friedman show <path>` ([`show`](@ref ref-show)), or omit `--model` when passing a model stem to post-estimation verbs such as `irf`, `fevd`, `hd`, `forecast`, `predict`, or `residuals`, the router automatically binds the loaded object into `--model` or `--result` without re-estimating.

---

## End-to-End Pipeline Example (Table Output)

The workflow below imports `:denmark` (55 quarterly observations across `LRM`, `LRY`, `LPY`, `IBO`, `IDE`), fits a seeded `VAR(2)` saving `var_fit.jld2`, inspects handle metadata with [`friedman model info`](@ref ref-model-info), and computes Cholesky impulse responses without re-fitting the VAR:

<!-- capture -->
```bash
friedman --quiet data import :denmark -o macro
friedman --seed 42 --quiet estimate multivariate var macro --lags 2 --save-model var_fit
friedman --quiet model info var_fit.jld2
friedman irf var --model var_fit.jld2 --horizons 4 --shock 1 --ci none
```
```text
             IRF to LRM shock (cholesky identification)
┌─────────┬──────────┬────────┬──────────────┬──────────┬──────────┐
│ horizon │ variable │ shock  │    value     │  lower   │  upper   │
│  Int64  │  String  │ String │   Float64    │ Float64? │ Float64? │
├─────────┼──────────┼────────┼──────────────┼──────────┼──────────┤
│    1    │   LRM    │  LRM   │  0.0211523   │ missing  │ missing  │
│    1    │   LRY    │  LRM   │  0.00867905  │ missing  │ missing  │
│    1    │   LPY    │  LRM   │ -0.00301527  │ missing  │ missing  │
│    1    │   IBO    │  LRM   │ -0.00275231  │ missing  │ missing  │
│    1    │   IDE    │  LRM   │ -0.000271827 │ missing  │ missing  │
│    2    │   LRM    │  LRM   │  0.0125777   │ missing  │ missing  │
│    2    │   LRY    │  LRM   │  0.0111191   │ missing  │ missing  │
│    2    │   LPY    │  LRM   │ -0.00343509  │ missing  │ missing  │
│    2    │   IBO    │  LRM   │ -0.00214358  │ missing  │ missing  │
│    2    │   IDE    │  LRM   │ -0.000878119 │ missing  │ missing  │
│    3    │   LRM    │  LRM   │  0.0143858   │ missing  │ missing  │
│    3    │   LRY    │  LRM   │  0.0067444   │ missing  │ missing  │
│    3    │   LPY    │  LRM   │  -0.0032946  │ missing  │ missing  │
│    3    │   IBO    │  LRM   │ -0.00134605  │ missing  │ missing  │
│    ⋮    │    ⋮     │   ⋮    │      ⋮       │    ⋮     │    ⋮     │
└─────────┴──────────┴────────┴──────────────┴──────────┴──────────┘
                                                      6 rows omitted
```3858   │ missing  │ missing  │
│    3    │   LRY    │  LRM   │  0.0067444   │ missing  │ missing  │
│    3    │   LPY    │  LRM   │  -0.0032946  │ missing  │ missing  │
│    3    │   IBO    │  LRM   │ -0.00134605  │ missing  │ missing  │
│    ⋮    │    ⋮     │   ⋮    │      ⋮       │    ⋮     │    ⋮     │
└─────────┴──────────┴────────┴──────────────┴──────────┴──────────┘
                                                      6 rows omitted
```

At horizon `1`, a one-standard-deviation Cholesky shock to `LRM` raises `LRM` by `0.0211523` and `LRY` by `0.00867905` while lowering `IBO` by `-0.00275231`. Chaining `--save-model` to `--model` skips OLS estimation during `irf`, guarantees the exact same lag structure and covariance matrix across `irf`, `fevd`, `hd`, and `forecast` (JSON key `irf`), and accepts `-f json` or `-f csv` identically on every leaf.

---

## Reproducibility & JSON Envelopes

Under `--seed <int>` (a **leading global** placed before the subcommand), Friedman-cli seeds the process RNG, forwards `seed=` to stochastic estimators, records `meta.seed` and `meta.manifest` (package versions, thread count, OS, git state, and RNG seed) in both native `.jld2` handles and JSON output, and allows bit-for-bit verification with [`friedman model reproduce`](@ref ref-model-reproduce).

Every command emitting `--format json` (or leading `--json`) produces exactly **one JSON object on stdout** while keeping progress messages on **stderr**. The example below extracts two variables (`LRM`, `LRY`) from `denmark` and emits the complete JSON v1 envelope for a `VAR(1)`:

<!-- capture -->
```bash
friedman --quiet data load denmark --vars LRM,LRY -o tiny.csv
friedman --seed 42 --json estimate multivariate var tiny.csv --lags 1
```
```json
{
  "artifacts": [],
  "command": "friedman estimate multivariate var",
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
        ["LRM", "(Intercept)", 0.22484791, 0.36958612, 0.60837758, 0.54563721, -0.51712719, 0.96682301],
        ["LRM", "LRM.L1", 1.0767316, 0.058551789, 18.389388, 0, 0.95918394, 1.1942792],
        ["LRM", "LRY.L1", -0.1881037, 0.12128629, -1.5509066, 0.12710806, -0.43159608, 0.055388684],
        ["LRY", "(Intercept)", 0.15830798, 0.2675591, 0.59167481, 0.55668216, -0.37883932, 0.69545528],
        ["LRY", "LRM.L1", 0.12027868, 0.042388128, 2.8375559, 0.0065080586, 0.035180964, 0.2053764],
        ["LRY", "LRY.L1", 0.73636016, 0.087804296, 8.3863796, 3.6341818e-11, 0.56008568, 0.91263464]
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

- Full JSON envelope schema, error codes (`model/convergence`, `data/wrong-kind`, etc.), and `friedman serve --mcp`: [Agent Guide](../agent-guide.md)
- Machine-readable draft-07 per-leaf schemas: `friedman schema <verb> [<family>] <model>`
- Handle inspection and verification: [`friedman model`](@ref ref-model), [`friedman show`](@ref ref-show)
