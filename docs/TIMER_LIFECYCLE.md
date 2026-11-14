# Timer lifecycle and diagnostics

This guide describes the **0.2.371-consistent-decimals-test** branch. It traces the displayed timer through its native writer, addon hook, typography preparation, ownership and cleanup. The former cast text-mirror mode is historical. Source/fixture checks are separate from live-client correctness. [Module map](CODE_MAP.md) · [Tests](TESTING.md) · [Open live reports](../KNOWN_ISSUES.md)

The .356 allocation cleanup keeps every existing permission and current-owner check. `NativeDigitCells` shares protected member-reader functions and a constant buff layout-hook list. Safe buff setup may reuse an unchanged typography record, but still resolves current glyphs and calls the formatter preparation path so failed preparation and changed profiles can recover at the same epochs. Timer ticks still perform no new font measurement or formatter construction.

## .363 current buff threshold

A fresh native source receipt enters the existing ownership-checked transaction. Public remaining time permits decimals only when `0 < time < 10`; a genuine native duration object performs the same threshold selection inside its formatter. Public temporary-enchant timing retains its existing path. The original 9.9 clamp and supported whole-number spacing remain.

The broad opaque seconds-only decimal fallback is removed. A native seconds-format receipt identifies only the below-90-second band. It cannot select a below-ten precision rule, so unsupported opaque timers retain the current native text even below ten. No new clock, widget or inferred duration is introduced. The existing whole-format helper remains available only to supported sources; its public calibration range is not live threshold authorization. In .366 it validates every 0.0–9.9 string actually emitted by its two clamped consumers. Unused 10.0–90.0 decimal geometry is no longer sampled; current font/fit, guard, complete column, failure-cache and safe-epoch checks remain.

Native object cache/retry changes and the final setter still yield to newer assignments and writes. Exact public context tokens identify owned native writes; bounded transient replay preserves newer formatted output. Public samples retain their readable recovery source. `threshold-unavailable` reports unsupported opaque seconds, while `duration-object` and `accepted-fixed` identify accepted supported paths. Live coverage remains separate from these receipts.

## Four distinct timer paths

| Surface | Source and native writer | Addon presentation | Ownership and fallback |
| --- | --- | --- | --- |
| Action/pet-action button | The original cooldown widget owns its assignment, timing, appearance and countdown policy. Compatibility cells obtain a native duration object from a publicly identified action/spell/book slot. | `ActionTimerSpacing` validates public full-string character geometry; `CooldownSeconds` confirms formatter installation on the original widget. `NativeDigitCells` retires owned cells for the accepted native route and retains native duration bindings as compatibility fallback. | Physical-widget preference follows exact installed formatter identity. Cell bindings and hidden-number ownership are retired only after safe handoff; refused restoration remains pending and later external writers keep ownership. |
| Player cast/channel | Blizzard `UpdateCastTimeText` keeps the original `PlayerCastingBarFrame.CastTimeText` current; opaque native `UnitCastingDuration`/`UnitChannelDuration` objects are available for the player. | `CastBarDigits` forwards the native duration object untouched to native text bindings that paint coherent rounded glyph tracks and full-format overflow. Geometry follows the current native font/style/scales; no Lua timer math or addon tick loop. | The native source text is **never cleared**. Hide it with an accepted alpha write only after bindings activate; always restore native alpha before clearing cells, retaining cells if restoration is refused. |
| Ordinary player buff/debuff | Native `UpdateDuration` writes the current `Duration`/`duration` label. | `BuffPresentation.afterDuration` selects public short-duration cells/guarded text or the public-identity duration formatter; unsupported opaque input stays stock. `NativeDigitCells` owns physical-label cells and stock recovery. | Physical owner, generation, assignment and writer/stock-text receipts govern takeover and recovery. Private, forbidden and unsupported selector paths retain native presentation. |
| Tracked buff icon | Native viewer items own cooldown widgets and duration rendering. | `TrackedBuffSeconds` sets the widget's native decimal threshold to 10. | Current viewer pass and current item/widget association prevent a recycled item from styling its former widget. No custom countdown clock. |

Action formatting is **tenths below 10**, whole seconds for **10 ≤ time < 91**, then rounded-up minutes. Thus 90.99 displays `90`, while 91 displays `2m`; hour/day rules remain native formatter rules. Cast cells preserve the native string's precision and locale. Public buff cells handle positive sub-ten-second samples; longer buffs retain native formatting. Do not copy the action thresholds into every timer route.

