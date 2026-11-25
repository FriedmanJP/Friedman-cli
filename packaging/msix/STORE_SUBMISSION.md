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
| `AppExecutionAlias` | `frdc.exe` (`desktop4:Subsystem="console"`) |
| License | `GPL-3.0-only` |
| Privacy Policy URL | `https://friedmanjp.github.io/Friedman-cli/dev/getting-started/installation/#privacy-policy` |

> **Store `.msix` vs. GitHub sideload `.msix`:**
> - **Store upload (`-Mode store`)** uses `CN=B2EE8C32-50BC-46BC-B4B2-3BA1AB9A6ECB` and is
>   uploaded **unsigned** (`frdc-vX.Y.Z-windows-x86_64-store.msix`) to Partner Center.
>   Microsoft signs the package with the Microsoft Store certificate during ingestion at zero cost.
> - **GitHub Releases sideload (`-Mode sideload`)** uses Microsoft's unsigned-package OID
>   (`CN=FriedmanJP, OID.2.25.311729368913984317654407730594956997722=1`) so Windows 11 users and CI can
>   install it locally via `Add-AppxPackage -AllowUnsigned`.

---

## Mandatory GPL-3.0-only Custom License Terms (Overriding Microsoft SALT, #289)

> **CRITICAL FOR GPL-3.0 COMPLIANCE:** By default, apps published to the Microsoft Store
> without custom license terms are governed by Microsoft's **Standard Application License
> Terms (SALT)**, which impose proprietary restrictions conflicting with **GPL-3.0 §§ 7 & 10**
> (including for bundled third-party GPL-2.0-or-later libraries `FFTW_jll`, `Rmath_jll`, and
> `SuiteSparse_jll`). You **MUST** override SALT in Partner Center before publishing any release.

### Partner Center Settings

1. **Custom License Terms (Properties / Submission options → License terms):**
   Paste the notice below followed by the verbatim contents of the repository root `LICENSE`
   file (GNU General Public License, Version 3, 29 June 2007):

   ```text
   CUSTOM LICENSE TERMS — Friedman-cli (frdc)
   This application is licensed exclusively under the GNU General Public License,
   Version 3 (GPL-3.0-only). These terms supersede the Microsoft Standard Application
   License Terms (SALT). Nothing in Microsoft Store distribution imposes any further
   restriction on your rights under GPL-3.0 to run, copy, study, modify, or redistribute
   this software.

   Complete Corresponding Source (GPL-3.0 §6 and MPL-2.0 §3.2(b)), resolved Manifest.toml,
   and third-party license notices are publicly hosted at:
     https://github.com/FriedmanJP/Friedman-cli/releases
   and bundled inside the installed package directory under LICENSE, SOURCE_OFFER.txt,
   share\licenses\THIRD_PARTY_LICENSES.md, and share\licenses\DATA_LICENSES.md.
   Run `frdc --conditions` or `frdc --warranty` for in-app license details.

   [Append full verbatim text of LICENSE (GNU General Public License v3.0) here]
   ```

2. **Store DRM / App-Package Encryption (GPL-3.0 §§ 3 & 6):**
   - Keep **Store DRM / package encryption DISABLED** (do not opt into encrypted package
     licensing or locked S-Mode-only distribution).
   - Confirm `TargetDeviceFamily` remains `Windows.Desktop` (`MinVersion="10.0.17763.0"`),
     allowing users to build and run modified versions freely.

3. **Store Listing & Support Links:**
   - Include `https://github.com/FriedmanJP/Friedman-cli/releases` (Corresponding Source URL)
     in the Microsoft Store **Description**, **Website**, and **Support contact info** fields.
   - `pack_msix.ps1` enforces a hard gate refusing to build any `.msix` missing `LICENSE`,
     `SOURCE_OFFER.txt`, `share\licenses\THIRD_PARTY_LICENSES.md`, or
     `share\licenses\DATA_LICENSES.md`.

---

## `runFullTrust` Restricted Capability Justification

Copy and paste the following text into Partner Center under **Submission options → Restricted capabilities (`runFullTrust`)**:

> Friedman-cli is an open-source (GPL-3.0-only) command-line econometric analysis tool
> invoked from Windows Terminal, PowerShell, or Command Prompt via its `frdc.exe`
> `AppExecutionAlias`. Users invoke `frdc` from arbitrary working directories to read
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
     `frdc-vX.Y.Z-windows-x86_64-store.msix` (unsigned; NOT attached to public GitHub Releases).
   - Alternatively, build locally on Windows x64:
     ```powershell
     julia build_release.jl
     pwsh -File packaging/msix/pack_msix.ps1 `
       -Version 1.1.0 `
       -OutputPath build\frdc-v1.1.0-windows-x86_64-store.msix `
       -Mode store
     ```

2. **Pre-submission Windows App Certification Kit (`appcert.exe`) check (on Windows):**
   ```powershell
   & "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\appcert.exe" `
     test -appxpackagepath "build\frdc-v1.1.0-windows-x86_64-store.msix" `
     -reportoutputpath "appcert-report.xml"
   ```
   Confirm `OVERALL_RESULT="PASS"` in `appcert-report.xml`.

3. **Upload to Partner Center:**
   - Open the **Friedman-cli** product (`9NBBQSNP6W44`) in Microsoft Partner Center.
   - Under **Properties / Submission options → License terms**, enable **Custom License Terms**
     and paste the `GPL-3.0-only` SALT override notice + verbatim `LICENSE` text from above;
     confirm Store DRM / package encryption is **OFF**.
   - Under **Packages**, upload `frdc-vX.Y.Z-windows-x86_64-store.msix` (x64, unsigned).
   - Under **Store listings**, attach `packaging/msix/store-assets/StoreListing300x300.png` (300×300),
     terminal screenshots, `GPL-3.0-only` license & Corresponding Source link
     (`https://github.com/FriedmanJP/Friedman-cli/releases`), and Privacy Policy URL:
     `https://friedmanjp.github.io/Friedman-cli/dev/getting-started/installation/#privacy-policy`.
   - Include the `runFullTrust` justification above under **Notes for certification**.

4. **Post-publication clean-machine verification (Julia-free Windows 11):**
   ```powershell
   winget install 9NBBQSNP6W44 --source msstore
   frdc --version
   frdc --quiet data describe :denmark --format json
   printf "--version`nexit`n" | frdc repl
   winget uninstall 9NBBQSNP6W44
   ```

5. **Optional follow-up CI automation:**
   - Once initial Store certification succeeds, Partner Center submissions on `v*` tags can
     be automated with `microsoft/setup-msstore-cli` + `msstore publish` using Entra ID
     service principal credentials stored in GitHub repository secrets.
