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

## W0/#171 ledger (MEMs 0.9.4: DGP-01–DGP-18 #790–#807 + #813)

Verified against the `v0.9.4` tag sources (`abd1222`), which diff clean
against the resolved depot copy. Non-test `src/` delta vs 0.9.3: new
`src/dgp/` (11 files) + `MacroEconometricModels.jl` includes/exports;
`MersenneTwister` → `Xoshiro` default-RNG swaps; SMM `j_test` NaN policy
(`gmm/smm.jl`); `compare_var_lp` off-by-one fix (`lp/core.jl`);
`_smooth_lp_cv_errors` unknown-kwarg rejection (`lp/smooth.jl`); Johansen
`show` `_fmt` display normalization (`teststat/show.jl`); new private
`_simulation_smoother` (`core/kalman_kernel.jl`, unexported, no `src/`
callers — exercised only by upstream `test_kalman.jl`); docstring/example
rewords. No `report()`/`show` signature changes, no exports removed or
renamed.

Must-answer resolutions for W1/W2 (W0-branch line numbers):

- **Exact 40-export list** (confirmed live: 40 names resolve): `dgp_var`,
  `lyapunov_gamma0`, `var_irf`, `var_fevd`, `var_hd`,
  `dgp_nongaussian_var`, `dgp_heteroskedastic_var`, `dgp_arima`,
  `dgp_trend_cycle`, `dgp_ar2_peak`, `dgp_lagged_pair`, `dgp_state_space`,
  `dgp_unit_root_pair`, `dgp_vecm`, `dgp_cointreg`, `dgp_panel_var`,
  `dgp_ardl`, `dgp_nardl`, `dgp_pmg`, `dgp_garch_family`, `dgp_sv`,
  `dgp_mgarch`, `dgp_midas`, `dgp_dynamic_factors`,
  `dgp_mixed_frequency_panel`, `dgp_lp_iv`, `dgp_state_dependent_var`,
  `dgp_propensity`, `dgp_hac`, `dgp_cross_section`, `dgp_panel`,
  `dgp_staggered_did`, `dgp_regime_switching`, `dgp_gmm`, `dgp_pce_draws`,
  `dgp_dsge_observed`, `arma_spectrum`, `mm_aggregate`, `logit_ame`,
  `probit_ame`. Zero `dgp_` hits in CLI `src/` (no `data simulate`
  surface) — **defer to W2** (exposure decision + whether T3 adopts
  upstream DGPs/oracles over hand-rolled `test/integration/dgp.jl`).
  Mock stays a subset: nothing added.
- **`j_test` NaN-under-identity hits GMM too, not SMM-only.** The M-29
  policy pre-exists on `j_test(::GMMModel)` (`src/gmm/gmm.jl`: stored NaN
  + `reject_05=false` + message under `:identity`); 0.9.4 aligns
  `j_test(::SMMModel)` and makes `estimate_smm` store `NaN` + `:identity`
  honestly on every non-efficient path. CLI reach: `_estimate_gmm`
  renders `j_test` J/p/df + a `p < 0.05` verdict on stderr
  (`src/commands/estimate.jl:2806-2817`, `--weighting identity`
  reachable); `_estimate_smm` renders stored `model.J_stat` /
  `model.J_pvalue` (`estimate.jl:3436-3437`, identity reachable via
  `[smm] weighting`). CLI always passes `contributions_fn`, so the
  default `two_step` path stays efficient (real χ² p-value) — NaN bites
  only on explicit identity. → **W1** (NaN-`n/a` verdicts + T3 identity
  cases; no identity-weighting T3 coverage exists today).
- **`compare_var_lp`: unreachable.** Zero hits in CLI `src/` and `test/`;
  no transitive reach via `policy`/counterfactual paths (it is a
  top-level MEMs function the CLI never calls). Off-by-one fix is a
  **no-op** for the CLI.
- **`_smooth_lp_cv_errors`: unreachable with user kwargs.** Sole caller
  is `cross_validate_lambda` (forwards `kwargs...`); the CLI calls it
  positionally with no kwargs (`estimate.jl:2243`), and the CLI's
  `estimate_smooth_lp` call passes only its own `n_knots`/`lambda`
  (`estimate.jl:2252`) — never routes user input to the gated kwargs.
  The new `ArgumentError` cannot trigger from CLI paths. **No-op.**
- **Johansen `_fmt`: display-only.** `_fmt` (`src/core/display.jl:152`)
  is a pure number→string formatter (`-0.0`→`0.0`, NaN/Inf guards) used
  only inside `Base.show(::JohansenResult)`; `test johansen` reads
  result fields and rounds them itself (`src/commands/test.jl:1982+`).
  **No-op** (stderr text only, and only when a stat lands on exact
  negative-zero noise).
- **`seed=`/`reproduce` bit-reproduce holds under Xoshiro.**
  `_resolve_repro_rng` builds `Xoshiro(seed)`; `reproduce` reconstructs
  from the recorded manifest seed. Same-`--seed` streams differ vs
  0.12.0 wherever MEMs owns the seed (expected, W3 CHANGELOG caveat);
  determinism and bit-reproduction hold — the C052 byte-identical +
  SV-reproduce T3 cases pass on 0.9.4. CLI-owned `MersenneTwister(seed)`
  constructions (`dsge.jl:2093,3620,3720,3794`, `estimate.jl:3401`) keep
  their streams; the two stale comments (`shared.jl:794`,
  `dsge.jl:3796`) go to **W1** with the J-test verdicts.

