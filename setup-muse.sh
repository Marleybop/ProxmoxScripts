#!/bin/bash

# Proxmox Muse Discord Bot LXC Container Setup Script
# This script creates a Debian LXC container and installs Muse Discord music bot

set -e

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to get user input with default value
get_input() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        while [ -z "$result" ]; do
            read -p "$prompt: " result
            if [ -z "$result" ]; then
                print_warning "This value is required!"
            fi
        done
        echo "$result"
    fi
}

# Function to check if string is a number
is_number() {
    case "$1" in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Function to validate container ID
validate_container_id() {
    local id="$1"
    if ! is_number "$id"; then
        return 1
    fi
    if [ "$id" -lt 100 ] || [ "$id" -gt 999999999 ]; then
        return 1
    fi
    if pct list | grep -q "^$id"; then
        return 1
    fi
    return 0
}

# Function to list available templates
list_templates() {
    print_info "Available Debian templates:"
    pveam list local | grep debian | nl -v0
}

# Function to list available storage
list_storage() {
    print_info "Available storage:"
    pvesm status | grep -E "(active|enabled)" | awk '{print NR-1 ": " $1 " (" $2 ")"}'
}

clear
echo "============================================="
echo "    Proxmox Muse Discord Bot Setup"
echo "============================================="
echo

print_info "This script will create an LXC container and install Muse Discord music bot"
echo

# Interactive configuration
print_info "Container Configuration:"

# Container ID
while true; do
    CONTAINER_ID=$(get_input "Enter container ID (100-999999999)" "200")
    if validate_container_id "$CONTAINER_ID"; then
        break
    else
        print_error "Invalid container ID or ID already exists!"
    fi
done

# Container name
CONTAINER_NAME=$(get_input "Enter container name" "muse-bot")

# List and select template
echo
list_templates
echo
TEMPLATE_CHOICE=$(get_input "Select template number (or enter custom name)" "0")
if is_number "$TEMPLATE_CHOICE"; then
    TEMPLATE=$(pveam list local | grep debian | sed -n "$((TEMPLATE_CHOICE+1))p" | awk '{print $2}')
    if [ -z "$TEMPLATE" ]; then
        TEMPLATE="debian-12-standard_12.7-1_amd64.tar.zst"
        print_warning "Invalid selection, using default: $TEMPLATE"
    fi
else
    TEMPLATE="$TEMPLATE_CHOICE"
fi

# List and select storage
echo
list_storage
echo
STORAGE_CHOICE=$(get_input "Select storage number (or enter custom name)" "0")
if is_number "$STORAGE_CHOICE"; then
    STORAGE=$(pvesm status | grep -E "(active|enabled)" | sed -n "$((STORAGE_CHOICE+1))p" | awk '{print $1}')
    if [ -z "$STORAGE" ]; then
        STORAGE="local-lvm"
        print_warning "Invalid selection, using default: $STORAGE"
    fi
else
    STORAGE="$STORAGE_CHOICE"
fi

# Resource configuration
ROOT_SIZE=$(get_input "Root filesystem size" "8G")
MEMORY=$(get_input "Memory (MB)" "2048")
CORES=$(get_input "CPU cores" "2")

# Network configuration
NETWORK=$(get_input "Network bridge" "vmbr0")
echo
print_info "IP Configuration options:"
echo "1. DHCP (automatic)"
echo "2. Static IP (e.g., 192.168.1.100/24)"
IP_CHOICE=$(get_input "Choose IP configuration (1 or 2)" "1")
if [ "$IP_CHOICE" = "2" ]; then
    IP_ADDRESS=$(get_input "Enter static IP with subnet (e.g., 192.168.1.100/24)")
else
    IP_ADDRESS="dhcp"
fi

# Security
PASSWORD=$(get_input "Set root password" "")

# Optional: API Keys
echo
print_info "API Keys Configuration (optional - can be set later):"
echo "You can configure these now or later via the container"
read -p "Do you want to configure API keys now? (y/N): " CONFIGURE_KEYS
case "$CONFIGURE_KEYS" in
    [Yy]|[Yy][Ee][Ss])
        DISCORD_TOKEN=$(get_input "Discord Bot Token (required for bot to work)" "")
        YOUTUBE_API_KEY=$(get_input "YouTube API Key (required for YouTube support)" "")
        SPOTIFY_CLIENT_ID=$(get_input "Spotify Client ID (optional)" "")
        SPOTIFY_CLIENT_SECRET=$(get_input "Spotify Client Secret (optional)" "")
        ;;
    *)
        DISCORD_TOKEN=""
        YOUTUBE_API_KEY=""
        SPOTIFY_CLIENT_ID=""
        SPOTIFY_CLIENT_SECRET=""
        ;;
esac

