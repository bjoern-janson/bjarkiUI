# Native helpful-buff row: bounded design

Status: proposed architecture only; no runtime changes or client validation. Baseline: bjarkiUI `.357` (`c55db1c`); buff runtime remains unchanged in `.358`. Native references below use Forever commit `4cd0ab752a77164f654ccbca9d0c1fe8dafceebe` unless stated otherwise.

## Decision and corrected scope

The `.357` live report (`native=0`, `fallback=11`, `last=aura ID secret`, `hooked=48/48`, `readable-writes=21894`, pictured `2 s`/`0 s`) corroborates the existing secret-identity rejection. A native custom aura container offers a supported way to give a formatter to the native clock without exposing that identity. It requires newly owned buttons; it does not attach a formatter to the existing legacy Duration label.

**Collapse/consolidation is not a preservation requirement.** `BuffPresentation.lua`'s `keepBuffsExpanded` sets both `collapseExpandBuffs` and `consolidateBuffs` to `0`, intentionally retaining every buff and removing the arrow. Preserve that current behavior. The earlier stock-consolidation objection does not apply. [A1]

The proposed replacement is limited to the helpful player/vehicle row. Retain the existing BuffFrame as the Edit Mode and visibility owner. Keep DebuffFrame, its six private anchors, target/focus, tracked buffs, and their native assignments separate. Exact helpful-row equivalence is still blocked by the private-source and enchantment contracts described below; this is not ready to be included in the independent `.358` action repair.

## Supported rendering architecture

Create one `CustomAuraContainerTemplate` as a child of **BuffFrame**, alongside its legacy `AuraContainer`. Configure its unit and one `HELPFUL` group through native inbound methods. The native provider allocates `CustomAuraButtonTemplate` buttons and calls `initializeFrame` before applying access restrictions. Aura selection, recycling, private/native duration assignment, and duration updates then stay inside Blizzard's implementation. [N1][N2]

Use `AuraButtonArtTemplate` as the additional art-only template, or reproduce its static regions if template composition is refused by the actual client. Do not inherit `AuraButtonCodeTemplate` or `AuraButtonTemplate`: their legacy scripts, aura assignment, and timer writers are not part of this architecture. [N3]

During initialization, while the public frame is available:

- Register the icon with `SetIcon` and the count with `SetApplicationCount`. Retain the native 30-by-30 icon and `NumberFontNormal` count at the existing bottom-right inset. The native count delegate prints counts above one, matching the ordinary presentation. [N3][N4]
- Configure the current bjarkiUI mask and neutral rim directly from its existing atlas names and geometry. Do not run the generic `IconSkin.Apply` observer machinery against the new intrinsic buttons: it installs addon scripts/hooks, whereas the intrinsic forbids untrusted script/layout execution. This is an initialization-only reuse of the existing artwork, not a new skin. Enchantment buttons retain their separate native enchant border. [A2][N5]
- Register the descendant timer with `SetDurationText(timer, {textFormatter=formatter, textColor=...})`. Prepare a public conditional numeric formatter with tenths below ten and the current buff policy/localized units above ten. Reuse the current same-font glyph preparation only if its public profile succeeds; a plain formatter establishes decimals but does not establish stationary numeral ink. Use a native remaining-duration color curve for the existing white-below-90/gold-otherwise policy. No addon timer loop or secret-value arithmetic is needed. [A1][N4][N6]
- Use the current native timer font object, size, flags, shadow, and native text anchor. If the client's optional `SMALLER_AURA_DURATION_FONT_*` policy is active, preserving its time-dependent font/anchor changes needs a supported native equivalent; `SetDurationText` itself exposes formatter/color configuration, not font-selection rules. Do not silently freeze a different font. [N6]
- Set cancellation to `RightButtonUp`; retain the native bottom-left tooltip anchor and native combat-tooltip setting. Native intrinsic code resolves the current aura and cancellation target. There is no addon identity lookup or tooltip overlay. [N5]

`AuraContainerInbound.GetDefaultAuraDurationFormatter()` is a real public accessor discovered in the global inbound file. It corrects the earlier claim that the custom default had no accessor. It does **not** supply a legacy aura duration or assignment. Its whole-second policy is not the requested decimal policy, and its interval boundary differs from the existing buff formatter, so do not replace the latter blindly. The actual Forever `SecondsToTimeAbbrev` helper also directly selects units and has no formatter argument. [N7][A3]

## Keep saved Edit Mode geometry by following it

