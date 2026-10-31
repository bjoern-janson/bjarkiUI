# bjarkiUI architecture

**Incoming hit-text lifecycle (2026-10-27):** `0.2.258-hit-text-recovery-test` refreshes incoming Player hit-text position on scale/display changes and retries positioning after combat. It reuses the existing guarded two-pixel anchor calculation; no polling or saved layout writes are introduced. See section 42.

**Presentation recovery (2026-10-27):** `0.2.257-presentation-recovery-test` refreshes numeric status shadows after effective-scale changes and retains failed Soft Dark color/saturation restoration state for retry. Existing native Player colors, cooldown formatting and layout-neutral policy remain in place. See section 41 for the repair scope and verification boundary.

**Sub-five-second decimals (2026-10-26):** `0.2.256-five-second-decimals-test` adds one decimal to native action-button cooldowns strictly below five seconds. Whole seconds from five to 359 remain unchanged, as do six-minute-and-longer compact labels. The native formatter still receives protected values directly and no timer polling is introduced. Section 40 supersedes the lower-band presentation in section 39.

**Native cooldown seconds (2026-10-26):** `0.2.255-native-cooldown-seconds-test` formats Blizzard-owned action-button cooldown counts as whole seconds strictly below 360 seconds (e.g. `1:45 → 105`, `5:21 → 321`) via a single native `NumericRuleFormatter`. Longer cooldowns retain compact minute/hour/day labels. No timer data is read by addon Lua, and no new per-frame updates are introduced. See section 39.

**Native Player colors / minimalist status text (2026-10-26):** `0.2.254-native-player-shadow-text-test` stops custom class tinting of Player health and name while retaining class colors on Target/Focus/ToT/FoT. Health and power numeric FontStrings drop the font outline and receive a small native 1-pixel dark shadow. Native font family, size, text color, value updates and geometry remain unchanged. See section 38.

**Shop micro-menu notification (2026-10-26):** `0.2.253-shop-pip-test` suppresses the Shop/Store notification pip in-game, without hiding the button or changing its tooltip, action, or layout. This does not affect the character-selection screen, where character addons are not loaded. See section 37.

**Player text positioning and conditional status precision (2026-10-26):** `0.2.252-foundation-v16-combat-text-test` keeps incoming player feedback horizontally aligned to the health bar and anchors its bottom two physical screen pixels above the top of the native PlayerFrame. Percentage-only status text uses integer precision at/above 100% and one decimal below 100%, with native secret-safe number formatting. See section 36.

**Prelaunch offline repairs (2026-10-25):** `0.2.251-foundation-v16-offline-fixes-test` fixes Tracked Buffs pool iteration, completes PartyOrder visibility/geometry fail-closed preflight, retries remaining native presentation hooks without duplication, and verifies native color restoration setter success. Soft Dark Edit Mode callback registration is independently retryable. Section 35 records the scope and testing boundaries.

**Lifecycle repair (2026-10-25):** `0.2.250-foundation-v16-lifecycle-repair-test` adds repeatable notification-pip suppression, per-method PartyOrder hook retry, fail-closed secrecy probes, and guaranteed health-color recursion-guard cleanup. See section 34.

**Hardening update (2026-10-25):** `0.2.249-foundation-v16-hardening-test` makes classic nameplate CC offsets fail closed on unreadable permissions, restores captured native compact-border alpha, and retries missing native update hooks individually at Blizzard module/world-entry boundaries. CI now compiles all four Lua modules with Lua 5.1/5.4 and runs source-backed mocked regressions. The no-preset policy and saved-layout ownership remain unchanged.

**Layout-neutral release (2026-10-23):** `0.2.248-foundation-v16-layout-neutral` removes both bundled Edit Mode presets and all code that creates, replaces, saves, activates, or migrates player layouts. The addon retains only existing presentation refreshes triggered by Edit Mode changes; it never writes the serialized layout. Former installs are not retroactively undone: pre-existing saved layouts remain user-owned. Section 32 documents this change.

**v16 suite update (2026-10-22):** this addon receives release-version metadata only. Its behavior is byte-identical to v15 apart from that version string. The three timing repairs are in bjarkiCC Model/Observer. The full v16 suite passes 49 regression scripts and 28 runtime syntax checks on both Lua 5.1 and Lua 5.4; live-client findings below retain their existing status. The behavior described in architecture section 31 remains applicable.

> **Current repository baseline (2026-10-26):** `0.2.256-five-second-decimals-test`. Sections 1–39 are historical implementation notes; section 40 documents the sub-five-second decimal update. Live-client verification remains outstanding.

This document now tracks **bjarkiUI 0.2.256-five-second-decimals-test**. **Section 32 supersedes historical layout behavior; sections 33–40 document the current safeguards**. This is a maintenance reference, not a guarantee about undocumented WoW: Forever client behavior or taint safety.

The addon is deliberately small. The runtime consists of:

- `bjarkiUI.lua` — unit-frame presentation, names, highlights, non-persistent UI adjustments, combat text placement, and event hooks.
- `PartyOrder.lua` — visual ordering of raid-style party frames.
- `SoftDark.lua` — the fixed decorative theme.
- `TrackedBuffSeconds.lua` — integer-second tracked buff countdown presentation.
- `CooldownSeconds.lua` — bounded, native-format-only action-button cooldown presentation.
- two matching `.toc` manifests.

`ARCHITECTURE.md` is not loaded by the game.

## 1. General approach

bjarkiUI mostly leaves Blizzard frame ownership and data sources intact and changes presentation after native updates.

The main recurring pattern is:

1. resolve the Blizzard frame or region that owns a visual element;
2. wait for, or hook after, the native update that normally writes it;
3. apply the smaller presentation change;
4. avoid replacing the surrounding Blizzard system.

There is no addon-owned `OnUpdate` loop in the current build.

## 2. Unit frames

The addon styles six unit tokens:

- `player`
- `target`
- `focus`
- `targettarget`
- `focustarget`
- `pet`

Health and power bars are resolved through the current Blizzard frame structure with older/global fallbacks where useful.

Both health and power fills use the atlas:

`UI-HUD-CoolDownManager-Bar`

The addon does not replace the underlying health or power values.

### Health colors

The health-color path currently prefers:

1. positively identified players -> class color;
2. positively identified combat pets -> green;
3. disconnected/dead units -> grey;
4. tap-denied NPCs -> light grey;
5. hostile units with readable threat state -> red;
6. otherwise -> Blizzard selection color when readable.

Player class colors receive a small saturation/brightness adjustment.

For `targettarget` and `focustarget`, the native frames are reusable. The addon therefore reapplies the current unit's presentation when Blizzard rebinds those frames. It also hooks the final health-bar color write on those two derived frames so a later native tint does not leave the color from the previous referent.

If the derived referent cannot provide a readable replacement color, the current implementation clears the stale tint to neutral grey rather than preserving the previous unit's color.

### Power colors

Power bars use Blizzard's current power token and `PowerBarColor` when readable. The addon changes the bar artwork but not the power value or type calculation.

## 3. Names

Player names are shortened to their primary name on the surfaces the addon explicitly handles.

Current surfaces include:

- player/target/focus/derived unit-frame names;
- compact raid/raid-style party/nameplate player names;
- ordinary chat sender display;
- Communities/Guild roster and Communities chat display;
- Blizzard Damage Meter source labels.

The implementation tries to change only visible text. Hyperlink payloads, combat-source records, roster records, and other identity data remain native.

Damage Meter rows are recycled, so name normalization is attached near the final text writer rather than only at row creation.

## 4. Highlights and status presentation

Threat/combat/resting highlights reuse Blizzard textures and geometry.

The common visual intensity is currently:

`HIGHLIGHT_SCALE = 0.25`

The player frame's native pulsing status texture is hidden. Resting uses a static yellow copy of the native player flash geometry instead.

Pet attack/threat cues are also scaled to the same general intensity.

## 5. Level display

Level rings are hidden and level text is reduced slightly.

Level numbers are controlled by the per-character setting:

`bjarkiUISettings.showLevelNumbers`

Commands:

- `/bui levels`
- `/bui levels on`
- `/bui levels off`

When level numbers are shown again, target/focus defer to Blizzard's own level checks where available.

## 6. Edit Mode and bottom UI

The addon ships no Edit Mode layout or preset and never creates, imports, replaces, migrates, saves, or activates a layout. Player-saved layouts remain entirely user-owned. The `EDIT_MODE_LAYOUTS_UPDATED` event is used only to refresh presentation after a user-initiated layout change.

The Micro Menu correction is independent of the player's serialized Edit Mode layout. The addon leaves `MicroMenuContainer` in place and offsets the visible `MicroMenu` child downward by one UI unit after Blizzard anchors it.

This avoids moving the shared container that other bottom-bar elements may use as an anchor.

## 7. Combat text

Outgoing world combat text uses two CVars:

- `WorldTextScreenY_v2 = 0.0425`
- `WorldTextCritScreenY_v2 = 0.0550`

Incoming player hit text is anchored above the Personal Resource Display using Blizzard's existing combat-text frame.

The previous experimental PRD movement-speed/duel-distance module is not present in 0.2.67.

## 8. Party frame ordering

`PartyOrder.lua` changes only the visual order of raid-style party member frames.

Desired vertical order is:

`party1 -> party2 -> party3 -> party4 -> player`

For smaller groups, missing party slots simply disappear and the player remains last.

The module does **not** replace Blizzard's party comparator and does **not** call `SetFlowSortFunction()`.

The current implementation lets Blizzard finish `RefreshMembers()` first. A post-hook then reanchors the already-created visible member frames. This means Blizzard keeps the native unit assignment, compact-unit refresh, and normal frame setup; the addon changes only the final out-of-combat anchors.

Full raid ordering is left native. Pet-frame anchors are adjusted to remain under the visually reordered party block.

## 9. Event model

The main file uses scoped events rather than a general polling loop.

Examples:

- target/focus changes refresh the corresponding unit and derived unit;
- `UNIT_TARGET` is registered only for target/focus because only those tokens can change ToT/FoT;
- power/name events are registered only for the unit tokens the addon paints;
- NPC color-state events are scoped to target/focus/derived targets;
- `UNIT_PET` refreshes only the local pet presentation.

Optional Blizzard modules such as Communities and Damage Meter are hooked when they load.

`PartyOrder.lua` installs on login/world-entry/module availability, derives the visible party order from the current assigned unit tokens, and reapplies after both `RefreshMembers()` and direct `UpdateLayout()` paths. It does not initiate Blizzard compact-frame refreshes.

## 10. Protected and secret values

WoW: Forever can expose secret/protected values through otherwise ordinary-looking APIs.

The addon generally checks values before comparing, pattern-matching, or performing arithmetic on them, especially around:

- unit identity;
- class/power/color values;
- chat/combat-source strings;
- frame color components.

This is an implementation constraint rather than a complete emulation of Blizzard's protected execution model. Live-client behavior remains the final check for taint-sensitive paths.

## 11. Practical maintenance rules

The current source is easiest to maintain when changes stay local to the native object that owns the presentation.

In particular:

- do not style auxiliary bars merely because they share a unit token;
- do not move `MicroMenuContainer` to correct the visible menu;
- do not drive Blizzard compact-frame refreshes from custom party sorting;
- remember that ToT/FoT and Damage Meter rows are reused;
- prefer event/post-update corrections over permanent polling;
- keep documentation files out of the `.toc` load list.


## 12. Small presentation suppressions

The current build also makes three narrow presentation changes without replacing the surrounding Blizzard systems:

