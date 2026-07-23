#!/usr/bin/env python3

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest


SCRIPT = Path(__file__).with_name("preflight.py")


class PreflightTests(unittest.TestCase):
    def fixture(self, root: Path, duplicate: bool = False) -> Path:
        helper = root / "fetch-key"
        helper.write_text("#!/bin/sh\nprintf 'fixture-secret\\n'\n", encoding="utf-8")
        helper.chmod(0o700)
        catalogue = root / "models.json"
        catalogue.write_text(
            json.dumps(
                {
                    "models": [
                        {
                            "slug": "example-model",
                            "context_window": 900000,
                            "auto_compact_token_limit": 800000,
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        duplicate_line = 'model_provider = "direct"\n' if duplicate else ""
        config = root / "config.toml"
        config.write_text(
            textwrap.dedent(
                f"""
                model = "example-model"
                model_provider = "direct"
                {duplicate_line}model_context_window = 900000
                model_auto_compact_token_limit = 800000
                model_auto_compact_token_limit_scope = "total"
                model_catalog_json = "{catalogue}"

                [model_providers.direct]
                base_url = "https://example.invalid/v1"

                [model_providers.direct.auth]
                command = "{helper}"
                timeout_ms = 1000
                """
            ).lstrip(),
            encoding="utf-8",
        )
        return config

    def run_preflight(self, config: Path, *arguments: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--config", str(config), *arguments],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_valid_config_is_secret_safe(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_preflight(
                self.fixture(Path(directory)),
                "--total-context",
                "1050000",
                "--max-output",
                "128000",
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("fixture-secret", result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)["auth"], "executable-not-run")

    def test_duplicate_toml_key_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_preflight(self.fixture(Path(directory), duplicate=True))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not valid TOML", result.stderr)

    def test_unsafe_budget_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_preflight(
                self.fixture(Path(directory)),
                "--total-context",
                "950000",
                "--max-output",
                "100000",
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exceeds safe input", result.stderr)

    def test_non_positive_provider_numbers_fail(self) -> None:
        cases = (
            (("--total-context", "-1", "--max-output", "1"), "--total-context"),
            (("--total-context", "1050000", "--max-output", "-1"), "--max-output"),
            (("--min-headroom", "-1"), "--min-headroom"),
        )
        for arguments, label in cases:
            with self.subTest(label=label), tempfile.TemporaryDirectory() as directory:
                result = self.run_preflight(self.fixture(Path(directory)), *arguments)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(f"{label} must be a positive integer", result.stderr)

    def test_explicit_auth_check_never_prints_secret(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_preflight(
                self.fixture(Path(directory)),
                "--run-auth-helper",
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("fixture-secret", result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)["auth"], "delivered")


if __name__ == "__main__":
    unittest.main()
