# Codex findings report template (answer in chat; do not modify files)

## Summary

- Checked branch + commit SHA:
- Source freeze check:
- Matched Lua regression result:
- Tracked checkout cleanliness (`git status --porcelain`, before/after):
- Number of confirmed defects / unverified risks:
- Areas read and APIs verified:

## Confirmed findings (descending severity)

### [P1/P2/P3] Short, precise failure title

**Evidence:** `filename.lua:line-range` and exact code path.
**Trigger:** smallest state sequence needed; user-observable impact.
**Expected / actual:** explicitly distinguish.
**Reproducer:** exact test command or scratch scenario **outside the checkout**.
**Why existing tests did not catch it:** the missing invariant, mock limitation or fixture mismatch.
**Proposed smallest fix:** source-level outline ONLY; include failure/taint/performance risks.
**Regression to add after approval:** exact assertion or simulated sequence.
**Counter-check:** what would falsify this finding.

## Hypotheses requiring live verification

For each: symptom, API uncertainty, observation needed, whether a visual screenshot or protected-action error is decisive. Do not label a hypothesis as a confirmed bug.

## No-change attestation

- All commands with side effects (if any) were limited to files outside the checkout.
- No source, manifest, test, documentation, workflow, setting, branch or commit was modified.
- Any follow-up proposed work requires explicit user authorization.
