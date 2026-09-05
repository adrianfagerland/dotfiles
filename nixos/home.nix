{ config, lib, pkgs, ... }:

let
  oledBlackWallpaper = pkgs.runCommand "oled-black-wallpaper.png" {
  } ''
    printf 'P6\n1 1\n255\n\0\0\0' > "$out"
  '';
in
{
  home.username = "adrian";
  home.homeDirectory = "/home/adrian";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };
    iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.theme = config.gtk.theme;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style = {
      package = pkgs.adwaita-qt;
      name = "adwaita-dark";
    };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Adwaita";
      cursor-theme = "Bibata-Modern-Classic";
      cursor-size = 24;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = [ "helium.desktop" ];
      "text/xml" = [ "helium.desktop" ];
      "application/xhtml+xml" = [ "helium.desktop" ];
      "x-scheme-handler/http" = [ "helium.desktop" ];
      "x-scheme-handler/https" = [ "helium.desktop" ];
      "application/pdf" = [ "helium.desktop" ];
    };
  };

  xdg.configFile."mimeapps.list".force = true;
  # Whole-monitor capture currently fails DMA-BUF negotiation on this Intel/Hyprland
  # stack. Avoid the renegotiation loop and keep SHM capture cheap enough for meetings.
  xdg.configFile."hypr/xdph.conf" = {
    force = true;
    text = ''
      screencopy {
          force_shm = true
          max_fps = 30
      }
    '';
  };
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-termfilechooser
      xdg-desktop-portal-gtk
      gnome-keyring
    ];
    config = {
      common = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
  };
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = let
    launcherDeps = pkgs.buildEnv {
      name = "yazi-launcher-dependencies";
      paths = with pkgs; [
        bashInteractive
        coreutils
        gnused
        yazi
      ];
    };
  in ''
    [filechooser]
    env=PATH=${launcherDeps}/bin
    env=TERMCMD=${pkgs.ghostty}/bin/ghostty -e
    cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    default_dir=$HOME/Downloads
    open_mode=suggested
    save_mode=suggested
  '';

  home.activation.makeMimeAppsMutable = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    mimeapps="$HOME/.config/mimeapps.list"
    if [ -L "$mimeapps" ]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.coreutils}/bin/cat "$mimeapps" > "$tmp"
      ${pkgs.coreutils}/bin/rm "$mimeapps"
      ${pkgs.coreutils}/bin/install -m 0644 "$tmp" "$mimeapps"
      ${pkgs.coreutils}/bin/rm -f "$tmp"
    fi
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    BUN_INSTALL = "$HOME/.bun";
    PNPM_HOME = "$HOME/.local/share/pnpm";
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "24";
    GTK_THEME = "Adwaita:dark";
    GTK_USE_PORTAL = "1";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
    "$HOME/.local/share/pnpm"
  ];

  home.file.".local/bin/rclone-vedtak-gdrive-sync" = {
    executable = true;
    force = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      remote_name="vedtak-shared"
      remote="$remote_name:"
      local_dir="$HOME/gdrive"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/rclone/vedtak-gdrive"
      filters_file="$HOME/.config/rclone/vedtak-gdrive.filters"
      initialized_file="$state_dir/initialized"
      resync=0
      resync_mode="path1"

      usage() {
        printf '%s\n' "usage: rclone-vedtak-gdrive-sync [--resync [--resync-mode MODE]]"
      }

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --resync)
            resync=1
            shift
            ;;
          --resync-mode)
            if [ "$#" -lt 2 ]; then
              usage >&2
              exit 2
            fi
            resync_mode="$2"
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            usage >&2
            exit 2
            ;;
        esac
      done

      ${pkgs.coreutils}/bin/mkdir -p "$local_dir" "$state_dir" "$(${pkgs.coreutils}/bin/dirname "$filters_file")"

      if ! ${pkgs.rclone}/bin/rclone config show "$remote_name" 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '^token = '; then
        printf '%s\n' "rclone remote '$remote_name' is not authorized yet; run: rclone config reconnect $remote"
        exit 0
      fi

      if [ "$resync" -eq 0 ] && [ ! -f "$initialized_file" ]; then
        if [ -z "$(${pkgs.findutils}/bin/find "$local_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
          resync=1
        else
          printf '%s\n' "Refusing first bisync because $local_dir is not empty."
          printf '%s\n' "Inspect it, then run 'rclone-vedtak-gdrive-sync --resync' if the Drive side should win."
          exit 1
        fi
      fi

      args=(
        bisync
        "$remote"
        "$local_dir"
        --create-empty-src-dirs
        --conflict-resolve newer
        --resilient
        --recover
        --filters-file "$filters_file"
        --fast-list
        # Folder shortcuts can form cycles in Drive (currently the dibk and
        # molde aliases do). All shortcut targets also exist canonically in
        # this shared drive, so skip aliases instead of recursively following
        # them and exhausting the Drive API quota.
        --drive-skip-shortcuts
        --tpslimit 4
        --tpslimit-burst 8
        --checkers 4
        --transfers 2
        --max-lock 30m
        --no-update-dir-modtime
      )

      if [ "$resync" -eq 1 ]; then
        args+=(--resync --resync-mode "$resync_mode")
      fi

      ${pkgs.rclone}/bin/rclone "''${args[@]}"
      ${pkgs.coreutils}/bin/touch "$initialized_file"
    '';
  };

  home.file.".config/rclone/vedtak-gdrive.filters" = {
    force = true;
    text = ''
      - **/.git/**
      - **/.venv/**
      - **/node_modules/**
      - **/__pycache__/**
      - **/.pytest_cache/**
      - **/.mypy_cache/**
      - **/.ruff_cache/**
      - **/.cache/**
      - **/.~lock*#
      - **/.DS_Store
      - **/Thumbs.db
      - **/*.swp
      - **/*~
    '';
  };

  home.file.".local/bin/gdrive-sync-now" = {
    executable = true;
    force = true;
    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      ${pkgs.systemd}/bin/systemctl --user start rclone-vedtak-gdrive-bisync.service
    '';
  };

  home.file.".local/bin/gdrive-sync-status" = {
    executable = true;
    force = true;
    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      ${pkgs.systemd}/bin/systemctl --user status rclone-vedtak-gdrive-bisync.timer rclone-vedtak-gdrive-bisync.service --no-pager --full
      ${pkgs.systemd}/bin/journalctl --user -u rclone-vedtak-gdrive-bisync.service -n 80 --no-pager --output=short-iso
    '';
  };

  home.file.".local/bin/ntnu-vpn-refresh" = {
    executable = true;
    force = true;
    text = ''
      #!${pkgs.runtimeShell}
      set -eu

      ${pkgs.networkmanager}/bin/nmcli connection down "NTNU VPN" >/dev/null 2>&1 || true
      ${pkgs.networkmanager}/bin/nmcli connection delete "NTNU VPN" >/dev/null 2>&1 || true
      ${pkgs.networkmanager}/bin/nmcli connection add \
        type vpn \
        ifname '*' \
        con-name "NTNU VPN" \
        vpn-type openconnect \
        vpn.data "gateway=vpn.ntnu.no,protocol=anyconnect,useragent=AnyConnect Linux"
      ${pkgs.networkmanager}/bin/nmcli connection modify "NTNU VPN" connection.autoconnect no
      ${pkgs.networkmanager}/bin/nmcli connection up "NTNU VPN"
    '';
  };

  home.activation.ensureVedtakGdriveRcloneRemote = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rclone_config="$HOME/.config/rclone/rclone.conf"
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/rclone" "$HOME/gdrive"

    if ! ${pkgs.rclone}/bin/rclone config show vedtak-shared >/dev/null 2>&1; then
      ${pkgs.coreutils}/bin/touch "$rclone_config"
      ${pkgs.coreutils}/bin/chmod 0600 "$rclone_config"
      if [ -s "$rclone_config" ]; then
        ${pkgs.coreutils}/bin/printf '\n' >> "$rclone_config"
      fi
      ${pkgs.coreutils}/bin/cat >> "$rclone_config" <<'EOF'
