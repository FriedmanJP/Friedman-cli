# [Input-Output & Production Networks](@id chap-io)

Classical linear input–output accounting, MRIO database ingestion (`oecd`, `wiod`, `exiobase3`, `eora26`, `gloria`), Leontief/Ghosh multipliers, hypothetical extraction, structural decomposition analysis, and Baqaee–Farhi (2019, 2020) nonlinear general-equilibrium production network analysis live under [`frdc io`](@ref ref-io) across the linear `io` and nonlinear `io bf` families. See [MacroEconometricModels.jl — Input-Output & Networks](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/io/) for mathematical derivations.

## Quick Start

Omit `--data` on any `io` or `io bf` command to run directly on the built-in Miller–Blair 2-sector benchmark (`Agriculture`, `Manufacturing`), inspect the Leontief inverse $L = (I - A)^{-1}$, and solve a Baqaee–Farhi productivity shock:

<!-- capture -->
```bash
frdc io leontief --matrix L
```
```text
             Leontief Inverse (L)
┌───────────────┬─────────────┬───────────────┐
│    sector     │ Agriculture │ Manufacturing │
├───────────────┼─────────────┼───────────────┤
│  Agriculture  │    1.254    │     0.330     │
│ Manufacturing │    0.264    │     1.122     │
└───────────────┴─────────────┴───────────────┘
```

The command returns `leontief_inverse_l` (an extra dollar of agricultural demand induces `1.25412` of total agricultural output and `0.264026` of manufacturing output, or both `technical_coefficients_a` and `leontief_inverse_l` under `--matrix both`; pass `--data <path>` alongside `--n-sectors` and `--n-fd` for custom CSV/ICIO tables).

Every analysis leaf runs offline against the bundled `:wiot` fixture when `--data` is omitted. For multi-step custom workflows, parse raw CSV or OECD ICIO files once with [`io load`](@ref ref-io-load) (or repair/collapse them via [`io balance`](@ref ref-io-balance) and [`io aggregate`](@ref ref-io-aggregate)) using `--save-model <stem.jld2>`, then pass the persisted `IOData` handle to `--data` across downstream multiplier, linkage, footprint, and Baqaee–Farhi commands.

---

## Classical Leontief, Ghosh, Extraction & MRIO Accounting (`io`)

In a $S$-sector open input–output table with intermediate technical matrix $A_{ij} = Z_{ij} / x_j$ and output-allocation matrix $B_{ij} = Z_{ij} / x_i$, gross output $x$ responds to final demand $y$ via the Leontief inverse $L$, while supply-side value-added $v'$ pushes gross output via the Ghosh inverse $G$:

```math
L = (I - A)^{-1}, \quad \Delta x = L \, \Delta y; \qquad G = (I - B)^{-1}, \quad \Delta x' = \Delta v' \, G.
```

| Analytical Group | Subcommands under `frdc io` | Purpose & Key Output Tables (`--format json`) |
|---|---|---|
| Ingestion & Balancing | `sources`, `download`, `load`, `balance` (`ras`\|`gras`), `aggregate` | Catalog & fetch external MRIO datasets (`oecd`, `wiod`, `exiobase3`, `eora26`, `gloria`); balance/aggregate tables (`io_table_summary`, `sectors`) |
| Multipliers & Linkages | `leontief`, `ghosh`, `multipliers` (`output`\|`income`\|`employment`, Type `I`\|`II`), `linkages`, `key-sectors`, `network-stats` | Backward/forward Rasmussen dispersion indices, Domar weights, network centrality (`io_multipliers`, `linkages`, `key_sectors`, `network_stats_summary`) |
| Shocks, Extraction & SDA | `impact`, `price`, `extract` (`complete`\|`backward`\|`forward`\|`partial`), `sda` (`additive`\|`multiplicative`) | Demand/value-added shocks, Leontief/Ghosh price pass-through, sectoral extraction loss, and two-period decomposition (`hypothetical_extraction_loss`, `structural_decomposition`) |
| MRIO Trade & Footprints | `footprint`, `bilateral-trade`, `export-decomposition` (KWW), `vertical-specialization`, `baqaee-farhi` | Embodied emissions/factor footprints (`--account`), Koopman–Wang–Wei export value-added, Hummels vertical specialization, and legacy Hulten 2nd-order decomposition |

<!-- capture -->
```bash
frdc io linkages --forward ghosh
```
```text
                       Linkages (forward=ghosh)
┌───────────────┬──────────┬─────────┬───────┬───────┬────────────────┐
│    sector     │ backward │ forward │  Ui   │  Uj   │ classification │
├───────────────┼──────────┼─────────┼───────┼───────┼────────────────┤
│  Agriculture  │  1.518   │  1.914  │ 1.022 │ 1.208 │      key       │
│ Manufacturing │  1.452   │  1.254  │ 0.978 │ 0.792 │      weak      │
└───────────────┴──────────┴─────────┴───────┴───────┴────────────────┘
```

Under [`io linkages`](@ref ref-io-linkages), each sector is classified (`classification`) using normalized backward dispersion $U_j$ and forward dispersion $U_i$ relative to `1.0` (`Agriculture` has $U_i = 1.02222$, $U_j = 1.20833$ -> `key`, while `Manufacturing` has $0.977778$, $0.791667$ -> `weak`; [`io key-sectors`](@ref ref-io-key-sectors) extracts `key` vs `weak` rankings cleanly).

---

## Baqaee–Farhi Nonlinear Production Networks (`io bf`)

