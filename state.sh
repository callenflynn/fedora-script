#!/usr/bin/env bash

STATE_DIR="$HOME/.local/state/fedora-script"
STATE_FILE="$STATE_DIR/state"
PACKAGE_DIR="$STATE_DIR/packages"
BACKUP_DIR="$STATE_DIR/backups"

mkdir -p "$STATE_DIR" "$PACKAGE_DIR" "$BACKUP_DIR"

state_get() {
    local key="$1"
    [[ -f "$STATE_FILE" ]] || return 1
    awk -F= -v key="$key" '$1 == key {print substr($0, index($0,"=")+1); exit}' "$STATE_FILE"
}

state_set() {
    local key="$1" value="$2" tmp
    touch "$STATE_FILE"
    tmp="$(mktemp)"
    awk -F= -v key="$key" -v value="$value" '
        BEGIN { found=0 }
        $1 == key { print key "=" value; found=1; next }
        { print }
        END { if (!found) print key "=" value }
    ' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
}

state_has_installation() {
    [[ "$(state_get version 2>/dev/null || true)" == "1" || "$(state_get running 2>/dev/null || true)" == "1" ]]
}

state_mark_running() {
    state_set running 1
}

state_mark_installed() {
    state_set version 1
    state_set running 0
    state_set last_run "$(date -Iseconds)"
}

state_file_for() {
    printf '%s/%s.packages\n' "$PACKAGE_DIR" "$1"
}

snapshot_rpm() {
    rpm -qa --qf '%{NAME}\n' | sort -u
}

track_dnf_install() {
    local owner="$1"
    shift
    local before after file
    before="$(mktemp)"
    after="$(mktemp)"
    snapshot_rpm > "$before"
    sudo dnf install -y "$@"
    snapshot_rpm > "$after"
    file="$(state_file_for "$owner")"
    comm -13 "$before" "$after" >> "$file"
    sort -u "$file" -o "$file"
    rm -f "$before" "$after"
}

remove_owned_packages() {
    local owner="$1" file pkg
    local -a installed=()
    file="$(state_file_for "$owner")"
    [[ -s "$file" ]] || return 0

    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] || continue
        if rpm -q "$pkg" >/dev/null 2>&1; then
            installed+=("$pkg")
        fi
    done < "$file"

    if ((${#installed[@]} == 0)); then
        rm -f "$file"
        return 0
    fi

    echo "Removing packages recorded as installed by Fedora Script for $owner."
    echo "DNF will not autoremove unrelated dependencies."
    sudo dnf remove -y --no-autoremove "${installed[@]}"
    rm -f "$file"
}

remove_owned_flatpaks() {
    local owner="$1" file app
    file="$(state_file_for "flatpak-$owner")"
    [[ -s "$file" ]] || return 0

    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        if flatpak info "$app" >/dev/null 2>&1; then
            flatpak uninstall -y "$app"
        fi
    done < "$file"
    rm -f "$file"
}

backup_path() {
    local source="$1"
    local name timestamp destination
    name="$(basename "$source")"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    destination="$BACKUP_DIR/${name}.${timestamp}"
    mv "$source" "$destination"
    printf '%s\n' "$destination"
}
