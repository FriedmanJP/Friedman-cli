# filter

**Trend-cycle decomposition** of time series data across `hp`, `hamilton`, `bn`, `bk`, `bhp`, and `x13`. Each leaf regresses nothing: it splits every selected column into a **trend** (permanent) component and a **cycle** (transitory) component, and reports the **cycle variance ratio** (cycle variance over total variance) on stderr as a diagnostic.

Full option tables live in the generated reference (`generated/filter.md`); the tables below repeat the filter-specific options only.

---

## filter hp

The **Hodrick-Prescott filter** extracts a smooth trend by penalizing second-difference curvature with smoothing parameter λ.

```bash
friedman filter hp :nile --lambda=1600
friedman filter hp :nile --columns=1 --lambda=6.25
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lambda` | `-l` | Float64 | 1600.0 | Smoothing parameter (6.25 annual, 1600 quarterly, 129600 monthly) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |

Set λ to the frequency of the data: 6.25 for annual, 1600 for quarterly, 129600 for monthly observations.

---

## filter hamilton

The **Hamilton regression filter** (Hamilton 2018) defines the cycle as the residual of a projection of $y_t$ on its own lags $y_{t-h}, \dots, y_{t-h-p+1}$, and the trend as the fitted value. It avoids the spurious-cycle critique of the HP filter at business-cycle frequencies.

```bash
friedman filter hamilton :nile --horizon=8 --lags=4
friedman filter hamilton :nile --columns=1 --horizon=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--horizon` | | Int | 8 | Forecast horizon $h$ |
| `--lags` | `-p` | Int | 4 | Number of lags $p$ in the projection |
| `--columns` | `-c` | String | all | Column indices, comma-separated |

The filter truncates the valid range: the first $h + p - 1$ observations have no cycle value.

---

## filter bn

The **Beveridge-Nelson decomposition** splits the series into a permanent (random-walk trend) component and a transitory (stationary cycle) component. The `arima` method fits an ARIMA model and derives the decomposition analytically; `statespace` estimates it via the state-space representation.

```bash
friedman filter bn :nile
friedman filter bn :nile --p=2 --q=2
friedman filter bn :nile --method=statespace
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `arima` | `arima`, `statespace` |
| `--p` | | Int | auto | AR order (ARIMA method only; auto-selects when omitted) |
| `--q` | | Int | auto | MA order (ARIMA method only; auto-selects when omitted) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |

---

## filter bk

The **Baxter-King band-pass filter** keeps oscillations with periods between `--pl` and `--pu` and removes slower trends and faster noise. It applies a symmetric moving average of half-length $K$.

```bash
friedman filter bk :nile --pl=6 --pu=32 --K=12
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--pl` | | Int | 6 | Minimum period of oscillation |
| `--pu` | | Int | 32 | Maximum period of oscillation |
| `--K` | | Int | 12 | Truncation length (symmetric leads/lags) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |

The symmetric window costs $K$ observations at each end of the series.

---

## filter bhp

The **boosted HP filter** (Phillips & Shi 2021) iteratively re-applies the HP filter to the estimated cycle until a **stopping criterion** fires, which hardens the trend against structural breaks that a single HP pass absorbs into the cycle.

```bash
friedman filter bhp :nile --lambda=1600 --stopping=BIC
friedman filter bhp :nile --stopping=ADF --sig-p=0.01
friedman filter bhp :nile --stopping=fixed --max-iter=50
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lambda` | `-l` | Float64 | 1600.0 | Smoothing parameter |
| `--stopping` | | String | `BIC` | Stopping criterion: `BIC`, `ADF`, `fixed` |
| `--max-iter` | | Int | 100 | Maximum boosting iterations |
| `--sig-p` | | Float64 | 0.05 | ADF significance level (ADF stopping only) |
| `--columns` | `-c` | String | all | Column indices, comma-separated |

---

## filter x13

**X-13ARIMA-SEATS seasonal adjustment** via a pure-Julia port of the Census X-11/SEATS methods; no external binary is required. The leaf emits five tables: seasonally adjusted series, trend-cycle, seasonal factors, irregular, and per-variable diagnostics (ARIMA order, AIC, outlier count).

Each example below builds its own seasonal CSV in the same command, so every fence runs standalone. The generator writes monthly or quarterly observations with seasonal, trend, and noise parts:
```bash
awk 'BEGIN{srand(7); print "y"; for(t=1;t<=120;t++) printf "%.4f\n", 100+10*sin(2*3.14159265*t/12)+0.05*t+0.3*(rand()-0.5)*2}' > monthly.csv && friedman filter x13 monthly.csv --frequency=12 --method=x11 --transform=none
awk 'BEGIN{srand(7); print "y"; for(t=1;t<=60;t++) printf "%.4f\n", 100+10*sin(2*3.14159265*t/4)+0.05*t+0.3*(rand()-0.5)*2}' > quarterly.csv && friedman filter x13 quarterly.csv --frequency=4 --method=seats --trading-day --easter --transform=none
awk 'BEGIN{srand(7); print "y"; for(t=1;t<=120;t++) printf "%.4f\n", 100+10*sin(2*3.14159265*t/12)+0.05*t+0.3*(rand()-0.5)*2}' > monthly.csv && friedman filter x13 monthly.csv --columns=1 --transform=log --outliers=true
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

The series needs at least $3 \times$ `--frequency` observations (`data/too-short` otherwise). Use `--frequency=12` for monthly and `--frequency=4` for quarterly data; `--transform=log` suits strictly positive series with multiplicative seasonality. Treat the SEATS AIC as a diagnostic, not a formal likelihood-ratio statistic.

---

## References

- Hamilton, J. D. (2018). "Why You Should Never Use the Hodrick-Prescott Filter." *Review of Economics and Statistics*, 100(5), 831--843.
- Phillips, P. C. B., & Shi, Z. (2021). "Boosting: Why You Can Use the HP Filter." *International Economic Review*, 62(2), 521--570.
- U.S. Census Bureau. *X-13ARIMA-SEATS Reference Manual*. Time Series Staff, Statistical Research Division.
