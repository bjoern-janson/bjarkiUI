# Verification and live evidence for 0.2.357

Date: 2026-11-13. Build: **0.2.357-timer-handoff-recovery-test**.

## Result

This build repairs reproduced action visibility-handoff recovery defects and an unnecessary rejection of unchanged native formatters. It retains precise public failure stages in the existing `/buitimers` output. The user's live action positioning and secret-ID buff decimal reports remain open: the offline tests do not establish why the client's visibility handoff failed or prove the resulting pixels.

The baseline is .356: remote commit `a0e34b060862cfdabc6b4ead08ef64415859c726`, local commit `ac18b91afdd3d0a62ec85a8f28e18ecf209d6f79`, identical tree `782154c2eac1437d3c332a51d6a4c82b5ef607d3`. Runtime behavior changes are limited to `NativeDigitCells.lua` and `ActionTimerSpacing.lua`; main and both manifests receive the matching version update. There are still 16 runtime modules.

## What the live capture establishes

The supplied `.356` capture reads:

```text
aura native=0 fallback=12 last=aura ID secret readable-writes=53419
visibility-restricted=0 retries=0 hooked=48/48 retry-pending=0
fallback-buttons=12 private=6 inaccessible=0
actions cells=0 stock=2 idle=95 minimum-read-denied=0 below/equal-minimum=0
[ActionButton11:unavailable, MultiBarBottomLeftButton11:unavailable]
glyphs=fixed:0/plain:4/unavailable:0 last=plain
formats=fixed:0/plain:0/unavailable:4 last=layout
```

The action summary counts already prepared presenters; `unavailable` is the diagnostic default when a stock/restoration state has no recorded reason. It does not establish an unsupported minimum gate. A successful duration binding followed by a failed visibility handoff reproduces this exact lost-reason pattern.

The 48 accessible ordinary aura hooks are installed. The readable-write count includes successful fixed-cell and original-label decimal writes, so it does not count currently fixed buff timers. The latest native-duration fallback is specifically a secret aura ID; the aggregate last reason cannot establish that all 12 current fallback states share it. The full-formatter `layout` field belongs to the action typography cache, not a per-buff layout failure.

## Action recovery and ownership

Against unchanged .356 source, a first refused stock-hide write leaves no stock-fallback receipt. After the setter becomes available, the next ordinary native `SetCooldown` still leaves the prepared cells idle; an explicit installation is needed to recover. The previous fixture concealed that path by creating a clock outage first and explicitly retrying installation.

The correction retains a named stock fallback after an own hide-write or readback refusal. Existing native updates retry the prepared presenter with no additional regions, bindings, hooks or polling. Failures distinguish `hide-write-refused`, `hide-read-denied`, `hide-read-unavailable` and `hide-not-applied`; a pending rollback can append a separate `restore-*` stage. Only fixed public labels are recorded, without error payloads or hidden timing.

Review identified two ordering boundaries that the final patch covers. A native update during rollback must not acquire the same presenter before cleanup finishes, and binding shutdown must not overwrite a newer external visibility writer. `restoreFailedHandoff` guards the entire rollback, including cell shutdown after the visibility setter returns. Installation rejects entry during either an open visibility setter or that cleanup. Tentative visibility ownership is established before failed-hide cleanup and checked before restoration; external visibility hooks can still revoke it.

The existing action suite now includes fresh-owner thrown/false/after-write refusals, denied and unavailable readback, mismatched readback, deferred restoration, a preceding clock outage, updates during the rollback setter and both cleanup paths, and newer external visibility writers. It checks native visibility, actual `6.4` cell output, current native duration identity, next-update recovery, and reuse of regions/bindings/hooks during combat. Existing minimum/GCD, preference, style, replacement and reentrancy cases remain in the suite.

## Naturally tabular formatter identity

The existing fixture's equal numeral advances and its pixel-rounded outlined-width mode had not been combined. That combination reproduces the live `plain` glyph / `unavailable layout` diagnostic pattern for the full action and suffix formatters on both Lua versions. For example, three equal digits and punctuation can measure 0.125 UI units away from the sum of averaged glyph widths, exceeding the natural path's 0.003 tolerance.

