#!/usr/bin/env python3
"""Keep device-package boot paths when replacing the hardware settings."""
import pathlib
import re
import sys


def merge(device, profile):
    boot = [line for line in device.splitlines()
            if re.match(r'^\s*(?:(?:kernel|arm_64bit|arm_control)\s*=|initramfs\s+)', line)]
    return '[all]\n' + '\n'.join(boot) + '\n' + profile


if __name__ == '__main__':
    print(merge(pathlib.Path(sys.argv[1]).read_text(), pathlib.Path(sys.argv[2]).read_text()), end='')
