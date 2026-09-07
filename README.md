# Setups and Dotfiles

Personal repository for the tools and configurations I commonly use.

The scripts target Fedora Workstation 40 or newer and are currently maintained
on Fedora 44. Run the installer as a normal user with `sudo` access:

```bash
./install.sh
```

The default installation includes every tool below, including TeX Live and
Tailscale. It can therefore download several gigabytes.

## Installer options

- `--no-optional` installs only the required toolchain.
- `--no-config` skips dotfile symlinks, the config-only font asset, and the
  login-shell change.
- `--dry-run` prints the work without changing the machine.
- `--help` displays the command summary.

Options may be combined, for example:

```bash
./install.sh --no-optional --no-config
```

The installer is idempotent: package-manager operations can be repeated, tools
that are already present are skipped where appropriate, and an existing config
is never discarded. Before replacing a config path, `link-dotfiles.sh` moves it
under `~/.local/state/setups-and-dotfiles/backups/<timestamp>/`.

## Repository structure

### `install.sh`

The entry point. It validates Fedora, bootstraps `jq`, reads `packages.json`,
installs the selected packages, invokes focused helper scripts, and links the
dotfiles.

### `packages.json`

The machine-readable inventory of Fedora packages, external repositories,
Cargo applications, verified downloads, and dotfile mappings. Package names are
the actual Fedora names (for example, `vim-enhanced` provides Vim, `fd-find`
provides `fd`, and `python-unversioned-command` provides `python`).

### `dotfiles/`

Tracked configurations for Git, tmux, Vim, Neovim/LazyVim, VS Code, Alacritty,
Yazi, and Zsh. The installer creates absolute symlinks from their standard
locations to these files.

### `scripts/`

Small helpers for repositories, Cargo tools, Oh My Zsh, fonts, and dotfile
linking. See `scripts/README.md`.

## Installed tools and dependencies

### Required

- CLI tools: Git, tmux, and `jq`.
- Editors and applications: Vim, Neovim with LazyVim, Visual Studio Code,
  Python, and Alacritty.
- Build/bootstrap tools: Rust, Cargo, GCC/G++, Make, cURL, CA certificates,
  `pip`, Flatpak, and Fedora's DNF plugins.

### Optional (installed by default)

- CLI conveniences: ripgrep, `fd`, `fzf`, Termscp, Lazygit, Yazi, `xclip`,
  `zoxide`, and GitHub CLI.
- Development conveniences: `uv`, Zsh, Oh My Zsh, and the FiraCode Nerd Font
  used by Alacritty, VS Code, and LazyVim.
- Task-specific tools: Tailscale and the full Fedora TeX Live scheme.

LazyVim bootstraps its plugins on the first Neovim launch. Run `:LazyHealth`
after that first launch. Tailscale's service is enabled by the installer, but
device authentication remains explicit; run `sudo tailscale up` when ready.

## Fedora-specific details

The installer configures the following sources only when they are needed:

- Microsoft's signed RPM repository for Visual Studio Code.
- RPM Fusion free and nonfree plus a per-user Flathub remote during the optional
  installation.
- Tailscale's stable Fedora repository.
- The `dejan/lazygit` and `lihaohong/yazi` Fedora COPRs recommended in those
  projects' Fedora installation instructions.

Termscp is built with Cargo. Its Fedora build/runtime dependencies include
Perl, D-Bus, `pkg-config`, OpenSSL, and Samba client libraries; these are listed
explicitly in `packages.json`. Fedora 44 no longer provides a package named
`perl-core`, so the `perl` package is used instead.
