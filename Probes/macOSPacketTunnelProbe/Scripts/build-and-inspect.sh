#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROBE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPOSITORY_ROOT="$(cd "$PROBE_ROOT/../.." && pwd -P)"
OUTPUT_ROOT="${PROBE_OUTPUT_ROOT:-$REPOSITORY_ROOT/.temp/TASK-260715-1r0fxv}"
DERIVED_DATA="$OUTPUT_ROOT/DerivedData"
ARCHIVE_PATH="$OUTPUT_ROOT/ReluxPacketTunnelProbe.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/ReluxPacketTunnelProbe.app"
BUILD_LOG="$OUTPUT_ROOT/build-and-inspect.log"
METADATA="$OUTPUT_ROOT/build-metadata.txt"

mkdir -p "$OUTPUT_ROOT"
: > "$BUILD_LOG"

run() {
  echo "+ $*" | tee -a "$BUILD_LOG"
  "$@" 2>&1 \
    | "$SCRIPT_DIR/redact-build-log.sh" \
    | tee -a "$BUILD_LOG"
}

run xcodegen generate --spec "$PROBE_ROOT/project.yml"
run plutil -lint \
  "$PROBE_ROOT/Host/Info.plist" \
  "$PROBE_ROOT/Provider/Info.plist" \
  "$PROBE_ROOT/Config/Host.entitlements" \
  "$PROBE_ROOT/Config/Provider.entitlements"
run bash -n \
  "$SCRIPT_DIR/build-and-inspect.sh" \
  "$SCRIPT_DIR/check-signing-access.sh" \
  "$SCRIPT_DIR/inspect-archive.sh" \
  "$SCRIPT_DIR/redact-build-log.sh" \
  "$SCRIPT_DIR/test-log-redaction.sh" \
  "$SCRIPT_DIR/test-inspector-drift.sh"
run "$SCRIPT_DIR/test-log-redaction.sh"
run swift format lint --strict --recursive \
  "$PROBE_ROOT/Host" \
  "$PROBE_ROOT/Provider" \
  "$PROBE_ROOT/Shared" \
  "$PROBE_ROOT/Tests"
run xcodebuild \
  -project "$PROBE_ROOT/ReluxPacketTunnelProbe.xcodeproj" \
  -scheme ReluxPacketTunnelProbeTests \
  -configuration Debug \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  test
run "$SCRIPT_DIR/check-signing-access.sh"
run xcodebuild \
  -project "$PROBE_ROOT/ReluxPacketTunnelProbe.xcodeproj" \
  -scheme ReluxPacketTunnelProbe \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -archivePath "$ARCHIVE_PATH" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  archive
run "$SCRIPT_DIR/inspect-archive.sh" "$APP_PATH"
run "$SCRIPT_DIR/test-inspector-drift.sh" "$APP_PATH"

source_revision="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
if git -C "$REPOSITORY_ROOT" diff --quiet \
  && git -C "$REPOSITORY_ROOT" diff --cached --quiet \
  && [ -z "$(git -C "$REPOSITORY_ROOT" status --short --untracked-files=normal)" ]; then
  source_state="clean"
else
  source_state="dirty"
fi

{
  echo "task=TASK-260715-1r0fxv"
  echo "xcode=$(xcodebuild -version | tr '\n' ' ')"
  echo "sdk=$(xcrun --sdk macosx --show-sdk-version)"
  echo "sdkPath=$(xcrun --sdk macosx --show-sdk-path)"
  echo "sourceRevision=$source_revision"
  echo "sourceState=$source_state"
  echo "architecture=arm64"
  echo "developmentTeam=262RZ595FP"
  echo "codeSignIdentityClass=Apple Development"
  echo "hostBundleIdentifier=works.relux.tunnel.probe.mac"
  echo "hostProfileUUID=c0a3cd4e-77c8-475e-98e0-6deec8269810"
  echo "providerBundleIdentifier=works.relux.tunnel.probe.mac.tunnel"
  echo "providerProfileUUID=ef64bcae-00ac-458f-94dc-45834429fe80"
  echo "archive=$ARCHIVE_PATH"
  echo "application=$APP_PATH"
  echo "buildLog=$BUILD_LOG"
} > "$METADATA"

echo "Probe build, tests, archive, signature inspection, and drift tests passed."
echo "Metadata: $METADATA"
echo "Application: $APP_PATH"
