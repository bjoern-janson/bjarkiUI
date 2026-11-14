# Target refresh allocation cleanup

## Intent

The user still observes microstutters when selecting their own character after
.366 and declines a manual tracing workflow. Continue the authorized performance
work locally and deliver a regular addon ZIP. The live hitch remains unresolved;
source and fixture improvements must not be reported as an in-client fix.

## Evidence and chosen approach

The settled target path creates short-lived closures for protected member reads
in the main module, FrameLabelTweaks and IconSkin. FrameLabelTweaks also creates
observer closures before discovering that their hooks are already installed.
These allocations are reproducible without changing targets' class availability.

Replace only those capturing reads with shared parameterized readers, keeping
the exact expressions inside their original protected boundary. Construct label
observer callbacks only when their current hook is not installed. Continue all
existing discovery, permission checks, native calls and retries.

This is the implementer's narrow choice under the existing authorization. A
self-first class-alias shortcut was considered and rejected because it changes
witness priority. Skipping discovery or repeated native decoration writes was
also rejected because current recovery and ownership checks still require them.
No further diagnostic task is assigned to the user.

## Constraints

- Keep all existing unit/class alias ordering and physical-recipient checks.
- Keep current protected-call boundaries, read order, secrecy checks and results.
- Keep native frame writes, geometry, fonts, timers, settings and artwork.
- Preserve hook refusal/retry, reentry guards and late-created/replaced objects.
- Add no runtime sampling, polling, cached frame identities or new options.
- Verify native calls and visible fixture state against the exact .366 source;
  report allocation reductions separately from client CPU or frame pacing.

## Verification and delivery

Use before/after full-source probes with stopped garbage collection to compare
bounded heap growth, plus ordered native-call and visible-state comparisons.
Baseline versus itself must fail the improvement assertion before edits. Run
the existing native Lua 5.1/5.4 regression gate and exact package checks. Record
the work in a stacked draft branch and deliver .367 as a regular addon ZIP.
