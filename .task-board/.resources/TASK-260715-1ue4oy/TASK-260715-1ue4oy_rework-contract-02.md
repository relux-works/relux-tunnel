# Rework contract 02

Implement exactly the three blocking findings in TASK-260715-1ue4oy_reviewer-results-rework-02.md.

1. Initial publish must use an atomic no-replace primitive anchored to the parent directory. If a destination appears in the absent-case race, preserve its inode/content and fail closed or retry safely; never overwrite or delete it. Add the exact race regression.
2. Archive SHA verification and tar parsing must use the same O_NOFOLLOW-opened descriptor/file object: hash, rewind, then parse. Add pathname replacement/symlink and bounded hostile-metadata regressions.
3. sha256_file and write_new_file_at must retain explicit fd ownership until fdopen succeeds and close on every injected fdopen failure. Prefer fchmod over reopening output names. Add fault-injection leak regressions.

Preserve the already-passing 15 tests, atomic exchange cleanup, interruption and stale-replacement behavior. Rerun focused tests, formatting, deterministic/bundle checks, provider graph, unsigned Apple builds, core/protocol gates, and broad Swift tests. Do not touch real VPN state.