#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
LEGACY_ROOT="${LEGACY_ROOT:-$WORKSPACE_ROOT/../relux-proxy}"
MANIFEST="$WORKSPACE_ROOT/config/legacy-v0.1.0.sha256"
EXPECTED_TAG="v0.1.0"
EXPECTED_COMMIT="2557aba1c030d0643d76e0bc3b185f6d5fd172e1"
FAILURES=0

usage() {
    cat <<'USAGE'
Usage: scripts/check-legacy-preservation.sh [options]

Options:
  --legacy-root PATH     Legacy ReluxProxy Git checkout (default: ../relux-proxy)
  --workspace-root PATH  Generated-workspace repository to collision-check
                         (default: this repository)
  -h, --help             Show this help
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --legacy-root)
            [ "$#" -ge 2 ] || { echo "error: --legacy-root requires a path" >&2; exit 2; }
            LEGACY_ROOT="$2"
            shift 2
            ;;
        --workspace-root)
            [ "$#" -ge 2 ] || { echo "error: --workspace-root requires a path" >&2; exit 2; }
            WORKSPACE_ROOT="$2"
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

fail() {
    echo "FAIL: $*" >&2
    FAILURES=$((FAILURES + 1))
}

pass() {
    echo "PASS: $*"
}

require_file() {
    relative="$1"
    if [ -f "$LEGACY_ROOT/$relative" ]; then
        pass "legacy file exists: $relative"
        return 0
    fi
    fail "legacy file missing: $relative"
    return 1
}

require_literal() {
    relative="$1"
    literal="$2"
    description="$3"
    if [ ! -f "$LEGACY_ROOT/$relative" ]; then
        fail "$description (missing $relative)"
    elif grep -Fq -- "$literal" "$LEGACY_ROOT/$relative"; then
        pass "$description"
    else
        fail "$description"
    fi
}

require_plist_value() {
    key="$1"
    expected="$2"
    actual=""
    if [ ! -f "$LEGACY_ROOT/Resources/Info.plist" ]; then
        fail "Info.plist value $key=$expected (plist missing)"
        return
    fi
    actual="$(/usr/libexec/PlistBuddy -c "Print :$key" "$LEGACY_ROOT/Resources/Info.plist" 2>/dev/null || true)"
    if [ "$actual" = "$expected" ]; then
        pass "Info.plist $key=$expected"
    else
        fail "Info.plist $key expected '$expected', found '${actual:-<missing>}'"
    fi
}

if [ ! -d "$LEGACY_ROOT" ]; then
    echo "error: legacy root does not exist: $LEGACY_ROOT" >&2
    exit 2
fi
if [ ! -d "$WORKSPACE_ROOT" ]; then
    echo "error: workspace root does not exist: $WORKSPACE_ROOT" >&2
    exit 2
fi

LEGACY_ROOT="$(cd "$LEGACY_ROOT" && pwd -P)"
WORKSPACE_ROOT="$(cd "$WORKSPACE_ROOT" && pwd -P)"

legacy_top="$(git -C "$LEGACY_ROOT" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$legacy_top" ]; then
    fail "legacy root is a Git checkout"
elif [ "$(cd "$legacy_top" && pwd -P)" = "$WORKSPACE_ROOT" ]; then
    fail "legacy product and generated workspace must remain separate repositories"
else
    pass "legacy product is in an independent repository"
fi

tag_commit="$(git -C "$LEGACY_ROOT" rev-parse "$EXPECTED_TAG^{commit}" 2>/dev/null || true)"
if [ "$tag_commit" = "$EXPECTED_COMMIT" ]; then
    pass "$EXPECTED_TAG resolves to shipped commit $EXPECTED_COMMIT"
else
    fail "$EXPECTED_TAG expected commit $EXPECTED_COMMIT, found '${tag_commit:-<missing>}'"
fi

tag_type="$(git -C "$LEGACY_ROOT" cat-file -t "refs/tags/$EXPECTED_TAG" 2>/dev/null || true)"
if [ "$tag_type" = "tag" ]; then
    pass "$EXPECTED_TAG is an annotated tag"
else
    fail "$EXPECTED_TAG must remain an annotated tag"
fi

if git -C "$LEGACY_ROOT" cat-file -p "refs/tags/$EXPECTED_TAG" 2>/dev/null | grep -Fq -- "-----BEGIN SSH SIGNATURE-----"; then
    pass "$EXPECTED_TAG retains its signed release lineage"
else
    fail "$EXPECTED_TAG no longer contains its SSH signature"
fi

if [ ! -f "$MANIFEST" ]; then
    fail "preservation manifest missing: $MANIFEST"
else
    while read -r expected relative; do
        [ -n "${expected:-}" ] || continue
        [ -n "${relative:-}" ] || { fail "malformed preservation manifest entry"; continue; }
        if require_file "$relative"; then
            actual="$(shasum -a 256 "$LEGACY_ROOT/$relative" | awk '{print $1}')"
            if [ "$actual" = "$expected" ]; then
                pass "v0.1.0 bytes preserved: $relative"
            else
                fail "v0.1.0 bytes changed: $relative (expected $expected, found $actual)"
            fi
        fi
    done < "$MANIFEST"
