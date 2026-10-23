# PocketTerm35 device guide

## Desktop-only sessions and recovery

The build now uses **postmarketos-ui-sway** directly. Phosh, dialer/SMS/contacts
applications and cellular functions are not selected. Existing cellular modem
services are disabled during provisioning if found. Bluetooth, Wi-Fi and the
on-screen keyboard remain useful desktop functions and are retained.

The build uses a fresh isolated work directory to avoid recycling the earlier
mobile image. `PT35_SESSION=phosh` is no longer accepted. Previous-session symlink
backups remain available for recovery, but no mobile fallback is installed.
To reselect the installed desktop from a TTY:

```sh
sudo tinydm-set-session -f -s /usr/share/wayland-sessions/pocketterm35.desktop
```

Log out/reboot after changing the session. Physical keyboard is required for
swaylock authentication. Keep a known-working image as the primary recovery path.

One-time backups use `.before-pocketterm35` suffixes. The previous default-session
symlink is preserved with that suffix. Boot backups include `config.txt`,
`cmdline.txt` and an existing `usercfg.txt`. Restore those from a card reader if
a display change prevents boot. Do not overwrite the firmware's kernel/initramfs
paths with configuration from another distribution.

Re-running step 05 edits the existing image, not a fresh export. Steps 04/00
create a new image and therefore discard manual edits to an older image. The
file-only installer backs up rootfs config once and does not execute ARM binaries
on the host. It expects a standard unencrypted two-partition pmbootstrap image.

## Personal screen and app defaults

System Sway config: `/etc/sway/pocketterm35.conf`. Put personal overrides in
`~/.config/pocketterm35/sway.conf` and press Super+Shift+C. E.g. a different layout:

```sway
input type:keyboard xkb_layout fr
```

Keep scale 1: scale 2 gives only 320×240 logical pixels. Do not shrink every font
to make one large desktop application fit; prefer adaptive/native Wayland apps.
The app launcher and Controls are constrained to the panel size, but no global
setting can make every third-party dialog fit. Super+R is the recovery shortcut.
Floating dialogs can still require app-specific changes.

The window placement helper moves extra *tiled* windows onto free numbered
workspaces; floating dialogs are left with their parent. App-switching through
the bar remains available with touch. Remove `exec pocketterm35-windows` in a
copy of the system config if traditional tiling is preferred.

Foot user overrides: `~/.config/foot/foot.ini`. The system defaults have a 9-point
font; try 10 points if it is hard to read. Physical readability must be checked
on the real 3.5-inch panel. XWayland starts on demand through Sway, not as a
second desktop.

## Status bar customization

In Sway, Controls removes selected modules from Waybar's layout immediately,
reclaiming their space. It does not disable networking/audio/battery hardware.
**Apps** and **Set** are enabled by default but can also be hidden. Keep at least
one visible for touch access; **Super+P** is the keyboard recovery path. Battery cannot be
shown when Linux has no power_supply battery device.

Equivalent commands:

```sh
pocketterm35-bar hide network pulseaudio
pocketterm35-bar show network
pocketterm35-bar reset
pocketterm35-bar toggle
```

Generated configuration is `~/.config/waybar/config`; hidden-module state is
`pt35-hidden.json` in the same folder. The system baseline is
`/etc/xdg/waybar/pt35-base.json`. Existing user config is backed up once as
`config.before-pocketterm35` before first replacement. Restore that backup
manually if you want your old custom bar back. `reset` restores baseline modules,
not the old user file. Saving through Controls regenerates from the baseline;
manual additions to the generated file are not preserved. For custom styles use
`~/.config/waybar/style.css`; keep bars reasonably sized for touch.

Fullscreen hides the bar; Super+B controls ordinary visibility. Notifications
are compact and bounded to two visible items. Software keyboard runs only when
requested and uses 170 vertical pixels. Apps may not all resize correctly.


## CPU, memory and storage

