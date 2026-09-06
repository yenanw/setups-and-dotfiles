#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"
DRY_RUN=false

case ${1:-} in
  '') ;;
  --dry-run) DRY_RUN=true ;;
  *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2; }

command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }
if ! "$DRY_RUN"; then
  command -v cargo >/dev/null || { printf 'cargo is required\n' >&2; exit 1; }
fi

while IFS=$'\t' read -r crate binary locked; do
  if command -v "$binary" >/dev/null; then
    printf '[setup] %s is already installed\n' "$binary"
    continue
  fi

  cargo_args=(install)
  [[ $locked == true ]] && cargo_args+=(--locked)
  cargo_args+=("$crate")

  if "$DRY_RUN"; then
    printf '[dry-run] cargo'
    printf ' %q' "${cargo_args[@]}"
    printf '\n'
  else
    cargo "${cargo_args[@]}"
  fi
done < <(jq -er '.profiles.optional.cargo[] | [.crate, .binary, (.locked | tostring)] | @tsv' "$MANIFEST")
