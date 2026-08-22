#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
task_root=${RELUX_APPLE_UI_TEST_OUTPUT_ROOT:-"$repo_root/.temp/TASK-260715-1idq8c/apple-ui-test"}
workspace_generator=${RELUX_APPLE_UI_TEST_WORKSPACE_GENERATOR:-"$repo_root/scripts/generate-workspace.sh"}
xcodebuild_command=${RELUX_APPLE_UI_TEST_XCODEBUILD:-xcodebuild}
xcrun_command=${RELUX_APPLE_UI_TEST_XCRUN:-xcrun}
extractor_command=${RELUX_APPLE_UI_TEST_EXTRACTOR:-"$repo_root/scripts/extract_apple_ui_test_artifacts.py"}
swift_command=${RELUX_APPLE_UI_TEST_SWIFT:-swift}
mkdir -p "$task_root"
run_root=$(mktemp -d "$task_root/run.XXXXXX")
macos_derived_data="$run_root/DerivedData-macos"
ios_derived_data="$run_root/DerivedData-ios-simulator"
cd "$repo_root"

"$workspace_generator" --clean

build_macos_for_testing() {
  log="$run_root/macos-build-for-testing-xcodebuild.log"
  products="$run_root/macos-build-for-testing-products.txt"

  if "$xcodebuild_command" \
    -workspace ReluxTunnel.xcworkspace \
    -scheme ReluxProxyMacUITests \
    -configuration Debug \
    -destination 'platform=macOS' \
    -derivedDataPath "$macos_derived_data" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build-for-testing > "$log" 2>&1; then
    row_status=0
  else
    row_status=$?
  fi

  find \
    "$repo_root/.build/Products" \
    "$macos_derived_data/Build/Products" \
    -name 'ReluxProxyMacUITests_*.xctestrun' -print \
    > "$products" 2>/dev/null || true
  if [ "$row_status" -eq 0 ] && [ ! -s "$products" ]; then
    echo "error: native macOS build-for-testing produced no xctestrun" >> "$log"
    row_status=1
  fi
  return "$row_status"
}

run_ui_test() {
  scheme=$1
  destination=$2
  result_name=$3
  test_target=$4
  result_bundle="$run_root/$result_name.xcresult"
  artifacts_directory="$run_root/$result_name-artifacts"
  log="$run_root/$result_name-xcodebuild.log"

  if "$xcodebuild_command" \
    -workspace ReluxTunnel.xcworkspace \
    -scheme "$scheme" \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$ios_derived_data" \
    -resultBundlePath "$result_bundle" \
    -only-testing:"$test_target/ReluxUITestSmokeTests/testDiagnosticFixtureProducesStepScreenshots" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    test > "$log" 2>&1; then
    row_status=0
  else
    row_status=$?
  fi
  ui_test_xcodebuild_status=$row_status

  if [ "$row_status" -ne 0 ]; then
    ui_test_artifact_status=not_run
    return "$row_status"
  fi

  if "$extractor_command" "$result_bundle" "$artifacts_directory" >> "$log" 2>&1; then
    :
  else
    extraction_status=$?
    ui_test_artifact_status=$extraction_status
    echo "error: screenshot extraction failed with exit $extraction_status" >> "$log"
    return "$extraction_status"
  fi

  if python3 scripts/validate_apple_ui_test_artifacts.py \
    "$artifacts_directory" \
    --expected-step Step_01__diagnostic_fixture_ready \
    --expected-step Step_02__diagnostic_fixture_confirmed >> "$log" 2>&1; then
    ui_test_artifact_status=0
    return 0
  else
    validation_status=$?
    ui_test_artifact_status=$validation_status
    echo "error: screenshot evidence validation failed with exit $validation_status" >> "$log"
    return "$validation_status"
  fi
}

if build_macos_for_testing; then
  macos_status=0
else
  macos_status=$?
fi

simulator_id=$(
  "$xcrun_command" simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    for device in devices[runtime]:
        if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit("no available iPhone Simulator")
'
)
if run_ui_test \
  ReluxProxyIOSUITests \
  "platform=iOS Simulator,id=$simulator_id" \
  ios-simulator \
  ReluxProxyIOSUITests; then
  ios_status=0
else
  ios_status=$?
fi
ios_xcodebuild_status=$ui_test_xcodebuild_status
ios_artifact_status=$ui_test_artifact_status

snapshot_inputs="$run_root/snapshot-inputs"
snapshot_artifacts="$run_root/snapshot-diff-artifacts/controlled-mismatch"
"$swift_command" scripts/generate-snapshot-diff-fixtures.swift "$snapshot_inputs"
set +e
"$swift_command" run relux-snapshot-diff \
  "$snapshot_inputs/reference-input.png" \
  "$snapshot_inputs/failed-input.png" \
  "$snapshot_artifacts" > "$run_root/snapshot-diff.log" 2>&1
snapshot_status=$?
set -e
if [ "$snapshot_status" -ne 1 ]; then
  echo "error: controlled snapshot mismatch returned $snapshot_status, expected 1" >&2
  exit 1
fi
for artifact in reference.png failed.png diff.png; do
  test -f "$snapshot_artifacts/$artifact"
done

if [ "$macos_status" -eq 0 ] && [ "$ios_status" -eq 0 ]; then
  aggregate_status=0
else
  aggregate_status=1
fi

printf '%s\n' \
  "macos_build_for_testing_exit=$macos_status" \
  'macos_runtime_status=deferred' \
  'macos_runtime_owner=TASK-260822-3q4grm' \
  "ios_simulator_xcodebuild_exit=$ios_xcodebuild_status" \
  "ios_simulator_artifact_exit=$ios_artifact_status" \
  "ios_simulator_row_exit=$ios_status" \
  "snapshot_diff_exit=$snapshot_status" \
  "aggregate_build_host_exit=$aggregate_status" \
  > "$run_root/summary.txt"
printf '%s\n' "$run_root"

exit "$aggregate_status"
