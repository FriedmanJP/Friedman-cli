# [Hypothesis Testing & Diagnostics](@id chap-tests)

Diagnostic and specification tests in `Friedman-cli` live under [`friedman test`](@ref ref-test) across 11 families (`unit-root`, `coint`, `vecm`, `multivariate`, `serial`, `stability`, `panel`, `pvar`, `iv`, `did`, plus standalone model diagnostics). Use the decision guide below to select the right test before or after estimating any model. See [MacroEconometricModels.jl — Hypothesis Tests](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/tests/) for asymptotic distributions and finite-sample adjustments.

## Quick Start

Run the Augmented Dickey–Fuller unit-root test (`adf`), KPSS stationarity test (`kpss`), and Johansen trace/max-eigenvalue cointegration rank test on `:denmark`:

<!-- capture -->
```bash
friedman test unit-root adf :denmark --column 1 --trend constant
```
```text
       ADF Test: LRM
┌────────────────┬────────┐
│     metric     │ value  │
├────────────────┼────────┤
│ Test statistic │ -1.263 │
│      Lags      │   2    │
│    p-value     │ 0.6172 │
└────────────────┴────────┘
```

The command returns `adf_test` (`Test statistic = -1.263`, `Lags = 2`, `p-value = 0.6172`—failing to reject the unit-root null for `LRM`); complement unit-root rejection failures with [`test unit-root kpss`](@ref ref-test-unit-root-kpss) (whose null is *stationarity*) and multi-series rank checks via [`test coint johansen`](@ref ref-test-coint-johansen).

---

## Master Diagnostic Decision Matrix

| Empirical Question | Family / Anchor | Subcommands |
|---|---|---|
| Is a single series $I(0)$ or $I(1)$, possibly with seasonality or breaks? | [`unit-root`](@ref ref-fam-test-unit-root) | `adf`, `dfgls`, `ers`, `pp`, `np`, `kpss`, `za`, `adf-2break`, `lm-unitroot`, `fourier-adf`, `fourier-kpss`, `hegy` |
| Does a panel exhibit unit roots under cross-sectional dependence? | [`unit-root`](@ref ref-fam-test-unit-root), [`panel`](@ref ref-fam-test-panel) | `llc`, `ips`, `breitung`, `hadri`, `cips`, `moon-perron`, `panic` |
| Are $I(1)$ series cointegrated (single-eq, system, ARDL, or panel)? | [`coint`](@ref ref-fam-test-coint), [`vecm`](@ref ref-fam-test-vecm) | `johansen`, `engle-granger`, `phillips-ouliaris`, `gregory-hansen`, `ardl-bounds`, `kao`, `pedroni`, `westerlund`, `fisher-johansen`, `vecm alpha\|beta\|joint\|known-beta\|weak-exog` |
| Are VAR lags, residual whiteness, normality, or causality satisfied? | [`multivariate`](@ref ref-fam-test-multivariate), [`serial`](@ref ref-fam-test-serial), [`Other`](@ref ref-fam-test-other) | `lagselect`, `stability`, `granger`, `lm`, `lr`, `normality`, `heteroskedasticity`, `identifiability` |
| Are univariate/regression residuals autocorrelated, ARCH, or heteroskedastic? | [`serial`](@ref ref-fam-test-serial), [`Other`](@ref ref-fam-test-other) | `durbin-watson`, `ljung-box`, `box-pierce`, `bartlett-wn`, `bds`, `arch-lm`, `sign-bias`, `breusch-pagan`, `white`, `glejser`, `harvey`, `edf` |
| Are parameters, cointegration, variance, or asset prices unstable/bubbly? | [`stability`](@ref ref-fam-test-stability) | `chow`, `andrews`, `bai-perron`, `cusum`, `cusumsq`, `recursive-residuals`, `nyblom`, `hansen-instability`, `factor-break`, `sadf`, `gsadf` |
| Is the data-generating process nonlinear, long-memory, or asymmetric? | [`Other`](@ref ref-fam-test-other) | `hansen-linearity`, `star-linearity`, `nardl-symmetry`, `variance-ratio`, `gph`, `local-whittle`, `fisher` |
| Are cross-sectional OLS, IV, discrete, or count specifications valid? | [`iv`](@ref ref-fam-test-iv), [`Other`](@ref ref-fam-test-other) | `vif`, `influence`, `weak-instrument`, `anderson-rubin`, `wild-cluster`, `brant`, `hausman-iia`, `dispersion`, `park-added` |
| Which panel, PVAR, or DiD assumptions hold? | [`panel`](@ref ref-fam-test-panel), [`pvar`](@ref ref-fam-test-pvar), [`did`](@ref ref-fam-test-did) | `f-fe`, `hausman`, `modified-wald`, `pesaran-cd`, `wooldridge-ar`, `dh-causality`, `pmg-hausman`, `pvar hansen-j\|lagselect\|mmsc\|stability`, `did bacon\|negweight\|pretrend\|honest` |

