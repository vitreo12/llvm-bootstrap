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
    [string]$OutputDir,
    [ValidateSet("Static", "Shared")]
    [string]$Linkage = "Static",
    [ValidateSet("MD", "MT")]
    [string]$MsvcRuntime = "MT",
    [string]$LlvmRef = ""
)

$ErrorActionPreference = "Stop"

function Get-FirstLine([string]$Path, [string[]]$Arguments) {
    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()
    try {
        $process = Start-Process `
            -FilePath $Path `
            -ArgumentList $Arguments `
            -NoNewWindow `
            -Wait `
            -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        $stdoutLines = if (Test-Path $stdoutPath) { Get-Content -Path $stdoutPath } else { @() }
        $stderrLines = if (Test-Path $stderrPath) { Get-Content -Path $stderrPath } else { @() }
        $output = @($stdoutLines) + @($stderrLines)

        if ($process.ExitCode -ne 0 -and -not $output) {
            return ""
        }
        return ($output | Select-Object -First 1).ToString().Trim()
    } finally {
        foreach ($tempPath in @($stdoutPath, $stderrPath)) {
            if (Test-Path $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }
    }
}

function Get-ToolVersion([string]$Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        return ""
    }
    return $command.Source
}

$linkageToken = $Linkage.ToLowerInvariant()
$runtimeToken = ""
$archiveName = "llvm-$Version-$Platform-$Architecture-$linkageToken$runtimeToken.zip"
$archivePath = Join-Path $OutputDir $archiveName
$manifestDir = Join-Path $InstallDir "share\llvm-bootstrap"
$manifestPath = Join-Path $manifestDir "BUILDINFO.json"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $manifestDir | Out-Null

$cmakeVersion = Get-FirstLine "cmake" @("--version")
$ninjaVersion = Get-FirstLine "ninja" @("--version")
$clVersion = if (Get-Command "cl.exe" -ErrorAction SilentlyContinue) { Get-FirstLine "cmd.exe" @("/d", "/c", "cl.exe /Bv") } else { "" }
$linkVersion = if (Get-Command "link.exe" -ErrorAction SilentlyContinue) { Get-FirstLine "cmd.exe" @("/d", "/c", "link.exe") } else { "" }

$manifest = [ordered]@{
    package_version = 1
    llvm_version = $Version
    llvm_ref = $LlvmRef
    platform = $Platform
    architecture = $Architecture
    linkage = $Linkage
    runtime = if ($Platform -eq "windows") { $MsvcRuntime } else { "" }
    archive_name = $archiveName
    generator = "Ninja"
    cmake_version = $cmakeVersion
    ninja_version = $ninjaVersion
    llvm_config_version = Get-FirstLine (Join-Path $InstallDir "bin\llvm-config.exe") @("--version")
    runner_os = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    host_architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    visual_studio_version = $env:VisualStudioVersion
    vc_tools_version = $env:VCToolsVersion
    vc_tools_install_dir = $env:VCToolsInstallDir
    windows_sdk_version = $env:WindowsSDKVersion
    windows_sdk_dir = $env:WindowsSdkDir
    cl_path = Get-ToolVersion "cl.exe"
    cl_version = $clVersion
    link_path = Get-ToolVersion "link.exe"
    link_version = $linkVersion
    cmake_msvc_runtime_library = if ($Platform -eq "windows") {
        if ($MsvcRuntime -eq "MT") { "MultiThreaded" } else { "MultiThreadedDLL" }
    } else {
        ""
    }
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding utf8

if (Test-Path $archivePath) {
    Remove-Item $archivePath -Force
}

Compress-Archive -Path (Join-Path $InstallDir "*") -DestinationPath $archivePath -CompressionLevel Optimal

if (-not (Test-Path $archivePath)) {
    throw "Failed to produce archive at $archivePath"
}

Write-Host $archivePath
