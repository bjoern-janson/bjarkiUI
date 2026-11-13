# Action width validation implementation plan

> **For agentic workers:** Use superpowers:executing-plans for this focused repair; independent source investigation and a final fresh review support the implementation.

**Goal:** Allow the existing native action formatter to work for the user's reported tabular fonts when public character-area geometry is unavailable.

**Architecture:** Retain .360's native formatter and owned handoff. Add a conservative constant-guard, native-width validation route inside ActionTimerSpacing.lua, preserving the original character-area route and all buff/cell glyph helpers.

**Tech Stack:** WoW Lua, native public FontString sample metrics, NumericRuleFormatter; native Lua 5.1 and 5.4 fixtures.

**Spec:** [Action width validation design](../specs/2026-11-13-action-width-validation-design.md).

## Global constraints

- Exact current fonts, action tenths below 10, whole seconds below 91, then rounded-up minutes.
- No live countdown reads, guessed clocks, per-tick measurements, extra ticker, dependency or user setting.
- BuffPresentation.lua, CooldownSeconds.lua and NativeDigitCells.lua retain .360 behavior.
- Unknown/secret/refused measurements cannot earn acceptance. Valid contradictory character geometry must still reject.
- Evidence separates source, modeled tests, package equality and user-observed behavior.

## Review focus

- Native width rounding can conceal small differences; validate repeated guarded samples and disclose metric-resolution limits.
- Equal full string width alone cannot establish stable internal columns; verify prefixes and suffixes.
- Integer texture widths can work where fractional parsing does not; this fallback uses integer guards only.
- A later failed character span cannot convert previously contradictory geometry into a successful fallback.
- Width measurements and failures must be cached and cleaned up through existing typography epochs.

## Task 1: Add the missing supported-native-width route

**Files:** ActionTimerSpacing.lua, tests/action-timer-spacing.lua.

**Interfaces:** Keep GetFixedActionFormatter, IsFixedActionFormatter and existing diagnostic counters; add a fixed public success stage identifying width validation.

- [x] Write a failing fixture for absent character-area results with tabular advances, nontrivial bearings and kerning. Assert actual emitted formatter spelling and hand-derived columns.
- [x] Run the focused suite on native Lua 5.1 and 5.4 and record the expected failure.
- [x] Add the constant integer-guard route with all-digit/repeated-width, prefix/suffix, whole-string, height and widget-fit checks. Retain rejection on valid contradictory character geometry.
- [x] Cover unavailable/secret widths, ineffective guards, unequal advances, rounded widths, column drift, cache reuse and safe retry with independent layout assertions.
- [x] Run the focused suite on both native interpreters and review the diff.

## Task 2: Verify and deliver .361

**Files:** Version identifiers and current release documentation; new verification/source-hash files. No additional runtime behavior.

- [x] Independently review the change and resolve concrete findings.
- [x] Update known issues to record the user's .360 buff observation and continuing action failure.
- [x] Run all 37 suites on native Lua 5.1 and 5.4; package exactly the established 19 inputs and compare source bytes.
- [ ] Check the working diff, record evidence, commit, publish the already-authorized stacked draft and deliver the installable ZIP.
