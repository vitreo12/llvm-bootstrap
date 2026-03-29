#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$script_dir"

llvm_ref="$(tr -d '\r\n' < "$repo_root/llvm.version")"
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

rm -rf \
  "$repo_root/llvm-project" \
  "$repo_root/build" \
  "$repo_root/install" \
  "$repo_root/artifacts"

git clone --depth 1 --branch "$llvm_ref" https://github.com/llvm/llvm-project.git "$repo_root/llvm-project"

"$repo_root/build.sh" \
  "$llvm_ref" \
  "$repo_root/llvm-project" \
  "$repo_root/build" \
  "$repo_root/install"

"$repo_root/package.sh" \
  "$version" \
  "$platform" \
  "$arch" \
  "$repo_root/install" \
  "$repo_root/artifacts"
