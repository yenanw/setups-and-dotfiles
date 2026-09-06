# Helper scripts

These scripts are invoked by `../install.sh` and are also safe to run directly.
Each accepts `--dry-run`; `setup-repositories.sh` additionally accepts
`--no-optional`.

- `setup-repositories.sh` configures package sources.
- `install-rust-tools.sh` installs Cargo-managed applications.
- `install-oh-my-zsh.sh` installs Oh My Zsh without executing a remote script.
- `install-fonts.sh` installs and verifies the font required by the configs.
- `link-dotfiles.sh` backs up conflicts and creates the managed symlinks.
