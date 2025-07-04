#!/bin/bash

# Ubuntu Backup System Launcher
# Choose which backup method to use

set -e

echo "=== Ubuntu Backup System ==="
echo "Choose your backup method:"
echo ""
echo "1) System Image (dd) - Complete bit-for-bit disk copy (~954GB, 2-4 hours)"
echo "   Pros: Perfect for disaster recovery, includes everything"
echo "   Cons: Large size, slower"
echo ""
echo "2) File System (rsync) - Smart file copy (~18GB used space, 30-60 min)"
echo "   Pros: Smaller, faster, can restore to different hardware"
echo "   Cons: Requires bootloader setup"
echo ""
echo "3) Archive (tar) - Compressed archives (~5-10GB compressed, 15-30 min)"
echo "   Pros: Highly compressed, selective restore"
echo "   Cons: More complex restore process"
echo ""
echo "4) All Methods - Create all three backup types (recommended for first time)"
echo ""
echo "0) Exit"
echo ""

read -p "Select option (0-4): " choice

case $choice in
    1)
        echo "Starting System Image backup..."
        ./method1-system-image/backup.sh
        ;;
    2)
        echo "Starting File System backup..."
        ./method2-filesystem/backup.sh
        ;;
    3)
        echo "Starting Archive backup..."
        ./method3-archive/backup.sh
        ;;
    4)
        echo "Starting ALL backup methods..."
        echo "This will create comprehensive backups using all three methods."
        echo "Estimated total time: 3-5 hours"
        echo "Estimated total space needed: ~970GB"
        echo ""
        read -p "Continue with all methods? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo "=== Starting Method 3: Archive Backup ==="
            ./method3-archive/backup.sh
            echo ""
            echo "=== Starting Method 2: File System Backup ==="
            ./method2-filesystem/backup.sh
            echo ""
            echo "=== Starting Method 1: System Image Backup ==="
            ./method1-system-image/backup.sh
            echo ""
            echo "=== ALL BACKUPS COMPLETE ==="
            echo "You now have three different backup types for maximum flexibility!"
        else
            echo "All methods backup cancelled."
        fi
        ;;
    0)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid option selected."
        exit 1
        ;;
esac

echo ""
echo "Backup process completed!"
echo "Check the respective backup directories for your files."

