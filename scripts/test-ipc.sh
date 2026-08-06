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
# Overlay state must be back at rest after every unlock. It is reset explicitly
# on each exit rather than from an animation signal: fadeAnim.stop() emits
# nothing when the animation never ran (the watchdog path), and that once left a
# fully opaque overlay pinned over the desktop until the daemon was killed.
grep -q "overlay at rest, armed=false" "$log" \
    || { echo "FAIL: overlay state not returned to rest after unlock"; cat "$log"; exit 1; }

# Second scenario: a failing scan settles on the failed phase after ONE
# process run — retries are howdy's internal frame loop, never a process
# restart (each restart would pay python+camera startup with the camera off).
log2=$(mktemp)

env MUGLOCK_DEV=1 MUGLOCK_MOCK=fail qs -p shell >"$log2" 2>&1 &
pid2=$!
sleep 2
qs -p shell ipc call muglock wake >>"$log2" 2>&1 \
    || { echo "FAIL: ipc call rejected (fail run)"; cat "$log2"; exit 1; }
sleep 4

kill "$pid2"; wait "$pid2" 2>/dev/null || true
pid2=""

grep -q "MUGLOCK: phase failed" "$log2" || { echo "FAIL: no terminal failed phase"; cat "$log2"; exit 1; }
[ "$(grep -c "MUGLOCK: phase scanning" "$log2")" -eq 1 ] \
    || { echo "FAIL: scan process was restarted"; cat "$log2"; exit 1; }
echo PASS