- raises the default `UIErrorsFrame` vertically while preserving its horizontal center;
- hides dispel-type colored borders on harmful aura icons in compact Party/Raid frames while leaving the icons, cooldowns, stacks, and separate dispel overlay intact;
- hides Guild and Legacy-system notification pips on the Micro Menu while keeping the buttons functional.


## 13. Loss of Control presentation

The default Loss of Control frame remains Blizzard-owned. bjarkiUI post-hooks the
native display/timer writers and reduces the visible presentation to the spell
icon only. The red line textures, black backing, ability label, timer frame,
numeric countdown, and seconds label are hidden after native updates. The icon
is reanchored to the exact center of the existing Loss of Control frame.


## 14. Derived-frame repair notes

Version 0.2.73 hardens Target-of-Target / Focus-of-Target presentation in three places:

- derived health colors fail closed to neutral grey while player/pet identity witnesses are unreadable or disagree, instead of reusing an incorrect semantic tint;
- native ToT/FoT debuffs are restored when Blizzard's global `showDispelDebuffs` option would otherwise filter friendly derived units down to `HARMFUL|RAID`;
- compact Party/Raid debuff borders are suppressed by feeding the secure private-aura renderer zero border geometry through its ordinary frame settings, rather than attempting to hide forbidden `PrivateAuraMixin` regions after render.


## 15. Party-order lifecycle recovery

Version 0.2.74 keeps the custom raid-style party order stable across member
relogs, disconnect/reconnect transitions, and other compact-frame lifecycle
changes.

Two native paths are covered explicitly:

- CompactPartyFrame caches `UpdateLayout` as `updateLayoutFunc` during OnLoad,
  so bjarkiUI post-hooks that actual cached native writer rather than relying on
  the public method alone.
- individual compact member frames can hide/show while a unit token disappears
  and returns; their visibility transitions now trigger a bounded visual-order
  reapply out of combat.

Blizzard still owns unit assignment and compact-frame refresh. The addon only
reasserts anchors after native lifecycle/layout writes.


## 16. Communities chat secret-message boundary

Version 0.2.75 removes the direct wrapper around
`CommunitiesFrame.Chat:FormatMessage`.

Forever can supply `FormatMessage` with a secret message table. Calling the
native formatter from an addon-owned replacement taints that execution before
Blizzard indexes the secret table.

Guild/Communities secondary-name shortening now happens only after Blizzard's
native ScrollingMessageFrame has completed rendering. bjarkiUI registers an
`AddOnDisplayRefreshedCallback`, reads only accessible visible FontString text,
preserves the complete `playerCommunity` hyperlink payload, and shortens only
the hyperlink's display text.

The C_Club message table and native formatter remain untouched.


## 17. Compact-frame taint rollback

Version 0.2.76 removes the 0.2.73 compact Party/Raid debuff-border suppression.

The previous implementation wrote a synthetic negative `debuffBorderScale` directly
onto Blizzard compact unit frames so the secure private-aura renderer would compute
a zero-sized border. That writes addon-owned state into a compact frame later used
by native secret-health/heal-prediction code, and can taint Blizzard's
`CompactUnitFrame_OnUpdate` path.

The addon no longer modifies compact aura-renderer settings or private-aura border
geometry. Colored debuff borders therefore remain native for now rather than
trading a cosmetic change for secret-value taint.

Party-order reconnect recovery also no longer installs `OnShow`/`OnHide`
scripts on compact member frames. `UNIT_CONNECTION` is observed by a separate
addon event frame and the visual reanchor is deferred to the next tick, outside
Blizzard's compact-unit update stack.


## 18. Compact debuff border presentation

Version 0.2.77 restores the requested removal of compact Party/Raid debuff borders
without writing addon-owned values into Blizzard compact-frame Lua state.

The addon post-hooks Blizzard's final `AuraUtil.SetAuraBorderAtlas` presentation
write. After Blizzard has already consumed the secret aura/dispel data, bjarkiUI
identifies compact Party/Raid aura textures only from their fixed frame ancestry
and sets that border Texture's alpha to zero.

No `CompactUnitFrame` fields, private-aura settings, aura tables, health values,
or heal-prediction state are read or modified. Because private aura frames are
pooled, a border hidden by bjarkiUI is restored to alpha 1 if that same Texture is
later reused on a non-compact presentation.


## 19. Conservative hardening and audit

Version 0.2.78 makes no new presentation claims. It narrows two UNKNOWN-state
paths and adds read-only diagnostics.

- tap-denied NPC coloring now requires an explicit readable
  `UnitPlayerControlled == false`; UNKNOWN no longer authorizes an NPC tint;
- Damage Meter normal name shortening requires an explicit readable
  `isCreature == false`; secret/UNKNOWN creature status falls through to the
  independently warranted local-player path only;
- Loss of Control post-hooks track installation independently, so one unavailable
  Blizzard method cannot prevent the other from being retried later;
- `/bui audit` reports hook state, derived-frame availability, and compact-party
  `debuffBorderScale` values without repairing or mutating them.


## 20. Protected-input and party-order hardening

Version 0.2.79 tightens presentation ownership without changing the intended
visual layout.

- Blizzard-provided unit-token fields are checked for secrecy/readability before
  comparison, pattern matching, or use as unit API arguments.
- compact-party ordering treats the assigned unit token as the warrant for
  reordering. If a shown member's token is inaccessible, the addon leaves the
  native layout untouched instead of inferring identity from frame position.
- party-frame visibility, Edit Mode state, raid state, and title height are read
  through guarded helpers rather than assumed to be ordinary values.
- post-hooks on Blizzard party layout writers no longer reanchor frames inside
  the native update call stack. They coalesce one repair for the next tick,
  where live membership and combat state are checked again.
- reconnect/disconnect recovery uses that same deferred path instead of a
  separate scheduling mechanism.

The maintenance invariant is that **presentation authority follows readable
identity and runs outside Blizzard's protected state-transition stack whenever
possible**.


## 21. Compact debuff-border ownership

Version 0.2.80 corrected the intended native write boundary for the colored
compact debuff border to `CompactUnitFrame_UtilSetDebuff`, while retaining a
narrow `AuraUtil.SetAuraBorderAtlas` compatibility path.

## 22. Compact debuff-border lifecycle hardening

Version 0.2.81 tightens that implementation after live validation showed the
per-aura hook alone was insufficient on the tested client.

The addon now has three non-invasive final presentation boundaries:

1. `CompactUnitFrame_UtilSetDebuff` — catches the native type-color write;
2. `CompactUnitFrame_UpdateDebuffs` — performs a final sweep after the full
   debuff refresh;
3. `CompactUnitFrame_UpdateAuras` — covers builds that route aura refresh
   through that path.

The update hooks operate only on frames positively identified in their parent
chain as:

- `CompactPartyFrameMemberN`
- `CompactRaidGroupNMemberN`
- `CompactRaidFrameN`

The sweep changes only the existing `debuffFrame.border` alpha. It does not
inspect aura data, alter debuff selection, touch icons/cooldowns/stacks, change
health bars, or write compact-frame state.

Hook installation is also retryable. If Blizzard's compact-frame module is
loaded after `PLAYER_LOGIN`, bjarkiUI waits for the relevant
`ADDON_LOADED` boundary instead of permanently recording an uninstalled hook
as installed.


## 23. Reported Battleground class-color gaps

Recent user reports (2026-10-08) say opposing-faction class-colored health
bars remain white or otherwise incorrect in Battlegrounds. The same problem
affects enemy Target-of-Target and Focus-of-Target bars. This is not live-
validated against 0.2.90-local; the pushed source should not be described as a
confirmed fix.

A prior `/bui colors` capture showed the enemy target and targettarget as
`player=true` but `class=unknown`, with no usable nameplate color in that
diagnostic context. This records an UNKNOWN input at that point in the path; it
does not prove whether the cause is client API visibility, unit-token timing,
or refresh lifecycle. Trace the identity/color evidence before changing color
fallbacks.

During earlier ToT/FoT debugging, changing the display CVar made the frames
disappear. The user restored them with `show=1` and `mode=nil`; frames returned,
while opposite-faction class colors remained unresolved. Do not change those
CVars as a color workaround. Check frame availability, current unit binding,
readable class evidence, and the final native color writer as separate steps.
## 24. Field study: local 0.2.134, native bar rendering, and compact chrome (2026-10-11)

> **Historical record:** The version-boundary and repository-state observations in this section describe 2026-10-11. The later 0.2.156-local source is documented in section 25.

> **Version boundary.** This section documents a **tested local ZIP**, `bjarkiUI-0.2.134-local`, rather than the implementation on the repository's `main` branch. As inspected during this audit, `main` still had `bjarkiUI-0.2.90-local` and the preceding sections describe that older snapshot. **Do not infer that these local changes have been pushed or released.** The user has not requested a source-code merge. This is an additive maintenance record of what was observed, tested, rejected, and left unresolved.
>
> Local ZIP SHA-256: `eb590f56a727cfb7bb88504ecfe1f5e37abafa99f1e21b77b48c57dc5d076030`. Main Lua source SHA-256 (inside ZIP): `5a40129f822ca994a8be92581a61e49eac6d9ca931107e5b31d861cbfb68ac97`.

### 24.1. Evidence categories and visual coverage

The final review examined **four user-supplied in-game PNG screenshots**, capturing the addon in multiple conditions, not just a single still frame:

| Capture | Scene / what it exercises | Visible outcome / scope |
| --- | --- | --- |
| SS1 (1186 × 613) | Player, target, focus, PRD, full mana | Orange Druid HP and blue mana present with readable text and stable frame borders; minor native rendering differences are not proved absent. |
| SS2 (1228 × 725) | Hostile target/focus with derived player ToT/ToF, PRD | Red hostile health and orange player-derived health follow intended semantic colors; the compact silver borders and separators are visually legible. |
| SS3 (1232 × 728) | Druid form with Rage and secondary Mana | Red primary resource and blue secondary mana appear on PRD/frames as appropriate; reduced fill reflects changing resources, not missing textures. |
| SS4 (1221 × 751) | Druid form with Energy and secondary Mana | Yellow Energy and blue alternate Mana display distinctly; compact derived-frame chrome remains visible across resource changes. |

The images support **visual acceptance under those sampled states**. They do **not** independently prove pixel identity, persistence across all UI scales, frame reuse, dungeon/BG behavior, or zero taint in combat. Earlier screenshot-by-screenshot pixel claims were occasionally stronger than the evidence and should not be treated as engineering invariants.

### 24.2. Rendering model: do not conflate four independently owned surfaces

A unit frame is not one monolithic colored rectangle. At least four distinct native owners interact:

1. **Layout / geometry:** parent frame, health StatusBar, mana/other power StatusBar, and their separate anchors/heights;
2. **Fill artwork:** the StatusBarTexture atlas and its own RGB multiplier/desaturation;
3. **Masks and chrome:** health/power mask textures plus the frame's metallic/nameplate `FrameTexture` artwork;
4. **Status text:** independently anchored FontStrings, sometimes parented to the bar container rather than the StatusBar itself.

Consequences confirmed during iterations:

- Moving the player `HealthBarsContainer` does **not** reliably move the mana StatusBar or the health text in the same way. It can expose gaps or border overlap.
- Increasing health-bar height changes the texture's sampling/coverage and may not move the mask or border. An apparent one-pixel gap is not automatically an anchor error.
- Tinting an already-colored native atlas multiplies hues. Atlas choice, RGB multiplier, and masking must be debugged separately.
- **Frame level precedes draw layer.** Changing `SetDrawLayer` on a texture in a parent frame cannot be relied upon to draw over distinct higher-level StatusBar child frames. An overlay child frame with its own higher frame level was the observed successful mechanism.

