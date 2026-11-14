# Combat Level Highlights Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for inline implementation; delegate the independent fixture and final review.

**Goal:** Keep Player plain and make Target/Focus level outlines follow each unit's own combat state.

**Architecture:** Extend the existing FrameLabelTweaks owner with two optional highlight textures. Feed current unit combat and native numeric visibility through supported alpha sinks, refreshed by filtered unit events and existing native observers.

**Tech Stack:** WoW: Forever Lua, native regions and events; native Lua 5.1/5.4 fixtures.

**Spec:** ../specs/2026-11-14-combat-level-highlights-design.md

## Global Constraints

Five reusable textures maximum; no polling or player-combat substitution. Geometry only outside combat. No inspection or retention of opaque combat/derived-alpha values. Preserve existing text, lower circles, skulls and timer behavior.

## Review Focus

Independent target/focus state; target switches during combat; opaque numeric visibility combined with combat; refused native reads/writes; a newer target update superseding an older query. All are assigned to the focused badge fixture below.

## Task 1: Combat-aware badge owner

- [x] Adapt tests/frame-level-badges.lua to five textures and record baseline failures for independent combat state, switches, opaque composition, refusal and reentry.
- [x] Extend FrameLabelTweaks.lua with separately prepared highlight artwork and syncLevelHighlight, preserving the usable base on highlight failure.
- [x] Add filtered UNIT_FLAGS observation and immediate target/focus visibility refresh during combat; increment writer revisions before querying current unit state.
- [x] Run the focused fixture in native Lua 5.1/5.4 and resolve concrete failures.

## Task 2: Verify and deliver

- [x] Obtain a fresh independent runtime/source review; resolve concrete findings.
- [x] Update version/current docs and source hashes, run the complete existing verification gate and source-matched installable ZIP checks.
- [x] Commit and preserve a stacked draft PR; deliver the .370 ZIP with clear behavior and offline/live evidence limits.

The user has already requested execution and declined unnecessary approval/diagnostic chores. Proceed with the specified implementation and normal ZIP delivery without another approval round.
