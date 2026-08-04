#!/usr/bin/env bash
# Install (or remove) the Claude Stats Widget for the current user.
set -euo pipefail

BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
NAME="claude-stats-widget"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$NAME"

uninstall() {
    rm -f "$BIN_DIR/$NAME" "$APP_DIR/$NAME.desktop" \
          "$AUTOSTART_DIR/$NAME.desktop" "$ICON_DIR/claude-clawd.png" \
          "$HOME/Desktop/$NAME.desktop"
    echo "Removed. Your settings in ~/.config/$NAME.json were left alone."
    exit 0
}

[ "${1:-}" = "--uninstall" ] && uninstall

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

read -r -p "Start the widget automatically at login? [Y/n] " reply
if [[ ! "${reply:-y}" =~ ^[Nn] ]]; then
    mkdir -p "$AUTOSTART_DIR"
    cp "$APP_DIR/$NAME.desktop" "$AUTOSTART_DIR/$NAME.desktop"
    printf 'X-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=8\n' \
        >> "$AUTOSTART_DIR/$NAME.desktop"
    echo "Autostart enabled."
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "Note: $BIN_DIR is not on your PATH." ;;
esac

echo "Installed. Run '$NAME' or launch it from your applications menu."
