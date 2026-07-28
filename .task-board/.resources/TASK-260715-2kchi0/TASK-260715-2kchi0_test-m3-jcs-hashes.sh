#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture="$repo_root/.research/fixtures/TASK-260715-2kchi0_valid-pass.json"
schema="$repo_root/.research/fixtures/TASK-260715-2kchi0_m3-evidence-manifest-v1.schema.json"
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/TASK-260715-2kchi0-jcs.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

for command_name in check-jsonschema cmp grep jq od python3 sed shasum wc; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "missing required command: $command_name" >&2
    exit 1
  fi
done

projection='{
  schemaVersion: .schemaVersion,
  protocol: .protocol,
  identity: {
    rowID: .identity.rowID,
    repetitionIndex: .identity.repetitionIndex,
    seed: .identity.seed,
    matrixID: .identity.matrixID,
    workloadID: .identity.workloadID,
    executionClass: .identity.executionClass,
    pairRole: .identity.pairRole,
    baselineRunID: .identity.baselineRunID,
    candidateID: .identity.candidateID
  },
  authority: .authority,
  device: .device,
  environment: .environment,
  toolchain: .toolchain,
  revisions: .revisions,
  server: .server,
  algorithms: .algorithms,
  profile: .profile,
  policies: .policies,
  parameters: .parameters,
  traffic: .traffic,
  impairment: .impairment,
  schedule: .schedule
}'

