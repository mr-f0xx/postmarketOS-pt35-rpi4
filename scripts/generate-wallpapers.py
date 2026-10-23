#!/usr/bin/env python3
"""Original offline 640x480 artwork; deterministic PNGs, no external dependencies."""
import json
import math
from pathlib import Path
import random
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 640, 480


def rgb(hexcolor):
    return tuple(int(hexcolor[i:i+2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(x * (1-t) + y * t) for x, y in zip(a, b))


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)


def png(path, pixels):
    raw = b''.join(b'\0' + bytes(pixels[y*WIDTH*3:(y+1)*WIDTH*3]) for y in range(HEIGHT))
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', WIDTH, HEIGHT, 8, 2, 0, 0, 0))
                     + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def render(palette, style):
    bg, accent, surface = (rgb(palette[key]) for key in ('bg', 'accent', 'surface'))
    pixels = bytearray()
    rng = random.Random(35)
    stars = {(rng.randrange(640), rng.randrange(300)) for _ in range(85)}
    for y in range(HEIGHT):
        for x in range(WIDTH):
            color = mix(bg, surface, y / HEIGHT * 0.65)
            if style == 'mountains':
                for level in range(3):
                    ridge = 265 + level*62 + 35*math.sin(x / (82-level*12) + level*2) + 18*math.sin(x/35)
                    if y > ridge:
                        color = mix(bg, accent, 0.10 + level*0.08)
                if (x-495)**2 + (y-110)**2 < 28**2:
                    color = mix(bg, accent, 0.65)
            elif style == 'grid':
                if x % 40 == 0 or y % 40 == 0:
                    color = mix(bg, accent, 0.13)
                if abs(x-320) + abs(y-240) < 72:
                    color = mix(bg, accent, 0.18)
            elif style == 'orbits':
                distance = math.hypot(x-420, y-270)
                if any(abs(distance-radius) < 1.2 for radius in (65, 110, 160, 215)):
                    color = mix(bg, accent, 0.30)
                if (x-420)**2 + (y-270)**2 < 25**2:
                    color = mix(bg, accent, 0.65)
            elif style == 'stars':
                if (x, y) in stars:
                    color = mix(bg, accent, 0.75)
                if y > 385 + 12*math.sin(x/75):
                    color = mix(bg, accent, 0.08)
            pixels.extend(color)
    return pixels


def main():
    destination = ROOT / 'assets/wallpapers'
    destination.mkdir(parents=True, exist_ok=True)
    themes = json.loads((ROOT / 'assets/themes/palettes.json').read_text())
    manifest = {}
    for name, palette in themes.items():
        for style in ('mountains', 'grid', 'orbits', 'stars'):
            filename = f'{name}-{style}.png'
            png(destination / filename, render(palette, style))
            manifest[filename] = {'name': f'{palette["name"]} — {style.title()}', 'theme': name, 'style': style}
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')

if __name__ == '__main__':
    main()
