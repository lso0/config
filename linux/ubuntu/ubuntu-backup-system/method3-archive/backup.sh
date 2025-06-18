#!/bin/bash

# Method 3: Archive Backup using tar
# This creates compressed archives of the system

set -e

# Configuration
BACKUP_DIR="/home/wgu0/backups/method3-archive"
BACKUP_NAME="ubuntu-archive-$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d_%H%M%S).log"

echo "=== Ubuntu Archive Backup (tar) ==="
echo "Started: $(date)"
echo "Destination: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Define what to backup (separate archives for better management)
ARCHIVES=(
    "system:/:--exclude=/proc --exclude=/tmp --exclude=/mnt --exclude=/dev --exclude=/sys --exclude=/run --exclude=/media --exclude=/lost+found --exclude=/swapfile --exclude=/home --exclude=/var/cache --exclude=/var/tmp --exclude=/var/log --exclude=$BACKUP_DIR"
    "home:/home:--exclude=/home/*/.cache --exclude=/home/*/.local/share/Trash"
    "boot:/boot:"
    "etc:/etc:"
    "var-important:/var:--exclude=/var/cache --exclude=/var/tmp --exclude=/var/log"
)

echo "Creating multiple archives for better management..."

# Create each archive
for archive_def in "${ARCHIVES[@]}"; do
    IFS=':' read -ra ARCHIVE_PARTS <<< "$archive_def"
    ARCHIVE_NAME="${ARCHIVE_PARTS[0]}"
    SOURCE_DIR="${ARCHIVE_PARTS[1]}"
    EXCLUDES="${ARCHIVE_PARTS[2]}"
    
    ARCHIVE_FILE="$BACKUP_DIR/${BACKUP_NAME}-${ARCHIVE_NAME}.tar.gz"
    
    echo ""
    echo "Creating archive: $ARCHIVE_NAME"
    echo "Source: $SOURCE_DIR"
    echo "Output: $ARCHIVE_FILE"
    
    # Build tar command
    if [ -n "$EXCLUDES" ]; then
        eval "sudo tar -czf \"$ARCHIVE_FILE\" -C / $EXCLUDES \"${SOURCE_DIR#/}\" 2>&1" | tee -a "$LOG_FILE"
    else
        sudo tar -czf "$ARCHIVE_FILE" -C / "${SOURCE_DIR#/}" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    # Show progress
    ARCHIVE_SIZE=$(ls -lh "$ARCHIVE_FILE" | awk '{print $5}')
    echo "Archive created: $ARCHIVE_SIZE"
done

# Create system information archive
echo ""
echo "Creating system information archive..."
SYSINFO_DIR="/tmp/ubuntu-sysinfo-$$"
mkdir -p "$SYSINFO_DIR"

# Collect system information
cat > "$SYSINFO_DIR/SYSTEM_INFO.txt" << EOF
Ubuntu Archive Backup - System Information
==========================================
Date: $(date)
Method: tar (multiple archives)
Backup Name: $BACKUP_NAME

System Information:
$(uname -a)

Distribution:
$(lsb_release -a 2>/dev/null)

Disk Information:
$(df -h)

Block Devices:
$(lsblk)

Memory Information:
$(free -h)

CPU Information:
$(lscpu)

Network Interfaces:
$(ip addr show)

Network Routes:
$(ip route show)

Mounted Filesystems:
$(mount)

Running Services:
$(systemctl list-units --type=service --state=running --no-pager)
EOF

# Collect configuration files
dpkg --get-selections > "$SYSINFO_DIR/installed-packages.txt"
lsmod > "$SYSINFO_DIR/kernel-modules.txt"
crontab -l > "$SYSINFO_DIR/user-crontab.txt" 2>/dev/null || echo "No user crontab" > "$SYSINFO_DIR/user-crontab.txt"
sudo crontab -l > "$SYSINFO_DIR/root-crontab.txt" 2>/dev/null || echo "No root crontab" > "$SYSINFO_DIR/root-crontab.txt"

# Copy important config files
cp /etc/fstab "$SYSINFO_DIR/" 2>/dev/null || true
cp /etc/hosts "$SYSINFO_DIR/" 2>/dev/null || true
cp /etc/hostname "$SYSINFO_DIR/" 2>/dev/null || true
cp /etc/passwd "$SYSINFO_DIR/" 2>/dev/null || true
cp /etc/group "$SYSINFO_DIR/" 2>/dev/null || true

# Create the system info archive
tar -czf "$BACKUP_DIR/${BACKUP_NAME}-sysinfo.tar.gz" -C /tmp "ubuntu-sysinfo-$$"
rm -rf "$SYSINFO_DIR"

# Create restore script
cat > "$BACKUP_DIR/${BACKUP_NAME}-RESTORE.sh" << 'EOF'
#!/bin/bash

# Ubuntu Archive Restore Script
# This script helps restore from tar archives

set -e

BACKUP_DIR="$(dirname "$0")"
BACKUP_NAME="$(basename "$0" | sed 's/-RESTORE\.sh$//')"

echo "=== Ubuntu Archive Restore ==="
echo "Backup: $BACKUP_NAME"
echo "Location: $BACKUP_DIR"

# Check available archives
echo ""
echo "Available archives:"
ls -lh "$BACKUP_DIR/$BACKUP_NAME"*.tar.gz

