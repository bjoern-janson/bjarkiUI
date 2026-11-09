# Codex deep bug audit — bjarkiUI 0.2.309

**Mode: exhaustive read-only audit. No fixes, commits, refactors or UI changes.** The owner wants to spend available Codex capacity on discovering and understanding defects before authorizing any changes. This is not a request to produce a new release. Follow root `AGENTS.md`.

## Goal and reporting standard

Identify **actual, triggerable bugs** and highest-risk missing coverage in the precise source at `audit/codex-0.2.309-readonly`. Prioritize correctness, addon safety, combat-time CPU/GC overhead, Blizzard secret-value/taint rules, and visual stability. For every reported finding, provide:

- **Severity:** P0 (breaks combat/taints protected action), P1 (serious regression, repeated stutter, lost UI functionality), P2 (wrong timer/state/visible defect), P3 (conditional edge case), or *unverified risk*.
- **Path and narrow line range**, call chain, exact trigger, expected vs actual result, and why the model permits that trigger. State whether observed in a test, source-proof, or only hypothesized.
- **Reproducer:** a minimal command, self-contained Lua harness or state timeline; where secrecy prevents offline reproduction, state the exact client condition needed. If generating a scratch test, keep it outside the checkout.
- **Minimal proposed patch** and associated regression test (describe, do not apply). Estimate risk to visual settings, protected APIs, and frame time.
- **Counterarguments / false positives:** identify the existing guard or native API contract that could make the allegation wrong.

Do not fill the report with speculative micro-optimizations. Prefer 5 precise findings to 50 plausible guesses; spend extra time trying to disprove each finding.

## Suggested multi-hour research plan (adjust effort to evidence)

**Phase 1 — Baseline and ownership (15–30 min).** Verify branch/manifest/frozen source, run version-matched suite, read both TOCs, README, architecture and known-issues history. Inventory events, hooks, `OnUpdate`, timer creation, weak tables, native frame ownership and late initialization; map production dependency/load order. List any baseline/legacy-test drift separately from code defects.

**Phase 2 — New native timers (60–90 min; highest priority).** Audit `NativeDigitCells.lua`, `CastBarDigits.lua`, `CooldownSeconds.lua`, `BuffPresentation.lua`, `TrackedBuffSeconds.lua` together. Trace their interactions with native Blizzard countdown visibility, native binding activation/disabling, `C_ActionBar.GetActionCooldownDuration(..., true)` / spell path, `UnitCastingDuration` and `UnitChannelDuration`, aura refresh, and secret/forbidden data. Exercise start, finish, cancel, interrupt, reuse, keybind changes, GCD-only, real cooldown during GCD, cast-to-channel and channel-to-cast, spell replacement, logout/reload, and Edit Mode. Boundary table: 0, 0.1, 0.9, 1, 9.9/10, 10/9.9, 59/60, 99/100, 359/360, and duration unavailable/secret. Check for duplicate presenters for 1–3 frames, blank numbers, stale text, positioning drift and hidden native fallbacks. Verify that `SetHideCountdownNumbers`/restore logic has single ownership across reinitialization and combat.

**Phase 3 — Safety, taint and layout lifecycle (45–75 min).** Review `bjarkiUI.lua`, `FrameLabelTweaks.lua`, `IconSkin.lua`, `UnitAuraStyling.lua`, `PartyOrder.lua`, and `SoftDark.lua`: forbidden-object guards, `issecretvalue` failures, protected setters, frame name/identity reuse, hook retry state, one-time-init assumptions, combat entry/exit, UI scale and Edit Mode handoffs, native artwork/class-colour ownership, disposal, and restoration after partial failure. No target/focus aura replacement: that previously caused a protected-action block. Examine registered event order and source-private mixins for native changes; do not infer writable access from successful mock calls.

**Phase 4 — Adversarial fault injection and performance (45–90 min).** Test missing APIs, throws, nil returns, secret arguments, re-entrant hooks, item/attribute changes mid-combat, pooled frame recycling, different locale decimal separator, font measurement failure, presentation reinitialization, and surprising state transitions. Quantify expensive operations per event, per visible button, and per combat second: frame enumeration, weak-map growth, repeated `CreateFontString`/duration bindings, hot-path `pcall`, SetText and hook registration. Simulate 12/48/120 visible action buttons and repeated aura refresh without asserting a live FPS result. Distinguish Lua overhead from engine-side native binding load; identify what cannot be measured offline.

**Phase 5 — Findings triage and stopping rules (30–60 min).** Review each candidate against concrete source guards and tests. Group duplicate symptoms by root cause. Provide severity-ranked report and a separate list of *unverified hypotheses / live-client checks*. For remaining time, deepen the top 2–3 findings with counterexamples. The final answer should include commands actually run, results, number of source files examined, and proof that `git status --porcelain` is unchanged. No patches.

## Preserved user requirements (not optional)

- Default Blizzard fonts and original icon artwork. Timers visually centered and non-jerking; recent fixed-digit layouts are still **experimental in the live client**, especially the `.309` cast-bar spacing change.
- No new timer numbers for GCD-only action-bar swipes; real cooldown numbers remain. No new user-facing slash commands or settings.
- No change to action-bar binds, Edit Mode layout, user frame coordinates, class-colour choices, Soft Dark styling, buff priorities or unrelated addon modules.
- No loop or heavy callback that risks combat stutter. Native cooldown formatters may themselves have performance costs; inspect rather than assume zero cost.
- `RestrictedAuraAPI` target/focus auras remain native and unstyled. Do not derive protected spell/aura identity from forbidden views.

## Known reports that are not automatically fixed

- Native buff/debuff borders sometimes disappear; sub-10-second timers have shown whole seconds on certain auras in earlier builds. Offline tests are not live proof.
- `.293–.296` timer typography attempts caused or strongly correlated with combat stutter. `.301` displayed overlapping characters; `.303` introduced mutually exclusive native digit presentations; `.304–.306` added spacing and whole-/three-digit layouts; `.307` added buff-anchor and cast digits; `.308` suppressed GCD-only numbers; `.309` tightened cast-bar spacing. **These transitions need fault-injection and visual scrutiny.**
- `.309` has not been signed off as visually final or combat-profiling-safe. The exact GitHub `main` branch still hosts `.286`.
- Some old tests in `tests/` were written for past module revisions and should not be treated as green/representative for `.309` without explicit reconciliation.

## Tools and sources

- Primary evidence is the checked-in Lua source, original snapshot fixtures in `tests/snapshot-0.2.309/`, and a clean local reproduction.
- `python3 tools/audit/check_frozen_source.py` asserts all production files are byte-identical to the supplied `.309` ZIP.
- `bash tools/audit/run_snapshot_tests.sh` runs the original .309 tests with Lua 5.4. No mocks are proofs of protected-client legality.
- Original source/provenance is in `docs/AUDIT_BASELINE.md`; historical decisions in `ARCHITECTURE.md` and `KNOWN_ISSUES.md`.
- Review the installed client/API docs where available (e.g. the `forever` code mirror at `Gethe/wow-ui-source`). Mirrors can lag the actual Forever client; when implementation is not visible, label assumptions.

**Conclude with a read-only bug report, not a diff.** If the user later requests fixes, propose a separate approval step, narrow branch and regression-based change plan.
