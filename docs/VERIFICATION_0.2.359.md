# Verification and live evidence for 0.2.359

Date: 2026-11-13. Build: **0.2.359-native-timer-validation-test**.

## Result and limits

This build removes an unnecessary exact fractional-alpha requirement from the fixed action renderer's calibration and verifies the zero/one endpoints that its scalar gate actually consumes. It also identifies which native style property prevented resynchronization, without changing style acceptance or fallback behavior. Independent review found no material issue, and the full local package gate passes on both native Lua interpreters.

The latest client capture still demonstrates failed action rendering and missing buff decimals. It is not a successful result for the earlier build. The new correction is supported by source analysis and explicit counterexample fixtures; it has not been observed in-game. The capture does not establish the actual client alpha quantizer. Separate unavailable-style cases and secret-ID buff decimals remain open.

Baseline: .358 local commit `2f3a007fb7311ae2c3dcbee4fa685df26f73e1f8`, remote commit `070c2eb3f2f3bd426272f6a359dce6b64424158d`, identical tree `003abc1fab09d5bf0fb3f9d9e33c18a58dae8358`. Runtime behavior changes are confined to `NativeDigitCells.lua`; main and the two manifests receive the version update. There are still 16 runtime modules.

## Latest live evidence

The user's capture after delivery of .358 contains:

```text
aura native=0 fallback=4 last=aura ID secret readable-writes=2417
visibility-restricted=0 retries=0 hooked=48/48 retry-pending=0
fallback-buttons=4 private=6 inaccessible=0
actions cells=0 stock=13 idle=84 minimum-read-denied=11 below/equal-minimum=0
[ActionButton11:style-unavailable,
 ActionButton3:gate-unsupported/probe-alpha,
 MultiBarRightButton10:style-unavailable]
cast=native-bindings state=stock setting=on
glyphs=fixed:0/plain:4/unavailable:0 last=plain
formats=fixed:0/plain:4/unavailable:0 last=plain
```

The short ordinary buff visibly reads `6 s`. The screenshot does not include the bjarkiUI version line; the unrelated bjarkiCC startup version is not treated as bjarkiUI's version. The counters describe cached prepared presenters, not a fresh enumeration of every live cooldown. The 84 idle states are not 84 failures, and the latest aura fallback cannot be assigned to every pictured buff individually.

No fixed action presenter is active in the report. The minimum-decision category has 11 recorded fallbacks; the named sample specifically reaches `probe-alpha`. That stage occurs only after synthetic native duration mappings have succeeded and before scalar/color gate creation. It therefore does not identify a curve interpolation, threshold, seconds/milliseconds, or rate-mapping failure.

## Incorrect validation requirement

The previous alpha probe attempted `SetAlpha(.25)`, required `GetAlpha()==.25`, and then attempted `SetAlpha(1)`. Any write refusal, read failure, restricted read, nonexact intermediate result or restoration refusal produced the same stage.

The pinned Forever [region API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua) declares `SingleColorValue` input/output and secret aspects. It provides no exact fractional-round-trip guarantee. The renderer's Step scalar curve, however, emits only zero and one. Fractional precision is not a capability the renderer consumes.

The old fixture silently guaranteed exact fractional behavior by assigning the requested Lua number directly to the mock label. Two counterexample models, floor-byte and nearest-byte alpha storage, preserve both required endpoints while failing the quarter-alpha requirement. Both models reject activation with the exact previous `gate-unsupported/probe-alpha` stage on both native Lua engines. These four red controls establish the overconstraint; they do not measure this client's storage or prove that rounding was its exact failed operation.

The correction validates each required endpoint separately:

1. The zero write must be accepted, and a protected read must return a positively public number exactly equal to zero.
2. The one write must be accepted, and a protected read must return a positively public number exactly equal to one.

Failures name `probe-alpha-zero` or `probe-alpha-one`. No epsilon or relaxed numerical threshold is introduced. Native duration mapping, minimum equality, the BaseTime/RealTime conjunction, color gating, cache capacity, retry epochs and stock ownership remain unchanged. Live opaque duration results are still forwarded untouched to their supported sink.

## Regression evidence

The existing actual-module fixture now checks both fractional storage models and 14 endpoint failure cases: thrown/refused writes plus thrown, secret, missing, wrong and nonnumeric readbacks, each at zero and one. Failed validation keeps the original countdown visible, preserves its text and leaves replacement bindings disabled. A later existing safe retry reuses the probe and prepared labels and displays the current native-bound `6.3` after successful validation.

