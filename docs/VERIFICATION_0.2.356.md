# Verification and performance evidence for 0.2.356

Date: 2026-11-13. Build: **0.2.356-presentation-performance-test**.

## Result and scope

The focused cleanup reduces demonstrated temporary Lua allocations and redundant NPC native-color traversal while retaining current presentation, native clocks and permission checks. The exact TOC description remains **“Ultralight unit-frame presentation for WoW: Forever”**. This describes the addon's presentation scope and event-driven architecture; the offline evidence does not establish live FPS, startup time or in-client memory.

The baseline is .355: upstream commit `6b3090e7196c820b574fe9f86f22b296657ec97f`, tree `bd5fe1ba705fcd999ba3dd55afdf0d87ed4b0852`, matching local baseline commit `7d416dcdf296e2029c83bbf872fb2211cbbabf28`. Runtime behavior changes are limited to `NativeDigitCells.lua`, `BuffPresentation.lua` and `bjarkiUI.lua`; both manifests receive the version update. The module count remains 16.

## Changes and recovery

- Timer member reads use one shared function under the same protected call and public-value/type filters. The buff layout-hook name list is reused instead of recreated.
- Safe buff setup reuses an unchanged typography receipt only after the current glyph lookup and formatter preparation/retry path run. It still clears unavailable profiles and replaces recovered formatters; it keeps current font, scale, owner and combat-layout recovery.
- NPC color discovery returns the first readable native witness, preserving ordering and downstream RGB validation. It no longer reads later candidates/regions after finding that witness.
- The native nameplate-color hook may supply call-local origin context. Direct lookup requires positive native access, matching public GUIDs, the current wrapper/origin/recipient and a current callback revision. Invalid hints use fresh discovery. No plate, unit identity or RGB is retained between callbacks.
- Discovery is followed by current actor and recipient validation. A target that became a player follows the current class/native route; a pet or unavailable identity retains native presentation. A callback revision receipt also makes an older operation yield to a newer native update during those final checks.
- Soft Dark keeps full safe lifecycle discovery, which recovers unseen replacements and late-created native artwork. No new polling, options, dependencies or runtime modules are added.

Approved crown positions, hidden rested-Z texture and classic-party faction badges, native icon artwork, timer fonts, fixed digit positions, clock ownership, countdown settings and user Edit Mode layouts remain within the existing contracts. This performance patch does not close the live timer-rendering reports in [KNOWN_ISSUES](../KNOWN_ISSUES.md).

## Timer comparison method

The harness loads the real `NativePrecision`, `ActionTimerSpacing`, `CooldownSeconds`, `NativeDigitCells` and `BuffPresentation` modules with fixed native-boundary doubles. Lua 5.1 also loads its existing fixture compatibility helper. It reuses the previous audited **24,036-byte workload prefix unchanged**: SHA256 `7a495986995b092f7895710d6af77af050c0eb68f4d4ff71bf6da0e3e212d048`. The full frozen input harness SHA256 is `007f951830e41986afbdb7ea75d314ff1352e68a04207877f31f9bf5399b4f0c`.

There are 15 warm scenarios, including three unhooked native-driver controls. Each interpreter runs three paired rounds with three samples per version per round: nine raw samples for each version/scenario. Each CPU sample uses 3,000 operations with garbage collection enabled; heap samples use 1,000 operations with collection stopped. Warm-up and each retained-heap batch use 1,000 operations. Versions run back-to-back and alternate first position by scenario and round. Lua 5.1.5 and Lua 5.4.6 run serially, completing 90 version batches per interpreter. Snapshot, live-source and output hashes are verified before and after each process.

Every paired timer native-call count and settled text/geometry signature matches .355. Existing assertions also pass for no new warm font measurement, formatter construction/validation or bindings, no redundant buff geometry writes, zero unchanged-tenth cell repaints, and the expected three cell writes for a changed tenth. The full native writer scenario includes `UpdateDuration → SetFontObject → SetPoint`; it is not the entire native aura OnUpdate or every client/locale path. Same-profile action setup deliberately replays a safe lifecycle epoch and is not an ordinary countdown tick.

### Temporary Lua heap growth

Values below are median **GC-stopped heap growth in bytes per operation**, not addon RAM or an exact gross-allocation accounting. Fractional residue includes fixed fixture/measurement costs amortized over the batch.

