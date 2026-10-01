# bjarkiUI Architecture

> Engineering notes for **WoW: Forever**.
>
> This document records the architecture, Blizzard implementation details,
> failure modes, and design constraints learned while building and live-testing
> bjarkiUI. It is intentionally more detailed than a user-facing README.
>
> Current reference build when this document was written: **0.2.57-local**.

---

## 1. What bjarkiUI is

bjarkiUI is a deliberately small presentation layer over Blizzard's native UI.

The governing idea is:

> **Keep Blizzard's behavior and ownership; change only the presentation that
> has a demonstrated reason to change.**

The addon is not trying to replace unit frames, Edit Mode, chat, nameplates,
the damage meter, or the micro menu. It hooks the existing systems after
Blizzard has done its work and applies narrowly scoped corrections.

That matters for three reasons:

1. WoW: Forever inherits modern protected/secret-value behavior.
2. Blizzard frames are highly interconnected; replacing or moving the wrong
   parent can affect unrelated systems.
3. Native frames receive frequent state updates. A cosmetic change that does
   not survive Blizzard's own refresh path is not a complete change.

The target is therefore **native-looking, low-overhead, reversible polish**.

---

## 2. Current package

The addon is intentionally compact:

- `bjarkiUI.lua` — runtime implementation
- `bjarkiUI.toc` — addon metadata
- `bjarkiUI_Camelot.toc` — alternate client metadata
- `ARCHITECTURE.md` — this document

There is no framework layer, dependency, custom scheduler, or addon-owned
`OnUpdate` loop.

---

## 3. Core architectural rules

### 3.1 Prefer post-hooks over replacement

When Blizzard already owns a behavior, use `hooksecurefunc` and run afterward.

Examples:

- unit-frame health updates
- unit-frame power updates
- target-of-target rebinds
- compact unit-frame names
- player status updates
- Micro Menu child anchoring
- Communities rows
- Damage Meter row text

This preserves Blizzard's state machine and reduces compatibility debt.

### 3.2 Do not poll cosmetic state

bjarkiUI has no cosmetic `OnUpdate` loop.

Use:

- the exact Blizzard function that performs the update,
- the narrowest applicable game event,
- or a one-time application on login/world entry.

If a cosmetic effect appears to require checking every frame, first find what
Blizzard is already calling every frame or on state change and attach to that
instead.

### 3.3 Inaccessible or secret data is UNKNOWN

Never treat a secret value as false, zero, empty, or absent.

The addon wraps potentially sensitive accesses and validates values before:

- branching,
- arithmetic,
- color calculations,
- string transformations,
- or setting protected presentation state.

`issecretvalue` is treated as an authority boundary.

### 3.4 Scope events before filtering

Do not register globally noisy events and then discard 99% of them in Lua when
`RegisterUnitEvent` can express the actual dependency.

Examples:

- `UNIT_TARGET` only for `target` and `focus`
- power/name events only for tracked unit tokens
- faction/threat/flags only for target/focus and their derived units
- `UNIT_PET` only for `player`

This is particularly important in populated cities.

### 3.5 Do not alter underlying data to change visible text

Where possible, alter only the rendered string.

Examples:

- Damage Meter keeps the full source identity internally.
- Communities chat hyperlinks preserve the full player-name payload.
- visible secondary names are stripped without rewriting combat/session data.

---

## 4. Tracked unit-frame model

bjarkiUI directly styles these unit tokens:

- `player`
- `target`
- `focus`
- `targettarget`
- `focustarget`
- `pet`

`targettarget` and `focustarget` use Blizzard's reusable small unit-frame
objects.

### Why reusable frames matter

A ToT/FoT frame is not permanently associated with one referent. Blizzard can
reuse the same frame object for:

- a player,
- a pet,
- an NPC,
- another player-controlled unit.

Therefore presentation state must be **re-derived from the current unit** after
Blizzard rebinds the frame.

A previous bug made this visible: a ToT/FoT frame could retain the universal
pet-green tint after its referent changed back to a player.

The repair is to hook `UnitFrame_Update` and, for tracked frames, reapply:

1. the full bar presentation,
2. the health color,
3. the power color,
4. the primary-name presentation.

This hook happens after Blizzard's final rebind/update path.

---

## 5. Health-bar architecture

### 5.1 Texture

Tracked health and power bars use the native atlas:

`UI-HUD-CoolDownManager-Bar`

The intent is to retain Blizzard's rendering machinery while using a cleaner
bar texture.

Texel snapping is disabled on the status-bar texture where supported to avoid
unwanted raster snapping artifacts.

### 5.2 Players

Real player identity has priority over pet identity.

This ordering is important.

When determining health color:

1. positively identified players get class color,
2. player-controlled pets get stock green,
3. NPC/reaction logic follows.

Do **not** check pet/player-controlled status before positive player identity.
Some Blizzard APIs describe ownership/control in ways that can overlap, and the
wrong test order previously allowed player frames to inherit pet green.

Class colors are slightly presentation-adjusted using:

- `CLASS_SATURATION = 1.18`
- `CLASS_BRIGHTNESS = 1.08`

The PRD intentionally remains visually brighter than ordinary unit-frame bars.

### 5.3 Pets

All player combat pets use Blizzard-style green health.

The rule applies consistently whether the pet appears as:

- the player's Pet Frame,
- target,
- focus,
- target of target,
- target of focus.

Pet color must be re-evaluated whenever a reusable frame changes referent.

### 5.4 NPCs and reaction state

NPC colors continue to follow semantic state rather than being permanently
overpainted.

The addon listens to the relevant state changes for only:

- target,
- focus,
- targettarget,
- focustarget.

This includes:

- `UNIT_FLAGS`
- `UNIT_FACTION`
- `UNIT_THREAT_SITUATION_UPDATE`
- `UNIT_THREAT_LIST_UPDATE`

Tagged neutral mobs must resolve to the intended grey state rather than remain
yellow.

---

## 6. Power bars

Power colors are derived from Blizzard's current unit power type.

Where available, `PowerBarColor[token]` is preferred over raw fallback RGB
values.

The update is attached to `UnitFrameManaBar_UpdateType` and is restricted to
the actual tracked unit-frame power bar. Auxiliary bars are not painted just
because they happen to share a unit token.

---

## 7. Never style auxiliary damage bars as health bars

PlayerFrame owns an `AnimatedLossBar`.

It is intentionally red during damage animation.

A broad health-bar hook once styled this auxiliary bar as though it were the
real health bar, causing the entire health presentation to flash red.

Current invariant:

> A `UnitFrameHealthBar_Update` callback may style a bar only when
> `bar == healthBar(unit)`.

Do not relax this guard.

---

## 8. Threat, combat, pet, and rested highlights

All current highlight-family effects use:

`HIGHLIGHT_SCALE = 0.25`

The value is intentionally literal now. Earlier builds accumulated odd values
such as `0.45 * 0.45`; those were historical tuning residue.

### 8.1 Player combat/threat

Use Blizzard's native PlayerFrame threat flash:

`PlayerFrameContainer.FrameFlash`

Do not substitute the PlayerFrame `StatusTexture`.

The native flash provides the correct visual language and geometry.

### 8.2 Target/focus threat

Target/focus threat continue to use their native threat indicators with the
same 25% presentation strength.

Pre-combat threat presentation is intentionally subtle and belongs to the same
visual family.

### 8.3 Pet cues

The pet frame flash and pet attack cue use the same 25% scale.

The goal is consistency, not identical perceived brightness: different source
art can still look slightly stronger or weaker at equal alpha.

### 8.4 Rested state

Blizzard normally uses `PlayerFrame ... StatusTexture` for a red/yellow
portrait-and-name-bar pulse.

bjarkiUI deliberately does **not** use that pulse.

Instead:

1. hide the native `StatusTexture`,
2. create a static texture using the native PlayerFrame threat-flash atlas,
3. copy the native threat-flash geometry,
4. tint it Blizzard resting yellow `(1.0, 0.88, 0.25)`,
5. show it at `HIGHLIGHT_SCALE`.

