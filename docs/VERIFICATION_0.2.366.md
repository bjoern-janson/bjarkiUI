# .366 lifecycle work: verification and performance evidence

## Outcome and source scope

This test build reduces three reproduced costs in current .365 source: repeated classic nameplate anchor requests, temporary SoftDark lookup closures and unused long-decimal buff preparation. It also skips nameplate repair scheduling when classic style is positively false. The user's microstutter report remains open until matched in-client measurements are available.

Baseline: .365 source tree `c94adfe014220533026df2099e2a908530431669`, local commit `e20c08193838bdf96377cd655b28713c97e7c948`, matching remote commit `f3e3658cf66c7172d155e9d56d7357d682e4ac9b`. Runtime changes are limited to `bjarkiUI.lua`, `SoftDark.lua` and `ActionTimerSpacing.lua`, plus the version fields in both manifests. All other runtime modules and the spacer texture retain exact .365 bytes.

The .365 level backgrounds/borders, portrait-side levels, secondary portraits, leader crowns, rested-Z suppression and native timer settings retain their existing behavior. No OnUpdate, ticker, dependency, saved setting, option, widget or runtime module is added. The manifests retain “Ultralight unit-frame presentation for WoW: Forever”.

## What the reported benchmark establishes

The user supplied 11 rendered intervals at least 25 ms, four at least 50 ms, a 69 ms worst interval and 22 bjarkiUI profiler ticks above 5 ms. These support prioritizing bjarkiUI as an addon CPU candidate. They do not identify the particular callback responsible for a frame or prove that the measured addon CPU explains all rendered latency. The exact installed bjarkiUI version and a completed matched UI-off result were not supplied with this report.

The inspected bjarkiPerf 0.1.0 package has SHA-256 `0911aa8d57d25feb6bb7a2e922a092e2873419add529a0db3889e0918399b5ff`. Its OnUpdate intervals and native profiler threshold deltas are distinct measures. Nominal snapshots occur every two seconds, with extra reads at event completion and stop; active windows can delay periodic sampling. Event rankings use a prior snapshot and can include pre-event work. The reported snapshot duration times the snapshot read/construction, rather than all observer activity. PeakTime is historical, not a baseline-subtracted value for the recording.

Primary native definitions: [profiler constants](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerConstantsDocumentation.lua) and [profiler API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/AddOnProfilerDocumentation.lua). Threshold counters describe ticks exceeding each threshold; the sources do not pair those counters with bjarkiPerf's observed rendered intervals.

A separate source-backed bjarkiPerf fixture reproduced an early-stop normalization defect: stopping 0.10 seconds into the final 1.35-second combat-exit window leaves `shortened` unset, so its saved summary counts that partial exit as complete. Let the final combat-exit window finish before stopping. No bjarkiPerf source or package is changed here. The reported four-versus-five entry discrepancy was not reproduced within a single stopped recording; completion between commands is a concrete possibility, not a finding about the user's screenshots.

## Reproduced reductions

Both native Lua 5.1 and 5.4 produced the same operation counts. [Machine-readable results and reproduction](performance/0.2.366/README.md) preserve the modeled populations, exact baseline tree and frozen probes.

### Nameplate layout

| Twenty-plate fixture, including deferred work | .365 | .366 |
| --- | ---: | ---: |
| Initial classic CC/LoC anchor writes | 40 | 40 |
| Settled repeat CC/LoC anchor writes | 40 | 0 |
| Nonclassic layout-repair callbacks | 20 | 0 |
| Nonclassic total callbacks, including target health | 21 | 1 |
| Full pass nameplate-list queries | 3 | 3 |
| Full pass NPC native-color reads | 2 | 2 |

The repair reads current public LEFT anchors; previous requests never serve as a layout cache. Native reset/replacement still repairs. Introduced getters are followed by current permission and exact physical-role checks. A weak native-writer revision catches same-object reentry, including a nested scheduling refusal. A successful newer queue retains its next-tick recovery; if scheduling fails, the existing safe writer remains available. Both instance and mixin hooks stay installed in nonclassic style. Unknown style retains deferred discovery.

### SoftDark temporary allocation

| Native interpreter | .365 median bytes per modeled exit | .366 median bytes per modeled exit | Fewer bytes |
| --- | ---: | ---: | ---: |
| Lua 5.1 | 202,066.28 | 54,210.28 | 147,856 |
| Lua 5.4 | 330,723.88 | 192,595.88 | 138,128 |

