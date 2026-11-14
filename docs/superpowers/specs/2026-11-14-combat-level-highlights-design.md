# Combat-aware target and focus level highlights

## Intent

The user rejected the assistant's .369 decision to remove all highlighting as an unnecessarily low-ambition choice. Implement their previously offered behavior: Player always has the plain badge; Target and Focus independently highlight only while their represented unit is in combat. The number's native visibility remains authoritative.

## Approach and evidence

Use the same native selected-outline artwork as .368, but give it the requested combat policy on the two target-like unit frames. The native Camelot nameplate source actually keys this particular outline to target/focus selection, not combat; do not claim the custom policy is identical to the native mixin. A permanent outline and blanket removal have both been rejected. Polling is unnecessary: use unit-filtered UNIT_FLAGS and existing target/focus-change and safe lifecycle events.

Pinned Forever source `bebcb6bf309cf41b41bd74f8ca651e6a105b2676` defines UnitAffectingCombat(unit) as returning a nonnil bool and SetAlphaFromBoolean as accepting secret arguments from tainted callers. Query only the fixed public `target` and `focus` tokens. Native combat visibility is never inferred from the player's combat lockdown, damage events, threat, or selection.

## Presentation and lifecycle

- Keep the three 28 × 16 base badges and sixteen-unit portrait gap. Add two reusable 34 × 23 outlines, centered half a portrait unit lower, below native text. No player outline is created: five textures maximum.
- Prepare/rebind artwork only outside combat. Target/focus switches and combat-flag updates must refresh already prepared visibility during combat without creating or moving regions.
- Compose local numeric visibility and unit combat through native alpha sinks. Public shown state selects public local alpha or zero. For opaque shown state, forward the base texture's resulting native alpha into the highlight's SetAlphaFromBoolean combat sink. Never inspect or retain opaque combat/derived-alpha values.
- A failed combat read, invalid public result, or refused highlight setter hides only the highlight; a valid base stays usable. Missing/changed physical owner or accepted side geometry hides both until safe recovery.
- Increment the existing writer revision on relevant unit events and native level anchor changes. Recheck revision/current binding after introduced native reads; an older query cannot paint a newer target. Preserve the bounded nested-writer retry.
- Reuse all resources after refusal and physical replacement. Keep existing numeric text, fonts/colors, skulls, lower circles, timers and settings native.

## Validation and delivery

Adapt the existing 13-case badge fixture and add focused checks for independent enter/exit, combat-time target/focus switches, opaque visibility composition, refused combat/sink reads, and a newer target update interrupting a query. Run all current suites under native Lua 5.1/5.4, obtain independent review, and package .370 as a normal installable ZIP. Source/fixture evidence is separate from live rendering and performance.
