# .356 Presentation Performance Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task by task. Keep file ownership disjoint and integrate only after source review.

**Goal:** Reduce demonstrated timer allocations and redundant NPC color discovery while preserving .355 presentation and permission behavior.

**Architecture:** Replace short-lived protected lookup closures with shared readers. Use the first native color witness and revalidate optional native callback context without persistent identity/color caches. Reuse safe-setup constants/receipts only where unchanged recovery is established.

**Tech Stack:** WoW: Forever Lua; native Lua 5.1/5.4 verification; existing Python packager and offline profiling probes.

**Spec:** `docs/superpowers/specs/2026-11-13-performance-cleanup-design.md`.

## Global constraints

Preserve every contract in the spec and `AGENTS.md`. No font/clock/threshold/layout/settings changes, no extra ticker, no inaccessible-value inspection and no main-branch merge. Keep old performance measurements immutable and record new probe/source hashes separately.

## Review focus

- Secret or throwing member reads must keep the same fail-open result; use existing timer ownership/refusal regressions.
- A stale frame/token or direct-lookup wrapper must not tint from the wrong NPC; add hint mismatch/reuse cases.
- Missing/forbidden/secret direct color must retain native fallback and first-witness priority; add readable/fallback cases.
- Re-entrant getter changes must invalidate the supplied association before using it; add current-unit/physical-frame checks in the health tests.
- Unchanged typography receipt reuse must still call the formatter's safe retry path and replace a newly recovered formatter; retain retry/scale/owner regressions.

## Task 1 — Timer allocation cleanup

**Files:** `NativeDigitCells.lua`; optional unchanged-receipt reuse in `BuffPresentation.lua`; existing timer tests.

**Interface:** Internal `readMember(object, key)` protected by existing `m/field` checks; no public API signature changes.

- [x] Confirm green .355 source baseline and preserve measured baseline heap/call results.
- [x] Replace only the two captured member-reader closures with one shared reader.
- [x] Evaluate hoisting the constant buff layout-hook list and reuse of an identical `durationTypography` receipt; keep all native reads and formatter retries.
- [x] Run relevant timer regression suites under both interpreters; use the real-source benchmark to establish reduced heap growth and unchanged native-call counts/output.

## Task 2 — NPC color discovery cleanup

**Files:** `bjarkiUI.lua`; existing health/lifecycle tests or a focused full-module `tests/nameplate-color-discovery.lua` if existing fixtures stub the needed route.

**Interface:** `matchingNamePlate`, `npcHealthColor` and `applyHealthColor` may consume an optional call-local native frame/token hint. General callers retain current lookup/fallback behavior.

- [x] Add tests that assert selected RGB and avoid region enumeration after the first readable direct color; observe failure on .355.
- [x] Add full-hook tests for verified native hint lookup, mismatch/secret/missing/forbidden fallback, reused physical frame and unit change during a getter. Assert the recipient's resulting RGB, current identity, and native search counts.
- [x] Return the first native color witness and accept only positively revalidated direct associations. Preserve fallback order; do not add persistent plate/RGB caches.
- [x] Run health/name/lifecycle/hardening tests on Lua 5.1/5.4 and independently review permission/owner transitions.

## Task 3 — Integrate and deliver .356

**Files:** version constant and TOCs; `README.md`, `CHANGELOG.md`, `AGENTS.md`, `KNOWN_ISSUES.md`, current code/testing/lifecycle docs, `docs/VERIFICATION_0.2.356.md`.

- [x] Freeze runtime after independent review; compare .355 and .356 with identical workload functions and alternating version order.
- [x] Record timing ranges, heap-growth deltas, native call counts and model limitations. Evaluate Soft Dark discovery; retain required recovery unless an established safe reduction is available.
- [x] Bump to `0.2.356-presentation-performance-test`, update affected documentation and record exact verification evidence.
- [x] Run all current top-level suites on native Lua 5.1 and 5.4, compile via native `loadfile`, and verify the normal 19-file addon package.
- [ ] Commit the exact verified source; publish a tree-identical stacked draft PR; save and deliver the installable ZIP. Do not merge.
