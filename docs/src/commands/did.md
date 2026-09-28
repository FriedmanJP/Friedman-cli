# did

Staggered-adoption difference-in-differences: `did estimate`, `did event-study`, `did lp-did`. Diagnostics live under `test did` (see Diagnostics below). Full option tables live in the [generated `did` reference](generated/did.md) and the [generated `test` reference](generated/test.md).

Every leaf reads a panel CSV as its positional `data` argument. `--id-col` and `--time-col` name the unit and time columns and default to the first and second columns. Start from a simulated staggered panel — every example below simulates it in-block with `data simulate did` (columns `id,time,y,D,cohort`; outcome `y`, treatment indicator `D`):

<!-- capture -->
```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv
```
```
id,time,y,D,cohort
1,1,-0.7939668122816973,0,0
1,2,-1.3400390898658225,0,0
1,3,2.7410600689998788,0,0
1,4,2.279284300948186,0,0
1,5,0.868159423021899,0,0
1,6,0.4234788787419166,0,0
1,7,-0.721092744644673,0,0
1,8,0.5770139988549423,0,0
1,9,0.6955160457107472,0,0
1,10,-1.6708968515199862,0,0
1,11,1.6600536280302147,0,0
1,12,0.40750638989871246,0,0
2,1,-0.06839864231932236,0,11
2,2,-2.6250212565552626,0,11
2,3,3.2297820516180566,0,11
2,4,3.6548448502710347,0,11
2,5,-0.052263182283847354,0,11
2,6,-0.05440292542539272,0,11
2,7,-2.027057345460417,0,11
2,8,-1.3293621038486332,0,11
2,9,-0.025334104798541812,0,11
2,10,-0.5978302566241555,0,11
2,11,2.071843787162667,1,11
2,12,-0.3878782537950677,1,11
3,1,-2.3127087663272095,0,11
3,2,1.1234952266639882,0,11
3,3,1.9739921832443807,0,11
3,4,-0.02795365918449544,0,11
3,5,-0.5629685849456588,0,11
3,6,0.48728371618826527,0,11
3,7,-3.184378517326416,0,11
3,8,-0.39442791959577184,0,11
3,9,0.6577360253209013,0,11
3,10,-0.24548924201962596,0,11
3,11,0.9073731984784913,1,11
3,12,-0.2040102637685005,1,11
4,1,-1.795910377771723,0,0
4,2,-2.6571719275533736,0,0
4,3,0.49366544216420216,0,0
4,4,-0.33673943013233565,0,0
4,5,-0.8034405238936536,0,0
4,6,0.5732542804044012,0,0
4,7,-0.5412915187254674,0,0
4,8,-1.0716275159730841,0,0
4,9,0.2866213030909185,0,0
4,10,0.26432018835438614,0,0
4,11,1.452548297480813,0,0
4,12,-3.016031590877323,0,0
5,1,-2.79704728560902,0,11
5,2,-1.3737331653686313,0,11
5,3,2.2429897628637914,0,11
5,4,-0.09357750888055905,0,11
5,5,-0.17130912218662014,0,11
5,6,1.0090918030149951,0,11
5,7,-1.1881425188953583,0,11
5,8,-0.9915359264302976,0,11
5,9,-0.17371728078955012,0,11
5,10,1.6452879158134668,0,11
5,11,0.03550873894763207,1,11
5,12,0.8359965103439606,1,11
6,1,-0.7499812004283889,0,6
6,2,1.5181746156039504,0,6
6,3,2.0983545306958065,0,6
6,4,-0.0010187283412965709,0,6
6,5,1.689541338957231,0,6
6,6,1.5510272929161282,1,6
6,7,1.423361287765148,1,6
6,8,0.4299210752748033,1,6
6,9,3.8017052417362542,1,6
6,10,1.7314522744427778,1,6
6,11,2.9186862740585218,1,6
6,12,1.228735230500502,1,6
7,1,-2.5103263432565446,0,11
7,2,-2.8249906633857895,0,11
7,3,1.3499428199375767,0,11
7,4,-0.8784879192907535,0,11
7,5,0.13745441628039068,0,11
7,6,-0.6554261704616315,0,11
7,7,0.23438483122567,0,11
7,8,-1.565905536918008,0,11
7,9,-0.23237018883440985,0,11
7,10,-1.0838845898927176,0,11
7,11,2.2975764684725424,1,11
7,12,-0.5751606500433615,1,11
8,1,-2.7930510468449157,0,11
8,2,-2.467230858845524,0,11
8,3,-0.17536875071469804,0,11
8,4,-0.28360401847263805,0,11
8,5,0.027302312644310378,0,11
8,6,-2.6979563379723843,0,11
8,7,-3.0947759682385265,0,11
8,8,-3.926370925770402,0,11
8,9,-2.188587353899152,0,11
8,10,-0.21471304822219373,0,11
8,11,-2.300952206318954,1,11
8,12,-1.7902508708328067,1,11
9,1,0.13049640738299723,0,11
9,2,-0.13171838433491673,0,11
9,3,3.0274514250496005,0,11
9,4,0.826549440776859,0,11
9,5,1.4214187550641821,0,11
9,6,1.5727718322311852,0,11
9,7,-0.026519112283797972,0,11
9,8,-0.3547870424160584,0,11
9,9,1.8791122163847491,0,11
9,10,1.604517316513473,0,11
9,11,4.919749363637408,1,11
9,12,1.393434503535053,1,11
10,1,-1.365661749284385,0,11
10,2,0.09312632224221654,0,11
10,3,1.8698054741450503,0,11
10,4,0.45362702204935457,0,11
10,5,1.0894232365465633,0,11
10,6,2.2852009353291907,0,11
10,7,-2.3209502391251666,0,11
10,8,0.1299181743973909,0,11
10,9,2.902540806546506,0,11
10,10,1.1476676765560723,0,11
10,11,3.8566071169835907,1,11
10,12,1.908430566201718,1,11
parameter,row,col,value
overall_att,0,0,1.3000000000000003
att_e:0,0,0,1.21875
att_e:1,0,0,1.3187499999999999
att_e:2,0,0,1.2
att_e:3,0,0,1.3
att_e:4,0,0,1.4
att_e:5,0,0,1.5
att_e:6,0,0,1.6
att_c:11,0,0,1.3000000000000003
att_c:6,0,0,1.3
metric,value
model,did
seed,7
n,10
periods,12
```
The simulator records the realized ATT as population truth, so estimates below can be read against a known value.

