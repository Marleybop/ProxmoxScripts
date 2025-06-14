#!/usr/bin/env bash

# Muse Discord Bot GUI Installer for Proxmox LXC
# Simple dialog-based installation with API key setup

# Check and install dialog if needed
if ! command -v dialog >/dev/null 2>&1; then
    echo "Installing dialog..."
    apt update && apt install -y dialog
fi

# Temp files
TEMP_DIR=$(mktemp -d)
CONFIG_FILE="$TEMP_DIR/config"
cleanup() { rm -rf "$TEMP_DIR"; clear; }
trap cleanup EXIT

# Error handler
error_exit() {
    dialog --title "Error" --msgbox "$1" 8 60
    exit 1
}

# Welcome screen
dialog --title "Muse Discord Bot Installer" \
    --msgbox "Welcome to the Muse Discord Bot installer!\n\nThis will create a Proxmox LXC container and install Muse with all dependencies.\n\nPress OK to continue." 12 60

# Container configuration
dialog --title "Container ID" \
    --inputbox "Enter container ID (100-999999999):" 8 50 "200" 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
CTID=$(cat "$CONFIG_FILE")

# Validate container ID
if ! [[ "$CTID" =~ ^[0-9]+$ ]] || [ "$CTID" -lt 100 ] || [ "$CTID" -gt 999999999 ]; then
    error_exit "Invalid container ID!"
fi

if pct list | grep -q "^$CTID "; then
    error_exit "Container $CTID already exists!"
fi

dialog --title "Container Name" \
    --inputbox "Enter container name:" 8 50 "muse-bot" 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
CT_NAME=$(cat "$CONFIG_FILE")

dialog --title "Root Password" \
    --passwordbox "Enter root password for the container:" 8 50 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
CT_PASSWORD=$(cat "$CONFIG_FILE")

if [ -z "$CT_PASSWORD" ]; then
    error_exit "Password cannot be empty!"
fi

# Container resources
dialog --title "Container Resources" \
    --form "Configure container resources:" 12 50 4 \
    "RAM (MB):" 1 1 "2048" 1 12 10 0 \
    "CPU Cores:" 2 1 "2" 2 12 10 0 \
    "Disk (GB):" 3 1 "8" 3 12 10 0 \
    "Storage:" 4 1 "local-lvm" 4 12 15 0 \
    2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0

# Parse form results
CT_RAM=$(sed -n '1p' "$CONFIG_FILE")
CT_CPU=$(sed -n '2p' "$CONFIG_FILE")
CT_DISK=$(sed -n '3p' "$CONFIG_FILE")
CT_STORAGE=$(sed -n '4p' "$CONFIG_FILE")

# Template selection
dialog --title "Template" \
    --inputbox "Enter Debian template name:" 8 60 "debian-12-standard_12.7-1_amd64.tar.zst" 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
CT_TEMPLATE=$(cat "$CONFIG_FILE")

# API Keys configuration
dialog --title "API Keys Setup" \
    --yesno "Do you want to configure API keys now?\n\n(Required for Muse to function)\n\nYou'll need:\n• Discord Bot Token\n• YouTube API Key\n• Spotify keys (optional)" 12 60

if [ $? -eq 0 ]; then
    # Discord Token
    dialog --title "Discord Bot Token" \
        --inputbox "Enter your Discord Bot Token:\n\nGet it from: https://discord.com/developers/applications" 10 70 2>"$CONFIG_FILE"
    [ $? -ne 0 ] && exit 0
    DISCORD_TOKEN=$(cat "$CONFIG_FILE")
    
    # YouTube API Key
    dialog --title "YouTube API Key" \
        --inputbox "Enter your YouTube API Key:\n\nGet it from: https://console.developers.google.com" 10 70 2>"$CONFIG_FILE"
    [ $? -ne 0 ] && exit 0
    YOUTUBE_API_KEY=$(cat "$CONFIG_FILE")
    
    # Spotify (optional)
    dialog --title "Spotify API Keys" \
        --yesno "Do you want to configure Spotify integration?\n\n(Optional - for playlist conversion)" 8 60
    
    if [ $? -eq 0 ]; then
        dialog --title "Spotify Client ID" \
            --inputbox "Enter Spotify Client ID:\n\nGet it from: https://developer.spotify.com/dashboard" 10 70 2>"$CONFIG_FILE"
        [ $? -ne 0 ] && exit 0
        SPOTIFY_CLIENT_ID=$(cat "$CONFIG_FILE")
        
        dialog --title "Spotify Client Secret" \
            --inputbox "Enter Spotify Client Secret:" 8 60 2>"$CONFIG_FILE"
        [ $? -ne 0 ] && exit 0
        SPOTIFY_CLIENT_SECRET=$(cat "$CONFIG_FILE")
    fi
    
    SETUP_KEYS="yes"
else
    SETUP_KEYS="no"
fi

# Configuration summary
SUMMARY="Container Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━
• ID: $CTID
• Name: $CT_NAME
• Template: $CT_TEMPLATE
• Storage: $CT_STORAGE
• RAM: ${CT_RAM}MB
• CPU: $CT_CPU cores
• Disk: ${CT_DISK}GB

