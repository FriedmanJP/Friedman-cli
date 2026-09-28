# test

**Goal:** decide what the data are — stationary or integrated, cointegrated or spurious, linear or nonlinear, well-specified or broken — before estimation. Every leaf fits (or takes) a model and reports a named test with a **null hypothesis**, a statistic, and a p-value or critical-value decision. Run the test first, then choose the estimator the verdict points at.

Full option tables for every leaf live in the [generated test reference](generated/test.md). This guide gives the decision logic: which null each family tests, how to read the verdict, and where the traps are.

```bash
friedman test unit-root adf :nile --trend=constant
friedman test coint johansen :denmark --lags=2 --trend=constant
friedman test serial white :stackloss --dep=stack.loss
```

---

## Unit roots: the workhorse decision

**Goal:** classify each series as **stationary** (I(0)) or **integrated** (I(1)) so downstream estimators get the right input. The single most consequential diagnostic choice in time-series work: a VAR in levels on I(1) data without cointegration is spurious, and differencing a stationary series throws away information.

**Dataset:** a single-column CSV, or a bundled level series such as `:nile`. One column per invocation (`--column`/`-c`, 1-based).

```bash
friedman test unit-root adf :nile --trend=constant
friedman test unit-root adf :nile --trend=trend --max-lags=8
friedman test unit-root kpss :nile --trend=constant
friedman test unit-root pp :nile --trend=constant
friedman test unit-root np :nile --trend=constant
```

**Interpretation.** The nulls come in opposite pairs — run both sides before concluding:

| Leaf | H0 | Rejection means |
|------|----|-----------------|
| `unit-root adf`, `unit-root pp`, `unit-root np` | **unit root** | stationary |
| `unit-root kpss` | **stationary** | non-stationary (reversed null) |
| `unit-root ers`, `unit-root dfgls` | **unit root** (point-optimal / GLS-detrended, higher power) | stationary |
| `unit-root za`, `unit-root lm-unitroot`, `unit-root adf-2break`, `unit-root fourier-adf` | **unit root** allowing breaks | stationary around a break |
| `unit-root fourier-kpss` | **stationary** allowing smooth breaks | non-stationary |
| `unit-root hegy` | **unit root at each seasonal frequency** | no unit root at that frequency |
| `stability sadf`, `stability gsadf` | **unit root** vs the right-tailed explosive alternative | bubble behaviour |

The confirmatory pattern is ADF-rejects plus KPSS-fails-to-reject (stationary), or ADF-fails-to-reject plus KPSS-rejects (unit root). Agreement in only one direction is weak evidence — say so and difference with care.

**Pitfalls.** `za` takes `--trend intercept|trend|both`; `lm-unitroot` takes `--breaks 0|1|2` with `--regression level|trend`; `adf-2break` takes `--model level|trend|both`; the Fourier leaves take `--regression constant|trend` plus `--fmax`. These vocabularies differ per leaf and are not interchangeable. `ers` takes a `--trend` **flag** (constant-only by default, needs 30+ observations). `hegy` reports one row per frequency with its own critical value — there is no single p-value; t-ratios are left-tailed, harmonic F-tests right-tailed. `sadf`/`gsadf` simulate their critical values (`--mc-reps`, `--seed`, `--cv asymptotic|wildboot`); an empty episode table is a valid answer, not a failure. A break test that ignores a visible level shift has no power — that is what `za`, `lm-unitroot`, and `adf-2break` are for, not a larger `--max-lags`.

Reference: [generated test reference](generated/test.md).

---

## Long memory: is it I(d)?

**Goal:** estimate the fractional integration order **d** when a series looks too persistent for I(0) but too mean-reverting for I(1). Complements `estimate univariate arfima`, which fits the full parametric model.

```bash
friedman test gph :nile --column=1
friedman test gph :nile --bandwidth=32 --trim=1
friedman test local-whittle :nile --column=1
friedman test local-whittle :nile --bandwidth=32
```

**Interpretation.** Both leaves test H0: d = 0 with a two-sided normal z. `d > 0` is long memory; `d ≥ 0.5` is non-stationary long memory. `gph` is the Geweke-Porter-Hudak log-periodogram regression; `local-whittle` is the Robinson semiparametric Whittle estimator with a minimized objective. Default bandwidth is ⌊√T⌋ (`--bandwidth`/`-m`).

**Pitfalls.** The estimate moves with the bandwidth — report the bandwidth beside the estimate, and distrust a verdict that flips under a nearby bandwidth. `--trim` (GPH only) drops contaminated low frequencies. Neither leaf replaces a break test: a level shift mimics long memory, so run `za` first on suspect series.

Reference: [generated test reference](generated/test.md).

---

## Randomness and nonlinearity

