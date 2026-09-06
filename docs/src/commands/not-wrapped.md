# Not wrapped (v0.12.0 / MEMs 0.9.3)

Surface that exists upstream and is **not** a CLI leaf. Dispositions live on GitHub #160 (v0.11.0 line) and #168 (v0.12.0 remainder, W4).

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

## W2/#166 deferrals (MEMs 0.9.2 SVAR remainder; cite W4 #168)

| Item | Disposition |
|------|-------------|
| `label_shocks` (#749) | **Defer.** Returns a relabeled result object, not a labels table — nothing to render, and the NG `irf`/`fevd` paths consume only Q downstream, so labeling would be invisible. Trigger: a result-holding leaf (e.g. a future `estimate nongaussian` family). |
| K-regime joint-ML token (#739) | **No token.** The `_k_regime_*` kernel is private; it rides `identify_markov_switching` (the `test heteroskedasticity --method markov` and `--test lambda-distinct` paths). |
| `estimate_svar` experimental extensions (#756) | **Defer.** Upstream-marked experimental surface stays out. |
| ForwardDiff-volume internals (#756) | **Defer.** Optimizer internals, no CLI shape. |
| Oracle/DGP-recovery test-only helpers (#755) | **Defer.** Test-only upstream helpers, never user surface. |
| RWZ rank/order checker (#752) | **Enforced upstream, no separate CLI.** `_assert_rwz_identified` runs inside `identify_arias` (frequentist + Bayesian) and `estimate_svar`; violations throw `IdentificationError` → `model/identification` (exit 5). Proven by the underidentified-pattern T3 case. |

## W4/#168 dispositions (MEMs 0.9.1–0.9.3 remainder)

| Item | Disposition |
|------|-------------|
| 0.9.1: `estimate_structural_dfm(X, :auto)` corners | **Adopted in W1 — no remainder.** `--q-method` (hallin-liska/bai-ng/amengual-watson) plus omitted `--factors` routes the upstream `:auto` Symbol method; all three selectors are CLI-exposed. |
| 0.9.1: `varindex` | **Wontwrap.** One-line name→index lookup over `StructuralDFM.varnames`; programmatic convenience with no table to render. |
| 0.9.1: `refs` / `report` pretty-printers | **Wontwrap as data; `report()` already stderr.** `report()` output rides stderr via `_status_report` (stdout stays data-only); `refs()` emits literature citations — no data shape to render. |
| 0.9.1: `TimeSeriesData`-dispatch conveniences | **Wontwrap.** CLI data paths are CSV→DataFrame→Matrix; `TimeSeriesData` objects never cross the CLI boundary. |
| 0.9.2: `estimate_svar` experimental extensions (#756) | **Defer** (carried from W2). Upstream-marked experimental surface stays out. |
| 0.9.2: ForwardDiff-volume internals (#756) | **Defer** (carried). Optimizer internals, no CLI shape. |
| 0.9.2: oracle/DGP-recovery helpers (#755) | **Defer** (carried). Test-only upstream helpers, never user surface. |
| 0.9.2: `compute_Q` registry corners | **No direct surface.** No leaf calls `compute_Q` directly (robust-bayes deliberately bypasses the generic path); the registry is reached through the `identify_*` leaves. |
| 0.9.2: identification-serialization details (#753) | **Adopted via W3.** `report(::SignIdentifiedSet)` exists upstream and rides stderr; `SignIdentifiedSet` is in the 350-type native registry with a proven round-trip; the `:garch` refs entry is present; citation fixes have no CLI surface. |
| 0.9.3: bundles / `note=` / `compress=` (#772/#785) | **Declined in W3** (see CHANGELOG): no `--compress` flag, no bundle/`note=` surface. Upstream kwargs stay available to library users; CLI saves are single-object uncompressed `.jld2`. |
| 0.9.3: v1 fixtures (#770) | **Wontwrap.** Upstream repo's own regression files (`test/fixtures/serialization/v1/`); test-only, never user surface. |
| 0.9.3: persistence-docs caveats | **Mirrored in docs.** Named-function requirement + Core.eval-allowlist trust caveat in the agent guide (`model info` stays header-only, never executes). |
| MEMs#816 (CLI-filed this wave, OPEN) | **Watch.** LinearSolve generated-`solve!` world-age boom on the steady-state QR-fallback branch masks `DSGESolveError` in stale-image envs. Trigger: upstream close → re-run the W4 bad-model probe set on a fresh depot. |

## Standing watches (re-checked at 0.9.3 for W4)

- **MEMs#609 (OPEN, no movement):** JuMP/Ipopt/NonlinearSolve are still direct required deps at 0.9.3 (plus JLD2 now hard; CodecZlib transitive-present via the JLD2 chain). C060 bundling story and the ~2.3 s cold-start floor stand.
- **MEMs#255 (OPEN, no movement):** sub-package split undecided upstream; no adapter impact to record.
- **`report()` overhaul:** no landed overhaul at 0.9.3; the `_status_report` swallow stands.
- **MEMs 1.0 major watch:** not announced; the #104/#121/#135 adaptation pattern holds ready.
