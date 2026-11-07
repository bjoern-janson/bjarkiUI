# bjarkiUI

Minimal WoW: Forever interface presentation addon. It keeps Blizzard's unit frames, bars, action buttons, and icons in charge of their own gameplay behavior while adjusting cosmetics, labels, positioning, and selected countdown formats. **Latest synced test build: `0.2.286-combat-icon-clearance-test` (2026-11-07).**

## Install

Copy the repository's addon Lua files and both `.toc` files into `World of Warcraft/.../Interface/AddOns/bjarkiUI/` (one `bjarkiUI` directory, not a directory inside another `bjarkiUI` directory). Restart the game. The manifest loads the nine Lua files in their declared order. Keep `WTF` and saved variables when replacing a version.

The GitHub Actions **Package addon** workflow builds an installable `bjarkiUI` artifact from the active `.toc` lists. No other bjarki addon is required, and installing it does **not** install or change an Edit Mode layout.

## Current presentation

- Native class-coloured Target/Focus and compact unit-frame health presentation, restrained status text, player/pet numbers, tooltip and frame styling; no wholesale unit-frame replacement.
- Nameplate-inspired mask and overlay for *accessible* player buff/debuff icons, cast icons and ToT/ToF debuffs; original Blizzard icon artwork retained. Debuff-type indicators stay native when the display cannot be read safely.
- Buff and debuff warning fading suppression, expanded player buff rows, and tenths below 10 seconds where the native timer API permits. Cooldown counts on native action buttons use compact formatting above the seconds range.
- Numeric level labels moved four UI units outward on player/target/focus; player crossed-swords combat icon currently requests `TOPLEFT (76, -63)` relative to its native contextual frame (12 right and 1 down from the Blizzard XML position).
- Free bag slot and quiver/ammunition numerals enlarged three points from their native fonts; their actual values, buttons, and layout remain native.
- Existing Soft Dark styling, party order presentation, incoming damage text and speed text features retain their separate implementation boundaries.

The latest 0.2.286 build is **not fully in-game validated**. In particular, players have observed intermittent missing decorative aura borders and whole-second buff timers. See [Known issues](KNOWN_ISSUES.md) and [Architecture](ARCHITECTURE.md) before treating a test ZIP as a stable release.

## Commands and diagnostics

| Command | Use |
| --- | --- |
| `/bui levels on` / `/bui levels off` | Toggle the level-number setting |
| `/bui audit`, `/bui colors`, `/bui tracked`, `/bui compact` | Existing targeted UI diagnostics |
| `/bui dark off` | Return Soft Dark's owned visual changes where restoration is possible |
| `/buiborders` | **Read-only:** capture decorative border state before a reload |
| `/buitimers` | Report recent native aura timer formatting paths |
| `/buiicons` | Report icon styling; **may reapply styling**, so capture `/buiborders` first |
| `/buicombat` | **Read-only:** show the combat-icon anchor and requested target |
| `/buiauras` | Reports that the experimental target/focus aura replacement is retired; it does not enable it |

If an aura border or decimal disappears, capture `/buiborders` and `/buitimers` *before* `/buiicons` or a reload. For a combat icon that appears unmoved, use `/buicombat` while the crossed swords are visible.

## Architecture and safety constraints

The native target/focus aura rows use `RestrictedAuraAPI` and can be backed by forbidden objects. bjarkiUI **does not** currently replace or reskin those buttons: the experimental approach was retired after a protected-action incident. The addon must not inspect secret aura data, drive restricted buttons, adjust gameplay state, replace native bindings, or write Edit Mode presets to achieve a cosmetic effect.

- [Architecture and historical decisions](ARCHITECTURE.md)
- [Open problems and in-game verification limits](KNOWN_ISSUES.md)
- [Test-build change history](CHANGELOG.md)

## Validation

The 0.2.286 ZIP was checked offline: nine loaded Lua modules compile, and the existing focused simulated-client tests pass. Those tests do not validate Blizzard's real protected APIs, frame rendering, taint behavior, or every character configuration. The repository CI runs syntax checks and regressions; a successful CI result must not be interpreted as in-game clearance.
