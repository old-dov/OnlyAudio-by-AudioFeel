[CmdletBinding()]
param(
    [string]$IsccPath,
    [switch]$SkipFlutterBuild,
    [switch]$AllowPreview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$installerScript = Join-Path $repoRoot 'installer.iss'
$defaultIsccPath = 'C:\Program Files\Inno Setup 7\ISCC.exe'

function Resolve-IsccPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        return $ExplicitPath
    }

    if ($env:ONLYAUDIO_ISCC_PATH) {
        return $env:ONLYAUDIO_ISCC_PATH
    }

    return $defaultIsccPath
}

function Get-IsccBanner {
    param([string]$CompilerPath)

    $banner = & $CompilerPath '/?' 2>&1 | Out-String
    if (-not $banner) {
        throw "Unable to read the Inno Setup banner from '$CompilerPath'."
    }

    return $banner
}

$resolvedIsccPath = Resolve-IsccPath -ExplicitPath $IsccPath
if (-not (Test-Path $resolvedIsccPath)) {
    throw "ISCC.exe not found at '$resolvedIsccPath'. Pass -IsccPath or set ONLYAUDIO_ISCC_PATH."
}

$banner = Get-IsccBanner -CompilerPath $resolvedIsccPath
$isPreview = $banner -match '(?i)preview'

if ($isPreview -and -not $AllowPreview) {
    throw @"
The selected Inno Setup compiler appears to be a preview build:
$resolvedIsccPath

Use a stable ISCC.exe path with -IsccPath or ONLYAUDIO_ISCC_PATH.
If you intentionally want to use the preview compiler, rerun with -AllowPreview.
"@
}

Push-Location $repoRoot
try {
    if (-not $SkipFlutterBuild) {
        Write-Host 'Building Windows release with puro flutter...'
        & puro flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw 'Flutter Windows release build failed.'
        }
    }

    Write-Host "Compiling installer with $resolvedIsccPath"
    & $resolvedIsccPath $installerScript
    if ($LASTEXITCODE -ne 0) {
        throw 'Inno Setup compilation failed.'
    }
}
finally {
    Pop-Location
}

$installerOutput = Join-Path $repoRoot 'installer_output\OnlyAudio_Setup.exe'
if (Test-Path $installerOutput) {
    Write-Host "Installer created: $installerOutput"
} else {
    throw "Installer build finished but '$installerOutput' was not found."
}
