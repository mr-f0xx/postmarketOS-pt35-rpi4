# PocketTerm35 — optimized postmarketOS for Raspberry Pi 4B

**Pi 4B only · aarch64 · 640×480 landscape · desktop-only Sway**

**Login:** `flylopi` / **PIN/password:** `0807`. Change this public password with
`passwd` after boot. The session starts a swaylock PIN/password lock; physical
keyboard required for unlocking in Sway. This is not a validated release image.

## What is optimized

- Native scale **1**, borderless windows and one main application per workspace.
  Extra non-floating windows move to a free workspace; dialogs stay with their app.
- Compact **24-pixel Waybar**, fullscreen and bar visibility toggles. Network,
  volume, battery, clock and workspace modules can be removed independently.
- Foot terminal: 9-point font, 2-pixel padding, bounded scrollback, no blinking cursor.
- Dynamic CPU governor, optional battery/performance profiles, no overclocking by default.
- RAM-aware compressed swap: half of RAM, capped at **1 GiB**, priority 100.
  Leaves pre-existing zram configurations and disk swap alone.
- On-demand on-screen keyboard, compact notifications, five-minute idle lock/blanking.
  No untested automatic suspend, guessed battery readings or firmware flashing.
- No mobile shell, dialer, SMS client or contacts application is selected.
- Repeatable file-only image customization, one-time boot/config backups, package
  manifest, build provenance and final image checksum.

See [device guide](docs/DEVICE-GUIDE.md) for tuning, recovery and acceptance tests.

## Build

Use a normal **Linux user with sudo**, at least 25 GB free space and 2 GB RAM.
Upstream GitLab, Alpine and postmarketOS mirrors must be reachable. Do not run
the entire pipeline with sudo; individual commands request it.

```sh
./scripts/00-run-all.sh
```

Step 02 backs up the host configuration and configures **ui=sway**, not a Phosh
base. It uses a new isolated work directory:
`~/.local/var/pmbootstrap-pocketterm35-desktop`. Step 05 selects the compact
PocketTerm35 desktop through tinydm. Phone UI/session selection is no longer
supported. A stale mobile rootfs is rejected rather than carried into a release.

For individual steps, run 01–05 in order as the same user. After step 01:
`export PATH="$HOME/.local/bin:$PATH"`. `./scripts/07-preflight.sh` runs host
checks without writing to a device. Host configuration backup:
`~/.config/pmbootstrap_v3.cfg.before-pocketterm35`.

Output is `images/postmarketOS-latest.img`, with checksum and provenance beside
it and a timestamped installed-package list. These are ignored by Git.

**Reproducibility limits:** package lists, source revision, source-file hashes
and image checksum record what was built; this does not make rolling edge
packages bit-for-bit reproducible. Preserve the image and source checkout for a
known-working release. Do not update a deployed device blindly.

### Flashing

Identify the target carefully (`lsblk`), then flash to microSD or supported USB
storage. This **erases the selected drive**:

```sh
sudo dd if=images/postmarketOS-latest.img of=/dev/sdX bs=4M status=progress conv=fsync
```

The Pi 4 does **not** support the Pi 5's native PCIe/NVMe connector. The legacy
NVMe helper is not a direct Pi 4 NVMe boot solution. Storage expansion is left
to the distribution, not a custom untested resize service.

## Controls and shortcuts

Launch **PocketTerm35 Controls** from Apps or press **Super+P**.

| Shortcut | Action |
|---|---|
| Super+Return / Alt+Return | Terminal |
| Super+D | Application launcher |
| Super+P | Controls: brightness and status-bar modules |
| Super+L | Lock |
| Super+F / Alt+F11 | Fullscreen (bar hidden) |
| Super+B | Toggle bar visibility |
| Super+Tab / Super+Shift+Tab | Next / previous workspace |
| Super+1…4 | Workspace selection |
| Super+R | Recover oversized window to 600×400 |
| Super+Shift+Space | Toggle floating |
| Super+O | Toggle software keyboard |
| Super+Q | Close app |
| Super+Shift+C | Reload Sway configuration |
| Super+Shift+E | Confirm logout |
| Ctrl+plus/minus / Ctrl+0 in Foot | Font resize / reset |

The bar's **Apps**, workspace numbers and **Set** buttons are touch-accessible.
Press Super+F again to leave fullscreen. Super+B restores a hidden bar.

### Brightness and battery: hardware limits