---

## Stationarity, Structural Breaks & Explosive Episodes

Classical unit-root tests lose power against trend-stationary alternatives with structural breaks or smooth transitions, while asset-price bubbles leave mildly explosive right-tailed signatures:

```math
\Delta y_t = \alpha + \beta t + \gamma y_{t-1} + \sum_{j=1}^p \delta_j \Delta y_{t-j} + \sum_{k=1}^K \left(a_k \sin\tfrac{2\pi k t}{T} + b_k \cos\tfrac{2\pi k t}{T}\right) + \varepsilon_t.
```

- **Confirmatory & Break-Aware Unit Roots:** Combine `adf`/`dfgls`/`pp`/`np`/`ers` against `kpss`; switch to Zivot–Andrews (`za`), Lee–Strazicich (`lm-unitroot`), or two-break ADF (`adf-2break`) for endogenous breaks, `fourier-adf`/`fourier-kpss` for smooth breaks, and `hegy` for quarterly/monthly seasonal roots.
- **Structural Stability & Bubbles:** Locate single breaks via [`test stability andrews`](@ref ref-test-stability-andrews) or multiple breaks via Bai–Perron [`bai-perron`](@ref ref-test-stability-bai-perron), monitor recursive residuals via `cusum`/`cusumsq`/`nyblom`, and date speculative bubbles via Phillips–Shi–Yu right-tailed [`sadf`](@ref ref-test-stability-sadf) / [`gsadf`](@ref ref-test-stability-gsadf).

<!-- capture -->
```bash
friedman test stability bai-perron :nile --response 1 --max-breaks 3 --criterion bic
```
```text
      Bai-Perron Test
┌──────────────────┬───────┐
│      metric      │ value │
├──────────────────┼───────┤
│ Number of breaks │   1   │
│   Break dates    │  28   │
│     Trimming     │ 0.15  │
│   Observations   │  100  │
└──────────────────┴───────┘
```

The `bai_perron_test` table identifies `1` endogenous level shift in `:nile` at observation `28` (out of `100` observations with `0.15` trimming, corresponding to completion of the first Aswan dam) under BIC selection.

---

## Cointegration, VAR Diagnostics & Causal Specification Tests

- **Johansen, ARDL Bounds & VECM Restrictions:** Determine cointegration rank with [`test coint johansen`](@ref ref-test-coint-johansen) (`--lags`, `--trend constant`), verify mixed-$I(0)/I(1)$ long-run relations via Pesaran–Shin–Smith [`test coint ardl-bounds`](@ref ref-test-coint-ardl-bounds), test regime-switching cointegration with [`test coint gregory-hansen`](@ref ref-test-coint-gregory-hansen), and impose exact linear restrictions $H\varphi$ / $A\psi$ on estimated VECMs via [`test vecm beta|alpha|joint|known-beta|weak-exog`](@ref ref-fam-test-vecm) ([Priors, SVAR & VECM Identification](@ref cfg-identification)).
- **VAR Order, Granger Causality & Residuals:** Select lag orders with [`test multivariate lagselect`](@ref ref-test-multivariate-lagselect), test modulus $< 1$ with [`test multivariate stability`](@ref ref-test-multivariate-stability), test block/pairwise exclusion with [`test multivariate granger`](@ref ref-test-multivariate-granger), and check residual non-normality/heteroskedasticity/non-Gaussian identifiability via [`test normality`](@ref ref-test-normality), [`test serial heteroskedasticity`](@ref ref-test-serial-heteroskedasticity), and [`test identifiability`](@ref ref-test-identifiability).

