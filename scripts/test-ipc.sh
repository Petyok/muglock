#!/usr/bin/env bash
# End-to-end check of shell.qml through its own IPC surface, with no privileges:
# MUGLOCK_DEV=1 keeps the session lock inert, MUGLOCK_MOCK=ok routes the scan to
# scripts/howdy-stub.sh. `wake` must produce scanning -> success.
set -euo pipefail
cd "$(dirname "$0")/.."
log=$(mktemp)
log2=""
pid=""
pid2=""
cleanup() {
    rm -f "$log" "$log2"
    for p in $pid $pid2; do kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT

env MUGLOCK_DEV=1 MUGLOCK_MOCK=ok qs -p shell >"$log" 2>&1 &
pid=$!
sleep 2
kill -0 "$pid" 2>/dev/null || { echo "FAIL: qs died on startup"; cat "$log"; exit 1; }

qs -p shell ipc call muglock wake >>"$log" 2>&1 \
    || { echo "FAIL: ipc call rejected"; cat "$log"; exit 1; }
sleep 4

kill "$pid"; wait "$pid" 2>/dev/null || true
pid=""

grep -q "MUGLOCK: phase scanning" "$log" || { echo "FAIL: no scan start"; cat "$log"; exit 1; }
grep -q "MUGLOCK: phase success" "$log"  || { echo "FAIL: no success transition"; cat "$log"; exit 1; }

# Second scenario: a failing scan must auto-retry exactly maxScanAttempts (3)
# times, shake between attempts, and only then settle on the failed phase.
log2=$(mktemp)

env MUGLOCK_DEV=1 MUGLOCK_MOCK=fail qs -p shell >"$log2" 2>&1 &
pid2=$!
sleep 2
qs -p shell ipc call muglock wake >>"$log2" 2>&1 \
    || { echo "FAIL: ipc call rejected (fail run)"; cat "$log2"; exit 1; }
sleep 9

kill "$pid2"; wait "$pid2" 2>/dev/null || true
pid2=""

grep -q "MUGLOCK: attempt 3" "$log2" || { echo "FAIL: no third auto-attempt"; cat "$log2"; exit 1; }
grep -q "MUGLOCK: attempt 4" "$log2" && { echo "FAIL: retried past the cap"; cat "$log2"; exit 1; }
grep -q "MUGLOCK: phase failed" "$log2" || { echo "FAIL: no terminal failed phase"; cat "$log2"; exit 1; }
echo PASS
