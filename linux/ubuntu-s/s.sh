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
    
    if [ "$DESKTOP_SUCCESS" = true ]; then
        ((additional_success_count++))
    fi
    ((additional_attempted++))
    
    if [ "$CHROME_SUCCESS" = true ]; then
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

# Install Google Cloud CLI
log_info "Installing Google Cloud CLI..."
GCLOUD_SUCCESS=false

# Add Google Cloud SDK repository
log_info "Adding Google Cloud SDK repository..."
if curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg; then
    sudo chmod 644 /usr/share/keyrings/cloud.google.gpg
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
    
    # Update package lists
    log_info "Updating package lists after adding Google Cloud SDK repository..."
    if retry_command sudo apt update; then
        log_success "Package lists updated successfully"
        
        # Install Google Cloud CLI
        log_info "Installing Google Cloud CLI package..."
        if retry_command sudo apt install -y google-cloud-cli; then
            log_success "Google Cloud CLI installed successfully"
            GCLOUD_SUCCESS=true
        else
            log_warning "Google Cloud CLI installation failed, continuing with other packages"
        fi
    else
        log_error "Failed to update package lists - removing Google Cloud SDK repository"
        sudo rm -f /etc/apt/sources.list.d/google-cloud-sdk.list /usr/share/keyrings/cloud.google.gpg
        retry_command sudo apt update
        log_warning "Skipping Google Cloud CLI installation due to repository issues"
    fi
else
    log_error "Failed to download Google Cloud SDK GPG key"
    log_warning "Skipping Google Cloud CLI installation"
fi

if [ "$GCLOUD_SUCCESS" = false ]; then
    log_warning "Google Cloud CLI installation was skipped or failed"
    log_info "You can install it manually later with: curl https://sdk.cloud.google.com | bash"
fi

# Install QEMU virtualization
log_info "Installing QEMU virtualization..."
QEMU_SUCCESS=false

if retry_command sudo apt install -y qemu-kvm qemu-system qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager; then
    log_success "QEMU and virtualization tools installed"
    
    # Add user to libvirt groups
    sudo usermod -aG libvirt,kvm $(whoami)
    log_info "Added user to libvirt and kvm groups"
    QEMU_SUCCESS=true
else
    log_warning "QEMU installation failed, continuing with other packages"
fi

if [ "$QEMU_SUCCESS" = false ]; then
    log_warning "QEMU installation was skipped or failed"
fi

# Install ZSH and plugins
log_info "Installing ZSH and plugins..."
ZSH_SUCCESS=false

# Install ZSH first
if retry_command sudo apt install -y zsh; then
    log_success "ZSH installed"
    
    # Install ZSH plugins via apt (more reliable than git)
    log_info "Installing ZSH plugins..."
    if retry_command sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting; then
        log_success "ZSH plugins installed via apt"
        ZSH_SUCCESS=true
    else
        log_warning "ZSH plugins installation via apt failed, trying manual installation..."
    fi
    
    # Fallback: Install plugins manually if apt failed
    if [ "$ZSH_SUCCESS" = false ]; then
        log_info "Installing ZSH plugins manually..."
        ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
        
        # Create custom directory if it doesn't exist
        mkdir -p "$ZSH_CUSTOM_DIR/plugins" 2>/dev/null
        
        # Install zsh-autosuggestions
        if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
            if git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" 2>/dev/null; then
                log_success "zsh-autosuggestions installed manually"
            fi
        fi
        
        # Install zsh-syntax-highlighting
        if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
            if git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" 2>/dev/null; then
                log_success "zsh-syntax-highlighting installed manually"
            fi
        fi
        
        # Install zsh-autocomplete
        if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autocomplete" ]; then
            if git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_CUSTOM_DIR/plugins/zsh-autocomplete" 2>/dev/null; then
                log_success "zsh-autocomplete installed manually"
            fi
        fi
        
        ZSH_SUCCESS=true
    fi
    
    # Create a basic .zshrc configuration if it doesn't exist
    if [ ! -f ~/.zshrc ]; then
        log_info "Creating basic .zshrc configuration..."
        cat > ~/.zshrc << 'EOF'
