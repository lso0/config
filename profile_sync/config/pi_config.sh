#!/bin/bash

# Raspberry Pi Configuration
PI_USER="wgr0"
PI_HOST="192.168.1.9"
PI_PROFILE_PATH="/home/wgr0/google-chrome"

# Local Configuration
LOCAL_PROFILE_PATH="$HOME/.config/google-chrome"
BACKUP_DIR="$(dirname "$0")/../backups"
CONFIG_DIR="$(dirname "$0")"

# SSH Configuration
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no"

# Rsync Configuration
RSYNC_OPTS="-avhz --delete --progress"
EXCLUDE_FILE="$CONFIG_DIR/rsync_exclude.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="$HOME/.config/chrome-sync.log"

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Test connection to Pi
test_pi_connection() {
    info "Testing connection to Raspberry Pi..."
    if ssh $SSH_OPTS "$PI_USER@$PI_HOST" "echo 'Connection successful'" >/dev/null 2>&1; then
        success "Successfully connected to $PI_USER@$PI_HOST"
        return 0
    else
        error "Failed to connect to $PI_USER@$PI_HOST"
        return 1
    fi
}

# Ensure directories exist
ensure_directories() {
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
} 