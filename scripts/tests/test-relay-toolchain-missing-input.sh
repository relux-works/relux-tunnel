#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

python3 scripts/relay_release.py toolchain-check

source_commit=$(git rev-parse HEAD)
diagnostic_dir=$(mktemp -d "${TMPDIR:-/tmp}/relux-relay-negative.XXXXXX")
trap 'rm -rf "$diagnostic_dir"' EXIT HUP INT TERM

expect_failure() {
    name=$1
    expected=$2
    shift 2
    if "$@" >"$diagnostic_dir/$name.stdout" 2>"$diagnostic_dir/$name.stderr"; then
        echo "$name unexpectedly succeeded" >&2
        exit 1
    fi
    actual=$(cat "$diagnostic_dir/$name.stderr")
    if [ "$actual" != "$expected" ]; then
        echo "$name produced the wrong diagnostic" >&2
        echo "expected: $expected" >&2
        echo "actual:   $actual" >&2
        exit 1
    fi
}

expect_failure missing-go \
    "relay-release: release tool not found: missing-go" \
    python3 scripts/relay_release.py build-target \
    --target linux/amd64 \
    --go .temp/TASK-260715-27uz4n/missing-go \
    --go-toolchain local \
    --relay-version 0.0.0 \
    --source-commit "$source_commit" \
    --source-date-epoch 0 \
    --cache-mode clean \
    --work-dir .build/relay/work/missing-input \
    --output .build/relay/missing-input/relux-relay-linux-amd64

expect_failure missing-source-date-epoch \
    "relay-release: SOURCE_DATE_EPOCH must be a non-negative decimal integer" \
    python3 scripts/relay_release.py build-target \
    --target linux/amd64 \
    --go .temp/TASK-260715-27uz4n/missing-go \
    --go-toolchain local \
    --relay-version 0.0.0 \
    --source-commit "$source_commit" \
    --cache-mode clean \
    --work-dir .build/relay/work/missing-epoch \
    --output .build/relay/missing-epoch/relux-relay-linux-amd64

echo "relay toolchain missing-input gates passed"
