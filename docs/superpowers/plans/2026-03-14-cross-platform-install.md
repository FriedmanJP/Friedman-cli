# Cross-Platform Installation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable one-command cross-platform installation of Friedman-cli on macOS ARM, Linux x64, and Windows x64 via GitHub Actions release CI and platform-detecting install scripts.

**Architecture:** A `build_release.jl` script (adapted from `build_app.jl`) builds platform-specific sysimages with auto-detected extensions and runtime Julia discovery launchers. A GitHub Actions `release.yml` workflow runs this on all three platforms on tag push, creating a GitHub Release with archives. Users install via `curl | bash` (macOS/Linux) or `irm | iex` (Windows), which downloads the right archive, ensures Julia 1.12 is available via `juliaup`, and sets up `~/.friedman-cli/`.

**Tech Stack:** Julia 1.12, PackageCompiler.jl, GitHub Actions, bash, PowerShell, juliaup

**Spec:** `docs/superpowers/specs/2026-03-14-cross-platform-install-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `build_release.jl` | Create | Cross-platform build script: auto-detect sysimage ext, generate platform-appropriate launchers with runtime Julia discovery |
| `install.sh` | Create | macOS/Linux installer: platform detection, Julia/juliaup setup, download, safe install to `~/.friedman-cli/`, PATH shim |
| `install.ps1` | Create | Windows installer: Julia/juliaup setup, download, safe install to `~\.friedman-cli\`, PATH config |
| `.github/workflows/release.yml` | Create | Release CI: matrix build on tag push, archive artifacts, create GitHub Release |
| `.gitignore` | Modify | Remove `install.sh` and `uninstall.sh` from ignore list |

---

## Chunk 1: build_release.jl

### Task 1: Create cross-platform build script

This adapts the existing `build_app.jl` (148 lines) with three key changes: auto-detected sysimage extension, runtime Julia discovery in launchers, and Windows `.cmd` launcher support.

**Files:**
- Reference: `build_app.jl` (existing, gitignored, local dev builds)
- Create: `build_release.jl`

- [ ] **Step 1: Create `build_release.jl`**

The script is structurally identical to `build_app.jl` with these differences:
1. Sysimage extension auto-detected via `Sys.iswindows()`/`Sys.isapple()`
2. Sysimage copied as `friedman$(sysimage_ext)` (not hardcoded `.dylib`)
3. Launcher finds Julia at runtime via `juliaup run +1.12` with fallback
4. Windows gets `friedman.cmd` instead of bash launcher
5. No hardcoded `Sys.BINDIR` julia path

```julia
# build_release.jl — Cross-platform build for CI releases
# Run: julia build_release.jl
#
# Produces: build/friedman/ with platform-appropriate sysimage and launcher
#
# This script:
# 1. Creates a temporary build environment with all deps (including weak deps)
# 2. Builds a sysimage via PackageCompiler.create_sysimage()
# 3. Creates a self-contained app directory with sysimage + launcher
# 4. Does NOT modify the source Project.toml

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
where juliaup >nul 2>&1
if %errorlevel% equ 0 (
    juliaup run +1.12 julia -- --project="%SCRIPT_DIR%" --sysimage="%SYSIMAGE%" --startup-file=no -e "using Friedman; Friedman.main(ARGS)" -- %*
    exit /b %errorlevel%
)

where julia >nul 2>&1
if %errorlevel% equ 0 (
    for /f "tokens=*" %%v in ('julia --version 2^>^&1') do set "JULIA_VER=%%v"
    julia --project="%SCRIPT_DIR%" --sysimage="%SYSIMAGE%" --startup-file=no -e "using Friedman; Friedman.main(ARGS)" -- %*
    exit /b %errorlevel%
)

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

# Find Julia: prefer juliaup run +1.12, fallback to julia on PATH
if command -v juliaup >/dev/null 2>&1; then
    exec juliaup run +1.12 julia -- \\
        --project="\$SCRIPT_DIR" \\
        --sysimage="\$SYSIMAGE" \\
        --startup-file=no \\
        -e 'using Friedman; Friedman.main(ARGS)' \\
        -- "\$@"
