# test

Statistical tests: unit root (including Fourier, DF-GLS, LM with breaks, ADF 2-break), cointegration (including Gregory-Hansen), diagnostics, identification, model comparison, structural breaks, panel unit root, panel specification, discrete choice, volatility-model diagnostics (Engle-Ng sign bias, Nyblom stability), randomness/nonlinearity (variance-ratio, BDS, Hansen (1996) SETAR linearity), Stock-Yogo weak-instrument diagnostics, panel stationarity (Hadri) and panel cointegration (Pedroni/Kao/Westerlund), ARDL bounds (Pesaran-Shin-Smith) and NARDL symmetry Wald tests, VECM cointegration restriction tests (β/α/weak-exogeneity/known-β/joint), and multicollinearity (VIF). 53 subcommands plus nested `var` (2), `pvar` (4) and `vecm` (5) nodes.

## Unit Root Tests

### test adf

Augmented Dickey-Fuller unit root test. H0: series has a unit root.

```bash
friedman test adf data.csv --column=1 --trend=constant
friedman test adf data.csv --column=2 --max-lags=8 --trend=trend
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--max-lags` | | Int | auto (AIC) | Maximum lag order |
| `--trend` | | String | `constant` | `none`, `constant`, `trend`, `both` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Test statistic, lags, p-value, rejection decision at 5%.

### test kpss

KPSS stationarity test. H0: series is stationary (reversed null compared to ADF).

```bash
friedman test kpss data.csv --column=1 --trend=constant
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--trend` | | String | `constant` | `constant`, `trend` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### test pp

Phillips-Perron unit root test. H0: series has a unit root.

```bash
friedman test pp data.csv --column=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--trend` | | String | `constant` | `none`, `constant`, `trend` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### test za

Zivot-Andrews unit root test with endogenous structural break.

```bash
friedman test za data.csv --column=1 --trend=both --trim=0.15
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--trend` | | String | `both` | `intercept`, `trend`, `both` |
| `--trim` | | Float64 | 0.15 | Trimming proportion |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Test statistic, estimated break date.

### test np

Ng-Perron unit root test (MZa, MZt, MSB, MPT statistics).

```bash
friedman test np data.csv --column=1 --trend=constant
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--trend` | | String | `constant` | `constant`, `trend` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

## Long-Memory (Fractional Integration)

Semiparametric estimators of the fractional integration order `d`. Both test
H₀: d = 0 (no long memory) with a two-sided normal z. `d > 0` indicates long-memory /
fractional integration; the estimator is complementary to `estimate arfima`.

### test gph

Geweke & Porter-Hudak (1983) log-periodogram regression estimator of `d`.

```bash
friedman test gph data.csv --column=1
friedman test gph data.csv --bandwidth=32 --trim=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--bandwidth` | `-m` | Int | ⌊√T⌋ | Number of Fourier frequencies |
| `--trim` | | Int | 0 | Trim the first N frequencies |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** `d` estimate, standard error, z-statistic, p-value (H₀: d = 0),
bandwidth, trim, observations.

### test local-whittle

Robinson (1995) local Whittle semiparametric estimator of `d`.

