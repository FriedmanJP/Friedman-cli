# Structural Break Tests

Tests for breaks in the coefficients of a linear regression, under `test stability`. Both leaves regress the `--response` column on an intercept plus all remaining numeric columns and test the stability of that projection. Full option tables live in the generated reference (`generated/test.md`). Examples use the shipped `:stackloss` dataset (stack loss with three regressors), so every fence runs standalone.

---

## test stability andrews

The **Andrews test** for a single unknown break point. **H0**: no structural break (constant coefficients over the whole sample). **H1**: a single break at an unknown date. The leaf computes the Wald, LR, or LM statistic at every candidate break date inside the trimmed sample and aggregates them: the **sup** variants (Andrews 1993) take the maximum, the **exp** and **mean** variants (Andrews & Ploberger 1994) take the exponential average and the simple average.

```bash
friedman test stability andrews :stackloss --response=1 --test=supwald
friedman test stability andrews :stackloss --response=2 --test=explr --trimming=0.20
friedman test stability andrews :stackloss --response=1 --test=meanlm
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--response` | | Int | 1 | Response variable column index (1-based) |
| `--test` | | String | `supwald` | Test type (see below) |
| `--trimming` | | Float64 | 0.15 | Trimming proportion (fraction of endpoints excluded) |

### Test Types

| Value | Description |
|-------|-------------|
| `supwald` | Supremum Wald statistic |
| `suplr` | Supremum LR statistic |
| `suplm` | Supremum LM statistic |
| `expwald` | Exponential Wald statistic |
| `explr` | Exponential LR statistic |
| `explm` | Exponential LM statistic |
| `meanwald` | Mean Wald statistic |
| `meanlr` | Mean LR statistic |
| `meanlm` | Mean LM statistic |

Rejection locates the break at the date maximizing the underlying sequence; the output reports the statistic, the $p$-value, and that break index. `--trimming` excludes that fraction of the sample from each end so the candidate dates stay away from the endpoints.

---

## test stability bai-perron

The **Bai-Perron test** for multiple unknown break points. It estimates the number of breaks (from zero up to `--max-breaks`) and their locations by global least-squares segmentation, selecting the count with `--criterion`: `bic` (the Bayesian information criterion) or `lwz` (the Liu-Wu-Zidek modified criterion, which penalizes extra breaks more heavily).

```bash
friedman test stability bai-perron :stackloss --response=1 --max-breaks=5
friedman test stability bai-perron :stackloss --response=2 --max-breaks=3 --criterion=lwz
friedman test stability bai-perron :stackloss --response=1 --trimming=0.20
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--response` | | Int | 1 | Response variable column index (1-based) |
| `--max-breaks` | | Int | 5 | Maximum number of breaks to test |
| `--trimming` | | Float64 | 0.15 | Trimming proportion (minimum regime length as a fraction of $T$) |
| `--criterion` | | String | `bic` | `bic`, `lwz` (Liu-Wu-Zidek) |

The output reports the estimated number of breaks, the break dates, and the coefficient vector of each regime on stderr. Start from Andrews when one break is suspected and move to Bai-Perron when the data may contain several regimes.

---

## References

- Andrews, D. W. K. (1993). "Tests for Parameter Instability and Structural Change with Unknown Change Point." *Econometrica*, 61(4), 821--856.
- Andrews, D. W. K., & Ploberger, W. (1994). "Optimal Tests When a Nuisance Parameter Is Present Only Under the Alternative." *Econometrica*, 62(6), 1383--1414.
- Bai, J., & Perron, P. (1998). "Estimating and Testing Linear Models with Multiple Structural Changes." *Econometrica*, 66(1), 47--78.
- Bai, J., & Perron, P. (2003). "Computation and Analysis of Multiple Structural Change Models." *Journal of Applied Econometrics*, 18(1), 1--22.
