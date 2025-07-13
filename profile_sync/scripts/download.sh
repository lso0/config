#!/bin/bash

# Load configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../config/pi_config.sh"

echo "⬇️  Chrome Profile Sync - Download from Raspberry Pi"
echo "=================================================="

# Ensure directories exist
ensure_directories

# Test connection to Pi
if ! test_pi_connection; then
    error "Cannot connect to Raspberry Pi. Run setup.sh first."
    exit 1
fi

# Check if Chrome is running
if pgrep -f "google-chrome" > /dev/null; then
    warning "Google Chrome is running. Please close Chrome before syncing."
    read -p "Press Enter after closing Chrome to continue..."
fi

# Create backup of current profile if it exists
if [ -d "$LOCAL_PROFILE_PATH" ]; then
    info "Creating backup of current profile..."
    BACKUP_NAME="pre-download-$(date +%Y%m%d-%H%M%S)"
    
    if cp -r "$LOCAL_PROFILE_PATH" "$BACKUP_DIR/$BACKUP_NAME"; then
        success "Backup created: $BACKUP_DIR/$BACKUP_NAME"
    else
        warning "Failed to create backup, continuing anyway..."
    fi
fi

# Check if profile exists on Pi
info "Checking if profile exists on Raspberry Pi..."
if ssh $SSH_OPTS "$PI_USER@$PI_HOST" "[ -d '$PI_PROFILE_PATH' ]"; then
    success "Profile found on Raspberry Pi"
else
    error "Profile not found on Raspberry Pi at $PI_PROFILE_PATH"
    echo "Available directories on Pi:"
    ssh $SSH_OPTS "$PI_USER@$PI_HOST" "ls -la ~/profile_sync/ 2>/dev/null || echo 'No profile_sync directory found'"
    exit 1
fi

# Show profile info
info "Profile information:"
ssh $SSH_OPTS "$PI_USER@$PI_HOST" "ls -lah '$PI_PROFILE_PATH' | head -10"

# Confirm download
echo ""
echo "📊 Download Summary:"
echo "From: $PI_USER@$PI_HOST:$PI_PROFILE_PATH"
echo "To: $LOCAL_PROFILE_PATH"
echo "Excludes: Cache files, logs, temporary data"
echo ""
read -p "Continue with download? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Download cancelled by user"
    exit 0
fi

# Create local profile directory
mkdir -p "$LOCAL_PROFILE_PATH"

# Download profile from Pi
info "Downloading Chrome profile from Raspberry Pi..."
info "This may take a few minutes depending on profile size..."

# Use rsync to download with exclusions
if rsync $RSYNC_OPTS \
    --exclude-from="$EXCLUDE_FILE" \
    "$PI_USER@$PI_HOST:$PI_PROFILE_PATH/" \
    "$LOCAL_PROFILE_PATH/"; then
    
    success "Profile downloaded successfully!"
    
    # Fix permissions
    info "Fixing file permissions..."
    chmod -R u+rw "$LOCAL_PROFILE_PATH"
    
    # Show download statistics
    info "Download statistics:"
    echo "Profile size: $(du -sh "$LOCAL_PROFILE_PATH" | cut -f1)"
    echo "Total files: $(find "$LOCAL_PROFILE_PATH" -type f | wc -l)"
    echo "Directories: $(find "$LOCAL_PROFILE_PATH" -type d | wc -l)"
    
    success "Chrome profile sync completed!"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Start Google Chrome to verify profile"
    echo "2. If issues occur, restore backup: ./restore.sh"
    echo "3. To upload changes back: ./upload.sh"
    
else
    error "Failed to download profile from Raspberry Pi"
    exit 1
fi

# Log completion
log "Profile downloaded from $PI_USER@$PI_HOST" 