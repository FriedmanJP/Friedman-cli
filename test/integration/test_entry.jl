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

    @testset "pre-dispatch globals are leading-only (#117)" begin
        # Mid-argv, --warranty/--conditions/--version are ordinary (unknown)
        # tokens for the leaf/node parser → usage error, exit 2. The old
        # whole-argv match printed the GPL notice / version and exited 0
        # WITHOUT running the command — a leaf option of the same name was
        # silently swallowed (`io download --version` shipped dead this way).
        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                @test Int(Friedman.run_cli(["estimate", "var", "nofile.csv", "--warranty"])) == 2
                @test Int(Friedman.run_cli(["estimate", "var", "nofile.csv", "--conditions"])) == 2
                @test Int(Friedman.run_cli(["estimate", "var", "nofile.csv", "--version"])) == 2
                @test Int(Friedman.run_cli(["estimate", "--warranty"])) == 2
                # Leading position still works.
                @test Int(Friedman.run_cli(["--warranty"])) == 0
                @test Int(Friedman.run_cli(["--conditions"])) == 0
                # -h is help EVERYWHERE — the 48 `short="h"` horizon shorts were
                # unreachable (help fires before tokenization) and are removed;
                # the registry guard refuses any future reserved name/short.
                @test Int(Friedman.run_cli(["fevd", "var", "-h"])) == 0
                @test_throws ErrorException Friedman._to_option(
                    Friedman.OptionSpec(name="x", short="h", type=Int, default=1, description=""))
            end
        end
    end

    @testset "MEMs logging routing (#348 / C050)" begin
        # Not quiet: @info and @warn both surface.
        Friedman._QUIET[] = false
        buf = IOBuffer()
        Base.CoreLogging.with_logger(Friedman._mems_logger(buf)) do
            @info "info-line-marker"
            @warn "warn-line-marker"
        end
        verbose = String(take!(buf))
        @test occursin("info-line-marker", verbose)
        @test occursin("warn-line-marker", verbose)

        # Quiet: @info dropped, @warn kept (@error would also survive).
        Friedman._QUIET[] = true
        qbuf = IOBuffer()
        Base.CoreLogging.with_logger(Friedman._mems_logger(qbuf)) do
            @info "info-line-marker"
            @warn "warn-line-marker"
        end
        quiet = String(take!(qbuf))
        Friedman._QUIET[] = false
        @test !occursin("info-line-marker", quiet)
        @test occursin("warn-line-marker", quiet)
    end
end
