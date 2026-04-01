param(
    [string]$LlvmRef = "",
    [string]$SourceDir = "",
    [string]$BuildDir = "",
    [string]$InstallDir = "",
    [string]$OutputDir = "",
    [ValidateSet("Static", "Shared")]
    [string]$Linkage = "Static",
    [ValidateSet("MD", "MT")]
    [string]$MsvcRuntime = "MT",
    [switch]$Package
)

function Import-VsDevEnvironment {
    $requiredTools = @("cl", "link", "rc", "mt")
    $missingTools = $requiredTools | Where-Object {
        -not (Get-Command $_ -ErrorAction SilentlyContinue)
    }
    if ($missingTools.Count -eq 0) {
        return
    }

    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw "vswhere.exe not found at $vswhere. Open a Visual Studio x64 Developer PowerShell or install Visual Studio 2022 Build Tools with the Windows SDK."
    }

    $installationPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($installationPath)) {
        throw "Unable to locate a Visual Studio installation with C++ build tools. Open a Visual Studio x64 Developer PowerShell or install Visual Studio 2022 Build Tools with the Windows SDK."
    }

    $vsDevCmd = Join-Path $installationPath "Common7\Tools\VsDevCmd.bat"
    if (-not (Test-Path $vsDevCmd)) {
        throw "VsDevCmd.bat not found at $vsDevCmd"
    }

    $envDump = & cmd.exe /s /c "`"$vsDevCmd`" -arch=x64 -host_arch=x64 >nul && set"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to initialize the Visual Studio developer environment from $vsDevCmd"
    }

    foreach ($line in $envDump) {
        if ($line -notmatch "^[^=]+=") {
            continue
        }

        $name, $value = $line -split "=", 2
        Set-Item -Path "Env:$name" -Value $value
    }
}

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $true
}

Import-VsDevEnvironment

$repoRoot = Resolve-Path .
if ([string]::IsNullOrWhiteSpace($LlvmRef)) {
    $LlvmRef = (Get-Content (Join-Path $repoRoot "llvm.version")).Trim()
}

if ([string]::IsNullOrWhiteSpace($LlvmRef)) {
    throw "llvm.version is empty"
}

$version = $LlvmRef -replace '^llvmorg-',''
$linkageLower = $Linkage.ToLowerInvariant()

if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    $SourceDir = Join-Path $repoRoot "llvm-project"
}
if ([string]::IsNullOrWhiteSpace($BuildDir)) {
    $BuildDir = Join-Path $repoRoot "build"
}
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $repoRoot "install"
}
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "artifacts"
}

if (Test-Path $SourceDir) { Remove-Item -Recurse -Force $SourceDir }
if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
if ($Package -and (Test-Path $OutputDir)) { Remove-Item -Recurse -Force $OutputDir }

git clone --depth 1 --branch $LlvmRef https://github.com/llvm/llvm-project.git $SourceDir
if ($LASTEXITCODE -ne 0) {
    throw "Failed to clone llvm-project"
}

.\build.ps1 `
    -LlvmRef $LlvmRef `
    -SourceDir $SourceDir `
    -BuildDir $BuildDir `
    -InstallDir $InstallDir `
    -Linkage $Linkage `
    -MsvcRuntime $MsvcRuntime

if ($Package) {
    .\package.ps1 `
        -Version $version `
        -Platform windows `
        -Architecture x64 `
        -InstallDir $InstallDir `
        -OutputDir $OutputDir `
        -Linkage $Linkage `
        -MsvcRuntime $MsvcRuntime `
        -LlvmRef $LlvmRef
}