```bash
friedman test local-whittle data.csv --column=1
friedman test local-whittle data.csv --bandwidth=32
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index |
| `--bandwidth` | `-m` | Int | ⌊√T⌋ | Number of Fourier frequencies |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** `d` estimate, standard error, z-statistic, p-value (H₀: d = 0),
bandwidth, observations, minimized objective R(d̂).

## Randomness & Nonlinearity

### test variance-ratio

Lo-MacKinlay variance-ratio test with the Chow-Denning joint (multiple-horizon) statistic. H0: the series follows a random walk (all variance ratios equal 1). A rejection indicates mean reversion or momentum. Per-horizon rows carry heteroskedasticity-robust `z*` statistics; the headline is the robust Chow-Denning `max|z*|`.

```bash
friedman test variance-ratio data.csv --column=1
friedman test variance-ratio data.csv --horizons=2,5,10,20
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--horizons` | | String | `2,4,8,16` | Comma-separated holding periods q (each ≥ 2) |
| `--method` | | String | `lomackinlay` | Variance-ratio method |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Per-horizon table (`horizon|variance_ratio|z_star|p_value`) + joint Chow-Denning statistic and p-value.

### test bds

BDS test (Brock-Dechert-Scheinkman) for independence / nonlinear dependence in a series (often applied to model residuals). H0: the series is iid. Reported per embedding dimension.

```bash
friedman test bds data.csv --column=1 --max-dim=6 --eps-frac=0.7
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--max-dim` | | Int | 6 | Maximum embedding dimension (tests m = 2..max-dim) |
| `--eps-frac` | | Float | 0.7 | Distance threshold ε as a fraction of the series SD |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Per-dimension table (`embed_dim|statistic|p_value`); the decision uses the smallest p-value across dimensions.

### test hansen-linearity

Hansen (1996) **sup-LM / sup-Wald test of linearity** against a two-regime SETAR threshold alternative, with fixed-regressor-bootstrap p-values. H0 is that the series is linear (`β₁ = β₂`, no threshold); a **low p-value rejects** linearity in favour of a two-regime self-exciting threshold model. Because the threshold `γ` is unidentified under the null (the Davies problem), the distribution is nonstandard and p-values come from Hansen's fixed-regressor bootstrap, not a χ². The handler builds the SETAR design internally by fitting `estimate_setar(y, p, d; linearity=true)` and surfacing its attached test (identical numbers to a standalone build). This is the same test folded into [`estimate setar`](estimate.md#estimate-setar)'s diagnostics, exposed here as a first-class test leaf.

```bash
friedman test hansen-linearity y.csv --column=1 --p=1 --d=1
friedman test hansen-linearity y.csv --p=2 --d=1 --reps=2000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | AR order for the SETAR design (≥ 1) |
| `--d` | | Int | 1 | Delay lag for the threshold variable `q = y[t−d]` (≥ 1) |
| `--trim` | | Float | 0.15 | Trimming fraction for the threshold grid (0 < trim < 0.5) |
| `--reps` | | Int | 1000 | Fixed-regressor bootstrap replications (≥ 1) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a kv block (`sup_lm`, `pvalue_lm`, `sup_wald`, `pvalue_wald`, `gamma_sup`, `reps`, `trim`, `n_grid`) plus a decision line. A too-short series (too few observations for the SETAR design) surfaces as a typed `data/invalid`, never an uncaught internal error.

## Instrumental-Variable Diagnostics

### test weak-instrument

