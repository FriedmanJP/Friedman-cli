# irf

Compute **impulse response functions** (IRFs) across `var`, `bvar`, `tvpvar`, `lp`, `vecm`, `pvar`, `favar`, and `sdfm`. An IRF traces the dynamic response of every variable to a one-time structural shock.

---
## Output format

`irf var`, `bvar`, `tvpvar`, `lp`, `vecm`, `favar`, and `sdfm` render through the tidy `long_table(result)`: one row per (`horizon`, `variable`, `shock`) cell with columns `horizon | variable | shock | value | lower | upper`. `lower`/`upper` are `missing` when the result carries no uncertainty band (for example `--ci=none`). `var`/`bvar`/`tvpvar`/`vecm` filter the tidy rows to the single selected `--shock`; `lp` filters to every shock named by `--shock`/`--shocks`; `favar`/`sdfm` take no shock filter and return every shock in one table. `irf pvar` and the Arias/Uhlig/sign-restriction paths build their arrays by hand and stay on the older wide, per-shock-file layout. Stable envelope keys live in the generated reference.

---
## irf var

Frequentist IRFs with multiple identification schemes and confidence intervals.

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
cat > narrative.toml <<'EOF'
[identification]
method = "narrative"

[identification.sign_matrix]
matrix = [
  [1, 0, 0, 0, 0],
  [0, 1, 0, 0, 0],
  [0, 0, 1, 0, 0],
  [0, 0, 0, 1, 0],
  [0, 0, 0, 0, 1]
]
horizons = [0]

[identification.narrative]
shock_index = 1
periods = [10, 15, 20]
signs = [1, -1, 1]
EOF
cat > arias_restrictions.toml <<'EOF'
[[identification.zero_restrictions]]
var = 1
shock = 1
horizon = 0

[[identification.sign_restrictions]]
var = 2
shock = 1
sign = "positive"
horizon = 0
EOF
cat > adrr_restrictions.toml <<'EOF'
[[identification.sign_restrictions]]
var = 2
shock = 1
sign = "positive"
horizon = 0

[[identification.narrative_contributions]]
variable = 1
shock = 1
window = [1, 4]
kind = "most_important"
EOF
friedman irf var :denmark --shock=1 --horizons=20
friedman irf var :denmark --id=sign --config=sign_restrictions.toml
friedman irf var :denmark --id=narrative --config=narrative.toml
friedman irf var :denmark --id=longrun --horizons=40
friedman irf var :denmark --id=arias --config=arias_restrictions.toml
friedman irf var :denmark --id=narrative-adrr --config=adrr_restrictions.toml
friedman irf var :denmark --id=fastica
friedman irf var :denmark --shock=1 --ci=bootstrap --replications=1000
friedman irf var :denmark --ci=bootstrap --bootstrap=wild --wild-dist=mammen
friedman irf var :denmark --ci=bootstrap --bootstrap=block --block-length=12
friedman irf var :denmark --ci=bootstrap --bias-correct --bias-reps=250
friedman irf var :denmark --shock=1 --cumulative
friedman irf var :denmark --id=sign --config=sign_restrictions.toml --identified-set
friedman irf var :denmark --id=sign --config=sign_restrictions.toml --identified-set --summary=median-target
friedman irf var :denmark --shock=1 --ci=bootstrap --stationary-only
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--id` | | String | `cholesky` | Identification method (see below) |
| `--ci` | | String | `bootstrap` | `none`, `bootstrap`, `theoretical` |
| `--replications` | | Int | 1000 | Bootstrap replications |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--target-var` | | String | | Max-share target column name or 1-based index (only with `--id max-share`) |
| `--config` | | String | | TOML config for identification restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |
| `--cumulative` | | Flag | | Compute cumulative IRFs (for differenced data) |
| `--identified-set` | | Flag | | Return full identified set (sign restrictions only) |
| `--summary` | | String | `none` | Set-identified summary: `median-target`, `modal-model`, `joint-band`, `sup-t-band` (only with `--identified-set`) |
| `--stationary-only` | | Flag | | Filter non-stationary bootstrap draws |
| `--bias-correct` | | Flag | | Kilian (1998) bias-corrected bands |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) filtered to `--shock` (the Arias/Uhlig/`--identified-set` paths stay wide).

---
## irf bvar

Bayesian IRFs with 68% credible intervals (16th/50th/84th percentiles).

