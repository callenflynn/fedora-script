# Fedora Script

A simple Fedora desktop setup script designed to run directly from a fresh Fedora TTY without cloning the repository first.

## Install

Run the installer with Bash:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/callenflynn/fedora-script/refs/heads/main/setup.sh)
```

Or, if `curl` is unavailable but `wget` is installed:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/callenflynn/fedora-script/refs/heads/main/setup.sh)
```

Choose **GNOME** or **KDE Plasma** when asked. `setup.sh` downloads the selected desktop script, the shared functions, and the wallpaper into a temporary directory, then runs the selected script.

The script installs the apps, LazyVim, McMojave cursors, dark mode, and the wallpaper. It can also optionally install gaming apps, iCloud sync, and Proton Pass.

Run it as your normal user. `sudo` is required.
