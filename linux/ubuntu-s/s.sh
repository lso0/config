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
    if [[ $exit_code -eq 0 ]]; then
        log_success "Ubuntu setup completed! Log saved: $LOG_FILE"
    else
        log_error "Ubuntu setup failed with exit code $exit_code. Check log: $LOG_FILE"
    fi
    log_to_file "=== END UBUNTU SESSION ==="
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

# Install Infisical CLI
log_info "Installing Infisical CLI..."
ARCH=$(dpkg --print-architecture)
if [ "$ARCH" = "amd64" ]; then
    INFISICAL_ARCH="linux_amd64"
elif [ "$ARCH" = "arm64" ]; then
    INFISICAL_ARCH="linux_arm64"
else
    log_warning "Unsupported architecture for Infisical: $ARCH. Skipping..."
fi

if [ -n "${INFISICAL_ARCH:-}" ]; then
    retry_command curl -fsSL "https://github.com/Infisical/infisical/releases/latest/download/infisical_${INFISICAL_ARCH}.deb" -o infisical.deb
    sudo dpkg -i infisical.deb
    rm infisical.deb
    log_success "Infisical CLI installed"
fi

# Install Node.js (LTS) via NodeSource
log_info "Installing Node.js LTS..."

# Download and run NodeSource setup script with better error handling
NODEJS_SUCCESS=false
log_info "Downloading NodeSource setup script..."
if curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -; then
    log_success "NodeSource repository added successfully"
    
    # Install Node.js
    log_info "Installing Node.js package..."
    if retry_command sudo apt install -y nodejs; then
        log_success "Node.js installed: $(node --version)"
        NODEJS_SUCCESS=true
    else
        log_warning "Node.js installation failed, continuing with other packages"
    fi
else
    log_error "Failed to add NodeSource repository"
    log_warning "Skipping Node.js installation"
fi

if [ "$NODEJS_SUCCESS" = false ]; then
    log_warning "Node.js installation was skipped or failed"
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
if [ "$NODEJS_SUCCESS" = true ]; then
    echo "• Node.js: $(node --version 2>/dev/null || echo 'Installed but version check failed')"
else
    echo "• Node.js: SKIPPED (repository issue)"
fi
echo "• Python: $(python3 --version 2>/dev/null || echo 'Not installed')"
echo ""

# Show what needs manual attention
if [ "$GITHUB_CLI_SUCCESS" = false ] || [ "$DOCKER_SUCCESS" = false ] || [ "$TAILSCALE_SUCCESS" = false ] || [ "$MULLVAD_SUCCESS" = false ] || [ "$NODEJS_SUCCESS" = false ]; then
    log_warning "Some packages were skipped due to GPG key or repository issues."
    log_info "These can be installed manually later using their official installation methods."
fi

log_warning "Please reboot or logout/login to ensure all group changes take effect."