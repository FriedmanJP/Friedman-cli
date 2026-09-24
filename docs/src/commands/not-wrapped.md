# Not wrapped (v1.0.0 / MEMs 1.0.0)

Surface that exists upstream and is **not** a CLI leaf. Standing dispositions below were re-verified against the MEMs 1.0.0 resolved copy; the 0.9.7→1.0.0 export diff is empty (1188/1188 identical), so the 1.0.0 major adds no new wrappable surface and no new rows.

The pre-1.0.0 per-wave audit ledgers were removed in the v1.0.0 docs overhaul — their verdicts are distilled into the tables below. Full text survives in git history (`git log -- docs/src/commands/not-wrapped.md`); release notes in `CHANGELOG.md`; wave detail in the closed tracking issues (#160, #168, #171, #173, #177, #179, #180, #185, #186, #192–#195).

## Standing deferrals

| Item | Disposition |
|------|-------------|
| `combine_blocks` / `HetBlock` / `MitBlock` / `SimpleBlock` | **Defer.** Programmatic DAG composition over closures; `_ha_solve` already uses it internally. Trigger: a TOML/file DAG language. |
| `DCEGMProblem` 4-closure constructor | **Refuse as flags.** Only via a user `.jl` file; the builtin `dcegm_retirement_model` is the CLI path. |
| HA OccBin (MEMs#654) | **Defer.** Every shipped HA builtin is rejected upstream (needs a nominal rate in `endog`). Trigger: a user spec that passes `_occbin_check_kind!`. |
| `parse_wiod` and `.zip` ICIO | **Refuse until bundled.** ZipFile/XLSX are MEMs weak deps and are not in the sysimage. Typed `env/missing-extension` (exit 6). |
| Estimation on DCEGM/OLG/CT/firm/bank | **Refuse.** Upstream `_require_estimable_spec` rejects them. Pre-guarded `usage/wrong-command`. |
| `E[t](...)` auto-rewrite | **Refuse.** Surface upstream's `config/invalid`. Write `x[t+1]`. |
| `io ras` / `gras` | **Defer.** Generic matrix operators, not `IOData`. Trigger: a matrix-loader for prior/row/col sums. `io balance` covers the IOData RAS path. |
| Multi-population `solve` | **Defer.** MEMs#651. CLI loaders refuse mixed/non-singleton household populations as `model/unsupported`. Trigger: upstream ships a public multi-pop solve that does not take a closure. |
| Two-asset SS closer kwargs / `FirmSystem` `solve(to_spec)` | **Do not wrap.** Closer knobs (`k_lo`/`k_hi`/`inner_max_iter`/`k_atol`/`stable_iters`) stay on auto-selection (revisit only on a T3 convergence failure); do not wrap a broken `solve(to_spec)` — file upstream if T3 shows a broken public path. |
| `label_shocks` | **Defer.** Returns a relabeled result object, not a labels table — nothing to render, and the NG `irf`/`fevd` paths consume only Q downstream, so labeling would be invisible. Trigger: a result-holding leaf (e.g. a future `estimate nongaussian` family). |
| `estimate_svar` experimental extensions | **Defer.** Upstream-marked experimental surface stays out. |
| ForwardDiff-volume internals | **Defer.** Optimizer internals, no CLI shape. |
| Oracle/DGP-recovery test-only helpers | **Defer.** Test-only upstream helpers, never user surface. |
| RWZ rank/order checker | **Enforced upstream, no separate CLI.** `_assert_rwz_identified` runs inside `identify_arias` and `estimate_svar`; violations throw `IdentificationError` → `model/identification` (exit 5). |
| `varindex` | **Wontwrap.** One-line name→index lookup over `StructuralDFM.varnames`; programmatic convenience with no table to render. |
| `refs` / `report` pretty-printers | **Wontwrap as data; `report()` already stderr.** `report()` output rides stderr via `_status_report` (stdout stays data-only); `refs()` emits literature citations — no data shape to render. |
| `TimeSeriesData`-dispatch conveniences | **Wontwrap.** CLI data paths are CSV→DataFrame→Matrix; `TimeSeriesData` objects never cross the CLI boundary. |
| Upstream v1 fixtures | **Wontwrap.** Upstream repo's own regression files (`test/fixtures/serialization/v1/`); test-only, never user surface. |
| Save bundles / `note=` / `compress=` | **Declined.** No `--compress` flag, no bundle/`note=` surface. Upstream kwargs stay available to library users; CLI saves are single-object uncompressed `.jld2`. |
| DGP-library internals (white-noise lint, simulation guide/API ref) | **No-op.** Upstream-internal checks and docs; the CLI documents only leaves it ships. Canonical upstream docs link stands. |
| SV-SVAR `smoother` | **Deliberately not exposed.** Upstream supports only `:ksc` (ArgumentError otherwise) — no choice to offer. |
| TVV/SV knobs on LP leaves | **Not exposed.** Upstream `structural_lp` pins its own `compute_Q` allow-list with no knob channel; TOML knob sections are consumed by the var/vecm/bvar/favar leaves only. |
| Pre-computed-Q injection / diagnostic pre-calls | **No.** `_svec_Q` is consumed only in the `:svec` branch — no generic pre-computed-Q path exists, and a pre-call would double estimation and describe a different rng draw than the rendered estimate. |
| `weak_id` on irf/fevd/hd | **Not surfaced.** Travels with the estimator result at library level; a dedicated identified-shock diagnostic leaf is future work. |
| VFI `optimizer_opts` passthrough | **Deferred with record.** Five `Optim.Options` keys need a typed TOML design; bare-string passthrough is unacceptable and scalar explosion is unjustified with no demand signal. Upstream defaults apply. Revisit on user request. |
| `--smolyak-mu` on PFI/projection | **Rejected as `usage/invalid`.** VFI-only surface; the other solvers stay on the upstream default `μ=3`. |

`--plot` is advertised only when a real `plot_result` method exists. Types without recipes stay plotless (plot-coverage baseline 181/181 at MEMs 1.0.0, no drift).

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

## Standing watches

- **`report()` overhaul:** none landed through 1.0.0; the `_status_report` swallow stands. Re-check on each release.
- **Next-major watch:** MEMs 1.x deprecations, none announced. A future JuMP/Ipopt demotion (#609-shaped, closed with no shipped effect 2026-09-08) or sub-package split (#255-shaped, closed with no shipped effect 2026-09-08) arrives via this watch.
- **Consumed at v1.0.0:** MEMs#609 (JuMP/Ipopt/NonlinearSolve stay required `[deps]` at 1.0.0; weakdeps hold only PATHSolver/XLSX/ZipFile — C060 bundling story and the ~2.3 s cold-start floor stand), MEMs#255 (single-package layout unchanged), MEMs 1.0 major watch (TRIGGERED — this v1.0.0 program was the adaptation series).
