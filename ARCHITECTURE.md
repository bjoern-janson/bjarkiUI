# bjarkiUI architecture

This document describes the current implementation of **bjarkiUI 0.2.102-local** as it exists in the repository. It is intended as a maintenance reference rather than a statement about undocumented client guarantees.

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

There is no addon-owned `OnUpdate` loop in the current build. Native ToT/FoT
updates do run per frame and reach the addon's presentation post-hooks. The
absence of a custom poller is not a claim of zero per-frame addon work.

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

The native Target/Focus
[classification update](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua)
replaces the health texture after UnitFrame_Update returns. Version 0.2.99
post-hooks CheckClassification on the current Target and Focus instances and
restores the requested atlas after that writer. The callback resolves only
those owned frames; classification geometry, masks and RGB rules are retained.

### Health colors

The health-color path currently prefers:

1. positively identified players -> adjusted readable direct/alias class color, then native class-color rendering, then a matching readable native health-bar color;
2. positively identified combat pets -> green;
3. unknown player identity -> class color only from a positively identified player alias with a readable same-actor match;
4. otherwise, a matching native health bar -> its readable RGB copied exactly;
5. when no matching native bar supplies a color, readable NPC state -> disconnected/dead grey, tap-denied light grey, hostile threat red, or Blizzard selection color.

Readable direct/alias class colors receive the existing small saturation/brightness adjustment. Direct positive player identity remains ahead of a stale pet witness. A readable non-player identity blocks contradictory class evidence from party, raid, or nameplate aliases. A class token by itself does not establish player identity.

Version 0.2.101 also lets ToT/FoT try the `player`, `target` and `focus`
tokens after the existing direct, group and nameplate class paths. The same
current-actor match, readable GUID-mismatch veto and positive player/class
checks apply. This supplies the existing 1.18 saturation and 1.08 brightness
when a primary token exposes readable class data that its derived token does
not. No identity or color is cached, and the previous readable-source priority
is retained. Opaque-only class colors remain on the native unadjusted path.

The native class-color path uses UnitClassBase and C_ClassColor.GetClassColor only after independent positive player evidence. It forwards ColorMixin:GetRGB components directly to SetStatusBarColor with alpha 1, through the existing write guard. Protected tokens and components never enter class inference, palette lookup, adjustment, logging, or retained identity state. A separate readable call-success result controls fallback; a failed write releases the guard. This path uses the native palette and precedes copied bar RGB, so a copied white bar cannot prevent an available class-color lookup. The pinned [class-color API](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_APIDocumentationGenerated/ClassColorDocumentation.lua) and [status-bar API](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua) permit this protected-component transport; live-client behavior still needs validation.

Native bar RGB is copied as presentation data, without reverse-mapping it to a class or applying the class-color adjustment again. Generic name/region FontString colors are not class evidence. Unmatched nameplates and unreadable copied bar components cannot authorize that fallback.

Version 0.2.101 observes the native
[CompactUnitFrame_UpdateHealthColor](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua)
after color selection finishes. An owned bar can otherwise sample old RGB
before a later nameplate event or deferred health update recolors the source.
The post-hook rejects forbidden/unreadable frames and non-nameplate unit
tokens, then runs existing color selection only for currently matching
target/focus/ToT/FoT actors. Unmatched nameplates and compact party/raid frames
do not trigger a full plate scan or owned-bar write. The hook does not invoke
native refresh functions or alter threat policy; it follows the finished
native presentation through the existing color and identity guards.

