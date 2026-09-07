#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"
readonly BACKUP_ROOT="$HOME/.local/state/setups-and-dotfiles/backups/$(date +%Y%m%d-%H%M%S)-$$"
DRY_RUN=false

case ${1:-} in
  '') ;;
  --dry-run) DRY_RUN=true ;;
  *) printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { printf 'Usage: %s [--dry-run]\n' "$0" >&2; exit 2; }
[[ $EUID -ne 0 ]] || { printf 'Run this script as your normal user, not as root\n' >&2; exit 1; }

command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }
command -v stow >/dev/null || { printf 'GNU Stow is required\n' >&2; exit 1; }

jq -e '.stow.target == "$HOME" and (.stow.packages | type == "array" and length > 0)' "$MANIFEST" >/dev/null || {
  printf 'Invalid Stow configuration in packages.json\n' >&2
  exit 1
}
stow_relative=$(jq -er '.stow.directory' "$MANIFEST")
[[ $stow_relative != /* && $stow_relative != *..* ]] || { printf 'Unsafe Stow directory in manifest\n' >&2; exit 1; }
readonly STOW_DIR="$REPO_ROOT/$stow_relative"
[[ -d $STOW_DIR ]] || { printf 'Missing Stow directory: %s\n' "$STOW_DIR" >&2; exit 1; }

target_destination() {
  realpath -m -- "$1"
}

declare -a packages=()
declare -a targets=()
declare -a sources=()
declare -a moved_targets=()
declare -a moved_backups=()

restore_backups() {
  local index
  for ((index = ${#moved_targets[@]} - 1; index >= 0; index--)); do
    if [[ ! -e ${moved_targets[$index]} && ! -L ${moved_targets[$index]} ]]; then
      mkdir -p -- "$(dirname -- "${moved_targets[$index]}")"
      mv -- "${moved_backups[$index]}" "${moved_targets[$index]}"
      printf '[setup] Restored %s after Stow failed\n' "${moved_targets[$index]}" >&2
    else
      printf '[setup] Could not restore occupied path %s; backup remains at %s\n' \
        "${moved_targets[$index]}" "${moved_backups[$index]}" >&2
    fi
  done
}

while IFS=$'\t' read -r package target_relative; do
  [[ $package =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] || { printf 'Unsafe Stow package: %s\n' "$package" >&2; exit 1; }
  if [[ -z $target_relative || $target_relative == /* || $target_relative == .. || $target_relative == ../* || $target_relative == */../* || $target_relative == */.. ]]; then
    printf 'Unsafe Stow target: %s\n' "$target_relative" >&2
    exit 1
  fi

  source_path="$STOW_DIR/$package/$target_relative"
  [[ -e $source_path ]] || { printf 'Missing Stow source: %s\n' "$source_path" >&2; exit 1; }
  source_path=$(realpath -e -- "$source_path")
  [[ $source_path == "$STOW_DIR/$package"/* ]] || { printf 'Stow source escapes its package: %s\n' "$source_path" >&2; exit 1; }

  packages+=("$package")
  targets+=("$target_relative")
  sources+=("$source_path")
done < <(jq -er '.stow.packages[] | [.name, .target] | @tsv' "$MANIFEST")

had_conflicts=false
for index in "${!packages[@]}"; do
  target_path="$HOME/${targets[$index]}"
  expected_source=${sources[$index]}

  if [[ -e $target_path || -L $target_path ]] && [[ $(target_destination "$target_path") == "$expected_source" ]]; then
    # Stow does not claim absolute links, including links created by the old
    # helper. Relative links (or paths reached through a folded relative link)
    # are already under Stow's control.
    if [[ ! -L $target_path ]] || [[ $(readlink -- "$target_path") != /* ]]; then
      continue
    fi
  fi

  if [[ -e $target_path || -L $target_path ]]; then
    backup_path="$BACKUP_ROOT/${targets[$index]}"
    had_conflicts=true
    if "$DRY_RUN"; then
      printf '[dry-run] back up %s to %s\n' "$target_path" "$backup_path"
    else
      mkdir -p -- "$(dirname -- "$backup_path")"
      if ! mv -- "$target_path" "$backup_path"; then
        restore_backups
        exit 1
      fi
      moved_targets+=("$target_path")
      moved_backups+=("$backup_path")
      printf '[setup] Backed up %s to %s\n' "${packages[$index]}" "$backup_path"
    fi
  fi
done

stow_command=(stow --dir "$STOW_DIR" --target "$HOME" --restow "${packages[@]}")
if "$DRY_RUN" && "$had_conflicts"; then
  printf '[dry-run]'
  printf ' %q' "${stow_command[@]}"
  printf '\n'
elif "$DRY_RUN"; then
  "${stow_command[@]}" --simulate --verbose=1
else
  if ! "${stow_command[@]}"; then
    restore_backups
    exit 1
  fi
fi

if ! "$DRY_RUN"; then
  for index in "${!packages[@]}"; do
    target_path="$HOME/${targets[$index]}"
    if [[ ! -e $target_path && ! -L $target_path ]] || [[ $(target_destination "$target_path") != "${sources[$index]}" ]]; then
      printf 'Stow did not create the expected link: %s\n' "$target_path" >&2
      exit 1
    fi
  done
  printf '[setup] Stowed %s\n' "${packages[*]}"
fi