**Goal:** test whether a series (often a fitted residual) is independent noise, and whether a linear AR is the right conditional mean. Rejection sends you to a nonlinear estimator (`estimate regime setar`, `estimate regime star`) rather than a bigger linear model.

```bash
friedman test variance-ratio :nile --column=1
friedman test variance-ratio :nile --horizons=2,5,10,20
friedman test serial bds :nile --column=1 --max-dim=6 --eps-frac=0.7
friedman test hansen-linearity :nile --p=1 --d=1
friedman test star-linearity :nile --p=1 --d=1
friedman test fisher :nile --column=1
friedman test serial bartlett-wn :nile --column=1
friedman test serial box-pierce :nile --column=1 --lags=20
friedman test serial durbin-watson :nile --column=1
```

**Interpretation.** `variance-ratio` tests H0 of a **random walk** (all ratios equal 1) with heteroskedasticity-robust per-horizon `z*` statistics and a Chow-Denning joint statistic as the headline. `serial bds` tests H0 of **iid** per embedding dimension — read the smallest p-value across dimensions. `fisher` and `serial bartlett-wn` test H0 of **white noise**; `serial box-pierce` tests H0 of **no autocorrelation** to `--lags` (default 20); `serial durbin-watson` tests H0 of **no AR(1)** with a statistic near 2 under the null. `hansen-linearity` tests H0 of **linearity** against a two-regime SETAR alternative (sup-LM/sup-Wald with fixed-regressor bootstrap p-values — the threshold is unidentified under the null, so there is no χ² shortcut). `star-linearity` tests H0 of **linearity** against a STAR alternative with an LM χ²(3p) statistic and an F-form (`--transition-col=0` is self-exciting; any other column names an external transition variable).

**Pitfalls.** BDS rejects on any dependence — heteroskedasticity included — so run it on standardized residuals, not raw returns. The Hansen bootstrap costs replications (`--reps`, default 1000); a short series surfaces a typed `data/invalid`, not a p-value. For STAR, `df = 3p` by construction; a constant external transition variable is a usage error, not a zero statistic.

Reference: [generated test reference](generated/test.md).

---

## Cointegration

**Goal:** decide whether individually I(1) series share stationary long-run relationships. H0 is **no cointegration** throughout this family (except where noted) — a low p-value is evidence *for* a relationship, the reverse of a unit-root reading.

```bash
friedman test coint johansen :denmark --lags=2 --trend=constant
friedman test coint engle-granger :denmark --dep=LRM --lags=aic
friedman test coint phillips-ouliaris :denmark --dep=LRM --kernel=bartlett --bandwidth=nw
friedman test coint gregory-hansen :denmark --model=C
friedman test stability hansen-instability :denmark --dep=LRM --method=fmols
friedman test park-added :denmark --dep=LRM --q-add=2 --hac-bandwidth=nw
```

**Interpretation.** `coint johansen` reports **trace** and **maximum-eigenvalue** statistics row by row for rank 0, 1, … — the estimated rank is the first rank not rejected; trace and max-eigenvalue disagreeing by one rank is common and not an error. `coint engle-granger` runs an ADF on the cointegrating residuals (`--lags aic|bic|tstat` or an integer); `coint phillips-ouliaris` reports both the studentized `Z_t` and the normalized-bias `Z_alpha`, each with its own p-value. `coint gregory-hansen` repeats the no-cointegration test allowing one regime shift (`--model C|C_T|C_S`) and reports ADF\*, Zt\*, Za\* with break indices. `stability hansen-instability` reverses the null again — H0 is **stable cointegration**, so a large `L_c` rejects stability. `park-added` tests H0 of **genuine cointegration** against spuriousness with a χ²(`--q-add`) statistic.

**Pitfalls.** Trend vocabularies differ and are enforced, not coerced: `engle-granger`/`phillips-ouliaris` take `none|constant|trend`; `hansen-instability`/`park-added` consume a cointegrating regression and take `none|const|linear` like `estimate regression cointreg`. `park-added` keeps the regression HAC options (`--kernel`/`--bandwidth`) separate from the test HAC options (`--hac-kernel`/`--hac-bandwidth`). The bounds test below has no p-value at all — do not compare its output to these p-values.

Reference: [generated test reference](generated/test.md). Pairs with [`estimate multivariate vecm`](estimate.md).

---

## ARDL bounds and NARDL symmetry

**Goal:** test for a level relationship in a single-equation ARDL without pre-testing every series as I(0)/I(1), then test whether positive and negative changes have symmetric effects.

```bash
friedman test coint ardl-bounds :denmark --dep=LRM --p=1 --q=1 --case=3 --level=0.05
friedman test coint ardl-bounds :denmark --dep=LRM --p=auto --q=auto --case=2
friedman test nardl-symmetry :denmark --dep=LRM --asymmetric=all --p=1 --q=1
```

