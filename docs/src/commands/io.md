# io

Input-Output analysis: Leontief/Ghosh multiplier models, backward/forward
linkages, key-sector classification, structural decomposition analysis (SDA),
hypothetical extraction, environmental footprints, and the Baqaee–Farhi (2019)
nonlinear IO decomposition. 12 subcommands.

Wraps the MacroEconometricModels `io` module. Every **analysis** leaf runs
offline out of the box: with no `--data`, the bundled **`:wiot`** example — the
Miller & Blair (2009) 2-sector table, with `employment` and `CO2` satellite
accounts — is used. `io download` is the only network-touching leaf.

## Loading data

Every analysis leaf shares these input options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--data` | String | | IO table: CSV path, `:wiot` (bundled example, the default), or another `:example` |
| `--n-sectors` | Int | `0` | Number of sectors (CSV: `Z` is the first `n_sectors` columns) |
| `--n-fd` | Int | `1` | Number of final-demand columns (CSV) |
| `--sectors` | String | | Comma-separated sector labels (CSV) |

A CSV is parsed by `parse_io`: the first `n_sectors` columns are the
intermediate-flow matrix `Z`, the next `n_fd` columns are final demand; value
added is derived from the column balance. Satellite accounts (needed for
`employment` multipliers and `footprint`) are **not** carried in a plain CSV —
use `:wiot`, or a full MRIO archive parsed via the `ZipFile`/`XLSX` extensions.

## Output format

IO result types are not Tables.jl-registered upstream, so io leaves render via
hand-built tables. **Square matrices** (Leontief/Ghosh inverses, technical /
allocation coefficients) render **wide** — first column `sector`, then one
column per sector. **Vector-valued** results (multipliers, linkages, Domar
weights, per-sector footprints) render as one row per sector.

## io sources

List the downloadable IO/MRIO sources (offline catalog).

```bash
friedman io sources
```

| source | credentials | versions |
|--------|-------------|----------|
| `oecd` | no | v2016, v2018, v2021, v2023 |
| `wiod` | no | 2013 |
| `exiobase3` | no | 3.8.2 |
| `eora26` | **yes** (worldmrio.com account) | 26 |
| `gloria` | no | 053 |

## io download

Download an IO/MRIO archive. **Network-touching.** Respects `--offline` (and the
`FRIEDMAN_OFFLINE=1` environment variable): refusing with exit code **6**
(`env/network`). A network failure also maps to `env/network`; a SHA-256
checksum mismatch maps to `env/checksum-mismatch` (exit 6).

```bash
friedman io download --source oecd --storage ./io_data --version v2023 --years 2018
friedman io download --source exiobase3 --storage ./io_data --system pxp
friedman io download --source eora26 --storage ./io_data --email you@example.com --password ***
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--source` | String | | `oecd`\|`wiod`\|`exiobase3`\|`eora26`\|`gloria` (required) |
| `--storage` | String | | Destination folder (required) |
| `--version` | String | | Source version (e.g. OECD `v2023`) |
| `--years` | String | | Comma-separated year filter |
| `--system` | String | `pxp` | EXIOBASE `pxp` (product×product) or `ixi` (industry×industry) |
| `--email` / `--password` | String | | EORA26 credentials |
| `--offline` | flag | | Refuse network access (exit 6) |
| `--overwrite` | flag | | Re-download existing files |
| `--no-verify` | flag | | Skip SHA-256 checksum verification |

Prints the download log (`url → filename`). Checksum verification is on by
default; the upstream checksum registry is unpopulated until maintainers record
digests, so unverified downloads emit a warning rather than failing.

## io load

Parse and inspect an IO table: dimensions, provenance, and per-sector gross
output / final demand / value added (a balance check).

```bash
friedman io load                       # the bundled :wiot example
friedman io load --data wiot.csv --n-sectors 35 --n-fd 1
```

## io leontief

Demand-driven (Leontief) representation: technical coefficients `A = Z x̂⁻¹` and
the Leontief inverse `L = (I − A)⁻¹` (total requirements).

```bash
friedman io leontief                   # L only (default)
friedman io leontief --matrix A        # technical coefficients
friedman io leontief --matrix both     # A and L
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--matrix` | String | `L` | `L` (Leontief inverse) \| `A` (technical coefficients) \| `both` |

## io ghosh

Supply-driven (Ghosh) representation: allocation coefficients `B = x̂⁻¹ Z` and
the Ghosh inverse `G = (I − B)⁻¹`.

```bash
friedman io ghosh                      # G only (default)
friedman io ghosh --matrix both        # B and G
```

## io multipliers

Sectoral multipliers.

```bash
friedman io multipliers --kind output --type I
friedman io multipliers --kind income --type II
friedman io multipliers --kind employment      # needs an employment account
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--kind` | String | `output` | `output` (column sums of `L`) \| `income` (value-added weighted) \| `employment` (jobs-weighted) |
| `--type` | String | `I` | Type I (open) \| Type II (household-closed) |

## io linkages

Backward linkages (column sums of `L`) and forward linkages (row sums of the
Ghosh inverse `G`, or of `L` with `--forward leontief`), plus the Rasmussen
power-of-dispersion (`Ui`) and sensitivity-of-dispersion (`Uj`) indices and the
per-sector `key`/`forward`/`backward`/`weak` classification.

```bash
friedman io linkages
friedman io linkages --forward leontief
```

## io key-sectors

The Rasmussen quadrant classification only (`key`/`forward`/`backward`/`weak`),
with quadrant counts on stderr.

```bash
friedman io key-sectors
```

## io sda

Structural decomposition of the change in gross output between two periods into
a technology (`ΔL`) effect and a final-demand (`Δy`) effect (Dietzenbacher &
Los 1998).

```bash
friedman io sda --data period0.csv --data2 period1.csv --n-sectors 35
friedman io sda --method multiplicative
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--data2` | String | | Second-period table (defaults to `--data`) |
| `--method` | String | `additive` | `additive` (exact, zero residual) \| `multiplicative` |

## io extract

Hypothetical extraction: the total-output loss from removing one or more sectors
(zero their rows/columns of `A` and their final demand, re-solve, and compare).

```bash
friedman io extract --sectors-extract Manufacturing
friedman io extract --sectors-extract 1,3,5
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--sectors-extract` | String | | Sector name(s) or 1-based index/indices, comma-separated (required) |

The extracted sectors and the total loss print on stderr; the per-sector loss is
the data table.

## io footprint

Consumption-based footprint of a satellite (environmental) account:
`total = M·Y + F_Y` per stressor, and the per-sector contribution `M ⊙ y'`, with
`M = S·L`.

```bash
friedman io footprint                          # first account (e.g. CO2)
friedman io footprint --account employment
friedman io footprint --account CO2 --detail   # also emit intensities S and multipliers M
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--account` | String | | Satellite account name (default: first available) |
| `--detail` | flag | | Also emit intensities `S = F x̂⁻¹` and emission multipliers `M = S·L` |

## io baqaee-farhi

Baqaee & Farhi (2019) nonlinear IO decomposition: Domar weights `λ = sales/GDP`
(the first-order Hulten term), the influence vector, and up/down-streamness
centralities. The second-order "beyond Hulten" Hessian is parameterized by the
substitution elasticities; with the Cobb-Douglas default (`--theta 1 --sigma 1`)
it vanishes and Hulten is exact.

```bash
friedman io baqaee-farhi
friedman io baqaee-farhi --theta 0.5 --sigma 0.9 --second-order
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--theta` | Float64 | `1.0` | Production substitution elasticity |
| `--sigma` | Float64 | `1.0` | Consumption substitution elasticity |
| `--second-order` | flag | | Also emit the second-order Hessian (sector×sector) |

## Common options

All leaves accept `--format table\|csv\|json` (`-f`) and `--output <path>` (`-o`).
