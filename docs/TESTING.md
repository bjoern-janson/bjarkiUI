# Testing and packaging bjarkiUI

Current test target: **0.2.335-cast-recovery-test**, **13 manifest-loaded runtime modules**, and **27 top-level Lua scripts**: 26 behavioral suites plus `tests/syntax.lua`. Run both Lua 5.1 and Lua 5.4. The current aura suite reports **217 cases**; suite/assertion counts describe fixture coverage, not a percentage of live-client behavior covered.

## Portable verification

Run from the repository root with Python 3.10 or newer and native Lua/luac executables installed:

```sh
python tools/verify.py
python tools/verify.py --output ../bjarkiUI-0.2.335-cast-recovery-test.zip
```

The default uses Lua 5.1 and 5.4 with their matching compilers. `--output` is an optional ZIP filename **outside the checkout**, not a report path. Its parent directory must already exist and the file must be new. Packaging occurs only after verification succeeds. The [CI workflow](../.github/workflows/package-addon.yml) uses native interpreters and the same [verification tool](../tools/verify.py).

Select explicit executables when their paths differ, or to run one interpreter while iterating:

```sh
python tools/verify.py --lua /path/to/lua5.4 --luac /path/to/luac5.4
python tools/verify.py --lua /path/to/lua5.1 --luac /path/to/luac5.1 --lua /path/to/lua5.4 --luac /path/to/luac5.4
```

Quote Windows executable paths containing spaces. A one-interpreter run is useful focused evidence; it does not replace the two-interpreter release check.

When native executables are unavailable, the optional Python `lupa` dependency provides an embedded fallback:

```sh
python tools/verify.py --lupa
```

This runs the embedded `lua51` and `lua54` runtimes and must not be combined with `--lua` or `--luac`. Identify embedded versus native execution in a verification report; they exercise different host installations.

## Run one suite directly

The first argument is the addon root. Lua 5.1 needs the [fixture compatibility preload](../tests/support/lua51.lua):

```sh
lua5.4 tests/aura-presentation.lua .
lua5.1 -l tests.support.lua51 tests/aura-presentation.lua .
luac5.4 -p NativeDigitCells.lua
luac5.1 -p NativeDigitCells.lua
```

Substitute another top-level script for a focused regression. `tests/syntax.lua` compiles all manifest-loaded modules through `loadfile`; it is not a behavioral test. The verifier also checks source/test syntax and manifest/package consistency.

## Suite map

| Route | Current scripts | What to inspect |
| --- | --- | --- |
| Action timers | [cooldown-seconds.lua](../tests/cooldown-seconds.lua), [action-timer-spacing.lua](../tests/action-timer-spacing.lua), [native-digit-cells.lua](../tests/native-digit-cells.lua) | Exact thresholds, native formatter support, fixed cells, font/style refresh, minimum/GCD gates, preference changes, duration binding and stock restoration. |
| Player aura timers | [aura-presentation.lua](../tests/aura-presentation.lua) | Public/opaque timing, assignment and expiry, native update order, font/layout changes, combat, physical owner changes, nested writes and fallback text. |
| Player cast timers | [castbar-digit-cells.lua](../tests/castbar-digit-cells.lua) | Frozen 0.2.309 native duration-to-text bindings, unmodified Blizzard source text, fixed positions and thresholds, casts/channels, permission refusals, and rejected alpha handoffs returning native text. |
| Tracked buffs and decoration | [presentation.lua](../tests/presentation.lua), [icon-skin.lua](../tests/icon-skin.lua) | Active pool iteration, item/widget reuse, threshold resets, masks/rims, external writes and restoration. |
| Health/name ownership | [health-color-observer.lua](../tests/health-color-observer.lua), [name-color-ownership.lua](../tests/name-color-ownership.lua) | Native color observation, recipient changes, partial restoration, stale ownership and combat-exit reconciliation. |
| Unit status typography | [status-style.lua](../tests/status-style.lua), [status-scale.lua](../tests/status-scale.lua), [status-combat.lua](../tests/status-combat.lua), [pet-status-text.lua](../tests/pet-status-text.lua) | Current native font, shadow/style, scale refresh and pet presentation. |
| Hit-text placement | [hit-text-lifecycle.lua](../tests/hit-text-lifecycle.lua), [hit-text-write-recovery.lua](../tests/hit-text-write-recovery.lua) | Geometry, lifecycle refresh and refused setter recovery. |
| Party order | [party-order-recovery.lua](../tests/party-order-recovery.lua) | Changed anchors only, dependent-anchor rollback, denied permission, roster/pet changes and later repair. |
| Cosmetic frame labels | [frame-label-tweaks.lua](../tests/frame-label-tweaks.lua), [combat-icon-level-mirror.lua](../tests/combat-icon-level-mirror.lua), [combat-icon-portrait-anchor.lua](../tests/combat-icon-portrait-anchor.lua) | Native geometry, write receipts, float precision, combat-icon alignment and count-font changes. |
| Soft Dark | [softdark-restore.lua](../tests/softdark-restore.lua), [softdark-discovery-handoff.lua](../tests/softdark-discovery-handoff.lua), [softdark-callback-recovery.lua](../tests/softdark-callback-recovery.lua) | Discovery, ownership transfer, native precision, refused restoration and incomplete callback registration. |
| Common lifecycle | [lifecycle.lua](../tests/lifecycle.lua), [hardening.lua](../tests/hardening.lua), [initialization-recovery.lua](../tests/initialization-recovery.lua) | Native hook retry, failed initialization, inaccessible/protected paths and broader module integration. |
| Retired aura route | [unit-aura-retirement.lua](../tests/unit-aura-retirement.lua) | Custom Target/Focus aura rendering remains inactive. |
| Manifest syntax | [syntax.lua](../tests/syntax.lua) | All 13 runtime modules parse in the selected Lua version. |

