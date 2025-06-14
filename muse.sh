#!/usr/bin/env bash

# Muse Discord Bot Installer - Following Official Docs Exactly
# https://github.com/museofficial/muse

set -e

echo "=========================================="
echo "        Muse Discord Bot Installer"
echo "=========================================="
echo

# Install prerequisites
echo "[INFO] Installing prerequisites..."
apt update
apt install -y curl wget git ffmpeg build-essential

# Install Node.js 18 LTS (required for opus dependency)
echo "[INFO] Installing Node.js 18 LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs

echo "[OK] Node.js $(node --version) installed"

# Remove conflicting yarn if it exists (the cmdtest package)
if [ -f /usr/bin/yarn ] && [ "$(yarn --version 2>/dev/null)" = "0.32+git" ]; then
    echo "[INFO] Removing conflicting yarn package..."
    rm /usr/bin/yarn
fi

# Install proper yarn
echo "[INFO] Installing Yarn..."
npm install -g yarn
echo "[OK] Yarn $(yarn --version) installed"

# Create muse user if running as root
if [ "$EUID" -eq 0 ]; then
    if ! id "muse" &>/dev/null; then
        useradd -m -s /bin/bash muse
        echo "[INFO] Created user 'muse'"
    fi
    
    echo "[INFO] Installing Muse as user 'muse'..."
    
    # Run installation as muse user
    su - muse << 'EOF'
# Step 1: Clone repository
git clone https://github.com/museofficial/muse.git && cd muse

# Step 2: Copy .env.example to .env
cp .env.example .env

# Step 3: Checkout latest release
LATEST_TAG=$(git describe --tags --abbrev=0)
git checkout $LATEST_TAG
echo "Checked out to: $LATEST_TAG"

# Step 4: Install dependencies
yarn install

echo "Muse installation completed!"
EOF

else
    echo "[INFO] Installing Muse in current user directory..."
    
    # Run as current user
    git clone https://github.com/museofficial/muse.git && cd muse
    cp .env.example .env
    LATEST_TAG=$(git describe --tags --abbrev=0)
    git checkout $LATEST_TAG
    echo "Checked out to: $LATEST_TAG"
    yarn install
    echo "Muse installation completed!"
fi

# Configure API keys
echo
echo "[INFO] Configuring API keys..."

read -p "Discord Bot Token (required): " DISCORD_TOKEN
while [ -z "$DISCORD_TOKEN" ]; do
    echo "Discord token is required!"
    read -p "Discord Bot Token: " DISCORD_TOKEN
done

read -p "YouTube API Key (optional, press enter to skip): " YOUTUBE_API_KEY
read -p "Spotify Client ID (optional, press enter to skip): " SPOTIFY_CLIENT_ID
if [ ! -z "$SPOTIFY_CLIENT_ID" ]; then
    read -p "Spotify Client Secret: " SPOTIFY_CLIENT_SECRET
fi

# Update .env file
if [ "$EUID" -eq 0 ]; then
    ENV_FILE="/home/muse/muse/.env"
else
    ENV_FILE="muse/.env"
fi

echo "[INFO] Updating .env file..."
sed -i "s/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/" "$ENV_FILE"

if [ ! -z "$YOUTUBE_API_KEY" ]; then
    sed -i "s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/" "$ENV_FILE"
fi

if [ ! -z "$SPOTIFY_CLIENT_ID" ]; then
    sed -i "s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/" "$ENV_FILE"
    sed -i "s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/" "$ENV_FILE"
fi

echo "[OK] Configuration updated"

# Create systemd service (only if running as root)
if [ "$EUID" -eq 0 ]; then
    echo "[INFO] Creating systemd service..."
    
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
    echo "[OK] Service created and enabled"
fi

echo
echo "=========================================="
echo "           Installation Complete"
echo "=========================================="
echo
echo "Configuration:"
echo "✓ Discord Bot Token: Configured"
if [ ! -z "$YOUTUBE_API_KEY" ]; then
    echo "✓ YouTube API Key: Configured"
fi
if [ ! -z "$SPOTIFY_CLIENT_ID" ]; then
    echo "✓ Spotify: Configured"
fi

if [ "$EUID" -eq 0 ]; then
    echo
    echo "Service Management:"
    echo "• Start service: systemctl start muse"
    echo "• Stop service: systemctl stop muse"
    echo "• Check status: systemctl status muse"
    echo "• View logs: journalctl -u muse -f"
    echo "• Restart service: systemctl restart muse"
    echo
    read -p "Start Muse service now? (y/N): " START_SERVICE
    if [[ $START_SERVICE =~ ^[Yy]$ ]]; then
        echo "[INFO] Starting Muse service..."
        systemctl start muse
        echo "[OK] Service started! Check logs for invite URL:"
        echo "journalctl -u muse -f"
    fi
else
    echo
    echo "To start Muse:"
    echo "   cd muse"
    echo "   yarn start"
fi
echo
echo "Get your Discord bot token from: https://discord.com/developers/applications"
echo "The bot will display an invite URL when started."