### 24.3. Geometry reference and what was actually adjusted

| Surface | Native reference or diagnostic | Local 0.2.134 behavior |
| --- | --- | --- |
| Player HP | Blizzard's runtime `PlayerFrame_ToPlayerArt` normally sets a **19-UI-unit** health bar, notwithstanding a 20-unit XML default. | Keeps the accepted `.114`–`.116` composition: HP fill height 20.5 and relative top offset +0.5 under a narrowly recognized player-art layout. Health text is adjusted independently. |
| Player resource | Separate `ManaBarArea.ManaBar`; runtime normal position corresponds to X=85, Y=-61. | Keeps the visually accepted resource position X=85, Y=-62, with native text anchored inside it. |
| ToT compact HP | Native `TargetofTargetFrameTemplate` uses 70 × 10, anchored `BOTTOMRIGHT` to parent `RIGHT` at (-6, -2.5). | 10-unit native ToT HP reference. |
| ToF compact HP | Same native template; observed health heights were 10.000018 and 9.999895 (ToT/ToF), a floating-point distinction, not a meaningful design difference. | ToF-only +0.25 height adjustment = nominal 10.25. Bottom-right anchor stays fixed; top edge changes. |
| ToT/ToF resource | Native 74 × 7 `ManaBar`, `TOPLEFT` relative to `HealthBar.BOTTOMLEFT`, X=-4, Y=-1. | Both compact resources use the tested Y=0 anchor, removing the native 1-UI-unit separation. |
| Compact effective scale | In a user diagnostic, both ToT and ToF reported ~0.825. | No change to overall compact scales or vertical parent-frame anchors. Horizontal portrait alignment is a separately guarded existing feature. |

The user's in-game measurement of the native compact seam showed **about 0.75 screen pixels** between HP bottom and mana top for both frames, after considering their location and scale. The later Y=0 change improved that seam, but **did not by itself produce fully pronounced silver chrome**.

**Guarding lesson:** WoW's returned geometry often has floating-point noise. A check expecting exactly `10` within `1e-6` was too strict and silently skipped the intended adjustment. The accepted local height helper now uses 0.005 tolerance and guards the anchor type/relative frame and native-like height. **Residual issue:** it does not require the expected X/Y anchor offsets, so an unfamiliar layout with the same anchor type and 10-unit height can still be adjusted. That is a compatibility hardening opportunity, not an observed failure in the four screenshots.

### 24.4. Decisive compact-frame chrome discovery

The silver frame/health-to-resource separator on ToT and ToF belongs to the compact parent frame's Blizzard **`FrameTexture`**, whose XML declares it in a `BACKGROUND` layer; the health and mana StatusBars are separate child frames. The user tested manually creating a new, mouse-transparent child frame at **`ManaBar:GetFrameLevel() + 1`**, copying the native `FrameTexture` atlas at its native dimensions and centering it over the compact frame. That improved the ToF chrome without relocating its bars. Applying the same mechanism to ToT then produced the visually accepted 0.2.134 state.

Implementation in `alignCompactChrome(unit)`:

- Applies **only** to `targettarget` and `focustarget` and only when combat state is explicitly readable and `false`.
- Resolves the live compact frame, its `ManaBar`, and original `FrameTexture`; reads the atlas and mana frame level with guarded calls.
- Creates one overlay frame per compact frame using `CreateFrame("Frame", nil, frame)`, `SetAllPoints()`, `SetFrameLevel(manaLevel + 1)`, and a centered `CreateTexture(nil, "OVERLAY")` with the original atlas (`useAtlasSize=true`).
- Keeps the overlay mouse-transparent; retains the underlying native border rather than hiding it; stores overlay state in a weak-keyed table.
- Revisits the cached overlay on supported lifecycle boundaries to update its atlas/frame level if Blizzard changes them; **does not add a polling loop**.

The earlier `.133` attempt was **ineffective**: it guarded for `FrameTexture:GetDrawLayer() == "ARTWORK"`, but the original compact chrome is declared `BACKGROUND`. Even changing that one guard would not solve cross-frame ordering by itself.

**Do not silently generalize the overlay:** it intentionally duplicates the visual chrome. It may need reevaluation under alternative UI scale, explicit focus-size changes, future atlas changes, and protected frame transitions. If initialization fails *after* creating its shell but *before* recording it, the current helper can leave a partial shell and retry later. The tested happy path is one overlay per compact frame, not a proof of leak-free failure behavior.

### 24.5. Health color fidelity with native Blizzard textures

The sequence matters:

1. `.126` removed addon-owned **health texture replacements** to restore native Blizzard health artwork. The corresponding class-tinted fill became olive/muddy in actual play; a native colored texture multiplied by the adjusted Druid color was not hue-neutral.
2. A manual `HealthBar:GetStatusBarTexture():SetDesaturated(true)` test restored the intended orange visual. `.127` applied the same principle to the handled health bars.
3. The local `setHealthColor` path first completes any relevant StatusBarDesaturated reset and RGB write, and **then** calls `neutralizeNativeHealthArtwork()` to desaturate the underlying texture only. `applyUnit()` also performs that neutralization after its color-selection path, covering identity-transition fallbacks.
4. This preserves native geometry/texture luminance while allowing class, pet, hostile, tap-denied, and NPC color selection to remain separately determined. It **does not** imply that all native health layers, heals, damage-loss overlays, or combat animations were exhaustively tested.

`CLASS_SATURATION = 1.18` and `CLASS_BRIGHTNESS = 1.08` remain the adjusted-class palette parameters. Native player identity is preferred only when positively supported; uncertain ToT/ToF identity no longer authorizes a guessed class tint. Existing BG/opposing-faction class-color limitations should remain documented as **not exhaustively validated**, despite positive screenshots in ordinary play.

### 24.6. PRD and native power atlas selection

Health and power are **separate** on PRD. The local code no longer assumes one blue mana atlas for all power types:

- `UnitPowerType` determines the **current primary power token**; for native unit frames the atlas is type-specific and uses the appropriate player/target/compact family.
- Fully colored resource atlases use an **RGB multiplier of (1,1,1)**; applying a blue/red/yellow `PowerBarColor` again can distort their native highlights. `GetAtlas()` confirming an atlas name does not establish that its final pixels are correct if the multiplier or mask is wrong.
- PRD primary **Mana**: native mana artwork (portrait-off preferred, same-resource fallback); **Rage**: red Rage artwork; **Energy**: the neutral `UI-HUD-CoolDownManager-Bar` texture with yellow `(1,1,0)` tint. The energy exception deliberately avoids a bright top edge bleeding through PRD's dedicated border.
- Druid Cat/Bear **alternate Mana** is drawn through `PersonalResourceDisplayFrame.AlternatePowerBar`, not `PowerBar`. Its active power token remains MANA even when `UnitPowerType("player")` returns ENERGY or RAGE. The helper must pass an **explicit `"MANA"` override**.
- PRD health is separate again: default green receives a 20% blend toward white; class-color mode uses the adjusted class palette. An earlier in-game default-green readout was approximately `(0.200, 0.839, 0.200)` and was evidence the health tint actually applied; it did not mean the PRD primary resource was green.

A previous leading/trailing-edge issue appeared when portrait-attached Mana atlases were stretched across PRD. A portrait-off candidate is preferred and a same-resource fallback is used if unavailable. The final screenshots show plausible native gradients, **not a mathematical proof that all atlas endpoints clip perfectly at every fractional resource value**.

### 24.7. Experiment ledger: what to keep and what not to repeat

| Versions | Observation / lesson | Disposition |
| --- | --- | --- |
| 0.2.107–.109 | Flipping container offset -40 / -42 / -41 moved the HP artwork but left status text/mana relationships inconsistent. | Avoid whole-container guessing. |
| .110–.113 | A 20-unit guard skipped against the actual 19-unit runtime bar; enlarging bars created top-border bleed and moved resource status text. | Require live geometry and independent text anchors. |
| .114–.116 | Separating HP text/fill alignment from resource bar placement produced the accepted player baseline. | **Retain** unless repeatable regression. |
| .117–.118 | PRD tint looked unchanged until RGB diagnostics clarified color mode and showed the 20% white blend. | Test actual RGB and native class-color setting. |
| .119–.123 | Atlas assignments alone were insufficient. White multipliers exposed blue native Mana artwork; type-specific Energy/Rage artwork and a separately styled Druid alternate Mana were necessary; PRD Energy needed neutral fill to avoid top bleed. | **Retain** type-specific semantics. |
| .124–.125 | Nudging the entire derived frame moved name/portrait/resource along with HP. | Rejected whole-frame Y adjustments. |
| .126–.127 | Native health texture + class tint turned orange to olive; desaturating the native fill after RGB writes restored intended colors. | **Retain** local color/texture separation. |
| .128–.130 | Overly strict float-height comparison prevented `.128` from applying; later ToF height changes improved a subset of the fill but not silver chrome. | ToF nominal 10.25 accepted; no more speculative height hunts. |
| .131–.132 | Moving compact mana Y=-1 → 0 reduced the visible native seam; applies to ToF and then ToT. | **Retain** with native-anchor guards. |
| .133 | Parent `SetDrawLayer` attempt had a false `ARTWORK` guard and could not reliably exceed child frame levels. | Rejected mechanism. |
| **.134** | New border-artwork child frame at mana frame level +1, overlaid on both compact bars, visually improved chrome. | **Current tested local baseline**, subject to live limitations below. |

### 24.8. Double-check: scope, tests, and boundaries

The local `.134` ZIP contains only `bjarkiUI.lua`, `PartyOrder.lua`, and the two `.toc` manifests. ZIP integrity passed, both Lua files parsed, and `PartyOrder.lua` was byte-identical to `.133`. A diff against `.133` shows the functional delta confined to the compact chrome helper; no unrelated unit-frame/resource algorithms were changed by that build.

Targeted **mock execution**, not WoW client execution, passed for:

- one compact chrome overlay per ToT/ToF, mouse transparency, native atlas, correct frame level, repeated application, combat gating, and updating level/atlas on simulated native changes;
- mana/energy/rage PRD selection, form-specific alternate Mana, unit-frame atlas mapping, missing-atlas fallback, and repeatability;
- native health-desaturation after RGB setting, idempotence, and texture replacement recovery;
- compact ToT native 10 / ToF 10.25, both mana anchors at Y=0, out-of-combat safeguards, and repeated application.

**Important discovered limitations:**

- The compact-health helper validates anchor kind/parent and near-native height but not its expected X/Y offsets. In an adversarial mock with a changed X offset it still applies. A later hardening pass should explicitly guard all relevant offsets, *without changing the accepted visual result*.
- On partial failure inside new overlay creation, the shell is not cached until all operations succeed. Retrying can leave an untracked partial frame. Track creation before risky setup or dispose safely when an API contract permits.
- `atlasAvailable` can optimistically try an atlas when the client lacks an atlas-query API; final visual success still depends on client texture support.
- Native hooks, `pcall`, and `issecretvalue` checks reduce obvious taint hazards but **do not prove zero taint**, secure-stack compatibility, or safety during every combat transition. In particular, creating/releveling child frames of unit frames should remain out of combat and be tested with error capture.
- The screenshots do not settle enemy BG class colors, all pet/guardian state changes, dungeon behavior, alternate UI scale, focus resize, or whether `bjarkiPortraits` always tracks reusable ToT/ToF auras. These are separate validation tasks.

### 24.9. Preferred future debugging protocol

