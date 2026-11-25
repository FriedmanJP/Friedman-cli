# Wave 4 (#316) real-MEMs v1.1.1 integration tests:
#   - All 7 `dsge abcd *` leaves (canonical ABCD, FVRSW invertibility, innovations + --as-abcd,
#     shock recoverability, population VAR, 3-way DSGE-vs-SVAR IRF audit, observable search)
#   - Invertible NK DSGE vs non-invertible news-shock DSGE empirical verification
#   - All 7 `dsge var *` leaves (prior, lambda profile + single --lambda, fixed & joint Bayesian
#     estimate, irf, fevd, hd, forecast)
#   - Handle round-trips: --save-model -> --model, --save-result -> --result, model reproduce
#   - policy sufficiency dsge (square + tall singular-R DARE upgrade in MEMs v1.1.1)
#   - --plot-save HTML artifact verification across all 9 new result types + population VAR
#
# Runs both included from `test/integration/runtests.jl` and standalone via:
#   julia --project=test/integration test/integration/test_w4_abcd_dsgevar.jl

using Test
using JSON3
using CSV
using DataFrames
using Random
using Statistics
using LinearAlgebra
using Friedman
import MacroEconometricModels

if !@isdefined(run_json)
    const _W4_ROOT = dirname(dirname(@__DIR__))
    const SCHEMA_PATH = joinpath(_W4_ROOT, "schema", "envelope-v1.json")
    include(joinpath(@__DIR__, "schema_validate.jl"))

    const _W4_DUMP_DIR = get(ENV, "FRDC_T3_DUMP_ENVELOPES", "")
    const _W4_DUMP_N = Ref(0)

    function _w4_dump_envelope(raw::AbstractString, doc)
        (isempty(_W4_DUMP_DIR) || doc === nothing) && return
        doc isa JSON3.Object || return
        isdir(_W4_DUMP_DIR) || mkpath(_W4_DUMP_DIR)
        _W4_DUMP_N[] += 1
        write(joinpath(_W4_DUMP_DIR, string(lpad(_W4_DUMP_N[], 5, '0'), ".json")), string(strip(raw)))
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
        catch
            Cint(1)
        end
        raw = read(out_path, String)
        rm(out_path; force=true)
        rm(err_path; force=true)
        doc = try; JSON3.read(strip(raw)); catch; nothing; end
        _w4_dump_envelope(raw, doc)
        return (code=Int(code), doc=doc, raw=raw)
    end

    function assert_envelope_ok(r; label="")
        if r.code != 0
            @info "non-zero exit for $label" code=r.code err=(r.doc !== nothing && haskey(r.doc, :error) ? r.doc.error : r.raw)
        end
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

    function named_table(doc, name::Symbol)
        doc === nothing && return nothing
        data = try; doc.data; catch; nothing; end
        data === nothing && return nothing
        haskey(data, name) ? data[name] : nothing
    end

    table_cols(tbl) = String[string(c) for c in (haskey(tbl, :columns) ? tbl.columns : tbl["columns"])]
    table_rows(tbl) = collect(haskey(tbl, :rows) ? tbl.rows : tbl["rows"])
    col_index(tbl, name::AbstractString) = findfirst(==(name), table_cols(tbl))
end

