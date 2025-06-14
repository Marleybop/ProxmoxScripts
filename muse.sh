#!/usr/bin/env bash

# Muse Discord Bot LXC Installer for Proxmox
# Creates LXC container and installs Muse Discord Bot with Interactive GUI
# https://github.com/museofficial/muse

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Helper functions
msg_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

msg_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

msg_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if dialog is installed, if not install it
if ! command -v whiptail &> /dev/null; then
    echo "Installing whiptail for GUI..."
    apt update && apt install -y whiptail
fi

# Check if running on Proxmox
if ! command -v pct &> /dev/null; then
    whiptail --title "Error" --msgbox "This script must be run on a Proxmox VE host!\n\nIf you want to install on existing system, use the regular installer." 10 60
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    whiptail --title "Error" --msgbox "This script needs to be run as root!\n\nPlease run: sudo $0" 10 50
    exit 1
fi

# Welcome screen
whiptail --title "Muse Discord Bot LXC Installer" --msgbox "Welcome to the Muse Discord Bot LXC Installer!\n\nThis script will:\n• Create a new LXC container\n• Install Node.js 18 and dependencies\n• Install Muse Discord Bot\n• Configure API keys\n• Set up systemd service\n• Auto-start and show logs\n\nPress OK to continue..." 16 70

