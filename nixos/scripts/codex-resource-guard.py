"""Keep Codex and its descendants out of the compositor's systemd service."""

import os
from pathlib import Path
import re
import subprocess
import time


CODEX_EXE = re.compile(
    r"/nix/store/[^/]+-codex-desktop-[^/]+/opt/codex-desktop/(ChatGPT|electron)$"
)
LIMITS = {
    "CPUQuotaPerSecUSec": "3s",
    "CPUWeight": "10",
    "IOWeight": "10",
    "MemoryHigh": "6442450944",
    "IOReadBandwidthMax": "/dev/nvme0n1 64000000",
    "IOWriteBandwidthMax": "/dev/nvme0n1 32000000",
    "IOReadIOPSMax": "/dev/nvme0n1 2000",
    "IOWriteIOPSMax": "/dev/nvme0n1 2000",
}


def read_processes(proc_root=Path("/proc")):
    processes = {}
    for proc in proc_root.iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if proc.stat().st_uid != os.getuid():
                continue
            status = dict(line.split(":", 1) for line in (proc / "status").read_text().splitlines())
            processes[int(proc.name)] = {
                "parent": int(status["PPid"]),
                "exe": os.readlink(proc / "exe"),
                "cgroup": (proc / "cgroup").read_text().strip().removeprefix("0::"),
            }
        except (OSError, ValueError, KeyError):
            # Processes may exit while /proc is being read.
            continue
    return processes


def codex_trees(processes):
    trees = {}
    for pid in processes:
        ancestor = pid
        root = None
        seen = set()
        while ancestor in processes and ancestor not in seen:
            seen.add(ancestor)
            if CODEX_EXE.fullmatch(processes[ancestor]["exe"]):
                root = ancestor
            ancestor = processes[ancestor]["parent"]
        if root is not None:
            trees.setdefault(root, []).append(pid)
    return trees


def run(*args, check=True):
    return subprocess.run(args, check=check, text=True, capture_output=True, timeout=10)


def manager_call(method, *args):
    return run("busctl", "--user", "call", "org.freedesktop.systemd1",
               "/org/freedesktop/systemd1", "org.freedesktop.systemd1.Manager", method, *args)


def apply_limits(unit):
    result = run("systemctl", "--user", "show", unit, "--property=" + ",".join(LIMITS))
    current = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if current != LIMITS:
        run("systemctl", "--user", "set-property", "--runtime", unit,
            "CPUQuota=300%", *(f"{key}={value}" for key, value in LIMITS.items()
                              if key != "CPUQuotaPerSecUSec"))


def guard():
    processes = read_processes()
    for root, pids in codex_trees(processes).items():
        unit = f"app-codex-desktop-{root}.scope"
        if run("systemctl", "--user", "is-active", "--quiet", unit, check=False).returncode:
            # StartTransientUnit can adopt an existing process. Delegate allows
            # AttachProcessesToUnit to collect children Chromium left elsewhere.
            manager_call("StartTransientUnit", "ssa(sv)a(sa(sv))", unit, "fail", "3",
                         "PIDs", "au", "1", str(root), "Delegate", "b", "true",
                         "Slice", "s", "app.slice", "0")
            for _ in range(20):
                if not run("systemctl", "--user", "is-active", "--quiet", unit, check=False).returncode:
                    break
                time.sleep(0.05)
            else:
                raise RuntimeError(f"Scope did not become active: {unit}")
        apply_limits(unit)
        for pid in pids:
            try:
                # Recheck ancestry and current membership before adopting a PID;
                # a fork/exit or PID reuse can race the initial snapshot.
                ancestor = pid
                seen = set()
                while ancestor != root:
                    if ancestor in seen or ancestor <= 1:
                        break
                    seen.add(ancestor)
                    status = Path(f"/proc/{ancestor}/status").read_text()
                    ancestor = int(next(line.split()[1] for line in status.splitlines()
                                        if line.startswith("PPid:")))
                if ancestor != root or not CODEX_EXE.fullmatch(os.readlink(f"/proc/{root}/exe")):
                    continue
                cgroup = Path(f"/proc/{pid}/cgroup").read_text().strip()
                if cgroup.endswith("/" + unit):
                    continue
                manager_call("AttachProcessesToUnit", "ssau", unit, "", "1", str(pid))
            except FileNotFoundError:
                continue
            except subprocess.CalledProcessError:
                if Path(f"/proc/{pid}").exists():
                    raise


if __name__ == "__main__":
    try:
        guard()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.stderr.strip() or str(error)) from error
