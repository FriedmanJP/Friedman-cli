# friedman — macroeconometrics from the terminal

[![CI](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/CI.yml/badge.svg)](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/CI.yml)
[![Documentation](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/Documentation.yml/badge.svg)](https://friedmanjp.github.io/Friedman-cli/dev/)

Estimate, test, and simulate macro models without leaving the shell.
`friedman` wraps [MacroEconometricModels.jl](https://github.com/FriedmanJP/MacroEconometricModels.jl)
(exact pin in `Project.toml`) as action-first commands —
`estimate`, `test`, `irf`, `fevd`, `forecast`, `dsge`, `hadsge`, `did`, `policy`, … —
that read CSV, print tables, and reproduce bit-for-bit.

Built for applied economists and researchers who live in the terminal;
equally callable from scripts and AI agents (see [For agents](#for-agents)).

## 60 seconds: VAR end-to-end

```bash
friedman estimate multivariate var macro.csv --lags 2
```

```
Estimating VAR(2) with 2 variables: y1, y2
Trend: constant, Observations: 200

  Vector Autoregression — VAR(2)

  Specification

  Variables                    2
  Lags                         2
  Observations (effective)   198
  Parameters per equation      5

                    Equation Summary

  Equation   Parms     RMSE       R²   Adj. R²   F-stat

  y1             5   1.0858   0.3983    0.3858   31.934
  y2             5   0.9642   0.2393    0.2235   15.177

                                  Equation: y1

                 Coef.   Std.Err.        t    P>|t|   CI lower   CI upper

  (Intercept)   0.0213     0.0774   0.2747   0.7839    -0.1314     0.1739
  y1.L1         0.5456     0.0717   7.6090   <0.001     0.4042     0.6870   ***
  y2.L1         0.1404     0.0807   1.7400   0.0835    -0.0187     0.2996   *
  y1.L2         0.0523     0.0722   0.7247   0.4695    -0.0901     0.1947
  y2.L2         0.0198     0.0807   0.2456   0.8062    -0.1393     0.1790
```

Impulse responses, with bootstrap bands and a plot you can send to a coauthor:

```bash
friedman irf var macro.csv --shock 1 --horizons 8 --plot-save irf.html
```

```
Impulse Response Functions

  Variables           2
  Shocks              2
  Horizon             8
  CI          bootstrap

             Shock: y1

           h=1       h=4      h=8

  y1   1.0398*   0.2874*   0.0303
  y2    0.1345   0.1818*   0.0679
```

(`*` = band excludes zero. `irf.html` is a self-contained interactive chart —
no separate `plot` command; any plot-capable leaf takes `--plot` / `--plot-save`.)

## …and equilibrium: DSGE in four lines

```bash
cat > rbc.toml <<'EOF'
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
friedman dsge solve rbc.toml
```

```
  Determinacy: unique
  Stability: stable
 DSGE Solution (method=gensys)
┌──────────┬─────────┬─────────┐
│ variable │  G1_Y   │  G1_C   │
│  String  │ Float64 │ Float64 │
├──────────┼─────────┼─────────┤
│    Y     │   0.9   │  -0.0   │
│    C     │   0.9   │  -0.0   │
└──────────┴─────────┴─────────┘
```

From here: `dsge irf`, `dsge estimate`, full Bayesian workflow
(`dsge bayes estimate`), heterogeneous-agent models (`hadsge solve huggett`),
OccBin constraints for the ZLB — same verbs, same tables.

## What you can do

Commands are organized by **action**, not model type — learn `estimate` once,
apply it everywhere. (Full tree: [CLI reference overview](https://friedmanjp.github.io/Friedman-cli/dev/commands/overview/).)

- **Time series** — VAR/BVAR, VECM, local projections (incl. IV/smooth/state-dependent),
  FAVAR, structural DFM, ARIMA/ARDL/MIDAS, regime switching (SETAR/STAR/MS):
  `estimate multivariate var`, `irf lp`, `forecast`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/commands/estimate/)
- **Volatility** — ARCH/GARCH/EGARCH/GJR, stochastic volatility, CCC/DCC/BEKK:
  `estimate volatility garch`, `forecast volatility garch`
- **Micro & panels** — OLS/IV/choice models, panel regression, DiD suite
  (TWFE, Callaway-Sant'Anna, event studies, HonestDiD):
  `estimate choice logit`, `did estimate`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/commands/did/)
- **Equilibrium** — RA/HA/OLG models, perturbation/projection/VFI, Bayesian estimation:
  `dsge solve`, `hadsge solve huggett`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/commands/dsge/)
- **Identification & diagnostics** — Cholesky/sign/narrative/long-run/Arias/Uhlig,
  unit-root and cointegration batteries, breaks, Granger, weak instruments:
  `irf var --id sign --config sign.toml`, `test unit-root adf`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/commands/test/)
- **Policy & IO** — causal-effect menus, optimal policy, counterfactuals,
  Leontief/Ghosh multipliers, SDA, Baqaee-Farhi:
  `policy effects var`, `io multipliers`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/commands/policy/)

Data handling (`data describe/diagnose/transform/validate`), filters
(`filter hp/hamilton/bk`), spectral analysis, nowcasting, and an interactive
REPL (`friedman repl`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/repl/))
round it out.

## Reproducibility is the point

- **Same command, same numbers.** `--seed N` is forwarded to samplers/simulators
  and every `--format json` envelope carries a manifest (seed, threads, OS,
  package versions) under `meta.manifest`.
- **No session state.** Save a fit, reuse it without re-estimating:
  `estimate multivariate var macro.csv --save-model var` →
  `irf var --model var` → `model reproduce var` to verify against a fresh run.
- **Scriptable output.** Every leaf speaks `--format table|csv|json`
  and `--output <path>`; status goes to stderr, data to stdout — pipes compose.

## For agents

If you are wiring an LLM to economic analysis: with `--format json`, stdout is
exactly one versioned JSON envelope with stable, registry-declared table keys;
exit codes are `0 ok · 2 usage · 3 data · 4 config · 5 model · 6 env · 1 internal`,
and every JSON failure carries a matching `error.code`/`error.exit_code`.
`friedman schema <path…>` returns a draft-07 input schema plus result-table keys
for any command; `serve --mcp` exposes every command as a Model Context Protocol
tool over stdio. Start at the [Agent Guide](https://friedmanjp.github.io/Friedman-cli/dev/agent-guide/).

## Installation

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

Installs to `~/.friedman-cli/` on macOS ARM64, Linux x86_64, and Windows x86_64
(Julia managed via [juliaup](https://github.com/JuliaLang/juliaup);
solvers JuMP+Ipopt ship bundled). From source:
`git clone … && julia --project -e 'using Pkg; Pkg.instantiate()'`.
Details: [Installation docs](https://friedmanjp.github.io/Friedman-cli/dev/installation/).

## License

GPL-3.0-or-later. Full command reference:
[docs](https://friedmanjp.github.io/Friedman-cli/dev/).
