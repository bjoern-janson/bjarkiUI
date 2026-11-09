#!/usr/bin/env bash
# Version-matched read-only tests. Output stays on stdout; no repo writes.
set -euo pipefail
cd "$(dirname "$0")/../.."
LUA_BIN="${LUA_BIN:-lua5.4}"
command -v "$LUA_BIN" >/dev/null || { echo "Lua 5.4 not found: $LUA_BIN" >&2; exit 2; }
python3 tools/audit/check_frozen_source.py
for test in tests/snapshot-0.2.309/*.lua; do
  echo "==> $test"
  "$LUA_BIN" "$test" .
done
printf 'PASS: all 0.2.309 snapshot tests\n'
