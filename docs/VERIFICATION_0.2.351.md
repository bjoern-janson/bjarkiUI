# Verification record for 0.2.351

Baseline: upstream `d4d24b4eacac46821f53937c64219c732893a0d5` (0.2.350), source tree `f06a67547bf7e37c92cdff628e43743d72ba0cd8`.

## Live evidence and correction

The user's two November 12 screenshots show target/focus crowns crowding the secondary circles while the player crown has clearance, and detached upper-left resting Zs. The previous equal-anchor assertions and non-overlap-only resting assertion did not establish visual parity or adjacency.

- Preserve Player crown (5, 11); set Target/Focus (-7, 11), a two-unit inward optical correction from .350. Classic-party crowns keep native X+2.
- Attach the original resting texture CENTER to the original player crown RIGHT with X = half the actual resting texture width + two portrait units converted to texture scale, Y = 0. The native animation, artwork and visibility are preserved.
- Recalculate accepted resting anchors after safe scale/layout changes while retaining stock-anchor eligibility, native float32 receipts, refusal retries and foreign-anchor exclusion.

The relevant [bjarkiPortraits .252 secondary geometry](https://github.com/bjoern-janson/bjarkiPortraits/blob/c176745270669c318a561e09b37abcb2f8aac1ed/Core.lua) matches .248. Its unnamed secondary frames remain private; bjarkiUI adds no cross-addon frame scanning or dependency. The precise renderer/scale cause of the unequal visible crown gap is not established, so the target/focus correction is explicitly optical calibration from the live report.

## Local verification

- All 36 current top-level suites passed under native Lua 5.1.5 and Lua 5.4.6 on the final .351 runtime/metadata. Lua 5.1 uses the existing fixture compatibility preload.
- Syntax checks use each native interpreter's `loadfile`; local verification did not claim a separate luac invocation. The repository CI uses native Lua and luac.
- Updated crown expectations failed against .350 (-5 instead of -7), then all nine crown scenarios passed after the correction.
- The revised resting adjacency fixture failed against .350's portrait-relative anchor before implementation. All 14 scenarios now pass, checking scaled physical edge distance and aligned centers, hidden/moving crowns, native width/scale changes, float32 receipts, combat, refused writes, invalid geometry and foreign anchors.
- The installable ZIP contains 19 files: 16 runtime modules, both matching TOCs and the existing media file. The repository package verifier checked archive integrity, membership and byte-for-byte equality against the tested inputs.
- One independent read-only review found no actionable runtime issues and reran all nine crown scenarios and 14 resting scenarios on both native interpreters. Its pending verification-document link was resolved before delivery.
- `git diff --check` passed.

## Artifact

`bjarkiUI-0.2.351-Crown-Spacing.zip`

SHA-256: `dcb0a250288cffa97939c0b1f550dc9752e47ccd4a8d8050bc54afacafda96b9`

## Reproduce and limits

Use `python3 tools/verify.py` with native Lua/luac 5.1 and 5.4, optionally adding `--output ../bjarkiUI-0.2.351-Crown-Spacing.zip` to build a new archive outside the checkout.

There is no local WoW: Forever client. Fixtures establish the requested geometry under their explicit API model; the corrected crown optical gap and native animated Z appearance still need an in-game check. No live taint or frame-time claim is made.
