# postmarketOS fuer Waveshare PocketTerm35 + Raspberry Pi 5

> **User:** pmos | **PIN:** 5115 | **UI:** Phosh | **Display:** 640x480

Dieses Repository enthaelt eine automatisierte Build-Pipeline, um ein
postmarketOS-Image fuer das **Waveshare PocketTerm35** mit **Raspberry Pi 5**
zu bauen. Das Image beinhaltet alle notwendigen Device-Tree-Overlays,
Display-Konfigurationen und Undervoltage-Schutzmassnahmen.

---

## Projektstruktur

```
rpmos/
├── README.md                       # Diese Dokumentation
├── scripts/
│   ├── 00-run-all.sh               # Alle Schritte automatisch (01-05)
│   ├── 01-install-pmbootstrap.sh   # Dependencies + pmbootstrap installieren
│   ├── 02-configure-pmbootstrap.sh # pmbootstrap init (RPi5, Phosh, pmos)
│   ├── 03-prepare-dtbos.sh         # Waveshare DTBOs downloaden/entpacken
│   ├── 04-build-image.sh           # postmarketOS Image bauen
│   └── 05-post-process.sh          # Image konfigurieren (User, configs, etc.)
├── configs/
│   ├── config.txt                  # Standard-Konfiguration (balanced)
│   ├── config.txt.powersave        # Untertaktet – kein Undervoltage
│   ├── config.txt.balanced         # Ausgewogen – Standard
│   └── config.txt.performance      # Volle Leistung – nur am Netzteil
├── dtbos/                          # Waveshare .dtbo Dateien (automatisch)
└── images/                         # Output: postmarketOS Images
    └── postmarketOS-latest.img     # Symlink auf letztes Build
```

---

## Schnellstart

### Voraussetzungen

- **Linux** x86_64 (pmbootstrap unterstuetzt nur Linux)
- **~10 GB** freier Speicher (fuer Build-Chroots)
- **2+ GB RAM** empfohlen
- **Schnelle Internetverbindung** (Erst-Build laedt ~1-2 GB)

### Build ausfuehren

```bash
# 1. Alle Skripte ausfuehren
cd rpmos
sudo ./scripts/00-run-all.sh
```

Oder Schritt fuer Schritt:

```bash
# 2. Oder manuell
cd rpmos
./scripts/01-install-pmbootstrap.sh
source ~/.profile
./scripts/02-configure-pmbootstrap.sh
./scripts/03-prepare-dtbos.sh
./scripts/04-build-image.sh
sudo ./scripts/05-post-process.sh
```

### Image flashen (SD-Karte oder USB)

```bash
# Geraet ermitteln (VORSICHT!)
lsblk

# Image flashen
sudo dd if=images/postmarketOS-latest.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### Image auf NVMe flashen (PocketTerm35)

```bash
# Automatisch (erkennt angeschlossene NVMe)
sudo ./scripts/06-flash-nvme.sh

# Oder manuell
sudo ./scripts/06-flash-nvme.sh /dev/nvme0n1
```

Das Script zeigt eine Sicherheitsabfrage bevor es schreibt und
prueft ob das Image auf den NVMe passt.

---

## Display-Konfiguration (640x480)

Das PocketTerm35 hat ein **3.5" IPS-Display mit 640x480 Pixeln**,
angeschlossen ueber den **DPI (Display Parallel Interface)** GPIO-Pinhead.

Die config.txt verwendet:
- `waveshare-35dpi-4b` / `waveshare-35dpi-5b` – DPI-Timings
- `hdmi_cvt=640 480 60 6 0 0 0` – Custom Mode
- `framebuffer_width=640` / `framebuffer_height=480` – Framebuffer

**DTBO-Herkunft:** Die Overlays werden von Waveshare bereitgestellt
(https://files.waveshare.com/wiki/common/3.5HDMI_E_DTBO.zip) und
automatisch von Script 03 heruntergeladen.

---

## Undervoltage-Warnungen

Der RPi5 ist bekannt fuer **Undervoltage-Warnungen** (Blitz-Symbol),
wenn die Spannung unter 4.65V faellt. Das PocketTerm35 wird ueber eine
integrierte Batterie versorgt, die bei Last nicht immer ausreichend
stabil ist.

### Loesungen im Image

**1. CPU-Takt reduzieren (in config.txt)**

| Profil | arm_freq | core_freq | sdram_freq | Wann? |
|--------|----------|-----------|------------|-------|
| `powersave` | 1500 MHz | 400 MHz | 3000 MHz | Batteriebetrieb |
| `balanced` | 1800 MHz | 600 MHz | 3500 MHz | Standard |
| `performance` | 2400 MHz | 700 MHz | 4267 MHz | Nur mit 27W PD-Netzteil |

**Profil wechseln:** Die config.txt auf der Boot-Partition austauschen:

```bash
# SD-Karte mounten
sudo mount /dev/sdX1 /mnt/boot

