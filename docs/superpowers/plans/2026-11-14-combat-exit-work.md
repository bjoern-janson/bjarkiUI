# Combat-exit work implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans for the assigned task. Runtime-file ownership is disjoint; integration and release belong to the root agent.

**Goal:** Reduce verified redundant native layout writes, discovery allocations and unused buff calibration without weakening current recovery.

**Architecture:** Retain existing lifecycle and native update paths. Change only an exact anchor equality fast path, nonclassic queue rejection, two shared protected readers, and the complete range of actually emitted short buff samples.

**Tech stack:** Existing WoW Lua modules; native Lua 5.1 and 5.4 fixtures and Python package verifier.

**Spec:** [Design](../specs/2026-11-14-combat-exit-work-design.md)

## Global constraints

- Preserve native clocks, source access checks, the below-ten threshold and typography retry epochs.
- Preserve full safe artwork discovery and current .365 visuals.
- Add no polling, settings, dependencies or widgets.
- Report offline operation counts separately from in-client stutters.

## Review focus

- Native anchor changes or physical recipient replacement during a getter must not be mistaken for an unchanged layout.
- Unavailable/secret geometry must not authorize comparison; existing safe retry still works.
- Both copied-instance and mixin hooks must retain style-change and refused-scheduling recovery.
- Short decimal range reduction must preserve every emitted column and the 9.9/10-second boundary.
- Shared readers must preserve protected failure behavior and late-art recovery.

## Task 1: Nameplate repair work (root)

- [x] Add a source-backed fixture with retained geometry: settled writes, native reset, edge/list replacement, multiple anchors, unreadable getters, getter reentry, combat permissions, nonclassic scheduling and retry after scheduling refusal.
- [x] Run against .365 and record the redundant-write failure.
- [x] In `bjarkiUI.lua`, skip exact current LEFT anchors and reject positively nonclassic scheduling while preserving per-frame queue semantics.
- [x] Run the new fixture plus `tests/hardening.lua` and the existing full-module nameplate operation probe in both interpreters.

## Task 2: SoftDark allocation reduction (lifecycle agent)

- [x] Replace only capturing member/object-type readers in `SoftDark.lua` with shared protected functions.
- [x] Run existing SoftDark recovery suites in both interpreters; compare a frozen before/after discovery probe for identical native calls and exact visuals.
- [x] Measure temporary Lua allocation in a bounded, matched fixture with collection paused; retain source hashes and avoid a native CPU claim.

## Task 3: Short buff calibration (timer agent)

- [x] Add a regression requiring all 100 emitted short decimals, no unused two-digit family, stable accepted columns and rejection of inconsistent used columns.
- [x] Record failure against .365; reduce the sample range in `ActionTimerSpacing.lua` only after confirming the sole consumer clamps at 9.9.
- [x] Run `tests/action-timer-spacing.lua` and `tests/aura-presentation.lua` in both interpreters; retain threshold, cached success and safe-epoch recovery coverage.
- [x] Compare exact public native sample counts for cold character/scalar routes and warm cache reuse.

## Task 4: Integration and release (root plus independent reviewer)

- [x] Review all three diffs and regression evidence; resolve concrete findings.
- [x] Update version manifests, current docs, known issues and source hashes; preserve 16 runtime modules and 19 package files.
- [x] Run the complete native Lua 5.1/5.4 verification and package gate once final source is ready.
- Release transaction: commit these verified bytes, publish the stacked draft PR and deliver the ZIP. Record returned publication identifiers in the external release ledger; this source checkpoint precedes that transaction.
