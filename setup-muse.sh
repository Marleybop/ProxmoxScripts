#!/usr/bin/env bash

# Proxmox Muse Discord Bot LXC Setup Script
# Based on community-scripts/ProxmoxVE style

source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func) 2>/dev/null || {
    # Fallback colors if build.func not available
    BL='\033[36m'
    GN='\033[1;92m'
    CL='\033[m'
    RD='\033[01;31m'
    YW='\033[1;33m'
    msg_info() { echo -e "${BL}[INFO]${CL} $1"; }
    msg_ok() { echo -e "${GN}[OK]${CL} $1"; }
    msg_error() { echo -e "${RD}[ERROR]${CL} $1"; }
}

# Default values
CTID="200"
CT_NAME="muse"
CT_DISK="8"
CT_RAM="2048"
CT_CPU="2"
CT_PASSWORD=""
CT_TEMPLATE=""
CT_STORAGE=""

# Functions
header_info() {
    cat <<"EOF"
    __  ___                 ____        __
   /  |/  /_  _________   / __ )____  / /_
  / /|_/ / / / / ___/ _ \ / __  / __ \/ __/
 / /  / / /_/ (__  )  __/ /_/ / /_/ / /_
/_/  /_/\__,_/____/\___/_____/\____/\__/

EOF
}

get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

# Main script
clear
header_info
echo -e "Loading..."

# Get available templates and storage
TEMPLATES=$(pveam available -section system | grep debian-12 | head -1 | awk '{print $2}')
STORAGES=$(pvesm status -content vztmpl | awk 'NR>1 {print $1}' | head -1)

if [ -z "$TEMPLATES" ]; then
    msg_error "No Debian templates available. Please download one first:"
    echo "pveam update && pveam download local debian-12-standard_12.7-1_amd64.tar.zst"
    exit 1
fi

CT_TEMPLATE="$TEMPLATES"
CT_STORAGE="$STORAGES"

echo
msg_info "Container Configuration"
CTID=$(get_input "Container ID" "$CTID")
CT_NAME=$(get_input "Container Name" "$CT_NAME")
CT_DISK=$(get_input "Disk Size (GB)" "$CT_DISK")
CT_RAM=$(get_input "RAM (MB)" "$CT_RAM")
CT_CPU=$(get_input "CPU Cores" "$CT_CPU")

echo
msg_info "Security"
while [ -z "$CT_PASSWORD" ]; do
    read -s -p "Root Password: " CT_PASSWORD
    echo
    if [ -z "$CT_PASSWORD" ]; then
        msg_error "Password cannot be empty!"
    fi
done

echo
msg_info "API Keys (optional - can configure later)"
read -p "Configure API keys now? (y/N): " SETUP_KEYS

if [[ "$SETUP_KEYS" =~ ^[Yy] ]]; then
    DISCORD_TOKEN=$(get_input "Discord Bot Token" "")
    YOUTUBE_API_KEY=$(get_input "YouTube API Key" "")
    SPOTIFY_CLIENT_ID=$(get_input "Spotify Client ID (optional)" "")
    SPOTIFY_CLIENT_SECRET=$(get_input "Spotify Client Secret (optional)" "")
fi

echo
msg_info "Summary:"
echo "ID: $CTID | Name: $CT_NAME | Disk: ${CT_DISK}GB | RAM: ${CT_RAM}MB | CPU: $CT_CPU"
echo "Template: $CT_TEMPLATE"
echo

read -p "Create container? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
    msg_error "Cancelled"
    exit 0
fi

# Create container
msg_info "Creating LXC container"
pct create $CTID $CT_TEMPLATE \
    --hostname $CT_NAME \
    --storage $CT_STORAGE \
    --rootfs $CT_STORAGE:$CT_DISK \
    --memory $CT_RAM \
    --cores $CT_CPU \
    --password $CT_PASSWORD \
    --net0 name=eth0,bridge=vmbr0,ip=dhcp \
    --features nesting=1 \
    --unprivileged 1 \
    --onboot 1
msg_ok "Container created"

msg_info "Starting container"
pct start $CTID
sleep 5
msg_ok "Container started"

# Install packages
msg_info "Installing packages"
pct exec $CTID -- bash -c "
    apt update >/dev/null 2>&1
    apt install -y curl wget git ffmpeg python3 build-essential >/dev/null 2>&1
"
msg_ok "Packages installed"

# Install Node.js 18
msg_info "Installing Node.js 18"
pct exec $CTID -- bash -c "
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1
    apt install -y nodejs >/dev/null 2>&1
"
msg_ok "Node.js installed"

# Create user and install Muse
msg_info "Installing Muse"
pct exec $CTID -- bash -c "
    useradd -m -s /bin/bash muse
    sudo -u muse bash -c '
        cd /home/muse
        git clone https://github.com/museofficial/muse.git >/dev/null 2>&1
        cd muse
        git checkout \$(git describe --tags --abbrev=0) >/dev/null 2>&1
        npm install >/dev/null 2>&1
        cp .env.example .env
        sed -i \"s/DISCORD_TOKEN=.*/DISCORD_TOKEN=${DISCORD_TOKEN:-}/\" .env
        sed -i \"s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=${YOUTUBE_API_KEY:-}/\" .env
        sed -i \"s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=${SPOTIFY_CLIENT_ID:-}/\" .env
        sed -i \"s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=${SPOTIFY_CLIENT_SECRET:-}/\" .env
        echo \"CACHE_LIMIT=1GB\" >> .env
    '
"
msg_ok "Muse installed"

# Create systemd service
msg_info "Creating service"
pct exec $CTID -- bash -c "
cat > /etc/systemd/system/muse.service << 'EOF'
[Unit]
Description=Muse Discord Music Bot
After=network.target

[Service]
Type=simple
User=muse
WorkingDirectory=/home/muse/muse
ExecStart=/usr/bin/npm run start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable muse >/dev/null 2>&1
"
msg_ok "Service created"

# Final setup
CT_IP=$(pct exec $CTID -- ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null || echo "DHCP")

echo
msg_ok "Muse Discord Bot installed successfully!"
echo
echo "Container Details:"
echo "- ID: $CTID"
echo "- IP: $CT_IP"
echo "- Username: muse"
echo "- Location: /home/muse/muse"
echo

if [ -z "$DISCORD_TOKEN" ]; then
    echo "Next Steps:"
    echo "1. Configure API keys:"
    echo "   pct exec $CTID -- sudo -u muse nano /home/muse/muse/.env"
    echo "2. Start service:"
    echo "   pct exec $CTID -- systemctl start muse"
else
    echo "Starting Muse service..."
    pct exec $CTID -- systemctl start muse
    echo "Service started! Check logs:"
    echo "   pct exec $CTID -- journalctl -u muse -f"
fi

echo
echo "Useful commands:"
echo "- Access container: pct enter $CTID"
echo "- Check status: pct exec $CTID -- systemctl status muse"
echo "- View logs: pct exec $CTID -- journalctl -u muse -f"
