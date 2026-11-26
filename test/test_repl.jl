using Test
using CSV, DataFrames, JSON3

# Set up minimal Friedman context for testing repl.jl
module Friedman
    using CSV, DataFrames, JSON3

    # Minimal stubs matching io.jl functions
    struct CliError <: Exception
        code::String; message::String; hint::String
    end
    CliError(code::String, message::String; hint::String="") = CliError(code, message, hint)

    const EXAMPLE_DATASETS = (
        :fred_md, :fred_qd, :pwt, :mpdta, :ddcg,
        :denmark, :gnp_hamilton, :grunfeld, :mp_shocks, :mroz, :nile, :stackloss,
    )

    function parse_dataset_name(name::AbstractString)
        stem = String(strip(name))
        startswith(stem, ":") && (stem = stem[2:end])
        sym = Symbol(replace(lowercase(stem), "-" => "_"))
        sym in EXAMPLE_DATASETS && return sym
        throw(CliError("data/unknown-dataset", "unknown dataset '$name'"))
    end

    # Mirrors io.jl: dual-read FRDC_* with FRIEDMAN_* fallback (#300)
    function _env_get(primary::String, legacy::String, default=nothing)
        haskey(ENV, primary) && return ENV[primary]
        haskey(ENV, legacy) && return ENV[legacy]
        return default
    end
    function _env_get(keys::Tuple{Vararg{String}}, default=nothing)
        for k in keys
            haskey(ENV, k) && return ENV[k]
        end
        return default
    end

    # Mirrors io.jl: Base.expanduser is a no-op on Windows, so repl.jl uses ours.
    function _expanduser(path::AbstractString)
        p = String(path)
        startswith(p, "~") || return p
        length(p) == 1 && return homedir()
        if Sys.iswindows()
            c = p[2]
            (c == '/' || c == '\\') || return p
            return joinpath(homedir(), lstrip(ch -> ch == '/' || ch == '\\', p[3:end]))
        end
        return try
            expanduser(p)
        catch e
            e isa ArgumentError ? p : rethrow()
        end
    end

    function resolve_stem(path::String; slot::Symbol=:data)::String
        startswith(path, ":") && return path
        startswith(path, "model://") && return path
        path = _expanduser(path)
        if occursin(r"\.[A-Za-z0-9]+$", basename(path))
            return path
        end
        jld = path * ".jld2"
        isfile(jld) && return jld
        if slot === :data
            csv = path * ".csv"
            isfile(csv) && return csv
        end
        isfile(path) && return path
        throw(CliError("data/file-not-found", "file not found: $path"))
    end

    function load_data(path::String)
        if startswith(path, ":")
            ds = load_example(parse_dataset_name(path))
            return DataFrame(ds.data, ds.varnames; makeunique=true)
        end
        path = _expanduser(path)
        isfile(path) || error("file not found: $path")
        df = CSV.read(path, DataFrame)
        nrow(df) == 0 && error("empty dataset: $path")
        return df
    end
    function df_to_matrix(df::DataFrame)
        numeric_cols = [n for n in names(df) if eltype(df[!, n]) <: Union{Number, Missing}]
        isempty(numeric_cols) && error("no numeric columns found")
        return Matrix{Float64}(df[!, numeric_cols])
    end
    variable_names(df::DataFrame) = [n for n in names(df) if eltype(df[!, n]) <: Union{Number, Missing}]

    function load_example(name::Symbol)
        if name == :fred_md
            data = [1.0 2.0 3.0; 4.0 5.0 6.0; 7.0 8.0 9.0]
            return (data=data, varnames=["INDPRO", "CPI", "FEDFUNDS"])
        elseif name == :fred_qd
            data = [1.0 2.0; 3.0 4.0]
            return (data=data, varnames=["GDP", "PCE"])
        elseif name == :pwt
            data = ones(5, 3)
            return (data=data, varnames=["rgdpe", "pop", "emp"])
        elseif name == :mpdta
            data = ones(4, 2)
            return (data=data, varnames=["lemp", "lpop"])
        elseif name == :ddcg
            data = ones(3, 2)
            return (data=data, varnames=["y", "d"])
        elseif name == :denmark
            data = ones(55, 5)
            return (data=data, varnames=["LRM", "LRY", "LPY", "IBO", "IDE"])
        elseif name in (:gnp_hamilton, :grunfeld, :mp_shocks, :mroz, :nile, :stackloss)
            data = ones(10, 2)
            return (data=data, varnames=["x1", "x2"])
        else
            error("unknown dataset: $name")
        end
    end

    # CLI type stubs matching real types from cli/types.jl
    struct ParseError <: Exception; message::String; end
    struct DispatchError <: Exception; message::String; end
    struct Argument; name::String; required::Bool; end
    struct Option; name::String; short::String; type::Type; default::Any; description::String; end
    struct Flag; name::String; short::String; description::String; end
    struct LeafCommand; name::String; handler::Function; args::Vector{Argument}; options::Vector{Option}; flags::Vector{Flag}; description::String; end
    struct NodeCommand; name::String; subcmds::Dict{String,Union{NodeCommand,LeafCommand}}; description::String; end
    struct Entry; name::String; root::NodeCommand; version::VersionNumber; end
    const FRIEDMAN_VERSION = v"0.4.1"
    const _QUIET = Ref(false)
    const _COLOR = Ref(true)
    const _SEED  = Ref{Union{Int,Nothing}}(nothing)
    _last_injected_model = nothing
    _last_dispatched_args = String[]
    _last_seen_seed = nothing
    _last_seen_quiet = false
    function dispatch(app, args; extra_kwargs...)
        global _last_dispatched_args = copy(args)
        global _last_seen_seed = _SEED[]
        global _last_seen_quiet = _QUIET[]
        if !isempty(args) && startswith(args[1], "-")
            throw(DispatchError("frdc: unknown command '$(args[1])'"))
        end
        # Return a mock result for estimate commands (model token: depth-3
        # family path, else the flat leaf)
        if !isempty(args) && args[1] == "estimate" && length(args) >= 2
            tag = length(args) >= 3 ? args[3] : args[2]
            return "mock_$(tag)_model"
        end
        # For downstream commands, store the injected model in a global for testing
        if haskey(Dict(extra_kwargs), :model)
            global _last_injected_model = Dict(extra_kwargs)[:model]
        end
        return nothing
    end
    function build_app()
        noop = (;kwargs...) -> nothing
        var_leaf = LeafCommand("var", noop, Argument[],
            [Option("lags", "p", Int, 4, "Lag order"), Option("format", "f", String, "table", "Output format")],
            [Flag("plot", "", "Show plot")], "Estimate VAR")
        bvar_leaf = LeafCommand("bvar", noop, Argument[], Option[], Flag[], "Estimate BVAR")
        vecm_leaf = LeafCommand("vecm", noop, Argument[], Option[], Flag[], "Estimate VECM")

        mvar_family = NodeCommand("multivariate", Dict{String,Union{NodeCommand,LeafCommand}}(
            "var" => var_leaf, "bvar" => bvar_leaf, "vecm" => vecm_leaf
        ), "Multivariate family")
        estimate_node = NodeCommand("estimate", Dict{String,Union{NodeCommand,LeafCommand}}(
            "multivariate" => mvar_family
        ), "Estimation commands")

        irf_var_leaf = LeafCommand("var", noop, Argument[], Option[], Flag[], "VAR IRF")
        irf_node = NodeCommand("irf", Dict{String,Union{NodeCommand,LeafCommand}}(
            "var" => irf_var_leaf
        ), "IRF commands")

        data_list = LeafCommand("list", noop, Argument[], Option[], Flag[], "List datasets")
        data_use = LeafCommand("use", noop, Argument[], Option[], Flag[], "Use dataset")
        data_node = NodeCommand("data", Dict{String,Union{NodeCommand,LeafCommand}}(
            "list" => data_list, "use" => data_use
        ), "Data commands")

        bayes_est = LeafCommand("estimate", noop, Argument[],
            [Option("draws", "n", Int, 1000, "Draws")], Flag[], "Bayes estimate")
        bayes_node = NodeCommand("bayes", Dict{String,Union{NodeCommand,LeafCommand}}(
            "estimate" => bayes_est
        ), "Bayesian DSGE")
        dsge_solve = LeafCommand("solve", noop, Argument[], Option[], Flag[], "Solve DSGE")
        dsge_node = NodeCommand("dsge", Dict{String,Union{NodeCommand,LeafCommand}}(
            "bayes" => bayes_node, "solve" => dsge_solve
        ), "DSGE commands")

        granger_leaf = LeafCommand("granger", noop, Argument[], Option[], Flag[], "Granger test")
        test_mvar = NodeCommand("multivariate", Dict{String,Union{NodeCommand,LeafCommand}}(
            "granger" => granger_leaf
        ), "Multivariate tests")
        test_node = NodeCommand("test", Dict{String,Union{NodeCommand,LeafCommand}}(
            "multivariate" => test_mvar
        ), "Tests")

        root = NodeCommand("frdc", Dict{String,Union{NodeCommand,LeafCommand}}(
            "estimate" => estimate_node,
            "irf" => irf_node,
            "data" => data_node,
            "dsge" => dsge_node,
            "test" => test_node,
        ), "Main")

        Entry("frdc", root, v"0.4.1")
    end

    # Precomputed completion index uses APP when present; tests call build_completion_index(app).
    include(joinpath(@__DIR__, "..", "src", "repl.jl"))
