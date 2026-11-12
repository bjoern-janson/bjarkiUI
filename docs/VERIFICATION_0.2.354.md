# Verification record for 0.2.354

Baseline: upstream `c3ed5ed2b618ee1c1351352ac1fcbc9b22679106` (0.2.353), tree `f2fc602601b4ecfa0278a9f33e3a5916a89bc1a4`. The user approved .353 party crown spacing in the subsequent screenshot.

## Native surface and change

The requested shields are `PartyMemberOverlay.PVPIcon` on the native classic-party pool. [Native UpdatePvPStatus](https://github.com/Gethe/wow-ui-source/blob/297d7aaaa736f346b3e036f38ee088eaf7f8c07f/Interface/AddOns/Blizzard_UnitFrame/Mainline/PartyMemberFrame.lua) selects Alliance/Horde/FFA artwork and calls Show; UpdateMember and UNIT_FACTION invoke it. No separate honor/prestige region exists on this path.

ClassicPartyPresentation now hides only that exact current texture and observes its Show/SetShown methods. It reuses the existing pool, events and lifecycle refreshes. Hooks prepare outside combat; installed callbacks perform guarded cosmetic Texture Hide during combat, following the existing level-ring suppression pattern. Callbacks recheck active membership, current path identity, public/nonforbidden region access and positive non-raid mode. No alpha state or geometry changes are introduced.

## Verification

- The new visible-state assertion failed against .353 before implementation. Independent review then caught that the initial combat gate allowed native Show to revive the badge; the revised combat regression failed before that gate was corrected.
- All 17 classic-party scenarios pass on native Lua 5.1.5 and Lua 5.4.6, including Alliance/Horde/FFA redraws, combat Show/SetShown, pool release/reacquire, region replacement, nonparty/raid reuse, missing/secret/forbidden permission and refused hides/hooks.
- The reviewer confirmed the combat re-show finding was resolved in the final diff. No persistent alpha state was added.
- All 36 current top-level suites and all 16 runtime modules passed final verification on both native interpreters. Local syntax compilation used loadfile; no separate local luac invocation is claimed.
- The 19-file installable ZIP passed integrity, exact manifest membership and byte-identity checks against tested source.

## Artifact

`bjarkiUI-0.2.354-No-Party-Faction-Icons.zip`

SHA-256: `e67bd8437fc0ff6454d041c129053048014826c76a1301b3af395378beb31371`

## Reproduce and limits

Use `python3 tools/verify.py` with native Lua/luac 5.1 and 5.4, optionally adding `--output ../bjarkiUI-0.2.354-No-Party-Faction-Icons.zip` for a new archive outside the checkout.

Initial discovery/hook preparation waits for positive out-of-combat permission. Native Hide refusals remain retryable through existing safe lifecycle refreshes. No local WoW: Forever client was available, so actual rendered visibility and protected-call behavior remain client follow-ups; fixtures do not certify taint safety or frame time.
