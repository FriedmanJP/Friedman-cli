# filter

Time series filtering and trend-cycle decomposition. 6 subcommands: `hp`, `hamilton`, `bn`, `bk`, `bhp`, `x13`.

All filter commands produce trend and cycle components, plus variance ratio diagnostics.

## filter hp

Hodrick-Prescott filter.

```bash
friedman filter hp data.csv --lambda=1600
friedman filter hp data.csv --columns=1,3,5 --lambda=6.25
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lambda` | `-l` | Float64 | 1600.0 | Smoothing parameter (6.25 annual, 1600 quarterly, 129600 monthly) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

## filter hamilton

Hamilton (2018) regression-based filter.

```bash
friedman filter hamilton data.csv --horizon=8 --lags=4
friedman filter hamilton data.csv --columns=1,2 --horizon=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--horizon` | `-h` | Int | 8 | Forecast horizon |
| `--lags` | `-p` | Int | 4 | Number of lags in regression |
| `--columns` | `-c` | String | all | Column indices, comma-separated |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Note:** Hamilton filter truncates the valid range (loses `h + p - 1` observations at the start).

## filter bn

Beveridge-Nelson decomposition. Supports ARIMA-based or state-space methods.

```bash
# ARIMA-based (default)
friedman filter bn data.csv
friedman filter bn data.csv --p=2 --q=2

# State-space method
friedman filter bn data.csv --method=statespace
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `arima` | `arima`, `statespace` |
| `--p` | | Int | auto | AR order (ARIMA method only) |
| `--q` | | Int | auto | MA order (ARIMA method only) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

## filter bk

Baxter-King band-pass filter.

```bash
friedman filter bk data.csv --pl=6 --pu=32 --K=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--pl` | | Int | 6 | Minimum period of oscillation |
| `--pu` | | Int | 32 | Maximum period of oscillation |
| `--K` | | Int | 12 | Truncation length (symmetric leads/lags) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Note:** Baxter-King loses `K` observations at each end of the series.

## filter bhp

Boosted HP filter (Phillips & Shi 2021). Iteratively re-applies the HP filter to the estimated cycle to improve trend estimation.

```bash
friedman filter bhp data.csv --lambda=1600 --stopping=BIC
friedman filter bhp data.csv --stopping=ADF --sig-p=0.01
friedman filter bhp data.csv --stopping=fixed --max-iter=50
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lambda` | `-l` | Float64 | 1600.0 | Smoothing parameter |
| `--stopping` | | String | `BIC` | Stopping criterion: `BIC`, `ADF`, `fixed` |
| `--max-iter` | | Int | 100 | Maximum boosting iterations |
| `--sig-p` | | Float64 | 0.05 | ADF significance level (ADF stopping only) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

## filter x13

X-13ARIMA-SEATS seasonal adjustment via MacroEconometricModels' pure-Julia port
(Census X-11 / SEATS methods; no external binary required).

```bash
# Monthly series, X-11 decomposition
friedman filter x13 monthly.csv --frequency=12 --method=x11

# Quarterly SEATS with trading-day + Easter
friedman filter x13 quarterly.csv --frequency=4 --method=seats --trading-day --easter

# Single column, log transform
friedman filter x13 data.csv --columns=1 --transform=log --outliers=true
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--frequency` | | Int | 12 | Seasonal period: 4 (quarterly) or 12 (monthly) |
| `--method` | | String | `seats` | Preferred decomposition: `seats` or `x11` |
| `--transform` | | String | `auto` | `auto`, `log`, or `none` |
| `--trading-day` | | Flag | | Trading-day regressors |
| `--easter` | | Flag | | Easter effect regressor |
| `--outliers` | | String | `true` | Detect AO/LS/TC outliers (`true`/`false`) |
| `--critical-value` | | Float64 | 0.0 | Outlier critical value (0 = automatic) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot |
| `--plot-save` | | String | | Save plot HTML |

**Output tables:** seasonally adjusted, trend, seasonal factors, irregular, diagnostics
(ARIMA order, AIC, outlier count).

**Errors:** `data/too-short` if T < 3×frequency; `env/x13-missing` (exit 6) if the
backend is unavailable (reserved; MEMs 0.6.7 ships pure-Julia X-13).

**Note:** Upstream MEMs #205 discusses exact-ML likelihood determinant questions for
some SEATS paths — treat SEATS AIC as diagnostic, not a formal likelihood ratio.
