# estimate

Estimate econometric models. 65 subcommands covering VAR, BVAR, VECM, Panel VAR, FAVAR, Structural DFM, systems estimation (SUR/3SLS), cross-sectional regression (OLS/WLS/IV/Logit/Probit), penalized regression (Lasso/Ridge/Elastic-Net), robust (Huber/bisquare M/MM), Tobit censored, truncated-normal and Heckman sample-selection regression, single-equation (FMOLS/CCR/DOLS) and panel (group-mean/pooled) cointegrating regression, single-equation ARDL and nonlinear/asymmetric NARDL, self-exciting threshold autoregression (SETAR, with an attached Hansen 1996 linearity test) and smooth-transition autoregression (STAR: LSTR1/LSTR2/ESTR, Teräsvirta NLS), Markov-switching autoregression (MS-AR, Hamilton mean-switching) and K-state Markov-switching regression (with a wide regime-transition matrix), structural state-space models (local level / local linear trend) and time-varying-parameter regression, nonparametric estimation (kernel density, kernel/local-polynomial regression, LOWESS), panel regression (FE/RE/IV/Logit/Probit), ordered and multinomial choice models, local projections, ARIMA, ARFIMA long memory, GMM, SMM, factor models, univariate volatility models (ARCH/GARCH/EGARCH/GJR-GARCH/SV plus IGARCH/Component-GARCH/APARCH/FIGARCH/FIEGARCH/GARCH-MIDAS), multivariate GARCH (CCC/DCC/BEKK), and non-Gaussian SVAR identification.

## Coefficient table format (C051)

Every coefficient-bearing model — `var`, `reg`, `iv`, `logit`, `probit`, `preg`, `piv`,
`plogit`, `pprobit`, `ologit`, `oprobit`, `mlogit` — renders its coefficients through MEMs'
`DataFrame(model)`: a tidy table with the core columns `term | estimate | std_error | stat
| p_value | ci_lower | ci_upper`. `var` prepends `equation` (one row per lag/variable per
equation); the panel models are the same 7 columns as `reg`/`logit`/`probit`; `ologit`/
`oprobit` prepend `block` (coefficients vs. cutpoints); `mlogit` prepends `alternative`
(one block per category, relative to the base). Fit statistics (R², AIC/BIC,
pseudo-R²/log-likelihood, convergence) print as a separate small table alongside the
coefficient table, not merged into it.

## estimate var

Estimate a VAR(p) model via OLS. Lag order is auto-selected via AIC when `--lags` is omitted.

```bash
friedman estimate var data.csv
friedman estimate var data.csv --lags=2
friedman estimate var data.csv --lags=4 --format=csv --output=var_results.csv
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | Lag order |
| `--trend` | | String | `constant` | `none`, `constant`, `trend`, `both` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`equation|term|estimate|std_error|stat|p_value|ci_lower|ci_upper`, [C051](#coefficient-table-format-c051)) via `DataFrame(model)`, plus a small AIC/BIC/HQC/log-likelihood fit-stats table.

## estimate bvar

Estimate a Bayesian VAR with MCMC sampling and posterior extraction.

```bash
friedman estimate bvar data.csv --lags=4 --draws=2000
friedman estimate bvar data.csv --config=prior.toml --method=median
friedman estimate bvar data.csv --sampler=gibbs --draws=5000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 4 | Lag order |
| `--prior` | | String | `minnesota` | Prior type |
| `--draws` | `-n` | Int | 2000 | MCMC draws |
| `--sampler` | | String | `direct` | `direct`, `gibbs` |
| `--method` | | String | `mean` | `mean`, `median` (posterior extraction) |
| `--config` | | String | | TOML config for prior hyperparameters |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Posterior mean/median coefficient matrix, AIC/BIC/HQC.

See [Configuration](../configuration.md) for Minnesota prior TOML format.

## estimate lp

Estimate local projections with 6 method variants.

### Standard LP (Jorda 2005)

```bash
friedman estimate lp data.csv --shock=1 --horizons=20 --vcov=newey_west
```

### LP-IV (Stock & Watson 2018)

```bash
friedman estimate lp data.csv --method=iv --shock=1 --instruments=instruments.csv
```

### Smooth LP (Barnichon & Brownlees 2019)

```bash
friedman estimate lp data.csv --method=smooth --shock=1 --horizons=20
friedman estimate lp data.csv --method=smooth --lambda=0.5 --knots=4
```

When `--lambda=0` (default), the smoothing parameter is auto-selected via cross-validation.

### State-Dependent LP (Auerbach & Gorodnichenko 2013)

```bash
friedman estimate lp data.csv --method=state --shock=1 --state-var=2 --gamma=1.5
```

### Propensity Score LP (Angrist et al. 2018)

```bash
friedman estimate lp data.csv --method=propensity --treatment=1 --score-method=logit
```

### Doubly Robust LP