fail() {
  echo "TASK-260715-2kchi0 JCS regression failed: $1" >&2
  exit 1
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

verify_hash() {
  local path=$1
  local expected=$2
  [[ "$(sha256_file "$path")" == "$expected" ]]
}

# Emit a strict jq/JCS-equivalent subset before jq is allowed to hash anything.
# Python's lexical hooks run before binary64 or jq number handling can erase the
# distinction between unsafe integers, -0, decimals, and exponent notation.
# Printable ASCII makes Python/jq key ordering equal to JCS UTF-16 ordering; safe
# plain integers have identical ECMAScript/JCS rendering. The emitted bytes are
# still compared with jq -cjS below, so any unproved serializer difference fails.
strict_jq_jcs_json() {
  local source_path=$1
  local mode=$2
  python3 - "$source_path" "$mode" <<'PY'
import json
import sys

SAFE_INTEGER = 9007199254740991


class DomainError(ValueError):
    pass


def parse_integer(token):
    if token == "-0":
        raise DomainError("negative zero is outside the schema-v1 JCS subset")
    value = int(token)
    if value < -SAFE_INTEGER or value > SAFE_INTEGER:
        raise DomainError("integer is outside the ECMAScript safe-integer domain")
    return value


def reject_non_integer(token):
    raise DomainError(f"non-plain-integer numeric token is unsupported: {token}")


def reject_constant(token):
    raise DomainError(f"non-finite numeric token is unsupported: {token}")


def reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise DomainError(f"duplicate object key: {key}")
        result[key] = value
    return result


def validate_closed_domain(value):
    if isinstance(value, dict):
        for key, nested in value.items():
            if not all(0x20 <= ord(character) <= 0x7E for character in key):
                raise DomainError("object key is outside printable ASCII")
            validate_closed_domain(nested)
    elif isinstance(value, list):
        for nested in value:
            validate_closed_domain(nested)
    elif isinstance(value, str):
        if not all(0x20 <= ord(character) <= 0x7E for character in value):
            raise DomainError("string is outside printable ASCII")
    elif value is None or isinstance(value, bool):
        return
    elif isinstance(value, int):
        if value < -SAFE_INTEGER or value > SAFE_INTEGER:
            raise DomainError("integer is outside the ECMAScript safe-integer domain")
    else:
        raise DomainError(f"unsupported parsed value type: {type(value).__name__}")


def project_row(data):
    identity_keys = (
        "rowID", "repetitionIndex", "seed", "matrixID", "workloadID",
        "executionClass", "pairRole", "baselineRunID", "candidateID",
    )
    projected = {
        "schemaVersion": data["schemaVersion"],
        "protocol": data["protocol"],
        "identity": {key: data["identity"][key] for key in identity_keys},
    }
    for key in (
        "authority", "device", "environment", "toolchain", "revisions",
        "server", "algorithms", "profile", "policies", "parameters",
        "traffic", "impairment", "schedule",
    ):
        projected[key] = data[key]
    return projected


try:
    with open(sys.argv[1], "r", encoding="utf-8") as source:
        document = json.load(
            source,
            parse_int=parse_integer,
            parse_float=reject_non_integer,
            parse_constant=reject_constant,
            object_pairs_hook=reject_duplicate_keys,
        )
    selected = project_row(document) if sys.argv[2] == "projection" else document
    validate_closed_domain(selected)
    serialized = json.dumps(
        selected,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    sys.stdout.buffer.write(serialized)
except (DomainError, json.JSONDecodeError, KeyError, OSError, TypeError) as error:
    print(f"strict jq/JCS domain rejection: {error}", file=sys.stderr)
    raise SystemExit(1)
PY
}

make_installed_memory_control() {
  local output_path=$1
  local numeric_literal=$2
  sed "s/\"installedMemoryBytes\": 19327352832/\"installedMemoryBytes\": $numeric_literal/" \
    "$fixture" >"$output_path"
  grep -Fq "\"installedMemoryBytes\": $numeric_literal" "$output_path" ||
    fail "failed to preserve hostile numeric source token: $numeric_literal"
}

assert_schema_valid() {
  check-jsonschema --schemafile "$schema" "$1" >/dev/null ||
    fail "numeric negative control is no longer schema-valid: $1"
}

assert_domain_rejects() {
  local source_path=$1
  local expected_reason=$2
  local rejection_log="$source_path.rejection.log"
  if strict_jq_jcs_json "$source_path" projection >"$tmp_dir/rejected-output.json" 2>"$rejection_log"; then
    fail "strict jq/JCS domain accepted unsupported numeric input: $source_path"
  fi
  grep -Fq "$expected_reason" "$rejection_log" ||
    fail "numeric control rejected for the wrong reason: $source_path"
  echo "numeric control $(basename "$source_path"): rejected ($expected_reason)"
}

strict_jq_jcs_json "$fixture" projection >"$tmp_dir/row-config.strict.json" ||
  fail "positive fixture left the proven jq/JCS-equivalent domain"

jq -cjS "$projection" "$fixture" >"$tmp_dir/row-config.jcs"
jq -cS "$projection" "$fixture" >"$tmp_dir/row-config.with-lf"
cmp -s "$tmp_dir/row-config.strict.json" "$tmp_dir/row-config.jcs" ||
  fail "strict serializer and jq -cjS bytes differ inside the proven domain"

# JSON Schema treats these mathematical values as integers, so the semantic
# preflight must reject their unsupported source representations before hashing.
make_installed_memory_control "$tmp_dir/unsafe-positive.json" '9007199254740993'
assert_schema_valid "$tmp_dir/unsafe-positive.json"
assert_domain_rejects "$tmp_dir/unsafe-positive.json" 'integer is outside the ECMAScript safe-integer domain'

make_installed_memory_control "$tmp_dir/negative-zero.json" '-0'
assert_schema_valid "$tmp_dir/negative-zero.json"
assert_domain_rejects "$tmp_dir/negative-zero.json" 'negative zero is outside the schema-v1 JCS subset'

make_installed_memory_control "$tmp_dir/decimal-integer.json" '1.0'
assert_schema_valid "$tmp_dir/decimal-integer.json"
assert_domain_rejects "$tmp_dir/decimal-integer.json" 'non-plain-integer numeric token is unsupported: 1.0'

make_installed_memory_control "$tmp_dir/exponent-integer.json" '1e3'
assert_schema_valid "$tmp_dir/exponent-integer.json"
assert_domain_rejects "$tmp_dir/exponent-integer.json" 'non-plain-integer numeric token is unsupported: 1e3'

# The signed lower bound is exercised even though installedMemoryBytes itself
# is nonnegative in the row schema; the lexical guard is symmetric by contract.
make_installed_memory_control "$tmp_dir/unsafe-negative.json" '-9007199254740992'
assert_domain_rejects "$tmp_dir/unsafe-negative.json" 'integer is outside the ECMAScript safe-integer domain'

recorded_config_hash=$(jq -er '.identity.canonicalRowConfigSHA256' "$fixture")
recorded_run_id=$(jq -er '.identity.runID' "$fixture")
recorded_repetition_id=$(jq -er '.identity.repetitionID' "$fixture")

verify_hash "$tmp_dir/row-config.jcs" "$recorded_config_hash" ||
  fail "positive fixture canonicalRowConfigSHA256 does not match exact JCS bytes"

expected_run_id="m3v1-${recorded_config_hash:0:24}"
[[ "$recorded_run_id" == "$expected_run_id" ]] || fail "runID is not derived from the JCS hash"

repetition_index=$(jq -er '.identity.repetitionIndex' "$fixture")
printf -v repetition_suffix 'r%02d' "$repetition_index"
[[ "$recorded_repetition_id" == "$recorded_run_id-$repetition_suffix" ]] ||
  fail "repetitionID is not derived from runID and repetitionIndex"

jcs_last_byte=$(tail -c 1 "$tmp_dir/row-config.jcs" | od -An -t x1 | tr -d '[:space:]')
[[ "$jcs_last_byte" == "7d" ]] || fail "JCS object does not end at its closing brace"

jcs_bytes=$(wc -c <"$tmp_dir/row-config.jcs" | tr -d '[:space:]')
newline_bytes=$(wc -c <"$tmp_dir/row-config.with-lf" | tr -d '[:space:]')
[[ "$newline_bytes" -eq $((jcs_bytes + 1)) ]] || fail "newline mutation is not exactly one byte longer"

newline_last_byte=$(tail -c 1 "$tmp_dir/row-config.with-lf" | od -An -t x1 | tr -d '[:space:]')
[[ "$newline_last_byte" == "0a" ]] || fail "jq -cS regression input does not end in LF"

if verify_hash "$tmp_dir/row-config.with-lf" "$recorded_config_hash"; then
  fail "semantic hash verification accepted a trailing-LF mutation"
fi

[[ "$(sha256_file "$tmp_dir/row-config.with-lf")" == \
  "389a19b5e967ac58d68c5eacb0054641975065de42853440c18fbe4ffc13a84a" ]] ||
  fail "newline-inclusive regression fingerprint changed unexpectedly"

jq 'del(.review.immutableManifestSHA256)' "$fixture" >"$tmp_dir/immutable-manifest.input.json"
strict_jq_jcs_json "$tmp_dir/immutable-manifest.input.json" document >"$tmp_dir/immutable-manifest.strict.json" ||
  fail "immutable manifest left the proven jq/JCS-equivalent domain"
jq -cjS <"$tmp_dir/immutable-manifest.input.json" >"$tmp_dir/immutable-manifest.jcs"
cmp -s "$tmp_dir/immutable-manifest.strict.json" "$tmp_dir/immutable-manifest.jcs" ||
  fail "strict serializer and jq immutable-manifest bytes differ inside the proven domain"
recorded_immutable_hash=$(jq -er '.review.immutableManifestSHA256' "$fixture")
verify_hash "$tmp_dir/immutable-manifest.jcs" "$recorded_immutable_hash" ||
  fail "positive fixture immutableManifestSHA256 does not match exact JCS bytes"

echo "TASK-260715-2kchi0 JCS hash regression: pass"
