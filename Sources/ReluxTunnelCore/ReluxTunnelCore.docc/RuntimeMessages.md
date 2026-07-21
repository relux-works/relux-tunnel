# Runtime Messages

Use deterministic, bounded v1 JSON models to exchange non-secret configuration
references and immutable runtime state without importing platform or transport
types into `ReluxTunnelCore`.

## Wire families

The legacy `version` request and response remain an exact exception with only
`kind` and `protocolVersion`. Every M1 app message has required
`protocolVersion`, `kind`, and `schemaVersion` fields. `requestID` is the only
optional common field and defaults to absent. The system-owned provider
configuration and start request are not app messages; they carry a required
`schemaVersion` instead of a command kind.

| Model | Version | Maximum JSON bytes | Required payload fields | Defaults |
| --- | --- | ---: | --- | --- |
| `ProviderVersionRequest`, `ProviderVersionResponse` | protocol 1 | 4 KiB | `protocolVersion`, `kind=version` | request protocol version 1 when constructed |
| `TunnelConfigurationReference` | schema 1 | 4 KiB | `schemaVersion`, `profileIdentifier` | current schema when constructed |
| `RuntimeStartRequest` | schema 1 | 4 KiB | `schemaVersion`, `configurationReference` | current schema when constructed |
| `RuntimeConfigurationSnapshot` | protocol 1, schema 1 | 64 KiB | generation, profile identity/revision, credential reference, trust reference, compatible route mode | absent `requestID` |
| `RuntimeCommand` | protocol 1, schema 1 | 4 KiB | one read-only command kind | absent `requestID` |
| `RuntimeProtocolCapabilitiesSnapshot` | protocol 1, schema 1 | 4 KiB | protocol range and per-kind schema ranges | current protocol range; absent `requestID` |
| `RuntimeCapabilitySnapshot` | protocol 1, schema 1 | 16 KiB | generation, sequence, TCP, safe DNS, UDP, route mode, route-installed, and health facts | absent `requestID`; capability facts never default while decoding |
| `RuntimeLifecycleSnapshot` | protocol 1, schema 1 | 16 KiB | generation, sequence, lifecycle/route state, and all capability facts | absent `requestID` and `error` |
| `RuntimeDiagnosticsSnapshot` | protocol 1, schema 1 | 64 KiB | generation and sequence | absent `requestID`; empty aggregate collections |
| `RuntimeProtocolError` | protocol 1, schema 1 | 4 KiB | finite error code and supported protocol/schema ranges | current supported ranges; absent `requestID` |

All opaque identifiers encode as UUID strings. Configuration models have no
arbitrary byte fields, free-form parameter dictionary, private-key field, or
passphrase field. Credential and trust values are lookup references only.

## Compatibility and rejection

`RuntimeMessageCodec` and `RuntimeConfigurationCodec` emit sorted-key JSON and
enforce the model-specific encoded limit in both directions. Decoding rejects
invalid UTF-8, non-object roots, trailing bytes, duplicate keys (including
escape-equivalent keys), nesting deeper than 16 levels, corrupt JSON numbers,
missing required fields, unsupported protocol/schema versions, unknown input
kinds, and unknown provider-input values through `RuntimeMessageCodecError`.
The start-request decoder validates both its own schema version and the nested
configuration-reference schema version before returning the request.

Unknown object fields are ignored and disappear on re-encoding. Unknown output
lifecycle, route-state, or route-mode values project to `unknown` with every
capability false. Known capability fields remain required, so their absence is
corrupt rather than an optimistic default. Diagnostics generation and sequence
remain required while absent aggregate collections decode to their documented
empty defaults. `RuntimeSnapshotPosition.isNewer(than:)` implements the
generation/sequence discard rule.

The v1 capability schema deliberately has independent `tcp`, `safeDNS`, `udp`,
`routeMode`, `routesInstalled`, and `healthy` fields and no aggregate full-mode
claim. M1 producers publish TCP and safe DNS independently while UDP remains
false.

## Provider routing and retirement

`TunnelProviderAdapter` accepts only `getProtocolCapabilities`,
`getRuntimeSnapshot`, `getCapabilities`, and `getDiagnostics` as v1 provider
commands. Although `RuntimeCommand` keeps `requestID` optional for wire-model
compatibility, the provider router requires a UUID for every v1 request. It
serializes reservations per runtime generation, bounds active and recently
completed identifiers, rejects concurrent duplicates, and copies the request
identifier into every successful response or post-decode protocol error.

Each non-nil Apple response handler is wrapped in a once-only gate. Stop retires
the generation and completes every accepted pending gate without waiting for a
late snapshot or diagnostics callback. Nil handlers are never retained. Source
lookups race the same retirement signal, so their late results cannot update or
retain another provider generation.

Provider cleanup is one joined operation with an injected ten-second graceful
budget. Cancellation fans out through a fixed-capacity cleanup registry; expiry
force-closes every registered controllable handle and records only a finite
`cleanup_deadline_exceeded` error plus the raw numeric Apple reason. No localized
platform error text, configuration, credential, endpoint, or traffic value is
added to the message or cleanup diagnostics.

## Host projection

`VPNSessionController` sends the read-only protocol, lifecycle, and capability
requests only while the freshly read exact `NETunnelProviderSession` status is
connected. Each request has a UUID correlation identifier and a three-second
monotonic deadline. A combined provider projection requires matching lifecycle
and capability positions that are strictly newer than the controller's last
accepted generation/sequence position. Relaunch creates a new controller with
no app-owned runtime history and requests the current facts again.

System session status remains independent: every non-connected status clears
provider capability immediately, while missing, nil, timed-out, corrupt,
unsupported, wrong-request, mismatched, stale, and late responses leave a
connected system session capability-unknown. Controller retirement removes
observers and cancels host waits without stopping the system tunnel.
