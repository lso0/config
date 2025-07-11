#!/bin/bash

# Ubuntu Server One-Click Setup Script
# Description: Automated setup for fresh Ubuntu server installations
# Usage: curl -fsSL <your-script-url> | bash

set -euo pipefail  # Enhanced error handling

# Setup logging
LOG_DIR="$HOME/.config/wgms-setup"
LOG_FILE="$LOG_DIR/ubuntu-setup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$LOG_DIR"

# Create log file with session info
cat > "$LOG_FILE" << EOF
# Ubuntu Server Setup Log
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

# Function to log command execution with output capture
log_command() {
    local cmd="$1"
    log_to_file "COMMAND: $cmd"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - COMMAND: $cmd" >> "$LOG_FILE"
}

# Function to retry commands with exponential backoff and logging
retry_command() {
    local max_attempts=3
    local delay=1
    local attempt=1
    
    log_command "$*"
    
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

# Cleanup function for script exit
cleanup() {
    local exit_code=$?
    log_to_file "=== UBUNTU SETUP EXIT ==="
    log_to_file "Exit code: $exit_code"
    log_to_file "Duration: $SECONDS seconds"
    log_to_file "Log file: $LOG_FILE"
    
    # Count successful core installations
    local core_success_count=0
    local total_attempted=0
    
    # Count core components (essential ones)
    if [ "$GITHUB_CLI_SUCCESS" = true ]; then
        ((core_success_count++))
    fi
    ((total_attempted++))
    
    if [ "$DOCKER_SUCCESS" = true ]; then
        ((core_success_count++))
    fi
    ((total_attempted++))
    
    if [ "$TAILSCALE_SUCCESS" = true ]; then
        ((core_success_count++))
    fi
    ((total_attempted++))
    
    if [ "$MULLVAD_SUCCESS" = true ]; then
        ((core_success_count++))
    fi
    ((total_attempted++))
    
    # Additional tools (not critical for exit code)
    local additional_success_count=0
    local additional_attempted=0
    
    if [ "$INFISICAL_SUCCESS" = true ]; then
        ((additional_success_count++))
    fi
    ((additional_attempted++))
    
    if [ "$NODE_SUCCESS" = true ]; then
        ((additional_success_count++))
    fi
    ((additional_attempted++))
    
    if [ "$YAZI_SUCCESS" = true ]; then
        ((additional_success_count++))
    fi
    ((additional_attempted++))
    
    if [ "$SPEEDTEST_SUCCESS" = true ]; then
        ((additional_success_count++))
    fi
    ((additional_attempted++))
    
    # Calculate success percentage for core components
    local success_percentage=$((core_success_count * 100 / total_attempted))
    
    log_to_file "Core components success: $core_success_count/$total_attempted ($success_percentage%)"
    log_to_file "Additional tools success: $additional_success_count/$additional_attempted"
    
    # Exit with success if we have 75% or more core components installed
    if [ $success_percentage -ge 75 ]; then
        log_to_file "Setup completed successfully (≥75% core components installed)"
        exit 0
    else
        log_to_file "Setup partially failed (<75% core components installed)"
        exit $exit_code
    fi
}

# Set trap for cleanup
trap cleanup EXIT

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

log_info "Starting Ubuntu Server One-Click Setup..."
log_to_file "=== UBUNTU SETUP STARTING ==="

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
retry_command sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    htop \
    tree \
    vim \
    nano \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    openssh-server
log_success "Essential packages installed"

# Configure basic security
log_info "Configuring basic security..."
sudo ufw --force enable
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
log_success "Basic security configured"

# Install GitHub CLI
log_info "Installing GitHub CLI..."

# Ensure keyrings directory exists with proper permissions
sudo mkdir -p /usr/share/keyrings
sudo chmod 755 /usr/share/keyrings

# Download and import GitHub CLI GPG key with better error handling
GITHUB_CLI_SUCCESS=false
log_info "Downloading GitHub CLI GPG key..."
if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null; then
    sudo chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg
    log_success "GitHub CLI GPG key imported successfully"
    
    # Add GitHub CLI repository
    log_info "Adding GitHub CLI repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    
    # Update package lists
    log_info "Updating package lists after adding GitHub CLI repository..."
    if retry_command sudo apt update; then
        log_success "Package lists updated successfully"
        
        # Install GitHub CLI
        log_info "Installing GitHub CLI package..."
        if retry_command sudo apt install -y gh; then
            log_success "GitHub CLI installed successfully"
            GITHUB_CLI_SUCCESS=true
        else
            log_warning "GitHub CLI installation failed, continuing with other packages"
        fi
    else
        log_error "Failed to update package lists - removing GitHub CLI repository"
        sudo rm -f /etc/apt/sources.list.d/github-cli.list /usr/share/keyrings/githubcli-archive-keyring.gpg
        retry_command sudo apt update
        log_warning "Skipping GitHub CLI installation due to repository issues"
    fi
else
    log_error "Failed to download GitHub CLI GPG key"
    log_warning "Skipping GitHub CLI installation"
fi

if [ "$GITHUB_CLI_SUCCESS" = false ]; then
    log_warning "GitHub CLI installation was skipped or failed"
fi

# Install Docker
log_info "Installing Docker..."
retry_command sudo apt install -y ca-certificates gnupg
sudo install -m 0755 -d /etc/apt/keyrings

# Download and import Docker GPG key with better error handling
DOCKER_SUCCESS=false
log_info "Downloading Docker GPG key..."
if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    sudo chmod 644 /etc/apt/keyrings/docker.gpg
    log_success "Docker GPG key imported successfully"
    
    # Add Docker repository
    log_info "Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package lists
    log_info "Updating package lists after adding Docker repository..."
    if retry_command sudo apt update; then
        log_success "Package lists updated successfully"
        
        # Install Docker packages
        log_info "Installing Docker packages..."
        if retry_command sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
            # Configure Docker
            sudo usermod -aG docker $USER
            sudo systemctl enable docker
            sudo systemctl start docker
            log_success "Docker installed and configured"
            DOCKER_SUCCESS=true
        else
            log_warning "Docker installation failed, continuing with other packages"
        fi
    else
        log_error "Failed to update package lists - removing Docker repository"
        sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg
        retry_command sudo apt update
        log_warning "Skipping Docker installation due to repository issues"
    fi
else
    log_error "Failed to download Docker GPG key"
    log_warning "Skipping Docker installation"
fi

if [ "$DOCKER_SUCCESS" = false ]; then
    log_warning "Docker installation was skipped or failed"
fi

# Install Tailscale
log_info "Installing Tailscale..."

# Download and import Tailscale GPG key with better error handling
TAILSCALE_SUCCESS=false
log_info "Downloading Tailscale GPG key..."
if curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null; then
    sudo chmod 644 /usr/share/keyrings/tailscale-archive-keyring.gpg
    log_success "Tailscale GPG key imported successfully"
    
    # Add Tailscale repository
    log_info "Adding Tailscale repository..."
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tailscale.list
    
    # Update package lists
    log_info "Updating package lists after adding Tailscale repository..."
    if retry_command sudo apt update; then
        log_success "Package lists updated successfully"
        
        # Install Tailscale
        log_info "Installing Tailscale package..."
        if retry_command sudo apt install -y tailscale; then
            sudo systemctl enable --now tailscaled
            log_success "Tailscale installed and started"
            TAILSCALE_SUCCESS=true
        else
            log_warning "Tailscale installation failed, continuing with other packages"
        fi
    else
        log_error "Failed to update package lists - removing Tailscale repository"
        sudo rm -f /etc/apt/sources.list.d/tailscale.list /usr/share/keyrings/tailscale-archive-keyring.gpg
        retry_command sudo apt update
        log_warning "Skipping Tailscale installation due to repository issues"
    fi
else
    log_error "Failed to download Tailscale GPG key"
    log_warning "Skipping Tailscale installation"
fi

if [ "$TAILSCALE_SUCCESS" = false ]; then
    log_warning "Tailscale installation was skipped or failed"
fi

# Install Mullvad VPN
log_info "Installing Mullvad VPN..."

# Download and import Mullvad VPN GPG key with better error handling
MULLVAD_SUCCESS=false
log_info "Downloading Mullvad VPN GPG key..."
if curl -fsSL https://repository.mullvad.net/deb/mullvad-keyring.asc | sudo gpg --dearmor -o /usr/share/keyrings/mullvad-keyring.gpg; then
    sudo chmod 644 /usr/share/keyrings/mullvad-keyring.gpg
    log_success "Mullvad VPN GPG key imported successfully"
    
    # Add Mullvad VPN repository
    log_info "Adding Mullvad VPN repository..."
    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.gpg arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mullvad.list
    
    # Update package lists
    log_info "Updating package lists after adding Mullvad VPN repository..."
    if retry_command sudo apt update; then
        log_success "Package lists updated successfully"
        
        # Install Mullvad VPN
        log_info "Installing Mullvad VPN package..."
        if retry_command sudo apt install -y mullvad-vpn; then
            log_success "Mullvad VPN installed"
            MULLVAD_SUCCESS=true
        else
            log_warning "Mullvad VPN installation failed, continuing with other packages"
        fi
    else
        log_error "Failed to update package lists - removing Mullvad VPN repository"
        sudo rm -f /etc/apt/sources.list.d/mullvad.list /usr/share/keyrings/mullvad-keyring.gpg
        retry_command sudo apt update
        log_warning "Skipping Mullvad VPN installation due to repository issues"
    fi
else
    log_error "Failed to download Mullvad VPN GPG key"
    log_warning "Skipping Mullvad VPN installation"
fi

if [ "$MULLVAD_SUCCESS" = false ]; then
    log_warning "Mullvad VPN installation was skipped or failed"
fi

# Install Node.js (LTS) via NodeSource
log_info "Installing Node.js LTS..."

# Download and run NodeSource setup script with better error handling
NODE_SUCCESS=false
log_info "Downloading NodeSource setup script..."
if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null; then
    log_success "NodeSource repository added successfully"
    
    # Install Node.js
    log_info "Installing Node.js package..."
    if retry_command sudo apt install -y nodejs; then
        log_success "Node.js installed: $(node --version)"
        NODE_SUCCESS=true
    else
        log_warning "Node.js installation failed, continuing with other packages"
    fi
else
    log_error "Failed to add NodeSource repository"
    log_warning "Skipping Node.js installation"
fi

if [ "$NODE_SUCCESS" = false ]; then
    log_warning "Node.js installation was skipped or failed"
fi

# Install Infisical CLI (after Node.js is available)
log_info "Installing Infisical CLI..."

# Check architecture and try different installation methods
ARCH=$(dpkg --print-architecture)
INFISICAL_SUCCESS=false

if [ "$ARCH" = "amd64" ]; then
    log_info "Attempting Infisical installation for AMD64..."
    
    # Configure npm for proper global package management (no sudo required)
    if command -v npm >/dev/null 2>&1; then
        log_info "Setting up npm global directory..."
        
        # Create a directory for global packages
        mkdir -p ~/.npm-global 2>/dev/null
        
        # Configure npm to use the new directory
        npm config set prefix "$HOME/.npm-global"
        
        # Add to PATH both for current session and future sessions
        if ! echo "$PATH" | grep -q "$HOME/.npm-global/bin"; then
            export PATH="$HOME/.npm-global/bin:$PATH"
            # Ensure we don't add duplicate entries to bashrc
            if ! grep -q "\.npm-global/bin" ~/.bashrc; then
                echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
            fi
            # Source bashrc to ensure PATH is updated
            source ~/.bashrc 2>/dev/null || true
        fi
        
        log_info "Installing Infisical CLI via npm..."
        if npm install -g @infisical/cli 2>/dev/null; then
            log_success "Infisical CLI installed via npm"
            
            # Ensure PATH is updated again after installation
            export PATH="$HOME/.npm-global/bin:$PATH"
            source ~/.bashrc 2>/dev/null || true
            
            # Verify installation with multiple checks
            if command -v infisical >/dev/null 2>&1 || [ -x "$HOME/.npm-global/bin/infisical" ]; then
                log_success "Infisical CLI verified and working"
                INFISICAL_SUCCESS=true
            else
                log_warning "Infisical installed but not in PATH, trying alternatives..."
            fi
        else
            log_warning "NPM installation failed, trying fallback methods..."
        fi
    fi
    
    # Fallback method 1: Try direct binary download if npm failed
    if [ "$INFISICAL_SUCCESS" = false ]; then
        log_info "Trying direct binary download..."
        if curl -1sLf 'https://dl.infisical.com/cli/install.sh' | sh 2>/dev/null; then
            log_success "Infisical CLI installed via direct download"
            INFISICAL_SUCCESS=true
        fi
    fi
    
    # Fallback method 2: Try manual binary installation
    if [ "$INFISICAL_SUCCESS" = false ]; then
        log_info "Trying manual binary installation..."
        LATEST_VERSION=$(curl -s https://api.github.com/repos/Infisical/infisical/releases/latest | grep tag_name | cut -d '"' -f 4 2>/dev/null)
        if [ -n "$LATEST_VERSION" ]; then
            DOWNLOAD_URL="https://github.com/Infisical/infisical/releases/download/${LATEST_VERSION}/infisical_${LATEST_VERSION#v}_linux_amd64.tar.gz"
            if curl -L "$DOWNLOAD_URL" -o /tmp/infisical.tar.gz 2>/dev/null && 
               tar -xzf /tmp/infisical.tar.gz -C /tmp 2>/dev/null &&
               sudo mv /tmp/infisical /usr/local/bin/ 2>/dev/null &&
               sudo chmod +x /usr/local/bin/infisical 2>/dev/null; then
                log_success "Infisical CLI installed via manual binary"
                INFISICAL_SUCCESS=true
                rm -f /tmp/infisical.tar.gz 2>/dev/null
            fi
        fi
    fi
    
    # Final fallback: Use sudo npm install (original method)
    if [ "$INFISICAL_SUCCESS" = false ]; then
        log_info "Trying sudo npm installation as final fallback..."
        if sudo npm install -g @infisical/cli 2>/dev/null; then
            log_success "Infisical CLI installed via sudo npm (fallback)"
            INFISICAL_SUCCESS=true
        fi
    fi
else
    log_warning "Infisical CLI: No ARM64 build available, skipping..."
fi

# Report results
if [ "$INFISICAL_SUCCESS" = true ]; then
    log_success "Infisical CLI installation completed"
    # Final verification
    if command -v infisical >/dev/null 2>&1; then
        log_success "Infisical CLI verified: $(infisical --version 2>/dev/null || echo 'Available')"
    fi
else
    log_warning "Infisical CLI installation was skipped or failed - this is not critical"
    log_info "You can install it manually later with: npm install -g @infisical/cli"
fi

# Install common development tools
log_info "Installing additional development tools..."
retry_command sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    jq \
    tmux \
    screen \
    rsync
log_success "Development tools installed"

# Install Yazi file manager and its dependencies
log_info "Installing Yazi file manager and dependencies..."
YAZI_SUCCESS=false

# Install Yazi dependencies first
log_info "Installing Yazi dependencies..."
retry_command sudo apt install -y \
    file \
    ffmpeg \
    p7zip-full \
    jq \
    poppler-utils \
    fd-find \
    ripgrep \
    fzf \
    zoxide \
    imagemagick \
    xclip

# For Ubuntu, fd-find is installed as fdfind, create symlink for fd
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    sudo ln -sf $(which fdfind) /usr/local/bin/fd
    log_info "Created fd symlink for fdfind"
fi

# Method 1: Try downloading binary release (fastest and most reliable)
log_info "Trying Yazi binary download..."
YAZI_VERSION=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep tag_name | cut -d '"' -f 4 2>/dev/null)
if [ -n "$YAZI_VERSION" ]; then
    # Try different binary variants
    ARCH_NAME=$(uname -m)
    case "$ARCH_NAME" in
        x86_64)
            YAZI_ARCH="x86_64-unknown-linux-gnu"
            ;;
        aarch64)
            YAZI_ARCH="aarch64-unknown-linux-gnu"
            ;;
        *)
            YAZI_ARCH="x86_64-unknown-linux-gnu"  # Default fallback
            ;;
    esac
    
    YAZI_URL="https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${YAZI_ARCH}.tar.gz"
    log_info "Downloading Yazi ${YAZI_VERSION} for ${YAZI_ARCH}..."
    
    if curl -L "$YAZI_URL" -o /tmp/yazi.tar.gz 2>/dev/null && 
       tar -xzf /tmp/yazi.tar.gz -C /tmp 2>/dev/null; then
        
        # Find the extracted directory (it might have different naming)
        YAZI_DIR=$(find /tmp -name "yazi-${YAZI_ARCH}" -o -name "yazi-*" -type d 2>/dev/null | head -1)
        if [ -n "$YAZI_DIR" ] && [ -f "$YAZI_DIR/yazi" ]; then
            if sudo mv "$YAZI_DIR/yazi" /usr/local/bin/ 2>/dev/null &&
               [ -f "$YAZI_DIR/ya" ] && sudo mv "$YAZI_DIR/ya" /usr/local/bin/ 2>/dev/null &&
               sudo chmod +x /usr/local/bin/yazi /usr/local/bin/ya 2>/dev/null; then
                log_success "Yazi installed via binary release"
                YAZI_SUCCESS=true
            fi
        fi
        rm -rf /tmp/yazi.tar.gz /tmp/yazi-* 2>/dev/null
    else
        log_warning "Binary download failed for ${YAZI_ARCH}"
    fi
