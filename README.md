# Setups and Dotfiles

Personal repository for my commonly used tools and my configurations for them.

All scripts in this repository assume you have a [Fedora Linux](https://fedoraproject.org/)
distro installed, e.g., Fedora 44 or something modern.

## Structure

### `install.sh`

The main install script. When run without any argument provided, it will
install and set up configuration files (if present) for all tools and packages
listed below, including the optional ones.

Arguments:

- `--no-optional` - install only the must-have tools
- `--no-config` - do not copy over configuration files from the `dotfiles/`
                  folder

### `packages.json`

### `dotfiles/`

### `scripts/`

## Installed tools/dependencies descriptions

### CLI tools/applications

Ensure the following are **ALWAYS** installed:

- git
- tmux - kinda must have for working with more complex projects
- jq - JSON processing, also because `install.sh` depends on it

Good to haves:

- ripgrep - for searching source trees
- fd - nicer `find`
- fzf - fuzzy finder
- termscp - nice TUI for file tranfers between local and remote
- lazygit - fantastic TUI for git
- yazi - terminal file manager
- xclip - clipboard tool

### Development environments

Base tools (must have):

- vim - for very light editing
- neovim - for heavier editing when I don't want GUI
- code - VSCode for main development
- python - my main development programming language
- alacritty - my choice of terminal simulator

Useful tools for aesthetics or convenience:

- uv - Python package manager
- zsh - more customizable than bash
- oh-my-zsh - must-have if zsh is used
- LazyVim - easy and very reasonable neovim default setup + very customizable

Optional, only needed for specific tasks:

- tailscale - requied if need to SSH between laptops (my setup is unfortunately
              rather scuffed)

Also, for writing papers locally, [Tex Live](https://www.tug.org/texlive/) need
to be installed.

## Fedora Linux nuances

1. Remembeer to enable the [RPM Fusion](https://rpmfusion.org/) packages.
2. If you somehow missed it, set up [Flathub here](https://flathub.org/en/setup/Fedora).
3. To install `termscp` on Fedora, you need the a lot of libraries from Perl
   standard library. So it is easiest to install the `perl.core` package first.