elif command -v julia >/dev/null 2>&1; then
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
```

- [ ] **Step 2: Test locally on macOS**

Run the build script to verify it produces the same output as `build_app.jl`:

```bash
julia build_release.jl
```

Expected: `build/friedman/` with `lib/friedman.dylib`, `bin/friedman` (bash launcher with `juliaup run +1.12` logic), `src/`, `Project.toml`, `Manifest.toml`.

Verify the launcher works:

```bash
build/friedman/bin/friedman --version
```

Expected: `friedman v0.4.0`

- [ ] **Step 3: Commit**

```bash
git add build_release.jl
git commit -m "feat: add cross-platform build script for CI releases"
```

---

## Chunk 2: install.sh (macOS/Linux installer)

### Task 2: Create macOS/Linux install script

**Files:**
- Create: `install.sh`
- Modify: `.gitignore` (remove `install.sh` from ignore list)

- [ ] **Step 1: Remove `install.sh` from `.gitignore`**

In `.gitignore`, remove the line `install.sh` and `uninstall.sh`:

Current `.gitignore` lines 7-8:
```
install.sh
uninstall.sh
```

Remove both lines. The old legacy `install.sh` (gitignored) will be replaced by the new one. `uninstall.sh` is no longer needed (uninstall is just `rm -rf`).

- [ ] **Step 2: Create `install.sh`**

```bash
#!/bin/bash
set -euo pipefail

# Friedman-cli installer for macOS and Linux
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
#   curl -fsSL https://...install.sh | bash -s -- --version 0.4.0

REPO="FriedmanJP/Friedman-cli"
INSTALL_DIR="$HOME/.friedman-cli"
BIN_DIR="$HOME/.local/bin"

# --- Parse arguments ---
VERSION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            VERSION="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# --- Detect platform ---
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) PLATFORM="darwin" ;;
    Linux)  PLATFORM="linux" ;;
    *)
        echo "Error: Unsupported OS: $OS" >&2
        echo "Supported platforms: macOS (ARM), Linux (x86_64)" >&2
        exit 1
        ;;
esac

case "$ARCH" in
    arm64|aarch64) ARCH_NAME="arm64" ;;
    x86_64|amd64)  ARCH_NAME="x86_64" ;;
    *)
        echo "Error: Unsupported architecture: $ARCH" >&2
        echo "Supported: arm64, x86_64" >&2
        exit 1
        ;;
esac

echo "Detected platform: ${PLATFORM}-${ARCH_NAME}"

# --- Check for curl ---
if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is required but not found." >&2
    echo "Install it via your package manager:" >&2
    echo "  Ubuntu/Debian: sudo apt install curl" >&2
    echo "  RHEL/Fedora:   sudo yum install curl" >&2
    exit 1
fi

# --- Fetch version ---
if [ -z "$VERSION" ]; then
    echo "Fetching latest release..."
    RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null) || {
        echo "Error: Failed to fetch latest release from GitHub API." >&2
        echo "You may be rate-limited. Try specifying a version:" >&2
        echo "  curl -fsSL https://raw.githubusercontent.com/${REPO}/master/install.sh | bash -s -- --version 0.4.0" >&2
        exit 1
    }
    VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/')
    if [ -z "$VERSION" ]; then
        echo "Error: Could not parse version from GitHub API response." >&2
        exit 1
    fi
fi

echo "Installing Friedman-cli v${VERSION}..."

# --- Construct download URL ---
ARCHIVE_NAME="friedman-v${VERSION}-${PLATFORM}-${ARCH_NAME}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ARCHIVE_NAME}"

# --- Ensure Julia 1.12 is available ---
ensure_julia() {
    # Check if juliaup is available
    if command -v juliaup >/dev/null 2>&1; then
        echo "Found juliaup. Ensuring Julia 1.12 is installed..."
        juliaup add 1.12 2>/dev/null || true
        return 0
    fi

    # Check if julia >= 1.12 is on PATH
    if command -v julia >/dev/null 2>&1; then
        JULIA_VER=$(julia --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        JULIA_MAJOR=$(echo "$JULIA_VER" | cut -d. -f1)
        JULIA_MINOR=$(echo "$JULIA_VER" | cut -d. -f2)
        if [ "$JULIA_MAJOR" -ge 1 ] && [ "$JULIA_MINOR" -ge 12 ]; then
            echo "Found Julia $(julia --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
            return 0
        fi
    fi

    # Install juliaup
    echo "Julia 1.12+ not found. Installing juliaup..."
    curl -fsSL https://install.julialang.org | sh -s -- --yes || {
        echo "Error: Failed to install juliaup." >&2
        echo "Install Julia manually: https://julialang.org/downloads/" >&2
        exit 1
    }

    # Source juliaup into current shell
    export PATH="$HOME/.juliaup/bin:$PATH"

    echo "Installing Julia 1.12..."
    juliaup add 1.12
}

ensure_julia

# --- Download archive ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading ${ARCHIVE_NAME}..."
curl -fSL "$DOWNLOAD_URL" -o "$TMPDIR/$ARCHIVE_NAME" || {
    echo "Error: Failed to download ${DOWNLOAD_URL}" >&2
    echo "Check that version v${VERSION} exists at:" >&2
    echo "  https://github.com/${REPO}/releases" >&2
    exit 1
}

