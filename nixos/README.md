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
sudo nixos-rebuild switch --flake path:/home/adrian/dotfiles/nixos#nixos --accept-flake-config
```

From another machine, copy this repo's config over first:

```sh
scp -r nixos/. adrian@<laptop-ip>:/tmp/nixos-config/
ssh -t adrian@<laptop-ip> 'sudo cp -a /tmp/nixos-config/. /etc/nixos/ && cd /etc/nixos && sudo nixos-rebuild switch --flake .#nixos'
```

## Update packages

Update pinned inputs and rebuild:

```sh
nix flake update --flake path:/home/adrian/dotfiles/nixos --accept-flake-config
nix build --no-link --max-jobs 1 --cores 2 path:/home/adrian/dotfiles/nixos#nixosConfigurations.nixos.config.system.build.toplevel --accept-flake-config
sudo nixos-rebuild switch --flake path:/home/adrian/dotfiles/nixos#nixos --accept-flake-config
```

Commit `flake.lock` after testing. The Codex CLI and Claude Code versions in
`overlays/ai-cli.nix` and the Helium version/hash in `configuration.nix` are
pinned separately; `nix flake update` does not update those pins.
A successful build does not activate the configuration. Kernel/initrd changes
need a reboot into the new generation; running applications need a normal
restart to use their updated binaries.

## Desktop responsiveness

Nix has its own system daemon outside the Codex job limits. It is configured
for one build with two cores and two simultaneous substitutions, plus root-disk
limits of 64 MB/s read and 16 MB/s write. The September 12 package refresh
coincided with renewed multi-application I/O stalls while this daemon was
uncapped; that build was interrupted. Lower CPU/I/O weights supplement the
explicit bandwidth limits. These settings take effect only after activation
(or an explicit runtime `systemctl set-property` for the daemon).

The encrypted root enables TRIM passthrough with
`boot.initrd.luks.devices.cryptroot.allowDiscards = true`; the weekly fstrim
service can therefore trim `/`, not just `/boot`. This keeps content encryption,
but exposes unused-block layout on the physical device. On September 12,
224.2 GiB was trimmed after enabling passthrough at runtime. SSD latency improved
sharply in the next sample, but variable workloads and remaining stalls prevent
claiming a complete fix.

After activation and reboot, check:

```sh
lsblk -D
cat /sys/block/nvme0n1/queue/scheduler
sysctl vm.dirty_background_bytes vm.dirty_bytes
systemctl status fstrim.timer
systemctl --failed
systemctl --user --failed
```

`cryptroot` must show nonzero discard support. Python, smartmontools and
cryptsetup are installed declaratively for diagnostics. The reviewed temporary
Codex guard service is backed up before activation and explicitly managed by
Home Manager, preventing the previous file-collision activation failure.

The September 12 storage-stall mitigation configures `mq-deadline` for
`nvme0n1` and writeback thresholds of 64 MiB (background) / 256 MiB
(writer participation). These are provisional latency settings, not a verified
cure or hard caps. They need NixOS activation to persist across boots. The
[kernel writeback documentation](https://docs.kernel.org/admin-guide/sysctl/vm.html#dirty-background-bytes)
and [deadline scheduler documentation](https://docs.kernel.org/block/deadline-iosched.html)
describe the controls.

To try only these settings without rebuilding or restarting applications:

```sh
sudo python3 /home/adrian/dotfiles/nixos/scripts/desktop-io-tuning.py apply
```

The helper verifies kernel readback and saves the original settings in
`/run/desktop-io-tuning.json`. Restore them with the same command ending in
`rollback`; `status` reads the live settings without sudo. A reboot restores
the active NixOS generation's settings. Validate responsiveness under normal
work before treating the mitigation as successful.

Codex child jobs have a shared 300% CPU quota and a 4 GiB memory
high watermark, with lower CPU and I/O weights. The Electron UI and its direct
Codex backend run in a separate sibling scope with their own 4 GiB memory
high watermark, normal CPU/I/O weights, and no CPU or disk bandwidth caps. The memory watermark applies
reclaim/throttling; it is not a hard kill limit.

On this laptop's `/dev/nvme0n1`, the guard also caps reads at 64 MB/s, writes
at 32 MB/s, and each direction at 2,000 IOPS. This trades background job
throughput for disk headroom. `IOWeight` alone was ineffective with the
previous `none` scheduler and inactive I/O cost controller; these explicit limits are
enforced by `io.max` instead.
See the [kernel I/O controller documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#io-interface-files).

Chromium can rename the running app's systemd scope, so
`codex-resource-guard.timer` checks its actual executable and scope every
15 seconds. It handles both the `ChatGPT` and legacy `electron` executables
inside the Codex Nix package without matching ordinary browsers. Chromium moves
only its main process into the new scope; the guard adopts the verified Codex
UI and backend into a delegated `app-codex-desktop-<pid>.scope`, including
renderers left in the compositor's service. Other executable branches and their
descendants move into `app-codex-jobs-<pid>.scope`. New jobs may share the
backend scope until the next timer pass (up to approximately 16 seconds).
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

## Short-term stability monitoring

`desktop-health-monitor.service` samples every five seconds with low CPU/I/O
priority. It records cumulative global and per-group pressure, disk counters,
memory events and occasional blocked process names, without command lines or
privileged kernel stacks. It reads an explicit expiry timestamp from
`~/.local/state/desktop-health-monitor/until`; absent or expired means exit.
It resumes on login only while that observation window is still valid.
Logs are private and bounded to two 32 MiB files.

To start a new 24-hour observation window after activation:

```sh
python3 -c 'from pathlib import Path; import time; p=Path.home()/".local/state/desktop-health-monitor"; p.mkdir(parents=True, exist_ok=True); (p/"until").write_text(str(time.time()+86400))'
systemctl --user restart desktop-health-monitor.service
```

Check with `systemctl --user status desktop-health-monitor.service`. To stop
and prevent resumption, remove the `until` file and stop the service. The Codex
scheduled follow-up is separate from the collector and has its own end time.
Compare counter deltas only within one boot and account for suspend gaps.
Global I/O pressure can include deliberately throttled background jobs; it is
not by itself proof of slow hardware or a frozen desktop. Do not sum byte
counters from both `nvme0n1` and `dm-0` as physical traffic.

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