# Get Container ID
while true; do
    CTID=$(whiptail --title "LXC Configuration" --inputbox "Enter Container ID (100-999):" 10 50 "103" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then exit 1; fi
    
    if [[ "$CTID" =~ ^[0-9]+$ ]] && [ "$CTID" -ge 100 ] && [ "$CTID" -le 999 ]; then
        if pct status $CTID &>/dev/null; then
            whiptail --title "Error" --msgbox "Container ID $CTID already exists!\nPlease choose a different ID." 10 50
        else
            break
        fi
    else
        whiptail --title "Error" --msgbox "Please enter a valid container ID between 100-999" 10 50
    fi
done

# Get hostname
HOSTNAME=$(whiptail --title "LXC Configuration" --inputbox "Enter container hostname:" 10 50 "muse" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit 1; fi
HOSTNAME=${HOSTNAME:-muse}

# Get password
while true; do
    PASSWORD=$(whiptail --title "LXC Configuration" --passwordbox "Enter root password for container:" 10 50 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then exit 1; fi
    if [ -n "$PASSWORD" ]; then
        PASSWORD2=$(whiptail --title "LXC Configuration" --passwordbox "Confirm root password:" 10 50 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then exit 1; fi
        if [ "$PASSWORD" = "$PASSWORD2" ]; then
            break
        else
            whiptail --title "Error" --msgbox "Passwords do not match! Please try again." 10 50
        fi
    else
        whiptail --title "Error" --msgbox "Password cannot be empty!" 10 50
    fi
done

# Get memory
MEMORY=$(whiptail --title "LXC Configuration" --inputbox "Enter memory size (MB):" 10 50 "2048" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit 1; fi
MEMORY=${MEMORY:-2048}

# Get disk size
DISK=$(whiptail --title "LXC Configuration" --inputbox "Enter disk size (GB):" 10 50 "20" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit 1; fi
DISK=${DISK:-20}

# Get CPU cores
CORES=$(whiptail --title "LXC Configuration" --inputbox "Enter number of CPU cores:" 10 50 "2" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then exit 1; fi
CORES=${CORES:-2}

# Configuration summary
if ! whiptail --title "Confirm Configuration" --yesno "Please confirm your LXC configuration:\n\nContainer ID: $CTID\nHostname: $HOSTNAME\nMemory: ${MEMORY}MB\nDisk: ${DISK}GB\nCPU Cores: $CORES\n\nProceed with creation?" 15 60; then
    exit 1
fi

# Get Discord token
while true; do
    DISCORD_TOKEN=$(whiptail --title "API Configuration" --inputbox "Enter Discord Bot Token (REQUIRED):\n\nGet your token from:\nhttps://discord.com/developers/applications" 12 70 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then exit 1; fi
    if [ -n "$DISCORD_TOKEN" ]; then
        break
    else
        whiptail --title "Error" --msgbox "Discord token is required to continue!" 10 50
    fi
done

# Get YouTube API key (optional)
if whiptail --title "API Configuration" --yesno "Do you want to configure YouTube API key?\n\n(Optional - enables YouTube search functionality)" 10 60; then
    YOUTUBE_API_KEY=$(whiptail --title "API Configuration" --inputbox "Enter YouTube API Key:" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then YOUTUBE_API_KEY=""; fi
fi

# Get Spotify credentials (optional)
if whiptail --title "API Configuration" --yesno "Do you want to configure Spotify integration?\n\n(Optional - enables Spotify playlist support)" 10 60; then
    SPOTIFY_CLIENT_ID=$(whiptail --title "API Configuration" --inputbox "Enter Spotify Client ID:" 10 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then SPOTIFY_CLIENT_ID=""; fi
    
    if [ -n "$SPOTIFY_CLIENT_ID" ]; then
        SPOTIFY_CLIENT_SECRET=$(whiptail --title "API Configuration" --inputbox "Enter Spotify Client Secret:" 10 60 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then SPOTIFY_CLIENT_SECRET=""; fi
    fi
fi

# Final confirmation
API_SUMMARY="Discord Bot Token: ✓ Configured"
if [ -n "$YOUTUBE_API_KEY" ]; then
    API_SUMMARY="$API_SUMMARY\nYouTube API: ✓ Configured"
fi
if [ -n "$SPOTIFY_CLIENT_ID" ]; then
    API_SUMMARY="$API_SUMMARY\nSpotify: ✓ Configured"
fi

if ! whiptail --title "Final Confirmation" --yesno "Ready to install Muse Discord Bot!\n\nContainer: $CTID ($HOSTNAME)\nResources: ${MEMORY}MB RAM, ${DISK}GB Disk, $CORES CPU\n\n$API_SUMMARY\n\nThis will take a few minutes.\nProceed with installation?" 16 70; then
    exit 1
fi

# Progress function
show_progress() {
    local title="$1"
    local message="$2"
    local percent="$3"
    echo "XXX"
    echo "$percent"
    echo "$message"
    echo "XXX"
}

# Installation with progress bar
{
    show_progress "Creating Container" "Creating LXC container..." 10
    
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
        --unprivileged 1 >/dev/null 2>&1
    
    show_progress "Starting Container" "Starting LXC container..." 20
    pct start $CTID >/dev/null 2>&1
    sleep 10
    
    show_progress "Installing Prerequisites" "Updating system and installing dependencies..." 30
    pct exec $CTID -- bash -c "apt update && apt upgrade -y" >/dev/null 2>&1
    pct exec $CTID -- bash -c "apt install -y curl wget git ffmpeg build-essential" >/dev/null 2>&1
    
    show_progress "Installing Node.js" "Installing Node.js 18 LTS..." 40
    pct exec $CTID -- bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -" >/dev/null 2>&1
    pct exec $CTID -- bash -c "apt install -y nodejs" >/dev/null 2>&1
    
    show_progress "Installing Yarn" "Installing Yarn package manager..." 50
    pct exec $CTID -- bash -c "
        if [ -f /usr/bin/yarn ] && [ \"\$(yarn --version 2>/dev/null)\" = \"0.32+git\" ]; then
            rm /usr/bin/yarn
        fi
        npm install -g yarn
    " >/dev/null 2>&1
    
    show_progress "Creating User" "Creating muse user..." 60
    pct exec $CTID -- useradd -m -s /bin/bash muse >/dev/null 2>&1
    
    show_progress "Installing Muse" "Downloading and installing Muse Discord Bot..." 70
    pct exec $CTID -- su - muse -c "
        git clone https://github.com/museofficial/muse.git && cd muse
        cp .env.example .env
        LATEST_TAG=\$(git describe --tags --abbrev=0)
        git checkout \$LATEST_TAG
        yarn install
    " >/dev/null 2>&1
    
    show_progress "Configuring API Keys" "Setting up API configuration..." 80
    pct exec $CTID -- sed -i "s/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/" /home/muse/muse/.env
    
    if [ -n "$YOUTUBE_API_KEY" ]; then
        pct exec $CTID -- sed -i "s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/" /home/muse/muse/.env
    fi
    
    if [ -n "$SPOTIFY_CLIENT_ID" ]; then
        pct exec $CTID -- sed -i "s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/" /home/muse/muse/.env
        pct exec $CTID -- sed -i "s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/" /home/muse/muse/.env
    fi
    
    show_progress "Creating Service" "Setting up systemd service..." 90
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
    " >/dev/null 2>&1
    
    show_progress "Starting Service" "Starting Muse Discord Bot..." 100
    pct exec $CTID -- systemctl start muse >/dev/null 2>&1
    
} | whiptail --title "Installing Muse Discord Bot" --gauge "Preparing installation..." 10 70 0

# Success message
whiptail --title "Installation Complete!" --msgbox "✅ Muse Discord Bot has been successfully installed!\n\nContainer ID: $CTID\nHostname: $HOSTNAME\n\nThe service is now starting up.\nPress OK to view the startup logs and Discord invite URL." 12 60

# Clear screen and show final status
clear
echo -e "${PURPLE}============================================"
echo -e "           Installation Complete!"
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
if [ -n "$YOUTUBE_API_KEY" ]; then
    echo "✓ YouTube API Key: Configured"
fi
if [ -n "$SPOTIFY_CLIENT_ID" ]; then
    echo "✓ Spotify: Configured"
fi
echo
echo -e "${CYAN}Management Commands:${NC}"
echo "• Enter container: pct enter $CTID"
echo "• Container status: pct status $CTID"
echo "• View logs: pct exec $CTID -- journalctl -u muse -f"
echo "• Restart service: pct exec $CTID -- systemctl restart muse"
echo
echo -e "${YELLOW}Starting Muse and showing startup logs...${NC}"
echo -e "${GREEN}Look for the Discord invite URL below:${NC}"
echo "============================================"

# Follow logs to show Discord invite URL
sleep 2
pct exec $CTID -- journalctl -u muse -f
