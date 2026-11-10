# Working on bjarkiUI

Start with the visible symptom in the [code map](docs/CODE_MAP.md). The two TOCs define runtime load order. For build and test commands use the [package workflow](.github/workflows/package-addon.yml). The current regressions are the Lua files directly under [tests](tests).

- For a timer issue, first identify the physical label or cooldown that displays the value. Follow the native writer, the addon's hook, and the cleanup that restores ownership when the button, cast or label changes.
- For a frame layout issue, distinguish the frame's native anchor from the addon's last successful write. Check combat entry, native relayout and frame reuse before changing the write path.
- Forward opaque duration objects to the native sink. Keep restricted Target and Focus aura frames under native control. Preserve Blizzard fonts and event-driven timing updates.
- Use the Lua 5.1 compatibility preload when running UI fixtures under 5.1. A useful regression checks what the simulated frame displays and which native setters were called.

The frozen 0.2.309 audit, its checksum script and `tests/snapshot-0.2.309/` belong to the historical baseline. Its branch preserves the exact inputs for reproduction. [Pinned audit](https://github.com/bjoern-janson/bjarkiUI/tree/d1797e392e0eb466906632e4dc047eb830b2ac78)
