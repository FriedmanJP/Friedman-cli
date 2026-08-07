# Ordered & Multinomial Choice Models

## Estimation

| Command | Description |
|---------|-------------|
| `estimate ologit` | Ordered logit regression |
| `estimate oprobit` | Ordered probit regression |
| `estimate mlogit` | Multinomial logit regression |

## Diagnostics

| Command | Description |
|---------|-------------|
| `predict ologit/oprobit/mlogit` | Predicted probabilities (one `prob_<category>` column per category); `--marginal-effects` adds an AME table |
| `residuals ologit/oprobit/mlogit` | Per-category residuals (one `resid_<category>` column), `--kind response\|pearson\|deviance`; ordered models also take `--generalized` for the length-`n` score residual |

### Marginal effects (`--marginal-effects`, v0.9.2)

`predict ologit|oprobit|mlogit --marginal-effects` emits a second, tidy table of
**average marginal effects** on each category probability — `variable | category |
dydx | se` — with delta-method standard errors (available upstream since MEMs#550).
Each variable's effects sum to zero across categories (probabilities sum to one), the
multinomial base category included. Upstream reports no z/p/CIs for these models, so
none are shown; on the multinomial model the SE column is omitted (with a stderr note)
if the model covariance is unavailable. With `--output`, the AME table goes to a
`_marginal_effects` sibling file so it never displaces the probability table.

```bash
friedman predict ologit data.csv --dep satisfaction --marginal-effects
```

The flag had been removed in v0.9.0 (#85) because neither the handlers nor upstream
supported it — it returned WITH handler support once upstream shipped the SEs.

## Tests

| Command | Description |
|---------|-------------|
| `test brant` | Brant test for parallel regression assumption (ordered models) |
| `test hausman-iia` | Hausman-McFadden IIA test (multinomial logit) |

## Usage

```bash
# Ordered logit
friedman estimate ologit data.csv --dep satisfaction

# Brant test
friedman test brant data.csv --dep satisfaction

# Multinomial logit
friedman estimate mlogit data.csv --dep choice

# Hausman IIA test
friedman test hausman-iia data.csv --dep choice --omit-category 3
```
