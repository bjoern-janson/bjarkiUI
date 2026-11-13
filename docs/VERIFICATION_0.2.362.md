# Verification — bjarkiUI 0.2.362-buff-format-consistency-test

## Scope and observed failure

This test build continues from local .361 commit `15b81543ef1bee48cdc481c44af1cc37f7e36dd2` and remote .361 tree `48fc49cdc2ab2c8bc228d4df677cb013d9f2ec01`. The latest user report says buffs sometimes wiggle and sometimes show a seconds suffix. That limits the earlier positive .360 screenshot to its pictured cases. There is no .362 client observation, and .361 action stability has not received a new live result.

The actual .361 modules reproduce three different presentations on one unchanged physical label: public `3.7` in fixed cells, opaque `3.6 s` as a whole native string without the prepared spacing, then public `3.5` in cells. The seconds sink also intercepts the supported calibrated duration-object route when a public aura identity is available. These are confirmed source/fixture defects; they do not establish every cause of the user's live motion.

## Native API boundary

The inspected source snapshot is `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`:

- [NumericFormatter](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericFormatterAPIDocumentation.lua) does not authorize addon `FormatNumber(opaqueTime)`; its secret-argument contract is AllowedWhenUntainted.
- [UnitAura](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) requires permitted aura access and a valid aura instance for GetAuraDuration. No hidden identity is inferred or decoded.
- [LuaDurationObject](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/LuaDurationObjectAPIDocumentation.lua) supports formatting a genuine object's remaining duration. Restricted numeric setters do not authorize fabricating an object from opaque seconds.
- [FontString](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) exposes the supported opaque text sinks, public sample metrics, nullable character areas, and variadic SetFormattedText arguments. The exact unused-public-vararg sink shapes are additionally prepared against native public output, independently of font geometry.

## Runtime changes

Only `ActionTimerSpacing.lua` and `BuffPresentation.lua` change runtime behavior. Version identifiers also change in `bjarkiUI.lua` and both manifests. Existing action formatter construction, action/cast integration, individual glyph mapping, other presentation modules and the spacer asset retain .361 behavior.

Within a fresh current source transaction, the buff renderer first attempts a genuine native duration object using a public identity. Its opaque formatted result goes to the native `%s` sink. Object/cache/backoff changes yield to a newer assignment or writer, including an assignment that reuses the same aura ID. The fallback no longer discards native object retry state.

If the original opaque seconds are the only usable source, the exact positively public native seconds selector permits bare `%.1f`. This removes the decimal seconds suffix but retains .360's precision band below 90 seconds. It does not make a secret below-ten comparison possible. Public and genuine-object precision still uses decimals below ten, including the existing 9.9 clamp; larger native unit formats remain intact. An unreadable selector with no usable object stays native and can still show `s`.

The current sink call carries one preallocated public context token as an unused vararg. An exact format alone is insufficient to identify ownership: another writer can also use `%s`. The recorder recognizes an owned sink only with the current public token and format. Other formatted writes contribute only their completed native text to bounded in-flight replay. Generic SetText remains a later writer. No original opaque countdown value is retained. Public short samples retain their existing readable recovery source if native GetText is refused.

The optional whole-number spacing format uses constant integer transparent guards at its outside edges. It validates actual native public printf output from 0.0 through 90.0, unchanged and unclipped heights, all-digit guard growth, complete widths, and every character position. If the initial character query is unusable, independent guarded/repeated prefix and suffix widths validate internal columns. A successful first character rectangle commits to that route; later contradictions cannot switch to scalar acceptance.

This helper rejects proportional advances and variable interior kerning. It uses the existing shared probe and a separate 16-profile cache; the profile includes native font, effective/text scale and smooth scaling. Use checks also revalidate current label fit. A supported short public/object/opaque sample can retain the same original label. An unavailable, stale or refused profile keeps the established cell/plain fallback.

## Verification evidence

Focused native Lua 5.1.5 and 5.4.6 runs pass all **263 aura cases** and the action/buff spacing suite. The initial route regressions failed before repair. Review-generated regressions separately failed for an equal-but-clipped sample, an unowned newer `%s` write, and public recovery when GetText is denied; all now pass.

The regression matrix includes mixed readability, native font/anchor setters after the timer update, combat reuse, public and opaque thresholds, larger units, public-identity coexistence, duration retry/recovery, same-ID nested assignment, stale getters/formatters, sink completion in both orders, physical owner transfer, generic later text, unsupported call contracts, guarded geometry rejection and safe retries. Existing ownership/handoff suites remain required release gates.

| Final release check | Result |
| --- | --- |
| Native Lua 5.1.5 | All 37 suites passed; 16 runtime modules and current tests compiled through native loadfile. |
| Native Lua 5.4.6 | All 37 suites passed with the same compilation gate. |
| Aura cases | 263 passed, 0 failed on each runtime. |
| Independent review | Both Important findings corrected and independently rechecked; no remaining Critical/Important finding. |
| ZIP | 19 files; integrity, manifest membership and exact source-byte checks passed. |
| Changed payloads from .361 | ActionTimerSpacing.lua, BuffPresentation.lua and the three version-label files only. |

Package: `bjarkiUI-0.2.362-Buff-Format-Consistency.zip`, **143,747 bytes** compressed and **576,524 bytes** expanded. Runtime Lua totals **574,392 bytes**. Relative to .361 this adds 2,891 archive bytes and 16,968 runtime Lua bytes, with no extra packaged member.

SHA-256: `c3b84a2dde4fe5d5947ba6419d0ddc78f7e82a766406ce7dab136f643a0ce14d`.

```sh
python3 /workspace/scratch/56461e2d1ebd/verify_ui356_local.py --root /workspace/scratch/56461e2d1ebd/bjarkiUI-0.2.362 --log /workspace/scratch/56461e2d1ebd/ui362-evidence/final.log --output /workspace/scratch/56461e2d1ebd/deliverables/bjarkiUI-0.2.362-Buff-Format-Consistency.zip
```

Evidence logs are retained under `ui362-evidence/` outside the checkout. [Packaged source hashes](SOURCE_SHA256_0.2.362.txt) describe the exact 19 inputs. The stacked draft is not a main merge and does not trigger the workflow restricted to main.

## Performance and live limits

The **Ultralight unit-frame presentation for WoW: Forever** wording remains an architectural description. This repair adds no ticker, polling loop, event frame, runtime module, dependency, setting, asset or per-button text widget. It reuses the existing native update, shared probe, safe epochs and bounded contexts/caches. Stable profile calls perform no geometry sampling or formatter allocation. Initial whole-format preparation does exercise 901 public numeric samples, and current-profile/ownership reads still occur during native updates.

No client CPU, frame-time, memory trace or preparation-latency measurement was performed. Scalar widths are limited to native metric resolution; repeated contexts cannot prove arbitrary subpixel equality. Character rectangles represent selection geometry, not exact optical ink. Ordinary digit-count/format transitions can reposition the centered group. A valid native write or prepared font profile does not close the user's live buff/action reports.

Diagnostics expose `buff-seconds=fixed:N/unavailable:N last=...` for cached geometry preparation and `seconds-sink-last=duration-object`, `accepted-fixed`, or `accepted-plain` for the latest accepted route. These are not counts of current timers or claims of stable live pixels.
