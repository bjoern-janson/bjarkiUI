# Known issues and bugs

Current test branch is **0.2.358-timer-gate-prewarm-test**, based on main 0.2.335-cast-recovery-test. The repairs below are supported by source inspection and offline fixtures; they do not close the recorded live reports. [Current verification evidence](docs/VERIFICATION_0.2.358.md) · [Timer lifecycle and diagnostics](docs/TIMER_LIFECYCLE.md) · [Testing guide](docs/TESTING.md)

## 0.2.358 idle action minimum-gate preparation — current live follow-up

The user reports .357 is still not static and buff decimals are not working. The new capture shows short buffs at `2 s` and `0 s`; aura diagnostics are `native=0`, `fallback=11`, `last=aura ID secret`, `readable-writes=21894`, `hooked=48/48`. Action diagnostics show `cells=1 stock=14 idle=82`, 12 minimum-read-denied fallbacks, and named `gate-unsupported/combat-cold` examples for ActionButton3 and ActionButton9. ActionButton6 has a separate `unavailable` receipt. All four glyph and full-formatter profiles now report plain/available.

A source reproduction matches the cold-gate stage: a safe event discards a failed minimum gate, but unchanged prepared idle actions return before preparing a replacement. First restricted use in combat cannot create it. The .358 repair prepares the current native profile during safe scans and native minimum changes, including idle color changes. No minimum/GCD policy or calibration acceptance rule is relaxed. A captured cold profile can also arise from cache eviction or a genuinely new combat-only setting; the single-profile prewarming correction does not claim to cover every possible cause.

Two ordinary fallback sequences can lose their diagnostic reason: rejected shutdown of a publicly zero clock, and a pending style recovery followed by native Clear then SetCooldown. They now retain public stage names, without claiming either unobserved prerequisite occurred on ActionButton6.

The native whole-second buff path remains a separate confirmed limitation. Existing bjarkiUI already disables collapsing and consolidation; those are not replacement compatibility blockers. A [native helpful-buff-row proposal](docs/NATIVE_BUFF_ROW_DESIGN.md) records the supported duration delegate and actual remaining ordering, temporary-enchant, private-aura and Edit Mode considerations. No replacement row is installed in .358. Live digit placement and protected-client behavior remain unverified. [Verification](docs/VERIFICATION_0.2.358.md)

## 0.2.357 timer handoff recovery — live report remains open

The supplied `.356` `/buitimers` capture reports `actions cells=0 stock=2 idle=95`, both sampled buttons as `unavailable`, and zero minimum-read-denied/below-minimum counts. The action reason can be lost after binding succeeds but visibility handoff fails; these counts alone do not identify why the native setter/readback failed. A source reproduction additionally shows that a first refused hide does not retain the fallback required for the next native cooldown update to recover.

The .357 repair retains that prepared fallback, reports hide-write/readback/restoration stages, prevents acquisition inside an open visibility transaction, and yields when binding cleanup invokes a newer visibility writer. Source regressions cover the resulting displayed cells, ordinary native update recovery and nested writes. They do not establish the cause or resolution of the live refusal.

The capture also reports four plain glyph profiles but four unavailable full action formatters at `layout`. Naturally tabular font measurements combined with pixel-rounded line widths reproduce this unnecessary rejection. The exact original formatter now returns after successful glyph preparation. This is an identity operation: it corrects misleading optional preparation failure, but does not by itself activate cells or prove optical numeral stability.

All 48 accessible ordinary aura hooks were installed; `readable-writes=53419` includes both cell and original-label decimal success. No native-duration success was recorded, 12 current states had recorded fallbacks, and the latest reason was `aura ID secret`. That last reason is not proof that all 12 shared it. The existing ordinary FontString exposes no supported below-ten-only formatter for a secret-ID aura. Native custom aura containers provide a separate supported architecture, but create new native-owned buttons and do not automatically preserve the legacy row's saved layout, ordering or inputs. The current rows remain unchanged; missing secret-ID decimals and observed moving buff digits remain open. [Native API evidence and scope](docs/VERIFICATION_0.2.357.md)

## 0.2.356 performance cleanup — offline evidence, live cost still open

