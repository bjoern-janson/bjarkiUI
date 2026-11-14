# Reduce avoidable lifecycle work in .366

## Intent and evidence

The user reported bjarkiPerf's first recording: 22 bjarkiUI profiler ticks over 5 ms, 11 rendered frames at least 25 ms, four at least 50 ms, and a 69 ms worst frame. This authorizes investigating and reducing unnecessary work while preserving the current presentation. It does not establish a particular function as the live hitch cause.

Read-only fixtures against .365 identified three bounded opportunities:

- Twenty settled classic nameplates receive 40 repeated LEFT-anchor writes per combat exit. Nonclassic nameplates still schedule one repair callback each, although repair immediately returns.
- One full SoftDark discovery with 116 action slots, a nested bag and seven sibling art frames executes 851 capturing member-reader closures and 365 capturing object-type closures. Full discovery is necessary to recover silently replaced or late-created artwork.
- Buff seconds geometry still validates 901 decimal strings from 0.0 through 90.0. Following .363, its only production consumer emits guarded decimals at most 9.9. Both public values and native duration rules clamp the short family; 10 seconds and above retain native unit formatting.

## Chosen approach and alternatives

The implementation choice is to remove these demonstrably unused operations, preserve all existing recovery events, and measure exact work-count differences in repeatable fixtures. This is the assistant's implementation choice under the user's existing authorization, not a new user-selected design.

Gating all combat-exit discovery on a pending flag was rejected: native artwork can change without an observed hook. Suppressing failed timer retries was rejected: the existing safe epochs recover transient native capability failures, and many live fallback stages can be cheap. A new permanent profiler or a broad event-queue rewrite is unnecessary for this first bounded patch; bjarkiPerf already supports matched before/after recordings.

## Contracts

- Keep native timer clocks, the below-ten decimal boundary, source secrecy and formatter validation. Validate every emitted short decimal, including 0.0 and 9.9, on character and scalar routes; retain failure/retry, cache, height, width and fit checks.
- Skip a nameplate LEFT write only after observing the exact current public anchor and physical edge. Unavailable geometry retains the existing write/retry route. Do not clear or add other anchors. Recheck current physical associations and permissions after introduced getters. Preserve native resets, replacements, reentry, scheduling refusal and confirmed-unprotected combat behavior.
- Gate nonclassic scheduling without losing existing mixin/instance hooks or style-change recovery. Keep the existing per-frame pending queue and callback order.
- Shared SoftDark readers preserve each protected lookup/call, false/nil behavior, order, and pre/post secrecy checks. No persistent discovery cache.
- No new OnUpdate, ticker, dependencies, saved settings, options or UI widgets. Current level badges, side-centered levels and secondary portraits retain .365 behavior.

## Delivery and limits

Use .366 as an installable test build, with a reproducible source report, both native Lua interpreters, the normal package gate, and a stacked draft PR. Distinguish operation/allocation counts from native CPU or frame-time results. Keep live microstutters and the existing timer coverage limitations open until a matched in-client recording is available.
