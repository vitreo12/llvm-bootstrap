#!/usr/bin/env bash
set -euo pipefail

llvm_ref=""
source_dir=""
build_dir=""
install_dir=""
output_dir=""
linkage="Static"
package=0

usage() {
  cat <<'EOF'
Usage: ./build_local.sh [options]

Options:
  --llvm-ref <ref>         LLVM ref to build. Defaults to llvm.version.
  --source-dir <path>      Source checkout directory. Defaults to ./llvm-project
  --build-dir <path>       Build directory. Defaults to ./build
  --install-dir <path>     Install directory. Defaults to ./install
  --output-dir <path>      Package output directory. Defaults to ./artifacts
  --linkage <Static|Shared>
  --package                Also package the install after building
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --llvm-ref)
      llvm_ref="${2:-}"
      shift 2
      ;;
    --source-dir)
      source_dir="${2:-}"
      shift 2
      ;;
    --build-dir)
      build_dir="${2:-}"
      shift 2
      ;;
    --install-dir)
      install_dir="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    --linkage)
      linkage="${2:-}"
      shift 2
      ;;
    --package)
      package=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$linkage" in
  Static|Shared) ;;
  *)
    echo "Invalid --linkage '$linkage' (expected Static or Shared)" >&2
    exit 1
    ;;
esac

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"

if [[ -z "$llvm_ref" ]]; then
  llvm_ref="$(tr -d '\r\n' < "$repo_root/llvm.version")"
fi
if [[ -z "$llvm_ref" ]]; then
  echo "llvm.version is empty" >&2
  exit 1
fi

version="${llvm_ref#llvmorg-}"

case "$(uname -s)" in
  Linux)
    platform="linux"
    ;;
  Darwin)
    platform="macos"
    ;;
  *)
    echo "unsupported host platform: $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64)
    arch="x64"
    ;;
  arm64|aarch64)
    arch="arm64"
    ;;
  *)
    echo "unsupported host architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

source_dir="${source_dir:-$repo_root/llvm-project}"
build_dir="${build_dir:-$repo_root/build}"
install_dir="${install_dir:-$repo_root/install}"
output_dir="${output_dir:-$repo_root/artifacts}"

rm -rf "$source_dir" "$build_dir" "$install_dir"
if [[ $package -eq 1 ]]; then
  rm -rf "$output_dir"
fi

git clone --depth 1 --branch "$llvm_ref" https://github.com/llvm/llvm-project.git "$source_dir"

"$repo_root/build.sh" \
  "$llvm_ref" \
  "$source_dir" \
  "$build_dir" \
  "$install_dir" \
  "$linkage" \
  "11.0"

if [[ $package -eq 1 ]]; then
  "$repo_root/package.sh" \
    "$version" \
    "$platform" \
    "$arch" \
    "$install_dir" \
    "$output_dir" \
    "$linkage" \
    "$llvm_ref"
fi