The .355 performance parse identified temporary protected-lookup functions on active timer paths and redundant NPC native-color discovery. The .356 cleanup targets that reproduced work while preserving presentation and native ownership. Its [comparison and verification](docs/VERIFICATION_0.2.356.md) distinguish Lua CPU samples, GC-stopped heap growth and native-call counts from live frame times or addon memory. Soft Dark's combat-exit discovery remains because a settled tint record does not prove that all current native artwork has been discovered. Existing timer rendering reports below remain open; this patch does not establish their in-client resolution.

## 0.2.355 timer spacing recovery — live follow-up required

The .354 screenshots show a short player buff displaying `2 s` on one application and `1.7` on the next; the user reports moving digits even when decimals appear, and action-bar digits often or always moving. The second screenshot establishes decimal availability on that application, not which renderer supplied it.

Source fixtures reproduced three buff gaps: the public-identity native-duration route used plain `%.1f` despite a prepared glyph map; a failed optional map was not retried on unchanged safe setup; and inherited effective-scale changes could retain a map measured at the old absolute scale. The .355 correction covers that native decimal route and safe typography recovery. Action replacement cells also omitted native label scale/text scale, and rejected mapped action formatters outlived safe retry epochs; these source contracts are repaired without asserting they caused the pictured client behavior.

Secret or missing aura identity can still retain native whole seconds. No supported alternate identity/clock source was established. Native action minimum-gate calibration also remains guarded: the exact client mapping between synthetic duration objects and cooldown-widget totals is not established by the Lua source, so its accepted mapping is not broadened speculatively. Cached typography-stage diagnostics can distinguish preparation failures from an active fixed renderer without reading hidden timings. Check actual buff and action digit stability across applications, combat and scale changes; local fixtures cannot close the live rendering/performance report.

## 0.2.354 classic-party faction badges — client follow-up

The user requested removal of the Alliance/Horde shield beside classic-party portraits. The current build hides the original PVPIcon texture and its native visibility refreshes; the same physical region also supplies the FFA badge. Initial hook preparation waits for positive out-of-combat permission. Installed callbacks can reassert guarded cosmetic Hide during combat and check current pool/path ownership and non-raid mode. Failed native calls remain retryable. Offline fixtures cover native faction redraws, combat refreshes and frame reuse; no local client was available to validate the resulting display.

## 0.2.353 classic-party crown clearance — visually approved

The current live screenshot shows the classic-party crown crowded against its smaller secondary circle. The previous native X+2 nudge was insufficient. The new X+4 profile shifts the crown two more UI units right at its existing height. The user's subsequent screenshot and 'nice' response approved this spacing. The native X+4 profile is the current baseline.

## 0.2.352 rested Z removal

After the .351 screenshot, the user requested complete removal of the Zs. The current build hides only the original rested Z texture and retires both placement experiments. Native resting state, XP and separate frame glow remain active. Suppression is reapplied after native texture visibility writes and normal safe lifecycle updates. Geometry/visibility writes defer during combat; a new texture or explicit native texture re-show encountered there is reconciled on combat exit. Offline coverage checks this behavior; no local game client was available.

## 0.2.351 crown spacing — Z placement superseded by .352

The .350 in-game screenshots rejected the earlier layout: target/focus crowns touched their secondary circles while the player crown had clearance, and the left-side Zs looked detached. Equal mirrored anchor offsets were insufficient to establish equal visible spacing. Both .248 and .252 bjarkiPortraits sources use the same large-frame secondary geometry; no exact native renderer cause for the crown asymmetry was established.

The correction preserves the player crown and gives target/focus two more portrait units inward (-7 instead of -5). It uses the user's right-of-crown alternative for the original Z animation, with a two-portrait-unit gap between native texture bounds and aligned centers. This replaces .350's fixed X=-48 placement. Offline fixtures establish the chosen geometry, ownership and lifecycle rules; confirm the optical target/focus gap and animated Z appearance in the client. Classic-party crown X+2 is unchanged.

## 0.2.349 classic party threat flash and player pet attack-mode pulse — visual verification pending