**Interpretation.** `coint ardl-bounds` (Pesaran-Shin-Smith) reports a joint bounds **F** and a **t** statistic with no p-values: above the I(1) upper bound is `cointegrated`, below the I(0) lower bound is `not_cointegrated`, between is `inconclusive`. The t-bounds are undefined for cases II and IV. `nardl-symmetry` reports long-run (`θ⁺ = θ⁻`, delta-method Wald) and short-run symmetry Wald tests per asymmetric regressor, each as χ²(1) and F(1, n−K) with matching p-values — rejection is evidence of asymmetric adjustment.

**Pitfalls.** `--case` (1–5) selects the deterministic specification and changes the critical values — a verdict without a stated case is meaningless. `--level` must be one of 0.10, 0.05, 0.025, 0.01. Only `pss` critical values are bundled (`--cv-source narayan` is a usage error). `--asymmetric` takes `all` or 1-based regressor indices.

Reference: [generated test reference](generated/test.md). Pairs with `estimate univariate ardl` / `estimate univariate nardl` in [estimate](estimate.md). Configuration format: [Configuration](../configuration.md).

---

## VECM restrictions on the cointegrating structure

**Goal:** test economic restrictions on an already-established cointegrating structure — exclusion, exogeneity, or a fully specified cointegrating vector. H0 is that the restriction **holds**, so a low p-value rejects the economics, not the cointegration.

```bash
friedman test vecm weak-exog :denmark --vars=IDE --rank=1
printf '[vecm_restriction]\nH = [[1.0], [0.0], [0.0], [0.0], [0.0]]\nA = [[1.0], [0.0], [0.0], [0.0], [0.0]]\nb = [[1.0], [-1.0], [0.0], [0.0], [0.0]]\n' > restr.toml
friedman test vecm beta :denmark --config=restr.toml --rank=1
friedman test vecm alpha :denmark --config=restr.toml --rank=1
friedman test vecm known-beta :denmark --config=restr.toml --rank=1
friedman test vecm joint :denmark --config=restr.toml
```

**Interpretation.** Each leaf fits a VECM (rank must be ≥ 1, else `data/no-cointegration`) and reports a likelihood-ratio statistic with degrees of freedom from the restriction dimension: `beta` tests β = Hφ, `alpha` tests α = Aψ, `known-beta` tests a fully specified β, `joint` tests both at once, `weak-exog` tests weak exogeneity of `--vars` (names or indices, no config needed).

**Pitfalls.** Restriction matrices go in a `[vecm_restriction]` TOML section, **row-major**, with conformable dimensions (`H` is p×s with s ≥ r; `b` is p×r with exactly r columns) — the fence writes one (`restr.toml`, five rows for the five Denmark series) before the config-reading leaves. A wrong-shaped matrix is a usage error. See [Configuration](../configuration.md).

Reference: [generated test reference](generated/test.md).

---

## OLS regression diagnostics

**Goal:** check the Gauss-Markov plumbing of a cross-section OLS fit before trusting its standard errors. All leaves fit the regression like `estimate regression reg` — `--dep` picks the dependent column, every other numeric column is a regressor, and **no intercept is prepended** (include a `const` column for one).

```bash
friedman test serial white :stackloss --dep=stack.loss
friedman test serial white :stackloss --dep=stack.loss --no-cross-terms
friedman test serial glejser :stackloss --dep=stack.loss
friedman test serial harvey :stackloss --dep=stack.loss
friedman test stability chow :stackloss --dep=stack.loss --break-at=10
friedman test stability chow :stackloss --dep=stack.loss --break-at=7,14 --type=forecast
friedman test stability cusum :stackloss --dep=stack.loss --level=0.05
friedman test stability cusumsq :stackloss --dep=stack.loss
friedman test stability recursive-residuals :stackloss --dep=stack.loss
friedman test influence :stackloss --dep=stack.loss
friedman test vif :stackloss --dep=stack.loss
```

**Interpretation.** `serial white` / `serial glejser` / `serial harvey` test H0 of **homoskedasticity** — a low p-value means heteroskedastic errors, so re-fit with a robust `--cov-type`. `stability chow` tests H0 of **constant coefficients** across segments at `--break-at` (required; comma-separated for multi-break). `stability cusum` / `cusumsq` report a path plus a significance band — the verdict is whether the path leaves the band (`crossed band` plus first crossing index), not a p-value; `cusum` catches coefficient drift, `cusumsq` catches a variance shift. `stability recursive-residuals` reports the recursive residuals themselves. `influence` reports leverage, studentized residuals, DFFITS, and Cook's distance per observation with flagged index lists (the `dfbetas` matrix stays out of the tidy table by design). `vif` reports variance inflation factors per regressor — above 5 is moderate, above 10 severe multicollinearity.

