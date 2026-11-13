# Verification and live evidence for 0.2.358

Date: 2026-11-13. Build: **0.2.358-timer-gate-prewarm-test**.

## Result and scope

This build repairs three reproduced gaps in preparing the native minimum-duration gate for idle action buttons. Each gap can produce the `gate-unsupported/combat-cold` fallback now visible in the user's client capture. The patch prepares the existing gate during already scheduled safe work; it does not change calibration, native clocks, duration thresholds or minimum/GCD policy. It also names two previously unexplained diagnostic fallbacks without changing their behavior.

The latest live capture remains the authority on the unsuccessful .357 result. No .358 in-game test was possible here. Source review and regression fixtures establish the repaired lifecycle, not the frequency of that lifecycle in the client or the final pixels. Secret-ID buff decimals are still open and unchanged by this package.

Baseline: .357 remote commit `b545f490c60a9e146e4273b9c72c1e39d50f55cf`, local commit `c55db1c4ab7afef7fe885ddb57893845dfac5dee`, identical tree `9bf7f10e2a966495ab898445014b080a53359d81`. Runtime behavior changes are confined to `NativeDigitCells.lua`; main and both manifests receive the matching version. There are still 16 runtime modules.

## What the new capture establishes

The user supplied the following .357 diagnostic alongside a game capture showing short ordinary buffs at `2 s` and `0 s`:

```text
aura native=0 fallback=11 last=aura ID secret readable-writes=21894
visibility-restricted=0 retries=0 hooked=48/48 retry-pending=0
fallback-buttons=11 private=6 inaccessible=0
actions cells=1 stock=14 idle=82 minimum-read-denied=12 below/equal-minimum=0
[ActionButton3:gate-unsupported/combat-cold,
 ActionButton6:unavailable,
 ActionButton9:gate-unsupported/combat-cold]
cast=native-bindings state=stock setting=on
glyphs=fixed:0/plain:4/unavailable:0 last=plain
formats=fixed:0/plain:4/unavailable:0 last=plain
```

Only one action presenter is reported with active fixed cells; 14 retain stock presentation. The 82 idle presenters are not 82 failures. Twelve fallbacks are recorded in the minimum-decision category, with two named samples specifically lacking a prepared gate during combat. The third named sample has no precise prior reason. These aggregate counts do not establish that every fallback has the same cause.

The action typography profiles are now plain/available. This is consistent with .357 removing an unnecessary full-formatter rejection; it does not prove stationary numeral ink or that a particular cooldown uses replacement cells. The visible action `0.6` alone likewise cannot identify its renderer.

All 48 ordinary aura hooks are installed. `readable-writes` counts successful decimal writes over time, including writes to the original label; it is not the number of currently fixed timers. No successful native aura-duration route is reported, and the latest fallback reason is `aura ID secret`. That reason cannot be assigned to every one of the 11 current fallback states or to a particular pictured buff from this aggregate report alone. The separate horizontal bars in the image are not used as evidence about action-cell rendering.

## Reproduction and correction

An action presenter can be fully prepared and active while its public native clock is zero, even if optional minimum-gate calibration failed. At an existing safe retry event, `RetryActionMinimumGates` removes failed gate entries. Previously, an unchanged-style resynchronization and the already-active installation return could then both skip rebuilding the idle presenter's gate. Its first restricted combat cooldown needed the missing gate, but creating one in combat was correctly refused as `combat-cold`.

Two other ordinary idle changes had the same gap: changing the native minimum from zero to positive, and changing the native countdown text color. The gate cache includes the current minimum and native color, so both require preparation of their current profile before combat.

`prepareActionMinimumGate` now reuses the existing guarded positive-minimum preparation in three places:

1. Initial action setup, replacing the equivalent inline preparation.
2. The existing native minimum setter hook, before its ordinary refresh.
3. Every successful safe prepared-action installation scan, after current-style resynchronization and before the active early return.

The helper requires a positively confirmed out-of-combat state and a publicly readable positive minimum. The original calibrated builder, cache key, 32-entry capacity, success/failure caching and retry epochs remain unchanged. Ordinary scans do not repeatedly retry a failed calibration within an epoch. Safe preparation does not acquire stock visibility or change an action's native duration object.

The actual-module regression uses the real `CooldownSeconds` event handler and minimum setter hook. Independent clean-parent controls fail each new retry, minimum and color scenario at its intended preparation assertion. With the patch, all three prepare while safe, then their first opaque combat update displays the native-bound `6.3` with the accepted source color. Instrumented counters verify that this combat update creates no curves, clocks, bindings or labels and performs no font measurement. The label check observes the actual fixture label list.

This repairs the demonstrated lifecycle gap. `combat-cold` is still possible for a genuinely new combat-only profile, a cache entry evicted after enough distinct profiles, or preparation that remains unavailable. The capture does not establish those conditions. No speculative calibration, rate-mapping, font or color-tolerance changes are included.