The non-raid-style party `Flash` and attached `PetFrame.Flash` textures previously had no bjarkiUI alpha scaling, unlike the Player's 25% intensity. They now share the native vertex-alpha observer. The player's own pet has two visually overlapping red states: true threat (`PetFrameFlash`, still 25%) and its continuously animated attack-mode `PetAttackModeTexture` (new 12.5% intensity, down from 25%). These are independent; no threat/event state is altered. The exact overly-bright in-game case was not identified by screenshot, so visually confirm which indicator appears too strong.

## 0.2.348 non-raid-style health still green — material-level repair (live check pending)

The first in-game v0.2.347 screenshot showed the classic party art darkened but health bars still green. The bug was in treating `SetStatusBarColor` as sufficient without changing the health fill's baked-green source material. The v0.2.348 patch delegates to the established native health-material ownership and restoration path and chooses the existing Blizzard colorable `-Status` health atlas or safe desaturation when appropriate. An offline RGB assertion alone cannot certify pixels; verify class fills on live players, pets, disconnect/vehicle transitions and party pool reuse.

## 0.2.347 non-raid-style party presentation (in-game validation pending)

A screenshot of Blizzard's **non-raid-style** party members showed default gold artwork, non-class-colored green health bars and native status text. Previous .342 compact-party presentation only covered raid-style members. New .347 code discovers the separate real PartyMemberFramePool, uses native name/bar class colors, existing LoL numeric shadow treatment, and Soft Dark's reversible party/vehicle/pet chrome tint. The client still needs visual checks for normal party, vehicle, party-pet, preview, combat and swapping party-style layouts. No native status contents or frame geometry are changed.

## 0.2.346 action-bar fixed digit ink (live confirmation pending)

A new report states that action-bar timers still visibly shift. Source inspection confirms that the four individual action number bindings used literal proportional `0–9` glyphs, although their FontStrings were separately anchored. This patch forwards calibrated native-font digit strings to those bindings using the already present glyph-map helper, reusing native duration objects and fixed geometry. A secret/unsupported font or rejected inline markup stays with the native or original fixed-cell fallback, which may remain visually proportional. In-game render confirmation and performance testing are pending.

## 0.2.345 long buff static digit coverage (live validation pending)

Source inspection confirms the gap: readable 10s+ buff clocks used Blizzard's centered proportional stock text, unlike public below-10s three-cell digits. v0.2.345 optionally equalizes native stock numeral advances using a cached native-font map after Blizzard's UpdateDuration while leaving its string, formatting, font and anchor under native ownership. Secret/denied/unsupported text is never inspected or replaced. This adds one cosmetic native SetText per supported long-buff native update; live FPS and visual stability still need verification. Rested ZZZ moves X49 → X48.

## 0.2.342 compact party typography/class colors — live verification pending

Compact party member `name`, `healthBar`, and native status text use an isolated presentation module. The native status routine is reused rather than duplicating font styling, while current native power colors, name text, status contents, portrait artwork and compact-party visual order are unchanged. The code is scoped to `CompactPartyFrame.memberUnitFrames`; in-game check needs to confirm class colors during party combat and after Edit Mode updates, including the precise health/power text surfaces exposed by WoW: Forever. No numeric status option is forced on.

## 0.2.341 buff timer numeral wobble — in-game check pending

The latest live report describes fixed buff timer numerals wobbling again. No buff-specific source changed between the .334 and .340 builds. This experimental patch normalizes visible glyph advances within **already fixed** three-cell public buff decimals, while retaining the native font and static anchors. It uses supported per-font measurement outside combat, with a bounded cache and native/uncalibrated fallback. This only addresses visual ink drift when the split-cell path is active. If the visible issue occurs on an opaque native-fallback aura, it can persist: capture the existing `/buitimers` information during the affected buff instead of guessing the aura ID or protected remaining time.

## 0.2.340 native leader crown alignment (live check pending)

The screenshot showed the small leader crown on Target/Focus needing a slight leftward adjustment, and the Player crown the opposite. This version changes only LeaderIcon by ±2 UI units and keeps other group icons native. Confirm optical placement on player, target and focus in Forever.

## 0.2.339 ZZZ right of the secondary portrait (in-game check pending)

After a user screenshot demonstrated that the previously relocated ZZZ remained on the **wrong side** of the player portrait, v0.2.339 places the native RestTexture at the upper-right **past the secondary circle**. Representative portrait-relative x offset is +72; vertical placement remains native. The animation/texture are not mirrored or replaced. Verify clearance at the configured UI scale; local tests cannot certify final in-client pixels.

