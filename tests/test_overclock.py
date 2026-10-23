import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from test_optimization import load, ROOT

MODEL = 'Raspberry Pi 4 Model B Rev 1.4'


class OverclockTests(unittest.TestCase):
    def fixture(self, directory):
        boot = Path(directory)
        (boot / 'config.txt').write_text('[all]\ninclude usercfg.txt\n')
        (boot / 'usercfg.txt').write_text('[all]\ninclude pocketterm35-overclock.txt\n')
        (boot / 'pocketterm35-overclock.txt').write_text('# original stock setting\n')
        return boot

    def test_stock_is_disabled_and_all_profiles_include_optional_file(self):
        tool = load('pocketterm35-overclock')
        self.assertEqual(tool.render('stock'), (ROOT / 'configs/pocketterm35-overclock.txt').read_text())
        self.assertNotIn('arm_freq=', tool.render('stock'))
        for profile in (ROOT / 'configs').glob('usercfg.txt*'):
            self.assertEqual(profile.read_text().count('include pocketterm35-overclock.txt'), 1)

    def test_presets_do_not_disable_protections_or_overclock_gpu_ram(self):
        tool = load('pocketterm35-overclock')
        for preset in tool.PRESETS:
            output = tool.render(preset)
            self.assertIn('arm_freq=' + preset, output)
            for forbidden in ('force_turbo=', 'avoid_warnings=', 'temp_limit=', 'gpu_freq=', 'sdram_freq='):
                self.assertNotIn(forbidden, output)

    def test_wrong_board_and_missing_include_rejected(self):
        tool = load('pocketterm35-overclock')
        with tempfile.TemporaryDirectory() as directory:
            boot = self.fixture(directory)
            for board in ('Raspberry Pi 5 Model B', 'Raspberry Pi 400', 'unknown'):
                with self.assertRaises(ValueError):
                    tool.validate(boot, board, '1800')
            (boot / 'usercfg.txt').write_text('[all]\n')
            with self.assertRaises(ValueError):
                tool.validate(boot, MODEL, '1800')

    def test_conflicting_boot_profile_refused_but_disable_allowed(self):
        tool = load('pocketterm35-overclock')
        with tempfile.TemporaryDirectory() as directory:
            boot = self.fixture(directory)
            with (boot / 'usercfg.txt').open('a') as file:
                file.write('arm_freq=1200\n')
            with self.assertRaises(ValueError):
                tool.validate(boot, MODEL, '2000')
            tool.validate(boot, MODEL, 'stock')

    def test_backup_preserved_and_stock_reversible(self):
        tool = load('pocketterm35-overclock')
        with tempfile.TemporaryDirectory() as directory, patch.object(tool.os, 'sync'):
            boot = self.fixture(directory)
            tool.write_preset(boot, MODEL, '1800')
            tool.write_preset(boot, MODEL, '2000')
            self.assertIn('arm_freq=2000', (boot / 'pocketterm35-overclock.txt').read_text())
            self.assertEqual((boot / 'pocketterm35-overclock.txt.before-overclock').read_text(), '# original stock setting\n')
            tool.write_preset(boot, MODEL, 'stock')
            self.assertEqual((boot / 'pocketterm35-overclock.txt').read_text(), tool.STOCK)
            self.assertFalse(list(boot.glob('.pt35-clock-*')))

    def test_symlinked_target_rejected(self):
        tool = load('pocketterm35-overclock')
        with tempfile.TemporaryDirectory() as directory:
            boot = self.fixture(directory)
            target = boot / 'pocketterm35-overclock.txt'
            target.unlink()
            target.symlink_to(boot / 'config.txt')
            with self.assertRaises(ValueError):
                tool.write_preset(boot, MODEL, '1800')
            self.assertIn('include usercfg.txt', (boot / 'config.txt').read_text())

    def test_risk_confirmation_rejects_noninteractive_and_wrong_phrase(self):
        tool = load('pocketterm35-overclock')
        with patch.object(tool.sys.stdin, 'isatty', return_value=False), patch('builtins.input') as prompt:
            with self.assertRaises(ValueError):
                tool.confirm_risk()
            prompt.assert_not_called()
        with patch.object(tool.sys.stdin, 'isatty', return_value=True), patch('builtins.input', return_value='yes'):
            with self.assertRaises(ValueError):
                tool.confirm_risk()
        with patch.object(tool.sys.stdin, 'isatty', return_value=True), patch('builtins.input', return_value='OVERCLOCK'):
            tool.confirm_risk()
