# Immutable 0.2.309 audit baseline

The checksums below identify the [pinned audit checkout](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78). For current source and test commands, see the [code map](CODE_MAP.md).

**Date:** 2026-11-09. **Repository:** `bjoern-janson/bjarkiUI`. **Audit branch:** `audit/codex-0.2.309-readonly`. **GitHub main:** still v0.2.286 at `f21400f004ac024204944663a8ed91c7fb15616c`. **Imported source commit:** `9236bbe587d68d5b98b9b432a637c1032544f02b`.

This branch's eleven Lua modules and both `.toc` manifests are byte-identical to the complete local build `bjarkiUI-0.2.309-compact-castbar-native-spacing-COMPLETE.zip`, SHA-256:

`5f08c263afe33cc2b8b87c594e264582e40c78812c9479e1974a11bbc708cc26`

The nine version-matched test scripts, manifest syntax test, archived test runner and original packaging script were also imported byte-for-byte. The root `tests/*.lua` remain historical tests from main; `tests/snapshot-0.2.309/` is the canonical .309 regression set. The old `tools/audit/verify_and_package.py` is a historical reproduction script with hard-coded `/mnt/data` paths, not the portable CI runner. Use `tools/audit/run_snapshot_tests.sh`, `check_frozen_source.py`, and `package_snapshot.py` instead.

## Load order — 11 modules

1. `bjarkiUI.lua`
2. `PartyOrder.lua`
3. `SoftDark.lua`
4. `TrackedBuffSeconds.lua`
5. `CooldownSeconds.lua`
6. `NativeDigitCells.lua`
7. `CastBarDigits.lua`
8. `IconSkin.lua`
9. `UnitAuraStyling.lua` (intentionally inactive stub)
10. `BuffPresentation.lua`
11. `FrameLabelTweaks.lua`

`bjarkiUI.toc` and `bjarkiUI_Camelot.toc` match. Do not alter this order during an audit.

## Verification evidence (not a release certification)

- The original .309 local packaging check reported **6,033 passing behavioral assertions across nine focused suites** plus 11 syntax checks. The complete tests were rerun successfully on Lua 5.4 with the identical snapshot source, independently of the original packaging script.
- The .309 ZIP passed archive integrity checks. Every imported GitHub blob SHA-1 matched the source bytes, including preserved CRLF where present.
- No live WoW: Forever combat, taint, locale, UI-scale or renderer test has validated this audit branch. Passing offline tests do **not** establish zero combat stutter, pixel-perfect spacing, safe protected calls or absence of regressions in areas not covered by fixtures.
- The `.309` cast-bar placement is a test build, not an accepted final UI design. Preserve its behavior in the audit; report defects without editing the working tree.

## Frozen-source checks

`python3 tools/audit/check_frozen_source.py` verifies the Git blob hash of all eleven runtime modules and both TOC files against the supplied release. This is a guardrail: it intentionally fails if those files change. The read-only audit workflow packages the exact manifest order and runs the matched tests. Do not edit hashes to make a changed runtime pass.

## What changed since main, conceptually

- Portrait-relative, level-mirrored player combat icon.
- More sophisticated player aura timer/fallback handling with native time modifiers, including weapon-enchant durations.
- Native fixed-character countdown presenters for accessible action-bar and player aura timers, independent cells for 2- and 3-digit seconds, real cooldown numbers but not GCD-only numbers.
- Fixed-digit player cast-bar presentation for cast/channel countdowns, with `.309` trying to align compact numbers with Blizzard's native cast timer start.
- Numerous test-only positioning, timer-lifecycle, styling and packaging experiments occurred along the way. Their effects are not all in-game certified.

**Branch policy:** This is a frozen comparison snapshot. Keep GitHub `main` and all runtime files unchanged. Audit results belong in Codex's final response unless the user separately authorizes a follow-up change.
