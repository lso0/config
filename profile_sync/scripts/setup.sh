#!/bin/bash

# Load configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../config/pi_config.sh"

echo "🔧 Chrome Profile Sync - Initial Setup"
echo "======================================"

# Ensure directories exist
ensure_directories

# Check if SSH key exists
if [ ! -f "$SSH_KEY_PATH" ]; then
    info "SSH key not found. Generating new SSH key..."
    ssh-keygen -t rsa -b 4096 -C "chrome-sync-$(hostname)" -f "$SSH_KEY_PATH" -N ""
    success "SSH key generated at $SSH_KEY_PATH"
else
    info "SSH key already exists at $SSH_KEY_PATH"
fi

# Copy SSH key to Pi
info "Setting up SSH key authentication with Raspberry Pi..."
echo "You may need to enter your password for the Raspberry Pi:"

if ssh-copy-id -i "$SSH_KEY_PATH.pub" "$PI_USER@$PI_HOST"; then
    success "SSH key successfully copied to Raspberry Pi"
else
    error "Failed to copy SSH key to Raspberry Pi"
    exit 1
fi

# Test connection
if test_pi_connection; then
    success "SSH connection test passed"
else
    error "SSH connection test failed"
    exit 1
fi

# Ensure profile directory exists on Pi
info "Creating profile directory on Raspberry Pi..."
if ssh $SSH_OPTS "$PI_USER@$PI_HOST" "mkdir -p ~/profile_sync"; then
    success "Profile directory created on Pi"
else
    error "Failed to create profile directory on Pi"
    exit 1
fi

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Display configuration summary
echo ""
echo "✅ Setup Complete!"
echo "=================="
echo "Pi Host: $PI_HOST"
echo "Pi User: $PI_USER"
echo "Pi Profile Path: $PI_PROFILE_PATH"
echo "Local Profile Path: $LOCAL_PROFILE_PATH"
echo "SSH Key: $SSH_KEY_PATH"
echo "Log File: $LOG_FILE"
echo ""
echo "🚀 Next Steps:"
echo "1. Upload current profile: ./upload.sh"
echo "2. Download profile (on new machine): ./download.sh"
echo "3. Create backup: ./backup.sh"
echo "" 