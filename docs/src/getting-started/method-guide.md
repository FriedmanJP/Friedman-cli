# [Choosing a Method](@id gs-method-guide)

Match your data structure, identification assumptions, and research question to the right `Friedman-cli` verb family and workflow chapter.

## By Data Type

Each estimator family accepts specific container kinds enforced at dispatch (returning `data/wrong-kind`, exit code `3`, on mismatch):

| Data Structure | Handle Kind | Typical Frequency / Dimensions | Primary Chapters |
|---|---|---|---|
| Single macro/financial series | `:timeseries` (`N = 1`) | Monthly, quarterly, daily returns | [Univariate, Filters & Spectral](@ref chap-univariate), [Volatility & Multivariate GARCH](@ref chap-volatility), [Regime-Switching & Nonlinear TS](@ref chap-nonlinear) |
| Multiple aggregate series | `:timeseries` (`N > 1`) | Quarterly/monthly macro blocks; mixed-freq | [VAR, BVAR, VECM & Factor Models](@ref chap-multivariate), [Structural ID, LP & Innovation Accounting](@ref chap-structural), [Nowcasting & Forecast Evaluation](@ref chap-nowcast) |
| Unit-by-time observations | `:panel` | Balanced or unbalanced `(group, time)` | [Panel Data, Panel VAR & Causal DiD](@ref chap-panel) |
| Independent observations | `:cross_section` | Household/firm survey or experimental units | [Regression, Systems & GMM/SMM](@ref chap-regression), [Discrete Choice, Count & Selection](@ref chap-choice) |
| Economic model (no raw data needed for solve) | Model spec (`.jl` / `.toml`) | Structural calibration or Bayesian estimation | [Representative-Agent & Bayesian DSGE](@ref chap-dsge), [Heterogeneous-Agent, CT & OLG Models](@ref chap-hadsge), [Policy Counterfactuals & Optimal Policy](@ref chap-policy) |
| Inter-sector flows / weights | IO / BF `.toml` or `.csv` | Sector × sector intermediate matrix | [Input-Output & Production Networks](@ref chap-io) |

---

## Time Series & Structural Macro

1. **Need trend/cycle decomposition or frequency-domain structure?**
   Start in [Univariate, Filters & Spectral](@ref chap-univariate) (`filter hp|hamilton|bn|bk|bhp|x13`, `spectral acf|periodogram|density|cross|transfer`, `estimate univariate arima|sarima|arfima|ardl|nardl|midas`).
2. **Modeling time-varying volatility or dynamic correlation?**
   Go to [Volatility & Multivariate GARCH](@ref chap-volatility) for ARCH/GARCH/EGARCH/GJR/APARCH/CGARCH/FIGARCH/IGARCH, stochastic volatility (`sv`), GARCH-MIDAS (`garch-midas`), and multivariate GARCH (`ccc`, `dcc`, `bekk`).
3. **Expecting discrete regime switches or smooth threshold nonlinearity?**
   Use [Regime-Switching & Nonlinear TS](@ref chap-nonlinear) (`estimate regime threshold|setar|star|ms-ar|ms`, paired with Hansen/STAR linearity tests).
4. **Forecasting or decomposing multi-variable dynamics?**
   Fit reduced-form VAR, Minnesota/diffuse BVAR, VECM, mixed-frequency VAR, TVP-VAR, FAVAR, or dynamic factor models in [VAR, BVAR, VECM & Factor Models](@ref chap-multivariate).
5. **Recovering structural shocks, IRFs, FEVDs, or historical decompositions?**
   Combine Cholesky, long-run, sign/narrative/Arias/Uhlig, proxy IV, max-share, non-Gaussian ICA, or heteroskedastic/SV identification with LP or VAR/BVAR/VECM/FAVAR/TVP-VAR in [Structural ID, LP & Innovation Accounting](@ref chap-structural).
6. **Nowcasting ragged-edge quarterly GDP from monthly releases or comparing forecasts?**
   Use `nowcast` and `forecast evaluate` in [Nowcasting & Forecast Evaluation](@ref chap-nowcast).

---

## Microeconometrics, Panel & Causal Inference

- **Continuous outcomes, endogeneity, shrinkage, semiparametric, or structural moments:** [Regression, Systems & GMM/SMM](@ref chap-regression) covers OLS, IV/2SLS, quantile, sharp/fuzzy RDD, Ridge/Lasso/Elastic Net, Huber/MM robust, FMOLS/DOLS/CCR cointegrating regression, SUR/3SLS, GMM, SMM, and KDE/LOESS.
- **Discrete, ordered, count, censored, or sample-selected outcomes:** [Discrete Choice, Count & Selection](@ref chap-choice) covers binary/ordered/multinomial logit & probit, Poisson/negative binomial, Tobit, truncated regression, and Heckman two-step/MLE.
- **Longitudinal & difference-in-differences identification:** [Panel Data, Panel VAR & Causal DiD](@ref chap-panel) provides static/dynamic FE/RE/FD/Hausman-Taylor, panel logit/probit/Tobit/PMG, panel VAR (`pvar` + GMM/IRF/FEVD/stability/Andrews-Lu tests), staggered Callaway-Sant'Anna / Sun-Abraham / BJS / Wooldridge / stacked DiD, event studies, HonestDiD sensitivity, and `lp-did`.

---

## Structural Equilibrium, Policy & Networks

- **Representative-agent equilibrium:** [Representative-Agent & Bayesian DSGE](@ref chap-dsge) solves linearized, higher-order pruned, projection, perfect-foresight, and inequality-constrained (`bounds`/`OccBin`) DSGE models and estimates parameters via SMC or Random-Walk Metropolis-Hastings.
- **Distributional & continuous-time equilibrium:** [Heterogeneous-Agent, CT & OLG Models](@ref chap-hadsge) handles sequence-space `HouseholdSystem` models (`hadsge`), Huggett/Aiyagari/Krusell-Smith/HANK (`dsge ct`), OLG (`dsge olg`), discrete-continuous choice (`dsge dcegm|lifecycle`), firm dynamics (`dsge firm`), and banking (`dsge bank`).
- **Counterfactuals & normative central banking:** [Policy Counterfactuals & Optimal Policy](@ref chap-policy) runs zeroing/sequence counterfactuals, policy rules, Ramsey/timeless optimal policy, and commitment vs. discretion comparisons.
- **Sectoral propagation:** [Input-Output & Production Networks](@ref chap-io) computes Leontief/Ghosh multipliers, hypothetical extraction, structural decomposition analysis, and Baqaee-Farhi nonlinear general equilibrium counterfactuals.

---

## Diagnostic Decision Map

Unsure which specification test checks unit roots, cointegration rank, lag misspecification, structural breaks, or DiD pre-trends? Use the master test decision matrix in [Hypothesis Testing & Diagnostics](@ref chap-tests).
