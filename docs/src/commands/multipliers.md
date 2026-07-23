# multipliers

Dynamic multipliers — the cumulative response of a variable to a permanent (step) change in a
regressor. This is a new top-level command (action-first, like `irf`/`fevd`/`hd`), extensible to
other multiplier families in future. It currently has one leaf.

## multipliers nardl

**Cumulative asymmetric dynamic multipliers** of a nonlinear ARDL (NARDL) model. For each
asymmetric regressor, `m⁺_{j,h}` and `m⁻_{j,h}` are the response of `y` at horizon `h = 0…H` to a
unit permanent change in that regressor's positive / negative partial sum, obtained by recursively
iterating the estimated ARDL difference equation. They converge to the long-run θ⁺_j / θ⁻_j as
`h → ∞`; the asymmetry curve `m⁺ − m⁻` traces how differently `y` reacts to increases vs. decreases.
Optional pointwise percentile bands come from a recursive-design (condition-on-`x`) residual
bootstrap.

The NARDL is fit exactly as [`estimate nardl`](estimate.md#estimate-nardl) (shared loader +
options), so `--dep`, `--asymmetric`, `--p`, `--q`, `--max-p`, `--max-q`, `--ic`, `--case` behave
identically.

```bash
# Point + bootstrap-band multipliers to horizon 24 (default 500 reps)
friedman multipliers nardl data.csv --dep=y --asymmetric=all --horizon=24

# Point multipliers only (no bands) — fast
friedman multipliers nardl data.csv --dep=y --horizon=12 --no-bootstrap

# Narrower bands with fewer reps
friedman multipliers nardl data.csv --dep=y --horizon=24 --nreps=200 --level=0.90
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--asymmetric` | | String | `all` | `all` or comma-separated 1-based regressor indices to split |
| `--p` / `--q` | | String | `auto` | ARDL AR / DL orders (`auto`, an integer, or a per-regressor list for `--q`) |
| `--max-p` / `--max-q` | | Int | `4` | Grid bounds for `auto` selection |
| `--ic` | | String | `aic` | `aic`, `bic` |
| `--case` | | Int | `3` | PSS deterministic case 1..5 |
| `--horizon` | | Int | `12` | Maximum multiplier horizon `H` (≥ 0) |
| `--nreps` | | Int | `500` | Bootstrap replications for the bands (`0` = no bands) |
| `--level` | | Float64 | `0.95` | Bootstrap band coverage |
| `--no-bootstrap` | | Flag | | Skip bootstrap bands (point multipliers only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one **tidy long table** melting the `n_asym × (H+1)` multiplier matrices —
`horizon | regressor | m_pos | m_neg | m_diff`, with per-band low/high columns
(`m_pos_lo`, `m_pos_hi`, `m_neg_lo`, `m_neg_hi`, `m_diff_lo`, `m_diff_hi`) present **only** when
bands are computed (`--nreps > 0` and not `--no-bootstrap`). A summary block reports `horizon`,
`n_asym`, `nreps`, `level`, `bootstrap`, and the long-run convergence targets `theta_pos`/`theta_neg`.

`NARDLMultipliers` is not Tables.jl-registered upstream, so the table is hand-built (a documented
[C051](estimate.md#coefficient-table-format-c051) exception). The bootstrap is an rng-only family:
reproducibility rides the global `--seed` (there is no per-estimator seed to record in a manifest).

## Related

- [`estimate nardl`](estimate.md#estimate-nardl) — fit the NARDL (folds long-run θ⁺/θ⁻ + bounds).
- [`test nardl-symmetry`](test.md#test-nardl-symmetry) — long-/short-run symmetry Wald tests.
