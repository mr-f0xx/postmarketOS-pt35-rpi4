import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class ConfigurationTests(unittest.TestCase):
    def test_shell_syntax(self):
        for script in (ROOT / 'scripts').glob('*.sh'):
            subprocess.run(['sh', '-n', str(script)], check=True)

    def test_pi4_credentials(self):
        config = (ROOT / 'scripts/02-configure-pmbootstrap.sh').read_text()
        for value in ('device = raspberry-pi4', 'user = flylopi', 'service_manager = openrc'):
            self.assertIn(value, config)
        self.assertIn('--password 0807', (ROOT / 'scripts/04-build-image.sh').read_text())

    def test_safe_profiles(self):
        for profile in (ROOT / 'configs').glob('usercfg.txt*'):
            text = profile.read_text()
            self.assertEqual(text.count('dtoverlay=waveshare-35dpi-'), 1)
            self.assertIn('dtoverlay=dwc2,dr_mode=host', text)
            for forbidden in ('force_turbo=', 'sdram_freq=', 'avoid_warnings=', 'over_voltage='):
                self.assertNotIn(forbidden, text)

    def test_native_scaling(self):
        text = (ROOT / 'configs/sway/config').read_text()
        self.assertEqual(text.count('mode 640x480@60Hz scale 1'), 2)

    def test_no_fake_overlay(self):
        text = (ROOT / 'scripts/03-prepare-dtbos.sh').read_text()
        self.assertIn('sha256sum -c', text)
        self.assertIn('d00dfeed', text)

if __name__ == '__main__':
    unittest.main()

class BuildConfigurationTests(unittest.TestCase):
    def test_extra_packages_have_no_whitespace(self):
        config = (ROOT / 'scripts/02-configure-pmbootstrap.sh').read_text()
        line = next(line for line in config.splitlines() if line.startswith('extra_packages = '))
        packages = line.split(' = ', 1)[1].split(',')
        self.assertTrue(packages)
        self.assertTrue(all(package and package == package.strip() for package in packages))
        self.assertIn('aports = $PMAPORTS_DIR', config)
        self.assertIn('pmb.config.work_version', config)

    def test_device_kernel_paths_preserved_without_old_overclock(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('merge_usercfg', ROOT / 'scripts/merge-usercfg.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        text = module.merge('kernel=vmlinuz-rpi\ninitramfs initramfs\narm_control=0x200\narm_freq=2000\n',
                            '[all]\ndtoverlay=vc4-kms-v3d\n')
        self.assertIn('kernel=vmlinuz-rpi', text)
        self.assertIn('initramfs initramfs', text)
        self.assertNotIn('arm_freq=', text)
