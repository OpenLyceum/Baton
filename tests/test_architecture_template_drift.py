"""Required architecture files and scripts use the canonical template."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


BATON = Path(__file__).resolve().parents[1]
CONFIG = ".dependency-cruiser.cjs"
FIXTURES = "tests/architecture.node-test.ts"
SCRIPTS = {
    "check:architecture": "depcruise --config .dependency-cruiser.cjs src",
    "test:architecture": "node --test tests/*.node-test.ts",
}


class ArchitectureTemplateDriftTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)
        self.template = root / "SceneryStackTemplate"
        self.sim = root / "Example"
        for checkout, name in [
            (self.template, "scenerystack-template"),
            (self.sim, "example"),
        ]:
            (checkout / "tests").mkdir(parents=True)
            (checkout / CONFIG).write_text('module.exports = { forbidden: [] };\n')
            (checkout / FIXTURES).write_text('import "node:test";\n')
            (checkout / "package.json").write_text(json.dumps({"name": name, "scripts": SCRIPTS}))

    def check(self, *flags):
        return subprocess.run(
            [
                "node", str(BATON / "scripts/check-template-drift.mjs"),
                "--architecture", "--template", str(self.template), "--dir", str(self.sim),
                "--json", *flags,
            ], capture_output=True, text=True, check=False,
        )

    def test_scoped_check_and_fix_preserve_sim_owned_changes(self):
        overlay = self.sim / ".dependency-cruiser.local.cjs"
        overlay.write_text("module.exports = {};\n")
        (self.sim / "package-lock.json").write_text("unrelated lockfile\n")
        self.assertEqual(self.check().returncode, 0)

        (self.sim / CONFIG).write_text("module.exports = {};\n")
        (self.sim / FIXTURES).unlink()
        (self.sim / "AGENTS.md").write_text(
            f"## Compliance carve-outs\n- `{CONFIG}`: forked policy\n"
            "- `check:architecture`: local command\n"
        )
        package_file = self.sim / "package.json"
        package = json.loads(package_file.read_text())
        package["scripts"].update({"check:architecture": "true", "local": "node local.js"})
        package_file.write_text(json.dumps(package))

        result = self.check()
        self.assertEqual(result.returncode, 1, result.stderr)
        issues = json.loads(result.stdout)[0]["issues"]
        self.assertEqual([issue["path"] for issue in issues], [CONFIG, FIXTURES, "check:architecture"])
        result = self.check("--fix")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.check().returncode, 0)
        self.assertEqual(json.loads(package_file.read_text())["scripts"], {**SCRIPTS, "local": "node local.js"})
        self.assertEqual(overlay.read_text(), "module.exports = {};\n")
        self.assertEqual((self.sim / "package-lock.json").read_text(), "unrelated lockfile\n")

    def test_missing_canonical_config_fails_closed(self):
        (self.template / CONFIG).unlink()
        result = self.check()
        self.assertEqual(result.returncode, 2)
        self.assertIn(CONFIG, result.stderr)
