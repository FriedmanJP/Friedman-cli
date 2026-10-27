# build_release.jl — Cross-platform build for CI releases
# Run: julia build_release.jl
#
# Produces: build/friedman/ with platform-appropriate sysimage and launcher
#
# This script:
# 1. Creates a temporary build environment seeded from the source Manifest
# 2. Builds a sysimage via PackageCompiler.create_sysimage()
# 3. Creates a self-contained app directory with sysimage + launcher
# 4. Does NOT modify the source Project.toml
#
# Bundled-dependency set = the seeded Manifest.
#   * With MacroEconometricModels >= 0.7.0, JuMP (MPL-2.0) and Ipopt (MIT wrapper
#     over the EPL-2.0 Ipopt library, linked dynamically as a separate work) are
#     REQUIRED upstream deps — they resolve into the Manifest and are bundled.
#     This is intentional; see the "Solver dependencies" note in README.md.
#   * PATHSolver / XLSX / ZipFile stay weak deps of MEMs (nothing hard-requires
#     them), so they are absent from the resolved Manifest and are not bundled.
#   * On the 0.6.x line JuMP/Ipopt are still weak and likewise absent — this
#     script's behavior is unchanged there.

using Pkg

const _PROJECT_DIR = @__DIR__
const _BUILD_PROJECT_DIR = joinpath(_PROJECT_DIR, "build_env")
const _APP_DIR = joinpath(_PROJECT_DIR, "build", "friedman")

# --- Platform detection ---
const _SYSIMAGE_EXT = if Sys.iswindows()
    ".dll"
elseif Sys.isapple()
    ".dylib"
else
    ".so"
end
const _SYSIMAGE_NAME = "friedman$(_SYSIMAGE_EXT)"

# --- Step 1: Create build environment with all deps ---
println("Setting up build environment...")
rm(_BUILD_PROJECT_DIR; force=true, recursive=true)
mkpath(_BUILD_PROJECT_DIR)

# Copy source files (launcher is regenerated later — do not copy bin/)
cp(joinpath(_PROJECT_DIR, "src"), joinpath(_BUILD_PROJECT_DIR, "src"))
# schema/ is read at PRECOMPILE time (W5/#140: envelope-v1.json baked into the
# `friedman schema` contract const via include_dependency) — without it the
# build_env precompile fails "No such file or directory".
cp(joinpath(_PROJECT_DIR, "schema"), joinpath(_BUILD_PROJECT_DIR, "schema"))
if isdir(joinpath(_PROJECT_DIR, "completions"))
    cp(joinpath(_PROJECT_DIR, "completions"), joinpath(_BUILD_PROJECT_DIR, "completions"))
end

# Read original Project.toml. Friedman declares no weakdeps/extensions of its own;
# these deletes are defensive so a future weak dep never forces an extension into
# the build. What actually gets bundled is fixed by the seeded Manifest (above).
const _ORIGINAL_TOML = Pkg.TOML.parsefile(joinpath(_PROJECT_DIR, "Project.toml"))
delete!(_ORIGINAL_TOML, "weakdeps")
delete!(_ORIGINAL_TOML, "extensions")

# Write Project.toml without weakdeps
open(joinpath(_BUILD_PROJECT_DIR, "Project.toml"), "w") do io
    Pkg.TOML.print(io, _ORIGINAL_TOML)
end

# Seed the resolved Manifest so build_env gets EXACTLY the source env's
# dependency graph (incl. the pinned MEMs commit), not a fresh resolve (F50).
const _SRC_MANIFEST = joinpath(_PROJECT_DIR, "Manifest.toml")
if isfile(_SRC_MANIFEST)
    cp(_SRC_MANIFEST, joinpath(_BUILD_PROJECT_DIR, "Manifest.toml"))
end

# Activate build env and install exactly the Manifest's dependency graph
Pkg.activate(_BUILD_PROJECT_DIR)
Pkg.instantiate()

# Add REPL stdlib so interactive mode can load it at runtime
println("Adding REPL stdlib for interactive mode...")
Pkg.add("REPL")

# --- Step 2: Install PackageCompiler ---
println("Loading PackageCompiler...")
Pkg.activate(; temp=true)
Pkg.add("PackageCompiler")
using PackageCompiler
Pkg.activate(_BUILD_PROJECT_DIR)