The secret-read case retains numeric type and requires a positive secrecy check. Removing `public(value)` in an isolated mutation makes that regression fail. This avoids a test that would pass merely because a table-shaped mock fails a number-type check.

The prior below/equal/above-minimum, native-rate, color, ownership, idle-preparation, refusal-cache and no-new-combat-resource assertions remain in place. New tests demonstrate the intended behavior under their explicit API models; they do not emulate the game engine's actual secret-value enforcement or renderer.

## Style diagnostics, not a style repair

`readActionStyle` can legitimately fail at several native interfaces. The current [FontString API](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) permits a nullable font file and an absent text-color result; text color can also be secret for VertexColor/Alpha. Effective scale has a secret Scale aspect in the region API. The current capture does not distinguish these from other getter refusals.

The same existing reads now return a fixed public property stage: `label`, `font`, `source-scale`, `parent-scale`, `text-scale`, `relative-scale`, `text-color`, `shadow-color` or `shadow-offset`. The cached output becomes `style-unavailable/<property>`. There are no new getters, raw-value/error-payload logs, guessed colors, cached-style substitutions or additional retries.

The nullable-font fixture and new absent-color, secret-color and secret-scale cases verify unchanged stock text/visibility, disabled replacement bindings, safe recovery displaying the current tenth, and diagnostics that do not query native state. This makes a later receipt informative; it does not fix unavailable native appearance or establish which property failed on the two pictured buttons.

## Architecture check and buff limit

The simpler native action `SetCountdownFormatter` route is already installed by bjarkiUI. The four plain typography profiles retain the original formatter when measured digit advances are equal; those measurements do not prove stationary visible ink or native string kerning. No native per-digit column switch was found. The current correction retains the existing independently anchored bindings rather than claiming that whole-label alignment proves fixed numerals.

The ordinary buff template exposes a FontString, not a duration binding or native cooldown that can receive a formatter. The inspected APIs expose no supported duration-by-slot lookup or binding lookup by FontString. Secret aura identity and secret timing cannot be passed through unsupported addon factories to create a replacement clock. The custom native duration delegate works on its own native-owned aura assignment.

The [native helpful-row design](NATIVE_BUFF_ROW_DESIGN.md) records the concrete private-aura exclusion and enchant/layout limits of that replacement. This investigation established no compatible in-place repair for the secret-ID buff path. No buff runtime or visible row is changed in this package.

## Final package verification

| Check | Result |
| --- | --- |
| Native Lua 5.1.5 | All 37 top-level scripts pass; all 16 runtime modules and test sources compile. |
| Native Lua 5.4.6 | All 37 top-level scripts pass with the same compilation checks. |
| Action digit suite | 6,306 assertions pass on each interpreter. |
| Aura suite | Existing 226 cases pass on each interpreter; buff runtime is unchanged. |
| Independent final review | No material findings; fresh focused runs pass on both native interpreters. |
| Archive/source checks | Matching manifest version/load order, exact 19-file membership, integrity and byte equality pass. |

`git diff --check` is clean. The established adapter uses native `loadfile` for compilation because standalone `luac` is unavailable, and the repository verifier's manifest/package functions. These are local results; the stacked draft does not run the workflow restricted to main. Counts describe fixture coverage rather than a percentage of client behavior. See [testing commands](TESTING.md) and the [packaged source manifest](SOURCE_SHA256_0.2.359.txt).

`bjarkiUI-0.2.359-Native-Timer-Validation.zip` contains one installable `bjarkiUI/` folder with 19 files: 16 Lua modules, two matching manifests and the existing spacer texture. Archive size: **134,181 bytes**. Expanded size: **527,795 bytes**; runtime Lua source: **525,663 bytes**. File sizes are not runtime memory.

SHA256: `91b2c482a9262f5abde5065ee1a8f0a496bcd97ad805bbd3490f80e56d906ea5`.

The “Ultralight unit-frame presentation for WoW: Forever” wording is retained. This patch adds no polling, ticker, event frame, module or dependency. The two endpoint checks run in existing safe calibration; style diagnostics reuse existing reads. The [.356 comparison](VERIFICATION_0.2.356.md) remains historical evidence, not a new benchmark or client FPS/memory claim. Tests and reports are excluded from the installable ZIP. The [live issues](../KNOWN_ISSUES.md) remain open.
