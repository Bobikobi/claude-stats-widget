import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import Clutter from 'gi://Clutter';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const UUID = 'claude-stats-widget@bobikobi';

export default class ClaudeStatsExtension extends Extension {
    enable() {
        this._cacheDir = GLib.build_filenamev([
            GLib.get_user_cache_dir(), 'claude-stats-widget',
        ]);
        this._stateFile = GLib.build_filenamev([
            this._cacheDir, 'panel-state.json',
        ]);
        this._commandFile = GLib.build_filenamev([
            this._cacheDir, 'panel-command',
        ]);
        this._lastIcon = '';
        this._button = new PanelMenu.Button(0.0, 'Claude Stats', false);
        this._box = new St.BoxLayout({ style: 'spacing: 8px; padding: 0 8px;' });
        this._icon = new St.Icon({
            style_class: 'system-status-icon',
            icon_size: 24,
        });
        this._box.add_child(this._icon);
        this._groups = {
            hour5: this._createGroup(),
            week: this._createGroup(),
        };
        this._button.add_child(this._box);
        this._buildMenu();
        this._button.connect('button-press-event', (_actor, event) => {
            const button = event.get_button();
            if (button === Clutter.BUTTON_PRIMARY) {
                this._openWidget();
                return Clutter.EVENT_STOP;
            }
            if (button === Clutter.BUTTON_SECONDARY) {
                this._button.menu.toggle();
                return Clutter.EVENT_STOP;
            }
            return Clutter.EVENT_PROPAGATE;
        });
        this._button.connect('enter-event', () => this._showTooltip());
        this._button.connect('leave-event', () => this._hideTooltip());
        // Left side of the panel, right after the Activities button.
        Main.panel.addToStatusArea(UUID, this._button, 1, 'left');
        this._pollId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT, 500, () => this._readState());
        this._readState();
    }

    disable() {
        if (this._pollId) {
            GLib.source_remove(this._pollId);
            this._pollId = 0;
        }
        this._hideTooltip();
        this._button?.destroy();
        this._button = null;
    }

    _createGroup() {
        const group = new St.BoxLayout({ style: 'spacing: 5px;' });
        // Text takes the panel's own colour and the track is a tint of it,
        // so the strip sits in the bar on any theme instead of on its own slab.
        const label = new St.Label({
            style: 'font-size: 10px; font-weight: bold;',
            y_align: Clutter.ActorAlign.CENTER,
        });
        const track = new St.Widget({
            style: 'height: 7px; border-radius: 4px; background-color: rgba(255, 255, 255, 0.16);',
            y_align: Clutter.ActorAlign.CENTER,
        });
        track.set_size(90, 7);
        const fill = new St.Widget({
            style: 'height: 7px; border-radius: 4px; background-color: #6fbf73;',
        });
        fill.set_size(0, 7);
        track.add_child(fill);
        const percent = new St.Label({
            style: 'font-size: 10px; font-weight: bold;',
            y_align: Clutter.ActorAlign.CENTER,
        });
        group.add_child(label);
        group.add_child(track);
        group.add_child(percent);
        this._box.add_child(group);
        return { group, label, track, fill, percent };
    }

    _buildMenu() {
        this._hourSwitch = new PopupMenu.PopupSwitchMenuItem('5-hour', true);
        this._weekSwitch = new PopupMenu.PopupSwitchMenuItem('Weekly', true);
        this._hourSwitch.connect('toggled', (_item, active) =>
            this._writeCommand({ action: 'set', key: 'tray_show_hour5', value: active }));
        this._weekSwitch.connect('toggled', (_item, active) =>
            this._writeCommand({ action: 'set', key: 'tray_show_week', value: active }));
        this._button.menu.addMenuItem(this._hourSwitch);
        this._button.menu.addMenuItem(this._weekSwitch);
        this._button.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._openItem = this._button.menu.addAction(
            'Open widget', () => this._openWidget());
        this._quitItem = this._button.menu.addAction('Quit widget', () =>
            this._writeCommand({ action: 'quit' }));
        this._button.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._hideTooltip();
        });
    }

    _readState() {
        try {
            const file = Gio.File.new_for_path(this._stateFile);
            if (!file.query_exists(null))
                return GLib.SOURCE_CONTINUE;
            const [ok, contents] = file.load_contents(null);
            if (!ok)
                return GLib.SOURCE_CONTINUE;
            const state = JSON.parse(new TextDecoder().decode(contents));
            this._applyState(state);
        } catch (error) {
            logError(error, `Unable to read Claude Stats panel state (${UUID})`);
        }
        return GLib.SOURCE_CONTINUE;
    }

    _applyState(state) {
        const iconPath = GLib.build_filenamev([this._cacheDir, state.icon || '']);
        if (state.icon && iconPath !== this._lastIcon) {
            this._icon.set_gicon(new Gio.FileIcon({
                file: Gio.File.new_for_path(iconPath),
            }));
            this._lastIcon = iconPath;
        }
        this._setGroup('hour5', state, state.show_hour5);
        this._setGroup('week', state, state.show_week);
        this._hourSwitch.setToggleState(Boolean(state.show_hour5));
        this._weekSwitch.setToggleState(Boolean(state.show_week));
        this._hourSwitch.label.text = state.hour5_menu_label || '5-hour';
        this._weekSwitch.label.text = state.week_menu_label || 'Weekly';
        this._openItem.label.text = state.open_label || 'Open widget';
        this._quitItem.label.text = state.quit_label || 'Quit widget';
        this._tooltipText = state.tooltip || '';
    }

    _setGroup(key, state, visible) {
        const group = this._groups[key];
        group.group.visible = Boolean(visible);
        if (!visible)
            return;
        const prefix = key === 'hour5' ? 'hour5' : 'week';
        const percent = Math.max(0, Math.min(100, Number(state[`${prefix}_pct`]) || 0));
        group.label.text = state[`${prefix}_label`] || prefix;
        group.percent.text = state[`${prefix}_text`] || `${Math.round(percent)}%`;
        const color = state[`${prefix}_is_quota`]
            ? (percent >= 80 ? '#e0645c' : percent >= 50 ? '#e8a34c' : '#6fbf73')
            : '#5b7bb8';
        group.fill.set_size(Math.round(90 * percent / 100), 7);
        group.fill.set_style(`height: 7px; border-radius: 4px; background-color: ${color};`);
    }

    _writeCommand(command) {
        try {
            Gio.File.new_for_path(this._commandFile).replace_contents(
                JSON.stringify(command), null, false,
                Gio.FileCreateFlags.REPLACE_DESTINATION, null);
        } catch (error) {
            logError(error, 'Unable to send a command to Claude Stats');
        }
    }

    _openWidget() {
        this._writeCommand({ action: 'open' });
        try {
            const info = Gio.File.new_for_path(this._stateFile)
                .query_info('time::modified', Gio.FileQueryInfoFlags.NONE, null);
            const ageSeconds = GLib.get_real_time() / 1000000 -
                info.get_attribute_uint64('time::modified');
            if (ageSeconds < 3)
                return;
        } catch (_error) {
            // No running widget has created its state yet; start the installed app.
        }
        const app = Gio.DesktopAppInfo.new('claude-stats-widget.desktop');
        if (app)
            app.launch([], null);
    }

    _showTooltip() {
        if (!this._tooltipText || this._tooltip)
            return;
        this._tooltip = new St.Label({
            style: 'padding: 8px 10px; border-radius: 8px; color: #f5f4ef; background-color: #262624; font-size: 10px;',
            text: this._tooltipText,
        });
        Main.uiGroup.add_child(this._tooltip);
        const [x] = this._button.get_transformed_position();
        this._tooltip.set_position(x, Main.panel.height + 4);
    }

    _hideTooltip() {
        this._tooltip?.destroy();
        this._tooltip = null;
    }
}
