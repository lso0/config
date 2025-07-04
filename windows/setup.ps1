# Windows Setup Script
# Description: Automated setup for Windows systems
# Usage: Invoke-WebRequest -Uri "https://wgms.uk/windows/setup.ps1" | Invoke-Expression

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator" -ForegroundColor Red
    Write-Host "Please right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}

Write-Host "Starting Windows Setup..." -ForegroundColor Blue

# Install winget if not available (Windows 10/11)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Windows Package Manager (winget)..." -ForegroundColor Yellow
    # This typically requires manual installation from Microsoft Store
    Write-Host "Please install winget from Microsoft Store first" -ForegroundColor Red
    exit 1
}

# Update winget sources
Write-Host "Updating package sources..." -ForegroundColor Blue
winget source update

# Install core tools
Write-Host "Installing core tools..." -ForegroundColor Blue
winget install --id Git.Git -e --source winget
winget install --id Microsoft.PowerShell -e --source winget

# Install GitHub CLI
Write-Host "Installing GitHub CLI..." -ForegroundColor Blue
winget install --id GitHub.cli -e --source winget

# Install Docker Desktop
Write-Host "Installing Docker Desktop..." -ForegroundColor Blue
winget install --id Docker.DockerDesktop -e --source winget

# Install Tailscale
Write-Host "Installing Tailscale..." -ForegroundColor Blue
winget install --id Tailscale.Tailscale -e --source winget

# Install Mullvad VPN
Write-Host "Installing Mullvad VPN..." -ForegroundColor Blue
winget install --id MullvadVPN.MullvadVPN -e --source winget

# Install Node.js
Write-Host "Installing Node.js..." -ForegroundColor Blue
winget install --id OpenJS.NodeJS -e --source winget

# Install Python
Write-Host "Installing Python..." -ForegroundColor Blue
winget install --id Python.Python.3.11 -e --source winget

# Install additional development tools
Write-Host "Installing additional tools..." -ForegroundColor Blue
winget install --id Microsoft.VisualStudioCode -e --source winget
winget install --id Microsoft.WindowsTerminal -e --source winget
winget install --id 7zip.7zip -e --source winget

# Install Infisical CLI (manual download)
Write-Host "Installing Infisical CLI..." -ForegroundColor Blue
$infisicalUrl = "https://github.com/Infisical/infisical/releases/latest/download/infisical_windows_amd64.exe"
$infisicalPath = "$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps\infisical.exe"
Invoke-WebRequest -Uri $infisicalUrl -OutFile $infisicalPath

Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps for authentication:" -ForegroundColor Blue
Write-Host "1. GitHub CLI: gh auth login" -ForegroundColor White
Write-Host "2. Tailscale: Open Tailscale app and login" -ForegroundColor White
Write-Host "3. Docker: Open Docker Desktop and complete setup" -ForegroundColor White
Write-Host "4. Mullvad VPN: Open Mullvad app and login" -ForegroundColor White
Write-Host "5. Infisical: infisical login" -ForegroundColor White
Write-Host ""
Write-Host "Please restart your terminal to use the new tools!" -ForegroundColor Yellow 