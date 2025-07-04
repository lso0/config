#!/bin/bash

# Restore system configuration from GitHub backup

set -e

echo "=== Restoring System Configuration ==="

# Install packages
echo "Installing packages..."
sudo apt update

# Restore manually installed packages
if [ -f "manually-installed.txt" ]; then
    sudo apt install -y $(cat manually-installed.txt | tr '\n' ' ')
fi

# Restore all packages (this might take a while)
if [ -f "installed-packages.txt" ]; then
    echo "Restoring all packages..."
    sudo dpkg --set-selections < installed-packages.txt
    sudo apt-get dselect-upgrade -y
fi

# Restore snap packages
if [ -f "snap-packages.txt" ] && [ -s "snap-packages.txt" ]; then
    echo "Installing snap packages..."
    while read snapname version rev tracking publisher notes; do
        if [ "$snapname" != "Name" ] && [ "$snapname" != "No" ]; then
            sudo snap install "$snapname" || true
        fi
    done < snap-packages.txt
fi

# Restore config files
echo "Restoring configuration files..."
if [ -d "configs" ]; then
    sudo cp configs/fstab /etc/ 2>/dev/null || true
    sudo cp configs/hosts /etc/ 2>/dev/null || true
    sudo cp configs/hostname /etc/ 2>/dev/null || true
    sudo cp configs/timezone /etc/ 2>/dev/null || true
fi

# Restore user configs
if [ -d "user-configs" ]; then
    cp user-configs/.bashrc ~/ 2>/dev/null || true
    cp user-configs/.profile ~/ 2>/dev/null || true
    cp user-configs/.gitconfig ~/ 2>/dev/null || true
    
    if [ -f "user-configs/ssh-config" ]; then
        mkdir -p ~/.ssh
        cp user-configs/ssh-config ~/.ssh/config
        chmod 600 ~/.ssh/config
    fi
fi

# Restore crontabs
if [ -f "user-crontab.txt" ] && [ -s "user-crontab.txt" ]; then
    crontab user-crontab.txt
fi

echo "=== Configuration Restore Complete ==="
echo "Note: You may need to:"
echo "1. Reboot the system"
echo "2. Reconfigure hardware-specific settings"
echo "3. Re-enter passwords and API keys"
echo "4. Restore your personal files from backup"
