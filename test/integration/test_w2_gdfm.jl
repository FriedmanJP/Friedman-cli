# Wave 2 (#314 / MEMs v1.1.1 GDFM expansion) — T3 real-MEMs integration tests.
# Included from test/integration/runtests.jl, and also runnable standalone:
#   julia --project=test/integration test/integration/test_w2_gdfm.jl

using Test
using JSON3
using Friedman
using Random
using Statistics
using LinearAlgebra
using CSV, DataFrames
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
        err = read(err_path, String)
        rm(out_path; force=true)
        rm(err_path; force=true)
        doc = try; JSON3.read(strip(raw)); catch; nothing; end
        if Int(code) != 0
            @info "run_json non-zero exit" args code=Int(code) err=err raw=raw
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
        !isempty(errs) && @info "schema errors for $label" errs
    end

    function table_rows(tbl)
        rows = haskey(tbl, :rows) ? tbl.rows : tbl["rows"]
        return collect(rows)
    end
    function table_cols(tbl)
        cols = haskey(tbl, :columns) ? tbl.columns : tbl["columns"]
        return String[string(c) for c in cols]
    end
end

function _w2_write_panel_csv(path::String, X::AbstractMatrix; ragged::Bool=false)
    T_obs, N = size(X)
    open(path, "w") do io
        println(io, join(["x$j" for j in 1:N], ","))
        for t in 1:T_obs
            row = String[]
            for j in 1:N
                if ragged && ((t == T_obs && j >= N - 2) || (t == T_obs - 1 && j == N))
                    push!(row, "")
                else
                    push!(row, string(Float64(X[t, j])))
                end
            end
            println(io, join(row, ","))
        end
    end
    return path
end

