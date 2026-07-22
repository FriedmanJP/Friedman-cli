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
        "CIPS statistic" => round(result.cips; digits=4),
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
        "Factors" => result.r,
        "Units" => result.n_units,
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
        "DF-GLS tau statistic" => round(result.tau_statistic; digits=4),
        "PT statistic" => round(result.pt_statistic; digits=4),
        "p-value" => round(result.pvalue; digits=4),
        "Lags" => result.lags,
        "Observations" => result.nobs,
    ]

    # Add M-GLS statistics if available
    for (k, v) in result.mgls_statistics
        push!(pairs, "M-GLS $k" => round(v; digits=4))
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

    if !isnothing(result.break_indices)
        push!(pairs, "Break indices" => join(result.break_indices, ", "))
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
        "Break 1 index" => result.break_index1,
        "Break 1 fraction" => round(result.break_fraction1; digits=4),
        "Break 2 index" => result.break_index2,
        "Break 2 fraction" => round(result.break_fraction2; digits=4),
        "Lags" => result.lags,
        "Observations" => result.nobs,
    ]

    output_kv(pairs; format=format, output=output, title="ADF 2-Break Test: $vname")

    interpret_test_result(result.pvalue,
        "Reject H0 (unit root) at 5% -- series appears stationary (with two breaks)",
        "Cannot reject H0 (unit root) at 5% -- series appears non-stationary")

    _status()
    _status("Estimated structural breaks at observations $(result.break_index1) and $(result.break_index2)")
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
    result = gregory_hansen_test(Y; lags=lags_arg, kw...)

    pairs = Pair{String,Any}[
        "ADF* statistic" => round(result.adf_statistic; digits=4),
        "ADF* p-value" => round(result.adf_pvalue; digits=4),
        "ADF* break index" => result.adf_break_index,
        "Zt* statistic" => round(result.zt_statistic; digits=4),
        "Zt* p-value" => round(result.zt_pvalue; digits=4),
        "Zt* break index" => result.zt_break_index,
        "Za* statistic" => round(result.za_statistic; digits=4),
        "Za* p-value" => round(result.za_pvalue; digits=4),
        "Za* break index" => result.za_break_index,
        "Model" => result.model,
        "Observations" => result.nobs,
    ]

    output_kv(pairs; format=format, output=output, title="Gregory-Hansen Test")

    # Use ADF* p-value for interpretation
    interpret_test_result(result.adf_pvalue,
        "Reject H0 (no cointegration): cointegration with structural break detected",
        "Cannot reject H0: no cointegration with structural break")

    _status()
    _status("Estimated break at observation $(result.adf_break_index) (ADF* criterion)")
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
    isempty(dep) && error("--dep is required")
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
    isempty(dep) && error("--dep is required")
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
    isempty(dep) && error("--dep is required")
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
    isempty(dep) && error("--dep is required")
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
    isempty(dep) && error("--dep is required")
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
    isempty(dep) && error("--dep is required")
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

    pairs = Pair{String,Any}[
        "DW statistic" => round(result.statistic; digits=4),
        "Lower bound (dL)" => round(result.lower_bound; digits=4),
        "Upper bound (dU)" => round(result.upper_bound; digits=4),
        "Decision" => result.decision,
        "Observations" => result.nobs,
    ]
    output_kv(pairs; format=format, output=output, title="Durbin-Watson Test: $vname")
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

    isnothing(omit_category) && error("--omit-category is required")

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
