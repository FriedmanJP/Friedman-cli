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

# DSGE commands: solve, irf, fevd, simulate, estimate, perfect-foresight, steady-state, bayes (NodeCommand)

function dsge_specs()::Vector{CommandSpec}
    return [
        CommandSpec(
            path=["dsge", "solve"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="method", type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
                OptionSpec(name="order", type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
                OptionSpec(name="degree", type=Int, default=5, description="Polynomial degree (projection/pfi)"),
                OptionSpec(name="grid", type=String, default="auto", description="Grid type: auto|chebyshev|smolyak"),
                OptionSpec(name="constraints", type=String, default="", description="Path to OccBin constraints TOML"),
                OptionSpec(name="constraint-solver", type=String, default="", description="Constraint solver: nonlinearsolve|optim|nlopt|ipopt|path"),
                OptionSpec(name="periods", type=Int, default=40, description="Number of periods for OccBin simulation"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:solve, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_solve),
        ),
        CommandSpec(
            path=["dsge", "irf"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="method", type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
                OptionSpec(name="order", type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="shock-size", type=Float64, default=1.0, description="Shock size (std devs)"),
                OptionSpec(name="n-sim", type=Int, default=0, description="Simulation-based IRF draws (0=analytical)"),
                OptionSpec(name="constraints", type=String, default="", description="Path to OccBin constraints TOML"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:irf, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_irf),
        ),
        CommandSpec(
            path=["dsge", "fevd"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="method", type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
                OptionSpec(name="order", type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="FEVD horizon"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="unconditional", description="Unconditional (asymptotic) FEVD for order≥2 perturbation (Andreasen et al. 2018)"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:fevd, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_fevd),
        ),
        CommandSpec(
            path=["dsge", "simulate"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="method", type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
                OptionSpec(name="order", type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
                OptionSpec(name="periods", type=Int, default=200, description="Simulation periods (after burn-in)"),
                OptionSpec(name="burn", type=Int, default=100, description="Burn-in periods to discard"),
                OptionSpec(name="seed", type=Int, default=0, description="Random seed (0=no seed)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="antithetic", description="Use antithetic sampling for variance reduction"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:simulate, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_simulate),
        ),
        CommandSpec(
            path=["dsge", "estimate"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="data", short="d", type=String, default="", description="Path to CSV data file"),
                OptionSpec(name="method", type=String, default="irf_matching", description="Estimation method: irf_matching|likelihood|bayesian|smm"),
                OptionSpec(name="params", type=String, default="", description="Comma-separated parameter names to estimate"),
                OptionSpec(name="solve-method", type=String, default="gensys", description="DSGE solution method"),
                OptionSpec(name="solve-order", type=Int, default=1, description="Perturbation order for solution"),
                OptionSpec(name="weighting", type=String, default="optimal", description="Weighting matrix: identity|optimal|diagonal"),
                OptionSpec(name="irf-horizon", type=Int, default=20, description="IRF horizon for matching"),
                OptionSpec(name="var-lags", type=Int, default=4, description="VAR lags for empirical IRF"),
                OptionSpec(name="sim-ratio", type=Int, default=5, description="Simulation-to-data ratio (SMM)"),
                OptionSpec(name="bounds", type=String, default="", description="Path to parameter bounds TOML"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:estimate, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_estimate),
        ),
        CommandSpec(
            path=["dsge", "perfect-foresight"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="shocks", type=String, default="", description="Path to shock sequence CSV"),
                OptionSpec(name="constraints", type=String, default="", description="Path to constraints TOML"),
                OptionSpec(name="constraint-solver", type=String, default="", description="Constraint solver: nonlinearsolve|optim|nlopt|ipopt|path"),
                OptionSpec(name="periods", type=Int, default=100, description="Simulation periods"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:perfect_foresight, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_perfect_foresight),
        ),
        CommandSpec(
            path=["dsge", "steady-state"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="constraints", type=String, default="", description="Path to OccBin constraints TOML"),
                OptionSpec(name="constraint-solver", type=String, default="", description="Constraint solver: nonlinearsolve|optim|nlopt|ipopt|path"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:steady_state, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_steady_state),
        ),
        CommandSpec(
            path=["dsge", "hd"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="data", short="d", type=String, default="", description="Path to CSV data file"),
                OptionSpec(name="observables", type=String, default="", description="Observable variable names (comma-separated)"),
                OptionSpec(name="states", type=String, default="observables", description="observables|all"),
                OptionSpec(name="measurement-error", type=String, default="", description="Measurement error std devs (comma-separated) or auto"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:hd, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_hd),
        ),
        CommandSpec(
            path=["dsge", "bayes", "estimate"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH (Christen & Fox 2005)")
            ],
            tables=[TableSpec(name=:bayes_estimate, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_estimate),
        ),
        CommandSpec(
            path=["dsge", "bayes", "irf"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bayes_irf, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_irf),
        ),
        CommandSpec(
            path=["dsge", "bayes", "fevd"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="FEVD horizon"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bayes_fevd, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_fevd),
        ),
        CommandSpec(
            path=["dsge", "bayes", "simulate"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="periods", type=Int, default=200, description="Simulation periods"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bayes_simulate, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_simulate),
        ),
        CommandSpec(
            path=["dsge", "bayes", "summary"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH")
            ],
            tables=[TableSpec(name=:bayes_summary, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_summary),
        ),
        CommandSpec(
            path=["dsge", "bayes", "compare"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="model2", type=String, default="", description="Path to second DSGE model file"),
                OptionSpec(name="params2", type=String, default="", description="Parameters for second model (comma-separated)"),
                OptionSpec(name="priors2", type=String, default="", description="Priors TOML for second model")
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH")
            ],
            tables=[TableSpec(name=:bayes_compare, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_compare),
        ),
        CommandSpec(
            path=["dsge", "bayes", "predictive"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="n-sim", type=Int, default=500, description="Number of predictive simulations"),
                OptionSpec(name="periods", type=Int, default=100, description="Periods per simulation"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bayes_predictive, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_predictive),
        ),
        CommandSpec(
            path=["dsge", "bayes", "hd"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="n-hd-draws", type=Int, default=200, description="Number of posterior draws for HD"),
                OptionSpec(name="quantiles", type=String, default="0.16,0.5,0.84", description="Quantile levels"),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="mode-only", description="Use posterior mode only (no full posterior)"),
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:bayes_hd, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_hd),
        ),
        # ── HA-DSGE node (C040 / MEMs 0.6.7) ──
        # estimate deferred: MEMs#228 (observables mapped to arbitrary reduced states)
        CommandSpec(
            path=["dsge", "ha", "solve"],
            summary="Solve HA-DSGE (SSJ / Reiter / Krusell-Smith)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin (huggett|krusell-smith|one-asset-hank|two-asset-hank) or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="ssj",
                           description="HA solution method: ssj|reiter|krusell-smith",
                           choices=["ssj", "reiter", "krusell-smith"]),
                OptionSpec(name="n-reduced", type=Int, default=30,
                           description="Reduced distribution states (SSJ/Reiter)"),
                OptionSpec(name="t-horizon", type=Int, default=300,
                           description="Sequence-space horizon (SSJ)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:diagnostics, description="Solution diagnostics"),
                TableSpec(name=:aggregates, description="Steady-state aggregates"),
                TableSpec(name=:prices, description="Steady-state prices"),
            ],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_solve),
        ),
        CommandSpec(
            path=["dsge", "ha", "steady-state"],
            summary="Compute HA-DSGE stationary equilibrium",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:aggregates, description="Steady-state aggregates"),
                TableSpec(name=:prices, description="Steady-state prices"),
                TableSpec(name=:diagnostics, description="Convergence diagnostics"),
            ],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_steady_state),
        ),
        CommandSpec(
            path=["dsge", "ha", "irf"],
            summary="Aggregate IRFs from linearized HA-DSGE solution",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="reiter",
                           description="HA solution method: ssj|reiter (krusell-smith has no linear IRF)",
                           choices=["ssj", "reiter"]),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="n-reduced", type=Int, default=30, description="Reduced states"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
            ],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=:irf, description="Aggregate impulse responses")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_irf),
        ),
        CommandSpec(
            path=["dsge", "ha", "fevd"],
            summary="Aggregate FEVD from linearized HA-DSGE solution",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="reiter",
                           description="HA solution method: ssj|reiter",
                           choices=["ssj", "reiter"]),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="FEVD horizon"),
                OptionSpec(name="n-reduced", type=Int, default=30, description="Reduced states"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
            ],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=:fevd, description="Forecast error variance decomposition")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_fevd),
        ),
        CommandSpec(
            path=["dsge", "ha", "simulate"],
            summary="Simulate aggregate paths from linearized HA-DSGE",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="reiter",
                           description="HA solution method: ssj|reiter",
                           choices=["ssj", "reiter"]),
                OptionSpec(name="periods", type=Int, default=200, description="Simulation periods"),
                OptionSpec(name="seed", type=Int, default=0, description="Random seed (0=no seed)"),
                OptionSpec(name="n-reduced", type=Int, default=30, description="Reduced states"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
            ],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=:simulate, description="Simulated aggregate deviations")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_simulate),
        ),
        CommandSpec(
            path=["dsge", "ha", "distribution-irf"],
            summary="Wealth distribution IRF after an aggregate shock (Reiter only)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="reiter",
                           description="Must be reiter (SSJ has no distribution basis)",
                           choices=["reiter"]),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="shock-index", type=Int, default=1, description="Aggregate shock index (1-based)"),
                OptionSpec(name="shock-size", type=Float64, default=1.0, description="Shock size (std devs)"),
                OptionSpec(name="n-reduced", type=Int, default=30, description="Reduced states"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:distribution_irf, description="Distribution mass deviations (summary moments)")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_distribution_irf),
        ),
        CommandSpec(
            path=["dsge", "ha", "inequality-irf"],
            summary="Gini and wealth-percentile IRFs after an aggregate shock",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="reiter",
                           description="Must be reiter for dynamic inequality IRF",
                           choices=["reiter"]),
                OptionSpec(name="horizon", short="h", type=Int, default=40, description="IRF horizon"),
                OptionSpec(name="shock-index", type=Int, default=1, description="Aggregate shock index (1-based)"),
                OptionSpec(name="shock-size", type=Float64, default=1.0, description="Shock size (std devs)"),
                OptionSpec(name="n-reduced", type=Int, default=30, description="Reduced states"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
            ],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=:inequality_irf, description="Gini and percentile paths")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_inequality_irf),
        ),
        CommandSpec(
            path=["dsge", "ha", "simulate-panel"],
            summary="Simulate individual asset holdings from steady-state policies",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="n-agents", type=Int, default=1000, description="Number of agents"),
                OptionSpec(name="periods", type=Int, default=100, description="Time periods"),
                OptionSpec(name="seed", type=Int, default=0, description="Random seed (0=no seed)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:panel, description="Panel summary (mean assets over time)")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_simulate_panel),
        ),
        # ── Continuous-time HA (C041) ──
        CommandSpec(
            path=["dsge", "ct", "solve"],
            summary="Continuous-time Aiyagari (or two-asset KMV) stationary equilibrium",
            args=ArgSpec[],
            options=[
                OptionSpec(name="alpha", type=Float64, default=0.36, description="Capital share"),
                OptionSpec(name="rho", type=Float64, default=0.05, description="Discount rate"),
                OptionSpec(name="sigma", type=Float64, default=2.0, description="CRRA risk aversion"),
                OptionSpec(name="delta", type=Float64, default=0.05, description="Depreciation"),
                OptionSpec(name="z", type=Float64, default=1.0, description="TFP level"),
                OptionSpec(name="a-min", type=Float64, default=0.0, description="Asset grid lower bound"),
                OptionSpec(name="a-max", type=Float64, default=30.0, description="Asset grid upper bound"),
                OptionSpec(name="grid-size", type=Int, default=100, description="Asset grid points (I)"),
                OptionSpec(name="max-iter", type=Int, default=100, description="Outer equilibrium iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-6, description="Convergence tolerance"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=[
                FlagSpec(name="two-asset", description="Solve Kaplan-Moll-Violante two-asset model instead"),
            ],
            tables=[
                TableSpec(name=:prices, description="Equilibrium r, w"),
                TableSpec(name=:aggregates, description="K, L and convergence"),
            ],
            category="dsge",
            handler=wrap_legacy(_dsge_ct_solve),
        ),
        CommandSpec(
            path=["dsge", "ct", "transition"],
            summary="MIT-shock perfect-foresight transition (ct_mit_shock)",
            args=ArgSpec[],
            options=[
                OptionSpec(name="alpha", type=Float64, default=0.36, description="Capital share"),
                OptionSpec(name="rho", type=Float64, default=0.05, description="Discount rate"),
                OptionSpec(name="sigma", type=Float64, default=2.0, description="CRRA risk aversion"),
                OptionSpec(name="delta", type=Float64, default=0.05, description="Depreciation"),
                OptionSpec(name="z", type=Float64, default=1.0, description="Steady-state TFP"),
                OptionSpec(name="shock-size", type=Float64, default=0.95, description="Impact TFP multiplier (Z_0 = shock-size * z)"),
                OptionSpec(name="periods", type=Int, default=40, description="Transition length (time points)"),
                OptionSpec(name="dt", type=Float64, default=0.25, description="Time step"),
                OptionSpec(name="a-max", type=Float64, default=30.0, description="Asset grid upper bound"),
                OptionSpec(name="grid-size", type=Int, default=100, description="Asset grid points"),
                OptionSpec(name="max-iter", type=Int, default=100, description="Shooting iterations"),
                OptionSpec(name="tol", type=Float64, default=1e-6, description="Convergence tolerance"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
            ],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=:transition, description="MIT-shock path (t, Z, K, r, w, C)")],
            category="dsge",
            handler=wrap_legacy(_dsge_ct_transition),
        ),
        # ── Blanchard OLG (C041) ──
        CommandSpec(
            path=["dsge", "olg", "solve"],
            summary="Blanchard perpetual-youth OLG: steady state + saddle path",
            args=ArgSpec[],
            options=[
                OptionSpec(name="alpha", type=Float64, default=0.36, description="Capital share"),
                OptionSpec(name="beta", type=Float64, default=0.96, description="Discount factor"),
                OptionSpec(name="delta", type=Float64, default=0.08, description="Depreciation"),
                OptionSpec(name="gamma", type=Float64, default=0.98, description="Survival probability"),
                OptionSpec(name="z", type=Float64, default=1.0, description="TFP"),
                OptionSpec(name="debt", type=Float64, default=0.0, description="Government debt b (see MEMs#237 if b≠0)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:steady_state, description="Steady-state levels"),
                TableSpec(name=:dynamics, description="Saddle-path diagnostics"),
            ],
            category="dsge",
            handler=wrap_legacy(_dsge_olg_solve),
        ),
        CommandSpec(
            path=["dsge", "olg", "simulate"],
            summary="Blanchard OLG transitional dynamics from k0 along the saddle path",
            args=ArgSpec[],
            options=[
                OptionSpec(name="alpha", type=Float64, default=0.36, description="Capital share"),
                OptionSpec(name="beta", type=Float64, default=0.96, description="Discount factor"),
                OptionSpec(name="delta", type=Float64, default=0.08, description="Depreciation"),
                OptionSpec(name="gamma", type=Float64, default=0.98, description="Survival probability"),
                OptionSpec(name="z", type=Float64, default=1.0, description="TFP"),
                OptionSpec(name="debt", type=Float64, default=0.0, description="Government debt b"),
                OptionSpec(name="k0", type=Float64, default=0.0,
                           description="Initial capital (0 = 80% of steady-state k)"),
                OptionSpec(name="horizon", short="h", type=Int, default=50, description="Transition periods H"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file"),
            ],
            flags=[FlagSpec(name="plot", description="Open interactive plot in browser")],
            tables=[TableSpec(name=:path, description="Transition paths k, C, r, w")],
            category="dsge",
            handler=wrap_legacy(_dsge_olg_simulate),
        ),
    ]
end

function register_dsge_commands!()
    # --save-model only on solve (estimate already covered under estimate command)
    specs = map(dsge_specs()) do s
        s.path == ["dsge", "solve"] ? with_save_model([s])[1] : s
    end
    register!(specs)
    return build_node("dsge", specs; description="DSGE models: RA, Bayesian, HA, CT, OLG")
end


# ── Implemented Handlers ─────────────────────────────────────

function _dsge_solve(; model::String, method::String="gensys", order::Int=1,
                      degree::Int=5, grid::String="auto",
                      constraints::String="", constraint_solver::String="",
                      periods::Int=40,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    if !isempty(constraint_solver) && !(constraint_solver in ("nonlinearsolve", "optim", "nlopt", "ipopt", "path"))
        error("invalid --constraint-solver value '$constraint_solver'; must be one of: nonlinearsolve, optim, nlopt, ipopt, path")
    end

    spec = _load_dsge_model(model)

    if !isempty(constraints)
        cons = _load_dsge_constraints(constraints; spec=spec)
        if isempty(constraint_solver)
            # Default: OccBin path (backward compatible)
            _status("\nSolving with OccBin constraints...")
            sol = _solve_dsge(spec; method=method, order=order, degree=degree, grid=grid)
            shocks = zeros(Float64, periods, spec.n_exog)
            shocks[1, 1] = 1.0
            ob_sol = occbin_solve(spec, shocks, cons; T_periods=periods)

            _maybe_plot(ob_sol; plot=plot, plot_save=plot_save)

            path_df = DataFrame()
            path_df.period = 1:periods
            for (vi, vname) in enumerate(spec.varnames)
                if vi <= size(ob_sol.piecewise_path, 2)
                    path_df[!, vname] = ob_sol.piecewise_path[:, vi]
                end
            end
            output_result(path_df; format=Symbol(format), output=output,
                          title="DSGE OccBin Solution ($(length(cons)) constraint(s), T=$periods)")
            return
        else
            # New solver hierarchy path
            _status("\nSolving with constraint-solver=$constraint_solver...")
            sol = _solve_dsge(spec; method=method, order=order, degree=degree,
                              grid=grid, constraint_solver=constraint_solver)
        end
    else
        sol = _solve_dsge(spec; method=method, order=order, degree=degree, grid=grid,
                          constraint_solver=constraint_solver)
    end

    # Standard solve output
    if sol isa MacroEconometricModels.DSGESolution
        n = spec.n_endog
        policy_df = DataFrame()
        policy_df.variable = spec.varnames
        for (vi, vname) in enumerate(spec.varnames)
            if vi <= size(sol.G1, 2)
                policy_df[!, "G1_$vname"] = sol.G1[:, vi]
            end
        end
        output_result(policy_df; format=Symbol(format), output=output,
                      title="DSGE Solution (method=$method)")
    elseif sol isa MacroEconometricModels.PerturbationSolution
        n_s = length(sol.state_indices)
        n_c = length(sol.control_indices)
        _status("\n  State variables ($n_s): $(join([spec.varnames[i] for i in sol.state_indices], ", "))")
        _status("  Control variables ($n_c): $(join([spec.varnames[i] for i in sol.control_indices], ", "))")

        gx_df = DataFrame(sol.gx, [spec.varnames[i] for i in sol.state_indices])
        insertcols!(gx_df, 1, :control => [spec.varnames[i] for i in sol.control_indices])
        output_result(gx_df; format=Symbol(format), output=output,
                      title="Perturbation Policy (gx, order=$order)")
    elseif sol isa MacroEconometricModels.ProjectionSolution
        _status("\n  Grid type: $(sol.grid_type), Degree: $(sol.degree)")
        _status("  Converged: $(sol.converged), Iterations: $(sol.iterations)")
        _status_styled("  Residual norm: $(round(sol.residual_norm; sigdigits=4))\n";
                    color = sol.residual_norm < 1e-6 ? :green : :yellow)

        coef_df = DataFrame(sol.coefficients,
                           ["basis_$i" for i in 1:size(sol.coefficients, 2)])
        insertcols!(coef_df, 1, :control => [spec.varnames[i] for i in sol.control_indices])
        output_result(coef_df; format=Symbol(format), output=output,
                      title="Projection Solution (degree=$(sol.degree), grid=$(sol.grid_type))")
    end
    _status()
    return sol  # for --save-model (C029)
end

function _dsge_steady_state(; model::String, constraints::String="",
                             constraint_solver::String="",
                             output::String="", format::String="table")
    if !isempty(constraint_solver) && !(constraint_solver in ("nonlinearsolve", "optim", "nlopt", "ipopt", "path"))
        error("invalid --constraint-solver value '$constraint_solver'; must be one of: nonlinearsolve, optim, nlopt, ipopt, path")
    end

    spec = _load_dsge_model(model)

    solver_kw = isempty(constraint_solver) ? (;) : (; solver=Symbol(constraint_solver))
    if !isempty(constraints)
        cons = _load_dsge_constraints(constraints; spec=spec)
        spec = compute_steady_state(spec; constraints=cons, solver_kw...)
    else
        spec = compute_steady_state(spec; solver_kw...)
    end

    ss_df = DataFrame(
        variable = spec.varnames,
        steady_state = spec.steady_state
    )
    output_result(ss_df; format=Symbol(format), output=output,
                  title="DSGE Steady State")
end

function _dsge_simulate(; model::String, method::String="gensys", order::Int=1,
                         periods::Int=200, burn::Int=100,
                         antithetic::Bool=false, seed::Int=0,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    _status("Simulating $(periods + burn) periods (burn-in=$burn)...")

    if seed > 0
        sim = simulate(sol, periods + burn; antithetic=antithetic, rng=Random.MersenneTwister(seed))
    else
        sim = simulate(sol, periods + burn; antithetic=antithetic)
    end

    # Drop burn-in
    sim_data = sim[burn+1:end, :]

    sim_df = DataFrame(sim_data, spec.varnames)
    insertcols!(sim_df, 1, :period => 1:periods)

    _maybe_plot(sim_df; plot=plot, plot_save=plot_save)

    output_result(sim_df; format=Symbol(format), output=output,
                  title="DSGE Simulation (method=$method, T=$periods)")
end

# ── IRF / FEVD / Estimate / Perfect Foresight ──────────────────

function _dsge_irf(; model::String, method::String="gensys", order::Int=1,
                    horizon::Int=40, shock_size::Float64=1.0, n_sim::Int=500,
                    constraints::String="",
                    output::String="", format::String="table",
                    plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    if !isempty(constraints)
        _status("\nComputing OccBin IRF...")
        cons = _load_dsge_constraints(constraints)
        ob_irf = occbin_irf(spec, cons, 1; shock_size=shock_size, horizon=horizon)

        _maybe_plot(ob_irf; plot=plot, plot_save=plot_save)

        n_h = size(ob_irf.piecewise, 1)
        for (vi, vname) in enumerate(spec.varnames)
            vi > size(ob_irf.piecewise, 2) && break
            irf_df = DataFrame(
                horizon = 0:(n_h - 1),
                linear = ob_irf.linear[:, vi, 1],
                piecewise = ob_irf.piecewise[:, vi, 1],
            )
            output_result(irf_df; format=Symbol(format),
                          output=_per_var_output_path(output, vname),
                          title="OccBin IRF: $vname ← $(ob_irf.shock_name)")
        end
        return
    end

    _status("\nComputing IRF: horizon=$horizon, shock_size=$shock_size")
    irf_result = irf(sol, horizon; shock_size=shock_size, n_sim=n_sim)

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    irf_vals = irf_result.values
    n_h = size(irf_vals, 1)
    ne = nshocks(sol)
    for si in 1:ne
        shock_name = si <= spec.n_exog ? String(spec.exog[si]) : "shock_$si"
        irf_df = DataFrame()
        irf_df.horizon = 0:(n_h - 1)
        for (vi, vname) in enumerate(spec.varnames)
            vi > size(irf_vals, 2) && break
            si > size(irf_vals, 3) && break
            irf_df[!, vname] = irf_vals[:, vi, si]
        end
        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock_name),
                      title="DSGE IRF: shock=$shock_name (method=$method, h=$horizon)")
    end
end

function _dsge_fevd(; model::String, method::String="gensys", order::Int=1,
                     horizon::Int=40, unconditional::Bool=false,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    if unconditional
        # MEMs: unconditional FEVD is only defined for PerturbationSolution with order ≥ 2
        if !(sol isa MacroEconometricModels.PerturbationSolution)
            throw(CliError("usage/invalid-option",
                "--unconditional requires --method=perturbation (got solution type $(typeof(sol).name.name))"))
        end
        if sol.order < 2
            throw(CliError("usage/invalid-option",
                "--unconditional requires --order ≥ 2 (got order=$(sol.order))"))
        end
        _status("\nComputing unconditional FEVD (order=$(sol.order) perturbation)")
        fevd_result = fevd(sol, horizon; unconditional=true)
    else
        _status("\nComputing FEVD: horizon=$horizon")
        fevd_result = fevd(sol, horizon)
    end

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    n_v = size(fevd_result.proportions, 1)
    ne = size(fevd_result.proportions, 2)
    n_h = size(fevd_result.proportions, 3)

    mode_label = unconditional ? "unconditional" : "method=$method, h=$horizon"
    for vi in 1:min(n_v, length(spec.varnames))
        vname = spec.varnames[vi]
        fevd_df = DataFrame()
        fevd_df.horizon = 1:n_h
        for si in 1:ne
            shock_name = si <= spec.n_exog ? String(spec.exog[si]) : "shock_$si"
            fevd_df[!, shock_name] = fevd_result.proportions[vi, si, :]
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="DSGE FEVD: $vname ($mode_label)")
    end
end

function _dsge_estimate(; model::String, data::String="", method::String="irf_matching",
                         params::String="", solve_method::String="gensys", solve_order::Int=1,
                         weighting::String="optimal",
                         irf_horizon::Int=20, var_lags::Int=4,
                         sim_ratio::Int=5, bounds::String="",
                         output::String="", format::String="table")
    isempty(data) && error("--data/-d is required for DSGE estimation")
    isempty(params) && error("--params is required (comma-separated parameter names)")

    spec = _load_dsge_model(model)
    Y, varnames = load_multivariate_data(data)
    param_names = [strip(s) for s in split(params, ",") if !isempty(strip(s))]

    isempty(param_names) && error("--params is required (comma-separated parameter names)")

    _status("Estimating DSGE model: method=$method, params=$(join(param_names, ", "))")
    _status("  Data: $(size(Y, 1)) obs × $(size(Y, 2)) vars")
    _status("  Solver: $solve_method, order=$solve_order")
    _status()

    est = estimate_dsge(spec, Y, param_names;
                        method=Symbol(method), solve_method=Symbol(solve_method),
                        solve_order=solve_order, weighting=Symbol(weighting),
                        irf_horizon=irf_horizon, var_lags=var_lags,
                        sim_ratio=sim_ratio)

    se = sqrt.(abs.(diag(est.vcov)))
    t_stats = est.theta ./ se
    p_vals = [2.0 * (1.0 - _normal_cdf(abs(t))) for t in t_stats]

    est_df = DataFrame(
        parameter = est.param_names,
        estimate = round.(est.theta; digits=6),
        std_error = round.(se; digits=6),
        t_stat = round.(t_stats; digits=4),
        p_value = round.(p_vals; digits=4),
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="DSGE Estimation ($method)")

    _status()
    _status_styled("  J-statistic: $(round(est.J_stat; digits=4))\n"; color=:cyan)
    _status_styled("  J p-value:   $(round(est.J_pvalue; digits=4))\n"; color=:cyan)
    _status_styled("  Converged:   $(est.converged)\n";
                color = est.converged ? :green : :red)
end

function _dsge_perfect_foresight(; model::String, shocks::String="",
                                  constraints::String="", constraint_solver::String="",
                                  periods::Int=100,
                                  output::String="", format::String="table",
                                  plot::Bool=false, plot_save::String="")
    isempty(shocks) && error("--shocks is required (path to shock CSV)")
    if !isempty(constraint_solver) && !(constraint_solver in ("nonlinearsolve", "optim", "nlopt", "ipopt", "path"))
        error("invalid --constraint-solver value '$constraint_solver'; must be one of: nonlinearsolve, optim, nlopt, ipopt, path")
    end

    spec = _load_dsge_model(model)

    shock_df = load_data(shocks)
    shock_mat = df_to_matrix(shock_df)

    _status("Computing perfect foresight transition path...")
    _status("  Shock periods: $(size(shock_mat, 1)), transition periods: $periods")
    _status()

    solver_kw = isempty(constraint_solver) ? (;) : (; solver=Symbol(constraint_solver))
    cons_kw = if !isempty(constraints)
        cons = _load_dsge_constraints(constraints; spec=spec)
        (; constraints=cons)
    else
        (;)
    end
    pf = perfect_foresight(spec; shocks=shock_mat, T_periods=periods, solver_kw..., cons_kw...)

    _maybe_plot(pf; plot=plot, plot_save=plot_save)

    path_df = DataFrame()
    n_periods = size(pf.path, 1)
    path_df.period = 1:n_periods
    for (vi, vname) in enumerate(spec.varnames)
        if vi <= size(pf.path, 2)
            path_df[!, vname] = pf.path[:, vi]
        end
    end

    output_result(path_df; format=Symbol(format), output=output,
                  title="Perfect Foresight Path (T=$n_periods, converged=$(pf.converged))")
end

# ── Bayesian DSGE Handlers ─────────────────────────────────────

"""Shared helper: run Bayesian DSGE estimation and return the result."""
function _dsge_bayes_run_estimation(; model::String, data::String, params::String,
        priors::String, sampler::String, n_smc::Int, n_particles::Int,
        n_draws::Int, burnin::Int, ess_target::Float64, observables::String,
        solver::String, order::Int, delayed_acceptance::Bool,
        constraint_solver::String="")
    isempty(data) && error("--data is required")
    isempty(params) && error("--params is required (comma-separated parameter names)")
    isempty(priors) && error("--priors is required (path to priors TOML)")

    if !isempty(constraint_solver) && !(constraint_solver in ("nonlinearsolve", "optim", "nlopt", "ipopt", "path"))
        error("invalid --constraint-solver value '$constraint_solver'; must be one of: nonlinearsolve, optim, nlopt, ipopt, path")
    end

    spec = _load_dsge_model(model)

    df = load_data(data)
    Y = df_to_matrix(df)

    param_names = [strip(p) for p in split(params, ",")]
    theta0 = ones(Float64, length(param_names)) * 0.5

    priors_config = load_config(priors)
    priors_dict = get_dsge_priors(priors_config)

    obs_syms = isempty(observables) ? Symbol[] : Symbol.(strip.(split(observables, ",")))

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Bayesian DSGE Estimation:")
    _status("  Sampler: $sampler")
    _status("  Parameters: $(join(param_names, ", "))")
    _status("  Data: $(size(Y, 1)) obs × $(size(Y, 2)) vars")
    _status("  Solver: $solver" * (order > 1 ? ", order=$order" : ""))
    _status()

    solver_obj_kw = isempty(constraint_solver) ? (;) : (; solver_obj=Symbol(constraint_solver))
    result = estimate_dsge_bayes(spec, Y, theta0;
        priors=priors_dict, method=Symbol(sampler),
        observables=obs_syms,
        n_smc=n_smc, n_particles=n_particles,
        n_draws=n_draws, burnin=burnin, ess_target=ess_target,
        solver=Symbol(solver), solver_kwargs=solver_kwargs,
        delayed_acceptance=delayed_acceptance, solver_obj_kw...)

    return result
end

function _dsge_bayes_estimate(; model::String, data::String="", params::String="",
                               priors::String="", sampler::String="smc",
                               n_smc::Int=5000, n_particles::Int=500,
                               n_draws::Int=10000, burnin::Int=5000,
                               ess_target::Float64=0.5, observables::String="",
                               solver::String="gensys", order::Int=1,
                               constraint_solver::String="",
                               delayed_acceptance::Bool=false,
                               output::String="", format::String="table")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    # Posterior summary table
    draws = result.theta_draws
    np = size(draws, 2)
    est_df = DataFrame(
        parameter = result.param_names,
        mean = [round(mean(draws[:, i]); digits=6) for i in 1:np],
        std = [round(sqrt(var(draws[:, i])); digits=6) for i in 1:np],
        q05 = [round(quantile(draws[:, i], 0.05); digits=6) for i in 1:np],
        median = [round(median(draws[:, i]); digits=6) for i in 1:np],
        q95 = [round(quantile(draws[:, i], 0.95); digits=6) for i in 1:np],
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="Bayesian DSGE Posterior ($sampler)")

    _status()
    _status_styled("  Log marginal likelihood: $(round(result.log_marginal_likelihood; digits=4))\n"; color=:cyan)
    _status_styled("  Acceptance rate: $(round(result.acceptance_rate; digits=4))\n"; color=:cyan)
    _status_styled("  Method: $(result.method)\n"; color=:cyan)
end

function _dsge_bayes_irf(; model::String, data::String="", params::String="",
                          priors::String="", sampler::String="smc",
                          n_smc::Int=5000, n_particles::Int=500,
                          n_draws::Int=10000, burnin::Int=5000,
                          ess_target::Float64=0.5, observables::String="",
                          solver::String="gensys", order::Int=1,
                          constraint_solver::String="",
                          delayed_acceptance::Bool=false,
                          horizon::Int=40,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Computing Bayesian DSGE IRF: horizon=$horizon")
    irf_result = irf(result, horizon; n_draws=n_draws,
        solver=Symbol(solver), solver_kwargs=solver_kwargs)

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    n_h = size(irf_result.mean, 1)
    ns = size(irf_result.mean, 3)
    varnames = irf_result.variables
    for si in 1:ns
        shock_name = si <= length(irf_result.shocks) ? irf_result.shocks[si] : "shock_$si"
        irf_df = DataFrame()
        irf_df.horizon = 0:(n_h - 1)
        for (vi, vname) in enumerate(varnames)
            vi > size(irf_result.mean, 2) && break
            irf_df[!, vname] = irf_result.mean[:, vi, si]
        end
        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock_name),
                      title="Bayesian DSGE IRF: shock=$shock_name ($sampler, h=$horizon)")
    end
end

function _dsge_bayes_fevd(; model::String, data::String="", params::String="",
                           priors::String="", sampler::String="smc",
                           n_smc::Int=5000, n_particles::Int=500,
                           n_draws::Int=10000, burnin::Int=5000,
                           ess_target::Float64=0.5, observables::String="",
                           solver::String="gensys", order::Int=1,
                           constraint_solver::String="",
                           delayed_acceptance::Bool=false,
                           horizon::Int=40,
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Computing Bayesian DSGE FEVD: horizon=$horizon")
    fevd_result = fevd(result, horizon; n_draws=n_draws,
        solver=Symbol(solver), solver_kwargs=solver_kwargs)

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    n_v = size(fevd_result.mean, 2)
    ns = size(fevd_result.mean, 3)
    n_h = size(fevd_result.mean, 1)
    varnames = fevd_result.variables
    for vi in 1:min(n_v, length(varnames))
        vname = varnames[vi]
        fevd_df = DataFrame()
        fevd_df.horizon = 1:n_h
        for si in 1:ns
            shock_name = si <= length(fevd_result.shocks) ? fevd_result.shocks[si] : "shock_$si"
            fevd_df[!, shock_name] = fevd_result.mean[:, vi, si]
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="Bayesian DSGE FEVD: $vname ($sampler, h=$horizon)")
    end
end

function _dsge_bayes_simulate(; model::String, data::String="", params::String="",
                               priors::String="", sampler::String="smc",
                               n_smc::Int=5000, n_particles::Int=500,
                               n_draws::Int=10000, burnin::Int=5000,
                               ess_target::Float64=0.5, observables::String="",
                               solver::String="gensys", order::Int=1,
                               constraint_solver::String="",
                               delayed_acceptance::Bool=false,
                               periods::Int=200,
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Simulating from Bayesian DSGE posterior: T=$periods")
    sim = simulate(result, periods; n_draws=n_draws,
        solver=Symbol(solver), solver_kwargs=solver_kwargs)

    _maybe_plot(sim; plot=plot, plot_save=plot_save)

    varnames = sim.variables
    sim_df = DataFrame()
    sim_df.period = 1:periods
    for (vi, vname) in enumerate(varnames)
        vi > size(sim.point_estimate, 2) && break
        sim_df[!, vname] = sim.point_estimate[:, vi]
    end
    output_result(sim_df; format=Symbol(format), output=output,
                  title="Bayesian DSGE Simulation ($sampler, T=$periods)")
end

function _dsge_bayes_summary(; model::String, data::String="", params::String="",
                              priors::String="", sampler::String="smc",
                              n_smc::Int=5000, n_particles::Int=500,
                              n_draws::Int=10000, burnin::Int=5000,
                              ess_target::Float64=0.5, observables::String="",
                              solver::String="gensys", order::Int=1,
                              constraint_solver::String="",
                              delayed_acceptance::Bool=false,
                              output::String="", format::String="table")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    summary = posterior_summary(result)
    pp_table = prior_posterior_table(result)

    # Posterior summary table
    pnames = result.param_names
    sum_df = DataFrame(
        parameter = pnames,
        mean = [round(summary[p][:mean]; digits=6) for p in pnames],
        median = [round(summary[p][:median]; digits=6) for p in pnames],
        std = [round(summary[p][:std]; digits=6) for p in pnames],
        q05 = [round(summary[p][:q05]; digits=6) for p in pnames],
        q95 = [round(summary[p][:q95]; digits=6) for p in pnames],
    )
    output_result(sum_df; format=Symbol(format), output=output,
                  title="Bayesian DSGE Posterior Summary ($sampler)")

    # Prior-posterior comparison
    pp_df = DataFrame(
        parameter = [r.param for r in pp_table],
        prior_mean = [round(r.prior_mean; digits=6) for r in pp_table],
        prior_std = [round(r.prior_std; digits=6) for r in pp_table],
        post_mean = [round(r.post_mean; digits=6) for r in pp_table],
        post_std = [round(r.post_std; digits=6) for r in pp_table],
        post_q05 = [round(r.post_q05; digits=6) for r in pp_table],
        post_q95 = [round(r.post_q95; digits=6) for r in pp_table],
    )
    output_result(pp_df; format=Symbol(format),
                  output=_per_var_output_path(output, "prior_posterior"),
                  title="Prior vs Posterior Comparison")

    _status()
    _status_styled("  Log marginal likelihood: $(round(result.log_marginal_likelihood; digits=4))\n"; color=:cyan)
    _status_styled("  Acceptance rate: $(round(result.acceptance_rate; digits=4))\n"; color=:cyan)
end

function _dsge_bayes_compare(; model::String, data::String="", params::String="",
                              priors::String="", sampler::String="smc",
                              n_smc::Int=5000, n_particles::Int=500,
                              n_draws::Int=10000, burnin::Int=5000,
                              ess_target::Float64=0.5, observables::String="",
                              solver::String="gensys", order::Int=1,
                              constraint_solver::String="",
                              delayed_acceptance::Bool=false,
                              model2::String="", params2::String="", priors2::String="",
                              output::String="", format::String="table")
    isempty(model2) && error("--model2 is required for model comparison")
    isempty(params2) && error("--params2 is required for model comparison")
    isempty(priors2) && error("--priors2 is required for model comparison")

    _status("Estimating Model 1...")
    r1 = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    _status("Estimating Model 2...")
    r2 = _dsge_bayes_run_estimation(; model=model2, data, params=params2,
        priors=priors2, sampler, n_smc, n_particles, n_draws, burnin,
        ess_target, observables, solver, order, delayed_acceptance, constraint_solver)

    bf = bayes_factor(r1, r2)

    comp_df = DataFrame(
        model = ["Model 1", "Model 2"],
        log_marginal_likelihood = [round(r1.log_marginal_likelihood; digits=4),
                                   round(r2.log_marginal_likelihood; digits=4)],
        acceptance_rate = [round(r1.acceptance_rate; digits=4),
                          round(r2.acceptance_rate; digits=4)],
    )
    output_result(comp_df; format=Symbol(format), output=output,
                  title="Bayesian Model Comparison")

    _status()
    _status_styled("  Bayes factor (M1 vs M2): $(round(bf; digits=4))\n"; color=:cyan)
    _status_styled("  Log Bayes factor: $(round(log(bf); digits=4))\n"; color=:cyan)
    if bf > 1
        _status_styled("  Evidence favors Model 1\n"; color=:green)
    else
        _status_styled("  Evidence favors Model 2\n"; color=:yellow)
    end
end

function _dsge_bayes_predictive(; model::String, data::String="", params::String="",
                                 priors::String="", sampler::String="smc",
                                 n_smc::Int=5000, n_particles::Int=500,
                                 n_draws::Int=10000, burnin::Int=5000,
                                 ess_target::Float64=0.5, observables::String="",
                                 solver::String="gensys", order::Int=1,
                                 constraint_solver::String="",
                                 delayed_acceptance::Bool=false,
                                 n_sim::Int=500, periods::Int=100,
                                 output::String="", format::String="table",
                                 plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    _status("Generating posterior predictive simulations: n=$n_sim, T=$periods")
    pp = posterior_predictive(result, n_sim; T_periods=periods)

    _maybe_plot(pp; plot=plot, plot_save=plot_save)

    # Summary statistics across simulations
    nv = size(pp, 3)
    varnames = result.param_names
    pp_df = DataFrame(
        variable = varnames[1:min(nv, length(varnames))],
        mean = [round(mean(pp[:, :, vi]); digits=6) for vi in 1:min(nv, length(varnames))],
        std = [round(sqrt(var(vec(pp[:, :, vi]))); digits=6) for vi in 1:min(nv, length(varnames))],
        min = [round(minimum(pp[:, :, vi]); digits=6) for vi in 1:min(nv, length(varnames))],
        max = [round(maximum(pp[:, :, vi]); digits=6) for vi in 1:min(nv, length(varnames))],
    )
    output_result(pp_df; format=Symbol(format), output=output,
                  title="Posterior Predictive Summary ($sampler, n=$n_sim, T=$periods)")
end

function _dsge_hd(; model::String, data::String="", observables::String="",
                   states::String="observables",
                   measurement_error::String="",
                   output::String="", format::String="table",
                   plot::Bool=false, plot_save::String="")
    isempty(data) && error("--data is required for DSGE historical decomposition")
    isempty(observables) && error("--observables is required (comma-separated variable names)")

    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec)

    df = load_data(data)
    Y = df_to_matrix(df)
    obs_syms = Symbol[Symbol(strip(s)) for s in split(observables, ",")]

    _status("DSGE Historical Decomposition")
    _status("  Model: $model")
    _status("  Observations: $(size(Y, 1)), Observable variables: $(length(obs_syms))")
    _status("  States: $states")
    _status()

    me = if isempty(measurement_error)
        nothing
    elseif measurement_error == "auto"
        :auto
    else
        [parse(Float64, strip(s)) for s in split(measurement_error, ",")]
    end

    hd = historical_decomposition(sol, Y, obs_syms;
        states=Symbol(states), measurement_error=me)

    ok = verify_decomposition(hd)
    ok && _status_styled("  Decomposition verified\n"; color=:green)

    for (si, sname) in enumerate(hd.shock_names)
        contrib = hd.contributions[:, :, si]
        contrib_df = DataFrame(contrib, hd.variables)
        insertcols!(contrib_df, 1, :t => 1:hd.T_eff)
        output_result(contrib_df; format=Symbol(format), output=output,
            title="Shock: $sname contributions")
    end

    _maybe_plot(hd; plot=plot, plot_save=plot_save)
    return hd
end

function _dsge_bayes_hd(; model::String, data::String="", params::String="",
                         priors::String="", observables::String="",
                         sampler::String="smc", n_smc::Int=5000,
                         n_particles::Int=500,
                         n_draws::Int=10000, burnin::Int=5000,
                         ess_target::Float64=0.5,
                         solver::String="gensys", order::Int=1,
                         constraint_solver::String="",
                         n_hd_draws::Int=200, quantiles::String="0.16,0.5,0.84",
                         mode_only::Bool=false,
                         delayed_acceptance::Bool=false,
                         horizon::Int=40,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    isempty(observables) && error("--observables is required (comma-separated variable names)")

    bd = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver)

    df = load_data(data)
    Y = df_to_matrix(df)
    obs_syms = Symbol[Symbol(strip(s)) for s in split(observables, ",")]
    q_levels = [parse(Float64, strip(s)) for s in split(quantiles, ",")]

    _status("Historical Decomposition from Bayesian DSGE posterior")
    _status()

    hd = historical_decomposition(bd, Y, obs_syms;
        mode_only=mode_only, n_draws=n_hd_draws, quantiles=q_levels)

    for (si, sname) in enumerate(hd.shock_names)
        pe = hd.point_estimate[:, :, si]
        pe_df = DataFrame(pe, hd.variables)
        insertcols!(pe_df, 1, :t => 1:hd.T_eff)
        output_result(pe_df; format=Symbol(format), output=output,
            title="Shock: $sname (posterior mean)")
    end

    _maybe_plot(hd; plot=plot, plot_save=plot_save)
    return hd
end

# ── HA-DSGE handlers (C040) ─────────────────────────────────

function _ha_ss_tables(ss; format::String, output::String, title_prefix::String="HA")
    agg = ss.aggregates
    prices = ss.prices
    if agg isa AbstractDict
        agg_df = DataFrame(
            name = String[string(k) for k in keys(agg)],
            value = [Float64(v) for v in values(agg)],
        )
    else
        agg_df = DataFrame(name=String[], value=Float64[])
    end
    if prices isa AbstractDict
        price_df = DataFrame(
            name = String[string(k) for k in keys(prices)],
            value = [Float64(v) for v in values(prices)],
        )
    else
        price_df = DataFrame(name=String[], value=Float64[])
    end
    diag_df = DataFrame(
        metric = ["converged", "iterations", "euler_error", "excess_demand"],
        value = [
            Float64(ss.converged ? 1.0 : 0.0),
            Float64(ss.iterations),
            Float64(ss.euler_error),
            Float64(ss.excess_demand),
        ],
    )
    output_result(agg_df; format=Symbol(format), output=output,
                  title="$title_prefix Steady-State Aggregates")
    output_result(price_df; format=Symbol(format), output=output,
                  title="$title_prefix Steady-State Prices")
    output_result(diag_df; format=Symbol(format), output=output,
                  title="$title_prefix Steady-State Diagnostics")
    return (agg_df, price_df, diag_df)
end

function _dsge_ha_steady_state(; model::String,
                                output::String="", format::String="table")
    spec = _load_ha_model(model)
    _status("Computing HA steady state for model=$(spec.model)...")
    ss = MacroEconometricModels.compute_steady_state(spec)
    _ha_ss_tables(ss; format=format, output=output)
    return ss
end

function _dsge_ha_solve(; model::String, method::String="ssj",
                         n_reduced::Int=30, t_horizon::Int=300,
                         output::String="", format::String="table")
    meth = _parse_ha_method(method)
    spec = _load_ha_model(model)
    sol = _solve_ha(spec; method=meth, n_reduced=n_reduced, T_horizon=t_horizon)

    if sol isa MacroEconometricModels.KrusellSmithSolution
        _status_styled("  Krusell–Smith PLM R²=$(round(sol.r_squared; digits=4)), " *
                       "converged=$(sol.converged), iterations=$(sol.iterations)\n";
                       color = sol.converged ? :green : :yellow)
        plm = sol.plm_coefficients
        plm_df = DataFrame(
            coefficient = ["b$i" for i in 1:length(plm)],
            value = Float64.(vec(plm)),
        )
        diag_df = DataFrame(
            metric = ["method", "r_squared", "converged", "iterations"],
            value = [String(meth), string(sol.r_squared), string(sol.converged), string(sol.iterations)],
        )
        output_result(diag_df; format=Symbol(format), output=output,
                      title="HA-DSGE Solve Diagnostics (krusell-smith)")
        output_result(plm_df; format=Symbol(format), output=output,
                      title="Krusell–Smith PLM Coefficients")
        _ha_ss_tables(sol.steady_state; format=format, output=output, title_prefix="HA")
        return sol
    end

    # HADSGESolution
    _status("  Method: $(sol.method), reduced states: $(sol.n_reduced)/$(sol.n_full_states)")
    if hasproperty(sol, :explained_variance)
        _status("  Explained variance: $(round(Float64(sol.explained_variance); digits=4))")
    end
    diag_df = DataFrame(
        metric = ["method", "n_full_states", "n_reduced", "explained_variance",
                  "obs_rows", "obs_cols"],
        value = [
            string(sol.method),
            string(sol.n_full_states),
            string(sol.n_reduced),
            string(sol.explained_variance),
            string(size(sol.C_obs, 1)),
            string(size(sol.C_obs, 2)),
        ],
    )
    output_result(diag_df; format=Symbol(format), output=output,
                  title="HA-DSGE Solve Diagnostics (method=$(sol.method))")
    _ha_ss_tables(sol.steady_state; format=format, output=output, title_prefix="HA")
    return sol
end

function _dsge_ha_require_linear(sol, meth::Symbol)
    sol isa MacroEconometricModels.HADSGESolution || throw(CliError("model/unsupported",
        "method=$meth does not produce a linearized HADSGESolution " *
        "(got $(typeof(sol))); use --method=ssj or --method=reiter"))
    return sol
end

function _dsge_ha_irf(; model::String, method::String="reiter",
                       horizon::Int=40, n_reduced::Int=30,
                       output::String="", format::String="table",
                       plot::Bool=false, plot_save::String="")
    meth = _parse_ha_method(method)
    meth === :krusell_smith && throw(CliError("usage/invalid-option",
        "HA IRF requires ssj or reiter (krusell-smith returns a PLM, not linear IRFs)"))
    spec = _load_ha_model(model)
    sol = _dsge_ha_require_linear(
        _solve_ha(spec; method=meth, n_reduced=n_reduced), meth)

    _status("Computing HA IRF: horizon=$horizon, method=$meth")
    ir = MacroEconometricModels.irf(sol, horizon)
    _maybe_plot(ir; plot=plot, plot_save=plot_save)

    vals = ir.values
    n_h, n_v, n_s = size(vals)
    for si in 1:n_s
        shock = si <= length(ir.shocks) ? String(ir.shocks[si]) : "shock_$si"
        irf_df = DataFrame(horizon = 0:(n_h - 1))
        for vi in 1:n_v
            vname = vi <= length(ir.variables) ? String(ir.variables[vi]) : "y$vi"
            irf_df[!, vname] = vals[:, vi, si]
        end
        output_result(irf_df; format=Symbol(format),
                      output=_per_var_output_path(output, shock),
                      title="HA-DSGE IRF: shock=$shock (method=$meth, h=$horizon)")
    end
    return ir
end

function _dsge_ha_fevd(; model::String, method::String="reiter",
                        horizon::Int=40, n_reduced::Int=30,
                        output::String="", format::String="table",
                        plot::Bool=false, plot_save::String="")
    meth = _parse_ha_method(method)
    meth === :krusell_smith && throw(CliError("usage/invalid-option",
        "HA FEVD requires ssj or reiter"))
    spec = _load_ha_model(model)
    sol = _dsge_ha_require_linear(
        _solve_ha(spec; method=meth, n_reduced=n_reduced), meth)

    _status("Computing HA FEVD: horizon=$horizon, method=$meth")
    fv = MacroEconometricModels.fevd(sol, horizon)
    _maybe_plot(fv; plot=plot, plot_save=plot_save)

    props = fv.proportions
    n_v, n_s, n_h = size(props)
    varnames = hasproperty(fv, :variables) ? fv.variables : ["y$i" for i in 1:n_v]
    shocks = hasproperty(fv, :shocks) ? fv.shocks : ["shock_$i" for i in 1:n_s]
    for vi in 1:n_v
        vname = vi <= length(varnames) ? String(varnames[vi]) : "y$vi"
        fevd_df = DataFrame(horizon = 1:n_h)
        for si in 1:n_s
            sname = si <= length(shocks) ? String(shocks[si]) : "shock_$si"
            fevd_df[!, sname] = props[vi, si, :]
        end
        output_result(fevd_df; format=Symbol(format),
                      output=_per_var_output_path(output, vname),
                      title="HA-DSGE FEVD: $vname (method=$meth, h=$horizon)")
    end
    return fv
end

function _dsge_ha_simulate(; model::String, method::String="reiter",
                            periods::Int=200, seed::Int=0, n_reduced::Int=30,
                            output::String="", format::String="table",
                            plot::Bool=false, plot_save::String="")
    meth = _parse_ha_method(method)
    meth === :krusell_smith && throw(CliError("usage/invalid-option",
        "HA simulate requires ssj or reiter"))
    spec = _load_ha_model(model)
    sol = _dsge_ha_require_linear(
        _solve_ha(spec; method=meth, n_reduced=n_reduced), meth)

    _status("Simulating HA aggregates: T=$periods, method=$meth")
    if seed > 0
        path = MacroEconometricModels.simulate(sol, periods; rng=Random.MersenneTwister(seed))
    else
        path = MacroEconometricModels.simulate(sol, periods)
    end

    n_out = size(path, 2)
    colnames = ["y$i" for i in 1:n_out]
    try
        ir0 = MacroEconometricModels.irf(sol, 1)
        if length(ir0.variables) == n_out
            colnames = String[string(v) for v in ir0.variables]
        end
    catch
    end
    sim_df = DataFrame(path, colnames)
    insertcols!(sim_df, 1, :period => 1:periods)
    _maybe_plot(sim_df; plot=plot, plot_save=plot_save)
    output_result(sim_df; format=Symbol(format), output=output,
                  title="HA-DSGE Simulation (method=$meth, T=$periods)")
    return path
end

function _dsge_ha_distribution_irf(; model::String, method::String="reiter",
                                    horizon::Int=40, shock_index::Int=1,
                                    shock_size::Float64=1.0, n_reduced::Int=30,
                                    output::String="", format::String="table")
    meth = _parse_ha_method(method)
    meth === :reiter || throw(CliError("usage/invalid-option",
        "distribution-irf requires --method=reiter (SSJ has no distribution basis)"))
    spec = _load_ha_model(model)
    sol = _dsge_ha_require_linear(
        _solve_ha(spec; method=meth, n_reduced=n_reduced), meth)

    _status("Computing distribution IRF: h=$horizon, shock=$shock_index, size=$shock_size")
    d = MacroEconometricModels.distribution_irf(sol, horizon;
            shock_index=shock_index, shock_size=shock_size)
    # Summarize 3D (n_a × n_e × h) as horizon moments
    n_a, n_e, n_h = size(d)
    mean_dev = [sum(abs, d[:, :, h]) for h in 1:n_h]
    max_dev = [maximum(abs, d[:, :, h]) for h in 1:n_h]
    df = DataFrame(
        horizon = 0:(n_h - 1),
        l1_mass_deviation = mean_dev,
        max_abs_deviation = max_dev,
        n_asset_bins = fill(n_a, n_h),
        n_income = fill(n_e, n_h),
    )
    output_result(df; format=Symbol(format), output=output,
                  title="HA Distribution IRF (shock=$shock_index, h=$horizon)")
    return d
end

function _dsge_ha_inequality_irf(; model::String, method::String="reiter",
                                  horizon::Int=40, shock_index::Int=1,
                                  shock_size::Float64=1.0, n_reduced::Int=30,
                                  output::String="", format::String="table",
                                  plot::Bool=false, plot_save::String="")
    meth = _parse_ha_method(method)
    meth === :reiter || throw(CliError("usage/invalid-option",
        "inequality-irf requires --method=reiter"))
    spec = _load_ha_model(model)
    sol = _dsge_ha_require_linear(
        _solve_ha(spec; method=meth, n_reduced=n_reduced), meth)

    _status("Computing inequality IRF: h=$horizon, shock=$shock_index")
    d = MacroEconometricModels.inequality_irf(sol, horizon;
            shock_index=shock_index, shock_size=shock_size)
    df = DataFrame(
        horizon = 0:(horizon - 1),
        gini = d[:gini],
        p10 = d[:p10],
        p25 = d[:p25],
        p50 = d[:p50],
        p75 = d[:p75],
        p90 = d[:p90],
    )
    _maybe_plot(df; plot=plot, plot_save=plot_save)
    output_result(df; format=Symbol(format), output=output,
                  title="HA Inequality IRF (shock=$shock_index, h=$horizon)")
    return d
end

function _dsge_ha_simulate_panel(; model::String,
                                  n_agents::Int=1000, periods::Int=100, seed::Int=0,
                                  output::String="", format::String="table")
    spec = _load_ha_model(model)
    _status("Computing HA steady state for panel simulation...")
    ss = MacroEconometricModels.compute_steady_state(spec)
    _status("Simulating panel: N=$n_agents, T=$periods")
    if seed > 0
        panel = MacroEconometricModels.simulate_panel(ss;
            N_agents=n_agents, T_periods=periods, rng=Random.MersenneTwister(seed))
    else
        panel = MacroEconometricModels.simulate_panel(ss;
            N_agents=n_agents, T_periods=periods)
    end
    # Summary path: cross-sectional mean assets over time (full N×T is huge)
    mean_a = [mean(panel[:, t]) for t in 1:size(panel, 2)]
    # Sample std via sqrt(var); avoids depending on Statistics.std in bare includes
    sd_a = [sqrt(var(panel[:, t])) for t in 1:size(panel, 2)]
    df = DataFrame(
        period = 1:size(panel, 2),
        mean_assets = mean_a,
        sd_assets = sd_a,
        n_agents = fill(size(panel, 1), size(panel, 2)),
    )
    output_result(df; format=Symbol(format), output=output,
                  title="HA Panel Simulation Summary (N=$n_agents, T=$periods)")
    return panel
end

# ── Continuous-time HA + Blanchard OLG (C041) ───────────────

function _dsge_ct_build_aiyagari(; alpha, rho, sigma, delta, z, a_min, a_max, grid_size)
    return MacroEconometricModels.CTAiyagari(;
        alpha=alpha, rho=rho, sigma=sigma, delta=delta, Z=z,
        a_min=a_min, a_max=a_max, I=grid_size)
end

function _dsge_ct_solve(; alpha::Float64=0.36, rho::Float64=0.05, sigma::Float64=2.0,
                         delta::Float64=0.05, z::Float64=1.0,
                         a_min::Float64=0.0, a_max::Float64=30.0, grid_size::Int=100,
                         max_iter::Int=100, tol::Float64=1e-6,
                         two_asset::Bool=false,
                         output::String="", format::String="table")
    if two_asset
        _status("Solving continuous-time two-asset (KMV) model...")
        m = MacroEconometricModels.CTTwoAsset(; sigma=sigma, rho=rho)
        sol = MacroEconometricModels.ct_two_asset_solve(m; max_iter=max_iter, tol=tol)
        # Summarize two-asset solution
        gsum = sum(sol.g)
        diag_df = DataFrame(
            metric = ["hjb_converged", "B_liquid", "A_illiquid", "mass"],
            value = [
                Float64(sol.hjb_converged ? 1.0 : 0.0),
                Float64(sol.B),
                Float64(sol.A),
                Float64(gsum),
            ],
        )
        output_result(diag_df; format=Symbol(format), output=output,
                      title="CT Two-Asset Solution")
        return sol
    end

    _status("Solving continuous-time Aiyagari steady state (I=$grid_size)...")
    m = _dsge_ct_build_aiyagari(; alpha, rho, sigma, delta, z, a_min, a_max, grid_size)
    ss = MacroEconometricModels.ct_steady_state(m; max_iter=max_iter, tol=tol)
    _status_styled("  Converged: $(ss.converged)  r=$(round(ss.r; digits=5))  K=$(round(ss.K; digits=4))\n";
                   color = ss.converged ? :green : :yellow)
    price_df = DataFrame(name=["r", "w"], value=[ss.r, ss.w])
    agg_df = DataFrame(name=["K", "L", "converged"],
                       value=[ss.K, ss.L, Float64(ss.converged ? 1.0 : 0.0)])
    output_result(price_df; format=Symbol(format), output=output, title="CT Aiyagari Prices")
    output_result(agg_df; format=Symbol(format), output=output, title="CT Aiyagari Aggregates")
    return ss
end

function _dsge_ct_transition(; alpha::Float64=0.36, rho::Float64=0.05, sigma::Float64=2.0,
                              delta::Float64=0.05, z::Float64=1.0,
                              shock_size::Float64=0.95, periods::Int=40, dt::Float64=0.25,
                              a_max::Float64=30.0, grid_size::Int=100,
                              max_iter::Int=100, tol::Float64=1e-6,
                              output::String="", format::String="table",
                              plot::Bool=false, plot_save::String="")
    periods >= 2 || throw(CliError("usage/invalid-option",
        "--periods must be >= 2 (need impact + terminal)"))
    _status("CT MIT-shock transition: periods=$periods, impact Z=$(shock_size)*$z")
    m = _dsge_ct_build_aiyagari(; alpha, rho, sigma, delta, z, a_min=0.0, a_max, grid_size)
    ss = MacroEconometricModels.ct_steady_state(m; max_iter=max_iter, tol=tol)
    # Z_path: impact then reversion to m.Z
    Z_path = fill(Float64(m.Z), periods)
    Z_path[1] = shock_size * Float64(m.Z)
    tr = MacroEconometricModels.ct_mit_shock(m, ss, Z_path; dt=dt, max_iter=max_iter, tol=tol)
    df = DataFrame(
        t = tr.t,
        Z = tr.Z,
        K = tr.K,
        r = tr.r,
        w = tr.w,
        C = tr.C,
    )
    _status_styled("  Transition converged: $(tr.converged) (iters=$(tr.iterations))\n";
                   color = tr.converged ? :green : :yellow)
    _maybe_plot(df; plot=plot, plot_save=plot_save)
    output_result(df; format=Symbol(format), output=output,
                  title="CT MIT-Shock Transition (impact=$(shock_size), T=$periods)")
    return tr
end

function _dsge_olg_build(; alpha, beta, delta, gamma, z, debt)
    return MacroEconometricModels.BlanchardOLG(;
        alpha=alpha, beta=beta, delta=delta, gamma=gamma, Z=z, b=debt)
end

function _dsge_olg_maybe_warn_debt(debt::Float64)
    if abs(debt) > 0
        # MEMs#237 was fixed in later tips for C = r*k + w; still surface a soft note
        # when debt is non-zero so agents know to re-check upstream notes.
        _status_styled(
            "  Note: debt b=$debt — verify MEMs Blanchard debt accounting (upstream #237).\n";
            color=:yellow)
    end
end

function _dsge_olg_solve(; alpha::Float64=0.36, beta::Float64=0.96, delta::Float64=0.08,
                          gamma::Float64=0.98, z::Float64=1.0, debt::Float64=0.0,
                          output::String="", format::String="table")
    _dsge_olg_maybe_warn_debt(debt)
    m = _dsge_olg_build(; alpha, beta, delta, gamma, z, debt)
    _status("Solving Blanchard OLG (γ=$gamma, b=$debt)...")
    sol = MacroEconometricModels.blanchard_solve(m)
    ss = sol.ss
    ss_df = DataFrame(
        variable = ["k", "C", "r", "w", "H", "mpc", "b", "converged"],
        value = [ss.k, ss.C, ss.r, ss.w, ss.H, ss.mpc, ss.b, Float64(ss.converged ? 1.0 : 0.0)],
    )
    dyn_df = DataFrame(
        metric = ["stable_eig", "policy_slope", "determinate",
                  "eig1_mod", "eig2_mod"],
        value = [
            Float64(sol.stable_eig),
            Float64(sol.policy_slope),
            Float64(sol.determinate ? 1.0 : 0.0),
            Float64(abs(sol.eigenvalues[1])),
            Float64(abs(sol.eigenvalues[2])),
        ],
    )
    _status_styled("  Determinate: $(sol.determinate)  stable_eig=$(round(sol.stable_eig; digits=4))\n";
                   color = sol.determinate ? :green : :red)
    output_result(ss_df; format=Symbol(format), output=output, title="Blanchard OLG Steady State")
    output_result(dyn_df; format=Symbol(format), output=output, title="Blanchard OLG Dynamics")
    return sol
end

function _dsge_olg_simulate(; alpha::Float64=0.36, beta::Float64=0.96, delta::Float64=0.08,
                             gamma::Float64=0.98, z::Float64=1.0, debt::Float64=0.0,
                             k0::Float64=0.0, horizon::Int=50,
                             output::String="", format::String="table",
                             plot::Bool=false, plot_save::String="")
    _dsge_olg_maybe_warn_debt(debt)
    m = _dsge_olg_build(; alpha, beta, delta, gamma, z, debt)
    sol = MacroEconometricModels.blanchard_solve(m)
    k_init = k0 == 0.0 ? 0.8 * sol.ss.k : k0
    _status("OLG transition: k0=$(round(k_init; digits=4)), H=$horizon, k*=$(round(sol.ss.k; digits=4))")
    paths = MacroEconometricModels.blanchard_transition(m, sol, k_init; H=horizon)
    df = DataFrame(
        period = 0:horizon,
        k = paths.k,
        C = paths.C,
        r = paths.r,
        w = paths.w,
    )
    _maybe_plot(df; plot=plot, plot_save=plot_save)
    output_result(df; format=Symbol(format), output=output,
                  title="Blanchard OLG Transition (H=$horizon)")
    return paths
end
