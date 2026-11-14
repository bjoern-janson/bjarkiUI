# .366 bounded performance comparisons

[Recorded results](results.json) compare .365 tree `c94adfe014220533026df2099e2a908530431669` (remote commit `f3e3658cf66c7172d155e9d56d7357d682e4ac9b`) with the .366 source. These fixtures count public native calls and measure GC-stopped temporary Lua heap growth. They do not measure the WoW renderer, client CPU, GC pause durations or actual microstutters.

## Reproduction

Run from a checkout containing the baseline tree and the current .366 sources, with native Lua 5.1 and 5.4 available:

```sh
python3 docs/performance/0.2.366/reproduce.py --output /tmp/bjarkiUI-366-comparison
```

The output directory must be new and outside the checkout. `--lua51` and `--lua54` accept explicit executable paths. The script extracts exact baseline blobs and current source bytes into separate temporary roots, records input hashes, runs the same probes against both, and preserves raw output. The release's full test gate is separate.

## Fixed populations and scope

- `main-exit-counts.lua` loads the complete main module with the existing native-health fixture. Twenty plates, two retained control-list anchors each, one NPC target, settled micro menu and focus flash. Initial repair still writes 40 anchors. Settled repeat writes fall from 40 to zero. Nonclassic total callbacks fall from 21 to one; the remaining callback is intentional target-health reconciliation. Other counted discovery/color reads remain identical.
- `buff-preparation-counts.lua` freezes the public-font model from the .365 action fixture. It loads actual NativePrecision, ActionTimerSpacing and CooldownSeconds modules. It records cold character/scalar routes, then 40 warm lookups after advancing the safe retry epoch. Both before and after retain zero warm geometry/printf work; only preparation of unused 10.0–90.0 decimal strings disappears.
- `compare-softdark.lua` loads complete frozen SoftDark sources and the same .365 discovery fixture. Population: 116 action objects, one nested bag, seven sibling frames, 118 texture objects. Each version gets three warm-up exits; three samples then run 25 settled exits with GC temporarily stopped. No debug hook or CPU timer runs. All 18 counted native-boundary operations, the 4,420-entry call order and exact serialized colors/desaturation must match before/after. Allocation size depends on the interpreter/build; interpret the paired change rather than treating these values as live addon memory.

The SoftDark helper replacement removes the 851 capturing member lookups and 365 capturing object-type calls counted in the initial fixture. Full safe discovery is retained, including silent texture replacement and late-created action art. No permanent polling or profiling is added to the addon.
