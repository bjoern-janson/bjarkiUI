# Verification and live evidence for 0.2.360

Date: 2026-11-13. Build: **0.2.360-native-countdown-format-test**.

## Result and limits

This action-timer repair changes the preferred presenter: the original native cooldown receives a fixed-spacing formatter when complete public sample geometry and exact installation identity are confirmed. The original widget continues to own timing, current appearance and eligibility. Compatibility cells remain available when native formatting cannot be accepted.

The user's latest capture is still a failed visual result. Neither the earlier alpha correction nor its passing fixtures establishes that the user's timers work. This package has no in-game verification. Native character-selection rectangles can verify public sample positions; the API does not promise optical ink bounds or prove the live countdown renderer uses every probe behavior identically. The live action movement report remains open.

The buff change uses a smaller in-place route than a replacement row: a positively public native seconds selector permits opaque seconds to pass unchanged to a one-decimal native text sink. This covers the native seconds band below 90 seconds, rather than conditional below-ten formatting. Existing rows and longer units remain. Selector availability and native sink behavior still require client evidence; accepted writes are not rendered proof. The [replacement-row proposal](NATIVE_BUFF_ROW_REPLACEMENT_PROPOSAL.md) remains an unimplemented alternative.

Baseline: .359 local commit `ce468501285f5f1a216db8a5ac9c8d82568a4f0d`, remote commit `9fd5fc8d5942ae0d365876928f4844b054f8b059`, identical tree `6e7402b13e08185c762db1428d326d1841509ae5`. Runtime behavior work is confined to `ActionTimerSpacing.lua`, `CooldownSeconds.lua`, `NativeDigitCells.lua` and `BuffPresentation.lua`; main and the manifests receive version updates. There are still 16 runtime modules.

## Latest live evidence

The capture supplied after .359 delivery contains:

```text
aura native=0 fallback=3 last=aura ID secret readable-writes=0
visibility-restricted=0 retries=0 hooked=48/48 retry-pending=0
fallback-buttons=3 private=6 inaccessible=0
actions cells=0 stock=13 idle=84 minimum-read-denied=11 below/equal-minimum=0
[MultiBarBottomLeftButton1:gate-unsupported/scalar-threshold,
 MultiBarRightButton10:style-unavailable/text-color,
 MultiBarRightButton1:gate-unsupported/scalar-threshold]
cast=native-bindings state=stock setting=on
glyphs=fixed:0/plain:4/unavailable:0 last=plain
formats=fixed:0/plain:4/unavailable:0 last=plain
```

The short ordinary buff reads `6 s`. The screenshot contains a bjarkiCC startup version, not bjarkiUI's version line; the order of delivery and feedback is not an independent installed-version receipt. The idle count is not a count of failed active cooldowns. The last aura fallback cannot be assigned separately to every pictured aura.

The action capture reaches two separate restrictions in the replacement presenter: exact synthetic threshold validation and unavailable source text color. The current Step-curve documentation does not certify the adjacent-breakpoint behavior assumed by the fixture. No epsilon change is presented as the repair. The original countdown widget already owns native eligibility and appearance, so the preferred route leaves those decisions there. [Plan and scope](NATIVE_COUNTDOWN_0.2.360_PLAN.md)

## Native API basis

Primary source was checked against Forever `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`:

- [FontString API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) declares `CalculateScreenAreaFromCharacterSpan` with public-text access requirements and nullable rectangle results. It also documents smooth-scaling behavior that can affect scaled font metrics.
- [Native selection caller](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/ScrollingMessageFrame.lua) uses original string indices and exclusive right endpoints, positioning each returned rectangle from the FontString's BOTTOMLEFT. This is evidence for character-selection coordinates, not a promise of optical ink geometry.
- [Cooldown API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua) provides native formatter setters and a nullable formatter getter. Exact readback can confirm the requested object on the physical cooldown.
- [Duration binding API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/DurationTextBindingObjectAPIDocumentation.lua) provides `IsEnabled`, allowing an existing binding's shutdown to be confirmed rather than inferred from a void setter.

No protected current timer text, hidden aura identity, secret duration arithmetic or source RGBA is needed by the accepted native action route. Public sample geometry is prepared at safe epochs.