# Summary
echo
print_info "Configuration Summary:"
echo "Container ID: $CONTAINER_ID"
echo "Container Name: $CONTAINER_NAME"
echo "Template: $TEMPLATE"
echo "Storage: $STORAGE"
echo "Root Size: $ROOT_SIZE"
echo "Memory: ${MEMORY}MB"
echo "Cores: $CORES"
echo "Network: $NETWORK"
echo "IP: $IP_ADDRESS"
if [ -n "$DISCORD_TOKEN" ]; then
    echo "API Keys: Configured"
else
    echo "API Keys: Will configure later"
fi
echo

read -p "Proceed with installation? (y/N): " CONFIRM
case "$CONFIRM" in
    [Yy]|[Yy][Ee][Ss])
        # Continue with installation
        ;;
    *)
        print_info "Installation cancelled."
        exit 0
        ;;
esac

# Check if container already exists
if pct list | grep -q "^$CONTAINER_ID"; then
    print_error "Container $CONTAINER_ID already exists!"
    exit 1
fi

# Create LXC container
print_info "Creating LXC container..."
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
    --onboot 1

print_success "Container created successfully!"

# Start the container
print_info "Starting container..."
pct start $CONTAINER_ID

# Wait for container to be ready
print_info "Waiting for container to start..."
sleep 10

# Install packages and setup Muse
print_info "Setting up Muse inside container..."
pct exec $CONTAINER_ID -- bash -c "
set -e

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y curl wget git ffmpeg python3 python3-pip build-essential

# Install Node.js 18 (required for Muse)
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# Verify installations
echo 'Node.js version:'
node --version
echo 'npm version:'
npm --version
echo 'ffmpeg version:'
ffmpeg -version | head -1

# Create muse user
useradd -m -s /bin/bash muse
usermod -aG sudo muse

# Switch to muse user and install Muse
sudo -u muse bash -c '
cd /home/muse

# Clone Muse repository
git clone https://github.com/museofficial/muse.git
cd muse

# Get latest release tag
LATEST_TAG=\$(git describe --tags --abbrev=0)
git checkout \$LATEST_TAG
echo \"Checked out to latest release: \$LATEST_TAG\"

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Configure basic settings
sed -i \"s/DISCORD_TOKEN=.*/DISCORD_TOKEN=$DISCORD_TOKEN/\" .env
sed -i \"s/YOUTUBE_API_KEY=.*/YOUTUBE_API_KEY=$YOUTUBE_API_KEY/\" .env
sed -i \"s/SPOTIFY_CLIENT_ID=.*/SPOTIFY_CLIENT_ID=$SPOTIFY_CLIENT_ID/\" .env
sed -i \"s/SPOTIFY_CLIENT_SECRET=.*/SPOTIFY_CLIENT_SECRET=$SPOTIFY_CLIENT_SECRET/\" .env

# Set cache limit to 1GB (adjust as needed)
echo \"CACHE_LIMIT=1GB\" >> .env

# Optional: Enable SponsorBlock (uncomment if desired)
# echo \"ENABLE_SPONSORBLOCK=true\" >> .env

echo \"Environment file configured\"
'

# Create systemd service for Muse
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

# Enable and start the service
systemctl daemon-reload
systemctl enable muse.service

echo 'Muse installation completed!'
echo 'Service created but not started yet - configure your API keys first'
"

echo ""
print_success "Setup Complete!"
echo ""
echo "Container Information:"
echo "- ID: $CONTAINER_ID"
echo "- Name: $CONTAINER_NAME"
echo "- IP: Check with 'pct exec $CONTAINER_ID -- ip addr show eth0'"
echo ""
echo "Next Steps:"
if [ -z "$DISCORD_TOKEN" ]; then
    echo "1. Configure your API keys:"
    echo "   pct exec $CONTAINER_ID -- sudo -u muse nano /home/muse/muse/.env"
    echo ""
    echo "2. Required API Keys to configure:"
    echo "   - DISCORD_TOKEN (from https://discord.com/developers/applications)"
    echo "   - YOUTUBE_API_KEY (from Google Developer Console)"
    echo "   - SPOTIFY_CLIENT_ID (optional, from Spotify Developer Dashboard)"
    echo "   - SPOTIFY_CLIENT_SECRET (optional, from Spotify Developer Dashboard)"
    echo ""
    echo "3. Start the Muse service:"
    echo "   pct exec $CONTAINER_ID -- systemctl start muse"
else
    echo "1. Start the Muse service:"
    echo "   pct exec $CONTAINER_ID -- systemctl start muse"
fi
echo ""
echo "4. Check service status:"
echo "   pct exec $CONTAINER_ID -- systemctl status muse"
echo ""
echo "5. View logs:"
echo "   pct exec $CONTAINER_ID -- journalctl -u muse -f"
echo ""
echo "6. The bot will log an invite URL when started. Use this to add it to your Discord server."
echo ""
echo "Container root password: $PASSWORD (change this!)"
echo ""
echo "To access the container: pct enter $CONTAINER_ID"