@testset "T3 Wave 2 (#314): Real MEMs v1.1.1 GDFM, FHLZ, I(1)/TV-GDFM, Rank Tests, Band-Pass/Eurocoin, Spectral FEVD & Nowcast GDFM" begin
    mktempdir() do dir
        # Stationary infinite-r GDFM panel (q=2, N=15, T=120)
        d_stat = MacroEconometricModels.dgp_infinite_gdfm(
            Random.Xoshiro(3141); T_obs=120, N=15, q=2, n_permanent=0, signal_share=0.80)
        stat_csv = _w2_write_panel_csv(joinpath(dir, "stat_gdfm.csv"), d_stat.X)
        ragged_csv = _w2_write_panel_csv(joinpath(dir, "ragged_gdfm.csv"), d_stat.X; ragged=true)

        # I(1) cointegrated GDFM panel (q=2, n_permanent=1, N=12, T=120)
        d_i1 = MacroEconometricModels.dgp_infinite_gdfm(
            Random.Xoshiro(3142); T_obs=120, N=12, q=2, n_permanent=1, signal_share=0.80)
        i1_csv = _w2_write_panel_csv(joinpath(dir, "i1_gdfm.csv"), d_i1.X)

        @testset "1. Upgraded estimate/forecast factor gdfm (--allow-missing, --n-lags-proj)" begin
            # Without --allow-missing, ragged CSV must fail with exit 3
            r_rej = run_json(["estimate", "factor", "gdfm", ragged_csv, "--dynamic-rank", "2", "--nfactors", "3"])
            @test r_rej.code == 3

            gdfm_h = joinpath(dir, "gdfm_ragged.jld2")
            r_est = run_json(["estimate", "factor", "gdfm", ragged_csv,
                              "--dynamic-rank", "2", "--nfactors", "3",
                              "--allow-missing", "--em-max-iter", "20", "--em-tol", "1e-3",
                              "--n-lags-proj", "1", "--bandwidth", "5", "--kernel", "parzen",
                              "--save-model", gdfm_h])
            assert_envelope_ok(r_est; label="estimate factor gdfm --allow-missing")
            @test isfile(gdfm_h)

            r_fc = run_json(["forecast", "factor", "gdfm", "--model", gdfm_h,
                             "--method", "one-sided", "--n-lags-proj", "1", "--horizons", "4"])
            assert_envelope_ok(r_fc; label="forecast factor gdfm --n-lags-proj")
            tbl = r_fc.doc.data.gdfm_forecast
            @test length(table_rows(tbl)) == 4 * 15
        end

        @testset "2. Upgraded SDFM with --method fhlz, --var-lags auto, --target max-share" begin
            sdfm_h = joinpath(dir, "sdfm_fhlz.jld2")
            r_est = run_json(["estimate", "factor", "sdfm", stat_csv,
                              "--factors", "2", "--method", "fhlz",
                              "--n-perm", "5", "--p-max", "3", "--var-lags", "auto",
                              "--horizons", "12", "--save-model", sdfm_h])
            assert_envelope_ok(r_est; label="estimate factor sdfm --method fhlz")
            @test isfile(sdfm_h)

            r_irf = run_json(["irf", "sdfm", "--model", sdfm_h, "--horizons", "8"])
            assert_envelope_ok(r_irf; label="irf sdfm --model fhlz")
            r_fevd = run_json(["fevd", "sdfm", "--model", sdfm_h, "--horizons", "8"])
            assert_envelope_ok(r_fevd; label="fevd sdfm --model fhlz")
            r_hd = run_json(["hd", "sdfm", "--model", sdfm_h, "--horizons", "10"])
            assert_envelope_ok(r_hd; label="hd sdfm --model fhlz")
            r_fc = run_json(["forecast", "factor", "sdfm", "--model", sdfm_h, "--horizons", "4"])
            assert_envelope_ok(r_fc; label="forecast factor sdfm --model fhlz")

            # --id max-share with --target
            r_ms = run_json(["estimate", "factor", "sdfm", stat_csv,
                             "--factors", "2", "--method", "fhlz",
                             "--n-perm", "4", "--p-max", "2",
                             "--id", "max-share", "--target", "x1", "--horizons", "10"])
            assert_envelope_ok(r_ms; label="estimate factor sdfm --id max-share --target")
        end

        @testset "3. FHLZ estimate / predict / residuals + --plot-save" begin
            fhlz_h = joinpath(dir, "fhlz.jld2")
            fhlz_p = joinpath(dir, "fhlz.html")
            r = run_json(["estimate", "factor", "fhlz", stat_csv,
                          "--dynamic-rank", "2", "--n-perm", "5", "--p-max", "3",
                          "--irf-horizon", "10", "--seed", "42",
                          "--save-model", fhlz_h, "--plot-save", fhlz_p])
            assert_envelope_ok(r; label="estimate factor fhlz")
            @test haskey(r.doc.data, :fhlz_impulse_filters)
            @test table_cols(r.doc.data.fhlz_impulse_filters) == ["horizon", "variable", "shock", "value", "var_explained"]
            @test isfile(fhlz_h) && isfile(fhlz_p) && filesize(fhlz_p) > 500

            r_pred = run_json(["predict", "factor", "fhlz", "--model", fhlz_h])
            assert_envelope_ok(r_pred; label="predict factor fhlz")
            r_res = run_json(["residuals", "factor", "fhlz", "--model", fhlz_h])
            assert_envelope_ok(r_res; label="residuals factor fhlz")

            r_miss = run_json(["estimate", "factor", "fhlz", ragged_csv,
                               "--dynamic-rank", "2", "--n-perm", "4", "--p-max", "2",
                               "--irf-horizon", "6", "--allow-missing", "--em-max-iter", "10"])
            assert_envelope_ok(r_miss; label="estimate factor fhlz --allow-missing")
        end

        @testset "4. I(1) Cointegrated GDFM full pipeline + --plot-save" begin
            i1_h = joinpath(dir, "gdfm_i1.jld2")
            i1_p = joinpath(dir, "gdfm_i1.html")
            r = run_json(["estimate", "factor", "gdfm-i1", i1_csv,
                          "--dynamic-rank", "2", "--n-permanent", "1",
                          "--id", "permanent-transitory", "--det-trend", "trend",
                          "--n-perm", "5", "--p-max", "2", "--irf-horizon", "12",
                          "--seed", "42", "--save-model", i1_h, "--plot-save", i1_p])
            assert_envelope_ok(r; label="estimate factor gdfm-i1")
            @test haskey(r.doc.data, :gdfm_i1_irf)
            @test isfile(i1_h) && isfile(i1_p) && filesize(i1_p) > 500

            assert_envelope_ok(run_json(["predict", "factor", "gdfm-i1", "--model", i1_h]); label="predict gdfm-i1")
            assert_envelope_ok(run_json(["residuals", "factor", "gdfm-i1", "--model", i1_h]); label="residuals gdfm-i1")

            r_fc = run_json(["forecast", "factor", "gdfm-i1", "--model", i1_h,
                             "--horizons", "6", "--ci", "theoretical"])
            assert_envelope_ok(r_fc; label="forecast factor gdfm-i1")
            @test length(table_rows(r_fc.doc.data.gdfm_i1_forecast)) == 6 * 12

            r_irf = run_json(["irf", "gdfm-i1", "--model", i1_h, "--horizons", "10"])
            assert_envelope_ok(r_irf; label="irf gdfm-i1")

            r_fevd = run_json(["fevd", "gdfm-i1", "--model", i1_h, "--horizons", "10", "--include-idiosyncratic"])
            assert_envelope_ok(r_fevd; label="fevd gdfm-i1")
            @test haskey(r_fevd.doc.data, :gdfm_i1_fevd)

            r_hd = run_json(["hd", "gdfm-i1", "--model", i1_h, "--horizons", "12", "--include-idiosyncratic"])
            assert_envelope_ok(r_hd; label="hd gdfm-i1")
            @test any(k -> startswith(string(k), "gdfm_i1_historical_decomposition_"), keys(r_hd.doc.data))
        end

        @testset "5. Time-Varying GDFM estimate / predict / residuals + --plot-save" begin
            tv_h = joinpath(dir, "tv_gdfm.jld2")
            tv_p = joinpath(dir, "tv_gdfm.html")
            r = run_json(["estimate", "factor", "tv-gdfm", stat_csv,
                          "--dynamic-rank", "2", "--n-grid", "10",
                          "--time-kernel", "gaussian", "--lag-kernel", "parzen",
                          "--save-model", tv_h, "--plot-save", tv_p])
            assert_envelope_ok(r; label="estimate factor tv-gdfm")
            @test haskey(r.doc.data, :tv_gdfm_variance_share_path)
            @test table_cols(r.doc.data.tv_gdfm_variance_share_path) == ["time", "factor", "variance_share"]
            @test isfile(tv_h) && isfile(tv_p) && filesize(tv_p) > 500

            assert_envelope_ok(run_json(["predict", "factor", "tv-gdfm", "--model", tv_h]); label="predict tv-gdfm")
            assert_envelope_ok(run_json(["residuals", "factor", "tv-gdfm", "--model", tv_h]); label="residuals tv-gdfm")
        end

        @testset "6. Dynamic & Static Factor Rank Tests + --plot-save + --result replay" begin
            oq_h = joinpath(dir, "oq.jld2"); oq_p = joinpath(dir, "oq.html")
            r_oq = run_json(["test", "factor", "onatski-q", stat_csv,
                             "--k0", "0", "--k1", "4", "--seed", "42",
                             "--save-result", oq_h, "--plot-save", oq_p])
            assert_envelope_ok(r_oq; label="test factor onatski-q fixed")
            @test isfile(oq_h) && isfile(oq_p) && filesize(oq_p) > 500
            assert_envelope_ok(run_json(["test", "factor", "onatski-q", "--result", oq_h]); label="onatski-q replay")

            r_oqs = run_json(["test", "factor", "onatski-q", stat_csv, "--select", "--k-max", "4", "--seed", "42"])
            assert_envelope_ok(r_oqs; label="test factor onatski-q select")

            ah_h = joinpath(dir, "ah.jld2"); ah_p = joinpath(dir, "ah.html")
            r_ah = run_json(["test", "factor", "ahn-horenstein", stat_csv,
                             "--k-max", "5", "--save-result", ah_h, "--plot-save", ah_p])
            assert_envelope_ok(r_ah; label="test factor ahn-horenstein")
            @test table_cols(r_ah.doc.data.ahn_horenstein_test) == ["k", "eigenvalue", "er", "gr", "r_er", "r_gr"]
            @test isfile(ah_h) && isfile(ah_p) && filesize(ah_p) > 500
            assert_envelope_ok(run_json(["test", "factor", "ahn-horenstein", "--result", ah_h]); label="ahn-horenstein replay")

            ed_h = joinpath(dir, "ed.jld2"); ed_p = joinpath(dir, "ed.html")
            r_ed = run_json(["test", "factor", "onatski-ed", stat_csv,
                             "--k-max", "5", "--save-result", ed_h, "--plot-save", ed_p])
            assert_envelope_ok(r_ed; label="test factor onatski-ed")
            @test table_cols(r_ed.doc.data.onatski_ed_test) == ["k", "eigenvalue", "delta", "r_ed", "converged"]
            @test isfile(ed_h) && isfile(ed_p) && filesize(ed_p) > 500
            assert_envelope_ok(run_json(["test", "factor", "onatski-ed", "--result", ed_h]); label="onatski-ed replay")
        end

        @testset "7. Band-Pass GDFM, Eurocoin, Spectral FEVD & Ragged-Edge Nowcast GDFM" begin
            gdfm_h = joinpath(dir, "gdfm_clean.jld2")
            sdfm_h = joinpath(dir, "sdfm_clean.jld2")
            assert_envelope_ok(run_json(["estimate", "factor", "gdfm", stat_csv,
                                         "--dynamic-rank", "2", "--nfactors", "3",
                                         "--save-model", gdfm_h]); label="gdfm for bp/nowcast")
            assert_envelope_ok(run_json(["estimate", "factor", "sdfm", stat_csv,
                                         "--factors", "2", "--method", "fglr",
                                         "--save-model", sdfm_h]); label="sdfm for spectral fevd")

            # filter bandpass-gdfm
            bp_h = joinpath(dir, "bp.jld2"); bp_p = joinpath(dir, "bp.html")
            r_bp = run_json(["filter", "bandpass-gdfm", "--model", gdfm_h,
                             "--pl", "6", "--pu", "32",
                             "--save-result", bp_h, "--plot-save", bp_p])
            assert_envelope_ok(r_bp; label="filter bandpass-gdfm")
            @test table_cols(r_bp.doc.data.bandpass_gdfm) == ["time", "variable", "twosided", "onesided"]
            @test isfile(bp_h) && isfile(bp_p) && filesize(bp_p) > 500
            assert_envelope_ok(run_json(["filter", "bandpass-gdfm", "--result", bp_h]); label="bandpass-gdfm replay")

            # filter eurocoin
            ec_h = joinpath(dir, "ec.jld2"); ec_p = joinpath(dir, "ec.html")
            r_ec = run_json(["filter", "eurocoin", stat_csv, "--target", "x1",
                             "--dynamic-rank", "2", "--nfactors", "3", "--cutoff", "0.5236",
                             "--save-result", ec_h, "--plot-save", ec_p])
            assert_envelope_ok(r_ec; label="filter eurocoin")
            @test table_cols(r_ec.doc.data.eurocoin_indicator) == ["period", "indicator", "target_lowpass", "r2", "cutoff"]
            ec_rows = table_rows(r_ec.doc.data.eurocoin_indicator)
            @test length(ec_rows) == 120
            @test all(r -> isfinite(Float64(r[2])), ec_rows)
            @test isfile(ec_h) && isfile(ec_p) && filesize(ec_p) > 500
            assert_envelope_ok(run_json(["filter", "eurocoin", "--result", ec_h]); label="eurocoin replay")

            # spectral fevd
            sf_h = joinpath(dir, "sf.jld2"); sf_p = joinpath(dir, "sf.html")
            r_sf = run_json(["spectral", "fevd", "--model", sdfm_h,
                             "--pl", "6", "--pu", "32", "--include-idiosyncratic",
                             "--save-result", sf_h, "--plot-save", sf_p])
            assert_envelope_ok(r_sf; label="spectral fevd")
            @test table_cols(r_sf.doc.data.spectral_fevd) == ["variable", "shock", "share", "power_band"]
            sf_rows = table_rows(r_sf.doc.data.spectral_fevd)
            # Shares per variable sum to 1.0
            x1_shares = sum(Float64(r[3]) for r in sf_rows if string(r[1]) == "x1")
            @test isapprox(x1_shares, 1.0; atol=1e-6)
            @test isfile(sf_h) && isfile(sf_p) && filesize(sf_p) > 500
            assert_envelope_ok(run_json(["spectral", "fevd", "--result", sf_h]); label="spectral fevd replay")

            # nowcast gdfm: ragged CSV alone AND ragged CSV + --model
            nc_h = joinpath(dir, "nc.jld2"); nc_p = joinpath(dir, "nc.html")
            r_nc1 = run_json(["nowcast", "gdfm", ragged_csv,
                              "--dynamic-rank", "2", "--nfactors", "3",
                              "--horizons", "0", "--n-lags", "2",
                              "--em-max-iter", "20", "--save-result", nc_h, "--plot-save", nc_p])
            assert_envelope_ok(r_nc1; label="nowcast gdfm ragged CSV")
            @test table_cols(r_nc1.doc.data.nowcast_gdfm) == ["variable", "nowcast", "std_error", "horizon", "observed"]
            nc_rows = table_rows(r_nc1.doc.data.nowcast_gdfm)
            @test length(nc_rows) == 15
            @test all(r -> isfinite(Float64(r[2])) && Float64(r[3]) > 0, nc_rows)
            @test isfile(nc_h) && isfile(nc_p) && filesize(nc_p) > 500
            assert_envelope_ok(run_json(["nowcast", "gdfm", "--result", nc_h]); label="nowcast gdfm replay")

            # Ragged CSV + pre-estimated GDFM handle (allow_data_with_model=true)
            r_nc2 = run_json(["nowcast", "gdfm", ragged_csv, "--model", gdfm_h,
                              "--horizons", "0", "--n-lags", "2"])
            assert_envelope_ok(r_nc2; label="nowcast gdfm ragged CSV + --model")
            nc2_rows = table_rows(r_nc2.doc.data.nowcast_gdfm)
            @test length(nc2_rows) == 15
            @test all(r -> isfinite(Float64(r[2])) && Float64(r[3]) > 0, nc2_rows)
        end
    end
end
