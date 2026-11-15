# [Data Management & Simulation](@id chap-data)

Every empirical pipeline begins with typed containers (`:timeseries`, `:panel`, `:cross_section`) imported from raw CSVs, loaded from bundled macroeconomic and microeconometric benchmarks, cleaned or filtered via [`friedman data`](@ref ref-data), or generated with known ground-truth parameters under the 21 structural and reduced-form DGP simulators in [`friedman data simulate`](@ref ref-data). See the upstream [Data Management manual](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/data/) in `MacroEconometricModels.jl` for underlying container types.

## Quick Start

List bundled benchmark datasets, import `:denmark` into a typed native `.jld2` handle with frequency metadata intact, inspect per-variable moments, and check stationarity/missingness before modeling:

<!-- capture -->
```bash
friedman data list
```
```text
                               Available Datasets
┌──────────────┬───────────────┬──────────────┬─────────────────────────────────
│     name     │     type      │  dimensions  │                                ⋯
│    String    │    String     │    String    │                                ⋯
├──────────────┼───────────────┼──────────────┼─────────────────────────────────
│   fred_md    │  Time Series  │  804 × 126   │                 FRED-MD Monthl ⋯
│   fred_qd    │  Time Series  │  268 × 245   │                FRED-QD Quarter ⋯
│     pwt      │     Panel     │ 38 × 74 × 42 │               Penn World Table ⋯
│    mpdta     │     Panel     │ 500 × 5 × 3  │                       Callaway ⋯
│     ddcg     │     Panel     │ 184 × 51 × 2 │                           Acem ⋯
│   denmark    │  Time Series  │    55 × 5    │                Danish money-de ⋯
│ gnp_hamilton │  Time Series  │   135 × 1    │                  US GNP growth ⋯
│   grunfeld   │     Panel     │ 10 × 20 × 3  │                      Grunfeld  ⋯
│  mp_shocks   │  Time Series  │   240 × 8    │ US monetary panel + policy-sho ⋯
│     mroz     │ Cross Section │   753 × 22   │                             Mr ⋯
│     nile     │  Time Series  │   100 × 1    │                     Nile river ⋯
│  stackloss   │ Cross Section │    21 × 4    │                    Brownlee st ⋯
└──────────────┴───────────────┴──────────────┴─────────────────────────────────
                                                                1 column omitted
```

All 12 built-in datasets can be passed directly to estimators via a leading colon (`:denmark`, `:fred_md`, `:pwt`) or materialized into a persistent handle with `friedman data import :denmark -o denmark`.

---

## Built-in Datasets & Typed Import

| Dataset (`:name`) | Kind | Dimensions | Domain & Use Case |
|---|---|---|---|
| `:fred_md` | Time Series | `804 × 126` | Monthly U.S. macroeconomic panel (McCracken–Ng) for factor models, DFM, BVAR |
| `:fred_qd` | Time Series | `268 × 245` | Quarterly U.S. macroeconomic panel for structural macro and nowcasting |
| `:denmark` | Time Series | `55 × 5` | Danish money demand (`LRM`, `LRY`, `LPY`, `IBO`, `IDE`) for VECM/VAR/cointegration |
| `:gnp_hamilton` | Time Series | `135 × 1` | U.S. real GNP growth for AR/ARIMA, regime switching (`ms-ar`), and unit-root tests |
| `:mp_shocks` | Time Series | `240 × 8` | Monthly monetary policy proxy and macro aggregates for LP-IV and proxy-SVAR |
| `:nile` | Time Series | `100 × 1` | Annual Nile river flow volume for state-space local level and structural break tests |
| `:pwt` | Panel | `38 × 74 × 42` | Penn World Table cross-country panel for panel FE/RE/PMGs and dynamic panels |
| `:mpdta` | Panel | `500 × 5 × 3` | Teen employment minimum-wage panel for staggered DiD and event-study estimators |
| `:ddcg` | Panel | `184 × 51 × 2` | Democracy and growth country-year panel for dynamic panel and LP-DiD |
| `:grunfeld` | Panel | `10 × 20 × 3` | Firm investment panel for SUR, 3SLS, and panel FE/RE comparisons |
| `:mroz` | Cross Section | `753 × 22` | Married women's labor supply for IV/2SLS, Probit/Logit, Tobit, and Heckman |
| `:stackloss` | Cross Section | `21 × 4` | Ammonia plant loss data for robust M/MM regression and outlier diagnostics |

