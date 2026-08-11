#!/bin/bash

set -u
set -o pipefail

SIGNING_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/relux-probe-signing.XXXXXX")"
PROFILE_DIRECTORY="${RELUX_PROBE_PROFILE_DIRECTORY:-$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles}"
HOST_PROFILE_UUID="c0a3cd4e-77c8-475e-98e0-6deec8269810"
PROVIDER_PROFILE_UUID="ef64bcae-00ac-458f-94dc-45834429fe80"

cleanup() {
  case "$SIGNING_TEMP" in
    "${TMPDIR:-/tmp}"/relux-probe-signing.*) rm -rf "$SIGNING_TEMP" ;;
    *) echo "refusing to clean unexpected signing-preflight path" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

printf '%s\n' 'int main(void) { return 0; }' > "$SIGNING_TEMP/main.c"
if ! xcrun clang "$SIGNING_TEMP/main.c" -o "$SIGNING_TEMP/baseline"; then
  echo "error: unable to compile the signing-access probe" >&2
  exit 2
fi

IDENTITIES="$SIGNING_TEMP/identities.txt"
security find-identity -v -p codesigning > "$IDENTITIES" 2>/dev/null || true

check_profile_signing_access() {
  label="$1"
  approved_uuid="$2"
  profile="$PROFILE_DIRECTORY/$approved_uuid.provisionprofile"
  decoded="$SIGNING_TEMP/$label-profile.plist"

  if [ ! -f "$profile" ]; then
    echo "error: approved $label profile is not installed (UUID $approved_uuid)" >&2
    return 1
  fi
  if ! security cms -D -i "$profile" > "$decoded" 2>/dev/null; then
    echo "error: approved $label profile cannot be decoded" >&2
    return 1
  fi
  decoded_uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$decoded" 2>/dev/null || true)"
  if [ "$decoded_uuid" != "$approved_uuid" ]; then
    echo "error: approved $label profile UUID drifted" >&2
    return 1
  fi

  certificate_count="$(plutil -extract DeveloperCertificates raw -o - "$decoded" 2>/dev/null || true)"
  case "$certificate_count" in
    '' | *[!0-9]*)
      echo "error: approved $label profile has no readable development certificates" >&2
      return 1
      ;;
  esac

  index=0
  matching_identity_count=0
  while [ "$index" -lt "$certificate_count" ]; do
    encoded_certificate="$SIGNING_TEMP/$label-certificate-$index.base64"
    certificate="$SIGNING_TEMP/$label-certificate-$index.der"
    if plutil -extract "DeveloperCertificates.$index" raw \
      -o "$encoded_certificate" "$decoded" >/dev/null 2>&1 \
      && base64 -D -i "$encoded_certificate" -o "$certificate" >/dev/null 2>&1; then
      fingerprint="$(
        openssl x509 -inform DER -in "$certificate" -noout -fingerprint -sha1 2>/dev/null \
          | sed 's/^.*=//' | tr -d ':'
      )"
      if [ -n "$fingerprint" ] \
        && awk -v expected="$fingerprint" '$2 == expected { found = 1 } END { exit !found }' \
          "$IDENTITIES"; then
        matching_identity_count=$((matching_identity_count + 1))
        candidate="$SIGNING_TEMP/$label-candidate-$index"
        cp "$SIGNING_TEMP/baseline" "$candidate"
        if codesign --force --sign "$fingerprint" "$candidate" >/dev/null 2>&1; then
          echo "Signing access preflight passed for the approved $label profile."
          return 0
        fi
      fi
    fi
    index=$((index + 1))
  done

  if [ "$matching_identity_count" -eq 0 ]; then
    echo "error: no installed Apple Development identity matches the approved $label profile" >&2
  else
    echo "error: approved $label profile has an installed identity, but its private key cannot sign" >&2
  fi
  return 1
}

failures=0
check_profile_signing_access host "$HOST_PROFILE_UUID" || failures=$((failures + 1))
check_profile_signing_access provider "$PROVIDER_PROFILE_UUID" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
  echo "Unlock the login Keychain or grant codesign access to the approved Apple Development private key, then rerun build-and-inspect.sh." >&2
  exit 1
fi

echo "Signing access preflight passed for both approved development profiles."
