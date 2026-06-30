#!/bin/sh
# 01-install-pmbootstrap.sh
# Installiert pmbootstrap und alle Abhaengigkeiten fuer den postmarketOS Build

set -e

echo "==> 01: Installiere Abhaengigkeiten und pmbootstrap"

# 1. System-Abhaengigkeiten
if command -v apt >/dev/null 2>&1; then
    sudo apt update
    sudo apt install -y git python3 python3-pip openssl xz-utils \
                        coreutils dosfstools e2fsprogs util-linux curl wget
elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --needed git python python-pip openssl xz \
                          coreutils dosfstools e2fsprogs util-linux curl wget
elif command -v apk >/dev/null 2>&1; then
    sudo apk add git python3 py3-pip openssl xz coreutils \
                  dosfstools e2fsprogs util-linux curl wget
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git python3 python3-pip openssl xz \
                        coreutils dosfstools e2fsprogs util-linux curl wget
else
    echo "Warnung: Kein bekannter Paketmanager gefunden."
    echo "Bitte installiere: git python3 openssl xz-utils coreutils dosfstools e2fsprogs curl wget"
fi

# 2. pmbootstrap von Git (empfohlen fuer aktuellste Version)
echo "==> Klone pmbootstrap..."
if [ ! -d "$HOME/pmbootstrap" ]; then
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$HOME/pmbootstrap"
else
    echo "pmbootstrap bereits geklont, pull..."
    cd "$HOME/pmbootstrap" && git pull
fi

# 3. Symlink in ~/.local/bin/
mkdir -p "$HOME/.local/bin"
if [ ! -L "$HOME/.local/bin/pmbootstrap" ]; then
    ln -sf "$HOME/pmbootstrap/pmbootstrap.py" "$HOME/.local/bin/pmbootstrap"
fi

# 4. PATH sicherstellen
case :$PATH: in
    *:$HOME/.local/bin:*) ;;
    *)
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "  -> ~/.local/bin zum PATH hinzugefuegt (bitte 'source ~/.profile' ausfuehren)"
        ;;
esac

# 5. Pruefen
echo "==> pmbootstrap version:"
"$HOME/.local/bin/pmbootstrap" --version

echo "==> 01: Fertig – pmbootstrap ist bereit."
echo "    Starte danach: source ~/.profile && ./02-configure-pmbootstrap.sh"