## Action countdown: prefer the original native widget

1. `CooldownSeconds.applyCooldownSeconds` discovers accessible action, pet, stance and related cooldown widgets out of combat. `ActionTimerSpacing.GetFixedActionFormatter` prepares bounded font/size/scale profiles from public sample strings, never the widget's protected current text.
2. The action formatter uses transparent spacing around numerals and validates complete standalone samples, including the prior equal-advance/plain path. The original font/flags, effective/text scales and smooth-scaling setting govern its profile. A successful initial `CalculateScreenAreaFromCharacterSpan` sample selects the character-rectangle route; inconsistent later metrics reject without switching routes. If that first sample is unusable, tabular fonts can use constant positive integer guards with independent repeated-digit, one-sided-growth, full-line and every-prefix/suffix width checks. Height and widget-fit checks apply to both. Character rectangles are selection geometry; scalar widths are limited by native metric resolution. Neither is optical ink or live rendering proof. The invariant is scoped to a digit-count/format family; native transitions such as `10.0` → `9.9` or `10m` → `9m` can move the centered group.
3. An accepted formatter write and exact public `GetCountdownFormatter` identity establish the physical widget's native preference. Ignored/refused writes and unreadable getters cannot establish it. Changes in font/scale or a later formatter writer invalidate stale preference.
4. `NativeDigitCells` restores only its own hidden-number state and confirms old binding shutdown before considering a handoff complete. Refused restoration or shutdown remains explicit and retries through existing lifecycle hooks. Native Clear, a changed clock or a changed physical owner invalidates old displayed cells even when restoration remains refused. A newer external visibility writer retains its decision.
5. Existing `InstallAction`, native update, minimum, Clear and preference-resume paths must not reacquire cells while the native preference is current. The preferred route performs no source color copying, custom minimum-gate calibration, duration-object lookup or clock arithmetic. The original widget owns those decisions.

The shared geometry probe and profile caches run at existing safe typography epochs, without per-button probe widgets or timer-tick measurement. Native configuration counts describe accepted receipts; they do not count running cooldowns or certify stable pixels. Successful scalar preparation records `last=fixed-widths` in the existing formatter diagnostics. Width failures can report `width-digits` or `measure`, and inconsistent complete sample families report `columns`. This route is separate from the unchanged individual glyph maps consumed by buffs and compatibility cells. [Original architecture](NATIVE_COUNTDOWN_0.2.360_PLAN.md) · [Width repair plan](superpowers/plans/2026-11-13-action-width-validation.md)

## Compatibility action cells: bind, observe, release

1. When no confirmed native fixed-spacing formatter owns the physical widget, `NativeDigitCells.InstallAction` may prepare the existing compatibility presenter. Pet spell-book resolution checks identity rather than accepting a convenient slot.
2. `prepareAction` reads the current source font/style, creates or refreshes cells, and configures native duration-to-text bindings. The bindings own their update interval and receive the opaque duration object directly.
3. Post-hooks on the native cooldown's `SetCooldown`, `Clear`, `SetHideCountdownNumbers` and minimum-duration setter observe the current native state. Epoch checks reject stale work if a setter triggers a newer update.
4. `setDuration` preserves native minimum/GCD policy. If public widget totals cannot establish eligibility, a complete synthetic native binding checks the supported duration/rate-to-color mapping before a native minimum gate can be used. A zero-duration probe or incomplete binding is not sufficient calibration.
5. `restoreStock` releases only the addon-owned hidden-number state. It reads back the native visibility flag and retains recovery state after refusal. A later native or external visibility writer releases the addon's previous claim.

Synthetic alpha calibration verifies accepted zero/one writes and exact, positively public numeric readback of those two values. Those are the only outputs of the Step scalar gate; an exact intermediate fraction is not a required capability. Failed endpoint checks retain stock. Native source color and the separate RealTime color gate keep their existing validation.

A failed current-style read records a public property stage (`label`, `font`, `source-scale`, `parent-scale`, `text-scale`, `relative-scale`, `text-color`, `shadow-color` or `shadow-offset`). That stage identifies the failed getter group, not whether the native value was missing, secret or refused. It does not permit guessing a font/color or reusing an unverified prior style. Diagnostics print only cached stage strings and add no native reads.