No preset import, saved-variable rewrite, new Edit Mode system, or layout activation is necessary. Native `EditModeAuraFrameSystemMixin` already materializes settings into `BuffFrame.AuraContainer`, then calls `UpdateGridLayout`. `IconLimitBuffFrame` becomes **iconStride**, the wrap count; it does not change the total 32-button capacity. [N8]

| Current native value | Proposed follower configuration |
|---|---|
| Native container anchor | Anchor the new container's matching growth corner directly to the same corner of `BuffFrame.AuraContainer`, with zero offset. Keep the native BuffFrame and its reserved arrow-space geometry intact even though the arrow is hidden. |
| `isHorizontal` | `SetFlowLayoutAxis`; horizontal cells are 30 by 40, vertical cells are 60 by 30. |
| `addIconsToRight`, `addIconsToTop` | `SetFlowLayoutGrowthDirection` and the corresponding TOPLEFT/TOPRIGHT/BOTTOMLEFT/BOTTOMRIGHT flow anchor. |
| `iconScale` | Apply that scale once to the follower container; its buttons remain at scale one. Both presentations then have the same total parent-relative scale. |
| `iconPadding=p` | Group `elementSpacing=p`, `lineSpacing=p`; zero outer padding and zero additional group gap. |
| `iconStride=n` | Maximum line size `n*d + (n-1)*p`, where `d` is the primary cell dimension (30 for either existing orientation). This derives from native flow placement, rather than treating line size as an icon count. |
| BuffFrame position, opacity, native shown state | Inherit from the preserved BuffFrame parent. Native dragging automatically moves the follower; do not copy screen coordinates or inspect custom aura bounds. |

The native grid uses unscaled cell measurements and offsets; scaling the whole follower once corresponds to the legacy scaling of each uniformly sized button. Preserve orientation-specific icon/text anchors from `UpdateGridLayout`. This is a source-supported mapping whose rendered equality still needs client inspection. [N6][N8][N9]

Observe only completed native layout/setup transitions to refresh this public configuration outside combat. Do not poll button positions, use ordinal identity matching, read the new secret layout bounds, or remeasure typography on countdown updates. In combat reuse an accepted geometry/profile configuration. If required public settings become unavailable, keep or restore the native presentation.

For the first version, **use the original native row during Edit Mode**. Hide/disable the custom presentation, restore the original AuraContainer, and let Blizzard own preview, handles, settings, and cancellation. After native Edit Mode exit and completed layout, synchronize the follower and perform the normal handoff. Native custom preview support is optional; it is unnecessary for preserving the existing editor.

## Ownership and lifecycle

The handoff unit is the entire legacy `BuffFrame.AuraContainer`, not individual buttons. The replacement is its sibling. After successful native custom initialization/configuration, hide only the old container with an accepted, owned visibility receipt, then show the replacement. Leave BuffFrame itself active so native events, layout ownership, vehicle state, and dependent DebuffFrame anchoring continue. Restore the old container before disabling a working replacement during rollback. Never assume a failed visibility setter succeeded, and yield to a newer external owner. This handoff's actual permission/visibility behavior is a client gate, not yet verified.

Follow the positively readable current `PlayerFrame.unit` after its native transition: use the custom container's public `SetUnit` for player/vehicle. Custom item enchantment sources are always player-owned. Legacy enchant buttons hide while native PlayerFrame displays vehicle auras, but their records still occupy prefix positions and consume the shared 32-position capacity. Any replacement must preserve that reservation even while hiding enchant art. Native source updates remain responsible for aura assignment. [N6][N10]

Honor `buffDurations`. Configure timer visibility from the public preference at initialization and its change events. Do not presume restricted custom descendants remain addon-writable after initialization. If the intended public reconfiguration is refused, hand back the whole row to native rather than showing unwanted duration text. The same policy applies to a refused geometry/font refresh.

## Remaining differences and technical gates