When importing a raw CSV file via [`friedman data import`](@ref ref-data-import), declare the container kind (`--kind timeseries|panel|cross-section`) alongside `--frequency`, `--dates`, or `--id-col`/`--time-col`. Use [`friedman data export`](@ref ref-data-export) to drop metadata and write a flat CSV for external tools.

---

## Diagnostics, Transformation & Panel Balancing

Real macroeconomic panels routinely mix stationary growth rates, $I(1)$ log-levels, missing observations, and unbalanced ragged edges. Under FRED transformation code `j \in \{1, \dots, 7\}`, `friedman data transform` transforms levels $y_t$ to stationarity, for instance first difference ($j=2$: $\Delta y_t$), log difference ($j=5$: $100 \Delta \ln y_t$), or second log difference ($j=6$: $\Delta^2 \ln y_t$):

```math
y_t^{(5)} = \ln(y_t) - \ln(y_{t-1}), \qquad y_t^{(6)} = \Delta^2 \ln(y_t).
```

Before fitting a VAR or panel model, screen missing values and constant columns with [`friedman data diagnose`](@ref ref-data-diagnose), compute summary quantiles with [`friedman data describe`](@ref ref-data-describe), clean rows via [`data dropna`](@ref ref-data-dropna) or [`data fix`](@ref ref-data-fix), slice observations with [`data keeprows`](@ref ref-data-keeprows), detrend directly with [`data filter`](@ref ref-data-filter), verify container compatibility via [`data validate`](@ref ref-data-validate), or impute missing panel blocks via EM dynamic factors in [`data balance`](@ref ref-data-balance):

<!-- capture -->
```bash
friedman --quiet data import :denmark -o macro
friedman data describe macro
```
```text
                             Descriptive Statistics
┌──────────┬───────┬─────────────┬────────────┬─────────┬─────────┬─────────┬───
│ variable │   n   │ first_valid │ last_valid │  mean   │   std   │   min   │  ⋯
│  String  │ Int64 │    Int64    │   Int64    │ Float64 │ Float64 │ Float64 │  ⋯
├──────────┼───────┼─────────────┼────────────┼─────────┼─────────┼─────────┼───
│   LRM    │  55   │      1      │     55     │ 11.7544 │ 0.1524  │ 11.5815 │  ⋯
│   LRY    │  55   │      1      │     55     │ 5.9524  │ 0.0728  │ 5.7868  │  ⋯
│   LPY    │  55   │      1      │     55     │ 0.0095  │  0.334  │ -0.6187 │  ⋯
│   IBO    │  55   │      1      │     55     │ 0.1564  │ 0.0308  │ 0.0977  │  ⋯
│   IDE    │  55   │      1      │     55     │ 0.0904  │ 0.0141  │ 0.0675  │  ⋯
└──────────┴───────┴─────────────┴────────────┴─────────┴─────────┴─────────┴───
                                                               6 columns omitted
```

Notice `descriptive_statistics` (JSON `data` table key) reports `55` non-missing observations per series alongside mean and standard deviation (`LRM`: `11.7544`, `0.1524`; `LRY`: `5.9524`, `0.0728`) across all five Danish macro series, whereas `data diagnose` emits `data_diagnostics` and `data balance` emits `balanced_panel`.

---

## Monte Carlo Simulation (`data simulate`)

Friedman-cli includes built-in DGP simulators organized under [`friedman data simulate`](@ref ref-fam-data-simulate) that output both synthetic observations (`simulated_data`) and true parameters (`population_truth`) while optionally persisting a ready-to-estimate typed handle (`--save-data STEM`). Passing a leading `--seed` or `--seed` option ensures bit-exact replication across runs.

