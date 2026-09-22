"""Apply/rollback only the desktop writeback and scheduler settings; needs root.

Usage: sudo python3 scripts/desktop-io-tuning.py [apply|rollback|status]
Runtime only: reboot restores the active NixOS generation's configuration.
"""

import json
import os
from pathlib import Path
import sys

STATE = Path("/run/desktop-io-tuning.json")
SCHEDULER = Path("/sys/block/nvme0n1/queue/scheduler")
VM = Path("/proc/sys/vm")
KEYS = ("dirty_background_bytes", "dirty_background_ratio", "dirty_bytes", "dirty_ratio")


def snapshot():
    scheduler = next(s[1:-1] for s in SCHEDULER.read_text().split() if s.startswith("["))
    return {"scheduler": scheduler, **{k: int((VM / k).read_text()) for k in KEYS}}


def restore(saved):
    SCHEDULER.write_text(saved["scheduler"] + "\n")
    for prefix in ("dirty_background", "dirty"):
        # Writing either counterpart resets the other to zero.
        key = prefix + ("_bytes" if saved[prefix + "_bytes"] else "_ratio")
        (VM / key).write_text(str(saved[key]) + "\n")


def main():
    action = sys.argv[1] if len(sys.argv) == 2 else "status" if len(sys.argv) == 1 else ""
    if action not in ("apply", "rollback", "status"):
        raise SystemExit("Usage: desktop-io-tuning.py [apply|rollback|status]")
    if action == "status":
        print(json.dumps(snapshot(), indent=2))
        return
    if os.geteuid() != 0:
        raise SystemExit("Root access is required to change kernel I/O settings; run with sudo.")
    if action == "rollback":
        saved = json.loads(STATE.read_text())
        restore(saved)
        if snapshot() != saved:
            raise RuntimeError("Rollback readback differs; saved settings retained in " + str(STATE))
        STATE.unlink()
    else:
        if "mq-deadline" not in SCHEDULER.read_text().replace("[", "").replace("]", "").split():
            raise SystemExit("mq-deadline is unavailable; no settings changed.")
        before = snapshot()
        if not STATE.exists():
            with STATE.open("x") as f:
                os.chmod(STATE, 0o600)
                json.dump(before, f)
        try:
            SCHEDULER.write_text("mq-deadline\n")
            (VM / "dirty_background_bytes").write_text("67108864\n")
            (VM / "dirty_bytes").write_text("268435456\n")
            expected = {"scheduler": "mq-deadline", "dirty_background_bytes": 67108864,
                        "dirty_background_ratio": 0, "dirty_bytes": 268435456, "dirty_ratio": 0}
            if snapshot() != expected:
                raise RuntimeError("Kernel settings failed readback")
        except BaseException:
            restore(before)
            raise
    print(json.dumps(snapshot(), indent=2))


if __name__ == "__main__":
    main()
