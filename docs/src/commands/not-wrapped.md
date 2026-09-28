# Not wrapped (v1.0.0 / MEMs 1.0.0)

Surface that exists upstream and is **not** a CLI leaf. Standing dispositions below were re-verified against the MEMs 1.0.0 resolved copy; the 0.9.7→1.0.0 export diff is empty (1203/1203 names identical, checked by set-diffing `names(MacroEconometricModels)` on both resolved copies under Julia 1.13), so the 1.0.0 major adds no new wrappable surface and no new rows.

The pre-1.0.0 per-wave audit ledgers were removed in the v1.0.0 docs overhaul — their verdicts are distilled into the tables below. Full text survives in git history (`git log -- docs/src/commands/not-wrapped.md`); release notes in `CHANGELOG.md`; wave detail in the closed tracking issues (#160, #168, #171, #173, #177, #179, #180, #185, #186, #192–#195).

---

## Standing deferrals

| Item | Disposition |
|------|-------------|
| `combine_blocks` / `HetBlock` / `MitBlock` / `SimpleBlock` | **Defer.** Programmatic DAG composition over closures (`dsge/heterogeneous/blocks.jl`); `_ha_solve` already uses it internally. Trigger: a TOML/file DAG language. |
| `DCEGMProblem` 4-closure constructor | **Refuse as flags.** Only via a user `.jl` file (keyword constructor in `dsge/heterogeneous/dcegm.jl`); the builtin `dcegm_retirement_model` is the CLI path. |
| HA OccBin | **Defer.** Upstream applies OccBin to HA aggregates only when the equations include a nominal policy rate (`dsge/occbin.jl`); every shipped HA builtin is rejected on that ground. Trigger: a user spec carrying a nominal rate. |
| `parse_wiod` and `.zip` ICIO | **Refuse until bundled.** `parse_wiod` lives in `io/parse.jl`; ZipFile/XLSX are MEMs weak deps and are not in the sysimage. Typed `env/missing-extension` (exit 6). |
| Estimation on DCEGM/OLG/CT/firm/bank | **Refuse.** Upstream `_require_estimable_spec` (`dsge/bayes_estimation.jl`) rejects them. Pre-guarded `usage/wrong-command`. |
| `E[t](...)` auto-rewrite | **Refuse.** Upstream removed the `E[t](...)` call form — the parser (`dsge/parser.jl`) errors on it. Write `x[t+1]`. |
| `io ras` / `gras` | **Defer.** Generic matrix operators (`io/ras.jl`), not `IOData`. Trigger: a matrix-loader for prior/row/col sums. `io balance` covers the IOData RAS path. |
| Multi-population `solve` | **Defer.** Upstream names it as the open item (MEMs#651, cited in `dsge/heterogeneous/parser.jl` and `ssj.jl`). CLI loaders refuse mixed/non-singleton household populations as `model/unsupported`. Trigger: upstream ships a public multi-pop solve that does not take a closure. |
| Two-asset SS closer kwargs / `FirmSystem` `solve(to_spec)` | **Do not wrap.** Closer knobs (`k_lo`/`k_hi`/`inner_max_iter`/`k_atol`/`stable_iters`, `dsge/heterogeneous/two_asset_ge.jl`) stay on auto-selection (revisit only on a T3 convergence failure); do not wrap a broken `solve(to_spec)` — file upstream if T3 shows a broken public path. |
| `label_shocks` | **Defer.** Returns a relabeled result object (`core/identification.jl`), not a labels table — nothing to render, and the NG `irf`/`fevd` paths consume only Q downstream, so labeling would be invisible. Trigger: a result-holding leaf (e.g. a future `estimate nongaussian` family). |
| `estimate_svar` further extensions | **Defer.** SVAR surface beyond what the CLI wraps stays out until upstream stabilises it. |
| ForwardDiff-volume internals | **Defer.** Optimizer internals, no CLI shape. |
| Oracle/DGP-recovery test-only helpers | **Defer.** Test-only upstream helpers, never user surface. |
| RWZ rank/order checker | **Enforced upstream, no separate CLI.** `_assert_rwz_identified` (`core/arias.jl`, called from `core/uhlig.jl` and the SVAR estimators) runs inside identification and estimation; violations throw `IdentificationError` → `model/identification` (exit 5). |
| `varindex` | **Wontwrap.** One-line name→index lookup over `StructuralDFM.varnames` (`factor/structural.jl`); programmatic convenience with no table to render. |
| `refs` / `report` pretty-printers | **Wontwrap as data; `report()` already stderr.** Per-type `report()` methods (still the pre-overhaul shape at 1.0.0) ride stderr via `_status_report` (stdout stays data-only); `refs()` emits literature citations — no data shape to render. |
| `TimeSeriesData`-dispatch conveniences | **Wontwrap.** CLI data paths are CSV→DataFrame→Matrix; `TimeSeriesData` objects never cross the CLI boundary. |
| Upstream v1 fixtures | **Wontwrap.** Upstream repo's own regression files (`test/fixtures/serialization/v1/`); test-only, never user surface. |
| Save bundles / `note=` / `compress=` | **Declined.** No `--compress` flag, no bundle/`note=` surface. Upstream `save_model` (`core/serial/api.jl`) carries those kwargs for library users; CLI saves are single-object uncompressed `.jld2`. |
| DGP-library internals (white-noise lint, simulation guide/API ref) | **No-op.** Upstream-internal checks and docs; the CLI documents only leaves it ships. Canonical upstream docs link stands. |
| SV-SVAR `smoother` | **Deliberately not exposed.** Upstream supports only `:ksc` (`nongaussian/sv_svar.jl` throws otherwise) — no choice to offer. |
| TVV/SV knobs on LP leaves | **Not exposed.** Upstream `structural_lp` pins its own `compute_Q` allow-list with no knob channel; TOML knob sections are consumed by the var/vecm/bvar/favar leaves only. |
| Pre-computed-Q injection / diagnostic pre-calls | **No.** `_svec_Q` is consumed only in the `:svec` branch — no generic pre-computed-Q path exists, and a pre-call would double estimation and describe a different rng draw than the rendered estimate. |
| `weak_id` on irf/fevd/hd | **Not surfaced.** Travels with the estimator result at library level (`nongaussian/lewis_tvv.jl`); a dedicated identified-shock diagnostic leaf is future work. |
| VFI `optimizer_opts` passthrough | **Deferred with record.** Five `Optim.Options` keys need a typed TOML design; bare-string passthrough is unacceptable and scalar explosion is unjustified with no demand signal. Upstream defaults apply. Revisit on user request. |
| `--smolyak-mu` on PFI/projection | **Rejected as `usage/invalid`.** VFI-only surface (`dsge/projection.jl`); the other solvers stay on the upstream default `μ=3`. |

`--plot` is advertised only when a real `plot_result` method exists. Types without recipes stay plotless (plot-coverage baseline 181/181 at MEMs 1.0.0, no drift).

---

## Adopted on the 1.0.0 program

Absorbed with no new not-wrapped remainder:

- **`data simulate` (#177):** the deferred DGP family shipped (leaves under `data simulate`; `simulated_data` + `population_truth` + `simulation_settings`; rng-only seeding via handler-side `Xoshiro`). Oracle helpers (`var_irf`/`var_fevd`/`lyapunov_gamma0`) adopted as closed-form T3 assertions; `test/integration/dgp.jl` stays hermetic.
- **SDFM statistical ID (#193 / MEMs#830):** `--id cholesky|sign|proxy|lewis-tvv|sv-em|gmm-moments` on the sdfm leaves; knobs ride `id_kwargs` from TOML (`[identification.lewis_tvv]` / `[identification.sv_svar]`).
- **`physical_nodes` (#194 / MEMs#829, closes #182):** `vfi_value_function` renders physical levels, matching `--evaluate-at`.
- **`GMMModel.first_stage_F` (#195):** renders in `gmm_diagnostics`; F < 10 warns on stderr.
- **Smolyak/VFI absorption (#180):** `--grid smolyak`, `--smolyak-mu`, `--optimizer` with `:auto` passthrough and knob-scoping guards (provably-dead explicit combos are `usage/invalid`; `auto` corners stay permissive and documented).
- **Uhlig sign-normalization (#814):** changed numbers on existing paths, no re-exposure; no drift hit goldens or captures.
- **`compute_steady_state` (#816, consumed):** world-age `MethodError` rewritten as `DSGESolveError` → `model/solve` (exit 5), already mapped.
- **Lead-variable catalog (#223):** `LinearDSGE.Pi` one column per distinct lead; CLI never touches the changed names — no adapter change.
- **Two-asset closer rewrite (#709):** `rb_init`/`relax_K`/`relax_rb` gone, `k_lo`/`k_hi`/`inner_max_iter`/`k_atol`/`stable_iters` added with retuned defaults; none of the removed kwargs were ever exposed — no adapter change, no steady-state value drift in captures.
- **Julia 1.13 support:** SVAR internals accept any `LowerTriangular` backing; CLI has no direct use — no adapter change.

---

- **Consumed at v1.0.0:** MEMs#609 (JuMP/Ipopt/NonlinearSolve stay required `[deps]` at 1.0.0; weakdeps hold only PATHSolver/XLSX/ZipFile — C060 bundling story and the ~2.3 s cold-start floor stand), MEMs#255 (single-package layout unchanged), MEMs 1.0 major watch (TRIGGERED — this v1.0.0 program was the adaptation series).

---

## References

Full option tables: [generated estimate reference](generated/estimate.md), [generated dsge reference](generated/dsge.md), [generated io reference](generated/io.md). Closed tracking issues (#160, #168, #171, #173, #177, #179, #180, #185, #186, #192–#195) carry the per-wave audit detail; release notes in `CHANGELOG.md`.
