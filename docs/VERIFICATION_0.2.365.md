# Verification — bjarkiUI 0.2.365-default-level-badges-test

## Requested result

Restore the Player, Target and Focus level backgrounds/borders in their **default native lower-corner positions**. The user wants to inspect those locations before deciding whether to move bjarkiPortraits secondary portraits there. The .364 side-centered level numbers stay in place; this change does not relocate a secondary portrait or reanchor the backgrounds behind the numbers.

## Implementation

Remove the `hiddenLevelRings` suppression block from bjarkiUI.lua and its seven `applyPlainLevelRings()` lifecycle calls. This retires the ring Hide/zero-alpha writes and the Show/SetShown/SetAlpha post-hooks. Native initialization owns these existing textures again after reload; no replacement artwork, forced visibility hook or extra UI region is introduced.

The pinned Camelot [PlayerFrame_OnLoad](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UnitFrame/Camelot/PlayerFrame.lua) and [TargetFrameMixin:OnLoad](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UnitFrame/Camelot/TargetFrame.lua) both show the native LevelBackgroundCircle. The [Player XML](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UnitFrame/Mainline/PlayerFrame.xml) and [Target XML](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml) retain their original bottom-corner anchors. No anchor or atlas setter is added by .365.

FrameLabelTweaks.lua retains .364 bytes, including the portrait-side number positions and the combat glyph's native-circle reference. Other timer and presentation modules are unchanged. The only runtime behavior change is removal of the suppression policy; the two manifests also receive version updates.

## Verification

Final release results: **passed**.

| Check | Result |
| --- | --- |
| Native Lua 5.1 | All 36 suites passed; 16 runtime modules compiled |
| Native Lua 5.4 | All 36 suites passed; 16 runtime modules compiled |
| Source review | Suppression block and all seven callers removed; no active references remain |
| Installable ZIP | 19 files; integrity, exact-source byte comparison and all payload hashes passed |

The existing frame-label (40 cases), combat-reference (7 cases) and combat-portrait attachment (8 cases) suites remain in the full gate and pass on each interpreter. The aura suite still contains 271 cases. These results do not establish live client rendering.

The old 13-case `level-ring-suppression.lua` suite required the backgrounds to stay hidden, the behavior expressly reversed by this request. It is retired, and its unused stub is removed from the isolated status-scale fixture. The current release therefore has 36 suites (35 behavioral plus manifest syntax), with the existing level-placement and combat-reference tests retained. No artificial replacement assertions are added merely to preserve a suite count.

Release command:

```sh
python3 /workspace/scratch/56461e2d1ebd/verify_ui356_local.py --root /workspace/scratch/56461e2d1ebd/bjarkiUI-0.2.363 --log /workspace/scratch/56461e2d1ebd/ui365-evidence/final.log --output /workspace/scratch/56461e2d1ebd/deliverables/bjarkiUI-0.2.365-Default-Level-Badges.zip
```

The existing worktree is reused on the `.365` branch. [Source hashes](SOURCE_SHA256_0.2.365.txt) cover all 19 installable payloads. Publication identifiers are recorded in the external `ui365-evidence/` ledger after this source snapshot is committed.

## Package

- File: `bjarkiUI-0.2.365-Default-Level-Badges.zip`
- SHA-256: `d87c109ddf47518c015cae6fc3e045b0db885b46eff298b52070197c38f0d75d`
- Compressed: 143,219 bytes; expanded: 574,412 bytes; runtime Lua: 572,286 bytes.
- Compared with .364: 647 fewer compressed bytes and 3,032 fewer runtime Lua bytes.
- Only `bjarkiUI.lua` and the two version-bearing manifests differ. FrameLabelTweaks.lua and every timer module retain exact .364 payload bytes.

## Live and performance limits

No .365 in-game observation is recorded yet. Install the package and reload the UI so the old runtime suppression hooks are gone and native frames initialize afresh. The restored native badge locations can then be judged for a possible later bjarkiPortraits change.

The change removes lifecycle work and adds no timer, polling, hook, setting, dependency or UI widget. It does not establish a client CPU/FPS result or close the existing timer and performance reports.