**Pitfalls.** `--break-at` is spelled with `-at` (`break` is reserved). `type=breakpoint` needs at least k observations per segment — use `forecast` for short segments. `test serial breusch-pagan` is *not* a heteroskedasticity test here: it is the panel random-effects LM test (see Panel specification). `--cov-type` is forwarded to the underlying fit on every leaf in this family.

Reference: [generated test reference](generated/test.md). Pairs with [`estimate regression reg`](estimate.md).

---

## Count and distributional diagnostics

**Goal:** check the distributional assumption behind count and continuous models. The count decision is directional — the sign of the statistic chooses the remedy.

```bash
friedman data simulate cross-section --kind poisson --n 200 --seed 7 --format csv --output sim_counts.csv
friedman test dispersion sim_counts.csv --dep=y
friedman test dispersion sim_counts.csv --dep=y --alpha=0.01
friedman test edf :nile --dist=normal --test=ad
friedman test edf :nile --dist=normal --params=specified --theta=0,1
friedman test normality :denmark --lags=2
```

**Interpretation.** `dispersion` (Cameron-Trivedi) fits Poisson, then runs the auxiliary regression in NB2 and NB1 forms. The p-values are two-sided but the decision is directional:

| Outcome | Reading |
|---------|---------|
| α > 0, significant | **Overdispersion** — prefer `estimate choice nbreg` |
| α < 0, significant | **Underdispersion** — NB2 cannot represent this; reach for generalised-Poisson or Conway–Maxwell–Poisson, not `nbreg` |
| not significant | Poisson is adequate |

`edf` tests H0 that the series follows `--dist` (`normal|exponential|logistic|gumbel|gamma|weibull|chisq`) with the `--test ks|lilliefors|cvm|ad|watson` statistic; `--params estimate` (default) fits parameters by ML, `specified` requires `--theta`. `normality` runs the VAR-residual normality suite at `--lags`/`-p` — a pre-test for non-Gaussian SVAR identification.

**Pitfalls.** Treating any dispersion rejection as "use nbreg" recommends the wrong model on underdispersed counts. For EDF, `specified` without `--theta` is a usage error.

Reference: [generated test reference](generated/test.md). Pairs with `estimate choice poisson` / `estimate choice nbreg` in [estimate](estimate.md).

---

## Instrumental-variable diagnostics

**Goal:** verify that instruments identify what the point estimate claims. A weak first stage invalidates the 2SLS Wald interval at any sample size — these leaves quantify the damage and give robust alternatives. Data layout matches `estimate regression iv`: `--endogenous` names endogenous regressors, `--instruments` names excluded instruments, every other numeric column is exogenous (include a `const` column for an intercept).

```bash
friedman data simulate cross-section --kind iv --n 200 --seed 7 --format csv --output sim_iv.csv
friedman test iv weak-instrument sim_iv.csv --dep=y --endogenous=x2 --instruments=z2,z3
friedman test iv weak-instrument sim_iv.csv --dep=y --endogenous=x2 --instruments=z2,z3 --threshold=10
friedman test iv anderson-rubin sim_iv.csv --dep=y --endogenous=x2 --instruments=z2,z3
friedman test iv anderson-rubin sim_iv.csv --dep=y --endogenous=x2 --instruments=z2,z3 --no-ci
friedman data simulate cross-section --kind cluster --n 200 --seed 7 --format csv --output sim_cluster.csv
friedman test iv wild-cluster sim_cluster.csv --dep=y --clusters=cluster --coefficient=x2
friedman test iv wild-cluster sim_cluster.csv --dep=y --clusters=cluster --coefficient=x2 --null=0 --boot-weights=webb --boot-reps=9999
```

**Interpretation.** `iv weak-instrument` reports the first-stage F, the Cragg-Donald F, the Kleibergen-Paap rk-Wald F, and the Stock-Yogo 10%-maximal-bias critical value; instruments are **weak** when the statistic falls below the critical value (or `--threshold`, default 10, when untabulated). `iv anderson-rubin` tests H0: β = `--beta0` with correct size at any instrument strength, and inverts the test into a confidence set that need not be an interval — `bounded`, `unbounded`, `disjoint`, `whole-line`, or `empty` (empty rejects the model, not just the strength). `iv wild-cluster` is the **few-cluster** procedure (Cameron-Gelbach-Miller): it reports the bootstrap p-value beside the analytic one, plus the inverted-test interval; the gap between the two is the reason to run it.

**Pitfalls.** Inverting the AR test needs exactly one endogenous regressor — with more, the test still reports but the set is skipped. Under `--cov-type cluster` the AR statistic is cluster-robust while the comparison Wald interval comes from an `hc1` fit (both recorded, never like-for-like). For wild-cluster, the default restricted (WCR) variant dominates the `--no-impose-null` WCU; with Rademacher weights and 2^G ≤ `--boot-reps`, signs enumerate exactly with zero simulation error; prefer `--boot-weights webb` when G is very small. Only `:rademacher` and `:webb` weights exist here — `:normal` is unsupported.