This makes rested and combat use the same border language.

An additional benefit is that hiding `StatusTexture` stops Blizzard's
PlayerFrame `OnUpdate` alpha-pulse work because that animation path runs only
while the texture is shown.

### 8.5 Avoid multiplicative alpha stacks

Do not simultaneously attenuate an effect with both:

- frame/texture alpha, and
- vertex alpha,

unless multiplication is explicitly intended.

The current implementation applies visual attenuation once through vertex
alpha so repeated Blizzard `Show`, `SetAlpha`, or refresh paths cannot compound
the effect.

---

## 9. Primary-name policy

bjarkiUI removes secondary player names where the secondary part is visual
noise.

The policy is **presentation-only** and applies to player identities, not NPC
names.

Supported surfaces include:

- Player/Target/Focus/ToT/FoT unit-frame names
- player nameplates
- raid frames
- raid-style party frames
- normal chat sender decoration
- Guild/Communities roster rows
- Guild/Communities embedded chat
- Blizzard Damage Meter rows

### 9.1 Compact unit frames

Nameplates, raid frames, and raid-style party frames share
`CompactUnitFrame_UpdateName`.

A single post-hook can therefore cover these surfaces, but it must first
confirm that the unit token represents a player-facing compact frame.

Do not blindly rewrite every compact-frame name; NPC and pet compact frames
are not part of this policy.

### 9.2 Chat

Use Blizzard's sender-name filtering path where available.

Visible sender decoration may be shortened, but identity/link behavior must
remain intact.

### 9.3 Guild/Communities roster

Hook:

`CommunitiesMemberListEntryMixin:SetMember`

Then rewrite only the visible member label.

### 9.4 Guild/Communities embedded chat

A subtle Blizzard implementation detail matters here:

The live `CommunitiesFrame.Chat` receives/copies mixin methods when the frame
is created.

Replacing `CommunitiesChatMixin.FormatMessage` later does **not necessarily**
modify the already-created live frame.

The working solution therefore patches the live
`CommunitiesFrame.Chat.FormatMessage` method after the frame exists and then
redraws current chat history with `DisplayChat`.

When shortening player names inside links:

- preserve the full player name in the hyperlink payload,
- shorten only the visible hyperlink text.

### 9.5 Blizzard Damage Meter

Hooking only row initialization is insufficient.

Damage Meter rows are recycled and Blizzard later calls `UpdateName`, which can
restore `sourceName`.

The robust solution is:

1. discover each row as it is created/reused,
2. install a one-time hook on that row's **name FontString `SetText`**,
3. transform the final visible text there,
4. leave `sourceName` and session data untouched.

This is a useful general pattern:

> If a visual value keeps returning, hook the final renderer, not merely the
> first population step.

Forever combat adds one more boundary: Damage Meter `sourceName`, `nameText`,
and the visible FontString text can become secret. For the local-player row,
`isLocalPlayer` plus independently readable `UnitName("player")` authorizes a
primary-name replacement without inspecting the secret source name. Never
compare or pattern-match a secret visible string; even `replacement == visible`
can taint and error.

---

## 10. Level display

Level rings are hidden.

The numeric player/target/focus levels are separately controllable through a
per-character setting:

`bjarkiUISettings.showLevelNumbers`

Default: enabled.

Commands:

- `/bui levels`
- `/bui levels on`
- `/bui levels off`

When re-enabling target/focus levels, allow Blizzard's own `CheckLevel()`
logic to decide whether a number is valid for the current unit.

Do not replace Blizzard's corpse/high-level/battle-pet visibility rules with a
simpler addon rule.

A `Show` hook on the relevant FontStrings prevents Blizzard refreshes from
making the numbers reappear when the setting is off.

---

## 11. Edit Mode ownership

bjarkiUI ships a character Edit Mode layout named:

`bjarkiUI`

The layout string is imported only when the named layout does not already
exist.

Once it exists:

> **The saved Edit Mode layout belongs to the player.**

The addon does not continuously overwrite the player's saved coordinates.

