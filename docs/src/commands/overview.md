# CLI Reference Overview

Friedman-cli uses an **action-first** command hierarchy: commands are organized by action (`estimate`, `irf`, `forecast`, ...) rather than by model type.

<!-- BEGIN GENERATED: do not hand-edit; run julia docs/generate_cli_reference.jl -->

## Command Tree

```
friedman
├── completions     bash | fish | zsh
├── data     balance | describe | diagnose | dropna | export | filter | fix | import | keeprows | list | load | simulate ardl | simulate arima | simulate cointreg | simulate cross-section | simulate ct | simulate did | simulate dsge | simulate factors | simulate garch | simulate gmm | simulate ha | simulate heteroskedastic-var | simulate lp-iv | simulate olg | simulate panel | simulate pvar | simulate regime | simulate sv | simulate svar | simulate var | simulate vecm | transform | validate
├── did     estimate | event-study | lp-did
├── dsge     bank irf | bank pe | bank steady-state | bank transition | bayes compare | bayes estimate | bayes fevd | bayes hd | bayes identification | bayes irf | bayes learning-rate | bayes marginal-lik | bayes mcmc-diag | bayes overlap | bayes posterior-mode | bayes predictive | bayes prior-predictive | bayes simulate | bayes summary | ct fevd | ct irf | ct solve | ct transition | dcegm fevd | dcegm irf | dcegm simulate | dcegm solve | dcegm steady-state | dcegm transition | determinacy-map | estimate | fevd | firm irf | firm steady-state | firm transition | hd | irf | lifecycle fevd | lifecycle irf | lifecycle simulate | lifecycle steady-state | lifecycle transition | moments | olg fevd | olg irf | olg simulate | olg solve | perfect-foresight | simulate | solve | steady-state
├── estimate     choice logit | choice mlogit | choice nbreg | choice ologit | choice oprobit | choice poisson | choice probit | factor dynamic | factor fastica | factor gdfm | factor sdfm | factor static | multivariate bvar | multivariate favar | multivariate lp | multivariate mfvar | multivariate svar | multivariate svec | multivariate tvpvar | multivariate var | multivariate vecm | panel piv | panel plogit | panel pmg | panel pprobit | panel preg | panel pvar | panel xtcointreg | regime ms | regime ms-ar | regime setar | regime star | regime threshold | regime tvp | regression 3sls | regression cointreg | regression elastic-net | regression gmm | regression heckman | regression iv | regression kde | regression kernel-reg | regression lasso | regression lowess | regression ml | regression qreg | regression rdd | regression reg | regression ridge | regression robust | regression select | regression smm | regression statespace | regression sur | regression tobit | regression truncreg | univariate ardl | univariate arfima | univariate arima | univariate midas | univariate nardl | univariate sarima | volatility aparch | volatility arch | volatility bekk | volatility ccc | volatility cgarch | volatility dcc | volatility egarch | volatility fiegarch | volatility figarch | volatility garch | volatility garch-midas | volatility gjr-garch | volatility igarch | volatility sv
├── fevd     bvar | favar | lp | pvar | sdfm | var | vecm
├── filter     bhp | bk | bn | hamilton | hp | x13
├── forecast     evaluate clark-west | evaluate combine | evaluate dm | evaluate encompassing | evaluate metrics | evaluate mincer-zarnowitz | factor dynamic | factor gdfm | factor sdfm | factor static | multivariate bvar | multivariate favar | multivariate lp | multivariate scenario | multivariate var | multivariate vecm | regime ms | regime ms-ar | regime setar | regime star | univariate arfima | univariate arima | univariate midas | univariate sarima | volatility aparch | volatility arch | volatility cgarch | volatility egarch | volatility fiegarch | volatility figarch | volatility garch | volatility garch-midas | volatility gjr-garch | volatility igarch | volatility sv
├── hadsge     accuracy | distribution-irf | estimate | fevd | hd | inequality-irf | irf | simulate | simulate-panel | solve | steady-state
├── hd     bvar | favar | lp | sdfm | var | vecm
├── io     aggregate | balance | baqaee-farhi | bf elasticities | bf equilibrium | bf local | bf misallocation | bf network | bf shock-curve | bf wedges | bilateral-trade | download | export-decomposition | extract | footprint | ghosh | impact | key-sectors | leontief | linkages | load | multipliers | network-stats | price | sda | sources | vertical-specialization
├── irf     bvar | favar | lp | pvar | sdfm | tvpvar | var | vecm
├── model     info | reproduce
├── nowcast     bridge | bvar | dfm | forecast | news
├── policy     counterfactual bvar | counterfactual lp | counterfactual var | effects bvar | effects lp | effects sign | effects var | history bvar | history var | jacobian ha | moments bvar | moments var | news dsge | news ha | opp bvar | opp var | opp-sequence bvar | opp-sequence var | optimal bvar | optimal lp | optimal var | spanning var | sufficiency dsge
├── predict     choice logit | choice mlogit | choice nbreg | choice ologit | choice oprobit | choice poisson | choice probit | factor dynamic | factor gdfm | factor static | multivariate bvar | multivariate favar | multivariate var | multivariate vecm | panel piv | panel plogit | panel pprobit | panel preg | regime ms | regime ms-ar | regression 3sls | regression reg | regression statespace | regression sur | univariate arfima | univariate arima | univariate sarima | volatility aparch | volatility arch | volatility cgarch | volatility egarch | volatility fiegarch | volatility figarch | volatility garch | volatility garch-midas | volatility gjr-garch | volatility igarch | volatility sv
├── residuals     choice logit | choice mlogit | choice nbreg | choice ologit | choice oprobit | choice poisson | choice probit | factor dynamic | factor gdfm | factor static | multivariate bvar | multivariate favar | multivariate var | multivariate vecm | panel piv | panel plogit | panel pprobit | panel preg | regime ms | regime ms-ar | regime setar | regime star | regression 3sls | regression reg | regression statespace | regression sur | univariate arfima | univariate arima | univariate sarima | volatility aparch | volatility arch | volatility cgarch | volatility egarch | volatility fiegarch | volatility figarch | volatility garch | volatility garch-midas | volatility gjr-garch | volatility igarch | volatility sv
├── serve
├── show
├── spectral     acf | cross | density | periodogram | transfer
└── test     brant | coint ardl-bounds | coint engle-granger | coint fisher-johansen | coint gregory-hansen | coint johansen | coint kao | coint pedroni | coint phillips-ouliaris | coint westerlund | did bacon | did honest | did negweight | did pretrend | dispersion | edf | fisher | gph | hansen-linearity | hausman-iia | identifiability | influence | iv anderson-rubin | iv weak-instrument | iv wild-cluster | local-whittle | multivariate granger | multivariate lagselect | multivariate lm | multivariate lr | multivariate stability | nardl-symmetry | normality | panel dh-causality | panel f-fe | panel hausman | panel modified-wald | panel panic | panel pesaran-cd | panel pmg-hausman | panel wooldridge-ar | park-added | pvar hansen-j | pvar lagselect | pvar mmsc | pvar stability | serial arch-lm | serial bartlett-wn | serial bds | serial box-pierce | serial breusch-pagan | serial durbin-watson | serial glejser | serial harvey | serial heteroskedasticity | serial ljung-box | serial sign-bias | serial white | stability andrews | stability bai-perron | stability chow | stability cusum | stability cusumsq | stability factor-break | stability gsadf | stability hansen-instability | stability nyblom | stability recursive-residuals | stability sadf | star-linearity | unit-root adf | unit-root adf-2break | unit-root breitung | unit-root cips | unit-root dfgls | unit-root ers | unit-root fourier-adf | unit-root fourier-kpss | unit-root hadri | unit-root hegy | unit-root ips | unit-root kpss | unit-root llc | unit-root lm-unitroot | unit-root moon-perron | unit-root np | unit-root pp | unit-root za | variance-ratio | vecm alpha | vecm beta | vecm joint | vecm known-beta | vecm weak-exog | vif

Total: 21 top-level commands, 477 leaves (from registry).
```

