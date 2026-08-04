#!/usr/bin/env bash
# Checks the howdy-stub.sh contract: exit 0 in ok mode, non-zero in fail mode, both quick.
set -euo pipefail
cd "$(dirname "$0")"
t0=$SECONDS
MUGLOCK_MOCK=ok ./howdy-stub.sh || { echo "FAIL: ok mode exit"; exit 1; }
MUGLOCK_MOCK=fail ./howdy-stub.sh && { echo "FAIL: fail mode exit 0"; exit 1; }
[ $((SECONDS - t0)) -lt 6 ] || { echo "FAIL: too slow"; exit 1; }
echo PASS
