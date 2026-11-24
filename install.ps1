# Friedman-cli standalone installer for Windows (x86_64, zero Julia required)
# Tip: For a Microsoft-signed, auto-updated Windows install, use Microsoft Store:
#   winget install 9NBBQSNP6W44 --source msstore
#
# Usage:
#   irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex
#
# Specific version (set env var before piping):
#   $env:FRIEDMAN_VERSION = "1.0.7"; irm https://raw.githubusercontent.com/FriedmanJP/Friedman-cli/master/install.ps1 | iex

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
        Write-Host 'You may be rate-limited. Try setting $env:FRIEDMAN_VERSION = "1.0.7" before running.' -ForegroundColor Yellow
        exit 1
    }
}

if (-not $Version) {
    Write-Host "Error: Could not determine version." -ForegroundColor Red
    exit 1
}

Write-Host "Installing standalone Friedman-cli v$Version (zero Julia required)..."

# --- Construct download URL ---
$ArchiveName = "friedman-v$Version-windows-x86_64.zip"
$DownloadUrl = "https://github.com/$Repo/releases/download/v$Version/$ArchiveName"

# --- Download archive ---
$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "friedman-install-$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

try {
    $ArchivePath = Join-Path $TmpDir $ArchiveName
    Write-Host "Downloading $ArchiveName..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath -ErrorAction Stop

    # --- Verify checksum ---
    $ChecksumUrl = "https://github.com/$Repo/releases/download/v$Version/checksums.sha256"
    $ChecksumPath = Join-Path $TmpDir "checksums.sha256"
    Write-Host "Verifying checksum..."
    try {
        Invoke-WebRequest -Uri $ChecksumUrl -OutFile $ChecksumPath -ErrorAction Stop
        $ChecksumContent = Get-Content $ChecksumPath
        $ExpectedLine = $ChecksumContent | Where-Object { $_ -match [regex]::Escape($ArchiveName) }
        if ($ExpectedLine) {
            $ExpectedHash = ($ExpectedLine -split '\s+')[0].ToUpper()
            $ActualHash = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash.ToUpper()
            if ($ExpectedHash -ne $ActualHash) {
                Write-Host "Error: Checksum verification failed! The download may be corrupted." -ForegroundColor Red
                Write-Host "  Expected: $ExpectedHash" -ForegroundColor Red
                Write-Host "  Got:      $ActualHash" -ForegroundColor Red
                exit 1
            }
            Write-Host "Checksum verified." -ForegroundColor Green
        } else {
            Write-Host "Warning: Archive not found in checksums file, skipping verification." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Warning: Could not download checksums file, skipping verification." -ForegroundColor Yellow
    }

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
        $NewPath = if ($CurrentPath) { "$BinDir;$CurrentPath" } else { $BinDir }
        [System.Environment]::SetEnvironmentVariable("PATH", $NewPath, "User")
        $env:PATH = "$BinDir;$env:PATH"
        Write-Host "Added $BinDir to user PATH."
    }

    # --- Verify ---
    $FriedmanExe = Join-Path $BinDir "friedman.exe"
    if (Test-Path $FriedmanExe) {
        Write-Host ""
        & $FriedmanExe --version
        Write-Host "Friedman-cli installed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Friedman-cli installed to $InstallDir" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Tip: For Microsoft-signed updates via Microsoft Store / winget, use:" -ForegroundColor Cyan
    Write-Host "  winget install 9NBBQSNP6W44 --source msstore" -ForegroundColor Cyan
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
    Remove-Item -Path $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
