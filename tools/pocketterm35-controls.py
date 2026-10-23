#!/usr/bin/env python3
"""Small-screen preferences. No root, firmware writes, or guessed hardware IO."""
import json
import os
import pathlib
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

def backlights(root=pathlib.Path('/sys/class/backlight')):
    return sorted(p.name for p in root.iterdir()
                  if (p / 'max_brightness').is_file()) if root.exists() else []


def brightness(device, percent):
    if device not in backlights():
        raise ValueError('Backlight no longer available')
    if not 5 <= percent <= 100:
        raise ValueError('Brightness must be 5–100%')
    subprocess.run(['brightnessctl', '--class=backlight', '--device', device,
                    'set', f'{percent}%'], check=True, capture_output=True, text=True, timeout=10)


# No arbitrary shell commands in saved layouts; only this audited catalogue.
TILES = {
    'wifi': ('Wi-Fi', 'network-wireless-symbolic', 'Toggle Wi-Fi through NetworkManager'),
    'bluetooth': ('Bluetooth', 'bluetooth-active-symbolic', 'Toggle Bluetooth controller power'),
    'mute': ('Mute sound', 'audio-volume-muted-symbolic', 'Mute or unmute the default output'),
    'dnd': ('Do Not Disturb', 'notifications-disabled-symbolic', 'Hide notification banners in Sway'),
    'keyboard': ('Keyboard', 'input-keyboard-symbolic', 'Show or hide the software keyboard'),
    'bar': ('Status bar', 'view-more-symbolic', 'Show or hide the Sway status bar'),
    'lock': ('Lock screen', 'system-lock-screen-symbolic', 'Lock without logging out'),
    'terminal': ('Terminal', 'utilities-terminal-symbolic', 'Open a compact Foot terminal'),
    'network': ('Network setup', 'network-workgroup-symbolic', 'Open nmtui in a terminal'),
    'appearance': ('Appearance', 'preferences-desktop-theme-symbolic', 'Choose a theme and wallpaper'),
    'brightness': ('Brightness', 'display-brightness-symbolic', 'Open brightness controls and firmware help'),
    'volume': ('Volume', 'audio-volume-high-symbolic', 'Open volume controls'),
    'battery': ('Battery info', 'battery-symbolic', 'Read genuine Linux battery information'),
    'power': ('CPU profiles', 'power-profile-balanced-symbolic', 'Open CPU profile controls; sudo still required'),
}
WINDOW_SIZE = (560, 400)
DEFAULT_TILES = ['wifi', 'mute', 'dnd', 'keyboard', 'appearance', 'brightness']
SWAY_ONLY = {'dnd', 'keyboard', 'bar', 'appearance'}
BAR_MODULES = {
    'custom/launcher': 'Apps button', 'sway/workspaces': 'Workspaces', 'clock': 'Clock',
    'network': 'Network', 'pulseaudio': 'Volume', 'battery': 'Battery',
    'custom/controls': 'Controls button', 'cpu': 'CPU usage', 'memory': 'Memory usage',
    'temperature': 'Temperature', 'backlight': 'Brightness', 'bluetooth': 'Bluetooth',
}


def config_root():
    return pathlib.Path(os.environ.get('XDG_CONFIG_HOME', pathlib.Path.home() / '.config'))


def normalize_layout(data):
    if not isinstance(data, dict) or not isinstance(data.get('tiles'), list):
        return list(DEFAULT_TILES)
    # Preserve intentional empty layouts, drop obsolete/unknown/duplicate IDs.
    return list(dict.fromkeys(tile for tile in data['tiles'] if isinstance(tile, str) and tile in TILES))


def load_layout(path):
    try:
        return normalize_layout(json.loads(path.read_text()))
    except (OSError, ValueError):
        return list(DEFAULT_TILES)


def save_layout(path, tiles):
    data = normalize_layout({'tiles': tiles})
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps({'version': 1, 'tiles': data}, indent=2) + '\n')
    temp.replace(path)


def command(args, timeout=12):
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=timeout,
                            env={**os.environ, 'LC_ALL': 'C'})
    return result.stdout.strip()


