#!/usr/bin/env python3
"""Fail if any production source file differs by a single byte from the 0.2.309 ZIP."""
from pathlib import Path
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[2]
# Git object hashes from the byte-identical imported distribution.
EXPECTED = {
    "bjarkiUI.lua": "ffff9c6af76f9b0c63c3fbdfb3a7f6fc9ed2d16e",
    "PartyOrder.lua": "53c096335a28b283ffe3babe88bf99c57ca7107b",
    "SoftDark.lua": "8459650e32c6db5af8ef649ee35966e1ef4b28e6",
    "TrackedBuffSeconds.lua": "20ddaca6d1fd74d340ddf23f120003d8536b0eb5",
    "CooldownSeconds.lua": "daf811919a7da47499b69d2f237abeb073327fa8",
    "NativeDigitCells.lua": "c53d01621a1f5214cd35de0a64f6f8daccd39612",
    "CastBarDigits.lua": "7ee3779a61f6d1455fe1651179f14f5c63491378",
    "IconSkin.lua": "b9574fbeb4ca8d252b73b7b13462c52c329992e2",
    "UnitAuraStyling.lua": "4a5e36fe0186001426c0a18b0a436bee0626d70a",
    "BuffPresentation.lua": "01bf3da9fa01732fd49bd1252eda3e6a680aed2e",
    "FrameLabelTweaks.lua": "219ed5903f799d920afb6b3830bc448bfd72ad49",
    "bjarkiUI.toc": "ae4e0b1bac221c1b5cf0a41aed5b556362e6f3b7",
    "bjarkiUI_Camelot.toc": "ae4e0b1bac221c1b5cf0a41aed5b556362e6f3b7",
}

def git_blob_sha(content):
    return hashlib.sha1(b"blob " + str(len(content)).encode("ascii") + b"\0" + content).hexdigest()

errors = []
for relative, expected in EXPECTED.items():
    try:
        actual = git_blob_sha((ROOT / relative).read_bytes())
    except OSError as exc:
        errors.append(f"{relative}: cannot read: {exc}")
        continue
    if actual != expected:
        errors.append(f"{relative}: expected {expected}, got {actual}")

for toc in ("bjarkiUI.toc", "bjarkiUI_Camelot.toc"):
    lines = (ROOT / toc).read_text(encoding="utf-8").splitlines()
    modules = [line.strip() for line in lines if line.strip().endswith(".lua")]
    if modules != list(EXPECTED)[:11]:
        errors.append(f"{toc}: 11-module load order differs from immutable baseline")

if errors:
    print("FAIL: frozen 0.2.309 source changed", file=sys.stderr)
    for error in errors:
        print("  " + error, file=sys.stderr)
    raise SystemExit(1)
print("PASS: all 11 runtime files + two TOCs match exact 0.2.309 Git blobs")