<!-- capture -->
```bash
friedman test coint johansen :denmark --lags 2 --trend constant
```
```text
          Johansen Trace Test
┌──────┬────────────┬─────────┬────────┐
│ rank │ trace_stat │ p_value │ reject │
├──────┼────────────┼─────────┼────────┤
│  0   │  123.686   │   0.0   │  yes   │
│  1   │  60.1904   │ 0.0117  │  yes   │
│  2   │  27.7573   │ 0.2556  │   no   │
│  3   │  10.2196   │ 0.6242  │   no   │
│  4   │   1.9722   │ 0.7794  │   no   │
└──────┴────────────┴─────────┴────────┘
     Johansen Max Eigenvalue Test
┌──────┬──────────┬─────────┬────────┐
│ rank │ max_stat │ p_value │ reject │
├──────┼──────────┼─────────┼────────┤
│  0   │ 63.4959  │   0.0   │  yes   │
│  1   │ 32.4331  │ 0.0124  │  yes   │
│  2   │ 17.5377  │  0.21   │   no   │
│  3   │  8.2474  │ 0.5295  │   no   │
│  4   │  1.9722  │ 0.7783  │   no   │
└──────┴──────────┴─────────┴────────┘
```

Both `johansen_trace_test` and `johansen_max_eigenvalue_test` reject rank `0` ($p = 0.0$) and rank `1` ($p = 0.0117$ trace; $p = 0.0124$ max-eigenvalue) at the 5% level while failing to reject rank `2` ($27.7573$, $p = 0.2556$; $17.5377$, $p = 0.21$), indicating cointegrating rank $r = 2$ across Danish money demand (`LRM`, `LRY`, `LPY`, `IBO`, `IDE`).

---

## Common Pitfalls

1. **Running `test unit-root kpss` and reading $H_0$ backwards:** Unlike `adf`, `pp`, and `dfgls` (null: unit root), `kpss` and `fourier-kpss` test the **null hypothesis of stationarity**; low $p$-values under KPSS reject stationarity.
2. **Omitting `--dep` on regression diagnostics (`vif`, `white`, `chow`, `cusum`, `park-added`):** Column-index time-series tests take `--column 1` (or `--response`), whereas regression diagnostics require explicit dependent variable selection via `--dep`.
3. **Leaving default high `mc-reps 999` on `sadf`/`gsadf` or `reps 1000` on `hansen-linearity` in interactive loops:** Set leading `--seed` and moderate bootstrap/Monte Carlo counts when iterating rapidly, then run full 999+ replications for final publication tables.

---

## References

- Dickey, D. A., & Fuller, W. A. (1979). Distribution of the estimators for autoregressive time series with a unit root. *JASA*, 74(366a), 427–431.
- Bai, J., & Perron, P. (2003). Computation and analysis of multiple structural change models. *Journal of Applied Econometrics*, 18(1), 1–22.
- Johansen, S. (1991). Estimation and hypothesis testing of cointegration vectors in Gaussian vector autoregressive models. *Econometrica*, 59(6), 1551–1580.
- Phillips, P. C., Shi, S., & Yu, J. (2015). Testing for multiple bubbles: Historical episodes of exuberance and collapse in the S&P 500. *IER*, 56(4), 1043–1078.
- Upstream manual: [MacroEconometricModels.jl — Hypothesis Tests](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/tests/)
- CLI reference: [`friedman test`](@ref ref-test), [`friedman test unit-root`](@ref ref-fam-test-unit-root), [`friedman test coint`](@ref ref-fam-test-coint), [`friedman test stability`](@ref ref-fam-test-stability)