def tile_state(tile):
    if tile == 'wifi':
        value = command(['nmcli', 'radio', 'wifi'], 4)
        if value not in ('enabled', 'disabled'):
            raise ValueError('NetworkManager did not report Wi-Fi state')
        return value == 'enabled'
    if tile == 'bluetooth':
        value = command(['bluetoothctl', 'show'], 4)
        if 'Powered: yes' not in value and 'Powered: no' not in value:
            raise ValueError('No Bluetooth controller found')
        return 'Powered: yes' in value
    if tile == 'mute':
        value = command(['pactl', 'get-sink-mute', '@DEFAULT_SINK@'], 4)
        if value not in ('Mute: yes', 'Mute: no'):
            raise ValueError('Audio server did not report mute state')
        return value == 'Mute: yes'
    if tile == 'dnd':
        return 'do-not-disturb' in command(['makoctl', 'mode'], 4).splitlines()
    return None


def toggle_tile(tile):
    active = tile_state(tile)
    args = {
        'wifi': ['nmcli', 'radio', 'wifi', 'off' if active else 'on'],
        'bluetooth': ['bluetoothctl', 'power', 'off' if active else 'on'],
        'mute': ['pactl', 'set-sink-mute', '@DEFAULT_SINK@', '0' if active else '1'],
        'dnd': ['makoctl', 'mode', '-r' if active else '-a', 'do-not-disturb'],
        'keyboard': ['pocketterm35-osk', 'toggle'],
        'bar': ['pocketterm35-bar', 'toggle'],
        'lock': ['pocketterm35-lock'],
    }.get(tile)
    if args is None:
        raise ValueError('Unknown quick action')
    command(args)
    return tile_state(tile)


def battery_text(root=pathlib.Path('/sys/class/power_supply')):
    result = []
    for supply in sorted(root.glob('*')):
        if (supply / 'type').is_file() and (supply / 'type').read_text().strip() == 'Battery':
            for key in ('capacity', 'status'):
                if (supply / key).is_file():
                    value = (supply / key).read_text().strip()
                    result.append(f'{key}: {value}' + ('%' if key == 'capacity' else ''))
    return '\n'.join(result) or 'No Linux battery device. RP2040-only telemetry is not supported yet.'