For buffs, [native UpdateDuration](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua) calls `Duration:SetFormattedText(SecondsToTimeAbbrev(timeLeft))`. [SecondsToTimeAbbrev](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/TimeUtil.lua) returns the original seconds in its seconds band; it only converts values on the longer-unit branches. The FontString API explicitly permits opaque arguments at the formatted-text sink. Source does not prove the selected format becomes secret, so the earlier absence of a conditional duration delegate must not be generalized to every in-place formatting route.

The smaller route can act only when the actual selector is positively public and matches the localized seconds format. It does not infer that selector from hidden time or recover a secret aura ID. The strict below-ten-only delegate remains unavailable on this legacy label; the larger native aura delegate belongs to a separate native-owned assignment. [Earlier buff design evidence](NATIVE_BUFF_ROW_DESIGN.md)

## Action regression evidence

The formatter fixture first reproduced equal sampled advances with moving standalone centered numeral and decimal positions. Its native-layout model distinguishes advance, side bearings, pair kerning, whole-line bounds, inline texture placement and rounding. The new formatter checks byte-indexed character-selection rectangles and complete widths within each matching digit-count/format family. The fixture asserts positions against independently hand-calculated columns, including the previously unchanged tabular path. This is a model of native behavior, not a capture of the user's font rasterizer.

One shared action sample FontString is configured with the source font, flags, effective scale, text scale and smooth-scaling mode. It is shown only after zero alpha is confirmed, then hidden and cleared on success or failure. Actual positive native probe bounds form the coordinate basis; arbitrary requested bounds are not required to round-trip exactly. The original glyph-map probe and buff/cell glyph outputs remain separate. Missing, secret, invalid, multiline or clipped character geometry cannot earn a fixed formatter receipt. Narrow widgets retain their fitting native formatter.

Guarded output also exposed an existing validation gap at the 99-day dynamic-rule boundary: native binary32 input rounding can select that rule for a public double just below the Lua cutoff. A temporary public marker on the same candidate identifies native dynamic-range membership. The final original dynamic day rule is then installed, and every sampled result is checked again against its appropriate literal or original native output. This adds no second formatter object, native precision assumption or broad acceptance of plain output.

Focused formatter runs pass on native Lua 5.1 and 5.4. The first synthetic profile performs **1,008 character-span calls**, **374 complete-line width calls** and **one formatter allocation**. There is one bounded candidate map. Repeated stable cache calls add zero measurements or formatter allocations. Full action profiles remain limited to 32 per base formatter and individual glyph profiles to 16. These are fixture call counts, not native execution timings or client memory measurements.

The integration regressions cover an accepted-but-ignored void formatter setter, refusal after application, unavailable/read-restricted getters, observer failure, external formatter replacement and reentrant newer receipts. The native route avoids source RGBA, minimum-policy reconstruction, duration lookup and replacement cell allocation. Existing ownership tests now also cover pending restoration across native Clear, a newer cooldown, changed physical owner/action, ignored binding shutdown, native preferences and later visibility writers. `IsEnabled` readback and owned-label hiding prevent invalid old bindings from repainting stale digits while restoration still refuses.

At the focused integration checkpoint, both native Lua versions pass **6,524 native-cell assertions** and **132 cooldown assertions**. Independent formatter review found no blocking issue. These numbers establish fixture outcomes only; final package results are recorded separately below.

## Buff regression evidence and ownership

The new actual-module cases first reproduced the missing decimals with a secret aura ID, opaque remaining seconds and no aura-duration API. The native-sink fixture now displays `2.8 s` from the unchanged opaque `2.83` argument, with zero aura lookup requests. It also verifies the deliberate whole-seconds-band policy with `14.3 s` and `89.4 s`. Native minutes, hours and days keep their formats; current public short-duration cells and public-expiry enchant cells retain their existing path.

Only a positively public exact native seconds selector can authorize the new sink. Preparation preserves the localized literal suffix/spacing around one supported integer conversion, declining ambiguous conversions. Secret selectors, hidden durations, examples, no-write updates, assignment changes, label replacement and multiple pending native source writes cannot authorize an old callback's seconds. A count of pending public source writes resolves same-format ambiguity without comparing opaque arguments.

