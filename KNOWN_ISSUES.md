# Known issues and bugs

**Sub-five-second cooldown precision (2026-10-26):** `0.2.256-five-second-decimals-test` shows one decimal on native action-button countdowns only below five seconds, while preserving whole seconds through 359 and larger compact units. Native secret-safe formatter support and visual appearance remain launch-client checks.

**Native cooldown seconds (2026-10-26):** `0.2.255-native-cooldown-seconds-test` adds native-format-only action-button cooldown counts in seconds below six minutes, with compact unit labels thereafter. This requires `NumericRuleFormatter` and `Cooldown:SetCountdownFormatter` on the Forever build; if either is unavailable, native text is preserved. CI mock tests do not prove live-client availability or taint safety.

**Player colors and status typography (2026-10-26):** `0.2.254-native-player-shadow-text-test` leaves Player frame health/name colors native while retaining other unit-frame class colors. Health/power numerical labels on unit frames and PRD remove outline flags and gain a subtle black shadow. Lua tests verify styling and client-boundary guards; native font resets and screenshot alignment still need launch verification.

**Shop notification (2026-10-26):** `0.2.253-shop-pip-test` adds bounded in-game Shop/Store micro-menu pip suppression and native reshow hooks. The Shop button remains interactive. The character-selection Shop marker cannot be changed by a normal character addon; in-game marker artwork awaits live Forever verification.

**Text presentation (2026-10-26):** `0.2.252-foundation-v16-combat-text-test` positions incoming Player hit text two physical screen pixels above the native frame while preserving health-bar horizontal centering, and omits status percentage decimals at 100%. Offline tests verify coordinate math and threshold formatting; client-specific animation offsets still require launch testing.

**Prelaunch offline correction (2026-10-25):** `0.2.251-foundation-v16-offline-fixes-test` repairs the Tracked Buff iterator contract, PartyOrder partial layout authorization, remaining visual hook retry flags, partial health-style restoration, and Soft Dark callback registration. New source-backed tests do not certify Forever's future live-client behavior.

**Lifecycle repair candidate (2026-10-25):** `0.2.250-foundation-v16-lifecycle-repair-test` addresses repeated micro-menu notifications, incomplete PartyOrder hook installs, failed secrecy probes, and color-write guard cleanup. Offline checks cannot prove safety in the unreleased Forever client. Native alpha-zero reuse and name-color snapshot ownership remain unverified.

**Hardening candidate (2026-10-25):** `0.2.249-foundation-v16-hardening-test` adds strict nameplate permission gates, original-alpha pooled compact-border restoration and independently retryable native update hooks, with Lua 5.1/5.4 CI regression coverage. All client-only behavior and previous Battleground observations remain open pending live testing.

**Layout ownership (2026-10-23):** `0.2.248-foundation-v16-layout-neutral` contains no bundled Edit Mode presets or automatic layout installation/replacement. Existing saved layouts are left untouched; any previous migration is not reversed.

**v16 suite update (2026-10-22):** this addon receives release-version metadata only. Its behavior is byte-identical to v15 apart from that version string. The three timing repairs are in bjarkiCC Model/Observer. The full v16 suite passes 49 regression scripts and 28 runtime syntax checks on both Lua 5.1 and Lua 5.4; live-client findings below retain their existing status. The behavior described in architecture section 31 remains applicable.

Current repository baseline (2026-10-26): **bjarkiUI 0.2.256-five-second-decimals-test**. The reports below are historical client observations and remain open pending current-client verification. Offline source, syntax and modeled-API checks do not close them. See architecture section 32 for the current layout-neutral behavior.

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