1. **Preserve known-good baseline** (`0.2.134-local`) and work on one variable at a time, with a clear rollback ZIP.
2. **Read the actual native XML and live Lua writer** for the object being changed; XML defaults can be superseded at runtime (e.g., player HP 20 → 19).
3. **Measure the exact property before patching** (`GetHeight`, `GetPoint`, `GetEffectiveScale`, `GetStatusBarTexture():GetAtlas`, `GetStatusBarColor`, relevant `GetFrameLevel`). Use guarded out-of-combat commands; do not infer the code executed from how a screenshot looks.
4. **Test a reversible minimal hypothesis** in game; require an observable result, and distinguish a test not being applied from the tested mechanism being wrong.
5. **Record whether the failed variant was skipped by a guard**, had no visible effect, or caused a genuine regression; do not bundle those outcomes together as “failed.”
6. **Respect ownership boundaries:** data identity → color entitlement; resource token → atlas entitlement; bar anchoring → geometry; texture/parent frame level → border layering. A correct RGB value does not authorize moving a bar.
7. **Audit implementation separately from screenshots**: compile/syntax, mocks, idempotence, combat gates, secret-value reads, lifecycle, and behavior under unsupported layouts. Claim “tested in mock” rather than “taint-free.”
8. **Keep local/repository version provenance explicit.** Updating this document alone must not be described as merging `0.2.134-local` into `main`.

## 25. Historical committed source: 0.2.156-local (2026-10-12)

**Provenance:** The implementation in `bjarkiUI.lua`, `PartyOrder.lua`, and both matching manifests is taken from the accepted `bjarkiUI-0.2.156-local.zip` (ZIP SHA-256 `2bdc6f25d581a6340d54c21811573efc11ddc6a993db2e440f9fa1ce8e592ed7`). The prior 0.2.134 field study remains useful history, but is not a description of the current code. `KNOWN_ISSUES.md` continues to record unresolved Battleground/client observations, not confirmed fixes.

### 25.1. Ownership and colors

- The six regular unit tokens (`player`, `target`, `focus`, `targettarget`, `focustarget`, `pet`) use the neutral `UI-HUD-CoolDownManager-Bar` fill atlas. Blizzard still owns unit values, native frame/mask geometry, and status updates.
- Player class colors use the native `RAID_CLASS_COLORS`/guarded `C_ClassColor` paths **without** the old custom `CLASS_SATURATION` and `CLASS_BRIGHTNESS` multipliers. This intentionally agrees with Blizzard's Damage Meter and class-colored PRD.
- Positively identified combat pets use pure `(0,1,0)`, matching the usual friendly-NPC green presentation; this is an explicit tint rule, **not** an additional saturation operation. NPCs use readable selection, tagged/tap-denied, threat, and death state. UNKNOWN/protected evidence does not justify inventing an actor identity.
- Regular Mana uses the PRD-like `(0.10, 0.25, 1.00)` tint. Energy is yellow, Rage red, and alternate Player-frame Mana gets the same Mana treatment. The PRD retains native bar textures and power values, with only the requested alternate-Mana tint and text adjustments described below.

### 25.2. Pixel geometry, PRD, and Edit Mode

- The accepted player resource-gap fix is a **native Mana mask adjustment**, not a bigger StatusBar: for the recognized portrait-on normal player layout, its `TOPLEFT` mask offset changes from `(-2, 2)` to `(-2, 3)`. Unfamiliar atlas, anchoring, or secret geometry causes a no-op. Keep the existing StatusBar height and text placements unchanged.
- Player health/container positioning comes from the earlier tested narrow alignment guards. The player's Mana percentage (`LeftText`) is left at Blizzard's native anchor because an intermittent native/update-order interaction made forced percentage offsets unreliable. Center/right Mana text retains the separate guarded presentation path.
- The PRD stays on Blizzard's native health/power/alternate-power fills. A small fixed text Y adjustment uses `+1` UI unit for Health and non-Mana primary power, `+0.5` for primary Mana and alternate Mana. Both percentage and numeric regions move together through known native anchors, **without reading secret `GetPoint()` coordinates**. Fractional rendering was judged visually at the user's tested scale; other scales are not certified.
- The embedded Edit Mode default contains Target `Y=-158` and PRD `Y=-175`, among the complete supplied layout settings. The named `bjarkiUI` layout is installed **only when absent**; replacing the addon does not silently overwrite the user's saved Edit Mode layout.

### 25.3. Compact frames and names

- ToT/ToF retain native color selection plus post-update/derived-identity checks; a reused token or inaccessible class does not license stale player-class or pet-green paint.
- The native compact frame's metallic border is copied into a higher-level, mouse-transparent **clipped chrome overlay** so its silver separator appears over both child bars while **not painting across the name field**. The repeated failed draw-layer-only patch did not work because a parent's artwork cannot reliably outrank its higher-level child frames.
- ToT and ToF compact resource bars retain the narrow, accepted `TOPLEFT` gap correction. ToF's bounded health-height experiment and the overlay are local rendering interventions; they are not permission to move the outer portrait or to alter resource text.
- On WoW: Forever a target/focus frame can update values and portrait without writing the new name (also seen with all addons disabled). `bjarkiUI` observes native `SetText` during `UnitFrame_Update`, then repairs a genuinely missed target/focus name write from the **current** unit when readable. This is a workaround for the observed client regression, not a replacement of normal native name writing.

### 25.4. Runtime boundaries and verification

- `PartyOrder.lua` continues to sort existing compact-party frames **visually**, deferring reanchoring until out of combat instead of replacing unit assignments or invoking Blizzard refresh code from an addon-owned path.
- Small UI corrections should be event/post-write based, fail closed on secret numbers or unfamiliar geometry, and never grow cumulative offsets. Diagnostic macros that read secret `GetPoint()` values are not safe evidence in Forever.
- The transient Player Mana seam-stripe, bronze-border, widened StatusBar, and masked-duplicate-artwork experiments from 0.2.136–0.147 were **rejected** and are not part of the 0.2.156 source. The successful native mask correction was retained. The portrait timer `/bp timery` experiment belongs only to the separate portraits addon and has been removed there.
- **Verified for this source sync:** ZIP integrity, both Lua sources parsing, manifest contents, and Git object blob checks. In-game screenshots supported the accepted visual appearance in several tested scenarios, but **do not establish universal combat-taint safety**, every UI scale, Battleground class evidence, or behavior after all client transitions.

## 26. Current synchronized source: 0.2.197-local (2026-10-14)

### 26.1 Provenance and atomic source boundary

This chapter describes the source in the **exact** `bjarkiUI-0.2.197-local.zip` supplied during the 2026-10-13 Forever UI work. ZIP SHA-256:
`c3074d15fc74ebf5c84cd5ff5ee7cd0a406b5d1eeb743e50da72460fd03c774c`.
The prior `main` head was `5138ac6cb36b1d1cfb1d6ed0afc617a4c1af99d7` at `0.2.156-local`. The intervening `0.2.157–0.2.196` artifacts were iterative **local** builds, not a claim of GitHub history. The synchronization imports their cumulative *accepted candidate* as-is, not a reconstruction from chat descriptions.

Module load order in both TOCs (Interface `16001`):
1. `bjarkiUI.lua` — primary unit-frame and PRD presentation;
2. `PartyOrder.lua` — visual compact-party ordering;
3. `SoftDark.lua` — fixed decorative-theme layer;
4. `TrackedBuffSeconds.lua` — tracked buff cooldown-number presentation;
5. `NameplateTimers.lua` — native nameplate aura countdown font.

`PartyOrder.lua` is byte-identical to the prior repository blob (`6f51134ffdbdaaf77ef8b6a833fcff7018d377a8`). Added repository source files are `SoftDark.lua`, `TrackedBuffSeconds.lua`, `NameplateTimers.lua`, and the bundled `EditMode-0.2.181.txt`. That layout file name records the original preset revision; its **contents** exactly match the `0.2.197` embedded layout and are not proof the code reverted to `.181`.

### 26.2 Ownership and non-implication boundaries

The addon owns **presentation**, not combat state, player identity, aura state, protected unit assignments, or Blizzard's rendering lifecycle. Successful access to a value does not by itself authorize assigning class identity, editing protected geometry, or altering an unrelated system. The modules obey different ownership contracts:

| Module | Owned outputs | Native/engine-owned inputs | Gate / fallback |
| --- | --- | --- | --- |
| Core `bjarkiUI.lua` | bounded color, text, atlas and known-frame presentation; one extra speed row | unit identities, resource values, frame geometry, protected values | guarded readability, recognized native layout, out-of-combat layout work |
| `PartyOrder.lua` | visual anchor order for compact PARTY frames | unit assignments, secure refresh and roster membership | next-tick scheduling, readable unit tokens, out-of-combat intent |
| `SoftDark.lua` | decorative texture vertex colors and partial desaturation | icon imagery, cooldowns, class-colored fills, button geometry | fixed 60% preset, saved original appearance, deferred combat work |
| `TrackedBuffSeconds.lua` | native cooldown style threshold | spell/aura durations and icon recycling | `Cooldown:SetCountdownMillisecondsThreshold(0)` on BuffIcon viewer only |
| `NameplateTimers.lua` | nameplate-aura countdown font | aura time, stacks, portraits, unit-frame data | native countdown font object with guarded FontString fallback |

Unknown or secret evidence must not silently be treated as permission. A `pcall` success is an API result, not proof of combat-taint freedom or correct visible pixels. Retain the existing `KNOWN_ISSUES.md` as open evidence for opposing-faction class colors and ToT/ToF identity unless fresh in-game tests close those observations.

### 26.3 Core frame and color behavior

Six handled units are `player`, `target`, `focus`, `targettarget`, `focustarget`, and `pet`. Owned unit-frame bar fills use the neutral `UI-HUD-CoolDownManager-Bar` texture; Blizzard keeps the native status values, masks and unit assignment. The addon resolves positively readable player/class/pet/reaction/tap-denied information before choosing its fallback color; inaccessible identity must not be replaced with a guess. Player class colors use native `RAID_CLASS_COLORS` or guarded `C_ClassColor`; combat pets use familiar pure green; Mana is PRD-like blue `(0.10,0.25,1.00)`.

ToT/ToF preserve the known compact layout: ToT health height 10, ToF health height 10.25, both Mana bars attached at `Y=0` to their corresponding health bars. A clipped, mouse-transparent copy of their native `FrameTexture` is layered above the fills but below the name area. This duplicate chrome is a **visual intervention**, not an independent native feature; do not confuse it with a second health/resource bar. Live diagnostic `/bui compact` reported `gapUI=0.000` on both at scale 0.825. Hiding the added copy did not remove the visible hairline separator, so further whole-frame or Mana Y-offset hunts remain unjustified without new evidence. Temporary `/bui compact chrome on|off` is a session-only diagnostic; the default is ON.

### 26.4 PRD speedometer: secret-compatible native bar

The added fourth PRD-style row is an ordinary, mouse-transparent child of `PersonalResourceDisplayFrame`, anchored below Blizzard's native bar stack. Its text and green fill show instantaneous speed relative to `BASE_MOVEMENT_SPEED`: idle/rooted `0%`, normal movement `100%`, speed-boosting effects above `100%`. The bar is scaled to **200% maximum** (higher text may continue while fill is capped). The row uses a native `StatusBar:SetValue` rather than addon arithmetic on combat-secret numbers; when `GetUnitSpeed` yields a secret, a guarded `AbbreviateNumbers` path formats the label for native `SetText`.

