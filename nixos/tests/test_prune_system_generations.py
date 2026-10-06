import importlib.util
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location(
    "prune", Path(__file__).parents[1] / "scripts/prune-system-generations.py")
prune = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prune)


class GenerationPlanTests(unittest.TestCase):
    def fixture(self, root):
        profiles = root / "profiles"
        profiles.mkdir()
        targets = {}
        for number in range(1, 8):
            target = root / f"closure-{number}"
            target.mkdir()
            (profiles / f"system-{number}-link").symlink_to(target)
            targets[number] = target
        return profiles, targets

    def test_keeps_recent_three(self):
        with tempfile.TemporaryDirectory() as tmp:
            profiles, targets = self.fixture(Path(tmp))
            self.assertEqual(prune.plan(profiles, [targets[7]]),
                             {"keep": [5, 6, 7], "delete": [1, 2, 3, 4]})

    def test_running_and_booted_older_generations_are_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            profiles, targets = self.fixture(Path(tmp))
            self.assertEqual(prune.plan(profiles, [targets[1], targets[3], targets[7]]),
                             {"keep": [1, 3, 5, 6, 7], "delete": [2, 4]})

    def test_unknown_protected_system_refuses_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            profiles, _ = self.fixture(Path(tmp))
            with self.assertRaises(RuntimeError):
                prune.plan(profiles, [Path(tmp) / "unknown"])

    def test_empty_profiles_refuse_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(RuntimeError):
                prune.plan(Path(tmp), [])


if __name__ == "__main__":
    unittest.main()
