# Verification — bjarkiUI 0.2.361-action-width-validation-test

## Result and live boundary

This is a focused action-formatter test build based on local .360 commit `30979c9a1f15d560a4ba51eacb1d98a2f1336ba0`. The full native Lua 5.1 and 5.4 release gates passed, and the installable archive passed manifest, membership, integrity and exact input-byte checks. No .361 in-game observation has occurred.

The user's follow-up after .360 delivery says “buffs seem good, action bar not yet.” The supplied capture visibly shows ordinary buff timers at `0.9 s` and `3.7 s`, with `seconds-sink-accepted=2040` and `seconds-sink-last=accepted`. This is positive evidence for the pictured buff scenarios. The .360 buff implementation is preserved byte for byte; its restricted seconds route still uses tenths throughout the native below-90-second band.

The same capture reports four unavailable action formatter profiles at `last=character-areas`, four plain individual-glyph profiles, `native-format-configured=0` and `native-handoff-pending=0`. No fixed native action formatter is recorded as configured. The screenshot does not show a bjarkiUI version line. The observed action movement remains open.

## Source evidence and diagnosed gap

The pinned [FontString API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) declares a nullable `CalculateScreenAreaFromCharacterSpan` result. It also exposes `GetUnboundedStringWidthForText`, `GetUnboundedStringWidth` and `GetStringWidth` for native scalar measurement.

The pinned [ScrollingMessageFrame](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua) uses the rectangle fields and local BOTTOMLEFT origin assumed by .360. No field-name or coordinate mismatch was established. Native documentation does not guarantee that a newly assigned, alpha-zero sample containing inline textures immediately returns usable per-character rectangles.

The aggregate failure stage cannot identify whether a call returned nothing, was inaccessible, returned unusable geometry, or later supplied inconsistent metrics. Alpha zero, markup indexing and deferred layout are possible explanations, not confirmed client causes. The confirmed architecture gap is making that selection query a mandatory preparation prerequisite even when independent public native width measurements can support the reported tabular fonts.

Native [TextureUtil](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXMLBase/TextureUtil.lua) generates integer texture dimensions. The new route uses integer guards and does not assume fractional inline-width parsing.

## Runtime change

Only ActionTimerSpacing.lua changes runtime behavior. Version labels change in bjarkiUI.lua and both TOCs. BuffPresentation.lua, CooldownSeconds.lua, NativeDigitCells.lua, the other runtime modules and the existing spacer texture are byte-identical to the delivered .360 package.

The first public character sample selects the validation route. If it supplies a usable rectangle, the existing character-area route remains authoritative; later inconsistent geometry cannot fall through to scalar acceptance.

If the first sample is unusable, the new route:

- Uses constant positive integer texture guards around all ten numerals.
- Checks single and eightfold repeated guarded numeral widths, plus actual one-sided and two-sided guard growth.
- Requires equal guarded advances at the native metric resolution.
- Validates the complete emitted timer and every corresponding complete prefix and suffix, including guarded repetitions, within each format family.
- Retains plain-versus-padded height checks, native widget/label fit, numeric rule validation, thresholds, bounded caches, safe retry epochs and probe cleanup.

An unavailable/secret width, ineffective guard, non-tabular advance, inconsistent column, changed height or insufficient widget width retains native fallback. The original native cooldown continues to own timing, color, font, visibility, minimum/GCD behavior and settings.

`last=fixed-widths` identifies accepted scalar preparation in existing typography diagnostics. The formatter is still installed only through .360's accepted setter and exact public getter identity receipt. `native-format-configured` counts physical configuration receipts, not running cooldowns or verified pixels; `cells=0` can be expected for that original-widget route.

## Verification performed

| Check | Result |
| --- | --- |
| Native Lua 5.1.5 | All 37 top-level suites passed; 16 runtime modules and current tests compiled through native loadfile. |
| Native Lua 5.4.6 | All 37 top-level suites passed; same compilation gate. |
| Aura regressions | Existing 249 cases passed under both interpreters; aura implementation unchanged. |
| New regression, before repair | Both interpreters rejected a tabular profile solely because character areas returned nil. Recorded RED logs. |
| New regression, after repair | Actual emitted formatter strings retain hand-derived numeral/punctuation columns and native spelling in the model. |
| Failure and recovery cases | Initial unusable rectangles, later contradictory metrics, integer-only tags, rounded widths, unequal repeated advances, restricted widths, ineffective guards, changed height, safe retry, narrow widgets and cache reuse exercised. |
| Existing action integration | Unchanged native handoff/ownership and cooldown suites passed as part of the full release gate. |
| Package | 19 members; integrity, exact source membership and input-byte verification passed. |
| .360 comparison | Exactly four changed package files: action spacing plus three version-label files. |
| Independent final review | No Critical or Important findings; suitable for a test ZIP after the full gate. |

Verification command:

```sh
python3 /workspace/scratch/56461e2d1ebd/verify_ui356_local.py --root /workspace/scratch/56461e2d1ebd/bjarkiUI-0.2.361 --log /workspace/scratch/56461e2d1ebd/ui361-evidence/final.log --output /workspace/scratch/56461e2d1ebd/deliverables/bjarkiUI-0.2.361-Action-Width-Validation.zip
```

Evidence is retained in `ui361-evidence/final.log`, `red-5.1.log`, `red-5.4.log`, `initial-area-red-5.1.log`, `initial-area-red-5.4.log` and `package_metadata.json` outside the checkout. [Payload source hashes](SOURCE_SHA256_0.2.361.txt) record the 19 packaged inputs.

## Performance and limits

The **Ultralight unit-frame presentation for WoW: Forever** wording is retained. This repair adds no polling loop, event frame, runtime module, dependency, user setting, per-button label or timer-tick measurement. It reuses the existing action probe and bounded profile caches.

The focused fixture records one character query, 1,246 scalar width calls and one formatter allocation for the first width profile. Fifty stable calls repeat no measurements or formatter allocations. These counts establish bounded preparation and cache behavior in the fixture, not native CPU cost. Repeated strings contain more text than single samples; fewer measurement calls alone would not prove faster preparation.

Scalar measurements operate at native metric resolution. Eightfold repetition exposes differences that a rounded single sample can conceal, but it cannot prove arbitrary subpixel equality or exact optical ink placement. Native format transitions such as 10.0 to 9.9 may still move the centered group. The requested in-game action stability, native first-profile latency, protected-client behavior and live frame time require client evidence.

**Deferred review minor:** the fixture provides GetUnboundedStringWidthForText. Its compatibility alternative using SetText plus GetStringWidth/GetUnboundedStringWidth is not separately covered. The target API documents the direct helper, and a refused/missing compatibility method remains a cached native fallback. No production failure was demonstrated.

## Package

- Filename: `bjarkiUI-0.2.361-Action-Width-Validation.zip`
- Archive size: **140,856 bytes**
- Expanded payload: **559,556 bytes**
- Runtime Lua: **557,424 bytes**
- Change versus .360: **+752 archive bytes; +3,177 runtime Lua bytes**
- SHA-256: `553d6c87a3839f1134d0f31216aa3a3b0442b96dca85b7deff8b030b8dbabd83`

The package contains the ordinary bjarkiUI addon folder. No tests, reports, saved variables or Edit Mode layouts are installed. The existing workflow is main-only; local test/package success must not be described as GitHub CI success.