| Issue | Evidence and design consequence |
|---|---|
| **Order** | Legacy `ForEachAura` follows `GetAuraSlots`. Custom `AuraInstanceIDOnly` sorts instance IDs inside native execution; it is the least opinionated exposed order, but is not documented as equivalent to legacy slot order. Choose it as the proposed default, never infer that the nth legacy/custom buttons match. The custom `Default` comparator adds player-caster/priority/applicability ordering and is a worse match. [N11] |
| **Private membership — source question closed** | Legacy single anchors are **not harmful-only**. The actual private watcher admits every private-source aura (`ShouldAddAura`, line 1208), builds its index using only `isPrivate` (line 1175), and the single anchor displays that index (line 1095). Its renderer explicitly handles non-harmful auras (line 211). Custom groups also enumerate the private source and admit anything accepted by their native `HELPFUL` predicate; no categorical private exclusion or shared exclusive-owner check exists in the inspected group path. No inbound public-only source setting, `isPrivate` candidate, or valid PRIVATE filter token exists. Therefore the proposed all-helpful replacement cannot guarantee the current exclusive private-anchor presentation using these exposed contracts. Actual occurrence of a matching private aura in the user's client remains unknown; this conclusion does not assume game content. [N12][N13][N14][N15] |
| **Enchant representation** | Legacy enumerates every public `C_Item.GetWeaponEnchantInfo` record per slot and honors `displayTemporaryEnchantIcon`. Custom `AddItemEnchantment` has one entry per slot and uses the PaperDoll API, which explicitly selects an imbue over another temporary enchant. Its icon path uses the inventory-item texture. Independently owned conventional `AuraButtonTemplate` enchant buttons could preserve the public records, art preference, native tooltip and per-record cancellation; the built-in custom enchant source cannot promise that parity. [N6][N10][N16][N17] |
| **Shared capacity and wrap** | Public qualifying enchant records can reserve `E=min(32, enchant count)` positions and set the custom helpful group cap to `32-E`, including while vehicle mode hides the enchant art. This does not solve continuous wrapping: no inbound arbitrary-sibling-frame or leading-reserved-cell option was found for the native flow. Offsetting a sibling custom row after the prefix shifts every later line, rather than preserving only the first partial line. Do not claim complete legacy grid parity for this proposed single-group design. Unknown public data retains native presentation. [N6][N10][N16] |
| **Input integrations** | Native mouse tooltip and right-click cancellation exist. Legacy gamepad navigation/automatic tooltip queue and `BuffButton.OnClick` notifications are not automatically reproduced by the intrinsic. Do not add scripts to forbidden intrinsic buttons to imitate them. If those integrations are required, retain native until a supported equivalent exists. [N5][N6] |

## What needs a user decision

The existing request already establishes the icons, fonts, saved position, expansion policy, and native ownership requirements. Choosing the art-only template, public flow settings, parent-following anchor, safe fallback, or original Edit Mode preview is routine reversible implementation work; none needs a separate permission question.

**The material visual choice is ordering**, if the custom native order differs in the client: may a helpful row use native instance order while keeping its appearance and saved placement? Do not ask the user to decide hidden API behavior, accept duplicate private auras, or approve guesses about enchant support. Those are technical compatibility gates to resolve first. Any intentional enchant-icon/coverage or gamepad behavior change would also need disclosure rather than being smuggled into a timer repair.

The next useful technical step, if continuing buff work, is a narrowly scoped reversible feasibility demonstration of the native delegate and geometry follower, with native fallback retained and no change to saved presets. Routine API/geometry investigation does not require another product-choice question. Switching the installed visible row requires disclosure of any observed ordering or feature difference. The demonstration would not establish a universally equivalent replacement. No such demonstration was built in this design-only task.

## Evidence

[A1]: ../BuffPresentation.lua "Current formatter, opacity policy, and keepBuffsExpanded (1072)"
[A2]: ../IconSkin.lua "Existing mask/rim constants, initialization and observer behavior"
[A3]: https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXML/TimeUtil.lua "Actual Forever SecondsToTimeAbbrev, retrieved by root at bebcb6bf309cf41b41bd74f8ca651e6a105b2676"
[N1]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.xml
[N2]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua
[N3]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_BuffFrame/BuffFrameTemplates.xml
[N4]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua
[N5]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.xml
[N6]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua
[N7]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerInbound.lua
[N8]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua
[N9]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_SharedXMLBase/AnchorUtil.lua
[N10]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerEnchantments.lua
[N11]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua
[N12]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_ManagedAuraContainer.lua
[N13]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.lua
[N14]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_PrivateAurasUI/PrivateAuraInit.lua
[N15]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerGroups.lua

Additional exact contracts: [custom API options](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/AuraContainerUtilDocumentation.lua), [custom group validation/configuration](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua), [legacy grid](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_SharedXML/GridLayoutUtil.lua), [native button behavior](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.lua), and [native icon/ownership/filter utilities](https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua).

[N16]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua
[N17]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_APIDocumentationGenerated/PaperDollInfoDocumentation.lua
