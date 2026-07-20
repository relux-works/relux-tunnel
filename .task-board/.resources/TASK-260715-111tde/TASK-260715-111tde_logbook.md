# TASK-260715-111tde logbook

## 2026-07-20 — Binding freeze

- The attached reviewer override supersedes the earlier foundation-blocked
  analysis. Gate A0 and `TASK-260715-32umrc` do not govern this reusable wire
  contract and must not remain dependency edges.
- Accepted ownership is Swift `ReluxTunnelCore`, Go 1.26.5 at `relay/`, and the
  candidate-neutral `SSHExecChannel` transport seam. There is no Swift/Go FFI.
- The binding selects canonical JSON plus a build-only Python-standard-library
  generator, checked-in value/metadata bindings, handwritten codecs/state, and
  independently audited shared vectors.
- The fixed v1 hello cannot carry build identity. The selected resolution is a
  separate bounded `--identity --protocol 1` exec record matched against the
  signed manifest before opening the long-lived `--stdio --protocol 1` channel.
- The HEV fixture proves that `MSGLEN` is DATA length and `HDRLEN` includes the
  three-byte prefix. Consequently a domain form is limited to 248 bytes by the
  one-byte `HDRLEN`, even though the domain length field itself is one byte.
- `TASK-260715-18owh7` remains the sole owner of numeric association, queue,
  datagram, idle, and hard-ceiling values and their v1 compatibility mechanism.
  No duplicate task or placeholder value was introduced.
- PlantUML 1.2026.6 rendered both diagrams with internal Smetana layout. System
  Graphviz remains broken because `dot` cannot load `libltdl.7.dylib`; this is a
  tooling anomaly only and does not block the authoritative sources or renders.

