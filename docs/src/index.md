# [Friedman-cli](@id home)

**Friedman-cli** is an action-first command-line interface and MCP server for macroeconomic, time-series, panel, cross-sectional, and structural equilibrium econometrics, backed by [MacroEconometricModels.jl](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/).

Use `verb [family] model` pipelines across CSV files, native typed data/model handles (`.jld2`, `.jls`, `.fmod`), bundled datasets (`:denmark`, `:fred_qd`, `:pwt`, `:mpdta`, and others), and TOML or model-card specifications—emitting human-readable tables, CSV exports, or strict v1 JSON envelopes (`--format json`) for automated agents.

---

## Domain Workflows

Start with [Getting Started](@ref gs-installation), pick the econometric workflow matching your data and identification strategy below, or jump straight to the [CLI Reference Overview](@ref cli-overview).

| Workflow Chapter | Primary Verbs & Families | Core Coverage |
|---|---|---|
| [Data Management & Simulation](@ref chap-data) | `data`, `data simulate` | Builtin datasets, import/export, FRED transforms, balancing, synthetic DGP simulators |
| [Univariate, Filters & Spectral](@ref chap-univariate) | `filter`, `spectral`, `estimate univariate` | HP/Hamilton/BN/BK/BHP/X-13 filters, spectra, ARIMA/SARIMA/ARFIMA/ARDL/NARDL/MIDAS, state-space, TVP |
| [Volatility & Multivariate GARCH](@ref chap-volatility) | `estimate\|forecast\|predict\|residuals volatility` | ARCH, GARCH, EGARCH, GJR, APARCH, CGARCH, IGARCH, FIGARCH/FIEGARCH, SV, GARCH-MIDAS, CCC/DCC/BEKK |
| [Regime-Switching & Nonlinear TS](@ref chap-nonlinear) | `estimate\|forecast\|predict\|residuals regime` | Markov-switching AR & regression, SETAR, STAR, threshold regression, nonlinearity tests |
| [VAR, BVAR, VECM & Factor Models](@ref chap-multivariate) | `estimate multivariate\|factor`, `forecast` | VAR, Bayesian VAR, VECM, MF-VAR, TVP-VAR, FAVAR, conditional scenarios, DFM/GDFM/SDFM |
| [Structural ID, LP & Innovation Accounting](@ref chap-structural) | `estimate multivariate svar\|svec\|lp`, `irf`, `fevd`, `hd` | Cholesky, long-run, sign/narrative/Arias/Uhlig, proxy/max-share/GMM, non-Gaussian ICA, TVV/SV-VAR |
| [Nowcasting & Forecast Evaluation](@ref chap-nowcast) | `nowcast`, `forecast evaluate` | DFM EM / Bayesian nowcasting, bridge equations, news decomposition, DM & Clark-West tests |
| [Regression, Systems & GMM/SMM](@ref chap-regression) | `estimate\|predict\|residuals regression` | OLS/WLS, IV/2SLS, quantile, RDD, Ridge/Lasso/EN, Huber/MM, FMOLS/DOLS, SUR/3SLS, GMM, SMM, KDE |
| [Discrete Choice, Count & Selection](@ref chap-choice) | `estimate\|predict\|residuals choice`, `tobit`, `heckman` | Binary/ordered/multinomial logit & probit, Poisson/NegBin, censored/truncated/selection models |
| [Panel Data, Panel VAR & Causal DiD](@ref chap-panel) | `estimate panel`, `irf\|fevd\|test pvar`, `did` | FE/RE/FD/Hausman-Taylor, panel logit/probit/PMG, PVAR + GMM/FEVD/tests, DiD, event studies, LP-DiD |
| [Representative-Agent & Bayesian DSGE](@ref chap-dsge) | `dsge` (RA & Bayes) | Steady state, 1st/2nd/3rd-order/projection solvers, perfect foresight, constraint/OccBin, SMC/MH Bayes |
| [Heterogeneous-Agent, CT & OLG Models](@ref chap-hadsge) | `hadsge`, `dsge ct\|olg\|dcegm\|lifecycle\|firm\|bank` | Sequence-space HA (`HouseholdSystem`), Krusell-Smith / Hank, HACT continuous-time, OLG, DCEGM, firm/bank |
| [Policy Counterfactuals & Optimal Policy](@ref chap-policy) | `policy` | Policy causal menus, rule counterfactuals, historical simulations, optimal policy projections (OPP), spanning |
| [Input-Output & Production Networks](@ref chap-io) | `io` (`io`, `bf`) | Leontief/Ghosh multipliers, hypothetical extraction, structural decomposition, Baqaee-Farhi nonlinear GE |
| [Hypothesis Testing & Diagnostics](@ref chap-tests) | `test` | Unit root, cointegration, VAR/panel/DiD diagnostics, weak instruments, heteroskedasticity, Andrews break tests |

---

## Quick Start

Install the CLI or run from source (see [Installation & Quickstart](@ref gs-installation)), then chain data import, estimation, structural analysis, and provenance inspection using native `.jld2` handles (detailed in [Pipelines, Handles & Reproducibility](@ref gs-pipelines)):

```bash
# Import a bundled timeseries dataset with date metadata into a typed handle
friedman data import :denmark --vars LRM,LRY,IBO -o macro

# Estimate a VAR(2) under a fixed seed and save the model handle
friedman --seed 42 estimate multivariate var macro --lags 2 --save-model var_fit

# Compute Cholesky impulse responses without re-estimating the VAR
friedman irf var macro --model var_fit.jld2 --horizons 8 --shock 1

# Verify reproducibility and inspect handle provenance
friedman model info var_fit.jld2
friedman model reproduce var_fit.jld2
```

For headless scripts, CI, or LLM tool integration over MCP stdio (`friedman serve --mcp`), see [Pipelines, Handles & Reproducibility](@ref gs-pipelines) and the [Agent Guide](agent-guide.md).

---

## Site Map

```@contents
Pages = [
    "getting-started/installation.md",
    "getting-started/pipelines.md",
    "getting-started/method-guide.md",
    "getting-started/repl.md",
    "agent-guide.md",
    "chapters/data.md",
    "chapters/univariate.md",
    "chapters/volatility.md",
    "chapters/nonlinear.md",
    "chapters/multivariate.md",
    "chapters/structural.md",
    "chapters/nowcast.md",
    "chapters/regression.md",
    "chapters/choice.md",
    "chapters/panel.md",
    "chapters/dsge.md",
    "chapters/hadsge.md",
    "chapters/policy.md",
    "chapters/io.md",
    "chapters/tests.md",
    "config/overview.md",
    "config/identification.md",
    "config/dsge.md",
    "config/models-policy.md",
    "commands/overview.md",
    "internals/architecture.md",
    "internals/api.md",
    "internals/not-wrapped.md",
]
Depth = 2
```