fi

# Method 2: Install Rust and try cargo installation if binary failed
if [ "$YAZI_SUCCESS" = false ]; then
    log_info "Binary installation failed, trying Rust/Cargo method..."
    
    # Check if cargo is available, if not install Rust
    if ! command -v cargo >/dev/null 2>&1; then
        log_info "Installing Rust/Cargo for Yazi..."
        if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null; then
            log_success "Rust/Cargo installed"
        else
            log_warning "Failed to install Rust/Cargo"
        fi
    fi
    
    # Source Rust environment for current session (do this regardless)
    if [ -f ~/.cargo/env ]; then
        source ~/.cargo/env 2>/dev/null || true
    fi
    export PATH="$HOME/.cargo/bin:$PATH"
    
    # Try cargo installation if cargo is now available
    if command -v cargo >/dev/null 2>&1; then
        log_info "Installing Yazi via cargo..."
        # Increase timeout to 5 minutes for large Rust compilation
        if timeout 300 cargo install --locked yazi-fm yazi-cli 2>/dev/null; then
            log_success "Yazi installed via cargo"
            YAZI_SUCCESS=true
        else
            log_warning "Cargo installation failed or timed out"
        fi
    else
        log_warning "Cargo not available after Rust installation"
    fi
fi

# Method 3: Try snap installation as final fallback
if [ "$YAZI_SUCCESS" = false ]; then
    log_info "Trying snap installation as fallback..."
    if command -v snap >/dev/null 2>&1; then
        if sudo snap install yazi 2>/dev/null; then
            log_success "Yazi installed via snap"
            YAZI_SUCCESS=true
        fi
    fi
