#!/usr/bin/env bash
# Runs the shell the way an installed muglock actually runs: through a symlinked
# config directory (~/.config/quickshell/muglock -> repo/shell).
#
# This exists because every other test launches `qs -p shell` from the repo, and
# that hides a whole class of bug: Quickshell.shellPath() resolves against the
# symlink path, so anything reached with "../" lands outside the config dir and
# silently fails. That is how the unlock chirp and the background dither both
# went missing in the real lockscreen while every test stayed green.
set -euo pipefail
cd "$(dirname "$0")/.."
repo=$(pwd)
tmp=$(mktemp -d)
log=$(mktemp)
pid=""
# shellcheck disable=SC2064
trap 'rm -rf "$tmp" "$log"; [ -n "$pid" ] && kill "$pid" 2>/dev/null || true' EXIT

ln -s "$repo/shell" "$tmp/muglock"

# The invariant, stated directly: everything the running shell needs at runtime
# must be reachable from inside the config directory itself.
for asset in assets/chirp.ogg assets/noise.png; do
    [ -f "$tmp/muglock/$asset" ] \
        || { echo "FAIL: $asset is not reachable through a symlinked config"; exit 1; }
done

# MUGLOCK_DEV=1: a floating window, no session lock, no privileges, no camera.
env MUGLOCK_DEV=1 qs -p "$tmp/muglock" >"$log" 2>&1 &
pid=$!
sleep 3
kill -0 "$pid" 2>/dev/null || { echo "FAIL: qs died"; cat "$log"; exit 1; }
kill "$pid"; wait "$pid" 2>/dev/null || true
pid=""

grep -qE 'Cannot open|No such file' "$log" \
    && { echo "FAIL: something the shell loads could not be opened"; cat "$log"; exit 1; }
grep -qE '^\s*ERROR' "$log" \
    && { echo "FAIL: errors while loading through a symlink"; cat "$log"; exit 1; }
echo PASS
