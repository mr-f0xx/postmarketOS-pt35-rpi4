import importlib.util
import pathlib
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('controls', ROOT / 'tools/pocketterm35-controls.py')
controls = importlib.util.module_from_spec(spec)
spec.loader.exec_module(controls)


class ControlsTests(unittest.TestCase):
    def test_backlight_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'panel').mkdir()
            (root / 'panel/max_brightness').write_text('255')
            (root / 'not-a-backlight').mkdir()
            self.assertEqual(controls.backlights(root), ['panel'])
        self.assertEqual(controls.backlights(pathlib.Path('/nonexistent/pt35')), [])

    def test_brightness_limits_and_command(self):
        with patch.object(controls, 'backlights', return_value=['panel']), patch.object(controls.subprocess, 'run') as run:
            for percent in (0, 4, 101):
                with self.assertRaises(ValueError):
                    controls.brightness('panel', percent)
            with self.assertRaises(ValueError):
                controls.brightness('other', 50)
            run.assert_not_called()
            controls.brightness('panel', 50)
            self.assertEqual(run.call_args.args[0], ['brightnessctl', '--class=backlight', '--device', 'panel', 'set', '50%'])

    def test_default_settings_have_unique_sections(self):
        import configparser
        config = configparser.ConfigParser(interpolation=None)
        config.read(ROOT / 'configs/dconf/00-pocketterm35')
        self.assertEqual(config['org/gnome/settings-daemon/plugins/power']['sleep-inactive-battery-type'], "'nothing'")

    def test_quick_layout_normalizes_and_keeps_empty(self):
        self.assertEqual(controls.normalize_layout({'tiles': []}), [])
        self.assertEqual(controls.normalize_layout({'tiles': ['wifi', 'wifi', 'unknown', None, 'lock']}), ['wifi', 'lock'])
        for malformed in (None, [], 'wifi', {'tiles': 'wifi'}, {'other': []}):
            self.assertEqual(controls.normalize_layout(malformed), controls.DEFAULT_TILES)

    def test_layout_roundtrip_and_corrupt_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'controls/layout.json'
            self.assertEqual(controls.load_layout(path), controls.DEFAULT_TILES)
            controls.save_layout(path, ['lock', 'wifi', 'mute'])
            self.assertEqual(controls.load_layout(path), ['lock', 'wifi', 'mute'])
            controls.save_layout(path, [])
            self.assertEqual(controls.load_layout(path), [])
            path.write_text('{bad json')
            self.assertEqual(controls.load_layout(path), controls.DEFAULT_TILES)

    def test_wifi_toggle_reads_actual_state_and_confirms_result(self):
        with patch.object(controls, 'command', side_effect=['enabled', '', 'disabled']) as command:
            self.assertFalse(controls.toggle_tile('wifi'))
            self.assertEqual(command.call_args_list[1].args[0], ['nmcli', 'radio', 'wifi', 'off'])

    def test_unknown_state_does_not_issue_hardware_change(self):
        with patch.object(controls, 'command', return_value='unknown') as command:
            with self.assertRaises(ValueError):
                controls.toggle_tile('wifi')
            command.assert_called_once_with(['nmcli', 'radio', 'wifi'], 4)

    def test_failed_action_does_not_report_success(self):
        import subprocess
        with patch.object(controls, 'command', side_effect=['enabled', subprocess.CalledProcessError(1, 'nmcli')]):
            with self.assertRaises(subprocess.CalledProcessError):
                controls.toggle_tile('wifi')

    def test_no_fake_battery_percentage(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            self.assertIn('No Linux battery device', controls.battery_text(root))
            (root / 'BAT0').mkdir()
            (root / 'BAT0/type').write_text('Battery\n')
            (root / 'BAT0/capacity').write_text('73\n')
            (root / 'BAT0/status').write_text('Charging\n')
            self.assertEqual(controls.battery_text(root), 'capacity: 73%\nstatus: Charging')

    def test_fixed_catalog_rejects_custom_commands(self):
        self.assertEqual(controls.normalize_layout({'tiles': ['$(reboot)', 'wifi; reboot']}), [])
        with self.assertRaises(ValueError):
            controls.toggle_tile('reboot')

    def test_control_dimensions_match_sway_and_leave_screen_space(self):
        width, height = controls.WINDOW_SIZE
        self.assertLessEqual(width, 640 - 24)
        self.assertLessEqual(height, 480 - 48)
        config = (ROOT / 'configs/sway/config').read_text()
        self.assertIn(f'resize set {width} {height}', config)
