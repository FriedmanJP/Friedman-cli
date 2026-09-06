# Changelog

All notable changes to Friedman-cli are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project adheres to
Semantic Versioning. Releases before v0.6.0 are recorded in the git tag history.

## [Unreleased] — v0.12.1 wave W0 (#171): MEMs pin `=0.9.3` → `=0.9.4`

C038 bump, re-resolved from General (MEMs-only Manifest delta, no new
transitives). T3 4031/4031 green; golden regen zero drift (mocks); docs
captures one attributed regen (`dsge ha solve huggett --method reiter`
`explained_variance` ULP move from the upstream `Xoshiro(1234)` default —
see below); mock-surface PASS with the mock kept a strict subset (none of
the 40 new upstream DGP exports added — no handler consumes them);
plot-coverage 179/179 with neither ADDED nor REMOVED. Hands W1 the J-test
NaN verdicts (GMM *and* SMM under identity weighting) plus two stale
`MersenneTwister` comments, and W2 the DGP-library exposure decision.
Full per-issue ledger (MEMs #790–#807 + #813) with file:line evidence:
`docs/src/commands/not-wrapped.md` (W0/#171 section).

### Decision record

- **W0 (#171): 0.9.4 absorption ledger.** Defer: the 40-export `src/dgp/`
  simulation library (no CLI leaf calls it; W2 decides exposure vs defer
  + T3-harness adoption). No-ops (verified unreachable/display-only):
  `compare_var_lp` off-by-one fix, `_smooth_lp_cv_errors` kwarg gate,
  Johansen `_fmt`, upstream DGP-02–DGP-04/06/07/09–18 test seeding. W1
  scope: SMM `j_test` NaN p-value under identity weighting (matches the
  pre-existing GMM M-29 policy — both leaves render it), Xoshiro comment
  rewords. Watches re-checked: MEMs#609/#255 open with no movement,
  no `report()` overhaul, MEMs 1.0 unannounced.

- **W1 (#172): 0.9.4 correctness moves.** SMM J p-value under identity
  weighting renders `n/a (identity weighting — χ² limit needs efficient
  weighting)` instead of a bare `NaN` (`_estimate_smm`); same NaN guard
  applied to the `_estimate_gmm` J-test, whose verdict branch now reports
  n/a on NaN instead of misreading `NaN < 0.05` as "Cannot reject"
  (`j_test(::GMMModel)` shares the M-29 NaN policy per the W0 ledger —
  through this leaf LP-GMM is just-identified, so the guard is
  defense-in-depth, pinned by T3). T3: new identity-weighting SMM case
  (n/a note, no bare NaN) + GMM identity/twostep cases pinning upstream
  behavior. Stale `MersenneTwister` comments reworded to `Xoshiro`
  (`shared.jl`, `dsge.jl`); CLI-owned `MersenneTwister(seed)`
  constructions untouched. Verified no-ops: `compare_var_lp`
  unreachable (zero `src/` hits, no `policy`/counterfactual transit),
  `estimate_smooth_lp` call passes only `n_knots`/`lambda` (the
  `_smooth_lp_cv_errors` kwarg gate cannot trigger — CLI calls
  `cross_validate_lambda` positionally), Johansen `_fmt` display-only
  (`test johansen` rounds result fields itself).

- **W2 (#173): 0.9.4 DGP-library decision (no feature code).** Defer:
  no `data simulate` leaf in v0.12.1 — a useful family is ~15–20 leaves
  against a patch line, truth+data bundles need envelope schema design
  (upstream returns NamedTuples, not tables), and upstream simulators
  take a positional `rng` (no `seed=` kwarg for `_fwd_seed`); sketch +
  T3 oracle-helper adoption filed as #177 (0.13.0 candidate). T3 harness
  stays hermetic (32 local CSV-path DGPs, pinned streams). No-ops:
  upstream white-noise lint, simulation guide, DGP API reference.
  Watches re-checked at 0.9.4: MEMs#609/#255 open with no movement, no
  `report()` overhaul, MEMs 1.0 unannounced. Full table:
  `docs/src/commands/not-wrapped.md` (W2/#173 section).

## [0.12.0] — 2026-09-06 — MEMs 0.9.3 adoption program (#163–#169)

CLI v0.12.0 adopts MacroEconometricModels **0.9.3**. The machine surface stays
additive: no leaf, option, or flag is removed or renamed.

### Added

- **SVAR expansion** (#166): new `estimate svar` (AB-model ML — `recursive`,
  `blanchard-quah`, and TOML-matrix `a-model`/`b-model`/`ab-model` with `nan`
  marking free parameters) and `estimate svec` (KPSW default plus optional
  `[svec]` long/short-run zero matrices) leaves, both plot-capable with native
  save/load handles; `--id narrative-adrr` on the `irf`/`fevd`/`hd` `var`
  leaves runs ADRR narrative contributions through the Arias pipeline
  (requires `[identification.narrative_contributions]` in `--config`);
  `--id svec` on the `irf`/`fevd`/`hd` `vecm` leaves routes through
  `identify_svec` on the VECM itself (KPSW default, optional `[svec]` zeros;
  IRFs are point-only, `--ci none`); `--id robust-bayes` on `irf bvar`
  renders Giacomini–Kitagawa robust bands from the posterior; `irf var
  --identified-set --summary` selects a set-identified summary
  (`median-target`/`modal-model`/`joint-band`/`sup-t-band`); `test
  identifiability` gains opt-in `lambda-distinct`/`gaussian-count`/
  `label-stability` riders plus `--n-bootstrap`; unknown `--id` values are now
  `usage/invalid` instead of silently falling back to Cholesky. Deferred with
  record: `label_shocks`, K-regime tokens, RWZ checker (enforced upstream).

### Added

- **Universal serialization + reproduce** (#167): the native `.jld2` registry
  grows 73 → **350** types (frozen fallback + mock mirror refreshed; all 73 old
  names still registered, `SERIALIZATION_FORMAT_VERSION` stays 1); the
  DSGE/HA-solution `.fmod` carve-out is **retired** — native round-trips proven
  field-by-field on real MEMs for `DSGESolution` (reloaded solution computes
  IRFs; only load-time `ss_fn` closures differ by design), `SVARModel`,
  `HASteadyState`, and `KrusellSmithSolution` (incl. `manifest.seed`); new
  **`model reproduce`** leaf re-runs a saved handle from its `ReproManifest`
  seed and reports a match verdict plus per-field diffs (honest
  `unverifiable` when no seed was recorded; works on `.jld2`/`.fmod`/`model://`);
  `--seed` is now forwarded as estimators' own `seed=` everywhere 0.9.3
  supports it — BVAR/IRF (existing) plus SV, MFVAR, TVPVAR, FAVAR, SDFM, SMM,
  quantile/robust/SETAR/threshold, NARDL multipliers, DiD, structural LP, PVAR
  bootstrap IRF, conditional forecast, all `identify_*`/non-Gaussian tests,
  wild-cluster bootstrap, MS/SETAR/STAR forecasts, the full policy/OPP family,
  DSGE Bayes estimation + predictives, and Krusell–Smith solves — via one
  `_fwd_seed()` helper that passes nothing when `--seed` is absent (so
  `seed::Int=<const>` defaults are untouched). `model info` now reads the
  container header (`model_info`: writing versions, note, bundle layout)
  without reconstructing the payload, with best-effort dimensions.

### Changed

- MEMs pin `=0.9.0` → `=0.9.3` (#164).
- Explicit no-surface (recorded): no `--compress` flag, no bundle/`note=`
  writers — the CLI stays single-model-per-file and deterministic-default;
  `model info` displays a saved note on the read path. CodecZlib arrives
  transitively with JLD2 (already in the Manifest/bundle, zlib-licensed), so
  no C060 action. Out of scope kept out: `posterior_mode` (no draws, no
  `seed=`), rng-only paths (`historical_decomposition`, VAR/BVAR/ARIMA
  forecasts, `identify_robust_bayes`, DSGE `simulate` leaves which pin their
  own RNG), pre-`#786` `seed::Int=<const>` spec tests, and uncalled helpers
  (`irf_match`, `model_average`, `identify_arias_bayesian`,
  `hansen_linearity_test`, `posterior_predictive_check`).

### Decision record

- **W4 (#168): unexposed 0.9.1–0.9.3 remainder.** Adopted: SDFM `:auto`
  corners (W1), #753 identification-serialization details (W3). Wontwrap:
  `varindex`, `refs`/`report` as data, `TimeSeriesData` conveniences, v1
  fixtures (#770). Deferred: `estimate_svar` experimental extensions,
  ForwardDiff internals (#756), oracle/DGP helpers (#755). No direct
  surface: `compute_Q` registry (reached via `identify_*`). Declined:
  bundles/`note=`/`compress=`. Watches: MEMs#609/#255 (no movement),
  `report()` overhaul (none landed), MEMs 1.0 (not announced), plus
  CLI-filed MEMs#816 (LinearSolve world-age boom on the steady-state
  QR-fallback branch). Full table: `docs/src/commands/not-wrapped.md`.

## [0.11.0] — 2026-08-29

CLI v0.11.0 adopts MacroEconometricModels **0.9.0** (program index #150, waves
#151–#161). The machine surface stays additive: no leaf, option, or flag is
removed or renamed. The only user-visible break is upstream's removal of the
`E[t](...)` grammar — write `x[t+1]`. Native save types grow 56 → **73**.

### Added

- **IO2 network layer** (#153–#155): riders on the existing `io` family
  (`extract --mode/--share/--region`, `footprint --by region`, `sda --factors/--on`,
  `io load --parser csv|icio`, IOData `.jld2` handles); a new **`io bf`** node
  (network, equilibrium, local, elasticities, shock-curve, wedges, misallocation);
  classical + MRIO leaves (`price`, `impact`, `network-stats`, `aggregate`,
  `balance`, `vertical-specialization`, `export-decomposition`, `bilateral-trade`).
  ZipFile/XLSX `.zip`/WIOD paths stay typed `env/missing-extension` (exit 6).
- **RA solvers** (#156): `dsge solve --method vfi|blanchard-kahn`, VFI/PFI knobs,
  TOML `utility`/`beta`/`controls`, `perfect-foresight --sparsity/--max-iter/--tol`.
- **HA expansion** (#157): live `two-asset-hank` and `endogenous-labor` builtins,
  `--hh-solver egm|vfi`, `--distribution young|winberry`, `dsge ha hd`,
  `dsge ha estimate --sampler mh|smc`.
- **Family kinds** (#158–#159): `dsge dcegm` (solve/steady-state/irf/fevd/simulate/transition),
  `dsge lifecycle`, `dsge olg irf|fevd`, `dsge ct irf|fevd` plus two-asset GE/MIT,
  `dsge firm` (Khan–Thomas) and `dsge bank` (Bewley banks).
- **Not wrapped** docs (`docs/src/commands/not-wrapped.md`) recording W9
  dispositions (#160).

### Changed

- MEMs pin `=0.8.0` → `=0.9.0`. Loaders use `ModelSpec` (RA = empty agents, HA =
  `HouseholdSystem`); HA `.jl` SSJ goes through the world-age barrier.
- `E[t](...)` is **not** rewritten — both `.toml` and `.jl` fail as typed
  `config/invalid` with the `x[t+1]` rule.

### Fixed

- Seven pre-existing dead `dsge` routes (#152): `perfect-foresight` uses
  `shock_path=` with a T_periods-row guard; OccBin 1/2 bounds (`>2` →
  `usage/invalid`); nonlinear constraints are `Meta.parse`d to `Expr`;
  `--method pfi|projection` no longer receive `order=`; Krusell–Smith `r_squared`
  renders as a Dict; `dsge bayes * --constraint-solver` no longer passes
  `solver_obj=`. ProjectionSolution control-column length is guarded.
- `io sda --on` is forwarded even when `--factors` is omitted (emission SDA
  was silently running the output path). Projection/PFI/VFI emit a
  `projection_diagnostics` kv (stdout `converged`); `dsge bank steady-state`
  emits the SS policy table so PE vs SS `l_policy` is comparable.

## [0.10.0] — 2026-08-12

CLI v0.10.0 is the **Agent-Contract Hardening** release (program index #135,
waves #136–#143): every machine-facing property of the CLI — the envelope, its
addresses, its failures, its self-description, and its latency — becomes an
enforced, externally-validated contract. The MEMs baseline stays **0.8.0**;
the surface grows 410 → **411 leaves / 20 top-level** with the new `serve`
command.

### Added

- **`friedman serve --mcp`** (#61/#142): the whole registry as a Model Context
  Protocol server over stdio — JSON-RPC 2.0, no external dependency.
  `tools/list` mirrors all 411 leaves with full input schemas; `tools/call`
  reconstructs the exact argv and returns the JSON envelope **verbatim**
  (`isError` mirrors the exit class); in-memory `model://` session handles let
  one session estimate once and run downstream commands against the fit with
  no files and no re-estimation. Warm calls run in ~2 ms — no per-call process
  spawn.
- **Machine-actionable `friedman schema`** (#63/#140): per-leaf draft-07
  `input_schema` (kebab names, enums, defaults, required positionals, and
  `x-cli` argv annotations), per-leaf `tables` (the declared stable keys),
  a root `contract` block (the embedded envelope schema + exit-code taxonomy),
  and `--docs` (the agent guide, baked into the binary). CI metaschema-checks
  every emitted input schema with python-jsonschema.
- **Error envelopes everywhere** (#137): when the argv asks for JSON, every
  failure — including usage/parse errors that die before a command resolves —
  emits exactly one schema-valid error envelope with `error.code`
  (`class/code`) and `error.exit_code` always equal to the process exit.
- **Two new typed domain mappings** (#81/#139):
  `StochasticSingularityError` → `model/stochastic-singularity` and
  `DSGESolveError` → `model/solve` (both exit 5), with actionable hints; the
  `_domain_or_data_error` wrapper no longer shadows specific classes.
- **Latency budgets gate the release** (#79/#141): `tools/bench_release.py`
  runs after the smoke battery on all 3 OSes — `--version` < 3000 ms and first
  `estimate var` < 3500 ms, min of 3 cold runs, enforced on ubuntu. The
  budgets are calibrated to the measured ubuntu cold-start floor of the
  bundled sysimage (~2.3 s runtime boot per invocation, unchanged since
  v0.9.2) plus regression headroom; from these numbers they are never relaxed
  to green a red run.

### Changed

- **Stable envelope `data` keys** (#138): keys are now registry-declared
  addresses, predictable before the command runs — `var_coefficients`, never
  `var_2_coefficients`; option values, data-derived tokens, and estimated
  parameters moved from keys into human-readable titles. Per-variable families
  are keyed `<declared>_<your-variable-slug>`. A CI drift gate
  (`check_table_keys`) validates every emitted key against the declarations —
  over the goldens and over the full T3 envelope dump.
- **Envelope schema v1 hardened** (#136): `data` values are strictly table
  objects (`columns` + `rows`; the dead scalar path is deleted), `meta`
  requires the version trio, `status`/`error` co-occurrence is a top-level
  `oneOf`, `error.code` is pattern-checked. The schema now validates under any
  conformant draft-07 validator; CI cross-validates schema, goldens, and every
  T3-captured envelope with python-jsonschema — the in-repo subset validator
  is fixed (its `additionalProperties` blind spot had cancelled the old
  schema's ambiguous `oneOf` for the repo's whole life) and deduplicated into
  one shared file.
- **Stability policy declared**: the machine surface is the API; envelope
  schema v1 is additive-only from v0.10.0 (a breaking change means
  `schema_version: 2` and a major); 0.x minors are additive-only. The hidden
  snake_case aliases and `FRIEDMAN_LEGACY_OUTPUT` are scheduled for removal at
  v1.0.0.

### Fixed

- The `schema --docs` splitter no longer consumes a path token after a flag.
- The factor-family stale-key class in T3 lookups (12 pre-rename keys) and the
  `build_release.jl` build env missing `schema/` (a precompile failure caught
  by the first latency dispatch runs).

## [0.9.2] — 2026-08-07

CLI v0.9.2 adopts **MacroEconometricModels 0.8.0** (exact pin `=0.7.2` → `=0.8.0`,
program index #121) and wraps its monetary/fiscal policy-analysis surface, taking
the CLI from **387 to 410 leaves** and adding the 19th top-level command.

### Added

- **New top-level `policy`** (W4–W7, #126–#129): structural policy analysis on
  VAR/BVAR/LP/DSGE/HA backends — `policy effects` (incl. sign-identified),
  `policy counterfactual`, `policy optimal`, `policy moments`, the OPP family
  (`opp`, `opp-sequence` — Barnichon-Mesters optimal policy perturbations),
  `policy news`, `policy jacobian ha`, `policy history`, `policy spanning`, and
  `policy sufficiency dsge`. Policy rules/losses are TOML-driven
  (`get_policy_rule`/`get_policy_loss`), and honesty diagnostics
  (rel_residual/spanned/error_path/n_draws_used) are part of the stdout DATA
  tables.
- `nowcast bvar --prior litterman` + hyperparameter knobs (W1, #123).
- `test factor-break` per-series diagnostics (W2, #124).
- `:mp_shocks` bundled dataset (EXAMPLE_DATASETS 11→12) and `data describe`
  first/last-valid columns (W3, #125).
- Dynamic-panel hardening (W10, #131): `estimate preg` Arellano-Bond/
  Blundell-Bond `--collapse`/`--min|max-lag-endo` with load-bearing guards +
  Dynamic Panel Diagnostics table; `estimate piv` Weak-Instrument Diagnostics;
  `predict ologit|oprobit|mlogit --marginal-effects` re-added with real SEs.
- Order-1 `dsge moments` re-enabled (W9, #116) — upstream MEMs#607 fixed the
  order-1 control-covariance defect at 0.7.3.

### Fixed

- **`dsge solve --method perturbation` was dead on every shocked model since
  MEMs 0.7.2** (gx is ny×nv with v=[states; shocks]) — caught and fixed at the
  0.8.0 bump (W0, #122).
- `data dropna --vars` was a TypeError on real MEMs (Vector{SubString}); NaN-not-
  zero policy enforced across the data family (W3, #125).
- `midas --horizon` was inert; factor varnames adopted upstream (MEMs#538) (W10,
  #131).
- Post-exit engine fixes: pre-dispatch globals are leading-only with `-h`
  reserved for help everywhere + a registry reservation guard (#117);
  `check_mock_surface` now sees NamedTuple returns and shape drift — its first
  run caught 6 live drifts including `test granger --all` exiting 1 on every
  real invocation (#118); plot-recipe drift gate + 0.8.0 receiver baseline
  (#95); CSV column names forwarded through the VAR family so IRF/FEVD/forecast
  tables carry the user's variable names (#119).

### Deferred

- The five closure-taking MEMs policy entry points (irf_match, opp_sensitivity,
  robust_weights, FunctionConstraint, counterfactual_history) are recorded as
  deliberate v0.9.2 non-goals in #130; opp_sensitivity is earmarked first for
  TOML specialization at v1.1.

## [0.9.1] — 2026-08-07

CLI v0.9.1 adopts **MacroEconometricModels 0.7.2** (exact pin `=0.7.0` → `=0.7.2`,
program index #104), closing all 14 C053 upstream rider gates in one release and
taking the CLI from **361 to 387 leaves**.

### Added

- **Stage-14 riders un-gated by 0.7.2** (W6–W10): `estimate sarima` +
  `forecast sarima`; `estimate tvpvar`/`mfvar` with `irf tvpvar` and
  `bvar --hyperopt`; `forecast scenario` (Waggoner-Zha conditional forecasts);
  IRF wild/block bootstrap + Kilian bias-corrected bands; `fevd --generalized`
  (Pesaran-Shin); Arias effective sample size; `estimate qreg`/`rdd`.
- **Micro-inference wave** (W10, #112): `estimate reg --cov-type conley`
  (spatial SEs), `estimate preg --absorb` (HDFE), `test wild-cluster`,
  `test anderson-rubin`, and LP-IV MOP effective-F + AR confidence bands.
- `estimate poisson`/`nbreg` + `test dispersion` (W2, #107); GARCH
  `--dist normal|student|ged` (W11, #113).
- `predict`/`forecast ms|ms-ar` (W3, #101); `residuals ologit|oprobit|mlogit`
  re-enabled on MEMs#507 with `--generalized` on the ordered models (W4, #87).
- Native save/load derived from the upstream serialization registry — 6 → **56
  types** (W1, #106).
- HA/OLG/CT Stage-14 audit: `dsge ha accuracy`, `--euler-points` (0.7.2 made
  midpoints the default Euler-accuracy convention), Den Haan on HADSGE (W13,
  #115 — also fixed the broken `.jl` HA model loader, #80).
- `dsge determinacy-map` (config-driven), `dsge moments` closed-form order-2/3,
  `--prefilter` across the `dsge bayes` family, Sims existence/uniqueness on
  `dsge solve` (W12, #114).

### Changed

- **Headline behavior drift at the pin bump** (W0, #105): `estimate_bvar` now
  defaults `hyperopt=:glp`, so every config-less BVAR result changed.
- `estimate lp --method iv` exit-1 fixed (the mock had invented a
  `weak_instrument_test` return surface real MEMs never had).

### Fixed

- `dsge moments --order 1` refused with a typed usage error while upstream
  MEMs#607 was open (order-1 control covariances were provably wrong; orders
  2/3 exact) — re-enabled in v0.9.2 after the upstream fix.
- Plot-coverage audit against the real recipe list (W5, #95): `_maybe_plot` net
  maps a missing `plot_result` method to a typed `model/unsupported` instead of
  an untyped exit 1.

## [0.9.0] — 2026-07-31

CLI v0.9.0 closes milestone **M5c — Surface Expansion**. All twelve wave issues
(C062–C073, #67–#78) are complete, taking the command surface from **312 to 361
leaves** across **18 top-level commands** on the same MacroEconometricModels
0.7.0 baseline — no dependency change from the 0.8.0 line.

### Added

- **Dynamic & cointegrating regression** (C062): `estimate cointreg`/`xtcointreg`
  (FMOLS/CCR/DOLS, single-equation and panel), the ARDL/NARDL family
  (`estimate ardl`/`nardl`, `test ardl-bounds`/`nardl-symmetry`, and a new
  top-level `multipliers nardl`), `estimate pmg` + `test pmg-hausman`, and
  `estimate midas` for mixed-frequency regression.
- **Systems estimation** (C063): `estimate sur`/`3sls` with `predict`/`residuals`.
- **Volatility** (C064): multivariate GARCH (`estimate ccc`/`dcc`/`bekk`), six
  univariate variants (igarch, cgarch, aparch, figarch, fiegarch, garch-midas)
  each with `forecast`/`predict`/`residuals`, plus `test sign-bias`/`nyblom`.
- **Nonlinear time series** (C065): `estimate setar`/`star`/`ms-ar`/`ms`/`threshold`,
  `test hansen-linearity`/`star-linearity`, `forecast setar`/`star`, and
  `residuals` for the four nonlinear fits.
- **State space & nonparametric** (C066): `estimate statespace` — canned
  local-level/local-linear-trend *and* arbitrary linear-Gaussian systems via a
  `[statespace]` config section — plus `estimate tvp`/`kde`/`kernel-reg`/`lowess`
  and `predict`/`residuals statespace`.
- **Regression** (C067): penalized and limited-dependent estimators
  (`lasso`/`ridge`/`elastic-net`/`robust`/`tobit`/`truncreg`/`heckman`),
  `estimate select` for stepwise search, k-class IV (`--method tsls|liml|fuller|kclass`),
  and eight OLS diagnostic leaves (white, glejser, harvey, chow, cusum, cusumsq,
  recursive-residuals, influence) plus `test weak-instrument`.
- **Long memory** (C068): `estimate arfima` with `forecast`/`predict`/`residuals`,
  and `test gph`/`local-whittle`.
- **Test batteries** (C069/C070/C071): seasonal, point-optimal, bubble and EDF
  unit-root tests; residual cointegration; first-generation panel unit-root tests;
  panel cointegration and Dumitrescu-Hurlin causality; and VECM restriction tests
  under a new `test vecm` node.
- **Forecast evaluation** (C072): `forecast evaluate` with metrics, Diebold-Mariano,
  Clark-West, Mincer-Zarnowitz, encompassing and combination.
- **DSGE Bayesian diagnostics** (C073): `dsge bayes mcmc-diag`, `identification`,
  `learning-rate`, `overlap`, `marginal-lik`, `posterior-mode`, `prior-predictive`.

### Fixed

- **19 commands were broken on real MacroEconometricModels while the test suite
  stayed green**, because `test/mocks.jl` defined `Base.getproperty` aliases for
  fields the real package does not have. `check_mock_surface.jl` compared struct
  fields only, so a method-based alias was invisible to it; it now parses every
  mock `getproperty` block and fails on any symbol that is not a real field.
  Affected leaves included `test cips`/`durbin-watson`/`dfgls`/`adf-2break`/
  `gregory-hansen`/`lm-unitroot`/`factor-break`, `fevd bvar`, `hd bvar`,
  `estimate favar --method bayesian`, and `dsge bayes irf`/`fevd`.
- **`predict` discrete-choice leaves failed on every invocation**: three options
  were declared as `String` while their handlers took `Bool`, so the default `""`
  raised a `TypeError` for `predict logit|probit|ologit|oprobit|mlogit`. They are
  now flags, and options no handler accepted were removed.
- **`estimate iv` leaked excluded instruments into the structural regressor
  matrix**, violating the order condition and failing on any realistic
  multi-instrument IV. Column partitioning now follows the standard
  `ivregress` convention.
- **`data load --path FILE` was unreachable** and bundled-dataset loading had nine
  further defects (panel id columns dropped, `:name` typos exiting 1, half the
  datasets undiscoverable). Dataset resolution is now single-sourced in `src/io.jl`.
- **Path validation no longer substring-matches `..`**, which had blocked ordinary
  parent-relative paths with no REPL workaround. Confinement is opt-in via
  `FRIEDMAN_DATA_ROOT` and compares normalized paths.
- The legacy `FRIEDMAN_LEGACY_OUTPUT=1 -f json` writer now sanitizes non-finite
  floats instead of crashing on `Inf`/`NaN`.

### Removed

- `residuals ologit|oprobit|mlogit` now return a typed `model/unsupported` (exit 5)
  pointing at `predict`: MacroEconometricModels defines no `residuals` for those
  models and the mock had invented one. Gated on upstream MEMs#507 (CLI #87).

### Repository

- 21 gitignored-but-tracked files removed from version control (`docs/plans/`,
  `docs/superpowers/`, `data.csv`, `build_app.jl`, `build_sysimage.jl`), plus five
  superseded definitions that nothing referenced. Audit with
  `git ls-files -i -c --exclude-standard`.

## [0.8.0] — 2026-07-29

CLI v0.8.0 closes milestone **M5b — Contract & IO**. Backfilled: this release was
tagged and shipped without a changelog entry.

### Added

- **Input-output analysis** (C049): a new top-level `io` command with 12 leaves —
  `sources`, `download`, `load`, `leontief`, `ghosh`, `multipliers`, `linkages`,
  `key-sectors`, `sda`, `extract`, `footprint`, `baqaee-farhi`. Offline by default
  against a bundled Miller & Blair fixture; `io download` is the only network leaf
  and refuses to fetch under `--offline`/`FRIEDMAN_OFFLINE=1`.
- **Model handles** (C052): `--save-model`/`--model` persist fitted models, using
  MacroEconometricModels' native versioned `save_model`/`load_model` (`.jld2`) for
  the six supported types and an interim `.fmod` fallback for the rest.
- **Reproducibility manifests** (C052): every JSON envelope carries a `manifest` in
  `meta` (seed, threads, os, machine, dependency versions, git, timestamp), and
  `--seed` is forwarded to estimators that accept one so the manifest records it.

### Changed

- **Tidy output** (C051): array-valued results (IRF/FEVD/forecast) render through
  upstream's `long_table`, and coefficient-bearing models through `DataFrame(model)`,
  replacing bespoke wide per-command tables. Leaves that previously split output
  across files now emit one tidy table with a `shock`/`variable` column. Documented
  exceptions stay wide (volatility forecasts, `did estimate`, sign/Uhlig/Arias
  paths, `irf`/`fevd pvar`, `hd`).

## [0.7.0] — 2026-07-19

CLI v0.7.0 re-platforms onto **MacroEconometricModels 0.7.0** (milestone M5a).
The upstream bump adds ~191 exports and makes JuMP + Ipopt required dependencies;
several wrapped outputs and error/logging behaviors change as noted below.

### Added

- **Typed domain errors** (C050, MEMs #245): MacroEconometricModels' `MacroModelError`
  hierarchy is mapped to CLI exit codes — `ConvergenceError`/`IdentificationError`/
  `SingularSystemError` → `model/*` (exit 5), `SerializationError` → `data/serialization`
  (exit 3). A mis-oriented DSGE data matrix now surfaces as `data/orientation`
  (exit 3) with a transpose hint (C054 #142) instead of an internal error.
- **Structured logging** (C050, MEMs #348): library `@info`/`@warn`/`@error` are
  routed to stderr; `--quiet` drops `@info` and keeps `@warn`/`@error`.
- **Bundled solvers** (C060): JuMP (MPL-2.0) and Ipopt (MIT wrapper over the
  EPL-2.0 library, dynamically linked) are now required upstream deps and ship in
  the precompiled release; PATHSolver stays optional and unbundled.

### Changed

- **Dependency pin** `MacroEconometricModels` 0.6.7 → **0.7.0**; `Logging` added
  as a direct stdlib dependency.
- **`dsge bayes` `--params`** (C054 #136): start values pass to upstream as a
  name→value mapping (order-independent, validated against the priors) rather than
  a positional vector.

### Fixed

- **Panel VAR / DiD family regression** (C054): the 0.7.0 bump broke the entire
  `estimate pvar` / `test pvar *` / `irf pvar` / `fevd pvar` / `did *` surface via
  upstream signature and result-shape changes (`xtset`, `estimate_pvar`/`_feols`,
  `pvar_bootstrap_irf`, `pvar_fevd`, `pvar_mmsc`/`pvar_lag_selection`, `LPDiDResult`).
  All are reconciled and now covered by the integration suite.
- **`did event-study`** no longer leaks the Lags/Leads values to stdout (they are
  status output and belong on stderr).

### Verified (no change)

- `dsge bayes compare` marginal likelihoods come from upstream's sound Geweke-MHM
  path and `did test honest` bounds from the Rambachan–Roth implementation
  (C061); the `validity_warning!` mechanism ships with zero active warnings.
- Johansen rank selection and MacKinnon unit-root p-values (C054 #270/#177).

## [0.6.0] — 2026-07-17

CLI v0.6.0 adopts **MacroEconometricModels 0.6.7** (from the Julia General
registry) and wraps the heterogeneous-agent / continuous-time / OLG / X-13
command families that landed upstream. Several wrapped outputs change *numerically*
because upstream reliability fixes are now in the pin — each is cited below.

### Added

- **`dsge ha` — heterogeneous-agent DSGE** (C040): `solve`, `steady-state`, `irf`,
  `fevd`, `simulate`, `distribution-irf`, `inequality-irf`, `simulate-panel`.
  Builtins (`huggett`, `krusell-smith`, `one-asset-hank`, `two-asset-hank`) or a
  `.jl` file evaluating to `HADSGESpec`. Methods: `ssj`, `reiter`, `krusell-smith`.
- **`dsge ha estimate`** (C048): Bayesian estimation of HA-DSGE parameters via
  Random-Walk Metropolis-Hastings. Un-deferred now that **MEMs#228** is fixed in
  0.6.7 (the Kalman observation matrix `Z` is built from the reduction `C` rows).
  Options: `--data`, `--priors`, `--observables`, `--method`, `--n-draws`,
  `--burnin`, `--t-horizon`, `--n-reduced`, `--proposal-scale`, `--adapt-interval`,
  `--measurement-error`, `--seed`.
- **`dsge ct` — continuous-time HA** (C041): `solve` (Aiyagari / two-asset KMV),
  `transition`.
- **`dsge olg` — Blanchard perpetual-youth OLG** (C041): `solve`, `simulate`.
- **`filter x13` — X-13ARIMA-SEATS** seasonal adjustment (C042; pure-Julia MEMs
  port). Raises `env/x13-missing` if the backend is unavailable.
- **`dsge fevd --unconditional`** (C043): asymptotic FEVD for order ≥ 2 perturbation
  (Andreasen et al. 2018); requires `--method=perturbation`.
- **Kebab-case primary leaves with hidden snake aliases** (C044): `gjr-garch`,
  `arch-lm`, `ljung-box`, `pvar hansen-j`. The old snake_case forms still work but
  print a one-line deprecation to stderr (removed in v1.0).
- `validity_warning!` mechanism (C047): the reusable stderr + envelope
  (`warnings[]`) channel for upstream-known-invalid outputs — quiet-proof (never
  suppressed by `--quiet`, since a validity warning is data, not status). No active
  callers at this pin (see "Validity warnings" below).

### Changed

- **MEMs pin → 0.6.7 from the General registry** (C038): CI, release, docs, and
  nightly-pinned use `Pkg.instantiate()`; only canary / nightly-mems-dev track the
  MEMs `dev` git rev.
- **Numeric changes from upstream reliability fixes now in the pin** — regenerate
  any downstream artifacts that pinned old values:
  - VAR standard errors, BVAR marginal likelihood, and PCA factor scaling corrected
    (**MEMs#100**; affects `estimate var` / `bvar` / `favar` / `static`).
  - RWMH burn-in discarded and marginal likelihood replaced with the Geweke modified
    harmonic mean (**MEMs#122**, **#130**; affects `dsge bayes` marginal-likelihood
    numerics and `dsge bayes compare`).
  - `did test honest` is now the proper Rambachan–Roth (2023) sensitivity analysis
    (Δ^RM / Δ^SD sets, Armstrong–Kolesár FLCI) rather than a naive linear bound
    (**MEMs#163**); confidence-interval bounds change.
  - DiD standard errors overhauled (**MEMs#164–#169**); `did estimate` / `did test`
    SE columns change.
  - Unit-root p-values use MacKinnon response surfaces (**MEMs#177**); `test adf` /
    `pp` / `za` / … p-values change.
  - Johansen cointegration-rank off-by-one fixed (**MEMs#270**); `test johansen` and
    `estimate vecm --rank=auto` selection may change.
- DSGE loader hardening (C046): a `.jl` returning `HADSGESpec` under an RA command
  (`dsge solve|irf|…`) raises `usage/wrong-command` (exit 2) pointing at `dsge ha …`;
  a RA `DSGESpec` under `dsge ha` is rejected symmetrically. `linear = true` TOML key
  for pre-linearized specs.

### Fixed

- **DSGE Bayesian priors bridge**: `dsge bayes estimate` / `irf` / `fevd` / `hd` /
  `simulate` / `predictive` and `dsge ha estimate` now convert the `[priors]` TOML
  (`{dist, a, b}`) into the `Dict{Symbol,<:Distribution}` that MEMs requires, instead
  of passing the raw config dict (the wrong type against real MEMs). Supported
  distributions: `beta`, `normal`, `inv_gamma`, `gamma`, `uniform`.

### Validity warnings (C047)

Verified against pin 0.6.7: **no validity warnings ship.** Every upstream defect the
plan targeted — `dsge bayes compare` (MEMs#122/#130) and `did test honest` (MEMs#163)
— is fixed and in the pin (all closed before the v0.6.7 tag). The Appendix-F sweep and
an open-issue scan found no other confirmed invalidity in a wrapped command. The
`validity_warning!` mechanism ships ready for the next such case.