When elasticities of substitution across intermediates ($\theta$), final demand ($\sigma$), nests ($\epsilon$), or primary factors ($\eta$) deviate from Cobb–Douglas (`1.0`), Hulten's linear approximation $\Delta \ln Y \approx \lambda' \Delta \ln A$ breaks down for large shocks or distorted wedges ($\mu_i \neq 1$). [`io bf`](@ref ref-fam-io-bf) builds a calibrated nonlinear CES/nested network (`network`), saves it via `--save-model <path.fmod>`, and solves exact nonlinear counterfactual equilibria:

```math
\frac{d \ln Y}{d \ln A_i} = \lambda_i^{\text{cost}}, \qquad \Delta \ln Y \approx \lambda' \Delta \ln A + \frac{1}{2} \Delta \ln A' \, \Xi \, \Delta \ln A.
```

- [`io bf network`](@ref ref-io-bf-network): Builds network Domar shares (`lambda`, `lambda_rev`, wedges `mu`; supports `--nests single|two`, `--factors single|va-cats`, vector overrides `--theta`, `--mu`).
- [`io bf equilibrium`](@ref ref-io-bf-equilibrium): Solves exact nonlinear counterfactual output `dlogY`, sector quantities `dlog_x`, and prices `dlog_p` for TFP (`--dlog-a`), labor (`--dlog-l`), or markup (`--dlog-mu`) shocks via Newton or fixed-point iteration.
- [`io bf elasticities`](@ref ref-io-bf-elasticities), [`local`](@ref ref-io-bf-local), [`wedges`](@ref ref-io-bf-wedges), [`misallocation`](@ref ref-io-bf-misallocation), [`shock-curve`](@ref ref-io-bf-shock-curve): Computes full general-equilibrium price incidence matrices, second-order Hulten Hessians $\Xi$, distortion-wedge decompositions ($\lambda^{\text{cost}}$ vs. $\lambda^{\text{rev}}$), efficiency misallocation gaps (`--point efficient|observed`), and multi-point shock curves comparing exact nonlinear vs. Hulten linear vs. second-order approximations.

<!-- capture -->
```bash
frdc --quiet io bf network --theta 0.5,1.2 --save-model bf_net.fmod
frdc io bf equilibrium --model bf_net.fmod --dlog-a 0.05,0.0 --method newton
```
```text
 BF Equilibrium Summary
┌──────────────┬───────┐
│    metric    │ value │
├──────────────┼───────┤
│    dlogY     │ 0.024 │
│    hulten    │ 0.024 │
│  technology  │ 0.024 │
│  allocative  │ 0.000 │
│ profit_share │ 0.000 │
│  converged   │ true  │
│  iterations  │   1   │
│   residual   │ 0.000 │
└──────────────┴───────┘
      BF Equilibrium Sectors
┌───────────────┬────────┬────────┐
│    sector     │ dlog_x │ dlog_p │
├───────────────┼────────┼────────┤
│  Agriculture  │ 0.064  │ -0.063 │
│ Manufacturing │ 0.016  │ -0.017 │
└───────────────┴────────┴────────┘
```

The exact nonlinear CES general-equilibrium response outputs scalar aggregate `dlogY = 0.024402` (vs Hulten first-order `0.02439`) and convergence metadata (`bf_equilibrium_summary`) alongside per-sector log changes (`Agriculture` `+0.063594` quantity, `-0.062575` price in `bf_equilibrium_sectors`) using the persisted `.fmod` network handle (`--model bf_net.fmod`).

---

## Common Pitfalls

1. **Forgetting `--n-sectors` when loading custom CSV IO tables:** The built-in 2-sector example runs with zero flags, but custom CSV files passed via `--data` must declare `--n-sectors` (and `--n-fd`, defaulting to `1`).
2. **Expecting Type II (`--type II`) multipliers or `--kind employment` without household/employment rows:** When a CSV matrix omits compensation or employment accounts, employment/Type-II requests fail validation cleanly (`data/*` error).
3. **Treating `maxiter`-truncated `io bf equilibrium` as a CLI error:** Non-convergence inside `io bf equilibrium` reports `converged = false` in `bf_equilibrium_summary` (`exit 0`, result payload) rather than aborting with exit `5`; always check the `converged` row or reduce `--damping`.
4. **Network access and credentials in `io download`:** [`io download`](@ref ref-io-download) is the only network-touching command in the `io` family ([`io sources`](@ref ref-io-sources) runs offline); pass `--offline` in restricted environments to fail cleanly with exit `6` (`env/network`), and supply `--email` and `--password` when fetching `eora26`.
5. **Re-calibrating `io bf` networks on every counterfactual:** Persist a calibrated `ProductionNetwork` once via [`io bf network`](@ref ref-io-bf-network) `--save-model` (`.jld2` native or `.fmod`) and pass `--model` to `equilibrium`, `elasticities`, `local`, `wedges`, `misallocation`, and `shock-curve` so all counterfactuals share identical elasticities and markups.

---

## References

- Miller, R. E., & Blair, P. D. (2009). *Input-Output Analysis: Foundations and Extensions* (2nd ed.). Cambridge University Press.
- Baqaee, D. R., & Farhi, E. (2019). The macroeconomic impact of microeconomic shocks: Beyond Hulten's theorem. *Econometrica*, 87(4), 1155–1203.
- Baqaee, D. R., & Farhi, E. (2020). Productivity and misallocation in general equilibrium. *Quarterly Journal of Economics*, 135(1), 105–163.
- Upstream manual: [MacroEconometricModels.jl — Input-Output & Networks](https://friedmanjp.github.io/MacroEconometricModels.jl/dev/io/)
- CLI reference: [`frdc io`](@ref ref-io), [`frdc io bf network`](@ref ref-io-bf-network), [`frdc io bf equilibrium`](@ref ref-io-bf-equilibrium), [`frdc io bf shock-curve`](@ref ref-io-bf-shock-curve)
