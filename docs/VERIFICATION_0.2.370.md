# .370 combat-aware level highlights

## Outcome and intent

The assistant previously chose blanket highlight removal in .369 after the user
offered it alongside a richer combat-aware option. The user rejected that
choice as inconsistent with this project's ambition. This build implements the
state-aware behavior:

| Frame | Highlight condition |
| --- | --- |
| Player | Never; no highlight texture or player combat query exists |
| Target | Its current unit is in combat and its native numeric level is displayed |
| Focus | Its current unit is in combat and its native numeric level is displayed |

The three native base badges remain 28 × 16 with a sixteen-unit portrait gap.
Target and Focus each receive one reusable native outline, 34 × 23 and centered
half a portrait unit lower, immediately below their numeric text. Five textures
are the total bound across all three roles. Native fonts/colors, lower circles,
skulls and timers retain their behavior.

Baseline .369: local commit `f68c837ca9a77edf2b07a71cfe0080130c872132`, remote
`a075184f654979bd6a41377bb017e004fb05febd`, matching tree
`10dc93c9d084067a6027f0487b523558018f57c4`. Runtime behavior changes only in
FrameLabelTweaks; the main literal and both manifests receive version metadata.
[Verified payload identities](SOURCE_SHA256_0.2.370.txt).

## Native contract and deliberate policy

The pinned Forever source revision is
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676` in Gethe/wow-ui-source.

- [Camelot level-frame mixin](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_NamePlates/Camelot/Blizzard_NamePlateLevelFrame.lua)
  keys this specific native outline to target/focus selection. bjarkiUI reuses
  that artwork with the user's requested combat policy on unit frames; it does
  not claim that the conditions reproduce the native selection mixin.
- [Unit API declarations](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
  define UnitAffectingCombat as returning a nonnil boolean with no secret-return
  flag. Queries use only the fixed public target and focus tokens. Unexpected
  nil, errors or other public types clear the highlight.
- [Region API declarations](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua)
  allow secret arguments from tainted callers for all SetAlphaFromBoolean
  arguments; GetAlpha follows its region's Alpha secrecy aspect. Opaque shown
  state is first composed into the base's native alpha, then that result is
  forwarded unchanged as the highlight's true alpha for the combat selector.
  No opaque boolean/numeric comparison, arithmetic, formatting or persistent
  opaque cache is used. Public hidden text explicitly contributes zero.

## Lifecycle and cost boundaries

Filtered UNIT_FLAGS registration observes target/focus. Both prepared roles
refresh on delivery so alias payload spelling does not decide correctness.
A guarded compatibility fallback receives UNIT_FLAGS globally if unit-filtered
registration is unavailable. Target/focus changes refresh prepared visibility
even during combat. Safe existing lifecycle events handle discovery and retry.
No polling, extra clock, runtime module or option is introduced.

Geometry and creation/rebinding remain outside combat. Refused highlight setup,
combat reads or highlight sinks preserve a usable base and clear only the
highlight. Losing the current physical label/owner or accepted side placement
hides both layers. Relevant unit events and native anchor changes increment the
writer revision; an older query cannot paint a newer target. Public accepted
outputs skip unchanged artwork writes; opaque values stay on the callback stack.
The two-attempt nested-writer retry remains bounded.

## Executed verification

- The badge fixture contains 18 cases: the original 13 presentation/lifecycle
  cases plus five combat-focused cases. The saved .369 source passes three and
  fails fifteen under both interpreters. .370 passes all eighteen under native
  Lua 5.1 and Lua 5.4.
- Coverage verifies actual geometry/draw layers, native mutation sentinels,
  independent combat entry/exit, filtered and alias event delivery, switches and
  deselection in combat, all four opaque combat/visibility combinations, failed
  combat reads/sinks/configuration, physical replacement, stale callbacks, and
  newer events interrupting a combat query. Replacement inside the query with
  no additional event immediately clears old artwork. Safe recovery reuses
  resources and unchanged warm refreshes do not rewrite geometry.
- All 38 top-level scripts pass under native Lua 5.1 and Lua 5.4. All 16 runtime
  modules compile through native loadfile; manifests agree on version/order and
  prohibited Edit Mode writer checks pass.
- A fresh independent reviewer found no Critical, Important or Minor issues,
  checked the actual native declarations, independently passed both focused
  runs and confirmed a clean whitespace check.

## Package

The ZIP contains 19 files: matching manifests, 16 runtime Lua modules and
one existing spacer texture. Archive integrity, exact membership and source-byte
equality pass. Expanded size: 594,329 bytes; ZIP size: 147,406 bytes.
All payloads except FrameLabelTweaks and the three version-bearing files are
byte-identical to .369. Tests, documents, research and user settings are excluded.

SHA-256: `c22c875fa6734d5717dce5af6938e1744581a083a7dcddcb2f196513d35d1b3a`.

## Live limits

Source and fixtures establish the declared APIs, safe forwarding and modeled
state transitions. The Lua source does not expose the engine's complete flag
emission implementation. Live combat entry/exit event delivery, optical fit,
taint behavior and frame-time performance have not been observed for this build.
The existing timer and microstutter reports remain open in
[known issues](../KNOWN_ISSUES.md). No manual diagnostic workflow is assigned.
