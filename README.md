# Friedman-cli : macroeconometrics from the terminal

[![CI](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/CI.yml/badge.svg)](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/CI.yml)
[![Documentation](https://github.com/FriedmanJP/Friedman-cli/actions/workflows/Documentation.yml/badge.svg)](https://friedmanjp.github.io/Friedman-cli/dev/)

Estimate, test, and simulate macro models without leaving the shell.
`frdc` v1.1.0 wraps [MacroEconometricModels.jl](https://github.com/FriedmanJP/MacroEconometricModels.jl)
(`=1.1.1`, exact pin in `Project.toml`) as action-first commands —
`estimate`, `test`, `irf`, `fevd`, `forecast`, `dsge`, `hadsge`, `did`, `policy`, `ri`, … —
that read CSV or `.jld2`/`.jls` handles, print tables, generate interactive plots across 278 plot-capable types, and reproduce bit-for-bit.

Built for applied economists and researchers who live in the terminal;
equally callable from scripts and AI agents (see [For agents](#for-agents)).

## 60 seconds: VAR end-to-end

```bash
frdc estimate multivariate var macro.csv --lags 2
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

Impulse responses, with bootstrap bands and a plot:

```bash
frdc irf var macro.csv --shock 1 --horizons 8 --plot-save irf.html
```

```
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
frdc dsge solve rbc.toml
```

```
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

From here: `dsge irf`, `dsge estimate`, full Bayesian workflow
(`dsge bayes estimate`), heterogeneous-agent models (`hadsge solve ha_huggett.jl`),
OccBin constraints for the ZLB — same verbs, same tables.

## What you can do

Commands are organized by **action**, not model type — learn `estimate` once,
apply it everywhere. (Full tree: [CLI reference overview](https://friedmanjp.github.io/Friedman-cli/dev/commands/overview/).)

- **Time series** — VAR/BVAR, VECM, local projections (incl. IV/smooth/state-dependent),
  FAVAR, quantile factors/VAR/FAVAR & Growth-at-Risk (`qfm`, `qvar`, `qfavar`, `growth-at-risk`),
  DFM/GDFM/FHLZ/GDFM-I(1)/TV-GDFM/SDFM, ARIMA/ARDL/MIDAS, regime switching (SETAR/STAR/MS):
  `estimate multivariate var`, `estimate factor qfm`, `irf lp`, `forecast`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/multivariate/)
- **Volatility** — ARCH/GARCH/EGARCH/GJR, stochastic volatility, CCC/DCC/BEKK:
  `estimate volatility garch`, `forecast volatility garch`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/volatility/)
- **Micro & panels** — OLS/IV/choice models (incl. RI-logit `ri-logit`), panel regression & interactive-factor panel quantile (`xtqreg`), DiD suite
  (TWFE, Callaway-Sant'Anna, event studies, HonestDiD):
  `estimate choice logit`, `estimate panel xtqreg`, `did estimate`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/panel/)
- **Equilibrium & Rational Inattention** — RA/HA/OLG models, perturbation/projection/VFI, OccBin (`madnlp` GPL-3.0 default), canonical ABCD invertibility (`dsge abcd`), Bayesian DSGE & DSGE-VAR (`dsge var`), plus full LQG / Maćkowiak–Wiederholt / Matějka–McKay Rational Inattention (`ri`):
  `dsge solve`, `dsge abcd invertibility`, `ri solve`, `hadsge solve ha_huggett.jl`, [DSGE guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/dsge/) · [RI guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/rational-inattention/)
- **Identification & diagnostics** — Cholesky/sign/narrative/long-run/Arias/Uhlig, LMS-SVAR, Lanne–Luoto GMM, SSVARMA, Cramér–von Mises ICA, spectral FEVD,
  unit-root, cointegration, factor-rank, SVAR hypothesis & fundamentalness batteries, breaks, Granger, weak instruments:
  `irf var --id sign --config sign.toml`, `test unit-root adf`, `test multivariate svar-hypothesis`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/tests/)
- **Policy & IO** — causal-effect menus, optimal policy, behavioral RI policy news, counterfactuals,
  Leontief/Ghosh multipliers, SDA, Baqaee-Farhi:
  `policy effects var`, `io multipliers`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/chapters/policy/)

Data handling (`data describe/diagnose/transform/validate`), filters
(`filter hp/hamilton/bk`), spectral analysis, nowcasting, and an interactive
REPL (`frdc repl`, [guide](https://friedmanjp.github.io/Friedman-cli/dev/getting-started/repl/))
round it out.

## Reproducibility

- **Same command, same numbers.** `--seed N` is forwarded to samplers/simulators
  and every `--format json` envelope carries a manifest (seed, threads, OS,
  package versions) under `meta.manifest`.
- **Typed handles, zero-hassle reuse.** Save data or fitted models to `.jld2` or `.jls`,
  reuse them without re-estimating:
  `estimate multivariate var macro.csv --save-model var` →
  `irf var var.jld2` (or `irf var --model var`) → `model reproduce var` to verify against a fresh run.
- **Scriptable output.** Every leaf speaks `--format table|csv|json`
  and `--output <path>`; status goes to stderr, data to stdout — pipes compose.

## For agents

If you are wiring an LLM to economic analysis: with `--format json`, stdout is
exactly one versioned JSON envelope with stable, registry-declared table keys;
exit codes are `0 ok · 2 usage · 3 data · 4 config · 5 model · 6 env · 1 internal`,
and every JSON failure carries a matching `error.code`/`error.exit_code`.
`frdc schema <path…>` returns a draft-07 input schema plus result-table keys
for any command in **< 10 ms** via the native thin wrapper (set `FRDC_NO_FASTPATH=1`
to bypass); `serve --mcp` exposes all 558 leaf commands as Model Context Protocol
tools over stdio — answering `initialize`, `ping`, and `tools/list` in **< 10 ms**
from the embedded `FRDCACHE` pack and spawning `frdc-core` lazily on the first
`tools/call` (supporting `--families`, `--tools`, and `--compact` scoping).
For multi-command pipelines and heavy DSGE / Bayesian / volatility workflows, keep a
persistent `frdc serve --mcp` (or `frdc repl`) session open to amortize Julia/JIT
startup and share `model://` handles in memory. Start at the
[Agent Guide](https://friedmanjp.github.io/Friedman-cli/dev/agent-guide/).

Full command reference:
[docs](https://friedmanjp.github.io/Friedman-cli/dev/).

## Installation

Pre-built standalone binaries are **zero-Julia** (no Julia installation or network artifact fetch required; GPL-3.0-compatible `MadNLP` + `NLPModels` constrained NLP solvers ship bundled; optional `Ipopt` and `PATHSolver` remain source-only weak dependencies):

- **Windows (x86_64) — Microsoft Store (recommended):** Microsoft-signed MSIX with auto-updates and `frdc` on `PATH`:

  ```powershell
  winget install 9NBBQSNP6W44 --source msstore
  ```

  Or via GitHub Releases (`.msix` sideload or standalone `.zip` into `%USERPROFILE%\.frdc`):

  ```powershell
  irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
  ```

- **Linux (x86_64):** Standalone bundle (private Julia `1.14+opt` runtime included) installed to `~/.frdc/` and symlinked at `~/.local/bin/frdc`:

  ```bash
  curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
  ```

- **macOS:** Pre-built macOS binaries are not distributed (requires Apple Developer code signing/notarization). Run or build locally from source with Julia 1.13+:

  ```bash
  git clone https://github.com/FriedmanJP/Friedman-cli.git && cd Friedman-cli
  julia --project -e 'using Pkg; Pkg.instantiate()'
  julia --project bin/frdc --help
  ```

Details (manual `.tar.gz`/`.zip`/`.msix` archives, sideloading, local `build_release.jl` builds, migrating from legacy `friedman` to `frdc`): [Installation docs](https://friedmanjp.github.io/Friedman-cli/dev/getting-started/installation/).

## License

GNU General Public License v3.0 (`GPL-3.0-only`). See [LICENSE](LICENSE), [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md), [DATA_LICENSES.md](DATA_LICENSES.md), and [SOURCE_OFFER.txt](SOURCE_OFFER.txt).