[vedtak-shared]
type = drive
scope = drive
team_drive = 0ANLilboyAAoHUk9PVA
EOF
    fi
  '';

  systemd.user.services.rclone-vedtak-gdrive-bisync = {
    Unit = {
      Description = "Bisync Vedtak Google Drive to ~/gdrive";
      Documentation = "https://rclone.org/bisync/";
    };

    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/rclone-vedtak-gdrive-sync";
      TimeoutStartSec = "30min";
    };
  };

  systemd.user.timers.rclone-vedtak-gdrive-bisync = {
    Unit.Description = "Run Vedtak Google Drive bisync every two minutes";

    Timer = {
      OnActiveSec = "30s";
      OnUnitInactiveSec = "2min";
      Unit = "rclone-vedtak-gdrive-bisync.service";
      Persistent = true;
    };

    Install.WantedBy = [ "timers.target" ];
  };

  home.file.".local/bin/codex-node-repl" = {
    executable = true;
    force = true;
    text = ''
      #!/usr/bin/env sh
      set -eu

      find_node_repl() {
          if [ "''${CODEX_NODE_REPL_PATH:-}" != "" ] && [ -x "$CODEX_NODE_REPL_PATH" ]; then
              printf '%s\n' "$CODEX_NODE_REPL_PATH"
              return 0
          fi

          if [ "''${CODEX_ELECTRON_RESOURCES_PATH:-}" != "" ] && [ -x "$CODEX_ELECTRON_RESOURCES_PATH/node_repl" ]; then
              printf '%s\n' "$CODEX_ELECTRON_RESOURCES_PATH/node_repl"
              return 0
          fi

          if [ -x "${pkgs.codex-desktop}/opt/codex-desktop/resources/node_repl" ]; then
              printf '%s\n' "${pkgs.codex-desktop}/opt/codex-desktop/resources/node_repl"
              return 0
          fi

          for candidate in /nix/store/*codex-desktop*/opt/codex-desktop/resources/node_repl; do
              if [ -x "$candidate" ]; then
                  printf '%s\n' "$candidate"
                  return 0
              fi
          done

          return 1
      }

      find_loader() {
          if [ "''${CODEX_NODE_REPL_LOADER:-}" != "" ] && [ -x "$CODEX_NODE_REPL_LOADER" ]; then
              printf '%s\n' "$CODEX_NODE_REPL_LOADER"
              return 0
          fi

          if command -v nix >/dev/null 2>&1; then
              glibc_out="$(nix eval --raw nixpkgs#glibc.outPath 2>/dev/null || true)"
              if [ "$glibc_out" != "" ] && [ -x "$glibc_out/lib64/ld-linux-x86-64.so.2" ]; then
                  printf '%s\n' "$glibc_out/lib64/ld-linux-x86-64.so.2"
                  return 0
              fi
          fi

          for candidate in /nix/store/*glibc*/lib64/ld-linux-x86-64.so.2; do
              if [ -x "$candidate" ]; then
                  printf '%s\n' "$candidate"
                  return 0
              fi
          done

          return 1
      }

      node_repl="$(find_node_repl)" || {
          printf '%s\n' "codex-node-repl: could not find Codex Desktop node_repl" >&2
          exit 127
      }

      loader="$(find_loader)" || {
          printf '%s\n' "codex-node-repl: could not find a glibc dynamic loader" >&2
          exit 127
      }

      export CODEX_HOME="''${CODEX_HOME:-$HOME/.codex}"

      exec "$loader" "$node_repl" "$@"
    '';
  };

  xdg.configFile."systemd/user/app-codex-desktop-.scope.d/50-resources.conf" = {
    force = true;
    text = ''
      [Scope]
      CPUQuota=300%
      CPUWeight=10
      IOWeight=10
      MemoryHigh=6G
    '';
  };

  home.file.".local/bin/codex-desktop" = {
    executable = true;
    force = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # Node/TypeScript processes launched by Codex can abort after exhausting
      # their V8 heap. Disable core files for this process tree so a compiler
      # failure cannot stall the desktop while systemd writes several GiB.
      ulimit -c 0

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/codex-desktop"
      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/codex-desktop"
      config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/Codex"
      app_pid_file="$state_dir/app.pid"
      cleanup_marker="$state_dir/cleanup-on-next-launch"
      launcher_log="$cache_dir/launcher.log"

      codex_is_running() {
          local pid
          local executable

          [ -r "$app_pid_file" ] || return 1
          IFS= read -r pid < "$app_pid_file" || return 1
          [[ "$pid" =~ ^[0-9]+$ ]] || return 1
          [ -r "/proc/$pid/exe" ] || return 1
          executable="$(${pkgs.coreutils}/bin/readlink -f "/proc/$pid/exe" 2>/dev/null || true)"

          case "$executable" in
              */codex-desktop-*/opt/codex-desktop/electron) return 0 ;;
              *) return 1 ;;
          esac
      }

      compact_launcher_log() {
          local max_bytes="''${CODEX_LAUNCHER_LOG_MAX_BYTES:-134217728}"
          local keep_bytes="''${CODEX_LAUNCHER_LOG_KEEP_BYTES:-16777216}"
          local size
          local compacted

          [ -f "$launcher_log" ] || return 0
          size="$(${pkgs.coreutils}/bin/stat -c %s "$launcher_log" 2>/dev/null || echo 0)"
          [[ "$size" =~ ^[0-9]+$ ]] || return 0
          [ "$size" -gt "$max_bytes" ] || return 0

          ${pkgs.coreutils}/bin/mkdir -p "$cache_dir"
          compacted="$(${pkgs.coreutils}/bin/mktemp "$cache_dir/.launcher.log.compact.XXXXXX")"
          ${pkgs.coreutils}/bin/tail -c "$keep_bytes" "$launcher_log" > "$compacted"
          ${pkgs.coreutils}/bin/chmod 600 "$compacted"
          # Copy over the existing inode so an inherited log descriptor cannot
          # keep a removed multi-gigabyte file alive.
          ${pkgs.coreutils}/bin/cp -- "$compacted" "$launcher_log"
          ${pkgs.coreutils}/bin/rm -f "$compacted"
      }

      run_staged_cleanup() {
          [ -e "$cleanup_marker" ] || return 0

          ${pkgs.coreutils}/bin/rm -rf -- \
              "$config_dir/Cache" \
              "$config_dir/Code Cache" \
              "$config_dir/GPUCache" \
              "$config_dir/DawnGraphiteCache" \
              "$config_dir/DawnWebGPUCache" \
              "$config_dir/Partitions/codex-browser-app/Cache" \
              "$config_dir/Partitions/codex-browser-app/Code Cache" \
              "$config_dir/Partitions/codex-browser-app/GPUCache" \
              "$config_dir/Partitions/codex-browser-app/DawnGraphiteCache" \
              "$config_dir/Partitions/codex-browser-app/DawnWebGPUCache"

          if [ -d "$state_dir/tmp" ]; then
              ${pkgs.findutils}/bin/find "$state_dir/tmp" \
                  -mindepth 1 -maxdepth 1 -mtime +7 \
                  -exec ${pkgs.coreutils}/bin/rm -rf -- {} +
          fi

          ${pkgs.coreutils}/bin/rm -f "$cleanup_marker"
      }

      apply_resource_guard() {
          local cgroup_path
          local scope_unit

          cgroup_path="$(${pkgs.gawk}/bin/awk -F: '$1 == "0" { print $3; exit }' /proc/self/cgroup 2>/dev/null || true)"
          scope_unit="''${cgroup_path##*/}"

          case "$scope_unit" in
              app-codex-desktop-*.scope)
                  ${pkgs.systemd}/bin/systemctl --user set-property --runtime "$scope_unit" \
                      "CPUQuota=''${CODEX_DESKTOP_CPU_QUOTA:-300%}" \
                      "CPUWeight=''${CODEX_DESKTOP_CPU_WEIGHT:-10}" \
                      "IOWeight=''${CODEX_DESKTOP_IO_WEIGHT:-10}" \
                      "MemoryHigh=''${CODEX_DESKTOP_MEMORY_HIGH:-6G}" \
                      >/dev/null 2>&1 || true
                  ;;
          esac
      }

      ${pkgs.coreutils}/bin/mkdir -p "$state_dir" "$cache_dir"
      apply_resource_guard
      if ! codex_is_running; then
          compact_launcher_log
          run_staged_cleanup
      fi

      # Codex Desktop's Nix wrapper provides GTK3 libraries but does not expose
      # the matching GTK3 GSettings schemas. Native file/project choosers can
      # abort when org.gtk.Settings.FileChooser is not visible.
      original="''${CODEX_DESKTOP_ORIGINAL:-${pkgs.codex-desktop}/bin/codex-desktop}"
      resolved="$(${pkgs.coreutils}/bin/readlink -f "$original" 2>/dev/null || ${pkgs.coreutils}/bin/printf '%s\n' "$original")"

      prepend_schema_root() {
          local schema_root="$1"
          local schema_dir="$schema_root/glib-2.0/schemas"

          if [ -f "$schema_dir/gschemas.compiled" ]; then
              XDG_DATA_DIRS="$schema_root''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
              export XDG_DATA_DIRS
          fi
      }

      gtk3_lib="$(${pkgs.gnugrep}/bin/grep -m 1 -o '/nix/store/[^":]*-gtk+3-[^"/]*/lib' "$resolved" 2>/dev/null || true)"
      gtk3_store="''${gtk3_lib%/lib}"

      if [ -n "$gtk3_store" ]; then
          for schema_root in "$gtk3_store"/share/gsettings-schemas/*; do
              schema_dir="$schema_root/glib-2.0/schemas"
              if [ -f "$schema_dir/gschemas.compiled" ]; then
                  export GSETTINGS_SCHEMA_DIR="$schema_dir"
                  prepend_schema_root "$schema_root"
                  break
              fi
          done
      fi

      for schema_root in ${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/*; do
          prepend_schema_root "$schema_root"
      done

      exec "$original" "$@"
    '';
  };

  xdg.dataFile."applications/codex-desktop.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Name=Codex Desktop
      Comment=Run Codex Desktop on Linux
      Exec=env BAMF_DESKTOP_FILE_HINT=${config.home.homeDirectory}/.local/share/applications/codex-desktop.desktop CHROME_DESKTOP=codex-desktop.desktop ${config.home.homeDirectory}/.local/bin/codex-desktop %u
      Icon=codex-desktop
      Terminal=false
      Type=Application
      Categories=Development;
      MimeType=x-scheme-handler/codex;x-scheme-handler/codex-browser-sidebar;
      StartupNotify=true
      StartupWMClass=codex-desktop
      X-GNOME-WMClass=codex-desktop
    '';
  };

  home.activation.ensureCodexNodeReplMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    codex_bin="${pkgs.codex}/bin/codex"
    wrapper="$HOME/.local/bin/codex-node-repl"

    if [ -x "$codex_bin" ] && [ -x "$wrapper" ]; then
      "$codex_bin" mcp get node_repl >/dev/null 2>&1 ||
        "$codex_bin" mcp add node_repl -- "$wrapper" >/dev/null 2>&1 ||
        true
    fi
  '';

  home.activation.patchCodexBrowserSkill = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for browser_skill in "$HOME"/.codex/plugins/cache/openai-bundled/browser-use/*/skills/browser/SKILL.md; do
      [ -f "$browser_skill" ] || continue

      ${pkgs.coreutils}/bin/chmod u+w "$browser_skill" 2>/dev/null || true
      ${pkgs.perl}/bin/perl -0pi -e 's#^description:.*$#description: "Browser automation for the Codex in-app browser. Use for @browser requests. Open this full SKILL.md before declaring Browser unavailable. Browser control uses local MCP server node_repl tool js directly; generic tool discovery may not show local MCP tools."#m' "$browser_skill"
      if ! ${pkgs.gnugrep}/bin/grep -q 'Do not call `tool_search` to find `node_repl`' "$browser_skill"; then
        ${pkgs.perl}/bin/perl -0pi -e 's#(Run browser setup code through the Node REPL `js` MCP tool\. In this environment the server is named `node_repl` and the execution tool is named `js`; a model-visible shorthand may appear as `mcp__node_repl__js`\. `js_reset` only clears state and is not the execution tool\.)#$1\n\nDo not call `tool_search` to find `node_repl`. Deferred app/tool discovery does not index local MCP tools reliably. First try the direct MCP callable (`node_repl` server, `js` tool, or `mcp__node_repl__js` shorthand if it is visible). Only after that direct callable fails should you say the Node REPL browser bridge is unavailable.#s' "$browser_skill"
      fi

      if ${pkgs.gnugrep}/bin/grep -q 'Use tool discovery for `node_repl js`' "$browser_skill"; then
        ${pkgs.perl}/bin/perl -0pi -e 's#Run browser setup code through the Node REPL `js` tool. In this environment the callable tool id typically appears as `mcp__node_repl__js`; `js_reset` only clears state and is not the execution tool. Run this once per fresh `node_repl` session:#Run browser setup code through the Node REPL `js` MCP tool. In this environment the server is named `node_repl` and the execution tool is named `js`; a model-visible shorthand may appear as `mcp__node_repl__js`. `js_reset` only clears state and is not the execution tool. Run this once per fresh `node_repl` session:#g; s#- If `js_reset` is visible but `js` is not, do not conclude that `node_repl` is unusable. Use tool discovery for `node_repl js`, then `mcp__node_repl__js`, then `js`, then `node_repl js JavaScript execution`; run the bootstrap cell with the Node REPL `js` tool once it is exposed.#- If `js_reset` is visible but `js` is not, do not conclude that `node_repl` is unusable. Call the MCP tool directly using server `node_repl` and tool `js`, or the shorthand `mcp__node_repl__js` when that callable is visible. Do not use generic tool discovery as proof that `node_repl` is unavailable; local MCP tools may not be indexed there.#g; s#- If the Node REPL `js` execution tool is still unavailable after those searches, say that explicitly before choosing any fallback browser-control path.#- If a direct call to the Node REPL `js` execution tool fails because the tool is unavailable, say that explicitly before choosing any fallback browser-control path.#g' "$browser_skill"
      fi
      ${pkgs.perl}/bin/perl -0pi -e 's#Do not use generic tool discovery as proof that `node_repl` is unavailable; local MCP tools may not be indexed there\.#Do not call `tool_search` and do not use generic tool discovery as proof that `node_repl` is unavailable; local MCP tools may not be indexed there.#g' "$browser_skill"
    done

    for browser_manifest in "$HOME"/.codex/plugins/cache/openai-bundled/browser-use/*/.codex-plugin/plugin.json; do
      [ -f "$browser_manifest" ] || continue

      ${pkgs.coreutils}/bin/chmod u+w "$browser_manifest" 2>/dev/null || true
      ${pkgs.perl}/bin/perl -0pi -e 'if (!/For \@browser requests, open and follow the full Browser SKILL\.md/) { s#("description": ".*?current in-app browser tab\.\\n\\n)#$1For @browser requests, open and follow the full Browser SKILL.md before declaring browser control unavailable. Browser control uses the local MCP server `node_repl` with tool `js`; call that MCP tool directly. Do not treat an empty generic tool discovery result as proof that local MCP browser control is unavailable.\\n\\n#s } s#"shortDescription": "[^"]*"#"shortDescription": "Control the in-app browser through node_repl/js"#; s#"longDescription": "[^"]*"#"longDescription": "Browser lets Codex open and control the in-app browser, mainly for local development pages and files. For @browser requests, Codex should read the full Browser skill and call local MCP server node_repl tool js directly. Do not call tool_search to find node_repl; generic tool discovery may not list local MCP tools. Use it to navigate, inspect, click, type, and take screenshots while testing pages inside Codex."#' "$browser_manifest"
    done
  '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
    };
    shellAliases = {
      spt = "spotify_player";
      venv = "source .venv/bin/activate";
      v = "nvim";
      o = "xdg-open";
      open = "xdg-open";
      sov = "systemctl sleep";
      bye = "shutdown now";
      ciao = "shutdown now";
      c = "codex --dangerously-bypass-approvals-and-sandbox";
      fuck = "pay-respects";
      bwlogin = "rbw register && rbw unlock && rbw sync";
      bwunlock = "rbw unlock && rbw sync";
      bwlock = "rbw lock";
      za = "cd $HOME/vedtak/checklist-a";
      zb = "cd $HOME/vedtak/checklist-b";
      zc = "cd $HOME/vedtak/checklist-c";
      zmain = "cd $HOME/vedtak/checklist";
    };
    initContent = ''
      bindkey '`' autosuggest-accept
      zmodload zsh/complist
      zstyle ':completion:*' menu select
      bindkey '^[[Z' reverse-menu-complete
      bindkey -M viins '^[[Z' reverse-menu-complete
      bindkey -M menuselect '^[[Z' reverse-menu-complete
      bindkey -M viins '^[b' vi-backward-word
      bindkey -M viins '^[f' vi-forward-word

      if [[ -n "$XDG_RUNTIME_DIR" ]]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
      fi

      eval "$(uv generate-shell-completion zsh)"
      eval "$(uvx --generate-shell-completion zsh)"
    '';
    loginExtra = ''
      if uwsm check may-start; then
        exec uwsm start hyprland.desktop
      fi
    '';
  };

  xdg.configFile."rofi-rbw.rc".text = ''
    selector=rofi
    clipboarder=wl-copy
    typer=wtype
    clear-after=45
    no-folder=true
    use-notify-send=true
  '';

  xdg.configFile."networkmanager-dmenu/config.ini".text = ''
    [dmenu]
    dmenu_command = rofi -i
    active_chars = ==
    highlight = True
    compact = True
    format = {name}  {sec}  {signal}%%
    list_saved = True
    prompt = Wi-Fi

    [dmenu_passphrase]
    obscure = True

    [editor]
    terminal = ghostty
    gui_if_available = True
    gui = nm-connection-editor

    [nmdm]
    rescan_delay = 5
    show_notifications = True
  '';

  home.file.".local/bin/hypr-hy3-toggle-split" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      hyprctl dispatch 'hl.plugin.hy3.change_group("untab")'  >/dev/null 2>&1 || true
      hyprctl dispatch 'hl.plugin.hy3.change_group("opposite")'  >/dev/null 2>&1 || true
    '';
  };

  home.file.".local/bin/hypr-projector" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      laptop="eDP-1"
      external="HDMI-A-1"
      laptop_mode="1920x1080@60"
      external_mode="3440x1440@49.99"
      mirror_mode="1920x1080@60"
      external_right_pos="1920x0"
      laptop_right_pos="3440x0"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-projector"
      state_file="$state_dir/mode"
      extend_right_label="Extend - external right"
      extend_left_label="Extend - external left"
      mirror_label="Mirror"
      laptop_label="Laptop only"
      external_label="External only"

      remember_mode() {
        mkdir -p "$state_dir"
        printf '%s\n' "$1" > "$state_file"
      }

      notify_mode() {
        local mode="$1"
        local body="$2"
        remember_mode "$mode"
        notify-send -u low -t 1800 "Projection: $mode" "$body" >/dev/null 2>&1 || true
      }

      external_connected() {
        hyprctl monitors all -j | jq -e --arg name "$external" 'any(.[]; .name == $name)' >/dev/null
      }

      move_all_workspaces_to_monitor() {
        local target="$1"

        hyprctl workspaces -j \
          | jq -r '.[].id' \
          | while read -r workspace; do
              hyprctl dispatch "hl.dsp.workspace.move({ workspace = '$workspace', monitor = '$target' })" >/dev/null 2>&1 || true
            done
      }

      apply_laptop() {
        hyprctl eval "hl.monitor({ output = '$laptop', mode = '$laptop_mode', position = '0x0', scale = 1 })" >/dev/null
        move_all_workspaces_to_monitor "$laptop"
        hyprctl eval "hl.monitor({ output = '$external', disabled = true })" >/dev/null 2>&1 || true
        notify_mode "laptop" "Laptop screen only"
      }

      apply_external() {
        if ! external_connected; then
          notify-send -u normal -t 2200 "Projection" "External display is not connected" >/dev/null 2>&1 || true
          apply_laptop
          return
        fi

        hyprctl eval "hl.monitor({ output = '$external', mode = '$external_mode', position = '0x0', scale = 1 })" >/dev/null
        move_all_workspaces_to_monitor "$external"
        hyprctl eval "hl.monitor({ output = '$laptop', disabled = true })" >/dev/null
        notify_mode "external" "External screen only"
      }

      apply_extend() {
        if ! external_connected; then
          notify-send -u normal -t 2200 "Projection" "External display is not connected" >/dev/null 2>&1 || true
          apply_laptop
          return
        fi

        hyprctl eval "hl.monitor({ output = '$laptop', mode = '$laptop_mode', position = '0x0', scale = 1 }); hl.monitor({ output = '$external', mode = '$external_mode', position = '$external_right_pos', scale = 1 })" >/dev/null
        notify_mode "extend-right" "External screen to the right"
      }

      apply_extend_left() {
        if ! external_connected; then
          notify-send -u normal -t 2200 "Projection" "External display is not connected" >/dev/null 2>&1 || true
          apply_laptop
          return
        fi

        hyprctl eval "hl.monitor({ output = '$external', mode = '$external_mode', position = '0x0', scale = 1 }); hl.monitor({ output = '$laptop', mode = '$laptop_mode', position = '$laptop_right_pos', scale = 1 })" >/dev/null
        notify_mode "extend-left" "External screen to the left"
      }

      apply_mirror() {
        if ! external_connected; then
          notify-send -u normal -t 2200 "Projection" "External display is not connected" >/dev/null 2>&1 || true
          apply_laptop
          return
        fi

        hyprctl eval "hl.monitor({ output = '$laptop', mode = '$laptop_mode', position = '0x0', scale = 1 })" >/dev/null
        move_all_workspaces_to_monitor "$laptop"
        hyprctl eval "hl.monitor({ output = '$external', mode = '$mirror_mode', position = '0x0', scale = 1, mirror = '$laptop' })" >/dev/null
        notify_mode "mirror" "Duplicating laptop screen"
      }

      current_mode() {
        local monitors laptop_row external_row mirror_of laptop_disabled external_disabled
        monitors="$(hyprctl monitors all -j)"
        laptop_row="$(jq -c --arg name "$laptop" '.[] | select(.name == $name)' <<< "$monitors" | head -n1)"
        external_row="$(jq -c --arg name "$external" '.[] | select(.name == $name)' <<< "$monitors" | head -n1)"

        if [[ -z "$external_row" ]]; then
          echo "laptop"
          return
        fi

        external_disabled="$(jq -r '.disabled // false' <<< "$external_row")"
        if [[ "$external_disabled" == "true" ]]; then
          echo "laptop"
          return
        fi

        if [[ -z "$laptop_row" ]]; then
          echo "external"
          return
        fi

        laptop_disabled="$(jq -r '.disabled // false' <<< "$laptop_row")"
        if [[ "$laptop_disabled" == "true" ]]; then
          echo "external"
          return
        fi

        mirror_of="$(jq -r '.mirrorOf // "none"' <<< "$external_row")"
        if [[ "$mirror_of" != "none" ]]; then
          echo "mirror"
          return
        fi

        local laptop_x external_x
        laptop_x="$(jq -r '.x // 0' <<< "$laptop_row")"
        external_x="$(jq -r '.x // 0' <<< "$external_row")"
        if (( external_x < laptop_x )); then
          echo "extend-left"
        else
          echo "extend-right"
        fi
      }

      selected_row_for_mode() {
        case "$1" in
          extend-right) echo 0 ;;
          extend-left) echo 1 ;;
          mirror) echo 2 ;;
          laptop) echo 3 ;;
          external) echo 4 ;;
          *) echo 0 ;;
        esac
      }

      rofi_menu() {
        local current ext_status selected choice

        current="$(current_mode)"
        selected="$(selected_row_for_mode "$current")"
        if external_connected; then
          ext_status="$external connected"
        else
          ext_status="$external not connected"
        fi

        choice="$(
          printf '%s\n' "$extend_right_label" "$extend_left_label" "$mirror_label" "$laptop_label" "$external_label" \
            | rofi -dmenu -i -p "Display" -mesg "Current: $current | $ext_status" -selected-row "$selected"
        )"

        case "$choice" in
          "$extend_right_label") apply_extend ;;
          "$extend_left_label") apply_extend_left ;;
          "$mirror_label") apply_mirror ;;
          "$laptop_label") apply_laptop ;;
          "$external_label") apply_external ;;
          "") exit 0 ;;
        esac
      }

      cycle_mode() {
        case "$(current_mode)" in
          laptop) apply_mirror ;;
          mirror) apply_extend ;;
          extend-right) apply_extend_left ;;
          extend-left) apply_external ;;
          external) apply_laptop ;;
          *) apply_extend ;;
        esac
      }

      case "''${1:-menu}" in
        menu|rofi|choose) rofi_menu ;;
        laptop|internal) apply_laptop ;;
        external|second) apply_external ;;
        extend|right|extend-right) apply_extend ;;
        left|extend-left) apply_extend_left ;;
        mirror|duplicate) apply_mirror ;;
        cycle|toggle) cycle_mode ;;
        current) current_mode ;;
        *)
          echo "usage: hypr-projector [menu|extend|extend-left|mirror|laptop|external|cycle|current]" >&2
          exit 2
          ;;
      esac
    '';
  };

  home.file.".local/bin/hypr-i3-focus" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      dir="''${1:?direction required}"
      case "$dir" in
        h|left) hypr_dir="l"; group_dir="b" ;;
        j|d|down) hypr_dir="d"; group_dir="f" ;;
        k|u|up) hypr_dir="u"; group_dir="b" ;;
        l|r|right) hypr_dir="r"; group_dir="f" ;;
        *) exit 2 ;;
      esac

      grouped_count="$(hyprctl activewindow -j | jq '(.grouped // []) | length' 2>/dev/null || echo 0)"
      if [[ "$grouped_count" -gt 1 ]]; then
        hyprctl dispatch changegroupactive "$group_dir"
      else
        hyprctl dispatch movefocus "$hypr_dir"
      fi
    '';
  };

  home.file.".local/bin/hypr-i3-move" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      dir="''${1:?direction required}"
      case "$dir" in
        h|left) hypr_dir="l"; group_dir="b" ;;
        j|d|down) hypr_dir="d"; group_dir="f" ;;
        k|u|up) hypr_dir="u"; group_dir="b" ;;
        l|r|right) hypr_dir="r"; group_dir="f" ;;
        *) exit 2 ;;
      esac

      grouped_count="$(hyprctl activewindow -j | jq '(.grouped // []) | length' 2>/dev/null || echo 0)"
      if [[ "$grouped_count" -gt 1 ]]; then
        hyprctl dispatch lockactivegroup unlock >/dev/null 2>&1 || true
        hyprctl dispatch layoutmsg preselect "$hypr_dir" >/dev/null 2>&1 || true
        hyprctl dispatch moveoutofgroup "$hypr_dir" >/dev/null 2>&1 || hyprctl dispatch moveoutofgroup >/dev/null 2>&1 || true
        hypr-i3-split-mode apply
      else
        hyprctl dispatch movewindow "$hypr_dir"
      fi
    '';
  };

  home.file.".local/bin/hypr-i3-split-mode" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-i3"
      state_file="$state_dir/split-mode"
      mkdir -p "$state_dir"

      current_mode() {
        if [[ -f "$state_file" ]]; then
          read -r mode < "$state_file" || mode="horizontal"
        else
          mode="horizontal"
        fi

        case "$mode" in
          vertical|v|down|d) echo "vertical" ;;
          *) echo "horizontal" ;;
        esac
      }

      apply_mode() {
        mode="$(current_mode)"
        case "$mode" in
          vertical) hyprctl dispatch layoutmsg preselect d >/dev/null 2>&1 || true ;;
          *) hyprctl dispatch layoutmsg preselect r >/dev/null 2>&1 || true ;;
        esac
      }

      case "''${1:-apply}" in
        horizontal|h|right|r)
          printf '%s\n' "horizontal" > "$state_file"
          apply_mode
          ;;
        vertical|v|down|d)
          printf '%s\n' "vertical" > "$state_file"
          apply_mode
          ;;
        toggle)
          grouped_count="$(hyprctl activewindow -j | jq '(.grouped // []) | length' 2>/dev/null || echo 0)"
          if [[ "$grouped_count" -gt 1 ]]; then
            hypr-i3-untab
            exit 0
          fi

          if [[ "$(current_mode)" == "horizontal" ]]; then
            printf '%s\n' "vertical" > "$state_file"
          else
            printf '%s\n' "horizontal" > "$state_file"
          fi
          apply_mode
          ;;
        current)
          current_mode
          ;;
        apply)
          apply_mode
          ;;
        *)
          echo "usage: hypr-i3-split-mode [horizontal|vertical|toggle|current|apply]" >&2
          exit 2
          ;;
      esac
    '';
  };

  home.file.".local/bin/hypr-i3-untab" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      workspace_id="$(hyprctl activeworkspace -j | jq -r '.id')"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-i3"
      state_file="$state_dir/tabbed-$workspace_id.json"

      active_json="$(hyprctl activewindow -j)"
      active_addr="$(jq -r '.address // empty' <<< "$active_json")"
      [[ -n "$active_addr" ]] || exit 0

      mapfile -t grouped < <(jq -r '(.grouped // [])[]?' <<< "$active_json")
      (( ''${#grouped[@]} > 1 )) || exit 0

      saved_mode="horizontal"
      if [[ -f "$state_file" ]]; then
        saved_mode="$(jq -r '.mode // "horizontal"' "$state_file" 2>/dev/null || echo horizontal)"
      fi
      case "$saved_mode" in
        vertical) split_dir="d" ;;
        *) saved_mode="horizontal"; split_dir="r" ;;
      esac

      if [[ -f "$state_file" ]]; then
        mapfile -t ordered < <(
          jq -r --argjson group "$(printf '%s\n' "''${grouped[@]}" | jq -R . | jq -s .)" '
            [.windows[]?.address] as $saved
            | ($saved + $group)
            | reduce .[] as $addr ([]; if index($addr) then . else . + [$addr] end)
            | map(select(. as $addr | $group | index($addr)))
            | .[]
          ' "$state_file" 2>/dev/null || true
        )
      else
        ordered=()
      fi

      if (( ''${#ordered[@]} == 0 )); then
        ordered=("''${grouped[@]}")
      fi

      anchor="''${ordered[0]}"
      hyprctl dispatch focuswindow "address:$anchor" >/dev/null 2>&1 || true
      hyprctl dispatch lockactivegroup unlock >/dev/null 2>&1 || true

      for addr in "''${ordered[@]:1}"; do
        hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
        hyprctl dispatch layoutmsg preselect "$split_dir" >/dev/null 2>&1 || true
        hyprctl dispatch moveoutofgroup "$split_dir" >/dev/null 2>&1 || hyprctl dispatch moveoutofgroup >/dev/null 2>&1 || true
        sleep 0.05
      done

      hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || hyprctl dispatch focuswindow "address:$anchor" >/dev/null 2>&1 || true
      hypr-i3-split-mode "$saved_mode"
    '';
  };

  home.file.".local/bin/hypr-i3-split-daemon" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}"
      : "''${HYPRLAND_INSTANCE_SIGNATURE:?HYPRLAND_INSTANCE_SIGNATURE is required}"

      socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      hypr-i3-split-mode horizontal

      while true; do
        if [[ -S "$socket" ]]; then
          socat -U - "UNIX-CONNECT:$socket" | while IFS= read -r event; do
            case "$event" in
              activewindow*|openwindow*|movewindow*|changefloatingmode*|workspace*)
                hypr-i3-split-mode apply
                ;;
            esac
          done
        fi
        sleep 1
      done
    '';
  };

  home.file.".local/bin/hypr-i3-tabbed" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      clients_json="$(hyprctl clients -j)"
      workspace_id="$(hyprctl activeworkspace -j | jq -r '.id')"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/hypr-i3"
      state_file="$state_dir/tabbed-$workspace_id.json"
      mkdir -p "$state_dir"

      mapfile -t windows < <(
        jq -r --argjson ws "$workspace_id" '
          map(select(.workspace.id == $ws and (.floating | not) and (.hidden | not)))
          | sort_by(.at[1], .at[0])
          | .[].address
        ' <<< "$clients_json"
      )

      (( ''${#windows[@]} > 0 )) || exit 0

      active_addr="$(hyprctl activewindow -j | jq -r '.address // empty')"
      if [[ -z "$active_addr" ]]; then
        active_addr="''${windows[0]}"
      fi

      all_grouped="$(
        jq -r --arg active "$active_addr" --argjson ws "$workspace_id" '
          . as $clients
          | ($clients[] | select(.address == $active) | .grouped // []) as $group
          | if ($group | length) == 0 then "false"
            else
              (([ $clients[]
                | select(.workspace.id == $ws and (.floating | not) and (.hidden | not))
                | .address
              ] - $group) | length) == 0
            end
        ' <<< "$clients_json"
      )"

      if [[ "$all_grouped" == "true" ]]; then
        hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || true
        exit 0
      fi

      jq --arg active "$active_addr" --arg mode "$(hypr-i3-split-mode current)" --argjson ws "$workspace_id" '
        {
          workspace_id: $ws,
          active: $active,
          mode: $mode,
          windows: (
            map(select(.workspace.id == $ws and (.floating | not) and (.hidden | not)))
            | sort_by(.at[1], .at[0])
            | map({ address, title, class, at, size })
          )
        }
      ' <<< "$clients_json" > "$state_file"

      base_json="$(jq -c --arg a "$active_addr" '.[] | select(.address == $a)' <<< "$clients_json")"
      base_x="$(jq -r '.at[0]' <<< "$base_json")"
      base_y="$(jq -r '.at[1]' <<< "$base_json")"
      base_w="$(jq -r '.size[0]' <<< "$base_json")"
      base_h="$(jq -r '.size[1]' <<< "$base_json")"
      base_cx=$((base_x + base_w / 2))
      base_cy=$((base_y + base_h / 2))

      hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || true
      if [[ "$(hyprctl activewindow -j | jq '(.grouped // []) | length')" -le 1 ]]; then
        hyprctl dispatch togglegroup >/dev/null 2>&1 || true
      fi
      hyprctl dispatch lockactivegroup unlock >/dev/null 2>&1 || true

      for addr in "''${windows[@]}"; do
        [[ "$addr" != "$active_addr" ]] || continue

        clients_json="$(hyprctl clients -j)"
        already_grouped="$(
          jq -r --arg a "$addr" '(.[] | select(.address == $a) | .grouped // []) | length > 1' <<< "$clients_json"
        )"
        [[ "$already_grouped" != "true" ]] || continue

        win_json="$(jq -c --arg a "$addr" '.[] | select(.address == $a)' <<< "$clients_json")"
        [[ -n "$win_json" ]] || continue

        x="$(jq -r '.at[0]' <<< "$win_json")"
        y="$(jq -r '.at[1]' <<< "$win_json")"
        w="$(jq -r '.size[0]' <<< "$win_json")"
        h="$(jq -r '.size[1]' <<< "$win_json")"
        cx=$((x + w / 2))
        cy=$((y + h / 2))
        dx=$((base_cx - cx))
        dy=$((base_cy - cy))

        if (( dx * dx >= dy * dy )); then
          if (( dx >= 0 )); then preferred=(r l d u); else preferred=(l r d u); fi
        else
          if (( dy >= 0 )); then preferred=(d u r l); else preferred=(u d r l); fi
        fi

        hyprctl dispatch focuswindow "address:$addr" >/dev/null 2>&1 || true
        for dir in "''${preferred[@]}"; do
          hyprctl dispatch moveintogroup "$dir" >/dev/null 2>&1 || true
          sleep 0.03
          grouped="$(
            hyprctl clients -j | jq -r --arg a "$addr" '(.[] | select(.address == $a) | .grouped // []) | length > 1'
          )"
          [[ "$grouped" == "true" ]] && break
        done
      done

      hyprctl dispatch focuswindow "address:$active_addr" >/dev/null 2>&1 || true
      hypr-i3-split-mode apply
    '';
  };

  home.file.".local/bin/hypr-google-workspace" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      workspace="10"
      # Serialize session/manual starts while browser windows appear.
      exec 9>"$XDG_RUNTIME_DIR/hypr-google-workspace.lock"
      ${pkgs.util-linux}/bin/flock -n 9 || exit 0
      gmail_url="https://mail.google.com/mail/u/0/#inbox"
      chat_url="https://chat.google.com/"
      attempts="''${GOOGLE_WORKSPACE_ATTEMPTS:-80}"
      delay="''${GOOGLE_WORKSPACE_DELAY:-0.15}"

      for _ in $(seq 1 "$attempts"); do
        if hyprctl clients -j >/dev/null 2>&1; then
          break
        fi

        sleep "$delay"
      done

      hyprctl clients -j >/dev/null 2>&1 || exit 0

      current_workspace="$(hyprctl activeworkspace -j | jq -r '.id // empty' 2>/dev/null || true)"

      helium_addresses() {
        hyprctl clients -j | jq -r '
          .[]
          | select((.class | ascii_downcase) == "helium")
          | .address
        '
      }

      new_helium_after() {
        local before="$1"
        local regex="$2"

        hyprctl clients -j | jq -r --arg before "$before" --arg regex "$regex" '
          ($before | split("\n")) as $before_addresses
          | .[]
          | select((.class | ascii_downcase) == "helium")
          | select(.address as $address | (($before_addresses | index($address)) | not))
          | select((.title // "") | test($regex; "i"))
          | .address
        ' | tail -n 1
      }

      find_existing() {
        local regex="$1"

        hyprctl clients -j | jq -r --arg regex "$regex" '
          .[]
          | select((.class | ascii_downcase) == "helium")
          | select((.title // "") | test($regex; "i"))
          | .address
        ' | tail -n 1
      }

      launch_window() {
        local url="$1"
        local fallback_regex="$2"
        local before addr

        before="$(helium_addresses)"
        hyprctl dispatch "hl.dsp.exec_cmd('helium --new-window \"$url\"', { workspace = '$workspace silent' })" >/dev/null

        for _ in $(seq 1 "$attempts"); do
          addr="$(new_helium_after "$before" "$fallback_regex")"
          if [ -n "$addr" ]; then
            printf '%s\n' "$addr"
            return 0
          fi

          sleep "$delay"
        done

        find_existing "$fallback_regex"
      }

      move_tiled() {
        local addr="$1"

        [ -n "$addr" ] || return 0
        hyprctl dispatch "hl.dsp.window.move({ workspace = '$workspace', window = 'address:$addr', follow = false })" >/dev/null 2>&1 || true
        hyprctl dispatch "hl.dsp.focus({ window = 'address:$addr' })" >/dev/null 2>&1 || true
        hyprctl dispatch 'hl.dsp.window.float({ action = "off" })'  >/dev/null 2>&1 || true
      }

      gmail_addr="$(find_existing 'Gmail|Inbox|Mail')"

      if [ -z "$gmail_addr" ]; then
        gmail_addr="$(launch_window "$gmail_url" 'Gmail|Inbox|Mail')"
      fi

      # Browser startup can restore Chat, so check again after opening Gmail.
      chat_addr="$(find_existing '(^| - )Chat|Google Chat')"
      if [ -z "$chat_addr" ]; then
        chat_addr="$(launch_window "$chat_url" '(^| - )Chat|Google Chat')"
      fi

      # Recover matching windows restored on any workspace without closing tabs.
      while read -r addr; do
        [ -n "$addr" ] || continue
        hyprctl dispatch "hl.dsp.window.move({ workspace = '$workspace', window = 'address:$addr', follow = false })" >/dev/null
      done < <(hyprctl clients -j | jq -r '
        .[] | select((.class | ascii_downcase) == "helium")
        | select((.title // "") | test("Gmail|Inbox|Mail|(^| - )Chat|Google Chat"; "i"))
        | .address
      ')

      hyprctl dispatch "hl.dsp.focus({ workspace = '$workspace' })" >/dev/null 2>&1 || true

      move_tiled "$gmail_addr"
      hyprctl dispatch 'hl.dsp.layout("preselect r")'  >/dev/null 2>&1 || true
      move_tiled "$chat_addr"

      if [ -n "$gmail_addr" ]; then
        hyprctl dispatch "hl.dsp.focus({ window = 'address:$gmail_addr' })" >/dev/null 2>&1 || true
        hyprctl dispatch 'hl.dsp.layout("preselect r")'  >/dev/null 2>&1 || true
      fi

      if [ -n "$current_workspace" ] && [ "$current_workspace" != "$workspace" ]; then
        hyprctl dispatch "hl.dsp.focus({ workspace = '$current_workspace' })" >/dev/null 2>&1 || true
      fi
    '';
  };

  systemd.user.services.hypr-google-workspace = {
    Unit = {
      Description = "Open Gmail and Google Chat on Hyprland workspace 10";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/hypr-google-workspace";
      RemainAfterExit = true;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.file.".local/bin/helium-open" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      exec helium --new-window "$@"
    '';
  };

  programs.ghostty = {
    enable = true;
    settings = {
      background = "#000000";
      cursor-style = "block";
      shell-integration-features = "no-cursor";
      keybind = [
        "ctrl+up=csi:A"
        "ctrl+down=csi:B"
        "ctrl+left=text:\\x1bb"
        "ctrl+right=text:\\x1bwa"
        "ctrl+backspace=text:\\x17"
      ];
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
      keyboard.bindings = [
        {
          key = "Back";
          mods = "Control";
          chars = "\\u001bb";
        }
        {
          key = "Return";
          mods = "Control|Shift";
          action = "SpawnNewInstance";
        }
      ];
      colors.primary.background = "#000000";
      window.opacity = 1.0;
    };
  };

  services.mako = {
    enable = true;
    settings = {
      background-color = "#000000";
      border-color = "#38bdf8";
      text-color = "#e8f7ff";
      border-size = 1;
      border-radius = 0;
      default-timeout = 5000;
      font = "MesloLGS Nerd Font 11";
    };
  };

  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = [
        "${oledBlackWallpaper}"
      ];
      wallpaper = [
        ",${oledBlackWallpaper}"
      ];
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = false;
        ignore_empty_input = true;
      };

      background = [
        {
          monitor = "";
          path = "${oledBlackWallpaper}";
          color = "rgb(000000)";
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "260, 52";
          position = "0, -80";
          fade_on_empty = false;
          dots_center = true;
          outline_thickness = 1;
          rounding = 0;
          font_family = "MesloLGS Nerd Font";
          font_color = "rgb(e8f7ff)";
          inner_color = "rgb(000000)";
          outer_color = "rgb(38bdf8)";
          check_color = "rgb(38bdf8)";
          fail_color = "rgb(f38ba8)";
          placeholder_text = "Password";
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })'";
        ignore_dbus_inhibit = false;
      };

      listener = [
        {
          timeout = 300;
          on-timeout = "brightnessctl -s set 20%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 660;
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })' && brightnessctl -r";
        }
        {
          timeout = 1200;
          on-timeout = "grep -q 0 /sys/class/power_supply/AC0/online 2>/dev/null && systemctl suspend || true";
        }
        {
          timeout = 2700;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  home.file.".local/bin/battery-watch" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      low=15
      critical=10
      suspend_at=5
      interval=30
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/battery-watch"
      state_file="$state_dir/notified"

      ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

      find_battery() {
        for supply in /sys/class/power_supply/*; do
          [[ -r "$supply/type" ]] || continue
          read -r type < "$supply/type"
          if [[ "$type" == "Battery" ]]; then
            printf '%s\n' "$supply"
            return 0
          fi
        done
        return 1
      }

      on_ac_power() {
        for supply in /sys/class/power_supply/*; do
          [[ -r "$supply/type" && -r "$supply/online" ]] || continue
          read -r type < "$supply/type"
          if [[ "$type" == "Mains" ]]; then
            read -r online < "$supply/online"
            [[ "$online" == "1" ]] && return 0
          fi
        done
        return 1
      }

      battery_capacity() {
        battery="$(find_battery)" || return 1
        read -r capacity < "$battery/capacity"
        printf '%s\n' "$capacity"
      }

      battery_status() {
        battery="$(find_battery)" || return 1
        if [[ -r "$battery/status" ]]; then
          read -r status < "$battery/status"
        else
          status="Unknown"
        fi
        printf '%s\n' "$status"
      }

      notify() {
        ${pkgs.libnotify}/bin/notify-send "$@" >/dev/null 2>&1 || true
      }

      current_stage() {
        if [[ -r "$state_file" ]]; then
          read -r stage < "$state_file" || stage="none"
          printf '%s\n' "$stage"
        else
          printf 'none\n'
        fi
      }

      set_stage() {
        printf '%s\n' "$1" > "$state_file"
      }

      should_act() {
        on_ac_power && return 1
        status="$(battery_status || true)"
        [[ "$status" == "Charging" || "$status" == "Full" ]] && return 1
        return 0
      }

      while true; do
        capacity="$(battery_capacity || true)"

        if [[ -z "$capacity" || ! "$capacity" =~ ^[0-9]+$ ]]; then
          ${pkgs.coreutils}/bin/sleep "$interval"
          continue
        fi

        if ! should_act || (( capacity > low )); then
          set_stage none
          ${pkgs.coreutils}/bin/sleep "$interval"
          continue
        fi

        stage="$(current_stage)"

        if (( capacity <= suspend_at )); then
          if [[ "$stage" != "suspend" ]]; then
            notify -u critical -t 0 \
              "Battery critically low" \
              "Battery at $capacity%. Suspending in 30 seconds unless power is connected."
            set_stage suspend
          fi

          ${pkgs.coreutils}/bin/sleep 30
          capacity_after="$(battery_capacity || echo 100)"

          if should_act && [[ "$capacity_after" =~ ^[0-9]+$ ]] && (( capacity_after <= suspend_at )); then
            notify -u critical -t 5000 \
              "Suspending now" \
              "Battery still at $capacity_after%."
            ${pkgs.systemd}/bin/systemctl suspend || true
          fi
        elif (( capacity <= critical )); then
          if [[ "$stage" != "critical" && "$stage" != "suspend" ]]; then
            notify -u critical -t 0 \
              "Battery critical" \
              "Battery at $capacity%. Connect power soon."
            set_stage critical
          fi

          ${pkgs.coreutils}/bin/sleep "$interval"
        else
          if [[ "$stage" == "none" ]]; then
            notify -u normal -t 15000 \
              "Battery low" \
              "Battery at $capacity%."
            set_stage low
          fi

          ${pkgs.coreutils}/bin/sleep "$interval"
        fi
      done
    '';
  };

  systemd.user.services.battery-watch = {
    Unit = {
      Description = "Warn and suspend before the battery is empty";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "%h/.local/bin/battery-watch";
      Restart = "always";
      RestartSec = "10s";
    };

    Install.WantedBy = [ "default.target" ];
  };

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "bottom";
      height = 28;
      modules-left = [ "hyprland/workspaces" "hyprland/window" ];
      modules-right = [ "bluetooth" "pulseaudio" "battery" "custom/power-draw" "memory" "cpu" "network" "clock" ];
      "hyprland/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
      };
      "hyprland/window" = {
        max-length = 60;
      };
      bluetooth = {
        format = "";
        format-disabled = "";
        format-off = "";
        format-on = "";
        format-connected = "{device_alias}";
        format-connected-battery = "{device_alias} {device_battery_percentage}%";
        format-no-controller = "";
        max-length = 28;
        tooltip-format = "Bluetooth: {status}";
        tooltip-format-connected = "{num_connections} connected\n{device_enumerate}";
        tooltip-format-connected-battery = "{device_alias}: {device_battery_percentage}%\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}";
        tooltip-format-enumerate-connected-battery = "{device_alias}: {device_battery_percentage}%";
        on-click = "blueman-manager";
        on-click-right = "bluetoothctl power off";
      };
      pulseaudio = {
        format = "{volume}%";
        format-muted = "muted";
        on-click = "pavucontrol";
      };
      battery = {
        format = "{capacity}%";
        format-charging = "{capacity}%+";
      };
      "custom/power-draw" = {
        exec = ''
          power=/sys/class/power_supply/BAT0/power_now
          status=/sys/class/power_supply/BAT0/status

          [ -r "$power" ] || exit 0

          microwatts="$(cat "$power")"
          [ "$microwatts" -gt 0 ] || exit 0

          watts="$(awk -v mw="$microwatts" 'BEGIN { printf "%.1f", mw / 1000000 }')"
          case "$(cat "$status" 2>/dev/null)" in
            Charging) printf '%sW+' "$watts" ;;
            *) printf '%sW' "$watts" ;;
          esac
        '';
        interval = 5;
        return-type = "text";
        tooltip = false;
      };
      memory = {
        format = "{percentage}%";
      };
      cpu = {
        format = "{usage}%";
      };
      network = {
        format-wifi = "{ifname} {essid} {bandwidthUpBytes} {bandwidthDownBytes}";
        format-ethernet = "{ifname} {ipaddr}";
        format-disconnected = "{ifname} disconnected";
        on-click = "networkmanager_dmenu";
        on-click-right = "nm-connection-editor";
      };
      clock = {
        format = "{:%H:%M:%S %d-%m-%Y}";
        format-alt = "{:%H:%M}";
      };
    };
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: "MesloLGS Nerd Font";
        font-size: 14px;
        min-height: 0;
      }

      window#waybar {
        background: #000000;
        color: #e8f7ff;
      }

      #workspaces button {
        padding: 0 8px;
        color: #8fb9d0;
        background: transparent;
      }

      #workspaces button.active {
        color: #ffffff;
        background: #38bdf8;
      }

      #workspaces button.urgent {
        color: #ffffff;
        background: #38bdf8;
      }

      #window,
      #pulseaudio,
      #battery,
      #custom-power-draw,
      #memory,
      #cpu,
      #network,
      #bluetooth,
      #clock {
        padding: 0 8px;
      }

      #clock,
      #network,
      #pulseaudio {
        color: #38bdf8;
      }

      #bluetooth {
        color: #e8f7ff;
      }
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    configType = "lua";
    plugins = [ pkgs.hyprlandPlugins.hy3 ];
    extraConfig = builtins.readFile ./hyprland.lua;
  };

  home.file.".local/bin/push-to-talk-toggle-wayland" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      pidfile="/tmp/push-to-talk.pid"
      audiofile="/tmp/push-to-talk.wav"
      notifyfile="/tmp/push-to-talk-notification.id"
      keyfile="$HOME/.config/push-to-talk/groq_api_key"

      notify_status() {
        local timeout="$1"
        local message="$2"
        local replace_args=()
        if [[ -s "$notifyfile" ]]; then
          replace_args=(-r "$(cat "$notifyfile")")
        fi

        local id
        id="$(notify-send -p -u low -t "$timeout" "''${replace_args[@]}" "Push-to-talk" "$message" 2>/dev/null || true)"
        if [[ "$id" =~ ^[0-9]+$ ]]; then
          printf '%s\n' "$id" > "$notifyfile"
        fi
      }

      if [[ ! -r "$keyfile" ]]; then
        notify-send -u critical "Push-to-talk" "Missing $keyfile"
        exit 1
      fi

      api_key="$(cat "$keyfile")"

      if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        pid="$(cat "$pidfile")"
        kill -INT "$pid" 2>/dev/null || true
        while kill -0 "$pid" 2>/dev/null; do
          sleep 0.1
        done
        rm -f "$pidfile"
        notify_status 2000 "Transcribing..."

        response="$(
          curl -s https://api.groq.com/openai/v1/audio/transcriptions \
            -H "Authorization: Bearer $api_key" \
            -F "file=@$audiofile" \
            -F "model=whisper-large-v3-turbo" \
            -F "temperature=0" \
            -F "response_format=json"
        )"

        text="$(printf '%s' "$response" | jq -r '.text // empty')"

        if [[ -n "$text" ]]; then
          printf '%s' "$text" | wl-copy
          wtype "$text"
        fi

        rm -f "$audiofile"
      else
        notify_status 0 "Recording..."
        arecord -f S16_LE -r 44100 -c 1 -q "$audiofile" &
        echo "$!" > "$pidfile"
      fi
    '';
  };
}