The row refreshes at `0.03` seconds (30 ms) only while the row updates. The display uses `UI-HUD-CoolDownManager-Bar` with green `(0.18,0.68,0.24)`; its background atlas is drawn at `BACKGROUND` layer below, not above, the fill. This fixed an observed nonnative dark inner overlay. Keep calibrated bar and text anchors independent of the native PRD frame's protected geometry. The implementation was visually iterated in play, but not certified for all forms, buffs, API secrecy policies or UI scales.

### 26.5 Soft Dark: fixed presentation preset and verified bag hierarchy

Soft Dark is **one automatic preset**: `SOFT_DARK_BRIGHTNESS=0.60`. Old per-character brightness, bag tint and atlas comparison settings are cleared on the fixed-preset revision. Ordinary use requires no chat commands. Only emergency ON/OFF and read-only audits remain for troubleshooting. If the full `DarkMode` addon is loaded, this theme refuses concurrent recoloring. Combat-delayed work retries at supported lifecycle boundaries; there is no theme-specific per-frame poll.

Original vertex colors are stored in a weak-keyed map, and original bag-texture desaturation is stored separately. Repeated repaints derive their output from these originals rather than repeatedly multiplying an already-dark texture. Soft Dark OFF restores both channels. Tinting stays on identified decorative textures, not spell/item icons, portrait pictures, name text, native bar fill values or cooldown sweeps.

The bag experiment is an unusually well-scoped client observation. Hiding regular `CharacterBag0Slot`–`3Slot` buttons did **not** remove the gold triangular seams; hiding `BagsBar` did. Hiding only the non-button sibling frames of `BagsBar`, while retaining `BagSlotCluster` and clickable buttons, **did** remove them. The live hierarchy exposed **seven unnamed sibling frames**; `0.2.195` proved that 27 textures across seven frames were reachable. `0.2.197` retains these frames, uses partial desaturation (`0.55`) plus a fixed warm-charcoal tint, and leaves bag slots significantly less dark than the rejected `0.32` multiplier builds. The seven-frame equality guard intentionally fails closed when the native client structure changes. **Exact visual parity after `.197` is not yet verified.**

Other Soft Dark targets include action-bar chrome, individually reachable normal/slot art, 33 pooled action-bar dividers observed in diagnostics, named window chrome, PRD background/border atlases, and both native and clipped ToT/ToF chrome textures. Counts are diagnostic observations, not universal frame coverage guarantees. Unrecognized textures are skipped rather than automatically darkening arbitrary frame descendants.

### 26.6 Timers and selected Edit Mode layout

`TrackedBuffSeconds.lua` affects only `BuffIconCooldownViewer` cooldown style: `SetCountdownMillisecondsThreshold(0)` requests integer seconds. It does not change the Blizzard cast-bar timer, essential/utility cooldowns, buff stacks or aura time data.

`NameplateTimers.lua` only modifies Blizzard nameplate aura **countdown FontStrings**, not aura stacks or bjarkiPortraits portrait timers. It caches native font objects and guards its post-`SetAura`/post-`RefreshList` pooled refresh paths. Code default is 11 pt; the user selected **13 pt** in persistent per-character settings. `/bui nameplates` is optional adjustment/diagnostic, not a required configuration step. The actual FontString is rechecked after applying the font rather than assuming a successful API call implies visible success.

The embedded Edit Mode preset is installed only if absent. Existing `bjarkiUI` layouts receive **one-time migrations of recognized old coordinates**, with saved-layout rollback after a failed write and unrelated player changes preserved. Current intended coordinates include Player Y=`-159.0`, Target Y=`-160.0`, and Tracked Buffs X=`152.0`. Tracked Buffs is serialized as `20 2`; earlier adjustments to `20 0` mistakenly targeted Essential Cooldowns and were reversed. Do not silently overwrite an existing player's custom layout or use an inferred cooldown viewer index without checking the exported entry.

### 26.7 Party ordering, observed risk, and release discipline

`PartyOrder.lua` rearranges only the **visual** compact PARTY frame anchors (party1 through party4, player last), deferring reanchors after native `RefreshMembers`/layout callbacks. It avoids `SetFlowSortFunction` because that path previously re-entered Blizzard's native protected refresh from addon-tainted code. Unit tokens are read live; on unknown tokens the reorder returns without guessing.

**Open P1 hardening finding (not silently patched in the `.197` source sync):** `PartyOrder.lua` currently defines `inCombat()` as `safeBool(InCombatLockdown) == true`. When the query fails, is secret, or has an unsupported type, `safeBool` returns `nil` and the condition evaluates **false**, permitting a visual reanchor attempt under *unknown* combat authorization. A future individually tested patch should require `safeBool(InCombatLockdown) == false` before doing protected anchor work, preserving the otherwise accepted player-last ordering. This is a code-level entitlement gap, not proof that an error has already occurred in live play.

### 26.8 Verification record and what remains open

**Checked at source sync:** `0.2.197` archive integrity; complete file extraction; byte equality between extracted files and the release ZIP; both manifest load orders; embedded versus bundled Edit Mode layout equality; syntax compilation of all five Lua modules through liblua **5.4**; matching GitHub blobs for every synchronized source file. No package-source modernization, UI re-layout, icon changes, or behavior-changing hardening was introduced during repository reconciliation.

**Not established:** zero taint in all combat transitions; compatibility with every future Forever build; class colors under all hostile BG secrets; dynamic ToT/ToF frame scale changes; every nameplate pool/cooldown mode; visual identity between bag chrome and Action Bar 1 following the final warm-charcoal `.197` preset. The local screenshots and in-game commands in prior work are **scope-limited evidence**, not universal proof.

**Maintenance protocol:** Keep behavioral patches separate from release-source syncing, test the *specific native owner and draw layer*, use reversible out-of-combat probes, compare pixels at the same UI scale, preserve a known-good ZIP, and check both the written API result and actual visible rendering. Prefer narrow post-write hooks and snapshot-based restoration to broad frame scans or cumulative tint/geometry adjustments.

### 26.9 CI packaging is part of the runtime contract

The previous `.github/workflows/package-addon.yml` was still hard-coded to copy only `bjarkiUI.lua`, `PartyOrder.lua`, and the two TOCs. A green GitHub Actions result therefore produced an **incomplete** post-`0.2.156` addon: `SoftDark.lua`, `TrackedBuffSeconds.lua`, and `NameplateTimers.lua` were missing from its packaged artifact.

The packaging workflow now parses both TOCs, requires identical nonempty module lists, verifies that each referenced file exists, stages exactly those modules plus the manifests (and the optional edit-layout reference file), then emits SHA-256 checksums. Its success means the artifact is *complete relative to the TOCs*; it does **not** independently prove WoW compatibility, zero taint, or visual quality. New modules must be added to both TOCs; no future release should rely on an obsolete manual `cp` list.

## 27. Current synchronized source: 0.2.203-local (2026-10-15)

### 27.1 Provenance and source synchronization

- Source: the user-tested `bjarkiUI-0.2.203-local.zip`; archive SHA-256 `1e6076ab2efb175f6a74c2cbcc91603c8a7b347d9d6fdd057570f111ae4eea18`.
- Both manifests declare the same five runtime modules (`bjarkiUI.lua`, `PartyOrder.lua`, `SoftDark.lua`, `TrackedBuffSeconds.lua`, `NameplateTimers.lua`). The named `EditMode-0.2.181.txt` preset remains a separately bundled asset; its version in the filename is historical, not the addon version.
- Changes relative to the prior synchronized `0.2.197` snapshot are limited to `bjarkiUI.lua`, `SoftDark.lua`, and the two manifests. `PartyOrder.lua`, `NameplateTimers.lua`, `TrackedBuffSeconds.lua`, and the Edit Mode asset were verified byte-identical; no broad rewrite.
- This synchronization deliberately retains the `0.2.201` event-driven PRD geometry path rather than the transient `0.2.202` 150 ms geometry polling experiment. `0.2.203` adds only bounded presentation backing to the later `0.2.201` baseline.

### 27.2 Soft Dark: correctly owned Forever artwork

- The user-verified circular faction/PvP badge treatment targets **the backdrop only**: `PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.PvpBackgroundCircle`, `TargetFrame.TargetFrameContent.TargetFrameContentContextual.PvpBackgroundCircle`, and the equivalent FocusFrame path. The separate `PvpBackgroundIcon` faction symbol is left unchanged. The prior retail `PVPIcon` / prestige paths and old global `PlayerPVPIcon` names did not correspond to the visible Forever badges.
- The native minimap day/night orb has a separate cycle-rim atlas. Soft Dark tints the bounded rim texture, not the sun/moon disc; this and the faction circle were positively evaluated in the client after the earlier failed paths.
- The preset is fixed at 60% brightness with no routine per-bag, per-element, or brightness configuration. Bounded bag-chrome discovery includes seven identified non-button sibling frames; darkening is restored on Soft Dark OFF and must remain safe through Edit Mode and combat deferral. These stages are **presentation** operations, not permission to change secure unit state.

### 27.3 PRD speedometer and native presentation

- The fourth row is an addon-owned `StatusBar` child of Blizzard's PRD. It inherits frame position, scale, and visibility; width/height are synchronized on recognized layout/lifecycle events rather than via the discarded constant geometry polling. No claimed support for arbitrary unsignaled third-party resizing.
- Speed is sampled every 30 ms for the text/bar readout; the native status-bar API and a formatter are used when current speed may be secret. The 200% fill cap means values above 200%, including observed 433–434% Gryphon speed, saturate the fill while the displayed percentage keeps increasing. The right-hand fill extent was adjusted in `0.2.201` and visually accepted against native PRD bars.
- `0.2.203` adds a one-time 25%-alpha black `BACKGROUND` sublevel -7 track backing inset one UI unit, for player, target, focus, ToT, ToF, and PRD (including the speed row). This does **not** add full-frame black panels, resize native bars, or add a poller. The player's health and partially empty mana presentation received positive visual feedback; comprehensive target/focus/ToT/ToF/PRD testing remains open.
- Native bar artwork can mask a backing drawn below it: an installed texture is not, by itself, proof of an observable effect under all client background/alpha combinations. Preserve the demonstrated player-frame rendering; do not automatically increase alpha.

### 27.4 Verification boundaries and open work

- Source blob and ZIP integrity checks establish exact source provenance, not zero runtime taint. The Forever client's protected values and secure update paths still determine what may be inspected or modified.
- The unresolved older `PartyOrder.lua` fail-open combat-guard concern persists, because the synced `0.2.203` release intentionally preserves that module unchanged. Keep the risk explicit rather than silently patching unrelated runtime behavior.
- The ToT/ToF apparent health-resource separator was measured at `gapUI=0` and did not disappear when the optional extra chrome was toggled. Do not change bar geometry without new evidence.
- The repeated bag-divider experiments establish texture ownership only for the tested Forever hierarchy. Future client changes should fail closed, not trigger broad UI-tree recoloring.
- Positive screenshots for the faction circles, minimap cycle rim, PRD full-speed fill, and player low-mana track must not be overgeneralized to every client state, combat transition, or UI scale.


## 28. Edit Mode preset and party-order safety update: 0.2.204-local (2026-10-15)

### 28.1 Exact user-exported Edit Mode reference

The live Edit Mode share string supplied on 2026-10-15 is now copied byte-for-byte (apart from the final newline) into the bundled `EditMode-0.2.181.txt` reference and the embedded `EDIT_MODE_LAYOUT_STRING` in `bjarkiUI.lua`. The reference filename and `EDIT_MODE_PRESET_REVISION` retain the historical `.181` labels because neither the loader identity nor the migration contract changed. This update changes exactly five serialized tokens relative to `.203`: three opaque action/microbar metadata tokens, the `3 4` Y offset from `-0.0` to `-253.4`, and one opaque `21 -1` status entry. Their semantics are not inferred from the opaque flags.

