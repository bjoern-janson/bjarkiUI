# Buff ten-second threshold implementation plan

Use superpowers:executing-plans for this focused correction, with independent fixture migration and a fresh final review.

**Spec:** [Strict buff decimal threshold](../specs/2026-11-14-buff-ten-second-threshold-design.md).

## Constraints

Decimals require a public sub-ten remainder or native selection through a genuine duration object. Preserve fonts, native clock/settings, ownership and retries. No new timing source, widget, polling, unsafe scalar operation or appearance inference. Do not count a fallback as successful decimal formatting.

## Tasks

- [x] Update actual-module fixtures and record a failing 66.2 strict-threshold case; keep older sink tests active using supported sources.
- [x] Remove only the broad opaque numeric fallback and identify its native fallback accurately in diagnostics.
- [x] Verify focused suites on Lua 5.1/5.4, independently review, and resolve concrete findings.
- [x] Update current release instructions, run all 37 suites on both runtimes, and verify the 19-file ZIP.
- [ ] Commit, publish the authorized stacked draft, save the installable ZIP, and explain remaining native fallback limits.

Verification evidence and package details are recorded in [VERIFICATION_0.2.363.md](../../VERIFICATION_0.2.363.md). The last task necessarily follows this committed source snapshot; its completion and resulting identifiers are recorded in the external `ui363-evidence/` release ledger.
