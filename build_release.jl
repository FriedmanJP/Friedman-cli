# build_release.jl — Cross-platform build for CI releases
# Run: julia build_release.jl
#
# Produces: build/friedman/ with platform-appropriate sysimage and launcher
#
# This script:
# 1. Creates a temporary build environment (weak deps excluded for license compat)
# 2. Builds a sysimage via PackageCompiler.create_sysimage()
# 3. Creates a self-contained app directory with sysimage + launcher
# 4. Does NOT modify the source Project.toml
#
# Note: JuMP/Ipopt/PATHSolver (EPL-2.0, GPL-incompatible) are excluded because
# they are never installed into build_env — they are optional extensions of
# MacroEconometricModels, not deps of this package. Users who need DSGE
# constrained optimization can install them separately: Pkg.add(["JuMP", "Ipopt"])

using Pkg

project_dir = @__DIR__
build_project_dir = joinpath(project_dir, "build_env")
app_dir = joinpath(project_dir, "build", "friedman")

# --- Platform detection ---
sysimage_ext = Sys.iswindows() ? ".dll" : Sys.isapple() ? ".dylib" : ".so"
sysimage_name = "friedman$(sysimage_ext)"

# --- Step 1: Create build environment with all deps ---
println("Setting up build environment...")
rm(build_project_dir; force=true, recursive=true)
mkpath(build_project_dir)

# Copy source files (launcher is regenerated later — do not copy bin/)
cp(joinpath(project_dir, "src"), joinpath(build_project_dir, "src"))

# Read original Project.toml, drop weakdeps and extensions (EPL-incompatible)
original_toml = Pkg.TOML.parsefile(joinpath(project_dir, "Project.toml"))
delete!(original_toml, "weakdeps")
delete!(original_toml, "extensions")

# Write Project.toml without weakdeps
open(joinpath(build_project_dir, "Project.toml"), "w") do io
    Pkg.TOML.print(io, original_toml)
end

# Seed the resolved Manifest so build_env gets EXACTLY the source env's
# dependency graph (incl. the pinned MEMs commit), not a fresh resolve (F50).
src_manifest = joinpath(project_dir, "Manifest.toml")
if isfile(src_manifest)
    cp(src_manifest, joinpath(build_project_dir, "Manifest.toml"))
end