| Workload | Lua 5.1: .355 → .356 | Lua 5.4: .355 → .356 |
| --- | ---: | ---: |
| Public buff, unchanged tenth | 0.000 → 0.000 | 0.320 → 0.320 |
| Public buff, changed tenth | 0.000 → 0.000 | 0.384 → 0.384 |
| Readable native long-buff text | 680.139 → 0.139 | 751.884 → 111.884 |
| Native-formatted short buff | 952.640 → 0.640 | 896.576 → 0.576 |
| Public buff + native font/anchor writes | 2296.000 → 384.000 | 2048.384 → 248.384 |
| Changed public buff + native font/anchor writes | 2296.000 → 384.000 | 2048.384 → 248.384 |
| Long buff + native font/anchor writes | 2840.139 → 384.139 | 2671.884 → 359.884 |
| Native-formatted buff + font/anchor writes | 3112.640 → 384.640 | 2816.576 → 248.576 |
| Unchanged buff safe setup | 2744.640 → 480.640 | 2496.576 → 424.576 |
| Action duration rebind | 1496.000 → 0.000 | 1408.448 → 0.448 |
| Idle action cooldown update | 680.000 → 0.000 | 640.448 → 0.448 |
| Unchanged action safe scan | 7106.470 → 4386.470 | 6408.400 → 3848.400 |

The native-formatted short-buff path removes **952 bytes/op on Lua 5.1 and 896 on Lua 5.4**. Action rebind removes **1,496 and 1,408 bytes/op** respectively. Public duration-only cases remain allocation-neutral. The reductions are consistent across all three paired rounds. Every measured retained-heap delta after both retained batches is zero for these fixtures; this is not a general leak guarantee.

### CPU observations and uncertainty

These are median native-interpreter process CPU samples in **microseconds per operation**. They include the Lua native-boundary doubles and exclude real engine work.

| Workload | Lua 5.1: .355 → .356 | Lua 5.4: .355 → .356 |
| --- | ---: | ---: |
| Public buff, unchanged tenth | 24.539 → 33.264 | 13.503 → 12.303 |
| Public buff, changed tenth | 33.491 → 37.068 | 17.170 → 19.723 |
| Readable native long-buff text | 39.211 → 35.003 | 29.990 → 21.647 |
| Native-formatted short buff | 53.268 → 39.970 | 61.747 → 32.721 |
| Public buff + native font/anchor writes | 77.020 → 61.739 | 46.951 → 43.491 |
| Changed public buff + native font/anchor writes | 83.808 → 65.227 | 56.623 → 52.029 |
| Long buff + native font/anchor writes | 98.109 → 66.332 | 56.500 → 51.440 |
| Native-formatted buff + font/anchor writes | 123.294 → 85.002 | 70.044 → 60.714 |
| Unchanged buff safe setup | 318.712 → 239.132 | 164.187 → 167.519 |
| Action duration rebind | 58.223 → 21.066 | 20.924 → 17.231 |
| Idle action cooldown update | 13.842 → 12.142 | 12.143 → 9.346 |
| Unchanged action safe scan | 504.907 → 483.586 | 382.181 → 434.358 |

There is substantial host/order scatter. Apparent regressions are retained: public unchanged buff duration on Lua 5.1 rises from 24.539 to 33.264 µs/op, and public changed duration on Lua 5.4 rises from 17.170 to 19.723. Their three paired per-round ratios span 0.976–1.755 and 0.735–1.358 respectively. Even unchanged native-only Lua 5.1 SetCooldown controls span 0.728–2.668. One opaque full-writer round reaches 3.827 while the other rounds are 0.777 and 0.419.

These samples do not establish a stable whole-addon CPU speedup or causal regression. Several changed paths have lower medians, but allocation reductions, selected output and operation counts are stronger evidence. No extra timing run was chosen to replace an unfavorable sample. All nine actual samples, per-round ratios, ranges, native counts and signatures are retained in the [portable evidence](performance/0.2.356/performance-evidence.json).

## Final NPC color counter comparison

The same full-module native-hook fixture runs on both versions and both interpreters, using 0, 20 and 40 plates, matched/unmatched NPCs, players, unchanged repeated callbacks and unrelated hooks. Positive native permission methods and direct lookups are counted. Every one of the 64 rows per version/interpreter asserts resulting RGBA; the native witness color differs from fallback. Values below are .355 → final .356.

| Matched NPC callback | Plate-list requests | Direct lookups | UnitIsUnit checks | Region sets / items | Native RGB reads | Recipient writes |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Ordinary health update, 20 plates | 1 → 1 | 0 → 0 | 21 → 22 | 3 / 9 → 0 / 0 | 2 → 1 | 1 → 1 |
| Ordinary health update, 40 plates | 1 → 1 | 0 → 0 | 41 → 42 | 3 / 9 → 0 / 0 | 2 → 1 | 1 → 1 |
| Originating native color hook, 20 plates | 1 → 0 | 0 → 1 | 25 → 8 | 3 / 9 → 0 / 0 | 2 → 1 | 1 → 1 |
| Originating native color hook, 40 plates | 1 → 0 | 0 → 1 | 45 → 8 | 3 / 9 → 0 / 0 | 2 → 1 | 1 → 1 |

