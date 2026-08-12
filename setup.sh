#!/usr/bin/env bash
set -euo pipefail

# Fedora KDE Plasma workstation bootstrap.
# Run from a clone of https://github.com/callenflynn/fedora-script
# so the ./bg directory is available.

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

log() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$1"
}

if [[ $EUID -eq 0 ]]; then
    echo "Run this script as your normal user, not as root."
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required."
    exit 1
fi

if [[ ! -d "$REPO_DIR/bg" ]]; then
    echo "Could not find $REPO_DIR/bg. Run this from the cloned repository."
    exit 1
fi

log "Updating Fedora"
sudo dnf upgrade --refresh -y

log "Installing base tools"
sudo dnf install -y \
    vim \
    wget \
    git \
    konsole \
    neovim \
    lazygit \
    ripgrep \
    fd-find \
    curl \
    gcc \
    tree-sitter-cli \
    make \
    unzip \
    tar \
    gzip

log "Installing Ghostty"
if ! command -v ghostty >/dev/null 2>&1; then
    # Fedora's Ghostty package is currently provided through this COPR.
    sudo dnf -y copr enable scottames/ghostty
    sudo dnf install -y ghostty
fi

log "Installing Zed"
if ! command -v zed >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/zed" ]]; then
    # Official Zed Linux installer.
    curl -f https://zed.dev/install.sh | sh
fi

log "Installing fetch"
if ! command -v fetch >/dev/null 2>&1; then
    # fetch's upstream README documents a Fedora COPR package.
    sudo dnf -y copr enable realorangekun/fetch
    sudo dnf install -y fetch
fi

log "Installing LazyVim"
NVIM_CONFIG="$HOME/.config/nvim"
if [[ ! -e "$NVIM_CONFIG" ]]; then
    git clone https://github.com/LazyVim/starter "$NVIM_CONFIG"
    rm -rf "$NVIM_CONFIG/.git"
else
    echo "Neovim config already exists at $NVIM_CONFIG; leaving it untouched."
    echo "If you want a fresh LazyVim config, move/remove that directory and rerun."
fi

log "Installing wallpapers"
mkdir -p "$WALLPAPER_DIR"
find "$REPO_DIR/bg" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 |
while IFS= read -r -d '' image; do
    cp -f "$image" "$WALLPAPER_DIR/"
done

# Use the first image alphabetically as the initial KDE wallpaper.
FIRST_WALLPAPER="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort | head -n 1)"
if [[ -n "$FIRST_WALLPAPER" ]] && command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$WALLPAPER_DIR/$FIRST_WALLPAPER" || true
fi

log "Enabling KDE Plasma dark mode"
if command -v kwriteconfig6 >/dev/null 2>&1; then
    # Breeze Dark is KDE's built-in dark color scheme.
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
    kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
    kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
    kwriteconfig6 --file kdeglobals --group General --key widgetStyle Breeze

    # GTK applications follow the KDE dark preference where supported.
    kwriteconfig6 --file kdeglobals --group KDE --key ShowDeleteCommand true

    # Ask KDE components to reload their configuration when possible.
    command -v kquitapp6 >/dev/null 2>&1 && kquitapp6 plasmashell 2>/dev/null || true
    command -v plasmashell >/dev/null 2>&1 && (nohup plasmashell >/dev/null 2>&1 & disown) || true
else
    echo "kwriteconfig6 was not found; skipping KDE theme configuration."
fi

log "Refreshing application/menu cache"
command -v kbuildsycoca6 >/dev/null 2>&1 && kbuildsycoca6 >/dev/null 2>&1 || true

log "Done"
echo "Installed: vim, wget, git, Konsole, Neovim, LazyVim, lazygit, ripgrep, fd, curl, gcc, tree-sitter, Ghostty, Zed, and fetch."
echo "Wallpapers copied to: $WALLPAPER_DIR"
echo "KDE Plasma dark mode requested."
echo
 echo "You may want to log out and back in once so every KDE component picks up the new theme."