API Keys: $([ "$SETUP_KEYS" = "yes" ] && echo "✓ Configured" || echo "✗ Will configure later")"

dialog --title "Confirm Installation" \
    --yesno "$SUMMARY\n\nProceed with installation?" 18 70
[ $? -ne 0 ] && exit 0

# Installation with progress
{
    echo "0" ; echo "Creating LXC container..."
    
    # Create container
    pct create $CTID local:vztmpl/$CT_TEMPLATE \
        --hostname $CT_NAME \
        --storage $CT_STORAGE \
        --rootfs $CT_STORAGE:$CT_DISK \
        --memory $CT_RAM \
        --cores $CT_CPU \
        --password $CT_PASSWORD \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 >/dev/null 2>&1
    
    echo "15" ; echo "Starting container..."
    pct start $CTID >/dev/null 2>&1
    sleep 10
    
    echo "25" ; echo "Updating system packages..."
    pct exec $CTID -- apt update >/dev/null 2>&1
    pct exec $CTID -- apt upgrade -y >/dev/null 2>&1
    
    echo "40" ; echo "Installing dependencies..."
    pct exec $CTID -- apt install -y curl wget git ffmpeg python3 build-essential >/dev/null 2>&1
    
    echo "55" ; echo "Installing Node.js 18..."
    pct exec $CTID -- bash -c "curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1"
    pct exec $CTID -- apt install -y nodejs >/dev/null 2>&1
    
    echo "70" ; echo "Creating muse user..."
    pct exec $CTID -- useradd -m -s /bin/bash muse >/dev/null 2>&1
    
    echo "80" ; echo "Installing Muse Discord Bot..."
    pct exec $CTID -- sudo -u muse bash -c "
        cd /home/muse
        git clone https://github.com/museofficial/muse.git >/dev/null 2>&1
        cd muse
        git checkout \$(git describe --tags --abbrev=0) >/dev/null 2>&1
        npm install >/dev/null 2>&1
        cp .env.example .env
        echo 'CACHE_LIMIT=1GB' >> .env
    " >/dev/null 2>&1
    
    echo "90" ; echo "Configuring API keys..."
    if [ "$SETUP_KEYS" = "yes" ]; then
        pct exec $CTID -- sudo -u muse bash -c "
            cd /home/muse/muse
            sed -i 's/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/' .env
            sed -i 's/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/' .env
            sed -i 's/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=${SPOTIFY_CLIENT_ID:-}/' .env
            sed -i 's/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=${SPOTIFY_CLIENT_SECRET:-}/' .env
        " >/dev/null 2>&1
    fi
    
    echo "95" ; echo "Creating systemd service..."
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
    " >/dev/null 2>&1
    
    echo "100" ; echo "Installation complete!"
    
} | dialog --title "Installing Muse" --gauge "Preparing installation..." 8 60 0

# Get container IP
CT_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}' 2>/dev/null || echo "Check manually")

# Success message
if [ "$SETUP_KEYS" = "yes" ]; then
    # Start service automatically if keys are configured
    pct exec $CTID -- systemctl start muse >/dev/null 2>&1
    
    RESULT_MSG="✅ Muse Discord Bot installed successfully!

Container Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Container ID: $CTID
• Container IP: $CT_IP
• Service Status: Started

✅ API keys configured and service started!

Next Steps:
1. Check logs for Discord invite URL:
   pct exec $CTID -- journalctl -u muse -f

2. The bot will show an invite link in the logs
3. Use that link to add the bot to your Discord server

Useful Commands:
• Access container: pct enter $CTID
• Check status: pct exec $CTID -- systemctl status muse
• Restart bot: pct exec $CTID -- systemctl restart muse"

else
    
    RESULT_MSG="✅ Muse Discord Bot installed successfully!

Container Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Container ID: $CTID
• Container IP: $CT_IP
• Service Status: Ready (not started)

⚠️  API keys not configured yet.

Next Steps:
1. Configure API keys:
   pct exec $CTID -- sudo -u muse nano /home/muse/muse/.env

2. Start the service:
   pct exec $CTID -- systemctl start muse

3. Check logs for Discord invite URL:
   pct exec $CTID -- journalctl -u muse -f

Required API Keys:
• DISCORD_TOKEN (from discord.com/developers/applications)
• YOUTUBE_API_KEY (from console.developers.google.com)
• SPOTIFY_CLIENT_ID & SECRET (optional, from developer.spotify.com)

Useful Commands:
• Access container: pct enter $CTID
• Check status: pct exec $CTID -- systemctl status muse"

fi

dialog --title "Installation Complete" --msgbox "$RESULT_MSG" 25 80

# Offer to show logs if service is running
if [ "$SETUP_KEYS" = "yes" ]; then
    dialog --title "View Logs" --yesno "Would you like to view the Muse logs now?\n\n(Look for the Discord invite URL)" 8 60
    if [ $? -eq 0 ]; then
        clear
        echo "=== Muse Bot Logs (Press Ctrl+C to exit) ==="
        echo "Look for the Discord invite URL in the logs below:"
        echo
        pct exec $CTID -- journalctl -u muse -f
    fi
fi
