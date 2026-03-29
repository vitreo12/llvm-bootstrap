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

$archiveName = "llvm-$Version-$Platform-$Architecture-static.zip"
$archivePath = Join-Path $OutputDir $archiveName

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

Compress-Archive -Path (Join-Path $InstallDir "*") -DestinationPath $archivePath -CompressionLevel Optimal

if (-not (Test-Path $archivePath)) {
    throw "Failed to produce archive at $archivePath"
}

Write-Host $archivePath
