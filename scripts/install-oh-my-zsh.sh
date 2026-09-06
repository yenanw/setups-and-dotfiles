#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"
readonly DESTINATION="$HOME/.oh-my-zsh"
DRY_RUN=false

case ${1:-} in
  '') ;;
  --dry-run) DRY_RUN=true ;;
  *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2; }

command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }

if [[ -d $DESTINATION/.git ]]; then
  printf '[setup] Oh My Zsh is already installed\n'
  exit 0
fi

if [[ -e $DESTINATION || -L $DESTINATION ]]; then
  printf 'Refusing to replace non-git path: %s\n' "$DESTINATION" >&2
  exit 1
fi

git_url=$(jq -er '.downloads.oh_my_zsh.git_url' "$MANIFEST")
branch=$(jq -er '.downloads.oh_my_zsh.branch' "$MANIFEST")

if "$DRY_RUN"; then
  printf '[dry-run] git clone --depth=1 --branch %q %q %q\n' "$branch" "$git_url" "$DESTINATION"
else
  git clone --depth=1 --branch "$branch" "$git_url" "$DESTINATION"
fi
