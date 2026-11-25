# Wave 2 (#314 / MEMs v1.1.1 GDFM expansion) — T2 mock unit tests.
# Included from test/test_commands.jl, and also runnable standalone:
#   julia --project test/test_w2_gdfm.jl

using Test

if !@isdefined(_dispatch_via_app)
    using CSV, DataFrames, JSON3, PrettyTables, TOML
    using Dates
    using LinearAlgebra: eigvals, diag, I, svd, diagm, logdet, det
    using Statistics: mean, median, var, quantile, std
    using Random
    using Serialization

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
    const FRIEDMAN_VERSION = VersionNumber(
        TOML.parsefile(joinpath(project_root, "Project.toml"))["version"])
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
    include(joinpath(project_root, "src", "commands", "w2_gdfm.jl"))
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

function _w2_build_app()
    root_cmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "estimate"  => register_estimate_commands!(),
        "test"      => register_test_commands!(),
        "irf"       => register_irf_commands!(),
        "fevd"      => register_fevd_commands!(),
        "hd"        => register_hd_commands!(),
        "forecast"  => register_forecast_commands!(),
        "predict"   => register_predict_commands!(),
        "residuals" => register_residuals_commands!(),
        "filter"    => register_filter_commands!(),
        "nowcast"   => register_nowcast_commands!(),
        "spectral"  => register_spectral_commands!(),
    )
    return Entry("frdc", NodeCommand("frdc", root_cmds, "w2 test tree"); version=FRIEDMAN_VERSION)
end

const _W2_TEST_APP = Ref{Union{Nothing,Entry}}(nothing)
function _w2_app()
    if _W2_TEST_APP[] === nothing
        _W2_TEST_APP[] = _w2_build_app()
    end
    return _W2_TEST_APP[]::Entry
end

function _w2_run_json(argv::Vector{String})
    out = _capture() do
        dispatch(_w2_app(), vcat(argv, ["--format", "json"]))
    end
    i = findfirst('{', out)
    @test i !== nothing
    return JSON3.read(out[i:end])
end

function _w2_make_ragged_csv(dir::String; T::Int=40, n::Int=6, name::String="ragged.csv")
    path = joinpath(dir, name)
    rng = MersenneTwister(314)
    open(path, "w") do io
        println(io, join(["x$j" for j in 1:n], ","))
        for t in 1:T
            vals = String[]
            for j in 1:n
                if (t == T && j >= n - 1) || (t == T - 1 && j == n)
                    push!(vals, "")
                else
                    push!(vals, string(round(randn(rng); digits=6)))
                end
            end
            println(io, join(vals, ","))
        end
    end
    return path
end

