# bjarkiUI architecture

This document describes the current implementation of **bjarkiUI 0.2.90-local** as it exists in the repository. It is intended as a maintenance reference rather than a statement about undocumented client guarantees.

The addon is deliberately small. The runtime consists of:

- `bjarkiUI.lua` — unit-frame presentation, names, highlights, Edit Mode setup, combat text placement, and event hooks.
- `PartyOrder.lua` — visual ordering of raid-style party frames.
- two matching `.toc` manifests.

`ARCHITECTURE.md` is not loaded by the game.

## 1. General approach

bjarkiUI mostly leaves Blizzard frame ownership and data sources intact and changes presentation after native updates.

The main recurring pattern is:

1. resolve the Blizzard frame or region that owns a visual element;
2. wait for, or hook after, the native update that normally writes it;
3. apply the smaller presentation change;
4. avoid replacing the surrounding Blizzard system.

There is no addon-owned `OnUpdate` loop in the current build.

## 2. Unit frames

The addon styles six unit tokens:

- `player`
- `target`
- `focus`
- `targettarget`
- `focustarget`
- `pet`

Health and power bars are resolved through the current Blizzard frame structure with older/global fallbacks where useful.

Both health and power fills use the atlas:

`UI-HUD-CoolDownManager-Bar`

The addon does not replace the underlying health or power values.

### Health colors

The health-color path currently prefers:

1. positively identified players -> class color;
2. positively identified combat pets -> green;
3. disconnected/dead units -> grey;
4. tap-denied NPCs -> light grey;
5. hostile units with readable threat state -> red;
6. otherwise -> Blizzard selection color when readable.

Player class colors receive a small saturation/brightness adjustment.

For `targettarget` and `focustarget`, the native frames are reusable. The addon therefore reapplies the current unit's presentation when Blizzard rebinds those frames. It also hooks the final health-bar color write on those two derived frames so a later native tint does not leave the color from the previous referent.

If the derived referent cannot provide a readable replacement color, the current implementation clears the stale tint to neutral grey rather than preserving the previous unit's color.

### Power colors

Power bars use Blizzard's current power token and `PowerBarColor` when readable. The addon changes the bar artwork but not the power value or type calculation.

## 3. Names

Player names are shortened to their primary name on the surfaces the addon explicitly handles.

Current surfaces include:

- player/target/focus/derived unit-frame names;
- compact raid/raid-style party/nameplate player names;
- ordinary chat sender display;
- Communities/Guild roster and Communities chat display;
- Blizzard Damage Meter source labels.

The implementation tries to change only visible text. Hyperlink payloads, combat-source records, roster records, and other identity data remain native.

Damage Meter rows are recycled, so name normalization is attached near the final text writer rather than only at row creation.

## 4. Highlights and status presentation

Threat/combat/resting highlights reuse Blizzard textures and geometry.

The common visual intensity is currently:

`HIGHLIGHT_SCALE = 0.25`

The player frame's native pulsing status texture is hidden. Resting uses a static yellow copy of the native player flash geometry instead.

Pet attack/threat cues are also scaled to the same general intensity.

## 5. Level display

Level rings are hidden and level text is reduced slightly.

Level numbers are controlled by the per-character setting:

`bjarkiUISettings.showLevelNumbers`

Commands:

- `/bui levels`
- `/bui levels on`
- `/bui levels off`

When level numbers are shown again, target/focus defer to Blizzard's own level checks where available.

## 6. Edit Mode and bottom UI

On first use, the addon can import a named Edit Mode layout called `bjarkiUI`.

Once a layout with that name exists, the addon treats it as user-owned and does not continuously overwrite its coordinates.

The Micro Menu correction is separate from the serialized Edit Mode layout. The addon leaves `MicroMenuContainer` in place and offsets the visible `MicroMenu` child downward by one UI unit after Blizzard anchors it.

This avoids moving the shared container that other bottom-bar elements may use as an anchor.

## 7. Combat text

Outgoing world combat text uses two CVars:

- `WorldTextScreenY_v2 = 0.0425`
- `WorldTextCritScreenY_v2 = 0.0550`

Incoming player hit text is anchored above the Personal Resource Display using Blizzard's existing combat-text frame.

The previous experimental PRD movement-speed/duel-distance module is not present in 0.2.67.

## 8. Party frame ordering

`PartyOrder.lua` changes only the visual order of raid-style party member frames.

Desired vertical order is:

`party1 -> party2 -> party3 -> party4 -> player`

For smaller groups, missing party slots simply disappear and the player remains last.

The module does **not** replace Blizzard's party comparator and does **not** call `SetFlowSortFunction()`.

The current implementation lets Blizzard finish `RefreshMembers()` first. A post-hook then reanchors the already-created visible member frames. This means Blizzard keeps the native unit assignment, compact-unit refresh, and normal frame setup; the addon changes only the final out-of-combat anchors.

Full raid ordering is left native. Pet-frame anchors are adjusted to remain under the visually reordered party block.

## 9. Event model

The main file uses scoped events rather than a general polling loop.

