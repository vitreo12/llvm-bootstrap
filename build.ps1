param(
    [Parameter(Mandatory = $true)]
    [string]$LlvmRef,
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [Parameter(Mandatory = $true)]
    [string]$BuildDir,
    [Parameter(Mandatory = $true)]
    [string]$InstallDir,
    [ValidateSet("Static", "Shared")]
    [string]$Linkage = "Static",
    [ValidateSet("MD", "MT")]
    [string]$MsvcRuntime = "MT"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSNativeCommandUseErrorActionPreference = $true
}

$targets = "X86;AArch64;WebAssembly"
$generator = "Ninja"
$llvmSourceDir = Join-Path $SourceDir "llvm"
$runningOnWindows = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
    [System.Runtime.InteropServices.OSPlatform]::Windows
)

$shared = $Linkage -eq "Shared"
$cmakeRuntime = switch ($MsvcRuntime) {
    "MT" { "MultiThreaded" }
    "MD" { "MultiThreadedDLL" }
    default { throw "Unsupported MSVC runtime mode: $MsvcRuntime" }
}

$configureArgs = @(
    "-Wno-dev",
    "-S", $llvmSourceDir,
    "-B", $BuildDir,
    "-G", $generator,
    "-DCMAKE_BUILD_TYPE=Release",
    "-DCMAKE_INSTALL_PREFIX=$InstallDir",
    "-DLLVM_ENABLE_ASSERTIONS=OFF",
    "-DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF",
    "-DLLVM_ENABLE_PROJECTS=",
    "-DLLVM_TARGETS_TO_BUILD=$targets",
    "-DLLVM_INCLUDE_TESTS=OFF",
    "-DLLVM_INCLUDE_BENCHMARKS=OFF",
    "-DLLVM_INCLUDE_EXAMPLES=OFF",
    "-DLLVM_INCLUDE_DOCS=OFF",
    "-DLLVM_ENABLE_ZLIB=OFF",
    "-DLLVM_ENABLE_ZSTD=OFF",
    "-DLLVM_ENABLE_LIBXML2=OFF"
)

if ($shared) {
    $configureArgs += @(
        "-DBUILD_SHARED_LIBS=ON",
        "-DLLVM_BUILD_LLVM_DYLIB=ON",
        "-DLLVM_BUILD_LLVM_C_DYLIB=ON",
        "-DLLVM_LINK_LLVM_DYLIB=ON"
    )
} else {
    $configureArgs += @(
        "-DBUILD_SHARED_LIBS=OFF",
        "-DLLVM_BUILD_LLVM_DYLIB=OFF",
        "-DLLVM_BUILD_LLVM_C_DYLIB=OFF",
        "-DLLVM_LINK_LLVM_DYLIB=OFF"
    )
}

if ($runningOnWindows) {
    $configureArgs += "-DCMAKE_MSVC_RUNTIME_LIBRARY=$cmakeRuntime"
} else {
    $configureArgs += "-DLLVM_ENABLE_TERMINFO=OFF"
}

cmake @configureArgs
if ($LASTEXITCODE -ne 0) {
    throw "CMake configure failed with exit code $LASTEXITCODE"
}

cmake --build $BuildDir --config Release --target install
if ($LASTEXITCODE -ne 0) {
    throw "CMake build failed with exit code $LASTEXITCODE"
}

$llvmConfig = Join-Path $InstallDir "bin/llvm-config.exe"
if (-not (Test-Path $llvmConfig)) {
    throw "llvm-config.exe not found at $llvmConfig after build"
}

$coreLib = if ($shared) {
    Join-Path $InstallDir "lib/LLVM.lib"
} else {
    Join-Path $InstallDir "lib/LLVMCore.lib"
}

if (-not (Test-Path $coreLib)) {
    throw "Expected LLVM library not found at $coreLib after build"
}