## Diagnostic-only additions

Two source-grounded sequences produced plain `unavailable` in the previous report:

| Public stage | Reproduced sequence |
| --- | --- |
| `zero-shutdown-refused` | A publicly zero native clock reaches the existing presenter-shutdown path, but shutdown does not finish. The receipt is recorded only after the existing epoch check. |
| `style-pending` | A safe style refresh is deferred, native Clear clears the earlier reason, and a later native SetCooldown reaches the still-pending style guard. An existing precise style reason is preserved. |

Both were reproduced on the parent source under native Lua 5.1 and 5.4. Regressions check stock visibility, old-cell suppression, normal recovery and read-only diagnostic reporting. These labels do not identify which prerequisite occurred on the live ActionButton6, and they do not change visibility, retry, timing or permission policy.

## Buff decimals: supported path and current limit

The legacy [BuffFrame duration writer](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua) writes `SecondsToTimeAbbrev(timeLeft)` into a FontString. The actual [TimeUtil helper](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/TimeUtil.lua) selects localized units directly and exposes no conditional numeric formatter. The public [aura-duration lookup](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua) does not permit forwarding the inaccessible aura identity through ordinary addon execution.

Native custom aura containers expose a supported [duration-text delegate](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua), with native assignment and clock ownership. Their public default-formatter accessor also exists, but gives neither a legacy button's assignment nor its duration. A replacement row is therefore a separate implementation, not an additional hook on the existing label. No protected identity is inferred or permission boundary bypassed.

The [concrete native-row design](NATIVE_BUFF_ROW_DESIGN.md) records a parent-following Edit Mode geometry mapping, original icon/font initialization, native input behavior, and the remaining private-aura, enchantment and ordering contracts. Existing bjarkiUI already disables collapsing and consolidation, so those are not blockers. The source investigation confirms that legacy private anchors admit every private aura, while the custom helpful group can also admit a helpful private aura and offers no public private-source exclusion. The built-in custom enchant source selects one record per slot rather than every legacy enchant record. Public enchant data permits a separately owned prefix, but its continuous wrapping with the native custom group is not established. These are concrete compatibility limits of the proposed helpful-only replacement. This package installs no replacement row and does not claim to solve the missing secret-ID decimals.

## Final verification

| Check | Result |
| --- | --- |
| Native Lua 5.1.5 | All 37 top-level suites pass; 16 runtime modules and test sources compile through native `loadfile`. |
| Native Lua 5.4.6 | All 37 top-level suites pass with the same compilation checks. |
| Action digit suite | 5,749 assertions pass on each interpreter. |
| Aura suite | Existing 226 cases pass on each interpreter; buff runtime is unchanged. |
| Independent review | No material findings after the final diagnostic changes and label-counter correction. |
| Package | Matching versions/load order, exact 19-file membership, archive integrity and byte equality against verified source inputs pass. |

`git diff --check` is clean. Counts describe the explicit fixture models and are not percentages of client coverage. The release gate uses the repository verifier's package and manifest functions with the established local adapter running native interpreters. No standalone `luac` is available here; native `loadfile` performs compilation. The stacked draft PR is outside the workflow's `main` trigger, so these are local results, not a GitHub CI claim. Reproduction commands are in [TESTING.md](TESTING.md); packaged inputs are recorded in the [SHA256 manifest](SOURCE_SHA256_0.2.358.txt).

## Performance wording and package

The description remains **“Ultralight unit-frame presentation for WoW: Forever.”** This correction adds no polling loop, timer, event frame, option, dependency or runtime module. It performs current-profile preparation on existing safe lifecycle scans and native minimum changes, and reuses the existing bounded gate cache. The first restricted combat update in the new regressions adds no rendering resources or font measurements. The [.356 allocation comparison](VERIFICATION_0.2.356.md) remains historical evidence, not a new measurement of .358. Offline results do not establish live FPS, frame time or addon memory.

`bjarkiUI-0.2.358-Timer-Gate-Prewarm.zip` contains one normal `bjarkiUI/` folder with **19 files**: 16 runtime Lua modules, two matching manifests and the existing spacer texture. Archive size: **134,008 bytes**. Expanded payload: **527,192 bytes**, including **525,070 bytes** of runtime Lua source. File size is not runtime memory.

SHA256: `7f2b8908ce40eb911764610b8a2e883e84f596b2dae1d45c130d862adb9da393`.

Tests and development documents are excluded from the ZIP. Accepted crown spacing, removed rested Zs, hidden classic-party faction badges, native timer fonts, saved character settings and user Edit Mode layouts are retained. The [open live reports](../KNOWN_ISSUES.md) remain explicit.
