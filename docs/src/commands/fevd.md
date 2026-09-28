# fevd

Compute **forecast error variance decomposition** (FEVD) across `var`, `bvar`, `lp`, `vecm`, `pvar`, `favar`, and `sdfm`. FEVD reports the share of each variable's forecast-error variance attributable to each structural shock at each horizon.

---
## Output format

`fevd var`, `vecm`, `favar`, and `sdfm` render through the tidy `long_table(result)`: one row per (`horizon`, `variable`, `shock`) cell with columns `horizon | variable | shock | value` (proportions in `[0, 1]`). `fevd bvar` (`BayesianFEVD`), `fevd lp` (`LPFEVD`), and `fevd pvar` (a raw array, not a result type) are not covered by `long_table` and stay on the older wide table (columns = shocks, rows = horizons). Stable envelope keys live in the generated reference.

---
## fevd var

Frequentist FEVD with configurable identification.

```bash
cat > sign_restrictions.toml <<'EOF'
[identification]
method = "sign"

[identification.sign_matrix]
matrix = [
  [1, 0, 0, 0, 0],
  [0, 1, 0, 0, 0],
  [0, 0, 1, 0, 0],
  [0, 0, 0, 1, 0],
  [0, 0, 0, 0, 1]
]
horizons = [0, 1]
EOF
friedman fevd var :denmark --horizons=20 --id=cholesky
friedman fevd var :denmark --id=sign --config=sign_restrictions.toml
friedman fevd var :denmark --horizons=20 --generalized
friedman fevd var :denmark --horizons=20 --generalized --normalize
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun`, `arias`, `uhlig`, `proxy`, `max-share`, `gmm-moments`, `narrative-adrr`, `lewis-tvv`, `sv-em` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--target-var` | | String | | Max-share target column name or 1-based index (only with `--id max-share`) |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |
| `--generalized` | | Flag | | Pesaran–Shin generalized FEVD (identification-free; shares do not sum to 1) |
| `--normalize` | | Flag | | Rescale generalized shares to sum to 1 per variable |

**Output:** Tidy table (`horizon|variable|shock|value`); `value` is the variance share in `[0, 1]` (Arias/Uhlig identification still builds its own wide table — no `FEVD` to route through `long_table`).

---
## fevd bvar

Bayesian FEVD with posterior mean proportions.

```bash
friedman fevd bvar :denmark --horizons=20
friedman fevd bvar :denmark --draws=5000 --sampler=gibbs
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 4 | Lag order |
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun` |
| `--draws` | `-n` | Int | 2000 | MCMC draws |
| `--sampler` | | String | `direct` | `direct`, `gibbs` |
| `--config` | | String | | TOML config for identification/prior |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Wide table (columns = shocks, rows = horizons) — `BayesianFEVD` is not covered by `long_table` yet.

---
## fevd lp

LP-based FEVD with bias-corrected proportions (Gorodnichenko & Lee 2019).

```bash
friedman fevd lp :denmark --horizons=20 --id=cholesky
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--lags` | `-p` | Int | 4 | LP control lags |
| `--var-lags` | | Int | same as `--lags` | VAR lag order for identification |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun` |
| `--vcov` | | String | `newey_west` | `newey_west`, `white`, `driscoll_kraay` |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Wide table (columns = shocks, rows = horizons) — `LPFEVD` is not covered by `long_table` yet.

---
## fevd vecm

VECM-based FEVD. The VECM converts to its VAR representation for decomposition.

```bash
friedman fevd vecm :denmark --horizons=20
friedman fevd vecm :denmark --rank=2 --deterministic=constant --lags=4
friedman fevd vecm :denmark --id=svec --rank=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order (in levels) |
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--rank` | `-r` | String | `auto` | Cointegration rank (auto via Johansen, or explicit) |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--id` | | String | `cholesky` | Identification method (`cholesky`, `sign`, `narrative`, `longrun`, `svec`, `lewis-tvv`, `sv-em`; `svec` accepts an optional `[svec]` config) |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`); VECM → VAR representation, same schema as `fevd var`.

---
## fevd pvar

Panel VAR forecast error variance decomposition.

```bash
friedman fevd pvar :grunfeld --id-col=group --time-col=time --horizons=10
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 1 | Lag order |
| `--horizons` | `-h` | Int | 10 | Forecast horizon |
| `--id-col` | | String | | Panel group identifier column |
| `--time-col` | | String | | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Wide, per-shock-file table (columns = variables, rows = horizons) — `pvar_fevd` returns a raw array, not a result type, so this leaf stays outside the `long_table` conversion.

---
## fevd favar

FAVAR forecast error variance decomposition.

```bash
friedman fevd favar :denmark --lags=2 --key-vars=LRM,LRY,LPY
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | | Key variable names or indices |
| `--horizons` | `-h` | Int | 20 | FEVD horizon |
| `--id` | | String | `cholesky` | Identification method |
| `--config` | | String | | TOML config for restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`).

---
## fevd sdfm

Structural DFM forecast error variance decomposition. Estimation shares the `estimate`/`irf`/`hd` SDFM surface (`--factors`, `--id`, `--q-method`, `--method`, `--spectral`, `--instrument`, `--var-lags`).

```bash
friedman fevd sdfm :denmark --factors=2 --horizons=20
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto | Number of dynamic factors (default: auto via `--q-method`) |
| `--id` | | String | `cholesky` | Identification at estimation |
| `--q-method` | | String | `hallin-liska` | Auto factor selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Estimator: `fglr`, `gdfm-var` (legacy path) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizons` | | Int | 20 | FEVD horizon |
| `--config` | | String | | TOML config for sign restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`) in factor space.

---
## Generalized FEVD (`--generalized`)

Pesaran–Shin generalized forecast error variance decomposition. It sidesteps identification entirely — each variable is shocked under the historical covariance rather than an orthogonalized one — so it is a flag rather than an `--id` value, and `--id`/`--config` are ignored when it is set.

```bash
friedman fevd var :denmark --horizons=20 --generalized
friedman fevd var :denmark --horizons=20 --generalized --normalize
```

!!! warning "Generalized shares do not sum to 1"
    This is the property that trips people up. The generalized shocks are **correlated**, so their contributions overlap and the shares for a given (horizon, variable) sum to something other than 1 — often greater. They are *not* an orthogonal decomposition and must not be read as "shock *j* explains *x*% of variable *i*".

    The advantage is invariance: unlike a Cholesky FEVD, the answer does not depend on the ordering of the variables, which is often arbitrary.

    `--normalize` rescales each variable's row to sum to 1. That makes the numbers readable as shares, but the rescaling is a convention, not a derivation — the overlap it hides is still there.

| Flag | Description |
|------|-------------|
| `--generalized` | Pesaran–Shin generalized FEVD (identification-free) |
| `--normalize` | Rescale shares to sum to 1 per variable |

---
## See Also

For impulse responses of the same shocks, see [irf](irf.md). For shock contributions over history, see [hd](hd.md). For DSGE model FEVD, see [dsge fevd](dsge.md#dsge-fevd).

---
## References

- Pesaran, H. H., & Shin, Y. (1998). Generalized impulse response analysis in linear multivariate models. *Economics Letters*.
- Gorodnichenko, Y., & Lee, B. (2019). Forecast error variance decompositions with local projections. *Journal of Monetary Economics*.
