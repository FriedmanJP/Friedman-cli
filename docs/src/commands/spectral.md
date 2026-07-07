# Spectral Analysis

The `spectral` command provides frequency-domain analysis tools.

## Subcommands

| Command | Description |
|---------|-------------|
| `spectral acf` | Autocorrelation / partial autocorrelation / cross-correlation |
| `spectral periodogram` | Raw periodogram |
| `spectral density` | Spectral density estimation (`periodogram`/`welch`/`smoothed`/`ar`) |
| `spectral cross` | Cross-spectral analysis (coherence, phase, gain) |
| `spectral transfer` | Filter transfer function (theoretical frequency response) |

All subcommands support `--output`/`-o` (export file), `--format`/`-f` (`table`, `csv`, `json`), `--plot`, and `--plot-save`. Every subcommand except `transfer` takes a CSV data file as its positional argument; `transfer` computes a theoretical response and takes no data file.

## spectral acf

```bash
friedman spectral acf data.csv --column 1 --max-lag 20
friedman spectral acf data.csv --column 1 --ccf-with 2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--max-lag` | | Int | min(20, T−1) | Maximum lag |
| `--ccf-with` | | Int | — | Column index for cross-correlation |

## spectral periodogram

```bash
friedman spectral periodogram data.csv --column 1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |

## spectral density

```bash
friedman spectral density data.csv --method welch
friedman spectral density data.csv --method smoothed --bandwidth 0.1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--method` | `-m` | String | `welch` | `periodogram`, `welch`, `smoothed`, `ar` |
| `--bandwidth` | | Float | auto | Smoothing bandwidth |

## spectral cross

```bash
friedman spectral cross data.csv --var1 1 --var2 2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--var1` | | Int | 1 | First variable column index |
| `--var2` | | Int | 2 | Second variable column index |

## spectral transfer

```bash
friedman spectral transfer --filter hp --lambda 1600 --nobs 200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--filter` | | String | `hp` | `hp`, `bk`, `hamilton`, `ideal` |
| `--lambda` | | Float | 1600.0 | Filter parameter (e.g. HP λ) |
| `--nobs` | | Int | 200 | Observations for the frequency grid |
