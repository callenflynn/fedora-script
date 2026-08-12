# Fedora Script

A simple Fedora desktop setup script designed to run directly from a fresh Fedora TTY without cloning the repository first.

## Install

Simply run fd.sh with bash:

```bash
curl -fsSL https://callen.page/scripts/fd.sh | bash
```

Choose **GNOME** or **KDE Plasma** when asked. `setup.sh` downloads the selected desktop script, the shared functions, and the wallpaper into a temporary directory, then runs the selected script.

The script installs the apps, LazyVim, McMojave cursors, dark mode, and the wallpaper. It can also optionally install gaming apps, iCloud sync, and Proton Pass.

Run it as your normal user. `sudo` is required.
