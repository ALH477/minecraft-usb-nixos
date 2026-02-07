# Minecraft All the Mons Server - NixOS USB Edition

A declarative NixOS configuration for running All the Mons modded Minecraft servers from USB storage with optimized performance, automatic backups, and **drop-in file setup**.

**Author**: ALH477  
**License**: GNU General Public License v3.0  
**Platform**: NixOS 24.11, x86_64-linux  

## Quick Start (Drop-In File Setup)

The easiest way to get started:

```bash
# 1. Build the ISO
nix build .#usb-image

# 2. Flash to USB (creates 2 partitions)
dd if=result/iso/nixos.iso of=/dev/sdX bs=4M status=progress

# 3. Mount the DATA partition and create server-files directory
mkdir -p /mnt/usb/server-files

# 4. Download All the Mons ServerFiles.zip from CurseForge
# Copy to /mnt/usb/server-files/

# 5. (Optional) Add world backup
cp save.zip /mnt/usb/server-files/

# 6. Boot USB - auto-setup runs on first boot!
```

## Overview

This project provides a complete, reproducible NixOS configuration optimized for running the All the Mons Minecraft modpack server from USB storage devices. The **drop-in file system** allows you to simply copy server files to the USB before booting - no command line setup required!

### Key Features

- **Drop-In File Setup**: Copy `ServerFiles.zip` to USB `server-files/` directory before booting
- **Auto-Setup on First Boot**: Automatically extracts, installs Forge, and configures server
- **World Backup Support**: Place `save.zip` in `server-files/` to restore existing world
- **Declarative Configuration**: Complete system defined in a single Nix flake
- **USB Optimized**: Filesystem tuning and tmpfs usage to minimize USB wear
- **Automatic Backups**: Scheduled backups every 6 hours plus pre-shutdown backups
- **Performance Tuned**: Optimized for 8GB RAM systems with dual/quad-core CPUs
- **Simple Management**: Shell aliases and helper scripts for common operations
- **Persistent Storage**: All server data, worlds, and configurations survive reboots
- **Offline Mode**: No authentication required for LAN play

## System Requirements

### Hardware

- **Memory**: 8GB RAM minimum (7GB allocated to Java, 1GB for system)
- **CPU**: Dual-core or quad-core processor (Intel i3/i5 or AMD Ryzen 3/5)
- **Storage**: 32GB USB 3.0 flash drive or SSD (USB 2.0 works but slower)
- **Network**: Ethernet connection recommended (gigabit preferred)

### Software

- **NixOS**: Version 24.11 or newer (for building)
- **Java**: OpenJDK 21 (included in configuration)
- **Modpack**: All the Mons server files from CurseForge

## Installation Methods

### Method 1: Drop-In File Setup (Recommended)

This is the easiest method - no command line setup on the server required!

#### Step 1: Build the ISO

```bash
# Clone or download this repository
cd minecraft-usb

# Build the bootable ISO
nix build .#usb-image

# The ISO will be at: result/iso/nixos.iso
```

#### Step 2: Flash to USB

**Linux/Mac:**
```bash
# Find your USB device (BE CAREFUL!)
lsblk

# Flash the ISO (replace sdX with your device!)
sudo dd if=result/iso/nixos.iso of=/dev/sdX bs=4M status=progress
sync
```

