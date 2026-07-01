#!/bin/sh
# 01-install-pmbootstrap.sh
# Installs pmbootstrap and all dependencies for the postmarketOS build

set -e

echo "==> 01: Installing dependencies and pmbootstrap"

# 1. System dependencies
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
    echo "Warning: No known package manager found."
    echo "Please install: git python3 openssl xz-utils coreutils dosfstools e2fsprogs curl wget"
fi

# 2. pmbootstrap from Git (recommended for the latest version)
echo "==> Cloning pmbootstrap..."
if [ ! -d "$HOME/pmbootstrap" ]; then
    git clone --depth=1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git "$HOME/pmbootstrap"
else
    echo "pmbootstrap already cloned, pulling..."
    cd "$HOME/pmbootstrap" && git pull
fi

# 3. Symlink in ~/.local/bin/
mkdir -p "$HOME/.local/bin"
if [ ! -L "$HOME/.local/bin/pmbootstrap" ]; then
    ln -sf "$HOME/pmbootstrap/pmbootstrap.py" "$HOME/.local/bin/pmbootstrap"
fi

# 4. Ensure PATH is set
case :$PATH: in
    *:$HOME/.local/bin:*) ;;
    *)
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.profile"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        echo "  -> ~/.local/bin added to PATH (please run 'source ~/.profile')"
        ;;
esac

# 5. Verify
echo "==> pmbootstrap version:"
"$HOME/.local/bin/pmbootstrap" --version

echo "==> 01: Done – pmbootstrap is ready."
echo "    Next: source ~/.profile && ./02-configure-pmbootstrap.sh"
