# bjarkiUI architecture

This document describes the current implementation of **bjarkiUI 0.2.61-local** as it exists in the repository. It is intended as a maintenance reference rather than a statement about undocumented client guarantees.

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

There is no addon-owned `OnUpdate` loop in the current build.

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

### Health colors

The health-color path currently prefers:

1. positively identified players -> class color;
2. positively identified combat pets -> green;
3. disconnected/dead units -> grey;
4. tap-denied NPCs -> light grey;
5. hostile units with readable threat state -> red;
6. otherwise -> Blizzard selection color when readable.

Player class colors receive a small saturation/brightness adjustment.

For `targettarget` and `focustarget`, the native frames are reusable. The addon therefore reapplies the current unit's presentation when Blizzard rebinds those frames. It also hooks the final health-bar color write on those two derived frames so a later native tint does not leave the color from the previous referent.

If the derived referent cannot provide a readable replacement color, the current implementation clears the stale tint to neutral grey rather than preserving the previous unit's color.

### Power colors

Power bars use Blizzard's current power token and `PowerBarColor` when readable. The addon changes the bar artwork but not the power value or type calculation.

## 3. Names

Player names are shortened to their primary name on the surfaces the addon explicitly handles.

Current surfaces include:

- player/target/focus/derived unit-frame names;
- compact raid/raid-style party/nameplate player names;
- ordinary chat sender display;
- Communities/Guild roster and Communities chat display;
- Blizzard Damage Meter source labels.

The implementation tries to change only visible text. Hyperlink payloads, combat-source records, roster records, and other identity data remain native.

Damage Meter rows are recycled, so name normalization is attached near the final text writer rather than only at row creation.

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

The Micro Menu correction is separate from the serialized Edit Mode layout. The addon leaves `MicroMenuContainer` in place and offsets the visible `MicroMenu` child downward by one UI unit after Blizzard anchors it.

This avoids moving the shared container that other bottom-bar elements may use as an anchor.

## 7. Combat text

Outgoing world combat text uses two CVars:

- `WorldTextScreenY_v2 = 0.0425`
- `WorldTextCritScreenY_v2 = 0.0550`

Incoming player hit text is anchored above the Personal Resource Display using Blizzard's existing combat-text frame.

The previous experimental PRD movement-speed/duel-distance module is not present in 0.2.61.

## 8. Party frame ordering

`PartyOrder.lua` changes only the visual order of raid-style party member frames.

Desired vertical order is:

`party1 -> party2 -> party3 -> party4 -> player`

For smaller groups, missing party slots simply disappear and the player remains last.

The module does **not** replace Blizzard's party comparator and does **not** call `SetFlowSortFunction()`.

The current implementation lets Blizzard finish `RefreshMembers()` first. A post-hook then reanchors the already-created visible member frames. This means Blizzard keeps the native unit assignment, compact-unit refresh, and normal frame setup; the addon changes only the final out-of-combat anchors.

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

`PartyOrder.lua` installs its hook on login/world-entry/module availability and retries deferred visual ordering after leaving combat.

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
