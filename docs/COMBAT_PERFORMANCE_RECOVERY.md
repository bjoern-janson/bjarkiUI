## 0.2.336 — avoid redundant Soft Dark scans on clean combat exits

Blizzard issues PLAYER_REGEN_ENABLED on every combat exit. A fully
initialized Soft Dark theme previously traversed unit chrome, bag and
window regions and PRD artwork on each such event despite no color or
ownership transition. Now it skips a clean exit when no previous work
was deferred, no setter refused a tint and no Edit Mode recovery is
pending. Pending/rejected work still receives one safe OOC repair.

`tests/combat-softdark-idle.lua` runs the actual SoftDark.lua event
callback against a fake texture. It verifies initial painting, zero
reads/writes on a clean regeneration event and recovery after a blocked
combat invocation. This is a source-level improvement, not an
in-client benchmark. The addon remains fully enabled.
