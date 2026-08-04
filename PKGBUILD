# Maintainer: petruha <petruha@users.noreply.github.com>
pkgname=muglock
pkgver=0.1.0
pkgrel=1
pkgdesc="macOS-style FaceID screen unlock for Hyprland (quickshell lockscreen + howdy)"
arch=(any)
url="https://github.com/petruha/muglock"
license=(MIT)
depends=(quickshell hypridle bash)
optdepends=(
  'howdy: face recognition backend (without it only the password path works)'
  'hyprlock: fallback lockscreen for recovery'
)
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
# Replaced by `updpkgsums` at release time.
sha256sums=('SKIP')

package() {
  cd "$srcdir/$pkgname-$pkgver"
  install -d "$pkgdir/usr/share/$pkgname"
  cp -r shell assets "$pkgdir/usr/share/$pkgname/"
  # install.sh resolves the repo from its own dirname, so it must sit next to shell/;
  # /usr/bin/muglock-install is a thin exec wrapper (a symlink would leave $0 in /usr/bin).
  install -Dm755 install.sh "$pkgdir/usr/share/$pkgname/install.sh"
  printf '#!/bin/sh\nexec /usr/share/%s/install.sh "$@"\n' "$pkgname" \
    >"$pkgdir/usr/bin/$pkgname-install"
  chmod 755 "$pkgdir/usr/bin/$pkgname-install"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