Additionally, `friedman repl` launches an interactive REPL session with persistent data loading, result caching, and tab completion.

## Generated reference pages

- [`completions`](generated/completions.md) — 3 leaves
- [`data`](generated/data.md) — 34 leaves
- [`did`](generated/did.md) — 3 leaves
- [`dsge`](generated/dsge.md) — 51 leaves
- [`estimate`](generated/estimate.md) — 76 leaves
- [`fevd`](generated/fevd.md) — 7 leaves
- [`filter`](generated/filter.md) — 6 leaves
- [`forecast`](generated/forecast.md) — 35 leaves
- [`hadsge`](generated/hadsge.md) — 11 leaves
- [`hd`](generated/hd.md) — 6 leaves
- [`io`](generated/io.md) — 27 leaves
- [`irf`](generated/irf.md) — 8 leaves
- [`model`](generated/model.md) — 2 leaves
- [`nowcast`](generated/nowcast.md) — 5 leaves
- [`policy`](generated/policy.md) — 23 leaves
- [`predict`](generated/predict.md) — 38 leaves
- [`residuals`](generated/residuals.md) — 40 leaves
- [`serve`](generated/serve.md) — 1 leaves
- [`show`](generated/show.md) — 1 leaves
- [`spectral`](generated/spectral.md) — 5 leaves
- [`test`](generated/test.md) — 95 leaves

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
friedman schema estimate multivariate var
```
