# bjarkiUI

**0.2.352-hide-rested-zs-test for WoW: Forever** adjusts Blizzard's unit-frame labels, party layout, aura presentation and timers while retaining native artwork and fonts. Settings are saved per character in `bjarkiUISettings`. The addon does not install, replace or activate Edit Mode layouts.

## Latest test build

**.352:** Removes the player-frame rested Z animation at the user's request. Hide the original Z texture and keep it hidden after native visibility refreshes. The previous Z placement experiments are retired. [Changes](CHANGELOG.md) · [Verification](docs/VERIFICATION_0.2.352.md)

## Install

1. Open a successful [Package addon run](https://github.com/bjoern-janson/bjarkiUI/actions/workflows/package-addon.yml?query=branch%3Afix%2Fhide-rested-zs-0.2.352) and download the `bjarkiUI` artifact.
2. Extract its `bjarkiUI` folder into the Forever client's `Interface/AddOns/` directory. Check that `Interface/AddOns/bjarkiUI/bjarkiUI.toc` exists.
3. Enable the addon and reload the interface. Use `/bui help` for the main commands and `/bdark` for Soft Dark controls.

Historical **0.2.340-leader-crown-nudge-test** nudged the native crowns horizontally. The current portrait-relative placement supersedes those native-relative offsets.

**0.2.341 buff-digit test:** For player buff/debuff timers with *public* remaining seconds, the three already-fixed digit cells may now use native-font glyph width calibration to keep the *visible numeral ink* from wobbling when a narrow `1` becomes a wide `8`. This only changes a supported, out-of-combat-prepared buff glyph's transparent inline spacing. If calibration fails, the original digits remain. Secret/native-fallback timers remain Blizzard-owned. No fonts, timers, frame anchors, other addons or settings are changed.

**0.2.342 compact party presentation:** Native compact party members (player and party1–4) now receive class-colored **names and health-bar fills**, plus the exact existing LoL-style status-text treatment (native font and size, no outline, a one-screen-pixel dark shadow). The native status/power numbers, resource colors, auras, portraits, party order and user Edit Mode layout stay untouched. This is not a new in-game option. [Changelog](CHANGELOG.md)

**v0.2.345 readable long buff timers:** The previous three fixed glyphs covered only public timers below 10 seconds. At 10 seconds and above, buffs used Blizzard's original proportional text, allowing visible digits to shift. This build applies the existing native-font equal-advance glyph map to *readable stock buff text* (seconds, minutes, hours and days), while preserving Blizzard's time formats, font, color, anchor, visibility and clock. Secret or unsupported values remain native; no extra timer or setting is introduced. Also includes the requested resting ZZZ X 49 → 48 adjustment.

**v0.2.346 action timer numerals:** The six action binding positions were fixed, but four individual numeral tracks (whole/tenths, seconds tens/ones) still printed proportional native digits. This build applies the existing validated font/scale-specific transparent-spacing map to those four **native duration-text binding formatters**. Their physical cell positions, original Blizzard fonts, colors, timer lengths, swipes, GCD filtering, and minute/hour units remain unchanged. A rejected/unsupported markup rule falls back to the original fixed-cell or native formatter; no independent timer is added. [Changelog](CHANGELOG.md)

**v0.2.347 native (non-raid-style) party frames:** Extends the existing bjarkiUI look to Blizzard's classic pooled `PartyFrame` members, separate from the compact raid-style party renderer. Each party member receives class-colored native names, health-bar fills and owner-colored pet health, the same outline-free LoL-style shadow treatment on native health/power status numbers, and Soft Dark's reversible 60% tint on decorative party/vehicle/pet frame art. Portraits, health/power values, icons, power colors, aura frames, UI layout and settings remain native. No in-game options or custom frame implementations.

**v0.2.348 classic party health material fix:** Native non-raid-style health fills use Blizzard's baked-green party atlas, so changing status bar RGB alone did not make them class colored in-game. The classic presenter now delegates to bjarkiUI's existing reversible health-material owner. It uses the stock colorable party health `-Status` atlas where available (including the party pet), and guarded desaturation when a vehicle uses a different stock health mask. Native names, text values, fonts, power colors, portraits, dark art and Edit Mode layout remain unchanged. [Changelog](CHANGELOG.md)

**v0.2.349 classic party aggro intensity:** The original native threat flash on each non-raid-style party member and their attached pet now receives the same 25% vertex-alpha policy as Player/Target/Focus. The separate **player pet attack-mode red pulse** (Blizzard's persistent additive `PetAttackModeTexture`, distinct from pet aggro) is now half as strong as before: 12.5% of native instead of 25%. Both leave the original atlas, attack/threat events, visibility, animation, tint, and positioning native. No additional options or timer loops.

## Current behavior

| Surface | Behavior and native fallback |
| --- | --- |
| Action and pet-action countdowns | Fixed digit cells retain the current native font. Tenths appear below 10 seconds; whole seconds continue through 90.99 seconds; rounded-up minutes begin at 91 seconds (`2m`), with hours/days at their existing boundaries. Blizzard still owns cooldown timing, swipes, countdown preferences and minimum/GCD policy. Unsupported fixed-cell paths use the guarded native countdown. |
| Player cast/channel timer | Restores the pinned 0.2.309 native duration-bound fixed-digit renderer for casts/channels; Blizzard's original `CastTimeText` is never cleared. The original timer remains visible whenever binding setup or native alpha handoff fails. Native font, settings and Edit Mode remain authoritative. |
| Player buff/debuff timer | Public short durations can use fixed tenths in the native font and native above/below/beside placement. An unchanged native font/anchor update retains already prepared cells in combat. Actual geometry changes defer to native text until safe preparation. Restricted identity, private anchors and forbidden frames retain their supported native route. |
| Tracked buff icons | Accessible native cooldown widgets receive the ten-second tenths threshold; timing, longer formats and visibility remain native. |
| Unit frames and party | Unit names, status typography, readable class colors, cosmetic labels and vertical compact-party ordering use guarded native presentation hooks. Compact party names/health fills are class colored and their native numeric text gets the same LoL-style outline-free shadow. Camelot level badge artwork stays hidden through native Show, SetShown and SetAlpha writes; the separate level number remains intact. Layout repairs touch displaced anchors and retain rollback state after partial failure. |
| Soft Dark and icon borders | Eligible native artwork receives reversible tinting or nameplate-style icon decoration. Restoration checks current ownership before replacing a later writer's work. |

Historical **0.2.339-zzz-right-of-secondary-test** placed the original resting animation beyond the upper-right secondary portrait. The .350 upper-left and .351 right-of-crown experiments were subsequently rejected; .352 hides the Z texture completely.

**0.2.338-zzz-inward-test** moves the mirrored player resting Zs 8 UI units to the right (toward the portrait rim), retaining their original vertical position and Blizzard animation. The cast-timer and level-ring fixes are unchanged. A verified ZIP is saved to Library → Addon Versions.

**0.2.337-zzz-integrated-test** includes the previously isolated ZZZ animation fix: the native player resting indicator is mirrored to the upper-left of the portrait, away from bjarkiPortraits' upper-right secondary circle. It does not change the art, animation, fonts, secondary portrait or saved layout. Earlier builds omitted the ZZZ module. [Changelog](CHANGELOG.md)

**0.2.336-level-ring-test** repairs the Camelot level-badge background/rim reappearing on player, target and focus. A Show-only hook missed SetShown/alpha updates; narrowly scoped hooks and lifecycle retries now suppress the native LevelBackgroundCircle without hiding the number or changing portrait artwork. Offline checks are not in-game verification. [Changelog](CHANGELOG.md)

**0.2.335-cast-recovery-test** rolls back only the destructive 0.2.334 cast text-mirror rewrite after a live Hearthstone cast showed no countdown. Native duration bindings preserve the fixed digit positions, and failed native alpha writes now recognize explicit `false` refusals. Source-level tests are not live validation. [Changelog](CHANGELOG.md)

Version **0.2.334** repairs a modeled buff-timer regression: native `UpdateDuration` can be followed by identical `SetFontObject` and `SetPoint` calls. Those calls formerly retired prepared fixed digits during combat. The new regression follows that complete sequence and checks visible text, fixed positions, zero redundant glyph-geometry writes and reuse after combat. Fixed action/cast timers, fonts, thresholds and settings are preserved. [Changelog](CHANGELOG.md)

Offline regressions do not establish live rendering, protected-call safety or reduced stuttering. The reported action/cast movement, occasional whole-second buffs, intermittent borders and historical Battleground color issues remain open until checked in the client. [Known issues and capture instructions](KNOWN_ISSUES.md)

## Diagnostics

Capture the affected state before `/reload` or `/buiicons`, which can reapply styling.

| Command | What it tells you |
| --- | --- |
| `/buitimers` | Aura-formatting outcomes and accessible-hook coverage, precise identity fallback reasons, plus cached action/cast renderer status. Counts describe observed bindings or writes, not unique spells or a live correctness verdict. |
| `/buiborders` | Public icon-skin coverage, missing owned rims and restoration state. It cannot certify private or inaccessible icons. |
| `/buicombat` | Player combat-icon anchor diagnostics. |
| `/bui colors` | Readable identity and health-color evidence for unit-frame investigations. |

For action/cast reports, capture while the affected cooldown or cast is active. Aura outcome counters survive a short aura expiring, but current button coverage may already have changed. [Diagnostic field guide](docs/TIMER_LIFECYCLE.md#reading-buitimers)

## Development and verification

Start with [AGENTS.md](AGENTS.md), then the [code map](docs/CODE_MAP.md). The two manifests load **16 runtime modules**. Current verification runs **36 top-level Lua scripts** (35 behavioral suites plus the manifest syntax script) under Lua 5.1 and Lua 5.4; the aura suite contains 219 cases. See [testing and packaging](docs/TESTING.md) for commands and the boundary between offline and live evidence.

- [Timer sources, native writers, hooks and cleanup](docs/TIMER_LIFECYCLE.md)
- [Default manifest](bjarkiUI.toc) · [Camelot manifest](bjarkiUI_Camelot.toc)
- [Package workflow](.github/workflows/package-addon.yml) · [Changelog](CHANGELOG.md)
- [Verified source identity and build evidence](docs/BUILD_VERIFICATION.md)

`ARCHITECTURE.md` records implementation history, including retired experiments. The 0.2.309 audit documents, `tests/snapshot-0.2.309/` and `tools/audit/` are historical reproduction material, not the current test or packaging entry point. Reproduce that audit at its [pinned revision](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78). Current source and top-level tests take precedence over historical descriptions. [Architecture history](ARCHITECTURE.md) · [Audit baseline](docs/AUDIT_BASELINE.md)