The fixed fixture has 116 action objects, one nested bag and seven sibling frames, totaling 118 textures. Each version receives three warm-ups and three measured batches of 25 settled exits. Garbage collection is paused during a batch; no CPU timer or debug hook runs. These figures represent temporary Lua heap growth including fixed fixture costs, not live addon memory or measured GC stalls.

Two shared protected readers replace 1,216 executed capturing closures per modeled exit. All 18 native-boundary counters, the complete 4,420-entry ordered trace, exact serialized RGBA/desaturation and zero settled tint writes match before/after. Full discovery remains necessary: existing probes still recover silently replaced textures and late-created action artwork.

### Buff typography preparation

| Cold preparation operation | .365 | .366 |
| --- | ---: | ---: |
| Character-route character queries | 3,515 | 311 |
| Character-route line widths | 951 | 150 |
| Character-route native printf calls | 1,802 | 200 |
| Scalar-route character queries | 1 | 1 |
| Scalar-route line widths | 3,117 | 390 |
| Scalar-route native printf calls | 1,802 | 200 |

The only production consumer of the private buff format sends short values clamped to 9.9, either through its public seconds sink or native duration rules. Ten seconds and above keep native unit formatting. The previous calibration still checked 901 decimal strings through 90.0; .366 checks all 100 actually emitted 0.0–9.9 strings, retaining every guard, numeral, complete column, height, width, current-style and fit check. Kerning limited to unused two-digit strings can no longer reject a valid short profile.

Forty warm calls after a safe retry epoch produce zero new character/width/printf/formatter/probe work in both versions. Savings therefore apply to cold or new profiles and sufficiently late retry failures. This does not reduce every countdown tick, and the action retry/minimum-gate policy is unchanged.

## Correctness and package verification

The new nameplate suite has 20 scenarios for exact unchanged geometry, native reset, every tuple field, multiple anchors, replacement, unavailable/secret getters, failed native writes, post-getter permission, current CC/LoC role, both native observers, nonclassic style, scheduling refusal and same-object reentry. Against .365, the initial fixture produced 12 relevant failures; after implementation the completed suite passes in both native interpreters. Existing hardening retains its 43 assertions.

The buff regression failed against .365 in both interpreters because unused adjacent-digit kerning rejected supported short columns. The revised suite validates native plain and guarded printf for all 100 short values and checks cache reuse on both metric routes. The 271-case aura suite retains 9.999→9.9 and 10→native seconds transitions across supported and unsupported input paths.

The final release command passed with native Lua 5.1 and Lua 5.4: **16 runtime modules, 37 suites per interpreter (36 behavioral plus manifest syntax), 19 package files**. The new nameplate suite reports 20 passes and the aura suite 271. The independent source review reported no material findings; its rerun confirmed nameplate/hardening behavior and full-module operation counts under both interpreters. The portable reproduction script independently matched all recorded operation counts and the paired allocation reductions.

```sh
python3 /workspace/scratch/56461e2d1ebd/verify_ui356_local.py --root /workspace/scratch/56461e2d1ebd/bjarkiUI-0.2.363 --log /workspace/scratch/56461e2d1ebd/ui366-evidence/final.log --output /workspace/scratch/56461e2d1ebd/deliverables/bjarkiUI-0.2.366-Lifecycle-Work.zip
```

Package: `bjarkiUI-0.2.366-Lifecycle-Work.zip`.

- SHA-256: `37c28c5b7b22016307fc7205721b10dea3730703ac812fb7e6a3ef10b9788985`
- Compressed: 144,109 bytes; expanded: 578,514 bytes; runtime Lua: 576,400 bytes.
- All 19 ZIP payloads match the verified source byte-for-byte; only the three stated runtime modules and two manifests differ from .365.
- [Source checksums](SOURCE_SHA256_0.2.366.txt) cover every installable file. Test/benchmark inputs, docs and reports are excluded from the installable package.

Publication identifiers are recorded in the external `ui366-evidence/` release ledger after the verified source is committed. Separate live checks remain necessary for frame pacing, actual optical rendering, client secrecy/taint, native formatter cost and client garbage collection.

## Matched in-client comparison

Save the existing recording before starting another one. A useful comparison uses the same route, camera behavior, enemies, nameplate style and other addons, with 8–10 combat exits per condition. Use .365 as `before366`, then this build as `after366`, and compare through bjarkiPerf. Allow at least two seconds after the final exit before stopping, so the existing profiler's last event window completes.

If a baseline already has a different saved name, preserve it and use that name rather than overwriting it. Counts above 5/10 ms, slow/severe frames per complete exit and worst exit frame answer different questions; assess them together. A further UI-off comparison remains useful if the live stutters persist. This release supplies the lower-work candidate, not a claim that the 69 ms frame cause is resolved.
