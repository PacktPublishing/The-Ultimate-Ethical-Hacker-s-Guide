#!/bin/bash
# =============================================================================
#  SysReptor Automated Installer for Kali Linux
#  Method: Manual Installation
# =============================================================================

set -euo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Helpers
info()    { echo -e "${CYAN}[*]${NC} $*"; }
success() { echo -e "${GREEN}[v]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[x]${NC} $*"; exit 1; }
banner()  { echo -e "\n${BOLD}${CYAN}=== $* ===${NC}\n"; }

# Root check
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root. Try: sudo bash $0"
fi

# Detect architecture
ARCH=$(dpkg --print-architecture)
if [[ "$ARCH" != "amd64" && "$ARCH" != "arm64" ]]; then
    error "Unsupported architecture: $ARCH. Only amd64 and arm64 are supported."
fi

# Detect Debian base version
DEBIAN_VERSION=$(. /etc/os-release && echo "${VERSION_CODENAME:-bookworm}" 2>/dev/null || echo "bookworm")
case "$DEBIAN_VERSION" in
    kali-rolling|trixie|sid) DEBIAN_VERSION="bookworm" ;;
esac

# =============================================================================
banner "SysReptor Installer for Kali Linux"
# =============================================================================
echo -e "  Architecture : ${BOLD}$ARCH${NC}"
echo -e "  Docker base  : ${BOLD}$DEBIAN_VERSION${NC}"
echo -e "  Target dir   : ${BOLD}/opt/sysreptor${NC}"
echo ""
warn "This script will install Docker CE and SysReptor. Press Ctrl+C to abort."
sleep 3

# =============================================================================
banner "Step 1 - System Update"
# =============================================================================
info "Updating package lists..."
apt-get update -qq
success "Package lists updated."

# =============================================================================
banner "Step 2 - Install Dependencies"
# =============================================================================
info "Installing required packages..."
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    python3 \
    git \
    sed \
    openssl \
    uuid-runtime \
    coreutils
success "Dependencies installed."

# =============================================================================
banner "Step 3 - Install Docker CE"
# =============================================================================

info "Removing any old Docker installations..."
for pkg in docker docker-engine docker.io containerd runc docker-compose; do
    apt-get remove -y -qq "$pkg" 2>/dev/null || true
done

info "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/debian/gpg" \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
success "Docker GPG key added."

info "Adding Docker repository (debian/${DEBIAN_VERSION})..."
echo \
    "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/debian ${DEBIAN_VERSION} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -qq
success "Docker repository added."

info "Installing Docker CE..."
apt-get install -y -qq \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
success "Docker CE installed."

info "Enabling and starting Docker service..."
systemctl enable docker --quiet
systemctl start docker
success "Docker service is running."

DOCKER_VERSION=$(docker --version)
success "Docker ready: ${DOCKER_VERSION}"

# =============================================================================
banner "Step 4 - Download SysReptor"
# =============================================================================
INSTALL_DIR="/opt/sysreptor"

if [[ -d "$INSTALL_DIR" ]]; then
    warn "Directory $INSTALL_DIR already exists. Backing it up..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d%H%M%S)"
fi

mkdir -p "$INSTALL_DIR"

info "Downloading SysReptor install script..."
curl -fsSL https://docs.sysreptor.com/install.sh -o /tmp/sysreptor_install.sh
chmod +x /tmp/sysreptor_install.sh

info "Running SysReptor install script..."
SYSREPTOR_INSTALL_DIR="$INSTALL_DIR" bash /tmp/sysreptor_install.sh
success "SysReptor downloaded and deployed."

# =============================================================================
banner "Step 5 - Create Superuser"
# =============================================================================
DEPLOY_DIR="$INSTALL_DIR/sysreptor/deploy"

if [[ ! -f "$DEPLOY_DIR/docker-compose.yml" ]]; then
    DEPLOY_DIR=$(find "$INSTALL_DIR" -name "docker-compose.yml" -maxdepth 4 | head -1 | xargs dirname 2>/dev/null || true)
fi

if [[ -z "$DEPLOY_DIR" || ! -f "$DEPLOY_DIR/docker-compose.yml" ]]; then
    warn "Could not locate docker-compose.yml automatically."
    warn "Please manually run:"
    warn "  cd <sysreptor_deploy_dir> && docker compose exec app python3 manage.py createsuperuser"
else
    info "Starting containers to create superuser..."
    cd "$DEPLOY_DIR"
    docker compose up -d --quiet-pull 2>/dev/null || docker compose up -d

    info "Waiting for the app container to be ready (30s)..."
    sleep 30

    echo ""
    echo -e "${BOLD}${YELLOW}>>> Create your SysReptor superuser account <<<${NC}"
    docker compose exec app python3 manage.py createsuperuser
    success "Superuser created."
fi

# =============================================================================
banner "Step 6 - Import Templates (Optional)"
# =============================================================================
echo -e "Would you like to import report templates?\n"
echo "  1) Hack The Box templates"
echo "  2) OffSec (OSCP/OSEP) templates"
echo "  3) Both"
echo "  4) Skip"
echo ""
read -rp "Choice [1-4]: " TEMPLATE_CHOICE

cd "$DEPLOY_DIR"

import_templates() {
    local label="$1" url="$2"
    info "Importing ${label} templates..."
    curl -s "$url" | docker compose exec --no-TTY app python3 manage.py importdemodata --type=design
    success "${label} templates imported."
}

case "$TEMPLATE_CHOICE" in
    1) import_templates "Hack The Box" "https://docs.sysreptor.com/assets/htb-designs.tar.gz" ;;
    2) import_templates "OffSec"       "https://docs.sysreptor.com/assets/offsec-designs.tar.gz" ;;
    3)
        import_templates "Hack The Box" "https://docs.sysreptor.com/assets/htb-designs.tar.gz"
        import_templates "OffSec"       "https://docs.sysreptor.com/assets/offsec-designs.tar.gz"
        ;;
    *) info "Skipping template import." ;;
esac

# =============================================================================
banner "Step 7 - Add Current User to Docker Group"
# =============================================================================
REAL_USER="${SUDO_USER:-}"
if [[ -n "$REAL_USER" ]] && ! groups "$REAL_USER" | grep -q docker; then
    info "Adding ${REAL_USER} to the docker group..."
    usermod -aG docker "$REAL_USER"
    warn "Log out and back in (or run 'newgrp docker') for the group change to take effect."
    success "User ${REAL_USER} added to docker group."
else
    info "User already in docker group or running as root -- skipping."
fi

# =============================================================================
banner "Installation Complete!"
# =============================================================================
echo -e "  ${GREEN}${BOLD}SysReptor is up and running!${NC}"
echo ""
echo -e "  Access URL : ${CYAN}http://127.0.0.1:8000/${NC}"
echo -e "  Deploy dir : ${CYAN}${DEPLOY_DIR}${NC}"
echo ""
echo -e "  ${BOLD}Useful commands:${NC}"
echo -e "  Start -> cd ${DEPLOY_DIR} && docker compose up -d"
echo -e "  Stop  -> cd ${DEPLOY_DIR} && docker compose stop"
echo -e "  Logs  -> cd ${DEPLOY_DIR} && docker compose logs -f"
echo ""
echo -e "  Optional HTTPS setup: https://docs.sysreptor.com/setup/webserver/"
echo ""
