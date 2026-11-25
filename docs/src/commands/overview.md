# [CLI Reference Overview](@id cli-overview)

Friedman-cli uses an **action-first** command hierarchy (`verb [family] model`). For pipeline-oriented walkthroughs organized by econometric domain, start from the domain chapters in the sidebar or [Choosing a Method](@ref gs-method-guide).

<!-- BEGIN GENERATED: do not hand-edit; run julia --project docs/generate_cli_reference.jl -->

## Command Tree

```text
frdc
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

Additionally, `frdc repl` launches an interactive REPL session ([Interactive REPL](@ref gs-repl)).

---

## Generated Reference Pages

- [`completions`](@ref ref-completions) — 3 leaves
- [`data`](@ref ref-data) — 34 leaves
- [`did`](@ref ref-did) — 3 leaves
- [`dsge`](@ref ref-dsge) — 51 leaves
- [`estimate`](@ref ref-estimate) — 76 leaves
- [`fevd`](@ref ref-fevd) — 7 leaves
- [`filter`](@ref ref-filter) — 6 leaves
- [`forecast`](@ref ref-forecast) — 35 leaves
- [`hadsge`](@ref ref-hadsge) — 11 leaves
- [`hd`](@ref ref-hd) — 6 leaves
- [`io`](@ref ref-io) — 27 leaves
- [`irf`](@ref ref-irf) — 8 leaves
- [`model`](@ref ref-model) — 2 leaves
- [`nowcast`](@ref ref-nowcast) — 5 leaves
- [`policy`](@ref ref-policy) — 23 leaves
- [`predict`](@ref ref-predict) — 38 leaves
- [`residuals`](@ref ref-residuals) — 40 leaves
- [`serve`](@ref ref-serve) — 1 leaves
- [`show`](@ref ref-show) — 1 leaves
- [`spectral`](@ref ref-spectral) — 5 leaves
- [`test`](@ref ref-test) — 95 leaves

<!-- END GENERATED -->

---

## Common Options & Globals

Every leaf that produces tabular output supports `--format`/`-f` (`table`|`csv`|`json`) and `--output`/`-o` (`<path>` to write to a file instead of stdout). Leaves accepting structured specifications add `--config <path>` (see [Model Cards & Config Grammar](@ref cfg-overview)); plot-capable leaves add `--plot` and `--plot-save <path>`.

Leading agent globals go **before** the command: `--seed N`, `--quiet`/`-q`, `--json`, and `--no-color`. See [Pipelines, Handles & Reproducibility](@ref gs-pipelines) and the [Agent Guide](../agent-guide.md) for the complete JSON envelope and typed handle contract.

---

## Help & Machine Schema

Every node and leaf accepts `--help` (`-h`). Machine-readable draft-07 input schemas and declared table keys come from `frdc schema`:

```bash
frdc schema estimate multivariate var
```
