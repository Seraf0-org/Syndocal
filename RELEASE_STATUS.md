# Syndocal 1.2.0 release status

Current product version: `1.2.0-rc.3` (release candidate).

## Verified

- Display output at 60 fps with three video layers and group effects on a
  2560×1600 display, in a six-session campaign and a 30-minute sustained run.
- MIDI control and LED feedback with a hardware controller (DAW mode).
- Automated checks: TypeScript type checking, frontend build, release metadata
  and self-tests, signing workflow and NSIS pipeline contracts, macOS artifact
  workflow, and the Rust application test suite.

## Open before 1.2.0

- Installation on a clean machine and an N→N+1 signed update.
- The full Windows ASIO device, lifecycle and licence matrix.
- Syphon interoperability with external macOS clients.
- Windows Authenticode signing through SignPath Foundation (application pending).

## Distribution

- Windows: NSIS installer, not Authenticode-signed (SmartScreen may warn); the
  updater payload is signed with the production updater key.
- macOS (Apple Silicon, macOS 12+): `.pkg`, not signed or notarized.

See [installation](README.md#インストール), [signing policy](qa/CODE_SIGNING_POLICY.md),
[update acceptance](qa/UPDATE_RELEASE_RUNBOOK.md), [ASIO input](qa/ASIO_INPUT_ACCEPTANCE.md)
and [ASIO output](qa/ASIO_PROGRAM_CUE_OUTPUT_ACCEPTANCE.md).
