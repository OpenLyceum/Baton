"""Template-only Knip entries must not become required entry exemptions in forks."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

BATON = Path(__file__).resolve().parents[1]
STARTER = "src/common/SimPanel.ts!"


class KnipTemplateDriftTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.template = self.root / "SceneryStackTemplate"
        self.sim = self.root / "Example"
        for directory in [self.template, self.sim]:
            directory.mkdir()
            (directory / "package.json").write_text('{"name":"example","scripts":{}}')
        self.config = {"project": ["src/**/*.ts!"], "entry": [STARTER]}
        self.write_config(self.template, self.config)
        self.manifest = self.root / "manifest.json"
        self.manifest.write_text(json.dumps({
            "template": "SceneryStackTemplate",
            "tokens": {"packageName": "example", "repoName": "SceneryStackTemplate"},
            "exact": [], "linesSuperset": [], "forbidden": [],
            "jsonExtend": {"knip.json": ["entry", "project"]},
            "templateOnly": {
                "files": [], "scripts": [],
                "jsonArrayValues": {"knip.json": {"entry": [STARTER]}},
            },
            "packageJson": {"matchKeys": []},
            "noTemplateCopies": {"files": [], "threshold": 0.6},
        }))

    def write_config(self, directory, config):
        (directory / "knip.json").write_text(json.dumps(config))

    def check(self, directory=None, name="Example"):
        result = subprocess.run([
            "node", str(BATON / "scripts/check-template-drift.mjs"),
            "--dir", str(directory or self.sim), "--name", name,
            "--template", str(self.template), "--json",
        ], env=dict(os.environ, TEMPLATE_MANIFEST=str(self.manifest)), capture_output=True, text=True, check=False)
        return result.returncode, json.loads(result.stdout)[0]["issues"]

    def test_fork_can_omit_starter_and_add_a_real_custom_entry(self):
        self.write_config(self.sim, {"project": ["src/**/*.ts!"], "entry": ["scripts/generate.ts"]})
        self.assertEqual(self.check(), (0, []))

    def test_template_keeps_its_documented_starter_entry(self):
        self.assertEqual(self.check(self.template, "SceneryStackTemplate"), (0, []))

    def test_production_project_coverage_is_still_required(self):
        self.write_config(self.sim, {"project": ["src/**/*.ts"], "entry": []})
        code, issues = self.check()
        self.assertEqual(code, 1)
        self.assertIn('project drops "src/**/*.ts!"', issues[0]["detail"])

    def test_fork_must_not_inherit_template_starter_exemptions(self):
        self.write_config(self.sim, self.config)
        code, issues = self.check()
        self.assertEqual(code, 1)
        self.assertIn("entry retains template-only values", issues[0]["detail"])
