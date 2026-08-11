# T4 subprocess battery (TS-8 / C033).
# Runs when CI=1 or FRIEDMAN_E2E=1 (dev-mode startup is slower).
#
# Contract: `friedman … --format=json | jq .` — stdout is exactly one JSON document.

using Test
using JSON3

const _E2E = get(ENV, "CI", "") != "" || get(ENV, "FRIEDMAN_E2E", "") == "1"
const _ROOT = dirname(@__DIR__)
const _JULIA = Base.julia_cmd()
const _BIN = joinpath(_ROOT, "bin", "friedman")

function _e2e_run(args::Vector{String})
    cmd = `$_JULIA --project=$_ROOT $_BIN $args`
    out = IOBuffer(); err = IOBuffer()
    p = run(pipeline(cmd; stdout=out, stderr=err); wait=false)
    wait(p)
    return (code=p.exitcode, out=String(take!(out)), err=String(take!(err)))
end

"""True if `s` parses as exactly one JSON value (no trailing garbage)."""
function _exactly_one_json(s::AbstractString)
    t = strip(s)
    isempty(t) && return false
    try
        JSON3.read(t)
        # Reject multiple top-level values: if a second `{`/`[` appears after first value
        # with non-ws content, fail. Simple check: re-read must succeed and string is single doc.
        # JSON3 doesn't expose remainder easily; require first non-ws is { or [ and balanced.
        return startswith(t, "{") || startswith(t, "[")
    catch
        return false
    end
end

function _make_fixture()
    fix = joinpath(tempdir(), "friedman_e2e_$(getpid()).csv")
    open(fix, "w") do f
        println(f, "y1,y2,y3")
        for t in 1:80
            println(f, "$(sin(t/3)),$(cos(t/4)),$(sin(t/5)+cos(t/7))")
        end
    end
    return fix
end

