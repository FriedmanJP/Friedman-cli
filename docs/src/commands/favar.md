# favar & sdfm

Factor-Augmented VAR (FAVAR) and Structural Dynamic Factor Model (SDFM) commands. FAVAR spans the full analysis pipeline across `estimate`, `irf`, `fevd`, `hd`, `forecast`, `predict`, and `residuals`. SDFM covers `estimate`, `irf`, `fevd`, `hd`, and `forecast`.

Full option lists live in the generated reference ([estimate](generated/estimate.md),
[irf](generated/irf.md), [fevd](generated/fevd.md), [hd](generated/hd.md),
[forecast](generated/forecast.md), [predict](generated/predict.md),
[residuals](generated/residuals.md)).

---

## FAVAR

FAVAR (Bernanke, Boivin & Eliasz 2005) augments a standard VAR with latent factors extracted from a large panel of macroeconomic variables. A small number of **key variables** (e.g., the federal funds rate) enter the VAR directly alongside the extracted factors.

!!! note "Output labels carry the CSV column names"
    The CSV column names are threaded onto the estimated models, so output labels are
    real names rather than positions: `irf|fevd favar` and `forecast multivariate favar`
    label the key variables inside the augmented VAR by their column names
    (`F1, F2, infl, ffr` — previously the positional `X9`/`X10`), and `irf sdfm` labels
    every panel response by its column name (previously `Var 1`, `Var 2`, …).
    `fevd sdfm` decomposes in **factor space** and keeps its `Factor i` labels.
    `estimate factor dynamic` is unchanged — its upstream estimator accepts no variable
    names (its loadings table was already labelled CLI-side).

---

### estimate multivariate favar

Estimate a FAVAR model. Supports two-step (PCA + VAR) and Bayesian (joint MCMC) estimation. Omitting `--factors` auto-selects the count via information criteria. Fences run on the bundled Denmark money dataset (`:denmark`); each fence is standalone.

```bash
# Two-step estimation with 2 factors, key variables by name
friedman estimate multivariate favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1

# Key variables by 1-based column index (IBO, IDE are columns 4, 5)
friedman estimate multivariate favar :denmark --key-vars=4,5 --factors=2 --lags=1

# Bayesian joint estimation
friedman estimate multivariate favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --method=bayesian --draws=500
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto (IC) | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices (comma-separated) |
| `--method` | | String | `two_step` | `two_step`, `bayesian` |
| `--draws` | `-n` | Int | 5000 | MCMC draws (bayesian only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Coefficient matrix over factors and key variables (one row per equation ×
regressor) on the two-step route; a factor/key-variable/lag/draw estimation record on
the Bayesian route. Fit statistics (factor and key-variable counts, AIC/BIC) print as
status lines.

---

### irf favar

FAVAR impulse response functions. Identification routes through the shared VAR-family
map (`cholesky` default; `sign`, `narrative`, `longrun`, Uhlig, and statistical /
non-Gaussian methods with `--config` supplying the restrictions).

```bash
friedman irf favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=8

# Panel-wide IRFs (responses for all original variables)
friedman irf favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=8 --panel-irf
```

With sign restrictions (the matrix is square in the augmented-VAR dimension —
2 factors + 2 key variables, so 4×4):

```bash
cat > favar_signs.toml <<'EOF'
[identification]
method = "sign"
[identification.sign_matrix]
matrix = [
  [1, 0, 0, 0],
  [0, 1, 0, 0],
  [0, 0, 1, 0],
  [0, 0, 0, 1],
]
horizons = [0]
EOF
friedman irf favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=8 --id=sign --config=favar_signs.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices |
| `--horizons` | | Int | 20 | IRF horizon |
| `--id` | | String | `cholesky` | Identification method (shared VAR-family map) |
| `--config` | | String | | TOML config for identification restrictions |
| `--panel-irf` | | Flag | | Output panel-wide IRFs (N variables) instead of factor-level |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) — `irf(favar,...)`
delegates to the VAR representation, so every shock lands in one table (no shock
filter; FAVAR takes no `--shock`). With `--panel-irf`, `variable` covers all original
panel variables instead of factors + key variables.

---

### fevd favar

FAVAR forecast error variance decomposition.

```bash
friedman fevd favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=8
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices |
| `--horizons` | | Int | 20 | FEVD horizon |
| `--id` | | String | `cholesky` | Identification method (shared VAR-family map) |
| `--config` | | String | | TOML config for identification restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`) — `fevd(favar,...)` delegates
to the VAR representation, so every variable/shock pair lands in one table.

---

### hd favar

FAVAR historical decomposition.

```bash
friedman hd favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=8
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices |
| `--horizons` | | Int | 20 | HD horizon |
| `--id` | | String | `cholesky` | Identification method (shared VAR-family map) |
| `--config` | | String | | TOML config for identification restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable shock contribution tables + initial conditions.

---

### forecast multivariate favar

FAVAR forecasting with optional panel-wide output.

```bash
friedman forecast multivariate favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=4

