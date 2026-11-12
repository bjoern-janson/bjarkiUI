# Timer lifecycle and diagnostics

This guide describes the **0.2.355-timer-spacing-recovery-test** branch. It traces the displayed timer through its native writer, addon hook, typography preparation, ownership and cleanup. The former cast text-mirror mode is historical. Source/fixture checks are separate from live-client correctness. [Module map](CODE_MAP.md) · [Tests](TESTING.md) · [Open live reports](../KNOWN_ISSUES.md)

## Four distinct timer paths

| Surface | Source and native writer | Addon presentation | Ownership and fallback |
| --- | --- | --- | --- |
| Action/pet-action button | Publicly identified action/spell/book slot → native cooldown duration object. The cooldown widget owns its swipe, timing and countdown policy. | `CooldownSeconds` installs native formatting; `NativeDigitCells` feeds the duration object to native text bindings for fixed glyph cells. `ActionTimerSpacing` measures the current font for cells and the native fallback formatter. | Per-button/widget state tracks binding epoch, cell readiness, native hidden-number ownership and restoration. Failed or unsupported fixed rendering returns the native countdown where permitted. |
| Player cast/channel | Blizzard `UpdateCastTimeText` keeps the original `PlayerCastingBarFrame.CastTimeText` current; opaque native `UnitCastingDuration`/`UnitChannelDuration` objects are available for the player. | The restored pinned .309 `CastBarDigits` forwards the native duration object untouched to native text bindings that paint fixed glyph cells; no Lua timer math or addon tick loop. | The native source text is **never cleared**. Hide it with an accepted alpha write only after bindings activate; always restore native alpha before clearing cells, retaining cells if restoration is refused. |
| Ordinary player buff/debuff | Native `UpdateDuration` writes the current `Duration`/`duration` label. | `BuffPresentation.afterDuration` selects public short-duration cells or the supported native formatting route. `NativeDigitCells` owns the cells attached to the physical label. | Physical owner, generation, assignment and stock-text receipts govern takeover and recovery. Restricted identity/private/forbidden paths remain native. |
| Tracked buff icon | Native viewer items own cooldown widgets and duration rendering. | `TrackedBuffSeconds` sets the widget's native decimal threshold to 10. | Current viewer pass and current item/widget association prevent a recycled item from styling its former widget. No custom countdown clock. |

Action formatting is **tenths below 10**, whole seconds for **10 ≤ time < 91**, then rounded-up minutes. Thus 90.99 displays `90`, while 91 displays `2m`; hour/day rules remain native formatter rules. Cast cells preserve the native string's precision and locale. Public buff cells handle positive sub-ten-second samples; longer buffs retain native formatting. Do not copy the action thresholds into every timer route.

## Action countdown: bind, observe, release

1. `CooldownSeconds.applyCooldownSeconds` discovers accessible action, pet, stance and related cooldown widgets out of combat. It installs the native formatter and calls `NativeDigitCells.InstallAction`. Pet spell-book resolution checks identity rather than accepting a convenient slot.
2. `prepareAction` reads the current source font/style, creates or refreshes cells, and configures native duration-to-text bindings. The bindings own their update interval and receive the opaque duration object directly.
3. Post-hooks on the native cooldown's `SetCooldown`, `Clear`, `SetHideCountdownNumbers` and minimum-duration setter observe the current native state. Epoch checks reject stale work if a setter triggers a newer update.
4. `setDuration` preserves native minimum/GCD policy. If public widget totals cannot establish eligibility, a complete synthetic native binding checks the supported duration/rate-to-color mapping before a native minimum gate can be used. A zero-duration probe or incomplete binding is not sufficient calibration.
5. `restoreStock` releases only the addon-owned hidden-number state. It reads back the native visibility flag and retains recovery state after refusal. A later native or external visibility writer releases the addon's previous claim.

Failed minimum-gate calibration is retried at safe login/world-entry/combat-exit boundaries; successful calibration remains cached. Existing cells resynchronize native font/style rather than substituting a font. Countdown preference changes use the native visibility handoff; an off setting must not leave addon digits visible. Follow the current action test's recorded setters and displayed cells when investigating duplicate, blank or stale numbers.

## Cast countdown: native duration bindings and non-destructive fallback

The 0.2.334 text-mirror renderer was removed from this test branch following an observed Hearthstone cast bar with no timer. That renderer erased the source FontString after painting another set of glyphs. A hidden, clipped or failed replacement could therefore leave nothing visible. This branch restores the pinned 0.2.309 duration-bound strategy.

