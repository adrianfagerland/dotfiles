{
  description = "Adrian's NixOS desktop install";

  nixConfig = {
    extra-substituters = [
      "https://cache.lantian.pub/lantian"
    ];
    extra-trusted-public-keys = [
      "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Use the release branch so the CachyOS kernel is likely to be in binary cache.
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";

    codex-desktop-linux.url = "github:ilysenko/codex-desktop-linux";

    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, nix-cachyos-kernel, codex-desktop-linux, claude-desktop, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            (import ./overlays/ai-cli.nix)
            (final: prev: {
              codex-desktop =
                let
                  packaged = codex-desktop-linux.packages.${final.stdenv.hostPlatform.system}.codex-desktop;
                  version = "26.1103.60933";
                  upstreamDeb = final.fetchurl {
                    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
                    hash = "sha256-B0bpuldRgvXb4yYXuCpkXrk61XyliOWpNYaVprZa7nE=";
                  };
                in
                # Keep the official stable payload explicitly pinned.
                packaged.overrideAttrs (old: {
                  inherit version;
                  __intentionallyOverridingVersion = true;
                  installPhase = builtins.replaceStrings
                    [ (toString old.passthru.upstreamDeb) ]
                    [ (toString upstreamDeb) ]
                    old.installPhase;
                  passthru = old.passthru // {
                    inherit upstreamDeb;
                    upstreamVersion = version;
                  };
                });
            })
            claude-desktop.overlays.default
            (final: prev: {
              # Pin the official stable payload while the packaging input catches up.
              claude-desktop = prev.claude-desktop.overrideAttrs (_: rec {
                version = "4.23118.1";
                src = final.fetchurl {
                  url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
                  hash = "sha256-sJzN1ys4kWyWN9SFSNtw53xCXrLgm7RnRlQJ0v+dKHo=";
                };
              });
            })
            nix-cachyos-kernel.overlays.pinned
          ];

          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

          nix.settings.substituters = [
            "https://cache.lantian.pub/lantian"
          ];
          nix.settings.trusted-public-keys = [
            "lantian:WVGO7vsRMSEN+h7Lp7kv6SAmrkEXgUGbbXm7jMDjBuQ="
          ];

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.adrian = import ./home.nix;
        })
      ];
    };
  };
}
