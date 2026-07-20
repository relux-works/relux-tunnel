# ReluxNIOSSH upstream provenance

ReluxNIOSSH is a minimal source fork of
[`apple/swift-nio-ssh`](https://github.com/apple/swift-nio-ssh).

| Field | Value |
| --- | --- |
| Upstream tag | `0.14.1` |
| Upstream commit | `31cdc3c3391a10460dedf1170530cf651d2ca496` |
| Source archive SHA-256 | `0b135087e76cb03e33f544484f21e1c3ba3b967f8a0ba2aead960ce4d0d06e6a` |
| License | Apache License 2.0 |
| `LICENSE.txt` SHA-256 | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |
| Fork package identity | `ReluxNIOSSH` |
| Preserved library product/module | `NIOSSH` |

The archive is the GitHub commit archive at:

```text
https://github.com/apple/swift-nio-ssh/archive/31cdc3c3391a10460dedf1170530cf651d2ca496.tar.gz
```

The fork checks in `Package.resolved` to lock the audited graph. Its resolved graph is SwiftNIO
`2.101.3`, Swift Crypto `4.5.1`, Swift Atomics `1.3.1`, Swift ASN.1 `1.7.1`,
Swift Collections `1.6.0`, and Swift System `1.7.4`, at the exact revisions in
that file.

Run the fail-closed provenance and delta check from the repository root:

```sh
make check-reluxniossh
```
