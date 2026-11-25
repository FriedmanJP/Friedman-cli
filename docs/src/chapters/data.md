# [Data Management & Simulation](@id chap-data)

Every empirical pipeline begins with typed containers (`:timeseries`, `:panel`, `:cross_section`) imported from raw CSVs, loaded from bundled macroeconomic and microeconometric benchmarks, cleaned or filtered via [`frdc data`](@ref ref-data), or generated with known ground-truth parameters under the 21 structural and reduced-form DGP simulators in [`frdc data simulate`](@ref ref-data). See the upstream [Data Management manual](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/data/) in `MacroEconometricModels.jl` for underlying container types.

## Quick Start

List bundled benchmark datasets, import `:denmark` into a typed native `.jld2` handle with frequency metadata intact, inspect per-variable moments, and check stationarity/missingness before modeling:

<!-- capture -->
```bash
frdc data list
```
```text
                                                            Available Datasets
┌──────────────┬───────────────┬──────────────┬──────────────────────────────────────────────────────────────────────────────────────────┐
│     name     │     type      │  dimensions  │                                       description                                        │
├──────────────┼───────────────┼──────────────┼──────────────────────────────────────────────────────────────────────────────────────────┤
│   fred_md    │  Time Series  │  804 × 114   │            FRED-MD Monthly Database (114 US federal public-domain indicators)            │
│   fred_qd    │  Time Series  │  268 × 226   │           FRED-QD Quarterly Database (226 US federal public-domain indicators)           │
│     pwt      │     Panel     │ 38 × 74 × 42 │         Penn World Table (38 OECD countries, 74 years, 42 variables; CC-BY-4.0)          │
│    mpdta     │     Panel     │ 500 × 5 × 3  │                       Callaway-Sant'Anna (2021) minimum wage panel                       │
│     ddcg     │     Panel     │ 184 × 51 × 2 │                           Acemoglu et al. democracy-GDP panel                            │
│   denmark    │  Time Series  │    55 × 5    │                Danish money-demand data (Johansen-Juselius cointegration)                │
│ gnp_hamilton │  Time Series  │   135 × 1    │                  US GNP growth (Hamilton 1989 Markov-switching example)                  │
│   grunfeld   │     Panel     │ 10 × 20 × 3  │                      Grunfeld investment panel (10 firms, 20 years)                      │
│  mp_shocks   │  Time Series  │   240 × 8    │ US monetary panel + policy-shock series (McKay-Wolf 2023; NaN outside published samples) │
│     mroz     │ Cross Section │   753 × 22   │                             Mroz (1987) female labour supply                             │
│     nile     │  Time Series  │   100 × 1    │                     Nile river annual flow (local-level state space)                     │
│  stackloss   │ Cross Section │    21 × 4    │                    Brownlee stack-loss plant data (robust regression)                    │
└──────────────┴───────────────┴──────────────┴──────────────────────────────────────────────────────────────────────────────────────────┘
```

All 12 built-in datasets can be passed directly to estimators via a leading colon (`:denmark`, `:fred_md`, `:pwt`) or materialized into a persistent handle with `frdc data import :denmark -o denmark`.

---

## Built-in Datasets & Typed Import

| Dataset (`:name`) | Kind | Dimensions | Domain & Use Case |
|---|---|---|---|
| `:fred_md` | Time Series | `804 × 114` | Monthly U.S. federal public-domain macroeconomic panel (McCracken–Ng) for factor models, DFM, BVAR |
| `:fred_qd` | Time Series | `268 × 226` | Quarterly U.S. federal public-domain macroeconomic panel for structural macro and nowcasting |
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

When importing a raw CSV file via [`frdc data import`](@ref ref-data-import), declare the container kind (`--kind timeseries|panel|cross-section`) alongside `--frequency`, `--dates`, or `--id-col`/`--time-col`. Use [`frdc data export`](@ref ref-data-export) to serialize typed handles to flat CSV (dropping metadata) or write `.jld2`/`.jls`/`.fmod` targets with `-o`.

