# [Discrete Choice, Count & Selection](@id chap-choice)

Binary, ordered, multinomial, and count outcomes sit under [`estimate choice`](@ref ref-fam-estimate-choice) alongside full fitted-probability/marginal-effect prediction ([`predict choice`](@ref ref-fam-predict-choice)) and residual extraction ([`residuals choice`](@ref ref-fam-residuals-choice)), while censored (`tobit`), truncated (`truncreg`), sample-selected (`heckman`), and stepwise (`select`) regressions sit under [`estimate regression`](@ref ref-fam-estimate-regression). See [MacroEconometricModels.jl — Discrete Choice & Selection](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/discrete/) for full likelihood derivations.

## Quick Start

Simulate a binary cross-sectional dataset (`logit`), fit a binary logit model with HC1 standard errors, and compute average marginal effects and classification accuracy:

<!-- capture -->
```bash
friedman --quiet data simulate cross-section --kind logit --n 200 --seed 11 --save-data bin_sim
friedman predict choice logit bin_sim --dep y --cov-type hc1 --marginal-effects --classification-table
```
```text
                      Average Marginal Effects (Logit)
┌──────┬──────────┬───────────┬────────┬───────────┬────────────┬──────────┐
│ term │ estimate │ std_error │  stat  │  p_value  │  ci_lower  │ ci_upper │
├──────┼──────────┼───────────┼────────┼───────────┼────────────┼──────────┤
│  x2  │ 0.056878 │ 0.0279252 │ 2.0368 │ 0.0416704 │ 0.00214558 │ 0.11161  │
└──────┴──────────┴───────────┴────────┴───────────┴────────────┴──────────┘
```

The command produces predicted probabilities (`logit_fitted_probabilities`), average marginal effects (`average_marginal_effects_logit`, here `x2 = 0.056878`, `p = 0.0416704`), classification accuracy (`classification_metrics`, `confusion_matrix`), and optional odds ratios (`--odds-ratio`).

---

## Binary & Ordinal Models (`logit`, `probit`, `ologit`, `oprobit`)

