#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
FILTER="$SCRIPT_DIR/redact-build-log.sh"
DUMMY_A="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
DUMMY_B="BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"

actual="$(
  printf '%s\n' \
    "codesign --sign $DUMMY_A binary" \
    "validator -signing-cert $DUMMY_B extension" \
    '    Signing Identity:     "Apple Development: Example"' \
    'sourceRevision=5d2204e74442ca94b31c7120dbc5c65ed4373a46' \
    | "$FILTER"
)"
expected='codesign --sign <redacted> binary
validator -signing-cert <redacted> extension
    Signing Identity:     "<redacted Apple Development identity>"
sourceRevision=5d2204e74442ca94b31c7120dbc5c65ed4373a46'

if [ "$actual" != "$expected" ]; then
  echo "Log redaction test failed." >&2
  exit 1
fi

echo "Log redaction tests passed."