@testset "[MEM111-W4] #316 — dsge abcd & dsge var (real MEMs v1.1.1)" begin
    mktempdir() do dir
        # 1. Standard 2-shock New Keynesian DSGE (invertible for observables [:y, :pi])
        nk_jl = joinpath(dir, "nk_inv.jl")
        write(nk_jl, """
        using .MacroEconometricModels
        @dsge begin
            parameters: rho = 0.8, phi = 1.5, kappa = 0.3, rho_m = 0.5
            endogenous: y, pi, r, a
            exogenous: e_a, e_m
            y[t] = y[t+1] - (r[t] - pi[t+1]) + a[t]
            pi[t] = 0.99 * pi[t+1] + kappa * y[t]
            r[t] = phi * pi[t] + rho_m * r[t-1] + e_m[t]
            a[t] = rho * a[t-1] + e_a[t]
        end
        """)

        # 2. Classic non-invertible 1-period news-shock model:
        #    y[t] = a[t] + 0.5 * x[t],  a[t] = 0.7 * a[t-1] + news[t-1] + e_s[t],  news[t] = e_n[t]
        #    Observing y alone (k=1 < m=2) is underdetermined; observing (y, a) with delayed impact
        #    is non-invertible (singular D / unstable transmission zero)!
        news_jl = joinpath(dir, "news_noninv.jl")
        write(news_jl, """
        using .MacroEconometricModels
        @dsge begin
            parameters: rho = 0.7, psi = 0.5
            endogenous: y, a, news
            exogenous: e_n
            news[t] = e_n[t]
            a[t] = rho * a[t-1] + news[t-1]
            y[t] = a[t] + psi * a[t+1]
        end
        """)

        # 3. TOML DSGE model to verify .toml support as well
        ar_toml = joinpath(dir, "ar2.toml")
        write(ar_toml, """
        [model]
        parameters = { rho_y = 0.7, rho_pi = 0.5, gamma = 0.2 }
        endogenous = ["y", "pi"]
        exogenous = ["e_y", "e_pi"]
        linear = true

        [[model.equations]]
        expr = "y[t] = rho_y * y[t-1] + e_y[t]"

        [[model.equations]]
        expr = "pi[t] = rho_pi * pi[t-1] + gamma * y[t] + e_pi[t]"
        """)

        # Generate deterministic simulated data for DSGE-VAR(λ) tests (T=120)
        sim_csv = joinpath(dir, "nk_sim.csv")
        r_sim = run_json(["--seed", "42", "dsge", "simulate", nk_jl, "--periods", "120", "--burn", "50",
                          "-o", sim_csv, "--format", "csv"])
        @test r_sim.code == 0
        @test isfile(sim_csv)
        # Keep only y, pi columns as a clean 2-column dataset as well
        sim_df = CSV.read(sim_csv, DataFrame)
        ypi_csv = joinpath(dir, "nk_ypi.csv")
        CSV.write(ypi_csv, sim_df[:, [:y, :pi]])

        # Also save a solved DSGESolution handle for --model round-trips
        sol_path = joinpath(dir, "nk_sol.jld2")
        r_sol = run_json(["dsge", "solve", nk_jl, "--save-model", sol_path])
        assert_envelope_ok(r_sol; label="dsge solve --save-model")
        @test isfile(sol_path)

        # ── 1. All 7 `dsge abcd *` leaves ─────────────────────
        abcd_path = joinpath(dir, "nk_abcd.jld2")
        @testset "dsge abcd extract (+ TOML + --model + --plot-save)" begin
            p_html = joinpath(dir, "plot_abcd.html")
            r = run_json(["dsge", "abcd", "extract", nk_jl, "--observables", "y,pi",
                          "--reduction", "predetermined", "--save-model", abcd_path,
                          "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge abcd extract")
            tbl = named_table(r.doc, :abcd_system)
            @test tbl !== nothing
            @test "eigen_index" in table_cols(tbl) && "n_states" in table_cols(tbl)
            @test isfile(abcd_path) && isfile(p_html) && filesize(p_html) > 200

            # From saved DSGESolution handle via --model (with --save-model transform allowed)
            abcd2_path = joinpath(dir, "nk_abcd_from_sol.jld2")
            r2 = run_json(["dsge", "abcd", "extract", "--model", sol_path,
                           "--observables", "y,pi", "--reduction", "minimal",
                           "--save-model", abcd2_path])
            assert_envelope_ok(r2; label="dsge abcd extract --model sol.jld2")
            @test isfile(abcd2_path)

            # From TOML DSGE file
            r_toml = run_json(["dsge", "abcd", "extract", ar_toml, "--observables", "y,pi"])
            assert_envelope_ok(r_toml; label="dsge abcd extract toml")
        end

        @testset "dsge abcd invertibility: invertible NK vs non-invertible news shock" begin
            inv_res_path = joinpath(dir, "nk_inv_res.jld2")
            p_html = joinpath(dir, "plot_inv.html")
            r_inv = run_json(["dsge", "abcd", "invertibility", "--model", abcd_path,
                              "--save-result", inv_res_path, "--plot-save", p_html])
            assert_envelope_ok(r_inv; label="dsge abcd invertibility (NK)")
            tbl = named_table(r_inv.doc, :abcd_invertibility)
            @test tbl !== nothing
            ci_inv = col_index(tbl, "invertible")
            @test ci_inv !== nothing
            @test all(r -> r[ci_inv] === true, table_rows(tbl))
            @test isfile(inv_res_path) && isfile(p_html) && filesize(p_html) > 200

            # --result replay
            r_rep = run_json(["dsge", "abcd", "invertibility", "--result", inv_res_path])
            assert_envelope_ok(r_rep; label="dsge abcd invertibility --result replay")
            @test named_table(r_rep.doc, :abcd_invertibility) !== nothing

            # Non-invertible news-shock model observing y only (delayed impact -> singular D / non-invertible)
            r_news = run_json(["dsge", "abcd", "invertibility", news_jl, "--observables", "y"])
            assert_envelope_ok(r_news; label="dsge abcd invertibility (news non-invertible)")
            t_news = named_table(r_news.doc, :abcd_invertibility)
            @test t_news !== nothing
            ci_ni = col_index(t_news, "invertible")
            @test all(row -> row[ci_ni] === false, table_rows(t_news))
        end

        @testset "dsge abcd innovations (+ --as-abcd + --plot-save)" begin
            innov_path = joinpath(dir, "nk_innov.jld2")
            p_html = joinpath(dir, "plot_innov.html")
            r = run_json(["dsge", "abcd", "innovations", "--model", abcd_path,
                          "--save-model", innov_path, "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge abcd innovations")
            tbl = named_table(r.doc, :abcd_innovations)
            @test tbl !== nothing && "K_gain" in table_cols(tbl)
            @test isfile(innov_path) && isfile(p_html) && filesize(p_html) > 200

            # --as-abcd returns canonical ABCDSystem
            wold_abcd_path = joinpath(dir, "nk_wold_abcd.jld2")
            r2 = run_json(["dsge", "abcd", "innovations", "--model", abcd_path,
                           "--as-abcd", "--save-model", wold_abcd_path])
            assert_envelope_ok(r2; label="dsge abcd innovations --as-abcd")
            tbl2 = named_table(r2.doc, :abcd_innovations)
            @test tbl2 !== nothing && "eigen_index" in table_cols(tbl2)
            @test MacroEconometricModels.load_model(wold_abcd_path) isa MacroEconometricModels.ABCDSystem
        end

        @testset "dsge abcd recoverability: invertible R^2(0)=1 vs news R^2(0)<R^2(k)" begin
            rec_path = joinpath(dir, "nk_rec.jld2")
            p_html = joinpath(dir, "plot_rec.html")
            r_inv = run_json(["dsge", "abcd", "recoverability", "--model", abcd_path,
                              "--max-lead", "6", "--save-result", rec_path, "--plot-save", p_html])
            assert_envelope_ok(r_inv; label="dsge abcd recoverability (NK)")
            tbl = named_table(r_inv.doc, :abcd_recoverability)
            @test tbl !== nothing && table_cols(tbl) == ["lead", "shock", "r2"]
            # Invertible model: contemporaneous R^2(0) ≈ 1
            r2_lead0 = [Float64(row[3]) for row in table_rows(tbl) if Int(row[1]) == 0]
            @test all(v -> v > 0.99, r2_lead0)
            @test isfile(rec_path) && isfile(p_html) && filesize(p_html) > 200

            # --result replay
            r_rep = run_json(["dsge", "abcd", "recoverability", "--result", rec_path])
            assert_envelope_ok(r_rep; label="dsge abcd recoverability --result replay")

            # News-shock model: contemporaneous R^2(0) < 1, strictly increases with leads!
            r_news = run_json(["dsge", "abcd", "recoverability", news_jl,
                               "--observables", "y", "--max-lead", "6"])
            assert_envelope_ok(r_news; label="dsge abcd recoverability (news)")
            tn = named_table(r_news.doc, :abcd_recoverability)
            @test tn !== nothing
            rows_n = table_rows(tn)
            r0 = only([Float64(row[3]) for row in rows_n if Int(row[1]) == 0])
            r6 = only([Float64(row[3]) for row in rows_n if Int(row[1]) == 6])
            @test r0 < 0.99
            @test r6 > r0
        end

        @testset "dsge abcd population-var (+ --save-model + --plot-save)" begin
            pvar_path = joinpath(dir, "nk_pvar.jld2")
            p_html = joinpath(dir, "plot_pvar.html")
            r = run_json(["dsge", "abcd", "population-var", "--model", abcd_path,
                          "--lags", "2", "--n-obs-effective", "500",
                          "--save-model", pvar_path, "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge abcd population-var")
            tbl = named_table(r.doc, :population_var)
            @test tbl !== nothing && "equation" in table_cols(tbl) && "estimate" in table_cols(tbl)
            @test isfile(pvar_path) && isfile(p_html) && filesize(p_html) > 200
            @test MacroEconometricModels.load_model(pvar_path) isa MacroEconometricModels.VARModel
        end

        @testset "dsge abcd audit-irf (best-rotation, cholesky, sign + --plot-save)" begin
            audit_path = joinpath(dir, "nk_audit.jld2")
            p_html = joinpath(dir, "plot_audit.html")
            r = run_json(["dsge", "abcd", "audit-irf", "--model", abcd_path,
                          "--lags", "2", "--horizons", "10", "--id", "best-rotation",
                          "--save-result", audit_path, "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge abcd audit-irf best-rotation")
            t_irf = named_table(r.doc, :dsge_var_irf_audit)
            t_wdg = named_table(r.doc, :dsge_var_irf_wedges)
            @test t_irf !== nothing && "dsge_irf" in table_cols(t_irf) && "svar_irf" in table_cols(t_irf)
            @test t_wdg !== nothing && "noninv_wedge" in table_cols(t_wdg) && "trunc_wedge" in table_cols(t_wdg)
            @test isfile(audit_path) && isfile(p_html) && filesize(p_html) > 200

            # Cholesky
            r_chol = run_json(["dsge", "abcd", "audit-irf", "--model", abcd_path,
                               "--lags", "2", "--horizons", "8", "--id", "cholesky"])
            assert_envelope_ok(r_chol; label="dsge abcd audit-irf cholesky")

            # Sign with --config
            sign_cfg = joinpath(dir, "sign.toml")
            write(sign_cfg, """
            [[identification.sign_restrictions]]
            var = 1
            shock = 1
            sign = "positive"
            horizon = 0
            """)
            r_sign = run_json(["--seed", "7", "dsge", "abcd", "audit-irf", "--model", abcd_path,
                               "--lags", "2", "--horizons", "8", "--id", "sign",
                               "--config", sign_cfg])
            assert_envelope_ok(r_sign; label="dsge abcd audit-irf sign")

            # --result replay
            r_rep = run_json(["dsge", "abcd", "audit-irf", "--result", audit_path])
            assert_envelope_ok(r_rep; label="dsge abcd audit-irf --result replay")
            @test named_table(r_rep.doc, :dsge_var_irf_audit) !== nothing
            @test named_table(r_rep.doc, :dsge_var_irf_wedges) !== nothing
        end

        @testset "dsge abcd search-observables (+ --plot-save)" begin
            srch_path = joinpath(dir, "nk_search.jld2")
            p_html = joinpath(dir, "plot_search.html")
            r = run_json(["dsge", "abcd", "search-observables", nk_jl,
                          "--k", "2", "--candidates", "y,pi,r,a",
                          "--must-include", "y", "--target-shocks", "e_a,e_m",
                          "--save-result", srch_path, "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge abcd search-observables")
            tbl = named_table(r.doc, :abcd_observable_search)
            @test tbl !== nothing && "observables" in table_cols(tbl) && "min_R2" in table_cols(tbl)
            @test length(table_rows(tbl)) == 3  # {y,pi}, {y,r}, {y,a}
            @test isfile(srch_path) && isfile(p_html) && filesize(p_html) > 200

            r_rep = run_json(["dsge", "abcd", "search-observables", "--result", srch_path])
            assert_envelope_ok(r_rep; label="dsge abcd search-observables --result replay")
        end

        # ── 2. All 7 `dsge var *` leaves ──────────────────────
        @testset "dsge var prior (+ --save-model + --plot-save)" begin
            prior_path = joinpath(dir, "nk_prior.jld2")
            p_html = joinpath(dir, "plot_prior.html")
            r = run_json(["dsge", "var", "prior", "--model", abcd_path,
                          "--lags", "2", "--lambda", "1.5", "--t-obs", "100",
                          "--save-model", prior_path, "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge var prior")
            tbl = named_table(r.doc, :dsge_var_prior)
            @test tbl !== nothing && "phi_star" in table_cols(tbl) && "lambda" in table_cols(tbl)
            @test isfile(prior_path) && isfile(p_html) && filesize(p_html) > 200
            @test MacroEconometricModels.load_model(prior_path) isa MacroEconometricModels.DSGEVARPrior
        end

        @testset "dsge var lambda (grid profile + single --lambda + allow_data_with_model + --plot-save)" begin
            prof_path = joinpath(dir, "nk_lambda.jld2")
            p_html = joinpath(dir, "plot_lambda.html")
            r = run_json(["dsge", "var", "lambda", "--model", abcd_path,
                          "--data", ypi_csv, "--lags", "2",
                          "--lambda-grid", "0.5,1.0,2.0,5.0,10.0",
                          "--save-result", prof_path, "--plot-save", p_html])
            assert_envelope_ok(r; label="dsge var lambda grid")
            tbl = named_table(r.doc, :dsge_var_lambda_profile)
            @test tbl !== nothing && "log_marginal_likelihood" in table_cols(tbl) && "lambda_hat" in table_cols(tbl)
            @test length(table_rows(tbl)) == 5
            @test isfile(prof_path) && isfile(p_html) && filesize(p_html) > 200

            # Single --lambda via dsge_var_logml + column auto-slicing from full 4-var sim_csv
            r_one = run_json(["dsge", "var", "lambda", nk_jl, "--data", sim_csv,
                              "--observables", "y,pi", "--lags", "2", "--lambda", "1.5"])
            assert_envelope_ok(r_one; label="dsge var lambda single --lambda")
            t1 = named_table(r_one.doc, :dsge_var_lambda_profile)
            @test t1 !== nothing && length(table_rows(t1)) == 1

            # --result replay
            r_rep = run_json(["dsge", "var", "lambda", "--result", prof_path])
            assert_envelope_ok(r_rep; label="dsge var lambda --result replay")
        end

        post_path = joinpath(dir, "nk_dsgevar_post.jld2")
        @testset "dsge var estimate (fixed-parameter & full Bayesian ModelSpec RWMH/SMC + --plot-save)" begin
            p_html = joinpath(dir, "plot_post.html")
            # Fixed-parameter route from --model abcd.jld2 + --data ypi.csv + --seed for reproduce
            r_fix = run_json(["--seed", "42", "dsge", "var", "estimate",
                              "--model", abcd_path, "--data", ypi_csv,
                              "--lags", "2", "--lambda", "1.5", "--draws", "40",
                              "--save-model", post_path, "--plot-save", p_html])
            assert_envelope_ok(r_fix; label="dsge var estimate fixed")
            tbl = named_table(r_fix.doc, :dsge_var_posterior)
            @test tbl !== nothing && "parameter" in table_cols(tbl) && "mean" in table_cols(tbl)
            @test isfile(post_path) && isfile(p_html) && filesize(p_html) > 200
            @test MacroEconometricModels.load_model(post_path) isa MacroEconometricModels.DSGEVARPosterior

            # Full Bayesian ModelSpec route (RWMH with repeatable --prior)
            r_rwmh = run_json(["--seed", "11", "dsge", "var", "estimate", nk_jl,
                               "--data", ypi_csv, "--observables", "y,pi",
                               "--lags", "2", "--lambda", "1.5",
                               "--prior", "rho ~ beta(8, 2)",
                               "--method", "rwmh", "--draws", "12", "--burnin", "6"])
            assert_envelope_ok(r_rwmh; label="dsge var estimate joint rwmh")
            t_rwmh = named_table(r_rwmh.doc, :dsge_var_posterior)
            @test t_rwmh !== nothing
            @test length(table_rows(t_rwmh)) == 1
            @test string(table_rows(t_rwmh)[1][1]) == "rho"

            # Full Bayesian ModelSpec route (SMC with --priors TOML)
            pri_toml = joinpath(dir, "priors.toml")
            write(pri_toml, """
            [priors.rho]
            dist = "beta"
            a = 8.0
            b = 2.0
            """)
            r_smc = run_json(["--seed", "12", "dsge", "var", "estimate", nk_jl,
                              "--data", ypi_csv, "--observables", "y,pi",
                              "--lags", "2", "--lambda", "1.5",
                              "--priors", pri_toml, "--method", "smc",
                              "--n-particles", "12", "--draws", "12"])
            assert_envelope_ok(r_smc; label="dsge var estimate joint smc")
        end

        @testset "model reproduce on saved DSGEVARPosterior.jld2" begin
            r_rep = run_json(["model", "reproduce", post_path])
            assert_envelope_ok(r_rep; label="model reproduce DSGEVARPosterior")
            tsum = named_table(r_rep.doc, :model_reproduce_summary)
            tfld = named_table(r_rep.doc, :model_reproduce_fields)
            @test tsum !== nothing && tfld !== nothing
            kv = Dict(string(row[1]) => string(row[2]) for row in table_rows(tsum))
            @test kv["model_type"] == "DSGEVARPosterior"
            @test kv["matched"] == "true"
            @test parse(Float64, kv["max_abs_diff"]) == 0.0
        end

        @testset "dsge var irf|fevd|hd|forecast round-trip from --model DSGEVARPosterior.jld2 (+ inline + --plot-save)" begin
            # IRF from saved posterior (--id dsge-qr & cholesky + --save-result + --plot-save)
            irf_res_path = joinpath(dir, "dv_irf.jld2")
            p_irf = joinpath(dir, "plot_dv_irf.html")
            r_irf = run_json(["dsge", "var", "irf", "--model", post_path,
                              "--id", "dsge-qr", "--horizons", "8",
                              "--quantiles", "0.16,0.5,0.84", "--point-estimate", "median",
                              "--save-result", irf_res_path, "--plot-save", p_irf])
            assert_envelope_ok(r_irf; label="dsge var irf --model")
            t_irf = named_table(r_irf.doc, :dsge_var_irf)
            @test t_irf !== nothing && "horizon" in table_cols(t_irf) && "value" in table_cols(t_irf)
            @test isfile(irf_res_path) && isfile(p_irf) && filesize(p_irf) > 200

            r_irf_ch = run_json(["dsge", "var", "irf", "--model", post_path,
                                 "--id", "cholesky", "--horizons", "6", "--shock", "1"])
            assert_envelope_ok(r_irf_ch; label="dsge var irf cholesky --shock 1")

            r_irf_rep = run_json(["dsge", "var", "irf", "--result", irf_res_path])
            assert_envelope_ok(r_irf_rep; label="dsge var irf --result replay")

            # FEVD from saved posterior
            fevd_res_path = joinpath(dir, "dv_fevd.jld2")
            p_fevd = joinpath(dir, "plot_dv_fevd.html")
            r_fevd = run_json(["dsge", "var", "fevd", "--model", post_path,
                               "--id", "dsge-qr", "--horizons", "8",
                               "--save-result", fevd_res_path, "--plot-save", p_fevd])
            assert_envelope_ok(r_fevd; label="dsge var fevd --model")
            @test named_table(r_fevd.doc, :dsge_var_fevd_y) !== nothing
            @test named_table(r_fevd.doc, :dsge_var_fevd_pi) !== nothing
            @test isfile(fevd_res_path) && isfile(p_fevd) && filesize(p_fevd) > 200

            r_fevd_rep = run_json(["dsge", "var", "fevd", "--result", fevd_res_path])
            assert_envelope_ok(r_fevd_rep; label="dsge var fevd --result replay")

            # HD from saved posterior
            hd_res_path = joinpath(dir, "dv_hd.jld2")
            p_hd = joinpath(dir, "plot_dv_hd.html")
            r_hd = run_json(["--seed", "42", "dsge", "var", "hd", "--model", post_path,
                             "--id", "dsge-qr",
                             "--save-result", hd_res_path, "--plot-save", p_hd])
            assert_envelope_ok(r_hd; label="dsge var hd --model")
            @test named_table(r_hd.doc, :dsge_var_hd_y) !== nothing
            @test named_table(r_hd.doc, :dsge_var_hd_pi) !== nothing
            @test isfile(hd_res_path) && isfile(p_hd) && filesize(p_hd) > 200

            r_hd_rep = run_json(["dsge", "var", "hd", "--result", hd_res_path])
            assert_envelope_ok(r_hd_rep; label="dsge var hd --result replay")

            # Forecast from saved posterior
            fc_res_path = joinpath(dir, "dv_fc.jld2")
            p_fc = joinpath(dir, "plot_dv_fc.html")
            r_fc = run_json(["--seed", "42", "dsge", "var", "forecast", "--model", post_path,
                             "--horizons", "6", "--quantiles", "0.16,0.5,0.84",
                             "--point-estimate", "mean",
                             "--save-result", fc_res_path, "--plot-save", p_fc])
            assert_envelope_ok(r_fc; label="dsge var forecast --model")
            t_fc = named_table(r_fc.doc, :dsge_var_forecast)
            @test t_fc !== nothing && "horizon" in table_cols(t_fc) && "value" in table_cols(t_fc)
            @test isfile(fc_res_path) && isfile(p_fc) && filesize(p_fc) > 200

            r_fc_rep = run_json(["dsge", "var", "forecast", "--result", fc_res_path])
            assert_envelope_ok(r_fc_rep; label="dsge var forecast --result replay")

            # Inline estimation path: dsge var irf <model.jl> --data <csv>
            r_inline = run_json(["--seed", "99", "dsge", "var", "irf", nk_jl,
                                 "--data", ypi_csv, "--observables", "y,pi",
                                 "--lags", "2", "--lambda", "1.5", "--draws", "20",
                                 "--horizons", "6"])
            assert_envelope_ok(r_inline; label="dsge var irf inline")
        end

        # ── 3. Policy sufficiency DSGE on MEMs v1.1.1 DARE ────
        @testset "policy sufficiency dsge (square & tall singular-R DARE)" begin
            r_sq = run_json(["policy", "sufficiency", "dsge", nk_jl,
                             "--observables", "y,pi", "--horizons", "10"])
            assert_envelope_ok(r_sq; label="policy sufficiency dsge square")
            t_sq = named_table(r_sq.doc, :forecast_sufficiency_fev_ratios)
            @test t_sq !== nothing && length(table_rows(t_sq)) == 20

            # Tall system: 3 observables (y, pi, r) with only 2 shocks (singular R!)
            r_tall = run_json(["policy", "sufficiency", "dsge", sol_path,
                               "--observables", "y,pi,r", "--horizons", "10"])
            assert_envelope_ok(r_tall; label="policy sufficiency dsge tall singular-R")
            t_tall = named_table(r_tall.doc, :forecast_sufficiency_fev_ratios)
            @test t_tall !== nothing && length(table_rows(t_tall)) == 30
        end
    end
end