def main():
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gdk, Gtk, GLib, Pango
    GLib.set_prgname('pocketterm35-controls')
    GLib.set_application_name('PocketTerm35 Controls')
    sway = bool(os.environ.get('SWAYSOCK'))
    root = config_root()
    layout_file = root / 'pocketterm35/quick-layout.json'
    tiles = load_layout(layout_file)
    executor = ThreadPoolExecutor(max_workers=2)
    alive = [True]
    window = Gtk.Window(title='PocketTerm35 Controls')
    window.set_name('pt35-controls')
    window.set_default_size(*WINDOW_SIZE)
    window.set_size_request(320, 240)
    # Use the actual work area when it is smaller; never force 640px of content.
    display = Gdk.Display.get_default()
    monitor = display.get_primary_monitor() or display.get_monitor(0) if display else None
    if monitor:
        area = monitor.get_workarea()
        window.set_default_size(min(WINDOW_SIZE[0], max(320, area.width - 24)), min(WINDOW_SIZE[1], max(240, area.height - 36)))
    def close(_):
        alive[0] = False
        executor.shutdown(wait=False, cancel_futures=True)
        Gtk.main_quit()
    window.connect('destroy', close)
    provider = Gtk.CssProvider()
    palette = {'bg': '202733', 'fg': 'eceff4', 'surface': '303b4c', 'accent': '88c0d0'}
    try:
        selected = json.loads((root / 'pocketterm35/theme/selection.json').read_text())['theme']
        candidate = json.loads(pathlib.Path('/usr/share/pocketterm35/themes/palettes.json').read_text())[selected]
        import re
        if all(re.fullmatch('[0-9a-fA-F]{6}', candidate[k]) for k in palette):
            palette = {k: candidate[k] for k in palette}
    except (OSError, ValueError, KeyError, TypeError):
        pass
    css = '''
#pt35-controls { background: #BG; color: #FG; font: 10pt Sans; }
#pt35-controls label { color: #FG; }
#pt35-controls button { min-height: 30px; padding: 3px 8px; background-image: none; background-color: #SURFACE; color: #FG; border-radius: 6px; }
#pt35-controls button:disabled { opacity: 0.55; }
#pt35-controls button:hover { border-color: #ACCENT; }
#pt35-controls entry { background: #SURFACE; color: #FG; }
#pt35-controls switch:checked { background: #ACCENT; }
#pt35-controls .quick-tile { min-height: 66px; background-image: none; background-color: #SURFACE; border: 1px solid transparent; border-radius: 8px; }
#pt35-controls button:focus { border-color: #ACCENT; }
#pt35-controls .active-tile { border-color: #ACCENT; }
#pt35-controls .muted { opacity: 0.75; font-size: 9pt; }
#pt35-controls .title { font-weight: bold; font-size: 12pt; }
#pt35-controls stackswitcher button { min-height: 26px; padding: 2px 7px; }
#pt35-controls .footer { font-size: 9pt; }
'''
    for key, value in palette.items():
        css = css.replace('#' + key.upper(), '#' + value)
    provider.load_from_data(css.encode())
    Gtk.StyleContext.add_provider_for_screen(window.get_screen(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, margin=8)
    window.add(outer)

    def text(value, wrap=True, muted=False):
        label = Gtk.Label(label=value, xalign=0)
        label.set_line_wrap(wrap)
        label.set_line_wrap_mode(Pango.WrapMode.WORD_CHAR)
        label.set_max_width_chars(38)
        if muted:
            label.get_style_context().add_class('muted')
        return label

    header = Gtk.Box(spacing=8)
    title = text('PocketTerm35', False)
    title.get_style_context().add_class('title')
    header.pack_start(title, True, True, 0)
    customize = Gtk.Button(label='Customize')
    header.pack_end(customize, False, False, 0)
    outer.pack_start(header, False, False, 0)
    stack = Gtk.Stack()
    stack.set_transition_type(Gtk.StackTransitionType.NONE)
    # Don't let a hidden page's natural height enlarge the window.
    stack.set_hhomogeneous(False)
    stack.set_vhomogeneous(False)
    switcher = Gtk.StackSwitcher(stack=stack, homogeneous=True)
    outer.pack_start(switcher, False, False, 0)
    outer.pack_start(stack, True, True, 0)
    last_message = ['Hide controls without disabling hardware.']
    footer_row = Gtk.Box(spacing=4)
    footer = Gtk.Label(label='Hide controls without disabling hardware.', xalign=0)
    footer.set_ellipsize(Pango.EllipsizeMode.END)
    footer.get_style_context().add_class('footer')
    footer_row.pack_start(footer, True, True, 0)
    details = Gtk.Button(label='Details')
    footer_row.pack_end(details, False, False, 0)
    outer.pack_end(footer_row, False, False, 0)
    def show_details(_):
        dialog = Gtk.Dialog(title='Control details', transient_for=window, modal=True)
        dialog.set_default_size(420, 260)
        dialog.add_button('Close', Gtk.ResponseType.CLOSE)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        view = Gtk.TextView(editable=False, cursor_visible=False, wrap_mode=Gtk.WrapMode.WORD_CHAR)
        view.set_left_margin(10)
        view.set_right_margin(10)
        view.get_buffer().set_text(last_message[0][:8000])
        scroll.add(view)
        dialog.get_content_area().pack_start(scroll, True, True, 0)
        dialog.show_all()
        dialog.run()
        dialog.destroy()
    details.connect('clicked', show_details)
    footer.set_tooltip_text('Messages and errors appear here. Hover to read the complete message.')

    def notify(value):
        last_message[0] = str(value)
        footer.set_text(str(value).replace('\n', ' ')[:220])
        footer.set_tooltip_text(str(value))

    def work(task, done=None, widget=None):
        if widget:
            widget.set_sensitive(False)
        def complete(future):
            if not alive[0]:
                return False
            if widget:
                widget.set_sensitive(True)
            try:
                result = future.result()
                if done:
                    done(result)
            except Exception as error:
                notify((getattr(error, 'stderr', '') or str(error)).strip() or 'Action failed')
            return False
        future = executor.submit(task)
        future.add_done_callback(lambda future: GLib.idle_add(complete, future))

    def page(name, title=None):
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_min_content_width(0)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8, margin=4)
        scroll.add(box)
        if title:
            stack.add_titled(scroll, name, title)
        else:
            stack.add_named(scroll, name)
        return box

    quick = page('quick', 'Quick')
    look = page('look', 'Look')
    bar = page('bar', 'Bar')
    device = page('device', 'Device')
    editor = page('customize')
    customize.connect('clicked', lambda _: stack.set_visible_child_name('customize'))

    def button(parent, title, callback):
        widget = Gtk.Button(label=title)
        widget.connect('clicked', callback)
        parent.pack_start(widget, False, False, 0)
        return widget

    def launch(args):
        try:
            subprocess.Popen(args, start_new_session=True)
            notify('Opened in a separate window.')
        except OSError as error:
            notify(str(error))

    def action(tile, widget):
        if tile in ('appearance', 'brightness', 'volume', 'power'):
            stack.set_visible_child_name('look' if tile == 'appearance' else 'device')
        elif tile in ('terminal', 'network'):
            launch(['foot'] if tile == 'terminal' else ['foot', '-e', 'nmtui'])
        elif tile == 'battery':
            work(battery_text, notify, widget)
        else:
            def completed(active):
                style = widget.get_style_context()
                (style.add_class if active else style.remove_class)('active-tile')
                if hasattr(widget, 'state_label'):
                    widget.state_label.set_text('On' if active else 'Off')
                notify(TILES[tile][0] + (': on' if active else ': off') if active is not None else 'Action completed.')
                # Re-read all states when returning to Quick; no continuous polling.
            work(lambda: toggle_tile(tile), completed, widget)

    def build_quick():
        for child in quick.get_children():
            quick.remove(child)
        if not tiles:
            quick.pack_start(text('Your Quick page is empty. Use Customize to add controls.'), False, False, 8)
        grid = Gtk.Grid(column_spacing=8, row_spacing=8, column_homogeneous=True)
        quick.pack_start(grid, False, False, 0)
        for index, tile in enumerate(tiles):
            title, icon, description = TILES[tile]
            widget = Gtk.Button()
            widget.set_hexpand(True)
            widget.get_style_context().add_class('quick-tile')
            widget.set_tooltip_text(description)
            content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3, margin=3)
            content.pack_start(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.LARGE_TOOLBAR), False, False, 0)
            label = Gtk.Label(label=title)
            label.set_ellipsize(Pango.EllipsizeMode.END)
            label.set_max_width_chars(18)
            content.pack_start(label, False, False, 0)
            widget.add(content)
            if tile in ('wifi', 'bluetooth', 'mute', 'dnd'):
                state_label = Gtk.Label(label='Checking…')
                state_label.get_style_context().add_class('muted')
                content.pack_start(state_label, False, False, 0)
                widget.state_label = state_label
                def probe(tile=tile):
                    try:
                        return tile_state(tile), ''
                    except Exception as error:
                        return None, (getattr(error, 'stderr', '') or str(error)).strip()
                def probed(value, widget=widget, description=description):
                    active, error = value
                    # Don't overwrite status while a clicked action is running.
                    if not widget.get_sensitive():
                        return
                    widget.state_label.set_text('Unavailable' if active is None else ('On' if active else 'Off'))
                    if active:
                        widget.get_style_context().add_class('active-tile')
                    if error:
                        widget.set_tooltip_text(description + ': ' + error[:250])
                if tile not in SWAY_ONLY or sway:
                    work(probe, probed)
                else:
                    state_label.set_text('Sway only')
            if tile in SWAY_ONLY and not sway:
                widget.set_sensitive(False)
                widget.set_tooltip_text('Available in the PocketTerm35 Sway session')
            widget.connect('clicked', lambda widget, tile=tile: action(tile, widget))
            grid.attach(widget, index % 2, index // 2, 1, 1)
        quick.show_all()

    def persist():
        try:
            save_layout(layout_file, tiles)
            build_quick()
            notify('Quick layout saved. Hidden controls do not change hardware state.')
        except OSError as error:
            notify('Could not save layout: ' + str(error))

    def build_editor():
        for child in editor.get_children():
            editor.remove(child)
        editor.pack_start(text('Choose your Quick controls. Switches only show/hide tiles.'), False, False, 0)
        ordered = tiles + [tile for tile in TILES if tile not in tiles]
        for tile in ordered:
            row = Gtk.Box(spacing=4)
            label = text(TILES[tile][0], False)
            label.set_ellipsize(Pango.EllipsizeMode.END)
            row.pack_start(label, True, True, 0)
            for delta, symbol in ((-1, '↑'), (1, '↓')):
                mover = Gtk.Button(label=symbol)
                mover.set_tooltip_text('Move up' if delta == -1 else 'Move down')
                mover.set_sensitive(tile in tiles and 0 <= tiles.index(tile) + delta < len(tiles))
                def move(_, tile=tile, delta=delta):
                    index = tiles.index(tile)
                    tiles[index], tiles[index+delta] = tiles[index+delta], tiles[index]
                    persist()
                    GLib.idle_add(build_editor)
                mover.connect('clicked', move)
                row.pack_end(mover, False, False, 0)
            switch = Gtk.Switch(active=tile in tiles, valign=Gtk.Align.CENTER)
            switch.set_tooltip_text('Show ' + TILES[tile][0] + ' on Quick')
            def change(switch, _, tile=tile):
                if switch.get_active() and tile not in tiles:
                    tiles.append(tile)
                elif not switch.get_active() and tile in tiles:
                    tiles.remove(tile)
                persist()
                GLib.idle_add(build_editor)
            switch.connect('notify::active', change)
            row.pack_end(switch, False, False, 4)
            editor.pack_start(row, False, False, 0)
        def defaults(_):
            tiles[:] = DEFAULT_TILES
            persist()
            build_editor()
        button(editor, 'Restore default Quick layout', defaults)
        button(editor, 'Done — back to Quick', lambda _: stack.set_visible_child_name('quick'))
        editor.show_all()
        return False

    build_quick()
    build_editor()

    # Desktop grid and terminal typography do not require a mobile shell.
    label_switch = Gtk.CheckButton(label='Show application icon labels')
    prefs_file = root / 'pocketterm35/desktop.json'
    try:
        desktop_prefs = json.loads(prefs_file.read_text())
        labels_visible = bool(desktop_prefs.get('show_labels', True))
    except (OSError, ValueError, AttributeError):
        labels_visible = True
    label_switch.set_active(labels_visible)
    def save_labels(widget):
        try:
            prefs_file.parent.mkdir(parents=True, exist_ok=True)
            temp = prefs_file.with_suffix('.tmp')
            temp.write_text(json.dumps({'show_labels': widget.get_active()}) + '\n')
            temp.replace(prefs_file)
            notify('Saved. Reopen Apps to see label visibility. Search still uses application names.')
        except OSError as error:
            notify(str(error))
    label_switch.connect('toggled', save_labels)
    look.pack_start(label_switch, False, False, 0)
    look.pack_start(text('Terminal font · size 8–14 pt'), False, False, 0)
    font_combo = Gtk.ComboBoxText()
    font_combo.set_hexpand(True)
    look.pack_start(font_combo, False, False, 0)
    font_size = Gtk.SpinButton.new_with_range(8, 14, 1)
    font_size.set_value(9)
    look.pack_start(font_size, False, False, 0)
    def populate_fonts(output):
        try:
            choice = json.loads((root / 'pocketterm35/font.json').read_text())
        except (OSError, ValueError):
            choice = {}
        names = output.splitlines()
        for name in names:
            font_combo.append(name, name)
        font_combo.set_active_id(choice.get('family', 'DejaVu Sans Mono'))
        if font_combo.get_active() < 0 and names:
            font_combo.set_active(0)
        font_size.set_value(choice.get('size', 9))
    work(lambda: command(['pocketterm35-fonts', 'list']), populate_fonts)
    def apply_font(widget):
        family = font_combo.get_active_id()
        if not family:
            notify('No installed font selected.')
            return
        size = font_size.get_value_as_int()
        work(lambda: command(['pocketterm35-fonts', 'apply', family, '--size', str(size)]),
             lambda _: notify('Font saved. Open a new terminal to preview legibility.'), widget)
    button(look, 'Apply terminal font', apply_font)
    look.pack_start(text('Neon80 can be selected after installing your licensed font file and running fc-cache.', muted=True), False, False, 0)

    # Appearance: short selectors avoid long popups overflowing the small screen.
    look.pack_start(text('Themes & wallpapers'), False, False, 0)
    if sway:
        try:
            assets = pathlib.Path('/usr/share/pocketterm35')
            themes = json.loads((assets / 'themes/palettes.json').read_text())
            wallpaper_data = json.loads((assets / 'wallpapers/manifest.json').read_text())
            theme = Gtk.ComboBoxText()
            for key, value in themes.items():
                theme.append(key, value['name'])
            try:
                selection = json.loads((root / 'pocketterm35/theme/selection.json').read_text())
            except (OSError, ValueError):
                selection = {}
            theme.set_active_id(selection.get('theme', 'nord'))
            look.pack_start(theme, False, False, 0)
            paper_palette = Gtk.ComboBoxText()
            paper_palette.append('matching', 'Wallpaper: match UI palette')
            for key, value in themes.items():
                paper_palette.append(key, 'Wallpaper: ' + value['name'])
            previous_paper = wallpaper_data.get(selection.get('wallpaper', ''), {}).get('theme')
            paper_palette.set_active_id(previous_paper if previous_paper and previous_paper != selection.get('theme') else 'matching')
            look.pack_start(paper_palette, False, False, 0)
            wallpaper = Gtk.ComboBoxText()
            for key, title in [('mountains', 'Mountains'), ('solid', 'Solid background'), ('grid', 'Grid'), ('orbits', 'Orbits'), ('stars', 'Stars')]:
                wallpaper.append(key, title)
            old = selection.get('wallpaper', '')
            chosen = wallpaper_data.get(old, {}).get('style', 'mountains') if old != 'solid' else 'solid'
            wallpaper.set_active_id(chosen)
            look.pack_start(wallpaper, False, False, 0)
            def apply_theme(widget):
                name = theme.get_active_id() or 'nord'
                style = wallpaper.get_active_id() or 'mountains'
                paper_name = paper_palette.get_active_id()
                if not paper_name or paper_name == 'matching':
                    paper_name = name
                args = ['pocketterm35-theme', 'apply', name, '--wallpaper',
                        'solid' if style == 'solid' else f'{paper_name}-{style}.png']
                work(lambda: command(args), lambda _: notify('Applied. New terminals use the new palette; reopen Controls for its colors.'), widget)
            button(look, 'Apply appearance', apply_theme)
            button(look, 'Restore default appearance', lambda widget: work(lambda: command(['pocketterm35-theme', 'reset']), lambda _: notify('Default appearance restored.'), widget))
            look.pack_start(text('8 palettes · 32 offline wallpapers. App themes remain unchanged.', muted=True), False, False, 0)
        except (OSError, ValueError, KeyError, TypeError) as error:
            look.pack_start(text('Theme files unavailable: ' + str(error)), False, False, 0)
    else:
        look.pack_start(text('Coordinated themes require the Sway session.'), False, False, 0)

    bar.pack_start(text('Bar modules — remove or add items'), False, False, 0)
    if sway:
        def json_file(path, fallback):
            try:
                value = json.loads(path.read_text())
                return value if isinstance(value, list) else fallback
            except (OSError, ValueError):
                return fallback
        hidden = json_file(root / 'waybar/pt35-hidden.json', [])
        extra = json_file(root / 'waybar/pt35-extra.json', [])
        default = {'custom/launcher', 'sway/workspaces', 'clock', 'network', 'pulseaudio', 'battery', 'custom/controls'}
        controls = {}
        for module, title in BAR_MODULES.items():
            check = Gtk.CheckButton(label=title)
            check.set_active(module not in hidden and (module in default or module in extra))
            bar.pack_start(check, False, False, 0)
            controls[module] = check
        def apply_bar(widget):
            show = [key for key, value in controls.items() if value.get_active()]
            hide = [key for key, value in controls.items() if not value.get_active()]
            def apply():
                if show:
                    command(['pocketterm35-bar', 'show', *show])
                if hide:
                    command(['pocketterm35-bar', 'hide', *hide])
            work(apply, lambda _: notify('Bar saved. Super+P always opens Controls, even if all bar items are hidden.'), widget)
        button(bar, 'Apply bar layout', apply_bar)
        button(bar, 'Toggle entire bar', lambda widget: work(lambda: command(['pocketterm35-bar', 'toggle']), widget=widget))
        bar.pack_start(text('Extra modules need supported hardware. Super+P recovers Controls; Super+B restores the bar.', muted=True), False, False, 0)
    else:
        bar.pack_start(text('Module selection requires the PocketTerm35 Sway desktop.'), False, False, 0)

    device.pack_start(text('Brightness'), False, False, 0)
    devices = backlights()
    if devices and shutil.which('brightnessctl'):
        selector = Gtk.ComboBoxText()
        for name in devices:
            selector.append_text(name)
        selector.set_active(0)
        device.pack_start(selector, False, False, 0)
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 5, 100, 5)
        scale.set_digits(0)
        def sync_brightness(*_):
            try:
                base = pathlib.Path('/sys/class/backlight') / selector.get_active_text()
                scale.set_value(max(5, 100 * int((base / 'brightness').read_text()) / int((base / 'max_brightness').read_text())))
            except (OSError, ValueError, ZeroDivisionError, TypeError):
                scale.set_value(50)
        sync_brightness()
        selector.connect('changed', sync_brightness)
        device.pack_start(scale, False, False, 0)
        def apply_brightness(widget):
            selected, value = selector.get_active_text(), round(scale.get_value())
            work(lambda: brightness(selected, value), lambda _: notify(f'Brightness set to {value}%.'), widget)
        button(device, 'Apply brightness', apply_brightness)
    else:
        device.pack_start(text('Hardware keys: Fn+− dims, Fn+= brightens, Fn+C toggles backlight on original firmware. No Linux backlight detected.', muted=True), False, False, 0)
    device.pack_start(text('Volume'), False, False, 0)
    volume = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5)
    volume.set_digits(0)
    volume.set_value(50)
    device.pack_start(volume, False, False, 0)
    def read_volume():
        import re
        output = command(['pactl', 'get-sink-volume', '@DEFAULT_SINK@'], 4)
        match = re.search(r'(\d+)%', output)
        if not match:
            raise ValueError('Audio server did not return volume')
        return min(100, int(match.group(1)))
    if shutil.which('pactl'):
        work(read_volume, volume.set_value)
    else:
        volume.set_sensitive(False)
    def set_volume(widget):
        value = round(volume.get_value())
        work(lambda: command(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', f'{value}%']), lambda _: notify(f'Volume set to {value}%.'), widget)
    button(device, 'Apply volume', set_volume)
    device.pack_start(text('CPU profiles — opens a sudo prompt in Foot'), False, False, 0)
    for profile in ('balanced', 'battery', 'performance'):
        button(device, profile.title(), lambda _, profile=profile: launch(['foot', '-e', 'sudo', '/usr/local/bin/pocketterm35-power', profile]))
    device.pack_start(text('Experimental CPU overclock · reboot required'), False, False, 0)
    device.pack_start(text('Off by default. May cause boot failure, data corruption or hardware damage. '
                           'Cooling and stable external power are required; presets are not hardware-tested.', muted=True), False, False, 0)
    clock_choice = Gtk.ComboBoxText()
    for key, title in [('stock', 'Disable overclock (keep boot profile)'), ('1800', '1.8 GHz — experimental'), ('2000', '2.0 GHz — experimental, higher voltage')]:
        clock_choice.append(key, title)
    clock_choice.set_active_id('stock')
    device.pack_start(clock_choice, False, False, 0)
    def configure_clock(_):
        launch(['foot', '-H', '-e', 'sudo', '/usr/local/bin/pocketterm35-overclock', clock_choice.get_active_id() or 'stock'])
        notify('Opened an explicit sudo/risk prompt. No reboot or overclock is applied by this button alone.')
    button(device, 'Configure next-boot CPU clock…', configure_clock)
    button(device, 'Read battery information', lambda widget: work(battery_text, notify, widget))
    device.pack_start(text('No automatic suspend. Battery telemetry and brightness depend on device firmware.', muted=True), False, False, 0)

    window.show_all()
    stack.set_visible_child_name('quick')
    Gtk.main()


if __name__ == '__main__':
    main()