The formatter is unchanged for naturally tabular numerals. After successful permission, native font, scale and glyph preparation, the code now returns that exact original formatter before transformed-string validation. Validation for actual padded output remains intact. Both new regression cases failed before the correction and pass afterward.

This correction does not by itself activate action cells: both existing consumers already retained the base formatter when optional preparation failed. It also does not establish visible ink centering or repair the separate buff formatter.

## Secret-ID buff boundary and supported alternative

The existing ordinary buff `Duration` is a FontString updated through Blizzard's `UpdateDuration`. Native API source restricts secret arguments to untainted execution for `GetAuraDuration`, `NumericFormatter:FormatNumber`, and duration construction setters. Passing a secret ID through `pcall` does not grant access. FontString text sinks accept opaque text/numbers, but a fixed `%.1f` sink cannot select the requested below-ten-only policy while retaining native longer-duration units. See the pinned Forever [aura API](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua), [numeric formatter API](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/NumericFormatterAPIDocumentation.lua), and [ordinary buff writer](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua).

Blizzard's [custom aura button](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua) exposes a supported `SetDurationText` delegate while native code owns the aura assignment and clock. That is a genuine separate architecture. Its display label must descend from the custom owner, and its group factory creates new native-owned buttons; it cannot simply format the legacy button's unrelated label. The custom container's preview support does not automatically inherit saved BuffFrame Edit Mode geometry, ordering, private anchors or input behavior. See [ownership validation](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua) and [frame providers](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua).

No supported in-place conditional-decimal bridge was found for the existing secret-ID row. This build leaves that row intact and documents the limitation rather than inferring an identity, estimating a clock or introducing a replacement layout. The inspected legacy `BuffFrame.lua` is byte-identical at pinned Forever commit `4cd0ab7` and current inspected head `bebcb6b` (blob `0402dbb8251448aa3804e7d6900f58319d98c422`).

## Verification

- Native Lua **5.1.5**: all **37 top-level suites** pass; all **16 runtime modules** and test sources compile through native `loadfile`.
- Native Lua **5.4.6**: all **37 top-level suites** pass with the same compilation checks.
- The final action digit suite passes **5,576 assertions** on each interpreter. The unchanged aura suite retains **226 cases**. Counts describe the explicit fixture models, not percentages of client coverage.
- Independent review reproduced the reentrant failures before the final correction and confirmed the named fallback, newer-writer preservation and subsequent native-update recovery on both interpreters. No remaining blocking review issue was found.
- Matching manifest versions/load order, `git diff --check`, archive integrity, exact 19-file membership and packaged byte equality pass. [Source SHA256 manifest](SOURCE_SHA256_0.2.357.txt).

The release gate used the repository's `tools/verify.py` manifest and archive functions with the established local adapter running native interpreters. No standalone `luac` is available here; native `loadfile` performs source compilation. The stacked draft PR is outside the workflow's `main` trigger, so these are local results, not GitHub CI execution. Reproduction commands are in [TESTING.md](TESTING.md).

## Performance scope and package

The exact description remains **“Ultralight unit-frame presentation for WoW: Forever.”** This repair adds no polling loop, event frame, option, dependency or runtime module. Retry work occurs on the existing native cooldown updates and reuses prepared resources; failure stages are fixed strings. Natural formatter preparation skips unnecessary work. The .356 allocation improvements remain, but its [measured comparison](VERIFICATION_0.2.356.md) is not a fresh benchmark of .357, and neither build's offline evidence establishes live FPS or client memory.

The installable `bjarkiUI-0.2.357-Timer-Handoff-Recovery.zip` contains one normal `bjarkiUI/` folder with **19 files**: 16 Lua modules, two matching manifests and the existing transparent spacer texture. Archive: **133,897 bytes**. Expanded: **526,667 bytes**, including **524,537 bytes** of runtime Lua source. File size is not runtime memory.

SHA256: `b53acf1bb3e77261bdbb01065c218f5eceb513b7d330adc1ca4dc1a307a7f8ad`.

Tests, reports, source snapshots and development files are excluded from the ZIP. Current fonts, native clocks and countdown policies, saved settings, approved crowns, removed rested Zs, hidden classic-party faction badges and user Edit Mode layouts are preserved. No in-game test was possible here; [the live reports](../KNOWN_ISSUES.md) remain explicit.
