# Cross-Platform Installation for Friedman-cli

**Date:** 2026-03-14
**Status:** Approved
**Scope:** GitHub Actions release workflow, cross-platform build script, install scripts for macOS/Linux/Windows

## Summary

Add cross-platform installation support for Friedman-cli via:
- A GitHub Actions workflow that builds platform-specific sysimages on tag push
- A cross-platform build script (`build_release.jl`) that auto-detects OS and generates appropriate launchers
- Install scripts (`install.sh` for macOS/Linux, `install.ps1` for Windows) that handle Julia setup, asset download, and PATH configuration
- A hybrid Julia strategy: install `juliaup` if missing, `juliaup add 1.12` without changing the user's default, launchers invoke Julia 1.12 via `juliaup run +1.12 julia`

## Target Platforms

| Runner | OS | Arch | Sysimage Extension | Archive Format |
|---|---|---|---|---|
| `macos-14` | macOS | ARM (arm64) | `.dylib` | `.tar.gz` |
| `ubuntu-latest` | Linux | x64 (x86_64) | `.so` | `.tar.gz` |
| `windows-latest` | Windows | x64 (x86_64) | `.dll` | `.zip` |

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Julia dependency | Hybrid — install `juliaup` if missing, never change default | Keeps artifacts small (~673 MB sysimage vs ~2 GB bundled runtime), respects user's environment |
| Install location | `~/.friedman-cli/` | Self-contained, easy uninstall, avoids polluting bin directories |
| Discovery channels | `curl \| bash` one-liner + GitHub Releases page | Quick install for most users, manual option for inspection |
| Update mechanism | Re-run install script | Simple, reliable, no self-update machinery to maintain |
| Julia version pinning | Launcher uses `juliaup run +1.12 julia` | Never changes user's default Julia version |

## Component 1: CI Workflow — `release.yml`

**Trigger:** Push of tags matching `v*` (e.g. `v0.4.0`).

**Matrix strategy:** Three jobs (macOS ARM, Linux x64, Windows x64), all-or-nothing — if any platform fails, no release is created.

**Steps per matrix entry:**

1. Checkout code
2. Setup Julia via `julia-actions/setup-julia@v2` with `version: '1.12'` (pinned, not `'1'`)
3. Install MacroEconometricModels from GitHub (same as existing CI.yml)
4. Run `julia build_release.jl` — produces `build/friedman/` with platform-appropriate sysimage and launcher
5. Archive `build/friedman/` into platform-specific tarball (`.tar.gz`) or zip (`.zip`)
6. Upload archive as workflow artifact

**Important:** The release workflow must pin `version: '1.12'` explicitly, not `'1'` (latest). This ensures the sysimage is built with the same Julia version that users will run via `juliaup run +1.12`.

**Post-matrix step:** Create GitHub Release via `softprops/action-gh-release`, attaching:
- `friedman-v{VERSION}-darwin-arm64.tar.gz`
- `friedman-v{VERSION}-linux-x86_64.tar.gz`
- `friedman-v{VERSION}-windows-x86_64.zip`
- `install.sh`
- `install.ps1`

## Component 2: Build Script — `build_release.jl`

A cross-platform adaptation of the existing `build_app.jl`. Key differences:

**Auto-detect sysimage extension:**
```julia
sysimage_ext = Sys.iswindows() ? ".dll" : Sys.isapple() ? ".dylib" : ".so"
```

**Platform-appropriate launcher generation:**
- macOS/Linux: `bin/friedman` — bash script with sysimage filename interpolated as `friedman$(sysimage_ext)`, finds Julia via `juliaup run +1.12 julia` (with fallback to bare `julia` if juliaup is absent and julia >= 1.12 is on PATH)
- Windows: `bin/friedman.cmd` — batch script with equivalent logic, uses `juliaup run +1.12 julia -- ...` or bare `julia`, sysimage filename `friedman.dll`

**Runtime Julia discovery (launcher logic):**
1. Check if `juliaup` is available → use `juliaup run +1.12 julia` (note: `+` prefix is required for juliaup channel selection)
2. Else check if `julia` is on PATH and version >= 1.12 → use it directly
3. Else print error with install instructions and exit 1

