# [MEM111-W3] #315 T2 mock unit tests — standalone runnable or included by test/test_commands.jl

using Test
using CSV, DataFrames, JSON3, PrettyTables, TOML
using Dates
using LinearAlgebra: eigvals, diag, I, svd, diagm, logdet, det
using Statistics: mean, median, var, quantile, std
using Random
using Serialization

if !@isdefined(register_estimate_commands!)
    project_root = dirname(@__DIR__)
    if !@isdefined(MacroEconometricModels)
        include(joinpath(project_root, "test", "mocks.jl"))
        using .MacroEconometricModels
    end
    if !@isdefined(tf_unicode_rounded)
        const tf_unicode_rounded = text_table_borders__unicode_rounded
    end
    include(joinpath(project_root, "src", "output", "errors.jl"))
    include(joinpath(project_root, "src", "io.jl"))
    include(joinpath(project_root, "src", "output", "envelope.jl"))
    include(joinpath(project_root, "src", "output", "render.jl"))
    include(joinpath(project_root, "src", "config.jl"))
    include(joinpath(project_root, "src", "model_card.jl"))
    if !@isdefined(FRIEDMAN_VERSION)
        const FRIEDMAN_VERSION = VersionNumber(
            TOML.parsefile(joinpath(project_root, "Project.toml"))["version"])
    end
    include(joinpath(project_root, "src", "cli", "types.jl"))
    include(joinpath(project_root, "src", "cli", "parser.jl"))
    include(joinpath(project_root, "src", "cli", "help.jl"))
    include(joinpath(project_root, "src", "cli", "dispatch.jl"))
    include(joinpath(project_root, "src", "commands", "shared.jl"))
    include(joinpath(project_root, "src", "model_handle.jl"))
    include(joinpath(project_root, "src", "handles.jl"))
    include(joinpath(project_root, "src", "registry", "spec.jl"))
    include(joinpath(project_root, "src", "registry", "adapter.jl"))
    include(joinpath(project_root, "src", "registry", "families.jl"))
    include(joinpath(project_root, "src", "commands", "w3_nongaussian.jl"))
    include(joinpath(project_root, "src", "commands", "estimate.jl"))
    include(joinpath(project_root, "src", "commands", "test.jl"))
    include(joinpath(project_root, "src", "commands", "irf.jl"))
    include(joinpath(project_root, "src", "commands", "fevd.jl"))
    include(joinpath(project_root, "src", "commands", "hd.jl"))
    include(joinpath(project_root, "src", "commands", "forecast.jl"))
    include(joinpath(project_root, "src", "commands", "fitted.jl"))
    include(joinpath(project_root, "src", "commands", "filter.jl"))
    include(joinpath(project_root, "src", "commands", "data_simulate.jl"))
    include(joinpath(project_root, "src", "commands", "data.jl"))
    include(joinpath(project_root, "src", "commands", "io.jl"))
    include(joinpath(project_root, "src", "commands", "nowcast.jl"))
    include(joinpath(project_root, "src", "commands", "dsge.jl"))
    include(joinpath(project_root, "src", "commands", "hadsge.jl"))
    include(joinpath(project_root, "src", "commands", "did.jl"))
    include(joinpath(project_root, "src", "commands", "multipliers.jl"))
    include(joinpath(project_root, "src", "commands", "policy.jl"))
    include(joinpath(project_root, "src", "commands", "spectral.jl"))
    include(joinpath(project_root, "src", "commands", "model.jl"))
    include(joinpath(project_root, "src", "commands", "completions.jl"))
    include(joinpath(project_root, "src", "commands", "show.jl"))
    include(joinpath(project_root, "test", "support.jl"))
end

function _w3_parse_json(raw::String)
    i = findfirst('{', raw)
    @test i !== nothing
    return JSON3.read(raw[i:end])
end

function _w3_dispatch_json(args::Vector{String})
    raw = _capture() do
        _dispatch_via_app(vcat(args, ["--format", "json"]))
    end
    return _w3_parse_json(raw)
end

