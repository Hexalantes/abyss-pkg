#!/bin/bash
set -e

if [[ $# -eq 0 ]]; then
    echo "Usage: help, usage, install, add, remove, delete, upgrade, update, installaur, installarch, search, info, query, version,"
    echo "autoremove, clean, check, verify, stats, reinstall, orphans, whatdepends, changelog, files, owns, extract, lock, unlock"
fi

CMD="$1"
shift
PACKAGES=("$@")

aur_search() {
  query="$1"
  results=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=search&arg=$query" | jq -r '.results[] | "\(.Name) - \(.Description)"')
  if [[ -z "$results" ]]; then
    echo "No packages found in AUR for '$query'."
    return 1
  else
    echo "$results"
    return 0
  fi
}

aur_package_exists() {
  pkgname="$1"
  count=$(curl -s "https://aur.archlinux.org/rpc/?v=5&type=info&arg=${pkgname}" | jq '.results | length')
  if [[ "$count" -gt 0 ]]; then
    return 0
  else
    return 1
  fi
}

aur_install() {
  pkgname="$1"
  if ! aur_package_exists "$pkgname"; then
    echo "AUR package '$pkgname' not found. Aborting installation."
    return 1
  fi
  tempdir=$(mktemp -d)
  echo "Installing from AUR..."
  git clone "https://aur.archlinux.org/${pkgname}.git" "$tempdir" || { echo "Failed to clone AUR repo."; rm -rf "$tempdir"; return 1; }
  cd "$tempdir"
  makepkg -si --noconfirm
  cd -
  rm -rf "$tempdir"
}

install_local() {
  local pkgfile="$1"
  if [[ ! -f "$pkgfile" ]]; then
    echo "Error: File '$pkgfile' does not exist."
    exit 1
  fi
  echo "Installing local package file '$pkgfile'..."
  doas pacman -U --noconfirm "$pkgfile"
}

usage() {
  echo ""
  echo "Usage:"
  echo "  pkg <command> [options] [package(s)/file(s)]"
  echo ""
  echo "Core Commands:"
  echo "  install, add        Install package(s) from repo or AUR"
  echo "    -f, --file        Install local .pkg.tar.zst package file(s)"
  echo "  remove, delete      Uninstall package(s)"
  echo "  upgrade             Full upgrade (pacman -Syu) or upgrade specific package(s)"
  echo "  update              Sync package database (pacman -Sy)"
  echo "  help                Show this"
  echo "  installaur          Install package(s) from only AUR"
  echo "  installarch         Install package(s) from only official repository."
  echo "Search & Info:"
  echo "  search <pkg>        Search in official repos"
  echo "  search <pkg> -a     Search in AUR"
  echo "  info <pkg>          Show info from official repos"
  echo "  query <pkg>         Show detailed local package info"
  echo "  version <pkg>       Show installed vs repo version"
  echo ""
  echo "System Maintenance:"
  echo "  autoremove          Remove orphaned packages"
  echo "  clean               Clean package cache"
  echo "  check               Verify installed files exist"
  echo "  verify              Check integrity of installed package(s)"
  echo "  stats               Show basic package stats"
  echo ""
  echo "Advanced:"
  echo "  reinstall <pkg>     Reinstall specified package(s)"
  echo "  orphans             List orphaned packages"
  echo "  whatdepends <pkg>   Show reverse dependencies"
  echo "  changelog <pkg>     Show recent updates from pacman log"
  echo ""
  echo "Filesystem:"
  echo "  files <pkg>         List files installed by package"
  echo "  owns <file>         Find which package owns a file"
  echo "  extract <.tar.zst>  Extract package archive (no install)"
  echo ""
  echo "Package Locking:"
  echo "  lock <pkg>          Lock package from upgrades (experimental)"
  echo "  unlock <pkg>        Unlock previously locked package"
  echo ""
  echo "Examples:"
  echo "  pkg install neofetch"
  echo "  pkg search yay -a"
  echo "  pkg install -f ./path/to/pkg.tar.zst"
  echo "  pkg upgrade"
  echo ""
  exit 0
}


if [[ -z "$CMD" ]]; then
  usage
fi

case "$CMD" in
  install|add|-i)
    if [[ "$1" == "-f" || "$1" == "--file" ]]; then
      shift
      for pkgfile in "$@"; do
        install_local "$pkgfile"
      done
    else
      for pkg in "${PACKAGES[@]}"; do
        echo "Trying to install package '$pkg' from Pacman repos..."
        if doas pacman -S --noconfirm "$pkg"; then
          echo "Package '$pkg' installed successfully from Pacman repo."
        else
	  echo "Wait for AUR checking... '$pkg'"
          if [[ $EUID -eq 0 ]]; then
            echo "AUR packages cannot be installed as root. Please run as a regular user." >&2
            exit 1
          fi
          aur_install "$pkg"
        fi
      done
    fi
    ;;
  installaur|-ia|addaur)
    for pkg in "${PACKAGES[@]}"; do
      echo "Wait for AUR checking... '$pkg'"
      if [[ $EUID -eq 0 ]]; then
        echo "AUR packages cannot be installed as root. Please run as a reguler user." >&2
        exit 1
      fi
      aur_install "$pkg"
    done
    ;;
  installarch|-iar|addarch)
    for pkg in "${PACKAGES[@]}"; do
      echo "Trying to install package '$pkg' from official repos..."
      if doas pacman -S --noconfirm "$pkg"; then
        echo "Package '$pkg' installed successfully from official repo."
      else
	echo "Package '$pkg' could not be installed from official repo." >&2
	exit 1
      fi
    done
    ;;
  remove|delete|-r)
    doas pacman -R --noconfirm "${PACKAGES[@]}"
    ;;
  upgrade|-U)
    if [[ ${#PACKAGES[@]} -eq 0 ]]; then
      doas pacman -Syu --noconfirm
    else
      for pkg in "${PACKAGES[@]}"; do
        echo "Updating package '$pkg'..."
        doas pacman -Sy --noconfirm "$pkg"
      done
    fi
    ;;
  update|-u)
    doas pacman -Sy --noconfirm
    ;;
  search|-s)
    if [[ "${PACKAGES[1]}" == "-a" || "${PACKAGES[1]}" == "--aur" ]]; then
      query="${PACKAGES[0]}"
      echo "Searching AUR for '$query'..."
      curl -s "https://aur.archlinux.org/rpc/?v=5&type=search&arg=$query" | jq -r '.results[] | "\(.Name) - \(.Description)"'
    else
      pacman -Ss "${PACKAGES[0]}"
    fi
    ;;
  info)
    pacman -Si "${PACKAGES[@]}"
    ;;
  autoremove)
    doas pacman -Rns $(pacman -Qtdq) || echo "No orphaned packages to remove."
    ;;
  clean)
    doas pacman -Sc --noconfirm
    ;;
  check)
    doas pacman -Qk
    ;;
  audit)
    echo "Audit command is not supported by pacman."
    ;;
  lock)
    for pkg in "${PACKAGES[@]}"; do
      doas bash -c "echo $pkg >> /etc/pacman.d/holdlist"
    done
    echo "Packages locked: ${PACKAGES[*]}"
    ;;
  unlock)
    for pkg in "${PACKAGES[@]}"; do
      doas sed -i "/^$pkg$/d" /etc/pacman.d/holdlist
    done
    echo "Packages unlocked: ${PACKAGES[*]}"
    ;;
  which)
    for file in "${PACKAGES[@]}"; do
      pacman -Qo "$file"
    done
    ;;
  query)
    for pkg in "${PACKAGES[@]}"; do
      pacman -Qi "$pkg"
    done
    ;;
  version)
    for pkg in "${PACKAGES[@]}"; do
      echo "Local version:"
      pacman -Qi "$pkg" | grep Version
      echo "Repo version:"
      pacman -Si "$pkg" | grep Version
    done
    ;;
  fetch)
    for pkg in "${PACKAGES[@]}"; do
      doas pacman -Sw "$pkg"
    done
    ;;
  files)
    for pkg in "${PACKAGES[@]}"; do
      pacman -Ql "$pkg"
    done
    ;;
  owns)
    for path in "${PACKAGES[@]}"; do
      pacman -Qo "$path"
    done
    ;;
  extract)
    for file in "${PACKAGES[@]}"; do
      bsdtar -xf "$file"
    done
    ;;
  reinstall)
    for pkg in "${PACKAGES[@]}"; do
      doas pacman -S --noconfirm "$pkg"
    done
    ;;
  orphans)
    pacman -Qtdq
    ;;
  whatdepends)
    for pkg in "${PACKAGES[@]}"; do
      pactree -r "$pkg"
    done
    ;;
  changelog)
    for pkg in "${PACKAGES[@]}"; do
      grep "\[ALPM\] upgraded $pkg" /var/log/pacman.log
    done
    ;;
  homepage)
    for pkg in "${PACKAGES[@]}"; do
      url=$(pacman -Si "$pkg" | grep "URL" | awk '{print $3}')
      echo "$pkg homepage: $url"
    done
    ;;
  stats)
    echo "Total installed: $(pacman -Q | wc -l)"
    echo "Explicitly installed: $(pacman -Qe | wc -l)"
    echo "Orphans: $(pacman -Qtdq | wc -l)"
    ;;
  verify)
    doas pacman -Qk "${PACKAGES[@]}"
    ;;

  help|usage|-h|--help)
    usage
    ;;
  *)
    echo "Usage: help, usage, install, add, remove, delete, upgrade, update, installaur, installarch, search, info, query, version,"
    echo "autoremove, clean, check, verify, stats, reinstall, orphans, whatdepends, changelog, files, owns, extract, lock, unlock"
    ;;

esac
