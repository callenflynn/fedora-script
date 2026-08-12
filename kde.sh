#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_user

log "Installing KDE Plasma desktop"
sudo dnf group install -y "KDE Plasma Workspaces"

install_apps
install_cursor
install_wallpapers

log "Configuring KDE Plasma dark mode and cursor"
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
    kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme McMojave-cursors
fi

FIRST_WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort | head -n 1)"
if [[ -n "$FIRST_WALLPAPER" ]] && command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
fi

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true

echo
 echo "KDE Plasma setup complete. Log out and select Plasma at the login screen if needed."
