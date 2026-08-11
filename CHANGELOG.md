# Changelog

All notable changes to Friedman-cli are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project adheres to
Semantic Versioning. Releases before v0.6.0 are recorded in the git tag history.

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
