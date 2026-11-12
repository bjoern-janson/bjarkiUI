# Verification: 0.2.355 timer spacing recovery

## Scope and evidence

The user reported a short buff showing whole seconds on one application and decimals with moving digits on the next, plus action-bar numerals often or always moving. This build repairs reproduced typography coverage/recovery gaps; it does not certify in-client pixel placement, secret-value enforcement, taint or performance.

Baseline: upstream .354 commit `1227e5baa97307d5ed56579a4dd6beb411dbb353`, tree `2379d76343304f96d4b9f50652fcc11a3eb68145`. Runtime edits are confined to ActionTimerSpacing, NativeDigitCells and BuffPresentation, plus the version constant/manifests. Native fonts, clocks, action 10/91-second thresholds, native buff units, countdown preferences, minimum/GCD policy and approved portrait/party changes are preserved.

## Reproduced failures and repairs

- A prepared glyph map existed while the native opaque-duration buff path still wrote plain `1.7`. Prepared native formatter literals now cover supported short decimals; secret output goes unchanged to the original sink.
- Safe buff setup never retried a failed optional calibration on an unchanged layout, and inherited scale changes retained the old absolute-scale map. Existing safe setup now refreshes typography without rebuilding unchanged geometry; ordinary duration ticks do not measure fonts or construct formatters.
- Action receiving cells remained at scale 1 when the native source label used 1.5. Receiving scale/text scale and style resynchronization now match the source. A rejected style write leaves the native stock countdown visible until safe recovery.
- Rejected mapped action formatters survived every retry epoch. Failure caching now permits one fresh attempt per existing safe epoch, preserving successful mappings and bounding repeated failures.
- Review caught a new literal-rule rounding mismatch at fractional boundaries. A failing midpoint regression led to sampling the original native formatter around double/binary32 transitions and validating the mapped rules against it before use.
- Existing typography failures now retain fixed public preparation-stage labels. The existing diagnostic reports cached profiles, without inspecting live timer data or printing arbitrary native errors.

Focused regressions were observed failing before each runtime correction. Independent review found no remaining actionable issue in the changed action/buff ownership and fallback paths.

## Final local verification

- Native Lua 5.1.5: all 36 top-level suites passed; all 16 runtime modules and test sources compiled through native `loadfile`.
- Native Lua 5.4.6: all 36 top-level suites passed; the same native `loadfile` compilation passed.
- Aura presentation: 226 cases passed on each interpreter, including opaque output, current owners, calibration retry, inherited scale, refusal recovery, combat reuse and exact rounding boundaries.
- Action digit suite: 5,293 assertions; static action numeral suite: 464 public binding transitions plus retry checks; static buff suite: 8 cases.
- Matching manifest versions/load order, `git diff --check`, archive integrity, exact 19-file membership and packaged byte equality passed.

No standalone `luac` was available locally. Compilation above used each native interpreter's `loadfile`; it is not reported as a `luac` run. The stacked draft PR does not match the workflow's `main` trigger, so these are local verification results, not a claim of GitHub CI execution.

## Deliverable

`bjarkiUI-0.2.355-Timer-Spacing-Recovery.zip` contains the normal `bjarkiUI/` addon folder: 16 runtime modules, two matching manifests and the existing spacer texture. Size: 132436 bytes.

SHA-256: `258c92997c51ea4e6f28bc4f6e3a6d8fe03ae047059976a640b3c01ca3c4e775`.

## Remaining live limits

Secret/missing aura identity can still retain native whole seconds; no supported alternate identity lookup or clock was established. Unsupported calibration/rules retain the plain native presentation. A newly changed font profile can remain plain until existing safe setup prepares it. The native action minimum-gate mapping was not relaxed without client evidence. Actual rendered stability, repeated applications/combat transitions and frame-time cost remain live checks in [KNOWN_ISSUES.md](../KNOWN_ISSUES.md).