end

@testset "REPL Session" begin
    @testset "Session initialization" begin
        s = Friedman.Session()
        @test s.data_path == ""
        @test isnothing(s.df)
        @test isnothing(s.Y)
        @test isempty(s.varnames)
        @test isempty(s.results)
        @test s.last_model == :none
    end

    @testset "session_load_data!" begin
        s = Friedman.Session()
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "x,y,z")
            println(io, "1.0,2.0,3.0")
            println(io, "4.0,5.0,6.0")
            println(io, "7.0,8.0,9.0")
        end
        Friedman.session_load_data!(s, tmpfile)
        @test s.data_path == tmpfile
        @test !isnothing(s.df)
        @test size(s.Y) == (3, 3)
        @test s.varnames == ["x", "y", "z"]
        @test isempty(s.results)
        rm(tmpfile; force=true)
    end

    @testset "session_load_data! clears results" begin
        s = Friedman.Session()
        s.results[:var] = "fake_model"
        s.last_model = :var
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "a,b")
            println(io, "1.0,2.0")
            println(io, "3.0,4.0")
        end
        Friedman.session_load_data!(s, tmpfile)
        @test isempty(s.results)
        @test s.last_model == :none
        rm(tmpfile; force=true)
    end

    @testset "session_load_data! resolves stem to .jld2" begin
        s = Friedman.Session()
        mktempdir() do dir
            csv = joinpath(dir, "macro.csv")
            jld = joinpath(dir, "macro.jld2")
            CSV.write(csv, DataFrame(x=[1.0, 2.0], y=[3.0, 4.0]))
            # stub load_data CSV.reads; table content at the .jld2 path is enough
            # to pin that `data use macro` injects `macro.jld2` when it exists.
            CSV.write(jld, DataFrame(x=[10.0, 20.0], y=[30.0, 40.0]))
            Friedman.session_load_data!(s, joinpath(dir, "macro"))
            @test s.data_path == jld
            @test s.varnames == ["x", "y"]
            @test size(s.Y) == (2, 2)
            @test s.Y[1, 1] == 10.0
        end
    end

    @testset "session_clear!" begin
        s = Friedman.Session()
        s.data_path = "test.csv"
        s.results[:var] = "fake"
        s.last_model = :var
        Friedman.session_clear!(s)
        @test s.data_path == ""
        @test isnothing(s.df)
        @test isempty(s.results)
        @test s.last_model == :none
    end

    @testset "session_store_result!" begin
        s = Friedman.Session()
        Friedman.session_store_result!(s, :var, "var_model")
        @test s.results[:var] == "var_model"
        @test s.last_model == :var
        Friedman.session_store_result!(s, :bvar, "bvar_model")
        @test s.results[:bvar] == "bvar_model"
        @test s.last_model == :bvar
        @test s.results[:var] == "var_model"
        Friedman.session_store_result!(s, :var, "var_model_v2")
        @test s.results[:var] == "var_model_v2"
        @test s.last_model == :var
    end

    @testset "session_has_data" begin
        s = Friedman.Session()
        @test !Friedman.session_has_data(s)
        s.data_path = "test.csv"
        @test Friedman.session_has_data(s)
    end

    @testset "session_get_result" begin
        s = Friedman.Session()
        @test isnothing(Friedman.session_get_result(s, :var))
        Friedman.session_store_result!(s, :var, "model")
        @test Friedman.session_get_result(s, :var) == "model"
        @test isnothing(Friedman.session_get_result(s, :bvar))
    end

    @testset "parse_data_source" begin
        @test Friedman.parse_data_source(":fred-md") == (:builtin, :fred_md)
        @test Friedman.parse_data_source(":fred-qd") == (:builtin, :fred_qd)
        @test Friedman.parse_data_source(":pwt") == (:builtin, :pwt)
        @test Friedman.parse_data_source(":mpdta") == (:builtin, :mpdta)
        @test Friedman.parse_data_source(":ddcg") == (:builtin, :ddcg)
        @test Friedman.parse_data_source("myfile.csv") == (:file, "myfile.csv")
        @test_throws Friedman.CliError Friedman.parse_data_source(":nonexistent")

        # Both separator spellings resolve — `data list`/`data load` say `fred_md`,
        # so the REPL must not reject it (regression: underscore form was an error).
        @test Friedman.parse_data_source(":fred_md") == (:builtin, :fred_md)
        @test Friedman.parse_data_source(":fred_qd") == (:builtin, :fred_qd)
        @test Friedman.parse_data_source(":FRED-MD") == (:builtin, :fred_md)
    end

    @testset "session_load_builtin!" begin
        s = Friedman.Session()
        Friedman.session_load_builtin!(s, :fred_md)
        @test s.data_path == ":fred_md"
        @test !isnothing(s.df)
        @test !isnothing(s.Y)
        @test size(s.Y) == (3, 3)
        @test s.varnames == ["INDPRO", "CPI", "FEDFUNDS"]
        @test isempty(s.results)
        @test s.last_model == :none
    end
