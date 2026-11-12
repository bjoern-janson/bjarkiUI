# Verification record for 0.2.350

Baseline: upstream `a1b5172cb1dca454187e25731b729d8218e5ed82` (0.2.349). All 88 restored source files were checked against their original Git blob hashes before edits.

## Local evidence

- All 36 current top-level suites passed on native Lua 5.1.5 and Lua 5.4.6, before and after the runtime change. Lua 5.1 uses the existing fixture compatibility preload.
- Runtime and test syntax was compiled through each native interpreter's `loadfile`; the local runner did not substitute an unrelated Lua version or claim a standalone luac invocation.
- Crown fixture: 9 scenarios per interpreter, including actual ClassicPartyPresentation/FrameLabelTweaks load ordering, mirrored anchors, effective-scale changes, native reanchors, refusals, combat, pooled release/reacquire, unknown raid permission and foreign-anchor exclusion.
- Resting fixture: 11 scenarios per interpreter, including opposite-side placement, full native texture clearance, mixed initial effective scales, native reset/refusal and combat deferral.
- One independent read-only reviewer inspected the runtime/test diff and ran both focused fixtures on both interpreters. No Critical, Important or Minor findings were reported.
- The regular installable ZIP contains 19 files: the same 16 runtime modules, both matching TOCs and the existing TimerSpacer media file. The existing package verifier checks membership, integrity and byte-for-byte equality to the validated inputs.

## Reproduce

Run `python3 tools/verify.py` with native Lua/luac 5.1 and 5.4. Add `--output ../bjarkiUI-0.2.350-Crowns-and-Rested.zip` for a new installable archive outside the checkout. The GitHub package workflow uses that native compiler/interpreter path.

## Evidence limits

No live WoW: Forever client was available here. Final optical placement, native animation clipping, taint and actual rendering remain unverified. Older timer and resting-scale behaviors outside this change were not re-audited. Positional mirroring is implemented; the original Z artwork is not reversed.
