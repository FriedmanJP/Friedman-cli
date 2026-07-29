# fevd

Compute forecast error variance decomposition. 7 subcommands: `var`, `bvar`, `lp`, `vecm`, `pvar`, `favar`, `sdfm`.

## Output format (C051)

`fevd var`, `vecm`, `favar`, and `sdfm` render through MEMs' tidy `long_table(result)`: one
row per `(horizon, variable, shock)` cell, columns `horizon | variable | shock | value`
(proportions in `[0, 1]`). `fevd bvar` (`BayesianFEVD`), `fevd lp` (`LPFEVD`), and
`fevd pvar` (a raw array, not a MEMs result type) aren't covered by `long_table` and stay
on the older wide table (columns = shocks, rows = horizons).

## fevd var

Frequentist FEVD with configurable identification.

```bash
friedman fevd var data.csv --horizons=20 --id=cholesky
friedman fevd var data.csv --id=sign --config=sign_restrictions.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun`, `arias`, `uhlig` |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`); `value` is the variance share in `[0, 1]` (Arias/Uhlig identification still builds its own wide table — no MEMs `FEVD` to route through `long_table`).

## fevd bvar

Bayesian FEVD with posterior mean proportions.

```bash
friedman fevd bvar data.csv --horizons=20
friedman fevd bvar data.csv --draws=5000 --sampler=gibbs
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

**Output:** Wide table (columns = shocks, rows = horizons) — `BayesianFEVD` isn't covered by `long_table` yet.

## fevd lp

LP-based FEVD with bias-corrected proportions (Gorodnichenko & Lee 2019).

```bash
friedman fevd lp data.csv --horizons=20 --id=cholesky
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

**Output:** Wide table (columns = shocks, rows = horizons) — `LPFEVD` isn't covered by `long_table` yet.

## fevd vecm

VECM-based FEVD. The VECM is converted to its VAR representation for decomposition.

```bash
friedman fevd vecm data.csv --horizons=20
friedman fevd vecm data.csv --rank=2 --deterministic=constant --lags=4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--rank` | `-r` | Int | auto | Cointegration rank (auto via Johansen) |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--id` | | String | `cholesky` | Identification method |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`); VECM → VAR representation, same schema as `fevd var`.

## fevd pvar

Panel VAR forecast error variance decomposition.

```bash
friedman fevd pvar data.csv --id-col=country --time-col=year --horizons=20
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--horizons` | `-h` | Int | 20 | Forecast horizon |
| `--id-col` | | String | | Panel group identifier column |
| `--time-col` | | String | | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Wide, per-shock-file table (columns = variables, rows = horizons) — `pvar_fevd` returns a raw array, not a MEMs result type, so this leaf stays outside the `long_table` conversion.

## See Also

For DSGE model FEVD, see [dsge fevd](dsge.md#dsge-fevd).
