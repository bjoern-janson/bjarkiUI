# .369 plain level badges

## Request and change

The user's live .368 screenshots show the bright level-badge highlight on all
three large frames. The user explicitly offered removing highlighting altogether
or making it conditional on combat for Target/Focus. This build implements the
first option: remove the extra highlight from Player, Target and Focus.

The base `ui-hud-nameplates-levelindicator` artwork remains, including its normal
border and dark interior. The separate selected-outline atlas is no longer
created. Owned resources decrease from six textures to three. The base stays
28 × 16 portrait-relative units at the existing sixteen-unit side gap, with its
existing text owner, draw sublevel, visibility cache and safe setup/recovery.
Native fonts/colors, lower circles, skulls and timers retain their behavior.
No new combat-state query, event, timer, polling, option or runtime module is
introduced.

Baseline: local .368 commit `5d01bc85af9fc7b9447a0e4d7cd021a767bfd462`,
matching remote commit `b2af80be8149aac7e7e51f016d61f3fb253c8320` and tree
`1d6a2cbaf46c99abb6003f7ac593d4e4f2b601a0`. Runtime changes are limited to
FrameLabelTweaks; the main version literal and both TOCs receive metadata.
[Verified payload hashes](SOURCE_SHA256_0.2.369.txt).

## Executed checks

- The existing 13-case badge fixture was updated for one texture per role and
  explicitly rejects selected-outline artwork. It fails all 13 cases on .368
  and passes all 13 on .369 under native Lua 5.1 and Lua 5.4.
- The same cases preserve actual geometry/scale checks, native mutation
  sentinels, public/opaque visibility, local alpha and parent visibility,
  combat setup/reset, replaced labels/owners, stale callbacks, refused creation
  or configuration and warm resource/geometry stability. No new test suite was
  added for the visual removal.
- Full gate: all 38 top-level Lua scripts pass under both native interpreters;
  all 16 runtime modules compile through native loadfile. Matching manifest
  versions/load order and prohibited Edit Mode writer checks pass.
- An independent runtime review found no issues and independently passed the
  focused fixture in both interpreters. Whitespace checks are clean.

## Installable package

The verified ZIP contains 19 files: both manifests, 16 runtime Lua modules
and the existing spacer texture. Archive integrity, exact membership and byte
identity against the verified payload pass. Expanded bytes: 588,845;
ZIP bytes: 146,414. All packaged files except FrameLabelTweaks and the three
version-bearing files are byte-identical to .368. Tests, documents and user
settings are excluded.

ZIP SHA-256: `2c0b79ec4ca77996976afc88a07c2ef0eced52bbda4b12cbf9ca0411ed54eec4`.

## Evidence limits

The screenshots establish the user's rejection of .368's permanent highlight.
The code and fixtures establish that .369 no longer creates that layer. The
revised build's live optical appearance and taint/frame-time behavior have not
been observed. Earlier microstutter and timer reports remain open in
[known issues](../KNOWN_ISSUES.md).
