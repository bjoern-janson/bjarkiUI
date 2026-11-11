# bjarkiUI

**0.2.339-zzz-right-of-secondary-test for WoW: Forever** adjusts Blizzard's unit-frame labels, party layout, aura presentation and timers while retaining native artwork and fonts. Settings are saved per character in `bjarkiUISettings`. The addon does not install, replace or activate Edit Mode layouts.

## Install

1. Open a successful [Package addon run](https://github.com/bjoern-janson/bjarkiUI/actions/workflows/package-addon.yml?query=branch%3Amain) and download the `bjarkiUI` artifact.
2. Extract its `bjarkiUI` folder into the Forever client's `Interface/AddOns/` directory. Check that `Interface/AddOns/bjarkiUI/bjarkiUI.toc` exists.
3. Enable the addon and reload the interface. Use `/bui help` for the main commands and `/bdark` for Soft Dark controls.

## Current behavior

| Surface | Behavior and native fallback |
| --- | --- |
| Action and pet-action countdowns | Fixed digit cells retain the current native font. Tenths appear below 10 seconds; whole seconds continue through 90.99 seconds; rounded-up minutes begin at 91 seconds (`2m`), with hours/days at their existing boundaries. Blizzard still owns cooldown timing, swipes, countdown preferences and minimum/GCD policy. Unsupported fixed-cell paths use the guarded native countdown. |
| Player cast/channel timer | Restores the pinned 0.2.309 native duration-bound fixed-digit renderer for casts/channels; Blizzard's original `CastTimeText` is never cleared. The original timer remains visible whenever binding setup or native alpha handoff fails. Native font, settings and Edit Mode remain authoritative. |
| Player buff/debuff timer | Public short durations can use fixed tenths in the native font and native above/below/beside placement. An unchanged native font/anchor update retains already prepared cells in combat. Actual geometry changes defer to native text until safe preparation. Restricted identity, private anchors and forbidden frames retain their supported native route. |
| Tracked buff icons | Accessible native cooldown widgets receive the ten-second tenths threshold; timing, longer formats and visibility remain native. |
| Unit frames and party | Unit names, status typography, readable class colors, cosmetic labels and vertical compact-party ordering use guarded native presentation hooks. Camelot level badge artwork stays hidden through native Show, SetShown and SetAlpha writes; the separate level number remains intact. Layout repairs touch displaced anchors and retain rollback state after partial failure. |
| Soft Dark and icon borders | Eligible native artwork receives reversible tinting or nameplate-style icon decoration. Restoration checks current ownership before replacing a later writer's work. |

**0.2.339-zzz-right-of-secondary-test** moves Blizzard's original resting ZZZ animation to the **upper-right beyond the secondary portrait**, leaving height, animation and all previous cast/level fixes unchanged. The prior left-side position was a misinterpretation. The installable ZIP is saved in Library → Addon Versions.

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

Start with [AGENTS.md](AGENTS.md), then the [code map](docs/CODE_MAP.md). The two manifests load **14 runtime modules**. Current verification runs **29 top-level Lua scripts** (28 behavioral suites plus the manifest syntax script) under Lua 5.1 and Lua 5.4; the aura suite contains 217 cases. See [testing and packaging](docs/TESTING.md) for commands and the boundary between offline and live evidence.

- [Timer sources, native writers, hooks and cleanup](docs/TIMER_LIFECYCLE.md)
- [Default manifest](bjarkiUI.toc) · [Camelot manifest](bjarkiUI_Camelot.toc)
- [Package workflow](.github/workflows/package-addon.yml) · [Changelog](CHANGELOG.md)
- [Verified source identity and build evidence](docs/BUILD_VERIFICATION.md)

`ARCHITECTURE.md` records implementation history, including retired experiments. The 0.2.309 audit documents, `tests/snapshot-0.2.309/` and `tools/audit/` are historical reproduction material, not the current test or packaging entry point. Reproduce that audit at its [pinned revision](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78). Current source and top-level tests take precedence over historical descriptions. [Architecture history](ARCHITECTURE.md) · [Audit baseline](docs/AUDIT_BASELINE.md)
