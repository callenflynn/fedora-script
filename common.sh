#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CURSOR_DIR="$HOME/.local/share/icons/McMojave-cursors"
GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_CONFIG="$GHOSTTY_CONFIG_DIR/config.ghostty"
BASH_CONFIG_DIR="$HOME/.config/fedora-script/bash"
BASH_CONFIG="$BASH_CONFIG_DIR/bashrc"
BASH_MARKER="# Fedora Script managed Bash configuration"
PIPES_BIN="$HOME/.local/bin/pipes.sh"

source "$SCRIPT_DIR/state.sh"

log() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }

require_user() {
    [[ $EUID -ne 0 ]] || { echo "Run this as your normal user, not root."; exit 1; }
    command -v sudo >/dev/null 2>&1 || { echo "sudo is required."; exit 1; }
}

ask_reboot() {
    local answer
    printf '\nSetup is complete. A reboot is recommended to finish applying system changes.\n'
    while true; do
        read -r -p 'Reboot now? [y/N] ' answer < /dev/tty
        case "${answer,,}" in
            y|yes) sudo systemctl reboot; return 0 ;;
            ""|n|no) return 0 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

track_flatpak_install() {
    local owner="$1"
    shift
    local app
    for app in "$@"; do
        if ! flatpak info "$app" >/dev/null 2>&1; then
            flatpak install -y flathub "$app"
            printf '%s\n' "$app" >> "$(state_file_for "flatpak-$owner")"
        else
            echo "$app is already installed; leaving it untouched."
        fi
    done
    sort -u "$(state_file_for "flatpak-$owner")" -o "$(state_file_for "flatpak-$owner")" 2>/dev/null || true
}

enable_repositories() {
    log "Enabling additional Fedora repositories"
    local fedora_version
    fedora_version="$(rpm -E %fedora)"

    if ! rpm -q rpmfusion-free-release >/dev/null 2>&1; then
        track_dnf_install repositories "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_version}.noarch.rpm"
    else
        echo "RPM Fusion Free is already enabled."
    fi

    if ! rpm -q rpmfusion-nonfree-release >/dev/null 2>&1; then
        track_dnf_install repositories "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora_version}.noarch.rpm"
    else
        echo "RPM Fusion Nonfree is already enabled."
    fi

    if [[ ! -f /etc/yum.repos.d/docker-ce.repo ]]; then
        sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    else
        echo "Docker repository is already enabled."
    fi
}

install_multimedia_codecs() {
    log "Installing multimedia codecs"
    if rpm -q ffmpeg-free >/dev/null 2>&1; then
        sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing
    elif ! rpm -q ffmpeg >/dev/null 2>&1; then
        sudo dnf install -y ffmpeg --allowerasing
    else
        echo "Full FFmpeg is already installed."
    fi

    sudo dnf install -y --setopt=install_weak_deps=False \
        gstreamer1-plugins-good \
        gstreamer1-plugins-bad-free \
        gstreamer1-plugins-bad-free-extras \
        gstreamer1-plugins-bad-freeworld \
        gstreamer1-plugins-ugly \
        gstreamer1-plugin-openh264 \
        gstreamer1-libav \
        lame-libs
    sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1 || true
}

install_docker() {
    log "Installing Docker"
    track_dnf_install docker docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker

    if getent group docker >/dev/null 2>&1 && ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        sudo usermod -aG docker "$USER"
        echo "Added $USER to the docker group. Log out and back in before using Docker without sudo."
    fi
}

install_shell_tools() {
    log "Installing Bash and CLI tools"
    track_dnf_install shell-tools \
        bash git gh openssh-clients starship zoxide fzf ripgrep fd-find bat eza \
        jq tmux btop tree wget curl unzip tar gzip lazygit cava cmatrix

    mkdir -p "$BASH_CONFIG_DIR"
    if [[ ! -f "$BASH_CONFIG" ]]; then
        cat > "$BASH_CONFIG" <<'EOF'
# Fedora Script managed Bash configuration

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
EOF
    fi

    if [[ -f "$HOME/.bashrc" ]] && ! grep -Fqx "$BASH_MARKER" "$HOME/.bashrc"; then
        printf '\n%s\nsource "%s"\n' "$BASH_MARKER" "$BASH_CONFIG" >> "$HOME/.bashrc"
    fi
}

