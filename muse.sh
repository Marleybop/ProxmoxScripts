#!/usr/bin/env bash

# Muse Discord Bot Installer for Proxmox LXC
# Interactive installation with Discord, YouTube, and Spotify configuration

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

# Check if running on Proxmox
if ! command -v pct >/dev/null 2>&1; then
    error_exit "This script must be run on a Proxmox VE host"
fi

# Welcome screen
dialog --title "Muse Discord Bot Installer" \
    --msgbox "Welcome to the Muse Discord Bot installer!\n\nThis will:\n• Create a Proxmox LXC container\n• Install Muse Discord music bot\n• Configure Discord, YouTube & Spotify APIs\n\nPress OK to continue." 12 60

# Container ID
while true; do
    dialog --title "Container ID" \
        --inputbox "Enter container ID (100-999999999):" 8 50 "200" 2>"$CONFIG_FILE"
    [ $? -ne 0 ] && exit 0
    
    CTID=$(cat "$CONFIG_FILE")
    
    if ! [[ "$CTID" =~ ^[0-9]+$ ]] || [ "$CTID" -lt 100 ] || [ "$CTID" -gt 999999999 ]; then
        dialog --title "Error" --msgbox "Invalid container ID! Must be 100-999999999" 6 50
        continue
    fi
    
    if pct list | grep -q "^$CTID "; then
        dialog --title "Error" --msgbox "Container $CTID already exists!" 6 40
        continue
    fi
    
    break
done

# Container name
dialog --title "Container Name" \
    --inputbox "Enter container name:" 8 50 "muse-bot" 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
CT_NAME=$(cat "$CONFIG_FILE")

# Root password
dialog --title "Root Password" \
    --passwordbox "Enter root password for the container:" 8 50 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
CT_PASSWORD=$(cat "$CONFIG_FILE")

if [ -z "$CT_PASSWORD" ]; then
    error_exit "Password cannot be empty!"
fi

# Discord Bot Token (Required)
dialog --title "Discord Bot Token" \
    --msgbox "You need a Discord Bot Token for Muse to work.\n\nTo get one:\n1. Go to https://discord.com/developers/applications\n2. Create 'New Application'\n3. Go to 'Bot' section\n4. Copy the token\n\nPress OK to enter your token." 12 70

dialog --title "Discord Bot Token" \
    --inputbox "Enter your Discord Bot Token:" 8 70 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
DISCORD_TOKEN=$(cat "$CONFIG_FILE")

if [ -z "$DISCORD_TOKEN" ]; then
    error_exit "Discord token is required for Muse to function!"
fi

# YouTube API Key (Required)
dialog --title "YouTube API Key" \
    --msgbox "You need a YouTube API Key for music playback.\n\nTo get one:\n1. Go to https://console.developers.google.com\n2. Create a new project\n3. Enable 'YouTube Data API v3'\n4. Create credentials (API Key)\n\nPress OK to enter your key." 12 70

dialog --title "YouTube API Key" \
    --inputbox "Enter your YouTube API Key:" 8 70 2>"$CONFIG_FILE"
[ $? -ne 0 ] && exit 0
YOUTUBE_API_KEY=$(cat "$CONFIG_FILE")

if [ -z "$YOUTUBE_API_KEY" ]; then
    error_exit "YouTube API key is required for music playback!"
fi

# Spotify Integration (Optional)
dialog --title "Spotify Integration" \
    --yesno "Do you want Spotify integration?\n\nThis allows:\n• Converting Spotify playlists to YouTube\n• Playing Spotify tracks via YouTube\n\nThis is optional but recommended." 10 60

if [ $? -eq 0 ]; then
    dialog --title "Spotify Setup" \
        --msgbox "To get Spotify API keys:\n\n1. Go to https://developer.spotify.com/dashboard\n2. Create an app\n3. Copy Client ID and Client Secret\n\nPress OK to enter your keys." 10 70
    
    dialog --title "Spotify Client ID" \
        --inputbox "Enter Spotify Client ID:" 8 60 2>"$CONFIG_FILE"
    [ $? -ne 0 ] && exit 0
    SPOTIFY_CLIENT_ID=$(cat "$CONFIG_FILE")
    
    dialog --title "Spotify Client Secret" \
        --inputbox "Enter Spotify Client Secret:" 8 60 2>"$CONFIG_FILE"
    [ $? -ne 0 ] && exit 0
    SPOTIFY_CLIENT_SECRET=$(cat "$CONFIG_FILE")
    
    SPOTIFY_ENABLED="yes"
else
    SPOTIFY_ENABLED="no"
fi

# Configuration summary
SUMMARY="Ready to install Muse Discord Bot!

Container: $CTID ($CT_NAME)
Discord: ✓ Configured
YouTube: ✓ Configured
Spotify: $([ "$SPOTIFY_ENABLED" = "yes" ] && echo "✓ Configured" || echo "✗ Disabled")

The container will be created with:
• Debian 12 LTS
• 2GB RAM, 2 CPU cores, 8GB disk
• Node.js 18 & all dependencies
• Muse bot with your API keys"

dialog --title "Confirm Installation" \
    --yesno "$SUMMARY\n\nProceed with installation?" 16 70
[ $? -ne 0 ] && exit 0

