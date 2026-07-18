{ config, pkgs, ... }:

let
  heliumVersion = "0.13.4.1";
  heliumBrowserApp = pkgs.appimageTools.wrapType2 rec {
    pname = "helium";
    version = heliumVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
      hash = "sha256-z23up+T6bj6F+cQslmI92bEksIAw1OQHRIrmQSaaxY8=";
    };
    extraInstallCommands =
      let
        desktopItem = pkgs.makeDesktopItem {
          name = "helium";
          desktopName = "Helium";
          genericName = "Web Browser";
          exec = "helium %U";
          categories = [ "Network" "WebBrowser" ];
          mimeTypes = [
            "text/html"
            "text/xml"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ];
        };
      in
      ''
        mkdir -p $out/share/applications
        cp ${desktopItem}/share/applications/helium.desktop $out/share/applications/
      '';
  };
  heliumBrowser = pkgs.symlinkJoin {
    name = "helium-${heliumVersion}";
    paths = [ heliumBrowserApp ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      rm -f $out/bin/helium
      makeWrapper ${heliumBrowserApp}/bin/helium $out/bin/helium \
        --set GTK_USE_PORTAL 1 \
        --set XDG_CURRENT_DESKTOP Hyprland \
        --set XDG_SESSION_DESKTOP Hyprland \
        --set XDG_SESSION_TYPE wayland \
        --set NIXOS_OZONE_WL 1 \
        --add-flags --ozone-platform=wayland \
        --add-flags --enable-features=UsePortalFileDialog \
        --add-flags --disable-features=VaapiVideoDecoder,VaapiVideoEncoder,VaapiVideoDecodeLinuxGL
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    # bitwarden-desktop 2026.5.0 is still packaged against this EOL Electron.
    "electron-39.8.10"
  ];

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      zstd
      openssl
      libffi
      sqlite
      xz
      bzip2
      libuuid
      glib
      curl
      libxml2

      # Runtime libraries for Playwright's bundled Chromium (e2e tests). The
      # downloaded chrome-headless-shell uses the plain glibc loader, so these
      # must be reachable via LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH at test time
      # (they aggregate into /run/current-system/sw/share/nix-ld/lib).
      nss
      nspr
      atk
      at-spi2-atk
      at-spi2-core
      cups
      dbus
      libdrm
      libgbm
      libxkbcommon
      expat
      alsa-lib
      pango
      cairo
      gtk3
      gdk-pixbuf
      fontconfig
      freetype
      systemd # libudev.so.1
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxrender
      libxtst
      libxi
      libxcursor
      libxscrnsaver
      libxshmfence
    ];
  };

  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [
      networkmanager-openconnect
    ];
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Keep core dumps for large processes (e.g. Helium/Chromium renderers) so crashes
  # are debuggable. Defaults cap ProcessSizeMax/ExternalSizeMax at 1G, which silently
  # drops multi-GB browser cores.
  systemd.coredump.enable = true;
  systemd.coredump.settings.Coredump = {
    Storage = "external";
    Compress = "yes";
    ProcessSizeMax = "8G";
    ExternalSizeMax = "8G";
    MaxUse = "10G";
  };

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  powerManagement.enable = true;
  services.power-profiles-daemon.enable = true;

  # --- Out-of-memory handling ---------------------------------------------
  # On 2026-07-07 a memory spike drove free swap to ~0; a heap allocation in
  # Hyprland then failed and the compositor segfaulted, tearing down the whole
  # graphical session (looked like a spontaneous "crash + logout"). Three
  # layers now guard against a repeat:

  # 1. zram: fast, compressed, RAM-backed swap. Used first (higher priority).
  zramSwap.enable = true;

  # 2. A real on-disk swapfile as overflow past zram, giving memory pressure
  #    genuine runway instead of a hard wall. It lives on the LUKS-encrypted
  #    root, so it is encrypted at rest. Auto-created on the next rebuild.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024; # MiB => 16 GiB
    }
  ];

  # 3. earlyoom: shed a memory hog *before* the kernel's hard OOM wall, so a
  #    spike can never starve the compositor into a failed allocation again.
  #    SIGTERM at 5% free RAM / 10% free swap (SIGKILL at half of each). It is
  #    told to never target the compositor or core session plumbing, and to
  #    prefer the heavy Electron/browser apps as victims. earlyoom honours
  #    oom_score_adj, and the compositor runs at +200 (more killable than the
  #    default 0), so the explicit --avoid list is what actually shields it.
  #    (A user systemd unit cannot lower Hyprland below the user manager's
  #    score without CAP_SYS_RESOURCE, so --avoid is the reliable lever here.)
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
    freeSwapThreshold = 10;
    enableNotifications = true; # desktop notification naming the killed process
    extraArgs = [
      "-g" # kill the whole process group (e.g. a browser's tab tree)
      "--avoid"
      "(Hyprland|hyprlock|wayland-wm|uwsm|Xwayland|systemd|sd-pam|gnome-keyring|pipewire|wireplumber|dbus|sshd)"
      "--prefer"
      "(helium|chrome|chromium|electron|claude|codex|bun)"
    ];
  };

  # Run a single userspace OOM guard. systemd-oomd (on by default) acts on
  # cgroup PSI pressure and did not intervene in time on 2026-07-07; running it
  # alongside earlyoom means two daemons with different policies both killing
  # processes. Let earlyoom (tuned above) be the sole guard.
  systemd.oomd.enable = false;
  # ------------------------------------------------------------------------
  services.thermald.enable = true;
  services.upower = {
    enable = true;
    usePercentageForPolicy = true;
    percentageLow = 15;
    percentageCritical = 8;
    percentageAction = 5;
    criticalPowerAction = "Suspend";
    allowRiskyCriticalPowerAction = true;
  };
  services.fwupd.enable = true;
  services.fstrim.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandlePowerKey = "suspend";
    HandlePowerKeyLongPress = "poweroff";
  };

  security.pam.services.hyprlock = { };

  systemd.services.battery-charge-threshold = {
    description = "Limit battery charging to preserve battery health";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      threshold=/sys/class/power_supply/BAT0/charge_control_end_threshold
      if [ -w "$threshold" ]; then
        echo 80 > "$threshold"
      fi
    '';
  };

  systemd.services.power-profile-auto = {
    description = "Set power profile based on AC state";
    wantedBy = [ "graphical.target" ];
    wants = [ "power-profiles-daemon.service" ];
    after = [ "power-profiles-daemon.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ac_online=0
      for supply in /sys/class/power_supply/*; do
        if [ -r "$supply/type" ] && [ "$(cat "$supply/type")" = "Mains" ] && [ -r "$supply/online" ]; then
          ac_online="$(cat "$supply/online")"
          break
        fi
      done

      if [ "$ac_online" = "1" ]; then
        profile=balanced
      else
        profile=power-saver
      fi

      for attempt in $(seq 1 20); do
        if ${pkgs.power-profiles-daemon}/bin/powerprofilesctl list | grep -Eq "^\\*? *$profile:"; then
          ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$profile"
          exit 0
        fi
        sleep 0.5
      done

      echo "Power profile '$profile' is not available" >&2
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl list >&2 || true
    '';
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${pkgs.systemd}/bin/systemctl --no-block start power-profile-auto.service"
  '';

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  virtualisation.podman = {
    enable = true;
    # Docker (above) already owns the `docker` command and /run/docker.sock, so
    # leave dockerCompat/dockerSocket off — enabling them would collide with
    # virtualisation.docker. Podman runs rootless by default, no group needed.
    defaultNetwork.settings.dns_enabled = true; # container name DNS on the default net
  };

  users.users.adrian = {
    isNormalUser = true;
    description = "Adrian";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" "docker" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMkyIDP02Cr7ZLEyyyJWFq6G7mwfs7JYr1siqYh3ev+q adrian@Mac.lan"
    ];
  };

  security.sudo.wheelNeedsPassword = true;

  programs.dconf.enable = true;
  programs.zsh.enable = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-termfilechooser
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

  services.xserver.xkb = {
    layout = "drix";
    variant = "";
    options = "caps:swapescape,ctrl:swap_lalt_lctl";
    extraLayouts.drix = {
      description = "English custom Norwegian letters";
      languages = [ "eng" ];
      symbolsFile = ./xkb/drix;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman = {
    enable = true;
  };

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  programs.seahorse.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    GTK_USE_PORTAL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.meslo-lg
  ];

  environment.systemPackages = with pkgs; [
    git
    gh
    vim
    neovim
    zed-editor
    (writeShellScriptBin "zed" ''
      exec ${zed-editor}/bin/zeditor "$@"
    '')
    curl
    wget
    jq
    unzip
    ripgrep
    fd
    google-cloud-sdk
    btop
    pciutils
    powertop
    upower

    ghostty
    alacritty
    yazi
    google-chrome
    heliumBrowser
    rofi
    waybar
    mako
    libnotify
    hyprpaper
    hyprlock
    hypridle
    nwg-displays
    kanshi

    grim
    slurp
    swappy
    wl-clipboard
    cliphist
    socat
    wtype

    brightnessctl
    pamixer
    pavucontrol
    networkmanagerapplet
    networkmanager_dmenu
    openconnect
    tigervnc
    (writeShellScriptBin "vnc-mac-mini" ''
      exec ${tigervnc}/bin/vncviewer \
        -via adrian@100.75.174.48 \
        "$@" \
        localhost:0
    '')
    blueman
    bitwarden-desktop
    bitwarden-cli
    rbw
    rofi-rbw
    libreoffice
    libsecret
    seahorse

    rclone
    pay-respects
    codex
    codex-desktop
    claude-code
    claude-desktop-fhs
    uv
    pnpm
    bun
    rustup
    spotify-player

    alsa-utils
    sox
  ];

  # Set this to the NixOS release used for the first install.
  system.stateVersion = "25.11";
}
