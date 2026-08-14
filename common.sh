#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CURSOR_DIR="$HOME/.local/share/icons/McMojave-cursors"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

require_user() {
    [[ $EUID -ne 0 ]] || { echo "Run this as your normal user, not root."; exit 1; }
    command -v sudo >/dev/null 2>&1 || { echo "sudo is required."; exit 1; }
}

install_apps() {
    log "Updating Fedora"
    sudo dnf upgrade --refresh -y

    log "Installing default Fedora applications"
    sudo dnf install -y \
        vim wget git konsole neovim lazygit ripgrep fd-find curl gcc \
        tree-sitter-cli make unzip tar gzip flatpak btop vlc libreoffice \
        blender obs-studio xdg-utils dnf-plugins-core

    log "Enabling Flathub"
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    log "Installing Ghostty"
    if ! command -v ghostty >/dev/null 2>&1; then
        sudo dnf -y copr enable scottames/ghostty
        sudo dnf install -y ghostty
    fi

    log "Installing Zed"
    if ! command -v zed >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/zed" ]]; then
        curl -f https://zed.dev/install.sh | sh
    fi

    log "Installing fetch"
    if ! command -v fetch >/dev/null 2>&1; then
        sudo dnf -y copr enable realorangekun/fetch
        sudo dnf install -y fetch
    fi

    log "Installing LazyVim"
    if [[ ! -e "$HOME/.config/nvim" ]]; then
        git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
        rm -rf "$HOME/.config/nvim/.git"
    else
        echo "Neovim config already exists; leaving it untouched."
    fi

    log "Installing default Flatpak applications"
    flatpak install -y flathub \
        com.spotify.Client \
        com.discordapp.Discord \
        md.obsidian.Obsidian \
        org.localsend.localsend_app \
        io.github.flattool.Warehouse \
        org.gimp.GIMP

    log "Installing Brave Browser"
    if ! command -v brave-browser >/dev/null 2>&1; then
        sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
        sudo dnf install -y brave-browser
    fi
    xdg-settings set default-web-browser brave-browser.desktop || true

    install_photogimp
    install_davinci_resolve
}

install_photogimp() {
    log "Setting up PhotoGIMP"
    mkdir -p "$HOME/Downloads"

    timeout 15s flatpak run org.gimp.GIMP >/dev/null 2>&1 || true
    sleep 2
    pkill -x gimp-3.0 >/dev/null 2>&1 || true
    pkill -x gimp >/dev/null 2>&1 || true

    local zip_file="$HOME/Downloads/PhotoGIMP-linux.zip"
    curl -fL "https://github.com/Diolinux/PhotoGIMP/releases/latest/download/PhotoGIMP-linux.zip" -o "$zip_file"
    unzip -o "$zip_file" -d "$HOME"
    rm -f "$zip_file"
}

install_davinci_resolve() {
    log "Checking for DaVinci Resolve"
    local installer
    installer="$(find "$HOME/Downloads" -maxdepth 1 -type f -iname 'DaVinci_Resolve*_Linux.run' -print -quit 2>/dev/null || true)"

    if [[ -n "$installer" ]]; then
        sudo dnf install -y libxcrypt-compat libcurl mesa-libGLU fuse fuse-libs
        chmod +x "$installer"
        sudo SKIP_PACKAGE_CHECK=1 "$installer" -i
        return
    fi

    echo "DaVinci Resolve needs its installer downloaded from Blackmagic Design."
    echo "If you want it installed by this script, put the DaVinci_Resolve*_Linux.run file in ~/Downloads and run setup.sh again."
}

install_gaming_apps() {
    log "Installing gaming applications"
    flatpak install -y flathub com.valvesoftware.Steam
    sudo dnf -y copr enable g3tchoo/prismlauncher
    sudo dnf install -y prismlauncher
    flatpak install -y flathub com.heroicgameslauncher.hgl
}

ask_gaming() {
    if [[ "${INSTALL_GAMING:-0}" == "1" ]]; then
        install_gaming_apps
    fi
}

install_icloud_sync() {
    log "Setting up Snap and iCloud sync"
    sudo dnf install -y snapd
    sudo systemctl enable --now snapd.socket
    if [[ ! -e /snap ]]; then
        sudo ln -s /var/lib/snapd/snap /snap
    fi

    log "Installing iCloud for Linux"
    sudo snap install icloud-for-linux
}

ask_icloud_sync() {
    if [[ "${INSTALL_ICLOUD:-0}" == "1" ]]; then
        echo "WARNING: iCloud sync uses Snap. This will install and configure Snap on Fedora."
        install_icloud_sync
    fi
}

install_proton_pass() {
    log "Installing Proton Pass"
    local rpm_url="https://proton.me/download/pass/linux/proton-pass-1.38.1-1.x86_64.rpm"
    local rpm_file="$HOME/Downloads/proton-pass.rpm"
    mkdir -p "$HOME/Downloads"
    curl -fL "$rpm_url" -o "$rpm_file"
    sudo dnf install -y "$rpm_file"
    rm -f "$rpm_file"
}

ask_proton_pass() {
    if [[ "${INSTALL_PROTON_PASS:-0}" == "1" ]]; then
        install_proton_pass
    fi
}

install_cursor() {
    log "Installing McMojave cursor theme"
    rm -rf "$HOME/.cache/McMojave-cursors"
    git clone --depth 1 https://github.com/vinceliuice/McMojave-cursors "$HOME/.cache/McMojave-cursors"
    mkdir -p "$HOME/.local/share/icons"
    rm -rf "$CURSOR_DIR"
    cp -a "$HOME/.cache/McMojave-cursors/dist" "$CURSOR_DIR"
}

install_wallpapers() {
    log "Installing wallpapers"
    mkdir -p "$WALLPAPER_DIR"
    if [[ -d "$SCRIPT_DIR/bg" ]]; then
        find "$SCRIPT_DIR/bg" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 |
        while IFS= read -r -d '' image; do
            cp -f "$image" "$WALLPAPER_DIR/"
        done
    fi
}

set_cursor_x11() {
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nInherits=McMojave-cursors\n' > "$HOME/.icons/default/index.theme"
}