Examples:

- target/focus changes refresh the corresponding unit and derived unit;
- `UNIT_TARGET` is registered only for target/focus because only those tokens can change ToT/FoT;
- power/name events are registered only for the unit tokens the addon paints;
- NPC color-state events are scoped to target/focus/derived targets;
- `UNIT_PET` refreshes only the local pet presentation.

Optional Blizzard modules such as Communities and Damage Meter are hooked when they load.

`PartyOrder.lua` installs on login/world-entry/module availability, derives the visible party order from the current assigned unit tokens, and reapplies after both `RefreshMembers()` and direct `UpdateLayout()` paths. It does not initiate Blizzard compact-frame refreshes.

## 10. Protected and secret values

WoW: Forever can expose secret/protected values through otherwise ordinary-looking APIs.

The addon generally checks values before comparing, pattern-matching, or performing arithmetic on them, especially around:

- unit identity;
- class/power/color values;
- chat/combat-source strings;
- frame color components.

This is an implementation constraint rather than a complete emulation of Blizzard's protected execution model. Live-client behavior remains the final check for taint-sensitive paths.

## 11. Practical maintenance rules

The current source is easiest to maintain when changes stay local to the native object that owns the presentation.

In particular:

- do not style auxiliary bars merely because they share a unit token;
- do not move `MicroMenuContainer` to correct the visible menu;
- do not drive Blizzard compact-frame refreshes from custom party sorting;
- remember that ToT/FoT and Damage Meter rows are reused;
- prefer event/post-update corrections over permanent polling;
- keep documentation files out of the `.toc` load list.


## 12. Small presentation suppressions

The current build also makes three narrow presentation changes without replacing the surrounding Blizzard systems:

- raises the default `UIErrorsFrame` vertically while preserving its horizontal center;
- hides dispel-type colored borders on harmful aura icons in compact Party/Raid frames while leaving the icons, cooldowns, stacks, and separate dispel overlay intact;
- hides Guild and Legacy-system notification pips on the Micro Menu while keeping the buttons functional.


## 13. Loss of Control presentation

The default Loss of Control frame remains Blizzard-owned. bjarkiUI post-hooks the
native display/timer writers and reduces the visible presentation to the spell
icon only. The red line textures, black backing, ability label, timer frame,
numeric countdown, and seconds label are hidden after native updates. The icon
is reanchored to the exact center of the existing Loss of Control frame.


## 14. Derived-frame repair notes

Version 0.2.73 hardens Target-of-Target / Focus-of-Target presentation in three places:

- derived health colors fail closed to neutral grey while player/pet identity witnesses are unreadable or disagree, instead of reusing an incorrect semantic tint;
- native ToT/FoT debuffs are restored when Blizzard's global `showDispelDebuffs` option would otherwise filter friendly derived units down to `HARMFUL|RAID`;
- compact Party/Raid debuff borders are suppressed by feeding the secure private-aura renderer zero border geometry through its ordinary frame settings, rather than attempting to hide forbidden `PrivateAuraMixin` regions after render.


## 15. Party-order lifecycle recovery

Version 0.2.74 keeps the custom raid-style party order stable across member
relogs, disconnect/reconnect transitions, and other compact-frame lifecycle
changes.

Two native paths are covered explicitly:

- CompactPartyFrame caches `UpdateLayout` as `updateLayoutFunc` during OnLoad,
  so bjarkiUI post-hooks that actual cached native writer rather than relying on
  the public method alone.
- individual compact member frames can hide/show while a unit token disappears
  and returns; their visibility transitions now trigger a bounded visual-order
  reapply out of combat.

Blizzard still owns unit assignment and compact-frame refresh. The addon only
reasserts anchors after native lifecycle/layout writes.


## 16. Communities chat secret-message boundary

Version 0.2.75 removes the direct wrapper around
`CommunitiesFrame.Chat:FormatMessage`.

Forever can supply `FormatMessage` with a secret message table. Calling the
native formatter from an addon-owned replacement taints that execution before
Blizzard indexes the secret table.

Guild/Communities secondary-name shortening now happens only after Blizzard's
native ScrollingMessageFrame has completed rendering. bjarkiUI registers an
`AddOnDisplayRefreshedCallback`, reads only accessible visible FontString text,
preserves the complete `playerCommunity` hyperlink payload, and shortens only
the hyperlink's display text.

The C_Club message table and native formatter remain untouched.


## 17. Compact-frame taint rollback

Version 0.2.76 removes the 0.2.73 compact Party/Raid debuff-border suppression.

The previous implementation wrote a synthetic negative `debuffBorderScale` directly
onto Blizzard compact unit frames so the secure private-aura renderer would compute
a zero-sized border. That writes addon-owned state into a compact frame later used
by native secret-health/heal-prediction code, and can taint Blizzard's
`CompactUnitFrame_OnUpdate` path.

The addon no longer modifies compact aura-renderer settings or private-aura border
geometry. Colored debuff borders therefore remain native for now rather than
trading a cosmetic change for secret-value taint.