**No hardcoded Julia path:** Unlike `build_app.jl` which bakes in `Sys.BINDIR`, the launcher finds Julia at runtime. The sysimage extension is interpolated at build time (`.dylib`/`.so`/`.dll`) so each platform's launcher references the correct file.

**Manifest.toml bundling:** The `Manifest.toml` included in the release archive comes from the `build_env/` directory (generated during the build), not from the repository (which gitignores it). The `isfile` check from `build_app.jl` carries over.

**Everything else unchanged:** build_env isolation, weak deps promotion (Ipopt, JuMP, PATHSolver), REPL stdlib addition, precompile script, cleanup.

The existing `build_app.jl` is preserved for local development builds.

## Component 3: Install Script — `install.sh` (macOS/Linux)

**Invocation:**
```bash
curl -fsSL https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.sh | bash
```

**Specific version:** `curl -fsSL https://...install.sh | bash -s -- --version 0.4.0`

**Steps:**

1. **Parse arguments** — accept optional `--version X.Y.Z` to skip API lookup and construct direct download URL
2. **Detect platform** — `uname -s` (Darwin/Linux) + `uname -m` (arm64/x86_64) → asset name. Exit 1 on unsupported platforms.
3. **Fetch version** — if `--version` provided, use it; otherwise query GitHub API `/repos/FriedmanJP/Friedman-cli/releases/latest` → tag name + asset URL
4. **Check for Julia:**
   - If `julia` not found and `juliaup` not found → install juliaup non-interactively via `curl -fsSL https://install.julialang.org | sh -s -- --yes`, then `juliaup add 1.12`
   - If `juliaup` found but Julia 1.12 not installed → `juliaup add 1.12`
   - If `julia` found and version >= 1.12 → proceed (no juliaup needed)
   - Never run `juliaup default` — user's default is not touched
5. **Download archive** — `curl` the `.tar.gz` to a temp directory
6. **Install to `~/.friedman-cli/`** — extract archive to temp directory first, then `rm -rf ~/.friedman-cli`, then `mv` temp → `~/.friedman-cli/`. This ensures the old install is only removed after the new one is fully extracted.
7. **Create PATH shim** — symlink `~/.friedman-cli/bin/friedman` → `~/.local/bin/friedman`. Create `~/.local/bin/` if needed.
8. **PATH guidance** — detect shell (bash/zsh/fish), check if `~/.local/bin` is in PATH. If not, print the line to add to the user's rc file.
9. **Verify** — run `friedman --version`, print success message
10. **Print uninstall instructions** — `rm -rf ~/.friedman-cli ~/.local/bin/friedman`

**Upgrade:** Step 6 replaces `~/.friedman-cli/` entirely. Idempotent.

## Component 4: Install Script — `install.ps1` (Windows)

**Invocation:**
```powershell
irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
```

**Specific version:** `irm https://...install.ps1 | iex` with `$env:FRIEDMAN_VERSION = "0.4.0"` set beforehand.

**Steps:**

1. **Parse version** — check `$env:FRIEDMAN_VERSION` or default to latest via API
2. **Platform** — hardcoded `windows-x86_64`
3. **Fetch version** — if env var set, use it; otherwise `Invoke-RestMethod` on GitHub API `/releases/latest`
4. **Check for Julia:**
   - If `julia` and `juliaup` not found → install juliaup via `winget install --id Julialang.Juliaup --accept-source-agreements --accept-package-agreements` (correct winget package ID, non-interactive flags). If `winget` unavailable, print error with link to julialang.org manual install.
   - If `juliaup` found but 1.12 missing → `juliaup add 1.12`
   - If `julia` >= 1.12 on PATH → proceed
   - Never run `juliaup default`
