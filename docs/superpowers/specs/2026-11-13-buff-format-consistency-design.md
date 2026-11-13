# Buff format consistency repair

The user's current observation supersedes the earlier isolated positive buff screenshot: buffs can still wiggle and intermittently show a seconds suffix. A same-label fixture reproduces public `3.7` in calibrated cells, opaque `3.6 s` on the uncalibrated native label, then public `3.5` in cells. The new seconds sink also intercepts a usable native duration object and discards its retry/cache state.

## Selected repair

1. Keep the native writer, exact current label/owner, assignment, visibility and bounded reentrant-writer transaction. Within an eligible fresh source transaction, prefer a genuine native duration object obtained with a public identity. Forward its opaque output through `SetFormattedText("%s", text)` so ordinary `SetText` remains a later writer. Recheck freshness before cache mutations and before the sink. Identify the exact write with a preallocated public token in a natively validated unused vararg; a matching format alone cannot distinguish another writer. Preserve public samples for recovery if native text is unreadable.
2. When the original opaque seconds are the only supported source, use a suffix-free one-decimal native sink. This still covers the native seconds band below 90 seconds; it cannot test an opaque value against ten. Larger native units retain their unit labels. A denied/ambiguous selector cannot authorize this fallback.
3. Prepare an optional whole-string format with constant integer transparent guards at both outside edges. Validate every public decimal output 0.0 through 90.0, complete line height/width and character positions, or independently guarded/repeated prefixes and suffixes when the initial character query is unusable. Reject proportional advances and variable internal kerning. Keep existing action formatters and individual glyph maps unchanged.
4. A valid current profile lets readable short timers and duration-object short formatting use the same guarded native label as the opaque fallback. A missing/changed profile keeps the established safe cell/plain fallback. Never substitute a font or measure on an aura tick.

## Constraints and limits

- Preserve .361 action behavior, native icons/fonts, character settings and all earlier frame presentation fixes.
- No opaque arithmetic, parsing, comparisons, identity guessing, retained opaque seconds, fabricated duration objects, global formatter changes, new polling, settings, modules or dependencies.
- Preserve public below-ten precision/clamping and native larger units. The seconds-only opaque fallback retains .360's wider precision band, now without its seconds suffix.
- Use the existing shared probe, bounded profile cache and safe retry epochs. Profile validity includes font, effective/text scale and smooth scaling.
- No accepted write or offline model establishes live taint safety, optical ink stability, performance or complete client success. Scalar validation is limited to native reported metric resolution. Keep that distinction in the release record.

## Evidence required

- Failing regressions for mixed readability, simultaneous native sources, plain suffix, guarded complete-string geometry and stale native-object cache updates.
- Existing owner-transfer, later-writer, refusal, font/layout and combat matrices remain green.
- Test both Lua 5.1 and 5.4, independently review the changed transactions, verify the 19-file ZIP against source, then deliver the installable archive.