| Upstream item | Disposition |
|------|-------------|
| DGP library `#790` (test half) + `#813` (public `src/dgp/`, guide, API ref) | **Defer to W2** (expose vs defer; T3-harness adoption). |
| DGP-02–DGP-04, DGP-06, DGP-07, DGP-09–DGP-18 (`#791`–`#793`, `#795`, `#796`, `#798`–`#807`) | **Test-only upstream.** Seeded fixtures + white-noise lint; no `src/` behavior change, no CLI surface. |
| DGP-05 `#794` (LP truth + `compare_var_lp` fix + kwargs gate) | Behavior delta confirmed **unreachable** (above). No-op. |
| DGP-08 `#797` (GMM DGP + SMM `j_test` NaN) | NaN policy reaches two leaves (above). → **W1**. |
| DGP-01 `#790` (`_fmt`, Xoshiro seeding/docstrings) | Display-only + comment-only on CLI paths. **No-op** (comments → W1 reword). |
| `_simulation_smoother` (new private) | **No surface.** Unexported, no callers. |

## W2/#173 dispositions (MEMs 0.9.4 DGP library: exposure vs defer + T3 adoption)

Verified against the `v0.9.4` tag sources (`abd1222`, `/tmp` clone diffs
clean vs the `Pkg.dependencies`-resolved copy): `src/dgp/` is 11 files,
40 exports (32 truth-returning `dgp_*` simulators pairing the sample with
population truth in a NamedTuple + 8 analytic helpers). Every simulator
takes a positional `rng::AbstractRNG` (e.g. `dgp_var(rng; ...)`); there is
no `seed=` kwarg, so the CLI `_fwd_seed` convention cannot thread through
without a handler-side `Xoshiro(seed)` construction.

| Item | Disposition |
|------|-------------|
| CLI exposure of the DGP library (`data simulate` family) | **Defer to #177** (0.13.0 candidate, sketch recorded there). No v0.12.1 leaf: a useful family is ~15–20 leaves against a patch line; the truth+data bundle envelope needs schema design (upstream NamedTuples are not tables); upstream positions it as a simulation/testing library; zero user demand signal. |
| T3-harness adoption of upstream DGPs/oracles | **Defer to #177; harness stays hermetic.** The 32 local `MersenneTwister`-seeded CSV-path generators in `test/integration/dgp.jl` match the CLI's CSV boundary with pinned streams — swapping to in-memory upstream NamedTuples buys adapter churn across fixtures/goldens. Follow-up adopts only the oracle helpers (`var_irf`/`var_fevd`/`lyapunov_gamma0`) as closed-form T3 assertions per the W12/#114 lesson. |
| Upstream white-noise lint (`test/dgp/test_dgp_lint.jl` + `ALLOWLIST.md`) | **No-op.** Upstream-internal static check over upstream `test/`; nothing crosses the CLI boundary. |
| Upstream simulation guide (`docs/src/simulation.md`) | **No-op; no CLI mirror.** User-facing simulation docs live upstream; the CLI documents only leaves it ships. |
| Upstream DGP API reference (`docs/src/api/simulation.md`) | **No-op; canonical link stands.** `docs/API_REFERENCE.md` already points at the upstream docs as canonical. |
| #790–#807/#813 remainder not absorbed by W0/W1 | **Closed by the rows above.** Test-seeding halves are upstream-test-only; behavior deltas went to W1 (`#797` J-test NaN) or verified no-ops (W0 ledger). No silent gaps. |

## Standing watches (re-checked at 0.9.4 for W2)

- **MEMs#609 (OPEN, no movement):** JuMP/Ipopt/NonlinearSolve still required deps; C060 story and cold-start floor stand.
- **MEMs#255 (OPEN, no movement):** sub-package split undecided; no adapter impact.
- **`report()` overhaul:** none landed (only `show`-body display lines at 0.9.4); the `_status_report` swallow stands.
- **MEMs 1.0 major watch:** not announced (0.9.x line); adaptation pattern holds ready.

W0 audit on `=0.9.4`: T3 **4031/4031** (core 3972 + entry points 59,
exit 0); golden regen zero drift (mocks, as expected); docs captures one
attributed regen — `dsge ha solve huggett --method reiter` 
`explained_variance` `…4282` → `…4043` (2.4e-14: the `_reiter_linearize`
default `MersenneTwister(1234)` → `Xoshiro(1234)` stream move; CLI passes
no rng so the default owns it; string-exact gate, value substantively
identical); `check_mock_surface` PASS (0 hard, allowlist 7/10, mock stays
a subset — no handler consumes the 40 new exports);
`check_plot_coverage` 179/179 neither ADDED nor REMOVED; inventory 453
leaves / 20 top-level unchanged. Manifest delta MEMs-only
(`0.9.3→0.9.4`, identical dep lists — no new transitives). Residual
breakage: none exposed (nothing to fix or file).

## Standing watches (re-checked at 0.9.4 for W0)

- **MEMs#609 (OPEN, no movement):** JuMP/Ipopt still required deps at
  0.9.4; NonlinearSolve likewise. C060 story and cold-start floor stand.
- **MEMs#255 (OPEN, no movement):** split undecided; no adapter impact.
- **`report()` overhaul:** none landed (only `show`-body display lines);
  the `_status_report` swallow stands.
- **MEMs 1.0 major watch:** not announced (0.9.x line); adaptation
  pattern holds ready.

## W0/#179 ledger (MEMs 0.9.5: Smolyak + multi-control VFI #817–#821)

