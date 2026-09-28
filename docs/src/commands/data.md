# data

Manage data end to end: import CSV files and bundled example datasets into typed handles, simulate samples with known population truth, inspect, clean, transform, filter, validate, and subset. Each section below states behavior; the full flag surface with defaults and choices lives in the generated [data reference](generated/data.md).

---

## Typed handles and stems

The preferred unit of work is a MEMs typed container (`TimeSeriesData`, `PanelData`, `CrossSectionData`) persisted as a **stem** — pass `macro`, not `macro.jld2`. `.jld2` is storage. CSV input remains accepted wherever it was.

- **Load (data slots):** `macro.jld2` if it exists (preferred), else `macro.csv`, else the exact path. Explicit suffixes skip the search (`macro.csv` is always CSV). `--model` on typed leaves stem-resolves like `--result` (`var` → `var.jld2`, no CSV fallback). `model info` still wants `var.jld2` (or `.fmod` / `model://`).
- **Save:** a suffix-less `-o` / `--save-model` becomes `.jld2`. `data import … -o out.jld2` (or a stem) **is** the CSV → typed conversion. An **edit** of a CSV with `-o out.jld2` is `usage/invalid` (import first). Omitting `--save-model` means do not save (no default stem).
- **Wrong kind:** a handle whose type is not in the leaf's `data_kinds` is `data/wrong-kind` (exit 3) — e.g. a panel handle on `estimate multivariate var`, a raw CSV on `data export`, or `apply_tcode` on `CrossSectionData`.

| Input | `-o` | Writes |
|-------|------|--------|
| handle | omitted / stem | same type, default `*_clean.jld2` / `*_transformed.jld2` / … |
| handle | `out.csv` | CSV export; stderr warns metadata dropped |
| `.csv` | omitted / stem | CSV (today’s path, default `*_clean.csv`) |
| `.csv` edit | `out.jld2` | `usage/invalid` — run `data import` first |
| `data import` CSV | stem / `out.jld2` | typed handle (intended conversion) |

No implicit in-place overwrite. `data fix macro -o macro` is allowed (explicit same stem); stderr notes the replace. See [Architecture](../architecture.md) for the full pipeline.

Paths accept a leading `~` on every platform (expanded before resolution, since the REPL has no shell to do it). Confinement is opt-in: with `FRIEDMAN_DATA_ROOT` set, every input/output path is normalized and must resolve inside it, otherwise `data/bad-path` (exit 3); with the variable unset, normal filesystem access applies. `model://` session URIs are not filesystem paths and skip confinement.

`friedman show STEM` renders any loadable handle (data, model, or result). Data containers emit the same descriptive-stats table as `data describe`; bundles list keys only and are not unpacked. Stem resolution uses the result slot (`.jld2`, no CSV fallback).

---
## data simulate

Draw a sample and the population that generated it. Every leaf emits the same three tables:

| Table | Contents |
|-------|----------|
| `simulated_data` | Observables an estimator would read. Time series carry `time`; panels carry `id` and `time`; cross-sections carry `obs`. |
| `population_truth` | Population parameters, flattened to `parameter`, `row`, `col`, `value`. A scalar has `row = col = 0`. A vector uses `row`. A matrix uses `row` and `col`. A list of matrices is `A_1`, `A_2`, … |
| `simulation_settings` | `model`, the effective `seed`, and the kind or distribution. |

Leaf `--seed 0` defers to the global `--seed`. With neither set, the draw is `Xoshiro(0)`, so an unseeded call still reproduces. Structural shocks are not copied into the truth table; the seed reproduces them. Conditional variances `h` are included for the volatility leaves, because that is the latent series a volatility estimator recovers.