# Profil wechseln
sudo cp /mnt/boot/config.txt.powersave /mnt/boot/config.txt

# Oder von einem anderen Profil
sudo cp /mnt/boot/config.txt.balanced /mnt/boot/config.txt

sudo umount /mnt/boot
```

**2. Avoid Warnings**
`avoid_warnings=2` unterdrueckt die visuellen Warnungen.

**3. Hardware-Tipps**
- Hochwertiges USB-C Kabel (5A rated) verwenden
- 27W+ USB-PD Netzteil (official RPi5 power supply empfohlen)
- Keine stromhungrigen USB-Geraete am PocketTerm35 im Batteriebetrieb
- Das offizielle RPi5 Netzteil ist fuer stabilen Betrieb notwendig

---

## Benutzerkonfiguration

| Eigenschaft | Wert |
|-------------|------|
| Username | `pmos` |
| Passwort/PIN | `5115` |
| Shell | `/bin/bash` |
| Autologin | Phosh startet automatisch |

Nach dem ersten Boot das Passwort aendern:
```bash
passwd
```

---

## Troubleshooting

### Keyboard funktioniert nicht (RP2040 I2C)

Der Tastatur-Controller kommuniziert via I2C. Pruefe:

```bash
# I2C-Bus erkennen
i2cdetect -l

# RP2040 finden (Adresse 0x15 oder 0x17)
i2cdetect -y 1
```

### Display bleibt schwarz

1. Pruefe ob die DTBOs in `/boot/overlays/` vorhanden sind
2. HDMI-Kabel abziehen (das Display laeuft ueber GPIO/DPI)
3. Anderes Profil versuchen (`config.txt.balanced` statt `config.txt`)

### Phosh ist zu klein / zu gross

```bash
# Zoom anpassen
gsettings set org.gnome.desktop.interface text-scaling-factor 1.5

# Oder Monitor-Skalierung
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
```

---

## Build-Details

### Verwendete Software

| Komponente | Version |
|------------|---------|
| postmarketOS | edge / v24.12 |
| pmbootstrap | latest (git) |
| UI | phosh (Phosh Shell + phoc) |
| Kernel | linux-rpi (Alpine/RPi) |
| Init | OpenRC |

### Benoetigte Pakete auf dem Build-Host

- git, python3, openssl
- xz-utils (fuer Image-Kompression)
- dosfstools, e2fsprogs (fuer Loop-Mount)
- curl / wget (fuer DTBO-Download)

### Bekannte Einschraenkungen

- `waveshare-35dpi-4b/5b` Overlays sind ggf. nicht im mainline Kernel
  enthalten – sie werden separat von Waveshare bezogen
- Phosh ist fuer 640x480 nicht ideal optimiert – Skalierung manuell anpassen
- Der erste Build kann 30-120 Minuten dauern

---

## Lizenz

GPL-3.0 (wie postmarketOS)

---

## Links

- [Waveshare PocketTerm35 Wiki](https://docs.waveshare.com/PocketTerm35/)
- [postmarketOS Wiki](https://wiki.postmarketos.org/)
- [pmbootstrap Repository](https://gitlab.postmarketos.org/postmarketOS/pmbootstrap)
- [RPi5 config.txt Dokumentation](https://www.raspberrypi.com/documentation/computers/config_txt.html)
