# postmarketOS for Waveshare PocketTerm35 + Raspberry Pi 5

> **User:** pmos | **PIN:** 5115 | **UI:** Phosh | **Display:** 640x480

This repository contains an automated build pipeline to create a
postmarketOS image for the **Waveshare PocketTerm35** with **Raspberry Pi 5**.
The image includes all required Device Tree Overlays,
display configurations, and undervoltage protection measures.

---

## Project Structure

```
rpmos/
├── README.md                       # This documentation
├── scripts/
│   ├── 00-run-all.sh               # Run all steps automatically (01-05)
│   ├── 01-install-pmbootstrap.sh   # Install dependencies + pmbootstrap
│   ├── 02-configure-pmbootstrap.sh # pmbootstrap init (RPi5, Phosh, pmos)
│   ├── 03-prepare-dtbos.sh         # Download/extract Waveshare DTBOs
│   ├── 04-build-image.sh           # Build postmarketOS image
│   └── 05-post-process.sh          # Configure image (user, configs, etc.)
├── configs/
│   ├── config.txt                  # Default configuration (balanced)
│   ├── config.txt.powersave        # Underclocked – no undervoltage
│   ├── config.txt.balanced         # Balanced – default
│   └── config.txt.performance      # Full performance – power supply only
├── dtbos/                          # Waveshare .dtbo files (auto-downloaded)
└── images/                         # Output: postmarketOS images
    └── postmarketOS-latest.img     # Symlink to latest build
```

---

## Quick Start

### Prerequisites

- **Linux** x86_64 (pmbootstrap supports Linux only)
- **~10 GB** free disk space (for build chroots)
- **2+ GB RAM** recommended
- **Fast internet connection** (first build downloads ~1-2 GB)

### Running the Build

```bash
# 1. Run all scripts
cd rpmos
sudo ./scripts/00-run-all.sh
```

Or step by step:

```bash
# 2. Or manually
cd rpmos
./scripts/01-install-pmbootstrap.sh
source ~/.profile
./scripts/02-configure-pmbootstrap.sh
./scripts/03-prepare-dtbos.sh
./scripts/04-build-image.sh
sudo ./scripts/05-post-process.sh
```

### Flashing the Image (SD card or USB)

```bash
# Identify device (CAUTION!)
lsblk

# Flash image
sudo dd if=images/postmarketOS-latest.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### Flashing the Image to NVMe (PocketTerm35)

```bash
# Automatic (detects connected NVMe)
sudo ./scripts/06-flash-nvme.sh

# Or manually
sudo ./scripts/06-flash-nvme.sh /dev/nvme0n1
```

The script shows a confirmation prompt before writing and
checks whether the image fits on the NVMe drive.

---

## Display Configuration (640x480)

The PocketTerm35 has a **3.5" IPS display with 640x480 pixels**,
connected via the **DPI (Display Parallel Interface)** GPIO pinheader.

The config.txt uses:
- `waveshare-35dpi-4b` / `waveshare-35dpi-5b` – DPI timings
- `hdmi_cvt=640 480 60 6 0 0 0` – Custom mode
- `framebuffer_width=640` / `framebuffer_height=480` – Framebuffer

**DTBO source:** The overlays are provided by Waveshare
(https://files.waveshare.com/wiki/common/3.5HDMI_E_DTBO.zip) and
are downloaded automatically by script 03.

---

## Undervoltage Warnings

The RPi5 is known for **undervoltage warnings** (lightning bolt symbol)
when voltage drops below 4.65V. The PocketTerm35 is powered by an
integrated battery, which is not always sufficiently stable under load.

### Solutions in the Image

**1. Reduce CPU clock (in config.txt)**

| Profile | arm_freq | core_freq | sdram_freq | When? |
|---------|----------|-----------|------------|-------|
| `powersave` | 1500 MHz | 400 MHz | 3000 MHz | Battery operation |
| `balanced` | 1800 MHz | 600 MHz | 3500 MHz | Default |
| `performance` | 2400 MHz | 700 MHz | 4267 MHz | 27W PD power supply only |

**Switching profiles:** Replace config.txt on the boot partition:

```bash
# Mount SD card
sudo mount /dev/sdX1 /mnt/boot

# Switch profile
sudo cp /mnt/boot/config.txt.powersave /mnt/boot/config.txt

# Or from another profile
sudo cp /mnt/boot/config.txt.balanced /mnt/boot/config.txt

sudo umount /mnt/boot
```

**2. Avoid Warnings**
`avoid_warnings=2` suppresses the visual warnings.

**3. Hardware Tips**
- Use a high-quality USB-C cable (5A rated)
- 27W+ USB-PD power supply (official RPi5 power supply recommended)
- No power-hungry USB devices on the PocketTerm35 during battery operation
- The official RPi5 power supply is required for stable operation

---

## User Configuration

| Property | Value |
|----------|-------|
| Username | `pmos` |
| Password/PIN | `5115` |
| Shell | `/bin/bash` |
| Autologin | Phosh starts automatically |

Change the password after the first boot:
```bash
passwd
```

---

## Troubleshooting

### Keyboard not working (RP2040 I2C)

The keyboard controller communicates via I2C. Check:

```bash
# Detect I2C bus
i2cdetect -l

# Find RP2040 (address 0x15 or 0x17)
i2cdetect -y 1
```

### Display stays black

1. Check if DTBOs are present in `/boot/overlays/`
2. Unplug HDMI cable (the display runs via GPIO/DPI)
3. Try a different profile (`config.txt.balanced` instead of `config.txt`)

### Phosh is too small / too large

```bash
# Adjust zoom
gsettings set org.gnome.desktop.interface text-scaling-factor 1.5

# Or monitor scaling
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
```

---

## Build Details

### Software Used

| Component | Version |
|-----------|---------|
| postmarketOS | edge / v24.12 |
| pmbootstrap | latest (git) |
| UI | phosh (Phosh Shell + phoc) |
| Kernel | linux-rpi (Alpine/RPi) |
| Init | OpenRC |

### Required Packages on the Build Host

- git, python3, openssl
- xz-utils (for image compression)
- dosfstools, e2fsprogs (for loop mount)
- curl / wget (for DTBO download)

### Known Limitations

- `waveshare-35dpi-4b/5b` overlays may not be included in the mainline kernel
  – they are obtained separately from Waveshare
- Phosh is not ideally optimized for 640x480 – adjust scaling manually
- The first build can take 30-120 minutes

---

## License

GPL-3.0 (like postmarketOS)

---

## Links

- [Waveshare PocketTerm35 Wiki](https://docs.waveshare.com/PocketTerm35/)
- [postmarketOS Wiki](https://wiki.postmarketos.org/)
- [pmbootstrap Repository](https://gitlab.postmarketos.org/postmarketOS/pmbootstrap)
- [RPi5 config.txt Documentation](https://www.raspberrypi.com/documentation/computers/config_txt.html)
