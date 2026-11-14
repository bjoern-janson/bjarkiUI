# Verification — bjarkiUI 0.2.363-buff-ten-second-threshold-test

## Finding and correction

The latest screenshot shows a buff timer at `66.2`, without a build/version line. The .362 source directly permits this: when the timer number is opaque and no genuine native duration object is available, its seconds-only fallback forwards that number into `%.1f` across the native below-90-second band. This was an implementation compromise and does not meet the user's decimals-below-ten requirement.

.363 removes that numeric fallback. Supported public short timers, public temporary-enchant timing and genuine duration objects retain their existing below-ten rules, 9.9 clamp and prepared spacing. Unsupported opaque timers retain the current native text at all durations, including below ten. This closes the over-ten decimal source defect without claiming complete restricted-buff decimal or spacing coverage.

Only BuffPresentation.lua changes runtime behavior; bjarkiUI.lua and both manifests change version identifiers. ActionTimerSpacing.lua, NativeDigitCells.lua and all other presentation modules retain .362 bytes. No new timing source, clock, ticker, widget, dependency, setting or native font change is introduced. The whole-format helper remains prepared over its existing public sample range; that range is not authorization to format unknown live values.

## Why the native fallback cannot select the threshold

The inspected API source is pinned at `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`:

- [FontString SetFormattedText](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) permits the opaque value in a native text sink, but the public format string supplies no conditional below-ten rule.
- [Duration text bindings](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/DurationTextBindingObjectAPIDocumentation.lua) require a genuine LuaDurationObject; they do not accept an arbitrary opaque scalar as their duration input.
- [Cooldown setters](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua) restrict secret scalar arguments to untainted callers. Creating another cooldown widget would not authorize forwarding an opaque remaining/expiration number from addon code.

The ordinary buff button carries scalar timing fields rather than a genuine duration object. The existing public-identity duration API remains the supported object source. No private aura container, hidden identity or timing signal is inferred. The optional public-expiration calculation is not added to this focused correction.

## Behavior matrix

| Current source | 9.999 seconds | 10 seconds | 66.2 seconds | 90 seconds |
| --- | --- | --- | --- | --- |
| Public numeric remainder | `9.9` | Native `10 s` | Native `66 s` | Native `2 m` |
| Genuine native duration object | `9.9` | Native `10 s` | Native `66 s` | Native `2 m` |
| Opaque remainder with no usable object | Native `9 s` | Native `10 s` | Native `66 s` | Native `2 m` |

English fixture spelling is shown; native unit labels remain localized. Unsupported opaque sources are not counted as successful decimal writes. The existing diagnostic reports `threshold-unavailable` for that seconds case.

## Verification

Final fixture, independent review and package results: **passed**.

| Check | Result |
| --- | --- |
| Final aura fixtures against unchanged .362, Lua 5.4 | 260 passed, 11 expected failures, exit 1 |
| Corrected .363 aura fixtures, Lua 5.1 | 271 passed, 0 failed, exit 0 |
| Corrected .363 aura fixtures, Lua 5.4 | 271 passed, 0 failed, exit 0 |
| Full release gate, Lua 5.1 and Lua 5.4 | All 37 suites passed on each interpreter; all 16 runtime modules compiled |
| Independent source and fixture review | Approved; no Critical or Important findings |
| Installable archive | 19 files; every payload byte matches the verified source; archive integrity and source SHA-256 checks passed |

The RED run includes the screenshot regression: expected `66 s`, actual `66.2`. All four older-supported/newer-unsupported ordering cases also fail on .362 and pass on .363. Four threshold source matrices cover public fixed cells, public guarded formatting, genuine native duration objects and unsupported opaque values at 9.999, 10, 66.2 and 90 seconds.

Formerly active fallback tests remain meaningful: native sink refusal, newer writes, physical transfers and bounded contexts use supported public or native-object sources. Explicit callback counts, refusal counts advancing from one to two and 50 actual supported writes prevent those tests from passing through an unreachable setter. The four mixed-order cases require a newer unsupported `66 s` both immediately and after an older supported decimal setter completes, with zero addon sink writes for the unsupported value.

Release command:

```sh
python3 /workspace/scratch/56461e2d1ebd/verify_ui356_local.py --root /workspace/scratch/56461e2d1ebd/bjarkiUI-0.2.363 --log /workspace/scratch/56461e2d1ebd/ui363-evidence/final.log --output /workspace/scratch/56461e2d1ebd/deliverables/bjarkiUI-0.2.363-Buff-Ten-Second-Threshold.zip
```

Evidence is retained in `ui363-evidence/` outside the checkout. [Payload SHA-256 values](SOURCE_SHA256_0.2.363.txt) cover the exact 19 installable inputs. The stacked draft does not imply a main merge or a successful main-only CI run.

## Package

- File: `bjarkiUI-0.2.363-Buff-Ten-Second-Threshold.zip`
- SHA-256: `389a57c1c2532fb48afb9d34b3cd4ee962939ece87f90390d3aa9274fc170701`
- Compressed: 143,579 bytes; expanded: 575,893 bytes; runtime Lua: 573,757 bytes.
- Relative to .362: 168 fewer compressed bytes and 635 fewer runtime Lua bytes.
- Changed payloads: `BuffPresentation.lua`, `bjarkiUI.lua`, `bjarkiUI.toc` and `bjarkiUI_Camelot.toc`. The latter three only update the version.

The final publication and artifact-save identifiers are recorded in the external release ledger after this source snapshot is committed.

## Live and performance limits

There is no .363 in-game observation yet. Unsupported short buffs can still show whole seconds and an `s`, and their native font may still move. Action-bar stability remains a separate open live report. This release deliberately does not claim universal timer success.

The source correction removes an addon formatting write from unsupported timer updates and adds no new ongoing work. The existing Ultralight wording remains architectural; there is no new client CPU, FPS or preparation-latency measurement.