The existing `bjarkiUI` Edit Mode layout is still installed **only when absent**. This does **not** forcibly replace a user's existing custom layout, nor does it perform a migration for the new `3 4` or opaque-field changes. The user's supplied share string already expresses the desired live layout; first-time installations receive it from the embedded preset. Future migrations require an explicitly scoped decision rather than a silent global rewrite.

### 28.2 Visual party sorting authorization

`PartyOrder.lua` now requires **readable out-of-combat (`InCombatLockdown == false`) and non-raid (`IsInRaid == false`) evidence** before it changes any compact-party member, pet, or border anchors. A missing, secret, failing, or otherwise unrecognized result denies reanchoring. The Edit Mode horizontal/vertical orientation must also be a readable boolean; UNKNOWN no longer becomes vertical by default. The callback remains next-tick coalesced; without the timer API it skips reanchoring rather than synchronously entering a native compact-frame hook.

The familiar party1–party4, then player visual order is unchanged when those conditions are readable. Unit assignments, secure native sorting, and unrelated party/raid settings remain Blizzard-owned.

### 28.3 Validation boundary

Source-side verification should include the five-token share-string diff, matching embedded/reference layouts, both `.toc` module lists, syntax compilation of all five Lua modules, and mocked combat/raid/orientation/queue paths. Real client behavior, especially Edit Mode, party grouping, and combat transitions, must be retested before claiming runtime safety. This is a focused edit: no health/power colors, typography, Soft Dark materials, PRD geometry, or portrait-aura logic were modified.

## 29. Four-module release and micro-menu pip preservation: 0.2.206-local (2026-10-15)

### 29.1 NameplateTimers removed completely

The player preferred Blizzard's native nameplate aura countdown size to a separate custom 13/14 pt intervention. The four runtime modules are now exactly `bjarkiUI.lua`, `PartyOrder.lua`, `SoftDark.lua`, and `TrackedBuffSeconds.lua` in both the regular and Camelot manifests. `NameplateTimers.lua` was removed from the repository and the shipped ZIP. This also removes the `/bui nameplates` override and the associated nameplate-aura SetAura/RefreshList hooks. Ordinary class-color/nameplate presentation in `bjarkiUI.lua` and integer-second **tracked buffs** in `TrackedBuffSeconds.lua` are unaffected.

A previously stored `bjarkiUISettings.nameplateTimerFontSize` can remain in the per-character SavedVariables table but is inert: no loaded source references or consumes it. The cleanup does not modify unrelated SavedVariables or Edit Mode layout.

### 29.2 Previously local-only 0.2.205 micro-menu change now synchronized

Version `0.2.205-local` was distributed as a local ZIP without updating GitHub `main`. Its changed code broadens overlay-only notification pip suppression to recognized Legacy, Guild, Help, and Game Menu microbuttons. The synchronization of `0.2.206-local` deliberately includes the exact preceding local `0.2.205` microbutton code (with only the version constant changing) so those changes are not lost. The action buttons and click behavior remain Blizzard-owned; successful suppression of every Forever notification artwork variant still requires a live client test.

### 29.3 Verification boundary

Both manifests declare the same four Lua files. All four passed Lua 5.4 syntax compilation and the installation ZIP contains no NameplateTimers module. The packed Edit Mode reference and the remaining modules `PartyOrder.lua`, `SoftDark.lua`, and `TrackedBuffSeconds.lua` are unchanged from `0.2.205-local`. GitHub source blob parity with the release archive, packaging completeness, and in-game behavior are independent checks; successful compilation and packaging do not imply tested combat taint safety.

## 30. Forever 1.60.1 post-patch synchronization: 0.2.220-macro-labels-test (2026-10-17)

This commit promotes the **exact tested local 0.2.220 runtime ZIP** from the local-only 0.2.207–0.2.220 experimentation series directly onto GitHub `main`. Intermediate local versions are not retroactively represented as public commits. The four runtime Lua modules and both TOCs, plus the embedded Edit Mode reference, must match the accepted `bjarkiUI-0.2.220-hide-macro-text-test.zip` byte-for-byte. This synchronization edits no packaged runtime content beyond the tested snapshot.

### 30.1 Blizzard-owned native unit-frame presentation

- The 1.60.1 native frame redesign superseded the old custom bar-height, mask, black-backing, and texture adjustments. `bjarkiUI` keeps **native frame art and bar geometry** while class-coloring native player health fills (including Target/Focus/ToT/ToF), matching appropriate NPC nameplate/reaction colors when readable, and leaving pet treatments native.
- The accepted post-patch exceptions are the horizontal compact Target-of-Target/Focus-of-Target alignment, Target frame placement, Player hit-feedback above the separate PRD, level-indicator treatment, targeted status-text optical anchors and subdued/rested highlight treatment. Native name text, portrait ring and most threat/healing animations remain Blizzard-owned. No PRD-style replacement bars or historical unit-frame resizes return.
- Class, reaction, nameplate and relationship information can become inaccessible or rewritten after combat/duels. The class-color repair and `/bui colors` diagnostics are evidence-gated; unreadable classification must not be replaced by a remembered guess. A historical green Focus frame after a duel is not, by itself, proof of repair in all conditions.
- Separate PRD and speedometer remain in their existing visual state, including the event/throttle design and native scaling ownership. `bjarkiPortraits` owns the aura images/timers; unit-frame changes must not rework their calibration.

### 30.2 Compact circle alignment and Edit Mode

- Target-of-Target and Focus-of-Target are moved as **whole compact frames** horizontally to center their visible circular bezels beneath their parent portraits. The 0.2.217/0.2.218 optical corrections are scale-aware and non-cumulative; their internal bars, names, scale and vertical placement stay native. Aura artwork and countdown centering within the circle are exclusively `bjarkiPortraits` concerns.
- The installed Edit Mode share string is the user's finalized 2026-10-17 export, stored identically in `bjarkiUI.lua` and `EditMode-0.2.181.txt`. The Target preset is `-292.5, -161`, and the party stack's final narrow width is stored without additional nudges. Serialized opaque flags must be preserved rather than inferred or reformatted.
- The preset remains **install-if-absent**: users with existing SavedVariables/layouts are not silently reset or migrated. Preserve `PartyOrder.lua`'s fail-closed combat and raid restrictions, and do not infer protected party sorting or edit-mode safe writes from screenshot alignment alone.

### 30.3 Other presentation changes and module scope

- Soft Dark remains active for eligible non-unit-frame elements, while quest/gossip paper stays readable and the flight-map frame chrome receives the intended dark treatment. New borderless faction glyphs are excluded from old circle-darkening. The minimap day/night `MinimapCluster.DielFrame` disc/rim is suppressed as an entire decorative control; unrelated minimap clock, tracking and calendar behavior remain Blizzard-owned.
- The post-patch action-bar macro-caption option in 0.2.220 suppresses **only the `Name` FontStrings** on the standard Blizzard action buttons. Hotkeys, charge/stack counts, cooldown numbers, icons, tooltips and click actions remain intact. Reapply only at addon load and permitted lifecycle/Edit Mode points; no per-frame poller or macro rewriting is installed.
- The four modules in both manifest files are `bjarkiUI.lua`, `PartyOrder.lua`, `SoftDark.lua`, `TrackedBuffSeconds.lua`. `NameplateTimers.lua` remains retired. The tracked buff countdown presentation stays separate from the ActionBar macro label change.

### 30.4 Verification and unresolved behavior

- The local 0.2.220 candidate compiled as four Lua modules and passed focused macro-caption tests, plus retained form-state checks performed in the paired test run. Several historical assertions fail **also on the unchanged 0.2.219 baseline**, so do not advertise the historical aggregate as wholly passing. Git blob/ZIP byte parity, compiler checks, and live WoW rendering/taint proof are distinct evidence classes.
- Live screenshot comparisons support the selected post-patch optical positioning and native bar usage; they do not settle every PvP/instance/Focus/aggro/nameplate behavior. Track remaining open observations in `KNOWN_ISSUES.md` until current-client reproductions or narrow negative tests close them.

## 31. Verified foundation synchronization: 0.2.246-foundation-v15-fixes-test (2026-10-22)

The four Lua modules, both TOCs and `EditMode-0.2.233.txt` match the verified v15 suite byte-for-byte. The prior repository source was `0.2.220-macro-labels-test` at `f011180c33d64624b0c1be7f74b155d80e32f451`; this synchronization imports the intervening accepted source directly. Relative to the verified v14 UI, v15 changes only the version constant and TOC versions. The v15 behavioral repairs belong to `bjarkiCC`.

### 31.1 Current presentation and ownership

- Native unit-frame artwork and geometry remain the baseline. Full names, including surnames, use Blizzard's `GetUnitName`; the old chat, Communities, compact-frame and Damage Meter name-shortening hooks and `/bui names` diagnostic are removed. Unit-frame and nameplate labels receive class colors only through current player or supported pet/totem-owner evidence.
- Player, Target and Focus percentage-only status labels use guarded one-decimal formatting after the native text writer. Native zero, hidden, paused and two-column modes remain native; inaccessible inputs do not authorize Lua arithmetic. The earlier unit-frame and PRD status-text anchor overrides are removed.
- An unreadable native health-color write invalidates the old readable snapshot. Fallback restores native artwork without repainting an obsolete color; deferred primary repairs recheck the current binding and class evidence. Derived native updates avoid redundant color passes.
- Incoming hit feedback is anchored above the Player health bar. The old UI error-stack relocation and icon-only Loss of Control treatment are removed. The active fourth PRD speed bar is replaced by dormant, independent speed text: `SPEED_TEXT_ENABLED = false` creates no display or polling loop. Native PRD track backings and alternate-Mana treatment remain.
- Party ordering is vertical-only, requires readable out-of-combat/non-raid/orientation evidence and coalesces repairs to the next tick. Horizontal member, pet and border anchors remain native. Separate connection-event registrations cover all five supported tokens. Soft Dark coalesces an eligible addon-load burst into its immediate pass plus one deferred pass. `TrackedBuffSeconds.lua` is unchanged from the prior repository.

### 31.2 Edit Mode and packaging

The embedded preset exactly matches `EditMode-0.2.233.txt`. On first application of revision `bjarkiUI-layout-0.2.233`, an existing named `bjarkiUI` layout receives a **one-time full replacement of its systems**, preserving its layout identity and list position. A failed save restores the original systems; later player edits are left alone once the revision is recorded. This supersedes the older install-if-absent and recognized-coordinate-only migration descriptions. An absent layout is still installed through the existing creation path.

`EditMode-0.2.181.txt` remains a historical repository reference; it is not the current embedded preset or packaged layout. The packaging workflow now stages `.233`, together with the four TOC-declared modules and matching manifests, and records their SHA-256 checksums. Repository documentation remains outside the addon load list.

### 31.3 Verification boundary

The source has exact v15 runtime parity, matching manifests and embedded/reference layout, four Lua 5.4 syntax checks, and local execution of the repository's packaging validation. The verified suite also exercises modeled native-color restoration, delayed primary repair, party gates, Soft Dark lifecycle and tracked-buff iteration. These checks do not establish native-client taint safety, every secrecy transition or rendered appearance; the historical client observations in `KNOWN_ISSUES.md` remain open.

## 32. Layout-neutral release: 0.2.248-foundation-v16-layout-neutral (2026-10-23)

