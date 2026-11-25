
#!/usr/bin/env bash

set -Eeuo pipefail

# Universal Docker Removal Script
# Supports Kali, Debian, Ubuntu and derivatives.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*"; }

echo "======================================"
echo "       COMPLETE DOCKER REMOVER"
echo "======================================"

# Require root
if [[ $EUID -ne 0 ]]; then
    err "Run this script as root:"
    echo "sudo bash remove-docker.sh"
    exit 1
fi

# Confirm destructive operation
warn "This will permanently delete Docker data,"
warn "including containers, images and volumes."

read -rp "Continue? Type YES: " confirm

if [[ "$confirm" != "YES" ]]; then
    log "Operation cancelled."
    exit 0
fi

# Stop and disable Docker services
log "Stopping Docker services..."

services=(
    docker.service
    docker.socket
    containerd.service
)

for service in "${services[@]}"; do
    systemctl disable --now "$service" 2>/dev/null || true
done

# Stop any remaining Docker processes
log "Stopping remaining Docker processes..."

for process in dockerd containerd docker-proxy; do
    pkill -TERM -x "$process" 2>/dev/null || true
done

sleep 2

# Remove installed packages
log "Removing Docker-related packages..."

if command -v apt-get >/dev/null 2>&1; then
    apt-get purge -y \
        docker-ce \
        docker-ce-cli \
        docker-ce-rootless-extras \
        docker.io \
        docker-cli \
        docker-compose \
        docker-compose-v2 \
        docker-compose-plugin \
        docker-buildx-plugin \
        docker-doc \
        docker-desktop \
        podman-docker \
        containerd \
        containerd.io \
        runc \
        moby-engine \
        moby-cli \
        moby-buildx \
        moby-compose \
        2>/dev/null || true

    apt-get autoremove --purge -y
    apt-get autoclean
elif command -v dnf >/dev/null 2>&1; then
    dnf remove -y docker\* containerd.io containerd runc podman-docker || true
elif command -v yum >/dev/null 2>&1; then
    yum remove -y docker\* containerd.io containerd runc podman-docker || true
elif command -v pacman >/dev/null 2>&1; then
    pacman -Rns --noconfirm docker docker-compose containerd runc || true
else
    warn "Unsupported package manager. Remove packages manually."
fi

# Remove Docker data and configuration
log "Removing Docker data and configurations..."

paths=(
    /var/lib/docker
    /var/lib/containerd
    /etc/docker
    /etc/containerd
    /run/docker
    /run/containerd
    /var/run/docker.sock
    /var/run/docker.pid
    /etc/docker/daemon.json
    /etc/systemd/system/docker.service
    /etc/systemd/system/docker.socket
    /etc/systemd/system/containerd.service
    /usr/local/bin/docker
    /usr/local/bin/dockerd
    /usr/local/bin/containerd
    /usr/local/bin/docker-compose
    /usr/local/bin/docker-buildx
    /opt/docker-desktop
    /usr/share/docker-desktop
    /root/.docker
)

for path in "${paths[@]}"; do
    rm -rf -- "$path"
done

# Remove Docker repository configurations
log "Removing Docker repository files..."

rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources.list.d/docker.sources
rm -f /etc/apt/keyrings/docker.asc
rm -f /etc/apt/keyrings/docker.gpg
rm -f /etc/yum.repos.d/docker-ce.repo

# Reload systemd
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# Final verification
echo
echo "======================================"
echo "          REMOVAL REPORT"
echo "======================================"

if command -v docker >/dev/null 2>&1; then
    warn "Docker command still exists:"
    command -v docker
else
    ok "Docker CLI not found."
fi

if dpkg -l 2>/dev/null | grep -Eq '^ii[[:space:]]+(docker|containerd|runc)'; then
    warn "Some related Debian packages remain:"
    dpkg -l | grep -Ei 'docker|containerd|runc'
else
    ok "No matching installed Debian packages found."
fi

if systemctl is-active --quiet docker 2>/dev/null; then
    warn "Docker service is still active."
else
    ok "Docker service is not active."
fi

echo
ok "Docker removal process completed."
echo "======================================"
