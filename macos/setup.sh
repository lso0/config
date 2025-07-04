#!/bin/bash

# macOS Setup Script
# Description: Automated setup for macOS systems
# Usage: curl -fsSL wgms.uk | bash

set -euo pipefail

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   log_error "This script should not be run as root"
   exit 1
fi

log_info "Starting macOS Setup..."

# Install Homebrew if not installed
if ! command -v brew &> /dev/null; then
    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    log_success "Homebrew installed"
else
    log_info "Homebrew already installed"
fi

# Update Homebrew
log_info "Updating Homebrew..."
brew update

# Install core tools
log_info "Installing core tools..."
brew install git curl wget

# Install GitHub CLI
log_info "Installing GitHub CLI..."
brew install gh

# Install Docker Desktop (requires manual interaction)
log_info "Installing Docker Desktop..."
brew install --cask docker

# Install Tailscale
log_info "Installing Tailscale..."
brew install --cask tailscale

# Install Mullvad VPN
log_info "Installing Mullvad VPN..."
brew install --cask mullvadvpn

# Install Infisical CLI
log_info "Installing Infisical CLI..."
brew install infisical/get-cli/infisical

# Install Node.js
log_info "Installing Node.js..."
brew install node

# Install Python
log_info "Installing Python..."
brew install python

# Install additional development tools
log_info "Installing additional tools..."
brew install jq htop tree tmux

# Install common cask applications
log_info "Installing common applications..."
brew install --cask visual-studio-code
brew install --cask iterm2

# Cleanup
log_info "Cleaning up..."
brew cleanup

log_success "🎉 macOS Setup Complete!"
log_info "Next steps for authentication:"
echo ""
echo "1. GitHub CLI: gh auth login"
echo "2. Tailscale: Open Tailscale app and login"
echo "3. Docker: Open Docker Desktop and complete setup"
echo "4. Mullvad VPN: Open Mullvad app and login"
echo "5. Infisical: infisical login"
echo ""
log_info "Applications installed:"
echo "• Git: $(git --version)"
echo "• GitHub CLI: $(gh --version | head -n1)"
echo "• Node.js: $(node --version)"
echo "• Python: $(python3 --version)"
echo "• Docker: Open Docker Desktop to complete setup" 