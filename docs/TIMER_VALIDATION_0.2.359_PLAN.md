# 0.2.359 native timer validation

## Evidence and corrected premise

The latest user capture after delivery of .358 still shows zero active action cell presenters, 13 stock fallbacks, 11 minimum-decision fallbacks and a named `gate-unsupported/probe-alpha` sample. Two other samples report `style-unavailable`. The short buff in the image still displays `6 s`; the latest aura fallback remains `aura ID secret`.

`probe-alpha` runs only after public synthetic clock mapping succeeds and before scalar/color gate construction. It requires `SetAlpha(.25)` to read back as the exact Lua number `.25`, then restores alpha one. Native API documentation declares a `SingleColorValue` result and no exact fractional-round-trip contract. The actual minimum scalar emits only zero and one. Therefore the quarter-alpha precondition is unrelated to the capability the presenter consumes. Existing test doubles preserve alpha doubles exactly and do not expose that mismatch.

The screenshot does not distinguish a refused write, unavailable read, fractional conversion or refused restoration. Do not claim a measured client quantizer. Byte-floor and nearest-byte models are counterexamples to the unnecessary requirement, not measurements of this client.

## Bounded changes

1. Reproduce rejected activation under modeled fractional alpha storage against the unchanged parent. Validate both actual zero/one endpoints using accepted setters and protected, positively public numeric readbacks. Retain fallback for refusal, missing/secret/wrong endpoint results. Preserve all minimum, equality, rate, color and native-clock policies.
2. Replace the ambiguous style failure receipt with fixed public property stages, using only reads already performed. Keep the current style acceptance and stock restoration behavior. No guessed native color, cached style substitution, or additional retry is authorized by this evidence.
3. Review independently, then run the ordinary native Lua 5.1/5.4 package gate once against the final runtime and tests. Keep archive/source identity and live limits explicit.

## Architectural assessment and unresolved scope

The native action countdown formatter already exists in this addon; no native per-digit column control was found. The six bindings remain the existing route to independently anchored glyphs. The current change corrects its validation precondition and does not establish client rendering success.

The legacy buff FontString has neither an exposed native duration binding nor a supported duration-by-slot lookup. Existing public factories do not grant access to secret aura identity/timing. The custom native helpful-row alternative still lacks the required private-aura exclusion and complete legacy enchant/layout equivalence; see [the source-grounded design](NATIVE_BUFF_ROW_DESIGN.md). No compatible in-place buff decimal repair was established. Do not label buffs fixed or ship a speculative row replacement.
