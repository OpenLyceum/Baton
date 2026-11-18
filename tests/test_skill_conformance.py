"""Skill-conformance probes: detection, comment stripping, carve-outs, warn/fail levels."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

BATON = Path(__file__).resolve().parents[1]

PASSING = {
    "src/main.ts": 'import "./brand.js";\n',
    "src/demo/DemoScreen.ts": "export class DemoScreen {}\n",
    "src/demo/view/DemoScreenView.ts": (
        'import { VBox } from "scenerystack/scenery";\n'
        'import { Checkbox } from "scenerystack/sun";\n'
        'import { optionize } from "scenerystack/phet-core";\n'
        "export const box = new VBox();\n"
    ),
    "src/demo/view/DemoKeyboardHelpContent.ts": "export const s = new SliderControlsKeyboardHelpSection();\n",
    "src/preferences/demoQueryParameters.ts": "export const q = QueryStringMachine.getAll({});\n",
}


class SkillConformanceTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.sim = Path(self.directory.name) / "Demo"
        self.write(PASSING)

    def write(self, files):
        for rel, text in files.items():
            path = self.sim / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)

    def run_check(self, *flags):
        result = subprocess.run(
            ["node", str(BATON / "scripts/check-skill-conformance.mjs"), "--dir", str(self.sim), "--json", *flags],
            capture_output=True, text=True, check=False,
        )
        probes = {p["id"]: p for p in json.loads(result.stdout)[0]["probes"]}
        return result.returncode, probes

    def test_template_shaped_sim_follows_every_probe(self):
        code, probes = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual({p["status"] for p in probes.values()}, {"follow", "n/a"})

    def test_enum_is_a_failing_gap(self):
        self.write({"src/demo/model/Mode.ts": "export enum Mode { A, B }\n"})
        code, probes = self.run_check()
        self.assertEqual(code, 1)
        self.assertEqual(probes["coding-conventions"]["status"], "gap")
        self.assertEqual(probes["coding-conventions"]["path"], "src/demo/model/Mode.ts")

    def test_pattern_inside_a_comment_is_not_a_hit(self):
        self.write({"src/demo/model/Notes.ts": "/** Never write `new Audio()` or `enum X {}` here. */\n// location.search\n"})
        code, probes = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual(probes["sound"]["status"], "n/a")

    def test_keyboard_help_stub_is_a_gap(self):
        self.write({"src/demo/view/DemoKeyboardHelpContent.ts": "export const s = new BasicActionsKeyboardHelpSection();\n"})
        code, probes = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual(probes["keyboard-help-dialog"]["status"], "gap")

    def test_model_view_transform_in_model_is_a_gap(self):
        self.write({"src/demo/model/DemoModel.ts": "export const t = ModelViewTransform2.createIdentity();\n"})
        _, probes = self.run_check()
        self.assertEqual(probes["model-view-transform"]["status"], "gap")

    def test_warn_probe_reports_without_failing_unless_strict(self):
        self.write({"src/demo/view/HandleNode.ts": "export const d = new DragListener({});\n"})
        code, probes = self.run_check()
        self.assertEqual(probes["drag-listener"]["status"], "gap")
        self.assertEqual(code, 0)
        self.assertEqual(self.run_check("--strict")[0], 1)

    def test_missing_common_api_patterns_are_advisory(self):
        self.write({"src/demo/view/DemoScreenView.ts": "export class DemoScreenView {}\n"})
        code, probes = self.run_check()
        self.assertEqual(code, 0)
        for name in ("optionize", "layout", "ui-controls"):
            with self.subTest(probe=name):
                self.assertEqual(probes[name]["status"], "gap")
                self.assertEqual(probes[name]["level"], "warn")
        self.assertEqual(self.run_check("--strict")[0], 1)

    def test_keyboard_drag_satisfies_drag_listener(self):
        self.write({"src/demo/view/HandleNode.ts": "new DragListener({});\nnew KeyboardDragListener({});\n"})
        _, probes = self.run_check()
        self.assertEqual(probes["drag-listener"]["status"], "follow")

    def test_carve_out_bullet_approves_a_gap(self):
        self.write({
            "src/demo/model/Mode.ts": "export enum Mode { A, B }\n",
            "AGENTS.md": "# Demo\n\n## Compliance carve-outs\n\n- `skill:coding-conventions`: generated enum\n",
        })
        code, probes = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual(probes["coding-conventions"]["status"], "carved-out")

    def test_prose_mention_is_not_a_carve_out(self):
        self.write({
            "src/demo/model/Mode.ts": "export enum Mode { A, B }\n",
            "AGENTS.md": "## Compliance carve-outs\n\nWe once discussed `skill:coding-conventions` here.\n",
        })
        self.assertEqual(self.run_check()[0], 1)

    def test_sound_manager_requires_supports_sound(self):
        self.write({"src/demo/view/Sounds.ts": "soundManager.addSoundGenerator(x);\n", "src/init.ts": "export {};\n"})
        code, probes = self.run_check()
        self.assertEqual(code, 0)
        self.assertEqual(probes["sound"]["status"], "gap")
        self.write({"src/init.ts": "init({ supportsSound: true });\n"})
        self.assertEqual(self.run_check()[1]["sound"]["status"], "follow")


if __name__ == "__main__":
    unittest.main()