Reference: [generated test reference](generated/test.md). Pairs with [`estimate regression iv`](estimate.md).

---

## VAR and Panel VAR diagnostics

**Goal:** specify the VAR (lag order, stability) and test direction and nesting. The `--all` Granger sweep and the information-criteria tables answer "what VAR?" before any structural work.

```bash
friedman data simulate pvar --n 15 --periods 25 --seed 7 --format csv --output sim_pvar.csv
friedman test multivariate lagselect :denmark --max-lags=4 --criterion=aic
friedman test multivariate stability :denmark --lags=2
friedman test multivariate granger :denmark --cause=1 --effect=2
friedman test multivariate granger :denmark --cause=1 --effect=2 --model=var --all
friedman test multivariate lr :denmark :denmark --lags1=2 --lags2=4
friedman test multivariate lm :denmark :denmark --lags1=2 --lags2=4
friedman test pvar hansen-j sim_pvar.csv --id-col=id --time-col=time --lags=1
friedman test pvar mmsc sim_pvar.csv --id-col=id --time-col=time --max-lags=4
friedman test pvar lagselect sim_pvar.csv --id-col=id --time-col=time --max-lags=4
friedman test pvar stability sim_pvar.csv --id-col=id --time-col=time --lags=1
```

**Interpretation.** `multivariate lagselect` reports AIC/BIC/HQC per lag with the optimum; `multivariate stability` checks companion-matrix eigenvalue moduli against 1. `granger` tests H0 of **no Granger causality** from `--cause` to `--effect` — direction matters, the pair is not interchangeable; the default `--model` is `vecm` with `--rank auto`, and `--all` sweeps every pair under `--model var` only. `lr`/`lm` compare nested VARs fit on two datasets (restricted vs unrestricted) with `--lags1`/`--lags2`. `pvar hansen-j` tests H0 of **valid overidentifying restrictions**; `pvar mmsc`/`pvar lagselect` select the panel VAR lag order (Andrews-Lu criteria vs information criteria); `pvar stability` checks the panel companion matrix.

**Pitfalls.** `granger` takes variable **indices**, not names. `pvar` leaves need `--id-col`/`--time-col`; the panel lag criteria spell the third option `hqic`, not `hqc`. LR/LM need two datasets — the same file twice tests lag nesting, not model nesting.

Reference: [generated test reference](generated/test.md). Pairs with `estimate multivariate var` / `estimate panel pvar` in [estimate](estimate.md).

---

## Non-Gaussian SVAR diagnostics

**Goal:** check whether the data support non-Gaussian identification before imposing it. Run these before any heteroskedasticity- or independence-based SVAR.

```bash
friedman test identifiability :denmark --test=all
friedman test identifiability :denmark --test=strength
friedman test identifiability :denmark --test=gaussianity --method=jade
friedman test serial heteroskedasticity :denmark --method=markov --regimes=2
friedman test serial heteroskedasticity :denmark --method=garch
```

**Interpretation.** `identifiability` runs up to five checks — identification strength, shock Gaussianity, shock independence, overidentification, Gaussian-vs-non-Gaussian comparison. The W2 riders (`lambda-distinct`, `gaussian-count`, `label-stability`) are opt-in only: `--test all` keeps its historical five. `serial heteroskedasticity` estimates the structural impact matrix B0 from variance changes across regimes (`markov|garch|smooth_transition|external`; the last two need `--config`).

**Pitfalls.** Only advertise `--plot` where a real `plot_result` method exists for the result type. `--contrast logcosh|exp|kurtosis` applies to FastICA only. `label-stability` reports a bootstrap column-match fraction with no p-value. Only declare `--method fastica|jade|sobi|dcov|hsic` values the handler supports.

Reference: [generated test reference](generated/test.md). Configuration format: [Configuration](../configuration.md).

---

## Residual and volatility diagnostics

**Goal:** test what is left after the mean and variance fits. ARCH effects send you to `estimate volatility`; leftover asymmetry or drifting parameters send you back to re-specify.

```bash
friedman test serial arch-lm :gnp_hamilton --column=1 --lags=4
friedman test serial ljung-box :gnp_hamilton --column=1 --lags=10
friedman test serial sign-bias :gnp_hamilton --column=1 --model=garch
friedman test stability nyblom :gnp_hamilton --column=1 --model=garch
```

