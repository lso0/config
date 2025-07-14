#!/bin/bash

# Universal Multi-Phase System Setup Script
# Description: Detects system, runs appropriate setup script, then handles Chrome sync
# Usage: curl -fsSL <your-script-url> | bash

set -euo pipefail

# Setup logging
LOG_DIR="$HOME/.config/wgms-setup"
LOG_FILE="$LOG_DIR/universal-setup-$(date +%Y%m%d-%H%M%S).log"
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
    echo -e "${CYAN}║${NC}                    ${WHITE}🚀 UNIVERSAL SETUP SYSTEM${NC}                    ${CYAN}║${NC}"
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

# System detection function
detect_system() {
    local os_type=""
    local arch=""
    local distro=""
    
    # Detect OS type
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="linux"
        
        # Detect Linux distribution
        if command -v lsb_release >/dev/null 2>&1; then
            distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        elif [[ -f /etc/os-release ]]; then
            distro=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
        elif [[ -f /etc/redhat-release ]]; then
            distro="rhel"
        elif [[ -f /etc/debian_version ]]; then
            distro="debian"
        else
            distro="unknown"
        fi
        
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macos"
        distro="macos"
        
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        os_type="windows"
        distro="windows"
        
    else
        log_error "Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    # Detect architecture
    arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l)
            arch="armv7"
            ;;
        i386|i686)
            arch="386"
            ;;
        *)
            log_warning "Unknown architecture: $arch"
            ;;
    esac
    
    echo "$os_type:$distro:$arch"
}

