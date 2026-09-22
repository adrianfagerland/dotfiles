"""Low-overhead, bounded desktop measurements; no privileged reads or settings writes.

The caller writes a Unix expiry time to ~/.local/state/desktop-health-monitor/until.
Missing/expired control files stop collection. Logs rotate at 32 MiB (one backup).
"""

import json
import os
from pathlib import Path
import time

STATE = Path.home() / '.local/state/desktop-health-monitor'
CGROUP = Path('/sys/fs/cgroup')
MAX_LOG_BYTES = 32 * 1024 * 1024


def read(path):
    try:
        return path.read_text().strip()
    except OSError:
        return None


def counters(path):
    text = read(path)
    if text is None:
        return None
    return {parts[0]: int(parts[1]) for line in text.splitlines()
            if len(parts := line.split()) == 2 and parts[1].isdigit()}


def pressure(path):
    text = read(path)
    if text is None:
        return None
    return {line.split()[0]: int(line.rsplit('total=', 1)[1]) for line in text.splitlines()}


def sample(tick):
    user = CGROUP / f'user.slice/user-{os.getuid()}.slice/user@{os.getuid()}.service'
    groups = list((user / 'app.slice').glob('app-codex-*.scope'))
    groups += [user / 'session.slice/wayland-wm@hyprland.desktop.service',
               CGROUP / 'system.slice/docker.service',
               CGROUP / 'system.slice/nix-daemon.service']
    row = {
        'time': time.time(), 'monotonic': time.monotonic(),
        'boot_id': read(Path('/proc/sys/kernel/random/boot_id')),
        'pressure': {key: pressure(Path('/proc/pressure') / key) for key in ('cpu', 'memory', 'io')},
        'meminfo': {key: value for key, value in
                    (line.split(':', 1) for line in Path('/proc/meminfo').read_text().splitlines())
                    if key in ('MemAvailable', 'Dirty', 'Writeback', 'SwapFree', 'SwapTotal')},
        'vmstat': {key: value for key, value in counters(Path('/proc/vmstat')).items()
                   if key in ('pswpin', 'pswpout', 'pgmajfault', 'allocstall_normal')},
        'disks': {parts[2]: list(map(int, parts[3:]))
                  for line in Path('/proc/diskstats').read_text().splitlines()
                  if (parts := line.split())[2] in ('nvme0n1', 'dm-0')},
        'groups': {},
    }
    for group in groups:
        if group.exists():
            row['groups'][group.name] = {
                'io': pressure(group / 'io.pressure'),
                'memory': pressure(group / 'memory.pressure'),
                'memory_events': counters(group / 'memory.events'),
                'cpu': counters(group / 'cpu.stat'),
                'memory_current': read(group / 'memory.current'),
                'swap_current': read(group / 'memory.swap.current'),
                'io_stat': read(group / 'io.stat'),
            }
    if tick % 2 == 0:
        row['blocked'] = []
        for proc in Path('/proc').glob('[0-9]*'):
            status = read(proc / 'status') or ''
            if any(line.startswith('State:') and 'D (' in line for line in status.splitlines()):
                row['blocked'].append({'pid': int(proc.name), 'name': read(proc / 'comm'),
                                       'wchan': read(proc / 'wchan'), 'cgroup': read(proc / 'cgroup')})
    if tick % 12 == 0:
        row['settings'] = {
            'scheduler': read(Path('/sys/block/nvme0n1/queue/scheduler')),
            'discard_max_bytes': read(Path('/sys/block/dm-0/queue/discard_max_bytes')),
            'dirty_bytes': read(Path('/proc/sys/vm/dirty_bytes')),
            'dirty_background_bytes': read(Path('/proc/sys/vm/dirty_background_bytes')),
            'system': os.path.realpath('/run/current-system'),
        }
    return row


def main():
    STATE.mkdir(parents=True, exist_ok=True)
    path = STATE / 'samples.jsonl'
    tick = 0
    while True:
        until = read(STATE / 'until')
        if until is None or time.time() >= float(until):
            return
        start = time.monotonic()
        row = sample(tick)
        if path.exists() and path.stat().st_size >= MAX_LOG_BYTES:
            path.replace(path.with_suffix('.jsonl.1'))
        with path.open('a') as output:
            output.write(json.dumps(row, separators=(',', ':')) + '\n')
        tick += 1
        time.sleep(max(0, 5 - (time.monotonic() - start)))


if __name__ == '__main__':
    main()
