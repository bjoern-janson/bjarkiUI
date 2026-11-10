#!/usr/bin/env python3
"""Verify current Lua source/tests and optionally package one installable addon."""
from __future__ import annotations

import argparse
import importlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]


def package_inputs():
    manifests = sorted(p for p in ROOT.glob("*.toc") if not p.stem.endswith("_Camelot"))
    if len(manifests) != 1:
        raise ValueError("Expected one standard TOC and its matching Camelot TOC")
    main = manifests[0]
    addon = main.stem
    camelot = ROOT / (addon + "_Camelot.toc")

    def read_manifest(path):
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        modules = [line.strip() for line in lines if line.strip() and not line.lstrip().startswith("#")]
        versions = [line.split(":", 1)[1].strip() for line in lines if line.startswith("## Version:")]
        if len(versions) != 1:
            raise ValueError("Expected one Version field in " + path.name)
        return modules, versions[0]

    modules, version = read_manifest(main)
    if read_manifest(camelot) != (modules, version):
        raise ValueError("TOC versions or load orders disagree")
    if not modules or len(set(modules)) != len(modules):
        raise ValueError("Missing or duplicate runtime modules")
    for name in modules:
        relative = Path(name)
        if relative.suffix != ".lua" or relative.is_absolute() or ".." in relative.parts:
            raise ValueError("Unsafe runtime module path: " + name)
        if not (ROOT / relative).resolve().is_relative_to(ROOT) or not (ROOT / relative).is_file():
            raise ValueError("Missing or out-of-repository module: " + name)
    runtime_version = ROOT / ("Core.lua" if addon == "bjarkiPortraits" else "bjarkiUI.lua")
    source = runtime_version.read_text(encoding="utf-8")
    marker = r'R\.VERSION\s*=\s*"([^"]+)"' if addon == "bjarkiPortraits" else r'BJARKI_UI_VERSION\s*=\s*"([^"]+)"'
    match = re.search(marker, source)
    if not match or match.group(1) != version:
        raise ValueError("Runtime version differs from the manifests")
    extras = ["Media/TimerSpacer.tga"] if addon == "bjarkiUI" else []
    inputs = modules + [main.name, camelot.name] + extras
    if any(not (ROOT / name).is_file() for name in inputs):
        raise ValueError("A package input is missing")
    if list(ROOT.glob("EditMode-*.txt")):
        raise ValueError("Bundled Edit Mode presets are prohibited")
    forbidden = ("C_EditMode.SaveLayouts", "C_EditMode.OnLayoutAdded",
                 "C_EditMode.SetActiveLayout", "C_EditMode.ConvertStringToLayoutInfo")
    for name in modules:
        if any(api in (ROOT / name).read_text(encoding="utf-8") for api in forbidden):
            raise ValueError("Unexpected Edit Mode layout writer in " + name)
    tests = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "tests").glob("*.lua"))
    if not tests:
        raise ValueError("No current regression suites found")
    return addon, version, modules, inputs, tests


def verify_native(addon, modules, tests, interpreters, compilers):
    failures = []
    for lua, luac in zip(interpreters, compilers):
        if not shutil.which(lua) or not shutil.which(luac):
            raise ValueError("Missing Lua executable/compiler: " + lua + " / " + luac)
        result = subprocess.run([lua, "-e", "io.write(_VERSION)"], cwd=ROOT,
                                check=True, capture_output=True, text=True)
        version = result.stdout.strip()
        if version not in ("Lua 5.1", "Lua 5.4"):
            raise ValueError("Unsupported interpreter: " + version)
        compiler = subprocess.run([luac, "-v"], cwd=ROOT, check=True, capture_output=True, text=True)
        if not re.search(r"\b" + re.escape(version) + r"(?:\.|\s|$)", compiler.stdout + compiler.stderr):
            raise ValueError("Compiler does not match " + version)
        before = len(failures)
        for name in modules + tests:
            if subprocess.run([luac, "-p", name], cwd=ROOT).returncode:
                failures.append(version + " syntax " + name)
        preload = ["-l", "tests.support.lua51"] if addon == "bjarkiUI" and version == "Lua 5.1" else []
        for name in tests:
            if subprocess.run([lua] + preload + [name, "."], cwd=ROOT).returncode:
                failures.append(version + " " + name)
        print(("PASS" if len(failures) == before else "FAIL"), version,
              len(modules), "modules,", len(tests), "suites", flush=True)
    return failures


