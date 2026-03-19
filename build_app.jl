# Build a standalone compiled executable for Friedman-cli
# Run: julia build_app.jl
#
# Produces: build/friedman/bin/friedman (standalone, bundled Julia runtime)
#
# This script:
# 1. Creates a temporary build environment with all deps (including weak deps)
# 2. Builds a sysimage via PackageCompiler.create_sysimage()
# 3. Creates a self-contained app directory with bundled Julia + sysimage
# 4. Does NOT modify the source Project.toml

using Pkg

project_dir = @__DIR__
build_project_dir = joinpath(project_dir, "build_env")
app_dir = joinpath(project_dir, "build", "friedman")

# --- Step 1: Create build environment with all deps ---
println("Setting up build environment...")
rm(build_project_dir; force=true, recursive=true)
mkpath(build_project_dir)

# Copy source files
cp(joinpath(project_dir, "src"), joinpath(build_project_dir, "src"))
cp(joinpath(project_dir, "bin"), joinpath(build_project_dir, "bin"))

# Read original Project.toml, drop weakdeps (will Pkg.add them by name)
original_toml = Pkg.TOML.parsefile(joinpath(project_dir, "Project.toml"))
weak_dep_names = collect(keys(get(original_toml, "weakdeps", Dict())))
delete!(original_toml, "weakdeps")

# Write Project.toml without weakdeps
open(joinpath(build_project_dir, "Project.toml"), "w") do io
    Pkg.TOML.print(io, original_toml)
end

# Activate build env and add weak deps by name (resolves correct UUIDs from registry)
Pkg.activate(build_project_dir)
Pkg.instantiate()
if !isempty(weak_dep_names)
    println("Adding weak deps as real deps: ", join(weak_dep_names, ", "))
    Pkg.add(weak_dep_names)
end

# Add REPL stdlib so interactive mode can load it at runtime
println("Adding REPL stdlib for interactive mode...")
Pkg.add("REPL")

# --- Step 2: Install PackageCompiler ---
println("Loading PackageCompiler...")
Pkg.activate(; temp=true)
Pkg.add("PackageCompiler")
using PackageCompiler
Pkg.activate(build_project_dir)

# --- Step 3: Generate precompile script ---
precompile_script = joinpath(build_project_dir, "precompile_app.jl")
open(precompile_script, "w") do io
    write(io, """
    using Friedman
    app = Friedman.build_app()
    Friedman.dispatch(app, ["--help"])
    Friedman.dispatch(app, ["estimate", "--help"])
    Friedman.dispatch(app, ["test", "--help"])
    Friedman.dispatch(app, ["irf", "--help"])
    Friedman.dispatch(app, ["forecast", "--help"])
    Friedman.dispatch(app, ["filter", "--help"])
    Friedman.dispatch(app, ["data", "--help"])
    Friedman.dispatch(app, ["dsge", "--help"])
    Friedman.dispatch(app, ["did", "--help"])
    Friedman.dispatch(app, ["spectral", "--help"])
    Friedman.dispatch(app, ["nowcast", "--help"])
    Friedman.dispatch(app, ["--version"])
    """)
end

# --- Step 4: Build sysimage ---
sysimage_path = joinpath(build_project_dir, "friedman.dylib")
println("Building sysimage...")
println("This will take several minutes.")

create_sysimage(
    [:Friedman];
    sysimage_path=sysimage_path,
    precompile_execution_file=precompile_script,
    project=build_project_dir,
)

# --- Step 5: Bundle into app directory ---
println("Bundling app...")
rm(app_dir; force=true, recursive=true)
mkpath(joinpath(app_dir, "bin"))
mkpath(joinpath(app_dir, "lib"))

# Copy sysimage
cp(sysimage_path, joinpath(app_dir, "lib", "friedman.dylib"))

# Copy project files for LOAD_PATH
cp(joinpath(build_project_dir, "Project.toml"), joinpath(app_dir, "Project.toml"))
if isfile(joinpath(build_project_dir, "Manifest.toml"))
    cp(joinpath(build_project_dir, "Manifest.toml"), joinpath(app_dir, "Manifest.toml"))
end
cp(joinpath(build_project_dir, "src"), joinpath(app_dir, "src"))

# Find julia binary
julia_bin = joinpath(Sys.BINDIR, "julia")

# Create launcher script
launcher = joinpath(app_dir, "bin", "friedman")
open(launcher, "w") do io
    write(io, """#!/bin/bash
# Friedman-cli — compiled launcher
# Uses precompiled sysimage for instant startup

# Resolve symlinks (macOS compatible)
SOURCE="\$0"
while [ -L "\$SOURCE" ]; do
    DIR="\$(cd "\$(dirname "\$SOURCE")" && pwd)"
    SOURCE="\$(readlink "\$SOURCE")"
    [[ "\$SOURCE" != /* ]] && SOURCE="\$DIR/\$SOURCE"
done
SCRIPT_DIR="\$(cd "\$(dirname "\$SOURCE")/.." && pwd)"
SYSIMAGE="\$SCRIPT_DIR/lib/friedman.dylib"

export JULIA_LOAD_PATH="\$SCRIPT_DIR:@stdlib"

exec "$julia_bin" \\
    --project="\$SCRIPT_DIR" \\
    --sysimage="\$SYSIMAGE" \\
    --startup-file=no \\
    -e 'using Friedman; Friedman.main(ARGS)' \\
    -- "\$@"
""")
end
chmod(launcher, 0o755)

# --- Step 6: Clean up build env ---
rm(build_project_dir; force=true, recursive=true)

println()
println("Done! Compiled app: $app_dir/bin/friedman")
println()
println("To install, add to PATH in your shell profile:")
println("  export PATH=\"$app_dir/bin:\$PATH\"")
println()
println("Or symlink:")
println("  ln -sf $app_dir/bin/friedman /usr/local/bin/friedman")
