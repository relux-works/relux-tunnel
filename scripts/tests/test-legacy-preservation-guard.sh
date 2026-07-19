#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GUARD="$PROJECT_ROOT/scripts/check-legacy-preservation.sh"
LEGACY_ROOT="${LEGACY_ROOT:-$PROJECT_ROOT/../relux-proxy}"
FAILURES=0

usage() {
    echo "Usage: scripts/tests/test-legacy-preservation-guard.sh [--legacy-root PATH]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --legacy-root)
            [ "$#" -ge 2 ] || { echo "error: --legacy-root requires a path" >&2; exit 2; }
            LEGACY_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ ! -d "$LEGACY_ROOT/.git" ]; then
    echo "error: expected a legacy Git checkout at $LEGACY_ROOT" >&2
    exit 2
fi

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/relux-legacy-guard-tests.XXXXXX")"

cleanup() {
    case "$TEST_ROOT" in
        "${TMPDIR:-/tmp}"/relux-legacy-guard-tests.*)
            chmod -R u+w "$TEST_ROOT" 2>/dev/null || true
            rm -rf "$TEST_ROOT"
            ;;
        *)
            echo "refusing to clean unexpected test path: $TEST_ROOT" >&2
            ;;
    esac
}
trap cleanup EXIT INT TERM

baseline="$TEST_ROOT/baseline"
git clone --quiet --local --no-hardlinks "$LEGACY_ROOT" "$baseline"
git -C "$baseline" checkout --quiet v0.1.0

expect_pass() {
    name="$1"
    legacy="$2"
    workspace="$3"
    log="$TEST_ROOT/$name.log"
    if "$GUARD" --legacy-root "$legacy" --workspace-root "$workspace" >"$log" 2>&1; then
        echo "PASS: $name"
    else
        echo "FAIL: $name (expected success)" >&2
        sed -n '1,220p' "$log" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

expect_failure() {
    name="$1"
    legacy="$2"
    workspace="$3"
    log="$TEST_ROOT/$name.log"
    if "$GUARD" --legacy-root "$legacy" --workspace-root "$workspace" >"$log" 2>&1; then
        echo "FAIL: $name (guard unexpectedly accepted drift)" >&2
        FAILURES=$((FAILURES + 1))
    else
        echo "PASS: $name rejected"
    fi
}

new_case() {
    name="$1"
    case_root="$TEST_ROOT/$name"
    cp -R "$baseline" "$case_root"
    echo "$case_root"
}

workspace="$TEST_ROOT/workspace"
mkdir -p "$workspace"
expect_pass "baseline" "$baseline" "$workspace"

case_root="$(new_case missing-product-file)"
rm "$case_root/Resources/Info.plist"
expect_failure "missing-product-file" "$case_root" "$workspace"

case_root="$(new_case bundle-id-migration)"
perl -0pi -e 's/works\.relux\.proxy/works.relux.migrated/' "$case_root/Resources/Info.plist"
expect_failure "bundle-id-migration" "$case_root" "$workspace"

case_root="$(new_case defaults-migration)"
perl -0pi -e 's/private var host = "relux"/private var host = "new-default"/' "$case_root/Sources/ReluxProxy/MenuContentView.swift"
expect_failure "defaults-migration" "$case_root" "$workspace"

case_root="$(new_case system-ssh-migration)"
perl -0pi -e 's#/usr/bin/ssh#/opt/local/bin/ssh#' "$case_root/Sources/ReluxProxy/SSHCommandBuilder.swift"
expect_failure "system-ssh-migration" "$case_root" "$workspace"

case_root="$(new_case command-test-migration)"
perl -0pi -e 's/ServerAliveInterval=30/ServerAliveInterval=60/' "$case_root/Tests/ReluxProxyTests/TunnelConfigurationTests.swift"
expect_failure "command-test-migration" "$case_root" "$workspace"

case_root="$(new_case artifact-migration)"
perl -0pi -e 's/ReluxProxy\.dmg/ReluxTunnel.dmg/g' "$case_root/.github/workflows/release.yml"
expect_failure "artifact-migration" "$case_root" "$workspace"

collision_workspace="$TEST_ROOT/collision-workspace"
mkdir -p "$collision_workspace/Sources/ReluxProxy"
expect_failure "workspace-path-collision" "$baseline" "$collision_workspace"

if [ "$FAILURES" -ne 0 ]; then
    echo "Legacy preservation guard tests failed: $FAILURES" >&2
    exit 1
fi

echo "Legacy preservation guard tests passed"
