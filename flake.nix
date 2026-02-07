{
  description = "Minecraft All the Mons USB Server - Bootable USB Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      worldBackup = pkgs.stdenv.mkDerivation {
        pname = "minecraft-world-backup";
        version = "1.0";
        src = ./world-backup;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out
          if [ -f "save.zip" ]; then
            cp save.zip $out/world-backup.zip
          else
            echo "No world backup found - will start fresh" > $out/README.txt
          fi
        '';
      };
      
      # Common configuration for both install and image
      commonConfig = { config, pkgs, lib, ... }: {
        boot.loader.grub = {
          enable = lib.mkDefault true;
          device = lib.mkDefault "nodev";
          efiSupport = lib.mkDefault true;
        };
        
        networking = {
          hostName = "minecraft-server";
          useDHCP = true;
          firewall = {
            enable = true;
            allowedTCPPorts = [ 33777 25575 ];
            allowedUDPPorts = [ 33777 ];
          };
        };

        powerManagement.cpuFreqGovernor = "performance";
        
        boot.kernel.sysctl = {
          "net.core.rmem_max" = 67108864;
          "net.core.wmem_max" = 67108864;
          "net.ipv4.tcp_congestion_control" = "bbr";
          "vm.swappiness" = 10;
          "vm.dirty_ratio" = 90;
          "vm.dirty_background_ratio" = 3;
          "vm.overcommit_memory" = 1;
        };
        
        boot.kernelModules = [ "tcp_bbr" ];
        
        boot.kernelParams = [ "quiet" "mitigations=off" "idle=poll" ];
        
        zramSwap = {
          enable = true;
          algorithm = "lz4";
          memoryPercent = 30;
          priority = 5;
        };

        fileSystems."/" = {
          device = "/dev/disk/by-label/NIXOS_SD";
          fsType = "ext4";
          options = [ "noatime" "nodiratime" "commit=120" ];
        };

        # Backup partition - using a different label than the USB mount
        fileSystems."/srv/backup" = {
          device = "/dev/disk/by-label/BACKUP";
          fsType = "ext4";
          options = [ "noatime" "nodiratime" "commit=300" "nofail" ];
        };

        # Mount USB data partition for drop-in server files
        fileSystems."/mnt/usb" = {
          device = "/dev/disk/by-label/DATA";
          fsType = "auto";
          options = [ "ro" "nofail" "x-systemd.automount" ];
        };

        fileSystems."/var/log" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = [ "mode=0755" "size=128M" ];
        };

        fileSystems."/tmp" = {
          device = "tmpfs";
          fsType = "tmpfs";
          options = [ "mode=1777" "size=512M" ];
        };

        environment.systemPackages = with pkgs; [
          vim htop mcrcon unzip zip curl wget git
        ];

        # Copy entire directories to ISO for drop-in setup
        # These are mounted read-only from the ISO
        environment.etc."server-files".source = ./server-files;
        environment.etc."world-backup".source = ./world-backup;

        users.users.minecraft = {
          isSystemUser = true;
          group = "minecraft";
          home = "/srv/minecraft";
          createHome = true;
        };

        users.groups.minecraft = {};

        systemd.tmpfiles.rules = [
          "d /srv/minecraft 0755 minecraft minecraft -"
          "d /srv/backup 0755 minecraft minecraft -"
          "d /var/log/minecraft 0755 minecraft minecraft -"
        ];

        systemd.services.minecraft-server = {
          description = "All the Mons Minecraft Server";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" ];

          serviceConfig = {
            Type = "simple";
            User = "minecraft";
            Group = "minecraft";
            WorkingDirectory = "/srv/minecraft";
            Restart = "always";
            RestartSec = "10s";
            CPUAffinity = "0-3";
            MemoryMax = "7500M";
            Nice = "-5";
            ExecStart = ''
              ${pkgs.jdk21}/bin/java -Xms6G -Xmx7G \
                -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 \
                -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch \
                -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 \
                -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 \
                -XX:InitiatingHeapOccupancyPercent=15 -XX:+UseStringDeduplication \
                -Dusing.aikars.flags=https://mcflags.emc.gs \
                -Dfml.readTimeout=180 \
                @user_jvm_args.txt @libraries/net/minecraftforge/forge/*/unix_args.txt nogui
            '';
            NoNewPrivileges = true;
            PrivateTmp = true;
            ReadWritePaths = [ "/srv/minecraft" ];
            LimitNOFILE = 65536;
            StandardOutput = "journal";
            StandardError = "journal";
          };
        };

        systemd.services.minecraft-backup = {
          description = "Minecraft World Backup";
          serviceConfig = {
            Type = "oneshot";
            User = "minecraft";
            Group = "minecraft";
            TimeoutStartSec = "300";
          };
          
          script = ''
            set -e
            BACKUP_DIR="/srv/backup"
            WORLD_DIR="/srv/minecraft/world"
            TIMESTAMP=$(date +%Y%m%d-%H%M%S)
            BACKUP_FILE="$BACKUP_DIR/world-backup-$TIMESTAMP.zip"
            
            if [ ! -d "$WORLD_DIR" ]; then
              echo "No world to backup yet"
              exit 0
            fi
            
            mkdir -p "$BACKUP_DIR"
            cd /srv/minecraft
            ${pkgs.zip}/bin/zip -r "$BACKUP_FILE" world/ -x "*.log" "world/session.lock"
            cd "$BACKUP_DIR"
            ls -t world-backup-*.zip 2>/dev/null | tail -n +8 | xargs -r rm
            echo "Backup complete: $(basename $BACKUP_FILE)"
          '';
        };

        systemd.timers.minecraft-backup = {
          description = "Minecraft Backup Timer";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 00,06,12,18:00:00";
            Persistent = true;
          };
        };

        systemd.services.minecraft-backup-shutdown = {
          description = "Backup World Before Shutdown";
          before = [ "shutdown.target" ];
          wantedBy = [ "shutdown.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "minecraft";
            Group = "minecraft";
            TimeoutStartSec = "120";
          };
          script = config.systemd.services.minecraft-backup.script;
        };

        # Auto-setup from packaged files on ISO
        systemd.services.minecraft-auto-setup = {
          description = "Auto-setup Minecraft from packaged files";
          wantedBy = [ "multi-user.target" ];
          before = [ "minecraft-server.service" ];
          after = [ "local-fs.target" ];
          
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          
          script = ''
            # Check if already setup
            if [ -f /srv/minecraft/.setup-complete ]; then
              echo "Minecraft server already set up"
              exit 0
            fi
            
            echo "Looking for packaged server files..."
            
            # Copy all files from /etc/server-files (packaged in ISO)
            if [ -d /etc/server-files ]; then
              echo "Copying server files from ISO..."
              cp -r /etc/server-files/* /srv/minecraft/ 2>/dev/null || true
            fi
            
            # Check if we have any files
            if [ -z "$(ls -A /srv/minecraft 2>/dev/null)" ]; then
              echo "No server files found on ISO."
              echo "Add files to the server-files/ directory before building."
              # Don't mark as complete so it can retry
              exit 0
            fi
            
            echo "Found server files, setting up..."
            
            cd /srv/minecraft
            
            # Extract any zip files
            for zip in *.zip; do
              if [ -f "$zip" ]; then
                echo "Extracting: $zip"
                if ! unzip -o "$zip"; then
                  echo "ERROR: Failed to extract $zip"
                  exit 1
                fi
              fi
            done
            
            # Find and run any installer jars
            for jar in *forge*.jar *installer*.jar neoforge*.jar; do
              if [ -f "$jar" ]; then
                echo "Running installer: $jar"
                if ! java -jar "$jar" --installServer; then
                  echo "WARNING: Installer may have failed for $jar"
                fi
              fi
            done
            
            # Accept EULA
            echo "eula=true" > /srv/minecraft/eula.txt
            
            # Copy world backup if exists
            if [ -d /etc/world-backup ]; then
              echo "Copying world backup..."
              cp -r /etc/world-backup/* /srv/minecraft/ 2>/dev/null || true
            fi
            
            # Set ownership
            chown -R minecraft:minecraft /srv/minecraft
            
            # Only mark as complete if we successfully got here
            touch /srv/minecraft/.setup-complete
            echo "Minecraft server setup complete!"
            echo "Run 'mc-start' to start the server"
          '';
        };

        environment.shellAliases = {
          mc-start = "systemctl start minecraft-server";
          mc-stop = "systemctl stop minecraft-server";
          mc-restart = "systemctl restart minecraft-server";
          mc-status = "systemctl status minecraft-server";
          mc-logs = "journalctl -u minecraft-server -f";
          mc-backup = "systemctl start minecraft-backup";
          mc-backups = "ls -lh /srv/backup/";
          mc = "mcrcon -H localhost -P 25575 -p ChangeMe";
        };

        documentation.enable = false;
        services.udisks2.enable = false;
        services.accounts-daemon.enable = false;
        programs.command-not-found.enable = false;
        
        systemd.extraConfig = ''
          DefaultTimeoutStopSec=10s
          DefaultTimeoutStartSec=10s
        '';

        # Limit journald size since we're using tmpfs
        services.journald.extraConfig = ''
          SystemMaxUse=100M
          RuntimeMaxUse=100M
        '';
        
        boot.supportedFilesystems = [ "ext4" "vfat" ];

        users.motd = ''
          ╔══════════════════════════════════════════════════════════╗
          ║           Minecraft All the Mons Server                 ║
          ╚══════════════════════════════════════════════════════════╝
          
          ⚠️  SECURITY: Change RCON password in server.properties!
          
          Server commands:
            mc-start      Start the server
            mc-stop       Stop the server  
            mc-restart    Restart the server
            mc-status     Check if running
            mc-logs       Watch server logs
            mc-backup     Backup now
            mc-backups    List backups
            
          Server address: $(hostname -I | awk '{print $1}'):33777
        '';
        
        environment.etc."minecraft-help.txt".text = ''
          MINECRAFT SERVER QUICK REFERENCE
          ================================
          
          INSTALLATION
          ------------
          1. Flash this image to USB: dd if=result/nixos.img of=/dev/sdX bs=4M
          2. Boot from USB
          3. Download All the Mons server pack from CurseForge
          4. Extract to /srv/minecraft/
          5. Run Forge installer
          6. Accept EULA: echo "eula=true" > eula.txt
          7. Start: mc-start
          
          SERVER MANAGEMENT
          ----------------
          Start:    mc-start
          Stop:     mc-stop
          Restart:  mc-restart
          Status:   mc-status
          Logs:     mc-logs
          
          BACKUPS
          -------
          Automatic: Every 6 hours + on shutdown
          Manual:    mc-backup
          List:      mc-backups
          Location:  /srv/backup/
          
          SECURITY
          --------
          ⚠️  IMPORTANT: Change rcon.password in server.properties before using RCON
          Default RCON password "ChangeMe" is NOT SECURE
          
          PORTS
          -----
          Game Port: 33777 (custom, not default 25565)
          RCON Port: 25575
          
          For help, check server logs: mc-logs
        '';

        system.stateVersion = "24.11";
      };
      
    in
    {
      packages.${system} = {
        default = pkgs.writeShellScriptBin "backup-world" ''
          #!/usr/bin/env bash
          WORLD_DIR="/srv/minecraft/world"
          BACKUP_FILE="./save.zip"
          
          if [ ! -d "$WORLD_DIR" ]; then
            echo "Error: No world found at $WORLD_DIR"
            exit 1
          fi
          
          cd /srv/minecraft
          ${pkgs.zip}/bin/zip -r "$BACKUP_FILE" world/ -x "*.log" "world/session.lock"
          echo "Backup created: $BACKUP_FILE"
        '';
        
        backup-tool = worldBackup;
        
        # SD card image for x86_64 systems
        sd-image = nixos-generators.nixosGenerate {
          inherit system;
          modules = [ commonConfig ];
          format = "sd-x86_64";
        };
      };

      # NixOS configuration for SD card installation
      nixosConfigurations.minecraft-sd = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ commonConfig ];
      };
    };
}
