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

    $missingTools = $requiredTools | Where-Object {
        -not (Get-Command $_ -ErrorAction SilentlyContinue)
    }
    if ($missingTools.Count -ne 0) {
        throw "Visual Studio environment initialized, but required tools are still missing: $($missingTools -join ', '). Install the Windows SDK and C++ build tools."
    }
}

Import-VsDevEnvironment

$llvmRef = (Get-Content .\llvm.version).Trim()
$version = $llvmRef -replace '^llvmorg-',''

if (Test-Path .\llvm-project) { Remove-Item -Recurse -Force .\llvm-project }
if (Test-Path .\build) { Remove-Item -Recurse -Force .\build }
if (Test-Path .\install) { Remove-Item -Recurse -Force .\install }
if (Test-Path .\artifacts) { Remove-Item -Recurse -Force .\artifacts }

git clone --depth 1 --branch $llvmRef https://github.com/llvm/llvm-project.git .\llvm-project

.\build.ps1 `
	-LlvmRef $llvmRef `
	-SourceDir "$PWD\llvm-project" `
	-BuildDir "$PWD\build" `
	-InstallDir "$PWD\install"

.\package.ps1 `
	-Version $version `
	-Platform windows `
	-Architecture x64 `
	-InstallDir "$PWD\install" `
	-OutputDir "$PWD\artifacts"
