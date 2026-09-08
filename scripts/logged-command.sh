#!/bin/sh
# Retain complete child output in the uploaded log tree and expose failures inline.
run_logged_command() {
  command_log=$1
  shift
  if "$@" > "$command_log" 2>&1; then
    return 0
  else
    command_status=$?
    printf 'FAIL: %s (exit %s; log: %s)\n' "$*" "$command_status" "$command_log" >&2
    cat "$command_log" >&2
    return "$command_status"
  fi
}
