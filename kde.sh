#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_user

log "Installing KDE Plasma desktop"
track_dnf_install desktop-kde @kde-desktop-environment sddm

log "Enabling KDE graphical login"
sudo systemctl set-default graphical.target
sudo systemctl enable sddm

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

log "Configuring KDE Plasma dark mode, cursor, and font"
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
    kwriteconfig6 --file kdeglobals --group General --key font 'JetBrains Mono,11,-1,5,50,0,0,0,0,0'
    kwriteconfig6 --file kdeglobals --group General --key fixed 'JetBrains Mono,11,-1,5,50,0,0,0,0,0'
    kwriteconfig6 --file kdeglobals --group General --key menuFont 'JetBrains Mono,11,-1,5,50,0,0,0,0,0'
    kwriteconfig6 --file kdeglobals --group General --key taskbarFont 'JetBrains Mono,11,-1,5,50,0,0,0,0,0'
    kwriteconfig6 --file kdeglobals --group General --key toolBarFont 'JetBrains Mono,11,-1,5,50,0,0,0,0,0'
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
    kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme McMojave-cursors
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication ghostty
fi

FIRST_WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort | head -n 1)"
if [[ -n "$FIRST_WALLPAPER" ]] && command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
fi

command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true

if [[ -n "${OLD_DESKTOP:-}" ]]; then
    log "Removing previous desktop packages"
    remove_owned_packages "desktop-$OLD_DESKTOP"
fi

state_set desktop kde
state_set gaming "${INSTALL_GAMING:-0}"
state_mark_installed

echo
echo "KDE Plasma setup complete. SDDM and graphical boot are enabled."

ask_reboot
