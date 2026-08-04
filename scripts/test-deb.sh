#!/usr/bin/env bash
# Checks the release artifacts: the .deb builds and carries the shell payload,
# and the PKGBUILD parses cleanly for the AUR.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/make-deb.sh
deb=build/muglock_0.1.0_all.deb
dpkg-deb --info "$deb" | grep -q "Package: muglock" || { echo "FAIL: control"; exit 1; }
dpkg-deb --contents "$deb" | grep -q "usr/share/muglock/shell/shell.qml" || { echo "FAIL: shell.qml not packaged"; exit 1; }
dpkg-deb --contents "$deb" | grep -q "usr/bin/muglock-install" || { echo "FAIL: muglock-install not packaged"; exit 1; }
makepkg --printsrcinfo >/dev/null || { echo "FAIL: PKGBUILD"; exit 1; }
echo PASS
