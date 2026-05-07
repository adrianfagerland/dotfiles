{ config, pkgs, ... }:

let
  heliumVersion = "0.12.1.1";
  heliumBrowser = pkgs.appimageTools.wrapType2 rec {
    pname = "helium";
    version = heliumVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
      hash = "sha256-+UE+JqQtxbA5szPvAohapXlES21VBOdNsV6Ej1dRRfs=";
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
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  time.timeZone = "Europe/Oslo";
  i18n.defaultLocale = "en_US.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  powerManagement.enable = true;
  zramSwap.enable = true;
  services.power-profiles-daemon.enable = true;
  services.thermald.enable = true;
  services.upower.enable = true;
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
    wantedBy = [ "multi-user.target" ];
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
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced
      else
        ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver
      fi
    '';
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${pkgs.systemd}/bin/systemctl --no-block start power-profile-auto.service"
  '';

  users.users.adrian = {
    isNormalUser = true;
    description = "Adrian";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "input" ];
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
    withApplet = false;
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
    curl
    wget
    jq
    unzip
    ripgrep
    fd
    btop
    pciutils
    powertop
    upower

    ghostty
    alacritty
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
    blueman
    bitwarden-desktop
    bitwarden-cli
    rbw
    rofi-rbw
    libsecret
    seahorse

    rclone
    pay-respects
    codex
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
