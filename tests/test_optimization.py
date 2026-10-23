import copy
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    loader = importlib.machinery.SourceFileLoader(name.replace('-', '_'), str(ROOT / 'tools' / name))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class OptimizationTests(unittest.TestCase):
    def test_bar_reclaims_space_without_modifying_base(self):
        bar = load('pocketterm35-bar')
        base = json.loads((ROOT / 'configs/waybar/config.json').read_text())
        before = copy.deepcopy(base)
        result = bar.configure(base, {'clock', 'network', 'battery'})
        self.assertEqual(base, before)
        self.assertEqual(result['modules-center'], [])
        self.assertNotIn('network', result['modules-right'])
        self.assertIn('custom/controls', result['modules-right'])
        self.assertTrue(result['ipc'])
        self.assertEqual(result['id'], 'pt35')

    def test_bar_cli_reset_hide_show(self):
        bar = load('pocketterm35-bar')
        with tempfile.TemporaryDirectory() as directory:
            env = {'XDG_CONFIG_HOME': directory}
            with patch.dict(os.environ, env), patch.object(bar, 'BASE', ROOT / 'configs/waybar/config.json'), patch.object(bar.subprocess, 'run'):
                for arguments in (['reset'], ['hide', 'clock', 'network'], ['show', 'network']):
                    with patch('sys.argv', ['pocketterm35-bar', *arguments]):
                        bar.main()
                state = json.loads((Path(directory) / 'waybar/pt35-hidden.json').read_text())
                self.assertEqual(state, ['clock'])
                config = json.loads((Path(directory) / 'waybar/config').read_text())
                self.assertEqual(config['modules-center'], [])
                self.assertIn('network', config['modules-right'])

    def test_governor_selection_and_caps(self):
        power = load('pocketterm35-power')
        self.assertEqual(power.limits('balanced', 1500000, 600000, ['schedutil', 'performance']), ('schedutil', 1500000))
        self.assertEqual(power.limits('battery', 1800000, 600000, ['ondemand']), ('ondemand', 1200000))
        self.assertEqual(power.limits('battery', 1000000, 600000, ['ondemand']), ('ondemand', 1000000))
        with self.assertRaises(ValueError):
            power.limits('balanced', 1500000, 600000, ['performance'])

    def test_cpu_profile_restores_hardware_max(self):
        power = load('pocketterm35-power')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            policy = root / 'policy0'
            policy.mkdir()
            for name, value in {'cpuinfo_max_freq': '1500000', 'scaling_min_freq': '600000',
                                'scaling_available_governors': 'ondemand performance',
                                'scaling_max_freq': '1500000', 'scaling_governor': 'ondemand'}.items():
                (policy / name).write_text(value)
            power.apply('battery', root)
            self.assertEqual((policy / 'scaling_max_freq').read_text(), '1200000')
            power.apply('balanced', root)
            self.assertEqual((policy / 'scaling_max_freq').read_text(), '1500000')

    def test_bounded_zram_for_all_ram_sizes(self):
        zram = load('pocketterm35-zram')
        for gib in (1, 2, 4, 8):
            size = zram.size_bytes(gib * 1024 * 1024)
            self.assertLessEqual(size, 1024 ** 3)
            self.assertEqual(size, min(gib * 1024 ** 3 // 2, 1024 ** 3))

    def test_existing_zram_not_touched(self):
        zram = load('pocketterm35-zram')
        with patch.object(zram, 'MARKER') as marker, patch.object(zram, 'run') as run:
            marker.exists.return_value = True
            zram.start()
            run.assert_not_called()

    def test_failed_swapoff_never_resets_active_device(self):
        zram = load('pocketterm35-zram')
        with patch.object(zram, 'MARKER') as marker, patch.object(zram, 'run') as run:
            marker.exists.return_value = True
            marker.read_text.return_value = '/dev/zram0\n'
            run.side_effect = subprocess.CalledProcessError(1, 'swapoff')
            with self.assertRaises(subprocess.CalledProcessError):
                zram.stop()
            run.assert_called_once_with('swapoff', '/dev/zram0')
            marker.unlink.assert_not_called()

    def test_dialogs_not_moved_to_new_workspace(self):
        windows = load('pocketterm35-windows')
        app = lambda identifier: {'type': 'con', 'id': identifier, 'app_id': 'foot', 'nodes': []}
        tree = {'nodes': [{'type': 'workspace', 'num': 1, 'nodes': [app(1), app(2)], 'floating_nodes': []}]}
        self.assertEqual(windows.destination(tree, 2), 2)
        tree['nodes'][0]['floating_nodes'] = [app(3)]
        self.assertIsNone(windows.destination(tree, 3))
        tree['nodes'].append({'type': 'workspace', 'num': 2, 'nodes': [app(4)]})
        self.assertEqual(windows.destination(tree, 2), 3)

    def test_all_shell_helpers_parse(self):
        for directory in ('tools', 'configs/openrc'):
            for path in (ROOT / directory).iterdir():
                if path.is_file() and path.read_text().startswith(('#!/bin/sh', '#!/sbin/openrc-run')):
                    subprocess.run(['sh', '-n', str(path)], check=True)

    def test_no_forced_software_renderer_or_overclock(self):
        session = (ROOT / 'tools/pocketterm35-session').read_text()
        self.assertNotIn('WLR_RENDERER=', session)
        self.assertNotIn('LIBGL_ALWAYS_SOFTWARE=', session)
        self.assertNotIn('arm_freq=', (ROOT / 'configs/usercfg.txt').read_text())

    @unittest.skipUnless(os.geteuid() == 0, 'file-only installation test needs root ownership')
    def test_rootfs_install_repeatable_and_preserves_previous_session(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            for folder in ('etc/init.d', 'usr/share/wayland-sessions', 'etc/dconf/profile', 'var/lib/tinydm'):
                (target / folder).mkdir(parents=True)
            (target / 'etc/passwd').write_text('flylopi:x:1000:1000::/home/flylopi:/bin/sh\n')
            (target / 'etc/init.d/tinydm').write_text('# test fixture\n')
            (target / 'usr/share/wayland-sessions/sway.desktop').write_text('[Desktop Entry]\n')
            profile = target / 'etc/dconf/profile/user'
            profile.write_text('user-db:user\nsystem-db:vendor\n')
            session = target / 'var/lib/tinydm/default-session.desktop'
            session.symlink_to('/usr/share/wayland-sessions/sway.desktop')
            command = ['sh', str(ROOT / 'scripts/install-rootfs.sh'), str(target)]
            subprocess.run(command, check=True)
            first = (target / 'etc/sway/pocketterm35.conf').read_bytes()
            subprocess.run(command, check=True)
            self.assertEqual(first, (target / 'etc/sway/pocketterm35.conf').read_bytes())
            self.assertEqual(profile.read_text().count('system-db:local'), 1)
            self.assertIn('system-db:vendor', profile.read_text())
            self.assertEqual(os.readlink(session), '/usr/share/wayland-sessions/pocketterm35.desktop')
            self.assertEqual(os.readlink(str(session) + '.before-pocketterm35'), '/usr/share/wayland-sessions/sway.desktop')
            rejected = subprocess.run(command + ['phosh'], capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertEqual(os.readlink(session), '/usr/share/wayland-sessions/pocketterm35.desktop')
            self.assertTrue(os.access(target / 'usr/local/bin/pocketterm35-report', os.X_OK))

class BarExtrasTests(unittest.TestCase):
    def test_any_base_module_can_be_hidden_and_extras_added(self):
        bar = load('pocketterm35-bar')
        base = json.loads((ROOT / 'configs/waybar/config.json').read_text())
        hidden = set(base['modules-left'] + base['modules-center'] + base['modules-right'])
        result = bar.configure(base, hidden, ['cpu', 'memory', 'bluetooth'])
        self.assertEqual(result['modules-left'], [])
        self.assertEqual(result['modules-center'], [])
        self.assertEqual(result['modules-right'], ['cpu', 'memory', 'bluetooth'])
        result = bar.configure(base, hidden | {'cpu'}, ['cpu'])
        self.assertEqual(result['modules-right'], [])

    def test_extra_cli_state_survives_and_resets(self):
        bar = load('pocketterm35-bar')
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {'XDG_CONFIG_HOME': directory}), patch.object(bar, 'BASE', ROOT / 'configs/waybar/config.json'), patch.object(bar.subprocess, 'run'):
                for arguments in (['show', 'cpu', 'memory'], ['hide', 'custom/launcher', 'memory']):
                    with patch('sys.argv', ['pocketterm35-bar', *arguments]):
                        bar.main()
                config = json.loads((Path(directory) / 'waybar/config').read_text())
                self.assertIn('cpu', config['modules-right'])
                self.assertNotIn('memory', config['modules-right'])
                self.assertNotIn('custom/launcher', config['modules-left'])
                with patch('sys.argv', ['pocketterm35-bar', 'reset']):
                    bar.main()
                self.assertEqual(json.loads((Path(directory) / 'waybar/pt35-extra.json').read_text()), [])
