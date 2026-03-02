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

# DSGE commands: solve, irf, fevd, simulate, estimate, perfect-foresight, steady-state

function register_dsge_commands!()
    dsge_solve = LeafCommand("solve", _dsge_solve;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("method"; type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
            Option("order"; type=Int, default=1, description="Perturbation order (1 or 2)"),
            Option("degree"; type=Int, default=5, description="Polynomial degree (projection/pfi)"),
            Option("grid"; type=String, default="auto", description="Grid type: auto|chebyshev|smolyak"),
            Option("constraints"; type=String, default="", description="Path to OccBin constraints TOML"),
            Option("periods"; type=Int, default=40, description="Number of periods for OccBin simulation"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Solve a DSGE model (linearize + solve, or OccBin with constraints)")

    dsge_irf = LeafCommand("irf", _dsge_irf;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("method"; type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
            Option("order"; type=Int, default=1, description="Perturbation order (1 or 2)"),
            Option("horizon"; short="h", type=Int, default=40, description="IRF horizon"),
            Option("shock-size"; type=Float64, default=1.0, description="Shock size (std devs)"),
            Option("n-sim"; type=Int, default=0, description="Simulation-based IRF draws (0=analytical)"),
            Option("constraints"; type=String, default="", description="Path to OccBin constraints TOML"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Impulse response functions from a solved DSGE model")

    dsge_fevd = LeafCommand("fevd", _dsge_fevd;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("method"; type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
            Option("order"; type=Int, default=1, description="Perturbation order (1 or 2)"),
            Option("horizon"; short="h", type=Int, default=40, description="FEVD horizon"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Forecast error variance decomposition from a solved DSGE model")

    dsge_simulate = LeafCommand("simulate", _dsge_simulate;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("method"; type=String, default="gensys", description="Solution method: gensys|klein|perturbation|projection|pfi"),
            Option("order"; type=Int, default=1, description="Perturbation order (1 or 2)"),
            Option("periods"; type=Int, default=200, description="Simulation periods (after burn-in)"),
            Option("burn"; type=Int, default=100, description="Burn-in periods to discard"),
            Option("seed"; type=Int, default=0, description="Random seed (0=no seed)"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[
            Flag("antithetic"; description="Use antithetic sampling for variance reduction"),
            Flag("plot"; description="Open interactive plot in browser"),
        ],
        description="Simulate from a solved DSGE model")

    dsge_estimate = LeafCommand("estimate", _dsge_estimate;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("data"; short="d", type=String, default="", description="Path to CSV data file"),
            Option("method"; type=String, default="irf_matching", description="Estimation method: irf_matching|likelihood|bayesian|smm"),
            Option("params"; type=String, default="", description="Comma-separated parameter names to estimate"),
            Option("solve-method"; type=String, default="gensys", description="DSGE solution method"),
            Option("solve-order"; type=Int, default=1, description="Perturbation order for solution"),
            Option("weighting"; type=String, default="optimal", description="Weighting matrix: identity|optimal|diagonal"),
            Option("irf-horizon"; type=Int, default=20, description="IRF horizon for matching"),
            Option("var-lags"; type=Int, default=4, description="VAR lags for empirical IRF"),
            Option("sim-ratio"; type=Int, default=5, description="Simulation-to-data ratio (SMM)"),
            Option("bounds"; type=String, default="", description="Path to parameter bounds TOML"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        description="Estimate DSGE model parameters from data")

    dsge_pf = LeafCommand("perfect-foresight", _dsge_perfect_foresight;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("shocks"; type=String, default="", description="Path to shock sequence CSV"),
            Option("periods"; type=Int, default=100, description="Simulation periods"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
            Option("plot-save"; type=String, default="", description="Save plot to HTML file"),
        ],
        flags=[Flag("plot"; description="Open interactive plot in browser")],
        description="Perfect foresight simulation (deterministic transition path)")

    dsge_ss = LeafCommand("steady-state", _dsge_steady_state;
        args=[Argument("model"; description="Path to DSGE model file (.toml or .jl)")],
        options=[
            Option("constraints"; type=String, default="", description="Path to OccBin constraints TOML"),
            Option("output"; short="o", type=String, default="", description="Export results to file"),
            Option("format"; short="f", type=String, default="table", description="table|csv|json"),
        ],
        description="Compute the steady state of a DSGE model")

    subcmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "solve"              => dsge_solve,
        "irf"                => dsge_irf,
        "fevd"               => dsge_fevd,
        "simulate"           => dsge_simulate,
        "estimate"           => dsge_estimate,
        "perfect-foresight"  => dsge_pf,
        "steady-state"       => dsge_ss,
    )
    return NodeCommand("dsge", subcmds, "DSGE models: solve, IRF, FEVD, simulate, estimate, OccBin, perfect foresight")
end

# ── Implemented Handlers ─────────────────────────────────────

function _dsge_solve(; model::String, method::String="gensys", order::Int=1,
                      degree::Int=5, grid::String="auto",
                      constraints::String="", periods::Int=40,
                      output::String="", format::String="table",
                      plot::Bool=false, plot_save::String="")
    spec = _load_dsge_model(model)
    sol = _solve_dsge(spec; method=method, order=order, degree=degree, grid=grid)

    if !isempty(constraints)
        println("\nSolving with OccBin constraints...")
        cons = _load_dsge_constraints(constraints)
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
        println("\n  State variables ($n_s): $(join([spec.varnames[i] for i in sol.state_indices], ", "))")
        println("  Control variables ($n_c): $(join([spec.varnames[i] for i in sol.control_indices], ", "))")

        gx_df = DataFrame(sol.gx, [spec.varnames[i] for i in sol.state_indices])
        insertcols!(gx_df, 1, :control => [spec.varnames[i] for i in sol.control_indices])
        output_result(gx_df; format=Symbol(format), output=output,
                      title="Perturbation Policy (gx, order=$order)")
    elseif sol isa MacroEconometricModels.ProjectionSolution
        println("\n  Grid type: $(sol.grid_type), Degree: $(sol.degree)")
        println("  Converged: $(sol.converged), Iterations: $(sol.iterations)")
        printstyled("  Residual norm: $(round(sol.residual_norm; sigdigits=4))\n";
                    color = sol.residual_norm < 1e-6 ? :green : :yellow)

        coef_df = DataFrame(sol.coefficients,
                           ["basis_$i" for i in 1:size(sol.coefficients, 2)])
        insertcols!(coef_df, 1, :control => [spec.varnames[i] for i in sol.control_indices])
        output_result(coef_df; format=Symbol(format), output=output,
                      title="Projection Solution (degree=$(sol.degree), grid=$(sol.grid_type))")
    end
    println()
end

function _dsge_steady_state(; model::String, constraints::String="",
                             output::String="", format::String="table")
    spec = _load_dsge_model(model)

    if !isempty(constraints)
        cons = _load_dsge_constraints(constraints)
        spec = compute_steady_state(spec; constraints=cons)
    else
        spec = compute_steady_state(spec)
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

    println("Simulating $(periods + burn) periods (burn-in=$burn)...")

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

# ── Placeholder Handlers (Task 6) ────────────────────────────

function _dsge_irf(; kwargs...)
    error("dsge irf not yet implemented")
end

function _dsge_fevd(; kwargs...)
    error("dsge fevd not yet implemented")
end

function _dsge_estimate(; kwargs...)
    error("dsge estimate not yet implemented")
end

function _dsge_perfect_foresight(; kwargs...)
    error("dsge perfect-foresight not yet implemented")
end
