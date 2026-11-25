# [Volatility & Multivariate GARCH](@id chap-volatility)

Financial and macroeconomic volatility clustering, leverage asymmetries, long-memory persistence, mixed-frequency macro drivers, latent stochastic volatility, and time-varying conditional covariance matrices are handled across all 14 volatility subcommands under [`estimate volatility`](@ref ref-fam-estimate-volatility), alongside conditional variance prediction (`predict volatility`), standardized residuals (`residuals volatility`), and multi-step volatility forecasting (`forecast volatility`). See the upstream [Volatility manual](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/volatility/) in `MacroEconometricModels.jl`.

## Quick Start

Simulate a 250-period GARCH(1,1) series with a fixed seed, estimate conditional variance parameters (Gaussian innovations), and forecast conditional variance across a 6-step horizon:

<!-- capture -->
```bash
frdc --quiet data simulate garch --kind garch --periods 250 --seed 42 --save-data garch_sim
frdc --quiet estimate volatility garch garch_sim --p 1 --q 1 --save-model garch_fit
frdc forecast volatility garch --model garch_fit.jld2 --horizons 6
```
```text
GARCH(1,1) Volatility Forecast (series, h=6)
┌─────────┬──────────┬────────────┐
│ horizon │ variance │ volatility │
├─────────┼──────────┼────────────┤
│    1    │ 0.320159 │  0.565826  │
│    2    │ 0.323899 │  0.569121  │
│    3    │ 0.327559 │  0.572328  │
│    4    │ 0.330963 │  0.575293  │
│    5    │ 0.334169 │  0.578074  │
│    6    │ 0.336948 │  0.580472  │
└─────────┴──────────┴────────────┘
```

Storing `garch_fit.jld2` reuses the fitted MLE parameters directly across [`predict volatility garch`](@ref ref-predict-volatility-garch), [`residuals volatility garch`](@ref ref-residuals-volatility-garch), and [`forecast volatility garch`](@ref ref-forecast-volatility-garch) (JSON table key `garch_volatility_forecast`).

---

## Univariate GARCH & Asymmetric Volatility

Conditional heteroskedasticity models express demeaned innovations $r_t = \mu + \varepsilon_t$ as $\varepsilon_t = \sigma_t z_t$ where $z_t$ follows normal, Student-$t$, or generalized error distributions (`--dist normal|student|ged`). Standard GARCH($p,q$) updates conditional variance $\sigma_t^2$, whereas GJR-GARCH adds asymmetric indicator responses $\mathbb{I}\{\varepsilon_{t-i} < 0\}$ and EGARCH models log variance directly without non-negativity restrictions:

```math
\sigma_t^2 = \omega + \sum_{i=1}^q \left(\alpha_i + \gamma_i \mathbb{I}_{\varepsilon_{t-i}<0}\right)\varepsilon_{t-i}^2 + \sum_{j=1}^p \beta_j \sigma_{t-j}^2, \qquad \ln \sigma_t^2 = \omega + \dots
```

| Model Subcommand | Functional Form & Purpose | Output Tables (`--format json`) |
|---|---|---|
| [`arch`](@ref ref-estimate-volatility-arch) | Short-memory squared-shock ARCH($q$) | `arch_coefficients` |
| [`garch`](@ref ref-estimate-volatility-garch) | Baseline stationary GARCH($p,q$) with `--dist` | `garch_coefficients`, `conditional_distribution` |
| [`egarch`](@ref ref-estimate-volatility-egarch) | Exponential log-variance asymmetry | `egarch_coefficients`, `conditional_distribution` |
| [`gjr-garch`](@ref ref-estimate-volatility-gjr-garch) | Threshold leverage effect on negative shocks | `gjr_garch_coefficients`, `conditional_distribution` |
| [`aparch`](@ref ref-estimate-volatility-aparch) | Asymmetric Power ARCH ($\sigma_t^\delta$; `--fix-delta`, `--fix-gamma`) | `aparch_coefficients`, `aparch_diagnostics` |
| [`cgarch`](@ref ref-estimate-volatility-cgarch) | Two-component transitory/permanent volatility | `cgarch_coefficients`, `cgarch_diagnostics` |

