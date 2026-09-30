#!/usr/bin/env python3
"""Switch Codex (CLI and Desktop) between OpenAI and Claude via the local proxy.

Codex Desktop cannot select config profiles, so the switch edits the top-level
keys of the app-managed ~/.codex/config.toml in place and keeps everything
else, including the app's own sections, untouched.
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import tomlkit


PROVIDER_ID = "anthropic"
SERVICE = "codex-claude-proxy.service"
DEFAULT_CLAUDE_MODEL = "claude-opus-5-5"
STASHED_KEYS = ("model", "model_reasoning_effort")


def read_token(path):
    for line in Path(path).read_text().splitlines():
        key, _, value = line.partition("=")
        if key.strip() == "LITELLM_MASTER_KEY":
            return value.strip().strip("'\"")
    raise ValueError(f"LITELLM_MASTER_KEY missing from {path}")


def load_json(path):
    try:
        return json.loads(Path(path).read_text())
    except FileNotFoundError:
        return {}


def write_private(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w") as handle:
            handle.write(text)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


def on_claude(doc):
    return doc.get("model_provider") == PROVIDER_ID


def use_claude(doc, state, *, model, catalog, base_url, token):
    if not on_claude(doc):
        state["openai"] = {key: doc[key] for key in STASHED_KEYS if key in doc}
    model = model or state.get("claude", {}).get("model") or DEFAULT_CLAUDE_MODEL

    doc["model_provider"] = PROVIDER_ID
    doc["model_catalog_json"] = str(catalog)
    doc["model"] = model

    provider = tomlkit.table()
    provider["name"] = "Claude (local LiteLLM proxy)"
    provider["base_url"] = base_url
    provider["wire_api"] = "responses"
    provider["experimental_bearer_token"] = token
    if "model_providers" not in doc:
        doc["model_providers"] = tomlkit.table(is_super_table=True)
    doc["model_providers"][PROVIDER_ID] = provider
    state["claude"] = {"model": model}


def use_openai(doc, state):
    if not on_claude(doc):
        return
    if "model" in doc:
        state["claude"] = {"model": doc["model"]}
    for key in ("model_provider", "model_catalog_json", *STASHED_KEYS):
        doc.pop(key, None)
    for key, value in state.get("openai", {}).items():
        doc[key] = value


def systemctl(*args):
    return subprocess.run(["systemctl", "--user", *args], check=False).returncode


def main(argv=None):
    parser = argparse.ArgumentParser(prog="codex-provider", description=__doc__.splitlines()[0])
    parser.add_argument("target", choices=("claude", "openai", "status"))
    parser.add_argument("model", nargs="?", help="Claude model slug, e.g. claude-sonnet-5")
    parser.add_argument("--codex-home", default=os.environ.get("CODEX_HOME", Path.home() / ".codex"))
    parser.add_argument("--state", default=Path.home() / ".local/state/codex-provider/state.json")
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--token-file", required=True)
    parser.add_argument("--marker", required=True, help="file that lets the proxy service start")
    parser.add_argument("--no-service", action="store_true", help="do not start or stop the proxy")
    args = parser.parse_args(argv)

    config = Path(args.codex_home) / "config.toml"
    doc = tomlkit.parse(config.read_text()) if config.exists() else tomlkit.document()
    state = load_json(args.state)

    if args.target == "status":
        provider = "claude" if on_claude(doc) else "openai"
        print(f"provider: {provider}\nmodel: {doc.get('model', '(default)')}")
        return 0

    if args.target == "claude":
        catalog = json.loads(Path(args.catalog).read_text())
        slugs = [entry["slug"] for entry in catalog["models"]]
        if args.model and args.model not in slugs:
            parser.error(f"unknown Claude model {args.model!r}; choose from {', '.join(slugs)}")
        marker = Path(args.marker)
        marker.parent.mkdir(parents=True, exist_ok=True)
        marker.touch()
        # A skipped start condition (e.g. missing API key file) still exits 0.
        if not args.no_service and (systemctl("start", SERVICE) != 0 or systemctl("is-active", "--quiet", SERVICE) != 0):
            print(f"could not start {SERVICE}; check `systemctl --user status {SERVICE}`", file=sys.stderr)
            return 1
        use_claude(
            doc,
            state,
            model=args.model,
            catalog=args.catalog,
            base_url=args.base_url,
            token=read_token(args.token_file),
        )
    else:
        use_openai(doc, state)
        Path(args.marker).unlink(missing_ok=True)
        if not args.no_service:
            systemctl("stop", SERVICE)

    write_private(config, tomlkit.dumps(doc))
    write_private(args.state, json.dumps(state, indent=2) + "\n")
    print(f"Codex now uses {args.target} ({doc.get('model', 'default model')}).")
    print("Restart Codex Desktop for the change to take effect.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
