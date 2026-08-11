#!/bin/bash

set -euo pipefail

sed -E \
  -e 's/(--sign )[0-9A-F]{40}/\1<redacted>/g' \
  -e 's/(-signing-cert )[0-9A-F]{40}/\1<redacted>/g' \
  -e 's/^([[:space:]]*Signing Identity:).*$/\1     "<redacted Apple Development identity>"/'
