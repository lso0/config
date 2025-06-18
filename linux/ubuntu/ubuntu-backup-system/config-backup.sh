#!/bin/bash

# Configuration Backup - Store system settings in GitHub
# This captures configuration, not files

set -e

CONFIG_DIR="system-config"
mkdir -p "$CONFIG_DIR"

echo "=== Capturing System Configuration ==="

# Package lists
echo "Capturing installed packages..."
dpkg --get-selections > "$CONFIG_DIR/installed-packages.txt"
apt-mark showmanual > "$CONFIG_DIR/manually-installed.txt"
snap list > "$CONFIG_DIR/snap-packages.txt" 2>/dev/null || echo "No snap packages" > "$CONFIG_DIR/snap-packages.txt"

# System information
echo "Capturing system info..."
uname -a > "$CONFIG_DIR/system-info.txt"
lsb_release -a > "$CONFIG_DIR/distribution-info.txt" 2>/dev/null
lscpu > "$CONFIG_DIR/cpu-info.txt"
free -h > "$CONFIG_DIR/memory-info.txt"
lsblk > "$CONFIG_DIR/disk-layout.txt"
ip addr show > "$CONFIG_DIR/network-interfaces.txt"

# Configuration files (copy important ones)
echo "Copying configuration files..."
mkdir -p "$CONFIG_DIR/configs"

# Copy key config files (small text files only)
cp /etc/fstab "$CONFIG_DIR/configs/" 2>/dev/null || echo "No fstab"
cp /etc/hosts "$CONFIG_DIR/configs/" 2>/dev/null || echo "No custom hosts"
cp /etc/hostname "$CONFIG_DIR/configs/" 2>/dev/null || echo "No hostname"
cp /etc/timezone "$CONFIG_DIR/configs/" 2>/dev/null || echo "No timezone"

# User configurations (home directory settings)
mkdir -p "$CONFIG_DIR/user-configs"
cp ~/.bashrc "$CONFIG_DIR/user-configs/" 2>/dev/null || echo "No .bashrc"
cp ~/.profile "$CONFIG_DIR/user-configs/" 2>/dev/null || echo "No .profile"
cp ~/.gitconfig "$CONFIG_DIR/user-configs/" 2>/dev/null || echo "No .gitconfig"

# SSH config (without private keys!)
if [ -f ~/.ssh/config ]; then
    cp ~/.ssh/config "$CONFIG_DIR/user-configs/ssh-config" 2>/dev/null || true
fi

# Crontabs
crontab -l > "$CONFIG_DIR/user-crontab.txt" 2>/dev/null || echo "No user crontab"
sudo crontab -l > "$CONFIG_DIR/root-crontab.txt" 2>/dev/null || echo "No root crontab"

# Services
systemctl list-unit-files --state=enabled > "$CONFIG_DIR/enabled-services.txt"
systemctl list-units --type=service --state=running > "$CONFIG_DIR/running-services.txt"

# Create restore script
cat > "$CONFIG_DIR/RESTORE-CONFIG.sh" << 'EOF'
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
EOF

chmod +x "$CONFIG_DIR/RESTORE-CONFIG.sh"

echo "=== Configuration Backup Complete ==="
echo "Files stored in: $CONFIG_DIR/"
echo "To commit to GitHub:"
echo "  git add $CONFIG_DIR"
echo "  git commit -m 'Add system configuration backup'"
echo "  git push"

