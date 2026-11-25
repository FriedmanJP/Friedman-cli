# [MEM111-W3] #315 Real-MEMs T3 integration tests — standalone runnable or included by test/integration/runtests.jl

using Test
using JSON3
using CSV
using DataFrames
using Friedman
using Random
using Statistics
using LinearAlgebra
import MacroEconometricModels

if !@isdefined(run_json)
    const ROOT = dirname(dirname(@__DIR__))
    const SCHEMA_PATH = joinpath(ROOT, "schema", "envelope-v1.json")
    include(joinpath(@__DIR__, "schema_validate.jl"))

    function run_json(args::Vector{String}; quiet::Bool=true)
        argv = String[]
        quiet && push!(argv, "--quiet")
        append!(argv, args)
        any(a -> startswith(a, "--format") || a == "-f" || startswith(a, "-f=") || a == "--json", argv) ||
            push!(argv, "--format", "json")
        out_path = tempname()
        err_path = tempname()
        code = try
            open(out_path, "w") do out_io
                open(err_path, "w") do err_io
                    redirect_stdout(out_io) do
                        redirect_stderr(err_io) do
                            return Friedman.run_cli(argv)
                        end
                    end
                end
            end
        catch
            Cint(1)
        end
        raw = read(out_path, String)
        rm(out_path; force=true)
        rm(err_path; force=true)
        doc = try
            JSON3.read(strip(raw))
        catch
            nothing
        end
        return (code=Int(code), doc=doc, raw=raw)
    end

    function assert_envelope_ok(r; label="")
        @test r.code == 0
        @test r.doc !== nothing
        r.doc === nothing && return
        @test string(r.doc.status) == "ok"
        errs = validate_envelope_json(r.raw; schema_path=SCHEMA_PATH)
        @test isempty(errs)
        if !isempty(errs)
            @info "schema errors for $label" errs
        end
    end
end

