#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly MANIFEST="$REPO_ROOT/packages.json"
readonly TARGET_USER="$(id -un)"

INSTALL_OPTIONAL=true
INSTALL_CONFIG=true
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--no-optional] [--no-config] [--dry-run] [--help]

Install the tools and personal configuration in this repository on Fedora.

  --no-optional  Install only the required tools
  --no-config    Do not link dotfiles or install config-only assets
  --dry-run      Print the actions that would be taken
  -h, --help     Show this help
EOF
}

log() {
  printf '[setup] %s\n' "$*"
}

die() {
  printf '[setup] error: %s\n' "$*" >&2
  exit 1
}

run() {
  if "$DRY_RUN"; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --no-optional) INSTALL_OPTIONAL=false ;;
    --no-config) INSTALL_CONFIG=false ;;
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown argument: $arg"
      ;;
  esac
done

[[ $EUID -ne 0 ]] || die "run this script as your normal user, not as root"
[[ -r /etc/os-release ]] || die "cannot identify the operating system"

# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == fedora ]] || die "Fedora Workstation is required (found ${ID:-unknown})"
[[ -f $MANIFEST ]] || die "missing package manifest: $MANIFEST"

minimum_version=$(sed -n 's/.*"minimum_version"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$MANIFEST" | head -n 1)
[[ ${VERSION_ID%%.*} -ge ${minimum_version:-40} ]] || die "Fedora ${minimum_version:-40} or newer is required"

if ! "$DRY_RUN"; then
  command -v sudo >/dev/null || die "sudo is required"
  log "Refreshing sudo credentials"
  sudo -v
fi

# jq is both a managed package and the manifest reader, so bootstrap it first.
if ! command -v jq >/dev/null; then
  log "Bootstrapping jq"
  run sudo dnf install -y jq
fi

if "$DRY_RUN" && ! command -v jq >/dev/null; then
  die "jq is needed to resolve packages during a dry run"
fi

jq -e '
  .schema_version == 1 and
  .platform.distribution == "fedora" and
  (.profiles.required.dnf | type == "array") and
  (.profiles.required.repository_packages | type == "array") and
  (.profiles.optional.dnf | type == "array") and
  (.profiles.optional.repository_packages | type == "array") and
  (.profiles.optional.cargo | type == "array") and
  (.stow.directory | type == "string") and
  .stow.target == "$HOME" and
  (.stow.packages | type == "array")
' "$MANIFEST" >/dev/null || die "packages.json does not match schema version 1"

mapfile -t required_packages < <(jq -er '.profiles.required.dnf[]' "$MANIFEST")
mapfile -t required_repo_packages < <(jq -er '.profiles.required.repository_packages[]' "$MANIFEST")

for package_name in "${required_packages[@]}" "${required_repo_packages[@]}"; do
  [[ $package_name =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] || die "unsafe package name in manifest: $package_name"
done

log "Installing required Fedora packages"
run sudo dnf install -y "${required_packages[@]}"

repo_args=()
"$INSTALL_OPTIONAL" || repo_args+=(--no-optional)
"$DRY_RUN" && repo_args+=(--dry-run)
"$REPO_ROOT/scripts/setup-repositories.sh" "${repo_args[@]}"

log "Installing packages from configured repositories"
run sudo dnf install -y "${required_repo_packages[@]}"

if "$INSTALL_OPTIONAL"; then
  mapfile -t optional_packages < <(jq -er '.profiles.optional.dnf[]' "$MANIFEST")
  mapfile -t optional_repo_packages < <(jq -er '.profiles.optional.repository_packages[]' "$MANIFEST")

  for package_name in "${optional_packages[@]}" "${optional_repo_packages[@]}"; do
    [[ $package_name =~ ^[a-zA-Z0-9][a-zA-Z0-9+_.-]*$ ]] || die "unsafe package name in manifest: $package_name"
  done

  log "Installing optional Fedora packages (TeX Live may take a while)"
  run sudo dnf install -y "${optional_packages[@]}" "${optional_repo_packages[@]}"

  rust_args=()
  "$DRY_RUN" && rust_args+=(--dry-run)
  "$REPO_ROOT/scripts/install-rust-tools.sh" "${rust_args[@]}"

  omz_args=()
  "$DRY_RUN" && omz_args+=(--dry-run)
  "$REPO_ROOT/scripts/install-oh-my-zsh.sh" "${omz_args[@]}"

  if "$DRY_RUN"; then
    log "Would enable and start tailscaled"
    "$INSTALL_CONFIG" && log "Would set zsh as the login shell for $TARGET_USER"
  else
    sudo systemctl enable --now tailscaled
    if "$INSTALL_CONFIG"; then
      zsh_path=$(command -v zsh)
      if [[ ${SHELL:-} != "$zsh_path" ]]; then
        sudo usermod --shell "$zsh_path" "$TARGET_USER"
        log "Login shell changed to $zsh_path; it takes effect at your next login"
      fi
    fi
  fi
fi

if "$INSTALL_CONFIG"; then
  font_args=()
  "$DRY_RUN" && font_args+=(--dry-run)
  "$REPO_ROOT/scripts/install-fonts.sh" "${font_args[@]}"

  stow_args=()
  "$DRY_RUN" && stow_args+=(--dry-run)
  "$REPO_ROOT/scripts/stow-dotfiles.sh" "${stow_args[@]}"
fi

log "Setup complete"
if "$INSTALL_OPTIONAL"; then
  log "Run 'sudo tailscale up' when you are ready to authenticate this device"
fi