# Panel-wide forecast (all original variables)
friedman forecast multivariate favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1 --horizons=4 --panel-forecast
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices |
| `--horizons` | | Int | 12 | Forecast horizon |
| `--panel-forecast` | | Flag | | Forecast all N panel variables (via factor loadings) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|value|lower|upper`). With `--panel-forecast`,
`variable` covers all original panel variables.

---

### predict multivariate favar

FAVAR in-sample fitted values.

```bash
friedman predict multivariate favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** In-sample fitted values for each variable.

---

### residuals multivariate favar

FAVAR model residuals.

```bash
friedman residuals multivariate favar :denmark --key-vars=IBO,IDE --factors=2 --lags=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | (required) | Key variable names or 1-based column indices |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Model residuals for each variable.

---

## Structural DFM

Structural Dynamic Factor Model (Forni et al. 2009) identifies structural shocks in a dynamic factor framework. `--id` takes `cholesky`, `sign`, `proxy` (external instrument), `lewis-tvv`, `sv-em`, or `gmm-moments`; `--id proxy` requires `--instrument`. The default estimator is FGLR (2009); `--method gdfm-var` restores the legacy GDFM-factor VAR path. Omitting `--factors` selects the dynamic rank automatically via `--q-method` (Hallin–Liška default; deterministic). A non-default `--q-method` together with explicit `--factors` is a usage error (selection never runs). `--bandwidth`/`--kernel` are estimation-only: only `estimate factor sdfm` takes them.

---

### estimate factor sdfm

Estimate a Structural DFM. Emits an estimation record (panel dimensions, factor
counts, identification, factor-VAR lags, shock names, average common variance share);
the structural arrays live on `irf sdfm` / `fevd sdfm`.

```bash
# Cholesky identification (default)
friedman estimate factor sdfm :denmark --factors=2

# Automatic factor selection via Bai–Ng (omit --factors to select)
friedman estimate factor sdfm :denmark --q-method=bai-ng

# Proxy identification with an external instrument column
friedman estimate factor sdfm :denmark --factors=2 --id=proxy --instrument=IBO

# Legacy estimator + legacy spectrum
friedman estimate factor sdfm :denmark --factors=2 --method=gdfm-var --spectral=smoothed-periodogram

# Custom bandwidth and kernel
friedman estimate factor sdfm :denmark --factors=2 --bandwidth=10 --kernel=parzen
```

With sign restrictions (rows cover the panel variables, columns the factor shocks):

```bash
cat > sdfm_signs.toml <<'EOF'
[identification]
method = "sign"
[identification.sign_matrix]
matrix = [
  [1, 0],
  [0, 1],
  [0, 0],
  [0, 0],
  [0, 0],
]
horizons = [0]
EOF
friedman estimate factor sdfm :denmark --factors=2 --id=sign --config=sdfm_signs.toml
```

Heteroskedasticity-based identification needs a longer panel than `:denmark`
(upstream requires at least 100 usable observations), so this fence simulates one
in-block first:

```bash
friedman data simulate factors --series 12 --periods 150 --seed 7 --format csv --output panel.csv
cat > lewis.toml <<'EOF'
[identification]
method = "lewis-tvv"
[identification.lewis_tvv]
weighting = "two_step"
EOF
friedman estimate factor sdfm panel.csv --factors=3 --id=lewis-tvv --config=lewis.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto (`--q-method`) | Number of dynamic factors |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `proxy`, `lewis-tvv`, `sv-em`, `gmm-moments` (`--id proxy` requires `--instrument`) |
| `--q-method` | | String | `hallin-liska` | Auto selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Estimator: `fglr`, `gdfm-var` (legacy) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizon` | | Int | 40 | Structural IRF horizon |
| `--config` | | String | | TOML config for sign restrictions (lewis-tvv/sv-em estimator knobs) |
| `--bandwidth` | | Int | 0 | Spectral bandwidth (0 = auto) |
| `--kernel` | | String | `bartlett` | `bartlett`, `parzen`, `quadratic_spectral` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Identification method, factor VAR lags, shock names.

---

### irf sdfm

Structural DFM impulse response functions. Outputs panel-wide responses (all original variables), computed on demand for the requested horizon; bootstrap bands come from the factor-VAR residual bootstrap.

```bash
friedman irf sdfm :denmark --factors=2 --horizons=8
friedman irf sdfm :denmark --factors=2 --horizons=8 --ci=bootstrap --reps=20
```

With sign restrictions (rows cover the panel variables, columns the factor shocks):

```bash
cat > sdfm_signs.toml <<'EOF'
[identification]
method = "sign"
[identification.sign_matrix]
matrix = [
  [1, 0],
  [0, 1],
  [0, 0],
  [0, 0],
  [0, 0],
]
horizons = [0]
EOF
friedman irf sdfm :denmark --factors=2 --horizons=8 --id=sign --config=sdfm_signs.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto (`--q-method`) | Number of dynamic factors |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `proxy`, `lewis-tvv`, `sv-em`, `gmm-moments` (`--id proxy` requires `--instrument`) |
| `--q-method` | | String | `hallin-liska` | Auto selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Estimator: `fglr`, `gdfm-var` (legacy) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizons` | | Int | 40 | IRF horizon |
| `--config` | | String | | TOML config for sign restrictions (lewis-tvv/sv-em estimator knobs) |
| `--ci` | | String | `none` | Bands: `none`, `bootstrap` |
| `--reps` | | Int | 200 | Bootstrap replications (with `--ci bootstrap`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) — `irf(sdfm,...)`
returns a panel-wide `ImpulseResponse` directly, so every shock/variable pair lands in
one table.

---

### fevd sdfm

Structural DFM forecast error variance decomposition (factor space, using the identification stored at estimation).

```bash
friedman fevd sdfm :denmark --factors=2 --horizons=8
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto (`--q-method`) | Number of dynamic factors |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `proxy`, `lewis-tvv`, `sv-em`, `gmm-moments` (`--id proxy` requires `--instrument`) |
| `--q-method` | | String | `hallin-liska` | Auto selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Estimator: `fglr`, `gdfm-var` (legacy) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizons` | | Int | 20 | FEVD horizon |
| `--config` | | String | | TOML config for sign restrictions (lewis-tvv/sv-em estimator knobs) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value`) — factor-space shocks, not panel-wide.

