# hd

Compute **historical decomposition** (HD) of shocks across `var`, `bvar`, `lp`, `vecm`, `favar`, and `sdfm`. Historical decomposition splits each observed series into contributions from each structural shock plus initial conditions.

---
## Output format

Every `hd` leaf emits one table per variable (a `family` table set): columns `period | actual | initial | contrib_<shock>…`, one shock-contribution column per structural shock. Each table carries a decomposition check — contributions plus initial conditions reconstruct the observed series. Stable envelope keys live in the generated reference.

---
## hd var

Frequentist historical decomposition.

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
friedman hd var :denmark --id=cholesky
friedman hd var :denmark --id=longrun --lags=4
friedman hd var :denmark --id=sign --config=sign_restrictions.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun`, `arias`, `uhlig`, `proxy`, `max-share`, `gmm-moments`, `narrative-adrr`, `lewis-tvv`, `sv-em` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--target-var` | | String | | Max-share target column name or 1-based index (only with `--id max-share`) |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable table with columns: period, actual value, initial conditions, contribution from each shock. Includes decomposition verification.

---
## hd bvar

Bayesian historical decomposition with posterior mean contributions.

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
friedman hd bvar :denmark --draws=2000
friedman hd bvar :denmark --id=sign --config=sign_restrictions.toml
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

---
## hd lp

Historical decomposition via structural local projections.

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
friedman hd lp :denmark --id=cholesky
friedman hd lp :denmark --id=sign --config=sign_restrictions.toml --vcov=white
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

---
## hd vecm

Historical decomposition for Vector Error Correction Models. The VECM converts to its VAR representation for decomposition.

```bash
friedman hd vecm :denmark --id=cholesky
friedman hd vecm :denmark --rank=2 --deterministic=constant --lags=4
friedman hd vecm :denmark --id=svec --rank=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order (in levels) |
| `--rank` | `-r` | String | `auto` | Cointegration rank (auto via Johansen, or explicit) |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--id` | | String | `cholesky` | Identification method (`cholesky`, `sign`, `narrative`, `longrun`, `svec`, `lewis-tvv`, `sv-em`; `svec` accepts an optional `[svec]` config) |
| `--config` | | String | | TOML config for identification |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable table with columns: period, actual value, initial conditions, contribution from each shock.

---
## hd favar

FAVAR historical decomposition (factor-augmented VAR).

```bash
friedman hd favar :denmark --lags=2 --key-vars=LRM,LRY,LPY
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

---
## hd sdfm

Structural DFM historical decomposition. Estimation shares the `estimate`/`irf`/`fevd` SDFM surface (`--factors`, `--id`, `--q-method`, `--method`, `--spectral`, `--instrument`, `--var-lags`); decomposition uses the identification stored at estimation. `--space panel` (default) decomposes the N panel variables into q structural shocks plus an idiosyncratic column; `--space factor` decomposes the q factors (no idiosyncratic column, so `--no-idiosyncratic` is rejected there).

```bash
friedman hd sdfm :denmark --factors=2 --horizons=20
friedman hd sdfm :denmark --factors=2 --space=factor
friedman hd sdfm :denmark --factors=2 --no-idiosyncratic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto | Number of dynamic factors (default: auto via `--q-method`) |
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

---
## Coverage

Verified against the resolved MEMs copy (`src/core/hd.jl`, `src/vecm/analysis.jl`, `src/favar/analysis.jl`): `historical_decomposition` ships for VAR, BVAR posteriors, structural LP, VECM, FAVAR, structural DFM, and DSGE solutions (linear, perturbation, Bayesian) — every `hd` leaf above wraps a real upstream method.

| Leaf | Status | Reason |
|------|--------|--------|
| `hd pvar` | **Not shipped** | MEMs `historical_decomposition` still has no method for `PVARModel` (only the private `_pvar_fevd_decomp` FEVD helper) |
| `hd sdfm` | **Shipped** | `historical_decomposition(::StructuralDFM)` wrapped with `--space panel\|factor` and `--no-idiosyncratic` |

When upstream adds a method, ship the leaf as a rider. Do not invent CLI wrappers over unsupported APIs.

---
## See Also

For impulse responses of the same shocks, see [irf](irf.md). For variance shares of the same shocks, see [fevd](fevd.md). For DSGE model HD, see [dsge hd](dsge.md#dsge-hd).

---
## References

- Burbidge, J., & Harrison, A. (1985). An historical decomposition of the great depression to determine the role of money. *Journal of Monetary Economics*.
