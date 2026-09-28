# Spectral Analysis

**Frequency-domain analysis**: the `spectral` family decomposes the second-order structure of a series by frequency instead of by lag. `acf` and `periodogram` describe the data nonparametrically; `density` smooths or models the spectrum; `cross` relates two series frequency by frequency; `transfer` evaluates a theoretical filter response with no data at all.

Full option tables live in the generated reference (`generated/spectral.md`).

---

## spectral acf

Sample **autocorrelation** (ACF) and **partial autocorrelation** (PACF) by lag with **Ljung-Box** $Q$ statistics and $p$-values. ACF at lag $k$ is the correlation of $y_t$ with $y_{t-k}$; PACF at lag $k$ is the correlation conditional on the intermediate lags. With `--ccf-with`, a second table reports the **cross-correlation** (CCF) of the two columns by lag.

```bash
friedman spectral acf :nile --column 1 --max-lag 20
friedman spectral acf :fred_md --column 1 --ccf-with 2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--max-lag` | | Int | auto | Maximum lag (auto: min(20, T−1)) |
| `--ccf-with` | | Int | — | Column index for cross-correlation |

Use slowly decaying ACF with a sharp PACF cutoff to diagnose autoregressive structure, and the reverse for moving-average structure.

---

## spectral periodogram

The raw **periodogram**: squared magnitude of the discrete Fourier transform at each Fourier frequency. It is an unbiased but inconsistent estimator of the spectral density — adjacent ordinates stay noisy no matter how large $T$ grows — so read peak locations from it and magnitudes from `density`.

```bash
friedman spectral periodogram :nile --column 1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |

---

## spectral density

Estimated **spectral density** with a confidence band by frequency. The `--method` selects the estimator: `periodogram` returns the raw ordinates, `welch` averages periodograms over overlapping segments, `smoothed` applies kernel smoothing with `--bandwidth`, and `ar` fits an autoregression and reports its implied spectrum.

```bash
friedman spectral density :nile --method welch
friedman spectral density :nile --method smoothed --bandwidth 0.1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--method` | `-m` | String | `welch` | `periodogram`, `welch`, `smoothed`, `ar` |
| `--bandwidth` | | Float | auto | Smoothing bandwidth (smoothed method) |

---

## spectral cross

**Cross-spectral analysis** of two series: the co-spectrum (in-phase covariance) and quadrature spectrum (out-of-phase covariance) by frequency, plus **coherence** (frequency-domain squared correlation), **phase** (lead-lag shift in radians), and **gain** (regression slope of the second series on the first at each frequency).

```bash
friedman spectral cross :fred_md --var1 1 --var2 2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--var1` | | Int | 1 | First variable column index |
| `--var2` | | Int | 2 | Second variable column index |

Coherence near one means the second series is (up to phase and scale) predictable from the first at that frequency; phase divided by frequency gives the time lag.

---

## spectral transfer

Theoretical **transfer function** of a named filter: gain and phase by frequency on a grid of `--nobs` observations. It takes no data file. The gain shows which frequencies the filter keeps (gain near one) and kills (gain near zero); compare the HP gain against the `ideal` band-pass to see the HP filter's leakage and compression.

```bash
friedman spectral transfer --filter hp --lambda 1600 --nobs 200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--filter` | | String | `hp` | `hp`, `bk`, `hamilton`, `ideal` |
| `--lambda` | | Float | 1600.0 | Filter parameter (e.g. HP λ) |
| `--nobs` | | Int | 200 | Observations for the frequency grid |

---

## References

- Hamilton, J. D. (1994). *Time Series Analysis*, Chapters 6--8. Princeton University Press.
- Priestley, M. B. (1981). *Spectral Analysis and Time Series*. Academic Press.