---

## did estimate

Estimate the **average treatment effect on the treated (ATT)** by event time. The default is two-way fixed effects (`--method twfe`); the heterogeneity-robust alternatives are `--method cs` (Callaway–Sant'Anna), `sa` (Sun–Abraham), `bjs` (Borusyak–Jaravel–Spiess imputation), and `dcdh` (de Chaisemartin–D'Haultfoeuille). The shorts map to the upstream estimator names (`callaway_santanna`, `sun_abraham`, `did_multiplegt`); the Callaway–Sant'Anna run additionally emits a group-time ATT table with one row per treatment cohort and one column per calendar period.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did estimate did_panel.csv --outcome=y --treatment=D
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did estimate did_panel.csv --outcome=y --treatment=D --method=cs --control-group=not_yet_treated
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did estimate did_panel.csv --outcome=y --treatment=D --method=sa --cluster=twoway
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did estimate did_panel.csv --outcome=y --treatment=D --method=dcdh --n-boot=500
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did estimate did_panel.csv --outcome=y --treatment=D --method=cs --id-col=id --time-col=time --base-period=universal
```

`--leads` and `--horizon` set the pre/post window; `--covariates` names adjustment columns; `--cluster` sets the clustering level. `--n-boot` applies to `dcdh` only and `--base-period` to `cs` only. The leaf emits the `did_estimation` table (ATT, standard error, confidence band by event time); `cs` additionally emits the `group_time_att_callaway_sant_anna` cohort-by-event-time matrix.

---

## did event-study

Panel event study by local projection: leads test the identifying assumption, lags trace the dynamic response.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did event-study did_panel.csv --outcome=y --treatment=D --leads=3 --horizon=5
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did event-study did_panel.csv --outcome=y --treatment=D --lags=6 --cluster=twoway
```

