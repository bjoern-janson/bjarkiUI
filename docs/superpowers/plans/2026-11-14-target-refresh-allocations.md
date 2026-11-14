# Target Refresh Allocation Cleanup Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation and a fresh whole-branch review. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Reduce demonstrated temporary allocation during target refreshes without changing presentation or recovery.

**Architecture:** Shared protected reader functions replace per-call captures in the main module, FrameLabelTweaks and IconSkin. Already-installed label hooks return before constructing unused callbacks. No event or discovery path changes.

**Tech Stack:** WoW Lua, native Lua 5.1 and 5.4 fixtures, Python verification/packaging.

**Spec:** `docs/superpowers/specs/2026-11-14-target-refresh-allocations-design.md`

## Global Constraints

- Keep all existing unit/class alias ordering and physical-recipient checks.
- Keep current protected-call boundaries, read order, secrecy checks and results.
- Keep native frame writes, geometry, fonts, timers, settings and artwork.
- Preserve hook refusal/retry, reentry guards and late-created/replaced objects.
- Add no runtime sampling, polling, cached frame identities or new options.
- Live self-target stutter remains open; fixture heap reduction is not client timing.

## Review Focus

- Throwing member getters remain inside the original protected expression.
- Secret, unavailable and false values retain their distinct handling.
- Refused hooks retry and installed hooks retain their exact callback semantics.
- Full safe discovery still observes late-created or replaced objects.
- Native call order, level/crown geometry and current fonts remain unchanged.

### Task 1: Remove demonstrated target-refresh allocations

**Files:** `bjarkiUI.lua`, `FrameLabelTweaks.lua`, `IconSkin.lua`; reproducible comparison tools under `docs/performance/0.2.367/`.

**Interfaces:** Existing public/native interfaces and callback signatures remain unchanged. Probes consume exact .366 and candidate runtime sources and frozen .366 fixtures, and emit allocation/call-parity results.

- [x] Record baseline/baseline failures for strict allocation-improvement checks.
- [x] Hoist main status methods, status member, power-bar and derived portrait reads; preserve each expression and protected boundary.
- [x] Share the existing member-read expression in FrameLabelTweaks and IconSkin.
- [x] Guard FrameLabelTweaks callback construction by the existing hook receipt; keep hookOnce's own checks.
- [x] Require lower bounded heap growth and identical ordered native calls/fixture presentation in both interpreters.
- [x] Run existing affected suites for status, health/name ownership, derived layout, frame labels, classic-party presentation, icon skins and aura presentation; inspect refusal/replacement cases.

### Task 2: Verify and deliver .367

**Files:** Both TOCs, version literal, README/AGENTS/code map/testing/known issues, source hashes and `docs/VERIFICATION_0.2.367.md`.

**Interfaces:** A 19-file installable ZIP matching the verified runtime payload, with an unchanged 16-module load order.

- [x] Update current-version documentation and retain the live self-target issue.
- [x] Run the full existing native Lua 5.1/5.4 gate; expect all suites and syntax checks to pass.
- [x] Obtain independent whole-diff review and resolve material findings.
- [x] Commit verified changes, create the exact-source stacked draft PR, package and save the normal addon ZIP.
- [x] Report the measured allocation improvement briefly, with its live-performance limit and no diagnostic chore.
