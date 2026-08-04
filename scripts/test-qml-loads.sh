#!/usr/bin/env bash
# Usage: test-qml-loads.sh <config-dir-or-qml> [seconds]
# Loads a quickshell target in dev/mock mode and fails on crash or QML errors.
set -euo pipefail
target=${1:?}; secs=${2:-3}
log=$(mktemp)
env MUGLOCK_DEV=1 MUGLOCK_MOCK=ok qs -p "$target" >"$log" 2>&1 &
pid=$!
sleep "$secs"
if ! kill -0 "$pid" 2>/dev/null; then echo "FAIL: qs died"; cat "$log"; exit 1; fi
kill "$pid"; wait "$pid" 2>/dev/null || true
grep -Ei 'error|cannot|failed to create' "$log" && { echo "FAIL: errors in log"; exit 1; }
echo PASS