Data transformation and cleaning utilities (`data load`, `fix`, `transform`, `balance`, `dropna`, `keeprows`, and `export`) never create unsolicited files in the current working directory: when `-o` is omitted they stream directly to stdout in the requested `--format`, and write output files (recorded in JSON `artifacts`) only when `-o` is explicitly passed. Pass `--vars` before `--transform` on [`frdc data load`](@ref ref-data-load) to subset columns cleanly prior to applying stored FRED transformation codes.

---

## Diagnostics, Transformation & Panel Balancing

Real macroeconomic panels routinely mix stationary growth rates, $I(1)$ log-levels, missing observations, and unbalanced ragged edges. Under FRED transformation code `j \in \{1, \dots, 7\}`, `frdc data transform` transforms levels $y_t$ to stationarity, for instance first difference ($j=2$: $\Delta y_t$), log difference ($j=5$: $100 \Delta \ln y_t$), or second log difference ($j=6$: $\Delta^2 \ln y_t$):

```math
y_t^{(5)} = \ln(y_t) - \ln(y_{t-1}), \qquad y_t^{(6)} = \Delta^2 \ln(y_t).
```

Before fitting a VAR or panel model, screen missing values and constant columns with [`frdc data diagnose`](@ref ref-data-diagnose), compute summary quantiles with [`frdc data describe`](@ref ref-data-describe), clean rows via [`data dropna`](@ref ref-data-dropna) or [`data fix`](@ref ref-data-fix), slice observations with [`data keeprows`](@ref ref-data-keeprows), detrend directly with [`data filter`](@ref ref-data-filter), verify container compatibility via [`data validate`](@ref ref-data-validate), or impute missing panel blocks via EM dynamic factors in [`data balance`](@ref ref-data-balance):

<!-- capture -->
```bash
frdc --quiet data import :denmark -o macro
frdc data describe macro
```
```text
                                                        Descriptive Statistics
┌──────────┬────┬─────────────┬────────────┬─────────┬────────┬─────────┬─────────┬─────────┬────────┬─────────┬──────────┬──────────┐
│ variable │ n  │ first_valid │ last_valid │  mean   │  std   │   min   │   p25   │ median  │  p75   │   max   │ skewness │ kurtosis │
├──────────┼────┼─────────────┼────────────┼─────────┼────────┼─────────┼─────────┼─────────┼────────┼─────────┼──────────┼──────────┤
│   LRM    │ 55 │      1      │     55     │ 11.7544 │ 0.1524 │ 11.5815 │ 11.629  │ 11.7049 │ 11.819 │ 12.0755 │  0.8781  │ -0.4777  │
│   LRY    │ 55 │      1      │     55     │ 5.9524  │ 0.0728 │ 5.7868  │ 5.9098  │ 5.9396  │ 5.9858 │  6.099  │  0.1084  │ -0.0413  │
│   LPY    │ 55 │      1      │     55     │ 0.0095  │ 0.334  │ -0.6187 │ -0.2763 │ 0.0333  │ 0.3236 │ 0.4683  │ -0.2525  │ -1.2915  │
│   IBO    │ 55 │      1      │     55     │ 0.1564  │ 0.0308 │ 0.0977  │ 0.1336  │ 0.1611  │ 0.1794 │ 0.2108  │ -0.1355  │ -0.9956  │
│   IDE    │ 55 │      1      │     55     │ 0.0904  │ 0.0141 │ 0.0675  │ 0.0775  │  0.088  │ 0.102  │  0.121  │  0.3683  │ -0.9232  │
└──────────┴────┴─────────────┴────────────┴─────────┴────────┴─────────┴─────────┴─────────┴────────┴─────────┴──────────┴──────────┘
```

Notice `descriptive_statistics` (JSON `data` table key) reports `55` non-missing observations per series alongside mean and standard deviation (`LRM`: `11.7544`, `0.1524`; `LRY`: `5.9524`, `0.0728`) across all five Danish macro series, whereas `data diagnose` emits `data_diagnostics` and `data balance` emits `balanced_panel`.

---

## Monte Carlo Simulation (`data simulate`)

