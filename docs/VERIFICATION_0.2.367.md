# .367 target refresh: verification and allocation evidence

## Outcome and source scope

The user still reports a self-target microstutter after .366 and declines a
manual tracing workflow. This build reduces reproducible temporary allocation
in the target-refresh code. It does not establish the cause of the live hitch or
that the hitch is fixed.

Baseline is .366 tree `546ee7ea64be8f2ff5a2f2955c4de7e1bbf34b5f`, local commit
`23cbc26fdd6015e352948febaa8ed976fc86d8a4`, matching remote commit
`a7bc87ca33956f97a6e8aef9993e758a6580004a`. Runtime changes are limited to
`bjarkiUI.lua`, `FrameLabelTweaks.lua`, `IconSkin.lua` and version fields in both
TOCs. [Payload hashes](SOURCE_SHA256_0.2.367.txt) identify the candidate exactly.

The main module shares four protected readers; the label and icon modules each
share one. Their values are never cached. The label module constructs native
observer callbacks only when their existing hook receipt is false or absent.
Refused hooks still retry; installed callbacks retain their own-write guards.

No event scope, native call, alias priority, permission check, clock, setting,
layout, font or artwork policy is removed. All 16 runtime modules remain. No
runtime sampler, polling, dependency or option is added. The manifests retain
“Ultralight unit-frame presentation for WoW: Forever”.

## Measurements

All numbers below are GC-stopped Lua heap growth from fixed engine doubles,
including fixture costs. They are not elapsed CPU time, live retained addon
memory, measured garbage-collection pauses or rendered frame time.

| Modeled workload | Lua 5.1 before → after | Lua 5.4 before → after |
| --- | ---: | ---: |
| Main target-change event, bytes/call | 5,184.672 → 736.672 | 4,776.448 → 680.448 |
| Main native Target + ToT updates followed by target event, bytes/call | 12,000.672 → 3,376.672 | 11,088.512 → 3,152.512 |
| Label pass, median KiB / 50 target events | 1,448.078125 → 143.781250 | 1,363.328125 → 137.937500 |
| Icon target/native refresh, bytes/refresh | 37,061.406 → 13,397.406 | 34,164.156 → 11,892.406 |

The main target event removes 44 temporary reader closures; the combined native
pair and event remove 86. The label pass removes 183 temporary field readers and
19 unused callback constructions per modeled event. The icon workload removes
174 temporary reader closures per modeled refresh. Shared functions are created
once when the modules load.

The label workload allocates about 90% less and the icon workload about 64–65%
less. These are separate modeled workloads, not percentages for the whole addon
or a single client frame. [Portable probes, protocols and recorded results](performance/0.2.367/README.md).

## Behavioral evidence

- Main: fourteen paired scenarios preserve native call order/arguments/counters
  and presentation. The unavailable-class case still performs four plate-list
  queries and 258 `UnitIsUnit` calls with twenty modeled plates; no self-alias
  priority shortcut is included.
- Labels: sixteen paired scenarios preserve 11,558 ordered native calls and 376
  geometry/font/visibility snapshots. A settled event retains 918 protected
  calls with no native writes, new hooks or identity queries. All five hook
  refusal/retry sites and late physical replacements are covered.
- Icons: both deferred/native orders preserve 1,080 native-boundary entries and
  four visible-state snapshots each. The one callback, five Apply calls, eight
  paints and all decoration writes remain.
- Each baseline/baseline allocation gate failed as expected before edits, after
  passing behavior parity. All six current comparisons pass on native Lua 5.1
  and Lua 5.4.
- The current 37 regression suites and all 16 runtime modules pass under both
  native interpreters. Existing status, name/health ownership, frame-label,
  classic-party, icon and aura fixtures remain unchanged.

The first full gate caught a fixture extraction dependency in the main reader
placement: two isolated status suites did not include the helper declared above
their section marker. The helper now resides inside that status section. Both
suites and the complete gate pass without modifying their tests.

A fresh read-only review found no Critical, Important or Minor issues in the runtime changes, evidence or documented limits. It reviewed the paired-probe structure and supplied successful runs; the complete native test, reproduction and archive executions were performed by the implementer.

## Package verification

The installable archive contains the matching manifests, 16 runtime Lua modules
and the spacer texture: 19 files, 579,560 expanded bytes and 144,404 ZIP bytes.
Archive integrity, exact membership and byte equality with all verified payload
inputs pass. Only the three scoped runtime modules and two versioned manifests
differ from .366; every other packaged file is byte-identical.

ZIP SHA-256: `6b1b8cbd349a741e80f26f95fe57ab7f3ef582f7d102dc84ffab18f9e42da674`.
Tests, probes, documents and settings files are excluded from the package.

## Practical limits

The warm readable self-target model does not show an unbounded update loop.
The more expensive class-alias fallback remains conditional on unavailable class
reads; its live frequency is unknown. Portraits native aura-container work is
outside this patch. The user is not assigned another diagnostic workflow.

The self-target microstutter and prior live timer limitations remain recorded in
[known issues](../KNOWN_ISSUES.md). Offline equivalence and allocation savings do
not close those reports or establish in-client taint/rendering behavior.