@testset "[MEM111-W3] #315 Non-Gaussian SVAR, Hypothesis Battery, Lanne-Luoto GMM & SSVARMA" begin

    @testset "Registry, ID_METHOD_MAP & _TIDY_COEF_TYPES" begin
        for k in ("cvm", "mixture-normal-asym", "mixture_normal_asym", "lms")
            @test haskey(ID_METHOD_MAP, k)
            @test k in CONFIG_ENUMS["identification.method"]
        end
        @test "cue" in CONFIG_ENUMS["gmm.weighting"]
        for tok in ("lms-svar", "lanne-luoto", "ssvarma")
            @test _MODEL_FAMILY[tok] == "multivariate"
        end
        for tok in ("svar-hypothesis", "nongaussian-diag", "gmm-moments",
                    "fundamentalness", "sufficient-info")
            @test _TEST_FAMILY[tok] == "multivariate"
        end
        for T in (LMSSVARResult, SVARHypothesisTest, NonGaussianDiagnostics,
                  LanneLuotoGMMResult, GMMMomentSelectionResult, SVARMAModel,
                  FundamentalnessTestResult, SufficientInformationTestResult)
            @test T <: _TIDY_COEF_TYPES
        end
    end

    @testset "get_svar_hypothesis TOML parser — all 6 valid types & malformed guards" begin
        # 1. recursiveness (default, canonical, best_match, custom perm)
        h1 = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"recursiveness\"\n"))
        @test h1["type"] == "recursiveness" && h1["ordering"] === nothing

        h1b = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"recursiveness\"\nordering = \"best_match\"\n"))
        @test h1b["ordering"] === :best_match

        h1c = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"recursiveness\"\nordering = [2, 1, 3]\n"))
        @test h1c["ordering"] == [2, 1, 3]

        # 2. impact_zero (kebab-case alias too)
        h2 = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"impact-zero\"\nzeros = [[1, 2], [1, 3]]\n"))
        @test h2["type"] == "impact_zero"
        @test h2["zeros"] == [(1, 2), (1, 3)]

        # 3. impact_linear (with and without r)
        h3 = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"impact_linear\"\nR = [[1.0, 0.0], [0.0, 1.0]]\nr = [0.0, 0.5]\n"))
        @test h3["type"] == "impact_linear"
        @test size(h3["R"]) == (2, 2) && h3["r"] == [0.0, 0.5]

        h3_def = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"impact_linear\"\nR = [[1.0, -1.0]]\n"))
        @test h3_def["r"] == [0.0]

        # 4. long_run
        h4 = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"long_run\"\nzeros = [[1, 2]]\nordering = \"canonical\"\n"))
        @test h4["type"] == "long_run" && h4["zeros"] == [(1, 2)] && h4["ordering"] === :canonical

        # 5. horizon_irf (table entries with optional value=0.0 AND 3-element arrays)
        h5 = get_svar_hypothesis(TOML.parse("""
        [svar_hypothesis]
        type = "horizon_irf"
        restrictions = [{horizon = 1, var = 1, shock = 2, value = 0.0}, {horizon = 4, var = 2, shock = 1}]
        """))
        @test h5["type"] == "horizon_irf"
        @test h5["restrictions"] == [(1, 1, 2), (4, 2, 1)]

        h5b = get_svar_hypothesis(TOML.parse("[svar_hypothesis]\ntype = \"horizon-irf\"\nrestrictions = [[0, 1, 2], [2, 2, 1]]\n"))
        @test h5b["restrictions"] == [(0, 1, 2), (2, 2, 1)]

        # 6. mixed (short_run + long_run + horizon)
        h6 = get_svar_hypothesis(TOML.parse("""
        [svar_hypothesis]
        type = "mixed"
        [svar_hypothesis.short_run]
        zeros = [[1, 2]]
        [svar_hypothesis.long_run]
        zeros = [[1, 3]]
        [svar_hypothesis.horizon]
        restrictions = [{horizon = 2, var = 2, shock = 1}]
        """))
        @test h6["type"] == "mixed"
        @test h6["short_run"]["type"] == "impact_zero"
        @test h6["long_run"]["zeros"] == [(1, 3)]
        @test h6["horizon"]["restrictions"] == [(2, 2, 1)]

        # Malformed specs → typed config/invalid
        bad_tomls = [
            "",  # missing section
            "[svar_hypothesis]\nzeros = [[1, 2]]\n",  # missing type
            "[svar_hypothesis]\ntype = \"bogus\"\n",  # unknown type
            "[svar_hypothesis]\ntype = \"recursiveness\"\nordering = [1, 3]\n",  # not a perm
            "[svar_hypothesis]\ntype = \"recursiveness\"\nordering = \"random\"\n",  # bad ordering str
            "[svar_hypothesis]\ntype = \"impact_zero\"\n",  # missing zeros
            "[svar_hypothesis]\ntype = \"impact_zero\"\nzeros = []\n",  # empty zeros
            "[svar_hypothesis]\ntype = \"impact_zero\"\nzeros = [[1, 2], [1, 2]]\n",  # duplicate
            "[svar_hypothesis]\ntype = \"impact_zero\"\nzeros = [[0, 2]]\n",  # non-positive
            "[svar_hypothesis]\ntype = \"impact_linear\"\nR = [[1.0], [1.0, 2.0]]\n",  # ragged R
            "[svar_hypothesis]\ntype = \"impact_linear\"\nR = [[1.0, 0.0]]\nr = [0.0, 1.0]\n",  # r mismatch
            "[svar_hypothesis]\ntype = \"long_run\"\nzeros = [[1]]\n",  # wrong tuple len
            "[svar_hypothesis]\ntype = \"horizon_irf\"\nrestrictions = [{horizon = -1, var = 1, shock = 2}]\n",
            "[svar_hypothesis]\ntype = \"horizon_irf\"\nrestrictions = [{horizon = 1, var = 1, shock = 2, value = 0.5}]\n",
            "[svar_hypothesis]\ntype = \"horizon_irf\"\nrestrictions = [{horizon = 1, var = 1}]\n",
            "[svar_hypothesis]\ntype = \"mixed\"\n",  # empty mixed
            "[svar_hypothesis]\ntype = \"mixed\"\n[svar_hypothesis.short_run]\nrecursiveness = true\nzeros = [[1, 2]]\n",  # conflicting
        ]
        for (idx, txt) in enumerate(bad_tomls)
            err = try
                get_svar_hypothesis(TOML.parse(txt))
                nothing
            catch e
                e
            end
            @test err isa CliError
            @test err.code == "config/invalid"
        end
    end

    @testset "Upgraded leaves: CvM ICA, asymmetric ML + vcov-type, GMM CUE, identifiability CvM" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=120, n=3)

            # estimate factor fastica --method cvm
            doc_cvm = _w3_dispatch_json(["estimate", "factor", "fastica", csv,
                                         "--lags", "2", "--method", "cvm", "--n-starts", "2"])
            @test doc_cvm.status == "ok"
            @test haskey(doc_cvm.data, :structural_impact_matrix_b0)
            @test haskey(doc_cvm.data, :structural_impact_standard_errors)
            @test haskey(doc_cvm.data, :structural_shocks)

            # test identifiability --method cvm
            doc_id = _w3_dispatch_json(["test", "identifiability", csv,
                                        "--lags", "2", "--method", "cvm", "--n-starts", "2"])
            @test doc_id.status == "ok"
            @test haskey(doc_id.data, :identifiability_test_results)

            # label-stability + cvm guard
            err_ls = try
                _test_identifiability(; data=csv, lags=2, test="label-stability", method="cvm")
                nothing
            catch e; e; end
            @test err_ls isa CliError && err_ls.code == "usage/invalid"

            # estimate regression ml --asymmetric + vcov-type + n-starts + max-iter + tol
            doc_ml = _w3_dispatch_json(["estimate", "regression", "ml", csv,
                                        "--lags", "2", "--distribution", "mixture_normal",
                                        "--asymmetric", "--vcov-type", "sandwich",
                                        "--n-starts", "2", "--max-iter", "50", "--tol", "1e-5"])
            @test doc_ml.status == "ok"
            @test haskey(doc_ml.data, :structural_impact_matrix_b0)
            @test haskey(doc_ml.data, :parameter_estimates_with_standard_errors)

            # --vcov-type information accepted
            doc_ml_info = _w3_dispatch_json(["estimate", "regression", "ml", csv,
                                             "--lags", "2", "--distribution", "student_t",
                                             "--vcov-type", "information"])
            @test doc_ml_info.status == "ok"

            # --asymmetric guard on non-mixture distribution
            err_asym = try
                _estimate_ml(; data=csv, lags=2, distribution="student_t", asymmetric=true)
                nothing
            catch e; e; end
            @test err_asym isa CliError && err_asym.code == "usage/invalid"

            # estimate regression gmm --weighting cue (LP-GMM & IV-GMM)
            gmm_cfg = joinpath(dir, "gmm_lp.toml")
            write(gmm_cfg, "[gmm]\nmoment_conditions = [\"var1\"]\nweighting = \"cue\"\n")
            doc_gmm = _w3_dispatch_json(["estimate", "regression", "gmm", csv,
                                         "--config", gmm_cfg, "--weighting", "cue"])
            @test doc_gmm.status == "ok"

            iv_csv = joinpath(dir, "iv.csv")
            CSV.write(iv_csv, DataFrame(y=randn(100), x1=randn(100), z1=randn(100), z2=randn(100)))
            iv_cfg = joinpath(dir, "gmm_iv.toml")
            write(iv_cfg, "[gmm]\ndep = \"y\"\nendogenous = [\"x1\"]\ninstruments = [\"z1\", \"z2\"]\ntheta0 = [0.0, 0.5]\n")
            doc_iv = _w3_dispatch_json(["estimate", "regression", "gmm", iv_csv,
                                        "--config", iv_cfg, "--weighting", "cue"])
            @test doc_iv.status == "ok"
            @test haskey(doc_iv.data, :gmm_estimates)

            # irf/fevd/hd var with new --id methods cvm, mixture-normal-asym, lms
            for id_m in ("cvm", "mixture-normal-asym", "lms")
                doc_i = _w3_dispatch_json(["irf", "var", csv, "--lags", "1", "--id", id_m, "--ci", "none", "--horizons", "5"])
                @test doc_i.status == "ok"
                doc_f = _w3_dispatch_json(["fevd", "var", csv, "--lags", "1", "--id", id_m, "--horizons", "5"])
                @test doc_f.status == "ok"
                doc_h = _w3_dispatch_json(["hd", "var", csv, "--lags", "1", "--id", id_m])
                @test doc_h.status == "ok"
            end
        end
    end

    @testset "LMS-SVAR estimate, residuals, plot-save & downstream irf/fevd/hd" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=120, n=3)
            mod_path = joinpath(dir, "lms.jld2")
            plt_path = joinpath(dir, "lms.html")
            doc = _w3_dispatch_json(["estimate", "multivariate", "lms-svar", csv,
                                     "--lags", "2", "--distributions", "student-t,mixture-normal,skew-normal",
                                     "--method", "one-step", "--se", "sandwich",
                                     "--n-starts", "2", "--max-iter", "100", "--tol", "1e-6",
                                     "--save-model", mod_path, "--plot-save", plt_path])
            @test doc.status == "ok"
            @test haskey(doc.data, :lms_svar_estimates)
            @test isfile(mod_path)
            @test isfile(plt_path)

            # residuals inline + --model
            doc_r1 = _w3_dispatch_json(["residuals", "multivariate", "lms-svar", csv, "--lags", "2"])
            @test doc_r1.status == "ok" && haskey(doc_r1.data, :lms_svar_residuals)
            doc_r2 = _w3_dispatch_json(["residuals", "multivariate", "lms-svar", "--model", mod_path])
            @test doc_r2.status == "ok" && haskey(doc_r2.data, :lms_svar_residuals)

            # downstream irf / fevd / hd var --model <LMSSVARResult>
            doc_irf = _w3_dispatch_json(["irf", "var", "--model", mod_path, "--ci", "none", "--horizons", "8"])
            @test doc_irf.status == "ok" && haskey(doc_irf.data, :irf)
            doc_fevd = _w3_dispatch_json(["fevd", "var", "--model", mod_path, "--horizons", "8"])
            @test doc_fevd.status == "ok" && haskey(doc_fevd.data, :fevd)
            doc_hd = _w3_dispatch_json(["hd", "var", "--model", mod_path])
            @test doc_hd.status == "ok"

            # invalid distribution length guard
            err_d = try
                _estimate_lms_svar(; data=csv, lags=2, distributions="student-t,skew-normal")
                nothing
            catch e; e; end
            @test err_d isa CliError && err_d.code == "usage/invalid"
        end
    end

    @testset "Hypothesis battery (6 types) & non-Gaussian diagnostics" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=120, n=3)
            lms_path = joinpath(dir, "lms.jld2")
            ll_path = joinpath(dir, "ll.jld2")
            _w3_dispatch_json(["estimate", "multivariate", "lms-svar", csv, "--lags", "1", "--save-model", lms_path])
            _w3_dispatch_json(["estimate", "multivariate", "lanne-luoto", csv, "--lags", "1", "--save-model", ll_path])

            # 1. recursiveness without config + bootstrap + save/replay result + plot
            res_path = joinpath(dir, "hyp.jld2")
            plt_path = joinpath(dir, "hyp.html")
            d_rec = _w3_dispatch_json(["test", "multivariate", "svar-hypothesis", "--model", lms_path,
                                       "--type", "recursiveness", "--method", "lr",
                                       "--bootstrap", "wild", "--n-boot", "10",
                                       "--save-result", res_path, "--plot-save", plt_path])
            @test d_rec.status == "ok" && haskey(d_rec.data, :svar_hypothesis_test)
            @test isfile(res_path) && isfile(plt_path)
            d_rep = _w3_dispatch_json(["test", "multivariate", "svar-hypothesis", "--result", res_path])
            @test d_rep.status == "ok" && haskey(d_rep.data, :svar_hypothesis_test)

            # 2-6. config-driven types: impact_zero, impact_linear, long_run, horizon_irf, mixed
            cfgs = [
                ("impact_zero", "[svar_hypothesis]\ntype = \"impact_zero\"\nzeros = [[1, 2]]\n"),
                ("impact_linear", "[svar_hypothesis]\ntype = \"impact_linear\"\nR = [[1.0, 0.0, 0.0, 0.0, 0.0, 0.0]]\nr = [0.0]\n"),
                ("long_run", "[svar_hypothesis]\ntype = \"long_run\"\nzeros = [[1, 2]]\n"),
                ("horizon_irf", "[svar_hypothesis]\ntype = \"horizon_irf\"\nrestrictions = [{horizon = 1, var = 1, shock = 2}]\n"),
                ("mixed", "[svar_hypothesis]\ntype = \"mixed\"\n[svar_hypothesis.short_run]\nzeros = [[1, 2]]\n[svar_hypothesis.long_run]\nzeros = [[1, 3]]\n"),
            ]
            for (nm, txt) in cfgs
                cp = joinpath(dir, "$nm.toml")
                write(cp, txt)
                d_h = _w3_dispatch_json(["test", "multivariate", "svar-hypothesis", "--model", lms_path,
                                         "--config", cp, "--method", "wald"])
                @test d_h.status == "ok" && haskey(d_h.data, :svar_hypothesis_test)
            end

            # Lanne-Luoto GMM hypothesis (--method gmm-lr)
            d_gmm_hyp = _w3_dispatch_json(["test", "multivariate", "svar-hypothesis", "--model", ll_path,
                                           "--type", "recursiveness", "--method", "gmm-lr"])
            @test d_gmm_hyp.status == "ok" && haskey(d_gmm_hyp.data, :svar_hypothesis_test)

            # Method/estimator mismatch guards
            err_g = try
                _dispatch_via_app(["test", "multivariate", "svar-hypothesis", "--model", lms_path,
                                   "--type", "recursiveness", "--method", "gmm-lr", "--format", "json"])
                nothing
            catch e; e; end
            @test err_g isa CliError && err_g.code == "usage/invalid"

            err_b = try
                _dispatch_via_app(["test", "multivariate", "svar-hypothesis", "--model", ll_path,
                                   "--type", "recursiveness", "--method", "wald", "--bootstrap", "wild", "--format", "json"])
                nothing
            catch e; e; end
            @test err_b isa CliError && err_b.code == "usage/invalid"

            # nongaussian-diag inline + --model + --save-result/--result + --plot-save
            diag_res = joinpath(dir, "diag.jld2")
            diag_plt = joinpath(dir, "diag.html")
            d_diag = _w3_dispatch_json(["test", "multivariate", "nongaussian-diag", "--model", lms_path,
                                        "--diag-lags", "4", "--save-result", diag_res, "--plot-save", diag_plt])
            @test d_diag.status == "ok" && haskey(d_diag.data, :nongaussian_diagnostics)
            @test isfile(diag_res) && isfile(diag_plt)
            d_diag_rep = _w3_dispatch_json(["test", "multivariate", "nongaussian-diag", "--result", diag_res])
            @test d_diag_rep.status == "ok" && haskey(d_diag_rep.data, :nongaussian_diagnostics)
        end
    end

    @testset "Lanne-Luoto GMM & moment selection" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=120, n=3)
            ll_path = joinpath(dir, "ll.jld2")
            ll_plt = joinpath(dir, "ll.html")
            d_ll = _w3_dispatch_json(["estimate", "multivariate", "lanne-luoto", csv,
                                      "--lags", "1", "--form", "a-model", "--weighting", "cue",
                                      "--moment-selection", "rmsc-seq", "--kernel", "parzen",
                                      "--bandwidth", "4", "--save-model", ll_path, "--plot-save", ll_plt])
            @test d_ll.status == "ok" && haskey(d_ll.data, :lanne_luoto_gmm_estimates)
            @test isfile(ll_path) && isfile(ll_plt)

            # residuals + irf/fevd/hd var --model <LanneLuotoGMMResult>
            @test _w3_dispatch_json(["residuals", "multivariate", "lanne-luoto", "--model", ll_path]).status == "ok"
            @test _w3_dispatch_json(["irf", "var", "--model", ll_path, "--ci", "none", "--horizons", "6"]).status == "ok"
            @test _w3_dispatch_json(["fevd", "var", "--model", ll_path, "--horizons", "6"]).status == "ok"
            @test _w3_dispatch_json(["hd", "var", "--model", ll_path]).status == "ok"

            # test multivariate gmm-moments
            gm_res = joinpath(dir, "gm.jld2")
            gm_plt = joinpath(dir, "gm.html")
            d_gm = _w3_dispatch_json(["test", "multivariate", "gmm-moments", csv,
                                      "--lags", "1", "--weighting", "cue",
                                      "--save-result", gm_res, "--plot-save", gm_plt])
            @test d_gm.status == "ok" && haskey(d_gm.data, :gmm_moment_selection)
            @test isfile(gm_res) && isfile(gm_plt)
            @test _w3_dispatch_json(["test", "multivariate", "gmm-moments", "--result", gm_res]).status == "ok"
        end
    end

    @testset "Strong SVARMA, fundamentalness & sufficient-info" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=120, n=2)
            panel_csv = _make_csv(dir; T=120, n=5, colnames=["x1", "x2", "x3", "x4", "x5"])
            panel_path = joinpath(dir, "panel.csv")
            cp(panel_csv, panel_path; force=true)
            csv2 = joinpath(dir, "var_data.csv")
            CSV.write(csv2, DataFrame(y1=randn(120), y2=randn(120)))

            sv_path = joinpath(dir, "ssvarma.jld2")
            sv_plt = joinpath(dir, "ssvarma.html")
            d_sv = _w3_dispatch_json(["estimate", "multivariate", "ssvarma", csv2,
                                      "--ar-lags", "1", "--ma-lags", "1", "--method", "pml",
                                      "--distribution", "mixture-normal-asym", "--se", "sandwich",
                                      "--blaschke", "--save-model", sv_path, "--plot-save", sv_plt])
            @test d_sv.status == "ok"
            @test haskey(d_sv.data, :ssvarma_estimates)
            @test haskey(d_sv.data, :ssvarma_regime)
            @test haskey(d_sv.data, :ssvarma_blaschke)
            @test isfile(sv_path) && isfile(sv_plt)

            # gmm-2sls alias
            d_gmm2 = _w3_dispatch_json(["estimate", "multivariate", "ssvarma", csv2,
                                        "--ar-lags", "1", "--ma-lags", "1", "--method", "gmm-2sls"])
            @test d_gmm2.status == "ok"

            # residuals / irf / fevd ssvarma
            @test _w3_dispatch_json(["residuals", "multivariate", "ssvarma", "--model", sv_path]).status == "ok"
            d_irf = _w3_dispatch_json(["irf", "ssvarma", "--model", sv_path, "--horizons", "8", "--shock", "1"])
            @test d_irf.status == "ok" && haskey(d_irf.data, :ssvarma_irf)
            d_fevd = _w3_dispatch_json(["fevd", "ssvarma", "--model", sv_path, "--horizons", "8"])
            @test d_fevd.status == "ok" && haskey(d_fevd.data, :ssvarma_fevd)

            # fundamentalness inline + --model <SVARMAModel> + --save-result/--result + --plot-save
            fn_res = joinpath(dir, "fund.jld2")
            fn_plt = joinpath(dir, "fund.html")
            d_fn = _w3_dispatch_json(["test", "multivariate", "fundamentalness", "--model", sv_path,
                                      "--max-lag", "4", "--moments", "skew,kurt", "--n-boot", "25",
                                      "--save-result", fn_res, "--plot-save", fn_plt])
            @test d_fn.status == "ok" && haskey(d_fn.data, :fundamentalness_test)
            @test isfile(fn_res) && isfile(fn_plt)
            @test _w3_dispatch_json(["test", "multivariate", "fundamentalness", "--result", fn_res]).status == "ok"

            # sufficient-info with <data> + --panel, --model + --factors, and mutual-exclusion guards
            fm_path = joinpath(dir, "fm.jld2")
            _w3_dispatch_json(["estimate", "factor", "static", panel_path, "--nfactors", "2", "--save-model", fm_path])
            si_res = joinpath(dir, "si.jld2")
            si_plt = joinpath(dir, "si.html")
            d_si1 = _w3_dispatch_json(["test", "multivariate", "sufficient-info", csv2,
                                       "--lags", "1", "--panel", panel_path, "--r-max", "3", "--p-f", "2",
                                       "--save-result", si_res, "--plot-save", si_plt])
            @test d_si1.status == "ok" && haskey(d_si1.data, :sufficient_information_test)
            @test isfile(si_res) && isfile(si_plt)

            d_si2 = _w3_dispatch_json(["test", "multivariate", "sufficient-info", "--model", sv_path,
                                       "--factors", fm_path, "--r-max", "2", "--p-f", "2"])
            @test d_si2.status == "ok" && haskey(d_si2.data, :sufficient_information_test)
            @test _w3_dispatch_json(["test", "multivariate", "sufficient-info", "--result", si_res]).status == "ok"

            # allow_data_with_model=true on sufficient-info
            si_specs = filter(s -> s.path == ["test", "multivariate", "sufficient-info"], REGISTRY)
            @test !isempty(si_specs) && last(si_specs).allow_data_with_model

            # guard: both --panel and --factors
            err_both = try
                _test_sufficient_info(; data=csv2, panel=panel_path, factors=fm_path)
                nothing
            catch e; e; end
            @test err_both isa CliError && err_both.code == "usage/invalid"

            # guard: neither --panel nor --factors
            err_none = try
                _test_sufficient_info(; data=csv2)
                nothing
            catch e; e; end
            @test err_none isa CliError && err_none.code == "usage/missing-option"
        end
    end

end
