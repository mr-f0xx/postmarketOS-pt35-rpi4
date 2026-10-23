import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
from test_optimization import load, ROOT


class ThemeTests(unittest.TestCase):
    def test_all_palettes_have_valid_colors(self):
        theme = load('pocketterm35-theme')
        with patch.object(theme, 'ASSETS', ROOT / 'assets'):
            palettes = theme.palettes()
        self.assertEqual(len(palettes), 8)
        for name, palette in palettes.items():
            config = theme.foot_colors(palette)
            self.assertIn('regular7=', config)
            self.assertIn('bright7=', config)

    def test_32_native_resolution_wallpapers(self):
        manifest = json.loads((ROOT / 'assets/wallpapers/manifest.json').read_text())
        self.assertEqual(len(manifest), 32)
        for filename in manifest:
            data = (ROOT / 'assets/wallpapers' / filename).read_bytes()
            self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
            self.assertEqual(struct.unpack('!II', data[16:24]), (640, 480))

    def test_apply_and_reset_preserve_personal_foot(self):
        theme = load('pocketterm35-theme')
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            # Mimic installed shared defaults, without privileged target execution.
            assets = root / 'assets'
            (assets / 'themes').mkdir(parents=True)
            (assets / 'wallpapers').mkdir()
            for source, dest in [('assets/themes/palettes.json', 'themes/palettes.json'),
                                 ('assets/wallpapers/manifest.json', 'wallpapers/manifest.json'),
                                 ('configs/mako/config', 'themes/mako-base.conf')]:
                (assets / dest).write_bytes((ROOT / source).read_bytes())
            config = root / 'config'
            (config / 'foot').mkdir(parents=True)
            original = '[main]\nfont=monospace:size=11\n'
            (config / 'foot/foot.ini').write_text(original)
            with patch.object(theme, 'ASSETS', assets), patch.dict(os.environ, {'XDG_CONFIG_HOME': str(config)}), patch.object(theme, 'refresh'):
                theme.apply('nord')
                self.assertIn('include=', (config / 'foot/foot.ini').read_text())
                self.assertIn('nord-mountains.png', (config / 'pocketterm35/theme/sway.conf').read_text())
                theme.apply('amber', 'solid')
                self.assertIn('#000000 solid_color', (config / 'pocketterm35/theme/sway.conf').read_text())
                self.assertEqual((config / 'pocketterm35/foot-before-theme.ini').read_text(), original)
                with self.assertRaises(ValueError):
                    theme.apply('nord', '../../not-a-wallpaper.png')
                with patch.dict(os.environ, {'SWAYSOCK': ''}):
                    theme.reset()
                self.assertEqual((config / 'foot/foot.ini').read_text(), original)
                self.assertFalse((config / 'pocketterm35/theme/sway.conf').exists())

    def test_theme_assets_are_installed(self):
        text = (ROOT / 'scripts/install-rootfs.sh').read_text()
        for token in ('palettes.json', 'wallpapers/*.png', 'pocketterm35-theme', 'pocketterm35-notifications'):
            self.assertIn(token, text)