## 0.2.338 resting indicator optical alignment (in-game check pending)

A live screenshot showed the upper-left native ZZZ animation too far from the portrait. This build nudges its native anchor 8 UI units inward while preserving the vertical position, animation and strict left-side guard. Mocked layout tests pass; confirm optical alignment in the client.

## 0.2.337 rested indicator integration — in-game check pending

A new live screenshot showed the native resting ZZZ indicator still at the upper-right of PlayerPortrait. Root cause: prior 0.2.336 ZIP never packaged the standalone ZZZ PR #4 implementation. The .337 package integrates that module, its manifest entries and original tests, without touching the already repaired cast timer or level rings. Verify the Z's move to the upper-left during rest, while the secondary circle retains its upper-right position.

## 0.2.336 level-background clearance (live validation pending)

- A screenshot after 0.2.335 shows the round black/gold level background and border visible again on target. The source only hooked `LevelBackgroundCircle.Show`, while native Camelot may update `SetShown` and `SetAlpha` independently. This build observes all three and retries narrowly when the target/focus frame refreshes.
- Verify player, target and focus numbers remain visible while only their level badge/rim disappears, including repeated target changes, zoning and combat. This source-level repair does not establish actual client rendering or protected-call safety.

## New cast timer recovery test

- Reported live regression: a Hearthstone cast displayed no countdown while the cast bar remained visible on the 0.2.334 family. The 0.2.334 cast module cleared Blizzard's native `CastTimeText` to replace it with independent glyph regions. Restore the frozen 0.2.309 native duration-bound renderer in this test branch, preserving the original text as fallback. Offline tests validate supported transition/refusal paths, not the live result.
- Validate the native Show Cast Time option is enabled. If it is off, this test build deliberately does **not** change the user's saved option or force Blizzard to show a disabled label. `/buitimers` reports `cast=native-bindings`, current state and whether the option is on/off/unknown.
- The ZZZ portrait clearance remains a separate experimental PR and is not included here.

## Current live follow-up

| Open observation | Current behavior and next evidence |
| --- | --- |
| Action/cast numbers move sideways or disappear | Fixed action/cast rendering remains enabled with the current native font. Capture `/buitimers` during the affected cooldown/cast and record UI scale, native countdown/cast-time setting and combat state. Repeat cast/channel transitions before treating a single successful display as recovery. |
| Some short player buffs use whole seconds | Public short timers and supported public-identity native formatting have separate routes. Secret-ID ordinary buffs, private anchors and forbidden frames can intentionally retain stock formatting. Capture the precise identity/coverage reason; do not infer a formatter defect from the visible precision alone. |
| Combat stuttering | The .334 case proves an unchanged-layout retention defect in a modeled native sequence. It does not identify the cause of live stuttering or measure a frame-time improvement. A comparable live workload and frame-time capture are still needed. |
| Intermittent buff/debuff decorative borders | Run `/buiborders` before `/buiicons` or reload. Public skin coverage does not include every private/inaccessible icon. |
| Battleground colors, cosmetic alignment and protected calls | Historical observations below remain open pending current-build client checks. Preserve native Target/Focus aura rows and user settings while gathering evidence. |

## Version-specific repair evidence

**0.2.334 buff timer repair, live verification pending:** The native aura-font-adjustment path can repeat an identical anchor after every duration update. Version .333 incorrectly retired prepared fixed digits in combat on that unchanged write. The regression now exercises the full native font-and-anchor sequence; unchanged layouts retain fixed digits, while actual changes retain the stock fallback. This offline reproduction does not establish the cause of reported in-game stuttering or close other live timer reports.

**0.2.333 audit repairs, live verification pending:** Fixed action and cast timers remain enabled. Failed action minimum-gate preparation can retry at safe lifecycle boundaries, and prepared action digits can refresh changed native font/style. Buff tenths retain the native above/below/beside placement. Combat exit no longer performs the same name-color pass twice. Tests cover these code paths; actual client rendering, protected execution and frame time remain separate checks.