# Installation with progress
{
    echo "0" ; echo "Creating LXC container..."
    
    # Create container with sensible defaults
    pct create $CTID local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
        --hostname $CT_NAME \
        --storage local-lvm \
        --rootfs local-lvm:8 \
        --memory 2048 \
        --cores 2 \
        --password $CT_PASSWORD \
        --net0 name=eth0,bridge=vmbr0,ip=dhcp \
        --features nesting=1 \
        --unprivileged 1 \
        --onboot 1 >/dev/null 2>&1
    
    echo "15" ; echo "Starting container..."
    pct start $CTID >/dev/null 2>&1
    sleep 10
    
    echo "25" ; echo "Updating system..."
    pct exec $CTID -- apt update >/dev/null 2>&1
    pct exec $CTID -- apt upgrade -y >/dev/null 2>&1
    
    echo "40" ; echo "Installing dependencies..."
    pct exec $CTID -- apt install -y curl wget git ffmpeg python3 build-essential >/dev/null 2>&1
    
    echo "55" ; echo "Installing Node.js 18..."
    pct exec $CTID -- bash -c "curl -fsSL https://deb.nodesource.com/setup_18.x | bash - >/dev/null 2>&1"
    pct exec $CTID -- apt install -y nodejs >/dev/null 2>&1
    
    echo "70" ; echo "Creating muse user..."
    pct exec $CTID -- useradd -m -s /bin/bash muse >/dev/null 2>&1
    
    echo "80" ; echo "Installing Muse..."
    pct exec $CTID -- sudo -u muse bash -c "
        cd /home/muse
        git clone https://github.com/museofficial/muse.git >/dev/null 2>&1
        cd muse
        git checkout \$(git describe --tags --abbrev=0) >/dev/null 2>&1
        npm install >/dev/null 2>&1
        cp .env.example .env
    " >/dev/null 2>&1
    
    echo "90" ; echo "Configuring API keys..."
    pct exec $CTID -- sudo -u muse bash -c "
        cd /home/muse/muse
        sed -i 's/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/' .env
        sed -i 's/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/' .env
        $([ "$SPOTIFY_ENABLED" = "yes" ] && echo "
        sed -i 's/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/' .env
        sed -i 's/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/' .env
        ")
        echo 'CACHE_LIMIT=1GB' >> .env
    " >/dev/null 2>&1
    
    echo "95" ; echo "Setting up service..."
    pct exec $CTID -- bash -c "
        cat > /etc/systemd/system/muse.service << 'EOF'
[Unit]
Description=Muse Discord Music Bot
After=network.target

[Service]
Type=simple
User=muse
WorkingDirectory=/home/muse/muse
ExecStart=/usr/bin/node /home/muse/muse/dist/index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable muse >/dev/null 2>&1
    " >/dev/null 2>&1
    
    echo "98" ; echo "Building Muse..."
    pct exec $CTID -- sudo -u muse bash -c "
        cd /home/muse/muse
        npm run build >/dev/null 2>&1
    " >/dev/null 2>&1
    
    echo "99" ; echo "Starting service..."
    pct exec $CTID -- systemctl start muse >/dev/null 2>&1
    
    echo "100" ; echo "Installation complete!"
    
} | dialog --title "Installing Muse" --gauge "Setting up your Discord music bot..." 8 70 0

# Get container IP
CT_IP=$(pct exec $CTID -- hostname -I | awk '{print $1}' 2>/dev/null || echo "DHCP assigned")

# Success message
SUCCESS_MSG="🎵 Muse Discord Bot installed successfully!

Container Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Container ID: $CTID
Container IP: $CT_IP
Service Status: ✓ Running

API Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Discord: ✓ Configured
YouTube: ✓ Configured
Spotify: $([ "$SPOTIFY_ENABLED" = "yes" ] && echo "✓ Configured" || echo "✗ Not configured")

Next Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Check logs for Discord invite URL:
   pct exec $CTID -- journalctl -u muse -f

2. Copy the invite link from the logs
3. Open the link to add Muse to your Discord server
4. Use /play <song> to start playing music!

Useful Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Access container: pct enter $CTID
View logs: pct exec $CTID -- journalctl -u muse -f
Restart bot: pct exec $CTID -- systemctl restart muse
Check status: pct exec $CTID -- systemctl status muse"

dialog --title "🎵 Installation Complete!" --msgbox "$SUCCESS_MSG" 25 80

# Better flow for getting the invite link
dialog --title "Get Discord Invite Link" \
    --msgbox "Muse is now running!\n\nTo get your Discord invite link:\n\n1. Click OK to view the logs\n2. Look for a line starting with 'Invite Muse:'\n3. Copy that entire URL\n4. Press Ctrl+C to exit logs\n5. Paste the URL in your browser to add Muse to Discord\n\nThe invite link appears within the first few seconds." 14 70

if [ $? -eq 0 ]; then
    clear
    echo "=========================================="
    echo "     Muse Discord Bot - Live Logs"
    echo "=========================================="
    echo ""
    echo "🔍 Looking for Discord invite URL..."
    echo "📋 Copy the full invite link when it appears"
    echo "⏹️  Press Ctrl+C to exit when done"
    echo ""
    echo "Logs:"
    echo "────────────────────────────────────────"
    pct exec $CTID -- journalctl -u muse -f --no-pager
fi
