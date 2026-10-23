import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from test_optimization import load, ROOT


class DesktopTests(unittest.TestCase):
    def test_desktop_only_default_and_apps(self):
        config = (ROOT / 'scripts/02-configure-pmbootstrap.sh').read_text()
        self.assertIn('ui = sway', config)
        self.assertNotIn('ui = phosh', config)
        for package in ('filezilla', 'qbittorrent', 'thunderbird', 'telegram-desktop', 'foot', 'pcmanfm', 'font-jetbrains-mono', 'font-hack', 'font-fira-mono-ttf'):
            self.assertIn(package, config)
        build = (ROOT / 'scripts/04-build-image.sh').read_text()
        self.assertIn('nicotine-plus', config)
        self.assertIn('rpi-imager', config)
        self.assertNotIn('@pt35testing', build)
        self.assertNotIn('[sm/puri/phosh]', (ROOT / 'configs/dconf/00-pocketterm35').read_text())

    def test_font_override_follows_includes_and_keeps_colors(self):
        fonts = load('pocketterm35-fonts')
        before = '[main]\ninclude=/etc/xdg/foot/foot.ini\nfont=monospace:size=9\n[colors]\nbackground=000000\n'
        updated = fonts.set_font(before, 'JetBrains Mono', 10)
        self.assertLess(updated.index('include='), updated.index('font=JetBrains Mono'))
        self.assertNotIn('font=monospace', updated)
        self.assertIn('[colors]\nbackground=000000', updated)
        self.assertEqual(updated, fonts.set_font(updated, 'JetBrains Mono', 10))
        for family in ('bad\ninclude=/etc/passwd', 'bad:size=90'):
            with self.assertRaises(ValueError):
                fonts.set_font(before, family, 10)
        with self.assertRaises(ValueError):
            fonts.set_font(before, 'Hack', 30)

    def test_only_installed_fonts_can_be_selected(self):
        fonts = load('pocketterm35-fonts')
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict('os.environ', {'XDG_CONFIG_HOME': directory}), patch.object(fonts, 'families', return_value=['Hack']):
                fonts.apply('Hack', 9)
                self.assertIn('font=Hack:size=9', (Path(directory) / 'foot/foot.ini').read_text())
                with self.assertRaises(ValueError):
                    fonts.apply('Neon80', 9)

    def test_launcher_has_labels_preference_and_no_shell_execution(self):
        text = (ROOT / 'tools/pocketterm35-apps').read_text()
        self.assertIn("get('show_labels', True)", text)
        self.assertIn('if show_labels:', text)
        self.assertIn('app.launch([],', text)
        self.assertNotIn('shell=True', text)
        self.assertIn('app.should_show()', text)