**0.2.332 forward timer repair, live verification pending:** The fixed action/cast paths remain enabled. Cast glyphs no longer anchor to an emptied native FontString or unbounded parent; a model allowing empty text to have no geometry reproduced the old blank display. Action minimum-gate calibration now supplies a formatter and uses positive test durations, matching the native binding setup rather than demanding a color from an incomplete or zero-duration binding. Neither conditional reproduction establishes the exact live cause. The .331 rollback was rejected. Retest repeated casts/channels and capture /buitimers while an affected cooldown is active.

**0.2.330 targeted timer changes, live verification pending:** The live .329 action diagnostic confirmed three minimum-read-denied fallbacks, and the cast diagnostic confirmed the tabular-font opt-out. Action cells now use a native minimum gate when its client duration/rate mapping passes a synthetic check. Cast digits use the current native text in fixed-position regions. These are source-level repairs with regression coverage, not a claim of confirmed in-game spacing. Secret-ID ordinary player buffs remain on Blizzard’s native formatting; no supported narrow conditional-decimal route has been established for them.

**Current timer reports (.329 diagnostic build):** Action and cast numbers still move sideways in game, and some short player buffs display whole seconds. The live .328 diagnostic showed three active identity-gate fallbacks; its old message did not distinguish missing, secret or invalid fields. Version .329 provides that distinction and reports cached action cell/fallback and cast calibration status through the same /buitimers command. It changes diagnostic metadata, not timer rendering. Capture after a short cast while an affected action cooldown and short buff are active. A successful offline fallback test does not establish that static digits or decimals meet the requested behavior.

## Earlier live checks recorded for 0.2.323

Check that cast-to-channel transitions retain one visible timer, including empowered hold-at-max time. At the UI scales you use, watch short buff timers during button reuse and check party anchors after a pet changes. Frame time in a busy battleground still needs measurement. [Code and tests](docs/CODE_MAP.md)

## Observations from 0.2.286 (2026-11-07)

- **Player buff/debuff decorative borders remain intermittent.** Missing or inconsistent nameplate-style rims were reported even after the 0.2.277 and 0.2.281 lifecycle fixes. A screenshot alone does not distinguish an unstyled/private aura slot from a previously styled border becoming hidden. Run `/buiborders` while the problem is visible, **before** `/buiicons` or `/reload`. The diagnostic only counts public icons that the skin reached; a zero missing count does not establish that every visible icon was styled.
- **Sub-ten-second buff/debuff decimals are not universally reliable in-game.** 0.2.280 addresses modeled visibility and retry failure paths, but a few visible buffs (including an Escape Artist report) still showed whole seconds. Run `/buitimers` after the occurrence; private/forbidden timers intentionally retain native formatting rather than guessed values.
- **Target/focus native aura buttons are unstyled.** `RestrictedAuraAPI=true` on the tested client selects forbidden buttons. The custom replacement experiment in 0.2.272–0.2.273 did not activate reliably and a protected-action block was reported. It was retired in 0.2.274; `UnitAuraStyling.lua` remains an inert stub. Do not treat more frame enumeration or script hooks as a safe fix.
- **Player combat icon alignment needs a new screenshot check.** `/buicombat` confirmed that the former position `TOPLEFT (68,-63)` was applied, despite inadequate optical clearance. The new 0.2.286 target is `(76,-63)`, not yet confirmed visually. This is a presentation offset, not a guarantee of exact separation at every UI scale.
- **Protected-action and taint safety remain live verification requirements.** Offline mocks cannot establish full client compatibility. If a protected-action error returns, disable the test addon and record the exact blocked function before changing native hooks again.

## Capture order

For disappearing borders or missing decimals, use `/buiborders` and `/buitimers` **before** `/buiicons` or a reload. `/buiicons` may reapply styling. For the combat icon, `/buicombat` is read-only. Keep default Blizzard icon artwork and native target/focus aura rows until a supported replacement is demonstrated in-game.

**Ten-second decimal cutoff (2026-10-31):** `0.2.262-ten-second-decimals-test` displays one decimal on native action-button countdowns strictly below ten seconds, with whole seconds starting at ten. The six-minute and longer formats remain unchanged. See architecture section 46.