---

### hd sdfm

Structural DFM historical decomposition, in panel or factor space.

```bash
friedman hd sdfm :denmark --factors=2 --horizons=8
friedman hd sdfm :denmark --factors=2 --horizons=8 --space=factor
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto (`--q-method`) | Number of dynamic factors |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `proxy`, `lewis-tvv`, `sv-em`, `gmm-moments` (`--id proxy` requires `--instrument`) |
| `--q-method` | | String | `hallin-liska` | Auto selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Estimator: `fglr`, `gdfm-var` (legacy) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizons` | | Int | 20 | HD horizon (periods decomposed) |
| `--config` | | String | | TOML config for sign restrictions (lewis-tvv/sv-em estimator knobs) |
| `--space` | | String | `panel` | Decomposition space: `panel`, `factor` |
| `--no-idiosyncratic` | | Flag | | Drop the idiosyncratic column (panel space only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Per-variable shock contribution tables + initial conditions (one family
table per variable).

---

### forecast factor sdfm

Structural DFM panel forecasting.

```bash
friedman forecast factor sdfm :denmark --factors=2 --horizons=4
friedman forecast factor sdfm :denmark --factors=2 --horizons=4 --ci=bootstrap --reps=20
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto (`--q-method`) | Number of dynamic factors |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `proxy`, `lewis-tvv`, `sv-em`, `gmm-moments` (`--id proxy` requires `--instrument`) |
| `--q-method` | | String | `hallin-liska` | Auto selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Structural estimator: `fglr`, `gdfm-var` (legacy) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizons` | | Int | 12 | Forecast horizon |
| `--config` | | String | | TOML config for sign restrictions (lewis-tvv/sv-em estimator knobs) |
| `--ci` | | String | `none` | Intervals: `none`, `bootstrap` |
| `--reps` | | Int | 200 | Bootstrap replications (with `--ci bootstrap`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|value|lower|upper`).

---

## Key Concepts

### FAVAR vs Standard VAR

A standard VAR includes a small number of variables. FAVAR extracts latent factors from a large dataset (potentially hundreds of series) and includes them alongside key policy variables in the VAR. This allows:

- Information from a large cross-section without running into dimensionality issues
- Policy analysis (e.g., monetary policy shocks) while controlling for the broad state of the economy
- Panel-wide impulse responses: track how every series in the panel responds to structural shocks

---

### Two-Step vs Bayesian Estimation

- **Two-step** (default): Extract factors via PCA, then estimate the VAR on factors + key variables. Fast and straightforward.
- **Bayesian**: Joint estimation of factors and VAR parameters via MCMC. More coherent but computationally intensive.

---

### Panel-Wide Output

The `--panel-irf` and `--panel-forecast` flags map factor-space results back to the original variable space using the estimated factor loadings. This produces responses/forecasts for all N variables in the panel, not just the factors and key variables.

---

## References

- Bernanke, B. S., Boivin, J., & Eliasz, P. (2005). "Measuring the Effects of
  Monetary Policy: A Factor-Augmented Vector Autoregressive (FAVAR) Approach."
  *The Quarterly Journal of Economics*, 120(1), 387–422.
- Forni, M., Giannone, D., Lippi, M., & Reichlin, L. (2009). "Opening the Black Box:
  Structural Factor Models with Large Cross Sections." *Econometric Theory*, 25(5),
  1319–1347.
