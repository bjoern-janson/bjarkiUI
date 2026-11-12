# bjarkiUI code map

Current test branch: **0.2.353-party-crown-spacing-test**. Start with the physical region that displays the symptom, then follow its native writer, addon observer, ownership record and cleanup. [Timer lifecycle detail](TIMER_LIFECYCLE.md) · [Verification commands and suite map](TESTING.md)

## Runtime load order

The [default manifest](../bjarkiUI.toc) and [Camelot manifest](../bjarkiUI_Camelot.toc) load these same 16 files in this order and declare `bjarkiUISettings` as per-character saved variables. This order is part of the integration contract: formatter helpers load before their consumers; the digit API exists before aura setup.

| Order | Module | Responsibility |
| --- | --- | --- |
| 1 | [NativePrecision.lua](../NativePrecision.lua) | Shared `RoundToFloat32` helper for recognizing native-stored presentation values. |
| 2 | [bjarkiUI.lua](../bjarkiUI.lua) | Settings, unit-frame health/name/status presentation, derived frames, incoming hit text, compact chrome and miscellaneous native UI details. |
| 3 | [PartyOrder.lua](../PartyOrder.lua) | Vertical compact-party order, native layout observation and partial-write rollback. |
| 4 | [PartyPresentation.lua](../PartyPresentation.lua) | Compact party names/health class colors and native numeric LoL-style status shadows, without altering native layout or text. |
| 5 | [SoftDark.lua](../SoftDark.lua) | Native artwork tinting, ownership-aware restoration and `/bdark`. |
| 6 | [ClassicPartyPresentation.lua](../ClassicPartyPresentation.lua) | Native non-raid party member class names/health via `nativeHealthStyle` colorable fills, owner-colored pet health, shared 25%-alpha native threat flashes, LoL status text and Soft Dark chrome, excluding compact/raid frames. |
| 7 | [TrackedBuffSeconds.lua](../TrackedBuffSeconds.lua) | Native ten-second decimal threshold for active tracked-buff cooldown widgets. |
| 8 | [ActionTimerSpacing.lua](../ActionTimerSpacing.lua) | Measures native font glyphs, verifies action formatters and prepares a bounded 16-style map of optional fixed-width glyph text for buff digit cells. |
| 9 | [CooldownSeconds.lua](../CooldownSeconds.lua) | Installs native action countdown formatting; observes settings and safe bar lifecycle events. |
| 10 | [NativeDigitCells.lua](../NativeDigitCells.lua) | Action duration bindings, native-font calibrated single-digit action cells, public buff glyph preparation/calibration, longer readable stock text digit mapping, and physical-label ownership. |
| 11 | [CastBarDigits.lua](../CastBarDigits.lua) | Native `UnitCastingDuration`/`UnitChannelDuration` objects drive fixed glyph bindings; retains Blizzard's original cast text as fallback and never clears it. |
| 12 | [IconSkin.lua](../IconSkin.lua) | Native icon masks/rims, donor visibility restoration and `/buiborders`. |
| 13 | [UnitAuraStyling.lua](../UnitAuraStyling.lua) | Inert compatibility stub reporting retirement of the custom target/focus aura route. |
| 14 | [BuffPresentation.lua](../BuffPresentation.lua) | Accessible aura/cast/icon discovery; player duration post-hooks; `/buitimers` and `/buiicons`. |
| 15 | [FrameLabelTweaks.lua](../FrameLabelTweaks.lua) | Level offsets, combat-icon mirror, portrait-relative leader crowns with per-side optical spacing, guarded classic-party crown X+4, bag/ammunition count fonts and `/buicombat`. |
| 16 | [RestIndicatorPlacement.lua](../RestIndicatorPlacement.lua) | Hide only the original player rested-Z texture; observe native Show/SetShown and retry safe lifecycle discovery. Historical filename retained; no placement writes. |

## Find a symptom

