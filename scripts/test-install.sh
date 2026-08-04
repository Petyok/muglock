#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n install.sh || { echo "FAIL: syntax"; exit 1; }
command -v shellcheck >/dev/null && { shellcheck -S warning install.sh || exit 1; }
out=$(./install.sh --dry-run)
grep -q "sudoers.d/muglock" <<<"$out" || { echo "FAIL: no sudoers step"; exit 1; }
grep -q "NOPASSWD: /usr/bin/howdy compare" <<<"$out" || { echo "FAIL: sudoers line"; exit 1; }
grep -q "hypridle" <<<"$out" || { echo "FAIL: no hypridle hint"; exit 1; }
echo PASS
