# [Installation & Quickstart](@id gs-installation)

Install `Friedman-cli` as a self-contained, zero-Julia standalone package on Windows or Linux, or run and build from source with Julia 1.13+ on macOS and other architectures.

## Quick Installer (Recommended)

### Windows (`x86_64`) — Microsoft Store & `winget`

The recommended Windows installation is the Microsoft-signed MSIX package from Microsoft Store (`9NBBQSNP6W44`). It requires no Julia installation, receives automatic updates, and exposes `frdc` on `PATH` via `AppExecutionAlias`:

```powershell
winget install 9NBBQSNP6W44 --source msstore
frdc --version
```

Alternatively, install the standalone `.zip` archive from GitHub Releases into `%USERPROFILE%\.frdc` without Store access or administrator rights:

```powershell
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

### Linux (`x86_64`)

```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
```

The installer downloads the standalone `linux-x86_64` tarball (which bundles a private Julia `1.14+opt` runtime and all JLL artifacts—no `julia` or `juliaup` required), extracts it to `~/.frdc/`, and links `~/.local/bin/frdc`. Add `~/.local/bin` to your `PATH` if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
frdc --help
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

- `frdc-vX.Y.Z-linux-x86_64.tar.gz` — Linux `x86_64` standalone tarball (zero Julia required)
- `frdc-vX.Y.Z-windows-x86_64.msix` — Windows `x86_64` unsigned sideload MSIX (`AppExecutionAlias`)
- `frdc-vX.Y.Z-windows-x86_64.zip` — Windows `x86_64` standalone archive (`bin\frdc.exe`)

### Windows MSIX Sideloading vs. Microsoft Store vs. `.zip`

- **Microsoft Store (`winget install 9NBBQSNP6W44 --source msstore`):** Microsoft-signed, double-click/one-command install, zero SmartScreen warnings.
- **GitHub `.msix` sideload:** Signed with Microsoft's unsigned-package publisher OID for testing and offline enterprise deployment. On Windows 11 with Developer Mode enabled, install from PowerShell:

  ```powershell
  Add-AppxPackage -Path .\frdc-vX.Y.Z-windows-x86_64.msix -AllowUnsigned
  frdc --version
  ```

- **Standalone `.zip` / `install.ps1`:** Extract anywhere (or run `install.ps1` for `%USERPROFILE%\.frdc\bin\frdc.exe`) with zero admin privileges or Developer Mode.

### Runtime Depot, Object Cache & Offline Notes

Standalone builds bundle all required artifacts under `share/julia/artifacts/` and run completely offline without network access. On Julia 1.14 standalone builds, the native C driver automatically resolves a **version- and build-stamp-keyed per-user local object cache** (`JULIA_OBJCACHE=1`) under `~/Library/Caches/frdc/` (macOS), `$XDG_CACHE_HOME/frdc/` or `~/.cache/frdc/` (Linux), or `%LOCALAPPDATA%\frdc\cache\` (Windows) after verifying recursive writability and a local filesystem (rejecting NFS/SMB/CIFS/FUSE network mounts). On read-only install roots (`WindowsApps` MSIX, `/opt`, `chmod 555` homes/depots) or network home directories, it silently falls back to `JULIA_OBJCACHE=0` with zero stderr noise.

Control or inspect the object cache via environment variables and [`frdc cache`](@ref ref-cache):

- `FRDC_OBJCACHE=0` or `JULIA_OBJCACHE=0` — disable on-disk JIT object caching cleanly (writes zero cache files)
- `FRDC_CACHE_DIR=<path>` — override the per-user object-cache base directory
- `FRDC_CACHE_MAX_MB=<int>` — soft footprint budget reported by `frdc cache info` (default `256` MiB)
- `frdc cache info` / `frdc cache clear [--stale-only]` — inspect or prune cached build stamps

### Multithreading & Opt-In Resident Daemon

- **Safe multithreading:** Pass `--threads=<1|N|auto>` or set `FRDC_THREADS=<1|N|auto>` (default `1`; `auto` uses container/cgroup- and P-core-aware sizing capped at `4`). Whenever Julia runs with `> 1` thread and `OPENBLAS_NUM_THREADS` is unset, `frdc` defaults `OPENBLAS_NUM_THREADS=1` and pins `FFTW` to 1 thread while per-leaf `thread_mode` (`:julia_threads`, `:blas_threads`, `:serial_safe`) coordinates OpenBLAS, FFTW, NLopt, MadNLP, and SuiteSparse cleanly.
- **Opt-in resident worker daemon:** Set `FRDC_DAEMON=1` (off by default) or manage explicitly via [`frdc daemon`](@ref ref-daemon) (`frdc daemon start|stop|status`) to keep a single warm worker resident behind the C99 thin wrapper with anti-spawn-storm locking, 23-Ref state-reset isolation, RSS recycle ceilings (`FRDC_DAEMON_MAX_RSS_MB=2048`), idle TTL (`FRDC_DAEMON_TTL=600`), and bounded-acquire fail-open (`FRDC_DAEMON_ACQUIRE_MS=200`). See [Resident Worker Daemon Architecture](@ref int-daemon-adr).

---

## Shell Completions

Standalone builds include a native C99 thin front-end that serves `--version`, `--help`, `schema`, `completions`, `data list`, and `io sources` in **< 10 ms**, making shell-init sourcing (such as `eval "$(frdc completions zsh)"`) instantaneous. You can also write static completion scripts ([`completions`](@ref ref-completions)):

```bash
# Bash
frdc completions bash -o ~/.local/share/bash-completion/completions/frdc

