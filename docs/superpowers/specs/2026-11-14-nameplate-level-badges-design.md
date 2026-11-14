# Nameplate artwork for side level numbers

## Requested result

Move Player, Target and Focus numeric levels six portrait units farther out (gap 10 → 16), and put the native nameplate level background and gold selected outline behind each number. Keep the existing native text, font, difficulty color and visibility. Preserve the lower native level circles and high-level skulls.

## Design

Reuse `ui-hud-nameplates-levelindicator` at 28 × 16 and `ui-hud-nameplates-levelindicator-rectangle-selected` with its native three-unit side/top and four-unit bottom expansion. Both are addon-owned textures on the native FontString's exact main owner, immediately below its draw sublevel. Their geometry follows the portrait's effective scale. The outline is a static matching decoration on all three labels, not a new selection-state indicator.

The artwork is from the Forever native Camelot nameplate template, pinned at Gethe/wow-ui-source `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, `Interface/AddOns/Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.xml`. Source establishes the atlas names and proportions; live optical fit remains unobserved.

Use one reusable texture pair per role. Prepare only outside combat. Existing lifecycle refreshes retry missing setup; installed Show/Hide/SetShown/SetAlpha observers mirror current native numeric visibility without writing native text or visibility. An opaque IsShown result may go directly to the documented `SetAlphaFromBoolean` sink, never into addon branching or SetShown. Same-parent artwork inherits ancestor visibility. Hide the owned art when the label/owner/accepted side placement is unavailable. Native anchor resets during combat hide it until safe restoration.

No polling, unit queries, new runtime module, timer changes, new options, or user diagnostics.

## Validation

Execute the real module in focused native-object fixtures. Cover actual centered geometry, scale conversion, layering, all three labels, native hide/skull/parent behavior, combat reset/recovery, physical replacement, refused setup and bounded warm refreshes. Run the existing full gate under native Lua 5.1 and 5.4 and verify the installable ZIP against source. Report offline evidence separately from live rendering.
