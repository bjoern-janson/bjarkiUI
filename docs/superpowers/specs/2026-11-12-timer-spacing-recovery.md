# Timer spacing recovery

## Report and acceptance

On v0.2.354 the user first observed a short buff displaying `2 s`, then reported that its next application displayed `1.7` but the digits moved. Action-bar countdowns also often or always appeared proportional. The accepted presentation remains the current Blizzard fonts with stable digit positions and tenths below ten seconds. Preserve action whole seconds through 90.99 and rounded-up minutes from 91, native buff suffixes, native countdown preferences, clocks, GCD/minimum policy, and all approved portrait/party changes.

## Established gaps

- The public-identity native-duration buff route formats opaque remaining time with a plain `%.1f` formatter. It never uses the already prepared native-font digit map. Decimals can therefore work while fixed spacing is absent.
- A failed optional buff glyph calibration can remain nil indefinitely because unchanged-layout preparation returns before retrying it. Inherited effective-scale changes can likewise retain a map calibrated at the previous absolute scale.
- Action digit maps are calibrated using the stock label's effective/text scale, while replacement cells copy only its font/colors/shadow. Scale-only changes are missing from style comparison. A rejected mapped action formatter is also cached permanently, beyond the existing safe retry epoch.
- The exact in-client reason for the original plain/whole-second paths remains unproven. Source fixtures demonstrate these conditional gaps, not native rendering or performance. The current secret-ID gate remains required; no unsupported identity lookup or estimated clock is introduced.

## Design

Prepare optional fixed-width native buff formatter rules from validated glyph maps outside combat. Forward the original opaque duration object and its formatted output through their existing supported sinks. Reuse only current physical label/owner/profile receipts; retain the ordinary formatter on unsupported preparation. Refresh optional buff typography at existing safe lifecycle setup without rebuilding unchanged geometry or adding work on every timer tick.

Make action replacement cells inherit the same relative scale and text scale used for calibration, and include those properties in the existing restore-then-resync handoff. Retry rejected glyph formatters once per existing safe epoch. Preserve the separate decimal point and suffix formatters.

Keep fixed public failure-stage metadata from existing typography preparation and include it in the existing `/buitimers` readout. No new command, polling loop, hidden value logging, or native minimum-gate relaxation.

## Verification boundary

Regressions must first fail on .354 and check visible prepared output, scale/profile changes, owner changes, denied writes and bounded retries. Run all current suites on native Lua 5.1 and 5.4, then validate the normal addon ZIP. Live decimal consistency, rendered digit stability, taint and frame time remain client observations.