Stock-Yogo weak-instrument diagnostics for a cross-section 2SLS regression. Uses the same data layout as [`estimate iv`](estimate.md#estimate-iv): `--endogenous` names the endogenous regressor(s), `--instruments` names the **excluded** instrument(s), and every other numeric column (besides `--dep`) is an exogenous regressor/instrument (include a `const` column for an intercept). Fits `estimate_iv` and reports the excluded-instrument first-stage F, the Cragg-Donald F (the multi-endogenous statistic), the Kleibergen-Paap robust rk-Wald F, and the Stock-Yogo 10%-maximal-bias critical value.

The verdict compares the Cragg-Donald F (or the first-stage partial F when a single endogenous regressor) against the Stock-Yogo 10% critical value — or, when no critical value is tabulated, the Staiger-Stock rule-of-thumb `--threshold` (default 10). Instruments are flagged **weak** when the statistic falls below that bound.

```bash
friedman test weak-instrument data.csv --dep=wage --endogenous=educ --instruments=father_educ,mother_educ
friedman test weak-instrument data.csv --dep=y --endogenous=x_endog --instruments=z1,z2 --threshold=10
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--endogenous` | | String | (required) | Comma-separated endogenous regressor column names |
| `--instruments` | | String | (required) | Comma-separated **excluded** instrument column names |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--threshold` | | Float | 10.0 | First-stage F rule-of-thumb (used only if no Stock-Yogo critical value) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a diagnostics kv block (`n_endogenous`, `n_excluded_instruments`, `first_stage_f`, `cragg_donald_f`, `kleibergen_paap_f`, `stock_yogo_10pct_cv` or `threshold`, `weak`) plus a decision line (H0: instruments are weak — a large F rejects it).

## Cointegration

### test johansen

Johansen cointegration test with trace and max eigenvalue statistics.

```bash
friedman test johansen data.csv --lags=2 --trend=constant
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order |
| `--trend` | | String | `constant` | `none`, `constant`, `trend` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Trace statistics table, max eigenvalue statistics table, estimated cointegration rank.

### VECM Cointegration Restriction Tests

`test vecm beta | alpha | weak-exog | known-beta | joint` are Johansen likelihood-ratio tests of linear restrictions on the cointegrating structure of a VECM. Each first fits a VECM to the data (same options as `estimate vecm`: `--lags`, `--rank`, `--deterministic`, `--method`, `--significance`) — the fitted cointegrating rank must be **≥ 1** (else `data/no-cointegration`) — then tests the restriction. H0 is that the restriction holds, so a **low p-value rejects** the imposed restriction. Output is a kv block (`LR statistic`, `df`, `p-value`, `rank`, `converged`, restriction description) plus a decision line.

The restriction matrices are supplied via `--config` in a `[vecm_restriction]` TOML section, given **row-major** (an array of equal-length numeric rows). See [Configuration](../configuration.md).

| Leaf | Restriction | Config matrix | df |
|------|-------------|---------------|----|
| `test vecm beta` | β = Hφ (β lies in span(H)) | `H` (p×s, s ≥ r) | r(p−s) |
| `test vecm alpha` | α = Aψ (α lies in span(A)) | `A` (p×a, a ≥ r) | r(p−a) |
| `test vecm known-beta` | β = b (fully specified) | `b` (p×r, exactly r cols) | r(p−r) |
| `test vecm joint` | β = Hφ **and** α = Aψ | both `H` and `A` | r(p−s)+r(p−a) |
| `test vecm weak-exog` | weak exogeneity of `--vars` | — (uses `--vars`, not config) | r·\|vars\| |

```bash
# β restriction (H in the config)
friedman test vecm beta data.csv --config restr.toml --rank=1

# weak exogeneity of the policy rate (by name or index), no config needed
friedman test vecm weak-exog data.csv --vars rate --rank=1
friedman test vecm joint data.csv --config restr.toml
```

Common options (all 5 leaves): `--lags`/`-p` (Int, 2), `--rank`/`-r` (String, `auto`), `--deterministic` (`none`|`constant`|`trend`), `--method` (`johansen`|`engle_granger`), `--significance` (Float64, 0.05), `--format`/`-f`, `--output`/`-o`. The four matrix-based leaves take `--config`; `weak-exog` takes `--vars` (comma-separated indices or names) instead.

## VAR Diagnostics

### test var lagselect

Select optimal lag order for a VAR model.

```bash
friedman test var lagselect data.csv --max-lags=12 --criterion=aic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--max-lags` | | Int | 12 | Maximum lag order to test |
| `--criterion` | | String | `aic` | `aic`, `bic`, `hqc` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Table of AIC/BIC/HQC for each lag order, optimal lag.

### test var stability

Check VAR stationarity via companion matrix eigenvalues.

```bash
friedman test var stability data.csv --lags=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | Lag order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Companion matrix eigenvalues with moduli, stability verdict, max modulus.

## Non-Gaussian SVAR Diagnostics

### test normality

Normality test suite for VAR residuals. Useful as a pre-test for non-Gaussian SVAR methods.

```bash
friedman test normality data.csv --lags=4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Multiple normality test results (statistic, p-value, df), rejection count.

### test identifiability

Test identifiability conditions for non-Gaussian SVAR. Runs up to 5 tests: identification strength, shock Gaussianity, shock independence, overidentification, and Gaussian vs non-Gaussian comparison.

```bash
friedman test identifiability data.csv --test=all
friedman test identifiability data.csv --test=strength
friedman test identifiability data.csv --test=gaussianity --method=jade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--test` | `-t` | String | `all` | `strength`, `gaussianity`, `independence`, `overidentification`, `all` |
| `--method` | | String | `fastica` | `fastica`, `jade`, `sobi`, `dcov`, `hsic` |
| `--contrast` | | String | `logcosh` | `logcosh`, `exp`, `kurtosis` (FastICA only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### test heteroskedasticity

Heteroskedasticity-based SVAR identification. Estimates structural impact matrix B0 using variance changes across regimes.

```bash
friedman test heteroskedasticity data.csv --method=markov --regimes=2
friedman test heteroskedasticity data.csv --method=garch
friedman test heteroskedasticity data.csv --method=smooth_transition --config=config.toml
friedman test heteroskedasticity data.csv --method=external --config=config.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--method` | | String | `markov` | `markov`, `garch`, `smooth_transition`, `external` |
| `--config` | | String | | TOML config (required for `smooth_transition` and `external`) |
| `--regimes` | | Int | 2 | Number of regimes |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Structural impact matrix (B0).

See [Configuration](../configuration.md) for the TOML format specifying transition/regime variables.

## Residual Diagnostics

### test arch\_lm

ARCH-LM test for conditional heteroskedasticity in a series. H0: no ARCH effects.

```bash
friedman test arch_lm data.csv --column=1 --lags=4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--lags` | `-p` | Int | 4 | Number of lags |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### test ljung\_box

Ljung-Box test on squared residuals for serial autocorrelation. H0: no serial correlation in squared residuals.

```bash
friedman test ljung_box data.csv --column=1 --lags=10
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--lags` | `-p` | Int | 10 | Number of lags |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

## Volatility Model Diagnostics

`test sign-bias` and `test nyblom` first fit a univariate volatility model to the chosen return column, then test its standardized residuals / parameters. `--model` selects the volatility model to fit and is restricted to `garch`, `egarch`, `gjr-garch` — the three that share the `(p,q)` estimator signature and are supported by both diagnostics.

### test sign-bias

Engle-Ng (1993) sign-bias and size-bias test for asymmetry left in a fitted volatility model. H0: no remaining asymmetry (a rejection suggests a leverage/asymmetric model such as EGARCH or GJR-GARCH). Reports the sign bias, negative/positive size bias `t`-statistics and the joint χ²(3) test.

```bash
friedman test sign-bias data.csv --column=1 --model=garch
friedman test sign-bias data.csv --model=egarch --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Return series column (1-based) |
| `--model` | | String | `garch` | Volatility model to fit: `garch`, `egarch`, `gjr-garch` |
| `--p` | | Int | 1 | GARCH order p |
| `--q` | | Int | 1 | ARCH order q |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### test nyblom

Nyblom (1989) / Hansen (1992) parameter-stability test against the alternative that parameters follow a martingale. H0: stable parameters. Reports per-parameter individual `Lᵢ` statistics and the joint `L_C` against the Hansen (1992) 5% critical values (a critical-value test — no p-value). Supported for `garch`, `egarch`, `gjr-garch` fits.

```bash
friedman test nyblom data.csv --column=1 --model=garch
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Return series column (1-based) |
| `--model` | | String | `garch` | Volatility model to fit: `garch`, `egarch`, `gjr-garch` |
| `--p` | | Int | 1 | GARCH order p |
| `--q` | | Int | 1 | ARCH order q |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

## Model Comparison Tests

### test granger

Granger causality test for VAR or VECM models.

```bash
friedman test granger data.csv --cause=1 --effect=2 --lags=4
friedman test granger data.csv --cause=1 --effect=2 --model=vecm --rank=1
friedman test granger data.csv --all --lags=4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--cause` | | Int | 1 | Cause variable index (1-based) |
| `--effect` | | Int | 2 | Effect variable index (1-based) |
| `--model` | | String | `var` | `var`, `vecm` |
| `--rank` | `-r` | Int | auto | Cointegration rank (VECM only) |
| `--all` | | Flag | | Test all pairwise Granger causality |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Test statistic, p-value, rejection decision.

### test lr

Likelihood ratio test comparing two nested VAR models estimated from separate datasets.

```bash
friedman test lr restricted.csv unrestricted.csv
friedman test lr data_p2.csv data_p4.csv --lags1=2 --lags2=4
```

| Argument | Description |
|----------|-------------|
| `<data1>` | Path to CSV for restricted model |
| `<data2>` | Path to CSV for unrestricted model |

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags1` | | Int | auto | Lag order for restricted model |
| `--lags2` | | Int | auto | Lag order for unrestricted model |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** LR statistic, degrees of freedom, p-value, rejection decision.

### test lm

Lagrange multiplier test comparing two nested VAR models estimated from separate datasets.

```bash
friedman test lm restricted.csv unrestricted.csv
friedman test lm data_p2.csv data_p4.csv --lags1=2 --lags2=4
```

| Argument | Description |
|----------|-------------|
| `<data1>` | Path to CSV for restricted model |
| `<data2>` | Path to CSV for unrestricted model |

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags1` | | Int | auto | Lag order for restricted model |
| `--lags2` | | Int | auto | Lag order for unrestricted model |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** LM statistic, degrees of freedom, p-value, rejection decision.

## Panel VAR Diagnostics

Nested under `test pvar`. 4 subcommands for Panel VAR model diagnostics.

### test pvar hansen\_j

Hansen's J overidentification test for Panel VAR.

```bash
friedman test pvar hansen_j data.csv --id-col=country --time-col=year --lags=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--id-col` | | String | (required) | Panel group identifier column |
| `--time-col` | | String | (required) | Panel time identifier column |
| `--vars` | | String | | Comma-separated dependent variables |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** J statistic, p-value, degrees of freedom.

### test pvar mmsc

Andrews-Lu MMSC model and moment selection criteria for optimal lag order.

```bash
friedman test pvar mmsc data.csv --id-col=country --time-col=year --max-lags=8
friedman test pvar mmsc data.csv --id-col=country --time-col=year --criterion=bic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--max-lags` | | Int | 8 | Maximum lag order to test |
| `--criterion` | | String | `bic` | `aic`, `bic`, `hqc` |
| `--id-col` | | String | (required) | Panel group identifier column |
| `--time-col` | | String | (required) | Panel time identifier column |
| `--vars` | | String | | Comma-separated dependent variables |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** MMSC criteria table for each lag order, optimal lag.

### test pvar lagselect

Select optimal lag order for a Panel VAR model.

```bash
friedman test pvar lagselect data.csv --id-col=country --time-col=year --max-lags=8
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--max-lags` | | Int | 8 | Maximum lag order to test |
| `--criterion` | | String | `aic` | `aic`, `bic`, `hqc` |
| `--id-col` | | String | (required) | Panel group identifier column |
| `--time-col` | | String | (required) | Panel time identifier column |
| `--vars` | | String | | Comma-separated dependent variables |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Information criteria table for each lag order, optimal lag.

### test pvar stability

Check Panel VAR stationarity via companion matrix eigenvalues.

```bash
friedman test pvar stability data.csv --id-col=country --time-col=year --lags=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--id-col` | | String | (required) | Panel group identifier column |
| `--time-col` | | String | (required) | Panel time identifier column |
| `--vars` | | String | | Comma-separated dependent variables |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Companion matrix eigenvalues with moduli, stability verdict, max modulus.

## Panel Stationarity & Cointegration

`test hadri` tests panel stationarity from a wide matrix (one column per unit); `test pedroni | kao | westerlund` test panel cointegration from a long-format panel (`id`, `time`, and variable columns — like the panel regression / Panel VAR commands). The three cointegration tests share the same `--id-col`/`--time-col`/`--dep`/`--indep` interface and report a `statistic|value|p_value` table (H0: no cointegration; any p-value < 0.05 rejects). `--id-col`/`--time-col` default to the first/second columns; `--dep` defaults to the first variable and `--indep` to the rest.

### test hadri

Hadri (2000) LM test for panel stationarity. H0: all units are (trend-)stationary; a rejection indicates at least one unit has a unit root. Takes a wide numeric matrix (columns = units).

```bash
friedman test hadri panel_wide.csv --deterministic=constant
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--deterministic` | | String | `constant` | `constant` or `trend` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** `statistic`, `p-value`, `n_units`, `observations`.

### test pedroni

Pedroni residual-based panel cointegration test (seven panel/group statistics).

```bash
friedman test pedroni panel.csv --id-col=country --time-col=year --dep=y --indep=x1,x2 --trend=constant
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--id-col` | | String | (1st col) | Panel unit identifier column |
| `--time-col` | | String | (2nd col) | Time period column |
| `--dep` | | String | (1st var) | Dependent variable |
| `--indep` | | String | (rest) | Regressors (comma-separated) |
| `--trend` | | String | `constant` | `constant` or `trend` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### test kao

Kao residual-based panel cointegration test (DF/ADF-type statistics). Same interface as `test pedroni` but without `--trend`.

```bash
friedman test kao panel.csv --dep=y --indep=x
```

### test westerlund

Westerlund error-correction panel cointegration test (Gt/Ga/Pt/Pa statistics). Same interface as `test pedroni`.

```bash
friedman test westerlund panel.csv --dep=y --indep=x --trend=constant
```

## ARDL / NARDL Tests

### test ardl-bounds

**Pesaran-Shin-Smith (2001) bounds test** for the existence of a level (long-run) relationship. Fits a single-equation ARDL (same loader/options as [`estimate ardl`](estimate.md#estimate-ardl)) then computes the joint bounds `F`-statistic (all error-correction level terms zero) and the Dickey-Fuller-type `t`-statistic on the lagged `y` level.

**No p-value.** The null distributions are non-standard functionals of Brownian motion, so the statistics are compared **only** to the tabulated I(0)/I(1) critical-value bounds: above the I(1) upper bound ⇒ `cointegrated`; below the I(0) lower bound ⇒ `not_cointegrated`; in between ⇒ `inconclusive`. The command renders the decision **symbols** plus the bracketing bounds — it never produces a p-value or calls `interpret_test_result`. The `t`-bounds are undefined for cases II and IV (restricted deterministic) and render as `"undefined"` (`t_decision = undefined`).

```bash
friedman test ardl-bounds data.csv --dep=y --p=1 --q=1 --case=3 --level=0.05
friedman test ardl-bounds data.csv --dep=y --p=auto --q=auto --case=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--p` / `--q` | | String | `auto` | ARDL AR / DL orders (`auto`, an integer, or a per-regressor list for `--q`) |
| `--max-p` / `--max-q` | | Int | `4` | Grid bounds for `auto` selection |
| `--ic` | | String | `aic` | `aic`, `bic` |
| `--trend` | | String | `none` | Informational trend label |
| `--case` | | Int | `3` | PSS deterministic case 1..5 |
| `--level` | | Float64 | `0.05` | Decision level: one of `0.10`, `0.05`, `0.025`, `0.01` |
| `--cv-source` | | String | `pss` | Critical-value source (only `pss`; `narayan` finite-sample bounds are not bundled) |
| `--format` / `--output` | `-f`/`-o` | String | | Format / export path |

**Output:** a bounds table (`bound|statistic|i0_lower|i1_upper|decision` — one row each for `F` and `t`; **no `p_value` column**) + a summary (`f_stat`, `t_stat`, `k`, `case`, `cv_source`, `level`, `f_decision`, `t_decision`, `nobs`) and a decision line keyed off the F-bound. `ARDLBoundsTest` is not a CLI-registered test type, so the rendering is hand-built. A bad `--level`/`--case` or `--cv-source narayan` is a usage error (exit 2).

### test nardl-symmetry

Long- and short-run **symmetry Wald tests** for a nonlinear ARDL, one row per asymmetric regressor. Fits a NARDL (same loader/options as [`estimate nardl`](estimate.md#estimate-nardl)) then tests `H₀: θ⁺ = θ⁻` (long-run, a delta-method Wald whose Jacobian carries the `1 − Σφ̂` denominator) and `H₀: Σ_ℓ π⁺_ℓ = Σ_ℓ π⁻_ℓ` (short-run, a linear Wald on the ECM differenced-term coefficients). Each single-restriction statistic is reported as both a `χ²(1)` and an `F(1, n−K)` with the matching p-value — rejecting is evidence of asymmetric adjustment.

```bash
friedman test nardl-symmetry data.csv --dep=y --asymmetric=all --p=1 --q=1
friedman test nardl-symmetry data.csv --dep=y --asymmetric=1,3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--asymmetric` | | String | `all` | `all` or comma-separated 1-based regressor indices to split |
| `--p` / `--q` | | String | `auto` | ARDL AR / DL orders |
| `--max-p` / `--max-q` | | Int | `4` | Grid bounds |
| `--ic` | | String | `aic` | `aic`, `bic` |
| `--case` | | Int | `3` | PSS deterministic case 1..5 |
| `--format` / `--output` | `-f`/`-o` | String | | Format / export path |

**Output:** a tidy multi-row table `regressor|theta_pos|theta_neg|lr_stat|lr_p_chi2|lr_p_f|sr_stat|sr_p_chi2|sr_p_f` + a summary (`df`, `dof_resid`, `n_asym`) and an interpretation of the long-run test on the first regressor. Unlike the bounds test, this test HAS p-values (χ² & F).

### test pmg-hausman

**PMG Hausman selection test** for dynamic heterogeneous panels (Pesaran, Shin & Smith 1999). Fits the same long-format panel **twice** — the estimator efficient under `H₀` (`--efficient=pmg` or `dfe`) and the always-consistent Mean Group — via the same loader/options as [`estimate pmg`](estimate.md#estimate-pmg), then runs the generalized Hausman quadratic form on the common long-run coefficients `θ`. `H₀` is **long-run homogeneity**: failing to reject supports the pooled (PMG) long-run vector; a low p-value favours the unrestricted Mean Group estimator.

```bash
friedman test pmg-hausman panel.csv --id-col=id --time-col=time --dep=y --indep=x1,x2
friedman test pmg-hausman panel.csv --dep=y --indep=x1,x2 --efficient=dfe
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--id-col` | | String | (1st column) | Panel group id column |
| `--time-col` | | String | (2nd column) | Panel time column |
| `--dep` | | String | (1st variable) | Dependent panel variable |
| `--indep` | | String | (all others) | Long-run regressors, comma-separated |
| `--efficient` | | String | `pmg` | Estimator efficient under `H₀`: `pmg`, `dfe` (consistent is always MG) |
| `--trend` | | String | `constant` | Per-unit EC deterministics: `none`, `constant`, `trend` |
| `--p` / `--q` | | Int | `1` / `1` | ARDL AR / DL orders |
| `--maxiter` | | Int | `100` | PMG outer-loop max iterations |
| `--tol` | | Float64 | `1e-8` | PMG outer-loop convergence tolerance |
| `--format` / `--output` | `-f`/`-o` | String | | Format / export path |

**Output:** a standard test summary (`test_name`, `statistic`, `pvalue`, `df`, `description`) with an interpretation line. Unlike [`test ardl-bounds`](#test-ardl-bounds), this test HAS a p-value.

## Advanced Unit Root Tests

### test fourier-adf

Fourier ADF unit root test allowing for smooth structural breaks via Fourier frequencies (Enders & Lee 2012).

```bash
friedman test fourier-adf data.csv --column=1 --regression=constant --fmax=3
friedman test fourier-adf data.csv --column=2 --lags=aic --trim=0.15
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--regression` | | String | `constant` | `constant`, `trend` |
| `--fmax` | | Int | 3 | Maximum Fourier frequency |
| `--lags` | | String | `aic` | Lag order or `aic`/`bic` for auto |
| `--max-lags` | | Int | auto | Maximum lag order |
| `--trim` | | Float64 | 0.15 | Trimming proportion |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Test statistic, p-value, optimal frequency, Fourier F-test.

### test fourier-kpss

Fourier KPSS stationarity test with smooth breaks (Becker, Enders & Lee 2006).

```bash
friedman test fourier-kpss data.csv --column=1 --regression=constant --fmax=3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--regression` | | String | `constant` | `constant`, `trend` |
| `--fmax` | | Int | 3 | Maximum Fourier frequency |
| `--bandwidth` | | Int | auto | Bandwidth parameter |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Test statistic, p-value, optimal frequency, bandwidth, Fourier F-test.

### test dfgls

Elliott-Rothenberg-Stock DF-GLS unit root test with GLS detrending.

```bash
friedman test dfgls data.csv --column=1 --regression=constant
friedman test dfgls data.csv --column=1 --lags=aic --max-lags=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--regression` | | String | `constant` | `constant`, `trend` |
| `--lags` | | String | `aic` | Lag order or `aic`/`bic` for auto |
| `--max-lags` | | Int | auto | Maximum lag order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** DF-GLS tau statistic, PT statistic, p-value, M-GLS statistics.

### test lm-unitroot

LM unit root test with 0, 1, or 2 endogenous structural breaks (Lee & Strazicich 2003, 2013).

```bash
friedman test lm-unitroot data.csv --column=1 --breaks=0
friedman test lm-unitroot data.csv --column=1 --breaks=1 --regression=level --trim=0.15
friedman test lm-unitroot data.csv --column=1 --breaks=2 --lags=aic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--breaks` | | Int | 0 | Number of structural breaks (0, 1, or 2) |
| `--regression` | | String | `level` | `level`, `trend` |
| `--lags` | | String | `aic` | Lag order or `aic`/`bic` for auto |
| `--max-lags` | | Int | auto | Maximum lag order |
| `--trim` | | Float64 | 0.15 | Trimming proportion |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** LM statistic, p-value, break indices and fractions (when breaks > 0).

### test adf-2break

ADF unit root test with two endogenous structural breaks.

```bash
friedman test adf-2break data.csv --column=1 --model=level
friedman test adf-2break data.csv --column=1 --model=trend --trim=0.10
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--model` | | String | `level` | `level`, `trend`, `both` |
| `--lags` | | String | `aic` | Lag order or `aic`/`bic` for auto |
| `--max-lags` | | Int | auto | Maximum lag order |
| `--trim` | | Float64 | 0.10 | Trimming proportion |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Test statistic, p-value, two estimated break dates with fractions.

### test gregory-hansen

Gregory-Hansen cointegration test with regime shift (Gregory & Hansen 1996). Tests for cointegration in the presence of a structural break.

```bash
friedman test gregory-hansen data.csv --model=C
friedman test gregory-hansen data.csv --model=C_T --lags=aic --trim=0.15
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--model` | | String | `C` | `C` (level shift), `C_T` (trend shift), `C_S` (regime shift) |
| `--lags` | | String | `aic` | Lag order or `aic`/`bic` for auto |
| `--max-lags` | | Int | auto | Maximum lag order |
| `--trim` | | Float64 | 0.15 | Trimming proportion |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** ADF\*, Zt\*, Za\* statistics with p-values and estimated break indices.

## Multicollinearity Diagnostics

### test vif

Variance Inflation Factors for detecting multicollinearity. Internally estimates OLS regression, then computes VIF per regressor.

```bash
friedman test vif data.csv --dep=wage
friedman test vif data.csv --dep=wage --cov-type=hc1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--cov-type` | | String | `hc1` | Covariance type for internal OLS |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Per-regressor VIF and tolerance values, with colored warnings (VIF > 5 moderate, VIF > 10 severe).

## Panel Specification Tests

### test hausman

Hausman specification test for fixed effects vs random effects in panel models.

```bash
friedman test hausman panel.csv --dep=gdp --indep=investment,trade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Hausman statistic, degrees of freedom, p-value, recommendation (FE or RE).

### test breusch-pagan

Breusch-Pagan LM test for random effects. H0: no random effects (pooled OLS is appropriate).

```bash
friedman test breusch-pagan panel.csv --dep=gdp --indep=investment,trade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** LM statistic, p-value, rejection decision.

### test f-fe

F-test for the joint significance of individual fixed effects. H0: all individual effects are zero.

```bash
friedman test f-fe panel.csv --dep=gdp --indep=investment,trade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** F-statistic, numerator/denominator df, p-value.

### test pesaran-cd

Pesaran CD test for cross-sectional dependence in panel data. H0: cross-sectional independence.

```bash
friedman test pesaran-cd panel.csv --dep=gdp --indep=investment,trade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** CD statistic, p-value, rejection decision.

### test wooldridge-ar

Wooldridge test for first-order serial correlation in panel data. H0: no serial correlation.

```bash
friedman test wooldridge-ar panel.csv --dep=gdp --indep=investment,trade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** F-statistic, p-value, rejection decision.

### test modified-wald

Modified Wald test for groupwise heteroskedasticity in FE panel models. H0: homoskedastic errors.

```bash
friedman test modified-wald panel.csv --dep=gdp --indep=investment,trade
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Wald statistic, degrees of freedom, p-value.

## Discrete Choice Tests

### test brant

Brant test for the parallel regression (proportional odds) assumption in ordered logit models. H0: proportional odds hold.

```bash
friedman test brant data.csv --dep=satisfaction
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (ordered integer) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Overall and per-variable Brant statistics with p-values; rejection indicates violation of the parallel regression assumption.

### test hausman-iia

Hausman-McFadden IIA (Independence of Irrelevant Alternatives) test for multinomial logit. H0: IIA holds for the omitted category.

```bash
friedman test hausman-iia data.csv --dep=choice --omit-category=3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (categorical integer) |
| `--omit-category` | | Int | (last) | Category to omit when testing IIA |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Hausman chi-squared statistic, degrees of freedom, p-value; rejection suggests IIA violation.

## See Also

For structural break tests (`test andrews`, `test bai-perron`), see [Structural Breaks](structural-breaks.md). For panel unit root tests (`test panic`, `test cips`, `test moon-perron`, `test factor-break`), see [Panel Unit Root](panel-unit-root.md). For panel regression specification tests, see [Panel Regression](panel-regression.md). For ordered/multinomial tests, see [Ordered & Multinomial](ordered-multinomial.md).