def verify_lupa(addon, modules, tests):
    # Optional local runner; CI uses the standalone interpreters and compilers.
    failures = []
    previous = Path.cwd()
    os.chdir(ROOT)
    try:
        for version in ("51", "54"):
            runtime = importlib.import_module("lupa.lua" + version).LuaRuntime
            compiler = runtime()
            before = len(failures)
            for name in modules + tests:
                try:
                    compiler.compile((ROOT / name).read_bytes(), name="@" + name)
                except Exception as exc:
                    failures.append("Lua " + version + " syntax " + name)
                    print(failures[-1], exc, file=sys.stderr)
            for name in tests:
                vm = runtime()
                vm.globals().arg = vm.table_from({0: name, 1: "."})
                vm.execute("os.exit=function(c) assert(not c or c==0, 'test exited '..tostring(c)) end")
                if version == "51" and addon == "bjarkiUI":
                    vm.execute("require('tests.support.lua51')")
                try:
                    vm.execute((ROOT / name).read_bytes(), name="@" + name)
                except Exception as exc:
                    failures.append("Lua " + version + " " + name)
                    print(failures[-1], exc, file=sys.stderr)
            print(("PASS" if len(failures) == before else "FAIL"), "Lua " + version,
                  len(modules), "modules,", len(tests), "suites", flush=True)
    finally:
        os.chdir(previous)
    return failures


def write_package(addon, inputs, output):
    # Capture the tested bytes; the archive contains runtime inputs only.
    payloads = {addon + "/" + name: (ROOT / name).read_bytes() for name in inputs}
    with ZipFile(output, "x", ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in payloads.items():
            archive.writestr(name, data)
    with ZipFile(output) as archive:
        if archive.testzip() is not None or archive.namelist() != list(payloads):
            raise ValueError("Package integrity/member check failed")
        for name, data in payloads.items():
            if archive.read(name) != data:
                raise ValueError("Packaged bytes differ: " + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", action="append", help="Interpreter; repeat with matching --luac for each version")
    parser.add_argument("--luac", action="append", help="Matching compiler; default pairs are Lua 5.1 and 5.4")
    parser.add_argument("--lupa", action="store_true", help="Use optional Python lupa.lua51 and lupa.lua54 instead")
    parser.add_argument("--output", type=Path, help="New installable ZIP outside the repository")
    args = parser.parse_args()
    if args.lupa and (args.lua or args.luac):
        parser.error("--lupa cannot be combined with --lua/--luac")
    interpreters = args.lua or ["lua5.1", "lua5.4"]
    compilers = args.luac or ["luac5.1", "luac5.4"]
    if len(interpreters) != len(compilers) or bool(args.lua) != bool(args.luac):
        parser.error("Provide one matching --luac per --lua")
    output = args.output.resolve() if args.output else None
    if output and (output.is_relative_to(ROOT) or output.exists() or not output.parent.is_dir()):
        parser.error("--output must be a new file in an existing directory outside the repository")
    try:
        addon, version, modules, inputs, tests = package_inputs()
        failures = (verify_lupa(addon, modules, tests) if args.lupa else
                    verify_native(addon, modules, tests, interpreters, compilers))
        if failures:
            print("FAILED: " + ", ".join(failures), file=sys.stderr)
            return 1
        if output:
            write_package(addon, inputs, output)
            print("PASS package:", output, len(inputs), "files")
        print("PASS", addon, version, "- offline verification; live client behavior remains unverified")
        return 0
    except (ValueError, OSError, ImportError, subprocess.CalledProcessError) as exc:
        print("FAIL:", exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.dont_write_bytecode = True
    raise SystemExit(main())
