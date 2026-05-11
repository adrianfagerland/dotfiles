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

## Google Drive sync

Home Manager creates an rclone remote stub for the Vedtak shared drive
(`vedtak-shared`, team drive ID `0ANLilboyAAoHUk9PVA`), a `~/gdrive` folder, and
a user timer that runs `rclone bisync` every two minutes.

After a fresh install, authorize the remote once:

```sh
rclone config reconnect vedtak-shared:
```

Then either wait for the timer or run the first sync directly:

```sh
rclone-vedtak-gdrive-sync --resync
```

The automatic first run only performs `--resync` when `~/gdrive` is empty. If it
is not empty, inspect the folder first and run the command above when the Drive
side should be treated as the source of truth.

## Roll back

Temporarily switch back:

```sh
sudo nixos-rebuild switch --rollback
```

Or pick an older generation from the systemd-boot menu.
