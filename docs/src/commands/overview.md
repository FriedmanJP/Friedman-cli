# CLI Reference Overview

Friedman-cli uses an **action-first** command hierarchy: commands are organized by action (`estimate`, `irf`, `forecast`, ...) rather than by model type.

<!-- BEGIN GENERATED: do not hand-edit; run julia docs/generate_cli_reference.jl -->

## Command Tree

```
friedman
├── completions     bash | fish | zsh
├── data     balance | describe | diagnose | dropna | filter | fix | keeprows | list | load | transform | validate
├── did     estimate | event-study | lp-did | test bacon | test honest | test negweight | test pretrend
├── dsge     bayes compare | bayes estimate | bayes fevd | bayes hd | bayes identification | bayes irf | bayes learning-rate | bayes marginal-lik | bayes mcmc-diag | bayes overlap | bayes posterior-mode | bayes predictive | bayes prior-predictive | bayes simulate | bayes summary | ct solve | ct transition | estimate | fevd | ha accuracy | ha distribution-irf | ha estimate | ha fevd | ha inequality-irf | ha irf | ha simulate | ha simulate-panel | ha solve | ha steady-state | hd | irf | olg simulate | olg solve | perfect-foresight | simulate | solve | steady-state
├── estimate     3sls | aparch | arch | ardl | arfima | arima | bekk | bvar | ccc | cgarch | cointreg | dcc | dynamic | egarch | elastic-net | fastica | favar | fiegarch | figarch | garch | garch-midas | gdfm | gjr-garch | gmm | heckman | igarch | iv | kde | kernel-reg | lasso | logit | lowess | lp | mfvar | midas | ml | mlogit | ms | ms-ar | nardl | nbreg | ologit | oprobit | piv | plogit | pmg | poisson | pprobit | preg | probit | pvar | reg | ridge | robust | sarima | sdfm | select | setar | smm | star | statespace | static | sur | sv | threshold | tobit | truncreg | tvp | tvpvar | var | vecm | xtcointreg
├── fevd     bvar | favar | lp | pvar | sdfm | var | vecm
├── filter     bhp | bk | bn | hamilton | hp | x13
├── forecast     aparch | arch | arfima | arima | bvar | cgarch | dynamic | egarch | evaluate clark-west | evaluate combine | evaluate dm | evaluate encompassing | evaluate metrics | evaluate mincer-zarnowitz | favar | fiegarch | figarch | garch | garch-midas | gdfm | gjr-garch | igarch | lp | midas | ms | ms-ar | sarima | setar | star | static | sv | var | vecm
├── hd     bvar | favar | lp | var | vecm
├── io     baqaee-farhi | download | extract | footprint | ghosh | key-sectors | leontief | linkages | load | multipliers | sda | sources
├── irf     bvar | favar | lp | pvar | sdfm | tvpvar | var | vecm
├── model     info
├── multipliers     nardl
├── nowcast     bridge | bvar | dfm | forecast | news
├── predict     3sls | aparch | arch | arfima | arima | bvar | cgarch | dynamic | egarch | favar | fiegarch | figarch | garch | garch-midas | gdfm | gjr-garch | igarch | logit | mlogit | ms | ms-ar | nbreg | ologit | oprobit | piv | plogit | poisson | pprobit | preg | probit | reg | sarima | statespace | static | sur | sv | var | vecm
├── residuals     3sls | aparch | arch | arfima | arima | bvar | cgarch | dynamic | egarch | favar | fiegarch | figarch | garch | garch-midas | gdfm | gjr-garch | igarch | logit | mlogit | ms | ms-ar | nbreg | ologit | oprobit | piv | plogit | poisson | pprobit | preg | probit | reg | sarima | setar | star | statespace | static | sur | sv | var | vecm
├── spectral     acf | cross | density | periodogram | transfer
└── test     adf | adf-2break | andrews | arch-lm | ardl-bounds | bai-perron | bartlett-wn | bds | box-pierce | brant | breitung | breusch-pagan | chow | cips | cusum | cusumsq | dfgls | dh-causality | dispersion | durbin-watson | edf | engle-granger | ers | f-fe | factor-break | fisher | fisher-johansen | fourier-adf | fourier-kpss | glejser | gph | granger | gregory-hansen | gsadf | hadri | hansen-instability | hansen-linearity | harvey | hausman | hausman-iia | hegy | heteroskedasticity | identifiability | influence | ips | johansen | kao | kpss | ljung-box | llc | lm | lm-unitroot | local-whittle | lr | modified-wald | moon-perron | nardl-symmetry | normality | np | nyblom | panic | park-added | pedroni | pesaran-cd | phillips-ouliaris | pmg-hausman | pp | pvar hansen-j | pvar lagselect | pvar mmsc | pvar stability | recursive-residuals | sadf | sign-bias | star-linearity | var lagselect | var stability | variance-ratio | vecm alpha | vecm beta | vecm joint | vecm known-beta | vecm weak-exog | vif | weak-instrument | westerlund | white | wooldridge-ar | za

Total: 18 top-level commands, 380 leaves (from registry).
```

Additionally, `friedman repl` launches an interactive REPL session with persistent data loading, result caching, and tab completion.

## Generated reference pages

- [`completions`](generated/completions.md) — 3 leaves
- [`data`](generated/data.md) — 11 leaves
- [`did`](generated/did.md) — 7 leaves
- [`dsge`](generated/dsge.md) — 37 leaves
- [`estimate`](generated/estimate.md) — 72 leaves
- [`fevd`](generated/fevd.md) — 7 leaves
- [`filter`](generated/filter.md) — 6 leaves
- [`forecast`](generated/forecast.md) — 33 leaves
- [`hd`](generated/hd.md) — 5 leaves
- [`io`](generated/io.md) — 12 leaves
- [`irf`](generated/irf.md) — 8 leaves
- [`model`](generated/model.md) — 1 leaves
- [`multipliers`](generated/multipliers.md) — 1 leaves
- [`nowcast`](generated/nowcast.md) — 5 leaves
- [`predict`](generated/predict.md) — 38 leaves
- [`residuals`](generated/residuals.md) — 40 leaves
- [`spectral`](generated/spectral.md) — 5 leaves
- [`test`](generated/test.md) — 89 leaves

<!-- END GENERATED -->

## Common Options

All commands that produce output support these options:

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--format` | `-f` | String | `table` | Output format: `table`, `csv`, or `json` |
| `--output` | `-o` | String | (stdout) | Export results to a file path |

## Help

Every command and subcommand supports `--help`. Machine-readable schema:

```bash
friedman schema estimate var
```
