#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 || $# -gt 6 ]]; then
  echo "usage: ./build.sh <llvm-ref> <source-dir> <build-dir> <install-dir> [linkage] [macos-deployment-target]" >&2
  exit 1
fi

llvm_ref="$1"
source_dir="$2"
build_dir="$3"
install_dir="$4"
linkage="${5:-Static}"
macos_deployment_target="${6:-11.0}"

targets="X86;AArch64;WebAssembly"
configure_args=(
  -S "$source_dir/llvm"
  -B "$build_dir"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX="$install_dir"
  -DLLVM_ENABLE_ASSERTIONS=OFF
  -DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF
  -DLLVM_ENABLE_PROJECTS=
  -DLLVM_TARGETS_TO_BUILD="$targets"
  -DLLVM_INCLUDE_TESTS=OFF
  -DLLVM_INCLUDE_BENCHMARKS=OFF
  -DLLVM_INCLUDE_EXAMPLES=OFF
  -DLLVM_INCLUDE_DOCS=OFF
  -DLLVM_ENABLE_ZLIB=OFF
  -DLLVM_ENABLE_ZSTD=OFF
  -DLLVM_ENABLE_LIBXML2=OFF
  -DLLVM_ENABLE_TERMINFO=OFF
)

case "$linkage" in
  Static|static)
    configure_args+=(
      -DBUILD_SHARED_LIBS=OFF
      -DLLVM_BUILD_LLVM_DYLIB=OFF
      -DLLVM_BUILD_LLVM_C_DYLIB=OFF
      -DLLVM_LINK_LLVM_DYLIB=OFF
    )
    expected_core_lib="$install_dir/lib/libLLVMCore.a"
    ;;
  Shared|shared)
    configure_args+=(
      -DBUILD_SHARED_LIBS=ON
      -DLLVM_BUILD_LLVM_DYLIB=ON
      -DLLVM_BUILD_LLVM_C_DYLIB=ON
      -DLLVM_LINK_LLVM_DYLIB=ON
    )
    case "$(uname -s)" in
      Darwin)
        expected_core_lib="$install_dir/lib/libLLVM.dylib"
        ;;
      *)
        expected_core_lib="$install_dir/lib/libLLVM.so"
        ;;
    esac
    ;;
  *)
    echo "unsupported linkage: $linkage" >&2
    exit 1
    ;;
esac

if [[ "$(uname -s)" == "Darwin" ]]; then
  configure_args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$macos_deployment_target")
fi

cmake "${configure_args[@]}"

cmake --build "$build_dir" --config Release --target install

if [[ ! -x "$install_dir/bin/llvm-config" && ! -f "$install_dir/bin/llvm-config" ]]; then
  echo "llvm-config not found at $install_dir/bin/llvm-config after build" >&2
  exit 1
fi

if [[ ! -f "$expected_core_lib" ]]; then
  echo "expected LLVM library not found at $expected_core_lib after build" >&2
  exit 1
fi
