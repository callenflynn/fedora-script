#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_user

log "Installing Fedora Script applications"
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

printf '\nApplication setup complete. No desktop environment was changed.\n'
ask_reboot