| Symptom | Writer, ownership and recovery route | Focused tests |
| --- | --- | --- |
| Health colors or stale class tint | `applyUnit` → `applyHealthColor` → `nativeHealthStyle.Prepare/ObserveColor/Restore`. Separate unit identity from class availability and native color writes. Restore only the current recipient and owned color/material state. | [health-color-observer.lua](../tests/health-color-observer.lua), [lifecycle.lua](../tests/lifecycle.lua) |
| Name color after target/focus replacement | `applyClassNameColor`, `prepareNameColor`, `restoreNativeNameColor`; check alias/owner identity and native setter order. The combat-exit route performs one name-color reconciliation pass. | [name-color-ownership.lua](../tests/name-color-ownership.lua) |
| Native non-raid party art, colors, numbers | `PartyFrame.PartyMemberFramePool` → `ClassicPartyPresentation` guarded native setters; `SoftDark.TintClassicPartyChrome` tints only original decorative art. Only the leader crown delegates geometry to `InstallClassicPartyLeaderCrown` with the current member validator; protected status values stay native. | [classic-party-presentation.lua](../tests/classic-party-presentation.lua), [classic-party-softdark.lua](../tests/classic-party-softdark.lua) |
| Status text/shadow or pet text | `installUnitStatusFonts` → `installStatusFont` → `styleStatusFont`; the native font/style writes and effective scale determine the next application. | [status-style.lua](../tests/status-style.lua), [status-scale.lua](../tests/status-scale.lua), [status-combat.lua](../tests/status-combat.lua), [pet-status-text.lua](../tests/pet-status-text.lua) |
| Incoming player hit-text placement | `anchorCombatText`; follow safe lifecycle retries and native write refusals separately from geometry math. | [hit-text-lifecycle.lua](../tests/hit-text-lifecycle.lua), [hit-text-write-recovery.lua](../tests/hit-text-write-recovery.lua) |
| Action or pet-action countdown | `applyCooldownSeconds` → `InstallAction` → `prepareAction/setDuration/refreshAction`; native duration bindings drive cells. `restoreStock` and visibility ownership return the native countdown. Check minimum/GCD policy, preference, spell identity and current source style. | [cooldown-seconds.lua](../tests/cooldown-seconds.lua), [action-timer-spacing.lua](../tests/action-timer-spacing.lua), [native-digit-cells.lua](../tests/native-digit-cells.lua) |
| Player cast/channel countdown | `UpdateCastTimeTextShown` and player cast/channel events → `prepare/refresh/activate` → opaque `UnitCastingDuration`/`UnitChannelDuration` passed unchanged to native duration text bindings. `disable` restores native alpha before disabling cells. Never clear `CastTimeText`; the mirrored-native-text approach is retired in this test build. | [castbar-digit-cells.lua](../tests/castbar-digit-cells.lua) |
| Player buff/debuff countdown | Native `UpdateDuration` → `afterDuration/showTenths`; `PrepareBuff/BuffBinding/ReadyBuff/ShowBuff` manage the physical label and its generation. `releaseDigits/ClearBuff` and stock receipts handle retirement or handoff. Native font/layout setters can run after the duration hook. | [aura-presentation.lua](../tests/aura-presentation.lua), [static-buff-timers.lua](../tests/static-buff-timers.lua) |
| Tracked buff countdown | Viewer `RefreshLayout` → `updateViewer/setTenths/applyThreshold`; a pass identity and current item-to-cooldown association prevent recycled items from reclaiming old widgets. | [presentation.lua](../tests/presentation.lua) |
| Missing icon rims/masks | `BuffPresentation.setupButton/styleIcon` → `Skin.Apply`; follow icon ownership, donor alpha, mask attachment and `release/restore`. Private/inaccessible icons are outside public skin coverage. | [icon-skin.lua](../tests/icon-skin.lua), [aura-presentation.lua](../tests/aura-presentation.lua) |
| Party or pet order | Native layout → `queueVisualOrder/applyVisualOrder`; `readPoints` snapshots before writes and `restorePoints` unwinds touched frames. Only displaced anchors should be rewritten. | [party-order-recovery.lua](../tests/party-order-recovery.lua) |
| Compact party colors/status | Native compact name and health-color updates → `PartyPresentation` class colors; existing `bjarkiUI.InstallCompactStatusFont` routine only on party numeric text. Changes must not affect raid/nameplate frames or native power colors. | [party-presentation.lua](../tests/party-presentation.lua) |
| Level ring/text, combat-icon and bag-count geometry | `FrameLabelTweaks.apply` → `moveLevel/mirroredCombatAnchor/moveCombatIcon/enlargeCount`. `recordReceipt` stores native-confirmed geometry/font state; do not mistake an addon request for an accepted write. | [frame-label-tweaks.lua](../tests/frame-label-tweaks.lua), [leader-crown-nudge.lua](../tests/leader-crown-nudge.lua), [level-ring-suppression.lua](../tests/level-ring-suppression.lua), [combat-icon-level-mirror.lua](../tests/combat-icon-level-mirror.lua), [combat-icon-portrait-anchor.lua](../tests/combat-icon-portrait-anchor.lua) |
| Soft Dark stale tint or restoration | `applyTheme/tintTexture` and `restore`; inspect original values, native float precision, later writers and failed restoration retries. Edit Mode callback registration is a separate recovery path. | [softdark-restore.lua](../tests/softdark-restore.lua), [softdark-discovery-handoff.lua](../tests/softdark-discovery-handoff.lua), [softdark-callback-recovery.lua](../tests/softdark-callback-recovery.lua) |
| Failed initialization or later native UI availability | Main `installHooks/installNativeUpdateHooks` and each module's setup/event handler. A failed install must remain retryable without duplicating successful hooks. | [initialization-recovery.lua](../tests/initialization-recovery.lua), [hardening.lua](../tests/hardening.lua), [lifecycle.lua](../tests/lifecycle.lua) |
| Restricted target/focus aura behavior | Native aura rows remain authoritative. `bjarkiUIUnitAuraRows.GetStatus` reports retirement; do not revive the old custom renderer from historical notes. | [unit-aura-retirement.lua](../tests/unit-aura-retirement.lua) |

## Shared boundaries

A duration object's existence is not permission to read its remaining time. The cast native duration object is forwarded without examining its protected remaining time. Action cells use native bindings; the restricted public-identity aura route forwards native formatted text to its sink without parsing it. Secret or unavailable identity leaves that aura on the native fallback. Cast cells require a publicly readable native string. These are different permission paths, not interchangeable timer implementations.

Many modules intentionally repeat safe discovery at login, world entry, combat exit or addon load. Timer progression comes from existing native writers and bindings, not an addon-created polling loop. Recovery callbacks and bounded retries are still work: offline tests do not measure their live cost.

For protected-frame changes, inspect the permission check immediately before the writer. Keep native ownership, successful write receipts and later external writes distinct. The shared float helper accounts for native storage precision; it is not a broad tolerance for overwriting changed state.

## Current versus historical material

`tests/*.lua` is the current 36-script verification set. `tests/snapshot-0.2.309/`, `tools/audit/`, the `CODEX_*` audit prompts and [AUDIT_BASELINE.md](AUDIT_BASELINE.md) describe the pinned .309 audit. [ARCHITECTURE.md](../ARCHITECTURE.md) preserves historical design notes, some of which describe superseded cast/timer implementations. Use current source and this map when changing main.
