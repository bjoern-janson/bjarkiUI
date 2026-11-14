# .368 nameplate-style side levels

## Result and scope

Player, Target and Focus numeric levels move six portrait units farther outward:
the center-to-portrait-edge gap is now 16 instead of 10. Player uses the left
edge; Target and Focus use the right. The existing portrait-to-label effective
scale conversion and accepted native anchor receipts remain in use.

Each native number gets the nameplate's dark level background and gold selected
outline. This is static matching decoration on all three frames. It does not
introduce nameplate selection, focus tint, unit-level queries or custom text.

The prior .367 baseline is local commit
`db283a72b75170923a67dd5ec6eeaa37fa3023f6`, matching remote commit
`7203ec2deec9a8afe55b959c3c2f60af0d821410` and tree
`816cd45ae2d839c8066e72f77ae5241cf8be5b51`.
Runtime behavior changes only in `FrameLabelTweaks.lua`; the main module and both
TOCs receive version metadata. [Payload identities](SOURCE_SHA256_0.2.368.txt).

## Native artwork and ownership

The [Forever Camelot nameplate template](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.xml)
defines `ui-hud-nameplates-levelindicator` and
`ui-hud-nameplates-levelindicator-rectangle-selected`. The independent badge
uses a nominal 28 × 16 base. The outline expands three units on each side and
top, four below: 34 × 23, centered half a unit lower. Dimensions are converted
from portrait units into the native text owner's effective scale.

There is one reusable texture pair per role: six textures total. The pair sits
on the native label's exact main owner, on the same draw layer at sublevels two
and one below its text. Resource creation, reparenting and geometry preparation
occur only outside combat. Failed partial setup retains resources for the next
existing safe lifecycle event. Unchanged preparation skips artwork geometry.

Installed Show/Hide/SetShown observers read the current local native visibility,
not an earlier callback argument. Public booleans use owned texture visibility;
opaque results go directly to the documented SetAlphaFromBoolean sink. Public
local alpha is mirrored; ancestor visibility and fades are inherited from the
shared parent. Unavailable ownership, visibility or accepted side placement
hides the owned artwork. A native level-anchor reset during combat hides the
badge until safe restoration. Old physical-label callbacks cannot touch the
pair rebound to a newer label/owner.

Native level text, font, difficulty color, text parent, visibility, high-level
skull and lower level-circle artwork are not rewritten by the badge presenter.
The existing combat-glyph mirror remains based on the native lower circle.

## Executed verification

- The updated existing side-offset fixture first failed on the .367 baseline
  (26 passed, 14 failed), exposing the original ten-unit gap. It now passes all
  40 cases, including native text/style preservation, float receipts and combat
  geometry deferral.
- The new real-module badge fixture fails all 13 cases against the saved .367
  source because the requested artwork is absent. All 13 pass on .368 under
  both native Lua 5.1 and Lua 5.4.
- Badge cases cover exact artwork/layers/geometry, mixed scales, local and parent
  visibility, public alpha, opaque visibility forwarding, combat setup/reset,
  physical label and owner replacement, stale callbacks, partial setup refusal,
  explicit false hook refusal and safe retry. Repeated settled events create no
  new textures/hooks and make no additional artwork geometry writes.
- The full current gate passes all 38 top-level Lua scripts under native Lua
  5.1 and Lua 5.4 and compiles all 16 runtime modules through native loadfile.
  The first full run exposed four stale side-position assertions in two combat
  glyph suites. Only those numeric-label expectations were updated; their
  original combat-glyph coordinates and behavior assertions remain unchanged.
- Manifest version/load-order agreement, prohibited Edit Mode writer checks and
  whitespace checks pass. No polling, new runtime module, option or timer
  change is introduced. The ultralight description remains qualified as before.

## Independent review and package

A fresh read-only review found no Critical, Important or Minor issues in the
scoped runtime change. The reviewer independently passed all 13 badge cases
under both native interpreters and checked the atlas/outline geometry against
the pinned native source. Full-gate and ZIP execution were performed by the
implementer.

The installable archive contains both manifests, 16 runtime Lua files and the
spacer texture: **19 files, 589,532 expanded bytes, 146,533 ZIP bytes**.
Archive integrity, exact membership and byte equality with the verified payload
inputs pass. Only FrameLabelTweaks behavior and the main/manifest version fields
differ from .367; all other packaged files are byte-identical. Tests, research,
verification documents and settings files are excluded.

ZIP SHA-256: `ba9625f3bc7b0b8e782f0708f83179153322cf9c2f713ef20313f5993babe0d6`.

## Live limits

These checks establish source behavior and modeled native-object presentation.
They do not establish the live client's optical fit, atlas rendering, taint
behavior or frame time. The source identifies native artwork; it is not a
rendered screenshot of this build. The earlier self-target microstutter and
timer reports remain open in [known issues](../KNOWN_ISSUES.md).
