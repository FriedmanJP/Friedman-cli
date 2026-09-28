# io

Input-Output analysis: Leontief/Ghosh multiplier models, backward/forward
linkages, key-sector classification, structural decomposition analysis (SDA),
hypothetical extraction, environmental footprints, and the Baqaee–Farhi (2019)
nonlinear IO decomposition.

Wraps the MacroEconometricModels `io` module. Every **analysis** leaf runs
offline out of the box: with no `--data`, the bundled **`:wiot`** example — the
Miller & Blair (2009) 2-sector table, with `employment` and `CO2` satellite
accounts — is used. `io download` is the only network-touching leaf.

Option tables: [generated `io` reference](generated/io.md).

---
## Loading data

Every analysis leaf shares these input options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--data` | String | | IO table: CSV path, `:wiot` (bundled example, the default), or another `:example` |
| `--n-sectors` | Int | `0` | Number of sectors (CSV: `Z` is the first `n_sectors` columns) |
| `--n-fd` | Int | `1` | Number of final-demand columns (CSV) |
| `--sectors` | String | | Comma-separated sector labels (CSV) |

An empty `--data` means `:wiot`. Another `:example` loads that bundled
example (it must be an IO table); a `.jld2` path or `model://` handle loads a
saved table; anything else is a CSV path, which requires `--n-sectors`. A CSV
is parsed by `parse_io`: the first `n_sectors` columns are the
intermediate-flow matrix `Z`, the next `n_fd` columns are final demand; value
added is derived from the column balance. Satellite accounts (needed for
`employment` multipliers and `footprint`) are **not** carried in a plain CSV —
use `:wiot`, or a full MRIO archive parsed via the `ZipFile`/`XLSX` extensions.
Leaves that read downloaded MRIO tables add `--parser csv|icio` — see the
[generated `io` reference](generated/io.md).

---
## Output format

IO result types are not Tables.jl-registered upstream, so io leaves render via
hand-built tables. **Square matrices** (Leontief/Ghosh inverses, technical /
allocation coefficients) render **wide** — first column `sector`, then one
column per sector. **Vector-valued** results (multipliers, linkages, Domar
weights, per-sector footprints) render as one row per sector.

---
## io sources

List the downloadable IO/MRIO sources (offline catalog): source names,
available versions, and credential requirements.

```bash
friedman io sources
```

---
## io download

Download an IO/MRIO archive. **Network-touching.** Respects `--offline` (and the
`FRIEDMAN_OFFLINE=1` environment variable): refusing with exit code **6**
(`env/network`). A network failure also maps to `env/network`; a SHA-256
checksum mismatch maps to `env/checksum-mismatch` (exit 6).

```bash
friedman io download --source oecd --storage ./io_data --source-version v2023 --years 2018
friedman io download --source exiobase3 --storage ./io_data --system pxp
friedman io download --source eora26 --storage ./io_data --email you@example.com --password ***
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--source` | String | | `oecd`\|`wiod`\|`exiobase3`\|`eora26`\|`gloria` (required) |
| `--storage` | String | | Destination folder (required) |
| `--source-version` | String | | Source version (e.g. OECD `v2023`) — not `--version`, which is the reserved CLI global |
| `--years` | String | | Comma-separated year filter |
| `--system` | String | `pxp` | EXIOBASE `pxp` (product×product) or `ixi` (industry×industry) |
| `--email` / `--password` | String | | EORA26 credentials |
| `--offline` | flag | | Refuse network access (exit 6) |
| `--overwrite` | flag | | Re-download existing files |
| `--no-verify` | flag | | Skip SHA-256 checksum verification |

Prints the download summary (source, resolved version, file count) and the
download log (`url → filename`). Checksum verification is on by
default; the upstream checksum registry is unpopulated until maintainers record
digests, so unverified downloads emit a warning rather than failing.

---
## io load

Parse and inspect an IO table: dimensions, provenance, and per-sector gross
output / final demand / value added (a balance check).

```bash
friedman io load                       # the bundled :wiot example
friedman io load --data :wiot
```

OECD ICIO text tables parse with `--parser icio` (plus `--year`, `--member`,
`--no-aggregate-cn-mx`, `--check`); a parsed table persists with
`--save-model`. Full option list: [generated `io` reference](generated/io.md).

---
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

---
## io ghosh

Supply-driven (Ghosh) representation: allocation coefficients `B = x̂⁻¹ Z` and
the Ghosh inverse `G = (I − B)⁻¹`.

```bash
friedman io ghosh                      # G only (default)
friedman io ghosh --matrix both        # B and G
```

---
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

---
## io linkages

Backward linkages (column sums of `L`) and forward linkages (row sums of the
Ghosh inverse `G`, or of `L` with `--forward leontief`), plus the Rasmussen
power-of-dispersion (`Ui`) and sensitivity-of-dispersion (`Uj`) indices and the
per-sector `key`/`forward`/`backward`/`weak` classification.

```bash
friedman io linkages
friedman io linkages --forward leontief
```

---
## io key-sectors

The Rasmussen quadrant classification only (`key`/`forward`/`backward`/`weak`),
with quadrant counts on stderr. Takes the same `--forward` basis as
`io linkages`.

```bash
friedman io key-sectors
```

---
## io sda

Structural decomposition of the change in an indicator between two periods
(Dietzenbacher & Los 1998 two-polar average). Omit `--factors` and `--on` for
the classical output path, which emits legacy `L_effect`/`Y_effect` columns.
Pass `--on <satellite>` (e.g. `CO2` on `:wiot`) for emission SDA; the default
factors then become intensity, technology, and final demand (no `L`/`Y` keys).

