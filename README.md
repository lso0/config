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

## 🏗️ Architecture Support

- ✅ **AMD64** (x86_64) - Full support for all packages
- ✅ **ARM64** (aarch64) - Full support with intelligent fallbacks  
- 🔄 **Automatic detection** with platform-specific optimizations
- 🛠️ **Fallback methods** for packages without native ARM64 builds

### **ARM64 Compatibility:**
- **GitHub CLI**: ✅ Native ARM64 support
- **Docker**: ✅ Native ARM64 support  
- **Tailscale**: ✅ Native ARM64 support
- **Mullvad VPN**: ✅ Native ARM64 support
- **Infisical**: 🔄 Fallback to npm installation
- **Node.js**: ✅ Native ARM64 support

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
- **GPG key validation** for all repositories
- **Graceful degradation** when packages fail

## 📊 Comprehensive Logging

### **Automatic Logging**
All setup sessions are automatically logged to `~/.config/wgms-setup/`:

```
~/.config/wgms-setup/
├── setup-20241204-143022.log      # Universal detector
├── ubuntu-setup-20241204-143025.log # Ubuntu-specific
└── ...
```

### **What Gets Logged**
- ✅ **System information** (OS, hardware, network)
- ✅ **All commands executed** with timestamps
- ✅ **Command output** (stdout and stderr)
- ✅ **Error messages** and warnings
- ✅ **Execution duration** and exit codes
- ✅ **Detection results** and script selection

### **Log Analysis Tools**

**View recent log:**
```bash
./view-logs.sh --recent
```

**List all logs:**
```bash
./view-logs.sh --list
```

**Show only errors:**
```bash
./view-logs.sh --errors
```

**Show failed setups:**
```bash
./view-logs.sh --failed
```

**Show executed commands:**
```bash
./view-logs.sh --commands
```

### **Log Viewer Options**
```bash
./view-logs.sh [option]

Options:
  -l, --list       List all log files
  -r, --recent     Show most recent log
  -a, --all        Show all logs concatenated
  -f, --failed     Show only failed setups
  -s, --success    Show only successful setups
  -e, --errors     Show only error lines
  -w, --warnings   Show only warning lines
  -c, --commands   Show only executed commands
```

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

## 🔧 Troubleshooting

### **Common Issues and Solutions**

#### **GPG Key Verification Errors**
```
The following signatures couldn't be verified because the public key is not available
```
**Solution**: ✅ **FIXED** - Enhanced GPG key handling with proper permissions and validation.

#### **Repository Not Signed Errors**
```
The repository 'https://...' is not signed
```
**Solution**: ✅ **FIXED** - Automatic repository cleanup and fallback handling.

#### **Architecture Compatibility Issues**
```
curl: (22) The requested URL returned error: 404
```
**Solution**: ✅ **FIXED** - Intelligent architecture detection with fallback installation methods.

#### **Network Connectivity Issues**
```
curl: (6) Could not resolve host
```
**Solution**: The script includes retry logic and network validation.

### **Check Installation Status**
After running the setup, check what was installed:
```bash
./view-logs.sh --recent | grep "Installation Summary" -A 20
```

### **Manual Installation for Skipped Packages**
If packages were skipped, install them manually:

**GitHub CLI:**
```bash
# Alternative installation via snap
sudo snap install gh
```

**Docker:**
```bash
# Alternative installation via snap
sudo snap install docker
```

**Node.js:**
```bash
# Alternative installation via snap or nvm
sudo snap install node --classic
```

## 📁 Repository Structure

```
config/
├── s.sh                    # Universal detector
├── view-logs.sh           # Log analysis utility
├── linux/
│   ├── ubuntu-s/s.sh      # Ubuntu/Debian setup
│   └── nixos/setup.sh     # NixOS setup
├── macos/
│   └── setup.sh           # macOS setup
└── windows/
    └── setup.ps1          # Windows setup
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

## 🏆 Success Stories

### **✅ Recent ARM64 VM Test Results**
```
System: Ubuntu 24.04.2 LTS on ARM64 (aarch64)
Hardware: QEMU Virtual Machine
Results: 🎉 SUCCESS!

✅ GitHub CLI: Installed successfully
✅ Docker: Installed successfully  
✅ Tailscale: Installed successfully
✅ Mullvad VPN: Installed successfully
⚠️ Infisical: Gracefully handled (no ARM64 build)
✅ Node.js: Installed successfully
✅ Python: Installed successfully
✅ All essential tools: Working perfectly!

Total time: 6 minutes
```

### **🛠️ Robustness Improvements**
- **GPG key errors**: Fixed with enhanced validation
- **Repository signing**: Automatic cleanup and fallback
- **Network issues**: Retry logic with exponential backoff
- **Architecture mismatch**: Intelligent detection and alternatives
- **Partial failures**: Graceful degradation, continues installing other packages

---

**⭐ Star this repo if it helped you!** → [github.com/lso0/config](https://github.com/lso0/config) 