This is an important ownership boundary. A default is not an eternal source of
authority over user edits.

---

## 12. The Micro Menu lesson

This is the clearest example of why visual ownership and anchor ownership must
be distinguished.

### 12.1 The visible problem

The Micro Menu button row was visually about one pixel higher than:

- Action Bar 1,
- the Bags bar.

At first glance this looked like a straightforward Edit Mode Y-coordinate
problem.

It was not.

### 12.2 Why changing `MicroMenuContainer` failed

Blizzard defines:

- `MicroMenuContainer` — an Edit Mode system / anchor root
- `MicroMenu` — the actual visible button layout child

Other bottom UI systems can be anchored relative to `MicroMenuContainer`.

Therefore moving `MicroMenuContainer` moves the surrounding cluster with it.

The relative optical mismatch remains unchanged.

This was confirmed live: dragging the Micro Menu in Edit Mode caused
surrounding bottom UI elements to move too.

### 12.3 A serialization trap

The Edit Mode layout string contained an entry with the text:

`MicroMenuContainer -4.5 -4.0`

It was tempting to read this as:

> "MicroMenuContainer is at -4.5, -4.0."

That interpretation was wrong.

In that serialized record, `MicroMenuContainer` was the **relative anchor
target for another system** (the Main Action Bar relationship), not proof that
the record itself represented the Micro Menu's own position.

General rule:

> A frame name appearing in an anchor serialization may describe
> `relativeTo`, not object identity.

Never mutate a serialized coordinate merely because the desired frame name
appears next to it. Decode the system/anchor relationship first.

### 12.4 The correct layer

Blizzard's `MicroMenuMixin:AnchorToMenuContainer()` anchors the visual
`MicroMenu` child directly to `MicroMenuContainer` at `(0, 0)`.

That is the correct seam.

Current fix:

- leave `MicroMenuContainer` untouched,
- hook `MicroMenu:AnchorToMenuContainer`,
- after Blizzard anchors the child, set the child Y offset to `-1`,
- only when `MicroMenu` is actually parented to the normal container.

Constant:

`MICRO_MENU_CHILD_Y_OFFSET = -1`

This shifts the visible buttons without moving the anchor root or any
neighboring systems.

This change finally aligned the Micro Menu with Action Bar 1 and Bags.

### 12.5 General UI principle from this bug

For any visual offset problem, distinguish:

1. **layout root**
2. **anchor relationship**
3. **visible child**
4. **art inside the child**

Move the lowest layer that actually owns the visual discrepancy.

Moving a higher layer can preserve the error while translating an entire
dependency graph.

---

## 13. World combat text

Outgoing Blizzard damage text is engine/world text, not a normal UI FontString.

bjarkiUI changes its screen spawn position through CVars rather than creating a
replacement combat-text system.

Current values:

- `WorldTextScreenY_v2 = 0.0425`
- `WorldTextCritScreenY_v2 = 0.0550`

This keeps Blizzard's combat-text behavior and has no addon runtime loop.

---

## 14. Event model

### Main lifecycle events

- `PLAYER_LOGIN`
- `PLAYER_ENTERING_WORLD`
- `PLAYER_TARGET_CHANGED`
- `PLAYER_FOCUS_CHANGED`
- `EDIT_MODE_LAYOUTS_UPDATED`
- `ADDON_LOADED`

`ADDON_LOADED` is used for optional Blizzard modules such as:

- `Blizzard_Communities`
- `Blizzard_DamageMeter`

### Derived-target changes

Only target and focus can change the derived unit tokens that bjarkiUI paints.

Therefore:

`UNIT_TARGET` is registered only for:

- `target`
- `focus`

### Power/name events

These are partitioned across narrow unit registrations covering the tracked
unit set.

### NPC state-color events

Only NPC-capable painted tokens receive:

- `UNIT_FLAGS`
- `UNIT_FACTION`
- `UNIT_THREAT_SITUATION_UPDATE`
- `UNIT_THREAT_LIST_UPDATE`

### Pet rebinding

`UNIT_PET` is registered only for `player`.

---

