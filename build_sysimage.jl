# Build a custom system image for fast startup
# Run: julia --project build_sysimage.jl
# Takes a few minutes, but makes `friedman` start in <0.5s

using Pkg
# Install PackageCompiler in a temporary env so it doesn't pollute Project.toml
Pkg.activate(; temp=true)
Pkg.add("PackageCompiler")
using PackageCompiler
Pkg.activate(@__DIR__)

sysimage_path = joinpath(@__DIR__, "friedman.so")

# Precompile statements: exercise the main code paths
precompile_script = joinpath(@__DIR__, "precompile_exec.jl")

open(precompile_script, "w") do io
    write(io, """
    using Friedman
    # Real handler paths (F45); no in-package @compile_workload (F46)
    fixture = joinpath(@__DIR__, "precompile_fixture.csv")
    open(fixture, "w") do f
        println(f, "y1,y2,y3")
        for t in 1:80
            println(f, string(sin(t/3)) * "," * string(cos(t/4)) * "," *
                       string(sin(t/5) + cos(t/7)))
        end
    end
    app = Friedman.APP
    Friedman.dispatch(app, ["--help"])
    Friedman.dispatch(app, ["--version"])
    for cmd in ["estimate", "test", "irf", "forecast", "filter", "data",
                "dsge", "did", "spectral", "nowcast"]
        Friedman.dispatch(app, [cmd, "--help"])
    end
    outdir = mktempdir()
    Friedman.dispatch(app, ["estimate", "var", fixture, "--lags", "1"])
    Friedman.dispatch(app, ["estimate", "var", fixture, "--lags", "1",
                            "--format", "json"])
    Friedman.dispatch(app, ["estimate", "var", fixture, "--lags", "1",
                            "--format", "csv", "--output", joinpath(outdir, "o.csv")])
    Friedman.dispatch(app, ["irf", "var", fixture, "--lags", "1"])
    Friedman.dispatch(app, ["test", "adf", fixture])
    Friedman.dispatch(app, ["filter", "hp", fixture])
    Friedman.dispatch(app, ["forecast", "var", fixture, "--lags", "1"])
    """)
end

println("Building system image at $sysimage_path ...")
println("This will take a few minutes.")

create_sysimage(
    [:Friedman];
    sysimage_path=sysimage_path,
    precompile_execution_file=precompile_script,
    project=@__DIR__,
    sysimage_build_args=`--strip-metadata`,
)

# Clean up
rm(precompile_script; force=true)

println()
println("Done! System image: $sysimage_path")
println("Reinstall with: bash install.sh")
