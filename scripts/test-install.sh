#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n install.sh || { echo "FAIL: syntax"; exit 1; }
command -v shellcheck >/dev/null && { shellcheck -S warning install.sh || exit 1; }
out=$(./install.sh --dry-run)
grep -q "sudoers.d/muglock" <<<"$out" || { echo "FAIL: no sudoers step"; exit 1; }
grep -q "NOPASSWD: /usr/bin/timeout --signal=KILL 12 /usr/bin/python3 /usr/lib/security/howdy/compare.py" <<<"$out" || { echo "FAIL: sudoers line"; exit 1; }
grep -q "hypridle" <<<"$out" || { echo "FAIL: no hypridle hint"; exit 1; }
# Real hypridle keys — `on-lock`/`on-resume` in general{} are silently ignored.
grep -q "lock_cmd = qs -p ~/.config/quickshell/muglock ipc call muglock lock" <<<"$out" || { echo "FAIL: hypridle lock_cmd"; exit 1; }
grep -q "after_sleep_cmd = qs -p ~/.config/quickshell/muglock ipc call muglock wake" <<<"$out" || { echo "FAIL: hypridle after_sleep_cmd"; exit 1; }
echo PASS
