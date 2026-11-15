# [Installation & Quickstart](@id gs-installation)

Install `Friedman-cli` via the standalone release binary for everyday terminal and pipeline use, or run directly from the Julia source repository for development and test verification.

## Quick Installer (Recommended)

### macOS & Linux

```bash
curl -fsSL https://friedmanjp.github.io/Friedman-cli/install.sh | bash
```

The installer downloads the latest release archive for your architecture (`darwin-arm64`, `darwin-x64`, `linux-x64`, `linux-arm64`), extracts it under `~/.friedman-cli/`, and links the `friedman` wrapper into `~/.local/bin/friedman`. Add `~/.local/bin` to your `PATH` if it is not already present:

```bash
export PATH="$HOME/.local/bin:$PATH"
friedman --help
```

### Windows (PowerShell)

```powershell
irm https://friedmanjp.github.io/Friedman-cli/install.ps1 | iex
```

The Windows installer places the bundle in `$Env:LOCALAPPDATA\Friedman-cli` and adds its `bin` directory to your user `Path`.

### Manual Release Archives

Pre-built release archives are published on the [GitHub Releases](https://github.com/friedmanjp/Friedman-cli/releases) page:

- `friedman-cli-vX.Y.Z-darwin-arm64.tar.gz` — macOS Apple Silicon (M1–M4)
- `friedman-cli-vX.Y.Z-darwin-x64.tar.gz` — macOS Intel
- `friedman-cli-vX.Y.Z-linux-x64.tar.gz` — Linux x86_64
- `friedman-cli-vX.Y.Z-linux-arm64.tar.gz` — Linux ARM64
- `friedman-cli-vX.Y.Z-windows-x64.zip` — Windows x86_64

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

## Running & Building from Source

Running from source requires **Julia >= 1.13** (managed cleanly with `juliaup`):

```bash
git clone https://github.com/friedmanjp/Friedman-cli.git
cd Friedman-cli
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project bin/friedman --help
```

To compile a standalone relocatable release tarball via PackageCompiler.jl:

```bash
julia --project build_release.jl
```

---

## Optional Dependencies & Licensing

- **MCP & Complementarity / NLP Solvers:** Equilibrium models built with JuMP/Ipopt or optional `PATHSolver` licenses must be installed/licensed in your environment when solving complementarity problems that target those backends; check solver license terms separately.
- **License:** Friedman-cli is distributed under **GPL-3.0-or-later**. See `LICENSE` in the repository root.

---

## Running the Test Suite

To run the unit and CLI integration test suite from source:

```bash
julia --project test/runtests.jl
```

To jump straight into interactive exploration, run `friedman repl` ([Interactive REPL](@ref gs-repl)), or read [Pipelines, Handles & Reproducibility](@ref gs-pipelines) to learn `.jld2` pipeline chaining and JSON envelopes.
