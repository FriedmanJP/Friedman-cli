# Wave 4 (#316) T2 mock unit tests:
#   - Registry metadata & short-flag uniqueness for `dsge abcd *` (7) and `dsge var *` (7)
#   - _TIDY_COEF_TYPES / _TIDY_LONG_TYPES zero-ambiguity coverage across all 9 new types
#   - End-to-end dispatch tests for all 14 Wave-4 leaves, handle round-trips, --plot-save,
#     model reproduce on DSGEVARPosterior, and typed CliError guards
#
# Runs both included from `test/test_commands.jl` and standalone via:
#   julia --project test/test_w4_abcd_dsgevar.jl

if !@isdefined(_dsge_abcd_extract)
    using Test
    using CSV, DataFrames, JSON3, PrettyTables, TOML
    using Dates
    using LinearAlgebra: eigvals, diag, I, svd, diagm, logdet, det
    using Statistics: mean, median, var, quantile, std
    using Random
    using Serialization

    _w4_project_root = dirname(@__DIR__)
    if !@isdefined(MacroEconometricModels)
        include(joinpath(_w4_project_root, "test", "mocks.jl"))
        using .MacroEconometricModels
    end
    if !@isdefined(tf_unicode_rounded)
        const tf_unicode_rounded = text_table_borders__unicode_rounded
    end
    include(joinpath(_w4_project_root, "src", "output", "errors.jl"))
    include(joinpath(_w4_project_root, "src", "io.jl"))
    include(joinpath(_w4_project_root, "src", "output", "envelope.jl"))
    include(joinpath(_w4_project_root, "src", "output", "render.jl"))
    include(joinpath(_w4_project_root, "src", "config.jl"))
    include(joinpath(_w4_project_root, "src", "model_card.jl"))
    if !@isdefined(FRIEDMAN_VERSION)
        const FRIEDMAN_VERSION = VersionNumber(
            TOML.parsefile(joinpath(_w4_project_root, "Project.toml"))["version"])
    end
    include(joinpath(_w4_project_root, "src", "cli", "types.jl"))
    include(joinpath(_w4_project_root, "src", "cli", "parser.jl"))
    include(joinpath(_w4_project_root, "src", "cli", "help.jl"))
    include(joinpath(_w4_project_root, "src", "cli", "dispatch.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "shared.jl"))
    include(joinpath(_w4_project_root, "src", "model_handle.jl"))
    include(joinpath(_w4_project_root, "src", "handles.jl"))
    include(joinpath(_w4_project_root, "src", "registry", "spec.jl"))
    include(joinpath(_w4_project_root, "src", "registry", "adapter.jl"))
    include(joinpath(_w4_project_root, "src", "registry", "families.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "estimate.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "test.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "irf.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "fevd.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "hd.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "forecast.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "fitted.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "filter.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "data_simulate.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "data.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "io.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "nowcast.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "w4_abcd_dsgevar.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "dsge.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "hadsge.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "did.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "multipliers.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "policy.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "spectral.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "model.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "completions.jl"))
    include(joinpath(_w4_project_root, "src", "commands", "show.jl"))
    include(joinpath(_w4_project_root, "test", "support.jl"))
end

function _w4_make_dsge_toml(dir::AbstractString; name::String="nk_w4.toml")
    path = joinpath(dir, name)
    write(path, """
    [model]
    parameters = { beta = 0.99, kappa = 0.3, phi = 1.5, rho = 0.8 }
    endogenous = ["y", "pi", "r"]
    exogenous = ["e_y", "e_pi"]
    linear = true

    [[model.equations]]
    expr = "y[t] = y[t+1] - (r[t] - pi[t+1]) + e_y[t]"

    [[model.equations]]
    expr = "pi[t] = beta * pi[t+1] + kappa * y[t] + e_pi[t]"

    [[model.equations]]
    expr = "r[t] = phi * pi[t]"
    """)
    return path
end

function _w4_run_ok_json(args::Vector{String})
    doc = _run_leaf(args)
    @test string(doc.status) == "ok"
    @test doc.schema_version == 1
    errs = validate_envelope_json(JSON3.write(doc))
    @test isempty(errs)
    return doc
end

function _w4_expect_cli_error(args::Vector{String}, expected_code::AbstractString)
    err = try
        _capture() do
            _dispatch_via_app(args)
        end
        nothing
    catch e
        e
    end
    @test err isa CliError
    if err isa CliError
        @test err.code == expected_code
    end
    return err
end

@testset "[MEM111-W4] #316 — dsge abcd & dsge var (mock T2)" begin
    @testset "registry structure, node descriptions, short flags & tidy routing" begin
        @test haskey(_NODE_DESCRIPTIONS, ("dsge", "abcd"))
        @test haskey(_NODE_DESCRIPTIONS, ("dsge", "var"))

        dsge_node = register_dsge_commands!()
        @test haskey(dsge_node.subcmds, "abcd")
        @test haskey(dsge_node.subcmds, "var")

        abcd_node = dsge_node.subcmds["abcd"]
        var_node = dsge_node.subcmds["var"]
        @test abcd_node isa NodeCommand
        @test var_node isa NodeCommand

        abcd_leaves = ["extract", "invertibility", "innovations", "recoverability",
                       "population-var", "audit-irf", "search-observables"]
        var_leaves = ["prior", "lambda", "estimate", "irf", "fevd", "hd", "forecast"]

        for leaf in abcd_leaves
            @test haskey(abcd_node.subcmds, leaf)
            lc = abcd_node.subcmds[leaf]
            @test lc isa LeafCommand
            @test any(o -> o.name == "plot-save", lc.options)
            @test any(f -> f.name == "plot", lc.flags)
            @test any(o -> o.name == "model", lc.options)
        end

        for leaf in var_leaves
            @test haskey(var_node.subcmds, leaf)
            lc = var_node.subcmds[leaf]
            @test lc isa LeafCommand
            @test any(o -> o.name == "plot-save", lc.options)
            @test any(f -> f.name == "plot", lc.flags)
            @test any(o -> o.name == "model", lc.options)
        end

        # Verify allow_data_with_model=true on dsge var lambda|estimate|irf|fevd|hd|forecast
        w4_specs = Dict(s.path => s for s in w4_dsge_specs())
        for sub in ("lambda", "estimate", "irf", "fevd", "hd", "forecast")
            @test w4_specs[["dsge", "var", sub]].allow_data_with_model === true
        end
        @test w4_specs[["dsge", "var", "prior"]].allow_data_with_model === false

        # Zero short-flag collisions across dsge tree
        short_map = Dict{String,Set{String}}()
        function _walk(node)
            for sub in values(node.subcmds)
                if sub isa LeafCommand
                    for o in sub.options
                        isempty(o.short) || push!(get!(short_map, o.short, Set{String}()), o.name)
                    end
                    for f in sub.flags
                        isempty(f.short) || push!(get!(short_map, f.short, Set{String}()), f.name)
                    end
                else
                    _walk(sub)
                end
            end
        end
        _walk(dsge_node)
        @test all(v -> length(v) == 1, values(short_map))

        # All 9 new types registered in _TIDY_COEF_TYPES / _TIDY_LONG_TYPES with zero overlap
        coef_names = Set(Symbol[nameof(t) for t in Base.uniontypes(_TIDY_COEF_TYPES)])
        long_names = Set(Symbol[nameof(t) for t in Base.uniontypes(_TIDY_LONG_TYPES)])
        @test isempty(intersect(coef_names, long_names))
        for t in (:ABCDSystem, :InvertibilityResult, :InnovationsRepresentation,
                  :ObservableSearchResult, :DSGEVARPrior, :DSGEVARLambdaProfile,
                  :DSGEVARPosterior)
            @test t in coef_names
        end
        for t in (:ShockRecoverabilityResult, :DSGEVARIRFAudit)
            @test t in long_names
        end
    end

    @testset "dsge abcd * (all 7 leaves + handle round-trips + --plot-save)" begin
        mktempdir() do dir
            dsge_file = _w4_make_dsge_toml(dir)
            sign_cfg = _make_sign_config(dir)

            # 1. extract (from file + --save-model + --plot-save)
            abcd_path = joinpath(dir, "sys_abcd.jld2")
            plot_abcd = joinpath(dir, "abcd.html")
            doc_ext = _w4_run_ok_json([
                "dsge", "abcd", "extract", dsge_file,
                "--observables", "y,pi",
                "--reduction", "minimal",
                "--measurement-error", "0.01,0.01",
                "--save-model", abcd_path,
                "--plot-save", plot_abcd,
            ])
            @test haskey(doc_ext.data, :abcd_system)
            @test isfile(abcd_path)
            @test isfile(plot_abcd)
            @test load_model_dispatch(abcd_path) isa MacroEconometricModels.ABCDSystem

            # extract from saved DSGESolution handle (--model + --save-model)
            sol_path = joinpath(dir, "dsge_sol.jld2")
            _w4_run_ok_json(["dsge", "solve", dsge_file, "--save-model", sol_path])
            abcd_from_sol = joinpath(dir, "sys_abcd_from_sol.jld2")
            doc_ext2 = _w4_run_ok_json([
                "dsge", "abcd", "extract",
                "--model", sol_path,
                "--observables", "y,pi",
                "--save-model", abcd_from_sol,
            ])
            @test haskey(doc_ext2.data, :abcd_system)
            @test isfile(abcd_from_sol)

            # extract from saved StateSpaceModel handle (no --measurement-error)
            ssm_path = joinpath(dir, "ssm.jld2")
            save_model_dispatch(ssm_path, MacroEconometricModels.StateSpaceModel(
                [0.8 0.0; 0.0 0.5], [1.0 0.0; 0.0 1.0],
                [1.0 0.0; 0.0 1.0], [0.1 0.0; 0.0 0.1]))
            doc_ext_ssm = _w4_run_ok_json(["dsge", "abcd", "extract", "--model", ssm_path])
            @test haskey(doc_ext_ssm.data, :abcd_system)

            # 2. invertibility (from --model ABCDSystem + --save-result + --result replay)
            inv_res = joinpath(dir, "inv_res.jld2")
            plot_inv = joinpath(dir, "inv.html")
            doc_inv = _w4_run_ok_json([
                "dsge", "abcd", "invertibility",
                "--model", abcd_path,
                "--tol", "1e-8",
                "--max-var-lags", "20",
                "--save-result", inv_res,
                "--plot-save", plot_inv,
            ])
            @test haskey(doc_inv.data, :abcd_invertibility)
            @test isfile(inv_res) && isfile(plot_inv)
            doc_inv_replay = _w4_run_ok_json(["dsge", "abcd", "invertibility", "--result", inv_res])
            @test haskey(doc_inv_replay.data, :abcd_invertibility)

            # 3. innovations (default InnovationsRepresentation + --as-abcd)
            innov_path = joinpath(dir, "innov.jld2")
            innov_abcd_path = joinpath(dir, "innov_abcd.jld2")
            plot_innov = joinpath(dir, "innov.html")
            doc_innov = _w4_run_ok_json([
                "dsge", "abcd", "innovations",
                "--model", abcd_path,
                "--save-model", innov_path,
                "--plot-save", plot_innov,
            ])
            @test haskey(doc_innov.data, :abcd_innovations)
            @test load_model_dispatch(innov_path) isa MacroEconometricModels.InnovationsRepresentation
            @test isfile(plot_innov)

            doc_innov_abcd = _w4_run_ok_json([
                "dsge", "abcd", "innovations",
                "--model", abcd_path,
                "--as-abcd",
                "--save-model", innov_abcd_path,
            ])
            @test haskey(doc_innov_abcd.data, :abcd_innovations)
            @test load_model_dispatch(innov_abcd_path) isa MacroEconometricModels.ABCDSystem

            # 4. recoverability (--max-lead + --save-result + --result replay)
            rec_res = joinpath(dir, "rec_res.jld2")
            plot_rec = joinpath(dir, "rec.html")
            doc_rec = _w4_run_ok_json([
                "dsge", "abcd", "recoverability",
                "--model", abcd_path,
                "--max-lead", "6",
                "--save-result", rec_res,
                "--plot-save", plot_rec,
            ])
            @test haskey(doc_rec.data, :abcd_recoverability)
            @test isfile(rec_res) && isfile(plot_rec)
            doc_rec_replay = _w4_run_ok_json(["dsge", "abcd", "recoverability", "--result", rec_res])
            @test haskey(doc_rec_replay.data, :abcd_recoverability)

            # 5. population-var (--save-model VARModel + --plot-save)
            pvar_path = joinpath(dir, "pvar.jld2")
            plot_pvar = joinpath(dir, "pvar.html")
            doc_pvar = _w4_run_ok_json([
                "dsge", "abcd", "population-var",
                "--model", abcd_path,
                "--lags", "2",
                "--n-obs-effective", "500",
                "--save-model", pvar_path,
                "--plot-save", plot_pvar,
            ])
            @test haskey(doc_pvar.data, :population_var)
            @test load_model_dispatch(pvar_path) isa MacroEconometricModels.VARModel
            @test isfile(plot_pvar)

            # 6. audit-irf (best-rotation, cholesky, sign + --config, --save-result + --result)
            audit_res = joinpath(dir, "audit_res.jld2")
            plot_audit = joinpath(dir, "audit.html")
            doc_aud = _w4_run_ok_json([
                "dsge", "abcd", "audit-irf",
                "--model", abcd_path,
                "--lags", "2",
                "--horizons", "8",
                "--id", "best-rotation",
                "--save-result", audit_res,
                "--plot-save", plot_audit,
            ])
            @test haskey(doc_aud.data, :dsge_var_irf_audit)
            @test haskey(doc_aud.data, :dsge_var_irf_wedges)
            @test isfile(audit_res) && isfile(plot_audit)

            doc_aud_chol = _w4_run_ok_json([
                "dsge", "abcd", "audit-irf",
                "--model", abcd_path,
                "--lags", "2", "--horizons", "6",
                "--id", "cholesky",
            ])
            @test haskey(doc_aud_chol.data, :dsge_var_irf_audit)

            doc_aud_sign = _w4_run_ok_json([
                "dsge", "abcd", "audit-irf",
                "--model", abcd_path,
                "--lags", "2", "--horizons", "6",
                "--id", "sign", "--config", sign_cfg,
            ])
            @test haskey(doc_aud_sign.data, :dsge_var_irf_audit)

            doc_aud_replay = _w4_run_ok_json(["dsge", "abcd", "audit-irf", "--result", audit_res])
            @test haskey(doc_aud_replay.data, :dsge_var_irf_audit)
            @test haskey(doc_aud_replay.data, :dsge_var_irf_wedges)

            # 7. search-observables (--k, --candidates, --must-include, --target-shocks, --save-result)
            srch_res = joinpath(dir, "srch_res.jld2")
            plot_srch = joinpath(dir, "srch.html")
            doc_srch = _w4_run_ok_json([
                "dsge", "abcd", "search-observables", dsge_file,
                "--k", "2",
                "--candidates", "y,pi,r",
                "--must-include", "y",
                "--target-shocks", "1,2",
                "--save-result", srch_res,
                "--plot-save", plot_srch,
            ])
            @test haskey(doc_srch.data, :abcd_observable_search)
            @test isfile(srch_res) && isfile(plot_srch)
            doc_srch_replay = _w4_run_ok_json(["dsge", "abcd", "search-observables", "--result", srch_res])
            @test haskey(doc_srch_replay.data, :abcd_observable_search)
        end
    end

    @testset "dsge var * (all 7 leaves + fixed/joint routes + model reproduce)" begin
        mktempdir() do dir
            dsge_file = _w4_make_dsge_toml(dir)
            csv_path = _make_csv(dir; T=80, n=2, colnames=["y", "pi"])
            sol_path = joinpath(dir, "dsge_sol.jld2")
            _w4_run_ok_json(["dsge", "solve", dsge_file, "--save-model", sol_path])

            # 1. prior (--save-model + --lambda inf + --no-intercept + --plot-save)
            prior_path = joinpath(dir, "dv_prior.jld2")
            plot_prior = joinpath(dir, "dv_prior.html")
            doc_pr = _w4_run_ok_json([
                "dsge", "var", "prior",
                "--model", sol_path,
                "--lags", "2",
                "--lambda", "1.0",
                "--t-obs", "100",
                "--observables", "y,pi",
                "--save-model", prior_path,
                "--plot-save", plot_prior,
            ])
            @test haskey(doc_pr.data, :dsge_var_prior)
            @test load_model_dispatch(prior_path) isa MacroEconometricModels.DSGEVARPrior
            @test isfile(plot_prior)

            doc_pr_inf = _w4_run_ok_json([
                "dsge", "var", "prior", dsge_file,
                "--lags", "2", "--lambda", "inf", "--no-intercept",
            ])
            @test haskey(doc_pr_inf.data, :dsge_var_prior)

            # 2. lambda (--model + --data testing allow_data_with_model, grid, single --lambda, --save-result)
            lam_res = joinpath(dir, "dv_lam.jld2")
            plot_lam = joinpath(dir, "dv_lam.html")
            doc_lam = _w4_run_ok_json([
                "dsge", "var", "lambda",
                "--model", sol_path,
                "--data", csv_path,
                "--lags", "2",
                "--lambda-grid", "0.5,1.0,2.0",
                "--no-refine",
                "--observables", "y,pi",
                "--save-result", lam_res,
                "--plot-save", plot_lam,
            ])
            @test haskey(doc_lam.data, :dsge_var_lambda_profile)
            @test isfile(lam_res) && isfile(plot_lam)

            doc_lam_single = _w4_run_ok_json([
                "dsge", "var", "lambda", dsge_file,
                "--data", csv_path,
                "--lags", "2",
                "--lambda", "1.5",
                "--observables", "y,pi",
            ])
            @test haskey(doc_lam_single.data, :dsge_var_lambda_profile)

            doc_lam_replay = _w4_run_ok_json(["dsge", "var", "lambda", "--result", lam_res])
            @test haskey(doc_lam_replay.data, :dsge_var_lambda_profile)

            # 3. estimate (fixed-parameter with --model + --data + --save-model)
            post_path = joinpath(dir, "dv_post.jld2")
            plot_post = joinpath(dir, "dv_post.html")
            prev_seed = _SEED[]
            _SEED[] = 42
            doc_est = try
                _w4_run_ok_json([
                    "dsge", "var", "estimate",
                    "--model", sol_path,
                    "--data", csv_path,
                    "--lags", "2",
                    "--lambda", "1.0",
                    "--draws", "40",
                    "--observables", "y,pi",
                    "--save-model", post_path,
                    "--plot-save", plot_post,
                ])
            finally
                _SEED[] = prev_seed
            end
            @test haskey(doc_est.data, :dsge_var_posterior)
            @test load_model_dispatch(post_path) isa MacroEconometricModels.DSGEVARPosterior
            @test isfile(plot_post)

            # estimate (joint Bayesian ModelSpec route: rwmh & smc)
            for meth in ("rwmh", "smc")
                doc_joint = _w4_run_ok_json([
                    "dsge", "var", "estimate", dsge_file,
                    "--data", csv_path,
                    "--lags", "2",
                    "--lambda", "1.0",
                    "--draws", "20",
                    "--burnin", "5",
                    "--n-particles", "20",
                    "--method", meth,
                    "--prior", "rho ~ Beta(2, 2)",
                    "--observables", "y,pi",
                ])
                @test haskey(doc_joint.data, :dsge_var_posterior)
            end

            # 4. irf (from saved --model DSGEVARPosterior, --shock filter, --save-result + --result, inline)
            irf_res = joinpath(dir, "dv_irf.jld2")
            plot_irf = joinpath(dir, "dv_irf.html")
            doc_irf = _w4_run_ok_json([
                "dsge", "var", "irf",
                "--model", post_path,
                "--id", "dsge-qr",
                "--horizons", "8",
                "--shock", "1",
                "--save-result", irf_res,
                "--plot-save", plot_irf,
            ])
            @test haskey(doc_irf.data, :dsge_var_irf)
            @test isfile(irf_res) && isfile(plot_irf)
            doc_irf_replay = _w4_run_ok_json(["dsge", "var", "irf", "--result", irf_res])
            @test haskey(doc_irf_replay.data, :dsge_var_irf)

            doc_irf_inline = _w4_run_ok_json([
                "dsge", "var", "irf", dsge_file,
                "--data", csv_path,
                "--lags", "2", "--lambda", "1.0", "--draws", "20",
                "--horizons", "6", "--observables", "y,pi",
            ])
            @test haskey(doc_irf_inline.data, :dsge_var_irf)

            # 5. fevd (from saved --model + --save-result + --result)
            fevd_res = joinpath(dir, "dv_fevd.jld2")
            plot_fevd = joinpath(dir, "dv_fevd.html")
            doc_fevd = _w4_run_ok_json([
                "dsge", "var", "fevd",
                "--model", post_path,
                "--id", "cholesky",
                "--horizons", "8",
                "--save-result", fevd_res,
                "--plot-save", plot_fevd,
            ])
            @test any(k -> startswith(string(k), "dsge_var_fevd"), keys(doc_fevd.data))
            @test isfile(fevd_res) && isfile(plot_fevd)
            doc_fevd_replay = _w4_run_ok_json(["dsge", "var", "fevd", "--result", fevd_res])
            @test any(k -> startswith(string(k), "dsge_var_fevd"), keys(doc_fevd_replay.data))

            # 6. hd (from saved --model + --save-result + --result)
            hd_res = joinpath(dir, "dv_hd.jld2")
            plot_hd = joinpath(dir, "dv_hd.html")
            doc_hd = _w4_run_ok_json([
                "dsge", "var", "hd",
                "--model", post_path,
                "--id", "dsge-qr",
                "--save-result", hd_res,
                "--plot-save", plot_hd,
            ])
            @test any(k -> startswith(string(k), "dsge_var_hd"), keys(doc_hd.data))
            @test isfile(hd_res) && isfile(plot_hd)
            doc_hd_replay = _w4_run_ok_json(["dsge", "var", "hd", "--result", hd_res])
            @test any(k -> startswith(string(k), "dsge_var_hd"), keys(doc_hd_replay.data))

            # 7. forecast (from saved --model + --conf-level + --save-result + --result + inline)
            fc_res = joinpath(dir, "dv_fc.jld2")
            plot_fc = joinpath(dir, "dv_fc.html")
            doc_fc = _w4_run_ok_json([
                "dsge", "var", "forecast",
                "--model", post_path,
                "--horizons", "6",
                "--conf-level", "0.90",
                "--save-result", fc_res,
                "--plot-save", plot_fc,
            ])
            @test haskey(doc_fc.data, :dsge_var_forecast)
            @test isfile(fc_res) && isfile(plot_fc)
            doc_fc_replay = _w4_run_ok_json(["dsge", "var", "forecast", "--result", fc_res])
            @test haskey(doc_fc_replay.data, :dsge_var_forecast)

            # 8. model reproduce on saved DSGEVARPosterior handle
            doc_repro = _w4_run_ok_json(["model", "reproduce", post_path])
            @test haskey(doc_repro.data, :model_reproduce_summary)
            @test haskey(doc_repro.data, :model_reproduce_fields)
            kv_repro = Dict(string(r[1]) => string(r[2]) for r in doc_repro.data.model_reproduce_summary.rows)
            @test kv_repro["model_type"] == "DSGEVARPosterior"
            @test kv_repro["matched"] == "true"
        end
    end

    @testset "Wave-4 typed CliError guards" begin
        mktempdir() do dir
            dsge_file = _w4_make_dsge_toml(dir)
            csv_path = _make_csv(dir; T=60, n=2, colnames=["y", "pi"])
            ssm_path = joinpath(dir, "ssm.jld2")
            save_model_dispatch(ssm_path, MacroEconometricModels.StateSpaceModel(
                [0.8 0.0; 0.0 0.5], [1.0 0.0; 0.0 1.0],
                [1.0 0.0; 0.0 1.0], [0.1 0.0; 0.0 0.1]))
            sol_path = joinpath(dir, "dsge_sol.jld2")
            _w4_run_ok_json(["dsge", "solve", dsge_file, "--save-model", sol_path])
            inv_res = joinpath(dir, "inv_res.jld2")
            _w4_run_ok_json(["dsge", "abcd", "invertibility", dsge_file, "--save-result", inv_res])

            # Missing model/file
            _w4_expect_cli_error(["dsge", "abcd", "extract"], "usage/missing")
            _w4_expect_cli_error(["dsge", "var", "estimate", dsge_file], "usage/missing")

            # Positional file + --model conflict
            _w4_expect_cli_error(["dsge", "abcd", "extract", dsge_file, "--model", sol_path],
                                 "usage/conflicting-options")

            # --measurement-error rejected on StateSpaceModel
            _w4_expect_cli_error(["dsge", "abcd", "extract", "--model", ssm_path,
                                  "--measurement-error", "0.1,0.1"],
                                 "usage/invalid-option")

            # --id sign requires --config
            _w4_expect_cli_error(["dsge", "abcd", "audit-irf", dsge_file, "--id", "sign"],
                                 "usage/missing")

            # --result conflicts with model/file
            _w4_expect_cli_error(["dsge", "abcd", "invertibility", dsge_file, "--result", inv_res],
                                 "usage/invalid")

            # --lambda and --lambda-grid conflict on dsge var lambda
            _w4_expect_cli_error(["dsge", "var", "lambda", dsge_file, "--data", csv_path,
                                  "--lambda", "1.0", "--lambda-grid", "0.5,1.0"],
                                 "usage/conflicting-options")

            # --prior requires ModelSpec, not solved DSGESolution handle
            _w4_expect_cli_error(["dsge", "var", "estimate", "--model", sol_path,
                                  "--data", csv_path, "--prior", "rho ~ Beta(2, 2)"],
                                 "usage/conflicting-options")

            # Invalid numeric/option bounds
            _w4_expect_cli_error(["dsge", "var", "prior", dsge_file, "--lags", "0"],
                                 "usage/invalid-option")
            _w4_expect_cli_error(["dsge", "var", "prior", dsge_file, "--lambda", "-1.0"],
                                 "usage/invalid-option")
            _w4_expect_cli_error(["dsge", "abcd", "recoverability", dsge_file, "--max-lead", "-1"],
                                 "usage/invalid-option")
        end
    end
end
