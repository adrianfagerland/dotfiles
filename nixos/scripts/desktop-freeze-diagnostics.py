"""Read-only system diagnostics. Run with sudo; writes a private report in /run."""

import json
import os
from pathlib import Path
import subprocess
import shutil
import tempfile
import time


def read(path):
    try:
        return Path(path).read_text().strip()
    except OSError as error:
        return str(error)


def command(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=15)
        return {"status": result.returncode, "stdout": result.stdout, "stderr": result.stderr}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {"error": str(error)}


def sample():
    blocked = []
    for proc in Path('/proc').glob('[0-9]*'):
        status = read(proc / 'status')
        if any(line.startswith('State:') and 'D (' in line for line in status.splitlines()):
            blocked.append({"pid": int(proc.name), "name": read(proc / 'comm'),
                            "stack": read(proc / 'stack'), "wchan": read(proc / 'wchan'),
                            "cgroup": read(proc / 'cgroup')})
    return {"time": time.time(), "blocked": blocked,
            "diskstats": read('/proc/diskstats'), "meminfo": read('/proc/meminfo'),
            "pressure": {key: read('/proc/pressure/' + key) for key in ('cpu', 'memory', 'io')}}


def main():
    if os.geteuid() != 0:
        raise SystemExit('Run with sudo to read SSD health and blocked kernel stacks.')
    directory = Path(tempfile.mkdtemp(prefix='desktop-freeze-', dir='/run'))
    report = directory / 'report.json'
    data = {
        "smart": command(shutil.which('smartctl') or '/nix/store/qhnwii9l2nmlb932vhbsp8b07bwnhrgy-smartmontools-7.5/bin/smartctl', '-x', '/dev/nvme0n1'),
        "encryption": command(shutil.which('cryptsetup') or '/nix/store/lqbk574wjvikykdx4grkjkvv65mky6si-cryptsetup-2.8.6-bin/bin/cryptsetup', 'status', 'cryptroot'),
        "discard_max_bytes": read('/sys/block/dm-0/queue/discard_max_bytes'),
        "scheduler": read('/sys/block/nvme0n1/queue/scheduler'),
        "samples": [],
    }
    print('Sampling blocked processes for 20 seconds; no system settings are changed.', flush=True)
    for _ in range(20):
        data['samples'].append(sample())
        time.sleep(1)
    report.write_text(json.dumps(data, indent=2))
    report.chmod(0o600)
    # Keep device identifiers private while making the report readable to the caller.
    uid = int(os.environ.get('SUDO_UID', '0'))
    gid = int(os.environ.get('SUDO_GID', '0'))
    os.chown(report, uid, gid)
    os.chown(directory, uid, gid)
    print('Report saved to ' + str(report))


if __name__ == '__main__':
    main()