# Activate build env and install deps (weak deps excluded)
Pkg.activate(build_project_dir)
Pkg.instantiate()

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
# Real handler paths (estimate/irf/test/filter/forecast + all formats), not just
# --help (F45). No in-package PrecompileTools.@compile_workload (F46): that would
# run on every dev Pkg.precompile; the sysimage script owns the heavy paths.
precompile_script = joinpath(build_project_dir, "precompile_app.jl")
open(precompile_script, "w") do io
    write(io, """
    using Friedman

    # Deterministic fixture (no RNG — sysimage builds must be reproducible)
    fixture = joinpath(@__DIR__, "precompile_fixture.csv")
    open(fixture, "w") do f
        println(f, "y1,y2,y3")
        for t in 1:80
            println(f, string(sin(t/3)) * "," * string(cos(t/4)) * "," *
                       string(sin(t/5) + cos(t/7)))
        end
    end

    app = Friedman.APP

    # Help/metadata paths
    Friedman.dispatch(app, ["--help"])
    Friedman.dispatch(app, ["--version"])
    for cmd in ["estimate", "test", "irf", "forecast", "filter", "data",
                "dsge", "did", "spectral", "nowcast"]
        Friedman.dispatch(app, [cmd, "--help"])
    end

    # Real handler paths: estimation, IRF, unit root, filter, forecast,
    # all three render formats. These dominate agent workloads.
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

# --- Step 4: Build sysimage ---
sysimage_path = joinpath(build_project_dir, sysimage_name)
println("Building sysimage ($(sysimage_name))...")
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
cp(sysimage_path, joinpath(app_dir, "lib", sysimage_name))

# Copy project files for LOAD_PATH
cp(joinpath(build_project_dir, "Project.toml"), joinpath(app_dir, "Project.toml"))
if isfile(joinpath(build_project_dir, "Manifest.toml"))
    cp(joinpath(build_project_dir, "Manifest.toml"), joinpath(app_dir, "Manifest.toml"))
end
cp(joinpath(build_project_dir, "src"), joinpath(app_dir, "src"))

# --- Step 5a: Create platform-appropriate launcher ---
if Sys.iswindows()
    # Windows batch launcher
    launcher = joinpath(app_dir, "bin", "friedman.cmd")
    open(launcher, "w") do io
        write(io, """@echo off
rem Friedman-cli — compiled launcher
rem Uses precompiled sysimage for instant startup

set "SCRIPT_DIR=%~dp0.."
set "SYSIMAGE=%SCRIPT_DIR%\\lib\\$(sysimage_name)"

set "JULIA_LOAD_PATH=%SCRIPT_DIR%;@stdlib"

rem Find Julia: prefer juliaup, fallback to julia on PATH
rem Prefer julia +1.12 (juliaup channel); juliaup run is not portable on 1.20.x
where julia >nul 2>&1
if %errorlevel% neq 0 goto :nojulia
julia +1.12 --version >nul 2>&1
if %errorlevel% equ 0 (
    julia +1.12 --project="%SCRIPT_DIR%" --sysimage="%SYSIMAGE%" --startup-file=no -e "using Friedman; Friedman.main(ARGS)" -- %*
    exit /b %errorlevel%
)
for /f "tokens=3" %%v in ('julia --version 2^>nul') do set "JULIA_VER=%%v"
for /f "tokens=1,2 delims=." %%a in ("%JULIA_VER%") do (
    set "JMAJ=%%a"
    set "JMIN=%%b"
)
if "%JMAJ%"=="" goto :nojulia
if %JMAJ% lss 1 goto :nojulia
if %JMAJ% equ 1 if %JMIN% lss 12 goto :nojulia
julia --project="%SCRIPT_DIR%" --sysimage="%SYSIMAGE%" --startup-file=no -e "using Friedman; Friedman.main(ARGS)" -- %*
exit /b %errorlevel%

:nojulia
echo Error: Julia 1.12+ is required but not found.
echo Install via: winget install --id Julialang.Juliaup
echo Then run: juliaup add 1.12
exit /b 1
""")
    end
else
    # macOS/Linux bash launcher
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
SYSIMAGE="\$SCRIPT_DIR/lib/$(sysimage_name)"

export JULIA_LOAD_PATH="\$SCRIPT_DIR:@stdlib"

# Find Julia: prefer channel `julia +1.12` (juliaup), then bare julia ≥1.12.
# Note: `juliaup run` is not portable across juliaup versions (1.20.x has no `run`).
if command -v julia >/dev/null 2>&1; then
    if julia +1.12 --version >/dev/null 2>&1; then
        exec julia +1.12 \\
            --project="\$SCRIPT_DIR" \\
            --sysimage="\$SYSIMAGE" \\
            --startup-file=no \\
            -e 'using Friedman; Friedman.main(ARGS)' \\
            -- "\$@"
    fi
    JULIA_VER=\$(julia --version 2>&1 | grep -oE '[0-9]+\\.[0-9]+' | head -1)
    JULIA_MAJOR=\$(echo "\$JULIA_VER" | cut -d. -f1)
    JULIA_MINOR=\$(echo "\$JULIA_VER" | cut -d. -f2)
    if [ "\$JULIA_MAJOR" -ge 1 ] && [ "\$JULIA_MINOR" -ge 12 ]; then
        exec julia \\
            --project="\$SCRIPT_DIR" \\
            --sysimage="\$SYSIMAGE" \\
            --startup-file=no \\
            -e 'using Friedman; Friedman.main(ARGS)' \\
            -- "\$@"
    fi
fi

echo "Error: Julia 1.12+ is required but not found." >&2
echo "Install via: curl -fsSL https://install.julialang.org | sh -s -- --yes" >&2
echo "Then run: juliaup add 1.12" >&2
exit 1
""")
    end
    chmod(launcher, 0o755)
end

# --- Step 6: Clean up build env ---
rm(build_project_dir; force=true, recursive=true)

println()
println("Done! Compiled app: $(app_dir)/bin/friedman$(Sys.iswindows() ? ".cmd" : "")")
println("Sysimage: $(app_dir)/lib/$(sysimage_name)")
