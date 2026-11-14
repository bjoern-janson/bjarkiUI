# Decimal timer consistency — .371

## Goal and scope

Make supported bjarkiUI decimal timers use compact, symmetric numeral/point spacing while retaining each native font role, size, localized cast template, clock and ownership contract. The user's visual report is supported by source differences; no new live screenshot establishes which renderer is currently active on every element.

The existing authorization covers implementation and a reviewable ZIP. This change is stacked on .370; main is not merged. Portraits and CC are inspected for context but have separate current source and release ownership.

## Evidence

- Action native short strings guard each numeral independently; the already validated buff short format guards the whole number. For identical modeled advances, these differ by one guard unit on either side of the decimal point.
- Action sub-ten formatting can round to `10.0`; supported buff paths cap that band at `9.9`.
- Action/buff compatibility cells include box padding in their spacing, leaving an unnecessary 0.05-unit addition. Cast cells use a separate asymmetric arrangement.
- Cast integer cells select raw integer breakpoints while tenths round independently. The existing fixture reproduces `1.96` becoming `1.0 s` instead of `2.0 s`.
- Cast fonts are copied once, text/relative/smooth scaling is absent, and valid empty native suffixes are rejected.

## Implementation

1. Reuse the independently proved buff compact decimal format for native action short strings when the same native profile supports it. Retain complete action validation and per-digit guards for unsupported compact profiles and other format families. Keep bounded caches and safe retry epochs.
2. Use the native nearest-tenth rule for action decimals and cap that band at `9.9`; keep whole seconds below 91 and existing minute/hour/day behavior. The same native nearest-tenth rule already drives genuine-duration buffs and now drives coherent cast digits. Exact quarter ties are deliberate (`1.25` becomes `1.3` under the documented nearest model), rather than claiming identity with raw printf's midpoint rounding.
3. Share one pure decimal-step calculation through `NativeDigitCells.GetDecimalCellStep`. Pass native advances without box padding, apply text scale once, preserve the existing conservative size ceiling. Use symmetric centers in action/buff compatibility and cast cells.
4. Repair cast carry using a coherent native rounding rule, validating every digit against the full native rounded-template formatter on public samples including exact quarter ties. Preserve the localized template, not the independent raw-printf tie policy. Refresh current font/style and scale safely; preserve empty/localized suffixes. Keep original native text maintained, with restoration before binding cleanup. A native full-format overflow track prevents a blank above the two-digit range.
5. Preserve unsupported opaque buff fallback. The native seconds selector proves only a below-90 band and cannot authorize a below-ten decimal rule.

## Verification and delivery

Focused regressions must exercise displayed text/columns, not only internal receipts: same-profile action/buff spacing; guard and kerning refusals; values immediately around ten; cast integer carry and range handoffs; style/scale refresh; no combat geometry; refusal and restoration; no timer-tick metric work. Run both native Lua 5.1 and 5.4 and the complete current package gate. Independently review the runtime diff, verify ZIP bytes against source, retain the live rendering/performance limitations, and deliver a new .371 installable ZIP and stacked draft PR.
