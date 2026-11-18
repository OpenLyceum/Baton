"""Template drift for Knip starter entries, exact files, and locked dependencies."""
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

    def check(self, directory=None, name="Example", flags=()):
        result = subprocess.run([
            "node", str(BATON / "scripts/check-template-drift.mjs"),
            "--dir", str(directory or self.sim), "--name", name,
            "--template", str(self.template), "--json", *flags,
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

    def prepare_exact_file(self, template_text, sim_text):
        manifest = json.loads(self.manifest.read_text())
        manifest["exact"] = ["vite.config.ts"]
        self.manifest.write_text(json.dumps(manifest))
        self.write_config(self.sim, {"project": ["src/**/*.ts!"], "entry": []})
        (self.template / "vite.config.ts").write_text(template_text)
        (self.sim / "vite.config.ts").write_text(sim_text)

    def test_exact_file_can_mention_the_sim_in_a_shared_comment(self):
        text = "// Lazy imports are used by Example and OtherSim.\nexport default {};\n"
        self.prepare_exact_file(text, text)
        self.assertEqual(self.check(), (0, []))

    def test_exact_file_can_retain_the_template_name_in_a_shared_comment(self):
        text = "// Bump SceneryStackTemplate and repos together.\nexport default {};\n"
        self.prepare_exact_file(text, text)
        self.assertEqual(self.check(), (0, []))

    def test_exact_file_renders_template_name_tokens(self):
        self.prepare_exact_file(
            '// Used by Example.\nexport const repo = "SceneryStackTemplate";\n',
            '// Used by Example.\nexport const repo = "Example";\n',
        )
        self.assertEqual(self.check(), (0, []))

    def test_exact_file_still_rejects_changed_content(self):
        self.prepare_exact_file("export default { value: 1 };\n", "export default { value: 2 };\n")
        code, issues = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(issues[0]["path"], "vite.config.ts")

    def prepare_owned_file(self, template_text, sim_text=None):
        manifest = json.loads(self.manifest.read_text())
        manifest["ownedIfPresent"] = ["src/common/TimeModel.ts"]
        self.manifest.write_text(json.dumps(manifest))
        self.write_config(self.sim, {"project": ["src/**/*.ts!"], "entry": []})
        for directory, text in [(self.template, template_text), (self.sim, sim_text)]:
            if text is not None:
                (directory / "src/common").mkdir(parents=True, exist_ok=True)
                (directory / "src/common/TimeModel.ts").write_text(text)

    def test_owned_if_present_file_may_be_deleted(self):
        self.prepare_owned_file("export class TimeModel {}\n")
        self.assertEqual(self.check(), (0, []))

    def test_owned_if_present_file_must_match_when_kept(self):
        self.prepare_owned_file("export class TimeModel {}\n", "export class TimeModel { fork = 1; }\n")
        code, issues = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(issues[0]["path"], "src/common/TimeModel.ts")

    def test_owned_if_present_fork_can_be_carved_out(self):
        self.prepare_owned_file("export class TimeModel {}\n", "export class TimeModel { fork = 1; }\n")
        (self.sim / "AGENTS.md").write_text(
            "## Compliance carve-outs\n\n- `src/common/TimeModel.ts`: adds a custom clock\n"
        )
        self.assertEqual(self.check(), (0, []))

    def test_owned_if_present_fix_syncs_a_fork_but_not_a_deletion(self):
        self.prepare_owned_file("export class TimeModel {}\n", "export class TimeModel { fork = 1; }\n")
        self.check(flags=("--fix",))
        self.assertEqual((self.sim / "src/common/TimeModel.ts").read_text(), "export class TimeModel {}\n")
        (self.sim / "src/common/TimeModel.ts").unlink()
        self.check(flags=("--fix",))
        self.assertFalse((self.sim / "src/common/TimeModel.ts").exists())

    def prepare_lockfiles(self, sim_version):
        manifest = json.loads(self.manifest.read_text())
        manifest["packageJson"]["matchDirectDependencyLockVersions"] = True
        self.manifest.write_text(json.dumps(manifest))
        self.write_config(self.sim, {"project": ["src/**/*.ts!"], "entry": []})
        for directory, name, version in [
            (self.template, "scenerystack-template", "8.3.8"),
            (self.sim, "example", sim_version),
        ]:
            pkg = {"name": name, "scripts": {}, "devDependencies": {"vite": "^8.3.8"}}
            (directory / "package.json").write_text(json.dumps(pkg))
            packages = {"": pkg, "node_modules/vite": {"version": version}}
            if directory == self.sim:
                packages["node_modules/extra"] = {"version": "1.0.0"}
            (directory / "package-lock.json").write_text(json.dumps({"packages": packages}))

    def test_matching_shared_versions_allow_extra_lock_entries(self):
        self.prepare_lockfiles("8.3.8")
        self.assertEqual(self.check(), (0, []))

    def test_matching_ranges_do_not_hide_version_drift_even_with_fix(self):
        self.prepare_lockfiles("8.3.9")
        lockfile = self.sim / "package-lock.json"
        original = lockfile.read_text()
        code, issues = self.check(flags=("--fix",))
        self.assertEqual(code, 1)
        self.assertEqual([(issue["kind"], issue["path"]) for issue in issues], [("lockfile", "vite")])
        self.assertIn("8.3.9 (template: 8.3.8)", issues[0]["detail"])
        self.assertEqual(lockfile.read_text(), original)

    def test_explicit_dependency_carve_out_allows_locked_version(self):
        self.prepare_lockfiles("8.3.9")
        (self.sim / "AGENTS.md").write_text("## Compliance carve-outs\n\n- `vite`: requires 8.3.9.\n")
        self.assertEqual(self.check(), (0, []))

    def test_missing_sim_lockfile_is_reported(self):
        self.prepare_lockfiles("8.3.8")
        (self.sim / "package-lock.json").unlink()
        code, issues = self.check()
        self.assertEqual(code, 1)
        self.assertEqual(issues[0]["path"], "package-lock.json")
