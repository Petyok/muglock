#!/usr/bin/env bash
# Checks every FaceScanner outcome through the mock backend, including the
# backend-fault classes that an "any non-zero means no match" mapping hides.
set -euo pipefail
cd "$(dirname "$0")/.."
log=$(mktemp)
trap 'rm -f "$log"' EXIT
# Output goes to a file, not a pipe: in slow mode the killed stub leaves an
# orphaned `sleep` holding the inherited stdout, which would stall a pipeline.
# MUGLOCK_DEV=1 is mandatory: the mock backend is gated on dev mode as well.
run() { env MUGLOCK_DEV=1 MUGLOCK_MOCK="$1" timeout 30 qs -p shell/DevScanner.qml >"$log" 2>&1 || true; }

check() { # mode, expected line
    run "$1"
    grep -q "$2" "$log" || { echo "FAIL $1: expected '$2'"; cat "$log"; exit 1; }
}

check ok     "MUGLOCK: succeeded"
check fail   "MUGLOCK: failed no-match"
check busy   "MUGLOCK: failed unavailable"
check dark   "MUGLOCK: failed too-dark"
check capped "MUGLOCK: failed timeout"
check slow   "MUGLOCK: failed timeout"
echo PASS