Balanced starts automatically using `schedutil`, `ondemand` or `conservative`
(in that preference order), at the hardware-advertised maximum. No forced
low-speed governor, RAM/GPU clock changes, overvoltage, hidden undervoltage
warnings or disabled thermal protection. Stock firmware boost remains disabled
in the small enclosure; this is not an overclocked profile.

```sh
sudo pocketterm35-power balanced
sudo pocketterm35-power battery      # dynamic governor, maximum 1200 MHz
sudo pocketterm35-power performance  # performance governor, hardware maximum
```

Runtime changes last until reboot. For a persistent choice, edit
`/etc/conf.d/pocketterm35-power` (`profile="balanced"`, `"battery"` or
`"performance"`). Not every kernel exports every governor; failure is reported
rather than forcing an unsupported setting. Performance keeps the CPU fast even
at idle: prefer balanced for normal use. Returning to balanced restores the
hardware maximum after a battery cap. Monitor temperature and supply stability
before extended use. There is no automatic battery-driven switching until real
battery telemetry is established.

Zram uses half the detected RAM, capped at 1 GiB, and prefers lz4/lzo compression.
For 1/2/4/8 GiB RAM this gives 512 MiB/1 GiB/1 GiB/1 GiB of logical swap
capacity; it does not reserve that much RAM up front. Existing zram devices are
left alone, including kernel/distribution-created ones, so check `zramctl` and
`swapon --show`. The service does not reconfigure existing disk swap or tune
system-wide swappiness without measurement. Stop refuses to reset a device if
swapoff fails due to memory pressure.

Disable if measurements show no benefit:

```sh
sudo rc-update del pocketterm35-zram default
sudo rc-service pocketterm35-zram stop
```

The stop command may fail under memory pressure: close apps or reboot rather
than forcibly resetting an active device. No swapfile is created on microSD.
A bounded logrotate policy covers only `/var/log/pocketterm35.log` if you choose
to capture a report there; distribution logging policy is left untouched.
No routine background benchmarks, polling reports or aggressive writeback/mount
flags are installed.

## Brightness, battery and privacy

