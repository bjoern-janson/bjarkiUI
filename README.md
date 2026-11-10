# bjarkiUI

**0.2.323 for WoW: Forever** adjusts Blizzard's unit-frame labels, party layout, aura presentation and timers while retaining native artwork and fonts. Settings are saved per character in `bjarkiUISettings`.

## Install

1. Open a successful [Package addon run on main](https://github.com/bjoern-janson/bjarkiUI/actions/workflows/package-addon.yml?query=branch%3Amain) and download the `bjarkiUI` artifact.
2. Extract its `bjarkiUI` folder into the Forever client's `Interface/AddOns/` directory. Check that `Interface/AddOns/bjarkiUI/bjarkiUI.toc` exists.
3. Enable the addon and reload the interface. Use `/bui help` for the main commands and `/bdark` for Soft Dark controls.

## What to look for in 0.2.323

- Player cast and channel timers use fixed-position digits. Empowered casts use their own native clock, including hold-at-max time. A new channel can take over while the old cast's labels are being cleared.
- A reused buff label can restore the current owner's timer. A failed text read with no trustworthy time discards stale saved text.
- Vertical compact-party ordering repairs the frames whose anchors changed. A single displaced pet can be repaired without rewriting the rest of the party.

Offline regression coverage includes nested cast callbacks, shared buff labels and partial party-layout failures. Visual spacing at different UI scales, combat restrictions and performance in a busy battleground still need live verification. [Known issues](KNOWN_ISSUES.md)

## Diagnostics

`/buitimers` reports recent aura timer formatting activity. `/buiborders` inspects border state, and `/buicombat` reports the player combat icon anchor. Capture the visible state before reloading or using `/buiicons`, which can reapply styling.

## For contributors

Use the [code map](docs/CODE_MAP.md) to find the writer and test for a specific symptom. [Agent guidance](AGENTS.md) · [Manifest](bjarkiUI.toc) · [Package and test workflow](.github/workflows/package-addon.yml) · [Changelog](CHANGELOG.md)

Earlier architecture notes document the decisions behind individual modules. The original 0.2.309 audit can be reproduced at its pinned revision. [Architecture history](ARCHITECTURE.md) · [Frozen audit](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78)
