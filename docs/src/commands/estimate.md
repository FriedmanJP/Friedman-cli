# estimate

Estimate econometric models. 50 subcommands covering VAR, BVAR, VECM, Panel VAR, FAVAR, Structural DFM, systems estimation (SUR/3SLS), cross-sectional regression (OLS/WLS/IV/Logit/Probit), penalized regression (Lasso/Ridge/Elastic-Net), robust (Huber/bisquare M/MM), Tobit censored, truncated-normal and Heckman sample-selection regression, panel regression (FE/RE/IV/Logit/Probit), ordered and multinomial choice models, local projections, ARIMA, ARFIMA long memory, GMM, SMM, factor models, univariate volatility models (ARCH/GARCH/EGARCH/GJR-GARCH/SV plus IGARCH/Component-GARCH/APARCH/FIGARCH/FIEGARCH/GARCH-MIDAS), multivariate GARCH (CCC/DCC/BEKK), and non-Gaussian SVAR identification.

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
