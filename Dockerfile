# Dockerfile for building minecraft-usb-nixos ISO
# Uses official Nix image with overlay configuration
#
# Usage:
#   docker build -t mc-usb-builder .
#   docker run --privileged -v $(pwd):/build -v $(pwd)/output:/output mc-usb-builder
#
# Note: --privileged is required for ISO builds (uses QEMU/KVM)

FROM nixos/nix:latest

LABEL maintainer="ALH477"
LABEL description="Build environment for Minecraft USB NixOS ISO"

# Install required packages and configure Nix
RUN nix-env -iA nixpkgs.git nixpkgs.cacert && \
    mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf && \
    echo "trusted-users = root" >> /etc/nix/nix.conf && \
    echo "sandbox = false" >> /etc/nix/nix.conf

# Set environment
ENV NIX_PATH=/nix/var/nix/profiles/per-user/root/channels
ENV PATH=/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH

# Create directories
RUN mkdir -p /build /output

# Copy entrypoint script
COPY docker-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set working directory
WORKDIR /build

# Default entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command (can be overridden)
CMD ["build"]
