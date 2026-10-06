"""Keep three recent NixOS generations plus the running and booted systems.

Without --apply, print the exact plan without modifying anything.
With --apply, root removes only the listed profile generations, refreshes the
current system's boot menu, then collects unreachable Nix store paths.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess


PROFILE_DIR = Path("/nix/var/nix/profiles")


def plan(profile_dir, protected_systems, keep_count=3):
    generations = {}
    for link in profile_dir.iterdir():
        match = re.fullmatch(r"system-(\d+)-link", link.name)
        if match and link.is_symlink():
            generations[int(match[1])] = link.resolve(strict=True)
    if not generations:
        raise RuntimeError("No system generations found; refusing cleanup")

    keep = set(sorted(generations)[-keep_count:])
    for system in protected_systems:
        matches = [number for number, target in generations.items() if target == system]
        if not matches:
            raise RuntimeError(f"Protected system has no profile generation: {system}")
        keep.add(max(matches))
    return {"keep": sorted(keep), "delete": sorted(set(generations) - keep)}


def current_plan():
    protected = [Path(path).resolve(strict=True) for path in
                 ("/run/current-system", "/run/booted-system", str(PROFILE_DIR / "system"))]
    return plan(PROFILE_DIR, protected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    proposed = current_plan()
    print(json.dumps(proposed, indent=2), flush=True)
    if not args.apply:
        return
    if os.geteuid() != 0:
        raise SystemExit("System-generation cleanup requires sudo; nothing was deleted")
    if current_plan() != proposed:
        raise SystemExit("System generations changed; rerun to obtain a fresh plan")
    if proposed["delete"]:
        subprocess.run(["/run/current-system/sw/bin/nix-env", "--profile",
                        str(PROFILE_DIR / "system"), "--delete-generations",
                        *map(str, proposed["delete"])], check=True)
    subprocess.run(["/run/current-system/bin/switch-to-configuration", "boot"], check=True)
    subprocess.run(["/run/current-system/sw/bin/ionice", "-c", "3",
                    "/run/current-system/sw/bin/nice", "-n", "19",
                    "/run/current-system/sw/bin/nix-store", "--gc"], check=True)
    subprocess.run(["/run/current-system/sw/bin/df", "-h", "/", "/boot"], check=True)


if __name__ == "__main__":
    main()
