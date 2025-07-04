#!/bin/bash

# Ubuntu Server One-Click Setup Script
# Description: Automated setup for fresh Ubuntu server installations
# Usage: curl -fsSL <your-script-url> | bash

set -euo pipefail  # Enhanced error handling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to retry commands with exponential backoff
retry_command() {
    local max_attempts=3
    local delay=1
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "Command failed after $max_attempts attempts: $*"
                return 1
            fi
            log_warning "Attempt $attempt failed. Retrying in ${delay}s..."
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

log_info "Starting Ubuntu Server One-Click Setup..."

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
retry_command curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
retry_command sudo apt update
retry_command sudo apt install -y gh
log_success "GitHub CLI installed"

# Install Docker
log_info "Installing Docker..."
retry_command sudo apt install -y ca-certificates gnupg
sudo install -m 0755 -d /etc/apt/keyrings
retry_command curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
retry_command sudo apt update
retry_command sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker
log_success "Docker installed and configured"

# Install Tailscale
log_info "Installing Tailscale..."
retry_command curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tailscale.list
retry_command sudo apt update
retry_command sudo apt install -y tailscale
sudo systemctl enable --now tailscaled
log_success "Tailscale installed and started"

# Install Mullvad VPN
log_info "Installing Mullvad VPN..."
retry_command curl -fsSL https://repository.mullvad.net/deb/mullvad-keyring.asc | sudo gpg --dearmor -o /usr/share/keyrings/mullvad-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.gpg arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mullvad.list
retry_command sudo apt update
retry_command sudo apt install -y mullvad-vpn
log_success "Mullvad VPN installed"

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
retry_command curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
retry_command sudo apt install -y nodejs
log_success "Node.js installed: $(node --version)"

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
log_info "Installed versions:"
echo "• Git: $(git --version)"
echo "• GitHub CLI: $(gh --version | head -n1)"
echo "• Docker: $(docker --version)"
echo "• Node.js: $(node --version)"
echo "• Python: $(python3 --version)"
echo ""
log_warning "Please reboot or logout/login to ensure all group changes take effect."