# --- Extract to temp, then safe-replace install dir ---
echo "Installing to ${INSTALL_DIR}..."
mkdir -p "$TMPDIR/extract"
tar -xzf "$TMPDIR/$ARCHIVE_NAME" -C "$TMPDIR/extract"

# The archive contains a top-level friedman/ directory
if [ -d "$TMPDIR/extract/friedman" ]; then
    EXTRACTED="$TMPDIR/extract/friedman"
else
    EXTRACTED="$TMPDIR/extract"
fi

# Safe replacement: only remove old install after new one is fully extracted
rm -rf "$INSTALL_DIR"
mv "$EXTRACTED" "$INSTALL_DIR"

# --- Create PATH shim ---
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/friedman" "$BIN_DIR/friedman"

# --- PATH guidance ---
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo ""
    echo "Add ${BIN_DIR} to your PATH by adding this line to your shell profile:"
    SHELL_NAME="$(basename "$SHELL")"
    case "$SHELL_NAME" in
        zsh)  echo "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.zshrc" ;;
        bash) echo "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.bashrc" ;;
        fish) echo "  fish_add_path ${BIN_DIR}" ;;
        *)    echo "  export PATH=\"${BIN_DIR}:\$PATH\"" ;;
    esac
    echo ""
    echo "Then restart your shell or run: export PATH=\"${BIN_DIR}:\$PATH\""
fi

# --- Verify ---
if command -v friedman >/dev/null 2>&1; then
    echo ""
    friedman --version
    echo "Friedman-cli installed successfully!"
else
    echo ""
    echo "Friedman-cli installed to ${INSTALL_DIR}"
    echo "Run: export PATH=\"${BIN_DIR}:\$PATH\" && friedman --version"
fi

echo ""
echo "To uninstall: rm -rf ${INSTALL_DIR} ${BIN_DIR}/friedman"
```

- [ ] **Step 3: Make `install.sh` executable**

```bash
chmod +x install.sh
```

- [ ] **Step 4: Commit**

```bash
git add install.sh .gitignore
git commit -m "feat: add macOS/Linux install script with juliaup integration"
```

---

## Chunk 3: install.ps1 (Windows installer)

### Task 3: Create Windows install script

**Files:**
- Create: `install.ps1`

- [ ] **Step 1: Create `install.ps1`**

```powershell
# Friedman-cli installer for Windows
# Usage:
#   irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
#
# Specific version (set env var before piping):
#   $env:FRIEDMAN_VERSION = "0.4.0"; irm https://...install.ps1 | iex

$ErrorActionPreference = "Stop"

$Repo = "FriedmanJP/Friedman-cli"
$InstallDir = Join-Path $env:USERPROFILE ".friedman-cli"
$BinDir = Join-Path $InstallDir "bin"

# --- Parse version ---
$Version = $env:FRIEDMAN_VERSION
if (-not $Version) {
    Write-Host "Fetching latest release..."
    try {
        $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        $Version = $Release.tag_name -replace '^v', ''
    } catch {
        Write-Host "Error: Failed to fetch latest release from GitHub API." -ForegroundColor Red
        Write-Host 'You may be rate-limited. Try setting $env:FRIEDMAN_VERSION = "0.4.0" before running.' -ForegroundColor Yellow
        exit 1
    }
}

if (-not $Version) {
    Write-Host "Error: Could not determine version." -ForegroundColor Red
    exit 1
}

Write-Host "Installing Friedman-cli v$Version..."

# --- Construct download URL ---
$ArchiveName = "friedman-v$Version-windows-x86_64.zip"
$DownloadUrl = "https://github.com/$Repo/releases/download/v$Version/$ArchiveName"

# --- Ensure Julia 1.12 is available ---
function Ensure-Julia {
    # Check if juliaup is available
    if (Get-Command juliaup -ErrorAction SilentlyContinue) {
        Write-Host "Found juliaup. Ensuring Julia 1.12 is installed..."
        & juliaup add 1.12 2>$null
        return
    }

    # Check if julia >= 1.12 is on PATH
    if (Get-Command julia -ErrorAction SilentlyContinue) {
        $JuliaVer = & julia --version 2>&1
        if ($JuliaVer -match '(\d+)\.(\d+)') {
            $Major = [int]$Matches[1]
            $Minor = [int]$Matches[2]
            if ($Major -ge 1 -and $Minor -ge 12) {
                Write-Host "Found $JuliaVer"
                return
            }
        }
    }

    # Install juliaup via winget
    Write-Host "Julia 1.12+ not found. Installing juliaup..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id Julialang.Juliaup --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: Failed to install juliaup via winget." -ForegroundColor Red
            Write-Host "Install Julia manually: https://julialang.org/downloads/" -ForegroundColor Yellow
            exit 1
        }
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
        Write-Host "Installing Julia 1.12..."
        & juliaup add 1.12
    } else {
        Write-Host "Error: winget is not available." -ForegroundColor Red
        Write-Host "Install juliaup manually: https://julialang.org/downloads/" -ForegroundColor Yellow
        exit 1
    }
}

