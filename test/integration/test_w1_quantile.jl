# Wave 1 ([MEM111-W1] #313) T3 real-MEMs integration tests.
# Runnable standalone (`julia --project=test/integration test/integration/test_w1_quantile.jl`)
# or included from `test/integration/runtests.jl`.

using Test
using JSON3
using CSV, DataFrames
using Friedman
using Random
using Statistics
using LinearAlgebra
import MacroEconometricModels

if !@isdefined(run_json)
    const ROOT = dirname(dirname(@__DIR__))
    const SCHEMA_PATH = joinpath(ROOT, "schema", "envelope-v1.json")
    include(joinpath(@__DIR__, "schema_validate.jl"))

    const _W1_DUMP_DIR = get(ENV, "FRDC_T3_DUMP_ENVELOPES", "")
    const _W1_DUMP_N = Ref(0)
    function _w1_dump_envelope(raw::AbstractString, doc)
        (isempty(_W1_DUMP_DIR) || doc === nothing) && return
        doc isa JSON3.Object || return
        isdir(_W1_DUMP_DIR) || mkpath(_W1_DUMP_DIR)
        _W1_DUMP_N[] += 1
        write(joinpath(_W1_DUMP_DIR, string(lpad(_W1_DUMP_N[], 5, '0'), ".json")),
              string(strip(raw)))
    end

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
        catch e
            println(stderr, "run_cli threw for $args: ", e)
            Cint(1)
        end
        raw = read(out_path, String)
        err = read(err_path, String)
        rm(out_path; force=true)
        rm(err_path; force=true)
        doc = try
            JSON3.read(strip(raw))
        catch
            nothing
        end
        if code != 0
            println(stderr, "NONZERO EXIT ($code) for $args:\n  raw=$(first(raw, 400))\n  err=$(first(err, 400))")
        end
        _w1_dump_envelope(raw, doc)
        return (code=Int(code), doc=doc, raw=raw, err=err)
    end

    function assert_envelope_ok(res; label::String="")
        @test res.code == 0
        @test res.doc !== nothing
        res.doc === nothing && return
        @test String(res.doc.status) == "ok"
        errs = validate_envelope_json(res.raw; schema_path=SCHEMA_PATH)
        if !isempty(errs)
            @error "Schema errors for $label" errs
        end
        @test isempty(errs)
    end
end

function _w1_make_factor_panel_csv(dir::String; T::Int=90, N::Int=8, seed::Int=313)
    rng = Random.Xoshiro(seed)
    f1 = zeros(T); f2 = zeros(T)
    for t in 2:T
        f1[t] = 0.6 * f1[t - 1] + randn(rng)
        f2[t] = 0.4 * f2[t - 1] + randn(rng)
    end
    X = Matrix{Float64}(undef, T, N)
    for j in 1:N
        l1 = 0.8 + 0.1 * j
        l2 = iseven(j) ? 0.6 : -0.5
        X[:, j] = l1 .* f1 .+ l2 .* f2 .+ 0.4 .* randn(rng, T)
    end
    df = DataFrame(X, ["x$j" for j in 1:N])
    path = joinpath(dir, "qfm_panel.csv")
    CSV.write(path, df)
    return path
end

function _w1_make_xtqreg_panel_csv(dir::String; N::Int=12, T::Int=20, seed::Int=314)
    rng = Random.Xoshiro(seed)
    f = randn(rng, T)
    lam = randn(rng, N)
    id = Int[]; time = Int[]; y = Float64[]; x1 = Float64[]; x2 = Float64[]
    for i in 1:N, t in 1:T
        w1 = 0.5 * lam[i] * f[t] + randn(rng)
        w2 = randn(rng)
        yi = 1.5 * w1 - 0.8 * w2 + lam[i] * f[t] + 0.4 * randn(rng)
        push!(id, i); push!(time, t); push!(y, yi); push!(x1, w1); push!(x2, w2)
    end
    path = joinpath(dir, "xtqreg_panel.csv")
    CSV.write(path, DataFrame(id=id, time=time, y=y, x1=x1, x2=x2))
    return path
