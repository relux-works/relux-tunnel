#!/bin/sh
# Execute only host-compatible target shells. Cross-built targets that cannot
# run locally are reported as required release-CI rows, never local passes.
set -eu

release_dir=${1:?release directory is required}
test_dir=${2:?protocol-test directory is required}
relay_version=${3:?relay version is required}
source_commit=${4:?source commit is required}
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
release_tool="$script_dir/../relay_release.py"
umask 077
smoke_state=$(mktemp -d "${TMPDIR:-/tmp}/relux-relay-smoke.XXXXXX")
cleanup() {
    rm -rf -- "$smoke_state"
}
trap cleanup 0
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

validate_protocol_test_smoke() {
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

validate_identity() {
    executable=$1
    target=$2
    execution_mode=$3
    target_slug=$(printf '%s' "$target" | tr / -)
    identity_output="$smoke_state/identity-$target_slug.json"
    diagnostics="$smoke_state/identity-$target_slug.stderr"
    if [ "$execution_mode" = rosetta ]; then
        if ! arch -x86_64 "$executable" --identity --protocol 1 >"$identity_output" 2>"$diagnostics"; then
            echo "identity command failed" >&2
            return 1
        fi
    elif ! "$executable" --identity --protocol 1 >"$identity_output" 2>"$diagnostics"; then
        echo "identity command failed" >&2
        return 1
    fi
    if [ -s "$diagnostics" ]; then
        echo "identity command emitted diagnostics" >&2
        return 1
    fi
    python3 "$release_tool" verify-identity \
        --target "$target" \
        --manifest "$release_dir/relux-relay-manifest-v1.json" \
        --executable "$executable" \
        --identity-output "$identity_output"
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

validate_stdio() {
    executable=$1
    execution_mode=$2
    python3 -c '
import struct, subprocess, sys
command = [sys.argv[1], "--stdio", "--protocol", "1"]
if sys.argv[2] == "rosetta":
    command = ["arch", "-x86_64", *command]
client_hello = b"RLXR" + struct.pack(">HHI", 1, 0, 4096)
expected = b"RLXR" + struct.pack(">HHII", 1, 0, 0, 4096)
result = subprocess.run(command, input=client_hello, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
if result.returncode != 0 or result.stdout != expected or result.stderr:
    raise SystemExit("stdio contract mismatch")
' "$executable" "$execution_mode"
}

run_native_pair() {
    os_name=$1
    arch_name=$2
    relay="$release_dir/relux-relay-$os_name-$arch_name"
    protocol_test="$test_dir/relux-relay-protocol-test-$os_name-$arch_name"
    validate_identity "$relay" "$os_name/$arch_name" native
    validate_stdio "$relay" native
    validate_protocol_test_smoke "$("$protocol_test" smoke)" relux-relay-protocol-test "$os_name/$arch_name"
    validate_protocol_run "$("$protocol_test" run)"
}

run_rosetta_pair() {
    relay="$release_dir/relux-relay-darwin-amd64"
    protocol_test="$test_dir/relux-relay-protocol-test-darwin-amd64"
    validate_identity "$relay" darwin/amd64 rosetta
    validate_stdio "$relay" rosetta
    validate_protocol_test_smoke "$(arch -x86_64 "$protocol_test" smoke)" relux-relay-protocol-test darwin/amd64
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
