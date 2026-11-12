# Working on bjarkiUI

This is the current **0.2.355-timer-spacing-recovery-test** development tree. Read the [code map](docs/CODE_MAP.md) for the affected surface, [timer lifecycle guide](docs/TIMER_LIFECYCLE.md) for countdown work, and [testing guide](docs/TESTING.md) for verification commands. Both TOCs define the same 16-module runtime load order. Current regression scripts live directly under `tests/`.

## Trace the displayed result

1. Identify the physical label, cooldown widget, texture or frame that the user sees. A saved Lua reference can be an alias to a region now owned by another button.
2. Trace the native data source and native writer before inspecting the addon post-hook. Include native setters that run **after** that hook; `.334` depends on the complete `UpdateDuration` → `SetFontObject` → `SetPoint` sequence.
3. Follow the ownership record, successful write receipt, binding generation and cleanup. Check what happens when a setter invokes a newer update before the older setter returns.
4. Verify displayed text/geometry and native calls in the fixture. Internal flags or aggregate assertion counts alone do not establish a correct presentation.

## Preserve these contracts

- Retain fixed action/cast timers, exact current timer fonts, native countdown settings and saved character settings. Action thresholds are tenths below 10, seconds below 91, then rounded-up minutes; do not apply that action policy indiscriminately to buffs or cast text.
- Keep action digit bindings on the existing native duration clock; only prepare calibrated single-glyph numeric rules when the font is safely readable, and never modify the separate decimal point/suffix formatters. Default to uncalibrated native strings if an inline-glyph formatter is refused.
- Action receiving cells must inherit the native label's relative effective scale and text scale, with scale-only changes using the existing stock handoff. Retry rejected mapped formatters only at existing safe typography epochs. Buff native-duration decimal formatters may use already calibrated fixed-width literals; prepare outside combat, recheck current label/owner/profile, and forward opaque results unchanged. Safe buff setup must refresh failed or inherited-scale-changed typography without rebuilding unchanged geometry or measuring on timer ticks.
- Keep native clock ownership. Forward opaque duration objects or formatted strings only to their supported native sink. Never infer hidden timing from spell names, guessed durations, inaccessible values or combat-log estimates.
- Treat unavailable, secret, false and zero as different results. A failed secrecy/permission probe is not permission to inspect or write a value.
- Keep restricted Target/Focus aura rows and private aura anchors native. `UnitAuraStyling.lua` is an intentional compatibility stub, not an unfinished custom-aura feature.
- Public native buff text >=10s may be padded only when its current formatted text is positively readable; never parse protected time or replace its native format. This adds a cosmetic native SetText on an existing aura refresh, so measure in-client performance.
- Prepare geometry safely and retain event-driven native timer updates. `.334` reuses an already complete public layout receipt in combat; it does not permit new geometry writes there.
- A cleanup may restore only state still owned by this presenter. Recheck the physical recipient after nested writes, label replacement and A → B → A reuse. Do not overwrite newer native text or another addon's appearance.
- For frame layouts, distinguish native geometry from the last accepted addon write. Preserve partial-failure rollback and retry behavior. Party reanchoring requires positive permission that combat lockdown and raid mode are off.
- Large-frame leader crowns use portrait-corner anchors: (5, 11) on Player and the screenshot-calibrated (-7, 11) on Target/Focus, converted through effective scales. Equal mirrored offsets in .350 did not establish equal visible rim clearance. Classic-party crown geometry is native X+4 at the original height and requires current pooled membership; the earlier X+2 remained crowded against the secondary circle in the live screenshot. The user removed resting Zs in .352: hide only the exact current PlayerRestLoop.RestTexture, reassert after native Show/SetShown, and retry safe discovery after login/world/resting/combat-exit updates. Keep the native resting state, XP, gold glow, animation owner and all indicator geometry separate. GuideIcons stay native.
- Classic pooled party and attached pet threat flashes must reuse the Player's existing 25% vertex-alpha observer; the player pet's separate persistent attack-mode pulse uses a quieter 12.5%. Never change native threat/attack visibility or event classification.
- Hide only current classic-party `PartyMemberOverlay.PVPIcon` faction/PvP badges. Prepare hooks outside combat; installed Show/SetShown observers may issue the same guarded cosmetic Texture Hide used by native level-ring suppression during combat. Recheck active pooled membership, exact current texture identity, public/nonforbidden access and positive non-raid mode. Do not add persistent alpha state or change native PvP flags, other group icons or compact/raid frames.
- Non-raid classic party health must use the existing native health-material ownership (colorable party -Status atlas or guarded desaturation). A raw SetStatusBarColor on the green baked-in artwork does not establish the class-colored visual requirement.
- Non-raid classic party frames belong to the pooled `PartyFrame.PartyMemberFramePool` (not the compact-party renderer). Style only positively identified physical member frames, preserve native status values/power colors, and tint only decorative art through the existing reversible Soft Dark owner. Reacquisition must not add duplicate native hooks.
- Preserve user-owned Edit Mode layouts. No preset files or automatic layout installation, replacement or activation.
- Compact party presentation is isolated to the native member list and may not repaint unrelated raid/nameplate frames, change native power/status values, or add in-game options.

## Verification and reporting

Use [tools/verify.py](tools/verify.py) with native Lua/luac, or the standalone commands in [TESTING.md](docs/TESTING.md). Use `tests.support.lua51` when running UI fixtures under Lua 5.1. The package workflow runs both supported interpreters. Put ad hoc reports and packages outside the checkout unless the task explicitly calls for a tracked artifact.

For a lifecycle repair, cover the relevant ordering matrix: native update before/after the hook, unchanged versus changed font/layout, combat entry/exit, same versus changed owner, refusal versus successful native write, and cleanup interrupted by a newer update. Keep tests tied to a concrete failing behavior; do not add redundant tests merely to raise totals.

Report separately what source inspection, Lua fixtures, package checks and live client observation establish. Passing mocks cannot close a rendering, taint or performance report. Keep unresolved live observations in [KNOWN_ISSUES.md](KNOWN_ISSUES.md), even when a modeled source defect is repaired.

## Historical material

The frozen `.309` audit documents (`docs/AUDIT_BASELINE.md`, `docs/CODEX_DEEP_AUDIT.md`, `docs/CODEX_START_PROMPT.md`), `tests/snapshot-0.2.309/` and `tools/audit/` describe a different 11-module source snapshot. Their no-change audit instructions and checksums belong to that historical audit, not ordinary authorized work on current main. `ARCHITECTURE.md` is chronological history; reconcile it with current source before reusing a claim. [Pinned .309 audit](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78)
