#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: ./package.sh <version> <platform> <arch> <install-dir> <output-dir>" >&2
  exit 1
fi

version="$1"
platform="$2"
arch="$3"
install_dir="$4"
output_dir="$5"

mkdir -p "$output_dir"

archive="$output_dir/llvm-$version-$platform-$arch-static.tar.xz"
rm -f "$archive"
tar -cJf "$archive" -C "$install_dir" .

if [[ ! -f "$archive" ]]; then
  echo "failed to produce archive at $archive" >&2
  exit 1
fi

printf '%s\n' "$archive"
