#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"
readonly FONT_DIR="$HOME/.local/share/fonts/FiraCodeNerdFont"
DRY_RUN=false

case ${1:-} in
  '') ;;
  --dry-run) DRY_RUN=true ;;
  *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2; }

command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }

if command -v fc-list >/dev/null && fc-list | grep -Fi 'FiraCode Nerd Font Mono' >/dev/null; then
  printf '[setup] FiraCode Nerd Font is already installed\n'
  exit 0
fi

version=$(jq -er '.downloads.fira_code_nerd_font.version' "$MANIFEST")
archive_template=$(jq -er '.downloads.fira_code_nerd_font.archive_url' "$MANIFEST")
checksums_template=$(jq -er '.downloads.fira_code_nerd_font.checksums_url' "$MANIFEST")
archive_url=${archive_template//%s/$version}
checksums_url=${checksums_template//%s/$version}

if "$DRY_RUN"; then
  printf '[dry-run] download and checksum FiraCode Nerd Font %s into %s\n' "$version" "$FONT_DIR"
  exit 0
fi

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
curl --fail --location --proto '=https' --tlsv1.2 "$archive_url" --output "$work_dir/FiraCode.tar.xz"
curl --fail --location --proto '=https' --tlsv1.2 "$checksums_url" --output "$work_dir/SHA-256.txt"

expected_hash=$(awk '$2 == "FiraCode.tar.xz" || $2 == "*FiraCode.tar.xz" { print $1; exit }' "$work_dir/SHA-256.txt")
[[ $expected_hash =~ ^[[:xdigit:]]{64}$ ]] || { printf 'No valid FiraCode checksum found\n' >&2; exit 1; }
printf '%s  %s\n' "$expected_hash" "$work_dir/FiraCode.tar.xz" | sha256sum --check --status

mkdir -p "$work_dir/extracted" "$FONT_DIR"
tar -xJf "$work_dir/FiraCode.tar.xz" -C "$work_dir/extracted"
find "$work_dir/extracted" -type f \( -name '*.ttf' -o -name '*.otf' \) -exec install -m 0644 -t "$FONT_DIR" {} +
fc-cache -f "$FONT_DIR"
