#!/usr/bin/env bash
# Checks all three FaceScanner outcomes through the mock backend.
set -euo pipefail
cd "$(dirname "$0")/.."
log=$(mktemp)
trap 'rm -f "$log"' EXIT
# Output goes to a file, not a pipe: in slow mode the killed stub leaves an
# orphaned `sleep` holding the inherited stdout, which would stall a pipeline.
# MUGLOCK_DEV=1 is mandatory: the mock backend is gated on dev mode as well.
run() { env MUGLOCK_DEV=1 MUGLOCK_MOCK="$1" timeout 20 qs -p shell/DevScanner.qml >"$log" 2>&1 || true; }

run ok;   grep -q "MUGLOCK: succeeded"       "$log" || { echo "FAIL ok";      cat "$log"; exit 1; }
run fail; grep -q "MUGLOCK: failed no-match" "$log" || { echo "FAIL fail";    cat "$log"; exit 1; }
run slow; grep -q "MUGLOCK: failed timeout"  "$log" || { echo "FAIL timeout"; cat "$log"; exit 1; }
echo PASS
