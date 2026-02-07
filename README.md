# Minecraft All the Mons Server - NixOS SD Edition

A declarative NixOS configuration for running All the Mons modded Minecraft servers from SD card storage with optimized performance, automatic backups, and **drop-in file setup**.

**Author**: ALH477  
**License**: GNU General Public License v3.0  
**Platform**: NixOS 24.11, x86_64-linux  

## Quick Start (Package Files for SD Card)

The easiest way to get started:

```bash
# 1. Place your server files in the project directory
cp ~/Downloads/AllTheMons-ServerFiles-*.zip server-files/
cp ~/save.zip world-backup/  # Optional: world backup

# 2. Build the SD card image (packages all files)
nix build .#sd-image

# 3. Flash to SD card
dd if=result/sdImage/nixos-sd-image-24.11-x86_64-linux.img of=/dev/sdX bs=4M status=progress

# 4. Boot from SD card - auto-setup runs on first boot!
```

### How It Works

The entire `server-files/` and `world-backup/` directories are packaged into the ISO during build. When you boot:

1. System copies all files from ISO to `/srv/minecraft/`
2. Extracts any `.zip` files automatically
3. Runs any installer JARs (Forge, NeoForge, etc.)
4. Accepts EULA automatically
5. Restores world backup if present
6. Server is ready to start with `mc-start`

No manual setup required after flashing!

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

#### Step 1: Build the SD card image

```bash
# Clone or download this repository
cd minecraft-sd

# Build the SD card image
nix build .#sd-image

# The image will be at: result/sdImage/nixos-sd-image-24.11-x86_64-linux.img
```

#### Step 2: Flash to SD card

**Linux/Mac:**
```bash
# Find your SD card device (BE CAREFUL!)
lsblk

# Flash the image (replace sdX with your device!)
sudo dd if=result/sdImage/nixos-sd-image-24.11-x86_64-linux.img of=/dev/sdX bs=4M status=progress
sync
```

**Windows:**
Use [Rufus](https://rufus.ie) to flash the image to SD card.

#### Step 3: Add Server Files

The SD card will have one partition after flashing:
- **Partition 1**: NixOS system (read-only, bootable)

**Mount the SD card and add files:**

```bash
# Mount the SD card
sudo mkdir -p /mnt/minecraft-sd
sudo mount /dev/disk/by-label/NIXOS /mnt/minecraft-sd

# Create server-files directory
sudo mkdir -p /mnt/minecraft-sd/server-files

# Download All the Mons Server Files from CurseForge
# Copy the ServerFiles-*.zip to the server-files directory:
sudo cp ~/Downloads/AllTheMons-ServerFiles-*.zip /mnt/minecraft-sd/server-files/

# (Optional) Add world backup if you have one:
sudo cp ~/save.zip /mnt/minecraft-sd/server-files/

# Unmount
sudo umount /mnt/minecraft-sd
```

#### Step 4: Boot and Play!

1. Insert SD card into your server machine
2. Boot from SD card (may need to press F12/F2/Del for boot menu)
3. The system will:
   - Boot NixOS
   - Auto-detect server files on SD card
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

## SD Card Partition Layout

After flashing, your SD card will have this layout:

```
/dev/sdX (SD Card Device)
└── /dev/sdX1 (ISO - bootable, read-only)
    └── NixOS system files
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
docker build -t mc-sd-builder .

# Build the SD card image (privileged mode required)
docker run --privileged \
  -v $(pwd):/build \
  -v $(pwd)/output:/output \
  mc-sd-builder

# Output will be in ./output/nixos-minecraft-sd.img
```

**Docker commands:**
```bash
# Just check the flake
docker run -v $(pwd):/build mc-sd-builder check

# Development shell
docker run -it -v $(pwd):/build mc-sd-builder shell

# Show help
docker run mc-sd-builder help
```

### Option 2: Build with Nix (Native)

If you have Nix with flakes enabled:

```bash
# Build SD card image
nix build .#sd-image
# Result: result/sdImage/nixos-sd-image-24.11-x86_64-linux.img

# Build system closure
nix build .#nixosConfigurations.minecraft-sd.config.system.build.toplevel

# Update flake
nix flake update
```

## License

Copyright (C) 2025 ALH477 - GPL v3.0

## Files

- `flake.nix` - Main NixOS configuration
- `README.md` - This file
- `world-backup/` - Directory for world backups
- `server-files/` - Drop-in server files (on SD card)
