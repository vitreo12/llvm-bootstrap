#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 5 || $# -gt 7 ]]; then
  echo "usage: ./package.sh <version> <platform> <arch> <install-dir> <output-dir> [linkage] [llvm-ref]" >&2
  exit 1
fi

version="$1"
platform="$2"
arch="$3"
install_dir="$4"
output_dir="$5"
linkage="${6:-Static}"
llvm_ref="${7:-}"

linkage_token="$(printf '%s' "$linkage" | tr '[:upper:]' '[:lower:]')"
archive="$output_dir/llvm-$version-$platform-$arch-$linkage_token.tar.xz"
manifest_dir="$install_dir/share/llvm-bootstrap"
manifest_path="$manifest_dir/BUILDINFO.json"

mkdir -p "$output_dir" "$manifest_dir"

cmake_version="$(cmake --version | head -n 1)"
ninja_version="$(ninja --version | head -n 1)"
llvm_config_version="$("$install_dir/bin/llvm-config" --version)"
compiler_path="$(command -v clang || command -v gcc || command -v cc || true)"
compiler_version=""
if [[ -n "$compiler_path" ]]; then
  compiler_version="$("$compiler_path" --version | head -n 1)"
fi

runner_image=""
if [[ -n "${ImageOS:-}" || -n "${ImageVersion:-}" ]]; then
  runner_image="${ImageOS:-} ${ImageVersion:-}"
  runner_image="${runner_image#"${runner_image%%[![:space:]]*}"}"
  runner_image="${runner_image%"${runner_image##*[![:space:]]}"}"
fi

macos_deployment_target=""
if [[ "$platform" == "macos" ]]; then
  macos_deployment_target="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
fi

export PKG_LLVM_VERSION="$version"
export PKG_LLVM_REF="$llvm_ref"
export PKG_PLATFORM="$platform"
export PKG_ARCH="$arch"
export PKG_LINKAGE="$linkage"
export PKG_ARCHIVE_NAME="$(basename "$archive")"
export PKG_CMAKE_VERSION="$cmake_version"
export PKG_NINJA_VERSION="$ninja_version"
export PKG_LLVM_CONFIG_VERSION="$llvm_config_version"
export PKG_COMPILER_PATH="$compiler_path"
export PKG_COMPILER_VERSION="$compiler_version"
export PKG_RUNNER_IMAGE="$runner_image"
export PKG_MACOS_DEPLOYMENT_TARGET="$macos_deployment_target"

python3 - "$manifest_path" <<'PY'
import json
import os
import platform
import sys

path = sys.argv[1]
data = {
    "package_version": 1,
    "llvm_version": os.environ["PKG_LLVM_VERSION"],
    "llvm_ref": os.environ.get("PKG_LLVM_REF", ""),
    "platform": os.environ["PKG_PLATFORM"],
    "architecture": os.environ["PKG_ARCH"],
    "linkage": os.environ["PKG_LINKAGE"],
    "runtime": "",
    "archive_name": os.environ["PKG_ARCHIVE_NAME"],
    "generator": "Ninja",
    "cmake_version": os.environ["PKG_CMAKE_VERSION"],
    "ninja_version": os.environ["PKG_NINJA_VERSION"],
    "llvm_config_version": os.environ["PKG_LLVM_CONFIG_VERSION"],
    "runner_os": platform.platform(),
    "host_architecture": platform.machine(),
    "compiler_path": os.environ.get("PKG_COMPILER_PATH", ""),
    "compiler_version": os.environ.get("PKG_COMPILER_VERSION", ""),
    "runner_image": os.environ.get("PKG_RUNNER_IMAGE", ""),
    "macos_deployment_target": os.environ.get("PKG_MACOS_DEPLOYMENT_TARGET", ""),
}

with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=False)
    f.write("\n")
PY

rm -f "$archive"
tar -cJf "$archive" -C "$install_dir" .

if [[ ! -f "$archive" ]]; then
  echo "failed to produce archive at $archive" >&2
  exit 1
fi

printf '%s\n' "$archive"
