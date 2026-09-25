# hd

Compute historical decomposition of shocks across `var`, `bvar`, `lp`, `vecm`, `favar`, and `sdfm`.

Historical decomposition decomposes observed data into contributions from each structural shock plus initial conditions.

## hd var

Frequentist historical decomposition.

```bash
friedman hd var data.csv --id=cholesky
friedman hd var data.csv --id=longrun --lags=4
friedman hd var data.csv --id=sign --config=sign_restrictions.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun`, `arias`, `uhlig`, `narrative-adrr` |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable table with columns: period, actual value, initial conditions, contribution from each shock. Includes decomposition verification.

## hd bvar

Bayesian historical decomposition with posterior mean contributions.

```bash
friedman hd bvar data.csv --draws=2000
friedman hd bvar data.csv --id=sign --config=sign_restrictions.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 4 | Lag order |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun` |
| `--draws` | `-n` | Int | 2000 | MCMC draws |
| `--sampler` | | String | `direct` | `direct`, `gibbs` |
| `--config` | | String | | TOML config for identification/prior |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

## hd lp

Historical decomposition via structural local projections.

```bash
friedman hd lp data.csv --id=cholesky
friedman hd lp data.csv --id=sign --config=sign_restrictions.toml --vcov=white
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 4 | LP control lags |
| `--var-lags` | | Int | same as `--lags` | VAR lag order for identification |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun` |
| `--vcov` | | String | `newey_west` | `newey_west`, `white`, `driscoll_kraay` |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

## hd vecm

Historical decomposition for Vector Error Correction Models. The VECM is converted to its VAR representation for decomposition.

```bash
friedman hd vecm data.csv --id=cholesky
friedman hd vecm data.csv --rank=2 --deterministic=constant --lags=4
friedman hd vecm data.csv --id=svec --rank=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--rank` | `-r` | Int | auto | Cointegration rank (auto via Johansen) |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--id` | | String | `cholesky` | Identification method (`cholesky`, `sign`, `narrative`, `longrun`, `svec`; `svec` accepts an optional `[svec]` config) |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable table with columns: period, actual value, initial conditions, contribution from each shock.

## hd favar

FAVAR historical decomposition (factor-augmented VAR).

```bash
friedman hd favar data.csv --lags=2 --key-vars=GDP,CPI,FFR
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | | Key variable names or indices |
| `--horizons` | `-h` | Int | 20 | HD horizon |
| `--id` | | String | `cholesky` | Identification method |
| `--config` | | String | | TOML config for restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

## hd sdfm

Structural DFM historical decomposition. Estimation shares the `estimate`/`irf`/`fevd` SDFM surface (`--factors`, `--id`, `--q-method`, `--method`, `--spectral`, `--instrument`, `--var-lags`); decomposition uses the identification stored at estimation. `--space panel` (default) decomposes the N panel variables into q structural shocks plus an idiosyncratic column; `--space factor` decomposes the q factors (no idiosyncratic column, so `--no-idiosyncratic` is rejected there).

```bash
friedman hd sdfm data.csv --factors=2 --horizons=20
friedman hd sdfm data.csv --factors=2 --space=factor
friedman hd sdfm data.csv --factors=2 --no-idiosyncratic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto | Number of dynamic factors |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--id` | | String | `cholesky` | Identification at estimation |
| `--method` | | String | `fglr` | `fglr`, `gdfm-var` |
| `--spectral` | | String | `lag-window` | `lag-window`, `smoothed-periodogram` |
| `--q-method` | | String | `hallin-liska` | Auto factor selection |
| `--instrument` | | String | | Proxy-instrument column (only with `--id proxy`) |
| `--horizons` | | Int | 20 | HD horizon (periods decomposed) |
| `--space` | | String | `panel` | `panel`, `factor` |
| `--no-idiosyncratic` | | Flag | | Drop the idiosyncratic column (panel space only) |
| `--config` | | String | | TOML config for sign restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable table with columns: period, actual value, initial conditions, contribution from each shock (plus `contrib_Idiosyncratic` in panel space unless `--no-idiosyncratic`). Includes decomposition verification.

## Coverage audit (re-audited at MEMs 1.0.0)

| Leaf | Status | Reason |
|------|--------|--------|
| `hd pvar` | **Not shipped** | MEMs `historical_decomposition` still has no method for `PVARModel` at 1.0.0 (only the private `_pvar_fevd_decomp` FEVD helper) |
| `hd sdfm` | **Shipped** | `historical_decomposition(::StructuralDFM)` wrapped with `--space panel\|factor` and `--no-idiosyncratic` |

When upstream adds a method, ship the leaf as a rider. Do not invent CLI wrappers over unsupported APIs.