Readable unequal GUIDs veto a positive alias comparison before any class or
native RGB is copied. After positive pet checks, an explicit readable
UnitIsMinion=false establishes non-pet identity even if the local-pet comparison
is restricted. A positive minion result alone does not classify a combat pet.
The native [unit API](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
defines minions to include pets, totems and guardians.

Health-update hooks require the actual bar's current readable bound unit;
an event may name another alias such as target while the bar belongs to focus.
Missing or inaccessible bindings do not fall back to the event argument.
The actual owned-bar check still excludes auxiliary and unrelated status bars.
This closes a skipped-refresh path; it does not prove that an aliased native
event caused every reported focus reset.

For `targettarget` and `focustarget`, the native frames are reusable. The addon therefore reapplies the current unit's presentation when Blizzard rebinds those frames. It also hooks the final health-bar color write on those two derived frames so a later native tint does not leave the color from the previous referent.

If the derived referent cannot provide a warranted replacement color, the addon makes no color write and preserves Blizzard's native tint. Unknown identity does not introduce a neutral-grey fallback.

### Power colors

Power bars use Blizzard's current power token and `PowerBarColor` when readable. The addon changes the bar artwork but not the power value or type calculation.

## 3. Names

Player names are shortened to their primary name on the surfaces the addon explicitly handles.

Current surfaces include:

- player/target/focus/derived unit-frame names;
- compact raid/raid-style party/nameplate player names;
- ordinary chat sender display;
- readable ping sender display;
- Communities/Guild roster and Communities chat display;
- Blizzard Damage Meter source labels.

The implementation tries to change only visible text. Hyperlink payloads, combat-source records, roster records, and other identity data remain native.

The native
[PING formatter](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/ChatFrameOverrides.lua)
uses its preformatted sender argument directly, bypassing the ordinary sender-name
filter. A single CHAT_MSG_PING event filter changes only the local readable
sender display. Player-link destinations stay intact; plain labels require an
exact readable name returned for the sender's readable player GUID. Role labels,
color/atlas/texture markup, ping bodies and remaining event arguments are preserved.
Unknown names and unsupported display markup retain native text.

Blizzard's
[message-filter registry](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameFilters.lua)
skips addon callbacks when the message is inaccessible. The adapter also rejects
protected sender text before parsing it. The
[chat-lockdown predicate](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)
includes restricted combat and communication-restricted maps. Protected pings can
therefore retain secondary names in instances or PvP. No private formatter,
message-history record or global text writer is modified.

The first UnitName component can be passed unchanged to the native text widget
when RegionalUniqueNamesEnabled is readable and explicitly false. The native
[Camelot name helper](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_FrameXMLUtil/Camelot/NameUtil.lua)
returns that component directly in this mode, and the
[FontString API](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)
accepts protected text. A separate readable flag authorizes the write; the
protected name is never parsed, compared, logged or cached. Version 0.2.100
permits this raw transport even when player identity is unavailable or its
readable witnesses disagree. Known NPCs remain untouched; an unknown NPC's
multiword component is transported whole. The existing string parsing still
requires positive player identity. Regional or unknown mode does not authorize
opaque combined-name shortening.

Damage Meter rows are recycled, so name normalization is attached near the final text writer rather than only at row creation.

For a protected nonlocal source name, version 0.2.100 can use the current native
Init record to ask UnitTokenFromGUID for a current unit. The
[unit API](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
permits an opaque GUID argument, but the returned token must be independently
readable and positively identified as a player. Explicit non-creature and
nonlocal row state is required; known creature IDs and readable GUID mismatch
veto the adapter. A readable source GUID additionally requires a matching
readable current GUID. No combat-source record or unit mapping is retained.

The native first component goes through SetText or SetFormattedText. If a
readable native classification/faction prefix exists, the supported
[C_StringUtil.WrapString](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/StringUtilDocumentation.lua)
preserves it without parsing the opaque name. Existing initialization hooks and
initial visible-row scans provide the current source record; no new event or
hook is added. The native UpdateName caller is Entry.Init. An external standalone
UpdateName call without source context may temporarily restore the full label
until the next native source refresh. Existing readable/local paths are retained.

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

Version 0.2.98 retains the supplied version-5, 59-record Edit Mode export with
one coordinate adjustment: BuffFrame X changes from 244.0 to 238.3. This moves
the top buff block approximately six screen pixels left at the measured layout
scale, aligning its reference icon with the existing Focus/FoT artwork axis.
The DebuffFrame keeps its relative anchor to BuffFrame and follows that move.
All other coordinates, encoded settings and relative anchors are unchanged.
The import lifecycle is unchanged, so an existing named layout remains
user-owned and requires an explicit import to adopt the revised coordinates.
Screenshot calibration does not certify the client's final pixel rendering.

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

The current implementation observes `RefreshMembers()`, the cached native layout writer and native member visibility notifications. Each queues the same coalesced repair for the next tick, where current membership and combat state are checked again. Blizzard keeps the native unit assignment, compact-unit refresh and normal frame setup; the addon changes only the final out-of-combat anchors.

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

The current build also makes these narrow presentation changes without replacing the surrounding Blizzard systems:

- raises the default `UIErrorsFrame` vertically while preserving its horizontal center;
- hides dispel-type borders reached through older public compact aura renderers, while leaving their icons, cooldowns and stacks intact; current private aura borders are outside those hooks;
- disables the native whole-frame dispel color overlay through its supported CVar; the separate dispel indicator remains available;
- hides Guild and Legacy-system notification pips on the Micro Menu while keeping the buttons functional.


## 13. Loss of Control presentation

The default Loss of Control frame remains Blizzard-owned. bjarkiUI post-hooks the
native display/timer writers and reduces the visible presentation to the spell
icon only. The red line textures, black backing, ability label, timer frame,
numeric countdown, and seconds label are hidden after native updates. The icon
is reanchored to the exact center of the existing Loss of Control frame.


## 14. Derived-frame repair notes

The following 0.2.73 behavior is historical. All three entries have been
superseded: the grey fallback by the current color rules, private-border
geometry by section 17, and derived debuff re-entry by section 27:

- derived health colors fail closed to neutral grey while player/pet identity witnesses are unreadable or disagree, instead of reusing an incorrect semantic tint;
- native ToT/FoT debuffs are restored when Blizzard's global `showDispelDebuffs` option would otherwise filter friendly derived units down to `HARMFUL|RAID`;
- compact Party/Raid debuff borders are suppressed by feeding the secure private-aura renderer zero border geometry through its ordinary frame settings, rather than attempting to hide forbidden `PrivateAuraMixin` regions after render.


## 15. Party-order lifecycle recovery

Version 0.2.74 introduced additional party-order lifecycle recovery. Its
member-script subscriptions were subsequently removed as described in section
17. Version 0.2.100 restores the missing visibility observation through the
existing native notification rather than installing member scripts.

Two native paths are covered explicitly:

- CompactPartyFrame caches `UpdateLayout` as `updateLayoutFunc` during OnLoad,
  so bjarkiUI post-hooks that actual cached native writer rather than relying on
  the public method alone.
- individual compact member frames can hide/show without a parent refresh.
  A post-hook on the native CompactUnitFrame_OnVisiblityChanged notification
  matches only the current party's member objects and queues the existing
  deferred visual-order repair. Native scripts and callback tables are retained.

One source reproduction has pet display disabled: the container skips its
UNIT_PET parent update while a member's own UNIT_PET handler calls UpdateAll
and changes its visibility. The previous compressed anchor chain could then
overlap the returning member or retain a gap. The observer covers the actual
visibility transition rather than assuming which logout/death event preceded
it. Ordinary offline/dead status updates alone did not reproduce anchor changes.

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

The addon no longer writes synthetic compact-frame aura settings or private-aura
border geometry. Current private icon borders remain native. The supported
whole-frame overlay CVar described in section 26 controls a different layer.

Party-order reconnect recovery also no longer installs `OnShow`/`OnHide`
scripts on compact member frames. `UNIT_CONNECTION` is observed by a separate
addon event frame and the visual reanchor is deferred to the next tick, outside
Blizzard's compact-unit update stack.


## 18. Compact debuff border presentation

Version 0.2.77 added removal for public compact aura renderers without writing
addon-owned values into Blizzard compact-frame Lua state. The current private
renderer uses a separate environment and is not reached by this hook.

The addon post-hooks Blizzard's final `AuraUtil.SetAuraBorderAtlas` presentation
write. After Blizzard has already consumed the secret aura/dispel data, bjarkiUI
identifies compact Party/Raid aura textures only from their fixed frame ancestry
and sets that border Texture's alpha to zero.

No `CompactUnitFrame` fields, private-aura settings, aura tables, health values,
or heal-prediction state are read or modified by this operation. Because public aura frames are
pooled, a border hidden by bjarkiUI is restored to alpha 1 if that same Texture is
later reused on a non-compact presentation.

In 0.2.91, the legacy debuff helper and AuraUtil hook share this final-texture
ownership handling. The weak ownership marker is created only after successful
suppression and cleared only after successful restoration. Forbidden textures
and unreadable ancestry defer both writes and ownership changes, allowing a later
native update to retry.


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

Semantic rewriting follows readable identity; a permitted native text component
can also be forwarded unchanged to its text sink. Party anchor changes run
outside Blizzard's native state-transition stack on the target client's timer
path and remain deferred during combat.


## 21. Compact debuff-border ownership

Version 0.2.80 added the public `CompactUnitFrame_UtilSetDebuff` border-write
path while retaining the narrow public `AuraUtil.SetAuraBorderAtlas` hook.
Neither path reaches the current secure private-aura renderer.

## 22. Compact debuff-border lifecycle hardening

Version 0.2.81 tightens that implementation after live validation showed the
per-aura hook alone was insufficient on the tested client.

The public-renderer compatibility code has three final presentation boundaries:

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


## 23. Reported Battleground class-color gaps

Recent user reports (2026-10-08) say opposing-faction class-colored health
bars remain white or otherwise incorrect in Battlegrounds. The same problem
affects enemy Target-of-Target and Focus-of-Target bars. These symptoms have not
been checked in the live client against 0.2.92-local. The source repairs do not
establish live resolution of these reports.

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

## 24. Color authority and compact-border repair

Version 0.2.91 corrects the confirmed source paths described above: pet/NPC
identity precedence, unsupported text/RGB class inference, and pooled border
restoration across both native border writers. `/bui audit` now reports
`compactLegacy`, `compactDebuffRefresh`, `compactAuraRefresh`, and
`compactAuraUtil` separately without changing presentation.

Loss of Control decoration uses field-name iteration so a missing optional
alias cannot hide later supported fields from the loop. The native icon remains
centered in the same frame, with unchanged geometry. This is compatibility
hardening; the pinned native field shape already supplied the required fields.

These changes have source-level behavioral validation with mocked WoW inputs.
Live Battleground rendering, restricted API availability, and protected
execution remain separate validation requirements.

## 25. Derived portrait horizontal alignment

Version 0.2.95 retains the derived-frame alignment adapter and adds a one-unit
left optical correction for the visible small-circle aperture. Native vertical
placement, parent Edit Mode coordinates, frame sizes and aura row constraints
remain in effect.

The pinned [native frame definitions](https://github.com/Gethe/wow-ui-source/blob/15666a6e67938a1ab5caf041406464251db111ca/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml)
place the parent portrait center 55 units left of its right edge and the
derived portrait center 96.5 units left of the derived frame's right edge.
The existing TOPRIGHT-to-parent-BOTTOMRIGHT anchor therefore uses
`x = 95.5 - 55 * (parentEffectiveScale / derivedEffectiveScale)`, including
the optical correction. At equal scale, native x=12 becomes x=40.5, moving the
small frame right by 28.5 units and one unit left of its 0.2.93 position.
The effective-scale ratio also covers the native small Focus mode.

An addon-owned weak table holds hook and recursion state. Secure post-hooks
on the derived frame's SetPoint and SetScale reapply only this X adjustment.
The adapter checks readable out-of-combat state before point/scale reads or
anchor writes, accepts only the recognized single native anchor, and retains
its current Y. Missing or protected geometry leaves the native anchor intact.
It never reads aura counts, visibility or screen positions, and never writes
addon fields onto the native frame.

Login, world entry, Edit Mode updates, UnitFrame module loading and combat exit
retry from the current native relation. A native reset during combat remains
untouched until the post-combat retry. Source-level geometry and lifecycle
checks do not certify live pixel alignment or protected execution.

## Player damage-loss presentation

The player health bar's separate AnimatedLossBar is native red artwork that
briefly covers the previous health amount after damage. The existing player
presentation pass sets only this auxiliary frame's alpha to zero. The native
[animation mixin](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitFrame.lua)
changes its visibility and value but never frame alpha, so no additional
animation hook or polling loop is needed. Main health values, power, absorb
widgets and other units' damage layers retain their existing behavior.


## 26. Current private aura borders and diagnostic scope

The current compact Party/Raid aura path passes anchor settings into
Blizzard_PrivateAurasUI. Its
[TOC](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.toc)
selects a secure execution environment, and its
[XML](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.xml)
marks the aura templates forbidden and hidden from the public environment.
The private Update method shows DebuffBorder for harmful auras and calls its
own secure AuraUtil copy. Public compact/AuraUtil hooks cannot reach that
writer; sections 18, 21 and 22 describe public-renderer compatibility only.

The inspected public settings expose size, border scale and separate dispel
indicators, but no individual private-icon border-visibility switch. Zero
border scale still yields an icon-sized border; hiding a dispel glyph selects
a colored no-glyph atlas. Neither removes the border. The earlier negative
geometry workaround remains removed. The current private border request is
unresolved, with its native owner identified.

The whole-frame dispel color overlay has a separate supported control:
[raidFramesDispelIndicatorOverlay](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Mainline/InterfaceOverrides.lua).
Version 0.2.99 sets known enabled values to Disabled (0) through C_CVar during
the existing compact-border installation lifecycle. Missing APIs, failed or
protected reads, unknown values and failed writes are handled without accessing
private frame objects. Native code hides the overlay border, gradient and
background together and stops its animations. The separate dispel indicator
and the private harmful-icon border retain their native behavior.
This persistent setting is shared by normal compact party and raid frames;
the same lifecycle disables it again if a known enabled value is restored.

The existing /bui audit reports public private-container API availability and
client ownership of private-border visibility without inspecting private
icons. The existing /bui colors adds readable connection, death, tap-denial
and selection RGB to distinguish grey NPC states from copied or retained
native colors. These commands report unknown on unavailable or protected
inputs and make no presentation writes.

Targeted-nameplate font size remains native. The inspected target-selection
Lua updates health/level selection without resizing the name font; this does
not establish whether native C++ scaling has a beta regression. No font or
CVar workaround follows from the screenshot alone.

## 27. Current native bindings and final presentation writers

Version 0.2.102 requires the current readable native frame/bar binding before
applying a tracked unit's names, color and bar presentation. The native vehicle
layout can reuse PlayerFrame for vehicle and PetFrame for player while keeping
the same frame objects. A known object alone cannot authorize literal-player
or literal-pet presentation. Unsupported or unavailable bindings remain native;
the existing native update hooks resume presentation when bindings return.

The level-number preference observes both Show and SetShown. Enabling levels
does not forcibly reveal the vehicle-bound player's level; target/focus retain
native CheckLevel rules for corpses, battle pets and unknown levels, after the
same current-binding check. Source fixtures model independent C widget methods;
they are not evidence of live internal Show/SetShown dispatch or taint safety.

Communities SetMember lays out the rank icon before the addon's primary-name
post-hook. After a successful readable replacement, the addon updates only
the existing LEFT anchor using the current readable name width and presence
icon width. Hidden or inaccessible geometry stays native. SetPoint replaces
the native anchor without clearing it first, so a denied write retains the
previous placement. The native member formatter and parsing policy are unchanged.

Party pet rows now anchor first to the visible native party border, matching
CompactPartyFrame.UpdateLayout. With no visible border, the existing reordered
member anchor remains. Player-last order and combat deferral are unchanged.

The derived AuraUtil.RefreshAuras re-entry was removed. Re-entering that native
renderer from an addon hook can replace an icon before a protected expiration
comparison or duration calculation fails, leaving mismatched icon/timer state.
Friendly ToT/FoT small debuff lists therefore follow native showDispelDebuffs
filtering when enabled. The global CVar is not changed. bjarkiPortraits remains
an independent portrait-aura renderer; this limitation concerns the native small
debuff list. Removing the adapter also removes its duplicate list pass.
