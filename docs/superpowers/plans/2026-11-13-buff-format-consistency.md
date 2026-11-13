# Buff format consistency implementation plan

Use superpowers:executing-plans for this tightly coupled repair. Independent source/geometry investigations and a fresh final review support inline implementation.

**Spec:** [Buff format consistency design](../specs/2026-11-13-buff-format-consistency-design.md).

## Global constraints

Preserve exact fonts, native clocks/settings, .361 action behavior and the 16-module runtime. No live protected-text inspection, new timer, per-tick geometry, guessed identity/duration or fabricated native clock. Keep writer/assignment/physical-owner checks and bounded replay. Native seconds-only fallback cannot select a secret below-ten threshold. Report modeled results separately from live behavior.

## Task 1: Prepare a validated whole buff seconds format

Files: ActionTimerSpacing.lua, tests/action-timer-spacing.lua.

- [x] Add RED tests for complete guarded native printf output, edge bearings, pair-kerning cancellation, unavailable/secret metrics, height, cache reuse and safe retry.
- [x] Add `GetFixedBuffSecondsFormat(label)` with shared probe, full public sample validation and bounded style cache; no current text or numeric input.
- [x] Run focused tests on native Lua 5.1 and 5.4.

## Task 2: Repair native buff source selection and short presentation

Files: BuffPresentation.lua, tests/aura-presentation.lua.

- [x] Add RED cases for mixed readability, public-identity coexistence, suffix-free opaque fallback and genuine-object reentrant cache safety.
- [x] Prefer genuine native-duration formatting inside the guarded transaction, retaining retries/cache on fallback. Keep `SetText` as later-writer; use exact `%s` owned sink for opaque formatted output.
- [x] Apply current prepared whole format to public short/native short presentation and the seconds-only opaque fallback; otherwise retain safe cells/plain output. Preserve current public precision and larger units.
- [x] Cover same-ID nested assignment, sink before/after later writer, physical transfer, selector/refusal and retry recovery; run focused tests.

## Task 3: Verify and deliver .362

- [x] Independent review; resolve concrete findings.
- [x] Update version/release/known-issue documentation, preserving open live status.
- [x] Run all 37 suites on both native interpreters, verify the 19-file ZIP and source hashes.
- [ ] Commit, publish the already-authorized stacked draft, save and link the installable ZIP. Publication follows this verified source snapshot and is recorded in the external release ledger.
