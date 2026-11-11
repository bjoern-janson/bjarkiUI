# Timer lifecycle and diagnostics

This guide describes the **0.2.335-cast-recovery-test** branch based on 0.2.334. The former cast text-mirror mode is historical; the action and aura paths remain unchanged. It traces the displayed timer through its native writer, addon hook, ownership and cleanup. It is not a claim of live-client correctness. [Module map](CODE_MAP.md) · [Tests](TESTING.md) · [Open live reports](../KNOWN_ISSUES.md)

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
- **Restricted remaining time with public unit and aura-instance identity:** `GetAuraDuration` supplies an opaque native object. `FormatRemainingDuration` selects formatting using native time-modifier behavior. Its result may itself be secret; it is forwarded unchanged to `SetText`, never parsed to build cells.
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
| `below/equal-minimum` | Native minimum policy prevented the fixed presenter. | An obligation to force a countdown visible. |
| `cast=fixed-cells setup=... last=...` | Current setup state and last recorded cast outcome, e.g. `ready`/`cells`, `native-format-unmatched` or `native-clear-refused`. | That a cast is currently active or pixels are correctly spaced at every scale. |

Aura identity reasons distinguish `aura ID secret`, `missing`, `invalid` and `inaccessible`, plus unsupported/missing units or info. A secret-ID fallback is deliberate native ownership; adding a spell-name allowlist would not repair the missing permission.

Capture exact output with addon/client version, surface, combat state and relevant setting. Keep an affected action/cast active during capture; aura counters can still help after a short aura expires. Capture borders with `/buiborders` before `/buiicons` or reload. Existing live reports remain open in [KNOWN_ISSUES.md](../KNOWN_ISSUES.md).
