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
| `predict ologit/oprobit/mlogit` | Predicted probabilities (one `prob_<category>` column per category) |
| `residuals ologit/oprobit/mlogit` | Per-category residuals (one `resid_<category>` column), `--kind response\|pearson\|deviance`; ordered models also take `--generalized` for the length-`n` score residual |

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
