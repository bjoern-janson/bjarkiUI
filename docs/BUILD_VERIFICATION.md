# Verification record for 0.2.334

This records the source and offline checks for the update from GitHub main
0.2.323 to 0.2.334. It is not a claim of verified live-client rendering,
taint safety, protected API compatibility, or frame-time improvement.

- Runtime: 13 Lua modules in matching standard and Camelot manifests.
- Current regression suites: 27 files directly under `tests/`, run on both
  Lua 5.1 and Lua 5.4. Historical subdirectories are separate baselines.
- Package: 16 files under one `bjarkiUI/` folder.
- The portable verifier rebuilt a package whose every member matched the
  previously delivered 0.2.334 ZIP byte for byte.
- Cross-addon startup was checked in both addon load orders with empty,
  compatible and incompatible evidence bridges on both Lua engines.

## Source identity

[Source SHA-256 manifest](SOURCE_SHA256_0.2.334.txt) records the runtime files,
manifests and any shipped media. Paths are relative to the addon root.
This manifest is historical evidence for 0.2.334; update it only when making
an intentional new verification record, not to silence a mismatch.

The previously delivered `bjarkiUI-0.2.334-COMPLETE.zip` had SHA-256:

```text
8b7a1a288c55f6ab7e0378145c50ced0f1d8316b413b0d6f3cd25b92c43c3c66
```

ZIP timestamps and other archive metadata can differ between builds. Compare
the member hashes for source identity rather than treating a different archive
hash alone as a runtime change.

## Reproduce

From the repository root, use Python 3.10 or newer and Lua/luac 5.1 and 5.4:

```sh
python3 tools/verify.py --output ../bjarkiUI-0.2.334-COMPLETE.zip
```

The output path must not exist and must be outside the repository. Without
`--output`, the command validates manifests, compiles modules and tests, and runs
the current suites without creating a package. See [testing](TESTING.md) for
focused checks and the optional embedded Lua runner.

Local publication checks used Lupa's Lua 5.1 and Lua 5.4 engines. The
[package workflow](../.github/workflows/package-addon.yml) uses standalone
Lua/luac for both versions and produces the installable artifact. Check the
[workflow runs](https://github.com/bjoern-janson/bjarkiUI/actions/workflows/package-addon.yml?query=branch%3Amain)
for the exact commit before downloading.

## Evidence limit

Current open client reports remain in [known issues](../KNOWN_ISSUES.md).
Source comparisons and mocked API regressions establish the tested code paths;
they do not establish that every live timer, protected aura, or combat transition
behaves as modeled.
