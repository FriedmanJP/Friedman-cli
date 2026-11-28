#!/usr/bin/env julia
# Multi-thread solver conflict matrix & 1T == 4T determinism gate ([PERF-W5] #359).
#
# Run under JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1:
#   JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 julia --project=test/integration test/integration/test_multithread_conflicts.jl

using Test
using JSON3
using LinearAlgebra
using Logging
using Random
using MacroEconometricModels
using Friedman

function _run_cli_json(args::Vector{String})
    out_p, out_io = mktemp()
    err_p, err_io = mktemp()
    rc = Cint(1)
    try
        rc = redirect_stdout(out_io) do
            redirect_stderr(err_io) do
                Friedman.run_cli(vcat(["--quiet", "-J"], args))
            end
        end
        flush(out_io); flush(err_io)
        close(out_io); close(err_io)
        so = read(out_p, String)
        se = read(err_p, String)
        return (code=Int(rc), stdout=so, stderr=se, json=(isempty(strip(so)) ? nothing : JSON3.read(so)))
    finally
        try; close(out_io); catch; end
        try; close(err_io); catch; end
        try; rm(out_p; force=true); catch; end
        try; rm(err_p; force=true); catch; end
    end
end

@testset "Multi-Thread Solver Conflict Matrix & 1T == NT Parity (#358, #359)" begin
    @test Threads.nthreads() >= 2
    if isdefined(MacroEconometricModels, :FFTW) && isdefined(MacroEconometricModels.FFTW, :get_num_threads)
        @test MacroEconometricModels.FFTW.get_num_threads() == 1
    end

    @testset "1. _MemsCliLogger & _LOG_LOCK concurrent @warn stress" begin
        env = Friedman.Envelope(command="mt-stress")
        Friedman._ENVELOPE[] = env
        io = IOBuffer()
        try
            with_logger(Friedman._mems_logger(io)) do
                Threads.@threads for k in 1:80
                    @warn "mt-conflict-warn-$k"
                end
            end
            @test length(env.warnings) == 80
            seen = Set(w["message"] for w in env.warnings)
            @test length(seen) == 80
            for k in 1:80
                @test ("mt-conflict-warn-$k") in seen
            end
        finally
            Friedman._ENVELOPE[] = nothing
        end
    end

    @testset "2. Per-leaf thread_mode BLAS/FFTW coordination & restore" begin
        BLAS.set_num_threads(1)
        @test BLAS.get_num_threads() == 1
        r_io = _run_cli_json(["io", "leontief"])
        @test r_io.code == 0
        @test r_io.json.status == "ok"
        @test r_io.json.meta.manifest.n_threads == Threads.nthreads()
        @test r_io.json.meta.manifest.blas_threads == Friedman._auto_thread_count()
        @test BLAS.get_num_threads() == 1  # cleanly restored after :blas_threads leaf!
    end

    mktempdir() do tmpdir
        # Deterministic 3-variable VAR(1) fixture for BVAR/SVAR/NLopt tests
        mv_csv = joinpath(tmpdir, "mv3.csv")
        open(mv_csv, "w") do f
            println(f, "y1,y2,y3")
            rng = Random.MersenneTwister(42)
            y1 = 0.0; y2 = 0.0; y3 = 0.0
            for _ in 1:100
                ny1 = 0.55 * y1 + 0.10 * y2 - 0.05 * y3 + 0.4 * randn(rng)
                ny2 = 0.15 * y1 + 0.50 * y2 + 0.08 * y3 + 0.4 * randn(rng)
                ny3 = -0.05 * y1 + 0.12 * y2 + 0.45 * y3 + 0.4 * randn(rng)
                y1, y2, y3 = ny1, ny2, ny3
                println(f, "$y1,$y2,$y3")
            end
        end

        rbc_toml = joinpath(tmpdir, "rbc.toml")
        write(rbc_toml, """
[model]
endogenous = ["y", "pi"]
exogenous = ["e_a"]
linear = true
[model.parameters]
rho = 0.85
sigma = 0.02
kappa = 0.25
[[model.equations]]
expr = "y[t] = rho * y[t-1] + sigma * e_a[t]"
[[model.equations]]
expr = "pi[t] = 0.99 * pi[t+1] + kappa * y[t]"
""")

        dsge_csv = joinpath(tmpdir, "dsge_obs.csv")
        open(dsge_csv, "w") do f
            println(f, "y,pi")
            rng = Random.MersenneTwister(42)
            yv = 0.0
            for _ in 1:60
                yv = 0.85 * yv + 0.02 * randn(rng)
                pv = 0.25 * yv + 0.005 * randn(rng)
                println(f, "$yv,$pv")
            end
        end

        sign_json = """{"identification":{"sign_matrix":{"matrix":[[1,1,1],[-1,1,1],[1,-1,1]],"horizons":[0]}}}"""
        rb_json = """{"identification":{"sign_restrictions":[{"var":1,"shock":1,"horizon":0,"sign":"positive"},{"var":2,"shock":1,"horizon":0,"sign":"positive"}]}}"""

        @testset "3. MadNLP constrained DSGE (:serial_safe)" begin
            r = _run_cli_json(["dsge", "steady-state", rbc_toml,
                               "--constraint", "y[t] >= -10.0",
                               "--constraint-solver", "madnlp"])
            @test r.code == 0
            @test r.json.status == "ok"
            @test r.json.meta.manifest.blas_threads == 1
        end

        @testset "4. SuiteSparse / UMFPACK (hadsge solve huggett, filter hp)" begin
            r1 = _run_cli_json(["hadsge", "solve", "huggett"])
            @test r1.code == 0
            @test r1.json.status == "ok"
            @test r1.json.meta.manifest.blas_threads == 1

            r2 = _run_cli_json(["filter", "hp", ":denmark"])
            @test r2.code == 0
            @test r2.json.status == "ok"
            @test r2.json.meta.manifest.blas_threads == 1
        end

        @testset "5. FFTW (spectral density, estimate factor gdfm)" begin
            r1 = _run_cli_json(["spectral", "density", ":denmark"])
            @test r1.code == 0
            @test r1.json.status == "ok"
            @test r1.json.meta.manifest.blas_threads == 1

            r2 = _run_cli_json(["estimate", "factor", "gdfm", ":denmark", "--nfactors", "1", "--dynamic-rank", "1"])
            @test r2.code == 0
            @test r2.json.status == "ok"
            @test r2.json.meta.manifest.blas_threads == 1
            if isdefined(MacroEconometricModels, :FFTW) && isdefined(MacroEconometricModels.FFTW, :get_num_threads)
                @test MacroEconometricModels.FFTW.get_num_threads() == 1
            end
        end

        @testset "6. NLopt (irf bvar --id robust-bayes, dsge bayes posterior-mode)" begin
            bvar_m = joinpath(tmpdir, "bvar_nlopt.jld2")
            r_est = _run_cli_json(["--seed", "42", "estimate", "multivariate", "bvar", mv_csv,
                                   "--lags", "2", "--draws", "80", "--save-model", bvar_m])
            @test r_est.code == 0

            r_rb = _run_cli_json(["--seed", "42", "irf", "bvar", "--model", bvar_m,
                                  "--horizons", "4", "--id", "robust-bayes",
                                  "--config-json", rb_json])
            @test r_rb.code == 0
            @test r_rb.json.status == "ok"

            r_pm = _run_cli_json(["--seed", "42", "dsge", "bayes", "posterior-mode", rbc_toml,
                                  "--data", dsge_csv, "--observables", "y",
                                  "--params", "rho", "--prior", "rho ~ beta(5, 2)"])
            @test r_pm.code == 0
            @test r_pm.json.status == "ok"
            @test r_pm.json.meta.manifest.blas_threads == 1
        end

        @testset "7. Outer @threads workloads (bootstrap, Arias, Uhlig, QFM, GSADF, DSGE SMC)" begin
            r_boot = _run_cli_json(["--seed", "42", "irf", "var", mv_csv, "--lags", "1",
                                    "--horizons", "6", "--ci", "bootstrap", "--draws", "60"])
            @test r_boot.code == 0 && r_boot.json.status == "ok"

            r_arias = _run_cli_json(["--seed", "42", "irf", "var", mv_csv, "--lags", "1",
                                     "--horizons", "6", "--id", "arias",
                                     "--config-json", rb_json, "--draws", "40"])
            @test r_arias.code == 0 && r_arias.json.status == "ok"

            r_uhlig = _run_cli_json(["--seed", "42", "irf", "var", mv_csv, "--lags", "1",
                                     "--horizons", "6", "--id", "uhlig",
                                     "--config-json", rb_json])
            @test r_uhlig.code == 0 && r_uhlig.json.status == "ok"

            qfm_d = joinpath(tmpdir, "qfm.jld2")
            @test _run_cli_json(["--seed", "42", "data", "simulate", "qfm",
                                 "--periods", "60", "--series", "8", "--save-data", qfm_d]).code == 0
            r_qfm = _run_cli_json(["--seed", "42", "estimate", "factor", "qfm", qfm_d,
                                   "--factors", "1", "--tau", "0.5"])
            @test r_qfm.code == 0 && r_qfm.json.status == "ok"

            r_gsadf = _run_cli_json(["--seed", "42", "test", "stability", "gsadf", ":denmark", "--column", "1"])
            @test r_gsadf.code == 0 && r_gsadf.json.status == "ok"

            r_smc = _run_cli_json(["--seed", "42", "dsge", "bayes", "estimate", rbc_toml,
                                   "--data", dsge_csv, "--observables", "y",
                                   "--params", "rho", "--prior", "rho ~ beta(5, 2)",
                                   "--sampler", "smc", "--n-smc", "40"])
            @test r_smc.code == 0 && r_smc.json.status == "ok"
        end

        @testset "8. MEMs v1.1.3 (#945) parallel BVAR irf/fevd/hd 1T == NT bit-exact parity" begin
            bvar_m = joinpath(tmpdir, "bvar_par.jld2")
            r_est = _run_cli_json(["--seed", "42", "estimate", "multivariate", "bvar", mv_csv,
                                   "--lags", "2", "--draws", "120", "--save-model", bvar_m])
            @test r_est.code == 0

            # Compare parallel (threaded=true on NT threads) vs serial (threaded=false via :serial_safe)
            for (label, args) in [
                ("irf bvar sign",  ["--seed", "42", "irf", "bvar", "--model", bvar_m, "--horizons", "8", "--id", "sign", "--config-json", sign_json]),
                ("fevd bvar sign", ["--seed", "42", "fevd", "bvar", "--model", bvar_m, "--horizons", "8", "--id", "sign", "--config-json", sign_json]),
                ("hd bvar sign",   ["--seed", "42", "hd", "bvar", "--model", bvar_m, "--id", "sign", "--config-json", sign_json]),
            ]
                r_par = _run_cli_json(args)
                @test r_par.code == 0
                @test r_par.json.status == "ok"

                # Force serial path using direct MacroEconometricModels comparison through :serial_safe
                post = Friedman.load_model_dispatch(bvar_m)
                cfg = Friedman.write_merged_config_toml(Friedman.merge_config(""; config_json=sign_json))
                cf, nc = Friedman._build_check_func(cfg; nvars=3)
                if startswith(label, "irf")
                    Random.seed!(42)
                    b_ser = MacroEconometricModels.irf(post, 8; method=:sign, check_func=cf, quantiles=[0.16, 0.5, 0.84], threaded=false)
                    Random.seed!(42)
                    b_par = MacroEconometricModels.irf(post, 8; method=:sign, check_func=cf, quantiles=[0.16, 0.5, 0.84], threaded=true)
                    @test b_ser.point_estimate == b_par.point_estimate
                    @test b_ser.quantiles == b_par.quantiles
                elseif startswith(label, "fevd")
                    Random.seed!(42)
                    b_ser = MacroEconometricModels.fevd(post, 8; method=:sign, check_func=cf, quantiles=[0.16, 0.5, 0.84], threaded=false)
                    Random.seed!(42)
                    b_par = MacroEconometricModels.fevd(post, 8; method=:sign, check_func=cf, quantiles=[0.16, 0.5, 0.84], threaded=true)
                    @test b_ser.point_estimate == b_par.point_estimate
                    @test b_ser.quantiles == b_par.quantiles
                else
                    Random.seed!(42)
                    b_ser = MacroEconometricModels.historical_decomposition(post, size(post.data, 1) - post.p; method=:sign, check_func=cf, quantiles=[0.16, 0.5, 0.84], seed=42, threaded=false)
                    Random.seed!(42)
                    b_par = MacroEconometricModels.historical_decomposition(post, size(post.data, 1) - post.p; method=:sign, check_func=cf, quantiles=[0.16, 0.5, 0.84], seed=42, threaded=true)
                    @test b_ser.point_estimate == b_par.point_estimate
                    @test b_ser.quantiles == b_par.quantiles
                end
            end
        end
    end
end
