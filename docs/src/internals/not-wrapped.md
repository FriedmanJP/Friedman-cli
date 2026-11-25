# [Unwrapped Upstream Surface](@id int-not-wrapped)

Functionality present in `MacroEconometricModels.jl` (pinned in `Project.toml`) that is **not** exposed as a standalone CLI leaf is tracked below together with its design rationale and trigger conditions for future adoption.

---

## Standing Deferrals & Exclusions

| Upstream Item | Disposition | Rationale / Trigger |
|---|---|---|
| `combine_blocks` / `HetBlock` / `MitBlock` / `SimpleBlock` | **Defer** | Programmatic DAG composition over closures (`dsge/heterogeneous/blocks.jl`); CLI HA solvers compose blocks internally. Revisit if a declarative TOML block-DAG syntax is designed. |
| `DCEGMProblem` 4-closure constructor | **Defer as CLI flags** | Arbitrary closures require Julia evaluation (covered by `.jl` spec loading); built-in lifecycle specs are exposed directly under [`frdc dsge dcegm`](@ref ref-fam-dsge-dcegm). |
| HA OccBin | **Defer** | Upstream restricts HA OccBin constraints to aggregate equations carrying a nominal policy rate, which built-in HA benchmarks omit; add once user specs with nominal rates are supported. |
| `parse_wiod` and `.zip` ICIO archives | **Refuse until bundled** | `ZipFile` / `XLSX` remain optional weak dependencies excluded from sysimage bundles; calling them surfaces typed `env/missing-extension` (exit `6`). |
| Bayesian/frequentist estimation on DCEGM/OLG/CT/firm/bank | **Refuse** | Upstream `_require_estimable_spec` restricts DSGE estimation to perturbation-estimable specifications (`usage/wrong-command`). |
| Legacy `E[t](...)` expectation syntax | **Refuse** | Upstream DSGE parser removed `E[t](...)` call syntax in favor of explicit leads `x[t+1]`. |
| Generic matrix `ras` / `gras` operators | **Defer** | Operates on bare matrices rather than typed `IOData`; use [`frdc io balance`](@ref ref-io-balance) for structured IO table balancing. |
| Multi-population HA `solve` | **Defer** | Multi-population heterogeneous-agent aggregation relies on functional closures upstream; CLI loaders reject non-singleton household populations with `model/unsupported`. |
| Two-asset steady-state closer kwargs & `FirmSystem` `solve(to_spec)` | **Do not wrap** | Solver bracket/iteration controls (`k_lo`, `k_hi`, `k_atol`) remain auto-tuned upstream to keep the CLI free of solver-implementation churn. |
| `label_shocks` | **Defer** | Relabels result objects in memory without emitting a tabular artifact; revisit when non-Gaussian structural identification gains standalone result-relabelling leaves. |
| Additional `estimate_svar` extensions | **Defer** | Held out until upstream non-Gaussian and weak-ID interfaces stabilize further. |
| ForwardDiff volume & optimizer internals | **Do not wrap** | Low-level optimization diagnostics have no stable tabular CLI surface. |
| RWZ rank/order checker | **Enforced internally** | Upstream `_assert_rwz_identified` executes automatically inside SVAR estimation/identification and maps violations to `model/identification` (exit `5`). |
| `varindex` | **Do not wrap** | Programmatic string-to-column lookup helper; CLI users pass variable names directly on options. |
| Interactive `refs()` & terminal `report()` pretty-printers | **Stderr only** | Human `report()` summaries route to stderr alongside structured stdout data; `refs()` citations belong in reference docs rather than machine JSON payloads. |
| Raw `TimeSeriesData`-dispatch shortcuts | **Internal** | CLI pipelines serialize `TimeSeriesData`, `PanelData`, and `CrossSectionData` cleanly through `.jld2` handles ([`frdc data import`](@ref ref-data-import)), while low-level in-memory library wrappers stay internal. |
| Save bundles (`note=`, `compress=`) | **Declined** | CLI handles serialize single uncompressed objects per stem (`.jld2`, `.jls`, or `.fmod`) for predictable reproducibility. |
| SV-SVAR `smoother` choice | **Not exposed** | Only `:ksc` is valid upstream; exposing a singleton switch adds no value. |
| TVV/SV identification knobs on LP leaves | **Not exposed** | Upstream `structural_lp` enforces a fixed internal Q allow-list; `[identification.lewis_tvv]` and `[identification.sv_svar]` apply to VAR/VECM/BVAR/FAVAR/SDFM paths. |
| `weak_id` sub-struct extraction on IRF/FEVD/HD | **Not surfaced** | Wait for dedicated post-estimation shock-diagnostic leaf design. |
| VFI `optimizer_opts` raw passthrough & `--smolyak-mu` on PFI | **Deferred / Guarded** | VFI optimizer tuning awaits a structured TOML block rather than free-form strings; `--smolyak-mu` raises `usage/invalid` outside VFI grids where upstream fixes $\mu = 3$. |

Interactive HTML plots via `--plot` and `--plot-save` are advertised strictly on leaves whose upstream result struct defines a concrete `plot_result` method (verified continuously by `test/tools/check_plot_coverage.jl`).

---

## Recently Adopted Upstream Capabilities

Several formerly deferred capabilities have already been promoted into first-class CLI families:

- **Synthetic Data Generation (`data simulate`):** Covered across the `data simulate` family emitting simulated datasets, population truth tables, and simulation metadata; documented in [Data Management & Simulation](@ref chap-data).
- **SDFM Statistical Identification (`--id lewis-tvv|sv-em|gmm-moments`):** Integrated across structural factor estimation, IRFs, FEVDs, and historical decompositions under [Structural ID, LP & Innovation Accounting](@ref chap-structural).
- **Smolyak Grids, Physical VFI Nodes & GMM Weak-IV F:** Exposed natively across [`frdc dsge`](@ref ref-dsge), [`frdc hadsge`](@ref ref-hadsge), and [`frdc estimate regression gmm`](@ref ref-estimate-regression-gmm).
- **Single-Object `.jld2` & `.jls` Typed Handles:** Unified data/model/result persistence documented in [Automated Pipelines & JSON Envelopes](@ref gs-pipelines).

---

## References

- [Architecture](@ref int-architecture) — handle lifecycles and `_emit_result` dispatch
- [API Reference](@ref int-api) — exported Julia embedding entry points
- Generated CLI option tables: [`estimate`](@ref ref-estimate), [`dsge`](@ref ref-dsge), [`io`](@ref ref-io)
- Upstream package documentation: [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/)
