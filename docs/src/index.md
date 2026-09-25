# Friedman-cli

Macroeconometric analysis from the terminal. A Julia CLI wrapping [MacroEconometricModels.jl](https://github.com/FriedmanJP/MacroEconometricModels.jl).

## Features

| Category | Models / Tests | Commands |
|----------|---------------|----------|
| **VAR** | Frequentist VAR, Bayesian VAR (Minnesota prior, MCMC) | `estimate multivariate var`, `estimate multivariate bvar` |
| **VECM** | Vector Error Correction Model (Johansen) | `estimate multivariate vecm` |
| **Panel VAR** | GMM/FE-OLS estimation, OIRF/GIRF | `estimate panel pvar` |
| **Local Projections** | Standard, IV, Smooth, State-dependent, Propensity score, Doubly robust | `estimate multivariate lp --method=...` |
| **Factor Models** | Static (PCA), Dynamic, Generalized Dynamic (spectral) | `estimate factor static`, `dynamic`, `gdfm` |
| **FAVAR** | Factor-Augmented VAR (Bernanke, Boivin & Eliasz 2005) | `estimate multivariate favar`, `irf favar`, `forecast multivariate favar`, ... |
| **Structural DFM** | Structural Dynamic Factor Model (Forni et al. 2009) | `estimate factor sdfm`, `irf sdfm`, `fevd sdfm` |
| **ARIMA** | AR, MA, ARMA, ARIMA with auto order selection | `estimate univariate arima` |
| **Volatility** | ARCH, GARCH, EGARCH, GJR-GARCH, Stochastic Volatility | `estimate volatility arch`, `garch`, ... |
| **Non-Gaussian SVAR** | FastICA, JADE, SOBI, dCov, HSIC, ML (Student-t, mixture, PML, skew-normal) | `estimate factor fastica`, `estimate regression ml` |
| **GMM** | Identity, optimal, two-step, iterated weighting | `estimate regression gmm` |
| **Cross-Sectional** | OLS, WLS, IV (2SLS), Logit, Probit | `estimate regression reg`, `estimate regression iv`, `estimate choice logit`, `estimate choice probit` |
| **ARDL / NARDL** | Single-equation ARDL, nonlinear/asymmetric NARDL, PSS bounds test, symmetry Wald tests, cumulative dynamic multipliers | `estimate univariate ardl`, `estimate univariate nardl`, `test coint ardl-bounds`, `test nardl-symmetry`, `estimate univariate nardl` |
| **Panel ARDL (PMG)** | Dynamic heterogeneous-panel ARDL: Pooled Mean Group / Mean Group / Dynamic Fixed Effects, PMG Hausman selection test | `estimate panel pmg`, `test panel pmg-hausman` |
| **IRF** | Cholesky, sign, narrative, long-run, Arias, Uhlig, non-Gaussian methods | `irf var`, `irf bvar`, `irf lp`, `irf vecm`, `irf pvar` |
| **FEVD** | Frequentist, Bayesian, LP (bias-corrected), VECM, Panel VAR | `fevd var`, `fevd bvar`, `fevd lp`, `fevd vecm`, `fevd pvar` |
| **Historical Decomposition** | Frequentist, Bayesian, LP-based, VECM | `hd var`, `hd bvar`, `hd lp`, `hd vecm` |
| **Forecasting** | VAR, BVAR, LP, ARIMA, factor models, volatility models, VECM | `forecast multivariate var`, `forecast univariate arima`, ... |
| **Predict / Residuals** | In-sample fitted values and model residuals | `predict multivariate var`, `residuals multivariate var`, ... |
| **Filters** | HP, Hamilton, Beveridge-Nelson, Baxter-King, Boosted HP | `filter hp`, `filter hamilton`, ... |
| **Nowcasting** | DFM, BVAR, bridge equations, news decomposition | `nowcast dfm`, `nowcast bvar`, ... |
| **Input-Output** | Leontief/Ghosh multipliers, linkages, SDA, hypothetical extraction, environmental footprints, Baqaee-Farhi (2019) | `io leontief`, `io multipliers`, `io footprint`, ... |
| **Data Management** | Typed import/export (`.jld2` stems), example datasets, diagnostics, transformations, validation, balancing | `data import`, `data export`, `data list`, `data load`, `data describe`, ... |
| **DSGE** | RA + Bayesian + closed families; one-household HA is `hadsge` | `dsge solve`, `hadsge solve`, `dsge ct`, `dsge olg`, ... |
| **DID** | TWFE, Callaway-Sant'Anna, Sun-Abraham, BJS, dCdH, event study LP, LP-DiD | `did estimate`, `did event-study`, `did lp-did` |
| **DID Diagnostics** | Bacon decomposition, pre-trend test, negative weights, HonestDiD | `test did bacon`, `test did pretrend`, ... |
| **SMM** | Simulated Method of Moments estimation | `estimate regression smm` |
| **Structural Breaks** | Andrews (1993), Bai-Perron (1998) multiple breaks | `test stability andrews`, `test stability bai-perron` |
| **Panel Unit Root** | PANIC (Bai-Ng), CIPS (Pesaran), Moon-Perron, factor break | `test panel panic`, `test unit-root cips`, ... |
| **Advanced Unit Root** | Fourier ADF, Fourier KPSS, DF-GLS, LM (0/1/2 breaks), ADF 2-break | `test unit-root fourier-adf`, `test unit-root dfgls`, `test unit-root lm-unitroot`, ... |
| **Cointegration w/ Break** | Gregory-Hansen regime-shift cointegration | `test coint gregory-hansen` |
| **Multicollinearity** | Variance inflation factors | `test vif` |
| **Unit Root Tests** | ADF, KPSS, Phillips-Perron, Zivot-Andrews, Ng-Perron | `test unit-root adf`, `test unit-root kpss`, ... |
| **Cointegration** | Johansen trace and max eigenvalue | `test coint johansen` |
| **Diagnostics** | Normality, identifiability, ARCH-LM, Ljung-Box, heteroskedasticity | `test normality`, ... |
| **Model Comparison** | Granger causality, LR test, LM test | `test multivariate granger`, `test multivariate lr`, `test multivariate lm` |
| **Panel Regression** | FE/RE/BE/pooled OLS, panel IV (2SLS), panel logit/probit | `estimate panel preg`, `estimate panel piv`, `estimate panel plogit`, `estimate panel pprobit` |
| **Panel Specification Tests** | Hausman, Breusch-Pagan LM, F-test FE, Pesaran CD, Wooldridge AR, Modified Wald | `test panel hausman`, `test serial breusch-pagan`, ... |
| **Ordered & Multinomial** | Ordered logit/probit, multinomial logit | `estimate choice ologit`, `estimate choice oprobit`, `estimate choice mlogit` |
| **Discrete Choice Tests** | Brant parallel regression test, Hausman-McFadden IIA test | `test brant`, `test hausman-iia` |
| **DSGE HD** | Historical decomposition from solved/Bayesian DSGE | `dsge hd`, `dsge bayes hd` |
| **Policy Counterfactuals** | McKay-Wolf causal-effect menus, rule counterfactuals, optimal policy, second moments, Barnichon-Mesters OPP | `policy effects`, `policy counterfactual`, `policy optimal`, `policy moments`, `policy opp`, ... |
| **Spectral Analysis** | ACF/PACF, periodogram, spectral density, cross-spectrum, transfer function | `spectral acf`, `spectral density`, ... |
| **Data Utilities** | Drop rows with missing values, keep rows by condition | `data dropna`, `data keeprows` |

Action-first CLI: commands organized by action (`estimate`, `irf`, `forecast`, `did`, `policy`, `hadsge`, `show`, ...) rather than by model type. See the [CLI reference overview](commands/overview.md) for the full command tree.

## Quick Start

```bash
# Install
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e 'using Pkg; Pkg.instantiate()'

# Import CSV to a typed handle (stem, not suffix), then estimate
julia --project bin/friedman data import data.csv --kind timeseries -o macro
julia --project bin/friedman estimate multivariate var macro --lags=2 --save-model var

# CSV shortcut (unchanged)
julia --project bin/friedman estimate multivariate var data.csv --lags=2

# Compute impulse responses (or from a saved model stem)
julia --project bin/friedman irf var data.csv --shock=1 --horizons=20
julia --project bin/friedman irf var --model var --horizons=20 --save-result irf
julia --project bin/friedman show irf

# Forecast 12 steps ahead
julia --project bin/friedman forecast multivariate var data.csv --horizons=12

# Run unit root test
julia --project bin/friedman test unit-root adf data.csv --column=1

# Nowcast GDP
julia --project bin/friedman nowcast dfm mixed_freq.csv --factors=3

# Solve a DSGE model
julia --project bin/friedman dsge solve rbc.toml

# DSGE impulse responses
julia --project bin/friedman dsge irf rbc.toml --horizon=40

# Difference-in-differences (Callaway-Sant'Anna)
julia --project bin/friedman did estimate panel.csv --outcome=y --treatment=treat --method=cs

# Event study LP
julia --project bin/friedman did event-study panel.csv --outcome=y --treatment=treat

# FAVAR estimation
julia --project bin/friedman estimate multivariate favar macro.csv --key-vars=ffr,cpi --factors=3

# Bayesian DSGE estimation
julia --project bin/friedman dsge bayes estimate rbc.toml --data=macro.csv --params=alpha,beta --priors=priors.toml
```

All commands support `--format=table|csv|json` and `--output=file.csv` for flexible output.

## Contents

```@contents
Pages = [
    "installation.md",
    "commands/overview.md",
    "commands/estimate.md",
    "commands/test.md",
    "commands/irf.md",
    "commands/fevd.md",
    "commands/hd.md",
    "commands/forecast.md",
    "commands/predict_residuals.md",
    "commands/filter.md",
    "commands/data.md",
    "commands/io.md",
    "commands/nowcast.md",
    "commands/dsge.md",
    "commands/did.md",
    "commands/policy.md",
    "commands/favar.md",
    "commands/structural-breaks.md",
    "commands/panel-unit-root.md",
    "commands/spectral.md",
    "commands/panel-regression.md",
    "commands/ordered-multinomial.md",
    "repl.md",
    "configuration.md",
    "api.md",
    "architecture.md",
]
Depth = 2
```