install_pipes_sh() {
    log "Installing pipes.sh"
    mkdir -p "$(dirname "$PIPES_BIN")"
    if [[ -x "$PIPES_BIN" ]]; then
        echo "pipes.sh is already installed; leaving it untouched."
        return
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    if git clone --depth 1 https://github.com/pipeseroni/pipes.sh "$tmp_dir/pipes.sh"; then
        install -m 0755 "$tmp_dir/pipes.sh/pipes.sh" "$PIPES_BIN"
    else
        rm -rf "$tmp_dir"
        echo "Failed to download pipes.sh." >&2
        return 1
    fi
    rm -rf "$tmp_dir"
}

install_fonts() {
    log "Installing fonts"
    track_dnf_install fonts jetbrains-mono-fonts fira-code-fonts cascadia-mono-nf-fonts
}

configure_ghostty() {
    log "Configuring Ghostty"
    mkdir -p "$GHOSTTY_CONFIG_DIR"
    if [[ -e "$GHOSTTY_CONFIG" || -e "$GHOSTTY_CONFIG_DIR/config" ]]; then
        echo "Existing Ghostty configuration found; leaving it untouched."
        return
    fi

    cat > "$GHOSTTY_CONFIG" <<'EOF'
# Fedora Script default terminal configuration
font-family = "JetBrains Mono"
font-family = "Fira Code"
font-family = "Cascadia Mono NF"
EOF
}

install_apps() {
    enable_repositories
    log "Updating Fedora"
    sudo dnf upgrade --refresh -y

    log "Installing default Fedora applications"
    track_dnf_install base-apps \
        vim wget git neovim ripgrep fd-find curl gcc \
        tree-sitter-cli make unzip tar gzip flatpak btop vlc libreoffice \
        blender obs-studio xdg-utils dnf-plugins-core

    install_multimedia_codecs
    install_shell_tools
    install_pipes_sh
    install_fonts
    install_docker

    log "Enabling Flathub"
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    log "Installing Ghostty"
    if ! command -v ghostty >/dev/null 2>&1; then
        sudo dnf -y copr enable scottames/ghostty
        track_dnf_install ghostty ghostty
    else
        echo "Ghostty is already installed; leaving it untouched."
    fi
    configure_ghostty

    log "Installing Zed"
    if ! command -v zed >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/zed" ]]; then
        curl -f https://zed.dev/install.sh | sh
    else
        echo "Zed is already installed; leaving it untouched."
    fi

    log "Installing fetch"
    if ! command -v fetch >/dev/null 2>&1; then
        sudo dnf -y copr enable realorangekun/fetch
        track_dnf_install fetch fetch
    else
        echo "fetch is already installed; leaving it untouched."
    fi

    log "Installing LazyVim"
    if [[ ! -e "$HOME/.config/nvim" ]]; then
        git clone https://github.com/LazyVim/starter "$HOME/.config/nvim"
        rm -rf "$HOME/.config/nvim/.git"
    else
        echo "Neovim config already exists; leaving it untouched."
    fi

    log "Installing default Flatpak applications"
    track_flatpak_install base-flatpaks \
        com.spotify.Client \
        com.discordapp.Discord \
        md.obsidian.Obsidian \
        org.localsend.localsend_app \
        io.github.flattool.Warehouse \
        org.gimp.GIMP

    log "Installing Brave Browser"
    if ! command -v brave-browser >/dev/null 2>&1; then
        sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
        track_dnf_install brave brave-browser
    else
        echo "Brave is already installed; leaving it untouched."
    fi
    xdg-settings set default-web-browser brave-browser.desktop || true

    install_photogimp
    install_davinci_resolve
}