fi

if [ "$YAZI_SUCCESS" = true ]; then
    log_success "Yazi file manager installation completed"
    # Verify installation
    if command -v yazi >/dev/null 2>&1; then
        log_success "Yazi verified: $(yazi --version 2>/dev/null || echo 'Available')"
    fi
else
    log_warning "Yazi installation failed - you can install it manually later"
    log_info "Manual installation options:"
    log_info "1. Via snap: sudo snap install yazi"
    log_info "2. Via cargo: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh && cargo install --locked yazi-fm yazi-cli"
fi

# Install Speedtest CLI
log_info "Installing Speedtest CLI..."
SPEEDTEST_SUCCESS=false

# Method 1: Try official Ookla repository
log_info "Adding Ookla Speedtest repository..."
if curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash 2>/dev/null; then
    log_success "Speedtest repository added"
    
    # Install speedtest package
    if retry_command sudo apt install -y speedtest; then
        log_success "Speedtest CLI installed via official repository"
        SPEEDTEST_SUCCESS=true
    fi
else
    log_warning "Official Speedtest repository failed, trying alternative..."
fi

# Method 2: Try direct download if repository failed
if [ "$SPEEDTEST_SUCCESS" = false ]; then
    log_info "Trying direct speedtest binary download..."
    # Get the latest version from the official site
    SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
    if curl -L "$SPEEDTEST_URL" -o /tmp/speedtest.tgz 2>/dev/null &&
       tar -xzf /tmp/speedtest.tgz -C /tmp 2>/dev/null &&
       sudo mv /tmp/speedtest /usr/local/bin/ 2>/dev/null &&
       sudo chmod +x /usr/local/bin/speedtest 2>/dev/null; then
        log_success "Speedtest CLI installed via direct download"
        SPEEDTEST_SUCCESS=true
        rm -f /tmp/speedtest.tgz 2>/dev/null
    fi
