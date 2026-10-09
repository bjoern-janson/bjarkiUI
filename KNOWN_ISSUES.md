# Known issues and bugs

Status recorded 2026-10-09 for **bjarkiUI 0.2.97-local**.

The Battleground observations below reflect user reports and diagnostic output.
They remain open until checked in the live client against this build.
A report describes a visible symptom; it does not by itself establish the
failing code path or root cause.

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

No live WoW test has confirmed these reports fixed in 0.2.97-local. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the frame/color implementation and
reported BG diagnostics. Pet portraits and aura category failures are tracked
in the [bjarkiPortraits issue list](https://github.com/bjoern-janson/bjarkiPortraits/blob/main/KNOWN_ISSUES.md).


## Latest bundled layout in 0.2.97

The embedded layout is the supplied version-5 export, preserved verbatim with
all 59 records. The main frame coordinates retain the earlier spacing edits:
Player/Target Y -157, Focus -163 and PRD -167. Other encoded settings and
relative anchors match the new export. A previously installed named layout
remains user-owned; importing a different export is an explicit user action.

The target and party content rectangles in the supplied crop already align
within roughly one pixel, while their native bevels differ. No party X change
is included. The scoreboard partly obscures the focus portrait; full-circle
clearance would require a much larger move than the requested small nudge.
Today's build 70291 also adds Druid/Rogue class-resource frames and changes
Druid alternate-mana visibility. Because PRD uses a center anchor and its
height follows visible bars, exact post-maintenance outer-edge alignment
requires a fresh live view.
