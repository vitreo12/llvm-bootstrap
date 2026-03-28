param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$Platform,
    [Parameter(Mandatory = $true)]
    [string]$Architecture,
    [Parameter(Mandatory = $true)]
    [string]$InstallDir,
    [Parameter(Mandatory = $true)]
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$archiveName = "llvm-$Version-$Platform-$Architecture-static.tar.xz"
$archivePath = Join-Path $OutputDir $archiveName

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

tar -cJf $archivePath -C $InstallDir .

if (-not (Test-Path $archivePath)) {
    throw "Failed to produce archive at $archivePath"
}

Write-Host $archivePath