5. **Download archive** — `Invoke-WebRequest` for `.zip` to temp directory
6. **Install to `%USERPROFILE%\.friedman-cli\`** — `Expand-Archive` to temp, remove old install, move temp → `~\.friedman-cli\`. Same safe replacement strategy as `install.sh`.
7. **Add to PATH** — add `%USERPROFILE%\.friedman-cli\bin` to user-level PATH via `[Environment]::SetEnvironmentVariable(..., "User")`. Skip if already present.
8. **Verify** — run `friedman --version`, print success message
9. **Print uninstall instructions** — remove `~\.friedman-cli\` and the PATH entry

**No symlink:** `.cmd` launcher runs directly from `~\.friedman-cli\bin\`.

## Installed Directory Structure

**macOS/Linux:**
```
~/.friedman-cli/
├── bin/
│   └── friedman              # Bash launcher
├── lib/
│   └── friedman.{dylib,so}   # Platform sysimage
├── src/                      # Bundled source
├── Project.toml
└── Manifest.toml

~/.local/bin/
└── friedman → ~/.friedman-cli/bin/friedman   # Symlink
```

**Windows:**
```
%USERPROFILE%\.friedman-cli\
├── bin\
│   └── friedman.cmd           # Batch launcher
├── lib\
│   └── friedman.dll           # Sysimage
├── src\                       # Bundled source
├── Project.toml
└── Manifest.toml
```

## Release Assets (per tag)

```
friedman-v{VERSION}-darwin-arm64.tar.gz
friedman-v{VERSION}-linux-x86_64.tar.gz
friedman-v{VERSION}-windows-x86_64.zip
install.sh
install.ps1
```

## Repository Changes

**New files:**
- `build_release.jl` — cross-platform build script
- `install.sh` — macOS/Linux installer (committed to repo)
- `install.ps1` — Windows installer (committed to repo)
- `.github/workflows/release.yml` — release CI workflow

**Modified files:**
- `.gitignore` — remove `install.sh` and `uninstall.sh` from ignore list

**Unchanged:**
- `build_app.jl` — local dev builds (stays gitignored)
- `.github/workflows/CI.yml` — existing test CI
- `.github/workflows/Documentation.yml` — existing docs CI

## Error Handling

**Install script failures:**

| Scenario | Behavior |
|---|---|
| Unsupported platform (e.g. Linux ARM) | Print supported platforms, exit 1 |
| GitHub API rate limited | Print error, suggest `--version X.Y.Z` flag (`bash -s -- --version 0.4.0`) for direct URL |
| `juliaup` install fails | Print error, link to julialang.org for manual install |
| Julia present but < 1.12, no juliaup | Print error with `juliaup` install instructions |
| `~/.friedman-cli/` exists (upgrade) | Extract new to temp, remove old, move new into place (safe replacement) |
| No write permission | Print error, exit 1 |
| `curl` not available (minimal Linux) | Print error with `apt install curl` / `yum install curl` suggestion |
| Network failure mid-download | Download to temp first, only replace `~/.friedman-cli/` after successful extraction |
| `winget` not available (Windows) | Print error with link to julialang.org for manual juliaup install |

**CI failures:**

| Scenario | Behavior |
|---|---|
| Sysimage build fails on one platform | Matrix job fails, no release created (all-or-nothing) |
| MacroEconometricModels install fails | Job fails before build step |

## Assumptions

- **Julia patch compatibility:** `juliaup add 1.12` installs the latest 1.12.x patch. Sysimages are forward-compatible across patch versions, so a sysimage built with 1.12.4 works with 1.12.5+. If a future patch breaks this, the installer can be updated to pin a specific patch.
- **GitHub org:** Install script URLs use `FriedmanJP/Friedman-cli`. If the repo moves to a different org, the install scripts must be updated.
- **No checksum verification:** Release archives are downloaded over HTTPS from GitHub. Checksum verification is not included in v1 — accepted risk given the HTTPS transport. Can be added later with a `checksums.sha256` release asset.

## Out of Scope

- Self-update command (`friedman update`) — re-run installer instead
- Homebrew tap / Scoop bucket — can be layered on later
- Proxy/firewall environments — standard curl/PowerShell proxy settings apply
- Bundling Julia runtime — sysimage-only, Julia installed via juliaup
- macOS x64 (Intel) — not in current CI matrix, trivial to add later with `macos-13` runner
