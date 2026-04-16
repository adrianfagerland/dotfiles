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

### TODO on new machine setup

**Push these files from the source Mac** — currently missing from the repo and required for SketchyBar to render anything:

- `.config/sketchybar/sketchybarrc` (entry point)
- `.config/sketchybar/items/apple.lua`
- `.config/sketchybar/items/menu_spaces_toggle.lua`
- `.config/sketchybar/items/menus.lua`
- `.config/sketchybar/items/spaces.lua`
- `.config/sketchybar/items/front_apps.lua`
- `.config/sketchybar/items/widgets.lua` (and any submodules it `require`s under `items/widgets/`)
- `.config/sketchybar/items/message.lua`

Without these, `items/init.lua` fails to load and SketchyBar shows an empty default bar.

### macOS system settings (manual, GUI-only)

These aren't captured in dotfiles and must be set in System Settings on each new machine:

- **Menu bar**: Control Center → Menu Bar → *Automatically hide and show the menu bar: Always* (so SketchyBar owns the top strip)
- **Dock**: Desktop & Dock → *Automatically hide and show the Dock: on*; size set to minimum
- **Accessibility permissions** (Privacy & Security → Accessibility): AeroSpace, borders, Karabiner-Elements
- **Karabiner driver**: approve the kernel extension on first launch
- **Ghostty**: set font to *MesloLGS Nerd Font* (for powerlevel10k glyphs)
- **SSH key**: `ssh-keygen -t ed25519` (the `.zshrc` expects `~/.ssh/id_ed25519`)
- **Custom keyboard layout**: drop `custom_keyboard_layout` into `~/Library/Keyboard Layouts/` and select it in System Settings → Keyboard → Input Sources

### Post-install commands

```sh
# SbarLua (built from source — required by the SketchyBar Lua config)
git clone --depth=1 https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && (cd /tmp/SbarLua && make install)

# Start services
brew services start sketchybar
brew services start borders
open -a AeroSpace
```