Ensure-Julia

# --- Download archive ---
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "friedman-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

try {
    $ArchivePath = Join-Path $TmpDir $ArchiveName
    Write-Host "Downloading $ArchiveName..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -ErrorAction Stop

    # --- Extract to temp, then safe-replace install dir ---
    Write-Host "Installing to $InstallDir..."
    $ExtractDir = Join-Path $TmpDir "extract"
    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractDir -Force

    # The archive contains a top-level friedman/ directory
    $Extracted = Join-Path $ExtractDir "friedman"
    if (-not (Test-Path $Extracted)) {
        $Extracted = $ExtractDir
    }

    # Safe replacement
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
    }
    Move-Item -Path $Extracted -Destination $InstallDir

    # --- Add to PATH ---
    $CurrentPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($CurrentPath -notlike "*$BinDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$BinDir;$CurrentPath", "User")
        $env:PATH = "$BinDir;$env:PATH"
        Write-Host "Added $BinDir to user PATH."
    }

    # --- Verify ---
    $FriedmanCmd = Join-Path $BinDir "friedman.cmd"
    if (Test-Path $FriedmanCmd) {
        Write-Host ""
        & $FriedmanCmd --version
        Write-Host "Friedman-cli installed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Friedman-cli installed to $InstallDir" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "To uninstall:"
    Write-Host "  Remove-Item -Recurse -Force '$InstallDir'"
    Write-Host "  Then remove '$BinDir' from your PATH in System Settings > Environment Variables"

} catch {
    Write-Host "Error: Failed to download or install." -ForegroundColor Red
    Write-Host "Check that version v$Version exists at:" -ForegroundColor Yellow
    Write-Host "  https://github.com/$Repo/releases" -ForegroundColor Yellow
    exit 1
} finally {
    # Clean up temp
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
```

- [ ] **Step 2: Commit**

```bash
git add install.ps1
git commit -m "feat: add Windows install script with juliaup/winget integration"
```

---

## Chunk 4: release.yml (GitHub Actions workflow)

### Task 4: Create release CI workflow

**Files:**
- Reference: `.github/workflows/CI.yml` (existing test workflow, for patterns)
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create `.github/workflows/release.yml`**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  build:
    name: Build - ${{ matrix.os }}
    runs-on: ${{ matrix.os }}
    timeout-minutes: 90
    strategy:
      fail-fast: true
      matrix:
        include:
          - os: macos-14
            arch: arm64
            platform: darwin-arm64
            archive_ext: tar.gz
          - os: ubuntu-latest
            arch: x64
            platform: linux-x86_64
            archive_ext: tar.gz
          - os: windows-latest
            arch: x64
            platform: windows-x86_64
            archive_ext: zip

    steps:
      - uses: actions/checkout@v4

      - uses: julia-actions/setup-julia@v2
        with:
          version: '1.12'
          arch: ${{ matrix.arch }}

      - uses: julia-actions/cache@v2

      - name: Install dependencies
        run: |
          julia --project -e '
            using Pkg
            Pkg.rm("MacroEconometricModels")
            Pkg.add(url="https://github.com/FriedmanJP/MacroEconometricModels.jl.git", rev="main")
            Pkg.instantiate()
          '

      - name: Build sysimage
        run: julia build_release.jl
        timeout-minutes: 60

      - name: Get version
        id: version
        shell: bash
        run: echo "version=${GITHUB_REF_NAME#v}" >> "$GITHUB_OUTPUT"

      - name: Archive (tar.gz)
        if: matrix.archive_ext == 'tar.gz'
        shell: bash
        run: |
          cd build
          tar -czf friedman-v${{ steps.version.outputs.version }}-${{ matrix.platform }}.tar.gz friedman/

      - name: Archive (zip)
        if: matrix.archive_ext == 'zip'
        shell: pwsh
        run: |
          cd build
          Compress-Archive -Path friedman -DestinationPath "friedman-v${{ steps.version.outputs.version }}-${{ matrix.platform }}.zip"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: friedman-${{ matrix.platform }}
          path: build/friedman-v${{ steps.version.outputs.version }}-${{ matrix.platform }}.${{ matrix.archive_ext }}

  release:
    name: Create Release
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts
          merge-multiple: true

      - name: List artifacts
        run: ls -la artifacts/

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          files: |
            artifacts/*
            install.sh
            install.ps1
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add release workflow for cross-platform builds on tag push"
```

---

## Chunk 5: Final verification and documentation

### Task 5: Verify everything and update docs

**Files:**
- Verify: `build_release.jl`, `install.sh`, `install.ps1`, `.github/workflows/release.yml`, `.gitignore`
- Update: `docs/src/installation.md` (installation docs for users)

- [ ] **Step 1: Verify `.gitignore` changes**

Confirm that `install.sh` and `uninstall.sh` are no longer in `.gitignore`. Run:

```bash
git status
```

Expected: `install.sh`, `install.ps1`, `build_release.jl`, `.github/workflows/release.yml` are tracked. `build_app.jl` is still gitignored.

- [ ] **Step 2: Verify `build_release.jl` runs locally**

```bash
julia build_release.jl
build/friedman/bin/friedman --version
```

Expected: `friedman v0.4.0`. The launcher should use `juliaup run +1.12` path since juliaup is installed locally.

- [ ] **Step 3: Update `docs/src/installation.md`**

Replace the existing installation docs with updated content reflecting the new cross-platform install process. The file currently has source-install instructions and mentions of sysimage. Update to show:

1. One-liner install for macOS/Linux and Windows
2. Specific version install
3. Manual install from GitHub Releases
4. What the installer does (Julia setup, sysimage, PATH)
5. Upgrading (re-run installer)
6. Uninstalling
7. Building from source (existing content, kept as alternative)

```markdown
# Installation

## Quick Install

### macOS and Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

## What the Installer Does

1. **Checks for Julia 1.12** — if not found, installs [juliaup](https://github.com/JuliaLang/juliaup) (the official Julia version manager) and adds Julia 1.12. Your default Julia version is never changed.
2. **Downloads a precompiled sysimage** — platform-specific binary from GitHub Releases (~670 MB)
3. **Installs to `~/.friedman-cli/`** — self-contained directory with sysimage, source, and launcher
4. **Adds to PATH** — creates a symlink in `~/.local/bin/` (macOS/Linux) or adds to user PATH (Windows)

## Install a Specific Version

### macOS/Linux

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash -s -- --version 0.4.0
```

### Windows

```powershell
$env:FRIEDMAN_VERSION = "0.4.0"; irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

## Manual Install from GitHub Releases

1. Go to [Releases](https://github.com/FriedmanJP/Friedman-cli/releases)
2. Download the archive for your platform:
   - `friedman-vX.Y.Z-darwin-arm64.tar.gz` (macOS Apple Silicon)
   - `friedman-vX.Y.Z-linux-x86_64.tar.gz` (Linux x64)
   - `friedman-vX.Y.Z-windows-x86_64.zip` (Windows x64)
3. Extract to `~/.friedman-cli/`
4. Add `~/.friedman-cli/bin` to your PATH

**Requires:** Julia 1.12+ installed via [juliaup](https://github.com/JuliaLang/juliaup) or manually.

## Upgrade

Re-run the install command. The installer replaces the existing installation.

## Uninstall

### macOS/Linux

```bash
rm -rf ~/.friedman-cli ~/.local/bin/friedman
```

### Windows

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.friedman-cli"
```

Then remove `%USERPROFILE%\.friedman-cli\bin` from your user PATH in System Settings.

## Build from Source

For development or if you prefer to build locally:

```bash
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e '
  using Pkg
  Pkg.rm("MacroEconometricModels")
  Pkg.add(url="https://github.com/FriedmanJP/MacroEconometricModels.jl.git")
'
```

Run directly:

```bash
julia --project bin/friedman [command] [subcommand] [args] [options]
```

Or build a local sysimage:

```bash
julia build_release.jl
~/.friedman-cli/bin/friedman --version
```

## Optional Dependencies

For DSGE constrained optimization, install JuMP and solver packages:

```julia
using Pkg
Pkg.add(["JuMP", "Ipopt"])
```

These are included automatically in the precompiled release builds.
```

- [ ] **Step 4: Commit docs update**

```bash
git add docs/src/installation.md
git commit -m "docs: update installation guide for cross-platform installer"
```

- [ ] **Step 5: Verify all files are committed**

```bash
git log --oneline -5
git status
```

Expected: 4 new commits, clean working tree (except `build/` which is gitignored).
