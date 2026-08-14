# Fedora Script

A simple Fedora desktop setup script designed to run directly from a fresh Fedora TTY without cloning the repository first.

## Install

Run the one-line installer as your normal user:

```bash
curl -fsSL https://callen.page/scripts/fd.sh | bash
```

The script first asks for the desktop environment and optional components. It then asks for the `sudo` password once and runs the remaining installation automatically.

Choose **GNOME** or **KDE Plasma** when asked. `setup.sh` downloads the selected desktop script, the shared functions, and the wallpaper into a temporary directory, then runs the selected script.

The script installs the apps, LazyVim, McMojave cursors, dark mode, and the wallpaper. Optional components are gaming applications, iCloud sync, and Proton Pass.

Run it as your normal user. `sudo` is required.
