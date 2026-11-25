# Friedman-cli — Wave 5 ([MEM111-W5] #317) T2 Mock Unit Tests
# Covers:
#   - [statespace] G config parser + estimate regression statespace --steady-state
#   - policy news --behavioral-ri-gain / --behavioral-ri-rho & guards
#   - [ri], [ri.mw], [ri.discrete], [ri.logit] TOML config parsers & error paths
#   - All 11 `ri` leaves (solve, transition, statespace, irf, fevd, simulate,
#     estimate, cg-test, mw, discrete, iia-test) + handles + --result replay
#   - Choice family `estimate choice ri-logit` and `predict choice ri-logit`
#   - `_emit_result` coverage for all 10 Wave-5 types + ABCDSystem

function _w5_write_ri_toml(dir::String; extra::String="")
    p = joinpath(dir, "ri_prob.toml")
    write(p, """
    [ri]
    A = [[0.8]]
    B = [[1.0]]
    H = [[1.0]]
    M = [[1.0]]
    beta = 0.99
    capacity = 1.0
    units = "bits"
    state_names = ["x1"]
    action_names = ["u1"]
    shock_names = ["w1"]
    $extra
    """)
    return p
end

function _w5_write_mw_toml(dir::String)
    p = joinpath(dir, "ri_mw.toml")
    write(p, """
    [ri.mw]
    capacity = 2.0
    strategic_complementarity = 0.85

    [ri.mw.agg_block]
    rho = 0.8
    sigma = 0.01

    [ri.mw.idio_block]
    rho = 0.5
    sigma = 0.1
    """)
    return p
end

function _w5_write_discrete_toml(dir::String)
    p = joinpath(dir, "ri_discrete.toml")
    write(p, """
    [ri.discrete]
    U = [[1.0, 0.0], [0.0, 1.0]]
    mu = [0.5, 0.5]
    new_option_payoffs = [0.6, 0.6]
    omega = 0.5
    units = "bits"
    """)
    return p
end

function _w5_write_ri_logit_csv(dir::String; N::Int=24)
    rows = DataFrame(env=Int[], state=Int[], alt=Int[], choice=Int[], x1=Float64[], x2=Float64[])
    rng = Random.Xoshiro(317)
    for i in 1:N
        m = mod1(i, 2)
        s = mod1(div(i - 1, 2) + 1, 2)
        chosen = s  # state 1 favors alt 1, state 2 favors alt 2
        for j in 1:2
            x1 = (j == s ? 1.5 : -0.5) + 0.1 * m
            x2 = (j == 1 ? 0.3 : -0.3) * s
            push!(rows, (m, s, j, j == chosen ? 1 : 0, x1, x2))
        end
    end
    p = joinpath(dir, "ri_logit.csv")
    CSV.write(p, rows)
    return p
end

