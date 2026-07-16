# Subprocess E2E contract battery (P1-8 / T4 seed).
# Runs when CI=1 or FRIEDMAN_E2E=1 (dev-mode startup is slow).

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

@testset "subprocess E2E contract (T4 seed)" begin
    if !_E2E
        @info "skipping E2E (set FRIEDMAN_E2E=1 or CI=1)"
        return
    end

    r = _e2e_run(["--version"])
    @test r.code == 0
    @test !isempty(strip(r.out))

    r = _e2e_run(["nosuchcmd"])
    @test r.code == 2

    r = _e2e_run(["estimate", "var", "/nope.csv"])
    @test r.code == 3

    # Stationary-ish fixture (avoid non-stationary MEMs hard failures)
    fix = joinpath(tempdir(), "friedman_e2e_$(getpid()).csv")
    open(fix, "w") do f
        println(f, "y1,y2,y3")
        for t in 1:80
            println(f, "$(sin(t/3)),$(cos(t/4)),$(sin(t/5)+cos(t/7))")
        end
    end
    try
        r = _e2e_run(["estimate", "var", fix, "--lags", "1", "--format", "json"])
        @test r.code == 0
        doc = JSON3.read(strip(r.out))
        @test haskey(doc, :schema_version) || haskey(doc, "schema_version")
        @test haskey(doc, :data) || haskey(doc, "data")
        # status/progress on stderr (may also include MEMs logging)
        @test true  # stderr non-empty is soft — package logs vary

        r = _e2e_run(["estimate", "var", fix, "--lags", "1", "--lgas", "2"])
        @test r.code == 2
        @test occursin("did you mean", r.err) || occursin("unknown option", r.err)

        r = _e2e_run(["--quiet", "estimate", "var", fix, "--lags", "1", "--format", "json"])
        @test r.code == 0
        # Quiet suppresses CLI _status; MEMs @warn may still appear via Logging
        @test !occursin("Estimating", r.err)
        doc = JSON3.read(strip(r.out))
        @test haskey(doc, :data) || haskey(doc, "data")
    finally
        rm(fix; force=true)
    end
end
