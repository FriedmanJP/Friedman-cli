# Panel Unit Root Tests

Panel unit root tests for data with $N$ cross-sectional units observed over $T$ periods. Wide-format leaves accept CSV data with rows as time periods and columns as units; long panel format needs `--id-col` and `--time-col`. Full option tables live in the generated reference (`generated/test.md`). Wide examples simulate a stationary VAR panel in-block; long examples simulate a panel with `id`/`time` columns in-block — every fence runs standalone.

---

## First- vs second-generation tests

**First-generation** tests (Levin-Lin-Chu, Im-Pesaran-Shin) assume **cross-sectional independence**: a common shock that moves all units together violates the assumption and distorts size. The three tests on this page are **second-generation**: they model the **cross-sectional dependence** explicitly, so they stay valid when units share common factors. Use a first-generation test only after demeaning or when independence is defensible; otherwise start here.

---

## test panel panic

The **PANIC test** (Bai & Ng 2004) decomposes each series into estimated **common factors** and **idiosyncratic components** and tests each part for unit roots separately. **H0**: the idiosyncratic component has a unit root (nonstationary panel after removing the common factors). Rejection means the panel is stationary once common shocks are factored out.

```bash
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test panel panic panel_wide.csv --factors=auto
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test panel panic panel_wide.csv --factors=3 --method=individual
friedman data simulate panel --n 30 --periods 12 --seed 7 --format csv --output panel.csv && friedman test panel panic panel.csv --id-col=id --time-col=time
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | | String | `auto` | Number of factors (`auto` or integer) |
| `--method` | | String | `pooled` | `pooled` (pooled ADF on defactored data), `individual` (unit-by-unit) |
| `--id-col` | | String | | Panel unit ID column (optional) |
| `--time-col` | | String | | Time column (optional) |

`auto` selects the factor count by information criterion; pass an integer to fix it. `pooled` aggregates into one panel-wide verdict, while `individual` reports unit-by-unit evidence.

---

## test unit-root cips

The **CIPS test** (Pesaran 2007) augments each unit's ADF regression with cross-sectional averages of the level and differences (**CADF** regressions), which proxy the unobserved common factor without estimating it. The CIPS statistic is the cross-sectional average of the individual CADF $t$-statistics. **H0**: every unit has a unit root. Rejection means a nonzero fraction of units is stationary.

```bash
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test unit-root cips panel_wide.csv
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test unit-root cips panel_wide.csv --lags=4 --deterministic=trend
friedman data simulate panel --n 30 --periods 12 --seed 7 --format csv --output panel.csv && friedman test unit-root cips panel.csv --id-col=id --time-col=time
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | | String | `auto` | Lag order (`auto` or integer) |
| `--deterministic` | | String | `constant` | `constant`, `trend` |
| `--id-col` | | String | | Panel unit ID column (optional) |
| `--time-col` | | String | | Time column (optional) |

CIPS needs no factor-count choice, which makes it the default second-generation test when the dependence structure is unknown.

---

## test unit-root moon-perron

The **Moon-Perron test** (Moon & Perron 2004) estimates the common factors by principal components, removes them, and applies the modified $t_a^*$ and $t_b^*$ statistics to the defactored data. **H0**: every unit has a unit root. Both statistics are standard normal under H0 with rejection in the left tail; the leaf rejects when either $p$-value is small.

```bash
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test unit-root moon-perron panel_wide.csv
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test unit-root moon-perron panel_wide.csv --factors=2
friedman data simulate panel --n 30 --periods 12 --seed 7 --format csv --output panel.csv && friedman test unit-root moon-perron panel.csv --id-col=id --time-col=time
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | | String | `auto` | Number of factors (`auto` or integer) |
| `--id-col` | | String | | Panel unit ID column (optional) |
| `--time-col` | | String | | Time column (optional) |

---

## test stability factor-break

The **factor-structure break test** asks whether the loadings of a dynamic factor model changed at an unknown date. **H0**: the factor structure is stable over the whole sample. The `--method` selects the test; the pooled methods additionally emit a *Per-Series Break Diagnostics* table ranking each series by its own sup statistic and maximizing date.

```bash
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test stability factor-break panel_wide.csv --factors=2
friedman data simulate var --periods 200 --seed 7 --format csv --output panel_wide.csv && friedman test stability factor-break panel_wide.csv --factors=3 --method=chen_dolado_gonzalo
friedman data simulate panel --n 30 --periods 12 --seed 7 --format csv --output panel.csv && friedman test stability factor-break panel.csv --method=han_inoue --id-col=id --time-col=time
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--factors` | | Int | 2 | Number of factors |
| `--method` | | String | `breitung_eickmeier` | `breitung_eickmeier`, `chen_dolado_gonzalo`, `han_inoue` |
| `--id-col` | | String | | Panel unit ID column (optional) |
| `--time-col` | | String | | Time column (optional) |

`chen_dolado_gonzalo` has no per-series decomposition, so the diagnostics table is absent for it — never an error.

!!! warning "The per-series ranking assumes a modest breaking subset"
    The ranking identifies the breaking series when a modest subset of the panel breaks. A break large enough to rotate the estimated factor space — for example, half the panel flipping sign — elevates the *stable* series' statistics too, because loading breaks are only identified relative to the factor normalization. Under a suspected large break, read the pooled verdict, not the ranking.

### Methods

| Method | Reference |
|--------|-----------|
| `breitung_eickmeier` | Breitung & Eickmeier (2011) |
| `chen_dolado_gonzalo` | Chen, Dolado & Gonzalo (2014) |
| `han_inoue` | Han & Inoue (2015) |

---

## References

- Bai, J., & Ng, S. (2004). "A PANIC Attack on Unit Roots and Cointegration." *Econometrica*, 72(4), 1127--1177.
- Pesaran, M. H. (2007). "A Simple Panel Unit Root Test in the Presence of Cross-Section Dependence." *Journal of Applied Econometrics*, 22(2), 265--312.
- Moon, H. R., & Perron, B. (2004). "Testing for a Unit Root in Panels with Dynamic Factors." *Journal of Econometrics*, 122(1), 81--126.
- Breitung, J., & Eickmeier, S. (2011). "Testing for Structural Breaks in Dynamic Factor Models." *Journal of Econometrics*, 163(1), 71--84.
- Chen, L., Dolado, J. J., & Gonzalo, J. (2014). "Detecting Big Structural Breaks in Large Factor Models." *Journal of Econometrics*, 180(1), 30--48.
- Han, X., & Inoue, A. (2015). "Tests for Parameter Instability in Dynamic Factor Models." *Econometric Theory*, 31(5), 1117--1152.
