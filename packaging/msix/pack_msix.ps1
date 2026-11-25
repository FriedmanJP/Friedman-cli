# Package a PackageCompiler.create_app() Windows directory into an unsigned MSIX
# package (either Store-ready or sideloadable with Microsoft's unsigned OID).
#
# Usage:
#   pwsh -File packaging/msix/pack_msix.ps1 -Version 1.1.0 -OutputPath build/frdc-v1.1.0-windows-x86_64.msix -Mode sideload
#   pwsh -File packaging/msix/pack_msix.ps1 -Version 1.1.0 -OutputPath build/frdc-v1.1.0-windows-x86_64-store.msix -Mode store

param(
    [string]$AppDir = "build\frdc",
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [ValidateSet("store", "sideload")]
    [string]$Mode = "store",
    [string]$IdentityName = "FriedmanJP.Friedman-cli",
    [string]$Publisher = "",
    [string]$PublisherDisplayName = "FriedmanJP",
    [string]$DisplayName = "Friedman-cli",
    [string]$Description = "Macroeconometric analysis toolkit from the terminal, powered by MacroEconometricModels.jl"
)

$ErrorActionPreference = "Stop"

# Normalize version to strict 4-part Major.Minor.Patch.0
$CleanVersion = $Version.Trim().TrimStart('v', 'V')
$CleanVersion = ($CleanVersion -split '[-+]')[0]
$Parts = $CleanVersion -split '\.'
if ($Parts.Count -eq 3) {
    $MsixVersion = "$($Parts[0]).$($Parts[1]).$($Parts[2]).0"
} elseif ($Parts.Count -eq 4) {
    $MsixVersion = "$($Parts[0]).$($Parts[1]).$($Parts[2]).$($Parts[3])"
} else {
    throw "Invalid version '$Version'. Expected Major.Minor.Patch (e.g. 1.0.7)."
}

if (-not $Publisher) {
    if ($Mode -eq "store") {
        $Publisher = "CN=B2EE8C32-50BC-46BC-B4B2-3BA1AB9A6ECB"
    } else {
        # Microsoft unsigned MSIX sideload publisher OID (installable via Add-AppxPackage -AllowUnsigned)
        $Publisher = "CN=FriedmanJP, OID.2.25.311729368913984317654407730594956997722=1"
    }
}

$ResolvedAppDir = (Resolve-Path $AppDir).Path
$ExePath = Join-Path $ResolvedAppDir "bin\frdc.exe"
if (-not (Test-Path $ExePath)) {
    throw "Expected standalone executable not found: $ExePath"
}

