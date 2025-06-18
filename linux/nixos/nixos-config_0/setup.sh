#!/bin/bash

# Clone the repository to /etc/nixos
sudo git clone https://github.com/lso0/nixos-config_0.git /etc/nixos

# Apply the configuration
sudo nixos-rebuild switch 