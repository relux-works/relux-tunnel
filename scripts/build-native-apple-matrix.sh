#!/bin/sh
set -eu

repo_root=$(cd "$(dirname "$0")/.." && pwd)
derived_data=${RELUX_NATIVE_DERIVED_DATA:-"$repo_root/.build/native-apple-matrix"}
products="$derived_data/Products"
intermediates="$derived_data/Intermediates"
tool="$repo_root/scripts/native-dependency-tool.py"

build_scheme() {
    scheme=$1
    destination=$2
    build_key=$(printf '%s-%s' "$scheme" "$destination" | tr '/=, ' '-----')
    scheme_products="$products/$build_key"
    scheme_intermediates="$intermediates/$build_key"
    case "$destination" in
        generic/platform=macOS)
            xcodebuild -quiet \
                -scheme "$scheme" \
                -destination "$destination" \
                -configuration Release \
                -derivedDataPath "$derived_data" \
                APPLICATION_EXTENSION_API_ONLY=YES \
                CODE_SIGNING_ALLOWED=NO \
                ONLY_ACTIVE_ARCH=NO \
                "ARCHS=arm64 x86_64" \
                SYMROOT="$scheme_products" \
                OBJROOT="$scheme_intermediates" \
                build
            ;;
        *)
            xcodebuild -quiet \
                -scheme "$scheme" \
                -destination "$destination" \
                -configuration Release \
                -derivedDataPath "$derived_data" \
                APPLICATION_EXTENSION_API_ONLY=YES \
                CODE_SIGNING_ALLOWED=NO \
                SYMROOT="$scheme_products" \
                OBJROOT="$scheme_intermediates" \
                build
            ;;
    esac
}

build_swiftpm_macos_target() {
    target=$1
    architecture=$2
    scratch="$derived_data/swiftpm-$target-$architecture"
    swift build \
        -c release \
        --target "$target" \
        --triple "$architecture-apple-macosx15.0" \
        --scratch-path "$scratch" \
        -Xswiftc -application-extension
}

cd "$repo_root"

"$tool" inspect \
    --dependency hev-lwip \
    --xcframework NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework \
    --verify-lock

# The native adapter is the shared Core/native consumer. The provider schemes
# prove both extension destinations; the macOS provider and harness also link
# the pinned libssh2/OpenSSL candidate graph.
build_scheme ReluxTunnelNativeAdapter 'generic/platform=iOS'
build_scheme ReluxTunnelNativeAdapter 'generic/platform=iOS Simulator'
build_scheme ReluxTunnelNativeAdapter 'generic/platform=macOS'
build_scheme ReluxTunnelIOSAdapter 'generic/platform=iOS'
build_scheme ReluxTunnelIOSAdapter 'generic/platform=iOS Simulator'
build_swiftpm_macos_target ReluxTunnelMacOSAdapter arm64
build_swiftpm_macos_target ReluxTunnelMacOSAdapter x86_64
build_swiftpm_macos_target ReluxTunnelHarness arm64
build_swiftpm_macos_target ReluxTunnelHarness x86_64

# Inspect a production SwiftPM harness link. Xcode's generated package scheme
# always instruments build actions for test coverage; the production harness
# path is the non-instrumented SwiftPM release product.
swiftpm_scratch="$derived_data/swiftpm-release"
swift build -c release --scratch-path "$swiftpm_scratch"
swiftpm_bin=$(swift build -c release --scratch-path "$swiftpm_scratch" --show-bin-path)
xcrun strip -S "$swiftpm_bin/ReluxTunnelHarness"
"$tool" inspect-linked \
    --binary "$swiftpm_bin/ReluxTunnelHarness" \
    --architectures "$(uname -m)" \
    --required-symbol hev_socks5_tunnel_main_from_str \
    --required-symbol hev_socks5_tunnel_quit \
    --required-symbol hev_socks5_tunnel_stats
if ! nm "$swiftpm_bin/ReluxTunnelHarness" | grep -Eq ' [tT] _libssh2_session_rekey$'; then
    echo "release harness does not contain the hidden libssh2 rekey symbol" >&2
    exit 1
fi

echo "Pinned HEV, libssh2/OpenSSL, and native fixture linked for the approved Apple matrix"