# --- Step 3: Generate precompile script ---
# Real handler paths (estimate/irf/test/filter/forecast + all formats), not just
# --help (F45). No in-package PrecompileTools.@compile_workload (F46): that would
# run on every dev Pkg.precompile; the sysimage script owns the heavy paths.
const _PRECOMPILE_SCRIPT = joinpath(_BUILD_PROJECT_DIR, "precompile_app.jl")
open(_PRECOMPILE_SCRIPT, "w") do io
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
    Friedman.dispatch(app, ["estimate", "multivariate", "var", fixture, "--lags", "1"])
    Friedman.dispatch(app, ["estimate", "multivariate", "var", fixture, "--lags", "1",
                            "--format", "json"])
    Friedman.dispatch(app, ["estimate", "multivariate", "var", fixture, "--lags", "1",
                            "--format", "csv", "--output", joinpath(outdir, "o.csv")])
    Friedman.dispatch(app, ["irf", "var", fixture, "--lags", "1",
                            "--plot-save", joinpath(outdir, "irf.html")])
    Friedman.dispatch(app, ["test", "unit-root", "adf", fixture])
    Friedman.dispatch(app, ["filter", "hp", fixture])
    Friedman.dispatch(app, ["forecast", "multivariate", "var", fixture, "--lags", "1"])
    """)
end

# --- Step 4: Build sysimage ---
const _SYSIMAGE_PATH = joinpath(_BUILD_PROJECT_DIR, _SYSIMAGE_NAME)
println("Building sysimage ($(_SYSIMAGE_NAME))...")
println("This will take several minutes.")

# --strip-metadata: size win when StructUtils/JSON3 path stays healthy (F47).
# Validated by release smoke (C006) on the next tag — do NOT add --strip-ir
# (MissingCodeError) or filter_stdlibs (needs incremental=false).
#
# Julia 1.13 PackageCompiler defaults cpu_target to "sysimage". On the official
# x86_64 build that is three clones
# (generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)). Julia 1.12
# defaulted to "native" (one clone), and the v0.13.1 ubuntu release finished
# "compiling incremental system image" in ~19 min on the same 15Gi runner.
# v1.0.0 died there twice (14 min and 17 min) with SIGTERM — the runner
# shutdown that follows an OOM, not the 120 min step timeout. One portable
# clone fits: x86_64 uses "generic". aarch64 uses "apple-m1" (one clone).
# "sysimage" there is generic;apple-m1,clone_all, and macos-14 (3-core M1,
# 7 GB) was still in that compile when the 120-minute step timeout fired
# (run 36456649455). Later Apple Silicon runs apple-m1 code.
const _CPU_TARGET = Sys.ARCH === :x86_64 ? "generic" : "apple-m1"
println("Sysimage cpu_target: $_CPU_TARGET")
create_sysimage(
    [:Friedman];
    sysimage_path=_SYSIMAGE_PATH,
    precompile_execution_file=_PRECOMPILE_SCRIPT,
    project=_BUILD_PROJECT_DIR,
    cpu_target=_CPU_TARGET,
    sysimage_build_args=`--strip-metadata`,
)

# --- Step 5: Bundle into app directory ---
println("Bundling app...")
rm(_APP_DIR; force=true, recursive=true)
mkpath(joinpath(_APP_DIR, "bin"))
mkpath(joinpath(_APP_DIR, "lib"))

# Copy sysimage
cp(_SYSIMAGE_PATH, joinpath(_APP_DIR, "lib", _SYSIMAGE_NAME))

# Copy project files for LOAD_PATH
cp(joinpath(_BUILD_PROJECT_DIR, "Project.toml"), joinpath(_APP_DIR, "Project.toml"))
if isfile(joinpath(_BUILD_PROJECT_DIR, "Manifest.toml"))
    cp(joinpath(_BUILD_PROJECT_DIR, "Manifest.toml"), joinpath(_APP_DIR, "Manifest.toml"))
end
cp(joinpath(_BUILD_PROJECT_DIR, "src"), joinpath(_APP_DIR, "src"))
# Ship schema/ beside src/ so a non-sysimage fallback load can precompile too
cp(joinpath(_BUILD_PROJECT_DIR, "schema"), joinpath(_APP_DIR, "schema"))
if isdir(joinpath(_BUILD_PROJECT_DIR, "completions"))
    cp(joinpath(_BUILD_PROJECT_DIR, "completions"), joinpath(_APP_DIR, "completions"))
end

# --- Step 5a: Create platform-appropriate launcher ---
if Sys.iswindows()
    # Windows batch launcher
    launcher = joinpath(_APP_DIR, "bin", "friedman.cmd")
    open(launcher, "w") do io
        write(io, """@echo off
rem Friedman-cli — compiled launcher
rem Uses precompiled sysimage for instant startup

set "SCRIPT_DIR=%~dp0.."
set "SYSIMAGE=%SCRIPT_DIR%\\lib\\$(_SYSIMAGE_NAME)"
set "READY=%SCRIPT_DIR%\\.artifacts_ready"
set "INIT_EXPR=using Pkg; Pkg.instantiate()"
set "MAIN_EXPR=using Friedman; Friedman.main(ARGS)"

set "JULIA_LOAD_PATH=%SCRIPT_DIR%;@stdlib"

