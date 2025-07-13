#!/bin/bash

# Load configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../config/pi_config.sh"

echo "⬆️  Chrome Profile Sync - Upload to Raspberry Pi"
echo "=============================================="

# Ensure directories exist
ensure_directories

# Test connection to Pi
if ! test_pi_connection; then
    error "Cannot connect to Raspberry Pi. Run setup.sh first."
    exit 1
fi

# Check if local profile exists
if [ ! -d "$LOCAL_PROFILE_PATH" ]; then
    error "Local Chrome profile not found at $LOCAL_PROFILE_PATH"
    echo "Make sure Google Chrome is installed and has been run at least once."
    exit 1
fi

# Check if Chrome is running
if pgrep -f "google-chrome" > /dev/null; then
    warning "Google Chrome is running. Please close Chrome before syncing."
    read -p "Press Enter after closing Chrome to continue..."
fi

# Create backup of current profile on Pi if it exists
info "Creating backup of current profile on Raspberry Pi..."
BACKUP_NAME="pre-upload-$(date +%Y%m%d-%H%M%S)"

if ssh $SSH_OPTS "$PI_USER@$PI_HOST" "[ -d '$PI_PROFILE_PATH' ]"; then
    if ssh $SSH_OPTS "$PI_USER@$PI_HOST" "cp -r '$PI_PROFILE_PATH' '~/profile_sync/backups/$BACKUP_NAME'"; then
        success "Backup created on Pi: ~/profile_sync/backups/$BACKUP_NAME"
    else
        warning "Failed to create backup on Pi, continuing anyway..."
    fi
else
    info "No existing profile found on Pi"
fi

# Create profile directory on Pi
info "Ensuring profile directory exists on Raspberry Pi..."
ssh $SSH_OPTS "$PI_USER@$PI_HOST" "mkdir -p '$PI_PROFILE_PATH'"
ssh $SSH_OPTS "$PI_USER@$PI_HOST" "mkdir -p ~/profile_sync/backups"

# Show local profile info
info "Local profile information:"
echo "Size: $(du -sh "$LOCAL_PROFILE_PATH" | cut -f1)"
echo "Files: $(find "$LOCAL_PROFILE_PATH" -type f | wc -l)"
echo "Last modified: $(stat -c %y "$LOCAL_PROFILE_PATH")"

# Confirm upload
echo ""
echo "📊 Upload Summary:"
echo "From: $LOCAL_PROFILE_PATH"
echo "To: $PI_USER@$PI_HOST:$PI_PROFILE_PATH"
echo "Excludes: Cache files, logs, temporary data"
echo ""
read -p "Continue with upload? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Upload cancelled by user"
    exit 0
fi

# Upload profile to Pi
info "Uploading Chrome profile to Raspberry Pi..."
info "This may take a few minutes depending on profile size..."

# Use rsync to upload with exclusions
if rsync $RSYNC_OPTS \
    --exclude-from="$EXCLUDE_FILE" \
    "$LOCAL_PROFILE_PATH/" \
    "$PI_USER@$PI_HOST:$PI_PROFILE_PATH/"; then
    
    success "Profile uploaded successfully!"
    
    # Show upload statistics
    info "Upload statistics:"
    PI_SIZE=$(ssh $SSH_OPTS "$PI_USER@$PI_HOST" "du -sh '$PI_PROFILE_PATH' | cut -f1")
    PI_FILES=$(ssh $SSH_OPTS "$PI_USER@$PI_HOST" "find '$PI_PROFILE_PATH' -type f | wc -l")
    
    echo "Profile size on Pi: $PI_SIZE"
    echo "Total files on Pi: $PI_FILES"
    
    success "Chrome profile sync completed!"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Profile is now available on Raspberry Pi"
    echo "2. Download on other machines: ./download.sh"
    echo "3. To restore Pi backup if needed: ssh $PI_USER@$PI_HOST"
    
else
    error "Failed to upload profile to Raspberry Pi"
    exit 1
fi

# Log completion
log "Profile uploaded to $PI_USER@$PI_HOST" 