| Domain | `data simulate <dgp>` Subcommands | Ground-Truth Persistence |
|---|---|---|
| Univariate & Long Memory | `arima`, `ardl`, `garch`, `sv`, `regime` | `simulated_data`, `population_truth`, `simulation_settings` |
| Multivariate & Structural Macro | `var`, `svar`, `vecm`, `heteroskedastic-var`, `factors`, `lp-iv`, `cointreg` | Structural impact matrix, cointegrating rank, or VAR lag matrices |
| Micro, Cross-Section & Panel | `cross-section`, `gmm`, `panel`, `pvar`, `did` | Known slope, selection/censoring thresholds, or cohort ATTs |
| Equilibrium & Heterogeneity | `dsge`, `ha`, `ct`, `olg` | Simulated series plus solver grid / policy truth |

The example below draws 150 periods from a seeded VAR DGP (`--seed 7`), persists `sim_var.jld2`, and verifies [`friedman data diagnose`](@ref ref-data-diagnose) reports zero missing or constant series:

<!-- capture -->
```bash
friedman --quiet data simulate var --periods 150 --burn 50 --seed 7 --save-data sim_var
friedman data diagnose sim_var
```
```text
             Data Diagnostics
┌──────────┬───────┬───────┬─────────────┐
│ variable │ n_nan │ n_inf │ is_constant │
│  String  │ Int64 │ Int64 │    Bool     │
├──────────┼───────┼───────┼─────────────┤
│    y1    │   0   │   0   │    false    │
│    y2    │   0   │   0   │    false    │
│    y3    │   0   │   0   │    false    │
└──────────┴───────┴───────┴─────────────┘
```

After running `data simulate`, use `sim_var` directly in [`friedman estimate multivariate var`](@ref ref-estimate-multivariate-var) (`data_diagnostics` confirms `0` NaN/Inf values and `is_constant = false` across `y1`–`y3`, while the generator's `population_truth` JSON key lets agents score estimation error automatically).

---

## Common Pitfalls

1. **Passing `--kind` inconsistently on CSV import:** [`friedman data import`](@ref ref-data-import) requires `--kind panel` together with `--id-col` and `--time-col`; omitting them fails with exit `2` (`usage`), and `--kind cross-section` requires `--frequency other`.
2. **Expecting frequency/tcodes in flat CSV exports:** [`friedman data export`](@ref ref-data-export) intentionally drops `:timeseries` frequency tags and FRED tcodes when serializing to CSV; keep a `.jld2` handle via `-o STEM` when passing series downstream.
3. **Mixing `data filter` and `filter`:** [`data filter`](@ref ref-data-filter) applies univariate trend-cycle decompositions (`hp`, `hamilton`, `bn`, `bk`, `bhp`) directly inside the `data` utility tree, whereas [`friedman filter`](@ref ref-filter) adds seasonal adjustment via [`filter x13`](@ref ref-filter-x13).
4. **Using `--vars` on `:example` import vs `data load`:** Use [`friedman data load`](@ref ref-data-load) when subsetting a bundled dataset to CSV with `--vars` or applying stored FRED transforms (`-t`); import full typed handles cleanly with `data import :name -o STEM`.

---

## References

- McCracken, M. W., & Ng, S. (2016). FRED-MD: A Monthly Database for Macroeconomic Research. *Journal of Business & Economic Statistics*, 34(4), 574–589.
- Johansen, S., & Juselius, K. (1990). Maximum likelihood estimation and inference on cointegration—with applications to the demand for money (`:denmark`). *Oxford Bulletin of Economics and Statistics*, 52(2), 169–210.
- Upstream manual: [MacroEconometricModels.jl — Data Management](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/data/)
- CLI reference: [`friedman data`](@ref ref-data), [`friedman data import`](@ref ref-data-import), [`friedman data simulate`](@ref ref-fam-data-simulate)
