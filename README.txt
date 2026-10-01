bjarkiUI 0.2.57-local

Ultralight native-UI presentation for WoW: Forever.

Current checkpoint highlights:
- PRD-style fill atlas on tracked health/power bars.
- Brighter/saturated player class colors; player combat pets remain stock green.
- ToT/FoT bar color is re-derived after Blizzard reuses/rebinds the small frame.
- Player combat, target/focus threat, pet cues, and rested border family use a clean 25% highlight scale.
- Rested state uses a static yellow copy of the native PlayerFrame threat-flash geometry; Blizzard's pulsing StatusTexture stays hidden.
- Secondary player names are removed from supported unit frames/nameplates/chat, Communities roster/chat, raid-style compact frames, and Blizzard Damage Meter visible text.
- Damage Meter cleanup hooks the final row-name FontString `SetText` path rather than only row initialization.
- `/bui levels` toggles player/target/focus level numbers while leaving Blizzard validity rules intact.
- World damage text uses the configured raised CVar positions.
- The named `bjarkiUI` Edit Mode layout is imported only when absent; existing user layout ownership is preserved.
- Micro Menu optical alignment is implemented by shifting the visible `MicroMenu` child down 1 UI unit after Blizzard anchors it. `MicroMenuContainer` remains untouched because it is an anchor root for surrounding bottom UI.
- No addon-owned cosmetic polling/OnUpdate loop.

`ARCHITECTURE.md` contains the detailed frame ownership, secret-value, event,
name-renderer, Edit Mode, threat/rest, and Micro Menu lessons.


Current source corresponds to v0.2.57-local.
