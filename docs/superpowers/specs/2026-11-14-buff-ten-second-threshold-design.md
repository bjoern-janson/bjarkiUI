# Strict buff decimal threshold

The latest user screenshot displays `66.2` and reaffirms the intended decimals-below-ten rule. The .360–.362 opaque seconds-only fallback deliberately applied `%.1f` throughout the native below-90-second band. That compromise does not satisfy the user's requirement and is removed.

## Selected correction

- Remove the unconditional numeric decimal sink when a remainder is opaque and no genuine native duration object can be used.
- Preserve readable public short timers, public temporary-enchant timing, genuine native duration formatters, current prepared spacing and the existing 9.9 clamp.
- Preserve the entire source/owner/assignment/retry/replay transaction. An unsupported timer must retire old cells and retain the current native display, not revive an older decimal.
- Add a precise diagnostic stage, `threshold-unavailable`, for an unsupported opaque seconds source. Do not label it a formatting success.
- Retain .362 action behavior and all unrelated presentation/settings.

## Explicit limits

A public native seconds selector establishes only the native seconds band, not `<10`. The inspected native APIs do not accept an opaque scalar into a NumericRuleFormatter binding from addon code. A new cooldown widget does not remove that permission restriction. Do not guess timing, use appearance as a hidden-data signal, fabricate a duration object, add a clock/ticker, or use general-number formatting that changes precision/rounding and reintroduces moving columns.

Without readable time or a usable genuine object, the native whole-second display remains at all durations, including below ten. This correction closes the over-ten decimal defect; it does not claim universal decimal or spacing coverage. A separate public-expiration path is not needed for this focused correction and is not added.

## Required evidence

Verify public/object/unsupported sources at 9.999, 10, 66.2 and 90. Keep short-path writer, refusal, retry, physical transfer and reentry tests active by moving former opaque-fallback sink exercises to supported sources. Cover an older supported sink finishing after a newer unsupported 66.2 update, in both orders. Native source stays `66 s` and there is no addon decimal sink call for unsupported opaque input.
