#!/usr/bin/env python3
"""Secret-safe audit for a Codex large-context configuration."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tomllib


class PreflightError(RuntimeError):
    pass


def positive_int(value: object, label: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise PreflightError(f"{label} must be a positive integer")
    return value


def load_toml(path: Path) -> dict:
    try:
        with path.open("rb") as handle:
            return tomllib.load(handle)
    except FileNotFoundError as error:
        raise PreflightError(f"config not found: {path}") from error
    except tomllib.TOMLDecodeError as error:
        raise PreflightError(f"config is not valid TOML: {error}") from error


def validate_catalog(path: Path, model: str, context: int, compact: int) -> None:
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise PreflightError(f"model catalogue not found: {path}") from error
    except json.JSONDecodeError as error:
        raise PreflightError(f"model catalogue is not valid JSON: {error}") from error

    models = document.get("models")
    if not isinstance(models, list):
        raise PreflightError("model catalogue has no models array")
    entry = next(
        (item for item in models if isinstance(item, dict) and item.get("slug") == model),
        None,
    )
    if entry is None:
        raise PreflightError(f"model catalogue is missing {model}")
    if entry.get("context_window") != context:
        raise PreflightError(f"{model}.context_window does not match config")
    if entry.get("auto_compact_token_limit") != compact:
        raise PreflightError(f"{model}.auto_compact_token_limit does not match config")


def validate_auth_helper(provider: dict, run_helper: bool) -> str:
    auth = provider.get("auth")
    if auth is None:
        return "not-configured"
    if not isinstance(auth, dict):
        raise PreflightError("provider auth must be a TOML table")
    command = auth.get("command")
    if not isinstance(command, str) or not command.strip():
        raise PreflightError("provider auth.command is missing")
    arguments = shlex.split(command)
    if len(arguments) != 1:
        raise PreflightError("provider auth.command must be one executable path")
    helper = Path(arguments[0]).expanduser()
    if not helper.is_file() or not os.access(helper, os.X_OK):
        raise PreflightError(f"provider auth helper is not executable: {helper}")
    if not run_helper:
        return "executable-not-run"

    timeout_ms = positive_int(auth.get("timeout_ms", 5000), "provider auth.timeout_ms")
    try:
        completed = subprocess.run(
            [str(helper)],
            check=False,
            capture_output=True,
            timeout=timeout_ms / 1000,
        )
    except subprocess.TimeoutExpired as error:
        raise PreflightError("provider auth helper timed out") from error
    if completed.returncode != 0:
        raise PreflightError("provider auth helper failed")
    if not completed.stdout.strip():
        raise PreflightError("provider auth helper returned no credential")
    return "delivered"


def audit(args: argparse.Namespace) -> dict:
    config_path = Path(args.config).expanduser()
    config = load_toml(config_path)

    model = config.get("model")
    provider_name = config.get("model_provider")
    if not isinstance(model, str) or not model:
        raise PreflightError("model is missing")
    if not isinstance(provider_name, str) or not provider_name:
        raise PreflightError("model_provider is missing")

    context = positive_int(config.get("model_context_window"), "model_context_window")
    compact = positive_int(
        config.get("model_auto_compact_token_limit"),
        "model_auto_compact_token_limit",
    )
    if config.get("model_auto_compact_token_limit_scope") != "total":
        raise PreflightError('model_auto_compact_token_limit_scope must be "total"')
    if compact >= context:
        raise PreflightError("compaction threshold must be below the configured context")

    min_headroom = positive_int(args.min_headroom, "--min-headroom")
    safe_input = None
    if (args.total_context is None) != (args.max_output is None):
        raise PreflightError("--total-context and --max-output must be provided together")
    if args.total_context is not None:
        total_context = positive_int(args.total_context, "--total-context")
        max_output = positive_int(args.max_output, "--max-output")
        safe_input = total_context - max_output
        if safe_input <= 0:
            raise PreflightError("provider maximum output must be below total context")
        if context > safe_input:
            raise PreflightError(
                f"configured context {context} exceeds safe input {safe_input}"
            )
        if compact > safe_input - min_headroom:
            raise PreflightError(
                f"compaction threshold leaves less than {min_headroom} tokens of headroom"
            )

    providers = config.get("model_providers")
    if not isinstance(providers, dict):
        raise PreflightError("model_providers table is missing")
    provider = providers.get(provider_name)
    if not isinstance(provider, dict):
        raise PreflightError(f"selected provider table is missing: {provider_name}")

    catalogue = config.get("model_catalog_json")
    if isinstance(catalogue, str) and catalogue:
        validate_catalog(Path(catalogue).expanduser(), model, context, compact)
        catalogue_state = "matched"
    else:
        catalogue_state = "not-configured"

    auth_state = validate_auth_helper(provider, args.run_auth_helper)
    return {
        "status": "ok",
        "model": model,
        "provider": provider_name,
        "context_window": context,
        "auto_compact_token_limit": compact,
        "safe_input": safe_input,
        "catalogue": catalogue_state,
        "auth": auth_state,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="~/.codex/config.toml")
    parser.add_argument("--total-context", type=int)
    parser.add_argument("--max-output", type=int)
    parser.add_argument("--min-headroom", type=int, default=50_000)
    parser.add_argument("--run-auth-helper", action="store_true")
    args = parser.parse_args()

    try:
        result = audit(args)
    except PreflightError as error:
        print(f"Codex context preflight failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