Binary response models parameterize choice probability $P(y_i = 1 \mid x_i) = F(x_i'\beta)$ via logistic ($F = \Lambda$) or normal ($F = \Phi$) cumulative links, whereas ordinal models partition a latent index $y_i^* = x_i'\beta + u_i$ across ordered cutpoints $\alpha_1 < \dots < \alpha_{J-1}$:

```math
P(y_i = j \mid x_i) = F(\alpha_j - x_i'\beta) - F(\alpha_{j-1} - x_i'\beta), \qquad j \in \{1, \dots, J\}.
```

- **Binary ([`logit`](@ref ref-estimate-choice-logit), [`probit`](@ref ref-estimate-choice-probit)):** Supports `ols`, `hc0`–`hc3`, and `cluster` standard errors (`--clusters`); [`predict choice`](@ref ref-fam-predict-choice) computes average marginal effects (`--marginal-effects`) and confusion tables (`--classification-table` at `--threshold 0.5`).
- **Ordinal ([`ologit`](@ref ref-estimate-choice-ologit), [`oprobit`](@ref ref-estimate-choice-oprobit)):** Outputs `ordered_*_coefficients`, estimated `cutpoints`, and `fit_statistics`. Under `ologit`, verify the proportional-odds / parallel-regressions restriction across outcome thresholds with [`test brant`](@ref ref-test-brant), and request generalized residuals via `--generalized` on [`residuals choice ologit`](@ref ref-residuals-choice-ologit).

<!-- capture -->
```bash
friedman --quiet data simulate cross-section --kind ordered --n 200 --seed 17 --save-data ord_sim
friedman estimate choice ologit ord_sim --dep y --cov-type hc1
```
```text
       Cutpoints
┌──────────┬───────────┐
│ Cutpoint │   Value   │
├──────────┼───────────┤
│   cut1   │ -1.69797  │
│   cut2   │ -0.308124 │
│   cut3   │  1.32528  │
└──────────┴───────────┘
                                 Ordered Logit Coefficients
┌──────────┬──────┬───────────┬───────────┬──────────┬─────────────┬───────────┬───────────┐
│  block   │ term │ estimate  │ std_error │   stat   │   p_value   │ ci_lower  │ ci_upper  │
├──────────┼──────┼───────────┼───────────┼──────────┼─────────────┼───────────┼───────────┤
│   coef   │  x1  │ 0.680818  │ 0.110363  │ 6.16891  │ 6.87609e-10 │ 0.464511  │ 0.897126  │
│   coef   │  x2  │  1.16801  │ 0.165612  │  7.0527  │ 1.75482e-12 │ 0.843416  │  1.4926   │
│ cutpoint │ cut1 │ -1.69797  │ 0.162727  │ -10.4345 │     0.0     │ -2.01691  │ -1.37903  │
│ cutpoint │ cut2 │ -0.308124 │ 0.103522  │ -2.9764  │ 0.00291654  │ -0.511025 │ -0.105224 │
│ cutpoint │ cut3 │  1.32528  │ 0.131603  │ 10.0702  │     0.0     │  1.06734  │  1.58321  │
└──────────┴──────┴───────────┴───────────┴──────────┴─────────────┴───────────┴───────────┘
       Fit Statistics
┌────────────────┬──────────┐
│     metric     │  value   │
├────────────────┼──────────┤
│   Pseudo R2    │ 0.117169 │
│ Log-likelihood │ -232.635 │
│      AIC       │  475.27  │
│      BIC       │ 491.762  │
│   Categories   │    4     │
└────────────────┴──────────┘
```

Notice `ordered_logit_coefficients` reports latent index slopes (`x1 = 0.680818`, `x2 = 1.16801`) alongside monotonically increasing `cutpoints` (`-1.69797`, `-0.308124`, `1.32528`) and log-likelihood `-232.635` / pseudo-$R^2$ `0.117169` in `fit_statistics`.

---

## Multinomial Choice & Count Models (`mlogit`, `poisson`, `nbreg`)

When categories are unordered ($j \in \{1, \dots, J\}$) or outcomes are non-negative counts ($y_i \in \{0, 1, 2, \dots\}$):

```math
P(y_i = j \mid x_i) = \frac{\exp(x_i'\beta_j)}{1 + \sum_{m=2}^J \exp(x_i'\beta_m)}, \qquad \mathbb{E}[y_i \mid x_i] = \exp(x_i'\beta + \ln E_i).
```

- **Multinomial Logit ([`estimate choice mlogit`](@ref ref-estimate-choice-mlogit)):** Estimates alternative-varying slope vectors relative to the base category (`multinomial_logit_coefficients`); test independence of irrelevant alternatives (IIA) via [`test hausman-iia`](@ref ref-test-hausman-iia) (`--omit-category`).
- **Count Regression ([`poisson`](@ref ref-estimate-choice-poisson), [`nbreg`](@ref ref-estimate-choice-nbreg)):** Support optional `--offset` or `--exposure` controls and exponentiated incidence rate ratios (`--irr`). Test equidispersion ($\mathrm{Var}(y \mid x) = \mathbb{E}[y \mid x]$) via Cameron–Trivedi [`test dispersion`](@ref ref-test-dispersion) before choosing Poisson over Negative Binomial (`overdispersion_parameter`).

---

## Censoring, Truncation, Selection & Stepwise (`tobit`, `truncreg`, `heckman`, `select`)

When sample observability depends on outcome thresholds or selection rules, linear OLS is attenuated and biased:

- **Censored & Truncated MLE ([`tobit`](@ref ref-estimate-regression-tobit), [`truncreg`](@ref ref-estimate-regression-truncreg)):** Handle lower and/or upper limits (`--lower 0.0`, `--upper Inf`) differently depending on whether limit observations remain in the sample (Tobit) or are omitted entirely (truncated).
- **Heckman Selection ([`heckman`](@ref ref-estimate-regression-heckman)):** Models outcome `--dep` with `--outcome-vars` and selection indicator `--select` with `--select-vars` via two-step inverse Mills ratio adjustment or full-information MLE (`--method twostep|mle`), testing correlation $\rho = 0$ via $\lambda$ in `heckman_diagnostics`.
- **Automated Covariate Selection ([`select`](@ref ref-estimate-regression-select)):** Runs forward, backward, bidirectional, best-subset, or Hendry–Doornik `gets` general-to-specific search (`--keep` forces required controls).

<!-- capture -->
```bash
friedman --quiet data simulate cross-section --kind tobit --n 200 --seed 23 --save-data tob_sim
friedman estimate regression tobit tob_sim --dep y --lower 0.0
```
```text
                   Tobit Coefficients
┌───────────┬──────────┬───────────┬─────────┬─────────┐
│ parameter │ estimate │ std_error │ z_stat  │ p_value │
├───────────┼──────────┼───────────┼─────────┼─────────┤
│    x1     │ 0.88883  │ 0.081545  │ 10.8999 │   0.0   │
│    x2     │ 0.506189 │ 0.080424  │  6.294  │   0.0   │
└───────────┴──────────┴───────────┴─────────┴─────────┘
       Tobit Diagnostics
┌──────────────────┬──────────┐
│      metric      │  value   │
├──────────────────┼──────────┤
│      sigma       │ 1.10693  │
│      loglik      │ -276.908 │
│       aic        │ 559.816  │
│       bic        │ 569.711  │
│      lower       │   0.0    │
│      upper       │   Inf    │
│ n_censored_left  │    42    │
│ n_censored_right │    0     │
│    converged     │   true   │
└──────────────────┴──────────┘
```

The `tobit_coefficients` (`x1 = 0.88883`, `x2 = 0.506189`) and `tobit_diagnostics` (`sigma = 1.10693`, `n_censored_left = 42`) tables distinguish latent structural slopes and ancillary error scale $\sigma$ from censored observations at `0.0`.

---

## Common Pitfalls

1. **Ignoring perfect separation in small binary samples:** When a binary predictor perfectly separates `y = 0` from `y = 1`, `logit`/`probit` MLE coefficients diverge (`model/convergence`, exit `5`); inspect cross-tabulations or rescale covariates.
2. **Omitting `--select`, `--outcome-vars`, or `--select-vars` in `heckman`:** Without exclusion restrictions between `--select-vars` and `--outcome-vars`, two-step Heckman identification rests purely on nonlinearity of the inverse Mills ratio and exhibits severe collinearity.
3. **Confusing `poisson --cov-type robust` vs `nbreg`:** Quasi-MLE Poisson with `--cov-type robust` yields valid standard errors under overdispersion whenever the conditional mean is correctly specified, whereas [`nbreg`](@ref ref-estimate-choice-nbreg) explicitly parameterizes conditional variance via quadratic dispersion `alpha`.

---

## References

- McFadden, D. (1974). Conditional logit analysis of qualitative choice behavior. In *Frontiers in Econometrics* (pp. 105–142). Academic Press.
- Cameron, A. C., & Trivedi, P. K. (1990). Regression-based tests for overdispersion in the Poisson model. *Journal of Econometrics*, 46(3), 347–364.
- Heckman, J. J. (1979). Sample selection bias as a specification error. *Econometrica*, 47(1), 153–161.
- Upstream manual: [MacroEconometricModels.jl — Discrete Choice & Selection](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/discrete/)
- CLI reference: [`friedman estimate choice`](@ref ref-fam-estimate-choice), [`friedman predict choice`](@ref ref-fam-predict-choice), [`friedman residuals choice`](@ref ref-fam-residuals-choice), [`friedman test brant`](@ref ref-test-brant), [`friedman test dispersion`](@ref ref-test-dispersion)
