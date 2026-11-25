# Friedman-cli — Wave 5 ([MEM111-W5] #317) T3 Real-MEMs Integration Tests
# Verifies on real MacroEconometricModels v1.1.1:
#   1. Closed-form Luo (2008) scalar RI solution:
#      K_eff = 1 - 2^(-2*kappa), Sigma_post = sigma_w^2 / (2^(2*kappa) - rho^2),
#      implied_cg_slope = 1 / (2^(2*kappa) - 1)
#   2. Closed-form Matějka-McKay (2015) discrete-choice probabilities
#   3. All 11 `ri *` leaves end-to-end with envelope validation + handles
#   4. `estimate/predict choice ri-logit`
#   5. `estimate regression statespace --steady-state` + correlated noise `G`
#   6. `policy news dsge --behavioral-ri-gain` & `--behavioral-ri-rho`
#   7. `--plot-save` HTML generation across all 10 Wave-5 result types

using CSV, DataFrames

@testset "[MEM111-W5] #317: Real MEMs v1.1.1 Rational Inattention & StateSpace G/SSK" begin

    @testset "Closed-form Luo (2008) scalar RI & all 11 `ri` leaves" begin
        mktempdir() do dir
            rho = 0.8
            sigma_w = 1.0
            kappa = 1.0
            ri_toml = joinpath(dir, "luo.toml")
            write(ri_toml, """
            [ri]
            A = [[$rho]]
            B = [[$sigma_w]]
            H = [[1.0]]
            M = [[1.0]]
            beta = 0.99
            capacity = $kappa
            units = "bits"
            state_names = ["x"]
            action_names = ["u"]
            shock_names = ["w"]
            Sigma_init = [[2.0]]
            """)

            # 1a. ri solve --problem-only (RationalInattentionProblem + plot_result)
            prob_path = joinpath(dir, "prob.jld2")
            prob_html = joinpath(dir, "prob.html")
            rp = run_json(["ri", "solve", "--config", ri_toml, "--problem-only",
                           "--save-model", prob_path, "--plot-save", prob_html])
            assert_envelope_ok(rp; label="ri solve --problem-only")
            @test haskey(rp.doc.data, :ri_problem)
            @test isfile(prob_path) && isfile(prob_html) && filesize(prob_html) > 100

            # 1b. ri solve (SimsKalmanSolution — verify exact Luo 2008 closed form!)
            sol_path = joinpath(dir, "sol.jld2")
            sol_html = joinpath(dir, "sol.html")
            rs = run_json(["ri", "solve", "--config", ri_toml, "--method", "water-filling",
                           "--save-model", sol_path, "--plot-save", sol_html])
            assert_envelope_ok(rs; label="ri solve water-filling")
            @test haskey(rs.doc.data, :ri_kalman_solution)
            @test haskey(rs.doc.data, :ri_summary)
            @test isfile(sol_path) && isfile(sol_html) && filesize(sol_html) > 100

            sol_obj = MacroEconometricModels.load_model(sol_path)
            @test sol_obj isa MacroEconometricModels.SimsKalmanSolution
            K_eff = (sol_obj.K_gain * transpose(sol_obj.Y_signal))[1, 1]
            expected_K_eff = 1.0 - 2.0^(-2.0 * kappa)
            expected_Sigma_post = sigma_w^2 / (2.0^(2.0 * kappa) - rho^2)
            @test isapprox(K_eff, expected_K_eff; atol=1e-6)
            @test isapprox(sol_obj.Sigma_post[1, 1], expected_Sigma_post; atol=1e-6)

            # Also verify logdet-barrier agrees with water-filling
            rs_lb = run_json(["ri", "solve", "--config", ri_toml, "--method", "logdet-barrier"])
            assert_envelope_ok(rs_lb; label="ri solve logdet-barrier")

            # 2. ri transition (DynamicRISolution + plot_result)
            dyn_path = joinpath(dir, "dyn.jld2")
            dyn_html = joinpath(dir, "dyn.html")
            rt = run_json(["ri", "transition", "--model", sol_path, "--config", ri_toml,
                           "--t-path", "15", "--damping", "0.7",
                           "--save-result", dyn_path, "--plot-save", dyn_html])
            assert_envelope_ok(rt; label="ri transition")
            @test haskey(rt.doc.data, :ri_transition_path)
            @test length(rt.doc.data.ri_transition_path.rows) == 15
            @test isfile(dyn_path) && isfile(dyn_html) && filesize(dyn_html) > 100
            # Replay --result
            rt_rep = run_json(["ri", "transition", "--result", dyn_path])
            assert_envelope_ok(rt_rep; label="ri transition --result")

            # 3. ri statespace (--as statespace | abcd | steady-kalman)
            rss = run_json(["ri", "statespace", "--model", sol_path, "--as", "statespace", "--observables", "all"])
            assert_envelope_ok(rss; label="ri statespace --as statespace")
            @test haskey(rss.doc.data, :ri_statespace_system)

            abcd_html = joinpath(dir, "abcd.html")
            rab = run_json(["ri", "statespace", "--model", sol_path, "--as", "abcd",
                            "--observables", "actions", "--plot-save", abcd_html])
            assert_envelope_ok(rab; label="ri statespace --as abcd")
            @test haskey(rab.doc.data, :ri_abcd_system)
            @test isfile(abcd_html) && filesize(abcd_html) > 100

            rsk = run_json(["ri", "statespace", "--model", sol_path, "--as", "steady-kalman",
                            "--observables", "actions"])
            assert_envelope_ok(rsk; label="ri statespace --as steady-kalman")
            @test haskey(rsk.doc.data, :ri_steady_kalman)

            # 4. ri irf
            irf_path = joinpath(dir, "ri_irf.jld2")
            rirf = run_json(["ri", "irf", "--model", sol_path, "--horizons", "10",
                             "--observables", "all", "--save-result", irf_path])
            assert_envelope_ok(rirf; label="ri irf")
            @test haskey(rirf.doc.data, :ri_irf)
            @test isfile(irf_path)

            # 5. ri fevd
            fevd_path = joinpath(dir, "ri_fevd.jld2")
            rfevd = run_json(["ri", "fevd", "--model", sol_path, "--horizons", "10",
                              "--observables", "actions", "--save-result", fevd_path])
            assert_envelope_ok(rfevd; label="ri fevd")
            @test haskey(rfevd.doc.data, :ri_fevd)
            @test isfile(fevd_path)

            # 6. ri simulate + --save-data
            sim_path = joinpath(dir, "sim.jld2")
            rsim = run_json(["ri", "simulate", "--model", sol_path, "--periods", "80",
                             "--burn", "30", "--seed", "42", "--save-data", sim_path])
            assert_envelope_ok(rsim; label="ri simulate")
            @test haskey(rsim.doc.data, :ri_simulated_data)
            @test length(rsim.doc.data.ri_simulated_data.rows) == 80
            @test isfile(sim_path)

            # 7. ri estimate (MLE on simulated actions via --model prob.jld2 + plot_result)
            sim_raw = MacroEconometricModels.simulate(sol_obj, 120; burn=40, seed=123)
            act_csv = joinpath(dir, "actions.csv")
            CSV.write(act_csv, DataFrame(u = vec(sim_raw.actions)))
            est_html = joinpath(dir, "est.html")
            est_path = joinpath(dir, "est.jld2")
            rest = run_json(["ri", "estimate", act_csv, "--model", prob_path,
                             "--method", "mle", "--estimate-param", "capacity",
                             "--save-result", est_path, "--plot-save", est_html])
            assert_envelope_ok(rest; label="ri estimate mle")
            @test haskey(rest.doc.data, :ri_estimation)
            @test haskey(rest.doc.data, :ri_estimation_summary)
            @test isfile(est_path) && isfile(est_html) && filesize(est_html) > 100

            # Also verify Bayesian estimation path
            rest_b = run_json(["--seed=7", "ri", "estimate", act_csv, "--config", ri_toml,
                               "--method", "bayes", "--draws", "60", "--burnin", "20"])
            assert_envelope_ok(rest_b; label="ri estimate bayes")

            # 8. ri cg-test (with --model SimsKalmanSolution comparing exact implied CG slope 1/(2^(2κ)-1))
            rng = Random.Xoshiro(99)
            T_cg = 80
            x_s = vec(sim_raw.states)
            b_s = vec(sim_raw.beliefs)
            # Build realized y_{t+1}, F_t y_{t+1} = rho * b_t, F_{t-1} y_{t+1} = rho^2 * b_{t-1}
            cg_df = DataFrame(
                realized = x_s[3:(T_cg + 2)],
                f_now    = rho .* b_s[2:(T_cg + 1)],
                f_lag    = (rho^2) .* b_s[1:T_cg],
            )
            cg_csv = joinpath(dir, "cg.csv")
            CSV.write(cg_csv, cg_df)
            cg_html = joinpath(dir, "cg.html")
            rcg = run_json(["ri", "cg-test", cg_csv, "--realized", "realized",
                            "--forecast-now", "f_now", "--forecast-lag", "f_lag",
                            "--hac-lags", "auto", "--model", sol_path, "--horizon", "1",
                            "--plot-save", cg_html])
            assert_envelope_ok(rcg; label="ri cg-test")
            @test haskey(rcg.doc.data, :cg_test)
            @test haskey(rcg.doc.data, :cg_summary)
            @test isfile(cg_html) && filesize(cg_html) > 100
            # Check model_implied_cg_slope ≈ 1 / (2^(2*kappa) - 1) = 1/3
            cg_kv = Dict(String(row[1]) => row[2] for row in rcg.doc.data.cg_summary.rows)
            @test isapprox(Float64(cg_kv["model_implied_cg_slope"]), 1.0 / (2.0^(2.0 * kappa) - 1.0); atol=1e-5)

            # 9. ri mw (MWAttentionResult + plot_result)
            mw_toml = joinpath(dir, "mw.toml")
            write(mw_toml, """
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
            mw_html = joinpath(dir, "mw.html")
            mw_path = joinpath(dir, "mw.jld2")
            rmw = run_json(["ri", "mw", "--config", mw_toml, "--horizons", "15",
                            "--save-model", mw_path, "--plot-save", mw_html])
            assert_envelope_ok(rmw; label="ri mw")
            @test haskey(rmw.doc.data, :ri_mw_attention)
            @test haskey(rmw.doc.data, :ri_mw_summary)
            @test isfile(mw_path) && isfile(mw_html) && filesize(mw_html) > 100

            # 10. ri discrete (verify exact symmetric Matějka-McKay 2015 closed form!)
            # For U = [1 0; 0 1], mu = [0.5, 0.5], omega = 0.5:
            # By symmetry P(1) = P(2) = 0.5, and P(1|1) = exp(1/ω) / (exp(1/ω) + 1) = 1 / (1 + exp(-2))
            dc_toml = joinpath(dir, "dc.toml")
            write(dc_toml, """
            [ri.discrete]
            U = [[1.0, 0.0], [0.0, 1.0]]
            mu = [0.5, 0.5]
            new_option_payoffs = [0.8, 0.8]
            omega = 0.5
            units = "bits"
            """)
            dc_path = joinpath(dir, "dc.jld2")
            dc_html = joinpath(dir, "dc.html")
            rdc = run_json(["ri", "discrete", "--config", dc_toml,
                            "--save-model", dc_path, "--plot-save", dc_html])
            assert_envelope_ok(rdc; label="ri discrete 2x2")
            @test haskey(rdc.doc.data, :ri_discrete_choice)
            @test isfile(dc_path) && isfile(dc_html) && filesize(dc_html) > 100

            dc_obj = MacroEconometricModels.load_model(dc_path)
            @test dc_obj isa MacroEconometricModels.RIDiscreteChoiceSolution
            expected_p11 = 1.0 / (1.0 + exp(-1.0 / 0.5))
            @test isapprox(dc_obj.uncond_probs[1], 0.5; atol=1e-6)
            @test isapprox(dc_obj.cond_probs[1, 1], expected_p11; atol=1e-6)
            @test isapprox(dc_obj.cond_probs[2, 2], expected_p11; atol=1e-6)

            # Also verify non-square J < S (2x3) doesn't hit upstream BoundsError
            dc_rect = joinpath(dir, "dc_rect.toml")
            write(dc_rect, """
            [ri.discrete]
            U = [[1.0, 0.0, 0.5], [0.0, 1.0, 0.5]]
            mu = [0.4, 0.4, 0.2]
            omega = 0.5
            """)
            rdc_rect = run_json(["ri", "discrete", "--config", dc_rect])
            assert_envelope_ok(rdc_rect; label="ri discrete 2x3")
            @test length(rdc_rect.doc.data.ri_discrete_choice.rows) == 6

            # 11. ri iia-test (RIIIADiagnostic + plot_result)
            iia_html = joinpath(dir, "iia.html")
            iia_path = joinpath(dir, "iia.jld2")
            riia = run_json(["ri", "iia-test", "--config", dc_toml,
                             "--save-result", iia_path, "--plot-save", iia_html])
            assert_envelope_ok(riia; label="ri iia-test")
            @test haskey(riia.doc.data, :ri_iia_diagnostic)
            @test isfile(iia_path) && isfile(iia_html) && filesize(iia_html) > 100
        end
    end

    @testset "StateSpace correlated noise G & SteadyStateKalman (real MEMs)" begin
        mktempdir() do dir
            rng = Random.Xoshiro(2026)
            ss_csv = joinpath(dir, "ss_y.csv")
            CSV.write(ss_csv, DataFrame(y = randn(rng, 50)))
            ss_toml = joinpath(dir, "ss_g.toml")
            write(ss_toml, """
            [statespace]
            Z = [[1.0]]
            H = [[0.5]]
            T = [[0.8]]
            Q = [[1.0]]
            G = [[0.1]]
            """)
            ssk_path = joinpath(dir, "ssk.jld2")
            ssk_html = joinpath(dir, "ssk.html")
            r = run_json(["estimate", "regression", "statespace", ss_csv,
                          "--config", ss_toml, "--steady-state",
                          "--save-model", ssk_path, "--plot-save", ssk_html])
            assert_envelope_ok(r; label="estimate regression statespace --steady-state + G")
            @test haskey(r.doc.data, :state_space_system_general)
            @test haskey(r.doc.data, :steady_state_kalman)
            @test isfile(ssk_path) && isfile(ssk_html) && filesize(ssk_html) > 100
            ssk = MacroEconometricModels.load_model(ssk_path)
            @test ssk isa MacroEconometricModels.SteadyStateKalman
            @test maximum(abs, ssk.closed_loop_eigs) < 1.0
        end
    end

    @testset "Behavioral RI Jacobian on policy news dsge (real MEMs)" begin
        mktempdir() do dir
            nk_jl = joinpath(dir, "nk_ri.jl")
            write(nk_jl, """
            using MacroEconometricModels
            @dsge begin
                parameters: β = 0.99, κ = 0.1, σ = 1.0, ϕ_π = 1.5, ρ_i = 0.8
                endogenous: y, π, i
                exogenous: ε_i
                y[t] = y[t+1] - (1/σ) * (i[t] - π[t+1])
                π[t] = β * π[t+1] + κ * y[t]
                i[t] = ρ_i * i[t-1] + (1 - ρ_i) * ϕ_π * π[t] + ε_i[t]
            end
            """)
            r_re = run_json(["policy", "news", "dsge", nk_jl,
                             "--policy-shock", "ε_i", "--outcomes", "infl=π,ygap=y",
                             "--instruments", "rate=i", "--horizons", "12"])
            assert_envelope_ok(r_re; label="policy news dsge RE")

            r_ri = run_json(["policy", "news", "dsge", nk_jl,
                             "--policy-shock", "ε_i", "--outcomes", "infl=π,ygap=y",
                             "--instruments", "rate=i", "--horizons", "12",
                             "--behavioral-ri-gain", "0.5", "--behavioral-ri-rho", "0.8"])
            assert_envelope_ok(r_ri; label="policy news dsge --behavioral-ri-gain")
            @test haskey(r_ri.doc.data, :policy_causal_effects_menu)
            # RI Jacobian modifies anticipated news columns compared to RE baseline
            re_vals = [Float64(row[5]) for row in r_re.doc.data.policy_causal_effects_menu.rows]
            ri_vals = [Float64(row[5]) for row in r_ri.doc.data.policy_causal_effects_menu.rows]
            @test !isapprox(re_vals, ri_vals; atol=1e-6)

            # Guard: --behavioral-ri-rho without --behavioral-ri-gain -> exit 2 usage/invalid
            r_bad = run_json(["policy", "news", "dsge", nk_jl,
                              "--policy-shock", "ε_i", "--outcomes", "infl=π",
                              "--instruments", "rate=i", "--horizons", "12",
                              "--behavioral-ri-rho", "0.6"])
            @test r_bad.code == 2
            @test String(r_bad.doc.error.code) == "usage/invalid"
        end
    end

    @testset "Choice family: estimate & predict choice ri-logit (real MEMs)" begin
        mktempdir() do dir
            # Generate synthetic choices from exact Matějka-McKay RI discrete choice
            rng = Random.Xoshiro(3170)
            J, S, K, M = 2, 2, 1, 2
            attrs = zeros(Float64, J, S, K, M)
            attrs[:, :, 1, 1] = [1.0 0.0; 0.0 1.0]
            attrs[:, :, 1, 2] = [1.5 0.0; 0.0 1.5]
            beta_true = [1.0]
            sols = [MacroEconometricModels.solve_ri_discrete(attrs[:, :, 1, m] .* beta_true[1], [0.5, 0.5]; omega=0.5)
                    for m in 1:M]

            rows = DataFrame(env=Int[], state=Int[], alt=Int[], choice=Int[], x1=Float64[])
            for m in 1:M, _ in 1:40
                s = rand(rng, 1:S)
                p1 = sols[m].cond_probs[1, s]
                chosen = rand(rng) < p1 ? 1 : 2
                for j in 1:J
                    push!(rows, (m, s, j, j == chosen ? 1 : 0, attrs[j, s, 1, m]))
                end
            end
            csv = joinpath(dir, "ri_logit.csv")
            CSV.write(csv, rows)

            m_path = joinpath(dir, "rilogit.jld2")
            m_html = joinpath(dir, "rilogit.html")
            re = run_json(["estimate", "choice", "ri-logit", csv,
                           "--env-col", "env", "--choice-col", "choice",
                           "--alt-col", "alt", "--state-col", "state",
                           "--attr-cols", "x1", "--normalize", "omega-one",
                           "--cov-type", "hessian",
                           "--save-model", m_path, "--plot-save", m_html])
            assert_envelope_ok(re; label="estimate choice ri-logit")
            @test haskey(re.doc.data, :ri_logit_coefficients)
            @test haskey(re.doc.data, :fit_statistics)
            @test isfile(m_path) && isfile(m_html) && filesize(m_html) > 100
            m_obj = MacroEconometricModels.load_model(m_path)
            @test m_obj isa MacroEconometricModels.RILogitModel

            rp = run_json(["predict", "choice", "ri-logit", "--model", m_path, "--kind", "conditional"])
            assert_envelope_ok(rp; label="predict choice ri-logit conditional")
            @test haskey(rp.doc.data, :ri_logit_predicted_probabilities)
            @test length(rp.doc.data.ri_logit_predicted_probabilities.rows) == 80
            # Verify predicted row probabilities sum to ~1
            first_row = rp.doc.data.ri_logit_predicted_probabilities.rows[1]
            @test isapprox(Float64(first_row[4]) + Float64(first_row[5]), 1.0; atol=1e-4)

            rp_u = run_json(["predict", "choice", "ri-logit", "--model", m_path, "--kind", "unconditional"])
            assert_envelope_ok(rp_u; label="predict choice ri-logit unconditional")
            @test length(rp_u.doc.data.ri_logit_predicted_probabilities.rows) == 80
        end
    end

end
