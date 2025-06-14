#!/bin/bash

# Proxmox Muse Discord Bot LXC Container Setup Script - GUI Version
# This script provides a dialog-based GUI for setting up Muse

# Check if dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "Installing dialog for GUI..."
    apt update && apt install -y dialog
fi

# Temporary files for dialog
TEMP_FILE=$(mktemp)
CONFIG_FILE=$(mktemp)

# Cleanup function
cleanup() {
    rm -f "$TEMP_FILE" "$CONFIG_FILE"
}
trap cleanup EXIT

# Function to show error and exit
show_error() {
    dialog --title "Error" --msgbox "$1" 8 60
    exit 1
}

# Welcome screen
dialog --title "Proxmox Muse Setup" --msgbox "Welcome to the Proxmox Muse Discord Bot Setup!\n\nThis wizard will guide you through creating an LXC container and installing the Muse Discord music bot.\n\nPress OK to continue." 12 60

# Container ID
while true; do
    dialog --title "Container ID" --inputbox "Enter container ID (100-999999999):" 8 60 "200" 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    
    CONTAINER_ID=$(cat "$TEMP_FILE")
    if [[ "$CONTAINER_ID" =~ ^[0-9]+$ ]] && [ "$CONTAINER_ID" -ge 100 ] && [ "$CONTAINER_ID" -le 999999999 ]; then
        if ! pct list | grep -q "^$CONTAINER_ID"; then
            break
        else
            dialog --title "Error" --msgbox "Container ID $CONTAINER_ID already exists!" 6 50
        fi
    else
        dialog --title "Error" --msgbox "Invalid container ID! Must be a number between 100-999999999." 6 60
    fi
done

# Container name
dialog --title "Container Name" --inputbox "Enter container name:" 8 60 "muse-bot" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
CONTAINER_NAME=$(cat "$TEMP_FILE")

# Template selection
TEMPLATES=$(pveam list local | grep debian | awk '{print NR " " $2}')
if [ -z "$TEMPLATES" ]; then
    dialog --title "Templates" --inputbox "No Debian templates found. Enter template name manually:" 8 60 "debian-12-standard_12.2-1_amd64.tar.zst" 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    TEMPLATE=$(cat "$TEMP_FILE")
else
    eval "dialog --title 'Select Template' --menu 'Choose a Debian template:' 15 80 8 $TEMPLATES" 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    TEMPLATE_NUM=$(cat "$TEMP_FILE")
    TEMPLATE=$(pveam list local | grep debian | sed -n "${TEMPLATE_NUM}p" | awk '{print $2}')
fi

# Storage selection
STORAGES=$(pvesm status | grep -E "(active|enabled)" | awk '{print NR " " $1 "(" $2 ")"}')
eval "dialog --title 'Select Storage' --menu 'Choose storage:' 15 60 8 $STORAGES" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
STORAGE_NUM=$(cat "$TEMP_FILE")
STORAGE=$(pvesm status | grep -E "(active|enabled)" | sed -n "${STORAGE_NUM}p" | awk '{print $1}')

# Resource configuration
dialog --title "Root Filesystem Size" --inputbox "Enter root filesystem size:" 8 40 "8G" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
ROOT_SIZE=$(cat "$TEMP_FILE")

dialog --title "Memory" --inputbox "Enter memory in MB:" 8 40 "2048" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
MEMORY=$(cat "$TEMP_FILE")

dialog --title "CPU Cores" --inputbox "Enter number of CPU cores:" 8 40 "2" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
CORES=$(cat "$TEMP_FILE")

# Network configuration
dialog --title "Network Bridge" --inputbox "Enter network bridge:" 8 40 "vmbr0" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
NETWORK=$(cat "$TEMP_FILE")

# IP Configuration
dialog --title "IP Configuration" --menu "Choose IP configuration:" 10 60 2 \
    1 "DHCP (automatic)" \
    2 "Static IP" 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi

IP_CHOICE=$(cat "$TEMP_FILE")
if [ "$IP_CHOICE" = "2" ]; then
    dialog --title "Static IP" --inputbox "Enter static IP with subnet (e.g., 192.168.1.100/24):" 8 60 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    IP_ADDRESS=$(cat "$TEMP_FILE")
else
    IP_ADDRESS="dhcp"
fi

# Root password
dialog --title "Root Password" --passwordbox "Enter root password:" 8 40 2>"$TEMP_FILE"
if [ $? -ne 0 ]; then exit 1; fi
PASSWORD=$(cat "$TEMP_FILE")

# API Keys configuration
dialog --title "API Keys" --yesno "Do you want to configure API keys now?\n\n(You can also configure them later)" 8 50
if [ $? -eq 0 ]; then
    dialog --title "Discord Token" --inputbox "Enter Discord Bot Token:" 8 60 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    DISCORD_TOKEN=$(cat "$TEMP_FILE")
    
    dialog --title "YouTube API Key" --inputbox "Enter YouTube API Key:" 8 60 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    YOUTUBE_API_KEY=$(cat "$TEMP_FILE")
    
    dialog --title "Spotify Client ID" --inputbox "Enter Spotify Client ID (optional):" 8 60 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    SPOTIFY_CLIENT_ID=$(cat "$TEMP_FILE")
    
    dialog --title "Spotify Client Secret" --inputbox "Enter Spotify Client Secret (optional):" 8 60 2>"$TEMP_FILE"
    if [ $? -ne 0 ]; then exit 1; fi
    SPOTIFY_CLIENT_SECRET=$(cat "$TEMP_FILE")
