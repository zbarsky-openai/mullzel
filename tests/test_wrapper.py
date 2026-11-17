"""Exercise the Mullzel wrapper without Cargo, Rust, or Mull installed."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "mullzel"

FAKE = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["MULLZEL_TEST_LOG"], "a") as log:
    print(json.dumps([name, args, os.environ.get("MULL_CONFIG"),
                      os.environ.get("RUSTC_BOOTSTRAP")]), file=log)

if name == "cargo":
    print("mull: ordinary non-JSON plugin output")
    triple = {
        "reason": "compiler-artifact",
        "manifest_path": str(Path("Cargo.toml").resolve()),
        "package_id": "path+file:///tmp/demo#0.1.0",
        "target": {"name": "demo", "kind": ["lib"], "crate_types": ["lib"]},
        "profile": {"test": True},
        "executable": os.environ["MULLZEL_TEST_ARTIFACT"],
    }
    decoy = dict(triple, target={"name": "decoy", "kind": ["test"]},
                 executable=os.environ["MULLZEL_TEST_DECOY"])
    lib = dict(triple, profile={"test": False},
               executable=os.environ["MULLZEL_TEST_DECOY"])
    for entry in (decoy, lib, triple):
        print(json.dumps(entry))
elif name == "test-bin":
    rc = int(os.environ.get("MULLZEL_TEST_BASELINE_EXIT", "0"))
    if not rc:
        print("test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out")
    sys.exit(rc)
"""


class WrapperIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name).resolve()
        self.log = self.root / "commands.jsonl"
        self.plugin = self.root / "plugin.so"
        self.plugin.touch()
        self.config = self.root / "mull.yml"
        self.config.write_text("mutators: []\n", encoding="utf-8")
        self.manifest = self.root / "Cargo.toml"
        self.manifest.write_text(
            '[package]\nname = "demo"\nversion = "0.1.0"\n', encoding="utf-8"
        )
        for name in ("cargo", "test-bin", "runner", "decoy"):
            path = self.root / name
            path.write_text(FAKE, encoding="utf-8")
            path.chmod(0o755)

    def run_wrapper(self, baseline_exit=0):
        env = os.environ.copy()
        env.update(
            PATH=f"{self.root}{os.pathsep}{env.get('PATH', '')}",
            MULLZEL_TEST_LOG=str(self.log),
            MULLZEL_TEST_ARTIFACT=str(self.root / "test-bin"),
            MULLZEL_TEST_DECOY=str(self.root / "decoy"),
            MULLZEL_TEST_BASELINE_EXIT=str(baseline_exit),
        )
        result = subprocess.run(
            [
                str(WRAPPER), "--plugin", str(self.plugin),
                "--runner", str(self.root / "runner"), "--toolchain", "1.85.1",
                "--config", str(self.config), "--manifest-path", str(self.manifest),
                "--package", "demo", "--lib", "--offline", "--bootstrap",
                "--runner-arg=--debug", "--", "name with spaces", "--exact",
            ],
            cwd=self.root, env=env, capture_output=True, text=True, timeout=10,
        )
        trace = (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists() else []
        )
        return result, trace

    def test_selects_test_profile_artifact_and_runs_baseline_before_mutation(self):
        result, trace = self.run_wrapper()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([item[0] for item in trace], ["cargo", "test-bin", "runner"])
        cargo, baseline, runner = (entry[1] for entry in trace)
        for arg in ("+1.85.1", "rustc", "--lib", "--offline", str(self.manifest),
                    "demo", "--profile", "test", "--message-format=json",
                    f"-Zllvm-plugins={self.plugin}"):
            self.assertIn(arg, cargo)
        self.assertEqual(trace[0][2:], [str(self.config), "1"])
        self.assertEqual(trace[2][2], str(self.config))
        self.assertEqual(baseline, ["name with spaces", "--exact"])
        self.assertIn("--debug", runner)
        self.assertEqual(runner[-4:], ["--", str(self.root / "test-bin"), "name with spaces", "--exact"])

    def test_does_not_start_mutation_after_failed_baseline(self):
        result, trace = self.run_wrapper(baseline_exit=17)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([item[0] for item in trace], ["cargo", "test-bin"])


if __name__ == "__main__":
    unittest.main()