**Windows:**
Use [Rufus](https://rufus.ie) to flash the ISO to USB.

#### Step 3: Add Server Files

The USB will have two partitions after flashing:
- **Partition 1**: NixOS system (read-only, bootable)
- **Partition 2**: DATA (read-write, for server files)

**Mount the DATA partition and add files:**

```bash
# Mount the DATA partition
sudo mkdir -p /mnt/minecraft-usb
sudo mount /dev/disk/by-label/DATA /mnt/minecraft-usb

# Create server-files directory
sudo mkdir -p /mnt/minecraft-usb/server-files

# Download All the Mons Server Files from CurseForge
# Copy the ServerFiles-*.zip to the server-files directory:
sudo cp ~/Downloads/AllTheMons-ServerFiles-*.zip /mnt/minecraft-usb/server-files/

# (Optional) Add world backup if you have one:
sudo cp ~/save.zip /mnt/minecraft-usb/server-files/

# Unmount
sudo umount /mnt/minecraft-usb
```

#### Step 4: Boot and Play!

1. Insert USB into your server machine
2. Boot from USB (may need to press F12/F2/Del for boot menu)
3. The system will:
   - Boot NixOS
   - Auto-detect server files on USB
   - Extract and install Forge automatically
   - Accept EULA
   - Restore world backup (if present)
   - Display "Setup complete!" message

4. Start the server:
   ```bash
   mc-start
   mc-logs  # Watch it start up
   ```

5. Connect on port 33777!

### Method 2: Direct NixOS Installation

For advanced users who want to install directly to disk:

```bash
# Format and mount target disk
sudo mkfs.ext4 -L nixos /dev/sdX1
sudo mount /dev/disk/by-label/nixos /mnt

# Install
sudo nixos-install --flake .#minecraft-usb

# Set password and reboot
sudo passwd root
reboot
```

Then manually set up the server:
```bash
# Download and extract server files to /srv/minecraft
cd /srv/minecraft
unzip /path/to/ServerFiles-*.zip
java -jar forge-*.jar --installServer
echo "eula=true" > eula.txt
chown -R minecraft:minecraft /srv/minecraft
mc-start
```

## USB Partition Layout

After flashing, your USB will have this layout:

```
/dev/sdX (USB Device)
├── /dev/sdX1 (ISO - bootable, read-only)
│   └── NixOS system files
│
└── /dev/sdX2 (DATA - read-write, labeled "DATA")
    ├── server-files/
    │   ├── AllTheMons-ServerFiles-*.zip  (Required)
    │   └── save.zip                       (Optional - world backup)
    ├── backups/                           (Auto-created)
    └── world/                             (Auto-created)
```

## Configuration

### Server Properties

The server configuration is managed through `/srv/minecraft/server.properties`:

```properties
server-port=33777
online-mode=false
max-players=10
view-distance=6
simulation-distance=6
rcon.password=ChangeMe
```

### Management Commands

```bash
mc-start      # Start Minecraft server
mc-stop       # Stop Minecraft server
mc-restart    # Restart Minecraft server
mc-status     # Check server status
mc-logs       # Watch server logs
mc-backup     # Create manual backup
mc-backups    # List all backups
mc "command"  # RCON commands
```

### RCON Commands

```bash
mc "list"                       # Who's online?
mc "op PlayerName"              # Make admin
mc "whitelist add PlayerName"   # Allow player
mc "save-all"                   # Save world
```

## Troubleshooting

### Auto-Setup Not Working

Check the auto-setup logs:
```bash
journalctl -u minecraft-auto-setup
```

Common issues:
- **ServerFiles not found**: Verify file is in `server-files/` directory on DATA partition
- **Wrong filename**: Should be named `*ServerFiles*.zip`
- **USB not mounted**: Check `/mnt/usb` exists and is readable

### Manual Setup

If auto-setup fails, run manually:
```bash
sudo systemctl start minecraft-auto-setup
# Or run the easy-install script:
bash /path/to/easy-install.sh
```

### Server Won't Start

```bash
# Check logs
mc-logs

# Common fixes
echo "eula=true" > /srv/minecraft/eula.txt  # Accept EULA
mc-restart
```

## Building

### Option 1: Build with Docker (Recommended for non-NixOS users)

If you don't have Nix installed, you can use Docker:

```bash
# Build the Docker image
docker build -t mc-usb-builder .

# Build the ISO (privileged mode required)
docker run --privileged \
  -v $(pwd):/build \
  -v $(pwd)/output:/output \
  mc-usb-builder

# Output will be in ./output/nixos-minecraft-usb.iso
```

**Docker commands:**
```bash
# Just check the flake
docker run -v $(pwd):/build mc-usb-builder check

# Development shell
docker run -it -v $(pwd):/build mc-usb-builder shell

# Show help
docker run mc-usb-builder help
```

### Option 2: Build with Nix (Native)

If you have Nix with flakes enabled:

```bash
# Build ISO
nix build .#usb-image
# Result: result/iso/nixos.iso

# Build system closure
nix build .#nixosConfigurations.minecraft-usb.config.system.build.toplevel

# Update flake
nix flake update
```

## License

Copyright (C) 2025 ALH477 - GPL v3.0

## Files

- `flake.nix` - Main NixOS configuration
- `easy-install.sh` - Interactive setup wizard
- `README.md` - This file
- `world-backup/` - Directory for world backups
- `server-files/` - Drop-in server files (on USB DATA partition)
