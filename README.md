# Fedora Script

A personal Fedora workstation setup script designed to run directly from a fresh Fedora TTY without cloning the repository first.

## Install

Run the one-line installer as your normal user:

```bash
curl -fsSL https://callen.page/scripts/fd.sh | bash
```

`fd.sh` is maintained separately from this repository. It launches `setup.sh` from this repository.

The installer asks all questions first. It then requests the `sudo` password and performs the remaining setup automatically.

## Desktop environments

Choose:

- GNOME
- KDE Plasma

The installer records its state in `~/.local/state/fedora-script/`. On later runs, it can keep the current desktop, re-run its configuration, or switch desktop environments.

When switching desktops, the new desktop is installed first. Fedora Script only removes packages recorded as owned by its previous desktop installation after the new desktop setup succeeds.

## Default setup

The standard setup includes:

- Bash
- Ghostty
- Starship
- zoxide
- Git and LazyGit
- GitHub CLI
- OpenSSH client
- Docker Engine, Compose and Buildx
- Neovim with LazyVim
- Zed
- Brave Browser
- Obsidian
- Spotify
- Discord
- GIMP with PhotoGIMP configuration
- LibreOffice
- VLC
- Blender
- OBS Studio
- CAVA
- cmatrix
- `pipes.sh`
- common command-line tools such as `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `jq`, `btop` and `tmux`

JetBrains Mono is the primary terminal font. Fira Code and Cascadia Mono NF are installed as fallback fonts.

## Fedora repositories and codecs

The installer enables:

- RPM Fusion Free
- RPM Fusion Nonfree
- Docker's official Fedora repository
- Brave's repository
- Flathub

It also installs the RPM Fusion multimedia codec stack and full FFmpeg support.

## Optional components

The installer can manage:

- Steam, Heroic and Prism Launcher
- iCloud sync
- Proton Pass

These components are tracked separately so they can be kept or removed on later runs.

## State and safety

Fedora Script tracks packages that it installs. Package removal uses `dnf remove --no-autoremove` so unrelated dependencies are not automatically removed.

Non-DNF components such as Zed, LazyVim, PhotoGIMP, the cursor theme and `pipes.sh` are also recorded in the installer state.

Existing user configuration is normally left untouched. The installer does not change the user's shell from Bash.

The installer asks whether to reboot after setup. Reboot is optional.

## Requirements

- Fedora Linux
- A normal user account with `sudo` access
- `curl` or `wget`
- Internet access

Do not run the installer as root.