**Interpretation.** `serial arch-lm` tests H0 of **no ARCH effects**; `serial ljung-box` tests H0 of **no serial correlation** in the squared series. Both test the passed column directly — no model is fit. `serial sign-bias` (Engle-Ng) tests H0 of **no remaining asymmetry** — rejection points at a leverage model (EGARCH/GJR-GARCH) — with sign, negative-size, and positive-size t-statistics plus a joint χ²(3); it first fits the volatility model named by `--model` (`garch|egarch|gjr-garch`, the three sharing the (p,q) signature) and tests its standardized residuals. `stability nyblom` (Nyblom/Hansen) tests H0 of **stable parameters** against martingale drift, with per-parameter statistics and a joint test against Hansen 5% critical values (a critical-value test — no p-value).

**Pitfalls.** `serial box-pierce` tests the levels (the mean); `serial ljung-box` squares the passed column first, so it always tests the variance — know which series you passed. `--p`/`--q` are the fitted GARCH orders, not the test lags.

Reference: [generated test reference](generated/test.md). Pairs with `estimate volatility` in [estimate](estimate.md).

---

## Panel specification tests

**Goal:** choose the panel estimator (pooled, random effects, fixed effects) and check its assumptions. Long-format panels with `--id-col`/`--time-col` (defaulting to the first/second columns) and `--dep`/`--indep`.

```bash
friedman data simulate panel --n 20 --periods 30 --seed 7 --format csv --output sim_panel.csv
friedman test panel hausman sim_panel.csv --dep=y --indep=x1,x2
friedman test serial breusch-pagan sim_panel.csv --dep=y --indep=x1,x2
friedman test panel f-fe sim_panel.csv --dep=y --indep=x1,x2
friedman test panel pesaran-cd sim_panel.csv --dep=y --indep=x1,x2
friedman test panel wooldridge-ar sim_panel.csv --dep=y --indep=x1,x2
friedman test panel modified-wald sim_panel.csv --dep=y --indep=x1,x2
```

**Interpretation.** `panel hausman` tests H0 that random effects are consistent (no correlation between effects and regressors) — rejection picks **fixed effects**. `serial breusch-pagan` tests H0 of **no random effects** (pooled OLS suffices) — note this is the panel LM test, unrelated to cross-section heteroskedasticity. `panel f-fe` tests H0 of **no fixed effects**. `panel pesaran-cd` tests H0 of **cross-sectional independence** — rejection means first-generation panel tests do not apply (use `cips`/`moon-perron`/`panic`). `panel wooldridge-ar` tests H0 of **no first-order serial correlation**; `panel modified-wald` tests H0 of **homoskedastic errors** in an FE fit.

**Pitfalls.** The Hausman and Breusch-Pagan nulls point in opposite directions — rejecting both means fixed effects with a reason to double-check the specification, not a contradiction. Pesaran-CD rejection invalidates every first-generation panel unit-root p-value on that panel.

Reference: [generated test reference](generated/test.md). Pairs with [Panel Regression](panel-regression.md).

---

## Panel unit roots, panel cointegration, and breaks

**Goal:** handle non-stationarity in panels and date structural breaks. First-generation tests assume cross-sectional independence; second-generation tests model it.

```bash
friedman data simulate panel --n 20 --periods 30 --seed 7 --format csv --output sim_panel_ur.csv
friedman test unit-root llc :denmark --deterministic=trend
friedman test unit-root ips :denmark --lags=2
friedman test unit-root breitung :denmark --cs-demean
friedman test unit-root hadri :denmark --deterministic=constant
friedman test coint pedroni sim_panel_ur.csv --dep=y --indep=x1,x2 --trend=constant
friedman test coint kao sim_panel_ur.csv --dep=y --indep=x1
friedman test coint westerlund sim_panel_ur.csv --dep=y --indep=x1 --trend=constant
friedman test coint fisher-johansen sim_panel_ur.csv --vars=y,x1,x2 --lags=2 --combine=mw
friedman test panel dh-causality sim_panel_ur.csv --cause=x1 --effect=y --p=2
friedman test stability andrews :denmark --response=1 --test=supwald --trimming=0.15
friedman test stability bai-perron :denmark --response=1 --max-breaks=5
friedman test unit-root cips sim_panel_ur.csv --deterministic=constant
friedman test unit-root moon-perron sim_panel_ur.csv --factors=auto
friedman test panel panic sim_panel_ur.csv --factors=auto --method=pooled
friedman test stability factor-break sim_panel_ur.csv --factors=2
friedman test panel pmg-hausman sim_panel_ur.csv --dep=y --indep=x1,x2 --efficient=pmg
```

