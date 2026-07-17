# CLI Reference Overview

Friedman-cli uses an **action-first** command hierarchy: commands are organized by action (`estimate`, `irf`, `forecast`, ...) rather than by model type.

<!-- BEGIN GENERATED: do not hand-edit; run julia docs/generate_cli_reference.jl -->

## Command Tree

```
friedman
├── completions     bash | fish | zsh
├── data     balance | describe | diagnose | dropna | filter | fix | keeprows | list | load | transform | validate
├── did     estimate | event-study | lp-did | test bacon | test honest | test negweight | test pretrend
├── dsge     bayes compare | bayes estimate | bayes fevd | bayes hd | bayes irf | bayes predictive | bayes simulate | bayes summary | ct solve | ct transition | estimate | fevd | ha distribution-irf | ha fevd | ha inequality-irf | ha irf | ha simulate | ha simulate-panel | ha solve | ha steady-state | hd | irf | olg simulate | olg solve | perfect-foresight | simulate | solve | steady-state
├── estimate     arch | arima | bvar | dynamic | egarch | fastica | favar | garch | gdfm | gjr_garch | gmm | iv | logit | lp | ml | mlogit | ologit | oprobit | piv | plogit | pprobit | preg | probit | pvar | reg | sdfm | smm | static | sv | var | vecm
├── fevd     bvar | favar | lp | pvar | sdfm | var | vecm
├── filter     bhp | bk | bn | hamilton | hp | x13
├── forecast     arch | arima | bvar | dynamic | egarch | favar | garch | gdfm | gjr_garch | lp | static | sv | var | vecm
├── hd     bvar | favar | lp | var | vecm
├── irf     bvar | favar | lp | pvar | sdfm | var | vecm
├── model     info
├── nowcast     bridge | bvar | dfm | forecast | news
├── predict     arch | arima | bvar | dynamic | egarch | favar | garch | gdfm | gjr_garch | logit | mlogit | ologit | oprobit | piv | plogit | pprobit | preg | probit | reg | static | sv | var | vecm
├── residuals     arch | arima | bvar | dynamic | egarch | favar | garch | gdfm | gjr_garch | logit | mlogit | ologit | oprobit | piv | plogit | pprobit | preg | probit | reg | static | sv | var | vecm
├── spectral     acf | cross | density | periodogram | transfer
└── test     adf | adf-2break | andrews | arch_lm | bai-perron | bartlett-wn | box-pierce | brant | breusch-pagan | cips | dfgls | durbin-watson | f-fe | factor-break | fisher | fourier-adf | fourier-kpss | granger | gregory-hansen | hausman | hausman-iia | heteroskedasticity | identifiability | johansen | kpss | ljung_box | lm | lm-unitroot | lr | modified-wald | moon-perron | normality | np | panic | pesaran-cd | pp | pvar hansen_j | pvar lagselect | pvar mmsc | pvar stability | var lagselect | var stability | vif | wooldridge-ar | za

Total: 16 top-level commands, 221 leaves (from registry).
```

Additionally, `friedman repl` launches an interactive REPL session with persistent data loading, result caching, and tab completion.

## Generated reference pages

- [`completions`](generated/completions.md) — 3 leaves
- [`data`](generated/data.md) — 11 leaves
- [`did`](generated/did.md) — 7 leaves
- [`dsge`](generated/dsge.md) — 28 leaves
- [`estimate`](generated/estimate.md) — 31 leaves
- [`fevd`](generated/fevd.md) — 7 leaves
- [`filter`](generated/filter.md) — 6 leaves
- [`forecast`](generated/forecast.md) — 14 leaves
- [`hd`](generated/hd.md) — 5 leaves
- [`irf`](generated/irf.md) — 7 leaves
- [`model`](generated/model.md) — 1 leaves
- [`nowcast`](generated/nowcast.md) — 5 leaves
- [`predict`](generated/predict.md) — 23 leaves
- [`residuals`](generated/residuals.md) — 23 leaves
- [`spectral`](generated/spectral.md) — 5 leaves
- [`test`](generated/test.md) — 45 leaves

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
