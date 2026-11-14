# Verification — bjarkiUI 0.2.364-portrait-level-centers-test

## Requested layout

Center the Player level vertically just outside the portrait's left side, with Target and Focus mirrored on the right. Each label retains its single CENTER anchor and is attached to the portrait's LEFT or RIGHT midpoint, ten portrait units outward. Effective-scale conversion keeps that gap consistent when the level and portrait have different inherited scales.

Only the known native CENTER / LevelBackgroundCircle / CENTER attachment or an owned placement receipt is eligible. The addon does not clear anchors, stack constraints, rewrite the level text or change its native visibility. Native frame resets reapply the placement; scale refreshes recompute it; repeated unchanged geometry does not accumulate offsets. Unsupported geometry and combat lockdown retain the existing guarded behavior.

## Preserve the player combat glyph

The old combat glyph mirrored the visible Player level. Moving that level to the portrait midpoint would also raise the glyph beside the health bar. The new reference is the live native LevelBackgroundCircle center plus the old player label offset, (-4, -1.5) in label units. This retains the previous lower-corner position independently of the relocated number.

Native source pinned at `bebcb6bf309cf41b41bd74f8ca651e6a105b2676` confirms that Camelot initializes both level labels at CENTER / LevelBackgroundCircle / CENTER / 0, -0.5:

- [Camelot PlayerFrame_OnLoad](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UnitFrame/Camelot/PlayerFrame.lua)
- [Camelot TargetFrameMixin:OnLoad](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UnitFrame/Camelot/TargetFrame.lua)

If the circle becomes unavailable after a side-placement receipt, combat positioning pauses instead of using the moved number as its reference. It resumes when the native circle returns. The legacy live-label mirror is available only when no side-placement receipt exists. Native Target/Focus high-level skull positioning is unchanged.

## Verification

Final fixture and package results: **passed**.

| Check | Lua 5.1 | Lua 5.4 |
| --- | --- | --- |
| Frame label fixture | 40 passed, 0 failed | 40 passed, 0 failed |
| Combat reference fixture | 7 passed, 0 failed | 7 passed, 0 failed |
| Combat portrait attachment fixture | 8 passed, 0 failed | 8 passed, 0 failed |
| Full release gate | 37 suites passed; 16 runtime modules compiled | 37 suites passed; 16 runtime modules compiled |

Both runs use native interpreters. The case totals are unchanged; existing fixtures were migrated to the requested layout. Checks cover physical center geometry, inherited scales, unchanged-geometry idempotence, native resets, exact/binary32 receipts, setter/readback refusal, hook retries, combat deferral, foreign anchors and unavailable geometry. The missing-circle case verifies that the existing glyph stays untouched, a native glyph reset is not speculatively repaired, and restoring the circle permits recovery.

Existing geometry fixtures are updated for the requested layout and actual native circle attachment. Their rendered label centers follow accepted anchors, so a fixture cannot hide the combat-icon coupling by returning a fixed center unrelated to SetPoint.

The independent source review identified the missing-circle transition above; the guard was added and the reviewer approved the corrected scoped change. This is source review, not an in-game observation.

Release gate:

```sh
python3 /workspace/scratch/56461e2d1ebd/verify_ui356_local.py --root /workspace/scratch/56461e2d1ebd/bjarkiUI-0.2.363 --log /workspace/scratch/56461e2d1ebd/ui364-evidence/final.log --output /workspace/scratch/56461e2d1ebd/deliverables/bjarkiUI-0.2.364-Portrait-Level-Centers.zip
```

The existing isolated worktree directory is reused for the `.364` branch. Its directory name is not the packaged version. [Payload hashes](SOURCE_SHA256_0.2.364.txt) cover the 19 installable files; final publication identifiers are recorded in the external `ui364-evidence/` ledger after this snapshot is committed.

## Package

- File: `bjarkiUI-0.2.364-Portrait-Level-Centers.zip`
- SHA-256: `5229bdd53941d9d19ac93fc1c4a60f816f3c28f18cd44372d793575b982bf1d5`
- 19 files; 143,866 compressed bytes; 577,448 expanded bytes; 575,318 runtime Lua bytes.
- Archive integrity, exact payload/source byte equality and all 19 recorded source hashes passed.
- Compared with .363, only `FrameLabelTweaks.lua` and the three version-bearing files differ. Runtime Lua grows by 1,561 bytes; compressed ZIP grows by 287 bytes. All timer payloads retain .363 bytes.

## Limits

There is no .364 in-game observation yet. The source and fixtures establish portrait-relative center geometry; optical clearance at the user's UI scale remains a live check. The .363 timer behavior and all open restricted-buff/action-bar and performance reports remain unchanged.

The placement uses the existing safe frame lifecycle and SetPoint observers. It adds no frame timer, OnUpdate loop, polling ticker, setting, dependency or font. No client CPU/FPS claim is made.