Verified against the `v0.9.5` tag sources (`061a48e`, `/tmp` clone
`src/` diffs clean vs the `Pkg.dependencies`-resolved depot copy).
Non-test `src/` delta vs 0.9.4: `src/dsge/vfi.jl` rewritten Bellman
core + new `src/dsge/vfi_smolyak.jl` (152 lines: sparse grid builder,
Chebyshev-collocation interpolant, shared `_smolyak_*` construction
with PFI) + one `include` line in `MacroEconometricModels.jl`;
`Project.toml` is a version-only change. No exports added, removed,
or renamed. Docs: `changelog.md` / `citation.md` /
`dsge_nonlinear.md` (Smolyak routing/node-count tables, optimizer
routing table, tuning guide). Tests: `test_aqua.jl` + `test_dsge.jl`
only. No `report()`/`show` signature changes.

Must-answer resolutions for W1 (W0-branch line numbers):

- **Exact `vfi_solver` signature** (`vfi.jl:135-161`). New kwargs:
  `smolyak_mu::Union{Integer,AbstractVector{<:Integer}}=2` (:148),
  `optimizer::Symbol=:auto` (:152),
  `optimizer_opts::NamedTuple=(;)` (:153). Everything else keeps its
  0.9.4 name, position, and default.
- **Optimizer set is 4 symbols, not 3** (`_VFI_OPTIMIZERS`, `vfi.jl:692`):
  `(:auto, :grid1d, :fminbox_nm, :fminbox_lbfgs)` — this corrects
  issue #180's title/body, which names `fminbox-lbfgs` only.
  `:fminbox_nm` (derivative-free `Optim.Fminbox(NelderMead())`) is the
  `:auto` choice for control vectors. `:auto` → `:grid1d` iff
  `n_ctrl == 1`, else `:fminbox_nm` (:703); explicit `:grid1d` with
  `n_ctrl != 1` throws `ArgumentError` (:704-707), as does any unknown
  symbol (:701-702).
- **`optimizer_opts` keys** (`vfi.jl:720`):
  `(:iterations, :x_tol, :f_tol, :g_tol, :show_trace)`, mapped onto
  `Optim.Options` (`iterations` default 200 nm / 100 lbfgs;
  `x_abstol`/`f_reltol`/`g_abstol` 1e-8; `show_trace` false). Unknown
  keys throw `ArgumentError` fail-fast — but only when the resolved
  optimizer is not `:grid1d` (`vfi.jl:211-214`). The `:grid1d` branch
  takes `n_choice` and never sees `optimizer_opts`
  (`_vfi_maximize`, `vfi.jl:811-818`); symmetrically the fminbox
  branch takes `optimizer_opts` and never sees `n_choice` (:819-823).
  Both are silently-ignored-knob pairs upstream — W1 scopes the CLI
  guards in both directions, with the wrinkle that `:auto` resolves
  per `n_ctrl`, which is only known after the spec loads.
- **`grid=:auto` routing** (`vfi.jl:196-198`): `nx <= 3` → `:tensor`,
  `nx >= 4` → `:smolyak`. 0.9.4 routed `:auto` → `:tensor` always and
  threw on anything non-tensor (0.9.4 `vfi.jl:164-168`). The CLI
  currently forces `:tensor` (`shared.jl:2099`), so it is insulated
  from the routing change pending the W1 decision.
- **`smolyak_mu` validation** (`_smolyak_level_vector`,
  `projection.jl:180-190`, shared with PFI): scalar `μ >= 0`, or a
  vector of length `nx` with all entries `>= 0` (a `μ_k = 0` pins
  that dimension at level 0); anything else throws `ArgumentError`.
  Validated on the Smolyak path only; the tensor path ignores it
  (`vfi.jl:200-206`). VFI default `μ=2` (41 nodes at `nx=4`;
  PFI's `μ=3` is too rich per-iteration for the refit-every-sweep
  cost).
- **`smolyak_levels::Matrix{Int}`** (`types.jl:392`): `n_blocks × nx`
  level set on the Smolyak path (`vfi.jl:407`), `0×0` on tensor
  (:433). `degree` on the Smolyak path reports `maximum(levels)`
  (:409) — W1's diagnostics row reads the field, not the title.
- **0.9.4 rejected multi-control specs**
  (`n_ctrl == 1 || throw(ArgumentError(...))`, 0.9.4 `vfi.jl:186-188`)
  — a CLI TOML with two `controls` errored. The CLI `controls` value
  is already a vector (`config.jl:407-409` → `controls: a, b`
  synthesis at `shared.jl:1690-1693`), so multi-control specs are
  declarable today and newly solvable. → **W1** (multi-control T3).
- **Threading needs no dispatch change.** `solve(...; method=:vfi)`
  forwards `kwargs...` verbatim to `vfi_solver` (`gensys.jl:315-316`,
  same as `:projection`/`:pfi`), so W1 threads the new knobs through
  `_ra_solve_extra` / `_solve_dsge` (`shared.jl:2036-2179`) only.
- **VFI-capable leaf set: solve/irf/simulate.** Those three specs
  carry `RA_SOLVER_KNOB_OPTIONS` (`dsge.jl:57,93,144`); `fevd`/`hd`
  declare the knobs but handler-reject vfi (`dsge.jl:2187,2841`).
  This corrects the index: `dsge estimate` does NOT carry the knobs
  (no `--method vfi` there).