**Interpretation.** `unit-root llc` (common root), `unit-root ips` (heterogeneous roots, with per-unit ADF statistics), and `unit-root breitung` test H0 that **every unit has a unit root** on a T×N wide matrix — a low p-value means a stationary panel. `unit-root hadri` reverses the null (H0: **all units stationary**). `coint pedroni` (seven panel/group statistics), `coint kao` (DF/ADF-type), and `coint westerlund` (Gt/Ga/Pt/Pa error-correction) test H0 of **no panel cointegration** on long-format panels. `coint fisher-johansen` combines per-unit Johansen tests (`--combine mw|choi`) with one row per rank hypothesis. `panel dh-causality` (Dumitrescu-Hurlin) tests H0 of **no causality for any unit** from `--cause` to `--effect` — both required, direction matters — reporting W-bar, Z-bar, and the small-T-corrected Z-tilde. `andrews` tests H0 of **no break** at an unknown date (sup/exp/mean × Wald/LR/LM via `--test`); `bai-perron` selects up to `--max-breaks` breaks by `--criterion bic|lwz`. `cips` / `moon-perron` / `panic` are second-generation panel unit-root tests allowing cross-sectional dependence; `factor-break` tests factor-model stability. `panel pmg-hausman` tests H0 of **long-run homogeneity** — failing to reject supports the pooled (PMG) long-run vector, rejection favours Mean Group.

**Pitfalls.** Wide matrix for unit-root tests (one column per unit) vs long format for cointegration/Causality/PMG-Hausman — transposing silently answers a different question. `llc`/`ips` take `--lags auto` plus `--criterion aic|bic|tstat`; `breitung` takes an integer `--lags` (default 0). `--cs-demean` only mitigates dependence; with strong factor structure use the second-generation tests. Full detail: [Panel Unit Root](panel-unit-root.md), [Panel Regression](panel-regression.md), [Structural Breaks](structural-breaks.md). `test did bacon|pretrend|negweight|honest` cover DiD diagnostics: [DiD](did.md).

Reference: [generated test reference](generated/test.md).

---

## Discrete-choice specification tests

**Goal:** check the identifying assumptions of ordered and multinomial choice models. Rejection re-specifies the estimator (generalized ordered logit, nested logit), not the covariates.

```bash
friedman data simulate cross-section --kind ordered --n 200 --seed 7 --format csv --output sim_ordered.csv
friedman test brant sim_ordered.csv --dep=y
friedman data simulate cross-section --kind mlogit --n 200 --seed 7 --format csv --output sim_mlogit.csv
friedman test hausman-iia sim_mlogit.csv --dep=y --omit-category=3
```

**Interpretation.** `brant` tests H0 of **proportional odds** (parallel regressions) overall and per variable — rejection violates the ordered-logit assumption. `hausman-iia` tests H0 of **IIA** for the omitted category (`--omit-category`, default last) — rejection points at nested logit or mixed logit.

**Pitfalls.** Brant needs genuine ordered integers in `--dep`; a per-variable rejection suggests a partial-proportional-odds specification, not dropping the variable. Full detail: [Ordered & Multinomial](ordered-multinomial.md).

Reference: [generated test reference](generated/test.md).

---

## References

Full option tables: [generated test reference](generated/test.md). Workflow counterparts: [estimate](estimate.md), [Configuration](../configuration.md). Specialist pages: [Structural Breaks](structural-breaks.md), [Panel Unit Root](panel-unit-root.md), [Panel Regression](panel-regression.md), [Ordered & Multinomial](ordered-multinomial.md), [DiD](did.md).

Anderson, T. W. and Rubin, H. (1949). Estimation of the parameters of a single equation in a complete system of stochastic equations. *Annals of Mathematical Statistics*.

Andrews, D. W. K. (1993). Tests for parameter instability and structural change with unknown change point. *Econometrica*.

Bai, J. and Perron, P. (1998, 2003). Computation and analysis of multiple structural change models. *Journal of Applied Econometrics*.

Becker, R., Enders, W. and Lee, J. (2006). A stationarity test in the presence of an unknown number of smooth breaks. *Journal of Time Series Analysis*.

Breitung, J. (2000). The local power of some unit root tests for panel data. *Advances in Econometrics*.

Brock, W. A., Dechert, W. D. and Scheinkman, J. A. (1987). A test for independence based on the correlation dimension. *SSRI Working Paper*.

Brown, R. L., Durbin, J. and Evans, J. M. (1975). Techniques for testing the constancy of regression relationships over time. *JRSS B*.

Cameron, A. C., Gelbach, J. B. and Miller, D. L. (2008). Bootstrap-based improvements for inference with clustered errors. *Review of Economics and Statistics*.

Cameron, A. C. and Trivedi, P. K. (1990). Regression-based tests for overdispersion in the Poisson model. *Journal of Econometrics*.

Chow, G. C. (1960). Tests of equality between sets of coefficients in two linear regressions. *Econometrica*.

Dickey, D. A. and Fuller, W. A. (1979). Distribution of the estimators for autoregressive time series with a unit root. *JASA*.

Dumitrescu, E.-I. and Hurlin, C. (2012). Testing for Granger non-causality in heterogeneous panels. *Economic Modelling*.