# Basic ZSH configuration
export ZSH="$HOME/.oh-my-zsh"

# Enable plugins
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-autocomplete
)

# Load Oh My Zsh if available
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source $ZSH/oh-my-zsh.sh
fi

# Load system-wide plugins if installed via apt
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Load manually installed plugins
if [ -f ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [ -f ~/.oh-my-zsh/custom/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]; then
    source ~/.oh-my-zsh/custom/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh
fi

# Initialize zoxide if available
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# Common aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'

# Set default editor
export EDITOR=vim

# History configuration
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
EOF
        log_success "Basic .zshrc configuration created"
    fi
    
    # Suggest changing default shell
    log_info "To make ZSH your default shell, run: chsh -s $(which zsh)"
else
    log_warning "ZSH installation failed"
fi

if [ "$ZSH_SUCCESS" = false ]; then
    log_warning "ZSH and plugins installation was skipped or failed"
fi

# Install Browser Automation Tools
log_info "Installing browser automation tools..."
BROWSER_AUTOMATION_SUCCESS=false

# Install core browser automation packages
log_info "Installing Chromium and automation dependencies..."
if retry_command sudo apt install -y chromium-browser xvfb fonts-liberation libxss1 libappindicator3-1 libindicator7 xdg-utils; then
    log_success "Chromium and X11 dependencies installed"
    
    # Install ChromeDriver
    log_info "Installing ChromeDriver..."
    CHROMEDRIVER_SUCCESS=false
    
    # Method 1: Try installing via apt
    if retry_command sudo apt install -y chromium-chromedriver; then
        log_success "ChromeDriver installed via apt"
        CHROMEDRIVER_SUCCESS=true
    else
        # Method 2: Manual download and installation
        log_info "Downloading ChromeDriver manually..."
        CHROME_VERSION=$(chromium-browser --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)
        if [ -n "$CHROME_VERSION" ]; then
            CHROME_MAJOR_VERSION=$(echo "$CHROME_VERSION" | cut -d. -f1)
            CHROMEDRIVER_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip"
            
            if curl -L "$CHROMEDRIVER_URL" -o /tmp/chromedriver.zip 2>/dev/null &&
               unzip -q /tmp/chromedriver.zip -d /tmp 2>/dev/null &&
               sudo mv /tmp/chromedriver-linux64/chromedriver /usr/local/bin/ 2>/dev/null &&
               sudo chmod +x /usr/local/bin/chromedriver 2>/dev/null; then
                log_success "ChromeDriver installed manually"
                CHROMEDRIVER_SUCCESS=true
                rm -rf /tmp/chromedriver.zip /tmp/chromedriver-linux64 2>/dev/null
            else
                log_warning "ChromeDriver manual installation failed"
            fi
        fi
    fi
    
    # Install Python automation packages
    log_info "Installing Python automation packages..."
    PYTHON_AUTOMATION_SUCCESS=false
    if pip3 install selenium webdriver-manager pyvirtualdisplay pandas beautifulsoup4 requests undetected-chromedriver 2>/dev/null; then
        log_success "Python automation packages installed"
        PYTHON_AUTOMATION_SUCCESS=true
    else
        log_warning "Some Python packages may have failed to install"
    fi
    
    # Install Node.js automation packages (Puppeteer)
    log_info "Installing Node.js automation packages..."
    NODEJS_AUTOMATION_SUCCESS=false
    if command -v npm >/dev/null 2>&1; then
        # Install Puppeteer globally
        if npm install -g puppeteer playwright 2>/dev/null; then
            log_success "Puppeteer and Playwright installed globally"
            NODEJS_AUTOMATION_SUCCESS=true
        else
            log_warning "Node.js automation packages installation failed"
        fi
    else
        log_warning "npm not available - skipping Node.js automation packages"
    fi
    
    # Create browser automation directories and example scripts
    log_info "Setting up browser automation environment..."
    mkdir -p ~/browser_automation/{chrome_profiles,scripts,downloads} 2>/dev/null
    mkdir -p ~/browser_automation/chrome_profiles/{work,personal,automation,testing} 2>/dev/null
    
    # Create example Puppeteer script
    cat > ~/browser_automation/scripts/puppeteer_example.js << 'EOF'
const puppeteer = require('puppeteer');

const profiles = [
  { name: 'work', port: 9222 },
  { name: 'personal', port: 9223 },
  { name: 'automation', port: 9224 }
];

async function runProfile(profile) {
  console.log(`[${profile.name}] Starting browser automation...`);
  
  const browser = await puppeteer.launch({
    headless: 'new', // Use new headless mode
    userDataDir: `../chrome_profiles/${profile.name}`,
    args: [
      `--remote-debugging-port=${profile.port}`,
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--disable-gpu'
    ]
  });

  const page = await browser.newPage();
  
  // Set user agent to avoid detection
  await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
  
  // Example automation
  await page.goto('https://httpbin.org/user-agent');
  const title = await page.title();
  console.log(`[${profile.name}] Page title: ${title}`);
  
  // Take screenshot
  await page.screenshot({ 
    path: `../downloads/${profile.name}_screenshot.png`,
    fullPage: true 
  });
  
  await browser.close();
  console.log(`[${profile.name}] Automation completed`);
}

// Run automation for all profiles
async function runAll() {
  for (const profile of profiles) {
    await runProfile(profile);
  }
}

runAll().catch(console.error);
EOF

    # Create example Python script with undetected ChromeDriver
    cat > ~/browser_automation/scripts/undetected_selenium_example.py << 'EOF'
#!/usr/bin/env python3
import undetected_chromedriver as uc
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
import time
import os

def create_undetected_driver(profile_name):
    """Create an undetected ChromeDriver instance"""
    profile_path = f"../chrome_profiles/{profile_name}"
    
    # Create profile directory if it doesn't exist
    os.makedirs(profile_path, exist_ok=True)
    
    options = uc.ChromeOptions()
    options.add_argument(f"--user-data-dir={profile_path}")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_experimental_option("excludeSwitches", ["enable-automation"])
    options.add_experimental_option('useAutomationExtension', False)
    
    # For headless mode (uncomment if needed)
    # options.add_argument("--headless=new")
    
    driver = uc.Chrome(options=options)
    driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    
    return driver

def test_automation():
    """Example automation with undetected ChromeDriver"""
    profiles = ['work', 'personal', 'automation']
    
    for profile in profiles:
        print(f"[{profile}] Starting undetected browser automation...")
        
        driver = create_undetected_driver(profile)
        
        try:
            # Test anti-bot detection
            driver.get("https://bot.sannysoft.com/")
            time.sleep(3)
            
            # Take screenshot
            screenshot_path = f"../downloads/{profile}_bot_test.png"
            driver.save_screenshot(screenshot_path)
            print(f"[{profile}] Screenshot saved: {screenshot_path}")
            
            # Check if detected as bot
            page_source = driver.page_source
            if "You are a bot" in page_source:
                print(f"[{profile}] ❌ Detected as bot")
            else:
                print(f"[{profile}] ✅ Not detected as bot")
                
        except Exception as e:
            print(f"[{profile}] Error: {e}")
        finally:
            driver.quit()
            print(f"[{profile}] Browser closed")

if __name__ == "__main__":
    test_automation()
EOF

    # Create XVFB wrapper script
    cat > ~/browser_automation/scripts/xvfb_run.sh << 'EOF'
#!/bin/bash
# XVFB wrapper for running GUI applications headlessly

if [ $# -eq 0 ]; then
    echo "Usage: $0 <command> [args...]"
    echo "Example: $0 python3 selenium_script.py"
    exit 1
fi

echo "Starting virtual display..."
exec xvfb-run -a --server-args="-screen 0 1920x1080x24 -dpi 96" "$@"
EOF

    # Create profile initializer script
    cat > ~/browser_automation/scripts/init_profiles.sh << 'EOF'
#!/bin/bash
# Initialize Chrome profiles without GUI

PROFILES=("work" "personal" "automation" "testing")

for profile in "${PROFILES[@]}"; do
    echo "Initializing profile: $profile"
    
    # Create profile directory
    mkdir -p "../chrome_profiles/$profile"
    
    # Start temporary instance to create profile structure
    chromium-browser \
        --user-data-dir="../chrome_profiles/$profile" \
        --headless=new \
        --no-first-run \
        --no-default-browser-check \
        --disable-default-apps \
        --remote-debugging-port=$((9222 + $(echo "$profile" | wc -c))) \
        about:blank &
    
    # Wait for profile creation
    sleep 5
    
    # Kill the instance
    pkill -f "user-data-dir=.*chrome_profiles/$profile"
    
    echo "Profile $profile initialized"
done

echo "All profiles initialized successfully!"
EOF

    # Make scripts executable
    chmod +x ~/browser_automation/scripts/*.sh
    chmod +x ~/browser_automation/scripts/*.py
    
    # Create README with usage instructions
    cat > ~/browser_automation/README.md << 'EOF'
# Browser Automation Setup

## Quick Start

### 1. Initialize Chrome Profiles
```bash
cd ~/browser_automation/scripts
./init_profiles.sh
```

### 2. Run Puppeteer Automation
```bash
cd ~/browser_automation/scripts
node puppeteer_example.js
```

### 3. Run Undetected Selenium
```bash
cd ~/browser_automation/scripts
python3 undetected_selenium_example.py
```

### 4. Run with Virtual Display (if needed)
```bash
cd ~/browser_automation/scripts
./xvfb_run.sh python3 undetected_selenium_example.py
```

## Directory Structure
- `chrome_profiles/`: Browser profiles (work, personal, automation, testing)
- `scripts/`: Automation scripts and utilities
- `downloads/`: Screenshots and downloaded files

## Available Tools
- **Chromium**: Headless browser engine
- **ChromeDriver**: WebDriver for Selenium
- **Puppeteer**: Node.js browser automation
- **Playwright**: Modern browser automation
- **Undetected ChromeDriver**: Anti-detection Selenium
- **XVFB**: Virtual display for GUI-required scenarios

## Tips
- Use undetected ChromeDriver for sites with bot detection
- Enable headless mode by uncommenting headless options
- Profiles persist data between runs
- Screenshots and downloads go to `downloads/` folder
EOF

    log_success "Browser automation environment set up"
    log_info "Automation scripts created in ~/browser_automation/"
    
    BROWSER_AUTOMATION_SUCCESS=true
else
    log_warning "Browser automation tools installation failed"
fi

if [ "$BROWSER_AUTOMATION_SUCCESS" = true ]; then
    log_success "Browser automation tools installation completed"
    log_info "Example scripts available in ~/browser_automation/scripts/"
    log_info "Run 'cd ~/browser_automation && cat README.md' for usage instructions"
else
    log_warning "Browser automation tools installation was skipped or failed"
fi

# Initialize desktop and chrome success flags
DESKTOP_SUCCESS=false
CHROME_SUCCESS=false

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
        
        # Detect if we're in a resource-constrained environment (VM/container)
        timeout_duration=900  # Default 15 minutes
        cpu_cores=$(nproc 2>/dev/null || echo "1")
        total_mem=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo "1024")
        
        # Increase timeout for resource-constrained environments
        if [ "$cpu_cores" -le 2 ] || [ "$total_mem" -le 2048 ]; then
            timeout_duration=3600  # 1 hour for VMs/low-resource systems
            log_info "Detected resource-constrained environment (${cpu_cores} cores, ${total_mem}MB RAM)"
            log_info "Using extended timeout (60 minutes) for Rust compilation"
        else
            log_info "Detected powerful system (${cpu_cores} cores, ${total_mem}MB RAM)"
            log_info "Using standard timeout (15 minutes) for Rust compilation"
        fi
        
        log_info "Building Yazi (this may take a while - up to $((timeout_duration/60)) minutes)..."
        echo "Progress: Starting Rust compilation..."
        
        # Create a background process to show progress dots
        show_progress() {
            local count=0
            while kill -0 $1 2>/dev/null; do
                case $((count % 4)) in
                    0) echo -ne "\rProgress: Compiling Rust crates.   " ;;
                    1) echo -ne "\rProgress: Compiling Rust crates..  " ;;
                    2) echo -ne "\rProgress: Compiling Rust crates... " ;;
                    3) echo -ne "\rProgress: Compiling Rust crates...." ;;
                esac
                sleep 2
                count=$((count + 1))
                
                # Show elapsed time every minute
                if [ $((count % 30)) -eq 0 ]; then
                    elapsed=$((count * 2 / 60))
                    echo -ne "\rProgress: ${elapsed} minutes elapsed, still compiling..."
                    sleep 2
                fi
            done
            echo -e "\rProgress: Compilation finished.                    "
        }
        
        # Run cargo in background and capture both stdout and stderr to log
        (
            timeout "$timeout_duration" cargo install --locked yazi-fm yazi-cli 2>&1
            echo "CARGO_EXIT_CODE=$?" > /tmp/cargo_exit_code
        ) >> "$LOG_FILE" 2>&1 &
        cargo_pid=$!
        
        # Show progress while cargo runs
        show_progress $cargo_pid
        
        # Wait for cargo to finish
        wait $cargo_pid
        
        # Get the exit code
        if [ -f /tmp/cargo_exit_code ]; then
            source /tmp/cargo_exit_code
            rm -f /tmp/cargo_exit_code
        else
            CARGO_EXIT_CODE=1
        fi
        
        if [ "$CARGO_EXIT_CODE" -eq 0 ]; then
            log_success "Yazi installed via cargo"
            YAZI_SUCCESS=true
        else
            log_warning "Cargo installation failed or timed out after $((timeout_duration/60)) minutes"
            log_info "Check log file for detailed compilation output: $LOG_FILE"
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

# Install Desktop Environment (Ubuntu Desktop)
log_info "Installing Ubuntu Desktop Environment..."
DESKTOP_SUCCESS=false

# Install Ubuntu Desktop
if retry_command sudo apt install -y ubuntu-desktop-minimal; then
    log_success "Ubuntu Desktop Environment installed"
    DESKTOP_SUCCESS=true
else
    log_warning "Ubuntu Desktop installation failed, trying alternative..."
    # Try installing just the essential desktop components
    if retry_command sudo apt install -y xorg xfce4 xfce4-goodies lightdm; then
        log_success "XFCE Desktop Environment installed as alternative"
        DESKTOP_SUCCESS=true
    else
            log_warning "Desktop environment installation failed"
fi

# Configure SSH server (after desktop environment)
log_info "Configuring SSH server..."
sudo systemctl enable ssh
sudo systemctl start ssh
sudo ufw allow ssh
log_success "SSH server configured and enabled"
log_info "SSH is now enabled and will start automatically on boot"
fi

# Install Google Chrome
log_info "Installing Google Chrome..."
CHROME_SUCCESS=false

# Add Google Chrome repository
log_info "Adding Google Chrome repository..."
if wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add - 2>/dev/null; then
    if echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null; then
        # Try to update package lists, but don't fail if some repositories are broken
        log_info "Updating package lists..."
        if sudo apt update 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Package lists updated successfully"
        else
            log_warning "Package list update had some issues, but continuing with Chrome installation..."
        fi
        
        # Try to install Chrome directly
        log_info "Installing Google Chrome..."
        if sudo apt install -y google-chrome-stable 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Google Chrome installed successfully"
            CHROME_SUCCESS=true
        else
            log_warning "Google Chrome installation failed, trying alternative method..."
            
            # Alternative installation method
            log_info "Trying alternative Chrome installation method..."
            if wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb 2>/dev/null; then
                if sudo dpkg -i /tmp/google-chrome.deb 2>&1 | tee -a "$LOG_FILE"; then
                    sudo apt-get install -f -y 2>&1 | tee -a "$LOG_FILE" || true
                    log_success "Google Chrome installed successfully via direct download"
                    CHROME_SUCCESS=true
                else
                    log_warning "Alternative Chrome installation also failed"
                fi
                rm -f /tmp/google-chrome.deb
            else
                log_warning "Failed to download Chrome package directly"
            fi
        fi
    else
        log_warning "Failed to add Google Chrome repository"
    fi
else
    log_warning "Failed to add Google Chrome GPG key"
fi

# Install Chrome Profile Sync System
if [ "$CHROME_SUCCESS" = true ]; then
    log_info "Setting up Chrome Profile Sync System..."
    
    # Create profile_sync directory in user's home
    PROFILE_SYNC_DIR="$HOME/profile_sync"
    mkdir -p "$PROFILE_SYNC_DIR"
    
    # Copy profile sync scripts from the config repository
    if [ -d "profile_sync" ]; then
        log_info "Copying profile sync scripts from local repository..."
        cp -r profile_sync/* "$PROFILE_SYNC_DIR/"
        chmod +x "$PROFILE_SYNC_DIR/scripts/"*.sh 2>/dev/null || true
        chmod +x "$PROFILE_SYNC_DIR/demo.sh" 2>/dev/null || true
        log_success "Profile sync scripts copied to $PROFILE_SYNC_DIR"
    else
        log_info "Creating profile sync scripts..."
        
        # Create basic profile sync structure
        mkdir -p "$PROFILE_SYNC_DIR/scripts" "$PROFILE_SYNC_DIR/config" "$PROFILE_SYNC_DIR/backups"
        
        # Create a simple download script for immediate use
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

        # Create a simple upload script
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
        log_success "Basic profile sync scripts created in $PROFILE_SYNC_DIR"
    fi
    
    # Create a post-installation script for Chrome profile sync setup
    cat > "$HOME/setup-chrome-sync.sh" << 'EOF'
#!/bin/bash
echo "🔧 Chrome Profile Sync Setup"
echo "============================"
echo ""
echo "This script will help you set up Chrome profile syncing with your Raspberry Pi."
echo ""
echo "Prerequisites:"
echo "• Raspberry Pi accessible at 192.168.1.9"
echo "• SSH access to user 'wgr0' on the Pi"
echo ""

# Setup SSH key if not exists
if [ ! -f "$HOME/.ssh/id_rsa" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -C "chrome-sync-$(hostname)" -f "$HOME/.ssh/id_rsa" -N ""
fi

# Copy SSH key to Pi
echo "Setting up SSH key authentication with Raspberry Pi..."
echo "You may need to enter your password for the Raspberry Pi:"
ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" wgr0@192.168.1.9

# Test connection
echo "Testing connection..."
if ssh -o ConnectTimeout=10 wgr0@192.168.1.9 "echo 'Connection successful'" >/dev/null 2>&1; then
    echo "✅ SSH connection successful!"
    echo ""
    echo "🚀 Chrome Profile Sync is ready!"
    echo ""
    echo "Usage:"
    echo "• Download profile from Pi: cd ~/profile_sync && ./scripts/download.sh"
    echo "• Upload profile to Pi: cd ~/profile_sync && ./scripts/upload.sh"
    echo ""
    echo "First time setup:"
    echo "1. Run Chrome once to create profile"
    echo "2. Upload your profile: ./scripts/upload.sh"
    echo "3. Download on other machines: ./scripts/download.sh"
else
    echo "❌ SSH connection failed"
    echo "Please check your Pi IP address and SSH configuration"
fi
EOF

    chmod +x "$HOME/setup-chrome-sync.sh"
    log_success "Chrome profile sync setup script created: ~/setup-chrome-sync.sh"
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
echo "5. Google Cloud CLI Authentication:"
echo "   gcloud auth login"
echo "   gcloud config set project YOUR_PROJECT_ID"
echo ""
echo "6. ZSH as Default Shell (optional):"
echo "   chsh -s \$(which zsh)  # Then logout/login"
echo ""
echo "7. QEMU/KVM Virtualization:"
echo "   # Groups added - logout/login to use without sudo"
echo "   virt-manager  # GUI for managing VMs"
echo ""
echo "8. Infisical Authentication:"
echo "   infisical login"
echo ""
echo "9. Yazi File Manager:"
echo "   yazi  # Launch file manager"
echo ""
echo "10. Speedtest CLI:"
echo "    speedtest  # Test internet speed"
echo ""
echo "11. Zoxide (smart cd):"
echo "    z <directory_name>  # Jump to frequently used directories"
echo ""
echo "12. Browser Automation:"
echo "    cd ~/browser_automation/scripts"
echo "    ./init_profiles.sh  # Initialize Chrome profiles"
echo "    node puppeteer_example.js  # Run Puppeteer automation"
echo "    python3 undetected_selenium_example.py  # Anti-detection automation"
echo ""
echo "13. Desktop Environment:"
if [ "$DESKTOP_SUCCESS" = true ]; then
    echo "    ✅ Desktop environment installed - reboot to access GUI"
else
    echo "    ⚠️  Desktop installation failed - install manually: sudo apt install ubuntu-desktop"
fi
echo ""
echo "14. Google Chrome Profile Sync:"
if [ "$CHROME_SUCCESS" = true ]; then
    echo "    ✅ Chrome installed - setup profile sync: ~/setup-chrome-sync.sh"
    echo "    • Upload profile to Pi: cd ~/profile_sync && ./scripts/upload.sh"
    echo "    • Download profile from Pi: cd ~/profile_sync && ./scripts/download.sh"
else
    echo "    ⚠️  Chrome installation failed - install manually"
fi
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
if [ "$GCLOUD_SUCCESS" = true ]; then
    echo "• Google Cloud CLI: $(gcloud --version 2>/dev/null | head -n1 || echo 'Installed')"
else
    echo "• Google Cloud CLI: SKIPPED (GPG key or repository issue)"
fi
if [ "$QEMU_SUCCESS" = true ]; then
    echo "• QEMU: $(qemu-system-x86_64 --version 2>/dev/null | head -n1 || echo 'Installed')"
else
    echo "• QEMU: SKIPPED (installation failed)"
fi
if [ "$ZSH_SUCCESS" = true ]; then
    echo "• ZSH with plugins: $(zsh --version 2>/dev/null || echo 'Installed')"
else
    echo "• ZSH with plugins: SKIPPED (installation failed)"
fi
if [ "$BROWSER_AUTOMATION_SUCCESS" = true ]; then
    echo "• Browser Automation: Chromium + ChromeDriver + Puppeteer + Undetected ChromeDriver"
else
    echo "• Browser Automation: SKIPPED (installation failed)"
fi
if [ "$DESKTOP_SUCCESS" = true ]; then
    echo "• Desktop Environment: Ubuntu Desktop (reboot to access GUI)"
else
    echo "• Desktop Environment: SKIPPED (installation failed)"
fi
if [ "$CHROME_SUCCESS" = true ]; then
    echo "• Google Chrome: $(google-chrome --version 2>/dev/null | head -n1 || echo 'Installed')"
    echo "• Chrome Profile Sync: Setup script created (~/setup-chrome-sync.sh)"
else
    echo "• Google Chrome: SKIPPED (installation failed)"
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
echo "• Zoxide: $(zoxide --version 2>/dev/null || echo 'Installed')"
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
if [ "$GITHUB_CLI_SUCCESS" = false ] || [ "$DOCKER_SUCCESS" = false ] || [ "$TAILSCALE_SUCCESS" = false ] || [ "$MULLVAD_SUCCESS" = false ] || [ "$GCLOUD_SUCCESS" = false ] || [ "$QEMU_SUCCESS" = false ] || [ "$ZSH_SUCCESS" = false ] || [ "$BROWSER_AUTOMATION_SUCCESS" = false ] || [ "$DESKTOP_SUCCESS" = false ] || [ "$CHROME_SUCCESS" = false ] || [ "$INFISICAL_SUCCESS" = false ] || [ "$NODE_SUCCESS" = false ] || [ "$YAZI_SUCCESS" = false ] || [ "$SPEEDTEST_SUCCESS" = false ]; then
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