# Integration tests for [MEM111-W6] (#318):
#   - 4 new v1.1.0 synthetic DGPs (qfm, qfavar, gdfm-infinite, ssvarma)
#   - --seed reproducibility & --save-data .jld2 downstream round-trip
#   - --plot-save HTML smoke renders across all 5 v1.1.0 families

@testset "[MEM111-W6] (#318) v1.1.0 DGPs & plot smoke renders" begin
    mktempdir() do dir
        # 1. data simulate qfm (+ seed reproducibility + --save-data -> estimate qfm)
        qfm_h = joinpath(dir, "sim_qfm.jld2")
        r1 = run_json(["data", "simulate", "qfm", "--periods", "40", "--series", "10",
                       "--location-factors", "1", "--scale-factors", "1",
                       "--seed", "42", "--save-data", qfm_h])
        r2 = run_json(["data", "simulate", "qfm", "--periods", "40", "--series", "10",
                       "--location-factors", "1", "--scale-factors", "1",
                       "--seed", "42"])
        assert_envelope_ok(r1; label="data simulate qfm")
        assert_envelope_ok(r2; label="data simulate qfm repeat")
        @test isfile(qfm_h)
        @test r1.doc.data.simulated_data.rows == r2.doc.data.simulated_data.rows
        @test length(r1.doc.data.simulated_data.rows) == 40
        @test length(r1.doc.data.simulated_data.columns) == 11

        # Downstream estimation + W1 plot smoke render
        p_w1 = joinpath(dir, "w1_qfm.html")
        rqfm = run_json(["estimate", "factor", "qfm", qfm_h, "--factors", "2", "--tau", "0.5",
                         "--plot-save", p_w1])
        assert_envelope_ok(rqfm; label="estimate qfm from simulated .jld2 + plot-save")
        @test isfile(p_w1) && filesize(p_w1) > 200

        # 2. data simulate qfavar
        qfv_h = joinpath(dir, "sim_qfavar.jld2")
        rq1 = run_json(["data", "simulate", "qfavar", "--periods", "40", "--series", "10",
                        "--factors", "2", "--lags", "1", "--n-key", "1", "--burn", "15",
                        "--seed", "17", "--save-data", qfv_h])
        rq2 = run_json(["data", "simulate", "qfavar", "--periods", "40", "--series", "10",
                        "--factors", "2", "--lags", "1", "--n-key", "1", "--burn", "15",
                        "--seed", "17"])
        assert_envelope_ok(rq1; label="data simulate qfavar")
        @test isfile(qfv_h)
        @test rq1.doc.data.simulated_data.rows == rq2.doc.data.simulated_data.rows
        @test length(rq1.doc.data.simulated_data.columns) == 12

        # 3. data simulate gdfm-infinite + W2 plot smoke render
        gd_h = joinpath(dir, "sim_gdfm_inf.jld2")
        rg1 = run_json(["data", "simulate", "gdfm-infinite", "--periods", "50", "--series", "10",
                        "--dynamic-rank", "2", "--n-permanent", "0", "--burn", "20",
                        "--seed", "29", "--save-data", gd_h])
        rg2 = run_json(["data", "simulate", "gdfm-infinite", "--periods", "50", "--series", "10",
                        "--dynamic-rank", "2", "--n-permanent", "0", "--burn", "20",
                        "--seed", "29"])
        assert_envelope_ok(rg1; label="data simulate gdfm-infinite")
        @test isfile(gd_h)
        @test rg1.doc.data.simulated_data.rows == rg2.doc.data.simulated_data.rows

        p_w2 = joinpath(dir, "w2_fhlz.html")
        rfhlz = run_json(["estimate", "factor", "fhlz", gd_h, "--dynamic-rank", "1", "--p-max", "2",
                          "--n-perm", "5", "--plot-save", p_w2])
        assert_envelope_ok(rfhlz; label="estimate fhlz + plot-save")
        @test isfile(p_w2) && filesize(p_w2) > 200

        # 4. data simulate ssvarma (default + custom --config) + W3 plot smoke render
        sv_h = joinpath(dir, "sim_ssvarma.jld2")
        rs1 = run_json(["data", "simulate", "ssvarma", "--periods", "80", "--dist", "student-t",
                        "--nu", "5.0", "--burn", "30", "--seed", "77", "--save-data", sv_h])
        rs2 = run_json(["data", "simulate", "ssvarma", "--periods", "80", "--dist", "student-t",
                        "--nu", "5.0", "--burn", "30", "--seed", "77"])
        assert_envelope_ok(rs1; label="data simulate ssvarma")
        @test isfile(sv_h)
        @test rs1.doc.data.simulated_data.rows == rs2.doc.data.simulated_data.rows

        cfg_sv = joinpath(dir, "ssv.toml")
        write(cfg_sv, """
        [ssvarma]
        mu = [0.0, 0.0]
        Phi = [[0.3, 0.0], [0.0, 0.3]]
        Theta = [[-0.4, 0.0], [0.0, -0.4]]
        C = [[1.0, 0.2], [-0.2, 1.0]]
        """)
        rsc = run_json(["data", "simulate", "ssvarma", "--periods", "50", "--dist", "laplace",
                        "--burn", "20", "--config", cfg_sv, "--seed", "11"])
        assert_envelope_ok(rsc; label="data simulate ssvarma --config")

        p_w3 = joinpath(dir, "w3_ssvarma.html")
        rssv = run_json(["estimate", "multivariate", "ssvarma", sv_h, "--ar-lags", "1", "--ma-lags", "1",
                         "--max-iter", "20", "--plot-save", p_w3])
        assert_envelope_ok(rssv; label="estimate ssvarma + plot-save")
        @test isfile(p_w3) && filesize(p_w3) > 200

        # W4 plot smoke render (ABCDSystem)
        rbc = joinpath(dir, "rbc_w6.jl")
        write(rbc, """
        using .MacroEconometricModels
        @dsge begin
            parameters: α = 0.33, β = 0.99, δ = 0.025, ρ = 0.9
            endogenous: k, c, z
            exogenous: e
            c[t]^(-1) = β * c[t+1]^(-1) * (α * exp(z[t+1]) * k[t]^(α-1) + 1 - δ)
            k[t] = exp(z[t]) * k[t-1]^α + (1 - δ) * k[t-1] - c[t]
            z[t] = ρ * z[t-1] + e[t]
        end
        """)
        p_w4 = joinpath(dir, "w4_abcd.html")
        rabcd = run_json(["dsge", "abcd", "extract", rbc, "--observables", "c", "--plot-save", p_w4])
        assert_envelope_ok(rabcd; label="dsge abcd extract + plot-save")
        @test isfile(p_w4) && filesize(p_w4) > 200

        # W5 plot smoke render (SimsKalmanSolution)
        ri_cfg = joinpath(dir, "ri_w6.toml")
        write(ri_cfg, """
        [ri]
        A = [[0.8]]
        B = [[1.0]]
        H = [[1.0]]
        M = [[1.0]]
        beta = 0.99
        capacity = 1.0
        """)
        p_w5 = joinpath(dir, "w5_ri.html")
        rri = run_json(["ri", "solve", "--config", ri_cfg, "--plot-save", p_w5])
        assert_envelope_ok(rri; label="ri solve + plot-save")
        @test isfile(p_w5) && filesize(p_w5) > 200
    end
end
