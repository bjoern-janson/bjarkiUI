# Known issues and bugs

Status recorded 2026-10-10 for **bjarkiUI 0.2.105-local**.

The observations below reflect user reports and diagnostic output.
They remain open until checked in the live client against this build.
A report describes a visible symptom; it does not by itself establish the
failing code path or root cause.

## Dungeon meter secondary names — October 10 follow-up

The new Damage Done screenshot shows `Si Yam`, `Panoh Panoh`, `Magey Vent...`,
`Jon Foreverpvp` and `Bjarki`. It confirms another visible recurrence, but
contains no `/bui names` output and does not establish those rows' mapping,
regional mode, source/text secrecy, identity or native prefix access.

This is separate from the earlier dungeon report showing `Akirts Ud` and
`Sedria Forev...`. The user left/reset after that earlier report, losing its
live state. That history does not establish whether the new screenshot's
affected state is still available to inspect.

Fresh native verification found Forever **1.60.1.70338**, commit
`943764493e6b16d63ded3ab304150d1f05e58b57`. The
[comparison from 70291](https://github.com/Gethe/wow-ui-source/compare/9465cb273b5513495d8ecc12fbb19930dd6b8957...943764493e6b16d63ded3ab304150d1f05e58b57)
changes only `version.txt`; meter Lua, XML and generated API contracts are
unchanged. The unmodified **0.2.105-local** addon passes **56/56 actual-source
cases**, including native session selection, event routing, row reuse and a
mapping becoming available without a totals change. C APIs, widgets,
post-hooks and secrecy are modeled. These checks do not reproduce the live
secret/taint engine or identify the screenshot's failed path. No new runtime
fix was established, and this investigation changes no addon version.

The inspected native meter,
[C_DamageMeter API](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_APIDocumentationGenerated/DamageMeterDocumentation.lua)
and [Edit Mode options](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSettingDisplayInfo.lua)
expose no primary-only source-name setting. Native
[row formatting](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_DamageMeter/DamageMeterEntry.lua)
uses the full `combatSource.name`; the separate **My surname**
([UnitSurnameOwn](https://github.com/Gethe/wow-ui-source/blob/943764493e6b16d63ded3ab304150d1f05e58b57/Interface/AddOns/Blizzard_SettingsDefinitions_Frame/Nameplates.lua))
preference is not consulted by the meter. Ordinary Lua name helpers do not
grant permission to split protected text, and a current roster member with
the same primary name cannot identify an unmapped historical source. The
existing supported native component transports remain in place; universal
secondary-name removal is not established.

While the affected rows and selected session remain visible, run:

```text
/bui names
```

Capture both complete lines with the meter visible, before leaving/resetting:

```text
names version=... rows=... hooked=... sourceSecret=... textSecret=... unavailable=...
names guidSecret=... tokenSecret=... tokenMissing=... playerUnknown=... prefixSecret=... regional=... UnitName=...
```

Identify whether the selected session is **Current**, **Overall** or a numbered
historical fight. If the display changes after combat, capture the same
rows/session again. `/bjarkiui names` is equivalent; `/bjui` is not registered.
The command prints anonymous aggregate access counters, calls no `UnitName`,
changes no presentation and retains no identities. The counters narrow the
remaining branch; they are not per-row proof or a guarantee that formatting
succeeds. The live report remains open.

## Tagged NPC gray-to-red fallback in 0.2.105

The open-world report describes a tagged mob turning from gray to red while
a warlock channels Drain Life. The affected surface and live API state were
not captured, so the spell is not established as the cause.

The direct NPC fallback incorrectly required `UnitIsEnemy=false` in addition
to a readable denied tap and `UnitPlayerControlled=false`. Native
[`CompactUnitFrame_IsTapDenied`](https://github.com/Gethe/wow-ui-source/blob/9465cb273b5513495d8ecc12fbb19930dd6b8957/Interface/AddOns/Blizzard_UnitFrame/Shared/CompactUnitFrame.lua)
has no hostility requirement. When a matched native color was unavailable,
this extra condition let an otherwise gray tagged NPC fall through to red.
The fallback now uses the native tap predicate without that extra condition.

Focused source cases reproduce native-gray/owned-red mismatches both without
a matched nameplate and with unreadable native RGB during health refreshes.
The correction keeps those owned bars gray. The fixture also distinguishes
native party threat-health red, which can legitimately precede native tap
gray. Matching readable native RGB remains the preferred color source, so the
addon still follows that red presentation when Blizzard selects it.

These cases execute actual addon/native Lua with controlled C API/widget
returns; they do not reproduce a live Drain Life cast or certify protected
execution. If the issue recurs, `/bui colors` while the same target remains
selected can distinguish the owned bar from a readable matched native plate.
The report remains open for live confirmation.

## Derived dungeon names in 0.2.104

The reported ToT label can show a previous mob/player name beside a current
portrait. The addon has no previous-target name cache, and the native child
frame's name source is its own targettarget/focustarget token.

A conditional native reproduction exposes one retention path: with regional
names enabled and local surname display disabled, GetUnitFirstName's separator
pattern can return nil for the current first component. UnitFrame_Update then
keeps the old label while updating the portrait. The previous addon policy
could not supply a replacement when player identity or the regional component
was protected. This reproduction does not establish those exact inputs in the
two screenshots; protected name data alone is not a failed lookup.

Owned, correctly bound ToT/FoT frames now permit the fresh UnitName component to
reach SetText unchanged when primary-only formatting is unavailable. A combined
or protected component may retain its surname. No protected content is parsed,
compared or cached, and no player identity is inferred from a portrait or alias.
Explicit known-NPC rejection preserves native NPC/follower labels; other name
surfaces keep their prior policy. Missing/erroring name results or a rejected
text write still leave native presentation in place.

Focused cases exercise the actual native formatter/update body and addon path
with controlled API/widget returns. They cover regional retention, both derived
frames, protected text, unit changes and unaffected name surfaces. Live dungeon
confirmation is still needed.

## Opposing-faction meter names in 0.2.103

The meter adapter rejected an opaque UnitTokenFromGUID result before the native
UnitName call, although both APIs permit protected arguments in addon code.
For an opaque source GUID and explicit nonregional mode, that mapped token now
reaches UnitName and its first component passes unchanged through the existing
text sink. The code does not inspect, parse, compare or retain opaque identities.
Readable source GUIDs still require the existing readable matching round trip.
Known creature, source, local-player, rank and faction-formatting checks remain.

The repaired path passes focused cases for enemy prefixes, death rows, recycled
rows and complete multiword native components. The screenshot cannot establish
that its particular rows supplied an opaque mapped token. Secondary names can
remain when mapping is unavailable, regional mode is enabled/unknown, a readable
GUID cannot be verified, or required native row/prefix/rank information is
inaccessible. A standalone external UpdateName still lacks current source data
until native initialization runs again.

`/bui names` inspects currently shown native rows and prints two anonymous access
summaries. It does not call UnitName or print name contents, changes no
presentation and records no identity.
Use it while the failure is visible. Source execution with modeled native APIs
does not certify the live secret/taint engine or universal BG surname removal.

## Native binding and presentation repairs in 0.2.102

Tracked presentation now requires the current readable native frame/bar unit.
The native vehicle layout reuses PlayerFrame and PetFrame with different units;
the same object no longer authorizes a stale literal-player name or class color.
Unavailable bindings retain native presentation instead of borrowing the event
argument. Existing class brightness, native NPC colors and matching-nameplate
refresh rules remain unchanged.

The level-number preference now follows native SetShown as well as Show, and
enabling it preserves a level intentionally hidden by the vehicle layout.
Communities rank icons are repositioned after a readable primary name shortens,
using current native text/presence geometry. Party pet rows use the visible
native party border before the existing reordered-member fallback.

The former ToT/FoT full-debuff-list adapter re-entered AuraUtil.RefreshAuras.
Source execution demonstrates an icon update followed by a protected-duration
failure, leaving the old timer on the new icon. That re-entry is removed.
With showDispelDebuffs enabled, friendly derived native debuff lists retain
their native dispel filtering. No global CVar change is made, and the separate
bjarkiPortraits aura selection is unchanged by this UI repair.

These are reproduced source transitions with unavailable WoW C/widget behavior
modeled. They do not establish live vehicle, secure execution, pixel placement
or resolution of every reported Battleground symptom.

## Health-color synchronization and derived class aliases in 0.2.101

An owned bar can copy a neutral nameplate's yellow RGB before the native
nameplate event or deferred health update finishes with red. Without a later
owned refresh, the copied color remains stale. The native final color-selection
function is now observed, and current matching target/focus/ToT/FoT bars run
their existing color selection again after it returns. Unreadable identity or
RGB still cannot authorize a copy.

The source reproduction uses a documented grouped tank-style threat display
to produce red while personal detailed-threat status remains nil. This proves
the update-order gap, but not the user's actual role, CVar setting or event
timing. The repair follows readable native presentation and introduces no
party-wide threat inference.

ToT/FoT already receive the shared bar atlas and the same class adjustment
when direct, group or nameplate class data is readable. They can now also
use readable class data from a positively matched player/target/focus token,
after those existing class sources. This closes an omitted alias path while
preserving source priority, NPC/pet checks and GUID-mismatch vetoes.

Opaque-only native class RGB remains unadjusted. The source checks do not
measure the reported visual brightness difference, mask edges or the live
secret/taint engine. No screenshot was supplied for this follow-up.

## Primary-name transport in 0.2.100

The existing ToT/FoT hook already follows the native name writer. Its helper
previously rejected every name when player identity was unavailable. In
explicit nonregional mode the native first UnitName component can now pass
unchanged to the text sink in that state. Known NPC names remain untouched;
unknown multiword NPC components stay whole. Player-only parsing still requires
positive identity, and protected combined names in regional/unknown mode remain
native. The screenshot does not establish which predicate or name was readable.

Damage Meter creation, reuse and late native name writes are already observed.
The remaining protected-source case can now use a current native source-to-unit
mapping when its returned token is readable and positively identifies a player.
Known creature IDs, unavailable classification, readable GUID mismatch and
unsupported formatting fail without changing the label. Rank, death-row and
readable native prefix formatting are preserved through supported text sinks.
The source record and unit mapping are never cached.

Protected/unmapped sources can still display secondary names. An external
standalone UpdateName call without source context may restore the full label
until the next native source initialization. The focused checks establish the
supported transport paths; they do not prove the screenshot entered those states
or validate the live secret/taint engine.

## Party visibility and order in 0.2.100

A shown/hidden member can change independently of the parent layout. The old
visible-member anchor chain could then overlap a returning member or retain a
gap after the existing connection timer had finished. The native visibility
notification now queues the same existing next-tick ordering step for current
party-member objects only. Desired order remains party1 through party4, then
player; native unit assignments and member scripts are retained.

The reproduced path uses a member-only UNIT_PET refresh with native pet display
disabled. Ordinary offline/dead status updates alone preserve anchors in the
source checks. The exact logout/death timing of the reported incident remains
unobserved. Combat defers repair until the existing regen path; unavailable unit
identity still prevents reordering.

## Target/Focus health artwork in 0.2.99

The native classification update can replace the requested health atlas after
the existing UnitFrame_Update hook restores presentation. Actual-source checks
reproduce this on full refreshes, roster refreshes and classification-only
updates while the Druid RGB remains correct. The new per-frame post-hook restores
only the atlas after that writer, retaining native geometry and color policy.

The reported olive Focus fill is consistent with an artwork/compositing change.
The screenshot does not prove that a flight landing triggered this path or
that this overwrite accounts for every rendered color difference. Final
appearance still needs a client check.

## Whole-frame dispel overlay in 0.2.99

The rectangular debuff-color highlight around compact Party/Raid frames is
separate from the small aura icon's border. The supported
raidFramesDispelIndicatorOverlay CVar is now set to Disabled (0) through the
existing compact-frame lifecycle when its current value is known and enabled.
Native code hides the overlay border, gradient and background together and
stops its animations. The separate dispel droplet remains available.
The setting persists and applies to normal compact party and raid frames.

This does not remove the private harmful-icon border described below.

## Readable ping sender display in 0.2.96

The native ping formatter bypasses the ordinary sender-name filter. A dedicated
CHAT_MSG_PING filter now shortens readable sender labels when a player hyperlink
or an exact readable GUID-name lookup supplies the character name. It preserves
role text/icons, hyperlink destinations, the ping body and remaining arguments.
Unknown names and unsupported markup stay native.

Protected messages skip addon filters, and protected sender strings cannot be
parsed. Chat lockdown can apply in PvP, encounters and communication-restricted
maps such as dungeons and raids. Secondary names can therefore remain in those
pings. The reported Mana Devourer screenshot does not establish which arguments
were readable, and this build has not been validated in the live client.

## Source repairs in 0.2.95

- A readable non-minion NPC can now replace a previous player's tint even
  when the local-pet comparison is restricted. Positive player and pet
  precedence remain intact.
- Readable unequal GUIDs veto copying RGB from a stale nameplate alias.
- Health refreshes route through the actual bar's unit, covering a focus bar
  receiving a target alias. The test establishes the refresh-routing gap; the
  screenshot's complete native reset sequence remains unproven.
- Both derived frames move one native unit left after aperture measurement.
  Their Y, scale, parent placement and bundled Edit Mode string are unchanged.
- Protected player first names can pass directly to the native text widget
  when regional full-name mode is explicitly false. Other unavailable states
  retain native text; the ToT surname report still needs live confirmation.
- The player's separate native red damage-loss layer is made transparent.
  Actual native animation transitions preserve this alpha. This does not
  recolor or change the underlying health values or absorb widgets.

The current private party debuff border remains unresolved as described below.

## Native class-color fallback in 0.2.92

Positively identified players can now use the native class-color lookup even
when their class token or RGB components are protected. Components pass directly
to the native status bar with alpha 1. Readable direct/authorized-alias class
colors retain their adjustment and priority; copied native bar RGB remains the
fallback if the new path fails.

Player/pet/NPC/unknown identity rules, green pets and the existing derived-frame
write guard are preserved. Focused mocked cases cover copied-white precedence,
failed writes, recovery and unit/frame reassignment. This establishes source
behavior, not resolution of every Battleground color report.

## Confirmed source repairs in 0.2.91

- Confirmed pets are resolved before untyped nameplate fallback. A class-bearing
  NPC or contradictory alias cannot override known non-player identity with a
  player class tint. Positive player identity retains the accepted adjusted
  class color.
- Matching native health-bar RGB is copied exactly. Generic white names and
  other FontString colors no longer establish a class, and native bar RGB is
  not reverse-mapped to a class or adjusted again.
- Legacy and AuraUtil compact-border paths share suppression/restoration
  ownership. Pooled reuse outside compact ancestry restores only a border the
  addon successfully hid; failed or inaccessible restoration remains pending.
- `/bui audit` exposes all four compact-border hook states independently.
- Optional Loss of Control field gaps no longer skip valid later decoration;
  icon placement and the present native frame shape remain unchanged.

These repairs are demonstrated by actual-source tests with mocked WoW boundary
APIs. They do not establish that the Battleground observations below are fixed
in the live client.

## Opposing-faction class colors in Battlegrounds

- Enemy player health bars have been reported white or otherwise not
  class-colored, even when the nameplate shows the player's class color.
- Enemy Target-of-Target and Focus-of-Target health bars have also been
  reported with missing or incorrect class colors.
- A `/bui colors` capture showed the enemy target and targettarget as
  `player=true`, but `class=unknown` and no usable nameplate color in that
  diagnostic context. This confirms an unknown input at that point in the
  diagnostic path; it does not identify why the class data was unavailable.

Keep class identity, unit binding, relation/readability, native bar-color
writes, and fallback selection as separate diagnostic stages. Do not treat a
white bar as proof that the class-color lookup itself was reached.

## ToT/FoT visibility and color

During earlier debugging, changing the display CVar made ToT/FoT frames
disappear. The user restored them with `show=1` and `mode=nil`; the frames
returned, while the opposing-faction color issue remained. Do not change those
CVars as a color workaround. Frame visibility and health-color selection are
separate issues.

## Persistent private party debuff borders

Poison and curse borders in the current compact party frames are drawn by
Blizzard_PrivateAurasUI in a separate secure environment. Its forbidden aura
frames are hidden from the public environment, and its harmful-icon update
unconditionally displays DebuffBorder. The addon's legacy compact/AuraUtil
hooks do not reach this writer.

Current public settings expose icon size, border scale and separate dispel
indicators, but no border-visibility control for this private renderer.
Zero border scale leaves an icon-sized border, and disabling dispel indicators
does not hide it. Native-source execution reproduces both observations.
No private-frame or negative-border-geometry workaround is added. Removal
of these specific borders remains unresolved; earlier public-hook success
must not be described as a fix for them.

The existing `/bui audit` now distinguishes public private-container API
availability from the private border's client-owned visibility.

## Grey dungeon targets and targeted nameplate names

A dungeon screenshot shows a grey NPC target-of-target bar. The current code
uses grey for readable dead/disconnected or tap-denied state, may copy a
matching native bar colour, and preserves the native tint when identity is
unknown. The screenshot does not distinguish those paths. `/bui colors` now
includes readable connection, death, tap-denial and native selection colour
alongside the existing actor and rendered-bar diagnostics. It does not change
the health-colour policy or write presentation state.

Another screenshot shows a targeted nameplate name without the expected size
increase. The inspected native target refresh changes selection/health/level
presentation without resizing the name font. bjarkiUI does not resize that
name font either. The screenshot alone does not establish a regression or a
Blizzard bug; no speculative font or CVar change is included.

## Derived portrait alignment in 0.2.93

ToT/FoT frames were reported overlapping the parent aura rows. The current
adapter moves the small frames right until the native portrait centers align
horizontally, retaining the native Y and accounting for effective scale.
It does not alter aura row logic or the user's parent frame positions.

Point and scale reads/writes are deferred during combat. If Blizzard resets
the anchor during combat, the correction retries after combat using the
current native anchor. Final pixel placement, crowded aura rows and native
protected execution need an in-client check.

## Verification boundary

No live WoW test has confirmed these reports fixed in 0.2.105-local. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the frame/color implementation and
reported BG diagnostics. Pet portraits and aura category failures are tracked
in the [bjarkiPortraits issue list](https://github.com/bjoern-janson/bjarkiPortraits/blob/main/KNOWN_ISSUES.md).


## Latest bundled layout in 0.2.98

The embedded layout retains all 59 records of the supplied version-5 export.
Only BuffFrame X changes, from 244.0 to 238.3. In the measured screenshot, its
reference icon is approximately six pixels right of the Focus/FoT artwork
axis; the calibrated move addresses that gap. The existing DebuffFrame follows
its unchanged relative anchor to BuffFrame. Main-frame coordinates and all
encoded settings remain unchanged. A previously installed named layout
remains user-owned; importing the revised export is an explicit user action.
The screenshot is from an earlier build, and the revised layout still needs
an in-client rendering check. No new runtime alignment hook is introduced.

The target and party content rectangles in the supplied crop already align
within roughly one pixel, while their native bevels differ. No party X change
is included. The scoreboard partly obscures the focus portrait; full-circle
clearance would require a much larger move than the requested small nudge.
Build 70291 also added Druid/Rogue class-resource frames and changed
Druid alternate-mana visibility. Because PRD uses a center anchor and its
height follows visible bars, exact post-maintenance outer-edge alignment
requires a fresh live view.
