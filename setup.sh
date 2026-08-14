#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/callenflynn/fedora-script/refs/heads/main"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as your normal user, not as root."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required."
    exit 1
fi

if command -v curl >/dev/null 2>&1; then
    download() {
        curl -fsSL "$1" -o "$2"
    }
elif command -v wget >/dev/null 2>&1; then
    download() {
        wget -qO "$2" "$1"
    }
else
    echo "curl or wget is required to download the Fedora setup files."
    exit 1
fi

printf '\nFedora desktop setup\n'
printf '%s\n' '===================='
printf 'Choose your desktop environment:\n'
printf '1) GNOME\n'
printf '2) KDE Plasma\n'

while true; do
    read -r -p 'Enter 1 or 2: ' choice
    case "$choice" in
        1) DESKTOP_SCRIPT="gnome.sh"; break ;;
        2) DESKTOP_SCRIPT="kde.sh"; break ;;
        *) echo "Please enter 1 or 2." ;;
    esac
done

printf '\nOptional components:\n'

while true; do
    read -r -p 'Install gaming applications (Steam, Prism Launcher, Heroic)? [y/N] ' answer
    case "${answer,,}" in
        y|yes) INSTALL_GAMING=1; break ;;
        n|no|"") INSTALL_GAMING=0; break ;;
        *) echo "Please answer y or n." ;;
    esac
done

while true; do
    read -r -p 'Set up iCloud sync? [y/N] ' answer
    case "${answer,,}" in
        y|yes) INSTALL_ICLOUD=1; break ;;
        n|no|"") INSTALL_ICLOUD=0; break ;;
        *) echo "Please answer y or n." ;;
    esac
done

while true; do
    read -r -p 'Install Proton Pass? [y/N] ' answer
    case "${answer,,}" in
        y|yes) INSTALL_PROTON_PASS=1; break ;;
        n|no|"") INSTALL_PROTON_PASS=0; break ;;
        *) echo "Please answer y or n." ;;
    esac
done

printf '\nRequesting administrator access...\n'
sudo -v

printf '\nDownloading %s...\n' "$DESKTOP_SCRIPT"
download "$BASE_URL/common.sh" "$WORK_DIR/common.sh"
download "$BASE_URL/$DESKTOP_SCRIPT" "$WORK_DIR/$DESKTOP_SCRIPT"
download "$BASE_URL/bg/saturn-rings.jpg" "$WORK_DIR/bg-saturn-rings.jpg"

mkdir -p "$WORK_DIR/bg"
mv "$WORK_DIR/bg-saturn-rings.jpg" "$WORK_DIR/bg/saturn-rings.jpg"
chmod +x "$WORK_DIR/$DESKTOP_SCRIPT"

export INSTALL_GAMING INSTALL_ICLOUD INSTALL_PROTON_PASS

exec bash "$WORK_DIR/$DESKTOP_SCRIPT"
