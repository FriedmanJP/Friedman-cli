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
        # W12/#114: determinacy-region mapping (MEMs#367). Config-driven because the sweep
        # is two parameter names + two grids + a resolution — well past the "few flags"
        # threshold. `plot_result(::DeterminacyMap)` EXISTS upstream
        # (plotting/dsge_extra.jl:258), so --plot is honoured, not advertised on faith.
        CommandSpec(
            path=["dsge", "determinacy-map"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="config", type=String, default="",
                           description="TOML with a [determinacy] section (params, lower/upper/points or grids); REQUIRED"),
                OptionSpec(name="rank-rtol", type=Float64, default=1e-8,
                           description="Relative tolerance of the Sims rank tests"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"]),
                OptionSpec(name="plot-save", type=String, default="", description="Save plot to HTML file")
            ],
            flags=[
                FlagSpec(name="threaded", description="Evaluate grid points on all available threads (results are identical to the serial sweep)"),
                FlagSpec(name="verbose-solver", description="Do NOT suppress per-grid-point solver warnings"),
                FlagSpec(name="plot", description="Open interactive plot in browser")
            ],
            tables=[TableSpec(name=:determinacy_map, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_determinacy_map),
        ),
        # W12/#114: closed-form (simulation-free) theoretical moments at perturbation order
        # 1/2/3 (MEMs#368). NOTE there is deliberately no `--pruned` switch: upstream's
        # `simulate(::PerturbationSolution)` is ALWAYS pruned (Kim et al. 2008) and exposes
        # no unpruned path, so a flag would advertise a choice that does not exist.
        CommandSpec(
            path=["dsge", "moments"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="method", type=String, default="perturbation",
                           description="Solution method (moments need a PerturbationSolution)"),
                OptionSpec(name="order", type=Int, default=2,
                           description="Perturbation order: 2 or 3 (order 1 is disabled — upstream's order-1 moments are wrong for controls)"),
                OptionSpec(name="lags", type=Int, default=1, description="Autocovariance lags to report (>= 1)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table", description="table|csv|json", choices=["table","csv","json"])
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:moments, description="Path to DSGE model file (.toml or .jl)")],
            category="dsge",
            handler=wrap_legacy(_dsge_moments),
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
        # ── Bayesian DSGE diagnostics (C073 / MEMs 0.7.0) ──
        CommandSpec(
            path=["dsge", "bayes", "mcmc-diag"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH")
            ],
            tables=[TableSpec(name=:bayes_mcmc_diag, description="MCMC convergence diagnostics (R-hat / ESS / Geweke)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_mcmc_diag),
        ),
        CommandSpec(
            path=["dsge", "bayes", "identification"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                OptionSpec(name="params", type=String, default="", description="Comma-separated estimated parameter names (required)"),
                OptionSpec(name="observables", type=String, default="", description="Observable variable names (comma-separated; default: all endogenous)"),
                OptionSpec(name="solver", type=String, default="gensys", description="gensys|klein|perturbation", choices=["gensys","klein","perturbation"]),
                OptionSpec(name="order", type=Int, default=1, description="Perturbation order (1, 2, or 3)"),
                OptionSpec(name="n-lags", type=Int, default=2, description="Autocovariance lags in the Iskrev moment vector"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:bayes_identification, description="Iskrev (2010) local-identification rank test")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_identification),
        ),
        CommandSpec(
            path=["dsge", "bayes", "learning-rate"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="fractions", type=String, default="0.5,1.0", description="Nested subsample fractions (comma-separated, in (0,1])"),
                OptionSpec(name="threshold", type=Float64, default=0.2, description="Flag threshold on the learning rate α"),
                OptionSpec(name="refit-n-smc", type=Int, default=100, description="SMC particles per subsample refit"),
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH")
            ],
            tables=[TableSpec(name=:bayes_learning_rate, description="Koop-Pesaran-Smith (2013) learning-rate check")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_learning_rate),
        ),
        CommandSpec(
            path=["dsge", "bayes", "overlap"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="threshold", type=Float64, default=0.8, description="Flag threshold on the prior/posterior overlap"),
                OptionSpec(name="n-grid", type=Int, default=0, description="Histogram bins (0 = auto ≈ √N)"),
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH")
            ],
            tables=[TableSpec(name=:bayes_overlap, description="Prior/posterior overlap (weak-identification signal)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_overlap),
        ),
        CommandSpec(
            path=["dsge", "bayes", "marginal-lik"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                BAYES_OPTIONS...,
                OptionSpec(name="proposal", type=String, default="normal", description="Bridge proposal family: normal|t", choices=["normal","t"]),
                OptionSpec(name="df", type=Float64, default=5.0, description="Degrees of freedom for the t proposal"),
            ],
            flags=[
                FlagSpec(name="delayed-acceptance", description="Use delayed acceptance for MH")
            ],
            tables=[TableSpec(name=:bayes_marginal_lik, description="Marginal likelihood via bridge sampling (Meng-Wong 1996)")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_marginal_lik),
        ),
        # C073 remainder (#78). NOTE: BAYES_OPTIONS is NOT splatted here — it carries
        # sampler/n-smc/n-particles/burnin/ess-target, which neither handler accepts, and
        # declaring an option a handler cannot take MethodErrors on every use (#85).
        # select_options picks exactly the ones each signature has.
        CommandSpec(
            path=["dsge", "bayes", "posterior-mode"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                select_options(BAYES_OPTIONS, "data", "params", "priors", "observables",
                               "solver", "order", "constraint-solver", "output", "format")...,
                OptionSpec(name="max-iter", type=Int, default=500, description="Maximum optimizer iterations (≥ 1)"),
                OptionSpec(name="f-reltol", type=Float64, default=1e-8, description="Relative function tolerance (> 0)"),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:bayes_posterior_mode, description="Posterior mode with Laplace standard errors")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_posterior_mode),
        ),
        CommandSpec(
            path=["dsge", "bayes", "prior-predictive"],
            summary="Path to DSGE model file (.toml or .jl)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing, description="")],
            options=[
                # no --data: prior_predictive draws from the PRIOR and needs none
                select_options(BAYES_OPTIONS, "params", "priors", "observables", "solver",
                               "order", "constraint-solver", "n-draws", "output", "format")...,
                OptionSpec(name="periods", type=Int, default=200, description="Periods to simulate per draw (≥ 1)"),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:bayes_prior_predictive, description="Prior predictive distribution of summary statistics")],
            category="dsge",
            handler=wrap_legacy(_dsge_bayes_prior_predictive),
        ),
        # ── HA-DSGE node (C040 / MEMs 0.6.7) ──
        # estimate un-deferred (C048): MEMs#228 fixed in 0.6.7 — observation matrix Z is
        # now built from the reduction C rows, so HA Bayesian estimation is meaningful.
        CommandSpec(
            path=["dsge", "ha", "accuracy"],
            summary="Den Haan (2010) accuracy of the aggregate law of motion",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Capital builtin (krusell-smith|one-asset-hank) or .jl HADSGESpec")],
            options=[
                OptionSpec(name="method", type=String, default="krusell-smith",
                           description="Solution to score: krusell-smith|ssj|reiter",
                           choices=["krusell-smith", "ssj", "reiter"]),
                OptionSpec(name="n-reduced", type=Int, default=30, description="Reduced distribution states"),
                OptionSpec(name="t-sim", type=Int, default=10000, description="Simulation length (must exceed --t-burn by >= 10)"),
                OptionSpec(name="t-burn", type=Int, default=1000, description="Burn-in discarded before scoring"),
                OptionSpec(name="t-fit", type=Int, default=4000,
                           description="Fitting length for the implied law (> 100; ssj|reiter only)"),
                OptionSpec(name="rho-z", type=Float64, default=0.95, description="Aggregate shock persistence, |rho| < 1"),
                OptionSpec(name="sigma-z", type=Float64, default=0.007, description="Aggregate shock s.d. (> 0)"),
                OptionSpec(name="seed", type=Int, default=98765, description="Simulation seed"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
                PLOT_OPTIONS...,
            ],
            flags=copy(PLOT_FLAGS),
            tables=[TableSpec(name=:accuracy, description="Den Haan accuracy metrics")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_accuracy),
        ),
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
                OptionSpec(name="euler-points", type=String, default="midpoints",
                           description="Euler-error evaluation points: midpoints|nodes",
                           choices=["midpoints", "nodes"]),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[
                TableSpec(name=:aggregates, description="Steady-state aggregates"),
                TableSpec(name=:prices, description="Steady-state prices"),
                TableSpec(name=:diagnostics, description="Convergence diagnostics"),
                TableSpec(name=:euler, description="Euler accuracy by convention"),
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
        CommandSpec(
            path=["dsge", "ha", "estimate"],
            summary="Bayesian estimation of HA-DSGE parameters (RWMH; MEMs#228 fixed in 0.6.7)",
            args=[ArgSpec(name="model", type=String, required=true, default=nothing,
                          description="Builtin name or .jl HADSGESpec")],
            options=[
                OptionSpec(name="data", type=String, default="", description="Path to observed aggregates CSV (required)"),
                OptionSpec(name="priors", type=String, default="", description="Path to priors TOML with [priors] section (required)"),
                OptionSpec(name="observables", type=String, default="",
                           description="Comma-separated observed aggregates (e.g. K,Y); default: first aggregates"),
                OptionSpec(name="method", type=String, default="ssj",
                           description="HA solution method re-solved each draw: ssj|reiter",
                           choices=["ssj", "reiter"]),
                OptionSpec(name="n-draws", type=Int, default=2000, description="Total RWMH draws (including burn-in)"),
                OptionSpec(name="burnin", type=Int, default=500, description="Burn-in draws to discard"),
                OptionSpec(name="t-horizon", type=Int, default=300,
                           description="Sequence-space truncation length (SSJ); default 300 (ABRS 2021)"),
                OptionSpec(name="n-reduced", type=Int, default=15, description="Reduced distribution states"),
                OptionSpec(name="proposal-scale", type=Float64, default=0.01, description="Initial RWMH proposal scale"),
                OptionSpec(name="adapt-interval", type=Int, default=100, description="Adapt proposal covariance every N draws"),
                OptionSpec(name="measurement-error", type=String, default="none",
                           description="Measurement error: none|auto (auto adds 10% per-obs variance)",
                           choices=["none", "auto"]),
                OptionSpec(name="seed", type=Int, default=0, description="Random seed (0=no seed)"),
                OptionSpec(name="output", short="o", type=String, default="", description="Export results to file"),
                OptionSpec(name="format", short="f", type=String, default="table",
                           description="table|csv|json", choices=["table","csv","json"]),
            ],
            flags=FlagSpec[],
            tables=[TableSpec(name=:posterior, description="Posterior summary (mean, std, quantiles per parameter)")],
            category="dsge",
            handler=wrap_legacy(_dsge_ha_estimate),
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
            ob_sol = _dsge_call(occbin_solve, spec, shocks, cons; T_periods=periods)

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

    # W12/#114 item 4: the Sims [existence, uniqueness] verdict pair. Both DSGESolution and
    # PerturbationSolution carry `eu::Vector{Int}`. Collapsing it to a single "determinate"
    # boolean loses the distinction that matters: e=0 means NO stable solution exists, while
    # e=1,u=0 means solutions exist but are not unique (sunspots) — different diagnoses with
    # different fixes. Emitted for every solution type that carries the pair.
    if hasproperty(sol, :eu) && sol.eu isa AbstractVector && length(sol.eu) >= 2
        e_, u_ = Int(sol.eu[1]), Int(sol.eu[2])
        verdict = e_ == 0 ? "no stable solution (existence fails)" :
                  u_ == 1 ? "determinate (unique stable solution)" :
                            "indeterminate (solutions exist but are not unique)"
        output_kv(Pair{String,Any}[
            "existence" => e_,
            "uniqueness" => u_,
            "verdict" => verdict,
            "solver" => string(hasproperty(sol, :method) ? sol.method : method),
        ]; format=format, output=_per_var_output_path(output, "determinacy"),
           title="Determinacy Verdict")
        e_ == 1 && u_ == 1 ||
            _status_styled("  Determinacy: $verdict\n"; color=:yellow)
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

# ── W12/#114: determinacy region mapping ──────────────────────────────────
# `determinacy_region` re-specs the model and calls `solve` at every grid point, i.e. it
# EVALUATES the runtime-loaded spec's @dsge residual closures — so it goes through the
# `_dsge_call` world-age barrier like every other spec-evaluating path (the RA loader
# lesson). Failed grid points are recorded by upstream as code -2 and the sweep continues;
# they are surfaced here rather than swallowed, because a solve failure is missing
# information, not a fourth determinacy region.
function _dsge_determinacy_map(; model::String, config::String="", rank_rtol::Float64=1e-8,
                                threaded::Bool=false, verbose_solver::Bool=false,
                                output::String="", format::String="table",
                                plot::Bool=false, plot_save::String="")
    isempty(config) && throw(CliError("usage/missing",
        "dsge determinacy-map requires --config <toml> with a [determinacy] section";
        hint="params = [\"phi_pi\"], lower = [0.0], upper = [3.0], points = [61]"))
    rank_rtol > 0 || throw(CliError("usage/invalid",
        "dsge determinacy-map: --rank-rtol must be > 0 (got $rank_rtol)"))

    cfg = get_determinacy(load_config(config))
    spec = _load_dsge_model(model)

    # Reject unknown parameter names HERE: upstream raises a bare ArgumentError, and a typo
    # in a config file is user input (exit 4), not a model failure.
    known = Set(String.(spec.params))
    for p in cfg.params
        p in known || throw(CliError("config/invalid",
            "[determinacy] parameter '$p' is not a parameter of this model " *
            "(have $(join(sort(collect(known)), ", ")))"))
    end

    npts = prod(length.(cfg.grids))
    _status("Determinacy map: sweeping $(join(cfg.params, " × ")) over $npts grid point(s)")
    for (i, p) in enumerate(cfg.params)
        g = cfg.grids[i]
        _status("  $p: $(length(g)) points in [$(first(g)), $(last(g))]")
    end
    _status("  Solver: $(cfg.method), div=$(cfg.div), rank_rtol=$rank_rtol" *
            (threaded ? ", threaded" : ""))
    _status()

    dmap = try
        _dsge_call(determinacy_region, spec;
            params=Symbol[Symbol(p) for p in cfg.params],
            grids=cfg.grids, div=cfg.div, rank_rtol=rank_rtol,
            method=cfg.method, threaded=threaded, quiet=!verbose_solver)
    catch e
        e isa CliError && rethrow()
        e isa ArgumentError && throw(CliError("config/invalid",
            "determinacy map: $(sprint(showerror, e))"))
        throw(_domain_or_data_error(e, "determinacy region sweep"))
    end

    _maybe_plot(dmap; plot=plot, plot_save=plot_save)

    # Tidy long table: one row per grid cell. The raw Sims [existence, uniqueness] pair
    # rides along with the collapsed verdict — the pair is what distinguishes "no solution"
    # (e=0) from "indeterminate" (e=1, u=0), and an agent should not have to re-derive it.
    p1 = cfg.params[1]
    p2 = length(cfg.params) == 2 ? cfg.params[2] : ""
    n1, n2 = size(dmap.verdict)
    rows = NamedTuple[]
    for j in 1:n2, i in 1:n1
        code = dmap.verdict[i, j]
        push!(rows, (; Symbol(p1) => dmap.axes[1][i],
                     (isempty(p2) ? (;) : (; Symbol(p2) => dmap.axes[2][j]))...,
                     verdict = code,
                     label = determinacy_label(code),
                     existence = dmap.eu[i, j, 1],
                     uniqueness = dmap.eu[i, j, 2]))
    end
    output_result(DataFrame(rows); format=Symbol(format), output=output,
                  title="DSGE Determinacy Map ($(join(cfg.params, " × ")))")

    # Region counts. A `failed` count > 0 is reported explicitly rather than folded into
    # "indeterminate": it means the sweep has holes, not that the model is indeterminate there.
    counts = Dict{Int,Int}()
    for c in dmap.verdict
        counts[c] = get(counts, c, 0) + 1
    end
    total = length(dmap.verdict)
    pairs = Pair{String,Any}[
        "n_grid_points" => total,
        "n_determinate" => get(counts, DETERMINACY_CODES.determinate, 0),
        "n_indeterminate" => get(counts, DETERMINACY_CODES.indeterminate, 0),
        "n_no_solution" => get(counts, DETERMINACY_CODES.no_solution, 0),
        "n_failed" => get(counts, DETERMINACY_CODES.failed, 0),
        "method" => string(dmap.method),
        "div" => dmap.div,
    ]
    _status()
    output_kv(pairs; format=format, output=_per_var_output_path(output, "summary"),
              title="Determinacy Region Summary")

    n_failed = get(counts, DETERMINACY_CODES.failed, 0)
    n_failed > 0 && _status_styled(
        "  $n_failed of $total grid point(s) could not be solved and are recorded as " *
        "'failed' — holes in the sweep, NOT an indeterminacy region\n"; color=:yellow)

    # Boundary: one-parameter sweeps only (for two, the boundary is a curve — read the map).
    if length(cfg.params) == 1
        bnd = try
            determinacy_boundary(dmap)
        catch e
            throw(_domain_or_data_error(e, "determinacy boundary"))
        end
        _status()
        output_result(DataFrame(; boundary = collect(Float64.(bnd)));
            format=Symbol(format), output=_per_var_output_path(output, "boundary"),
            title="Determinacy Boundary ($p1)")
        isempty(bnd) ?
            _status("  Verdict is constant across the grid — no boundary crossing.") :
            _status("  Boundary at $p1 ≈ $(join(round.(Float64.(bnd); digits=6), ", ")) " *
                    "(resolution = the grid spacing; refine the grid to sharpen it)")
    end
    return dmap
end

# ── W12/#114: closed-form theoretical moments at order 1/2/3 ───────────────
# Uses the exported `analytical_moments` with format=:gmm, which is a SUPERSET of the
# :covariance packing: means, then upper-triangle PRODUCT moments E[yᵢyⱼ], then diagonal
# E[yᵢ,ₜ·yᵢ,ₜ₋ₖ]. Central moments are recovered from it exactly, so one call yields means,
# variances/covariances and autocovariances rather than two calls with different layouts.
# The mean matters at order ≥ 2: the risk-adjusted mean differs from the steady state, and
# that difference is the point of solving at higher order.
function _dsge_moments(; model::String, method::String="perturbation", order::Int=2,
                        lags::Int=1, output::String="", format::String="table")
    (1 <= order <= 3) || throw(CliError("usage/invalid",
        "dsge moments: --order must be 1, 2 or 3 (got $order)"))
    # ── UPSTREAM DEFECT: the order-1 analytical-moments path is WRONG for controls ──
    # `analytical_moments` at order 1 sets `Var_y[state, control] = Var_x * gx_state'`,
    # which is Cov(z_{t-1}, y_t): it neither applies `hx` nor adds the contemporaneous
    # `eta_x * eta_y'` term, so the true `Cov(z_t, y_t) = hx*Var(z)*gx' + eta_x*eta_y'` comes
    # out short by a factor of rho. The same lagged map is then squared into the
    # autocovariance recursion (`G1_equiv[control, state] = gx_state * hx_state`), so a
    # control's autocorrelation at lag k is reported as rho^(k+2) instead of rho^k.
    #
    # Measured on y = 0.4*z with z an AR(1), rho = 0.7: corr(z, y) came out 0.7 instead of
    # 1.0, and autocorr(y, k) as rho^(k+2). Variances and the whole state block are correct;
    # only blocks involving CONTROLS are wrong — which in a typical DSGE is most of the
    # variables anyone cares about. Orders 2 and 3 go through `_augmented_moments_2nd/3rd`
    # and reproduce the closed form exactly, so the defect is confined to order 1. (Upstream
    # fixed this same control-map time shift in the order-2/3 routine in MEMs#368 and left
    # the order-1 branch alone.)
    #
    # Refusing is strictly better than emitting a wrong table: for a LINEAR model `--order 2`
    # returns the first-order moments exactly (the second-order blocks are zero), so nothing
    # is lost there. Re-enable order 1 once upstream is fixed — the handler needs no other
    # change.
    order >= 2 || throw(CliError("usage/invalid",
        "dsge moments: --order 1 is disabled — MacroEconometricModels' order-1 analytical " *
        "moments are wrong for control variables (the state↔control covariance omits the " *
        "contemporaneous shock term, so correlations and control autocorrelations are off " *
        "by powers of the persistence). Orders 2 and 3 are correct.";
        hint="use --order 2: for a linear model it reproduces the first-order moments exactly"))
    lags >= 1 || throw(CliError("usage/invalid",
        "dsge moments: --lags must be ≥ 1 (got $lags)"))

    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)
    sol isa MacroEconometricModels.PerturbationSolution || throw(CliError("usage/invalid",
        "dsge moments needs a perturbation solution; --method $method produced a " *
        "$(nameof(typeof(sol)))";
        hint="use --method perturbation (the default), optionally with --order 2 or 3"))

    # Augmented specs report moments over the ORIGINAL variables only, so the labels must be
    # filtered the same way upstream filters the matrices — otherwise every moment is
    # attributed to the wrong variable. Replicated from public fields rather than calling
    # the private `_original_var_indices`.
    idx = spec.augmented ? Int[findfirst(==(v), spec.endog) for v in spec.original_endog] :
                           collect(1:spec.n_endog)
    any(isnothing, idx) && throw(CliError("model/error",
        "could not map the augmented model's original variables back to the solved set"))
    names = String[spec.varnames[i] for i in idx]
    k = length(names)

    _status("DSGE theoretical moments: order=$order, $k variable(s), $lags autocovariance lag(s)")
    order == 1 || _status("  Closed-form pruned-state-space moments (simulation-free)")
    _status()

    mv = try
        analytical_moments(sol; lags=lags, format=:gmm)
    catch e
        throw(_domain_or_data_error(e, "theoretical moments"))
    end
    expected = k + div(k * (k + 1), 2) + k * lags
    length(mv) == expected || throw(CliError("model/error",
        "moment vector has $(length(mv)) entries but the $k-variable × $lags-lag layout " *
        "implies $expected — the upstream packing changed"))

    E = Float64[mv[i] for i in 1:k]
    pos = k
    Var = zeros(Float64, k, k)
    for i in 1:k, j in i:k
        pos += 1
        # :gmm packs the PRODUCT moment E[yᵢyⱼ]; the central second moment is that minus E·E.
        v = mv[pos] - E[i] * E[j]
        Var[i, j] = v
        Var[j, i] = v
    end
    ss = Float64.(sol.steady_state)[idx]

    mean_df = DataFrame(
        variable = names,
        steady_state = round.(ss; digits=8),
        mean = round.(E; digits=8),
        # At order 1 this is identically zero; at order ≥ 2 it is the risk correction.
        mean_minus_ss = round.(E .- ss; digits=8),
        std_dev = round.(sqrt.(max.(diag(Var), 0.0)); digits=8),
    )
    output_result(mean_df; format=Symbol(format), output=output,
                  title="DSGE Theoretical Moments (order=$order)")

    cov_rows = NamedTuple[]
    for i in 1:k, j in i:k
        sd = sqrt(max(Var[i, i], 0.0)) * sqrt(max(Var[j, j], 0.0))
        push!(cov_rows, (variable1 = names[i], variable2 = names[j],
                         covariance = round(Var[i, j]; digits=8),
                         correlation = sd > 0 ? round(Var[i, j] / sd; digits=8) : NaN))
    end
    output_result(DataFrame(cov_rows); format=Symbol(format),
                  output=_per_var_output_path(output, "covariance"),
                  title="Variance-Covariance (order=$order)")

    ac_rows = NamedTuple[]
    for lag in 1:lags, i in 1:k
        pos += 1
        # Diagonal autocovariance, again de-centred out of the :gmm product moment.
        ac = mv[pos] - E[i]^2
        push!(ac_rows, (variable = names[i], lag = lag,
                        autocovariance = round(ac; digits=8),
                        autocorrelation = Var[i, i] > 0 ? round(ac / Var[i, i]; digits=8) : NaN))
    end
    output_result(DataFrame(ac_rows); format=Symbol(format),
                  output=_per_var_output_path(output, "autocovariance"),
                  title="Autocovariances (order=$order)")
    return sol
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
        spec = _dsge_call(compute_steady_state, spec; constraints=cons, solver_kw...)
    else
        spec = _dsge_call(compute_steady_state, spec; solver_kw...)
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
        ob_irf = _dsge_call(occbin_irf, spec, cons, 1; shock_size=shock_size, horizon=horizon)

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

    est = _dsge_call(estimate_dsge, spec, Y, param_names;
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
    pf = _dsge_call(perfect_foresight, spec; shocks=shock_mat, T_periods=periods, solver_kw..., cons_kw...)

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

"""
    _dsge_prior_distribution(name, spec) → Distribution

Map one `[priors.<name>]` TOML entry (`{dist, a, b}` from `get_dsge_priors`) to a
`Distributions.jl` object. The two numbers `a`, `b` are the distribution's
positional constructor arguments (MEMs/Dynare convention): `beta` → `Beta(a,b)`,
`normal` → `Normal(mean, sd)`, `inv_gamma` → `InverseGamma(a,b)`,
`gamma` → `Gamma(a,b)`, `uniform` → `Uniform(lo, hi)`.
"""
function _dsge_prior_distribution(name::AbstractString, spec)
    D = MacroEconometricModels.Distributions
    dist = lowercase(strip(string(spec["dist"])))
    a = Float64(spec["a"]); b = Float64(spec["b"])
    dist == "beta"                                    ? D.Beta(a, b) :
    dist in ("normal", "gaussian")                    ? D.Normal(a, b) :
    dist in ("inv_gamma", "inverse_gamma", "invgamma") ? D.InverseGamma(a, b) :
    dist == "gamma"                                   ? D.Gamma(a, b) :
    dist == "uniform"                                 ? D.Uniform(a, b) :
    throw(CliError("config/bad-prior",
        "unknown prior dist '$(spec["dist"])' for parameter '$name'; " *
        "use one of beta|normal|inv_gamma|gamma|uniform",
        hint="see the [priors] TOML reference"))
end

"""
    _dsge_priors_distributions(priors_config) → Dict{Symbol,<:Distribution}

Bridge the `[priors]` TOML to the `Dict{Symbol,<:Distribution}` that MEMs
`estimate_dsge_bayes` requires (both the RA `DSGESpec` and HA `HADSGESpec`
methods). `get_dsge_priors` yields `{name => {dist,a,b}}`; each entry becomes a
concrete distribution via [`_dsge_prior_distribution`].
"""
function _dsge_priors_distributions(priors_config::Dict)
    raw = get_dsge_priors(priors_config)  # throws config/missing-key if no [priors]
    return Dict(Symbol(name) => _dsge_prior_distribution(name, spec)
                for (name, spec) in raw)
end

"""Gather the shared inputs for every Bayesian DSGE leaf: the spec, the data matrix,
`theta0` as a name→value Dict, the bridged priors, observables and solver kwargs. Split
out of `_dsge_bayes_run_estimation` so `dsge bayes posterior-mode`/`prior-predictive`
(#78) get IDENTICAL input handling rather than a second, drifting copy.

`require_data=false` serves `prior-predictive`, which needs no data at all — it draws
from the prior, so demanding `--data` would be a false requirement."""
function _dsge_bayes_inputs(; model::String, data::String, params::String,
        priors::String, observables::String, solver::String, order::Int,
        constraint_solver::String="", require_data::Bool=true)
    require_data && isempty(data) &&
        throw(CliError("usage/missing", "--data is required (path to CSV data file)"))
    isempty(params) && throw(CliError("usage/missing", "--params is required (comma-separated parameter names)"))
    isempty(priors) && throw(CliError("usage/missing", "--priors is required (path to priors TOML)"))

    if !isempty(constraint_solver) && !(constraint_solver in ("nonlinearsolve", "optim", "nlopt", "ipopt", "path"))
        throw(CliError("usage/invalid",
            "invalid --constraint-solver value '$constraint_solver'; must be one of: nonlinearsolve, optim, nlopt, ipopt, path"))
    end

    spec = _load_dsge_model(model)

    Y = isempty(data) ? zeros(0, 0) : df_to_matrix(load_data(data))

    param_names = [strip(p) for p in split(params, ",")]
    # theta0 as a name→value Dict (MEMs #136 / C054): the by-name path resolves
    # start values against the (internally sorted) prior keys, so it is immune to
    # silent alphabetical reordering AND validates that --params matches the
    # priors' parameter set. A bare positional vector would only be length-checked.
    theta0 = Dict(Symbol(p) => 0.5 for p in param_names)

    priors_config = load_config(priors)
    # Bridge {dist,a,b} TOML → Dict{Symbol,<:Distribution} (MEMs requires distribution
    # objects, not the raw config dict — C048; previously passed the wrong type).
    priors_dict = _dsge_priors_distributions(priors_config)

    obs_syms = isempty(observables) ? Symbol[] : Symbol.(strip.(split(observables, ",")))

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    return (spec=spec, Y=Y, theta0=theta0, priors_dict=priors_dict,
            obs_syms=obs_syms, solver_kwargs=solver_kwargs, param_names=param_names)
end

"""Shared helper: run Bayesian DSGE estimation and return the result."""
function _dsge_bayes_run_estimation(; model::String, data::String, params::String,
        priors::String, sampler::String, n_smc::Int, n_particles::Int,
        n_draws::Int, burnin::Int, ess_target::Float64, observables::String,
        solver::String, order::Int, delayed_acceptance::Bool,
        constraint_solver::String="",
        prefilter::String="none", hp_lambda::Float64=1600.0)
    inp = _dsge_bayes_inputs(; model, data, params, priors, observables, solver, order,
                             constraint_solver)
    spec, Y, theta0 = inp.spec, inp.Y, inp.theta0
    priors_dict, obs_syms, solver_kwargs = inp.priors_dict, inp.obs_syms, inp.solver_kwargs
    param_names = inp.param_names

    _status("Bayesian DSGE Estimation:")
    _status("  Sampler: $sampler")
    _status("  Parameters: $(join(param_names, ", "))")
    _status("  Data: $(size(Y, 1)) obs × $(size(Y, 2)) vars")
    _status("  Solver: $solver" * (order > 1 ? ", order=$order" : ""))
    _status()

    # W12/#114 (MEMs#339): observables with trends. `estimate_dsge_bayes` is the ONLY
    # upstream estimation entry point that takes `prefilter` — the frequentist
    # `estimate_dsge` has no such kwarg, and `posterior_mode` takes `trends` but not
    # `prefilter`, so the option is declared on the Bayesian leaves only (#85: never declare
    # an option the handler cannot feed through). It rides on the SHARED runner because
    # every `dsge bayes` leaf re-estimates from scratch — a prefilter that only worked on
    # `bayes estimate` could not be carried into `bayes irf`/`fevd`/`hd`.
    prefilter in ("none", "demean", "first-difference", "linear-detrend", "hp") ||
        throw(CliError("usage/invalid",
            "dsge bayes: --prefilter must be none|demean|first-difference|linear-detrend|hp, got '$prefilter'"))
    (prefilter == "hp" || hp_lambda == 1600.0) || throw(CliError("usage/invalid",
        "dsge bayes: --hp-lambda applies only to --prefilter hp (got --prefilter $prefilter)"))
    hp_lambda > 0 || throw(CliError("usage/invalid",
        "dsge bayes: --hp-lambda must be > 0 (got $hp_lambda)"))
    pf = Symbol(replace(prefilter, '-' => '_'))
    pf === :none || _status("  Prefilter: $prefilter" *
        (pf === :hp ? " (lambda=$hp_lambda)" : ""))

    solver_obj_kw = isempty(constraint_solver) ? (;) : (; solver_obj=Symbol(constraint_solver))
    # World-age barrier: estimate_dsge_bayes re-solves the spec (evaluating its @dsge
    # residual fns) on every posterior draw — must run at the latest world age.
    result = _dsge_call(estimate_dsge_bayes, spec, Y, theta0;
        priors=priors_dict, method=Symbol(sampler),
        observables=obs_syms,
        n_smc=n_smc, n_particles=n_particles,
        n_draws=n_draws, burnin=burnin, ess_target=ess_target,
        solver=Symbol(solver), solver_kwargs=solver_kwargs,
        delayed_acceptance=delayed_acceptance,
        prefilter=pf, hp_lambda=hp_lambda, solver_obj_kw...)

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
                               prefilter::String="none", hp_lambda::Float64=1600.0,
                               output::String="", format::String="table")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

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
                          prefilter::String="none", hp_lambda::Float64=1600.0,
                          horizon::Int=40,
                          output::String="", format::String="table",
                          plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Computing Bayesian DSGE IRF: horizon=$horizon")
    # re-solves per draw → world-age barrier (see _dsge_call)
    irf_result = _dsge_call(irf, result, horizon; n_draws=n_draws,
        solver=Symbol(solver), solver_kwargs=solver_kwargs)

    _maybe_plot(irf_result; plot=plot, plot_save=plot_save)

    n_h = size(irf_result.point_estimate, 1)
    ns = size(irf_result.point_estimate, 3)
    varnames = irf_result.variables
    for si in 1:ns
        shock_name = si <= length(irf_result.shocks) ? irf_result.shocks[si] : "shock_$si"
        irf_df = DataFrame()
        irf_df.horizon = 0:(n_h - 1)
        for (vi, vname) in enumerate(varnames)
            vi > size(irf_result.point_estimate, 2) && break
            irf_df[!, vname] = irf_result.point_estimate[:, vi, si]
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
                           prefilter::String="none", hp_lambda::Float64=1600.0,
                           output::String="", format::String="table",
                           plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Computing Bayesian DSGE FEVD: horizon=$horizon")
    # re-solves per draw → world-age barrier (see _dsge_call)
    fevd_result = _dsge_call(fevd, result, horizon; n_draws=n_draws,
        solver=Symbol(solver), solver_kwargs=solver_kwargs)

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    n_v = size(fevd_result.point_estimate, 2)
    ns = size(fevd_result.point_estimate, 3)
    n_h = size(fevd_result.point_estimate, 1)
    varnames = fevd_result.variables
    for vi in 1:min(n_v, length(varnames))
        vname = varnames[vi]
        fevd_df = DataFrame()
        fevd_df.horizon = 1:n_h
        for si in 1:ns
            shock_name = si <= length(fevd_result.shocks) ? fevd_result.shocks[si] : "shock_$si"
            fevd_df[!, shock_name] = fevd_result.point_estimate[:, vi, si]
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
                               prefilter::String="none", hp_lambda::Float64=1600.0,
                               periods::Int=200,
                               output::String="", format::String="table",
                               plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Simulating from Bayesian DSGE posterior: T=$periods")
    # re-solves per draw → world-age barrier (see _dsge_call)
    sim = _dsge_call(simulate, result, periods; n_draws=n_draws,
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
                              prefilter::String="none", hp_lambda::Float64=1600.0,
                              output::String="", format::String="table")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

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
                              prefilter::String="none", hp_lambda::Float64=1600.0,
                              output::String="", format::String="table")
    isempty(model2) && error("--model2 is required for model comparison")
    isempty(params2) && error("--params2 is required for model comparison")
    isempty(priors2) && error("--priors2 is required for model comparison")

    _status("Estimating Model 1...")
    r1 = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    _status("Estimating Model 2...")
    r2 = _dsge_bayes_run_estimation(; model=model2, data, params=params2,
        priors=priors2, sampler, n_smc, n_particles, n_draws, burnin,
        ess_target, observables, solver, order, delayed_acceptance, constraint_solver)

    # MEMs `bayes_factor` returns the LOG Bayes factor: log BF₁₂ = logML₁ − logML₂
    # (positive favors Model 1). Do NOT take log() of it again. `bf = exp(log_bf)` may
    # overflow to Inf under strong evidence — that is fine to display.
    log_bf = bayes_factor(r1, r2)
    bf = exp(log_bf)

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
    _status_styled("  Log Bayes factor: $(round(log_bf; digits=4))\n"; color=:cyan)
    # Kass & Raftery (1995): 2·log BF > 6 is strong evidence for Model 1.
    if log_bf > 0
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
                                 prefilter::String="none", hp_lambda::Float64=1600.0,
                                 output::String="", format::String="table",
                                 plot::Bool=false, plot_save::String="")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    _status("Generating posterior predictive simulations: n=$n_sim, T=$periods")
    # re-solves per draw → world-age barrier (see _dsge_call)
    pp = _dsge_call(posterior_predictive, result, n_sim; T_periods=periods)

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
                         prefilter::String="none", hp_lambda::Float64=1600.0,
                         output::String="", format::String="table",
                         plot::Bool=false, plot_save::String="")
    isempty(observables) && error("--observables is required (comma-separated variable names)")

    bd = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    df = load_data(data)
    Y = df_to_matrix(df)
    obs_syms = Symbol[Symbol(strip(s)) for s in split(observables, ",")]
    q_levels = [parse(Float64, strip(s)) for s in split(quantiles, ",")]

    _status("Historical Decomposition from Bayesian DSGE posterior")
    _status()

    # re-solves per draw → world-age barrier (see _dsge_call)
    hd = _dsge_call(historical_decomposition, bd, Y, obs_syms;
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

# ── Bayesian DSGE diagnostics (C073) ────────────────────────
# Convergence + identification diagnostics on a fitted Bayesian DSGE posterior.
# All share _dsge_bayes_run_estimation to fit, then route the (world-age-sensitive)
# MEMs diagnostic through _dsge_call. Hand-built tables — none are Tables.jl types.

function _dsge_bayes_mcmc_diag(; model::String, data::String="", params::String="",
                                priors::String="", sampler::String="smc",
                                n_smc::Int=5000, n_particles::Int=500,
                                n_draws::Int=10000, burnin::Int=5000,
                                ess_target::Float64=0.5, observables::String="",
                                solver::String="gensys", order::Int=1,
                                constraint_solver::String="",
                                delayed_acceptance::Bool=false,
                                prefilter::String="none", hp_lambda::Float64=1600.0,
                                output::String="", format::String="table")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    _status("Computing MCMC convergence diagnostics (R-hat / ESS / Geweke)")
    # Pure post-processing of theta_draws, but wrapped for world-age consistency.
    d = _dsge_call(mcmc_diagnostics, result)

    diag_df = DataFrame(
        parameter = string.(d.param_names),
        rhat = round.(d.rhat; digits=4),
        ess_bulk = round.(d.ess_bulk; digits=1),
        ess_tail = round.(d.ess_tail; digits=1),
        geweke_z = round.(d.geweke_z; digits=4),
        geweke_p = round.(d.geweke_p; digits=4),   # may be NaN — _json_safe sanitizes both paths
    )
    output_result(diag_df; format=Symbol(format), output=output,
                  title="MCMC Convergence Diagnostics")

    output_kv(Pair{String,Any}[
        "n_draws" => d.n_draws,
        "method"  => string(d.method),
    ]; format=format, title="MCMC Diagnostics Summary")
    return nothing
end

"""Map an untyped `identification_diagnostics` failure to a typed CliError — these are NOT
`MacroModelError`s, so without this they reach run_cli's exit-1 tail. Bad `--params` name →
`KeyError`; bad `--observables` / a model that fails to solve or has a non-finite moment
Jacobian at θ → `ArgumentError`."""
function _identification_error(e)
    e isa CliError && return e
    if e isa KeyError
        return CliError("usage/invalid",
            "unknown --params name $(repr(e.key)): not a calibrated parameter of the model")
    elseif e isa ArgumentError
        msg = sprint(showerror, e)
        if occursin("observable", msg)
            return CliError("usage/invalid", "identification: $msg")
        elseif occursin("solve", msg) || occursin("non-finite", msg) || occursin("Jacobian", msg)
            return CliError("model/error", "identification: $msg";
                hint="the model does not solve, or has a singular/non-finite moment Jacobian, at the calibrated θ")
        end
        return CliError("data/invalid", "identification: $msg")
    elseif e isa DomainError
        return CliError("data/invalid", "identification: $(sprint(showerror, e))")
    end
    return CliError("model/error", "identification diagnostics failed: $(sprint(showerror, e))")
end

function _dsge_bayes_identification(; model::String, params::String="",
                                     observables::String="", solver::String="gensys",
                                     order::Int=1, n_lags::Int=2,
                                     output::String="", format::String="table")
    isempty(params) && throw(CliError("usage/missing",
        "--params is required (comma-separated estimated parameter names)"))
    spec = _load_dsge_model(model)
    param_syms = Symbol.(filter(!isempty, strip.(split(params, ","))))
    isempty(param_syms) && throw(CliError("usage/missing",
        "--params is required (comma-separated estimated parameter names)"))
    obs_syms = isempty(observables) ? Symbol[] : Symbol.(strip.(split(observables, ",")))
    solver_kwargs = order > 1 ? (order=order,) : NamedTuple()

    _status("Iskrev (2010) local-identification rank test: params=" * join(string.(param_syms), ", "))
    # Evaluates the runtime-loaded spec's residual fns (steady state + solve) →
    # world-age barrier (see _dsge_call). This is the ONLY bayes leaf that feeds raw user
    # --params/--observables straight to a MEMs call (the others go through
    # _dsge_bayes_run_estimation first), and identification_diagnostics throws UNTYPED
    # KeyError (bad --params name → spec.param_values[p]) / ArgumentError (bad --observables,
    # or a model that fails to solve / has a non-finite moment Jacobian at θ) — none are
    # MacroModelError, so they'd fall through run_cli to exit-1. Map them (adversarial review).
    idr = try
        _dsge_call(identification_diagnostics, spec, param_syms;
            observables=obs_syms, n_lags=n_lags, solver=Symbol(solver),
            solver_kwargs=solver_kwargs)
    catch e
        throw(_identification_error(e))
    end

    output_kv(Pair{String,Any}[
        "rank"       => idr.rank,
        "n_params"   => idr.n_params,
        "n_moments"  => idr.n_moments,
        "n_lags"     => idr.n_lags,
        "identified" => idr.identified,
        "tol"        => round(idr.tol; sigdigits=6),
    ]; format=format, output=output, title="Identification Diagnostics")

    sv_df = DataFrame(
        index = collect(1:length(idr.singular_values)),
        singular_value = round.(idr.singular_values; sigdigits=6),
    )
    output_result(sv_df; format=Symbol(format), title="Singular Values")
    return nothing
end

function _dsge_bayes_learning_rate(; model::String, data::String="", params::String="",
                                    priors::String="", sampler::String="smc",
                                    n_smc::Int=5000, n_particles::Int=500,
                                    n_draws::Int=10000, burnin::Int=5000,
                                    ess_target::Float64=0.5, observables::String="",
                                    solver::String="gensys", order::Int=1,
                                    constraint_solver::String="",
                                    delayed_acceptance::Bool=false,
                                    fractions::String="0.5,1.0", threshold::Float64=0.2,
                                    refit_n_smc::Int=100,
                                    prefilter::String="none", hp_lambda::Float64=1600.0,
                                    output::String="", format::String="table")
    frac_vec = try
        Float64[parse(Float64, strip(s)) for s in split(fractions, ",") if !isempty(strip(s))]
    catch
        throw(CliError("usage/invalid",
            "--fractions must be comma-separated numbers in (0,1], got '$fractions'"))
    end
    (length(frac_vec) >= 2 && all(f -> 0 < f <= 1, frac_vec)) || throw(CliError("usage/invalid",
        "--fractions must be at least two values in (0,1], got '$fractions'"))

    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    _status("Koop-Pesaran-Smith learning-rate check (refit n_smc=$refit_n_smc)")
    # Re-runs SMC on nested subsamples (evaluates the spec) → world-age barrier.
    lr = _dsge_call(learning_rate_check, result; fractions=frac_vec,
        n_smc=refit_n_smc, threshold=threshold)

    lr_df = DataFrame(
        parameter = string.(lr.param_names),
        learning_rate = round.(lr.learning_rate; digits=4),
        flagged = lr.flagged,
    )
    output_result(lr_df; format=Symbol(format), output=output,
                  title="Learning-Rate Check")

    output_kv(Pair{String,Any}[
        "threshold"    => threshold,
        "sample_sizes" => string(lr.sample_sizes),
    ]; format=format, title="Learning-Rate Summary")
    return nothing
end

function _dsge_bayes_overlap(; model::String, data::String="", params::String="",
                              priors::String="", sampler::String="smc",
                              n_smc::Int=5000, n_particles::Int=500,
                              n_draws::Int=10000, burnin::Int=5000,
                              ess_target::Float64=0.5, observables::String="",
                              solver::String="gensys", order::Int=1,
                              constraint_solver::String="",
                              delayed_acceptance::Bool=false,
                              threshold::Float64=0.8, n_grid::Int=0,
                              prefilter::String="none", hp_lambda::Float64=1600.0,
                              output::String="", format::String="table")
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    _status("Prior/posterior overlap (weak-identification signal)")
    ov = _dsge_call(prior_posterior_overlap, result; n_grid=n_grid, threshold=threshold)

    ov_df = DataFrame(
        parameter = string.(ov.param_names),
        overlap = round.(ov.overlap; digits=4),
        flagged = ov.flagged,
    )
    output_result(ov_df; format=Symbol(format), output=output,
                  title="Prior-Posterior Overlap")

    output_kv(Pair{String,Any}[
        "threshold" => threshold,
    ]; format=format, title="Overlap Summary")
    return nothing
end

# C073 remainder (#78): posterior mode + prior predictive.
#
# Both go through the shared `_dsge_bayes_inputs`, so they see the same theta0-as-Dict,
# priors bridging and observable handling as the sampler leaves. Both evaluate the
# runtime-loaded @dsge spec's residual fns, so both route through `_dsge_call` (the
# world-age barrier).
#
# NOTE `posterior_mode` reports the LAPLACE log marginal likelihood as a field
# (`laplace_log_ml`). There is deliberately no `--ml bridge` here: bridge sampling needs
# posterior DRAWS, which a mode-finder does not produce — `dsge bayes marginal-lik` is
# the leaf for that.
function _dsge_bayes_posterior_mode(; model::String, data::String="", params::String="",
        priors::String="", observables::String="", solver::String="gensys", order::Int=1,
        max_iter::Int=500, f_reltol::Float64=1e-8, constraint_solver::String="",
        output::String="", format::String="table")
    max_iter >= 1 || throw(CliError("usage/invalid",
        "dsge bayes posterior-mode: --max-iter must be ≥ 1 (got $max_iter)"))
    f_reltol > 0 || throw(CliError("usage/invalid",
        "dsge bayes posterior-mode: --f-reltol must be > 0 (got $f_reltol)"))
    inp = _dsge_bayes_inputs(; model, data, params, priors, observables, solver, order,
                             constraint_solver)
    _status("Bayesian DSGE Posterior Mode:")
    _status("  Parameters: $(join(inp.param_names, ", "))")
    _status("  Data: $(size(inp.Y, 1)) obs × $(size(inp.Y, 2)) vars")
    _status()
    res = try
        _dsge_call(posterior_mode, inp.spec, inp.Y, inp.theta0;
            priors=inp.priors_dict, observables=inp.obs_syms,
            solver=Symbol(solver), solver_kwargs=inp.solver_kwargs,
            f_reltol=f_reltol, max_iter=max_iter)
    catch e
        throw(_identification_error(e))
    end
    # Mode + the Laplace standard errors implied by the inverse Hessian.
    md = Float64.(collect(res.mode))
    se = [sqrt(abs(Float64(res.inv_hessian[i, i]))) for i in 1:length(md)]
    output_result(DataFrame(
            parameter = String.(res.param_names),
            mode = round.(md; digits=6),
            std_error = round.(se; digits=6));
        format=Symbol(format), output=output, title="Posterior Mode")
    output_kv(Pair{String,Any}[
        "log posterior" => round(Float64(res.log_posterior); digits=6),
        "log likelihood" => round(Float64(res.log_likelihood); digits=6),
        "Laplace log ML" => round(Float64(res.laplace_log_ml); digits=6),
        "converged" => res.converged,
        "iterations" => res.n_iterations];
        format=format, title="Posterior Mode Diagnostics")
    res.converged || _status_styled("-> optimizer did NOT converge — treat the mode and its Laplace ML with caution\n"; color=:yellow)
    return res
end

# prior_predictive draws from the PRIOR, so it needs NO data — requiring --data would be
# a false requirement (hence require_data=false).
function _dsge_bayes_prior_predictive(; model::String, params::String="",
        priors::String="", observables::String="", solver::String="gensys", order::Int=1,
        n_draws::Int=500, periods::Int=200, constraint_solver::String="",
        output::String="", format::String="table")
    n_draws >= 1 || throw(CliError("usage/invalid",
        "dsge bayes prior-predictive: --n-draws must be ≥ 1 (got $n_draws)"))
    periods >= 1 || throw(CliError("usage/invalid",
        "dsge bayes prior-predictive: --periods must be ≥ 1 (got $periods)"))
    inp = _dsge_bayes_inputs(; model, data="", params, priors, observables, solver, order,
                             constraint_solver, require_data=false)
    _status("Bayesian DSGE Prior Predictive: draws=$n_draws, periods=$periods")
    _status()
    res = try
        _dsge_call(prior_predictive, inp.spec, inp.priors_dict;
            n_draws=n_draws, T_periods=periods, observables=inp.obs_syms,
            solver=Symbol(solver), solver_kwargs=inp.solver_kwargs)
    catch e
        throw(_identification_error(e))
    end
    # `stats` is (n_effective × n_stats): summarise each statistic across the draws that
    # actually solved, which is the point of a prior predictive check.
    S = Float64.(res.stats)
    nstat = size(S, 2)
    output_result(DataFrame(
            statistic = String.(res.stat_names),
            mean = [round(mean(view(S, :, j)); digits=6) for j in 1:nstat],
            std = [round(sqrt(var(view(S, :, j))); digits=6) for j in 1:nstat],
            q05 = [round(quantile(view(S, :, j), 0.05); digits=6) for j in 1:nstat],
            median = [round(median(view(S, :, j)); digits=6) for j in 1:nstat],
            q95 = [round(quantile(view(S, :, j), 0.95); digits=6) for j in 1:nstat]);
        format=Symbol(format), output=output, title="Prior Predictive Distribution")
    output_kv(Pair{String,Any}[
        "draws requested" => res.n_draws,
        "draws that solved" => res.n_effective,
        "periods simulated" => res.T_periods];
        format=format, title="Prior Predictive Summary")
    res.n_effective < res.n_draws && _status_styled(
        "-> $(res.n_draws - res.n_effective) prior draw(s) failed to solve and were dropped\n"; color=:yellow)
    return res
end

function _dsge_bayes_marginal_lik(; model::String, data::String="", params::String="",
                                   priors::String="", sampler::String="smc",
                                   n_smc::Int=5000, n_particles::Int=500,
                                   n_draws::Int=10000, burnin::Int=5000,
                                   ess_target::Float64=0.5, observables::String="",
                                   solver::String="gensys", order::Int=1,
                                   constraint_solver::String="",
                                   delayed_acceptance::Bool=false,
                                   proposal::String="normal", df::Float64=5.0,
                                   prefilter::String="none", hp_lambda::Float64=1600.0,
                                   output::String="", format::String="table")
    proposal in ("normal", "t") || throw(CliError("usage/invalid",
        "--proposal must be normal|t, got '$proposal'"))
    result = _dsge_bayes_run_estimation(; model, data, params, priors, sampler,
        n_smc, n_particles, n_draws, burnin, ess_target, observables,
        solver, order, delayed_acceptance, constraint_solver, prefilter, hp_lambda)

    _status("Bridge-sampling marginal likelihood (proposal=$proposal)")
    # Re-evaluates the likelihood over the spec → world-age barrier. Returns a scalar
    # log-ML (NaN on a too-short/diffuse chain — handled gracefully).
    logml = _dsge_call(bridge_sampling_ml, result; proposal=Symbol(proposal), df=df)
    logml_smc = result.log_marginal_likelihood

    output_kv(Pair{String,Any}[
        "log_marginal_likelihood_bridge" => (isfinite(logml) ? round(logml; digits=4) : string(logml)),
        "log_marginal_likelihood_smc"    => (isfinite(logml_smc) ? round(logml_smc; digits=4) : string(logml_smc)),
        "proposal"                       => proposal,
        "df"                             => df,
    ]; format=format, output=output, title="Marginal Likelihood (Bridge Sampling)")
    return nothing
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
    # Distinct paths for the 2nd+ table, or `--output f.csv` silently keeps only the last.
    output_result(price_df; format=Symbol(format), output=_per_var_output_path(output, "prices"),
                  title="$title_prefix Steady-State Prices")
    output_result(diag_df; format=Symbol(format), output=_per_var_output_path(output, "diagnostics"),
                  title="$title_prefix Steady-State Diagnostics")

    # Euler accuracy detail (MEMs#508). `ss.euler` carries BOTH conventions —
    # `(midpoints=…, nodes=…)`, each `(points, max, mean, n_evaluated, n_constrained,
    # n_offgrid)`. `euler_error` above is whichever one `--euler-points` selected, and the
    # two differ by 2.5–3.8 log10 units, so reporting only the selected number invites a
    # comparison against published figures measured the other way. `nothing` for steady
    # states built by paths that do not measure accuracy — then this table is absent.
    eu = hasproperty(ss, :euler) ? ss.euler : nothing
    if eu !== nothing
        rows = NamedTuple[]
        for conv in (:midpoints, :nodes)
            haskey(eu, conv) || continue
            s = eu[conv]
            push!(rows, (convention=String(conv),
                         max=Float64(s.max), mean=Float64(s.mean),
                         n_evaluated=Int(s.n_evaluated),
                         n_constrained=Int(s.n_constrained),
                         n_offgrid=Int(s.n_offgrid)))
        end
        if !isempty(rows)
            output_result(DataFrame(rows);
                          format=Symbol(format),
                          output=_per_var_output_path(output, "euler"),
                          title="$title_prefix Euler Accuracy (log10, by convention)")
        end
    end
    return (agg_df, price_df, diag_df)
end

function _dsge_ha_steady_state(; model::String, euler_points::String="midpoints",
                                output::String="", format::String="table")
    ep = lowercase(strip(euler_points))
    ep in ("midpoints", "nodes") || throw(CliError("usage/invalid-option",
        "invalid --euler-points '$euler_points'; must be midpoints or nodes"))
    spec = _load_ha_model(model)
    _status("Computing HA steady state for model=$(spec.model)...")
    ss = MacroEconometricModels.compute_steady_state(spec; euler_points=Symbol(ep))
    _ha_ss_tables(ss; format=format, output=output)
    return ss
end

# ── W13/#115: Den Haan (2010) accuracy for a Krusell-Smith solution ───────────
#
# The audit's strongest row and the one it required resolved concretely.
#
# `den_haan_test` has TWO methods: `KrusellSmithSolution` (the fitted PLM) and
# `HADSGESolution` for the linearized `:ssj`/`:reiter` solutions, which recover the implied
# law by regression over `T_fit` periods. Both are exposed via --method; the linearized ones
# additionally take --t-fit. The two are NOT comparable — upstream measures 0.07% for the
# fitted KS PLM against 12.2% (ssj) and 5.5% (reiter) on the same model — so the renderer
# labels which solution produced the number.
#
# Upstream's own guards are `@assert`s (T_sim/T_burn, T_fit, the z-augmented PLM) and bare
# `error()`s (:huggett, wrong method) — all UNTYPED, i.e. exit 1 — so each is either
# pre-guarded here or mapped. `DenHaanAccuracy` has a real plot recipe
# (plotting/ha_dynamics.jl), so the plot flags are genuinely backed.
function _dsge_ha_accuracy(; model::String, method::String="krusell-smith",
                            n_reduced::Int=30,
                            t_sim::Int=10000, t_burn::Int=1000, t_fit::Int=4000,
                            rho_z::Float64=0.95, sigma_z::Float64=0.007,
                            seed::Int=98765,
                            plot::Bool=false, plot_save::String="",
                            output::String="", format::String="table")
    meth = _parse_ha_method(method)
    t_sim > t_burn + 10 || throw(CliError("usage/invalid",
        "dsge ha accuracy: --t-sim must exceed --t-burn by at least 10 " *
        "(got t_sim=$t_sim, t_burn=$t_burn)"))
    t_burn >= 0 || throw(CliError("usage/invalid",
        "dsge ha accuracy: --t-burn must be ≥ 0 (got $t_burn)"))
    sigma_z > 0 || throw(CliError("usage/invalid",
        "dsge ha accuracy: --sigma-z must be > 0 (got $sigma_z)"))
    abs(rho_z) < 1 || throw(CliError("usage/invalid",
        "dsge ha accuracy: --rho-z must satisfy |rho| < 1 (got $rho_z)"))
    if meth !== :krusell_smith
        t_fit > 100 || throw(CliError("usage/invalid",
            "dsge ha accuracy: --t-fit must be > 100 to fit the implied law of motion " *
            "(got $t_fit)"))
    end

    spec = _load_ha_model(model)
    # Refuse BEFORE the (expensive) solve. Upstream only errors once den_haan_test is
    # reached, so without this a user asking for an undefined combination waits through a
    # full solve just to be told no.
    hasproperty(spec, :model) && spec.model === :huggett && throw(CliError(
        "model/unsupported",
        "Den Haan accuracy is undefined for :huggett — it scores the aggregate CAPITAL " *
        "law of motion, and the Huggett clearing rate is driven by the wealth distribution " *
        "rather than the aggregate shock alone";
        hint="use krusell-smith or one-asset-hank (or an :aiyagari-family .jl spec)"))
    sol = _solve_ha(spec; method=meth, n_reduced=n_reduced)

    dh_kwargs = meth === :krusell_smith ?
        (; T_sim=t_sim, T_burn=t_burn, rho_z=rho_z, sigma_z=sigma_z, seed=seed) :
        (; T_sim=t_sim, T_burn=t_burn, T_fit=t_fit, rho_z=rho_z, sigma_z=sigma_z, seed=seed)
    acc = try
        MacroEconometricModels.den_haan_test(sol; dh_kwargs...)
    catch e
        e isa CliError && rethrow()
        throw(CliError("model/unsupported",
            "Den Haan accuracy is not available for this model/solution combination " *
            "(model='$model', method=$meth)";
            hint=sprint(showerror, e)))
    end

    _status("Den Haan accuracy: aggregate=$(acc.aggregate), T_sim=$(acc.T_sim), " *
            "T_burn=$(acc.T_burn)"); _status()
    output_result(DataFrame(
        metric=["dh_max", "dh_mean", "sigma_ref", "sigma_plm"],
        value=round.(Float64[acc.dh_max, acc.dh_mean, acc.sigma_ref, acc.sigma_plm]; digits=6),
    ); format=Symbol(format), output=output,
       title="Den Haan Accuracy (% deviation, $(acc.aggregate), $(meth))")
    # The two simulated aggregate paths, tidy and long, under a distinct output path.
    n = min(length(acc.ref_path), length(acc.plm_path))
    output_result(DataFrame(t=1:n,
                            reference=round.(Float64.(acc.ref_path[1:n]); digits=6),
                            plm_only=round.(Float64.(acc.plm_path[1:n]); digits=6));
                  format=Symbol(format), output=_per_var_output_path(output, "paths"),
                  title="Reference vs PLM-only Aggregate Path")
    settings = Pair{String,Any}[
        "method"    => String(meth),
        "aggregate" => String(acc.aggregate),
        "source"    => String(acc.source),
        "T_sim"     => acc.T_sim,
        "T_burn"    => acc.T_burn,
        "seed"      => seed,
    ]
    meth === :krusell_smith || push!(settings, "T_fit" => t_fit)
    output_kv(settings; format=format, title="Den Haan Simulation Settings")
    _maybe_plot(acc; plot=plot, plot_save=plot_save)
    return acc
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

# HA Bayesian estimation (C048; un-deferred after MEMs#228). RWMH re-solves the full
# HA model at every draw (Auclert-Bardóczy-Rognlie-Straub 2021 "offline" approach), so
# runs are intentionally small by default relative to RA SMC.
function _dsge_ha_estimate(; model::String, data::String="", priors::String="",
                            observables::String="", method::String="ssj",
                            n_draws::Int=2000, burnin::Int=500,
                            t_horizon::Int=300, n_reduced::Int=15,
                            proposal_scale::Float64=0.01, adapt_interval::Int=100,
                            measurement_error::String="none", seed::Int=0,
                            output::String="", format::String="table")
    isempty(data) && throw(CliError("usage/missing-option",
        "--data is required (path to observed aggregates CSV)"))
    isempty(priors) && throw(CliError("usage/missing-option",
        "--priors is required (path to priors TOML with a [priors] section)"))
    meth = _parse_ha_method(method)
    meth === :krusell_smith && throw(CliError("usage/invalid-option",
        "HA Bayesian estimation requires --method=ssj or reiter " *
        "(krusell-smith yields a PLM, not a linear state space for the Kalman filter)"))
    me = measurement_error == "auto" ? :auto :
         (measurement_error in ("none", "") ? nothing :
          throw(CliError("usage/invalid-option", "--measurement-error must be none|auto")))

    spec = _load_ha_model(model)
    df = load_data(data)
    Y = df_to_matrix(df)

    priors_config = load_config(priors)
    priors_dist = _dsge_priors_distributions(priors_config)
    param_names = sort!(collect(keys(priors_dist)))          # match DSGEPrior sorted order
    theta0 = Float64[mean(priors_dist[pn]) for pn in param_names]
    obs_syms = isempty(observables) ? Symbol[] :
               Symbol.(strip.(split(observables, ",")))

    _status("HA-DSGE Bayesian Estimation (RWMH):")
    _status("  Model: $(spec.model), method: $meth")
    _status("  Parameters: $(join(String.(param_names), ", "))")
    _status("  Observables: " * (isempty(obs_syms) ? "(default aggregates)" :
                                 join(String.(obs_syms), ", ")))
    _status("  Data: $(size(Y, 1)) obs × $(size(Y, 2)) vars; draws=$n_draws, burnin=$burnin")
    _status()

    rng = seed > 0 ? Random.MersenneTwister(seed) : Random.default_rng()
    result = MacroEconometricModels.estimate_dsge_bayes(spec, Y, theta0;
        priors=priors_dist, observables=obs_syms,
        n_draws=n_draws, burnin=burnin, measurement_error=me,
        ha_method=meth, ha_kwargs=(T_horizon=t_horizon, n_reduced=n_reduced),
        proposal_scale=proposal_scale, adapt_interval=adapt_interval, rng=rng)

    draws = result.theta_draws
    np = size(draws, 2)
    est_df = DataFrame(
        parameter = String.(result.param_names),
        mean = [round(mean(draws[:, i]); digits=6) for i in 1:np],
        std = [round(sqrt(var(draws[:, i])); digits=6) for i in 1:np],
        q05 = [round(quantile(draws[:, i], 0.05); digits=6) for i in 1:np],
        median = [round(median(draws[:, i]); digits=6) for i in 1:np],
        q95 = [round(quantile(draws[:, i], 0.95); digits=6) for i in 1:np],
    )
    output_result(est_df; format=Symbol(format), output=output,
                  title="HA-DSGE Bayesian Posterior (rwmh, method=$meth)")

    _status()
    _status_styled("  Log marginal likelihood: $(round(result.log_marginal_likelihood; digits=4))\n"; color=:cyan)
    _status_styled("  Acceptance rate: $(round(result.acceptance_rate; digits=4))\n"; color=:cyan)
    _status_styled("  Effective draws: $(size(draws, 1)) (after burnin=$burnin)\n"; color=:cyan)
    return result
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
