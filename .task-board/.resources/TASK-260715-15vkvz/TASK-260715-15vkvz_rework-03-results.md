# TASK-260715-15vkvz rework 03 evidence

Both Apple `NEVPNStatusDidChange` adapters now register before their authoritative status read. The observation seam is injectable for deterministic ordering tests and uses a locked registration/retirement handshake. If a terminal notification fires synchronously before registration returns its token, completion retires first and the returned token is immediately unregistered. A notification-free transition during registration is caught by the post-registration status recheck. Resolution, cancellation, duplicate notifications, late notifications, and deinitialization cannot produce a second callback or a second unregister.

The Swift Testing matrix runs every scenario against both `IOSVPNStatusObservation` and `MacOSVPNStatusObservation`: terminal-before-registration, terminal-during-registration, synchronous notification-before-token-return, notification-first completion, duplicate/late notification retirement, and cancellation retirement. This directly proves that an already-terminal connection does not wait for the repository's 15-second stop deadline.

Prior guarantees remain intact: the FIFO repository gate, exact signed/unsigned `NSNumber` version decoding, fresh-manager authority, least-data persistence, and zero-write handling for unrelated/type-confused/future managers all remain covered by the focused suite.

Validation on Xcode 26.5 / Swift 6.3.2:

- `swift test --filter OwnedVPNManagerRepositoryTests`: passed, 33 tests in 1 suite.
- `swift test --sanitize=thread --filter OwnedVPNManagerRepositoryTests`: passed, 33 tests in 1 suite with no Thread Sanitizer report.
- `make validate-core`: passed, 251 tests in 24 suites plus the post-test `swift build`.
- `swift format lint --strict --recursive Sources Tests Package.swift`: passed.
- Tracked and task-owned untracked `git diff --check`: passed.
- `task-board validate`: passed.
- Generic iOS Simulator `ReluxTunnelIOSAdapter` Xcode build with signing disabled: passed.
- Generic macOS `ReluxTunnelMacOSAdapter` Xcode build with signing disabled: passed.

One intermediate test-only `#expect` involving an Objective-C protocol existential triggered an Xcode 26.5 compiler crash. The nonessential token-identity assertion was removed; token retirement remains proven through exact unregister counts, and all required final gates pass.
