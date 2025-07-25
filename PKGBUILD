# PKGBUILD
pkgname=abyss-pkg
pkgver=1.1
pkgrel=1
pkgdesc="XPM - A simple shell-based Pacman and AUR helper for Arch Linux and derivatives. Just aliased as PKG just like BSD derivatives."
arch=('any')
url="https://github.com/Hexalantes/abyss-pkg"
license=('GPL')
depends=('bash' 'curl' 'wget' 'tar' 'git' 'zstd' 'libarchive' 'coreutils' 'jq' 'pacman' 'sudo' 'xz' 'base-devel')
conflicts=('pkg')
source=('pkg.sh')
md5sums=('SKIP')

package() {
  install -Dm755 "$srcdir/pkg.sh" "$pkgdir/usr/bin/pkg"
}