`--lags` (`-p`) sets the control lags. The leaf emits the `event_study_lp` table (coefficient, standard error, confidence band by event time). Non-zero lead coefficients warn that **parallel trends** fails; confirm with `test did pretrend`.

---

## did lp-did

The LP-DiD estimator (Dube, Girardi, Jordà & Taylor) with clean-comparison and reweighting machinery. `--pre-window` and `--post-window` bound the comparison window (`--post-window 0` means the horizon); `--ylags` and `--dylags` add outcome lags in levels and differences. `--pmd` selects pre-treatment matching (`ccs`, `ipw`, or an integer); `--nonabsorbing` takes integer periods for non-absorbing treatments. The control set and output shape come from flags: `--reweight`, `--nocomp`, `--notyet`, `--nevertreated`, `--firsttreat`, `--oneoff`, `--only-pooled`, `--only-event`.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did lp-did did_panel.csv --outcome=y --treatment=D --horizon=5
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did lp-did did_panel.csv --outcome=y --treatment=D --horizon=5 --reweight --pmd=ipw
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did lp-did did_panel.csv --outcome=y --treatment=D --horizon=5 --notyet --only-pooled
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman did lp-did did_panel.csv --outcome=y --treatment=D --horizon=5 --pre-window=3 --post-window=5
```

The leaf emits the `lp_did_dube_et_al_2023` table (coefficient, standard error, confidence band, observation count by event time) plus pooled pre/post effects on stderr unless an `--only-*` flag narrows the report.

---

## Diagnostics under `test did`

Four diagnostics live under `test did`: spell them `friedman test did …` — `did test …` does not dispatch. Options repeat the estimator surface above; see the [generated `test` reference](generated/test.md) for full tables.

### test did bacon

Bacon decomposition (Goodman-Bacon): split the TWFE estimate into its 2×2 comparisons and weights to diagnose heterogeneity bias.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman test did bacon did_panel.csv --outcome=y --treatment=D
```

### test did pretrend

Joint test of the parallel-trends assumption from pre-treatment coefficients. `--method` selects the source (`did` or `event-study`); `--did-method` picks the DiD estimator when the source is `did`.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman test did pretrend did_panel.csv --outcome=y --treatment=D
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman test did pretrend did_panel.csv --outcome=y --treatment=D --method=event-study
```

### test did negweight

Negative-weight check (de Chaisemartin–D'Haultfoeuille): report whether TWFE assigns negative weights, how many, and their total. Takes `--treatment` without `--outcome`.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman test did negweight did_panel.csv --treatment=D
```

### test did honest

HonestDiD sensitivity (Rambachan–Roth): robust confidence intervals under bounded parallel-trends violations. `--mbar` sets the violation bound; `--method` and `--did-method` work as in `pretrend`.

```bash
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman test did honest did_panel.csv --outcome=y --treatment=D --mbar=1.0
friedman data simulate did --n 10 --periods 12 --seed 7 --format csv --output did_panel.csv && friedman test did honest did_panel.csv --outcome=y --treatment=D --method=event-study --mbar=0.5
```

---

## References

- Callaway & Sant'Anna (2021). Difference-in-differences with multiple time periods.
- Sun & Abraham (2021). Estimating dynamic treatment effects in event studies with heterogeneous treatment effects.
- Borusyak, Jaravel & Spiess (2024). Revisiting event-study designs.
- de Chaisemartin & D'Haultfoeuille (2020). Two-way fixed effects estimators with heterogeneous treatment effects.
- Dube, Girardi, Jordà & Taylor. Local projections–difference-in-differences.
- Goodman-Bacon (2021). Difference-in-differences with variation in treatment timing.
- Rambachan & Roth (2023). A more credible approach to parallel trends.
- Full option and output-table reference: [generated `did` reference](generated/did.md), [generated `test` reference](generated/test.md).
