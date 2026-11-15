# AI control-plane sidecar contract

The optional sidecar exposes MCP stdio/streamable HTTP and JSON-RPC/REST/WS adapters over bounded IPC. It provides crash isolation and no-startup-dependency behavior: the native application starts and operates without a sidecar.

The sidecar never starts the native application, opens physical devices, or bypasses principal authentication, grants, output leases, typed-command validation, or safety fences. Loopback transport sessions are bounded; expired sessions require negotiation again. An uncertain mutation is recovered through its original request receipt, never an automatic retry.
