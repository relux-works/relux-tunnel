#!/bin/sh
# Execute only host-compatible target shells. Cross-built targets that cannot
# run locally are reported as required release-CI rows, never local passes.
set -eu

release_dir=${1:?release directory is required}
test_dir=${2:?protocol-test directory is required}
relay_version=${3:?relay version is required}
source_commit=${4:?source commit is required}

validate_smoke() {
    output=$1
    executable=$2
    target=$3
    python3 -c '
import json, sys
value = json.loads(sys.argv[1])
expected = {
    "schemaVersion": 1,
    "executable": sys.argv[2],
    "executableVersion": sys.argv[4],
    "protocolVersion": 1,
    "sourceRevision": sys.argv[5],
    "buildTarget": sys.argv[3],
    "contract": "metadata-and-empty-health",
    "relayBehaviorImplemented": False,
    "status": "ok",
}
if value != expected:
    raise SystemExit("smoke contract mismatch")
' "$output" "$executable" "$target" "$relay_version" "$source_commit"
}

validate_protocol_run() {
    output=$1
    python3 -c '
import json, sys
expected = {
    "schemaVersion": 1,
    "contract": "empty-health-and-version-mismatch",
    "emptyHealth": "pass",
    "versionMismatch": "pass",
    "casesRun": 2,
    "status": "pass",
}
if json.loads(sys.argv[1]) != expected:
    raise SystemExit("protocol-test contract mismatch")
' "$output"
}

run_native_pair() {
    os_name=$1
    arch_name=$2
    relay="$release_dir/relux-relay-$os_name-$arch_name"
    protocol_test="$test_dir/relux-relay-protocol-test-$os_name-$arch_name"
    validate_smoke "$("$relay" smoke)" relux-relay "$os_name/$arch_name"
    validate_smoke "$("$protocol_test" smoke)" relux-relay-protocol-test "$os_name/$arch_name"
    validate_protocol_run "$("$protocol_test" run)"
}

run_rosetta_pair() {
    relay="$release_dir/relux-relay-darwin-amd64"
    protocol_test="$test_dir/relux-relay-protocol-test-darwin-amd64"
    validate_smoke "$(arch -x86_64 "$relay" smoke)" relux-relay darwin/amd64
    validate_smoke "$(arch -x86_64 "$protocol_test" smoke)" relux-relay-protocol-test darwin/amd64
    validate_protocol_run "$(arch -x86_64 "$protocol_test" run)"
}

host_os=$(uname -s)
host_arch=$(uname -m)
case "$host_os/$host_arch" in
    Darwin/arm64)
        run_native_pair darwin arm64
        echo "runtime darwin/arm64: native pass"
        if arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
            run_rosetta_pair
            echo "runtime darwin/amd64: Rosetta 2 pass; native Intel release-CI row still required"
        else
            echo "runtime darwin/amd64: not executed; native Intel release-CI row required"
        fi
        echo "runtime linux/amd64: not executed; native release-CI row required"
        echo "runtime linux/arm64: not executed; native release-CI row required"
        ;;
    Darwin/x86_64)
        run_native_pair darwin amd64
        echo "runtime darwin/amd64: native pass"
        echo "runtime darwin/arm64: not executed; native release-CI row required"
        echo "runtime linux/amd64: not executed; native release-CI row required"
        echo "runtime linux/arm64: not executed; native release-CI row required"
        ;;
    Linux/x86_64)
        run_native_pair linux amd64
        echo "runtime linux/amd64: native pass"
        echo "runtime linux/arm64: not executed; native release-CI row required"
        echo "runtime darwin/amd64: not executed; native release-CI row required"
        echo "runtime darwin/arm64: not executed; native release-CI row required"
        ;;
    Linux/aarch64|Linux/arm64)
        run_native_pair linux arm64
        echo "runtime linux/arm64: native pass"
        echo "runtime linux/amd64: not executed; native release-CI row required"
        echo "runtime darwin/amd64: not executed; native release-CI row required"
        echo "runtime darwin/arm64: not executed; native release-CI row required"
        ;;
    *)
        echo "unsupported smoke host; all four native release-CI rows required" >&2
        exit 1
        ;;
esac