- **HA `--hh-solver vfi` / PE-VFI: untouched.** Proven by the file
  list: the `src/` delta is `vfi.jl` + `vfi_smolyak.jl` + the include
  line; `heterogeneous/` and the PE solvers are byte-identical.
  **No-op.**
- **Optim is pre-existing**, not new (`Project.toml` `[deps]`,
  compat `"1, 2"`; resolves to **2.3.1**). That lands the
  full-accuracy `:fminbox_nm` path — the `vfi_solver` docstring warns
  Optim v1's `Fminbox(NelderMead())` stalls at boundary optima.
  Manifest delta: MEMs `0.9.4→0.9.5` + routine transitive patches
  (NonlinearSolve stack, Ipopt 1.15→1.16, JSON, SciMLBase),
  197→197 packages, none added or removed. No C060 bundling note.
- **No `seed=`/`rng` kwarg on `vfi_solver`** in either version — the
  `--seed` story is unchanged (global-RNG reproducibility only, same
  as the other rng-only families).

| Upstream item | Disposition |
|------|-------------|
| `#817` Smolyak grid + Chebyshev-collocation interpolant | → **W1** (`--grid smolyak`, `--smolyak-mu`). |
| `#818` control-vector Bellman optimizer | → **W1** (`--optimizer`, `optimizer_opts` design, multi-control T3). |
| `#819` Smolyak + multi-control wiring into `vfi_solver` | → **W1** (`auto`-routing decision, knob-scoping guards). |
| `#820` tests/docs/benchmarks | **No-op.** Upstream tests + solver docs; nothing crosses the CLI boundary. |
| `#821` anisotropic + adaptive Smolyak levels | → **W1** (vector `--smolyak-mu`). |
| `test_aqua.jl` change + changelog/citation entries | **No-op.** Upstream lint + release docs. |

W0 audit on `=0.9.5`: T3 **4046/4046** (core 3987 + entry points
59, exit 0) — the +15 vs the W0-time 4031 is exactly the 15 `@test`s
W1/#172 added (identity-weighting SMM/GMM cases), verified by diff;
zero bump drift. Golden regen zero drift (mocks, as expected); docs
captures OK (6 blocks current, no regen); `check_mock_surface` PASS
(0 hard, allowlist 7/10, mock stays a subset — no new exports to
consume); `check_plot_coverage` 179/179 neither ADDED nor REMOVED;
inventory 453 leaves / 20 top-level unchanged. Manifest delta:
MEMs-only + routine transitive patches (NonlinearSolve stack, Ipopt,
JSON, SciMLBase), 197→197 packages, Optim pre-existing at 2.3.1
(full-accuracy `:fminbox_nm`). Residual breakage: none exposed
(nothing to fix or file).

## Standing watches (re-checked at 0.9.5 for W0)

- **MEMs#609 (OPEN, no movement):** JuMP/Ipopt/NonlinearSolve still
  required deps; C060 story and cold-start floor stand.
- **MEMs#255 (OPEN, no movement):** split undecided; no adapter impact.
- **`report()` overhaul:** none landed (delta is VFI-only); the
  `_status_report` swallow stands.
- **MEMs 1.0 major watch:** not announced (latest release 0.9.5);
  adaptation pattern holds ready.
- **Upstream OPEN #814/#815/#816:** watches, not scope (#816 is a
  `compute_steady_state` error-path shape question — stays
  upstream-gated per the standing rule).

## W1/#180 appendix (MEMs 0.9.5 VFI absorption: decisions + notes)

- **`auto`-routing decision: pass `:auto` through.** Evidence (real
  MEMs 0.9.5): on `nx=2`, `auto`→tensor bit-identical to explicit
  tensor (same it/res/V); on `nx=4`, `auto`→smolyak bit-identical to
  explicit smolyak (V gap 0.0) with 41 nodes (`N(4,2)`). Rationale:
  upstream-intended (the tensor grid is intractable at `nx ≥ 4` —
  12⁴ nodes at the default `--n-grid 12`); `nx ≤ 3` behavior is
  bit-identical so nothing regresses; explicit `--grid
  tensor|smolyak` still overrides. T3 pins both identities plus the
  closed-form node counts. The only behavior move is `nx ≥ 4`
  default solves (tensor → Smolyak), noted in the CHANGELOG.
- **`optimizer_opts`: deferred with record.** Five keys
  (`iterations`/`x_tol`/`f_tol`/`g_tol`/`show_trace`) forwarding to
  `Optim.Options` need a typed design (TOML section vs scalar
  subset); a bare string passthrough is unacceptable and scalar
  explosion is unjustified with no demand signal. Upstream defaults
  apply (200/100 iters, 1e-8 tols). Revisit on user request.
- **`--smolyak-mu` is VFI-only.** `pfi_solver`/`collocation_solver`
  accept `smolyak_mu` (pre-existing surface the 0.9.5 release did
  not touch) but stay on the upstream default `μ=3`; exposing it
  there is a separate feature with no T3 demand. PFI/projection +
  `--smolyak-mu` → `usage/invalid`, honestly messaged.
- **Knob-scoping rule: provably-dead explicit combos are rejected;
  the `auto` corners stay permissive and documented.** Upstream
  silently ignores the losing knob in each pair, so accept-and-ignore
  would lie: `--n-grid`×`--grid smolyak`, `--degree`×`--grid smolyak`
  (tensor-path export only — the Smolyak path reports
  `maximum(levels)`), `--smolyak-mu`×`--grid tensor`,
  `--n-choice`×`--optimizer fminbox-*` are all `usage/invalid`, as is
  `--optimizer grid1d` on an explicitly multi-control model (post-load
  check — `n_ctrl` needs the spec).
  `--grid auto` / `--optimizer auto` (or unset) with the same knobs
  stay allowed, since resolution needs the solved model; help text
  says so. T3 pins both the rejections and the leniency.