---

## Integrated, Long-Memory, MIDAS & Stochastic Volatility

Volatility shocks often decay hyperbolically rather than exponentially, obey unit persistence ($\alpha + \beta = 1$), depend on low-frequency macro drivers, or evolve via latent log-volatility innovations $h_t$:

```math
(1 - \beta(L))(\ln \sigma_t^2 - \dots) \quad \text{vs.} \quad h_{t+1} = \mu + \phi (h_t - \mu) + \eta_t, \quad \eta_t \sim \mathcal{N}(0, \sigma_\eta^2).
```

- **Integrated & Long-Memory Volatility:** [`igarch`](@ref ref-estimate-volatility-igarch) constrains persistence to unity; [`figarch`](@ref ref-estimate-volatility-figarch) and [`fiegarch`](@ref ref-estimate-volatility-fiegarch) introduce fractional differencing $(1-L)^d$ with initial `--d0 0.4` and lag truncation `--truncation 1000`.
- **MIDAS Long-Run Decomposition (`garch-midas`):** [`estimate volatility garch-midas`](@ref ref-estimate-volatility-garch-midas) multiplicatively splits short-run GARCH dynamics from a secular component driven either by realized return blocks (`--rv realized`) or by an exogenous macro driver `[garch_midas] x_lf` passed via `--config` ([GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy)).
- **Bayesian Stochastic Volatility (`sv`):** [`estimate volatility sv`](@ref ref-estimate-volatility-sv) estimates the Kim–Shephard–Chib MCMC sampler (`--draws`) using leading `--seed` for reproducibility (`sv_coefficients`, `sv_conditional_variance`, `sv_standardized_residuals`).

<!-- capture -->
```bash
frdc --quiet --seed 42 data simulate sv --mu -0.5 --phi 0.95 --sigma-eta 0.2 --periods 150 --save-data sv_sim
frdc --seed 42 estimate volatility sv sv_sim --draws 400
```
```text
   SV Coefficients (y)
┌───────────┬───────────┐
│ parameter │ estimate  │
├───────────┼───────────┤
│    mu     │ -0.498525 │
│    phi    │ 0.945236  │
│ sigma_eta │ 0.154004  │
└───────────┴───────────┘
```

The `sv_coefficients` table summarizes posterior mean estimates (`mu = -0.498525`, `phi = 0.945236`, `sigma_eta = 0.154004`) near the true DGP values.

---

## Multivariate GARCH (`ccc`, `dcc`, `bekk`)

Multivariate volatility models decompose the conditional covariance matrix $H_t = D_t R_t D_t$ into univariate GARCH volatilities $D_t = \mathrm{diag}(\sqrt{h_{1t}}, \dots, \sqrt{h_{Nt}})$ and constant (`ccc`) or time-varying (`dcc`) conditional correlation $R_t$, or specify quadratic covariance updates directly in `bekk`:

```math
Q_t = (1 - a - b)\bar{Q} + a (\tilde{\varepsilon}_{t-1}\tilde{\varepsilon}_{t-1}') + b Q_{t-1}, \qquad R_t = \mathrm{diag}(Q_t)^{-1/2} Q_t \mathrm{diag}(Q_t)^{-1/2}.
```

- [`estimate volatility ccc`](@ref ref-estimate-volatility-ccc): Constant Conditional Correlation GARCH(`--p`, `--q`).
- [`estimate volatility dcc`](@ref ref-estimate-volatility-dcc): Engle's Dynamic Conditional Correlation (`--correction none|aielli` for cDCC consistency).
- [`estimate volatility bekk`](@ref ref-estimate-volatility-bekk): Positive-definite BEKK covariance recursion (`--kind scalar|diagonal`).

