# .367 target-refresh allocation evidence

These developer-only probes compare the complete runtime modules against .366
tree `546ee7ea64be8f2ff5a2f2955c4de7e1bbf34b5f`. They are excluded from the addon
ZIP. [Recorded results](results.json) describe bounded native Lua fixture heap
growth with garbage collection stopped, not live client CPU or frame time.

Run from a clone containing the baseline tree:

```sh
python3 docs/performance/0.2.367/reproduce.py \
  --lua51 /absolute/path/to/lua5.1 \
  --lua54 /absolute/path/to/lua5.4 \
  --output /new/directory/outside/the/checkout
```

The wrapper stages exact before/current sources and the Lua 5.1 compatibility
preload. It checks the frozen label fixture against the baseline Git object,
records input hashes and commands, and requires all six paired comparisons to
pass. Logs and label native-call/state traces remain in the output directory.
Different hosts may produce small differences in raw heap totals.

| Probe | Fixture / protocol | Behavior comparison |
| --- | --- | --- |
| `main-readers.lua` | Full main module with a frozen nameplate-color scenario extended for Target/ToT status and native updates; minimum of three batches of 1,000 warmed calls for four routes. | Fourteen cases compare native calls/arguments/counters and presentation, including missing class data and both native/event orders. |
| `labels/compare.lua` | Three levels, three crowns, combat icon and six bag counts; median of three batches each at 25 and 50 warmed target events. | Sixteen cases, 11,558 native-call entries and 376 state snapshots, including all five refused-hook sites, native reset order, combat recovery and physical replacements. |
| `icon-readers.lua` | Frozen aura scenario, actual retired Target aura stub, four compact debuffs and five references to one cast bar; 128 warmed combined target/native refreshes. | Two deferred/native orders, each with 1,080 native-call entries and four visible-state snapshots. |

Before implementation, each probe was run against the baseline on both sides:
behavior parity passed and the allocation-improvement requirement failed under
both interpreters. Current comparisons pass. The unchanged 37-suite behavioral
gate is separate from these paired performance probes.

The probes measure different modeled workloads. Do not add their bytes or
percentages together as a claim about one client frame or total addon memory.
See [verification and limits](../../VERIFICATION_0.2.367.md).
