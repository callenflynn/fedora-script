#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_user

log "Installing GNOME desktop"
sudo dnf install -y @workstation-product-environment

install_apps

if [[ "${INSTALL_GAMING:-0}" == "1" ]]; then
    install_gaming_apps
fi

if [[ "${INSTALL_ICLOUD:-0}" == "1" ]]; then
    install_icloud_sync
fi

if [[ "${INSTALL_PROTON_PASS:-0}" == "1" ]]; then
    install_proton_pass
fi

install_cursor
install_wallpapers

log "Installing GNOME extensions"
sudo dnf install -y gnome-shell-extension-gsconnect gnome-menus

EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXTENSIONS_DIR"

install_gnome_extension() {
    local uuid="$1"
    local url="https://extensions.gnome.org/extension-info/?pk=$uuid&shell_version=$(gnome-shell --version | sed -E 's/.* ([0-9]+)\..*/\1/')"
    local zip
    zip="$(mktemp --suffix=.zip)"
    if curl -fsSL "$url" -o "$zip"; then
        rm -rf "$EXTENSIONS_DIR/$uuid"
        mkdir -p "$EXTENSIONS_DIR/$uuid"
        unzip -q "$zip" -d "$EXTENSIONS_DIR/$uuid"
    else
        echo "Could not download GNOME extension $uuid; install it from extensions.gnome.org."
    fi
    rm -f "$zip"
}

install_gnome_extension "arcmenu@arcmenu.com"
install_gnome_extension "gsconnect@andyholmes.github.io"

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
echo "ArcMenu and GSConnect were installed."