@testset "MEM111-W3 (#315): LMS-SVAR, Hypothesis Battery, Lanne-Luoto GMM, CvM ICA, GMM CUE & SSVARMA" begin
    mktempdir() do dir
        # Non-Gaussian VAR(1) DGP (n=2, heavy-tailed Student-t shocks for strong statistical ID)
        rng_ng = MersenneTwister(3151)
        ng_sim = MacroEconometricModels.dgp_nongaussian_var(rng_ng; T=250, dist=:t, nu=4.0)
        ng_csv = joinpath(dir, "ng_var.csv")
        CSV.write(ng_csv, DataFrame(y1=ng_sim.Y[:, 1], y2=ng_sim.Y[:, 2]))

        # Non-fundamental Strong SVARMA(1,1) DGP (GMR eq. 4.27 mixed non-fundamental)
        sv_sim = MacroEconometricModels.dgp_ssvarma(; T=240, dist=:student_t, nu=4.0, seed=3152)
        sv_csv = joinpath(dir, "ssvarma.csv")
        CSV.write(sv_csv, DataFrame(y1=sv_sim.Y[:, 1], y2=sv_sim.Y[:, 2]))

        # Large informational panel aligned with sv_sim for sufficient-info test
        rng_p = MersenneTwister(3153)
        T_p = size(sv_sim.Y, 1)
        F_lat = randn(rng_p, T_p, 2)
        Load = randn(rng_p, 2, 6)
        X_pan = F_lat * Load .+ 0.3 .* randn(rng_p, T_p, 6)
        panel_csv = joinpath(dir, "panel.csv")
        CSV.write(panel_csv, DataFrame(X_pan, ["x$j" for j in 1:6]))

        # 1. CvM ICA + test identifiability --method cvm
        @testset "CvM ICA & identifiability" begin
            r_cvm = run_json(["--seed", "11", "estimate", "factor", "fastica", ng_csv,
                              "--lags", "1", "--method", "cvm", "--n-starts", "2"])
            assert_envelope_ok(r_cvm; label="estimate factor fastica --method cvm")
            @test haskey(r_cvm.doc.data, :structural_impact_matrix_b0)
            @test haskey(r_cvm.doc.data, :structural_impact_standard_errors)
            @test haskey(r_cvm.doc.data, :structural_shocks)

            r_id = run_json(["--seed", "11", "test", "identifiability", ng_csv,
                             "--lags", "1", "--method", "cvm", "--n-starts", "2", "--test", "gaussianity"])
            assert_envelope_ok(r_id; label="test identifiability --method cvm")
            @test haskey(r_id.doc.data, :identifiability_test_results)
        end

        # 2. Asymmetric mixture-of-normals ML & vcov-type
        @testset "ML --asymmetric & --vcov-type" begin
            r_ml = run_json(["--seed", "12", "estimate", "regression", "ml", ng_csv,
                             "--lags", "1", "--distribution", "mixture_normal",
                             "--asymmetric", "--vcov-type", "sandwich",
                             "--n-starts", "2", "--max-iter", "80", "--tol", "1e-5"])
            assert_envelope_ok(r_ml; label="estimate regression ml --asymmetric")
            @test haskey(r_ml.doc.data, :structural_impact_matrix_b0)
            @test haskey(r_ml.doc.data, :parameter_estimates_with_standard_errors)
            @test length(r_ml.doc.data.parameter_estimates_with_standard_errors.rows) == 4

            r_bad = run_json(["estimate", "regression", "ml", ng_csv,
                              "--lags", "1", "--distribution", "student_t", "--asymmetric"])
            @test r_bad.code == 2
            @test string(r_bad.doc.error.code) == "usage/invalid"
        end

        # 3. GMM CUE weighting
        @testset "GMM --weighting cue" begin
            rng_iv = MersenneTwister(3154)
            N_iv = 180
            z1 = randn(rng_iv, N_iv); z2 = randn(rng_iv, N_iv)
            u = randn(rng_iv, N_iv)
            x1 = 0.8 .* z1 .+ 0.6 .* z2 .+ 0.5 .* u .+ 0.3 .* randn(rng_iv, N_iv)
            y = 1.0 .+ 2.0 .* x1 .+ u
            iv_csv = joinpath(dir, "iv_cue.csv")
            CSV.write(iv_csv, DataFrame(y=y, x1=x1, z1=z1, z2=z2))
            iv_cfg = joinpath(dir, "iv_cue.toml")
            write(iv_cfg, "[gmm]\ndep = \"y\"\nendogenous = [\"x1\"]\ninstruments = [\"z1\", \"z2\"]\ntheta0 = [0.5, 1.5]\n")

            r_cue = run_json(["estimate", "regression", "gmm", iv_csv,
                              "--config", iv_cfg, "--weighting", "cue"])
            assert_envelope_ok(r_cue; label="estimate regression gmm --weighting cue")
            @test haskey(r_cue.doc.data, :gmm_estimates)
        end

        # 4. ID_METHOD_MAP upgrades (cvm, mixture-normal-asym, lms)
        @testset "IRF with cvm / mixture-normal-asym / lms" begin
            for id_m in ("cvm", "mixture-normal-asym", "lms")
                r_i = run_json(["--seed", "13", "irf", "var", ng_csv,
                                "--lags", "1", "--id", id_m, "--ci", "none", "--horizons", "6"])
                assert_envelope_ok(r_i; label="irf var --id $id_m")
                @test haskey(r_i.doc.data, :irf)
            end
        end

        # 5. LMS-SVAR + residuals + downstream irf/fevd/hd + 6-type hypothesis battery + nongaussian-diag
        lms_path = joinpath(dir, "lms_model.jld2")
        @testset "LMS-SVAR, hypothesis battery & non-Gaussian diagnostics" begin
            lms_plt = joinpath(dir, "lms.html")
            r_lms = run_json(["--seed", "14", "estimate", "multivariate", "lms-svar", ng_csv,
                              "--lags", "1", "--distributions", "student-t,student-t",
                              "--method", "three-step", "--se", "sandwich",
                              "--n-starts", "2", "--max-iter", "120",
                              "--save-model", lms_path, "--plot-save", lms_plt])
            assert_envelope_ok(r_lms; label="estimate multivariate lms-svar")
            @test haskey(r_lms.doc.data, :lms_svar_estimates)
            @test isfile(lms_path)
            @test isfile(lms_plt) && filesize(lms_plt) > 0

            r_lms_res = run_json(["residuals", "multivariate", "lms-svar", "--model", lms_path])
            assert_envelope_ok(r_lms_res; label="residuals multivariate lms-svar --model")
            @test haskey(r_lms_res.doc.data, :lms_svar_residuals)

            r_lms_irf = run_json(["irf", "var", "--model", lms_path, "--ci", "none", "--horizons", "6"])
            assert_envelope_ok(r_lms_irf; label="irf var --model LMSSVARResult")
            r_lms_fevd = run_json(["fevd", "var", "--model", lms_path, "--horizons", "6"])
            assert_envelope_ok(r_lms_fevd; label="fevd var --model LMSSVARResult")
            r_lms_hd = run_json(["hd", "var", "--model", lms_path])
            assert_envelope_ok(r_lms_hd; label="hd var --model LMSSVARResult")

            # All 6 hypothesis types on real LMSSVARResult
            hyp_res_path = joinpath(dir, "hyp_rec.jld2")
            hyp_plt = joinpath(dir, "hyp_rec.html")
            r_h1 = run_json(["--seed", "15", "test", "multivariate", "svar-hypothesis",
                             "--model", lms_path, "--type", "recursiveness",
                             "--method", "wald", "--bootstrap", "wild", "--n-boot", "5",
                             "--save-result", hyp_res_path, "--plot-save", hyp_plt])
            assert_envelope_ok(r_h1; label="svar-hypothesis recursiveness wald+wild")
            @test haskey(r_h1.doc.data, :svar_hypothesis_test)
            @test isfile(hyp_res_path)
            @test isfile(hyp_plt) && filesize(hyp_plt) > 0

            # --result replay
            r_h1_rep = run_json(["test", "multivariate", "svar-hypothesis", "--result", hyp_res_path])
            assert_envelope_ok(r_h1_rep; label="svar-hypothesis --result replay")
            @test haskey(r_h1_rep.doc.data, :svar_hypothesis_test)

            # lr and lm methods on recursiveness
            for mth in ("lr", "lm")
                r_m = run_json(["test", "multivariate", "svar-hypothesis",
                                "--model", lms_path, "--type", "recursiveness", "--method", mth])
                assert_envelope_ok(r_m; label="svar-hypothesis recursiveness $mth")
            end

            # Config-driven types: impact_zero, impact_linear, long_run, horizon_irf, mixed
            cfgs = [
                ("impact_zero", "[svar_hypothesis]\ntype = \"impact_zero\"\nzeros = [[1, 2]]\n"),
                ("impact_linear", "[svar_hypothesis]\ntype = \"impact_linear\"\nR = [[1.0, 0.0]]\nr = [0.0]\n"),
                ("long_run", "[svar_hypothesis]\ntype = \"long_run\"\nzeros = [[1, 2]]\n"),
                ("horizon_irf", "[svar_hypothesis]\ntype = \"horizon_irf\"\nrestrictions = [{horizon = 1, var = 1, shock = 2}]\n"),
                ("mixed", "[svar_hypothesis]\ntype = \"mixed\"\n[svar_hypothesis.short_run]\nzeros = [[1, 2]]\n[svar_hypothesis.long_run]\nzeros = [[2, 1]]\n"),
            ]
            for (nm, txt) in cfgs
                cp = joinpath(dir, "hyp_$nm.toml")
                write(cp, txt)
                r_ht = run_json(["test", "multivariate", "svar-hypothesis",
                                 "--model", lms_path, "--config", cp, "--method", "wald"])
                assert_envelope_ok(r_ht; label="svar-hypothesis $nm")
                @test haskey(r_ht.doc.data, :svar_hypothesis_test)
            end

            # Non-Gaussian diagnostics
            diag_res = joinpath(dir, "ng_diag.jld2")
            diag_plt = joinpath(dir, "ng_diag.html")
            r_dg = run_json(["test", "multivariate", "nongaussian-diag",
                             "--model", lms_path, "--diag-lags", "4",
                             "--save-result", diag_res, "--plot-save", diag_plt])
            assert_envelope_ok(r_dg; label="test multivariate nongaussian-diag")
            @test haskey(r_dg.doc.data, :nongaussian_diagnostics)
            @test isfile(diag_res) && isfile(diag_plt) && filesize(diag_plt) > 0
            r_dg_rep = run_json(["test", "multivariate", "nongaussian-diag", "--result", diag_res])
            assert_envelope_ok(r_dg_rep; label="nongaussian-diag --result replay")
        end

        # 6. Lanne-Luoto co-kurtosis GMM + moment selection + GMM-LR hypothesis + downstream irf/fevd/hd
        @testset "Lanne-Luoto GMM & moment selection" begin
            ll_path = joinpath(dir, "ll_model.jld2")
            ll_plt = joinpath(dir, "ll.html")
            r_ll = run_json(["--seed", "16", "estimate", "multivariate", "lanne-luoto", ng_csv,
                             "--lags", "1", "--form", "b-model", "--weighting", "two-step",
                             "--moment-selection", "none", "--n-starts", "2", "--max-iter", "60",
                             "--save-model", ll_path, "--plot-save", ll_plt])
            assert_envelope_ok(r_ll; label="estimate multivariate lanne-luoto")
            @test haskey(r_ll.doc.data, :lanne_luoto_gmm_estimates)
            @test isfile(ll_path) && isfile(ll_plt) && filesize(ll_plt) > 0

            r_ll_res = run_json(["residuals", "multivariate", "lanne-luoto", "--model", ll_path])
            assert_envelope_ok(r_ll_res; label="residuals multivariate lanne-luoto --model")
            r_ll_irf = run_json(["irf", "var", "--model", ll_path, "--ci", "none", "--horizons", "6"])
            assert_envelope_ok(r_ll_irf; label="irf var --model LanneLuotoGMMResult")
            r_ll_fevd = run_json(["fevd", "var", "--model", ll_path, "--horizons", "6"])
            assert_envelope_ok(r_ll_fevd; label="fevd var --model LanneLuotoGMMResult")
            r_ll_hd = run_json(["hd", "var", "--model", ll_path])
            assert_envelope_ok(r_ll_hd; label="hd var --model LanneLuotoGMMResult")

            # GMM-LR hypothesis test on LanneLuotoGMMResult
            r_gmm_lr = run_json(["test", "multivariate", "svar-hypothesis",
                                 "--model", ll_path, "--type", "recursiveness", "--method", "gmm-lr"])
            assert_envelope_ok(r_gmm_lr; label="svar-hypothesis LanneLuoto gmm-lr")

            # Moment selection
            gm_res = joinpath(dir, "gmm_mom.jld2")
            gm_plt = joinpath(dir, "gmm_mom.html")
            r_gm = run_json(["--seed", "17", "test", "multivariate", "gmm-moments", ng_csv,
                             "--lags", "1", "--n-starts", "2", "--max-iter", "50",
                             "--save-result", gm_res, "--plot-save", gm_plt])
            assert_envelope_ok(r_gm; label="test multivariate gmm-moments")
            @test haskey(r_gm.doc.data, :gmm_moment_selection)
            @test isfile(gm_res) && isfile(gm_plt) && filesize(gm_plt) > 0
            r_gm_rep = run_json(["test", "multivariate", "gmm-moments", "--result", gm_res])
            assert_envelope_ok(r_gm_rep; label="gmm-moments --result replay")
        end

        # 7. Non-fundamental Strong SVARMA + Blaschke + residuals/irf/fevd + fundamentalness + sufficient-info
        @testset "Strong SVARMA, fundamentalness & sufficient-info" begin
            sv_path = joinpath(dir, "ssvarma_model.jld2")
            sv_plt = joinpath(dir, "ssvarma.html")
            r_sv = run_json(["--seed", "18", "estimate", "multivariate", "ssvarma", sv_csv,
                             "--ar-lags", "1", "--ma-lags", "1", "--method", "pml",
                             "--distribution", "student-t", "--n-starts", "1", "--max-iter", "60",
                             "--blaschke", "--save-model", sv_path, "--plot-save", sv_plt])
            assert_envelope_ok(r_sv; label="estimate multivariate ssvarma --blaschke")
            @test haskey(r_sv.doc.data, :ssvarma_estimates)
            @test haskey(r_sv.doc.data, :ssvarma_regime)
            @test haskey(r_sv.doc.data, :ssvarma_blaschke)
            @test isfile(sv_path) && isfile(sv_plt) && filesize(sv_plt) > 0

            r_sv_res = run_json(["residuals", "multivariate", "ssvarma", "--model", sv_path])
            assert_envelope_ok(r_sv_res; label="residuals multivariate ssvarma --model")
            @test haskey(r_sv_res.doc.data, :ssvarma_residuals)

            r_sv_irf = run_json(["irf", "ssvarma", "--model", sv_path, "--horizons", "8", "--shock", "1"])
            assert_envelope_ok(r_sv_irf; label="irf ssvarma --model")
            @test haskey(r_sv_irf.doc.data, :ssvarma_irf)

            r_sv_fevd = run_json(["fevd", "ssvarma", "--model", sv_path, "--horizons", "8"])
            assert_envelope_ok(r_sv_fevd; label="fevd ssvarma --model")
            @test haskey(r_sv_fevd.doc.data, :ssvarma_fevd)

            # Fundamentalness test (on saved SVARMAModel + inline VAR)
            fn_res = joinpath(dir, "fund.jld2")
            fn_plt = joinpath(dir, "fund.html")
            r_fn = run_json(["--seed", "19", "test", "multivariate", "fundamentalness",
                             "--model", sv_path, "--max-lag", "4", "--moments", "skew,kurt",
                             "--n-boot", "19", "--save-result", fn_res, "--plot-save", fn_plt])
            assert_envelope_ok(r_fn; label="test multivariate fundamentalness --model SVARMAModel")
            @test haskey(r_fn.doc.data, :fundamentalness_test)
            @test isfile(fn_res) && isfile(fn_plt) && filesize(fn_plt) > 0
            r_fn_rep = run_json(["test", "multivariate", "fundamentalness", "--result", fn_res])
            assert_envelope_ok(r_fn_rep; label="fundamentalness --result replay")

            # Sufficient-information test: (a) <data> + --panel, (b) --model + --factors
            fm_path = joinpath(dir, "factors.jld2")
            r_fm = run_json(["estimate", "factor", "static", panel_csv, "--nfactors", "2", "--save-model", fm_path])
            assert_envelope_ok(r_fm; label="estimate factor static for sufficient-info")

            si_res = joinpath(dir, "si.jld2")
            si_plt = joinpath(dir, "si.html")
            r_si1 = run_json(["test", "multivariate", "sufficient-info", sv_csv,
                              "--lags", "1", "--panel", panel_csv, "--r-max", "3", "--p-f", "2",
                              "--save-result", si_res, "--plot-save", si_plt])
            assert_envelope_ok(r_si1; label="test multivariate sufficient-info --panel")
            @test haskey(r_si1.doc.data, :sufficient_information_test)
            @test isfile(si_res) && isfile(si_plt) && filesize(si_plt) > 0

            r_si2 = run_json(["test", "multivariate", "sufficient-info", "--model", sv_path,
                              "--factors", fm_path, "--r-max", "2", "--p-f", "2"])
            assert_envelope_ok(r_si2; label="test multivariate sufficient-info --model + --factors")
            @test haskey(r_si2.doc.data, :sufficient_information_test)

            r_si_rep = run_json(["test", "multivariate", "sufficient-info", "--result", si_res])
            assert_envelope_ok(r_si_rep; label="sufficient-info --result replay")
        end
    end
end
