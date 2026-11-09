# bjarkiUI — 0.2.309 read-only Codex audit branch

**You are on `audit/codex-0.2.309-readonly`, not the release branch.** This checkout is an **exact, frozen snapshot** of `0.2.309-native-spacing-castbar` (2026-11-09), assembled to let Codex perform an extensive **read-only** bug audit. It is *not* a merge request or a new stable release. GitHub `main` stays on `0.2.286`.

## Start here if you are Codex

1. Read [AGENTS.md](AGENTS.md) — **do not change any files or create commits**.
2. Read [the deep audit instructions](docs/CODEX_DEEP_AUDIT.md) and [source/verification baseline](docs/AUDIT_BASELINE.md).
3. Run `python3 tools/audit/check_frozen_source.py`, then `bash tools/audit/run_snapshot_tests.sh` with Lua 5.4 available (CI installs it). Both are read-only.
4. Audit the exact code and deliver a severity-ranked report in chat, following [the findings template](docs/AUDIT_FINDINGS_TEMPLATE.md). Do not apply fixes.

**Suggested task text:** [Codex start prompt](docs/CODEX_START_PROMPT.md).

## Contents and provenance

- Eleven load-ordered Lua modules, including `NativeDigitCells.lua` and `CastBarDigits.lua`, and the two matching `.toc` manifests.
- `tests/snapshot-0.2.309/`: the nine **original version-matched behavioral regression scripts** plus a syntax manifest test, imported byte-for-byte from the 0.2.309 test archive.
- `tests/*.lua`: retained older historical regression scripts from the `.286` repository. These may contain stale expectations. Do not silently use their failure or success as evidence for `.309`.
- `tools/audit/`: read-only baseline checksum, portable suite runner, external-output package script, and archived historical runner/packager.
- `.github/workflows/audit-0.2.309.yml`: separate source-frozen audit CI with no write permission. The older `package-addon.yml` workflow targets `main` and its nine-module baseline; do not treat it as `.309` audit validation.

### Functional scope under audit

This addon refines Blizzard's original UI (unit frames, names, status text, buffs, icons, cooldown labels, party ordering, Soft Dark appearance, bags and combat icon). Its newest work uses **native duration bindings and individually anchored characters** to stabilize timer numbers while keeping default Blizzard fonts and icons. The cast timer geometry in `.309` remains an unverified in-game experiment.

**No-change invariants:** no font swaps, no new slash commands, no polling, no Edit Mode layout writes, no gameplay action changes, and no target/focus restricted-aura replacements. The user previously reported combat stutter from timer-typography hooks and a protected-action error from custom target/focus aura handling. These are audit priorities, not invitations to recreate the unsafe designs.

## Install/package distinction

Use a verified release ZIP for gameplay; this branch is an audit snapshot. The read-only workflow can create an installable 11-module ZIP outside the checkout as an artifact, but **a passing CI result is not live-client verification**. Do not merge the audit branch into `main` solely because its offline tests pass.

Historical context remains in [ARCHITECTURE.md](ARCHITECTURE.md), [KNOWN_ISSUES.md](KNOWN_ISSUES.md) and [CHANGELOG.md](CHANGELOG.md). Some of their dated sections describe earlier `.286` and below rather than this frozen `.309` experiment.
