#!/bin/bash

# Load configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../config/pi_config.sh"

echo "💾 Chrome Profile Sync - Create Backup"
echo "====================================="

# Ensure directories exist
ensure_directories

# Check if local profile exists
if [ ! -d "$LOCAL_PROFILE_PATH" ]; then
    error "Local Chrome profile not found at $LOCAL_PROFILE_PATH"
    exit 1
fi

# Check if Chrome is running
if pgrep -f "google-chrome" > /dev/null; then
    warning "Google Chrome is running. For best results, close Chrome before backing up."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Backup cancelled by user"
        exit 0
    fi
fi

# Create backup name with timestamp
BACKUP_NAME="chrome-profile-$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Show profile info
info "Profile information:"
echo "Source: $LOCAL_PROFILE_PATH"
echo "Size: $(du -sh "$LOCAL_PROFILE_PATH" | cut -f1)"
echo "Files: $(find "$LOCAL_PROFILE_PATH" -type f | wc -l)"
echo "Backup destination: $BACKUP_PATH"

# Confirm backup
echo ""
read -p "Create backup? (Y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
    info "Backup cancelled by user"
    exit 0
fi

# Create backup
info "Creating backup of Chrome profile..."
info "This may take a few minutes..."

if cp -r "$LOCAL_PROFILE_PATH" "$BACKUP_PATH"; then
    success "Backup created successfully!"
    
    # Show backup statistics
    info "Backup statistics:"
    echo "Backup size: $(du -sh "$BACKUP_PATH" | cut -f1)"
    echo "Backup location: $BACKUP_PATH"
    echo "Files backed up: $(find "$BACKUP_PATH" -type f | wc -l)"
    
    # Clean up old backups (keep last 5)
    info "Cleaning up old backups (keeping last 5)..."
    cd "$BACKUP_DIR" && ls -t | tail -n +6 | xargs -r rm -rf
    
    success "Backup completed!"
    echo ""
    echo "🚀 Backup created: $BACKUP_NAME"
    echo "To restore this backup: ./restore.sh $BACKUP_NAME"
    
else
    error "Failed to create backup"
    exit 1
fi

# Log completion
log "Backup created: $BACKUP_NAME" 