# bjarkiUI architecture

Current maintenance reference for **bjarkiUI 0.2.105-local**, reviewed
2026-10-10. Runtime behavior is defined by the source; native API contracts and
source reproductions do not certify live protected execution or pixel output.
Repair history and outstanding reports are recorded in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).

## 1. Scope and ownership

| File | Responsibility |
| --- | --- |
| [bjarkiUI.lua](bjarkiUI.lua) | Owned unit-frame bar/name presentation, chat/Communities/meter display names, highlights, levels, derived alignment, public compact borders, Loss of Control, Edit Mode import, bottom UI, combat text, events and diagnostics. |
| [PartyOrder.lua](PartyOrder.lua) | Player-last visual ordering and pet/border anchors for Blizzard's raid-style **party** frames. |
| [bjarkiUI.toc](bjarkiUI.toc), [bjarkiUI_Camelot.toc](bjarkiUI_Camelot.toc) | Matching runtime manifests and per-character settings declaration. |

Blizzard owns unit assignment, health/power values, native refreshes, aura
selection, combat-source records, hyperlinks and frame lifecycles. bjarkiUI
resolves the existing presentation object, observes its native writer, then
applies a local correction. It does not replace the surrounding systems.
[bjarkiPortraits](https://github.com/bjoern-janson/bjarkiPortraits/blob/repair/second-pass-20261008/ARCHITECTURE.md) is an independent portrait
aura renderer; its behavior is not part of this addon's native small debuff lists.

This document is not loaded by the game. The experimental PRD movement-speed
and duel-distance module is absent from the current runtime.

## 2. Execution and protected-value boundaries

The main file installs general presentation hooks on login, with separate
availability checks for optional Communities, Damage Meter, compact-frame,
Loss of Control and geometry adapters. Relevant `ADDON_LOADED` boundaries retry
Communities, Damage Meter, compact borders and derived alignment. Loss of Control
hook installation retries on login/world entry. World entry reapplies presentation;
Edit Mode changes reapply
derived alignment, Micro Menu placement, incoming combat-text anchoring and
owned unit presentation. Combat exit retries derived alignment and party order.

Unit traffic is scoped to the surfaces the addon paints:

| Trigger | Work |
| --- | --- |
| Target/focus change | Refresh that primary unit and its derived target. |
| `UNIT_TARGET` on `target`/`focus` | Refresh ToT/FoT only. |
| `UNIT_DISPLAYPOWER`, `UNIT_NAME_UPDATE` on the six styled tokens | Power events refresh bars; name events refresh non-pet bars/names. |
| Flags, faction and threat events on target/focus/ToT/FoT | Reevaluate health color. |
| Nameplate addition/removal | Reevaluate the four target/focus bars. |
| Finished native nameplate health-color update | Reevaluate only currently matching target/focus/ToT/FoT actors. |
| `UNIT_PET` on `player` | Refresh local pet bars. |

There is no addon-owned `OnUpdate` loop. Native ToT/FoT updates run per frame and
reach addon post-hooks, so this is not a claim of zero per-frame addon work.
Party repairs coalesce onto `C_Timer.After(0, ...)`, outside the native compact
update stack on the target client; the source has an immediate compatibility
fallback when that timer is unavailable.

Readable Boolean helpers distinguish `true`, `false` and unavailable/secret
inputs. Unit tokens must be readable before comparison, pattern matching or
identity queries. Secret values cannot authorize string parsing, class
inference, palette lookup or arithmetic. Narrow native transports may forward
opaque components unchanged to APIs that explicitly accept them, with a
separate readable condition authorizing the operation.

Sensitive hook/recursion/ownership state lives in addon-owned weak tables.
There is no source/GUID/name-to-unit mapping cache. In particular, the addon
does not write synthetic compact aura settings, install compact member
`OnShow`/`OnHide` scripts, wrap Communities' native `FormatMessage`, or reenter
`AuraUtil.RefreshAuras` from a derived-frame hook. These boundaries prevent
known source paths that enter native secret-health/message/aura work from
addon-tainted execution. `pcall` and modeled tests are not a taint guarantee.

## 3. Bound unit frames and bars

Bar artwork and color cover `player`, `target`, `focus`, `targettarget`,
`focustarget` and `pet`. Resolvers prefer the current nested Blizzard frame
structure and retain older/global fallbacks. Names cover the five non-pet
frames.

An object reference alone does not authorize a unit's presentation. The normal
unit pass requires each present health/power bar's readable `unit` binding to
equal the requested token; names require the frame's current readable binding.
Health/power update hooks route by the actual bar's bound token and verify it
is the resolved owned bar, excluding auxiliary damage/absorb bars. They do not
borrow the event's unit argument when a binding is missing. This matters when
vehicle layout reuses `PlayerFrame` for a vehicle and `PetFrame` for the player.
Unsupported bindings retain native presentation until native hooks see a
supported binding again.

Both fills use `UI-HUD-CoolDownManager-Bar`, with texel snapping bias `0` and
pixel-grid snapping disabled where supported. Target/Focus
[`CheckClassification`](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.lua)
writes the health texture after `UnitFrame_Update`, so an instance post-hook
restores the atlas after that final artwork writer. Native classification
geometry and masks remain intact. Power color uses readable `UnitPowerType`
and `PowerBarColor`; values and power-type calculation remain native.

### Health-color authority

`applyHealthColor` first verifies the bar's current token. An explicit
`UnitExists=false` produces no replacement. The remaining precedence is:

1. **Positive player identity:** adjusted readable class RGB, then native
   class-color transport, then matching readable native health-bar RGB.
2. **Positive combat-pet identity:** `(0, 1, 0, 1)`, ahead of untyped native RGB.
3. **Other or unknown identity:** a positively identified same-actor player
   alias may supply adjusted class RGB; otherwise a matching native health bar
   may supply its actual readable RGB.
4. **Unresolved derived identity:** when player or pet identity remains unknown
   and no preceding source supplied RGB, preserve the native tint.
5. **Remaining readable state:** disconnected/dead `(0.5, 0.5, 0.5, 1)`;
   tap denied with explicit `UnitPlayerControlled=false`
   `(0.9, 0.9, 0.9, 1)`; nonfriend with a readable numeric threat status
   `(1, 0, 0, 1)`; then readable `UnitSelectionColor`.

The NPC tap fallback follows native
[`CompactUnitFrame_IsTapDenied`](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua):
hostility does not disqualify an otherwise readable tap-denied NPC from gray.
Matching readable native RGB still takes precedence. In particular, native
nameplates can choose an optional threat-health color ahead of their tap-gray
branch; the addon continues to copy that actual native color.

Direct positive player identity outranks a stale pet witness. Player identity
uses readable `UnitIsPlayer` and readable GUID prefix evidence; disagreement
is unknown. A class token alone never establishes a player. A readable
non-player identity blocks contradictory player-class evidence from aliases.
Pets are identified by the local-pet relation or `UnitIsOtherPlayersPet`;
`UnitIsMinion=false` can establish non-pet identity, but `true` alone cannot
distinguish pets from totems/guardians.

Readable class sources are tried in order: direct unit, matching party/raid
alias, matching nameplate alias, and for ToT/FoT only, matching `player`,
`target`, then `focus`. A readable `UnitIsUnit=false` rejects the match; readable
unequal GUIDs also veto a positive comparison. With no readable relation,
matching readable GUIDs can establish the relation. No color or identity is
retained between referents.

Class RGB comes from `CUSTOM_CLASS_COLORS` or `RAID_CLASS_COLORS`. With
`maximum = max(r, g, b)`, each component is adjusted as
`min(1, (maximum + (component - maximum) * 1.18) * 1.08)`, with alpha `1`.
Copied native health-bar RGB is used exactly, without reverse-mapping it to a
class or adjusting it again. Name/FontString colors, unmatched nameplates,
cast/power bars and unreadable copied components are not color witnesses.

The native player path independently requires positive player identity, then
forwards `UnitClassBase` to `C_ClassColor.GetClassColor` and
`ColorMixin:GetRGB` directly to `SetStatusBarColor(..., 1)`. The pinned
[class-color](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/ClassColorDocumentation.lua)
and [status-bar](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua)
contracts accept protected arguments. Opaque tokens/components never enter the
readable class adjustment or diagnostics. A readable call-success result
controls fallback, so copied white RGB does not preempt available native class
rendering. The write guard releases even after a failed write; successful
color paths also request `SetStatusBarDesaturated(false)` where supported.

ToT/FoT frames are reused. The `UnitFrame_Update` post-hook reapplies current
presentation after rebinding; a guarded post-hook on each derived bar's final
`SetStatusBarColor` catches later native tints. The
[`CompactUnitFrame_UpdateHealthColor`](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua)
observer follows finished native nameplate color selection and rejects
forbidden/unreadable frames or non-nameplate tokens. It does not invoke a
native refresh or change threat policy. An unwarranted replacement causes no
write; unknown derived identity never creates a neutral-grey fallback.

## 4. Display names

The shared unit/chat/Communities helper `primaryDisplayName` removes a
recognizable local realm suffix, then takes the first non-whitespace token.
This is a display
operation; identity records and hyperlink destinations remain native.

| Surface | Boundary and policy |
| --- | --- |
| Player/target/focus/ToT/FoT | Native update post-hooks and scoped events; current frame binding required. |
| Compact nameplates, party and raid | After `CompactUnitFrame_UpdateName`, using its readable assigned unit. |
| Ordinary chat sender | Sender-name filter; readable sender/player evidence required. SAY/YELL/EMOTE without readable player GUID evidence stay native. |
| Ping sender | One `CHAT_MSG_PING` event filter; edit only readable local sender display, preserving player-link payloads, role/color/atlas/texture markup, body and remaining arguments. Plain labels require an exact readable GUID-derived name. |
| Communities/Guild roster | After `SetMember`/`UpdateNameFrame`, plus visible-list refresh; preserve the Timerunning icon when readable. After a successful replacement, update only the rank icon's existing LEFT anchor from readable text/presence widths. |
| Communities chat | `AddOnDisplayRefreshedCallback` on the native ScrollingMessageFrame; shorten only readable visible `playerCommunity` hyperlink text. No C_Club message table or native formatter is touched. |
| Damage Meter | Recycled-row final text hooks and current-source initialization adapter, detailed below. |

The native
[PING formatter](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/ChatFrameOverrides.lua)
bypasses ordinary sender filtering. The
[message-filter registry](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameFilters.lua)
skips callbacks for inaccessible messages, and the
[chat-lockdown predicate](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)
includes restricted combat and communication-restricted maps. Protected pings
and unsupported markup can retain secondary names.

### Unchanged native components and derived recovery

`primaryName` rejects explicitly known non-players. Positive player identity
permits parsing a readable `UnitName` component. When
`RegionalUniqueNamesEnabled` is readable and explicitly false, an otherwise
unavailable/disagreeing identity permits that first component to reach the
native text sink **unchanged**. Opaque text is transported whole, without
inspection, comparison, logging or caching. An unknown NPC's multiword
component is therefore not split. The
[Camelot helper](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_FrameXMLUtil/Camelot/NameUtil.lua)
returns this component directly in nonregional mode, and the
[FontString contract](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua)
accepts protected text.

**0.2.104 additionally permits unchanged fresh-name transport on correctly
bound ToT/FoT frames in regional or unknown mode.** The current component may
contain a surname. Explicit known-NPC/follower rejection still applies, and
other surfaces retain their prior policy. This addresses a conditional native
retention path: `GetUnitFirstName` can return nil for a regional separator
pattern, while `UnitFrame_Update` preserves an old label and independently
updates the portrait. The adapter supplies the current token's component; it
does not infer identity from the portrait. Missing/erroring `UnitName` or a
rejected text sink can still leave native text in place. This derived fallback
does not change the meter's policy or promise surname removal.

### Damage Meter lifecycle and source policy

The October 10 native review uses Forever **1.60.1.70338**, commit
`943764493e6b16d63ded3ab304150d1f05e58b57`. The
[comparison from build 70291](https://github.com/Gethe/wow-ui-source/compare/9465cb273b5513495d8ecc12fbb19930dd6b8957...943764493e6b16d63ded3ab304150d1f05e58b57)
changes only `version.txt`; the native Lua, XML and generated API bodies remain
unchanged. This investigation changes no runtime behavior or addon version.

Rows/windows are recycled. Weak tables retain only hook/guard state, not
source identities. Installation post-hooks `DamageMeterSourceEntryMixin.Init`
and each session window's `InitEntry`, scans already existing rows/local
entries, and discovers future windows after `SetupSessionWindow`. The ordinary
native name writer is `UpdateName`, called by
[`Entry.Init`](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_DamageMeter/DamageMeterEntry.lua)
before addon initialization post-hooks. Each name region's guarded `SetText`
post-hook preserves the readable/local paths after later writes.

The readable path requires explicit `isCreature=false`, a readable source
name and readable visible text before replacing its first full-name occurrence.
Known creature rows are rejected. An independently readable `isLocalPlayer=true`
can instead use `UnitName("player")`, preserving readable native text where
possible or reconstructing the existing rank/death-row label from readable
local facts.

For a **protected nonlocal source name**, the current native Init record may
supply `sourceGUID` to `UnitTokenFromGUID`. This adapter requires explicit
`isCreature=false`, `isLocalPlayer=false`, and no readable known creature ID.
The pinned [unit API](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
accepts opaque arguments for both the mapper and `UnitName`:

- A readable mapped token must be positively identified as a player. A
  readable source GUID additionally requires a readable **matching** current
  `UnitGUID`; unavailable or mismatching round trips are rejected.
- An opaque mapped token is accepted only when the source GUID is also opaque
  and regional mode is explicitly false. It reaches `UnitName` directly and
  the complete first component is transported unchanged. The token is not
  classified, compared or cached, and a multiword component remains whole.

Death rows require readable death-recap state and use `SetText`. Normal rows
also require readable rank/index, format and native classification/faction
prefix decisions, then use `SetFormattedText`. A readable prefix is preserved
with [C_StringUtil.WrapString](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/StringUtilDocumentation.lua),
without parsing opaque name contents. Inaccessible required prefix/rank/source
state leaves the native label intact. A standalone external `UpdateName` call
without current source context can temporarily restore a full protected label
until native initialization refreshes it again.

Native [session-window refresh](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_DamageMeter/DamageMeterSessionWindow.lua)
reinitializes visible rows from the selected session's current source data.
The October 10 investigation passes **56/56 actual-source cases** on the
unchanged addon. They include the native current/historical session getters,
event routing, recycled rows, and mapping becoming available on a later refresh
without a totals change. C APIs, widgets, post-hooks and secrecy are modeled;
these cases do not emulate the live secret/taint engine or prove the screenshot's
inputs. No new resolver/refresh defect or runtime fix was established. The
readable-token unavailable `UnitIsPlayer` case remains synthetic: the pinned
schema returns a non-nil Boolean with no secret-return annotation. It is not
evidence that this predicate becomes unknown for the reported live readable token.

The inspected native meter module,
[C_DamageMeter contract](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
and [Edit Mode settings](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua)
expose no primary-only source-name option. Native row formatting consumes
`combatSource.name` whole. The
[UnitSurnameOwn setting](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua)
controls **My surname**; meter formatting does not consult it. Camelot
`NameUtil.GetUnitFirstName` performs ordinary Lua parsing in regional mode,
so calling it does not authorize parsing protected names. A displayed label
is not proof of readable text, and a matching primary name in the current roster
does not establish the identity of a historical source.

**Live dungeon secondary-name retention remains open.** The earlier report
showed `Akirts Ud` and `Sedria Forev...`; that live state was lost after the user
left the dungeon/reset the meter. A new October 10 screenshot shows `Si Yam`,
`Panoh Panoh`, `Magey Vent...`, `Jon Foreverpvp` and `Bjarki`, again without
`/bui names` output. It supplies new evidence of the visible recurrence, but
does not establish mapping, regional mode, secrecy, identity or prefix access.
The earlier reset does not describe the new screenshot's live state. Capture
both diagnostic lines with the affected rows and selected session visible,
as specified in section 9. Neither source tests nor the derived 0.2.104
fallback establish universal primary-name display or repair of these reports.

## 5. Geometry and status presentation

### Derived portrait alignment

Only the recognized single `TOPRIGHT` -> parent `BOTTOMRIGHT` anchor is
adjusted, after readable out-of-combat and finite positive scale checks. The
pinned [native frame definitions](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Mainline/TargetFrame.xml)
put the parent portrait center `55` units left of its right edge and the
derived center `96.5` units left of its right edge. The one-unit left optical
correction gives:

`x = 95.5 - 55 * (parentEffectiveScale / derivedEffectiveScale)`

At equal scale, native `x=12` becomes `40.5`, a `28.5`-unit rightward move.
Current native Y, sizes, parent Edit Mode placement and aura-row constraints
remain intact; the ratio also handles small Focus mode. Guarded `SetPoint` and
`SetScale` post-hooks reapply X without clearing the point first. Missing,
protected or unrecognized geometry stays native. Combat-time resets wait for
combat exit. The adapter reads no aura counts, visibility or screen positions
and writes no alignment fields onto native frames.

### Highlights, levels and loss layers

Threat flashes keep each frame's native artwork/geometry. Player, target,
focus, pet threat and pet attack textures receive native vertex alpha times
`HIGHLIGHT_SCALE=0.25`, once through a guarded vertex-color writer. Protected
components are rejected before arithmetic or guard entry.

The player's pulsing `StatusTexture` is hidden. Resting uses an addon texture
copying the native player flash atlas/anchor, with static RGBA
`(1.0, 0.88, 0.25, 0.25)`, synchronized after native status/art updates. Only
the player health bar's auxiliary `AnimatedLossBar` gets alpha `0`. Its
[native animation](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitFrame.lua)
changes visibility/value without resetting frame alpha; no animation poller is
added. Health values, absorbs and other units' loss layers stay native.

Player/target/focus level rings are hidden and fonts shrink by one unit,
minimum `1`. Per-character `bjarkiUISettings.showLevelNumbers` defaults true;
`/bui levels` toggles and `/bui levels on|off` selects it. Both `Show` and
`SetShown` are observed to enforce hiding. Enabling requires a current matching
binding: the player uses its native level update, and target/focus defer to
`CheckLevel` for corpses, battle pets and unknown/high levels. A vehicle-bound
player level is not forcibly revealed.

Loss of Control remains Blizzard-owned. Independent retryable post-hooks on
`SetUpDisplay` and `SetTime` hide red lines, black backing, ability/type labels,
timer frame and countdown/seconds text. The existing icon alone is anchored
`CENTER` -> frame `CENTER`, `(0, 0)`; event selection and timer data remain native.

## 6. Player-last party layout

[PartyOrder.lua](PartyOrder.lua) changes only final visual anchors for raid-style
party frames. Normal shown entries follow `party1`, `party2`, `party3`,
`party4`, then `player`; missing slots disappear. Any extra readable assigned
tokens precede the player. If a shown member's token is unavailable, the module
leaves native order intact. Edit Mode's forced preview repeats the player
token, so that specific preview orders native member slots 2..N, then slot 1.
Full raids stay native.

`RefreshMembers`, the cached `updateLayoutFunc` (or `UpdateLayout` fallback),
the existing native `CompactUnitFrame_OnVisiblityChanged` notification for
current party members, and scoped `UNIT_CONNECTION` all queue the same repair.
Login/world entry/module availability, Edit Mode and combat exit retry
installation/order. The deferred callback reevaluates current members and
combat state; no anchor changes run during positively detected combat.
Native unit assignment, member scripts, callback tables and refresh remain
Blizzard's responsibility. The module never calls `SetFlowSortFunction`,
replaces a comparator or initiates compact-frame refreshes.

Vertical layout chains member `TOP` to previous `BOTTOM`; horizontal layout
chains `LEFT` to previous `RIGHT`. The first member anchors at party
`TOP`/`TOPLEFT`, Y `-titleHeight`. A shown border wraps the first/last members
with `TOPLEFT (-2, 2)` and `BOTTOMRIGHT (2, -3)`. Pets anchor first to the shown
native party border, otherwise to the reordered first member horizontally or
last member vertically. Horizontal pets start `TOPLEFT` -> `BOTTOMLEFT` and
continue `LEFT` -> previous shown pet's `RIGHT`; vertical pets use `TOP` ->
previous shown pet/anchor `BOTTOM`. This retains the native border relation
while keeping pets below the reordered block.

## 7. Compact aura borders and native debuff selection

Three separate native layers must not be conflated:

| Layer | Current behavior |
| --- | --- |
| Older **public** compact debuff borders | Hide final border Texture alpha on positively identified party/raid ancestry. Icons, cooldowns, stacks and selection stay native. |
| Current **private** harmful-icon borders | Remain client-owned; public hooks cannot reach their secure renderer. The requested removal is unresolved. |
| Whole-frame dispel overlay | Disable known enabled values `1`/`2` of supported `raidFramesDispelIndicatorOverlay` with CVar value `0`. Separate dispel indicators and private aura borders remain native. |

Public compatibility observes `CompactUnitFrame_UtilSetDebuff`, final sweeps
after `CompactUnitFrame_UpdateDebuffs`/`UpdateAuras`, and
`AuraUtil.SetAuraBorderAtlas`. Ownership is established through readable,
non-forbidden fixed ancestry matching `CompactPartyFrameMemberN`,
`CompactRaidGroupNMemberN` or `CompactRaidFrameN`. No aura/secret-health data or
compact-frame settings are edited. A weak marker is created after a successful
alpha-zero write, and a marked pooled Texture returning to positively
non-compact ancestry is restored to alpha `1`. Inaccessible ancestry/write
failure defers both presentation and ownership changes for a later retry.

The current private renderer's
[TOC](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.toc)
selects a secure environment and its
[XML](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.xml)
uses forbidden templates hidden from public execution. Its own AuraUtil copy
writes harmful borders. Inspected public settings expose size, border scale
and dispel indicators, but no private-icon border-visibility switch: zero
scale still leaves an icon-sized border, and hiding a glyph chooses a colored
no-glyph atlas. Synthetic negative border geometry remains removed.

The supported [overlay setting](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Mainline/InterfaceOverrides.lua)
hides its border/gradient/background and stops its animations. It is a
persistent setting shared by compact party/raid frames; the installation
lifecycle disables a known enabled value again on its next pass. Missing APIs,
protected/unknown values and failed writes do not lead to private-object access.

Friendly native ToT/FoT small debuff lists follow Blizzard's `showDispelDebuffs`
filter when enabled. The addon does not change that CVar or reenter the native
aura renderer. This avoids replacing an icon before a protected duration
calculation fails, and leaves portrait auras to the independent addon.

## 8. Edit Mode, bottom UI and combat text

The supplied Edit Mode export is version `5`, `59` records, named `bjarkiUI`.
If no layout of that name exists and character-layout capacity permits, the
addon converts the export, saves it as a character layout, announces it with
`OnLayoutAdded` (or activates via the fallback API), and records completion.
Missing APIs, failed conversion/save or exhausted capacity leave installation
unchecked for retry. After a successful save, activation/notification is
best-effort and installation is marked checked. **A layout with that name is the
installation marker and becomes user-owned**; normal Edit Mode changes are
not continuously overwritten. Existing layouts need an explicit import to
adopt revised serialized coordinates.

Current BuffFrame X is `238.3`, Y `-100.0`; DebuffFrame remains anchored to it
at `(-16.0, -4.0)`. The X was calibrated from `244.0` to move the measured
reference icon approximately six screen pixels left; that estimate does not
certify final client rendering. The serialized export in the source is the
authority for the other coordinates/settings.

The separate Micro Menu adapter offsets only the visible child after
`AnchorToMenuContainer`: X `0`, Y `-1`, retaining the native point relation to
`MicroMenuContainer`. The shared container stays in place because other bottom
UI anchors depend on it. Guild and Legacy notification pips are hidden while
their buttons remain functional.

| Presentation | Exact current setting |
| --- | --- |
| Outgoing ordinary world text | `WorldTextScreenY_v2 = "0.0425"` |
| Outgoing critical world text | `WorldTextCritScreenY_v2 = "0.0550"` |
| Incoming player hit text | Existing HitText `BOTTOM` -> Personal Resource Display `TOP`, `(0, 3)` |
| Default UI error stack | `UIErrorsFrame TOP` -> `UIParent TOP`, `(0, -32)` |

Outgoing text remains engine/world text; its two CVars are applied on
login/world entry without a loop. Incoming text uses the native player widget
and is reanchored on login, world entry and Edit Mode updates.

## 9. Diagnostics and evidence scope

The registered aliases are `/bui` and `/bjarkiui`; `/bjui` is not registered.
Diagnostics are read-only and never repair presentation:

| Command | Reports |
| --- | --- |
| `/bui audit` | Version; independent hook installation states; derived frame/bar/color-hook availability; public private-container API availability with `privateBorderVisibility=client-owned`; readable compact member `debuffBorderScale`, flagging negative values without changing them. |
| `/bui colors` | For target/focus/ToT/FoT: existence, connection/death/tap state, selection RGB, player/pet/class evidence, matching plate/token/bar path and readable native/final RGB. |
| `/bui names` | **Two anonymous summaries** for currently shown native meter windows/rows: row/hook counts; source/text access; GUID/token secrecy or missing mapping; readable-token classifier availability; prefix access; regional mode and UnitName API availability. |

`names` excludes hidden windows/rows and stale hook-only entries, never calls
`UnitName`, prints no names/GUIDs/tokens, retains no identity and adds no recurring
work or hooks. Counters are aggregate boundaries, not per-actor proof;
`unavailable` can count multiple failures for a row, and `prefixSecret=0` does
not prove formatting succeeds. While the affected rows and selected session
remain visible, run `/bui names` and capture both complete output lines:

```text
names version=... rows=... hooked=... sourceSecret=... textSecret=... unavailable=...
names guidSecret=... tokenSecret=... tokenMissing=... playerUnknown=... prefixSecret=... regional=... UnitName=...
```

Keep the meter visible in the capture and identify **Current**, **Overall** or
the numbered historical fight. Capture before leaving/resetting; if presentation
changes after combat, a second capture of the same rows/session can distinguish
the transition. Unknown/secret diagnostic state is evidence about that access
boundary, not a diagnosis of the screenshot's root cause. Aggregate counters
do not identify every per-row GUID-round-trip or name-output rejection.

Earlier native references retain Forever source commit
`9465cb273b5513495d8ecc12fbb19930dd6b8957` (build `70291`). The October 10 meter
review verified **1.60.1.70338**, commit
`943764493e6b16d63ded3ab304150d1f05e58b57`; its comparison changes only
`version.txt`, so those earlier source bodies remain valid. Focused source
fixtures execute actual addon helpers and selected native formatter, entry,
window and update bodies with modeled WoW APIs/widgets/secret propagation.
They verify conditional control flow, geometry and lifecycle rules; they do
not emulate the live secret/taint engine or certify Battleground/dungeon output.
Live opposing-faction colors, private icon borders, secondary-name reports and
pixel alignment retain the scope recorded in [KNOWN_ISSUES.md](KNOWN_ISSUES.md).
Targeted-nameplate font size remains native; a screenshot alone does not
establish a C++ scaling defect or warrant a font/CVar workaround.

Maintenance changes should follow the current native owner and final writer,
require the actual current binding, and reevaluate reusable frames/rows instead
of retaining actor mappings. Keep party sorting outside native refresh stacks,
private aura/message ownership intact, layout coordinates user-owned, and
documentation out of the manifests. Historical experiments belong in the
issue history, not in the current behavior contract.