```bash
friedman io sda                        # classical output path on :wiot (legacy L_effect/Y_effect)
friedman io sda --method multiplicative
friedman io sda --factors technology,final-demand
friedman io sda --on CO2
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--data2` | String | | Second-period table (defaults to `--data`) |
| `--method` | String | `additive` | `additive` (exact, zero residual) \| `multiplicative` |
| `--factors` | String | | Comma-separated SDA factors (kebab); omit for legacy `L_effect`/`Y_effect` |
| `--on` | String | `output` | `output` or a satellite account name (emission SDA) |

---
## io extract

Hypothetical extraction: the total-output loss from removing one or more sectors
(zero their rows/columns of `A` and their final demand, re-solve, and compare).

```bash
friedman io extract --sectors-extract Manufacturing
friedman io extract --sectors-extract 1,3,5
friedman io extract --sectors-extract Manufacturing --mode partial --share 0.5
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--sectors-extract` | String | | Sector name(s) or 1-based index/indices, comma-separated (required) |
| `--mode` | String | `complete` | `complete` \| `backward` \| `forward` \| `partial` |
| `--share` | Float64 | `1.0` | Partial extraction share in (0, 1] |
| `--region` | String | | Extract a whole MRIO region block |

The extracted sectors and the total loss print on stderr; the per-sector loss is
the data table, with a summary (`total_loss`, `loss_pct_go`, `loss_pct_gdp`,
`mode`, `share`).

---
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
| `--by` | String | `sector` | `sector` \| `region` (MRIO production vs consumption) |
| `--detail` | flag | | Also emit intensities `S = F x̂⁻¹` and emission multipliers `M = S·L` |

---
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

---
## Baqaee–Farhi standard form (`io bf` …)

The `io bf` leaves calibrate a Baqaee–Farhi `ProductionNetwork` from the IO
table and run exact nonlinear counterfactuals on it. Every `io bf` leaf shares
the network-calibration options (`--theta`, `--sigma`, `--epsilon`, `--eta`,
`--nests`, `--factors`, `--mu`, `--no-check`) plus `--parser` — see the
[generated `io` reference](generated/io.md) for the exact per-leaf tables.

| Leaf | Analysis |
|------|----------|
| `io bf network` | Calibrate the `ProductionNetwork`: cost/revenue Domar weights and markups |
| `io bf equilibrium` | Exact nested-CES counterfactual equilibrium (`--dlog-a/--dlog-l/--dlog-mu`, `--method/--tol/--maxiter/--damping`) |
| `io bf local` | Local Hulten weights plus the second-order Hessian (`--hessian`, `--no-elasticities`) |
| `io bf elasticities` | Factor-price, goods-price, and Domar-share incidence at the base point |
| `io bf shock-curve` | One-sector productivity shock over a `--range` grid: exact vs Hulten vs second-order Taylor (`--sector`, `--points`) |
| `io bf wedges` | Technology vs allocative-efficiency split for a shock bundle (`--dlog-a/--dlog-l/--dlog-mu`) |
| `io bf misallocation` | Harberger misallocation distance (`--point`, `--hessian`) |

```bash
friedman io bf network
friedman io bf equilibrium --dlog-a 0.01,0
friedman io bf shock-curve --sector 1 --range -0.2,0.2
```

---
## Classical extensions and MRIO trade

Price, impact, network, balancing, and multi-region trade leaves. Every leaf
takes the shared [Loading data](#loading-data) options plus
`--parser csv|icio` — see the [generated `io` reference](generated/io.md).

| Leaf | Analysis |
|------|----------|
| `io price` | Leontief cost-push (or Ghosh dual) price model (`--dva`, `--dtax`, `--mode`) |
| `io impact` | Final-demand scenario through the Leontief inverse (`--dy`, `--kind`, `--type`) |
| `io network-stats` | Domar weights, Herfindahl, APL, degrees, upstreamness/downstreamness |
| `io aggregate` | Aggregate over regions and/or sector types (`--region-map`, `--sector-map`) |
| `io balance` | Repair intermediate flows so row and column accounts close, RAS/GRAS (`--method`, `--tol`, `--maxiter`) |
| `io vertical-specialization` | Hummels–Ishii–Yi / KWW import content of exports (`--region`) |
| `io export-decomposition` | Koopman–Wang–Wei (2014) DVA/RDV/FVA/PDC decomposition of gross exports (`--region`) |
| `io bilateral-trade` | Bilateral intermediate/final/total trade, exporter to importer (`--exporter`, `--importer`, `--kind`) |

```bash
friedman io price --dva 0.1,0
friedman io impact --dy 10,0
```

`io bilateral-trade` needs a multi-region table (e.g. via `io download` plus `--parser icio`); the single-region `:wiot` example has no second region to address.

---
## Common options

All leaves accept `--format table|csv|json` (`-f`) and `--output <path>` (`-o`).

---
## References

- Full option and output-table list: [generated `io` reference](generated/io.md).
- Miller, R. E., & Blair, P. D. (2009). *Input-Output Analysis: Foundations and Extensions.* Cambridge University Press.
- Dietzenbacher, E., & Los, B. (1998). "Structural Decomposition Techniques: Sense and Sensitivity." *Economic Systems Research*, 10(4), 307--324.
- Baqaee, D. R., & Farhi, E. (2019). "The Macroeconomic Impact of Microeconomic Shocks: Beyond Hulten's Theorem." *Econometrica*, 87(4), 1155--1203.
- Hummels, D., Ishii, J., & Yi, K.-M. (2001). "The Nature and Growth of Vertical Specialization in World Trade." *Journal of International Economics*, 54(1), 75--96.
- Koopman, R., Wang, Z., & Wei, S.-J. (2014). "Tracing Value-Added and Double Counting in Gross Exports." *American Economic Review*, 104(2), 459--494.