- **`grid1d` + default (undeclared) controls → `data/invalid`
  (exit 3).** With empty `bellman_controls` the count resolves
  inside upstream (non-state endogenous), whose `ArgumentError` maps
  to `data/invalid` like any shape mismatch. T3 pins exit 2
  (explicit) vs exit 3 (default) side by side.
- **The `μ=2`-vs-tensor gap is discretization, not a bug.**
  Measured on the T3 RBC (`nx=2`, default wide `k` bounds): gaps
  8.93 (`μ=2`) → 1.23 (`μ=3`) toward tensor; tight-tol `μ=2`
  unchanged (109.806 both); Howard-0 similar gap. A degree-2
  polynomial over the 10× capital range simply carries units of
  approximation error. T3 therefore pins the μ-refinement property
  and a garbage-excluding band, never tight agreement.
- **`collocation_nodes` are unit-cube on both paths**
  (`Matrix{T}(nodes_unit)`, `vfi.jl` solution construction) — so the
  `vfi_value_function` table's state-named coordinate columns show
  unit values, and `evaluate_value` (physical levels) disagrees with
  node coordinates by construction. Pre-existing on tensor (not a
  0.9.5 regression); out of scope to re-render here. Follow-up:
  #182.
- **NM-vs-LBFGS fixed-point gap on labor3 (upstream solver
  behavior).** Both converge (`res ≈ 1e-4`) but to V's 1.1 apart —
  distinct local maxima of the 2-control Bellman RHS (labor has no
  disutility cost, so the maximizers sit near the `n` bound
  differently). T3 asserts convergence + same-path bit-identity,
  never cross-optimizer agreement. `lbfgs` on 2 controls costs
  ~150 s (central finite differences) and is upstream-tested
  (#818); the CLI threads all four optimizer values through one map
  lookup, pinned on 1 control.
- **Round-6 `m_r=60.01` anomaly: unreproduced, T3 arbitrates.** One
  experiment script shape twice produced `V=60.014125` on the
  auto→nm path where 15+ other solves (fresh processes, bisects,
  alias test) give `58.8960206283` bit-exact; post-lbfgs re-evals
  rule out cross-solve corruption. The T3 bit-exact auto==nm
  assertion is the arbiter — T3-RESULT-PENDING.
- **Multi-control reachability map (the hunt, condensed).**
  `@dsge utility:` requires exactly one consumption symbol, but
  `controls:` is n-ary — so `utility: log(c)` + `controls: c, n`
  parses while 0.9.4 threw at solve time. Of the candidates: `[c,i]`
  is fundamentally unsolvable (static resource constraint → zero
  G1 control columns, and no defining equation for `i`); plain
  labor fails default-guess SS (`n^(-α)` at `n=0`); cleared
  denominators fix SS but residual inference needs one equation
  with LHS exactly `v[t]` per control (`_lhs_defines` is
  syntactic); the `n[t] = 1 - …` rearrangement (exact, same zeros)
  satisfies it. Result: labor3 solves end-to-end on the
  CLI-faithful path (default SS, no closures). No `.jl` closure
  smuggling is needed or supported.
- **4-state SS lesson.** Unscaled `exp(a1+a2+a3)` puts `e³ ≈ 20×`
  output at the default guess, and Newton wanders to `k<0`
  (`DomainError`); scaling to `/3` reproduces rbc1's initial
  residual and converges. (Also: a 3-state default-grid tensor VFI
  costs ~13 min — tensor T3 cases always shrink `--n-grid`.)
- **`dsge simulate` antithetic fix (pre-existing, zero
  coverage).** `simulate(::ProjectionSolution)` takes only
  `shock_draws`/`seed`/`rng` (real `simulation.jl:206`), so the
  unconditional `antithetic=` kwarg made EVERY
  projection/pfi/vfi `simulate` exit 1 with `internal/error`. Fixed
  by type-branching (`seed=` forwarded, stderr note when
  `--antithetic` is set); T1/T2 + T3 regression (tensor + smolyak
  + seed); the mock now rejects `antithetic` with `MethodError`
  parity so a regression fails loudly instead of hiding again.
- **Mock `@dsge` utility-quote fix (pre-existing, latent).**
  The mock spliced `utility:` expressions bare into the
  `ModelSpec` constructor, evaluating `C` in the caller scope
  (`UndefVarError`) — reachable on the first-ever T1/T2
  VFI-success test (only the config-error path existed).
  `QuoteNode` now mirrors real unevaluated storage.

## W0/#185 ledger (MEMs 0.9.6: Lewis TVV-ID + BB SV-SVAR #823–#827)

Verified against the `v0.9.6` tag sources (`51a2588`, `/tmp` clone
`src/` diffs clean vs the `Pkg.dependencies`-resolved depot copy
`~/.julia/packages/MacroEconometricModels/xHvag`).
Non-test `src/` delta vs 0.9.5 is PURELY ADDITIVE — 1096 insertions,
0 deletions across 8 files: new `src/nongaussian/tvv_common.jl`
(245 lines: SV/TVV shock simulators, Q-alignment test support) +
`lewis_tvv.jl` (291) + `sv_svar.jl` (456) + 3 `include` lines;
`core/identification.jl` +11 (2 `compute_Q` branches + 2 registry
tuples + doc); `core/serial/registry.jl` +2;
`plotting/svar_statid.jl` +69 (2 `plot_result` methods);
`summary_refs.jl` +11 (1 ref entry + type refs + 2 `refs`
methods); `Project.toml` version-only. 4 new exports
(`identify_lewis_tvv`, `identify_sv_svar`, `LewisTVVResult`,
`SVSVARResult`), none removed or renamed. Docs: `id_tvv.md` /
`id_sv_svar.md` / changelog / citation / API pages. Tests: new
`test_lewis_tvv` / `test_sv_svar` / `test_tvv_common` + `id_dgps`
fixtures + #828 FAST-gates. No `report()`/`show` signature
changes (2 new `show` methods for the 2 new types, additive).

Must-answer resolutions for W1 (upstream tag line numbers; CLI
lines on the W0 branch):

- **Exact `identify_lewis_tvv` signature**
  (`lewis_tvv.jl:211-220`): `(model::VARModel{T}; K=5,
  lags=collect(1:K), weighting=:two_step, hac=true, bandwidth=0,
  n_starts=10, max_iter=100, tol=1e-8, rng)` — takes a FITTED
  VARModel (the CLI fits, then calls). All guards `ArgumentError`:
  `weighting` in one_step/two_step/cue; `n_starts >= 1`; `lags`
  nonempty and `>= 0`; `n >= 2`; lags supply `>= n(n-1)/2`
  conditions (order); `T_eff - maxlag >= 100`.
- **`J_pvalue` is NaN under `:one_step`** (`lewis_tvv.jl:179-181`,
  same convention as `estimate_gmm`) → W1 renders via the
  M-29/#172 n/a policy, never a bare NaN or a misread verdict.
- **`LewisTVVResult`: 18 fields in order** (`lewis_tvv.jl:56-75`):
  `B0 Q theta vcov se J J_pvalue K lags weighting converged
  iters weak_id id_strength message shocks varnames shock_names`.
  `varnames` is copied from the model (the #119 adoption flows
  automatically); `shock_names` are `"Shock j"`. `weak_id` — not
  `converged` — is the identification check.
- **Exact `identify_sv_svar` signature**
  (`sv_svar.jl:278-291`): `(Y::AbstractMatrix, p::Int;
  hetero=trues(n), smoother=:ksc, maxiter=500, tol=1e-3,
  b_iter=5, gibbs_burn=5, gibbs_draws=100, init=:ols_chol,
  phi_init=0.9, s_init=0.2, theta_grid=12, c=1e-5, rng)` —
  takes RAW LEVELS + `p` (runs its own OLS/GLS on rows `p+1:T`).
  All guards `ArgumentError`: `smoother == :ksc` ONLY (do not
  expose — upstream offers no choice); `n >= 2`; `p >= 1`;
  `Te >= 100`; `hetero` length `n`; `any(hetero)`;
  `maxiter >= 1`; `tol > 0`; `init` in haar/ols_chol.
- **`SVSVARResult`: 12 fields in order** (`sv_svar.jl:65-78`):
  `B A c mus rhos sigmas hetero H_smooth loglik converged
  iters message`. NO `varnames`/`shock_names` (W1 supplies names
  from the CSV side); `A` is per-lag matrices (rendering design
  for W1); homoskedastic shocks carry NaN SV entries
  (`mus`/`rhos`/`sigmas`/`H_smooth`) — render honestly.
- **SV cost is MCEM-heavy** (`maxiter=500` x
  `gibbs(5+100)` x `n`; upstream FAST-gates its own recovery
  tests in #828): T3 must use tiny settings. Single-start CLI
  (the docstring advises multi-`rng` starts in applied work);
  `rng` kwarg only, no `seed=` — global-seed story unchanged
  (same for Lewis).
- **`compute_Q` routing (the per-family map).** The single
  generic method is on `VARModel` (`identification.jl:868`);
  both new branches forward `kwargs`+`rng` (Lewis takes the
  model; SV-EM takes `model.Y`/`model.p` and solves Q via the
  Cholesky factor — VAR-slope re-estimation ignored at this
  layer). VECM `irf`/`fevd`/`hd` convert via `to_var` and
  forward `method`+kwargs (`vecm/analysis.jl:47-85`;
  svec/long_run take the svec path). BVAR runs per-draw
  VARModels with kwargs (`bvar/utils.jl:99/126`) and
  sign-permutation column matching — both new methods match
  (`_should_match_columns`, :741-743, plus their
  `(true,false,false)` tuples). LP routes via the auxiliary
  VAR (`lp/core.jl:440/555`); FAVAR/SDFM via `factor_var`
  (`factor/structural.jl:587/950`). PVAR has no `compute_Q`
  path (unaffected). `kwargs` threading confirmed at
  `core/irf.jl:231-239` (+ bias-correct re-ID :263-271).
- **Registry 25→27** (count-verified 27 tuples):
  +`(:lewis_tvv, true, false, false)`,
  +`(:sv_em, true, false, false)`.
- **Serialization 350→352.** Both types registered
  (`registry.jl:128/133`; runtime `haskey` true; the CLI
  derived set counts 352). The "drop new types" commit
  (`e836444`) removed them from `api.md`'s table mid-PR; the
  serialize commit (`4a90946`) registered them ("generic
  positional reconstruction covers
  Symbol/BitVector/Vector{Matrix}") and re-added them —
  final state round-trips both, guarded by the `api.md:665`
  table/registry drift check.
- **Plotting +2 methods, 0 removed**
  (`plotting/svar_statid.jl`): `LewisTVVResult`
  `view=:mixing` (B0 heatmap); `SVSVARResult` `:B` (impact
  heatmap) / `:volatility` (`H_smooth` lines); unknown view
  → `ArgumentError`. Plot audit expects ADDED=2, REMOVED=0.
- **#823 DGP infra: test-side, no CLI exposure.**
  `tvv_common.jl` adds no exports (the release's only 4 new
  exports are #824/#825's); `simulate_sv_shocks` /
  `simulate_tvv_dgp` / `align_Q` / `q_distance` /
  `check_orthogonal` are internal utilities. T3 may use
  `simulate_tvv_dgp` as a DGP (W1 test-harness decision);
  exposure questions belong to #177, not this program.
- **#828 is test-only** (5 `test(ci)` commits — FAST-gates,
  Optim-gate drop, runner/`id_dgps` guards — + merge; no
  `src/` behavior in the compare file list).
- **Optim is pre-existing** (the rotation M-step uses
  `Optim.LBFGS`; the Manifest delta is MEMs-only, 198→198
  both envs, nothing added/removed — integration
  additionally stamps the Friedman path dep
  v0.12.1→v0.12.2). No C060 bundling note.
- **CLI `--id` inventory for W1** (descriptions are
  hardcoded per-leaf; the MAP enforces): `irf`
  var :29 / bvar :73 / lp :128 / vecm :156 / favar :206 /
  sdfm :226 (tvpvar + pvar declare no `--id`); `fevd`
  var :28 / bvar :54 / lp :77 / vecm :100 / favar :142 /
  sdfm :161; `hd` var :34 / bvar :55 / lp :77 / vecm :99 /
  favar :121; `estimate sdfm` (`estimate.jl:1425`);
  `forecast sdfm` (`forecast.jl:527`).

| Upstream item | Disposition |
|------|-------------|
| `#823` shared TVV/SV DGP infra + fixtures | **No-op** for the CLI (internal test infra, no new exports). T3-harness use of `simulate_tvv_dgp` is a W1 decision; exposure → #177. |
| `#824` Lewis TVV-ID | → **W1** (`--id` value, weighting/n_starts/lags/hac knobs, J/weak_id rendering). |
| `#825` BB SV-SVAR EM | → **W1** (`--id` value, hetero/init/maxiter design; `smoother` NOT exposed). |
| `#826` `compute_Q` wiring | → **W1** (map extension per the verified per-family acceptance). |
| `#827` recovery table/docs/serialization | Split: serialization → **W1** (types flow automatically; `model info` + T3); recovery table/docs → **no-op**. |
| `#828` CI/test gates | **No-op** (test-only). |
| `#609` / `#255` closures | → recorded dispositions in Standing watches below (rows consumed). |

W0 audit on `=0.9.6`: T1/T2 exit 0; T3 **4084/4084** (core,
19m13s) + 59/59 entry points — identical counts to the 0.12.2
exit, zero bump drift. Golden regen zero drift (mocks, as
expected); docs captures OK (6 blocks current, no regen);
`check_mock_surface` PASS (0 hard, allowlist 7/10, mock stays a
subset — the 4 new upstream exports not consumed);
`check_table_keys` PASS (453 leaves); `check_plot_coverage`
179→181 (ADDED `LewisTVVResult` + `SVSVARResult`, REMOVED
none — baseline updated; both are W1 sweep-A plot-flag
candidates); inventory 453 leaves / 20 top-level unchanged.
Manifest delta: MEMs-only (0.9.5→0.9.6), 198→198 packages both
envs, nothing added/removed (integration additionally stamps
the Friedman path dep v0.12.1→v0.12.2). Residual breakage:
none exposed (nothing to fix or file).

## Standing watches (re-checked at 0.9.6 for W0)

- **MEMs#609 (CLOSED completed 2026-09-08, no shipped effect —
  row consumed):** manual close by chung9207, no comments, all 5
  checkboxes still open, no linked commit; MEMs `main`-branch
  `Project.toml` still lists JuMP/Ipopt/NonlinearSolve under
  `[deps]` with `[weakdeps]`/`[extensions]` holding only the
  pre-existing PATHSolver/XLSX/ZipFile entries — the demotion
  landed nowhere (neither 0.9.6, whose `Project.toml` delta is
  version-only, nor `main`). Treated as decided-declined/deferred.
  C060 story + ~2.3 s floor stand.
- **MEMs#255 (CLOSED completed 2026-09-08, no shipped effect —
  row consumed):** same close shape (manual, no comments, boxes
  open); `main`-branch `src/` is still the single package;
  adapter import paths unaffected. Corroboration: tracker
  MEMs#373 closed the same minute (program wind-down, not new
  work landing).
