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
        )
    ]
end

function register_dsge_commands!()
    specs = dsge_specs()
    register!(specs)
    return build_node("dsge", specs; description="DSGE models: solve, IRF, FEVD, simulate, estimate, Bayesian, OccBin, perfect foresight")
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
                     horizon::Int=40,
                     output::String="", format::String="table",
                     plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order)

    _status("\nComputing FEVD: horizon=$horizon")
    fevd_result = fevd(sol, horizon)

    _maybe_plot(fevd_result; plot=plot, plot_save=plot_save)

    n_v = size(fevd_result.proportions, 1)
    ne = size(fevd_result.proportions, 2)
    n_h = size(fevd_result.proportions, 3)

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
                      title="DSGE FEVD: $vname (method=$method, h=$horizon)")
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