Friedman-cli includes built-in DGP simulators organized under [`frdc data simulate`](@ref ref-fam-data-simulate) that output both synthetic observations (`simulated_data`) and true parameters (`population_truth`) while optionally persisting a ready-to-estimate typed handle (`--save-data STEM`). Passing a leading `--seed` or `--seed` option ensures bit-exact replication across runs.

| Domain | `data simulate <dgp>` Subcommands | Ground-Truth Persistence |
|---|---|---|
| Univariate & Long Memory | `arima`, `ardl`, `garch`, `sv`, `regime` | `simulated_data`, `population_truth`, `simulation_settings` |
| Multivariate & Structural Macro | `var`, `svar`, `vecm`, `heteroskedastic-var`, `factors`, `lp-iv`, `cointreg` | Structural impact matrix, cointegrating rank, or VAR lag matrices |
| Micro, Cross-Section & Panel | `cross-section`, `gmm`, `panel`, `pvar`, `did` | Known slope, selection/censoring thresholds, or cohort ATTs |
| Equilibrium & Heterogeneity | `dsge`, `ha`, `ct`, `olg` | Simulated series plus solver grid / policy truth |

The example below draws 150 periods from a seeded VAR DGP (`--seed 7`), persists `sim_var.jld2`, and verifies [`frdc data diagnose`](@ref ref-data-diagnose) reports zero missing or constant series:

<!-- capture -->
```bash
frdc --quiet data simulate var --periods 150 --burn 50 --seed 7 --save-data sim_var
frdc data diagnose sim_var
```
```text
             Data Diagnostics
┌──────────┬───────┬───────┬─────────────┐
│ variable │ n_nan │ n_inf │ is_constant │
├──────────┼───────┼───────┼─────────────┤
│    y1    │   0   │   0   │    false    │
│    y2    │   0   │   0   │    false    │
│    y3    │   0   │   0   │    false    │
└──────────┴───────┴───────┴─────────────┘
```

After running `data simulate`, use `sim_var` directly in [`frdc estimate multivariate var`](@ref ref-estimate-multivariate-var) (`data_diagnostics` confirms `0` NaN/Inf values and `is_constant = false` across `y1`–`y3`, while the generator's `population_truth` JSON key lets agents score estimation error automatically).

---

## Common Pitfalls

1. **Passing `--kind` inconsistently on CSV import:** [`frdc data import`](@ref ref-data-import) requires `--kind panel` together with `--id-col` and `--time-col`; omitting them fails with exit `2` (`usage`), and `--kind cross-section` requires `--frequency other`.
2. **Expecting frequency/tcodes in flat CSV exports:** [`frdc data export`](@ref ref-data-export) intentionally drops `:timeseries` frequency tags and FRED tcodes when serializing to CSV; keep a `.jld2` or `.jls` handle via `-o STEM.jld2` / `-o STEM.jls` (or omit `-o` to stream stdout) when preserving metadata downstream.
3. **Mixing `data filter` and `filter`:** [`data filter`](@ref ref-data-filter) applies univariate trend-cycle decompositions (`hp`, `hamilton`, `bn`, `bk`, `bhp`) directly inside the `data` utility tree, whereas [`frdc filter`](@ref ref-filter) adds seasonal adjustment via [`filter x13`](@ref ref-filter-x13).
4. **Using `--vars` on `:example` import vs `data load`:** Use [`frdc data load`](@ref ref-data-load) when subsetting a bundled dataset to CSV with `--vars` or applying stored FRED transforms (`-t`); import full typed handles cleanly with `data import :name -o STEM`.

---

## References

- McCracken, M. W., & Ng, S. (2016). FRED-MD: A Monthly Database for Macroeconomic Research. *Journal of Business & Economic Statistics*, 34(4), 574–589.
- Johansen, S., & Juselius, K. (1990). Maximum likelihood estimation and inference on cointegration—with applications to the demand for money (`:denmark`). *Oxford Bulletin of Economics and Statistics*, 52(2), 169–210.
- Upstream manual: [MacroEconometricModels.jl — Data Management](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/data/)
- CLI reference: [`frdc data`](@ref ref-data), [`frdc data import`](@ref ref-data-import), [`frdc data simulate`](@ref ref-fam-data-simulate)
