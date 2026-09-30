import importlib.util
import json
from pathlib import Path
import tempfile
import tomllib
import unittest


spec = importlib.util.spec_from_file_location(
    "provider", Path(__file__).parents[1] / "scripts/codex-provider.py"
)
provider = importlib.util.module_from_spec(spec)
spec.loader.exec_module(provider)

CONFIG = """model = "gpt-5.6-luna"
model_reasoning_effort = "high"
approval_policy = "never"
[projects."/home/adrian"]
trust_level = "trusted"

[mcp_servers.node_repl]
command = "/nix/store/x/node_repl"

[mcp_servers.node_repl.env]
CODEX_HOME = "/home/adrian/.codex"
"""


class CodexProviderTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.home = root / "codex"
        self.home.mkdir()
        self.config = self.home / "config.toml"
        self.config.write_text(CONFIG)
        self.catalog = root / "catalog.json"
        self.catalog.write_text(json.dumps({"models": [{"slug": "claude-opus-5-5"}, {"slug": "claude-sonnet-5"}]}))
        self.token = root / "proxy.env"
        self.token.write_text("LITELLM_MASTER_KEY='sk-local-abc'\n")
        self.marker = root / "state/claude-enabled"
        self.state = root / "state/state.json"

    def tearDown(self):
        self.tmp.cleanup()

    def run_cli(self, *args):
        return provider.main([
            *args,
            "--codex-home", str(self.home),
            "--state", str(self.state),
            "--catalog", str(self.catalog),
            "--base-url", "http://127.0.0.1:4100/v1",
            "--token-file", str(self.token),
            "--marker", str(self.marker),
            "--no-service",
        ])

    def parsed(self):
        return tomllib.loads(self.config.read_text())

    def test_claude_sets_top_level_provider_and_keeps_app_sections(self):
        self.assertEqual(self.run_cli("claude"), 0)
        config = self.parsed()

        self.assertEqual(config["model_provider"], "anthropic")
        self.assertEqual(config["model"], "claude-opus-5-5")
        self.assertEqual(config["model_catalog_json"], str(self.catalog))
        self.assertEqual(config["model_reasoning_effort"], "high")
        self.assertEqual(config["model_providers"]["anthropic"], {
            "name": "Claude (local LiteLLM proxy)",
            "base_url": "http://127.0.0.1:4100/v1",
            "wire_api": "responses",
            "experimental_bearer_token": "sk-local-abc",
        })
        self.assertEqual(config["mcp_servers"]["node_repl"]["env"]["CODEX_HOME"], "/home/adrian/.codex")
        self.assertEqual(config["projects"]["/home/adrian"]["trust_level"], "trusted")
        self.assertTrue(self.marker.exists())
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    def test_round_trip_restores_openai_and_remembers_claude_model(self):
        self.run_cli("claude", "claude-sonnet-5")
        self.run_cli("claude")  # re-running must not stash the Claude model as the OpenAI one
        self.assertEqual(self.run_cli("openai"), 0)
        config = self.parsed()

        self.assertEqual(config["model"], "gpt-5.6-luna")
        self.assertEqual(config["model_reasoning_effort"], "high")
        self.assertNotIn("model_provider", config)
        self.assertNotIn("model_catalog_json", config)
        self.assertFalse(self.marker.exists())

        self.run_cli("claude")
        self.assertEqual(self.parsed()["model"], "claude-sonnet-5")

    def test_openai_is_a_no_op_when_already_on_openai(self):
        self.assertEqual(self.run_cli("openai"), 0)
        self.assertEqual(self.parsed(), tomllib.loads(CONFIG))

    def test_rejects_models_missing_from_catalog(self):
        with self.assertRaises(SystemExit):
            self.run_cli("claude", "gpt-5.5")
        self.assertEqual(self.config.read_text(), CONFIG)
        self.assertFalse(self.marker.exists())


if __name__ == "__main__":
    unittest.main()
