# 0.2.358 action minimum-gate preparation

## Live evidence

The .357 client capture reports one active action cell presenter, 14 stock fallbacks and 12 minimum-duration refusals. Two named samples report `gate-unsupported/combat-cold`; typography preparation is now plain/available. Short ordinary buffs still show whole seconds, with the latest aura fallback `aura ID secret`.

## Reproduced cause and correction

A failed gate is discarded at an existing safe retry epoch. If its prepared action is idle, unchanged-style and already-active fast paths skip gate preparation. A later restricted combat cooldown therefore needs a gate that is absent and cannot be created in combat. Idle positive-minimum changes and source-color changes have the same preparation gap.

Reuse the existing guarded positive-minimum gate preparation at initial setup, every successful safe prepared-action scan before the active early return, and the native minimum setter before refresh. Keep public minimum reads, native calibration, native clocks and GCD/minimum policy unchanged. Cached successes and failures avoid repeated construction within the existing safe epochs.

## Verification

Add actual-module regressions for an initially failed idle gate followed by the real combat-exit event, zero-to-positive minimum changes while idle, and changed native source color while idle. Confirm preparation occurs before combat; the first restricted combat update must display the current native-bound fixed digits without new resources. Retain refusal caching and external-writer/rollback ownership coverage. Run both native Lua engines and the normal package gate after review. Live rendering and any persistent native calibration refusal remain separate observations.

The ordinary secret-ID buff route needs a supported native duration owner; this gate patch does not grant aura identity access or change the buff rows. Investigate the native custom-container configuration separately before changing that presentation.