## 15. Performance philosophy

### 15.1 No addon-owned per-frame loop

There is no bjarkiUI `OnUpdate` loop for:

- colors,
- names,
- highlights,
- Micro Menu correction,
- level visibility,
- damage-meter cleanup.

### 15.2 Hook only after proving the hook is necessary

Global Blizzard hooks currently used include paths such as:

- `UnitFrameHealthBar_Update`
- `UnitFrameManaBar_UpdateType`
- `UnitFrame_Update`
- `CompactUnitFrame_UpdateName`

They are acceptable because each callback performs an immediate narrow guard.

Nevertheless, `CompactUnitFrame_UpdateName` is a plausible A/B target if dense
city performance ever regresses, because nameplates/party/raid frames can call
it frequently.

### 15.3 Cache one-time hooks

Damage Meter FontStrings, level FontStrings, and similar runtime objects are
hooked once and remembered.

Do not install duplicate hooks on recycled objects.

### 15.4 Prefer native work already being performed

Examples:

- use Blizzard's threat texture instead of animating a custom one,
- use Blizzard's row renderer instead of rebuilding a damage meter,
- use Blizzard's Edit Mode instead of maintaining custom drag state,
- use Blizzard's status-bar objects instead of replacing unit frames.

---

## 16. Secret-value / taint discipline

WoW: Forever can expose values that exist but are not legally readable in the
current execution context.

Rules:

1. Check secret status before arithmetic.
2. Check secret status before boolean tests.
3. Do not stringify a secret value merely to inspect it.
4. Do not infer semantic falsehood from inaccessible data.
5. Keep protected-state presentation changes post-hooked and narrow.
6. Avoid combat-time structural rebuilds where a presentation refresh is
   sufficient.

Historical taint lessons from related UI work strongly reinforce these rules:

- secret booleans can taint a seemingly harmless `if`,
- secret numbers can trigger strong taint through status-bar arithmetic,
- protected layout changes can fail even when a frame appears visually simple.

bjarkiUI should remain more conservative than ordinary Retail addon examples.

---

## 17. Blizzard implementation facts worth remembering

### PlayerFrame status

Blizzard's PlayerFrame status logic distinguishes:

- resting,
- combat,
- hate list,
- neutral state.

Resting normally shows a yellow `StatusTexture`.

Combat normally shows a red `StatusTexture` plus combat icon behavior.

The `StatusTexture` alpha is animated by Blizzard while the texture is shown.

This is why hiding it is sufficient to stop that specific pulse path.

### PlayerFrame threat flash

The native player threat flash is separate from `StatusTexture` and is the
correct border language for bjarkiUI combat/rest presentation.

### Target-of-target update order

Blizzard's ToT update path performs `UnitFrame_Update(self)` after the derived
unit changes.

That final update is a reliable place to reapply referent-dependent
presentation.

### Micro Menu

`MicroMenuContainer` is an Edit Mode system.

`MicroMenu` is a child which can be re-anchored by
`MicroMenuMixin:AnchorToMenuContainer()`.

The child may also be temporarily reparented by Blizzard, so bjarkiUI's offset
must apply only when:

`MicroMenu:GetParent() == MicroMenuContainer`.

### Communities

The live chat frame can own copied mixin methods independent of later changes
to the global mixin table.

### Damage Meter

Rows are recycled and the final visible name can be rewritten after
initialization.

---

## 18. Anti-regression checklist

Before changing unit-frame presentation, verify:

- [ ] Player remains class-colored.
- [ ] Target/focus players remain class-colored.
- [ ] ToT/FoT do not retain stale pet green.
- [ ] All player combat pets are green in every tracked context.
- [ ] Neutral/tagged NPC state still resolves correctly.
- [ ] Animated loss bar remains Blizzard red and is not restyled.
- [ ] Power bars retain correct resource colors.
- [ ] PRD presentation remains intentionally brighter.

Before changing highlights, verify:

- [ ] player combat uses native threat-flash art.
- [ ] target/focus threat still works.
- [ ] pet flash remains subtle.
- [ ] rested border is static yellow.
- [ ] Player `StatusTexture` pulse remains hidden.
- [ ] all highlight-family effects use the intended shared scale.