| Leaf | What it draws |
|------|---------------|
| `var` | Reference stationary VAR(1); truth reports `A_1`, `B0`, `Sigma`, `c` |
| `svar` | Non-Gaussian SVAR with independent structural shocks (`--dist`, `--nu`) |
| `heteroskedastic-var` | Heteroskedastic SVAR: Markov, GARCH, smooth, or break (`--kind`) |
| `arima` | Gaussian ARIMA with optional seasonal AR/MA left at zero |
| `garch` | GARCH-family returns; the `h` path is in the truth table |
| `sv` | Stochastic volatility (Gaussian, no leverage) |
| `vecm` | Rank-1 VECM; truth reports `alpha`, `beta`, `Gamma`, `Sigma` |
| `cointreg` | Cointegrating regression with endogenous regressors; `--spurious` draws independent random walks instead |
| `ardl` | ARDL(1,1); truth reports `phi`, `beta`, and the long-run multiplier `theta` |
| `factors` | Dynamic factor model (VAR factors, random loadings) |
| `lp-iv` | Local-projection IV (instrument `z`, endogenous `s`, outcome `y`) |
| `panel` | Linear or binary panel with optional correlated effects |
| `pvar` | Panel VAR(1) with random effects |
| `did` | Staggered adoption with the realized ATT (`overall_att`, `att_e:`, `att_c:`). Cohorts follow the upstream dates 6, 11, and 16, keeping only dates that fall inside the sample; a shorter panel gets a single in-sample date. A non-finite ATT is left out of `population_truth`. |
| `gmm` | Heteroskedastic OLS or IV moments |
| `regime` | Markov-switching, SETAR, LSTAR, or ESTAR |
| `cross-section` | Cross-section DGP from OLS through RDD |
| `dsge MODEL` | Representative-agent path (`.jl` or `.toml`). `--meas-sd` adds Gaussian measurement error; the truth table records the standard deviations. |
| `ha MODEL` | Heterogeneous-agent aggregate **deviations** (`--method ssj` or `reiter`). Steady-state levels are `ss_agg:*` and `ss_price:*` in the truth table. |
| `olg` | Blanchard perpetual-youth saddle path. Deterministic; the truth table holds the steady state. |
| `ct` | Continuous-time Aiyagari MIT transition after an initial TFP shock. |

DSGE-family leaves have no fixed DGP: they solve the model and call MEMs `simulate`. `--order` applies only to `dsge --method perturbation` (any other combination is `usage/invalid`). `ha --method krusell-smith` has no aggregate path (`usage/invalid`). Keep the `ct` solver grid at its default: coarsened grids have failed to converge on some platforms while passing on others, which no single-machine check catches. The DSGE-family leaves need a model spec file, so the runnable examples below use the fixed DGPs.

```bash
friedman data simulate var --periods 200 --burn 50 --seed 7 --format json
friedman data simulate arima --periods 200 --seed 7 --format json
friedman data simulate garch --periods 300 --seed 7 --format json
```

---
## data list

List available example datasets.

```bash
friedman data list
```

The set is fixed in `src/io.jl` (`EXAMPLE_DATASETS`) and every dataset surface derives from it. The `wiot` input-output table is not listed here: it is an `IOData` archive with no rectangular `data`/`varnames`, served by the [`io`](io.md) family instead.

!!! warning "NaN-padded series: NaN is not zero"
    `mp_shocks` (quarterly) keeps each policy-shock series `NaN` outside its published sample. Loading preserves the `NaN` cells — zero is a valid shock value, so they are never zero-filled. Use `data describe` to see each column's valid window (`first_valid`/`last_valid`), then `data dropna --vars ...` or `data keeprows --rows ...` to cut a finite sample before estimation.

### Referring to a dataset

Every command that takes a `<data>` path also accepts a `:name` reference to a bundled dataset, and both separator spellings resolve to the same set:

```bash
friedman data describe :fred_md      # equivalently :fred-md, fred_md, fred-md
friedman test unit-root cips :grunfeld --id-col=group --time-col=time
```

An unknown name is `data/unknown-dataset` (exit 3) with a nearest-match hint; `:wiot` points at the `io` family. Panel datasets expose their identifiers as leading `group` and `time` columns, so panel commands bind `--id-col`/`--time-col` directly to a bundled panel. The REPL resolves the same references (`data use :fred_md`, underscore canonical) through one code path, so builtins and files behave identically.

---
## data load

Load an example dataset or CSV file and export.

```bash
# Named example datasets
friedman data load fred_md --output=macro_tmp.csv
friedman data load fred_md --vars=INDPRO,CPIAUCSL,FEDFUNDS --output=macro_sub_tmp.csv
friedman data load pwt --country=USA --output=us_data_tmp.csv
friedman data load :fred-md --output=macro_tmp.csv     # ':' reference also accepted
```

```bash
# From a CSV file — write one first, then load it by path
friedman data load :nile --output=nile_tmp.csv
friedman data load --path=nile_tmp.csv
```

Give either a dataset `<name>` or `--path`; supplying neither is a usage error. When both are given, `--path` wins and a note is written to stderr. `--vars` subsets columns (unknown names are `data/column-range`); `--country` filters the PWT panel. `--transform` applies FRED transformation codes, which a cross-section dataset does not have (`usage/invalid`); `--dates` takes effect for time-series data only.

A blank line in a single-column CSV is an empty row that the CSV reader skips, so the series comes back shorter — not a `missing` cell. A genuine missing value needs a multi-column row with one empty cell; those are rejected before numeric conversion and surface as typed `data/missing-values` at estimation time, or cut them first with `data dropna`.

---
## data import