fi

# Method 3: Python speedtest-cli as fallback
if [ "$SPEEDTEST_SUCCESS" = false ]; then
    log_info "Installing Python speedtest-cli as fallback..."
    if pip3 install speedtest-cli 2>/dev/null; then
        log_success "Python speedtest-cli installed as fallback"
        SPEEDTEST_SUCCESS=true
        log_info "Note: Use 'speedtest-cli' command (not 'speedtest')"
    fi
fi

# Method 4: Try snap installation as final fallback
if [ "$SPEEDTEST_SUCCESS" = false ]; then
    log_info "Trying snap installation as final fallback..."
    if command -v snap >/dev/null 2>&1; then
        if sudo snap install speedtest-cli 2>/dev/null; then
            log_success "Speedtest CLI installed via snap"
            SPEEDTEST_SUCCESS=true
        fi
    fi
fi

if [ "$SPEEDTEST_SUCCESS" = true ]; then
    log_success "Speedtest CLI installation completed"
    # Verify installation
    if command -v speedtest >/dev/null 2>&1; then
        log_success "Speedtest CLI verified: $(speedtest --version 2>/dev/null || echo 'Available')"
    elif command -v speedtest-cli >/dev/null 2>&1; then
        log_success "Python speedtest-cli verified: $(speedtest-cli --version 2>/dev/null || echo 'Available')"
    fi