The shortcut has safety costs: matched originating-hook GUID calls rise from 7 to 17 and permission probes from 3 to 10. Ordinary health updates still scan the list, with one additional current pet/UnitIsUnit check and two GUID calls for post-discovery eligibility. It would be incorrect to claim that every query or every callback became cheaper. Readable players still bypass NPC plate lookup; unrelated hooks cause no recipient write. Full changed counters, including increases, are in [health-counter-deltas.tsv](performance/0.2.356/health-counter-deltas.tsv).

The original exports `performance-evidence-0.2.356-final.json` and `health-counter-deltas-0.2.356-final.tsv` are copied byte for byte into the repository as `performance-evidence.json` and `health-counter-deltas.tsv`. The JSON retains the original TSV basename for provenance.

## Soft Dark recovery decision

Keep the full combat-exit discovery pass. Both versions/interpreters produce identical settled discovery counts. The synthetic 116-action-object fixture reads 116 normal textures and 116 colors with zero tint writes; the deliberately deep 31-frame PRD fixture performs 31 region and 31 child queries with zero writes. These are constructed workloads, not measured real-client tree sizes.

A separate recovery probe silently replaces an action texture and introduces a late action button without calling an observed addon hook. Combat exit discovers and themes both, while a settled follow-up avoids repainting. The `pending` flag records already observed blocked work; it does not prove that current native object identities are unchanged. Skipping discovery on that flag would remove this recovery boundary.

## Review and source reconciliation

Independent review covered the timer change, native-color change and combined branch. Consumer regressions demonstrated and then repaired an actor changing from NPC to player/pet/unavailable during lookup or RGB reads, and an older color operation being superseded by a callback from a later identity getter. The final discovery suite contains **38 full-module cases**. The last repair adds a three-line revision receipt/guard to main, plus its regression.

That final main-only guard was added after the timed comparison. The timer harness does not load main: all five production modules it actually loads, plus the Lua 5.1 compatibility helper, are verified byte-identical between measured and final source. The final health fixture was then replayed on .355 and final .356 with both interpreters; all RGBA assertions pass and counters exactly match the pre-guard comparison. No unrelated timer timing was repeated.

The portable JSON explicitly separates `measured_sources` from `final_package_sources`, records the loaded timer identity mapping and final health provenance, and preserves the original raw timing samples. Final package-input map SHA256: `23e25f387d6c93347472b4b4c2897a7deda5956f29003703ed1d69f007e507ad`. Final main SHA256: `b0b0034f54a371cc7ae60056a4dd9cc658a18663c86e9f3c2593dd8f1b611375`.

## Final release verification

- Native Lua **5.1.5**: all **37 top-level suites** pass; all 16 runtime modules and test sources compile through native `loadfile`.
- Native Lua **5.4.6**: all **37 top-level suites** pass; the same native source compilation passes.
- Existing aura suite: **226 cases**. Discovery: **38 cases**. Health observer: **123 cases**. Action digit suite: **5,293 assertions**. Static action numerals: **464 transitions**. Counts describe fixtures, not a percentage of client coverage.
- Both manifest versions and the 16-module load order match. `git diff --check`, archive integrity, exact membership and packaged byte equality pass.

No standalone `luac` is installed in this local environment; the native interpreter's `loadfile` performs compilation. The package uses repository `tools/verify.py` manifest and archive validation with the established local adapter running the native tests and compilation. The stacked draft PR is outside the workflow's `main` trigger; these are local results, not a claim of GitHub CI execution. Standard reproduction commands are in [TESTING.md](TESTING.md).

## Installable package

`bjarkiUI-0.2.356-Presentation-Performance.zip` contains the normal `bjarkiUI/` folder: **19 files**, consisting of 16 runtime modules, two manifests and the existing spacer texture. Archive size: **133,456 bytes**. Expanded package: **525,175 bytes**, of which Lua source is **523,041 bytes**. File size is not runtime memory.

SHA256: `b9860991382670bd439c020ab27d4a8f496264a7d69a5c4861c1a5af92297637`.

Tests, reports, measurement data and source snapshots are excluded from the installable ZIP. Current rendering, protected-call behavior, real native formatter/API costs, client GC, full-addon CPU and FPS remain live checks. No inaccessible timing is decoded, no minimum/GCD rule is relaxed, and no new diagnostic command is required.
