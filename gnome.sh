#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

require_user

log "Installing GNOME desktop"
track_dnf_install desktop-gnome @workstation-product-environment

install_apps

if [[ "${REMOVE_GAMING:-0}" == "1" ]]; then
    remove_gaming_apps
elif [[ "${INSTALL_GAMING:-0}" == "1" ]]; then
    install_gaming_apps
fi

if [[ "${REMOVE_ICLOUD:-0}" == "1" ]]; then
    remove_icloud_sync
elif [[ "${INSTALL_ICLOUD:-0}" == "1" ]]; then
    install_icloud_sync
fi

if [[ "${REMOVE_PROTON_PASS:-0}" == "1" ]]; then
    remove_proton_pass
elif [[ "${INSTALL_PROTON_PASS:-0}" == "1" ]]; then
    install_proton_pass
fi

install_cursor
install_wallpapers

log "Installing GNOME extensions"
track_dnf_install gnome-extensions gnome-shell-extension-gsconnect gnome-menus

EXTENSIONS_DIR="$HOME/.local/share/gnome-shell/extensions"
mkdir -p "$EXTENSIONS_DIR"

install_gnome_extension() {
    local uuid="$1"
    local pk="$2"
    local shell_version
    shell_version="$(gnome-shell --version | sed -E 's/.* ([0-9]+)\..*/\1/')"
    local info_file
    info_file="$(mktemp)"
    local zip
    zip="$(mktemp --suffix=.zip)"

    if [[ -d "$EXTENSIONS_DIR/$uuid" ]]; then
        echo "GNOME extension $uuid is already installed; leaving it untouched."
    elif curl -fsSL "https://extensions.gnome.org/extension-info/?pk=${pk}&shell_version=${shell_version}&api_version=1" -o "$info_file"; then
        local download_url
        download_url="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("download_url", ""))' "$info_file" 2>/dev/null || true)"
        if [[ -n "$download_url" ]] && curl -fsSL "$download_url" -o "$zip"; then
            mkdir -p "$EXTENSIONS_DIR/$uuid"
            unzip -q "$zip" -d "$EXTENSIONS_DIR/$uuid"
        else
            echo "Could not get a compatible download for $uuid."
        fi
    else
        echo "Could not query GNOME Extensions for $uuid."
    fi

    rm -f "$info_file" "$zip"
}

install_gnome_extension "arcmenu@arcmenu.com" 3628

log "Configuring GNOME dark mode, cursor, and font"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || true
gsettings set org.gnome.desktop.interface cursor-theme 'McMojave-cursors' || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 11' || true

FIRST_WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort | head -n 1)"
if [[ -n "$FIRST_WALLPAPER" ]]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
fi

state_set desktop gnome
state_set gaming "${INSTALL_GAMING:-0}"
state_mark_installed

echo
echo "GNOME setup complete. Log out and select GNOME at the login screen if needed."
echo "ArcMenu and GSConnect were installed when compatible with this GNOME release."

printf '\nSetup is complete. A reboot is recommended to finish applying system changes.\n'
while true; do
    read -r -p 'Reboot now? [y/N] ' answer < /dev/tty || break
    case "${answer,,}" in
        y|yes) sudo systemctl reboot; break ;;
        n|no|'') echo "Reboot skipped. You can reboot later with: sudo systemctl reboot"; break ;;
        *) echo "Please answer y or n." ;;
    esac
done