rem Find Julia: prefer juliaup, fallback to julia on PATH
rem Prefer julia +1.13 (juliaup channel); juliaup run is not portable on 1.20.x
where julia >nul 2>&1
if %errorlevel% neq 0 goto :nojulia
julia +1.13 --version >nul 2>&1
if %errorlevel% equ 0 (
    if not exist "%READY%" (
        set "JULIA_PKG_PRECOMPILE_AUTO=0"
        julia +1.13 --project="%SCRIPT_DIR%" --startup-file=no ^
            -e "%INIT_EXPR%" 1>&2 && type nul > "%READY%"
    )
    julia +1.13 --project="%SCRIPT_DIR%" --sysimage="%SYSIMAGE%" ^
        --startup-file=no -e "%MAIN_EXPR%" -- %*
    exit /b %errorlevel%
)
for /f "tokens=3" %%v in ('julia --version 2^>nul') do set "JULIA_VER=%%v"
for /f "tokens=1,2 delims=." %%a in ("%JULIA_VER%") do (
    set "JMAJ=%%a"
    set "JMIN=%%b"
)
if "%JMAJ%"=="" goto :nojulia
if %JMAJ% lss 1 goto :nojulia
if %JMAJ% equ 1 if %JMIN% lss 13 goto :nojulia
if not exist "%READY%" (
    set "JULIA_PKG_PRECOMPILE_AUTO=0"
    julia --project="%SCRIPT_DIR%" --startup-file=no ^
        -e "%INIT_EXPR%" 1>&2 && type nul > "%READY%"
)
julia --project="%SCRIPT_DIR%" --sysimage="%SYSIMAGE%" ^
    --startup-file=no -e "%MAIN_EXPR%" -- %*
exit /b %errorlevel%

:nojulia
echo Error: Julia 1.13+ is required but not found.
echo Install via: winget install --id Julialang.Juliaup
echo Then run: juliaup add 1.13
exit /b 1
""")
    end
else
    # macOS/Linux bash launcher
    launcher = joinpath(_APP_DIR, "bin", "friedman")
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
SYSIMAGE="\$SCRIPT_DIR/lib/$(_SYSIMAGE_NAME)"

export JULIA_LOAD_PATH="\$SCRIPT_DIR:@stdlib"

# Find Julia: prefer channel `julia +1.13` (juliaup), then bare julia ≥1.13.
# Note: `juliaup run` is not portable across juliaup versions (1.20.x has no `run`).
if command -v julia >/dev/null 2>&1; then
    if julia +1.13 --version >/dev/null 2>&1; then
        if [ ! -f "\$SCRIPT_DIR/.artifacts_ready" ]; then
            JULIA_PKG_PRECOMPILE_AUTO=0 julia +1.13 \\
                --project="\$SCRIPT_DIR" \\
                --startup-file=no \\
                -e 'using Pkg; Pkg.instantiate()' >&2 \\
                && touch "\$SCRIPT_DIR/.artifacts_ready"
        fi
        exec julia +1.13 \\
            --project="\$SCRIPT_DIR" \\
            --sysimage="\$SYSIMAGE" \\
            --startup-file=no \\
            -e 'using Friedman; Friedman.main(ARGS)' \\
            -- "\$@"
    fi
    JULIA_VER=\$(julia --version 2>&1 | grep -oE '[0-9]+\\.[0-9]+' | head -1)
    JULIA_MAJOR=\$(echo "\$JULIA_VER" | cut -d. -f1)
    JULIA_MINOR=\$(echo "\$JULIA_VER" | cut -d. -f2)
    if [ "\$JULIA_MAJOR" -ge 1 ] && [ "\$JULIA_MINOR" -ge 13 ]; then
        if [ ! -f "\$SCRIPT_DIR/.artifacts_ready" ]; then
            JULIA_PKG_PRECOMPILE_AUTO=0 julia \\
                --project="\$SCRIPT_DIR" \\
                --startup-file=no \\
                -e 'using Pkg; Pkg.instantiate()' >&2 \\
                && touch "\$SCRIPT_DIR/.artifacts_ready"
        fi
        exec julia \\
            --project="\$SCRIPT_DIR" \\
            --sysimage="\$SYSIMAGE" \\
            --startup-file=no \\
            -e 'using Friedman; Friedman.main(ARGS)' \\
            -- "\$@"
    fi
fi

echo "Error: Julia 1.13+ is required but not found." >&2
echo "Install via: curl -fsSL https://install.julialang.org | sh -s -- --yes" >&2
echo "Then run: juliaup add 1.13" >&2
exit 1
""")
    end
    chmod(launcher, 0o755)
end

# --- Step 6: Clean up build env ---
rm(_BUILD_PROJECT_DIR; force=true, recursive=true)

println()
println("Done! Compiled app: $(_APP_DIR)/bin/friedman$(Sys.iswindows() ? ".cmd" : "")")
println("Sysimage: $(_APP_DIR)/lib/$(_SYSIMAGE_NAME)")
