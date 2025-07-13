#!/bin/bash

# Multi-Phase Ubuntu Setup Script
# Description: Automated setup with phase detection and progression
# Usage: curl -fsSL <your-script-url> | bash

set -euo pipefail

# Setup logging
LOG_DIR="$HOME/.config/wgms-setup"
LOG_FILE="$LOG_DIR/ubuntu-setup-$(date +%Y%m%d-%H%M%S).log"
PHASE_FILE="$LOG_DIR/current-phase"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Phase detection and management
detect_phase() {
    if [ -f "$PHASE_FILE" ]; then
        CURRENT_PHASE=$(cat "$PHASE_FILE")
        echo "$CURRENT_PHASE"
    else
        echo "1"
    fi
}

set_phase() {
    echo "$1" > "$PHASE_FILE"
}

show_phase_banner() {
    local phase=$1
    local title=$2
    local description=$3
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${WHITE}🚀 UBUNTU SETUP SYSTEM${NC}                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  ${PURPLE}PHASE $phase${NC} - ${WHITE}$title${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}$description${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to log both to console and file
log_to_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Enhanced logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_to_file "INFO: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_to_file "SUCCESS: $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_to_file "WARNING: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "ERROR: $1"
}

log_phase() {
    echo -e "${PURPLE}[PHASE]${NC} $1"
    log_to_file "PHASE: $1"
}

# Function to retry commands with exponential backoff and logging
retry_command() {
    local max_attempts=3
    local delay=1
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_to_file "Attempt $attempt of $max_attempts: $*"
        if "$@" 2>&1 | tee -a "$LOG_FILE"; then
            log_to_file "Command succeeded on attempt $attempt"
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "Command failed after $max_attempts attempts: $*"
                log_to_file "FAILED: $* (after $max_attempts attempts)"
                return 1
            fi
            log_warning "Attempt $attempt failed. Retrying in ${delay}s..."
            log_to_file "Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
            attempt=$((attempt + 1))
        fi
    done
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Check sudo privileges
if ! sudo -n true 2>/dev/null; then
    log_info "Please enter your password for sudo access:"
    sudo -v
fi

# Detect current phase
CURRENT_PHASE=$(detect_phase)

# Phase 1: Initial Setup (Desktop, Tools, Chrome)
if [ "$CURRENT_PHASE" = "1" ]; then
    show_phase_banner "1" "INITIAL SETUP" "Installing desktop environment, development tools, and Google Chrome"
    
    log_phase "Starting Phase 1: Initial Setup"
    log_to_file "=== PHASE 1 STARTING ==="
    
    # Log system information
    log_to_file "=== SYSTEM INFORMATION ==="
    log_to_file "OS: $(uname -a)"
    log_to_file "Distribution: $(lsb_release -a 2>/dev/null || cat /etc/os-release)"
    log_to_file "Uptime: $(uptime)"
    log_to_file "Disk Space: $(df -h)"
    log_to_file "Memory: $(free -h)"
    log_to_file "User: $(whoami)"
    log_to_file "Groups: $(groups)"
    log_to_file "=== END SYSTEM INFO ==="

    # System Update
    log_info "Updating system packages..."
    retry_command sudo apt update
    retry_command sudo apt full-upgrade -y
    log_success "System updated successfully"

    # Install essential packages
    log_info "Installing essential packages..."
    retry_command sudo apt install -y git curl wget unzip htop tree vim nano build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release ufw fail2ban openssh-server
    log_success "Essential packages installed"

    # Initialize success flags
    GITHUB_CLI_SUCCESS=false
    DOCKER_SUCCESS=false
    TAILSCALE_SUCCESS=false
    MULLVAD_SUCCESS=false
    GCLOUD_SUCCESS=false
    QEMU_SUCCESS=false
    ZSH_SUCCESS=false
    BROWSER_AUTOMATION_SUCCESS=false
    DESKTOP_SUCCESS=false
    CHROME_SUCCESS=false
    INFISICAL_SUCCESS=false
    NODE_SUCCESS=false
    YAZI_SUCCESS=false
    SPEEDTEST_SUCCESS=false

    # Install GitHub CLI
    log_info "Installing GitHub CLI..."
    GITHUB_CLI_SUCCESS=false
    log_info "Downloading GitHub CLI GPG key..."
    if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null; then
        sudo chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg
        log_success "GitHub CLI GPG key imported successfully"
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        
        if retry_command sudo apt update; then
            if retry_command sudo apt install -y gh; then
                log_success "GitHub CLI installed successfully"
                GITHUB_CLI_SUCCESS=true
            fi
        fi
    fi

    # Install Docker
    log_info "Installing Docker..."
    DOCKER_SUCCESS=false
    retry_command sudo apt install -y ca-certificates gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    
    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
        sudo chmod 644 /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        if retry_command sudo apt update; then
            if retry_command sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
                sudo usermod -aG docker $USER
                sudo systemctl enable docker
                sudo systemctl start docker
                log_success "Docker installed and configured"
                DOCKER_SUCCESS=true
            fi
        fi
    fi

    # Install Desktop Environment
    log_info "Installing Ubuntu Desktop Environment..."
    DESKTOP_SUCCESS=false
    
    if retry_command sudo apt install -y ubuntu-desktop-minimal; then
        log_success "Ubuntu Desktop Environment installed"
        DESKTOP_SUCCESS=true
    else
        log_warning "Ubuntu Desktop installation failed, trying alternative..."
        if retry_command sudo apt install -y xorg xfce4 xfce4-goodies lightdm; then
            log_success "XFCE Desktop Environment installed as alternative"
            DESKTOP_SUCCESS=true
        fi
    fi

    # Install Google Chrome
    log_info "Installing Google Chrome..."
    CHROME_SUCCESS=false
    
    if wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - 2>/dev/null; then
        if echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null; then
            retry_command sudo apt update
            if retry_command sudo apt install -y google-chrome-stable; then
                log_success "Google Chrome installed successfully"
                CHROME_SUCCESS=true
            fi
        fi
    fi

    # Install Chrome Profile Sync System
    if [ "$CHROME_SUCCESS" = true ]; then
        log_info "Setting up Chrome Profile Sync System..."
        
        PROFILE_SYNC_DIR="$HOME/profile_sync"
        mkdir -p "$PROFILE_SYNC_DIR"
        
        # Create basic profile sync structure
        mkdir -p "$PROFILE_SYNC_DIR/scripts" "$PROFILE_SYNC_DIR/config" "$PROFILE_SYNC_DIR/backups"
        
        # Create download script
        cat > "$PROFILE_SYNC_DIR/scripts/download.sh" << 'EOF'
#!/bin/bash
echo "⬇️  Chrome Profile Sync - Download from Raspberry Pi"
echo "=================================================="

PI_USER="wgr0"
PI_HOST="192.168.1.9"
PI_PROFILE_PATH="/home/wgr0/google-chrome"
LOCAL_PROFILE_PATH="$HOME/.config/google-chrome"

# Test connection
echo "Testing connection to Raspberry Pi..."
if ssh -o ConnectTimeout=10 "$PI_USER@$PI_HOST" "echo 'Connection successful'" >/dev/null 2>&1; then
    echo "✅ Successfully connected to $PI_USER@$PI_HOST"
else
    echo "❌ Failed to connect to $PI_USER@$PI_HOST"
    echo "Please ensure:"
    echo "1. Raspberry Pi is accessible at 192.168.1.9"
    echo "2. SSH key is configured: ssh-copy-id $PI_USER@$PI_HOST"
    exit 1
fi

# Check if Chrome is running
if pgrep -f "google-chrome" > /dev/null; then
    echo "⚠️  Google Chrome is running. Please close Chrome before syncing."
    read -p "Press Enter after closing Chrome to continue..."
fi

# Create backup of current profile
if [ -d "$LOCAL_PROFILE_PATH" ]; then
    echo "Creating backup of current profile..."
    BACKUP_NAME="pre-download-$(date +%Y%m%d-%H%M%S)"
    cp -r "$LOCAL_PROFILE_PATH" "$HOME/profile_sync/backups/$BACKUP_NAME"
    echo "✅ Backup created: $BACKUP_NAME"
fi

# Download profile from Pi
echo "Downloading Chrome profile from Raspberry Pi..."
echo "This may take a few minutes..."

if rsync -avhz --delete --progress \
    --exclude='*/Cache/*' \
    --exclude='*/Code Cache/*' \
    --exclude='*/Media Cache/*' \
    --exclude='*/GPUCache/*' \
    --exclude='*/logs/*' \
    --exclude='*.tmp' \
    --exclude='*.log' \
    "$PI_USER@$PI_HOST:$PI_PROFILE_PATH/" \
    "$LOCAL_PROFILE_PATH/"; then
    
    echo "✅ Profile downloaded successfully!"
    echo "Profile size: $(du -sh "$LOCAL_PROFILE_PATH" | cut -f1)"
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Start Google Chrome to verify profile"
    echo "2. To upload changes back: ./upload.sh"
    
else
    echo "❌ Failed to download profile from Raspberry Pi"
    exit 1
fi
EOF

        # Create upload script
        cat > "$PROFILE_SYNC_DIR/scripts/upload.sh" << 'EOF'
#!/bin/bash
echo "⬆️  Chrome Profile Sync - Upload to Raspberry Pi"
echo "=============================================="

PI_USER="wgr0"
PI_HOST="192.168.1.9"
PI_PROFILE_PATH="/home/wgr0/google-chrome"
LOCAL_PROFILE_PATH="$HOME/.config/google-chrome"

# Test connection
echo "Testing connection to Raspberry Pi..."
if ssh -o ConnectTimeout=10 "$PI_USER@$PI_HOST" "echo 'Connection successful'" >/dev/null 2>&1; then
    echo "✅ Successfully connected to $PI_USER@$PI_HOST"
else
    echo "❌ Failed to connect to $PI_USER@$PI_HOST"
    exit 1
fi

# Check if local profile exists
if [ ! -d "$LOCAL_PROFILE_PATH" ]; then
    echo "❌ Local Chrome profile not found at $LOCAL_PROFILE_PATH"
    echo "Make sure Google Chrome is installed and has been run at least once."
    exit 1
fi

# Check if Chrome is running
if pgrep -f "google-chrome" > /dev/null; then
    echo "⚠️  Google Chrome is running. Please close Chrome before syncing."
    read -p "Press Enter after closing Chrome to continue..."
fi

# Upload profile to Pi
echo "Uploading Chrome profile to Raspberry Pi..."
echo "This may take a few minutes..."

if rsync -avhz --delete --progress \
    --exclude='*/Cache/*' \
    --exclude='*/Code Cache/*' \
    --exclude='*/Media Cache/*' \
    --exclude='*/GPUCache/*' \
    --exclude='*/logs/*' \
    --exclude='*.tmp' \
    --exclude='*.log' \
    "$LOCAL_PROFILE_PATH/" \
    "$PI_USER@$PI_HOST:$PI_PROFILE_PATH/"; then
    
    echo "✅ Profile uploaded successfully!"
    echo ""
    echo "🚀 Profile is now available on Raspberry Pi"
    echo "Download on other machines: ./download.sh"
    
else
    echo "❌ Failed to upload profile to Raspberry Pi"
    exit 1
fi
EOF

        chmod +x "$PROFILE_SYNC_DIR/scripts/"*.sh
        log_success "Chrome profile sync scripts created in $PROFILE_SYNC_DIR"
    fi

    # Cleanup
    log_info "Cleaning up..."
    sudo apt autoremove -y
    sudo apt autoclean
    log_success "Cleanup completed"

    # Phase 1 completion
    log_phase "Phase 1 completed successfully!"
    log_success "🎉 Initial setup complete! Desktop environment and Chrome installed."
    
    # Set phase to 2 for next run
    set_phase "2"
    
    echo ""
    echo -e "${GREEN}✅ PHASE 1 COMPLETE!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. System will reboot to enable desktop environment"
    echo "2. After reboot, run: ${WHITE}curl wgms.uk|bash${NC}"
    echo "3. This will automatically start Phase 2 (Chrome sync setup)"
    echo ""
    
    # Automatic reboot
    echo -e "${YELLOW}Rebooting in 10 seconds to enable desktop environment...${NC}"
    echo "Press Ctrl+C to cancel reboot"
    
    for i in 10 9 8 7 6 5 4 3 2 1; do
        echo -n "Rebooting in $i seconds... "
        sleep 1
        echo ""
    done
    
    log_info "Rebooting now..."
    sudo reboot

# Phase 2: Post-Reboot Setup (Chrome Sync Configuration)
elif [ "$CURRENT_PHASE" = "2" ]; then
    show_phase_banner "2" "CHROME SYNC SETUP" "Configuring Chrome profile sync with Raspberry Pi"
    
    log_phase "Starting Phase 2: Chrome Sync Setup"
    log_to_file "=== PHASE 2 STARTING ==="
    
    # Check if desktop environment is available
    if command -v gnome-session >/dev/null 2>&1 || command -v xfce4-session >/dev/null 2>&1; then
        log_success "Desktop environment detected"
    else
        log_warning "Desktop environment not detected - Phase 1 may have failed"
    fi
    
    # Check if Chrome is installed
    if command -v google-chrome >/dev/null 2>&1; then
        log_success "Google Chrome detected: $(google-chrome --version | head -n1)"
    else
        log_error "Google Chrome not found - Phase 1 may have failed"
        exit 1
    fi
    
    # Setup Chrome Profile Sync
    log_info "Setting up Chrome Profile Sync with Raspberry Pi..."
    
    PROFILE_SYNC_DIR="$HOME/profile_sync"
    
    # Setup SSH key if not exists
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        log_info "Generating SSH key for Pi access..."
        ssh-keygen -t rsa -b 4096 -C "chrome-sync-$(hostname)" -f "$HOME/.ssh/id_rsa" -N ""
        log_success "SSH key generated"
    else
        log_info "SSH key already exists"
    fi
    
    # Copy SSH key to Pi
    log_info "Setting up SSH key authentication with Raspberry Pi..."
    echo "You may need to enter your password for the Raspberry Pi:"
    
    if ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" wgr0@192.168.1.9; then
        log_success "SSH key copied to Raspberry Pi"
    else
        log_error "Failed to copy SSH key to Pi"
        log_info "You can manually run: ssh-copy-id -i ~/.ssh/id_rsa.pub wgr0@192.168.1.9"
    fi
    
    # Test connection
    log_info "Testing connection to Raspberry Pi..."
    if ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "echo 'Connection successful'" >/dev/null 2>&1; then
        log_success "✅ SSH connection to Raspberry Pi successful!"
    else
        log_warning "❌ SSH connection failed"
        log_info "Please check:"
        log_info "1. Raspberry Pi is accessible at 192.168.1.9"
        log_info "2. SSH service is running on Pi"
        log_info "3. User 'wgr0' exists on Pi"
    fi
    
    # Create profile directory on Pi
    log_info "Creating profile directory on Raspberry Pi..."
    ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "mkdir -p ~/profile_sync" 2>/dev/null || true
    
    # Set phase to 3 for next run
    set_phase "3"
    
    log_phase "Phase 2 completed successfully!"
    log_success "🎉 Chrome sync setup complete!"
    
    echo ""
    echo -e "${GREEN}✅ PHASE 2 COMPLETE!${NC}"
    echo ""
    echo -e "${CYAN}Chrome Profile Sync is ready!${NC}"
    echo ""
    echo -e "${WHITE}Usage:${NC}"
    echo "• Upload profile to Pi: ${BLUE}cd ~/profile_sync && ./scripts/upload.sh${NC}"
    echo "• Download profile from Pi: ${BLUE}cd ~/profile_sync && ./scripts/download.sh${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. Run Chrome once to create your profile"
    echo "2. Upload your profile: ${WHITE}cd ~/profile_sync && ./scripts/upload.sh${NC}"
    echo "3. On new machines, download: ${WHITE}cd ~/profile_sync && ./scripts/download.sh${NC}"
    echo ""
    echo -e "${YELLOW}To run Phase 3 (profile sync operations): curl wgms.uk|bash${NC}"

# Phase 3: Profile Sync Operations
elif [ "$CURRENT_PHASE" = "3" ]; then
    show_phase_banner "3" "PROFILE SYNC OPERATIONS" "Upload or download Chrome profiles"
    
    log_phase "Starting Phase 3: Profile Sync Operations"
    log_to_file "=== PHASE 3 STARTING ==="
    
    PROFILE_SYNC_DIR="$HOME/profile_sync"
    
    # Check if profile sync scripts exist
    if [ ! -f "$PROFILE_SYNC_DIR/scripts/upload.sh" ] || [ ! -f "$PROFILE_SYNC_DIR/scripts/download.sh" ]; then
        log_error "Profile sync scripts not found. Please run Phase 1 again."
        exit 1
    fi
    
    # Test Pi connection
    log_info "Testing connection to Raspberry Pi..."
    if ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "echo 'Connection successful'" >/dev/null 2>&1; then
        log_success "✅ Connected to Raspberry Pi"
    else
        log_error "❌ Cannot connect to Raspberry Pi"
        log_info "Please check your Pi connection and run Phase 2 again"
        exit 1
    fi
    
    # Show sync options
    echo ""
    echo -e "${CYAN}Chrome Profile Sync Operations:${NC}"
    echo ""
    echo "1. Upload current profile to Pi (from this machine)"
    echo "2. Download profile from Pi (to this machine)"
    echo "3. Show sync status"
    echo "4. Reset to Phase 1 (start over)"
    echo ""
    
    read -p "Choose an option (1-4): " choice
    
    case $choice in
        1)
            log_info "Starting profile upload to Pi..."
            cd "$PROFILE_SYNC_DIR" && ./scripts/upload.sh
            ;;
        2)
            log_info "Starting profile download from Pi..."
            cd "$PROFILE_SYNC_DIR" && ./scripts/download.sh
            ;;
        3)
            log_info "Profile sync status:"
            echo ""
            echo -e "${BLUE}Local Chrome Profile:${NC}"
            if [ -d "$HOME/.config/google-chrome" ]; then
                echo "✅ Found at: $HOME/.config/google-chrome"
                echo "   Size: $(du -sh "$HOME/.config/google-chrome" | cut -f1)"
            else
                echo "❌ Not found"
            fi
            echo ""
            echo -e "${BLUE}Pi Profile:${NC}"
            if ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "[ -d ~/google-chrome ]" 2>/dev/null; then
                echo "✅ Found on Pi"
                PI_SIZE=$(ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "du -sh ~/google-chrome 2>/dev/null | cut -f1" 2>/dev/null || echo "Unknown")
                echo "   Size: $PI_SIZE"
            else
                echo "❌ Not found on Pi"
            fi
            echo ""
            echo -e "${BLUE}Connection:${NC}"
            if ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "echo 'OK'" 2>/dev/null; then
                echo "✅ Connected to Pi"
            else
                echo "❌ Cannot connect to Pi"
            fi
            ;;
        4)
            log_info "Resetting to Phase 1..."
            rm -f "$PHASE_FILE"
            echo -e "${GREEN}Reset complete! Run 'curl wgms.uk|bash' again to start Phase 1.${NC}"
            ;;
        *)
            log_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}Phase 3 completed!${NC}"
    echo -e "${CYAN}Run 'curl wgms.uk|bash' again for more sync operations.${NC}"

else
    log_error "Unknown phase: $CURRENT_PHASE"
    log_info "Resetting phase tracking..."
    rm -f "$PHASE_FILE"
    echo -e "${GREEN}Reset complete! Run 'curl wgms.uk|bash' again to start Phase 1.${NC}"
fi

# Log completion
log_to_file "=== SCRIPT EXIT ==="
log_to_file "Final phase: $(detect_phase)"
log_to_file "Log file: $LOG_FILE" 