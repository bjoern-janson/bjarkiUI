# Known issues and bugs

**Layout ownership (2026-10-23):** `0.2.248-foundation-v16-layout-neutral` contains no bundled Edit Mode presets or automatic layout installation/replacement. Existing saved layouts are left untouched; any previous migration is not reversed.

**v16 suite update (2026-10-22):** this addon receives release-version metadata only. Its behavior is byte-identical to v15 apart from that version string. The three timing repairs are in bjarkiCC Model/Observer. The full v16 suite passes 49 regression scripts and 28 runtime syntax checks on both Lua 5.1 and Lua 5.4; live-client findings below retain their existing status. The behavior described in architecture section 31 remains applicable.

Current repository baseline (2026-10-23): **bjarkiUI 0.2.248-foundation-v16-layout-neutral**. The reports below are historical client observations and remain open pending current-client verification. Offline source, syntax and modeled-API checks do not close them. See architecture section 32 for the current layout-neutral behavior.

Original status recorded 2026-10-08 for **bjarkiUI 0.2.90-local**.

The items below reflect reports and diagnostic output from Battleground
sessions. They remain open until checked in the live client against this build.
A report describes a visible symptom; it does not by itself establish the
failing code path or root cause.

## Opposing-faction class colors in Battlegrounds

- Enemy player health bars have been reported white or otherwise not
  class-colored, even when the nameplate shows the player's class color.
- Enemy Target-of-Target and Focus-of-Target health bars have also been
  reported with missing or incorrect class colors.
- A `/bui colors` capture showed the enemy target and targettarget as
  `player=true`, but `class=unknown` and no usable nameplate color in that
  diagnostic context. This confirms an unknown input at that point in the
  diagnostic path; it does not identify why the class data was unavailable.

Keep class identity, unit binding, relation/readability, native bar-color
writes, and fallback selection as separate diagnostic stages. Do not treat a
white bar as proof that the class-color lookup itself was reached.

## ToT/FoT visibility and color

During earlier debugging, changing the display CVar made ToT/FoT frames
disappear. The user restored them with `show=1` and `mode=nil`; the frames
returned, while the opposing-faction color issue remained. Do not change those
CVars as a color workaround. Frame visibility and health-color selection are
separate issues.

## Verification boundary

No live WoW test has confirmed these reports fixed in 0.2.90-local. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the frame/color implementation and
reported BG diagnostics. Pet portraits and aura category failures are tracked
in the [bjarkiPortraits issue list](https://github.com/bjoern-janson/bjarkiPortraits/blob/main/KNOWN_ISSUES.md).

## Historical post-patch follow-up: 0.2.220 (2026-10-17)

- Opposite-faction and Focus class-colored health fills, native redraws after duels, and occasional wrong-color reports require renewed verification on the current 1.60.1 client. Source guards and screenshot examples do not establish full coverage across Battleground secrecy transitions.
- A historical aggro/flash border remaining after untargeting motivated narrower Target/Focus highlight handling. Recheck the actual target/focus warning lifecycle on the current build; do not disable legitimate flash effects to mask a stale state.
- Compact ToT/ToF position, Player/Target/Focus status text optical anchors and nameplate CC edge avoidance have been visually calibrated but remain dependent on UI scale and current native artwork. Any future alignment changes should use native screen-pixel evidence without restoring obsolete bar geometry.
- Minimap day/night decorative glyph removal and action-button macro-name suppression need in-game verification under loading-screen changes, Edit Mode and alternative action-bar visibility. The initial candidate uses native objects only; retain hotkey/stack text and click functionality.
- Historical 0.2.220 builds bundled an Edit Mode preset. That behavior was retired in 0.2.248; the current addon does not install, replace, or activate layouts.
- Four-Lua-module syntax checks and focused offline assertions pass; some older historical test expectations also fail against the unchanged pre-sync local source. Do not claim complete live taint correctness or a uniformly green historical regression suite on this basis.