@testset "[MEM111-W5] #317: Rational Inattention, StateSpace G/SSK, Behavioral RI & RI-Logit" begin

    @testset "Config parsers: [statespace] G, [ri], [ri.mw], [ri.discrete], [ri.logit]" begin
        mktempdir() do dir
            # 1. [statespace] G valid + bad shape
            ss_ok = joinpath(dir, "ss_g.toml")
            write(ss_ok, """
            [statespace]
            Z = [[1.0, 0.0]]
            H = [[0.5]]
            T = [[0.8, 0.1], [0.0, 0.5]]
            Q = [[1.0, 0.0], [0.0, 0.5]]
            G = [[0.1], [0.0]]
            """)
            cfg_ss = get_statespace(load_config(ss_ok))
            @test cfg_ss.G == reshape([0.1, 0.0], 2, 1)

            ss_bad = joinpath(dir, "ss_g_bad.toml")
            write(ss_bad, """
            [statespace]
            Z = [[1.0, 0.0]]
            H = [[0.5]]
            T = [[0.8, 0.1], [0.0, 0.5]]
            Q = [[1.0, 0.0], [0.0, 0.5]]
            G = [[0.1, 0.2]]
            """)
            err = try; get_statespace(load_config(ss_bad)); nothing; catch e; e; end
            @test err isa CliError && err.code == "config/shape"

            # 2. [ri] valid + shape/mutual-exclusion errors
            ri_p = _w5_write_ri_toml(dir; extra="Sigma_init = [[2.0]]\nomega_path = [0.5, 0.5, 0.5]")
            cfg_ri = get_ri_problem(load_config(ri_p))
            @test cfg_ri.A == [0.8;;]
            @test cfg_ri.capacity == 1.0
            @test cfg_ri.units === :bits
            @test cfg_ri.Sigma_init == [2.0;;]
            @test cfg_ri.omega_path == [0.5, 0.5, 0.5]

            ri_both = joinpath(dir, "ri_both.toml")
            write(ri_both, "[ri]\nA = [[0.8]]\nB = [[1.0]]\nH = [[1.0]]\ncapacity = 1.0\nomega = 0.5\n")
            err_b = try; get_ri_problem(load_config(ri_both)); nothing; catch e; e; end
            @test err_b isa CliError && err_b.code == "config/invalid"

            ri_bad_b = joinpath(dir, "ri_bad_b.toml")
            write(ri_bad_b, "[ri]\nA = [[0.8]]\nB = [[1.0], [2.0]]\nH = [[1.0]]\ncapacity = 1.0\n")
            err_s = try; get_ri_problem(load_config(ri_bad_b)); nothing; catch e; e; end
            @test err_s isa CliError && err_s.code == "config/shape"

            # 3. [ri.mw] valid + invalid complementarity
            mw_p = _w5_write_mw_toml(dir)
            cfg_mw = get_ri_mw(load_config(mw_p))
            @test cfg_mw.capacity == 2.0
            @test cfg_mw.strategic_complementarity == 0.85
            @test cfg_mw.agg_block.rho == 0.8

            mw_bad = joinpath(dir, "mw_bad.toml")
            write(mw_bad, """
            [ri.mw]
            capacity = 2.0
            strategic_complementarity = 1.0
            [ri.mw.agg_block]
            rho = 0.8
            sigma = 0.01
            [ri.mw.idio_block]
            rho = 0.5
            sigma = 0.1
            """)
            err_mw = try; get_ri_mw(load_config(mw_bad)); nothing; catch e; e; end
            @test err_mw isa CliError && err_mw.code == "config/invalid"

            # 4. [ri.discrete] valid + mismatched mu
            dc_p = _w5_write_discrete_toml(dir)
            cfg_dc = get_ri_discrete(load_config(dc_p))
            @test size(cfg_dc.U) == (2, 2)
            @test cfg_dc.mu == [0.5, 0.5]
            @test cfg_dc.new_option_payoffs == [0.6, 0.6]

            dc_bad = joinpath(dir, "dc_bad.toml")
            write(dc_bad, "[ri.discrete]\nU = [[1.0, 0.0], [0.0, 1.0]]\nmu = [0.5, 0.3, 0.2]\nomega = 0.5\n")
            err_dc = try; get_ri_discrete(load_config(dc_bad)); nothing; catch e; e; end
            @test err_dc isa CliError && err_dc.code == "config/shape"

            # 5. [ri.logit] priors + base_payoff
            rl_cfg = joinpath(dir, "rl_cfg.toml")
            write(rl_cfg, """
            [ri.logit]
            priors = [[0.5, 0.6], [0.5, 0.4]]
            base_payoff = [[[1.0, 0.0], [0.0, 1.0]], [[1.0, 0.1], [0.1, 1.0]]]
            """)
            cfg_rl = get_ri_logit_config(load_config(rl_cfg), 2, 2, 2)
            @test size(cfg_rl.priors) == (2, 2)
            @test size(cfg_rl.base_payoff) == (2, 2, 2)
        end
    end

    @testset "Registry & family wiring" begin
        @test _MODEL_FAMILY["ri-logit"] == "choice"
        @test _family_for(["ri", "solve"]) == "ri"
        ri_node = register_ri_commands!()
        @test ri_node isa NodeCommand
        @test Set(keys(ri_node.subcmds)) == Set([
            "solve", "transition", "statespace", "irf", "fevd", "simulate",
            "estimate", "cg-test", "mw", "discrete", "iia-test",
        ])
        est_choice = register_estimate_commands!().subcmds["choice"]
        @test haskey(est_choice.subcmds, "ri-logit")
        pred_choice = register_predict_commands!().subcmds["choice"]
        @test haskey(pred_choice.subcmds, "ri-logit")
    end

    @testset "StateSpace correlated noise G & --steady-state" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=40, n=1, colnames=["y1"])
            ss_toml = joinpath(dir, "ss.toml")
            write(ss_toml, """
            [statespace]
            Z = [[1.0]]
            H = [[0.5]]
            T = [[0.8]]
            Q = [[1.0]]
            G = [[0.1]]
            """)
            plot_html = joinpath(dir, "ssk.html")
            ssk_path = joinpath(dir, "ssk.jld2")
            doc = _run_leaf(["estimate", "regression", "statespace", csv,
                             "--config", ss_toml, "--steady-state",
                             "--save-model", ssk_path, "--plot-save", plot_html])
            @test string(doc.status) == "ok"
            @test haskey(doc.data, :state_space_system_general)
            @test haskey(doc.data, :steady_state_kalman)
            @test isfile(ssk_path)
            @test load_model_dispatch(ssk_path) isa SteadyStateKalman
            @test isfile(plot_html)
        end
    end

    @testset "Policy news behavioral RI Jacobian & guards" begin
        mktempdir() do dir
            dsge_toml = joinpath(dir, "nk.toml")
            write(dsge_toml, """
            [model]
            parameters = { beta = 0.99, rho = 0.8 }
            endogenous = ["y", "pi", "i"]
            exogenous = ["eps_i"]

            [[model.equations]]
            expr = "y[t] = 0.5*y[t-1] - i[t]"

            [[model.equations]]
            expr = "pi[t] = beta*pi[t+1] + 0.1*y[t]"

            [[model.equations]]
            expr = "i[t] = rho*i[t-1] + eps_i[t]"
            """)
            # Valid --behavioral-ri-gain and --behavioral-ri-rho
            doc = _run_leaf(["policy", "news", "dsge", dsge_toml,
                             "--policy-shock", "eps_i", "--outcomes", "infl=pi,ygap=y",
                             "--instruments", "rate=i", "--horizons", "8",
                             "--behavioral-ri-gain", "0.6", "--behavioral-ri-rho", "0.7"])
            @test string(doc.status) == "ok"
            @test haskey(doc.data, :policy_causal_effects_menu)
            @test haskey(doc.data, :policy_causal_effects_summary)

            # Guard: --behavioral-ri-rho without --behavioral-ri-gain -> usage/invalid
            err1 = try
                _dispatch_via_app(["policy", "news", "dsge", dsge_toml,
                                   "--policy-shock", "eps_i", "--outcomes", "infl=pi",
                                   "--instruments", "rate=i", "--horizons", "8",
                                   "--behavioral-ri-rho", "0.7"])
                nothing
            catch e; e; end
            @test err1 isa CliError && err1.code == "usage/invalid"

            # Guard: out-of-range --behavioral-ri-gain -> usage/invalid
            err2 = try
                _dispatch_via_app(["policy", "news", "dsge", dsge_toml,
                                   "--policy-shock", "eps_i", "--outcomes", "infl=pi",
                                   "--instruments", "rate=i", "--horizons", "8",
                                   "--behavioral-ri-gain", "1.5"])
                nothing
            catch e; e; end
            @test err2 isa CliError && err2.code == "usage/invalid"

            # Guard: out-of-range --behavioral-ri-rho -> usage/invalid
            err3 = try
                _dispatch_via_app(["policy", "news", "dsge", dsge_toml,
                                   "--policy-shock", "eps_i", "--outcomes", "infl=pi",
                                   "--instruments", "rate=i", "--horizons", "8",
                                   "--behavioral-ri-gain", "0.5", "--behavioral-ri-rho", "-0.1"])
                nothing
            catch e; e; end
            @test err3 isa CliError && err3.code == "usage/invalid"
        end
    end

    @testset "All 11 `ri` leaves end-to-end (mock)" begin
        mktempdir() do dir
            ri_toml = _w5_write_ri_toml(dir; extra="Sigma_init = [[2.0]]")
            mw_toml = _w5_write_mw_toml(dir)
            dc_toml = _w5_write_discrete_toml(dir)
            sol_path = joinpath(dir, "sol.jld2")
            prob_path = joinpath(dir, "prob.jld2")

            # 1a. ri solve --problem-only (covers RationalInattentionProblem via _emit_result)
            d_prob = _run_leaf(["ri", "solve", "--config", ri_toml, "--problem-only",
                                "--save-model", prob_path])
            @test string(d_prob.status) == "ok"
            @test haskey(d_prob.data, :ri_problem)
            @test load_model_dispatch(prob_path) isa RationalInattentionProblem

            # 1b. ri solve (covers SimsKalmanSolution)
            d_sol = _run_leaf(["ri", "solve", "--config", ri_toml,
                               "--method", "logdet-barrier", "--capacity", "1.2",
                               "--save-model", sol_path,
                               "--plot-save", joinpath(dir, "sol.html")])
            @test string(d_sol.status) == "ok"
            @test haskey(d_sol.data, :ri_kalman_solution)
            @test haskey(d_sol.data, :ri_summary)
            @test load_model_dispatch(sol_path) isa SimsKalmanSolution

            # Replay ri solve via --result
            d_sol_rep = _run_leaf(["ri", "solve", "--result", sol_path])
            @test string(d_sol_rep.status) == "ok" && haskey(d_sol_rep.data, :ri_kalman_solution)

            # 2. ri transition (via --model & --save-result, plus --result replay)
            dyn_path = joinpath(dir, "dyn.jld2")
            d_dyn = _run_leaf(["ri", "transition", "--model", sol_path, "--config", ri_toml,
                               "--t-path", "15", "--damping", "0.8",
                               "--save-result", dyn_path])
            @test string(d_dyn.status) == "ok"
            @test haskey(d_dyn.data, :ri_transition_path)
            @test haskey(d_dyn.data, :ri_transition_summary)
            @test load_model_dispatch(dyn_path) isa DynamicRISolution
            d_dyn_rep = _run_leaf(["ri", "transition", "--result", dyn_path])
            @test string(d_dyn_rep.status) == "ok" && haskey(d_dyn_rep.data, :ri_transition_path)

            # 3. ri statespace (--as statespace, abcd, steady-kalman)
            d_ss = _run_leaf(["ri", "statespace", "--model", sol_path, "--as", "statespace"])
            @test string(d_ss.status) == "ok" && haskey(d_ss.data, :ri_statespace_system)
            d_abcd = _run_leaf(["ri", "statespace", "--model", sol_path, "--as", "abcd", "--observables", "actions"])
            @test string(d_abcd.status) == "ok" && haskey(d_abcd.data, :ri_abcd_system)
            d_ssk = _run_leaf(["ri", "statespace", "--model", sol_path, "--as", "steady-kalman", "--observables", "states"])
            @test string(d_ssk.status) == "ok" && haskey(d_ssk.data, :ri_steady_kalman)

            # 4. ri irf
            irf_path = joinpath(dir, "ri_irf.jld2")
            d_irf = _run_leaf(["ri", "irf", "--model", sol_path, "--horizons", "10",
                               "--save-result", irf_path])
            @test string(d_irf.status) == "ok" && haskey(d_irf.data, :ri_irf)
            @test load_model_dispatch(irf_path) isa ImpulseResponse

            # 5. ri fevd
            fevd_path = joinpath(dir, "ri_fevd.jld2")
            d_fevd = _run_leaf(["ri", "fevd", "--model", sol_path, "--horizons", "10",
                                "--observables", "actions", "--save-result", fevd_path])
            @test string(d_fevd.status) == "ok" && haskey(d_fevd.data, :ri_fevd)
            @test load_model_dispatch(fevd_path) isa FEVD

            # 6. ri simulate + --save-data
            sim_data = joinpath(dir, "ri_sim.jld2")
            d_sim = _run_leaf(["ri", "simulate", "--model", sol_path, "--periods", "30",
                               "--burn", "10", "--seed", "42", "--save-data", sim_data])
            @test string(d_sim.status) == "ok"
            @test haskey(d_sim.data, :ri_simulated_data)
            @test haskey(d_sim.data, :ri_simulation_settings)
            @test load_model_dispatch(sim_data) isa TimeSeriesData

            # 7. ri estimate (allow_data_with_model=true + --config)
            est_csv = _make_csv(dir; T=40, n=1, colnames=["u1"])
            est_res = joinpath(dir, "ri_est.jld2")
            d_est = _run_leaf(["ri", "estimate", est_csv, "--model", prob_path,
                               "--method", "mle", "--estimate-param", "capacity",
                               "--cov-type", "sandwich", "--save-result", est_res])
            @test string(d_est.status) == "ok"
            @test haskey(d_est.data, :ri_estimation)
            @test haskey(d_est.data, :ri_estimation_summary)
            @test load_model_dispatch(est_res) isa RIEstimationResult

            d_est_b = _run_leaf(["ri", "estimate", est_csv, "--config", ri_toml,
                                 "--method", "bayes", "--draws", "50", "--burnin", "10"])
            @test string(d_est_b.status) == "ok" && haskey(d_est_b.data, :ri_estimation)

            # 8. ri cg-test (allow_data_with_model=true with --model SimsKalmanSolution)
            cg_csv = _make_csv(dir; T=40, n=3, colnames=["y", "f_now", "f_lag"])
            cg_res = joinpath(dir, "cg.jld2")
            d_cg = _run_leaf(["ri", "cg-test", cg_csv, "--realized", "y",
                              "--forecast-now", "f_now", "--forecast-lag", "f_lag",
                              "--hac-lags", "2", "--model", sol_path, "--horizon", "1",
                              "--save-result", cg_res])
            @test string(d_cg.status) == "ok"
            @test haskey(d_cg.data, :cg_test)
            @test haskey(d_cg.data, :cg_summary)
            @test load_model_dispatch(cg_res) isa CGTestResult

            # 9. ri mw
            mw_path = joinpath(dir, "mw.jld2")
            d_mw = _run_leaf(["ri", "mw", "--config", mw_toml, "--horizons", "15",
                              "--save-model", mw_path])
            @test string(d_mw.status) == "ok"
            @test haskey(d_mw.data, :ri_mw_attention)
            @test haskey(d_mw.data, :ri_mw_summary)
            @test load_model_dispatch(mw_path) isa MWAttentionResult

            # 10. ri discrete
            dc_path = joinpath(dir, "dc.jld2")
            d_dc = _run_leaf(["ri", "discrete", "--config", dc_toml, "--save-model", dc_path])
            @test string(d_dc.status) == "ok"
            @test haskey(d_dc.data, :ri_discrete_choice)
            @test haskey(d_dc.data, :ri_discrete_summary)
            @test load_model_dispatch(dc_path) isa RIDiscreteChoiceSolution

            # 11. ri iia-test
            iia_path = joinpath(dir, "iia.jld2")
            d_iia = _run_leaf(["ri", "iia-test", "--config", dc_toml, "--save-result", iia_path])
            @test string(d_iia.status) == "ok"
            @test haskey(d_iia.data, :ri_iia_diagnostic)
            @test haskey(d_iia.data, :ri_iia_summary)
            @test load_model_dispatch(iia_path) isa RIIIADiagnostic
        end
    end

    @testset "Choice family: estimate & predict choice ri-logit (mock)" begin
        mktempdir() do dir
            csv = _w5_write_ri_logit_csv(dir; N=24)
            m_path = joinpath(dir, "rilogit.jld2")
            plot_html = joinpath(dir, "rilogit.html")

            d_est = _run_leaf(["estimate", "choice", "ri-logit", csv,
                               "--env-col", "env", "--choice-col", "choice",
                               "--alt-col", "alt", "--state-col", "state",
                               "--attr-cols", "x1,x2", "--normalize", "omega-one",
                               "--cov-type", "sandwich",
                               "--save-model", m_path, "--plot-save", plot_html])
            @test string(d_est.status) == "ok"
            @test haskey(d_est.data, :ri_logit_coefficients)
            @test haskey(d_est.data, :fit_statistics)
            @test load_model_dispatch(m_path) isa RILogitModel
            @test isfile(plot_html)

            d_pred = _run_leaf(["predict", "choice", "ri-logit", "--model", m_path,
                                "--kind", "conditional"])
            @test string(d_pred.status) == "ok"
            @test haskey(d_pred.data, :ri_logit_predicted_probabilities)

            d_pred_u = _run_leaf(["predict", "choice", "ri-logit", "--model", m_path,
                                  "--kind", "unconditional"])
            @test string(d_pred_u.status) == "ok"
            @test haskey(d_pred_u.data, :ri_logit_predicted_probabilities)
        end
    end

    @testset "_emit_result covers all 10 Wave-5 types with zero overlap" begin
        for T in (SteadyStateKalman, RationalInattentionProblem, SimsKalmanSolution,
                  RIEstimationResult, CGTestResult, MWAttentionResult,
                  RIIIADiagnostic, RILogitModel, ABCDSystem)
            @test T <: _TIDY_COEF_TYPES
            @test !(T <: _TIDY_LONG_TYPES)
        end
        for T in (DynamicRISolution, RIDiscreteChoiceSolution)
            @test T <: _TIDY_LONG_TYPES
            @test !(T <: _TIDY_COEF_TYPES)
        end
    end

end
