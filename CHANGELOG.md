# bjarkiUI test-build changelog

This log covers the synchronized post-launch local test builds. Older implementation notes and audit history remain in [ARCHITECTURE.md](ARCHITECTURE.md). Entries describe intended code behavior, **not** independently verified in-game outcomes.

## 0.2.353-party-crown-spacing-test — classic party crown clearance

- The live party-frame screenshot shows the leader crown crowded against the secondary portrait. Increase the classic-party horizontal adjustment from native X+2 to X+4: two additional UI units toward the bars.
- Keep the native crown height and attachment, current pooled-member/non-raid/combat guards, accepted-write receipts and single hook. This is a narrow optical correction; no new layout mechanism is added.
- Retain the .352 rested-Z removal and current player/target/focus crown profiles.

## 0.2.352-hide-rested-zs-test — remove the rested Z animation

- Hide only the original player `PlayerRestLoop.RestTexture`, as requested after the .351 screenshot. Retire all Z positioning code while keeping the existing module/manifest path for normal addon installation.
- Reassert hidden state after the texture's native Show/SetShown calls, with one retryable hook per method and physical texture. Native parent-frame refreshes cannot undo the child texture's own hidden flag.
- Safely discover the current region on login, world entry, resting updates, Blizzard unit-frame load and combat exit. Skip forbidden/secret regions and defer writes during combat; ignore retired texture callbacks after region replacement.
- Preserve crown positions, native resting/XP state, the separate resting glow, original animation owner and other .351 presentation. No polling, alpha writes or replacement art.

## 0.2.351-portrait-spacing-test — crown clearance and adjacent rested Zs

- The .350 live screenshots showed target/focus crowns touching their secondary rims while the player crown had clearance. Keep the player gap at 5 portrait units and move target/focus from -5 to -7 at the same height. This is a screenshot-calibrated optical correction; source inspection does not establish the exact native renderer/scale cause of the unequal visible gaps.
- Replace the detached upper-left Z placement with the user's right-of-crown fallback. Anchor the original RestTexture CENTER to the native player LeaderIcon RIGHT, using half the actual Z texture width plus two portrait units for X and zero for Y. The bounding edges stay adjacent even while the crown is hidden.
- Recalculate owned Z placement on existing safe scale/layout updates; leave foreign anchors and unavailable/forbidden/secret geometry untouched. Native artwork, animation and visibility remain unchanged, with no polling or replacement textures.
- Classic-party crown X+2 and all other .350 behavior remain intact. Rested fixtures now check scaled physical edge adjacency and center alignment instead of only non-overlap. Live optical confirmation remains pending.

## 0.2.350-portrait-indicators-test — mirrored crowns and separate resting Zs

- Use target/focus crown placement as the reference, two UI units farther inward toward the name/health bars. Player and Target/Focus use mirrored portrait-relative corners with the same height and gap, converted through actual portrait/texture scales.
- Move the original rested Z flipbook from +48 to -48 portrait units, preserving native height, art, animation and visibility. This mirrors placement across the main portrait, separating it from the upper-right secondary circle and crown. The original Z artwork itself is not reversed.
- Shift each active classic-party member's original crown two units right at its native height. Reuse the existing pool discovery and one private FrameLabelTweaks helper; native reanchors retain one hook and released/nonparty members cannot keep applying the offset.
- Foreign, forbidden, unknown-permission and combat-time geometry remains guarded. Guide/role/PvP icons, portrait frames, .349 threat intensities, health materials, fonts and timers retain their previous behavior.
- Existing real-module crown/rest fixtures cover mirrored geometry, mixed scales, native reset/refusal, no cumulative drift, full Z-texture clearance, actual TOC ordering, pooled reuse and raid permission. Full 36-suite runs passed on native Lua 5.1.5 and 5.4.6. The subsequent live capture rejected this layout; .351 supersedes its crown spacing and left-side Z placement.

## 0.2.349-party-aggro-visuals-test — party threat parity, less aggressive pet attack mode

- Native `PartyMemberFrame.Flash` and `PartyMemberPetFrame.Flash` use the **same 25%-strength native threat-flash treatment** already applied to Player/Target/Focus. A shared private callback reuses the existing weak-key alpha observer and retains one hook per physical pooled texture across group, vehicle and Edit Mode updates.
- The continuously pulsing, additive-red `PetAttackModeTexture` on **the player's pet** is a separate *attacking* indicator, not the actual pet threat frame. Reduce only that pulse to **12.5% native strength** (formerly 25% in bjarkiUI); keep the genuine `PetFrameFlash` at 25%, matching the player.
- No new threat calculations, visibility toggles, new event loop, CVar, font, frame geometry or replacement art. Existing class health fills, party colors, Soft Dark, cooldowns and ZZZ remain unchanged.
- A new test suite executes the existing native alpha routine and the classic party module, verifying the correct textures are styled once, native pulses scale without multiplying, attack mode has distinct lower alpha, and unrelated status/icon textures remain untouched. Live WoW: Forever visual approval remains outstanding.

