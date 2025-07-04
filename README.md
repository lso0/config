# Universal System Setup

🚀 **One command to set up any system** - Automatically detects your OS and installs the right tools!

## ⚡ Ultra-Short Universal Command

```bash
curl wgms.uk|bash
```

**Works on:**
- 🐧 **Linux** (Ubuntu, Debian, NixOS, Arch)
- 🍎 **macOS** (Intel & Apple Silicon)
- 🪟 **Windows** (PowerShell)

## 🎯 What It Does

### 🔍 **Smart Detection**
- **OS Type**: Linux, macOS, Windows
- **Distribution**: Ubuntu, Debian, NixOS, Arch, etc.
- **Architecture**: AMD64, ARM64, ARMv7
- **Hardware**: Container, VM, Cloud (AWS/GCP/Azure), Raspberry Pi
- **Network**: Internet connectivity & restrictions

### 📦 **Installs Common Tools**
- **Git** - Version control
- **GitHub CLI** - GitHub command line
- **Docker** - Containerization
- **Tailscale** - Zero-config VPN
- **Mullvad VPN** - Privacy VPN
- **Infisical** - Secret management
- **Node.js** - JavaScript runtime
- **Python** - Programming language
- **Development tools** - Code editors, terminals

## 🖥️ Platform-Specific Commands

### 🐧 Linux
```bash
curl wgms.uk|bash
```

### 🍎 macOS
```bash
curl wgms.uk|bash
```

### 🪟 Windows (PowerShell as Administrator)
```powershell
# The universal script will detect Windows and show this command:
Invoke-WebRequest -Uri "https://wgms.uk/windows/setup.ps1" | Invoke-Expression
```

## 🔧 How It Works

1. **Detection**: Script analyzes your system
2. **Selection**: Chooses the right setup script
3. **Installation**: Downloads and runs platform-specific installer
4. **Configuration**: Sets up tools and dependencies

## 🎨 Example Output

```
[INFO] 🚀 Universal System Setup - Detecting Environment...
[INFO] System: linux (ubuntu) on amd64
[INFO] Hardware: cloud:aws
[INFO] Network: open
[SUCCESS] ✅ Selected script: Ubuntu setup
[INFO] 🔄 Downloading and executing setup script...
[SUCCESS] 🎉 Setup completed successfully!
```

## 🛡️ Security Features

- **Environment validation** before execution
- **Network connectivity** checks
- **Error handling** with clear messages
- **No root execution** (except where required)
- **Timeout protection** for network calls

## 🚀 Advanced Usage

### Manual Platform Selection
```bash
# Ubuntu/Debian
curl wgms.uk/c/m/linux/u-s/s.sh | bash

# macOS
curl -fsSL https://raw.githubusercontent.com/lso0/config/main/macos/setup.sh | bash

# Windows
# Download and run setup.ps1
```

### Verification Mode
```bash
# Test without execution
curl wgms.uk | bash -n
```

## 📁 Repository Structure

```
config/
├── s.sh                    # Universal detector
├── linux/
│   ├── ubuntu-s/s.sh      # Ubuntu/Debian
│   └── nixos/setup.sh     # NixOS
├── macos/
│   └── setup.sh           # macOS
└── windows/
    └── setup.ps1          # Windows
```

## 🔗 Direct Links

- **Repository**: https://github.com/lso0/config
- **Universal Setup**: https://wgms.uk
- **Ubuntu Specific**: https://wgms.uk/c/m/linux/u-s/s.sh

## 🎯 Perfect For

- 🖥️ **Fresh system deployments**
- 🐳 **Development environments**
- ☁️ **Cloud instances**
- 🔒 **Security-focused setups**
- 📊 **DevOps workflows**

---

**⭐ Star this repo if it helped you!** → [github.com/lso0/config](https://github.com/lso0/config) 