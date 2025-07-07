#!/bin/bash

# Method 1: Complete System Image Backup using dd
# This creates a bit-for-bit copy of the entire disk

set -e

# Configuration
BACKUP_DIR="/home/wgu0/backups/method1-system-image"
BACKUP_FILE="ubuntu-system-$(date +%Y%m%d_%H%M%S).img"
SOURCE_DISK="/dev/nvme0n1"
LOG_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d_%H%M%S).log"

echo "=== Ubuntu System Image Backup ==="
echo "Started: $(date)"
echo "Source: $SOURCE_DISK"
echo "Destination: $BACKUP_DIR/$BACKUP_FILE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check available space
echo "Checking disk space..."
df -h "$BACKUP_DIR"

# Get disk info
echo "Source disk information:"
sudo fdisk -l "$SOURCE_DISK"

# Confirm backup
echo ""
echo "WARNING: This will create a full disk image (~954GB)"
echo "Estimated time: 2-4 hours depending on disk speed"
echo ""
read -p "Continue with backup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Backup cancelled."
    exit 1
fi

# Start backup with progress
echo "Starting backup at $(date)..."
echo "Creating image: $BACKUP_DIR/$BACKUP_FILE" | tee -a "$LOG_FILE"

sudo dd if="$SOURCE_DISK" of="$BACKUP_DIR/$BACKUP_FILE" bs=4M status=progress conv=sync,noerror 2>&1 | tee -a "$LOG_FILE"

# Verify backup
echo "Backup completed at $(date)" | tee -a "$LOG_FILE"
echo "Verifying backup integrity..." | tee -a "$LOG_FILE"

# Get file size and checksum
BACKUP_SIZE=$(ls -lh "$BACKUP_DIR/$BACKUP_FILE" | awk '{print $5}')
echo "Backup file size: $BACKUP_SIZE" | tee -a "$LOG_FILE"

# Calculate checksums (this may take a while)
echo "Calculating checksums..." | tee -a "$LOG_FILE"
SOURCE_CHECKSUM=$(sudo sha256sum "$SOURCE_DISK" | awk '{print $1}')
BACKUP_CHECKSUM=$(sha256sum "$BACKUP_DIR/$BACKUP_FILE" | awk '{print $1}')

echo "Source checksum:  $SOURCE_CHECKSUM" | tee -a "$LOG_FILE"
echo "Backup checksum:  $BACKUP_CHECKSUM" | tee -a "$LOG_FILE"

if [ "$SOURCE_CHECKSUM" = "$BACKUP_CHECKSUM" ]; then
    echo "✓ Backup verification successful!" | tee -a "$LOG_FILE"
else
    echo "✗ Backup verification failed!" | tee -a "$LOG_FILE"
    exit 1
fi

# Create info file
cat > "$BACKUP_DIR/backup-info.txt" << EOF
Ubuntu System Image Backup
==========================
Date: $(date)
Source: $SOURCE_DISK
Backup File: $BACKUP_FILE
Size: $BACKUP_SIZE
Checksum: $BACKUP_CHECKSUM

System Information:
$(uname -a)
$(lsb_release -a 2>/dev/null)

Disk Layout:
$(sudo fdisk -l "$SOURCE_DISK")
EOF

echo ""
echo "=== Backup Complete ==="
echo "Backup file: $BACKUP_DIR/$BACKUP_FILE"
echo "Log file: $LOG_FILE"
echo "Info file: $BACKUP_DIR/backup-info.txt"
echo "Completed: $(date)"

