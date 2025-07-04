#!/bin/bash

# Method 2: File System Backup using rsync
# This copies all files while excluding system-specific directories

set -e

# Configuration
BACKUP_DIR="/home/wgu0/backups/method2-filesystem"
BACKUP_NAME="ubuntu-filesystem-$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d_%H%M%S).log"

echo "=== Ubuntu File System Backup (rsync) ==="
echo "Started: $(date)"
echo "Destination: $BACKUP_DIR/$BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Define exclusions (directories that shouldn't be backed up)
EXCLUDES=(
    "/dev/*"
    "/proc/*"
    "/sys/*"
    "/tmp/*"
    "/run/*"
    "/mnt/*"
    "/media/*"
    "/lost+found"
    "/swapfile"
    "/var/cache/*"
    "/var/tmp/*"
    "/var/log/*"
    "/home/*/.cache/*"
    "/home/*/.local/share/Trash/*"
    "/snap/*/common/.cache/*"
    "$BACKUP_DIR"
)

# Create exclude file
EXCLUDE_FILE="$BACKUP_DIR/exclude-list.txt"
printf '%s\n' "${EXCLUDES[@]}" > "$EXCLUDE_FILE"

echo "Exclusions saved to: $EXCLUDE_FILE"
echo "Starting backup..."

# Start backup with rsync
rsync -aAXHv \
    --progress \
    --exclude-from="$EXCLUDE_FILE" \
    --log-file="$LOG_FILE" \
    / "$BACKUP_DIR/$BACKUP_NAME/" 2>&1 | tee -a "$LOG_FILE"

# Create system info
echo "Creating system information..."
cat > "$BACKUP_DIR/$BACKUP_NAME/BACKUP_INFO.txt" << EOF
Ubuntu File System Backup
=========================
Date: $(date)
Method: rsync
Backup Directory: $BACKUP_NAME

System Information:
$(uname -a)
$(lsb_release -a 2>/dev/null)

Disk Information:
$(df -h)

Block Devices:
$(lsblk)

Network Configuration:
$(ip addr show)

Installed Packages:
$(dpkg --get-selections | head -20)
... (full list in packages.txt)

Kernel Modules:
$(lsmod | head -10)
... (full list in modules.txt)
EOF

# Save detailed system info
dpkg --get-selections > "$BACKUP_DIR/$BACKUP_NAME/packages.txt"
lsmod > "$BACKUP_DIR/$BACKUP_NAME/modules.txt"
cp /etc/fstab "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || true
cp /boot/grub/grub.cfg "$BACKUP_DIR/$BACKUP_NAME/" 2>/dev/null || true

# Create restore instructions
cat > "$BACKUP_DIR/$BACKUP_NAME/RESTORE_INSTRUCTIONS.md" << 'EOF'
# File System Restore Instructions

## Prerequisites
1. Fresh Ubuntu installation with same or newer version
2. Root access to target system
3. Network connectivity

## Restore Steps

### 1. Prepare Target System
```bash
# Boot from Ubuntu live USB/CD
# Mount target root partition
sudo mount /dev/sdXY /mnt
sudo mount /dev/sdXZ /mnt/boot/efi  # if separate EFI partition
```

### 2. Copy Files
```bash
# Copy all files from backup
sudo rsync -aAXHv /path/to/backup/ /mnt/

# Recreate essential directories
sudo mkdir -p /mnt/{dev,proc,sys,tmp,run,mnt,media}
```

### 3. Configure System
```bash
# Chroot into restored system
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo chroot /mnt

# Update fstab if needed
nano /etc/fstab

# Reinstall GRUB bootloader
grub-install /dev/sdX
update-grub

# Update initramfs
update-initramfs -u
```

### 4. Final Steps
```bash
# Exit chroot
exit

# Unmount filesystems
sudo umount /mnt/dev /mnt/proc /mnt/sys
sudo umount /mnt/boot/efi
sudo umount /mnt

# Reboot
reboot
```

## Notes
- Adjust device names (/dev/sdX) according to your system
- May need to update network configuration
- Check and update user passwords if needed
- Reinstall hardware-specific drivers if moving to different hardware
EOF

# Calculate backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR/$BACKUP_NAME" | cut -f1)
echo "Backup size: $BACKUP_SIZE" | tee -a "$LOG_FILE"

echo ""
echo "=== Backup Complete ==="
echo "Backup location: $BACKUP_DIR/$BACKUP_NAME"
echo "Backup size: $BACKUP_SIZE"
echo "Log file: $LOG_FILE"
echo "Exclude list: $EXCLUDE_FILE"
echo "Completed: $(date)"

