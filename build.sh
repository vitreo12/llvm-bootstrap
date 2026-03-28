#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: ./build.sh <llvm-ref> <source-dir> <build-dir> <install-dir>" >&2
  exit 1
fi

llvm_ref="$1"
source_dir="$2"
build_dir="$3"
install_dir="$4"

targets="X86;AArch64;WebAssembly"

cmake \
  -S "$source_dir/llvm" \
  -B "$build_dir" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$install_dir" \
  -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON \
  -DLLVM_ENABLE_ASSERTIONS=OFF \
  -DLLVM_ABI_BREAKING_CHECKS=FORCE_OFF \
  -DLLVM_ENABLE_PROJECTS= \
  -DLLVM_TARGETS_TO_BUILD="$targets" \
  -DLLVM_INCLUDE_TESTS=OFF \
  -DLLVM_INCLUDE_BENCHMARKS=OFF \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_DOCS=OFF \
  -DLLVM_ENABLE_ZLIB=OFF \
  -DLLVM_ENABLE_ZSTD=OFF \
  -DLLVM_ENABLE_LIBXML2=OFF \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DLLVM_INSTALL_UTILS=ON \
  -DBUILD_SHARED_LIBS=OFF \
  -DLLVM_BUILD_LLVM_DYLIB=OFF \
  -DLLVM_BUILD_LLVM_C_DYLIB=OFF \
  -DLLVM_LINK_LLVM_DYLIB=OFF

cmake --build "$build_dir" --config Release --target install

if [[ ! -x "$install_dir/bin/llvm-config" && ! -f "$install_dir/bin/llvm-config" ]]; then
  echo "llvm-config not found at $install_dir/bin/llvm-config after build" >&2
  exit 1
fi

if [[ ! -f "$install_dir/lib/libLLVMCore.a" ]]; then
  echo "libLLVMCore.a not found at $install_dir/lib/libLLVMCore.a after build" >&2
  exit 1
fi
