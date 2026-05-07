# NixOS laptop setup

This is Adrian's NixOS + Hyprland laptop config.

## Fresh install

Boot the NixOS installer, partition and mount the target system at `/mnt`, then copy this folder to the installer:

```sh
scp -r nixos/* root@<installer-ip>:/mnt/etc/nixos/
```

Generate hardware config on the target:

```sh
nixos-generate-config --root /mnt
```

Keep the generated `/mnt/etc/nixos/hardware-configuration.nix`, then install:

```sh
nixos-install --flake /mnt/etc/nixos#nixos
```

## Rebuild an existing machine

From the laptop itself:

```sh
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

From another machine, copy this repo's config over first:

```sh
scp -r nixos/. adrian@<laptop-ip>:/tmp/nixos-config/
ssh -t adrian@<laptop-ip> 'sudo cp -a /tmp/nixos-config/. /etc/nixos/ && cd /etc/nixos && sudo nixos-rebuild switch --flake .#nixos'
```

## Update packages

Update pinned inputs and rebuild:

```sh
cd /etc/nixos
sudo nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

Commit `flake.lock` after testing.

## Roll back

Temporarily switch back:

```sh
sudo nixos-rebuild switch --rollback
```

Or pick an older generation from the systemd-boot menu.
