# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Test commands: adf, kpss, pp, za, np, johansen, normality, identifiability,
#                heteroskedasticity, arch_lm, ljung_box, var (lagselect, stability),
#                granger, pvar (hansen_j, mmsc, lagselect, stability), lr, lm,
#                andrews, bai-perron, panic, cips, moon-perron, factor-break,
#                fourier-adf, fourier-kpss, dfgls, lm-unitroot, adf-2break,
#                gregory-hansen, vif

function test_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["test", "adf"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="max-lags", type=Int, default=nothing, description="Max lags (default: auto via AIC)"),
                OptionSpec(name="trend", type=String, default="constant", description="none|constant|trend|both"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:adf, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_adf),
        ),
        CommandSpec(
            path=["test", "kpss"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test"),
                OptionSpec(name="trend", type=String, default="constant", description="constant|trend"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:kpss, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_kpss),
        ),
        CommandSpec(
            path=["test", "pp"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test"),
                OptionSpec(name="trend", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pp, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_pp),
        ),
        CommandSpec(
            path=["test", "za"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test"),
                OptionSpec(name="trend", type=String, default="both", description="intercept|trend|both"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming proportion"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:za, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_za),
        ),
        CommandSpec(
            path=["test", "np"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test"),
                OptionSpec(name="trend", type=String, default="constant", description="constant|trend"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:np, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_np),
        ),
        CommandSpec(
            path=["test", "gph"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test"),
                OptionSpec(name="bandwidth", short="m", type=Int, default=nothing, description="Number of Fourier frequencies (default: floor(sqrt(T)))"),
                OptionSpec(name="trim", type=Int, default=0, description="Trim the first N frequencies"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:gph, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_gph),
        ),
        CommandSpec(
            path=["test", "local-whittle"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test"),
                OptionSpec(name="bandwidth", short="m", type=Int, default=nothing, description="Number of Fourier frequencies (default: floor(sqrt(T)))"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=Symbol("local-whittle"), description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_local_whittle),
        ),
        CommandSpec(
            path=["test", "johansen"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order"),
                OptionSpec(name="trend", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:johansen, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_johansen),
        ),
        CommandSpec(
            path=["test", "normality"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:normality, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_normality),
        ),
        CommandSpec(
            path=["test", "identifiability"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="test", short="t", type=String, default="all", description="strength|gaussianity|independence|overidentification|all"),
                OptionSpec(name="method", type=String, default="fastica", description="fastica|jade|sobi|dcov|hsic (for gaussianity/independence/overidentification tests)"),
                OptionSpec(name="contrast", type=String, default="logcosh", description="logcosh|exp|kurtosis (for FastICA)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:identifiability, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_identifiability),
        ),
        CommandSpec(
            path=["test", "heteroskedasticity"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="method", type=String, default="markov", description="markov|garch|smooth_transition|external"),
                OptionSpec(name="config", type=String, default="", description="TOML config (for transition/regime variables)"),
                OptionSpec(name="regimes", type=Int, default=2, description="Number of regimes"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:heteroskedasticity, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_heteroskedasticity),
        ),
        CommandSpec(
            path=["test", "arch-lm"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="lags", short="p", type=Int, default=4, description="Number of lags for ARCH-LM test"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:arch_lm, description="Path to CSV data file")],
            category="test",
            aliases=["arch_lm"],
            handler=wrap_legacy(_test_arch_lm),
        ),
        CommandSpec(
            path=["test", "ljung-box"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="lags", short="p", type=Int, default=10, description="Number of lags for Ljung-Box test"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:ljung_box, description="Path to CSV data file")],
            category="test",
            aliases=["ljung_box"],
            handler=wrap_legacy(_test_ljung_box),
        ),
        # C064b: volatility-model residual diagnostics (Engle-Ng sign bias; Nyblom stability).
        CommandSpec(
            path=["test", "sign-bias"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Return series column (1-based)"),
                OptionSpec(name="model", type=String, default="garch", description="Volatility model to fit: garch | egarch | gjr-garch", choices=["garch","egarch","gjr-garch"]),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:sign_bias, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_sign_bias),
        ),
        CommandSpec(
            path=["test", "nyblom"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Return series column (1-based)"),
                OptionSpec(name="model", type=String, default="garch", description="Volatility model to fit: garch | egarch | gjr-garch", choices=["garch","egarch","gjr-garch"]),
                OptionSpec(name="p", type=Int, default=1, description="GARCH order p"),
                OptionSpec(name="q", type=Int, default=1, description="ARCH order q"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:nyblom, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_nyblom),
        ),
        # C069/C070: randomness/nonlinearity (variance-ratio, BDS) + panel
        # stationarity/cointegration (Hadri; Pedroni/Kao/Westerlund) test batteries.
        # All flat `test` leaves.
        CommandSpec(
            path=["test", "variance-ratio"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="horizons", type=String, default="2,4,8,16", description="Comma-separated holding periods q (each ≥ 2)"),
                OptionSpec(name="method", type=String, default="lomackinlay", description="Variance-ratio method", choices=["lomackinlay"]),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:variance_ratio, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_variance_ratio),
        ),
        CommandSpec(
            path=["test", "bds"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="max-dim", type=Int, default=6, description="Maximum embedding dimension (≥ 2; tests m=2..max)"),
                OptionSpec(name="eps-frac", type=Float64, default=0.7, description="Distance threshold as a fraction of the sample sd"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:bds, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_bds),
        ),
        # C069 (remainder). Trend vocabularies differ per family and are NOT shared:
        # engle-granger/phillips-ouliaris use none|constant|trend; hansen-instability/
        # park-added consume a CointRegModel and use cointreg's none|const|linear.
        CommandSpec(
            path=["test", "hegy"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="frequency", type=Int, default=4, description="Seasonal frequency: 4 (quarterly) or 12 (monthly)"),
                OptionSpec(name="deterministic", type=String, default="const-trend-seas", description="Deterministic terms", choices=["none","const","const-seas","const-trend","const-trend-seas"]),
                OptionSpec(name="lags", type=String, default="auto", description="Augmentation lags: auto or a non-negative integer"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:hegy, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_hegy),
        ),
        CommandSpec(
            path=["test", "ers"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=[FlagSpec(name="trend", description="Include a linear trend (default: constant only)")],
            tables=[TableSpec(name=:ers, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_ers),
        ),
        CommandSpec(
            path=["test", "sadf"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="r0", type=String, default="auto", description="Minimum window fraction: auto or a number in (0,1)"),
                OptionSpec(name="adflag", type=Int, default=0, description="ADF augmentation lags (≥ 0)"),
                OptionSpec(name="mc-reps", type=Int, default=999, description="Monte-Carlo replications for critical values (≥ 1)"),
                OptionSpec(name="cv", type=String, default="asymptotic", description="Critical-value method", choices=["asymptotic","wildboot"]),
                OptionSpec(name="seed", type=Int, default=20240716, description="RNG seed for the critical-value simulation"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:sadf, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_sadf),
        ),
        CommandSpec(
            path=["test", "gsadf"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="r0", type=String, default="auto", description="Minimum window fraction: auto or a number in (0,1)"),
                OptionSpec(name="adflag", type=Int, default=0, description="ADF augmentation lags (≥ 0)"),
                OptionSpec(name="mc-reps", type=Int, default=999, description="Monte-Carlo replications for critical values (≥ 1)"),
                OptionSpec(name="cv", type=String, default="asymptotic", description="Critical-value method", choices=["asymptotic","wildboot"]),
                OptionSpec(name="seed", type=Int, default=20240716, description="RNG seed for the critical-value simulation"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:gsadf, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_gsadf),
        ),
        CommandSpec(
            path=["test", "edf"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="dist", type=String, default="normal", description="Null distribution", choices=["normal","exponential","logistic","gumbel","gamma","weibull","chisq"]),
                OptionSpec(name="test", type=String, default="ad", description="EDF statistic", choices=["ks","lilliefors","cvm","ad","watson"]),
                OptionSpec(name="params", type=String, default="estimate", description="Parameters ML-fitted from the data, or supplied via --theta", choices=["estimate","specified"]),
                OptionSpec(name="theta", type=String, default="", description="Comma-separated parameters (required with --params specified)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:edf, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_edf),
        ),
        CommandSpec(
            path=["test", "engle-granger"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="trend", type=String, default="constant", description="Deterministic terms in the cointegrating regression", choices=["none","constant","trend"]),
                OptionSpec(name="lags", type=String, default="aic", description="ADF lags on the residuals: aic|bic|tstat or a non-negative integer"),
                OptionSpec(name="max-lags", type=String, default="", description="Upper bound for automatic lag selection"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:engle_granger, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_engle_granger),
        ),
        CommandSpec(
            path=["test", "phillips-ouliaris"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="trend", type=String, default="constant", description="Deterministic terms in the cointegrating regression", choices=["none","constant","trend"]),
                OptionSpec(name="kernel", type=String, default="bartlett", description="HAC kernel for the residual long-run variance", choices=["bartlett","parzen","qs","tukey-hanning"]),
                OptionSpec(name="bandwidth", type=String, default="nw", description="HAC bandwidth: nw|andrews|nw94 or a non-negative number"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:phillips_ouliaris, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_phillips_ouliaris),
        ),
        CommandSpec(
            path=["test", "hansen-instability"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="method", type=String, default="fmols", description="Cointegrating-regression estimator", choices=["fmols","ccr","dols"]),
                OptionSpec(name="trend", type=String, default="const", description="Deterministic terms (cointreg vocabulary)", choices=["none","const","linear"]),
                OptionSpec(name="kernel", type=String, default="bartlett", description="HAC kernel for the fit", choices=["bartlett","parzen","qs","tukey-hanning"]),
                OptionSpec(name="bandwidth", type=String, default="andrews", description="Fit bandwidth: andrews|nw94 or a non-negative number"),
                OptionSpec(name="leads", type=String, default="auto", description="DOLS leads: auto or a non-negative integer"),
                OptionSpec(name="lags", type=String, default="auto", description="DOLS lags: auto or a non-negative integer"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:hansen_instability, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_hansen_instability),
        ),
        CommandSpec(
            path=["test", "park-added"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="method", type=String, default="fmols", description="Cointegrating-regression estimator", choices=["fmols","ccr","dols"]),
                OptionSpec(name="trend", type=String, default="const", description="Deterministic terms (cointreg vocabulary)", choices=["none","const","linear"]),
                OptionSpec(name="kernel", type=String, default="bartlett", description="HAC kernel for the fit", choices=["bartlett","parzen","qs","tukey-hanning"]),
                OptionSpec(name="bandwidth", type=String, default="andrews", description="Fit bandwidth: andrews|nw94 or a non-negative number"),
                OptionSpec(name="leads", type=String, default="auto", description="DOLS leads: auto or a non-negative integer"),
                OptionSpec(name="lags", type=String, default="auto", description="DOLS lags: auto or a non-negative integer"),
                OptionSpec(name="q-add", type=Int, default=2, description="Number of superfluous trends added (≥ 1; the test df)"),
                OptionSpec(name="hac-kernel", type=String, default="bartlett", description="HAC kernel for the test statistic", choices=["bartlett","parzen","qs","tukey-hanning"]),
                OptionSpec(name="hac-bandwidth", type=String, default="nw", description="HAC bandwidth for the test: nw|andrews|nw94 or a non-negative number"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:park_added, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_park_added),
        ),
        # C067 remainder (#72): cross-section OLS diagnostics. All fit via
        # _load_reg_data + estimate_reg — NOT the panel loader that the existing
        # `test breusch-pagan` (panel RE variant) uses.
        CommandSpec(
            path=["test", "white"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=[FlagSpec(name="no-cross-terms", description="Omit the cross-product terms from the auxiliary regression")],
            tables=[TableSpec(name=:white, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_white),
        ),
        CommandSpec(
            path=["test", "glejser"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:glejser, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_glejser),
        ),
        CommandSpec(
            path=["test", "harvey"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:harvey, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_harvey),
        ),
        CommandSpec(
            path=["test", "chow"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                # --break-at, not --break: `break` is a Julia reserved word and cannot be a kwarg.
                OptionSpec(name="break-at", type=String, default="", description="Required: 1-based break index, or a comma-separated list for a multi-break test"),
                OptionSpec(name="type", type=String, default="breakpoint", description="Chow variant", choices=["breakpoint","forecast"]),
                OptionSpec(name="level", type=Float64, default=0.05, description="Significance level in (0,1)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:chow, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_chow),
        ),
        CommandSpec(
            path=["test", "cusum"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="level", type=Float64, default=0.05, description="Band significance level in (0,1)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:cusum, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_cusum),
        ),
        CommandSpec(
            path=["test", "cusumsq"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="level", type=Float64, default=0.05, description="Band significance level in (0,1)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:cusumsq, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_cusumsq),
        ),
        CommandSpec(
            path=["test", "recursive-residuals"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:recursive_residuals, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_recursive_residuals),
        ),
        CommandSpec(
            path=["test", "influence"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column (default: first numeric)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator for the OLS fit"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:influence, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_influence),
        ),
        # C065a: Hansen (1996) sup-LM / sup-Wald test of linearity vs a two-regime SETAR
        # threshold, with fixed-regressor-bootstrap p-values. Reads `.linearity` off a
        # `estimate_setar(...; linearity=true)` fit (identical numbers, no design rebuild).
        CommandSpec(
            path=["test", "hansen-linearity"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order for the SETAR design (≥ 1)"),
                OptionSpec(name="d", type=Int, default=1, description="Delay lag for the threshold variable q=y[t-d] (≥ 1)"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming fraction for the threshold grid (0 < trim < 0.5)"),
                OptionSpec(name="reps", type=Int, default=1000, description="Fixed-regressor bootstrap replications (≥ 1)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_hansen_linearity, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_hansen_linearity),
        ),
        # C065b: Luukkonen–Saikkonen–Teräsvirta LM3 test of linearity vs a smooth-transition
        # (STAR) alternative. Wraps `star_linearity_test` (a deterministic NamedTuple → pure
        # kv). An external transition variable can be supplied via `--transition-col`.
        CommandSpec(
            path=["test", "star-linearity"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="p", type=Int, default=1, description="AR order (≥ 1)"),
                OptionSpec(name="d", type=Int, default=1, description="Delay lag for the self-exciting transition var (≥ 1)"),
                OptionSpec(name="transition-col", type=Int, default=0, description="Column index of an external transition var s (0 = self-exciting y[t-d])"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_star_linearity, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_star_linearity),
        ),
        CommandSpec(
            path=["test", "hadri"],
            summary="Path to CSV data file (rows=T, cols=N units)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file (rows=T, cols=N units)")],
            options=[
                OptionSpec(name="deterministic", type=String, default="constant", description="constant|trend", choices=["constant","trend"]),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:hadri, description="Path to CSV data file (rows=T, cols=N units)")],
            category="test",
            handler=wrap_legacy(_test_hadri),
        ),
        CommandSpec(
            path=["test", "pedroni"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column (default: second column)"),
                OptionSpec(name="dep", type=String, default="", description="Dependent variable (default: first panel variable)"),
                OptionSpec(name="indep", type=String, default="", description="Comma-separated regressors (default: all other panel variables)"),
                OptionSpec(name="trend", type=String, default="constant", description="constant|trend", choices=["constant","trend"]),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pedroni, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_pedroni),
        ),
        CommandSpec(
            path=["test", "kao"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column (default: second column)"),
                OptionSpec(name="dep", type=String, default="", description="Dependent variable (default: first panel variable)"),
                OptionSpec(name="indep", type=String, default="", description="Comma-separated regressors (default: all other panel variables)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:kao, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_kao),
        ),
        CommandSpec(
            path=["test", "westerlund"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column (default: second column)"),
                OptionSpec(name="dep", type=String, default="", description="Dependent variable (default: first panel variable)"),
                OptionSpec(name="indep", type=String, default="", description="Comma-separated regressors (default: all other panel variables)"),
                OptionSpec(name="trend", type=String, default="constant", description="constant|trend", choices=["constant","trend"]),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:westerlund, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_westerlund),
        ),
        # C067b: weak-instrument diagnostics for cross-section 2SLS. Fits `estimate_iv`
        # (shared `_load_iv_data` loader) and reports the stored first-stage/Cragg-Donald/
        # Kleibergen-Paap F against the Stock-Yogo 10%-maximal-bias critical value.
        CommandSpec(
            path=["test", "weak-instrument"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable column name (default: first numeric column)"),
                OptionSpec(name="endogenous", type=String, default="", description="Endogenous regressor column names, comma-separated (required)"),
                OptionSpec(name="instruments", type=String, default="", description="EXCLUDED instrument column names, comma-separated (required; other numeric cols are exogenous regressors — include a `const` for an intercept)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="ols|hc0|hc1|hc2|hc3"),
                OptionSpec(name="threshold", type=Float64, default=10.0, description="First-stage F rule-of-thumb (used if no Stock-Yogo CV)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:weak_instrument, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_weak_instrument),
        ),
        # C062b: ARDL bounds test (Pesaran-Shin-Smith 2001) + NARDL symmetry Wald tests.
        # Both fit a single-equation (N)ARDL via the shared `_load_reg_data` loader + the
        # `_fit_ardl`/`_fit_nardl` helpers (estimate.jl), then run the test. The bounds test has
        # NO p-value (non-standard I(0)/I(1) bounds) → decision symbols, never interpret_test_result.
        CommandSpec(
            path=["test", "ardl-bounds"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent column name (default: first numeric column)"),
                OptionSpec(name="p", type=String, default="auto", description="AR order: auto or an integer ≥ 1"),
                OptionSpec(name="q", type=String, default="auto", description="DL order: auto, an integer, or a comma-separated per-regressor list"),
                OptionSpec(name="max-p", type=Int, default=4, description="Max AR order for auto IC selection"),
                OptionSpec(name="max-q", type=Int, default=4, description="Max DL order for auto IC selection"),
                OptionSpec(name="ic", type=String, default="aic", description="Selection criterion: aic|bic", choices=["aic","bic"]),
                OptionSpec(name="trend", type=String, default="none", description="Informational trend label: none|const|trend", choices=["none","const","trend"]),
                OptionSpec(name="case", type=Int, default=3, description="Pesaran-Shin-Smith deterministic case (1..5)"),
                OptionSpec(name="level", type=Float64, default=0.05, description="Decision level: one of 0.10|0.05|0.025|0.01"),
                OptionSpec(name="cv-source", type=String, default="pss", description="Critical-value source (only pss)", choices=["pss"]),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:ardl_bounds, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_ardl_bounds),
        ),
        CommandSpec(
            path=["test", "nardl-symmetry"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent column name (default: first numeric column)"),
                OptionSpec(name="asymmetric", type=String, default="all", description="'all' or comma-separated 1-based regressor indices to split into +/-"),
                OptionSpec(name="p", type=String, default="auto", description="AR order: auto or an integer ≥ 1"),
                OptionSpec(name="q", type=String, default="auto", description="DL order: auto, an integer, or a comma-separated list"),
                OptionSpec(name="max-p", type=Int, default=4, description="Max AR order for auto IC selection"),
                OptionSpec(name="max-q", type=Int, default=4, description="Max DL order for auto IC selection"),
                OptionSpec(name="ic", type=String, default="aic", description="Selection criterion: aic|bic", choices=["aic","bic"]),
                OptionSpec(name="case", type=Int, default=3, description="Pesaran-Shin-Smith deterministic case (1..5)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:nardl_symmetry, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_nardl_symmetry),
        ),
        # C062c: PMG Hausman selection test. Fits a long-format panel twice (efficient PMG/DFE
        # vs consistent MG) via the shared `_load_panel_reg` loader, then runs the PMG-typed
        # hausman_test on the common long-run θ. Standard PanelTestResult (HAS a p-value) →
        # interpret_test_result. H0 = long-run homogeneity; low p favours MG.
        CommandSpec(
            path=["test", "pmg-hausman"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group id column (default: first column)"),
                OptionSpec(name="time-col", type=String, default="", description="Panel time column (default: second column)"),
                OptionSpec(name="dep", type=String, default="", description="Dependent panel variable (default: first variable)"),
                OptionSpec(name="indep", type=String, default="", description="Long-run regressors, comma-separated (default: all other variables)"),
                OptionSpec(name="efficient", type=String, default="pmg", description="Estimator efficient under H0: pmg|dfe (consistent is always MG)", choices=["pmg","dfe"]),
                OptionSpec(name="trend", type=String, default="constant", description="Per-unit EC deterministics: none|constant|trend", choices=["none","constant","trend"]),
                OptionSpec(name="p", type=Int, default=1, description="Autoregressive order (≥ 1)"),
                OptionSpec(name="q", type=Int, default=1, description="Distributed-lag order for all regressors (≥ 0)"),
                OptionSpec(name="maxiter", type=Int, default=100, description="PMG outer-loop max iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-8, description="PMG outer-loop convergence tolerance"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pmg_hausman, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_pmg_hausman),
        ),
        # C071: VECM cointegration restriction tests (Johansen LR on β / α).
        # Each fits a VECM then tests a linear restriction on the cointegrating
        # structure; restriction matrices come from a [vecm_restriction] config.
        CommandSpec(
            path=["test", "vecm", "beta"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config with [vecm_restriction] H = [[...],...] (p×s, s≥r)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels, VECM uses p-1)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="method", type=String, default="johansen", description="johansen|engle_granger"),
                OptionSpec(name="significance", type=Float64, default=0.05, description="Significance level for rank selection"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_vecm_beta, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_vecm_beta),
        ),
        CommandSpec(
            path=["test", "vecm", "alpha"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config with [vecm_restriction] A = [[...],...] (p×a, a≥r)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels, VECM uses p-1)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="method", type=String, default="johansen", description="johansen|engle_granger"),
                OptionSpec(name="significance", type=Float64, default=0.05, description="Significance level for rank selection"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_vecm_alpha, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_vecm_alpha),
        ),
        CommandSpec(
            path=["test", "vecm", "weak-exog"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="vars", type=String, default="", description="Comma-separated variable indices or names to test for weak exogeneity"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels, VECM uses p-1)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="method", type=String, default="johansen", description="johansen|engle_granger"),
                OptionSpec(name="significance", type=Float64, default=0.05, description="Significance level for rank selection"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_vecm_weak_exog, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_vecm_weak_exog),
        ),
        CommandSpec(
            path=["test", "vecm", "known-beta"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config with [vecm_restriction] b = [[...],...] (p×r, exactly r cols)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels, VECM uses p-1)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="method", type=String, default="johansen", description="johansen|engle_granger"),
                OptionSpec(name="significance", type=Float64, default=0.05, description="Significance level for rank selection"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_vecm_known_beta, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_vecm_known_beta),
        ),
        CommandSpec(
            path=["test", "vecm", "joint"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="config", type=String, default="", description="TOML config with [vecm_restriction] both H and A matrices"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels, VECM uses p-1)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="method", type=String, default="johansen", description="johansen|engle_granger"),
                OptionSpec(name="significance", type=Float64, default=0.05, description="Significance level for rank selection"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:test_vecm_joint, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_vecm_joint),
        ),
        CommandSpec(
            path=["test", "var", "lagselect"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="max-lags", type=Int, default=12, description="Maximum lag order to test"),
                OptionSpec(name="criterion", type=String, default="aic", description="aic|bic|hqc"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:var_lagselect, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_var_lagselect),
        ),
        CommandSpec(
            path=["test", "var", "stability"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="lags", short="p", type=Int, default=nothing, description="Lag order (default: auto via AIC)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:var_stability, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_var_stability),
        ),
        CommandSpec(
            path=["test", "granger"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="cause", type=Int, default=1, description="Cause variable index (1-based)"),
                OptionSpec(name="effect", type=Int, default=2, description="Effect variable index (1-based)"),
                OptionSpec(name="lags", short="p", type=Int, default=2, description="Lag order (in levels)"),
                OptionSpec(name="rank", short="r", type=String, default="auto", description="Cointegration rank (auto|1|2|...)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="none|constant|trend"),
                OptionSpec(name="model", type=String, default="vecm", description="var|vecm (model type for Granger test)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=[
                FlagSpec(name="all", description="Test all pairwise combinations (VAR only)")
            ],
            tables=[TableSpec(name=:granger, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_granger),
        ),
        CommandSpec(
            path=["test", "pvar", "hansen-j"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="Lag order"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pvar_hansen_j, description="Path to CSV panel data file")],
            category="test",
            aliases=["hansen_j"],
            handler=wrap_legacy(_test_pvar_hansen_j),
        ),
        CommandSpec(
            path=["test", "pvar", "mmsc"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column"),
                OptionSpec(name="max-lags", type=Int, default=4, description="Maximum lag order to test"),
                OptionSpec(name="criterion", type=String, default="bic", description="bic|aic|hqic"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pvar_mmsc, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_pvar_mmsc),
        ),
        CommandSpec(
            path=["test", "pvar", "lagselect"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column"),
                OptionSpec(name="max-lags", type=Int, default=4, description="Maximum lag order to test"),
                OptionSpec(name="criterion", type=String, default="bic", description="bic|aic|hqic"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pvar_lagselect, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_pvar_lagselect),
        ),
        CommandSpec(
            path=["test", "pvar", "stability"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[
                OptionSpec(name="id-col", type=String, default="", description="Panel group identifier column"),
                OptionSpec(name="time-col", type=String, default="", description="Time period column"),
                OptionSpec(name="lags", short="p", type=Int, default=1, description="Lag order"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pvar_stability, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_pvar_stability),
        ),
        CommandSpec(
            path=["test", "lr"],
            summary="Path to CSV data file for restricted model",
            args=[ArgSpec(name="data1", type=String, required=true, default=nothing, description="Path to CSV data file for restricted model"), ArgSpec(name="data2", type=String, required=true, default=nothing, description="Path to CSV data file for unrestricted model")],
            options=[
                OptionSpec(name="lags1", type=Int, default=nothing, description="Lag order for restricted model (default: auto)"),
                OptionSpec(name="lags2", type=Int, default=nothing, description="Lag order for unrestricted model (default: auto)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:lr, description="Path to CSV data file for restricted model")],
            category="test",
            handler=wrap_legacy(_test_lr),
        ),
        CommandSpec(
            path=["test", "lm"],
            summary="Path to CSV data file for restricted model",
            args=[ArgSpec(name="data1", type=String, required=true, default=nothing, description="Path to CSV data file for restricted model"), ArgSpec(name="data2", type=String, required=true, default=nothing, description="Path to CSV data file for unrestricted model")],
            options=[
                OptionSpec(name="lags1", type=Int, default=nothing, description="Lag order for restricted model (default: auto)"),
                OptionSpec(name="lags2", type=Int, default=nothing, description="Lag order for unrestricted model (default: auto)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:lm, description="Path to CSV data file for restricted model")],
            category="test",
            handler=wrap_legacy(_test_lm),
        ),
        CommandSpec(
            path=["test", "andrews"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="response", type=Int, default=1, description="Response variable column index (1-based)"),
                OptionSpec(name="test", type=String, default="supwald", description="supwald|suplr|suplm|expwald|explr|explm|meanwald|meanlr|meanlm"),
                OptionSpec(name="trimming", type=Float64, default=0.15, description="Trimming proportion"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:andrews, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_andrews),
        ),
        CommandSpec(
            path=["test", "bai-perron"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="response", type=Int, default=1, description="Response variable column index (1-based)"),
                OptionSpec(name="max-breaks", type=Int, default=5, description="Maximum number of breaks"),
                OptionSpec(name="trimming", type=Float64, default=0.15, description="Trimming proportion"),
                OptionSpec(name="criterion", type=String, default="bic", description="bic|lwz"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bai_perron, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_bai_perron),
        ),
        CommandSpec(
            path=["test", "panic"],
            summary="Path to CSV data file (rows=T, cols=N)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="factors", type=String, default="auto", description="Number of factors (auto|N)"),
                OptionSpec(name="method", type=String, default="pooled", description="pooled|individual"),
                OptionSpec(name="id-col", type=String, default="", description="Panel unit ID column (optional)"),
                OptionSpec(name="time-col", type=String, default="", description="Time column (optional)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:panic, description="Path to CSV data file (rows=T, cols=N)")],
            category="test",
            handler=wrap_legacy(_test_panic),
        ),
        CommandSpec(
            path=["test", "cips"],
            summary="Path to CSV data file (rows=T, cols=N)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="lags", type=String, default="auto", description="Lag order (auto|N)"),
                OptionSpec(name="deterministic", type=String, default="constant", description="constant|trend"),
                OptionSpec(name="id-col", type=String, default="", description="Panel unit ID column (optional)"),
                OptionSpec(name="time-col", type=String, default="", description="Time column (optional)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:cips, description="Path to CSV data file (rows=T, cols=N)")],
            category="test",
            handler=wrap_legacy(_test_cips),
        ),
        CommandSpec(
            path=["test", "moon-perron"],
            summary="Path to CSV data file (rows=T, cols=N)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="factors", type=String, default="auto", description="Number of factors (auto|N)"),
                OptionSpec(name="id-col", type=String, default="", description="Panel unit ID column (optional)"),
                OptionSpec(name="time-col", type=String, default="", description="Time column (optional)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:moon_perron, description="Path to CSV data file (rows=T, cols=N)")],
            category="test",
            handler=wrap_legacy(_test_moon_perron),
        ),
        CommandSpec(
            path=["test", "factor-break"],
            summary="Path to CSV data file (rows=T, cols=N)",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="factors", type=Int, default=2, description="Number of factors"),
                OptionSpec(name="method", type=String, default="breitung_eickmeier", description="breitung_eickmeier|chen_dolado_gonzalo|han_inoue"),
                OptionSpec(name="id-col", type=String, default="", description="Panel unit ID column (optional)"),
                OptionSpec(name="time-col", type=String, default="", description="Time column (optional)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:factor_break, description="Path to CSV data file (rows=T, cols=N)")],
            category="test",
            handler=wrap_legacy(_test_factor_break),
        ),
        CommandSpec(
            path=["test", "fourier-adf"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="regression", type=String, default="constant", description="constant|trend"),
                OptionSpec(name="fmax", type=Int, default=3, description="Maximum Fourier frequency"),
                OptionSpec(name="lags", type=String, default="aic", description="Lag order (aic|bic|N)"),
                OptionSpec(name="max-lags", type=Int, default=nothing, description="Max lags (default: auto)"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming proportion"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:fourier_adf, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_fourier_adf),
        ),
        CommandSpec(
            path=["test", "fourier-kpss"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="regression", type=String, default="constant", description="constant|trend"),
                OptionSpec(name="fmax", type=Int, default=3, description="Maximum Fourier frequency"),
                OptionSpec(name="bandwidth", type=Int, default=nothing, description="Bandwidth (default: auto)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:fourier_kpss, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_fourier_kpss),
        ),
        CommandSpec(
            path=["test", "dfgls"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="regression", type=String, default="constant", description="constant|trend"),
                OptionSpec(name="lags", type=String, default="aic", description="Lag order (aic|bic|N)"),
                OptionSpec(name="max-lags", type=Int, default=nothing, description="Max lags (default: auto)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:dfgls, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_dfgls),
        ),
        CommandSpec(
            path=["test", "lm-unitroot"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="breaks", type=Int, default=0, description="Number of structural breaks (0|1|2)"),
                OptionSpec(name="regression", type=String, default="level", description="level|trend"),
                OptionSpec(name="lags", type=String, default="aic", description="Lag order (aic|bic|N)"),
                OptionSpec(name="max-lags", type=Int, default=nothing, description="Max lags (default: auto)"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming proportion"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:lm_unitroot, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_lm_unitroot),
        ),
        CommandSpec(
            path=["test", "adf-2break"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index to test (1-based)"),
                OptionSpec(name="model", type=String, default="level", description="level|trend|regime"),
                OptionSpec(name="lags", type=String, default="aic", description="Lag order (aic|bic|N)"),
                OptionSpec(name="max-lags", type=Int, default=nothing, description="Max lags (default: auto)"),
                OptionSpec(name="trim", type=Float64, default=0.10, description="Trimming proportion"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:adf_2break, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_adf_2break),
        ),
        CommandSpec(
            path=["test", "gregory-hansen"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="model", type=String, default="C", description="C|C/T|C/S (level shift/trend/regime)"),
                OptionSpec(name="lags", type=String, default="aic", description="Lag order (aic|bic|N)"),
                OptionSpec(name="max-lags", type=Int, default=nothing, description="Max lags (default: auto)"),
                OptionSpec(name="trim", type=Float64, default=0.15, description="Trimming proportion"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:gregory_hansen, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_gregory_hansen),
        ),
        CommandSpec(
            path=["test", "vif"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable name (default: first numeric column)"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance estimator (ols|hc0|hc1|hc2|hc3)"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:vif, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_vif),
        ),
        CommandSpec(
            path=["test", "hausman"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[select_options(PREG_OPTIONS, "dep", "indep", "id-col", "time-col")...; OUTPUT_OPTIONS...],
            flags=FlagSpec[],
            tables=[TableSpec(name=:hausman, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_hausman),
        ),
        CommandSpec(
            path=["test", "breusch-pagan"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[select_options(PREG_OPTIONS, "dep", "indep", "id-col", "time-col")...; OUTPUT_OPTIONS...],
            flags=FlagSpec[],
            tables=[TableSpec(name=:breusch_pagan, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_breusch_pagan),
        ),
        CommandSpec(
            path=["test", "f-fe"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[select_options(PREG_OPTIONS, "dep", "indep", "id-col", "time-col")...; OUTPUT_OPTIONS...],
            flags=FlagSpec[],
            tables=[TableSpec(name=:f_fe, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_f_fe),
        ),
        CommandSpec(
            path=["test", "pesaran-cd"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[select_options(PREG_OPTIONS, "dep", "indep", "id-col", "time-col")...; OUTPUT_OPTIONS...],
            flags=FlagSpec[],
            tables=[TableSpec(name=:pesaran_cd, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_pesaran_cd),
        ),
        CommandSpec(
            path=["test", "wooldridge-ar"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[select_options(PREG_OPTIONS, "dep", "indep", "id-col", "time-col")...; OUTPUT_OPTIONS...],
            flags=FlagSpec[],
            tables=[TableSpec(name=:wooldridge_ar, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_wooldridge_ar),
        ),
        CommandSpec(
            path=["test", "modified-wald"],
            summary="Path to CSV panel data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV panel data file")],
            options=[select_options(PREG_OPTIONS, "dep", "indep", "id-col", "time-col")...; OUTPUT_OPTIONS...],
            flags=FlagSpec[],
            tables=[TableSpec(name=:modified_wald, description="Path to CSV panel data file")],
            category="test",
            handler=wrap_legacy(_test_modified_wald),
        ),
        CommandSpec(
            path=["test", "fisher"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:fisher, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_fisher),
        ),
        CommandSpec(
            path=["test", "bartlett-wn"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:bartlett_wn, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_bartlett_wn),
        ),
        CommandSpec(
            path=["test", "box-pierce"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index"),
                OptionSpec(name="lags", short="p", type=Int, default=20, description="Number of lags"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:box_pierce, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_box_pierce),
        ),
        CommandSpec(
            path=["test", "durbin-watson"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="column", short="c", type=Int, default=1, description="Column index"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:durbin_watson, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_durbin_watson),
        ),
        CommandSpec(
            path=["test", "brant"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable"),
                OptionSpec(name="cov-type", type=String, default="hc1", description="Covariance type"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:brant, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_brant),
        ),
        CommandSpec(
            path=["test", "hausman-iia"],
            summary="Path to CSV data file",
            args=[ArgSpec(name="data", type=String, required=true, default=nothing, description="Path to CSV data file")],
            options=[
                OptionSpec(name="dep", type=String, default="", description="Dependent variable"),
                OptionSpec(name="omit-category", type=Int, default=nothing, description="Category to omit for IIA test"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file")
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:hausman_iia, description="Path to CSV data file")],
            category="test",
            handler=wrap_legacy(_test_hausman_iia),
        )
    ]
end

function register_test_commands!()
    specs = with_config_ergonomics(test_specs())
    register!(specs)
    return build_node("test", specs; description="Statistical tests (unit root, cointegration, diagnostics)")
end


# ── Unit Root Tests ──────────────────────────────────────

function _test_adf(; data::String, column::Int=1, max_lags=nothing,
                    trend::String="constant", format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    lags_arg = isnothing(max_lags) ? :aic : max_lags
    regression = to_regression_symbol(trend)

    _status("ADF Test: variable=$vname, observations=$(length(y)), trend=$trend")
    _status()

    result = adf_test(y; lags=lags_arg, regression=regression)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "Lags" => result.lags,
        "p-value" => round(result.pvalue; digits=4),
    ]

    output_kv(pairs; format=format, output=output, title="ADF Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% level -- series appears stationary",
        "Cannot reject H0 (unit root) at 5% level -- series appears non-stationary")
end

function _test_kpss(; data::String, column::Int=1, trend::String="constant",
                     format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    regression = to_regression_symbol(trend)

    _status("KPSS Test: variable=$vname, observations=$(length(y)), trend=$trend")
    _status()

    result = kpss_test(y; regression=regression)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
    ]

    output_kv(pairs; format=format, output=output, title="KPSS Test: $vname")

    # KPSS: reversed interpretation (H0 = stationarity)
    pval = hasproperty(result, :pvalue) ? result.pvalue : 1.0
    _status()
    if pval < 0.05
        _status_styled("-> Reject H0 (stationarity) at 5% -- series appears non-stationary\n"; color=:yellow)
    else
        _status_styled("-> Cannot reject H0 (stationarity) -- series appears stationary\n"; color=:green)
    end
end

function _test_pp(; data::String, column::Int=1, trend::String="constant",
                   format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    regression = to_regression_symbol(trend)

    _status("Phillips-Perron Test: variable=$vname, observations=$(length(y)), trend=$trend")
    _status()

    result = pp_test(y; regression=regression)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
    ]

    output_kv(pairs; format=format, output=output, title="Phillips-Perron Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% -- series appears stationary",
        "Cannot reject H0 (unit root) at 5% -- series appears non-stationary")
end

function _test_za(; data::String, column::Int=1, trend::String="both",
                   trim::Float64=0.15, format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    regression = to_regression_symbol(trend)

    _status("Zivot-Andrews Test: variable=$vname, observations=$(length(y)), model=$trend")
    _status()

    result = za_test(y; regression=regression, trim=trim)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "Break date" => result.break_index,
    ]

    output_kv(pairs; format=format, output=output, title="Zivot-Andrews Test: $vname")

    _status()
    _status("Estimated structural break at observation $(result.break_index)")
end

function _test_np(; data::String, column::Int=1, trend::String="constant",
                   format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    regression = to_regression_symbol(trend)

    _status("Ng-Perron Test: variable=$vname, observations=$(length(y)), trend=$trend")
    _status()

    result = ngperron_test(y; regression=regression)

    pairs = Pair{String,Any}[
        "MZa statistic" => round(result.MZa; digits=4),
        "MZt statistic" => round(result.MZt; digits=4),
        "MSB statistic" => round(result.MSB; digits=4),
        "MPT statistic" => round(result.MPT; digits=4),
    ]

    output_kv(pairs; format=format, output=output, title="Ng-Perron Test: $vname")
end

# ── Long-Memory (fractional integration) ─────────────────

function _test_gph(; data::String, column::Int=1, bandwidth=nothing, trim::Int=0,
                    format::String="table", output::String="")
    trim >= 0 || throw(CliError("usage/invalid",
        "GPH test: --trim must be >= 0, got $trim"))
    y, vname = load_univariate_series(data, column)
    m_arg = isnothing(bandwidth) ? :default : bandwidth

    _status("GPH Log-Periodogram Test: variable=$vname, observations=$(length(y))")
    _status()

    result = try
        gph_test(y; m=m_arg, trim=trim)
    catch e
        throw(_long_memory_error(e, "GPH test"))
    end

    pairs = Pair{String,Any}[
        "d (long-memory)" => round(result.d; digits=4),
        "Std. error" => round(result.se; digits=4),
        "z-statistic" => round(result.tstat; digits=4),
        "p-value" => round(result.pval; digits=4),
        "Frequencies (m)" => result.m,
        "Trimmed" => result.trim,
        "Observations" => result.n,
    ]

    output_kv(pairs; format=format, output=output, title="GPH Test: $vname")

    interpret_test_result(result.pval,
        "Reject H0 (d = 0) at 5% -- evidence of long memory / fractional integration",
        "Cannot reject H0 (d = 0) at 5% -- no evidence of long memory")
end

function _test_local_whittle(; data::String, column::Int=1, bandwidth=nothing,
                              format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    m_arg = isnothing(bandwidth) ? :default : bandwidth

    _status("Local Whittle Test: variable=$vname, observations=$(length(y))")
    _status()

    result = try
        local_whittle(y; m=m_arg)
    catch e
        throw(_long_memory_error(e, "local Whittle test"))
    end

    pairs = Pair{String,Any}[
        "d (long-memory)" => round(result.d; digits=4),
        "Std. error" => round(result.se; digits=4),
        "z-statistic" => round(result.tstat; digits=4),
        "p-value" => round(result.pval; digits=4),
        "Frequencies (m)" => result.m,
        "Observations" => result.n,
        "Objective R(d)" => round(result.objective; digits=4),
    ]

    output_kv(pairs; format=format, output=output, title="Local Whittle Test: $vname")

    interpret_test_result(result.pval,
        "Reject H0 (d = 0) at 5% -- evidence of long memory / fractional integration",
        "Cannot reject H0 (d = 0) at 5% -- no evidence of long memory")
end

# ── Cointegration ────────────────────────────────────────

function _test_johansen(; data::String, lags::Int=2, trend::String="constant",
                         format::String="table", output::String="")
    Y, varnames = load_multivariate_data(data)
    det = to_regression_symbol(trend)

    _status("Johansen Cointegration Test: $(size(Y, 2)) variables, lags=$lags, trend=$trend")
    _status()

    result = johansen_test(Y, lags; deterministic=det)

    trace_df = DataFrame(
        rank=0:(length(result.trace_stats)-1),
        trace_stat=round.(result.trace_stats; digits=4),
        p_value=round.(result.trace_pvalues; digits=4),
        reject=[p < 0.05 ? "yes" : "no" for p in result.trace_pvalues]
    )
    output_result(trace_df; format=Symbol(format), title="Johansen Trace Test")
    _status()

    maxeig_df = DataFrame(
        rank=0:(length(result.max_eigen_stats)-1),
        max_stat=round.(result.max_eigen_stats; digits=4),
        p_value=round.(result.max_eigen_pvalues; digits=4),
        reject=[p < 0.05 ? "yes" : "no" for p in result.max_eigen_pvalues]
    )
    output_result(maxeig_df; format=Symbol(format),
                  output=output, title="Johansen Max Eigenvalue Test")

    _status()
    rank = 0
    for i in 1:length(result.trace_pvalues)
        if result.trace_pvalues[i] < 0.05
            rank = i
        else
            break
        end
    end
    _status_styled("Estimated cointegration rank: $rank\n"; bold=true)
end

# ── Normality Test Suite ─────────────────────────────────

function _test_normality(; data::String, lags=nothing,
                           output::String="", format::String="table")
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)

    _status("Normality Test Suite: VAR($p), $n variables")
    _status()

    suite = normality_test_suite(model)

    test_df = DataFrame(
        test=String[],
        statistic=Float64[],
        p_value=Float64[],
        df=Int[]
    )
    for r in suite.results
        push!(test_df, (
            test=string(r.test_name),
            statistic=round(r.statistic; digits=4),
            p_value=round(r.pvalue; digits=4),
            df=r.df
        ))
    end

    output_result(test_df; format=Symbol(format), output=output,
                  title="Normality Tests for VAR Residuals")

    _status()
    n_reject = count(r -> r.pvalue < 0.05, suite.results)
    if n_reject > 0
        _status_styled("$n_reject of $(length(suite.results)) tests reject normality at 5%\n"; color=:yellow)
        _status_styled("Non-Gaussian identification methods may be applicable\n"; color=:green)
    else
        _status_styled("No tests reject normality at 5% -- Gaussian assumption appears valid\n"; color=:green)
    end
end

# ── Identifiability Tests ────────────────────────────────

function _test_identifiability(; data::String, lags=nothing, test::String="all",
                                  method::String="fastica", contrast::String="logcosh",
                                  output::String="", format::String="table")
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)

    _status("Identifiability Tests: VAR($p), $n variables")
    _status()

    results_df = DataFrame(
        test=String[],
        statistic=Float64[],
        p_value=Float64[],
        conclusion=String[]
    )

    run_strength = test == "all" || test == "strength"
    run_gaussianity = test == "all" || test == "gaussianity"
    run_independence = test == "all" || test == "independence"
    run_overid = test == "all" || test == "overidentification"
    run_comparison = test == "all"

    if run_strength
        str_result = test_identification_strength(model)
        push!(results_df, (
            test="Identification Strength",
            statistic=round(str_result.statistic; digits=4),
            p_value=round(str_result.pvalue; digits=4),
            conclusion=str_result.pvalue < 0.05 ? "Strong identification" : "Weak identification"
        ))
    end

    ica_result = nothing
    if run_gaussianity || run_independence || run_overid
        ica_result = if method == "jade"
            identify_jade(model)
        elseif method == "sobi"
            identify_sobi(model)
        elseif method == "dcov"
            identify_dcov(model)
        elseif method == "hsic"
            identify_hsic(model)
        else
            identify_fastica(model; contrast=Symbol(contrast))
        end
    end

    if run_gaussianity && !isnothing(ica_result)
        gauss_result = test_shock_gaussianity(ica_result)
        push!(results_df, (
            test="Shock Gaussianity",
            statistic=round(gauss_result.statistic; digits=4),
            p_value=round(gauss_result.pvalue; digits=4),
            conclusion=gauss_result.pvalue < 0.05 ? "Reject Gaussianity" : "Cannot reject Gaussianity"
        ))
    end

    if run_independence && !isnothing(ica_result)
        indep_result = test_shock_independence(ica_result)
        push!(results_df, (
            test="Shock Independence",
            statistic=round(indep_result.statistic; digits=4),
            p_value=round(indep_result.pvalue; digits=4),
            conclusion=indep_result.pvalue < 0.05 ? "Reject independence" : "Cannot reject independence"
        ))
    end

    if run_overid && !isnothing(ica_result)
        overid_result = test_overidentification(model, ica_result)
        push!(results_df, (
            test="Overidentification",
            statistic=round(overid_result.statistic; digits=4),
            p_value=round(overid_result.pvalue; digits=4),
            conclusion=overid_result.pvalue < 0.05 ? "Reject overidentification" : "Cannot reject overidentification"
        ))
    end

    if run_comparison
        comp_result = test_gaussian_vs_nongaussian(model)
        push!(results_df, (
            test="Gaussian vs Non-Gaussian",
            statistic=round(comp_result.statistic; digits=4),
            p_value=round(comp_result.pvalue; digits=4),
            conclusion=comp_result.pvalue < 0.05 ? "Non-Gaussian preferred" : "No significant difference"
        ))
    end

    output_result(results_df; format=Symbol(format), output=output,
                  title="Identifiability Test Results")

    _status()
    n_reject = count(row -> row.p_value < 0.05, eachrow(results_df))
    if n_reject > 0
        _status_styled("$n_reject of $(nrow(results_df)) tests significant at 5%\n"; color=:green)
    else
        _status_styled("No tests significant at 5%\n"; color=:yellow)
    end
end

# ── Heteroskedasticity-Based Identification ──────────────

function _test_heteroskedasticity(; data::String, lags=nothing, method::String="markov",
                                     config::String="", regimes::Int=2,
                                     output::String="", format::String="table")
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = length(varnames)
    df = load_data(data)

    _status("Heteroskedasticity SVAR: method=$method, regimes=$regimes, VAR($p), $n variables")
    _status()

    result = if method == "garch"
        identify_garch(model)
    elseif method == "smooth_transition"
        if isempty(config)
            error("smooth_transition requires --config specifying [nongaussian] transition_variable")
        end
        cfg = load_config(config)
        ng_cfg = get_nongaussian(cfg)
        tv_name = ng_cfg["transition_variable"]
        tv_idx = findfirst(==(tv_name), names(df))
        isnothing(tv_idx) && error("transition variable '$tv_name' not found in data")
        transition_var = Vector{Float64}(df[!, tv_name])
        identify_smooth_transition(model, transition_var)
    elseif method == "external"
        if isempty(config)
            error("external requires --config specifying [nongaussian] regime_variable")
        end
        cfg = load_config(config)
        ng_cfg = get_nongaussian(cfg)
        rv_name = ng_cfg["regime_variable"]
        rv_idx = findfirst(==(rv_name), names(df))
        isnothing(rv_idx) && error("regime variable '$rv_name' not found in data")
        regime_indicator = Vector{Float64}(df[!, rv_name])
        identify_external_volatility(model, regime_indicator; regimes=regimes)
    else
        identify_markov_switching(model; n_regimes=regimes)
    end

    b0_df = DataFrame(result.B0, varnames)
    insertcols!(b0_df, 1, :equation => varnames)
    output_result(b0_df; format=Symbol(format), output=output,
                  title="Structural Impact Matrix (B0) -- $method identification")
end

# ── ARCH-LM Test ─────────────────────────────────────────

function _test_arch_lm(; data::String, column::Int=1, lags::Int=4,
                         format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    _status("ARCH-LM Test: variable=$vname, observations=$(length(y)), lags=$lags")
    _status()

    result = arch_lm_test(y, lags)

    pairs = Pair{String,Any}[
        "LM statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Lags" => lags,
    ]

    output_kv(pairs; format=format, output=output, title="ARCH-LM Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (no ARCH effects) at 5% -- ARCH effects detected",
        "Cannot reject H0 (no ARCH effects) at 5%")
end

# ── Ljung-Box Squared Test ───────────────────────────────

function _test_ljung_box(; data::String, column::Int=1, lags::Int=10,
                           format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    _status("Ljung-Box Squared Residuals Test: variable=$vname, observations=$(length(y)), lags=$lags")
    _status()

    result = ljung_box_squared(y, lags)

    pairs = Pair{String,Any}[
        "Q statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Lags" => lags,
    ]

    output_kv(pairs; format=format, output=output, title="Ljung-Box Squared Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (no serial correlation in squared residuals) at 5%",
        "Cannot reject H0 at 5% -- no significant ARCH effects")
end

# ── C064b: volatility-model residual diagnostics ─────────
# Engle-Ng (1993) sign/size bias and Nyblom (1989)/Hansen (1992) parameter stability.
# Both first fit a univariate volatility model to the series, then test its residuals.
# v1 scope: `--model` is restricted to garch|egarch|gjr-garch — the three that share the
# `(y,p,q)` estimator signature AND are supported by BOTH diagnostics (IGARCH/CGARCH/
# APARCH nyblom support exists upstream but those estimators take different signatures).

"""Fit the univariate volatility model requested by a diagnostic leaf's `--model`.
Restricted to the three (y,p,q)-signature estimators (see scope note above)."""
function _fit_vol_for_diag(y, model::String, p::Int, q::Int)
    model == "garch"     && return estimate_garch(y, p, q)
    model == "egarch"    && return estimate_egarch(y, p, q)
    model == "gjr-garch" && return estimate_gjr_garch(y, p, q)
    throw(CliError("usage/invalid", "unknown --model '$model' (garch|egarch|gjr-garch)"))
end

function _test_sign_bias(; data::String, column::Int=1, model::String="garch",
                          p::Int=1, q::Int=1, format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    _status("Sign-Bias Test (Engle-Ng): variable=$vname, observations=$(length(y)), model=$model")
    _status()
    fitted = try
        _fit_vol_for_diag(y, model, p, q)
    catch e
        throw(_garch_variant_error(e, "$model fit"))
    end
    result = try
        sign_bias_test(fitted)
    catch e
        throw(_garch_variant_error(e, "sign-bias test"))
    end
    pairs = Pair{String,Any}[
        "sign_bias" => round(result.sign_bias; digits=4),
        "sign_bias_t" => round(result.sign_bias_t; digits=4),
        "sign_bias_p" => round(result.sign_bias_p; digits=4),
        "neg_size_t" => round(result.neg_size_t; digits=4),
        "neg_size_p" => round(result.neg_size_p; digits=4),
        "pos_size_t" => round(result.pos_size_t; digits=4),
        "pos_size_p" => round(result.pos_size_p; digits=4),
        "joint_statistic" => round(result.joint_statistic; digits=4),
        "joint_pvalue" => round(result.joint_pvalue; digits=4),
        "dof" => result.dof,
    ]
    output_kv(pairs; format=format, output=output, title="Sign-Bias Test: $vname ($model)")
    interpret_test_result(result.joint_pvalue,
        "Reject H0 (no remaining asymmetry) at 5% -- leverage/asymmetry present; consider EGARCH/GJR",
        "Cannot reject H0 (no remaining asymmetry) at 5%")
end

function _test_nyblom(; data::String, column::Int=1, model::String="garch",
                       p::Int=1, q::Int=1, format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    _status("Nyblom Parameter-Stability Test: variable=$vname, observations=$(length(y)), model=$model")
    _status()
    fitted = try
        _fit_vol_for_diag(y, model, p, q)
    catch e
        throw(_garch_variant_error(e, "$model fit"))
    end
    result = try
        nyblom_test(fitted)
    catch e
        throw(_garch_variant_error(e, "nyblom test"))
    end
    # Headline: per-parameter individual Lᵢ vs the Hansen (1992) 5% critical value (≈0.470).
    df = DataFrame(parameter=result.param_names,
                   L_stat=round.(Float64.(result.individual); digits=4),
                   cv_5pct=fill(round(Float64(result.cv_individual); digits=3), length(result.individual)),
                   reject_5pct=Float64.(result.individual) .> Float64(result.cv_individual))
    output_result(df; format=Symbol(format), output=output,
                  title="Nyblom Individual Stability: $vname ($model)")
    reject_joint = Float64(result.joint) > Float64(result.cv_joint)
    output_kv(Pair{String,Any}[
        "joint_LC" => round(Float64(result.joint); digits=4),
        "cv_joint_5pct" => round(Float64(result.cv_joint); digits=4),
        "n_params" => result.k,
        "reject_joint_5pct" => reject_joint,
    ]; format=format, title="Nyblom Joint Stability: $vname ($model)")
    # nyblom_test is a critical-value test (no p-value); synthesize a decision-consistent
    # pseudo p-value so the standard interpretation line prints (stdout stays data-only).
    interpret_test_result(reject_joint ? 0.01 : 0.5,
        "Reject H0 (stable parameters) at 5% -- evidence of parameter instability",
        "Cannot reject H0 (stable parameters) at 5%")
end

# ── C067b: weak-instrument diagnostics for cross-section 2SLS ──────
# Fits `estimate_iv` (shared typed `_load_iv_data` loader) and surfaces the stored
# excluded-instrument first-stage F, Cragg-Donald F, Kleibergen-Paap (robust) rk-Wald F,
# and the Stock-Yogo 10%-maximal-bias critical value. Verdict: instruments are WEAK when the
# comparison statistic (Cragg-Donald when available — the multi-endogenous statistic; else
# the first-stage partial F) falls below the Stock-Yogo 10% CV, or below `--threshold`
# (Staiger-Stock rule of thumb, default 10) when no critical value is tabulated.
function _test_weak_instrument(; data::String, dep::String="", endogenous::String="",
                                instruments::String="", cov_type::String="hc1",
                                threshold::Float64=10.0, format::String="table", output::String="")
    cov_type in ("ols", "hc0", "hc1", "hc2", "hc3") || throw(CliError("usage/invalid",
        "test weak-instrument: --cov-type must be one of ols|hc0|hc1|hc2|hc3, got '$cov_type'"))
    d = _load_iv_data(data, dep, endogenous, instruments)
    y, X, Z, xcols, endog_idx = d.y, d.X, d.Z, d.xcols, d.endog_idx
    n_excl = length(d.inst_names)   # number of excluded instruments q

    _status("Weak-Instrument Test (Stock-Yogo): $(d.dep_col) ~ $(join(xcols, " + "))")
    _status("  Endogenous: $(join(d.endog_names, ", ")); excluded instruments: $(join(d.inst_names, ", "))")
    _status("  Observations: $(length(y)), excluded instruments: $n_excl, cov type: $cov_type")
    _status()

    model = try
        estimate_iv(y, X, Z; endogenous=endog_idx, cov_type=Symbol(cov_type), varnames=xcols)
    catch e
        throw(_garch_variant_error(e, "IV (2SLS) estimation"))
    end

    fs_f = model.first_stage_f
    cd_f = model.cragg_donald_f
    kp_f = model.kleibergen_paap_f
    sy   = model.stock_yogo_10pct
    # Comparison statistic: Cragg-Donald (proper with >1 endogenous) if present, else first-stage F.
    stat = (cd_f !== nothing && isfinite(cd_f)) ? Float64(cd_f) :
           (fs_f !== nothing ? Float64(fs_f) : NaN)
    cv   = (sy !== nothing) ? Float64(sy) : threshold
    # A NON-FINITE statistic (e.g. a degenerate first stage: more instruments than usable
    # observations → df≤0 → MEMs returns NaN, stored raw) must NOT read as "strong". Treat a
    # non-finite F as weak/unusable, not as a passing verdict (adversarial-review fix — the
    # `_load_iv_data` m<n guard normally prevents this, but keep the handler robust).
    degenerate = !isfinite(stat)
    weak = degenerate || stat < cv

    pairs = Pair{String,Any}["n_endogenous" => length(endog_idx),
                             "n_excluded_instruments" => n_excl]
    # Non-finite diagnostics render as strings (legacy JSON writer rejects NaN/Inf floats).
    _fnum(x) = isfinite(x) ? round(Float64(x); digits=4) : string(Float64(x))
    fs_f !== nothing && push!(pairs, "first_stage_f" => _fnum(fs_f))
    (cd_f !== nothing) && push!(pairs, "cragg_donald_f" => _fnum(cd_f))
    (kp_f !== nothing) && push!(pairs, "kleibergen_paap_f" => _fnum(kp_f))
    if sy !== nothing
        push!(pairs, "stock_yogo_10pct_cv" => round(Float64(sy); digits=4))
    else
        push!(pairs, "threshold" => round(threshold; digits=4))
    end
    push!(pairs, "weak" => weak)
    output_kv(pairs; format=format, output=output,
              title="Weak-Instrument Diagnostics: $(d.dep_col)")

    if degenerate
        interpret_test_result(0.5, "",
            "Weak-instrument F is non-finite (degenerate first stage — likely too many instruments relative to usable observations); instruments are effectively unusable/weak")
    else
        cvsrc = (sy !== nothing) ? "Stock-Yogo 10% CV" : "rule-of-thumb threshold"
        # H0 = "instruments are weak"; a large F rejects it (instruments are strong).
        interpret_test_result(weak ? 0.5 : 0.01,
            "Reject H0 (weak instruments): F=$(round(stat; digits=3)) exceeds the $cvsrc ($(round(cv; digits=3))) -- instruments look strong",
            "Cannot reject H0 (weak instruments): F=$(round(stat; digits=3)) ≤ the $cvsrc ($(round(cv; digits=3))) -- instruments may be weak (biased 2SLS)")
    end
end

# ── C071: VECM cointegration restriction tests ───────────
# Johansen LR tests of linear restrictions on the cointegrating structure
# (β = Hφ, α = Aψ, weak exogeneity, β = b known, and joint β&α). Each fits a VECM
# then runs the restriction test; both the fit and the test throw bare untyped
# MEMs exceptions on bad input (r<1 → ArgumentError, matrix dims → DimensionMismatch/
# ArgumentError), so both are wrapped to typed CliErrors (standing lesson: never let
# an untyped exception on user input reach the top level as an internal exit-1).

"""Fit the VECM every restriction leaf needs; map fit failures to typed errors and
require a cointegrating rank ≥ 1 (all restriction tests demand r ≥ 1 upstream)."""
function _vecm_for_restriction(data, lags, rank, deterministic, method, significance)
    vecm, _, varnames, _ = try
        _load_and_estimate_vecm(data, lags, rank, deterministic, method, significance)
    catch e
        e isa CliError && rethrow()
        (e isa ArgumentError || e isa DomainError) && throw(CliError("data/invalid",
            "VECM estimation: $(sprint(showerror, e))"; hint="check --lags/--rank/--deterministic"))
        e isa DimensionMismatch && throw(CliError("data/shape", "VECM estimation: $(sprint(showerror, e))"))
        throw(CliError("model/error", "VECM estimation failed: $(sprint(showerror, e))"))
    end
    vecm.rank >= 1 || throw(CliError("data/no-cointegration",
        "restriction tests need cointegrating rank ≥ 1 (fitted rank = $(vecm.rank)); set --rank ≥ 1 or check the series"))
    return vecm, varnames
end

"""Map a restriction-test failure. Matrix-dimension errors come from the user's
`--config` restriction matrix → `config/shape`; other bad input → `data/invalid`."""
function _vecm_restriction_error(e, what::String)
    e isa CliError && return e
    e isa DimensionMismatch && return CliError("config/shape",
        "$what: $(sprint(showerror, e))"; hint="check the restriction matrix dimensions in [vecm_restriction]")
    e isa ArgumentError && return CliError("config/shape", "$what: $(sprint(showerror, e))";
        hint="the restriction must have at least r columns and p rows (p = number of series, r = rank)")
    e isa DomainError && return CliError("data/invalid", "$what: $(sprint(showerror, e))")
    return CliError("model/error", "$what failed: $(sprint(showerror, e))")
end

"""Render a `VECMRestrictionTest`: a kv block (LR statistic / df / p-value / rank /
converged / restriction) plus a decision line. H0 = the restriction holds, so a low
p-value rejects the imposed restriction."""
function _vecm_restriction_output(res, label, vname; format, output)
    pairs = Pair{String,Any}[
        "LR statistic" => round(Float64(res.lr_stat); digits=4),
        "df"           => res.df,
        "p-value"      => round(Float64(res.pvalue); digits=4),
        "rank (r)"     => res.rank,
        "converged"    => res.converged,
        "restriction"  => res.description,
    ]
    output_kv(pairs; format=format, output=output, title="$label: $vname")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (restriction holds) at 5% -- the imposed cointegration restriction is rejected",
        "Cannot reject H0 at 5% -- the restriction is consistent with the data")
end

function _test_vecm_beta(; data::String, config::String="", lags::Int=2, rank::String="auto",
        deterministic::String="constant", method::String="johansen", significance::Float64=0.05,
        format::String="table", output::String="")
    isempty(config) && throw(CliError("usage/missing-config",
        "test vecm beta requires --config <toml> with [vecm_restriction] H = [[...],...]"))
    cfg = load_config(config)
    H = get_vecm_restriction(cfg, "H")
    vecm, varnames = _vecm_for_restriction(data, lags, rank, deterministic, method, significance)
    _status("VECM β-restriction test: series=$(length(varnames)), rank=$(vecm.rank)"); _status()
    res = try
        test_beta_restriction(vecm, H)
    catch e
        throw(_vecm_restriction_error(e, "β restriction"))
    end
    _vecm_restriction_output(res, "VECM β-restriction (β = Hφ)", join(varnames, ","); format=format, output=output)
    return res
end

function _test_vecm_alpha(; data::String, config::String="", lags::Int=2, rank::String="auto",
        deterministic::String="constant", method::String="johansen", significance::Float64=0.05,
        format::String="table", output::String="")
    isempty(config) && throw(CliError("usage/missing-config",
        "test vecm alpha requires --config <toml> with [vecm_restriction] A = [[...],...]"))
    cfg = load_config(config)
    A = get_vecm_restriction(cfg, "A")
    vecm, varnames = _vecm_for_restriction(data, lags, rank, deterministic, method, significance)
    _status("VECM α-restriction test: series=$(length(varnames)), rank=$(vecm.rank)"); _status()
    res = try
        test_alpha_restriction(vecm, A)
    catch e
        throw(_vecm_restriction_error(e, "α restriction"))
    end
    _vecm_restriction_output(res, "VECM α-restriction (α = Aψ)", join(varnames, ","); format=format, output=output)
    return res
end

function _test_vecm_known_beta(; data::String, config::String="", lags::Int=2, rank::String="auto",
        deterministic::String="constant", method::String="johansen", significance::Float64=0.05,
        format::String="table", output::String="")
    isempty(config) && throw(CliError("usage/missing-config",
        "test vecm known-beta requires --config <toml> with [vecm_restriction] b = [[...],...]"))
    cfg = load_config(config)
    b = get_vecm_restriction(cfg, "b")
    vecm, varnames = _vecm_for_restriction(data, lags, rank, deterministic, method, significance)
    _status("VECM known-β test: series=$(length(varnames)), rank=$(vecm.rank)"); _status()
    res = try
        test_known_beta(vecm, b)
    catch e
        throw(_vecm_restriction_error(e, "known-β restriction"))
    end
    _vecm_restriction_output(res, "VECM known-β (β = b)", join(varnames, ","); format=format, output=output)
    return res
end

function _test_vecm_joint(; data::String, config::String="", lags::Int=2, rank::String="auto",
        deterministic::String="constant", method::String="johansen", significance::Float64=0.05,
        format::String="table", output::String="")
    isempty(config) && throw(CliError("usage/missing-config",
        "test vecm joint requires --config <toml> with [vecm_restriction] both H and A matrices"))
    cfg = load_config(config)
    H = get_vecm_restriction(cfg, "H")
    A = get_vecm_restriction(cfg, "A")
    vecm, varnames = _vecm_for_restriction(data, lags, rank, deterministic, method, significance)
    _status("VECM joint β&α restriction test: series=$(length(varnames)), rank=$(vecm.rank)"); _status()
    res = try
        test_joint_restriction(vecm, H, A)
    catch e
        throw(_vecm_restriction_error(e, "joint restriction"))
    end
    _vecm_restriction_output(res, "VECM joint (β=Hφ, α=Aψ)", join(varnames, ","); format=format, output=output)
    return res
end

function _test_vecm_weak_exog(; data::String, vars::String="", lags::Int=2, rank::String="auto",
        deterministic::String="constant", method::String="johansen", significance::Float64=0.05,
        format::String="table", output::String="")
    isempty(strip(vars)) && throw(CliError("usage/invalid",
        "test vecm weak-exog requires --vars (e.g. --vars 1,2 or --vars gdp,rate)"))
    # Fit first: need varnames for name resolution + n for the range check.
    vecm, varnames = _vecm_for_restriction(data, lags, rank, deterministic, method, significance)
    n = length(varnames)
    idxs = Int[]
    for tok in split(vars, ",")
        t = strip(tok)
        isempty(t) && continue
        i = tryparse(Int, t)
        if i === nothing
            j = findfirst(==(t), varnames)
            j === nothing && throw(CliError("usage/invalid",
                "unknown variable '$t' (have: $(join(varnames, ", ")))"))
            push!(idxs, j)
        else
            (1 <= i <= n) || throw(CliError("usage/invalid", "variable index $i out of range 1:$n"))
            push!(idxs, i)
        end
    end
    isempty(idxs) && throw(CliError("usage/invalid", "no variables parsed from --vars"))
    # Guard on DISTINCT variables and the cointegrating rank: making `k` variables weakly
    # exogenous leaves `n-k` error-correcting rows, and MEMs needs `n-k ≥ r` (else it throws
    # a bare ArgumentError that would mismap to config/shape — this command takes no config
    # matrix). Dedupe to match MEMs' setdiff-based selection (so `--vars 1,1` == `--vars 1`).
    idxs = unique(idxs)
    (n - length(idxs)) >= vecm.rank || throw(CliError("usage/invalid",
        "weak-exogeneity of $(length(idxs)) variable(s) leaves $(n - length(idxs)) error-correcting equation(s), but cointegrating rank r=$(vecm.rank) needs ≥ r; select fewer variables"))
    _status("VECM weak-exogeneity test: series=$n, rank=$(vecm.rank), vars=$(join([varnames[i] for i in idxs], ","))"); _status()
    res = try
        test_weak_exogeneity(vecm, idxs)
    catch e
        throw(_vecm_restriction_error(e, "weak-exogeneity"))
    end
    _vecm_restriction_output(res, "VECM weak-exogeneity", join([varnames[i] for i in idxs], ","); format=format, output=output)
    return res
end

# ── C069/C070: randomness/nonlinearity + panel stationarity/cointegration ──
# variance-ratio & BDS (univariate); Hadri (panel matrix); Pedroni/Kao/Westerlund
# (panel cointegration). The MEMs teststat calls throw bare, untyped exceptions on
# bad user input (ArgumentError: series too short / bad q / too many regressors;
# DimensionMismatch on shape), so every call is wrapped to a typed CliError via
# `_teststat_error` (standing lesson: never let an untyped exception on user input
# reach the top level as an internal exit-1).

"""Map an untyped MEMs test-statistic failure to a typed CliError (never exit-1)."""
function _teststat_error(e, what::String)
    e isa CliError && return e
    (e isa ArgumentError || e isa DomainError) && return CliError("data/invalid",
        "$what: $(sprint(showerror, e))"; hint="need a longer/cleaner series or a well-formed panel")
    e isa DimensionMismatch && return CliError("data/shape", "$what: $(sprint(showerror, e))")
    return CliError("model/error", "$what failed: $(sprint(showerror, e))")
end

"""Parse a comma-separated list of integers (e.g. horizons "2,4,8,16"). Empty or
non-integer tokens → a typed usage error (never an untyped parse throw)."""
function _parse_int_list(s::AbstractString)
    toks = [strip(t) for t in split(s, ",") if !isempty(strip(t))]
    isempty(toks) && throw(CliError("usage/invalid",
        "expected a comma-separated list of integers, got '$s'"))
    out = Int[]
    for t in toks
        v = tryparse(Int, t)
        v === nothing && throw(CliError("usage/invalid", "invalid integer '$t' in '$s'"))
        push!(out, v)
    end
    return out
end

function _test_variance_ratio(; data::String, column::Int=1, horizons::String="2,4,8,16",
        method::String="lomackinlay", format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    q = _parse_int_list(horizons)
    all(qi -> qi >= 2, q) || throw(CliError("usage/invalid",
        "every horizon q must be ≥ 2 (got $q)"))
    _status("Variance-Ratio Test: variable=$vname, observations=$(length(y)), horizons=$(join(q, ","))"); _status()
    res = try
        variance_ratio_test(y; q=q, method=Symbol(method))
    catch e
        throw(_teststat_error(e, "variance-ratio test"))
    end
    # Per-horizon rows carry the robust (heteroskedasticity-consistent) individual
    # z*-stats, matching the robust=true default. The joint headline is the robust
    # Chow–Denning max|z*| (cd_star_*) — exactly StatsAPI.pvalue(res) when robust=true,
    # so it stays internally consistent with the robust z* above.
    df = DataFrame(horizon=res.q, variance_ratio=round.(Float64.(res.vr); digits=4),
                   z_star=round.(Float64.(res.z_star); digits=4),
                   p_value=round.(Float64.(res.z_star_pvalue); digits=4))
    output_result(df; format=Symbol(format), output=output, title="Variance-Ratio Test: $vname")
    output_kv(Pair{String,Any}[
        "Chow-Denning stat" => round(Float64(res.cd_star_stat); digits=4),
        "Chow-Denning p-value" => round(Float64(res.cd_star_pvalue); digits=4),
        "robust" => res.robust,
        "observations" => res.nobs];
        format=format, title="Joint Random-Walk Test")
    interpret_test_result(Float64(res.cd_star_pvalue),
        "Reject H0 (random walk) at 5% -- variance ratios differ from 1 (mean reversion / momentum)",
        "Cannot reject H0 (random walk) at 5%")
    return res
end

function _test_bds(; data::String, column::Int=1, max_dim::Int=6, eps_frac::Float64=0.7,
        format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    max_dim >= 2 || throw(CliError("usage/invalid", "--max-dim must be ≥ 2 (got $max_dim)"))
    eps_frac > 0 || throw(CliError("usage/invalid", "--eps-frac must be > 0 (got $eps_frac)"))
    _status("BDS Test: variable=$vname, observations=$(length(y)), embedding dims=2..$max_dim"); _status()
    res = try
        bds_test(y; m=2:max_dim, eps_frac=eps_frac)
    catch e
        throw(_teststat_error(e, "BDS test"))
    end
    # res.statistic / res.pvalue are (n_dims × n_eps) matrices; a single scalar
    # --eps-frac ⇒ one ε column, so flatten to per-dimension vectors aligned with res.m.
    df = DataFrame(embed_dim=res.m,
                   statistic=round.(Float64.(vec(res.statistic)); digits=4),
                   p_value=round.(Float64.(vec(res.pvalue)); digits=4))
    output_result(df; format=Symbol(format), output=output, title="BDS Test: $vname")
    interpret_test_result(minimum(Float64.(res.pvalue)),
        "Reject H0 (iid) at 5% -- nonlinear dependence / structure detected",
        "Cannot reject H0 (iid) at 5%")
    return res
end

# ─────────────────────────────────────────────────────────────────────────────
# C069 (remainder): seasonal / point-optimal / bubble / distributional tests and
# the residual-based cointegration battery. Nine flat `test` leaves over MEMs
# `teststat/{hegy,dfgls,bubble,edf,engle_granger,phillips_ouliaris,
# hansen_instability,park_added}.jl`.
#
# Three input shapes, mirroring the upstream signatures exactly:
#   * univariate `(y)`            — hegy, ers, sadf, gsadf, edf
#   * `(y, X)`                    — engle-granger, phillips-ouliaris
#   * a FITTED `CointRegModel`    — hansen-instability, park-added
#
# TREND VOCABULARY TRAP: engle-granger / phillips-ouliaris take
# `:none|:constant|:trend` — NOT cointreg's `none|const|linear` and NOT ARDL's
# `none|const|trend`. hansen-instability / park-added consume a CointRegModel and
# therefore use the COINTREG spelling. Do not share a trend OptionSpec between them.
# ─────────────────────────────────────────────────────────────────────────────

"""Parse a `--lags` that upstream types as `Union{Int,Symbol}`: a named rule
(`auto`/`aic`/`bic`/`tstat`) or a non-negative integer. Junk → typed usage/invalid.
Zero is valid, so this must NOT route through `_parse_bandwidth` (which rejects 0)."""
function _parse_test_lags(s::AbstractString, flag::String, rules::NTuple{N,String}) where {N}
    s in rules && return Symbol(s)
    v = tryparse(Int, s)
    (v === nothing || v < 0) && throw(CliError("usage/invalid",
        "$flag must be one of $(join(rules, "|")) or a non-negative integer, got '$s'"))
    return v
end

"""Parse the HAC `--bandwidth` shared by phillips-ouliaris / park-added: the
Phillips–Ouliaris rule of thumb `nw`, the `lrvar` rules `andrews`/`nw94`, or a
non-negative number. Distinct from `_parse_cointreg_bandwidth`, which has no `nw`."""
function _parse_hac_bandwidth(s::AbstractString)
    s in ("nw", "andrews", "nw94") && return Symbol(s)
    v = tryparse(Float64, s)
    (v === nothing || !isfinite(v) || v < 0) && throw(CliError("usage/invalid",
        "--bandwidth must be nw|andrews|nw94 or a non-negative number, got '$s'"))
    return v
end

"""Render a `Dict{Int,<:Real}` of critical values as sorted `"CV 1%" => x` pairs."""
_cv_pairs(cv) = Pair{String,Any}[
    "CV $(k)%" => round(Float64(cv[k]); digits=4) for k in sort(collect(keys(cv)))]

# HEGY (1990) seasonal unit roots. Rejection is per-frequency, so the headline is a
# frequency-by-frequency table (zero / Nyquist / harmonic pairs), not one p-value.
function _test_hegy(; data::String, column::Int=1, frequency::Int=4,
        deterministic::String="const-trend-seas", lags::String="auto",
        format::String="table", output::String="")
    frequency in (4, 12) || throw(CliError("usage/invalid",
        "test hegy: --frequency must be 4 (quarterly) or 12 (monthly), got $frequency"))
    lg = _parse_test_lags(lags, "--lags", ("auto",))
    y, vname = load_univariate_series(data, column)
    _status("HEGY Seasonal Unit-Root Test: variable=$vname, observations=$(length(y)), frequency=$frequency"); _status()
    res = try
        hegy_test(y; frequency=frequency,
                  deterministic=Symbol(replace(deterministic, '-' => '_')), lags=lg)
    catch e
        throw(_teststat_error(e, "HEGY test"))
    end
    # One row per tested frequency: the zero and Nyquist t-ratios, then the joint F for
    # each complex harmonic pair. HEGY has NO single p-value — rejection is per-frequency
    # against that frequency's own critical values — so render a decision per row and do
    # NOT feed interpret_test_result (same rule as the ARDL bounds test). The t-ratios are
    # left-tailed (reject when t < CV); the pair F statistics are right-tailed.
    cv5(d, fallback) = haskey(d, 5) ? Float64(d[5]) : fallback
    tz_cv, tn_cv, pf_cv = cv5(res.t_zero_cv, NaN), cv5(res.t_nyquist_cv, NaN), cv5(res.pair_F_cv, NaN)
    labels = ["zero (pi_1)", "Nyquist (pi_2)"]
    stats  = Float64[Float64(res.t_zero), Float64(res.t_nyquist)]
    kinds  = ["t", "t"]
    cvs    = Float64[tz_cv, tn_cv]
    decs   = String[_hegy_decision(Float64(res.t_zero), tz_cv, :left),
                    _hegy_decision(Float64(res.t_nyquist), tn_cv, :left)]
    for (i, f) in enumerate(res.pair_freqs)
        push!(labels, "pair at freq $(round(Float64(f); digits=4))")
        push!(stats, Float64(res.pair_F[i]))
        push!(kinds, "F")
        push!(cvs, pf_cv)
        push!(decs, _hegy_decision(Float64(res.pair_F[i]), pf_cv, :right))
    end
    output_result(DataFrame(frequency=labels, kind=kinds,
                            statistic=round.(stats; digits=4),
                            cv_5pct=[isfinite(c) ? round(c; digits=4) : "n/a" for c in cvs],
                            decision=decs);
                  format=Symbol(format), output=output,
                  title="HEGY Seasonal Unit-Root Test: $vname")
    output_kv(Pair{String,Any}[
        "F (seasonal, joint)" => round(Float64(res.F_seasonal); digits=4),
        "F (all roots)" => round(Float64(res.F_all); digits=4),
        "deterministic" => String(res.deterministic),
        "lags" => res.lags,
        "observations" => res.nobs];
        format=format, title="HEGY Summary")
    _status_styled("H0 at each frequency is a unit root; 'reject' means no unit root there.\n";
                   color=:cyan)
    return res
end

"""Decision label for one HEGY frequency at the 5% level. `:left` for the t-ratios
(reject when statistic < CV), `:right` for the pair F statistics. A missing CV renders
`n/a` rather than a bogus verdict."""
function _hegy_decision(stat::Float64, cv::Float64, tail::Symbol)
    isfinite(cv) && isfinite(stat) || return "n/a"
    rejected = tail === :left ? stat < cv : stat > cv
    return rejected ? "reject (no unit root)" : "cannot reject (unit root)"
end

# Elliott-Rothenberg-Stock (1996) feasible point-optimal P_T. SMALL P_T rejects, so
# the decision is read off the reported p-value, not the statistic's sign.
function _test_ers(; data::String, column::Int=1, trend::Bool=false,
        format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)
    _status("ERS Point-Optimal Test: variable=$vname, observations=$(length(y)), regression=$(trend ? "trend" : "constant")"); _status()
    res = try
        ers_test(y; trend=trend)
    catch e
        throw(_teststat_error(e, "ERS point-optimal test"))
    end
    pairs = Pair{String,Any}[
        "P_T statistic" => round(Float64(res.P_T); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "regression" => String(res.regression),
        "observations" => res.nobs,
    ]
    append!(pairs, _cv_pairs(res.critical_values))
    output_kv(pairs; format=format, output=output, title="ERS Point-Optimal Test: $vname")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (unit root) at 5% -- series is stationary",
        "Cannot reject H0 (unit root) at 5%")
    return res
end

"""Shared body for the PSY bubble pair (`sadf`/`gsadf`) — identical options and
rendering, only the upstream entry point and the label differ."""
function _bubble_leaf(fn, label::String; data::String, column::Int, r0::String,
        adflag::Int, mc_reps::Int, cv::String, seed::Int, format::String, output::String)
    adflag >= 0 || throw(CliError("usage/invalid", "test $label: --adflag must be ≥ 0 (got $adflag)"))
    mc_reps >= 1 || throw(CliError("usage/invalid", "test $label: --mc-reps must be ≥ 1 (got $mc_reps)"))
    r0v = if r0 == "auto"
        :auto
    else
        v = tryparse(Float64, r0)
        (v === nothing || !(0.0 < v < 1.0)) && throw(CliError("usage/invalid",
            "test $label: --r0 must be 'auto' or a number in (0,1), got '$r0'"))
        v
    end
    y, vname = load_univariate_series(data, column)
    _status("$(uppercase(label)) Bubble Test: variable=$vname, observations=$(length(y)), cv=$cv"); _status()
    res = try
        fn(y; r0=r0v, adflag=adflag, mc_reps=mc_reps, cv=Symbol(cv), seed=seed)
    catch e
        throw(_teststat_error(e, "$label test"))
    end
    # Date-stamped explosive episodes are the actionable output; empty is a valid answer.
    eps_df = isempty(res.episodes) ?
        DataFrame(episode=Int[], start_index=Int[], end_index=Int[]) :
        DataFrame(episode=collect(1:length(res.episodes)),
                  start_index=[e[1] for e in res.episodes],
                  end_index=[e[2] for e in res.episodes])
    output_result(eps_df; format=Symbol(format), output=output,
                  title="Explosive Episodes ($(uppercase(label))): $vname")
    pairs = Pair{String,Any}[
        "statistic" => round(Float64(res.statistic); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "kind" => String(res.kind),
        "r0" => round(Float64(res.r0); digits=4),
        "adflag" => res.adflag,
        "cv method" => String(res.cv_method),
        "mc reps" => res.mc_reps,
        "episodes" => length(res.episodes),
        "observations" => res.nobs,
    ]
    append!(pairs, _cv_pairs(res.critical_values))
    output_kv(pairs; format=format, title="$(uppercase(label)) Summary")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (unit root) at 5% -- explosive/bubble behaviour detected",
        "Cannot reject H0 (unit root) at 5% -- no evidence of explosive behaviour")
    return res
end

function _test_sadf(; data::String, column::Int=1, r0::String="auto", adflag::Int=0,
        mc_reps::Int=999, cv::String="asymptotic", seed::Int=20240716,
        format::String="table", output::String="")
    return _bubble_leaf(sadf_test, "sadf"; data=data, column=column, r0=r0, adflag=adflag,
        mc_reps=mc_reps, cv=cv, seed=seed, format=format, output=output)
end

function _test_gsadf(; data::String, column::Int=1, r0::String="auto", adflag::Int=0,
        mc_reps::Int=999, cv::String="asymptotic", seed::Int=20240716,
        format::String="table", output::String="")
    return _bubble_leaf(gsadf_test, "gsadf"; data=data, column=column, r0=r0, adflag=adflag,
        mc_reps=mc_reps, cv=cv, seed=seed, format=format, output=output)
end

# Empirical-distribution-function goodness of fit (KS / Lilliefors / Cramer-von Mises /
# Anderson-Darling / Watson). H0 is that the series follows `--dist`.
function _test_edf(; data::String, column::Int=1, dist::String="normal", test::String="ad",
        params::String="estimate", theta::String="", format::String="table", output::String="")
    th = nothing
    if !isempty(theta)
        toks = [strip(t) for t in split(theta, ",") if !isempty(strip(t))]
        isempty(toks) && throw(CliError("usage/invalid", "test edf: --theta is empty"))
        vals = Float64[]
        for t in toks
            v = tryparse(Float64, t)
            (v === nothing || !isfinite(v)) && throw(CliError("usage/invalid",
                "test edf: invalid number '$t' in --theta"))
            push!(vals, v)
        end
        th = vals
    end
    # Upstream spells the supplied-parameter case :specified (NOT :known) — mismatching
    # it reached MEMs as a bare ArgumentError mapped to data/invalid on a valid request.
    params == "specified" && th === nothing && throw(CliError("usage/missing",
        "test edf: --params specified requires --theta"; hint="give the parameters, e.g. --theta 0,1"))
    y, vname = load_univariate_series(data, column)
    _status("EDF Goodness-of-Fit Test: variable=$vname, observations=$(length(y)), dist=$dist, test=$test"); _status()
    res = try
        edf_test(y; dist=Symbol(dist), test=Symbol(test), params=Symbol(params), theta=th)
    catch e
        throw(_teststat_error(e, "EDF test"))
    end
    pairs = Pair{String,Any}[
        "statistic" => round(Float64(res.statistic); digits=4),
        "raw statistic" => round(Float64(res.raw_statistic); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "test" => String(res.test),
        "distribution" => String(res.dist),
        "parameters" => String(res.params),
        "case" => res.case,
        "theta" => join(round.(Float64.(res.theta); digits=4), ", "),
        "observations" => res.nobs,
    ]
    append!(pairs, _cv_pairs(res.critical_values))
    output_kv(pairs; format=format, output=output, title="EDF Test: $vname")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 at 5% -- the series does not follow the $dist distribution",
        "Cannot reject H0 at 5% -- consistent with the $dist distribution")
    return res
end

# Engle-Granger (1987) residual-based cointegration. H0: NO cointegration, so a LOW
# p-value is evidence FOR a cointegrating relationship — the opposite reading from a
# unit-root test on a single series.
function _test_engle_granger(; data::String, dep::String="", trend::String="constant",
        lags::String="aic", max_lags::String="", format::String="table", output::String="")
    lg = _parse_test_lags(lags, "--lags", ("aic", "bic", "tstat"))
    ml = isempty(max_lags) ? nothing : begin
        v = tryparse(Int, max_lags)
        (v === nothing || v < 0) && throw(CliError("usage/invalid",
            "test engle-granger: --max-lags must be a non-negative integer, got '$max_lags'"))
        v
    end
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Engle-Granger Cointegration Test: $dep_name ~ $(join(xcols, " + ")), n=$(length(y))"); _status()
    res = try
        engle_granger_test(y, X; trend=Symbol(trend), lags=lg, max_lags=ml)
    catch e
        throw(_teststat_error(e, "Engle-Granger test"))
    end
    output_kv(Pair{String,Any}[
        "statistic" => round(Float64(res.statistic); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "lags" => res.lags,
        "regression" => String(res.regression),
        "regressors (k)" => res.k,
        "I(1) series (N)" => res.N,
        "observations" => res.nobs];
        format=format, output=output, title="Engle-Granger Test: $dep_name")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (no cointegration) at 5% -- the series are cointegrated",
        "Cannot reject H0 (no cointegration) at 5%")
    return res
end

# Phillips-Ouliaris (1990). Same H0 as Engle-Granger but semiparametric: reports both
# the studentized Z_t and the normalized-bias Z_alpha, each with its own p-value.
function _test_phillips_ouliaris(; data::String, dep::String="", trend::String="constant",
        kernel::String="bartlett", bandwidth::String="nw",
        format::String="table", output::String="")
    bw = _parse_hac_bandwidth(bandwidth)
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Phillips-Ouliaris Cointegration Test: $dep_name ~ $(join(xcols, " + ")), n=$(length(y))"); _status()
    res = try
        phillips_ouliaris_test(y, X; trend=Symbol(trend),
                               kernel=Symbol(replace(kernel, '-' => '_')), bandwidth=bw)
    catch e
        throw(_teststat_error(e, "Phillips-Ouliaris test"))
    end
    output_result(DataFrame(
            statistic=["Z_t", "Z_alpha"],
            value=round.(Float64[res.statistic, res.z_alpha]; digits=4),
            p_value=round.(Float64[res.pvalue, res.z_alpha_pvalue]; digits=4));
        format=Symbol(format), output=output,
        title="Phillips-Ouliaris Test: $dep_name")
    output_kv(Pair{String,Any}[
        "regression" => String(res.regression),
        "kernel" => String(res.kernel),
        "bandwidth" => round(Float64(res.bandwidth); digits=4),
        "regressors (k)" => res.k,
        "I(1) series (N)" => res.N,
        "observations" => res.nobs];
        format=format, title="Phillips-Ouliaris Summary")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (no cointegration) at 5% -- the series are cointegrated",
        "Cannot reject H0 (no cointegration) at 5%")
    return res
end

"""Fit the `CointRegModel` that `hansen_instability_test`/`park_added_test` consume.
Mirrors `_estimate_cointreg`'s call exactly (same COINTREG trend vocabulary
`none|const|linear`), so the two diagnostics describe the same regression the user
would get from `estimate cointreg`."""
function _cointreg_for_test(data::String, dep::String, method::String, trend::String,
                            kernel::String, bandwidth::String, leads::String, lags::String,
                            label::String)
    y, X, xcols = _load_reg_data(data, dep)
    bw = _parse_cointreg_bandwidth(bandwidth)
    model = try
        estimate_cointreg(y, X; method=Symbol(method), trend=Symbol(trend),
            kernel=Symbol(replace(kernel, '-' => '_')), bandwidth=bw,
            leads=_parse_cointreg_leadlag(leads, "--leads"),
            lags=_parse_cointreg_leadlag(lags, "--lags"))
    catch e
        throw(_teststat_error(e, "$label (cointegrating regression fit)"))
    end
    return model, xcols
end

# Hansen (1992) L_c parameter-instability test. H0 here is COINTEGRATION WITH STABLE
# coefficients, so a large L_c / low p-value rejects stability — note this is the
# reverse of the Engle-Granger/Phillips-Ouliaris null.
function _test_hansen_instability(; data::String, dep::String="", method::String="fmols",
        trend::String="const", kernel::String="bartlett", bandwidth::String="andrews",
        leads::String="auto", lags::String="auto", format::String="table", output::String="")
    model, xcols = _cointreg_for_test(data, dep, method, trend, kernel, bandwidth,
                                      leads, lags, "hansen-instability")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Hansen (1992) Instability Test: $dep_name ~ $(join(xcols, " + ")), method=$method"); _status()
    res = try
        hansen_instability_test(model)
    catch e
        throw(_teststat_error(e, "Hansen instability test"))
    end
    output_kv(Pair{String,Any}[
        "L_c statistic" => round(Float64(res.statistic); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "regression" => String(res.regression),
        "trend" => String(res.trend),
        "parameters" => res.nparam,
        "regressors (k)" => res.k,
        "observations" => res.nobs];
        format=format, output=output, title="Hansen Instability Test: $dep_name")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (stable cointegration) at 5% -- parameter instability / no stable cointegrating vector",
        "Cannot reject H0 (stable cointegration) at 5%")
    return res
end

# Park (1990) H(p,q) added-superfluous-trends test. H0: genuine cointegration; a large
# Wald statistic rejects in favour of a spurious regression.
function _test_park_added(; data::String, dep::String="", method::String="fmols",
        trend::String="const", kernel::String="bartlett", bandwidth::String="andrews",
        leads::String="auto", lags::String="auto", q_add::Int=2,
        hac_kernel::String="bartlett", hac_bandwidth::String="nw",
        format::String="table", output::String="")
    q_add >= 1 || throw(CliError("usage/invalid", "test park-added: --q-add must be ≥ 1 (got $q_add)"))
    hac_bw = _parse_hac_bandwidth(hac_bandwidth)
    model, xcols = _cointreg_for_test(data, dep, method, trend, kernel, bandwidth,
                                      leads, lags, "park-added")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Park (1990) Added-Variables Test: $dep_name ~ $(join(xcols, " + ")), q_add=$q_add"); _status()
    res = try
        park_added_test(model; q_add=q_add,
                        kernel=Symbol(replace(hac_kernel, '-' => '_')), bandwidth=hac_bw)
    catch e
        throw(_teststat_error(e, "Park added-variables test"))
    end
    output_kv(Pair{String,Any}[
        "H(p,q) statistic" => round(Float64(res.statistic); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "q_add (df)" => res.q_add,
        "base trend order (p)" => res.base_order,
        "regression" => String(res.regression),
        "trend" => String(res.trend),
        "regressors (k)" => res.k,
        "observations" => res.nobs];
        format=format, output=output, title="Park Added-Variables Test: $dep_name")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (genuine cointegration) at 5% -- evidence of a spurious regression",
        "Cannot reject H0 (genuine cointegration) at 5%")
    return res
end

# ─────────────────────────────────────────────────────────────────────────────
# C067 (remainder, #72): OLS regression diagnostics — heteroskedasticity,
# parameter stability and influence. Eight flat `test` leaves over MEMs
# `reg/{diagnostics,stability}.jl`.
#
# All eight fit a cross-section OLS via `_load_reg_data` + `estimate_reg` (X =
# every numeric column except --dep, NO intercept prepended — include a `const`
# column, exactly like `estimate reg`), then run the diagnostic on the fitted
# RegModel. NOTE the existing `test breusch-pagan` is the PANEL random-effects LM
# test (`_load_panel_for_preg` + estimate_xtreg); these are the CROSS-SECTION
# diagnostics and deliberately do NOT share its loader.
#
# Three result shapes:
#   * RegDiagnosticResult — white, glejser, harvey, chow  (statistic + p-value)
#   * StabilityResult     — cusum, cusumsq  (a BAND PATH with NO p-value)
#   * InfluenceStats / Vector — influence, recursive-residuals (per-observation)
# ─────────────────────────────────────────────────────────────────────────────

"""Round for display, but render a non-finite value as a string — the legacy
`FRIEDMAN_LEGACY_OUTPUT=1 -f json` writer historically choked on raw Inf/NaN, and a
string is honest either way. (`_test_weak_instrument` has its own local `_fnum`.)"""
_finite_or_str(x) = isfinite(x) ? round(Float64(x); digits=6) : string(Float64(x))

"""Fit the cross-section OLS that the `reg` diagnostics consume. Mirrors
`estimate reg` (same `_load_reg_data` partition and `--cov-type`), so the diagnostic
describes the regression the user would get from that command."""
function _reg_for_diagnostic(data::String, dep::String, cov_type::String, label::String)
    y, X, xcols = _load_reg_data(data, dep)
    model = try
        estimate_reg(y, X; cov_type=Symbol(cov_type), varnames=xcols)
    catch e
        throw(_teststat_error(e, "$label (OLS fit)"))
    end
    return model, xcols
end

"""Render a `RegDiagnosticResult` as a kv block. `df` is an Int or an (Int,Int)
tuple depending on the test, and the F-form fields are `nothing` for the chi-square-
only tests — both are handled here so each leaf stays a few lines."""
function _reg_diagnostic_kv(res, title::String, format::String, output::String)
    pairs = Pair{String,Any}[
        "test" => res.test_name,
        "H0" => res.h0,
        "statistic" => _finite_or_str(Float64(res.statistic)),
        "p-value" => _finite_or_str(Float64(res.pvalue)),
        "df" => res.df isa Tuple ? join(res.df, ", ") : res.df,
    ]
    if res.f_stat !== nothing
        push!(pairs, "F statistic" => _finite_or_str(Float64(res.f_stat)))
        res.f_pvalue === nothing || push!(pairs, "F p-value" => _finite_or_str(Float64(res.f_pvalue)))
        res.f_df === nothing || push!(pairs, "F df" => join(res.f_df, ", "))
    end
    push!(pairs, "auxiliary R2" => _finite_or_str(Float64(res.aux_r2)))
    push!(pairs, "observations" => res.n)
    output_kv(pairs; format=format, output=output, title=title)
    return nothing
end

function _test_white(; data::String, dep::String="", cov_type::String="hc1",
        no_cross_terms::Bool=false, format::String="table", output::String="")
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, "white")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("White Heteroskedasticity Test: $dep_name ~ $(join(xcols, " + "))"); _status()
    res = try
        white_test(model; cross_terms=!no_cross_terms)
    catch e
        throw(_teststat_error(e, "White test"))
    end
    _reg_diagnostic_kv(res, "White Test: $dep_name", format, output)
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (homoskedasticity) at 5% -- errors are heteroskedastic (use a robust --cov-type)",
        "Cannot reject H0 (homoskedasticity) at 5%")
    return res
end

function _test_glejser(; data::String, dep::String="", cov_type::String="hc1",
        format::String="table", output::String="")
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, "glejser")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Glejser Heteroskedasticity Test: $dep_name ~ $(join(xcols, " + "))"); _status()
    res = try
        glejser_test(model)
    catch e
        throw(_teststat_error(e, "Glejser test"))
    end
    _reg_diagnostic_kv(res, "Glejser Test: $dep_name", format, output)
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (homoskedasticity) at 5% -- errors are heteroskedastic",
        "Cannot reject H0 (homoskedasticity) at 5%")
    return res
end

function _test_harvey(; data::String, dep::String="", cov_type::String="hc1",
        format::String="table", output::String="")
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, "harvey")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Harvey Heteroskedasticity Test: $dep_name ~ $(join(xcols, " + "))"); _status()
    res = try
        harvey_test(model)
    catch e
        throw(_teststat_error(e, "Harvey test"))
    end
    _reg_diagnostic_kv(res, "Harvey Test: $dep_name", format, output)
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (homoskedasticity) at 5% -- multiplicative heteroskedasticity detected",
        "Cannot reject H0 (homoskedasticity) at 5%")
    return res
end

# Chow (1960). `--break` is REQUIRED (a comma-separated list gives a multi-break
# test); upstream needs every index in 1:n-1 and, for :breakpoint, each segment to
# hold at least k observations — :forecast is the fallback for a short segment.
function _test_chow(; data::String, dep::String="", cov_type::String="hc1",
        break_at::String="", type::String="breakpoint", level::Float64=0.05,
        format::String="table", output::String="")
    # NOTE the option is --break-at, not --break: `break` is a Julia reserved word and
    # cannot be a handler kwarg (the registry binds --multi-word to multi_word).
    isempty(break_at) && throw(CliError("usage/missing",
        "test chow: --break-at is required";
        hint="give the 1-based observation index of the break, e.g. --break-at 50"))
    breaks = _parse_int_list(break_at)
    all(b -> b >= 1, breaks) || throw(CliError("usage/invalid",
        "test chow: every --break-at index must be ≥ 1 (got $breaks)"))
    (0.0 < level < 1.0) || throw(CliError("usage/invalid",
        "test chow: --level must be in (0, 1) (got $level)"))
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, "chow")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Chow Structural-Break Test: $dep_name ~ $(join(xcols, " + ")), breaks=$(join(breaks, ","))"); _status()
    res = try
        chow_test(model, breaks; type=Symbol(type), level=level)
    catch e
        throw(_teststat_error(e, "Chow test"))
    end
    _reg_diagnostic_kv(res, "Chow Test: $dep_name", format, output)
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (no structural break) at 5% -- coefficients differ across the break",
        "Cannot reject H0 (no structural break) at 5%")
    return res
end

"""Shared body for the CUSUM pair. `StabilityResult` carries a PATH and a
significance band, NOT a p-value — the verdict is whether the path crosses the band,
so these leaves render a decision and never call `interpret_test_result` (same rule
as the ARDL bounds test and HEGY)."""
function _cusum_leaf(fn, label::String, statcol::String; data::String, dep::String,
        cov_type::String, level::Float64, format::String, output::String)
    (0.0 < level < 1.0) || throw(CliError("usage/invalid",
        "test $label: --level must be in (0, 1) (got $level)"))
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, label)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("$(uppercase(label)) Stability Test: $dep_name ~ $(join(xcols, " + "))"); _status()
    res = try
        fn(model; level=level)
    catch e
        throw(_teststat_error(e, "$label test"))
    end
    # ALL-Pair construction: the statistic column name is dynamic, and DataFrame does
    # not accept a Pair alongside keyword columns (that combination is an exit-1
    # MethodError, not a nice error).
    output_result(DataFrame(
            "observation" => res.tindex,
            statcol => round.(Float64.(res.stat_path); digits=6),
            "lower" => round.(Float64.(res.lower); digits=6),
            "upper" => round.(Float64.(res.upper); digits=6));
        format=Symbol(format), output=output,
        title="$(uppercase(label)) Path: $dep_name")
    output_kv(Pair{String,Any}[
        "kind" => String(res.kind),
        "crossed band" => res.crossed,
        "first crossing" => res.first_crossing === nothing ? "none" : res.first_crossing,
        "level" => res.level,
        "observations" => res.n,
        "regressors (k)" => res.k];
        format=format, title="$(uppercase(label)) Summary")
    # H0 is parameter stability; there is no p-value, so the band crossing IS the verdict.
    if res.crossed
        _status_styled("-> Path leaves the $(round(Int, 100*(1-res.level)))% band at observation $(res.first_crossing) -- parameter instability\n"; color=:yellow)
    else
        _status_styled("-> Path stays inside the $(round(Int, 100*(1-res.level)))% band -- no evidence of instability\n"; color=:green)
    end
    return res
end

function _test_cusum(; data::String, dep::String="", cov_type::String="hc1",
        level::Float64=0.05, format::String="table", output::String="")
    return _cusum_leaf(cusum_test, "cusum", "cusum"; data=data, dep=dep,
        cov_type=cov_type, level=level, format=format, output=output)
end

function _test_cusumsq(; data::String, dep::String="", cov_type::String="hc1",
        level::Float64=0.05, format::String="table", output::String="")
    return _cusum_leaf(cusumsq_test, "cusumsq", "cusumsq"; data=data, dep=dep,
        cov_type=cov_type, level=level, format=format, output=output)
end

# Brown-Durbin-Evans recursive least-squares residuals — a plain Vector, one value
# per recursive step (the first k observations initialise the recursion).
function _test_recursive_residuals(; data::String, dep::String="", cov_type::String="hc1",
        format::String="table", output::String="")
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, "recursive-residuals")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Recursive Residuals: $dep_name ~ $(join(xcols, " + "))"); _status()
    w = try
        recursive_residuals(model)
    catch e
        throw(_teststat_error(e, "recursive residuals"))
    end
    wv = Float64.(collect(w))
    k = size(model.X, 2)
    output_result(DataFrame(step=collect(1:length(wv)),
                            observation=collect((k + 1):(k + length(wv))),
                            recursive_residual=round.(wv; digits=6));
        format=Symbol(format), output=output,
        title="Recursive Residuals: $dep_name")
    output_kv(Pair{String,Any}[
        "count" => length(wv),
        "mean" => _finite_or_str(isempty(wv) ? NaN : sum(wv) / length(wv)),
        "regressors (k)" => k];
        format=format, title="Recursive Residuals Summary")
    return w
end

# Per-observation influence diagnostics. `dfbetas` is an n×k MATRIX and is
# deliberately omitted from the tidy per-observation table (it would need one column
# per regressor); the flagged index lists are the actionable output.
function _test_influence(; data::String, dep::String="", cov_type::String="hc1",
        format::String="table", output::String="")
    model, xcols = _reg_for_diagnostic(data, dep, cov_type, "influence")
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("Influence Diagnostics: $dep_name ~ $(join(xcols, " + "))"); _status()
    res = try
        influence_stats(model)
    catch e
        throw(_teststat_error(e, "influence statistics"))
    end
    output_result(DataFrame(
            observation = collect(1:res.n),
            hat = round.(Float64.(res.hat); digits=6),
            student_internal = round.(Float64.(res.student_internal); digits=6),
            student_external = round.(Float64.(res.student_external); digits=6),
            dffits = round.(Float64.(res.dffits); digits=6),
            cooksd = round.(Float64.(res.cooksd); digits=6));
        format=Symbol(format), output=output,
        title="Influence Diagnostics: $dep_name")
    output_kv(Pair{String,Any}[
        "sigma" => _finite_or_str(Float64(res.sigma)),
        "high-leverage count" => length(res.high_leverage),
        "high-leverage obs" => isempty(res.high_leverage) ? "none" : join(res.high_leverage, ", "),
        "influential count" => length(res.influential),
        "influential obs" => isempty(res.influential) ? "none" : join(res.influential, ", "),
        "observations" => res.n,
        "regressors (k)" => res.k];
        format=format, title="Influence Summary")
    return res
end

# C065a: Hansen (1996) linearity test. Per the locked design decision, DO NOT rebuild the
# SETAR design in-handler — fit `estimate_setar(y, p, d; linearity=true, ...)` and read the
# attached `HansenLinearityTest` (`.linearity`); identical numbers, far less code. Every
# option is guarded up-front → usage/invalid; the fit is try-wrapped → typed CliError via the
# shared `_nonlinear_error` (a too-short series surfaces there as data/invalid, never exit-1).
function _test_hansen_linearity(; data::String, column::Int=1, p::Int=1, d::Int=1,
        trim::Float64=0.15, reps::Int=1000, format::String="table", output::String="")
    p >= 1 || throw(CliError("usage/invalid", "test hansen-linearity: --p must be ≥ 1 (got $p)"))
    d >= 1 || throw(CliError("usage/invalid", "test hansen-linearity: --d must be ≥ 1 (got $d)"))
    (0.0 < trim < 0.5) || throw(CliError("usage/invalid",
        "test hansen-linearity: --trim must be in (0, 0.5) (got $trim)"))
    reps >= 1 || throw(CliError("usage/invalid", "test hansen-linearity: --reps must be ≥ 1 (got $reps)"))
    y, vname = load_univariate_series(data, column)
    _status("Hansen (1996) Linearity Test: variable=$vname, observations=$(length(y)), SETAR(p=$p, d=$d), reps=$reps"); _status()
    model = try
        estimate_setar(y, p, d; linearity=true, reps=reps, trim=trim)
    catch e
        throw(_nonlinear_error(e, "Hansen linearity test"))
    end
    res = model.linearity
    res === nothing && throw(CliError("model/error",
        "Hansen linearity test: the SETAR fit did not attach a linearity test result"))
    output_kv(Pair{String,Any}[
        "sup_lm"      => round(Float64(res.sup_lm); digits=4),
        "pvalue_lm"   => round(Float64(res.pvalue_lm); digits=4),
        "sup_wald"    => round(Float64(res.sup_wald); digits=4),
        "pvalue_wald" => round(Float64(res.pvalue_wald); digits=4),
        "gamma_sup"   => round(Float64(res.gamma_sup); digits=6),
        "reps"        => res.reps,
        "trim"        => round(Float64(res.trim); digits=4),
        "n_grid"      => res.n_grid,
    ]; format=format, output=output, title="Hansen (1996) Linearity Test: $vname")
    interpret_test_result(Float64(res.pvalue_lm),
        "Reject H0 (linearity) at 5% -- evidence of two-regime threshold nonlinearity",
        "Cannot reject H0 (linearity) at 5%")
    return res
end

# C065b: STAR (smooth-transition) linearity test. Wraps `star_linearity_test` — the LSTV
# LM3 auxiliary regression (χ² and F forms) → a NamedTuple `(stat, pvalue, fstat, fpvalue,
# df)`, rendered as pure kv. Options are guarded up-front → usage/invalid; the optional
# external transition series gets the same length/constant guards as `estimate star`; the
# test call is try-wrapped → typed CliError via the shared `_nonlinear_error` (never exit-1).
function _test_star_linearity(; data::String, column::Int=1, p::Int=1, d::Int=1,
        transition_col::Int=0, format::String="table", output::String="")
    p >= 1 || throw(CliError("usage/invalid", "test star-linearity: --p must be ≥ 1 (got $p)"))
    d >= 1 || throw(CliError("usage/invalid", "test star-linearity: --d must be ≥ 1 (got $d)"))
    y, vname = load_univariate_series(data, column)
    s = nothing
    if transition_col > 0
        s, _ = load_univariate_series(data, transition_col)
        length(s) == length(y) || throw(CliError("data/shape",
            "test star-linearity: transition variable (column $transition_col) has length $(length(s)), " *
            "but the series has length $(length(y))"))
        std(s) > 0 || throw(CliError("data/invalid",
            "test star-linearity: transition variable (column $transition_col) is constant"))
    end
    _status("STAR Linearity Test (LM3): variable=$vname, observations=$(length(y)), p=$p, d=$d" *
            (transition_col > 0 ? ", external transition col=$transition_col" : ", self-exciting")); _status()
    res = try
        star_linearity_test(y, p; s=s, d=d)
    catch e
        throw(_nonlinear_error(e, "STAR linearity test"))
    end
    output_kv(Pair{String,Any}[
        "stat"     => round(Float64(res.stat); digits=4),
        "pvalue"   => round(Float64(res.pvalue); digits=4),
        "fstat"    => round(Float64(res.fstat); digits=4),
        "fpvalue"  => round(Float64(res.fpvalue); digits=4),
        "df"       => res.df,
    ]; format=format, output=output, title="STAR Linearity Test (LM3): $vname")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (linearity) at 5% -- evidence of smooth-transition nonlinearity",
        "Cannot reject H0 (linearity) at 5%")
    return res
end

function _test_hadri(; data::String, deterministic::String="constant",
        format::String="table", output::String="")
    Y, varnames = load_multivariate_data(data)
    deterministic in ("constant", "trend") || throw(CliError("usage/invalid",
        "--deterministic must be constant|trend (got '$deterministic')"))
    _status("Hadri Panel Stationarity Test: units=$(size(Y,2)), observations=$(size(Y,1)), deterministic=$deterministic"); _status()
    res = try
        hadri_test(Y; deterministic=Symbol(deterministic))
    catch e
        throw(_teststat_error(e, "Hadri test"))
    end
    output_kv(Pair{String,Any}[
        "statistic" => round(Float64(res.statistic); digits=4),
        "p-value" => round(Float64(res.pvalue); digits=4),
        "n_units" => res.n_units,
        "observations" => res.nobs];
        format=format, output=output, title="Hadri Panel Stationarity Test")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (all panels stationary) at 5% -- at least one unit has a unit root",
        "Cannot reject H0 (all panels stationary) at 5%")
    return res
end

"""Load a panel + resolve --dep/--indep to Symbols for the panel-cointegration
trio (Pedroni/Kao/Westerlund). id/time default to the first/second DATA column
(mirrors `_load_panel_for_preg`)."""
function _panel_coint_inputs(data, id_col, time_col, dep, indep)
    cols = names(load_data(data))
    length(cols) >= 3 || throw(CliError("usage/invalid",
        "panel cointegration needs id, time, and variable column(s) (found $(length(cols)))"))
    id = isempty(id_col) ? cols[1] : id_col
    tc = isempty(time_col) ? cols[2] : time_col
    pd = load_panel_data(data, id, tc)          # typed: data/missing-column (bad id/time),
                                                # data/invalid (no numeric vars / duplicate (id,time) pairs)
    vars = pd.varnames                          # numeric cols minus id/time (non-empty — load_panel_data guards)
    depc = isempty(dep) ? vars[1] : dep
    depc in vars || throw(CliError("usage/invalid",
        "--dep '$depc' is not a panel variable (have: $(join(vars, ", ")))"))
    indeps = isempty(indep) ? filter(!=(depc), vars) : _parse_varlist(indep)
    isempty(indeps) && throw(CliError("usage/invalid", "need at least one regressor via --indep"))
    for v in indeps
        v in vars || throw(CliError("usage/invalid",
            "--indep '$v' is not a panel variable (have: $(join(vars, ", ")))"))
    end
    return pd, Symbol(depc), Symbol.(indeps), depc, indeps
end

"""Render a Pedroni/Kao/Westerlund result: statistic|value|p_value table + metadata
kv (all three share the `.names`/`.statistics`/`.pvalues`/`.n_units`/`.n_regressors`/
`.nobs` output triple). H0 = no cointegration; any p-value < 0.05 rejects."""
function _panel_coint_output(res, label, depc, indeps; format, output)
    df = DataFrame(statistic=String.(res.names),
                   value=round.(Float64.(res.statistics); digits=4),
                   p_value=round.(Float64.(res.pvalues); digits=4))
    output_result(df; format=Symbol(format), output=output,
                  title="$label: $depc ~ $(join(indeps, " + "))")
    output_kv(Pair{String,Any}[
        "n_units" => res.n_units,
        "n_regressors" => res.n_regressors,
        "observations" => res.nobs];
        format=format, title="$label Summary")
    interpret_test_result(minimum(Float64.(res.pvalues)),
        "Reject H0 (no cointegration) at 5% -- evidence of panel cointegration",
        "Cannot reject H0 (no cointegration) at 5%")
end

function _test_pedroni(; data::String, id_col::String="", time_col::String="",
        dep::String="", indep::String="", trend::String="constant",
        format::String="table", output::String="")
    trend in ("constant", "trend") || throw(CliError("usage/invalid",
        "--trend must be constant|trend (got '$trend')"))
    pd, depsym, indepsyms, depc, indeps = _panel_coint_inputs(data, id_col, time_col, dep, indep)
    _status("Pedroni Panel Cointegration Test: $depc ~ $(join(indeps, " + ")), units=$(pd.n_groups)"); _status()
    res = try
        pedroni_test(pd, depsym, indepsyms...; trend=Symbol(trend))
    catch e
        throw(_teststat_error(e, "Pedroni test"))
    end
    _panel_coint_output(res, "Pedroni cointegration", depc, indeps; format=format, output=output)
    return res
end

function _test_kao(; data::String, id_col::String="", time_col::String="",
        dep::String="", indep::String="", format::String="table", output::String="")
    pd, depsym, indepsyms, depc, indeps = _panel_coint_inputs(data, id_col, time_col, dep, indep)
    _status("Kao Panel Cointegration Test: $depc ~ $(join(indeps, " + ")), units=$(pd.n_groups)"); _status()
    res = try
        kao_test(pd, depsym, indepsyms...)
    catch e
        throw(_teststat_error(e, "Kao test"))
    end
    _panel_coint_output(res, "Kao cointegration", depc, indeps; format=format, output=output)
    return res
end

function _test_westerlund(; data::String, id_col::String="", time_col::String="",
        dep::String="", indep::String="", trend::String="constant",
        format::String="table", output::String="")
    trend in ("constant", "trend") || throw(CliError("usage/invalid",
        "--trend must be constant|trend (got '$trend')"))
    pd, depsym, indepsyms, depc, indeps = _panel_coint_inputs(data, id_col, time_col, dep, indep)
    _status("Westerlund Panel Cointegration Test: $depc ~ $(join(indeps, " + ")), units=$(pd.n_groups)"); _status()
    res = try
        westerlund_test(pd, depsym, indepsyms...; trend=Symbol(trend))
    catch e
        throw(_teststat_error(e, "Westerlund test"))
    end
    _panel_coint_output(res, "Westerlund cointegration", depc, indeps; format=format, output=output)
    return res
end

# ── C062b: ARDL bounds test + NARDL symmetry Wald tests ──────────────
# Both fit a single-equation (N)ARDL via the shared `_load_reg_data` + `_fit_ardl`/`_fit_nardl`
# helpers (estimate.jl) then run the test. `ARDLBoundsTest`/`NARDLSymmetryTest` are NOT
# CLI-registered test types → hand-built rendering. The bounds test has NO p-value: it is
# compared ONLY to the tabulated I(0)/I(1) bounds, so we render decision symbols + the
# bracketing bounds and NEVER feed `interpret_test_result` (that would require a p-value).

"""Map a bounds/symmetry MEMs failure to a typed CliError (never exit-1). Enums/case/level are
pre-guarded up front → usage/invalid, so this only sees genuine data/model faults."""
_ardl_test_error(e, what::String) = _teststat_error(e, what)

const _ARDL_BOUNDS_LEVELS = [0.10, 0.05, 0.025, 0.01]

function _test_ardl_bounds(; data::String, dep::String="", p::String="auto", q::String="auto",
        max_p::Int=4, max_q::Int=4, ic::String="aic", trend::String="none", case::Int=3,
        level::Float64=0.05, cv_source::String="pss", format::String="table", output::String="")
    # Up-front usage guards (before any fit) so bad knobs → exit 2, never a wrapped data error.
    (1 <= case <= 5) || throw(CliError("usage/invalid", "test ardl-bounds: --case must be in 1:5, got $case"))
    any(x -> isapprox(x, level), _ARDL_BOUNDS_LEVELS) || throw(CliError("usage/invalid",
        "test ardl-bounds: --level must be one of 0.10|0.05|0.025|0.01, got $level"))
    cv_source == "pss" || throw(CliError("usage/invalid",
        "test ardl-bounds: --cv-source must be pss (narayan finite-sample bounds are not bundled), got '$cv_source'"))
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("ARDL bounds test (PSS 2001, case $case, level $level): $dep_name ~ $(join(xcols, " + ")), n=$(length(y))"); _status()
    m = _fit_ardl(y, X, xcols, dep_name; p=p, q=q, max_p=max_p, max_q=max_q,
                  ic=ic, case=case, trend=trend, label="test ardl-bounds")
    res = try
        bounds_test(m; case=case, level=level, cv_source=:pss)
    catch e
        throw(_ardl_test_error(e, "ARDL bounds test"))
    end
    li = findfirst(x -> isapprox(x, res.level), res.levels)
    li === nothing && (li = 2)   # fall back to the 5% row (levels are the fixed PSS grid)
    # Bounds table at the decision level: t-bounds are NaN for cases II/IV → "undefined".
    _fb(x) = isnan(x) ? "undefined" : round(Float64(x); digits=4)
    df = DataFrame(bound=String["F", "t"],
                   statistic=round.(Float64[res.fstat, res.tstat]; digits=4),
                   i0_lower=[_fb(res.f_lower[li]), _fb(res.t_lower[li])],
                   i1_upper=[_fb(res.f_upper[li]), _fb(res.t_upper[li])],
                   decision=String[String(res.f_decision), String(res.t_decision)])
    output_result(df; format=Symbol(format), output=output,
                  title="ARDL Bounds Test (I(0)/I(1) bounds; NO p-value)")
    output_kv(Pair{String,Any}[
        "f_stat"     => round(Float64(res.fstat); digits=4),
        "t_stat"     => round(Float64(res.tstat); digits=4),
        "k"          => res.k,
        "case"       => res.case,
        "cv_source"  => String(res.cv_source),
        "level"      => res.level,
        "f_decision" => String(res.f_decision),
        "t_decision" => String(res.t_decision),
        "nobs"       => res.n,
    ]; format=format, title="ARDL Bounds Test Summary")
    # Decision text keyed off the SYMBOLS (not a p-value): F-bound is the primary conclusion.
    _status()
    fmsg = res.f_decision === :cointegrated ?
               "F-bound: evidence of a level (cointegrating) relationship (F above the I(1) bound)" :
           res.f_decision === :not_cointegrated ?
               "F-bound: no level relationship (F below the I(0) bound)" :
               "F-bound: inconclusive — F falls inside the I(0)/I(1) band"
    _status_styled("-> $fmsg\n"; color=(res.f_decision === :inconclusive ? :yellow : :green))
    return res
end

"""Render a `NARDLSymmetryTest` as a tidy multi-row table (one row per asymmetric regressor):
`regressor|theta_pos|theta_neg|lr_stat|lr_p_chi2|lr_p_f|sr_stat|sr_p_chi2|sr_p_f`."""
function _nardl_symmetry_table(res)
    return DataFrame(
        regressor = String.(res.reg_names),
        theta_pos = round.(Float64.(res.theta_pos); digits=6),
        theta_neg = round.(Float64.(res.theta_neg); digits=6),
        lr_stat   = round.(Float64.(res.lr_stat); digits=4),
        lr_p_chi2 = round.(Float64.(res.lr_p_chi2); digits=4),
        lr_p_f    = round.(Float64.(res.lr_p_f); digits=4),
        sr_stat   = round.(Float64.(res.sr_stat); digits=4),
        sr_p_chi2 = round.(Float64.(res.sr_p_chi2); digits=4),
        sr_p_f    = round.(Float64.(res.sr_p_f); digits=4),
    )
end

function _test_nardl_symmetry(; data::String, dep::String="", asymmetric::String="all",
        p::String="auto", q::String="auto", max_p::Int=4, max_q::Int=4, ic::String="aic",
        case::Int=3, format::String="table", output::String="")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep
    _status("NARDL symmetry Wald tests: $dep_name ~ $(join(xcols, " + ")) (asym=$asymmetric, case=$case), n=$(length(y))"); _status()
    m = _fit_nardl(y, X, xcols, dep_name; asymmetric=asymmetric, p=p, q=q,
                   max_p=max_p, max_q=max_q, ic=ic, case=case, label="test nardl-symmetry")
    res = try
        symmetry_test(m)
    catch e
        throw(_ardl_test_error(e, "NARDL symmetry test"))
    end
    output_result(_nardl_symmetry_table(res); format=Symbol(format), output=output,
                  title="NARDL Symmetry Tests (H0: θ⁺=θ⁻ long-run / Σπ⁺=Σπ⁻ short-run)")
    output_kv(Pair{String,Any}[
        "df"        => res.df,
        "dof_resid" => res.dof_resid,
        "n_asym"    => length(res.reg_names),
    ]; format=format, title="NARDL Symmetry Test Summary")
    # χ²(1) p-values ARE available — interpret the long-run test on the first regressor.
    isempty(res.reg_names) || interpret_test_result(Float64(res.lr_p_chi2[1]),
        "Reject H0 (long-run symmetry) at 5% for $(res.reg_names[1]) -- asymmetric adjustment",
        "Cannot reject H0 (long-run symmetry) at 5% for $(res.reg_names[1])")
    return res
end

# ── C062c: PMG Hausman selection test (PMG/DFE-vs-MG) ─────────────────────────
# `test pmg-hausman` fits the SAME panel TWICE — the estimator efficient under H0 (PMG or DFE)
# and the always-consistent Mean Group — then runs the PMG-typed `hausman_test(::PMGModel,
# ::PMGModel)` on the common long-run θ (the (PMGModel,PMGModel) dispatch, distinct from the
# generic FE-vs-RE hausman). H0 = long-run homogeneity: failing to reject supports the pooled
# (PMG) long-run vector. Result is a standard `PanelTestResult` (HAS a p-value) → the usual
# test kv + `interpret_test_result`, exactly the pedroni/kao/westerlund pattern. Every MEMs
# call is wrapped → typed CliError (single-unit panel etc. → data/invalid, never exit-1).
function _test_pmg_hausman(; data::String, id_col::String="", time_col::String="",
        dep::String="", indep::String="", trend::String="constant", p::Int=1, q::Int=1,
        maxiter::Int=100, tol::Float64=1e-8, efficient::String="pmg",
        format::String="table", output::String="")
    p >= 1 || throw(CliError("usage/invalid", "--p must be ≥ 1, got $p"))
    q >= 0 || throw(CliError("usage/invalid", "--q must be ≥ 0, got $q"))
    pd, depsym, indepsyms, depc, indeps = _load_panel_reg(data, id_col, time_col, dep, indep)
    _status("PMG Hausman Test ($(uppercase(efficient)) vs MG): $depc ~ $(join(indeps, " + ")), units=$(pd.n_groups)"); _status()
    eff = try
        estimate_pmg(pd, depsym, indepsyms...; method=Symbol(efficient), p=p, q=q,
                     trend=Symbol(trend), maxiter=maxiter, tol=tol)
    catch e
        throw(_teststat_error(e, "PMG Hausman ($efficient) fit"))
    end
    cons = try
        estimate_pmg(pd, depsym, indepsyms...; method=:mg, p=p, q=q,
                     trend=Symbol(trend), maxiter=maxiter, tol=tol)
    catch e
        throw(_teststat_error(e, "PMG Hausman (MG) fit"))
    end
    res = try
        hausman_test(eff, cons)
    catch e
        throw(_teststat_error(e, "PMG Hausman test"))
    end
    output_kv(Pair{String,Any}[
        "test_name"   => res.test_name,
        "statistic"   => round(Float64(res.statistic); digits=4),
        "pvalue"      => round(Float64(res.pvalue); digits=4),
        "df"          => res.df,
        "description" => res.description,
    ]; format=format, output=output, title="PMG Hausman Specification Test")
    interpret_test_result(Float64(res.pvalue),
        "Reject H0 (long-run homogeneity) -- PMG inconsistent, prefer MG",
        "Cannot reject H0 -- PMG long-run homogeneity supported")
    return res
end

# ── VAR Lag Selection ────────────────────────────────────

function _test_var_lagselect(; data::String, max_lags::Int=12, criterion::String="aic",
                               format::String="table", output::String="")
    Y, _ = load_multivariate_data(data)
    n = size(Y, 2)

    max_p = min(max_lags, size(Y,1) ÷ (3*n))
    crit_sym = Symbol(lowercase(criterion))

    _status("Lag order selection (max lags: $max_p, criterion: $criterion)")
    _status()

    results = []
    for p in 1:max_p
        try
            m = estimate_var(Y, p)
            push!(results, (p=p, aic=m.aic, bic=m.bic, hqc=m.hqic))
        catch
            continue
        end
    end

    if isempty(results)
        error("could not estimate VAR for any lag order 1:$max_p")
    end

    res_df = DataFrame(results)
    rename!(res_df, :p => :lags, :aic => :AIC, :bic => :BIC, :hqc => :HQC)

    optimal = select_lag_order(Y, max_p; criterion=crit_sym)

    output_result(res_df; format=Symbol(format), output=output, title="Lag Order Selection")
    _status()
    _status_styled("Optimal lag order ($criterion): $optimal\n"; bold=true)

    if format == "json"
        output_kv(Pair{String,Any}["optimal_lag" => optimal, "criterion" => criterion];
                  format=format, title="Optimal Lag")
    end
end

# ── VAR Stability Check ─────────────────────────────────

function _test_var_stability(; data::String, lags=nothing, format::String="table", output::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 2)

    p = if isnothing(lags)
        select_lag_order(Y, min(12, size(Y,1) ÷ (3*n)); criterion=:aic)
    else
        lags
    end

    model = estimate_var(Y, p)
    result = is_stationary(model)

    _status("VAR($p) Stationarity Check")
    _status()

    eigenvalues = result.eigenvalues
    moduli = abs.(eigenvalues)

    eig_df = DataFrame(
        index=1:length(eigenvalues),
        eigenvalue=string.(round.(eigenvalues; digits=6)),
        modulus=round.(moduli; digits=6)
    )

    output_result(eig_df; format=Symbol(format), output=output, title="Companion Matrix Eigenvalues")
    _status()

    if result.is_stationary
        _status_styled("VAR($p) is stable (all eigenvalues inside unit circle)\n"; color=:green, bold=true)
    else
        _status_styled("VAR($p) is NOT stable (eigenvalue(s) outside unit circle)\n"; color=:red, bold=true)
    end
    _status("  Max modulus: $(round(maximum(moduli); digits=6))")
end

# ── VECM Granger Causality Test ────────────────────────

function _test_granger(; data::String, cause::Int=1, effect::Int=2,
                         lags::Int=2, rank::String="auto",
                         deterministic::String="constant",
                         model::String="vecm", all::Bool=false,
                         format::String="table", output::String="")
    validate_method(model, ["var", "vecm"], "Granger causality model")

    if model == "var"
        _test_granger_var(data, cause, effect, lags, all, format, output)
    else
        _test_granger_vecm(data, cause, effect, lags, rank, deterministic, format, output)
    end
end

function _test_granger_vecm(data, cause, effect, lags, rank, deterministic, format, output)
    vecm, Y, varnames, p = _load_and_estimate_vecm(data, lags, rank, deterministic, "johansen", 0.05)
    n = size(Y, 2)
    r = cointegrating_rank(vecm)

    cause_name = _var_name(varnames, cause)
    effect_name = _var_name(varnames, effect)

    _status("VECM Granger Causality Test: $cause_name → $effect_name")
    _status("VECM($(p-1)), rank=$r, $n variables")
    _status()

    result = granger_causality_vecm(vecm, cause, effect)

    test_df = DataFrame(
        test=["Short-run", "Long-run", "Strong (joint)"],
        statistic=round.([result.short_run_stat, result.long_run_stat, result.strong_stat]; digits=4),
        df=[result.short_run_df, result.long_run_df, result.strong_df],
        p_value=round.([result.short_run_pvalue, result.long_run_pvalue, result.strong_pvalue]; digits=4)
    )

    output_result(test_df; format=Symbol(format), output=output,
                  title="Granger Causality: $cause_name → $effect_name")

    interpret_test_result(result.strong_pvalue,
        "Reject H0: $cause_name Granger-causes $effect_name (joint short+long-run)",
        "Cannot reject H0: no Granger causality from $cause_name to $effect_name")
end

function _test_granger_var(data, cause, effect, lags, test_all, format, output)
    model, Y, varnames, p = _load_and_estimate_var(data, lags)
    n = size(Y, 2)

    if test_all
        _status("VAR Granger Causality Test (all pairwise): VAR($p), $n variables")
        _status()

        results = granger_test_all(model)

        test_df = DataFrame(
            cause=String[],
            effect=String[],
            statistic=Float64[],
            df=Int[],
            p_value=Float64[]
        )
        for r in results
            push!(test_df, (cause=r.cause, effect=r.effect,
                           statistic=round(r.statistic; digits=4),
                           df=r.df, p_value=round(r.pvalue; digits=4)))
        end

        output_result(test_df; format=Symbol(format), output=output,
                      title="VAR Granger Causality (all pairwise)")
    else
        cause_name = _var_name(varnames, cause)
        effect_name = _var_name(varnames, effect)

        _status("VAR Granger Causality Test: $cause_name → $effect_name")
        _status("VAR($p), $n variables")
        _status()

        result = granger_test(model, cause, effect)

        pairs = Pair{String,Any}[
            "Test statistic" => round(result.statistic; digits=4),
            "p-value" => round(result.pvalue; digits=4),
            "Degrees of freedom" => result.df,
        ]

        output_kv(pairs; format=format, output=output,
                  title="Granger Causality: $cause_name → $effect_name")

        interpret_test_result(result.pvalue,
            "Reject H0: $cause_name Granger-causes $effect_name at 5%",
            "Cannot reject H0: no Granger causality from $cause_name to $effect_name")
    end
end

# ── Panel VAR Tests ────────────────────────────────────────

function _test_pvar_hansen_j(; data::String, id_col::String="", time_col::String="",
                               lags::Int=1, format::String="table", output::String="")
    isempty(id_col) && error("Panel VAR test requires --id-col")
    isempty(time_col) && error("Panel VAR test requires --time-col")

    model, panel, varnames = _load_and_estimate_pvar(data, id_col, time_col, lags)

    _status("Hansen J Overidentification Test: Panel VAR($lags)")
    _status()

    result = pvar_hansen_j(model)

    pairs = Pair{String,Any}[
        "J statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Degrees of freedom" => result.df,
        "Instruments" => result.n_instruments,
        "Parameters" => result.n_params,
    ]
    output_kv(pairs; format=format, output=output, title="Hansen J Test")

    interpret_test_result(result.pvalue,
        "Reject H0: overidentifying restrictions not valid at 5%",
        "Cannot reject H0: overidentifying restrictions appear valid")
end

function _test_pvar_mmsc(; data::String, id_col::String="", time_col::String="",
                           max_lags::Int=4, criterion::String="bic",
                           format::String="table", output::String="")
    isempty(id_col) && error("Panel VAR test requires --id-col")
    isempty(time_col) && error("Panel VAR test requires --time-col")

    panel = load_panel_data(data, id_col, time_col)

    _status("MMSC Model Selection: max lags=$max_lags, criterion=$criterion")
    _status()

    # MEMs 0.7.0 (C054): pvar_mmsc is now a single-model criterion; MMSC-based
    # lag selection is pvar_lag_selection, which returns a (table, best_bic,
    # best_aic, best_hqic, models) NamedTuple (`.table` is an [p, BIC, AIC, HQIC]
    # Matrix{Any}) and computes all three criteria at once.
    result = pvar_lag_selection(panel, max_lags)

    res_df = DataFrame(result.table, [:lags, :BIC, :AIC, :HQIC])
    output_result(res_df; format=Symbol(format), output=output, title="MMSC Results")

    _status()
    _status_styled("Optimal lag order ($criterion): $(_pvar_best_lag(result, criterion))\n"; bold=true)
end

"""Optimal lag from a pvar_lag_selection result for the requested criterion."""
_pvar_best_lag(result, criterion::AbstractString) =
    criterion == "aic"  ? result.best_aic  :
    criterion == "hqic" ? result.best_hqic : result.best_bic

function _test_pvar_lagselect(; data::String, id_col::String="", time_col::String="",
                                max_lags::Int=4, criterion::String="bic",
                                format::String="table", output::String="")
    isempty(id_col) && error("Panel VAR test requires --id-col")
    isempty(time_col) && error("Panel VAR test requires --time-col")

    panel = load_panel_data(data, id_col, time_col)

    _status("Panel VAR Lag Selection: max lags=$max_lags, criterion=$criterion")
    _status()

    result = pvar_lag_selection(panel, max_lags)

    res_df = DataFrame(result.table, [:lags, :BIC, :AIC, :HQIC])
    output_result(res_df; format=Symbol(format), output=output, title="Lag Selection Results")

    _status()
    _status_styled("Optimal lag order ($criterion): $(_pvar_best_lag(result, criterion))\n"; bold=true)
end

function _test_pvar_stability(; data::String, id_col::String="", time_col::String="",
                                lags::Int=1, format::String="table", output::String="")
    isempty(id_col) && error("Panel VAR test requires --id-col")
    isempty(time_col) && error("Panel VAR test requires --time-col")

    model, panel, varnames = _load_and_estimate_pvar(data, id_col, time_col, lags)

    _status("Panel VAR($lags) Stability Check")
    _status()

    result = pvar_stability(model)

    eig_df = DataFrame(
        index=1:length(result.eigenvalues),
        eigenvalue=string.(round.(result.eigenvalues; digits=6)),
        modulus=round.(result.moduli; digits=6)
    )

    output_result(eig_df; format=Symbol(format), output=output,
                  title="Panel VAR Companion Matrix Eigenvalues")
    _status()

    if result.is_stable
        _status_styled("Panel VAR($lags) is stable (all eigenvalues inside unit circle)\n"; color=:green, bold=true)
    else
        _status_styled("Panel VAR($lags) is NOT stable (eigenvalue(s) outside unit circle)\n"; color=:red, bold=true)
    end
    _status("  Max modulus: $(round(maximum(result.moduli); digits=6))")
end

# ── LR Test ───────────────────────────────────────────────

function _test_lr(; data1::String, data2::String, lags1=nothing, lags2=nothing,
                    format::String="table", output::String="")
    m1, _, _, p1 = _load_and_estimate_var(data1, lags1)
    m2, _, _, p2 = _load_and_estimate_var(data2, lags2)

    if p1 == p2 && data1 == data2
        _status_styled("  Warning: Both models have the same specification (p=$p1) on the same data.\n"; color=:yellow)
        _status_styled("  Use --lags1 and --lags2 to specify different restricted/unrestricted models.\n"; color=:yellow)
    end

    _status("Likelihood Ratio Test: restricted (p=$p1) vs unrestricted (p=$p2)")
    _status()

    result = lr_test(m1, m2)

    pairs = Pair{String,Any}[
        "LR statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Degrees of freedom" => result.df,
        "Log-lik (restricted)" => round(result.loglik_restricted; digits=4),
        "Log-lik (unrestricted)" => round(result.loglik_unrestricted; digits=4),
    ]
    output_kv(pairs; format=format, output=output, title="Likelihood Ratio Test")

    interpret_test_result(result.pvalue,
        "Reject H0: restrictions are not supported by the data at 5%",
        "Cannot reject H0: restrictions appear valid")
end

# ── LM Test ───────────────────────────────────────────────

function _test_lm(; data1::String, data2::String, lags1=nothing, lags2=nothing,
                    format::String="table", output::String="")
    m1, _, _, p1 = _load_and_estimate_var(data1, lags1)
    m2, _, _, p2 = _load_and_estimate_var(data2, lags2)

    if p1 == p2 && data1 == data2
        _status_styled("  Warning: Both models have the same specification (p=$p1) on the same data.\n"; color=:yellow)
        _status_styled("  Use --lags1 and --lags2 to specify different restricted/unrestricted models.\n"; color=:yellow)
    end

    _status("Lagrange Multiplier Test: restricted (p=$p1) vs unrestricted (p=$p2)")
    _status()

    result = lm_test(m1, m2)

    pairs = Pair{String,Any}[
        "LM statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Degrees of freedom" => result.df,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Lagrange Multiplier Test")

    interpret_test_result(result.pvalue,
        "Reject H0: restrictions are not supported at 5%",
        "Cannot reject H0: restrictions appear valid")
end

# ── Andrews Structural Break Test ─────────────────────

function _test_andrews(; data::String, response::Int=1,
                        test::String="supwald", trimming::Float64=0.15,
                        format::String="table", output::String="",
                        plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 1)

    y = Y[:, response]
    X = hcat(ones(n), Y[:, setdiff(1:size(Y, 2), response)])

    _status("Andrews Structural Break Test: $(varnames[response]), test=$test, trimming=$trimming")
    _status()

    result = andrews_test(y, X; test=Symbol(test), trimming=trimming)

    _maybe_plot(result; plot=plot, plot_save=plot_save)

    pairs = Pair{String,Any}[
        "Test type" => result.test_type,
        "Statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Break date (index)" => result.break_index,
        "Break fraction" => round(result.break_fraction; digits=4),
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Andrews Break Test")

    interpret_test_result(result.pvalue,
        "Reject H0: structural break detected at index $(result.break_index)",
        "Cannot reject H0: no structural break detected")
end

# ── Bai-Perron Multiple Break Test ────────────────────

function _test_bai_perron(; data::String, response::Int=1,
                           max_breaks::Int=5, trimming::Float64=0.15,
                           criterion::String="bic",
                           format::String="table", output::String="",
                           plot::Bool=false, plot_save::String="")
    Y, varnames = load_multivariate_data(data)
    n = size(Y, 1)

    y = Y[:, response]
    X = hcat(ones(n), Y[:, setdiff(1:size(Y, 2), response)])

    _status("Bai-Perron Multiple Break Test: $(varnames[response]), max_breaks=$max_breaks, criterion=$criterion")
    _status()

    result = bai_perron_test(y, X; max_breaks=max_breaks, trimming=trimming,
                             criterion=Symbol(criterion))

    _maybe_plot(result; plot=plot, plot_save=plot_save)

    pairs = Pair{String,Any}[
        "Number of breaks" => result.n_breaks,
        "Break dates" => join(result.break_dates, ", "),
        "Trimming" => result.trimming,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Bai-Perron Test")

    if !isempty(result.regime_coefs)
        for (i, coefs) in enumerate(result.regime_coefs)
            _status("  Regime $i: $(join(round.(coefs; digits=4), ", "))")
        end
    end
end

# ── Panel Unit Root Tests ─────────────────────────────

function _test_panic(; data::String, factors::String="auto",
                      method::String="pooled", id_col::String="", time_col::String="",
                      format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    r_arg = factors == "auto" ? :auto : parse(Int, factors)

    _status("PANIC Panel Unit Root Test: factors=$(factors), method=$method")
    _status()

    result = panic_test(dat; r=r_arg, method=Symbol(method))

    pairs = Pair{String,Any}[
        "Pooled statistic" => round(result.pooled_statistic; digits=4),
        "Pooled p-value" => round(result.pooled_pvalue; digits=4),
        "Number of factors" => result.n_factors,
        "Units" => result.n_units,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="PANIC Test (Bai-Ng)")

    interpret_test_result(result.pooled_pvalue,
        "Reject H0: panel has unit roots (after removing common factors)",
        "Cannot reject H0: panel is stationary (after removing common factors)")
end

function _test_cips(; data::String, lags::String="auto",
                     deterministic::String="constant",
                     id_col::String="", time_col::String="",
                     format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    lags_arg = lags == "auto" ? :auto : parse(Int, lags)

    _status("Pesaran CIPS Panel Unit Root Test: lags=$lags, deterministic=$deterministic")
    _status()

    result = pesaran_cips_test(dat; lags=lags_arg, deterministic=Symbol(deterministic))

    pairs = Pair{String,Any}[
        "CIPS statistic" => round(result.cips_statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Lags" => result.lags,
        "Deterministic" => result.deterministic,
        "Units" => result.n_units,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Pesaran CIPS Test")

    interpret_test_result(result.pvalue,
        "Reject H0: panel has unit roots",
        "Cannot reject H0: panel is stationary")
end

function _test_moon_perron(; data::String, factors::String="auto",
                            id_col::String="", time_col::String="",
                            format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    r_arg = factors == "auto" ? :auto : parse(Int, factors)

    _status("Moon-Perron Panel Unit Root Test: factors=$factors")
    _status()

    result = moon_perron_test(dat; r=r_arg)

    pairs = Pair{String,Any}[
        "t_a* statistic" => round(result.t_a_statistic; digits=4),
        "t_b* statistic" => round(result.t_b_statistic; digits=4),
        "p-value (t_a*)" => round(result.pvalue_a; digits=4),
        "p-value (t_b*)" => round(result.pvalue_b; digits=4),
        "Factors" => result.n_factors,
        "Units" => result.n_units,
    ]
    output_kv(pairs; format=format, output=output, title="Moon-Perron Test")

    interpret_test_result(min(result.pvalue_a, result.pvalue_b),
        "Reject H0: panel has unit roots",
        "Cannot reject H0: panel is stationary")
end

function _test_factor_break(; data::String, factors::Int=2,
                              method::String="breitung_eickmeier",
                              id_col::String="", time_col::String="",
                              format::String="table", output::String="")
    dat, is_panel = _load_panel_or_matrix(data; id_col=id_col, time_col=time_col)

    _status("Factor Break Test: factors=$factors, method=$method")
    _status()

    result = factor_break_test(dat, factors; method=Symbol(method))

    pairs = Pair{String,Any}[
        "Statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Break date (index)" => result.break_date,
        "Method" => result.method,
        "Factors" => result.n_factors,
        "Units" => result.n_vars,
    ]
    output_kv(pairs; format=format, output=output, title="Factor Break Test")

    interpret_test_result(result.pvalue,
        "Reject H0: factor structure instability detected at index $(result.break_date)",
        "Cannot reject H0: factor structure appears stable")
end

# ── Fourier ADF Test ──────────────────────────────────

function _test_fourier_adf(; data::String, column::Int=1,
                             regression::String="constant", fmax::Int=3,
                             lags::String="aic", max_lags=nothing,
                             trim::Float64=0.15,
                             format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    lags_arg = tryparse(Int, lags) !== nothing ? parse(Int, lags) : Symbol(lags)
    reg_sym = Symbol(regression)

    _status("Fourier ADF Test: variable=$vname, observations=$(length(y)), regression=$regression, fmax=$fmax")
    _status()

    kw = Dict{Symbol,Any}(:regression => reg_sym, :fmax => fmax, :trim => trim)
    !isnothing(max_lags) && (kw[:max_lags] = max_lags)
    result = fourier_adf_test(y; lags=lags_arg, kw...)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Optimal frequency" => result.frequency,
        "F-statistic (Fourier)" => round(result.f_statistic; digits=4),
        "F p-value" => round(result.f_pvalue; digits=4),
        "Lags" => result.lags,
        "Observations" => result.nobs,
    ]

    output_kv(pairs; format=format, output=output, title="Fourier ADF Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% -- series appears stationary (with smooth breaks)",
        "Cannot reject H0 (unit root) at 5% -- series appears non-stationary")

    if result.f_pvalue < 0.05
        _status()
        _status_styled("Fourier terms are jointly significant (F=$(round(result.f_statistic; digits=4)), p=$(round(result.f_pvalue; digits=4)))\n"; color=:green)
    end
end

# ── Fourier KPSS Test ────────────────────────────────

function _test_fourier_kpss(; data::String, column::Int=1,
                              regression::String="constant", fmax::Int=3,
                              bandwidth=nothing,
                              format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    reg_sym = Symbol(regression)

    _status("Fourier KPSS Test: variable=$vname, observations=$(length(y)), regression=$regression, fmax=$fmax")
    _status()

    kw = Dict{Symbol,Any}(:regression => reg_sym, :fmax => fmax)
    !isnothing(bandwidth) && (kw[:bandwidth] = bandwidth)
    result = fourier_kpss_test(y; kw...)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Optimal frequency" => result.frequency,
        "F-statistic (Fourier)" => round(result.f_statistic; digits=4),
        "F p-value" => round(result.f_pvalue; digits=4),
        "Bandwidth" => result.bandwidth,
        "Observations" => result.nobs,
    ]

    output_kv(pairs; format=format, output=output, title="Fourier KPSS Test: $vname")

    # KPSS: reversed interpretation (H0 = stationarity)
    _status()
    if result.pvalue < 0.05
        _status_styled("-> Reject H0 (stationarity) at 5% -- series appears non-stationary\n"; color=:yellow)
    else
        _status_styled("-> Cannot reject H0 (stationarity) -- series appears stationary (with smooth breaks)\n"; color=:green)
    end
end

# ── DF-GLS Test ──────────────────────────────────────

function _test_dfgls(; data::String, column::Int=1,
                      regression::String="constant",
                      lags::String="aic", max_lags=nothing,
                      format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    lags_arg = tryparse(Int, lags) !== nothing ? parse(Int, lags) : Symbol(lags)
    reg_sym = Symbol(regression)

    _status("DF-GLS Test: variable=$vname, observations=$(length(y)), regression=$regression")
    _status()

    kw = Dict{Symbol,Any}(:regression => reg_sym)
    !isnothing(max_lags) && (kw[:max_lags] = max_lags)
    result = dfgls_test(y; lags=lags_arg, kw...)

    pairs = Pair{String,Any}[
        "DF-GLS tau statistic" => round(result.statistic; digits=4),
        "PT statistic" => round(result.pt_statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Lags" => result.lags,
        "Observations" => result.nobs,
    ]

    # M-GLS statistics are separate fields upstream, not a collection.
    for k in (:MZa, :MZt, :MSB, :MPT)
        push!(pairs, "M-GLS $k" => round(getfield(result, k); digits=4))
    end

    output_kv(pairs; format=format, output=output, title="DF-GLS Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% -- series appears stationary",
        "Cannot reject H0 (unit root) at 5% -- series appears non-stationary")
end

# ── LM Unit Root Test ───────────────────────────────

function _test_lm_unitroot(; data::String, column::Int=1,
                             breaks::Int=0, regression::String="level",
                             lags::String="aic", max_lags=nothing,
                             trim::Float64=0.15,
                             format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    lags_arg = tryparse(Int, lags) !== nothing ? parse(Int, lags) : Symbol(lags)
    reg_sym = Symbol(regression)

    _status("LM Unit Root Test: variable=$vname, observations=$(length(y)), breaks=$breaks, regression=$regression")
    _status()

    kw = Dict{Symbol,Any}(:breaks => breaks, :regression => reg_sym, :trim => trim)
    !isnothing(max_lags) && (kw[:max_lags] = max_lags)
    result = lm_unitroot_test(y; lags=lags_arg, kw...)

    pairs = Pair{String,Any}[
        "LM statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Breaks" => result.breaks,
        "Lags" => result.lags,
        "Observations" => result.nobs,
    ]

    if !isnothing(result.break_dates)
        push!(pairs, "Break indices" => join(result.break_dates, ", "))
        push!(pairs, "Break fractions" => join(round.(result.break_fractions; digits=4), ", "))
    end

    output_kv(pairs; format=format, output=output, title="LM Unit Root Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% -- series appears stationary",
        "Cannot reject H0 (unit root) at 5% -- series appears non-stationary")
end

# ── ADF 2-Break Test ────────────────────────────────

function _test_adf_2break(; data::String, column::Int=1,
                            model::String="level",
                            lags::String="aic", max_lags=nothing,
                            trim::Float64=0.10,
                            format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    lags_arg = tryparse(Int, lags) !== nothing ? parse(Int, lags) : Symbol(lags)
    model_sym = Symbol(model)

    _status("ADF 2-Break Test: variable=$vname, observations=$(length(y)), model=$model")
    _status()

    kw = Dict{Symbol,Any}(:model => model_sym, :trim => trim)
    !isnothing(max_lags) && (kw[:max_lags] = max_lags)
    result = adf_2break_test(y; lags=lags_arg, kw...)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Break 1 index" => result.break1,
        "Break 1 fraction" => round(result.break1_fraction; digits=4),
        "Break 2 index" => result.break2,
        "Break 2 fraction" => round(result.break2_fraction; digits=4),
        "Lags" => result.lags,
        "Observations" => result.nobs,
    ]

    output_kv(pairs; format=format, output=output, title="ADF 2-Break Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% -- series appears stationary (with two breaks)",
        "Cannot reject H0 (unit root) at 5% -- series appears non-stationary")

    _status()
    _status("Estimated structural breaks at observations $(result.break1) and $(result.break2)")
end

# ── Gregory-Hansen Cointegration Test ───────────────

function _test_gregory_hansen(; data::String, model::String="C",
                                lags::String="aic", max_lags=nothing,
                                trim::Float64=0.15,
                                format::String="table", output::String="")
    Y, varnames = load_multivariate_data(data)

    lags_arg = tryparse(Int, lags) !== nothing ? parse(Int, lags) : Symbol(lags)
    model_sym = Symbol(model)

    _status("Gregory-Hansen Test: $(length(varnames)) variables, model=$model")
    _status()

    kw = Dict{Symbol,Any}(:model => model_sym, :trim => trim)
    !isnothing(max_lags) && (kw[:max_lags] = max_lags)
    # Cointegration needs a dependent + at least one regressor; upstream signals a
    # one-column matrix with a bare ArgumentError, which would exit 1 (#81 class).
    result = try
        gregory_hansen_test(Y; lags=lags_arg, kw...)
    catch e
        e isa ArgumentError && throw(CliError("data/shape",
            "gregory-hansen needs at least 2 columns (dependent + regressor)";
            hint="got $(length(varnames)): $(join(varnames, ", "))"))
        rethrow()
    end

    pairs = Pair{String,Any}[
        "ADF* statistic" => round(result.adf_statistic; digits=4),
        "ADF* p-value" => round(result.adf_pvalue; digits=4),
        "ADF* break index" => result.adf_break,
        "Zt* statistic" => round(result.zt_statistic; digits=4),
        "Zt* p-value" => round(result.zt_pvalue; digits=4),
        "Zt* break index" => result.zt_break,
        "Za* statistic" => round(result.za_statistic; digits=4),
        "Za* p-value" => round(result.za_pvalue; digits=4),
        "Za* break index" => result.za_break,
        "Model" => result.model,
        "Observations" => result.nobs,
    ]

    output_kv(pairs; format=format, output=output, title="Gregory-Hansen Test")

    # Use ADF* p-value for interpretation
    interpret_test_result(result.adf_pvalue,
        "Reject H0 (no cointegration): cointegration with structural break detected",
        "Cannot reject H0: no cointegration with structural break")

    _status()
    _status("Estimated break at observation $(result.adf_break) (ADF* criterion)")
end

# ── VIF (Variance Inflation Factor) ─────────────────

function _test_vif(; data::String, dep::String="",
                    cov_type::String="hc1",
                    format::String="table", output::String="")
    y, X, xcols = _load_reg_data(data, dep)

    _status("Variance Inflation Factors: $(length(xcols)) regressors, cov_type=$cov_type")
    _status()

    model = estimate_reg(y, X; cov_type=Symbol(cov_type), varnames=xcols)
    vif_vals = vif(model)

    vif_df = DataFrame(
        Variable = xcols,
        VIF = round.(vif_vals; digits=4),
        Tolerance = round.(1.0 ./ vif_vals; digits=4),
    )

    output_result(vif_df; format=Symbol(format), output=output,
                  title="Variance Inflation Factors")

    _status()
    max_vif = maximum(vif_vals)
    if max_vif > 10.0
        _status_styled("Warning: VIF > 10 detected -- severe multicollinearity\n"; color=:red)
    elseif max_vif > 5.0
        _status_styled("Moderate multicollinearity detected (VIF > 5)\n"; color=:yellow)
    else
        _status_styled("No significant multicollinearity (all VIF < 5)\n"; color=:green)
    end
    _status("  Mean VIF: $(round(sum(vif_vals) / length(vif_vals); digits=4))")
end

# ── Panel Specification Tests ────────────────────────

function _test_hausman(; data::String, dep::String="", indep::String="",
                        id_col::String="", time_col::String="",
                        output::String="", format::String="table")
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    fe_model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:fe)
    re_model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:re)
    result = hausman_test(fe_model, re_model)

    _status("Hausman Test: FE vs RE")
    _status()
    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "χ² statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (use FE)" : "Fail to reject H0 (RE consistent)",
    ]
    output_kv(pairs; format=format, output=output, title="Hausman Specification Test")
end

function _test_breusch_pagan(; data::String, dep::String="", indep::String="",
                              id_col::String="", time_col::String="",
                              output::String="", format::String="table")
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:re)
    result = breusch_pagan_test(model)

    _status("Breusch-Pagan LM Test for Random Effects")
    _status()
    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "LM statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (RE preferred over pooled OLS)" : "Fail to reject H0 (pooled OLS adequate)",
    ]
    output_kv(pairs; format=format, output=output, title="Breusch-Pagan LM Test")
end

function _test_f_fe(; data::String, dep::String="", indep::String="",
                     id_col::String="", time_col::String="",
                     output::String="", format::String="table")
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:fe)
    result = f_test_fe(model)

    _status("F-Test for Individual Fixed Effects")
    _status()
    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "F statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (individual effects significant)" : "Fail to reject H0 (pooled OLS adequate)",
    ]
    output_kv(pairs; format=format, output=output, title="F-Test for Fixed Effects")
end

function _test_pesaran_cd(; data::String, dep::String="", indep::String="",
                           id_col::String="", time_col::String="",
                           output::String="", format::String="table")
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:fe)
    result = pesaran_cd_test(model)

    _status("Pesaran CD Test for Cross-Sectional Dependence")
    _status()
    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "CD statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (cross-sectional dependence detected)" : "Fail to reject H0 (no cross-sectional dependence)",
    ]
    output_kv(pairs; format=format, output=output, title="Pesaran CD Test")
end

function _test_wooldridge_ar(; data::String, dep::String="", indep::String="",
                              id_col::String="", time_col::String="",
                              output::String="", format::String="table")
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:fe)
    result = wooldridge_ar_test(model)

    _status("Wooldridge Test for Serial Correlation in Panel Data")
    _status()
    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "F statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (serial correlation detected)" : "Fail to reject H0 (no serial correlation)",
    ]
    output_kv(pairs; format=format, output=output, title="Wooldridge AR Test")
end

function _test_modified_wald(; data::String, dep::String="", indep::String="",
                              id_col::String="", time_col::String="",
                              output::String="", format::String="table")
    isempty(dep) && throw(CliError("usage/missing", "--dep is required";
        hint="name the dependent variable column, e.g. --dep y"))
    pd = _load_panel_for_preg(data, id_col, time_col)
    indep_syms = _parse_indep_vars(pd, dep, indep)

    model = estimate_xtreg(pd, Symbol(dep), indep_syms; model=:fe)
    result = modified_wald_test(model)

    _status("Modified Wald Test for Groupwise Heteroskedasticity")
    _status()
    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "χ² statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (groupwise heteroskedasticity detected)" : "Fail to reject H0 (homoskedastic)",
    ]
    output_kv(pairs; format=format, output=output, title="Modified Wald Test")
end

# ── Spectral/Portmanteau Tests ───────────────────────

function _test_fisher(; data::String, column::Int=1,
                       format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    _status("Fisher's Test for Periodicity: variable=$vname")
    _status()

    result = fisher_test(y)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Fisher's Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (no periodicity): significant periodic component detected",
        "Cannot reject H0: no significant periodicity")
end

function _test_bartlett_wn(; data::String, column::Int=1,
                            format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    _status("Bartlett White Noise Test: variable=$vname")
    _status()

    result = bartlett_white_noise_test(y)

    pairs = Pair{String,Any}[
        "Test statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Bartlett White Noise Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (white noise): series is not white noise",
        "Cannot reject H0: series is consistent with white noise")
end

function _test_box_pierce(; data::String, column::Int=1, lags::Int=20,
                           format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    _status("Box-Pierce Test: variable=$vname, lags=$lags")
    _status()

    result = box_pierce_test(y; lags=lags)

    pairs = Pair{String,Any}[
        "Q statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Box-Pierce Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (white noise): significant autocorrelation detected",
        "Cannot reject H0: no significant autocorrelation")
end

function _test_durbin_watson(; data::String, column::Int=1,
                              format::String="table", output::String="")
    y, vname = load_univariate_series(data, column)

    _status("Durbin-Watson Test: variable=$vname")
    _status()

    result = durbin_watson_test(y)

    # DurbinWatsonResult is (statistic, pvalue, nobs) — real MEMs exposes no
    # Savin-White dL/dU bounds or decision string, so report the p-value instead.
    pairs = Pair{String,Any}[
        "DW statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Durbin-Watson Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0: residuals are autocorrelated",
        "Cannot reject H0: no first-order autocorrelation")
end

# ── Discrete Choice Tests ────────────────────────────

function _test_brant(; data::String, dep::String="", cov_type::String="hc1",
                      format::String="table", output::String="")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    model = estimate_ologit(y, X; cov_type=Symbol(cov_type), varnames=xcols)

    _status("Brant Test for Parallel Regression: $dep_name")
    _status()

    result = brant_test(model)

    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "χ² statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (parallel regression assumption violated)" : "Fail to reject H0 (parallel regression assumption holds)",
    ]
    output_kv(pairs; format=format, output=output, title="Brant Test")
end

function _test_hausman_iia(; data::String, dep::String="", omit_category=nothing,
                            format::String="table", output::String="")
    y, X, xcols = _load_reg_data(data, dep)
    dep_name = isempty(dep) ? variable_names(load_data(data))[1] : dep

    isnothing(omit_category) && throw(CliError("usage/missing", "--omit-category is required";
        hint="name the alternative to drop, e.g. --omit-category 2"))

    model = estimate_mlogit(y, X; cov_type=:ols, varnames=xcols)

    _status("Hausman-McFadden IIA Test: $dep_name, omit category=$omit_category")
    _status()

    result = hausman_iia(model; omit_category=omit_category)

    pairs = Pair{String,Any}[
        "Test" => result.test_name,
        "χ² statistic" => round(result.statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "df" => result.df,
        "Omitted category" => omit_category,
        "Decision" => result.pvalue < 0.05 ? "Reject H0 (IIA assumption violated)" : "Fail to reject H0 (IIA assumption holds)",
    ]
    output_kv(pairs; format=format, output=output, title="Hausman-McFadden IIA Test")
end
