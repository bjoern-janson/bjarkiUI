#!/usr/bin/env python3
"""Package exactly the frozen manifest to a supplied OUTSIDE-REPO path."""
import argparse
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--output", required=True, type=Path,
                    help="zip path (use /tmp or GitHub RUNNER_TEMP, not the repository)")
args = parser.parse_args()
output = args.output.resolve()
if ROOT == output or ROOT in output.parents:
    parser.error("read-only audit policy: output ZIP must be outside repository")

def manifest(name):
    content = (ROOT / name).read_text(encoding="utf-8")
    return [line.strip() for line in content.splitlines() if line.strip().endswith(".lua")]

modules = manifest("bjarkiUI.toc")
assert modules == manifest("bjarkiUI_Camelot.toc"), "TOCs disagree"
assert len(modules) == 11 and len(set(modules)) == 11, "unexpected module count"
assert all(Path(item).name == item for item in modules), "unsafe module path"
assert not list(ROOT.glob("EditMode-*.txt")), "unexpected layout presets"
inputs = modules + ["bjarkiUI.toc", "bjarkiUI_Camelot.toc"]
for name in inputs:
    assert (ROOT / name).is_file(), f"missing: {name}"
with ZipFile(output, "w", ZIP_DEFLATED, compresslevel=9) as z:
    for name in inputs:
        z.write(ROOT / name, arcname="bjarkiUI/" + name)
with ZipFile(output) as z:
    assert z.testzip() is None
    assert len(z.namelist()) == len(inputs)
print(f"PASS: packaged {len(modules)} frozen modules to {output}")