end

@testset "REPL dispatch wrapper" begin
    @testset "inject_session_data" begin
        app = Friedman.build_app()
        s = Friedman.Session()
        s.data_path = "/tmp/test.csv"

        # Args with no data positional — inject before options
        args = ["estimate", "multivariate", "var", "--lags", "4"]
        result = Friedman.inject_session_data(s, args, app)
        @test result == ["estimate", "multivariate", "var", "/tmp/test.csv", "--lags", "4"]

        # Args already have data (a .csv path) — don't inject
        args2 = ["estimate", "multivariate", "var", "mydata.csv", "--lags", "4"]
        result2 = Friedman.inject_session_data(s, args2, app)
        @test result2 == args2

        # Extensionless positional — do not inject (tree-walk, F27)
        args_ext = ["estimate", "multivariate", "var", "mydata", "--lags", "4"]
        result_ext = Friedman.inject_session_data(s, args_ext, app)
        @test result_ext == args_ext

        # Builtin dataset token — already a positional
        args_bi = ["estimate", "multivariate", "var", ":fred-md"]
        @test Friedman.inject_session_data(s, args_bi, app) == args_bi

        # No session data — return unchanged
        s2 = Friedman.Session()
        result3 = Friedman.inject_session_data(s2, args, app)
        @test result3 == args

        # Deep nesting: dsge bayes estimate
        s3 = Friedman.Session()
        s3.data_path = "/tmp/test.csv"
        args4 = ["dsge", "bayes", "estimate", "--draws", "1000"]
        result4 = Friedman.inject_session_data(s3, args4, app)
        @test result4 == ["dsge", "bayes", "estimate", "/tmp/test.csv", "--draws", "1000"]

        # Do not inject session data when --model or --result supplies a handle
        args_mod = ["irf", "var", "--model", "v.jld2"]
        @test Friedman.inject_session_data(s, args_mod, app) == args_mod
        args_mod_eq = ["irf", "var", "--model=v.jld2"]
        @test Friedman.inject_session_data(s, args_mod_eq, app) == args_mod_eq
        args_res = ["irf", "var", "--result", "r.jld2"]
        @test Friedman.inject_session_data(s, args_res, app) == args_res

        # Even if ./var.jld2 exists in CWD, `test multivariate granger --model var` injects session data,
        # whereas `irf var --model var` treats `var` as a model handle stem and does NOT inject session data.
        mktempdir() do dir
            cd(dir) do
                write("var.jld2", "stub")
                args_gr = ["test", "multivariate", "granger", "--model", "var"]
                @test Friedman.inject_session_data(s, args_gr, app) ==
                    ["test", "multivariate", "granger", s.data_path, "--model", "var"]
                args_irf_stem = ["irf", "var", "--model", "var"]
                @test Friedman.inject_session_data(s, args_irf_stem, app) == args_irf_stem
            end
        end
    end

    @testset "detect_model_type" begin
        @test Friedman.detect_model_type(["estimate", "multivariate", "var"]) == :var
        @test Friedman.detect_model_type(["estimate", "multivariate", "bvar"]) == :bvar
        @test Friedman.detect_model_type(["irf", "var"]) == :var
        @test Friedman.detect_model_type(["test", "unit-root", "adf"]) == :adf
        @test Friedman.detect_model_type(["data", "use"]) == :use
        @test Friedman.detect_model_type(["data"]) == :none
    end

    @testset "is_estimate_command" begin
        @test Friedman.is_estimate_command(["estimate", "multivariate", "var", "d.csv"])
        @test !Friedman.is_estimate_command(["irf", "var", "d.csv"])
        @test !Friedman.is_estimate_command(["data", "use", "d.csv"])
    end
