#!/usr/bin/env bash
# End-to-end check of shell.qml through its own IPC surface, with no privileges:
# MUGLOCK_DEV=1 keeps the session lock inert, MUGLOCK_MOCK=ok routes the scan to
# scripts/howdy-stub.sh. `wake` must produce scanning -> success.
set -euo pipefail
cd "$(dirname "$0")/.."
log=$(mktemp)
pid=""
# shellcheck disable=SC2064  # $log/$pid must expand now, the trap runs later
trap 'rm -f "$log"; [ -n "$pid" ] && kill "$pid" 2>/dev/null || true' EXIT

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
echo PASS
