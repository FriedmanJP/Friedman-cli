# estimate

Estimate econometric models, covering VAR, BVAR, VECM, Panel VAR, FAVAR, Structural DFM, systems estimation (SUR/3SLS), cross-sectional regression (OLS/WLS/IV/Logit/Probit), penalized regression (Lasso/Ridge/Elastic-Net), robust (Huber/bisquare M/MM), Tobit censored, truncated-normal and Heckman sample-selection regression, single-equation (FMOLS/CCR/DOLS) and panel (group-mean/pooled) cointegrating regression, single-equation ARDL and nonlinear/asymmetric NARDL, self-exciting threshold autoregression (SETAR, with an attached Hansen 1996 linearity test) and smooth-transition autoregression (STAR: LSTR1/LSTR2/ESTR, Teräsvirta NLS), Markov-switching autoregression (MS-AR, Hamilton mean-switching) and K-state Markov-switching regression (with a wide regime-transition matrix), structural state-space models (local level / local linear trend) and time-varying-parameter regression, nonparametric estimation (kernel density, kernel/local-polynomial regression, LOWESS), panel regression (FE/RE/IV/Logit/Probit), ordered and multinomial choice models, local projections, ARIMA, ARFIMA long memory, GMM, SMM, factor models, univariate volatility models (ARCH/GARCH/EGARCH/GJR-GARCH/SV plus IGARCH/Component-GARCH/APARCH/FIGARCH/FIEGARCH/GARCH-MIDAS), multivariate GARCH (CCC/DCC/BEKK), and non-Gaussian SVAR identification.

Option defaults and choices live in the [generated estimate reference](generated/estimate.md); the tables below summarize the flags each example uses.

---

## Coefficient table format (C051)

Every coefficient-bearing model — `var`, `reg`, `iv`, `logit`, `probit`, `preg`, `piv`,
`plogit`, `pprobit`, `ologit`, `oprobit`, `mlogit` — renders its coefficients through MEMs'
`DataFrame(model)`: a tidy table with the core columns `term | estimate | std_error | stat
| p_value | ci_lower | ci_upper`. `var` prepends `equation` (one row per lag/variable per
equation); the panel models are the same 7 columns as `reg`/`logit`/`probit`; `ologit`/
`oprobit` prepend `block` (coefficients vs. cutpoints); `mlogit` prepends `alternative`
(one block per category, relative to the base). Fit statistics (R², AIC/BIC,
pseudo-R²/log-likelihood, convergence) print as a separate small table alongside the
coefficient table, not merged into it.

---

## estimate multivariate var

Estimate a VAR(p) model via OLS. Lag order is auto-selected via AIC when `--lags` is omitted.

```bash
friedman estimate multivariate var :denmark
friedman estimate multivariate var :denmark --lags=2
friedman estimate multivariate var :denmark --lags=4 --format=csv --output=var_results.csv
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | Lag order |
| `--trend` | | String | `constant` | `none`, `constant`, `trend`, `both` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`equation|term|estimate|std_error|stat|p_value|ci_lower|ci_upper`, [C051](#coefficient-table-format-c051)) via `DataFrame(model)`, plus a small AIC/BIC/HQC/log-likelihood fit-stats table. The `equation` and lag labels carry the CSV column names — a file with `x,y` columns reports equations `x`/`y`, not `y1`/`y2` — and the same names flow into the derived `irf`/`fevd`/`forecast` renderings.

Shown on the bundled Denmark money dataset (`:denmark`); status lines go to stderr, JSON below is stdout only.

<!-- capture -->
```bash
friedman estimate multivariate var :denmark --lags 1 --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "var_coefficients": {
            "columns": [
                "equation",
                "term",
                "estimate",
                "std_error",
                "stat",
                "p_value",
                "ci_lower",
                "ci_upper"
            ],
            "rows": [
                [
                    "LRM",
                    "(Intercept)",
                    3.4288123,
                    0.62645112,
                    5.4733916,
                    1.5808111e-6,
                    2.1692479,
                    4.6883767
                ],
                [
                    "LRM",
                    "LRM.L1",
                    0.75549524,
                    0.083439926,
                    9.0543613,
                    5.8997252e-12,
                    0.58772802,
                    0.92326245
                ],
                [
                    "LRM",
                    "LRY.L1",
                    -0.059877806,
                    0.13484502,
                    -0.44404907,
                    0.65900261,
                    -0.3310019,
                    0.21124628
                ],
                [
                    "LRM",
                    "LPY.L1",
                    0.061270076,
                    0.016870169,
                    3.631859,
                    0.0006827661,
                    0.027350328,
                    0.095189824
                ],
                [
                    "LRM",
                    "IBO.L1",
                    -0.99583584,
                    0.29903095,
                    -3.33021,
                    0.0016745141,
                    -1.5970779,
                    -0.39459383
                ],
                [
                    "LRM",
                    "IDE.L1",
                    -0.39973257,
                    0.47468227,
                    -0.84210553,
                    0.4039052,
                    -1.3541452,
                    0.55468011
                ],
                [
                    "LRY",
                    "(Intercept)",
                    1.5060334,
                    0.51159296,
                    2.9438118,
                    0.0049837046,
                    0.4774068,
                    2.53466
                ],
                [
                    "LRY",
                    "LRM.L1",
                    0.089413611,
                    0.068141436,
                    1.3121768,
                    0.19570109,
                    -0.047593928,
                    0.22642115
                ],
                [
                    "LRY",
                    "LRY.L1",
                    0.58192718,
                    0.11012154,
                    5.2844081,
                    3.0405248e-6,
                    0.36051297,
                    0.80334138
                ],
                [
                    "LRY",
                    "LPY.L1",
                    0.049987127,
                    0.013777068,
                    3.6282848,
                    0.00069020982,
                    0.022286475,
                    0.077687779
                ],
                [
                    "LRY",
                    "IBO.L1",
                    0.25023321,
                    0.24420441,
                    1.0246875,
                    0.31064719,
                    -0.24077268,
                    0.74123909
                ],
                [
                    "LRY",
                    "IDE.L1",
                    -1.1626354,
                    0.38765053,
                    -2.9991844,
                    0.00428128,
                    -1.9420591,
                    -0.38321181
                ],
                [
                    "LPY",
                    "(Intercept)",
                    -0.094685616,
                    0.17432105,
                    -0.543168,
                    0.58952779,
                    -0.44518158,
                    0.25581034
                ],
                [
                    "LPY",
                    "LRM.L1",
                    -0.014622663,
                    0.023218628,
                    -0.62978153,
                    0.53182407,
                    -0.061306843,
                    0.032061517
                ],
                [
                    "LPY",
                    "LRY.L1",
                    0.045399714,
                    0.037523001,
                    1.2099169,
                    0.23223578,
                    -0.030045335,
                    0.12084476
                ],
                [
                    "LPY",
                    "LPY.L1",
                    0.98339248,
                    0.0046944215,
                    209.48108,
                    0,
                    0.97395371,
                    0.99283125
                ],
                [
                    "LPY",
                    "IBO.L1",
                    0.10809135,
                    0.083210624,
                    1.2990091,
                    0.20014629,
                    -0.059214818,
                    0.27539753
                ],
                [
                    "LPY",
                    "IDE.L1",
                    -0.0053550379,
                    0.1320887,
                    -0.040541227,
                    0.9678298,
                    -0.27093716,
                    0.26022709
                ],
                [
                    "IBO",
                    "(Intercept)",
                    -0.35860737,
                    0.23029215,
                    -1.5571846,
                    0.12599625,
                    -0.82164077,
                    0.10442602
                ],
                [
                    "IBO",
                    "LRM.L1",
                    -0.0076093243,
                    0.030673678,
                    -0.24807343,
                    0.80513582,
                    -0.069282887,
                    0.054064238
                ],
                [
                    "IBO",
                    "LRY.L1",
                    0.076430821,
                    0.049570906,
                    1.5418484,
                    0.12967798,
                    -0.023238167,
                    0.17609981
                ],
                [
                    "IBO",
                    "LPY.L1",
                    -0.014373792,
                    0.0062017089,
                    -2.3177147,
                    0.024773914,
                    -0.026843163,
                    -0.0019044205
                ],
                [
                    "IBO",
                    "IBO.L1",
                    1.0100517,
                    0.10992794,
                    9.1883074,
                    3.7541081e-12,
                    0.78902674,
                    1.2310766
                ],
                [
                    "IBO",
                    "IDE.L1",
                    -0.099428345,
                    0.17449981,
                    -0.56979057,
                    0.57147704,
                    -0.45028372,
                    0.25142703
                ],
                [
                    "IDE",
                    "(Intercept)",
                    -0.26118995,
                    0.13949317,
                    -1.872421,
                    0.067246769,
                    -0.54165977,
                    0.019279871
                ],
                [
                    "IDE",
                    "LRM.L1",
                    0.012884448,
                    0.018579742,
                    0.69346756,
                    0.49135843,
                    -0.024472626,
                    0.050241522
                ],
                [
                    "IDE",
                    "LRY.L1",
                    0.01808454,
                    0.030026221,
                    0.60229157,
                    0.54981486,
                    -0.042287224,
                    0.078456304
                ],
                [
                    "IDE",
                    "LPY.L1",
                    -0.0025295012,
                    0.0037565156,
                    -0.67336369,
                    0.50394541,
                    -0.010082482,
                    0.0050234796
                ],
                [
                    "IDE",
                    "IBO.L1",
                    0.21452174,
                    0.066585842,
                    3.221732,
                    0.0022903665,
                    0.080641931,
                    0.34840155
                ],
                [
                    "IDE",
                    "IDE.L1",
                    0.64891228,
                    0.10569849,
                    6.1392768,
                    1.5357806e-7,
                    0.43639122,
                    0.86143333
                ]
            ]
        },
        "information_criteria": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "AIC",
                    -44.683245
                ],
                [
                    "BIC",
                    -43.578254
                ],
                [
                    "HQC",
                    -44.257093
                ],
                [
                    "Log-likelihood",
                    853.33421
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman estimate multivariate var",
    "meta": {
    },
    "error": null
}
```

---

## estimate multivariate bvar

Estimate a Bayesian VAR with MCMC sampling and posterior extraction.

```bash
cat > prior.toml <<'EOF'
[prior]
type = "minnesota"

[prior.hyperparameters]
lambda1 = 0.2
lambda2 = 0.5
lambda3 = 1.0
lambda4 = 100000.0
EOF
friedman estimate multivariate bvar :denmark --lags=4 --draws=2000
friedman estimate multivariate bvar :denmark --lags=2 --config=prior.toml --method=median
friedman estimate multivariate bvar :denmark --lags=2 --sampler=gibbs --draws=5000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 4 | Lag order |
| `--prior` | | String | `minnesota` | Prior type |
| `--draws` | `-n` | Int | 2000 | MCMC draws |
| `--sampler` | | String | `direct` | `direct`, `gibbs` |
| `--method` | | String | `mean` | `mean`, `median` (posterior extraction) |
| `--hyperopt` | | String | `glp` | Minnesota hyperparameter selection: `glp`, `grid` |
| `--config` | | String | | TOML config for prior hyperparameters |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Posterior mean/median coefficient matrix, AIC/BIC/HQC.

See [Configuration](../configuration.md) for Minnesota prior TOML format.

!!! note "Hyperparameter selection (history to ≤0.13.x)"
    `--prior minnesota` (the default) without a `--config` leaves the hyperparameters
    to the library, which runs the full **Giannone, Lenza & Primiceri (2015)**
    joint optimization of the marginal likelihood over the overall, sum-of-coefficients
    and dummy-initial-observation tightness. In earlier releases this was a `tau`-only
    grid search, so **`estimate multivariate bvar` results changed at that point** for runs that do
    not pass `--config`. Supplying `--config` pins the hyperparameters explicitly and is
    unaffected, as is `--prior normal`.

    Only this leaf is affected. The derived BVAR commands (`irf`/`fevd`/`hd`/`forecast`/
    `predict`/`residuals multivariate bvar`, `nowcast bvar`) default to the **normal** prior when no
    `--config` is given, and hyperparameter selection is never reached under that prior.

### Choosing and inspecting the hyperparameters

`--hyperopt grid` restores the older `tau`-only grid search if you need to reproduce
older numbers; `glp` (the default) runs the joint optimization.

Either way the selected values are reported as their own table, which the library itself
does not expose — `BVARPosterior` keeps only the draws, so without this there is no way to
tell what prior the posterior was actually drawn under. The table reports the selected
`tau`, `decay`, `lambda`, `mu` and `omega` alongside `log_ml` (the optimized marginal
likelihood), `log_ml_default` (under the library defaults), `log_posterior`, a
`converged` flag, an `at_bound` flag, and the optimizer iteration count:


Read `log_ml` against `log_ml_default`: that is the marginal-likelihood gain over the
library's default hyperparameters, and it is the only direct evidence the optimization
helped. **`at_bound = 1` deserves more attention than `converged = 0`** — it means a
hyperparameter is pinned to the edge of the search box, so the "optimum" is an artefact of
the box rather than a maximum, and the CLI warns on stderr when it happens.

**Precedence:** an explicit `--config` `[prior]` pins the hyperparameters and the library
then ignores hyperparameter selection entirely, so `--hyperopt` has no effect and no table
is emitted; the CLI says so on stderr rather than letting the flag look effective. Under
`--prior normal` the Minnesota hyperparameters are never consulted at all.

!!! note "`--config` minnesota mapping (history to ≤0.13.x)"
    The config path once passed a length-*n* vector of AR residual standard deviations as
    `omega`, but `omega` is a **scalar** weight on the residual-covariance prior. Per-variable
    σᵢ scaling is the library's own job; the config's `lambda1`/`lambda2`/`lambda3` map to
    `tau`/`lambda`/`decay` and `mu`/`omega` keep the library defaults.

---

## estimate regression qreg

Quantile regression (Koenker–Bassett). Where OLS fits the conditional mean, this fits a
conditional quantile — so it shows whether a covariate acts differently at the bottom and
top of the outcome distribution.

```bash
friedman data simulate cross-section --kind qreg --seed 7 --format csv --output xs.csv
friedman estimate regression qreg xs.csv --dep=y --tau=0.5
friedman estimate regression qreg xs.csv --dep=y --tau=0.1,0.25,0.5,0.75,0.9 --se=robust
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | first numeric column | Dependent variable |
| `--tau` | | String | `0.5` | Quantile(s) in (0,1); one value or a comma-list |
| `--se` | | String | `iid` | `iid`, `robust`, `boot` |
| `--n-boot` | | Int | 500 | Bootstrap replications for `--se boot` |
| `--alpha` | | Float64 | 0.05 | Significance level for the CI |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

Every other numeric column is a regressor, as in `estimate regression reg` — **include a `const_`
column of ones if you want an intercept.** A comma-list fits all quantiles in a single call
and the coefficient table carries a `tau` column, one row per (quantile, term).

Which `--se`: `iid` assumes the errors are identically distributed (fast, but the assumption
that usually motivates quantile regression is that they are not); `robust` uses a
Powell-style sandwich; `boot` resamples. Prefer `robust` or `boot` for real work.

**Reading the output.** Under homoskedastic errors the slopes are the *same* at every
quantile and only the intercept shifts — so quantile-varying slopes are the finding, not the
baseline. `pseudo_r2` is per-quantile and is **not** comparable with an OLS R²: it compares
the check-function objective against an intercept-only fit *at that quantile*.

No `--plot`: upstream ships no plot recipe for `QuantileRegModel` (verified at MEMs 1.0.0).

---

## estimate regression rdd

Regression discontinuity with Calonico–Cattaneo–Titiunik robust bias correction. Units just
above and just below a cutoff are treated as comparable, so the jump in the outcome at the
cutoff identifies the treatment effect.

```bash
cat > rdd.csv <<'EOF'
y,score,enrolled
11.5630,71.6360,1
11.4025,68.4875,1
7.4337,37.7187,0
6.1028,36.8225,0
12.0407,69.2007,1
16.5109,81.2074,1
8.9875,42.1067,0
7.9424,43.0811,0
14.5438,72.9951,1
10.5454,58.2420,0
6.7442,54.9133,0
5.9340,50.9489,0
3.5572,33.8312,0
11.5714,57.2800,0
11.1153,48.0872,0
7.2859,53.3446,0
14.4699,62.4179,1
15.0496,71.0154,1
15.6700,67.4851,1
16.8957,74.5623,1
6.5203,31.0930,0
13.7814,69.2554,1
12.2517,62.5238,1
13.0982,81.0805,1
10.4153,86.3418,1
4.9254,30.7694,0
13.3356,79.6997,1
6.6228,45.1994,0
13.5787,67.4825,1
12.5615,75.8651,1
14.1152,80.8198,1
16.5167,86.4362,1
14.1877,68.0823,1
13.4223,81.5525,1
6.5105,59.8619,0
7.5859,44.0017,0
6.4775,39.6035,0
8.6458,59.8726,0
14.1826,74.7212,1
9.2219,56.9606,0
14.3159,70.8767,1
10.8661,37.5189,0
14.9212,88.3027,1
6.4691,58.4339,0
18.3143,79.6102,1
14.2654,73.7355,1
13.1559,76.8410,1
8.2051,52.9958,0
1.0511,36.6360,0
8.6618,57.3189,0
7.0598,49.8777,0
7.9617,53.9181,0
14.3741,89.5467,1
9.5229,48.5416,0
15.3566,76.9506,1
5.9900,39.9817,0
14.3186,65.6214,1
5.4348,50.8025,0
6.2252,44.5428,0
4.3729,53.5576,0
13.4192,86.0597,1
14.0835,64.7016,1
13.3681,61.0905,1
16.3303,78.2158,1
11.7144,60.2223,1
5.4715,36.7574,0
4.4279,37.8684,0
14.8386,73.1067,1
9.3809,58.0074,0
8.4050,42.5299,0
16.9542,88.0132,1
5.0424,46.2213,0
15.1230,76.9664,1
4.8281,49.0107,0
10.6341,74.7696,1
13.5109,61.6454,1
5.3831,32.1893,0
15.7592,72.7701,1
8.3948,47.5217,0
5.1291,56.0668,0
12.4532,72.8258,1
15.9457,89.7174,1
7.8093,56.8200,0
14.8323,70.3393,1
5.2782,59.1383,0
13.4705,69.9737,1
7.2115,39.5374,0
19.7295,89.6380,1
3.3258,38.6344,0
17.2157,70.0517,1
4.7916,33.9546,0
2.6035,35.2415,0
17.8691,82.4218,1
12.3258,74.9789,1
3.2037,35.7818,0
8.0833,46.8669,0
7.4509,34.2102,0
15.7041,86.1324,1
13.5916,80.7963,1
11.6309,76.6062,1
14.3560,71.9063,1
9.3071,70.3453,1
2.2323,31.9689,0
7.4012,33.3948,0
7.9849,48.0541,0
15.8408,64.6188,1
15.7286,79.7516,1
5.3055,56.5623,0
7.3690,44.9512,0
10.1158,68.0654,1
17.0276,87.1127,1
10.5651,59.1275,0
11.2916,63.7272,1
8.7118,47.3939,0
14.5150,75.2084,1
5.4699,38.7767,0
9.9830,70.1738,1
5.9105,43.1139,0
15.6986,70.5248,1
9.4921,60.1197,1
13.8927,79.4948,1
11.8971,63.9859,1
12.0937,84.4284,1
9.6999,57.0523,0
5.0359,30.9054,0
15.8415,88.5150,1
16.4849,76.1201,1
13.3379,79.3456,1
21.3844,79.6719,1
4.7469,37.5760,0
12.8310,82.4666,1
6.6873,35.0464,0
7.5338,48.5381,0
3.9680,39.6050,0
6.0240,58.9750,0
7.7430,41.3797,0
6.8008,42.6706,0
14.2571,64.7554,1
7.6676,39.6848,0
6.6481,58.9161,0
16.6570,71.6336,1
5.1281,30.9387,0
16.7278,83.0606,1
12.6778,75.2680,1
16.0048,75.1112,1
14.8984,73.4412,1
20.7194,87.6700,1
5.5651,38.6515,0
8.5607,34.9632,0
15.7244,74.3829,1
EOF
friedman estimate regression rdd rdd.csv --outcome=y --running=score --cutoff=60
friedman estimate regression rdd rdd.csv --outcome=y --running=score --cutoff=60 --fuzzy=enrolled
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--outcome` | String | first numeric column | Outcome variable |
| `--running` | String | next numeric column | Running/forcing variable |
| `--fuzzy` | String | | Treatment column for a **fuzzy** design (default: sharp) |
| `--cutoff` | Float64 | 0.0 | Threshold on the running variable |
| `--bandwidth` | Float64 | 0 (auto) | Main bandwidth *h*; 0 uses CCT selection |
| `--bias-bandwidth` | Float64 | 0 (auto) | Bias bandwidth *b*; 0 uses CCT selection |
| `--kernel` | String | `triangular` | `triangular`, `epanechnikov`, `uniform` |
| `--order` | Int | 1 | Local polynomial order |
| `--level` | Float64 | 0.95 | Confidence level |

!!! warning "`--cutoff` defaults to 0"
    That matches the common convention of centring the running variable, but a forgotten
    `--cutoff` on an uncentred variable produces a confident, wrong answer rather than an
    error. The cutoff in force is always echoed on stderr — check it. If the cutoff falls
    outside the running variable's range the CLI refuses (`data/invalid`) rather than fitting
    a one-sided regression.

**Output — the CCT triple.** Three rows, and the relationship between them matters:

| method | estimate | interpretation |
|---|---|---|
| `conventional` | τ̂ | the local-polynomial estimate, biased at the boundary |
| `bias-corrected` | τ̂<sup>bc</sup> | bias removed, but its CI understates uncertainty |
| `robust` | τ̂<sup>bc</sup> | **same point estimate**, wider SE accounting for having estimated the bias |

`robust` is not a third estimate — it is the bias-corrected point with honest inference, and
it is the row to report. `bias-corrected` deliberately has no CI here, because a
conventional interval around it is the one CCT warn against.

The settings table reports the selected bandwidths and `n_left`/`n_right` — the **effective**
observations inside the bandwidth, not the full sample. A handful of effective points makes
the estimate fragile no matter how tight the interval looks, and the CLI warns below 10 per
side.

For a fuzzy design, `--fuzzy` names the actual-treatment column and `first_stage` reports the
jump in treatment probability at the cutoff. A weak first stage inflates the ratio estimate
exactly as a weak instrument does.

No `--plot`: upstream ships no plot recipe for `RDDResult` (verified at MEMs 1.0.0).

---

## estimate multivariate tvpvar

Time-varying-parameter VAR with stochastic volatility (Primiceri 2005): both the
coefficients and the shock volatilities drift as random walks, estimated by Gibbs sampling.

```bash
friedman estimate multivariate tvpvar :denmark --lags=2 --draws=2000 --burnin=1000
friedman estimate multivariate tvpvar :denmark --lags=2 --draws=2000 --burnin=1000 --no-sv   # drifting coefficients, constant volatility
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order |
| `--draws` | `-n` | Int | 2000 | Retained Gibbs draws |
| `--burnin` | | Int | 1000 | Burn-in sweeps discarded |
| `--thin` | | Int | 1 | Keep every k-th draw |
| `--n-train` | | Int | 0 | Training sample used to calibrate priors |
| `--k-q` / `--k-s` / `--k-w` | | Float64 | 0.01 / 0.1 / 0.01 | Random-walk prior scales (> 0) |
| `--no-tvp` | | Flag | | Hold coefficients constant |
| `--no-sv` | | Flag | | Hold volatilities constant |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** the stochastic-volatility path in tidy long form (`period`, `variable`, `mean`,
`q16`, `q50`, `q84`) plus a specification summary.

The volatility column is a **standard deviation**, σ*ᵢₜ* = exp(*hᵢₜ*/2). The sampler's state
is a log-*variance*, so a number quoted straight off the state would be wrong by a square
and a log; the CLI converts.

Requires at least 2 variables. There is no `--plot`: upstream ships no plot recipe for `TVPVARPosterior` (verified at MEMs 1.0.0).

---

## irf tvpvar

The IRF of a TVP-VAR is **different at every date** — that time variation is the reason to
fit one — so `--date` is required rather than quietly defaulting to the end of the sample.

```bash
friedman irf tvpvar :denmark --date=40 --horizons=20
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--date` | | Int | | **Required.** Date index in `1:T_eff` |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--irf-draws` | | Int | 500 | Posterior draws used for the bands |
| `--no-stationary-only` | | Flag | | Include explosive draws instead of discarding them |

Estimation options (`--lags`, `--draws`, `--burnin`, `--thin`, `--n-train`, `--k-q`/`--k-s`/`--k-w`,
`--no-tvp`, `--no-sv`) match `estimate multivariate tvpvar`.

`--date` indexes the **effective** sample, after lags and any training observations — run
`estimate multivariate tvpvar` first and read `T_eff` from the specification table. A missing `--date` is
rejected before the sampler runs; an out-of-range one can only be caught afterwards, since
`T_eff` is not known until then.

By default explosive posterior draws are discarded. If *every* draw is explosive at the
requested date the command fails with `model/error` naming `--no-stationary-only` as the
escape hatch — that is a modelling outcome, not a bug.

---

## estimate multivariate mfvar

Mixed-frequency VAR (Schorfheide & Song 2015). Series observed at different frequencies are
combined in a single high-frequency VAR, with the low-frequency series treated as a latent
high-frequency process observed only periodically.

```bash
cat > mf.csv <<'EOF'
monthly,q1,q2
1.3507,,
1.1535,,
-0.4709,2.2230,-0.4926
-0.4696,,
-0.6212,,
-0.6004,-1.6165,-0.6919
0.2366,,
-1.1371,,
0.2844,-0.4503,-0.0213
-0.9573,,
-0.7628,,
0.4293,-1.0211,-0.5844
0.9212,,
-0.1383,,
1.6859,2.0525,0.2033
1.3771,,
-0.1282,,
-0.0344,1.9759,-0.3499
-0.8517,,
-0.0768,,
-1.3879,-2.3781,-1.5877
-0.3527,,
-1.9821,,
-0.0926,-2.9386,-0.9391
0.2166,,
1.4865,,
0.1814,1.7871,-0.4386
-1.9856,,
-2.5610,,
-1.7792,-5.6061,-1.3792
0.8963,,
1.1096,,
1.9776,4.4362,0.8676
0.3088,,
-0.3463,,
-0.5407,-0.3721,-0.7819
0.8449,,
-0.0578,,
-0.3256,0.3844,-0.2946
1.4256,,
-0.0174,,
-0.0433,0.9177,0.2032
-1.3704,,
-1.0580,,
0.1946,-3.0337,-0.0419
1.3093,,
-0.6061,,
-2.8889,-2.3399,-1.4528
-1.1947,,
0.9504,,
-0.1304,-1.0037,0.2146
0.1863,,
0.1385,,
-2.0737,-2.2513,-1.3895
-3.9146,,
-2.4158,,
-0.9634,-7.8264,-0.7267
-2.0951,,
-1.5842,,
-1.7437,-5.2858,0.5290
-2.0101,,
-2.4968,,
-0.3280,-6.2099,0.2437
-0.1862,,
-0.3454,,
-0.6967,-0.8336,0.3417
EOF
friedman estimate multivariate mfvar mf.csv --freq-ratio=3 --aggregation=average
friedman estimate multivariate mfvar mf.csv --low-freq=2,3 --aggregation=growth,flow
```

**Data layout.** One CSV at the **high** frequency. A low-frequency series occupies a normal
column, blank in the periods where it is not observed:

```csv
monthly,quarterly
0.31,
0.28,
0.44,0.34
0.19,
```

Unlike every other loader this one *keeps* the gaps — they are the signal, not bad data. The
blank must be a genuinely empty cell in a multi-column row; a blank line is an empty row that
CSV parsing skips entirely, which would silently shorten the series instead.

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order |
| `--low-freq` | | String | | 1-based indices of low-frequency columns (default: those with gaps) |
| `--freq-ratio` | | Int | 3 | High- per low-frequency periods (3 = monthly/quarterly) |
| `--aggregation` | | String | `growth` | `stock`, `flow`, `average`, `growth` — one, or one per low-frequency series |
| `--draws` | `-n` | Int | 1000 | Retained Gibbs draws |
| `--burnin` | | Int | 500 | Burn-in sweeps discarded |
| `--prior` | | String | `minnesota` | `minnesota`, `diffuse` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

`--aggregation` states how the low-frequency observation relates to the latent
high-frequency path: `stock` (end-of-period level), `flow` (sum), `average` (mean), or
`growth` (the triangular weighting appropriate to log-differences). Getting this wrong
misstates the observation equation, so it is worth being deliberate about.

**Output:** the latent high-frequency path in tidy long form (`period`, `variable`, `mean`,
`q16`, `q50`, `q84`) plus a specification summary. The path covers **every** series at the
high frequency, including the interpolated ones — that interpolation is the point of the
model. Fully-observed series come back with zero-width bands, which is a useful sanity check.

No `--plot`: upstream ships no plot recipe for `MFVARPosterior` (verified at MEMs 1.0.0).

!!! note "Seeding"
    `estimate_tvpvar` and `estimate_mfvar` take an RNG rather than a seed, so `--seed`
    cannot be recorded in the result's reproducibility manifest the way it is for
    `estimate multivariate bvar`. Runs remain reproducible through the global seed the CLI sets.

---

## estimate multivariate lp

Estimate local projections with 6 method variants.

### Standard LP (Jorda 2005)

```bash
friedman estimate multivariate lp :denmark --shock=1 --horizons=20 --vcov=newey_west
```

### LP-IV (Stock & Watson 2018)

```bash
friedman data simulate lp-iv --seed 7 --format csv --output lpiv.csv
cut -d, -f2- lpiv.csv > lp.csv
cut -d, -f5 lpiv.csv > z.csv
friedman estimate multivariate lp lp.csv --method=iv --shock=1 --instruments=z.csv
```

### Smooth LP (Barnichon & Brownlees 2019)

```bash
friedman estimate multivariate lp :denmark --method=smooth --shock=1 --horizons=20
friedman estimate multivariate lp :denmark --method=smooth --shock=1 --lambda=0.5 --knots=4
```

When `--lambda=0` (default), the smoothing parameter is auto-selected via cross-validation.

### State-Dependent LP (Auerbach & Gorodnichenko 2013)

```bash
friedman estimate multivariate lp :denmark --method=state --shock=1 --state-var=2 --gamma=1.5
```

### Propensity Score LP (Angrist et al. 2018)

```bash
friedman estimate multivariate lp :denmark --method=propensity --treatment=1 --score-method=logit
```

### Doubly Robust LP

```bash
friedman estimate multivariate lp :denmark --method=robust --treatment=1 --score-method=logit
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--method` | | String | `standard` | `standard`, `iv`, `smooth`, `state`, `propensity`, `robust` |
| `--shock` | | Int | 1 | Shock variable index (1-based) |
| `--horizons` | `-h` | Int | 20 | IRF horizon |
| `--control-lags` | | Int | 4 | Number of control lags |
| `--vcov` | | String | `newey_west` | `newey_west`, `white`, `driscoll_kraay` |
| `--instruments` | | String | | Path to instruments CSV (iv only) |
| `--knots` | | Int | 3 | B-spline knots (smooth only) |
| `--lambda` | | Float64 | 0.0 | Smoothing penalty, 0=auto CV (smooth only) |
| `--state-var` | | Int | | State variable index (state only, required) |
| `--gamma` | | Float64 | 1.5 | Transition steepness (state only) |
| `--transition` | | String | `logistic` | `logistic`, `exponential`, `indicator` (state only) |
| `--treatment` | | Int | 1 | Treatment variable index (propensity/robust only) |
| `--score-method` | | String | `logit` | `logit`, `probit` (propensity/robust only) |
| `--mop-f` | | Flag | off | Report the Montiel Olea-Pflueger effective first-stage F (iv only) |
| `--mop-tau` | | Float64 | 0.10 | MOP worst-case relative-bias target: `0.05`, `0.10`, `0.20`, `0.30` |
| `--mop-bandwidth` | | Int | 0 | HAC lag length for the effective F; 0 = auto |
| `--ar-bands` | | Flag | off | Report weak-instrument-robust Anderson-Rubin IRF bands (iv only) |
| `--ar-level` | | Float64 | 0.95 | Coverage of the AR bands |
| `--ar-grid` | | Int | 401 | Grid points per horizon × response when inverting the AR test |
| `--ar-span` | | Float64 | 20.0 | AR search half-width, in 2SLS standard errors |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

### Weak-instrument-robust LP-IV

The LP-IV summary always reports the per-horizon first-stage F — as a **minimum over horizons**, because LP-IV re-estimates the first stage at every `h` and the binding one is the weakest. Two stronger diagnostics are available on `--method iv`, both off by default (the AR bands invert a test over a grid at every horizon × response and are far from free):

```bash
friedman data simulate lp-iv --seed 7 --format csv --output lpiv.csv
cut -d, -f2- lpiv.csv > lp.csv
cut -d, -f5 lpiv.csv > z.csv
# Montiel Olea-Pflueger effective F — the correct weak-IV statistic under heteroskedasticity
friedman estimate multivariate lp lp.csv --method=iv --shock=1 --instruments=z.csv --mop-f --mop-tau=0.10