else
    log_warning "Speedtest CLI installation failed - you can install it manually later"
    log_info "Manual installation options:"
    log_info "1. Via pip: pip3 install speedtest-cli"
    log_info "2. Via snap: sudo snap install speedtest-cli"
fi

# Cleanup
log_info "Cleaning up..."
sudo apt autoremove -y
sudo apt autoclean
log_success "Cleanup completed"

# Post-installation information
echo ""
log_success "🎉 Ubuntu Server One-Click Setup Complete!"
echo ""
log_info "Next steps for authentication and configuration:"
echo ""
echo "1. GitHub CLI Authentication:"
echo "   gh auth login"
echo ""
echo "2. Tailscale Authentication:"
echo "   sudo tailscale up"
echo ""
echo "3. Docker (logout and login to use without sudo):"
echo "   newgrp docker  # or logout/login"
echo ""
echo "4. Mullvad VPN Configuration:"
echo "   mullvad account login <account-number>"
echo ""
echo "5. Infisical Authentication:"
echo "   infisical login"
echo ""
echo "6. Yazi File Manager:"
echo "   yazi  # Launch file manager"
echo ""
echo "7. Speedtest CLI:"
echo "   speedtest  # Test internet speed"
echo ""
log_info "Installation Summary:"
echo "• Git: $(git --version 2>/dev/null || echo 'Not installed')"
if [ "$GITHUB_CLI_SUCCESS" = true ]; then
    echo "• GitHub CLI: $(gh --version 2>/dev/null | head -n1 || echo 'Installed but version check failed')"
