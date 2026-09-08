# Visual Studio Code configuration

`.config/Code/User/settings.json` and `.config/Code/User/keybindings.json` are
linked to their matching paths under `~/.config/Code/User/` by GNU Stow through
the setup script.

VS Code extensions are intentionally not installed or managed by this
repository. Extension-specific settings are still kept in `settings.json` so
that the preferred configuration takes effect whenever the corresponding
extension is installed separately.