At a safe lifecycle event, `prepare` confirms the player cast bar, its original `CastTimeText` label and font, then allocates nine native text bindings in fixed positions (one- and two-digit tracks). No `SetText('')` call is made on Blizzard's native label. The original text is still maintained by Blizzard's `UpdateCastTimeText`.

`refresh` observes the native player cast/channel mode through the existing cast-bar lifecycle and player `UNIT_SPELLCAST_*` events. `UnitCastingDuration('player')` or `UnitChannelDuration('player')` produces an opaque native duration object, forwarded **unchanged** to `SetDuration` on the bindings. Only if all bindings accept the new duration does `activate` try to hide the native text with `SetAlpha(0)`. An unsupported duration, disabled native Show Cast Time option, denied binding, or refused native alpha setter leaves/restores the original text.

On cast end, `disable` restores the native alpha **before** disabling native bindings. If the alpha setter throws or returns `false`, the existing cells remain active rather than clearing the only visible presenter. Later native lifecycle events can retry. The helper reports `cast=native-bindings`, `state=cells|stock` and `setting=on|off|unknown` through existing `/buitimers` output without reading hidden values.

The original .309 fixture, restored as the current cast suite, exercises fixed glyph positions and threshold handoffs, cast/channel changes, unavailable duration objects, disabled Show Cast Time, thrown setters, explicit `false` setters, and subsequent restoration. These simulated tests do **not** prove live rendering, protected-call safety, or empowered hold-at-max behavior. Keep the live issue open until witnessed in WoW: Forever.

## Player auras: assignment, physical ownership and receipts

`BuffPresentation.setupButton` operates only on accessible ordinary buttons exposing `UpdateDuration`. Private anchor placeholders are excluded. It hooks the native method rather than adding another `OnUpdate`: the native aura code can replace or remove its update script when a slot becomes permanent or timed.

`Update` and `UpdateExpirationTime` invalidate the old duration object, assignment and saved text, and release old split digits. Edit Mode examples also retire the current custom presentation. A repeated aura ID alone is not proof that expiration, physical owner or assignment is unchanged.

After each native duration write, `showTenths` checks the current physical label, visibility/preference permission and `BuffBinding`:

- **Public short sample:** `ReadyBuff` confirms preparation and ownership, the original label text is captured/cleared, then `ShowBuff` writes the fixed tenth. A failed takeover restores a current native receipt or uses the native formatting sink.
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
| `visibility-restricted` | Observed bindings using the supported restricted-visibility permission path. | Hidden timers forced visible. |
| `hooked=N/M` | Successfully recorded duration hooks among currently accessible ordinary buttons exposing the native method. | Coverage of private/inaccessible slots. |
| `retry-pending`, `fallback-buttons` | Current accessible button states with a queued retry or recorded fallback. | Current spell identity or an all-clear after the button expires/recycles. |
| `private`, `inaccessible` | Skipped private anchors and inaccessible/blocked entries encountered by coverage inspection. | A bug merely because the count is nonzero. |
| `actions cells/stock/idle` | Cached prepared action states currently rendering cells, on fallback/restoration, or idle. | Full coverage of all native action widgets or a fresh live-clock measurement. |
| `minimum-read-denied` | Count includes both direct denied reads and unsupported native-gate fallbacks. Up to three button samples give the more precise reason. | That every count was the same failed getter. |
| `gate-unsupported/<stage>` | The recorded setup/binding failure, such as `probe-formatter`, `probe-mapping`, `combat-cold` or a color-binding stage. | A confirmed root cause of visible motion or stuttering. |
| `typography profiles glyphs=... formats=... last=...` | Cached native-font preparation profiles: fixed spacing, naturally tabular/plain, or unavailable; the last fixed public stage records where preparation stopped. No live timer/text is read and no calibration runs for this diagnostic. | Active displayed timers, a current per-buff route, or proof of rendered glyph stability. |
| `below/equal-minimum` | Native minimum policy prevented the fixed presenter. | An obligation to force a countdown visible. |
| `cast=fixed-cells setup=... last=...` | Current setup state and last recorded cast outcome, e.g. `ready`/`cells`, `native-format-unmatched` or `native-clear-refused`. | That a cast is currently active or pixels are correctly spaced at every scale. |

Aura identity reasons distinguish `aura ID secret`, `missing`, `invalid` and `inaccessible`, plus unsupported/missing units or info. A secret-ID fallback is deliberate native ownership; adding a spell-name allowlist would not repair the missing permission.

Capture exact output with addon/client version, surface, combat state and relevant setting. Keep an affected action/cast active during capture; aura counters can still help after a short aura expires. Capture borders with `/buiborders` before `/buiicons` or reload. Existing live reports remain open in [KNOWN_ISSUES.md](../KNOWN_ISSUES.md).
