# ProxmoxScripts

A collection of Proxmox automation scripts for easy LXC container deployment and application setup.

## Muse Discord Bot Setup

Automated scripts to deploy the [Muse Discord music bot](https://github.com/museofficial/muse) in a Proxmox LXC container.

### Available Scripts

#### 1. Interactive Command Line Version
**File:** `setup-muse.sh`

A fully interactive script with colored output and input validation.

**Features:**
- ✅ Interactive prompts for all configuration
- ✅ Lists available templates and storage automatically
- ✅ Input validation and error checking
- ✅ Colored output for better visibility
- ✅ Configuration summary before installation
- ✅ Optional API key setup during installation

#### 2. GUI Dialog Version
**File:** `setup-muse-gui.sh`

A text-based GUI using dialog boxes for point-and-click setup.

**Features:**
- ✅ Menu-driven template and storage selection
- ✅ Progress bar during installation
- ✅ Password input fields
- ✅ Automatic dialog installation if missing
- ✅ Option to start service immediately after setup

### Prerequisites

- Proxmox VE host
- Root access to Proxmox host
- Internet connectivity for downloading packages
- Available container ID (100-999999999)

### Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/Marleybop/ProxmoxScripts.git
   cd ProxmoxScripts
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x setup-muse.sh setup-muse-gui.sh
   ```

3. **Run your preferred version:**
   
   **Interactive CLI:**
   ```bash
   ./setup-muse.sh
   ```
   
   **GUI Version:**
   ```bash
   ./setup-muse-gui.sh
   ```

### What Gets Installed

The scripts create a Debian 12 LXC container with:

- **Node.js 18** (required for Muse)
- **ffmpeg** (required for audio processing)
- **Git** and build tools
- **Muse Discord bot** (latest stable release)
- **Systemd service** for automatic startup
- **Dedicated user** for security

### Configuration Options

Both scripts allow you to configure:

- **Container ID** and name
- **Template selection** (from available Debian templates)
- **Storage pool** (from available storage)
- **Resources** (CPU, RAM, disk size)
- **Network settings** (DHCP or static IP)
- **API keys** (Discord, YouTube, Spotify)

### Required API Keys

To use Muse, you'll need:

1. **Discord Bot Token** (Required)
   - Go to [Discord Developer Portal](https://discord.com/developers/applications)
   - Create a new application → Bot → Copy token

2. **YouTube API Key** (Required)
   - Go to [Google Developer Console](https://console.developers.google.com)
   - Create project → Enable YouTube Data API v3 → Create credentials

3. **Spotify API Keys** (Optional)
   - Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
   - Create app → Copy Client ID and Client Secret

### Post-Installation

After the script completes:

1. **Configure API keys** (if not done during installation):
   ```bash
   pct exec [CONTAINER_ID] -- sudo -u muse nano /home/muse/muse/.env
   ```

2. **Start the Muse service:**
   ```bash
   pct exec [CONTAINER_ID] -- systemctl start muse
   ```

3. **Check service status:**
   ```bash
   pct exec [CONTAINER_ID] -- systemctl status muse
   ```

4. **View logs for Discord invite URL:**
   ```bash
   pct exec [CONTAINER_ID] -- journalctl -u muse -f
   ```

5. **Access container directly:**
   ```bash
   pct enter [CONTAINER_ID]
   ```

### Default Container Specifications

- **OS:** Debian 12
- **Memory:** 2048 MB
- **CPU Cores:** 2
- **Storage:** 8 GB
- **Network:** DHCP on vmbr0
- **Features:** Nesting enabled, unprivileged

### Troubleshooting

**Container creation fails:**
- Check if container ID is already in use
- Verify template exists: `pveam list local`
- Check storage availability: `pvesm status`

**Muse won't start:**
- Verify API keys in `/home/muse/muse/.env`
- Check logs: `journalctl -u muse -f`
- Ensure Node.js 18 is installed: `node --version`

**No audio playback:**
- Verify ffmpeg installation: `ffmpeg -version`
- Check Discord bot permissions in server
- Ensure bot is in a voice channel

### Support

- **Muse Documentation:** [GitHub Repository](https://github.com/museofficial/muse)
- **Proxmox Documentation:** [Official Docs
