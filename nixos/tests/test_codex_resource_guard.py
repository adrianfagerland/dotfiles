import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "guard", Path(__file__).parents[1] / "scripts/codex-resource-guard.py"
)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)
CODEX = "/nix/store/hash-codex-desktop-26/opt/codex-desktop/ChatGPT"


def process(parent, exe, cgroup="/session.slice/wayland-wm.service"):
    return {"parent": parent, "exe": exe, "cgroup": cgroup}


class ResourceGuardTests(unittest.TestCase):
    def test_collects_renderers_and_jobs_without_adopting_compositor_or_browser(self):
        processes = {
            1: process(0, "/bin/systemd"),
            2: process(1, "/bin/Hyprland"),
            10: process(2, CODEX, "/app.slice/app-org.chromium.Chromium-10.scope"),
            11: process(10, CODEX),
            12: process(11, CODEX),
            13: process(10, "/bin/codex"),
            14: process(13, "/bin/bun"),
            20: process(2, "/opt/other-app/ChatGPT"),
            21: process(20, "/bin/renderer"),
            22: process(2, "/bin/helium"),
        }
        self.assertEqual(guard.codex_trees(processes), {10: [10, 11, 12, 13, 14]})

    def test_legacy_and_multiple_instances_keep_separate_trees(self):
        legacy = CODEX.replace("/ChatGPT", "/electron")
        processes = {10: process(1, CODEX), 20: process(1, legacy),
                     21: process(20, "/bin/node")}
        self.assertEqual(guard.codex_trees(processes), {10: [10], 20: [20, 21]})

    def test_scope_renames_do_not_change_ownership(self):
        processes = {10: process(1, CODEX),
                     11: process(10, "/bin/bun", "/app.slice/run-another.scope")}
        self.assertEqual(guard.codex_trees(processes), {10: [10, 11]})

    def test_truncated_or_cyclic_process_snapshots_terminate(self):
        processes = {10: process(99, CODEX), 20: process(21, "/bin/node"),
                     21: process(20, "/bin/node")}
        self.assertEqual(guard.codex_trees(processes), {10: [10]})

    def test_no_property_writes_when_limits_already_match(self):
        output = "\n".join(f"{k}={v}" for k, v in guard.LIMITS.items())
        with patch.object(guard, "run", return_value=SimpleNamespace(stdout=output)) as run:
            guard.apply_limits("app-codex-desktop-10.scope")
        self.assertEqual(run.call_count, 1)

    def test_missing_io_limits_are_applied_even_when_cpu_limits_match(self):
        output = "\n".join(f"{k}={v}" for k, v in guard.LIMITS.items() if "IOPS" not in k)
        with patch.object(guard, "run", return_value=SimpleNamespace(stdout=output)) as run:
            guard.apply_limits("app-codex-desktop-10.scope")
        self.assertEqual(run.call_count, 2)
        self.assertIn("IOReadIOPSMax=/dev/nvme0n1 2000", run.call_args.args)
        self.assertIn("IOWriteIOPSMax=/dev/nvme0n1 2000", run.call_args.args)


if __name__ == "__main__":
    unittest.main()