@testset "Wave 2 (#314): GDFM/FHLZ/I(1)/TV-GDFM, Rank Tests, Band-Pass/Eurocoin, Spectral FEVD & Nowcast GDFM" begin

    @testset "Registry paths, families & tidy unions" begin
        app = _w2_app()
        @test haskey(app.root.subcmds["estimate"].subcmds["factor"].subcmds, "fhlz")
        @test haskey(app.root.subcmds["estimate"].subcmds["factor"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["estimate"].subcmds["factor"].subcmds, "tv-gdfm")
        @test haskey(app.root.subcmds["predict"].subcmds["factor"].subcmds, "fhlz")
        @test haskey(app.root.subcmds["predict"].subcmds["factor"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["predict"].subcmds["factor"].subcmds, "tv-gdfm")
        @test haskey(app.root.subcmds["residuals"].subcmds["factor"].subcmds, "fhlz")
        @test haskey(app.root.subcmds["residuals"].subcmds["factor"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["residuals"].subcmds["factor"].subcmds, "tv-gdfm")
        @test haskey(app.root.subcmds["forecast"].subcmds["factor"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["irf"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["fevd"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["hd"].subcmds, "gdfm-i1")
        @test haskey(app.root.subcmds["test"].subcmds["factor"].subcmds, "onatski-q")
        @test haskey(app.root.subcmds["test"].subcmds["factor"].subcmds, "ahn-horenstein")
        @test haskey(app.root.subcmds["test"].subcmds["factor"].subcmds, "onatski-ed")
        @test haskey(app.root.subcmds["filter"].subcmds, "bandpass-gdfm")
        @test haskey(app.root.subcmds["filter"].subcmds, "eurocoin")
        @test haskey(app.root.subcmds["spectral"].subcmds, "fevd")
        @test haskey(app.root.subcmds["nowcast"].subcmds, "gdfm")

        # Disjointness of _TIDY_COEF_TYPES and _TIDY_LONG_TYPES
        for T in (OnatskiQTestResult, AhnHorensteinResult, OnatskiEDResult,
                  EurocoinResult, GDFMNowcastResult)
            @test T <: _TIDY_COEF_TYPES
            @test !(T <: _TIDY_LONG_TYPES)
        end
        for T in (FHLZModel, CointegratedGDFM, TimeVaryingGDFM,
                  BandPassGDFMResult, SpectralFEVDResult)
            @test T <: _TIDY_LONG_TYPES
            @test !(T <: _TIDY_COEF_TYPES)
        end

        # nowcast gdfm allows <data> alongside --model
        ng_specs = filter(s -> s.path == ["nowcast", "gdfm"], REGISTRY)
        @test !isempty(ng_specs) && ng_specs[end].allow_data_with_model
    end

    @testset "Upgraded GDFM & SDFM leaves" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=6)
            rcsv = _w2_make_ragged_csv(dir; T=50, n=6)

            # estimate factor gdfm rejects missing without --allow-missing
            err_miss = try
                _estimate_gdfm(; data=rcsv, dynamic_rank=2, nfactors=2, format="table")
                nothing
            catch e
                e
            end
            @test err_miss isa CliError && err_miss.code == "data/missing-values"

            # estimate factor gdfm succeeds with --allow-missing + new knobs
            gdfm_path = joinpath(dir, "gdfm_ragged.jld2")
            doc = _w2_run_json(["estimate", "factor", "gdfm", rcsv,
                                "--dynamic-rank", "2", "--nfactors", "2",
                                "--allow-missing", "--em-max-iter", "20",
                                "--em-tol", "1e-3", "--n-lags-proj", "1",
                                "--bandwidth", "4", "--kernel", "parzen",
                                "--save-model", gdfm_path])
            @test doc.status == "ok"
            @test isfile(gdfm_path)

            # forecast factor gdfm with --n-lags-proj
            doc_fc = _w2_run_json(["forecast", "factor", "gdfm", csv,
                                   "--dynamic-rank", "2", "--nfactors", "2",
                                   "--method", "one-sided", "--n-lags-proj", "2",
                                   "--horizons", "4"])
            @test doc_fc.status == "ok"
            @test haskey(doc_fc.data, :gdfm_forecast)

            # SDFM with --method fhlz, --n-perm, --p-max, --var-lags auto, --target
            sdfm_path = joinpath(dir, "sdfm_fhlz.jld2")
            doc_s = _w2_run_json(["estimate", "factor", "sdfm", csv,
                                  "--factors", "2", "--method", "fhlz",
                                  "--n-perm", "5", "--p-max", "3",
                                  "--var-lags", "auto", "--id", "max-share",
                                  "--target", "var1", "--save-model", sdfm_path])
            @test doc_s.status == "ok"
            @test isfile(sdfm_path)

            for verb_args in (
                ["irf", "sdfm", csv, "--factors", "2", "--method", "fhlz", "--n-perm", "4", "--p-max", "2", "--var-lags", "auto", "--horizons", "6"],
                ["fevd", "sdfm", csv, "--factors", "2", "--method", "fhlz", "--n-perm", "4", "--p-max", "2", "--var-lags", "auto", "--horizons", "6"],
                ["hd", "sdfm", csv, "--factors", "2", "--method", "fhlz", "--n-perm", "4", "--p-max", "2", "--var-lags", "auto", "--horizons", "6"],
                ["forecast", "factor", "sdfm", csv, "--factors", "2", "--method", "fhlz", "--n-perm", "4", "--p-max", "2", "--var-lags", "auto", "--horizons", "4"],
            )
                d = _w2_run_json(verb_args)
                @test d.status == "ok"
            end

            # Invalid --var-lags rejected as usage/invalid
            e_vl = try; _parse_sdfm_var_lags("bogus", "estimate factor sdfm"); nothing; catch e; e; end
            @test e_vl isa CliError && e_vl.code == "usage/invalid"
        end
    end

    @testset "FHLZ estimate / predict / residuals" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=6)
            rcsv = _w2_make_ragged_csv(dir; T=50, n=6)
            mpath = joinpath(dir, "fhlz.jld2")
            ppath = joinpath(dir, "fhlz.html")

            doc = _w2_run_json(["estimate", "factor", "fhlz", csv,
                                "--dynamic-rank", "2", "--n-perm", "5",
                                "--p-max", "3", "--irf-horizon", "8",
                                "--kernel", "parzen", "--seed", "42",
                                "--save-model", mpath, "--plot-save", ppath])
            @test doc.status == "ok"
            @test haskey(doc.data, :fhlz_impulse_filters)
            @test isfile(mpath) && isfile(ppath)

            # Auto dynamic rank + --allow-missing
            doc_auto = _w2_run_json(["estimate", "factor", "fhlz", rcsv,
                                     "--allow-missing", "--n-perm", "4", "--irf-horizon", "5"])
            @test doc_auto.status == "ok"

            # predict & residuals from data and from --model
            d_p = _w2_run_json(["predict", "factor", "fhlz", "--model", mpath])
            @test d_p.status == "ok" && haskey(d_p.data, :fhlz_common_component)
            d_r = _w2_run_json(["residuals", "factor", "fhlz", "--model", mpath])
            @test d_r.status == "ok" && haskey(d_r.data, :fhlz_idiosyncratic_component)
            d_p2 = _w2_run_json(["predict", "factor", "fhlz", csv, "--dynamic-rank", "2", "--n-perm", "3"])
            @test d_p2.status == "ok"
        end
    end

    @testset "I(1) Cointegrated GDFM estimate / predict / residuals / forecast / irf / fevd / hd" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=6)
            mpath = joinpath(dir, "gdfm_i1.jld2")
            ppath = joinpath(dir, "gdfm_i1.html")
            fc_res = joinpath(dir, "gdfm_i1_fc.jld2")
            irf_res = joinpath(dir, "gdfm_i1_irf.jld2")
            fevd_res = joinpath(dir, "gdfm_i1_fevd.jld2")
            hd_res = joinpath(dir, "gdfm_i1_hd.jld2")

            doc = _w2_run_json(["estimate", "factor", "gdfm-i1", csv,
                                "--dynamic-rank", "2", "--n-permanent", "1",
                                "--id", "permanent-transitory", "--det-trend", "trend",
                                "--n-perm", "5", "--p-max", "3", "--irf-horizon", "10",
                                "--seed", "42", "--save-model", mpath, "--plot-save", ppath])
            @test doc.status == "ok" && haskey(doc.data, :gdfm_i1_irf)
            @test isfile(mpath) && isfile(ppath)

            @test _w2_run_json(["predict", "factor", "gdfm-i1", "--model", mpath]).status == "ok"
            @test _w2_run_json(["residuals", "factor", "gdfm-i1", "--model", mpath]).status == "ok"

            dfc = _w2_run_json(["forecast", "factor", "gdfm-i1", "--model", mpath,
                                "--horizons", "6", "--ci", "theoretical",
                                "--save-result", fc_res])
            @test dfc.status == "ok" && haskey(dfc.data, :gdfm_i1_forecast)
            @test _w2_run_json(["forecast", "factor", "gdfm-i1", "--result", fc_res]).status == "ok"

            dirf = _w2_run_json(["irf", "gdfm-i1", "--model", mpath,
                                 "--horizons", "8", "--save-result", irf_res])
            @test dirf.status == "ok" && haskey(dirf.data, :gdfm_i1_irf)
            @test _w2_run_json(["irf", "gdfm-i1", "--result", irf_res]).status == "ok"

            dfevd = _w2_run_json(["fevd", "gdfm-i1", "--model", mpath,
                                  "--horizons", "8", "--include-idiosyncratic",
                                  "--save-result", fevd_res])
            @test dfevd.status == "ok" && haskey(dfevd.data, :gdfm_i1_fevd)
            @test _w2_run_json(["fevd", "gdfm-i1", "--result", fevd_res]).status == "ok"

            dhd = _w2_run_json(["hd", "gdfm-i1", "--model", mpath,
                                "--horizons", "10", "--include-idiosyncratic",
                                "--save-result", hd_res])
            @test dhd.status == "ok"
            @test any(k -> startswith(string(k), "gdfm_i1_historical_decomposition_"), keys(dhd.data))
            @test _w2_run_json(["hd", "gdfm-i1", "--result", hd_res]).status == "ok"

            # Guard checks: --id proxy without --instrument, --n-permanent > q
            e_px = try
                _estimate_gdfm_i1(; data=csv, dynamic_rank=2, id="proxy", format="table")
                nothing
            catch e; e; end
            @test e_px isa CliError && e_px.code == "usage/missing"

            e_np = try
                _estimate_gdfm_i1(; data=csv, dynamic_rank=2, n_permanent=3, format="table")
                nothing
            catch e; e; end
            @test e_np isa CliError && e_np.code == "usage/invalid"
        end
    end

    @testset "Time-Varying GDFM estimate / predict / residuals" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=6)
            mpath = joinpath(dir, "tv_gdfm.jld2")
            ppath = joinpath(dir, "tv_gdfm.html")

            doc = _w2_run_json(["estimate", "factor", "tv-gdfm", csv,
                                "--dynamic-rank", "2", "--n-grid", "10",
                                "--time-bandwidth", "0.25", "--lag-bandwidth", "4",
                                "--time-kernel", "gaussian", "--lag-kernel", "parzen",
                                "--save-model", mpath, "--plot-save", ppath])
            @test doc.status == "ok" && haskey(doc.data, :tv_gdfm_variance_share_path)
            @test isfile(mpath) && isfile(ppath)

            @test _w2_run_json(["predict", "factor", "tv-gdfm", "--model", mpath]).status == "ok"
            @test _w2_run_json(["residuals", "factor", "tv-gdfm", "--model", mpath]).status == "ok"
        end
    end

    @testset "Factor rank selection tests (onatski-q, ahn-horenstein, onatski-ed)" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=8)
            r_oq = joinpath(dir, "oq.jld2")
            r_ah = joinpath(dir, "ah.jld2")
            r_ed = joinpath(dir, "ed.jld2")
            p_oq = joinpath(dir, "oq.html")
            p_ah = joinpath(dir, "ah.html")
            p_ed = joinpath(dir, "ed.html")

            # onatski-q fixed hypothesis mode
            d1 = _w2_run_json(["test", "factor", "onatski-q", csv,
                               "--k0", "0", "--k1", "4", "--kernel", "tukey-hanning",
                               "--seed", "42", "--save-result", r_oq, "--plot-save", p_oq])
            @test d1.status == "ok" && haskey(d1.data, :onatski_q_test)
            @test isfile(r_oq) && isfile(p_oq)
            @test _w2_run_json(["test", "factor", "onatski-q", "--result", r_oq]).status == "ok"

            # onatski-q sequential selection mode (implicit when --k0 omitted, and explicit --select)
            d1s = _w2_run_json(["test", "factor", "onatski-q", csv, "--select", "--k-max", "4", "--alpha", "0.05"])
            @test d1s.status == "ok" && haskey(d1s.data, :onatski_q_test)

            # ahn-horenstein
            d2 = _w2_run_json(["test", "factor", "ahn-horenstein", csv,
                               "--k-max", "4", "--no-demean",
                               "--save-result", r_ah, "--plot-save", p_ah])
            @test d2.status == "ok" && haskey(d2.data, :ahn_horenstein_test)
            @test isfile(r_ah) && isfile(p_ah)
            @test _w2_run_json(["test", "factor", "ahn-horenstein", "--result", r_ah]).status == "ok"

            # onatski-ed
            d3 = _w2_run_json(["test", "factor", "onatski-ed", csv,
                               "--k-max", "4", "--max-iter", "15",
                               "--save-result", r_ed, "--plot-save", p_ed])
            @test d3.status == "ok" && haskey(d3.data, :onatski_ed_test)
            @test isfile(r_ed) && isfile(p_ed)
            @test _w2_run_json(["test", "factor", "onatski-ed", "--result", r_ed]).status == "ok"
        end
    end

    @testset "Band-pass GDFM, Eurocoin, Spectral FEVD & Nowcast GDFM" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=6)
            rcsv = _w2_make_ragged_csv(dir; T=50, n=6)
            gdfm_m = joinpath(dir, "gdfm.jld2")
            sdfm_m = joinpath(dir, "sdfm.jld2")
            bp_r = joinpath(dir, "bp.jld2")
            ec_r = joinpath(dir, "ec.jld2")
            sf_r = joinpath(dir, "sf.jld2")
            nc_r = joinpath(dir, "nc.jld2")

            _w2_run_json(["estimate", "factor", "gdfm", csv, "--dynamic-rank", "2", "--nfactors", "2", "--save-model", gdfm_m])
            _w2_run_json(["estimate", "factor", "sdfm", csv, "--factors", "2", "--save-model", sdfm_m])

            # filter bandpass-gdfm (data + --model + explicit band + --result replay + plot)
            dbp1 = _w2_run_json(["filter", "bandpass-gdfm", csv, "--dynamic-rank", "2", "--nfactors", "2",
                                 "--pl", "6", "--pu", "32", "--save-result", bp_r,
                                 "--plot-save", joinpath(dir, "bp.html")])
            @test dbp1.status == "ok" && haskey(dbp1.data, :bandpass_gdfm)
            @test isfile(bp_r) && isfile(joinpath(dir, "bp.html"))
            dbp2 = _w2_run_json(["filter", "bandpass-gdfm", "--model", gdfm_m,
                                 "--band-low", "0.2", "--band-high", "1.0"])
            @test dbp2.status == "ok"
            @test _w2_run_json(["filter", "bandpass-gdfm", "--result", bp_r]).status == "ok"

            # filter eurocoin
            dec = _w2_run_json(["filter", "eurocoin", csv, "--target", "var1",
                                "--dynamic-rank", "2", "--nfactors", "2", "--cutoff", "0.52",
                                "--save-result", ec_r, "--plot-save", joinpath(dir, "ec.html")])
            @test dec.status == "ok" && haskey(dec.data, :eurocoin_indicator)
            @test isfile(ec_r) && isfile(joinpath(dir, "ec.html"))
            @test _w2_run_json(["filter", "eurocoin", "--result", ec_r]).status == "ok"

            # spectral fevd (data + --model + --include-idiosyncratic + --result replay + plot)
            dsf1 = _w2_run_json(["spectral", "fevd", csv, "--factors", "2", "--method", "fhlz",
                                 "--n-perm", "4", "--pl", "6", "--pu", "32",
                                 "--include-idiosyncratic", "--save-result", sf_r,
                                 "--plot-save", joinpath(dir, "sf.html")])
            @test dsf1.status == "ok" && haskey(dsf1.data, :spectral_fevd)
            @test isfile(sf_r) && isfile(joinpath(dir, "sf.html"))
            dsf2 = _w2_run_json(["spectral", "fevd", "--model", sdfm_m, "--pl", "6", "--pu", "32"])
            @test dsf2.status == "ok"
            @test _w2_run_json(["spectral", "fevd", "--result", sf_r]).status == "ok"

            # nowcast gdfm: (1) ragged CSV alone, (2) ragged CSV + --model, (3) --model alone, (4) --result replay
            nc_m = joinpath(dir, "nc_gdfm.jld2")
            dnc1 = _w2_run_json(["nowcast", "gdfm", rcsv, "--dynamic-rank", "2", "--nfactors", "2",
                                 "--horizons", "0", "--n-lags", "2",
                                 "--save-model", nc_m, "--save-result", nc_r,
                                 "--plot-save", joinpath(dir, "nc.html")])
            @test dnc1.status == "ok" && haskey(dnc1.data, :nowcast_gdfm)
            @test isfile(nc_m) && isfile(nc_r) && isfile(joinpath(dir, "nc.html"))

            dnc2 = _w2_run_json(["nowcast", "gdfm", rcsv, "--model", gdfm_m, "--horizons", "1", "--n-lags", "2"])
            @test dnc2.status == "ok" && haskey(dnc2.data, :nowcast_gdfm)

            dnc3 = _w2_run_json(["nowcast", "gdfm", "--model", gdfm_m, "--horizons", "0"])
            @test dnc3.status == "ok"

            @test _w2_run_json(["nowcast", "gdfm", "--result", nc_r]).status == "ok"

            # Validation: mismatched --band-low without --band-high
            e_band = try
                _w2_parse_band(6.0, 32.0, 0.2, nothing, 6.0, 32.0, "filter bandpass-gdfm")
                nothing
            catch e; e; end
            @test e_band isa CliError && e_band.code == "usage/invalid"
        end
    end
end
