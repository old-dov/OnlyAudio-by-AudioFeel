[CmdletBinding()]
param(
    [string]$IsccPath,
    [string]$OutputDir,
    [switch]$SkipBuild,
    [switch]$AllowPreview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $PSScriptRoot 'build_windows_release.ps1'
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$defaultOutputDir = Join-Path $repoRoot 'dist'
$publishDir = if ($OutputDir) { $OutputDir } else { $defaultOutputDir }
$portableDir = Join-Path $publishDir 'OnlyAudio'
$installerSource = Join-Path $repoRoot 'installer_output\OnlyAudio_Setup.exe'
$installerTarget = Join-Path $publishDir 'OnlyAudio_Setup.exe'

function Assert-NoSensitiveRepoData {
    param([string]$RepositoryRoot)

    $gitCommand = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCommand) {
        Write-Warning 'Git is unavailable; skipping sensitive file preflight.'
        return
    }

    $statusOutput = & $gitCommand.Source -C $RepositoryRoot status --short --untracked-files=all 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect git status before publishing: $statusOutput"
    }

    $sensitivePattern = '(?i)(playlist|player[_-]?state|shared[_-]?preferences|prefs|user[_-]?data).*(\.json|\.txt|\.m3u8?)$'
    $sensitiveEntries = @($statusOutput | Where-Object {
        $trimmed = $_.Trim()
        if (-not $trimmed) {
            return $false
        }

        $path = if ($trimmed.Length -gt 3) { $trimmed.Substring(3).Trim() } else { $trimmed }
        return $path -match $sensitivePattern
    })

    if ($sensitiveEntries.Count -gt 0) {
        $details = ($sensitiveEntries -join [Environment]::NewLine)
        throw @"
Sensitive user-data files were detected in the repository. Remove them from the commit or add them to .gitignore before publishing.

$details
"@
    }
}

if (-not (Test-Path $buildScript)) {
    throw "Required script not found: '$buildScript'."
}

Assert-NoSensitiveRepoData -RepositoryRoot $repoRoot

$buildParams = @{}
if ($IsccPath) {
    $buildParams.IsccPath = $IsccPath
}
if ($SkipBuild) {
    $buildParams.SkipFlutterBuild = $true
}
if ($AllowPreview) {
    $buildParams.AllowPreview = $true
}

& $buildScript @buildParams
if ($LASTEXITCODE -ne 0) {
    throw 'Windows build or installer compilation failed.'
}

if (-not (Test-Path $releaseDir)) {
    throw "Release directory not found: '$releaseDir'."
}
if (-not (Test-Path $installerSource)) {
    throw "Installer not found: '$installerSource'."
}

New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
if (Test-Path $portableDir) {
    Remove-Item -Path $portableDir -Recurse -Force
}
New-Item -ItemType Directory -Path $portableDir -Force | Out-Null

Copy-Item -Path (Join-Path $releaseDir '*') -Destination $portableDir -Recurse -Force
Copy-Item -Path $installerSource -Destination $installerTarget -Force

Write-Host "Portable app prepared in: $portableDir"
Write-Host "Installer copied to: $installerTarget"
