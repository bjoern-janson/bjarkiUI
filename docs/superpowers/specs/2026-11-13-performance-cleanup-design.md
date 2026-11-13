# .356 presentation performance cleanup

## Intent and authorization

The user approved the focused cleanup recommended by the .355 performance parse: reduce temporary timer lookup allocations, reduce redundant NPC nameplate/color discovery, then evaluate repeated safe-setup work. This is a performance patch with the existing presentation and permission contracts preserved.

Baseline: local commit `7d416dcdf296e2029c83bbf872fb2211cbbabf28`, matching upstream .355 tree `bd5fe1ba705fcd999ba3dd55afdf0d87ed4b0852` / commit `6b3090e7196c820b574fe9f86f22b296657ec97f`.

## Approach

Use shared protected member readers in `NativeDigitCells.m/field` instead of constructing a capturing function per lookup. The existing public-value checks, `pcall` boundary, result filtering, and physical-owner checks remain authoritative.

For NPC colors, stop after the first readable native health-color witness, preserving the existing witness order and fallback. A native nameplate-color hook may supply its current frame/token as a hint; use direct native lookup only after positively validating its current physical association and unit identity. A refused, missing, secret, forbidden, changed or mismatched hint returns to current native discovery. Do not retain a plate, unit identity or RGB across callbacks to avoid scans.

Evaluate safe-setup allocation reuse separately. Hoisting constant hook-name lists or retaining an identical typography receipt can reduce work while leaving every getter, retry epoch and recovery path intact. Skipping whole combat-exit discovery without a reliable invalidation contract would risk late-created/replaced artwork and is outside this patch.

The selected approach removes reproduced redundant work. Broad cache-based discovery suppression and presentation/feature removal were rejected because they would change current recovery or visual behavior.

## Contracts

- Preserve native fonts, fixed digit positions, clocks, countdown preferences, action 10/91-second boundaries and distinct native buff formats.
- Preserve restricted/opaque values, current recipients, ownership generations, failed-setter recovery and re-entrant updates.
- Preserve the approved large/classic-party crown positions, hidden rested Z texture and party faction badges, native icon artwork, class/status appearance and user Edit Mode layouts.
- Add no polling, options, dependency, new runtime module or diagnostic chore.
- Keep the exact existing TOC description: `Ultralight unit-frame presentation for WoW: Forever`.

## Evidence and delivery

Use existing timer regressions and the audited real-source benchmark to check the protected-reader refactor. Add consumer-level health regressions for direct-witness ordering, verified hint reuse and invalidated/recycled hints. Compare .355 and .356 with the same native-boundary model; operation counts and GC-stopped heap growth are offline evidence, not live FPS or in-game memory.

Deliver a normal .356 addon ZIP after native Lua 5.1/5.4 verification, package byte checks and independent code review. Publish source to a stacked draft PR without merging. Document the narrowed changes and remaining live limits.