# Hard GPL-3.0-only compliance gate (#289, #290): refuse to package any MSIX
# missing LICENSE, SOURCE_OFFER.txt, THIRD_PARTY_LICENSES.md, or DATA_LICENSES.md.
$RequiredLicenseFiles = @(
    "LICENSE",
    "SOURCE_OFFER.txt",
    "share\licenses\THIRD_PARTY_LICENSES.md",
    "share\licenses\DATA_LICENSES.md"
)
foreach ($RelLic in $RequiredLicenseFiles) {
    $LicFull = Join-Path $ResolvedAppDir $RelLic
    if (-not (Test-Path $LicFull) -or (Get-Item $LicFull).Length -eq 0) {
        throw "GPL-3.0 compliance gate failed (#289): missing or empty required notice '$RelLic' in $ResolvedAppDir"
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplatePath = Join-Path $ScriptDir "AppxManifest.xml.in"
$AssetsSrc = Join-Path $ScriptDir "Assets"
if (-not (Test-Path $TemplatePath)) {
    throw "Manifest template not found: $TemplatePath"
}
if (-not (Test-Path $AssetsSrc)) {
    throw "MSIX visual assets directory not found: $AssetsSrc"
}

# Locate MakeAppx.exe
$MakeAppx = $null
$Cmd = Get-Command "MakeAppx.exe" -ErrorAction SilentlyContinue
if ($Cmd) {
    $MakeAppx = $Cmd.Source
} else {
    $SdkRoots = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "${env:ProgramFiles}\Windows Kits\10\bin"
    )
    foreach ($Root in $SdkRoots) {
        if (Test-Path $Root) {
            $Found = Get-ChildItem -Path $Root -Filter "MakeAppx.exe" -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\x64\\MakeAppx\.exe$' } |
                Sort-Object { $_.FullName } -Descending |
                Select-Object -First 1
            if ($Found) {
                $MakeAppx = $Found.FullName
                break
            }
        }
    }
}

if (-not $MakeAppx) {
    throw "MakeAppx.exe not found. Install Windows 10/11 SDK or add MakeAppx.exe to PATH."
}
Write-Host "Using MakeAppx: $MakeAppx"

# Escape XML special characters in substituted values
function Escape-Xml([string]$Text) {
    return [System.Security.SecurityElement]::Escape($Text)
}

$StageDir = Join-Path ([System.IO.Path]::GetTempPath()) ("frdc-msix-stage-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

try {
    Write-Host "Staging app bundle into $StageDir (mode=$Mode, version=$MsixVersion)..."
    Copy-Item -Path (Join-Path $ResolvedAppDir "*") -Destination $StageDir -Recurse -Force
    Copy-Item -Path $AssetsSrc -Destination (Join-Path $StageDir "Assets") -Recurse -Force

    # Double-check staged license notices before MakeAppx invocation (#289)
    foreach ($RelLic in $RequiredLicenseFiles) {
        $StagedLic = Join-Path $StageDir $RelLic
        if (-not (Test-Path $StagedLic) -or (Get-Item $StagedLic).Length -eq 0) {
            throw "GPL-3.0 compliance gate failed (#289): staged notice missing '$RelLic' in $StageDir"
        }
    }

    $ManifestText = [System.IO.File]::ReadAllText($TemplatePath, [System.Text.Encoding]::UTF8)
    $ManifestText = $ManifestText.Replace("{{IDENTITY_NAME}}", (Escape-Xml $IdentityName))
    $ManifestText = $ManifestText.Replace("{{PUBLISHER}}", (Escape-Xml $Publisher))
    $ManifestText = $ManifestText.Replace("{{VERSION}}", (Escape-Xml $MsixVersion))
    $ManifestText = $ManifestText.Replace("{{DISPLAY_NAME}}", (Escape-Xml $DisplayName))
    $ManifestText = $ManifestText.Replace("{{PUBLISHER_DISPLAY_NAME}}", (Escape-Xml $PublisherDisplayName))
    $ManifestText = $ManifestText.Replace("{{DESCRIPTION}}", (Escape-Xml $Description))

    # Write UTF-8 without BOM so MakeAppx and Partner Center ingest cleanly
    $ManifestOut = Join-Path $StageDir "AppxManifest.xml"
    [System.IO.File]::WriteAllText($ManifestOut, $ManifestText, [System.Text.UTF8Encoding]::new($false))

    if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $ResolvedOut = [System.IO.Path]::GetFullPath($OutputPath)
    } else {
        $ResolvedOut = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $OutputPath))
    }
    $OutDir = Split-Path -Parent $ResolvedOut
    if ($OutDir -and -not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    if (Test-Path $ResolvedOut) {
        Remove-Item -Path $ResolvedOut -Force
    }

    & $MakeAppx pack /d $StageDir /p $ResolvedOut /o
    if ($LASTEXITCODE -ne 0) {
        throw "MakeAppx pack failed with exit code $LASTEXITCODE"
    }

    $SizeMB = [math]::Round((Get-Item $ResolvedOut).Length / 1MB, 2)
    Write-Host "Created MSIX package: $ResolvedOut ($SizeMB MB)"
} finally {
    if (Test-Path $StageDir) {
        Remove-Item -Path $StageDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
