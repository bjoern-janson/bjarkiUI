bjarkiUI 0.2.15-ultralight

Always-on personal unit-frame presentation for WoW: Forever.

- PRD fill atlas on player/target/focus/ToT/FoT/pet health and power bars.
- Explicit Blizzard power colors after applying the PRD atlas.
- Brighter/more saturated class colors on player-unit health bars.
- NPC unit-frame bars mirror useful nameplate state: tap-denied/tagged grey, engaged non-friendly red, otherwise selection color.
- Own-pet health bars are green on PetFrame and whenever target/focus/derived units resolve to the player's pet.
- Subtle red warning treatment preserves the accepted v0.2.13 visual strength through one stable vertex-alpha channel; repeated Show/SetAlpha paths no longer compound it. Pet attack-mode highlight remains 27%.
- Player/target/focus level numerals reduced by 1 font point.
- Player combat feedback anchored 3 px above PersonalResourceDisplayFrame.
- Player secondary names removed on Player/Target/Focus/ToT/FoT, player nameplates, and chat sender decoration.
- Outgoing world damage text raised to WorldTextScreenY_v2=0.0425 and WorldTextCritScreenY_v2=0.0550.
- Embeds the canonical `bjarkiUI` Edit Mode export. If no character-specific layout with that name exists, it is imported and activated once through Blizzard's Edit Mode APIs; subsequent manual edits are left alone.

No SavedVariables. No slash commands. No portrait/aura code.

v0.2.14-ultralight hardens class-color fallback, tagged-NPC grey handling, chat sender evidence, and red-warning attenuation without changing portrait/aura ownership.

v0.2.15-ultralight embeds the canonical Edit Mode layout as a one-time character-specific import named `bjarkiUI`. Existing `bjarkiUI` layouts are never overwritten, and Edit Mode updates reapply only addon-owned presentation.

Current source corresponds to v0.2.15-ultralight.
