# Ordered & Multinomial Choice Models

**Goal:** model an ordered rating or an unordered alternative choice, report **average marginal effects** on each category probability, and test the assumption that identifies the estimator. Full option tables live in the [generated estimate reference](generated/estimate.md); predict/residuals leaves are tabled in the [generated predict reference](generated/predict.md) and [generated residuals reference](generated/residuals.md). Test logic also sits in [test](test.md), which pairs back here.

---

## Estimation

| Command | Description |
|---------|-------------|
| `estimate choice ologit` | Ordered logit regression (slopes plus estimated category cutpoints) |
| `estimate choice oprobit` | Ordered probit regression (slopes plus estimated category cutpoints) |
| `estimate choice mlogit` | Multinomial logit regression (one coefficient vector per alternative) |

Reference: [generated estimate reference](generated/estimate.md).

---

## Diagnostics

| Command | Description |
|---------|-------------|
| `predict choice ologit/oprobit/mlogit` | Predicted probabilities (one `prob_<category>` column per category); `--marginal-effects` adds an AME table |
| `residuals choice ologit/oprobit/mlogit` | Per-category residuals (one `resid_<category>` column), `--kind response\|pearson\|deviance`; ordered models also take `--generalized` for the length-`n` score residual |

### Marginal effects (`--marginal-effects`)

`predict choice ologit|oprobit|mlogit --marginal-effects` emits a second, tidy table of
**average marginal effects** on each category probability — `variable | category |
dydx | se` — with delta-method standard errors.
Each variable's effects sum to zero across categories (probabilities sum to one), the
multinomial base category included. Neither family reports z/p/CIs, so
none are shown; on the multinomial model the SE column is omitted (with a stderr note)
when the model covariance is unavailable. With `--output`, the AME table goes to a
`_marginal_effects` sibling file so it never displaces the probability table.

```bash
# Simulate an ordered rating plus covariates, then report average marginal effects
friedman data simulate cross-section --kind ordered --n 500 --seed 7 --format csv --output choice.csv
friedman predict choice ologit choice.csv --dep y --marginal-effects
```

Reference: [generated predict reference](generated/predict.md).

---

## Tests

| Command | H0 | Rejection means |
|---------|----|-----------------|
| `test brant` | **proportional odds** (parallel regressions): the J−1 binary-logit slope vectors are equal. Ordered logit only; needs at least 3 categories | the ordered-logit assumption fails — re-specify (generalized or partial-proportional-odds form), do not just drop variables |
| `test hausman-iia` | **IIA** (Independence of Irrelevant Alternatives): dropping one alternative leaves the remaining coefficients unchanged. Takes `--omit-category` (required: the 1-based index of the alternative to drop); needs at least 3 remaining categories | IIA fails for the omitted alternative — points at nested or mixed logit |

Reference: [generated test reference](generated/test.md).

---

## Usage

```bash
# Simulate an ordered rating plus covariates, then estimate ordered logit
friedman data simulate cross-section --kind ordered --n 500 --seed 7 --format csv --output choice.csv
friedman estimate choice ologit choice.csv --dep y

# Brant parallel-regression test on the same file
friedman test brant choice.csv --dep y

# Simulate a three-alternative choice, then estimate multinomial logit
friedman data simulate cross-section --kind mlogit --n 500 --seed 7 --format csv --output mchoice.csv
friedman estimate choice mlogit mchoice.csv --dep y
```

The Hausman IIA test needs at least four alternatives (omitting one must leave
three for the restricted model), so the three-alternative simulation above
cannot feed it. On a file with four or more alternatives the call is
`friedman test hausman-iia <mchoice> --dep <choice-col> --omit-category 3`.

---

## References

Full option tables: [generated estimate reference](generated/estimate.md), [generated predict reference](generated/predict.md), [generated test reference](generated/test.md). Specification logic: [test](test.md).

Brant, R. (1990). Assessing proportionality in the proportional odds model for ordinal logistic regression. *Biometrics*.

Hausman, J. and McFadden, D. (1984). Specification tests for the multinomial logit model. *Econometrica*.
