# Known issues and bugs

Status recorded 2026-10-09 for **bjarkiUI 0.2.100-local**.

The Battleground observations below reflect user reports and diagnostic output.
They remain open until checked in the live client against this build.
A report describes a visible symptom; it does not by itself establish the
failing code path or root cause.

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

No live WoW test has confirmed these reports fixed in 0.2.100-local. See
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
Today's build 70291 also adds Druid/Rogue class-resource frames and changes
Druid alternate-mana visibility. Because PRD uses a center anchor and its
height follows visible bars, exact post-maintenance outer-edge alignment
requires a fresh live view.