Tests run each script in its own interpreter invocation. Do not turn the archived snapshot into an additional current-suite glob: it targets different source behavior.

## The .334 regression and its limits

The aura case named **repeated native font and anchor writes preserve fixed buff digits in combat** models this full sequence:

1. The native timer writes through `UpdateDuration`; the addon post-hook displays the current fixed tenth.
2. Native code then applies `SetFontObject('NormalSmall')` and `SetPoint('TOP', owner, 'BOTTOM')`, including unchanged values.
3. Repeated updates before and during combat retain visible fixed text and the empty native source label. Instrumented glyph setters record zero redundant geometry/font/parent writes.
4. Combat exit reuses the same prepared regions. Existing companion cases cover genuinely changed geometry/fonts, failed or incomplete preparation, ownership changes and native fallback.

The fixture cites the native source revision used to model that sequence. A source-matched sequence and passing visible-state assertions demonstrate a conditional regression repair. They do not demonstrate the sequence's frequency in the user's client, pixel appearance, taint safety or a causal reduction in stuttering.

## Package and evidence checks

The package contains both matching manifests, exactly their runtime Lua files and `Media/TimerSpacer.tga`. The verifier checks archive integrity, membership and byte equality against its input payloads. Tests, documentation, historical audit tools, settings files and bundled Edit Mode presets are excluded. No packaging step should overwrite a user's live `WTF`/SavedVariables or Edit Mode layouts. Current source hashes and recorded verification evidence are in [BUILD_VERIFICATION.md](BUILD_VERIFICATION.md).

A useful verification report names the source version/revision, interpreter type and version, suite results, package path/hash if produced, and whether any actual in-game test occurred. Distinguish:

| Evidence | Establishes | Does not establish |
| --- | --- | --- |
| Source review | The inspected code paths and permission/ownership checks. | That every path occurs in the client as modeled. |
| Lua fixture pass | Expected results under the test's explicit API/event model. | Native renderer, secret-value enforcement, protected-call behavior or performance. |
| Manifest/ZIP/checksum check | Packaged files match the verified source inputs. | Correct live installation or behavior. |
| In-game capture | Observed behavior on that build, character, settings and scenario. | Universal correctness across locales, scales, combat or other addons. |

## Live follow-up

Use [KNOWN_ISSUES.md](../KNOWN_ISSUES.md) for open reports. For timer work, record the exact addon/client versions, timer surface, combat state, UI scale and relevant native setting. Capture `/buitimers` while action/cast examples are active and before `/buiicons` or reload.

Check repeated casts/channels and empowered transitions; action 10/91-second transitions, GCD-only and minimum-duration cases; short buffs before/during/after combat and after layout/font changes; temporary enchants, private auras and reused buttons. Check the scales/locales actually used. Rendering and protected-call observations should be recorded separately from a measured frame-time comparison.

## Historical .309 audit

The [pinned audit](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78) used 11 runtime modules and its own snapshot fixtures. Its [baseline](AUDIT_BASELINE.md), `tests/snapshot-0.2.309/` and `tools/audit/` are retained for reproduction. In particular, the old audit packaging script has historical hard-coded paths. These inputs and their no-change audit instructions are not the current verification workflow.
