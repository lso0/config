#!/bin/bash

# Quick Restore - One command to restore system from GitHub
# Run this on a fresh Ubuntu installation

set -e

echo "=== Ubuntu Quick Restore from GitHub ==="
echo "This will:"
echo "1. Install git and gh CLI"
echo "2. Clone the backup repository"  
echo "3. Restore system configuration"
echo "4. Reinstall all packages"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

# Install required tools
echo "Installing git and gh CLI..."
sudo apt update
sudo apt install -y git

# Install GitHub CLI
if ! command -v gh &> /dev/null; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
    sudo apt install -y gh
fi

# Clone the repository
echo "Cloning backup repository..."
if [ ! -d "ubuntu-backup-system" ]; then
    git clone https://github.com/lso0/ubuntu-backup-system.git
fi

cd ubuntu-backup-system

# Restore configuration
echo "Restoring system configuration..."
cd system-config
./RESTORE-CONFIG.sh

echo ""
echo "=== Quick Restore Complete! ==="
echo ""
echo "✅ System configuration restored"
echo "✅ All packages reinstalled"
echo "✅ Services configured"
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. Check all applications are working"
echo "3. Restore personal files if needed"
echo ""
echo "Your Ubuntu system should now be restored to its previous state!"

