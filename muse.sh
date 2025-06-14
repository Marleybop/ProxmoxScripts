#!/usr/bin/env bash

# Muse Discord Bot LXC Installer for Proxmox
# Creates LXC container and installs Muse Discord Bot
# https://github.com/museofficial/muse

set -e

# Color definitions for GUI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions for colored output
msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

msg_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Header with style
clear
echo -e "${PURPLE}============================================"
echo -e "    Muse Discord Bot LXC Installer"
echo -e "============================================${NC}"
echo

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    msg_error "This script must be run on a Proxmox VE host"
    msg_info "If you want to install on existing system, use the regular installer"
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    msg_error "This script needs to be run as root"
    echo "Please run: sudo $0"
    exit 1
fi

# Get user input for LXC configuration
echo -e "${CYAN}LXC Container Configuration:${NC}"
echo -e "${BLUE}Enter your container settings:${NC}"
echo
read -p "$(echo -e ${GREEN}Container ID ${YELLOW}[100-999]${NC}: )" CTID
while [[ ! "$CTID" =~ ^[0-9]+$ ]] || [ "$CTID" -lt 100 ] || [ "$CTID" -gt 999 ]; do
    msg_error "Please enter a valid container ID (100-999)"
    read -p "$(echo -e ${GREEN}Container ID ${YELLOW}[100-999]${NC}: )" CTID
done

# Check if container ID already exists
if pct status $CTID &>/dev/null; then
    msg_error "Container ID $CTID already exists!"
    exit 1
fi

read -p "$(echo -e ${GREEN}Container hostname ${YELLOW}[muse]${NC}: )" HOSTNAME
HOSTNAME=${HOSTNAME:-muse}

echo -e "${GREEN}Root password:${NC}"
read -p "$(echo -e ${YELLOW}Password${NC}: )" -s PASSWORD
echo
while [ -z "$PASSWORD" ]; do
    msg_error "Password cannot be empty!"
    read -p "$(echo -e ${YELLOW}Password${NC}: )" -s PASSWORD
    echo
done

read -p "$(echo -e ${GREEN}Memory ${YELLOW}[2048 MB]${NC}: )" MEMORY
MEMORY=${MEMORY:-2048}

read -p "$(echo -e ${GREEN}Disk size ${YELLOW}[20 GB]${NC}: )" DISK
DISK=${DISK:-20}

read -p "$(echo -e ${GREEN}CPU cores ${YELLOW}[2]${NC}: )" CORES
CORES=${CORES:-2}

echo
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}        API Keys Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}Configure your bot API keys:${NC}"
echo

read -p "$(echo -e ${GREEN}Discord Bot Token ${RED}[REQUIRED]${NC}: )" DISCORD_TOKEN
while [ -z "$DISCORD_TOKEN" ]; do
    msg_error "Discord token is required!"
    read -p "$(echo -e ${GREEN}Discord Bot Token ${RED}[REQUIRED]${NC}: )" DISCORD_TOKEN
done

read -p "$(echo -e ${GREEN}YouTube API Key ${YELLOW}[OPTIONAL]${NC}: )" YOUTUBE_API_KEY
read -p "$(echo -e ${GREEN}Spotify Client ID ${YELLOW}[OPTIONAL]${NC}: )" SPOTIFY_CLIENT_ID
if [ ! -z "$SPOTIFY_CLIENT_ID" ]; then
    read -p "$(echo -e ${GREEN}Spotify Client Secret${NC}: )" SPOTIFY_CLIENT_SECRET
fi

echo
msg_info "Creating LXC container..."

# Create LXC container
pct create $CTID local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
    --hostname $HOSTNAME \
    --password $PASSWORD \
    --memory $MEMORY \
    --rootfs local-lvm:${DISK} \
    --cores $CORES \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --onboot 1 \
    --features nesting=1 \
    --unprivileged 1

msg_ok "LXC container $CTID created"

# Start container
msg_info "Starting container..."
pct start $CTID
sleep 10
msg_ok "Container started"

# Install Muse in container
msg_info "Installing Muse Discord Bot in container..."

pct exec $CTID -- bash -c "
# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y curl wget git ffmpeg build-essential

# Install Node.js 18 LTS
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

# Remove conflicting yarn if exists
if [ -f /usr/bin/yarn ] && [ \"\$(yarn --version 2>/dev/null)\" = \"0.32+git\" ]; then
    rm /usr/bin/yarn
fi

# Install proper yarn
npm install -g yarn

# Create muse user
useradd -m -s /bin/bash muse

# Install Muse as muse user
su - muse << 'EOF'
git clone https://github.com/museofficial/muse.git && cd muse
cp .env.example .env
LATEST_TAG=\$(git describe --tags --abbrev=0)
git checkout \$LATEST_TAG
yarn install
EOF

# Configure .env file
sed -i 's/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/' /home/muse/muse/.env
"

# Configure API keys in container
if [ ! -z "$YOUTUBE_API_KEY" ]; then
    pct exec $CTID -- sed -i "s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/" /home/muse/muse/.env
fi

if [ ! -z "$SPOTIFY_CLIENT_ID" ]; then
    pct exec $CTID -- sed -i "s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/" /home/muse/muse/.env
    pct exec $CTID -- sed -i "s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/" /home/muse/muse/.env
fi

# Create systemd service in container
pct exec $CTID -- bash -c "
cat > /etc/systemd/system/muse.service << 'EOF'
[Unit]
Description=Muse Discord Music Bot
After=network.target

[Service]
Type=simple
User=muse
Group=muse
WorkingDirectory=/home/muse/muse
ExecStart=/usr/bin/yarn start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable muse
"

msg_ok "Muse installation completed in container"

# Start the service and show logs
msg_info "Starting Muse service..."
pct exec $CTID -- systemctl start muse
msg_ok "Service started!"

echo
echo -e "${PURPLE}============================================"
echo -e "           Installation Complete"
echo -e "============================================${NC}"
echo
echo -e "${GREEN}Container Details:${NC}"
echo "• Container ID: $CTID"
echo "• Hostname: $HOSTNAME"
echo "• Memory: ${MEMORY}MB"
echo "• Disk: ${DISK}GB"
echo "• Cores: $CORES"
echo
echo -e "${GREEN}Configuration:${NC}"
echo "✓ Discord Bot Token: Configured"
if [ ! -z "$YOUTUBE_API_KEY" ]; then
    echo "✓ YouTube API Key: Configured"
fi
if [ ! -z "$SPOTIFY_CLIENT_ID" ]; then
    echo "✓ Spotify: Configured"
fi
echo
echo -e "${CYAN}Container Management:${NC}"
echo "• Enter container: pct enter $CTID"
echo "• Start container: pct start $CTID"
echo "• Stop container: pct stop $CTID"
echo "• Container status: pct status $CTID"
echo
echo -e "${CYAN}Service Management (inside container):${NC}"
echo "• Check status: systemctl status muse"
echo "• View logs: journalctl -u muse -f"
echo "• Restart service: systemctl restart muse"
echo
echo -e "${YELLOW}Showing Muse startup logs (Ctrl+C to exit):${NC}"
echo -e "${GREEN}Look for the Discord invite URL below:${NC}"
echo "============================================"

# Follow logs to show Discord invite URL
pct exec $CTID -- journalctl -u muse -f