end

function _w1_make_qvar_csv(dir::String; T::Int=120, n::Int=3, seed::Int=315)
    rng = Random.Xoshiro(seed)
    A = [0.5 0.1 0.0; 0.05 0.4 0.1; 0.0 0.05 0.35][1:n, 1:n]
    Y = zeros(T, n)
    for t in 2:T
        Y[t, :] = A * Y[t - 1, :] + randn(rng, n)
    end
    path = joinpath(dir, "qvar.csv")
    CSV.write(path, DataFrame(Y, ["y$i" for i in 1:n]))
    return path
end

@testset "[MEM111-W1] #313 Real MEMs Integration Suite" begin
    mktempdir() do dir
        panel_csv = _w1_make_factor_panel_csv(dir)
        xt_csv = _w1_make_xtqreg_panel_csv(dir)
        qvar_csv = _w1_make_qvar_csv(dir)

        @testset "1. estimate regression qreg --solver ipm|irls" begin
            r_ipm = run_json(["--seed", "42", "estimate", "regression", "qreg", qvar_csv,
                              "--dep", "y1", "--tau", "0.25,0.5,0.75", "--solver", "ipm"])
            assert_envelope_ok(r_ipm; label="qreg --solver ipm")
            r_irls = run_json(["--seed", "42", "estimate", "regression", "qreg", qvar_csv,
                               "--dep", "y1", "--tau", "0.25,0.5,0.75", "--solver", "irls"])
            assert_envelope_ok(r_irls; label="qreg --solver irls")
            @test haskey(r_ipm.doc.data, :quantile_regression_coefficients)
            @test haskey(r_irls.doc.data, :quantile_regression_coefficients)
        end

        @testset "2. QFM estimate (iqr/smoothed, criteria), predict, residuals, forecast, spanning, constancy" begin
            qfm_jld2 = joinpath(dir, "qfm.jld2")
            grid_jld2 = joinpath(dir, "qfm_grid.jld2")
            qfm_plot = joinpath(dir, "qfm.html")
            grid_plot = joinpath(dir, "qfm_grid.html")

            # Auto-rank across criteria (rank, ic1, ic2, ic3) + method=iqr & method=smoothed + plot-save
            for crit in ("rank", "ic1", "ic2", "ic3")
                rc = run_json(["--seed", "42", "estimate", "factor", "qfm", panel_csv,
                               "--tau", "0.5", "--factors", "auto", "--r-max", "3",
                               "--criterion", crit, "--n-starts", "1", "--max-iter", "30"])
                assert_envelope_ok(rc; label="estimate factor qfm --criterion $crit")
                @test haskey(rc.doc.data, :qfm_ic)
                @test haskey(rc.doc.data, :qfm_loadings)
            end

            r_sm = run_json(["--seed", "42", "estimate", "factor", "qfm", panel_csv,
                             "--tau", "0.5", "--factors", "2", "--method", "smoothed",
                             "--kernel", "epanechnikov", "--se", "asymptotic",
                             "--standardize", "--n-starts", "1", "--max-iter", "40",
                             "--save-model", qfm_jld2, "--plot-save", qfm_plot])
            assert_envelope_ok(r_sm; label="estimate factor qfm --method smoothed")
            @test isfile(qfm_jld2) && isfile(qfm_plot) && filesize(qfm_plot) > 100

            r_grid = run_json(["--seed", "42", "estimate", "factor", "qfm", panel_csv,
                               "--taus", "0.1,0.5,0.9", "--factors", "2",
                               "--n-starts", "1", "--max-iter", "30",
                               "--save-model", grid_jld2, "--plot-save", grid_plot])
            assert_envelope_ok(r_grid; label="estimate factor qfm --taus grid")
            @test isfile(grid_jld2) && isfile(grid_plot) && filesize(grid_plot) > 100

            # predict & residuals factor qfm via --model
            r_pred = run_json(["predict", "factor", "qfm", "--model", qfm_jld2])
            assert_envelope_ok(r_pred; label="predict factor qfm --model")
            @test haskey(r_pred.doc.data, :qfm_common_component)

            r_res = run_json(["residuals", "factor", "qfm", "--model", qfm_jld2])
            assert_envelope_ok(r_res; label="residuals factor qfm --model")
            @test haskey(r_res.doc.data, :qfm_residuals)

            # forecast factor qfm (single model + --save-result/--result + --plot-save + grid)
            fc_res = joinpath(dir, "qfm_fc.jld2")
            fc_plot = joinpath(dir, "qfm_fc.html")
            r_fc = run_json(["--seed", "42", "forecast", "factor", "qfm",
                             "--model", qfm_jld2, "--horizons", "4", "--lags", "1",
                             "--save-result", fc_res, "--plot-save", fc_plot])
            assert_envelope_ok(r_fc; label="forecast factor qfm --model")
            @test isfile(fc_res) && isfile(fc_plot) && filesize(fc_plot) > 100

            r_fcr = run_json(["forecast", "factor", "qfm", "--result", fc_res])
            assert_envelope_ok(r_fcr; label="forecast factor qfm --result")

            r_fcg = run_json(["--seed", "42", "forecast", "factor", "qfm",
                              "--model", grid_jld2, "--horizons", "4", "--lags", "1"])
            assert_envelope_ok(r_fcg; label="forecast factor qfm grid")

            # test factor qfm-spanning (--model, --save-result, --result, --plot-save)
            span_res = joinpath(dir, "span.jld2")
            span_plot = joinpath(dir, "span.html")
            r_sp = run_json(["test", "factor", "qfm-spanning", "--model", grid_jld2,
                             "--r-pca", "2", "--threshold", "0.5",
                             "--save-result", span_res, "--plot-save", span_plot])
            assert_envelope_ok(r_sp; label="test factor qfm-spanning")
            @test haskey(r_sp.doc.data, :qfm_spanning_test)
            @test isfile(span_res) && isfile(span_plot) && filesize(span_plot) > 100

            r_spr = run_json(["test", "factor", "qfm-spanning", "--result", span_res])
            assert_envelope_ok(r_spr; label="test factor qfm-spanning --result")

            # test factor qfm-constancy (block & wild, --save-result, --result, --plot-save)
            const_res = joinpath(dir, "const.jld2")
            const_plot = joinpath(dir, "const.html")
            r_ct = run_json(["--seed", "42", "test", "factor", "qfm-constancy",
                             "--model", grid_jld2, "--tau1", "0.1", "--tau2", "0.9",
                             "--n-boot", "6", "--bootstrap", "block", "--max-iter", "15",
                             "--save-result", const_res, "--plot-save", const_plot])
            assert_envelope_ok(r_ct; label="test factor qfm-constancy block")
            @test haskey(r_ct.doc.data, :qfm_constancy_test)
            @test isfile(const_res) && isfile(const_plot) && filesize(const_plot) > 100

            r_ctw = run_json(["--seed", "42", "test", "factor", "qfm-constancy",
                              "--model", grid_jld2, "--tau1", "0.1", "--tau2", "0.9",
                              "--n-boot", "6", "--bootstrap", "wild", "--max-iter", "15"])
            assert_envelope_ok(r_ctw; label="test factor qfm-constancy wild")

            r_ctr = run_json(["test", "factor", "qfm-constancy", "--result", const_res])
            assert_envelope_ok(r_ctr; label="test factor qfm-constancy --result")
        end

        @testset "3. Growth-at-Risk (skewed-t, normal, none, --save-model/--model, --save-result/--result, --plot-save)" begin
            gar_res = joinpath(dir, "gar.jld2")
            gar_mod = joinpath(dir, "gar_grid.jld2")
            gar_plot = joinpath(dir, "gar.html")
            for dens in ("skewed-t", "normal", "none")
                extra = dens == "skewed-t" ?
                    ["--save-model", gar_mod, "--save-result", gar_res, "--plot-save", gar_plot] : String[]
                rg = run_json(vcat(["--seed", "42", "forecast", "factor", "growth-at-risk",
                                    panel_csv, "--target", "x1", "--horizons", "1",
                                    "--factors", "2", "--lags", "1",
                                    "--taus", "0.1,0.25,0.5,0.75,0.9",
                                    "--density", dens], extra))
                assert_envelope_ok(rg; label="growth-at-risk --density $dens")
                @test haskey(rg.doc.data, :growth_at_risk)
            end
            @test isfile(gar_mod) && isfile(gar_res) && isfile(gar_plot) && filesize(gar_plot) > 100

            r_garr = run_json(["forecast", "factor", "growth-at-risk", "--result", gar_res])
            assert_envelope_ok(r_garr; label="growth-at-risk --result")

            r_garm = run_json(["--seed", "42", "forecast", "factor", "growth-at-risk",
                               "--model", gar_mod, "--target", "x1",
                               "--horizons", "1", "--density", "normal"])
            assert_envelope_ok(r_garm; label="growth-at-risk --model")
        end

        @testset "4. Interactive panel quantile regression (xtqreg)" begin
            xt_jld2 = joinpath(dir, "xtqreg.jld2")
            xt_plot = joinpath(dir, "xtqreg.html")
            r_xt = run_json(["--seed", "42", "estimate", "panel", "xtqreg", xt_csv,
                             "--id-col", "id", "--time-col", "time",
                             "--dep", "y", "--indep", "x1,x2",
                             "--factors", "1", "--tau", "0.5", "--max-iter", "30",
                             "--save-model", xt_jld2, "--plot-save", xt_plot])
            assert_envelope_ok(r_xt; label="estimate panel xtqreg")
            @test haskey(r_xt.doc.data, :xtqreg_coefficients)
            @test isfile(xt_jld2) && isfile(xt_plot) && filesize(xt_plot) > 100

            r_xp = run_json(["predict", "panel", "xtqreg", "--model", xt_jld2])
            assert_envelope_ok(r_xp; label="predict panel xtqreg --model")
            @test haskey(r_xp.doc.data, :xtqreg_fitted_values)

            r_xr = run_json(["residuals", "panel", "xtqreg", "--model", xt_jld2])
            assert_envelope_ok(r_xr; label="residuals panel xtqreg --model")
            @test haskey(r_xr.doc.data, :xtqreg_residuals)
        end

        @testset "5. QVAR & QIRF (analytical + simulation, --save-model/--model, --save-result/--result, --plot-save)" begin
            qv_jld2 = joinpath(dir, "qvar.jld2")
            qi_jld2 = joinpath(dir, "qirf.jld2")
            qi_plot = joinpath(dir, "qirf.html")

            r_qv = run_json(["--seed", "42", "estimate", "multivariate", "qvar", qvar_csv,
                             "--lags", "1", "--taus", "0.1,0.5,0.9", "--se", "asymptotic",
                             "--save-model", qv_jld2])
            assert_envelope_ok(r_qv; label="estimate multivariate qvar")
            @test haskey(r_qv.doc.data, :qvar_coefficients)
            @test isfile(qv_jld2)

            r_qr = run_json(["residuals", "multivariate", "qvar", "--model", qv_jld2])
            assert_envelope_ok(r_qr; label="residuals multivariate qvar --model")
            @test haskey(r_qr.doc.data, :qvar_residuals)

            r_qi = run_json(["--seed", "42", "irf", "qvar", "--model", qv_jld2,
                             "--horizons", "6", "--shock", "1", "--tau-profile", "0.1",
                             "--method", "analytical", "--save-result", qi_jld2,
                             "--plot-save", qi_plot])
            assert_envelope_ok(r_qi; label="irf qvar analytical")
            @test haskey(r_qi.doc.data, :qvar_irf)
            @test isfile(qi_jld2) && isfile(qi_plot) && filesize(qi_plot) > 100

            r_qir = run_json(["irf", "qvar", "--result", qi_jld2])
            assert_envelope_ok(r_qir; label="irf qvar --result")

            r_qis = run_json(["--seed", "42", "irf", "qvar", "--model", qv_jld2,
                              "--horizons", "4", "--shock", "1", "--method", "simulation",
                              "--n-boot", "10"])
            assert_envelope_ok(r_qis; label="irf qvar simulation")
        end

        @testset "6. QFAVAR (twostep & vb), irf qfavar, forecast multivariate qfavar" begin
            qf_jld2 = joinpath(dir, "qfavar.jld2")
            vb_jld2 = joinpath(dir, "vbqfavar.jld2")
            qfi_jld2 = joinpath(dir, "qfavar_irf.jld2")
            qfi_plot = joinpath(dir, "qfavar_irf.html")
            qff_jls = joinpath(dir, "qfavar_fc.jls")

            r_qf = run_json(["--seed", "42", "estimate", "multivariate", "qfavar", panel_csv,
                             "--factors", "2", "--lags", "1", "--key-vars", "x1",
                             "--taus", "0.1,0.5,0.9", "--method", "twostep",
                             "--save-model", qf_jld2])
            assert_envelope_ok(r_qf; label="estimate multivariate qfavar twostep")
            @test haskey(r_qf.doc.data, :qfavar_loadings)
            @test isfile(qf_jld2)

            r_vb = run_json(["--seed", "42", "estimate", "multivariate", "qfavar", panel_csv,
                             "--factors", "2", "--lags", "1", "--key-vars", "x1",
                             "--taus", "0.1,0.5,0.9", "--method", "vb",
                             "--vb-maxiter", "15", "--n-draws", "20",
                             "--save-model", vb_jld2])
            assert_envelope_ok(r_vb; label="estimate multivariate qfavar vb")
            @test haskey(r_vb.doc.data, :qfavar_loadings)
            @test isfile(vb_jld2)

            r_qfi_ts = run_json(["--seed", "42", "irf", "qfavar", "--model", qf_jld2,
                                 "--horizons", "4", "--shock", "3", "--ci-type", "none"])
            assert_envelope_ok(r_qfi_ts; label="irf qfavar twostep")

            r_qfi = run_json(["--seed", "42", "irf", "qfavar", "--model", vb_jld2,
                              "--horizons", "5", "--shock", "3", "--ci-type", "credible",
                              "--save-result", qfi_jld2, "--plot-save", qfi_plot])
            assert_envelope_ok(r_qfi; label="irf qfavar vb credible")
            @test haskey(r_qfi.doc.data, :qfavar_irf)
            @test isfile(qfi_jld2) && isfile(qfi_plot) && filesize(qfi_plot) > 100

            r_qfir = run_json(["irf", "qfavar", "--result", qfi_jld2])
            assert_envelope_ok(r_qfir; label="irf qfavar --result")

            r_qff = run_json(["forecast", "multivariate", "qfavar", "--model", qf_jld2,
                              "--horizons", "4", "--save-result", qff_jls])
            assert_envelope_ok(r_qff; label="forecast multivariate qfavar")
            @test haskey(r_qff.doc.data, :qfavar_forecast)
            @test isfile(qff_jls)

            r_qffr = run_json(["forecast", "multivariate", "qfavar", "--result", qff_jls])
            assert_envelope_ok(r_qffr; label="forecast multivariate qfavar --result")
        end

        @testset "7. Table & CSV format smoke checks on real MEMs" begin
            for fmt in ("table", "csv")
                out_path = tempname()
                code = open(out_path, "w") do io
                    redirect_stdout(io) do
                        Friedman.run_cli(["--quiet", "--seed", "42", "estimate", "factor", "qfm",
                                          panel_csv, "--tau", "0.5", "--factors", "2",
                                          "--n-starts", "1", "--max-iter", "20", "--format", fmt])
                    end
                end
                txt = read(out_path, String)
                rm(out_path; force=true)
                @test Int(code) == 0
                @test !isempty(strip(txt))
            end
        end
    end
end
