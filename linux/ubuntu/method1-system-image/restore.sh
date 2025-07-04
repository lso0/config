#!/bin/bash

# Method 1: System Image Restore using dd
# This restores a complete disk image back to a target drive

set -e

# Configuration
BACKUP_DIR="/home/wgu0/backups/method1-system-image"
TARGET_DISK="/dev/nvme0n1"  # DANGER: This will overwrite the target disk!

echo "=== Ubuntu System Image Restore ==="
echo "WARNING: This will COMPLETELY OVERWRITE the target disk!"
echo "Target disk: $TARGET_DISK"

# List available backups
echo ""
echo "Available backup images:"
ls -lh "$BACKUP_DIR"/*.img 2>/dev/null || {
    echo "No backup images found in $BACKUP_DIR"
    exit 1
}

echo ""
read -p "Enter the backup image filename: " BACKUP_IMAGE
BACKUP_PATH="$BACKUP_DIR/$BACKUP_IMAGE"

if [ ! -f "$BACKUP_PATH" ]; then
    echo "Error: Backup image not found: $BACKUP_PATH"
    exit 1
fi

# Show backup info if available
INFO_FILE="$BACKUP_DIR/backup-info.txt"
if [ -f "$INFO_FILE" ]; then
    echo ""
    echo "Backup Information:"
    cat "$INFO_FILE"
fi

# Final confirmation
echo ""
echo "FINAL WARNING:"
echo "This will completely erase and overwrite: $TARGET_DISK"
echo "Source image: $BACKUP_PATH"
echo "Size: $(ls -lh "$BACKUP_PATH" | awk '{print $5}')"
echo ""
read -p "Are you absolutely sure you want to proceed? Type 'YES' to continue: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Restore cancelled."
    exit 1
fi

# Unmount any mounted partitions from target disk
echo "Unmounting any mounted partitions..."
sudo umount ${TARGET_DISK}* 2>/dev/null || true

# Start restore
echo ""
echo "Starting restore at $(date)..."
echo "This may take 2-4 hours..."

sudo dd if="$BACKUP_PATH" of="$TARGET_DISK" bs=4M status=progress conv=sync,noerror

echo ""
echo "Restore completed at $(date)"

# Verify restore
echo "Verifying restore..."
BACKUP_CHECKSUM=$(sha256sum "$BACKUP_PATH" | awk '{print $1}')
RESTORED_CHECKSUM=$(sudo sha256sum "$TARGET_DISK" | awk '{print $1}')

echo "Backup checksum:   $BACKUP_CHECKSUM"
echo "Restored checksum: $RESTORED_CHECKSUM"

if [ "$BACKUP_CHECKSUM" = "$RESTORED_CHECKSUM" ]; then
    echo "✓ Restore verification successful!"
else
    echo "✗ Restore verification failed!"
    exit 1
fi

# Update partition table
echo "Updating partition table..."
sudo partprobe "$TARGET_DISK"

# Show final disk layout
echo ""
echo "Final disk layout:"
sudo fdisk -l "$TARGET_DISK"

echo ""
echo "=== Restore Complete ==="
echo "System has been restored from: $BACKUP_PATH"
echo "You may need to reboot to complete the restore process."
echo "Completed: $(date)"

