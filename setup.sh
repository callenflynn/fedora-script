#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as your normal user, not as root."
    exit 1
fi

if [[ ! -d "$REPO_DIR/bg" ]]; then
    echo "Could not find $REPO_DIR/bg. Run this from the cloned repository."
    exit 1
fi

printf '\nFedora dotfiles installer\n'
printf '%s\n' '=========================='
printf 'Choose your desktop environment:\n'
printf '  1) GNOME\n'
printf '  2) KDE Plasma\n\n'

while true; do
    read -r -p 'Enter 1 or 2: ' choice
    case "$choice" in
        1) exec bash "$REPO_DIR/gnome.sh" ;;
        2) exec bash "$REPO_DIR/kde.sh" ;;
        *) echo "Please enter 1 or 2." ;;
    esac
done
