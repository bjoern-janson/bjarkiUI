# Proposed buff and debuff presentation with native decimals

**Status: deferred alternative; not implemented or client-validated.** `.360` instead uses an in-place native seconds sink when the ordinary label exposes a public seconds-format selector: it forwards opaque seconds unchanged and displays tenths across Blizzard's native seconds band (below 90 seconds). That reversible precision tradeoff keeps the existing rows, private anchors, ordering and enchant positions. Strict below-ten-only formatting still needs a supported restricted-time selector. The larger replacement below is retained for review, not selected for this repair.

The proposed display keeps the current Blizzard artwork, bjarkiUI mask/rim, icon size, timer font, scale, and saved BuffFrame/DebuffFrame settings. Blizzard's custom aura containers would own the helpful and harmful rows, including aura assignment and duration updates. Their native duration-text delegate supplies tenths below ten seconds and the existing buff units above that threshold. It avoids the secret-ID lookup that currently prevents the ordinary-label replacement from running. This is a supported API route, not evidence that it already renders correctly in the client. [N1][N2]

## What would visibly change

| Surface | Current display | Proposed display |
|---|---|---|
| Ordinary buffs/debuffs | Existing native rows; affected short timers remain whole seconds. | Same artwork and typeface, with native-bound short decimals. Independently stationary numeral ink remains a separate validation requirement. |
| Private auras | Up to six native indexed anchors beside the debuff presentation, including helpful private auras. | Native HELPFUL/HARMFUL selection places accepted private helpful auras with buffs and private harmful auras with debuffs. The old private presentation is retired to prevent duplicates. Full private-membership equivalence is a technical gate, not an assumption. |
| Aura order | Legacy slot order. | Native instance-ID order. It may differ; there is no ordinal matching between old and new buttons. |
| Weapon enchants | Prefix positions within the shared buff grid. | A dedicated strip below the helpful row, retaining every qualifying public enchant record, its current icon preference, border, count, tooltip, and per-record cancellation. |
| Debuffs attached below buffs | Follow the original BuffFrame footprint. | Follow the combined helpful-row/enchant-strip footprint at the saved relative gap. Their visible vertical position can therefore change as that footprint changes. Independently positioned debuffs stay at their saved position. |

The source establishes the private-source overlap and enchant representation differences; it does not establish which private effects the user's current character will encounter. [N3][N4]

## Exact placement

The helpful row starts at the existing BuffFrame aura-container growth corner with zero offset. It retains the current public orientation, growth directions, wrap count, padding, and scale. The harmful row initially follows the corresponding DebuffFrame corner. Neither original frame, saved layout, nor preset is replaced. [N4][N5]

For the pictured horizontal, right-aligned layout, the enchant strip's **TOPRIGHT anchors to the new helpful container's BOTTOMRIGHT, at `(0, -5)`** in that container's unscaled units. Left-aligned layouts mirror those corners to TOPLEFT/BOTTOMLEFT. The five-unit gap begins below the complete aura cells, including their timer space. Enchants use the existing icon size and spacing and wrap at the public buff wrap count; each additional enchant row contains only enchant records.

Blizzard's flow pass sizes the helpful container itself. The strip follows its bottom through a native anchor: no addon reads a restricted height, counts secret auras, or moves the strip on timer ticks. With no enchant records the strip has zero height and no added gap. Vehicle mode hides its art; qualifying public enchant records still reserve their existing share of the 32-position buff capacity. [N4][N6]

When the saved DebuffFrame relationship attaches below BuffFrame, the visible harmful follower instead attaches below this strip, preserving the publicly readable horizontal relationship and vertical gap, translated between the original container corners. This is a temporary presentation relationship; the saved anchor remains intact. With no enchants it follows the helpful container's bottom directly. An independent DebuffFrame anchor stays independent.

**Exact old debuff pixels and guaranteed clearance cannot both be promised for every saved layout.** A separate enchant strip can need another line. The attached-row movement above is part of this proposal. Independent placements, upward/vertical growth, and screen-edge arrangements require client inspection; unavailable or ambiguous anchor configuration retains the original presentation, rather than silently repositioning a saved layout. [N4][N5][N6]

## Native ownership and acceptance limits

Original BuffFrame/DebuffFrame controllers remain active for native events, vehicle transitions, and deadly-debuff warnings. Only their ordinary/private visible presenters are handed off, after all replacement configuration and ownership checks succeed. Any refused handoff retains or restores the complete original presentation. Edit Mode uses the original preview and handles; leaving it reapplies the accepted follower configuration. Duration preferences remain authoritative. [N2][N4][N5]

Client acceptance must establish private HELPFUL/HARMFUL coverage, limits and dispel styling; safe presenter visibility handoff; relative anchoring during wrap/vehicle changes; enchant cancellation; and current font behavior. Native mouse interactions are available, but gamepad navigation and optional smaller-duration-font behavior have no proven equivalent. An unmet required behavior keeps the native presentation. No secret timing arithmetic, guessed aura identity, new polling loop, or universal compatibility claim is part of this proposal.

## Source basis

The [bounded design](NATIVE_BUFF_ROW_DESIGN.md) contains the detailed contracts and earlier investigation. Relevant implementations were rechecked against Forever `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`; the core custom-aura source contracts are unchanged.

[N1]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraContainer.xml
[N2]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua
[N3]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.lua
[N4]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_BuffFrame/BuffFrame.lua
[N5]: https://github.com/Gethe/wow-ui-source/blob/4cd0ab752a77164f654ccbca9d0c1fe8dafceebe/Interface/AddOns/Blizzard_EditMode/Shared/EditModeSystemTemplates.lua
[N6]: https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_SharedXMLBase/AnchorUtil.lua
