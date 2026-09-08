#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
GUARD="$PROJECT_ROOT/scripts/check-migration-isolation.py"
LEGACY_ROOT="${LEGACY_ROOT:-$PROJECT_ROOT/../relux-proxy}"
FAILURES=0

usage() {
    echo "Usage: scripts/tests/test-migration-isolation-guard.sh [--legacy-root PATH]"
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

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/relux-migration-isolation.XXXXXX")"

cleanup() {
    case "$TEST_ROOT" in
        "${TMPDIR:-/tmp}"/relux-migration-isolation.*)
            chmod -R u+w "$TEST_ROOT" 2>/dev/null || true
            rm -rf "$TEST_ROOT"
            ;;
        *)
            echo "refusing to clean unexpected test path: $TEST_ROOT" >&2
            ;;
    esac
}
trap cleanup EXIT INT TERM

legacy="$TEST_ROOT/legacy-v0.1.0"
git clone --quiet --local --no-hardlinks "$LEGACY_ROOT" "$legacy"
git -C "$legacy" checkout --quiet v0.1.0

copy_workspace() {
    destination="$1"
    mkdir -p "$destination"
    for relative in App config Configuration Sources .github scripts; do
        cp -R "$PROJECT_ROOT/$relative" "$destination/$relative"
    done
    cp "$PROJECT_ROOT/Makefile" "$PROJECT_ROOT/Package.swift" \
        "$PROJECT_ROOT/Project.swift" "$destination/"
}

expect_pass() {
    name="$1"
    legacy_root="$2"
    workspace_root="$3"
    log="$TEST_ROOT/$name.log"
    if python3 "$GUARD" --legacy-root "$legacy_root" \
        --workspace-root "$workspace_root" >"$log" 2>&1; then
        echo "PASS: $name"
    else
        echo "FAIL: $name (expected success)" >&2
        sed -n '1,220p' "$log" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

expect_failure() {
    name="$1"
    expected="$2"
    legacy_root="$3"
    workspace_root="$4"
    shift 4
    log="$TEST_ROOT/$name.log"
    if python3 "$GUARD" --legacy-root "$legacy_root" \
        --workspace-root "$workspace_root" "$@" >"$log" 2>&1; then
        echo "FAIL: $name (guard unexpectedly admitted the mutation)" >&2
        FAILURES=$((FAILURES + 1))
    elif ! grep -Fq -- "$expected" "$log"; then
        echo "FAIL: $name rejected for the wrong reason" >&2
        sed -n '1,220p' "$log" >&2
        FAILURES=$((FAILURES + 1))
    else
        echo "PASS: $name rejected at the production isolation gate"
    fi
}

baseline="$TEST_ROOT/workspace-baseline"
copy_workspace "$baseline"
expect_pass "baseline" "$legacy" "$baseline"

cross_link="$TEST_ROOT/workspace-cross-link"
copy_workspace "$cross_link"
perl -0pi -e 's/\.package\(product: "ReluxTunnelCore"\)/.package(product: "ReluxProxy")/' \
    "$cross_link/Project.swift"
expect_failure "generated-cross-link" \
    "generated target graph cross-links the legacy ReluxProxy product" \
    "$legacy" "$cross_link"

legacy_cross_link="$TEST_ROOT/legacy-cross-link"
cp -R "$legacy" "$legacy_cross_link"
perl -0pi -e 's/import PackageDescription/import PackageDescription\n\/\/ ReluxTunnelCore/' \
    "$legacy_cross_link/Package.swift"
expect_failure "legacy-cross-link" \
    "legacy SwiftPM path cross-links generated runtime token ReluxTunnelCore" \
    "$legacy_cross_link" "$baseline"

identifier_collision="$TEST_ROOT/workspace-identifier-collision"
copy_workspace "$identifier_collision"
perl -0pi -e 's/works\.relux\.tunnel\.mac$/works.relux.proxy/m' \
    "$identifier_collision/Configuration/Identity.xcconfig"
expect_failure "identifier-collision" \
    "generated identity drifted: RELUX_MACOS_HOST_BUNDLE_ID" \
    "$legacy" "$identifier_collision"

defaults_collision="$TEST_ROOT/workspace-defaults-collision"
copy_workspace "$defaults_collision"
perl -0pi -e 's/application\.run\(\)/\/\/ \@AppStorage("sshHost")\napplication.run()/' \
    "$defaults_collision/App/ReluxProxyMac/Sources/main.swift"
expect_failure "defaults-key-collision" \
    "generated production source reuses legacy defaults key sshHost" \
    "$legacy" "$defaults_collision"

keychain_collision="$TEST_ROOT/workspace-keychain-collision"
copy_workspace "$keychain_collision"
perl -0pi -e 's/works\.relux\.tunnel\.credential\.v1/works.relux.proxy/' \
    "$keychain_collision/Sources/ReluxTunnelMacOSAdapter/MacOSSystemKeychainCredentialResolver.swift"
expect_failure "keychain-namespace-collision" \
    "generated Keychain service namespace drifted" \
    "$legacy" "$keychain_collision"

release_substitution="$TEST_ROOT/workspace-release-substitution"
copy_workspace "$release_substitution"
perl -0pi -e 's/run: make credential-free-validate[^\n]*/run: cp candidate.dmg dist\/ReluxProxy.dmg/' \
    "$release_substitution/.github/workflows/ci.yml"
expect_failure "release-script-substitution" \
    "generated release entry substitutes legacy artifact ReluxProxy.dmg" \
    "$legacy" "$release_substitution"

product_collision="$TEST_ROOT/generated-product-collision"
mkdir -p "$product_collision/Debug/ReluxProxy.app"
expect_failure "build-product-collision" \
    "generated build products collide with legacy artifacts" \
    "$legacy" "$baseline" --products-root "$product_collision"

if [ "$FAILURES" -ne 0 ]; then
    echo "Migration isolation guard tests failed: $FAILURES" >&2
    exit 1
fi

echo "Migration isolation guard tests passed"