**Dependency and ownership recovery (2026-10-31):** `0.2.261-recovery-test` addresses the two exact-ZIP re-audit findings: circular party-anchor rollback after a late write failure, and health tint ownership acquired without a successful native-color observer. Regression tests model native anchor dependencies and rejected/missing tracking hooks. Ordinary visual values remain unchanged; native failure occurrence, protected execution and rendering remain live-client checks. See architecture section 45.

**Remaining audit repairs (2026-10-31):** `0.2.260-audit-fixes-test` repairs threat/resting hook recovery, partial party positioning, anonymous bag discovery, late theme handoff, stale name-color restoration, contradictory owner-name identity and late MicroMenu offset installation. Focused regressions cover the demonstrated source paths. These are conditional recovery/presentation repairs; historical Battleground reports still require live verification. See architecture section 44.

**Conditional recovery repairs (2026-10-27):** `0.2.259-recovery-test` isolates incoming hit-text setter errors from the remaining lifecycle repairs, and recovers stale Soft Dark Edit Mode state after incomplete callback registration. Both defects were reproduced with modeled API failures against the exact `0.2.258-hit-text-recovery-test` build. Native occurrence, event ordering, protected writes, rendering and taint still need in-game validation. Existing historical reports and other conditional compatibility questions remain open.

**Incoming hit-text lifecycle (2026-10-27):** `0.2.258-hit-text-recovery-test` retries Player incoming-text anchoring at combat exit and refreshes it after UI scale/display changes, using the existing guarded helper and current geometry. Full-module lifecycle regressions compare with `0.2.257-presentation-recovery-test`; live rendering, event ordering and taint still require in-game validation. Unrelated conditional gaps and historical Battleground reports remain open.

**Presentation recovery (2026-10-27):** `0.2.257-presentation-recovery-test` repairs stale status-shadow scale caching and retains failed Soft Dark restoration state for retry. Focused Lua 5.1/5.4 regressions compare these paths with `0.2.256-five-second-decimals-test`; they do not establish live-client scale-event ordering, native setter behavior, taint safety or rendering. Other conditional compatibility gaps and the historical Battleground reports remain open.

**Sub-five-second cooldown precision (2026-10-26):** `0.2.256-five-second-decimals-test` shows one decimal on native action-button countdowns only below five seconds, while preserving whole seconds through 359 and larger compact units. Native secret-safe formatter support and visual appearance remain launch-client checks.

**Native cooldown seconds (2026-10-26):** `0.2.255-native-cooldown-seconds-test` adds native-format-only action-button cooldown counts in seconds below six minutes, with compact unit labels thereafter. This requires `NumericRuleFormatter` and `Cooldown:SetCountdownFormatter` on the Forever build; if either is unavailable, native text is preserved. CI mock tests do not prove live-client availability or taint safety.

**Player colors and status typography (2026-10-26):** `0.2.254-native-player-shadow-text-test` leaves Player frame health/name colors native while retaining other unit-frame class colors. Health/power numerical labels on unit frames and PRD remove outline flags and gain a subtle black shadow. Lua tests verify styling and client-boundary guards; native font resets and screenshot alignment still need launch verification.

**Shop notification (2026-10-26):** `0.2.253-shop-pip-test` adds bounded in-game Shop/Store micro-menu pip suppression and native reshow hooks. The Shop button remains interactive. The character-selection Shop marker cannot be changed by a normal character addon; in-game marker artwork awaits live Forever verification.

**Text presentation (2026-10-26):** `0.2.252-foundation-v16-combat-text-test` positions incoming Player hit text two physical screen pixels above the native frame while preserving health-bar horizontal centering, and omits status percentage decimals at 100%. Offline tests verify coordinate math and threshold formatting; client-specific animation offsets still require launch testing.

**Prelaunch offline correction (2026-10-25):** `0.2.251-foundation-v16-offline-fixes-test` repairs the Tracked Buff iterator contract, PartyOrder partial layout authorization, remaining visual hook retry flags, partial health-style restoration, and Soft Dark callback registration. New source-backed tests do not certify Forever's future live-client behavior.

**Lifecycle repair candidate (2026-10-25):** `0.2.250-foundation-v16-lifecycle-repair-test` addresses repeated micro-menu notifications, incomplete PartyOrder hook installs, failed secrecy probes, and color-write guard cleanup. Offline checks cannot prove safety in the unreleased Forever client. Native alpha-zero reuse and name-color snapshot ownership remain unverified.