end

@testset "REPL line splitting" begin
    @test Friedman._split_repl_line("estimate multivariate var data.csv --lags 4") == ["estimate", "multivariate", "var", "data.csv", "--lags", "4"]
    @test Friedman._split_repl_line("  estimate   multivariate var  ") == ["estimate", "multivariate", "var"]
    @test Friedman._split_repl_line("data use \"my file.csv\"") == ["data", "use", "my file.csv"]
    @test Friedman._split_repl_line("") == String[]
    @test Friedman._split_repl_line("   ") == String[]
    @test Friedman._split_repl_line("help") == ["help"]
    # Unclosed quote — takes rest of line as token
    @test Friedman._split_repl_line("data use \"my file") == ["data", "use", "my file"]
end

@testset "command path tree-walk" begin
    app = Friedman.build_app()
    # Leaf depth
    _, d1 = Friedman._walk_command_path(app, ["estimate", "multivariate", "var", "data.csv"])
    @test d1 == 3
    _, d2 = Friedman._walk_command_path(app, ["dsge", "bayes", "estimate", "model.toml"])
    @test d2 == 3
    _, d3 = Friedman._walk_command_path(app, ["data", "list"])
    @test d3 == 2
    _, d0 = Friedman._walk_command_path(app, ["--help"])
    @test d0 == 0
    _, dempty = Friedman._walk_command_path(app, String[])
    @test dempty == 0
    # Path with slash / extensionless still depth 2 (positional is not a subcommand)
    _, d4 = Friedman._walk_command_path(app, ["estimate", "multivariate", "var", "/path/to/data"])
    @test d4 == 3
    _, d5 = Friedman._walk_command_path(app, ["dsge", "solve", "model.jl"])
    @test d5 == 2
    # Extensionless bare name is positional, not a third subcommand
    leaf, d6 = Friedman._walk_command_path(app, ["estimate", "multivariate", "var", "mydata"])
    @test d6 == 3
    @test leaf isa Friedman.LeafCommand
end

@testset "_complete_leaf_options" begin
    app = Friedman.build_app()
    var_leaf = app.root.subcmds["estimate"].subcmds["multivariate"].subcmds["var"]
    # Option prefix matching
    completions = Friedman._complete_leaf_options(var_leaf, "--la")
    @test "--lags" in completions
    # Flag prefix matching
    completions2 = Friedman._complete_leaf_options(var_leaf, "--pl")
    @test "--plot" in completions2
    # Non-option prefix returns empty
    @test isempty(Friedman._complete_leaf_options(var_leaf, "data"))
end

@testset "repl_dispatch" begin
    @testset "data use (file)" begin
        s = Friedman.Session()
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "x,y")
            println(io, "1.0,2.0")
            println(io, "3.0,4.0")
        end
        Friedman.session_load_data!(s, tmpfile)
        @test s.data_path == tmpfile
        @test s.varnames == ["x", "y"]
        rm(tmpfile; force=true)
    end

    @testset "data current with no data" begin
        s = Friedman.Session()
        @test !Friedman.session_has_data(s)
    end

    @testset "data clear" begin
        s = Friedman.Session()
        s.data_path = "test.csv"
        s.results[:var] = "model"
        Friedman.session_clear!(s)
        @test !Friedman.session_has_data(s)
        @test isempty(s.results)
    end

    @testset "exit/quit throws InterruptException" begin
        app = Friedman.build_app()
        s = Friedman.Session()
        @test_throws InterruptException Friedman.repl_dispatch(s, app, ["exit"])
        @test_throws InterruptException Friedman.repl_dispatch(s, app, ["quit"])
    end

    @testset "empty args is no-op" begin
        app = Friedman.build_app()
        s = Friedman.Session()
        # Should return without error
        Friedman.repl_dispatch(s, app, String[])
    end

    @testset "data use loads file via repl_dispatch" begin
        s = Friedman.Session()
        app = Friedman.build_app()
        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "a,b")
            println(io, "1.0,2.0")
            println(io, "3.0,4.0")
        end
        Friedman.repl_dispatch(s, app, ["data", "use", tmpfile])
        @test s.data_path == tmpfile
        @test s.varnames == ["a", "b"]
        @test size(s.Y) == (2, 2)
        rm(tmpfile; force=true)
    end

    @testset "data use loads builtin via repl_dispatch" begin
        s = Friedman.Session()
        app = Friedman.build_app()
        Friedman.repl_dispatch(s, app, ["data", "use", ":fred-md"])
        @test s.data_path == ":fred_md"
        @test s.varnames == ["INDPRO", "CPI", "FEDFUNDS"]
    end

    @testset "data current output" begin
        s = Friedman.Session()
        app = Friedman.build_app()
        # No data — prints "No data loaded"
        output = let (tmppath, tmpio) = mktemp()
            try
                redirect_stdout(tmpio) do
                    Friedman.repl_dispatch(s, app, ["data", "current"])
                end
                close(tmpio)
                read(tmppath, String)
            finally
                try; close(tmpio); catch; end
                try; rm(tmppath; force=true); catch; end
            end
        end
        @test contains(output, "No data loaded")

        # With data
        Friedman.session_load_builtin!(s, :fred_md)
        output2 = let (tmppath, tmpio) = mktemp()
            try
                redirect_stdout(tmpio) do
                    Friedman.repl_dispatch(s, app, ["data", "current"])
                end
                close(tmpio)
                read(tmppath, String)
            finally
                try; close(tmpio); catch; end
                try; rm(tmppath; force=true); catch; end
            end
        end
        @test contains(output2, ":fred_md")
        @test contains(output2, "3×3")
    end

    @testset "data clear via repl_dispatch" begin
        s = Friedman.Session()
        app = Friedman.build_app()
        Friedman.session_load_builtin!(s, :fred_md)
        @test Friedman.session_has_data(s)
        Friedman.repl_dispatch(s, app, ["data", "clear"])
        @test !Friedman.session_has_data(s)
    end

    @testset "functions are defined" begin
        @test hasmethod(Friedman.repl_dispatch, Tuple{Friedman.Session, Friedman.Entry, Vector{String}})
        @test hasmethod(Friedman.start_repl, Tuple{})
        @test hasmethod(Friedman._split_repl_line, Tuple{String})
    end

    @testset "REPL result capture" begin
        s = Friedman.Session()
        s.data_path = "/tmp/test.csv"  # pretend data is loaded
        app = Friedman.build_app()

        # Simulate estimate multivariate var dispatch
        Friedman.repl_dispatch(s, app, ["estimate", "multivariate", "var", "data.csv"])
        @test Friedman.session_get_result(s, :var) == "mock_var_model"
        @test s.last_model == :var

        # Non-estimate command should not cache
        Friedman.repl_dispatch(s, app, ["irf", "var", "data.csv"])
        @test s.last_model == :var  # unchanged
    end