A first refused hide or post-hide readback retains a prepared stock fallback, just as a later clock refusal does. The next native cooldown update may retry without a safe rescan or new resources. Acquisition is rejected while an own visibility write is open; cleanup rechecks ownership after disabling bindings. A newer native/external visibility writer still releases the old claim. Fixed public diagnostics distinguish hide-write, hide-readback and pending-restoration stages. These stages identify the observed failure, not its client-specific cause.

Failed minimum-gate calibration is retried at safe login/world-entry/combat-exit boundaries; successful calibration remains cached. Every successful safe scan of a prepared action prepares its current positive-minimum/color gate before the active/idle fast return. A native minimum setter also prepares it out of combat, even on a zero clock. Changed colors are prepared after current-style resynchronization. Thus idle presentation cannot silently skip an existing safe retry and leave its first restricted combat update cold. Existing cells resynchronize native font/style rather than substituting a font. Countdown preference changes use the native visibility handoff; an off setting must not leave addon digits visible. Follow the current action test's recorded setters and displayed cells when investigating duplicate, blank or stale numbers.

## .371 compact decimal agreement

The independently validated whole-number buff profile is reused for action short decimal strings when the same native font, flags, size, effective scale, text scale and smooth mode supports it. The action builder still validates the complete output itself. A rejected compact profile retains the existing per-digit action guards; whole seconds and unit labels always retain those guards. Current widget/label fitting remains separate from cached font proof. The profile cache and shared probes remain bounded; successful reuse does not remeasure.

Action short output now explicitly rounds to the nearest tenth with the native rule engine and caps the result at 9.9. The raw ten-second threshold selects whole seconds; 91 continues to select rounded-up minutes. Genuine-duration buffs already use the nearest-tenth rule and a 9.9 cap. Public buff expiry still floors positive time at 0.1, while native-duration output can show 0.0 before expiry. This near-zero distinction and unsupported opaque buff fallback remain explicit.

Compatibility action/buff cells and casts share the same pure center-spacing helper. Raw numeral/point advances determine compact spacing; box padding cannot add a separate gap. The native font-size ceiling for overreported measurements remains. Native font roles and sizes remain surface-specific, so this is agreement in layout policy, not a forced single pixel size.

## Cast countdown: native duration bindings and current typography

The .371 presenter retains the native-duration strategy restored in .335 after the retired .334 text-mirror renderer caused a blank cast timer. Blizzard continues maintaining `CastTimeText`; the addon never clears its text.

At safe preparation, the player cast label's current font, size, flags, colors, shadow, effective scale relative to the cast bar, text scale and smooth mode define a style receipt. One reusable hidden probe measures unscaled public glyph advances. `NativeDigitCells.GetDecimalCellStep` supplies symmetric numeral/point spacing, with text scale applied once; padded receiving boxes are independent of those advances. Native style changes and existing lifecycle events refresh that receipt safely. No native text/remaining-time value is measured for geometry, and native binding ticks perform no typography work.

The localized `CAST_BAR_CAST_TIME` template supplies decimal punctuation and suffix, including an empty suffix. One- and two-integer-digit tracks retain fixed cells; a tenth native-bound full-format track displays overflow when the rounded value reaches 100. All digit components use the same native nearest-tenth rule before integer/modulo extraction. Public native-formatter probes verify carry and track handoffs before takeover. This is an explicit common nearest-tenth presentation policy, also used by supported actions and genuine-duration buffs; raw printf's independent exact-midpoint behavior is not the output authority.

`UnitCastingDuration('player')` and `UnitChannelDuration('player')` provide opaque native objects. They are forwarded unchanged to the native bindings at their existing 0.1-second cadence. Current ownership/style, Show Cast Time, native label visibility, binding acceptance and alpha handoff govern activation. Unsupported preparation retains the original text. Restoration of owned native alpha precedes retiring the replacement; refused or superseded native operations must not blank both presenters or overwrite a newer owner.

The focused fixture covers rounded output and range transitions, current fonts and non-unit scales, empty/localized suffixes, cast/channel transitions, no tick-time measurement, and refusal/recovery. These simulated checks do not prove live optical ink, protected-client behavior, empowered hold-at-max semantics, or in-client CPU cost. Existing `/buitimers` reports `cast=native-bindings` and `state=cells|stock` from cached presentation state without reading hidden clocks.

## Player auras: assignment, physical ownership and receipts

`BuffPresentation.setupButton` operates only on accessible ordinary buttons exposing `UpdateDuration`. Private anchor placeholders are excluded. It hooks the native method rather than adding another `OnUpdate`: the native aura code can replace or remove its update script when a slot becomes permanent or timed.

