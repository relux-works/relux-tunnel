# Remote relay protocol

## Purpose and boundary

OpenSSH has no UDP equivalent of `direct-tcpip`. `relux-relay` provides UDP
egress on the user-owned SSH host. It is launched as a child of `sshd` through a
long-lived exec channel and exchanges framed messages only on stdin/stdout.

The relay MUST NOT require root, a persistent service, `PermitTunnel`, a public
listener, or firewall changes. It MUST treat stderr as diagnostics and never mix
diagnostics with framed stdout.

## Deployment

The application bundle contains signed-release assets for:

- Linux x86_64 and arm64;
- macOS x86_64 and arm64.

Bootstrap sequence:

1. Probe `uname -s` and `uname -m` through an exec channel.
2. Select a bundled asset and expected SHA-256.
3. Create a user-owned directory under `$HOME/.cache/relux-tunnel`, falling back
   to a safe temporary user directory when needed.
4. If a matching executable is absent, stream it over exec stdin to a random
   temporary name with `umask 077`.
5. Verify with `sha256sum`, `shasum -a 256`, or a protocol-level self-hash where
   available; never accept a known mismatch.
6. `chmod 700` and atomically rename into a versioned path.
7. Execute `relux-relay --stdio --protocol 1`.

No SFTP implementation is required. Shell command construction MUST quote every
dynamic path and MUST NOT include profile secrets. Unsupported OS/architecture,
read-only homes, `noexec`, and missing utilities enter degraded mode with a
specific capability reason.

## Protocol v1

All integer fields are unsigned and network byte order. An exec session starts
with a handshake, followed by framed messages.

### Handshake

Client hello:

```text
magic[4] = "RLXR"
version:u16 = 1
flags:u16
maxFrame:u32
```

Server hello:

```text
magic[4] = "RLXR"
version:u16
status:u16
features:u32
maxFrame:u32
```

Unknown magic, unsupported version, nonzero status, or an unreasonable frame
limit closes the channel and produces a degraded-mode reason. Version
negotiation never guesses a lower framing format.

### Envelope

```text
frameLength:u32
type:u8
flags:u8
associationID:u32
payload[frameLength - 6]
```

`frameLength` covers `type` through the payload and MUST be between 6 and the
negotiated limit. Reserved flags MUST be zero. Invalid lengths close the relay
session; malformed datagram addresses reject only the association when safe.

Message types:

| Value | Name | Direction | Purpose |
| --- | --- | --- | --- |
| `0x10` | `UDP_DATAGRAM` | both | Destination/source address plus UDP payload |
| `0x11` | `UDP_ERROR` | server to client | Bounded error code for an association |
| `0x20` | `PING` | client to server | Health probe with opaque payload |
| `0x21` | `PONG` | server to client | Echoed health response |
| `0x30` | `CLOSE_ASSOCIATION` | both | Release sockets and state for one association |
| `0x31` | `CLOSE_SESSION` | both | Graceful whole-session shutdown |

### UDP payload

`UDP_DATAGRAM` reuses the HEV UDP-in-TCP relay layout:

```text
MSGLEN:u16 | HDRLEN:u8 | ATYP:u8 | DST.ADDR:variable | DST.PORT:u16 | DATA:variable
```

`MSGLEN` and `HDRLEN` follow the upstream HEV definition. `ATYP` supports IPv4,
IPv6, and domain names. On responses, the address is the source endpoint seen by
the relay. The adapter validates the inner length even though the outer envelope
also has a length.

`associationID` is allocated by the client and isolates application UDP
associations. The relay maps it to bounded socket state and idle timers. IDs are
not reused within one relay session until a close or expiry has completed.

## Resource limits and behavior

- Maximum frame, association count, queued bytes, datagram size, and idle timeout
  are negotiated/capped and included in diagnostics.
- Oversized UDP datagrams fail with a bounded error; they are never split by the
  relay protocol.
- Queue saturation drops datagrams and increments counters; it does not block the
  SSH event loop with unbounded retry.
- DNS associations receive latency priority but no protocol privilege.
- Relay exit, framing failure, or lane-A loss closes all relay associations and
  enters degraded mode until a clean handshake succeeds.
- The relay never logs payloads, domain names, or destination addresses by
  default.

## Build and compatibility

The relay and client share generated protocol constants and conformance vectors.
Golden tests cover every address family, limits, fragmented stream reads,
multiple frames per read, invalid lengths, unknown types, close behavior, and
version mismatch. A protocol change requires a new version or explicitly
backward-compatible feature bit.
