# Verification record for 0.2.353

Baseline: upstream `062467db3293c65f91202e2abe69bc603857ce6f` (0.2.352), tree `96c5cb7349a09afe8834265bbc942f4f85be7325`.

The user's classic-party screenshot showed the crown crowded against the secondary portrait. The runtime change is limited to increasing PARTY_CROWN_NUDGE from 2 to 4. The known native BOTTOM-to-overlay-TOP anchor moves from (-8, -6) to (-6, -6). Native height and all pool, permission, ownership and retry handling remain unchanged. A separate read-only source/screenshot check found no reason to broaden the correction.

## Verification

- The updated existing crown fixture failed against .352's -8 offset before the runtime change; all nine crown scenarios now pass on native Lua 5.1.5 and Lua 5.4.6.
- All 36 current top-level suites and all 16 runtime modules passed final verification on both native interpreters. Local syntax compilation uses loadfile, without claiming a separate local luac invocation.
- Existing cases retain native reanchor, no cumulative drift, current membership, pool release/reacquisition, raid/combat permission, foreign-anchor and refusal coverage.
- The installable ZIP contains 19 files and passed archive integrity, exact manifest membership and byte-identity checks against tested source.

## Artifact

`bjarkiUI-0.2.353-Party-Crown-Spacing.zip`

SHA-256: `656a1e88f90637624a6c02f2ce904ca891bb0d09d815f96f8005363843e929dd`

## Reproduction and limits

Use `python3 tools/verify.py` with native Lua/luac 5.1 and 5.4. Optionally add `--output ../bjarkiUI-0.2.353-Party-Crown-Spacing.zip` for a new archive outside the checkout.

This is a small optical adjustment based on the live screenshot. No local game client was available, so the corrected visible gap still needs in-client confirmation.