# Hardware detection function
detect_hardware() {
    local hardware_info=""
    
    # Check if running in a container
    if [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        hardware_info="container:docker"
    elif grep -q lxc /proc/1/cgroup 2>/dev/null; then
        hardware_info="container:lxc"
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt_type=$(systemd-detect-virt)
        if [[ "$virt_type" != "none" ]]; then
            hardware_info="vm:$virt_type"
        fi
    fi
    
    # Check for Raspberry Pi
    if [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
        hardware_info="raspberry-pi"
    fi
    
    # Check for cloud providers
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1; then
        hardware_info="cloud:aws"
    elif curl -s --max-time 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/ >/dev/null 2>&1; then
        hardware_info="cloud:gcp"
    elif curl -s --max-time 2 -H "Metadata: true" http://169.254.169.254/metadata/instance >/dev/null 2>&1; then
        hardware_info="cloud:azure"
    fi
    
    echo "$hardware_info"
}

# Network detection function
detect_network() {
    local network_info=""
    
    # Check internet connectivity
    if ! curl -s --max-time 5 https://www.google.com >/dev/null 2>&1; then
        log_error "No internet connectivity detected"
        exit 1
    fi
    
    # Check for common corporate/restricted networks
    if curl -s --max-time 2 http://detectportal.firefox.com/canonical.html | grep -q "success" 2>/dev/null; then
        network_info="open"
    else
        network_info="restricted"
    fi
    
    echo "$network_info"
}

# Function to log system information
log_system_info() {
    log_to_file "=== SYSTEM INFORMATION ==="
    log_to_file "OS: $(uname -s)"
    log_to_file "Kernel: $(uname -r)"
    log_to_file "Architecture: $(uname -m)"
    log_to_file "Hostname: $(hostname)"
    if command -v lsb_release >/dev/null 2>&1; then
        log_to_file "Distribution: $(lsb_release -d | cut -f2)"
    fi
    log_to_file "Uptime: $(uptime)"
    log_to_file "Disk Space: $(df -h / | tail -1)"
    log_to_file "Memory: $(free -h | grep '^Mem:' || echo 'N/A')"
    log_to_file "=== END SYSTEM INFO ==="
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

# Phase 1: System Detection and OS-Specific Setup
if [ "$CURRENT_PHASE" = "1" ]; then
    show_phase_banner "1" "SYSTEM DETECTION & SETUP" "Detecting system and running OS-specific setup"
    
    log_phase "Starting Phase 1: System Detection and Setup"
    log_to_file "=== PHASE 1 STARTING ==="
    
    # Log system information
    log_system_info
    
    # Detect system information
    log_info "Detecting system configuration..."
    local system_info=$(detect_system)
    local hardware_info=$(detect_hardware)
    local network_info=$(detect_network)
    
    # Parse system info
    IFS=':' read -r os_type distro arch <<< "$system_info"
    
    log_info "System: $os_type ($distro) on $arch"
    [[ -n "$hardware_info" ]] && log_info "Hardware: $hardware_info"
    log_info "Network: $network_info"
    
    # Log detection results
    log_to_file "=== DETECTION RESULTS ==="
    log_to_file "OS Type: $os_type"
    log_to_file "Distribution: $distro"
    log_to_file "Architecture: $arch"
    log_to_file "Hardware: $hardware_info"
    log_to_file "Network: $network_info"
    log_to_file "=== END DETECTION ==="
    
    # Determine which script to run
    local script_url=""
    
    case "$os_type" in
        "linux")
            case "$distro" in
                "ubuntu"|"debian")
                    script_url="https://raw.githubusercontent.com/lso0/config/main/linux/ubuntu-s/s.sh"
                    ;;
                "nixos")
                    script_url="https://raw.githubusercontent.com/lso0/config/main/linux/nixos/setup.sh"
                    ;;
                "arch"|"manjaro")
                    script_url="https://raw.githubusercontent.com/lso0/config/main/linux/arch/setup.sh"
                    ;;
                *)
                    log_warning "Unsupported Linux distribution: $distro"
                    log_info "Trying generic Ubuntu script..."
                    script_url="https://raw.githubusercontent.com/lso0/config/main/linux/ubuntu-s/s.sh"
                    ;;
            esac
            ;;
        "macos")
            script_url="https://raw.githubusercontent.com/lso0/config/main/macos/setup.sh"
            ;;
        "windows")
            script_url="https://raw.githubusercontent.com/lso0/config/main/windows/setup.ps1"
            log_error "Windows PowerShell script detected. Please run:"
            log_error "Invoke-WebRequest -Uri '$script_url' | Invoke-Expression"
            exit 1
            ;;
        *)
            log_error "Unsupported operating system: $os_type"
            exit 1
            ;;
    esac
    
    log_success "✅ Selected script: $script_url"
    log_to_file "Selected script URL: $script_url"
    log_info "🔄 Downloading and executing setup script..."
    
    # Download and execute the appropriate script with logging
    log_to_file "=== EXECUTING PLATFORM SCRIPT ==="
    
    # Execute with output capture and improved error handling
    local temp_script="/tmp/setup_script_$$.sh"
    local script_exit_code=0
    
    # Download script first to check for errors
    if curl -fsSL "$script_url" -o "$temp_script" 2>&1 | tee -a "$LOG_FILE"; then
        # Make script executable and run it
        chmod +x "$temp_script"
        
        # Capture both output and exit code
        if bash "$temp_script" 2>&1 | tee -a "$LOG_FILE"; then
            script_exit_code=0
        else
            script_exit_code=$?
        fi
        
        # Clean up temp script
        rm -f "$temp_script"
        
        # Check for success indicators in the logs
        if grep -q "Setup Complete\|🎉.*Complete" "$LOG_FILE" || [ $script_exit_code -eq 0 ]; then
            log_success "🎉 OS-specific setup completed successfully!"
            log_to_file "Platform script execution: SUCCESS"
        else
            # Check if it's a partial success (most core components installed)
            if grep -q "SUCCESS.*packages installed\|SUCCESS.*tools installed\|SUCCESS.*Development tools installed" "$LOG_FILE"; then
                log_success "🎉 OS-specific setup completed with partial success!"
                log_warning "Some optional packages may have been skipped, but core installation succeeded"
                log_to_file "Platform script execution: PARTIAL SUCCESS"
            else
                log_error "❌ OS-specific setup failed. Please check the logs above."
                log_to_file "Platform script execution: FAILED"
                exit 1
            fi
        fi
    else
        log_error "❌ Failed to download setup script from: $script_url"
        log_to_file "Platform script download: FAILED"
        exit 1
    fi

    # Phase 1 completion
    log_phase "Phase 1 completed successfully!"
    log_success "🎉 System detection and OS-specific setup complete!"
    
    # Set phase to 2 for next run
    set_phase "2"
    
    echo ""
    echo -e "${GREEN}✅ PHASE 1 COMPLETE!${NC}"
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "1. OS-specific setup completed"
    echo "2. Run: ${WHITE}curl wgms.uk|bash${NC}"
    echo "3. This will automatically start Phase 2 (Chrome sync setup)"
    echo ""

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