<!-- capture -->
```bash
frdc --quiet data simulate var --periods 300 --burn 50 --seed 2 --save-data mv_sim
frdc estimate volatility dcc mv_sim --p 1 --q 1 --correction none
```
```text
     DCC-GARCH Conditional Correlation
┌────────┬──────────┬──────────┬──────────┐
│ series │    y1    │    y2    │    y3    │
├────────┼──────────┼──────────┼──────────┤
│   y1   │   1.0    │ 0.383801 │ 0.413936 │
│   y2   │ 0.383801 │   1.0    │ 0.12696  │
│   y3   │ 0.413936 │ 0.12696  │   1.0    │
└────────┴──────────┴──────────┴──────────┘
             DCC-GARCH Dynamics Parameters
┌───────────┬──────────┬───────────┬────────┬─────────┐
│ parameter │ estimate │ std_error │ z_stat │ p_value │
├───────────┼──────────┼───────────┼────────┼─────────┤
│     a     │ 0.15717  │ 0.040307  │ 3.8993 │ 0.0001  │
│     b     │ 0.150718 │ 0.127061  │ 1.1862 │ 0.2355  │
└───────────┴──────────┴───────────┴────────┴─────────┘
   DCC-GARCH Diagnostics
┌──────────────┬──────────┐
│    metric    │  value   │
├──────────────┼──────────┤
│    loglik    │ -1293.58 │
│     aic      │ 2615.16  │
│     bic      │ 2667.01  │
│    series    │    3     │
│ observations │   300    │
│  converged   │   true   │
│     kind     │   dcc    │
│  correction  │   none   │
│ persistence  │ 0.307888 │
└──────────────┴──────────┘
```

The command emits `dcc_garch_conditional_correlation` (`(y1, y2) = 0.383801`, `(y1, y3) = 0.413936`), `dcc_garch_dynamics_parameters` (`a = 0.15717`, `b = 0.150718`), and `dcc_garch_diagnostics` (`loglik = -1293.58`, `bic = 2667.01`, `persistence = 0.307888`) under `--format json`. Notice multivariate GARCH commands (`ccc`, `dcc`, `bekk`) estimate full-system dynamics and do not have separate `predict`/`forecast`/`residuals` leaves.

---

## Common Pitfalls

1. **Omitting `--config [garch_midas]` when `--rv macro` is set:** Under the default `--rv realized`, [`estimate volatility garch-midas`](@ref ref-estimate-volatility-garch-midas) requires no config; switching to `--rv macro` requires a TOML `[garch_midas]` vector `x_lf` covering at least `floor(n / m_freq)` blocks ([GMM, SMM, Systems, State-Space & Policy](@ref cfg-models-policy)).
2. **Expecting `predict`/`forecast` leaves for `ccc`, `dcc`, `bekk`:** Conditional covariance prediction and residual extraction live exclusively for the 11 univariate GARCH/SV models (`arch`, `garch`, `egarch`, `gjr-garch`, `aparch`, `cgarch`, `figarch`, `fiegarch`, `igarch`, `garch-midas`, `sv`); multivariate GARCH outputs its final conditional correlations directly during `estimate`.
3. **Re-running `sv` MCMC without `--seed`:** Stochastic volatility draws depend on RNG state; always fix leading `--seed` so posterior summaries (`sv_coefficients`) and [`model reproduce`](@ref ref-model-reproduce) verify cleanly.

---

## References

- Bollerslev, T. (1986). Generalized autoregressive conditional heteroskedasticity. *Journal of Econometrics*, 31(3), 307–327.
- Engle, R. (2002). Dynamic conditional correlation: A simple class of multivariate generalized autoregressive conditional heteroskedasticity models. *Journal of Business & Economic Statistics*, 20(3), 339–350.
- Kim, S., Shephard, N., & Chib, S. (1998). Stochastic volatility: Likelihood inference and comparison with ARCH models. *Review of Economic Studies*, 65(3), 361–393.
- Upstream manual: [MacroEconometricModels.jl — Volatility](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/volatility/)
- CLI reference: [`frdc estimate volatility`](@ref ref-fam-estimate-volatility), [`frdc forecast volatility`](@ref ref-fam-forecast-volatility), [`frdc predict volatility`](@ref ref-fam-predict-volatility), [`frdc residuals volatility`](@ref ref-fam-residuals-volatility)