Import a CSV or a bundled `:example` dataset to a typed `.jld2` handle (`TimeSeriesData`, `PanelData`, or `CrossSectionData`). `--kind` is required for CSV and optional for `:example` (inferred; a mismatch is `data/wrong-kind`). Import reads CSV or `:example`, never an existing handle — re-importing a handle is `usage/invalid`.

```bash
friedman data import :fred_md -o fred_md_demo
friedman data import :grunfeld -o grunfeld_demo
friedman data import :stackloss -o stackloss_demo
```

```bash
# CSV imports need --kind; panel CSVs also need --id-col/--time-col
friedman data load :nile --output=nile_tmp.csv
friedman data import nile_tmp.csv --kind timeseries -o nile_demo
```

```bash
friedman data load :grunfeld --output=grunfeld_tmp.csv
friedman data import grunfeld_tmp.csv --kind panel --id-col group --time-col time -o grunfeld_csv_demo
```

Panel import requires `--id-col` and `--time-col`. `--frequency` does not apply to `--kind cross-section` (`usage/invalid`), and the same holds for `--transform` at load time and `data transform` on a `CrossSectionData` handle (`data/wrong-kind`). Identifier and label columns are metadata, not variables: `--id-col`, `--time-col`, and `--dates` are excluded from the stored variable set. Columns with missing cells are rejected (`data/missing-values`) — drop or impute them first.

Default `-o` is the input basename next to the source (or `fred_md.jld2` for `:fred_md`). A suffix-less stem becomes `.jld2`.

The stem flow carries into estimation: import once, then pass the stem wherever a data path is accepted.

<!-- capture -->
```bash
friedman data import :stackloss -o stackloss_demo --format json
friedman estimate regression robust stackloss_demo
```
```json
{
    "schema_version": 1,
    "data": {
        "imported_data": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "kind",
                    "cross_section"
                ],
                [
                    "n_obs",
                    21
                ],
                [
                    "n_vars",
                    4
                ],
                [
                    "path",
                    "stackloss_demo.jld2"
                ],
                [
                    "frequency",
                    "other"
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman data import",
    "meta": {
    },
    "error": null
}
```

**Output table:** `imported_data` — `kind`, `n_obs`, `n_vars`, `path`, `frequency`.

---
## data export

Write a typed handle to CSV (the inverse of `data import`). Panel handles include `group`/`time` columns. Frequency, tcode, and dates are dropped (stderr note). Input must be a data container (`TimeSeriesData` / `PanelData` / `CrossSectionData`); a raw CSV is `data/wrong-kind`.

```bash
friedman data import :fred_md -o fred_md_demo
friedman data export fred_md_demo -o fred_md_tmp.csv
```

```bash
friedman data import :grunfeld -o grunfeld_demo
friedman data export grunfeld_demo
```

Default `-o` is `<stem>.csv` next to the handle.

No envelope table — writes the CSV directly.

---
## data describe

Summary statistics for a dataset. Accepts a CSV path, a `:example` name, or a typed handle stem. A `PanelData` handle is described as panel data (not wrapped as `TimeSeriesData`).

```bash
friedman data describe :stackloss
friedman data describe :denmark
```

```bash
friedman data import :grunfeld -o grunfeld_demo
friedman data describe grunfeld_demo
```

<!-- capture -->
```bash
friedman data describe :stackloss --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "descriptive_statistics": {
            "columns": [
                "variable",
                "n",
                "first_valid",
                "last_valid",
                "mean",
                "std",
                "min",
                "p25",
                "median",
                "p75",
                "max",
                "skewness",
                "kurtosis"
            ],
            "rows": [
                [
                    "Air.Flow",
                    21,
                    1,
                    21,
                    60.4286,
                    9.1683,
                    50,
                    56,
                    58,
                    62,
                    80,
                    0.8736,
                    0.0218
                ],
                [
                    "Water.Temp",
                    21,
                    1,
                    21,
                    21.0952,
                    3.1608,
                    17,
                    18,
                    20,
                    24,
                    27,
                    0.5044,
                    -1.0503
                ],
                [
                    "Acid.Conc.",
                    21,
                    1,
                    21,
                    86.2857,
                    5.3586,
                    72,
                    82,
                    87,
                    89,
                    93,
                    -0.9392,
                    0.5165
                ],
                [
                    "stack.loss",
                    21,
                    1,
                    21,
                    17.5238,
                    10.1716,
                    7,
                    11,
                    15,
                    19,
                    42,
                    1.2442,
                    0.4556
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman data describe",
    "meta": {
    },
    "error": null
}
```

**Output:** per variable, `n` counts finite observations and every statistic excludes NaN and Inf; `first_valid`/`last_valid` are the row indices of the first and last finite value (0 if none), which locate the usable window of NaN-padded series such as the `mp_shocks` shock columns.

---
## data diagnose

Data quality diagnostics. Same inputs as `data describe` (CSV, `:example`, or typed handle).

