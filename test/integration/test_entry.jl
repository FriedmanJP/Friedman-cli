# Real Friedman entry-point coverage (TS-11 / C036) — replaces test/test_main.jl mirror.
# Loaded from integration suite (has real MEMs + using Friedman).

using Test
using Friedman

@testset "real entry points (build_app / run_cli)" begin
    @testset "build_app tree" begin
        app = Friedman.build_app()
        @test app isa Friedman.Entry
        @test app.name == "friedman"
        @test app.version == Friedman.FRIEDMAN_VERSION
        expected = ["estimate", "test", "irf", "fevd", "hd", "forecast",
                    "predict", "residuals", "filter", "data", "nowcast",
                    "dsge", "did", "spectral", "schema", "model", "completions"]
        for cmd in expected
            @test haskey(app.root.subcmds, cmd)
        end
        for (_, cmd) in app.root.subcmds
            @test cmd isa Friedman.NodeCommand || cmd isa Friedman.LeafCommand
        end
    end

    @testset "run_cli --version / --help" begin
        mktemp() do path, io
            code = Ref(Cint(-1))
            redirect_stdout(io) do
                redirect_stderr(devnull) do
                    code[] = Friedman.run_cli(["--version"])
                end
            end
            flush(io)
            @test Int(code[]) == 0
            @test occursin(string(Friedman.FRIEDMAN_VERSION), read(path, String))
        end
        mktemp() do path, io
            code = Ref(Cint(-1))
            redirect_stdout(io) do
                redirect_stderr(devnull) do
                    code[] = Friedman.run_cli(["--help"])
                end
            end
            flush(io)
            out = read(path, String)
            @test Int(code[]) == 0
            @test occursin("estimate", out)
        end
    end

    @testset "run_cli exit classes" begin
        # usage
        @test Int(Friedman.run_cli(["definitely-not-a-command"])) == 2
        # data
        @test Int(Friedman.run_cli(["estimate", "var", "/nonexistent/file.csv"])) == 3
    end
end
