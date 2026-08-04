#!/usr/bin/env bash
# Builds build/muglock_<ver>_all.deb from the repo layout. Version comes from PKGBUILD
# so the AUR and .deb artifacts can never drift apart.
set -euo pipefail
cd "$(dirname "$0")/.."

ver=$(sed -n 's/^pkgver=//p' PKGBUILD)
[ -n "$ver" ] || { echo "make-deb: cannot read pkgver from PKGBUILD" >&2; exit 1; }

stage=build/deb
rm -rf "$stage"
install -d "$stage/DEBIAN" "$stage/usr/share/muglock" "$stage/usr/bin"
cp -r shell assets "$stage/usr/share/muglock/"
# install.sh resolves the repo from its own dirname, so it must sit NEXT TO shell/;
# /usr/bin/muglock-install is a thin exec wrapper (a symlink would leave $0 in /usr/bin).
install -Dm755 install.sh "$stage/usr/share/muglock/install.sh"
printf '#!/bin/sh\nexec /usr/share/muglock/install.sh "$@"\n' >"$stage/usr/bin/muglock-install"
chmod 755 "$stage/usr/bin/muglock-install"
install -Dm644 LICENSE "$stage/usr/share/doc/muglock/LICENSE"
if [ -f README.md ]; then install -Dm644 README.md "$stage/usr/share/doc/muglock/README.md"; fi

# quickshell and howdy are not in apt — postinst points at them instead of Depends.
cat >"$stage/DEBIAN/control" <<EOF
Package: muglock
Version: $ver
Section: x11
Priority: optional
Architecture: all
Depends: bash
Maintainer: petruha <petruha@users.noreply.github.com>
Homepage: https://github.com/petruha/muglock
Description: macOS-style FaceID screen unlock for Hyprland
 A quickshell QML lockscreen with an animated face-scan plaque, howdy face
 recognition, a success chirp and a password fallback that always works.
 Needs quickshell (qs) and howdy, neither of which ships in apt — see postinst.
EOF

cat >"$stage/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
command -v qs >/dev/null 2>&1 || \
  echo "muglock: quickshell (qs) not found - build it from https://github.com/quickshell-mirror/quickshell"
command -v howdy >/dev/null 2>&1 || \
  echo "muglock: howdy not found - install from ppa:boltgolt/howdy, then run 'sudo howdy add'"
echo "muglock: enable it with 'muglock-install' (links /usr/share/muglock/shell into ~/.config/quickshell/muglock)"
exit 0
EOF
chmod 755 "$stage/DEBIAN/postinst"

install -d build
dpkg-deb --build --root-owner-group "$stage" "build/muglock_${ver}_all.deb"
