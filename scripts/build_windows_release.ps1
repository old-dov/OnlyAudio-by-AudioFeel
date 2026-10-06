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

    # Windows PowerShell exposes native stderr as an ErrorRecord. With the
    # script-wide Stop preference, ISCC's help banner would otherwise abort
    # the build before its output can be inspected.
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $banner = & $CompilerPath '/?' 2>&1 | Out-String
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if (-not $banner) {
        throw "Unable to read the Inno Setup banner from '$CompilerPath'."
    }

    # ISCC /? identifies the major version but omits preview qualifiers.
    # Installed preview builds expose the full version in the uninstall entry.
    $compilerDirectory = [IO.Path]::GetFullPath((Split-Path -Parent $CompilerPath)).TrimEnd('\')
    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $installedCompiler = Get-ItemProperty $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object {
            $installLocationProperty = $_.PSObject.Properties['InstallLocation']
            if (-not $installLocationProperty -or -not $installLocationProperty.Value) {
                return $false
            }

            try {
                return [IO.Path]::GetFullPath($installLocationProperty.Value).TrimEnd('\') -eq $compilerDirectory
            }
            catch {
                return $false
            }
        } |
        Select-Object -First 1

    if ($installedCompiler) {
        $banner = "$banner`n$($installedCompiler.DisplayName)`n$($installedCompiler.DisplayVersion)"
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