Try Fn+minus / Fn+equals / Fn+C with the original firmware. A source copy of the
[original keyboard firmware](https://github.com/black-ghost-off/pocketTerm35-keyboard-firmware/blob/HEAD/backup_orinigal_firmware/code.py)
implements these directly on the RP2040. Different firmware may differ.
Linux controls only appear when `/sys/class/backlight` contains a real device.
If brightnessctl reports permission denied, inspect the distribution's udev
rules and device permissions; don't solve this with world-writable sysfs files
or a passwordless root shell.

`pocketterm35-check` reports input, display, backlight and real battery devices.
No battery interface means the percentage is unavailable, not 0%. Collect the
firmware version and USB interface details before developing a battery bridge.
Do not flash replacement firmware just to obtain a percentage without a tested
backup and recovery path.

## GPU and performance acceptance tests

Run diagnostics **as the desktop user in the graphical session** so Wayland and
Sway environment variables are available:

```sh
pocketterm35-report > ~/pocketterm35-report.txt
```

This is read-only and bounds each subprocess to 15 seconds. Some kernel logs
may require privileges; missing tools/permissions are reported. Review the file
before sharing: device names, network interface details and kernel messages may
be private. Do not run the whole report with sudo and lose the session context.

Check for real V3D rendering in EGL/compositor information. `llvmpipe` and
`softpipe` indicate software rendering. Sway's output listing alone does not
prove GPU acceleration. Mesa packages are installed, but actual acceleration
must be verified. No environment variable forces hardware success or silently
pretends software rendering is hardware rendering.

Before calling a build usable:

1. Cold boot into Sway, unlock with 0807, launch terminal/Controls/launcher.
2. Confirm native 640×480 at scale 1, no clipped controls, correct landscape
   orientation, readable fonts and accessible bar. Check fullscreen and recovery.
3. `sudo libinput debug-events` / `sudo evtest`: all physical keys, Fn combinations,
   modifiers, USB reconnection, and touchscreen centre/corners. Confirm no mirrored
   axes or offsets before and after locking. Internal panel is mapped to HDMI-A-1.
4. Test all bar modules, hide/show/reset, all-hidden layout, fullscreen, app
   switching, software keyboard toggle and restoration of manually customized bar.
5. Test initial lock, manual lock, idle blanking, wake, failed PIN attempts and
   notifications while locked. No automatic suspend should occur.
6. Check firmware brightness keys and, if exposed, Linux brightness at 5/50/100%.
7. Compare actual battery readings and charge state on AC/unplugged. If absent,
   record it as unsupported—not a passing test.
8. Run a repeatable real workload for 15–30 minutes on AC and battery. Compare
   launch latency, memory/swap use, temperature and frequency between balanced and
   battery profiles. Inspect kernel messages for throttling, undervoltage, Goodix
   errors and USB disconnects. Do not disable protections to improve a score.
9. Confirm no dialer/SMS/contacts apps are present and that the previous-session
   symlink backup and boot-config backups exist.
10. Keep the known-good image, image checksum, package list and source hashes
    before testing updates. The rolling edge base is not a locked release.

## Themes and offline wallpapers

Controls (**Super+P**) now has a theme and wallpaper picker in the Sway session:

- Nord
- Amber on Black
- Dracula
- Tokyo Night
- Solarized Dark and Solarized Light
- Gruvbox Dark
- Catppuccin Mocha

Each palette includes four original static **640×480** wallpapers: mountains,
grid, orbits and stars. All **32 PNGs** together are about 200 KiB, install
locally and require no network access. The solid-color option avoids imagery
entirely. This is an LCD: black backgrounds do not provide OLED-style backlight
power savings. No animations or periodic wallpaper processes are added.

Themes coordinate Sway window borders/background, Waybar, Foot terminal colors,
Wofi launcher, Mako notifications and the next lock-screen background. Sizes,
font settings, hidden bar modules and keyboard shortcuts remain unchanged.
These are **palette presets**, not full GTK/icon themes: ordinary GTK apps and
other applications keep their existing themes. Shell theme selection is
intended for the PocketTerm35 Sway session, not an alternative compositor.

Examples:

```sh
pocketterm35-theme list
pocketterm35-theme apply nord
pocketterm35-theme apply amber --wallpaper solid
pocketterm35-theme apply tokyo-night --wallpaper tokyo-night-stars.png
# Mix a palette with another palette's wallpaper:
pocketterm35-theme apply dracula --wallpaper nord-mountains.png
pocketterm35-theme reset
```

Use the normal desktop user, not sudo. Sway/bar/notifications reload immediately;
open a **new terminal** to get the new terminal palette. Launcher colors update
next time it opens; an already active lock screen is not changed or unlocked.
A manual Sway background override in `~/.config/pocketterm35/sway.conf` still
wins because that file is loaded last. On wallpaper selection, choose the wallpaper palette and style independently. “Match UI palette”
automatically follows the chosen theme.

Generated files live in `~/.config/pocketterm35/theme/`, including selection.json
for persistence across logins. Personal Waybar CSS is imported before palette
colors and left untouched. On first use, an existing Foot configuration is saved
as `~/.config/pocketterm35/foot-before-theme.ini`; the new Foot config includes
that backup and the generated palette. Don't edit the managed Foot wrapper;
keep your preferences in the saved original or reset the theme before editing.
Reset restores the saved Foot configuration and default desktop colors while
retaining your personal bar settings. Mako's stable generated config returns to
the personal/default config on reset. While a palette is active it uses compact
system notification settings; personal Mako settings are not overwritten.

Wallpaper artwork is original procedural artwork dedicated to CC0; palette
names describe color schemes, not endorsements. Regenerate bundled artwork
with `python3 scripts/generate-wallpapers.py` (standard library only).

On device, test every theme for legibility, bar/launcher/notification colors,
new terminal colors and lock-screen contrast. Verify reset restores your prior
Foot settings and hidden bar modules remain hidden. Themes and wallpapers have
host-side tests, but have not been visually verified on the physical panel.

## Compact control center and custom Quick layout

Controls is now a **560×400 logical-pixel** window centered within the 640×480
screen. It reserves room for the bar and borders and uses the current monitor's
work area when smaller. Sway's floating rule matches that size. Four short tabs
keep navigation visible: **Quick, Look, Bar, Device**. Each page scrolls vertically
without a horizontal scrollbar. Two-column tiles use approximately 70-pixel
heights; buttons have at least a 30-pixel content height plus padding. Dialogs
for message details are bounded to 420×260 and scroll rather than forcing long
text beyond the screen. Controls follows the selected palette **when launched**;
reopen it after a theme change to refresh its own styling.

**Customize** is permanently visible in the header, not a removable tile.
Its switches only show/hide controls: they do not change hardware state.
Up/down buttons reorder visible Quick tiles. Every tile can be hidden—even
all of them—and **Restore default Quick layout** recovers the initial set.
Appearance, bar and device pages remain reachable; hiding a shortcut isn't a
security restriction or removal of its underlying setting.

Available Quick controls/actions:

| Control | Behaviour |
|---|---|
| Wi-Fi | Toggle NetworkManager Wi-Fi radio; not a connectivity claim |
| Bluetooth | Toggle controller power through bluetoothctl |
| Mute sound | Read and toggle the default audio output's mute state |
| Do Not Disturb | Add/remove Mako's notification-hiding mode in Sway |
| Keyboard | Toggle the on-demand software keyboard in Sway |
| Status bar | Toggle the whole Sway bar |
| Lock screen | Lock using the existing secure locker |
| Terminal | Open Foot |
| Network setup | Open nmtui in Foot |
| Appearance | Jump to theme/wallpaper selection |
| Brightness / Volume | Jump to the Device page |
| Battery info | Read real Linux battery information |
| CPU profiles | Jump to profile actions, which open explicit sudo prompts |

The catalogue is fixed and audited, not an arbitrary shell-command launcher.
Missing hardware, service permissions or session support is reported instead of
showing a fake success. Sway-only actions are disabled outside the Sway desktop. Initial Wi-Fi,
Bluetooth, mute and DND states are checked asynchronously; state queries do not
run continuous background polling. Device commands run off the GTK thread with
timeouts, so a slow radio/DBus call does not freeze scrolling or navigation.
A failed action does not claim success. The footer's **Details** button shows
complete messages on touch devices; hovering isn't required.

Layouts persist in `~/.config/pocketterm35/quick-layout.json`. Empty is valid;
unknown and duplicate IDs are discarded. Malformed JSON falls back to defaults.
To recover manually, delete just that file and reopen Controls. A normal theme
change or restart does not reset your chosen controls or order.

The **Bar** tab now supports every default module, including Apps and Controls,
plus optional **CPU usage, memory usage, temperature, backlight and Bluetooth**.
These extras are off initially and require suitable Waybar/hardware support.
They can overcrowd a 640-pixel bar: enable only useful modules. New extras are
tracked in `~/.config/waybar/pt35-extra.json`; hidden items remain in
`pt35-hidden.json`. `pocketterm35-bar reset` restores the baseline layout.

On-device layout acceptance checks:

1. Check all four pages at 640×480/scale 1, with the bar visible. No clipped
   header/footer, horizontal scrolling or off-screen buttons should occur.
2. Select all Quick tiles, scroll to the bottom, hide everything, recover with
   Customize, reorder items and restart the app to confirm persistence.
3. Check light and dark palettes, focus outlines, keyboard Tab navigation,
   unavailable-state labels and touch access to Details.
4. Test actual radio/mute states and permission failures. Verify DND hides
   banners, and disabling DND does not remove lock-screen privacy mode.
5. Try every optional bar module; hide the entire bar and recover via Super+P.
6. These dimensions and backend logic have host tests, but this sandbox has no
   GTK/display environment: final rendered sizes and touch behaviour must still
   be checked on the physical device. No screenshot/rendering test is claimed.

## Default desktop applications and font choices

The desktop build now requests these native aarch64 packages:

| App | Role |
|---|---|
| Foot | Default terminal; native Wayland and compact settings |
| PCManFM | File browser (through XWayland where needed) |
| FileZilla | FTP/SFTP client |
| qBittorrent | Graphical BitTorrent client |
| Nicotine+ | Soulseek client |
| Thunderbird | Email client |
| Telegram Desktop | Desktop messaging, not a cellular/SMS component |
| Raspberry Pi Imager | Write an OS image to a separate removable drive |

Nothing is autostarted, logged in, or configured to download/share files on your
behalf. qBittorrent is the graphical package, not a boot-time headless daemon.
Never use Imager to overwrite the running system's microSD/USB drive. It may need
a desktop authorization agent/permissions; installation is not evidence that its
privileged write path works on this image.

Recipes were checked in Alpine aports: FileZilla, qBittorrent, Thunderbird and
Telegram Desktop are in community, while **nicotine-plus and rpi-imager are in
edge/testing**. The current pmbootstrap edge channel includes Alpine testing by
default; all requested applications are installed in one transaction. Earlier
ad-hoc `@pt35testing` tags were incompatible with pmbootstrap regenerating its
repository list and have been removed. This image follows the upstream rolling
edge repository configuration; it is **not isolated from testing dependencies**.
If packages cannot resolve on aarch64, the build fails rather than omitting them.
Installing them in the first transaction includes them in the image. A full
package download, dependency resolution and GUI launch test remain unverified in
this network-restricted sandbox. Budget at least 25 GB on the build host and a
32 GB target card; these desktop applications substantially increase image size.

Package recipes:
- https://github.com/alpinelinux/aports/tree/master/community/filezilla
- https://github.com/alpinelinux/aports/tree/master/community/qbittorrent
- https://github.com/alpinelinux/aports/tree/master/community/thunderbird
- https://github.com/alpinelinux/aports/tree/master/community/telegram-desktop
- https://github.com/alpinelinux/aports/tree/master/testing/nicotine-plus
- https://github.com/alpinelinux/aports/tree/master/testing/rpi-imager

These are full desktop apps, **not certified 640×480-adaptive apps**. Some dialogs
will not fit. Use fullscreen (Super+F), window recovery (Super+R) and app-specific
compact toolbars; an external monitor may still be needed for some operations.
Do not globally scale down the whole desktop until text becomes unreadable.

### Fonts

The default font packages now include **JetBrains Mono, Hack, Fira Mono, Source
Code Pro, Inconsolata, DejaVu, Liberation and Noto**. Foot remains the default
terminal because its native Wayland rendering and compact layout suit the Pi.
Controls → **Look → Terminal font** lists actually installed font families, with
an explicit 8–14 point size selector. New terminals pick up changes; existing
terminals are not restarted. For a readable 3.5-inch display, start at 9–10 points.
Use a monospace family for terminal alignment; proportional fonts remain
selectable but are not recommended for terminals.

```sh
pocketterm35-fonts list
pocketterm35-fonts apply 'JetBrains Mono' --size 9
pocketterm35-fonts apply Hack --size 10
```

Color theme application/reset preserves the independent font preference. Existing
Foot settings and includes are retained; the font override follows includes so
it actually takes precedence. The one-time pre-font backup is
`~/.config/foot/foot.ini.before-font-choice`, with selection in
`~/.config/pocketterm35/font.json`.

**Neon80 is not bundled yet.** No verified redistributable font source/license
was found. Supply the exact font file/source and redistribution permission to
include it in the image. For personal use with a licensed TTF/OTF:

```sh
mkdir -p ~/.local/share/fonts
# Copy your licensed font file into that directory, then:
fc-cache -f
pocketterm35-fonts list
```

Reopen Controls: its actual Fontconfig family name will appear in the list.
No similarly named font is silently substituted and no unlicensed download is
performed. Font selection currently changes **Foot**, not every application.

### Application icons and labels

The Apps button/Super+D now opens a compact GTK icon grid rather than the old
Wofi text list. It follows the selected palette when opened, shows installed
visible desktop entries, and launches them through Gio (not shell expansion).
Search remains functional even when labels are hidden; Enter launches the first
match, Esc closes. Tooltips retain names for identification.

Controls → **Look → Show application icon labels** persists to
`~/.config/pocketterm35/desktop.json`. Reopen Apps after changing it. This controls
the **application grid**, not icons placed directly over the wallpaper: Sway
does not currently provide a wallpaper desktop-icon layer. PCManFM is installed
as a file browser, not forced into an unsupported Wayland desktop-manager mode.

On device: verify every requested app launches, check large dialogs and keyboard
navigation, test Imager on a spare drive only, and confirm fonts/labels survive
color theme changes and reboot. RAM-heavy apps like Thunderbird and Telegram
should not all run simultaneously on a 1–2 GB Pi without measuring memory use.

## Optional CPU overclock (experimental)

**Disabled by default.** Controls → Device offers next-boot CPU presets:

| Choice | CPU maximum request | Firmware `over_voltage` |
|---|---:|---:|
| Disable overclock | No OC override; existing boot profile still applies | No OC override |
| 1.8 GHz | 1800 MHz | 2 |
| 2.0 GHz | 2000 MHz | 6 |

These are **experimental configuration presets, not tested safe/stable settings**.
The higher-voltage 2.0 GHz option especially requires adequate cooling and stable
external power; it is not recommended for battery operation in a closed enclosure.
Overclocking may cause boot failure, overheating, data corruption, hardware damage,
and affect warranty coverage. Back up your card and have a second computer/card
reader ready. A preset may not be achievable on every Pi 4 board/firmware.

The GUI opens Foot with a normal sudo prompt. Enabling either preset additionally
requires typing **OVERCLOCK** in the terminal. No automatic reboot occurs. The
helper rejects non-Pi-4B boards, missing boot integration, conflicting explicit
CPU settings in usercfg.txt (e.g. the powersave boot profile), and measured thermal
zones already at/above 75°C. A cool idle reading does not prove thermal headroom
or adequate power. It does not measure the supply or certify cooling.

```sh
pocketterm35-overclock status          # requested next-boot settings, not live clock
sudo pocketterm35-overclock 1800       # interactive risk confirmation required
sudo pocketterm35-overclock 2000       # interactive risk confirmation required
sudo pocketterm35-overclock stock      # disable OC; manual reboot still required
```

Only CPU frequency and voltage offsets are written. GPU/RAM clocks, thermal limits,
voltage warnings and turbo protection are not modified. The tool does not set
force_turbo. The dedicated file is included at the end of every supplied boot
profile, but enabling OC refuses conflicting usercfg CPU directives. Start with
balanced/default firmware config, not the powersave boot file. Runtime battery
profiles still cap CPU speed, and a persistent battery cap can prevent reaching
an OC frequency. After boot, the balanced/performance runtime profile uses the
kernel-advertised maximum—which may now include the selected OC request.

The first dedicated-file contents are backed up once as
`pocketterm35-overclock.txt.before-overclock` on the boot partition. Re-running
image post-processing preserves an existing opt-in selection on that image;
a new image starts disabled. Custom firmware config outside the supplied files
can override/interact with this request; don't combine competing overclock tools.

**If the Pi no longer boots:** power off, put the card in another computer, open
the boot partition and replace `pocketterm35-overclock.txt` with just a comment:

```text
# Overclock disabled for recovery
```

Alternatively remove its `include pocketterm35-overclock.txt` line from usercfg.txt.
There is **no automatic rollback/watchdog recovery**. Removing the OC request
cannot repair files already corrupted by instability. Boot again at stock and
inspect logs/storage health before trying another frequency. Test progressively
under real workloads, watching temperature, frequency, undervoltage and USB errors.
No speedup, hardware safety, or on-device validation is claimed by host tests.
