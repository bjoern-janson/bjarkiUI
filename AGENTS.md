# Codex instructions — bjarkiUI audit branch

This branch is an **evidence-only, read-only bug hunt**. The user wants exhaustive bug discovery **without changing the addon**. These instructions apply to all files and subdirectories.

## Absolute rules

1. **DO NOT EDIT ANY TRACKED FILE**, including Lua, manifests, tests, docs, workflows, images or package metadata. Do not create a commit, branch, PR or tag; do not stage files; do not run autoformatters, autofixers, upgrade scripts, or generators that write into the repository. Read-only commands, tests, and temporary scratch work **outside** the repository are permitted.
2. Preserve appearance and native ownership: original Blizzard fonts, icons, cast/action-bar artwork, Edit Mode layouts, keybinds, positions, colours, ability semantics, and all current timer behavior. Propose minimal repairs in findings, but **do not implement** them until the user explicitly lifts the read-only restriction in a future request.
3. Read `docs/CODEX_DEEP_AUDIT.md` and `docs/AUDIT_BASELINE.md` before starting. Work from **this audit branch's frozen 0.2.309 snapshot**, not `main` (0.2.286) or an older test ZIP. Neither the branch name nor an offline green suite certifies client compatibility.
4. WoW: Forever employs **secret/restricted values, forbidden aura frames, and protected operations**. Do not circumvent secrecy or force restricted target/focus aura access. `UnitAuraStyling.lua` is intentionally inert after a live taint report; do not propose restoring its retired replacement hooks as a cosmetic fix.
5. Do not add polling, high-frequency OnUpdate work, text measurement loops or per-frame scans as a cosmetic fix. The user previously observed combat stutter from excessive timer styling. Native digit bindings may have engine-side costs even without Lua tickers: audit their cardinality and lifecycle.
6. Do not ask the user to run debug slash commands for routine evidence; the user dislikes in-game command-based workflows. In-game-only behavior must be marked **requires live verification** instead of claimed fixed.
7. A useful finding requires an exact source location, trigger, failure mechanism, reproducible test or state trace, impact/severity, competing explanations considered, and a narrowly scoped proposed fix **without applying it**. Treat an untested suspicion as a hypothesis, not a confirmed bug.
8. Check `git status --porcelain` at the beginning and end. Leave it clean. Store scratch files under `/tmp` or another location outside the checkout. Report everything in the chat response, not as an unrequested repository edit.

## Start here

Run `python3 tools/audit/check_frozen_source.py` and `bash tools/audit/run_snapshot_tests.sh` if Lua 5.4 is installed. Consult the dedicated branch GitHub Actions audit workflow for the reproducible CI environment. Legacy `tests/*.lua` are retained as historical evidence; the version-matched regression suite is under `tests/snapshot-0.2.309/`.

**Stop condition:** If you cannot verify a claim without a live client or prohibited code modification, report the limitation and keep the checkout unchanged. Do not invent a fix or silently broaden scope.
