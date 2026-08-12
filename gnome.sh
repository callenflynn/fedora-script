#!/usr/bin/env bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_user

log "Installing GNOME desktop"
sudo dnf group install -y "GNOME Desktop Environment"

install_apps
install_cursor
install_wallpapers

log "Configuring GNOME dark mode and cursor"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || true
gsettings set org.gnome.desktop.interface cursor-theme 'McMojave-cursors' || true

FIRST_WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort | head -n 1)"
if [[ -n "$FIRST_WALLPAPER" ]]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
fi

gsettings set org.gnome.desktop.interface monospace-font-name 'Monospace 11' || true

echo
 echo "GNOME setup complete. Log out and select GNOME at the login screen if needed."
