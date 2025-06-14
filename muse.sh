#!/usr/bin/env bash

# Simple Muse Discord Bot Installer
# Run this inside a Debian/Ubuntu container or VM

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

header() {
    echo "=========================================="
    echo "        Muse Discord Bot Installer"
    echo "=========================================="
    echo
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

clear
header

msg_info "This script will install Muse Discord Bot with all dependencies"
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    msg_warn "Running as root - will create 'muse' user for the bot"
    RUN_AS_ROOT=true
else
    msg_info "Running as regular user"
    RUN_AS_ROOT=false
fi

# Update system
msg_info "Updating system packages..."
if [ "$RUN_AS_ROOT" = true ]; then
    apt update && apt upgrade -y
else
    sudo apt update && sudo apt upgrade -y
fi
msg_ok "System updated"

# Install dependencies
msg_info "Installing dependencies..."
if [ "$RUN_AS_ROOT" = true ]; then
    apt install -y curl wget git ffmpeg python3 build-essential
else
    sudo apt install -y curl wget git ffmpeg python3 build-essential
fi
msg_ok "Dependencies installed"

# Install Node.js 18
msg_info "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | $([ "$RUN_AS_ROOT" = true ] && echo "bash -" || echo "sudo -E bash -")
if [ "$RUN_AS_ROOT" = true ]; then
    apt install -y nodejs
else
    sudo apt install -y nodejs
fi
msg_ok "Node.js installed ($(node --version))"

# Create muse user if running as root
if [ "$RUN_AS_ROOT" = true ]; then
    if ! id "muse" &>/dev/null; then
        msg_info "Creating muse user..."
        useradd -m -s /bin/bash muse
        msg_ok "User 'muse' created"
    else
        msg_info "User 'muse' already exists"
    fi
    MUSE_USER="muse"
    MUSE_HOME="/home/muse"
else
    MUSE_USER="$USER"
    MUSE_HOME="$HOME"
fi

# Install Muse
msg_info "Installing Muse Discord Bot..."
if [ "$RUN_AS_ROOT" = true ]; then
    sudo -u muse bash -c "
        cd $MUSE_HOME
        if [ -d 'muse' ]; then
            echo 'Muse directory exists, removing...'
            rm -rf muse
        fi
        git clone https://github.com/museofficial/muse.git
        cd muse
        LATEST_TAG=\$(git describe --tags --abbrev=0)
        git checkout \$LATEST_TAG
        echo 'Checked out to: '\$LATEST_TAG
        npm install
        cp .env.example .env
        echo 'CACHE_LIMIT=1GB' >> .env
    "
else
    cd "$MUSE_HOME"
    if [ -d 'muse' ]; then
        msg_info "Muse directory exists, removing..."
        rm -rf muse
    fi
    git clone https://github.com/museofficial/muse.git
    cd muse
    LATEST_TAG=$(git describe --tags --abbrev=0)
    git checkout $LATEST_TAG
    echo "Checked out to: $LATEST_TAG"
    npm install
    cp .env.example .env
    echo 'CACHE_LIMIT=1GB' >> .env
fi
msg_ok "Muse installed"

# Configure API keys
echo
msg_info "API Key Configuration"
echo "You need to configure these API keys for Muse to work:"
echo

read -p "Do you want to configure API keys now? (y/N): " CONFIGURE_NOW
if [[ "$CONFIGURE_NOW" =~ ^[Yy] ]]; then
    echo
    msg_info "Discord Bot Token"
    echo "Get it from: https://discord.com/developers/applications"
    DISCORD_TOKEN=$(get_input "Discord Bot Token" "")
    
    echo
    msg_info "YouTube API Key"
    echo "Get it from: https://console.developers.google.com"
    YOUTUBE_API_KEY=$(get_input "YouTube API Key" "")
    
    echo
    read -p "Configure Spotify integration? (y/N): " SPOTIFY_SETUP
    if [[ "$SPOTIFY_SETUP" =~ ^[Yy] ]]; then
        echo "Get these from: https://developer.spotify.com/dashboard"
        SPOTIFY_CLIENT_ID=$(get_input "Spotify Client ID" "")
        SPOTIFY_CLIENT_SECRET=$(get_input "Spotify Client Secret" "")
    fi
    
    # Update .env file
    msg_info "Updating configuration..."
    if [ "$RUN_AS_ROOT" = true ]; then
        sudo -u muse bash -c "
            cd $MUSE_HOME/muse
            sed -i 's/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/' .env
            sed -i 's/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/' .env
            $([ -n "$SPOTIFY_CLIENT_ID" ] && echo "sed -i 's/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/' .env")
            $([ -n "$SPOTIFY_CLIENT_SECRET" ] && echo "sed -i 's/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/' .env")
        "
    else
        cd "$MUSE_HOME/muse"
        sed -i "s/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/" .env
        sed -i "s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/" .env
        [ -n "$SPOTIFY_CLIENT_ID" ] && sed -i "s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/" .env
        [ -n "$SPOTIFY_CLIENT_SECRET" ] && sed -i "s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/" .env
    fi
    msg_ok "Configuration updated"
    
    KEYS_CONFIGURED=true
else
    KEYS_CONFIGURED=false
fi

# Create systemd service (only if root)
if [ "$RUN_AS_ROOT" = true ]; then
    msg_info "Creating systemd service..."
    cat > /etc/systemd/system/muse.service << EOF
[Unit]
Description=Muse Discord Music Bot
After=network.target

[Service]
Type=simple
User=muse
Group=muse
WorkingDirectory=$MUSE_HOME/muse
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable muse
    msg_ok "Service created and enabled"
fi

# Final instructions
echo
msg_ok "Muse Discord Bot installation completed!"
echo
echo "Installation Details:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "User: $MUSE_USER"
echo "Location: $MUSE_HOME/muse"
echo "Config: $MUSE_HOME/muse/.env"
echo "API Keys: $([ "$KEYS_CONFIGURED" = true ] && echo "✓ Configured" || echo "✗ Not configured")"
echo

if [ "$KEYS_CONFIGURED" = false ]; then
    echo "Next Steps:"
    echo "1. Configure API keys:"
    echo "   nano $MUSE_HOME/muse/.env"
    echo
    echo "Required API keys:"
    echo "• DISCORD_TOKEN (from https://discord.com/developers/applications)"
    echo "• YOUTUBE_API_KEY (from https://console.developers.google.com)"
    echo "• SPOTIFY_CLIENT_ID & SECRET (optional, from https://developer.spotify.com)"
    echo
fi

echo "To run Muse:"
if [ "$RUN_AS_ROOT" = true ]; then
    if [ "$KEYS_CONFIGURED" = true ]; then
        echo "• Start service: systemctl start muse"
        echo "• Check status: systemctl status muse"
        echo "• View logs: journalctl -u muse -f"
    else
        echo "• Configure keys first, then: systemctl start muse"
    fi
    echo "• Stop service: systemctl stop muse"
else
    echo "• cd $MUSE_HOME/muse && npm start"
fi
echo
echo "The bot will display a Discord invite URL when started."
echo "Use that URL to add Muse to your Discord server!"

if [ "$RUN_AS_ROOT" = true ] && [ "$KEYS_CONFIGURED" = true ]; then
    echo
    read -p "Start Muse service now? (y/N): " START_NOW
    if [[ "$START_NOW" =~ ^[Yy] ]]; then
        msg_info "Starting Muse service..."
        systemctl start muse
        sleep 3
        echo
        echo "Service started! Check logs:"
        echo "journalctl -u muse -f"
    fi
fi