`Update` and `UpdateExpirationTime` invalidate the old duration object, assignment and saved text, and release old split digits. Edit Mode examples also retire the current custom presentation. A repeated aura ID alone is not proof that expiration, physical owner or assignment is unchanged.

After each native duration write, `showTenths` checks the current physical label, visibility/preference permission and `BuffBinding`:

- **Public short sample:** `ReadyBuff` confirms preparation and ownership, the original label text is captured/cleared, then `ShowBuff` writes the fixed tenth. A failed takeover restores a current native receipt or uses the native formatting sink.
- **Opaque seconds with a public native seconds selector:** exact ordinary-label text hooks retain only the public writer serial/selector receipt. The actual button's `afterDuration` callback consumes it and validates current label/parent/owner and native duration visibility. It forwards that call's opaque original seconds unchanged to a prepared localized one-decimal `SetFormattedText` sink. The native selector covers the entire below-90-second band, so this route intentionally cannot select decimals only below ten. Public short-cell handling remains separate. A later writer, nested update, stale owner, secret selector or refused sink cannot authorize a replay.
- **Restricted remaining time with public unit and aura-instance identity:** `GetAuraDuration` supplies an opaque native object. `FormatRemainingDuration` selects formatting using native time-modifier behavior. A safely prepared native-font formatter can supply fixed-width short decimal strings. Its result may itself be secret; it is forwarded unchanged to `SetText`, never parsed to build cells. Missing preparation keeps the ordinary formatter.
- **Secret, missing, invalid or inaccessible identity:** no guessed lookup or estimated duration is substituted. The native timer remains authoritative, and diagnostics describe the rejected identity stage without logging its value.
- **Temporary enchant:** a supported public expiration can supply the remaining time; inaccessible expiration remains native.
- **Hidden, permanent, replaced or inaccessible label:** release the addon's existing claim. An unknown visibility result is not automatically hidden; the restricted-visibility path separately checks the public `buffDurations` setting and never forces native visibility.

A saved `button.Duration` can point to a label now parented to another button. `BuffBinding` therefore tracks physical owner and owner generation; A → B → A is a new ownership period. `recoverForeignTimer`, `RestoreBuffStockReceipt` and assignment checks prevent an old alias or interrupted setter from repainting the new owner's timer.

Saved native text is a receipt for a specific owner and assignment, not an alternate clock. Failed reads use bounded retries through existing native updates. A receipt with no trustworthy age is discarded; ownership, assignment and public/hidden sample transitions retire stale text. A finite nested burst can schedule one deferred settlement, not an ongoing polling timer.

## The .334 unchanged-layout repair

Native code can perform this sequence in one update:

```text
AuraButtonMixin:OnUpdate
  → UpdateDuration(timeLeft)
      → native duration text
      → bjarkiUI afterDuration/showTenths
  → native SetFontObject(...)
  → native SetPoint(...)
```

The duration post-hook is therefore not the last native presentation write. The source label's layout setters mark the prepared geometry dirty and call `PrepareBuff`. In .333, an identical repeated anchor could take the combat-deferred rebuild path and retire valid fixed digits.

The .334 fast path reuses a complete prepared receipt only when:

- The label has the same accessible physical parent/icon and unchanged font path, size and flags.
- Preparation is ready and all three glyph anchors were completed (`anchored == 3`).
- The owner generation and saved layout receipt remain unchanged across inspection.
- The newly read public anchor, relative frame/point, offsets, effective-scale ratio and text scale exactly match that receipt.

It then clears layout dirtiness without issuing glyph geometry writes. This is reuse of an existing layout, not a combat-time rebuild. Changed font/owner/layout, denied reads and incomplete preparation retain the guarded restoration/native fallback path. Safe lifecycle setup can prepare the changed geometry later.

The 217-case [aura suite](../tests/aura-presentation.lua) includes **repeated native font and anchor writes preserve fixed buff digits in combat**. Its sequence models native `UpdateDuration` → `SetFontObject` → `SetPoint`, asserts fixed visible text and unchanged positions, counts geometry/font/parent setters, and verifies region reuse after combat. Companion cases retain actual-change, denial, partial-transfer and nested-write coverage. These checks do not establish the cause of live stuttering.

## Buff numeral glyph calibration (v0.2.341 test build)

