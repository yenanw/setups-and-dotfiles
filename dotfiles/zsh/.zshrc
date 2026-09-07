# Oh My Zsh lives outside this repository and is installed by install.sh.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="crcandy"
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"
HIST_STAMPS="yyyy-mm-dd"

plugins=(git gh fzf)

source "$ZSH/oh-my-zsh.sh"

# User-level configs

# User-local package managers and programs.
export PATH="$HOME/.cargo/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Set up default editor variable for programs that use them
export EDITOR=nvim
export VISUAL=nvim

eval "$(zoxide init zsh)"