# Anderson-Rubin bands — correct coverage at ANY instrument strength
friedman estimate multivariate lp lp.csv --method=iv --shock=1 --instruments=z.csv --ar-bands --ar-level=0.95
```

`--mop-f` emits a **Montiel Olea-Pflueger Effective F** table (`f_effective`, `critical_value`, `tau`, `weak`, `n_instruments`, `bandwidth`, `f_naive`). The effective F is the statistic to act on: the naive first-stage F is valid only under homoskedasticity, and the two diverge exactly when it matters. The critical values are MOP's *simplified* (nuisance-parameter-free) ones — conservative upper bounds — so a pass is a genuine pass.

`--ar-bands` emits **LP-IV Anderson-Rubin Bands**, one row per horizon × response: `horizon | response | irf | ar_lower | ar_upper | n_components | bounded | is_empty | wald_lower | wald_upper | bandwidth`. Both the AR set and the 2SLS Wald band are reported side by side because **the contrast between them is the diagnostic**. `ar_lower`/`ar_upper` may be `±Inf` (rendered as `"-Inf"`/`"Inf"` in JSON): an unbounded cell means the instrument cannot bound the response at that horizon, and the Wald band there is over-confident rather than merely wide. The HAC bandwidth scales with the horizon (`max(auto, h+1)`), since horizon-`h` LP residuals are MA(`h`) by construction; the value actually used is reported per cell.

One row per horizon × response means the shock variable appears as a response to itself. At `h=0` that response is **identically 1 with zero standard error**, so both the Wald band and the AR set legitimately collapse to the single point `{1}` (`ar_lower == ar_upper == wald_lower == wald_upper == 1`). That cell is correct output, not a degenerate failure — do not read a zero-width interval there as a bug.

Both option groups are rejected with a typed `usage/invalid` under any other `--method` — silently ignoring them would let an agent believe it received robust bands it never got.

---

## estimate univariate arima

Estimate ARIMA(p,d,q) models. Auto-selects order via information criteria when `--p` is omitted.

```bash
# Auto-selection
friedman estimate univariate arima :nile --criterion=bic

# Explicit order
friedman estimate univariate arima :nile --p=1 --d=1 --q=1

# Specific column of a multivariate file
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > macro.csv
friedman estimate univariate arima macro.csv --column=2 --p=2 --d=0 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | auto | AR order |
| `--d` | | Int | 0 | Differencing order |
| `--q` | | Int | 0 | MA order |
| `--max-p` | | Int | 5 | Max AR order for auto selection |
| `--max-d` | | Int | 2 | Max differencing order for auto selection |
| `--max-q` | | Int | 5 | Max MA order for auto selection |
| `--criterion` | | String | `bic` | `aic`, `bic` |
| `--method` | `-m` | String | `css_mle` | `ols`, `css`, `mle`, `css_mle` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** AR/MA coefficients, AIC/BIC/log-likelihood.

---

## estimate univariate sarima

Multiplicative seasonal ARIMA, `SARIMA(p,d,q)(P,D,Q)[s]`.

```bash
# monthly data with a seasonal AR term
friedman estimate univariate sarima :nile --p 1 --q 0 --P 1 --Q 0 --s 12

# let the library choose the orders (and d/D) for a quarterly series
friedman estimate univariate sarima :nile --s 4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | (auto) | Non-seasonal AR order — **omit to auto-select** |
| `--d` / `--q` | | Int | 0 | Non-seasonal differencing / MA order |
| `--P` / `--D` / `--Q` | | Int | 0 | Seasonal AR / differencing / MA order |
| `--s` | | Int | 12 | Seasonal period (12 monthly, 4 quarterly) |
| `--max-p`/`--max-q`/`--max-P`/`--max-Q` | | Int | 2/2/1/1 | Auto search bounds |
| `--criterion` | | String | `aic` | `aic`, `bic` (auto selection) |
| `--method` | | String | `css_mle` | `css_mle`, `mle`, `css` |
| `--max-iter` | | Int | 500 | Maximum optimiser iterations |
| `--auto` | | Flag | off | Force auto selection even when orders are given |
| `--no-intercept` | | Flag | off | Exclude the intercept |
| `--plot` / `--plot-save` | | Flag/String | | Plot the fitted model |

**Omitting `--p` means "select automatically"** — the same convention as
[`estimate univariate arima`](#estimate-arima). In that mode the library also chooses `d` and `D` by
seasonal/regular unit-root testing unless you pin them. `--auto` forces selection even when
orders are supplied.

`--s` must be ≥ 2 whenever any of `--P`/`--D`/`--Q` is positive; a seasonal order with `--s 1`
is rejected as a data error rather than silently fitting a non-seasonal model.

**Output:** coefficient table (`intercept`, `ar*`, `ma*`, `sar*`, `sma*`, `sigma2` — seasonal
terms are labelled `sar`/`sma` to keep them distinct from their non-seasonal counterparts) and
information criteria. `predict univariate sarima` / `residuals univariate sarima` give in-sample fitted values and
residuals; [`forecast univariate sarima`](forecast.md) forecasts through both differencing operators.

---

## estimate univariate arfima

Estimate ARFIMA(p,d,q) fractionally-integrated (long-memory) models. The fractional
integration order `d ∈ (−0.5, 0.5)` is estimated (starting from a GPH pre-estimate
unless `--d0` is given); `p` and `q` are the short-memory AR and MA orders.

```bash
# Pure fractional noise ARFIMA(0,d,0)
friedman estimate univariate arfima :nile --p=0 --q=0

# ARFIMA(1,d,1) via exact Gaussian ML
friedman estimate univariate arfima :nile --p=1 --q=1 --method=mle

# Custom starting value for d
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > macro.csv
friedman estimate univariate arfima macro.csv --column=2 --d0=0.2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 0 | AR order |
| `--q` | | Int | 0 | MA order |
| `--method` | `-m` | String | `css` | `css` (conditional sum of squares), `mle` (exact Gaussian ML) |
| `--d0` | | Float64 | GPH pre-estimate | Starting value for d |
| `--max-iter` | | Int | 500 | Maximum optimizer iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a hand-built coefficient table (`const`, `d`, `ar*`, `ma*` with standard
errors, z-stats, p-values) plus a diagnostics block (d estimate and its standard
error, log-likelihood, AIC/BIC, convergence). `ARFIMAModel` is not one of MEMs'
coefficient-table types, so — like `estimate univariate arima` and the volatility models — the
coefficient table is emitted directly rather than via the tidy `DataFrame(model)`
path (a documented C051 exception).

---

## estimate regression gmm

Estimate a GMM model. Requires a TOML config specifying moment conditions and instruments.

```bash
cat > gmm_spec.toml <<'EOF'
[gmm]
dep = "y"
endogenous = ["x2"]
exogenous = ["x1"]
instruments = ["z1", "z2", "z3"]
theta0 = [0.0, 0.0, 0.0]
weighting = "twostep"
EOF
friedman data simulate gmm --kind iv --seed 7 --format csv --output gmm.csv
friedman estimate regression gmm gmm.csv --config=gmm_spec.toml --weighting=twostep
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | (required) | TOML config file |
| `--weighting` | `-w` | String | `twostep` | `identity`, `optimal`, `twostep`, `iterated` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates, J-test for overidentification.

See [Configuration](../configuration.md) for GMM TOML format.

---

## estimate regression smm

Estimate via Simulated Method of Moments (SMM): parameters are chosen so that moments of
data **simulated** from a parametric model match the moments of the observed data.

Because SMM needs a data-generating model to simulate from, `--config` is **required** — the
`[smm]` section names one of the built-in simulators (`ar1`, `arp`, `var1`, `iid_normal`) and
its initial parameter vector `theta0`. Moments are the autocovariance moments
(`autocovariance_moments`); two-step estimation uses the optimal HAC weighting matrix, and
`--seed` pins the simulation draws for a reproducible fit.

```bash
cat > smm_ar1.toml <<'EOF'
[smm]
model = "ar1"
theta0 = [0.4, 0.5]
lags = 2
EOF
cat > smm_var1.toml <<'EOF'
[smm]
model = "var1"
theta0 = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 1.0, 1.0, 1.0, 1.0, 1.0]
lags = 3
EOF
friedman estimate regression smm :nile --config=smm_ar1.toml
friedman --seed 42 estimate regression smm :denmark --config=smm_var1.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--config` | | String | | **Required.** TOML with `[smm]` (`model`, `theta0`, …) |
| `--weighting` | | String | `two_step` | `identity` or `two_step` (config `weighting` overrides) |
| `--sim-ratio` | | Int | 5 | Simulation-to-sample ratio (config `sim_ratio` overrides) |
| `--burn` | | Int | 100 | Burn-in periods (config `burn` overrides) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Parameter estimates with standard errors, t-statistics, and p-values (rows named
by the model's parameters, e.g. `phi`/`sigma`). Status stream reports the J-statistic,
J p-value, and convergence.

See [Configuration](../configuration.md#smm-specification) for the `[smm]` TOML schema and the
per-model `theta0` layouts.

---

## estimate factor static

Estimate a static factor model via PCA. Factor count is auto-selected via Bai-Ng information criteria when `--nfactors` is omitted.

```bash
friedman estimate factor static :denmark
friedman estimate factor static :denmark --nfactors=3 --criterion=ic2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto (IC) | Number of factors |
| `--criterion` | | String | `ic1` | `ic1`, `ic2`, `ic3` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Scree data (eigenvalues, variance shares), factor loadings.

---

## estimate factor dynamic

Estimate a dynamic factor model with a factor VAR.

```bash
friedman estimate factor dynamic :denmark --nfactors=2 --factor-lags=1
friedman estimate factor dynamic :denmark --nfactors=2 --method=em
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto | Number of factors |
| `--factor-lags` | `-p` | Int | 1 | Factor VAR lag order |
| `--method` | | String | `twostep` | `twostep`, `em` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Factor loadings, companion matrix eigenvalues, stationarity check.

---

## estimate factor gdfm

Estimate a generalized dynamic factor model (spectral method).

```bash
friedman estimate factor gdfm :denmark --dynamic-rank=2
friedman estimate factor gdfm :denmark --nfactors=3 --dynamic-rank=2
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--nfactors` | `-r` | Int | auto | Number of static factors |
| `--dynamic-rank` | `-q` | Int | auto | Dynamic rank |
| `--spectral` | | String | `lag-window` | Spectrum: `lag-window` (FHLR), `smoothed-periodogram` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Common variance shares per variable, average common variance share.

---

## estimate volatility arch

Estimate an ARCH(q) volatility model.

```bash
friedman estimate volatility arch :nile --column=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha), persistence, unconditional variance.

---

## estimate volatility garch

Estimate a GARCH(p,q) volatility model.

```bash
friedman estimate volatility garch :nile --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order |
| `--q` | | Int | 1 | ARCH order |
| `--dist` | | String | `normal` | Conditional distribution: `normal`, `student`, `ged` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha, beta), persistence, half-life, unconditional variance.

### Conditional distributions (`--dist`)

By default the innovations are Gaussian. `--dist student` (Student's *t*) or `--dist ged`
(generalised error distribution) fits a fat-tailed conditional likelihood instead, estimating
the shape parameter **jointly** with the volatility parameters.

Because the shape sits outside the coefficient vector, it is reported in its own
**Conditional Distribution** table — the *t* degrees of freedom, or the GED shape — rather
than as another coefficient row. Nothing extra is emitted under the Gaussian default.

**`--dist` is only offered where the library supports it: `garch`, `egarch` and `gjr-garch`.**
It is deliberately absent from `arch`, `sv`, `igarch`, `cgarch` and `aparch`, which take no
conditional-distribution argument at all, and from `figarch`/`fiegarch`, which accept the
argument but implement Gaussian QMLE only. Passing `--dist` to any of those is a usage error
rather than a silently ignored option.

---

## estimate volatility egarch

Estimate an EGARCH(p,q) volatility model.

```bash
friedman estimate volatility egarch :nile --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | EGARCH order |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha, gamma, beta), persistence.

---

## estimate volatility gjr-garch

Estimate a GJR-GARCH(p,q) volatility model with asymmetric leverage effects.

