#!/usr/bin/env julia
# Regenerate golden envelope JSON for migrated leaves (C022 / TS-5).
#
# Usage (from repo root):
#   julia --project test/tools/regen_golden.jl
#
# Deterministic: Random.seed!(42). Uses mocks so CI and local match.
# Protocol: after changing a handler's tables/scalars, re-run this and review the diff.

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using Test
using CSV, DataFrames, JSON3, PrettyTables, TOML, Random
using LinearAlgebra: eigvals, diag, I, svd, diagm
using Statistics: mean, median, var, quantile
using Dates

const ROOT = dirname(dirname(@__DIR__))
project_root = ROOT

include(joinpath(ROOT, "test", "mocks.jl"))
using .MacroEconometricModels

if !@isdefined(tf_unicode_rounded)
    const tf_unicode_rounded = text_table_borders__unicode_rounded
end

include(joinpath(ROOT, "src", "output", "errors.jl"))
include(joinpath(ROOT, "src", "io.jl"))
include(joinpath(ROOT, "src", "output", "envelope.jl"))
include(joinpath(ROOT, "src", "output", "render.jl"))
include(joinpath(ROOT, "src", "config.jl"))
const FRIEDMAN_VERSION = VersionNumber(TOML.parsefile(joinpath(ROOT, "Project.toml"))["version"])

include(joinpath(ROOT, "src", "cli", "types.jl"))
include(joinpath(ROOT, "src", "cli", "parser.jl"))
include(joinpath(ROOT, "src", "cli", "help.jl"))
include(joinpath(ROOT, "src", "cli", "dispatch.jl"))
include(joinpath(ROOT, "src", "commands", "shared.jl"))
include(joinpath(ROOT, "src", "registry", "spec.jl"))
include(joinpath(ROOT, "src", "registry", "adapter.jl"))
include(joinpath(ROOT, "src", "commands", "estimate.jl"))
include(joinpath(ROOT, "src", "commands", "test.jl"))
include(joinpath(ROOT, "src", "commands", "irf.jl"))
include(joinpath(ROOT, "src", "commands", "fevd.jl"))
include(joinpath(ROOT, "src", "commands", "hd.jl"))
include(joinpath(ROOT, "src", "commands", "forecast.jl"))
include(joinpath(ROOT, "src", "commands", "predict.jl"))
include(joinpath(ROOT, "src", "commands", "residuals.jl"))
include(joinpath(ROOT, "src", "commands", "filter.jl"))
include(joinpath(ROOT, "src", "commands", "data.jl"))
include(joinpath(ROOT, "src", "commands", "nowcast.jl"))
include(joinpath(ROOT, "src", "commands", "dsge.jl"))
include(joinpath(ROOT, "src", "commands", "did.jl"))
include(joinpath(ROOT, "src", "commands", "spectral.jl"))
include(joinpath(ROOT, "test", "support.jl"))

# Deterministic fixtures
Random.seed!(42)

function _fixture_csv(path::String; T=80, n=3)
    open(path, "w") do f
        println(f, join(["y$i" for i in 1:n], ","))
        for t in 1:T
            # deterministic non-random series
            vals = [sin(t / (2 + i)) + 0.1 * cos(t / (3 + i)) for i in 1:n]
            println(f, join(string.(round.(vals; digits=8)), ","))
        end
    end
    return path
end

"""Golden cases: (cmd path tokens after top-level, argv tail, golden relative path keys)."""
function _golden_cases(fixture::String)
    return [
        (["spectral", "acf", fixture, "--lags", "1", "--format", "json"],
         # max-lag not required; column default 1
         ["spectral", "acf"],
         ["spectral", "acf", fixture, "--format", "json"]),
        (["spectral", "periodogram", fixture, "--format", "json"],
         ["spectral", "periodogram"],
         ["spectral", "periodogram", fixture, "--format", "json"]),
        (["spectral", "density", fixture, "--method", "welch", "--format", "json"],
         ["spectral", "density"],
         ["spectral", "density", fixture, "--method", "welch", "--format", "json"]),
        (["spectral", "cross", fixture, "--var1", "1", "--var2", "2", "--format", "json"],
         ["spectral", "cross"],
         ["spectral", "cross", fixture, "--var1", "1", "--var2", "2", "--format", "json"]),
        (["spectral", "transfer", "--filter", "hp", "--lambda", "1600", "--nobs", "200", "--format", "json"],
         ["spectral", "transfer"],
         ["spectral", "transfer", "--filter", "hp", "--lambda", "1600", "--nobs", "200", "--format", "json"]),
    ]
end

function main()
    mktempdir() do dir
        fix = _fixture_csv(joinpath(dir, "golden_data.csv"))
        cases = [
            (["spectral", "acf", fix, "--format", "json"], ["spectral", "acf"]),
            (["spectral", "periodogram", fix, "--format", "json"], ["spectral", "periodogram"]),
            (["spectral", "density", fix, "--method", "welch", "--format", "json"], ["spectral", "density"]),
            (["spectral", "cross", fix, "--var1", "1", "--var2", "2", "--format", "json"], ["spectral", "cross"]),
            (["spectral", "transfer", "--filter", "hp", "--lambda", "1600.0", "--nobs", "200", "--format", "json"], ["spectral", "transfer"]),
        ]
        for (argv, gpath) in cases
            Random.seed!(42)
            out = _capture() do
                _dispatch_via_app(String[string(a) for a in argv])
            end
            js = _extract_json_object(out)
            js === nothing && error("no JSON in output for $argv\n$out")
            # schema validate
            errs = validate_envelope_json(js)
            isempty(errs) || @warn "schema warnings for $gpath" errs
            dest = _golden_path(gpath)
            _write_golden(js, dest)
            println("wrote $dest")
        end
    end
    # Renderer text goldens (table + csv) — centralized output path
    mktempdir() do dir
        env = Envelope(command="estimate var")
        add_table!(env, :coefficients, DataFrame(variable=["y1", "y2"], est=[0.5, -0.25]))
        add_scalar!(env, "lags", 2)
        # table
        buf = IOBuffer(); render(env, :table, buf)
        open(joinpath(_GOLDEN_DIR, "render.table.txt"), "w") do io
            write(io, replace(String(take!(buf)), "\r\n" => "\n"))
        end
        # csv
        buf = IOBuffer(); render(env, :csv, buf)
        open(joinpath(_GOLDEN_DIR, "render.csv.txt"), "w") do io
            write(io, replace(String(take!(buf)), "\r\n" => "\n"))
        end
        # json envelope shape
        buf = IOBuffer(); render(env, :json, buf)
        _write_golden(String(take!(buf)), joinpath(_GOLDEN_DIR, "render.envelope.json"))
        println("wrote renderer goldens")
    end
    println("DONE regen goldens under $(_GOLDEN_DIR)")
end

main()
