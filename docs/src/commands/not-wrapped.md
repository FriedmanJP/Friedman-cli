# Not wrapped (v0.11.0 / MEMs 0.9.0)

Surface that exists upstream at MEMs 0.8.1/0.9.0 and is **not** a CLI leaf. Dispositions live on GitHub #160.

| Item | Disposition |
|------|-------------|
| `combine_blocks` / `HetBlock` / `MitBlock` / `SimpleBlock` | **Defer.** Programmatic DAG composition over closures; `_ha_solve` already uses it internally. Trigger: a TOML/file DAG language. |
| `DCEGMProblem` 4-closure constructor | **Refuse as flags.** Only via a user `.jl` file; the builtin `dcegm_retirement_model` is the CLI path. |
| HA OccBin (MEMs#654) | **Defer.** Every shipped HA builtin is rejected upstream (needs a nominal rate in `endog`). Trigger: a user spec that passes `_occbin_check_kind!`. |
| `parse_wiod` and `.zip` ICIO | **Refuse until bundled.** ZipFile/XLSX are MEMs weak deps and are not in the sysimage. Typed `env/missing-extension` (exit 6). W9 decision: do **not** bundle in v0.11.0 (sysimage size + cold-start vs #79). Revisit if #79 calibration moves. |
| Estimation on DCEGM/OLG/CT/firm/bank | **Refuse.** Upstream `_require_estimable_spec` rejects them. Pre-guarded `usage/wrong-command`. |
| `E[t](...)` auto-rewrite | **Refuse.** Surface upstream's `config/invalid`. Write `x[t+1]`. |
| `io ras` / `gras` | **Defer.** Generic matrix operators, not `IOData`. Trigger: a matrix-loader for prior/row/col sums. `io balance` covers the IOData RAS path. |
| Multi-population `solve` | **Defer.** MEMs#651. CLI loaders refuse mixed/non-singleton household populations as `model/unsupported`. Trigger: upstream ships a public multi-pop solve that does not take a closure. |
| Two-asset SS kwargs / `FirmSystem` `solve(to_spec)` | **File upstream** if T3 shows a broken public path; do not wrap a broken `solve(to_spec)`. |
| MEMs#609 JuMP/Ipopt/NonlinearSolve as extensions | **Watch-list.** Would change C060 bundling/licensing and the ~2.3 s cold-start floor. |

`--plot` is advertised only when a real `plot_result` method exists. Types without recipes (Threshold/STAR/MS forecasts, `ProjectionSolution`, firm/bank results, `DCEGMEquilibrium`, `LifeCycleTransition`, `CTTwoAssetGE`) stay plotless.