else
    echo "• GitHub CLI: SKIPPED (GPG key or repository issue)"
fi
if [ "$DOCKER_SUCCESS" = true ]; then
    echo "• Docker: $(docker --version 2>/dev/null || echo 'Installed but version check failed')"
else
    echo "• Docker: SKIPPED (GPG key or repository issue)"
fi
if [ "$TAILSCALE_SUCCESS" = true ]; then
    echo "• Tailscale: $(tailscale version 2>/dev/null || echo 'Installed')"
else
    echo "• Tailscale: SKIPPED (GPG key or repository issue)"
fi
if [ "$MULLVAD_SUCCESS" = true ]; then
    echo "• Mullvad VPN: Installed"
else
    echo "• Mullvad VPN: SKIPPED (GPG key or repository issue)"
fi
if [ "$INFISICAL_SUCCESS" = true ]; then
    echo "• Infisical CLI: Installed"
else
    echo "• Infisical CLI: SKIPPED (no ARM64 build available)"
fi
if [ "$NODE_SUCCESS" = true ]; then
    echo "• Node.js: $(node --version 2>/dev/null || echo 'Installed but version check failed')"
else
    echo "• Node.js: SKIPPED (repository issue)"
fi
echo "• Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
if [ "$YAZI_SUCCESS" = true ]; then
    echo "• Yazi file manager: $(yazi --version 2>/dev/null || echo 'Installed')"
