# CLI Reference Overview

Friedman-cli uses an **action-first** command hierarchy: commands are organized by action (`estimate`, `irf`, `forecast`, ...) rather than by model type.

<!-- BEGIN GENERATED: do not hand-edit; run julia docs/generate_cli_reference.jl -->

## Command Tree

```
friedman
├── completions     bash | fish | zsh
├── data     balance | describe | diagnose | dropna | filter | fix | keeprows | list | load | transform | validate
├── did     estimate | event-study | lp-did | test bacon | test honest | test negweight | test pretrend
├── dsge     bayes compare | bayes estimate | bayes fevd | bayes hd | bayes identification | bayes irf | bayes learning-rate | bayes marginal-lik | bayes mcmc-diag | bayes overlap | bayes predictive | bayes simulate | bayes summary | ct solve | ct transition | estimate | fevd | ha distribution-irf | ha estimate | ha fevd | ha inequality-irf | ha irf | ha simulate | ha simulate-panel | ha solve | ha steady-state | hd | irf | olg simulate | olg solve | perfect-foresight | simulate | solve | steady-state
├── estimate     3sls | aparch | arch | ardl | arfima | arima | bekk | bvar | ccc | cgarch | cointreg | dcc | dynamic | egarch | elastic-net | fastica | favar | fiegarch | figarch | garch | garch-midas | gdfm | gjr-garch | gmm | heckman | igarch | iv | kde | kernel-reg | lasso | logit | lowess | lp | midas | ml | mlogit | nardl | ologit | oprobit | piv | plogit | pmg | pprobit | preg | probit | pvar | reg | ridge | robust | sdfm | setar | smm | statespace | static | sur | sv | tobit | truncreg | tvp | var | vecm | xtcointreg
├── fevd     bvar | favar | lp | pvar | sdfm | var | vecm
├── filter     bhp | bk | bn | hamilton | hp | x13
├── forecast     arch | arima | bvar | dynamic | egarch | evaluate clark-west | evaluate combine | evaluate dm | evaluate encompassing | evaluate metrics | evaluate mincer-zarnowitz | favar | garch | gdfm | gjr-garch | lp | setar | static | sv | var | vecm
├── hd     bvar | favar | lp | var | vecm
├── io     baqaee-farhi | download | extract | footprint | ghosh | key-sectors | leontief | linkages | load | multipliers | sda | sources
├── irf     bvar | favar | lp | pvar | sdfm | var | vecm
├── model     info
├── multipliers     nardl
├── nowcast     bridge | bvar | dfm | forecast | news
├── predict     arch | arima | bvar | dynamic | egarch | favar | garch | gdfm | gjr-garch | logit | mlogit | ologit | oprobit | piv | plogit | pprobit | preg | probit | reg | static | sv | var | vecm
├── residuals     arch | arima | bvar | dynamic | egarch | favar | garch | gdfm | gjr-garch | logit | mlogit | ologit | oprobit | piv | plogit | pprobit | preg | probit | reg | static | sv | var | vecm
├── spectral     acf | cross | density | periodogram | transfer
└── test     adf | adf-2break | andrews | arch-lm | ardl-bounds | bai-perron | bartlett-wn | bds | box-pierce | brant | breusch-pagan | cips | dfgls | durbin-watson | f-fe | factor-break | fisher | fourier-adf | fourier-kpss | gph | granger | gregory-hansen | hadri | hansen-linearity | hausman | hausman-iia | heteroskedasticity | identifiability | johansen | kao | kpss | ljung-box | lm | lm-unitroot | local-whittle | lr | modified-wald | moon-perron | nardl-symmetry | normality | np | nyblom | panic | pedroni | pesaran-cd | pmg-hausman | pp | pvar hansen-j | pvar lagselect | pvar mmsc | pvar stability | sign-bias | var lagselect | var stability | variance-ratio | vecm alpha | vecm beta | vecm joint | vecm known-beta | vecm weak-exog | vif | weak-instrument | westerlund | wooldridge-ar | za

Total: 18 top-level commands, 298 leaves (from registry).
```

Additionally, `friedman repl` launches an interactive REPL session with persistent data loading, result caching, and tab completion.

## Generated reference pages

- [`completions`](generated/completions.md) — 3 leaves
- [`data`](generated/data.md) — 11 leaves
- [`did`](generated/did.md) — 7 leaves
- [`dsge`](generated/dsge.md) — 34 leaves
- [`estimate`](generated/estimate.md) — 62 leaves
- [`fevd`](generated/fevd.md) — 7 leaves
- [`filter`](generated/filter.md) — 6 leaves
- [`forecast`](generated/forecast.md) — 21 leaves
- [`hd`](generated/hd.md) — 5 leaves
- [`io`](generated/io.md) — 12 leaves
- [`irf`](generated/irf.md) — 7 leaves
- [`model`](generated/model.md) — 1 leaves
- [`multipliers`](generated/multipliers.md) — 1 leaves
- [`nowcast`](generated/nowcast.md) — 5 leaves
- [`predict`](generated/predict.md) — 23 leaves
- [`residuals`](generated/residuals.md) — 23 leaves
- [`spectral`](generated/spectral.md) — 5 leaves
- [`test`](generated/test.md) — 65 leaves

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
