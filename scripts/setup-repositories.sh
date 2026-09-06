#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"

INSTALL_OPTIONAL=true
DRY_RUN=false

for arg in "$@"; do
  case "$arg" in
    --no-optional) INSTALL_OPTIONAL=false ;;
    --dry-run) DRY_RUN=true ;;
    *) printf 'Unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

run() {
  if "$DRY_RUN"; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

command -v jq >/dev/null || { printf 'jq is required\n' >&2; exit 1; }

key_url=$(jq -er '.repositories.vscode.key_url' "$MANIFEST")
code_base_url=$(jq -er '.repositories.vscode.base_url' "$MANIFEST")

if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
  if "$DRY_RUN"; then
    printf '[dry-run] configure the signed Visual Studio Code repository from %s\n' "$code_base_url"
  else
    work_dir=$(mktemp -d)
    trap 'rm -rf -- "$work_dir"' EXIT
    curl --fail --location --proto '=https' --tlsv1.2 "$key_url" --output "$work_dir/microsoft.asc"
    sudo rpm --import "$work_dir/microsoft.asc"
    printf '%s\n' \
      '[code]' \
      'name=Visual Studio Code' \
      "baseurl=$code_base_url" \
      'enabled=1' \
      'autorefresh=1' \
      'type=rpm-md' \
      'gpgcheck=1' \
      "gpgkey=$key_url" >"$work_dir/vscode.repo"
    sudo install -o root -g root -m 0644 "$work_dir/vscode.repo" /etc/yum.repos.d/vscode.repo
  fi
fi

if "$INSTALL_OPTIONAL"; then
  source /etc/os-release
  free_template=$(jq -er '.repositories.rpm_fusion.free_release_url' "$MANIFEST")
  nonfree_template=$(jq -er '.repositories.rpm_fusion.nonfree_release_url' "$MANIFEST")
  free_url=${free_template//%s/$VERSION_ID}
  nonfree_url=${nonfree_template//%s/$VERSION_ID}

  if ! rpm -q rpmfusion-free-release >/dev/null 2>&1 || ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
    run sudo dnf install -y "$free_url" "$nonfree_url"
  fi

  while IFS= read -r copr; do
    run sudo dnf copr enable -y "$copr"
  done < <(jq -er '.repositories.copr[]' "$MANIFEST")

  tailscale_repo_url=$(jq -er '.repositories.tailscale.repo_url' "$MANIFEST")
  if [[ ! -f /etc/yum.repos.d/tailscale.repo ]]; then
    if "$DRY_RUN"; then
      printf '[dry-run] install Tailscale repo file from %s\n' "$tailscale_repo_url"
    else
      : "${work_dir:=$(mktemp -d)}"
      trap 'rm -rf -- "$work_dir"' EXIT
      curl --fail --location --proto '=https' --tlsv1.2 "$tailscale_repo_url" --output "$work_dir/tailscale.repo"
      sudo install -o root -g root -m 0644 "$work_dir/tailscale.repo" /etc/yum.repos.d/tailscale.repo
    fi
  fi

  if command -v flatpak >/dev/null; then
    flathub_url=$(jq -er '.repositories.flathub.remote_url' "$MANIFEST")
    run flatpak remote-add --user --if-not-exists flathub "$flathub_url"
  fi
fi