## 0.2.348-classic-party-health-material-test — class color requires the health material too

- In-game screenshot shows **green non-raid party health bars** despite v0.2.347's attempts to set class RGB. The underlying `UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health` atlas is precolored green; simple vertex/status-bar tinting is insufficient (the same issue previously fixed on Player/Target/Focus).
- Extend the existing native `nativeHealthStyle` reversible colorable-material mapping to Blizzard's *original* `UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status` asset (available in Blizzard's PartyFrameTemplates.xml), with the matching party-pet atlas. Vehicle fills retain their native atlas and use the already guarded desaturation route.
- Export one tightly scoped `ApplyClassicPartyHealthColor` helper to call the same ownership observer/material setup and class RGB path; classic party presentation no longer does standalone SetStatusBarColor. It positively checks the current physical bar's unit, and never recolors unrelated raid/party5 bars.
- Add four source-backed health-material cases (native party atlas, pet atlas, vehicle desaturation, and unrelated-frame refusal), plus a classic-party test that requires a colorable material instead of checking RGB alone. Total 123 native-health ownership cases and 12 classic-party cases pass on Lua 5.1/5.4.
- All other v0.2.347 visual surfaces and timings are untouched. **Live visual confirmation remains required.**

## 0.2.347-classic-party-presentation-test — native party frame visual parity

- Extend styling to **non-raid-style party frames**. These are dynamically pooled `PartyFrame.PartyMemberFramePool` members, not the compact `CompactPartyFrame.memberUnitFrames` used for raid-style party.
- New isolated `ClassicPartyPresentation.lua` applies Blizzard class RGB to native party names and health bars and to attached pet-health fills, reasserting after the original setters, vehicle/party changes and pool reuse. Non-party frames are excluded. Unknown/secret/forbidden units remain native.
- Reuse the existing `installStatusFont` presentation for health/power Center/Left/Right and known numeric status regions. Native text, values, fonts, size, positioning and power colors remain unchanged; outline-free black one-screen-pixel shadow matches the primary frames.
- Expand the existing reversible Soft Dark pass to **decorative native party/vehicle/pet artwork only**, retaining original atlas, visibility and undo ownership. Do not darken portraits, debuff/PvP/leader icons, health fills, masks, overlay statuses, or aura art.
- No new options, new OnUpdate, frame replacements, saved Edit Mode layout or per-update generic UI tree scans. The existing 15 runtime modules and timers are otherwise unchanged. Full Lua 5.1/5.4 CI and in-game visual parity are distinct validation.
- Two new focused tests cover native pool changes, class redraws, nonparty isolation, status treatment, theme opt-out, combat deferral and narrow tint scope.

## 0.2.346-static-action-digits-test — stabilize ink inside action-bar numeral cells

- The six native action text bindings had fixed positions, but four of them still rendered ordinary proportional single-glyph numerals. The visible ink of narrow `1` and broad `8` could shift even though their FontStrings never moved.
- Reuse `ActionTimerSpacing.GetFixedTimerGlyphs` for the four numeral binding formatters (decimal integer/tenth and two-digit seconds tens/ones). Validate native numeric rule output at each transition before changing a binding. The decimal separator and minute/hour/day suffix formatters remain unchanged.
- Cache one set of four calibrated native rule objects per usable font/scale profile and reuse it across buttons. A naturally tabular font requires no extra formatter. Unsupported font measurements or rejected numeric markup retain the proven uncalibrated bindings.
- A native font/scale change rebinds the four formatters only after handing visibility back to stock, then reacquires the existing fixed presenter. Never read a restricted cooldown, add Lua time arithmetic, change fonts or frame geometry, or introduce an OnUpdate.
- New targeted regression tests cover the complete 9.9 → 10 → 90 → 91s handoffs, all numerals, font-profile reuse and rejected markup. Offline formatter output isn't proof of live ink geometry; confirm visually and check combat FPS.
- All existing buff, cast, portrait, crown, ZZZ and compact-party styles remain unchanged.

## 0.2.345-static-buff-text-test — cover long-buff numeral shift

- Static three-cell buff decimals previously applied only under 10s; the readable 10s+ native stock FontString still used proportional digits and could visibly move. This build also applies the prepared native-font transparent-spacer mapping to readable long seconds/minutes/hours/days while retaining their exact native format, anchor, font, color, visibility and clock.
- Never parse secret text/time or guess durations; native/unsupported and unprepared layouts remain untouched. A guarded SetText follows Blizzard's existing UpdateDuration; no new timer/OnUpdate or combat-time geometry writes. The extra cosmetic native text write is an explicit in-game performance check.
- Resting ZZZ moves just 1 UI unit left: portrait-relative X 49 → 48, same height and Blizzard animation. No crown, party, portrait, cast or action timer changes.
- Dedicated stock buff numeral regression suite and updated rested-position assertions. Live visual/static behavior still needs confirmation.

