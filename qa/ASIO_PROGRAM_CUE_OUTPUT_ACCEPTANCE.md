# ASIO PROGRAM/CUE output acceptance

The canonical `syndocal_asio_bridge.dll` carries input ABI/schema v2 and PROGRAM/CUE/full-duplex ABI/schema v3 under one process-wide lease. Old names, old ABI, load/symbol faults and unapproved bridge identities fail closed.

Required acceptance:

- Explicit driver, rate, native format, fixed buffer and PROGRAM/CUE channel routes are validated before output. Shared-ASIO routes use one clock; ASIO PROGRAM plus explicit WDM CUE reports independent clocks and never silently falls back.
- Full-duplex ownership prevents competing bridge sessions. Start/stop/free, cancellation, terminal fault, disconnect, reset/resync, XRUN and recovery preserve exact ownership and observable state.
- Deterministic regression tests prove routing, framing, stale request rejection, bounded callbacks, no-callback timeout, silence and resource cleanup.
- The frozen native artifact passes the advertised real-device matrix, audible PROGRAM/CUE separation, hot-plug/fault recovery, long soak and physical latency checks.
- SDK licensing, separate artifact/notice workflow, runtime inventory and clean-machine installation pass before distribution.

All current physical and distribution gates remain open. Prior short runs and source tests are not acceptance for a different artifact or ABI. [Local-only build boundary](ASIO_SHOW_LOCAL_ONLY.md) and [SDK pin](ASIO_SDK_PIN.json) remain authoritative.
