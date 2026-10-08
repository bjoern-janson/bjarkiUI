# Known issues and bugs

Status recorded 2026-10-08 for **bjarkiUI 0.2.92-local**.

The Battleground observations below reflect user reports and diagnostic output.
They remain open until checked in the live client against this build.
A report describes a visible symptom; it does not by itself establish the
failing code path or root cause.

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

## Verification boundary

No live WoW test has confirmed these reports fixed in 0.2.92-local. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the frame/color implementation and
reported BG diagnostics. Pet portraits and aura category failures are tracked
in the [bjarkiPortraits issue list](https://github.com/bjoern-janson/bjarkiPortraits/blob/main/KNOWN_ISSUES.md).