```bash
cat > prior.toml <<'EOF'
[prior]
type = "minnesota"

[prior.hyperparameters]
lambda1 = 0.2
lambda2 = 0.5
lambda3 = 1.0
EOF
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
cat > bvar_restrictions.toml <<'EOF'
[prior]
type = "minnesota"

[prior.hyperparameters]
lambda1 = 0.2
lambda2 = 0.5
lambda3 = 1.0

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
friedman irf bvar :denmark --shock=1 --horizons=20
friedman irf bvar :denmark --draws=5000 --sampler=gibbs --config=prior.toml
friedman irf bvar :denmark --id=sign --config=sign_restrictions.toml
friedman irf bvar :denmark --id=robust-bayes --config=bvar_restrictions.toml
friedman irf bvar :denmark --shock=1 --cumulative
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 4 | Lag order |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun`, `robust-bayes` (Giacomini–Kitagawa bands; config must carry both `[prior]` and `[identification]`) |
| `--draws` | `-n` | Int | 2000 | MCMC draws |
| `--sampler` | | String | `direct` | `direct`, `gibbs` |
| `--config` | | String | | TOML config for identification/prior |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |
| `--cumulative` | | Flag | | Compute cumulative IRFs (for differenced data) |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`), filtered to `--shock`; `value` is the posterior mean, `lower`/`upper` the 16th/84th percentile credible band.

---
## irf tvpvar

Date-specific IRF from a TVP-VAR-SV. Responses are evaluated at one point in the sample, so `--date` is required.

```bash
friedman irf tvpvar :denmark --date=40 --shock=1 --horizons=20
friedman irf tvpvar :denmark --date=40 --no-sv
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--date` | | Int | required | Date index in 1:T_eff to evaluate the IRF at |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--lags` | `-p` | Int | 2 | Lag order |
| `--draws` | `-n` | Int | 2000 | Retained Gibbs draws |
| `--burnin` | | Int | 1000 | Burn-in sweeps discarded |
| `--thin` | | Int | 1 | Keep every k-th draw |
| `--n-train` | | Int | 0 | Training sample used to calibrate priors |
| `--k-q` | | Float64 | 0.01 | Coefficient random-walk prior scale (> 0) |
| `--k-s` | | Float64 | 0.1 | Covariance random-walk prior scale (> 0) |
| `--k-w` | | Float64 | 0.01 | Log-volatility random-walk prior scale (> 0) |
| `--irf-draws` | | Int | 500 | Posterior draws used for the IRF bands |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--no-tvp` | | Flag | | Hold coefficients constant |
| `--no-sv` | | Flag | | Hold volatilities constant |
| `--no-stationary-only` | | Flag | | Include explosive draws instead of discarding them |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) with 68% credible bands at the selected date.

---
## irf lp

Structural LP impulse response functions. Supports multi-shock analysis.

```bash
friedman irf lp :denmark --id=cholesky --shock=1 --horizons=20
friedman irf lp :denmark --shocks=1,2,3 --id=cholesky --horizons=30
friedman irf lp :denmark --id=cholesky --ci=bootstrap --replications=500
friedman irf lp :denmark --id=cholesky --shock=1 --cumulative
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--shock` | | Int | 1 | Single shock index (1-based) |
| `--shocks` | | String | | Comma-separated shock indices (e.g. `1,2,3`) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--lags` | `-p` | Int | 4 | LP control lags |
| `--var-lags` | | Int | same as `--lags` | VAR lag order for identification |
| `--id` | | String | `cholesky` | `cholesky`, `sign`, `narrative`, `longrun` |
| `--ci` | | String | `none` | `none`, `bootstrap` |
| `--replications` | | Int | 200 | Bootstrap replications |
| `--conf-level` | | Float64 | 0.95 | Confidence level |
| `--vcov` | | String | `newey_west` | `newey_west`, `white`, `driscoll_kraay` |
| `--config` | | String | | TOML config for sign/narrative restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |
| `--cumulative` | | Flag | | Compute cumulative IRFs (for differenced data) |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) filtered to every shock named by `--shock`/`--shocks` — one table even with multiple shocks selected.

---
## irf vecm

IRFs for Vector Error Correction Models. The VECM converts to its VAR representation, then IRFs are computed.

