# Active macOS profile-loader scope

Implement against the accepted TASK-260715-29ws8l contract and digest 8c81d2dc15904d6648f1333620370ac2c8c455e081fe6e98b4480a92c64bd5f2.

The macOS host and root provider do not share an App Group. Decode the full bounded non-secret SSHProfileSnapshotV1 from NETunnelProviderProtocol.providerConfiguration. Preserve the manager ownership/contract markers defined by TASK-260715-1q4qhw. Capture one immutable configuration generation before credential lookup. No Keychain access, secret bytes, routes, network calls, or profile writes in this task. Use Swift Testing and attach task-scoped non-secret evidence.