end

@testset "REPL model injection" begin
    @testset "is_downstream_command" begin
        @test Friedman.is_downstream_command(["irf", "var"])
        @test Friedman.is_downstream_command(["fevd", "bvar"])
        @test Friedman.is_downstream_command(["hd", "var"])
        @test Friedman.is_downstream_command(["forecast", "multivariate", "var"])
        @test Friedman.is_downstream_command(["predict", "multivariate", "var"])
        @test Friedman.is_downstream_command(["residuals", "multivariate", "var"])
        @test !Friedman.is_downstream_command(["estimate", "multivariate", "var"])
        @test !Friedman.is_downstream_command(["test", "unit-root", "adf"])
        @test !Friedman.is_downstream_command(["data", "use"])
    end

    @testset "model injection into downstream dispatch" begin
        s = Friedman.Session()
        s.data_path = "/tmp/test.csv"
        app = Friedman.build_app()

        # First estimate to cache a result
        Friedman.repl_dispatch(s, app, ["estimate", "multivariate", "var", "data.csv"])
        @test Friedman.session_get_result(s, :var) == "mock_var_model"

        # Now run downstream without explicit <data> — should inject cached model
        Friedman._last_injected_model = nothing
        Friedman.repl_dispatch(s, app, ["irf", "var"])
        @test Friedman._last_injected_model == "mock_var_model"
        @test Friedman._last_dispatched_args == ["irf", "var"]

        # Explicit <data>, --model, --result, or re-estimation flags must NOT inject cached model (#253)
        for override_args in (
            ["irf", "var", "other.csv"],
            ["irf", "var", "--model", "other.jld2"],
            ["irf", "var", "--result", "res.jld2"],
            ["irf", "var", "--lags", "3"],
            ["irf", "var", "-p", "3"],
        )
            Friedman._last_injected_model = nothing
            Friedman.repl_dispatch(s, app, override_args)
            @test Friedman._last_injected_model === nothing
        end

        # Downstream-only options (--horizons, --id/--config, --format) still inject cached model (#253)
        Friedman._last_injected_model = nothing
        Friedman.repl_dispatch(s, app, ["irf", "var", "--horizons", "8", "--id", "sign", "--config", "s.toml", "--format", "json"])
        @test Friedman._last_injected_model == "mock_var_model"
        @test !("/tmp/test.csv" in Friedman._last_dispatched_args)
    end

    @testset "leading global flags in REPL (#253)" begin
        s = Friedman.Session()
        s.data_path = "/tmp/test.csv"
        app = Friedman.build_app()
        Friedman._QUIET[] = false
        Friedman._SEED[] = nothing

        Friedman.repl_dispatch(s, app, ["--seed", "42", "--quiet", "--json", "estimate", "multivariate", "var", "data.csv"])
        @test Friedman.session_get_result(s, :var) == "mock_var_model"
        @test Friedman._last_seen_seed == 42
        @test Friedman._last_seen_quiet == true
        @test "--format" in Friedman._last_dispatched_args && "json" in Friedman._last_dispatched_args
        # Global flag state must NOT leak to subsequent REPL lines
        @test Friedman._QUIET[] == false
        @test Friedman._SEED[] === nothing
    end
end

import REPL

mutable struct _ReplFakeTerminal <: REPL.Terminals.UnixTerminal
    in_stream::IO
    out_stream::IO
    err_stream::IO
    hascolor::Bool
    raw::Bool
    _ReplFakeTerminal(stdin::IO, stdout::IO, stderr::IO, hascolor::Bool=false) =
        new(stdin, stdout, stderr, hascolor, false)
end
REPL.Terminals.hascolor(t::_ReplFakeTerminal) = t.hascolor
REPL.Terminals.raw!(t::_ReplFakeTerminal, raw::Bool) = (t.raw = raw)
REPL.Terminals.size(t::_ReplFakeTerminal) = (24, 80)

# Regression guard: must run BEFORE any prior call to `_init_completion_provider()`
# so `_init_completion_provider()` and `Base.invokelatest` run in the same frame/world age.
function _exercise_first_lineedit_init(app, s, idx, term, hist_path)
    Friedman._init_completion_provider()
    try
        Base.invokelatest(Friedman._make_tty_terminal)
    catch
    end
    return Base.invokelatest(Friedman._run_lineedit_repl, app, s, idx; term=term, histfile=hist_path)
end

@testset "LineEdit world-age single-frame initialization (no binding warnings)" begin
    mktempdir() do dir
        app = Friedman.build_app()
        idx = Friedman._reset_completion_index!(app)
        s = Friedman.Session()
        term = _ReplFakeTerminal(IOBuffer("data use :denmark\rexit\r"), IOBuffer(), IOBuffer())
        hist_path = joinpath(dir, ".friedman_history")

        out_path, out_io = mktemp()
        err_path, err_io = mktemp()
        err_txt = ""
        try
            redirect_stdio(; stdout=out_io, stderr=err_io) do
                _exercise_first_lineedit_init(app, s, idx, term, hist_path)
            end
            close(out_io)
            close(err_io)
            err_txt = read(err_path, String)
        finally
            try; close(out_io); catch; end
            try; close(err_io); catch; end
            rm(out_path; force=true)
            rm(err_path; force=true)
        end
        @test !occursin("Detected access to binding", err_txt)
        @test !occursin("WARNING:", err_txt)
        @test s.data_path == ":denmark"
        @test s.varnames == ["LRM", "LRY", "LPY", "IBO", "IDE"]
    end
