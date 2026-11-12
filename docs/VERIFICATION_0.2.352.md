# Verification record for 0.2.352

Baseline: upstream `34cac43e15e281203dc81f64df084ed33b76f415` (0.2.351), source tree `b9b4a58d0cbb7bbe054ffa51b9c679dd731ca9b5`.

The user explicitly requested removal of the rested Zs after the .351 screenshot. The historical RestIndicatorPlacement module now hides only the original PlayerRestLoop.RestTexture and observes its Show/SetShown calls. It has no geometry, alpha, artwork, parent or animation writes. Crown geometry and other resting presentation remain separate.

## Evidence

- The updated resting fixture failed against .351 because the Z texture remained shown. All seven suppression cases then passed on native Lua 5.1.5 and Lua 5.4.6.
- All 36 current top-level suites and all 16 runtime modules passed the final native Lua 5.1/5.4 run. Local syntax compilation used each native interpreter's loadfile; no separate local luac invocation is claimed.
- The fixture checks native parent refreshes, explicit texture Show/SetShown, idempotence, positive safe combat permission, denied hides/hooks, secret/forbidden/missing regions, and native texture replacement/retirement.
- One scoped independent read-only review found no actionable issues.
- The installable archive contains 19 files, verified for integrity, exact manifest membership and byte identity to the tested source inputs.

## Package

`bjarkiUI-0.2.352-No-Rested-Zs.zip`

SHA-256: `a765263298c1493e7536ee7f84a638e330556efac270025622ee5e422643b2cb`

## Reproduction and limits

Use `python3 tools/verify.py` with native Lua/luac 5.1 and 5.4, optionally adding `--output ../bjarkiUI-0.2.352-No-Rested-Zs.zip` for a new archive outside the checkout.

Writes defer while combat permission is unavailable or lockdown is active. A native explicit texture re-show/new texture encountered in combat is reconciled on combat exit. Native resting refreshes normally show only the parent loop, which does not undo the hidden child texture. No local WoW: Forever client was available; the checks do not claim live taint or frame-time validation.
