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
