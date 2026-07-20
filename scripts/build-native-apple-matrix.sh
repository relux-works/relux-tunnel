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
                SYMROOT="$products" \
                OBJROOT="$intermediates" \
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
                SYMROOT="$products" \
                OBJROOT="$intermediates" \
                build
            ;;
    esac
}

cd "$repo_root"

# The native adapter is the shared Core/native consumer. The provider schemes
# prove both extension destinations; the harness proves the macOS executable.
build_scheme ReluxTunnelNativeAdapter 'generic/platform=iOS'
build_scheme ReluxTunnelNativeAdapter 'generic/platform=iOS Simulator'
build_scheme ReluxTunnelNativeAdapter 'generic/platform=macOS'
build_scheme ReluxTunnelIOSAdapter 'generic/platform=iOS'
build_scheme ReluxTunnelIOSAdapter 'generic/platform=iOS Simulator'
build_scheme ReluxTunnelMacOSAdapter 'generic/platform=macOS'
build_scheme ReluxTunnelHarness 'generic/platform=macOS'

# Inspect a production SwiftPM harness link. Xcode's generated package scheme
# always instruments build actions for test coverage; the production harness
# path is the non-instrumented SwiftPM release product.
swiftpm_scratch="$derived_data/swiftpm-release"
swift build -c release --scratch-path "$swiftpm_scratch"
swiftpm_bin=$(swift build -c release --scratch-path "$swiftpm_scratch" --show-bin-path)
xcrun strip -S "$swiftpm_bin/ReluxTunnelHarness"
"$tool" inspect-linked \
    --binary "$swiftpm_bin/ReluxTunnelHarness" \
    --architectures "$(uname -m)"

echo "Native fixture linked for iOS device, iOS simulator, macOS provider, shared consumer, and harness"
