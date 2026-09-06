#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"
readonly BACKUP_ROOT="$HOME/.local/state/setups-and-dotfiles/backups/$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false

case ${1:-} in
  '') ;;
  --dry-run) DRY_RUN=true ;;
  *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2; }

command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }

while IFS=$'\t' read -r name source_relative target_relative; do
  for relative_path in "$source_relative" "$target_relative"; do
    if [[ -z $relative_path || $relative_path == /* || $relative_path == .. || $relative_path == ../* || $relative_path == */../* || $relative_path == */.. ]]; then
      printf 'Unsafe relative path in manifest: %s\n' "$relative_path" >&2
      exit 1
    fi
  done

  source_path="$REPO_ROOT/$source_relative"
  target_path="$HOME/$target_relative"
  backup_path="$BACKUP_ROOT/$target_relative"

  [[ -e $source_path ]] || { printf 'Missing dotfile source: %s\n' "$source_path" >&2; exit 1; }
  source_path=$(realpath -e -- "$source_path")
  [[ $source_path == "$REPO_ROOT"/* ]] || { printf 'Dotfile source escapes repository: %s\n' "$source_path" >&2; exit 1; }

  if [[ -L $target_path ]] && [[ $(readlink -- "$target_path") == "$source_path" ]]; then
    printf '[setup] %s is already linked\n' "$name"
    continue
  fi

  if "$DRY_RUN"; then
    if [[ -e $target_path || -L $target_path ]]; then
      printf '[dry-run] back up %s to %s\n' "$target_path" "$backup_path"
    fi
    printf '[dry-run] link %s -> %s\n' "$target_path" "$source_path"
    continue
  fi

  mkdir -p -- "$(dirname -- "$target_path")"
  if [[ -e $target_path || -L $target_path ]]; then
    mkdir -p -- "$(dirname -- "$backup_path")"
    mv -- "$target_path" "$backup_path"
    printf '[setup] Backed up %s to %s\n' "$name" "$backup_path"
  fi
  ln -s -- "$source_path" "$target_path"
  printf '[setup] Linked %s\n' "$name"
done < <(jq -er '.dotfiles[] | [.name, .source, .target] | @tsv' "$MANIFEST")
