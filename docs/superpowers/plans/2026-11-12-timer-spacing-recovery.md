# Timer spacing recovery implementation

**Goal:** Cover the native buff decimal route and repair stale/incorrect typography preparation on buffs and actions, preserving native timing and fonts.

**Baseline:** v0.2.354, upstream commit `1227e5baa97307d5ed56579a4dd6beb411dbb353`, tree `2379d76343304f96d4b9f50652fcc11a3eb68145`.

**Spec:** `docs/superpowers/specs/2026-11-12-timer-spacing-recovery.md`.

- [x] Trace the two screenshots, current formatter/owner paths and pinned Forever API contracts; reproduce the plain opaque-buff output, missed buff retry and stale inherited-scale map.
- [x] Extend focused fixtures with the relevant failure/recovery scenarios before runtime changes.
- [x] Repair optional buff formatter coverage and safe typography refresh in the existing buff presenter.
- [x] Repair action scale inheritance/resync and bounded retry of rejected mapped formatters.
- [x] Expose sanitized cached typography preparation stages through the existing diagnostic.
- [x] Review the combined changes for owner handoff, combat restrictions, native fallback and timing invariants.
- [x] Update .355 metadata/current documentation, run both native Lua verification sets and validate the installable ZIP.
- [x] Prepare the verified development source, draft PR description and normal ZIP for publication/delivery. Keep the remaining live reports explicit.
