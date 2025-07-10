#!/bin/bash

# Universal System Setup Script
# Description: Detects system and runs appropriate setup script
# Usage: curl -fsSL wgms.uk | bash

set -euo pipefail

# Setup logging
LOG_DIR="$HOME/.config/wgms-setup"
LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# Create log file with session info
cat > "$LOG_FILE" << EOF
# Universal System Setup Log
# Started: $(date)
# User: $(whoami)
# PWD: $(pwd)
# Command: $0 $*
# Session ID: $$
EOF

# Function to log both to console and file
log_to_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to log command execution
log_command() {
    local cmd="$1"
    log_to_file "COMMAND: $cmd"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - COMMAND: $cmd" >> "$LOG_FILE"
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

# Cleanup function for script exit
cleanup() {
    local exit_code=$?
    log_to_file "=== SCRIPT EXIT ==="
    log_to_file "Exit code: $exit_code"
    log_to_file "Duration: $SECONDS seconds"
    log_to_file "Log file: $LOG_FILE"
    if [[ $exit_code -eq 0 ]]; then
        log_success "Setup completed successfully! Log: $LOG_FILE"
    else
        log_error "Setup failed with exit code $exit_code. Check log: $LOG_FILE"
    fi
    log_to_file "=== END SESSION ==="
}

# Set trap for cleanup
trap cleanup EXIT

# Main function
main() {
    log_info "🚀 Universal System Setup - Detecting Environment..."
    log_to_file "=== STARTING UNIVERSAL SETUP ==="
    
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
    log_command "curl -fsSL '$script_url' | bash"
    
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
            log_success "🎉 Setup completed successfully!"
            log_to_file "Platform script execution: SUCCESS"
        else
            # Check if it's a partial success (most core components installed)
            if grep -q "SUCCESS.*packages installed\|SUCCESS.*tools installed\|SUCCESS.*Development tools installed" "$LOG_FILE"; then
                log_success "🎉 Setup completed with partial success!"
                log_warning "Some optional packages may have been skipped, but core installation succeeded"
                log_to_file "Platform script execution: PARTIAL SUCCESS"
            else
                log_error "❌ Setup failed. Please check the logs above."
                log_to_file "Platform script execution: FAILED"
                exit 1
            fi
        fi
    else
        log_error "❌ Failed to download setup script from: $script_url"
        log_to_file "Platform script download: FAILED"
        exit 1
    fi
}

# Run main function
main "$@" 