#!/bin/bash

# Load configuration
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/../config/pi_config.sh"

echo "🔄 Chrome Profile Sync - Restore from Backup"
echo "==========================================="

# Ensure directories exist
ensure_directories

# Function to list available backups
list_backups() {
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        cd "$BACKUP_DIR" && ls -lt | grep ^d | awk '{print $9, $6, $7, $8}' | head -10
    else
        echo "No backups found in $BACKUP_DIR"
    fi
}

# Check if backup name provided as argument
if [ $# -eq 1 ]; then
    BACKUP_NAME="$1"
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
else
    # Show available backups
    list_backups
    echo ""
    echo "Usage: $0 <backup_name>"
    echo "Example: $0 chrome-profile-20240711-143000"
    exit 1
fi

# Check if backup exists
if [ ! -d "$BACKUP_PATH" ]; then
    error "Backup not found: $BACKUP_PATH"
    echo ""
    list_backups
    exit 1
fi

# Check if Chrome is running
if pgrep -f "google-chrome" > /dev/null; then
    warning "Google Chrome is running. Please close Chrome before restoring."
    read -p "Press Enter after closing Chrome to continue..."
fi

# Show backup info
info "Backup information:"
echo "Backup: $BACKUP_NAME"
echo "Path: $BACKUP_PATH"
echo "Size: $(du -sh "$BACKUP_PATH" | cut -f1)"
echo "Files: $(find "$BACKUP_PATH" -type f | wc -l)"
echo "Created: $(stat -c %y "$BACKUP_PATH")"

# Create backup of current profile before restore
if [ -d "$LOCAL_PROFILE_PATH" ]; then
    info "Creating backup of current profile before restore..."
    CURRENT_BACKUP_NAME="pre-restore-$(date +%Y%m%d-%H%M%S)"
    CURRENT_BACKUP_PATH="$BACKUP_DIR/$CURRENT_BACKUP_NAME"
    
    if cp -r "$LOCAL_PROFILE_PATH" "$CURRENT_BACKUP_PATH"; then
        success "Current profile backed up to: $CURRENT_BACKUP_NAME"
    else
        warning "Failed to backup current profile, continuing anyway..."
    fi
fi

# Confirm restore
echo ""
echo "⚠️  WARNING: This will replace your current Chrome profile!"
echo "From backup: $BACKUP_NAME"
echo "To: $LOCAL_PROFILE_PATH"
echo ""
read -p "Continue with restore? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Restore cancelled by user"
    exit 0
fi

# Remove current profile
if [ -d "$LOCAL_PROFILE_PATH" ]; then
    info "Removing current profile..."
    rm -rf "$LOCAL_PROFILE_PATH"
fi

# Restore from backup
info "Restoring Chrome profile from backup..."
info "This may take a few minutes..."

if cp -r "$BACKUP_PATH" "$LOCAL_PROFILE_PATH"; then
    success "Profile restored successfully!"
    
    # Fix permissions
    info "Fixing file permissions..."
    chmod -R u+rw "$LOCAL_PROFILE_PATH"
    
    # Show restore statistics
    info "Restore statistics:"
    echo "Restored size: $(du -sh "$LOCAL_PROFILE_PATH" | cut -f1)"
    echo "Restored files: $(find "$LOCAL_PROFILE_PATH" -type f | wc -l)"
    
    success "Chrome profile restore completed!"
    echo ""
    echo "🚀 Profile restored from: $BACKUP_NAME"
    echo "1. Start Google Chrome to verify profile"
    echo "2. If issues occur, restore another backup"
    echo "3. Current profile backed up as: $CURRENT_BACKUP_NAME"
    
else
    error "Failed to restore profile from backup"
    exit 1
fi

# Log completion
log "Profile restored from backup: $BACKUP_NAME" 