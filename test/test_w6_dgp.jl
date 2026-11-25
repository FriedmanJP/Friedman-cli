# Friedman-cli — macroeconometric analysis from the terminal
# Copyright (C) 2026 Wookyung Chung <chung@friedman.jp>
#
# [MEM111-W6] (#318): 4 new v1.1.0 synthetic DGPs (data simulate qfm, qfavar,
# gdfm-infinite, ssvarma) + plot flag discipline audit on non-plottable types.

@testset "[MEM111-W6] (#318) v1.1.0 DGPs & plot discipline" begin

    function _parse_sim_json(args::Vector{String})
        out = _capture() do
            _dispatch_via_app(vcat(args, ["--format", "json"]))
        end
        i = findfirst('{', out)
        @test i !== nothing
        doc = JSON3.read(out[i:end])
        @test String(doc.status) == "ok"
        @test haskey(doc.data, :simulated_data)
        @test haskey(doc.data, :population_truth)
        @test haskey(doc.data, :simulation_settings)
        return doc
    end

    @testset "data simulate qfm" begin
        mktempdir() do d
            doc1 = _parse_sim_json(["data", "simulate", "qfm", "--periods", "40",
                                    "--series", "10", "--location-factors", "1",
                                    "--scale-factors", "1", "--asym-factors", "1",
                                    "--df-idio", "3.0", "--idio-scale", "0.8",
                                    "--loadings-scale", "1.2", "--seed", "42"])
            doc2 = _parse_sim_json(["data", "simulate", "qfm", "--periods", "40",
                                    "--series", "10", "--location-factors", "1",
                                    "--scale-factors", "1", "--asym-factors", "1",
                                    "--df-idio", "3.0", "--idio-scale", "0.8",
                                    "--loadings-scale", "1.2", "--seed", "42"])
            @test length(doc1.data.simulated_data.rows) == 40
            @test length(doc1.data.simulated_data.columns) == 11   # time + x1..x10
            @test doc1.data.simulated_data.rows == doc2.data.simulated_data.rows
            pnames = Set(String(r[1]) for r in doc1.data.population_truth.rows)
            @test "Lambda_loc" in pnames && "Lambda_scale" in pnames && "Lambda_asym" in pnames
            @test "tau_grid" in pnames && "df_idio" in pnames

            sp = joinpath(d, "qfm_sim.jls")
            _parse_sim_json(["data", "simulate", "qfm", "--periods", "30", "--series", "8",
                             "--seed", "7", "--save-data", sp])
            @test isfile(sp)

            # Invalid zero total factors
            e = try
                _data_simulate_qfm(; location_factors=0, scale_factors=0, asym_factors=0)
                nothing
            catch ex; ex; end
            @test e isa CliError && e.code == "usage/invalid"
        end
    end

    @testset "data simulate qfavar" begin
        mktempdir() do d
            doc1 = _parse_sim_json(["data", "simulate", "qfavar", "--periods", "35",
                                    "--series", "12", "--factors", "2", "--lags", "1",
                                    "--n-key", "2", "--df-idio", "4.0",
                                    "--tail-amplification", "1.8", "--burn", "10",
                                    "--seed", "19"])
            doc2 = _parse_sim_json(["data", "simulate", "qfavar", "--periods", "35",
                                    "--series", "12", "--factors", "2", "--lags", "1",
                                    "--n-key", "2", "--df-idio", "4.0",
                                    "--tail-amplification", "1.8", "--burn", "10",
                                    "--seed", "19"])
            @test length(doc1.data.simulated_data.rows) == 35
            @test length(doc1.data.simulated_data.columns) == 15   # time + 12 x + 2 y_key
            @test "y_key1" in String.(doc1.data.simulated_data.columns)
            @test doc1.data.simulated_data.rows == doc2.data.simulated_data.rows
            pnames = Set(String(r[1]) for r in doc1.data.population_truth.rows)
            @test "A0" in pnames && "B_median" in pnames && "true_qirf_impact" in pnames

            sp = joinpath(d, "qfavar_sim.jls")
            _parse_sim_json(["data", "simulate", "qfavar", "--periods", "25", "--series", "10",
                             "--burn", "5", "--seed", "3", "--save-data", sp])
            @test isfile(sp)

            e = try
                _data_simulate_qfavar(; series=2, factors=2, n_key=1)
                nothing
            catch ex; ex; end
            @test e isa CliError && e.code == "usage/invalid"
        end
    end

    @testset "data simulate gdfm-infinite" begin
        mktempdir() do d
            doc1 = _parse_sim_json(["data", "simulate", "gdfm-infinite", "--periods", "40",
                                    "--series", "12", "--dynamic-rank", "2",
                                    "--a-coef", "0.6", "--b-coef", "0.4",
                                    "--n-permanent", "1", "--signal-share", "0.8",
                                    "--idio-ar", "0.2", "--burn", "15", "--seed", "99"])
            doc2 = _parse_sim_json(["data", "simulate", "gdfm-infinite", "--periods", "40",
                                    "--series", "12", "--dynamic-rank", "2",
                                    "--a-coef", "0.6", "--b-coef", "0.4",
                                    "--n-permanent", "1", "--signal-share", "0.8",
                                    "--idio-ar", "0.2", "--burn", "15", "--seed", "99"])
            @test length(doc1.data.simulated_data.rows) == 40
            @test length(doc1.data.simulated_data.columns) == 13   # time + x1..x12
            @test doc1.data.simulated_data.rows == doc2.data.simulated_data.rows
            pnames = Set(String(r[1]) for r in doc1.data.population_truth.rows)
            @test "alpha" in pnames && "b" in pnames && "q" in pnames && "n_permanent" in pnames

            sp = joinpath(d, "gdfm_inf.jls")
            _parse_sim_json(["data", "simulate", "gdfm-infinite", "--periods", "30", "--series", "8",
                             "--burn", "5", "--seed", "5", "--save-data", sp])
            @test isfile(sp)

            e = try
                _data_simulate_gdfm_infinite(; dynamic_rank=2, n_permanent=3)
                nothing
            catch ex; ex; end
            @test e isa CliError && e.code == "usage/invalid"
        end
    end

    @testset "data simulate ssvarma" begin
        mktempdir() do d
            doc1 = _parse_sim_json(["data", "simulate", "ssvarma", "--periods", "50",
                                    "--dist", "student-t", "--nu", "6.0", "--skew", "0.2",
                                    "--burn", "20", "--seed", "123"])
            doc2 = _parse_sim_json(["data", "simulate", "ssvarma", "--periods", "50",
                                    "--dist", "student-t", "--nu", "6.0", "--skew", "0.2",
                                    "--burn", "20", "--seed", "123"])
            @test length(doc1.data.simulated_data.rows) == 50
            @test length(doc1.data.simulated_data.columns) == 3   # time + y1, y2
            @test doc1.data.simulated_data.rows == doc2.data.simulated_data.rows
            pnames = Set(String(r[1]) for r in doc1.data.population_truth.rows)
            @test "Phi_1" in pnames && "Theta_1" in pnames && "C" in pnames && "ma_eig_abs" in pnames

            # Custom TOML config with 3x3 matrices
            cfg = joinpath(d, "ssvarma.toml")
            write(cfg, """
            [ssvarma]
            mu = [0.1, 0.0, -0.1]
            Phi = [[0.3, 0.0, 0.0], [0.0, 0.3, 0.0], [0.0, 0.0, 0.3]]
            Theta = [[-0.4, 0.0, 0.0], [0.0, -0.4, 0.0], [0.0, 0.0, -0.4]]
            C = [[1.0, 0.0, 0.0], [0.2, 1.0, 0.0], [0.0, 0.2, 1.0]]
            """)
            sp = joinpath(d, "ssvarma_sim.jls")
            doc_cfg = _parse_sim_json(["data", "simulate", "ssvarma", "--periods", "40",
                                       "--dist", "laplace", "--burn", "10", "--config", cfg,
                                       "--seed", "55", "--save-data", sp])
            @test length(doc_cfg.data.simulated_data.columns) == 4  # time + y1..y3
            @test isfile(sp)

            # Invalid dist
            e1 = try; _data_simulate_ssvarma(; dist="bogus"); nothing; catch ex; ex; end
            @test e1 isa CliError && e1.code == "usage/invalid"
            # Invalid nu for student-t
            e2 = try; _data_simulate_ssvarma(; dist="student-t", nu=1.5); nothing; catch ex; ex; end
            @test e2 isa CliError && e2.code == "usage/invalid"
        end
    end

    @testset "plot flag discipline on non-plottable v1.1.0 types" begin
        est_mv = APP.root.subcmds["estimate"].subcmds["multivariate"].subcmds
        fc_mv  = APP.root.subcmds["forecast"].subcmds["multivariate"].subcmds
        for (lbl, leaf) in (("estimate multivariate qvar", est_mv["qvar"]),
                            ("estimate multivariate qfavar", est_mv["qfavar"]),
                            ("forecast multivariate qfavar", fc_mv["qfavar"]))
            @test !any(f -> f.name == "plot", leaf.flags)
            @test !any(o -> o.name == "plot-save", leaf.options)
        end
    end
end