Party-order reconnect recovery also no longer installs `OnShow`/`OnHide`
scripts on compact member frames. `UNIT_CONNECTION` is observed by a separate
addon event frame and the visual reanchor is deferred to the next tick, outside
Blizzard's compact-unit update stack.


## 18. Compact debuff border presentation

Version 0.2.77 restores the requested removal of compact Party/Raid debuff borders
without writing addon-owned values into Blizzard compact-frame Lua state.

The addon post-hooks Blizzard's final `AuraUtil.SetAuraBorderAtlas` presentation
write. After Blizzard has already consumed the secret aura/dispel data, bjarkiUI
identifies compact Party/Raid aura textures only from their fixed frame ancestry
and sets that border Texture's alpha to zero.

No `CompactUnitFrame` fields, private-aura settings, aura tables, health values,
or heal-prediction state are read or modified. Because private aura frames are
pooled, a border hidden by bjarkiUI is restored to alpha 1 if that same Texture is
later reused on a non-compact presentation.


## 19. Conservative hardening and audit

Version 0.2.78 makes no new presentation claims. It narrows two UNKNOWN-state
paths and adds read-only diagnostics.

- tap-denied NPC coloring now requires an explicit readable
  `UnitPlayerControlled == false`; UNKNOWN no longer authorizes an NPC tint;
- Damage Meter normal name shortening requires an explicit readable
  `isCreature == false`; secret/UNKNOWN creature status falls through to the
  independently warranted local-player path only;
- Loss of Control post-hooks track installation independently, so one unavailable
  Blizzard method cannot prevent the other from being retried later;
- `/bui audit` reports hook state, derived-frame availability, and compact-party
  `debuffBorderScale` values without repairing or mutating them.


## 20. Protected-input and party-order hardening

Version 0.2.79 tightens presentation ownership without changing the intended
visual layout.

- Blizzard-provided unit-token fields are checked for secrecy/readability before
  comparison, pattern matching, or use as unit API arguments.
- compact-party ordering treats the assigned unit token as the warrant for
  reordering. If a shown member's token is inaccessible, the addon leaves the
  native layout untouched instead of inferring identity from frame position.
- party-frame visibility, Edit Mode state, raid state, and title height are read
  through guarded helpers rather than assumed to be ordinary values.
- post-hooks on Blizzard party layout writers no longer reanchor frames inside
  the native update call stack. They coalesce one repair for the next tick,
  where live membership and combat state are checked again.
- reconnect/disconnect recovery uses that same deferred path instead of a
  separate scheduling mechanism.

The maintenance invariant is that **presentation authority follows readable
identity and runs outside Blizzard's protected state-transition stack whenever
possible**.


## 21. Compact debuff-border ownership

Version 0.2.80 corrected the intended native write boundary for the colored
compact debuff border to `CompactUnitFrame_UtilSetDebuff`, while retaining a
narrow `AuraUtil.SetAuraBorderAtlas` compatibility path.

## 22. Compact debuff-border lifecycle hardening

Version 0.2.81 tightens that implementation after live validation showed the
per-aura hook alone was insufficient on the tested client.

The addon now has three non-invasive final presentation boundaries:

1. `CompactUnitFrame_UtilSetDebuff` — catches the native type-color write;
2. `CompactUnitFrame_UpdateDebuffs` — performs a final sweep after the full
   debuff refresh;
3. `CompactUnitFrame_UpdateAuras` — covers builds that route aura refresh
   through that path.

The update hooks operate only on frames positively identified in their parent
chain as:

- `CompactPartyFrameMemberN`
- `CompactRaidGroupNMemberN`
- `CompactRaidFrameN`

The sweep changes only the existing `debuffFrame.border` alpha. It does not
inspect aura data, alter debuff selection, touch icons/cooldowns/stacks, change
health bars, or write compact-frame state.

Hook installation is also retryable. If Blizzard's compact-frame module is
loaded after `PLAYER_LOGIN`, bjarkiUI waits for the relevant
`ADDON_LOADED` boundary instead of permanently recording an uninstalled hook
as installed.


## 22. Reported Battleground class-color gaps

Recent user reports (2026-10-08) say opposing-faction class-colored health
bars remain white or otherwise incorrect in Battlegrounds. The same problem
affects enemy Target-of-Target and Focus-of-Target bars. This is not live-
validated against 0.2.90-local; the pushed source should not be described as a
confirmed fix.

A prior `/bui colors` capture showed the enemy target and targettarget as
`player=true` but `class=unknown`, with no usable nameplate color in that
diagnostic context. This records an UNKNOWN input at that point in the path; it
does not prove whether the cause is client API visibility, unit-token timing,
or refresh lifecycle. Trace the identity/color evidence before changing color
fallbacks.

During earlier ToT/FoT debugging, changing the display CVar made the frames
disappear. The user restored them with `show=1` and `mode=nil`; frames returned,
while opposite-faction class colors remained unresolved. Do not change those
CVars as a color workaround. Check frame availability, current unit binding,
readable class evidence, and the final native color writer as separate steps.