```bash
friedman data diagnose :stackloss
friedman data diagnose :mp_shocks
```

```bash
friedman data import :denmark -o denmark_demo
friedman data diagnose denmark_demo
```

**Output:** per variable, NaN count, Inf count, and constant-series flag, plus a colored verdict (clean / issues found).

---
## data fix

Clean data by handling NaN, Inf, and constant columns. A typed handle is cleaned in place as the same type (`*_clean.jld2` by default). CSV input still writes CSV; CSV `-o out.jld2` is `usage/invalid` (run `data import` first). Handle `-o out.csv` writes CSV and notes that metadata was dropped.

```bash
friedman data fix :denmark --method=listwise
friedman data fix :denmark --method=interpolate --output=denmark_clean_tmp.csv
friedman data fix :denmark --method=mean
```

```bash
friedman data import :denmark -o denmark_demo
friedman data fix denmark_demo --method=listwise -o denmark_clean_demo
```

---
## data transform

Apply FRED transformation codes. One code per variable; the count must match the variable count (`usage/invalid` otherwise). Codes outside 1–7 are `usage/invalid`.

```bash
friedman data transform :denmark --tcodes=5,5,1,6,1
```

```bash
friedman data import :denmark -o denmark_demo
friedman data transform denmark_demo --tcodes=5,5,1,6,1 -o denmark_tcode_demo
```

| Code | Transformation |
|------|---------------|
| 1 | Level (no transformation) |
| 2 | First difference |
| 3 | Second difference |
| 4 | Log |
| 5 | First difference of log |
| 6 | Second difference of log |
| 7 | First difference of percent change |

`apply_tcode` is defined for time-series and panel data only. A `CrossSectionData` handle is `data/wrong-kind`.

---
## data filter

Apply a time series filter (unified interface over `hp`, `hamilton`, `bn`, `bk`, and `bhp`). Only time-series data qualifies: a panel handle is `data/wrong-kind`.

```bash
friedman data filter :nile --method=hp --component=cycle
friedman data filter :nile --method=hamilton --horizon=8 --lags=4
friedman data filter :nile --method=bn --columns=1
```

---
## data validate

Validate data suitability for a model type. `--model` is a **model-type string** (`var`, `arima`, …), not a saved-model handle.

```bash
friedman data validate :denmark --model=var
friedman data validate :nile --model=garch
```

```bash
friedman data import :denmark -o denmark_demo
friedman data validate denmark_demo --model=var
```

The verdict prints to stderr; no envelope table is emitted.

---
## data balance

Balance a panel dataset with missing observations via DFM imputation.

```bash
friedman data balance :grunfeld --factors=3 --lags=2
friedman data balance :grunfeld --output=grunfeld_balanced_tmp.csv
```

**Output:** balanced panel with imputed values (envelope table `balanced_panel`). Also persists the cleaned object (`*_balanced.jld2` from a handle, `*_balanced.csv` from CSV).

---
## data dropna

Drop all rows containing NaN or missing values from a dataset.

```bash
friedman data dropna :mp_shocks
friedman data dropna :mp_shocks --output=mp_shocks_clean_tmp.csv
friedman data dropna :mp_shocks --vars=ygap,infl,ffr   # check only these columns
```

With `--vars`, only the listed columns are checked for NaN/Inf (a row with NaN in an *unlisted* column is kept). This is the prep step for NaN-padded datasets like `mp_shocks`: subset the variables of interest, drop their jointly-invalid rows, and estimate on the result. An unknown column name is `data/column-range`; if every row contains NaN/Inf the command fails with `data/invalid` rather than emitting an empty dataset.

**Output:** cleaned dataset with missing rows removed, plus a summary of rows dropped (envelope table `cleaned_data`). Also persists the cleaned object (`*_dropna.jld2` from a handle, `*_dropna.csv` from CSV).

---
## data keeprows

Keep only rows at the given index positions (range or comma-separated list). `--rows` is required; `end` binds to the last row.

```bash
friedman data keeprows :nile --rows=1:100
friedman data keeprows :nile --rows=1,5,10 --output=nile_sub_tmp.csv
```

Out-of-range or unparseable selections are `usage/invalid`.

**Output:** filtered dataset containing only the selected rows (envelope table `filtered_data`). Also persists the selected object (`*_rows.jld2` from a handle, `*_rows.csv` from CSV).

---
## References

- Generated [data reference](generated/data.md) — full flag surface, defaults, choices, and envelope tables for every `data` leaf
- [Input-output (`io`)](io.md) — the `wiot` table and input-output analysis
- [Architecture](../architecture.md) — handles, stems, and the save/load pipeline
- [Agent guide](../agent-guide.md) — envelope contract, exit codes, and machine use
