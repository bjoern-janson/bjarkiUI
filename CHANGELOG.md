# bjarkiUI test-build changelog

This log covers the synchronized post-launch local test builds. Older implementation notes and audit history remain in [ARCHITECTURE.md](ARCHITECTURE.md). Entries describe intended code behavior, **not** independently verified in-game outcomes.

## 0.2.338-zzz-inward-test — tuck the rested Zs closer to the portrait

- The native Blizzard resting ZZZ animation remains on the upper-left, but its mirrored horizontal anchor moves **8 UI units inward** (representative coordinate -20 → -12) with exactly the same vertical anchor.
- Cap the inward offset at 2 UI units left of portrait center, preventing a narrow/scale-dependent placement from crossing to the secondary portrait's side.
- Change only `RestIndicatorPlacement.lua`, version metadata, and its focused positioning regression. No cast, level, portrait, font, frame, skin, timer, or saved Edit Mode changes.
- Verified the 17-file installable ZIP against branch sources; Lua 5.4 compiled all 14 modules, and 13 local resting-position scenarios passed. Live pixel placement remains to be checked.

## 0.2.337-zzz-integrated-test — include the missing rested indicator fix

- The previous 0.2.336 ZIP contained the level-ring and cast-timer repairs but **not** the earlier rested-ZZZ change, which remained in separate draft PR #4. The player resting Zs therefore could not have moved.
- Include the already tested original Blizzard `PlayerRestLoop.RestTexture` mirror in the same package as the existing level-ring and cast fixes. The animation remains Blizzard-owned and only the validated native CENTER anchor is horizontally reflected across `PlayerPortrait` (upper right → upper left).
- Preserve the original 0.2.336 level-ring behavior and 0.2.335 cast-timer recovery unchanged, with no custom art, additional timers, or Edit Mode layout changes.
- Add the existing nine-case rested-portrait regression suite alongside the level-ring suite. Live optical positioning in WoW: Forever still needs confirmation.

## 0.2.336-level-ring-test — keep Camelot level badge hidden

- Fix the level background/rim returning around player, target and focus level numbers. The existing `LevelBackgroundCircle` hide observed native `Show` only, missing direct `SetShown` and `SetAlpha` restoration.
- Guard the exact native Camelot ring by hiding it and holding alpha at zero. Observe `Show`, `SetShown`, and `SetAlpha` via secure post-hooks, with separate retryable registrations, refusal-safe writes, and a recursion guard. Leave `LevelText`, frame art, protected/secret objects and other textures untouched.
- Reassert this narrowly scoped presentation at native UI load, target/focus changes, Edit Mode refresh, scale changes and combat exit. No per-frame update or global frame scan.
- New isolated 13-case Lua regression suite tests native re-show/alpha, ring recycling, refused setters, forbidden objects, hook failures, and stable geometry. Live client verification remains pending.
- The prior cast-timer recovery and all other timer/portrait behavior are unchanged.

## 0.2.335-cast-recovery-test — restore the cast timer

- The 0.2.334 cast glyph renderer could clear `PlayerCastingBarFrame.CastTimeText` while its replacement became invisible or failed to paint. A live Hearthstone cast displayed no countdown.
- Restore the pinned 0.2.309 cast module's native duration-to-fixed-digit bindings and preserve Blizzard's original timer text. A failed binding or alpha handoff returns to the native text; source text is never cleared. Preserve native font, cast-time option, visual anchors, and no addon OnUpdate loop.
- Handle native `SetAlpha` returning `false` as a rejected hide or restore, not a successful handoff. Reuse the pinned regression suite with explicit false-return cases.
- This only changes the cast timer path. Action cooldowns, buff timers, portraits, borders, frame geometry and Edit Mode layouts are unchanged. Live client rendering remains to be verified.

## 0.2.334

- Retain prepared fixed buff digits when the native duration update repeats an unchanged font and anchor during combat. Identical layouts need no glyph geometry writes; actual changes still defer safely to native text.
- Add the missing full native font-and-anchor update sequence to the aura regression suite, including repeated combat updates and recovery.
- Reuse the prepared layout only with unchanged native font, physical owner/generation and public geometry, and all three glyph anchors complete. The regression verifies the displayed tenth, fixed positions, zero redundant geometry writes and post-combat region reuse.
- Preserve fixed action/cast timers, fonts, countdown thresholds and settings. Live rendering remains unverified.

The current regression set is 27 top-level scripts under both Lua 5.1 and Lua 5.4, including 217 aura cases and the 13-module manifest syntax script. [Testing and packaging](docs/TESTING.md) · [Recorded build evidence](docs/BUILD_VERIFICATION.md)

## 0.2.333

- Preserve fixed action/cast timers, current fonts, and existing countdown thresholds.
- Retry failed action minimum-gate setup at safe lifecycle boundaries, retaining successful calibrations.
- Refresh existing action digit regions when native font/style changes.
- Respect native buff timer orientation when displaying fixed tenths.
- Remove the duplicate combat-exit name-color pass while retaining current-recipient reconciliation.
- Offline regressions verify these paths; live rendering and hitch improvement remain unverified.

## 0.2.332

- Keep fixed action/cast timer rendering. Cast glyphs use a bounded frame with the native anchor, independent of the cleared source text.
- Configure the action minimum-gate probe as a complete native binding and distinguish its failure stages. Countdown precision, minimum/GCD behavior and fonts are preserved.
- These changes address modeled failure paths; in-game confirmation is pending.

## 0.2.328

- Action-button digit regions fit their rendered glyphs at the button’s scale. Their fixed positions are retained when font outlines would exceed the earlier text-box width. Optional native spacing is limited to the available display width.

## 0.2.327

- The player cast bar keeps Blizzard’s cast-time label visible across repeated casts and channels. Its native update supplies the current spell’s text. bjarkiUI adds measured spacing to readable digits in proportional fonts.

## 0.2.326

- Action buttons recover fixed digits after a temporary clock or binding failure. A verified stock visibility refresh can resume an existing presenter.
- Native countdowns and unit-suffixed labels use measured spacing in their original font when the client can verify it.

## 0.2.325

- A new player cast or channel checks its own clock even if the previous spell used the same cast mode. Blizzard's cast-time label stays available when the replacement digits are blank, hidden or unreadable.
- Cast cleanup restores the stock timer after an addon-owned hide when its alpha temporarily becomes unreadable.

## 0.2.324

- Action-bar cooldowns display rounded-up minutes above 90 whole seconds. The countdown switches from `2m` to `90`, then uses tenths below ten seconds.

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

`0.2.334` is the current source baseline, not a claim of stable release readiness. It retains fixed action/cast presentation, current timer fonts and settings, native timing ownership, default Blizzard icon textures and the user's own Edit Mode layouts. Entries for older versions describe their historical behavior; some implementations have since been superseded. See [KNOWN_ISSUES.md](KNOWN_ISSUES.md) for unresolved live reports and [CODE_MAP.md](docs/CODE_MAP.md) for the current implementation.