## 0.2.344-rested-zzz-nudge-test — tiny leftward adjustment

- Move the original resting ZZZ texture 3 UI units left while keeping it to the right of the secondary portrait (portrait-relative X = 52 → 49; prior repository baseline X = 72). No Y, animation, frame ownership, class color, party styling or other timer changes.
- Regression expectations now cover the requested X=49 offset. Live optical placement remains to be confirmed.

## 0.2.342-party-presentation-test — class colors and LoL text on compact party frames

- Extend bjarkiUI presentation to the Blizzard-owned compact party member frames (player, party1–4); these use `frame.name`, `frame.healthBar` and `frame.statusText` instead of normal Player/Target unit-frame fields.
- Class-color each actual member's name and health-bar fill using Blizzard's `C_ClassColor` source or a verified readable `RAID_CLASS_COLORS` fallback, and reapply after the native name/health refresh. Respect changing/reused unit tokens and never style unrelated compact raid/nameplate frames.
- Reuse bjarkiUI's existing status typography routine on the compact status region and known native health/power text regions: native face, size, color, text, anchors and visibility remain; outlines are removed and a dark 1-screen-pixel shadow is applied when safe.
- No new commands/settings, extra clocks, per-frame event loops, custom frame replacements, status-value changes, status preference overrides, resource-bar recoloring or Edit Mode layout changes.
- New dedicated party regression suite covers five class colors, native redraws, nonparty isolation, membership replacement, hook idempotence, and native typography parity. Twelve more exhaustive local scenarios passed on Lua 5.3; live WoW: Forever confirmation is pending.
- All prior v0.2.341 buff-digit, crown, ZZZ, cast and level-ring behavior is preserved.

## 0.2.341-buff-glyph-stability-test — stabilize ink inside fixed buff digits

- User reported returning left/right wobble on player buff countdown numerals. The crown update did not change the buff renderer.
- Existing buff cells had fixed anchors and centered FontStrings, but a proportional Blizzard font renders narrow `1` and broad `8` with different ink widths. Reuse the already validated native fixed-glyph calibration helper, with invisible inline spacers, **only in the three public short-buff digit cells**. Decimal punctuation and each cell's native font, scale, tint, color, anchor, and timing remain unchanged.
- Upgrade that glyph calibration cache to 16 bounded font/scale profiles, preventing repeated font probing when differently sized buff icons alternate. Calibration happens on safe preparation **outside combat** and never on timer ticks.
- Invalid/secret/inaccessible native font or unsupported inline markup keeps the existing plain-glyph behavior. No additional clock, polling, slash commands, font replacement, or protected duration reads.
- Two additional aura regression cases verify digit mapping/constant anchors and unsupported calibration fallback; action-spacing tests check alternating cached profiles. Local Lua 5.4 syntax plus focused code-path tests passed; **live rendering and actual wobble root are not yet verified**.
- Existing crowns, ZZZ, cast timers, level rings and all other visual presentation retain their v0.2.340 behavior.

## 0.2.340-leader-crown-nudge-test — minimal leader crown alignment

- Adjust only the native LeaderIcon position: **Player +2** UI units right, **Target/Focus −2** UI units left.
- Retain each crown's existing vertical anchor, artwork, visibility, native relative frame and one-point attachment. GuideIcon, role/PvP icons and all portraits are unchanged.
- Reuse FrameLabelTweaks' out-of-combat guarded native geometry and receipt tracking; observe subsequent native SetPoint without cumulative drift, and retry on existing lifecycle events.
- Ten isolated Lua 5.4 runtime regressions passed locally; added focused source regression suite. The 17-file installable ZIP has verified source identities. Live client optical alignment remains pending.

## 0.2.339-zzz-right-of-secondary-test — ZZZ belongs past the second portrait

- Correct the mistakenly left-side ZZZ placement. The requested visual order is **player portrait → secondary portrait → native resting ZZZ** from left to right.
- Reposition only the original `PlayerRestLoop.RestTexture` at +72 portrait-relative UI units horizontally, to the upper-right beyond bjarkiPortraits' secondary circle. Preserve its original vertical coordinate, flipbook animation, artwork, alpha, visibility and native frame ownership.
- Guard unknown/secret/native-left layouts, reanchors, combat deferral and UI-scale differences. No more mirroring the ZZZ's position to the left. The original texture itself is not flipped.
- Scope changes to the resting ZZZ source, its test, version metadata and documentation. All other runtime modules match the previous .338 package byte-for-byte.
- Local verification: 14 runtime modules parse with Lua 5.4, 13 dedicated placement scenarios pass, and the installable 17-file ZIP has validated structure and hashes. In-game optical check remains pending.

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