install_photogimp() {
    log "Setting up PhotoGIMP"
    mkdir -p "$HOME/Downloads"
    if [[ -d "$HOME/.config/GIMP" || -d "$HOME/.var/app/org.gimp.GIMP/config/GIMP" ]]; then
        echo "GIMP configuration already exists; leaving it untouched."
        return
    fi

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
        track_dnf_install davinci-dependencies libxcrypt-compat libcurl mesa-libGLU fuse fuse-libs
        chmod +x "$installer"
        sudo SKIP_PACKAGE_CHECK=1 "$installer" -i
        return
    fi

    echo "DaVinci Resolve needs its installer downloaded from Blackmagic Design."
    echo "If you want it installed by this script, put the DaVinci_Resolve*_Linux.run file in ~/Downloads and run setup.sh again."
}

install_gaming_apps() {
    log "Installing gaming applications"
    track_flatpak_install gaming-flatpaks com.valvesoftware.Steam com.heroicgameslauncher.hgl
    sudo dnf -y copr enable g3tchoo/prismlauncher
    track_dnf_install gaming-prismlauncher prismlauncher
    state_set gaming 1
}

remove_gaming_apps() {
    log "Removing Fedora Script gaming applications"
    remove_owned_flatpaks gaming-flatpaks
    remove_owned_packages gaming-prismlauncher
    state_set gaming 0
}

install_icloud_sync() {
    log "Setting up Snap and iCloud sync"
    track_dnf_install icloud-snap snapd
    sudo systemctl enable --now snapd.socket
    if [[ ! -e /snap ]]; then
        sudo ln -s /var/lib/snapd/snap /snap
        state_set snap_link 1
    fi

    log "Installing iCloud for Linux"
    if ! snap list icloud-for-linux >/dev/null 2>&1; then
        sudo snap install icloud-for-linux
    else
        echo "iCloud for Linux is already installed; leaving it untouched."
    fi
    state_set icloud 1
}

remove_icloud_sync() {
    log "Removing Fedora Script iCloud sync"
    if snap list icloud-for-linux >/dev/null 2>&1; then
        sudo snap remove icloud-for-linux
    fi
    if [[ "$(state_get snap_link 2>/dev/null || true)" == "1" && -L /snap ]]; then
        sudo rm -f /snap
        state_set snap_link 0
    fi
    remove_owned_packages icloud-snap
    state_set icloud 0
}

install_proton_pass() {
    log "Installing Proton Pass"
    local rpm_url="https://proton.me/download/pass/linux/proton-pass-1.38.1-1.x86_64.rpm"
    local rpm_file="$HOME/Downloads/proton-pass.rpm"
    mkdir -p "$HOME/Downloads"
    curl -fL "$rpm_url" -o "$rpm_file"
    track_dnf_install proton-pass "$rpm_file"
    rm -f "$rpm_file"
    state_set proton_pass 1
}

remove_proton_pass() {
    log "Removing Fedora Script Proton Pass"
    remove_owned_packages proton-pass
    state_set proton_pass 0
}

install_cursor() {
    log "Installing McMojave cursor theme"
    if [[ -d "$CURSOR_DIR" ]]; then
        echo "McMojave cursor theme is already installed; leaving it untouched."
        return
    fi
    git clone --depth 1 https://github.com/vinceliuice/McMojave-cursors "$HOME/.cache/McMojave-cursors"
    mkdir -p "$HOME/.local/share/icons"
    cp -a "$HOME/.cache/McMojave-cursors/dist" "$CURSOR_DIR"
}

install_wallpapers() {
    log "Installing wallpapers"
    mkdir -p "$WALLPAPER_DIR"
    if [[ -d "$SCRIPT_DIR/bg" ]]; then
        find "$SCRIPT_DIR/bg" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 |
        while IFS= read -r -d '' image; do
            cp -n "$image" "$WALLPAPER_DIR/" 2>/dev/null || true
        done
    fi
}

set_cursor_x11() {
    mkdir -p "$HOME/.icons/default"
    printf '[Icon Theme]\nInherits=McMojave-cursors\n' > "$HOME/.icons/default/index.theme"
}
