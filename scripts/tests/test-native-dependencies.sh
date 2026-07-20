#!/bin/sh
set -eu

repo_root=$(cd "$(dirname "$0")/../.." && pwd)
tool="$repo_root/scripts/native-dependency-tool.py"
fixture="$repo_root/NativeDependencies/Artifacts/ReluxNativeFixture.xcframework"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/relux-native-tests.XXXXXX")

cleanup() {
    if [ -n "$test_root" ] && [ -d "$test_root" ]; then
        rm -rf "$test_root"
    fi
}
trap cleanup EXIT HUP INT TERM

expect_failure() {
    name=$1
    shift
    if "$@" >"$test_root/$name.stdout" 2>"$test_root/$name.stderr"; then
        echo "expected failure: $name" >&2
        exit 1
    fi
}

cd "$repo_root"

python3 scripts/tests/test-native-build-configuration.py

"$tool" verify --dependency relux-native-fixture
"$tool" inspect --dependency hev-lwip \
    --xcframework NativeDependencies/Artifacts/HevSocks5Tunnel.xcframework \
    --verify-lock
"$tool" inspect --dependency libssh2-openssl \
    --xcframework NativeDependencies/Artifacts/ReluxLibSSH2.xcframework \
    --verify-lock

rebuilt="$test_root/ReluxNativeFixture.xcframework"
"$tool" build-fixture --output "$rebuilt"
"$tool" artifact-lock --dependency relux-native-fixture --xcframework "$fixture" \
    >"$test_root/committed.json"
"$tool" artifact-lock --dependency relux-native-fixture --xcframework "$rebuilt" \
    >"$test_root/rebuilt.json"
cmp "$test_root/committed.json" "$test_root/rebuilt.json"

"$tool" notices --dependency relux-native-fixture --output "$test_root/THIRD_PARTY_NOTICES.txt"
cmp NativeDependencies/THIRD_PARTY_NOTICES.txt "$test_root/THIRD_PARTY_NOTICES.txt"

tampered_root="$test_root/tampered-source"
mkdir -p "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/Sources"
mkdir -p "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/include"
cp NativeDependencies/manifest.json "$tampered_root/NativeDependencies/manifest.json"
cp NativeDependencies/Fixtures/ReluxNativeFixture/LICENSE \
    "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/LICENSE"
cp NativeDependencies/Fixtures/ReluxNativeFixture/Sources/relux_native_fixture.c \
    "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/Sources/relux_native_fixture.c"
cp NativeDependencies/Fixtures/ReluxNativeFixture/include/module.modulemap \
    "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/include/module.modulemap"
cp NativeDependencies/Fixtures/ReluxNativeFixture/include/relux_native_fixture.h \
    "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/include/relux_native_fixture.h"
printf '\n/* tampered */\n' >> \
    "$tampered_root/NativeDependencies/Fixtures/ReluxNativeFixture/Sources/relux_native_fixture.c"
expect_failure source-checksum env RELUX_NATIVE_REPOSITORY_ROOT="$tampered_root" \
    "$tool" verify --dependency relux-native-fixture

missing_arch="$test_root/missing-arch.xcframework"
cp -R "$fixture" "$missing_arch"
lipo -remove x86_64 \
    "$missing_arch/macos-arm64_x86_64/libCReluxNativeFixture.a" \
    -output "$missing_arch/macos-arm64_x86_64/libCReluxNativeFixture.a"
expect_failure missing-architecture "$tool" inspect \
    --dependency relux-native-fixture --xcframework "$missing_arch"

dynamic_library="$test_root/dynamic-library.xcframework"
cp -R "$fixture" "$dynamic_library"
xcrun --sdk macosx clang -dynamiclib \
    -target arm64-apple-macos15.0 \
    NativeDependencies/Fixtures/ReluxNativeFixture/Sources/relux_native_fixture.c \
    -I NativeDependencies/Fixtures/ReluxNativeFixture/include \
    -o "$dynamic_library/macos-arm64_x86_64/libCReluxNativeFixture.a"
expect_failure dynamic-library "$tool" inspect \
    --dependency relux-native-fixture --xcframework "$dynamic_library"

absolute_path="$test_root/absolute-path.xcframework"
cp -R "$fixture" "$absolute_path"
printf '\n/Users/build-agent/opaque/source.c\n' >> \
    "$absolute_path/ios-arm64/Headers/relux_native_fixture.h"
expect_failure absolute-build-path "$tool" inspect \
    --dependency relux-native-fixture --xcframework "$absolute_path"

artifact_drift="$test_root/artifact-drift.xcframework"
cp -R "$fixture" "$artifact_drift"
printf '\n/* artifact drift */\n' >> \
    "$artifact_drift/ios-arm64/Headers/relux_native_fixture.h"
expect_failure artifact-hash "$tool" inspect \
    --dependency relux-native-fixture --xcframework "$artifact_drift" --verify-lock

unexpected_slice="$test_root/unexpected-slice.xcframework"
cp -R "$fixture" "$unexpected_slice"
/usr/libexec/PlistBuddy \
    -c "Add :AvailableLibraries:3 dict" \
    -c "Add :AvailableLibraries:3:LibraryIdentifier string unmodeled-slice" \
    "$unexpected_slice/Info.plist"
expect_failure unexpected-slice "$tool" inspect \
    --dependency relux-native-fixture --xcframework "$unexpected_slice"

echo "Native dependency checksum, reproducibility, notices, architecture, and extension-safety tests passed"