- **`report()` overhaul:** none landed (additive delta); the
  `_status_report` swallow stands.
- **MEMs 1.0 major watch:** not announced (latest release 0.9.6);
  adaptation pattern holds ready. Any future #609/#255-shaped
  move arrives via this watch.
- **Upstream OPEN #814/#815/#816:** watches, not scope (#816 is a
  `compute_steady_state` error-path shape question — stays
  upstream-gated per the standing rule).

## W1/#186 appendix (TVV/SV exposure decisions)

- **Knobs are TOML-first** (`[identification.lewis_tvv]` /
  `[identification.sv_svar]`, the uhlig precedent): weighting /
  hetero_shocks / maxiter / gibbs_burn / gibbs_draws / init.
  Zero new CLI options (avoids a `--weighting` vocab collision
  with smm's different choices and `--n-starts`/`--max-iter`
  meaning drift vs estimate svar). Lewis K/lags/n_starts/
  max_iter/hac/bandwidth/tol and SV tol/b_iter/theta_grid/
  phi_init/s_init/c stay on upstream defaults (deferred with
  record — the #180 optimizer_opts precedent).
- **`smoother` deliberately NOT exposed**: upstream supports
  only `:ksc` (ArgumentError otherwise) — no choice to offer
  (the pruned-flag lesson).
- **LP leaves: methods flow, knobs stay default.** Upstream
  `structural_lp` pins its own compute_Q allow-list
  (lp/core.jl:440-443 — horizon/checks/max_draws/transition/
  regime/rng only), so lewis/sv knobs have no channel there;
  T3 caught the `weighting` MethodError and the knob merge was
  reverted before merge. Same as the pre-existing uhlig-knob
  behavior on LP. TOML knob sections are consumed by the
  var/vecm/bvar/favar leaves.
- **No Q-injection / no diagnostic pre-call**: `_svec_Q` is
  consumed only in the `:svec` compute_Q branch
  (identification.jl:952-953) — no generic pre-computed-Q
  path exists. A diagnostic pre-call would double estimation
  (MCEM minutes for SV) AND describe a different rng draw
  than the rendered estimate. The CLI mirrors the library
  `irf(model; method=...)` call 1:1, same as the existing
  stat-ID methods (gmm-moments/markov_switching/garch render
  no estimator diagnostics either).
- **J-n/a ledger correction**: the W0 ledger's "W1 renders via
  the M-29/#172 n/a policy" is moot — no J is rendered on
  these paths (one_step's NaN J_pvalue never reaches a table),
  so there is nothing to render. The policy stands for leaves
  that render J (gmm/smm).
- **weak_id travels with the estimator result** (library
  level); not surfaced on irf/fevd/hd (same as
  MarkovSwitching convergence). A dedicated identified-shock
  diagnostic leaf is future work, not this wave.
- **fevd bvar fix (pre-existing silent-ignore, found by the
  W1 sweep)**: `--id` was validated nowhere and threaded
  nowhere — every --id rendered cholesky numbers under the
  requested method's title. Now validates against the base
  map + threads (irf/hd bvar sibling parity). T1/T2 + T3
  regression pinned (invalid --id → usage/invalid).
- **SDFM: estimation-gated, methods flow to the upstream
  allow-list** (structural.jl:161-167 — excludes lewis/sv AND
  several existing methods): out-of-set --id → upstream bare
  ArgumentError, which escaped as exit 1 (found by the W1
  adversarial probe: `irf sdfm --id lewis-tvv`). Fixed with a
  loader-level `throw(_domain_or_data_error(...))` wrap
  (shared.jl `_load_and_estimate_sdfm`) → data/invalid, exit 3.
  No allow-list mirror (drift risk); enabling needs upstream
  support (MEMs#830 filed). sdfm --id descriptions stay on
  the curated safe subset.
- **estimate svar / test identifiability / policy /
  predict+residuals: untouched with record.** estimate svar
  is the classical AB-pattern estimator (recursive/BQ/A/B/AB
  — estimate.jl:1346/3112); statistical-ID doesn't apply.
  identifiability tests data properties (test.jl:177/2065),
  not estimators. policy + fitted declare no --id.
- **Plot flags: none.** No CLI leaf returns
  LewisTVVResult/SVSVARResult (irf/fevd/hd return response
  objects), so the two new upstream recipes have no CLI
  call site. Plot-coverage ADDED=2 closed with this record.
- **Bootstrap × identification cost**: irf var defaults to
  --ci bootstrap × 1000 reps, each re-identifying (GMM 10
  starts / MCEM). Same shape as the existing expensive ids
  (markov_switching/garch); T3 uses --ci none throughout.
  No action (estimator economics, not a CLI defect).
- **Review hardening (pre-existing defects, W1-exposed)**:
  (1) `_irf_var`'s `irf(model...)` call had no wrap, so the
  upstream hetero guards (lewis-tvv n≥2 / T_eff≥100,
  lewis_tvv.jl:227/237) escaped as exit 1 — now
  `throw(_domain_or_data_error(e, "VAR IRF"))` (exit 3). The
  first attempt (bare-ArgumentError branch in
  `_domain_error_class`) was reverted: it broke the pinned
  taxonomy contract and would have hidden missing wraps
  suite-wide. (2) `_build_prior` indexed
  `prior_cfg["lambda1/2/3"]` directly, so EVERY BVAR-family
  `--config` without `[prior.hyperparameters]` KeyError'd
  (exit 1) — now `get` with the documented defaults
  (0.2/0.5/1.0). (3) `ID_METHOD_MAP` pin 16→18 + entry
  assertions for the two new methods.
- **sv-em limits observed (typed, no action)**: `irf vecm
  --id sv-em` → upstream IdentificationError (non-orthogonal
  Q, ‖Q'Q−I‖≈6e-4, budget-invariant) → model/identification;
  `fevd bvar --id sv-em` → all posterior draws unidentified
  at draws≤30 → model/identification. Both are
  estimator-raised and correctly typed; no CLI defect.
  T3 pins the vecm exit class.