```bash
friedman irf vecm :denmark --shock=1 --horizons=20
friedman irf vecm :denmark --rank=2 --deterministic=constant --lags=4
friedman irf vecm :denmark --id=cholesky --ci=bootstrap --replications=500
friedman irf vecm :denmark --id=svec --ci=none --rank=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order (in levels) |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--rank` | `-r` | String | `auto` | Cointegration rank (auto via Johansen, or explicit) |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--id` | | String | `cholesky` | Identification method (`cholesky`, `sign`, `narrative`, `longrun`, `svec`, `lewis-tvv`, `sv-em`; `svec` requires `--ci none` and accepts an optional `[svec]` config) |
| `--ci` | | String | `bootstrap` | `none`, `bootstrap`, `theoretical` |
| `--replications` | | Int | 1000 | Bootstrap replications |
| `--config` | | String | | TOML config for identification restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) filtered to `--shock` (VECM → VAR representation, same schema as `irf var`).

---
## irf pvar

Panel VAR impulse response functions. Supports orthogonalized (OIRF) and generalized (GIRF) impulse responses.

```bash
friedman irf pvar :grunfeld --id-col=group --time-col=time --horizons=10
friedman irf pvar :grunfeld --id-col=group --time-col=time --irf-type=girf --horizons=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 1 | Lag order |
| `--horizons` | `-h` | Int | 10 | IRF horizon |
| `--id-col` | | String | | Panel group identifier column |
| `--time-col` | | String | | Panel time identifier column |
| `--irf-type` | | String | `oirf` | `oirf` (orthogonalized), `girf` (generalized) |
| `--boot-draws` | | Int | 500 | Bootstrap draws for CIs |
| `--confidence` | | Float64 | 0.95 | Confidence level |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Wide, per-shock-file table (columns = variables, rows = horizons) with bootstrap bands — `pvar_bootstrap_irf` returns a plain NamedTuple, not a result type, so this leaf stays outside the `long_table` conversion.

---
## irf favar

FAVAR impulse response functions. Reports every shock in one table; `--panel-irf` widens the response space from the factors to all panel variables.

```bash
friedman irf favar :denmark --lags=2 --key-vars=LRM,LRY,LPY
friedman irf favar :denmark --lags=2 --panel-irf
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-r` | Int | auto | Number of factors |
| `--lags` | `-p` | Int | 2 | VAR lag order |
| `--key-vars` | | String | | Key variable names or indices (comma-separated) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--id` | | String | `cholesky` | Identification method |
| `--config` | | String | | TOML config for restrictions |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |
| `--panel-irf` | | Flag | | Output panel-wide IRFs (N variables) instead of factor-level |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) covering every shock.

---
## irf sdfm

Structural DFM impulse response functions (panel-wide). Estimation shares the `estimate`/`fevd`/`hd` SDFM surface (`--factors`, `--id`, `--q-method`, `--method`, `--spectral`, `--instrument`, `--var-lags`).

```bash
friedman irf sdfm :denmark --factors=2 --horizons=40
friedman irf sdfm :denmark --factors=2 --ci=bootstrap --reps=200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | `-q` | Int | auto | Number of dynamic factors (default: auto via `--q-method`) |
| `--id` | | String | `cholesky` | Identification at estimation |
| `--q-method` | | String | `hallin-liska` | Auto factor selection: `hallin-liska`, `bai-ng`, `amengual-watson` |
| `--method` | | String | `fglr` | Estimator: `fglr`, `gdfm-var` (legacy path) |
| `--spectral` | | String | `lag-window` | GDFM spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--instrument` | | String | | Proxy-instrument CSV column (only with `--id proxy`) |
| `--var-lags` | | Int | 1 | Factor VAR lag order |
| `--horizons` | `-h` | Int | 40 | IRF horizon |
| `--config` | | String | | TOML config for sign restrictions |
| `--ci` | | String | `none` | Bands: `none`, `bootstrap` (residual bootstrap) |
| `--reps` | | Int | 200 | Bootstrap replications (with `--ci bootstrap`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Tidy table (`horizon|variable|shock|value|lower|upper`) covering every shock.

---
## Identification methods

`irf var` accepts the full identification surface; every other leaf accepts the subset named in its own table above.

| ID String | Method | Config Required |
|-----------|--------|----------------|
| `cholesky` | Cholesky decomposition (recursive) | No |
| `sign` | Sign restrictions | Yes (sign matrix) |
| `narrative` | Narrative sign restrictions | Yes (narrative block) |
| `longrun` | Long-run (Blanchard–Quah) | No |
| `arias` | Arias et al. zero + sign | Yes (restrictions) |
| `narrative-adrr` | Arias pipeline + Antolín-Díaz/Rubio-Ramírez narrative contributions | Yes (restrictions + narrative_contributions) |
| `uhlig` | Uhlig (Mountford & Uhlig 2009) penalty-based | Yes (restrictions + uhlig params) |
| `proxy` | External-instrument (proxy SVAR) | No (`--instrument` names the CSV column) |
| `max-share` | Max forecast-error-variance share | No (`--target-var` names the target) |
| `gmm-moments` | Non-Gaussian GMM moment conditions | No |
| `lewis-tvv` | Heteroskedasticity (Lewis time-varying volatility) | No |
| `sv-em` | Heteroskedasticity (stochastic-volatility EM) | No |
| `fastica` | FastICA | No |
| `jade` | JADE | No |
| `sobi` | SOBI | No |
| `dcov` | Distance covariance | No |
| `hsic` | Hilbert–Schmidt independence | No |
| `student_t` | Student-t ML | No |
| `mixture_normal` | Mixture normal ML | No |
| `pml` | Pseudo-ML | No |
| `skew_normal` | Skew-normal ML | No |
| `markov_switching` | Markov-switching heteroskedasticity | No |
| `garch_id` | GARCH-based heteroskedasticity | No |

See [Configuration](../configuration.md) for restriction TOML formats. Sign/narrative IRFs report the identified-set median with set-robust bands by default; `--summary` selects an alternative set summary (Fry–Pagan median target, modal model, joint or sup-t bands) on the `--identified-set` path.

### Bootstrap schemes and bias correction

These apply under `--ci bootstrap` only; with any other `--ci` they are ignored and the CLI says so on stderr rather than letting the flag look effective.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--bootstrap` | String | `iid` | `iid`, `wild`, `block` |
| `--wild-dist` | String | `rademacher` | Multiplier for `--bootstrap wild`: `rademacher`, `mammen` |
| `--block-length` | Int | 0 | Block length for `--bootstrap block` (0 = library default) |
| `--bias-correct` | Flag | | Kilian (1998) bias-corrected bands |
| `--bias-reps` | Int | 0 | Inner reps for `--bias-correct` (0 = same as `--replications`) |

