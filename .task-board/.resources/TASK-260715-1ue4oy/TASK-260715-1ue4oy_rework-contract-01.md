# Rework contract 01

Implement only the blocking reviewer findings in TASK-260715-1ue4oy_reviewer-results-20260819.md.

- Replace pathname read_bytes validation with descriptor-owned no-follow opens, fstat size gates before allocation, a hard manifest cap, exact asset-size checks, and bounded/streaming digest plus identity validation.
- Publish generated bundles through an exclusive randomized sibling staging directory with ownership-aware cleanup and atomic replacement; recover from partial/stale output.
- Add regression coverage for oversized manifest/assets, symlink and replacement races/path-safety, injected interruption, stale replacement, cleanup, and deterministic regeneration.
- Format every modified Python file, including scripts/check-generated-provider-graph.py.
- Rerun focused manifest/bundle/provider/Apple unsigned gates, core boundary checks, and the broad Swift suite. Preserve the previous HEV timing-flake history; do not modify unrelated HEV code/tests merely to make this task green.
- Preserve build-host safety: no signing, install, NetworkExtension preference mutation, tunnel start, route or DNS change.

Do not broaden the task or weaken validation.