**Hardening candidate (2026-10-25):** `0.2.249-foundation-v16-hardening-test` adds strict nameplate permission gates, original-alpha pooled compact-border restoration and independently retryable native update hooks, with Lua 5.1/5.4 CI regression coverage. All client-only behavior and previous Battleground observations remain open pending live testing.

**Layout ownership (2026-10-23):** `0.2.248-foundation-v16-layout-neutral` contains no bundled Edit Mode presets or automatic layout installation/replacement. Existing saved layouts are left untouched; any previous migration is not reversed.

**v16 suite update (2026-10-22):** this addon receives release-version metadata only. Its behavior is byte-identical to v15 apart from that version string. The three timing repairs are in bjarkiCC Model/Observer. The full v16 suite passes 49 regression scripts and 28 runtime syntax checks on both Lua 5.1 and Lua 5.4; live-client findings below retain their existing status. The behavior described in architecture section 31 remains applicable.

Historical packaged source baseline (2026-11-02): **bjarkiUI 0.2.264-audit-fixes-test**. The reports below are historical client observations and remain open pending current-client verification. Offline source, syntax and modeled-API checks do not close them. See architecture section 32 for the origin of the layout-neutral behavior retained by current source.

Original status recorded 2026-10-08 for **bjarkiUI 0.2.90-local**.

The items below reflect reports and diagnostic output from Battleground
sessions. They remain open until checked in the live client against this build.
A report describes a visible symptom; it does not by itself establish the
failing code path or root cause.

## Opposing-faction class colors in Battlegrounds

- Enemy player health bars have been reported white or otherwise not
  class-colored, even when the nameplate shows the player's class color.
- Enemy Target-of-Target and Focus-of-Target health bars have also been
  reported with missing or incorrect class colors.
- A `/bui colors` capture showed the enemy target and targettarget as
  `player=true`, but `class=unknown` and no usable nameplate color in that
  diagnostic context. This confirms an unknown input at that point in the
  diagnostic path; it does not identify why the class data was unavailable.

Keep class identity, unit binding, relation/readability, native bar-color
writes, and fallback selection as separate diagnostic stages. Do not treat a
white bar as proof that the class-color lookup itself was reached.

## ToT/FoT visibility and color

During earlier debugging, changing the display CVar made ToT/FoT frames
disappear. The user restored them with `show=1` and `mode=nil`; the frames
returned, while the opposing-faction color issue remained. Do not change those
CVars as a color workaround. Frame visibility and health-color selection are
separate issues.

## Verification boundary

These reports originated in 0.2.90-local; no live result recorded here closes them for current 0.2.334. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the frame/color implementation and
reported BG diagnostics. Pet portraits and aura category failures are tracked
in the [bjarkiPortraits issue list](https://github.com/bjoern-janson/bjarkiPortraits/blob/main/KNOWN_ISSUES.md).

## Historical post-patch follow-up: 0.2.220 (2026-10-17)

- Opposite-faction and Focus class-colored health fills, native redraws after duels, and occasional wrong-color reports require renewed verification on the current 1.60.1 client. Source guards and screenshot examples do not establish full coverage across Battleground secrecy transitions.
- A historical aggro/flash border remaining after untargeting motivated narrower Target/Focus highlight handling. Recheck the actual target/focus warning lifecycle on the current build; do not disable legitimate flash effects to mask a stale state.
- Compact ToT/ToF position, Player/Target/Focus status text optical anchors and nameplate CC edge avoidance have been visually calibrated but remain dependent on UI scale and current native artwork. Any future alignment changes should use native screen-pixel evidence without restoring obsolete bar geometry.
- Minimap day/night decorative glyph removal and action-button macro-name suppression need in-game verification under loading-screen changes, Edit Mode and alternative action-bar visibility. The initial candidate uses native objects only; retain hotkey/stack text and click functionality.
- Historical 0.2.220 builds bundled an Edit Mode preset. That behavior was retired in 0.2.248; the current addon does not install, replace, or activate layouts.
- Four-Lua-module syntax checks and focused offline assertions pass; some older historical test expectations also fail against the unchanged pre-sync local source. Do not claim complete live taint correctness or a uniformly green historical regression suite on this basis.