echo ""
echo "WARNING: This will overwrite existing files!"
echo "Make sure you're running this from a live Ubuntu system"
echo "with the target drive mounted at /mnt"
echo ""
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

# Mount check
if ! mountpoint -q /mnt; then
    echo "Error: /mnt is not a mount point"
    echo "Please mount your target root partition at /mnt first"
    exit 1
fi

# Restore archives in order
RESTORE_ORDER=("system" "home" "boot" "etc" "var-important")

for archive in "${RESTORE_ORDER[@]}"; do
    ARCHIVE_FILE="$BACKUP_DIR/${BACKUP_NAME}-${archive}.tar.gz"
    if [ -f "$ARCHIVE_FILE" ]; then
        echo "Restoring $archive..."
        sudo tar -xzf "$ARCHIVE_FILE" -C /mnt
        echo "✓ $archive restored"
    else
        echo "⚠ Archive not found: $ARCHIVE_FILE"
    fi
done

echo ""
echo "Creating essential directories..."
sudo mkdir -p /mnt/{dev,proc,sys,tmp,run,mnt,media}

echo ""
echo "Archive restore complete!"
echo "Next steps:"
echo "1. Chroot into the system: sudo chroot /mnt"
echo "2. Reinstall bootloader: grub-install /dev/sdX && update-grub"
echo "3. Update initramfs: update-initramfs -u"
echo "4. Exit chroot and reboot"
EOF

chmod +x "$BACKUP_DIR/${BACKUP_NAME}-RESTORE.sh"

# Create comprehensive restore instructions
cat > "$BACKUP_DIR/${BACKUP_NAME}-RESTORE_INSTRUCTIONS.md" << 'EOF'
# Ubuntu Archive Restore Instructions

## Overview
This backup consists of multiple compressed tar archives:
- `system` - Core system files (/, excluding /home, /boot, etc.)
- `home` - User home directories
- `boot` - Boot partition files
- `etc` - Configuration files
- `var-important` - Important /var files (excluding logs/cache)
- `sysinfo` - System information and configuration

## Prerequisites
1. Ubuntu Live USB/CD
2. Target system with properly partitioned disk
3. Network connectivity (if needed)

## Restore Process

### 1. Boot and Prepare
```bash
# Boot from Ubuntu Live USB
# Partition target disk if needed
sudo fdisk /dev/sdX  # or use gparted

# Create filesystems
sudo mkfs.ext4 /dev/sdX2  # root partition
sudo mkfs.fat -F32 /dev/sdX1  # EFI partition (if UEFI)

# Mount target filesystems
sudo mount /dev/sdX2 /mnt
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/sdX1 /mnt/boot/efi  # if UEFI
```

### 2. Restore Archives
```bash
# Navigate to backup location
cd /path/to/backup

# Run the restore script
sudo ./BACKUP_NAME-RESTORE.sh

# Or manually restore each archive:
sudo tar -xzf BACKUP_NAME-system.tar.gz -C /mnt
sudo tar -xzf BACKUP_NAME-home.tar.gz -C /mnt
sudo tar -xzf BACKUP_NAME-boot.tar.gz -C /mnt
sudo tar -xzf BACKUP_NAME-etc.tar.gz -C /mnt
sudo tar -xzf BACKUP_NAME-var-important.tar.gz -C /mnt
```

### 3. Configure Restored System
```bash
# Prepare for chroot
sudo mount --bind /dev /mnt/dev
sudo mount --bind /dev/pts /mnt/dev/pts
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys

# Chroot into restored system
sudo chroot /mnt

# Update fstab if needed
nano /etc/fstab

# Reinstall bootloader
grub-install /dev/sdX  # replace X with your disk
update-grub

# Update initramfs
update-initramfs -u

# Exit chroot
exit
```

### 4. Final Steps
```bash
# Unmount everything
sudo umount /mnt/dev/pts
sudo umount /mnt/dev
sudo umount /mnt/proc
sudo umount /mnt/sys
sudo umount /mnt/boot/efi
sudo umount /mnt

# Reboot
sudo reboot
```

## Post-Restore Tasks
1. Check network configuration
2. Update system: `sudo apt update && sudo apt upgrade`
3. Verify all services are running correctly
4. Restore any hardware-specific drivers if needed
5. Update user passwords if required

## Troubleshooting
- If boot fails, check /etc/fstab for correct UUIDs
- If network doesn't work, reconfigure network settings
- If graphics issues, reinstall GPU drivers
- Check system logs: `journalctl -xe`
EOF

# Calculate total backup size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR"/${BACKUP_NAME}*.tar.gz | awk '{total+=$1} END {print total}' || du -sh "$BACKUP_DIR" | cut -f1)
echo ""
echo "=== Backup Complete ==="
echo "Backup name: $BACKUP_NAME"
echo "Location: $BACKUP_DIR"
echo "Archives created:"
ls -lh "$BACKUP_DIR"/${BACKUP_NAME}*.tar.gz
echo ""
echo "Total size: $(du -sh "$BACKUP_DIR"/${BACKUP_NAME}*.tar.gz | awk '{sum+=$1} END {print sum "B"}' 2>/dev/null || echo "Multiple files")"
echo "Log file: $LOG_FILE"
echo "Restore script: $BACKUP_DIR/${BACKUP_NAME}-RESTORE.sh"
echo "Instructions: $BACKUP_DIR/${BACKUP_NAME}-RESTORE_INSTRUCTIONS.md"
echo "Completed: $(date)"