```bash
friedman estimate lp data.csv --method=robust --treatment=1 --score-method=logit
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `standard` | `standard`, `iv`, `smooth`, `state`, `propensity`, `robust` |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--control-lags` | | Int | 4 | Number of control lags |
| `--vcov` | | String | `newey_west` | `newey_west`, `white`, `driscoll_kraay` |
| `--instruments` | | String | | Path to instruments CSV (iv only) |
| `--knots` | | Int | 3 | B-spline knots (smooth only) |
| `--lambda` | | Float64 | 0.0 | Smoothing penalty, 0=auto CV (smooth only) |
| `--state-var` | | Int | | State variable index (state only, required) |
| `--gamma` | | Float64 | 1.5 | Transition steepness (state only) |
| `--transition` | | String | `logistic` | `logistic`, `exponential`, `indicator` (state only) |
| `--treatment` | | Int | 1 | Treatment variable index (propensity/robust only) |
| `--score-method` | | String | `logit` | `logit`, `probit` (propensity/robust only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

## estimate arima

Estimate ARIMA(p,d,q) models. Auto-selects order via information criteria when `--p` is omitted.

```bash
# Auto-selection
friedman estimate arima data.csv --criterion=bic

# Explicit order
friedman estimate arima data.csv --p=1 --d=1 --q=1

# Specific column
friedman estimate arima data.csv --column=2 --p=2 --d=0 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | auto | AR order |
| `--d` | | Int | 0 | Differencing order |
| `--q` | | Int | 0 | MA order |
| `--max-p` | | Int | 5 | Max AR order for auto selection |
| `--max-d` | | Int | 2 | Max differencing order for auto selection |
| `--max-q` | | Int | 5 | Max MA order for auto selection |
| `--criterion` | | String | `bic` | `aic`, `bic` |
| `--method` | `-m` | String | `css_mle` | `ols`, `css`, `mle`, `css_mle` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** AR/MA coefficients, AIC/BIC/log-likelihood.

## estimate arfima

Estimate ARFIMA(p,d,q) fractionally-integrated (long-memory) models. The fractional
integration order `d ∈ (−0.5, 0.5)` is estimated (starting from a GPH pre-estimate
unless `--d0` is given); `p` and `q` are the short-memory AR and MA orders.

```bash
# Pure fractional noise ARFIMA(0,d,0)
friedman estimate arfima data.csv --p=0 --q=0

# ARFIMA(1,d,1) via exact Gaussian ML
friedman estimate arfima data.csv --p=1 --q=1 --method=mle

# Custom starting value for d
friedman estimate arfima data.csv --column=2 --d0=0.2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 0 | AR order |
| `--q` | | Int | 0 | MA order |
| `--method` | `-m` | String | `css` | `css` (conditional sum of squares), `mle` (exact Gaussian ML) |
| `--d0` | | Float64 | GPH pre-estimate | Starting value for d |
| `--max-iter` | | Int | 500 | Maximum optimizer iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a hand-built coefficient table (`const`, `d`, `ar*`, `ma*` with standard
errors, z-stats, p-values) plus a diagnostics block (d estimate and its standard
error, log-likelihood, AIC/BIC, convergence). `ARFIMAModel` is not one of MEMs'
coefficient-table types, so — like `estimate arima` and the volatility models — the
coefficient table is emitted directly rather than via the tidy `DataFrame(model)`
path (a documented C051 exception).

## estimate gmm

Estimate a GMM model. Requires a TOML config specifying moment conditions and instruments.

```bash
friedman estimate gmm data.csv --config=gmm_spec.toml --weighting=twostep
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | (required) | TOML config file |
| `--weighting` | `-w` | String | `twostep` | `identity`, `optimal`, `twostep`, `iterated` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates, J-test for overidentification.

See [Configuration](../configuration.md) for GMM TOML format.

## estimate smm

Estimate via Simulated Method of Moments (SMM): parameters are chosen so that moments of
data **simulated** from a parametric model match the moments of the observed data.

Because SMM needs a data-generating model to simulate from, `--config` is **required** — the
`[smm]` section names one of the built-in simulators (`ar1`, `arp`, `var1`, `iid_normal`) and
its initial parameter vector `theta0`. Moments are the autocovariance moments
(`autocovariance_moments`); two-step estimation uses the optimal HAC weighting matrix, and
`--seed` pins the simulation draws for a reproducible fit.

```bash
friedman estimate smm gdp.csv --config=smm_ar1.toml
friedman --seed 42 estimate smm y.csv --config=smm_var1.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | | **Required.** TOML with `[smm]` (`model`, `theta0`, …) |
| `--weighting` | | String | `two_step` | `identity` or `two_step` (config `weighting` overrides) |
| `--sim-ratio` | | Int | 5 | Simulation-to-sample ratio (config `sim_ratio` overrides) |
| `--burn` | | Int | 100 | Burn-in periods (config `burn` overrides) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates with standard errors, t-statistics, and p-values (rows named
by the model's parameters, e.g. `phi`/`sigma`). Status stream reports the J-statistic,
J p-value, and convergence.

See [Configuration](../configuration.md#smm-specification) for the `[smm]` TOML schema and the
per-model `theta0` layouts.

## estimate static

Estimate a static factor model via PCA. Factor count is auto-selected via Bai-Ng information criteria when `--nfactors` is omitted.

```bash
friedman estimate static data.csv
friedman estimate static data.csv --nfactors=3 --criterion=ic2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto (IC) | Number of factors |
| `--criterion` | | String | `ic1` | `ic1`, `ic2`, `ic3` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Scree data (eigenvalues, variance shares), factor loadings.

## estimate dynamic

Estimate a dynamic factor model with a factor VAR.

```bash
friedman estimate dynamic data.csv --nfactors=2 --factor-lags=1
friedman estimate dynamic data.csv --method=em
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto | Number of factors |
| `--factor-lags` | `-p` | Int | 1 | Factor VAR lag order |
| `--method` | | String | `twostep` | `twostep`, `em` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Factor loadings, companion matrix eigenvalues, stationarity check.

## estimate gdfm

Estimate a generalized dynamic factor model (spectral method).

```bash
friedman estimate gdfm data.csv --dynamic-rank=2
friedman estimate gdfm data.csv --nfactors=5 --dynamic-rank=3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto | Number of static factors |
| `--dynamic-rank` | `-q` | Int | auto | Dynamic rank |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Common variance shares per variable, average common variance share.

## estimate arch

Estimate an ARCH(q) volatility model.

```bash
friedman estimate arch data.csv --column=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha), persistence, unconditional variance.

## estimate garch

Estimate a GARCH(p,q) volatility model.

```bash
friedman estimate garch data.csv --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha, beta), persistence, half-life, unconditional variance.

## estimate egarch

Estimate an EGARCH(p,q) volatility model.

```bash
friedman estimate egarch data.csv --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | EGARCH order |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha, gamma, beta), persistence.

## estimate gjr\_garch

Estimate a GJR-GARCH(p,q) volatility model with asymmetric leverage effects.

```bash
friedman estimate gjr_garch data.csv --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha, gamma, beta), persistence, half-life.

## estimate sv

Estimate a Stochastic Volatility model via MCMC.

```bash
friedman estimate sv data.csv --column=1 --draws=5000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--draws` | `-n` | Int | 5000 | MCMC draws |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, phi, sigma_eta), persistence (phi).

## estimate igarch

Estimate an Integrated GARCH(p,q) model — GARCH with the persistence constraint `Σα + Σβ = 1` imposed exactly (a shock to variance never dies out; the RiskMetrics EWMA is the `ω=0` special case).

```bash
friedman estimate igarch data.csv --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order p |
| `--q` | | Int | 1 | ARCH order q |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter | estimate | std_error | z_stat | p_value`; parameters `mu, omega, alpha…, beta…`) plus a `metric | value` diagnostics table (`log_likelihood, aic, bic, persistence` = 1, `converged, iterations`).

## estimate cgarch

Estimate a Component-GARCH(1,1) model (Engle & Lee 1999) decomposing the conditional variance into a slowly mean-reverting permanent component and a fast transitory component. Orders are fixed at (1,1).

```bash
friedman estimate cgarch data.csv --column=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, rho, phi, alpha, beta`) plus diagnostics (`log_likelihood, aic, bic, persistence` = ρ, `converged, iterations, transitory_persistence` = α+β, `unconditional_variance` = ω).

## estimate aparch

Estimate an Asymmetric Power ARCH(p,q) model (Ding, Granger & Engle 1993) with a free power `δ` of the conditional standard deviation and a Box-Cox-style leverage term. Pin `δ` and/or `γ` with `--fix-delta` / `--fix-gamma`.

```bash
friedman estimate aparch data.csv --column=1 --p=1 --q=1
friedman estimate aparch data.csv --fix-delta=2 --fix-gamma=0   # ≡ GARCH
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order p |
| `--q` | | Int | 1 | ARCH order q |
| `--fix-delta` | | Float64 | (auto) | Pin power δ (>0); default estimates it |
| `--fix-gamma` | | Float64 | (auto) | Pin leverage γ ∈ (-1,1); default estimates it |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, alpha…, gamma…, beta…, delta`) plus diagnostics (`log_likelihood, aic, bic, persistence, converged, iterations, delta, n_params`).

## estimate figarch

Estimate a Fractionally-Integrated GARCH(p,d,q) model (Baillie, Bollerslev & Mikkelsen 1996) — long-memory volatility with hyperbolic decay via the fractional-difference order `d ∈ (0,1)`. Gaussian QMLE (`--dist normal`).

```bash
friedman estimate figarch data.csv --column=1 --p=1 --q=1 --d0=0.4 --truncation=1000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH β(L) order p |
| `--q` | | Int | 1 | ARCH φ(L) order q |
| `--d0` | | Float64 | 0.4 | Initial fractional-integration order d ∈ (0,1) |
| `--truncation` | | Int | 1000 | ARCH(∞) truncation lag |
| `--dist` | | String | `normal` | Innovation distribution (Gaussian QMLE) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, phi…, beta…, d`) plus diagnostics (`log_likelihood, aic, bic, persistence` = d, `converged, iterations, d, truncation, n_neg_lambda`).

## estimate fiegarch

Estimate a Fractionally-Integrated EGARCH(p,d,q) model (Bollerslev & Mikkelsen 1996) — the log-variance long-memory analogue of FIGARCH with an EGARCH news function (sign term `θ`, magnitude term `γ`). Gaussian QMLE.

```bash
friedman estimate fiegarch data.csv --column=1 --p=1 --q=1 --d0=0.4 --truncation=1000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH β(L) order p |
| `--q` | | Int | 1 | ARCH φ(L) order q |
| `--d0` | | Float64 | 0.4 | Initial fractional-integration order d ∈ (0,1) |
| `--truncation` | | Int | 1000 | MA(∞) truncation lag |
| `--dist` | | String | `normal` | Innovation distribution (Gaussian QMLE) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, theta, gamma, phi…, beta…, d`) plus diagnostics (`log_likelihood, aic, bic, persistence` = d, `converged, iterations, d, truncation`).

## estimate garch-midas

Estimate a GARCH-MIDAS model (Engle, Ghysels & Sohn 2013): a mixed-frequency model splitting the conditional variance `σ² = τ·g` into a short-run unit-mean GARCH(1,1) component `g` and a long-run MIDAS-filtered component `τ`. `--m-freq` (high-frequency observations per low-frequency block) is **required**. With `--rv realized` the long-run driver is realized variance computed from the returns (no extra input); with `--rv macro` supply an exogenous low-frequency driver via `--config` (a `[garch_midas]` TOML section — see [Configuration](../configuration.md)).

```bash
# realized-variance driver (self-contained)
friedman estimate garch-midas data.csv --column=1 --m-freq=22 --k=12
# exogenous macro driver
friedman estimate garch-midas data.csv --m-freq=22 --rv=macro --config=gm.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | High-frequency return series column (1-based) |
| `--m-freq` | | Int | 0 | High-frequency observations per low-frequency block (**required**, ≥1) |
| `--k` | | Int | 12 | Number of MIDAS lags (K ≥ 2) |
| `--rv` | | String | `realized` | Long-run driver: `realized` (from returns) or `macro` (exogenous) |
| `--span` | | String | `fixed` | τ span: `fixed` (per block) or `rolling` (rolling RV) |
| `--config` | | String | | TOML with `[garch_midas] x_lf = [...]` (required for `--rv macro`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, alpha, beta, m, theta, w`) plus diagnostics (`log_likelihood, aic, bic, persistence` = α+β, `converged, iterations, variance_ratio, K, m_freq, n_blocks, rv, span`).

## Multivariate GARCH

`estimate ccc`, `estimate dcc`, and `estimate bekk` fit **multivariate** volatility models over the full numeric matrix (T×n, columns are series — there is no `--column`; use at least 2 numeric columns). Each headline output is the **conditional correlation matrix** rendered wide (series×series — the same documented exception as the input-output family), followed by a second-stage dynamics-coefficient table (omitted for CCC, which has none) and a diagnostics block (`loglik, aic, bic, series, observations, converged, kind`). A single-column input, a series with a missing cell, or a non-finite value surfaces a typed `data/*` error rather than an internal failure.

## estimate ccc

Estimate a **Constant Conditional Correlation** (Bollerslev 1990) MGARCH: a univariate GARCH(p,q) margin per series with a single constant correlation matrix. No second-stage optimization (the correlation is the closed-form standardized-residual correlation).

```bash
friedman estimate ccc returns.csv --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--p` | | Int | 1 | GARCH order p for the univariate margins |
| `--q` | | Int | 1 | ARCH order q for the univariate margins |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Conditional correlation matrix (wide) + diagnostics (no dynamics table — CCC has no second-stage parameters).

## estimate dcc

Estimate a **Dynamic Conditional Correlation** (Engle 2002) MGARCH with time-varying correlations, or the **cDCC** correction of Aielli (2013) via `--correction=aielli`. Reports the `[a, b]` correlation dynamics with QML sandwich standard errors and the last-period conditional correlation matrix.

```bash
friedman estimate dcc returns.csv --p=1 --q=1
friedman estimate dcc returns.csv --correction=aielli   # cDCC
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--p` | | Int | 1 | GARCH order p for the univariate margins |
| `--q` | | Int | 1 | ARCH order q for the univariate margins |
| `--correction` | | String | `none` | DCC targeting correction: `none` or `aielli` (cDCC) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Last-period conditional correlation matrix (wide) + dynamics coefficients (`a`, `b`) + diagnostics (adds `correction`, `persistence` = a+b).

## estimate bekk

Estimate a **BEKK(1,1)** (Engle & Kroner 1995) MGARCH, modelling the conditional covariance directly with variance targeting. `--kind=scalar` (default) estimates two news/persistence scalars `a, b`; `--kind=diagonal` estimates per-series `aᵢ, bᵢ`.

```bash
friedman estimate bekk returns.csv --kind=scalar
friedman estimate bekk returns.csv --kind=diagonal
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--kind` | | String | `scalar` | BEKK(1,1) parameterization: `scalar` or `diagonal` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Unconditional correlation matrix (wide) + dynamics coefficients (`a`, `b` for scalar; `aᵢ`, `bᵢ` for diagonal) + diagnostics (adds `bekk_kind`).

## estimate fastica

ICA-based non-Gaussian SVAR identification. Supports 5 ICA methods.

```bash
friedman estimate fastica data.csv --method=fastica --contrast=logcosh
friedman estimate fastica data.csv --method=jade
friedman estimate fastica data.csv --method=sobi
friedman estimate fastica data.csv --method=dcov
friedman estimate fastica data.csv --method=hsic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--method` | | String | `fastica` | `fastica`, `jade`, `sobi`, `dcov`, `hsic` |
| `--contrast` | | String | `logcosh` | `logcosh`, `exp`, `kurtosis` (FastICA only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Structural impact matrix (B0), structural shocks (first 10 observations).

## estimate ml

Maximum likelihood non-Gaussian SVAR identification.

```bash
friedman estimate ml data.csv --distribution=student_t
friedman estimate ml data.csv --distribution=mixture_normal
friedman estimate ml data.csv --distribution=pml
friedman estimate ml data.csv --distribution=skew_normal
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--distribution` | `-d` | String | `student_t` | `student_t`, `skew_t`, `ghd`, `mixture_normal`, `pml`, `skew_normal` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Structural impact matrix (B0), model fit (log-likelihood, AIC, BIC), distribution parameters, parameter estimates with standard errors.

## estimate vecm

Estimate a Vector Error Correction Model via Johansen MLE. Cointegration rank is auto-selected via trace test when `--rank` is omitted.

```bash
friedman estimate vecm data.csv --lags=2
friedman estimate vecm data.csv --rank=1 --deterministic=constant
friedman estimate vecm data.csv --lags=4 --rank=2 --method=johansen
friedman estimate vecm data.csv --significance=0.01
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--rank` | `-r` | Int | auto (Johansen) | Cointegration rank |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--method` | | String | `johansen` | Estimation method |
| `--significance` | | Float64 | 0.05 | Significance level for auto rank selection |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Cointegration rank, loading matrix (alpha), cointegrating vectors (beta), short-run coefficients.

## estimate pvar

Estimate a Panel VAR model via GMM or fixed-effects OLS.

```bash
friedman estimate pvar data.csv --id-col=country --time-col=year --lags=2
friedman estimate pvar data.csv --id-col=country --time-col=year --method=feols
friedman estimate pvar data.csv --id-col=country --time-col=year --vars=gdp,inflation,rate
friedman estimate pvar data.csv --id-col=country --time-col=year --transformation=fd
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--id-col` | | String | (required) | Panel group identifier column |
| `--time-col` | | String | (required) | Panel time identifier column |
| `--vars` | | String | | Comma-separated list of dependent variables |
| `--method` | | String | `gmm` | `gmm`, `feols` |
| `--transformation` | | String | `fd` | `fd` (first difference), `demean` |
| `--steps` | | String | `twostep` | `onestep`, `twostep` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient matrix with standard errors and p-values.

## estimate reg

OLS/WLS regression. If `--dep` is omitted, the first numeric column is used as the dependent variable and all remaining numeric columns are regressors.

```bash
friedman estimate reg data.csv --dep=wage --cov-type=hc1
friedman estimate reg data.csv --dep=wage --weights=pop_weight --cov-type=hc3
friedman estimate reg data.csv --dep=wage --clusters=state --cov-type=cluster
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3`, `cluster` |
| `--weights` | | String | | Weight variable column name (for WLS) |
| `--clusters` | | String | | Cluster variable column name |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`term|estimate|std_error|stat|p_value|ci_lower|ci_upper`, [C051](#coefficient-table-format-c051)) + fit statistics (R², Adj R², F-stat, AIC, BIC).

## Penalized, robust & censored regression

`estimate lasso | ridge | elastic-net | robust | tobit` extend the cross-section regression family beyond OLS. Like `estimate reg`, they take the dependent variable via `--dep` (default: first numeric column) and use all remaining numeric columns as regressors. A bad `--dep` surfaces a typed `data/column-range` error. Coefficient tables are hand-built (these result types are not Tables.jl-registered upstream — the C051 exception).

## estimate lasso

L1-penalized (Lasso) regression. `--lambda=auto` selects the penalty along a cross-validated path (rule set by `--select`); pass a number to fix it. The intercept is reported as `(Intercept)`; the `nonzero` column flags the active (selected) coefficients.

```bash
friedman estimate lasso data.csv --dep=y
friedman estimate lasso data.csv --dep=y --lambda=0.1
friedman estimate lasso data.csv --dep=y --select=bic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lambda` | | String | `auto` | `auto` (CV path) or a non-negative number |
| `--select` | | String | `cv` | Lambda selection rule: `cv`, `aic`, `bic`, `ebic` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`term|estimate|nonzero`, intercept first) + diagnostics (`alpha`, selected `lambda`, `n_active`, `r2`, `aic`, `bic`, `ebic`, `select`).

## estimate ridge

L2-penalized (Ridge) regression. Same options and output as `estimate lasso` (Ridge fixes the L1/L2 mix `alpha=0`).

```bash
friedman estimate ridge data.csv --dep=y --lambda=auto
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lambda` | | String | `auto` | `auto` (CV path) or a non-negative number |
| `--select` | | String | `cv` | Lambda selection rule: `cv`, `aic`, `bic`, `ebic` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

## estimate elastic-net

Elastic-Net regression — an L1/L2 mix controlled by `--alpha` (`1`=Lasso, `0`=Ridge).

```bash
friedman estimate elastic-net data.csv --dep=y --alpha=0.5
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--alpha` | | Float | 0.5 | L1/L2 mixing in [0,1] (1=Lasso, 0=Ridge) |
| `--lambda` | | String | `auto` | `auto` (CV path) or a non-negative number |
| `--select` | | String | `cv` | Lambda selection rule: `cv`, `aic`, `bic`, `ebic` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

## estimate robust

Robust regression by iteratively reweighted least squares (M) or high-breakdown MM estimation, with a Huber or Tukey-bisquare weight function. Reports coefficients with QML/sandwich standard errors.

```bash
friedman estimate robust data.csv --dep=y --psi=huber --method=m
friedman estimate robust data.csv --dep=y --psi=bisquare --method=mm
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--psi` | | String | `huber` | Weight function: `huber`, `bisquare` |
| `--method` | | String | `m` | Estimator: `m`, `mm` (MM = high-breakdown) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter|estimate|std_error|z_stat|p_value`) + diagnostics (`psi`, `method`, `scale`, `robust_r2`, `converged`, `iterations`).

## estimate tobit

Tobit (censored) regression by maximum likelihood, for a dependent variable censored at `--lower` and/or `--upper` (defaults: left-censored at 0, no upper bound).

```bash
friedman estimate tobit data.csv --dep=y --lower=0
friedman estimate tobit data.csv --dep=y --lower=0 --upper=100
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lower` | | Float | 0.0 | Lower censoring bound |
| `--upper` | | Float | Inf | Upper censoring bound (default: none) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter|estimate|std_error|z_stat|p_value`) + diagnostics (`sigma`, `loglik`, `aic`, `bic`, `lower`, `upper`, `n_censored_left`, `n_censored_right`, `converged`).

## estimate truncreg

Truncated-normal regression by maximum likelihood (Hausman & Wise 1977). Unlike Tobit, the sample is *truncated* — only observations with `--lower < y < --upper` are in the data (no censored mass). Every `y` must lie strictly inside the bounds or a `data/invalid` error is returned.

```bash
friedman estimate truncreg data.csv --dep=y --lower=0
friedman estimate truncreg data.csv --dep=y --lower=0 --upper=100
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lower` | | Float | 0.0 | Lower truncation bound |
| `--upper` | | Float | Inf | Upper truncation bound (default: none) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter|estimate|std_error|z_stat|p_value`) + diagnostics (`sigma`, `sigma_se`, `loglik`, `aic`, `bic`, `lower`, `upper`, `n_truncated`, `converged`).

## estimate heckman

Heckman sample-selection model — two equations: an outcome equation `--dep ~ --outcome-vars` observed only when the binary `--select` indicator is 1, and a selection equation `--select ~ --select-vars` (probit). Estimated by the Heckit two-step (`--method twostep`, default) or full-information MLE (`--method mle`). Include a `const` column in each variable list for an intercept (no auto-intercept, matching `estimate reg`). For identification beyond nonlinearity, `--select-vars` should include an *exclusion restriction* — a variable driving selection but not in `--outcome-vars`.

```bash
friedman estimate heckman data.csv --dep=lwage --select=inlf \
    --outcome-vars=const,educ,exper --select-vars=const,educ,exper,kids
friedman estimate heckman data.csv --dep=lwage --select=inlf \
    --outcome-vars=const,educ --select-vars=const,educ,kids --method=mle
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Outcome variable column name |
| `--select` | | String | (required) | Binary 0/1 selection-indicator column |
| `--outcome-vars` | | String | (required) | Outcome-equation regressor columns (comma-separated) |
| `--select-vars` | | String | (required) | Selection-equation regressor columns (comma-separated) |
| `--method` | | String | `twostep` | `twostep` (Heckit) or `mle` (FIML) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one tidy two-equation coefficient table (`equation|term|estimate|std_error|z_stat|p_value`, where `equation` is `outcome`/`selection`) + diagnostics (`method`, `rho` (+se), `sigma` (+se), `lambda` (+se), `loglik`, `aic`, `bic`, `n_selected`, `n_total`, `converged`). `HeckmanModel` is not Tables.jl-registered upstream, so the coefficient table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

## estimate statespace

Structural (linear-Gaussian) state-space models fitted by prediction-error-decomposition maximum likelihood on a single numeric `--column`. `--model local-level` fits the random-walk-plus-noise model (`yₜ = μₜ + εₜ`, `μₜ₊₁ = μₜ + ηₜ`); `--model local-linear-trend` adds a stochastic slope (state `[μₜ, βₜ]`). `--init-mode` selects the Kalman initialization (`kappa` large-variance diffuse by default, or exact `diffuse`).

```bash
friedman estimate statespace nile.csv --model=local-level
friedman estimate statespace gdp.csv --column=2 --model=local-linear-trend --init-mode=diffuse
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | 1-based numeric column to model |
| `--model` | | String | `local-level` | `local-level` or `local-linear-trend` |
| `--init-mode` | | String | `kappa` | Kalman initialization: `kappa` or `diffuse` |
| `--kappa` | | Float | 1e6 | Large-variance diffuse-init constant (`init-mode=kappa`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** hyper-parameter table (`parameter|estimate` — the estimated natural-scale variances σ̂², e.g. `σ²_ε`, `σ²_η`) + diagnostics (`model`, `loglik`, `converged`, `n_state`, `n_obs`, `method`). `StateSpaceModel` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

## estimate tvp

Time-varying-parameter regression with random-walk coefficients (`yₜ = Xₜ βₜ + εₜ`, `βₜ₊₁ = βₜ + ηₜ`), fitted via the Kalman filter/RTS smoother by MLE of the variance hyper-parameters. The whole point is the recovered coefficient *path* `βₜ`. A time-varying intercept is prepended automatically unless `--no-intercept` is set, so the data should NOT include a `const` column.

```bash
friedman estimate tvp phillips.csv --dep=inflation
friedman estimate tvp data.csv --dep=y --no-intercept
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--init-mode` | | String | `kappa` | Kalman initialization: `kappa` or `diffuse` |
| `--kappa` | | Float | 1e6 | Large-variance diffuse-init constant (`init-mode=kappa`) |
| `--no-intercept` | | Flag | off | Do NOT prepend a time-varying intercept coefficient |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** hyper-parameter table (`parameter|estimate`) + a tidy long coefficient-path table (`period|coefficient|estimate` — one row per time × coefficient) + diagnostics (`loglik`, `converged`, `n_coef`, `intercept`, `method`). Hand-built tables (documented [C051](#coefficient-table-format-c051) exception).

## estimate kde

Univariate kernel density estimate on an equally-spaced grid, for a single numeric `--column`. Bandwidth `--bw` is a rule (`silverman` = R `bw.nrd0`, `sj` = Sheather-Jones plug-in) or a positive number; `--kernel` selects a unit-variance kernel.

```bash
friedman estimate kde returns.csv --kernel=gaussian --bw=silverman
friedman estimate kde x.csv --column=1 --bw=0.5 --npoints=1024 --kernel=epanechnikov
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | 1-based numeric column |
| `--kernel` | | String | `gaussian` | `gaussian`, `epanechnikov`, `triangular`, `uniform` |
| `--bw` | | String | `silverman` | `silverman`, `sj`, or a positive number |
| `--npoints` | | Int | 512 | Number of grid points |
| `--cut` | | Float | 3.0 | Grid extends `cut·h` beyond the data range each side |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** density grid table (`x|density`) + diagnostics (`kernel`, `bw_method`, `bandwidth`, `nobs`). `KernelDensity` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

## estimate kernel-reg

Nonparametric regression of a response `--dep` on a SINGLE predictor `--indep`: Nadaraya-Watson (`--method nw`), local-linear (`--method ll`, default; boundary-bias corrected), or local-polynomial (`--method lp --degree d`). Bandwidth `--bw` is a rule (`cv` leave-one-out cross-validation, `rot` Silverman rule-of-thumb) or a positive number.

```bash
friedman estimate kernel-reg data.csv --dep=y --indep=x --method=ll --bw=cv
friedman estimate kernel-reg data.csv --dep=y --indep=x --method=lp --degree=2 --bw=0.4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Response variable column name |
| `--indep` | | String | (required) | Single predictor column name |
| `--method` | | String | `ll` | `nw`, `ll`, or `lp` |
| `--degree` | | Int | 1 | Local-polynomial degree (`method=lp`) |
| `--bw` | | String | `cv` | `cv`, `rot`, or a positive number |
| `--kernel` | | String | `gaussian` | `gaussian`, `epanechnikov`, `triangular`, `uniform` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** fitted-curve table (`x|fitted|se`, evaluated at the sorted design points) + diagnostics (`method`, `degree`, `kernel`, `bw_method`, `bandwidth`, `nobs`). `KernelRegression` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

## estimate lowess

Cleveland (1979) LOWESS/LOESS scatterplot smoother of a response `--dep` on a SINGLE predictor `--indep`: tricube-weighted local-linear fits over the `⌊f·n⌋` nearest neighbours, with `--iter` bisquare robustifying passes. `--frac` is the span `f ∈ (0,1]`.

```bash
friedman estimate lowess data.csv --dep=y --indep=x
friedman estimate lowess data.csv --dep=y --indep=x --frac=0.3 --iter=5
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Response variable column name |
| `--indep` | | String | (required) | Single predictor column name |
| `--frac` | | Float | 0.6667 | Smoother span `f ∈ (0,1]` (fraction of points per window) |
| `--iter` | | Int | 3 | Number of bisquare robustifying passes |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** smoothed-curve table (`x|fitted`, sorted by `x`) + diagnostics (`frac`, `iter`, `nobs`). `LowessFit` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

## estimate cointreg

Single-equation **cointegrating regression** for a long-run relationship `y_t = D_t'δ + x_t'β + u_t` where the `--dep` variable and the other numeric columns are `I(1)` (integrated of order 1). Three estimators correct the OLS-on-levels fit for regressor endogeneity and error serial correlation: `fmols` (Phillips-Hansen fully-modified OLS), `ccr` (Park canonical cointegrating regression), and `dols` (Saikkonen / Stock-Watson dynamic OLS). Deterministics are added via `--trend` (the cointreg vocabulary is `none|const|linear` — do not confuse with the ARDL/PMG trend vocabularies). No intercept is prepended to the regressor matrix — cointreg builds its own deterministic block.

```bash
friedman estimate cointreg data.csv --dep=y --method=fmols
friedman estimate cointreg data.csv --dep=y --method=dols --leads=2 --lags=2 --ic=bic
friedman estimate cointreg data.csv --dep=y --method=ccr --trend=linear --kernel=qs --bandwidth=nw94
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent (levels) column name |
| `--method` | | String | `fmols` | `fmols`, `ccr`, `dols` |
| `--trend` | | String | `const` | Deterministics: `none`, `const`, `linear` |
| `--kernel` | | String | `bartlett` | HAC kernel: `bartlett`, `parzen`, `qs`, `tukey-hanning` |
| `--bandwidth` | | String | `andrews` | `andrews`, `nw94`, or a fixed truncation lag (≥0) |
| `--leads` | | String | `auto` | DOLS leads: `auto` or a non-negative integer |
| `--lags` | | String | `auto` | DOLS lags: `auto` or a non-negative integer |
| `--ic` | | String | `aic` | DOLS lead/lag selection: `aic`, `bic` |
| `--dols-se` | | String | `lrv` | DOLS standard errors: `lrv`, `robust` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** tidy long-run coefficient table (`term|estimate|std_error|stat|p_value|ci_lower|ci_upper`; p-values/CIs use the large-sample normal approximation, the estimators being asymptotically mixed-normal) + diagnostics (`method`, `trend`, `kernel`, resolved `bandwidth`, `omega_uv`, `nobs`, `d`, `k`; DOLS adds `leads`/`lags`). `CointRegModel` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). `--bandwidth`/`--leads`/`--lags` are dual-type flags parsed in-handler; note `--bandwidth 4` = a fixed truncation lag while `--bandwidth andrews` = data-driven selection.

## estimate xtcointreg

**Panel cointegrating regression** across the `N` units of a long-format panel (`--id-col`/`--time-col` default to the first/second columns). Each unit is fit by the single-equation estimator ([`estimate cointreg`](#estimate-cointreg)) and aggregated either group-mean (`--pooling=group`, Pedroni 2001 between-dimension) or pooled (`--pooling=pooled`, within-dimension: Pedroni 2000 FMOLS / Kao-Chiang 2000 DOLS). Only `fmols` and `dols` are available for panels (no `ccr`).

```bash
friedman estimate xtcointreg panel.csv --dep=lc --indep=ly --method=fmols --pooling=group
friedman estimate xtcointreg panel.csv --id-col=country --time-col=year --dep=lc --indep=ly,r --method=dols --pooling=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--id-col` | | String | (1st col) | Panel group id column |
| `--time-col` | | String | (2nd col) | Panel time column |
| `--dep` | | String | (1st var) | Dependent panel variable |
| `--indep` | | String | (all others) | Regressors, comma-separated |
| `--method` | | String | `fmols` | `fmols`, `dols` (no `ccr` for panels) |
| `--pooling` | | String | `group` | `group` (between) or `pooled` (within) |
| `--trend` | | String | `const` | Per-unit deterministics: `none`, `const`, `linear` |
| `--kernel` | | String | `bartlett` | HAC kernel: `bartlett`, `parzen`, `qs`, `tukey-hanning` |
| `--bandwidth` | | String | `andrews` | `andrews`, `nw94`, or a fixed truncation lag (≥0) |
| `--leads` | | String | `auto` | DOLS leads: `auto` or a non-negative integer |
| `--lags` | | String | `auto` | DOLS lags: `auto` or a non-negative integer |
| `--ic` | | String | `aic` | DOLS lead/lag selection: `aic`, `bic` |
| `--dols-se` | | String | `lrv` | DOLS standard errors: `lrv`, `robust` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** tidy panel coefficient table (`term|estimate|std_error|stat|p_value|ci_lower|ci_upper`; group-mean reports Pedroni's between-dimension `t`-statistic and a back-solved display SE that can be `Inf` for a degenerate coefficient — rendered non-finite-safe) + diagnostics (`method`, `pooling`, `trend`, `kernel`, `N` units, total `nobs`, `T_i` span, `balanced`, `k`, `d`). `PanelCointRegModel` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

## estimate ardl

**Autoregressive distributed-lag** model `ARDL(p, q₁…q_k)`, estimated by OLS on the lagged **levels** of `y` and the regressors. Loads `y` + `X` via the shared regression loader (`--dep` = dependent; all other numeric columns are regressors; **no intercept is prepended** — ARDL adds its own deterministics per the Pesaran-Shin-Smith `--case`). The single leaf folds three views into one call: the levels-form coefficient table, the **long-run** (level) multipliers `θ̂_j = (Σ_ℓ β̂_{jℓ})/(1 − Σ_i φ̂_i)` with delta-method standard errors, and the **error-correction** speed of adjustment `α = Σφ̂ − 1` (in the diagnostics).

```bash
# ARDL(1,1): y on x with one AR lag and one distributed lag, unrestricted intercept (case III)
friedman estimate ardl data.csv --dep=y --p=1 --q=1 --case=3

# IC-selected lag orders (AIC grid over p∈1:max-p, q∈0:max-q)
friedman estimate ardl data.csv --dep=y --p=auto --q=auto --max-p=4 --max-q=4 --ic=aic

# Per-regressor distributed-lag orders (one entry per regressor)
friedman estimate ardl data.csv --dep=y --p=2 --q=2,1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--p` | | String | `auto` | AR order: `auto` or an integer ≥ 1 |
| `--q` | | String | `auto` | DL order: `auto`, an integer, or a comma-separated per-regressor list |
| `--max-p` | | Int | `4` | Max AR order for `auto` IC selection |
| `--max-q` | | Int | `4` | Max DL order for `auto` IC selection |
| `--ic` | | String | `aic` | Selection criterion: `aic`, `bic` |
| `--case` | | Int | `3` | PSS deterministic case 1..5 (I none; II restricted intercept; III unrestricted intercept; IV +restricted trend; V +trend) |
| `--trend` | | String | `none` | Informational trend label: `none`, `const`, `trend` (deterministics are governed by `--case`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** levels coefficient table (`term|estimate|std_error|stat|p_value`) + a long-run coefficient table + diagnostics (`p`, `q`, `case`, `trend`, `ic`, `selected`, `nobs`, `K`, `sigma2`, `loglik`, `aic`, `bic`, `alpha`, `alpha_se`, `alpha_t`, `longrun_denom` = `1 − Σφ̂`). `ARDLModel` is not Tables.jl-registered, so tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). See [`test ardl-bounds`](test.md#test-ardl-bounds) for the Pesaran-Shin-Smith bounds test. **Trend-vocabulary note:** ARDL uses `none|const|trend` (distinct from cointreg's `none|const|linear` and PMG's `:constant`).

## estimate nardl

**Nonlinear (asymmetric) ARDL** of Shin, Yu & Greenwood-Nimmo (2014). Each regressor selected by `--asymmetric` is decomposed into positive/negative partial sums `x⁺, x⁻` (cumulated from `Δx`), and the pair replaces the original column in the ARDL design. The enlarged design is estimated by the same ARDL machinery, so an asymmetric regressor contributes **two** columns to the number-of-regressors `k` that indexes the bounds table. The single leaf folds the split-regressor coefficient table, the asymmetric long-run coefficients (θ⁺/θ⁻), and the cached enlarged-`k` **bounds decision** (F/t decision symbols — no p-value) into one call.

```bash
# Split every regressor into +/- partial sums
friedman estimate nardl data.csv --dep=y --asymmetric=all --p=1 --q=1

# Split only the 1st and 3rd regressors (others enter symmetrically)
friedman estimate nardl data.csv --dep=y --asymmetric=1,3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--asymmetric` | | String | `all` | `all` or comma-separated 1-based regressor indices to split |
| `--p` | | String | `auto` | AR order: `auto` or an integer ≥ 1 |
| `--q` | | String | `auto` | DL order: `auto`, an integer, or a comma-separated list (over the **split** regressors) |
| `--max-p` | | Int | `4` | Max AR order for `auto` IC selection |
| `--max-q` | | Int | `4` | Max DL order for `auto` IC selection |
| `--ic` | | String | `aic` | Selection criterion: `aic`, `bic` |
| `--case` | | Int | `3` | PSS deterministic case 1..5 |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** split-regressor coefficient table (labels carry `_POS`/`_NEG` suffixes) + asymmetric long-run table (θ⁺/θ⁻) + diagnostics including the enlarged-`k` bounds decision (`k_orig`, `k`, `asym`, `f_stat`, `t_stat`, `f_decision`, `t_decision`, `bounds_level`). NARDL has no `--trend` option (informational-only upstream). See [`test nardl-symmetry`](test.md#test-nardl-symmetry) for the long-/short-run symmetry Wald tests and [`multipliers nardl`](multipliers.md) for the cumulative dynamic multipliers.

## estimate pmg

**Dynamic heterogeneous-panel ARDL** in error-correction form (Pesaran, Shin & Smith 1999), estimated on a long-format panel (`--id-col`/`--time-col` default to the first/second columns; regressors via `--indep`). `--method` selects the estimator:

- `pmg` — **Pooled Mean Group**: a common long-run vector `θ` across units, with heterogeneous short-run dynamics and per-unit error-correction speeds `φ_i`. Fit by concentrated ML (block coordinate ascent).
- `mg` — **Mean Group** (Pesaran & Smith 1995): an unrestricted per-unit ARDL, averaged across units.
- `dfe` — **Dynamic Fixed Effects**: a pooled within-transformed EC regression with unit intercepts and cluster-robust SEs.

Each unit's ARDL(`p`, `q`) is written as `Δy_it = φ_i (y_{i,t-1} − θ' x_{i,t-1}) + Σ ξ_ij Δy_{i,t-j} + Σ ψ_ij' Δx_{i,t-j} + deterministics_i + ε_it`.

```bash
# Pooled Mean Group: common long-run theta + heterogeneous short-run
friedman estimate pmg panel.csv --id-col=id --time-col=time --dep=y --indep=x1,x2 --method=pmg

# Mean Group and Dynamic Fixed Effects alternatives
friedman estimate pmg panel.csv --dep=y --indep=x1,x2 --method=mg
friedman estimate pmg panel.csv --dep=y --indep=x1,x2 --method=dfe --p=2 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--id-col` | | String | (1st column) | Panel group id column |
| `--time-col` | | String | (2nd column) | Panel time column |
| `--dep` | | String | (1st variable) | Dependent panel variable |
| `--indep` | | String | (all others) | Long-run regressors, comma-separated |
| `--method` | | String | `pmg` | `pmg`, `mg`, `dfe` |
| `--trend` | | String | `constant` | Per-unit EC deterministics: `none`, `constant`, `trend` |
| `--p` | | Int | `1` | Autoregressive order (≥ 1) |
| `--q` | | Int | `1` | Distributed-lag order for all regressors (≥ 0) |
| `--maxiter` | | Int | `100` | PMG outer-loop max iterations |
| `--tol` | | Float64 | `1e-8` | PMG outer-loop convergence tolerance |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a long-run coefficient table `θ` (`term|estimate|std_error|stat|p_value`) + a short-run/error-correction table (`term|estimate|std_error`, with the adjustment speed `φ` as the first row) + diagnostics (`method`, `N`, `p`, `q`, `T_i`, `phi`, `phi_se`, `loglik`, `converged`, `iters`, `n_nonconv`). `PMGModel` is not Tables.jl-registered, so tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). Display SEs (`φ`, `θ`) can be `Inf` for degenerate units — rendered non-finite-safe. See [`test pmg-hausman`](test.md#test-pmg-hausman) for the PMG-vs-MG selection test. **Trend-vocabulary note:** PMG spells `--trend=constant` out — distinct from ARDL's `none|const|trend` and cointreg's `none|const|linear`; do not carry a `const` value here.

## estimate midas

**MIDAS (MIxed-DAta Sampling) regression** (Ghysels, Sinko & Valkanov 2007) of a **low-frequency** target on `--k` **high-frequency** lags of a single indicator, aggregated through a parsimonious weight function `w(θ)`. The equation is `y_t = β₀ + β₁·Σₖ wₖ(θ) x_{t,k} + Σⱼ ρⱼ y_{t−j} + u_t`, where `x_{t,k}` is the `k`-th high-frequency lag (most-recent-first) inside low-frequency period `t`, and the `--p-ar` term makes it an ADL-MIDAS.

This is the only estimator with a **two-CSV mixed-frequency contract**: the low-frequency target comes from `--data` (column `--column`), and the high-frequency indicator from a separate `--hf-data` CSV (column `--hf-column`). The HF series must supply **at least** `--m` observations per low-frequency period, i.e. `length(HF) ≥ m × length(LF)`. The estimator anchors the *last* HF observation to the *last* target period and works backwards, so any **leading** ragged edge (extra early HF history) is dropped automatically — the natural nowcasting layout (a long high-frequency indicator against a shorter low-frequency target) is fully supported, and the number of dropped leading HF observations is reported on stderr. Only a HF series *shorter* than `m × LF` is rejected as a typed `data/shape` error. Both inputs load through the hardened univariate loader, so a missing/non-numeric cell or out-of-range column surfaces a typed `data/missing-values`/`data/column-range`.

`--weights` selects the aggregation scheme:

- `expalmon` (default) — two-parameter **exponential Almon** curve (Ghysels et al.), estimated by profiled NLS.
- `beta2` / `beta3` — **Beta** density weights (2- or 3-parameter); require `--k ≥ 2`.
- `almon` — polynomial Almon of degree `--poly-degree`.
- `umidas` — **unrestricted** U-MIDAS (Foroni, Marcellino & Schumacher 2015): the `K` lags enter with free coefficients (plain OLS, no weight function).

```bash
# Nowcast a quarterly target from a monthly indicator (m = 3, 6 monthly lags)
friedman estimate midas gdp_q.csv --hf-data ip_m.csv --m 3 --k 6 --weights expalmon

# ADL-MIDAS with one autoregressive lag of the target and Beta weights
friedman estimate midas gdp_q.csv --hf-data ip_m.csv --m 3 --k 6 --weights beta2 --p-ar 1

# Unrestricted U-MIDAS (OLS on the K stacked lags)
friedman estimate midas gdp_q.csv --hf-data ip_m.csv --m 3 --k 6 --weights umidas
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | | Int | `1` | Low-frequency target column in `--data` (1-based) |
| `--hf-data` | | String | | **Required.** High-frequency indicator CSV |
| `--hf-column` | | Int | `1` | High-frequency indicator column in `--hf-data` (1-based) |
| `--m` | | Int | | **Required, ≥ 1.** Frequency ratio HF/LF (e.g. 3 = monthly→quarterly) |
| `--k` | | Int | | **Required, ≥ 1.** Number of high-frequency lags |
| `--weights` | | String | `expalmon` | `expalmon`, `beta2`, `beta3`, `almon`, `umidas` |
| `--p-ar` | | Int | `0` | Autoregressive lags of the target (ADL-MIDAS, ≥ 0) |
| `--poly-degree` | | Int | `2` | Polynomial degree for `--weights almon` |
| `--horizon` | | Int | `1` | Direct forecast horizon `h` stored in the model (1 = nowcast) |
| `--max-iter` | | Int | `500` | LBFGS iteration cap per NLS start |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a headline **weight-curve table** (`lag|weight`, length `K`, most-recent-first; for `umidas` these are the raw lag coefficients) + a coefficient table (`term|estimate|std_error|stat|p_value` over `[β; θ]`, normal-approximation p-values) + diagnostics (`weights_kind`, `m`, `K`, `p_ar`, `poly_degree`, `h`, `nobs`, `r2`, `adj_r2`, `ssr`, `sigma2`, `aic`, `bic`, `loglik`, `converged`). `MidasModel` is not Tables.jl-registered, so tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). The restricted NLS is noisy on short samples; a "failed to converge from any start" is surfaced as `model/convergence`. `forecast midas` is deferred to a later release. **Frequency-alignment note:** the loader requires `length(HF) ≥ m × length(LF)` and drops the leading ragged edge (reported on stderr); the estimator then drops any remaining incomplete `K`-block internally.

## estimate threshold

**Two-regime threshold regression** (Hansen 1996, 2000) — the general case, where the sample is split by a **separate** threshold variable rather than by a lag of the dependent variable. The model is `yᵢ = xᵢ'β₁·1{qᵢ ≤ γ} + xᵢ'β₂·1{qᵢ > γ} + uᵢ`. The threshold `γ` is estimated by grid search over the trimmed order statistics of `q`, minimising the concentrated sum of squared residuals; each regime is then fit by OLS and `γ`'s confidence interval inverts the Hansen (2000) likelihood-ratio statistic. [`estimate setar`](#estimate-setar) is the self-exciting special case of this command (`q = y_{t−d}`, `X` the lag matrix) and returns the same model type.

**Column partition:** `--dep` is the dependent variable, **`--threshold-col` is required** and names the splitting variable, and **every other numeric column becomes a regressor**. The threshold variable is deliberately *excluded* from the regressor matrix — including it would make the regressors collinear with the split and silently fit a different model rather than raise an error. No intercept is prepended: add a `const` column if you want one (the same convention as [`estimate reg`](#estimate-reg)).

As with `estimate setar`, a **Hansen (1996) sup-LM / sup-Wald linearity test** is fitted alongside by default and folded into the diagnostics (`--no-linearity` skips it; `--het` uses a heteroskedastic White bootstrap). `--ci-level` must be **exactly** `0.90`, `0.95`, or `0.99` — the Hansen (2000) critical values are tabulated only at those levels.

```bash
# Split the sample on z; x1 and x2 are the regressors, y the outcome
friedman estimate threshold data.csv --dep y --threshold-col z

# 90% threshold CI, heteroskedastic bootstrap, skip the linearity test
friedman estimate threshold data.csv --dep y --threshold-col z --ci-level 0.90 --het --no-linearity
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | first numeric | Dependent variable column |
| `--threshold-col` | | String | | **Required** — the variable that splits the sample (excluded from the regressors) |
| `--trim` | | Float | `0.15` | Trimming fraction for the threshold grid (0 < trim < 0.5) |
| `--reps` | | Int | `1000` | Bootstrap replications for the linearity test (≥ 1) |
| `--ci-level` | | Float | `0.95` | Threshold CI level: `0.90`, `0.95`, or `0.99` (exact) |
| `--het` | | Flag | off | Heteroskedasticity-robust bootstrap |
| `--no-linearity` | | Flag | off | Skip the Hansen (1996) linearity test |
| `--plot` | | Flag | off | Display an interactive plot |
| `--plot-save` | | String | | Save the plot to an HTML file |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one **two-regime coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`, with the blocks `regime1 (<q>≤γ)` / `regime2 (<q>>γ)` stacked and labelled with the actual threshold-variable name, normal-approximation z/p) + a diagnostics block (`threshold_var`, `gamma`, `gamma_ci_lower`, `gamma_ci_upper`, `gamma_ci_level`, `n`, `n1`, `n2`, `ssr`, `sigma2`, `aic`, `bic`, `is_setar`, and — unless `--no-linearity` — `sup_lm`, `pvalue_lm`, `sup_wald`, `pvalue_wald`, `gamma_sup`). `ThresholdModel` is not Tables.jl-registered, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). Every option is validated up-front (`usage/invalid`); a constant threshold variable, a sample too small for two regimes, or any other estimator failure surfaces as a typed `data/invalid`/`model/error`, never an uncaught internal error.

## estimate setar

**Self-exciting threshold autoregression (SETAR)** (Tong 1990; Hansen 2000) — a two-regime autoregression whose regime is switched by a lagged value of the series itself. The model is `yₜ = X_t'β₁·1{qₜ ≤ γ} + X_t'β₂·1{qₜ > γ} + uₜ`, with `qₜ = y_{t−d}` the self-exciting threshold variable and `X_t = [1, y_{t−1}, …, y_{t−p}]`. The threshold `γ` is estimated by grid search over the trimmed order statistics of `q`, minimising the concentrated sum of squared residuals; its confidence interval inverts the Hansen (2000) likelihood-ratio statistic (tabulated only for the three levels below).

`--d` is the delay lag `d` and accepts either a positive integer or `auto` (search the `1:p` grid and pick the delay with the smallest concentrated SSR). By default a **Hansen (1996) sup-LM / sup-Wald linearity test** is fitted alongside and folded into the diagnostics (`--no-linearity` skips it; `--het` uses a heteroskedastic White bootstrap for its p-values). `--ci-level` must be **exactly** one of `0.90`, `0.95`, `0.99` — the Hansen (2000) critical values are tabulated only at those levels.

```bash
# SETAR(2; 1, 1) with delay d = 1 and 1000 bootstrap replications
friedman estimate setar y.csv --p 1 --d 1

# Auto-select the delay over the 1:p grid; heteroskedastic bootstrap, no linearity test
friedman estimate setar y.csv --p 2 --d auto --het --no-linearity
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--p` | | Int | `1` | AR order (≥ 1) |
| `--d` | | String | `1` | Delay lag: an integer ≥ 1, or `auto` (=`1:p` grid) |
| `--trim` | | Float | `0.15` | Trimming fraction for the threshold grid (0 < trim < 0.5) |
| `--reps` | | Int | `1000` | Bootstrap reps for the Hansen test / threshold CI (≥ 1) |
| `--ci-level` | | Float | `0.95` | Threshold CI level: `0.90`, `0.95`, or `0.99` (exact) |
| `--het` | | Flag | off | Heteroskedastic (White) bootstrap |
| `--no-linearity` | | Flag | off | Skip the attached Hansen (1996) linearity test |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one **two-regime coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`, with the two regime blocks `regime1 (q≤γ)` / `regime2 (q>γ)` stacked, normal-approximation z/p) + a diagnostics block (`gamma`, `gamma_ci_lower`, `gamma_ci_upper`, `gamma_ci_level`, `n`, `n1`, `n2`, `ssr`, `sigma2`, `aic`, `bic`, `p`, `d`, `is_setar`, and — unless `--no-linearity` — the attached `sup_lm`, `pvalue_lm`, `sup_wald`, `pvalue_wald`, `gamma_sup`). `ThresholdModel` is not Tables.jl-registered, so the coefficient table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). Every option is validated up-front (`usage/invalid`); a too-short series or other estimator failure surfaces as a typed `data/invalid`/`model/error`, never an uncaught internal error. See also [`estimate threshold`](#estimate-threshold) (the general case, split by a separate variable), [`test hansen-linearity`](test.md#test-hansen-linearity) (the standalone linearity test) and [`forecast setar`](forecast.md#forecast-setar) (bootstrap-simulation forecasts).

## estimate star

**Smooth-transition autoregression (STAR)** (Teräsvirta 1994) — the smooth-transition sibling of SETAR. The conditional mean is a convex combination of two linear autoregressions whose weight is a smooth function `G(sₜ; γ, c) ∈ [0, 1]` of a transition variable `sₜ`: `yₜ = φ₁'zₜ·(1 − G) + φ₂'zₜ·G + uₜ`, with `zₜ = [1, y_{t−1}, …, y_{t−p}]`. Unlike SETAR's abrupt switch, `G` transitions smoothly, and the parameters are estimated by nonlinear least squares.

`--type` selects the transition shape: **`lstr1`** (logistic, one location), **`lstr2`** (logistic, two locations), **`estr`** (exponential), or **`auto`** (Teräsvirta's sequential LM3 model-selection procedure picks LSTR1 vs ESTR and reports the `H₀₄`/`H₀₃`/`H₀₂` p-value triple). By default the transition variable is self-exciting (`sₜ = y_{t−d}`, delay `--d`); an external transition series can be supplied via `--transition-col` (a 1-based column index, which then must be non-constant). `--n-gamma`/`--n-c` set the start-value grid resolution for the NLS.

```bash
# STAR(1) with auto shape selection, self-exciting transition sₜ = y_{t−1}
friedman estimate star y.csv --p 1 --d 1 --type auto

# Fix a logistic one-location LSTR1(2); external transition variable in column 3
friedman estimate star y.csv --p 2 --type lstr1 --transition-col 3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--p` | | Int | `1` | AR order (≥ 1) |
| `--d` | | Int | `1` | Delay lag for the self-exciting transition var (≥ 1) |
| `--type` | | String | `auto` | Transition shape: `lstr1`, `lstr2`, `estr`, `auto` |
| `--n-gamma` | | Int | `15` | Grid points for the γ start values (≥ 2) |
| `--n-c` | | Int | `15` | Grid points for the c start values (≥ 2) |
| `--transition-col` | | Int | `0` | Column of an external transition var s (0 = self-exciting) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** two hand-built tables plus diagnostics — a **regime-weight coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`, the two blocks `regime1 (G→0)` / `regime2 (G→1)` stacked) and a **transition-parameters table** (`parameter|estimate|std_error|z_stat|p_value` over `γ` and the location(s) `c`, length 1 for LSTR1/ESTR or 2 for LSTR2), both with normal-approximation z/p; then a diagnostics block (`trans_type`, `sname`, `sigma_s`, `n`, `p`, `d`, `ssr`, `sigma2`, `aic`, `bic`, the Luukkonen–Saikkonen–Teräsvirta LM3 statistics `lm3_stat`/`lm3_pvalue`/`lm3_fstat`/`lm3_fpvalue`, `converged`, and — for `--type auto` only — the Teräsvirta selection triple `sel_H04`/`sel_H03`/`sel_H02`). Note the two **regime weights** here (`1−G` / `G`) are smooth combination weights, unlike SETAR's hard split; the `switching_variance` diagnostic is a Markov-switching concept and does not apply to STAR. `STARModel` is not Tables.jl-registered, so the tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). Every option is validated up-front (`usage/invalid`); a constant transition variable, too-short series, or NLS failure surfaces as a typed `data/invalid`/`data/shape`/`model/error`, never an uncaught internal error. See also [`test star-linearity`](test.md#test-star-linearity) and [`forecast star`](forecast.md#forecast-star).

## estimate ms-ar

**Markov-switching autoregression (MS-AR)** (Hamilton 1989) — the *mean-switching* autoregression `(yₜ − μ_{sₜ}) = Σⱼ φⱼ (y_{t−j} − μ_{s_{t−j}}) + εₜ`, `εₜ ~ N(0, σ²_{sₜ})`, where a latent `K`-state Markov chain `sₜ` (with transition matrix `P`) switches the level `μ` while the AR coefficients `φ` are **common** across regimes. Estimated by the Hamilton forward filter, the Kim smoother, and EM with a maximum-likelihood polish (delta-method standard errors). Regimes are labelled deterministically in order of increasing conditional mean `μ` (defeating label-switching across seeds), so regime 1 is always the lowest-mean state.

> **Note the `switching_variance` polarity:** for `estimate ms-ar` the variance is **common by default** (the Hamilton form) — `--switching-variance` turns per-regime variances *on*. This is the **opposite** default of [`estimate ms`](#estimate-ms), where the variance switches by default (`--no-switching-variance` turns it off). The two are intentionally not unified.

```bash
# 2-regime MS-AR(1) with a common variance (Hamilton form)
friedman estimate ms-ar y.csv --p 1

# 3-regime MS-AR(2) with per-regime (switching) variances
friedman estimate ms-ar y.csv --p 2 --k-regimes 3 --switching-variance
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--p` | | Int | `1` | AR order (≥ 1) |
| `--k-regimes` | | Int | `2` | Number of regimes (≥ 2) |
| `--max-iter` | | Int | `1000` | Max EM iterations (≥ 1) |
| `--switching-variance` | | Flag | off | Let σ² switch across regimes (default: off, Hamilton form) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** four hand-built tables plus diagnostics — a **per-regime coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`: one switching `mu` row per regime, then a single `common-AR` block for the shared φ₁…φₚ, normal-approximation z/p), a **per-regime variance table** (`regime|sigma2|std_error`), the **wide K×K transition matrix** (`from_regime|to_regime1|…|to_regimeK`, `P[i,j] = Pr(sₜ=j | s_{t−1}=i)`, rows sum to 1) — the transition matrix renders **wide** (regime×regime), a documented [C051](#coefficient-table-format-c051) exception parallel to the MGARCH conditional-correlation matrix — and the **regime-probability table** described below; then a diagnostics block (`loglik`, `n_params`, `aic`, `bic`, per-regime `ergodic_k` and `expected_duration_k`, `switching_var`, `switching_ar`, `converged`, `iterations`). `MSRegModel` is not Tables.jl-registered, so all tables are hand-built. Every option is validated up-front (`usage/invalid`); a too-short series or EM failure surfaces as a typed `data/invalid`/`model/error`, never an uncaught internal error.

### Regime probabilities

Both `estimate ms-ar` and `estimate ms` emit a **regime-probability table** — for most applied
work the point of fitting a Markov-switching model at all, since it answers "which regime were
we in at time *t*":

```
period | regime  | filtered | smoothed
```

`filtered` is `Pr(sₜ = k | y₁…yₜ)` (real time, using only information available at `t`) and
`smoothed` is `Pr(sₜ = k | y₁…y_n)` (full sample). The smoothed path is the sharper of the two
and is what you normally want for dating regimes historically; the filtered path is what a
real-time observer would have seen.

The table is **long**, not one column per regime: `K` comes from `--k-regimes`, so a wide layout
would make the *column set* depend on a user option and every consumer would have to discover
`K` before reading the table. Long keeps the columns fixed and grows the row count (`n × K`)
instead — the same reasoning as
[`predict statespace`](predict_residuals.md#state-space-predict-statespace-residuals-statespace).
With `--output <file>` it is written to a `…_probabilities` path so it does not overwrite the
coefficient table.

## estimate ms

**Markov-switching regression (MS)** — a `K`-state switching regression `yₜ = xₜ'β_{sₜ} + εₜ`, `εₜ ~ N(0, σ²_{sₜ})`, where **every** coefficient (not just the level) switches with the latent `K`-state Markov chain, and (by default) the variance switches too. Regressors come from the numeric columns other than `--dep` (**no auto-intercept** — include a `const` column, exactly like [`estimate reg`](#estimate-reg)); when the dependent variable is the **only** numeric column, the command routes to the single-argument intercept-only dispatch (a switching-intercept model, `X = ones(n, 1)`). Regimes are labelled by increasing conditional mean.

> **Note the `switching_variance` polarity:** for `estimate ms` the variance **switches by default** — `--no-switching-variance` forces a common σ². This is the **opposite** default of [`estimate ms-ar`](#estimate-ms-ar) (common variance by default).

```bash
# 2-regime switching regression: dep = y, regressors = the other numeric columns (add a const)
friedman estimate ms data.csv --dep y

# Intercept-only switching-mean model (dep is the only numeric column), common variance
friedman estimate ms y.csv --no-switching-variance
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | | Dependent variable column (default: first numeric) |
| `--k-regimes` | | Int | `2` | Number of regimes (≥ 2) |
| `--max-iter` | | Int | `500` | Max EM iterations (≥ 1) |
| `--tol` | | Float | `1e-8` | EM convergence tolerance (> 0) |
| `--no-switching-variance` | | Flag | off | Force a common σ² across regimes (default: σ² switches) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** the same four hand-built tables as [`estimate ms-ar`](#estimate-ms-ar) (including the [regime-probability table](#regime-probabilities)) rendered by the shared renderer, but the per-regime coefficient table carries the **full per-regime switching coefficients** over the regressor names (`regime|term|estimate|std_error|z_stat|p_value`) rather than a `mu` row + common-AR block; then the per-regime variance table, the wide K×K transition matrix (a documented [C051](#coefficient-table-format-c051) wide exception), and the same diagnostics kv. Every option is validated up-front (`usage/invalid`); a too-short series, a dimension mismatch, or EM failure surfaces as a typed `data/invalid`/`data/shape`/`model/error`, never an uncaught internal error.

## estimate iv

Instrumental variables (2SLS) regression. `--endogenous` names the endogenous regressor(s) and `--instruments` names the **excluded** instrument(s) — extra columns that identify the endogenous regressors but do not enter the structural equation. Every *other* numeric column (besides `--dep` and the endogenous ones) is treated as an exogenous regressor and instrument; include a `const` column of ones for an intercept. So the regressor matrix `X` = all columns except `{dep, excluded instruments}`, and the instrument matrix `Z` = all columns except `{dep, endogenous}`.

```bash
# wage ~ const + exper + educ, with educ endogenous, instrumented by father_educ, mother_educ
friedman estimate iv data.csv --dep=wage --endogenous=educ --instruments=father_educ,mother_educ
friedman estimate iv data.csv --dep=log_wage --endogenous=educ,exper --instruments=z1,z2,z3 --cov-type=hc1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--endogenous` | | String | (required) | Comma-separated endogenous regressor column names |
| `--instruments` | | String | (required) | Comma-separated **excluded** instrument column names (need at least as many as endogenous regressors) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + IV diagnostics (first-stage F-statistic, Sargan overidentification test). See also [`test weak-instrument`](test.md) for the full Stock-Yogo weak-instrument battery.

**k-class family (#72).** `--method` selects the estimator:

| `--method` | k used | Notes |
|---|---|---|
| `tsls` (default) | 1 | Two-stage least squares |
| `liml` | κ̂ | Limited-information maximum likelihood |
| `fuller` | κ̂ − a/(n−m) | Fuller (1977); `--fuller-a` (default 1) is approximately unbiased |
| `kclass` | your `--k` | Generic k-class: `--k 0` is OLS, `--k 1` is exactly 2SLS |

`--k` is **required** with `--method kclass` and rejected with any other method;
`--fuller-a` applies only to `--method fuller`. Both are usage errors (exit 2) rather
than upstream failures. The diagnostics block reports the `k-class k` actually used and,
for LIML/Fuller, `kappa_hat`.

```bash
friedman estimate iv data.csv --dep=y --endogenous=educ --instruments=z1,z2 --method=liml
friedman estimate iv data.csv --dep=y --endogenous=educ --instruments=z1,z2 --method=kclass --k=1
```

## estimate select

General-to-specific and stepwise variable selection. This is a **dedicated leaf rather
than an `estimate reg --select` flag**, so `estimate reg`'s envelope tables stay fixed —
a leaf whose table set changes with a flag forces every consumer to branch on it.

Regressors are every numeric column except `--dep`, and no intercept is prepended, so
include a `const` column if you want one. The result carries the refitted final model,
so the coefficient table is exactly what `estimate reg` would print for the selected
subset.

```bash
friedman estimate select data.csv --dep=y
friedman estimate select data.csv --dep=y --method=gets --criterion=bic
friedman estimate select data.csv --dep=y --keep=const,x1
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--dep` | String | first numeric | Dependent variable column |
| `--method` | String | `bidirectional` | `forward`, `backward`, `bidirectional`, `best-subset`, `gets` |
| `--criterion` | String | `pvalue` | `pvalue`, `aic`, `bic` |
| `--p-enter` | Float64 | 0.05 | p-value to enter a regressor |
| `--p-remove` | Float64 | 0.10 | p-value to remove; must be ≥ `--p-enter` for bidirectional + pvalue |
| `--keep` | String | | Comma-separated regressor names always retained |

**Output:** the selected model's coefficient table, a `step | action | variable |
statistic` **selection path** (the audit trail), and a summary kv with the selected set,
forced-in variables, candidate count and the encompassing F-test where available.

## estimate sur

Seemingly-unrelated regressions (Zellner 1962), fitted by feasible GLS across a multi-equation system. The equation system is specified in a config TOML; each `[[equations]]` block names a dependent column and its regressors (column names from the data CSV). Efficiency gains over equation-by-equation OLS come from cross-equation error correlation.

```bash
friedman estimate sur data.csv --config=system.toml
friedman estimate sur data.csv --config=system.toml --iterate        # iterate FGLS to the MLE
friedman estimate sur data.csv --config=system.toml --no-intercept
```

```toml
[[equations]]
name  = "consumption"       # optional; default eq1, eq2, ...
dep   = "cons"
indep = ["income", "wealth"]

[[equations]]
name  = "investment"
dep   = "inv"
indep = ["income", "interest"]
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--config` | String | (required) | TOML with `[[equations]]` blocks (`dep` + `indep`) |
| `--iterate` | flag | | Iterate FGLS to the Gaussian MLE |
| `--no-intercept` | flag | | Omit the per-equation constant (added by default) |
| `--format` | String | `table` | `table`, `csv`, `json` |
| `--output` | String | | Export file path |

**Output:** a tidy `equation \| term \| estimate \| std_error \| stat \| p_value \| ci_lower \| ci_upper` coefficient table (asymptotic normal inference) + a system-statistics table (equations, obs/eq, det(Σ), McElroy R², log-likelihood, FGLS iterations). SUR/3SLS result types are not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception, like the `io` family).

## estimate 3sls

Three-stage least squares (Zellner & Theil 1962) for a simultaneous system: each equation's regressors are projected onto the instrument space, then a system GLS estimator combines instrumentation with the SUR efficiency gain. Instruments are a common set (`[instruments].common`) or per-equation (`instr` in each `[[equations]]` block, with `--instruments perequation`).

```bash
friedman estimate 3sls data.csv --config=system.toml                       # common instruments
friedman estimate 3sls data.csv --config=system.toml --instruments=perequation
```

```toml
[[equations]]
dep   = "cons"
indep = ["income", "wealth"]

[[equations]]
dep   = "inv"
indep = ["income", "interest"]

[instruments]
common = ["gov", "taxes", "lag_income"]
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--config` | String | (required) | TOML with `[[equations]]` + instruments |
| `--instruments` | String | `common` | `common` (shared set) or `perequation` (each block's `instr`) |
| `--no-intercept` | flag | | Omit the per-equation constant |
| `--format` | String | `table` | `table`, `csv`, `json` |
| `--output` | String | | Export file path |

When the instruments span every regressor, 3SLS collapses to SUR; when every equation is exactly identified it collapses to equation-by-equation 2SLS. **Output:** the same tidy coefficient table as `sur` + a system-statistics table (with instruments-per-equation).

## estimate logit

Logit (logistic regression) for binary choice models.

```bash
friedman estimate logit data.csv --dep=employed --cov-type=hc1
friedman estimate logit data.csv --dep=default --clusters=state --maxiter=200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--tol` | | Float64 | 1e-8 | Convergence tolerance |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC, convergence).

## estimate probit

Probit regression for binary choice models.

```bash
friedman estimate probit data.csv --dep=employed --cov-type=hc1
friedman estimate probit data.csv --dep=default --clusters=state
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--tol` | | Float64 | 1e-8 | Convergence tolerance |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC, convergence).

## Panel Regression Models

### estimate preg

Panel regression with fixed effects (FE), random effects (RE), between effects (BE), or pooled OLS. Supports two-way fixed effects.

```bash
friedman estimate preg panel.csv --dep=gdp --indep=investment,trade --method=fe
friedman estimate preg panel.csv --dep=gdp --indep=investment,trade --method=re --twoway
friedman estimate preg panel.csv --id-col=country --time-col=year --dep=gdp --method=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--method` | | String | `fe` | `fe`, `re`, `be`, `pooled` |
| `--twoway` | | Flag | | Include time fixed effects (two-way FE/RE) |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--cov-type` | | String | `cluster` | `ols`, `hc1`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) with SE, t-stat, p-value; within/between/overall R²; F-statistic.

### estimate piv

Panel IV (2SLS) regression with panel-robust standard errors.

```bash
friedman estimate piv panel.csv --dep=gdp --exog=trade --endog=investment --instruments=lag_inv
friedman estimate piv panel.csv --dep=gdp --endog=investment,credit --instruments=z1,z2,z3 --method=fe
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--exog` | | String | | Comma-separated exogenous regressor names |
| `--endog` | | String | (required) | Comma-separated endogenous regressor names |
| `--instruments` | | String | (required) | Comma-separated instrument column names |
| `--method` | | String | `fe` | `fe`, `re`, `pooled` |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + IV diagnostics (first-stage F-statistic, Sargan test).

### estimate plogit

Panel logit regression (pooled MLE or random effects).

```bash
friedman estimate plogit panel.csv --dep=employed --method=re
friedman estimate plogit panel.csv --dep=default --method=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--method` | | String | `pooled` | `pooled`, `re` |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC).

### estimate pprobit

Panel probit regression (pooled MLE or random effects).

```bash
friedman estimate pprobit panel.csv --dep=employed --method=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--method` | | String | `pooled` | `pooled`, `re` |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC).

## Ordered & Multinomial Choice Models

### estimate ologit

Ordered logit regression for ordered categorical outcomes.

```bash
friedman estimate ologit data.csv --dep=satisfaction
friedman estimate ologit data.csv --dep=rating --cov-type=hc1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (ordered integer) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`block|term|...`, [C051](#coefficient-table-format-c051)) — `block` distinguishes coefficients from cutpoints — plus threshold parameters, pseudo R², log-likelihood, AIC, BIC.

### estimate oprobit

Ordered probit regression for ordered categorical outcomes.

```bash
friedman estimate oprobit data.csv --dep=satisfaction
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (ordered integer) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`block|term|...`, [C051](#coefficient-table-format-c051)) — `block` distinguishes coefficients from cutpoints — plus threshold parameters, pseudo R², log-likelihood, AIC, BIC.

### estimate mlogit

Multinomial logit regression for unordered categorical outcomes.

```bash
friedman estimate mlogit data.csv --dep=choice
friedman estimate mlogit data.csv --dep=mode --base-category=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (categorical integer) |
| `--base-category` | | Int | 1 | Reference category |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** One tidy coefficient table keyed by `alternative` ([C051](#coefficient-table-format-c051)) — every category's coefficients (relative to the base) in a single table — plus pseudo R², log-likelihood, AIC, BIC.
