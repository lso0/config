# NixOS Configuration

This repository contains my personal NixOS configuration files.

## Quick Setup

To use this configuration, simply run:

```bash
chmod +x setup.sh
./setup.sh
```

The script will clone this repository to `/etc/nixos` and apply the configuration automatically.

```bash
sudo git clone https://github.com/lso0/nixos-config
sudo nixos-rebuild switch
```
