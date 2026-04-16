# dotfiles

My dotfiles for Linux (i3) and macOS (AeroSpace).

## macOS setup

The macOS setup is heavily inspired by [agenttank/dotfiles_macos](https://github.com/agenttank/dotfiles_macos).

- **WM**: AeroSpace (i3-like tiling)
- **Bar**: SketchyBar (Lua-based with SbarLua)
- **Terminal**: Ghostty
- **Editor**: Neovim
- **Theme**: Rose Pine
- **Borders**: JankyBorders
- **File manager**: Marta

## Setting up a new Mac

End-to-end bootstrap from a fresh macOS install. Steps 1–6 are scripted; 7–9 are
manual (GUI permissions, OAuth). Apple Silicon assumed; paths use
`/opt/homebrew` throughout.

### 1. Install Homebrew and GitHub CLI

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install gh
gh auth login   # https protocol, authenticate via browser
```

### 2. Clone dotfiles

```sh
git clone https://github.com/adrianfagerland/dotfiles.git ~/dotfiles
```

### 3. Symlink into `$HOME`

```sh
mkdir -p ~/.config ~/.local/bin ~/.dotfiles-backup
[ -e ~/.zshrc ] && mv ~/.zshrc ~/.dotfiles-backup/.zshrc.bak

ln -sfn ~/dotfiles/.zshrc          ~/.zshrc
ln -sfn ~/dotfiles/.aerospace.toml ~/.aerospace.toml
ln -sfn ~/dotfiles/.xinitrc        ~/.xinitrc

for d in aerospace sketchybar karabiner i3 polybar; do
  [ -e ~/dotfiles/.config/$d ] && ln -sfn ~/dotfiles/.config/$d ~/.config/$d
done
for f in alacritty.toml picom.conf; do
  [ -e ~/dotfiles/.config/$f ] && ln -sfn ~/dotfiles/.config/$f ~/.config/$f
done
for f in ~/dotfiles/.local/bin/*; do
  ln -sfn "$f" ~/.local/bin/$(basename "$f")
done
```

### 4. Install packages

```sh
# Taps
brew tap nikitabobko/tap
brew tap FelixKratz/formulae

# Formulae
brew install sketchybar borders neovim lua jq rclone thefuck uv pnpm nvm
brew install oven-sh/bun/bun

# Casks (apps + font)
brew install --cask aerospace ghostty marta karabiner-elements font-meslo-lg-nerd-font

# Rust (for cargo — .zshrc sources $HOME/.cargo/env)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```

### 5. Install oh-my-zsh, powerlevel10k, and plugins

```sh
RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git              $ZSH_CUSTOM/themes/powerlevel10k
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions          $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting      $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search $ZSH_CUSTOM/plugins/zsh-history-substring-search
git clone --depth=1 https://github.com/MichaelAquilina/zsh-you-should-use.git $ZSH_CUSTOM/plugins/you-should-use
```

### 6. Build SbarLua (SketchyBar's Lua runtime)

```sh
git clone --depth=1 https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua
(cd /tmp/SbarLua && make install)
```

Installs `sketchybar.so` to `~/.local/share/sketchybar_lua/`.

### 7. Restore missing SketchyBar config

The SketchyBar Lua config in this repo is **incomplete** — `items/init.lua` `require`s these
files which aren't committed. Copy them from the source Mac (or a backup):

- `.config/sketchybar/sketchybarrc` (entry point)
- `.config/sketchybar/items/apple.lua`
- `.config/sketchybar/items/menu_spaces_toggle.lua`
- `.config/sketchybar/items/menus.lua`
- `.config/sketchybar/items/spaces.lua`
- `.config/sketchybar/items/front_apps.lua`
- `.config/sketchybar/items/widgets.lua` (plus any submodules it `require`s under `items/widgets/`)
- `.config/sketchybar/items/message.lua`

Without these, SketchyBar falls back to an empty default bar.

### 8. macOS system settings (GUI-only)

- **Menu bar**: System Settings → Control Center → Menu Bar → *Automatically hide and show the menu bar: Always* (so SketchyBar owns the top strip)
- **Dock**: System Settings → Desktop & Dock → *Automatically hide and show the Dock: on*, Size: minimum
- **Accessibility** (Privacy & Security → Accessibility): enable AeroSpace, borders, Karabiner-Elements
- **Karabiner driver**: on first launch, approve the kernel extension in Privacy & Security
- **Ghostty**: set font to *MesloLGS Nerd Font* (required for powerlevel10k glyphs)
- **Custom keyboard layout**: copy `~/dotfiles/custom_keyboard_layout` into `~/Library/Keyboard Layouts/`, then select it in Keyboard → Input Sources

### 9. Generate SSH key and register with GitHub

```sh
ssh-keygen -t ed25519 -C "a@fgr.land"
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"
```

### 10. Start services

```sh
brew services start sketchybar
brew services start borders
open -a AeroSpace
open -a Karabiner-Elements   # triggers the first-launch permission flow
```

Reopen terminal, then run `p10k configure` to generate `~/.p10k.zsh`.

### 11. (Optional) Google Drive sync via rclone

Mirrors the `vedtak-shared` team drive to `~/gdrive` with two-way sync every 2 min.

1. **Configure remote** (interactive, needs browser for OAuth):
   ```sh
   rclone config
   ```
   - `n` new remote, name: `vedtak-shared`
   - type: `drive`
   - client_id / client_secret: leave blank
   - scope: `1` (full access)
   - advanced config: no
   - auto config: yes (browser opens → sign in to work Google account)
   - team drive: yes → select the drive (ID `0ANLilboyAAoHUk9PVA`)
   - confirm, `q` to quit

2. **Verify and initialize:**
   ```sh
   rclone lsd vedtak-shared:
   mkdir -p ~/gdrive
   rclone bisync vedtak-shared: ~/gdrive --resync --create-empty-src-dirs --verbose
   ```
   The `--resync` is required only on the first run.

3. **Create the launchd agent** at `~/Library/LaunchAgents/land.fgr.rclone-gdrive-bisync.plist`
   (runs bisync every 2 min; logs to `~/Library/Logs/rclone/`):

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>Label</key><string>land.fgr.rclone-gdrive-bisync</string>
     <key>ProgramArguments</key>
     <array>
       <string>/opt/homebrew/bin/rclone</string>
       <string>bisync</string>
       <string>vedtak-shared:</string>
       <string>/Users/adrian/gdrive</string>
       <string>--create-empty-src-dirs</string>
       <string>--conflict-resolve</string><string>newer</string>
       <string>--resilient</string>
       <string>--recover</string>
     </array>
     <key>StartInterval</key><integer>120</integer>
     <key>RunAtLoad</key><true/>
     <key>StandardOutPath</key><string>/Users/adrian/Library/Logs/rclone/bisync.log</string>
     <key>StandardErrorPath</key><string>/Users/adrian/Library/Logs/rclone/bisync.err</string>
     <key>EnvironmentVariables</key>
     <dict><key>HOME</key><string>/Users/adrian</string></dict>
   </dict>
   </plist>
   ```

4. **Load it:**
   ```sh
   mkdir -p ~/Library/Logs/rclone
   launchctl load ~/Library/LaunchAgents/land.fgr.rclone-gdrive-bisync.plist
   ```

### 12. Install GUI apps aerospace auto-launches

`.aerospace.toml` opens these at login — install them (App Store or direct download):

- Spotify
- Google Chrome
- Mail (built-in)
- Claude
- Slack
- Gmail (desktop app)