Which scheme to use follows from what the residuals violate. `iid` resamples them independently and assumes both homoskedasticity and no serial dependence. `wild` multiplies each residual by a mean-zero draw, preserving conditional heteroskedasticity — the usual choice for macro data. `block` resamples contiguous blocks, preserving short-range dependence the VAR has not captured.

!!! warning "`--bias-correct` is bootstrap-after-bootstrap"
    OLS VAR coefficients are biased toward stationarity in small samples, which biases the IRFs. Kilian's correction estimates that bias by an *inner* bootstrap, re-centres the DGP, and corrects every outer draw.

    The cost is **multiplicative, not additive**: the inner loop runs `--bias-reps` (default: `--replications`) re-estimations *per outer draw*. Set `--bias-reps` well below `--replications` — a few hundred is normally enough to pin the bias down — before running this on anything large.

### Arias identification diagnostics

`--id arias` reports an importance-sampling diagnostics table alongside the IRF:

| Field | Meaning |
|---|---|
| `acceptance_rate` | Fraction of candidate draws satisfying the restrictions |
| `n_draws` | Nominal draw count |
| `ess` | Kish's effective sample size of the importance weights |
| `ess_fraction` | `ess / n_draws` |

Read `ess_fraction`, not `n_draws`. Under pure sign restrictions the weights are uniform and the fraction is 1. **With zero restrictions it can be far below 1**, meaning a handful of draws carry most of the posterior mass. Below 0.1 the CLI warns on stderr.

---
## See Also

For FAVAR background, see [favar & sdfm](favar.md). For DSGE model IRFs, see [dsge irf](dsge.md#dsge-irf). For variance shares of the same shocks, see [fevd](fevd.md). For shock contributions over history, see [hd](hd.md).

---
## References

- Kilian, L. (1998). Small-sample confidence intervals for impulse response functions. *Review of Economics and Statistics*.
- Arias, J. E., Rubio-Ramírez, J. F., & Waggoner, D. F. (2018). Inference based on structural vector autoregressions identified with sign and zero restrictions. *Econometrica*.
- Fry, R., & Pagan, A. (2011). Sign restrictions in structural vector autoregressions: A critical review. *Journal of Economic Literature*.
