# Friedman-cli

Macroeconometric analysis from the terminal. A Julia CLI wrapping [MacroEconometricModels.jl](https://github.com/FriedmanJP/MacroEconometricModels.jl).

---

## Features

| Category | Models / Tests | Commands |
|----------|---------------|----------|
| **VAR** | Frequentist VAR, Bayesian VAR (Minnesota prior, MCMC) | `estimate multivariate var`, `estimate multivariate bvar` |
| **VECM** | Vector Error Correction Model (Johansen) | `estimate multivariate vecm` |
| **Panel VAR** | GMM/FE-OLS estimation, OIRF/GIRF | `estimate panel pvar` |
| **Local Projections** | Standard, IV, smooth, state-dependent, propensity score, doubly robust | `estimate multivariate lp` |
| **Factor Models** | Static (PCA), dynamic, generalized dynamic (spectral) | `estimate factor static`, `estimate factor dynamic`, `estimate factor gdfm` |
| **FAVAR** | Factor-Augmented VAR (Bernanke, Boivin & Eliasz 2005) | `estimate multivariate favar`, `irf favar`, `forecast multivariate favar` |
| **Structural DFM** | Structural Dynamic Factor Model (Forni et al. 2009) | `estimate factor sdfm`, `irf sdfm`, `fevd sdfm` |
| **ARIMA** | AR, MA, ARMA, ARIMA with auto order selection | `estimate univariate arima` |
| **Volatility** | ARCH, GARCH, EGARCH, GJR-GARCH, stochastic volatility | `estimate volatility arch`, `estimate volatility garch`, `estimate volatility sv` |
| **Non-Gaussian SVAR** | FastICA, JADE, SOBI, dCov, HSIC, ML (Student-t, mixture, PML, skew-normal) | `estimate factor fastica`, `estimate regression ml` |
| **GMM** | Identity, optimal, two-step, iterated weighting | `estimate regression gmm` |
| **Cross-Sectional** | OLS, WLS, IV (2SLS), Logit, Probit | `estimate regression reg`, `estimate regression iv`, `estimate choice logit`, `estimate choice probit` |
| **ARDL / NARDL** | Single-equation ARDL, nonlinear/asymmetric NARDL, PSS bounds test, symmetry Wald tests, cumulative dynamic multipliers | `estimate univariate ardl`, `estimate univariate nardl`, `test coint ardl-bounds`, `test nardl-symmetry` |
| **Panel ARDL (PMG)** | Dynamic heterogeneous-panel ARDL: Pooled Mean Group / Mean Group / Dynamic Fixed Effects, PMG Hausman selection test | `estimate panel pmg`, `test panel pmg-hausman` |
| **IRF** | Cholesky, sign, narrative, long-run, Arias, Uhlig, non-Gaussian methods | `irf var`, `irf bvar`, `irf lp`, `irf vecm`, `irf pvar` |
| **FEVD** | Frequentist, Bayesian, LP (bias-corrected), VECM, Panel VAR | `fevd var`, `fevd bvar`, `fevd lp`, `fevd vecm`, `fevd pvar` |
| **Historical Decomposition** | Frequentist, Bayesian, LP-based, VECM | `hd var`, `hd bvar`, `hd lp`, `hd vecm` |
| **Forecasting** | VAR, BVAR, LP, ARIMA, factor models, volatility models, VECM | `forecast multivariate var`, `forecast univariate arima`, `forecast factor dynamic` |
| **Predict / Residuals** | In-sample fitted values and model residuals | `predict multivariate var`, `residuals multivariate var` |
| **Filters** | HP, Hamilton, Beveridge-Nelson, Baxter-King, boosted HP | `filter hp`, `filter hamilton`, `filter bk` |
| **Nowcasting** | DFM, BVAR, bridge equations, news decomposition | `nowcast dfm`, `nowcast bvar`, `nowcast bridge`, `nowcast news` |
| **Input-Output** | Leontief/Ghosh multipliers, linkages, SDA, hypothetical extraction, environmental footprints, Baqaee-Farhi | `io leontief`, `io multipliers`, `io footprint`, `io baqaee-farhi` |
| **Data Management** | Typed import/export, example datasets, diagnostics, transformations, validation, balancing | `data import`, `data export`, `data list`, `data load`, `data describe` |
| **DSGE (RA)** | Representative-agent models: solve, estimate, Bayesian estimation, closed families (CT, OLG, DCEGM, bank, firm, lifecycle) | `dsge solve`, `dsge estimate`, `dsge bayes estimate`, `dsge ct solve`, `dsge olg solve` |
| **HA-DSGE** | Heterogeneous-agent models: solve, estimate, simulate, accuracy | `hadsge solve`, `hadsge estimate`, `hadsge simulate`, `hadsge accuracy` |
| **DSGE HD** | Historical decomposition from solved/Bayesian DSGE | `dsge hd`, `dsge bayes hd` |
| **DID** | TWFE, Callaway-Sant'Anna, Sun-Abraham, BJS, dCdH, event study LP, LP-DiD | `did estimate`, `did event-study`, `did lp-did` |
| **DID Diagnostics** | Bacon decomposition, pre-trend test, negative weights, HonestDiD | `test did bacon`, `test did pretrend`, `test did honest` |
| **SMM** | Simulated Method of Moments estimation | `estimate regression smm` |
| **Structural Breaks** | Andrews (1993), Bai-Perron (1998) multiple breaks | `test stability andrews`, `test stability bai-perron` |
| **Panel Unit Root** | PANIC (Bai-Ng), CIPS (Pesaran), Moon-Perron, factor break | `test panel panic`, `test unit-root cips`, `test unit-root moon-perron` |
| **Advanced Unit Root** | Fourier ADF, Fourier KPSS, DF-GLS, LM (0/1/2 breaks), ADF 2-break | `test unit-root fourier-adf`, `test unit-root dfgls`, `test unit-root lm-unitroot` |
| **Cointegration w/ Break** | Gregory-Hansen regime-shift cointegration | `test coint gregory-hansen` |
| **Multicollinearity** | Variance inflation factors | `test vif` |
| **Unit Root Tests** | ADF, KPSS, Phillips-Perron, Zivot-Andrews, Ng-Perron | `test unit-root adf`, `test unit-root kpss`, `test unit-root pp` |
| **Cointegration** | Johansen trace and max eigenvalue | `test coint johansen` |
| **Diagnostics** | Normality, identifiability, ARCH-LM, Ljung-Box, heteroskedasticity | `test normality`, `test serial arch-lm`, `test serial ljung-box` |
| **Model Comparison** | Granger causality, LR test, LM test | `test multivariate granger`, `test multivariate lr`, `test multivariate lm` |
| **Panel Regression** | FE/RE/BE/pooled OLS, panel IV (2SLS), panel logit/probit | `estimate panel preg`, `estimate panel piv`, `estimate panel plogit`, `estimate panel pprobit` |
| **Panel Specification Tests** | Hausman, F-test FE, Pesaran CD, Wooldridge AR, Modified Wald | `test panel hausman`, `test panel pesaran-cd`, `test panel wooldridge-ar` |
| **Ordered & Multinomial** | Ordered logit/probit, multinomial logit | `estimate choice ologit`, `estimate choice oprobit`, `estimate choice mlogit` |
| **Discrete Choice Tests** | Brant parallel regression test, Hausman-McFadden IIA test | `test brant`, `test hausman-iia` |
| **Policy Counterfactuals** | McKay-Wolf causal-effect menus, rule counterfactuals, optimal policy, second moments, Barnichon-Mesters OPP | `policy effects var`, `policy counterfactual var`, `policy optimal var`, `policy moments var`, `policy opp var` |
| **Spectral Analysis** | ACF, periodogram, spectral density, cross-spectrum, transfer function | `spectral acf`, `spectral density`, `spectral periodogram` |
| **Data Utilities** | Drop rows with missing values, keep rows by condition | `data dropna`, `data keeprows` |

Action-first CLI: commands organized by action (`estimate`, `irf`, `forecast`, `did`, `policy`, `dsge`, `hadsge`, `show`, `model`, `completions`, ...) rather than by model type. See the [CLI reference overview](commands/overview.md) for the full command tree.

---

## Quick Start

One shell, top to bottom: the three `simulate` lines create every file the
later lines read, and the `import` line creates the handle the `estimate` line
fits. Later lines depend on earlier ones — run them in order.

```bash
# Install (once) and enter the repo
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e 'using Pkg; Pkg.instantiate()'

# Simulate demo data first — everything below reads these files
julia --project bin/friedman data simulate var --periods 200 --seed 7 --format csv --output demo_var.csv
julia --project bin/friedman data simulate did --n 40 --periods 12 --seed 7 --format csv --output demo_panel.csv
julia --project bin/friedman data simulate cross-section --kind ordered --n 500 --seed 7 --format csv --output demo_choice.csv

# Import CSV to a typed handle (stem, not suffix), then estimate
julia --project bin/friedman data import demo_var.csv --kind timeseries -o demo_macro
julia --project bin/friedman estimate multivariate var demo_macro --lags 2 --save-model demo_var

# CSV shortcut (no handle needed)
julia --project bin/friedman estimate multivariate var demo_var.csv --lags 2

# Impulse responses from the saved model stem, then render the saved result
julia --project bin/friedman irf var --model demo_var --shock 1 --horizons 20 --save-result demo_irf
julia --project bin/friedman show demo_irf

# Forecast 12 steps ahead
julia --project bin/friedman forecast multivariate var demo_var.csv --horizons 12

# Unit root test on the first column
julia --project bin/friedman test unit-root adf demo_var.csv --column 1

# Ordered choice on the simulated ratings
julia --project bin/friedman estimate choice ologit demo_choice.csv --dep y

# Difference-in-differences on the simulated panel (columns: id,time,y,D,cohort)
julia --project bin/friedman did estimate demo_panel.csv --outcome y --treatment D --method cs
julia --project bin/friedman did event-study demo_panel.csv --outcome y --treatment D

# Solve a DSGE model (spec created in-block; solve before irf)
cat > demo_rbc.toml <<'EOF'
[model]
parameters = { rho = 0.9, sigma = 0.01 }
endogenous = ["Y", "C"]
exogenous = ["e"]
linear = true
[[model.equations]]
expr = "Y[t] = rho * Y[t-1] + sigma * e[t]"
[[model.equations]]
expr = "C[t] = Y[t]"
EOF
julia --project bin/friedman dsge solve demo_rbc.toml
julia --project bin/friedman dsge irf demo_rbc.toml --horizon 40
```

All commands support `--format=table|csv|json` and `--output=file.csv` for flexible output.

---

## Contents

```@contents
Pages = [
    "installation.md",
    "agent-guide.md",
    "commands/overview.md",
    "commands/generated/completions.md",
    "commands/generated/data.md",
    "commands/generated/did.md",
    "commands/generated/dsge.md",
    "commands/generated/estimate.md",
    "commands/generated/fevd.md",
    "commands/generated/filter.md",
    "commands/generated/forecast.md",
    "commands/generated/hadsge.md",
    "commands/generated/hd.md",
    "commands/generated/io.md",
    "commands/generated/irf.md",
    "commands/generated/model.md",
    "commands/generated/nowcast.md",
    "commands/generated/policy.md",
    "commands/generated/predict.md",
    "commands/generated/residuals.md",
    "commands/generated/serve.md",
    "commands/generated/show.md",
    "commands/generated/spectral.md",
    "commands/generated/test.md",
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
    "commands/ha-dsge.md",
    "commands/not-wrapped.md",
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