# Zsh (ensure the directory is in $fpath before compinit)
frdc completions zsh -o ~/.zsh/completions/_frdc

# Fish
frdc completions fish -o ~/.config/fish/completions/frdc.fish
```

See [`frdc completions bash`](@ref ref-completions-bash), [`frdc completions zsh`](@ref ref-completions-zsh), and [`frdc completions fish`](@ref ref-completions-fish) for leaf options.

!!! note "Migrating from `friedman` to `frdc`"
    Starting with v1.1.0, the CLI binary, shell completions, REPL prompt (`frdc>` / `~/.frdc_history`), and environment variables (`FRDC_DATA_ROOT`, `FRDC_HISTFILE`, `FRDC_OFFLINE`) use the 4-letter command `frdc`. Legacy `FRIEDMAN_*` environment variables continue to work as silent fallbacks during the transition.

---

## [Running & Building from Source](@id gs-source)

Running from source requires **Julia >= 1.13** (managed cleanly with `juliaup`):

```bash
git clone https://github.com/FriedmanJP/Friedman-cli.git
cd Friedman-cli
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project bin/frdc --help
```

To compile a standalone relocatable app bundle locally (including macOS Apple Silicon or other architectures) via `PackageCompiler.create_app()`:

```bash
julia --project build_release.jl
./build/frdc/bin/frdc --version
```

For fast local metadata/help/schema turnaround on macOS or Linux without compiling a full sysimage, build the optional local thin wrapper (it automatically falls back to `julia --project bin/frdc` whenever `src/` or `Project.toml` changes):

```bash
julia --project tools/build_thin_wrapper.jl
./build/dev-wrapper/bin/frdc --help
```

---

## Optional Dependencies & Licensing

- **Constrained DSGE / NLP Solvers:** Standalone releases bundle the GPL-3.0-compatible `MadNLP` (MIT) + `NLPModels` (MPL-2.0) interior-point solver (`--constraint-solver madnlp`), along with native Projected Newton and `NLopt` (LGPL-2.1+). Optional `Ipopt` (`EPL-2.0` + `MUMPS_seq_jll` `CeCILL-C`) and `PATHSolver` (proprietary) remain source-install-only weak dependencies and are never bundled in distributed binaries.
- **Data Licenses:** Bundled example datasets (`:fred_md`, `:fred_qd` US federal public-domain subsets; `:pwt` under CC-BY-4.0; and 10 public-domain / academic replication datasets) are documented in `DATA_LICENSES.md` (`share/licenses/DATA_LICENSES.md` in standalone releases).
- **License:** Friedman-cli is distributed under **GPL-3.0-only**. See `LICENSE`, `SOURCE_OFFER.txt`, and `share/licenses/THIRD_PARTY_LICENSES.md`.

---

## [Privacy Policy](@id privacy-policy)

Friedman-cli executes 100% locally on your machine. It collects zero telemetry, analytics, crash reports, or usage metrics, stores no cloud account data, and makes no automatic network connections (all bundled datasets, solvers, and runtime artifacts are self-contained inside the application package).

---

## Running the Test Suite

To run the unit and CLI integration test suite from source:

```bash
julia --project test/runtests.jl
```

To jump straight into interactive exploration, run `frdc repl` ([Interactive REPL](@ref gs-repl)), or read [Pipelines, Handles & Reproducibility](@ref gs-pipelines) to learn `.jld2` pipeline chaining and JSON envelopes.