- Delete both formerly bundled `EditMode-0.2.181.txt` and `EditMode-0.2.233.txt` references from the repository. Remove the embedded share string, the named `bjarkiUI` preset, its revision gate and all `C_EditMode` layout-write or activation calls.
- Neither a fresh install nor an upgrade creates or changes any player-saved Edit Mode layout. A previous release may already have altered a layout; this version deliberately does **not** try to undo it, delete it, or clear unrelated per-character settings.
- Keep `EDIT_MODE_LAYOUTS_UPDATED` and out-of-combat layout-responsive presentation (e.g. micro-menu child offset, ToT/ToF optical alignment, combat text). These adjust specific runtime visuals without persisting layout systems.
- `/bui tracked` is read-only and reports the current active layout name, native Tracked Buffs viewer index and live offset; it has no baked-in `bjarkiUI` layout or coordinate expectations.
- Packaging stages only the two manifests and their four declared Lua modules, with SHA-256 checksums; a guard rejects future bundled preset files or known native layout-write calls. No historical Edit Mode text file is shipped.
- This scope is source/packaging hygiene; it does not establish additional in-client rendering, combat or taint guarantees.

## 33. Native hook, nameplate, compact border and CI hardening: 0.2.249-foundation-v16-hardening-test (2026-10-25)

- A classic nameplate CC/LoC anchor correction now requires readable `IsForbidden() == false` for the owning frame, anchor texture and destination list; unknown list protection denies the write, and confirmed protected lists require confirmed out-of-combat state. Native anchoring remains in effect if permissions are inaccessible.
- Public compact debuff-border suppression saves each qualifying texture's readable original alpha in weak-key state. On reuse outside compact frames it restores that value **only if the border still reads as hidden**. If a native writer already supplied nonzero alpha, the addon discards its snapshot instead of overriding the native value. Repeated compact updates retain the original alpha unless a new native nonzero write is observed.
- Three native presentation post-hooks (`UnitFrameHealthBar_Update`, `UnitFrame_Update`, `CompactUnitFrame_UpdateHealthColor`) now register independently. Missing or failed installations retry at Blizzard `ADDON_LOADED` and world-entry boundaries; successful hooks are not duplicated. One-time threat/resting setup stays one-time. The derived-health path also avoids evaluating secret lock flags as Lua booleans.
- `/bui audit` exposes read-only native hook installation states. This release does not introduce native frame refresh calls or new polling loops.
- GitHub Actions compiles all four TOC-declared Lua modules and the regression test with Lua 5.1 and 5.4, then runs extracted-production-code mock scenarios for nameplate permission gates, pooled border restoration, and late native hook availability/failure/duplicate avoidance. Offline mocks and compilation are not a substitute for live Forever taint tests.
- No serialized Edit Mode preset, layout creation, replacement, migration, or activation is reintroduced. PartyOrder, SoftDark, TrackedBuffSeconds, and all client CVar behavior are unchanged.

## 34. Lifecycle and failure-recovery repairs: 0.2.250-foundation-v16-lifecycle-repair-test (2026-10-25)

- Micro-menu notification overlays are hidden on every qualifying native refresh, not only on first discovery. Successful hook installations remain deduplicated; failed registrations are retried.
- `PartyOrder.lua` records successful global, `RefreshMembers`, direct `UpdateLayout`, and cached `updateLayoutFunc` hooks independently. Late native initialization can no longer permanently skip a hook. Failed deferred scheduling clears the pending flag without entering a protected refresh synchronously.
- Main and party secrecy probes treat failed or unrecognized results as unreadable when `issecretvalue` exists; older clients without the API retain compatibility behavior.
- Class-color set/restore pathways clear their recursion guards after unexpected native API failures, preserving restoration retry state on an uncaught getter exception. Native unit-frame geometry and class-color selection remain unchanged.
- Retry nameplate class-name hook installation when `Blizzard_CompactUnitFrame` becomes available after login. No new polling or layout-management code is introduced.
- `tests/lifecycle.lua` adds source-backed mocked regressions in both Lua 5.1 and 5.4, alongside the existing hardening tests. GitHub CI compiles both tests and the four runtime modules.
- Native alpha-zero reuse, recycled name-color ownership, and Battleground secrecy transitions remain **client-dependent/unverified**. No speculative hooks or ownership inference were introduced. The saved Edit Mode layout remains fully user-owned.

## 35. Prelaunch offline corrections: 0.2.251-foundation-v16-offline-fixes-test (2026-10-25)

- `TrackedBuffSeconds.lua` retains the entire native `EnumerateActive()` iterator triple through `pcall`; the existing whole-second formatting remains limited to Tracked Buff Icons. If an iterator becomes invalid during native recycling, the formatting attempt fails locally without aborting the viewer update.
- `PartyOrder.lua` preserves true/false/unknown visibility for visible member enumeration and Edit Mode previews. Unknown member visibility cancels the custom order. It preflights title height, border visibility, pet visibility and anchor methods before writing any member anchors, while keeping its vertical, out-of-combat/non-raid order.
- Derived class-color hooks, level-ring visibility hooks, individual level-text `Show`/`SetShown` hooks, name-backdrop hooks, native compact aura border hooks and micro-menu offset hook now record successful registration only. Failed registrations remain retryable at their existing lifecycle boundaries.
- Threat flash `SetVertexColor` post-hooks install before the initial alpha seed, so a failed registration cannot multiply the initial alpha repeatedly. The same owner-only hooks retry at world-entry/Edit Mode lifecycle boundaries without duplicate installation.
- Native health style restoration now reports individual atlas/desaturation/status-bar setter failures and preserves retry ownership after a partial restore. Its recursion guard remains cleared on all outcomes.
- Soft Dark registers Edit Mode Enter/Exit callbacks independently; an Exit failure no longer duplicates a successful Enter callback.
- `tests/presentation.lua` provides additional source-backed Lua 5.1/5.4 scenarios, including full Tracked Buff event/viewer iteration, PartyOrder no-write cases, restoration setter failure/retry, native hook partial success, and Soft Dark callback recovery. CI compiles all four modules plus all tests, then runs the three test scripts; tests are excluded from the shipped addon.
- No saved Edit Mode layout writer, periodic runtime poller, or additional CVar change is introduced. Existing speculative cases (pooled alpha-zero native ownership, native name-color snapshot replacement, Battleground secret identity transitions) remain deferred to client evidence.

## 36. Incoming player text and status precision: 0.2.252-foundation-v16-combat-text-test (2026-10-26)

- Incoming combat/heal feedback stays **horizontally centered on the native Player health bar**, but the feedback FontString's `BOTTOM` point is now anchored to the native `PlayerFrame` `TOP` with **2 physical screen pixels** of separation. The existing hit text, animation, font and Blizzard value production remain untouched. Guarded `GetCenter` and `GetEffectiveScale` measurements preserve its X position across UI scales while the PlayerFrame anchor follows normal Edit Mode moves. If geometry is secret/unreadable or the client is in combat, the addon leaves existing anchors untouched.
- Player, Target and Focus *percentage-only* health/resource labels now show **`100%`** for percent values at or above 100 and **one decimal below 100** (for example `99.9%`), without modifying other Blizzard status-text modes, zeros or paused updates. This also applies to displayed percentage prefixes.
- `AbbreviateNumbers` receives a descending 100/0 breakpoint configuration for secret-safe native precision selection. Lua performs no comparisons/arithmetic on opaque percentages. If that API is unavailable or fails on secret values, it leaves the previous native label alone. Readable values use matching bounded one-decimal truncation below 100 rather than rounding an incomplete bar up to `100.0%`.
- `tests/status-combat.lua` supplies native-style formatter, prefix, secret fallback, status-mode, physical pixel-gap, horizontal alignment, Edit Mode movement and forbidden-geometry mocks under both Lua 5.1 and 5.4. It is not packaged with the runtime modules.
- No saved Edit Mode preset/layout writer, new polling loop, CVar change, class-color rule, or unrelated geometry change is introduced. Native-client animation and screenshot-scale confirmation remain pending the Forever release.

## 37. Shop notification pip: 0.2.253-shop-pip-test (2026-10-26)

- Extend the existing bounded micro-menu notification selection to the Shop button's known `StoreMicroButton` / `ShopMicroButton` names and `store` / `shop` commands. Existing Guild, Help, Game Menu and Legacy handling is unchanged.
- Suppress only the button-owned `NotificationOverlay`. Existing `UpdateNotificationIcon` post-hook handling remains idempotent; Shop additionally observes the same overlay's native `Show` and `SetShown` writers to re-hide a pip without touching the actual button, its icon, tooltip, click action, or anchoring. A global Store/Shop button lookup covers clients where it is not a direct `MicroMenu` child.
- Registration success is tracked independently with weak-key tables; failures can retry at existing lifecycle boundaries, without polling or new saved variables. `tests/lifecycle.lua` covers exact Shop identification, unrelated buttons, native pip reshow, partial hook failures, and Shop button interaction under Lua 5.1/5.4.
- The login/character-selection screen loads before ordinary per-character UI addons. No unsupported login-frame manipulation is attempted; the character-select Shop marker remains client-owned.

## 38. Native Player colors and restrained status-text shadows: 0.2.254-native-player-shadow-text-test (2026-10-26)

- The Player frame is no longer class tinted by bjarkiUI: `applyHealthColor("player")` declines all writes and `applyUnit("player")` retains full-name correction and numerical styling, but does not install the class health-color hooks or tint its name. `applyClassNameColor("player")` also declines external calls. **Blizzard owns Player health fill and Player name colors.** Target, Focus, ToT and FoT retain their existing class/NPC-color decisions, race portraits, bars, and native frame geometry.
- Health/resource numeric FontStrings for Player, Target, Focus, ToT and FoT, plus the PRD's three native status bars, use the same restrained font treatment. Only known bar-owned `TextString`, `LeftText`, `RightText` and the lowercase left/right aliases are eligible. Name, level, aura, cooldown, cast, action-bar and combat text remain unchanged.
- Preserve native font file, point size, color and anchoring; remove only `OUTLINE`/`THICKOUTLINE` font flags and preserve independent flags such as `MONOCHROME`. Add black shadow alpha `0.78`, with offset `(+1, -1)` **physical screen pixel** when the text's effective scale is readable. No new font assets or glyph replacement.
- Native FontString `SetFont` post-hooks reapply the look only after a native font-template update and avoid recursion. A weak-key registry prevents duplicate hooks. Secret/unreadable or forbidden FontStrings fail closed; presentation changes are skipped in combat and retried at existing unit/world/edit-mode or `PLAYER_REGEN_ENABLED` events. No new `OnUpdate` loops or layout management.
- `tests/status-style.lua` exercises status-only field selection, outline flag removal, one-screen-pixel shadows, name/level exclusion, native font resets, combat/secret behavior, and Player/Target color boundaries under Lua 5.1 and 5.4. No test files are packaged.
- Native-client typography and scale-specific optical judgment still need launch screenshots. Existing unrelated CVar behavior, whole-second tracked buffs, incoming combat-text anchoring, soft dark, and saved Edit Mode layout ownership remain unchanged.

## 39. Native seconds below six minutes: 0.2.255-native-cooldown-seconds-test (2026-10-26)