An already-fixed FontString can still appear to wobble when the *visible ink* of narrow `1` and broad `8` is centered differently by Blizzard's proportional font. When `NativeDigitCells.layoutBuff` prepares a public, supported short-buff layout **out of combat**, it asks the previously implemented `ActionTimerSpacing.GetFixedTimerGlyphs` helper for optional font-specific, transparent-spacer glyph strings. The cache is bounded to 16 complete font/size/effective-scale/text-scale profiles. The mapping is attached to the existing physical buffer state and read only when writing its current integer and tenth; the decimal point remains native. No geometry setters, font measurements or timers run during the native per-frame duration update. A failed calibration leaves plain existing glyphs. A secret buff timer with no usable public identity remains under Blizzard's native formatting and may still show proportionally spaced text.

This is a source-grounded **possible fix for ink wobble** in existing public fixed digit cells, not proof of the cause of every live wobble report. Verify by watching a known readable buff transition between `1.x` and `8.x` and around the ten-second handoff in-game. Capture `/buitimers` before a reload for non-fixed/native fallback samples.

## Long readable buff text and fixed numeral advances

The existing isolated three-glyph buff timer covers supported public times *below 10 seconds*. At **10 seconds or more**, `BuffPresentation` previously returned to Blizzard's original centered, proportional FontString. Changing numeral ink widths can appear as wobble even with the underlying label anchored.

In v0.2.345, the existing `NativeDigitCells` prepared glyph map is also used for **positively readable** original stock timer strings. After Blizzard's current native `UpdateDuration` has written the string, `StabilizeBuffStockText` verifies its physical owner, unchanged preparation, public text and no active split digits; then it wraps ASCII numerals in validated transparent spacing. Existing unit suffixes, decimal punctuation, original font, positioning, alpha, duration source and update cadence remain unchanged. No independent timer, numeric duration conversion, new in-combat geometry, or hidden source label is added. Secret, markup-containing, forbidden and unsupported data stay untouched.

The tradeoff is an additional cosmetic native `SetText` for *each supported long-duration native refresh*; local tests cannot measure the WoW client's performance or pixel stability. The split fixed-digit path remains the native-public under-10s presenter. A transition between different display formats may still change overall string width; this build primarily stabilizes digit advances within a format.

## Action numeral ink alignment (v0.2.346)

The six action glyph cells already have fixed physical CENTER anchors, but `NativeDigitCells.buildFormatters` used proportional literal characters for four numeric tracks. v0.2.346 obtains the supported, currently native-font-width-calibrated glyph map from `ActionTimerSpacing.GetFixedTimerGlyphs`, then builds and validates four extra native numeric rule formatters with the same breakpoints and digits. These bind to the existing opaque duration objects, without Lua clock arithmetic or new update loops. The decimal separator and existing suffix formatter are unchanged. When style/scale changes, the presenter releases to Blizzard stock before switching its numeral formatter. A valid naturally tabular font retains its original formatters; unsupported or secret font reads and rejected formatter rules keep the existing native fallback.

The profile cache is bounded by the underlying glyph-map calibration cache; one set of native formatters is reused across similarly styled buttons. Offline formatting checks establish output equivalence and failure-to-native policy but **not in-client visual glyph centering or performance**.

## .355 typography coverage and recovery

The .354 native-duration buff route used plain `%.1f` even when the physical label already had a calibrated glyph map. The .355 route prepares optional native decimal rules from that map, leaving selection of the actual time/precision inside the native duration object. Formatting a secret duration does not grant permission to inspect its output. Existing ten-second and longer localized rules remain unchanged.

Buff typography is refreshed through existing safe setup even when the relative layout is already complete. A prior failed calibration can retry, and a changed absolute effective scale receives the correct map. This does not require moving the three cells when their relative geometry is unchanged. Current physical owner, preparation and profile still govern reuse; normal timer ticks do not remeasure fonts or construct new formatters.

Action cells now inherit the source label's scale relative to the cooldown widget and its native text scale. Those properties join the existing font/color/shadow style receipt. Scale-only changes use the same restore-stock-before-resync ordering as font changes. Rejected mapped numeral formatters retry once per existing safe typography epoch; successful results stay cached. These repairs do not loosen the native minimum-duration/GCD gate or establish the client-specific mapping used by its synthetic calibration.

## Reading /buitimers

The command reports cached outcomes plus read-only public coverage. It does not refresh the renderer, query an action/cast clock or expose secret aura values.