else
    DISCORD_TOKEN=""
    YOUTUBE_API_KEY=""
    SPOTIFY_CLIENT_ID=""
    SPOTIFY_CLIENT_SECRET=""
fi

# Configuration summary
SUMMARY="Container ID: $CONTAINER_ID
Container Name: $CONTAINER_NAME
Template: $TEMPLATE
Storage: $STORAGE
Root Size: $ROOT_SIZE
Memory: ${MEMORY}MB
Cores: $CORES
Network: $NETWORK
IP: $IP_ADDRESS
API Keys: $([ -n "$DISCORD_TOKEN" ] && echo "Configured" || echo "Will configure later")"

dialog --title "Configuration Summary" --yesno "$SUMMARY\n\nProceed with installation?" 15 70
if [ $? -ne 0 ]; then
    dialog --title "Cancelled" --infobox "Installation cancelled." 5 30
    sleep 2
    exit 0
fi

# Progress dialog function
show_progress() {
    local step=$1
    local total=$2
    local message=$3
    local percent=$((step * 100 / total))
    
    echo "$percent" | dialog --title "Installing..." --gauge "$message" 8 60 0
}

# Installation process with progress
{
    echo "10" ; echo "Creating LXC container..."
    
    # Create LXC container
    pct create $CONTAINER_ID $TEMPLATE \
        --hostname $CONTAINER_NAME \
        --storage $STORAGE \
        --rootfs $STORAGE:$ROOT_SIZE \
        --memory $MEMORY \
        --cores $CORES \
        --password $PASSWORD \
        --net0 name=eth0,bridge=$NETWORK,ip=$IP_ADDRESS \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 >/dev/null 2>&1
    
    echo "25" ; echo "Starting container..."
    pct start $CONTAINER_ID >/dev/null 2>&1
    sleep 10
    
    echo "40" ; echo "Updating system packages..."
    pct exec $CONTAINER_ID -- apt update >/dev/null 2>&1
    pct exec $CONTAINER_ID -- apt upgrade -y >/dev/null 2>&1
    
    echo "55" ; echo "Installing dependencies..."
    pct exec $CONTAINER_ID -- apt install -y curl wget git ffmpeg python3 python3-pip build-essential >/dev/null 2>&1
    
    echo "70" ; echo "Installing Node.js 18..."
    pct exec $CONTAINER_ID -- bash -c "curl -fsSL https://deb.nodesource.com/setup_18.x | bash -" >/dev/null 2>&1
    pct exec $CONTAINER_ID -- apt install -y nodejs >/dev/null 2>&1
    
    echo "85" ; echo "Setting up Muse bot..."
    pct exec $CONTAINER_ID -- useradd -m -s /bin/bash muse >/dev/null 2>&1
    pct exec $CONTAINER_ID -- usermod -aG sudo muse >/dev/null 2>&1
    
    # Install Muse
    pct exec $CONTAINER_ID -- sudo -u muse bash -c "
        cd /home/muse
        git clone https://github.com/museofficial/muse.git >/dev/null 2>&1
        cd muse
        LATEST_TAG=\$(git describe --tags --abbrev=0)
        git checkout \$LATEST_TAG >/dev/null 2>&1
        npm install >/dev/null 2>&1
        cp .env.example .env
        
        # Configure environment
        sed -i \"s/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/\" .env
        sed -i \"s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/\" .env
        sed -i \"s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/\" .env
        sed -i \"s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/\" .env
        echo \"CACHE_LIMIT=1GB\" >> .env
    " >/dev/null 2>&1
    
    # Create systemd service
    pct exec $CONTAINER_ID -- bash -c "
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
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable muse.service >/dev/null 2>&1
    "
    
    echo "100" ; echo "Installation complete!"
    
} | dialog --title "Installing Muse" --gauge "Preparing installation..." 8 60 0

# Success message
NEXT_STEPS="Installation completed successfully!

Container Information:
- ID: $CONTAINER_ID
- Name: $CONTAINER_NAME

Next Steps:
$(if [ -z "$DISCORD_TOKEN" ]; then
echo "1. Configure API keys:
   pct exec $CONTAINER_ID -- sudo -u muse nano /home/muse/muse/.env

2. Start the service:
   pct exec $CONTAINER_ID -- systemctl start muse"
else
echo "1. Start the service:
   pct exec $CONTAINER_ID -- systemctl start muse"
fi)

3. Check status:
   pct exec $CONTAINER_ID -- systemctl status muse

4. View logs:
   pct exec $CONTAINER_ID -- journalctl -u muse -f

Access container: pct enter $CONTAINER_ID"

dialog --title "Installation Complete" --msgbox "$NEXT_STEPS" 20 80

# Offer to start the service if API keys are configured
if [ -n "$DISCORD_TOKEN" ]; then
    dialog --title "Start Service" --yesno "API keys are configured. Would you like to start the Muse service now?" 8 60
    if [ $? -eq 0 ]; then
        pct exec $CONTAINER_ID -- systemctl start muse
        dialog --title "Service Started" --msgbox "Muse service has been started!\n\nCheck the logs for the Discord invite URL:\npct exec $CONTAINER_ID -- journalctl -u muse -f" 10 60
    fi
fi
