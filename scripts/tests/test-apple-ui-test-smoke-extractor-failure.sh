#!/bin/sh
set -eu

test_root=$(mktemp -d "${TMPDIR:-/tmp}/relux-apple-ui-smoke.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
stubs="$test_root/stubs"
output_root="$test_root/output"
mkdir -p "$stubs" "$output_root"

cat > "$stubs/workspace-generator" <<'STUB'
#!/bin/sh
exit 0
STUB

cat > "$stubs/xcodebuild" <<'STUB'
#!/bin/sh
set -eu
derived_data=
result_bundle=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -derivedDataPath)
      shift
      derived_data=$1
      ;;
    -resultBundlePath)
      shift
      result_bundle=$1
      ;;
  esac
  shift
done
if [ -n "$result_bundle" ]; then
  mkdir -p "$result_bundle"
else
  mkdir -p "$derived_data/Build/Products"
  : > "$derived_data/Build/Products/ReluxProxyMacUITests_stub.xctestrun"
fi
exit 0
STUB

cat > "$stubs/xcrun" <<'STUB'
#!/bin/sh
printf '%s\n' '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-test":[{"isAvailable":true,"name":"iPhone Stub","udid":"stub-simulator"}]}}'
STUB

cat > "$stubs/extractor" <<'STUB'
#!/bin/sh
exit 42
STUB

cat > "$stubs/swift" <<'STUB'
#!/bin/sh
set -eu
if [ "$1" = "run" ]; then
  artifact_directory=$5
  mkdir -p "$artifact_directory"
  : > "$artifact_directory/reference.png"
  : > "$artifact_directory/failed.png"
  : > "$artifact_directory/diff.png"
  exit 1
fi
mkdir -p "$2"
: > "$2/reference-input.png"
: > "$2/failed-input.png"
exit 0
STUB

chmod +x "$stubs"/*

set +e
RELUX_APPLE_UI_TEST_OUTPUT_ROOT="$output_root" \
RELUX_APPLE_UI_TEST_WORKSPACE_GENERATOR="$stubs/workspace-generator" \
RELUX_APPLE_UI_TEST_XCODEBUILD="$stubs/xcodebuild" \
RELUX_APPLE_UI_TEST_XCRUN="$stubs/xcrun" \
RELUX_APPLE_UI_TEST_EXTRACTOR="$stubs/extractor" \
RELUX_APPLE_UI_TEST_SWIFT="$stubs/swift" \
  ./scripts/run-apple-ui-test-smoke.sh > "$test_root/smoke.log" 2>&1
smoke_status=$?
set -e

if [ "$smoke_status" -eq 0 ]; then
  echo "error: aggregate smoke succeeded after injected extractor failure" >&2
  exit 1
fi

summary=$(find "$output_root" -name summary.txt -type f -print -quit)
test -n "$summary"
grep -q '^ios_simulator_xcodebuild_exit=0$' "$summary"
grep -q '^ios_simulator_artifact_exit=42$' "$summary"
grep -q '^ios_simulator_row_exit=42$' "$summary"
grep -q '^aggregate_build_host_exit=1$' "$summary"
printf '%s\n' "extractor failure propagated through aggregate smoke (exit=$smoke_status)"
