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
    # Exercise build_app and help paths
    app = Friedman.build_app()
    Friedman.dispatch(app, ["--help"])
    Friedman.dispatch(app, ["estimate", "--help"])
    Friedman.dispatch(app, ["test", "--help"])
    Friedman.dispatch(app, ["irf", "--help"])
    Friedman.dispatch(app, ["forecast", "--help"])
    Friedman.dispatch(app, ["--version"])
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
