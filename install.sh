#!/usr/bin/env bash
# Install (or remove) the Claude Stats Widget for the current user.
set -euo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
NAME="claude-stats-widget"
REF="${CSW_REF:-main}"
RAW_URL="https://raw.githubusercontent.com/Bobikobi/$NAME/$REF/$NAME"

# Next to this script when the repo was cloned; downloaded when the script is
# being piped straight into bash, where there is no script directory and no
# sibling file. Nothing else is needed: no git, no editor, no build step.
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$NAME"
fi
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
    SRC="$(mktemp -t "$NAME.XXXXXX")"
    trap 'rm -f "$SRC"' EXIT
    echo "Fetching the widget from $REF ..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$RAW_URL" -o "$SRC"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$SRC" "$RAW_URL"
    else
        echo "Need curl or wget to download the widget." >&2
        exit 1
    fi
fi

# Where the desktop actually is. It is localised - a Hebrew or French desktop
# is not called "Desktop" - so ask the XDG user-dirs configuration first and
# only fall back to the English name. xdg-user-dir answers $HOME when nothing
# is configured, which is not a desktop and must not be written to.
desktop_dir() {
    local dir=""
    if command -v xdg-user-dir >/dev/null 2>&1; then
        dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
    fi
    if [ -z "$dir" ] || [ "$dir" = "$HOME" ]; then
        local dirs_file="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
        if [ -r "$dirs_file" ]; then
            dir="$(. "$dirs_file" >/dev/null 2>&1; echo "${XDG_DESKTOP_DIR:-}")"
        fi
    fi
    if [ -z "$dir" ] || [ "$dir" = "$HOME" ]; then
        dir="$HOME/Desktop"
    fi
    echo "$dir"
}

DESKTOP_DIR="$(desktop_dir)"

uninstall() {
    rm -f "$BIN_DIR/$NAME" "$APP_DIR/$NAME.desktop" \
          "$AUTOSTART_DIR/$NAME.desktop" "$ICON_DIR/claude-clawd.png" \
          "$DESKTOP_DIR/$NAME.desktop" "$HOME/Desktop/$NAME.desktop"
    echo "Removed. Your settings in ~/.config/$NAME.json were left alone."
    exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

NO_DESKTOP_SHORTCUT=0
[ "${1:-}" = "--no-desktop-shortcut" ] && NO_DESKTOP_SHORTCUT=1

command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
python3 -c 'import gi; gi.require_version("Gtk","3.0"); from gi.repository import Gtk' 2>/dev/null || {
    echo "GTK 3 bindings are missing. Install python3-gi (Debian/Ubuntu:" >&2
    echo "  sudo apt install python3-gi gir1.2-gtk-3.0)" >&2
    exit 1
}

mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR"
install -m 755 "$SRC" "$BIN_DIR/$NAME"

# draw the Clawd icon once, so the launcher and notifications have it
"$BIN_DIR/$NAME" --write-icon >/dev/null 2>&1 || true

cat > "$APP_DIR/$NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Claude Stats Widget
Comment=Claude Code usage at a glance
Exec=$BIN_DIR/$NAME
Icon=$ICON_DIR/claude-clawd.png
Terminal=false
Categories=Utility;
StartupNotify=false
EOF

command -v update-desktop-database >/dev/null && \
    update-desktop-database "$APP_DIR" 2>/dev/null || true

if [ "$NO_DESKTOP_SHORTCUT" -eq 0 ]; then
    if [ -d "$DESKTOP_DIR" ]; then
        cp "$APP_DIR/$NAME.desktop" "$DESKTOP_DIR/$NAME.desktop"
        # GNOME and Cinnamon refuse to run a launcher they were not told to
        # trust, and show the raw file name until both of these are set.
        chmod +x "$DESKTOP_DIR/$NAME.desktop"
        command -v gio >/dev/null 2>&1 && \
            gio set "$DESKTOP_DIR/$NAME.desktop" metadata::trusted true \
                2>/dev/null || true
        echo "Desktop shortcut created in $DESKTOP_DIR."
    else
        echo "Note: no desktop folder at $DESKTOP_DIR, skipped that shortcut."
    fi
fi

# Piped into bash, stdin is the script itself: a prompt here would either eat
# the rest of the script or hit EOF. Ask only when there is someone to ask.
reply=""
asked=0
if [ -t 0 ]; then
    read -r -p "Start the widget automatically at login? [Y/n] " reply || true
    asked=1
elif [ -r /dev/tty ]; then
    read -r -p "Start the widget automatically at login? [Y/n] " reply < /dev/tty || true
    asked=1
fi

if [ "$asked" -eq 1 ] && [[ ! "${reply:-y}" =~ ^[Nn] ]]; then
    mkdir -p "$AUTOSTART_DIR"
    cp "$APP_DIR/$NAME.desktop" "$AUTOSTART_DIR/$NAME.desktop"
    printf 'X-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=8\n' \
        >> "$AUTOSTART_DIR/$NAME.desktop"
    echo "Autostart enabled."
elif [ "$asked" -eq 0 ]; then
    echo "Autostart not set up. To enable it later, re-run this from a terminal."
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "Note: $BIN_DIR is not on your PATH." ;;
esac

echo "Installed. Run '$NAME', or launch it from your applications menu or desktop."

# leave the user looking at a running widget, not at instructions
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] && [ "${CSW_NO_LAUNCH:-0}" != "1" ]; then
    pkill -f "$BIN_DIR/$NAME" 2>/dev/null || true
    nohup "$BIN_DIR/$NAME" >/dev/null 2>&1 &
    disown 2>/dev/null || true
    echo "Started."
fi
