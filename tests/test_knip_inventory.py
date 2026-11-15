"""Inventory regression checks; run with python3 -m unittest discover -s tests -p 'test_knip_*.py'."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import subprocess
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("inventory_knip", Path(__file__).resolve().parents[1] / "scripts/inventory-knip.py")
inventory_knip = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inventory_knip)


class InventoryTests(unittest.TestCase):
    def test_knip_six_counts_files_and_exports_without_counting_owners(self):
        report = {"issues": [{"file": "src/a.ts", "files": [{"name": "a.ts"}],
                              "exports": [{"name": "unused"}], "owners": [{"name": "team"}]}]}
        self.assertEqual(inventory_knip.summarize(json.dumps(report)), {"files": 1, "exports": 1})
        self.assertEqual(inventory_knip.summarize('{"issues":[]}'), {})
        self.assertIsNone(inventory_knip.summarize(""))
        self.assertIsNone(inventory_knip.summarize('{"issues":[null]}'))

    def run_inventory(self, code, stdout, stderr):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            repo = root / "Example"
            (repo / "node_modules/knip/bin").mkdir(parents=True)
            (repo / "node_modules/knip/bin/knip.js").write_text("")
            (repo / "node_modules/knip/package.json").write_text('{"version":"6.45.1"}')
            (repo / "knip.json").write_text('{}')
            output = root / "reports"
            output.mkdir()

            def capture(command, cwd):
                if command[0] == "git":
                    return 0, "", ""
                return code, stdout, stderr

            with patch.object(inventory_knip, "capture", side_effect=capture):
                result = inventory_knip.inventory("Example", root, output, "node")
            for mode in ["default", "production"]:
                self.assertEqual((output / "Example" / f"{mode}.json").read_text(), stdout)
                self.assertEqual((output / "Example" / f"{mode}.stderr").read_text(), stderr)
                self.assertEqual(result["modes"][mode]["exitCode"], code)
            return result

    def test_config_hint_exit_is_not_mistaken_for_clean_json(self):
        result = self.run_inventory(1, '{"issues":[]}', "Configuration hints: stale ignore")
        self.assertEqual(result["status"], "findings")

    def test_empty_success_output_is_an_execution_error(self):
        self.assertEqual(self.run_inventory(0, "", "")["status"], "error")

    def test_timeout_is_an_error(self):
        self.assertEqual(self.run_inventory(None, "", "timed out")["status"], "error")

    def test_timeout_preserves_partial_output(self):
        error = subprocess.TimeoutExpired(["node"], 120, output=b"partial", stderr=b"diagnostic")
        with patch.object(inventory_knip.subprocess, "run", side_effect=error):
            code, stdout, stderr = inventory_knip.capture(["node"], Path("."))
        self.assertIsNone(code)
        self.assertEqual(stdout, "partial")
        self.assertIn("diagnostic", stderr)

    def test_warn_only_findings_are_not_a_clean_baseline(self):
        report = '{"issues":[{"file":"src/a.ts","cycles":[[{"name":"a"}]]}]}'
        self.assertEqual(self.run_inventory(0, report, "")["status"], "findings")

    def test_clean_requires_zero_exit_and_empty_report(self):
        self.assertEqual(self.run_inventory(0, '{"issues":[]}', "")["status"], "clean")


if __name__ == "__main__":
    unittest.main()
