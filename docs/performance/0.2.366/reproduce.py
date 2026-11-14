#!/usr/bin/env python3
"""Reproduce bounded .365/.366 operation and allocation comparisons."""
from pathlib import Path
import argparse
import csv
import hashlib
import io
import json
import shutil
import statistics
import subprocess

BASELINE_TREE = "c94adfe014220533026df2099e2a908530431669"
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
    files = ["NativePrecision.lua", "bjarkiUI.lua", "ActionTimerSpacing.lua",
             "CooldownSeconds.lua", "tests/nameplate-color-discovery.lua", "tests/support/lua51.lua"]
    manifest = {"baseline_tree": BASELINE_TREE, "inputs": {}, "runs": []}

    def baseline(path):
        return subprocess.check_output(["git", "show", BASELINE_TREE + ":" + path], cwd=ROOT)

    def save(path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        manifest["inputs"][str(path.relative_to(output))] = hashlib.sha256(content).hexdigest()

    for version in ("before", "after"):
        for name in files:
            save(output / version / name, baseline(name) if version == "before" else (ROOT / name).read_bytes())
    soft = output / "softdark"
    save(soft / "before-SoftDark.lua", baseline("SoftDark.lua"))
    save(soft / "after-SoftDark.lua", (ROOT / "SoftDark.lua").read_bytes())
    save(soft / "fixture-softdark-discovery-handoff.lua", baseline("tests/softdark-discovery-handoff.lua"))
    expected = json.loads((HERE / "results.json").read_text())

    def run(lua, version, probe, argv, cwd, preload):
        command = [lua] + preload + [str(HERE / probe)] + [str(value) for value in argv]
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
        log = output / (Path(probe).stem + "-" + version + "-" + Path(lua).name + ".log")
        log.write_text(result.stdout + result.stderr)
        manifest["runs"].append({"command": command, "cwd": str(cwd), "log": log.name,
                                 "returncode": result.returncode})
        if result.returncode:
            raise RuntimeError("probe failed; inspect " + str(log))
        return result.stdout

    for number, executable in (("5.1", args.lua51), ("5.4", args.lua54)):
        lua = shutil.which(executable)
        if not lua:
            raise RuntimeError("missing interpreter: " + executable)
        preload = ["-l", "tests.support.lua51"] if number == "5.1" else []
        for version in ("before", "after"):
            cwd = output / version
            text = run(lua, version, "main-exit-counts.lua", [], cwd, preload)
            rows = {parts[0]: [int(value) for value in parts[1:]]
                    for line in text.splitlines() if "\t" in line
                    for parts in [line.split("\t")]}
            for phase in ("first_exit", "settled_exit", "nonclassic_exit"):
                row = rows[phase + "_after_flush"]
                want = expected["nameplates"][phase][version]
                assert row == [3, 2, want["callbacks"], want["anchor_writes"], 2, 2, 2], (phase, row)
            text = run(lua, version, "buff-preparation-counts.lua", [cwd], cwd, preload)
            rows = list(csv.DictReader(io.StringIO(text), delimiter="\t"))
            for row in rows:
                for key in list(row):
                    if key not in ("route", "phase"):
                        row[key] = int(row[key])
            assert rows == expected["buff"][number][version], rows
        text = run(lua, "comparison", "compare-softdark.lua", [soft], output / "after", preload)
        allocations = {version: [] for version in ("before", "after")}
        for line in text.splitlines():
            parts = line.split("\t")
            if parts[0] == "ALLOC":
                allocations[parts[1]].append(float(parts[-1]))
        before, after = (statistics.median(allocations[v]) for v in ("before", "after"))
        assert after < before, allocations
        print("PASS Lua", number, "exact main/buff work counts; identical SoftDark native calls and colors;")
        print("  SoftDark temporary bytes/exit:", before, "->", after, "(host-dependent allocation result)")
    (output / "reproduction.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("Evidence:", output)


if __name__ == "__main__":
    main()