end

@testset "Tab completion" begin
    app = Friedman.build_app()

    @testset "top-level completions" begin
        completions = Friedman.complete_command(app, "est")
        @test "estimate" in completions
        @test !("irf" in completions)
    end

    @testset "subcommand completions" begin
        # Family node, then the model token under it.
        completions = Friedman.complete_command(app, "estimate m")
        @test "multivariate" in completions
        @test !("vecm" in completions)
        @test !("bvar" in completions)
        nested = Friedman.complete_command(app, "estimate multivariate v")
        @test "var" in nested
        @test "vecm" in nested
        @test !("bvar" in nested)
    end

    @testset "option completions" begin
        completions = Friedman.complete_command(app, "estimate multivariate var --la")
        @test "--lags" in completions
    end

    @testset "empty input returns all top-level" begin
        completions = Friedman.complete_command(app, "")
        @test "estimate" in completions
        @test "irf" in completions
    end

    @testset "unknown command returns empty" begin
        completions = Friedman.complete_command(app, "nonexistent sub")
        @test isempty(completions)
    end

    @testset "trailing-space completions (#228)" begin
        # Trailing space after node name completes child subcommands
        kids = Friedman.complete_command(app, "estimate ")
        @test kids == ["multivariate"]
        subkids = Friedman.complete_command(app, "estimate multivariate ")
        @test Set(subkids) == Set(["var", "bvar", "vecm"])
        # Trailing space after leaf name completes leaf options
        leaf_opts = Friedman.complete_command(app, "estimate multivariate var ")
        @test "--lags" in leaf_opts
        @test "--format" in leaf_opts
        @test "--plot" in leaf_opts
        # Option completion after a positional argument
        after_pos = Friedman.complete_command(
            app, "estimate multivariate var data.csv --la",
        )
        @test after_pos == ["--lags"]
    end

    @testset "REPL stdlib UUID and LineEdit completion provider (#228)" begin
        @test Friedman._REPL_PKG_ID.uuid ==
            Base.UUID("3fa0cd96-eef1-5676-8a61-b3b8758bbffb")
        @test Friedman._init_completion_provider() === nothing
        @test isdefined(Friedman, :FriedmanCompletionProvider)
    end
end

@testset "REPL readline loop & CSI handling (#228)" begin
    app = Friedman.build_app()

    @testset "piped stdin EOF exits cleanly without spinning" begin
        s = Friedman.Session()
        inp = IOBuffer("estimate multivariate var data.csv\n")
        out = IOBuffer()
        err = IOBuffer()
        Friedman._repl_readline_loop(app, s; input=inp, output=out, err=err)
        @test s.results[:var] == "mock_var_model"
        @test occursin("Goodbye!", String(take!(out)))
        @test isempty(take!(err))
    end

    @testset "bare CSI arrow sequences are stripped in readline fallback" begin
        s = Friedman.Session()
        inp = IOBuffer("\e[A\e[B\e[C\e[Destimate multivariate var data.csv\nexit\n")
        out = IOBuffer()
        err = IOBuffer()
        Friedman._repl_readline_loop(app, s; input=inp, output=out, err=err)
        @test s.results[:var] == "mock_var_model"
        @test isempty(take!(err))
    end
end

@testset "REPL integration" begin
    @testset "data use → estimate → irf workflow" begin
        s = Friedman.Session()

        tmpfile = tempname() * ".csv"
        open(tmpfile, "w") do io
            println(io, "x,y,z")
            for i in 1:50
                println(io, "$(rand()),$(rand()),$(rand())")
            end
        end

        Friedman.session_load_data!(s, tmpfile)
        @test Friedman.session_has_data(s)

        # Simulate estimate → store
        Friedman.session_store_result!(s, :var, "mock_var_model")
        @test Friedman.session_get_result(s, :var) == "mock_var_model"
        @test s.last_model == :var

        # Simulate second estimate
        Friedman.session_store_result!(s, :bvar, "mock_bvar_model")
        @test s.last_model == :bvar
        @test Friedman.session_get_result(s, :var) == "mock_var_model"  # still cached

        # Data change clears results
        Friedman.session_load_data!(s, tmpfile)
        @test isempty(s.results)
        @test s.last_model == :none

        rm(tmpfile; force=true)
    end

    @testset "data injection into args" begin
        app = Friedman.build_app()
        s = Friedman.Session()
        s.data_path = "/tmp/macro.csv"
        s.Y = zeros(10, 3)
        s.varnames = ["a", "b", "c"]

        # estimate multivariate var --lags 4 → estimate multivariate var /tmp/macro.csv --lags 4
        injected = Friedman.inject_session_data(s, ["estimate", "multivariate", "var", "--lags", "4"], app)
        @test injected[4] == "/tmp/macro.csv"

        # dsge solve model.toml → unchanged (has positional)
        unchanged = Friedman.inject_session_data(s, ["dsge", "solve", "model.toml"], app)
        @test unchanged == ["dsge", "solve", "model.toml"]

        # Extensionless file already provided — unchanged (tree-walk, not extension sniff)
        bare = Friedman.inject_session_data(s, ["estimate", "multivariate", "var", "panel_data"], app)
        @test bare == ["estimate", "multivariate", "var", "panel_data"]
    end

    @testset "builtin dataset workflow" begin
        s = Friedman.Session()
        Friedman.session_load_builtin!(s, :fred_md)
        @test s.data_path == ":fred_md"
        @test !isnothing(s.Y)

        # Store result
        Friedman.session_store_result!(s, :var, "var_on_fred")
        @test s.results[:var] == "var_on_fred"

        # Load different builtin clears results
        Friedman.session_load_builtin!(s, :pwt)
        @test s.data_path == ":pwt"
        @test isempty(s.results)
    end

    @testset "full dispatch cycle" begin
        s = Friedman.Session()
        s.data_path = "/tmp/test.csv"
        app = Friedman.build_app()

        # Estimate caches result
        Friedman.repl_dispatch(s, app, ["estimate", "multivariate", "var", "data.csv"])
        @test s.results[:var] == "mock_var_model"
        @test s.last_model == :var

        # Downstream (without explicit <data> override) gets cached model injected
        Friedman._last_injected_model = nothing
        Friedman.repl_dispatch(s, app, ["irf", "var"])
        @test Friedman._last_injected_model == "mock_var_model"

        # Clear resets everything
        Friedman.session_clear!(s)
        @test !Friedman.session_has_data(s)
        @test isempty(s.results)
    end
