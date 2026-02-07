#!/bin/sh
# Docker entrypoint for building minecraft-usb-nixos

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in privileged mode
check_privileged() {
    if ! capsh --print | grep -q "cap_sys_admin"; then
        log_warn "Container may not be running in privileged mode"
        log_warn "ISO builds require --privileged flag for QEMU/KVM"
    fi
}

# Verify flake exists
verify_flake() {
    if [ ! -f "/build/flake.nix" ]; then
        log_error "No flake.nix found in /build"
        log_error "Mount your project: docker run -v \$(pwd):/build ..."
        exit 1
    fi
    log_info "Found flake.nix"
}

# Build the ISO
build_iso() {
    log_info "Building minecraft-usb ISO..."
    log_info "This may take 10-30 minutes depending on cache state"
    
    cd /build
    
    # Build the ISO
    nix build .#usb-image \
        --out-link /output/iso \
        --extra-experimental-features "nix-command flakes" \
        || {
            log_error "Build failed!"
            log_error "Check logs above for errors"
            exit 1
        }
    
    log_info "Build complete!"
    
    # Show results
    if [ -L "/output/iso" ]; then
        ISO_PATH=$(readlink -f /output/iso)
        ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
        log_info "ISO location: $ISO_PATH"
        log_info "ISO size: $ISO_SIZE"
        
        # Also copy to output directory for easy access
        cp -L "$ISO_PATH" /output/nixos-minecraft-usb.iso 2>/dev/null || true
    fi
}

# Show help
show_help() {
    cat << EOF
Minecraft USB NixOS Builder

Usage: docker run [options] mc-usb-builder [command]

Commands:
  build       Build the ISO (default)
  check       Run nix flake check
  shell       Enter nix shell for development
  help        Show this help

Options:
  --privileged    Required for ISO builds (uses QEMU/KVM)
  -v $(pwd):/build    Mount your project directory
  -v $(pwd)/output:/output  Mount output directory

Examples:
  # Build ISO
  docker run --privileged -v \$(pwd):/build -v \$(pwd)/output:/output mc-usb-builder

  # Just check flake
  docker run -v \$(pwd):/build mc-usb-builder check

  # Development shell
  docker run -it -v \$(pwd):/build mc-usb-builder shell
EOF
}

# Run flake check
check_flake() {
    log_info "Running nix flake check..."
    cd /build
    nix flake check --extra-experimental-features "nix-command flakes"
    log_info "Flake check passed!"
}

# Enter development shell
enter_shell() {
    log_info "Entering Nix development shell..."
    cd /build
    exec nix shell nixpkgs#nixpkgs-fmt nixpkgs#nix-prefetch-git --extra-experimental-features "nix-command flakes"
}

# Main entrypoint
case "${1:-build}" in
    build)
        check_privileged
        verify_flake
        build_iso
        ;;
    check)
        verify_flake
        check_flake
        ;;
    shell)
        enter_shell
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