fi

# SwiftPM identity and macOS 14 compatibility lane.
require_literal "Package.swift" 'name: "ReluxProxy"' "SwiftPM package/target identity remains ReluxProxy"
require_literal "Package.swift" '.macOS(.v14)' "SwiftPM deployment target remains macOS 14"
require_literal "Package.swift" '.executable(name: "ReluxProxy", targets: ["ReluxProxy"])' "SwiftPM executable product remains ReluxProxy"
require_literal "Package.swift" 'name: "ReluxProxyTests"' "SwiftPM test target remains ReluxProxyTests"

# Persistent defaults and their standard-defaults bundle domain.
require_literal "Sources/ReluxProxy/MenuContentView.swift" '@AppStorage("sshHost") private var host = "relux"' "sshHost default remains relux"
require_literal "Sources/ReluxProxy/MenuContentView.swift" '@AppStorage("sshAccount") private var account = "administrator"' "sshAccount default remains administrator"
require_literal "Sources/ReluxProxy/MenuContentView.swift" '@AppStorage("localPort") private var localPort = 1_080' "localPort default remains 1080"

# System OpenSSH executable, fixed command vector, and byte-for-byte regression test.
require_literal "Sources/ReluxProxy/SSHCommandBuilder.swift" 'URL(fileURLWithPath: "/usr/bin/ssh")' "system SSH executable remains /usr/bin/ssh"
for argument in '-N' '-C' '-D' 'ExitOnForwardFailure=yes' 'ServerAliveInterval=30' 'ServerAliveCountMax=3' 'ConnectTimeout=15' 'BatchMode=yes' 'LogLevel=ERROR'; do
    require_literal "Sources/ReluxProxy/SSHCommandBuilder.swift" "\"$argument\"" "SSH command retains argument $argument"
done
require_literal "Tests/ReluxProxyTests/TunnelConfigurationTests.swift" 'func testSSHArgumentsMatchHardenedTunnelSetup() throws' "system-SSH command-construction regression test remains present"
require_literal "Tests/ReluxProxyTests/TunnelConfigurationTests.swift" '"administrator@relux"' "system-SSH default target assertion remains present"

# Bundle identity and shipped template version.
require_plist_value "CFBundleExecutable" "ReluxProxy"
require_plist_value "CFBundleIdentifier" "works.relux.proxy"
require_plist_value "CFBundleShortVersionString" "0.1.0"
require_plist_value "LSMinimumSystemVersion" "14.0"
require_plist_value "LSUIElement" "true"

# Existing build, test, universal app, Developer ID, and DMG entry points.
require_literal "Makefile" $'test:\n\tswift test' "make test still delegates to swift test"
require_literal "Makefile" $'build:\n\tswift build' "make build still delegates to swift build"
require_literal "Makefile" $'app:\n\tscripts/build-app.sh' "make app still delegates to the legacy app packager"
require_literal "Makefile" $'dmg: app\n\tscripts/create-dmg.sh' "make dmg still delegates to the legacy DMG packager"
require_literal "scripts/build-app.sh" 'APP_NAME="ReluxProxy"' "legacy app product remains ReluxProxy.app"
require_literal "scripts/build-app.sh" 'UNIVERSAL:-1' "universal app build remains the default"
require_literal "scripts/build-app.sh" '--arch arm64 --arch x86_64' "universal app retains arm64 and x86_64 slices"
require_literal "scripts/build-app.sh" 'Developer ID Application: Relux Works, LLC (262RZ595FP)' "Developer ID identity remains Relux Works, LLC (262RZ595FP)"
require_literal "scripts/create-dmg.sh" "ReluxProxy-v\$VERSION-universal.dmg" "versioned universal DMG naming remains intact"
require_literal ".github/workflows/ci.yml" 'run: swift test' "legacy CI retains swift test"
require_literal ".github/workflows/ci.yml" 'run: scripts/build-app.sh' "legacy CI retains credential-free app packaging"
require_literal ".github/workflows/release.yml" 'cp dist/ReluxProxy-*.dmg dist/ReluxProxy.dmg' "release retains stable ReluxProxy.dmg artifact"
require_literal ".github/workflows/release.yml" 'dist/ReluxProxy.dmg' "release publication retains stable ReluxProxy.dmg"

# These exact paths belong to the legacy lane. Future generated targets must use
# their approved ReluxProxyMac/ReluxProxyIOS paths rather than shadowing them.
for reserved in \
    Sources/ReluxProxy \
    Tests/ReluxProxyTests \
    Resources/Info.plist \
    scripts/build-app.sh \
    scripts/create-dmg.sh; do
    if [ -e "$WORKSPACE_ROOT/$reserved" ]; then
        fail "generated workspace collides with legacy-owned path: $reserved"
    else
        pass "generated workspace does not claim legacy-owned path: $reserved"
    fi
done

if [ "$FAILURES" -ne 0 ]; then
    echo "Legacy preservation check failed with $FAILURES violation(s)." >&2
    echo "Do not update the baseline without an approved legacy migration/retirement record." >&2
    exit 1
fi

echo "Legacy preservation contract satisfied for $LEGACY_ROOT"
