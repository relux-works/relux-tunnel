# TASK-260908-grpera housekeeping outcome

Ready for review. Operational cleanup only; no source, tests, branch, signing material, global cache or VPN changes. Finished at 2026-09-08T01:32:01.415672 Asia/Tbilisi, before 04:59 on 2026-09-08. No successor started.

## Measurements

- .temp before: 55,487,368 KiB; after: 53,480,956 KiB; observed decrease: 2,006,412 KiB.
- Exact allowlisted cache allocation removed: 2,015,328 KiB (1.922 GiB), across 20 paths.
- APFS caveat: du allocation is not guaranteed physical space reclaimed: clones, snapshots, shared extents and concurrent filesystem activity affect df. The df delta is an observation, not an attribution.

### df before (KiB)
```
Filesystem   1024-blocks      Used Available Capacity  iused      ifree %iused  Mounted on
/dev/disk3s5   971350180 730419440 218163668    78% 12566177 2181636680    1%   /System/Volumes/Data
```
### df after (KiB)
```
Filesystem   1024-blocks      Used Available Capacity  iused      ifree %iused  Mounted on
/dev/disk3s5   971350180 728903968 219679136    77% 12562222 2196791360    1%   /System/Volumes/Data
```

## Selection and exclusions

Inspected .temp top-level allocation, registered worktrees, large candidate task directories, exact cache contents, Git status, Git ignore rules, and live processes. Only TASK-260715-1idq8c ModuleCache.noindex directories were allowed. Source task status was done. Every selected directory contained only compiled .pcm/modulevalidation/timestamp cache files (see manifest), no symlinks, no nested repository, and no writes in the last seven days. Re-running the original Xcode build with the same DerivedData path regenerates SDK modules. No test evidence was removed.

Skipped all other candidates, including Go caches and CompilationCache.noindex, rather than expand deletion without equivalent proof. Source/history checkouts and broad DerivedData/run/task directories remain intact. Entire Shared Runtime STORY-260715-1y04r0, deadline-20260908, spawn-runs, logwork, prompts, evidence, attachments, signing material, and every worktree were outside the deletion allowlist. No exclusion was used as a traversal/deletion target.

## Validation and actual execution

- Initial required set_status: exit 0.
- Tool readiness: git, Python, du, df and lsof produced expected outputs. Evidence directory: .temp/TASK-260908-grpera.
- Every allowlisted path: git check-ignore -v exit 0; git ls-files exit 0 with empty output. Exact rule included in attached manifest.
- Global lsof -nP -Fpn immediately before deletion: exit 0, empty stderr; no open path at or beneath any candidate DerivedData parent. ps exit 0; no process arguments referencing those parents. This is point-in-time observable process evidence, not a guarantee against future processes.
- Deletion executed inline through shutil.rmtree on the materialized exact 20-path allowlist; all paths absent afterward. Python execution exit 0.
- 46,529 other files in source task tree: inode, size and mtime identical before/after.
- Registered worktree porcelain bytes identical before/after (11 registrations); independently checked with Python and cmp.
- du before/after and df before/after completed with exit 0.
- No build/test run needed or performed; no production gating code shipped, so negative production tests are not applicable. All cleanup evidence was collected in this run; no previously attached validation was accepted as a substitute.
- One exploratory board projection used unknown acceptanceCriteria field and failed; retried successfully with checklist-only projection. No filesystem decision depended on the failed read.

## Exact deletion allowlist

| Path | Allocated KiB | Regeneration | Git and process proof |
|---|---:|---|---|
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.0T3bU8/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.0T3bU8/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.2hBa59/DerivedData/ModuleCache.noindex` | 113832 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.2s7Z6X/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.2s7Z6X/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.56NU0K/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.56NU0K/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.B1xSoo/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.B1xSoo/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.CrGg8e/DerivedData/ModuleCache.noindex` | 113832 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.JJAXOL/DerivedData/ModuleCache.noindex` | 113832 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.LlcGMj/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.LlcGMj/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.P4Md6k/DerivedData/ModuleCache.noindex` | 190132 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.Xcqjbb/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.Xcqjbb/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.mR0QvC/DerivedData-ios-simulator/ModuleCache.noindex` | 76320 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/apple-ui-test/run.mR0QvC/DerivedData-macos/ModuleCache.noindex` | 113836 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/ios-simulator-smoke.7dwiCQ/DerivedData/ModuleCache.noindex` | 76304 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |
| `.temp/TASK-260715-1idq8c/ios-simulator-smoke.bWUxDe/DerivedData/ModuleCache.noindex` | 76304 | Original Xcode build regenerates Clang SDK modules | Ignored; 0 tracked files; 0 live parent references |

## Worktree registrations preserved
```
worktree /Users/iv/Developer/relux-tunnel
HEAD b3422b05226253a17676b9b84c764071fe3dbe74
branch refs/heads/main

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260715-1y04r0/worktree
HEAD 9bf4d0892db03035b989a4c040cfee37636ff8df
branch refs/heads/task-board/story/STORY-260715-1y04r0

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260715-1y04r0/worktree/.temp/TASK-260715-m8bi8i-review/candidate-wt
HEAD cd7187adc02ad2ebd54fad9b3583381e9256dcf5
detached

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260715-1zzt0c/worktree
HEAD 9039c2e3b7856424d515784ca03bd711fb34545d
branch refs/heads/task-board/story/STORY-260715-1zzt0c

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260715-1zzt0c/worktree/.temp/TASK-260715-3kjhkw/negative-worktree
HEAD 2eb40cf97819db02f3f54685d55eb0f04005f9f0
detached

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260715-2ungml/worktree
HEAD ef1303e694705f39aec8afb198be3a60e091bf1f
branch refs/heads/task-board/story/STORY-260715-2ungml

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260715-anxje6/worktree
HEAD 700df3cc61b4ce0e1c9074d868c85d7e6141274e
branch refs/heads/task-board/story/STORY-260715-anxje6

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260716-2byjks/worktree
HEAD b3422b05226253a17676b9b84c764071fe3dbe74
branch refs/heads/task-board/story/STORY-260716-2byjks

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260716-2mtjdn/worktree
HEAD b3422b05226253a17676b9b84c764071fe3dbe74
branch refs/heads/task-board/story/STORY-260716-2mtjdn

worktree /Users/iv/Developer/relux-tunnel/.temp/STORY-260717-1ecq74/worktree
HEAD 2aff85ffb24060f4aa7f8704ac80d35e0830f986
branch refs/heads/task-board/story/STORY-260717-1ecq74

worktree /Users/iv/Developer/relux-tunnel/.temp/TASK-260715-24icoz/clean-worktree
HEAD 58676a23e2e0fb3fcc1b5005d59c6ed56d3c0096
detached

```
