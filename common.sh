#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CURSOR_DIR="$HOME/.local/share/icons/McMojave-cursors"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

require_user() {
    [[ $EUID -ne 0 ]] || { echo "Run this as your normal user, not root."; exit 1; }
    command -v sudo >/dev/null 2>&1 || { echo "sudo is required."; exit 1; }
}

ask_yes_no() {
    local prompt="$1" answer
    while true; do
        read -r -p "$prompt [y/N] " answer
        case "${answer,,}" in
            y|yes) return 0 ;;
            n|no|"") return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

install_apps() {
    log "Updating Fedora"
    sudo dnf upgrade --refresh -y

    log "Installing common packages"
    sudo dnf install -y \
        vim wget git konsole neovim lazygit ripgrep fd-find curl gcc \
        tree-sitter-cli make unzip tar gzip flatpak btop vlc libreoffice \
        blender obs-studio

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

    log "Enabling Flathub"
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    log "Installing default Flatpak applications"
    flatpak install -y flathub \
        com.spotify.Client \
        com.discordapp.Discord \
        md.obsidian.Obsidian \
        org.localsend.localsend_app \
        io.github.flattool.Warehouse \
        org.gimp.GIMP

    install_photogimp

    log "Installing Brave Browser"
    if ! command -v brave-browser >/dev/null 2>&1; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo || true
        sudo dnf install -y brave-browser
    fi

    if command -v brave-browser >/dev/null 2>&1; then
        xdg-settings set default-web-browser brave-browser.desktop || true
    fi

    install_davinci_resolve
}

install_photogimp() {
    log "Setting up PhotoGIMP"
    timeout 15s flatpak run org.gimp.GIMP >/dev/null 2>&1 || true
    pkill -x gimp-3.0 >/dev/null 2>&1 || true
    pkill -x gimp >/dev/null 2>&1 || true

    local zip_file="$HOME/Downloads/PhotoGIMP-linux.zip"
    mkdir -p "$HOME/Downloads"
    curl -fL "https://github.com/Diolinux/PhotoGIMP/releases/latest/download/PhotoGIMP-linux.zip" -o "$zip_file"
    unzip -o "$zip_file" -d "$HOME"
    rm -f "$zip_file"
}

install_davinci_resolve() {
    log "Installing DaVinci Resolve"
    local installer
    installer="$(find "$HOME/Downloads" -maxdepth 1 -type f -iname 'DaVinci_Resolve*_Linux.run' -print -quit 2>/dev/null || true)"

    if [[ -n "$installer" ]]; then
        sudo dnf install -y libxcrypt-compat libcurl mesa-libGLU fuse fuse-libs
        chmod +x "$installer"
        sudo SKIP_PACKAGE_CHECK=1 "$installer" -i
        if [[ -d /opt/resolve/libs ]]; then
            sudo mkdir -p /opt/resolve/libs/disabled-libraries
            sudo bash -c 'shopt -s nullglob; mv /opt/resolve/libs/libglib* /opt/resolve/libs/libgio* /opt/resolve/libs/libgmodule* /opt/resolve/libs/libgobject* /opt/resolve/libs/disabled-libraries/ 2>/dev/null || true'
        fi
        return
    fi

    echo "DaVinci Resolve was not installed automatically."
    echo "Download the Linux installer from Blackmagic Design and place the .run file in ~/Downloads."
    echo "Then run this script again."
}

install_gaming_apps() {
    log "Installing gaming applications"
    sudo dnf install -y steam
    sudo dnf -y copr enable g3tchoo/prismlauncher
    sudo dnf install -y prismlauncher
    flatpak install -y flathub com.heroicgameslauncher.hgl
}

ask_gaming() {
    if ask_yes_no "Install gaming applications (Steam, Prism Launcher, Heroic)?"; then
        install_gaming_apps
    fi
}

install_icloud_sync() {
    printf '\nWARNING: iCloud sync uses Snap. This will install and configure Snap on Fedora.\n'
    if ! ask_yes_no "Continue with Snap and iCloud sync?"; then return; fi
    log "Setting up Snap"
    sudo dnf install -y snapd
    sudo ln -sf /var/lib/snapd/snap /snap
    sudo systemctl enable --now snapd.socket || true
    log "Installing iCloud for Linux"
    sudo snap install icloud-for-linux
}

ask_icloud_sync() {
    if ask_yes_no "Set up iCloud sync?"; then install_icloud_sync; fi
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
    if ask_yes_no "Install Proton Pass as your password manager?"; then install_proton_pass; fi
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
    find "$REPO_DIR/bg" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 |
    while IFS= read -r -d '' image; do cp -f "$image" "$WALLPAPER_DIR/"; done
}

set_cursor_x11() {
    command -v xcursorctl >/dev/null 2>&1 && xcursorctl McMojave-cursors || true
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nInherits=McMojave-cursors\n' > "$HOME/.icons/default/index.theme"
}
