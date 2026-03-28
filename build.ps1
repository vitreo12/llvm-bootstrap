param(
    [Parameter(Mandatory = $true)]
    [string]$LlvmRef,
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [Parameter(Mandatory = $true)]
    [string]$BuildDir,
    [Parameter(Mandatory = $true)]
    [string]$InstallDir
)

$ErrorActionPreference = "Stop"

$targets = "X86;AArch64;WebAssembly"
$generator = "Ninja"

cmake -S (Join-Path $SourceDir "llvm") `
    -B $BuildDir `
    -G $generator `
    -DCMAKE_BUILD_TYPE=Release `
    -DCMAKE_INSTALL_PREFIX=$InstallDir `
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON `
    -DLLVM_ENABLE_ASSERTIONS=OFF `
    -DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF `
    -DLLVM_ENABLE_PROJECTS= `
    -DLLVM_TARGETS_TO_BUILD=$targets `
    -DLLVM_INCLUDE_TESTS=OFF `
    -DLLVM_INCLUDE_BENCHMARKS=OFF `
    -DLLVM_INCLUDE_EXAMPLES=OFF `
    -DLLVM_INCLUDE_DOCS=OFF `
    -DLLVM_ENABLE_ZLIB=OFF `
    -DLLVM_ENABLE_ZSTD=OFF `
    -DLLVM_ENABLE_LIBXML2=OFF `
    -DLLVM_ENABLE_TERMINFO=OFF `
    -DLLVM_INSTALL_UTILS=ON `
    -DBUILD_SHARED_LIBS=OFF `
    -DLLVM_BUILD_LLVM_DYLIB=OFF `
    -DLLVM_BUILD_LLVM_C_DYLIB=OFF `
    -DLLVM_LINK_LLVM_DYLIB=OFF

cmake --build $BuildDir --config Release --target INSTALL

$llvmConfig = Join-Path $InstallDir "bin/llvm-config.exe"
if (-not (Test-Path $llvmConfig)) {
    throw "llvm-config.exe not found at $llvmConfig after build"
}

$coreLib = Join-Path $InstallDir "lib/LLVMCore.lib"
if (-not (Test-Path $coreLib)) {
    throw "LLVMCore.lib not found at $coreLib after build"
}