else
    echo "• Yazi file manager: SKIPPED (installation failed)"
fi
if [ "$SPEEDTEST_SUCCESS" = true ]; then
    echo "• Speedtest CLI: $(speedtest --version 2>/dev/null || echo 'Installed')"
else
    echo "• Speedtest CLI: SKIPPED (installation failed)"
fi
echo "• tmux: $(tmux -V 2>/dev/null || echo 'Installed')"
echo ""

# Show what needs manual attention
if [ "$GITHUB_CLI_SUCCESS" = false ] || [ "$DOCKER_SUCCESS" = false ] || [ "$TAILSCALE_SUCCESS" = false ] || [ "$MULLVAD_SUCCESS" = false ] || [ "$INFISICAL_SUCCESS" = false ] || [ "$NODE_SUCCESS" = false ] || [ "$YAZI_SUCCESS" = false ] || [ "$SPEEDTEST_SUCCESS" = false ]; then
    log_warning "Some packages were skipped due to compatibility or repository issues."
    log_info "These can be installed manually later using their official installation methods."
fi

log_warning "Please reboot or logout/login to ensure all group changes take effect."

# Automatic reboot option
echo ""
log_info "Setup completed! The system will reboot in 10 seconds to ensure all changes take effect."
log_info "Press Ctrl+C to cancel the reboot if you want to stay logged in."
echo ""

# Countdown
for i in 10 9 8 7 6 5 4 3 2 1; do
    echo -n "Rebooting in $i seconds... "
    sleep 1
    echo ""
done

log_info "Rebooting now..."
sudo reboot