Elliott, G., Rothenberg, T. J. and Stock, J. H. (1996). Efficient tests for an autoregressive unit root. *Econometrica*.

Enders, W. and Lee, J. (2012). The flexible Fourier form and Dickey-Fuller type unit root tests. *Economics Letters*.

Engle, R. F. and Granger, C. W. J. (1987). Co-integration and error correction. *Econometrica*.

Engle, R. F. and Ng, V. K. (1993). Measuring and testing the impact of news on volatility. *Journal of Finance*.

Geweke, J. and Porter-Hudak, S. (1983). The estimation and application of long memory time series models. *Journal of Time Series Analysis*.

Gregory, A. W. and Hansen, B. E. (1996). Residual-based tests for cointegration in models with regime shifts. *Journal of Econometrics*.

Hadri, K. (2000). Testing for stationarity in heterogeneous panel data. *Econometrics Journal*.

Hansen, B. E. (1992). Testing for parameter instability in linear models. *Journal of Policy Modeling*.

Hansen, B. E. (1996). Inference when a nuisance parameter is not identified under the null hypothesis. *Econometrica*.

Hausman, J. A. (1978). Specification tests in econometrics. *Econometrica*.

Hausman, J. A. and McFadden, D. (1984). Specification tests for the multinomial logit model. *Econometrica*.

Hylleberg, S., Engle, R. F., Granger, C. W. J. and Yoo, B. S. (1990). Seasonal integration and cointegration. *Journal of Econometrics*.

Im, K. S., Pesaran, M. H. and Shin, Y. (2003). Testing for unit roots in heterogeneous panels. *Journal of Econometrics*.

Johansen, S. (1991). Estimation and hypothesis testing of cointegration vectors in Gaussian vector autoregressive models. *Econometrica*.

Kao, C. (1999). Spurious regression and residual-based tests for cointegration in panel data. *Journal of Econometrics*.

Kwiatkowski, D., Phillips, P. C. B., Schmidt, P. and Shin, Y. (1992). Testing the null hypothesis of stationarity against the alternative of a unit root. *Journal of Econometrics*.

Lee, J. and Strazicich, M. C. (2003, 2013). Minimum Lagrange multiplier unit root test with breaks. *Review of Economics and Statistics* / *Oxford Bulletin*.

Levin, A., Lin, C.-F. and Chu, C.-S. J. (2002). Unit root tests in panel data. *Journal of Econometrics*.

Lo, A. W. and MacKinlay, A. C. (1988). Stock market prices do not follow random walks. *Review of Financial Studies*.

Luukkonen, R., Saikkonen, P. and Teräsvirta, T. (1988). Testing linearity against smooth transition autoregressive models. *Biometrika*.

MacKinnon, J. G. and Webb, M. D. (2017). Wild bootstrap inference for wildly different cluster sizes. *Journal of Applied Econometrics*.

Ng, S. and Perron, P. (2001). Lag length selection and the construction of unit root tests with good size and power. *Econometrica*.

Nyblom, J. (1989). Testing for the constancy of parameters over time. *JASA*.

Park, J. Y. (1992). Canonical cointegrating regressions. *Econometrica*.

Pedroni, P. (1999, 2004). Critical values for cointegration tests in heterogeneous panels. *Oxford Bulletin*.

Pesaran, M. H. (2007). A simple panel unit root test in the presence of cross-section dependence. *Journal of Applied Econometrics*.

Pesaran, M. H., Shin, Y. and Smith, R. J. (2001). Bounds testing approaches to the analysis of level relationships. *Journal of Applied Econometrics*.

Pesaran, M. H., Shin, Y. and Smith, R. P. (1999). Pooled mean group estimation of dynamic heterogeneous panels. *JASA*.

Phillips, P. C. B. and Ouliaris, S. (1990). Asymptotic properties of residual based tests for cointegration. *Econometrica*.

Phillips, P. C. B. and Perron, P. (1988). Testing for a unit root in time series regression. *Biometrika*.

Phillips, P. C. B., Shi, S.-P. and Yu, J. (2015). Testing for multiple bubbles. *International Economic Review*.

Robinson, P. M. (1995). Gaussian semiparametric estimation of long range dependence. *Annals of Statistics*.

Stock, J. H. and Yogo, M. (2005). Testing for weak instruments in linear IV regression. *Identification and Inference for Econometric Models*.

Westerlund, J. (2007). Testing for error correction in panel data. *Oxford Bulletin*.

White, H. (1980). A heteroskedasticity-consistent covariance matrix estimator and a direct test for heteroskedasticity. *Econometrica*.

Zivot, E. and Andrews, D. W. K. (1992). Further evidence on the great crash, the oil-price shock, and the unit-root hypothesis. *JBES*.