Original firmware copies show **Fn+minus** dims, **Fn+equals** brightens and
**Fn+C** toggles backlight. Firmware variants may differ. These run directly on
the RP2040 and do not need Linux support. When Linux exposes a real backlight,
Controls offers `brightnessctl` adjustment from 5–100%; normal distribution
permissions apply. Without a Linux backlight the GUI displays hardware-key
instructions, not a fake slider. No gamma-based imitation is used.

Battery percentage appears **only when a genuine Linux battery device is
available**. RP2040-only telemetry is not implemented: it needs a verified
firmware interface and a proper driver/UPower bridge. No speculative I²C reads,
voltage-derived fake percentage or automatic low-battery shutdown is installed.

## Hardware and overlay provenance

The display is **HDMI, not DPI**. Boot uses full KMS, with HDMI-A-1 forced to
640×480@60; connect the panel to HDMI0. Touch is Goodix GT911 over I²C and the
RP2040 keyboard is USB HID. The device package's kernel/initramfs/DTB settings
are retained; PocketTerm35 settings are included through `usercfg.txt`.

The Waveshare overlay named **5b** supports the GT911 at `0x5d` on Pi 4 as well
as `0x14`. The 4b overlay only probes `0x14`. Do not enable both. Step 03 uses
[this pinned community mirror](https://github.com/therezor/PocketTerm35-OS/tree/8e5b919390e60f468e534770335abe8ae0cb2451/boot)
of Waveshare's `3.5HDMI_E_DTBO.zip`, verifies SHA-256 and DTB magic, and fails
rather than creating placeholders. See also the
[community Pi 4 configuration](https://github.com/altgreen64/pocketterm35/tree/main/pocketterm35).

## Validation status

Host tests cover configuration, shell syntax, bar generation/CLI, brightness
validation, CPU policy changes against fixtures, zram sizing, workspace placement
and repeatable rootfs installation and previous-session backup. Run:

```sh
python3 -m unittest discover -s tests -v
# Also exercises file-only rootfs install in a temporary fixture:
sudo python3 -m unittest discover -s tests -v
```

**Not yet verified:** full image build/boot, Sway/Waybar rendering on the Pi,
GPU acceleration, touch accuracy, firmware keys, battery telemetry and sustained
thermal/power behaviour. This sandbox lacks the complete build toolchain and
cannot reach the required GitLab/Alpine hosts. A successful configuration test
is not evidence of working hardware. Follow the device guide before relying
on the image.

## Themes and wallpapers

Controls includes **Nord, Amber on Black, Dracula, Tokyo Night, Solarized
Dark/Light, Gruvbox Dark and Catppuccin Mocha**, plus **32 offline 640×480
wallpapers** (mountains, grid, orbits and stars for every palette). Sway, Waybar,
Foot, Wofi, notifications and lock-screen background use coordinated colors;
Other GTK application themes are unchanged. Choose a solid background if
preferred. See the device guide for CLI selection, backups and reset behaviour.

### Customizable control center

Controls now uses **Quick / Look / Bar / Device** pages in a compact **560×400**
window. Use **Customize** to show, hide or reorder any Quick tile; even an empty
layout is recoverable. Add Wi-Fi, Bluetooth, mute, Do Not Disturb, keyboard,
lock, terminal, network setup and device shortcuts. The Bar page can hide every
default module and optionally add CPU, memory, temperature, brightness or
Bluetooth. Slow device commands run asynchronously. See the device guide for
hardware limitations and the required on-device scaling checks.

### Desktop apps, fonts and icon labels

The build now selects a **desktop-only Sway base**, not Phosh. It requests
FileZilla, qBittorrent, Nicotine+, Thunderbird, Telegram Desktop and Raspberry Pi
Imager, plus Foot and PCManFM. Nicotine+ and Imager require tagged Alpine
edge/testing packages; full build/dependency validation is still pending.

Controls → Look offers installed terminal fonts and an app-grid label toggle.
Font packages include JetBrains Mono, Hack, Fira Mono, Source Code Pro,
Inconsolata, DejaVu, Liberation and Noto. **Neon80 needs a verified licensed source
before bundling**; a personally installed licensed font becomes selectable.
See the device guide for testing risks, font installation and app-size limits.

### Optional overclock

Controls → Device now offers **experimental 1.8 GHz / 2.0 GHz CPU boot presets**
and an option to disable them. Overclocking is off by default, requires sudo and
an explicit typed risk confirmation, and never reboots automatically. Cooling,
stable power, backups and a recovery card reader are essential. Settings are
not hardware-validated and can cause boot failure/data corruption/hardware damage.
See the device guide for voltage offsets, limitations and SD-card recovery.
