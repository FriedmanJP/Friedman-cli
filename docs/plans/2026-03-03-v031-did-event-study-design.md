# v0.3.1 Design: DID & Event Study LP Commands

Wraps MacroEconometricModels.jl v0.3.2 DID and event study LP features.

## Command Tree

```
friedman did
├── estimate <data>      # DID estimation (--method=twfe|cs|sa|bjs|dcdh)
│   --outcome, --treatment, --id-col, --time-col
│   --method (default: twfe), --leads, --horizon, --covariates
│   --control-group (never_treated|not_yet_treated), --cluster (unit|time|twoway)
│   --conf-level, --n-boot, --format, --output, --plot, --plot-save
│
├── event-study <data>   # Panel event study LP (Jorda 2005 + panel FE)
│   --outcome, --treatment, --id-col, --time-col
│   --leads (default: 3), --horizon (default: 5), --lags (default: 4)
│   --covariates, --cluster, --conf-level
│   --format, --output, --plot, --plot-save
│
├── lp-did <data>        # LP-DiD with clean controls (Dube et al. 2023)
│   (same options as event-study)
│
└── test                 # Diagnostics
    ├── bacon <data>       # Bacon decomposition (Goodman-Bacon 2021)
    │   --outcome, --treatment, --id-col, --time-col
    │   --format, --output, --plot, --plot-save
    │
    ├── pretrend <data>    # Pre-trend F-test
    │   --outcome, --treatment, --id-col, --time-col
    │   --leads, --horizon, --lags, --cluster, --conf-level
    │   --method (did|event-study), --did-method (twfe|cs|sa|bjs|dcdh)
    │   --format, --output
    │
    ├── negweight <data>   # Negative weight check (dCDH 2020)
    │   --treatment, --id-col, --time-col
    │   --format, --output
    │
    └── honest <data>      # HonestDiD sensitivity (Rambachan-Roth 2023)
        --outcome, --treatment, --id-col, --time-col
        --mbar (default: 1.0), --leads, --horizon, --lags, --cluster, --conf-level
        --method (did|event-study), --did-method (twfe|cs|sa|bjs|dcdh)
        --format, --output, --plot, --plot-save
```

## Architecture

### Approach: Single file + shared helper

- New file `src/commands/did.jl` (~500-600 lines) with `register_did_commands!()`
- Small `_load_panel_for_did()` helper in shared.jl
- Follows `dsge.jl` pattern (nested NodeCommand with leaves)

### Handler naming

`_did_estimate`, `_did_event_study`, `_did_lp_did`, `_did_test_bacon`, `_did_test_pretrend`, `_did_test_negweight`, `_did_test_honest`

### Data flow

```
CSV → load_panel_data(data, id_col, time_col) → PanelData
    → MEMs function (estimate_did / estimate_event_study_lp / ...)
    → Build DataFrame from result fields
    → output_result(df; format, output, title)
    → _maybe_plot(result; plot, plot_save)
```

### Output tables

- **estimate**: `Event_Time | ATT | SE | CI_Lower | CI_Upper` + overall ATT row. CS method also outputs group-time ATT matrix.
- **event-study / lp-did**: `Event_Time | Coefficient | SE | CI_Lower | CI_Upper`
- **bacon**: `Comparison_Type | Cohort_i | Cohort_j | Estimate | Weight`
- **pretrend**: Key-value via `output_kv` (F-stat, p-value, df, verdict)
- **negweight**: Key-value (has_negative_weights, n_negative, total_negative_weight) + optional weights table
- **honest**: `Event_Time | ATT | Robust_CI_Lower | Robust_CI_Upper | Original_CI_Lower | Original_CI_Upper` + breakdown value

### Plotting

All commands support `--plot`/`--plot-save`:
- estimate/event-study/lp-did: event study coefficient plots with CIs
- bacon: weight decomposition plot
- honest: sensitivity plot

## File Changes

### New
- `src/commands/did.jl` (~500-600 lines)

### Modified
1. `src/Friedman.jl` — include did.jl, register in build_app(), bump FRIEDMAN_VERSION to "0.3.1"
2. `src/commands/shared.jl` — add `_load_panel_for_did()` helper
3. `src/cli/types.jl` — bump Entry default version to "0.3.1"
4. `Project.toml` — version 0.3.1, MEMs compat 0.3.2
5. `test/mocks.jl` — 7 mock types + 8 mock functions
6. `test/test_commands.jl` — DID handler tests (~200-250 lines)
7. `test/runtests.jl` — DID CLI structure tests (~40-50 lines)

### Include order
`shared.jl` → ... → `dsge.jl` → `did.jl` → `nowcast.jl`

## Testing

### Mock types
DIDResult, EventStudyLP, BaconDecomposition, PretrendTestResult, NegativeWeightResult, HonestDiDResult

### Mock functions
estimate_did, estimate_event_study_lp, estimate_lp_did, bacon_decomposition, pretrend_test (2 dispatches), negative_weight_check, honest_did (2 dispatches)

### Test coverage
- Handler tests: each method path for estimate, event-study, lp-did, all 4 diagnostics
- CLI structure tests: verify command tree, options, flags, args on each leaf

## Version
- Friedman-cli: 0.3.0 → 0.3.1
- MEMs compat: 0.3.1 → 0.3.2
- Commands: 12 → 13 top-level, ~117 → ~124 subcommands