Review found and reproduced transition defects before the final repair: handled fallback paths could leave previous split cells visible, a stale alias could bypass physical-owner recovery, and a label transfer during an older sink could overwrite its new owner's text. The final route runs after the existing binding ownership check, retires only owned cells, and rechecks current binding owner/generation after the sink before capturing stock. Existing formatted-text stock receipts recover the current owner. Newer native updates survive older sink writes and split clears returning last.

The new route retains no raw seconds. Two reusable per-button context records handle bounded reentrancy; transient formatted output can be forwarded unchanged to its supported native text sink, and is cleared when the outer write ends. A repeated-write case checks context reuse and cleanup. The existing stock-recovery receipt retains only appropriately owned formatted output for this route. Secret or refused setter results produce fixed public stages without comparing or logging their payloads.

The final focused aura suite reports **249 passed, zero failed** on each native Lua version, up from 226 baseline cases. `seconds-sink-accepted` counts accepted native calls, not text readback or rendered success; `seconds-sink-last` describes only the cached public stage. A secret selector or unsupported native sink can still leave a live buff on its original presentation.

## Performance scope

The exact **“Ultralight unit-frame presentation for WoW: Forever”** description is retained. There is no added polling loop, ticker, event frame, runtime module, dependency or user setting. Accepted native action formatting avoids allocating replacement cells/bindings for those widgets. Geometry uses one additional shared action probe and bounded preparation caches; it performs no timer-tick measurements.

The buff route is not free: eligible native seconds updates receive one additional cosmetic formatted-text write and associated observer work. The pinned native `AuraButtonMixin:OnUpdate` calls `UpdateDuration` at the native frame-update cadence, so this is not a ten-Hz throttle. Reused contexts avoid adding a Lua table allocation to each sink call. These source/fixture facts support the narrow presentation architecture; they do not establish client FPS, native formatter CPU cost, startup latency or memory. The [.356 comparison](VERIFICATION_0.2.356.md) remains historical rather than a new benchmark for this build.

## Final package evidence

| Check | Result |
| --- | --- |
| Native Lua 5.1.5 | All 37 top-level scripts pass; all 16 runtime modules and test sources compile. |
| Native Lua 5.4.6 | All 37 top-level scripts pass with the same compilation checks. |
| Action formatter fixture | Complete-string geometry, exact numeric output, dynamic boundary, cleanup, fit and cache assertions pass on both interpreters. |
| Action integration fixtures | 6,524 native-cell assertions and 132 cooldown assertions pass on each interpreter. |
| Aura fixture | 249 cases pass on each interpreter, including the 23 added native-seconds and ownership regressions. |
| Independent reviews | Final action formatter, native handoff and buff source/ownership reviews report no remaining material blocker. |
| Archive/source checks | Matching manifest version/load order, exact 19-file membership, integrity and byte equality pass. |

`git diff --check` is clean. The established adapter uses native `loadfile` for compilation because standalone `luac` is unavailable, and the repository verifier's manifest/package functions. These are local results; the stacked draft does not run the workflow restricted to main. Counts describe fixture coverage rather than a percentage of client behavior. See [testing commands](TESTING.md) and the [packaged source manifest](SOURCE_SHA256_0.2.360.txt).

`bjarkiUI-0.2.360-Native-Countdown-Format.zip` contains one installable `bjarkiUI/` folder with 19 files: 16 Lua modules, two matching manifests and the existing spacer texture. Archive size: **140,104 bytes**. Expanded size: **556,379 bytes**; runtime Lua source: **554,247 bytes**. These sizes are not runtime memory.

SHA256: `c0251f9c1cfd750c3c2c83914c4a2740a10696637ab447aeb39b109121ed12ec`.

Compared with the .359 package, the archive adds 5,923 bytes and runtime Lua adds 28,584 bytes. That change does not establish CPU or memory growth in the native client. Tests and reports are excluded from the installable ZIP. No in-game test or performance measurement occurred during this verification; the [live issues](../KNOWN_ISSUES.md) remain open.