```bash
friedman estimate volatility gjr-garch :nile --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order |
| `--q` | | Int | 1 | ARCH order |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, omega, alpha, gamma, beta), persistence, half-life.

---

## estimate volatility sv

Estimate a Stochastic Volatility model via MCMC.

```bash
friedman estimate volatility sv :nile --column=1 --draws=5000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--draws` | `-n` | Int | 5000 | MCMC draws |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficients (mu, phi, sigma_eta), persistence (phi).

---

## estimate volatility igarch

Estimate an Integrated GARCH(p,q) model — GARCH with the persistence constraint `Σα + Σβ = 1` imposed exactly (a shock to variance never dies out; the RiskMetrics EWMA is the `ω=0` special case).

```bash
friedman estimate volatility igarch :nile --column=1 --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order p |
| `--q` | | Int | 1 | ARCH order q |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter | estimate | std_error | z_stat | p_value`; parameters `mu, omega, alpha…, beta…`) plus a `metric | value` diagnostics table (`log_likelihood, aic, bic, persistence` = 1, `converged, iterations`).

---

## estimate volatility cgarch

Estimate a Component-GARCH(1,1) model (Engle & Lee 1999) decomposing the conditional variance into a slowly mean-reverting permanent component and a fast transitory component. Orders are fixed at (1,1).

```bash
friedman estimate volatility cgarch :nile --column=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, rho, phi, alpha, beta`) plus diagnostics (`log_likelihood, aic, bic, persistence` = ρ, `converged, iterations, transitory_persistence` = α+β, `unconditional_variance` = ω).

---

## estimate volatility aparch

Estimate an Asymmetric Power ARCH(p,q) model (Ding, Granger & Engle 1993) with a free power `δ` of the conditional standard deviation and a Box-Cox-style leverage term. Pin `δ` and/or `γ` with `--fix-delta` / `--fix-gamma`.

```bash
friedman estimate volatility aparch :nile --column=1 --p=1 --q=1
friedman estimate volatility aparch :nile --column=1 --fix-delta=2 --fix-gamma=0   # ≡ GARCH
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH order p |
| `--q` | | Int | 1 | ARCH order q |
| `--fix-delta` | | Float64 | (auto) | Pin power δ (>0); default estimates it |
| `--fix-gamma` | | Float64 | (auto) | Pin leverage γ ∈ (-1,1); default estimates it |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, alpha…, gamma…, beta…, delta`) plus diagnostics (`log_likelihood, aic, bic, persistence, converged, iterations, delta, n_params`).

---

## estimate volatility figarch

Estimate a Fractionally-Integrated GARCH(p,d,q) model (Baillie, Bollerslev & Mikkelsen 1996) — long-memory volatility with hyperbolic decay via the fractional-difference order `d ∈ (0,1)`. Gaussian QMLE (`--dist normal`).

```bash
friedman estimate volatility figarch :nile --column=1 --p=1 --q=1 --d0=0.4 --truncation=1000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH β(L) order p |
| `--q` | | Int | 1 | ARCH φ(L) order q |
| `--d0` | | Float64 | 0.4 | Initial fractional-integration order d ∈ (0,1) |
| `--truncation` | | Int | 1000 | ARCH(∞) truncation lag |
| `--dist` | | String | `normal` | Innovation distribution (Gaussian QMLE) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, phi…, beta…, d`) plus diagnostics (`log_likelihood, aic, bic, persistence` = d, `converged, iterations, d, truncation, n_neg_lambda`).

---

## estimate volatility fiegarch

Estimate a Fractionally-Integrated EGARCH(p,d,q) model (Bollerslev & Mikkelsen 1996) — the log-variance long-memory analogue of FIGARCH with an EGARCH news function (sign term `θ`, magnitude term `γ`). Gaussian QMLE.

```bash
friedman estimate volatility fiegarch :nile --column=1 --p=1 --q=1 --d0=0.4 --truncation=1000
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | Column index (1-based) |
| `--p` | | Int | 1 | GARCH β(L) order p |
| `--q` | | Int | 1 | ARCH φ(L) order q |
| `--d0` | | Float64 | 0.4 | Initial fractional-integration order d ∈ (0,1) |
| `--truncation` | | Int | 1000 | MA(∞) truncation lag |
| `--dist` | | String | `normal` | Innovation distribution (Gaussian QMLE) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, omega, theta, gamma, phi…, beta…, d`) plus diagnostics (`log_likelihood, aic, bic, persistence` = d, `converged, iterations, d, truncation`).

---

## estimate volatility garch-midas

Estimate a GARCH-MIDAS model (Engle, Ghysels & Sohn 2013): a mixed-frequency model splitting the conditional variance `σ² = τ·g` into a short-run unit-mean GARCH(1,1) component `g` and a long-run MIDAS-filtered component `τ`. `--m-freq` (high-frequency observations per low-frequency block) is **required**. With `--rv realized` the long-run driver is realized variance computed from the returns (no extra input); with `--rv macro` supply an exogenous low-frequency driver via `--config` (a `[garch_midas]` TOML section — see [Configuration](../configuration.md)).

```bash
cat > gm.toml <<'EOF'
[garch_midas]
x_lf = [0.50, 0.60, 0.70, 0.80, 0.90, 0.50, 0.60, 0.70, 0.80, 0.90, 0.50, 0.60, 0.70, 0.80, 0.90, 0.50, 0.60, 0.70, 0.80, 0.90]
EOF
# realized-variance driver (self-contained)
friedman data simulate garch --periods 400 --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > ret.csv
friedman estimate volatility garch-midas ret.csv --column=1 --m-freq=22 --k=12
# exogenous macro driver
friedman estimate volatility garch-midas ret.csv --column=1 --m-freq=22 --rv=macro --config=gm.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | High-frequency return series column (1-based) |
| `--m-freq` | | Int | 0 | High-frequency observations per low-frequency block (**required**, ≥1) |
| `--k` | | Int | 12 | Number of MIDAS lags (K ≥ 2) |
| `--rv` | | String | `realized` | Long-run driver: `realized` (from returns) or `macro` (exogenous) |
| `--span` | | String | `fixed` | τ span: `fixed` (per block) or `rolling` (rolling RV) |
| `--config` | | String | | TOML with `[garch_midas] x_lf = [...]` (required for `--rv macro`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (parameters `mu, alpha, beta, m, theta, w`) plus diagnostics (`log_likelihood, aic, bic, persistence` = α+β, `converged, iterations, variance_ratio, K, m_freq, n_blocks, rv, span`).

---

## Multivariate GARCH

`estimate volatility ccc`, `estimate volatility dcc`, and `estimate volatility bekk` fit **multivariate** volatility models over the full numeric matrix (T×n, columns are series — there is no `--column`; use at least 2 numeric columns). Each headline output is the **conditional correlation matrix** rendered wide (series×series — the same documented exception as the input-output family), followed by a second-stage dynamics-coefficient table (omitted for CCC, which has none) and a diagnostics block (`loglik, aic, bic, series, observations, converged, kind`). A single-column input, a series with a missing cell, or a non-finite value surfaces a typed `data/*` error rather than an internal failure.

---

## estimate volatility ccc

Estimate a **Constant Conditional Correlation** (Bollerslev 1990) MGARCH: a univariate GARCH(p,q) margin per series with a single constant correlation matrix. No second-stage optimization (the correlation is the closed-form standardized-residual correlation).

```bash
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > returns.csv
friedman estimate volatility ccc returns.csv --p=1 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--p` | | Int | 1 | GARCH order p for the univariate margins |
| `--q` | | Int | 1 | ARCH order q for the univariate margins |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Conditional correlation matrix (wide) + diagnostics (no dynamics table — CCC has no second-stage parameters).

---

## estimate volatility dcc

Estimate a **Dynamic Conditional Correlation** (Engle 2002) MGARCH with time-varying correlations, or the **cDCC** correction of Aielli (2013) via `--correction=aielli`. Reports the `[a, b]` correlation dynamics with QML sandwich standard errors and the last-period conditional correlation matrix.

```bash
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > returns.csv
friedman estimate volatility dcc returns.csv --p=1 --q=1
friedman estimate volatility dcc returns.csv --p=1 --q=1 --correction=aielli   # cDCC
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--p` | | Int | 1 | GARCH order p for the univariate margins |
| `--q` | | Int | 1 | ARCH order q for the univariate margins |
| `--correction` | | String | `none` | DCC targeting correction: `none` or `aielli` (cDCC) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Last-period conditional correlation matrix (wide) + dynamics coefficients (`a`, `b`) + diagnostics (adds `correction`, `persistence` = a+b).

---

## estimate volatility bekk

Estimate a **BEKK(1,1)** (Engle & Kroner 1995) MGARCH, modelling the conditional covariance directly with variance targeting. `--kind=scalar` (default) estimates two news/persistence scalars `a, b`; `--kind=diagonal` estimates per-series `aᵢ, bᵢ`.

```bash
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > returns.csv
friedman estimate volatility bekk returns.csv --kind=scalar
friedman estimate volatility bekk returns.csv --kind=diagonal
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--kind` | | String | `scalar` | BEKK(1,1) parameterization: `scalar` or `diagonal` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Unconditional correlation matrix (wide) + dynamics coefficients (`a`, `b` for scalar; `aᵢ`, `bᵢ` for diagonal) + diagnostics (adds `bekk_kind`).

---

## estimate factor fastica

ICA-based non-Gaussian SVAR identification. Supports 5 ICA methods.

```bash
friedman estimate factor fastica :denmark --method=fastica --contrast=logcosh
friedman estimate factor fastica :denmark --method=jade
friedman estimate factor fastica :denmark --method=sobi
friedman estimate factor fastica :denmark --method=dcov
friedman estimate factor fastica :denmark --method=hsic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--method` | | String | `fastica` | `fastica`, `jade`, `sobi`, `dcov`, `hsic` |
| `--contrast` | | String | `logcosh` | `logcosh`, `exp`, `kurtosis` (FastICA only) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Structural impact matrix (B0), structural shocks (first 10 observations).

---

## estimate regression ml

Maximum likelihood non-Gaussian SVAR identification.

```bash
friedman estimate regression ml :denmark --distribution=student_t
friedman estimate regression ml :denmark --distribution=mixture_normal
friedman estimate regression ml :denmark --distribution=pml
friedman estimate regression ml :denmark --distribution=skew_normal
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--distribution` | `-d` | String | `student_t` | `student_t`, `skew_t`, `ghd`, `mixture_normal`, `pml`, `skew_normal` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Structural impact matrix (B0), model fit (log-likelihood, AIC, BIC), distribution parameters, parameter estimates with standard errors.

---

## estimate multivariate vecm

Estimate a Vector Error Correction Model via Johansen MLE. Cointegration rank is auto-selected via trace test when `--rank` is omitted.

```bash
friedman estimate multivariate vecm :denmark --lags=2
friedman estimate multivariate vecm :denmark --rank=1 --deterministic=constant
friedman estimate multivariate vecm :denmark --lags=4 --rank=2 --method=johansen
friedman estimate multivariate vecm :denmark --lags=2 --significance=0.01
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--rank` | `-r` | Int | auto (Johansen) | Cointegration rank |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--method` | | String | `johansen` | Estimation method |
| `--significance` | | Float64 | 0.05 | Significance level for auto rank selection |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Cointegration rank, loading matrix (alpha), cointegrating vectors (beta), short-run coefficients.

---

## estimate multivariate svar

Maximum-likelihood estimation of the AB-model SVAR (`A u_t = B ε_t`, Amisano–Giannini). `recursive` and `blanchard-quah` are closed-form; overidentified matrix patterns are maximised with LBFGS from `--n-starts` starting values. Matrix patterns come from the `[svar]` config table (`nan` = free parameter); see [Configuration](../configuration.md).

```bash
friedman estimate multivariate svar :denmark --lags=2
friedman estimate multivariate svar :denmark --lags=2 --pattern=blanchard-quah
cat > svar.toml <<'EOF'
[svar]
A = [[1.0, 0.0, 0.0], [nan, 1.0, 0.0], [nan, nan, 1.0]]
B = [[nan, 0.0, 0.0], [0.0, nan, 0.0], [0.0, 0.0, nan]]
EOF
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > svar.csv
friedman estimate multivariate svar svar.csv --lags=2 --pattern=a-model --config=svar.toml
friedman estimate multivariate svar svar.csv --lags=2 --pattern=ab-model --config=svar.toml --n-starts=10
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto (AIC) | VAR lag order |
| `--pattern` | | String | `recursive` | `recursive`, `blanchard-quah`, `a-model`, `b-model`, `ab-model` |
| `--config` | | String | | TOML config with `[svar]` A/B matrices (a/b/ab-model) |
| `--n-starts` | | Int | 5 | Optimizer starting values (overidentified patterns) |
| `--max-iter` | | Int | 400 | Max optimizer iterations per start |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Contemporaneous matrix A, structural matrix B, log-likelihood with the LR overidentification test and identification status.

---

## estimate multivariate svec

Structural VECM via King–Plosser–Stock–Watson (default) or custom long/short-run zero matrices from the `[svec]` config table. Without `--config` the identification is fully KPSW.

```bash
cat > svec.toml <<'EOF'
[svec]
long_run_zeros = [[nan, 0.0, 0.0], [nan, nan, 0.0], [nan, nan, nan]]
EOF
friedman data simulate vecm --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > vec.csv
friedman estimate multivariate svec vec.csv --lags=2 --rank=1
friedman estimate multivariate svec vec.csv --lags=2 --rank=1 --config=svec.toml
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | 2 | Lag order (in levels, VECM uses p-1) |
| `--rank` | `-r` | String | `auto` | Cointegration rank (`auto`, `1`, `2`, ...) |
| `--deterministic` | | String | `constant` | `none`, `constant`, `trend` |
| `--method` | | String | `johansen` | `johansen`, `engle_granger` |
| `--significance` | | Float64 | 0.05 | Significance level for auto rank selection |
| `--config` | | String | | TOML config with optional `[svec]` zero matrices |
| `--n-starts` | | Int | 5 | Optimizer starting values (restricted patterns) |
| `--max-iter` | | Int | 400 | Max optimizer iterations per start |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot` | | Flag | | Open interactive plot in browser |
| `--plot-save` | | String | | Save plot to HTML file |

**Output:** Contemporaneous impact matrix B0, long-run impact matrix Xi, permanent-shock count and identification status.

---

## estimate panel pvar

Estimate a Panel VAR model via GMM or fixed-effects OLS.

```bash
friedman data simulate pvar --seed 7 --format csv --output panel.csv
friedman estimate panel pvar panel.csv --id-col=id --time-col=time --lags=2
friedman estimate panel pvar panel.csv --id-col=id --time-col=time --lags=2 --method=feols
friedman estimate panel pvar panel.csv --id-col=id --time-col=time --lags=2 --vars=y1,y2
friedman estimate panel pvar panel.csv --id-col=id --time-col=time --lags=2 --transformation=fd
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--lags` | `-p` | Int | auto | Lag order |
| `--id-col` | | String | (required) | Panel group identifier column |
| `--time-col` | | String | (required) | Panel time identifier column |
| `--vars` | | String | | Comma-separated list of dependent variables |
| `--method` | | String | `gmm` | `gmm`, `feols` |
| `--transformation` | | String | `fd` | `fd` (first difference), `demean` |
| `--steps` | | String | `twostep` | `onestep`, `twostep` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient matrix with standard errors and p-values.

---

## estimate regression reg

OLS/WLS regression. If `--dep` is omitted, the first numeric column is used as the dependent variable and all remaining numeric columns are regressors.

```bash
friedman estimate regression reg :stackloss --dep=stack.loss --cov-type=hc1
cat > reg.csv <<'EOF'
wage,educ,exper,pop_weight,state
18.5466,12.0684,8.9983,2.5071,4
19.0527,14.7195,13.1261,2.7906,1
18.4916,14.4494,8.2438,1.8357,4
16.0619,10.9794,9.9270,2.9439,3
17.9186,11.4041,11.3714,2.1187,6
17.8943,10.9452,6.4950,2.1329,6
19.2740,13.1395,12.3944,2.4013,1
19.2222,11.8879,9.5801,2.2183,6
18.5462,13.4938,11.9699,2.6456,2
14.6737,8.3054,7.9126,2.2129,3
17.1335,15.1331,14.3448,1.9653,4
15.2721,11.8071,12.4208,2.0771,6
20.0668,13.3608,9.2879,3.1560,3
16.9595,11.7269,12.5278,2.5221,6
19.6650,11.2418,15.0390,1.9162,2
21.5751,12.9262,17.1647,2.5042,3
19.6755,13.6490,3.7057,1.7220,6
19.9594,11.5949,13.5325,3.3948,5
19.9476,11.6944,11.8603,1.7378,5
18.3611,13.3714,9.6246,2.7394,3
13.6029,10.2593,5.9733,2.7718,1
15.2225,8.9712,15.0288,1.7750,1
15.7418,12.7900,4.9530,2.6501,2
14.9478,10.6589,12.2678,2.9986,4
14.9948,8.1593,15.2075,2.7338,6
14.1928,10.3719,3.6013,2.6305,1
16.9920,11.0648,8.7899,2.9745,1
13.4420,9.6136,4.7631,2.5805,4
11.6576,9.0151,10.9762,2.6682,2
19.3313,12.0733,16.0575,2.4366,5
21.9146,13.7945,18.0942,2.8159,4
17.2622,11.5337,2.8875,2.0293,6
16.8760,10.5128,7.7002,2.8959,3
17.7731,12.7700,12.8142,2.2473,3
19.1953,13.4345,16.3175,1.9547,5
21.6466,11.4000,11.6848,2.6826,1
19.0894,13.0893,7.0154,3.3465,2
23.2880,14.0858,11.1885,2.9808,6
21.5078,11.5861,9.9335,2.2422,1
14.4177,10.3730,9.1850,2.8490,6
18.0454,12.6953,7.0621,2.2729,5
19.3771,12.4951,11.5490,2.4380,6
20.8468,14.1976,11.2315,2.5448,2
16.5169,9.4308,9.6281,1.3414,4
16.6795,10.6768,9.1132,2.5958,1
15.0653,10.3237,4.8603,1.9852,5
11.2372,8.5320,8.0553,2.1513,1
18.9192,12.2529,14.8258,1.7628,3
16.7206,13.0556,9.2378,1.7417,2
14.9425,10.5224,4.2412,2.0284,2
20.4833,14.7713,15.3378,2.9128,4
20.7884,13.6438,12.1211,3.3330,2
22.7717,13.2548,18.4323,2.4874,1
18.9351,12.8034,10.2500,3.0459,5
19.2077,13.9113,8.1545,2.3680,2
13.9176,9.3360,4.2094,1.5440,2
19.2753,13.2279,15.2954,2.5750,2
21.3189,13.2056,20.2780,2.7228,5
12.7952,8.4646,6.7163,2.2857,5
18.1547,12.6941,7.4116,2.6511,4
EOF
friedman estimate regression reg reg.csv --dep=wage --weights=pop_weight --cov-type=hc3
friedman estimate regression reg reg.csv --dep=wage --clusters=state --cov-type=cluster
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3`, `cluster`, `conley` |
| `--weights` | | String | | Weight variable column name (for WLS) |
| `--clusters` | | String | | Cluster variable column name (required for `--cov-type cluster`) |
| `--lat` | | String | | Latitude / first coordinate column (`conley` only) |
| `--lon` | | String | | Longitude / second coordinate column (`conley` only) |
| `--dist-cutoff` | | Float64 | 0.0 | Spatial cutoff: km for `haversine`, coordinate units for `euclidean` (`conley` only) |
| `--conley-kernel` | | String | `bartlett` | `bartlett` (tapered) or `uniform` (`conley` only) |
| `--conley-metric` | | String | `euclidean` | `euclidean` (projected coordinates) or `haversine` (degrees → km) |
| `--time-col` | | String | | Time column for spatial **and** serial correlation (`conley` only) |
| `--time-cutoff` | | Int | 0 | Serial-correlation lag cutoff; must accompany `--time-col` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`term|estimate|std_error|stat|p_value|ci_lower|ci_upper`, [C051](#coefficient-table-format-c051)) + fit statistics (R², Adj R², F-stat, AIC, BIC).

Shown on the bundled stack-loss dataset (`:stackloss`); status lines go to stderr, JSON below is stdout only.

<!-- capture -->
```bash
friedman estimate regression reg :stackloss --dep stack.loss --format json
```
```json
{
    "schema_version": 1,
    "data": {
        "fit_statistics": {
            "columns": [
                "metric",
                "value"
            ],
            "rows": [
                [
                    "R²",
                    0.85633
                ],
                [
                    "Adj. R²",
                    0.840366
                ],
                [
                    "F-statistic",
                    27.2237
                ],
                [
                    "F p-value",
                    0
                ],
                [
                    "Log-likelihood",
                    -57.6246
                ],
                [
                    "AIC",
                    123.2492
                ],
                [
                    "BIC",
                    127.4272
                ]
            ]
        },
        "reg_coefficients": {
            "columns": [
                "term",
                "estimate",
                "std_error",
                "stat",
                "p_value",
                "ci_lower",
                "ci_upper"
            ],
            "rows": [
                [
                    "Air.Flow",
                    0.7967652,
                    0.18250293,
                    4.3657666,
                    0.00037264853,
                    0.41334077,
                    1.1801896
                ],
                [
                    "Water.Temp",
                    1.1114225,
                    0.50940902,
                    2.1817879,
                    0.042625611,
                    0.041193817,
                    2.1816511
                ],
                [
                    "Acid.Conc.",
                    -0.62499326,
                    0.074792385,
                    -8.3563756,
                    1.3102134e-7,
                    -0.78212623,
                    -0.46786029
                ]
            ]
        }
    },
    "warnings": [
    ],
    "status": "ok",
    "artifacts": [
    ],
    "command": "friedman estimate regression reg",
    "meta": {
    },
    "error": null
}
```

### Conley (1999) spatial HAC standard errors

`--cov-type conley` weights every pair of observations by a kernel in their distance, rather than assuming correlation is total within a cluster and zero across it. Use it when dependence is spatial and continuous — neighbouring counties, nearby plants, grid cells — where no clustering partition is defensible.

```bash
cat > plants.csv <<'EOF'
output,x1,coord_y,coord_x
10.8563,-2.2691,32.1442,35.9090
9.7638,-0.8147,0.0624,54.9504
10.2783,0.7023,43.3197,16.3813
10.7783,0.3482,73.6059,122.9920
9.1245,1.2713,0.4052,41.1541
10.2558,0.4012,38.6166,134.4467
11.3804,0.3711,198.1724,48.9983
11.3869,0.3300,157.3869,167.3077
10.8649,-0.6418,24.2562,142.3701
9.4938,-0.4600,45.1543,185.6545
10.8874,-0.4583,153.3653,85.5997
11.5736,0.1831,183.3676,32.3902
9.5582,-0.9317,70.7643,188.8109
12.7640,-0.4222,157.1414,128.3500
9.9759,0.2763,29.3439,181.7257
11.8906,-0.0780,108.3457,99.5192
11.1503,-0.2807,119.3722,154.1666
12.1721,-0.2070,157.9802,98.5232
10.9614,-1.2354,55.7265,69.0402
10.6726,-1.3598,82.7267,148.5886
11.0012,-0.8045,75.2142,48.6054
9.9446,0.9472,27.5817,16.5176
11.1110,0.7827,135.1900,90.8001
11.8577,0.2703,111.4719,1.6150
10.5784,0.6162,101.2363,4.7860
10.7958,0.7862,125.2824,143.7911
12.4885,-2.3687,121.0517,99.3269
9.9528,-0.5536,14.6312,29.7648
10.7496,0.8345,59.9514,123.6417
11.6260,1.7597,80.6676,89.5323
10.1326,0.1796,37.6640,52.7986
11.1598,1.7242,144.1547,60.1201
12.2620,1.1608,134.8389,155.7298
11.5232,0.1401,153.3927,56.9329
10.1648,-1.0496,3.2328,14.2276
10.0292,-1.0097,19.4845,186.5099
10.7529,-0.0585,48.8029,56.0379
10.2889,0.1917,108.2980,110.7995
10.2391,-0.0719,15.4989,87.4989
12.3555,0.6092,185.4605,181.6910
10.5375,0.5702,5.9095,26.7657
11.0078,0.0440,126.4116,42.3281
11.8426,0.4369,152.4748,102.1093
12.2369,0.2965,116.8352,83.4298
10.8322,-1.8856,77.0516,106.6474
12.0583,-1.2807,172.0500,177.6044
10.4130,0.3128,59.0615,134.8071
9.5054,0.7627,37.1091,86.3894
11.4742,0.0949,110.2712,155.8374
9.7695,-0.2960,24.7379,69.7473
9.8164,0.2100,16.5795,93.5265
11.9044,0.4578,187.5122,177.2371
10.9394,0.1753,94.8781,28.5539
10.3842,-1.9810,44.6504,111.9833
11.9583,0.3211,140.1894,187.0951
11.8547,0.7352,178.6642,161.5614
10.1894,0.1178,16.9103,103.4682
10.2816,2.2046,82.1619,184.7169
11.1148,-1.4182,66.0304,185.4622
11.1557,-1.8082,179.5092,124.8270
EOF
# Projected coordinates (metres, km, …): euclidean distance, cutoff in the same units
friedman estimate regression reg plants.csv --dep=output --cov-type=conley \
  --lat=coord_y --lon=coord_x --dist-cutoff=50

cat > counties.csv <<'EOF'
wage,x1,latitude,longitude
21.1070,-0.3152,27.6515,-102.0488
21.6334,0.8296,46.0903,-115.0241
22.1025,2.4289,42.2143,-79.0422
21.7060,0.2635,25.6528,-107.1509
21.5785,-0.1508,29.7947,-69.0687
22.6424,-0.0217,41.3773,-114.3206
21.8192,0.4842,37.8918,-108.3664
21.5362,1.1139,34.7187,-67.8135
22.0917,1.0919,38.5857,-98.3964
22.6666,0.2522,46.7508,-119.8405
21.9411,0.5446,41.0866,-81.8453
21.8488,-0.1075,40.8147,-67.6450
21.9918,1.2827,43.8410,-121.9679
22.7012,-1.3906,42.1116,-87.6477
20.8294,1.0728,29.1083,-112.3388
21.7549,0.1635,27.8525,-82.0677
21.7054,0.0853,34.8606,-105.4799
21.9692,0.3191,29.8420,-68.7705
22.1520,0.0058,38.0878,-102.7831
21.9464,-0.7634,45.7327,-76.3673
21.3737,0.0537,26.0290,-111.3038
22.2420,0.1882,47.7240,-88.1888
21.3188,0.3633,29.6365,-98.2883
21.9573,0.9432,47.4726,-88.0143
22.7053,-0.2007,46.3455,-111.1648
21.5029,-1.8308,41.4694,-71.9751
21.8293,-0.0477,35.1122,-91.7451
22.7148,0.2877,41.8796,-122.5842
21.5881,0.3809,28.6205,-120.6094
22.2355,-1.8273,34.8294,-87.4552
22.1517,0.9213,37.4864,-123.5909
21.6626,1.6665,25.2554,-73.7334
22.1043,0.1055,47.2285,-107.3455
21.6498,1.0259,31.9123,-90.9548
21.8699,1.2512,34.3635,-112.8383
22.3018,1.5610,44.5333,-75.0839
21.7658,-1.2673,40.7561,-94.8889
21.4863,0.9535,35.6756,-118.7696
21.7867,-0.2259,35.5239,-69.0865
22.2420,-1.3570,42.1908,-104.9069
22.4795,0.2445,47.8677,-90.3615
21.0605,-0.1318,30.9420,-96.8519
21.7555,1.0925,38.2773,-67.3384
21.6780,0.8578,36.8846,-91.0690
21.4347,-0.7484,26.1628,-77.0610
21.8694,0.5546,42.5443,-103.9686
21.5774,0.6555,30.8424,-67.4151
22.0143,-1.3060,47.6270,-77.8383
21.2953,0.3277,28.3012,-100.8078
22.1677,-0.1775,39.1132,-82.4713
22.6225,1.3696,47.4053,-104.2498
21.4380,0.6511,36.1386,-79.6216
22.1580,-0.5301,42.4869,-76.4810
21.6815,-0.7338,37.6886,-113.2769
22.7931,-2.2046,44.4955,-73.1804
21.8452,1.2372,34.0566,-108.3238
22.1107,1.1894,41.7140,-108.8854
22.3320,0.9442,34.9903,-120.9146
20.7109,0.0840,31.7501,-80.1190
22.1375,0.5970,47.7134,-112.8702
21.4956,-0.7533,25.9112,-107.2641
21.5892,0.4601,31.8046,-93.3255
22.3711,0.6323,44.6727,-69.3290
21.8896,0.0946,41.1527,-119.0910
21.8323,1.9890,37.8675,-71.0619
22.3908,-0.0241,45.9014,-94.9260
22.5365,-0.7748,43.2532,-82.1472
22.5980,-1.1903,38.4425,-114.4346
21.7416,0.8192,41.3009,-111.9981
22.1897,-0.4400,40.1410,-81.9170
20.8553,-0.4948,29.6490,-93.2064
21.4310,-0.8640,31.0188,-91.6985
22.4755,-1.1864,47.0851,-109.7977
21.0796,0.6688,26.0951,-85.1598
21.5137,-1.7240,28.4111,-119.0626
22.0134,2.2637,40.7562,-88.2373
22.6791,-0.5752,42.6109,-118.7555
21.6250,0.7814,31.3513,-120.3001
21.5168,-0.2805,33.6137,-107.4559
21.8581,0.6901,46.4752,-110.9278
EOF
# Degrees: haversine distance, cutoff in kilometres
friedman estimate regression reg counties.csv --dep=wage --cov-type=conley \
  --lat=latitude --lon=longitude --conley-metric=haversine --dist-cutoff=100

cat > panel.csv <<'EOF'
y,x1,lat,lon,year
6.8619,1.6152,29.1888,-93.7411,2015
6.6566,-0.2339,34.4180,-84.9704,2016
6.1446,1.2800,32.6119,-103.3511,2017
7.3712,-0.2320,46.4228,-90.1910,2018
6.6770,0.5916,31.2553,-73.9626,2019
6.3895,-0.3528,30.4850,-89.3924,2015
5.9351,-0.1909,29.0166,-82.3689,2016
7.2002,0.6721,43.4857,-113.0785,2017
7.1992,0.3941,46.5402,-80.5705,2018
7.4368,-1.4094,45.3424,-74.5556,2019
5.9500,-0.2101,26.0282,-99.0315,2015
7.2126,1.3368,45.2084,-117.6452,2016
5.9234,-0.0861,30.6313,-116.6314,2017
6.5885,0.0384,39.8026,-80.8866,2018
6.0474,-1.4478,25.3604,-89.7388,2019
7.2083,2.6164,40.9936,-79.8207,2015
6.6794,-0.3892,39.3249,-97.0625,2016
6.8108,-1.0011,45.0215,-116.4396,2017
6.2865,-1.0255,25.3675,-98.7053,2018
6.9890,-0.2921,34.1381,-86.5402,2019
6.5227,-0.9153,38.0098,-71.1917,2015
6.9673,-1.0868,37.5784,-79.6923,2016
7.8209,0.5061,47.7334,-88.0854,2017
7.3249,0.2863,42.7143,-78.2476,2018
6.7029,-0.0378,42.3423,-98.5121,2019
7.3131,0.9014,44.6670,-122.4355,2015
6.8405,0.3435,45.5081,-120.4742,2016
7.0605,1.8295,43.4115,-75.9709,2017
7.5339,2.3326,38.0658,-110.0329,2018
7.5432,0.8115,36.0021,-116.0204,2019
6.7945,-0.1655,43.7142,-118.0852,2015
6.7123,1.3050,33.1049,-91.5083,2016
7.6200,-0.8938,44.6260,-68.8811,2017
5.8693,-0.0135,30.2735,-89.9844,2018
6.5851,-0.2238,31.8706,-93.2159,2019
6.4886,0.4845,34.6163,-88.0691,2015
7.1091,0.6311,42.5861,-119.5588,2016
7.4346,0.1212,44.7594,-88.7389,2017
6.2778,1.3777,30.6183,-68.0189,2018
5.9976,0.0161,30.1365,-81.2495,2019
6.5716,0.0719,39.3472,-122.5960,2015
7.0228,-0.3213,33.0586,-121.8075,2016
6.6512,-0.6241,29.5444,-90.7984,2017
6.7057,0.1146,29.2215,-95.6988,2018
6.9723,0.4178,44.1864,-79.0386,2019
7.0159,0.1873,37.9983,-69.3035,2015
7.1497,1.3650,40.8963,-112.8211,2016
6.7682,0.5409,29.0383,-120.0337,2017
7.2325,1.0085,43.5761,-101.0639,2018
7.7443,0.3466,44.3682,-72.1726,2019
7.2439,-2.3391,43.8339,-119.9287,2015
8.0617,0.0878,44.6200,-103.8303,2016
6.4028,-0.2767,36.1210,-74.4386,2017
7.5425,0.5672,46.1109,-92.2134,2018
6.1077,-0.2715,25.9854,-69.2041,2019
7.4874,-0.3563,47.0939,-69.1954,2015
6.5674,0.8681,25.7882,-106.9452,2016
6.3222,0.0718,37.2341,-116.1810,2017
7.4980,0.7270,34.9063,-71.4874,2018
7.2039,1.4344,47.3871,-98.3165,2019
7.1812,-0.1161,45.3413,-115.9099,2015
6.2481,-1.6656,41.1239,-115.4164,2016
6.6338,-0.4002,29.2841,-80.5843,2017
8.0479,-1.1532,47.9119,-70.3761,2018
7.2425,-1.4041,41.2970,-77.1985,2019
7.0406,1.4322,39.3899,-92.3736,2015
7.2362,2.3715,40.0516,-121.9602,2016
6.8145,-1.3686,40.3954,-98.2445,2017
7.0722,1.5690,43.8594,-105.3176,2018
7.6389,1.8675,41.2712,-68.5995,2019
6.2718,0.5795,27.8006,-123.9043,2015
6.8419,0.1723,42.6982,-94.6133,2016
6.6987,1.2317,40.6864,-102.0931,2017
6.9295,0.4786,35.2796,-81.9461,2018
7.1514,0.5906,37.1315,-76.0452,2019
5.8351,0.4367,27.0299,-115.9208,2015
7.3152,-0.1755,46.4264,-67.9863,2016
6.3746,0.0852,28.7689,-104.4291,2017
6.6163,-0.1723,45.6286,-106.5980,2018
7.6916,-0.0920,34.8732,-114.5325,2019
6.5619,0.7371,28.2125,-77.0225,2015
6.8465,-0.8689,41.7081,-67.4697,2016
5.6225,-0.6555,25.4889,-90.0399,2017
6.3845,0.2309,31.4652,-91.9936,2018
7.4771,1.2344,45.9696,-86.5210,2019
6.3378,0.7276,37.1363,-85.5307,2015
6.3879,0.2749,32.2624,-93.6709,2016
7.3529,-0.4453,37.8089,-77.1687,2017
7.3194,-1.3708,39.4808,-80.1815,2018
7.5328,-0.0351,46.8396,-106.9162,2019
6.8746,0.4256,37.5398,-89.5627,2015
6.3320,-1.1871,32.1902,-81.8225,2016
6.4218,2.0985,34.6586,-90.8481,2017
7.2005,0.5158,37.1775,-81.8096,2018
6.1705,1.1423,26.4007,-103.2813,2019
6.4516,0.8819,35.5745,-114.9381,2015
7.2434,-2.1683,42.0943,-109.0851,2016
6.4473,1.0399,31.3215,-73.2268,2017
6.6446,0.8625,31.8075,-68.6019,2018
6.4938,-1.4574,28.8798,-112.9659,2019
EOF
# Spatial *and* serial correlation (Conley panel): add a time column and a lag cutoff
friedman estimate regression reg panel.csv --dep=y --cov-type=conley \
  --lat=lat --lon=lon --conley-metric=haversine --dist-cutoff=100 \
  --time-col=year --time-cutoff=3
```

Under `conley` the leaf emits one extra table, **Conley Spatial HAC Settings**, recording the coordinate columns, metric, kernel and cutoff. This is deliberate: a Conley standard error is not interpretable without the cutoff that produced it, and the cutoff is a researcher choice, not a property of the data.

Guards, all typed:

* `--cov-type conley` without `--lat`/`--lon` → `usage/missing`; with `--dist-cutoff ≤ 0` → `usage/invalid`.
* Any Conley option supplied under a different `--cov-type` → `usage/invalid`, never a silent no-op.
* `--time-col` and `--time-cutoff` must be given together — a lag cutoff with no time column would silently degrade to spatial-only.
* `--conley-metric haversine` requires latitude in `[-90, 90]` and longitude in `[-180, 180]`; out-of-range degrees would otherwise yield nonsense distances rather than an error.
* The coordinate and time columns are **excluded from the regressor matrix**. They are ordinary numeric CSV columns, so without this they would enter the design as regressors — a wrong point estimate that no error would reveal.

Choosing the cutoff is a judgement call and the result is sensitive to it: too small and the correction is negligible, too large and the estimator loses precision (and can fail to be positive semi-definite, though upstream clips the eigenvalues to keep it valid). Report the cutoff, and check that conclusions survive a range of them.

---

## Penalized, robust & censored regression

`estimate regression lasso | ridge | elastic-net | robust | tobit` extend the cross-section regression family beyond OLS. Like `estimate regression reg`, they take the dependent variable via `--dep` (default: first numeric column) and use all remaining numeric columns as regressors. A bad `--dep` surfaces a typed `data/column-range` error. Coefficient tables are hand-built (these result types are not Tables.jl-registered upstream — the C051 exception).

---

## estimate regression lasso

L1-penalized (Lasso) regression. `--lambda=auto` selects the penalty along a cross-validated path (rule set by `--select`); pass a number to fix it. The intercept is reported as `(Intercept)`; the `nonzero` column flags the active (selected) coefficients.

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression lasso xs.csv --dep=y
friedman estimate regression lasso xs.csv --dep=y --lambda=0.1
friedman estimate regression lasso xs.csv --dep=y --select=bic
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lambda` | | String | `auto` | `auto` (CV path) or a non-negative number |
| `--select` | | String | `cv` | Lambda selection rule: `cv`, `aic`, `bic`, `ebic` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`term|estimate|nonzero`, intercept first) + diagnostics (`alpha`, selected `lambda`, `n_active`, `r2`, `aic`, `bic`, `ebic`, `select`).

---

## estimate regression ridge

L2-penalized (Ridge) regression. Same options and output as `estimate regression lasso` (Ridge fixes the L1/L2 mix `alpha=0`).

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression ridge xs.csv --dep=y --lambda=auto
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lambda` | | String | `auto` | `auto` (CV path) or a non-negative number |
| `--select` | | String | `cv` | Lambda selection rule: `cv`, `aic`, `bic`, `ebic` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

---

## estimate regression elastic-net

Elastic-Net regression — an L1/L2 mix controlled by `--alpha` (`1`=Lasso, `0`=Ridge).

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression elastic-net xs.csv --dep=y --alpha=0.5
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--alpha` | | Float | 0.5 | L1/L2 mixing in [0,1] (1=Lasso, 0=Ridge) |
| `--lambda` | | String | `auto` | `auto` (CV path) or a non-negative number |
| `--select` | | String | `cv` | Lambda selection rule: `cv`, `aic`, `bic`, `ebic` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

---

## estimate regression robust

Robust regression by iteratively reweighted least squares (M) or high-breakdown MM estimation, with a Huber or Tukey-bisquare weight function. Reports coefficients with QML/sandwich standard errors.

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression robust xs.csv --dep=y --psi=huber --method=m
friedman estimate regression robust xs.csv --dep=y --psi=bisquare --method=mm
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--psi` | | String | `huber` | Weight function: `huber`, `bisquare` |
| `--method` | | String | `m` | Estimator: `m`, `mm` (MM = high-breakdown) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter|estimate|std_error|z_stat|p_value`) + diagnostics (`psi`, `method`, `scale`, `robust_r2`, `converged`, `iterations`).

---

## estimate regression tobit

Tobit (censored) regression by maximum likelihood, for a dependent variable censored at `--lower` and/or `--upper` (defaults: left-censored at 0, no upper bound).

```bash
friedman data simulate cross-section --kind tobit --seed 7 --format csv --output cens.csv
friedman estimate regression tobit cens.csv --dep=y --lower=0
friedman estimate regression tobit cens.csv --dep=y --lower=0 --upper=100
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lower` | | Float | 0.0 | Lower censoring bound |
| `--upper` | | Float | Inf | Upper censoring bound (default: none) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter|estimate|std_error|z_stat|p_value`) + diagnostics (`sigma`, `loglik`, `aic`, `bic`, `lower`, `upper`, `n_censored_left`, `n_censored_right`, `converged`).

---

## estimate regression truncreg

Truncated-normal regression by maximum likelihood (Hausman & Wise 1977). Unlike Tobit, the sample is *truncated* — only observations with `--lower < y < --upper` are in the data (no censored mass). Every `y` must lie strictly inside the bounds or a `data/invalid` error is returned.

```bash
friedman data simulate cross-section --kind truncreg --seed 7 --format csv --output trunc.csv
friedman estimate regression truncreg trunc.csv --dep=y --lower=0
friedman estimate regression truncreg trunc.csv --dep=y --lower=0 --upper=100
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--lower` | | Float | 0.0 | Lower truncation bound |
| `--upper` | | Float | Inf | Upper truncation bound (default: none) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Coefficient table (`parameter|estimate|std_error|z_stat|p_value`) + diagnostics (`sigma`, `sigma_se`, `loglik`, `aic`, `bic`, `lower`, `upper`, `n_truncated`, `converged`).

---

## estimate regression heckman

Heckman sample-selection model — two equations: an outcome equation `--dep ~ --outcome-vars` observed only when the binary `--select` indicator is 1, and a selection equation `--select ~ --select-vars` (probit). Estimated by the Heckit two-step (`--method twostep`, default) or full-information MLE (`--method mle`). Include a `const` column in each variable list for an intercept (no auto-intercept, matching `estimate regression reg`). For identification beyond nonlinearity, `--select-vars` should include an *exclusion restriction* — a variable driving selection but not in `--outcome-vars`.

```bash
friedman data simulate cross-section --kind heckman --seed 7 --format csv --output heck.csv
friedman estimate regression heckman heck.csv --dep=y --select=selected \
    --outcome-vars=x1,x2 --select-vars=x1,x2
friedman estimate regression heckman heck.csv --dep=y --select=selected \
    --outcome-vars=x1 --select-vars=x1,x2 --method=mle
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Outcome variable column name |
| `--select` | | String | (required) | Binary 0/1 selection-indicator column |
| `--outcome-vars` | | String | (required) | Outcome-equation regressor columns (comma-separated) |
| `--select-vars` | | String | (required) | Selection-equation regressor columns (comma-separated) |
| `--method` | | String | `twostep` | `twostep` (Heckit) or `mle` (FIML) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one tidy two-equation coefficient table (`equation|term|estimate|std_error|z_stat|p_value`, where `equation` is `outcome`/`selection`) + diagnostics (`method`, `rho` (+se), `sigma` (+se), `lambda` (+se), `loglik`, `aic`, `bic`, `n_selected`, `n_total`, `converged`). `HeckmanModel` is not Tables.jl-registered upstream, so the coefficient table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

---

## estimate regression statespace

Structural (linear-Gaussian) state-space models fitted by prediction-error-decomposition maximum likelihood on a single numeric `--column`. `--model local-level` fits the random-walk-plus-noise model (`yₜ = μₜ + εₜ`, `μₜ₊₁ = μₜ + ηₜ`); `--model local-linear-trend` adds a stochastic slope (state `[μₜ, βₜ]`). `--init-mode` selects the Kalman initialization (`kappa` large-variance diffuse by default, or exact `diffuse`).

```bash
friedman estimate regression statespace :nile --model=local-level
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > macro.csv
friedman estimate regression statespace macro.csv --column=2 --model=local-linear-trend --init-mode=diffuse
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | 1-based numeric column to model |
| `--model` | | String | `local-level` | `local-level` or `local-linear-trend` (ignored with `--config`) |
| `--init-mode` | | String | `kappa` | Kalman initialization: `kappa` or `diffuse` |
| `--kappa` | | Float | 1e6 | Large-variance diffuse-init constant (`init-mode=kappa`) |
| `--config` | | String | | TOML with a `[statespace]` section — switches to a **general** system (below) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** hyper-parameter table (`parameter|estimate` — the estimated natural-scale variances σ̂², e.g. `σ²_ε`, `σ²_η`) + diagnostics (`model`, `loglik`, `converged`, `n_state`, `n_obs`, `method`). `StateSpaceModel` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

### General systems: `--config`

A `[statespace]` section specifies an arbitrary linear-Gaussian system directly, in the standard single-block form

```
yₜ   = Z αₜ + d + εₜ,     εₜ ~ N(0, H)
αₜ₊₁ = T αₜ + c + R ηₜ,   ηₜ ~ N(0, Q)
```

**This path is multivariate**: `Z` is `n_obs × n_state`, and the data file must have exactly `n_obs` numeric columns (`--column` does not apply). It is also **fixed-matrix**: nothing is optimized. The system is filtered and its log-likelihood evaluated, so `method` comes back as `filter` rather than `mle` and there are no hyper-parameters to report — the output is a **system table** (`matrix|role|rows|cols`) instead of `parameter|estimate`, showing the matrices in force *after* defaults are applied.

```toml
[statespace]
# Two observed series loading on one common AR(1) state
Z = [[1.0], [0.7]]              # n_obs × n_state       (required)
H = [[1.0, 0.0], [0.0, 2.0]]    # n_obs × n_obs         (required)
T = [[0.95]]                    # n_state × n_state     (required)
Q = [[0.5]]                     # r × r                 (required)
# optional:
d = [0.0, 0.0]                  # n_obs      observation intercept (default 0)
c = [0.0]                       # n_state    state intercept       (default 0)
R = [[1.0]]                     # n_state × r  noise loading        (default I)
a1 = [0.0]                      # n_state    explicit initial state mean
P1 = [[10.0]]                   # n_state × n_state  explicit initial covariance
init_mode = "kappa"             # kappa | diffuse | stationary
```

```bash
cat > two_series.csv <<'EOF'
s1,s2
0.6578,-0.5496
1.4521,-0.7491
1.8014,-0.5701
2.4391,1.2999
3.5152,2.3352
-0.0260,1.6410
0.4669,-1.1837
0.6717,-0.2527
0.7269,0.5752
-0.6892,1.9015
1.9394,1.4780
0.6363,1.9169
-0.5485,1.3147
0.0764,1.0153
-0.0727,-1.7169
-0.9716,0.4043
2.0492,-0.2569
1.7481,-2.1645
0.7760,-1.2705
1.6232,4.2534
0.0782,0.0206
1.2621,-1.8021
1.6480,0.2075
0.6034,3.0471
0.4950,0.5132
0.2191,0.8274
0.1976,-0.2740
0.6525,-0.3742
0.1618,1.9040
-1.1999,0.4564
0.2222,-0.3423
1.3381,0.7313
-1.4265,0.7456
-1.4623,-1.6894
-3.5547,-1.0062
-0.7064,-1.0805
-1.1559,-2.2063
-0.7653,0.1425
-1.9866,-1.5832
-1.6002,-1.2575
0.6428,-2.5164
0.1209,-2.2144
-0.8009,2.1819
-1.5003,-1.6152
0.8389,0.8742
0.6278,0.0454
3.0976,1.0557
-1.5042,0.2202
-1.6174,-1.8490
-0.7592,-0.8625
-2.5471,-0.4783
-1.4198,-0.2111
1.8259,0.0872
-0.3398,-0.5845
0.0556,1.3459
0.4941,3.0802
3.0135,2.4598
3.7855,1.1529
3.9951,3.1714
4.7407,3.6765
5.3090,4.1487
5.1363,5.9111
4.2583,3.1579
4.6788,2.8234
0.6511,0.6952
0.7217,1.0030
1.8671,0.7229
2.2851,3.9153
0.0342,1.2645
0.1488,-0.9266
0.6634,2.4267
-0.0532,-2.2124
-0.2889,0.8463
0.8104,1.4103
1.2477,1.3938
-0.1797,0.3083
1.1409,0.7593
1.8010,-0.1241
-1.4768,0.8630
-0.0946,-3.3703
EOF
cat > system.toml <<'EOF'
[statespace]
# Two observed series loading on one common AR(1) state
Z = [[1.0], [0.7]]
H = [[1.0, 0.0], [0.0, 2.0]]
T = [[0.95]]
Q = [[0.5]]
d = [0.0, 0.0]
c = [0.0]
R = [[1.0]]
a1 = [0.0]
P1 = [[10.0]]
init_mode = "kappa"
EOF
friedman estimate regression statespace two_series.csv --config system.toml
```

Notes:

- **`T` in the TOML is the transition matrix.** The Julia field is `Tt` and the upstream constructor keyword is `T_mat`, because `T` is the type parameter — three spellings of one matrix, unavoidable.
- **`a1` and `P1` must be given together or not at all.** Supplying only one is rejected rather than silently ignored: upstream switches to explicit initialization only when both are present, so a lone `a1` would quietly have no effect.
- Matrices are row-major arrays of arrays; `d`, `c`, `a1` are flat arrays.
- Every dimensional inconsistency is caught while parsing, so it surfaces as `config/shape` (exit 4) naming the file you wrote, rather than as an error from deep inside the library. A mismatch between `Z`'s implied `n_obs` and the CSV's column count is `data/shape` (exit 3), since that is a property of the data rather than the config.

---

## estimate regime tvp

Time-varying-parameter regression with random-walk coefficients (`yₜ = Xₜ βₜ + εₜ`, `βₜ₊₁ = βₜ + ηₜ`), fitted via the Kalman filter/RTS smoother by MLE of the variance hyper-parameters. The whole point is the recovered coefficient *path* `βₜ`. A time-varying intercept is prepended automatically unless `--no-intercept` is set, so the data should NOT include a `const` column.

```bash
cat > phillips.csv <<'EOF'
inflation,unemp
2.0346,5.3654
1.1695,4.7497
1.2242,4.9413
2.5647,4.9552
2.3121,5.2189
1.5987,5.2960
1.1592,5.6615
1.5733,5.6678
1.1209,5.5646
1.4896,5.6807
2.4420,5.7671
1.7182,5.6957
2.2600,5.6462
1.4936,5.7901
1.7192,5.9310
2.2768,5.8322
0.9527,5.7587
1.6276,5.3973
1.5550,5.7332
1.7968,5.6883
2.2990,5.9557
1.8231,6.0392
0.5371,6.4280
0.9968,6.7355
0.6536,6.7991
0.4928,7.0953
2.0598,6.9052
0.3900,7.1570
1.1878,6.8609
0.6776,6.9295
1.3592,7.1425
1.0832,7.1872
1.0068,7.1138
0.9856,6.9527
1.6268,6.8841
0.4870,7.0944
0.5003,7.2725
0.3316,7.2201
1.6818,6.9709
0.8004,7.1057
0.5734,6.8157
0.9357,6.7096
2.4685,6.5626
1.0906,6.7112
1.5458,6.7584
1.3072,6.8508
1.0412,6.9053
0.7688,6.7697
0.8945,6.8768
0.7431,7.1593
-0.1806,7.1519
2.1557,7.2786
1.3357,7.2535
0.8286,7.4592
0.6021,7.5925
0.2213,7.7677
1.0561,7.8374
0.3239,8.1654
0.6931,8.0931
-0.2069,8.0263
0.7353,7.9079
1.4851,8.0301
0.4024,7.9056
1.0116,7.7767
0.5566,7.9222
0.9753,8.1546
0.8990,8.2695
0.6644,7.7329
0.4491,7.5422
0.9796,7.3275
0.9779,7.0860
0.6888,7.0044
1.0443,7.3679
1.0629,7.3064
0.4758,7.1593
0.7947,7.2991
2.3041,7.3129
1.2399,7.3371
0.9490,7.1997
2.1558,7.1994
EOF
friedman estimate regime tvp phillips.csv --dep=inflation
friedman estimate regime tvp phillips.csv --dep=inflation --no-intercept
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--init-mode` | | String | `kappa` | Kalman initialization: `kappa` or `diffuse` |
| `--kappa` | | Float | 1e6 | Large-variance diffuse-init constant (`init-mode=kappa`) |
| `--no-intercept` | | Flag | off | Do NOT prepend a time-varying intercept coefficient |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** hyper-parameter table (`parameter|estimate`) + a tidy long coefficient-path table (`period|coefficient|estimate` — one row per time × coefficient) + diagnostics (`loglik`, `converged`, `n_coef`, `intercept`, `method`). Hand-built tables (documented [C051](#coefficient-table-format-c051) exception).

---

## estimate regression kde

Univariate kernel density estimate on an equally-spaced grid, for a single numeric `--column`. Bandwidth `--bw` is a rule (`silverman` = R `bw.nrd0`, `sj` = Sheather-Jones plug-in) or a positive number; `--kernel` selects a unit-variance kernel.

```bash
friedman estimate regression kde :nile --kernel=gaussian --bw=silverman
friedman estimate regression kde :nile --column=1 --bw=0.5 --npoints=1024 --kernel=epanechnikov
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | 1 | 1-based numeric column |
| `--kernel` | | String | `gaussian` | `gaussian`, `epanechnikov`, `triangular`, `uniform` |
| `--bw` | | String | `silverman` | `silverman`, `sj`, or a positive number |
| `--npoints` | | Int | 512 | Number of grid points |
| `--cut` | | Float | 3.0 | Grid extends `cut·h` beyond the data range each side |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** density grid table (`x|density`) + diagnostics (`kernel`, `bw_method`, `bandwidth`, `nobs`). `KernelDensity` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

---

## estimate regression kernel-reg

Nonparametric regression of a response `--dep` on a SINGLE predictor `--indep`: Nadaraya-Watson (`--method nw`), local-linear (`--method ll`, default; boundary-bias corrected), or local-polynomial (`--method lp --degree d`). Bandwidth `--bw` is a rule (`cv` leave-one-out cross-validation, `rot` Silverman rule-of-thumb) or a positive number.

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression kernel-reg xs.csv --dep=y --indep=x1 --method=ll --bw=cv
friedman estimate regression kernel-reg xs.csv --dep=y --indep=x1 --method=lp --degree=2 --bw=0.4
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Response variable column name |
| `--indep` | | String | (required) | Single predictor column name |
| `--method` | | String | `ll` | `nw`, `ll`, or `lp` |
| `--degree` | | Int | 1 | Local-polynomial degree (`method=lp`) |
| `--bw` | | String | `cv` | `cv`, `rot`, or a positive number |
| `--kernel` | | String | `gaussian` | `gaussian`, `epanechnikov`, `triangular`, `uniform` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** fitted-curve table (`x|fitted|se`, evaluated at the sorted design points) + diagnostics (`method`, `degree`, `kernel`, `bw_method`, `bandwidth`, `nobs`). `KernelRegression` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

---

## estimate regression lowess

Cleveland (1979) LOWESS/LOESS scatterplot smoother of a response `--dep` on a SINGLE predictor `--indep`: tricube-weighted local-linear fits over the `⌊f·n⌋` nearest neighbours, with `--iter` bisquare robustifying passes. `--frac` is the span `f ∈ (0,1]`.

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression lowess xs.csv --dep=y --indep=x1
friedman estimate regression lowess xs.csv --dep=y --indep=x1 --frac=0.3 --iter=5
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Response variable column name |
| `--indep` | | String | (required) | Single predictor column name |
| `--frac` | | Float | 0.6667 | Smoother span `f ∈ (0,1]` (fraction of points per window) |
| `--iter` | | Int | 3 | Number of bisquare robustifying passes |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** smoothed-curve table (`x|fitted`, sorted by `x`) + diagnostics (`frac`, `iter`, `nobs`). `LowessFit` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

---

## estimate regression cointreg

Single-equation **cointegrating regression** for a long-run relationship `y_t = D_t'δ + x_t'β + u_t` where the `--dep` variable and the other numeric columns are `I(1)` (integrated of order 1). Three estimators correct the OLS-on-levels fit for regressor endogeneity and error serial correlation: `fmols` (Phillips-Hansen fully-modified OLS), `ccr` (Park canonical cointegrating regression), and `dols` (Saikkonen / Stock-Watson dynamic OLS). Deterministics are added via `--trend` (the cointreg vocabulary is `none|const|linear` — do not confuse with the ARDL/PMG trend vocabularies). No intercept is prepended to the regressor matrix — cointreg builds its own deterministic block.

```bash
friedman data simulate cointreg --seed 7 --format csv --output coint.csv
friedman estimate regression cointreg coint.csv --dep=y --method=fmols
friedman estimate regression cointreg coint.csv --dep=y --method=dols --leads=2 --lags=2 --ic=bic
friedman estimate regression cointreg coint.csv --dep=y --method=ccr --trend=linear --kernel=qs --bandwidth=nw94
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent (levels) column name |
| `--method` | | String | `fmols` | `fmols`, `ccr`, `dols` |
| `--trend` | | String | `const` | Deterministics: `none`, `const`, `linear` |
| `--kernel` | | String | `bartlett` | HAC kernel: `bartlett`, `parzen`, `qs`, `tukey-hanning` |
| `--bandwidth` | | String | `andrews` | `andrews`, `nw94`, or a fixed truncation lag (≥0) |
| `--leads` | | String | `auto` | DOLS leads: `auto` or a non-negative integer |
| `--lags` | | String | `auto` | DOLS lags: `auto` or a non-negative integer |
| `--ic` | | String | `aic` | DOLS lead/lag selection: `aic`, `bic` |
| `--dols-se` | | String | `lrv` | DOLS standard errors: `lrv`, `robust` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** tidy long-run coefficient table (`term|estimate|std_error|stat|p_value|ci_lower|ci_upper`; p-values/CIs use the large-sample normal approximation, the estimators being asymptotically mixed-normal) + diagnostics (`method`, `trend`, `kernel`, resolved `bandwidth`, `omega_uv`, `nobs`, `d`, `k`; DOLS adds `leads`/`lags`). `CointRegModel` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). `--bandwidth`/`--leads`/`--lags` are dual-type flags parsed in-handler; note `--bandwidth 4` = a fixed truncation lag while `--bandwidth andrews` = data-driven selection.

---

## estimate panel xtcointreg

**Panel cointegrating regression** across the `N` units of a long-format panel (`--id-col`/`--time-col` default to the first/second columns). Each unit is fit by the single-equation estimator ([`estimate regression cointreg`](#estimate-cointreg)) and aggregated either group-mean (`--pooling=group`, Pedroni 2001 between-dimension) or pooled (`--pooling=pooled`, within-dimension: Pedroni 2000 FMOLS / Kao-Chiang 2000 DOLS). Only `fmols` and `dols` are available for panels (no `ccr`).

```bash
friedman estimate panel xtcointreg :grunfeld --id-col=group --time-col=time --dep=invest --indep=value --method=fmols --pooling=group
friedman estimate panel xtcointreg :grunfeld --id-col=group --time-col=time --dep=invest --indep=value,capital --method=dols --pooling=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--id-col` | | String | (1st col) | Panel group id column |
| `--time-col` | | String | (2nd col) | Panel time column |
| `--dep` | | String | (1st var) | Dependent panel variable |
| `--indep` | | String | (all others) | Regressors, comma-separated |
| `--method` | | String | `fmols` | `fmols`, `dols` (no `ccr` for panels) |
| `--pooling` | | String | `group` | `group` (between) or `pooled` (within) |
| `--trend` | | String | `const` | Per-unit deterministics: `none`, `const`, `linear` |
| `--kernel` | | String | `bartlett` | HAC kernel: `bartlett`, `parzen`, `qs`, `tukey-hanning` |
| `--bandwidth` | | String | `andrews` | `andrews`, `nw94`, or a fixed truncation lag (≥0) |
| `--leads` | | String | `auto` | DOLS leads: `auto` or a non-negative integer |
| `--lags` | | String | `auto` | DOLS lags: `auto` or a non-negative integer |
| `--ic` | | String | `aic` | DOLS lead/lag selection: `aic`, `bic` |
| `--dols-se` | | String | `lrv` | DOLS standard errors: `lrv`, `robust` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** tidy panel coefficient table (`term|estimate|std_error|stat|p_value|ci_lower|ci_upper`; group-mean reports Pedroni's between-dimension `t`-statistic and a back-solved display SE that can be `Inf` for a degenerate coefficient — rendered non-finite-safe) + diagnostics (`method`, `pooling`, `trend`, `kernel`, `N` units, total `nobs`, `T_i` span, `balanced`, `k`, `d`). `PanelCointRegModel` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception).

---

## estimate univariate ardl

**Autoregressive distributed-lag** model `ARDL(p, q₁…q_k)`, estimated by OLS on the lagged **levels** of `y` and the regressors. Loads `y` + `X` via the shared regression loader (`--dep` = dependent; all other numeric columns are regressors; **no intercept is prepended** — ARDL adds its own deterministics per the Pesaran-Shin-Smith `--case`). The single leaf folds three views into one call: the levels-form coefficient table, the **long-run** (level) multipliers `θ̂_j = (Σ_ℓ β̂_{jℓ})/(1 − Σ_i φ̂_i)` with delta-method standard errors, and the **error-correction** speed of adjustment `α = Σφ̂ − 1` (in the diagnostics).

```bash
cat > ardl.csv <<'EOF'
y,x1,x2
0.0000,0.6955,-1.8530
0.1988,-0.6317,0.5884
0.1292,-2.0632,-0.4308
-3.5983,-3.7117,-0.7779
-4.6176,-1.8157,0.2045
-3.3591,1.0710,0.1289
-1.5606,0.6569,1.3943
0.6408,0.5284,-1.4420
-0.3566,1.2792,-0.4284
3.0638,-0.3705,-0.1425
0.0946,2.2112,-1.8406
0.3089,0.4492,1.1731
-1.0528,-0.0649,1.7561
-0.1608,2.9264,-0.6251
2.2325,1.2555,0.3816
2.3835,0.0572,-0.2691
0.5844,-0.4547,0.2704
1.0022,0.0786,-0.6755
0.6192,-1.9594,0.8316
0.3465,-1.7102,-1.1656
-1.6905,1.3707,1.3634
-0.8811,1.0584,0.3564
0.4797,-0.1347,2.4247
0.1662,0.2527,-1.6513
0.5215,0.6011,-0.0955
0.1629,0.3594,-1.2856
-0.3278,0.6546,-0.1399
0.3431,-1.3703,0.4351
-2.2161,-0.2385,-0.9195
-2.0035,-0.3779,-1.4351
-0.9598,0.4490,-1.7338
-1.3404,0.3717,0.2209
-0.4097,-1.0088,1.2767
-0.2989,-0.5712,1.1719
-0.7760,-1.0431,0.0338
-1.4707,0.5092,-0.9617
-0.2444,0.4778,-0.3633
-0.2355,0.8388,-1.5079
0.0291,-0.6885,-1.5763
-1.2850,1.0619,1.0659
-0.3888,0.5086,-0.2781
-1.1712,1.2147,0.3144
2.5086,1.5367,-0.2735
3.7681,-0.6739,1.3249
1.7715,-0.2273,1.4375
2.2433,-0.3809,-0.7762
1.6270,0.1381,-0.3661
1.7530,1.6372,-0.6752
1.5688,1.4049,1.3178
1.0205,1.4123,1.2466
0.8963,-0.6376,-0.2903
-0.4003,-0.3818,2.2994
1.7776,0.4610,0.0264
2.8431,1.2684,-1.2159
1.7293,-0.0750,-2.0333
-0.3223,0.2591,-0.1438
1.2089,0.7139,0.3213
3.3803,-1.3096,-0.5866
-0.4925,-1.8019,0.3631
-1.0512,-0.0752,1.1951
0.0604,-0.9542,-0.0598
-1.0534,-1.8152,0.8429
-1.9345,0.2818,1.6646
-0.3828,0.7332,0.4977
0.6157,-0.0924,-0.5806
-1.5075,-0.0121,0.4318
-0.5661,-0.3518,0.5367
0.4628,-0.7392,2.1375
1.2758,-0.7291,-0.4346
0.6990,0.1558,-1.5504
0.2127,1.5143,0.2988
1.6607,0.1899,0.3258
3.0827,-0.3040,-0.4157
0.9850,-0.2526,0.5647
0.7075,-1.3692,0.3182
0.6610,-0.3781,1.2110
0.5829,0.9927,-0.8351
-0.5059,-0.4103,-0.7024
-1.3799,0.4113,-0.0226
-0.7679,-0.1551,-0.5078
-0.8338,0.8655,1.2711
0.3669,1.7915,0.5791
2.8684,0.2249,-0.0222
2.3422,-2.1925,1.5277
0.5449,-1.3485,0.5016
-0.9720,-1.5652,0.9995
-0.2819,-2.0103,0.8050
-0.4050,-0.9102,-0.1474
1.2290,1.2340,-0.1403
0.9775,0.5881,0.0074
0.8928,-0.2656,-1.0909
1.2154,-1.9603,-0.3449
-2.1347,-1.5314,0.8543
-1.6447,-1.6981,0.3097
-1.7943,-0.1772,-0.9438
-1.3174,-0.2681,2.3635
-0.8238,-0.3080,-1.0302
-0.9857,-0.0387,0.6226
-1.7096,-0.1961,0.7254
0.5095,0.8587,1.2773
1.0115,0.9631,-0.8594
1.1304,-0.0762,0.0250
0.5405,-0.0061,-0.1907
0.4157,0.6297,1.1478
1.3314,1.6477,0.3916
2.5978,0.8155,0.4278
1.7955,1.5125,0.5518
2.3931,0.1296,1.9756
1.0194,-0.5309,0.6923
-0.6482,-1.6041,0.9027
-2.0638,0.0783,-0.9066
-2.3104,-0.6217,0.7232
-2.7028,-1.5488,-1.2161
-3.6770,0.3259,0.9823
-0.5380,-0.1116,0.1898
0.1506,-1.0194,-0.8393
-1.4684,0.5765,-1.0996
-0.3780,0.2922,-0.0416
0.4147,0.8282,0.1772
3.6239,0.0575,-0.5058
0.0993,0.5253,-0.2700
0.6358,1.4419,-0.2458
0.0961,0.6216,-0.4665
1.6350,1.8401,-0.1251
2.0536,0.5034,0.3386
2.0354,-0.4098,1.3676
1.4690,-0.0265,0.7129
1.7255,1.0452,-0.4889
-1.3607,0.2152,1.6988
-0.9417,-0.5804,1.2673
-0.3104,0.0354,-0.1669
-1.4773,1.3767,1.1095
1.3917,0.2084,-0.4381
1.9501,-1.4859,-0.6565
-1.7262,-0.7697,-0.6213
-2.1163,0.5583,1.7212
0.7395,-0.2309,0.2445
2.1247,-0.1471,0.4235
2.1559,-1.8069,0.1771
0.4658,-0.9132,-0.2899
-1.4410,0.1134,0.5999
-0.3210,0.6739,0.7956
0.8622,0.6205,2.0819
1.1989,0.9264,-0.7232
1.5018,-0.6085,1.6581
0.6567,0.1631,0.7966
0.3771,-1.3211,-1.5933
0.6463,-1.4225,1.1075
-0.4998,0.8074,1.7491
2.9929,1.4041,1.2300
EOF
# ARDL(1,1): y on x with one AR lag and one distributed lag, unrestricted intercept (case III)
friedman estimate univariate ardl ardl.csv --dep=y --p=1 --q=1 --case=3

# IC-selected lag orders (AIC grid over p∈1:max-p, q∈0:max-q)
friedman estimate univariate ardl ardl.csv --dep=y --p=auto --q=auto --max-p=4 --max-q=4 --ic=aic

# Per-regressor distributed-lag orders (one entry per regressor)
friedman estimate univariate ardl ardl.csv --dep=y --p=2 --q=2,1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--p` | | String | `auto` | AR order: `auto` or an integer ≥ 1 |
| `--q` | | String | `auto` | DL order: `auto`, an integer, or a comma-separated per-regressor list |
| `--max-p` | | Int | `4` | Max AR order for `auto` IC selection |
| `--max-q` | | Int | `4` | Max DL order for `auto` IC selection |
| `--ic` | | String | `aic` | Selection criterion: `aic`, `bic` |
| `--case` | | Int | `3` | PSS deterministic case 1..5 (I none; II restricted intercept; III unrestricted intercept; IV +restricted trend; V +trend) |
| `--trend` | | String | `none` | Informational trend label: `none`, `const`, `trend` (deterministics are governed by `--case`) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** levels coefficient table (`term|estimate|std_error|stat|p_value`) + a long-run coefficient table + diagnostics (`p`, `q`, `case`, `trend`, `ic`, `selected`, `nobs`, `K`, `sigma2`, `loglik`, `aic`, `bic`, `alpha`, `alpha_se`, `alpha_t`, `longrun_denom` = `1 − Σφ̂`). `ARDLModel` is not Tables.jl-registered, so tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). See [`test coint ardl-bounds`](test.md#test-ardl-bounds) for the Pesaran-Shin-Smith bounds test. **Trend-vocabulary note:** ARDL uses `none|const|trend` (distinct from cointreg's `none|const|linear` and PMG's `:constant`).

---

## estimate univariate nardl

**Nonlinear (asymmetric) ARDL** of Shin, Yu & Greenwood-Nimmo (2014). Each regressor selected by `--asymmetric` is decomposed into positive/negative partial sums `x⁺, x⁻` (cumulated from `Δx`), and the pair replaces the original column in the ARDL design. The enlarged design is estimated by the same ARDL machinery, so an asymmetric regressor contributes **two** columns to the number-of-regressors `k` that indexes the bounds table. The single leaf folds the split-regressor coefficient table, the asymmetric long-run coefficients (θ⁺/θ⁻), and the cached enlarged-`k` **bounds decision** (F/t decision symbols — no p-value) into one call.

```bash
cat > nardl.csv <<'EOF'
y,x1,x2,x3
0.0000,-1.4309,1.2111,0.2411
-2.3910,-2.3674,1.8497,0.9276
-0.0937,-1.9735,3.3784,-1.2848
-0.0035,-2.4976,2.5880,-0.0926
1.2374,-1.9720,3.0286,0.2302
1.4611,-1.1646,1.6283,0.3995
3.3157,-2.6082,-0.0191,0.5037
0.2237,-1.5911,-1.3997,0.5754
1.4473,-2.1867,-0.6720,0.9883
1.7798,-0.0927,-0.4592,1.3804
2.7337,0.6360,-2.0905,0.3659
0.4595,0.0970,-0.7730,2.1900
0.3307,0.2985,0.2017,-0.4826
0.5371,0.5135,0.0215,-0.1999
0.2903,0.8430,-0.2206,0.3212
1.2325,2.2363,-0.2324,-0.7842
1.2709,2.7691,-1.4559,-1.4787
0.7217,4.4298,0.8953,-1.3203
2.7213,5.0640,0.4247,1.1607
1.5843,4.8862,0.2282,-0.6564
0.4123,3.3618,-0.1004,-1.3429
0.2721,1.8013,-0.7741,1.8865
-0.6863,2.0061,-1.6877,0.3718
-2.8676,2.6971,-1.3566,0.1919
-1.5576,4.1404,-2.6007,-0.9653
-0.6166,3.5271,-3.6535,0.2680
-2.4847,3.6048,-4.4704,-0.5162
-4.0629,2.7919,-3.6700,0.2369
-2.2688,2.3695,-4.6749,-0.0350
-2.9252,0.0901,-5.6805,-0.2418
-2.3834,0.8289,-5.3612,0.2012
-1.5760,0.1063,-6.5054,-0.9184
-1.0543,0.0336,-6.8412,-0.4392
-1.8212,0.4794,-5.9577,-0.8090
-1.2544,0.8184,-5.5545,0.3710
-0.5172,-0.4958,-5.5332,0.6902
-2.2523,1.0224,-4.0146,0.7855
-0.0031,1.7797,-4.4444,-1.9472
0.3996,2.2798,-5.0643,1.7085
-2.7603,1.6202,-6.8362,-0.2375
-4.1883,0.0160,-6.8148,-0.1412
-3.6468,-1.6142,-6.1944,-0.0681
-1.6892,-1.8226,-6.8769,-0.0803
-3.0067,-1.6620,-5.0036,1.2342
-3.8005,-2.3653,-3.9944,0.1098
-4.2811,-0.5359,-3.0813,0.2797
-1.1539,-0.2347,-4.3027,0.9304
-1.2887,0.7638,-4.0221,1.2970
-1.6971,1.6704,-3.6672,-1.0307
-0.8768,0.5999,-5.7272,-1.2348
-2.4817,1.5938,-5.7648,-1.9375
-0.9307,2.0440,-6.0204,-1.9188
-3.2401,0.7753,-7.7756,0.2924
-4.1734,1.4988,-7.2962,0.0792
-2.2589,2.5708,-5.2544,-0.0416
-2.4095,3.5474,-4.5155,0.3262
-2.5405,4.5992,-5.3830,0.2947
-2.2405,3.1891,-5.6547,1.1870
-0.8536,2.9416,-4.5419,1.6980
-1.4119,2.3959,-5.3900,-0.8051
-0.7885,2.4502,-5.0455,1.4943
-2.6673,2.5564,-5.0234,1.0679
-2.6624,3.6825,-4.8528,-0.7923
-1.1157,4.4346,-3.2024,0.1900
-0.6665,3.6057,-4.7396,-0.4194
-2.2603,4.5072,-3.5736,-1.6819
-3.6128,6.1333,-3.3146,0.0532
-0.8987,6.4396,-3.4147,-1.6109
-0.4178,4.9340,-5.0925,0.0581
-1.3391,4.2893,-4.7905,-1.0263
-3.6921,4.1098,-5.2082,-0.3175
-4.4437,2.4865,-8.1657,0.8178
-4.9516,2.3482,-9.5502,0.1312
-5.8595,1.0755,-10.7635,-0.7861
-4.6412,1.8681,-11.7892,0.2418
-5.9921,2.5525,-12.4139,0.7019
-6.0271,2.4760,-13.2597,0.9791
-7.4882,1.2212,-11.7046,-0.8152
-8.3554,1.5105,-10.6413,1.1413
-5.3635,0.8730,-10.7312,-0.1571
-5.2631,0.1852,-9.3442,-0.5343
-5.6723,1.2953,-7.2074,1.1896
-3.7394,0.5381,-6.7220,0.6387
-5.7506,-0.8387,-8.0534,0.6947
-3.2860,-0.0483,-7.6814,0.1497
-4.1718,1.7297,-6.2506,-1.7748
-4.3760,3.3390,-7.2576,0.4795
-4.0151,4.1200,-7.2693,0.5786
-3.0958,6.2121,-6.3323,-0.0953
-1.8745,5.8566,-5.1465,1.7100
-1.6655,8.0319,-4.2953,0.1526
0.0412,10.1304,-3.9228,1.7200
0.1431,9.7881,-4.0654,1.2117
-0.1751,10.2012,-4.6385,-0.6396
-3.0308,8.9144,-3.6338,-0.7930
-1.9657,7.8882,-2.7063,-0.2797
-1.2365,8.4540,-3.1945,-0.0113
-0.7690,7.2904,-3.8889,0.7272
-1.7515,7.5053,-2.6292,-0.5603
-1.8921,7.9680,-1.6276,-1.0065
-1.5708,8.1081,-2.3987,2.1801
-2.9568,9.0864,-4.0586,0.0804
-2.3190,11.0437,-3.9439,0.3364
0.1270,11.2392,-3.1359,1.7954
0.6622,12.2614,-2.1745,0.1699
-0.2577,13.7756,-1.3588,-2.2582
-0.1478,13.3385,-2.9133,0.5349
-1.4913,12.6892,-2.8707,-0.5618
-1.6749,10.2758,-3.2604,1.0533
-1.8982,10.7278,-4.0047,-1.7354
-1.2269,11.8046,-1.3695,0.2499
1.1564,12.2655,-1.3752,0.8661
-1.6952,14.3927,-1.1273,1.4783
-0.8122,15.9505,-1.4353,1.0354
-0.3060,16.7960,-0.7553,1.0028
0.0852,16.7870,0.4081,0.0633
0.5413,15.9361,0.1182,0.0468
1.9214,16.0754,0.0822,-0.9303
-0.0570,16.6072,-0.3726,1.0303
0.8173,16.5707,-1.4050,1.6179
-0.1884,16.2956,-1.5965,0.6780
-0.5241,15.9405,-1.2555,-0.7966
-0.3205,16.6712,-1.2455,-1.3283
0.7895,14.9912,-1.4998,-0.4453
-0.1765,14.7031,-3.3893,1.6378
-2.2084,14.8050,-3.0640,0.2403
-1.2683,15.5314,-2.9082,-0.8941
-0.4565,16.2651,-1.3843,-0.2811
-1.6973,16.0675,-2.0444,0.8913
-0.8740,15.5129,-3.4492,-0.5787
-1.5130,14.3707,-5.4046,-0.3998
-2.5066,15.5692,-6.0746,-0.4626
-2.0161,16.1862,-6.1692,-0.8152
-0.5589,16.4233,-5.9414,2.0070
-3.5114,15.7272,-7.5530,-0.7240
-3.5554,14.6298,-8.1456,0.3463
-5.8341,15.8311,-7.1581,1.2522
-3.7431,15.8515,-7.1210,-0.0338
-2.7078,16.3567,-7.4882,-0.3280
-4.8266,18.1926,-7.8839,-0.0766
-2.0583,16.6908,-9.4924,0.0751
-3.3444,15.9469,-10.9264,-0.1298
-4.8026,16.3480,-11.4810,-0.3633
-5.2937,17.0060,-10.2823,-0.3061
-4.8098,15.9949,-9.1563,0.1878
-4.6946,15.9467,-9.3394,1.8282
-4.7036,15.3728,-8.7417,-0.3325
-3.4928,14.8243,-8.3464,0.8724
-3.1321,15.2410,-7.2124,-0.1074
-4.0231,15.4700,-7.9408,-0.8790
EOF
# Split every regressor into +/- partial sums
friedman estimate univariate nardl nardl.csv --dep=y --asymmetric=all --p=1 --q=1

# Split only the 1st and 3rd regressors (others enter symmetrically)
friedman estimate univariate nardl nardl.csv --dep=y --asymmetric=1,3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st numeric) | Dependent column |
| `--asymmetric` | | String | `all` | `all` or comma-separated 1-based regressor indices to split |
| `--p` | | String | `auto` | AR order: `auto` or an integer ≥ 1 |
| `--q` | | String | `auto` | DL order: `auto`, an integer, or a comma-separated list (over the **split** regressors) |
| `--max-p` | | Int | `4` | Max AR order for `auto` IC selection |
| `--max-q` | | Int | `4` | Max DL order for `auto` IC selection |
| `--ic` | | String | `aic` | Selection criterion: `aic`, `bic` |
| `--case` | | Int | `3` | PSS deterministic case 1..5 |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |
| `--plot-save` | | String | | Save multipliers figure to HTML file |
| `--plot` | | Flag | | Open multipliers figure in browser |

**Output:** split-regressor coefficient table (labels carry `_POS`/`_NEG` suffixes) + asymmetric long-run table (θ⁺/θ⁻) + diagnostics including the enlarged-`k` bounds decision (`k_orig`, `k`, `asym`, `f_stat`, `t_stat`, `f_decision`, `t_decision`, `bounds_level`). NARDL has no `--trend` option (informational-only upstream). See [`test nardl-symmetry`](test.md#test-nardl-symmetry) for the long-/short-run symmetry Wald tests. The same `estimate univariate nardl` leaf emits the cumulative dynamic multipliers (`--horizon`, `--nreps`, `--level`, `--no-bootstrap`), plottable via `--plot`/`--plot-save` (one panel per asymmetric regressor: `m⁺`/`m⁻` with bands plus the asymmetry curve).

### Cumulative dynamic multipliers

**Cumulative dynamic multipliers** — the response of a variable to a permanent (step) change in a regressor — are emitted by this leaf (folded here at the v1.0.0 regroup; the two table keys are unchanged). For each asymmetric regressor, `m⁺_{j,h}` and `m⁻_{j,h}` are the response of `y` at horizon `h = 0…H` to a unit permanent change in that regressor's positive / negative partial sum, obtained by recursively iterating the estimated ARDL difference equation. They converge to the long-run θ⁺_j / θ⁻_j as `h → ∞`; the asymmetry curve `m⁺ − m⁻` traces how differently `y` reacts to increases vs. decreases. Optional pointwise percentile bands come from a recursive-design (condition-on-`x`) residual bootstrap.

The multipliers share the fit options above (`--dep`, `--asymmetric`, `--p`, `--q`, `--max-p`, `--max-q`, `--ic`, `--case` behave identically); only the band options are multiplier-specific:

```bash
cat > nardl.csv <<'EOF'
y,x1,x2,x3
0.0000,-1.4309,1.2111,0.2411
-2.3910,-2.3674,1.8497,0.9276
-0.0937,-1.9735,3.3784,-1.2848
-0.0035,-2.4976,2.5880,-0.0926
1.2374,-1.9720,3.0286,0.2302
1.4611,-1.1646,1.6283,0.3995
3.3157,-2.6082,-0.0191,0.5037
0.2237,-1.5911,-1.3997,0.5754
1.4473,-2.1867,-0.6720,0.9883
1.7798,-0.0927,-0.4592,1.3804
2.7337,0.6360,-2.0905,0.3659
0.4595,0.0970,-0.7730,2.1900
0.3307,0.2985,0.2017,-0.4826
0.5371,0.5135,0.0215,-0.1999
0.2903,0.8430,-0.2206,0.3212
1.2325,2.2363,-0.2324,-0.7842
1.2709,2.7691,-1.4559,-1.4787
0.7217,4.4298,0.8953,-1.3203
2.7213,5.0640,0.4247,1.1607
1.5843,4.8862,0.2282,-0.6564
0.4123,3.3618,-0.1004,-1.3429
0.2721,1.8013,-0.7741,1.8865
-0.6863,2.0061,-1.6877,0.3718
-2.8676,2.6971,-1.3566,0.1919
-1.5576,4.1404,-2.6007,-0.9653
-0.6166,3.5271,-3.6535,0.2680
-2.4847,3.6048,-4.4704,-0.5162
-4.0629,2.7919,-3.6700,0.2369
-2.2688,2.3695,-4.6749,-0.0350
-2.9252,0.0901,-5.6805,-0.2418
-2.3834,0.8289,-5.3612,0.2012
-1.5760,0.1063,-6.5054,-0.9184
-1.0543,0.0336,-6.8412,-0.4392
-1.8212,0.4794,-5.9577,-0.8090
-1.2544,0.8184,-5.5545,0.3710
-0.5172,-0.4958,-5.5332,0.6902
-2.2523,1.0224,-4.0146,0.7855
-0.0031,1.7797,-4.4444,-1.9472
0.3996,2.2798,-5.0643,1.7085
-2.7603,1.6202,-6.8362,-0.2375
-4.1883,0.0160,-6.8148,-0.1412
-3.6468,-1.6142,-6.1944,-0.0681
-1.6892,-1.8226,-6.8769,-0.0803
-3.0067,-1.6620,-5.0036,1.2342
-3.8005,-2.3653,-3.9944,0.1098
-4.2811,-0.5359,-3.0813,0.2797
-1.1539,-0.2347,-4.3027,0.9304
-1.2887,0.7638,-4.0221,1.2970
-1.6971,1.6704,-3.6672,-1.0307
-0.8768,0.5999,-5.7272,-1.2348
-2.4817,1.5938,-5.7648,-1.9375
-0.9307,2.0440,-6.0204,-1.9188
-3.2401,0.7753,-7.7756,0.2924
-4.1734,1.4988,-7.2962,0.0792
-2.2589,2.5708,-5.2544,-0.0416
-2.4095,3.5474,-4.5155,0.3262
-2.5405,4.5992,-5.3830,0.2947
-2.2405,3.1891,-5.6547,1.1870
-0.8536,2.9416,-4.5419,1.6980
-1.4119,2.3959,-5.3900,-0.8051
-0.7885,2.4502,-5.0455,1.4943
-2.6673,2.5564,-5.0234,1.0679
-2.6624,3.6825,-4.8528,-0.7923
-1.1157,4.4346,-3.2024,0.1900
-0.6665,3.6057,-4.7396,-0.4194
-2.2603,4.5072,-3.5736,-1.6819
-3.6128,6.1333,-3.3146,0.0532
-0.8987,6.4396,-3.4147,-1.6109
-0.4178,4.9340,-5.0925,0.0581
-1.3391,4.2893,-4.7905,-1.0263
-3.6921,4.1098,-5.2082,-0.3175
-4.4437,2.4865,-8.1657,0.8178
-4.9516,2.3482,-9.5502,0.1312
-5.8595,1.0755,-10.7635,-0.7861
-4.6412,1.8681,-11.7892,0.2418
-5.9921,2.5525,-12.4139,0.7019
-6.0271,2.4760,-13.2597,0.9791
-7.4882,1.2212,-11.7046,-0.8152
-8.3554,1.5105,-10.6413,1.1413
-5.3635,0.8730,-10.7312,-0.1571
-5.2631,0.1852,-9.3442,-0.5343
-5.6723,1.2953,-7.2074,1.1896
-3.7394,0.5381,-6.7220,0.6387
-5.7506,-0.8387,-8.0534,0.6947
-3.2860,-0.0483,-7.6814,0.1497
-4.1718,1.7297,-6.2506,-1.7748
-4.3760,3.3390,-7.2576,0.4795
-4.0151,4.1200,-7.2693,0.5786
-3.0958,6.2121,-6.3323,-0.0953
-1.8745,5.8566,-5.1465,1.7100
-1.6655,8.0319,-4.2953,0.1526
0.0412,10.1304,-3.9228,1.7200
0.1431,9.7881,-4.0654,1.2117
-0.1751,10.2012,-4.6385,-0.6396
-3.0308,8.9144,-3.6338,-0.7930
-1.9657,7.8882,-2.7063,-0.2797
-1.2365,8.4540,-3.1945,-0.0113
-0.7690,7.2904,-3.8889,0.7272
-1.7515,7.5053,-2.6292,-0.5603
-1.8921,7.9680,-1.6276,-1.0065
-1.5708,8.1081,-2.3987,2.1801
-2.9568,9.0864,-4.0586,0.0804
-2.3190,11.0437,-3.9439,0.3364
0.1270,11.2392,-3.1359,1.7954
0.6622,12.2614,-2.1745,0.1699
-0.2577,13.7756,-1.3588,-2.2582
-0.1478,13.3385,-2.9133,0.5349
-1.4913,12.6892,-2.8707,-0.5618
-1.6749,10.2758,-3.2604,1.0533
-1.8982,10.7278,-4.0047,-1.7354
-1.2269,11.8046,-1.3695,0.2499
1.1564,12.2655,-1.3752,0.8661
-1.6952,14.3927,-1.1273,1.4783
-0.8122,15.9505,-1.4353,1.0354
-0.3060,16.7960,-0.7553,1.0028
0.0852,16.7870,0.4081,0.0633
0.5413,15.9361,0.1182,0.0468
1.9214,16.0754,0.0822,-0.9303
-0.0570,16.6072,-0.3726,1.0303
0.8173,16.5707,-1.4050,1.6179
-0.1884,16.2956,-1.5965,0.6780
-0.5241,15.9405,-1.2555,-0.7966
-0.3205,16.6712,-1.2455,-1.3283
0.7895,14.9912,-1.4998,-0.4453
-0.1765,14.7031,-3.3893,1.6378
-2.2084,14.8050,-3.0640,0.2403
-1.2683,15.5314,-2.9082,-0.8941
-0.4565,16.2651,-1.3843,-0.2811
-1.6973,16.0675,-2.0444,0.8913
-0.8740,15.5129,-3.4492,-0.5787
-1.5130,14.3707,-5.4046,-0.3998
-2.5066,15.5692,-6.0746,-0.4626
-2.0161,16.1862,-6.1692,-0.8152
-0.5589,16.4233,-5.9414,2.0070
-3.5114,15.7272,-7.5530,-0.7240
-3.5554,14.6298,-8.1456,0.3463
-5.8341,15.8311,-7.1581,1.2522
-3.7431,15.8515,-7.1210,-0.0338
-2.7078,16.3567,-7.4882,-0.3280
-4.8266,18.1926,-7.8839,-0.0766
-2.0583,16.6908,-9.4924,0.0751
-3.3444,15.9469,-10.9264,-0.1298
-4.8026,16.3480,-11.4810,-0.3633
-5.2937,17.0060,-10.2823,-0.3061
-4.8098,15.9949,-9.1563,0.1878
-4.6946,15.9467,-9.3394,1.8282
-4.7036,15.3728,-8.7417,-0.3325
-3.4928,14.8243,-8.3464,0.8724
-3.1321,15.2410,-7.2124,-0.1074
-4.0231,15.4700,-7.9408,-0.8790
EOF
# Point + bootstrap-band multipliers to horizon 24 (default 500 reps)
friedman estimate univariate nardl nardl.csv --dep=y --asymmetric=all --horizon=24

# Point multipliers only (no bands) — fast
friedman estimate univariate nardl nardl.csv --dep=y --asymmetric=all --horizon=12 --no-bootstrap

# Narrower bands with fewer reps
friedman estimate univariate nardl nardl.csv --dep=y --asymmetric=all --horizon=24 --nreps=200 --level=0.90
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--horizon` | | Int | `12` | Maximum multiplier horizon `H` (≥ 0) |
| `--nreps` | | Int | `500` | Bootstrap replications for the bands (`0` = no bands) |
| `--level` | | Float64 | `0.95` | Bootstrap band coverage |
| `--no-bootstrap` | | Flag | | Skip bootstrap bands (point multipliers only) |

**Output:** one **tidy long table** melting the `n_asym × (H+1)` multiplier matrices — `horizon | regressor | m_pos | m_neg | m_diff`, with per-band low/high columns (`m_pos_lo`, `m_pos_hi`, `m_neg_lo`, `m_neg_hi`, `m_diff_lo`, `m_diff_hi`) present **only** when bands are computed (`--nreps > 0` and not `--no-bootstrap`). A summary block reports `horizon`, `n_asym`, `nreps`, `level`, `bootstrap`, and the long-run convergence targets `theta_pos`/`theta_neg`.

`NARDLMultipliers` is not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). The bootstrap is an rng-only family: reproducibility rides the global `--seed` (there is no per-estimator seed to record in a manifest).

---

## estimate panel pmg

**Dynamic heterogeneous-panel ARDL** in error-correction form (Pesaran, Shin & Smith 1999), estimated on a long-format panel (`--id-col`/`--time-col` default to the first/second columns; regressors via `--indep`). `--method` selects the estimator:

- `pmg` — **Pooled Mean Group**: a common long-run vector `θ` across units, with heterogeneous short-run dynamics and per-unit error-correction speeds `φ_i`. Fit by concentrated ML (block coordinate ascent).
- `mg` — **Mean Group** (Pesaran & Smith 1995): an unrestricted per-unit ARDL, averaged across units.
- `dfe` — **Dynamic Fixed Effects**: a pooled within-transformed EC regression with unit intercepts and cluster-robust SEs.

Each unit's ARDL(`p`, `q`) is written as `Δy_it = φ_i (y_{i,t-1} − θ' x_{i,t-1}) + Σ ξ_ij Δy_{i,t-j} + Σ ψ_ij' Δx_{i,t-j} + deterministics_i + ε_it`.

```bash
friedman data simulate panel --kind linear --n 20 --periods 30 --seed 7 --format csv --output panel.csv
# Pooled Mean Group: common long-run theta + heterogeneous short-run
friedman estimate panel pmg panel.csv --id-col=id --time-col=time --dep=y --indep=x1,x2 --method=pmg

# Mean Group and Dynamic Fixed Effects alternatives
friedman estimate panel pmg panel.csv --id-col=id --time-col=time --dep=y --indep=x1,x2 --method=mg
friedman estimate panel pmg panel.csv --id-col=id --time-col=time --dep=y --indep=x1,x2 --method=dfe --p=2 --q=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--id-col` | | String | (1st column) | Panel group id column |
| `--time-col` | | String | (2nd column) | Panel time column |
| `--dep` | | String | (1st variable) | Dependent panel variable |
| `--indep` | | String | (all others) | Long-run regressors, comma-separated |
| `--method` | | String | `pmg` | `pmg`, `mg`, `dfe` |
| `--trend` | | String | `constant` | Per-unit EC deterministics: `none`, `constant`, `trend` |
| `--p` | | Int | `1` | Autoregressive order (≥ 1) |
| `--q` | | Int | `1` | Distributed-lag order for all regressors (≥ 0) |
| `--maxiter` | | Int | `100` | PMG outer-loop max iterations |
| `--tol` | | Float64 | `1e-8` | PMG outer-loop convergence tolerance |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a long-run coefficient table `θ` (`term|estimate|std_error|stat|p_value`) + a short-run/error-correction table (`term|estimate|std_error`, with the adjustment speed `φ` as the first row) + diagnostics (`method`, `N`, `p`, `q`, `T_i`, `phi`, `phi_se`, `loglik`, `converged`, `iters`, `n_nonconv`). `PMGModel` is not Tables.jl-registered, so tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). Display SEs (`φ`, `θ`) can be `Inf` for degenerate units — rendered non-finite-safe. See [`test panel pmg-hausman`](test.md#test-pmg-hausman) for the PMG-vs-MG selection test. **Trend-vocabulary note:** PMG spells `--trend=constant` out — distinct from ARDL's `none|const|trend` and cointreg's `none|const|linear`; do not carry a `const` value here.

---

## estimate univariate midas

**MIDAS (MIxed-DAta Sampling) regression** (Ghysels, Sinko & Valkanov 2007) of a **low-frequency** target on `--k` **high-frequency** lags of a single indicator, aggregated through a parsimonious weight function `w(θ)`. The equation is `y_t = β₀ + β₁·Σₖ wₖ(θ) x_{t,k} + Σⱼ ρⱼ y_{t−j} + u_t`, where `x_{t,k}` is the `k`-th high-frequency lag (most-recent-first) inside low-frequency period `t`, and the `--p-ar` term makes it an ADL-MIDAS.

This is the only estimator with a **two-CSV mixed-frequency contract**: the low-frequency target comes from `--data` (column `--column`), and the high-frequency indicator from a separate `--hf-data` CSV (column `--hf-column`). The HF series must supply **at least** `--m` observations per low-frequency period, i.e. `length(HF) ≥ m × length(LF)`. The estimator anchors the *last* HF observation to the *last* target period and works backwards, so any **leading** ragged edge (extra early HF history) is dropped automatically — the natural nowcasting layout (a long high-frequency indicator against a shorter low-frequency target) is fully supported, and the number of dropped leading HF observations is reported on stderr. Only a HF series *shorter* than `m × LF` is rejected as a typed `data/shape` error. Both inputs load through the hardened univariate loader, so a missing/non-numeric cell or out-of-range column surfaces a typed `data/missing-values`/`data/column-range`.

`--weights` selects the aggregation scheme:

- `expalmon` (default) — two-parameter **exponential Almon** curve (Ghysels et al.), estimated by profiled NLS.
- `beta2` / `beta3` — **Beta** density weights (2- or 3-parameter); require `--k ≥ 2`.
- `almon` — polynomial Almon of degree `--poly-degree`.
- `umidas` — **unrestricted** U-MIDAS (Foroni, Marcellino & Schumacher 2015): the `K` lags enter with free coefficients (plain OLS, no weight function).

```bash
cat > gdp_q.csv <<'EOF'
y
0.4353
2.0379
0.6973
0.0506
0.6910
0.9440
0.6346
-0.1161
0.4855
0.0618
0.4416
0.6901
0.6514
0.6065
1.0350
0.9366
1.4916
0.6298
0.6153
0.4118
0.6701
0.9846
0.5085
0.5029
1.4107
0.9087
0.5930
-0.0505
1.0035
1.1964
0.8813
1.3922
-0.0134
-0.6546
-0.2905
0.4910
-0.0150
0.5874
1.2971
0.7648
0.0838
0.1783
-0.5997
0.5676
0.2897
-0.8898
-0.1315
0.0208
EOF
cat > ip_m.csv <<'EOF'
x
-0.5947
0.2145
1.1895
1.8636
3.1223
1.8004
1.8045
0.8969
-0.7970
-1.2618
-0.7471
-1.4381
-1.1982
0.2815
0.7675
1.1096
1.1219
0.6100
-1.4407
-0.0171
-1.5186
-0.8469
-0.7012
-0.3536
0.0048
-0.3305
0.6697
-0.8163
0.2205
-1.5376
0.1100
-0.4320
0.0717
1.5582
-1.0719
-1.0650
-0.1720
0.7789
1.9035
1.9386
1.8712
1.4161
1.2569
0.9508
1.6574
1.3195
1.5925
2.7309
3.0818
1.8131
1.1658
1.5509
0.4433
-1.5206
-2.0759
-0.9144
-0.8512
-0.9527
0.0802
-0.9956
1.5676
1.1204
0.4601
2.3590
0.5623
-0.1037
-0.1620
-1.0737
-1.0917
-0.1816
0.0423
-0.0189
0.9750
2.5691
3.3618
0.2599
1.5530
1.8628
1.7120
0.2152
-0.3013
-0.4206
-1.6870
0.0533
0.9279
0.6362
-0.5027
0.9940
1.3368
1.9990
0.9807
3.0823
2.0187
3.3679
0.3526
0.5551
0.4711
-2.1919
-2.1795
-2.7510
-3.3324
-3.0865
-3.3309
-2.0061
-0.9395
-0.3890
-1.1012
-1.2531
0.8012
0.2161
0.1305
-0.4964
0.1800
1.0113
1.5035
1.4782
1.7452
1.0084
1.3271
-0.0604
0.0587
0.9060
-0.3813
0.5120
0.6760
-0.7520
-2.2295
-3.2130
-3.2952
-1.9878
-1.1439
0.4276
2.5683
1.3192
-1.1159
-2.2710
-3.6206
-3.2250
-2.7985
-0.6826
-1.9870
-1.6404
-1.4032
-1.1155
EOF
# Nowcast a quarterly target from a monthly indicator (m = 3, 6 monthly lags)
friedman estimate univariate midas gdp_q.csv --hf-data ip_m.csv --m 3 --k 6 --weights expalmon

# ADL-MIDAS with one autoregressive lag of the target and Beta weights
friedman estimate univariate midas gdp_q.csv --hf-data ip_m.csv --m 3 --k 6 --weights beta2 --p-ar 1

# Unrestricted U-MIDAS (OLS on the K stacked lags)
friedman estimate univariate midas gdp_q.csv --hf-data ip_m.csv --m 3 --k 6 --weights umidas
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | | Int | `1` | Low-frequency target column in `--data` (1-based) |
| `--hf-data` | | String | | **Required.** High-frequency indicator CSV |
| `--hf-column` | | Int | `1` | High-frequency indicator column in `--hf-data` (1-based) |
| `--m` | | Int | | **Required, ≥ 1.** Frequency ratio HF/LF (e.g. 3 = monthly→quarterly) |
| `--k` | | Int | | **Required, ≥ 1.** Number of high-frequency lags |
| `--weights` | | String | `expalmon` | `expalmon`, `beta2`, `beta3`, `almon`, `umidas` |
| `--p-ar` | | Int | `0` | Autoregressive lags of the target (ADL-MIDAS, ≥ 0) |
| `--poly-degree` | | Int | `2` | Polynomial degree for `--weights almon` |
| `--horizon` | | Int | `1` | **≥ 1.** Direct forecast horizon: regresses `y_{t+h−1}` on HF lags dated `t` (1 = nowcast) |
| `--max-iter` | | Int | `500` | LBFGS iteration cap per NLS start |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** a headline **weight-curve table** (`lag|weight`, length `K`, most-recent-first; for `umidas` these are the raw lag coefficients) + a coefficient table (`term|estimate|std_error|stat|p_value` over `[β; θ]`, normal-approximation p-values) + diagnostics (`weights_kind`, `m`, `K`, `p_ar`, `poly_degree`, `h`, `nobs`, `r2`, `adj_r2`, `ssr`, `sigma2`, `aic`, `bic`, `loglik`, `converged`). `MidasModel` is not Tables.jl-registered, so tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). The restricted NLS is noisy on short samples; a "failed to converge from any start" is surfaced as `model/convergence`. **Direct multi-step note:** `--horizon h` fits a genuine direct h-step regression of `y_{t+h−1}` on information dated `t` — the target actually shifts, `nobs` drops by `h−1` tail periods, and `--horizon 1` reproduces the default exactly. The fitted horizon is fixed at estimation time — `forecast univariate midas` conditions on a fresh HF block at that same `h`. **Frequency-alignment note:** the loader requires `length(HF) ≥ m × length(LF)` and drops the leading ragged edge (reported on stderr); the estimator then drops any remaining incomplete `K`-block internally.

---

## estimate regime threshold

**Two-regime threshold regression** (Hansen 1996, 2000) — the general case, where the sample is split by a **separate** threshold variable rather than by a lag of the dependent variable. The model is `yᵢ = xᵢ'β₁·1{qᵢ ≤ γ} + xᵢ'β₂·1{qᵢ > γ} + uᵢ`. The threshold `γ` is estimated by grid search over the trimmed order statistics of `q`, minimising the concentrated sum of squared residuals; each regime is then fit by OLS and `γ`'s confidence interval inverts the Hansen (2000) likelihood-ratio statistic. [`estimate regime setar`](#estimate-setar) is the self-exciting special case of this command (`q = y_{t−d}`, `X` the lag matrix) and returns the same model type.

**Column partition:** `--dep` is the dependent variable, **`--threshold-col` is required** and names the splitting variable, and **every other numeric column becomes a regressor**. The threshold variable is deliberately *excluded* from the regressor matrix — including it would make the regressors collinear with the split and silently fit a different model rather than raise an error. No intercept is prepended: add a `const` column if you want one (the same convention as [`estimate regression reg`](#estimate-reg)).

As with `estimate regime setar`, a **Hansen (1996) sup-LM / sup-Wald linearity test** is fitted alongside by default and folded into the diagnostics (`--no-linearity` skips it; `--het` uses a heteroskedastic White bootstrap). `--ci-level` must be **exactly** `0.90`, `0.95`, or `0.99` — the Hansen (2000) critical values are tabulated only at those levels.

```bash
cat > thr.csv <<'EOF'
y,x1,x2,z
-1.5829,-1.8962,-0.6468,1.3803
1.1403,0.2096,0.1604,-1.3561
-1.7430,-1.1822,0.3141,0.2310
0.8469,-0.2900,0.0216,-0.5277
0.3792,-1.0000,-1.5015,-1.1402
1.5445,0.8749,0.7630,-0.4567
0.2588,-0.5452,-0.4627,-0.2873
0.5568,-0.1928,2.4868,0.4454
-1.7089,-1.0838,-0.2267,0.9455
0.9409,0.7329,0.2589,-1.9388
0.3898,-0.5099,-0.2906,-0.9838
-0.2131,-0.3784,1.7636,0.4166
1.2942,-0.0756,1.5402,-1.6651
-0.2385,-1.4518,0.6545,1.9911
0.2057,-0.0208,1.0816,1.3294
-0.3522,-1.6119,-0.8412,-1.8529
-1.2527,-0.2181,-0.9095,0.2702
0.3097,-0.2198,1.3377,0.4374
0.1916,-0.4004,-0.8226,-1.9723
0.9550,-0.1998,-0.2656,-1.2837
0.4405,-0.6744,-1.5165,-1.3403
1.1872,0.5108,-0.3545,-0.1522
-0.3795,-0.0034,0.4475,0.2680
0.1664,-0.4715,-0.0475,-0.1924
-2.0779,-0.2292,-1.4933,1.6791
-0.2110,-0.6771,0.8253,1.2597
0.9952,-0.1275,0.1982,-0.3953
0.0780,-0.3134,-2.5262,-1.1874
-0.5460,-1.8016,-1.0745,-0.5667
-1.3763,1.6475,-0.3293,1.4481
0.2374,-0.4450,-0.5190,-0.6047
-0.7449,-0.6714,0.1748,1.9643
0.4051,0.3004,1.0912,0.2631
-0.2899,-2.0892,-0.0686,-1.0526
-1.1836,-0.3978,-0.0806,0.6348
0.3666,0.3063,1.3692,0.6409
-0.0778,-0.2647,1.6155,0.0584
1.0909,0.0638,-0.3013,-0.8836
-0.1026,-0.4445,1.6310,0.5197
-0.2455,-0.3686,-1.7450,-0.0832
0.4004,-0.0409,1.5768,0.6132
-0.7491,0.1516,0.4915,0.1690
-0.1505,-1.0953,-0.8366,-1.5152
-1.7561,0.2789,-0.4919,1.6350
2.0103,0.2973,0.1402,-1.9311
0.9924,-0.6189,1.3421,-0.7570
0.3117,-0.5730,0.8810,-1.3145
1.4640,0.1168,0.3061,-0.6278
-1.0506,1.1628,-0.3762,0.4701
-1.0763,1.0874,0.1003,0.2033
-2.5203,-0.8322,-1.2046,0.8644
0.9493,-0.5420,-0.4007,-0.0422
-1.9570,-0.5626,-0.8540,1.3660
1.4242,0.3804,-0.3614,-0.6082
-0.9922,-0.1616,0.4402,0.1922
-0.9629,0.3171,-0.3292,0.0178
1.8581,1.2431,-1.7816,-1.9118
1.6166,0.2095,1.0736,-1.0881
1.5062,0.3925,-0.0283,-1.6654
1.8453,0.3319,0.4119,-1.0047
0.6058,-0.7830,-0.7260,-1.9736
0.5225,-0.1770,-0.2745,-0.8272
1.5537,-0.2603,-0.3142,-0.5045
-0.2127,-0.5396,1.4005,0.5873
-2.0006,1.4791,-1.2558,1.3749
1.6033,0.5280,0.8570,-0.3380
-1.2209,-2.7235,-0.1119,0.5267
-0.3941,-0.8549,0.6726,0.0791
0.2293,-0.1381,-0.6502,-1.0771
0.3994,-0.0448,-1.6936,-1.2043
0.9575,-0.8665,0.8799,-0.1909
-1.2759,-0.3710,-0.4135,1.1775
-0.6162,-0.4371,0.4377,0.3731
-1.3368,-0.5143,0.6646,0.7973
-2.2860,0.5875,-1.7728,0.9209
-1.3165,-0.0949,-0.5414,0.4851
-0.0588,-0.6114,-0.2410,-1.0228
-0.0758,-0.3384,0.5348,-0.2332
-0.4462,-0.0470,0.5672,0.0546
0.6297,-1.1425,0.7474,-1.9556
-0.1739,-0.5927,-0.2503,-0.8180
1.5553,0.5638,1.3254,-0.5629
2.4351,0.9575,0.0142,-1.9586
-0.7569,-2.3906,-0.0840,0.2487
-0.8665,2.4202,-0.5068,0.1956
-0.8621,-0.6503,-1.1471,-1.6421
1.7072,0.7853,-0.0346,-1.0031
-0.6188,-1.3780,0.2483,1.6171
2.8648,0.6909,0.2641,-0.2469
1.9652,0.0256,2.1634,-0.9582
-0.3964,-0.0801,0.2922,1.4507
0.7114,-0.3001,0.3616,-0.1773
-2.8043,-0.2529,-1.3116,0.5014
-1.4424,0.7368,-0.2629,1.6154
-1.5541,-0.7547,0.0175,0.1799
0.6093,-0.2550,0.4623,-1.3700
-0.8725,-0.3948,-0.2143,0.8557
-1.0009,-1.6353,0.3303,1.7420
-0.1119,0.0935,-1.0042,-0.3267
-0.2714,-0.0389,1.1146,0.6470
0.3116,-0.4811,1.0124,1.4971
0.0916,-1.3680,-1.1544,-1.3755
-1.5337,-0.3495,-1.5254,1.1298
0.2059,-0.1631,-0.6918,-0.1046
-0.6956,-0.0102,0.1349,0.2104
-1.8769,0.0515,-0.9080,1.6970
-1.6557,-1.1997,0.1357,1.2526
1.6219,1.0219,0.7226,-1.4643
0.9480,0.7933,0.9445,-0.3409
-0.7939,0.7897,1.0799,0.7031
-2.0188,0.4673,-1.4940,1.2469
1.5583,1.3174,-2.0205,-1.3571
-0.7047,0.7322,0.4616,0.8050
-0.7949,1.1286,-0.8071,0.0757
0.9221,0.3273,-0.8000,-1.6890
-1.5829,0.1460,-1.1211,0.0778
0.8345,0.6343,-0.6880,-0.2048
-0.0519,-0.7024,0.4905,-0.2246
0.2936,-0.2260,-1.5080,-0.9298
0.6054,0.2076,-1.4204,-0.5392
-0.5173,-0.5881,0.9426,1.0475
-0.8264,-2.4449,0.5579,-0.6309
-1.6980,-0.5837,-1.7672,1.4354
-3.1430,-0.7429,-1.9262,0.8083
-1.2428,0.8603,0.2674,1.0095
-0.1316,-1.9085,0.7396,-0.3894
1.3835,-0.7701,1.9407,-1.3091
3.2506,1.5907,0.5453,-1.9613
-1.3181,-2.3668,0.5256,-0.3718
0.9588,-0.2768,-0.3737,-0.1373
-0.4234,-0.6474,-0.0687,-0.4597
-0.5193,-1.7230,-0.5477,-1.5864
0.6738,0.0009,1.0372,-1.8263
-1.2552,-0.8936,0.2448,1.5105
-1.7161,-2.7129,0.9271,-0.4366
-0.3593,-0.6177,0.1761,1.4704
-1.6566,-1.3580,-1.0696,1.3318
-0.6771,1.0710,-0.1575,0.2986
-0.7203,0.0041,0.9333,1.4569
-0.2029,-1.1174,0.2323,1.8074
-1.9223,0.1939,-1.8631,0.5484
2.5792,1.8959,0.9185,-1.9888
-1.1782,-1.3007,-0.5801,0.5639
0.6836,-1.0197,1.2313,-0.0267
-1.0763,-0.1152,-0.4593,1.1629
1.2327,0.0345,-0.9882,-0.5635
-0.0257,0.1532,0.6913,0.7738
-0.4654,-1.5214,-1.2967,-0.5396
-0.7847,0.0903,1.0492,0.3360
-0.5811,-1.1880,-0.6180,-0.1933
0.6866,-0.7972,0.4867,-1.1570
1.2012,0.8919,-1.5426,-0.7188
0.5586,-0.7463,-0.0874,-1.7448
-2.3075,0.5790,-0.6422,0.4947
-0.0887,-0.3524,1.4833,1.5690
-1.8722,0.1424,-0.8778,0.3819
1.8099,0.1313,-0.2800,-1.3197
-1.7480,0.6172,-0.9160,0.1524
1.2465,0.7108,-0.0969,-0.9605
0.4625,-0.7590,0.0503,-0.4659
3.1204,1.6389,1.0477,-1.9899
0.8812,0.5865,0.6114,1.8361
-2.7610,0.9383,-1.6015,0.0917
1.4991,0.9798,1.7848,0.2860
-0.3372,-0.4837,0.0584,-1.6212
1.8370,-0.0699,1.0633,-1.4729
-0.5717,0.0771,-0.3956,1.5288
0.1804,0.2803,0.6994,1.3836
-1.9048,1.6931,-0.1608,0.6946
-1.3820,1.8525,-0.3553,0.7797
0.4528,3.4546,-0.1700,1.7261
-1.1222,1.8364,-0.9042,0.7053
0.1994,1.6879,0.4116,0.4060
1.0488,-0.0643,0.3296,-1.4062
0.6190,-0.8312,0.6249,-1.0821
1.4375,0.0256,1.2027,-1.1236
0.6745,-0.2744,0.9799,-1.8255
0.7738,-1.0003,0.4042,-0.3449
2.1752,-0.2356,1.0077,-1.8162
-1.3176,0.4402,0.1571,1.6334
-0.7202,0.0574,0.9318,0.4919
1.2342,0.9108,-0.0977,-0.6658
0.7406,0.6271,-1.7889,-0.9417
-1.4032,0.4425,-0.7161,0.9492
-1.2681,1.2754,-0.9550,1.5934
-1.1181,-0.0945,-0.4690,1.9793
1.1698,0.0908,-0.1489,-1.6637
1.5994,1.4748,0.1044,-0.2189
-0.4557,0.9748,0.5302,1.8926
-2.6375,-1.4883,-1.0347,0.3485
-1.3880,0.1402,-0.4425,1.2029
2.6338,1.5594,0.6812,-0.4596
-0.3765,0.4988,0.6124,1.4994
0.9036,1.2492,1.2468,1.8592
-0.1682,-1.4870,-0.2344,-0.9261
2.3556,0.4727,2.2310,-0.6646
0.7263,-1.9848,-0.6471,-0.3259
-1.6338,0.7406,-1.4951,1.8507
-0.7848,-1.1881,-0.3429,-1.7316
-2.3714,1.4473,-1.3337,0.4274
EOF
# Split the sample on z; x1 and x2 are the regressors, y the outcome
friedman estimate regime threshold thr.csv --dep y --threshold-col z

# 90% threshold CI, heteroskedastic bootstrap, skip the linearity test
friedman estimate regime threshold thr.csv --dep y --threshold-col z --ci-level 0.90 --het --no-linearity
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | first numeric | Dependent variable column |
| `--threshold-col` | | String | | **Required** — the variable that splits the sample (excluded from the regressors) |
| `--trim` | | Float | `0.15` | Trimming fraction for the threshold grid (0 < trim < 0.5) |
| `--reps` | | Int | `1000` | Bootstrap replications for the linearity test (≥ 1) |
| `--ci-level` | | Float | `0.95` | Threshold CI level: `0.90`, `0.95`, or `0.99` (exact) |
| `--het` | | Flag | off | Heteroskedasticity-robust bootstrap |
| `--no-linearity` | | Flag | off | Skip the Hansen (1996) linearity test |
| `--plot` | | Flag | off | Display an interactive plot |
| `--plot-save` | | String | | Save the plot to an HTML file |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one **two-regime coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`, with the blocks `regime1 (<q>≤γ)` / `regime2 (<q>>γ)` stacked and labelled with the actual threshold-variable name, normal-approximation z/p) + a diagnostics block (`threshold_var`, `gamma`, `gamma_ci_lower`, `gamma_ci_upper`, `gamma_ci_level`, `n`, `n1`, `n2`, `ssr`, `sigma2`, `aic`, `bic`, `is_setar`, and — unless `--no-linearity` — `sup_lm`, `pvalue_lm`, `sup_wald`, `pvalue_wald`, `gamma_sup`). `ThresholdModel` is not Tables.jl-registered, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). Every option is validated up-front (`usage/invalid`); a constant threshold variable, a sample too small for two regimes, or any other estimator failure surfaces as a typed `data/invalid`/`model/error`, never an uncaught internal error.

---

## estimate regime setar

**Self-exciting threshold autoregression (SETAR)** (Tong 1990; Hansen 2000) — a two-regime autoregression whose regime is switched by a lagged value of the series itself. The model is `yₜ = X_t'β₁·1{qₜ ≤ γ} + X_t'β₂·1{qₜ > γ} + uₜ`, with `qₜ = y_{t−d}` the self-exciting threshold variable and `X_t = [1, y_{t−1}, …, y_{t−p}]`. The threshold `γ` is estimated by grid search over the trimmed order statistics of `q`, minimising the concentrated sum of squared residuals; its confidence interval inverts the Hansen (2000) likelihood-ratio statistic (tabulated only for the three levels below).

`--d` is the delay lag `d` and accepts either a positive integer or `auto` (search the `1:p` grid and pick the delay with the smallest concentrated SSR). By default a **Hansen (1996) sup-LM / sup-Wald linearity test** is fitted alongside and folded into the diagnostics (`--no-linearity` skips it; `--het` uses a heteroskedastic White bootstrap for its p-values). `--ci-level` must be **exactly** one of `0.90`, `0.95`, `0.99` — the Hansen (2000) critical values are tabulated only at those levels.

```bash
# SETAR(2; 1, 1) with delay d = 1 and 1000 bootstrap replications
friedman estimate regime setar :nile --p 1 --d 1

# Auto-select the delay over the 1:p grid; heteroskedastic bootstrap, no linearity test
friedman estimate regime setar :nile --p 2 --d auto --het --no-linearity
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--p` | | Int | `1` | AR order (≥ 1) |
| `--d` | | String | `1` | Delay lag: an integer ≥ 1, or `auto` (=`1:p` grid) |
| `--trim` | | Float | `0.15` | Trimming fraction for the threshold grid (0 < trim < 0.5) |
| `--reps` | | Int | `1000` | Bootstrap reps for the Hansen test / threshold CI (≥ 1) |
| `--ci-level` | | Float | `0.95` | Threshold CI level: `0.90`, `0.95`, or `0.99` (exact) |
| `--het` | | Flag | off | Heteroskedastic (White) bootstrap |
| `--no-linearity` | | Flag | off | Skip the attached Hansen (1996) linearity test |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** one **two-regime coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`, with the two regime blocks `regime1 (q≤γ)` / `regime2 (q>γ)` stacked, normal-approximation z/p) + a diagnostics block (`gamma`, `gamma_ci_lower`, `gamma_ci_upper`, `gamma_ci_level`, `n`, `n1`, `n2`, `ssr`, `sigma2`, `aic`, `bic`, `p`, `d`, `is_setar`, and — unless `--no-linearity` — the attached `sup_lm`, `pvalue_lm`, `sup_wald`, `pvalue_wald`, `gamma_sup`). `ThresholdModel` is not Tables.jl-registered, so the coefficient table is hand-built (a documented [C051](#coefficient-table-format-c051) exception). Every option is validated up-front (`usage/invalid`); a too-short series or other estimator failure surfaces as a typed `data/invalid`/`model/error`, never an uncaught internal error. See also [`estimate regime threshold`](#estimate-threshold) (the general case, split by a separate variable), [`test hansen-linearity`](test.md#test-hansen-linearity) (the standalone linearity test) and [`forecast regime setar`](forecast.md#forecast-setar) (bootstrap-simulation forecasts).

---

## estimate regime star

**Smooth-transition autoregression (STAR)** (Teräsvirta 1994) — the smooth-transition sibling of SETAR. The conditional mean is a convex combination of two linear autoregressions whose weight is a smooth function `G(sₜ; γ, c) ∈ [0, 1]` of a transition variable `sₜ`: `yₜ = φ₁'zₜ·(1 − G) + φ₂'zₜ·G + uₜ`, with `zₜ = [1, y_{t−1}, …, y_{t−p}]`. Unlike SETAR's abrupt switch, `G` transitions smoothly, and the parameters are estimated by nonlinear least squares.

`--type` selects the transition shape: **`lstr1`** (logistic, one location), **`lstr2`** (logistic, two locations), **`estr`** (exponential), or **`auto`** (Teräsvirta's sequential LM3 model-selection procedure picks LSTR1 vs ESTR and reports the `H₀₄`/`H₀₃`/`H₀₂` p-value triple). By default the transition variable is self-exciting (`sₜ = y_{t−d}`, delay `--d`); an external transition series can be supplied via `--transition-col` (a 1-based column index, which then must be non-constant). `--n-gamma`/`--n-c` set the start-value grid resolution for the NLS.

```bash
# STAR(1) with auto shape selection, self-exciting transition sₜ = y_{t−1}
friedman estimate regime star :nile --p 1 --d 1 --type auto

# Fix a logistic one-location LSTR1(2); external transition variable in column 3
friedman data simulate var --seed 7 --format csv --output sim.csv
cut -d, -f2- sim.csv > star.csv
friedman estimate regime star star.csv --column=1 --p 2 --type lstr1 --transition-col 3
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--p` | | Int | `1` | AR order (≥ 1) |
| `--d` | | Int | `1` | Delay lag for the self-exciting transition var (≥ 1) |
| `--type` | | String | `auto` | Transition shape: `lstr1`, `lstr2`, `estr`, `auto` |
| `--n-gamma` | | Int | `15` | Grid points for the γ start values (≥ 2) |
| `--n-c` | | Int | `15` | Grid points for the c start values (≥ 2) |
| `--transition-col` | | Int | `0` | Column of an external transition var s (0 = self-exciting) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** two hand-built tables plus diagnostics — a **regime-weight coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`, the two blocks `regime1 (G→0)` / `regime2 (G→1)` stacked) and a **transition-parameters table** (`parameter|estimate|std_error|z_stat|p_value` over `γ` and the location(s) `c`, length 1 for LSTR1/ESTR or 2 for LSTR2), both with normal-approximation z/p; then a diagnostics block (`trans_type`, `sname`, `sigma_s`, `n`, `p`, `d`, `ssr`, `sigma2`, `aic`, `bic`, the Luukkonen–Saikkonen–Teräsvirta LM3 statistics `lm3_stat`/`lm3_pvalue`/`lm3_fstat`/`lm3_fpvalue`, `converged`, and — for `--type auto` only — the Teräsvirta selection triple `sel_H04`/`sel_H03`/`sel_H02`). Note the two **regime weights** here (`1−G` / `G`) are smooth combination weights, unlike SETAR's hard split; the `switching_variance` diagnostic is a Markov-switching concept and does not apply to STAR. `STARModel` is not Tables.jl-registered, so the tables are hand-built (a documented [C051](#coefficient-table-format-c051) exception). Every option is validated up-front (`usage/invalid`); a constant transition variable, too-short series, or NLS failure surfaces as a typed `data/invalid`/`data/shape`/`model/error`, never an uncaught internal error. See also [`test star-linearity`](test.md#test-star-linearity) and [`forecast regime star`](forecast.md#forecast-star).

---

## estimate regime ms-ar

**Markov-switching autoregression (MS-AR)** (Hamilton 1989) — the *mean-switching* autoregression `(yₜ − μ_{sₜ}) = Σⱼ φⱼ (y_{t−j} − μ_{s_{t−j}}) + εₜ`, `εₜ ~ N(0, σ²_{sₜ})`, where a latent `K`-state Markov chain `sₜ` (with transition matrix `P`) switches the level `μ` while the AR coefficients `φ` are **common** across regimes. Estimated by the Hamilton forward filter, the Kim smoother, and EM with a maximum-likelihood polish (delta-method standard errors). Regimes are labelled deterministically in order of increasing conditional mean `μ` (defeating label-switching across seeds), so regime 1 is always the lowest-mean state.

> **Note the `switching_variance` polarity:** for `estimate regime ms-ar` the variance is **common by default** (the Hamilton form) — `--switching-variance` turns per-regime variances *on*. This is the **opposite** default of [`estimate regime ms`](#estimate-ms), where the variance switches by default (`--no-switching-variance` turns it off). The two are intentionally not unified.

```bash
# 2-regime MS-AR(1) with a common variance (Hamilton form)
friedman estimate regime ms-ar :nile --p 1

# 3-regime MS-AR(2) with per-regime (switching) variances
friedman estimate regime ms-ar :nile --p 2 --k-regimes 3 --switching-variance
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--column` | `-c` | Int | `1` | Column index (1-based) |
| `--p` | | Int | `1` | AR order (≥ 1) |
| `--k-regimes` | | Int | `2` | Number of regimes (≥ 2) |
| `--max-iter` | | Int | `1000` | Max EM iterations (≥ 1) |
| `--switching-variance` | | Flag | off | Let σ² switch across regimes (default: off, Hamilton form) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** four hand-built tables plus diagnostics — a **per-regime coefficient table** (`regime|term|estimate|std_error|z_stat|p_value`: one switching `mu` row per regime, then a single `common-AR` block for the shared φ₁…φₚ, normal-approximation z/p), a **per-regime variance table** (`regime|sigma2|std_error`), the **wide K×K transition matrix** (`from_regime|to_regime1|…|to_regimeK`, `P[i,j] = Pr(sₜ=j | s_{t−1}=i)`, rows sum to 1) — the transition matrix renders **wide** (regime×regime), a documented [C051](#coefficient-table-format-c051) exception parallel to the MGARCH conditional-correlation matrix — and the **regime-probability table** described below; then a diagnostics block (`loglik`, `n_params`, `aic`, `bic`, per-regime `ergodic_k` and `expected_duration_k`, `switching_var`, `switching_ar`, `converged`, `iterations`). `MSRegModel` is not Tables.jl-registered, so all tables are hand-built. Every option is validated up-front (`usage/invalid`); a too-short series or EM failure surfaces as a typed `data/invalid`/`model/error`, never an uncaught internal error.

### Regime probabilities

Both `estimate regime ms-ar` and `estimate regime ms` emit a **regime-probability table** — for most applied
work the point of fitting a Markov-switching model at all, since it answers "which regime were
we in at time *t*":

```
period | regime  | filtered | smoothed
```

`filtered` is `Pr(sₜ = k | y₁…yₜ)` (real time, using only information available at `t`) and
`smoothed` is `Pr(sₜ = k | y₁…y_n)` (full sample). The smoothed path is the sharper of the two
and is what you normally want for dating regimes historically; the filtered path is what a
real-time observer would have seen.

The table is **long**, not one column per regime: `K` comes from `--k-regimes`, so a wide layout
would make the *column set* depend on a user option and every consumer would have to discover
`K` before reading the table. Long keeps the columns fixed and grows the row count (`n × K`)
instead — the same reasoning as
[`predict regression statespace`](predict_residuals.md#state-space-predict-statespace-residuals-statespace).
With `--output <file>` it is written to a `…_probabilities` path so it does not overwrite the
coefficient table.

---

## estimate regime ms

**Markov-switching regression (MS)** — a `K`-state switching regression `yₜ = xₜ'β_{sₜ} + εₜ`, `εₜ ~ N(0, σ²_{sₜ})`, where **every** coefficient (not just the level) switches with the latent `K`-state Markov chain, and (by default) the variance switches too. Regressors come from the numeric columns other than `--dep` (**no auto-intercept** — include a `const` column, exactly like [`estimate regression reg`](#estimate-reg)); when the dependent variable is the **only** numeric column, the command routes to the single-argument intercept-only dispatch (a switching-intercept model, `X = ones(n, 1)`). Regimes are labelled by increasing conditional mean.

> **Note the `switching_variance` polarity:** for `estimate regime ms` the variance **switches by default** — `--no-switching-variance` forces a common σ². This is the **opposite** default of [`estimate regime ms-ar`](#estimate-ms-ar) (common variance by default).

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
# 2-regime switching regression: dep = y, regressors = the other numeric columns
friedman estimate regime ms xs.csv --dep y

# Intercept-only switching-mean model (dep is the only numeric column), common variance
friedman estimate regime ms :nile --no-switching-variance
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | | Dependent variable column (default: first numeric) |
| `--k-regimes` | | Int | `2` | Number of regimes (≥ 2) |
| `--max-iter` | | Int | `500` | Max EM iterations (≥ 1) |
| `--tol` | | Float | `1e-8` | EM convergence tolerance (> 0) |
| `--no-switching-variance` | | Flag | off | Force a common σ² across regimes (default: σ² switches) |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** the same four hand-built tables as [`estimate regime ms-ar`](#estimate-ms-ar) (including the [regime-probability table](#regime-probabilities)) rendered by the shared renderer, but the per-regime coefficient table carries the **full per-regime switching coefficients** over the regressor names (`regime|term|estimate|std_error|z_stat|p_value`) rather than a `mu` row + common-AR block; then the per-regime variance table, the wide K×K transition matrix (a documented [C051](#coefficient-table-format-c051) wide exception), and the same diagnostics kv. Every option is validated up-front (`usage/invalid`); a too-short series, a dimension mismatch, or EM failure surfaces as a typed `data/invalid`/`data/shape`/`model/error`, never an uncaught internal error.

---

## estimate regression iv

Instrumental variables (2SLS) regression. `--endogenous` names the endogenous regressor(s) and `--instruments` names the **excluded** instrument(s) — extra columns that identify the endogenous regressors but do not enter the structural equation. Every *other* numeric column (besides `--dep` and the endogenous ones) is treated as an exogenous regressor and instrument; include a `const` column of ones for an intercept. So the regressor matrix `X` = all columns except `{dep, excluded instruments}`, and the instrument matrix `Z` = all columns except `{dep, endogenous}`.

```bash
cat > iv.csv <<'EOF'
y,const,x_endog,x2,z1,z2,z3
0.3064,1.0000,-0.4946,-0.0977,-0.4323,0.0049,0.6495
2.0114,1.0000,0.1547,1.9362,-1.1301,0.6955,-1.8623
0.2460,1.0000,-0.2393,-0.4447,0.6738,-0.8378,-1.4106
2.3038,1.0000,0.0549,0.9985,-1.1078,-0.0266,-0.1172
9.2374,1.0000,3.2077,0.9053,2.0139,0.3046,-0.9544
-1.7152,1.0000,-0.8095,-1.8181,0.9241,-0.0012,0.7731
3.8942,1.0000,1.4756,0.3237,-0.3593,1.4873,1.1691
1.7895,1.0000,0.5731,-1.2390,0.5705,0.0735,-0.6478
6.2974,1.0000,2.2317,0.2301,1.6116,-0.1933,1.0326
5.9311,1.0000,2.9347,0.3111,2.8340,0.1870,0.7009
-1.2740,1.0000,-1.0141,1.1853,-0.9233,-0.4171,0.0620
-0.2029,1.0000,-0.6574,-0.0121,1.0651,-0.8450,1.0833
6.4179,1.0000,1.5138,0.1789,0.5177,-0.2704,-0.3473
-0.8186,1.0000,-0.8661,0.3885,-0.2796,-0.6780,0.4114
9.9404,1.0000,3.9230,2.3625,1.0922,1.8147,-0.6007
7.0758,1.0000,2.5254,0.4140,0.5068,2.1164,-0.8683
5.1038,1.0000,1.7589,2.0204,1.0762,-0.4034,1.6278
-5.9734,1.0000,-3.2167,-0.5625,-0.5259,-2.8174,1.7321
1.0791,1.0000,-0.3432,-0.8609,-0.0025,-0.3863,0.2506
3.7307,1.0000,1.1910,0.7544,0.3950,0.6481,1.1744
-4.1899,1.0000,-1.5426,-0.7204,0.0196,-0.6465,-0.2666
4.6621,1.0000,1.3123,0.3158,0.0166,0.6672,-0.5812
-0.7377,1.0000,-0.4469,0.0200,-0.7684,0.6192,0.6487
6.4054,1.0000,1.6017,2.2437,0.1264,-0.6351,1.5900
6.2771,1.0000,1.1576,1.7754,0.1876,-0.2566,0.0957
1.8291,1.0000,-0.0762,2.3365,-0.0613,-0.9952,0.2360
3.4605,1.0000,0.7373,0.8747,-0.0147,-0.4358,0.0714
-3.4898,1.0000,-1.2702,-0.0400,0.6965,-1.1176,-0.8115
-0.6194,1.0000,-1.1388,-0.0445,-0.6586,-0.5410,-1.8115
8.6934,1.0000,3.3469,2.0775,0.6965,1.4677,0.1733
-0.1718,1.0000,-0.7425,-1.0296,-0.1535,-0.3205,-1.3024
2.5648,1.0000,0.4937,-0.4125,0.0562,1.0867,1.6761
0.9755,1.0000,-0.1821,-0.8564,-0.1909,0.3196,0.2252
3.5817,1.0000,0.3330,1.2175,0.8992,-1.5017,0.6634
5.0086,1.0000,1.1582,0.0406,0.7606,-0.0999,0.8723
0.2665,1.0000,0.0260,1.0076,0.0061,-0.4628,-1.0188
-2.7310,1.0000,-1.6667,1.4166,-0.4385,-1.2328,-1.0813
7.9647,1.0000,3.1310,2.9591,1.8564,-0.4728,1.4431
4.4799,1.0000,1.6124,1.0147,0.5390,1.2158,0.5262
-2.5652,1.0000,-1.0964,-2.2803,-1.1464,1.2109,0.1477
-2.6685,1.0000,-1.4778,-2.0186,-0.0044,-0.4199,0.8326
3.6496,1.0000,0.4982,-0.1195,-0.1123,-0.7206,-2.0376
3.9794,1.0000,1.4070,1.6103,0.7219,-0.0479,1.0889
-2.7168,1.0000,-0.9930,-0.8206,-0.2266,0.3352,0.2325
1.3093,1.0000,0.2053,-0.2643,-0.7393,1.3053,0.4797
2.3404,1.0000,0.5033,-1.3364,1.3382,-0.5865,0.7602
-6.7731,1.0000,-3.4079,-0.5429,-1.9925,-0.9460,2.1089
0.0522,1.0000,-0.3806,0.3772,-1.4141,-0.0598,0.7635
-5.7754,1.0000,-2.4498,-0.0042,-0.5228,-1.9906,-0.0085
2.5638,1.0000,0.1150,0.2278,-0.5143,-0.1406,-0.7843
5.2180,1.0000,1.3225,0.9646,-0.1273,0.4140,2.6861
-5.1744,1.0000,-2.4269,-0.1674,-0.0115,-1.9083,-1.9203
4.4091,1.0000,1.7610,-0.7103,0.9978,0.8787,-0.2251
-7.3749,1.0000,-3.8078,-2.7080,-1.5198,-0.6350,-0.2356
5.7856,1.0000,2.4430,-1.0960,2.9836,-0.2147,-0.9508
4.2935,1.0000,0.8569,1.2504,0.6114,-0.2908,-0.7051
-1.2648,1.0000,-1.2946,-1.2646,-0.7731,-0.1630,-0.2458
-2.5224,1.0000,-1.1947,-0.6231,-0.5715,-0.0458,-1.4142
-3.5314,1.0000,-1.5232,-0.9315,-0.4829,-0.6145,-0.5845
-8.3394,1.0000,-4.7201,-0.0705,-2.2315,-2.0009,0.0364
3.2163,1.0000,1.1174,0.5547,0.4008,0.8531,-1.8680
-0.1840,1.0000,-1.1762,-0.7909,-1.1112,-0.1396,-0.3742
-1.0721,1.0000,-0.6990,-0.9292,-0.5422,0.5131,-0.1692
-1.4708,1.0000,-1.2494,0.5514,-1.0960,0.2274,-0.4705
-2.7097,1.0000,-0.8321,-1.5990,-0.5980,1.1973,-0.4609
-0.5994,1.0000,0.0516,0.2762,0.0238,-0.0387,-0.4265
-2.4195,1.0000,-1.6685,-0.8188,-1.2858,-0.5418,-0.7753
7.2641,1.0000,3.9795,-0.2383,1.5169,2.6896,-1.0346
2.6724,1.0000,0.8245,0.7768,-1.2755,1.4945,0.4100
1.9520,1.0000,0.5791,0.6629,-0.4982,0.8572,-0.1451
5.2492,1.0000,1.3935,0.9547,-0.0256,1.1831,-0.0523
3.9559,1.0000,1.7980,-0.6987,0.6213,1.3859,1.4560
-2.2382,1.0000,-2.0332,-0.0096,0.2106,-2.1247,1.1216
0.6515,1.0000,0.0675,-0.7705,0.0313,-0.5518,-0.4285
2.5180,1.0000,0.2292,-1.0803,0.4855,0.1433,1.7598
2.0516,1.0000,1.1818,-0.4037,0.3616,0.6093,0.0311
-3.0838,1.0000,-1.7293,0.2887,-0.9806,-0.6596,1.2016
3.5381,1.0000,0.6130,0.0566,0.5672,0.1405,-1.7258
-3.6434,1.0000,-2.4933,-0.0766,-0.6660,-1.0533,1.7809
-3.8389,1.0000,-2.2080,-1.0630,-1.1683,-0.2962,-0.0724
-5.2639,1.0000,-2.8069,-0.0167,-0.1162,-1.9820,-0.6896
-1.3382,1.0000,-1.3080,0.3655,-0.5279,-0.4629,-0.7926
5.9462,1.0000,2.5496,1.8348,0.2155,1.5785,-2.4383
-4.5276,1.0000,-2.2158,-0.4151,0.2641,-1.2752,-1.2632
0.4747,1.0000,-0.5518,0.9959,-0.6346,0.6064,-0.7286
-2.1494,1.0000,-1.7489,0.0788,0.2830,-1.3202,1.5232
3.1163,1.0000,0.7996,3.0254,-0.0948,-1.0821,0.0675
4.6417,1.0000,1.2065,0.8162,-1.6627,2.3088,-0.4072
7.4092,1.0000,2.3841,1.8292,1.5091,-0.8978,1.1624
2.2541,1.0000,0.6098,0.9110,-0.0432,-0.1361,0.3831
-3.6124,1.0000,-1.4273,-0.7785,-0.1920,-0.4522,-0.6350
-4.3919,1.0000,-2.1721,-0.7726,0.8128,-2.7684,-0.8600
-4.0598,1.0000,-1.7994,0.1016,-1.4438,-0.2210,-1.7467
-2.3405,1.0000,-1.3743,-0.9190,-0.7308,0.6431,-0.1573
-1.4609,1.0000,-0.3542,0.4324,0.8894,-1.3524,-2.1867
-6.7741,1.0000,-3.5426,-0.5779,-1.9597,-1.3365,0.8101
-1.6562,1.0000,-1.2693,-0.1793,-0.9029,-0.9039,-1.6419
5.2353,1.0000,1.7623,-1.5250,1.6072,0.4324,0.0180
0.4749,1.0000,-0.0853,1.9743,0.5499,-0.9542,1.0328
-2.8929,1.0000,-1.2994,-1.0565,-1.0300,0.7867,-0.8240
EOF
# y ~ const + x2 + x_endog, with x_endog endogenous, instrumented by z1, z2
friedman estimate regression iv iv.csv --dep=y --endogenous=x_endog --instruments=z1,z2
friedman estimate regression iv iv.csv --dep=y --endogenous=x_endog,x2 --instruments=z1,z2,z3 --cov-type=hc1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--endogenous` | | String | (required) | Comma-separated endogenous regressor column names |
| `--instruments` | | String | (required) | Comma-separated **excluded** instrument column names (need at least as many as endogenous regressors) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + IV diagnostics (first-stage F-statistic, Sargan overidentification test). See also [`test iv weak-instrument`](test.md) for the full Stock-Yogo weak-instrument battery.

**k-class family (#72).** `--method` selects the estimator:

| `--method` | k used | Notes |
|---|---|---|
| `tsls` (default) | 1 | Two-stage least squares |
| `liml` | κ̂ | Limited-information maximum likelihood |
| `fuller` | κ̂ − a/(n−m) | Fuller (1977); `--fuller-a` (default 1) is approximately unbiased |
| `kclass` | your `--k` | Generic k-class: `--k 0` is OLS, `--k 1` is exactly 2SLS |

`--k` is **required** with `--method kclass` and rejected with any other method;
`--fuller-a` applies only to `--method fuller`. Both are usage errors (exit 2) rather
than upstream failures. The diagnostics block reports the `k-class k` actually used and,
for LIML/Fuller, `kappa_hat`.

```bash
cat > iv.csv <<'EOF'
y,const,x_endog,x2,z1,z2,z3
0.3064,1.0000,-0.4946,-0.0977,-0.4323,0.0049,0.6495
2.0114,1.0000,0.1547,1.9362,-1.1301,0.6955,-1.8623
0.2460,1.0000,-0.2393,-0.4447,0.6738,-0.8378,-1.4106
2.3038,1.0000,0.0549,0.9985,-1.1078,-0.0266,-0.1172
9.2374,1.0000,3.2077,0.9053,2.0139,0.3046,-0.9544
-1.7152,1.0000,-0.8095,-1.8181,0.9241,-0.0012,0.7731
3.8942,1.0000,1.4756,0.3237,-0.3593,1.4873,1.1691
1.7895,1.0000,0.5731,-1.2390,0.5705,0.0735,-0.6478
6.2974,1.0000,2.2317,0.2301,1.6116,-0.1933,1.0326
5.9311,1.0000,2.9347,0.3111,2.8340,0.1870,0.7009
-1.2740,1.0000,-1.0141,1.1853,-0.9233,-0.4171,0.0620
-0.2029,1.0000,-0.6574,-0.0121,1.0651,-0.8450,1.0833
6.4179,1.0000,1.5138,0.1789,0.5177,-0.2704,-0.3473
-0.8186,1.0000,-0.8661,0.3885,-0.2796,-0.6780,0.4114
9.9404,1.0000,3.9230,2.3625,1.0922,1.8147,-0.6007
7.0758,1.0000,2.5254,0.4140,0.5068,2.1164,-0.8683
5.1038,1.0000,1.7589,2.0204,1.0762,-0.4034,1.6278
-5.9734,1.0000,-3.2167,-0.5625,-0.5259,-2.8174,1.7321
1.0791,1.0000,-0.3432,-0.8609,-0.0025,-0.3863,0.2506
3.7307,1.0000,1.1910,0.7544,0.3950,0.6481,1.1744
-4.1899,1.0000,-1.5426,-0.7204,0.0196,-0.6465,-0.2666
4.6621,1.0000,1.3123,0.3158,0.0166,0.6672,-0.5812
-0.7377,1.0000,-0.4469,0.0200,-0.7684,0.6192,0.6487
6.4054,1.0000,1.6017,2.2437,0.1264,-0.6351,1.5900
6.2771,1.0000,1.1576,1.7754,0.1876,-0.2566,0.0957
1.8291,1.0000,-0.0762,2.3365,-0.0613,-0.9952,0.2360
3.4605,1.0000,0.7373,0.8747,-0.0147,-0.4358,0.0714
-3.4898,1.0000,-1.2702,-0.0400,0.6965,-1.1176,-0.8115
-0.6194,1.0000,-1.1388,-0.0445,-0.6586,-0.5410,-1.8115
8.6934,1.0000,3.3469,2.0775,0.6965,1.4677,0.1733
-0.1718,1.0000,-0.7425,-1.0296,-0.1535,-0.3205,-1.3024
2.5648,1.0000,0.4937,-0.4125,0.0562,1.0867,1.6761
0.9755,1.0000,-0.1821,-0.8564,-0.1909,0.3196,0.2252
3.5817,1.0000,0.3330,1.2175,0.8992,-1.5017,0.6634
5.0086,1.0000,1.1582,0.0406,0.7606,-0.0999,0.8723
0.2665,1.0000,0.0260,1.0076,0.0061,-0.4628,-1.0188
-2.7310,1.0000,-1.6667,1.4166,-0.4385,-1.2328,-1.0813
7.9647,1.0000,3.1310,2.9591,1.8564,-0.4728,1.4431
4.4799,1.0000,1.6124,1.0147,0.5390,1.2158,0.5262
-2.5652,1.0000,-1.0964,-2.2803,-1.1464,1.2109,0.1477
-2.6685,1.0000,-1.4778,-2.0186,-0.0044,-0.4199,0.8326
3.6496,1.0000,0.4982,-0.1195,-0.1123,-0.7206,-2.0376
3.9794,1.0000,1.4070,1.6103,0.7219,-0.0479,1.0889
-2.7168,1.0000,-0.9930,-0.8206,-0.2266,0.3352,0.2325
1.3093,1.0000,0.2053,-0.2643,-0.7393,1.3053,0.4797
2.3404,1.0000,0.5033,-1.3364,1.3382,-0.5865,0.7602
-6.7731,1.0000,-3.4079,-0.5429,-1.9925,-0.9460,2.1089
0.0522,1.0000,-0.3806,0.3772,-1.4141,-0.0598,0.7635
-5.7754,1.0000,-2.4498,-0.0042,-0.5228,-1.9906,-0.0085
2.5638,1.0000,0.1150,0.2278,-0.5143,-0.1406,-0.7843
5.2180,1.0000,1.3225,0.9646,-0.1273,0.4140,2.6861
-5.1744,1.0000,-2.4269,-0.1674,-0.0115,-1.9083,-1.9203
4.4091,1.0000,1.7610,-0.7103,0.9978,0.8787,-0.2251
-7.3749,1.0000,-3.8078,-2.7080,-1.5198,-0.6350,-0.2356
5.7856,1.0000,2.4430,-1.0960,2.9836,-0.2147,-0.9508
4.2935,1.0000,0.8569,1.2504,0.6114,-0.2908,-0.7051
-1.2648,1.0000,-1.2946,-1.2646,-0.7731,-0.1630,-0.2458
-2.5224,1.0000,-1.1947,-0.6231,-0.5715,-0.0458,-1.4142
-3.5314,1.0000,-1.5232,-0.9315,-0.4829,-0.6145,-0.5845
-8.3394,1.0000,-4.7201,-0.0705,-2.2315,-2.0009,0.0364
3.2163,1.0000,1.1174,0.5547,0.4008,0.8531,-1.8680
-0.1840,1.0000,-1.1762,-0.7909,-1.1112,-0.1396,-0.3742
-1.0721,1.0000,-0.6990,-0.9292,-0.5422,0.5131,-0.1692
-1.4708,1.0000,-1.2494,0.5514,-1.0960,0.2274,-0.4705
-2.7097,1.0000,-0.8321,-1.5990,-0.5980,1.1973,-0.4609
-0.5994,1.0000,0.0516,0.2762,0.0238,-0.0387,-0.4265
-2.4195,1.0000,-1.6685,-0.8188,-1.2858,-0.5418,-0.7753
7.2641,1.0000,3.9795,-0.2383,1.5169,2.6896,-1.0346
2.6724,1.0000,0.8245,0.7768,-1.2755,1.4945,0.4100
1.9520,1.0000,0.5791,0.6629,-0.4982,0.8572,-0.1451
5.2492,1.0000,1.3935,0.9547,-0.0256,1.1831,-0.0523
3.9559,1.0000,1.7980,-0.6987,0.6213,1.3859,1.4560
-2.2382,1.0000,-2.0332,-0.0096,0.2106,-2.1247,1.1216
0.6515,1.0000,0.0675,-0.7705,0.0313,-0.5518,-0.4285
2.5180,1.0000,0.2292,-1.0803,0.4855,0.1433,1.7598
2.0516,1.0000,1.1818,-0.4037,0.3616,0.6093,0.0311
-3.0838,1.0000,-1.7293,0.2887,-0.9806,-0.6596,1.2016
3.5381,1.0000,0.6130,0.0566,0.5672,0.1405,-1.7258
-3.6434,1.0000,-2.4933,-0.0766,-0.6660,-1.0533,1.7809
-3.8389,1.0000,-2.2080,-1.0630,-1.1683,-0.2962,-0.0724
-5.2639,1.0000,-2.8069,-0.0167,-0.1162,-1.9820,-0.6896
-1.3382,1.0000,-1.3080,0.3655,-0.5279,-0.4629,-0.7926
5.9462,1.0000,2.5496,1.8348,0.2155,1.5785,-2.4383
-4.5276,1.0000,-2.2158,-0.4151,0.2641,-1.2752,-1.2632
0.4747,1.0000,-0.5518,0.9959,-0.6346,0.6064,-0.7286
-2.1494,1.0000,-1.7489,0.0788,0.2830,-1.3202,1.5232
3.1163,1.0000,0.7996,3.0254,-0.0948,-1.0821,0.0675
4.6417,1.0000,1.2065,0.8162,-1.6627,2.3088,-0.4072
7.4092,1.0000,2.3841,1.8292,1.5091,-0.8978,1.1624
2.2541,1.0000,0.6098,0.9110,-0.0432,-0.1361,0.3831
-3.6124,1.0000,-1.4273,-0.7785,-0.1920,-0.4522,-0.6350
-4.3919,1.0000,-2.1721,-0.7726,0.8128,-2.7684,-0.8600
-4.0598,1.0000,-1.7994,0.1016,-1.4438,-0.2210,-1.7467
-2.3405,1.0000,-1.3743,-0.9190,-0.7308,0.6431,-0.1573
-1.4609,1.0000,-0.3542,0.4324,0.8894,-1.3524,-2.1867
-6.7741,1.0000,-3.5426,-0.5779,-1.9597,-1.3365,0.8101
-1.6562,1.0000,-1.2693,-0.1793,-0.9029,-0.9039,-1.6419
5.2353,1.0000,1.7623,-1.5250,1.6072,0.4324,0.0180
0.4749,1.0000,-0.0853,1.9743,0.5499,-0.9542,1.0328
-2.8929,1.0000,-1.2994,-1.0565,-1.0300,0.7867,-0.8240
EOF
friedman estimate regression iv iv.csv --dep=y --endogenous=x_endog --instruments=z1,z2 --method=liml
friedman estimate regression iv iv.csv --dep=y --endogenous=x_endog --instruments=z1,z2 --method=kclass --k=1
```

---

## estimate regression select

General-to-specific and stepwise variable selection. This is a **dedicated leaf rather
than an `estimate regression reg --select` flag**, so `estimate regression reg`'s envelope tables stay fixed —
a leaf whose table set changes with a flag forces every consumer to branch on it.

Regressors are every numeric column except `--dep`, and no intercept is prepended, so
include a `const` column if you want one. The result carries the refitted final model,
so the coefficient table is exactly what `estimate regression reg` would print for the selected
subset.

```bash
friedman data simulate cross-section --kind ols --seed 7 --format csv --output xs.csv
friedman estimate regression select xs.csv --dep=y
friedman estimate regression select xs.csv --dep=y --method=gets --criterion=bic
friedman estimate regression select xs.csv --dep=y --keep=x1
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--dep` | String | first numeric | Dependent variable column |
| `--method` | String | `bidirectional` | `forward`, `backward`, `bidirectional`, `best-subset`, `gets` |
| `--criterion` | String | `pvalue` | `pvalue`, `aic`, `bic` |
| `--p-enter` | Float64 | 0.05 | p-value to enter a regressor |
| `--p-remove` | Float64 | 0.10 | p-value to remove; must be ≥ `--p-enter` for bidirectional + pvalue |
| `--keep` | String | | Comma-separated regressor names always retained |

**Output:** the selected model's coefficient table, a `step | action | variable |
statistic` **selection path** (the audit trail), and a summary kv with the selected set,
forced-in variables, candidate count and the encompassing F-test where available.

---

## estimate regression sur

Seemingly-unrelated regressions (Zellner 1962), fitted by feasible GLS across a multi-equation system. The equation system is specified in a config TOML; each `[[equations]]` block names a dependent column and its regressors (column names from the data CSV). Efficiency gains over equation-by-equation OLS come from cross-equation error correlation.

```bash
cat > sys.csv <<'EOF'
cons,inv,income,wealth,interest
9.6213,3.7466,9.7300,4.9561,3.0496
11.0038,3.5685,10.8241,5.3830,2.8974
10.5377,5.6322,11.3399,5.7308,3.1512
12.4554,3.1075,10.8217,6.4938,2.5865
12.1865,4.4634,11.5939,6.2812,3.0896
12.2168,4.1951,10.2438,6.7838,3.4016
11.3857,4.0542,10.9373,5.9616,3.7808
10.4267,5.9367,10.4755,6.0244,2.3652
12.1158,2.8066,11.2069,5.2820,3.3747
10.3937,4.2514,11.7460,4.8897,3.1309
11.1345,4.6339,11.0788,5.4616,2.0204
12.7558,5.8378,11.7072,5.0359,2.6850
11.5436,3.2107,12.1491,5.8058,2.5009
9.3179,2.4597,11.6029,6.7142,3.2566
12.5934,4.3148,13.7041,7.0327,3.7348
16.0660,5.4354,14.6061,6.9330,3.6261
12.9775,4.3544,13.5240,6.4918,3.1203
11.3943,3.6352,12.6360,6.1233,3.6865
12.3958,4.3688,13.0528,6.1381,3.1927
14.4209,5.2826,13.4649,5.6923,3.1099
12.1418,5.9699,12.8380,5.6967,2.2423
12.3227,4.9181,14.1539,5.3572,2.6381
15.4654,4.2805,14.3509,5.7145,2.8151
12.9725,5.6746,13.5882,4.8480,2.6148
13.5677,4.3557,13.3136,5.1394,2.5067
11.3769,6.7845,13.2348,5.6670,2.7618
13.1566,3.8822,11.7815,5.2153,3.4961
11.6587,4.4018,11.0493,6.0006,3.2253
12.0974,2.2602,9.3394,6.8167,3.1322
11.7009,3.7168,9.1459,7.2116,2.8202
10.8148,3.0914,9.8585,6.5155,2.7736
10.2129,2.4447,8.6726,6.7006,2.9841
10.1486,3.5761,9.0947,5.9456,2.6288
12.2203,2.6201,8.0121,5.7678,3.0829
9.9784,3.4903,7.9484,5.1879,2.9269
10.2322,2.5764,7.5323,5.3162,2.8473
8.7541,2.8133,6.4201,4.9931,3.0777
5.8691,2.0094,5.9710,5.2117,2.9827
5.8387,0.8746,4.8455,5.7221,3.1307
8.8050,2.8923,5.2390,5.4196,2.5254
7.7037,1.7593,5.3852,5.7398,2.4967
7.7294,2.0246,6.6852,5.5845,2.5787
7.9693,1.2962,5.3219,5.5235,2.5036
8.4002,2.4077,6.5147,5.4212,3.6095
10.3493,1.1482,6.5359,5.0960,2.5570
7.8065,0.5582,7.0413,4.8611,3.1596
7.8815,1.7078,6.9528,5.3658,3.3252
10.1150,1.9820,8.5998,5.9365,3.6853
11.9703,3.1020,10.0858,5.9677,2.8775
11.9119,4.5089,11.2543,6.4340,2.7040
12.9611,5.9280,11.6138,6.9783,3.0669
10.6901,3.0685,9.3760,7.3531,3.8621
10.8563,3.1681,10.0323,6.3491,2.8459
10.8070,2.0755,10.0995,6.3572,3.4312
10.7831,2.5177,10.0656,7.0379,3.4552
12.5104,2.8201,10.6001,7.2411,2.4102
12.0756,2.4264,11.8936,7.2401,3.5430
13.7989,3.7845,12.2609,7.1123,3.3450
10.9419,5.4079,11.8944,7.3009,2.2118
9.8410,3.7544,11.2167,7.1661,3.4587
15.1807,3.8808,11.6868,7.6377,3.6026
12.1156,4.2164,12.8853,7.6401,3.0263
14.6803,4.7998,13.5333,7.6857,3.1289
14.4351,4.6395,14.0911,7.9753,3.3429
15.1688,3.6197,13.7401,8.6349,3.1561
15.7800,5.2441,12.6042,8.6076,2.5656
14.4475,4.8598,13.6503,8.8807,2.4079
15.5107,5.1740,14.3567,8.7914,2.6227
12.9795,3.2445,12.6290,8.2390,2.6319
13.5287,5.4383,12.0119,8.2868,3.2966
12.4532,6.3184,13.1132,8.6068,2.3627
16.0988,4.4005,14.2810,8.8344,2.5705
14.3650,3.9635,13.7401,8.8387,2.5576
14.9352,4.5734,16.0936,8.7589,3.6032
16.6555,6.7115,17.5953,8.1946,3.8243
17.4242,8.0428,18.6506,8.1787,3.2109
19.0831,6.1222,18.6230,9.0188,3.3874
15.3310,4.8430,17.3317,8.9530,3.3154
16.6189,5.8805,18.2422,8.9830,2.5263
19.7179,8.0698,20.1207,9.7255,2.6624
19.2529,7.8305,21.1347,9.8329,3.2226
19.1176,6.9583,20.1568,10.0079,3.0499
20.3643,7.5669,21.3955,9.4820,1.9510
18.6783,6.6485,20.8306,9.9392,2.5116
18.6850,7.0597,18.7326,10.6770,2.9604
17.0189,7.8406,19.1527,10.6967,2.2692
15.5571,6.7251,16.5425,11.2700,3.2772
17.4190,5.2322,16.7555,11.8053,3.2964
16.8108,7.0040,17.8675,10.4892,3.6124
17.7845,6.5484,19.0060,11.2100,2.4238
19.5019,8.0419,21.8268,10.5587,2.8623
21.1215,10.2800,22.5966,10.8230,3.3842
20.2583,9.8450,21.7133,11.0986,2.5393
21.0313,8.1119,22.4288,11.0300,2.9969
22.1139,11.0795,23.2080,10.8995,2.6350
23.0128,7.6764,22.7254,10.7584,2.9611
19.6020,7.7982,21.0755,10.5721,2.3558
20.9233,5.9411,20.8018,10.3949,2.9796
18.8793,6.7494,20.2074,10.0820,3.7376
17.9646,7.6299,19.9108,10.0833,3.5435
EOF
cat > system.toml <<'EOF'
[[equations]]
name = "consumption"
dep = "cons"
indep = ["income", "wealth"]

[[equations]]
name = "investment"
dep = "inv"
indep = ["income", "interest"]
EOF
friedman estimate regression sur sys.csv --config=system.toml
friedman estimate regression sur sys.csv --config=system.toml --iterate        # iterate FGLS to the MLE
friedman estimate regression sur sys.csv --config=system.toml --no-intercept
```

```toml
[[equations]]
name  = "consumption"       # optional; default eq1, eq2, ...
dep   = "cons"
indep = ["income", "wealth"]

[[equations]]
name  = "investment"
dep   = "inv"
indep = ["income", "interest"]
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--config` | String | (required) | TOML with `[[equations]]` blocks (`dep` + `indep`) |
| `--iterate` | flag | | Iterate FGLS to the Gaussian MLE |
| `--no-intercept` | flag | | Omit the per-equation constant (added by default) |
| `--format` | String | `table` | `table`, `csv`, `json` |
| `--output` | String | | Export file path |

**Output:** a tidy `equation \| term \| estimate \| std_error \| stat \| p_value \| ci_lower \| ci_upper` coefficient table (asymptotic normal inference) + a system-statistics table (equations, obs/eq, det(Σ), McElroy R², log-likelihood, FGLS iterations). SUR/3SLS result types are not Tables.jl-registered upstream, so the table is hand-built (a documented [C051](#coefficient-table-format-c051) exception, like the `io` family).

---

## estimate regression 3sls

Three-stage least squares (Zellner & Theil 1962) for a simultaneous system: each equation's regressors are projected onto the instrument space, then a system GLS estimator combines instrumentation with the SUR efficiency gain. Instruments are a common set (`[instruments].common`) or per-equation (`instr` in each `[[equations]]` block, with `--instruments perequation`).

```bash
cat > sys3.csv <<'EOF'
cons,inv,income,wealth,interest,gov,taxes,lag_income
9.6213,3.7466,9.7300,4.9561,3.0496,6.2545,3.4421,9.7300
11.0038,3.5685,10.8241,5.3830,2.8974,6.5137,2.7005,9.7300
10.5377,5.6322,11.3399,5.7308,3.1512,5.3392,5.9610,10.8241
12.4554,3.1075,10.8217,6.4938,2.5865,6.3171,4.2851,11.3399
12.1865,4.4634,11.5939,6.2812,3.0896,3.3523,5.5926,10.8217
12.2168,4.1951,10.2438,6.7838,3.4016,5.8335,4.4619,11.5939
11.3857,4.0542,10.9373,5.9616,3.7808,4.5866,4.1798,10.2438
10.4267,5.9367,10.4755,6.0244,2.3652,5.0701,5.0005,10.9373
12.1158,2.8066,11.2069,5.2820,3.3747,4.6952,4.6525,10.4755
10.3937,4.2514,11.7460,4.8897,3.1309,4.5660,3.6427,11.2069
11.1345,4.6339,11.0788,5.4616,2.0204,5.4745,4.1109,11.7460
12.7558,5.8378,11.7072,5.0359,2.6850,4.4205,3.5226,11.0788
11.5436,3.2107,12.1491,5.8058,2.5009,5.1192,4.8738,11.7072
9.3179,2.4597,11.6029,6.7142,3.2566,5.1533,2.9348,12.1491
12.5934,4.3148,13.7041,7.0327,3.7348,5.2484,3.9091,11.6029
16.0660,5.4354,14.6061,6.9330,3.6261,6.4308,4.3677,13.7041
12.9775,4.3544,13.5240,6.4918,3.1203,6.7749,3.9741,14.6061
11.3943,3.6352,12.6360,6.1233,3.6865,3.4432,4.2606,13.5240
12.3958,4.3688,13.0528,6.1381,3.1927,6.0260,2.6475,12.6360
14.4209,5.2826,13.4649,5.6923,3.1099,4.2447,1.9602,13.0528
12.1418,5.9699,12.8380,5.6967,2.2423,4.9504,5.5176,13.4649
12.3227,4.9181,14.1539,5.3572,2.6381,6.1485,3.4874,12.8380
15.4654,4.2805,14.3509,5.7145,2.8151,3.1431,3.7230,14.1539
12.9725,5.6746,13.5882,4.8480,2.6148,5.6319,4.2113,14.3509
13.5677,4.3557,13.3136,5.1394,2.5067,4.7175,4.6114,13.5882
11.3769,6.7845,13.2348,5.6670,2.7618,4.6779,4.8440,13.3136
13.1566,3.8822,11.7815,5.2153,3.4961,4.9806,4.8568,13.2348
11.6587,4.4018,11.0493,6.0006,3.2253,4.2278,3.4669,11.7815
12.0974,2.2602,9.3394,6.8167,3.1322,3.7937,3.8524,11.0493
11.7009,3.7168,9.1459,7.2116,2.8202,4.5444,3.5910,9.3394
10.8148,3.0914,9.8585,6.5155,2.7736,4.1491,2.0928,9.1459
10.2129,2.4447,8.6726,6.7006,2.9841,5.8379,3.7409,9.8585
10.1486,3.5761,9.0947,5.9456,2.6288,4.1651,3.7685,8.6726
12.2203,2.6201,8.0121,5.7678,3.0829,5.6295,2.7817,9.0947
9.9784,3.4903,7.9484,5.1879,2.9269,3.6292,2.1459,8.0121
10.2322,2.5764,7.5323,5.3162,2.8473,5.4586,3.7287,7.9484
8.7541,2.8133,6.4201,4.9931,3.0777,6.7826,3.4191,7.5323
5.8691,2.0094,5.9710,5.2117,2.9827,6.4724,3.6344,6.4201
5.8387,0.8746,4.8455,5.7221,3.1307,4.9495,5.3523,5.9710
8.8050,2.8923,5.2390,5.4196,2.5254,6.9723,3.7616,4.8455
7.7037,1.7593,5.3852,5.7398,2.4967,1.9335,3.7031,5.2390
7.7294,2.0246,6.6852,5.5845,2.5787,4.5954,2.5177,5.3852
7.9693,1.2962,5.3219,5.5235,2.5036,3.1783,3.6865,6.6852
8.4002,2.4077,6.5147,5.4212,3.6095,3.4597,4.8970,5.3219
10.3493,1.1482,6.5359,5.0960,2.5570,3.4126,4.5828,6.5147
7.8065,0.5582,7.0413,4.8611,3.1596,3.6609,3.2464,6.5359
7.8815,1.7078,6.9528,5.3658,3.3252,3.9764,4.8215,7.0413
10.1150,1.9820,8.5998,5.9365,3.6853,4.7396,6.0203,6.9528
11.9703,3.1020,10.0858,5.9677,2.8775,6.1194,2.6444,8.5998
11.9119,4.5089,11.2543,6.4340,2.7040,5.5454,3.7750,10.0858
12.9611,5.9280,11.6138,6.9783,3.0669,4.6016,2.1090,11.2543
10.6901,3.0685,9.3760,7.3531,3.8621,4.2037,5.5753,11.6138
10.8563,3.1681,10.0323,6.3491,2.8459,4.5460,2.3164,9.3760
10.8070,2.0755,10.0995,6.3572,3.4312,7.5211,4.2755,10.0323
10.7831,2.5177,10.0656,7.0379,3.4552,3.3508,4.2382,10.0995
12.5104,2.8201,10.6001,7.2411,2.4102,6.5089,5.2462,10.0656
12.0756,2.4264,11.8936,7.2401,3.5430,5.3355,3.9197,10.6001
13.7989,3.7845,12.2609,7.1123,3.3450,4.9901,3.6420,11.8936
10.9419,5.4079,11.8944,7.3009,2.2118,8.1059,2.4180,12.2609
9.8410,3.7544,11.2167,7.1661,3.4587,5.4250,2.9148,11.8944
15.1807,3.8808,11.6868,7.6377,3.6026,4.3050,3.8292,11.2167
12.1156,4.2164,12.8853,7.6401,3.0263,5.3485,4.9315,11.6868
14.6803,4.7998,13.5333,7.6857,3.1289,6.0672,2.1941,12.8853
14.4351,4.6395,14.0911,7.9753,3.3429,5.8004,4.8864,13.5333
15.1688,3.6197,13.7401,8.6349,3.1561,5.3674,3.4764,14.0911
15.7800,5.2441,12.6042,8.6076,2.5656,4.6335,2.3669,13.7401
14.4475,4.8598,13.6503,8.8807,2.4079,3.9401,4.3705,12.6042
15.5107,5.1740,14.3567,8.7914,2.6227,5.2591,4.4270,13.6503
12.9795,3.2445,12.6290,8.2390,2.6319,5.7531,4.9433,14.3567
13.5287,5.4383,12.0119,8.2868,3.2966,4.4289,4.7416,12.6290
12.4532,6.3184,13.1132,8.6068,2.3627,3.7642,3.3692,12.0119
16.0988,4.4005,14.2810,8.8344,2.5705,3.6252,4.4520,13.1132
14.3650,3.9635,13.7401,8.8387,2.5576,3.4638,3.9644,14.2810
14.9352,4.5734,16.0936,8.7589,3.6032,4.6140,4.1728,13.7401
16.6555,6.7115,17.5953,8.1946,3.8243,3.6088,3.6357,16.0936
17.4242,8.0428,18.6506,8.1787,3.2109,5.9728,3.0463,17.5953
19.0831,6.1222,18.6230,9.0188,3.3874,3.1845,3.8498,18.6506
15.3310,4.8430,17.3317,8.9530,3.3154,4.0532,4.4239,18.6230
16.6189,5.8805,18.2422,8.9830,2.5263,5.8916,2.7975,17.3317
19.7179,8.0698,20.1207,9.7255,2.6624,5.3266,3.9768,18.2422
19.2529,7.8305,21.1347,9.8329,3.2226,5.1122,3.1105,20.1207
19.1176,6.9583,20.1568,10.0079,3.0499,4.5480,2.6964,21.1347
20.3643,7.5669,21.3955,9.4820,1.9510,4.6975,3.5838,20.1568
18.6783,6.6485,20.8306,9.9392,2.5116,5.2822,4.4427,21.3955
18.6850,7.0597,18.7326,10.6770,2.9604,5.8265,4.8380,20.8306
17.0189,7.8406,19.1527,10.6967,2.2692,5.0626,3.1588,18.7326
15.5571,6.7251,16.5425,11.2700,3.2772,5.2252,3.3525,19.1527
17.4190,5.2322,16.7555,11.8053,3.2964,3.6550,2.9969,16.5425
16.8108,7.0040,17.8675,10.4892,3.6124,5.6693,4.3656,16.7555
17.7845,6.5484,19.0060,11.2100,2.4238,6.9152,4.0466,17.8675
19.5019,8.0419,21.8268,10.5587,2.8623,4.4018,4.4369,19.0060
21.1215,10.2800,22.5966,10.8230,3.3842,5.3389,5.3651,21.8268
20.2583,9.8450,21.7133,11.0986,2.5393,4.2854,3.6999,22.5966
21.0313,8.1119,22.4288,11.0300,2.9969,5.5119,3.6040,21.7133
22.1139,11.0795,23.2080,10.8995,2.6350,5.4507,5.0047,22.4288
23.0128,7.6764,22.7254,10.7584,2.9611,3.2787,3.8755,23.2080
19.6020,7.7982,21.0755,10.5721,2.3558,4.6877,3.4369,22.7254
20.9233,5.9411,20.8018,10.3949,2.9796,4.7766,4.8535,21.0755
18.8793,6.7494,20.2074,10.0820,3.7376,4.3979,4.8852,20.8018
17.9646,7.6299,19.9108,10.0833,3.5435,5.4481,2.5943,20.2074
EOF
cat > system.toml <<'EOF'
[[equations]]
dep = "cons"
indep = ["income", "wealth"]

[[equations]]
dep = "inv"
indep = ["income", "interest"]

[instruments]
common = ["gov", "taxes", "lag_income"]
EOF
cat > system_pe.toml <<'EOF'
[[equations]]
dep = "cons"
indep = ["income", "wealth"]
instr = ["gov", "lag_income"]

[[equations]]
dep = "inv"
indep = ["income", "interest"]
instr = ["gov", "taxes"]
EOF
friedman estimate regression 3sls sys3.csv --config=system.toml                       # common instruments
friedman estimate regression 3sls sys3.csv --config=system_pe.toml --instruments=perequation
```

```toml
[[equations]]
dep   = "cons"
indep = ["income", "wealth"]

[[equations]]
dep   = "inv"
indep = ["income", "interest"]

[instruments]
common = ["gov", "taxes", "lag_income"]
```

| Option / Flag | Type | Default | Description |
|--------|------|---------|-------------|
| `--config` | String | (required) | TOML with `[[equations]]` + instruments |
| `--instruments` | String | `common` | `common` (shared set) or `perequation` (each block's `instr`) |
| `--no-intercept` | flag | | Omit the per-equation constant |
| `--format` | String | `table` | `table`, `csv`, `json` |
| `--output` | String | | Export file path |

When the instruments span every regressor, 3SLS collapses to SUR; when every equation is exactly identified it collapses to equation-by-equation 2SLS. **Output:** the same tidy coefficient table as `sur` + a system-statistics table (with instruments-per-equation).

---

## estimate choice poisson

Poisson regression for count outcomes, fitted by IRLS.

```bash
cat > claims.csv <<'EOF'
claims,visits,const,x1,policy_years
3,1,1.0,-0.3597,2.2504
7,5,1.0,1.2037,2.7776
8,0,1.0,1.3969,2.5959
7,1,1.0,0.3172,2.1886
3,0,1.0,0.4141,1.5502
3,2,1.0,-0.4895,1.2050
4,0,1.0,-0.9141,1.7796
1,2,1.0,-0.9004,2.4234
3,0,1.0,-0.9984,2.9556
11,5,1.0,0.9292,2.2900
6,0,1.0,-0.0563,2.8386
9,0,1.0,0.1283,3.0804
3,3,1.0,-0.6400,3.6900
2,0,1.0,-1.0878,2.6435
1,1,1.0,-1.2020,3.2472
3,2,1.0,-0.8416,2.6172
4,1,1.0,0.5992,1.8807
0,1,1.0,0.0184,1.3647
4,4,1.0,-0.4568,2.6486
7,2,1.0,-0.2393,2.9442
7,0,1.0,-1.4273,3.7348
4,4,1.0,1.2307,2.1659
5,1,1.0,-1.2164,2.7451
4,4,1.0,0.0424,2.4421
4,0,1.0,2.1370,1.3158
2,2,1.0,-2.5512,2.6874
4,2,1.0,-1.4070,2.3391
1,2,1.0,-0.7237,1.8618
4,0,1.0,0.1166,3.3439
3,0,1.0,-1.7149,2.1915
4,0,1.0,-0.2353,2.7344
2,2,1.0,-0.0284,2.3673
2,1,1.0,0.1705,2.1417
0,0,1.0,-2.3884,2.4161
5,2,1.0,0.6464,2.8965
5,0,1.0,1.5969,2.1550
4,0,1.0,0.4366,1.6743
2,2,1.0,-0.7231,3.3982
2,2,1.0,-0.6134,2.7197
1,0,1.0,-2.6463,2.0205
2,2,1.0,0.4760,2.4542
3,2,1.0,1.5031,1.7176
5,5,1.0,0.6502,2.4674
1,1,1.0,-2.9773,2.9303
6,3,1.0,-0.4260,1.5341
4,2,1.0,-0.1029,2.9335
3,5,1.0,-0.4835,2.9038
5,2,1.0,1.0332,2.3641
2,0,1.0,-1.7443,2.5512
2,0,1.0,-0.7178,2.3333
7,3,1.0,0.5956,2.2770
2,1,1.0,0.9909,1.5691
5,1,1.0,0.1691,3.3152
4,4,1.0,1.0553,2.1643
9,8,1.0,0.5202,2.5674
6,3,1.0,-1.0593,2.3861
7,4,1.0,1.2935,2.7277
2,2,1.0,-0.5057,2.7836
1,0,1.0,-1.6306,1.9894
9,1,1.0,0.4380,2.6811
9,5,1.0,1.8143,2.3650
9,2,1.0,0.9592,2.0582
12,2,1.0,0.9973,3.1485
6,3,1.0,0.1906,3.0893
0,1,1.0,-2.4650,2.0478
4,2,1.0,0.6800,2.3489
4,3,1.0,0.1575,1.9946
0,0,1.0,-2.6411,1.9313
1,1,1.0,-0.6519,2.0088
4,3,1.0,-0.8797,2.7773
2,3,1.0,1.0611,1.7917
1,0,1.0,0.1234,1.7687
4,3,1.0,0.2982,2.6438
4,4,1.0,0.2427,2.1402
2,0,1.0,-1.3281,3.1146
1,0,1.0,-1.9638,2.0196
3,1,1.0,0.0572,2.2569
1,0,1.0,-0.2934,2.1122
2,0,1.0,-0.0143,1.3426
0,1,1.0,-0.1664,2.6739
EOF
friedman estimate choice poisson claims.csv --dep=claims --exposure=policy_years
friedman estimate choice poisson claims.csv --dep=visits --irr --conf-level=0.99
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent count column |
| `--offset` | | String | | Offset column, already on the log scale |
| `--exposure` | | String | | Exposure column, strictly positive; enters as `log(exposure)` |
| `--cov-type` | | String | `robust` | `robust`, `mle`, `hc0`–`hc3`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--tol` | | Float64 | 1e-10 | Convergence tolerance |
| `--conf-level` | | Float64 | 0.95 | Confidence level for the IRR interval |
| `--irr` | | Flag | off | Also report incidence-rate ratios |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**`--cov-type` defaults to `robust`, not `hc1`.** That mirrors the library, which reports the
Gourieroux–Monfort–Trognon pseudo-ML sandwich by default: Poisson QMLE stays consistent for the
conditional mean even when the equidispersion assumption fails, but only the sandwich standard
errors remain valid in that case. Use `--cov-type mle` for the (narrower) information-matrix
errors when equidispersion is credible — see [`test dispersion`](test.md#test-dispersion).

**`--offset` and `--exposure` are mutually exclusive** (exposure *is* an offset, log-transformed
for you); passing both is a usage error. Use `--exposure` for time-at-risk or population
denominators, `--offset` when your column is already logged.

`--irr` adds a second table of `exp(β)` with delta-method standard errors and confidence
intervals — the multiplicative reading of each coefficient.

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + optional IRR table
+ fit statistics (pseudo R², log-likelihood, deviance, AIC, BIC, convergence).

---

## estimate choice nbreg

Negative binomial (NB2) regression for overdispersed counts, estimating `(β, log α)` jointly.

```bash
cat > claims.csv <<'EOF'
claims,visits,const,x1,policy_years
3,1,1.0,-0.3597,2.2504
7,5,1.0,1.2037,2.7776
8,0,1.0,1.3969,2.5959
7,1,1.0,0.3172,2.1886
3,0,1.0,0.4141,1.5502
3,2,1.0,-0.4895,1.2050
4,0,1.0,-0.9141,1.7796
1,2,1.0,-0.9004,2.4234
3,0,1.0,-0.9984,2.9556
11,5,1.0,0.9292,2.2900
6,0,1.0,-0.0563,2.8386
9,0,1.0,0.1283,3.0804
3,3,1.0,-0.6400,3.6900
2,0,1.0,-1.0878,2.6435
1,1,1.0,-1.2020,3.2472
3,2,1.0,-0.8416,2.6172
4,1,1.0,0.5992,1.8807
0,1,1.0,0.0184,1.3647
4,4,1.0,-0.4568,2.6486
7,2,1.0,-0.2393,2.9442
7,0,1.0,-1.4273,3.7348
4,4,1.0,1.2307,2.1659
5,1,1.0,-1.2164,2.7451
4,4,1.0,0.0424,2.4421
4,0,1.0,2.1370,1.3158
2,2,1.0,-2.5512,2.6874
4,2,1.0,-1.4070,2.3391
1,2,1.0,-0.7237,1.8618
4,0,1.0,0.1166,3.3439
3,0,1.0,-1.7149,2.1915
4,0,1.0,-0.2353,2.7344
2,2,1.0,-0.0284,2.3673
2,1,1.0,0.1705,2.1417
0,0,1.0,-2.3884,2.4161
5,2,1.0,0.6464,2.8965
5,0,1.0,1.5969,2.1550
4,0,1.0,0.4366,1.6743
2,2,1.0,-0.7231,3.3982
2,2,1.0,-0.6134,2.7197
1,0,1.0,-2.6463,2.0205
2,2,1.0,0.4760,2.4542
3,2,1.0,1.5031,1.7176
5,5,1.0,0.6502,2.4674
1,1,1.0,-2.9773,2.9303
6,3,1.0,-0.4260,1.5341
4,2,1.0,-0.1029,2.9335
3,5,1.0,-0.4835,2.9038
5,2,1.0,1.0332,2.3641
2,0,1.0,-1.7443,2.5512
2,0,1.0,-0.7178,2.3333
7,3,1.0,0.5956,2.2770
2,1,1.0,0.9909,1.5691
5,1,1.0,0.1691,3.3152
4,4,1.0,1.0553,2.1643
9,8,1.0,0.5202,2.5674
6,3,1.0,-1.0593,2.3861
7,4,1.0,1.2935,2.7277
2,2,1.0,-0.5057,2.7836
1,0,1.0,-1.6306,1.9894
9,1,1.0,0.4380,2.6811
9,5,1.0,1.8143,2.3650
9,2,1.0,0.9592,2.0582
12,2,1.0,0.9973,3.1485
6,3,1.0,0.1906,3.0893
0,1,1.0,-2.4650,2.0478
4,2,1.0,0.6800,2.3489
4,3,1.0,0.1575,1.9946
0,0,1.0,-2.6411,1.9313
1,1,1.0,-0.6519,2.0088
4,3,1.0,-0.8797,2.7773
2,3,1.0,1.0611,1.7917
1,0,1.0,0.1234,1.7687
4,3,1.0,0.2982,2.6438
4,4,1.0,0.2427,2.1402
2,0,1.0,-1.3281,3.1146
1,0,1.0,-1.9638,2.0196
3,1,1.0,0.0572,2.2569
1,0,1.0,-0.2934,2.1122
2,0,1.0,-0.0143,1.3426
0,1,1.0,-0.1664,2.6739
EOF
friedman estimate choice nbreg claims.csv --dep=claims --exposure=policy_years
```

Options are the same as [`estimate choice poisson`](#estimate-poisson) **except `--cov-type` and
`--clusters`, which are not offered**: the library's NB2 estimator takes neither, reporting the
joint information-matrix covariance instead. `--maxiter` defaults to 1000.

**Output:** Tidy coefficient table, a separate **overdispersion table** carrying `α` and its
delta-method standard error (the coefficient covariance block stops at `β`, so `α` cannot ride
the same table), an optional IRR table, and fit statistics. Each table takes a distinct
`--output` path suffix so nothing is overwritten.

---

## estimate choice logit

Logit (logistic regression) for binary choice models.

```bash
cat > choice.csv <<'EOF'
y,x1,x2,state
0,0.3588,-0.0666,1
1,1.5107,-0.8145,1
0,-1.7863,-0.8795,1
1,1.6866,0.3777,1
0,-0.0473,1.3378,1
0,-0.8000,0.7130,1
0,-0.8030,0.6851,1
0,-1.0828,1.2457,1
0,-0.2236,-1.9910,1
0,0.8339,-1.5103,1
1,0.5841,-0.7054,1
1,0.6383,-1.1951,1
0,-1.6948,-0.9894,1
0,-1.5710,0.0699,1
0,1.5538,-1.2844,1
1,0.9689,-0.4435,1
1,2.1832,-2.0432,1
0,1.2098,-0.9740,1
0,-1.0244,1.3455,1
1,1.2853,-0.5429,1
1,0.6284,0.3241,2
0,0.2148,0.7082,2
0,-0.8199,-0.4909,2
1,0.0028,0.5791,2
1,-0.1470,0.2145,2
0,0.8925,0.6974,2
1,0.1245,-0.6356,2
1,1.5847,-1.4402,2
1,-0.7745,-1.0221,2
0,0.4711,-0.5548,2
1,0.4988,0.5358,2
1,-0.8643,-0.2043,2
0,-1.1813,-0.3988,2
1,1.0136,-0.1797,2
0,0.5174,1.0998,2
1,-0.1625,-0.5755,2
0,0.3944,1.5113,2
0,-0.6753,-1.2276,2
0,0.2383,-0.5922,2
0,-0.6051,0.8550,2
1,0.1888,0.5178,3
1,0.9861,-0.8555,3
1,-0.3396,-0.1090,3
1,0.8498,-0.7089,3
0,-1.0342,0.8510,3
0,-0.2885,0.5397,3
1,-1.3647,-0.7131,3
1,-0.1006,0.3972,3
0,0.0787,-0.3671,3
0,-0.1973,-0.0719,3
1,-0.2677,0.0646,3
0,1.3402,-0.5640,3
1,1.4238,0.4250,3
0,-1.2156,0.4603,3
1,1.1741,0.4259,3
0,-1.7231,1.1046,3
0,-0.7345,-0.2717,3
0,-0.1734,-1.4829,3
0,0.1111,-0.4891,3
0,-1.0474,0.2007,3
0,-0.7225,0.0220,4
0,0.0767,0.5787,4
1,-0.6934,0.8064,4
1,-0.6412,-0.1176,4
1,0.6663,-0.1104,4
1,0.9317,-0.9874,4
0,-0.0601,1.0331,4
1,0.0182,-0.2639,4
0,-0.0196,-1.0833,4
1,-0.4545,-1.1144,4
0,-0.5114,-0.4148,4
1,-1.0377,1.5554,4
0,0.6484,0.7725,4
1,-0.0842,-1.6940,4
1,-0.1374,-0.1236,4
1,0.2005,0.2640,4
0,0.5307,0.6266,4
0,1.4210,0.3437,4
0,-0.2735,-0.6407,4
1,-0.4012,0.4119,4
1,0.2006,-0.5542,5
1,-0.8455,-2.2406,5
1,1.2724,-0.7089,5
0,0.9262,-0.6860,5
0,0.6939,0.9536,5
0,-0.1196,1.0560,5
1,0.7396,-1.0453,5
1,1.0502,0.1739,5
1,0.4999,0.0901,5
1,-0.2800,-1.4358,5
0,-1.6851,-2.0531,5
1,0.9470,-0.0928,5
0,-0.3533,0.1364,5
1,-0.8432,-0.5948,5
1,0.8906,-2.7112,5
1,0.3382,-0.0295,5
0,-1.4188,-0.5786,5
1,-0.0990,-0.8894,5
1,-0.2692,-0.3242,5
1,0.9926,-1.1286,5
0,-1.8951,0.5598,6
1,-0.3856,0.0106,6
1,-0.1382,-0.5595,6
1,1.4189,0.2819,6
1,-1.0834,-0.0321,6
0,-2.9404,-1.5182,6
0,-1.3840,-0.1441,6
1,0.2631,-0.4572,6
1,0.8096,-1.7407,6
1,1.7335,-0.6520,6
1,0.4009,0.4263,6
0,-0.8023,-0.6195,6
0,0.8844,1.4075,6
1,-0.0111,1.6982,6
1,-0.2010,-0.3063,6
0,0.0176,0.5534,6
1,1.2746,1.9927,6
1,-0.9014,-0.3315,6
1,-1.0239,-0.8990,6
0,-0.0665,-0.4223,6
EOF
friedman estimate choice logit choice.csv --dep=y --cov-type=hc1
friedman estimate choice logit choice.csv --dep=y --clusters=state --maxiter=200
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--tol` | | Float64 | 1e-8 | Convergence tolerance |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC, convergence).

---

## estimate choice probit

Probit regression for binary choice models.

```bash
cat > choice.csv <<'EOF'
y,x1,x2,state
0,0.3588,-0.0666,1
1,1.5107,-0.8145,1
0,-1.7863,-0.8795,1
1,1.6866,0.3777,1
0,-0.0473,1.3378,1
0,-0.8000,0.7130,1
0,-0.8030,0.6851,1
0,-1.0828,1.2457,1
0,-0.2236,-1.9910,1
0,0.8339,-1.5103,1
1,0.5841,-0.7054,1
1,0.6383,-1.1951,1
0,-1.6948,-0.9894,1
0,-1.5710,0.0699,1
0,1.5538,-1.2844,1
1,0.9689,-0.4435,1
1,2.1832,-2.0432,1
0,1.2098,-0.9740,1
0,-1.0244,1.3455,1
1,1.2853,-0.5429,1
1,0.6284,0.3241,2
0,0.2148,0.7082,2
0,-0.8199,-0.4909,2
1,0.0028,0.5791,2
1,-0.1470,0.2145,2
0,0.8925,0.6974,2
1,0.1245,-0.6356,2
1,1.5847,-1.4402,2
1,-0.7745,-1.0221,2
0,0.4711,-0.5548,2
1,0.4988,0.5358,2
1,-0.8643,-0.2043,2
0,-1.1813,-0.3988,2
1,1.0136,-0.1797,2
0,0.5174,1.0998,2
1,-0.1625,-0.5755,2
0,0.3944,1.5113,2
0,-0.6753,-1.2276,2
0,0.2383,-0.5922,2
0,-0.6051,0.8550,2
1,0.1888,0.5178,3
1,0.9861,-0.8555,3
1,-0.3396,-0.1090,3
1,0.8498,-0.7089,3
0,-1.0342,0.8510,3
0,-0.2885,0.5397,3
1,-1.3647,-0.7131,3
1,-0.1006,0.3972,3
0,0.0787,-0.3671,3
0,-0.1973,-0.0719,3
1,-0.2677,0.0646,3
0,1.3402,-0.5640,3
1,1.4238,0.4250,3
0,-1.2156,0.4603,3
1,1.1741,0.4259,3
0,-1.7231,1.1046,3
0,-0.7345,-0.2717,3
0,-0.1734,-1.4829,3
0,0.1111,-0.4891,3
0,-1.0474,0.2007,3
0,-0.7225,0.0220,4
0,0.0767,0.5787,4
1,-0.6934,0.8064,4
1,-0.6412,-0.1176,4
1,0.6663,-0.1104,4
1,0.9317,-0.9874,4
0,-0.0601,1.0331,4
1,0.0182,-0.2639,4
0,-0.0196,-1.0833,4
1,-0.4545,-1.1144,4
0,-0.5114,-0.4148,4
1,-1.0377,1.5554,4
0,0.6484,0.7725,4
1,-0.0842,-1.6940,4
1,-0.1374,-0.1236,4
1,0.2005,0.2640,4
0,0.5307,0.6266,4
0,1.4210,0.3437,4
0,-0.2735,-0.6407,4
1,-0.4012,0.4119,4
1,0.2006,-0.5542,5
1,-0.8455,-2.2406,5
1,1.2724,-0.7089,5
0,0.9262,-0.6860,5
0,0.6939,0.9536,5
0,-0.1196,1.0560,5
1,0.7396,-1.0453,5
1,1.0502,0.1739,5
1,0.4999,0.0901,5
1,-0.2800,-1.4358,5
0,-1.6851,-2.0531,5
1,0.9470,-0.0928,5
0,-0.3533,0.1364,5
1,-0.8432,-0.5948,5
1,0.8906,-2.7112,5
1,0.3382,-0.0295,5
0,-1.4188,-0.5786,5
1,-0.0990,-0.8894,5
1,-0.2692,-0.3242,5
1,0.9926,-1.1286,5
0,-1.8951,0.5598,6
1,-0.3856,0.0106,6
1,-0.1382,-0.5595,6
1,1.4189,0.2819,6
1,-1.0834,-0.0321,6
0,-2.9404,-1.5182,6
0,-1.3840,-0.1441,6
1,0.2631,-0.4572,6
1,0.8096,-1.7407,6
1,1.7335,-0.6520,6
1,0.4009,0.4263,6
0,-0.8023,-0.6195,6
0,0.8844,1.4075,6
1,-0.0111,1.6982,6
1,-0.2010,-0.3063,6
0,0.0176,0.5534,6
1,1.2746,1.9927,6
1,-0.9014,-0.3315,6
1,-1.0239,-0.8990,6
0,-0.0665,-0.4223,6
EOF
friedman estimate choice probit choice.csv --dep=y --cov-type=hc1
friedman estimate choice probit choice.csv --dep=y --clusters=state
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--tol` | | Float64 | 1e-8 | Convergence tolerance |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC, convergence).

---

## Panel Regression Models

### estimate panel preg

Panel regression with fixed effects (FE), random effects (RE), between effects (BE), or pooled OLS. Supports two-way fixed effects.

```bash
friedman data simulate panel --kind linear --seed 7 --format csv --output panel.csv
friedman estimate panel preg panel.csv --dep=y --indep=x1,x2 --method=fe
friedman estimate panel preg panel.csv --dep=y --indep=x1,x2 --method=re --twoway
friedman estimate panel preg panel.csv --id-col=id --time-col=time --dep=y --method=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--indep` | | String | | Comma-separated independent variable names |
| `--method` | | String | `fe` | `fe`, `re`, `be`, `pooled` |
| `--twoway` | | Flag | | Include time fixed effects (two-way FE/RE) |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--cov-type` | | String | `cluster` | `ols`, `hc1`, `cluster` |
| `--clusters` | | String | | Cluster variable column name |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) with SE, t-stat, p-value; within/between/overall R²; F-statistic.

### estimate panel piv

Panel IV (2SLS) regression with panel-robust standard errors.

```bash
cat > panel_iv.csv <<'EOF'
id,time,y,x_endog,x_exog,z1,z2
1,1,2.9297,1.2741,2.1555,-0.6422,-0.2084
1,2,-0.5955,-1.0514,0.8918,-0.7653,-1.0841
1,3,6.2436,2.7143,1.5938,2.0207,-0.5438
1,4,1.4930,0.7961,-0.4503,0.1692,0.5609
1,5,-1.3259,-0.6853,-0.8742,-0.8979,0.3740
1,6,-1.8111,-0.9567,-1.7198,-0.9540,0.4255
1,7,-0.4827,-0.3184,-1.1537,1.8378,-0.7249
1,8,0.7742,0.3571,-0.3634,-0.5784,1.2791
1,9,5.8258,3.0313,0.1930,1.1887,1.5021
1,10,4.2739,1.5471,-1.3131,1.4233,1.8341
1,11,-0.6909,-1.6368,0.8161,-2.3244,1.0005
1,12,8.5523,3.9860,-0.1030,1.3510,1.8943
2,1,1.7311,0.4901,1.4675,-1.2959,1.5629
2,2,2.5197,0.4897,-0.0703,1.1769,-0.0720
2,3,-0.8085,0.0709,-2.1774,0.6888,0.6929
2,4,4.8969,2.5957,0.6497,-0.5544,2.4785
2,5,0.0586,-0.5151,-0.6994,-0.0023,0.0285
2,6,1.0190,-0.9038,0.6869,-0.4465,-0.1392
2,7,2.3303,0.1339,-0.1019,0.0594,0.0044
2,8,3.8149,2.1789,1.1343,0.9403,0.5866
2,9,-0.5223,-1.8817,0.2334,-0.6793,-0.6182
2,10,2.5052,0.7120,0.2795,0.7432,-0.2451
2,11,0.3554,-1.2758,0.1499,0.9407,-1.7548
2,12,2.4981,-0.1131,1.2306,0.6373,-1.0495
3,1,2.7804,0.7086,0.7919,1.1402,-0.6970
3,2,2.1028,0.6205,1.0629,1.7667,-0.9639
3,3,-2.4830,-2.1360,-0.0818,0.1717,-1.5014
3,4,3.1203,1.0239,0.0575,-0.0756,0.9053
3,5,0.1978,-0.6908,-0.1629,0.2037,-0.3470
3,6,-0.1953,-0.8746,-1.7614,-0.3998,0.0708
3,7,2.7203,1.1940,0.2435,-0.8517,1.7912
3,8,-1.0110,-0.6202,-1.2433,0.6463,-0.4822
3,9,1.3524,0.7832,-0.9568,0.7209,0.5776
3,10,-0.3499,-1.2749,0.3969,-0.4975,-1.3446
3,11,-0.1644,-0.5499,0.9249,-0.4012,-0.6232
3,12,-1.0493,-0.8352,-0.8669,-0.6189,0.6921
4,1,-0.1078,-1.2366,0.6320,-0.0899,-1.1630
4,2,-0.4575,-0.9844,-0.8531,0.2752,-0.4071
4,3,-0.8892,-0.3037,-0.6371,0.4037,-0.9443
4,4,0.5039,0.5991,-0.4528,-0.4637,0.9351
4,5,-1.6014,-1.0467,-1.0643,-0.3820,0.0113
4,6,3.6205,0.8101,1.1201,-0.3848,-0.0298
4,7,-0.8563,-0.6736,0.4013,0.8296,-0.9870
4,8,-1.3730,-0.1868,0.5150,-0.7111,0.5050
4,9,-1.4452,-1.8150,-1.0046,-0.1568,-0.3537
4,10,2.4692,0.2711,0.4537,0.3197,-0.9324
4,11,-2.1235,-1.2773,-0.5253,-0.3997,-0.6286
4,12,7.6707,3.4114,2.3703,-1.3319,2.3086
5,1,1.1316,-0.8180,-0.7638,-0.7922,0.7643
5,2,4.4264,1.7201,-0.4035,0.3602,1.8057
5,3,-0.0671,-0.0170,-0.6623,0.1286,-0.0020
5,4,-2.6799,-1.3074,-1.8962,0.1546,-0.2337
5,5,-3.9089,-0.6583,-1.6405,-0.4530,-0.0642
5,6,4.3930,1.3232,-0.1529,0.3191,1.3152
5,7,6.4965,2.7127,0.2862,0.3259,1.4734
5,8,0.2117,-0.8969,-0.9818,-0.2157,0.1308
5,9,3.4761,2.3513,0.0482,1.0593,0.6041
5,10,6.2867,1.1055,1.7236,-1.5893,1.7360
5,11,2.7568,1.6859,-0.3145,0.6319,0.5063
5,12,0.1821,-0.9709,-0.5373,-0.1846,-1.4888
6,1,5.4617,1.5668,1.0257,0.8274,0.1497
6,2,-2.5383,-1.3014,-0.4639,-1.1268,-0.1543
6,3,4.9469,1.7517,-0.3071,0.4155,1.9449
6,4,5.9989,2.4791,-0.3152,1.4346,1.3077
6,5,0.8585,0.1399,-0.9187,0.9047,-0.4028
6,6,2.2126,0.2235,-0.2540,1.2234,-1.0440
6,7,1.8784,-0.0996,-0.9905,1.5148,-0.8381
6,8,-2.3046,-1.9593,-0.5453,-1.4979,-0.0462
6,9,2.1081,0.3182,0.6859,0.5716,-0.7153
6,10,4.8336,3.3263,-0.3138,0.5504,1.9712
6,11,-1.2113,-1.4187,1.0710,-0.1889,-1.1790
6,12,0.4940,-0.6669,0.7076,-1.2985,-0.0815
7,1,-1.1747,-0.9348,0.1925,-1.0856,0.2689
7,2,-2.8834,-3.5194,0.5062,-1.5542,-1.9477
7,3,1.9512,0.1857,-0.2522,-0.4309,0.9802
7,4,-1.7764,-0.1255,-0.8275,-1.1560,1.0638
7,5,1.2313,0.3833,-0.3799,-0.9804,0.7748
7,6,-0.7536,-0.9316,0.0330,-1.0794,0.4757
7,7,2.1737,1.0431,-1.5454,2.2446,0.0825
7,8,1.8589,1.0625,-1.3524,-0.0835,1.1975
7,9,-3.4437,-1.9195,-1.6426,-0.6444,-0.2927
7,10,1.2946,0.5510,-0.3804,-0.4444,1.0440
7,11,2.9005,0.8131,0.6666,0.8659,-0.4656
7,12,1.0314,0.4175,-1.2730,0.9690,-0.3697
8,1,1.6142,0.0364,0.6133,0.5848,-0.6885
8,2,2.6635,0.9181,-0.1440,1.1898,0.1285
8,3,-1.3222,-1.6033,-0.5849,0.4958,-1.8084
8,4,1.6793,0.6698,0.2357,1.5685,-0.5259
8,5,2.1335,-0.8763,0.4260,-0.6732,-0.2663
8,6,-0.3416,-1.4819,0.9118,0.3438,-2.2987
8,7,3.3658,0.7711,1.3301,-0.2298,1.5934
8,8,3.3687,0.6859,0.8055,-0.2026,0.4474
8,9,-1.0248,-2.1345,-0.5664,-1.7369,-0.7880
8,10,1.3034,1.1203,-0.0469,-0.7272,1.8305
8,11,-1.9139,-0.8011,-1.3824,-1.9609,1.3019
8,12,-1.0226,-1.6795,0.7191,-0.3236,-2.4818
9,1,-1.0970,-1.0900,0.9190,-1.8509,0.8342
9,2,2.6547,0.4510,-1.3564,0.7121,0.8527
9,3,-1.6594,-0.0897,-1.7363,0.2190,0.1521
9,4,1.0319,-0.5703,0.5121,0.1434,-1.2733
9,5,0.4122,-1.1426,-0.9915,0.3985,-1.0046
9,6,-2.8844,-1.8455,-0.3730,0.0504,-1.0756
9,7,-2.0187,-1.0598,-0.0353,-1.4513,1.0406
9,8,0.7555,0.9333,-1.3182,0.7329,0.4406
9,9,-2.0280,-0.5552,-1.5954,0.0423,0.0137
9,10,2.9889,1.0201,0.1913,0.3766,-0.1927
9,11,-4.3713,-2.6047,-2.7773,-0.2133,-0.7737
9,12,1.3791,0.6661,0.5346,-0.3398,0.7727
10,1,1.6868,0.6493,-0.6520,-0.7314,2.0533
10,2,4.6755,2.2895,0.3089,-1.1803,3.4077
10,3,-5.5711,-2.9255,-1.6537,-0.3608,-0.5355
10,4,1.7159,0.0346,1.5126,0.1869,-0.9525
10,5,6.3989,2.0381,1.2410,2.2727,-1.2813
10,6,2.0909,-0.1374,0.7811,-0.1182,-0.4325
10,7,1.2254,0.5785,-0.7499,0.8838,-0.0228
10,8,0.3354,0.0659,0.0092,0.0883,-0.0085
10,9,3.2728,0.7003,0.5329,-0.0580,1.1070
10,10,4.2167,1.8596,0.9368,1.7243,-0.3398
10,11,-0.9602,-0.5109,1.2570,-1.1355,0.2941
10,12,-3.7181,-2.0914,-2.1787,0.6533,-1.6858
11,1,0.5312,-0.4025,-0.6992,-0.1113,-0.2390
11,2,1.8413,-0.1163,2.1479,-0.0952,-0.8603
11,3,-1.8482,-1.2292,-1.2141,1.1595,-2.6376
11,4,-1.7400,-1.6260,-0.4130,-0.7919,-1.0411
11,5,-0.8202,-1.2807,-1.3409,-0.1568,-1.0128
11,6,-0.3436,-0.0223,-0.3098,-0.9985,0.8772
11,7,-0.0697,-0.0401,0.1653,-0.5944,0.6129
11,8,3.7659,0.9868,1.1372,1.4208,-1.3920
11,9,0.3365,-0.6004,0.1424,-0.7851,0.5343
11,10,-0.7011,0.0642,-0.0765,0.4374,-0.7316
11,11,7.2768,4.0262,0.2854,2.0466,1.7463
11,12,1.4078,1.2653,0.4917,0.4505,1.4009
12,1,2.4784,1.0379,0.3194,0.4498,1.0375
12,2,3.2838,0.5211,0.7801,-0.3023,0.1826
12,3,7.3664,2.0050,2.4159,0.8827,-0.1994
12,4,0.1584,0.5650,-0.2829,0.1038,1.3493
12,5,2.1429,0.2179,0.0091,1.0530,-0.7410
12,6,-0.4495,-0.3951,-1.1150,-0.2390,1.0092
12,7,6.1487,3.0742,1.6986,0.6561,1.5254
12,8,-3.7737,-2.8278,-0.4063,-0.4644,-1.7096
12,9,5.1215,2.6208,0.7285,1.2919,0.9169
12,10,-0.8033,-0.7362,-1.1835,0.0174,0.5612
12,11,1.4596,-0.1397,-0.2920,0.0760,0.2099
12,12,2.3618,-0.1221,0.5699,-0.5532,0.3633
13,1,-0.8829,-0.7268,-0.8119,-1.0908,1.0860
13,2,1.8858,0.1772,-0.7153,0.0949,0.5063
13,3,3.3496,1.1878,-1.3980,1.4420,-0.0640
13,4,0.4738,-0.8935,-0.6722,-2.0480,1.3618
13,5,1.0388,-0.1691,-0.3130,0.8874,-1.6764
13,6,-4.0922,-2.6065,0.2952,-2.0359,-0.1758
13,7,-0.1159,-1.0205,-1.0109,1.3614,-1.2334
13,8,0.6433,0.2925,-1.7452,0.7098,-0.1060
13,9,1.7196,-0.4666,0.2923,-0.3993,0.4715
13,10,0.4243,0.0216,1.7928,0.1880,-1.6353
13,11,4.0696,1.7550,0.0384,1.5480,0.2205
13,12,-0.3466,-0.6012,0.0075,-1.1365,0.2261
14,1,-0.1980,-0.8284,-0.6556,0.3978,-0.7422
14,2,1.8370,-0.2991,-0.4491,-0.2484,0.2296
14,3,-1.0750,-0.3880,-2.4380,0.8616,0.0548
14,4,-2.3759,-1.0620,-0.8632,-0.2919,-0.4044
14,5,2.6770,1.7509,-1.1025,-0.1781,2.4858
14,6,-1.4603,-0.7462,-0.6332,0.2991,-0.6767
14,7,-0.9613,-1.4198,0.5065,-0.4744,-0.7675
14,8,-0.3181,-0.7360,-0.2912,-1.0651,0.1828
14,9,1.5447,0.3558,-0.1606,-1.1986,1.5560
14,10,0.9194,-0.3663,0.0810,-0.2888,-0.2958
14,11,6.2922,2.6994,0.9699,0.2187,1.3608
14,12,2.9183,0.5522,1.0412,0.6371,-0.9172
15,1,-3.1128,-2.0812,-0.8988,-1.3497,-0.6222
15,2,0.8909,-0.0900,1.7000,-0.9081,-0.4289
15,3,6.4845,2.6043,1.2125,0.5421,0.7880
15,4,1.0831,0.7384,-0.0153,-0.2453,1.0786
15,5,2.3471,1.1423,1.1914,1.6982,-0.8162
15,6,2.3777,1.4222,0.3853,1.3940,-0.2552
15,7,1.0969,0.8955,0.7377,-0.0947,0.6003
15,8,1.7328,0.3574,-0.6867,0.3054,0.3065
15,9,-0.3669,-1.9211,-0.3129,-1.6085,-0.1767
15,10,4.5963,2.0016,-0.0725,0.7704,0.5875
15,11,2.8520,0.6316,0.0506,1.1471,-0.7418
15,12,-1.4325,-1.3680,-0.3156,-0.6110,-1.2843
EOF
friedman estimate panel piv panel_iv.csv --id-col=id --time-col=time --dep=y --exog=x_exog --endog=x_endog --instruments=z1
friedman estimate panel piv panel_iv.csv --id-col=id --time-col=time --dep=y --endog=x_endog,x_exog --instruments=z1,z2 --method=fe
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name |
| `--exog` | | String | | Comma-separated exogenous regressor names |
| `--endog` | | String | (required) | Comma-separated endogenous regressor names |
| `--instruments` | | String | (required) | Comma-separated instrument column names |
| `--method` | | String | `fe` | `fe`, `re`, `pooled` |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + IV diagnostics (first-stage F-statistic, Sargan test).

### estimate panel plogit

Panel logit regression (pooled MLE or random effects).

```bash
friedman data simulate panel --kind logit --seed 7 --format csv --output panel_bin.csv
friedman estimate panel plogit panel_bin.csv --id-col=id --time-col=time --dep=y --method=re
friedman estimate panel plogit panel_bin.csv --id-col=id --time-col=time --dep=y --method=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--method` | | String | `pooled` | `pooled`, `re` |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC).

### estimate panel pprobit

Panel probit regression (pooled MLE or random effects).

```bash
friedman data simulate panel --kind probit --seed 7 --format csv --output panel_bin.csv
friedman estimate panel pprobit panel_bin.csv --id-col=id --time-col=time --dep=y --method=pooled
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (binary 0/1) |
| `--method` | | String | `pooled` | `pooled`, `re` |
| `--id-col` | | String | (auto) | Panel group identifier column |
| `--time-col` | | String | (auto) | Panel time identifier column |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table ([C051](#coefficient-table-format-c051)) + fit statistics (pseudo R², log-likelihood, AIC, BIC).

---

## Ordered & Multinomial Choice Models

### estimate choice ologit

Ordered logit regression for ordered categorical outcomes.

```bash
friedman data simulate cross-section --kind ordered --seed 7 --format csv --output ord.csv
friedman estimate choice ologit ord.csv --dep=y
friedman estimate choice ologit ord.csv --dep=y --cov-type=hc1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (ordered integer) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--maxiter` | | Int | 100 | Maximum IRLS iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`block|term|...`, [C051](#coefficient-table-format-c051)) — `block` distinguishes coefficients from cutpoints — plus threshold parameters, pseudo R², log-likelihood, AIC, BIC.

### estimate choice oprobit

Ordered probit regression for ordered categorical outcomes.

```bash
friedman data simulate cross-section --kind ordered --seed 7 --format csv --output ord.csv
friedman estimate choice oprobit ord.csv --dep=y
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (ordered integer) |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** Tidy coefficient table (`block|term|...`, [C051](#coefficient-table-format-c051)) — `block` distinguishes coefficients from cutpoints — plus threshold parameters, pseudo R², log-likelihood, AIC, BIC.

### estimate choice mlogit

Multinomial logit regression for unordered categorical outcomes.

```bash
friedman data simulate cross-section --kind mlogit --seed 7 --format csv --output mlog.csv
friedman estimate choice mlogit mlog.csv --dep=y
friedman estimate choice mlogit mlog.csv --dep=y --base-category=1
```

| Option | Short | Type | Default | Description |
|--------|-------|------|---------|-------------|
| `--dep` | | String | (1st col) | Dependent variable column name (categorical integer) |
| `--base-category` | | Int | 1 | Reference category |
| `--cov-type` | | String | `hc1` | `ols`, `hc0`, `hc1`, `hc2`, `hc3` |
| `--maxiter` | | Int | 100 | Maximum iterations |
| `--format` | `-f` | String | `table` | `table`, `csv`, `json` |
| `--output` | `-o` | String | | Export file path |

**Output:** One tidy coefficient table keyed by `alternative` ([C051](#coefficient-table-format-c051)) — every category's coefficients (relative to the base) in a single table — plus pseudo R², log-likelihood, AIC, BIC.

---

## References

- Option defaults, choices, and table keys: [generated estimate reference](generated/estimate.md).
- Impulse responses, decompositions, and forecasts built on these fits: [irf](irf.md), [fevd](fevd.md), [forecast](forecast.md).
- Weak-instrument and symmetry batteries: [test](test.md).
- Prior TOML format: [Configuration](../configuration.md).
