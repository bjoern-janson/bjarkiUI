# Action width validation repair

The user reports that .360 buff decimals now look good, while action numerals still move. Their capture shows all four action formatter profiles unavailable at `character-areas`, zero configured native formatters, and four naturally tabular individual-glyph profiles. The screenshot does not identify which native character-area prerequisite failed.

## Decision

Keep the original native cooldown and .360 formatter/handoff architecture. Add a narrowly scoped alternative when the public sample character-area query is unavailable: naturally tabular fonts may use constant positive integer texture guards after independent native whole-line, prefix and suffix width validation. This route must reject unequal advances, ineffective guards, changed height, clipping, inconsistent columns and unavailable public widths. It must not silently accept a contradictory valid character-area result.

This is an implementation decision within the requested repair. Alternative one was changing probe alpha or waiting for a rendered frame; neither is established as the live cause, and asynchronous sample layout adds lifecycle complexity. Alternative two was a general proportional-font width approximation; scalar width rounding makes its fractional padding uncertain. The selected natural-font route addresses the font class actually reported and preserves the existing character-area route for other fonts.

All measurements use addon-owned public sample strings outside combat. Keep the current fonts, native clock, color, visibility, minimum/GCD rules, thresholds, saved settings and existing buff code. No extra ticker, event frame, per-button label or dependency. Successful public measurements are evidence of compatibility at the native metric resolution, not a promise about optical ink bounds or the live renderer.

## Acceptance

The actual formatter must produce stationary modeled digit and punctuation positions with absent character-area results and a naturally tabular font. Test complete decimal, integer and unit strings; rounding, kerning and optical side bearings remain separate model dimensions. Verify graceful rejection for proportional or inconsistent widths, refused native methods, and a changed line height. Stable calls must use the cache without measurements. Preserve exact numeric spelling and thresholds, native formatter ownership and the .360 buff implementation byte for byte.