- Apply only to existing Blizzard action button cooldown widgets: main/multi bars, pet, stance and possess buttons, including their native `cooldown`, `chargeCooldown`, and `lossOfControlCooldown` variants when actually exposed. Do not touch the portrait aura cooldowns, Tracked Buff Icon timers, bag items, ability IDs, state values or font sizes.
- Use **one** `C_StringUtil.CreateNumericRuleFormatter` with native `NumericRuleFormatter:SetBreakpoints`. Strictly below 360 seconds render integer seconds (e.g. `59`, `105`, `321`, `359`), rounding down consistently with the portrait timer policy. At/above 360 seconds use compact minute/hour/day labels (e.g. `6m`, `1h`, `2d`), rounding larger unit bands upward.
- Apply the formatter through `Cooldown:SetCountdownFormatter`; unlike `SetCountdownAbbrevThreshold`, this controls the actual countdown text and accepts secrecy-protected native times without passing those values through addon Lua. No custom `OnUpdate`, text replacement, duration arithmetic, or cooldown restarts.
- Restrict writes to positive, readable native cooldown objects outside combat. Use a weak-key installation cache, optional `GetCountdownFormatter` recheck, and existing lifecycle events: login, world entry, native action-bar load, Edit Mode and combat exit. Reuse action-bar button names already recognized by bjarkiUI; no continuous scan. When the native formatter API isn't available, **leave Blizzard formatting intact** rather than trying a secret-unsafe Lua replacement.
- `tests/cooldown-seconds.lua` verifies the real module with mocked native formatters and buttons under Lua 5.1/5.4: boundaries, secret/forbidden objects, charge/loss-of-control variants, normal/native replacement, independent failures, out-of-combat deferral, late-loaded bars and missing API. The tests are not packaged for the game.
- This release changes only countdown *presentation*. Blizzard continues to own action-button art, cooldown readiness, charge logic, swipe, edge, color and countdown font. Exact 1.60.1 implementation support and visual size must be checked on the Forever launch client.

## 40. Native action-button decimals below five seconds: 0.2.256-five-second-decimals-test (2026-10-26)

- Reuse the single `CooldownSeconds.lua` native `NumericRuleFormatter`, adding `threshold = 0, format = "%.1f"` and moving the previous integer-second rule to `threshold = 5`. The six-minute, one-hour and one-day rules retain their previous thresholds, rounding policies and formats.
- Example outputs: `4.9 → 4.9`, `5 → 5`, `59 → 59`, `105 → 105`, `321 → 321`, `360 → 6m`. The formatter, not Lua, decides which rule applies to secrecy-protected countdown values. The sub-five-second `%.1f` rule follows the familiar native one-decimal rounding behavior, with no custom per-tick update.
- `tests/cooldown-seconds.lua` asserts the exact 5-second transition and the unchanged 360/3600/86400-second transitions under Lua 5.1 and 5.4. All other addon modules, countdown eligibility guards and saved-layout policy remain unchanged.
- Native 1.60.1 support for `SetCountdownFormatter` and the precise rendered font appearance still require live-client verification.

## 41. Status-shadow scale and Soft Dark restoration: 0.2.257-presentation-recovery-test (2026-10-27)

- Status-font presentation now includes readable effective scale in its cache dependencies. Existing unit/Edit Mode refreshes can correct a changed scale even without a native `SetFont` call. Successful styling records the scale; failed writes remain retryable. Unknown/missing scale retains the previous one-UI-unit compatibility fallback.
- `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` refresh only the owned numeric unit/PRD fonts. Unchanged scale avoids redundant styling and hooks. Combat still defers writes until the existing regeneration path; there is no polling or new frame timer.
- Soft Dark retires each saved vertex-color or desaturation value only after the corresponding restoration call succeeds. Exceptions and unreadable objects keep their original values in existing weak-key storage for a later explicit/lifecycle retry. A failed OFF followed directly by ON therefore keeps the true baseline and does not compound the tint.
- Whole-theme restoration attempts each property once per pass, independently of the bag-sibling subset. Temporary sibling restoration retains retry membership while either property remains unrestored. Successful nil-return native setters remain successful.
- `tests/status-scale.lua` covers scale changes, relevant event routing, unchanged-scale no-churn, combat/native-font resets, unknown scale and setter retries. `tests/softdark-restore.lua` loads the full module to cover failed OFF/retry/ON, independent tint/saturation failures, unreadable textures, sibling lifecycle paths, combat deferral, normal toggles and weak-key collection. Both run in Lua 5.1 and Lua 5.4 alongside the six unchanged original scripts.
- Offline regressions compare against `0.2.256-five-second-decimals-test` at `0003cc3bbe3c4a9a80ece12ba3057384a51ef494`. Actual native scale-event order, protected setter availability, rendering and taint still need in-game verification. Late DarkMode ownership, anonymous bag discovery and other conditional audit gaps are not claimed resolved.

## 42. Incoming Player hit-text lifecycle: 0.2.258-hit-text-recovery-test (2026-10-27)

- The existing `anchorCombatText()` helper now also runs from `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED` and `PLAYER_REGEN_ENABLED`. Scaling can no longer leave its stored UI-unit gap based on an obsolete effective scale; login/world/layout updates skipped in combat can recover when combat ends.
- The helper still performs no geometry writes unless combat state is readably false and all required centers/scales are readable, finite and valid. Each invocation resolves current frame, bar and text objects and measures current geometry. The two-screen-pixel vertical gap and health-bar horizontal centering formula are unchanged.
- Existing status-font scale refresh remains in the same event branch. Scale/display events now update both affected presentation paths without invoking unrelated class-color/layout work. There is no timer, polling loop, extra saved state, dependency or new event registration.
- `tests/hit-text-lifecycle.lua` loads the full main module and drives its actual event handlers, including scale changes, combat reload/exit, deferred geometry, unreadable geometry and recovery. The existing status-scale fixture explicitly permits the new hit-text call while continuing to reject unrelated work and check status-font behavior.
- The other runtime modules, including the 0.2.257 SoftDark restoration repair, remain unchanged. The seven other existing test scripts are preserved. All nine scripts run under Lua 5.1 and Lua 5.4 in the package workflow.
- Verification is against the exact delivered `0.2.257-presentation-recovery-test` ZIP. Native rendering, scale-event timing, protected setters, taint and live performance still require an in-game smoke test. This remains a test build.

## 43. Optional write and callback-gap recovery: 0.2.259-recovery-test (2026-10-27)

- `anchorCombatText()` contains errors from both native positioning setters. A failed `ClearAllPoints` skips the dependent `SetPoint`; neither write failure aborts the remaining lifecycle work, including status-font recovery at combat exit. Successful nil-return setters remain successful. Existing combat/readability/geometry gates and two-physical-pixel positioning remain unchanged, and the next relevant event resolves current objects and geometry again.
- Soft Dark retains bounded evidence that Enter/Exit registration was incomplete. Once both callbacks are installed, a later existing repaint boundary may reconcile a missed Exit from a positively readable native `editModeActive == false`. Missing, secret, nonboolean or true manager state retains recovery. The boolean read preserves false, unlike the general child lookup helper.
- Delivered Enter/Exit callbacks remain authoritative under complete coverage. An Enter in an incomplete interval keeps the gap evidence, while a callback-phase guard prevents reentrant restoration/lifecycle work from treating callback-time native lag as a missed Exit. This temporary guard is restored even if restoration throws. A native true interval need not have been observed: a whole Enter/Exit cycle may have passed while Exit was unavailable.
- Recovery follows existing full-theme and bag Layout paths. Combat and the latest ON/OFF setting continue to gate painting; successful callback registrations are not repeated. Two bounded booleans are added; no polling, additional timer, event, saved setting or dependency is introduced.
- The recovery boundary intentionally treats a later independent native manager observation as current state. Arbitrarily delayed native state across separate lifecycle events cannot be distinguished from an entirely missed cycle using these inputs. Ordinary delivered events are not continually overridden by manager false. Actual Forever callback/state ordering still needs live-client validation.
- `tests/hit-text-write-recovery.lua` and `tests/softdark-callback-recovery.lua` exercise the complete affected modules with injected native API failures, retry and replacement controls, partial registration, manager uncertainty, callback ordering, reentry and combat. All nine preexisting regression scripts remain byte-identical. The package workflow compiles and runs all eleven scripts on Lua 5.1 and Lua 5.4.
- Verification compares against the exact delivered `0.2.258-hit-text-recovery-test` source, retains the original audit reproductions and independent review probes, and validates the packaged bytes. These are offline robustness repairs; native failure occurrence, protected-value enforcement, rendering, taint and frame-time behavior are not established by the tests.

## 44. Remaining audit repairs: 0.2.260-audit-fixes-test (2026-10-31)

- Threat/resting initialization tracks successful work independently and retries missing or rejected hooks at existing lifecycle boundaries. A failed optional hook no longer aborts later login work. Successful hooks and resting textures are reused. Late MicroMenu loading runs the existing offset installer; the accepted one-unit child offset is unchanged.
- Unit-frame name coloring tracks native color ownership across later writes instead of restoring a one-time snapshot over a newer native value. Addon writes are distinguished from external writes; unavailable evidence cannot revive a stale baseline. Pet/totem owner coloring requires positively readable nonplayer identity, including for nameplate callers.
- Soft Dark recognizes the exact supported bag-border atlas during anonymous nested discovery as well as during tinting. On a late DarkMode handoff, changed external properties are relinquished; only properties still demonstrably owned by Soft Dark are eligible for baseline restoration. Color and desaturation recovery remain independent.
- Party ordering snapshots readable points before mutation, contains positioning errors, and rolls back a failed visual pass. Failed rollback retains bounded recovery for existing lifecycle opportunities; current combat/layout and native supersession checks prevent stale geometry from being replayed indiscriminately. Native unit assignments and horizontal-party layouts remain untouched.
- Existing colors, intensity, geometry offsets, cooldown thresholds, Player color policy, saved layouts and dormant speed text are unchanged. No new polling or user setting is introduced.
- Four focused regression scripts join the eleven retained scripts. CI compiles every runtime/test Lua file and runs every regression under Lua 5.1 and Lua 5.4, including on pull requests. Fault-injected ordinary-Lua checks establish recovery behavior; live native rejection, protected values, rendering, event ordering and taint remain client-validation boundaries.

## 45. Dependency and ownership recovery: 0.2.261-recovery-test (2026-10-31)

- Party rollback separates clearing current anchors from rebuilding saved points, breaking the custom player-last chain before reconnecting native player-first dependencies. Failed restoration remains bounded to the current transaction and existing event opportunities, subject to the same native-supersession, geometry, identity, combat and orientation checks.
- Health styling requires a successfully installed per-bar native-color observer before preparing native artwork or applying tint. Missing/rejected registration leaves the current native material and color alone; a later retry captures the then-current baseline. The shared gate covers readable class/NPC colors and native protected-class transport. Derived repaint hooks register only after that observer succeeds, so native-color observation always precedes synchronous repaint or restoration across retries.
- Regression coverage adds native dependent anchors with cycle rejection and tests failed color tracking, current-baseline acquisition after retry, and subsequent native-color restoration. Successful nil-return native APIs remain supported. These fixtures exercise addon behavior, not the client's protected-value or taint implementation.
- All existing visual values, successful party order, Player native-color policy, saved layouts, dormant movement text and cooldown thresholds remain unchanged. No new event, polling loop, setting or dependency is introduced.

## 46. Decimals below ten seconds: 0.2.262-ten-second-decimals-test (2026-10-31)

- Action-button countdowns use one decimal strictly below ten seconds (`5 → 5.0`, `9.9 → 9.9`) and whole seconds rounded down from ten (`10 → 10`, `10.1 → 10`). The six-minute, hour and day format rules are unchanged.
- Only the native formatter breakpoint changes; timing, colors, fonts, swipes and tracked-buff formatting retain their existing behavior. The existing countdown regression covers the revised boundary.
