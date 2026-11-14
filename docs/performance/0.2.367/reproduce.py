#!/usr/bin/env python3
"""Reproduce .366/.367 target-refresh allocation and behavior comparisons."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess

BASELINE_TREE = "546ee7ea64be8f2ff5a2f2955c4de7e1bbf34b5f"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua51", default="lua5.1")
    parser.add_argument("--lua54", default="lua5.4")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    output = args.output.resolve()
    if output == ROOT or ROOT in output.parents or output.exists():
        parser.error("output must be a new directory outside the checkout")
    output.mkdir(parents=True)
    manifest = {"baseline_tree": BASELINE_TREE, "inputs": {}, "runs": []}

    def baseline(name):
        return subprocess.check_output(["git", "show", BASELINE_TREE + ":" + name], cwd=ROOT)

    def save(path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        manifest["inputs"][str(path.relative_to(output))] = hashlib.sha256(content).hexdigest()

    names = ["NativePrecision.lua", "bjarkiUI.lua", "FrameLabelTweaks.lua",
             "IconSkin.lua", "BuffPresentation.lua", "UnitAuraStyling.lua",
             "tests/support/lua51.lua"]
    for version in ("before", "after"):
        for name in names:
            save(output / version / name, baseline(name) if version == "before" else (ROOT / name).read_bytes())
    for name in ("main-readers.lua", "icon-readers.lua", "labels/compare.lua", "labels/fixture.lua"):
        save(output / "probes" / name, (HERE / name).read_bytes())
    assert (HERE / "labels/fixture.lua").read_bytes() == baseline("tests/frame-label-tweaks.lua"), "label fixture is not the frozen .366 source"

    for number, executable in (("5.1", args.lua51), ("5.4", args.lua54)):
        lua = shutil.which(executable)
        if not lua:
            raise RuntimeError("missing interpreter: " + executable)
        preload = ["-l", "tests.support.lua51"] if number == "5.1" else []
        before, after, probes = output / "before", output / "after", output / "probes"
        cases = [
            ("main", probes / "main-readers.lua", [before / "bjarkiUI.lua", after / "bjarkiUI.lua", "--require-improvement"]),
            ("labels", probes / "labels/compare.lua", [before, after, output / ("labels-" + number)]),
            ("icons", probes / "icon-readers.lua", [before, before / "IconSkin.lua", after / "IconSkin.lua", "128"]),
        ]
        for name, probe, values in cases:
            command = [lua] + preload + [str(probe)] + [str(value) for value in values]
            result = subprocess.run(command, cwd=before, capture_output=True, text=True)
            log = output / (name + "-" + number + ".log")
            log.write_text(result.stdout + result.stderr)
            manifest["runs"].append({"command": command, "cwd": str(before), "log": log.name, "returncode": result.returncode})
            (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            if result.returncode:
                raise RuntimeError("comparison failed; inspect " + str(log))
            print("PASS", number, name, "native/presentation parity and lower allocation")
    print("PASS all six comparisons; no client CPU or frame-time measurement")


if __name__ == "__main__":
    main()