end

@testset "LineEdit arrow-key history, editing, completion & persistence (#241, #247)" begin
    @testset "_resolve_histfile env & defaults" begin
        withenv("FRDC_HISTFILE" => nothing, "FRIEDMAN_HISTFILE" => nothing, "FRIEDMAN_HISTORY_FILE" => nothing) do
            @test Friedman._resolve_histfile() == joinpath(Friedman._expanduser("~"), ".frdc_history")
        end
        withenv("FRDC_HISTFILE" => "~/custom_frdc_hist", "FRIEDMAN_HISTFILE" => "~/ignored_legacy") do
            @test Friedman._resolve_histfile() == joinpath(Friedman._expanduser("~"), "custom_frdc_hist")
        end
        withenv("FRDC_HISTFILE" => nothing, "FRIEDMAN_HISTFILE" => "~/custom_friedman_hist") do
            @test Friedman._resolve_histfile() == joinpath(Friedman._expanduser("~"), "custom_friedman_hist")
        end
        for disabled in ("", "none", "NONE", "off")
            withenv("FRDC_HISTFILE" => disabled, "FRIEDMAN_HISTFILE" => nothing) do
                @test Friedman._resolve_histfile() == ""
            end
        end
    end

    @testset "FriedmanCompletionProvider Julia 1.13 complete_line & inline hints (#247)" begin
        app = Friedman.build_app()
        idx = Friedman._reset_completion_index!(app)
        Friedman._init_completion_provider()
        prov = Friedman.FriedmanCompletionProvider(app, idx)

        panel = REPL.LineEdit.Prompt("frdc> "; complete=prov)
        term = _ReplFakeTerminal(IOBuffer(""), IOBuffer(), IOBuffer())
        pstate = REPL.LineEdit.init_state(term, panel)

        # Partial command at end of buffer: both Tab (hint=false) and inline ghost hint (hint=true)
        write(pstate.input_buffer, "est")
        comps_tab, reg_tab, ok_tab = REPL.LineEdit.complete_line_named(prov, pstate, Main; hint=false)
        @test ok_tab
        @test [c.completion for c in comps_tab] == ["estimate"]
        @test reg_tab == (0 => 3)
        @test String(copy(pstate.input_buffer.data[1:position(pstate.input_buffer)])) == "est"

        comps_hint, reg_hint, ok_hint = REPL.LineEdit.complete_line_named(prov, pstate, Main; hint=true)
        @test ok_hint
        @test [c.completion for c in comps_hint] == ["estimate"]
        @test reg_hint == (0 => 3)

        # Mid-line cursor: buffer has "est --lags 4" with cursor right after "est" (pos 3)
        truncate(pstate.input_buffer, 0)
        write(pstate.input_buffer, "est --lags 4")
        seek(pstate.input_buffer, 3)
        comps_mid, reg_mid, ok_mid = REPL.LineEdit.complete_line_named(prov, pstate, Main; hint=false)
        @test ok_mid
        @test [c.completion for c in comps_mid] == ["estimate"]
        @test reg_mid == (0 => 3)
    end

    @testset "Up/Down arrow recall, Left/Right editing, Tab completion & cross-session history (#241)" begin
        mktempdir() do dir
            hist_path = joinpath(dir, ".friedman_history")
            app = Friedman.build_app()
            idx = Friedman._reset_completion_index!(app)
            Friedman._init_completion_provider()

            # Session 1:
            # 1) "data use :fred_md\r" -> loads :fred_md
            # 2) "estimate multivariate bvar\r" -> caches :bvar
            # 3) Up twice ("\e[A\e[A") -> "data use :fred_md", Down once ("\e[B") -> "estimate multivariate bvar"
            #    Left 4 ("\e[D"^4) puts cursor before 'b', Right 1 ("\e[C") puts cursor after 'b',
            #    Backspace ("\x7f") deletes 'b' -> "estimate multivariate var", Enter ("\r") -> caches :var!
            # 4) "irf \t\r" -> Tab completes sole child "var", Enter dispatches "irf var" using cached :var model!
            # 5) Ctrl-D ("\x04") -> clean EOF exit (so last persisted history entry is "irf var")
            s1 = Friedman.Session()
            keys1 = string(
                "data use :fred_md\r",
                "estimate multivariate bvar\r",
                "\e[A\e[A\e[B",
                "\e[D\e[D\e[D\e[D\e[C\x7f\r",
                "irf \t\r",
                "\x04",
            )
            out1 = IOBuffer()
            err1 = IOBuffer()
            term1 = _ReplFakeTerminal(IOBuffer(keys1), out1, err1)
            Friedman._last_injected_model = nothing
            Base.invokelatest(Friedman._run_lineedit_repl, app, s1, idx; term=term1, histfile=hist_path)

            @test s1.data_path == ":fred_md"
            @test s1.results[:bvar] == "mock_bvar_model"
            @test s1.results[:var] == "mock_var_model"
            @test Friedman._last_injected_model == "mock_var_model"
            @test isfile(hist_path)
            hist_disk = read(hist_path, String)
            @test occursin("# mode: frdc", hist_disk)
            @test occursin("\tdata use :fred_md", hist_disk)
            @test occursin("\testimate multivariate var", hist_disk)

            # Session 2 (fresh Session, same histfile):
            # - Prefix-filtered Up arrow: type "data " + "\e[A\r" -> recalls "data use :fred_md" from disk!
            # - Plain Up arrow from Session 1's history: "\e[A\e[A\r" -> recalls "estimate multivariate var"
            # - "exit\r" -> terminates cleanly
            s2 = Friedman.Session()
            keys2 = string(
                "data \e[A\r",
                "\e[A\e[A\e[A\r",
                "exit\r",
            )
            out2 = IOBuffer()
            err2 = IOBuffer()
            term2 = _ReplFakeTerminal(IOBuffer(keys2), out2, err2)
            Base.invokelatest(Friedman._run_lineedit_repl, app, s2, idx; term=term2, histfile=hist_path)

            @test s2.data_path == ":fred_md"
            @test haskey(s2.results, :var)

            # Unwritable histfile (directory path) degrades gracefully to in-memory history without crashing
            s3 = Friedman.Session()
            term3 = _ReplFakeTerminal(IOBuffer("data use :pwt\r\e[A\r\x04"), IOBuffer(), IOBuffer())
            Base.invokelatest(Friedman._run_lineedit_repl, app, s3, idx; term=term3, histfile=dir)
            @test s3.data_path == ":pwt"
        end
    end
