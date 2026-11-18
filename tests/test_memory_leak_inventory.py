"""Memory-leak inventory: class-body parsing, suite bindings, carve-outs (check-memory-leak-inventory.mjs)."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

BATON = Path(__file__).resolve().parents[1]

NODE_IMPORT = 'import { Node } from "scenerystack/scenery";\n'


def node_with_dispose(name, with_import=True):
    """A scenery Node subclass that overrides dispose()."""
    body = f"export class {name} extends Node {{\n  public override dispose(): void {{\n    super.dispose();\n  }}\n}}\n"
    return (NODE_IMPORT if with_import else "") + body


SUITE_HEADER = 'import { describeDisposalLeaks } from "./helpers/memoryLeak.js";\n'


class MemoryLeakInventoryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.sim = Path(self.directory.name) / "Demo"
        self.write({"tests/memory-leak.test.ts": SUITE_HEADER + "describeDisposalLeaks([]);\n"})

    def write(self, files):
        for rel, text in files.items():
            path = self.sim / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)

    def suite(self, body):
        self.write({"tests/memory-leak.test.ts": SUITE_HEADER + body})

    def run_check(self):
        result = subprocess.run(
            ["node", str(BATON / "scripts/check-memory-leak-inventory.mjs"), "--json", str(self.sim)],
            capture_output=True, text=True, check=False,
        )
        report = json.loads(result.stdout)[0]
        return result.returncode, sorted(m["name"] for m in report["missing"]), report

    # ── Coverage on the suite side ──────────────────────────────────────────

    def test_import_path_only_mention_is_not_coverage(self):
        # StandingWaves: EquationReadoutNode imported from PhaseControlPanel.js must not credit PhaseControlPanel.
        self.write({
            "src/view/PhaseControlPanel.ts": node_with_dispose("PhaseControlPanel")
            + node_with_dispose("EquationReadoutNode", with_import=False),
        })
        self.suite(
            'import { EquationReadoutNode } from "../src/view/PhaseControlPanel.js";\n'
            'describeDisposalLeaks([{ name: "readout", create: () => new EquationReadoutNode() }]);\n'
        )
        code, missing, _ = self.run_check()
        self.assertEqual(code, 1)
        self.assertEqual(missing, ["PhaseControlPanel"])

    def test_comment_and_string_mentions_are_not_coverage(self):
        self.write({"src/view/FooNode.ts": node_with_dispose("FooNode")})
        self.suite('// FooNode is not covered here.\nit("FooNode later", () => {});\n')
        _, missing, _ = self.run_check()
        self.assertEqual(missing, ["FooNode"])

    def test_identifier_substring_is_not_coverage(self):
        # Oscilloscope: `disconnectChannel` must not credit Channel.
        self.write({"src/model/Channel.ts": "export class Channel {\n  public dispose(): void {}\n}\n"})
        self.suite("const model = { disconnectChannel: (n: number) => n };\nmodel.disconnectChannel(1);\n")
        _, missing, _ = self.run_check()
        self.assertEqual(missing, ["Channel"])

    def test_type_only_import_is_not_coverage(self):
        self.write({"src/view/FooNode.ts": node_with_dispose("FooNode")})
        self.suite('import type { FooNode } from "../src/view/FooNode.js";\nlet n: FooNode | null = null;\n')
        _, missing, _ = self.run_check()
        self.assertEqual(missing, ["FooNode"])

    def test_value_import_construction_and_case_name_cover(self):
        self.write({
            "src/view/FooNode.ts": node_with_dispose("FooNode"),
            "src/view/BarNode.ts": node_with_dispose("BarNode"),
            "src/view/BazNode.ts": node_with_dispose("BazNode"),
        })
        self.suite(
            'import { FooNode } from "../src/view/FooNode.js";\n'
            'import * as views from "../src/view/BarNode.js";\n'
            "describeDisposalLeaks([\n"
            '  { name: "FooNode", create: () => new FooNode() },\n'
            '  { name: "bar", create: () => new views.BarNode() },\n'
            '  { name: "BazNode (via factory)", create: () => makeNode("baz") },\n'
            "]);\n"
        )
        code, missing, _ = self.run_check()
        self.assertEqual((code, missing), (0, []))

    def test_explicit_covers_declaration_for_factory_probes(self):
        # OpticsLab: views built by createOpticalElementView(key) never name their class.
        self.write({
            "src/view/BaseView.ts": "export abstract class BaseView {\n  public dispose(): void {}\n}\n",
            "src/view/GlassView.ts": "export class GlassView extends BaseView {}\n",
            "src/view/MirrorView.ts": "export class MirrorView extends BaseView {}\n",
            "src/view/DetectorChartPanel.ts": node_with_dispose("DetectorChartPanel"),
            "src/view/Stray.ts": node_with_dispose("Stray"),
        })
        self.suite(
            "// memory-leak-covers-subclasses: BaseView (every view via createView(ALL_KEYS))\n"
            "/* memory-leak-covers: DetectorChartPanel (owned by DetectorView),\n"
            " *   SomethingElse */\n"
            'for (const key of ALL_KEYS) createView(key).dispose();\n'
        )
        _, missing, _ = self.run_check()
        self.assertEqual(missing, ["Stray"])

    # ── Class bodies on the source side ─────────────────────────────────────

    def test_two_classes_in_one_file_do_not_borrow_dispose(self):
        # CartCollisions: CartTrace sat just above Recording.dispose() in the same file.
        self.write({
            "src/model/Recording.ts": (
                "export class CartTrace {\n  public readonly times: number[] = [];\n}\n\n"
                "export class Recording {\n  private readonly traces = [new CartTrace()];\n"
                "  public dispose(): void {\n    this.traces.length = 0;\n  }\n}\n"
            ),
        })
        _, missing, _ = self.run_check()
        self.assertEqual(missing, ["Recording"])

    def test_late_dispose_in_long_class_is_found(self):
        # FluidDynamics: WebGPUFluidEngine.dispose() sits ~20k characters into the class.
        method = "  private method%d(): string {\n    const s = `{${%d}} }`; // } {\n    return s + '}';\n  }\n"
        filler = "".join(method % (i, i) for i in range(400))
        self.write({
            "src/gpu/Engine.ts": "export class Engine {\n" + filler + "  public dispose(): void {}\n}\n",
        })
        self.assertGreater(len((self.sim / "src/gpu/Engine.ts").read_text()), 20000)
        _, missing, report = self.run_check()
        self.assertEqual(missing, ["Engine"])
        self.assertIn("Engine.ts:", report["missing"][0]["why"])

    def test_braces_in_strings_regex_and_non_null_division_stay_balanced(self):
        self.write({
            "src/model/Tricky.ts": (
                "export class Tricky {\n"
                "  private a = '{';\n"
                '  private b = "}}";\n'
                "  private c = /[{}]+/g;\n"
                "  private d(x: number[]): number { return x[0]! / 2; }\n"
                "  private e = `${'}'}${`{`}`;\n"
                "}\n"
                "export class After {\n  public dispose(): void {}\n}\n"
            ),
        })
        _, missing, _ = self.run_check()
        self.assertEqual(missing, ["After"])

    def test_inherited_dispose_from_same_sim_parent(self):
        self.write({
            "src/model/BaseModel.ts": "export class BaseModel {\n  public dispose(): void {}\n}\n",
            "src/model/IntroModel.ts": "export class IntroModel extends BaseModel {\n  public constructor() { super(); }\n}\n",
            "src/view/PlainNode.ts": 'import { Node } from "scenerystack/scenery";\nexport class PlainNode extends Node {}\n',
        })
        self.suite('import { BaseModel } from "../src/model/BaseModel.js";\nnew BaseModel().dispose();\n')
        _, missing, report = self.run_check()
        self.assertEqual(missing, ["IntroModel"])
        self.assertIn("inherits dispose() from BaseModel", report["missing"][0]["why"])

    def test_abstract_base_is_covered_by_a_covered_subclass(self):
        self.write({
            "src/model/BaseModel.ts": "export abstract class BaseModel {\n  public dispose(): void {}\n}\n",
            "src/model/IntroModel.ts": "export class IntroModel extends BaseModel {}\n",
        })
        self.suite('import { IntroModel } from "../src/model/IntroModel.js";\nnew IntroModel().dispose();\n')
        code, missing, _ = self.run_check()
        self.assertEqual((code, missing), (0, []))

    def test_dispose_emitter_cleanup_is_reported_not_flagged(self):
        # this.disposeEmitter / this.addDisposable on an external base is not a dispose() definition,
        # and `disposeEmitter` / `disposeFoo` members must not be mistaken for one.
        self.write({
            "src/view/LabelNode.ts": (
                'import { Node } from "scenerystack/scenery";\n'
                "export class LabelNode extends Node {\n"
                "  private readonly disposeLabelNode: () => void;\n"
                "  public constructor() {\n    super();\n"
                "    this.disposeLabelNode = () => undefined;\n"
                "    this.disposeEmitter.addListener(() => this.disposeLabelNode());\n  }\n}\n"
            ),
            "src/view/Typed.ts": "export abstract class Typed {\n  public abstract dispose(): void;\n  public dispose2(): void {}\n}\n",
        })
        code, missing, report = self.run_check()
        self.assertEqual((code, missing), (0, []))
        self.assertEqual(report["disposeEmitterOnly"], ["LabelNode"])

    def test_screen_view_and_sim_classes_are_skipped(self):
        self.write({
            "src/intro/IntroScreenView.ts": node_with_dispose("IntroScreenView"),
            "src/DemoSim.ts": node_with_dispose("DemoSim"),
        })
        code, missing, _ = self.run_check()
        self.assertEqual((code, missing), (0, []))

    # ── Carve-outs ──────────────────────────────────────────────────────────

    def test_carve_out_hides_gap_and_orphans_are_reported(self):
        self.write({
            "src/view/FooNode.ts": node_with_dispose("FooNode"),
            "src/model/Recording.ts": "export class CartTrace {}\nexport class Recording {\n  public dispose(): void {}\n}\n",
            "AGENTS.md": (
                "# Demo\n\n## Compliance carve-outs\n\n"
                "- `memory-leak:FooNode` — needs a laid-out screen.\n"
                "- `memory-leak:CartTrace` — no dispose() of its own.\n"
                "- `memory-leak:Recording` — covered elsewhere.\n\n## Testing\n"
            ),
        })
        self.suite('import { Recording } from "../src/model/Recording.js";\nnew Recording().dispose();\n')
        code, missing, report = self.run_check()
        self.assertEqual((code, missing), (0, []))
        self.assertEqual(report["orphaned"], ["CartTrace", "Recording"])

    def test_text_output_keeps_the_coverage_script_format(self):
        self.write({"src/view/FooNode.ts": node_with_dispose("FooNode")})
        result = subprocess.run(
            ["bash", str(BATON / "scripts/check-memory-leak-coverage.sh"), str(self.sim)],
            capture_output=True, text=True, check=False,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout.strip(), "Demo: FooNode")


if __name__ == "__main__":
    unittest.main()
