bjarkiUI 0.2.19-ultralight

Always-on personal unit-frame presentation for WoW: Forever.

- PRD fill atlas on player/target/focus/ToT/FoT/pet health and power bars.
- Explicit Blizzard power colors after applying the PRD atlas.
- Brighter/more saturated class colors on player-unit health bars.
- NPC unit-frame bars mirror useful nameplate state: tap-denied/tagged grey, engaged non-friendly red, otherwise selection color.
- Combat-pet health bars are stock green for both the player's pet and other players' pets when observed on target/focus/ToT/FoT.
- Subtle red warning treatment preserves the accepted in-combat strength through one stable vertex-alpha channel. Target/focus threat rings use a quieter 0.08 multiplier until both the player and that observed unit report combat, then return to the existing 0.2025 strength. Pet attack-mode highlight remains 27%.
- Player/target/focus level numerals reduced by 1 font point.
- Player/target/focus LevelBackgroundCircle regions are kept hidden, preserving the plain level numeral while leaving high-level/skull and classification art alone.
- Player combat feedback anchored 3 px above PersonalResourceDisplayFrame.
- Player secondary names removed on Player/Target/Focus/ToT/FoT, player nameplates, and chat sender decoration.
- Outgoing world damage text raised to WorldTextScreenY_v2=0.0425 and WorldTextCritScreenY_v2=0.0550.
- Embeds the canonical `bjarkiUI` Edit Mode export. If no character-specific layout with that name exists, it is imported and activated once through Blizzard's Edit Mode APIs; subsequent manual edits are left alone.

No SavedVariables. No slash commands. No portrait/aura code.

v0.2.14-ultralight hardens class-color fallback, tagged-NPC grey handling, chat sender evidence, and red-warning attenuation without changing portrait/aura ownership.

v0.2.15-ultralight embeds the canonical Edit Mode layout as a one-time character-specific import named `bjarkiUI`. Existing `bjarkiUI` layouts are never overwritten, and Edit Mode updates reapply only addon-owned presentation.

v0.2.16-ultralight makes the plain level-number treatment explicit on player/target/focus by hiding only Blizzard's LevelBackgroundCircle region.

v0.2.17-ultralight tones down the target/focus threat ring before the player is in combat, while preserving the accepted in-combat warning strength.

v0.2.18-ultralight fixes the pre-combat discriminator: full target/focus warning strength now requires both player and observed unit to report combat, rather than player combat state alone.

Current source corresponds to v0.2.18-ultralight.


v0.2.19-ultralight makes combat-pet health bars universally green using positive `UnitIsOtherPlayersPet` identity plus the existing local-pet path. No new events or polling are added.
