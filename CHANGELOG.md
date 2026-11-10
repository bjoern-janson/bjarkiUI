# bjarkiUI test-build changelog

This log covers the synchronized post-launch local test builds. Older implementation notes and audit history remain in [ARCHITECTURE.md](ARCHITECTURE.md). Entries describe intended code behavior, **not** independently verified in-game outcomes.

## 0.2.323

- A new channel can take over the cast timer while the previous cast's cleanup is running. Empowered casts use the native duration object through hold-at-max.
- Shared buff labels discard saved text when a denied read leaves its age unknown.
- Vertical compact-party layout repairs only displaced anchors and rolls back the frames touched by a failed repair.

## 0.2.286 — combat-icon clearance test (2026-11-07)
- Player crossed-swords `AttackIcon` target is `TOPLEFT (76, -63)` against its native contextual frame: 12 UI units right, 1 down from Blizzard's XML. The preceding `/buicombat` output verified a former `(68, -63)` target was applied; the larger offset remains to be visually checked.
- Keeps the level labels at four UI units outward and bag/ammunition counts at native font size +3.

## 0.2.276–0.2.285 — typography, border and timer tests
- Applied the existing restrained status-text treatment to the pet frame (`.276`).
- Refreshed nameplate-style border geometry on public aura icons (`.277`, `.281`); **intermittent live border loss remains reported**.
- Positioned player/target/focus levels farther outside their frames (`.278`, `.284`); adjusted free bag-slot and ammunition number sizes (`.278`, `.279`, `.282`).
- Added recovery for native buff/debuff tenths below ten seconds (`.280`); **some live whole-second timers remain reported**.
- Applied and diagnosed player combat-icon cosmetic offsets (`.283`–`.285`).

## 0.2.265–0.2.275 — native aura styling experiments
- Suppressed native player aura fading, hid the buff-collapse arrow while retaining expanded buffs, and tested decimal formatting and small-icon cosmetics (`.265`–`.271`).
- Tried replacing forbidden target/focus aura rows via custom containers (`.272`–`.273`). **Retired the experimental replacement in `.274`** following a reported protected-action block; target/focus native aura rows remain untouched.
- Adopted Blizzard's nameplate mask/overlay appearance for accessible player aura, cast, and ToT/ToF icons (`.275`), while retaining native debuff-type indicators where readable.

## Scope and release status

`0.2.286-combat-icon-clearance-test` is the current source baseline, not a claim of stable release readiness. It preserves default Blizzard icon textures, the user's own Edit Mode layout ownership, and the original frame and action-button behavior. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for unresolved live reports.