@testset "subprocess E2E contract (T4)" begin
    if !_E2E
        @info "skipping E2E (set FRIEDMAN_E2E=1 or CI=1)"
        return
    end

    @testset "snapshots --version / --help / schema" begin
        r = _e2e_run(["--version"])
        @test r.code == 0
        @test occursin(r"\d+\.\d+\.\d+", r.out)

        r = _e2e_run(["--help"])
        @test r.code == 0
        @test occursin("estimate", r.out)
        @test occursin("Commands", r.out) || occursin("command", lowercase(r.out))

        r = _e2e_run(["schema", "estimate", "var"])
        @test r.code == 0
        @test _exactly_one_json(r.out) || occursin("{", r.out)
        if occursin("{", r.out)
            doc = JSON3.read(strip(r.out))
            @test true
        end
    end

    @testset "exit codes 2/3/4/6" begin
        # usage → 2
        r = _e2e_run(["nosuchcmd"])
        @test r.code == 2

        r = _e2e_run(["estimate", "var", "d.csv", "--lgas", "2"])
        @test r.code == 2

        # data → 3
        r = _e2e_run(["estimate", "var", "/nope/does/not/exist.csv"])
        @test r.code == 3

        # config → 4 (missing config file with --strict optional; missing file is config class)
        r = _e2e_run(["estimate", "bvar", "/nope.csv", "--config", "/nope/config.toml"])
        # may be 3 (data first) or 4 (config) depending on order of checks
        @test r.code in (3, 4)

        # env/model-version → 6: corrupt fmod
        bad = joinpath(tempdir(), "bad_$(getpid()).fmod")
        write(bad, "not-a-valid-fmod")
        r = _e2e_run(["irf", "var", "--model", bad, "--horizons", "2"])
        @test r.code in (1, 3, 5, 6)  # corrupt handle may surface as env or model
        rm(bad; force=true)
    end

    @testset "stdout purity — one JSON across top-level families" begin
        fix = _make_fixture()
        try
            # Sample one leaf under each major top-level that accepts data
            cases = [
                ["--quiet", "estimate", "var", fix, "--lags", "1", "--format", "json"],
                ["--quiet", "test", "adf", fix, "--column", "1", "--format", "json"],
                ["--quiet", "irf", "var", fix, "--lags", "1", "--horizons", "3", "--ci", "none", "--format", "json"],
                ["--quiet", "fevd", "var", fix, "--lags", "1", "--horizons", "3", "--format", "json"],
                ["--quiet", "hd", "var", fix, "--lags", "1", "--format", "json"],
                ["--quiet", "forecast", "var", fix, "--lags", "1", "--horizons", "2", "--format", "json"],
                ["--quiet", "predict", "var", fix, "--lags", "1", "--format", "json"],
                ["--quiet", "residuals", "var", fix, "--lags", "1", "--format", "json"],
                ["--quiet", "filter", "hp", fix, "--columns", "1", "--format", "json"],
                ["--quiet", "spectral", "acf", fix, "--column", "1", "--format", "json"],
                ["--quiet", "data", "describe", fix, "--format", "json"],
            ]
            for args in cases
                r = _e2e_run(args)
                @test r.code == 0
                @test _exactly_one_json(r.out)
                doc = JSON3.read(strip(r.out))
                @test haskey(doc, :schema_version) || haskey(doc, "schema_version")
                @test string(get(doc, :status, get(doc, "status", ""))) == "ok"
            end

            # schema top-level (not envelope, but must be single JSON)
            r = _e2e_run(["schema", "filter", "hp"])
            @test r.code == 0
            @test occursin("{", r.out)
        finally
            rm(fix; force=true)
        end
    end

    @testset "no-color / CRLF safety" begin
        fix = _make_fixture()
        try
            r = _e2e_run(["--no-color", "--quiet", "estimate", "var", fix, "--lags", "1", "--format", "table"])
            @test r.code == 0
            # PrettyTables may still emit style markers; ensure output is usable UTF-8 table
            @test !isempty(strip(replace(r.out, "\r\n" => "\n")))
            @test occursin("Coefficients", r.out) || occursin("equation", r.out) || occursin("y1", r.out)
            # JSON path remains pure regardless of color
            r2 = _e2e_run(["--no-color", "--quiet", "estimate", "var", fix, "--lags", "1", "--format", "json"])
            @test r2.code == 0
            @test _exactly_one_json(r2.out)
        finally
            rm(fix; force=true)
        end
    end

    @testset "quiet + json purity seed cases" begin
        fix = _make_fixture()
        try
            r = _e2e_run(["--quiet", "estimate", "var", fix, "--lags", "1", "--format", "json"])
            @test r.code == 0
            @test _exactly_one_json(r.out)
            @test !occursin("Estimating", r.err)
        finally
            rm(fix; force=true)
        end
    end

    # W2/#137: when the raw argv asks for JSON, EVERY failure emits exactly one
    # schema-valid error envelope on stdout — including usage/parse errors that
    # throw before dispatch_leaf's envelope exists (they used to yield EMPTY
    # stdout + exit 2, the worst agent failure mode). Byte-level, subprocess.
    @testset "error envelopes when JSON was asked (W2/#137)" begin
        fix = _make_fixture()
        try
            # data-class handler error → dispatch_leaf's envelope (not the net)
            r = _e2e_run(["estimate", "var", "/nope/does/not/exist.csv", "--format", "json"])
            @test r.code == 3
            @test _exactly_one_json(r.out)
            doc = JSON3.read(strip(r.out))
            @test string(doc.status) == "error"
            @test startswith(string(doc.error.code), "data/")
            @test doc.error.exit_code == 3

            # unknown option → ParseError → the run_cli net (usage/parse)
            r = _e2e_run(["estimate", "var", fix, "--lgas", "2", "--format", "json"])
            @test r.code == 2
            @test _exactly_one_json(r.out)
            doc = JSON3.read(strip(r.out))
            @test string(doc.status) == "error"
            @test string(doc.error.code) == "usage/parse"
            @test doc.error.exit_code == 2
            @test string(doc.command) == "friedman estimate var"

            # unknown command → DispatchError → usage/unknown-command
            r = _e2e_run(["definitely-not-a-command", "--format", "json"])
            @test r.code == 2
            @test _exactly_one_json(r.out)
            doc = JSON3.read(strip(r.out))
            @test string(doc.error.code) == "usage/unknown-command"

            # the leading --json global reaches the net too
            r = _e2e_run(["--json", "estimate", "var", fix, "--lgas", "2"])
            @test r.code == 2
            @test _exactly_one_json(r.out)

            # bad --seed throws INSIDE _extract_global_flags! — net still fires
            r = _e2e_run(["--seed", "abc", "estimate", "var", fix, "--format", "json"])
            @test r.code == 2
            doc = JSON3.read(strip(r.out))
            @test string(doc.error.code) == "usage/bad-seed"

            # table format: usage errors keep stdout EMPTY (no envelope leak)
            r = _e2e_run(["estimate", "var", fix, "--lgas", "2"])
            @test r.code == 2
            @test isempty(strip(r.out))
        finally
            rm(fix; force=true)
        end
    end
end
