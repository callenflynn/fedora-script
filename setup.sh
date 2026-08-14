#!/usr/bin/env bash
set -euo pipefail

BASE_URL="https://raw.githubusercontent.com/callenflynn/fedora-script/refs/heads/main"
WORK_DIR="$(mktemp -d)"
SUDO_KEEPALIVE_PID=""

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not as root."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required."
    exit 1
fi

if command -v curl >/dev/null 2>&1; then
    download() { curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then
    download() { wget -qO "$2" "$1"; }
else
    echo "curl or wget is required to download the Fedora setup files."
    exit 1
fi

cleanup() {
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

printf '\nFedora desktop setup\n'
printf '%s\n' '===================='

download "$BASE_URL/state.sh" "$WORK_DIR/state.sh"
source "$WORK_DIR/state.sh"

ask_yes_no() {
    local prompt="$1" default="$2" answer
    while true; do
        if [[ "$default" == "yes" ]]; then
            read -r -p "$prompt [Y/n] " answer
            [[ -z "$answer" ]] && return 0
        else
            read -r -p "$prompt [y/N] " answer
            [[ -z "$answer" ]] && return 1
        fi
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

CURRENT_DESKTOP=""
CURRENT_GAMING=0
CURRENT_ICLOUD=0
CURRENT_PROTON=0

if state_has_installation; then
    CURRENT_DESKTOP="$(state_get desktop 2>/dev/null || true)"
    CURRENT_GAMING="$(state_get gaming 2>/dev/null || echo 0)"
    CURRENT_ICLOUD="$(state_get icloud 2>/dev/null || echo 0)"
    CURRENT_PROTON="$(state_get proton_pass 2>/dev/null || echo 0)"

    printf '\nExisting Fedora Script installation detected.\n'
    if [[ "$(state_get running 2>/dev/null || true)" == "1" ]]; then
        printf 'The previous run did not finish. The installer will safely retry unfinished work.\n'
    fi
    printf '\nCurrent configuration:\n'
    printf '  Desktop:      %s\n' "${CURRENT_DESKTOP:-unknown}"
    printf '  Gaming:       %s\n' "$([[ "$CURRENT_GAMING" == 1 ]] && echo Yes || echo No)"
    printf '  iCloud sync:  %s\n' "$([[ "$CURRENT_ICLOUD" == 1 ]] && echo Yes || echo No)"
    printf '  Proton Pass:  %s\n\n' "$([[ "$CURRENT_PROTON" == 1 ]] && echo Yes || echo No)"

    printf 'What would you like to do?\n'
    printf '  1) Keep the current desktop and manage optional applications\n'
    printf '  2) Switch desktop environment\n'
    printf '  3) Re-run desktop configuration\n'
    printf '  4) Exit\n\n'

    while true; do
        read -r -p 'Enter 1-4: ' action
        case "$action" in
            1|2|3|4) break ;;
            *) echo "Please enter 1, 2, 3, or 4." ;;
        esac
    done

    case "$action" in
        4) exit 0 ;;
        1)
            DESKTOP_SCRIPT="${CURRENT_DESKTOP}.sh"
            [[ "$DESKTOP_SCRIPT" == "gnome.sh" || "$DESKTOP_SCRIPT" == "kde.sh" ]] || {
                echo "The saved desktop is invalid. Choose a desktop environment again."
                action=2
            }
            ;;
        2|3) ;;
    esac
else
    action=2
fi

if [[ "$action" == 2 || "$action" == 3 ]]; then
    printf '\nChoose your desktop environment:\n'
    printf '  1) GNOME\n'
    printf '  2) KDE Plasma\n\n'
    while true; do
        read -r -p 'Enter 1 or 2: ' choice
        case "$choice" in
            1) DESKTOP_SCRIPT="gnome.sh"; break ;;
            2) DESKTOP_SCRIPT="kde.sh"; break ;;
            *) echo "Please enter 1 or 2." ;;
        esac
    done
fi

NEW_DESKTOP="${DESKTOP_SCRIPT%.sh}"

if [[ -n "$CURRENT_DESKTOP" && "$CURRENT_DESKTOP" != "$NEW_DESKTOP" ]]; then
    echo
    echo "You are switching from $CURRENT_DESKTOP to $NEW_DESKTOP."
    echo "Only packages recorded as installed by Fedora Script will be offered for removal."
    if ! ask_yes_no "Continue with the desktop switch?" "no"; then
        exit 0
    fi
fi

printf '\nOptional applications\n'
printf '%s\n' '--------------------'

if [[ "$CURRENT_GAMING" == 1 ]]; then
    if ask_yes_no "Keep gaming applications (Steam, Prism Launcher, Heroic)?" "yes"; then
        INSTALL_GAMING=1
    else
        INSTALL_GAMING=0
        REMOVE_GAMING=1
    fi
else
    if ask_yes_no "Install gaming applications (Steam, Prism Launcher, Heroic)?" "no"; then
        INSTALL_GAMING=1
    else
        INSTALL_GAMING=0
    fi
fi

if [[ "$CURRENT_ICLOUD" == 1 ]]; then
    if ask_yes_no "Keep iCloud sync?" "yes"; then
        INSTALL_ICLOUD=1
    else
        INSTALL_ICLOUD=0
        REMOVE_ICLOUD=1
    fi
else
    if ask_yes_no "Set up iCloud sync?" "no"; then
        INSTALL_ICLOUD=1
    else
        INSTALL_ICLOUD=0
    fi
fi

if [[ "$CURRENT_PROTON" == 1 ]]; then
    if ask_yes_no "Keep Proton Pass?" "yes"; then
        INSTALL_PROTON_PASS=1
    else
        INSTALL_PROTON_PASS=0
        REMOVE_PROTON_PASS=1
    fi
else
    if ask_yes_no "Install Proton Pass as your password manager?" "no"; then
        INSTALL_PROTON_PASS=1
    else
        INSTALL_PROTON_PASS=0
    fi
fi

printf '\nRequesting administrator access...\n'
sudo -v
state_mark_running

while true; do
    sudo -n -v >/dev/null 2>&1 || break
    sleep 60
done &
SUDO_KEEPALIVE_PID=$!

if [[ -n "$CURRENT_DESKTOP" && "$CURRENT_DESKTOP" != "$NEW_DESKTOP" ]]; then
    remove_owned_packages "desktop-$CURRENT_DESKTOP"
fi

printf '\nDownloading %s...\n' "$DESKTOP_SCRIPT"
download "$BASE_URL/common.sh" "$WORK_DIR/common.sh"
download "$BASE_URL/$DESKTOP_SCRIPT" "$WORK_DIR/$DESKTOP_SCRIPT"
download "$BASE_URL/state.sh" "$WORK_DIR/state.sh"
download "$BASE_URL/bg/saturn-rings.jpg" "$WORK_DIR/bg-saturn-rings.jpg"
mkdir -p "$WORK_DIR/bg"
mv "$WORK_DIR/bg-saturn-rings.jpg" "$WORK_DIR/bg/saturn-rings.jpg"
chmod +x "$WORK_DIR/$DESKTOP_SCRIPT"

export INSTALL_GAMING INSTALL_ICLOUD INSTALL_PROTON_PASS
export REMOVE_GAMING REMOVE_ICLOUD REMOVE_PROTON_PASS
exec bash "$WORK_DIR/$DESKTOP_SCRIPT"
