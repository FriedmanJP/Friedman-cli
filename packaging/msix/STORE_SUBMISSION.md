# Microsoft Store MSIX Submission Runbook (#262)

This document covers packaging, local certification, and submission of the unsigned
Store MSIX package for **Friedman-cli** to Microsoft Partner Center.

## Partner Center Identity

| Field | Value |
|---|---|
| `Package/Identity/Name` | `FriedmanJP.Friedman-cli` |
| `Package/Identity/Publisher` | `CN=B2EE8C32-50BC-46BC-B4B2-3BA1AB9A6ECB` |
| `Package/Properties/PublisherDisplayName` | `FriedmanJP` |
| Package Family Name (PFN) | `FriedmanJP.Friedman-cli_f190rb6mg74fa` |
| Microsoft Store Product ID | `9NBBQSNP6W44` |
| Target architecture | `x64` (`Windows.Desktop`, MinVersion `10.0.17763.0`) |
| `AppExecutionAlias` | `friedman.exe` (`desktop4:Subsystem="console"`) |
| License | `GPL-3.0-or-later` |
| Privacy Policy URL | `https://friedmanjp.github.io/Friedman-cli/dev/getting-started/installation/#privacy-policy` |

> **Store `.msix` vs. GitHub sideload `.msix`:**
> - **Store upload (`-Mode store`)** uses `CN=B2EE8C32-50BC-46BC-B4B2-3BA1AB9A6ECB` and is
>   uploaded **unsigned** (`friedman-vX.Y.Z-windows-x86_64-store.msix`) to Partner Center.
>   Microsoft signs the package with the Microsoft Store certificate during ingestion at zero cost.
> - **GitHub Releases sideload (`-Mode sideload`)** uses Microsoft's unsigned-package OID
>   (`CN=FriedmanJP, OID.2.25.311729368913984317654407730594956997722=1`) so Windows 11 users and CI can
>   install it locally via `Add-AppxPackage -AllowUnsigned`.

---

## `runFullTrust` Restricted Capability Justification

Copy and paste the following text into Partner Center under **Submission options → Restricted capabilities (`runFullTrust`)**:

> Friedman-cli is an open-source (GPL-3.0-or-later) command-line econometric analysis tool
> invoked from Windows Terminal, PowerShell, or Command Prompt via its `friedman.exe`
> `AppExecutionAlias`. Users invoke `friedman` from arbitrary working directories to read
> and write user-specified input datasets, model specifications, estimation handles, and
> output tables/plots (`.csv`, `.toml`, `.jld2`, `.jls`, `.fmod`, `.json`, `.html`) passed
> via CLI arguments, or to communicate over standard input/output in interactive REPL and
> MCP (`serve --mcp`) modes. Unrestricted desktop trust (`runFullTrust`) is required so the
> console executable can access user-selected file paths in the caller's shell working
> directory without AppContainer filesystem isolation breaking standard CLI workflows.
> Friedman-cli runs 100% locally with zero telemetry, zero background services, and no
> automatic network requests.

---

## Submission Checklist

1. **Obtain the Store MSIX artifact from CI:**
   - Run `.github/workflows/release.yml` (via `workflow_dispatch` or by pushing tag `vX.Y.Z`).
   - Download the workflow artifact **`store-msix-windows-x86_64`**, which contains
     `friedman-vX.Y.Z-windows-x86_64-store.msix` (unsigned; NOT attached to public GitHub Releases).
   - Alternatively, build locally on Windows x64:
     ```powershell
     julia build_release.jl
     pwsh -File packaging/msix/pack_msix.ps1 `
       -Version 1.0.7 `
       -OutputPath build\friedman-v1.0.7-windows-x86_64-store.msix `
       -Mode store
     ```

2. **Pre-submission Windows App Certification Kit (`appcert.exe`) check (on Windows):**
   ```powershell
   & "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe" `
     test -appxpackagepath "build\friedman-v1.0.7-windows-x86_64-store.msix" `
     -reportoutputpath "appcert-report.xml"
   ```
   Confirm `OVERALL_RESULT="PASS"` in `appcert-report.xml`.

3. **Upload to Partner Center:**
   - Open the **Friedman-cli** product (`9NBBQSNP6W44`) in Microsoft Partner Center.
   - Under **Packages**, upload `friedman-vX.Y.Z-windows-x86_64-store.msix` (x64, unsigned).
   - Under **Store listings**, attach `packaging/msix/store-assets/StoreListing300x300.png` (300×300),
     terminal screenshots, GPL-3.0-or-later license note, and Privacy Policy URL:
     `https://friedmanjp.github.io/Friedman-cli/dev/getting-started/installation/#privacy-policy`.
   - Include the `runFullTrust` justification above under **Notes for certification**.

4. **Post-publication clean-machine verification (Julia-free Windows 11):**
   ```powershell
   winget install 9NBBQSNP6W44 --source msstore
   friedman --version
   friedman --quiet data describe :denmark --format json
   printf "--version`nexit`n" | friedman repl
   winget uninstall 9NBBQSNP6W44
   ```

5. **Optional follow-up CI automation:**
   - Once initial Store certification succeeds, Partner Center submissions on `v*` tags can
     be automated with `microsoft/setup-msstore-cli` + `msstore publish` using Entra ID
     service principal credentials stored in GitHub repository secrets.