end

@testset "v1.0.6 REPL quoting, built-ins, completions & history fallback (#279)" begin
    app = Friedman.build_app()

    @testset "_split_repl_line single quotes & UTF-8" begin
        @test Friedman._split_repl_line("data use 'my dir/data file.csv'") == ["data", "use", "my dir/data file.csv"]
        @test Friedman._split_repl_line("data use \"régime μ/café.csv\" --json") == ["data", "use", "régime μ/café.csv", "--json"]
        @test Friedman._split_repl_line("data use 'it\"s ok'") == ["data", "use", "it\"s ok"]
    end

    @testset "bare data use / --help / --json / --quiet built-ins" begin
        s = Friedman.Session()
        out = IOBuffer()
        err = IOBuffer()
        # Bare `data use` throws usage/missing-arg (or emits error envelope under --json) without mutating session;
        # `data use --help` prints usage text cleanly.
        Friedman.session_load_builtin!(s, :denmark)
        @test_throws Friedman.CliError Friedman.repl_dispatch(s, app, ["data", "use"]; output=out, err=err)
        @test s.data_path == ":denmark"

        out_bare_json = IOBuffer()
        Friedman.repl_dispatch(s, app, ["data", "use", "--json"]; output=out_bare_json, err=err)
        dbj = JSON3.read(String(take!(out_bare_json)))
        @test String(dbj.status) == "error" && String(dbj.error.code) == "usage/missing-arg"
        @test s.data_path == ":denmark"

        out_h = IOBuffer()
        Friedman.repl_dispatch(s, app, ["data", "use", "--help"]; output=out_h, err=err)
        @test occursin("usage: data use", String(take!(out_h)))
        @test s.data_path == ":denmark"

        # --json & --quiet on data use / current / clear
        out_u = IOBuffer(); err_u = IOBuffer()
        Friedman.repl_dispatch(s, app, ["data", "use", ":fred_md", "--json", "--quiet"]; output=out_u, err=err_u)
        @test isempty(String(take!(err_u)))
        du = JSON3.read(String(take!(out_u)))
        @test String(du.status) == "ok" && String(du.command) == "frdc data use"

        out_c = IOBuffer(); err_c = IOBuffer()
        Friedman.repl_dispatch(s, app, ["data", "current", "--json"]; output=out_c, err=err_c)
        dc = JSON3.read(String(take!(out_c)))
        @test String(dc.command) == "frdc data current" && String(dc.status) == "ok"

        out_cl = IOBuffer(); err_cl = IOBuffer()
        Friedman.repl_dispatch(s, app, ["data", "clear", "--json"]; output=out_cl, err=err_cl)
        dcl = JSON3.read(String(take!(out_cl)))
        @test String(dcl.command) == "frdc data clear" && !Friedman.session_has_data(s)
    end

    @testset "REPL completions (exit/quit/data/:datasets/paths) & FRIEDMAN_HISTORY_FILE" begin
        top = Friedman.complete_command(app, "")
        @test "exit" in top && "quit" in top
        data_kids = Friedman.complete_command(app, "data ")
        @test "use" in data_kids && "current" in data_kids && "clear" in data_kids
        ds = Friedman.complete_command(app, "data use :fr")
        @test ":fred_md" in ds && ":fred_qd" in ds
        @test "--lags" in Friedman.complete_command(app, "estimate multivariate var ")

        mktempdir() do dir
            write(joinpath(dir, "macro_demo.csv"), "a,b\n1,2\n")
            cd(dir) do
                cands = Friedman.complete_command(app, "data use mac")
                @test "macro_demo.csv" in cands
            end
        end

        withenv("FRDC_HISTFILE" => nothing, "FRIEDMAN_HISTFILE" => nothing, "FRIEDMAN_HISTORY_FILE" => "/tmp/custom_hist_279") do
            @test Friedman._resolve_histfile() == "/tmp/custom_hist_279"
        end
    end

    @testset "REPL --digits & --compact state isolation ([DISPLAY-W1] #323)" begin
        s = Friedman.Session()
        @test Friedman._repl_positional_args(["data", "use", "--digits", "6", ":denmark"], 3) == [":denmark"]
        @test Friedman._repl_positional_args(["data", "use", "--digits=full", "--compact", ":denmark"], 3) == [":denmark"]
        prev_d = Friedman._DISPLAY_DIGITS[]
        prev_c = Friedman._COMPACT[]
        out_io = IOBuffer(); err_io = IOBuffer()
        Friedman.repl_dispatch(s, app, ["--digits", "6", "--compact", "data", "use", ":denmark"]; output=out_io, err=err_io)
        @test Friedman._DISPLAY_DIGITS[] == prev_d
        @test Friedman._COMPACT[] == prev_c
        @test s.data_path == ":denmark"
    end
end
