# Friedman-cli (`frdc`)

[![CI](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/CI.yml/badge.svg)](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/FriedmanJP/Friedman-cli/graph/badge.svg)](https://app.codecov.io/gh/FriedmanJP/Friedman-cli)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://api.friedman.jp/Friedman-cli/stable/)

`frdc` (**v1.2.0**) is a command-line interface for [MacroEconometricModels.jl](https://github.com/FriedmanJP/MacroEconometricModels.jl) (pinned to `=1.1.2` in [Project.toml](Project.toml)). It wraps the package's estimation, testing, structural identification, forecasting, and equilibrium-solving routines as standalone shell commands that read CSV files or saved `.jld2`/`.jls` handles and write formatted tables, CSV, JSON, or self-contained HTML plots.

Full documentation and the generated command reference live at [api.friedman.jp/Friedman-cli/stable/](https://api.friedman.jp/Friedman-cli/stable/).

## Installation

Pre-built Linux and Windows distributions include a private Julia runtime, so you do not need a separate Julia installation or network access at runtime. Constrained nonlinear problems default to `MadNLP` and `NLPModels`, which ship inside the bundle under GPL-3.0-compatible terms; `Ipopt` and `PATHSolver` remain optional weak dependencies when running from source.

### Windows (x86_64)

The Microsoft Store package is signed by Microsoft, places `frdc` on `PATH` through an `AppExecutionAlias`, and receives updates automatically:

```powershell
winget install 9NBBQSNP6W44 --source msstore
```

If you prefer GitHub Releases (either sideloading the `.msix` or extracting the `.zip` archive into `%USERPROFILE%\.frdc`), run:

```powershell
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

### Linux (x86_64)

The install script downloads the standalone `.tar.gz` bundle into `~/.frdc/` and links `~/.local/bin/frdc`:

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
```

### macOS and source installs

Pre-built macOS binaries are not distributed at present because notarized builds require an Apple Developer certificate. On macOS, or anywhere you already have Julia 1.13 or newer, clone the repository and run from source:

```bash
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project bin/frdc --help
```

Manual archive downloads, MSIX sideloading, local standalone builds (`build_release.jl`), and notes on moving from the older `friedman` binary name to `frdc` are covered in the [installation guide](https://api.friedman.jp/Friedman-cli/stable/getting-started/installation/).

## Quick start

### VAR estimation and impulse responses

Estimate a two-lag VAR from a CSV file:

```bash
frdc estimate multivariate var macro.csv --lags 2
```

```text
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

  y1             5   0.9948   0.3616    0.3484   27.335
  y2             5   1.1199   0.2649    0.2497   17.387

                                   Equation: y1

                  Coef.   Std.Err.         t    P>|t|   CI lower   CI upper

  (Intercept)   -0.0739     0.0743   -0.9938   0.3216    -0.2205     0.0727
  y1.L1          0.4647     0.0792    5.8677   <0.001     0.3085     0.6209   ***
  y2.L1          0.0977     0.0707    1.3818   0.1686    -0.0418     0.2372
  y1.L2          0.0762     0.0794    0.9605    0.338    -0.0803     0.2327
  y2.L2          0.0248     0.0705    0.3521   0.7251    -0.1143     0.1640
```

Compute impulse responses and write an interactive HTML figure:

```bash
frdc irf var macro.csv --shock 1 --horizons 8 --plot-save irf.html
```

```text
Impulse Response Functions

  Variables           2
  Shocks              2
  Horizon             8
  CI          bootstrap

             Shock: y1

           h=1       h=4       h=8

  y1   1.0065*   0.2150*   0.0319*
  y2   0.5209*   0.1859*   0.0282*
```

An asterisk indicates that the bootstrap band excludes zero. There is no separate plotting subcommand; commands whose upstream return type supports plotting accept `--plot` and `--plot-save`.

### Solving a DSGE model

Model specifications can be written in TOML and passed directly to `dsge`:

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

frdc dsge solve rbc.toml
```

```text
  Determinacy: unique
  Stability: stable
                 Determinacy Verdict
┌────────────┬──────────────────────────────────────┐
│   metric   │                value                 │
│   String   │                 Any                  │
├────────────┼──────────────────────────────────────┤
│ existence  │                  1                   │
│ uniqueness │                  1                   │
│  verdict   │ determinate (unique stable solution) │
│   solver   │                gensys                │
└────────────┴──────────────────────────────────────┘
 DSGE Solution (method=gensys)
┌──────────┬─────────┬─────────┐
│ variable │  G1_Y   │  G1_C   │
│  String  │ Float64 │ Float64 │
├──────────┼─────────┼─────────┤
│    Y     │   0.9   │  -0.0   │
│    C     │   0.9   │  -0.0   │
└──────────┴─────────┴─────────┘
```

The same command structure extends to `dsge irf`, `dsge estimate`, `dsge bayes estimate`, canonical ABCD invertibility (`dsge abcd`), Bayesian DSGE-VAR (`dsge var`), OccBin occasionally binding constraints, and heterogeneous-agent models (`hadsge solve ha_huggett.jl`).

## Scope

Commands are grouped by action (`estimate`, `test`, `irf`, `fevd`, `hd`, `forecast`, `predict`, `residuals`, `dsge`, `hadsge`, `did`, `policy`, `ri`, `io`, `filter`, `spectral`, `nowcast`, `data`, `model`) rather than by individual estimator. See the [command overview](https://api.friedman.jp/Friedman-cli/stable/commands/overview/) for the full tree.

| Area | Examples | Guide |
|---|---|---|
| Time series and factors | VAR, BVAR, VECM, local projections, FAVAR, quantile factors/VAR/FAVAR and Growth-at-Risk (`qfm`, `qvar`, `qfavar`), DFM/GDFM/FHLZ/I(1)/TV-GDFM, ARIMA, ARDL, MIDAS, SETAR/STAR/Markov switching | [Multivariate](https://api.friedman.jp/Friedman-cli/stable/chapters/multivariate/), [Nonlinear](https://api.friedman.jp/Friedman-cli/stable/chapters/nonlinear/) |
| Volatility | ARCH, GARCH, EGARCH, GJR-GARCH, stochastic volatility, CCC, DCC, BEKK | [Volatility](https://api.friedman.jp/Friedman-cli/stable/chapters/volatility/) |
| Micro and panel data | OLS, IV, quantile regression, discrete choice (including RI-logit), panel regression, interactive-factor panel quantile (`xtqreg`), panel VAR, DiD (TWFE, Callaway-Sant'Anna, event studies, HonestDiD) | [Regression](https://api.friedman.jp/Friedman-cli/stable/chapters/regression/), [Panel](https://api.friedman.jp/Friedman-cli/stable/chapters/panel/) |
| Equilibrium and rational inattention | Perturbation, projection, VFI, OccBin, canonical ABCD invertibility, Bayesian DSGE and DSGE-VAR, HANK/Huggett/OLG (`hadsge`), LQG / Maćkowiak-Wiederholt / Matějka-McKay rational inattention (`ri`) | [DSGE](https://api.friedman.jp/Friedman-cli/stable/chapters/dsge/), [HADSGE](https://api.friedman.jp/Friedman-cli/stable/chapters/hadsge/), [Rational Inattention](https://api.friedman.jp/Friedman-cli/stable/chapters/rational-inattention/) |
| Identification and diagnostics | Cholesky, sign, narrative, long-run, Arias, Uhlig, LMS-SVAR, Lanne-Luoto GMM, SSVARMA, ICA, spectral FEVD, unit-root, cointegration, factor-rank, SVAR hypothesis, break, Granger, and weak-instrument tests | [Structural](https://api.friedman.jp/Friedman-cli/stable/chapters/structural/), [Tests](https://api.friedman.jp/Friedman-cli/stable/chapters/tests/) |
| Policy and input-output | Causal-effect menus, optimal policy, behavioral RI policy news, counterfactuals, Leontief and Ghosh multipliers, structural decomposition, Baqaee-Farhi | [Policy](https://api.friedman.jp/Friedman-cli/stable/chapters/policy/), [Input-Output](https://api.friedman.jp/Friedman-cli/stable/chapters/io/) |

Data utilities (`data describe`, `diagnose`, `transform`, `validate`, `simulate`), filters (`filter hp`, `hamilton`, `bk`, `eurocoin`), spectral tools, nowcasting, and an interactive shell (`frdc repl`) follow the same conventions.

## Data, handles, and reproducibility

Fitted models, datasets, and post-estimation objects can be saved to `.jld2` or `.jls` handles and passed into downstream commands without re-estimating:

```bash
frdc estimate multivariate var macro.csv --lags 2 --seed 42 --save-model var
frdc irf var --model var --shock 1 --horizons 8
frdc model reproduce var
```

Passing `--seed N` fixes the random seed for samplers and simulators. With `--format json` (or `-J`/`--json`), every response includes a `meta.manifest` record containing the seed, thread count, OS, CLI version, and package versions. Output format is controlled with `--format table|csv|json` (`-f`) and `--output <path>` (`-o`). Human `--format table` output displays 3 decimal places by default (configurable via `--digits <0..16|full>` or `FRDC_DIGITS`), while `--format json`, `--format csv`, MCP payloads, and `.jld2`/`.jls` handles always store exact unrounded IEEE-754 floats. Confidence and credible intervals default to **68%** (`-L`/`--conf-level 0.68`, `-Q`/`--quantiles 0.16,0.5,0.84`) for macroeconometric leaves (including `did lp-did`) and **90%** for microeconometric leaves, while hypothesis-test significance levels remain 5%. Coexisting short abbreviations (`frdc est mv var :denmark -p 2 -J`, `frdc fc uv arima`, `frdc t ur adf`, `frdc d desc`, `-M`/`-R`/`-S`/`-W`) dispatch identically to canonical names and always emit canonical `command` strings in JSON envelopes. Progress messages go to stderr and results go to stdout, so stdout can be redirected or piped without stripping log lines.

See the [pipelines and handles guide](https://api.friedman.jp/Friedman-cli/stable/getting-started/pipelines/) for multi-key handle addressing, session URIs (`data://`, `model://`, `result://`), and `model info`/`reproduce`.

## Scripting and MCP

For automated workflows and tool-calling agents, `--format json` emits a single schema-versioned JSON object on stdout with declared table keys and structured errors (`error.code`, `error.exit_code`). Exit codes distinguish error classes: `0` success, `2` usage, `3` data, `4` config, `5` model, `6` environment, and `1` internal error.

Programmatic callers can inspect command interfaces without parsing help text:

- `frdc schema <command...>` prints a JSON Schema (draft-07) description of the command's inputs and declared output table keys.
- `frdc serve --mcp` runs a Model Context Protocol server over stdio (supporting `--families`, `--tools`, and `--compact` to narrow the exposed tool list).

In standalone builds, a small C wrapper (`FRDCACHE` v2) handles `--version`, `--help` (including aliased paths), `schema`, `completions`, and MCP discovery (`initialize` with concise agent instructions, `ping`, strictly scoped `tools/list`) directly from a pre-built metadata cache in a few milliseconds, spawning `frdc-core` only when a command or MCP `tools/call` needs the Julia runtime. Setting `FRDC_NO_FASTPATH=1` bypasses the wrapper. For multi-step sessions, keeping a single `frdc repl` or `frdc serve --mcp` process open avoids repeated startup costs and allows in-memory handle reuse. Further details are in the [Agent Guide](https://api.friedman.jp/Friedman-cli/stable/agent-guide/).

## License

Friedman-cli is distributed under the GNU General Public License, version 3 (`GPL-3.0-only`). See [LICENSE](LICENSE), [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md), [DATA_LICENSES.md](DATA_LICENSES.md), and [SOURCE_OFFER.txt](SOURCE_OFFER.txt).
