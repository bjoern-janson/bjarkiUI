# .371 decimal timer consistency

## Result and scope

This build aligns supported bjarkiUI action, buff and player-cast decimal
presentation while preserving each native font role and size. It repairs
source-confirmed spacing, rounding and cast-style defects. It does not establish
suite-wide visual identity or close the existing live rendering and microstutter
reports.

Baseline .370: local commit `8fa3b4e9c896ec7f8c592d04fa51e7e2197204d8`,
remote commit `28a70ad569fd47d05d4e4eb69c7ad5f558ed61d2`, matching tree
`6c1e77d1344f84f78824cd8e1f2152baac9787af`.
Runtime behavior changes in four modules: ActionTimerSpacing, CooldownSeconds,
NativeDigitCells and CastBarDigits. The main version literal and two manifests
receive matching metadata. The .370 combat-aware level badges remain included.
[Payload hashes](SOURCE_SHA256_0.2.371.txt).

## Confirmed differences and repairs

| Surface | Source finding | .371 behavior |
| --- | --- | --- |
| Native actions versus buffs | Per-digit action guards added space around the point, while the proven whole-buff format used outside guards | Actions reuse the same compact profile where the font supports it, with complete action validation retained |
| Action boundary | Sub-ten raw printf could produce `10.0` while compatibility cells and buffs capped at `9.9` | Native nearest-tenth formatting with a 9.9 maximum; whole seconds still begin at ten and minutes at 91 |
| Compatibility cells | Padded box measurements left an extra 0.05-unit spacing allowance | Raw advances feed a shared symmetric geometry helper; box padding remains separate |
| Player cast carry | Integer cells used raw thresholds while the fractional cell rounded independently | Every digit derives from one native rounded tenth |
| Player cast typography | One-time font copy, separate asymmetric geometry, missing scale/smooth inheritance | Current native style and scales refresh safely; decimal centers use the common helper |
| Cast template/range | Empty suffixes were rejected; all fixed tracks became blank at 100 | Suffix-free/localized one-decimal templates work; a full-format native overflow track handles three or more integer digits |

The saved .370 cast fixture reproduced `0.96 -> 0.0 s`, `1.96 -> 1.0 s`,
`9.96 -> 9.0 s`, and `19.96 -> 19.0 s`. The repaired fixture produces `1.0 s`,
`2.0 s`, `10.0 s`, and `20.0 s` respectively. The baseline also retained
FRIZ/16/OUTLINE cells after its native label changed to ARIAL/20/MONOCHROME.
Those are controlled fixture values, not observations of the user's client.

With modeled native numeral advance 7.25 and point advance 2.5, action decimal
centers previously occupied -5.875 / 0 / +5.875, while the compact buff proof
used -4.875 / 0 / +4.875. The new same-profile fixture checks identical action
and buff strings and columns for all 100 tenths through both native character
and width qualification routes. This establishes modeled metric agreement,
not exact live glyph ink. Proportional/kerning-rejected profiles retain the
existing guarded action fallback.

## Rounding and native ownership

Supported actions and casts now explicitly use the native numeric rule engine's
nearest-tenth policy, matching genuine-duration buffs. Exact midpoint behavior
comes from that native rule, not raw printf's separate tie handling. The fixture
models nearest rounding with quarter-tie vectors such as `1.25 -> 1.3`.
Cast punctuation, suffix and one-decimal precision still come from the native
`CAST_BAR_CAST_TIME` template. Unsupported precision such as `%.2f` stays stock.

The [pinned Forever cast implementation](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_UIPanels_Game/Shared/CastingBarFrame.lua)
continues maintaining the original CastTimeText. The addon never clears that
source text and never reads the opaque duration's remaining time. Native
duration objects feed native text bindings at the existing 0.1-second cadence.

Public calibration requires coherent complete output, at most one digit in
each numeral cell, and mutually exclusive one-digit, two-digit and overflow
tracks. A modeled mismatch between input and threshold scalar precision is
rejected when it would put `10` into a single-numeral cell, even if concatenated
output looks correct.

## Lifecycle and cost

Cast preparation, activation and cleanup use bounded busy/revision receipts.
Current source identity is checked after native setters and after final style
and visibility reads. Independent reproductions caught a nested combat font
change and a source replacement from a final getter; both now retain current
native text and retire the stale receiving labels/bindings. Replacement-source
hooks install during ordinary refresh, and the bar-scale observer follows the
current source. Refused binding shutdown leaves pending cleanup and hidden
receiving labels; safe preparation waits for cleanup.

Required current font/style/scale methods must be public. Text scale is applied
once to raw measurements. An explicit scale fixture checks equal decimal gaps
of 9.375 label units / 28.125 screen units at native size 20, text scale 1.25,
and effective scale 3. Native binding ticks perform no glyph measurements or
geometry/style writes in the fixture.

There is no new Lua ticker, polling clock, runtime module or option. Action and
buff proof reuse stays bounded and cached. Casts reuse their probe, labels and
bindings; the overflow track adds one native binding, taking the player cast
presenter from nine to ten. Compact proof can incur a first-use preparation
cost even for a suffix-only action source; the shared cache bounds it, and no
timer tick performs that calibration. These facts do not quantify in-client
CPU, garbage collection or frame pacing. The existing ultralight description
remains a presentation-architecture description, not an FPS guarantee.

## Executed verification

- All **38 top-level scripts** pass under native **Lua 5.1 and Lua 5.4**.
  All **16 runtime modules** compile through native loadfile. Both manifests
  agree on version/order; prohibited Edit Mode writer checks pass.
- Focused counts on both interpreters: **1,726 cast assertions**, **6,529
  digit-cell assertions**, **139 action-format assertions**, and **271 aura
  cases**. The action-geometry suite passes both character-area and scalar
  qualification, compact-profile reuse, rejected kerning/proportional fallback,
  current label fit, near-ten values and exact midpoint cases.
- An independent reviewer reproduced both cast ownership defects before their
  fixes and confirmed native visibility plus stopped/hidden stale presenters
  afterward. Final review found no remaining Critical or Important issues.
- Whitespace verification passes. The full package gate reran after the final
  post-getter ownership correction.

## Package

`bjarkiUI-0.2.371-Consistent-Decimals.zip` contains **19 files**: 16 runtime Lua
modules, matching manifests and the existing spacer texture. ZIP integrity,
membership and exact source-byte equality pass. Twelve payloads are byte-identical
to .370; the four changed behavior modules and three version-bearing files
account for the other seven. Tests, docs, research and user settings are excluded.

- ZIP bytes: **150,405**
- Expanded bytes: **606,298**
- SHA-256: `5ba03201deaeaca719c2d562e35f965f23aea5d9942f62a492d4d70e80cf0535`

## Remaining visual boundaries

Unsupported opaque buffs retain native text and can still show whole seconds
or a seconds suffix below ten. The native below-90 selector alone cannot
authorize a below-ten precision rule. Public positive buff time still floors
at 0.1, while genuine-duration output can reach 0.0 before expiry. Tracked-buff
widgets keep their existing native formatting route.

The authoritative Portraits .269 package still uses separate fixed-cell and
native-secondary presentation and can show `10.0` just below ten. Its timer
files were verified byte-identical to the .266 audit checkpoint. CC 0.4.17.51
uses separate whole-string timers with tenths below five. Neither addon is
rewritten here. Live optical appearance, protected-client behavior and
performance remain unverified for .371; see [known issues](../KNOWN_ISSUES.md).
