# Tests for build_app() and main() from src/Friedman.jl
# Included from runtests.jl after test_commands.jl and test_repl.jl
# All register_*_commands!() and CLI types are available at top level.
# Re-include dispatch engine to match the re-defined types from test_commands.jl.

using Test

let project_root = dirname(@__DIR__)
    include(joinpath(project_root, "src", "cli", "parser.jl"))
    include(joinpath(project_root, "src", "cli", "help.jl"))
    include(joinpath(project_root, "src", "cli", "dispatch.jl"))
end

const FRIEDMAN_VERSION = v"0.4.2"

# Stub start_repl to avoid launching interactive REPL in tests
function start_repl()
    println("REPL started (stub)")
end

"""
    build_app() -> Entry

Construct the full CLI command tree (mirrors src/Friedman.jl).
"""
function build_app()
    root_cmds = Dict{String,Union{NodeCommand,LeafCommand}}(
        "estimate" => register_estimate_commands!(),
        "test"     => register_test_commands!(),
        "irf"      => register_irf_commands!(),
        "fevd"     => register_fevd_commands!(),
        "hd"       => register_hd_commands!(),
        "forecast"  => register_forecast_commands!(),
        "predict"   => register_predict_commands!(),
        "residuals" => register_residuals_commands!(),
        "filter"    => register_filter_commands!(),
        "data"      => register_data_commands!(),
        "nowcast"   => register_nowcast_commands!(),
        "dsge"      => register_dsge_commands!(),
        "did"       => register_did_commands!(),
        "spectral"  => register_spectral_commands!(),
    )

    root = NodeCommand("friedman", root_cmds,
        "A macroeconometric analysis toolkit powered by MacroEconometricModels.jl")

    return Entry("friedman", root; version=FRIEDMAN_VERSION)
end

"""
    run_cli(args)::Cint

Single entry shared by main/julia_main (mirrors src/Friedman.jl).
"""
function run_cli(args::Vector{String})::Cint
    # Launch REPL if "repl" is the first argument
    if !isempty(args) && args[1] == "repl"
        start_repl()
        return Cint(0)
    end

    app = build_app()
    try
        dispatch(app, args)
        return Cint(0)
    catch e
        printstyled(stderr, "Error: "; bold=true, color=:red)
        if e isa ParseError || e isa DispatchError
            println(stderr, e.message)
        else
            println(stderr, sprint(showerror, e))
        end
        return Cint(1)
    end
end

"""
    main(args)

Entry point (mirrors src/Friedman.jl). Dispatches CLI commands.
"""
function main(args::Vector{String}=ARGS)
    code = run_cli(args)
    code == 0 || exit(Int(code))
    return nothing
end

julia_main()::Cint = run_cli(ARGS)

@testset "build_app and main" begin

    @testset "build_app returns valid Entry" begin
        app = build_app()
        @test app isa Entry
        @test app.name == "friedman"
        @test app.version == FRIEDMAN_VERSION
        @test app.root isa NodeCommand
    end

    @testset "build_app has all 14 top-level commands" begin
        app = build_app()
        expected = ["estimate", "test", "irf", "fevd", "hd", "forecast",
                     "predict", "residuals", "filter", "data", "nowcast",
                     "dsge", "did", "spectral"]
        for cmd in expected
            @test haskey(app.root.subcmds, cmd)
        end
        @test length(app.root.subcmds) == 14
    end

    @testset "build_app commands are correct types" begin
        app = build_app()
        for (name, cmd) in app.root.subcmds
            @test cmd isa NodeCommand
        end
    end

    @testset "main --version" begin
        out = _capture() do
            main(["--version"])
        end
        @test contains(out, string(FRIEDMAN_VERSION))
    end

    @testset "main --help" begin
        out = _capture() do
            main(["--help"])
        end
        @test contains(out, "friedman")
        @test contains(out, "estimate")
        @test contains(out, "test")
    end

    @testset "main with no args shows help" begin
        out = _capture() do
            main(String[])
        end
        @test contains(out, "friedman")
        @test contains(out, "Commands")
    end

    @testset "main --warranty" begin
        out = _capture() do
            main(["--warranty"])
        end
        @test contains(out, "WARRANTY")
    end

    @testset "main --conditions" begin
        out = _capture() do
            main(["--conditions"])
        end
        @test contains(lowercase(out), "convey") || contains(lowercase(out), "distribute")
    end

    @testset "main repl calls start_repl" begin
        out = _capture() do
            main(["repl"])
        end
        @test contains(out, "REPL started")
    end

    @testset "FRIEDMAN_VERSION is a VersionNumber" begin
        @test FRIEDMAN_VERSION isa VersionNumber
    end

    @testset "run_cli exit codes (interim contract)" begin
        out = _capture() do
            @test run_cli(["--version"]) == 0
        end
        @test contains(out, string(FRIEDMAN_VERSION))
        # DispatchError → 1, single stderr line, no stack trace, no exit()
        @test run_cli(["definitely-not-a-command"]) == 1
        # Handler error() (file not found) → 1 instead of an uncaught throw
        @test run_cli(["estimate", "var", "/nonexistent/file.csv"]) == 1
    end
end
