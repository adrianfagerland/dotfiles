{
  description = "Adrian's NixOS desktop install";

  nixConfig = {
    extra-substituters = [
      "https://attic.xuyh0120.win/lantian"
    ];
    extra-trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
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
                  version = "26.928.21956";
                  upstreamDeb = final.fetchurl {
                    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${version}_amd64.deb";
                    hash = "sha256-msjQcRtGATaNSd7dv1Co/lI1jLYbbZ96XBi0HtRQCtg=";
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
            nix-cachyos-kernel.overlays.pinned
          ];

          boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;

          nix.settings.substituters = [
            "https://attic.xuyh0120.win/lantian"
          ];
          nix.settings.trusted-public-keys = [
            "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
          ];

          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.adrian = import ./home.nix;
        })
      ];
    };
  };
}
