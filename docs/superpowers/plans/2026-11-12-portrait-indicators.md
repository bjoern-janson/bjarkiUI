# Portrait Indicators Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan. Steps use checkbox syntax for tracking.

**Goal:** Separate rested Zs and leader crowns while making the large-frame crown placements mirror correctly.

**Architecture:** Retain FrameLabelTweaks as the crown geometry owner and RestIndicatorPlacement as the native Z texture owner. ClassicPartyPresentation supplies its existing verified pooled membership to one private crown helper. No new runtime module or frame update loop.

**Tech Stack:** WoW Lua 5.1-compatible source, native Lua 5.1/5.4 fixtures, existing Python manifest/package verifier.

**Spec:** `docs/superpowers/specs/2026-11-12-portrait-indicators.md`

## Global Constraints

Use exact .349 commit `a1b5172cb1dca454187e25731b729d8218e5ed82` as baseline. Preserve original icons/animation and user-owned settings. Mirror Z position only. Inward is toward the bars. Keep changes on a development branch and deliver a regular installable ZIP.

## Review Focus

Mixed effective scales must keep symmetric screen-space crown gaps; native reanchors and refused writes must remain retryable; foreign anchors must not be reclaimed; pooled party release/reacquisition must not duplicate hooks or style inactive frames; party geometry must defer when raid/combat permission is unknown.

## Task 1: Indicator placement and release

**Files:** Modify `FrameLabelTweaks.lua`, `ClassicPartyPresentation.lua`, `RestIndicatorPlacement.lua`, their existing crown/rest fixtures, version metadata, changelog and current documentation.

**Interfaces:** `uiPrivate.InstallClassicPartyLeaderCrown(frame, memberUnit)` consumes the existing physical frame and its membership validator; it writes only `frame.PartyMemberOverlay.LeaderIcon` geometry.

- [x] Establish the pinned baseline and run its existing suites on native Lua 5.1/5.4.
- [x] Update the existing crown/rest fixtures to demonstrate mirrored crown geometry, separated resting geometry, mixed scale, native refresh/refusal behavior, and pooled-party permissions. Observe the relevant failures against .349.
- [x] Implement the narrow crown profiles, private party handoff and left-side resting placement; run focused fixtures until they pass.
- [x] Set 0.2.350 metadata and document this test build; run both complete Lua suites and package identity validation.
- [x] Obtain one independent code review, address material findings, and prepare the verified source and installable ZIP for branch/PR publication and delivery.

## .351 corrective follow-up

- [x] Inspect the two live .350 captures and compare actual secondary/crown source geometry, including bjarkiPortraits .252.
- [x] Preserve player/classic-party positions and apply a two-unit target/focus optical correction.
- [x] Replace left-side Zs with the approved right-of-crown fallback; exercise physical adjacency and safe lifecycle recovery.
- [x] Run both native Lua verification sets and independently review the correction; prepare the verified regular .351 ZIP and development-source update.

## .352 requested Z removal

- [x] Trace the native resting writer and replace relocation with exact RestTexture suppression.
- [x] Update the obsolete resting fixture; observe the initial visibility failure against .351 and pass the seven suppression/recovery cases on native Lua 5.1/5.4.
- [x] Obtain a scoped independent read-only review; no actionable findings.
- [x] Verify both full native suites and package identity; prepare the .352 source update and installable ZIP for delivery.

## .353 classic-party crown spacing

- [x] Inspect the screenshot and confirm the existing classic-party profile; apply two additional rightward UI units with no new layout mechanism.
- [x] Update existing crown expectations and observe the expected -8 versus -6 failure before changing the constant.
- [x] Verify both full native suites and package identity; prepare .353 source and installable ZIP.

## .354 remove classic-party faction badges

- [x] Identify native PartyMemberOverlay.PVPIcon and its UpdatePvPStatus/UNIT_FACTION writers.
- [x] Extend the existing party fixture; observe failure before suppression and cover refreshes, combat, pool/path reuse, permission and refusal recovery.
- [x] Implement narrow suppression in ClassicPartyPresentation and resolve independent review's combat re-show finding; 17 focused cases pass on both native interpreters.
- [x] Verify both full native suites and package identity, then prepare .354 source and regular installable ZIP.
