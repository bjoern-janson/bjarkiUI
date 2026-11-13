# Native action formatting and buff seconds — .360 repair plan

Status: implemented and locally verified; see the [final evidence and live limits](VERIFICATION_0.2.360.md). This is an authorized timer repair, not a new user-facing setting. A later source check identified the smaller in-place buff route below; the separate [buff-row proposal](NATIVE_BUFF_ROW_REPLACEMENT_PROPOSAL.md) is not implemented by this plan.

## Evidence and decision

The capture supplied after .359 delivery still reports `actions cells=0 stock=13 idle=84`, eleven minimum-decision fallbacks, two named `gate-unsupported/scalar-threshold` samples and one `style-unavailable/text-color` sample. All four action formatter profiles are plain. The ordinary short buff reads `6 s`; the aura path reports `native=0 fallback=3 last=aura ID secret readable-writes=0`. The screenshot does not show bjarkiUI's version line.

The six-cell action replacement depends on reproducing native eligibility and copying native appearance. The latest evidence reaches two more unsupported parts of that reconstruction. The curve API does not guarantee that adjacent floating-point Step breakpoints preserve the exact threshold behavior assumed by the fixture. Another epsilon adjustment would not establish a sound contract.

Keep the physical native cooldown and its countdown label as the preferred action presenter. Give its native numeric formatter guarded, fixed-spacing strings only after public complete-string geometry validation. The native widget continues to own the clock, minimum/GCD eligibility, visibility, font, color, shadow and action assignment. Do not read its current protected countdown text or RGBA to prepare that formatter.

The earlier “naturally tabular” classification measures advances inside a repeated sentinel string. Returning the unchanged formatter from that classification does not establish fixed numeral positions in a standalone centered countdown. The new acceptance test must inspect complete sample strings and individual character rectangles. Character-selection rectangles are not a documented optical-ink measurement; in-client appearance remains a distinct acceptance limit.

## Implementation boundaries

1. **ActionTimerSpacing.lua:** prepare a separate bounded action-formatter profile. Preserve the current font, size, flags, effective scale and text scale. Surround every action numeral with transparent texture spacing, including the previous identity/plain path. Validate complete public samples with native `CalculateScreenAreaFromCharacterSpan`, their widths and widget fit. Keep spelling, decimals, existing units and thresholds. Missing, restricted, inconsistent or clipped geometry returns the native base formatter. Do not change the individual glyph map used by existing buff/cell paths.
2. **CooldownSeconds.lua:** install the requested formatter, require an accepted setter and exact public getter identity, and tell the digit presenter whether this physical widget has a verified native formatter. Ignored, refused or unreadable writes cannot earn that receipt. A changed style cannot silently reuse stale geometry.
3. **NativeDigitCells.lua:** retire only this addon's owned cell/hidden-number state after a confirmed native handoff. Existing hooks, safe retries and preference changes must not reacquire cells on a widget with a current native preference. Preserve later visibility writers and a pending restoration after refusal. Retain the older cell path only as compatibility fallback when native formatting was not accepted.
4. **Diagnostics:** report configured native formatter receipts and pending native handoffs separately from cell/stock/idle counts. A configured receipt is neither an active-cooldown count nor proof of live rendering. Diagnostics reuse cached public state.

Preparation uses a shared public sample probe and bounded profile caches at the existing safe typography epochs. There is no new per-button widget, event frame, polling loop, timing estimate, font substitution, setting or runtime module. Per-tick font measurements and formatter construction are prohibited. The historical .356 measurements do not establish this build's client CPU or memory cost.

## Verification tied to the failure

The formatter fixture must distinguish advance width, side bearings, whole-line centering, pair kerning, inline texture placement and pixel rounding. First reproduce a font classified as tabular while its standalone numeral/decimal positions move. Then assert the new complete-string positions, not merely the presence of markup or a cached formatter flag. Refused and unavailable native geometry must remain non-fixed.

The integration fixture must cover accepted-and-read-back installation, a void ignored setter, a refused setter that nevertheless applied, inaccessible getter results, later formatter replacement, physical cooldown replacement, visibility ownership, pending cell shutdown/restoration, native Clear, minimum changes and countdown preference transitions. No accepted native path should require source text-color reads or custom minimum-gate preparation.

After independent review, run the existing full package gate on native Lua 5.1 and 5.4, compile all manifest modules and fixtures, verify exact archive membership/bytes, and record source hashes. Publish an isolated stacked draft and deliver the installable test ZIP. Keep the action movement and missing secret-ID buff decimals open until witnessed in the client; do not label passing models a live fix.

## Additional in-place buff route

A final check of native `SecondsToTimeAbbrev` found a supported, narrower option before changing the rows. Its seconds branch returns the original seconds unchanged, while the minute/hour/day branches return converted values. The existing `FontString:SetFormattedText` sink accepts opaque arguments. If the native call's format selector is positively public and exactly `SECOND_ONELETTER_ABBR`, the addon can forward original opaque seconds to a prepared localized one-decimal format without an aura ID lookup or secret arithmetic.

This does not provide a below-ten-only decision: the native seconds branch covers values below 90 seconds. The deliberate precision tradeoff is tenths across that full band on this restricted path, with longer units unchanged. The user-facing progress update disclosed this difference. Current icons, typeface, positions, ordering, enchants, private anchors and Edit Mode remain intact; no replacement rows are needed.

`BuffPresentation.lua` will observe only the exact ordinary duration label's native formatted/plain text writers. Retain a public writer serial/selector receipt, never the numeric payload. Consume the receipt in the actual button's existing `afterDuration` callback, validate current physical label/parent/owner and native duration visibility, and forward that call's opaque seconds unchanged. Own-write guards prevent recursion; a later writer, owner change or nested update supersedes the receipt. Public short-duration cells retain their established route. Secret/ambiguous selectors and refused sinks remain native.

The existing actual-module aura fixture must reproduce opaque seconds failing before the change, then cover accepted seconds, unchanged longer units, secret selectors, disabled durations/examples, replaced/reused labels, refusals and reentrant newer writers. Diagnostics may count accepted sink calls and public failure stages, but cannot claim native readback or rendered success. This adds one supported cosmetic write to eligible existing native refreshes; measure its live cost separately from offline call counts.
