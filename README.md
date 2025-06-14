# 🎵 Muse Discord Bot LXC Installer

An automated installer for the [Muse Discord Bot](https://github.com/museofficial/muse) that creates a complete LXC container on Proxmox VE with an interactive GUI.

## ✨ Features

- 🐳 **Automated LXC Creation** - Creates and configures a complete container
- 🎨 **Interactive GUI** - User-friendly dialog-based interface
- 🚀 **One-Command Install** - Everything automated from container to bot
- 🔧 **API Key Configuration** - Guided setup for Discord, YouTube, and Spotify
- 📊 **Progress Tracking** - Visual progress bar during installation
- 🔄 **Systemd Service** - Auto-starts on boot with proper service management
- 📝 **Live Logs** - Shows Discord invite URL immediately after install

## 🖥️ Requirements

- **Proxmox VE** host (tested on Proxmox 8.x)
- **Root access** on Proxmox host
- **Internet connection** for downloading packages
- **Available container ID** (100-999)

## 🚀 Quick Start

Run this single command on your Proxmox host as root:

```bash
bash <(curl -s https://raw.githubusercontent.com/Marleybop/ProxmoxScripts/main/muse-lxc.sh)
```

## 📋 What You'll Need

Before running the installer, gather these API keys:

### Required
- **Discord Bot Token** - Get from [Discord Developer Portal](https://discord.com/developers/applications)
  1. Create a new application
  2. Go to "Bot" section
  3. Copy the token

### Optional
- **YouTube API Key** - Enables YouTube search functionality
  - Get from [Google Cloud Console](https://console.developers.google.com)
  - Enable YouTube Data API v3
  
- **Spotify Client ID & Secret** - Enables Spotify playlist support
  - Get from [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
  - Create an app and copy credentials

## 🎯 Installation Process

The installer will guide you through:

1. **Container Configuration**
   - Container ID (100-999)
   - Hostname
   - Root password
   - Memory allocation
   - Disk size
   - CPU cores

2. **API Key Setup**
   - Discord bot token (required)
   - YouTube API key (optional)
   - Spotify credentials (optional)

3. **Automated Installation**
   - Creates LXC container
   - Installs Node.js 18 LTS
   - Installs dependencies (ffmpeg, yarn, etc.)
   - Downloads and configures Muse
   - Sets up systemd service
   - Starts the bot

## 📱 GUI Screenshots

The installer features a complete interactive interface:

- **Welcome Screen** - Overview of installation process
![image](https://github.com/user-attachments/assets/1f6c8319-eba1-4f9f-8df7-3abba8b2121d)

- **Configuration Forms** - Easy input with validation
- **Progress Bar** - Visual installation progress
- **Confirmation Dialogs** - Review settings before proceeding
- **Success Messages** - Clear completion status

## 🔧 Management Commands

After installation, manage your Muse bot with these commands:

### Container Management
```bash
# Enter the container
pct enter [CONTAINER_ID]

# Check container status
pct status [CONTAINER_ID]

# Start/stop container
pct start [CONTAINER_ID]
pct stop [CONTAINER_ID]
```

### Service Management (inside container)
```bash
# Check service status
systemctl status muse

# Start/stop/restart service
systemctl start muse
systemctl stop muse
systemctl restart muse

# View live logs
journalctl -u muse -f

# View recent logs
journalctl -u muse --since "1 hour ago"
```

## 🏗️ Technical Details

### Container Specifications
- **OS**: Debian 12 (latest stable)
- **Default Resources**: 2GB RAM, 20GB storage, 2 CPU cores
- **Network**: DHCP on vmbr0
- **Features**: Nesting enabled for Docker support
- **Security**: Unprivileged container

### Software Stack
- **Node.js**: 18.x LTS (required for Muse)
- **Package Manager**: Yarn
- **Audio Processing**: FFmpeg
- **Database**: SQLite (embedded)
- **Process Manager**: systemd

### File Locations
```
/home/muse/muse/          # Muse installation directory
/home/muse/muse/.env      # Configuration file
/etc/systemd/system/muse.service  # Service definition
```

## 🐛 Troubleshooting

### Installation Issues

**Container ID already exists**
```bash
# Check existing containers
pct list

# Use a different ID or remove existing container
pct destroy [CONTAINER_ID]
```

**Template not found**
```bash
# Download Debian 12 template
pveam download local debian-12-standard_12.7-1_amd64.tar.zst
```

**Network issues**
- Ensure container has network access
- Check Proxmox firewall settings
- Verify DNS resolution in container

### Bot Issues

**Bot won't start**
```bash
# Check service logs
pct exec [CONTAINER_ID] -- journalctl -u muse -n 50

# Verify configuration
pct exec [CONTAINER_ID] -- cat /home/muse/muse/.env
```

**Invalid Discord token**
- Regenerate token in Discord Developer Portal
- Update .env file in container
- Restart service

**Missing permissions**
- Ensure bot has proper permissions in Discord server
- Check bot role hierarchy
- Verify required intents are enabled

## 🔄 Updates

To update Muse to the latest version:

```bash
# Enter container
pct enter [CONTAINER_ID]

# Switch to muse user
su - muse
cd muse

# Stop service
sudo systemctl stop muse

# Update to latest release
git fetch --tags
LATEST_TAG=$(git describe --tags --abbrev=0)
git checkout $LATEST_TAG

# Update dependencies
yarn install

# Start service
sudo systemctl start muse
```

## 🤝 Contributing

This installer is maintained as part of the [ProxmoxScripts](https://github.com/Marleybop/ProxmoxScripts) repository.

### Reporting Issues
- Open an issue with installation logs
- Include Proxmox version and container specs
- Provide error messages and steps to reproduce

### Feature Requests
- Suggest improvements for the installer
- Request support for additional configurations
- Propose GUI enhancements

## 📜 License

This installer script is provided as-is for educational and convenience purposes. 

The Muse Discord Bot itself is licensed under its own terms - see the [official Muse repository](https://github.com/museofficial/muse) for details.

## 🙏 Credits

- **Muse Discord Bot** - Created by [codetheweb](https://github.com/codetheweb)
- **Original Bot Repository** - https://github.com/museofficial/muse
- **Installation Script** - Simplified automation for Proxmox environments

## 📞 Support

- **Muse Bot Issues** - Use the [official Muse repository](https://github.com/museofficial/muse/issues)
- **Installer Issues** - Open an issue in this repository
- **Proxmox Help** - Check [Proxmox documentation](https://pve.proxmox.com/pve-docs/)

---

*Made with ❤️ for the Discord community*
