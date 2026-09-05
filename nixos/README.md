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

## Desktop responsiveness

Codex Desktop and its child jobs share a 300% CPU quota and a 6 GiB memory
high watermark, with lower CPU and I/O weights. The memory watermark applies
reclaim/throttling; it is not a hard kill limit.

On this laptop's `/dev/nvme0n1`, the guard also caps reads at 64 MB/s, writes
at 32 MB/s, and each direction at 2,000 IOPS. This trades background job
throughput for disk headroom. `IOWeight` alone was ineffective with the current
`none` scheduler and inactive I/O cost controller; these explicit limits are
enforced by `io.max` instead.
See the [kernel I/O controller documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#io-interface-files).

Chromium can rename the running app's systemd scope, so
`codex-resource-guard.timer` checks its actual executable and scope every
15 seconds. It handles both the `ChatGPT` and legacy `electron` executables
inside the Codex Nix package without matching ordinary browsers. Chromium moves
only its main process into the new scope; the guard adopts the verified Codex
process tree into a dedicated, delegated `app-codex-desktop-<pid>.scope`. This
includes renderers left in the compositor's service and existing child jobs.
Existing memory charges may remain in the old group until released; a normal
Codex restart clears that accounting history. Check it with:

```sh
systemctl --user status codex-resource-guard.timer
journalctl --user -u codex-resource-guard.service
cat /proc/pressure/{cpu,memory,io}
python3 -m unittest discover -s tests
```

The scope split is described in
[Chromium's systemd integration](https://github.com/chromium/chromium/blob/main/components/dbus/xdg/systemd.cc).

The September 2026 investigation found disk stalls, memory-pressure events,
and an unguarded `app-org.chromium.Chromium-<pid>.scope` containing Codex and
recursive store scans. This guard repairs the missing resource limits; it does
not establish that every possible cause of a display freeze has been resolved.

## Google Drive sync

Home Manager creates an rclone remote stub for the Vedtak shared drive
(`vedtak-shared`, team drive ID `0ANLilboyAAoHUk9PVA`), a `~/gdrive` folder, and
a user timer that runs filtered `rclone bisync` every two minutes.

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
