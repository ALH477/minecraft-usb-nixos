# All the Mons Server Files

Place your All the Mons modpack server files here.

## Setup Instructions

1. Download "All the Mons" server pack from CurseForge
2. Extract `ServerFiles-*.zip` to this directory
3. Run the Forge installer:
   ```
   cd server-files
   java -jar forge-*.jar --installServer
   ```
4. Accept the EULA:
   ```
   echo "eula=true" > eula.txt
   ```
5. Start the server:
   ```
   mc-start
   ```

## Directory Structure

```
server-files/
├── ServerFiles-*.zip      # Original download (keep for reference)
├── forge-*.jar           # Forge server jar
├── libraries/            # Minecraft libraries
├── mods/                 # Mods
├── config/               # Mod configurations
├── scripts/              # Server scripts
├── eula.txt              # Accepted EULA (create this)
├── server.properties     # Server settings
└── world/                # Generated world (on first run)
```

## Notes

- This directory is gitignored (large binary files)
- Configuration changes should be saved to ../server-config/ and tracked by Git
- Run `./backup.sh` to create world snapshots in ../world-backup/
