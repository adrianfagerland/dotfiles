# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# ssh-agent: on Linux use XDG_RUNTIME_DIR socket; on macOS, launchd provides one.
if [[ "$OSTYPE" == linux* ]] && [[ -n "$XDG_RUNTIME_DIR" ]]; then
  export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket
  if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)" > /dev/null
  fi
fi

[[ -f ~/.ssh/id_ed25519 ]] && ssh-add ~/.ssh/id_ed25519 2>/dev/null
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

zstyle ':omz:plugins:nvm' autoload yes
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git
 extract
 thefuck
 jsontools
 colored-man-pages
 zsh-autosuggestions
 zsh-syntax-highlighting
 zsh-history-substring-search
 you-should-use
 nvm)
[[ "$OSTYPE" == linux* ]] && plugins+=(debian)

export ZSH_COMPDUMP=$ZSH/cache/.zcompdump-$HOST
source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

. "$HOME/.cargo/env"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

alias spt=spotify_player
alias venv='source .venv/bin/activate'
# . "/home/adrian/.deno/env"

bindkey '`' autosuggest-accept
bindkey -M viins '^[b' vi-backward-word
bindkey -M viins '^[f' vi-forward-word

alias v='vim'
if [[ "$OSTYPE" == darwin* ]]; then
  alias o='open'
  alias sov='pmset sleepnow'
  alias bye='sudo shutdown -h now'
  alias ciao='sudo shutdown -h now'
else
  alias o='xdg-open'
  alias open='xdg-open'
  alias sov='systemctl sleep'
  alias bye='shutdown now'
  alias ciao='shutdown now'
fi

alias c='claude --dangerously-skip-permissions'

# Google Cloud SDK
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/google-cloud-sdk/completion.zsh.inc"; fi

eval "$(uv generate-shell-completion zsh)"
eval "$(uvx --generate-shell-completion zsh)"

alias dotfiles='git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Checklist parallel checkout navigation
alias za="cd $HOME/vedtak/checklist-a"
alias zb="cd $HOME/vedtak/checklist-b"
alias zc="cd $HOME/vedtak/checklist-c"
alias zmain="cd $HOME/vedtak/checklist"

# pnpm
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="$HOME/.local/share/pnpm"
fi
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

alias codex-app="$HOME/apps/codex-port/run-codex.sh"

# Google Drive browser opener
# Usage: gd [path]  (defaults to current directory)
unalias gd 2>/dev/null
gd() {
  local GDRIVE_ROOT="$HOME/gdrive"
  local RCLONE_REMOTE="vedtak-shared"
  local TEAM_DRIVE_ROOT_ID="0ANLilboyAAoHUk9PVA"

  local target
  if [[ $# -eq 0 ]]; then
    target="$PWD"
  elif [[ "$1" == /* ]]; then
    target="$1"
  else
    target="$PWD/$1"
  fi

  if [[ "$target" != "$GDRIVE_ROOT" && "$target" != "$GDRIVE_ROOT/"* ]]; then
    echo "gd: '$target' is not inside $GDRIVE_ROOT" >&2
    return 1
  fi

  if [[ ! -e "$target" ]]; then
    echo "gd: '$target' does not exist" >&2
    return 1
  fi

  local rel="${target#$GDRIVE_ROOT}"
  rel="${rel#/}"

  local url
  if [[ -z "$rel" ]]; then
    url="https://drive.google.com/drive/folders/${TEAM_DRIVE_ROOT_ID}"
  else
    local name parent_rel rclone_parent json_out id
    name="$(basename "$rel")"
    parent_rel="$(dirname "$rel")"

    if [[ "$parent_rel" == "." ]]; then
      rclone_parent="${RCLONE_REMOTE}:"
    else
      rclone_parent="${RCLONE_REMOTE}:${parent_rel}"
    fi

    json_out=$(rclone lsjson "$rclone_parent" 2>&1)
    if [[ $? -ne 0 ]]; then
      echo "gd: rclone failed to list '$rclone_parent'" >&2
      echo "$json_out" >&2
      return 1
    fi

    id=$(printf '%s' "$json_out" | jq -r --arg n "$name" '.[] | select(.Name == $n) | .ID')

    if [[ -z "$id" ]]; then
      echo "gd: could not find '$name' in Google Drive" >&2
      return 1
    fi

    if [[ -d "$target" ]]; then
      url="https://drive.google.com/drive/folders/${id}"
    else
      local ext="${${target:t}##*.}"
      case "${ext:l}" in
        doc|docx)  url="https://docs.google.com/document/d/${id}/edit" ;;
        xls|xlsx)  url="https://docs.google.com/spreadsheets/d/${id}/edit" ;;
        ppt|pptx)  url="https://docs.google.com/presentation/d/${id}/edit" ;;
        *)         url="https://drive.google.com/file/d/${id}/view" ;;
      esac
    fi
  fi

  echo "Opening: $url"
  if [[ "$OSTYPE" == darwin* ]]; then open "$url"; else xdg-open "$url"; fi
}
export PATH="$HOME/.local/bin:$PATH"
