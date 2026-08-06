#!/usr/bin/env bash
# Checks the release artifacts: the .deb builds and carries the shell payload,
# and the PKGBUILD parses cleanly for the AUR.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/make-deb.sh
deb=build/muglock_$(sed -n 's/^pkgver=//p' PKGBUILD)_all.deb
# Every dpkg-deb output is captured into a variable first, never piped into
# `grep -q`: grep -q exits at the first match, which SIGPIPEs the tar dpkg-deb
# forked, and `pipefail` turns that into a spurious failure (observed ~1 run in 10
# even for the small `--info` output).
info=$(dpkg-deb --info "$deb")
grep -q "Package: muglock" <<<"$info" || { echo "FAIL: control"; exit 1; }
contents=$(dpkg-deb --contents "$deb")
grep -q "usr/share/muglock/shell/shell.qml" <<<"$contents" || { echo "FAIL: shell.qml not packaged"; exit 1; }
grep -q "usr/bin/muglock-install" <<<"$contents" || { echo "FAIL: muglock-install not packaged"; exit 1; }
postinst=$(dpkg-deb --ctrl-tarfile "$deb" | tar -xOf - ./postinst)
grep -q "howdy-next" <<<"$postinst" || { echo "FAIL: postinst backend hint"; exit 1; }
grep -q "ppa:boltgolt/howdy" <<<"$postinst" && { echo "FAIL: legacy howdy hint"; exit 1; }
makepkg --printsrcinfo >/dev/null || { echo "FAIL: PKGBUILD"; exit 1; }
echo PASS
