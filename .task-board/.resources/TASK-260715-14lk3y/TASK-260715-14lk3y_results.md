# TASK-260715-14lk3y implementation evidence

## Delivered

- `docs/legacy-preservation.md`: explicit independent-lane identity contract,
  deprecation boundary, runnable commands, and before-state evidence.
- `config/legacy-v0.1.0.sha256`: complete product-bearing v0.1.0 source, test,
  bundle, build, packaging, and release-workflow baseline.
- `scripts/check-legacy-preservation.sh`: read-only semantic/hash/tag/path guard.
- `scripts/tests/test-legacy-preservation-guard.sh`: disposable negative tests
  for removal, bundle/default/SSH/test/artifact migration, and path collision.
- `Makefile` targets `check-legacy` and `test-legacy-guard` plus README tool
  documentation.

The separate `/Users/iv/Developer/relux-proxy` checkout was not modified. A
detached task-scoped reference clone of `v0.1.0` was made read-only, and build
outputs were produced only in a second disposable clone.

## Verification (2026-07-20)

| Command/check | Result |
| --- | --- |
| `shellcheck -S style scripts/check-legacy-preservation.sh scripts/tests/test-legacy-preservation-guard.sh` | Pass, no findings |
| `bash -n scripts/check-legacy-preservation.sh scripts/tests/test-legacy-preservation-guard.sh` | Pass |
| `make check-legacy LEGACY_ROOT=.temp/TASK-260715-14lk3y/legacy-v0.1.0` | Pass against read-only detached v0.1.0 clone |
| `make test-legacy-guard LEGACY_ROOT=/Users/iv/Developer/relux-proxy` | Pass: baseline accepted; seven removal/migration/collision cases rejected |
| `swift test` in disposable v0.1.0 clone | Pass: 4 tests, 0 failures |
| `swift build` in disposable v0.1.0 clone | Pass |
| `SIGN_IDENTITY=- VERSION=v0.1.0 make app` | Pass; ad-hoc codesign verification succeeds |
| `SIGN_IDENTITY=- VERSION=v0.1.0 make dmg` | Pass; creates `ReluxProxy-v0.1.0-universal.dmg` |
| `lipo -archs dist/ReluxProxy.app/Contents/MacOS/ReluxProxy` | `x86_64 arm64` |
| `codesign --verify --deep --strict --verbose=2 dist/ReluxProxy.app` | Pass |
| `hdiutil verify dist/ReluxProxy-v0.1.0-universal.dmg` | Valid checksum |
| Packaged plist inspection | `works.relux.proxy`, minimum macOS `14.0` |
| `git diff --check` | Pass |
| `task-board validate` | Pass, no issues |

Credentialed Developer ID signing, notarization, stapling, and publication were
not run because they require release secrets. Their source workflows and exact
identity are pinned by the credential-free guard; the published v0.1.0 artifact
remains the authoritative signed/notarized evidence.
