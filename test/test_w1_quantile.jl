# Wave 1 ([MEM111-W1] #313) T2 unit tests (mock MacroEconometricModels).
# Runnable standalone (`julia --project test/test_w1_quantile.jl`) or included
# at the end of `test/test_commands.jl`.

if !@isdefined(_estimate_qfm)
    using Test
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
    include(joinpath(project_root, "src", "commands", "w1_quantile.jl"))
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

function _w1_parse_json_envelope(raw::AbstractString)
    i = findfirst('{', raw)
    @assert i !== nothing "Expected JSON envelope, got: $raw"
    return JSON3.read(raw[i:end])
end

@testset "[MEM111-W1] #313 Quantile Factor, GaR, xtqreg, QVAR, QFAVAR & QReg IPM" begin

    @testset "Command tree, family registration & plot discipline" begin
        est = register_estimate_commands!()
        pred = register_predict_commands!()
        res = register_residuals_commands!()
        fc = register_forecast_commands!()
        irf_n = register_irf_commands!()
        tst = register_test_commands!()

        # Family nodes and leaves exist
        @test est.subcmds["factor"].subcmds["qfm"] isa LeafCommand
        @test est.subcmds["panel"].subcmds["xtqreg"] isa LeafCommand
        @test est.subcmds["multivariate"].subcmds["qvar"] isa LeafCommand
        @test est.subcmds["multivariate"].subcmds["qfavar"] isa LeafCommand

        @test pred.subcmds["factor"].subcmds["qfm"] isa LeafCommand
        @test pred.subcmds["panel"].subcmds["xtqreg"] isa LeafCommand
        @test res.subcmds["factor"].subcmds["qfm"] isa LeafCommand
        @test res.subcmds["panel"].subcmds["xtqreg"] isa LeafCommand
        @test res.subcmds["multivariate"].subcmds["qvar"] isa LeafCommand

        @test fc.subcmds["factor"].subcmds["qfm"] isa LeafCommand
        @test fc.subcmds["factor"].subcmds["growth-at-risk"] isa LeafCommand
        @test fc.subcmds["multivariate"].subcmds["qfavar"] isa LeafCommand

        @test irf_n.subcmds["qvar"] isa LeafCommand
        @test irf_n.subcmds["qfavar"] isa LeafCommand

        @test haskey(tst.subcmds, "factor")
        @test tst.subcmds["factor"].subcmds["qfm-spanning"] isa LeafCommand
        @test tst.subcmds["factor"].subcmds["qfm-constancy"] isa LeafCommand

        # QReg has --solver ipm|irls
        qreg_leaf = est.subcmds["regression"].subcmds["qreg"]
        solver_opt = only(filter(o -> o.name == "solver", qreg_leaf.options))
        @test solver_opt.default == "ipm"
        @test solver_opt.choices == ["ipm", "irls"]

        # STRICT PLOT DISCIPLINE:
        # QuantileVARModel, QuantileFAVAR, VBQuantileFAVAR, qfavar_panel_forecast have plot_result=false
        for leaf in (
            est.subcmds["multivariate"].subcmds["qvar"],
            est.subcmds["multivariate"].subcmds["qfavar"],
            fc.subcmds["multivariate"].subcmds["qfavar"],
        )
            @test !any(f -> f.name == "plot", leaf.flags)
            @test !any(o -> o.name == "plot-save", leaf.options)
        end

        # Plottable leaves MUST advertise --plot and --plot-save
        for leaf in (
            est.subcmds["factor"].subcmds["qfm"],
            est.subcmds["panel"].subcmds["xtqreg"],
            fc.subcmds["factor"].subcmds["qfm"],
            fc.subcmds["factor"].subcmds["growth-at-risk"],
            irf_n.subcmds["qvar"],
            irf_n.subcmds["qfavar"],
            tst.subcmds["factor"].subcmds["qfm-spanning"],
            tst.subcmds["factor"].subcmds["qfm-constancy"],
        )
            @test any(f -> f.name == "plot", leaf.flags)
            @test any(o -> o.name == "plot-save", leaf.options)
        end
    end

    @testset "estimate regression qreg --solver ipm|irls" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=3, colnames=["y", "x1", "x2"])
            for slv in ("ipm", "irls")
                out = _capture() do
                    _dispatch_via_app(["estimate", "regression", "qreg", csv,
                                       "--dep", "y", "--tau", "0.25,0.5",
                                       "--solver", slv, "--format", "json"])
                end
                doc = _w1_parse_json_envelope(out)
                @test doc.status == "ok"
                @test haskey(doc.data, :quantile_regression_coefficients)
                @test haskey(doc.data, :quantile_fit_diagnostics)
            end
        end
    end

    @testset "QFM estimate / predict / residuals / forecast / spanning / constancy" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=6, colnames=["x$i" for i in 1:6])
            qfm_handle = joinpath(dir, "qfm_single.jld2")
            grid_handle = joinpath(dir, "qfm_grid.jld2")
            fc_handle = joinpath(dir, "qfm_fc.jld2")

            # Single tau + auto factors (emits qfm_ic + qfm_loadings via _emit_result)
            out1 = _capture() do
                _dispatch_via_app(["estimate", "factor", "qfm", csv,
                                   "--tau", "0.5", "--factors", "auto",
                                   "--r-max", "3", "--criterion", "rank",
                                   "--method", "smoothed", "--kernel", "epanechnikov",
                                   "--se", "asymptotic", "--standardize",
                                   "--save-model", qfm_handle, "--format", "json"])
            end
            d1 = _w1_parse_json_envelope(out1)
            @test d1.status == "ok"
            @test haskey(d1.data, :qfm_ic)
            @test haskey(d1.data, :qfm_loadings)
            @test isfile(qfm_handle)

            # Multi-tau grid
            out2 = _capture() do
                _dispatch_via_app(["estimate", "factor", "qfm", csv,
                                   "--taus", "0.1,0.5,0.9", "--factors", "2",
                                   "--save-model", grid_handle, "--format", "json"])
            end
            d2 = _w1_parse_json_envelope(out2)
            @test d2.status == "ok"
            @test haskey(d2.data, :qfm_loadings)
            @test isfile(grid_handle)

            # predict & residuals factor qfm (both inline and --model)
            for verb in ("predict", "residuals")
                out_in = _capture() do
                    _dispatch_via_app([verb, "factor", "qfm", csv,
                                       "--tau", "0.5", "--factors", "2", "--format", "json"])
                end
                @test _w1_parse_json_envelope(out_in).status == "ok"
                out_m = _capture() do
                    _dispatch_via_app([verb, "factor", "qfm", "--model", qfm_handle,
                                       "--format", "json"])
                end
                @test _w1_parse_json_envelope(out_m).status == "ok"
            end

            # forecast factor qfm (single --model + --save-result + --result replay, plus grid)
            out_fc = _capture() do
                _dispatch_via_app(["forecast", "factor", "qfm", "--model", qfm_handle,
                                   "--horizons", "4", "--lags", "1",
                                   "--save-result", fc_handle, "--format", "json"])
            end
            dfc = _w1_parse_json_envelope(out_fc)
            @test dfc.status == "ok"
            @test haskey(dfc.data, :qfm_forecast)
            @test isfile(fc_handle)

            out_fcr = _capture() do
                _dispatch_via_app(["forecast", "factor", "qfm", "--result", fc_handle,
                                   "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_fcr).status == "ok"

            out_fcg = _capture() do
                _dispatch_via_app(["forecast", "factor", "qfm", "--model", grid_handle,
                                   "--horizons", "4", "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_fcg).status == "ok"

            # test factor qfm-spanning (inline, --model, --save-result / --result)
            span_res = joinpath(dir, "span.jld2")
            out_sp = _capture() do
                _dispatch_via_app(["test", "factor", "qfm-spanning", "--model", grid_handle,
                                   "--r-pca", "2", "--threshold", "0.5",
                                   "--save-result", span_res, "--format", "json"])
            end
            dsp = _w1_parse_json_envelope(out_sp)
            @test dsp.status == "ok"
            @test haskey(dsp.data, :qfm_spanning_test)
            @test isfile(span_res)

            out_spr = _capture() do
                _dispatch_via_app(["test", "factor", "qfm-spanning", "--result", span_res,
                                   "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_spr).status == "ok"

            # test factor qfm-constancy (inline, --model, --save-result / --result)
            const_res = joinpath(dir, "const.jld2")
            out_ct = _capture() do
                _dispatch_via_app(["test", "factor", "qfm-constancy", "--model", grid_handle,
                                   "--tau1", "0.1", "--tau2", "0.9", "--n-boot", "10",
                                   "--bootstrap", "wild", "--save-result", const_res,
                                   "--format", "json"])
            end
            dct = _w1_parse_json_envelope(out_ct)
            @test dct.status == "ok"
            @test haskey(dct.data, :qfm_constancy_test)
            @test isfile(const_res)

            out_ctr = _capture() do
                _dispatch_via_app(["test", "factor", "qfm-constancy", "--result", const_res,
                                   "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_ctr).status == "ok"

            # Bad tau not in grid → typed usage/invalid
            @test_throws CliError _dispatch_via_app([
                "test", "factor", "qfm-constancy", "--model", grid_handle,
                "--tau1", "0.25", "--tau2", "0.9", "--format", "json"])
        end
    end

    @testset "Growth-at-Risk (forecast factor growth-at-risk)" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=60, n=5, colnames=["gdp", "x1", "x2", "x3", "x4"])
            gar_res = joinpath(dir, "gar.jld2")
            gar_mod = joinpath(dir, "gar_grid.jld2")

            out = _capture() do
                _dispatch_via_app(["forecast", "factor", "growth-at-risk", csv,
                                   "--target", "gdp", "--horizons", "2", "--factors", "2",
                                   "--density", "skewed-t", "--alpha", "0.05",
                                   "--save-model", gar_mod, "--save-result", gar_res,
                                   "--format", "json"])
            end
            doc = _w1_parse_json_envelope(out)
            @test doc.status == "ok"
            @test haskey(doc.data, :growth_at_risk)
            @test isfile(gar_mod) && isfile(gar_res)

            # Replay --result and reuse --model
            out_r = _capture() do
                _dispatch_via_app(["forecast", "factor", "growth-at-risk",
                                   "--result", gar_res, "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_r).status == "ok"

            out_m = _capture() do
                _dispatch_via_app(["forecast", "factor", "growth-at-risk",
                                   "--model", gar_mod, "--target", "gdp",
                                   "--density", "normal", "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_m).status == "ok"
        end
    end

    @testset "Interactive panel quantile regression (xtqreg)" begin
        mktempdir() do dir
            pcsv = _make_panel_csv(dir; G=6, T_per=15, n=3, colnames=["y", "x1", "x2"])
            xt_mod = joinpath(dir, "xtqreg.jld2")

            out = _capture() do
                _dispatch_via_app(["estimate", "panel", "xtqreg", pcsv,
                                   "--id-col", "group", "--time-col", "time",
                                   "--dep", "y", "--indep", "x1,x2",
                                   "--factors", "1", "--tau", "0.5",
                                   "--save-model", xt_mod, "--format", "json"])
            end
            doc = _w1_parse_json_envelope(out)
            @test doc.status == "ok"
            @test haskey(doc.data, :xtqreg_coefficients)
            @test isfile(xt_mod)

            for (verb, tkey) in (("predict", :xtqreg_fitted_values), ("residuals", :xtqreg_residuals))
                out_m = _capture() do
                    _dispatch_via_app([verb, "panel", "xtqreg", "--model", xt_mod,
                                       "--format", "json"])
                end
                dm = _w1_parse_json_envelope(out_m)
                @test dm.status == "ok"
                @test haskey(dm.data, tkey)
            end
        end
    end

    @testset "QVAR & QIRF" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=80, n=3, colnames=["y1", "y2", "y3"])
            qv_mod = joinpath(dir, "qvar.jld2")
            qi_res = joinpath(dir, "qirf.jld2")

            out = _capture() do
                _dispatch_via_app(["estimate", "multivariate", "qvar", csv,
                                   "--lags", "1", "--taus", "0.1,0.5,0.9",
                                   "--ordering", "y2,y1,y3", "--se", "asymptotic",
                                   "--save-model", qv_mod, "--format", "json"])
            end
            doc = _w1_parse_json_envelope(out)
            @test doc.status == "ok"
            @test haskey(doc.data, :qvar_coefficients)
            @test isfile(qv_mod)

            out_res = _capture() do
                _dispatch_via_app(["residuals", "multivariate", "qvar",
                                   "--model", qv_mod, "--format", "json"])
            end
            dr = _w1_parse_json_envelope(out_res)
            @test dr.status == "ok"
            @test haskey(dr.data, :qvar_residuals)

            out_irf = _capture() do
                _dispatch_via_app(["irf", "qvar", "--model", qv_mod,
                                   "--horizons", "8", "--shock", "1",
                                   "--tau-profile", "0.1,0.2,0.5", "--method", "monte-carlo",
                                   "--save-result", qi_res, "--format", "json"])
            end
            di = _w1_parse_json_envelope(out_irf)
            @test di.status == "ok"
            @test haskey(di.data, :qvar_irf)
            @test isfile(qi_res)

            out_irfr = _capture() do
                _dispatch_via_app(["irf", "qvar", "--result", qi_res, "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_irfr).status == "ok"
        end
    end

    @testset "QFAVAR estimate / irf / forecast (twostep & vb)" begin
        mktempdir() do dir
            csv = _make_csv(dir; T=80, n=6, colnames=["x1", "x2", "x3", "x4", "infl", "ffr"])
            qf_mod = joinpath(dir, "qfavar.jld2")
            vb_mod = joinpath(dir, "vbqfavar.jld2")
            qfi_res = joinpath(dir, "qfavar_irf.jld2")
            qff_res = joinpath(dir, "qfavar_fc.jls")

            out1 = _capture() do
                _dispatch_via_app(["estimate", "multivariate", "qfavar", csv,
                                   "--factors", "2", "--lags", "1",
                                   "--key-vars", "infl,ffr", "--taus", "0.1,0.5,0.9",
                                   "--method", "twostep", "--save-model", qf_mod,
                                   "--format", "json"])
            end
            d1 = _w1_parse_json_envelope(out1)
            @test d1.status == "ok"
            @test haskey(d1.data, :qfavar_loadings)
            @test isfile(qf_mod)

            out2 = _capture() do
                _dispatch_via_app(["estimate", "multivariate", "qfavar", csv,
                                   "--factors", "2", "--lags", "1",
                                   "--key-vars", "infl,ffr", "--taus", "0.1,0.5,0.9",
                                   "--method", "vb", "--vb-maxiter", "10", "--n-draws", "20",
                                   "--save-model", vb_mod, "--format", "json"])
            end
            d2 = _w1_parse_json_envelope(out2)
            @test d2.status == "ok"
            @test haskey(d2.data, :qfavar_loadings)
            @test isfile(vb_mod)

            # irf qfavar with VB model + --ci-type credible + --save-result / --result
            out_irf = _capture() do
                _dispatch_via_app(["irf", "qfavar", "--model", vb_mod,
                                   "--horizons", "6", "--shock", "3",
                                   "--ci-type", "credible",
                                   "--save-result", qfi_res, "--format", "json"])
            end
            di = _w1_parse_json_envelope(out_irf)
            @test di.status == "ok"
            @test haskey(di.data, :qfavar_irf)
            @test isfile(qfi_res)

            out_irfr = _capture() do
                _dispatch_via_app(["irf", "qfavar", "--result", qfi_res, "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_irfr).status == "ok"

            # credible CI rejected on twostep QuantileFAVAR
            @test_throws CliError _dispatch_via_app([
                "irf", "qfavar", "--model", qf_mod, "--ci-type", "credible",
                "--format", "json"])

            # forecast multivariate qfavar + --save-result / --result
            out_fc = _capture() do
                _dispatch_via_app(["forecast", "multivariate", "qfavar", "--model", qf_mod,
                                   "--horizons", "4", "--save-result", qff_res,
                                   "--format", "json"])
            end
            dfc = _w1_parse_json_envelope(out_fc)
            @test dfc.status == "ok"
            @test haskey(dfc.data, :qfavar_forecast)
            @test isfile(qff_res)

            out_fcr = _capture() do
                _dispatch_via_app(["forecast", "multivariate", "qfavar",
                                   "--result", qff_res, "--format", "json"])
            end
            @test _w1_parse_json_envelope(out_fcr).status == "ok"
        end
    end

end
