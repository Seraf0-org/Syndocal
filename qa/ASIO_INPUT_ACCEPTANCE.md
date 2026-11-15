# ASIO input acceptance

Windows ASIO is a product release requirement. The default MIT/WASAPI package and the separately licensed, non-default ASIO bridge remain distinct. SDK identity and redistribution approval are pinned in [ASIO_SDK_PIN.json](ASIO_SDK_PIN.json).

Required acceptance for the frozen artifact:

- Explicit device identity, catalogue generation, rate, format, channel mix and fixed buffer are revalidated before start. Ambiguous, stale, unsupported and missing selections fail closed without another-device/backend fallback.
- Open/start/stop/free ownership, process-wide exclusivity, repeated lifecycle, device loss, hot-plug, reset/resync, XRUN, no-callback timeout and recovery preserve observable terminal status.
- Persistence retains the selected identity and rejects invalid/future data; refresh remaps only an unambiguous exact device identity.
- Deterministic tests cover callback framing, bounded queues, terminal event propagation, silence clearing and stale-generation rejection.
- Real-device acceptance covers the advertised rate/channel/buffer matrix, independent vendors, long soak, audible/reactive output and physical latency on the actual artifact.
- Distribution licensing, bridge/runtime inventory, notices, packaging and clean-machine installation are reviewed separately.

These gates remain open until current device and artifact evidence is recorded. Unit tests or a short smoke do not establish physical acceptance. See [PROGRAM/CUE output](ASIO_PROGRAM_CUE_OUTPUT_ACCEPTANCE.md).