Before changing names, verify:

- [ ] NPC names remain untouched.
- [ ] player hyperlinks still resolve correctly.
- [ ] Guild/Communities existing history redraws correctly.
- [ ] Damage Meter data identity remains intact.
- [ ] recycled Damage Meter rows do not restore secondary names.
- [ ] raid-style party frames are covered.

Before changing Edit Mode or bottom-bar layout, verify:

- [ ] saved `bjarkiUI` layout is not overwritten merely because it exists.
- [ ] a serialized frame name is not being mistaken for system identity.
- [ ] `relativeTo` relationships are understood before editing coordinates.
- [ ] moving an anchor root does not translate dependent systems.
- [ ] optical corrections target the visible child when appropriate.
- [ ] Micro Menu child remains aligned with Action Bar 1 and Bags.

Before adding any runtime mechanism, verify:

- [ ] there is no suitable existing Blizzard update function to hook.
- [ ] `RegisterUnitEvent` cannot narrow the event.
- [ ] no `OnUpdate`/polling solution is being introduced for a cosmetic state.
- [ ] secret-value checks occur before every relevant branch/arithmetic path.

---

## 19. Things intentionally not done

bjarkiUI does not aim to:

- replace Blizzard unit frames,
- replace Edit Mode,
- replace the Damage Meter,
- replace chat,
- create custom combat text,
- animate custom threat indicators,
- globally rename player data,
- poll every frame for cosmetic state,
- infer inaccessible protected information,
- continuously force the user's saved layout back to addon defaults.

---

## 20. Design heuristics for future changes

### Find the owner of the visual, not just the thing near it

If changing frame A moves frame B, A may be an anchor root rather than the
visual owner.

Inspect the child hierarchy and Blizzard layout call before adding offsets.

### Hook the last writer

If Blizzard keeps undoing a cosmetic change, identify the function that writes
the final value and run after it.

Do not fight the renderer from an earlier lifecycle stage.

### Preserve semantics underneath presentation

Change:

- visible color,
- atlas,
- visible string,
- child offset,

rather than replacing:

- unit identity,
- source data,
- chat hyperlink payload,
- session data,
- Edit Mode ownership.

### Prefer one invariant over several exceptions

Examples:

- one `HIGHLIGHT_SCALE = 0.25`,
- players before pets in identity precedence,
- child-only Micro Menu offset,
- one final-renderer rule for Damage Meter names.

A clean invariant is easier to audit than accumulated historical tuning.

### Treat live screenshots as measurements

A screenshot can reveal a rendering truth that the nominal layout model hides.

The Micro Menu issue is a good example:

- serialized positions looked plausible,
- container movement appeared to succeed,
- but the relative pixel mismatch remained.

The screenshot was the decisive evidence that the wrong layer was moving.

---

## 21. Current accepted presentation invariants

At the time of this document:

- Micro Menu visual child is offset **1 UI unit down** inside its container.
- Action Bar / Bags anchor topology is left untouched.
- Highlight-family strength is **25%**.
- Resting uses static yellow native-border geometry.
- Player `StatusTexture` pulse is hidden.
- Players use adjusted class-color health bars.
- Player combat pets use stock green health bars.
- ToT/FoT presentation is re-derived after Blizzard frame reuse.
- Secondary player names are removed from supported visible surfaces.
- Level numbers are independently toggleable.
- World damage numbers are raised using CVars.
- There is no addon-owned cosmetic `OnUpdate` loop.

---

## 22. Working definition of a good bjarkiUI change

A change is good when it:

1. fixes a visible or functional problem the user can actually demonstrate,
2. changes the smallest possible ownership layer,
3. survives Blizzard's native refresh path,
4. does not create a polling loop,
5. does not weaken secret/taint discipline,
6. preserves user-owned Edit Mode state,
7. preserves underlying game data,
8. does not create a regression in adjacent native UI.

Or, more compactly:

> **Patch the presentation seam, not the system.**
