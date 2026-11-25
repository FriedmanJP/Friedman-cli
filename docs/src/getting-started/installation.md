# [Installation & Quickstart](@id gs-installation)

Install `Friedman-cli` as a self-contained, zero-Julia standalone package on Windows or Linux, or run and build from source with Julia 1.13+ on macOS and other architectures.

## Quick Installer (Recommended)

### Windows (`x86_64`) — Microsoft Store & `winget`

The recommended Windows installation is the Microsoft-signed MSIX package from Microsoft Store (`9NBBQSNP6W44`). It requires no Julia installation, receives automatic updates, and exposes `friedman` on `PATH` via `AppExecutionAlias`:

```powershell
winget install 9NBBQSNP6W44 --source msstore
friedman --version
```

Alternatively, install the standalone `.zip` archive from GitHub Releases into `%USERPROFILE%\.friedman-cli` without Store access or administrator rights:

```powershell
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

### Linux (`x86_64`)

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
```

The installer downloads the standalone `linux-x86_64` tarball (which bundles a private Julia `1.14+opt` runtime and all JLL artifacts—no `julia` or `juliaup` required), extracts it to `~/.friedman-cli/`, and links `~/.local/bin/friedman`. Add `~/.local/bin` to your `PATH` if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
friedman --help
```

To uninstall on Linux:

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/uninstall.sh | bash
```

### macOS

Pre-built macOS binaries are not published because macOS Gatekeeper requires paid Apple Developer code signing and notarization. Run or build locally from source with **Julia 1.13+** (see [Running & Building from Source](@ref gs-source)).

---

## Manual Release Archives

Pre-built standalone archives are published on the [GitHub Releases](https://github.com/FriedmanJP/Friedman-cli/releases) page:

- `friedman-vX.Y.Z-linux-x86_64.tar.gz` — Linux `x86_64` standalone tarball (zero Julia required)
- `friedman-vX.Y.Z-windows-x86_64.msix` — Windows `x86_64` unsigned sideload MSIX (`AppExecutionAlias`)
- `friedman-vX.Y.Z-windows-x86_64.zip` — Windows `x86_64` standalone archive (`bin\friedman.exe`)

### Windows MSIX Sideloading vs. Microsoft Store vs. `.zip`

- **Microsoft Store (`winget install 9NBBQSNP6W44 --source msstore`):** Microsoft-signed, double-click/one-command install, zero SmartScreen warnings.
- **GitHub `.msix` sideload:** Signed with Microsoft's unsigned-package publisher OID for testing and offline enterprise deployment. On Windows 11 with Developer Mode enabled, install from PowerShell:

  ```powershell
  Add-AppxPackage -Path .\friedman-vX.Y.Z-windows-x86_64.msix -AllowUnsigned
  friedman --version
  ```

- **Standalone `.zip` / `install.ps1`:** Extract anywhere (or run `install.ps1` for `%USERPROFILE%\.friedman-cli\bin\friedman.exe`) with zero admin privileges or Developer Mode.

### Runtime Depot & Offline Notes

Standalone builds bundle all required artifacts under `share/julia/artifacts/` and run completely offline without network access. On Linux/Windows standalone builds powered by Julia 1.14, the native entry point defaults `JULIA_OBJCACHE=0` so read-only install directories (Windows `WindowsApps` MSIX, `/opt`, `chmod 555` depots) never emit `objcache error` messages or write cache files into user depots. Set `JULIA_OBJCACHE=1` if you want to opt into Julia's on-disk JIT object cache under a writable depot:

```bash
JULIA_OBJCACHE=1 friedman --version
```

---

## Shell Completions

Generate tab completion scripts for interactive shell use ([`completions`](@ref ref-completions)):

```bash
# Bash
friedman completions bash -o ~/.local/share/bash-completion/completions/friedman

# Zsh (ensure the directory is in $fpath before compinit)
friedman completions zsh -o ~/.zsh/completions/_friedman

# Fish
friedman completions fish -o ~/.config/fish/completions/friedman.fish
```

See [`friedman completions bash`](@ref ref-completions-bash), [`friedman completions zsh`](@ref ref-completions-zsh), and [`friedman completions fish`](@ref ref-completions-fish) for leaf options.

---

## [Running & Building from Source](@id gs-source)

Running from source requires **Julia >= 1.13** (managed cleanly with `juliaup`):

```bash
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project bin/friedman --help
```

To compile a standalone relocatable app bundle locally (including macOS Apple Silicon or other architectures) via `PackageCompiler.create_app()`:

```bash
julia --project build_release.jl
./build/friedman/bin/friedman --version
```

---

## Optional Dependencies & Licensing

- **MCP & Complementarity / NLP Solvers:** Equilibrium models built with JuMP/Ipopt ship bundled; optional `PATHSolver` licenses must be installed/licensed in your environment when solving complementarity problems that target that backend. Check solver license terms separately.
- **License:** Friedman-cli is distributed under **GPL-3.0-or-later**. See `LICENSE` in the repository root.

---

## [Privacy Policy](@id privacy-policy)

Friedman-cli executes 100% locally on your machine. It collects zero telemetry, analytics, crash reports, or usage metrics, stores no cloud account data, and makes no automatic network connections (all bundled datasets, solvers, and runtime artifacts are self-contained inside the application package).

---

## Running the Test Suite

To run the unit and CLI integration test suite from source:

```bash
julia --project test/runtests.jl
```

To jump straight into interactive exploration, run `friedman repl` ([Interactive REPL](@ref gs-repl)), or read [Pipelines, Handles & Reproducibility](@ref gs-pipelines) to learn `.jld2` pipeline chaining and JSON envelopes.
