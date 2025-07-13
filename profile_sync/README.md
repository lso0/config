# Chrome Profile Sync System

Sync your Google Chrome profiles across multiple machines using your Raspberry Pi as central storage.

## 🏗️ Architecture

```
┌─────────────────┐    rsync     ┌─────────────────┐    rsync     ┌─────────────────┐
│   Ubuntu VM 1   │ ←────────────→ │  Raspberry Pi   │ ←────────────→ │   Ubuntu VM 2   │
│                 │              │   (Central)     │              │                 │
│ ~/.config/      │              │ ~/profile_sync/ │              │ ~/.config/      │
│ google-chrome/  │              │ google-chrome/  │              │ google-chrome/  │
└─────────────────┘              └─────────────────┘              └─────────────────┘
```

## 📁 Directory Structure

```
profile_sync/
├── README.md
├── scripts/
│   ├── setup.sh           # Initial setup and SSH key configuration
│   ├── upload.sh          # Upload profile TO Raspberry Pi
│   ├── download.sh        # Download profile FROM Raspberry Pi
│   ├── backup.sh          # Create timestamped backup
│   └── restore.sh         # Restore from backup
├── config/
│   ├── rsync_exclude.txt  # Files/folders to exclude from sync
│   └── pi_config.sh       # Pi connection settings
└── backups/               # Local backup directory
```

## 🚀 Quick Start

### 1. Initial Setup
```bash
cd profile_sync
chmod +x scripts/*.sh
./scripts/setup.sh
```

### 2. Upload Current Profile to Pi
```bash
./scripts/upload.sh
```

### 3. Download Profile from Pi (on new machine)
```bash
./scripts/download.sh
```

## 🔧 Configuration

### Raspberry Pi Settings
- **IP Address**: `192.168.1.9`
- **Username**: `wgr0`
- **Profile Path**: `/home/wgr0/google-chrome`

### Excluded Files (Cache, Logs, etc.)
- `*/Cache/*`
- `*/Code Cache/*`
- `*/Media Cache/*`
- `*/GPUCache/*`
- `*/ShaderCache/*`
- `*/logs/*`
- `*/CrashPad/*`

## 🛡️ Security
- Uses SSH key authentication (no passwords)
- Excludes sensitive cache files
- Creates local backups before sync
- Validates connection before transfer

## 📋 Requirements
- SSH access to Raspberry Pi
- rsync installed on both machines
- Google Chrome installed on target machine

## 🔄 Workflow
1. **Setup** SSH keys and configuration
2. **Upload** current profile to Pi (from main machine)
3. **Download** profile from Pi (to new machines)
4. **Backup** profiles locally before major syncs
5. **Restore** from backup if needed

## 🆘 Troubleshooting
- If sync fails, check SSH connection: `ssh wgr0@192.168.1.9`
- If permission denied, run setup again: `./scripts/setup.sh`
- For connection issues, check Pi IP: `ping 192.168.1.9` 