| Field | Meaning | Do not infer |
| --- | --- | --- |
| `native`, `fallback`, `last` | Cumulative changes in recorded aura-formatting outcome and last fallback reason. Repeated identical outcomes on one state are deduplicated. | Unique spell counts or proof that every displayed timer used that path. |
| `readable-writes` | Successful readable-duration formatting writes, including fixed and native-sink success. | Number of fixed-cell buffs. |
| `seconds-sink-accepted` | Accepted native formatted-text calls on a current verified ordinary owner using the public native seconds selector. | Public time reads, fixed buff columns, text readback or rendered proof. |
| `seconds-sink-last` | Cached public stage such as accepted, unreadable selector, native longer unit, stale writer or refused sink. | The opaque seconds, raw format/error payload, or a cause shared by every aura. |
| `visibility-restricted` | Observed bindings using the supported restricted-visibility permission path. | Hidden timers forced visible. |
| `hooked=N/M` | Successfully recorded duration hooks among currently accessible ordinary buttons exposing the native method. | Coverage of private/inaccessible slots. |
| `retry-pending`, `fallback-buttons` | Current accessible button states with a queued retry or recorded fallback. | Current spell identity or an all-clear after the button expires/recycles. |
| `private`, `inaccessible` | Skipped private anchors and inaccessible/blocked entries encountered by coverage inspection. | A bug merely because the count is nonzero. |
| `actions cells/stock/idle` | Cached prepared action states currently rendering cells, on fallback/restoration, or idle. | Full coverage of all native action widgets or a fresh live-clock measurement. |
| `native-format-configured` | Physical cooldown widgets with an accepted, read-back native formatter and completed retirement of any owned legacy presenter. Normal, charge and loss-of-control widgets are separate entries. | Running cooldowns, unique action buttons, or proof of stable visible pixels. |
| `native-handoff-pending` | A native formatter is requested/confirmed but owned visibility restoration or binding shutdown still needs recovery. | A completed transition or permission to keep stale digits after native Clear. |
| `minimum-read-denied` | Count includes both direct denied reads and unsupported native-gate fallbacks. Up to three button samples give the more precise reason. | That every count was the same failed getter. |
| `gate-unsupported/<stage>` | The recorded setup/binding failure, such as `probe-formatter`, `probe-mapping`, `probe-alpha-zero`, `probe-alpha-one`, `combat-cold` or a color-binding stage. | A confirmed root cause of visible motion or stuttering. |
| `hide-write-refused`, `hide-read-denied`, `hide-read-unavailable`, `hide-not-applied` | The own stock-hide write or confirmation failed after binding setup. An appended `restore-*` stage describes pending stock restoration. | That combat or a particular secret aspect caused the failure; stages contain no error payload. |
| `style-unavailable/<property>` | Current native style preparation failed at the named label/font/color/scale/shadow read. | The secret value, the exact engine reason, or permission to substitute cached/default appearance. |
| `zero-shutdown-refused`, `style-pending` | A public-zero presenter could not finish shutdown, or an already deferred style still needs a safe refresh after native Clear. | A live duration or proof of the underlying native refusal. |
| `typography profiles glyphs=... formats=... last=...` | Cached native-font preparation profiles. Individual glyph maps may be naturally tabular/plain; full action formatters require guarded complete-string validation. The last fixed public stage records where preparation stopped. No live timer/text is read and no calibration runs for this diagnostic. | Active displayed timers, accepted installation on every widget, a current per-buff route, or proof of rendered glyph stability. |
| `below/equal-minimum` | Native minimum policy prevented the fixed presenter. | An obligation to force a countdown visible. |
| `cast=fixed-cells setup=... last=...` | Current setup state and last recorded cast outcome, e.g. `ready`/`cells`, `native-format-unmatched` or `native-clear-refused`. | That a cast is currently active or pixels are correctly spaced at every scale. |

Aura identity reasons distinguish `aura ID secret`, `missing`, `invalid` and `inaccessible`, plus unsupported/missing units or info. A secret-ID fallback is deliberate native ownership; adding a spell-name allowlist would not repair the missing permission.

Capture exact output with addon/client version, surface, combat state and relevant setting. Keep an affected action/cast active during capture; aura counters can still help after a short aura expires. Capture borders with `/buiborders` before `/buiicons` or reload. Existing live reports remain open in [KNOWN_ISSUES.md](../KNOWN_ISSUES.md).
