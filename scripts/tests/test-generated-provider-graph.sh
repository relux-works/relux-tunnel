#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
work_root=$(mktemp -d "${TMPDIR:-/tmp}/relux-provider-graph.XXXXXX")
cleanup() {
  case "$work_root" in
    "${TMPDIR:-/tmp}"/relux-provider-graph.*) rm -rf "$work_root" ;;
    *) echo "warning: refusing to clean unexpected test path: $work_root" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

validator="$repo_root/scripts/check-generated-provider-graph.py"
relay_root="$repo_root/.build/relay/apple-bundle-input"
generated_project="$repo_root/ReluxTunnelApp.xcodeproj/project.pbxproj"

if [ ! -f "$generated_project" ]; then
  "$repo_root/scripts/generate-workspace.sh" --clean >/dev/null
fi

expect_failure() {
  name=$1
  shift
  if "$@" >"$work_root/$name.stdout" 2>"$work_root/$name.stderr"; then
    echo "error: invalid provider graph unexpectedly passed: $name" >&2
    exit 1
  fi
}

"$validator" \
  --project "$repo_root/Project.swift" \
  --package "$repo_root/Package.swift" \
  --relay-root "$relay_root" \
  --generated-project "$generated_project" >/dev/null

cp "$generated_project" "$work_root/missing-generated-adapter-edge.pbxproj"
python3 - "$work_root/missing-generated-adapter-edge.pbxproj" <<'PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
text = path.read_text()
pattern = r'^\s*[0-9A-F]{24} /\* ReluxTunnelMacOSAdapter in Frameworks \*/,\n'
mutated, count = re.subn(pattern, '', text, flags=re.MULTILINE)
assert count == 1
assert 'ReluxTunnelMacOSAdapter' in mutated
path.write_text(mutated)
PY
expect_failure missing-generated-adapter-edge "$validator" \
  --project "$repo_root/Project.swift" \
  --package "$repo_root/Package.swift" \
  --relay-root "$relay_root" \
  --generated-project "$work_root/missing-generated-adapter-edge.pbxproj"

cp "$generated_project" "$work_root/missing-generated-relay-edge.pbxproj"
python3 - "$work_root/missing-generated-relay-edge.pbxproj" <<'PY'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
text = path.read_text()
pattern = r'^\s*[0-9A-F]{24} /\* apple-bundle-input in Resources \*/,\n'
mutated, count = re.subn(pattern, '', text, flags=re.MULTILINE)
assert count == 1
assert 'apple-bundle-input' in mutated
path.write_text(mutated)
PY
expect_failure missing-generated-relay-edge "$validator" \
  --project "$repo_root/Project.swift" \
  --package "$repo_root/Package.swift" \
  --relay-root "$relay_root" \
  --generated-project "$work_root/missing-generated-relay-edge.pbxproj"

cp "$repo_root/Project.swift" "$work_root/Project.swift"
python3 - "$work_root/Project.swift" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = '.package(product: "ReluxTunnelMacOSAdapter")'
assert text.count(old) == 1
path.write_text(text.replace(old, '.package(product: "ReluxTunnelCore")'))
PY
expect_failure missing-adapter "$validator" \
  --project "$work_root/Project.swift" \
  --package "$repo_root/Package.swift" \
  --relay-root "$relay_root"

cp -R "$relay_root" "$work_root/relay"
mv "$work_root/relay/relux-relay-linux-arm64" "$work_root/missing-relay"
expect_failure missing-relay-resource "$validator" \
  --project "$repo_root/Project.swift" \
  --package "$repo_root/Package.swift" \
  --relay-root "$work_root/relay"

cp "$repo_root/Package.swift" "$work_root/Package.swift"
python3 - "$work_root/Package.swift" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
old = 'name: "ReluxTunnelNativeAdapter",\n      dependencies: [\n        "ReluxTunnelCore",'
new = old + '\n        "CReluxNativeFixture",'
assert text.count(old) == 1
path.write_text(text.replace(old, new))
PY
expect_failure fixture-leakage "$validator" \
  --project "$repo_root/Project.swift" \
  --package "$work_root/Package.swift" \
  --relay-root "$relay_root"

: > "$work_root/linked-libraries.txt"
printf '                 U _dlopen\n' > "$work_root/undefined-symbols.txt"
expect_failure dynamic-loading "$validator" \
  --project "$repo_root/Project.swift" \
  --package "$repo_root/Package.swift" \
  --relay-root "$relay_root" \
  --linked-libraries "$work_root/linked-libraries.txt" \
  --undefined-symbols "$work_root/undefined-symbols.txt"

echo "generated provider graph negative tests passed"
